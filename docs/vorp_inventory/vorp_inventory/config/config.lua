---@class vorp_inventory_config
CONFIG                     = CONFIG or {}

CONFIG.LANGUAGE            = "English"

CONFIG.DEV_MODE            = false   -- If your server is live set this to false

CONFIG.PUSH_TO_TALK        = true    -- enable PTT while inventory is open

CONFIG.INV_ORDER           = "items" -- "items" or "weapons" what displays at the top of the inventory

CONFIG.WALK_WHILE_INV_OPEN = true    -- If true, the player can walk while the inventory is open as long they hold W key

CONFIG.SHOW_PLAYER_NAME    = false   -- When giving an item, show the character name of nearby players instead of their player ID
-- "Show Item": holding an item up so nearby players see what it is
CONFIG.SHOW_ITEM           = {
    RANGE     = 8.0, -- how far away the card is still drawn
    FADE_FROM = 5.5, -- starts dimming past this distance, must be under RANGE
    SECONDS   = 8.0, -- how long a card stays up
    COOLDOWN  = 3,   -- seconds between shows, per player
}


-- WEAPON COMPONENT TRACING. Two separate switches: this file is a SHARED script, so
-- one flag for both would put client lines in every player's F8 while chasing a server bug.
-- [compsdb] in the SERVER console: every write to loadout.comps, from either writer
CONFIG.TRACE_COMPONENTS                  = true
-- [comps] in each PLAYER'S F8: client-side component cache. Server-side work does
-- not need this, and it is seen by everyone online - leave it off unless the client
-- cache itself is in doubt.
CONFIG.TRACE_COMPONENTS_CLIENT           = false
-- Per-component apply rows on top of the summary (12+ more lines per run)
CONFIG.TRACE_COMPONENTS_VERBOSE          = false
-- WEAPON CONFIGURATION
CONFIG.REMOVE_LASSO                      = true -- If true, the lasso will be removed when player hogties an NPC, only works if MANUAL_WEAPON_RELOAD is true

CONFIG.DISABLE_HIP_FIRE                  = false -- If true, DISABLES hip fire and players must aim to shoot

-- the "Drop advanced" row in every item / weapon / money context menu
CONFIG.ENABLE_ADVANCED_DROP              = false
CONFIG.RELOAD_WAIT                       = 2000 -- after reload must wait this miliseconds

CONFIG.USE_RELOAD_SPEEDS                 = true -- If true, the reload speeds will be added to the weapons and you can change them in SHARED_DATA.WEAPONS

-- IF YOU DISABLE THIS A LOT OF FEATURES WILL BE DISABLED
CONFIG.MANUAL_WEAPON_RELOAD              = false -- If true, the player will have to manually reload their weapons, and other features will be added too like unload ammo from weapons etc.

CONFIG.USE_LANTERN_ON_BELT               = true  -- If true then lanterns will be put on belt

CONFIG.DUAL_WIELD                        = true  -- If true dual wielding will be allowed.

CONFIG.DUAL_WIELD_HOLSTER_NEEDED         = false  -- If true, the player will need to have a left holster to dual wield, other wise they cant equipp 2 guns to use dual wield (any clothing store will sell one)

-- put the off-hand holster ON the ped when dual wielding
CONFIG.DUAL_WIELD_ADD_HOLSTER            = false
CONFIG.AUTO_EQUIP_USED_WEAPONS           = true  -- will add weapons to the weapon wheel if player left with them equipped when they rejoin only works if MANUAL_WEAPON_RELOAD is true

CONFIG.REMOVE_THROWABLE_WEAPONS          = true  -- If true, the throwable weapons will be removed when fired, and if picked up they get theweapon back again

CONFIG.ENABLE_PETROL_CAN                 = false -- If true, the petrol can will be enabled and will be usable the amo is also saved

CONFIG.DISABLE_WEAPON_WHELL_ITEMS        = false -- this wheel contains the fishing rod etc, if you set this to true it will hide that wheel and you must use these from hot bar.

