-- pup_camps | database: schema, loading and saving camps

local function decode(s, fallback)
    if type(s) ~= 'string' or s == '' then return fallback end
    local ok, v = pcall(json.decode, s)
    if ok and v ~= nil then return v end
    return fallback
end
Decode = decode

local KNOWN = {
    name = true, bcolor = true, leader = true, members = true, coords = true, furni = true,
    raid = true, lifecycle = true, stewlevel = true, stewspoil = true, material = true,
    stock = true, maxstock = true, supply = true, hwagon = true, webhook = true, invoverride = true,
}

local function num(v, d) return tonumber(v) or d end

local function readPiece(p, key)
    if type(p) ~= 'table' then return nil end
    local id = tonumber(p.id) or tonumber(key)
    if not id then return nil end
    return {
        id = math.tointeger(id) or id,
        item = tostring(p.item or ''),
        prop = tonumber(p.prop) or p.prop,
        label = tostring(p.label or p.item or ''),
        cata = p.cata == 'set' and 'set' or 'prop',
        functional = type(p.functional) == 'string' and p.functional or 'none',
        active = p.active == true,
        grounded = p.grounded == true,
        coords = U.vec(p.coords),
        heading = num(p.heading, 0.0),
    }
end

local function readStashEntry(e)
    if type(e) ~= 'table' then return nil end
    local name = e.name or e.item
    if type(name) ~= 'string' or name == '' then return nil end
    local count = math.floor(num(e.count, 0))
    if count < 1 then return nil end
    return {
        name = name,
        label = tostring(e.label or name),
        count = count,
        type = e.type == 'item_weapon' and 'item_weapon' or 'item_standard',
        metadata = type(e.metadata) == 'table' and e.metadata or {},
        id = tonumber(e.id),
    }
end

-- every stash entry gets a unique id so the panel can point at exactly one stack
function FixStashIds(camp)
    local seen, top = {}, 0
    for _, e in ipairs(camp.inventory) do
        if e.id and not seen[e.id] then seen[e.id] = true end
        if e.id and e.id > top then top = e.id end
    end
    local used = {}
    for _, e in ipairs(camp.inventory) do
        if not e.id or used[e.id] then
            top = top + 1
            e.id = top
        end
        used[e.id] = true
    end
    camp.stashTop = top
end

function NextStashId(camp)
    camp.stashTop = (camp.stashTop or 0) + 1
    return camp.stashTop
end

