-- pup-gangs | client/features.lua: the world side - gang table, dens, plants, claims

local Core = exports.vorp_core:GetCore()

local function dbg(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-gangs]^7 " .. table.concat(parts, " "))
end

-- minimal on-screen text, declared UP HERE because both the run HUD and the claim HUD (further down) draw with it
local function drawtext(text, x, y, center, r, g, b, a)
    SetTextScale(0.0, 0.42)
    SetTextColor(math.floor(r or 255), math.floor(g or 255), math.floor(b or 255), math.floor(a or 255))
    SetTextCentre(center and true or false)
    SetTextDropshadow(1, 0, 0, 0, 220)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', tostring(text)), x, y)
end

-- GANG TABLE - placement is gated on being inside a house you own or hold (pup_realestate)
local tableObj  = nil
local tableData = nil
local tablePrompt, stashPrompt
local denPrompt, denRunPrompt, denMenuPrompt, denGroup

local function currentHouseId()
    -- pup_realestate's getCurrentHouseId export
    local ok, id = pcall(function() return exports['pup_realestate']:getCurrentHouseId() end)
    dbg('currentHouseId ->', ok and tostring(id) or ('export failed: ' .. tostring(id)))
    if ok and tonumber(id) then return tonumber(id) end
    return nil
end

local function setupPrompts()
    local group = GetRandomIntInRange(0, 0xffffff)

    tablePrompt = PromptRegisterBegin()
    PromptSetControlAction(tablePrompt, Config.Keys.table) -- E
    PromptSetText(tablePrompt, CreateVarString(10, 'LITERAL_STRING', Locale.tablePrompt))
    PromptSetEnabled(tablePrompt, 1)
    PromptSetVisible(tablePrompt, 1)
    PromptSetStandardMode(tablePrompt, 1)
    PromptSetGroup(tablePrompt, group)
    PromptRegisterEnd(tablePrompt)

    -- G is ONLY the founder's "pick up the table" escape hatch
    stashPrompt = PromptRegisterBegin()
    PromptSetControlAction(stashPrompt, Config.Keys.tablePickup) -- G
    PromptSetText(stashPrompt, CreateVarString(10, 'LITERAL_STRING', Locale.tablePickup or 'Pick up gang table'))
    PromptSetEnabled(stashPrompt, 1)
    PromptSetVisible(stashPrompt, 1)
    PromptSetStandardMode(stashPrompt, 1)
    PromptSetGroup(stashPrompt, group)
    PromptRegisterEnd(stashPrompt)

    -- dens use their own group so the label can say what E does in context (Collect Product / Raid)
    denGroup = GetRandomIntInRange(0, 0xffffff)
    denPrompt = PromptRegisterBegin()
    PromptSetControlAction(denPrompt, Config.Keys.denInteract) -- E
    PromptSetText(denPrompt, CreateVarString(10, 'LITERAL_STRING', 'Interact'))
    PromptSetEnabled(denPrompt, 1)
    PromptSetVisible(denPrompt, 1)
    PromptSetStandardMode(denPrompt, 1)
    PromptSetGroup(denPrompt, denGroup)
    PromptRegisterEnd(denPrompt)

    -- G at your own den STARTS a delivery run
    denRunPrompt = PromptRegisterBegin()
    PromptSetControlAction(denRunPrompt, Config.Keys.denRun) -- G
    PromptSetText(denRunPrompt, CreateVarString(10, 'LITERAL_STRING', 'Start a delivery run'))
    PromptSetEnabled(denRunPrompt, 1)
    PromptSetVisible(denRunPrompt, 1)
    PromptSetStandardMode(denRunPrompt, 1)
    PromptSetGroup(denRunPrompt, denGroup)
    PromptRegisterEnd(denRunPrompt)

    -- claims and raids are run out of the DEN, so the panel opens here too, in 'den' context
    denMenuPrompt = PromptRegisterBegin()
    PromptSetControlAction(denMenuPrompt, Config.Keys.denMenu) -- F
    PromptSetText(denMenuPrompt, CreateVarString(10, 'LITERAL_STRING', 'Claims & Raids'))
    PromptSetEnabled(denMenuPrompt, 1)
    PromptSetVisible(denMenuPrompt, 1)
    PromptSetStandardMode(denMenuPrompt, 1)
    PromptSetGroup(denMenuPrompt, denGroup)
    PromptRegisterEnd(denMenuPrompt)

    return group
