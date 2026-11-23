-- pup_staffdesk | main config
-- The Staff Desk: parcels from staff, character changes, the bug bounty shop and playtime.
Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    deskDistance = 2.0,                                  -- how close you must stand to a desk (metres)
    imagePath    = 'nui://vorp_inventory/html/img/items/', -- item pictures in the panel
    logAvatar    = '',                                   -- avatar URL for webhook log posts ('' = the webhook's own)
}

-- Prompt key. Change the hash only.
Config.Keys = {
    open = 0x760A9C6F, -- G
}

-------------------------------------------------------------------------------
-- STAFF  (who may send parcels, award points, rename others)
-------------------------------------------------------------------------------
Config.Staff = {
    groups = { 'admin' },          -- VORP user groups counted as staff
    permission = 'manage_staffdesk', -- or anyone holding this vorp_admin permission (desk.manage). It creates cash and items.
    commands = {
        desk    = 'staffdesk', -- /staffdesk opens the panel anywhere (staff only)
        parcel  = 'parcel',    -- /parcel <charid|discordid> cash <amount> [note] | item <name> <count> [note] | weapon <HASH> [note]
        parcels = 'parcels',   -- /parcels <charid|discordid>   list what is waiting
        bounty  = 'bounty',    -- /bounty <add|take|check> <charid> [points] [reason]
        rename  = 'rename',    -- /rename <serverid> <first> <last>   free staff rename
    },
    legacyCommands = true, -- also answer the old /recomp, /addPoints, /removePoints, /checkPoints
}

-------------------------------------------------------------------------------
-- DESKS  (where the panel opens)
-------------------------------------------------------------------------------
-- name = map label, coords = vector3, blip = sprite hash (nil = no blip)
Config.Desks = {
    saintdenis = { name = 'Staff Desk', coords = vector3(2746.9, -1395.07, 46.18),     blip = -426139257 },
    rhodes     = { name = 'Staff Desk', coords = vector3(1224.15, -1288.18, 76.94),    blip = -426139257 },
    annesburg  = { name = 'Staff Desk', coords = vector3(2930.18, 1279.58, 44.35),     blip = -426139257 },
    valentine  = { name = 'Staff Desk', coords = vector3(-174.2, 633.14, 114.13),      blip = -426139257 },
    blackwater = { name = 'Staff Desk', coords = vector3(-873.636, -1335.373, 43.614), blip = -426139257 },
    strawberry = { name = 'Staff Desk', coords = vector3(-1794.4, -379.14, 160.2),     blip = -426139257 },
    armadillo  = { name = 'Staff Desk', coords = vector3(-3726.2, -2602.8, -12.88),    blip = -426139257 },
}

-------------------------------------------------------------------------------
-- PARCELS  (what staff send you: cash, items, weapons)
-------------------------------------------------------------------------------
Config.Parcels = {
    maxCash   = 100000, -- largest cash parcel staff may send in one go
    maxItems  = 1000,   -- largest item stack in one parcel
    noteLength = 120,   -- longest note on a parcel
    -- a letter when something is waiting (needs pup_postoffice)
    mail = { enabled = true, fromName = 'The Staff Desk' },
}

-------------------------------------------------------------------------------
-- CHARACTER CHANGES
-------------------------------------------------------------------------------
Config.Height = {
    enabled = true,
    price   = 10000, -- cash
    min     = 0.95,  -- smallest scale
    max     = 1.05,  -- largest scale
    previewSeconds = 8, -- "Preview" shows the new height this long before you pay
}

Config.Rename = {
    enabled      = true,
    price        = 1000, -- cash
    cooldownDays = 30,   -- days between renames of the same character (0 = none)
    minLength    = 2,
    maxLength    = 16,   -- per name
    unique       = true, -- refuse a first + last name another character already has
    blocked      = { 'admin', 'staff', 'moderator', 'puppet' }, -- refused anywhere in a name (case ignored)
}

Config.PetName = {   -- needs pup-misc pets; writes onto the whistle you carry
    enabled      = true,
    price        = 1000,
    cooldownDays = 10,   -- per pet
}

Config.WeaponName = {
    enabled       = true,
    price         = 1000,
    cooldownDays  = 10,  -- per weapon
    maxNameLength = 32,
    maxDescLength = 200,
}

-------------------------------------------------------------------------------
-- BUG BOUNTY  (staff award points for reported bugs; players spend them here)
-------------------------------------------------------------------------------
-- item = inventory item, label = shown name, cost = points (0 hides it), maxHeld = refuse if you already carry this many
Config.Bounty = {
    enabled = true,
    rewards = {
        { item = 'crowbar01',     label = 'Crowbar',     cost = 150, maxHeld = 1 },
        { item = 'club03',        label = 'Wooden Club', cost = 150, maxHeld = 1 },
        { item = 'club06',        label = 'Bone Club',   cost = 150, maxHeld = 1 },
        { item = 'clamp01',       label = 'Clamp',       cost = 150, maxHeld = 1 },
        { item = 'shovel_weapon', label = 'Shovel',      cost = 150, maxHeld = 1 },
        { item = 'pup_cigar',     label = 'Lit Cigar',   cost = 75,  maxHeld = 1 },
        { item = 'pup_cane_wood', label = 'Wooden Cane', cost = 100, maxHeld = 1 },
        { item = 'cane',          label = 'Cane',        cost = 100, maxHeld = 1 },
    },
}

-------------------------------------------------------------------------------
-- PLAYTIME  (counted per character, a minute at a time)
-------------------------------------------------------------------------------
Config.Playtime = {
    command    = 'playtime',
    milestones = {
        enabled = false,
        list = {
            { hours = 10,  cash = 25,  note = '10 hours in the territory' },
            { hours = 50,  cash = 100, items = { { name = 'bread', count = 5 } }, note = '50 hours in the territory' },
            { hours = 100, cash = 250, note = '100 hours in the territory' },
        },
    },
}
