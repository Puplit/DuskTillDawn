fx_version 'adamant'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'pup'
description 'Mayoral elections: one vote per account, per region, on a timer'

dependency 'pup-ui'

shared_scripts {
    'config/main.lua',
    'config/locale.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- server only: the Discord webhook (Secrets.Webhooks)
    'server/main.lua',
}