CONFIG.DISABLE_WEAPON_WHEEL_WEAPONS      = false -- if true, the weapon wheel will not show weapons, only items and you must use these from hot bar. and set ammo in inventory actions dropdown

-- HERE WE DECIDE IF PLAYERS CAN EQUIP MORE THAN ONE WEAPON TYPE FOR EXAMPLE CAN EQUIPP 2 LONG WEAPONS? OR 2 SHORT WEAPONS?
--  IF YOU WANT TO DISABLE THIS JUST REMOVE IT FROM THE WEAPONS.LUA FILE the variables LongWeapon and ShortWeapon
CONFIG.EQUIP_WEAPONS                     = {
	LONG_WEAPONS = 2, -- HOW MANY THEY CAN EQUIP AT THE SAME TIME IF ONE THEY CAN ONLY EQUIP ONE LONG WEAPON
	SHORT_WEAPONS = 2, -- HOW MANY THEY CAN EQUIP AT THE SAME TIME IF ONE THEY CAN ONLY EQUIP ONE SHORT WEAPON
}
-- -------------------------
-- if you have a weapons script you might have to modify it to work with
-- vorp_inventory, or disable this feature
CONFIG.USE_WEAPON_COMPONENTS             = false
-- the drag-and-drop "Mods" panel inside the satchel
CONFIG.ENABLE_WEAPON_ATTACHMENTS_UI      = false

-- WEAPON CONDITION AND REPAIR: both off. To turn them on, set BOTH of these to true
-- (see "Weapon condition and repair" in README.md):
--   USE_WEAPON_DEGRADATION      guns wear, get dirty and rust, and the wear is saved
--   RESTORE_WEAPON_DEGRADATION  the repair kit, Clean and the gunsmith repair can fix a gun
-- While USE_WEAPON_DEGRADATION is false, weapons never degrade, stored wear is never
-- applied to the gun, nothing saves, and repair/clean refuse instead of charging.
-- Stored values stay in `loadout` untouched, so turning it back on restores every
-- weapon to the condition it had.
CONFIG.USE_WEAPON_DEGRADATION            = false

CONFIG.DISABLE_WEAPON_FIRE_WHEN_DEGRADED = false                  -- If true, the weapon will be disabled when degraded and damaged

CONFIG.RESTORE_WEAPON_DEGRADATION        = false                  -- if true degradation will be restored when cleaning it, if false it means weapon dont last forever.

-- the item RDR2's native inspect -> clean interaction consumes
CONFIG.CLEAN_WEAPON_ITEM                 = "repair_kit"

CONFIG.TIME_BETWEEN_ITEM_USE             = 2000                   -- ms

CONFIG.OPEN_INVENTORY_KEY                = `INPUT_QUICK_USE_ITEM` -- key to open inventory: I
-- REBINDABLE KEYS
CONFIG.KEYBINDS = {
	ENABLE = true,


	OPEN_INVENTORY = "I",     -- open the inventory
	HOTBAR_TOGGLE  = "X",     -- show/hide the hotbar
	HOTBAR_HOLD    = "LMENU", -- hold to use the hotbar

	-- Hold HOTBAR_HOLD then press one of these. Set REQUIRE_HOLD = false
	-- if the slots should fire on their own.
	REQUIRE_HOLD = true,
	HOTBAR_SLOTS = { "1", "2", "3", "4", "5" },
}
CONFIG.INVENTORY_UI = {

	WEIGHT_MEASURE = "", -- pup: no label - every item/weapon weighs a flat 1 (unit count, 200-slot system), so "kg" would be misleading

	BACKGROUND_FILTER = {
		ENABLE = true,     -- If true, the background filter will appear in the inventory
		FILTER = "OJDominoBlur", -- The filter to use for the background
		STRENGTH = 0.5,    -- The strength of the filter
	},

	SEARCH_BAR = {
		ENABLE = true, -- If true, the search bar will appear in the inventory
		FOCUS = false, -- If true, the search bar will automatically focus when the inventory is opened
	},

	-- "border" the border has a color. / "background" the background has a color / "background-img"   uses a slot image with colors and border "none"  no colors ( the label will still have color on toll tip)
	ITEM_RARITY_SLOT_STYLE = "background-img",
	-- tooltip "hover" = under the hovered slot (default). "dock" = fixed to the right of the main grid with secondary/custom storage open
	TOOLTIP_PLACEMENT = "hover",

	MAIN_INVENTORY_FIXED_SLOT_COUNT = 200, -- how many slots a player can have.this will be added per character in the future. to allow skills to be used to increase it.

	ADD_GOLD_ITEM = false,             -- If true, the gold item will be added to the inventory to represent the gold/give gold/drop gold

	ADD_ROLL_ITEM = false,             -- If true, the roll item will be added to the inventory to represent the roll/give roll/drop roll

	HAND_CRAFT_BUTTON = false,         -- enables hand crafting button in inventory

	SADDLE_BUTTON = false,             -- enables saddle inventory button

	SORT_BUTTON = false,               -- enables sort inventory button

}

