-- pup_business | the business list, rank cache and ledger-side caches

Biz = {}         -- [job] = business row (cleaned)
Ranks = {}       -- [job][grade] = { salary, perms = {k=bool}, tax, taxperiod, taxsince }
LedgerInfo = {}  -- [job] = { webhook = url or '', invaccess = n }
BizLoaded = false

local function decodeJson(s, fallback)
    if type(s) ~= 'string' or s == '' then return fallback end
    local ok, v = pcall(json.decode, s)
    if ok and v ~= nil then return v end
    return fallback
end

function DecodePerms(s)
    local raw = decodeJson(s, {})
    local out = {}
    for _, k in ipairs(PB.PERM_KEYS) do out[k] = type(raw) == 'table' and raw[k] == true or false end
    return out
end

function EncodePerms(p)
    local out = {}
    for _, k in ipairs(PB.PERM_KEYS) do out[k] = type(p) == 'table' and p[k] == true or false end
    return json.encode(out)
end

function AllPerms()
    local out = {}
    for _, k in ipairs(PB.PERM_KEYS) do out[k] = true end
    return out
end

local function rowToBiz(r)
    return {
        job = r.job,
        name = r.name or '',
        blipsprite = tonumber(r.blipsprite) or Config.DefaultBlipSprite,
        showblip = PB.bool(r.showblip),
        recruitmentrank = PB.int(r.recruitmentrank) or 0,
        bossrank = math.max(1, PB.int(r.bossrank) or 1),
        containerid = PB.int(r.containerid),
        containername = (r.containername and r.containername ~= '') and r.containername or 'Storage',
        billing = PB.bool(r.billing),
        webhook = PB.bool(r.webhook),
        salary = PB.bool(r.salary),
        tax = PB.bool(r.tax),
        positions = PB.points(decodeJson(r.positions, {})),
        jobmenu = PB.points(decodeJson(r.jobmenu, {})),
        created_by = r.created_by,
    }
end

function DisplayName(job)
    local b = Biz[job]
    if not b then return nil end
    return (b.name ~= '' and b.name) or b.job
end

function LoadBusinesses()
    local rows = MySQL.query.await('SELECT * FROM society_business') or {}
    local biz = {}
    for _, r in ipairs(rows) do
        if type(r.job) == 'string' and r.job ~= '' then biz[r.job] = rowToBiz(r) end
    end

    local ranks = {}
    local rrows = MySQL.query.await('SELECT job, grade, salary, perms, tax, taxperiod, taxsince FROM society_ranks') or {}
    for _, r in ipairs(rrows) do
        local g = PB.int(r.grade)
        if r.job and g then
            ranks[r.job] = ranks[r.job] or {}
            ranks[r.job][g] = {
                salary = PB.int(r.salary) or 0,
                perms = DecodePerms(r.perms),
                tax = math.max(0, PB.int(r.tax) or 0),
                taxperiod = PB.period(r.taxperiod),
                taxsince = PB.int(r.taxsince) or 0,
            }
        end
    end

    local info = {}
    local lrows = MySQL.query.await('SELECT job, webhook, invaccess FROM society_ledger') or {}
    for _, r in ipairs(lrows) do
        if type(r.job) == 'string' and not info[r.job] then
            info[r.job] = { webhook = type(r.webhook) == 'string' and r.webhook or '', invaccess = PB.int(r.invaccess) or 0 }
        end
    end

    Biz, Ranks, LedgerInfo = biz, ranks, info
end

-- every grade 0..boss gets a rank row; salary comes from the legacy table
function ReconcileRanks()
    for job, b in pairs(Biz) do
        Ranks[job] = Ranks[job] or {}
        for g = 0, b.bossrank do
            if not Ranks[job][g] then
                local legacy = MySQL.scalar.await('SELECT salary FROM society WHERE job = ? AND jobgrade = ? LIMIT 1', { job, g })
                local salary = PB.int(legacy) or 0
                local perms = g >= b.bossrank and AllPerms() or {}
                MySQL.insert.await(
                    'INSERT IGNORE INTO society_ranks (job, grade, salary, perms, tax, taxperiod, taxsince) VALUES (?, ?, ?, ?, 0, ?, 0)',
                    { job, g, salary, EncodePerms(perms), 'weekly' })
                Ranks[job][g] = { salary = salary, perms = DecodePerms(EncodePerms(perms)), tax = 0, taxperiod = 'weekly', taxsince = 0 }
            end
        end
    end
end

function RankOf(job, grade)
    local r = Ranks[job] and Ranks[job][grade]
    return r
end

function IsBossGrade(job, grade)
    local b = Biz[job]
    return b ~= nil and (tonumber(grade) or 0) >= b.bossrank
end

-- stored flags of a grade; the boss grade always holds all eight
function RankPerms(job, grade)
    if IsBossGrade(job, grade) then return AllPerms() end
    local r = RankOf(job, grade)
    local out = {}
    for _, k in ipairs(PB.PERM_KEYS) do out[k] = r ~= nil and r.perms[k] == true end
    return out
end

function HasRankPerm(job, grade, key)
    return RankPerms(job, grade)[key] == true
end

-- what the client is told it may do
function EffectivePerms(job, grade, admin)
    if admin or IsBossGrade(job, grade) then return AllPerms() end
    local p = RankPerms(job, grade)
    local b = Biz[job]
    if b and (tonumber(grade) or 0) >= b.recruitmentrank then
        p.hire, p.fire, p.setranks = true, true, true
    end
    return p
end

-- recruiter grade or the given permission
function CanRecruit(job, grade, key)
    local b = Biz[job]
    if not b then return false end
    grade = tonumber(grade) or 0
    return grade >= b.recruitmentrank or HasRankPerm(job, grade, key)
end

function StashAccessGrade(job)
    return (LedgerInfo[job] and LedgerInfo[job].invaccess) or 0
end

-- what every client needs to draw blips, prompts and menus
local function publicList()
    local out = {}
    for job, b in pairs(Biz) do
        out[#out + 1] = {
            job = job,
            name = DisplayName(job),
            showblip = b.showblip,
            blipsprite = b.blipsprite,
            positions = b.positions,
            jobmenu = b.jobmenu,
            bossrank = b.bossrank,
            recruitmentrank = b.recruitmentrank,
            billing = b.billing,
            salary = b.salary,
            invaccess = StashAccessGrade(job),
        }
    end
    table.sort(out, function(a, b) return a.job < b.job end)
    return out
end

function PushBusinesses(target)
    TriggerClientEvent('pup_business:businesses', target or -1, publicList())
end

function RefreshMercantile()
    if GetResourceState('pup_mercantile') ~= 'started' then return end
    pcall(function() exports.pup_mercantile:RefreshSocietyBossRanks() end)
end

function ReloadAndPush()
    LoadBusinesses()
    ReconcileRanks()
    PushBusinesses(-1)
    RefreshMercantile()
end

-- wait (in a thread) until the first load is done; false after `ms`
function WaitLoaded(ms)
    local untilAt = GetGameTimer() + (ms or 5000)
    while not BizLoaded do
        if GetGameTimer() > untilAt then return false end
        Wait(100)
    end
    return true
end

function BusinessOfContainer(id)
    id = tonumber(id)
    if not id then return nil end
    for job, b in pairs(Biz) do
        if b.containerid == id then return job end
    end
    return nil
end
