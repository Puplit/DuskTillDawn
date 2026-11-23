-- pup_armory | one lookup for both sides: Armory.get(item) -> definition

Armory = { list = {} }
local byItem = {}

-- the saved-position slots each kind has, in the order the editor offers them
local SLOTS <const> = {
    blade  = { 'worn', 'hand' },
    knife  = { 'worn', 'hand' },
    blunt  = { 'worn', 'hand' },
    shield = { 'worn' },
}

-- a kind with no hold style given falls back to the obvious one
local DEFAULT_HOLD <const> = { blade = 'blade', knife = 'knife', blunt = 'club' }

local function warn(def, msg) print(('^3[pup_armory]^7 %s: %s'):format(tostring(def.item), msg)) end

local function register(def)
    if type(def.item) ~= 'string' or byItem[def.item] then return end
    def.slots = SLOTS[def.kind]
    if not def.slots then return warn(def, ('unknown kind "%s" - skipped'):format(tostring(def.kind))) end

    -- the short format: carry / hold style names stand in for bone + positions
    local carry = def.carry or (def.kind == 'shield' and 'arm' or 'back')
    local style = Config.CarryStyles[carry]
    if not style then return warn(def, ('unknown carry "%s" - skipped'):format(tostring(carry))) end
    def.bone = def.bone or style.bone
    def.worn = def.worn or style.pos
    if def.kind ~= 'shield' then
        local hold = def.hold or DEFAULT_HOLD[def.kind]
        def.hand = def.hand or Config.HoldStyles[hold]
        if not def.hand then return warn(def, ('unknown hold "%s" - skipped'):format(tostring(hold))) end
    end
    byItem[def.item] = def
    Armory.list[#Armory.list + 1] = def
end

for _, w in ipairs(Config.Weapons or {}) do register(w) end

function Armory.get(item) return byItem[item] end

-- the in-hand position is staff-only unless Config.Rules.playersEditHand
function Armory.handLocked(slot)
    return slot == 'hand' and not (Config.Rules and Config.Rules.playersEditHand)
end

-- the base weapon a definition is swung as (nil for shields)
function Armory.baseWeapon(def)
    if def.kind == 'shield' then return nil end
    if def.base then return def.base end
    return Config.BaseWeapons[def.kind]
end

function Armory.default(def, slot)
    local server = GlobalState.pup_armory_defaults
    local saved = server and server[def.item] and server[def.item][slot]
    if saved then return saved end
    return def[slot]
end

-- a saved position must be six numbers and stay near the body
function Armory.validOffset(o)
    if type(o) ~= 'table' then return false end
    local lim = Config.Rules.maxOffset
    for i = 1, 6 do
        local v = tonumber(o[i])
        if not v or v ~= v then return false end
        if i <= 3 and math.abs(v) > lim then return false end
        if i > 3 and math.abs(v) > 720 then return false end
    end
    return true
end
