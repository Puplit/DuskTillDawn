-- pup_mortician | database: schema on start, business settings, register,
-- legacy migration. Every query is parameterised.

Business = {} -- job -> { cut = number|nil, webhook = string }
DbReady = false

local SCHEMA <const> = {
    [[CREATE TABLE IF NOT EXISTS `mortician_business` (
        `job` varchar(50) NOT NULL,
        `cut` int(11) NOT NULL DEFAULT 0,
        `webhook` text DEFAULT NULL,
        PRIMARY KEY (`job`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
    [[CREATE TABLE IF NOT EXISTS `mortician_register` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `job` varchar(50) NOT NULL,
        `charid` int(11) NOT NULL,
        `undertaker` varchar(100) NOT NULL,
        `deceased` varchar(100) NOT NULL,
        `cause` varchar(100) NOT NULL DEFAULT '',
        `place` varchar(50) NOT NULL DEFAULT '',
        `kind` varchar(10) NOT NULL DEFAULT 'casket',
        `goods` varchar(255) NOT NULL DEFAULT '',
        `paid` int(11) NOT NULL DEFAULT 0,
        `house` int(11) NOT NULL DEFAULT 0,
        `at` int(11) NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_job` (`job`, `at`),
        KEY `idx_char` (`charid`, `at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
    [[CREATE TABLE IF NOT EXISTS `mortician_shift` (
        `charid` int(11) NOT NULL,
        `started` int(11) NOT NULL,
        `burials` int(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`charid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
}

---------------------------------------------------------------------------
-- House cut and webhook
---------------------------------------------------------------------------
function MaxCut()
    local m = math.floor(tonumber(Config.HouseCut.max) or 0)
    return math.max(0, math.min(100, m))
end

function CutOf(job)
    local b = Business[job]
    local pct = (b and b.cut) or Config.HouseCut.default
    pct = math.floor(tonumber(pct) or 0)
    return math.max(0, math.min(MaxCut(), pct))
end

function WebhookOf(job)
    local b = Business[job]
    if b and type(b.webhook) == 'string' and b.webhook ~= '' then return b.webhook end
    return nil
end

-- always writes both columns: the one not being changed keeps its in-memory value
local function saveBusiness(job)
    local b = Business[job] or {}
    MySQL.insert('INSERT INTO mortician_business (job, cut, webhook) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE cut = VALUES(cut), webhook = VALUES(webhook)',
        { job, CutOf(job), b.webhook or '' })
end

function SetCut(job, pct)
    Business[job] = Business[job] or { webhook = '' }
    Business[job].cut = math.max(0, math.min(MaxCut(), math.floor(tonumber(pct) or 0)))
    saveBusiness(job)
    return Business[job].cut
end

function SetWebhook(job, url)
    Business[job] = Business[job] or {}
    if Business[job].cut == nil then Business[job].cut = CutOf(job) end
    Business[job].webhook = url or ''
    saveBusiness(job)
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------
function WriteRegister(row)
    MySQL.insert('INSERT INTO mortician_register (job, charid, undertaker, deceased, cause, place, kind, goods, paid, house, at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        row.job, row.charid, (row.undertaker or ''):sub(1, 100), (row.deceased or ''):sub(1, 100),
        (row.cause or ''):sub(1, 100), (row.place or ''):sub(1, 50), row.kind, (row.goods or ''):sub(1, 255),
        row.paid or 0, row.house or 0, os.time(),
    })
end

function ReadRegister(job)
    local ok, rows = pcall(MySQL.query.await,
        'SELECT deceased, cause, undertaker, paid, place, at FROM mortician_register WHERE job = ? ORDER BY id DESC LIMIT 40', { job })
    if not ok or type(rows) ~= 'table' then return {} end
    return rows
end

function ReadWeekSummary(job)
    local ok, rows = pcall(MySQL.query.await,
        'SELECT charid, undertaker, COUNT(*) AS n, SUM(paid) AS paid, SUM(house) AS house FROM mortician_register WHERE job = ? AND at >= ? GROUP BY charid, undertaker ORDER BY n DESC',
        { job, os.time() - 7 * 86400 })
    if not ok or type(rows) ~= 'table' then return {} end
    return rows
end

---------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------
local KVP_MIGRATED <const> = 'pup_mortician:migrated'

local function migrateLegacy()
    if GetResourceKvpInt(KVP_MIGRATED) == 1 then return end
    local ok, exists = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { 'undertaker_cut' })
    if not ok then
        Warn('could not check for the legacy house-cut table; will try again next start')
        return
    end
    if (tonumber(exists) or 0) == 0 then
        SetResourceKvpInt(KVP_MIGRATED, 1)
        return
    end
    local okRows, rows = pcall(MySQL.query.await, 'SELECT job, pct, webhook FROM undertaker_cut', {})
    if not okRows or type(rows) ~= 'table' then
        Warn('could not read undertaker_cut; will try again next start')
        return
    end
    local copied = 0
    for _, r in ipairs(rows) do
        if r.job then
            -- update.await returns affected rows: 0 when the job already had a row
            local okIns, affected = pcall(MySQL.update.await,
                'INSERT IGNORE INTO mortician_business (job, cut, webhook) VALUES (?, ?, ?)',
                { tostring(r.job):sub(1, 50), math.floor(tonumber(r.pct) or 0), r.webhook or '' })
            if okIns and (tonumber(affected) or 0) > 0 then copied = copied + 1 end
        end
    end
    print(('[%s] copied %d legacy house-cut row(s) into mortician_business'):format(RES, copied))
    SetResourceKvpInt(KVP_MIGRATED, 1)
end

local function loadBusiness()
    local ok, rows = pcall(MySQL.query.await, 'SELECT job, cut, webhook FROM mortician_business', {})
    if not ok or type(rows) ~= 'table' then
        Warn('could not load mortician_business')
        return
    end
    for _, r in ipairs(rows) do
        Business[r.job] = { cut = tonumber(r.cut), webhook = r.webhook or '' }
    end
end

MySQL.ready(function()
    for _, q in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.query.await, q, {})
        if not ok then Warn('schema: ' .. tostring(err)) end
    end
    migrateLegacy()
    -- migration may have added rows, so load after it
    loadBusiness()
    DbReady = true
end)
