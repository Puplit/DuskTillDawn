-- pup-events | THE PURGE: loot caches, client half.
-- Blips and crates exist only while the purge is live.

local promptGroup <const> = GetRandomIntInRange(0, 0xffffff)
local prompt
local activeKey = nil   -- the one cache currently out
local busy = false
local blips, props = {}, {}

local PICK_DICT <const> = 'script_proc@rustling@olar@player_picklock'

local function startPickAnim()
    RequestAnimDict(PICK_DICT)
    local waited = 0
    while not HasAnimDictLoaded(PICK_DICT) and waited < 5000 do
        Wait(100)
        waited = waited + 100
    end
    if not HasAnimDictLoaded(PICK_DICT) then return end
    TaskPlayAnim(PlayerPedId(), PICK_DICT, 'base', 8.0, 8.0, 120000, 31, 0, true, 0, false, 0, false)
end

local function stopPickAnim()
    ClearPedTasksImmediately(PlayerPedId())
    ClearPedSecondaryTask(PlayerPedId())
    RemoveAnimDict(PICK_DICT)
    FreezeEntityPosition(PlayerPedId(), false)
end

-- the lock, then the lid. The bar is the window where you need cover.
local function pryOpen(key, pryTime)
    exports['pup-ui']:Progress({ label = Locale.purgeCaches.prying, duration = pryTime }, function()
        stopPickAnim()
        busy = false
        TriggerServerEvent('pup-events:purgeloot:result', key, true)
    end)
end

local function failed(key)
    stopPickAnim()
    busy = false
    TriggerServerEvent('pup-events:purgeloot:result', key, false)
end

RegisterNetEvent('pup-events:purgeloot:begin', function(key, game, difficulty, pryTime)
    if busy then return end
    busy = true

    TaskStandStill(PlayerPedId(), -1)
    FreezeEntityPosition(PlayerPedId(), true)
    startPickAnim()

    -- the pin-and-tension game the underground raids use. Blocking export, so it
    -- runs on its own thread; safe_crack stands in if the resource is down.
    if game == 'lockpick' then
        if GetResourceState('lockpick') == 'started' then
            CreateThread(function()
                local lok, res = pcall(function() return exports.lockpick:lockpick() end)
                if lok and res == true then pryOpen(key, pryTime) else failed(key) end
            end)
            return
        end
        game = 'safe_crack'
    end

    -- no minigame configured: straight to the bar
    if not game or GetResourceState('pup-minigames') ~= 'started' then
        return pryOpen(key, pryTime)
    end

    -- some games read timer rather than difficulty, so derive one from the other
    local timer <const> = math.max(15000, 70000 - (difficulty * 10000))
    local ok = pcall(function()
        exports['pup-minigames'][game](exports['pup-minigames'], {
            style      = 'default',
            difficulty = difficulty,
            timer      = timer,
        }, function(success)
            if success then pryOpen(key, pryTime) else failed(key) end
        end)
    end)
    if not ok then
        -- a game name that is not one of pup-minigames' exports
        print('^1[pup-events]^7 purge cache minigame "' .. tostring(game) .. '" is not available')
        pryOpen(key, pryTime)
    end
end)

local function clearWorld()
    for i, b in pairs(blips) do
        RemoveBlip(b)
        blips[i] = nil
    end
    for i, p in pairs(props) do
        if DoesEntityExist(p) then DeleteEntity(p) end
        props[i] = nil
    end
end

