fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'pup_workbench'
description 'Crafting stations, recipes, timed crafts and the crafting box'
version '2.0.0'

shared_scripts {
    'config/main.lua',
    'config/categories.lua',
    'config/stations.lua',
    'locale/en.lua',
    'shared/util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- server-only settings (webhooks)
    'server/core.lua',
    'server/db.lua',
    'server/recipes.lua',
    'server/stations.lua',
    'server/progress.lua',
    'server/box.lua',
    'server/craft.lua',
    'server/placeables.lua',
    'server/admin.lua',
    'server/main.lua',
}

client_scripts {
    'client/state.lua',
    'client/craft.lua',
    'client/bench.lua',
    'client/prompt.lua',
    'client/placeables.lua',
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}
