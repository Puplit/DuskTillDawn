-- Modified by Puppet (Dusk Till Dawn), 2026
fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'


name 'vorp character'
author 'VORP @outsider' -- Initial Convertion from C# to lua by grumpypoo
description 'A Character creator with also shops built in for vorpcore framework'

dependency 'pup-ui'

shared_scripts {
	'config/main.lua', -- must load first: the data files below add to Config
	'config/spawns.lua',
	'config/appearance.lua',
	'config/overlays.lua',
	'config/components.lua',
	'config/shops.lua',
	'shared/utils.lua',
	'shared/translation.lua',
}

client_scripts {
	'@vorp_core/client/dataview.lua',
	'shared/clothing.lua',
	'shared/hairs.lua',
	'pup_form.lua', -- pup-ui InkMenu transport shim (replaces the legacy focused menu); must load before client scripts
	'client/*.lua',
}

server_scripts {
	'server/config.lua', -- webhooks (server only)
	'@oxmysql/lib/MySQL.lua',
	'server/pup_charcards.lua',
	'server/pup_charcode.lua',
	'server/pup_height.lua',
	'server/pup_secondchance.lua',
	'server/server.lua',
}

files {
	'images/*png',
	'images/clothingfemale/*png',
	'images/eyes/*png',
	'images/skin/*png',
	-- the face & body page (client/facepage.lua), plus character select and the spawn picker
	'ui/index.html',
	'ui/app.js',
	'ui/style.css',
	'ui/charselect.js',
	'ui/charselect.css',
	'ui/img/*.png',
	'ui/img/slider/*.png',
	'ui/fonts/*.ttf',
}

ui_page 'ui/index.html'


version '2.1'
vorp_checker 'no'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_character-lua'

-- this script is protected under its license.
