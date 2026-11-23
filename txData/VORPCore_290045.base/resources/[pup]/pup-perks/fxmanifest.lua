fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'pup'
description 'pup-perks - per-character civ/crime ability cards'
version '1.1.0'

shared_scripts {
    'config/main.lua',
    'config/trees.lua',
    'config/xp.lua',
    'config/perks.lua',
    'config/guide.lua',
    'config/locale.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/perks.js',
    'html/style.css',
    'html/fonts/oswald.ttf',
    'html/fonts/imfell.ttf',
    -- western-style art (same family as pup-ui's menus)
    'html/img/western/divider_line.png',
    'html/img/western/grid.png',
    'html/img/western/double_border.png',
    'html/img/western/selection_box_bg_1d.png',
    'html/img/western/selsected.png',
    'html/img/western/inkroller_1a.png',
    'html/img/western/menu_header_1a.png',
}

-- pup-ui is used for toasts (pup-perks:toast)
dependency 'pup-ui'
