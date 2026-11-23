fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'
author 'VORP @outsider'
name 'vorp inventory'
description 'Inventory System for vorp core framework'


shared_scripts {
  "@vorp_lib/import.lua",
  "config/config.lua",
  "config/crafting.lua",
  "config/weapons.lua",
  "config/ammo.lua",
  "languages/*.lua",
  "shared/models/*.lua",
  "shared/services/*.lua",
  "shared/services/Regex.js",
}

client_scripts {
  'client/exports.lua',
  "config/groups.lua",
  'client/client.lua',
  'client/models/*.lua',
  'client/services/*.lua',
  'client/controllers/*.lua',
  'client/pup_weaponRepair.lua', -- pup: live weapon condition reset after a repair
  'client/pup_giveAnim.lua',     -- pup: give/receive hand-over animation
  'client/pup_showItem.lua',     -- pup: hold an item up above your head
}

server_scripts {
  "config/config_server.lua",
  'server/config.lua', -- webhooks; after config_server.lua (it fills in CONFIG.LOGS)
  'server/pup_restricted_items.lua', -- pup: hideout-only contraband, loaded before the services that call it
  'server/pup_restartlock.lua',      -- pup: no gives or inventory moves in the last minutes before a txAdmin restart
  '@oxmysql/lib/MySQL.lua',
  'server/vorpInventoryApi.lua',
  'server/server.lua',
  'server/pup_invlogs.lua', -- pup: detailed audit block shared by every log site below
  'server/models/*.lua',
  'server/services/*.lua',
  'server/controllers/*.lua',
  'server/pup_weaponRepair.lua', -- pup: weapon full-repair exports (repair_kit + gunsmith)
  'server/pup_storageBox.lua',   -- pup: getOpenCustomInventory / reloadCustomInventory for pup_StorageBox
  'server/pup_layout.lua',       -- pup: shared Sort/Save order for custom containers
  -- after services/: re-checks the item with INVENTORY_API + SERVER_ITEMS
  'server/pup_showItem.lua',     -- pup: relay for the held-up item card
  'server/pup_itemdesc.lua',     -- pup: player-written descriptions + the HTML sanitiser
  -- after services/: uses USERS_WEAPONS, CUSTOM_INVENTORIES and DB_SERVICE
  'server/pup_evidenceLocker.lua', -- pup: move a SEIZED weapon into a container

}

files {
  'files/reloadspeeds.meta',
  'html/**/*'
}
ui_page 'html/ui.html'

---@deprecated
server_exports { 'vorp_inventoryApi' }


version '1.1'
vorp_checker 'no'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_inventory-v2'


data_file 'WEAPONINFO_FILE_PATCH' 'files/reloadspeeds.meta'
