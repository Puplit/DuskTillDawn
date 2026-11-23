CONFIG                        = CONFIG or {}
-- server console trace for GIVE and DESTROY. It prints a line per transfer and buries
-- everything else, so turn it on only while chasing a specific dupe report.
CONFIG.TRACE_ITEM_MOVES    = false

CONFIG.USE_GOLD_CURRENCY      = false -- you do not use gold currency leave this to false this will block any attempts to use gold

-- TO USE THE OPEN SADLE BUTTON ADD YOUR STABLE LOGIC HERE
-- this is a server side function
-- BY DEFAULT ITS USING VORP STABLES
CONFIG.OPEN_SADDLE            = function(charid, model, entity, netid)
    local id = ("%s_%s"):format(model, charid)
    return id -- return the inventory id here
end

CONFIG.NEW_PLAYER             = {
    ALLOW_ACTIONS = {
        ENABLE = false, -- if true, new players can give money or items to other players
        COOLDOWN = 300, -- in seconds 5m by default
    },
    START_ITEMS = {
        raspberrywater = 5, -- ITEMS SAME NAME AS IN DATABASE
        cakecarrot = 5         -- AMMO SAME NAME AS IN THE DATABASE
    },
    START_WEAPONS = {
        "WEAPON_MELEE_KNIFE" -- WEAPON NAME
    }
}
-- ACCEPT / DENY PROMPT ON GIVES
CONFIG.ASK_BEFORE_GIVE     = false

-- TXADMIN RESTART LOCK: this many minutes before a scheduled restart, nobody can give items, weapons,
-- money or ammo to another player, or move anything between inventories (stashes, wagons, houses,
-- other players). Fires on txAdmin's 30/15/10/5/4/3/2/1 minute warnings. 0 = off.
CONFIG.RESTART_LOCK_MINUTES = 5

CONFIG.DELETE_ITEM_EXPIRED    = false -- if true items on use that are expired will be deleted (only works for items with degradation)

CONFIG.PICKUPS.USE_TIMER      = false -- if true it will add timer to delete pickups
CONFIG.PICKUPS.TIMER          = 10    -- after this time pick up wll be deleted, IN MINUTES
CONFIG.PICKUPS.DELETE_ON_DROP = { -- if true then dropping only deletes them and a box on the floor is not created
    ITEM   = true,
    WEAPON = true,
    MONEY  = true,
    GOLD   = true,
    ROLL   = true,
}

-- HOW MANY WEAPONS ALLOWED PER PLAYER FOR ITEMS IS IN VORP CORE CONFIG
CONFIG.MAX_WEAPONS            = {
    PLAYERS   = 6,
    JOBS      = { -- leave empty to use the players amount
        police = 10,
    },
    -- Items that dont get added up torwards your max weapon count meaning you can carry as many as you want
    WHITELIST = {
        WEAPON_KIT_BINOCULARS_IMPROVED = true,
        WEAPON_KIT_BINOCULARS = true,
        WEAPON_FISHINGROD = true,
        WEAPON_KIT_CAMERA = true,
        WEAPON_KIT_CAMERA_ADVANCED = true,
        WEAPON_MELEE_LANTERN = true,
        WEAPON_MELEE_DAVY_LANTERN = true,
        WEAPON_MELEE_LANTERN_HALLOWEEN = true,
        WEAPON_KIT_METAL_DETECTOR = true,
        WEAPON_MELEE_HAMMER = true,
        WEAPON_MELEE_KNIFE = true,
    }
}