function ReadCamp(row)
    local info = decode(row.info, {})
    if type(info) ~= 'table' then info = {} end

    local camp = {
        id = tonumber(row.id),
        name = tostring(info.name or Config.Camp.defaultName),
        bcolor = math.max(1, math.min(Config.Camp.blipColours, math.floor(num(info.bcolor, 1)))),
        leader = tonumber(info.leader) or info.leader,
        members = {},
        coords = U.vec(info.coords),
        furni = {},
        raid = num(info.raid, 0),
        lifecycle = num(info.lifecycle, 0),
        stewlevel = math.floor(num(info.stewlevel, 0)),
        stewspoil = tonumber(info.stewspoil),
        material = num(info.material, 0),
        stock = num(info.stock, 0),
        maxstock = num(info.maxstock, Config.Economy.stockCap),
        supply = num(info.supply, 0),
        hwagon = num(info.hwagon, 0),
        webhook = type(info.webhook) == 'string' and info.webhook or nil,
        invoverride = tonumber(info.invoverride),
        extra = {},
        cash = U.round(num(row.cash, 0), 2),
        inventory = {},
        invlimit = math.floor(num(row.invlimit, 0)),
        repo = num(row.repo, 0) == 1,
        taxmoney = math.floor(num(row.taxmoney, 0)),
    }

    if type(info.members) == 'table' then
        for _, m in pairs(info.members) do
            if type(m) == 'table' and m.charid ~= nil then
                camp.members[#camp.members + 1] = {
                    name = tostring(m.name or ''),
                    charid = tonumber(m.charid) or m.charid,
                    rank = type(m.rank) == 'string' and m.rank or nil,
                }
            end
        end
    end

    if type(info.furni) == 'table' then
        for k, p in pairs(info.furni) do
            local piece = readPiece(p, k)
            if piece then camp.furni[piece.id] = piece end
        end
    end

    for k, v in pairs(info) do
        if not KNOWN[k] then camp.extra[k] = v end
    end

    for _, e in ipairs(decode(row.inventory, {}) or {}) do
        local entry = readStashEntry(e)
        if entry then camp.inventory[#camp.inventory + 1] = entry end
    end
    FixStashIds(camp)
    return camp
end

local function encodeInfo(camp)
    local info = {}
    for k, v in pairs(camp.extra or {}) do info[k] = v end
    info.name = camp.name
    info.bcolor = camp.bcolor
    info.leader = camp.leader
    info.members = {}
    for _, m in ipairs(camp.members) do
        info.members[#info.members + 1] = { name = m.name, charid = m.charid, rank = m.rank }
    end
    info.coords = camp.coords
    -- string keys: always a JSON object, never a sparse array
    info.furni = {}
    for id, p in pairs(camp.furni) do info.furni[tostring(id)] = p end
    info.raid = camp.raid
    info.lifecycle = camp.lifecycle
    info.stewlevel = camp.stewlevel
    info.stewspoil = camp.stewspoil
    info.material = camp.material
    info.stock = camp.stock
    info.maxstock = camp.maxstock
    info.supply = camp.supply
    info.hwagon = camp.hwagon
    info.webhook = camp.webhook
    info.invoverride = camp.invoverride
    return json.encode(info)
end

local function encodeStash(camp)
    if #camp.inventory == 0 then return '[]' end
    local list = {}
    for i, e in ipairs(camp.inventory) do
        list[i] = { name = e.name, label = e.label, count = e.count, type = e.type, metadata = e.metadata, id = e.id }
    end
    return json.encode(list)
end

-- coalesced writes: one in flight per camp, the latest state always lands last
local writing = {}   -- [campId] = { at = ms, again = bool, token = table }
local STUCK_MS <const> = 30000

local function writeCamp(camp)
    local id = camp.id
    local w = writing[id]
    -- a write whose callback never came back (query error) must not block this camp forever
    if w and GetGameTimer() - w.at < STUCK_MS then w.again = true return end
    local mine = { at = GetGameTimer(), again = false }
    writing[id] = mine
    local params = {
        encodeInfo(camp), ('%.2f'):format(camp.cash), encodeStash(camp),
        math.floor(camp.invlimit or 0), camp.repo and 1 or 0, math.floor(camp.taxmoney or 0), id,
    }
    MySQL.update('UPDATE clan SET info = ?, cash = ?, inventory = ?, invlimit = ?, repo = ?, taxmoney = ? WHERE id = ?',
        params, function()
            if writing[id] ~= mine then return end
            writing[id] = nil
            if mine.again and Camps[id] then writeCamp(Camps[id]) end
        end)
end

function Save(camp)
    if camp and camp.id and Camps[camp.id] == camp then writeCamp(camp) end
end

-- on resource stop: queue every write at once (an await here could be cut off mid-loop
-- while the resource is torn down)
function SaveAllNow()
    for _, camp in pairs(Camps) do
        MySQL.update('UPDATE clan SET info = ?, cash = ?, inventory = ?, invlimit = ?, repo = ?, taxmoney = ? WHERE id = ?', {
            encodeInfo(camp), ('%.2f'):format(camp.cash), encodeStash(camp),
            math.floor(camp.invlimit or 0), camp.repo and 1 or 0, math.floor(camp.taxmoney or 0), camp.id,
        })
    end
end

function SaveAll()
    for _, camp in pairs(Camps) do writeCamp(camp) end
end

------------------------------------------------------------------------------ schema

function EnsureSchema()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `clan` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `info` longtext NOT NULL DEFAULT '[]',
        `cash` tinytext NOT NULL DEFAULT 0,
        `inventory` longtext NOT NULL DEFAULT '[]',
        `invlimit` int(11) DEFAULT 1000,
        `repo` int(11) DEFAULT 0,
        `taxmoney` int(11) DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `coords` (`id`),
        KEY `container` (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `wagon_stash` (
        `charid` int(11) NOT NULL,
        `stash` longtext NULL,
        PRIMARY KEY (`charid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `cron_state` (
        `name` varchar(64) NOT NULL,
        `lastrun` varchar(16) NOT NULL DEFAULT '',
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    local has = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters' AND COLUMN_NAME = 'clan']])
    if (tonumber(has) or 0) == 0 then
        MySQL.query.await('ALTER TABLE `characters` ADD COLUMN `clan` INT(11) NULL DEFAULT 0')
        print('^2[pup_camps]^7 added characters.clan')
    end
end

function LoadCamps()
    local rows = MySQL.query.await('SELECT id, info, cash, inventory, invlimit, repo, taxmoney FROM clan') or {}
    local n = 0
    for _, row in ipairs(rows) do
        local camp = ReadCamp(row)
        if camp.id then
            Camps[camp.id] = camp
            RecomputeStorage(camp)
            n = n + 1
        end
    end
    print(('^2[pup_camps]^7 loaded %d camps'):format(n))
end

function SetCharClan(charid, campId)
    charid = tonumber(charid)
    if not charid then return end
    MySQL.update('UPDATE characters SET clan = ? WHERE charidentifier = ?', { campId or 0, charid })
end

function NewCampRow(info)
    return MySQL.insert.await("INSERT INTO clan (info, cash, inventory, invlimit, taxmoney) VALUES (?, '0', '[]', 1000, 0)", { info })
end

function DeleteCampRow(id)
    MySQL.update('DELETE FROM clan WHERE id = ?', { id })
end
