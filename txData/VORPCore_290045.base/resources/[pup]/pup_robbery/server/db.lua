-- pup_robbery | database: tables, cooldown clocks, history

DB = { ready = false }

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `robbery_cooldowns` (
        `scope` varchar(16) NOT NULL,
        `ckey` varchar(64) NOT NULL,
        `expires` int(11) NOT NULL,
        PRIMARY KEY (`scope`, `ckey`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `robbery_history` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `bank` varchar(64) NOT NULL,
        `outcome` varchar(16) NOT NULL,
        `crew` text DEFAULT NULL,
        `lootTaken` int(11) NOT NULL DEFAULT 0,
        `lootTotal` int(11) NOT NULL DEFAULT 0,
        `alarmPeak` int(11) NOT NULL DEFAULT 0,
        `duration` int(11) NOT NULL DEFAULT 0,
        `at` int(11) NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `robbery_fence_rep` (
        `charidentifier` int(11) NOT NULL,
        `rep` int(11) NOT NULL DEFAULT 0,
        `sales` int(11) NOT NULL DEFAULT 0,
        `value` int(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`charidentifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `robbery_fence_payouts` (
        `charidentifier` int(11) NOT NULL,
        `amount` int(11) NOT NULL DEFAULT 0,
        `readyAt` int(11) NOT NULL,
        `mailed` tinyint(4) NOT NULL DEFAULT 0,
        PRIMARY KEY (`charidentifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

-- [scope][ckey] = expires (unix seconds), only rows still in the future
DB.clocks = { heist = {}, player = {}, walkup = {}, place = {} }

function DB.query(sql, params)
    local ok, r = pcall(MySQL.query.await, sql, params or {})
    if not ok then
        S.warn('query failed: %s', tostring(r))
        return nil
    end
    return r
end

function DB.single(sql, params)
    local ok, r = pcall(MySQL.single.await, sql, params or {})
    if not ok then
        S.warn('query failed: %s', tostring(r))
        return nil
    end
    return r
end

function DB.update(sql, params)
    local ok, r = pcall(MySQL.update.await, sql, params or {})
    if not ok then
        S.warn('update failed: %s', tostring(r))
        return nil
    end
    return tonumber(r) or 0
end

function DB.insert(sql, params)
    local ok, r = pcall(MySQL.insert.await, sql, params or {})
    if not ok then
        S.warn('insert failed: %s', tostring(r))
        return nil
    end
    return r
end

--------------------------------------------------------------------------------
-- clocks

function DB.clockLeft(scope, key)
    local t = DB.clocks[scope] and DB.clocks[scope][tostring(key)]
    if not t then return 0 end
    local left = t - os.time()
    if left <= 0 then
        DB.clocks[scope][tostring(key)] = nil
        return 0
    end
    return left
end

function DB.setClock(scope, key, expires, persist)
    key = tostring(key)
    DB.clocks[scope] = DB.clocks[scope] or {}
    DB.clocks[scope][key] = expires
    if persist == false then return end
    MySQL.query('INSERT INTO robbery_cooldowns (scope, ckey, expires) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE expires = VALUES(expires)',
        { scope, key, expires })
end

function DB.clearClock(scope, key, persist)
    key = tostring(key)
    if DB.clocks[scope] then DB.clocks[scope][key] = nil end
    if persist == false then return end
    MySQL.query('DELETE FROM robbery_cooldowns WHERE scope = ? AND ckey = ?', { scope, key })
end

function DB.clearScope(scope, persist)
    DB.clocks[scope] = {}
    if persist == false then return end
    MySQL.query('DELETE FROM robbery_cooldowns WHERE scope = ?', { scope })
end

--------------------------------------------------------------------------------
-- history (write only)

function DB.history(row)
    MySQL.insert('INSERT INTO robbery_history (bank, outcome, crew, lootTaken, lootTotal, alarmPeak, duration, at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { row.bank, row.outcome, json.encode(row.crew or {}), row.lootTaken or 0, row.lootTotal or 0, row.alarmPeak or 0, row.duration or 0, row.at or os.time() })
end

--------------------------------------------------------------------------------
-- start-up

local readyHooks = {}
function DB.onReady(fn)
    if DB.ready then return fn() end
    readyHooks[#readyHooks + 1] = fn
end

CreateThread(function()
    for _, sql in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then S.warn('could not create a table: %s', tostring(err)) end
    end
    local now = os.time()
    local rows = DB.query('SELECT scope, ckey, expires FROM robbery_cooldowns WHERE expires > ?', { now }) or {}
    for _, r in ipairs(rows) do
        DB.clocks[r.scope] = DB.clocks[r.scope] or {}
        DB.clocks[r.scope][tostring(r.ckey)] = tonumber(r.expires)
    end
    S.dbg('loaded %d stored clocks', #rows)
    DB.ready = true
    for _, fn in ipairs(readyHooks) do
        local ok, err = pcall(fn)
        if not ok then S.warn('start-up step failed: %s', tostring(err)) end
    end
    readyHooks = {}
end)
