fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'Puppet'
version '1.0.0'
description 'Melee props carried on the body and swung as base-game weapons: swords, clubs, tools and shields, with a per-character position editor'

shared_scripts {
    'config/main.lua',
    'config/weapons.lua',
    'config/weapons_custom*.lua', -- your own weapons: the example template plus any weapons_custom.lua you add
    'config/locale.lua',
    'shared/index.lua',          -- after every config file: it indexes them
}

client_scripts {
    'client/main.lua',
    'client/editor.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}
