fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_robbery'
description 'Walk-up robberies, bank heists and the travelling fence'
version '2.0.0'

shared_scripts {
    'config/main.lua',
    'config/places.lua',
    'config/banks.lua',
    'config/fence.lua',
    'locale/en.lua',
    'shared/util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- server only: the Discord webhook (Secrets.webhook)
    'server/core.lua',
    'server/db.lua',
    'server/logs.lua',
    'server/police.lua',
    'server/walkup.lua',
    'server/heist.lua',
    'server/fence.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/guards.lua',
    'client/walkup.lua',
    'client/heist.lua',
    'client/doors.lua',
    'client/fence.lua',
    'client/police.lua',
    'client/dev.lua',
    'client/main.lua',
}

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
    'pup-minigames',
}