local function buildWorld()
    clearWorld()

    local model = Config.PurgeCaches.prop and GetHashKey(Config.PurgeCaches.prop) or nil
    -- checked first: a bad prop name otherwise stalls every spawn for 5s
    if model and not IsModelValid(model) then
        print(('^1[pup-events]^7 purge crate prop does not exist: %s'):format(tostring(Config.PurgeCaches.prop)))
        model = nil
    end
    if model then
        RequestModel(model)
        local waited = 0
        while not HasModelLoaded(model) and waited < 5000 do
            Wait(100)
            waited = waited + 100
        end
        if not HasModelLoaded(model) then model = nil end
    end

    for i, site in ipairs(Config.PurgeCaches.sites or {}) do
      if site.key == activeKey and PurgeLootConfigured(site) then
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, site.pos.x, site.pos.y, site.pos.z)
        SetBlipSprite(blip, Config.PurgeCaches.blip.sprite, 1)
        SetBlipScale(blip, Config.PurgeCaches.blip.scale or 0.2)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, site.label or Locale.purgeCaches.group)
        blips[i] = blip

        if model then
            local p = CreateObject(model, site.pos.x, site.pos.y, site.pos.z, false, false, false, false)
            if p and p ~= 0 then
                -- MLO: the snap would drop it to the terrain under the building
                if site.snapToGround ~= false then PlaceObjectOnGroundProperly(p) end
                if site.heading then SetEntityHeading(p, site.heading + 0.0) end
                FreezeEntityPosition(p, true)
                SetEntityCanBeDamaged(p, false)
                props[i] = p
            end
        end
      end
    end
    if model then SetModelAsNoLongerNeeded(model) end
end

-- guards, only on the client the server picked: random outfit first or it renders untextured, then the anti-cheap-kill flags
local guards = {}     -- key -> { ped, ... }
local claimed = {}    -- key -> true, so we only ask once

local function guardCfg(site)
    local d <const> = Config.PurgeCaches.guardDefaults or {}
    local g <const> = site.guards or {}
    return {
        count   = math.floor(tonumber(g.count) or tonumber(d.count) or 6),
        radius  = tonumber(g.radius) or tonumber(d.radius) or 20.0,
        trigger = tonumber(g.trigger) or tonumber(d.trigger) or 80.0,
        models  = g.models or d.models or {},
        weapons = g.weapons or d.weapons or {},
    }
end

local function dropGuards(key)
    for _, ped in ipairs(guards[key] or {}) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    guards[key] = nil
    claimed[key] = nil
end

local function dropAllGuards()
    for key in pairs(guards) do dropGuards(key) end
    guards, claimed = {}, {}
end

