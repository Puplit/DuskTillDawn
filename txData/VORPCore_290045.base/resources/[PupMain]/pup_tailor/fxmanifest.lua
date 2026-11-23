fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_tailor'
description 'Tailor benches: design outfits on a mannequin, copy what you wear, dye clothing once.'
version '2.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/catalogue.lua',
    'locale/en.lua',
    'shared/util.lua',
    'shared/palettes.lua',
    'shared/cloth_hash_names.lua',
    'shared/npc_clothing.lua',
    'shared/catalogue.lua',
    'shared/wear.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/hidden.lua',
    'server/palettes.lua',
    'server/make.lua',
    'server/dye.lua',
    'server/wear.lua',
}

client_scripts {
    'client/ped.lua',
    'client/main.lua',
    'client/menus.lua',
    'client/dyebook.lua',
    'client/wear.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/book.css',
    'html/book.js',
}
