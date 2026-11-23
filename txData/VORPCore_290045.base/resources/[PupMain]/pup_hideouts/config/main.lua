-- pup_hideouts | main settings

Config = Config or {}

Config.Debug         = false -- enables /stilltest, /stilltestreset, /themecheck
Config.DebugTeardown = false -- console trace of still teardowns

-- bucket = hideout id + offset; do not change (pup-misc relies on it)
Config.InstanceOffset = 2552

Config.RestartTimes = { 2359, 759, 1559 } -- HHMM

Config.StaffJobs  = {}
Config.PoliceJobs = { 'police', 'marshal' }

Config.Keys = {
    interact  = 0x760A9C6F, -- G
    secondary = 0xC7B5340A, -- Enter
    cancel    = 0x156F7119, -- Backspace
}
Config.KeyLabels = { interact = 'G', secondary = 'ENTER', cancel = 'BACKSPACE' }

Config.FredMeta = true -- send hunger/thirst changes to fred_meta

-- nil = the default shown
Config.SkillBar = {
    baseZone    = nil, -- 34 (% of the bar)
    zonePerStep = nil, -- 1.5 (% lost per difficulty point)
    minZone     = nil, -- 14
    perfectZone = nil, -- 6
    baseSpeed   = nil, -- 0.18
    speedStep   = nil, -- 0.02
    maxSpeed    = nil, -- 0.55
}

Config.AlertMinutes = 10
Config.AlertCommand = 'calert2'

----------------------------------------------------------------------------------------------------
-- Logs (webhook URLs go in server/config.lua)
----------------------------------------------------------------------------------------------------
Config.Logs = {
    enabled            = true,
    ownerWebhooks      = true,
    ownerCategories    = { Main = true, Ledger = true, Inventory = true, Production = true },
    username           = 'Underground Tracker',
    colors = {
        purchase = 65280, webhook = 3447003, delete = 16711680, rename = 3447003, transfer = 3447003,
        memberAdded = 3066993, memberRemoved = 15158332, memberLeft = 15158332,
        raidStarted = 16753920, brokenOpen = 16711680,
        withdrawal = 15158332, deposit = 3066993, ledgerStolen = 16711680,
        missionCompleted = 3066993, missionStarted = 15844367,
        itemDeposited = 3066993, itemWithdrawn = 15158332, production = 3447003,
        betPlaced = 10181046, fightStarted = 15844367, drugSold = 15105570,
        default = 5814783,
    },
}

----------------------------------------------------------------------------------------------------
-- Hideouts
----------------------------------------------------------------------------------------------------
Config.Hideouts = {
    maxTotal    = 4,   -- owned + co-owned
    maxOwned    = 1,
    maxCoOwned  = 3,

    consentRange   = 10.0,
    consentSeconds = 30,

    doorReach = 15.0,  -- buy, raid start, lock pick
    promptRange = 2.0, -- door prompts

    relocateMinutes = 30,
    relocatePrice   = 800, -- taken from the ledger
    relocateCommand = 'relocate',

    adminsSeeAllBlips = false,
    renamePrice = 100,
    nameMax = 50,

    townBlock = true,
    blockedTowns = { 'Annesburg', 'Armadillo', 'Blackwater', 'Rhodes', 'Siska', 'Strawberry', 'Tumbleweed', 'Valentine', 'Vanhorn' },

    plansItem       = 'hideout_plans',
    plansPrice      = 0,
    spacingOwned    = 150.0,
    spacingUnowned  = 40.0,
    plansReach      = 10.0, -- submitted spot must be this close to the real ped

    knockWait     = 20,   -- seconds
    knockRadius   = 12.0,
    inviteSeconds = 60,

    getoutCommand = 'getout',
    getoutPoint   = vector3(1514.6, 438.11, 89.93),
    nearInterior  = 100.0, -- "stuck" = this close to an inside point while not marked inside

    lastPosReach  = 50.0,  -- a saved last position must be this close to the real ped
    blipSprite    = -392465725,
    blipStyle     = 1664425300,
}

----------------------------------------------------------------------------------------------------
-- Stash
----------------------------------------------------------------------------------------------------
Config.Storage = {
    doorReach = 40.0, -- members using storage boxes may be this close to the door instead of inside
    blacklist = { wood = true, stone = true, metal = true, p_ambpack02x = true },
}

----------------------------------------------------------------------------------------------------
-- Raids
----------------------------------------------------------------------------------------------------
Config.Raids = {
    mode            = 'anyone', -- 'anyone' | 'police' | 'off'
    ownersOnline    = true,
    posseSize       = 3,
    warningMinutes  = 10,
    redAtSeconds    = 30,
    openMinutes     = 20,
    protectionDays  = 3,
    lockpickItem    = 'lockpick',
    safeCrackLevel  = 3,
    downDistance    = 100.0,
    syncSeconds     = 2,
    crackHintMs     = 4000,
}

