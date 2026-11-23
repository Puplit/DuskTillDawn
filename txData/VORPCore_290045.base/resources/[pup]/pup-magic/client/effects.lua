-- pup-magic | what every client shows for the spell kit: blasts, hits, leaps, smoke, lightning, shocks,
-- frogs and auras. Everything here is started by the server.

local Spells <const> = Config.Spells

local function num(v, lo, hi, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    return v
end

---------------------------------------------------------------------------
-- blasts, hits, the leap
---------------------------------------------------------------------------
local function blastFx(tag)
    if tag == 27 then return 'exp_grd_dynamite_volatile' end
    if tag == 24 then return 'exp_grd_lantern' end
    return 'exp_grd_dynamite'
end

RegisterNetEvent('pup-magic:blasts', function(list, caster)
    if type(list) ~= 'table' then return end
    local mine = math.tointeger(tonumber(caster)) == MyServerId()
    for i = 1, math.min(#list, 32) do
        local b = list[i]
        if type(b) == 'table' then
            local x, y, z = tonumber(b.x), tonumber(b.y), tonumber(b.z)
            local tag = math.tointeger(tonumber(b.tag)) or 25
            local size = num(b.size, 0.05, 10.0, 1.0)
            if x and y and z then
                if mine then
                    -- the engine syncs this one, with its sound, to everyone
                    AddExplosion(x, y, z, tag, (tonumber(Config.Blasts.engineDamage) or 0.0) + 0.0, true, false, (tonumber(Config.Blasts.shake) or 0.0) + 0.0)
                end
                FxOnce('core', blastFx(tag), x, y, z, size)
                if tag ~= 24 then FxOnce('core', 'exp_grd_smoke_post', x, y, z, size * 0.8) end
            end
        end
    end
end)

local function hurt(ped, amount)
    amount = math.floor(num(amount, 0, 100000, 0))
    if amount <= 0 then return end
    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - amount), 0)
end

