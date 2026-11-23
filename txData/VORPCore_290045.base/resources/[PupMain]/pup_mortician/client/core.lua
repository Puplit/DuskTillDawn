-- pup_mortician | client plumbing: the request channel, tips, loaders, prompts
-- and small ped helpers shared by the other client files.

Core = exports.vorp_core:GetCore()
RES = GetCurrentResourceName()

-- what the server last told us
Status = { undertaker = false, job = nil, charId = nil, left = 0, limit = 0, posting = nil }
TableStates = {}
Busy = false

function Tip(text)
    if text and text ~= '' then TriggerEvent('vorp:TipRight', text, 5000) end
end

-- one request to the server; never hangs (10 s cap)
function Act(action, payload)
    local p = promise.new()
    local done = false
    Core.Callback.TriggerAsync('pup_mortician:act', function(res)
        if done then return end
        done = true
        p:resolve(type(res) == 'table' and res or { ok = false, quiet = true })
    end, action, payload or {})
    SetTimeout(10000, function()
        if done then return end
        done = true
        p:resolve({ ok = false, quiet = true })
    end)
    return Citizen.Await(p)
end

-- shows the reply's message unless it is marked quiet
function Say(res)
    if res and not res.quiet and res.msg then Tip(res.msg) end
end

---------------------------------------------------------------------------
-- Loaders
---------------------------------------------------------------------------
function LoadModel(name)
    local hash = type(name) == 'number' and name or joaat(name)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(25) end
    return HasModelLoaded(hash) and hash or nil
end

function LoadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(25) end
    return HasAnimDictLoaded(dict)
end

function DeleteObj(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

---------------------------------------------------------------------------
-- Prompts
---------------------------------------------------------------------------
local function varString(text)
    return CreateVarString(10, 'LITERAL_STRING', text)
end
VarString = varString

function MakePrompt(control, text, group)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, control)
    PromptSetText(p, varString(text))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

function ShowGroup(group, title)
    PromptSetActiveGroupThisFrame(group, varString(title))
end

---------------------------------------------------------------------------
-- Peds
---------------------------------------------------------------------------
-- the dead, human, non-player ped the player carries, or nil
function CarriedCorpse()
    local ped = PlayerPedId()
    local ent = Citizen.InvokeNative(0xD806CD2A4F2C2996, ped) -- GET_FIRST_ENTITY_PED_IS_CARRYING
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if not IsEntityAPed(ent) or IsPedAPlayer(ent) or not IsPedHuman(ent) then return nil end
    if not IsEntityDead(ent) then return nil end
    return ent
end

-- makes sure the entity is networked (up to 1.5 s) and returns its net id
function EnsureNetworked(ent)
    if not NetworkGetEntityIsNetworked(ent) then
        NetworkRegisterEntityAsNetworked(ent)
        local t = GetGameTimer() + 1500
        while not NetworkGetEntityIsNetworked(ent) and GetGameTimer() < t do Wait(50) end
    end
    if not NetworkGetEntityIsNetworked(ent) then return nil end
    return NetworkGetNetworkIdFromEntity(ent)
end

function PlayerBusyBody()
    local ped = PlayerPedId()
    return IsPedDeadOrDying(ped, true) or IsPedOnMount(ped) or IsPedSwimming(ped)
        or IsPedClimbing(ped) or IsPedFalling(ped)
end

-- pup-perks shortens timed actions; without it nothing changes
function PerkTimed(ms)
    if GetResourceState('pup-perks') ~= 'started' then return ms end
    local ok, v = pcall(function() return exports['pup-perks']:Timed(ms, 'dig_speed') end)
    v = ok and tonumber(v) or nil
    if not v or v <= 0 then return ms end
    return v
end

-- a pup-ui progress bar that the caller waits on
function ProgressWait(label, ms)
    local p = promise.new()
    local done = false
    local function finish()
        if done then return end
        done = true
        p:resolve(true)
    end
    local ok = pcall(function() exports['pup-ui']:Progress({ label = label, duration = ms }, finish) end)
    SetTimeout(ms + (ok and 1500 or 0), finish)
    Citizen.Await(p)
end

-- map blips
function AddBlip(pos, label, scale)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, Config.BlipStyle, pos.x, pos.y, pos.z) -- BLIP_ADD_FOR_COORDS
    SetBlipSprite(blip, Config.BlipSprite, true)
    if scale then Citizen.InvokeNative(0xD38744167B2FA257, blip, scale) end -- SET_BLIP_SCALE
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, varString(label)) -- SET_BLIP_NAME
    return blip
end

function DropBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end
