fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

server_script {
	'config/main.lua',
	'server/config.lua', -- webhooks, server only; must load after config/main.lua
	'server/main.lua',
}

client_script {
	'client/weapons.lua',
	'client/main.lua',
}