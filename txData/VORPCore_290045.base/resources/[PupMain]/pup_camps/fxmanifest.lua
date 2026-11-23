fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_camps'
description 'Player camps: founding, members, safe and taxes, furniture, camp economy, missions, raids, public butchers, snake poison and the hunting wagon'
version '2.0.0'

shared_scripts {
    'config/main.lua',
    'config/places.lua',
    'config/furniture.lua',
    'config/animals.lua',
    'config/missions.lua',
    'config/integrations.lua',
    'locale/en.lua',
    'shared/util.lua',
}

client_scripts {
    'client/core.lua',
    'client/menu.lua',
    'client/interact.lua',
    'client/world.lua',
    'client/raids.lua',
    'client/campmenu.lua',
    'client/founding.lua',
    'client/furniture.lua',
    'client/missions.lua',
    'client/hunting.lua',
    'client/functional.lua',
    'client/poison.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/main.lua',
    'server/store.lua',
    'server/logs.lua',
    'server/camps.lua',
    'server/furniture.lua',
    'server/stash.lua',
    'server/functional.lua',
    'server/hunting.lua',
    'server/poison.lua',
    'server/missions.lua',
    'server/raids.lua',
    'server/taxes.lua',
    'server/staff.lua',
    'server/admin.lua',
    'server/lifecycle.lua',
}

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
}
