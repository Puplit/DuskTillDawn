fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'pup'
description 'Server and client diagnostics'
version '1.1.0'

shared_scripts {
    'config/main.lua',
    'config/locale.lua',
}
client_scripts {
    'client/main.lua',
    'client/sync.lua',  -- instanced-player check: evidence, warning text
}
server_scripts {
    'server/config.lua', -- webhook urls, server only; loads first
    'server/main.lua',
    'server/sync.lua',  -- answers the probe with the server's view of the ped
}
