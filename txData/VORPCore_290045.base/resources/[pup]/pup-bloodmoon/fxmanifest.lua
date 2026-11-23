fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name        'pup-bloodmoon'
description 'Blood moon: clear night sky, a dominating moon and a red cast, raised by a lycan howl or by hand'
version     '1.0.0'
author      'Puppet'
lua54 'yes'

shared_scripts {
    'config/main.lua',
    'config/locale.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'vorp_core',
    -- weathersync is optional (installed separately): every call to it is pcall-guarded
    'pup_shaman', -- the howl, and the GetCurse export the howl is gated on
}
