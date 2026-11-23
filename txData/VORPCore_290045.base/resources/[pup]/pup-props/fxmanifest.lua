fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup-props'
description 'Permanent world props. Placed from the admin prop placer, streamed by distance.'
author 'Puppet'
version '1.0.0'

shared_scripts {
    'config/main.lua',
    'config/locale.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'vorp_core',
    'vorp_admin',
}