--CAN ONLY USE HOTBAR IF PRESSING ALT AND HOLD so you can keep using the 1 2 3 4 5 keys normally while not holding ALT
CONFIG.HOTBAR       = {
	ENABLE = true,
	SHOW_WHEN_HOLD = true,                           -- will show hotbar when holding ALT
	EDIT_COMMAND = "hotbarpos",                      -- command to edit the hotbar position
	TOGGLE_KEY = `INPUT_EMOTE_GREET`,                -- X -- Hotbar: show/hide
	ALLOW = "all",                                   -- "all" is items and weapons , weapons only is "weapons" , "items" only is items
	HOLD_KEY = `INPUT_SELECT_RADAR_MODE`,            -- key to hold to show hotbar (ALT) and use hotbar, cant use hotbar if you are not pressing and holding this key
	SLOT_KEYS = {
		[1] = `INPUT_SELECT_QUICKSELECT_SIDEARMS_LEFT`, -- 1
		[2] = `INPUT_SELECT_QUICKSELECT_DUALWIELD`,  -- 2
		[3] = `INPUT_SELECT_QUICKSELECT_SIDEARMS_RIGHT`, -- 3
		[4] = `INPUT_SELECT_QUICKSELECT_UNARMED`,    -- 4
		[5] = `INPUT_SELECT_QUICKSELECT_MELEE_NO_UNARMED`, -- 5
	},
	HOSTER_WEAPONS_ON_UNEQUIP = true,                -- If true when used from hotbar the weapon isnt removed is holstered. if false will unequipp the weapon normally
}

-- SOUND CONFIGURATION
CONFIG.SFX          = {
	OPEN_INVENTORY = {
		ENABLE = true,
		NAME = "SELECT",
		REF = "RDRO_Character_Creator_Sounds",
	},
	CLOSE_INVENTORY = {
		ENABLE = true,
		NAME = "SELECT",
		REF = "RDRO_Character_Creator_Sounds",
	},
	ITEM_HOVER = {
		ENABLE = true,
		NAME = "BACK",
		REF = "RDRO_Character_Creator_Sounds",
	},
	ITEM_DROP = {
		ENABLE = true,
		NAME = "show_info",
		REF = "Study_Sounds",
	},
	MONEY_DROP = {
		ENABLE = true,
		NAME = "show_info",
		REF = "Study_Sounds",
	},
	GOLD_DROP = {
		ENABLE = true,
		NAME = "show_info",
		REF = "Study_Sounds",
	},
	ROLL_DROP = {
		ENABLE = true,
		NAME = "show_info",
		REF = "Study_Sounds",
	},
	PICK_UP = {
		ENABLE = true,
		NAME = "CHECKPOINT_PERFECT",
		REF = "HUD_MINI_GAME_SOUNDSET",
	}
}


