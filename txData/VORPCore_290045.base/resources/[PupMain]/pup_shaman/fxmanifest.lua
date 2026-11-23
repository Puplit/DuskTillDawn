fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'pup_shaman'
description 'Curses, animal forms, ancient trees and rituals'
version '2.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/curses.lua',
    'config/forms.lua',
    'config/trees.lua',
    'config/rituals.lua',
    'shared/locale.lua',
    'shared/rules.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/curses.lua',
    'server/forms.lua',
    'server/trees.lua',
    'server/rituals.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
    'client/affliction.lua',
    'client/forms.lua',
    'client/trees.lua',
    'client/rituals.lua',
}
