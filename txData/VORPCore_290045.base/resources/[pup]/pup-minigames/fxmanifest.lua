fx_version 'adamant'

game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Dusk Till Dawn'

description 'Minigame library (skill bar, safe crack, pin code and more) used by other resources through exports'

version '0.0.1'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/**/*',
}
client_scripts {
    '@pup-ui/ptt.lua', -- push-to-talk survives NUI focus; must load first
    'config/main.lua',
    'client/main.lua',
    'client/**/*',
}
