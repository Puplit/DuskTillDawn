-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_admin | group permissions
-- Which VORP group may do what. Used as-is when Discord permissions are off, and as the
-- fallback when they are on (see config/discord.lua).

-- Action sets. Every group in Config.Permissions.groups points at one of these, so the
-- same list does not have to be written out twice.
--   all = true            every action
--   <action key> = true   that one action (the keys the menu and panel check)
-- Example: lite = { open_menu = true, players_list_menu = true, spectate = true },
local actions <const> = {
    high = {
        all = true, -- allow all actions
    },

    medium = {
        --ADMIN ACTIONS
        tp_to_player = true,           -- allow to teleport to player
        tp_player_back = true,         -- allow to teleport player back
        bring_player = true,           -- allow to bring player to you
        send_player_back = true,       -- allow to send player back after teleported to you
        freeze_player = true,          -- allow to freeze player
        kick_player = true,            -- allow to kick player
        ban_player = true,             -- allow to ban player
        unban_player = true,           -- allow to use unban player
        ban_offline = true,            -- allow to use ban offline
        -- SERVER BANS (the panel's Bans tab) is gated separately from the three
        -- above, so banning there can be granted without the /ban commands.
        -- Lifting is NOT here: a ban undone is another staff member's call reversed,
        -- so server_unban is admin only, which gets it through actions.high.
        server_bans_view = true,       -- allow to open Server Bans and search it
        server_ban = true,             -- allow to issue a ban from Server Bans
        -- /devgun. Reads an entity's coords/model and changes nothing, so it is NOT
        -- devtools_menu, which also carries the prop placer and zone creator.
        dev_laser = true,
        respawn_player = true,         -- allow to respawn player
        give_item = true,              -- allow to give item to player
        give_horse = true,             -- allow to give horse to player
        give_wagon = true,             -- allow to give wagon to player
        give_weapon = true,            -- allow to give weapon to player
        give_moneygold = true,         -- allow to give gold or money to player
        clear_inventory = true,        -- allow to clear inventory of player
        check_player_inventory = true, -- allow to check player inventory (read-only list)
        open_player_inventory = true,  -- allow to OPEN their live inventory (can take items)
        clear_currency = true,         -- allow to clear currency of player
        set_group = true,              -- allow to set group to player
        set_job = true,                -- allow to set job to player
        whitelist_player = true,       -- allow to whitelist player
        revive_player = true,          -- allow to revive player
        heal_player = true,            -- allow to heal player
        get_coords = true,             -- allow to use get coords
        delete_horse = true,           -- allow to use delete horse
        delete_wagon = true,           -- allow to use delete wagon
        delete_wagons_radius = true,   -- allow to use delete wagons radius
        allow_announce = true,         -- allow to use announce
        godmode = true,                -- allow to use godmode
        infinite_ammo = true,          -- allow to use infinite ammo
        noclip = true,                 -- allow to use noclip
        invisibility = true,           -- allow to use invisibility
        spawn_horse = true,            -- allow to use spawn horse
        spawn_wagon = true,            -- allow to use spawn wagon
        golden_cores = true,           -- allow to use golden cores
        spectate = true,               -- allow to use spectate
        selfheal = true,               -- allow to use self heal
        selfrevive = true,             -- allow to use self revive
        tp_to_waypoint = true,         -- allow to use tp to waypoint
        tp_to_coords = true,           -- allow to use tp to coords
        teleport_to_guarma = true,     -- allow to use teleport to guarma

        -- troll menu actions
        troll_kill_player = true,        -- allow to use troll kill player
        troll_invisible = true,          -- allow to use troll invisible
        troll_lightning_strike = true,   -- allow to use troll lightning strike
        troll_set_player_on_fire = true, -- allow to use troll set player on fire
        troll_tp_to_heaven = true,       -- allow to use troll tp to heaven
        troll_ragdoll_player = true,     -- allow to use troll ragdoll player
        troll_drain_player_stam = true,  -- allow to use troll drain player stam
        troll_handcuff_player = true,    -- allow to use troll handcuff player
        troll_temp_high_player = true,   -- allow to use troll temp high player


        -- MENU ACTIONS
        open_menu = true,             -- allow to use open menu
        admin_menu = true,            -- allow to use admin menu
        boosters_menu = true,         -- allow to use boosters menu
        teleport_menu = true,         -- allow to use teleport menu
        database_menu = true,         -- allow to use database menu
        devtools_menu = true,         -- allow to use devtools menu
        manage_doorlocks = true,      -- allow to create, edit and delete door locks
        anticheat_panel = true,       -- allow to see the Anti-Cheat tab (read-only flag history)
        admin_actions_menu = true,    -- allow to use admin actions menu
        offline_actions_menu = true,  -- allow to use offline actions menu
        players_list_menu = true,     -- allow to use players list menu
        view_reports_menu = true,     -- allow to use view reports menu
        open_database_menu = true,    -- allow to use open database menu
        give_items_menu = true,       -- allow to use give items menu
        remove_items_menu = true,     -- allow to use remove items menu
        simple_actions_menu = true,   -- allow to use simple actions menu
        advanced_actions_menu = true, -- allow to use advanced actions menu
        troll_actions_menu = true,    -- allow to use troll actions menu
        players_list_submenu = true,  -- allow to use players list submenu
        ped_menu = true,              -- allow to open the ped menu and change your own ped
        -- NOT granted to medium: putting a ped on someone else is an admin call.
        -- admin gets it through actions.high (all = true).
        -- ped_menu_others
        -- NOT granted to medium either: transferring or deleting someone's horse
        -- or wagon is destructive and irreversible.
        -- stable_admin
        -- NOT granted to medium: the Weather tab changes time and weather for
        -- every player at once. admin gets it through actions.high (all = true),
        -- and weathersync still gates the events themselves on the
        -- command.weatherui ace in server.cfg.
        -- manage_weather
        -- NOT granted to medium: the Anti-Cheat tab's "Clear spawned entities" deletes
        -- every script-spawned wagon, horse, ped and prop for every player after a
        -- chat countdown. admin gets it through actions.high (all = true).
        -- anticheat_cleanup

    },
    -- create more here

}

-------------------------------------------------------------------------------
-- PERMISSIONS
-------------------------------------------------------------------------------
Config.Permissions = {
    useCharacterGroup = false, -- true = read staff group from the character, false = from the user (account)

    -- Set Group writes the new group to these. Both true = both get it.
    setGroup = {
        character = false, -- write to the character group
        user      = true,  -- write to the user group
    },

    -- VORP group -> action set. Any group listed here counts as staff.
    -- WEB PANEL keys are checked the same way, for example
    --   yourgroup = { actions = { open_menu = true, manage_housing = true } }
    -- manage_housing = Housing page (list/edit/seize/delete/transfer houses), manage_society = Society page
    groups = {
        admin = {
            actions = actions.high,
        },
        moderator = {
            actions = actions.medium,
        },
        -- create more here
    },
}
