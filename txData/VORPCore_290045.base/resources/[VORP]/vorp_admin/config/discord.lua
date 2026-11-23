-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_admin | Discord role permissions
-- Maps Discord roles to admin permissions. Turn it off to use Config.Permissions.groups
-- (config/permissions.lua) alone.

-------------------------------------------------------------------------------
-- DISCORD PERMISSIONS
-------------------------------------------------------------------------------
Config.DiscordPermissions = {
	enabled          = true, -- false = ignore Discord entirely and use Config.Permissions.groups (the VORP group table)
	-- Discord cannot be reached (no bot token, API down, rate limited, player has no Discord
	-- linked): true = fall back to the VORP group table, false = deny
	fallbackToGroups = true,
	cacheSeconds     = 60,   -- how long a player's resolved permission set is cached
}

-- ROLES. Key = Discord role id (as a string). One block per role:
--   name  = label for your own reference
--   perms = friendly names from permissionGroups below ("players.kick"), a whole group
--           with a wildcard ("teleport.*"), a raw action key ("devtools_menu"), or "all"
-- Example:
--   ["123456789012345678"] = { name = "Support", perms = { "menu.open", "players.heal" } },
-- The keys below are placeholders: replace each with your own Discord role id.
Config.DiscordPermissions.roles = {

	["OWNER_ROLE_ID"] = {
		name = "Owner",
		perms = { "all" },
	},

	["MANAGEMENT_ROLE_ID"] = {
		name = "Management",
		perms = { "all" },
	},
	["DEVELOPER_ROLE_ID"] = {
		name = "Developer",
		perms = { "all" },
	},

	-- Sees everything, reaches nobody. The Live Map, the Anti-Cheat tab and the
	-- Players list are all open to them, and they can heal, kick and ban.
	-- NOT in this list, so the buttons never render: teleport.toplayer (Go To),
	-- teleport.bring (Bring), players.spectate. No revive, no give, no troll.
	-- "players.openinv" would add the live two-way inventory panel, which is the
	-- one thing that would let this role take items out.
	["MODERATOR_ROLE_ID"] = {
		name = "Moderator",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"scenes.manage",   -- place and delete /scene markers
			"security.panel",   -- Anti-Cheat tab
			"players.view",     -- Players page and the read-only item list
			"players.heal",     -- patch someone up, but NOT revive
			"players.kick",
			"bans.view",        -- read the Server Bans list
			"bans.issue",       -- and place one. NOT bans.lift - see the unban group
			-- Tools page. The nav button itself is gated on devtools_menu, so without
			-- it the whole section is hidden however many tool keys they hold.
			"devtools_menu",
			"dev.*",            -- /devgun, and the Ped Menu
			"invisibility",
			"teleport_to_guarma",
		},
	},

	-- Moderator plus the tools to actually act on what they see: freeze, kick,
	-- pick a player up and put them back, patch them up. No ban, no giving
	-- anything out, no troll, nothing from destroy.
	["SENIOR_MODERATOR_ROLE_ID"] = {
		name = "Senior Moderator",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"scenes.manage",   -- place and delete /scene markers
			"security.panel",
			"players.view",
			"players.spectate",   -- watch a player, and the Spectate button on a map pin
			"players.freeze",
			"players.heal",
			"players.revive",
			"teleport.toplayer",
			"teleport.bring",
			"teleport.sendback",
			"teleport.playerback",
			"teleport.noclip",
			"self.heal",
			"self.revive",
			"bans.view",
			"bans.issue",        -- NOT bans.lift - see the unban group
			"devtools_menu",     -- gates the Tools nav button itself
			"dev.*",             -- /devgun, and the Ped Menu
			"invisibility",
			"teleport_to_guarma",
		},
	},

	-- Senior Moderator plus bans, handing things out, and the troll menu.
	-- Player tools, plus world props. Nothing else from destroy.
	["ADMIN_ROLE_ID"] = {
		name = "Admin",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"scenes.manage",   -- place and delete /scene markers
			"security.panel",
			"players.view",
			"players.openinv",    -- the live two-way inventory panel
			"players.spectate",
			"players.freeze",
			"players.kick",
			"players.ban",
			"players.unban",
			"players.banoffline",
			"players.whitelist",
			"players.heal",
			"players.revive",
			"players.respawn",
			"players.godmode",
			"players.ammo",
			"players.cores",
			"stable.admin",    -- another player's horses and wagons
			-- Server Bans: admin is the first rank that may LIFT one
			"bans.view",
			"bans.issue",
			"unban.lift",
			"teleport.*",
			"self.*",
			"spawn.*",
			"troll.*",
			-- Tools/Dev tab: prop placer, dev laser, zone creator
			"devtools_menu",
			-- dev.* carries the dev laser and the Ped Menu
			"dev.*",
			-- the rest of the Tools page
			"invisibility",
			"teleport_to_guarma",
			-- World Props page: list, place and delete
			"props.*",
			"destroy.prop",
			-- create, edit and delete door locks
			"manage_doorlocks",
			"manage.curses",   -- pup_shaman: the Curses page
			"manage.farms",    -- pup_homestead: the Farms page
			"desk.manage",     -- pup_staffdesk: /parcel creates cash, items and weapons
		},
	},

	-- Admin plus the announce line. Player tools and world props; nothing else
	-- from destroy, no management panels.
	["HEAD_ADMIN_ROLE_ID"] = {
		name = "Head Admin",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"scenes.manage",   -- place and delete /scene markers
			"menu.announce",
			"security.panel",
			"cleanup.world",   -- Anti-Cheat: Clear spawned entities (everyone's, after a countdown)
			-- NOT "players.*": that wildcard would also hand over clearinv and
			-- clearcash, which empty a player's satchel and wallet. Listed out.
			"players.view",
			"players.openinv",
			"players.spectate",
			"players.freeze",
			"players.kick",
			"players.ban",
			"players.unban",
			"players.banoffline",
			"players.whitelist",
			"players.heal",
			"players.revive",
			"players.respawn",
			"players.givemoney",
			"players.givehorse",
			"players.givewagon",
			"players.godmode",
			"players.ammo",
			"players.cores",
			"stable.admin",    -- another player's horses and wagons
			"bans.view",
			"bans.issue",
			"unban.lift",
			"teleport.*",
			"self.*",
			"spawn.*",
			"troll.*",
			"devtools_menu",
			"dev.*",              -- dev laser + Ped Menu
			"invisibility",
			"teleport_to_guarma",
			"props.*",
			"destroy.prop",
			"manage_doorlocks",
			"manage.curses",   -- pup_shaman: the Curses page
			"manage.farms",    -- pup_homestead: the Farms page
			"desk.manage",     -- pup_staffdesk: /parcel creates cash, items and weapons
		},
	},

	["HOUSING_TEAM_ROLE_ID"] = {
		name = "Housing Team",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"players.spectate", -- watch a player, and the Spectate button on a map pin
			"scenes.manage",   -- place and delete /scene markers
			"manage.housing",   -- NOT destroy.housing
		},
	},

	["GANG_TEAM_ROLE_ID"] = {
		name = "Gang Team",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"players.spectate", -- watch a player, and the Spectate button on a map pin
			"scenes.manage",   -- place and delete /scene markers
			"manage.gangs",
		},
	},

	["BUSINESS_TEAM_ROLE_ID"] = {
		name = "Business Team",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"players.spectate", -- watch a player, and the Spectate button on a map pin
			"scenes.manage",   -- place and delete /scene markers
			"manage.society",   -- NOT destroy.society
		},
	},

	-- Runs hideouts: ledger, stash, owners, raids, evict, move. NOT delete/wipe.
	["ROLE_ID_HERE_HIDEOUT"] = {
		name = "Hideout Team",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"players.spectate", -- watch a player, and the Spectate button on a map pin
			"scenes.manage",   -- place and delete /scene markers
			"manage.hideouts",
		},
	},

	-- Runs gang camps: safe, tax, stash, members, leader. NOT delete/wipe/repo.
	["ROLE_ID_HERE_CAMP"] = {
		name = "Camp Team",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"players.spectate", -- watch a player, and the Spectate button on a map pin
			"scenes.manage",   -- place and delete /scene markers
			"camps.manage",
		},
	},

	-- Runs player shops: rename, blip, move, slots. NOT delete or repo.
	["ROLE_ID_HERE_SHOPS"] = {
		name = "Shop Team",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"players.spectate", -- watch a player, and the Spectate button on a map pin
			"scenes.manage",   -- place and delete /scene markers
			"manage.stores",
		},
	},

	["ROLE_ID_HERE_SUPPORT"] = {
		name = "Support",
		perms = {
			"menu.open",
			"map.view",        -- Live Map page
			"players.spectate", -- watch a player, and the Spectate button on a map pin
			"scenes.manage",   -- place and delete /scene markers
			"players.view",
			"players.heal",
			"players.revive",
		},
	},
}