end

local function despawnTable()
    if tableObj and DoesEntityExist(tableObj) then DeleteEntity(tableObj) end
    tableObj = nil
end

local function spawnTable(t)
    despawnTable()
    if not t then return end
    local model = GetHashKey(Config.Table.prop)
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 100 do tries = tries + 1 Wait(10) end
    if not HasModelLoaded(model) then return end
    tableObj = CreateObject(model, t.x + 0.0, t.y + 0.0, t.z + 0.0, false, false, false)
    SetEntityHeading(tableObj, (tonumber(t.h) or 0.0) + 0.0)
    FreezeEntityPosition(tableObj, true)
    SetModelAsNoLongerNeeded(model)
    dbg('spawned gang table at', t.x, t.y, t.z)
end

local function refreshTable()
    local list = Core.Callback.TriggerAwait('pup-gangs:getTables')
    tableData = (type(list) == 'table') and list[1] or nil
    spawnTable(tableData)
end

RegisterNetEvent('pup-gangs:tablesDirty', function() refreshTable() end)

-- placement: only offered while inside a house
function PlaceGangTable()
    local houseid = currentHouseId()
    dbg('PlaceGangTable: houseid =', tostring(houseid))
    if not houseid then
        return exports['pup-ui']:Toast(Locale.needHouse)
    end
    local ped = PlayerPedId()

    -- gizmo placement: vorp_lib's drag gizmo, the same one the house furniture flows use
    if GetResourceState('vorp_lib') == 'started' then
        local model = GetHashKey(Config.Table.prop)
        RequestModel(model)
        local tries = 0
        while not HasModelLoaded(model) and tries < 100 do tries = tries + 1 Wait(10) end
        if HasModelLoaded(model) then
            local spawn = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
            local obj = CreateObject(model, spawn.x, spawn.y, spawn.z, true, true, false)
            if obj and obj ~= 0 and DoesEntityExist(obj) then
                SetEntityCollision(obj, false, false)
                SetEntityAsMissionEntity(obj, true)
                PlaceObjectOnGroundProperly(obj)
                SetModelAsNoLongerNeeded(model)

                local result = exports.vorp_lib:StartGizmo(obj, 200, false, false, true)

                if DoesEntityExist(obj) then DeleteObject(obj) end
                if result and result.position then
                    local heading = (result.rotation and result.rotation.z or 0.0) % 360
                    dbg('PlaceGangTable: gizmo confirmed at', result.position.x, result.position.y, result.position.z)
                    TriggerServerEvent('pup-gangs:placeTable', houseid,
                        result.position.x, result.position.y, result.position.z, heading)
                else
                    dbg('PlaceGangTable: gizmo cancelled')
                end
                return
            end
            SetModelAsNoLongerNeeded(model)
        end
    end

    -- fallback (vorp_lib missing): drop it a step in front like before
    local c = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local x, y, z = c.x + fwd.x * 1.2, c.y + fwd.y * 1.2, c.z - 0.95
    dbg('PlaceGangTable: sending placeTable (no gizmo)', houseid, x, y, z)
    TriggerServerEvent('pup-gangs:placeTable', houseid, x, y, z, GetEntityHeading(ped))
end

-- using the gang_table item from the satchel places it (founding flow: no gang, no panel access - the item is the way in)
RegisterNetEvent('pup-gangs:useTableItem', function()
    dbg('useTableItem event received from server')
    PlaceGangTable()
end)

-- same flow for a DEN (the panel's Perks tab calls this)
function DesignateDen()
    -- dens are found in the world, not made in a house
    if not Config.Dens.playerDens then
        return exports['pup-ui']:Toast(Locale.denNoBuild)
    end
    local houseid = currentHouseId()
    if not houseid then
        return exports['pup-ui']:Toast(Locale.denNeedHouse)
    end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local x, y, z = c.x + fwd.x * 1.2, c.y + fwd.y * 1.2, c.z - 0.95
    TriggerServerEvent('pup-gangs:designateDen', houseid, x, y, z, GetEntityHeading(ped))
end

-- DRUG PLANTS
local activePlants = {}   -- [id] = { id, x, y, z, endts, blip, attacker, defender }
local myGangId = nil

local function clearPlantBlip(p)
    if p and p.blip and DoesBlipExist(p.blip) then pcall(function() RemoveBlip(p.blip) end) end
end

-- generic alert circle - same radius-blip natives as the territory layer and the MDT's drug alerts
local function drawAlert(x, y, z, radius, name)
    local blip = Citizen.InvokeNative(0x45F13B7E0A15C880, 1664425300,
        x + 0.0, y + 0.0, z + 0.0, (tonumber(radius) or 90.0) + 0.0)
    if not blip then return nil end
    pcall(function() SetBlipSprite(blip, GetHashKey(Config.Missions.alertSprite)) end)
    pcall(function()
        Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey(Config.Missions.alertColor))
    end)
    pcall(function() Citizen.InvokeNative(0x9CB1A1623062F402, blip, tostring(name or 'Alert')) end)
    return blip
