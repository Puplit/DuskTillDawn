-- search | client: the prompt, the menu, the kneel, the restraint guard.
-- Nothing here decides anything that matters: every action is re-checked by
-- server/search/main.lua. Everything is local to this file except PupMenu
-- (client/search/pupmenu.lua) and the shared Search* helpers.

local CFG <const> = SearchConfig
local L <const> = SearchLocale
local T <const> = CFG.Timings

local Core = nil
do
    local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
    if ok then Core = core end
end

local function dbg(...)
    if CFG.General.debug then print('[pup-misc/search]', ...) end
end

local function notify(text, ms)
    if Core and Core.NotifyObjective then
        Core.NotifyObjective(text, ms or CFG.Notify.normalMs)
    else
        TriggerEvent('vorp:TipBottom', text, ms or CFG.Notify.normalMs)
    end
end

local function truthy(v) return v == true or v == 1 end

-- ------------------------------------------------------------------ state

local myJob = nil        -- nil until the server answers
local amSuper = false    -- told by the server, never guessed
local lastJobAsk = 0
local inSisika = false
local permitted = false
local purgeFlag = false

-- the one search this client may run: { id, target, phase, since, ... }
-- phase: 'waiting' (asked the server), 'menu', 'input', 'panel'
local current = nil
local searchSeq = 0
local animOn = false

-- ------------------------------------------------------------------ helpers

local function isLaw()
    return SearchIsLawJob(myJob)
end

local function computePermitted()
    if amSuper then return true end
    if isLaw() then return true end
    if CFG.Sisika.block and inSisika then return false end
    if CFG.Law.searchOnly then return false end
    return true
end

local function pedRestrained(ped)
    return truthy(IsPedHogtied(ped)) or truthy(IsPedCuffed(ped))
end

-- every native result goes through truthy(): some RedM natives return 0/1, and a
-- bare 0 is TRUE in Lua (it would read every player as dead or ragdolled)
local function pedDead(ped)
    return truthy(IsEntityDead(ped)) or truthy(IsPedDeadOrDying(ped, true))
end

local function carrying(ped)
    return truthy(Citizen.InvokeNative(0xA911EE21EDF69DAF, ped)) -- IsPedCarryingSomething
end

local function searcherReady(ped)
    if pedDead(ped) or pedRestrained(ped) then return false end
    if truthy(IsPedOnMount(ped)) or truthy(IsPedInAnyVehicle(ped, false)) then return false end
    if carrying(ped) then return false end
    return true
end

local function closestPlayer(ped)
    local me = PlayerId()
    local here = GetEntityCoords(ped)
    local bestPed, bestSid, bestDist = nil, nil, math.huge
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local other = GetPlayerPed(pid)
            if other and other ~= 0 and DoesEntityExist(other) then
                local d = #(GetEntityCoords(other) - here)
                if d < bestDist then
                    bestPed, bestSid, bestDist = other, GetPlayerServerId(pid), d
                end
            end
        end
    end
    return bestPed, bestSid, bestDist
end

-- ------------------------------------------------------------------ animation

local function stopAnim()
    if not animOn then return end
    animOn = false
    StopAnimTask(PlayerPedId(), CFG.Anim.dict, CFG.Anim.clip, 1.0)
    RemoveAnimDict(CFG.Anim.dict)
end

local function startAnim(id)
    CreateThread(function()
        RequestAnimDict(CFG.Anim.dict)
        local deadline = GetGameTimer() + 2000
        while not HasAnimDictLoaded(CFG.Anim.dict) and GetGameTimer() < deadline do Wait(50) end
        if not HasAnimDictLoaded(CFG.Anim.dict) then return end
        if not current or current.id ~= id then return end
        TaskPlayAnim(PlayerPedId(), CFG.Anim.dict, CFG.Anim.clip, 4.0, -4.0, -1, CFG.Anim.flags, 0.0, false, false, false)
        animOn = true
    end)
end

-- ------------------------------------------------------------------ ending

local function noop() end

