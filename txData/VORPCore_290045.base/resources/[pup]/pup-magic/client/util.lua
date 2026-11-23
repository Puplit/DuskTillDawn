-- pup-magic | small client helpers shared by every client file

local RES <const> = GetCurrentResourceName()
local warned = {}

function WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s]^7 %s'):format(RES, msg))
end

function Dbg(fmt, ...)
    if not Config.General.debug then return end
    print(('[%s] ' .. fmt):format(RES, ...))
end

function MyServerId()
    return GetPlayerServerId(PlayerId())
end

function TipRight(text, ms)
    if type(text) ~= 'string' or text == '' then return end
    TriggerEvent('vorp:TipRight', text, ms or 3000)
end

function TipBottom(text, ms)
    if type(text) ~= 'string' or text == '' then return end
    TriggerEvent('vorp:TipBottom', text, ms or 4000)
end

function LoadAnimDict(dict, timeoutMs)
    if type(dict) ~= 'string' then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local stop = GetGameTimer() + (timeoutMs or 3000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > stop then return false end
        Wait(10)
    end
    return true
end

function LoadPtfx(asset, timeoutMs)
    if type(asset) ~= 'string' then return false end
    local h = GetHashKey(asset)
    if HasNamedPtfxAssetLoaded(h) then return true end
    RequestNamedPtfxAsset(h)
    local stop = GetGameTimer() + (timeoutMs or 5000)
    while not HasNamedPtfxAssetLoaded(h) do
        if GetGameTimer() > stop then return false end
        Wait(10)
    end
    return true
end

-- a one-off particle at a spot
function FxOnce(asset, name, x, y, z, scale)
    CreateThread(function()
        if not LoadPtfx(asset, 5000) then return end
        UseParticleFxAsset(asset)
        StartParticleFxNonLoopedAtCoord(name, x + 0.0, y + 0.0, z + 0.0, 0.0, 0.0, 0.0, (scale or 1.0) + 0.0, false, false, false)
    end)
end

function StopLoop(handle)
    if handle and handle ~= 0 then pcall(StopParticleFxLooped, handle, false) end
end

-- kit emote on the upper body, by name
local function emoteKind(name)
    local n = name:lower()
    if n:find('reaction', 1, true) then return 0 end
    if n:find('taunt', 1, true) then return 2 end
    if n:find('greet', 1, true) then return 3 end
    if n:find('dance', 1, true) then return 5 end
    return 1
end

function PlayEmote(name)
    if type(name) ~= 'string' or name == '' then return end
    pcall(function()
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, PlayerPedId(), emoteKind(name), 0, GetHashKey(name), 1, 1, 0, 0, 0)
    end)
end

-- vorp_animations: one object for the session, nil when it is missing
local anims, animsTried = nil, false
local function animObject()
    if animsTried then return anims end
    animsTried = true
    if GetResourceState('vorp_animations') ~= 'started' then
        WarnOnce('anims', 'vorp_animations is not running: feeding plays without its animation')
        return nil
    end
    local ok, obj = pcall(function() return exports.vorp_animations:initiate() end)
    if ok and type(obj) == 'table' then anims = obj else WarnOnce('anims', 'vorp_animations initiate failed') end
    return anims
end

function StartVorpAnim(key)
    CreateThread(function()
        local a = animObject()
        if a and a.startAnimation then
            local ok, err = pcall(a.startAnimation, key)
            if not ok then WarnOnce('anim.' .. tostring(key), 'animation ' .. tostring(key) .. ' failed: ' .. tostring(err)) end
        end
    end)
end

function EndVorpAnim(key)
    local a = animObject()
    if a and a.endAnimation then pcall(a.endAnimation, key) end
end

function SetDrunk(ped, on, amount)
    pcall(function() Citizen.InvokeNative(0x406CCF555B04FAD3, ped, on and true or false, (amount or 0.0) + 0.0) end)
end

function CoreValue(ped, core)
    return Citizen.InvokeNative(0x36731AC041289BB1, ped, core, Citizen.ResultAsInteger()) or 0
end

function SetCoreValue(ped, core, value)
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, core, math.floor(value))
end

-- heading (degrees) to look from a to b
function HeadingTo(a, b)
    return math.deg(math.atan(-(b.x - a.x), b.y - a.y)) % 360.0
end

function ChestOf(ped)
    local bone = GetEntityBoneIndexByName(ped, 'SKEL_Spine4')
    if bone and bone ~= -1 then return GetWorldPositionOfEntityBone(ped, bone) end
    return GetEntityCoords(ped)
end

function ServerIdOfPed(ped)
    local player = NetworkGetPlayerIndexFromPed(ped)
    if not player or player == -1 then return nil end
    local sid = GetPlayerServerId(player)
    return (sid and sid > 0) and sid or nil
end

function PedOfServerId(sid)
    local player = GetPlayerFromServerId(sid)
    if not player or player == -1 or not NetworkIsPlayerActive(player) then return 0 end
    return GetPlayerPed(player)
end
