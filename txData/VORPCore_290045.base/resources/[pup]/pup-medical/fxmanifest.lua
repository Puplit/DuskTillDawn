fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup-medical'
author 'Puppet'
description 'Job alerts, call pay, duty, doctors, cabinets, the death screen and respawn rules'
version '2.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/medical.lua',
    'config/death.lua',
    'config/alerts.lua',
    'config/zones.lua',
    'config/locale.lua',
    'shared/switches.lua',
    'shared/util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- webhooks, server only; before core.lua
    'server/core.lua',
    'server/duty.lua',
    'server/restart.lua',
    'server/callpay.lua',
    'server/alerts.lua',
    'server/losses.lua',
    'server/respawn.lua',
    'server/medical.lua',
    'server/purge.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/alerts.lua',
    'client/medical.lua',
    'client/recovery.lua',
    'client/death.lua',
    'client/deathcam.lua',
    'client/purge.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}
