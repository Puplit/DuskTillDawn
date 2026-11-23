-- Modified by Puppet (Dusk Till Dawn), 2026
fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

-- Built on VORP's admin menu and heavily modified: it is the server's control
-- panel for every other script, plus its anti-cheat.
author 'VORP @outsider - modified by Puppet'
description 'Server control panel and anti-cheat: admin menu, web panel and live map, staff tools for the other scripts (stables, doors, events), bans, audit log, cash watch, spawn guard, Steam and VPN gates'
lua54 'yes'

dependency 'pup-ui'

shared_script {
    'config/main.lua', -- creates Config: must load first
    'config/permissions.lua', -- VORP group -> action sets
    'config/discord.lua', -- Discord role -> permission mapping
    'config/anticheat.lua', -- detector thresholds (no secrets; client needs them)
    'languages/translation.lua',
}

client_scripts { -- explicit list: load order matters (dashboard.lua, then panel.lua, near the end)
    '@pup-ui/ptt.lua', -- push-to-talk survives NUI focus; must load first
    'pupmenu.lua', -- so its OpenMenu override wins over functions.lua
    'client/admin.lua',
    'client/boosters.lua',
    'client/client.lua',
    'client/database.lua',
    'client/datapeds.lua',
    'client/dataprops.lua',
    'client/devTools.lua',
    'client/functions.lua',
    'client/datapeds_verified.lua', -- models known to render as a player ped
    'client/pedmenu.lua', -- after datapeds.lua: it builds its catalog from Peds
    'client/stableadmin.lua', -- horses/wagons
    'client/teleport.lua',
    'client/users.lua',
    'client/dashboard.lua',
    'client/panel.lua', -- NUI web panel; must load AFTER dashboard.lua (captures its OpenMenu)
    'client/pup_antiCheat.lua', -- movement detectors
    'client/pup_cleanup.lua', -- owner-side delete for the cleanup sweep
    'client/pup_worldCleanup.lua', -- world cleanup: reports what you ride, panel button
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua', -- webhooks and keys (server only); before any server file (bans.lua reads it at load)
    'config/guard.lua', -- spawn guard: server only, nothing on the client reads it
    'config/worldcleanup.lua', -- Anti-Cheat "Clear spawned entities": server only
    -- explicit list: load order matters
    'server/bans.lua',
    'server/pup_antiCheat.lua',
    'server/pup_auditLog.lua',
    'server/pup_cashWatch.lua',
    'server/pup_cleanup.lua',
    'server/pup_discordPerms.lua',
    'server/pup_doorLocks.lua',
    'server/pup_events.lua',
    'server/pup_flagStore.lua',
    'server/pup_spawnGuard.lua',
    'server/pup_steamGate.lua',
    'server/pup_vpnGate.lua',
    'server/pup_worldCleanup.lua',
    'server/server.lua',
}

ui_page 'html/index.html'

files { -- Credits to https://github.com/LVRP-BEN/bl_coords for clipboard copy method
    'html/index.html',
    'html/index.js',
    'html/panel.css',
    'html/panel.js',
    -- live map = Leaflet over kibook/webmap's rdr3 map.jpg, loaded from its public
    -- GitHub URL (not shipped here: it has no licence); panel.js carries the URL and calibration
    'html/vendor/leaflet.js',
    'html/vendor/leaflet.css',
    -- real RDR2 blip sprites cut to PNG; the live map falls back to its own
    -- glyphs for any layer with no file here. See html/img/blips/README.md
    'html/img/blips/*.png',
    -- pup: western restyle art (same family as pup-ui / pup-stable menus)
    'html/img/western/divider_line.png',
    'html/img/western/selection_box_bg_1d.png',
    'html/img/western/selsected.png',
    'html/img/western/menu_header_1a.png',
    'html/img/western/grid.png',
    'html/img/western/double_border.png',
}

-- Version check dont touch
version '2.6'
vorp_checker 'no'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_admin'
