-- pup-bank | settings (branches are in config/banks.lua, text in config/locale.lua)

Config = {}

Config.General = {
    debug = false,              -- trace every request and reply to the server console and F8
}

Config.Keys = {
    interact = 0x760A9C6F,      -- G: open the bank at a counter
}

Config.Counter = {
    promptRange = 1.5,          -- metres from the counter before the prompt shows
    serverRange = 15.0,         -- metres the server accepts a deposit / withdrawal from
}

Config.Logs = {
    avatarUrl      = "",        -- image on the Discord posts; "" = Discord's default
    pingStaffAbove = 30000,     -- a deposit this large adds @everyone (once per 5 minutes per character)
}

Config.Teller = {
    enabled      = true,
    job          = "bankteller",
    minGrade     = 0,
    managerGrade = 3,

    nearbyRange    = 5.0,        -- metres
    consentSeconds = 45,         -- seconds

    feeMin    = 0,               -- $
    feeMax    = 500,             -- $
    feeMaxPct = 10,              -- percent of the amount

    transferMin        = 1,      -- $
    transferMax        = 25000,  -- $
    transferMaxManager = 100000, -- $, managerGrade and above
}
