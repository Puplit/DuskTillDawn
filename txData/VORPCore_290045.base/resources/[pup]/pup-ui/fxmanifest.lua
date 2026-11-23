fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'pup-ui - RDR2 Online style interface layer: toasts, event banners, rank bar. Self-contained NUI. The one external asset is the kibook/webmap map image behind the app map block, loaded from GitHub at runtime and not shipped.'
version '0.1.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'ptt.lua', -- loaded by other resources as '@pup-ui/ptt.lua', so it must be packaged
    'html/index.html',
    'html/style.css',
    'html/app.js',
    -- every font in html/fonts is sent, so a font named in config/theme.lua only needs dropping in there
    'html/fonts/*.ttf',
    'html/fonts/*.otf',
    'html/audio/door_denied.ogg',
    -- menu textures
    'html/img/western/inkroller_1a.png',
    'html/img/western/menu_header_1a.png',
    'html/img/western/divider_line.png',
    'html/img/western/selection_box_bg_1d.png',
    'html/img/western/selsected.png',
    'html/img/western/selection_box.png',
    'html/img/western/selected-item-box.png',
    'html/img/western/scroller_right_bottom.png',
    'html/img/western/double_border.png',
    'html/img/western/grid.png',
    'html/img/western/tick.png',
    'html/img/western/menu_icon_circle.png',
    -- character-select skin textures
    'html/img/western/cs_bg.png',
    'html/img/western/cs_btn.png',
    'html/img/western/cs_header.png',
    'html/img/western/cs_sep.png',
}

shared_scripts {
    'config/main.lua',
    'config/theme.lua',
    'shared/theme.lua',
}

client_scripts {
    'client/main.lua',
    'client/inkmenu.lua',
    'client/pricepicker.lua',
    'client/menucompat.lua',
    'client/world3d.lua',
    'client/placement.lua',
    'client/posse.lua',
}

server_scripts {
    'server/posse.lua',
}
