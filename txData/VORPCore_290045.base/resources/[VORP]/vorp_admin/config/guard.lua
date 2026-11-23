-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_admin | spawn guard
-- Server side entity guard: blocked models, entity spam budgets, explosion spam and the
-- /cleanarea and /cleanowner sweep. Server only. Set its Discord webhook in `server/config.lua`.

-------------------------------------------------------------------------------
-- SPAWN GUARD
-------------------------------------------------------------------------------
Config.SpawnGuard = {
	enabled          = true,
	-- where blockedModels are refused:
	--   'towns'      only inside the town radii below (predators in Valentine)
	--   'everywhere' anywhere a client tries to create one
	mode             = 'towns',
	bypassPermission = 'admin_actions_menu', -- staff holding this action key can still spawn blocked models
	logToConsole     = false, -- off: blocks still reach the panel and the webhook, they just stop spamming console
	flagBlocks       = false, -- write an animal block into the Anti-Cheat panel (boats on alwaysBlocked are always written)
}

-- Model hashes that clients have no business creating. Obeys `mode` above.
--   [`model_name`] = 'Label shown in logs'
-- Example: [`A_C_Bear_01`] = 'Bear',
Config.SpawnGuard.blockedModels = {
	[`A_C_Panther_01`]           = 'Panther',
	[`A_C_PantherLegendary_01`]  = 'Legendary Panther',
	[`A_C_Bear_01`]              = 'Bear',
	[`A_C_BearBlack_01`]         = 'Black Bear',
	[`A_C_BearGrizzly_01`]       = 'Grizzly',
	[`A_C_Wolf_01`]              = 'Wolf',
	[`A_C_Wolf_Medium_01`]       = 'Wolf (medium)',
	[`A_C_Wolf_Large_01`]        = 'Wolf (large)',
	[`A_C_Wolf_Small_01`]        = 'Wolf (small)',
	[`A_C_Cougar_01`]            = 'Cougar',
	[`A_C_LionMangy_01`]         = 'Mangy Lion',
	[`re_savageaftermath_males_01`] = 'Savage',
	[`A_C_Alligator_01`]         = 'Alligator',
	[`A_C_Alligator_02`]         = 'Alligator',
	[`A_C_Alligator_03`]         = 'Alligator',
	[`A_C_AlligatorGhost_01`]    = 'Ghost Alligator',
	[`A_C_Boar_01`]              = 'Boar',
	[`A_C_BoarLegendary_01`]     = 'Legendary Boar',
	[`A_C_Buffalo_01`]           = 'Buffalo',
	[`A_C_Buffalo_Tatanka_01`]   = 'Tatanka Buffalo',
	[`A_C_BuffaloWhite_01`]      = 'White Buffalo',
	[`A_C_Bull_01`]              = 'Bull',
	[`A_C_Cow`]                  = 'Cow',
	[`A_C_Coyote_01`]            = 'Coyote',
	[`A_C_CoyoteLegendary_01`]   = 'Legendary Coyote',
	[`A_C_Elk_01`]               = 'Elk',
	[`A_C_ElkLegendary_01`]      = 'Legendary Elk',
	[`A_C_Moose_01`]             = 'Moose',
	[`A_C_MooseLegendary_01`]    = 'Legendary Moose',
	[`A_C_Ox_01`]                = 'Ox',
	[`A_C_Panther_Legendary_01`] = 'Legendary Panther',
	[`A_C_Pig_01`]               = 'Pig',
	[`A_C_Snake_01`]             = 'Snake',
	[`A_C_SnakeFerDeLance_01`]   = 'Fer-de-Lance',
	[`A_C_Wolf_Legendary_01`]    = 'Legendary Wolf',
}

-- Blocked EVERYWHERE whatever `mode` says, and deleted if one ever slips through. Nothing on
-- this server creates these: a tug boat or a river steamer is a cheat wherever it lands.
-- Small craft (canoe, pirogue, rowboat, skiff, rafts) are deliberately NOT here.
-- Same format as blockedModels.
Config.SpawnGuard.alwaysBlocked = {
	[`tugboat`]            = 'Tug Boat',
	[`boatsteam02x`]       = 'Steamboat',
	[`riverboat02x`]       = 'Riverboat',
	[`riverboatCasino01x`] = 'Casino Riverboat',
	[`keelboat`]           = 'Keelboat',
	[`smuggler02`]         = 'Smuggler Boat',
	[`turbineboat`]        = 'Turbine Boat',
	[`skifflrg`]           = 'Large Skiff',
	[`horseboat`]          = 'Horse Boat',
	[`ship_guama02`]       = 'Guarma Ship',
	[`ship_nbdguama`]      = 'Guarma Ship',
}

