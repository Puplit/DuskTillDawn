-- pup_shaman | client core: state, helpers shared by the client modules, curse notices, blips

Shaman = {
    curse = '',     -- what the server last said we carry
    form = nil,     -- { key, def, coat, bloodMoon, size, endsAt } while in an animal form
    dream = nil,    -- { tree, vision, origin, heading, endsAt } while on a vision
    busy = false,   -- a swap, a fade or an animation sequence is running
    stopHooks = {}, -- run on resource stop (no waiting possible there)
    resetHooks = {},-- run when the server says the character changed
}

local RESOURCE <const> = GetCurrentResourceName()

-- natives called by hash (names differ between native lists)
local N <const> = {
    setRandomOutfit   = 0x283978A15512B2FE,
    equipOutfitPreset = 0x77FF8D35EEC6BBC4,
    setPedScale       = 0x25ACFC650B65C538,
    fxPlay            = 0x4102732DF6B4005F,
    fxStop            = 0xB4FD7446BAB2F394,
    fxRunning         = 0x4A123E85D7C4CA0B,
    setCore           = 0xC6258F41D86676E0,
}
Shaman.N = N

function Shaman.OnStop(fn) Shaman.stopHooks[#Shaman.stopHooks + 1] = fn end
function Shaman.OnReset(fn) Shaman.resetHooks[#Shaman.resetHooks + 1] = fn end

function Shaman.Tip(msg, ms)
    if not msg or msg == '' then return end
    TriggerEvent('vorp:TipRight', msg, ms or 4000)
end

function Shaman.IsDead(ped)
    ped = ped or PlayerPedId()
    return IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
end

-- screen fades ---------------------------------------------------------------

function Shaman.FadeOut()
    local ms = Config.Shift.fadeMs
    DoScreenFadeOut(ms)
    local t = GetGameTimer() + ms + 1500
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(25) end
end

function Shaman.FadeIn()
    local ms = Config.Shift.fadeMs
    DoScreenFadeIn(ms)
    local t = GetGameTimer() + ms + 1500
    while not IsScreenFadedIn() and GetGameTimer() < t do Wait(25) end
end

-- loading ----------------------------------------------------------------------

function Shaman.LoadModel(name, timeoutMs)
    local hash = type(name) == 'number' and name or joaat(name)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil end
        Wait(25)
    end
    return hash
end

function Shaman.LoadDict(dict, timeoutMs)
    if not dict then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + (timeoutMs or 3000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(25)
    end
    return true
end

--- Plays a clip on a ped (flag 0 = once). Returns false when the dictionary would not load.
function Shaman.PlayAnim(ped, dict, clip, ms, flag)
    if not Shaman.LoadDict(dict) then return false end
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, ms or -1, flag or 0, 0, false, false, false)
    return true
end

-- screen effects ------------------------------------------------------------------

function Shaman.FxPlay(name)
    if not name then return end
    Citizen.InvokeNative(N.fxPlay, name)
end

function Shaman.FxStop(name)
    if not name then return end
    if Citizen.InvokeNative(N.fxRunning, name) then
        Citizen.InvokeNative(N.fxStop, name)
    end
end

-- size ----------------------------------------------------------------------------

local sizeToken = 0

--- Sets the ped scale now and again shortly after; a newer request cancels the older re-applications.
function Shaman.SetSize(size)
    sizeToken = sizeToken + 1
    local mine = sizeToken
    local function apply()
        if mine ~= sizeToken then return end
        Citizen.InvokeNative(N.setPedScale, PlayerPedId(), size + 0.0)
    end
    apply()
    if size == 1.0 then return end
    for _, ms in ipairs(Config.Shift.sizeReapplyMs) do
        SetTimeout(ms, apply)
    end
end

-- controls ------------------------------------------------------------------------

function Shaman.DisableControls(noJump)
    for _, c in ipairs(Config.Shift.disabledControls) do
        DisableControlAction(0, c, true)
    end
    if noJump then DisableControlAction(0, Config.Shift.jumpControl, true) end
end

-- moving --------------------------------------------------------------------------

function Shaman.Teleport(pos)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    local t = GetGameTimer() + Config.TreeRules.collisionWaitMs
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < t do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        Wait(50)
    end
end

-- bodies --------------------------------------------------------------------------

--- Swaps the player into an animal model with an optional coat. Returns the new ped, or nil on failure
--- (the player is still human then).
function Shaman.BecomeAnimal(modelName, coat)
    local hash = Shaman.LoadModel(modelName, Config.Shift.modelTimeoutMs)
    if not hash then return nil end
    -- an animal has no weapons: the empty belt must not be saved as zero ammo
    TriggerEvent('vorpinventory:ammoUpdateToggle', false)
    SetPlayerModel(PlayerId(), hash, false)
    local t = GetGameTimer() + Config.Shift.pedTimeoutMs
    while GetEntityModel(PlayerPedId()) ~= hash and GetGameTimer() < t do Wait(50) end
    SetModelAsNoLongerNeeded(hash)
    local ped = PlayerPedId()
    if GetEntityModel(ped) ~= hash then
        -- the swap never took: rebuild the human and give up
        Shaman.RestoreHuman(false)
        return nil
    end
    Citizen.InvokeNative(N.setRandomOutfit, ped, true)
    if coat then Citizen.InvokeNative(N.equipOutfitPreset, ped, coat, false) end
    SetPedCanRagdoll(ped, false)
    return ped
end

--- Rebuilds the character's own body (vorp_character's rc) and restores damage, ragdoll and ammo writes.
function Shaman.RestoreHuman(dead)
    local ped = PlayerPedId()
    Shaman.SetSize(1.0)
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
    SetPedCanRagdoll(ped, true)
    if Shaman.IsDead(ped) then
        -- vorp_character's rc does nothing for a dead ped. vorp_core's respawn or revive
        -- rebuilds the body (vorpcharacter:reloadafterdeath), so ammo writes wait for that.
        CreateThread(function()
            local t = GetGameTimer() + 600000
            while not IsPedHuman(PlayerPedId()) and GetGameTimer() < t do Wait(500) end
            Wait(Config.Shift.weaponsBackMs)
            TriggerEvent('vorpinventory:ammoUpdateToggle', true)
        end)
        return
    end
    ExecuteCommand(Config.Shift.rebuildCommand)
    local t = GetGameTimer() + Config.Shift.humanTimeoutMs
    local retryAt = GetGameTimer() + 5000
    while not IsPedHuman(PlayerPedId()) and GetGameTimer() < t do
        -- rc refuses silently while restrained or busy elsewhere: ask again
        if GetGameTimer() >= retryAt and not Shaman.IsDead() then
            ExecuteCommand(Config.Shift.rebuildCommand)
            retryAt = GetGameTimer() + 5000
        end
        Wait(100)
    end
    Wait(Config.Shift.weaponsBackMs)
    TriggerEvent('vorpinventory:ammoUpdateToggle', true)
    ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
    SetPedCanRagdoll(ped, true)
    if dead then SetEntityHealth(ped, 0) end
end

--- Makes the current ped invincible (forms when configured, and every vision).
function Shaman.Shield(ped)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
end

function Shaman.RefillCores()
    local ped = PlayerPedId()
    Citizen.InvokeNative(N.setCore, ped, 0, 100)
    Citizen.InvokeNative(N.setCore, ped, 1, 100)
end

-- curse state from the server -------------------------------------------------------

RegisterNetEvent('pup_shaman:client:curse', function(key, elapsed, mode)
    key = type(key) == 'string' and key or ''
    local prev = Shaman.curse
    Shaman.curse = key
    -- one notice per change; 'load' says nothing and 'quiet' means the sender has its own words
    if mode == 'change' and key ~= prev then
        local def = Config.Curses[key]
        if def then
            Shaman.Tip(L('cursed', def.label))
        elseif key == '' then
            Shaman.Tip(L('curse_left'))
        end
    end
    Affliction.Set(key, tonumber(elapsed) or 0)
    -- a form the new curse no longer grants ends at once
    TriggerEvent('pup_shaman:client:curseUpdated', key)
end)

RegisterNetEvent('pup_shaman:client:courseElapsed', function(key, elapsed)
    if key ~= Shaman.curse then return end
    Affliction.Set(key, tonumber(elapsed) or 0)
end)

-- cure drink
RegisterNetEvent('pup_shaman:client:drinkCure', function()
    CreateThread(function()
        local cfg = Config.CureDrink
        local ped = PlayerPedId()
        Affliction.Stop()
        local hash = Shaman.LoadModel(cfg.prop, 3000)
        if not hash or Shaman.form or Shaman.dream then return end
        local pos = GetEntityCoords(ped)
        local prop = CreateObject(hash, pos.x, pos.y, pos.z + 0.2, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        -- TASK_ITEM_INTERACTION_2: the ped drinks from the prop held at its grip
        Citizen.InvokeNative(0x72F52AA2D2B172CC, ped, hash, prop, joaat(cfg.grip), joaat(cfg.interaction), 1, 0, -1.0)
        Wait(cfg.ms)
        Affliction.Stop()
        if DoesEntityExist(prop) then DeleteObject(prop) end
        ClearPedTasks(ped)
    end)
end)

-- tree blips --------------------------------------------------------------------------

local blips = {}

local function clearBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

RegisterNetEvent('pup_shaman:client:blips', function(allowed)
    clearBlips()
    if allowed ~= true then return end
    local cfg = Config.TreeRules.blip
    for _, tree in ipairs(Config.Trees) do
        if tree.blip then
            local c = tree.coords
            local b = Citizen.InvokeNative(0x554D9D53F696D002, cfg.style, c.x, c.y, c.z) -- BLIP_ADD_FOR_COORDS
            SetBlipSprite(b, cfg.sprite, true)
            SetBlipScale(b, cfg.scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, b, CreateVarString(10, 'LITERAL_STRING', tree.name)) -- SET_BLIP_NAME
            blips[#blips + 1] = b
        end
    end
end)

-- lifecycle ------------------------------------------------------------------------------

AddEventHandler('onClientResourceStart', function(res)
    if res ~= RESOURCE then return end
    CreateThread(function()
        Wait(1000)
        TriggerServerEvent('pup_shaman:server:hello')
    end)
end)

-- the character changed: whatever the last one was doing ends without rebuilding its body
RegisterNetEvent('pup_shaman:client:reset', function()
    for _, fn in ipairs(Shaman.resetHooks) do pcall(fn) end
    Shaman.curse = ''
    Affliction.Set('', 0)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    for _, fn in ipairs(Shaman.stopHooks) do pcall(fn) end
    clearBlips()
    Affliction.Stop()
    if Shaman.busy or IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(0) end
end)
