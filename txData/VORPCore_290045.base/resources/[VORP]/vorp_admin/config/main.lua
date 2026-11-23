-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_admin | main settings
-- Menu, keys, integrations and the smaller feature blocks. Permissions, Discord roles,
-- anti-cheat and the spawn guard each have their own file in this folder.

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug      = false,            -- dev mode: skips the normal staff lookup and prints a warning. Leave false on a live server
    -- language table from languages/translation.lua:
    -- English | Portuguese_PT | Portuguese_BR | French | German | Spanish
    language   = "English",
    panelTitle = "Dusk Till Dawn", -- title at the top of the web admin panel. "" = the sv_projectName convar
}

-- Prompt and control keys. Change the hash only.
Config.Keys = {
    openMenu        = 0x3C3DD371, -- PGDOWN, opens the menu
    noclipUp        = 0xF84FA74F, -- Q
    noclipDown      = 0x07CE1E61, -- Z
    noclipForward   = 0x8FD015D8, -- W
    noclipBackward  = 0xD27782E3, -- S
    noclipSpeed     = 0x8FFC75D6, -- L-Shift, cycles through Config.NoClip.speeds
    noclipCancel    = 0x4AF4D473, -- Delete, switches noclip off
}

-------------------------------------------------------------------------------
-- INTEGRATIONS  (other resources this one can talk to)
-------------------------------------------------------------------------------
Config.Integrations = {
    -- qw reports: true = the Report button is left to qw_reports instead of the built-in report box
    qwReports     = { enabled = false },
    -- vorp_stables: true = given horses/wagons go into the `stables` table, false = `horses` / `wagons`
    vorpStables   = { enabled = false },
    -- vorp_character: the ped menu applies a ped through its reload command, which carries the
    -- Custom model override. Must match vorp_character/config/main.lua Config.Reload.command.
    vorpCharacter = { reloadCommand = "rc" },
}

-------------------------------------------------------------------------------
-- MENU  (how staff open the admin menu)
-------------------------------------------------------------------------------
Config.Menu = {
    commandEnabled = true,         -- register the chat command below
    command        = "adminMenu",  -- chat command that opens the menu
    openWhenDead   = true,         -- staff may open the menu while dead. WARNING: they can revive themselves with it
}

-------------------------------------------------------------------------------
-- HEAL  (what "heal" restores on top of health)
-------------------------------------------------------------------------------
Config.Heal = {
    -- runs on the healed player's client after a self heal
    restoreMetabolism = function()
        TriggerEvent("vorpmetabolism:changeValue", "Thirst", 1000)
        TriggerEvent("vorpmetabolism:changeValue", "Hunger", 1000)
        -- TriggerEvent('fred_meta:consume', 100, 100, 0, 0, 0.0, 0.0, 0.0, 0.0, 0.0) -- Fred Metabolism
    end,
}

-------------------------------------------------------------------------------
-- NO CLIP  (keys are in Config.Keys)
-------------------------------------------------------------------------------
Config.NoClip = {
    forwardMultiplier  = 0.2, -- forward/backward movement per tick, multiplied by the current speed
    verticalMultiplier = 0.1, -- up/down movement per tick, multiplied by the current speed

    -- Speed steps, cycled with Config.Keys.noclipSpeed. The first entry is the starting speed.
    --   label = text shown on the prompt, speed = movement multiplier
    --   example: { label = 'Normal', speed = 2 },
    speeds = {
        { label = 'Very Slow', speed = 0 },
        { label = 'Slow',      speed = 0.5 },
        { label = 'Normal',    speed = 2 },
        { label = 'Fast',      speed = 10 },
        { label = 'Very Fast', speed = 15 },
        { label = 'Max',       speed = 29 },
    },
}

-------------------------------------------------------------------------------
-- SCOREBOARD  (the players' own menu: report, request staff, player list)
-------------------------------------------------------------------------------
Config.Scoreboard = {
    usersMenu                   = false,     -- give non-staff the users menu at all
    playerListEnabled           = true,      -- show the player list in that menu
    showInfo                    = "showAll", -- what the list shows: showAll | showJob | showGroup | showID
    requestStaffCooldownSeconds = 60,        -- wait before a player may request staff again
}

-------------------------------------------------------------------------------
-- GUARMA  (Teleport to Guarma and back)
-------------------------------------------------------------------------------
Config.Guarma = {
    coords         = { x = 1269.724, y = -6855.1577, z = 43.168 }, -- where "travel to Guarma" lands you
    mainlandCoords = { x = 2717.04, y = -1435.52, z = 46.22 },     -- fallback for the trip back when no previous spot is known
    -- map zone hashes that count as Guarma. Only change if you know what you are doing.
    areaHashes     = {
        [joaat("GuarmaD")] = true,
        [joaat("Guarma")]  = true,
    },
}

-------------------------------------------------------------------------------
-- LIVE MAP  (web panel)
-------------------------------------------------------------------------------
Config.LiveMap = {
    playerBlipSprite = "blip_player", -- blip used by the "Player Blips" overlay on the Tools page
}

-------------------------------------------------------------------------------
-- LOGS  (Discord embed style; set the webhook URLs in `server/config.lua`)
-------------------------------------------------------------------------------
Config.Logs = {
    embedColor     = 16711680, -- embed colour as a decimal number (16711680 = red)
    embedName      = "VORP",   -- name shown on the embed and as the webhook username
    -- No images on the embeds. Blank here AND blank in vorp_core's config means the icon keys
    -- are left out of the payload entirely.
    logo           = "",
    footerLogo     = "",
    avatar         = "",
    printToConsole = false,    -- print every logged action to the server console as well
}