CONFIG.PICKUPS      = {
	USE_LIGHT = true,           -- If true, the pickup will have a light effect
	KEY = `INPUT_INTERACT_ANIMAL`, -- G key PROMPT PICKUP

	USE_WEAPON_MODELS = true,   -- If true, weapons will drop with a model other wise they default to the default_box prop

	DROP_MODELS = {
		default_box = "p_cottonbox01x", -- default when object is not found will always spawn this object for weapon or items
		money_bag = "p_moneybag02x", -- prop for the money pickup
		gold_bag = "s_pickup_goldbar01x", -- prop for the gold pickup
		rol_bag = "s_pickup_goldbar01x", -- prop for roll/currency pickups (reuse or override)
		-- add more here
	},

	ANIMATIONS = {
		DROP = {
			Item = {
				ENABLE = true,
				AnimDict = "amb_player@world_player_chore@bucket_put_down@male_a@base",
				AnimName = "base",
				Speed = 1.0,
				SpeedMultiplier = 8.0,
				Duration = -1,
				Flag = 1,
				ClearTaskTime = 1000
			},
			Weapon = {

				ENABLE = true,
				AnimDict = "amb_player@world_player_chore@box_put_down@male_a@base",
				AnimName = "base",
				Speed = 1.0,
				SpeedMultiplier = 8.0,
				Duration = -1,
				Flag = 1,
				ClearTaskTime = 1200
			},
			Money = {

				ENABLE = true,
				AnimDict = "mech_pickup@money@coins@table",
				AnimName = "2h_long_enter",
				Speed = 1.0,
				SpeedMultiplier = 8.0,
				Duration = -1,
				Flag = 1,
				ClearTaskTime = 500
			},
			Gold = {

				ENABLE = true,
				AnimDict = "mech_pickup@plant@gold_currant",
				AnimName = "enter_rf",
				Speed = 1.0,
				SpeedMultiplier = 8.0,
				Duration = -1,
				Flag = 1,
				ClearTaskTime = 1000
			},
			Roll = {

				ENABLE = true,
				AnimDict = "mech_pickup@plant@gold_currant",
				AnimName = "enter_rf",
				Speed = 1.0,
				SpeedMultiplier = 8.0,
				Duration = -1,
				Flag = 1,
				ClearTaskTime = 1000
			},
		},
		PICKUP = {
			ENABLE = true,
			AnimDict = "amb_work@world_human_box_pickup@1@male_a@stand_exit_withprop",
			AnimName = "exit_front",
			Speed = 1.0,
			SpeedMultiplier = 8.0,
			Duration = -1,
			Flag = 1,
			ClearTaskTime = 1200
		},
	},

	-- for dropped weapons , some will spawn standing so we modify their rotation
	WEAPON_ADJUSTMENTS = {
		WEAPON_MELEE_KNIFE = 90.0,
		WEAPON_BOW = 90.0,
		WEAPON_BOW_IMPROVED = 90.0,
		WEAPON_MELEE_KNIFE_RUSTIC = 90.0,
		WEAPON_MELEE_KNIFE_HORROR = 90.0,
		WEAPON_MELEE_KNIFE_CIVIL_WAR = 90.0,
		WEAPON_MELEE_KNIFE_JAWBONE = 90.0,
		WEAPON_MELEE_KNIFE_MINER = 90.0,
		WEAPON_MELEE_KNIFE_VAMPIRE = 90.0,
		WEAPON_MELEE_HATCHET = 90.0,
		WEAPON_MELEE_HATCHET_HUNTER = 90.0,
		WEAPON_MELEE_HATCHET_DOUBLE_BIT = 90.0,
		WEAPON_MELEE_MACHETE_COLLECTOR = 90.0,
		WEAPON_MELEE_MACHETE = 90.0,
		WEAPON_MELEE_CLEAVER = 90.0,
		WEAPON_MELEE_HAMMER = 90.0,
		WEAPON_FISHINGROD = 90.0,
		-- add here if more need to change rotation
	}
}
