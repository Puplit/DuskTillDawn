fx_version 'adamant'
games { 'rdr3', 'gta5' }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
author 'JaredScar'
description 'DiscordQueue-AdaptiveCards (Badger_Discord_API merged in)'
version '2.0'
url 'https://github.com/JaredScar/Bad-DiscordQueue'

client_scripts {
	'client.lua',
}

-- Badger_Discord_API is bundled in (discord_api.lua, client.lua)
-- Config is server side only (connection queue). Bot token and webhook are in server/config.lua.
server_scripts {
	'config/main.lua',
	'config/locale.lua',
	'server/config.lua',
	'discord_api.lua',
	'server.lua',
	'SharedQueue.lua',
	'pup_exports.lua', -- exposes GetDiscordRoles to other resources
}
