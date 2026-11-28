fx_version "adamant"

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
author 'Blue'

game "rdr3"




client_script {
    'client/main.lua',
}

shared_scripts {
    'shared/functions.lua',
    'config/locale.lua',
    'config/main.lua',
    -- shared, not client-only: the server's distance check reads Config.Nodes from it
    'config/data.lua',
}

server_scripts {
    'server/config.lua', -- webhook, server only; after the shared config/main.lua, before main
    'server/main.lua'
}

-- swing minigame (skill bar); gathering cannot work without it
dependency 'pup-minigames'
