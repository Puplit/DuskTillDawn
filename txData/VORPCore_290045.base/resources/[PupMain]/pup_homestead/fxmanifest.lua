fx_version 'adamant'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'Puppet'
version '2.0.0'
description 'Homestead farming: plant, water, feed, trim and harvest crops, with an Almanac of your plots'

shared_scripts {
    'config/main.lua',
    'config/crops.lua',
    'config/locale.lua',
    'shared/crops.lua',
}

client_scripts {
    'client/field.lua',
    'client/water.lua',
    'client/prompts.lua',
    'client/almanac.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/store.lua',
    'server/field.lua',
    'server/water.lua',
    'server/restart.lua',
    'server/main.lua',
}

server_exports { 'GetPlants', 'RemovePlant', 'IsRaining' }

-- pup-minigames is needed only while Config.Minigame.enabled is true
dependencies { 'vorp_core', 'vorp_inventory', 'oxmysql', 'pup-ui' }