local function endSearch()
    local s = current
    if not s then return end
    current = nil
    stopAnim()
    -- close our menu if it is still up, without re-entering here
    if PupMenu and PupMenu.IsOpen() and PupMenu.OnClose == s.onClose then
        PupMenu.OnClose = noop
        PupMenu.Close()
    end
    TriggerServerEvent('pup-search:endsearch')
    dbg('search ended', s.target)
end

-- ------------------------------------------------------------------ menu

local function cashRowAllowed()
    if amSuper then return true end
    if CFG.Steal.cash then return true end
    return CFG.Law.cashBypass and isLaw()
end

local function inventoryRowAllowed()
    if amSuper then return true end
    if CFG.Steal.items or CFG.Steal.weapons then return true end
    return (CFG.Law.itemBypass or CFG.Law.weaponBypass) and isLaw()
end

local function askAmount()
    local s = current
    if not s then return end
    if CFG.Law.cashOnly and not (amSuper or isLaw()) then
        PupMenu.Refresh()
        return
    end
    s.phase = 'input'
    s.inputAt = GetGameTimer()
    s.inputOwner = ('pup-misc:search:amount:%d'):format(s.id)
    exports['pup-ui']:OpenInput({
        owner = s.inputOwner,
        title = L.amountTitle,
        fields = {
            { label = L.amountField, type = 'number', placeholder = L.amountPlaceholder, required = true, min = 0 },
        },
    })
end

local function chooseInventory()
    local s = current
    if not s then return end
    s.keepOnClose = true -- the close that follows is the hand-over to the steal panel
end

local function openMenu(info)
    local s = current
    if not s then return end

    local options = {}
    if cashRowAllowed() then
        options[#options + 1] = {
            label = L.cashLabel:format(('%.2f'):format(tonumber(info.cash) or 0)),
            desc = L.cashDesc,
            action = askAmount,
            reopen = false,
        }
    end
    if inventoryRowAllowed() then
        options[#options + 1] = {
            label = L.inventoryLabel,
            desc = L.inventoryDesc,
            action = chooseInventory,
            close = true,
        }
    end

    -- the close handler is set on every open, so another module
    -- replacing PupMenu.OnClose in between cannot strand this search.
    s.onClose = function()
        if current ~= s then return end
        if s.keepOnClose then
            s.keepOnClose = false
            s.phase = 'panel'
            s.panelAskedAt = GetGameTimer()
            TriggerServerEvent('pup-search:ReloadstealInventory', s.target)
            return
        end
        endSearch()
    end
    PupMenu.OnClose = s.onClose
    s.phase = 'menu'
    PupMenu.Open({ title = L.menuTitle, subtitle = L.menuSubtitle, options = options })
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    local s = current
    if not s or s.phase ~= 'input' or owner ~= s.inputOwner then return end
    s.inputOwner = nil
    s.phase = 'menu'

    if type(values) ~= 'table' then
        PupMenu.Refresh() -- cancelled: back to the menu
        return
    end

    local amount = tonumber(values[1])
    -- whole dollars only, checked here so a too-small amount does not
    -- end the search for nothing. Two decimals are kept so "everything" can
    -- include the victim's cents (the server caps it).
    if not amount or amount ~= amount or amount < 1 then
        notify(L.amountTooSmall)
        PupMenu.Refresh()
        return
    end
    amount = math.floor(amount * 100) / 100
    TriggerServerEvent('pup-search:takecash', s.target, amount)
    PupMenu.Close() -- ends the search through s.onClose
end)

-- ------------------------------------------------------------------ opening

local function uiPanelOpen()
    local ok, open = pcall(function() return exports['pup-ui']:IsPanelOpen() end)
    return not ok or open == true -- unknown counts as open: never cut a live input short
end

local function watch(s)
    CreateThread(function()
        while current == s do
            Wait(500)
            if current ~= s then return end
            local now = GetGameTimer()
            if s.phase == 'waiting' and now - s.since > T.openReplyTimeoutMs then
                endSearch()
            elseif s.phase == 'menu' and not PupMenu.IsOpen() then
                endSearch()
            elseif s.phase == 'input' and now - (s.inputAt or now) > T.inputLostMs and not uiPanelOpen() then
                -- the amount panel vanished without an inputDone (force-closed or
                -- replaced): treat it as a cancel instead of kneeling forever
                s.inputOwner = nil
                s.phase = 'menu'
                PupMenu.Refresh()
            elseif s.phase == 'panel' and not s.panelOpen and now - (s.panelAskedAt or now) > T.panelOpenTimeoutMs then
                endSearch()
            end
        end
    end)