----------------------------------------------------------------------------------------------------
-- Still teardown (raiders)
----------------------------------------------------------------------------------------------------
Config.Teardown = {
    seconds     = 120,
    minSeconds  = 5,
    tether      = 50.0,
    tool        = 'crowbar',
    consumeTool = true,
    mashLevel   = 4,
    range       = 2.0,
}

----------------------------------------------------------------------------------------------------
-- Bar and drinking
----------------------------------------------------------------------------------------------------
Config.Bar = {
    almonds   = { hunger = 10, thirst = -10, metabolism = 5 },
    moonshine = { hunger = -10, thirst = 30, metabolism = 5 },
    drunkPerDrink = 200, distortPerDrink = 0.5, distortCap = 2.5,
    wearEvery = 60, wearDrunk = 100, wearDistort = 0.2,
    thresholds = { 200, 600, 1000 },
    pourSeconds = 5, almondSeconds = 5, drinkSeconds = 10, washSeconds = 5,
    scenarioPoints = { pour = -2133000179, almonds = -2133000177, wash = -2133000181 },
    drinkScenario = 'WORLD_HUMAN_DRINKING_MOONSHINE',
    drunkScenario = 'WORLD_HUMAN_DRINKING_DRUNK_MOONSHINE',
    drunkFx = 'PlayerDrunk01', lensFx = 'LensDistDrunk',
}

----------------------------------------------------------------------------------------------------
-- Piano
----------------------------------------------------------------------------------------------------
Config.Piano = {
    enabled = true,
    restMinutes = 5,
    startDifficulty = 5000, dropMin = 800, dropMax = 1000, floor = 1000,
    everySeconds = 10,
    scenarios = { 'PROP_HUMAN_PIANO', 'PROP_HUMAN_ABIGAIL_PIANO' },
}

----------------------------------------------------------------------------------------------------
-- Bookie
----------------------------------------------------------------------------------------------------
Config.Bookie = {
    price = 250,
    houseCut = 0.1,
    healthMin = 100, healthMax = 200,
    fightMin = 45, fightMax = 90,
    betExpiryMinutes = 30,
    startDelay = 5,
    pullBack = 1.25,
    models = { 'U_M_M_ODriscollBrawler_01', 'U_M_M_BHT_ODRISCOLLSLEEPING', 'U_M_M_BHT_ODRISCOLLMAULED', 'U_M_M_BHT_ODRISCOLLDRUNK', 'CS_ColmODriscoll' },
}

----------------------------------------------------------------------------------------------------
-- Optional resources (adapters; see the README)
----------------------------------------------------------------------------------------------------
Config.Integrations = {
    -- server; forcedSource false = anonymous alert
    mdtAlert = function(coords, text)
        return exports['pup-mdt']:SendPoliceAlert(coords, text, false, false)
    end,
    -- server; false = pup-mdt's own chance roll said no
    mdtRadius = function(coords, text, radius)
        return exports['pup-mdt']:SendRadiusAlert(coords, { label = text, radius = radius })
    end,
    -- server
    mdtOnDuty = function(src)
        return exports['pup-mdt']:IsPlayerOnDuty(src)
    end,
    -- server
    mdtZone = function(coords)
        local z = exports['pup-mdt']:ZoneNameFromCoords(coords)
        if type(z) ~= 'string' or z == '' or z == 'Unknown Zone' then return nil end
        return z
    end,

    -- server; returns { item, label, price, count } or nil
    gangOffer = function(src)
        local o = exports['pup-gangs']:DrugSellOffer(src)
        if type(o) ~= 'table' then return nil end
        return { item = o.resultitem, label = o.label, price = tonumber(o.sellprice), count = tonumber(o.held) }
    end,
    -- server; returns the units actually taken
    gangTake = function(src, _item, qty)
        local r = exports['pup-gangs']:DrugTakeForSale(src, qty)
        if type(r) == 'table' then return tonumber(r.count) or 0 end
        return tonumber(r) or 0
    end,
    -- server; payout multiplier (1 or more)
    gangMultiplier = function(src, _coords)
        return exports['pup-gangs']:DrugSaleMult(src)
    end,
    -- server
    gangSaleDone = function(src, _item, qty, paid, _coords)
        return exports['pup-gangs']:DrugSaleDone(src, qty, paid)
    end,
    -- server
    gangBloodMoney = function(src, kind, _amount)
        return exports['pup-gangs']:AwardBloodMoney(src, kind, 'pup_hideouts drug sale')
    end,

    -- server; may this player use the given vorp_admin action?
    adminAllowed = function(src, action)
        return exports['vorp_admin']:allowedToExecuteAction(src, action) == true
    end,

    -- client; blocks until the minigame ends, true = success
    lockpick = function()
        return exports['lockpick']:lockpick()
    end,
}
