-- pup-spawnselect: pick where your character wakes up

fx_version 'adamant'
game 'rdr3'
version '1.0.0'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_scripts {
    'config/main.lua',
    'config/spawns.lua',
    'config/locale.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/config.lua', -- server only: the Discord webhook (Secrets.Webhooks)
    'server/main.lua',
}

dependencies {
    'vorp_core',
    'oxmysql',
}
