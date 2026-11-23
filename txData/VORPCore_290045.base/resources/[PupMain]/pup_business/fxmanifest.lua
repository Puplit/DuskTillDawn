fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'pup_business'
description 'Businesses: ranks, permissions, ledger, salaries, tax, bills, stash, duty and admin tools'
version '2.0.0'

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/stations.lua',
    'shared/util.lua',
    'locale/en.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/core.lua',
    'server/rpc.lua',
    'server/db.lua',
    'server/business.lua',
    'server/logs.lua',
    'server/ledger.lua',
    'server/duty.lua',
    'server/staff.lua',
    'server/bills.lua',
    'server/tax.lua',
    'server/stash.lua',
    'server/dashboard.lua',
    'server/admin.lua',
    'server/exports.lua',
    'server/restart.lua',
    'server/main.lua',
}

client_scripts {
    'client/rpc.lua',
    'client/ui.lua',
    'client/prompt.lua',
    'client/main.lua',
    'client/jobmenu.lua',
    'client/dashboard.lua',
    'client/duty.lua',
    'client/admin.lua',
}
