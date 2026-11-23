-- pup_homestead | plants in memory and in the database (one row per plant)
-- State changes (water, feed, trim, health) are written as they happen. The growth
-- countdown ticks in memory and is written in batches, so a crash loses minutes at most.
Store = { plants = {}, ready = false }

local dirty = {}
local MIGRATED <const> = 'pup_homestead:migrated'

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS homestead_plants (
        id INT NOT NULL AUTO_INCREMENT,
        charid INT NOT NULL,
        crop VARCHAR(48) NOT NULL,
        x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
        minutes_left INT NOT NULL DEFAULT 0,
        watered TINYINT NOT NULL DEFAULT 0,
        fertilised TINYINT NOT NULL DEFAULT 0,
        trimmed TINYINT NOT NULL DEFAULT 0,
        health INT NOT NULL DEFAULT 100,
        difficulty INT NOT NULL DEFAULT 5,
        restarts INT NOT NULL DEFAULT 0,
        ripe_minutes INT NOT NULL DEFAULT 0,
        planted_at INT NOT NULL DEFAULT 0,
        PRIMARY KEY (id),
        KEY idx_char (charid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS homestead_stats (
        charid INT NOT NULL,
        crop VARCHAR(48) NOT NULL,
        planted INT NOT NULL DEFAULT 0,
        harvested INT NOT NULL DEFAULT 0,
        gathered INT NOT NULL DEFAULT 0,
        PRIMARY KEY (charid, crop)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function bool(v) return v == true or v == 1 or v == '1' end

local function fromRow(r)
    return {
        id = tonumber(r.id), charid = tonumber(r.charid), crop = r.crop,
        x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z),
        left = tonumber(r.minutes_left) or 0, watered = bool(r.watered), fert = bool(r.fertilised), trim = bool(r.trimmed),
        health = tonumber(r.health) or 100, difficulty = tonumber(r.difficulty) or 5,
        restarts = tonumber(r.restarts) or 0, ripe = tonumber(r.ripe_minutes) or 0,
    }
end

local function hasTable(name)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })) == 1
end

-- playerfarms: one JSON blob per character, { [crop] = { [key] = plant } } -> one row per plant, ids kept
local function copyOldFarms()
    if not hasTable('playerfarms') then return 0 end
    local n = 0
    for _, row in ipairs(MySQL.query.await('SELECT charid, farm FROM playerfarms') or {}) do
        local ok, farm = pcall(json.decode, row.farm or '')
        if ok and type(farm) == 'table' then
            for crop, group in pairs(farm) do
                if type(group) == 'table' then
                    for _, p in pairs(group) do
                        local c = type(p) == 'table' and p.coords
                        local id = type(p) == 'table' and tonumber(p.render)
                        if c and id then
                            n = n + (MySQL.update.await([[INSERT IGNORE INTO homestead_plants
                                (id, charid, crop, x, y, z, minutes_left, watered, fertilised, trimmed, health, difficulty, restarts, planted_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                                { id, tonumber(row.charid), tostring(p.type or crop), tonumber(c.x) or 0, tonumber(c.y) or 0, tonumber(c.z) or 0,
                                  math.max(0, math.floor(tonumber(p.timer) or 0)), p.watered and 1 or 0, p.fert and 1 or 0, p.trem and 1 or 0,
                                  tonumber(p.health) or 100, tonumber(p.difficulty) or 5, tonumber(p.life) or 0, os.time() }) or 0)
                        end
                    end
                end
            end
        end
    end
    return n
end

function Store.init()
    for _, sql in ipairs(SCHEMA) do MySQL.query.await(sql) end

    if GetResourceKvpInt(MIGRATED) ~= 1 then
        local have = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM homestead_plants')) or 0
        local copied = have == 0 and copyOldFarms() or 0
        SetResourceKvpInt(MIGRATED, 1)
        print(('^2[pup_homestead]^7 carried over %d plants from playerfarms (old table untouched)'):format(copied))
    end

    -- one more restart survived; the oldest are pulled up
    MySQL.update.await('UPDATE homestead_plants SET restarts = restarts + 1')
    local gone = MySQL.update.await('DELETE FROM homestead_plants WHERE restarts > ?', { Config.Plants.lifetimeRestarts }) or 0
    if gone > 0 then print(('^3[pup_homestead]^7 %d plants reached the end of their life'):format(gone)) end

    Store.plants = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM homestead_plants') or {}) do
        local p = fromRow(r)
        if Config.Crops[p.crop] then Store.plants[p.id] = p end
    end
    Store.ready = true
end

function Store.get(id) return Store.plants[tonumber(id)] end

function Store.ofChar(charid)
    local out = {}
    for _, p in pairs(Store.plants) do if p.charid == charid then out[#out + 1] = p end end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Store.add(charid, crop, pos)
    local c = Config.Crops[crop]
    local id = MySQL.insert.await([[INSERT INTO homestead_plants (charid, crop, x, y, z, minutes_left, health, difficulty, planted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { charid, crop, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, c.grow, c.health, c.difficulty, os.time() })
    if not id or id == 0 then return nil end
    local p = { id = id, charid = charid, crop = crop, x = pos.x + 0.0, y = pos.y + 0.0, z = pos.z + 0.0, left = c.grow,
                watered = false, fert = false, trim = false, health = c.health, difficulty = c.difficulty, restarts = 0, ripe = 0 }
    Store.plants[id] = p
    Store.count(charid, crop, 'planted', 1)
    return p
end

-- write the whole plant now
function Store.save(p)
    dirty[p.id] = nil
    MySQL.update.await([[UPDATE homestead_plants SET minutes_left = ?, watered = ?, fertilised = ?, trimmed = ?, health = ?,
        difficulty = ?, ripe_minutes = ? WHERE id = ?]],
        { p.left, p.watered and 1 or 0, p.fert and 1 or 0, p.trim and 1 or 0, p.health, p.difficulty, p.ripe, p.id })
end

function Store.touch(p) dirty[p.id] = true end

function Store.flush()
    for id in pairs(dirty) do
        local p = Store.plants[id]
        dirty[id] = nil
        if p then MySQL.update.await('UPDATE homestead_plants SET minutes_left = ?, ripe_minutes = ? WHERE id = ?', { p.left, p.ripe, id }) end
    end
end

function Store.remove(p)
    Store.plants[p.id] = nil
    dirty[p.id] = nil
    MySQL.update.await('DELETE FROM homestead_plants WHERE id = ?', { p.id })
end

-- lifetime counts per character and crop
function Store.count(charid, crop, field, n)
    if field ~= 'planted' and field ~= 'harvested' and field ~= 'gathered' then return end
    MySQL.update.await(('INSERT INTO homestead_stats (charid, crop, %s) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE %s = %s + ?'):format(field, field, field),
        { charid, crop, n, n })
end

function Store.stats(charid)
    return MySQL.query.await('SELECT crop, planted, harvested, gathered FROM homestead_stats WHERE charid = ? ORDER BY harvested DESC, crop', { charid }) or {}
end
