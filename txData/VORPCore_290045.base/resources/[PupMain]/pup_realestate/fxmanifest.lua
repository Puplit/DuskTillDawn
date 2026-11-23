fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_realestate'
description 'Player housing: houses, motel rooms, furniture, storage, tax and auctions'
version '2.0.0'

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
}

shared_scripts {
    'config/main.lua',
    'config/furniture.lua',
    'config/upgrades.lua',
    'shared/locale.lua',
    'shared/util.lua',
    'shared/catalog.lua',
}

client_scripts {
    'client/doors.lua',
    'client/main.lua',
    'client/menu.lua',
    'client/menus.lua',
    'client/prompts.lua',
    'client/interiors.lua',
    'client/world.lua',
    'client/creator.lua',
    'client/auctions.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- server-only settings (webhooks)
    'server/main.lua',
    'server/logs.lua',
    'server/storage.lua',
    'server/doorlocks.lua',
    'server/mail.lua',
    'server/houses.lua',
    'server/furniture.lua',
    'server/tax.lua',
    'server/auctions.lua',
    'server/admin.lua',
    'server/interiors.lua',
    'server/boot.lua',
}
