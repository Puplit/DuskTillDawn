fx_version "adamant"
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game "rdr3"

-- config is client-only: server.lua is empty and the NUI page gets it from hudmove.lua
-- hudmove.lua loads AFTER client.lua: it only adds the layout menu and never touches the gauge feed
client_script {
	'@pup-ui/ptt.lua', -- push-to-talk survives NUI focus; must load first
	'config/main.lua',
	'config/locale.lua',
	'client.lua',
	'hudmove.lua'
 }

server_script {
	'server.lua'
}

-- jQuery comes from the game itself (nui://game/ui/jquery.js in index.html)
ui_page('html/index.html')
files({
	"html/script.js",
	"html/styles.css",
	"html/img/*.svg",
	"html/img/*.png",
	"html/index.html",
})

export 'StressaPlayer'