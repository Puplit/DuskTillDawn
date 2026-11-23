-- skinanimals | shared/util.lua
-- Helpers used on both sides. Loaded after config/main.lua and config/animals.lua.
-- Builds one numbered row list from the three animal tables; client and server build the same
-- list from the same files, so a row index means the same row on both sides.

SkinUtil = {}

-- A hash as an unsigned 32-bit integer, or nil when the value is not a whole number
-- inside the 32-bit range (such a value can never match a game hash).
function SkinUtil.u32(v)
    if type(v) ~= 'number' then return nil end
    local i = math.tointeger(v)
    if not i or i < -2147483648 or i > 4294967295 then return nil end
    return i & 0xFFFFFFFF
end

local function present(name)
    return type(name) == 'string' and name ~= ''
end

local function label(name)
    local l = Config.Labels and Config.Labels[name]
    return present(l) and l or name
end

-- rows: { name, model (u32), outfit (u32) or false = any, items = { ids }, legendary }
SkinUtil.list = {}

local function add(name, model, outfit, items, legendary)
    local m = type(model) == 'string' and GetHashKey(model) or model
    m = SkinUtil.u32(m)
    if not m or type(items) ~= 'table' then
        print(('^3[skinanimals]^7 animal row "%s" skipped (bad model or items)'):format(tostring(name)))
        return
    end
    local o = false
    if outfit ~= false and outfit ~= nil then o = SkinUtil.u32(outfit) or false end
    SkinUtil.list[#SkinUtil.list + 1] = {
        name = tostring(name or '?'), model = m, outfit = o, items = items, legendary = legendary == true,
    }
end

-- legendaries first, so their outfit or model match is found before the plain row
for _, r in ipairs(Config.Legendaries or {}) do add(r[1], r[2], r[3], r[4], true) end
for _, model in ipairs(Config.Fish or {}) do add(model, model, false, { model }, false) end
for _, r in ipairs(Config.Animals or {}) do
    local yield = Config.Yields and Config.Yields[r[3]]
    if yield then
        add(r[1], r[2], false, yield, false)
    else
        print(('^3[skinanimals]^7 animal row "%s" names unknown yield "%s"'):format(tostring(r[1]), tostring(r[3])))
    end
end

-- kept for the server's model check
SkinUtil.rows = SkinUtil.list

-- Items a row pays as a list of { name = ..., label = ... } (at most three).
function SkinUtil.rowItems(row)
    local out = {}
    for i = 1, 3 do
        local name = row.items[i]
        if present(name) then out[#out + 1] = { name = name, label = label(name) } end
    end
    return out
end

function SkinUtil.rowIsLegendary(row)
    return row.legendary == true
end

-- Row index for a model and outfit (both as the game reports them), or nil.
-- First a row of that model with the same outfit; otherwise the first "any outfit" row of
-- that model. With anyOutfitFallback off, the any-outfit row is used only when the game
-- reports no outfit (0).
function SkinUtil.findRow(model, outfit)
    local m = SkinUtil.u32(model)
    if not m then return nil end
    local o = SkinUtil.u32(outfit) or 0
    local anyIndex
    for i, r in ipairs(SkinUtil.list) do
        if r.model == m then
            if r.outfit == false then
                anyIndex = anyIndex or i
            elseif o ~= 0 and r.outfit == o then
                return i
            end
        end
    end
    if anyIndex and (Config.Skinning.anyOutfitFallback or o == 0) then return anyIndex end
    return nil
end
