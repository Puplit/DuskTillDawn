fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pup-magic'
description 'Vampire feeding, blood vials that lend a face, and the staff spell kit'
version '2.0.0'

-- order matters: main creates Config, locale creates Locale before spells reads it,
-- shared/spells.lua checks the spells and builds MagicKeys last
shared_scripts {
    'config/main.lua',
    'config/locale.lua',
    'config/spells.lua',
    'config/limits.lua',
    'shared/spells.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- webhook, server only
    'server/casters.lua',
    'server/util.lua',
    'server/logs.lua',
    'server/curse.lua',
    'server/feeding.lua',
    'server/disguise.lua',
    'server/spells.lua',
}

client_scripts {
    'client/util.lua',
    'client/aim.lua',
    'client/feeding.lua',
    'client/victim.lua',
    'client/vials.lua',
    'client/spells.lua',
    'client/effects.lua',
}

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
}
