-- The tradeable item catalogue and the "plain stack" rules.

Items = {
    list = {},     -- sorted { name, label, lower }
    byName = {},   -- name -> entry
    storageBlock = {}, -- lower-case names kept out of market storage (exact names + prefix matches)
}

local blockedNames = {}
for _, n in ipairs(Config.Blacklist.names) do blockedNames[n:lower()] = true end

local function blocked(name)
    local lower = name:lower()
    if blockedNames[lower] then return true end
    for _, p in ipairs(Config.Blacklist.prefixes) do
        local pl = p:lower()
        if lower:sub(1, #pl) == pl then return true end
    end
    return false
end

function Items.Load()
    local rows = MySQL.query.await('SELECT `item`, `label` FROM `items`') or {}
    local list, byName, block = {}, {}, {}
    for n in pairs(blockedNames) do block[n] = true end
    for _, row in ipairs(rows) do
        local name = row.item
        if type(name) == 'string' and name ~= '' then
            if blocked(name) then
                block[name:lower()] = true
            elseif not byName[name] then
                local label = (type(row.label) == 'string' and row.label ~= '') and row.label or name
                local entry = { name = name, label = label, lower = label:lower() }
                list[#list + 1] = entry
                byName[name] = entry
            end
        end
    end
    table.sort(list, function(a, b)
        if a.lower == b.lower then return a.name < b.name end
        return a.lower < b.lower
    end)
    Items.list, Items.byName, Items.storageBlock = list, byName, block
    print(('[pup_tradepost] catalogue: %d tradeable items'):format(#list))
end

function Items.Get(name)
    if type(name) ~= 'string' then return nil end
    return Items.byName[name]
end

-- case-insensitive label match or item-name match, first N in label order
function Items.Search(text, limit)
    limit = limit or Config.Limits.catalogueResults
    text = type(text) == 'string' and text:lower() or ''
    local out = {}
    for _, e in ipairs(Items.list) do
        if text == '' or e.lower:find(text, 1, true) or e.name:lower():find(text, 1, true) then
            out[#out + 1] = e
            if #out >= limit then break end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- plain stacks: no metadata, no wear, and in the catalogue
---------------------------------------------------------------------------
local function isPlain(it)
    if type(it) ~= 'table' or type(it.name) ~= 'string' then return false end
    if not Items.byName[it.name] then return false end
    if it.isDegradable then return false end
    local md = it.metadata
    if md ~= nil and (type(md) ~= 'table' or next(md) ~= nil) then return false end
    return (tonumber(it.count) or 0) > 0
end

local function inventory(src)
    local ok, inv = pcall(function() return exports.vorp_inventory:getUserInventoryItems(src) end)
    if not ok or type(inv) ~= 'table' then return {} end
    return inv
end

-- { [name] = total } over plain stacks
function Items.PlainCounts(src)
    local counts = {}
    for _, it in ipairs(inventory(src)) do
        if isPlain(it) then
            counts[it.name] = (counts[it.name] or 0) + math.floor(tonumber(it.count) or 0)
        end
    end
    return counts
end

function Items.PlainCount(src, name)
    return Items.PlainCounts(src)[name] or 0
end

-- Removes qty units of one item from plain stacks only (never a named or worn
-- stack). Reading and removing happen in the same tick, so nothing can change
-- the stacks in between. Returns true when all qty were removed.
function Items.TakePlain(src, name, qty)
    local stacks, total = {}, 0
    for _, it in ipairs(inventory(src)) do
        if it.name == name and isPlain(it) then
            stacks[#stacks + 1] = { id = it.id, count = math.floor(tonumber(it.count) or 0) }
            total = total + stacks[#stacks].count
        end
    end
    if total < qty then return false end

    -- smallest stacks first keeps the inventory tidy
    table.sort(stacks, function(a, b) return a.count < b.count end)
    local left = qty
    for _, s in ipairs(stacks) do
        if left <= 0 then break end
        local take = math.min(s.count, left)
        local ok, done = pcall(function()
            return exports.vorp_inventory:subItemById(src, s.id, nil, false, take)
        end)
        if not ok or done == false then
            -- put back whatever this call already took, then give up
            local taken = qty - left
            if taken > 0 then Items.Give(src, name, taken) end
            return false
        end
        left = left - take
    end
    return true
end

-- gives plain units to a player's inventory; true on success
function Items.Give(src, name, qty)
    local ok, done = pcall(function()
        return exports.vorp_inventory:addItem(src, name, qty)
    end)
    return ok and done ~= false
end

function Items.CanCarry(src, name, qty)
    local ok, yes = pcall(function()
        return exports.vorp_inventory:canCarryItem(src, name, qty)
    end)
    return ok and yes == true
end
