-- pup_robbery | the fence, client side: his ped, his prompt, his menu, and /markjob

local F = Config.Fence
local MENU = 'pup_robbery:fence'

local spot = nil      -- { pos, heading, prompt }
local ped = nil
local prompt = nil
local lastPress = 0
local rows = {}       -- menu index -> action
local jobBlip = nil
local jobBlipToken = 0

--------------------------------------------------------------------------------
-- his ped

local function removePed()
    if ped and DoesEntityExist(ped) then DeletePed(ped) end
    ped = nil
end

local function spawnPed()
    removePed()
    if not F.npc.enabled or not spot then return end
    local hash = C.loadModel(F.npc.model, 5000) or C.loadModel(F.npc.fallbackModel, 5000)
    if not hash then return end
    local pos = C.v3(spot.pos)
    ped = CreatePed(hash, pos.x, pos.y, pos.z - F.npc.sinkMetres, spot.heading or 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then ped = nil return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- random outfit
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, spot.heading or 0.0)
end

local function promptPoint()
    if not spot then return nil end
    return C.v3(spot.prompt or spot.pos)
end

RegisterNetEvent('pup_robbery:fence:spot', function(s)
    if type(s) ~= 'table' then return end
    spot = s
    if LocalPlayer.state.IsInSession then spawnPed() end
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    for _ = 1, F.whereRetries do
        if spot then break end
        local s = C.cb('pup_robbery:fence:where')
        if type(s) == 'table' then spot = s break end
        Wait(F.whereRetryMs)
    end
    spawnPed()
end)

--------------------------------------------------------------------------------
-- the job blip (/markjob)

local function dropJobBlip()
    jobBlipToken = jobBlipToken + 1
    if jobBlip then C.removeBlip(jobBlip) end
    jobBlip = nil
    pcall(function()
        SetGpsMultiRouteRender(false)
        ClearGpsMultiRoute()
    end)
end

local function markJob()
    local ok, posse = pcall(function() return exports['pup-ui']:GetPosseLocal() end)
    local task = ok and type(posse) == 'table' and posse.task or nil
    if not task then return C.tip(L('noJob')) end
    local pos, label = nil, nil
    local bankId = tostring(task):match('^heist:(.+)$')
    if bankId and Config.Banks[bankId] then
        pos, label = Config.Banks[bankId].anchor, Config.Banks[bankId].label
    elseif Config.Places[task] then
        pos, label = Config.Places[task].anchor, task
    end
    if not pos then return C.tip(L('noJob')) end
    dropJobBlip()
    jobBlip = C.blipAt(pos, Config.Walkup.placeBlip.sprite, 0.9, L('jobBlip', label))
    if jobBlip then pcall(SetBlipAsShortRange, jobBlip, false) end
    pcall(function()
        local me = C.myPos()
        StartGpsMultiRoute(GetHashKey('COLOR_YELLOW'), true, true)
        AddPointToGpsMultiRoute(me.x, me.y, me.z, false)
        AddPointToGpsMultiRoute(pos.x, pos.y, pos.z, false)
        SetGpsMultiRouteRender(true)
    end)
    local token = jobBlipToken
    SetTimeout(F.jobs.blipMinutes * 60000, function()
        if token == jobBlipToken then dropJobBlip() end
    end)
end

RegisterCommand('markjob', markJob, false)

RegisterNetEvent('pup_robbery:fence:jobDropped', function()
    dropJobBlip()
end)

--------------------------------------------------------------------------------
-- the menu

local function openStall()
    if GetResourceState('pup_mercantile') ~= 'started' then return C.tip(L('stallPacked')) end
    local ok, id = pcall(function() return exports.pup_mercantile:StoreIdByName(F.stall.storeName) end)
    if not ok or not id then return C.tip(L('stallPacked')) end
    TriggerServerEvent('pup_mercantile:reloadStoreInventory', id)
end

local function seedOrder()
    if GetResourceState('pup-gangs') ~= 'started' then return nil end
    -- bounded wait: a callback that never answers must not keep the whole menu from opening
    local r = C.cbWithin(2000, 'pup-gangs:getSeedOrder')
    if type(r) == 'table' and (tonumber(r.count) or 0) > 0 then return r end
    return nil
