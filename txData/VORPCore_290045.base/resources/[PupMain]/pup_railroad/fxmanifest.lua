fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_railroad'
description 'Railroad companies: company trains, keys, coal and wear, repairs and upgrades, lockboxes, delivery routes, junctions, announcements and seats.'
version '1.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/stations.lua',
    'config/trains.lua',
    'config/routes.lua',
    'config/junctions.lua',
    'locale/en.lua',
    'shared/util.lua',
}

client_scripts {
    '@pup-ui/ptt.lua',
    'client/main.lua',
    'client/stations.lua',
    'client/deliveries.lua',
    'client/driving.lua',
    'client/dispatch.lua',
    'client/seats.lua',
    'client/dv.lua',
}

server_scripts {
    'server/config.lua', -- server-only settings (webhooks)
    'server/main.lua',
    'server/trains.lua',
    'server/workshop.lua',
    'server/deliveries.lua',
    'server/dispatch.lua',
}

files {
    'html/img/*.svg',
}
