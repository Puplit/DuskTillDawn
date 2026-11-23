-- pup_clothing | database access. Every query is parameterised.

local DB = {}
PC.DB = DB

local SCHEMA <const> = {
    [[CREATE TABLE IF NOT EXISTS `clothing_starter` (
        `charidentifier` int(11) NOT NULL,
        PRIMARY KEY (`charidentifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
    [[CREATE TABLE IF NOT EXISTS `clothing_extras` (
        `charidentifier` int(11) NOT NULL,
        `extras` longtext NULL,
        PRIMARY KEY (`charidentifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
    [[CREATE TABLE IF NOT EXISTS `clothing_outfits` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `charidentifier` int(11) NOT NULL,
        `identifier` varchar(100) NULL DEFAULT NULL,
        `title` varchar(255) NOT NULL DEFAULT 'Outfit',
        `comps` longtext NULL,
        `extras` longtext NULL,
        PRIMARY KEY (`id`),
        KEY `charidentifier` (`charidentifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
}

DB.ready = false

MySQL.ready(function()
    for _, q in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.query.await, q)
        if not ok then print(('^1[pup_clothing]^7 table check failed: %s'):format(tostring(err))) end
    end
    DB.ready = true
end)

function DB.getExtras(charId)
    local v = MySQL.scalar.await('SELECT `extras` FROM `clothing_extras` WHERE `charidentifier` = ?', { charId })
    if type(v) ~= 'string' or v == '' then return '{}' end
    return v
end

function DB.setExtras(charId, json)
    MySQL.update.await(
        'INSERT INTO `clothing_extras` (`charidentifier`, `extras`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `extras` = VALUES(`extras`)',
        { charId, json })
end

function DB.starterUsed(charId)
    return MySQL.scalar.await('SELECT 1 FROM `clothing_starter` WHERE `charidentifier` = ?', { charId }) ~= nil
end

function DB.markStarter(charId)
    MySQL.update.await('INSERT IGNORE INTO `clothing_starter` (`charidentifier`) VALUES (?)', { charId })
end

function DB.countOutfits(charId)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `clothing_outfits` WHERE `charidentifier` = ?', { charId })) or 0
end

function DB.listOutfits(charId)
    return MySQL.query.await(
        'SELECT `id`, `title` FROM `clothing_outfits` WHERE `charidentifier` = ? ORDER BY `id`', { charId }) or {}
end

function DB.getOutfit(id, charId)
    return MySQL.single.await(
        'SELECT `id`, `title`, `comps`, `extras` FROM `clothing_outfits` WHERE `id` = ? AND `charidentifier` = ?',
        { id, charId })
end

function DB.addOutfit(charId, identifier, title, comps, extras)
    return MySQL.insert.await(
        'INSERT INTO `clothing_outfits` (`charidentifier`, `identifier`, `title`, `comps`, `extras`) VALUES (?, ?, ?, ?, ?)',
        { charId, identifier, title, comps, extras })
end

function DB.setOutfitComps(id, charId, comps)
    MySQL.update.await('UPDATE `clothing_outfits` SET `comps` = ? WHERE `id` = ? AND `charidentifier` = ?',
        { comps, id, charId })
end

function DB.deleteOutfit(id, charId)
    return tonumber(MySQL.update.await(
        'DELETE FROM `clothing_outfits` WHERE `id` = ? AND `charidentifier` = ?', { id, charId })) or 0
end
