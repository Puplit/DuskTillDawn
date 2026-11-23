fx_version 'adamant'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'Puppet'
version '2.0.0'
description 'The Staff Desk: parcels from staff, character changes, bug bounty, playtime and a Discord command bridge'

shared_scripts {
    'config/main.lua',
    'config/weapons.lua',
    'config/locale.lua',
    'shared/util.lua',
}

client_scripts {
    'client/panel.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',   -- server-only settings (webhook, Discord bot)
    'config/discord.lua',
    'server/core.lua',
    'server/db.lua',
    'server/parcels.lua',
    'server/changes.lua',
    'server/bounty.lua',
    'server/playtime.lua',
    'server/main.lua',
    'server/discord/bridge.lua',
    'server/discord/actions.lua',
    'server/discord/bans.lua',
    'server/discord/reports.lua',
    'server/discord/catalogue.lua',
}

server_exports {
    'SendParcel',
    'GetBountyPoints',
    'AddBountyPoints',
    'GetPlaytime',
    'AddDiscordCommand',
    'ModifyCharName',
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'pup-ui',
    'oxmysql',
}
