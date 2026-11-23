-- storagebox | settings (see README)

StorageBoxConfig = {}
local C = StorageBoxConfig

C.Debug = false                    -- extra console lines on the server
C.LogUsername = 'StorageBox Logs'  -- Discord username on log posts (webhooks: Secrets.Webhooks.storagebox)

---------------------------------------------------------------------------- timings and distances
C.HideoutBucketFrom = 2553   -- routing bucket this or higher = inside a pup_hideouts hideout
C.HideoutPollMs     = 500    -- how often carriers' buckets are checked
C.ServerReach       = 5.0    -- metres: placed-box open / pick-up / put-down reach (server)
C.PromptRadius      = 1.5    -- metres: placed-box prompt radius (client)
C.PlaceThrottleMs   = 1000   -- one put-down per player per second
C.DepositGuardMs    = 10000  -- one deposit per box id inside this window
C.NewBoxLockMs      = 750    -- per source inventory, for transfers into an unopened box
C.GiveCheckMs       = 1500   -- after a box leaves a satchel, wait this long to see who holds it
C.DepositingFlagMs  = 3000   -- removal hooks stay silent for a box being deposited
C.PlacingFlagMs     = 2000   -- removal hooks stay silent for a box being put down
C.OpenDelayMs       = 300    -- pause between closing a panel and opening the box
C.StateResendMs     = 3000   -- after character select / resource start: send carry state + placed list
C.PlacedSyncDelayMs = 2500   -- after inventories are registered at start: broadcast placed boxes
C.RegisterDelayMs   = 1500   -- after start-up SQL: register every box inventory

-- vorp_inventory writes some stack merges asynchronously; reads are retried until they settle
C.WriteConfirmTimeoutMs = 3000
C.WriteConfirmStepMs    = 100

---------------------------------------------------------------------------- keys
C.Keys = {
    putDown = 0xE30CD707, -- G: put the carried box down
    pickUp  = 0x760A9C6F, -- G: pick a placed box up
    open    = 0xCEFD9220, -- E: open a placed box
}

---------------------------------------------------------------------------- carrying
C.Carry = {
    maxStamped      = 10,          -- opened boxes + packs one satchel may hold (also the default item limit)
    extraBoxFactor  = 0.8,         -- each extra loaded box multiplies the move rate by this (compounding)
    defaultMoveRate = 1.2,         -- move rate of a box type that sets none
    defaultModel    = -950356675,  -- crate model when a box type sets none ("p_crate02x" is an alternative)
    restoreMoveRate = 3.0,         -- movement cap given back when carrying stops (full sprint)
    -- the animation, bone, offset and rotation were tuned together: change them together
    anim     = { dict = 'mech_carry_box', clip = 'idle', flag = 31, blendIn = 1.0, blendOut = 8.0 },
    bone     = 'SKEL_R_Finger12',
    offset   = { 0.40, 0.028, -0.15 },
    rotation = { 70.0, 140.0, 80.0 },
    resetFlag       = 2,                          -- ped reset flag set every frame (native 0xC1E8A365BF3B29F2)
    blockedControls = { 0xD9D0E1C0, 0x5181713D }, -- jump, and the second control the carry blocks
    -- ped carrying flags switched off while carrying and restored afterwards, through
    -- the native below; empty = off
    handFlagNative = 0x18FF3110CF47115D,
    handFlags       = {},
    -- wagon block
    wagonEjectMs    = 1200,
    ragdollMinMs    = 2000,
    ragdollMaxMs    = 2500,
    wagonDebounceMs = 3000,
}

---------------------------------------------------------------------------- animations
C.Anims = {
    inspect = { dict = 'amb_work@world_human_crouch_inspect@female_a@base', clip = 'base', flag = 1 },
    putDown = { dict = 'amb_player@world_player_chore@box_put_down@male_a@stand_exit', clip = 'exit_front', ms = 1800 },
    pickUp  = { dict = 'amb_work@world_human_box_pickup@1@male_a@stand_exit_withprop', clip = 'exit_front', ms = 1800 },
}
C.InspectFocusWaitMs = 500   -- start watching NUI focus this long after opening a placed box
C.InspectFocusPollMs = 300
C.InspectFocusGraceMs = 3000 -- stop the crouch if the panel never took focus within this

---------------------------------------------------------------------------- putting down
C.PutDown = {
    rayHeight   = 1.7,  -- ray cast this high above the feet
    rayLength   = 0.8,  -- and this far forward
    wallMargin  = 0.25, -- subtracted from the hit distance
    minDistance = 0.1,
    maxDistance = 0.7,  -- also the distance when nothing is hit
}

---------------------------------------------------------------------------- inventory types
-- vorp_inventory panel types. Shops must never be added: they go through the shop path.
C.DepositTypes        = { clan = true, id = true, wagon = true, horse = true, hideout = true, Container = true }
C.TransferSourceTypes = { clan = true, custom = true, cart = true, horse = true, hideout = true, Container = true }
-- panel types where a pack unloads into the pockets instead of a container
C.PocketPanelTypes    = { [''] = true, main = true, normal = true, player = true, steal = true }
-- panel types that count as "at a shop"
C.ShopPanelTypes      = { store = true, shop = true }

-- custom inventory defaults for every box and pack
C.InventoryDefaults = {
    capacity = 500,      -- used when neither the row nor the type gives one
    acceptWeapons = false,
    shared = true,
    ignoreItemStackLimit = true,
}

-- item rows synced into vorp's `items` table at start
C.ItemDefaults = { weight = 1, canRemove = 1, type = 'item_standard', usable = 1, limit = 10, rarity = 1 }

---------------------------------------------------------------------------- switches
C.Switches = {
    OneUsedBoxPerType   = true,  -- a player may hold only one opened box of each item type
    EmptyBoxDirectInsert = true, -- last resort for an empty box tipped into an unregistered inventory: write it into the DB
    VerifyDepositArrival = true, -- before destroying a deposited box, read the target back and check every stack arrived
    -- a loaded box that leaves a satchel by a drop or delete: 'keep' its inventory and row (recoverable by whoever
    -- picks the item up, and by staff from the log), or 'delete' them with the contents
    LoadedDroppedBox    = 'keep',
    SteamInLogs         = true,  -- society and house logs show Steam name and id
    TypeWebhooks        = true,  -- also post to the per-type admin webhooks (house, camp, hideout, custom)
}
