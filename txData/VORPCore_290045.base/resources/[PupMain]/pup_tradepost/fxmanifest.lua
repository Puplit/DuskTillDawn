fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_tradepost'
description 'Trading Post: a shared board of buy orders and sell listings at the market counters'
version '3.0.0'

shared_scripts {
    'config/main.lua',
    'shared/locale.lua',
    'shared/util.lua',
}

client_scripts {
    'client/panel.lua',
    'client/world.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- server-only settings (webhooks)
    'server/core.lua',
    'server/db.lua',
    'server/items.lua',
    'server/money.lua',
    'server/storage.lua',
    'server/orders.lua',
    'server/reads.lua',
    'server/main.lua',
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}
