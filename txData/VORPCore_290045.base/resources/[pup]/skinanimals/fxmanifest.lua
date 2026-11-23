fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'skinanimals'
description 'Server-checked skinning payouts per animal, one payout per carcass, optional mercy kill and Discord log'
version '2.0.0'

shared_scripts {
    'config/main.lua',
    'config/animals.lua',
    'locale/en.lua',
    'shared/util.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- server only: the Discord webhook (SkinSecrets)
    'server/integrations.lua',
    'server/log.lua',
    'server/main.lua',
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
}
