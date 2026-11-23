-- huntingbirds | client helpers: toasts, prompts, models, ped outfits, player checks

Cl = {}

Cl.uiOwner = nil -- owner token of our open ink menu or input, nil when none

local N <const> = {
    randomOutfit  = 0x283978A15512B2FE,
    outfitPreset  = 0x77FF8D35EEC6BBC4,
    readyToRender = 0xA0BC8FAED8CFEB3C,
    refreshA      = 0x704C908E9C405136,
    refreshB      = 0xAAB86462966168CE,
    updateVar     = 0xCC8CA3E88256E58F,
    blockEvents   = 0x9F8AA94D6D97DBF4,
    isFrozen      = 0x083D497D57B7400F,
    hogtied       = 0x3AA24CCC0D451379,
    hogtying      = 0x42429C674B61238B,
    onLadder      = 0x59643424B68D52B5,
    cuffed        = 0x74E559B3BC910685,
    modelIsHorse  = 0x772A1969F649E902,
}
Cl.N = N

-- a BOOL answer from the game as a Lua boolean (RedM can hand back 0/1)
function Cl.is(v)
    return v == true or v == 1
end

function Cl.exists(e)
    return e ~= nil and e ~= 0 and Cl.is(DoesEntityExist(e))
end

function Cl.nb(hash, ...)
    local args = table.pack(...)
    args[args.n + 1] = Citizen.ResultAsInteger()
    return Citizen.InvokeNative(hash, table.unpack(args, 1, args.n + 1)) == 1
end

function Cl.toast(text, tone)
    if not text or text == '' then return end
    pcall(function()
        exports['pup-ui']:Toast({ title = Locale.title, subtitle = text, tone = tone or 'gold', duration = 5000 })
    end)
end

function Cl.varString(text)
    return CreateVarString(10, 'LITERAL_STRING', tostring(text))
end

-------------------------------------------------------------------------------- prompts
function Cl.newGroup()
    return GetRandomIntInRange(0, 0xffffff)
end

function Cl.prompt(key, text, group)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, Cl.varString(text))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

function Cl.pressed(p)
    return p ~= nil and Cl.is(PromptHasStandardModeCompleted(p))
end

function Cl.showGroup(group, title)
    PromptSetActiveGroupThisFrame(group, Cl.varString(title), 0, 0, 0, 0)
end

-------------------------------------------------------------------------------- player
function Cl.isDead(ped)
    ped = ped or PlayerPedId()
    return Cl.is(IsEntityDead(ped)) or Cl.is(IsPedDeadOrDying(ped, true))
end

function Cl.isHogtied(ped)
    return Cl.nb(N.hogtied, ped or PlayerPedId())
end

function Cl.isCuffed(ped)
    return Cl.nb(N.cuffed, ped or PlayerPedId())
end

-- reasons a bird cannot stay on the shoulder
function Cl.mustLeaveShoulder(ped)
    return Cl.is(IsPedClimbing(ped)) or Cl.nb(N.onLadder, ped) or Cl.is(IsPedFalling(ped))
        or Cl.nb(N.hogtied, ped) or Cl.nb(N.hogtying, ped) or Cl.is(IsPedRagdoll(ped))
        or Cl.is(IsPedSwimming(ped))
end

function Cl.isFrozen(ent)
    return Cl.nb(N.isFrozen, ent)
end

function Cl.isHorseModel(model)
    return Cl.nb(N.modelIsHorse, model)
end

function Cl.blockEvents(ped)
    Citizen.InvokeNative(N.blockEvents, ped, true)
end

-------------------------------------------------------------------------------- models and peds
function Cl.loadModel(model, timeoutMs)
    local hash = Util.u32(model)
    if not hash or not Cl.is(IsModelValid(hash)) then return nil end
    if Cl.is(HasModelLoaded(hash)) then return hash end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not Cl.is(HasModelLoaded(hash)) do
        if GetGameTimer() > deadline then return nil end
        Wait(50)
    end
    return hash
end

-- random variation, then the preset, wait to render (time limit), then refresh
function Cl.dress(ped, preset)
    Citizen.InvokeNative(N.randomOutfit, ped, true)
    Citizen.InvokeNative(N.outfitPreset, ped, tonumber(preset) or 0, false)
    local deadline = GetGameTimer() + 5000
    while Cl.exists(ped) and not Cl.nb(N.readyToRender, ped) do
        if GetGameTimer() > deadline then break end
        Wait(0)
    end
    if not Cl.exists(ped) then return end
    Citizen.InvokeNative(N.refreshA, ped)
    Citizen.InvokeNative(N.refreshB, ped, 1)
    Citizen.InvokeNative(N.updateVar, ped, false, true, true, true, false)
end

-- networked flag; nil when the model cannot load
function Cl.spawnPed(model, coords, heading, networked)
    local hash = Cl.loadModel(model, 5000)
    if not hash then return nil end
    local ped = CreatePed(hash, coords.x, coords.y, coords.z, heading or 0.0, networked == true, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 or not Cl.exists(ped) then return nil end
    return ped
end

function Cl.deleteEntity(e)
    if e and e ~= 0 and Cl.exists(e) then
        if Cl.is(IsEntityAttached(e)) then DetachEntity(e, true, true) end
        SetEntityAsMissionEntity(e, true, true)
        DeleteEntity(e)
    end
end

-- delete and wait (time limit) until the entity is gone
function Cl.deleteAndWait(e, timeoutMs)
    if not e or e == 0 then return end
    Cl.deleteEntity(e)
    local deadline = GetGameTimer() + (timeoutMs or 2000)
    while Cl.exists(e) and GetGameTimer() < deadline do
        Wait(0)
        DeleteEntity(e)
    end
end

-------------------------------------------------------------------------------- world
function Cl.drawMarker(x, y, z, sx, sy, sz)
    local c = Config.Markers.color or { 128, 200, 0 }
    Citizen.InvokeNative(0x2A32FAA57B937173, 0x6903B113, x, y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        sx, sy, sz, c[1] or 128, c[2] or 200, c[3] or 0, 100, false, false, 2, false, nil, nil, false)
end

-- zone hash under the player: place, then area, then district; the fallback when none match
function Cl.zoneHash()
    local c = GetEntityCoords(PlayerPedId())
    for _, lvl in ipairs(Config.HuntZones.levels) do
        local h = Util.u32(Citizen.InvokeNative(0x43AD8FC02B429D33, c.x, c.y, c.z, lvl.type, Citizen.ResultAsInteger()))
        if h and h ~= 0 and lvl.byHash[h] then return h end
    end
    return Config.HuntZones.fallbackHash
end

function Cl.formatWait(ms)
    local total = math.max(1, math.ceil(ms / 1000))
    local m, s = total // 60, total % 60
    if m > 0 then return Locale.minutesSeconds:format(m, s) end
    return Locale.seconds:format(s)
end
