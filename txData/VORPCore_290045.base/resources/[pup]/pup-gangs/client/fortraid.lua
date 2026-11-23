-- pup-gangs | client/fortraid.lua: the world half of the fort raid - spawns the locals, watches them die, draws the HUD

local Core = exports.vorp_core:GetCore()

local function dbg(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-gangs]^7 " .. table.concat(parts, " "))
end

local raid = nil        -- { index, label, x, y, z, waves, stage, wave }
local spawned = {}      -- peds this client created
local bossPed = nil
local lootObj = nil
local lootReady = false
local lootPrompt, lootGroup

-- waits up to 10 s (200 x 50 ms) for the model before giving up
local function loadModel(hash)
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 200 do tries = tries + 1 Wait(50) end
    if not HasModelLoaded(hash) then
        print(('^1[pup-gangs]^7 fort raid: model %s never loaded'):format(tostring(hash)))
        return false
    end
    return true
end

-- CHECK THE MODEL NAMES AT BOOT, not mid-raid
CreateThread(function()
    Wait(8000)
    if not Config.FortRaid or not Config.FortRaid.enabled then return end
    local bad = {}
    local function check(name)
        if not name or name == '' then return end
        if not IsModelInCdimage(GetHashKey(name)) then bad[name] = true end
    end
    for _, w in ipairs(Config.FortRaid.waves or {}) do
        for _, m in ipairs(w.models or {}) do check(m) end
    end
    check((Config.FortRaid.boss or {}).model)

    local list = {}
    for n in pairs(bad) do list[#list + 1] = n end
    if #list > 0 then
        table.sort(list)
        print(('^1[pup-gangs]^7 fort raid: %d model(s) DO NOT EXIST and will never spawn: ^1%s^7')
            :format(#list, table.concat(list, ', ')))
    else
        dbg('fort raid models all present')
    end
end)

local function cleanupPeds()
    for _, ped in ipairs(spawned) do
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end
    spawned = {}
    if bossPed and DoesEntityExist(bossPed) then
        SetEntityAsMissionEntity(bossPed, true, true)
        DeleteEntity(bossPed)
    end
    bossPed = nil
end

-- the game's own countdown, owned by vorp_core. Another job's clock can be up already, in which case
-- this one just doesn't show; the box still opens on time.
local clockOn = false

local function stopClock()
    if clockOn then
        clockOn = false
        pcall(function() exports.vorp_core:TimerStop() end)
    end
end

local function runClock(seconds)
    local forRaid = raid
    local endsAt = GetGameTimer() + seconds * 1000
    local red = tonumber(Config.FortRaid.timerRedSeconds) or 30
    forRaid.boxOpensAt = endsAt

    local ok, started = pcall(function() return exports.vorp_core:TimerStart(seconds, red) end)
    clockOn = ok and started == true

    CreateThread(function()
        while raid == forRaid and GetGameTimer() < endsAt do
            Wait(1000)
            if clockOn and raid == forRaid then
                pcall(function() exports.vorp_core:TimerUpdate(math.ceil((endsAt - GetGameTimer()) / 1000), red) end)
            end
        end
        if raid == forRaid then
            stopClock()
            exports['pup-ui']:Toast(Locale.fortBoxOpen, 5000)
        end
    end)
end

local function cleanupAll()
    stopClock()
    cleanupPeds()
    if lootObj and DoesEntityExist(lootObj) then DeleteObject(lootObj) end
    lootObj = nil
    lootReady = false
    if raid and raid.blip and DoesBlipExist(raid.blip) then
        pcall(function() RemoveBlip(raid.blip) end)
    end
    raid = nil
end

-- One hostile local
local function spawnFighter(model, weapon, x, y, z, health, accuracy)
    local hash = GetHashKey(model)
    if not loadModel(hash) then return nil end

    local ped, tries = 0, 0
    while not DoesEntityExist(ped) do
        ped = CreatePed(hash, x, y, z, 0.0, true, 0)
        tries = tries + 1
        Wait(300)
        if tries > 10 then break end
    end
    if not DoesEntityExist(ped) then
        print(('^1[pup-gangs]^7 fort raid: could not create ped %s'):format(tostring(model)))
        return nil
    end

    -- dress it, then WAIT for it to actually render before anything else
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    local renderWait = 0
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and renderWait < 3000 do
        Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
        Wait(200)
        renderWait = renderWait + 200
    end

    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetPedCanRagdoll(ped, false)
    PlaceObjectOnGroundProperly(ped)

    -- no cheap kills
    SetPedConfigFlag(ped, 263, true)
    SetPedConfigFlag(ped, 169, true)
    SetPedConfigFlag(ped, 340, true)

    SetEntityAsMissionEntity(ped, true, true)
    SetModelAsNoLongerNeeded(hash)

    local wHash <const> = GetHashKey(weapon)
    SetPedCombatAttributes(ped, 46, true)
    GiveWeaponToPed(ped, wHash, 1000, false, true)
    SetCurrentPedWeapon(ped, wHash, true)
    SetEntityHealth(ped, health or 200, 0)
    SetPedCombatMovement(ped, 2)
    SetPedAccuracy(ped, accuracy or 40)
    SetPedCombatAttributes(ped, 5,  true)   -- CA_ALWAYS_FIGHT
    SetPedCombatAttributes(ped, 17, false)  -- disable CA_ALWAYS_FLEE
    SetPedCombatAttributes(ped, 58, true)   -- CA_DISABLE_FLEE_FROM_COMBAT

    TaskCombatPed(ped, PlayerPedId(), 0, 16)
    dbg('spawned', model, 'hp', health or 200, 'acc', accuracy or 40)
    return ped
end

-- a point on the ring around the fort centre, scattered
local function ringPoint(cx, cy, cz, radius, i, total)
    local ang = (math.pi * 2.0) * (i / math.max(1, total))
        + ((math.random() - 0.5) * 0.35)
    local rad = radius + ((math.random() - 0.5) * (radius * 0.30))
    local x, y = cx + math.cos(ang) * rad, cy + math.sin(ang) * rad
    local ok, gz = GetGroundZFor_3dCoord(x, y, cz + 25.0, false)
    return x, y, (ok and gz or cz)
end

-- ARMED: called from the den, not yet begun
RegisterNetEvent('pup-gangs:fortRaidArmed', function(info)
    if not info then return end
    raid = { index = info.index, label = info.label, x = info.x, y = info.y, z = info.z,
             waves = 0, stage = 'armed', wave = 0, armed = true }
    raid.blip = Citizen.InvokeNative(0x45F13B7E0A15C880, 1664425300,
        info.x + 0.0, info.y + 0.0, info.z + 0.0, (Config.FortRaid.arenaRadius or 120.0) + 0.0)
    if raid.blip then
        pcall(function()
            Citizen.InvokeNative(0x662D364ABF16DE2F, raid.blip, GetHashKey('BLIP_MODIFIER_MP_COLOR_32'))
        end)
        pcall(function()
            Citizen.InvokeNative(0x9CB1A1623062F402, raid.blip, (info.label or 'Fort') .. ' - ride out')
        end)
    end
    exports['pup-ui']:Banner({
        title = 'RIDE ON ' .. string.upper(info.label or ''),
        text  = ('It starts when %d of you are inside the fort. %d minutes.')
            :format(tonumber(info.crew) or 1, tonumber(info.minutes) or 5),
    })
    dbg('raid ARMED on', info.label)
end)

RegisterNetEvent('pup-gangs:fortRaidStarted', function(info)
    if not info then return end
    -- clear the ARMED marker before drawing the live one, or the fort ends up with two circles on it for the rest of the raid
    if raid and raid.blip and DoesBlipExist(raid.blip) then
        pcall(function() RemoveBlip(raid.blip) end)
    end
    raid = { index = info.index, label = info.label, x = info.x, y = info.y, z = info.z,
             waves = info.waves, stage = 'wave', wave = 1 }
    raid.blip = Citizen.InvokeNative(0x45F13B7E0A15C880, 1664425300,
        info.x + 0.0, info.y + 0.0, info.z + 0.0, (Config.FortRaid.arenaRadius or 120.0) + 0.0)
    if raid.blip then
        pcall(function()
            Citizen.InvokeNative(0x662D364ABF16DE2F, raid.blip, GetHashKey('BLIP_MODIFIER_MP_COLOR_2'))
        end)
        pcall(function() Citizen.InvokeNative(0x9CB1A1623062F402, raid.blip, info.label .. ' - raid') end)
    end
    exports['pup-ui']:Banner({ title = 'RAID: ' .. string.upper(info.label or ''),
                               text = 'Clear the locals off the fort' })
    local minSeconds = tonumber(info.minSeconds) or 0
    if minSeconds > 0 then runClock(minSeconds) end
end)

-- the prompt finished before the server's clock did
RegisterNetEvent('pup-gangs:fortBoxStillShut', function()
    if raid and raid.lootX then lootReady = true end
    exports['pup-ui']:Toast(Locale.fortBoxShut, 5000)
end)

-- LEADER ONLY: bring a wave in
RegisterNetEvent('pup-gangs:fortSpawnWave', function(info)
    if not info or not info.cfg then return end
    local cfg = info.cfg
    CreateThread(function()
        local made = 0
        for i = 1, (cfg.count or 3) do
            local model  = cfg.models[math.random(#cfg.models)]
            local weapon = cfg.weapons[math.random(#cfg.weapons)]
            local x, y, z = ringPoint(info.x, info.y, info.z, cfg.spawnRadius or 45.0, i, cfg.count or 3)
            local ped = spawnFighter(model, weapon, x, y, z, cfg.health, cfg.accuracy)
            if ped then
                spawned[#spawned + 1] = ped
                made = made + 1
            end
            -- no artificial delay: spawnFighter already yields while the model loads and the ped renders
        end
        dbg('spawned wave', info.wave, '-', made, 'of', cfg.count or 3)
        -- tell the server how many actually came out: it set alive = count up front, so a ped
        -- that failed to spawn would leave the wave waiting for a kill that never comes
        TriggerServerEvent('pup-gangs:fortWaveSpawned', info.index, info.wave, made)
    end)
end)

RegisterNetEvent('pup-gangs:fortSpawnBoss', function(info)
    if not info or not info.cfg then return end
    local cfg = info.cfg
    CreateThread(function()
        local x, y, z = ringPoint(info.x, info.y, info.z, 12.0, 1, 1)
        bossPed = spawnFighter(cfg.model, cfg.weapon, x, y, z, cfg.health, cfg.accuracy)
        if bossPed and cfg.armour then
            -- soaks a lucky headshot; a crew still puts him down
            Citizen.InvokeNative(0x1E82C2FF8B12A730, bossPed, true) -- SetPedSuffersCriticalHits(false)
        end
        dbg('boss spawned')
    end)
end)

RegisterNetEvent('pup-gangs:fortWave', function(info)
    if not raid or not info then return end
    raid.stage = 'wave'
    raid.wave = info.wave
    exports['pup-ui']:Toast(('Wave %d of %d'):format(info.wave, info.total or 0), 5000)
end)

RegisterNetEvent('pup-gangs:fortWaveCleared', function(info)
    if not raid then return end
    exports['pup-ui']:Toast(('Wave clear - next in %ds'):format((info and info.nextIn) or 12), 5000)
end)

RegisterNetEvent('pup-gangs:fortBoss', function(info)
    if not raid then return end
    raid.stage = 'boss'
    exports['pup-ui']:Banner({ title = 'THE BOSS', text = (info and info.name) or 'Put him down' })
end)

RegisterNetEvent('pup-gangs:fortLoot', function(info)
    if not raid or not info then return end
    raid.stage = 'loot'
    raid.lootX, raid.lootY, raid.lootZ = info.x, info.y, info.z
    lootReady = true
    local hash = GetHashKey(info.prop or 'p_chestmetal01x')
    if loadModel(hash) then
        lootObj = CreateObject(hash, info.x + 0.0, info.y + 0.0, info.z + 0.0, false, false, false)
        PlaceObjectOnGroundProperly(lootObj)
        FreezeEntityPosition(lootObj, true)
        SetModelAsNoLongerNeeded(hash)
    end
    exports['pup-ui']:Banner({ title = 'THE STRONGBOX', text = 'Crack it before the law comes looking' })
end)

RegisterNetEvent('pup-gangs:fortRaidEnded', function(info)
    if info and info.won then
        exports['pup-ui']:Toast(Locale.fortWon, 6000)
    elseif raid then
        exports['pup-ui']:Toast(Locale.fortLost, 6000)
    end
    cleanupAll()
end)

RegisterNetEvent('pup-gangs:fortAbandoned', function()
    exports['pup-ui']:Toast(Locale.fortAbandoned, 6000)
end)

RegisterNetEvent('pup-gangs:fortCleanup', function() cleanupPeds() end)

-- vorp_admin world cleanup: staff are about to delete the locals. Forget them first so the
-- deletion is not reported as kills; the server sends the stage again once the sweep is done.
RegisterNetEvent('vorp_admin:worldCleanup', function()
    spawned = {}
    bossPed = nil
end)

-- the leader left and took his peds with him; the server is respawning this stage
RegisterNetEvent('pup-gangs:fortLeaderLeft', function()
    cleanupPeds()
    TriggerEvent('vorp:TipRight', 'Your raid leader is gone. Hold the fort.', 6000)
end)

-- watch our own spawned peds and report kills (leader only: `spawned` is empty on every other client)
CreateThread(function()
    while true do
        Wait(1000)
        if raid and #spawned > 0 then
            for i = #spawned, 1, -1 do
                local ped = spawned[i]
                if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
                    table.remove(spawned, i)
                    TriggerServerEvent('pup-gangs:fortKill', raid.index, false)
                    if DoesEntityExist(ped) then
                        SetTimeout(20000, function()
                            if DoesEntityExist(ped) then DeleteEntity(ped) end
                        end)
                    end
                end
            end
        end
        if raid and bossPed and (not DoesEntityExist(bossPed) or IsPedDeadOrDying(bossPed, true)) then
            local c = DoesEntityExist(bossPed) and GetEntityCoords(bossPed) or vector3(raid.x, raid.y, raid.z)
            bossPed = nil
            TriggerServerEvent('pup-gangs:fortKill', raid.index, true, c.x, c.y, c.z)
        end
    end
end)

-- the strongbox prompt
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    lootGroup = GetRandomIntInRange(0, 0xffffff)
    lootPrompt = PromptRegisterBegin()
    PromptSetControlAction(lootPrompt, Config.Keys.fortLoot) -- E
    PromptSetText(lootPrompt, CreateVarString(10, 'LITERAL_STRING', 'Crack the strongbox'))
    PromptSetEnabled(lootPrompt, 1)
    PromptSetVisible(lootPrompt, 1)
    PromptSetHoldMode(lootPrompt, (Config.FortRaid.lootSeconds or 8) * 1000)
    PromptSetGroup(lootPrompt, lootGroup)
    PromptRegisterEnd(lootPrompt)

    while true do
        local sleep = 800
        if raid and lootReady and raid.lootX then
            local c = GetEntityCoords(PlayerPedId())
            if raid.boxOpensAt and GetGameTimer() < raid.boxOpensAt then
                -- no prompt yet, and one reminder when they first walk up to it
                if #(c - vector3(raid.lootX, raid.lootY, raid.lootZ)) <= (Config.FortRaid.lootDistance or 2.5) then
                    if not raid.toldBoxShut then
                        raid.toldBoxShut = true
                        exports['pup-ui']:Toast(Locale.fortBoxShut, 5000)
                    end
                else
                    raid.toldBoxShut = nil
                end
            elseif #(c - vector3(raid.lootX, raid.lootY, raid.lootZ)) <= (Config.FortRaid.lootDistance or 2.5) then
                sleep = 0
                PromptSetActiveGroupThisFrame(lootGroup,
                    CreateVarString(10, 'LITERAL_STRING', 'Strongbox'))
                if Citizen.InvokeNative(0xE0F65F0640EF0617, lootPrompt) then -- PromptHasHoldModeCompleted
                    lootReady = false
                    TriggerServerEvent('pup-gangs:fortLooted', raid.index)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanupAll()
end)
