-- pup_tailor | the garment catalogue, slot names, palettes and prices. Shared, pure Lua.
-- Built from the data files cloth_hash_names.lua (multiplayer), npc_clothing.lua (singleplayer)
-- and palettes.lua. The ORDER of every category list is what the tailor numbers mean.
Tailor = Tailor or {}
local U = Tailor.U
local C = {}
Tailor.Cat = C

C.SEXES = { 'male', 'female' }

---------------------------------------------------------------------------
-- slots and categories
---------------------------------------------------------------------------
C.slotToCategory = {}
for cat, slot in pairs(Config.CategorySlot) do C.slotToCategory[slot] = cat end

C.itemCategory = {}
for _, cat in ipairs(Config.ItemCategories) do C.itemCategory[cat] = true end

function C.slotFor(cat)
    return Config.CategorySlot[cat] or cat
end

function C.categoryFor(slot)
    return C.slotToCategory[slot] or slot
end

function C.label(cat)
    return Config.CategoryLabels[cat]
end

-- game category hash for a slot: fixed table, then the data file's table, then the slot's own hash
function C.categoryHash(slot)
    local h = Config.SlotCategoryHash[slot]
    if h then return h end
    local cat = C.categoryFor(slot)
    local t = NPC_CLOTHING_CATEGORY_HASH
    if t and t[cat] then return t[cat] end
    if GetHashKey then return GetHashKey(slot) end
    return nil
end

---------------------------------------------------------------------------
-- palettes
---------------------------------------------------------------------------
C.palettes = {}
C.paletteSet = {}
for i, h in ipairs(PUP_PALETTES or {}) do
    local u = U.unsigned(h)
    C.palettes[i] = u
    C.paletteSet[u] = i
end

-- a stored palette value -> the hash to tint with. <= 25 is an index from an old item.
function C.resolvePalette(v)
    local n = U.int(v)
    if n and n >= 0 and n <= 25 then
        return C.palettes[n] or C.palettes[1]
    end
    return U.unsigned(v) or C.palettes[1]
end

