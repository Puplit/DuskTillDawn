-- pup-misc / interactions | helpers shared by the config files and client/interactions/main.lua
-- Loads first so anything below can use InteractionsUtil. The config itself only holds plain data
-- (model names, scenario names, gate tags), so nothing here is needed while the config loads.

InteractionsUtil = {}
local U = InteractionsUtil

-- natives answer true/false or 1/0 depending on how they are called
local function yes(v) return v == true or v == 1 end
U.yes = yes

-- run a native that may not exist on every build; a failure counts as "no"
local function safe(fn, ...)
    local ok, v = pcall(fn, ...)
    return ok and yes(v)
end

local function invokeFlag(hash, ped)
    local ok, v = pcall(Citizen.InvokeNative, hash, ped, Citizen.ResultAsInteger())
    return ok and v ~= nil and v ~= 0 and v ~= false
end
U.invokeFlag = invokeFlag

-------------------------------------------------------------------------------
-- MODEL HASHES
-- Model lists may hold names ('p_chair02x'), backtick hashes, or numbers that are signed or
-- unsigned. Everything is reduced to one unsigned 32-bit form before comparing.
-------------------------------------------------------------------------------
function U.hash(v)
    local t = type(v)
    if t == 'number' then
        local i = math.tointeger(v)
        if not i then return nil end
        return i & 0xFFFFFFFF
    elseif t == 'string' then
        local n = tonumber(v)
        if n then return U.hash(n) end
        return GetHashKey(v) & 0xFFFFFFFF
    end
    return nil
end

-- the signed form, for natives that take a model hash argument
function U.signed(h)
    if h >= 0x80000000 then return h - 0x100000000 end
    return h
end

-------------------------------------------------------------------------------
-- PED CHECKS
-------------------------------------------------------------------------------
function U.isHuman(ped) return safe(IsPedHuman, ped) end
function U.isMale(ped) return safe(IsPedMale, ped) end
-- child peds; the native is checked in game (see BUILDLOG)
function U.isChild(ped) return invokeFlag(0x137772000DAF42C5, ped) end

-- gate tags used by the config: on whole entries (`ped = 'adult'`) and on single actions
local GATES = {
    any          = function() return true end,
    human        = function(p) return U.isHuman(p) end,
    adult        = function(p) return U.isHuman(p) and not U.isChild(p) end,
    child        = function(p) return U.isHuman(p) and U.isChild(p) end,
    male         = function(p) return U.isHuman(p) and U.isMale(p) end,
    female       = function(p) return U.isHuman(p) and not U.isMale(p) end,
    adult_male   = function(p) return U.isHuman(p) and not U.isChild(p) and U.isMale(p) end,
    adult_female = function(p) return U.isHuman(p) and not U.isChild(p) and not U.isMale(p) end,
}
GATES.none = GATES.any

local warned = {}

-- nil passes; a tag is looked up above; a function is the owner's own check (called with the ped)
function U.fits(gate, ped)
    if gate == nil then return true end
    if type(gate) == 'function' then
        local ok, v = pcall(gate, ped)
        return ok and v == true
    end
    local check = GATES[gate]
    if not check then
        if not warned[gate] then
            warned[gate] = true
            print(('^3[pup-misc/interactions]^7 unknown ped gate "%s" (entry hidden)'):format(tostring(gate)))
        end
        return false
    end
    return check(ped)
end

-------------------------------------------------------------------------------
-- STATES THAT BLOCK THE MENU
-------------------------------------------------------------------------------
function U.isHogtied(ped)
    return invokeFlag(0x3AA24CCC0D451379, ped) or safe(IsPedBeingHogtied, ped)
end
function U.isCuffed(ped) return invokeFlag(0x74E559B3BC910685, ped) end
function U.isLeadingHorse(ped) return invokeFlag(0xEFC4303DDC6E60D3, ped) end
function U.isRagdoll(ped) return safe(IsPedRagdoll, ped) end
function U.isFalling(ped) return safe(IsPedFalling, ped) end
function U.isSwimming(ped) return safe(IsPedSwimming, ped) end
function U.isOnFire(ped) return safe(IsEntityOnFire, ped) end
function U.isDead(ped) return safe(IsPedDeadOrDying, ped, true) or safe(IsEntityDead, ped) end
function U.inCombat(ped) return safe(IsPedInCombat, ped, 0) or safe(IsPedInMeleeCombat, ped) end
function U.onMountOrVehicle(ped)
    return safe(IsPedOnMount, ped) or safe(IsPedInAnyVehicle, ped, false)
end

-- a pup-stable wagon close by owns the key there
function U.stableWagonNear(coords, radius, bagName)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(veh) - coords) <= radius then
            local ok, tag = pcall(function() return Entity(veh).state[bagName] end)
            if ok and tag then return true end
        end
    end
    return false
end
