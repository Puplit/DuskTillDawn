fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'legendaryhunt'
description 'Baited hunting traps that call legendary animals, and the trapper who sells the traps'
version '2.1.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/animals.lua',
    'config/grounds.lua',
    'config/shop.lua',
    'config/locale.lua',
    'shared/rules.lua',
}

server_scripts {
    'server/config.lua', -- webhook, server only

    'server/main.lua',
    'server/log.lua',
    'server/hunt.lua',
    'server/shop.lua',
}

client_scripts {
    'client/util.lua',
    'client/menu.lua',
    'client/trap.lua',
    'client/trapper.lua',
    'client/main.lua',
}
