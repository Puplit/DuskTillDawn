fx_version 'adamant'
game 'rdr3'
lua54 'yes'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/main.lua',
    'config/boards.lua',
    'config/locale.lua',
    'server/config.lua', -- server only: the Discord webhook (Secrets.Webhooks)
    'server/main.lua',
}

-- config is not in shared_scripts so ptt.lua stays the first client file
client_scripts {
    '@pup-ui/ptt.lua',
    'config/main.lua',
    'config/boards.lua',
    'config/locale.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

-- the page uses ES modules: every imported file must be listed
files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.svg',
    'html/fonts/*.ttf',
}
