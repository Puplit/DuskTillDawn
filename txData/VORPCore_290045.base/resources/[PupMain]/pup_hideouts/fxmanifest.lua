fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_hideouts'
description 'Moonshine hideouts: instanced shacks, stills and production, contraband sales, raids, wagon jobs, a betting table and a bar'
version '2.0.0'

shared_scripts {
    'config/main.lua',
    'config/interior.lua',
    'config/production.lua',
    'config/sales.lua',
    'config/wagons.lua',
    'locale/en.lua',
    'shared/util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/core.lua',
    'server/logs.lua',
    'server/instance.lua',
    'server/door.lua',
    'server/management.lua',
    'server/stash.lua',
    'server/production.lua',
    'server/raids.lua',
    'server/wagons.lua',
    'server/sales.lua',
    'server/bookie.lua',
    'server/admin.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/data.lua',
    'client/interior.lua',
    'client/door.lua',
    'client/raid.lua',
    'client/books.lua',
    'client/bar.lua',
    'client/bookie.lua',
    'client/sales.lua',
    'client/wagons.lua',
    'client/main.lua',
}

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
    'pup-minigames',
}
