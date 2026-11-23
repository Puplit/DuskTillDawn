-- pup_railroad | general settings

Config = {}

Config.Debug = false

-- the delete-vehicle command (anyone may use it; the server decides what it may delete)
Config.DeleteCommand = 'dv'

Config.KeyItem   = 'trainkey'
Config.CoalItem  = 'coal'
Config.KeyPrice  = 100 -- cash

-- items that can never be put in a train lockbox
Config.LockboxBlacklist = { 'lockpick', 'trainkey' }

Config.CruiseControl = true

Config.KeyCheckOnBoarding = true -- false = only the driver seat is checked

Config.Maintenance = {
    enabled         = true,
    wearPerCoal     = 0.5,
    jobs            = { 'standardtrain' },
    repairAtOrBelow = 20,
    promptAtOrBelow = 90,
    materialSets = { -- [wear] = materials; the nearest key is used
        [90] = { { item = 'ironbar', count = 5 },  { item = 'ironhammer', count = 1 } },
        [50] = { { item = 'ironbar', count = 10 }, { item = 'ironhammer', count = 1 } },
        [0]  = { { item = 'ironbar', count = 15 }, { item = 'ironhammer', count = 1 } },
    },
}

local function tierCost()
    return {
        { item = 'ironbar', label = 'iron bar', count = 10 },
        { item = 'copper',  label = 'copper',   count = 20 },
    }
end

Config.Upgrades = {
    jobs     = { 'standardtrain' },
    speedCap = 30, -- MPH
    speed = { -- amount = MPH added per tier
        { amount = 5, materials = tierCost() },
        { amount = 5, materials = tierCost() },
        { amount = 5, materials = tierCost() },
        { amount = 5, materials = tierCost() },
        { amount = 5, materials = tierCost() },
    },
    engine = { -- amount = seconds per coal added per tier
        { amount = 5, materials = tierCost() },
        { amount = 5, materials = tierCost() },
        { amount = 5, materials = tierCost() },
        { amount = 5, materials = tierCost() },
        { amount = 5, materials = tierCost() },
    },
    exitAfterWork = true,
}

Config.Announcements = {
    enabled          = true,
    boardEnabled     = true,
    job              = 'standardtrain',
    cooldown         = 20,  -- seconds per player
    platformRadius   = 60.0, -- metres
    hearingDistance  = 60.0, -- metres
    statusEverywhere = true, -- false = only the caller's station platform
    statuses = {
        { key = 'stop',       label = 'Stop',       description = 'Stopped at the closest station',  text = 'status_stop' },
        { key = 'clear',      label = 'Clear',      description = 'The track is clear',              text = 'status_clear' },
        { key = 'turnaround', label = 'Turnaround', description = 'Returning to the closest station', text = 'status_turnaround' },
    },
}

-- distances in metres (server checks are full 3D)
Config.Reach = {
    station        = 30.0,
    train          = 30.0,
    stopPlayer     = 50.0,
    stopTrain      = 150.0,
    junction       = 150.0,
    junctionPrompt = 50.0, -- client, horizontal
}

Config.MinRouteDistance = 1400.0 -- metres

Config.AbandonedSeconds = 300

Config.BusinessIntegration = true

Config.Timings = {
    spawnPermit       = 120,   -- s
    burnSlack         = 2,     -- s
    sweep             = 30,    -- s
    missingDrop       = 60,    -- s
    switchGap         = 300,   -- ms per player
    stationPrompt     = 2.0,   -- m
    lastStation       = 80.0,  -- m
    keyRecheck        = 30000, -- ms
    stopped           = 0.1,   -- speed below which a train counts as stopped
    stopPrompt        = 25.0,  -- m, horizontal
    movingAtStop      = 1.0,   -- speed above which "bring her to a stop" shows
    workDuration      = 30000, -- ms
    announceNotice    = 9000,  -- ms
    inputTimeout      = 120000,-- ms
    deliverAnswer     = 10000, -- ms
}

Config.Seats = {
    trainSeat    = 'PROP_VEHICHLE_SEAT_PASSENGER_TRAIN_TG', -- spelt as the game spells it
    chair        = 'PROP_HUMAN_SEAT_CHAIR',
    chairCentre  = vector3(2546.7, -1299.1, 48.7), -- Saint Denis platform
    chairRadius  = 100.0,
    searchRadius = 1.0,
    maxPoints    = 10,
    settleGrace  = 8000, -- ms
    pressCooldown = 2000, -- ms
}

-- control hashes
Config.Keys = {
    interact    = 0x760A9C6F, -- G: station menu, sit / get up
    switchLeft  = 0xA65EBAB4,
    switchRight = 0xDEB34313,
    upgrade     = 0x8CC9CD42, -- X
    lockbox     = 0x1CE6D9EB, -- 2
    viewMission = 0x6319DB71, -- Up
    cancelMission = 0x05CA7C52, -- Down
    announce    = 0x4F49CC4C, -- 3
    cruise      = 0xD8F73058, -- U
    coal        = 0xB4E465B4, -- D
    maintenance = 0x8FD015D8, -- W
    deliver     = 0xAB62E997, -- 5
    throttle    = 0xFF3626FC, -- Shift
    brake       = 0x2D79D80A, -- Ctrl
}

Config.Blips = {
    stationScale = 0.2,
    trainSprite  = -399496385,
    trainScale   = 1.5,
    stopSprite   = -1546805641,
    stopScale    = 0.2,
    stopModifier = 0x6F85C3CE,
    gpsColour    = 'COLOR_RED',
}

Config.WorkScenario = 'WORLD_HUMAN_CROUCH_INSPECT'

-- switch states every client applies at start
Config.StartupSwitches = {
    -- SPOONI ADD-ON TRACK (PAID): these two set points on a track from Spooni's track add-on maps,
    -- which each server owner has to buy from Spooni. Without those maps they do nothing.
    { track = -988268728, index = 1, value = 1 },
    { track = -988268728, index = 0, value = 1 },
}

Config.SpawnSetsCruiseSpeed = true -- turn off if trains roll away on their own

Config.Natives = {
    trackSwitch    = 0xE6C5E2125EB210C1,
    trackDirection = 0x3ABFA128F5BF5A70,
}
