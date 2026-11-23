fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup-mdt'
description 'Law and justice terminal: duty, records, jail, bounties, alerts, the legal side'
version '2.0.0'
license 'GPL-3.0-or-later'

shared_scripts {
    'config/config.lua',
    'config/legal.lua',
    'config/prison.lua',
    'config/world.lua',
    'config/confiscation.lua',
    'shared/locale.lua',
    'locales/*.lua',
    'shared/zones.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/core.lua',
    'server/permissions.lua',
    'server/duty.lua',
    'server/lawmen.lua',
    'server/records.lua',
    'server/public.lua',
    'server/penal.lua',
    'server/ledger.lua',
    'server/prison.lua',
    'server/legal.lua',
    'server/firm.lua',
    'server/bounties.lua',
    'server/reports.lua',
    'server/lockers.lua',
    'server/alerts.lua',
    'server/admin.lua',
    'server/main.lua',
}

client_scripts {
    'client/*.lua',
}

ui_page 'html/index.html'

files {
    'html/**/*',
}

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
}
