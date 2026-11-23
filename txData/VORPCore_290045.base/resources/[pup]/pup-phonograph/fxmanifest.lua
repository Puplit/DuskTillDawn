fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup-phonograph'
description 'Placeable phonographs that play web links with positional sound'
version '2.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'xsound',
    'pup-ui',
}

shared_scripts {
    'shared/config.lua',
    'shared/locale.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/util.lua',
    'server/config.lua', -- server only: the Discord webhook (PH.Secrets)
    'server/store.lua',
    'server/audio.lua',
    'server/actions.lua',
    'server/main.lua',
}

client_scripts {
    'client/util.lua',
    'client/props.lua',
    'client/audio.lua',
    'client/placement.lua',
    'client/menu.lua',
    'client/main.lua',
}
