fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'pup-trash - public bins that empty on every server restart'
version '1.0.0'

shared_scripts {
    'config/main.lua',
    'config/locations.lua',
    'config/locale.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies {
    'vorp_core',
    'vorp_inventory',
    'oxmysql',
}