-- Town zones used by 'towns' mode. 2D circles: name, centre x / y, radius in metres.
-- Example: { name = 'Valentine', x = -302.077, y = 792.273, radius = 70.0 },
Config.SpawnGuard.towns = {
	{ name = 'Valentine',   x =  -302.077, y =   792.273, radius =  70.0 },
	{ name = 'Rhodes',      x =  1335.757, y = -1309.353, radius =  70.0 },
	{ name = 'Blackwater',  x =  -800.695, y = -1298.853, radius = 172.0 },
	{ name = 'Tumbleweed',  x = -5512.785, y = -2936.821, radius = 100.0 },
	{ name = 'Armadillo',   x = -3682.661, y = -2937.091, radius = 200.0 },
	{ name = 'Saint Denis', x =  2653.621, y = -1268.223, radius = 260.0 },
	{ name = 'Annesburg',   x =  2936.667, y =  1343.206, radius = 120.0 },
	{ name = 'Van Horn',    x =  2959.725, y =   526.643, radius = 100.0 },
	{ name = 'Strawberry',  x = -1792.522, y =  -400.850, radius = 100.0 },
}

-------------------------------------------------------------------------------
-- SPAM GUARD  (rate, not identity: networked entities per player per window)
-------------------------------------------------------------------------------
Config.SpawnGuard.spam = {
	enabled = true,
	mode    = 'towns', -- fallback for kinds not in `modes`: 'off' log only | 'towns' cancel in town | 'everywhere'

	-- Per kind. A crash flood does not need a town, so objects and vehicles are cancelled
	-- everywhere. Peds stay town-scoped: an honest client takes ownership of the ambient crowd,
	-- and cancelling that in the wilderness breaks streaming.
	modes = {
		ped     = 'towns',
		vehicle = 'everywhere',
		object  = 'everywhere',
	},

	-- Cancelling each entity does not stop the sender, so a player who stays over budget is dropped.
	kick = {
		enabled      = true,
		afterWindows = 3, -- consecutive over-budget windows before the drop
		message      = 'Kicked for entity spam. Open a ticket if this was a mistake.',
	},

	windowSeconds    = 10,  -- rolling window
	-- Peds are ambient: streaming into a busy town counts every one of the crowd. Keep this well
	-- clear of normal streaming. /spawnpeak prints the real high-water mark to set it from.
	pedPerWindow     = 150, -- networked peds per player per window
	objectPerWindow  = 25,  -- networked objects per player per window
	vehiclePerWindow = 6,   -- networked vehicles (boats, wagons, carriages) per player per window
	recordFlag       = true, -- one Anti-Cheat flag per player per window, however far over they go
}

-------------------------------------------------------------------------------
-- CLEANUP SWEEP  (/cleanarea and /cleanowner, for what is already on the ground)
-------------------------------------------------------------------------------
Config.SpawnGuard.cleanup = {
	permission       = 'admin_actions_menu', -- action key needed to run the commands
	defaultRadius    = 60.0,  -- metres, /cleanarea with no radius
	maxRadius        = 500.0, -- metres, largest radius /cleanarea accepts
	-- Peds and vehicles must be asked for by name on the command; a blind sweep would take
	-- horses, wagons, pets and job peds with it. Anything carrying one of these state keys is
	-- left alone either way.
	protectStateKeys = { 'pup_stable_horseID', 'pup_stable_wagonID' },
}

-------------------------------------------------------------------------------
-- EXPLOSIONS  (cancelled server side before anyone else is told about them)
-------------------------------------------------------------------------------
-- Dynamite and fire bottles are legitimate, so this is a rate, not a ban: a robbery uses a
-- few, a griefer uses dozens. Staff with the bypass are exempt.
Config.SpawnGuard.explosion = {
	enabled       = true,
	windowSeconds = 10, -- rolling window
	perWindow     = 5,  -- explosions per player per window before the rest are dropped
}
