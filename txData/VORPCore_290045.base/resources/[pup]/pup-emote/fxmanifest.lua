fx_version 'adamant'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'pup'
description 'Emote wheel: a few saved emotes on a radial, kept per character'

-- the emotes themselves belong to pup-misc; this only picks and plays them
dependency 'pup-ui'

shared_scripts {
    'config/main.lua',
    'config/emotes.lua',
    'config/locale.lua',
    'shared/emotes.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
