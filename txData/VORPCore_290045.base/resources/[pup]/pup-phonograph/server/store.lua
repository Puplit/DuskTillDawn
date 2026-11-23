-- The phonographs table and the in-memory copy every rule reads from.

PH = PH or {}

-- [id] = { id, x, y, z, rx, ry, rz, job, rank, record, ownerCharId, radius, volume }
PH.Phonos = {}
PH.Ready = false

local SCHEMA <const> = [[
CREATE TABLE IF NOT EXISTS `phonographs` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `owner_identifier` varchar(255) NULL DEFAULT NULL,
    `owner_charid` int(11) NULL DEFAULT NULL,
    `x` double NULL DEFAULT NULL,
    `y` double NULL DEFAULT NULL,
    `z` double NULL DEFAULT NULL,
    `rot_x` double NULL DEFAULT NULL,
    `rot_y` double NULL DEFAULT NULL,
    `rot_z` double NULL DEFAULT NULL,
    `job` varchar(50) NULL DEFAULT '',
    `rank` int(11) NULL DEFAULT 0,
    `current_record` varchar(50) NULL DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

local function fromRow(row)
    local record = row.current_record
    if type(record) ~= 'string' or record == '' then record = nil end
    return {
        id = tonumber(row.id),
        x = tonumber(row.x) or 0.0,
        y = tonumber(row.y) or 0.0,
        z = tonumber(row.z) or 0.0,
        rx = tonumber(row.rot_x) or 0.0,
        ry = tonumber(row.rot_y) or 0.0,
        rz = tonumber(row.rot_z) or 0.0,
        job = type(row.job) == 'string' and row.job or '',
        rank = tonumber(row.rank) or 0,
        record = record,
        ownerCharId = tonumber(row.owner_charid) or 0,
        radius = Config.Radius.default,
        volume = nil,
    }
end

-- what a client may see: never the owner's identifiers
function PH.PublicView(p)
    return {
        id = p.id,
        x = p.x, y = p.y, z = p.z,
        rotation = { x = p.rx, y = p.ry, z = p.rz },
        job = p.job,
        rank = p.rank,
        record = p.record,
        radius = p.radius,
    }
end

function PH.PublicList()
    local list = {}
    for _, p in pairs(PH.Phonos) do list[#list + 1] = PH.PublicView(p) end
    return list
end

function PH.CountForChar(charId)
    local n = 0
    for _, p in pairs(PH.Phonos) do
        if p.ownerCharId == charId then n = n + 1 end
    end
    return n
end

function PH.AtLimit(charId)
    local limit = tonumber(Config.PerCharacterLimit) or 0
    if limit <= 0 then return false end
    return PH.CountForChar(charId) >= limit
end

function PH.LoadAll()
    MySQL.query.await(SCHEMA)
    local rows = MySQL.query.await(
        'SELECT `id`, `owner_charid`, `x`, `y`, `z`, `rot_x`, `rot_y`, `rot_z`, `job`, `rank`, `current_record` FROM `phonographs`')
    PH.Phonos = {}
    for _, row in ipairs(rows or {}) do
        local p = fromRow(row)
        if p.id then PH.Phonos[p.id] = p end
    end
    PH.Ready = true
end

-- returns the new phonograph (already in memory), or nil
function PH.Insert(ownerIdentifier, ownerCharId, pos, rot, job, rank)
    local id = MySQL.insert.await(
        'INSERT INTO `phonographs` (`owner_identifier`, `owner_charid`, `x`, `y`, `z`, `rot_x`, `rot_y`, `rot_z`, `job`, `rank`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { ownerIdentifier, ownerCharId, pos.x, pos.y, pos.z, 0.0, 0.0, rot.z, job, rank })
    id = tonumber(id)
    if not id or id <= 0 then return nil end
    local p = fromRow({
        id = id, owner_charid = ownerCharId, x = pos.x, y = pos.y, z = pos.z,
        rot_x = 0.0, rot_y = 0.0, rot_z = rot.z, job = job, rank = rank,
    })
    PH.Phonos[id] = p
    return p
end

-- the row's owner and position straight from the database, or nil
function PH.ReadRow(id)
    local row = MySQL.single.await(
        'SELECT `id`, `owner_charid`, `x`, `y`, `z` FROM `phonographs` WHERE `id` = ?', { id })
    if not row then return nil end
    return {
        id = tonumber(row.id),
        ownerCharId = tonumber(row.owner_charid) or 0,
        x = tonumber(row.x) or 0.0, y = tonumber(row.y) or 0.0, z = tonumber(row.z) or 0.0,
    }
end

-- true only when this call removed the row
function PH.DeleteRow(id)
    local affected = MySQL.update.await('DELETE FROM `phonographs` WHERE `id` = ?', { id })
    return (tonumber(affected) or 0) > 0
end

function PH.SetRecord(id, item)
    -- an unchanged value can report 0 rows, so only a failed query counts as failure
    local affected
    if item == nil then
        affected = MySQL.update.await('UPDATE `phonographs` SET `current_record` = NULL WHERE `id` = ?', { id })
    else
        affected = MySQL.update.await('UPDATE `phonographs` SET `current_record` = ? WHERE `id` = ?', { item, id })
    end
    return affected ~= nil
end
