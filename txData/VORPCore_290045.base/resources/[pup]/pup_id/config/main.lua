-- pup_id | settings

Config = {}

Config.Commands = {
    own     = 'myid',
    handOver = 'idcard',
    inspect = 'takeid',
}

Config.CloseControl = 0x308588E6 -- input hash; releasing it closes the paper

Config.HandOverRange = 2.0 -- metres
Config.InspectRange  = 2.0 -- metres

Config.ServerRange = 5.0 -- metres, checked by the server

Config.HandOverCooldownMs = 2000
Config.InspectCooldownMs  = 2000
Config.OwnCooldownMs      = 1000

Config.ServerRestraintCheck = true
Config.RestraintReplyTimeoutMs = 1500

Config.IssueDate = '1st January 1901'

Config.PlainJobs = {
    police = true,
    doctor = true,
}

Config.TipMs = 4000

-- files in pup-ui/html/fonts; the theme's default pair is swapped for the paper's own
Config.Fonts = {
    avoid = { ['oswald.ttf'] = true, ['imfell.ttf'] = true },
    fallbackTitle = 'imfell.ttf',
    fallbackBody  = 'robotoslab.ttf',
}