CONFIG.PLAYER_RESPAWN = {
    --- VORP CURRENCY ---
    MONEY = {
        ENABLE     = false, -- if true then the money will be cleared on player respawn
        JOB_LOCK   = {      -- Wont remove from these jobs
            police = true,
            doctor = true
        },
        PERCENTAGE = 1.0, -- 0.1 = 10% of money 1.0 = 100% of money
    },
    GOLD = {
        ENABLE     = false,
        JOB_LOCK   = {
            police = true,
            doctor = true
        },
        PERCENTAGE = 1.0,
    },
    ROLL = {
        ENABLE     = false,
        JOB_LOCK   = {
            police = true,
            doctor = true
        },
        PERCENTAGE = 1.0,
    },
    ---
    ITEMS = {
        ENABLE    = false,
        JOB_LOCK  = {
            police = true,
            doctor = true
        },
        ALL       = true, -- deletes all items instead of just the whitelist
        WHITELIST = {
            consumable_raspberrywater = true,
            ammorevolvernormal = true
        },
    },

    WEAPONS = {
        ENABLE    = false,
        JOB_LOCK  = {
            police = true,
            doctor = true
        },
        ALL       = true, -- deletes all weapons instead of just the whitelist
        WHITELIST = {
            WEAPON_MELEE_KNIFE = true,
            WEAPON_BOW = true
        },

    },

    AMMO = {
        ENABLE   = false, -- if true then the ammo will be cleared on player respawn
        JOB_LOCK = {
            police = true,
            doctor = true
        },
    },
}

CONFIG.LOGS           = {
    -- false strips the audit block (character id, identifier, server id, job, coords, resource)
    DETAILED                = true,

    -- every log below falls back to `webhook` when its own url is empty
    ItemUseWebhook          = "", -- item consumed / used
    CraftWebhook            = "", -- crafting (hand + location)
    ApiGiveWebhook          = "", -- items handed out BY A SCRIPT (admin give, shops, jobs)

    -- resources whose item gives/removes are NOT logged
    ApiGiveIgnore           = {
        miner_lumber     = true, -- mining / lumber, one payout per swing
        skinanimals      = true, -- skinning, one payout per carcass
    },
    WeaponApiWebhook        = "", -- weapons handed out or deleted by a script

    -- PLAYER TO PLAYER ONLY. Nothing a script does reaches these two, so the
    -- channel stays readable: one line per hand-over, one per destroy.
    -- Leave empty to fall back to `webhook` below, which is the noisy one.
    PlayerGiveWebhook       = "", -- a player handed an item to another player
    DestroyWebhook          = "", -- a player destroyed or dropped an item
    colorPlayerGive         = 3447003,  -- blue
    colorDestroyItem        = 15158332, -- red

    -- MAIN INVENTORY LOGS
    webhookname             = "INVENTORY LOGS", -- webhook name
    webhook                 = "",               -- webhook url

    --Gold Logs Color
    colorpickedgold         = 65280,
    colorgiveGold           = 4286945,
    colorDropGold           = 16711680,

    --Money log color
    colorgiveMoney          = 4286945,
    colormoneypickup        = 65280,
    colorDropMoney          = 16711680,

    --Item log color
    coloritemDrop           = 16711680,
    coloritempickup         = 65280,
    colorgiveitem           = 4286945,
    -- pup: colours for the extra pup log types
    colorItemUse            = 15844367, -- gold
    colorCraft              = 3447003,  -- blue
    colorApiGive            = 10181046, -- purple
    colorApiRemove          = 15105570, -- orange

    --Weapon log color
    colorweppickupd         = 65280,
    colorgiveWep            = 4286945,
    colordropedwep          = 16711680,

    -- CUSTOM INVENTORY LOGS

    cuscolor                = 16711680,
    custitle                = "CUSTOM INV LOGS",
    cusavatar               = "",
    cuslogo                 = "",
    cusfooterlogo           = "",
    cuswebhookname          = "CUSTOM INV LOGS",
    CustomInventoryTakeFrom = "", -- webhook url
    CustomInventoryMoveTo   = "", -- webhook url


    NetDupWebHook = {
        -- somone tries to use dev tools to cheat
        Active = true,
        color = 16711680,
        webhook = "", -- webhook url
        Language = {
            title = "Possible Cheater Detected",
            descriptionstart = "Invalid NUI Callback performed by...\n **Playername** `",
            descriptionend = "`\n"
        }
    },

}
