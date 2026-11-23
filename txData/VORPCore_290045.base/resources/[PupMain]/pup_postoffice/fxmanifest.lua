fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup_postoffice'
description 'PO boxes, chats, letters and business mail'
version '3.1.0'

dependencies {
    'vorp_core',
    'oxmysql',
    'pup-ui',
}

shared_scripts {
    'shared/config.lua',
    'shared/locale.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- server-only settings (webhooks)
    'server/util.lua',
    'server/mailbox.lua',
    'server/letters.lua',
    'server/business.lua',
    'server/chats.lua',
    'server/exports.lua',
    'server/schema.lua',
}

-- ptt.lua first: it keeps push-to-talk working while the mail window has focus
client_scripts {
    '@pup-ui/ptt.lua',
    'client/main.lua',
    'client/office.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/util.js',
    'html/js/settings.js',
    'html/js/emoji.js',
    'html/js/app.js',
}
