fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'pup_id'
description 'Character identity papers: look at your own, hand it over, or read a restrained person\'s.'
version '2.0.0'

shared_scripts {
    'config/main.lua',
    'locale/en.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/paper.css',
    'html/paper.js',
    'html/img/logo.png',
    'html/fonts/Rye-Regular.ttf',
    'html/fonts/OFL-Rye.txt',
    'html/fonts/IMFellEnglish-Regular.ttf',
    'html/fonts/IMFellEnglish-Italic.ttf',
    'html/fonts/OFL-IMFellEnglish.txt',
    'html/fonts/MrsSaintDelafield-Regular.ttf',
    'html/fonts/OFL-MrsSaintDelafield.txt',
}

dependencies {
    'vorp_core',
    'oxmysql',
}
