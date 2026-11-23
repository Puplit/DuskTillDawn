-- pup-hotel | main settings

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug = false,                  -- print debug info to the server console
}

-- Prompt keys. Change the hash only.
Config.Keys = {
    desk = 0x17BEC168,              -- E, front desk / office prompt (the same control doorlocks uses)
    door = 0x8FFC75D6,              -- SHIFT, lock / unlock a room door
}

-------------------------------------------------------------------------------
-- INTEGRATIONS  (other PUP resources this one can talk to)
-------------------------------------------------------------------------------
Config.Integrations = {
    -- pup_business share of every room payment; the rest leaves the economy
    society = {
        job        = 'sdhotel',     -- business ledger the cut is paid into
        cutPercent = 25,            -- percent of each payment, 0 turns it off
    },
}

-------------------------------------------------------------------------------
-- DESK
-------------------------------------------------------------------------------
Config.Desk = {
    promptRadius = 1.2,             -- metres; desk / office prompt range, keep under half the gap between them
}

-------------------------------------------------------------------------------
-- STAFF  (who may work the desk)
-------------------------------------------------------------------------------
Config.Staff = {
    permission = 'manage_hotel',    -- vorp_admin permission that counts as staff
    -- or anyone on one of these jobs at this grade or above (the same grade sets prices and evicts)
    jobs = {
        ['sdhotel'] = 0,
    },
    allowFreeAssign = true,         -- staff may waive the charge entirely
}

-------------------------------------------------------------------------------
-- RENT
-------------------------------------------------------------------------------
Config.Rent = {
    daySeconds         = 86400,     -- real seconds one day of rent lasts (86400 = a real 24 hours)
    maxDays            = 14,        -- most days a clerk may sell in one go
    roomsPerCharacter  = 1,         -- rooms one guest may hold at once, across every hotel
    currency           = 0,         -- 0 = cash, 1 = gold
    sweepSeconds       = 60,        -- how often expired stays are swept up
    warnBeforeSeconds  = 3600,      -- warn the guest this long before their stay runs out
}

-------------------------------------------------------------------------------
-- TIERS  (room types; price is per day, charged to the guest)
-- Office prices override these and are stored in hotel_settings.
-------------------------------------------------------------------------------
Config.Tiers = {
    basic = { label = 'Basic Room',    price = 25 },
    vip   = { label = 'VIP Suite',     price = 100 },
    vvip  = { label = 'The Apartment', price = 250 },
}

-------------------------------------------------------------------------------
-- DOORS  (room doors stay locked unless the guest holding the room opens one)
-------------------------------------------------------------------------------
Config.Doors = {
    enabled           = true,       -- false leaves room doors alone
    promptRadius      = 1.0,        -- metres; keep under half the gap between two neighbouring doors
    animation         = true,       -- key-in-the-lock animation; false goes straight to the click
    relockSeconds     = 0,          -- re-lock a room this long after it was opened, 0 = never
    -- lock state is lost on streaming, so it is re-asserted for doors this close
    enforceRadius     = 25.0,       -- metres
    enforceIntervalMs = 2000,       -- ms between re-asserts
}
