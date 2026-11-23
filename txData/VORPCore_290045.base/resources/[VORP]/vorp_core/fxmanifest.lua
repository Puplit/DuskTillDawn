fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'vorp core'
description 'A Tool to build your RedM server and scripts'
author 'VORP' -- converted from the original C# vorp core by goncalobsccosta#9041
repository 'https://github.com/VORPCORE/vorp-core-lua'

dependency 'pup-ui'

shared_scripts {
    'config/config.lua',
    'config/skills.lua',
    'translation/language.lua'
}

client_scripts {
    'client/ref/*.lua',
    'client/exports/*.lua',
    'client/coreactions.lua',
    'client/pupmenu.lua',
    'client/*.lua',
}

server_scripts {
    'config/logs.lua',
    'config/jobs.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/class/*.lua',
    'config/commands.lua',
    'server/*lua', -- includes server/config.lua (webhooks); after config/logs.lua, and Logs is only read at runtime
    'server/services/dbupdater/*.lua',
}

files {
    'ui/**/*',
}

ui_page 'ui/hud.html'

version '3.3'
vorp_checker 'no'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_core-lua'
