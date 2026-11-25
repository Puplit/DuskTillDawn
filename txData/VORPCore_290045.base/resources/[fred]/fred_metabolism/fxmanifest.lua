

fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

shared_scripts {
    'config/main.lua',
    'config/consumables.lua',
    'config/locale.lua',
}

client_scripts {
    'animations.lua', -- pup: consume animations (must load before client.lua)
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- pup: await-style DB for the admin-managed consumables
    'server.lua',
}

export 'getThirst'
export 'getHunger'
export 'getEffectiveTemp' -- pup: clothing-adjusted temp for fred_hud