---------------------------------------------------------------------------
-- singleplayer data: fold the extra rows in once (append to the end of each list)
---------------------------------------------------------------------------
local merged = false
local function mergeExtras()
    if merged or type(NPC_CLOTHING) ~= 'table' then return end
    merged = true
    NPC_CLOTHING_CATEGORY_HASH = NPC_CLOTHING_CATEGORY_HASH or {}
    for _, list in ipairs({ NPC_CLOTHING_UNIQUE or {}, NPC_CLOTHING_EXTRA or {} }) do
        for _, r in ipairs(list) do
            if r.cat and r.sex then
                if NPC_CLOTHING_CATEGORY_HASH[r.cat] == nil then NPC_CLOTHING_CATEGORY_HASH[r.cat] = r.h end
                local bySex = NPC_CLOTHING[r.sex]
                if bySex then
                    local l = bySex[r.cat]
                    if not l then l = {}; bySex[r.cat] = l end
                    l[#l + 1] = { d = r.d, a = r.a, n = r.n, m = r.m, p = r.p, t = r.t, cost = r.cost }
                end
            end
        end
    end
end

local function spCategoryHidden(cat)
    if Config.HiddenSPCategories[cat] then return true end
    if Config.HideUnnamedCategories and cat:sub(1, 9) == 'research_' then return true end
    return false
end

local function spDrawableHidden(d)
    local hidden = Config.HiddenSPDrawables
    if not hidden or next(hidden) == nil then return false end
    if hidden[d] then return true end
    local s, u = U.signed(d), U.unsigned(d)
    return (s and hidden[s]) or (u and hidden[u]) or false
end

---------------------------------------------------------------------------
-- the base catalogue (before staff-hidden garments)
-- base[sex][cat] = { entry, ... } where an entry is
--   { mp = true, hash = <unsigned>, cat = cat }
--   { sp = true, hash = <drawable as in the data>, key = <unsigned drawable>, cat = cat, row = row }
---------------------------------------------------------------------------
local base = nil
C.spIndex = { male = {}, female = {} }  -- [sex][unsigned drawable] = entry

function C.buildBase()
    if base then return base end
    mergeExtras()
    base = { male = {}, female = {} }

    -- multiplayer, from the last row of the file to the first
    local mpList = cloth_hash_names
    if type(mpList) == 'table' then
        for i = #mpList, 1, -1 do
            local e = mpList[i]
            if type(e) == 'table' and e.is_multiplayer then
                local cat = string.lower(tostring(e.category_hashname or ''))
                local sex = e.ped_type
                local h = U.unsigned(e.hash)
                if not Config.BodyPartCategories[cat] and h and base[sex] then
                    local list = base[sex][cat]
                    if not list then list = {}; base[sex][cat] = list end
                    list[#list + 1] = { mp = true, hash = h, key = h, cat = cat }
                end
            end
        end
    end

    -- singleplayer, appended after the multiplayer garments of the same category, in file order
    if type(NPC_CLOTHING) == 'table' then
        for _, sex in ipairs(C.SEXES) do
            for cat, rows in pairs(NPC_CLOTHING[sex] or {}) do
                if not spCategoryHidden(cat) then
                    for _, row in ipairs(rows) do
                        local key = U.unsigned(row.d)
                        if key and not spDrawableHidden(row.d) then
                            local list = base[sex][cat]
                            if not list then list = {}; base[sex][cat] = list end
                            local entry = { sp = true, hash = row.d, key = key, cat = cat, row = row }
                            list[#list + 1] = entry
                            C.spIndex[sex][key] = entry
                        end
                    end
                end
            end
        end
    end
    return base
end

-- the catalogue a player sees: base minus staff-hidden drawables (compared signed and unsigned)
-- hiddenSet is keyed by the UNSIGNED drawable
function C.build(hiddenSet)
    local b = C.buildBase()
    local out = { male = {}, female = {} }
    for _, sex in ipairs(C.SEXES) do
        for cat, list in pairs(b[sex]) do
            local l = {}
            for _, e in ipairs(list) do
                if not (e.sp and hiddenSet and hiddenSet[e.key]) then l[#l + 1] = e end
            end
            if #l > 0 then out[sex][cat] = l end
        end
    end
    return out
end

-- is this garment value a singleplayer garment for this sex? returns the entry
function C.spEntry(sex, value)
    local key = U.unsigned(value)
    if not key then return nil end
    return C.spIndex[sex] and C.spIndex[sex][key]
end

---------------------------------------------------------------------------
-- price list (server) and garment ownership: which sex and slot a hash belongs to
---------------------------------------------------------------------------
local prices, owners = nil, nil

local function normCost(cost)
    if type(cost) ~= 'table' then return nil end
    local items = {}
    for _, it in ipairs(cost.items or {}) do
        local cnt = U.int(it.count)
        if type(it.name) == 'string' and cnt and cnt > 0 then
            items[#items + 1] = { name = it.name, label = it.label or it.name, count = cnt }
        end
    end
    return { cash = tonumber(cost.cash) or 0, items = items }
end

function C.buildPrices()
    if prices then return prices, owners end
    mergeExtras()
    prices, owners = {}, {}
    local function own(h, sex, cat)
        local o = owners[h]
        if not o then o = {}; owners[h] = o end
        o[sex .. '|' .. C.slotFor(cat)] = true
    end
    if type(cloth_hash_names) == 'table' then
        for _, e in ipairs(cloth_hash_names) do
            if type(e) == 'table' and e.is_multiplayer then
                local cat = string.lower(tostring(e.category_hashname or ''))
                local h = U.unsigned(e.hash)
                local cost = normCost(e.cost)
                if h and cost and not Config.BodyPartCategories[cat] then
                    prices[h] = cost
                    if e.ped_type == 'male' or e.ped_type == 'female' then own(h, e.ped_type, cat) end
                end
            end
        end
    end
    local defaultCost = normCost(NPC_CLOTHING_COST)
    if type(NPC_CLOTHING) == 'table' then
        for _, sex in ipairs(C.SEXES) do
            for cat, rows in pairs(NPC_CLOTHING[sex] or {}) do
                if not spCategoryHidden(cat) then
                    for _, row in ipairs(rows) do
                        local h = U.unsigned(row.d)
                        if h and not spDrawableHidden(row.d) then
                            local cost = normCost(row.cost) or defaultCost
                            if cost then prices[h] = cost end
                            own(h, sex, cat)
                        end
                    end
                end
            end
        end
    end
    return prices, owners
end

function C.price(hash)
    local p = C.buildPrices()
    local h = U.unsigned(hash)
    return h and p[h] or nil
end

function C.belongs(hash, sex, slot)
    local _, o = C.buildPrices()
    local h = U.unsigned(hash)
    local set = h and o[h]
    return set ~= nil and set[sex .. '|' .. slot] == true
end

-- the garment belongs to this sex in any slot (worn data uses VORP's slot spelling)
function C.belongsSex(hash, sex)
    local _, o = C.buildPrices()
    local h = U.unsigned(hash)
    local set = h and o[h]
    if not set then return false end
    local prefix = sex .. '|'
    for k in pairs(set) do
        if k:sub(1, #prefix) == prefix then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- which slots of an item's outfit may be dyed (used by the page AND checked by the server)
---------------------------------------------------------------------------
function C.dyeableSlots(outfit, itemName)
    local out = {}
    if type(outfit) ~= 'table' then return out end
    for slot, value in pairs(outfit) do
        if type(slot) == 'string' and slot ~= 'colors' and U.isReal(value) then
            local cat = C.categoryFor(slot)
            local lower = slot:lower()
            local ok = lower ~= 'teeth' and C.label(cat) ~= nil
            if ok and slot == 'Mask' and not Config.MaskItems[itemName] then ok = false end
            if ok and slot == 'NeckWear' and not Config.NeckwearItems[itemName] then ok = false end
            if ok then out[slot] = { slot = slot, cat = cat, label = C.label(cat), hash = value } end
        end
    end
    return out
end

-- dye cost for n garments: [{ name, label, count }] in config order
function C.dyeCost(n)
    local list = {}
    if n <= 0 then return list end
    local idx = {}
    local function add(m, mult)
        local cnt = (U.int(m.count) or 0) * mult
        if cnt <= 0 then return end
        if idx[m.name] then
            idx[m.name].count = idx[m.name].count + cnt
        else
            local e = { name = m.name, label = m.label or m.name, count = cnt }
            idx[m.name] = e
            list[#list + 1] = e
        end
    end
    for _, m in ipairs(Config.DyeMaterials.flat or {}) do add(m, 1) end
    for _, m in ipairs(Config.DyeMaterials.perGarment or {}) do add(m, n) end
    return list
end
