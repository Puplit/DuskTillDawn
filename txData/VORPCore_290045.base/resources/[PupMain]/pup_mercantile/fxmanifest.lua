fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_mercantile'
description 'NPC stores, player shops and society shops on the vorp_inventory store grid'
version '2.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/locale.lua',
    'config/stores.lua',
    'config/weaponlabels.lua',
    'shared/util.lua',
    'shared/stores.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/core.lua',
    'server/integrations.lua',
    'server/shops.lua',
    'server/logs.lua',
    'server/db.lua',
    'server/venue.lua',
    'server/trade.lua',
    'server/box.lua',
    'server/create.lua',
    'server/manage.lua',
    'server/tax.lua',
    'server/admin.lua',
    'server/raid.lua',
    'server/sync.lua',
}

client_scripts {
    'client/main.lua',
    'client/store.lua',
    'client/dashboard.lua',
    'client/create.lua',
}
