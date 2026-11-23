fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'pup_library'
description 'Write, print, publish and sell books, newspapers, magazines, letters and contracts.'
version '2.0.0'

shared_scripts {
    'config/main.lua',
    'locale/en.lua',
}

client_scripts {
    'client/menu.lua',
    'client/book.lua',
    'client/library.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/clean.lua',
    'server/main.lua',
    'server/library.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/book.css',
    'html/clean.js',
    'html/writer.js',
    'html/book.js',
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}
