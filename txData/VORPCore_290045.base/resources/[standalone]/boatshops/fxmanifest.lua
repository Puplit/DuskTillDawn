fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'boatshops'
description 'Boat shops: buy, launch, park, give, sell and upgrade boats, with per-boat storage'
version '2.0.0'

shared_scripts {
    'config/main.lua',
    'config/boats.lua',
    'config/shops.lua',
    'config/upgrades.lua',
    'config/locale.lua',
    'shared/catalogue.lua',
}

client_scripts {
    'client/natives.lua',
    'client/main.lua',
    'client/menu.lua',
    'client/world.lua',
    'client/shop.lua',
    'client/boat.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/logs.lua',
    'server/core.lua',
    'server/fleet.lua',
    'server/actions.lua',
}

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
}
