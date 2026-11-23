fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'pup_gunsmith'
description 'Gun store counters, weapon and ammo crafting, ammo boxes and the customization bench'
version '3.0.0'

shared_scripts {
    'config/main.lua',
    'config/locations.lua',
    'config/shop.lua',
    'config/tiers.lua',
    'config/names.lua',
    'locale/en.lua',
    'shared/parts.lua',
    'shared/util.lua',
    'shared/catalogue.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/seeds.lua',
    'server/config.lua',
    'server/core.lua',
    'server/discord.lua',
    'server/schema.lua',
    'server/recipes.lua',
    'server/ammo.lua',
    'server/stations.lua',
    'server/shop.lua',
    'server/craft.lua',
    'server/bench.lua',
    'server/bench_presets.lua',
    'server/bench_workshop.lua',
    'server/equip.lua',
    'server/misc.lua',
}

client_scripts {
    'client/core.lua',
    'client/prompts.lua',
    'client/shop.lua',
    'client/craft.lua',
    'client/gunobject.lua',
    'client/bench.lua',
    'client/preview.lua',
    'client/refit.lua',
    'client/misc.lua',
}

ui_page 'html/bench.html'

files {
    'html/bench.html',
    'html/bench.css',
    'html/bench.js',
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
    'pup-minigames',
}