RegisterNetEvent('pup-events:purgeloot:spawnguards', function(key)
    local site
    for _, s in ipairs(Config.PurgeCaches.sites or {}) do
        if tostring(s.key) == tostring(key) then site = s break end
    end
    if not site or guards[key] then return end

    local cfg <const> = guardCfg(site)
    if #cfg.models == 0 then return end
    guards[key] = {}

    SetRelationshipBetweenGroups(5, `PLAYER`, `bandits`)
    SetRelationshipBetweenGroups(5, `bandits`, `PLAYER`)

    for i = 1, cfg.count do
        local name <const> = cfg.models[math.random(#cfg.models)]
        local model <const> = GetHashKey(name)
        if IsModelValid(model) then
            RequestModel(model)
            local waited = 0
            while not HasModelLoaded(model) and waited < 5000 do
                Wait(50)
                waited = waited + 50
            end
            if HasModelLoaded(model) then
                -- posted around the crate rather than stacked on it
                local ang <const> = (i / cfg.count) * math.pi * 2.0
                local dist <const> = cfg.radius * (0.4 + math.random() * 0.6)
                local x <const> = site.pos.x + math.cos(ang) * dist
                local y <const> = site.pos.y + math.sin(ang) * dist

                local ped = CreatePed(model, x, y, site.pos.z, math.random(0, 359) + 0.0, true, 0)
                if ped and ped ~= 0 and DoesEntityExist(ped) then
                    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)   -- random outfit, or it renders bald
                    local rendered = 0
                    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and rendered < 3000 do
                        Wait(200)
                        rendered = rendered + 200
                    end
                    SetEntityVisible(ped, true, false)
                    SetEntityCollision(ped, true, true)
                    SetPedCanRagdoll(ped, false)
                    PlaceObjectOnGroundProperly(ped)
                    -- no cheap one-hit kills
                    SetPedConfigFlag(ped, 263, true)
                    SetPedConfigFlag(ped, 169, true)
                    SetPedConfigFlag(ped, 340, true)

                    local weapon <const> = cfg.weapons[math.random(math.max(1, #cfg.weapons))]
                    if weapon then GiveWeaponToPed(ped, GetHashKey(weapon), 250, true, true) end

                    -- the group vorp_outlaws uses; 5 is hate, both ways
                    SetPedRelationshipGroupHash(ped, `bandits`)
                    SetPedCombatAttributes(ped, 46, true)   -- will fight rather than flee
                    SetPedCombatAttributes(ped, 5, true)
                    SetBlockingOfNonTemporaryEvents(ped, false)
                    SetPedAccuracy(ped, 40)
                    TaskCombatPed(ped, PlayerPedId(), 0, 16)

                    NetworkRegisterEntityAsNetworked(ped)
                    guards[key][#guards[key] + 1] = ped
                end
                SetModelAsNoLongerNeeded(model)
            end
        end
    end

    -- hand the ids back so the server can bin them when the purge ends
    local ids = {}
    for _, ped in ipairs(guards[key]) do
        local netId = NetworkGetNetworkIdFromEntity(ped)
        if netId and netId ~= 0 then
            Citizen.InvokeNative(0x299EEB23175895FC, netId, true)   -- let it migrate
            ids[#ids + 1] = netId
        end
    end
    TriggerServerEvent('pup-events:purgeloot:guardnets', key, ids)
end)

-- ask for the job when we get close to a defended cache
CreateThread(function()
    while true do
        local sleep = 2000
        if activeKey then
            local here <const> = GetEntityCoords(PlayerPedId())
            for _, site in ipairs(Config.PurgeCaches.sites or {}) do
                if site.key == activeKey and site.guards and PurgeLootConfigured(site) and not claimed[site.key] then
                    local cfg <const> = guardCfg(site)
                    if #(here - site.pos) <= cfg.trigger then
                        claimed[site.key] = true
                        TriggerServerEvent('pup-events:purgeloot:claim', site.key)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    Wait(1000)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.Keys.purgeCache)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', Locale.purgeCaches.prompt))
    PromptSetEnabled(prompt, 1)
    PromptSetVisible(prompt, 1)
    PromptSetStandardMode(prompt, 1)
    PromptSetGroup(prompt, promptGroup)
    PromptRegisterEnd(prompt)
end)

RegisterNetEvent('pup-events:purgeloot:active', function(key)
    if Config.PurgeCaches.enabled == false then return end
    activeKey = key
    clearWorld()
    dropAllGuards()
    if activeKey then buildWorld() end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if activeKey and prompt then
            local here <const> = GetEntityCoords(PlayerPedId())
            local reach <const> = tonumber(Config.PurgeCaches.distance) or 2.0
            for _, site in ipairs(Config.PurgeCaches.sites or {}) do
                if site.key == activeKey and PurgeLootConfigured(site) and #(here - site.pos) <= reach then
                    sleep = 0
                    -- rebuilt every frame: a cached VarString points into a buffer
                    -- the game reuses, so the header shows whatever wrote there last
                    PromptSetActiveGroupThisFrame(promptGroup,
                        CreateVarString(10, 'LITERAL_STRING', site.label or Locale.purgeCaches.group))
                    if PromptHasStandardModeCompleted(prompt) and not busy then
                        TriggerServerEvent('pup-events:purgeloot:try', site.key)
                        Wait(600)
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearWorld()
    dropAllGuards()
end)

-- vorp_admin world cleanup: guards staff deleted are forgotten, and the cache may be claimed
-- again (the server freed it) so they come back when someone rides up. The crate is local and stays.
RegisterNetEvent('vorp_admin:worldCleanupDone', function()
    for key in pairs(claimed) do
        local any = false
        for _, ped in ipairs(guards[key] or {}) do
            if DoesEntityExist(ped) then any = true break end
        end
        if not any then
            guards[key] = nil
            claimed[key] = nil
        end
    end
end)
