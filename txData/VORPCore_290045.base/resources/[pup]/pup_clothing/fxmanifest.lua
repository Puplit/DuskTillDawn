fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_clothing'
description 'Clothing stores, wardrobes, garment toggles and the extras store (colours and singleplayer garments).'
version '2.0.0'

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_character',
    'vorp_inventory',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/catalogue.lua',
    'locale/en.lua',
    'shared/util.lua',
    'data/cloth_hash_names.lua',
    'shared/catalogue.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/main.lua',
}

client_scripts {
    '@vorp_core/client/dataview.lua',
    'client/ped.lua',
    'client/extras.lua',
    'client/toggles.lua',
    'client/store.lua',
    'client/wardrobe.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
