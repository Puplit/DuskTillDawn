-- legendaryhunt | client helpers: tips, prompts, models, animations, perk multiplier

Cli = {}

local RES <const> = GetCurrentResourceName()
local warned = {}

function Cli.warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s]^7 %s'):format(RES, msg))
end

-- call a native by its RedM name only when this game build has it
function Cli.native(name, ...)
    local fn = _G[name]
    if type(fn) ~= 'function' then
        Cli.warnOnce('native_' .. name, ('native %s is not available; skipped'):format(name))
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        Cli.warnOnce('native_' .. name, ('native %s failed: %s'):format(name, tostring(result)))
        return nil
    end
    return result
end

function Cli.tip(text, ms)
    TriggerEvent('vorp:TipBottom', tostring(text), ms or 6000)
end

function Cli.tipRight(text, ms)
    TriggerEvent('vorp:TipRight', tostring(text), ms or 6000)
end

function Cli.varString(text)
    return CreateVarString(10, 'LITERAL_STRING', tostring(text))
end

function Cli.newGroup()
    return GetRandomIntInRange(0, 0xffffff)
end

function Cli.prompt(key, text, group)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, Cli.varString(text))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

function Cli.pressed(p)
    return p ~= nil and PromptHasStandardModeCompleted(p)
end

-- request a model with a time limit; returns the hash or nil
function Cli.loadModel(model, timeoutMs)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(50)
    end
    return hash
end

function Cli.loadDict(dict, timeoutMs)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

-- play a timed animation on the player and clear it afterwards (blocks for ms)
function Cli.playTimed(anim)
    local ped = PlayerPedId()
    if Cli.loadDict(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, anim.ms, 0, 0.0, false, false, false)
    end
    Wait(anim.ms)
    ClearPedTasks(ped)
    RemoveAnimDict(anim.dict)
end

function Cli.deleteEntity(e)
    if e and e ~= 0 and DoesEntityExist(e) then
        SetEntityAsMissionEntity(e, true, true)
        DeleteEntity(e)
    end
end

-- pup-perks multiplier on the trap waits; 1.0 when pup-perks is missing or fails
function Cli.perkMult()
    local res = Config.Integrations.perks
    if GetResourceState(res) ~= 'started' then return 1.0 end
    local ok, m = pcall(function() return exports[res]:Mult(Config.Integrations.perkKey) end)
    m = ok and tonumber(m) or nil
    if not m or m ~= m or m <= 0 then return 1.0 end
    return m
end

-- a wait scaled by the perk, whole seconds, at least 1
function Cli.scaledSeconds(base)
    return math.max(1, math.floor((tonumber(base) or 0) * Cli.perkMult()))
end

-- signed 32-bit, so a game hash compares with the signed values the code keeps (weapons, fighters)
function Cli.signed32(v)
    v = math.floor(tonumber(v) or 0) & 0xFFFFFFFF
    if v >= 0x80000000 then v = v - 0x100000000 end
    return v
end

-- 3D label over a world point: dark backing and up to two lines
function Cli.drawLabel(pos, line1, line2)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z)
    if not onScreen then return end
    DrawRect(x, y + 0.012, 0.13, 0.05, 12, 10, 8, 170, false, false)
    SetTextScale(0.32, 0.32)
    SetTextColor(240, 236, 226, 255)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(Cli.varString(line1), x, y - 0.008)
    if line2 then
        SetTextScale(0.32, 0.32)
        SetTextColor(212, 170, 72, 255) -- gold
        SetTextCentre(true)
        SetTextDropshadow(1, 0, 0, 0, 255)
        DisplayText(Cli.varString(line2), x, y + 0.012)
    end
end
