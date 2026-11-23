fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'goldpan'
description 'Gold panning in rivers, creeks, lakes and ponds, with hidden pay streaks'
version '2.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'pup-minigames',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/loot.lua',
    'config/waters.lua',
    'config/locale.lua',
    'shared/util.lua',
}

server_scripts {
    'server/main.lua',
    'server/streaks.lua',
    'server/reward.lua',
}

client_scripts {
    'client/util.lua',
    'client/pan.lua',
    'client/main.lua',
}
