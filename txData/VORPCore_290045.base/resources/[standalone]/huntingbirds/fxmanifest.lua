fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'huntingbirds'
description 'Trained birds: buy, call out, carry on the shoulder, send hunting, scavenging or fishing, and trade'
version '2.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'locale/en.lua',
    'shared/util.lua',
    'shared/data.lua',
}

client_scripts {
    'client/dataview.lua',
    'client/util.lua',
    'client/bird.lua',
    'client/shop.lua',
    'client/menu.lua',
    'client/sell.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- webhook, server only; after the shared config/main.lua, before log.lua
    'server/log.lua',
    'server/main.lua',
    'server/shop.lua',
    'server/hunt.lua',
    'server/trade.lua',
}

-- data the client needs; the catch lists (prey, scavenge, fish) stay on the server
files {
    'data/bird_catalog.json',
    'data/bird_roles.json',
    'data/shoulder_offsets.json',
    'data/shops.json',
    'data/hunt_zones.json',
    'data/parrot_speech.json',
}
