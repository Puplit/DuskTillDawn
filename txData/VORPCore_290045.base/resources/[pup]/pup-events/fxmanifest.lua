fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'pup-events - seasonal event framework. Dead of Night is the first event.'

shared_scripts {
    'config/main.lua',
    'config/events.lua',
    'config/deadofnight.lua',
    'config/tricktreat.lua',
    'config/tricktreat_doors.lua',
    'config/easter.lua',
    'config/purgecaches.lua',
    'config/purgecache_sites.lua',
    'config/locale.lua',
    'shared/purgeloot.lua',   -- PurgeLootConfigured helper
}

client_scripts {
    'client/main.lua',
    'client/purge.lua',
    'client/purgeloot.lua',
    'client/purgeposse.lua',
    'client/purgegrabs.lua',
    'client/ambience.lua',
    'client/specials.lua',
    'client/tricktreat.lua',
    'client/easter.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- webhook URLs, server only, loaded first
    'server/main.lua',
    'server/purge.lua',
    'server/purgesiren.lua',
    'server/purgeloot.lua',
    'server/tricktreat.lua',
    'server/easter.lua',
}

-- xsound fetches the siren over cfx-nui, so it has to be served; drop your own file in sounds/
files {
    'sounds/*',
}

dependencies {
    -- weathersync is optional (installed separately): without it, hour windows never open
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
}
