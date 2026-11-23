-- pup_staffdesk | tables, and a one-time copy of the older recomp-station data
-- Additive only: the old tables (recomps, bug_points, recomp_namecd) are read, never changed.
DeskDB = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS staffdesk_parcels (
        id INT NOT NULL AUTO_INCREMENT,
        charid INT NULL,
        discordid VARCHAR(32) NULL,
        kind VARCHAR(8) NOT NULL,
        name VARCHAR(64) NOT NULL DEFAULT '',
        label VARCHAR(100) NOT NULL DEFAULT '',
        amount DECIMAL(12,2) NOT NULL DEFAULT 0,
        note VARCHAR(200) NOT NULL DEFAULT '',
        sent_by VARCHAR(100) NOT NULL DEFAULT '',
        origin VARCHAR(16) NOT NULL DEFAULT 'staff',
        created_at INT NOT NULL,
        claimed_at INT NULL,
        claimed_by INT NULL,
        cancelled_at INT NULL,
        PRIMARY KEY (id),
        KEY idx_char (charid, claimed_at),
        KEY idx_discord (discordid, claimed_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS staffdesk_bounty (
        charid INT NOT NULL,
        points INT NOT NULL DEFAULT 0,
        earned INT NOT NULL DEFAULT 0,
        spent INT NOT NULL DEFAULT 0,
        PRIMARY KEY (charid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS staffdesk_ledger (
        id INT NOT NULL AUTO_INCREMENT,
        charid INT NOT NULL,
        delta INT NOT NULL,
        reason VARCHAR(160) NOT NULL DEFAULT '',
        by_name VARCHAR(100) NOT NULL DEFAULT '',
        at INT NOT NULL,
        PRIMARY KEY (id),
        KEY idx_char (charid, at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS staffdesk_renames (
        kind VARCHAR(16) NOT NULL,
        ref VARCHAR(64) NOT NULL,
        named_at INT NOT NULL,
        PRIMARY KEY (kind, ref)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS staffdesk_milestones (
        charid INT NOT NULL,
        hours INT NOT NULL,
        paid_at INT NOT NULL,
        PRIMARY KEY (charid, hours)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS staffdesk_audit (
        id INT NOT NULL AUTO_INCREMENT,
        at INT NOT NULL,
        via VARCHAR(10) NOT NULL,
        actor VARCHAR(100) NOT NULL,
        command VARCHAR(32) NOT NULL,
        args VARCHAR(255) NOT NULL DEFAULT '',
        ok TINYINT NOT NULL DEFAULT 1,
        PRIMARY KEY (id),
        KEY idx_at (at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local MIGRATED <const> = 'pup_staffdesk:migrated'

local function decodeList(s)
    if type(s) ~= 'string' or s == '' then return {} end
    local ok, v = pcall(json.decode, s)
    return (ok and type(v) == 'table') and v or {}
end

-- recomps: one row per discord id with cash + json items + json weapons -> one parcel per thing
local function copyRecomps(now)
    if not Desk.hasTable('recomps') then return 0 end
    local n = 0
    for _, r in ipairs(MySQL.query.await('SELECT discordid, cash, items, weapons FROM recomps') or {}) do
        local d = tostring(r.discordid or '')
        if d ~= '' then
            local function add(kind, name, label, amount)
                MySQL.insert.await([[INSERT INTO staffdesk_parcels
                    (discordid, kind, name, label, amount, note, sent_by, origin, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, 'legacy', ?)]],
                    { d, kind, name, label, amount, Locale.legacyNote, 'Staff', now })
                n = n + 1
            end
            local cash = Desk.cents(r.cash) or 0
            if cash > 0 then add('cash', '', '', cash) end
            for _, it in ipairs(decodeList(r.items)) do
                local count = math.floor(tonumber(it.count) or 0)
                if type(it.item) == 'string' and count > 0 then add('item', it.item, it.label or it.item, count) end
            end
            for _, w in ipairs(decodeList(r.weapons)) do
                local hash, label = Desk.weapon(tostring(w))
                if hash then add('weapon', hash, label, 1) end
            end
        end
    end
    return n
end

function DeskDB.init()
    for _, sql in ipairs(SCHEMA) do MySQL.query.await(sql) end

    if GetResourceKvpInt(MIGRATED) == 1 then return end
    -- a second guard besides the KVP: never copy twice into a table that already has the old data
    local already = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM staffdesk_parcels WHERE origin = 'legacy'")) or 0
    local now = os.time()
    local parcels = 0
    if already == 0 then parcels = copyRecomps(now) end

    local bounty, renames = 0, 0
    if Desk.hasTable('bug_points') then
        bounty = MySQL.update.await([[INSERT IGNORE INTO staffdesk_bounty (charid, points, earned, spent)
            SELECT charid, points, earned, spent FROM bug_points]]) or 0
    end
    if Desk.hasTable('recomp_namecd') then
        renames = MySQL.update.await([[INSERT IGNORE INTO staffdesk_renames (kind, ref, named_at)
            SELECT kind, ref, named_at FROM recomp_namecd]]) or 0
    end

    SetResourceKvpInt(MIGRATED, 1)
    print(('^2[pup_staffdesk]^7 carried over %d parcels, %d bounty balances, %d rename cooldowns (old tables untouched)')
        :format(parcels, tonumber(bounty) or 0, tonumber(renames) or 0))
end

-- cooldowns (kind = 'name' | 'weapon' | 'pet', ref = charid / weapon id / item id)
function DeskDB.cooldownLeft(kind, ref, days)
    days = tonumber(days) or 0
    if days <= 0 then return 0 end
    local at = tonumber(MySQL.scalar.await('SELECT named_at FROM staffdesk_renames WHERE kind = ? AND ref = ?',
        { kind, tostring(ref) })) or 0
    if at <= 0 then return 0 end
    return math.max(0, at + days * 86400 - os.time())
end

function DeskDB.stamp(kind, ref)
    MySQL.update.await([[INSERT INTO staffdesk_renames (kind, ref, named_at) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE named_at = VALUES(named_at)]], { kind, tostring(ref), os.time() })
end

function DeskDB.audit(via, actor, command, args, ok)
    if not (Config.Discord and Config.Discord.audit ~= false) and via == 'discord' then return end
    MySQL.insert.await('INSERT INTO staffdesk_audit (at, via, actor, command, args, ok) VALUES (?, ?, ?, ?, ?, ?)',
        { os.time(), via, tostring(actor):sub(1, 100), tostring(command):sub(1, 32), tostring(args or ''):sub(1, 255), ok and 1 or 0 })
end
