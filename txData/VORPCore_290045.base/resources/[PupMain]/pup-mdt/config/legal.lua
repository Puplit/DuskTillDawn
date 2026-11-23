-- pup-mdt | attorneys, the firm, ledger and payroll (shared)

Config.Legal = {
    enabled = true,
    jobs = { 'lawyer' },
    requireDuty = true,
    firedJob = 'unemployed',
    firedGrade = 0,
    footerLabel = 'Attorney',
    theme = { subtitle = 'Law Office', tagline = 'Attorneys at Law' },
    ranks = {
        [0] = 'Law Clerk', [1] = 'Paralegal', [2] = 'Junior Attorney', [3] = 'Attorney',
        [4] = 'Senior Attorney', [5] = 'District Attorney', [6] = 'Judge',
    },
    judgeGrade = 6,
    judgeApproves = false,    -- attorneys may rule on bail and appeals only when true

    tools = { expungements = true, bail = true, appeals = true, defense = true },

    -- lawyer grades merged into Config.Permissions for every lawyer job
    permissions = {
        criminals = 0, viewexpungements = 0, requestexpungement = 0,
        viewbail = 0, requestbail = 0, approvebail = 6,
        viewappeals = 0, requestappeal = 0, approveappeal = 6,
        viewdefense = 0, filedefense = 0, viewauditlog = 0,
        ledger = 0, ledgerdeposit = 0, ledgerwithdraw = 4,
        firmhome = 0, firmledger = 0, viewbarroster = 0,
        viewlawyerprofile = 4, firelawyers = 5, firmsettings = 5,
    },

    counsel = {
        enabled = true,
        command = 'lawyer',
        cancelCommand = 'cancellawyer',
        cooldownSeconds = 120,
        keep = 15,
        blip = true,
        blipColour = 'BLIP_MODIFIER_MP_COLOR_1',
        routeColour = 'COLOR_BLUE',
        blipSeconds = 300,
        arriveMetres = 15.0,
        homeWindowMinutes = 30,
    },

    bail = {
        clientPays = true,
        intoLedger = true,
        minAmount = 0,
        maxAmount = 0,            -- 0 = no limit
        courtHours = 48,
        autoForfeit = true,
        skipReimposes = true,
        refundOnAppear = true,    -- the bail goes back to the citizen when they appear
        processingTimeoutMinutes = 10,
    },

    firmLedger = {
        enabled = true,
        stationOnly = true,
        stations = {
            { label = 'Saint Denis Courthouse', coords = vector3(802.0, -1236.0, 43.6), radius = 20.0 },
        },
    },
}

Config.Ledger = {
    enabled = true,
    startBalance = 0,
    allowNegative = false,
    currency = 'cash',
    creditFines = true,
    stationOnly = true,
    stationRadius = 20.0,
    stations = {
        { label = 'Valentine',   coords = vector3(-274.7, 809.9, 119.4),   radius = 25.0 },
        { label = 'Rhodes',      coords = vector3(1359.0, -1300.5, 77.8) },
        { label = 'Blackwater',  coords = vector3(-763.6, -1268.5, 44.0) },
        { label = 'Saint Denis', coords = vector3(798.3, -1227.6, 43.6) },
        { label = 'Strawberry',  coords = vector3(-1806.4, -349.5, 164.6) },
    },
    -- external society table; must never be on together with creditFines
    externalFineCredit = { enabled = false, table = 'management_funds', amountColumn = 'amount', jobColumn = 'job_name', job = 'police' },
}

Config.Payroll = {
    enabled = true,
    intervalMinutes = 15,
    fromLedger = true,
    -- a wage is paid in proportion to the minutes on duty since the last payday
    proRata = true,
    wages = {
        police = { default = 45, [0] = 45, [1] = 55, [2] = 65, [3] = 80, [4] = 95, [5] = 110, [6] = 95,
                   [7] = 120, [8] = 120, [9] = 130, [10] = 130, [11] = 150, [12] = 160 },
        lawyer = { default = 40, [0] = 40, [1] = 55, [2] = 75, [3] = 100, [4] = 140, [5] = 200, [6] = 300 },
    },
}
