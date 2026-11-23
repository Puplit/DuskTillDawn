-- pup_armory | how to add your own weapons: base-game props, custom models and swords
-- Everything below is commented out, so this file adds nothing until you uncomment a block.
-- Put your weapons here (or copy this file to config/weapons_custom.lua; both are loaded).
-- config/weapons.lua has 39 base-game weapons to copy from.
--
-- For every weapon:
--   1. Add the item to the `items` table (copy a row from sql/install.sql, change item + label).
--   2. Add an item image: vorp_inventory/html/img/items/<item>.png
--   3. Restart, give yourself the item, use it, run /wp and nudge it into place.
--      Staff can save that position as the server default for everyone.

Config.Weapons = Config.Weapons or {}
local function add(target, list) for _, w in ipairs(list) do target[#target + 1] = w end end

-------------------------------------------------------------------------------
-- 1. BASE-GAME RDR2 PROPS  (no model pack needed)
-- Any prop in the game can be a weapon: use its model name. Prop names are listed in
-- the community object lists (e.g. github.com/femga/rdr3_discoveries -> objects).
-------------------------------------------------------------------------------
add(Config.Weapons, {
    -- {
    --     item  = 'my_pickaxe',         -- the usable item (same name as in the items table)
    --     label = 'Old Pickaxe',        -- the name players see
    --     model = 'p_pickaxe01x',       -- the base-game prop model
    --     kind  = 'blunt',              -- blade | knife | blunt | shield (how it swings)
    --     carry = 'back',               -- back | spine | hip | belt | arm (Config.CarryStyles)
    --     hold  = 'club',               -- blade | knife | club | long (Config.HoldStyles)
    -- },
    -- {
    --     item  = 'pan_shield',
    --     label = 'Frying Pan Shield',
    --     model = 'p_panlg01x',
    --     kind  = 'shield',             -- worn on the left forearm, no swing
    -- },
})

-------------------------------------------------------------------------------
-- 2. CUSTOM MODELS  (models you made or own)
-- Stream them from your own resource and ensure it before pup_armory in server.cfg:
--   the .ydr and .ytd, plus a .ytyp declared with data_file 'DLC_ITYP_REQUEST'.
-------------------------------------------------------------------------------
add(Config.Weapons, {
    -- {
    --     item  = 'my_sword',
    --     label = 'My Sword',
    --     model = 'my_sword_model',     -- the archetype name in your .ytyp
    --     kind  = 'blade',
    --     carry = 'back',
    --     hold  = 'blade',
    --     -- jobs = { 'police' },        -- optional: only these jobs may use it
    --     -- base = 'weapon_melee_knife', -- optional: swing it as this weapon instead
    -- },
    -- {
    --     item  = 'my_shield',
    --     label = 'My Shield',
    --     model = 'my_shield_model',
    --     kind  = 'shield',
    -- },
})

-------------------------------------------------------------------------------
-- 3. SWORDS  (with their own exact positions instead of a carry / hold style)
-- When a style does not suit a sword, give it a bone and its own two positions.
-- Each position is { x, y, z, rx, ry, rz }: metres and degrees from the bone.
-- Find the numbers in game: carry the sword, run /wp, move it, and read them from
-- the editor (staff can also just save it as the server default instead).
-------------------------------------------------------------------------------
add(Config.Weapons, {
    -- {
    --     item  = 'cavalry_sword',
    --     label = 'Cavalry Sword',
    --     model = 'p_sword01x',             -- a base-game sword prop, or your own model
    --     kind  = 'blade',
    --     bone  = 'SKEL_Pelvis',            -- the bone it hangs from while put away
    --     worn  = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },        -- put away (move it to the hip in /wp)
    --     hand  = { 0.10, 0.02, -0.02, -90.0, 0.0, 0.0 },  -- drawn, in the right hand
    --     -- jobs = { 'marshal' },          -- optional: only these jobs may use it
    -- },
})
