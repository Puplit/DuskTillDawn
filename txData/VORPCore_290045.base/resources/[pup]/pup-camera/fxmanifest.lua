fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup-camera'
author 'pup'
description 'Staff photo and cinematic camera. Steam-locked, server validated.'
version '1.0.0'

dependency 'pup-ui' -- the list menu

shared_scripts {
    'config/main.lua',
    'config/presets.lua',
    'config/locale.lua',
}

client_scripts {
    'client/pupmenu.lua', -- must load before client/main.lua, which calls PupMenu
    'client/main.lua',
}

server_scripts {
    'config/access.lua', -- access settings: server only
    'server/config.lua', -- staff steam ids: server only; after access.lua, which creates Config.Access
    'server/main.lua',
}
