fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Puppet'
version '1.1.0'
description 'pup-loading - themed loading screen, set up from html/config.js'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes' -- the music controls need a pointer

-- every file in img/, audio/ and fonts/ is sent to players
files {
    'html/index.html',
    'html/style.css',
    'html/config.js',
    'html/app.js',
    'html/img/*',
    'html/audio/*',
    'html/fonts/*',
}

shared_script 'config/main.lua'
client_script 'client/main.lua'
