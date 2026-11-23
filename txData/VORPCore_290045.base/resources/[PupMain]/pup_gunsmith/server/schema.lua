-- pup_gunsmith | tables owned by this resource, created on start when missing
-- The shared-table columns (characters.gunsmith, loadout.used2/dropped/comps/tier)
-- come from sql/install.sql; on start they are only checked, never altered.

Schema = {}

local CREATE_RECIPES <const> = [[
CREATE TABLE IF NOT EXISTS `weapon_recipes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kind` varchar(8) NOT NULL,
  `category` varchar(64) NOT NULL,
  `label` varchar(128) NOT NULL,
  `enabled` tinyint(4) NOT NULL DEFAULT 1,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `kind_cat_label` (`kind`, `category`, `label`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]]

local CREATE_STATIONS <const> = [[
CREATE TABLE IF NOT EXISTS `weapon_craft_locations` (
  `name` varchar(64) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `job` longtext NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]]

local CREATE_PRESETS <const> = [[
CREATE TABLE IF NOT EXISTS `gunsmith_presets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) NOT NULL,
  `weapon` varchar(64) NOT NULL,
  `name` varchar(40) NOT NULL,
  `comps` longtext NOT NULL,
  `updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `char_weapon_name` (`charid`, `weapon`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]]

local SHARED_COLUMNS <const> = {
    { 'characters', 'gunsmith' },
    { 'loadout', 'used2' },
    { 'loadout', 'dropped' },
    { 'loadout', 'comps' },
    { 'loadout', 'tier' },
}

Schema.ready = false

function Schema.ensure()
    local ok, err = pcall(function()
        MySQL.query.await(CREATE_RECIPES)
        MySQL.query.await(CREATE_STATIONS)
        MySQL.query.await(CREATE_PRESETS)
    end)
    if not ok then
        print(('^1[pup_gunsmith]^7 could not create the tables: %s'):format(tostring(err)))
        return false
    end

    local missing = {}
    for _, c in ipairs(SHARED_COLUMNS) do
        local okc, n = pcall(MySQL.scalar.await,
            'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
            { c[1], c[2] })
        if okc and tonumber(n) == 0 then missing[#missing + 1] = c[1] .. '.' .. c[2] end
    end
    if #missing > 0 then
        print(('^1[pup_gunsmith]^7 missing columns: %s - run sql/install.sql'):format(table.concat(missing, ', ')))
    end
    Schema.ready = true
    return true
end
