-- pup_gunsmith | part catalogue helpers (client and server)
-- The data is shared/parts.lua (GunParts). It is unpacked once here into
-- owner -> slot -> { { item, label, cash, gold }, ... }; GunParts itself is never changed.

Catalogue = {}

local PARTS <const> = GunParts or {}
local PRICE <const> = PARTS.price or {}

local function unpackSlot(parts)
    local list = {}
    for _, p in ipairs(parts) do
        if type(p) == 'table' then
            local cash, gold = p.cash or PRICE.cash, p.gold or PRICE.gold
            if p.range then
                for n = p.first, p.last do
                    list[#list + 1] = { item = p.range:format(n), label = p.label and p.label:format(n), cash = cash, gold = gold }
                end
            elseif type(p[1]) == 'string' then
                list[#list + 1] = { item = p[1], label = p[2], cash = cash, gold = gold }
            end
        end
    end
    return list
end

local function unpackGroup(src)
    local out = {}
    for owner, slots in pairs(src or {}) do
        local cats = {}
        for slot, parts in pairs(slots) do
            if type(parts) == 'table' then cats[slot] = unpackSlot(parts) end
        end
        out[owner] = cats
    end
    return out
end

local MODELS <const> = unpackGroup(PARTS.models)
local FAMILIES <const> = unpackGroup(PARTS.families)

-- which weapon names may take each family's shared parts
local FAMILY_PREFIXES <const> = {
    SHORTARM    = { 'WEAPON_REVOLVER_', 'WEAPON_PISTOL_' },
    LONGARM     = { 'WEAPON_REPEATER_', 'WEAPON_RIFLE_', 'WEAPON_SNIPERRIFLE_', 'WEAPON_SHOTGUN_' },
    SHOTGUN     = { 'WEAPON_SHOTGUN_' },
    MELEE_BLADE = { 'WEAPON_MELEE_', 'WEAPON_THROWN_', 'WEAPON_MACHETE' },
}

-- upper-cased model name -> the catalogue's own key (keys are compared ignoring case)
local modelKeyByUpper = {}
for key in pairs(MODELS) do modelKeyByUpper[key:upper()] = key end

function Catalogue.modelKey(weaponName)
    if type(weaponName) ~= 'string' then return nil end
    return modelKeyByUpper[weaponName:upper()]
end

function Catalogue.familyFits(family, weaponName)
    local prefixes = FAMILY_PREFIXES[family or '']
    if not prefixes or type(weaponName) ~= 'string' then return false end
    local up = weaponName:upper()
    for _, p in ipairs(prefixes) do
        if up:sub(1, #p) == p then return true end
    end
    return false
end

function Catalogue.isFamily(family)
    return FAMILY_PREFIXES[family or ''] ~= nil
end

-- the price a part costs at the bench; the config override replaces the catalogue price
local function priceOf(variant)
    local cash = Config.Bench.partCash
    local gold = Config.Bench.partGold
    if cash == nil then cash = variant.cash end
    if gold == nil then gold = variant.gold end
    cash = math.max(0, math.floor(tonumber(cash) or 0))
    gold = math.max(0, math.floor(tonumber(gold) or 0))
    return cash, gold
end

local function addCategories(out, seen, source)
    for cat, list in pairs(source or {}) do
        if type(cat) == 'string' and type(list) == 'table' then
            local ucat = cat:upper()
            out[ucat] = out[ucat] or {}
            seen[ucat] = seen[ucat] or {}
            for _, v in ipairs(list) do
                if type(v) == 'table' and type(v.item) == 'string' then
                    local item = v.item:upper()
                    if not seen[ucat][item] then
                        seen[ucat][item] = true
                        local cash, gold = priceOf(v)
                        out[ucat][#out[ucat] + 1] = { item = item, label = v.label, cash = cash, gold = gold }
                    end
                end
            end
        end
    end
end

--- The parts a gun can take: its model's own parts plus its family's shared parts
--- (the family only counts when it fits the weapon name). Empty categories are dropped.
---@return table<string, table[]>
function Catalogue.build(weaponName, family)
    local out, seen = {}, {}
    local key = Catalogue.modelKey(weaponName)
    if key then addCategories(out, seen, MODELS[key]) end
    if family and Catalogue.familyFits(family, weaponName) then
        addCategories(out, seen, FAMILIES[family])
    end
    for cat, list in pairs(out) do
        if #list == 0 then out[cat] = nil end
    end
    return out
end

function Catalogue.find(cat, item, catalogue)
    local list = catalogue and catalogue[cat]
    if not list then return nil end
    for i, v in ipairs(list) do
        if v.item == item then return v, i end
    end
    return nil
end

function Catalogue.isTint(cat)
    return type(cat) == 'string' and cat:sub(-5) == '_TINT'
end

-- the bench tab a category belongs to
function Catalogue.tabOf(cat)
    if cat:sub(-5) == '_TINT' then return 'tints' end
    if cat:find('ENGRAVING', 1, true) then return 'engraving' end
    if cat:sub(-9) == '_MATERIAL' then return 'finish' end
    return 'parts'
end

-- the first GRIP of a model is its default grip
function Catalogue.defaultGrip(weaponName)
    local key = Catalogue.modelKey(weaponName)
    local grips = key and MODELS[key].GRIP
    if type(grips) == 'table' and grips[1] and grips[1].item then return grips[1].item:upper() end
    return nil
end

function Catalogue.modelGrips(weaponName)
    local out = {}
    local key = Catalogue.modelKey(weaponName)
    local grips = key and MODELS[key].GRIP
    if type(grips) == 'table' then
        for _, v in ipairs(grips) do
            if v.item then out[#out + 1] = v.item:upper() end
        end
    end
    return out
end

-- weapon hash -> catalogue model key (for the equip refit, which only knows the hash)
local modelByHash = nil
function Catalogue.modelByHash(hash)
    if not modelByHash then
        modelByHash = {}
        for key in pairs(MODELS) do modelByHash[joaat(key:upper()) & 0xFFFFFFFF] = key end
    end
    local h = math.tointeger(hash)
    if not h then return nil end
    return modelByHash[h & 0xFFFFFFFF]
end

-- every component -> all variants of the catalogue list it sits in (built once)
local variantsOf = nil
function Catalogue.variantsOf(item)
    if not variantsOf then
        variantsOf = {}
        local function index(src)
            for _, cats in pairs(src) do
                for _, list in pairs(cats) do
                    if type(list) == 'table' then
                        local group = {}
                        for _, v in ipairs(list) do
                            if type(v) == 'table' and v.item then group[#group + 1] = v.item:upper() end
                        end
                        for _, it in ipairs(group) do
                            local bucket = variantsOf[it] or {}
                            local have = {}
                            for _, x in ipairs(bucket) do have[x] = true end
                            for _, x in ipairs(group) do
                                if not have[x] then bucket[#bucket + 1] = x; have[x] = true end
                            end
                            variantsOf[it] = bucket
                        end
                    end
                end
            end
        end
        index(MODELS)
        index(FAMILIES)
    end
    return variantsOf[item] or { item }
end