end

local function openMenu()
    local data = C.cb('pup_robbery:fence:menu')
    if type(data) ~= 'table' then return end
    if data.gone then return C.tip(L('fenceGone')) end
    if data.brush then return C.tip(data.brush, 6000) end

    rows = {}
    local options = {}
    local function add(action, label, desc, disabled)
        options[#options + 1] = { label = label, desc = desc, disabled = disabled == true }
        rows[#options] = action
    end

    if data.standing then
        local s = data.standing
        local desc
        if s.keepsNothing then desc = L('standingNothing')
        elseif s.next then desc = L('standingNext', s.rep, s.keeps, s.next, s.nextAt)
        else desc = L('standingTop', s.rep, s.keeps) end
        add(nil, L('standing', s.level), desc, true)
    end

    if data.inPosse and data.task then
        add('mark', L('whereJob'), L('whereJobDesc'))
        if data.isLeader then add('walkAway', L('walkAway'), L('walkAwayDesc')) end
    elseif data.inPosse and data.isLeader then
        add('ask', L('askWork'), L('askWorkDesc'))
    elseif not data.inPosse then
        add(nil, L('askWork'), L('askWorkNoPosse', data.posseCommand or Config.PosseCommand), true)
    end

    if data.buyer then
        add('crate', L('sellTake'), L('sellTakeDesc'))
        if data.crateHasItems then add('offer', L('makeOffer'), L('makeOfferDesc')) end
    end

    if data.payout then
        if data.payout.ready then add('collect', L('collect', data.payout.amount), L('collectDesc'))
        else add(nil, L('onItsWay'), L('onItsWayDesc', data.payout.minutes), true) end
    end

    if data.gangs then
        local seed = seedOrder()
        if seed then add('seed', L('seed', tonumber(seed.count) or 0), L('seedDesc', tostring(seed.label or ''))) end
    end

    if data.stall then add('stall', L('stall'), L('stallDesc')) end

    local menu = { owner = MENU, title = L('fenceTitle'), options = options, keyboard = true }
    if data.sin then
        menu.subtitle = data.sin.text
        menu.subtitleIcon = data.sin.icon
    end
    local ok = pcall(function() exports['pup-ui']:OpenListMenu(menu) end)
    if not ok then C.tip(L('posseService')) end
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= MENU then return end
    local action = rows[tonumber(index) or 0]
    rows = {}
    if action == 'mark' then markJob()
    elseif action == 'walkAway' then TriggerServerEvent('pup_robbery:fence:walkAway')
    elseif action == 'ask' then TriggerServerEvent('pup_robbery:fence:askWork')
    elseif action == 'crate' then TriggerServerEvent('pup_robbery:fence:openCrate')
    elseif action == 'offer' then TriggerServerEvent('pup_robbery:fence:offer')
    elseif action == 'collect' then TriggerServerEvent('pup_robbery:fence:collect')
    elseif action == 'seed' then TriggerServerEvent('pup-gangs:drugCollectSeed')
    elseif action == 'stall' then openStall()
    end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= MENU then return end
    rows = {}
end)

--------------------------------------------------------------------------------
-- the prompt

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    prompt = C.makePrompt(F.npc.promptGroup, F.npc.promptText, Config.InteractKey)
    while true do
        local sleep = 1000
        local point = promptPoint()
        if point and F.npc.enabled then
            local d = #(C.myPos() - point)
            if d < 25.0 then sleep = 250 end
            if d <= F.npc.promptRange and not C.dead() then
                sleep = 0
                C.showPrompt(prompt)
                if C.promptPressed(prompt) and GetGameTimer() - lastPress > F.npc.pressThrottleMs then
                    lastPress = GetGameTimer()
                    CreateThread(openMenu)
                end
            end
        end
        Wait(sleep)
    end
end)

--------------------------------------------------------------------------------
-- admin: turn him to face the way you face (checked on the server)

RegisterCommand('fenceface', function()
    TriggerServerEvent('pup_robbery:fence:face', GetEntityHeading(PlayerPedId()))
end, false)

function FenceClient_cleanup()
    removePed()
    dropJobBlip()
    if prompt then C.dropPrompt(prompt) end
    prompt = nil
end