end

local function beginSearch(targetSid)
    if current or not targetSid or targetSid <= 0 then return end
    searchSeq = searchSeq + 1
    current = { id = searchSeq, target = targetSid, phase = 'waiting', since = GetGameTimer() }
    TriggerServerEvent('pup-search:getinfo', targetSid)
    watch(current)
    dbg('asked to search', targetSid)
end

RegisterNetEvent('pup-search:recinfo', function(info)
    local s = current
    if not s or s.phase ~= 'waiting' or type(info) ~= 'table' then return end
    if tonumber(info.serverId) ~= s.target then return end
    s.info = info
    startAnim(s.id)
    openMenu(info)
end)

RegisterNetEvent('pup-misc:search:refused', function()
    local s = current
    if s and s.phase == 'waiting' then
        current = nil
        stopAnim()
    end
end)

RegisterNetEvent('pup-search:stopanime', function()
    endSearch()
    stopAnim()
end)

RegisterNetEvent('vorp_inventory:OpenstealInventory', function()
    if current and current.phase == 'panel' then current.panelOpen = true end
end)

RegisterNetEvent('vorp_inventory:ReloadstealInventory', function()
    if current and current.phase == 'panel' then current.panelOpen = true end
end)

-- vorp_inventory fires this on every close of any panel
AddEventHandler('pup:closeinv', function()
    if current then endSearch() end
end)

-- ------------------------------------------------------------------ prompts

local cuffGroup, cuffPrompt = nil, nil
local boundPrompt, boundPed = nil, nil
local hogSeenPed, hogSeenAt = nil, 0

local function makePrompt(group, onRelease)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, CFG.General.searchKey)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', L.prompt))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, onRelease)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

local function dropBound()
    if boundPrompt then
        PromptDelete(boundPrompt)
        boundPrompt, boundPed = nil, nil
    end
end

-- the prompt follows whichever target is closest
local function bindTo(ped)
    if boundPed == ped and boundPrompt then return end
    dropBound()
    local group = Citizen.InvokeNative(0xB796970BD125FCE8, ped, Citizen.ResultAsInteger()) -- PromptGetGroupIdForTargetEntity
    if not group or group == 0 then return end
    boundPrompt = makePrompt(group, true)
    boundPed = ped
end

CreateThread(function()
    Wait(T.promptGroupDelayMs)
    cuffGroup = GetRandomIntInRange(0, 0xffffff)
    cuffPrompt = makePrompt(cuffGroup, false)

    local groupLabel = CreateVarString(10, 'LITERAL_STRING', L.promptGroup)
    while true do
        local wait = 500
        local ped = PlayerPedId()

        if not current and permitted and searcherReady(ped) then
            local tPed, tSid, dist = closestPlayer(ped)
            if tPed and dist <= CFG.General.promptDistance then
                wait = 0
                local dead = pedDead(tPed)
                local hogtied = not dead and truthy(IsPedHogtied(tPed))
                local cuffed = not dead and not hogtied and truthy(IsPedCuffed(tPed))
                if not hogtied then hogSeenPed = nil end

                if dead and SearchRules.deadSearch then
                    bindTo(tPed)
                    if boundPed == tPed and PromptHasStandardModeCompleted(boundPrompt) then
                        beginSearch(tSid)
                    end
                elseif hogtied and CFG.Targets.hogtied then
                    if hogSeenPed ~= tPed then hogSeenPed, hogSeenAt = tPed, GetGameTimer() end
                    if GetGameTimer() - hogSeenAt >= T.hogtiedPromptDelayMs then
                        bindTo(tPed)
                    elseif boundPed ~= tPed then
                        dropBound()
                    end
                    if boundPed == tPed and PromptHasStandardModeCompleted(boundPrompt) then
                        beginSearch(tSid)
                    end
                elseif cuffed and CFG.Targets.cuffed then
                    dropBound()
                    PromptSetActiveGroupThisFrame(cuffGroup, groupLabel, 0, 0, 0, 0)
                    if PromptHasStandardModeCompleted(cuffPrompt) then
                        beginSearch(tSid)
                    end
                else
                    dropBound()
                end
            elseif tPed and dist <= 3.0 then
                wait = 100
                dropBound()
            else
                dropBound()
            end
        else
            dropBound()
        end

        Wait(wait)
    end
end)

