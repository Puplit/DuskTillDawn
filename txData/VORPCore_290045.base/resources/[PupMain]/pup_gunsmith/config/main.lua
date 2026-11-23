-- pup_gunsmith | main settings (see README)

Config = {}

Config.Debug = {
    general    = false,
    components = false,
    ammo       = false,
}

Config.InteractKey = 0x760A9C6F -- G

Config.PromptDistance = 1.0 -- metres

Config.JobOnly = true

---------------------------------------------------------------------------
-- Crafting stations
---------------------------------------------------------------------------
Config.Craft = {
    minGrade       = 1,
    reach          = 3.0,                          -- metres
    scenario       = 'WORLD_HUMAN_CROUCH_INSPECT',
    scenarioMs     = 15000,                        -- ms
    failConsumes   = true,
    useBox         = true,
    boxBase        = 12000000,
    ticketSeconds  = 180,
    maxAmount      = 1000,
    perksAward     = true,
    custom = {
        serial      = false,
        label       = false,
        description = false,
    },
    customMax = { serial = 20, label = 30, description = 120 }, -- characters
    noSerial = {
        'WEAPON_MELEE_CLEAVER', 'WEAPON_MELEE_HATCHET', 'WEAPON_MELEE_HATCHET_HUNTER', 'WEAPON_MELEE_KNIFE',
        'WEAPON_KIT_BINOCULARS_IMPROVED', 'WEAPON_KIT_BINOCULARS', 'WEAPON_FISHINGROD', 'WEAPON_KIT_CAMERA',
        'WEAPON_KIT_CAMERA_ADVANCED', 'WEAPON_MELEE_LANTERN', 'WEAPON_MELEE_DAVY_LANTERN',
        'WEAPON_MELEE_LANTERN_HALLOWEEN', 'WEAPON_KIT_METAL_DETECTOR', 'WEAPON_MELEE_HAMMER',
        'WEAPON_BOW', 'WEAPON_BOW_IMPROVED',
    },
}

Config.SkillBar = {
    baseZone        = 34,
    zoneLossPerLvl  = 1.5,
    minZone         = 14,
    baseSpeed       = 0.18,
    speedPerLvl     = 0.02,
    maxSpeed        = 0.55,
    perfectZone     = 6,
    iconWeapon      = 'fa-solid fa-gun',
    iconAmmo        = 'fa-solid fa-burst',
}

---------------------------------------------------------------------------
-- Customization bench
---------------------------------------------------------------------------
Config.Bench = {
    minGrade     = 1,
    reach        = 3.0,   -- metres
    scenario     = 'WORLD_HUMAN_WRITE_NOTEBOOK',
    partCash     = 0,     -- nil = catalogue prices
    partGold     = 0,     -- nil = catalogue prices
    workMs       = 6000,  -- ms
    watchRange   = 25.0,  -- metres
    watchRefresh = 2000,  -- ms
    presetLimit  = 40,    -- per character
    maxParts     = 40,
    camera = {
        fov       = 38,
        easeIn    = 1100, -- ms
        easeOut   = 800,  -- ms
        startElev = 28,   -- degrees
        minElev   = 5,    -- degrees
        maxElev   = 75,   -- degrees
        zoomMin   = 0.55,
        zoomMax   = 1.8,
        turnSpeed = 110, -- deg/s
        tiltSpeed = 55,  -- deg/s
        glide     = 9,
    },
    light = { r = 255, g = 236, b = 205, height = 0.7, range = 1.6, intensity = 6.0 },
}

---------------------------------------------------------------------------
-- Putting saved parts back on the gun in hand (client)
---------------------------------------------------------------------------
Config.Refit = {
    waitForWeaponMs = 30000, -- ms
    pollMs          = 250,   -- ms
    settleMs        = 500,   -- ms
    gripTint        = true,
    gripTintSkipTag = nil,   -- nil = no tag check
    tintSlots = {
        LONGARM     = 1465341584,
        SHORTARM    = 2145617267,
        MELEE_BLADE = 314786149,
    },
    inventorySlots = {
        character = 'SLOTID_NONE',
        weapon    = 'SLOTID_WEAPON_0',
        grip      = 'SLOTID_WEAPON_GRIP',
    },
}

Config.Repair = {
    kitItem  = 'repair_kit',                  -- not used here: vorp_inventory handles the kit
    fee      = 0,                             -- dollars; nil = free
    workMs   = 6000,                          -- ms
    scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK',  -- not used: the bench keeps its own scenario
}

---------------------------------------------------------------------------
-- Gun store counters
---------------------------------------------------------------------------
Config.Shop = {
    enabled    = true,
    reach      = 3.0,   -- metres
    maxAmount  = 1000,
    blipSprite = 202506373,
    blipScale  = 0.2,
    confirmTimeoutMs = 30000, -- ms
}

---------------------------------------------------------------------------
-- Security
---------------------------------------------------------------------------
Config.Security = {
    kickLegacyPayment = true,
}

Config.ItemImage = 'nui://vorp_inventory/html/img/items/%s.png'
