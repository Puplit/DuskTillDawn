-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_character | main settings
-- Character select, character creator, face & body page, /rc and the in-world stores.
-- Big data lists live next to this file: spawns.lua, appearance.lua, overlays.lua,
-- components.lua and shops.lua. Player-facing text lives in shared/translation.lua.

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    language  = "English",  -- language table from shared/translation.lua (Translation.Langs[language])
    devMode   = false,      -- true: restart the resource without restarting the server, plus debug prints
    menuAlign = "top-left", -- position of the ink menus (creator, stores)
}

-- Prompt keys. Change the hashes only; `key2` is the second key of a pair.
Config.Keys = {
    prompt_create = { key = 0x9959A6F0 },                           -- [ C ]
    prompt_delete = { key = 0x3F4DC0EF },                           -- [ DELETE ]
    prompt_swap = { key = 0xA65EBAB4 },                             -- [ LEFT ARROW ]
    prompt_select = { key = 0xCEFD9220 },                           -- [ NUM ENTER ]
    prompt_choose_gender_M = { key = 0xA65EBAB4 },                  -- [ LEFT ARROW  ]
    prompt_choose_gender_F = { key = 0xDEB34313 },                  -- [ RIGHT ARROW ]
    prompt_select_gender = { key = 0xD9D0E1C0 },                    -- [ SPACE ]
    prompt_camera_ws = { key = 0x8FD015D8, key2 = 0xD27782E3 },     -- [ W ] and [ S ]
    prompt_camera_rotate = { key = 0x7065027D, key2 = 0xB4E465B4 }, -- [ A ] and [ D ]
    prompt_camera_zoom = { key = 0x8FFC75D6, key2 = 0xDB096B85 },   -- [ SHIFT ] and [ CTRL ]  creator camera zoom in / out
    prompt_zoom = { key = 0x8BDE7443, key2 = 0x62800C92 },          -- [ MOUSE SCROLL DOWN ] and [ MOUSE SCROLL UP ]
    prompt_Back = { key = 0x156F7119 }                              -- [ BACKSPACE ]
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
-- Nothing to configure: pup-ui is a hard dependency (fxmanifest) and is always used.
Config.Integrations = {}

-------------------------------------------------------------------------------
-- CHARACTER SELECT
-------------------------------------------------------------------------------
-- The select scenes themselves are in config/spawns.lua (Config.SpawnPosition).
Config.CharacterSelect = {
    showGold    = false, -- show gold next to money on the character cards
    allowDelete = false, -- let players delete their own characters
}

-------------------------------------------------------------------------------
-- RELOAD  (/rc)
-------------------------------------------------------------------------------
Config.Reload = {
    command         = "rc",  -- chat command that reloads the character (vorp_admin calls it by name too)
    wearsEverything = false, -- true: /rc puts back every saved garment; false: /hat, /mask... toggles survive a reload

    -- extra checks before /rc runs; return false to block it. Add checks from other scripts here.
    canRun          = function()
        -- callback ? statbebag ?
        return true -- dont touch
    end,
}

-------------------------------------------------------------------------------
-- CREATOR
-------------------------------------------------------------------------------
Config.Creator = {
    minAge            = 18,                                     -- minimum age a new character can have
    bannedNames       = { "Arthur", "Marshton", "Shit", "Dick" }, -- a name containing any of these words is refused
    useIntroAnimScene = false,                                  -- true: RDO intro cinematic before the gender pick; false: straight to the gender pick
    genderInMenu      = false,                                  -- false: pick male/female on the prompt scene; true: a Gender row under Heritage
    finishPhoto       = false,                                  -- finish cinematic (walk to the mark, hands pose, portrait photo)
    startUndressed    = false,                                  -- start the creator undressed (off until proven not to break the ped)
    undressPreset     = nil,                                    -- outfit preset /undress and the Clothing row strip to; nil removes each garment instead. Not 3: a new ped is DRESSED with 3

    -- no custom creator scene: creation uses the stock vorp_character area.
    -- `spawn` is absent on purpose so creator_scene.lua never returns a scene;
    -- only the fill light is read, by CreatePlayerModel.
    scene             = {
        lightRange = 7.0, -- fill light range (metres)
        lightPower = 45.0, -- fill light intensity
    },
}

-------------------------------------------------------------------------------
-- FACE & BODY PAGE  (ui/ slider page)
-------------------------------------------------------------------------------
Config.FacePage = {
    enabled   = true,  -- face & body editing on the slider page; false uses the ink OpenFaceMenu
    buildTabs = true,  -- Heritage / Build / Age chips
    hairTabs  = true,  -- Hair / Beard / Bow / Brows / Stubble / Hair Dye chips
    makeup    = false, -- makeup chips (makeup is not part of creation)
    oneUI     = true,  -- the whole creator runs on the one page
}

-------------------------------------------------------------------------------
-- SPAWN PICKER  (new characters)
-------------------------------------------------------------------------------
-- The towns are in config/spawns.lua (Config.SpawnCoords).
Config.SpawnPicker = {
    enabled = false, -- let a new character pick a town; keep false while only one town is listed
}

-------------------------------------------------------------------------------
-- SHOPS  (in-world clothing / hair / makeup / face stores)
-------------------------------------------------------------------------------
-- The store locations and prices are in config/shops.lua.
Config.Shops = {
    enabled      = false, -- false: all of vorp_character's in-world stores are off (pup_clothing owns clothing). This also disables the hair/makeup/face stores

    -- second chance: re-edit the whole character
    secondChance = {
        price    = 15000,          -- what the player pays at a second chance store
        currency = 0,              -- 0 cash, 1 gold, 2 tokens
        item     = "secondchance", -- usable item that opens second chance
    },
}

-------------------------------------------------------------------------------
-- LOGS  (Discord embed style; set the webhook URL in `server/config.lua`)
-------------------------------------------------------------------------------
Config.Logs = {
    color           = 16711680,                          -- embed colour (decimal)
    logo            = "https://i.imgur.com/4X9Z5bH.png", -- embed logo URL
    footerLogo      = "https://i.imgur.com/4X9Z5bH.png", -- embed footer logo URL
    avatar          = "https://i.imgur.com/4X9Z5bH.png", -- webhook avatar URL

    -- sent when a player deletes a character (Secrets.Webhooks.deleteCharacter)
    deleteCharacter = {
        title       = "Delete Character",   -- embed title
        webhookName = "Character Deletion", -- webhook display name
    },
}
