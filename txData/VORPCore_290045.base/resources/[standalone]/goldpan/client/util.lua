-- goldpan | client helpers: toasts, models, animations, prop attach

Cli = {}

local RES <const> = GetCurrentResourceName()

function Cli.yes(v)
    return v == true or v == 1
end

-- data: string or { title, subtitle, tone, duration }
function Cli.toast(data)
    if GetResourceState('pup-ui') == 'started' then
        local ok = pcall(function() exports['pup-ui']:Toast(data) end)
        if ok then return end
    end
    local text, ms = data, 5000
    if type(data) == 'table' then
        text = data.title or ''
        if data.subtitle then text = text .. ' ' .. data.subtitle end
        ms = data.duration or ms
    end
    TriggerEvent('vorp:TipRight', tostring(text), ms)
end

-- a message from Config.Messages by key
function Cli.say(key)
    Cli.toast({ title = GP.msg(key), tone = GP.toneOf(key), duration = GP.msOf(key) })
end

function Cli.loadModel(model, timeoutMs)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not Cli.yes(IsModelValid(hash)) then return nil end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not Cli.yes(HasModelLoaded(hash)) do
        if GetGameTimer() > deadline then return nil end
        Wait(50)
    end
    return hash
end

function Cli.loadDict(dict, timeoutMs)
    if not Cli.yes(DoesAnimDictExist(dict)) then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not Cli.yes(HasAnimDictLoaded(dict)) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

function Cli.play(ped, anim, ms)
    if not anim or not Cli.loadDict(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, ms or -1, anim.flag or 0, 0.0, false, false, false)
end

function Cli.bone(ped)
    local b = Config.Options.BoneIndex
    if type(b) == 'number' then return b end
    return GetEntityBoneIndexByName(ped, b or 'SKEL_R_HAND')
end

-- pose = 'carry' | 'work'
function Cli.attach(prop, ped, pose)
    if not prop or not Cli.yes(DoesEntityExist(prop)) then return end
    local o = Config.Options.PanAttach[pose] or Config.Options.PanAttach.carry
    DetachEntity(prop, true, true)
    AttachEntityToEntity(prop, ped, Cli.bone(ped), o[1], o[2], o[3], o[4], o[5], o[6],
        false, false, false, false, 2, true, false, false)
end

function Cli.deleteEntity(e)
    if e and e ~= 0 and Cli.yes(DoesEntityExist(e)) then
        DetachEntity(e, true, true)
        SetEntityAsMissionEntity(e, true, true)
        DeleteObject(e)
        if Cli.yes(DoesEntityExist(e)) then DeleteEntity(e) end
    end
end

function Cli.varString(text)
    return CreateVarString(10, 'LITERAL_STRING', tostring(text))
end

function Cli.prompt(control, text, group)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, control)
    PromptSetText(p, Cli.varString(text))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C, p, true)
    PromptRegisterEnd(p)
    return p
end

function Cli.pressed(p)
    return p ~= nil and Cli.yes(Citizen.InvokeNative(0xC92AC953F0A982AE, p, Citizen.ResultAsInteger()))
end

-- water zone at the ped, 0 when none
function Cli.waterZone(ped)
    local c = GetEntityCoords(ped)
    local z = Citizen.InvokeNative(0x5BA7A68A346A5A91, c.x, c.y, c.z, Citizen.ResultAsInteger())
    return GP.u32(z)
end

function Cli.log(msg)
    print(('^3[%s]^7 %s'):format(RES, msg))
end
