-- pup_tailor | what wearing a clothing item changes. Pure rules, shared (the client runs them).
Tailor = Tailor or {}
local U = Tailor.U
local W = {}
Tailor.Wear = W

local function isTeeth(slot) return type(slot) == 'string' and slot:lower() == 'teeth' end

-- the same slot under vorp_character's spelling, if it has one
local function alias(slot) return Config.VorpAliases[slot] end

local function wornHas(worn, slot)
    if U.isReal(worn[slot]) then return true end
    local a = alias(slot)
    return a ~= nil and U.isReal(worn[a])
end

local function colorFor(map, slot)
    if type(map) ~= 'table' then return nil end
    local c = map[slot]
    if type(c) ~= 'table' and alias(slot) then c = map[alias(slot)] end
    if type(c) ~= 'table' then return nil end
    return c
end

-- the item's real garments: slot -> hash, without the colour map and teeth
function W.itemGarments(outfit)
    local g, n = {}, 0
    for slot, v in pairs(outfit or {}) do
        if type(slot) == 'string' and slot ~= 'colors' and not isTeeth(slot) and U.isReal(v) then
            g[slot] = v
            n = n + 1
        end
    end
    return g, n
end

--[[ args:
  whole  : true for clothingset / pristine_clothingset
  outfit : the item's outfit (may hold .colors)
  dyed   : the item carries a colour map
  sex    : 'male' | 'female' (for default teeth)
  worn   : the character's worn clothing (may hold .colors)
  keep   : the item's Keep Mask & Neckwear flag
 returns { result = slot->hash, colors = slot->{palette,color1,color2,color3},
           putOn = slot->hash, removed = slot->true } ]]
function W.compute(args)
    local worn = {}
    for k, v in pairs(args.worn or {}) do
        if k ~= 'colors' then worn[k] = v end
    end
    local wornColors = type(args.worn) == 'table' and args.worn.colors or nil
    local outfit = type(args.outfit) == 'table' and args.outfit or {}
    local itemColors = args.dyed and outfit.colors or nil

    local garments, n = W.itemGarments(outfit)
    local replaceAll = args.whole == true or n > 1
    local keepActive = args.keep == true and replaceAll

    local result, removed, putOn = {}, {}, {}
    for k, v in pairs(worn) do result[k] = v end

    if replaceAll then
        for slot, v in pairs(worn) do
            if U.isReal(v) and not isTeeth(slot) and not (keepActive and Config.KeepSlots[slot]) then
                result[slot] = -1
                removed[slot] = true
            end
        end
    end

    if args.whole == true then
        local hasTeeth = false
        for slot, v in pairs(result) do
            if isTeeth(slot) and U.isReal(v) then hasTeeth = true end
        end
        if not hasTeeth then
            local t = Config.DefaultTeeth[args.sex == 'female' and 'female' or 'male']
            result.teeth = t
            putOn.teeth = t
        end
    end

    for slot, h in pairs(garments) do
        local skip = keepActive and Config.KeepSlots[slot] and wornHas(worn, slot)
        if not skip then
            result[slot] = h
            putOn[slot] = h
            removed[slot] = nil
            -- the worn data may hold the same slot under VORP's spelling (Armor for armor):
            -- drop that copy, or toVorp could keep the old garment over the new one
            local a = alias(slot)
            if a and a ~= slot and result[a] ~= nil then
                result[a] = nil
                removed[a] = nil
            end
            local other = Config.ConflictSlots[slot]
            if other and garments[other] == nil and U.isReal(result[other]) then
                result[other] = -1
                removed[other] = true
                putOn[other] = nil
            end
        end
    end

    local colors = {}
    for slot, v in pairs(result) do
        if U.isReal(v) then
            if putOn[slot] ~= nil then
                local c = colorFor(itemColors, slot)
                if c then colors[slot] = c end
            else
                local c = colorFor(wornColors, slot)
                if c then colors[slot] = c end
            end
        end
    end

    return { result = result, colors = colors, putOn = putOn, removed = removed }
end

local function copyColor(c)
    return {
        palette = tonumber(c.palette) or 0,
        color1 = tonumber(c.color1) or 0,
        color2 = tonumber(c.color2) or 0,
        color3 = tonumber(c.color3) or 0,
    }
end

-- the result as vorp_character's worn-clothing map (VORP slot names only)
function W.toVorp(result, colors)
    local out = {}
    local function put(name, v)
        local cur = out[name]
        if cur == nil or (not U.isReal(cur) and U.isReal(v)) then out[name] = v end
    end
    for slot, v in pairs(result) do
        if Config.VorpSlots[slot] then put(slot, v) end
        local a = alias(slot)
        if a then put(a, v) end
    end
    if colors and next(colors) then
        local cmap = {}
        for slot, c in pairs(colors) do
            local name = Config.VorpSlots[slot] and slot or alias(slot)
            if name and U.isReal(out[name]) then cmap[name] = copyColor(c) end
        end
        if next(cmap) then out.colors = cmap end
    end
    return out
end

-- tint store update: VORP slot -> { "<hash>": { palette, tint0, tint1, tint2 } } ({} when undyed)
function W.toTints(vorpMap)
    local out, n = {}, 0
    local cmap = vorpMap.colors or {}
    for slot, v in pairs(vorpMap) do
        if slot ~= 'colors' and U.isReal(v) then
            local entry = {}
            local c = cmap[slot]
            if c then
                entry[U.hashKey(v)] = {
                    palette = Tailor.Cat.resolvePalette(c.palette),
                    tint0 = tonumber(c.color1) or 0,
                    tint1 = tonumber(c.color2) or 0,
                    tint2 = tonumber(c.color3) or 0,
                }
            end
            out[slot] = entry
            n = n + 1
        end
    end
    return out, n
end

-- pup_clothing payload: category key -> singleplayer drawable, or false
-- VORP spelling -> our slot name (Armor -> armor), so pup_clothing gets a category key
local unalias = {}
for lower, upper in pairs(Config.VorpAliases) do unalias[upper] = lower end

function W.extras(change, sex)
    local out = {}
    for slot, h in pairs(change.putOn) do
        local cat = Tailor.Cat.categoryFor(unalias[slot] or slot)
        local e = Tailor.Cat.spEntry(sex, h)
        out[cat] = e and e.hash or false
    end
    for slot in pairs(change.removed) do
        local cat = Tailor.Cat.categoryFor(unalias[slot] or slot)
        if out[cat] == nil then out[cat] = false end
    end
    return out
end