RegisterNetEvent('pup-magic:hit', function(x, y, z, damage, force)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end
    force = num(force, 0, 60, 0)
    local ped = PlayerPedId()
    hurt(ped, damage)
    if IsEntityDead(ped) then return end
    SetPedToRagdoll(ped, 2500, 2500, 0, false, false, false)
    SetTimeout(50, function()
        if not DoesEntityExist(ped) or IsEntityDead(ped) then return end
        local p = GetEntityCoords(ped)
        local dx, dy = p.x - x, p.y - y
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.05 then
            local fwd = GetEntityForwardVector(ped)
            dx, dy, len = fwd.x, fwd.y, 1.0
        end
        ApplyForceToEntity(ped, 1, dx / len * force, dy / len * force, 0.45 * force, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    end)
end)

RegisterNetEvent('pup-magic:selfDamage', function(amount)
    hurt(PlayerPedId(), amount)
end)

RegisterNetEvent('pup-magic:leap', function(forward, up)
    local ped = PlayerPedId()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return end
    forward, up = num(forward, 0, 80, 20.0), num(up, 0, 80, 10.0)
    SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
    SetTimeout(50, function()
        local rot = GetGameplayCamRot(2)
        local yaw = math.rad(rot.z)
        ApplyForceToEntity(ped, 1, -math.sin(yaw) * forward, math.cos(yaw) * forward, up, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    end)
end)

---------------------------------------------------------------------------
-- smoke and lightning
---------------------------------------------------------------------------
RegisterNetEvent('pup-magic:smoke', function(id, x, y, z)
    local spell = Spells[id]
    local fx = spell and spell.fx
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if type(fx) ~= 'table' or not x or not y or not z then return end
    CreateThread(function()
        if not LoadPtfx(fx.asset, 5000) then return end
        UseParticleFxAsset(fx.asset)
        local handle = StartParticleFxLoopedAtCoord(fx.name, x, y, z - 0.5, 0.0, 0.0, 0.0, (tonumber(fx.scale) or 0.7) + 0.0, false, false, false, false)
        if not handle or handle == 0 then return end
        pcall(SetParticleFxLoopedFarClipDist, handle, (tonumber(fx.radius) or 20.0) + 0.0)
        pcall(SetParticleFxLoopedAlpha, handle, 1.0)
        Wait(math.floor((tonumber(fx.duration) or 10) * 1000))
        StopLoop(handle)
    end)
end)

RegisterNetEvent('pup-magic:lightning', function(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end
    ForceLightningFlashAtCoords(x, y, z, -1.0)
end)

---------------------------------------------------------------------------
-- shock: the shocked player, the sparks everyone sees, and the voice mute
---------------------------------------------------------------------------
local shock = nil   -- { endsAt, sparks } while I am shocked
local sparksOn = {} -- [server id] = particle name, other players
local muted = {}    -- [server id] = true

local function endShock()
    if not shock then return end
    shock = nil
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ClearPedTasks(ped)
end

RegisterNetEvent('pup-magic:shock', function(seconds, sparks)
    seconds = num(seconds, 1, 120, 5)
    local endsAt = GetGameTimer() + math.floor(seconds * 1000)
    if shock then
        shock.endsAt = endsAt -- a fresh shock restarts the clock
        return
    end
    shock = { endsAt = endsAt, sparks = (type(sparks) == 'string' and #sparks < 80) and sparks or 'ent_sht_electrical_box' }
    local mine = shock

    TriggerEvent('pup_worldint:clear')
    SetEntityInvincible(PlayerPedId(), true)

    -- every frame: no controls, kept down, the countdown on screen
    CreateThread(function()
        while shock == mine do
            local ped = PlayerPedId()
            DisableAllControlActions(0)
            DisablePlayerFiring(PlayerId(), true)
            if not IsPedRagdoll(ped) then SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false) end
            local left = math.max(0, math.ceil((mine.endsAt - GetGameTimer()) / 1000))
            SetTextScale(0.5, 0.5)
            SetTextColor(255, 255, 255, 255)
            SetTextCentre(true)
            DisplayText(CreateVarString(10, 'LITERAL_STRING', Locale.shocked:format(left)), 0.50, 0.88)
            -- the server ends it; this only covers a server that never answers
            if GetGameTimer() > mine.endsAt + 3000 then endShock() break end
            Wait(0)
        end
    end)

    -- the sparks on me, restarted each second
    CreateThread(function()
        if not LoadPtfx('core', 5000) then return end
        while shock == mine do
            UseParticleFxAsset('core')
            local h = StartParticleFxLoopedOnEntity(mine.sparks, PlayerPedId(), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
            Wait(1000)
            StopLoop(h)
        end
    end)
end)

RegisterNetEvent('pup-magic:shockEnd', endShock)

local sparkLoop = false
local function runSparks()
    if sparkLoop then return end
    sparkLoop = true
    CreateThread(function()
        LoadPtfx('core', 5000)
        while next(sparksOn) do
            for sid, name in pairs(sparksOn) do
                local ped = PedOfServerId(sid)
                if ped ~= 0 and DoesEntityExist(ped) then
                    UseParticleFxAsset('core')
                    StartParticleFxNonLoopedOnEntity(name, ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
                end
            end
            Wait(1000)
        end
        sparkLoop = false
    end)
end

RegisterNetEvent('pup-magic:sparks', function(sid, name, on)
    sid = math.tointeger(tonumber(sid))
    if not sid or sid == MyServerId() then return end
    if on and type(name) == 'string' and #name < 80 then
        sparksOn[sid] = name
        runSparks()
    else
        sparksOn[sid] = nil
    end
end)

RegisterNetEvent('pup-magic:mute', function(sid, on)
    sid = math.tointeger(tonumber(sid))
    if not sid then return end
    if on then
        muted[sid] = true
        MumbleSetVolumeOverrideByServerId(sid, 0.0)
    elseif muted[sid] then
        muted[sid] = nil
        MumbleSetVolumeOverrideByServerId(sid, -1.0)
    end
end)

---------------------------------------------------------------------------
-- transform: through vorp_character's own reload command, so the way back is its normal reload
---------------------------------------------------------------------------
local frog = nil

local function isOwnModel(ped)
    local m = GetEntityModel(ped)
    return m == GetHashKey('mp_male') or m == GetHashKey('mp_female')
end

local function reload(model)
    TriggerEvent('vorp_inventory:pup:holdAmmoReconcile', 12000)
    ExecuteCommand(model and (MagicLimits.reloadCommand .. ' ' .. model) or MagicLimits.reloadCommand)
end

RegisterNetEvent('pup-magic:transform', function(model)
    if frog or type(model) ~= 'string' or not model:match('^[%w_]+$') then return end
    local hash = GetHashKey(model)
    if not IsModelValid(hash) then return end
    frog = model
    reload(model)
end)

local function untransform()
    if not frog then return end
    frog = nil
    CreateThread(function()
        for _ = 1, 5 do
            local before = PlayerPedId()
            if IsEntityDead(before) then return end -- the respawn puts the character back
            if isOwnModel(before) then break end
            -- /rc re-applies whatever vorp_character has cached: the real look, or the borrowed face if one is on
            reload(nil)
            local stop = GetGameTimer() + 6000
            while PlayerPedId() == before and GetGameTimer() < stop do Wait(100) end
            if isOwnModel(PlayerPedId()) then break end
            Wait(2000)
        end
        if isOwnModel(PlayerPedId()) then
            -- a rebuilt ped has empty hands: hand the loadout back, then the belt
            Wait(1500)
            TriggerServerEvent('vorpinventory:getInventory')
            SetTimeout(2500, function() TriggerEvent('vorp_inventory:pup:restoreBeltToPed') end)
        end
    end)
end

RegisterNetEvent('pup-magic:untransform', untransform)

---------------------------------------------------------------------------
-- auras: the server keeps GlobalState.pup_magic_auras = { ['<server id>'] = { spell ids } }
-- Each client draws them from its own Config.Spells, so nobody can put arbitrary particles on themselves.
---------------------------------------------------------------------------
local AURA_BAG <const> = 'pup_magic_auras'
local wanted = GlobalState[AURA_BAG] or {}
local shown = {} -- [server id] = { ped, fx = { [spell id] = { handles } } }

local function auraEntries(spell)
    local fx = spell.fx
    if type(fx) ~= 'table' then return {} end
    if fx.dict then return { fx } end
    return fx
end

local function v3(t, dx, dy, dz)
    t = type(t) == 'table' and t or {}
    return (tonumber(t.x) or dx) + 0.0, (tonumber(t.y) or dy) + 0.0, (tonumber(t.z) or dz) + 0.0
end

local function startAura(ped, id)
    local spell = Spells[id]
    if type(spell) ~= 'table' or spell.effect ~= 'aura' then return {} end
    local handles = {}
    for _, e in ipairs(auraEntries(spell)) do
        if type(e) == 'table' and type(e.dict) == 'string' and type(e.name) == 'string' and LoadPtfx(e.dict, 5000) then
            local bone = tonumber(e.bone) or 0
            if type(e.boneName) == 'string' then
                local b = GetEntityBoneIndexByName(ped, e.boneName)
                if b and b ~= -1 then bone = b end
            end
            local ox, oy, oz = v3(e.off, 0, 0, 0)
            local rx, ry, rz = v3(e.rot, 0, 0, 0)
            UseParticleFxAsset(e.dict)
            local h = StartParticleFxLoopedOnEntityBone(e.name, ped, ox, oy, oz, rx, ry, rz, math.floor(bone), (tonumber(e.scale) or 1.0) + 0.0, false, false, false)
            if h and h ~= 0 then handles[#handles + 1] = h end
        end
    end
    return handles
end

local function stopAll(entry)
    for _, hs in pairs(entry.fx) do
        for _, h in ipairs(hs) do StopLoop(h) end
    end
    entry.fx = {}
end

local function reconcileNow()
    local map = type(wanted) == 'table' and wanted or {}

    for key, ids in pairs(map) do
        local sid = math.tointeger(tonumber(key))
        if sid and type(ids) == 'table' then
            local ped = PedOfServerId(sid)
            local entry = shown[sid]
            if ped == 0 or not DoesEntityExist(ped) then
                if entry then stopAll(entry) shown[sid] = nil end
            else
                if entry and entry.ped ~= ped then stopAll(entry) entry = nil end
                if not entry then entry = { ped = ped, fx = {} } shown[sid] = entry end
                local want = {}
                for _, id in ipairs(ids) do if type(id) == 'string' then want[id] = true end end
                for id, hs in pairs(entry.fx) do
                    if not want[id] then
                        for _, h in ipairs(hs) do StopLoop(h) end
                        entry.fx[id] = nil
                    end
                end
                for id in pairs(want) do
                    if not entry.fx[id] then entry.fx[id] = startAura(ped, id) end
                end
            end
        end
    end

    for sid, entry in pairs(shown) do
        if type(map[tostring(sid)]) ~= 'table' then
            stopAll(entry)
            shown[sid] = nil
        end
    end
end

-- one pass at a time; an error in a pass must not leave the guard set, or auras would freeze for good
local reconciling = false
local function reconcile()
    if reconciling then return end
    reconciling = true
    local ok, err = pcall(reconcileNow)
    reconciling = false
    if not ok then WarnOnce('aura.reconcile', 'aura update failed: ' .. tostring(err)) end
end

AddStateBagChangeHandler(AURA_BAG, 'global', function(_, _, value)
    wanted = type(value) == 'table' and value or {}
    CreateThread(reconcile)
end)

-- players walk in and out of range and peds get rebuilt: check once a second while anything is on
CreateThread(function()
    while true do
        if next(wanted) or next(shown) then reconcile() end
        Wait(1000)
    end
end)

---------------------------------------------------------------------------
-- switching character or stopping the resource
---------------------------------------------------------------------------
RegisterNetEvent('vorp:SelectedCharacter', function()
    endShock()
    frog = nil -- the character load builds the real ped
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, entry in pairs(shown) do stopAll(entry) end
    shown = {}
    for sid in pairs(muted) do MumbleSetVolumeOverrideByServerId(sid, -1.0) end
    muted = {}
    sparksOn = {}
    if shock then
        shock = nil
        local ped = PlayerPedId()
        SetEntityInvincible(ped, false)
        ClearPedTasks(ped)
    end
    if frog then
        frog = nil
        reload(nil)
    end
end)