end

local function drawPlantAlert(p)
    return drawAlert(p.x, p.y, p.z, Config.Missions.alertRadius, 'Contraband')
end

RegisterNetEvent('pup-gangs:plantStarted', function(p)
    if not p or not p.id then return end
    activePlants[p.id] = p

    -- DEFENDERS get the alert and the circle
    local mine = myGangId
    if mine == p.defender then
        p.blip = drawPlantAlert(p)
        exports['pup-ui']:Toast(Locale.plantDetected)
        exports['pup-ui']:Banner({
            title = 'TERRITORY BREACH',
            text  = ('Contraband planted in %s - find and destroy it'):format(p.territory or 'your ground'),
        })
    elseif mine == p.attacker then
        p.blip = drawPlantAlert(p)
        exports['pup-ui']:Toast(Locale.plantDone)
    end
end)

RegisterNetEvent('pup-gangs:plantEnded', function(info)
    local p = info and activePlants[info.id]
    if not p then return end
    clearPlantBlip(p)
    activePlants[info.id] = nil
    if myGangId == p.defender then
        exports['pup-ui']:Toast(info.destroyed and Locale.plantDestroyed or Locale.plantSurvived)
    elseif myGangId == p.attacker then
        exports['pup-ui']:Toast(info.destroyed and Locale.plantDestroyed or Locale.plantSurvived)
    end
end)

-- plant the package you are carrying, if you are standing in rival ground
function PlantPackage()
    local t = RivalTerritoryHere()
    if not t then return exports['pup-ui']:Toast(Locale.plantNeedRival) end
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('pup-gangs:plantPackage', t.id, c.x, c.y, c.z)
end

-- DENS (level 3+ perk) - own gang sees all of theirs (crate prop + collect prompt)
local denList = { mine = {}, rivals = {}, dens = {}, props = {} }
local denObjs = {}
local activeRaids = {}
local reportedDens = {}   -- fixed dens we have already told the server we are near

-- INSTANCE AWARENESS
-- a den is local props and distance prompts, so while the player is inside ANY instance
-- (bucket ~= 0) the den hides itself completely
local myBucket = 0
local function inInstance() return myBucket ~= 0 end

local function clearDenObjs()
    for _, o in pairs(denObjs) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
    denObjs = {}
end

