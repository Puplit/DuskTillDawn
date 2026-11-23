fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_ranchero'
description 'Player ranches: livestock, herding and sale drives, chores, milk and eggs, tax, staff tools'
version '2.0.0'

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/locale.lua',
    'shared/util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- server-only settings (webhooks)
    'server/core.lua',
    'server/logs.lua',
    'server/ranch.lua',
    'server/drives.lua',
    'server/produce.lua',
    'server/tax.lua',
    'server/board.lua',
    'server/admin.lua',
    'server/init.lua',
}

client_scripts {
    '@pup-ui/ptt.lua', -- push-to-talk keeps working while our NUI has focus
    'client/main.lua',
    'client/menus.lua',
    'client/tasks.lua',
    'client/drives.lua',
    'client/minigame.lua',
    'client/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/art.js',
    'html/game.js',
}
