fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_mortician'
description 'The undertaker trade: prep tables, caskets, burials, a contract board and treasure digging'
version '3.0.0'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
    'pup-ui',
    'pup-minigames',
}

shared_scripts {
    'shared/config.lua',
    'shared/locale.lua',
    'shared/rules.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/core.lua',
    'server/db.lua',
    'server/limit.lua',
    'server/tables.lua',
    'server/ledger.lua',
    'server/contracts.lua',
    'server/digging.lua',
    'server/burial.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/props.lua',
    'client/carry.lua',
    'client/work.lua',
    'client/ledger.lua',
    'client/contracts.lua',
    'client/shovel.lua',
    'client/main.lua',
}
