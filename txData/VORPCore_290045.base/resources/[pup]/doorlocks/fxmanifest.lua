fx_version "cerulean"
games {"rdr3"}
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."
lua54 "yes"

-- Based on gs_doorlocks v1.0.5 by _G[S]cripts (GlitchOo), https://github.com/GlitchOo/gs_doorlocks, GPL-3.0. Modified; see README.
author '_G[S]cripts (GlitchOo), modified by Puppet'
description 'Create and manage doors for RedM - pup-ui + pup-minigames'
version '1.0.5-pup'

shared_scripts {
  'config/main.lua',
  'config/custom_doors.lua', -- MLO doors the game's door system does not list
  'config/doors.lua',
  'utils/shared/*.lua',
}

client_scripts {
  'utils/client/*.lua',
  'client/*.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/*.lua'
}

files {
  'locales/*.json'
}

-- menus and text input come from pup-ui
dependency {
  'oxmysql',
  'vorp_core',
  'vorp_inventory',
  'pup-ui',
  'pup-minigames',
}
