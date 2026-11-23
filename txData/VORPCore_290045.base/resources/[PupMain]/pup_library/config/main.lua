-- pup_library | settings shared by the client and the server.
-- Webhook addresses do NOT live here: set them in server/config.lua.

Config = {}

-- Libraries: a blip, and a press-to-open prompt at each position.
Config.Libraries = {
    { name = 'Saint Denis Library', pos = vector3(2754.78, -1237.16, 49.4) },
    { name = 'Strawberry Library',  pos = vector3(-1775.56, -399.92, 156.46) },
    { name = 'Blackwater Library',  pos = vector3(-790.6, -1287.8, 43.6) },
    { name = 'Valentine Library',   pos = vector3(-303.4, 777.24, 118.76) },
}

Config.Blip = {
    sprite = 587827268,
    style  = 1664425300,
    scale  = 0.8,
}

Config.Prompt = {
    distance = 2.5,         -- metres
    key      = 0x760A9C6F,  -- G
    nearScan = 5.0,         -- metres
    farScanMs = 500,        -- ms
}

Config.ReachDistance = 10.0 -- metres
Config.PassAtWorldOrigin = true -- no OneSync: true = allow, false = refuse

-- Works ---------------------------------------------------------------------
Config.Works = {
    { item = 'book',       label = 'Book' },
    { item = 'newspaper1', label = 'Newspaper' },
    { item = 'magazine',   label = 'Magazine' },
    { item = 'letter',     label = 'Letter' },
    { item = 'contract',   label = 'Contract' },
}
Config.DefaultWork = 'book' -- used when a stored kind is unknown
Config.SharedUsableItems = { book = true } -- left registered on stop

Config.MaxBytes      = 524288 -- bytes (512 KB) per saved book
Config.MaxPages      = 200
Config.NewBookPages  = 3
Config.TitleMax      = 50  -- characters
Config.AuthorMax     = 50  -- characters
Config.ReasonMax     = 200 -- characters

-- Jobs ------------------------------------------------------------------------
Config.StaffJobs        = { 'newspaper' }
Config.StaffOnlyLibrary = false -- true: only staff may open or use a library

-- Creation
Config.CreatePrice     = 50
Config.StaffCreateFree = true

-- Printing
Config.PrintPrice      = 1
Config.StaffPrintFree  = true  -- staff print at $0 even when StaffCreateFree is off
Config.MaxCopies       = 25
Config.PrintStaffOnly  = false
Config.PrintAuthorOnly = true

-- Publishing
Config.PublishJob      = 'newspaper'
Config.PublishMinGrade = 3
Config.ApplicationFee  = 50     -- paid into the publishing job's ledger
Config.MaxSalePrice    = 500
Config.LedgerIntegration = true -- pup_business AddToLedger
Config.LedgerReason    = 'Publishing application'

-- Discord
Config.Discord = {
    username = 'pup_library',
    avatar   = '',          -- empty = Discord's default picture
    colours  = {
        application = 15105570,
        published   = 3066993,
        removed     = 15158332,
    },
}

-- Timings ---------------------------------------------------------------------
Config.ServerReplyTimeout = 5000   -- ms
Config.UnstuckHoldMs      = 1000   -- ms
Config.LatentRate         = 250000 -- bytes per second
Config.PageTurnMs         = 650
Config.ScenarioRetryMs    = 1000
Config.Scenario           = 'WORLD_HUMAN_WRITE_NOTEBOOK'

Config.Notify = { -- ms
    default  = 5000,
    refusal  = 8000,
    saved    = 3000,
    unstuck  = 4000,
    noJob    = 6000,
}

Config.RequestGapMs = 700

-- Writer choices --------------------------------------------------------------
Config.Writer = {
    fonts = {
        { label = 'Georgia',            stack = 'Georgia, serif' },
        { label = 'Times New Roman',    stack = 'Times New Roman, serif' },
        { label = 'Palatino',           stack = 'Palatino Linotype, Palatino, serif' },
        { label = 'Book Antiqua',       stack = 'Book Antiqua, serif' },
        { label = 'Courier New',        stack = 'Courier New, monospace' },
        { label = 'Lucida Handwriting', stack = 'Lucida Handwriting, cursive' },
        { label = 'Segoe Script',       stack = 'Segoe Script, cursive' },
        { label = 'Arial',              stack = 'Arial, sans-serif' },
    },
    sizes = { 12, 14, 16, 18, 20, 24, 28, 36, 48, 72 },
    ink = { '#2b1d0e', '#5b3a1e', '#8a1c1c', '#a8551a', '#24452b', '#1d3557', '#4a2c5a', '#6b6256', '#000000', '#ffffff' },
    highlight = { '#e8c37a', '#e3a96b', '#d98f8f', '#a9c48f', '#9db8cf', '#c2a8d1', '#ffffff' },
}

-- Nothing to edit below this line -----------------------------------------------
Config.WorkByItem = {}
for _, w in ipairs(Config.Works) do Config.WorkByItem[w.item] = w end

function Config.IsWork(item)
    return type(item) == 'string' and Config.WorkByItem[item] ~= nil
end

function Config.IsStaffJob(job)
    if type(job) ~= 'string' or job == '' then return false end
    for _, j in ipairs(Config.StaffJobs) do
        if j == job then return true end
    end
    return false
end

function Config.IsPublisherJob(job, grade)
    return type(job) == 'string' and job ~= '' and job == Config.PublishJob
        and (tonumber(grade) or 0) >= Config.PublishMinGrade
end

function Config.Round2(n)
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    local sign = n < 0 and -1 or 1
    return sign * math.floor(math.abs(n) * 100 + 0.5) / 100
end

-- "$3" when whole, "$12.50" otherwise
function Config.Money(n)
    n = Config.Round2(n) or 0
    if n == math.floor(n) then return ('$%d'):format(math.floor(n)) end
    return ('$%.2f'):format(n)
end
