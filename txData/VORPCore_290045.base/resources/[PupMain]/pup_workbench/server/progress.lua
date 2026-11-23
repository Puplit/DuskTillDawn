-- Per-character experience (characters.crafting) and favourites (workbench_favourites).
Progress = {}

-- EXPERIENCE
local function baseXp()
    local t = {}
    for _, k in ipairs(Config.BaseXpCategories) do t[k] = 0 end
    return t
end

local function fillCategories(t)
    for _, c in ipairs(Config.Categories) do
        if type(t[c.key]) ~= 'number' then t[c.key] = tonumber(t[c.key]) or 0 end
    end
    return t
end

local function readRaw(charid)
    local raw = MySQL.scalar.await('SELECT crafting FROM characters WHERE charidentifier = ?', { charid })
    local t
    if type(raw) == 'string' and raw ~= '' then
        local ok, dec = pcall(json.decode, raw)
        if ok and type(dec) == 'table' then t = dec end
    end
    return t or baseXp()
end

function Progress.getXp(charid)
    local ok, t = pcall(readRaw, charid)
    if not ok then
        Warn('experience for %s could not be read: %s', tostring(charid), tostring(t))
        t = baseXp()
    end
    return fillCategories(t)
end

-- one writer per character at a time: a gain waits for the one before it to land,
-- so two crafts finishing together never overwrite each other
local xpBusy = {}

function Progress.addXp(charid, category, amount)
    amount = WB.int(amount)
    if not amount or amount <= 0 or type(category) ~= 'string' or category == '' then return end
    local waited = 0
    while xpBusy[charid] and waited < 10000 do
        Wait(25)
        waited = waited + 25
    end
    xpBusy[charid] = true
    local ok, err = pcall(function()
        local t = readRaw(charid)
        t[category] = (tonumber(t[category]) or 0) + amount
        MySQL.update.await('UPDATE characters SET crafting = ? WHERE charidentifier = ?', { json.encode(t), charid })
    end)
    xpBusy[charid] = nil
    if not ok then Warn('experience for %s could not be saved: %s', tostring(charid), tostring(err)) end
end

-- FAVOURITES
function Progress.getFavourites(charid)
    local raw = MySQL.scalar.await('SELECT ids FROM workbench_favourites WHERE charid = ?', { charid })
    if type(raw) ~= 'string' then return {} end
    local ok, dec = pcall(json.decode, raw)
    if not ok or type(dec) ~= 'table' then return {} end
    local out = {}
    for _, v in ipairs(dec) do
        local n = WB.int(v)
        if n then out[#out + 1] = n end
    end
    return out
end

function Progress.cleanFavourites(ids)
    local out, seen = {}, {}
    if type(ids) ~= 'table' then return out end
    for _, v in ipairs(ids) do
        local n = WB.int(v)
        if n and Recipes.byId[n] and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
            if #out >= 200 then break end
        end
    end
    return out
end

function Progress.saveFavourites(charid, ids)
    local clean = Progress.cleanFavourites(ids)
    MySQL.query.await('INSERT INTO workbench_favourites (charid, ids) VALUES (?, ?) ON DUPLICATE KEY UPDATE ids = VALUES(ids)',
        { charid, json.encode(clean) })
    return clean
end

-- ONE-TIME MIGRATION from the legacy crafting_fav table
local MIGRATED_KEY <const> = 'pup_workbench:favourites_migrated'

function Progress.migrateFavourites()
    if GetResourceKvpInt(MIGRATED_KEY) == 1 then return end
    if not DB.tableExists('crafting_fav') then
        SetResourceKvpInt(MIGRATED_KEY, 1)
        return
    end
    local ordered = MySQL.query.await('SELECT id FROM crafting_recipes ORDER BY id') or {}
    local byPos = {}
    for i, row in ipairs(ordered) do byPos[i] = tonumber(row.id) end

    local rows = MySQL.query.await('SELECT charidentifier, favo FROM crafting_fav') or {}
    local carried = 0
    for _, row in ipairs(rows) do
        local charid = WB.int(row.charidentifier)
        local ok, list = pcall(json.decode, tostring(row.favo or '[]'))
        if charid and ok and type(list) == 'table' then
            local ids, seen = {}, {}
            for _, pos in ipairs(list) do
                local id = byPos[WB.int(pos) or 0]
                if id and not seen[id] then
                    seen[id] = true
                    ids[#ids + 1] = id
                end
            end
            local n = MySQL.update.await('INSERT IGNORE INTO workbench_favourites (charid, ids) VALUES (?, ?)',
                { charid, json.encode(ids) })
            if (tonumber(n) or 0) > 0 then carried = carried + 1 end
        end
    end
    SetResourceKvpInt(MIGRATED_KEY, 1)
    print(('[pup_workbench] carried over favourites for %d characters from crafting_fav'):format(carried))
end
