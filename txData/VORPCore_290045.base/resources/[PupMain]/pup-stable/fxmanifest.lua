fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup-stable'
description 'Town stables: horses, tack, wagons, care, training, breeding and wild horses'
version '3.0.0'

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/stables.lua',
    'config/horses.lua',
    'config/wagons.lua',
    'config/items.lua',
    'config/locale.lua',
    'shared/util.lua',
    'shared/horseComponentsData.lua',
    'shared/wagonData.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- webhooks, server only; before core.lua
    'config/horse_stats.lua', -- birth ranks by model, server only
    'server/core.lua',
    'server/schema.lua',
    'server/store.lua',
    'server/world.lua',
    'server/care.lua',
    'server/horses.lua',
    'server/wagons.lua',
    'server/wild.lua',
    'server/breeding.lua',
    'server/starter.lua',
    'server/admin.lua',
    'server/misc.lua',
    'server/init.lua',
}

client_scripts {
    '@pup-ui/ptt.lua', -- push-to-talk keeps working while the menu page has focus
    'client/natives.lua',
    'client/core.lua',
    'client/nui.lua',
    'client/look.lua',
    'client/horse.lua',
    'client/wagon.lua',
    'client/stable.lua',
    'client/menus.lua',
    'client/actions.lua',
    'client/breeding.lua',
    'client/info.lua', -- uses N, U, Horse, Me; care.lua calls it
    'client/care.lua',
    'client/wild.lua',
    'client/misc.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