local function spawnDenProp(th)
    local model = GetHashKey(Config.Dens.prop)
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 100 do tries = tries + 1 Wait(10) end
    if not HasModelLoaded(model) then return end
    local obj = CreateObject(model, th.x + 0.0, th.y + 0.0, th.z + 0.0, false, false, false)
    SetEntityHeading(obj, (tonumber(th.h) or 0.0) + 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    denObjs[#denObjs + 1] = obj
end

local function refreshDens()
    -- inside a hideout instance the den does not exist for this player
    if inInstance() then clearDenObjs() return end
    local res = Core.Callback.TriggerAwait('pup-gangs:getDens')
    denList = (type(res) == 'table') and res or {}
    denList.mine   = denList.mine or {}
    denList.rivals = denList.rivals or {}
    denList.dens   = denList.dens or {}     -- fixed dens THIS gang has found
    denList.props  = denList.props or {}    -- every fixed den's crate, coords only
    clearDenObjs()

    -- a den with a SHACK (`site` set) gets NO crate
    local drawn = {}
    for _, th in ipairs(denList.mine) do
        drawn[th.id] = true
        if not th.site then spawnDenProp(th) end
    end
    for _, th in ipairs(denList.rivals) do spawnDenProp(th) end
    -- fixed-den crates stand in the world for EVERYONE: riding past one is how a gang finds it
    for _, p in ipairs(denList.props) do
        if not drawn[p.id] and not p.site then spawnDenProp(p) end
    end
    dbg('dens:', #denList.mine, 'mine,', #denList.rivals, 'rival,', #denList.dens, 'known den(s)')
end

RegisterNetEvent('pup-gangs:densDirty', function() refreshDens() end)

-- declared here, below refreshDens/clearDenObjs, so the handler can call them
RegisterNetEvent('pup-instance:bucket', function(b)
    myBucket = tonumber(b) or 0
    if inInstance() then clearDenObjs() else refreshDens() end
end)

-- IN-FLIGHT RUN state: the target crew while carrying, then the run home
local myRun = nil

RegisterNetEvent('pup-gangs:runTargeted', function(info)
    myRun = { phase = 'carry', tag = info and info.tag or '?' }
end)

RegisterNetEvent('pup-gangs:runCollect', function(info)
    if not info then return end
    myRun = {
        phase = 'collect',
        x = info.x, y = info.y, z = info.z,
        endAt = GetGameTimer() + (math.max(0, tonumber(info.secondsLeft) or 0) * 1000),
    }
    -- a marker home: the payday is at the den, not where you stand
    myRun.blip = drawAlert(info.x, info.y, info.z, 60.0, 'Get home')
end)

RegisterNetEvent('pup-gangs:runEnded', function()
    if myRun and myRun.blip and DoesBlipExist(myRun.blip) then
        pcall(function() RemoveBlip(myRun.blip) end)
    end
    myRun = nil
end)

-- the run-home countdown
CreateThread(function()
    while true do
        local sleep = 700
        if myRun and myRun.phase == 'collect' then
            sleep = 0
            local left = math.max(0, math.floor(((myRun.endAt or 0) - GetGameTimer()) / 1000))
            drawtext('GET BACK TO THE DEN', 0.5, 0.045, true, 255, 235, 210, 235)
            drawtext(('%02d:%02d'):format(math.floor(left / 60), left % 60), 0.5, 0.080, true, 214, 138, 122, 245)
        end
        Wait(sleep)
    end
end)

-- the panel's Perks tab reads this for its manage list (cached, synchronous)
function GangDensMine() return denList.mine or {} end

-- fixed dens THIS gang has found - owned by anyone or nobody. client/den.lua reads it for the door
function GangDensKnown() return denList.dens or {} end

-- The den prompt GROUP. client/den.lua registers its door prompt into this same group rather than making its own
function GangDenGroup() return denGroup end

-- a den being seized, and a den gone HOT while a batch cooks
local denAlerts = {}   -- [id] = blip

local function clearDenAlert(id)
    if denAlerts[id] and DoesBlipExist(denAlerts[id]) then
        pcall(function() RemoveBlip(denAlerts[id]) end)
    end
    denAlerts[id] = nil
end

RegisterNetEvent('pup-gangs:denSeizeStarted', function(info)
    if not info then return end
    clearDenAlert(info.id)
    denAlerts[info.id] = drawAlert(info.x, info.y, info.z, (tonumber(info.radius) or 60.0), (info.name or 'Den') .. ' - contested')
    exports['pup-ui']:Toast(info.mine and Locale.denSeizing
        or ((info.name or 'A den') .. ' is being taken'), 7000)
end)

RegisterNetEvent('pup-gangs:denSeizeEnded', function(info)
    if not info then return end
    clearDenAlert(info.id)
    if myGangId and info.gangid == myGangId then
        exports['pup-ui']:Toast(info.won and Locale.denTaken or Locale.denLost, 6000)
    end
    refreshDens()
end)

-- COOKING: the den lights up on the map of every crew that knows it
RegisterNetEvent('pup-gangs:denCookStarted', function(info)
    if not info then return end
    clearDenAlert(info.id)
    denAlerts[info.id] = drawAlert(info.x, info.y, info.z, (tonumber(info.radius) or 90.0),
        (info.name or 'Den') .. ' - cooking')
    if myGangId and info.gangid == myGangId then
        exports['pup-ui']:Toast(Locale.cookStarted, 7000)
    else
        exports['pup-ui']:Toast('Somebody is cooking - ' .. (info.name or 'a den'), 6000)
    end
end)

RegisterNetEvent('pup-gangs:denCookEnded', function(info)
    if not info then return end
    clearDenAlert(info.id)
    if myGangId and info.gangid == myGangId then
        exports['pup-ui']:Toast(Locale.cookDone, 5000)
    end
    refreshDens()
end)

RegisterNetEvent('pup-gangs:raidStarted', function(r)
    if not r or not r.id then return end
    activeRaids[r.id] = r
    if myGangId == r.defender then
        r.blip = drawAlert(r.x, r.y, r.z, Config.Dens.alertRadius, 'Den Raid')
        exports['pup-ui']:Toast(Locale.denRaidStarted)
        exports['pup-ui']:Banner({
            title = 'DEN RAID',
            text  = 'Rivals are hitting your den - get there and stop them',
        })
    elseif myGangId == r.attacker then
        r.blip = drawAlert(r.x, r.y, r.z, Config.Dens.alertRadius, 'Raid')
        exports['pup-ui']:Toast(('Hold the spot for %d seconds.'):format(Config.Dens.raidHoldSeconds))
    end
end)

RegisterNetEvent('pup-gangs:raidEnded', function(info)
    if not info then return end
    local r = activeRaids[info.id]
    if r then
        if r.blip and DoesBlipExist(r.blip) then pcall(function() RemoveBlip(r.blip) end) end
        activeRaids[info.id] = nil
    end
    if myGangId == info.defender or myGangId == info.attacker then
        exports['pup-ui']:Toast(info.success and Locale.denRaidWon or Locale.denRaidLost)
    end
end)

-- TERRITORY CLAIMS - the 20-minute siege HUD. Every gang sees a running claim
local activeClaim = nil   -- the claim we are watching (own gang's or one on our ground)
local claimBlip = nil

local function clearClaimBlip()
    if claimBlip and DoesBlipExist(claimBlip) then pcall(function() RemoveBlip(claimBlip) end) end
    claimBlip = nil
end

local function claimRole(c)
    if not myGangId then return nil end
    if c.attacker == myGangId then return 'attacker' end
    if c.defender and c.defender == myGangId then return 'defender' end
    return 'bystander'
end

local function showClaim(c)
    activeClaim = c
    -- convert the server's remaining-seconds into local game-timer deadlines
    c.endAt   = GetGameTimer() + (math.max(0, tonumber(c.secondsLeft) or 0) * 1000)
    c.graceAt = GetGameTimer() + (math.max(0, tonumber(c.graceLeft) or 0) * 1000)
    clearClaimBlip()
    claimBlip = drawAlert(c.x, c.y, c.z, (tonumber(c.radius) or 90.0), 'Contested - ' .. (c.name or 'ground'))
    local role = claimRole(c)
    if role == 'attacker' then
        exports['pup-ui']:Banner({ title = 'CLAIM UNDERWAY', text = 'Hold ' .. (c.name or 'the ground') .. ' until the clock runs out' })
    elseif role == 'defender' then
        exports['pup-ui']:Toast(Locale.claimDefend)
        exports['pup-ui']:Banner({ title = 'GROUND CONTESTED', text = (c.attackerTag or 'A gang') .. ' is moving on ' .. (c.name or 'your ground') })
    else
        exports['pup-ui']:Toast(Locale.claimAlert .. (c.name or 'the frontier'))
    end
end

RegisterNetEvent('pup-gangs:claimStarted', function(c)
    if not c then return end
    showClaim(c)
end)

RegisterNetEvent('pup-gangs:claimEnded', function(info)
    if not info then return end
    if activeClaim and activeClaim.territoryId == info.territoryId then
        activeClaim = nil
        clearClaimBlip()
    end
    if myGangId and info.attacker == myGangId then
        exports['pup-ui']:Toast(info.won and Locale.claimWon or Locale.claimLost, 6000)
    else
        exports['pup-ui']:Toast((info.name or 'Ground') .. (info.won and ' has been taken.' or ' held out.'), 5000)
    end
end)

-- the countdown itself. Two phases: the ride-out grace, then the hold.
CreateThread(function()
    while true do
        local sleep = 700
        if activeClaim then
            sleep = 0
            local now = GetGameTimer()
            local left = math.max(0, math.floor(((activeClaim.endAt or now) - now) / 1000))
            local grace = math.max(0, math.floor(((activeClaim.graceAt or now) - now) / 1000))
            local mins, secs = math.floor(left / 60), left % 60

            local role = claimRole(activeClaim)
            local head
            if role == 'attacker' then head = 'CLAIMING ' .. string.upper(activeClaim.name or '')
            elseif role == 'defender' then head = 'DEFENDING ' .. string.upper(activeClaim.name or '')
            else head = string.upper(activeClaim.name or '') .. ' CONTESTED' end

            drawtext(head, 0.5, 0.045, true, 255, 235, 210, 235)
            drawtext(('%s   %02d:%02d'):format((activeClaim.attackerTag or '?'), mins, secs),
                0.5, 0.080, true, 214, 138, 122, 245)
            if grace > 0 then
                drawtext(('ride out - %ds'):format(grace), 0.5, 0.112, true, 200, 190, 170, 205)
            end
        end
        Wait(sleep)
    end
end)

-- WORLD LOOP
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    local group = setupPrompts()
    Wait(4000)
    refreshTable()

    while true do
        local sleep = 800
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        -- gang table: E opens the panel
        if tableData then
            local d = #(coords - vector3(tableData.x, tableData.y, tableData.z))
            if d <= Config.Table.interactDistance then
                sleep = 0
                -- E opens the gang panel (stashes and everything else live in it)
                local founder = (myGangId == nil)
                PromptSetEnabled(stashPrompt, founder and 1 or 0)
                PromptSetVisible(stashPrompt, founder and 1 or 0)
                local label = CreateVarString(10, 'LITERAL_STRING', Locale.tablePrompt)
                PromptSetActiveGroupThisFrame(group, label)
                if Citizen.InvokeNative(0xC92AC953F0A982AE, tablePrompt) then
                    OpenGangPanel()
                elseif founder and Citizen.InvokeNative(0xC92AC953F0A982AE, stashPrompt) then
                    TriggerServerEvent('pup-gangs:pickupTable')
                end
            end
        end

        -- an active plant you are standing on, and it is YOUR ground to defend
        for id, p in pairs(activePlants) do
            if myGangId == p.defender then
                local d = #(coords - vector3(p.x, p.y, p.z))
                if d <= Config.Missions.destroyDistance then
                    sleep = 0
                    local label = CreateVarString(10, 'LITERAL_STRING', 'Destroy contraband')
                    PromptSetActiveGroupThisFrame(group, label)
                    if Citizen.InvokeNative(0xC92AC953F0A982AE, tablePrompt) then
                        TriggerServerEvent('pup-gangs:destroyPlant', id)
                    end
                end
            end
        end

        -- OWN den: E collects whatever has brewed
        if Config.Dens.enabled and not inInstance() then
            for _, th in ipairs(denList.mine or {}) do
                -- A SHACK DEN HAS NO WORLD PROMPTS AT ALL
                if not th.site then
                local d = #(coords - vector3(th.x, th.y, th.z))
                if d <= Config.Dens.interactDistance then
                    sleep = 0
                    -- carrying a finished run home?
                    local collecting = myRun ~= nil and myRun.phase == 'collect'
                    local label = CreateVarString(10, 'LITERAL_STRING',
                        collecting and 'Den - deliver the run'
                        or ('Den - %d on the shelf'):format(tonumber(th.stored) or 0))
                    -- G is context-sensitive at your own den: start a delivery run, or - if a cook is available - put a batch on
                    local canStart = (myRun == nil)
                    local canCook = th.canCook and not th.cooking and not collecting
                    PromptSetEnabled(denRunPrompt, (canStart or canCook) and 1 or 0)
                    PromptSetVisible(denRunPrompt, (canStart or canCook) and 1 or 0)
                    if canCook and not canStart then
                        PromptSetText(denRunPrompt, CreateVarString(10, 'LITERAL_STRING', 'Start a cook'))
                    elseif canCook then
                        PromptSetText(denRunPrompt, CreateVarString(10, 'LITERAL_STRING', 'Start a cook'))
                    else
                        PromptSetText(denRunPrompt, CreateVarString(10, 'LITERAL_STRING', 'Start a delivery run'))
                    end
                    if th.cooking then
                        label = CreateVarString(10, 'LITERAL_STRING',
                            ('Den - cooking, %dm left'):format(math.ceil((tonumber(th.cookLeft) or 0) / 60)))
                    end
                    PromptSetActiveGroupThisFrame(denGroup, label)
                    if Citizen.InvokeNative(0xC92AC953F0A982AE, denPrompt) then
                        if collecting then
                            TriggerServerEvent('pup-gangs:collectRun')
                        else
                            TriggerServerEvent('pup-gangs:collectDen', th.id)
                        end
                    elseif Citizen.InvokeNative(0xC92AC953F0A982AE, denRunPrompt) then
                        if canCook then
                            TriggerServerEvent('pup-gangs:startCook', th.id)
                        elseif canStart then
                            TriggerServerEvent('pup-gangs:takePackage')
                        end
                    elseif Citizen.InvokeNative(0xC92AC953F0A982AE, denMenuPrompt) then
                        OpenGangPanel('territory', 'den')
                    end
                end
                end
            end
            -- FIXED DENS: riding close enough FINDS one (reported once per den per session)
            for _, p in ipairs(denList.props or {}) do
                local d = #(coords - vector3(p.x, p.y, p.z))
                if d <= (Config.Dens.discovery.discoverDistance or 35.0) then
                    if not reportedDens[p.id] then
                        reportedDens[p.id] = true
                        TriggerServerEvent('pup-gangs:denNearby', p.id)
                    end
                end
            end

            -- a known fixed den you are standing at; with seizing off (Config.Dens.seize.enabled = false) the way in is the KEY
            local canSeize = Config.Dens.seize and Config.Dens.seize.enabled
            for _, den in ipairs(denList.dens or {}) do
                if canSeize or not den.unowned then
                    local d = #(coords - vector3(den.x, den.y, den.z))
                    if d <= Config.Dens.interactDistance + 1.0 then
                        sleep = 0
                        local label
                        if den.contested then
                            label = ('%s - being taken'):format(den.label or 'Den')
                        elseif den.unowned then
                            label = ('%s - seize it'):format(den.label or 'Den')
                        else
                            label = ('%s - held by %s'):format(den.label or 'Den', den.holder or '?')
                        end
                        PromptSetActiveGroupThisFrame(denGroup, CreateVarString(10, 'LITERAL_STRING', label))
                        if canSeize and den.unowned and not den.contested
                            and Citizen.InvokeNative(0xC92AC953F0A982AE, denPrompt) then
                            TriggerServerEvent('pup-gangs:seizeDen', den.id)
                        end
                    end
                end
            end

            -- RIVAL den (only visible while stocked): E starts the raid
            for _, th in ipairs(denList.rivals or {}) do
                local d = #(coords - vector3(th.x, th.y, th.z))
                if d <= Config.Dens.interactDistance + 1.0 then
                    sleep = 0
                    local label = CreateVarString(10, 'LITERAL_STRING',
                        ('Rival Den [%s] - raid it'):format(th.short ~= '' and th.short or '?'))
                    PromptSetActiveGroupThisFrame(denGroup, label)
                    if Citizen.InvokeNative(0xC92AC953F0A982AE, denPrompt) then
                        TriggerServerEvent('pup-gangs:startRaid', th.id)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- keep the local gang id current so the plant alerts know which side we are on
RegisterNetEvent('pup-gangs:refresh', function()
    CreateThread(function()
        local d = Core.Callback.TriggerAwait('pup-gangs:getPanel')
        myGangId = (type(d) == 'table' and d.hasGang) and d.id or nil
    end)
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    Wait(5000)
    local d = Core.Callback.TriggerAwait('pup-gangs:getPanel')
    myGangId = (type(d) == 'table' and d.hasGang) and d.id or nil
    for _, p in ipairs(Core.Callback.TriggerAwait('pup-gangs:getPlants') or {}) do
        activePlants[p.id] = p
        if myGangId == p.defender or myGangId == p.attacker then
            p.blip = drawPlantAlert(p)
        end
    end
    if Config.Dens.enabled and myGangId then refreshDens() end
    -- a siege may already be running when we join: pick it up mid-flight
    if Config.Claims.enabled then
        for _, c in ipairs(Core.Callback.TriggerAwait('pup-gangs:getClaims') or {}) do
            showClaim(c)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    despawnTable()
    clearDenObjs()
    clearClaimBlip()
    for id in pairs(denAlerts) do clearDenAlert(id) end
    for _, p in pairs(activePlants) do clearPlantBlip(p) end
    for _, r in pairs(activeRaids) do
        if r.blip and DoesBlipExist(r.blip) then pcall(function() RemoveBlip(r.blip) end) end
    end
end)
