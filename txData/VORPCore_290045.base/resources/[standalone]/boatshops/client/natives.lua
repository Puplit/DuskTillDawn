-- boatshops | thin wrappers over the game natives this resource uses

BN = {}
local Inv = Citizen.InvokeNative

-- a named native when this build has it, otherwise the hash
local function named(name, hash)
    local fn = _G[name]
    if type(fn) == 'function' then return fn end
    return function(...) return Inv(hash, ...) end
end

local P = {
    begin = named('UiPromptRegisterBegin', 0x04F97DE45A519419),
    control = named('UiPromptSetControlAction', 0xB5352B7494A08258),
    text = named('UiPromptSetText', 0x5DD02A8318420DD7),
    enabled = named('UiPromptSetEnabled', 0x8A0FB4D03A630D21),
    visible = named('UiPromptSetVisible', 0x71215ACCFDE075EE),
    standard = named('UiPromptSetStandardMode', 0xCC6656799977741B),
    group = named('UiPromptSetGroup', 0x2F11D3A254169EA4),
    finish = named('UiPromptRegisterEnd', 0xF7AA2696A22AD8B9),
    active = named('UiPromptSetActiveGroupThisFrame', 0xC65A45D4453C2627),
    delete = named('UiPromptDelete', 0x00EDE88D4D13CF59),
}

function BN.str(text)
    return Inv(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', tostring(text), Citizen.ResultAsLong())
end

-- a native's 0/1/false/true as a Lua boolean
function BN.yes(v)
    return v == true or v == 1
end

-- ------------------------------------------------------------------ prompts

-- one standard-mode prompt in its own group
function BN.prompt(control, text)
    local group = GetRandomIntInRange(0, 0xFFFFFF)
    local p = P.begin()
    P.control(p, control)
    P.text(p, BN.str(text))
    P.enabled(p, true)
    P.visible(p, true)
    P.standard(p, true)
    P.group(p, group, 0)
    Inv(0xC5F428EE08FA7F2C, p, true)
    P.finish(p)
    return { handle = p, group = group }
end

function BN.showPrompt(pr, label)
    P.active(pr.group, BN.str(label))
end

function BN.promptDone(pr)
    return BN.yes(Inv(0xC92AC953F0A982AE, pr.handle, Citizen.ResultAsInteger()))
end

function BN.deletePrompt(pr)
    if pr and pr.handle then P.delete(pr.handle) end
end

-- ------------------------------------------------------------------ blips

function BN.coordBlip(style, x, y, z)
    return Inv(0x554D9D53F696D002, style, x + 0.0, y + 0.0, z + 0.0, Citizen.ResultAsInteger())
end

function BN.entityBlip(style, ent)
    return Inv(0x23F74C2FDA6E7C61, style, ent, Citizen.ResultAsInteger())
end

function BN.blipSprite(blip, sprite)
    if type(sprite) == 'string' then sprite = GetHashKey(sprite) end
    Inv(0x74F74D3207ED525C, blip, sprite, true)
end

function BN.blipName(blip, name)
    Inv(0x9CB1A1623062F402, blip, BN.str(name))
end

function BN.blipModifier(blip, modifier)
    Inv(0x662D364ABF16DE2F, blip, GetHashKey(modifier))
end

function BN.blipScale(blip, scale)
    Inv(0xD38744167B2FA257, blip, scale + 0.0)
end

function BN.removeBlip(blip)
    if blip and blip ~= 0 and DoesBlipExist(blip) then RemoveBlip(blip) end
end

-- ------------------------------------------------------------------ boats

function BN.anchor(veh, on)
    if type(SetBoatAnchor) == 'function' then
        SetBoatAnchor(veh, on)
    else
        Inv(0xAEAB044F05B92659, veh, on)
    end
    if type(SetBoatFrozenWhenAnchored) == 'function' then SetBoatFrozenWhenAnchored(veh, on) end
end

function BN.noSink(veh)
    if type(SetBoatSinksWhenWrecked) == 'function' then SetBoatSinksWhenWrecked(veh, false) end
end

function BN.extra(veh, extra, on)
    Inv(0xBB6F89150BC9D16B, veh, extra, not on)
end

function BN.tint(veh, tint)
    Inv(0x8268B098F6FCA4E2, veh, tint)
end

function BN.livery(veh, livery)
    Inv(0xF89D82A0582E46ED, veh, livery)
end

function BN.addPropset(veh, name)
    Inv(0xC0F0417A90402742, veh, GetHashKey(name))
end

function BN.clearPropsets(veh)
    Inv(0xE31C0CB1C3186D40, veh)
end

-- ------------------------------------------------------------------ peds

function BN.randomOutfit(ped)
    Inv(0x283978A15512B2FE, ped, true)
end

-- ambient speech from an entity; cosmetic, so any failure is ignored
function BN.speak(ped, line)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    pcall(function()
        local params = {
            BN.str(line),
            BN.str(BoatConfig.Keeper.voice),
            1,
            GetHashKey(BoatConfig.Keeper.params),
            0, 1, 1, 1,
        }
        local buf = string.pack('<i8i8i8i8i8i8i8i8', table.unpack(params))
        Inv(0x8E04FEDD28D42462, ped, buf)
    end)
end

-- ------------------------------------------------------------------ models

function BN.loadModel(hash, timeoutMs)
    if not IsModelValid(hash) then return false end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end