-- FRIENDLY NAME -> INTERNAL KEY. Left: the name used in roles above (group.name).
-- Right: the action key the admin menu actually checks.
Config.DiscordPermissions.permissionGroups = {

	menu = {
		["open"]     = "open_menu",
		["actions"]  = "admin_actions_menu",
		["announce"] = "allow_announce",
	},

	security = {
		["panel"] = "anticheat_panel", -- see the Anti-Cheat tab and flag history
	},

	-- ITS OWN GROUP ON PURPOSE, like destroy below. "Clear spawned entities" on the
	-- Anti-Cheat tab deletes every script-spawned wagon, horse, ped and prop for everyone
	-- after a chat countdown, so "security.*" must not hand it out by wildcard.
	cleanup = {
		["world"] = "anticheat_cleanup",
	},

	-- /devgun only. Reads an entity's coords, hash, model and rotation and changes
	-- nothing, so it sits apart from devtools_menu (prop placer, zone creator).
	dev = {
		["laser"] = "dev_laser",
		-- Ped Menu, on the Dev Tools tab. "others" puts a ped on another player
		["pedmenu"]       = "ped_menu",
		["pedmenuothers"] = "ped_menu_others",
	},

	-- Stable Admin: another player's horses and wagons. Its OWN group on purpose -
	-- Moderator holds "dev.*", so putting this in dev would hand every
	-- moderator the power to transfer and delete other people's horses.
	stable = {
		["admin"] = "stable_admin",
	},

	-- The Live Map page. Its own key, separate from "spectate", so someone can be
	-- shown the map without also being allowed to spectate.
	-- Seeing the map is not the same as acting on it - the Go to / Bring /
	-- Spectate buttons on a player pin still need their own keys.
	map = {
		["view"] = "live_map",
	},

	players = {
		["view"]       = "check_player_inventory",
		-- read-only list vs the LIVE two-way panel. Separate on purpose: opening
		-- the real inventory means being able to take out of it.
		["openinv"]    = "open_player_inventory",
		["kick"]       = "kick_player",
		["ban"]        = "ban_player",
		["unban"]      = "unban_player",
		["banoffline"] = "ban_offline",
		["whitelist"]  = "whitelist_player",
		["freeze"]     = "freeze_player",
		["spectate"]   = "spectate",
		["heal"]       = "heal_player",
		["revive"]     = "revive_player",
		["respawn"]    = "respawn_player",
		["clearinv"]   = "clear_inventory",
		["clearcash"]  = "clear_currency",
		-- give_ is NOT a key anything checks. server.lua builds the key as "give_" .. action
		["give"]       = "give_item",
		["giveitem"]   = "give_item",
		["giveweapon"] = "give_weapon",
		["givemoney"]  = "give_moneygold",
		["givehorse"]  = "give_horse",
		["givewagon"]  = "give_wagon",
		["setgroup"]   = "set_group",
		["setjob"]     = "set_job",
		["godmode"]    = "godmode",
		["ammo"]       = "infinite_ammo",
		["cores"]      = "golden_cores",
	},

	-- SERVER BANS tab. Separate from players.ban / players.unban, which are the
	-- /ban and /unban commands. Without this mapping, with Discord permissions on,
	-- only an "all" role could reach the tab.
	bans = {
		["view"]  = "server_bans_view", -- open the tab and search it
		["issue"] = "server_ban",       -- place a ban from the tab
	},

	-- ITS OWN GROUP ON PURPOSE, like destroy below. Lifting a ban undoes another
	-- staff member's decision, so a "bans.*" wildcard must never hand it out.
	unban = {
		["lift"] = "server_unban",
	},

	teleport = {
		["toplayer"]  = "tp_to_player",
		["coords"]    = "tp_to_coords",
		["waypoint"]  = "tp_to_waypoint",
		["bring"]     = "bring_player",
		["sendback"]  = "send_player_back",
		["playerback"] = "tp_player_back",
		["noclip"]    = "noclip",
		["self"]      = "tp_to_waypoint",
	},

	self = {
		["heal"]   = "selfheal",
		["revive"] = "selfrevive",
	},

	spawn = {
		["horse"] = "spawn_horse",
		["wagon"] = "spawn_wagon",
	},

	-- the domain panels (housing, society, ranch, stores, crafting, gangs, perks)
	manage = {
		["housing"]  = "manage_housing",
		["society"]  = "manage_society",
		["ranch"]    = "manage_ranch",
		["stores"]   = "manage_stores",
		["crafting"] = "manage_crafting",
		["gangs"]    = "manage_gangs",
		["perks"]    = "manage_perks",
		["bank"]     = "manage_bank",
		["hideouts"] = "manage_hideouts",
		["curses"]   = "manage_curses",    -- pup_shaman: the Curses page
		["farms"]    = "manage_farms",     -- pup_homestead: the Farms page
	},

	-- ITS OWN GROUP ON PURPOSE, like destroy below. pup_staffdesk's /parcel creates cash, items
	-- and weapons, and /rename changes names, so "manage.*" must not hand it out by wildcard.
	desk = {
		["manage"] = "manage_staffdesk",
	},

	-- ITS OWN GROUP ON PURPOSE, like destroy below.
	-- A camp holds its members' safe, tax pot and whole stash, so "manage.*" must not
	-- hand it out by wildcard. Name "camps.manage" explicitly, or hold "all".
	camps = {
		["manage"] = "manage_camps",
	},

	-- Seasonal events (pup-events). Forcing one on changes the world for everyone
	-- and the time control moves the whole server's clock, so this is its own key.
	events = {
		["manage"] = "manage_events",
	},

	-- Mayoral elections (pup-voting). One key covers the lot, deleting included.
	elections = {
		["manage"] = "manage_elections",
	},

	-- /scene text markers are a permanent map change too. Its own key on purpose:
	-- riding on menu.open would let every staff role write on the map. Normally
	-- scenes are the newspaper job's job; grant this only to staff who should be able to place and clear scenes regardless of job. "all" covers it.
	scenes = {
		["manage"] = "manage_scenes",
	},

	-- world props are permanent map changes, so placing gets its own key rather than
	-- riding on get_coords. Deleting lives in destroy below.
	props = {
		["place"] = "place_world_props",
		["list"]  = "list_world_props",
	},

	-- ITS OWN GROUP ON PURPOSE.
	-- "manage.*" expands to every key in the manage group, so a destructive key
	-- living there would be handed out by the wildcard. These have to be named
	-- one at a time, or held through "all".
	destroy = {
		["housing"] = "delete_housing",
		["society"] = "delete_society",
		["gang"]    = "delete_gang",     -- disband: removes the gang from every member
		["hideout"] = "delete_hideout",  -- delete, and the stash/ledger wipes
		["camp"]    = "delete_camp",     -- disband a camp, and the stash/safe wipes
		["money"]   = "wipe_money",      -- bank balances and cash, gone
		["prop"]    = "delete_world_prop", -- removes a placed prop from the world for good
		["gangpoints"] = "reset_gang_points", -- season reset: every gang back to level 1
		["character"]  = "delete_character",  -- wipes a character row: money, job, everything
		["item"]       = "delete_item",       -- drops an items row, orphaning every copy players hold
		["store"]      = "delete_store",      -- delete or repossess a player-owned shop
		["ranch"]      = "delete_ranch",      -- delete, move, or change the owner of a ranch
		["consumable"] = "delete_consumable", -- removes a smoke / consumable definition
	},

	troll = {
		["kill"]      = "troll_kill_player",
		["lightning"] = "troll_lightning_strike",
		["fire"]      = "troll_set_player_on_fire",
		["heaven"]    = "troll_tp_to_heaven",
		["ragdoll"]   = "troll_ragdoll_player",
		["handcuff"]  = "troll_handcuff_player",
		["invisible"] = "troll_invisible",
		["stamina"]   = "troll_drain_player_stam",
		["temp"]      = "troll_temp_high_player",
	},
}