-- ------------------------------------------------------------------ permission + zone

local sisikaZone = nil
CreateThread(function()
    if PolyZone and PolyZone.Create then
        local pts = {}
        for i, p in ipairs(CFG.Sisika.points) do pts[i] = vector2(p.x, p.y) end
        local ok, zone = pcall(function()
            return PolyZone:Create(pts, { name = 'pup_misc_search_sisika', minZ = CFG.Sisika.minZ, maxZ = CFG.Sisika.maxZ })
        end)
        if ok and zone then
            sisikaZone = zone
            zone:onPlayerInOut(function(inside) inSisika = inside == true end)
        end
    end
    if not sisikaZone then
        print('^3[pup-misc/search]^7 PolyZone unavailable; using the built-in Sisika check')
    end

    while true do
        if not sisikaZone then
            local c = GetEntityCoords(PlayerPedId())
            inSisika = SearchInSisika(c.x, c.y, c.z)
        end
        permitted = computePermitted()
        Wait(T.permissionRecheckMs)
    end
end)

-- ------------------------------------------------------------------ job

local function askJob()
    lastJobAsk = GetGameTimer()
    TriggerServerEvent('pup-search:getjob')
end

RegisterNetEvent('pup-search:recjob', function(job, isSuper)
    if type(job) == 'string' then myJob = job end
    amSuper = isSuper == true
    permitted = computePermitted()
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    myJob, amSuper = nil, false
    endSearch()
    askJob()
end)

CreateThread(function()
    Wait(T.jobFirstAskMs)
    while true do
        -- an unknown job is asked for every second; a known one is
        -- refreshed now and then too (the server also pushes job changes)
        if myJob == nil or GetGameTimer() - lastJobAsk >= T.jobRefreshMs then
            askJob()
        end
        Wait(T.jobRetryMs)
    end
end)

-- ------------------------------------------------------------------ purge

RegisterNetEvent('pup-events:state', function(key, on)
    if key ~= CFG.Purge.eventKey then return end
    purgeFlag = on == true
    SearchSetPurge(purgeFlag)
end)

CreateThread(function()
    while true do
        Wait(T.purgePollMs)
        SearchSetPurge(purgeFlag)
    end
end)

-- ------------------------------------------------------------------ server asks: am I restrained?

RegisterNetEvent('pup-misc:search:stateQuery', function(nonce)
    local ped = PlayerPedId()
    TriggerServerEvent('pup-misc:search:stateReply', nonce,
        truthy(IsPedHogtied(ped)), truthy(IsPedCuffed(ped)), pedDead(ped))
end)

-- ------------------------------------------------------------------ restraint guard

CreateThread(function()
    local fired = false
    while true do
        local ped = PlayerPedId()
        local restrained = pedRestrained(ped) or pedDead(ped) or truthy(IsPedRagdoll(ped))
        if restrained then
            if not fired then
                fired = true
                if LocalPlayer.state.IsInvActive then TriggerEvent('vorp_inventory:CloseInv') end
                if current then endSearch() end
                stopAnim()
            end
            for _, control in ipairs(CFG.Controls.inventory) do
                DisableControlAction(0, control, true)
            end
            Wait(0)
        else
            fired = false
            Wait(250)
        end
    end
end)

-- ------------------------------------------------------------------ stop

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if cuffPrompt then PromptDelete(cuffPrompt) end
    dropBound()
    if sisikaZone then pcall(function() sisikaZone:destroy() end) end
    if current then
        local s = current
        current = nil
        if PupMenu and PupMenu.OnClose == s.onClose then PupMenu.OnClose = noop end
    end
    stopAnim()
end)
