-- pup-gangs | server/main.lua: authority for gangs, membership, ranks, points, territory and wars

local VorpCore = {}
TriggerEvent("getCore", function(core) VorpCore = core end)
if not VorpCore or not VorpCore.getUser then
    VorpCore = exports.vorp_core:GetCore()
end
local VorpInv = exports.vorp_inventory

local function dbg(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-gangs]^7 " .. table.concat(parts, " "))
end

-- DB helpers (global MySQL first, oxmysql fallback)
local function DBQuery(query, params)
    if _G.MySQL and _G.MySQL.query and _G.MySQL.query.await then
        return _G.MySQL.query.await(query, params or {})
    end
    return exports.oxmysql:query_async(query, params or {})
end

local function DBExec(query, params)
    if _G.MySQL and _G.MySQL.update then
        return _G.MySQL.update(query, params or {})
    end
    return exports.oxmysql:update(query, params or {})
end

local function DBInsert(query, params)
    if _G.MySQL and _G.MySQL.insert and _G.MySQL.insert.await then
        return _G.MySQL.insert.await(query, params or {})
    end
    return exports.oxmysql:insert_async(query, params or {})
end

-- State
local gangs       = {}  -- [gangid] = row
local members     = {}  -- [charid] = { gangid, rank, name }
local territories = {}  -- [id] = row
local wars        = {}  -- [id] = row
local invites     = {}  -- [charid] = { gangid, from, expires }
local factionPts  = {}  -- [factionKey] = accumulated season points

local function Char(src)
    local user = VorpCore.getUser(src)
    return user and user.getUsedCharacter or nil
end

local function notify(src, msg, dur)
    VorpCore.NotifyRightTip(src, msg, dur or 4000)
end

local function now() return os.time() end

-- THE COLOUR A GANG FLIES
local function gangColour(gang)
    local want = gang and tostring(gang.blipcolor or '') or ''
    if want == '' then want = Config.Colors.default or '' end
    for _, c in ipairs(Config.Colors.list or {}) do
        if c.key == want then return c end
    end
    return (Config.Colors.list or {})[1] or
        { key = 'grey', label = 'Grey', modifier = 'BLIP_MODIFIER_MP_COLOR_32', hex = '#8d8d8d' }
end

-- PER-GANG RANKS: every gang may define its own ladder - rank names and what each rank may do
local RANK_PERM_KEYS <const> = { 'invite', 'kick', 'promote', 'war', 'bank', 'territory' }

local function ranksFor(gang)
    if not gang then return Config.Ranks.list end
    if type(gang._ranks) == 'table' then return gang._ranks end
    if type(gang.ranks) == 'string' and gang.ranks ~= '' then
        local ok, decoded = pcall(json.decode, gang.ranks)
        if ok and type(decoded) == 'table' and #decoded >= 2 then
            gang._ranks = decoded
            return decoded
        end
    end
    return Config.Ranks.list
end

-- rank row for an index within a GANG's ladder, clamped into range
local function rankOfIn(gang, index)
    local list = ranksFor(gang)
    -- always a whole rank: the column is an INT, so 3.5 from a client would be saved as 4
    local i = math.floor(tonumber(index) or 1)
    if i ~= i or i < 1 then i = 1 end
    if i > #list then i = #list end
    return list[i], i
end

local function topRankIndex(gang) return #ranksFor(gang) end

-- does this character's rank allow `perm` in their gang?
local function can(charid, perm)
    local m = members[charid]
    if not m then return false end
    local gang = gangs[m.gangid]
    -- the leader can do everything, whatever the ladder says
    if gang and tonumber(gang.leader) == tonumber(charid) then return true end
    local rank = rankOfIn(gang, m.rank)
    return rank and rank[perm] == true
end

-- tell a gang's own members to re-pull their panel. Every client that gets this runs
-- getPanel and its queries, so it does not go to players outside the gang.
function GangRefreshCrew(gangid)
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local ch = s and Char(s)
        local m = ch and members[ch.charIdentifier]
        if m and m.gangid == gangid then TriggerClientEvent('pup-gangs:refresh', s) end
    end
end

-- free edits (rank editor, drug icon) write to the database and refresh the crew: five per five seconds, per player
local recentEdits = {}
function GangEditAllowed(src)
    local t, e = GetGameTimer(), recentEdits[src]
    if not e or t - e.at >= 5000 then
        recentEdits[src] = { at = t, n = 1 }
        return true
    end
    e.n = e.n + 1
    return e.n <= 5
end

-- POINTS -> RADIUS
local function radiusFor(points)
    local map = Config.Map
    points = tonumber(points) or 0
    if type(map.radiusCurve) == 'table' and #map.radiusCurve > 0 then
        local r = map.radiusCurve[1].radius or map.baseRadius
        for _, step in ipairs(map.radiusCurve) do
            if points >= (tonumber(step.points) or 0) then r = tonumber(step.radius) or r end
        end
        return math.min(r, map.maxRadius)
    end
    local steps = math.floor(points / math.max(1, map.pointsPerStep or 100))
    return math.min(map.baseRadius + steps * (map.radiusPerStep or 25.0), map.maxRadius)
end

-- the NEXT influence step: how many points away, and what radius it brings. nil when the curve is topped out
local function nextRadiusStep(points)
    points = tonumber(points) or 0
    for _, step in ipairs(Config.Map.radiusCurve or {}) do
        if points < (tonumber(step.points) or 0) then
            return step.points - points, tonumber(step.radius) or 0
        end
    end
    return nil
end

-- FACTION STANDINGS - every point a gang earns ALSO scores for the faction it reps
local function addFactionPoints(factionKey, amount)
    if not factionKey or not Config.Factions.list[factionKey] then return end
    local gain = math.floor(tonumber(amount) or 0)
    if gain <= 0 then return end
    factionPts[factionKey] = (factionPts[factionKey] or 0) + gain
    DBExec([[INSERT INTO gang_factions (faction, points, updated_at) VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE points = VALUES(points), updated_at = VALUES(updated_at)]],
        { factionKey, factionPts[factionKey], now() })
end

-- LIVE strength alongside the season score: how many gangs each faction fields right now, their combined points
local function factionStandings()
    local out, ranked = {}, {}
    for key, f in pairs(Config.Factions.list) do
        out[key] = {
            key = key, label = f.label, blurb = f.blurb,
            color = f.colorModifier,
            season = factionPts[key] or 0,
            gangs = 0, livePoints = 0, territories = 0,
        }
    end
    for _, g in pairs(gangs) do
        local row = out[g.faction]
        if row then
            row.gangs = row.gangs + 1
            row.livePoints = row.livePoints + (g.points or 0)
        end
    end
    for _, t in pairs(territories) do
        local g = t.gangid and gangs[t.gangid] or nil
        if g and out[g.faction] then out[g.faction].territories = out[g.faction].territories + 1 end
    end
    for _, key in ipairs(Config.Factions.order) do
        if out[key] then ranked[#ranked + 1] = out[key] end
    end
    table.sort(ranked, function(a, b) return (a.season or 0) > (b.season or 0) end)
    for i, row in ipairs(ranked) do row.place = i end
    return ranked
end

VorpCore.Callback.Register('pup-gangs:getFactions', function(source, cb)
    cb(factionStandings())
end)

exports('GetFactionStandings', factionStandings)

-- POINT LEDGER: every activity row can carry the point delta it represents (+75 Bank Robbery, -10 Inactivity...)
local function logActivity(gangid, kind, detail, actor, pts)
    DBExec('INSERT INTO gang_activity (gangid, ts, type, detail, actor, pts) VALUES (?, ?, ?, ?, ?, ?)',
        { gangid, now(), tostring(kind), tostring(detail or ''), tostring(actor or ''), math.floor(tonumber(pts) or 0) })
end

-- GANG STATISTICS - lifetime counters (robberies, heists, missions, wars)
local function gangStats(g)
    if type(g.stats) ~= 'table' then
        local ok, decoded = pcall(json.decode, tostring(g.stats or ''))
        g.stats = (ok and type(decoded) == 'table') and decoded or {}
    end
    return g.stats
end

local function bumpStat(g, key, n)
    local s = gangStats(g)
    s[key] = (tonumber(s[key]) or 0) + (tonumber(n) or 1)
    DBExec('UPDATE gangs SET stats = ? WHERE id = ?', { json.encode(s), g.id })
end

-- points earned (positive ledger rows only) in the last `days` - one grouped query for every gang at once
local function earnedSince(days)
    local since = now() - math.floor(days * 86400)
    local out = {}
    for _, row in ipairs(DBQuery(
        'SELECT gangid, SUM(pts) AS earned FROM gang_activity WHERE ts >= ? AND pts > 0 GROUP BY gangid',
        { since }) or {}) do
        out[tonumber(row.gangid)] = tonumber(row.earned) or 0
    end
    return out
end

local function activityScore(weeklyEarned)
    local a = Config.Activity or {}
    weeklyEarned = tonumber(weeklyEarned) or 0
    if weeklyEarned >= (a.highWeekly or 300) then return 'HIGH' end
    if weeklyEarned >= (a.mediumWeekly or 75) then return 'MEDIUM' end
    return 'LOW'
end

-- SHORT NAMES ("VPR") - uppercase A-Z/0-9, unique, shown on blips and the directory
local function sanitizeShort(s)
    s = tostring(s or ''):upper():gsub('[^A-Z0-9]', '')
    return s
end

local function shortNameTaken(short, exceptGangId)
    for _, g in pairs(gangs) do
        if g.id ~= exceptGangId and tostring(g.shortname or ''):upper() == short then return true end
    end
    return false
end

-- derive a unique tag from a gang's full name (existing gangs get one on boot)
local function deriveShort(name, gangid)
    local initials = ''
    for word in tostring(name or ''):gmatch('%S+') do
        local c = word:sub(1, 1):upper()
        if c:match('[A-Z0-9]') then initials = initials .. c end
    end
    local base = sanitizeShort(initials)
    if #base < Config.Creation.minShortLength then
        base = sanitizeShort(tostring(name or '')):sub(1, math.max(Config.Creation.minShortLength, 3))
    end
    if base == '' then base = 'G' .. tostring(gangid or 0) end
    base = base:sub(1, Config.Creation.maxShortLength)
    if not shortNameTaken(base, gangid) then return base end
    for i = 2, 99 do
        local try = (base:sub(1, Config.Creation.maxShortLength - #tostring(i))) .. tostring(i)
        if not shortNameTaken(try, gangid) then return try end
    end
    return ('G' .. tostring(gangid or 0)):sub(1, Config.Creation.maxShortLength)
end

-- Cache load
local function loadAll()
    gangs, members, territories, wars = {}, {}, {}, {}

    for _, row in ipairs(DBQuery('SELECT * FROM gangs') or {}) do
        row.id = tonumber(row.id)
        row.points = tonumber(row.points) or 0
        gangs[row.id] = row
    end

    for _, row in ipairs(DBQuery('SELECT * FROM gang_members') or {}) do
        members[tonumber(row.charid)] = {
            gangid = tonumber(row.gangid),
            rank   = tonumber(row.rank) or 1,
            name   = row.name or '',
        }
    end

    for _, row in ipairs(DBQuery('SELECT * FROM gang_territories') or {}) do
        row.id = tonumber(row.id)
        row.gangid = tonumber(row.gangid) -- nil stays nil (unclaimed)
        territories[row.id] = row
    end

    for _, row in ipairs(DBQuery("SELECT * FROM gang_wars WHERE status = 'active'") or {}) do
        row.id = tonumber(row.id)
        wars[row.id] = row
    end

    factionPts = {}
    for key in pairs(Config.Factions.list) do factionPts[key] = 0 end
    for _, row in ipairs(DBQuery('SELECT faction, points FROM gang_factions') or {}) do
        factionPts[row.faction] = tonumber(row.points) or 0
    end

    local g, m, t, w = 0, 0, 0, 0
    for _ in pairs(gangs) do g = g + 1 end
    for _ in pairs(members) do m = m + 1 end
    for _ in pairs(territories) do t = t + 1 end
    for _ in pairs(wars) do w = w + 1 end
    print(("^2[pup-gangs]^7 loaded %d gang(s), %d member(s), %d territory(ies), %d active war(s)")
        :format(g, m, t, w))
end

CreateThread(function()
    Wait(2000)
    -- schema upgrades (MariaDB IF NOT EXISTS)
    DBExec("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS shortname VARCHAR(8) NOT NULL DEFAULT ''")
    DBExec("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS stats LONGTEXT NULL")
    DBExec("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS ranks LONGTEXT NULL") -- per-gang rank ladder
    DBExec("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS blipcolor VARCHAR(16) NOT NULL DEFAULT ''") -- the colour they fly
    DBExec("ALTER TABLE gang_activity ADD COLUMN IF NOT EXISTS pts INT NOT NULL DEFAULT 0")
    Wait(500)
    loadAll()
    -- backfill: every existing gang gets a unique tag derived from its name, so the map and directory are never showing blanks
    for _, g in pairs(gangs) do
        if sanitizeShort(g.shortname) == '' then
            g.shortname = deriveShort(g.name, g.id)
            DBExec('UPDATE gangs SET shortname = ? WHERE id = ?', { g.shortname, g.id })
            dbg('backfilled shortname', g.name, '->', g.shortname)
        else
            g.shortname = sanitizeShort(g.shortname)
        end
    end
end)

-- MAP PAYLOAD
local function territoryPayload(forCharid)
    local mine = members[forCharid] and members[forCharid].gangid or nil

    -- TERRITORY IS FOR GANG MEMBERS ONLY
    if not mine then return {} end

    -- FACTION SECRECY: rivals never receive the faction fields
    local function factionFields(gang, isMine)
        local colour = gangColour(gang)
        if not gang then return nil, nil, colour.modifier, colour.hex end
        if Config.Factions.hidden and not isMine then
            return nil, nil, colour.modifier, colour.hex
        end
        local f = Config.Factions.list[gang.faction]
        return gang.faction, f and f.label or gang.faction, colour.modifier, colour.hex
    end

    local out = {}
    for _, t in pairs(territories) do
        local gang = t.gangid and gangs[t.gangid] or nil
        local isMine = gang ~= nil and gang.id == mine
        if Config.Map.showRivalTerritory or isMine or gang == nil then
            local fkey, flabel, fcolor, fhex = factionFields(gang, isMine)
            out[#out + 1] = {
                id      = t.id,
                name    = t.name,
                x       = tonumber(t.x) or 0.0,
                y       = tonumber(t.y) or 0.0,
                z       = tonumber(t.z) or 0.0,
                gangid  = gang and gang.id or nil,
                gang    = gang and gang.name or nil,
                short   = gang and gang.shortname or nil,
                faction = fkey,
                factionLabel = flabel,
                color   = fcolor,
                hex     = fhex,   -- the gang's chosen colour, for the panel map
                radius  = gang and radiusFor(gang.points) or Config.Map.baseRadius,
                mine    = isMine,
                points  = gang and gang.points or 0,
            }
        end
    end

    -- every gang with an HQ shows on the map: its influence circle sits around the gang table
    for gid, t in pairs(GANG_TABLES or {}) do
        local gang = gangs[gid]
        if gang then
            local isMine = gang.id == mine
            if Config.Map.showRivalTerritory or isMine then
                local fkey, flabel, fcolor, fhex = factionFields(gang, isMine)
                out[#out + 1] = {
                    id      = 'hq' .. tostring(gid),
                    hq      = true,
                    name    = (gang.shortname and gang.shortname ~= '' and gang.shortname or gang.name) .. ' HQ',
                    x       = tonumber(t.x) or 0.0,
                    y       = tonumber(t.y) or 0.0,
                    z       = tonumber(t.z) or 0.0,
                    gangid  = gang.id,
                    gang    = gang.name,
                    short   = gang.shortname or '',
                    faction = fkey,
                    factionLabel = flabel,
                    color   = fcolor,
                    hex     = fhex,
                    radius  = radiusFor(gang.points),
                    mine    = isMine,
                    points  = gang.points or 0,
                }
            end
        end
    end
    return out
end

VorpCore.Callback.Register('pup-gangs:getTerritories', function(source, cb)
    local ch = Char(source)
    if not ch then return cb({}) end
    cb(territoryPayload(ch.charIdentifier))
end)

-- PANEL DATA
VorpCore.Callback.Register('pup-gangs:getPanel', function(source, cb)
    local ch = Char(source)
    if not ch then return cb(false) end
    local charid = ch.charIdentifier
    local m = members[charid]

    -- no gang: the panel shows the creation form instead
    if not m or not gangs[m.gangid] then
        local factions = {}
        for _, key in ipairs(Config.Factions.order) do
            local f = Config.Factions.list[key]
            if f then
                factions[#factions + 1] = {
                    key = key, label = f.label, blurb = f.blurb,
                    bonus = f.bonus and f.bonus.label or '',
                }
            end
        end
        return cb({
            hasGang  = false,
            factions = factions,
            price    = Config.Creation.price,
            money    = math.floor(tonumber(ch.money) or 0),
        })
    end

    local gang = gangs[m.gangid]
    -- same leader rule as the roster below: the boss reads as the top of their own ladder
    local meLeader <const> = tonumber(gang.leader) == tonumber(charid)
    local rank, rankIndex = rankOfIn(gang, meLeader and topRankIndex(gang) or m.rank)

    local roster = {}
    for _, row in ipairs(DBQuery('SELECT * FROM gang_members WHERE gangid = ? ORDER BY rank DESC, name ASC', { gang.id }) or {}) do
        -- THE LEADER IS ALWAYS THE TOP OF THEIR OWN LADDER
        local isLeader <const> = tonumber(row.charid) == tonumber(gang.leader)
        local r = rankOfIn(gang, isLeader and topRankIndex(gang) or row.rank)
        roster[#roster + 1] = {
            charid = tonumber(row.charid),
            name   = row.name,
            rank   = tonumber(row.rank) or 1,
            rankLabel = r and r.label or '?',
            points = tonumber(row.points) or 0,
            isLeader = isLeader,
        }
    end

    local myTerritories = {}
    for _, t in pairs(territories) do
        if t.gangid == gang.id then
            myTerritories[#myTerritories + 1] = { id = t.id, name = t.name }
        end
    end

    local myWars = {}
    for _, w in pairs(wars) do
        if w.gang_a == gang.id or w.gang_b == gang.id then
            local otherId = (w.gang_a == gang.id) and w.gang_b or w.gang_a
            local other = gangs[otherId]
            myWars[#myWars + 1] = {
                id      = w.id,
                enemy   = other and other.name or ('gang ' .. tostring(otherId)),
                mine    = (w.gang_a == gang.id) and w.score_a or w.score_b,
                theirs  = (w.gang_a == gang.id) and w.score_b or w.score_a,
                endsIn  = math.max(0, (tonumber(w.endts) or 0) - now()),
            }
        end
    end

    -- gangs a war can be declared on
    local rivals = {}
    for _, g in pairs(gangs) do
        if g.id ~= gang.id then
            if Config.Factions.hidden or Config.Wars.allowSameFaction or g.faction ~= gang.faction then
                rivals[#rivals + 1] = {
                    id = g.id, name = g.name, short = g.shortname or '',
                    faction = (not Config.Factions.hidden) and g.faction or nil,
                    points = g.points,
                }
            end
        end
    end

    local activity = DBQuery('SELECT ts, type, detail, actor, pts FROM gang_activity WHERE gangid = ? ORDER BY id DESC LIMIT 25', { gang.id }) or {}

    -- level/perks come from server/features.lua (same Lua state, loaded after us)
    local levelInfo = GangLevelInfo and GangLevelInfo(gang.points) or nil
    -- OFFERED at this level. With Config.Blood.perksNeedBuying on, that is not
    -- the same as HELD, so perkOwned below is the one the panel colours by.
    local perkFlags = {}
    if levelInfo and levelInfo.perks then
        for _, flag in ipairs(levelInfo.perks.unlocks or {}) do perkFlags[flag] = true end
    end
    local perkOwned = {}
    for flag in pairs(Config.Perks.labels or {}) do
        if GangHasPerk and GangHasPerk(gang, flag) then perkOwned[flag] = true end
    end
    local hasTable = (GANG_TABLES ~= nil) and (GANG_TABLES[gang.id] ~= nil) or false

    -- recent earnings power the activity score + the "earned today / this week" stats
    local earnedRow = (DBQuery([[SELECT
            SUM(CASE WHEN ts >= ? THEN pts ELSE 0 END) AS today,
            SUM(pts) AS week
        FROM gang_activity WHERE gangid = ? AND ts >= ? AND pts > 0]],
        { now() - 86400, gang.id, now() - 7 * 86400 }) or {})[1] or {}
    local weekEarned = tonumber(earnedRow.week) or 0

    local stepAway, stepRadius = nextRadiusStep(gang.points)

    local faction = Config.Factions.list[gang.faction]
    cb({
        hasGang    = true,
        level      = levelInfo and levelInfo.level or 1,
        levelLabel = levelInfo and levelInfo.label or '',
        levelNextAt = levelInfo and levelInfo.nextAt or nil,
        levelNextLabel = levelInfo and levelInfo.nextLabel or nil,
        perkList   = levelInfo and levelInfo.perks or nil,
        perkFlags  = perkFlags,
        perkOwned  = perkOwned,
        hasTable   = hasTable,
        id         = gang.id,
        name       = gang.name,
        shortname  = gang.shortname or '',
        stats      = gangStats(gang),
        activityScore = activityScore(weekEarned),
        earnedToday = tonumber(earnedRow.today) or 0,
        earnedWeek  = weekEarned,
        motd       = gang.motd or '',
        points     = gang.points,
        money      = tonumber(gang.money) or 0,
        faction    = gang.faction,
        factionLabel = faction and faction.label or gang.faction,
        factionBonus = faction and faction.bonus and faction.bonus.label or '',
        radius     = radiusFor(gang.points),
        nextStepIn = stepAway,          -- nil = influence maxed
        nextStepRadius = stepRadius,
        myRank     = rankIndex,
        myRankLabel = rank and rank.label or '?',
        isLeader   = tonumber(gang.leader) == tonumber(charid),
        ranks      = ranksFor(gang), -- this GANG's ladder (labels + permissions)
        blipcolor  = gangColour(gang).key,
        blipHex    = gangColour(gang).hex,
        perms      = {
            invite = can(charid, 'invite'), kick = can(charid, 'kick'),
            promote = can(charid, 'promote'), war = can(charid, 'war'),
            bank = can(charid, 'bank'), territory = can(charid, 'territory'),
        },
        members    = roster,
        -- Effective cap: base + this level's extra slots (10 -> 20 across the ladder) + any slots BOUGHT with blood money
        maxMembers = Config.Creation.maxMembers > 0
            and (Config.Creation.maxMembers
                 + (levelInfo and levelInfo.perks and tonumber(levelInfo.perks.members) or 0)
                 + ((GangBoughtSlots and GangBoughtSlots(gang)) or 0))
            or 0,
        territories = myTerritories,
        wars       = myWars,
        rivals     = rivals,
        activity   = activity,
        now        = now(),
    })
end)

-- CREATE
local founding = {} -- [charid] = true while their gang row is being inserted

RegisterNetEvent('pup-gangs:create', function(name, faction, shortname)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier

    if members[charid] then return notify(_source, Locale.alreadyInGang) end
    if founding[charid] then return end

    -- the name goes into item descriptions and other players' UIs, so no markup
    name = tostring(name or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #name < Config.Creation.minNameLength or #name > Config.Creation.maxNameLength then
        return notify(_source, Locale.nameLength)
    end
    if not Config.Factions.list[faction] then return end

    -- the tag: uppercase A-Z/0-9, right length, unique
    local short = sanitizeShort(shortname)
    if #short < Config.Creation.minShortLength or #short > Config.Creation.maxShortLength then
        short = ''
    end
    if short ~= '' and shortNameTaken(short, nil) then
        return notify(_source, Locale.shortTaken or 'That short name is already taken.')
    end

    for _, g in pairs(gangs) do
        if g.name:lower() == name:lower() then return notify(_source, Locale.nameTaken) end
    end

    -- the table is the door: a gang is founded at a gang table the founder placed
    local ftable = GangUnfoundedTable and GangUnfoundedTable(charid) or nil
    if not ftable then return notify(_source, Locale.needTableToFound, 8000) end
    local ped = GetPlayerPed(_source)
    local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
    if not pc or #(vector3(pc.x, pc.y, pc.z) - vector3((tonumber(ftable.x) or 0) + 0.0, (tonumber(ftable.y) or 0) + 0.0, (tonumber(ftable.z) or 0) + 0.0)) > 6.0 then
        return notify(_source, Locale.standAtTable, 8000)
    end

    if (tonumber(ch.money) or 0) < Config.Creation.price then
        return notify(_source, Locale.nomoney)
    end
    if Config.Creation.item then
        local count = VorpInv:getItemCount(_source, nil, Config.Creation.item) -- (source, cb, item)
        if (tonumber(count) or 0) < 1 then return notify(_source, Locale.nomoney) end
        VorpInv:subItem(_source, Config.Creation.item, 1)
    end
    ch.removeCurrency(0, Config.Creation.price)

    -- the insert yields, so a second request in that gap would pay and found again
    founding[charid] = true
    local okInsert, id = pcall(DBInsert,
        'INSERT INTO gangs (name, faction, leader, points, money, created_at, last_activity) VALUES (?, ?, ?, 0, 0, ?, ?)',
        { name, faction, charid, now(), now() })
    founding[charid] = nil
    if not okInsert or not id then
        ch.addCurrency(0, Config.Creation.price)
        return notify(_source, 'Could not create the gang.')
    end

    gangs[id] = { id = id, name = name, faction = faction, leader = charid, points = 0, money = 0, motd = '', created_at = now(), last_activity = now() }
    if short == '' then short = deriveShort(name, id) end
    gangs[id].shortname = short
    DBExec('UPDATE gangs SET shortname = ? WHERE id = ?', { short, id })

    local top = topRankIndex()
    DBExec('INSERT INTO gang_members (gangid, charid, name, rank, points, joined_at) VALUES (?, ?, ?, ?, 0, ?)',
        { id, charid, ch.firstname .. ' ' .. ch.lastname, top, now() })
    members[charid] = { gangid = id, rank = top, name = ch.firstname .. ' ' .. ch.lastname }

    -- the founding table becomes THE gang table - HQ established where they stand
    if GangBindTable then GangBindTable(charid, id) end

    logActivity(id, 'founded', ('%s founded under %s'):format(name, faction), ch.firstname .. ' ' .. ch.lastname)
    dbg('gang created', id, name, faction, 'by', charid)
    notify(_source, Locale.created)
    TriggerClientEvent('pup-gangs:refresh', _source)
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
end)

-- MEMBERSHIP
-- EFFECTIVE cap = base + the level perk's extra slots + slots BOUGHT with blood money (server/blood.lua)
local function gangIsFull(gang)
    if Config.Creation.maxMembers <= 0 then return false end
    local perks = GangPerks and GangPerks(gang.points) or nil
    local bought = (GangBoughtSlots and GangBoughtSlots(gang)) or 0
    local cap = Config.Creation.maxMembers + (perks and tonumber(perks.members) or 0) + bought
    local count = 0
    for _, m in pairs(members) do if m.gangid == gang.id then count = count + 1 end end
    return count >= cap
end

RegisterNetEvent('pup-gangs:invite', function(targetId)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    if not can(charid, 'invite') then return notify(_source, Locale.notAllowed) end

    local gangid = members[charid].gangid
    local gang = gangs[gangid]
    if not gang then return end

    local target = tonumber(targetId)
    local tch = target and Char(target)
    if not tch then return notify(_source, 'That player is not online.') end
    if members[tch.charIdentifier] then return notify(_source, 'They are already in a gang.') end

    -- the real client invites the closest player within 5m
    local myPed, theirPed = GetPlayerPed(_source), GetPlayerPed(target)
    if not myPed or myPed == 0 or not theirPed or theirPed == 0
        or #(GetEntityCoords(myPed) - GetEntityCoords(theirPed)) > 25.0 then
        return notify(_source, 'That player is not nearby.')
    end

    if gangIsFull(gang) then return notify(_source, Locale.gangFull) end

    -- refuse the invite up front when the ledger cannot cover the new rider
    local joinCost <const> = (Config.Blood and Config.Blood.enabled)
        and (tonumber(Config.Blood.perMember) or 0) or 0
    if joinCost > 0 and (tonumber(gang.bloodmoney) or 0) < joinCost then
        return notify(_source, (Locale.bloodShort):format(joinCost, tonumber(gang.bloodmoney) or 0), 7000)
    end

    invites[tch.charIdentifier] = { gangid = gangid, from = charid, expires = now() + 60 }
    notify(_source, Locale.invited)
    notify(target, ('%s invited you to their gang - /gang to accept'):format(gang.name), 8000)
    TriggerClientEvent('pup-gangs:inviteReceived', target, { gangid = gangid, name = gang.name })
end)

RegisterNetEvent('pup-gangs:acceptInvite', function()
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local inv = invites[charid]
    if not inv or inv.expires < now() then
        invites[charid] = nil
        return notify(_source, 'That invite expired.')
    end
    invites[charid] = nil
    if members[charid] then return notify(_source, Locale.alreadyInGang) end
    local gang = gangs[inv.gangid]
    if not gang then return end
    -- an invite lasts 60 seconds, and several can be out at once
    if gangIsFull(gang) then return notify(_source, Locale.gangFull) end

    local fullname = ch.firstname .. ' ' .. ch.lastname

    -- a new rider costs blood money (Config.Blood.perMember)
    local cost <const> = (Config.Blood and Config.Blood.enabled)
        and (tonumber(Config.Blood.perMember) or 0) or 0
    if cost > 0 and GangBloodMove then
        local bal = GangBloodMove(gang, -cost, charid, fullname, 'member joined')
        if not bal then
            notify(_source, (Locale.bloodJoinShort):format(cost), 7000)
            -- tell the crew's leader too, if they are on. charSource lives in server/features.lua as a LOCAL
            for _, sid in ipairs(GetPlayers()) do
                local s = tonumber(sid)
                local c2 = s and Char(s)
                if c2 and tonumber(c2.charIdentifier) == tonumber(gang.leader) then
                    notify(s, (Locale.bloodJoinShortBoss):format(fullname, cost), 8000)
                    break
                end
            end
            return
        end
    end

    DBExec('INSERT INTO gang_members (gangid, charid, name, rank, points, joined_at) VALUES (?, ?, ?, 1, 0, ?)',
        { gang.id, charid, fullname, now() })
    members[charid] = { gangid = gang.id, rank = 1, name = fullname }
    logActivity(gang.id, 'joined', fullname .. ' joined', fullname)
    notify(_source, Locale.joined)
    TriggerClientEvent('pup-gangs:refresh', _source)
    -- territory is members-only, so joining must redraw the map for them at once
    TriggerClientEvent('pup-gangs:territoriesDirty', _source)
    -- the gang TABLE is members-only too: without this, a new member cannot see the table (prop or prompt) until they relog
    TriggerClientEvent('pup-gangs:tablesDirty', _source)
end)

RegisterNetEvent('pup-gangs:kick', function(targetCharid)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    if not can(charid, 'kick') then return notify(_source, Locale.notAllowed) end

    local gangid = members[charid].gangid
    local target = tonumber(targetCharid)
    local tm = target and members[target]
    if not tm or tm.gangid ~= gangid then return end
    if target == tonumber(gangs[gangid].leader) then return notify(_source, 'You cannot remove the boss.') end
    -- cannot act on an equal or higher rank
    if (tm.rank or 1) >= (members[charid].rank or 1) then return notify(_source, Locale.notAllowed) end

    DBExec('DELETE FROM gang_members WHERE charid = ?', { target })
    local nm = tm.name
    members[target] = nil
    logActivity(gangid, 'kicked', nm .. ' removed', ch.firstname .. ' ' .. ch.lastname)
    notify(_source, Locale.kicked)
    TriggerClientEvent('pup-gangs:refresh', _source)
    -- broadcast, not targeted: the kicked member may be offline, and the payload is gated per player anyway
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
    -- same rule for the table: the kicked member's client re-pulls, gets nothing, and the prop + prompt vanish for them
    TriggerClientEvent('pup-gangs:tablesDirty', -1)
end)

RegisterNetEvent('pup-gangs:setRank', function(targetCharid, newRank)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    if not can(charid, 'promote') then return notify(_source, Locale.notAllowed) end

    local myRank = members[charid].rank or 1
    local gangid = members[charid].gangid
    local gang = gangs[gangid]
    local target = tonumber(targetCharid)
    local tm = target and members[target]
    if not tm or tm.gangid ~= gangid then return end

    local _, want = rankOfIn(gang, newRank)
    -- never promote to or above your own rank, and never touch someone at/above you
    if want >= myRank or (tm.rank or 1) >= myRank then
        return notify(_source, Locale.notAllowed)
    end

    DBExec('UPDATE gang_members SET rank = ? WHERE charid = ?', { want, target })
    local up = want > (tm.rank or 1)
    tm.rank = want
    logActivity(gangid, up and 'promoted' or 'demoted', tm.name .. ' -> ' .. (rankOfIn(gang, want).label), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, up and Locale.promoted or Locale.demoted)
    TriggerClientEvent('pup-gangs:refresh', _source)
end)

-- BOSS RANK EDITOR: the leader designs the gang's own ladder
local function leaderGang(src)
    local ch = Char(src)
    if not ch then return nil end
    local m = members[ch.charIdentifier]
    if not m then return nil end
    local g = gangs[m.gangid]
    if not g then return nil end
    if tonumber(g.leader) ~= tonumber(ch.charIdentifier) then
        notify(src, Locale.notAllowed)
        return nil
    end
    return g, ch
end

-- editable deep copy of a gang's current ladder (only known keys survive)
local function rankListCopy(g)
    local list = {}
    for i, r in ipairs(ranksFor(g)) do
        list[i] = { label = tostring(r.label or ('Rank ' .. i)) }
        for _, k in ipairs(RANK_PERM_KEYS) do list[i][k] = r[k] == true end
    end
    return list
end

local function saveRanks(g, list)
    -- the top seat is the boss: every permission, always
    for _, k in ipairs(RANK_PERM_KEYS) do list[#list][k] = true end
    g._ranks = list
    g.ranks = json.encode(list)
    DBExec('UPDATE gangs SET ranks = ? WHERE id = ?', { g.ranks, g.id })
    GangRefreshCrew(g.id)
end

RegisterNetEvent('pup-gangs:rankSave', function(index, label, perms)
    local _source = source
    local g, ch = leaderGang(_source)
    if not g then return end
    if not GangEditAllowed(_source) then return end
    local list = rankListCopy(g)
    local i = math.floor(tonumber(index) or 0)
    if i < 1 or i > #list then return end

    label = tostring(label or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 20)
    if label ~= '' then list[i].label = label end
    -- perms editable on every seat but the top (saveRanks re-forces the top)
    if i < #list and type(perms) == 'table' then
        for _, k in ipairs(RANK_PERM_KEYS) do list[i][k] = perms[k] == true end
    end
    saveRanks(g, list)
    logActivity(g.id, 'ranks', ('rank %d is now "%s"'):format(i, list[i].label), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, 'Rank updated.')
end)

-- the boss picks the colour the gang flies (map blips + panel map circles)
RegisterNetEvent('pup-gangs:setColor', function(key)
    local _source = source
    local g, ch = leaderGang(_source)
    if not g then return end
    key = tostring(key or '')
    local found
    for _, c in ipairs(Config.Colors.list or {}) do
        if c.key == key then found = c break end
    end
    if not found then return end
    if g.blipcolor == key then return end   -- already flying it; charge nothing

    -- changing the banner costs blood money (Config.Blood.perColour)
    local first <const> = (g.blipcolor == nil or g.blipcolor == '')
    local cost <const> = (not first and Config.Blood and Config.Blood.enabled)
        and (tonumber(Config.Blood.perColour) or 0) or 0
    if cost > 0 and GangBloodMove then
        local bal = GangBloodMove(g, -cost, ch.charIdentifier,
            ch.firstname .. ' ' .. ch.lastname, 'colours - ' .. found.label)
        if not bal then
            return notify(_source, (Locale.bloodShort):format(cost, tonumber(g.bloodmoney) or 0), 7000)
        end
    end

    g.blipcolor = key
    DBExec('UPDATE gangs SET blipcolor = ? WHERE id = ?', { key, g.id })
    logActivity(g.id, 'colors', ('now flying %s'):format(found.label), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, cost > 0
        and ('Your gang now flies %s. That cost %d.'):format(found.label, cost)
        or ('Your gang now flies %s.'):format(found.label))
    -- everyone re-pulls: the colour is public
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
    TriggerClientEvent('pup-gangs:refresh', _source)
end)

RegisterNetEvent('pup-gangs:rankAdd', function(label)
    local _source = source
    local g, ch = leaderGang(_source)
    if not g then return end
    if not GangEditAllowed(_source) then return end
    local list = rankListCopy(g)
    if #list >= 8 then return notify(_source, 'Rank limit reached (8).') end

    label = tostring(label or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 20)
    if label == '' then label = 'New Rank' end

    -- insert just under the boss seat; everyone at/above that slot (the boss) shifts up one so the leader stays on top
    local pos = #list
    local row = { label = label }
    for _, k in ipairs(RANK_PERM_KEYS) do row[k] = false end
    table.insert(list, pos, row)
    DBExec('UPDATE gang_members SET rank = rank + 1 WHERE gangid = ? AND rank >= ?', { g.id, pos })
    for _, m in pairs(members) do
        if m.gangid == g.id and (m.rank or 1) >= pos then m.rank = m.rank + 1 end
    end
    saveRanks(g, list)
    logActivity(g.id, 'ranks', ('new rank created: %s'):format(label), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, 'Rank created.')
end)

RegisterNetEvent('pup-gangs:rankRemove', function(index)
    local _source = source
    local g, ch = leaderGang(_source)
    if not g then return end
    if not GangEditAllowed(_source) then return end
    local list = rankListCopy(g)
    local i = math.floor(tonumber(index) or 0)
    -- never the boss seat, and a gang keeps at least a two-step ladder
    if i < 1 or i >= #list then return end
    if #list <= 2 then return notify(_source, 'A gang needs at least two ranks.') end

    local removed = list[i].label
    table.remove(list, i)
    -- members holding the removed rank drop one step; everyone above shifts down
    DBExec('UPDATE gang_members SET rank = ? WHERE gangid = ? AND rank = ?', { math.max(1, i - 1), g.id, i })
    DBExec('UPDATE gang_members SET rank = rank - 1 WHERE gangid = ? AND rank > ?', { g.id, i })
    for _, m in pairs(members) do
        if m.gangid == g.id then
            if (m.rank or 1) == i then m.rank = math.max(1, i - 1)
            elseif (m.rank or 1) > i then m.rank = m.rank - 1 end
        end
    end
    saveRanks(g, list)
    logActivity(g.id, 'ranks', ('rank removed: %s'):format(removed), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, 'Rank removed.')
end)

RegisterNetEvent('pup-gangs:leave', function()
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = members[charid]
    if not m then return end
    if charid == tonumber(gangs[m.gangid] and gangs[m.gangid].leader) then
        return notify(_source, 'The boss cannot leave - promote someone first.')
    end
    DBExec('DELETE FROM gang_members WHERE charid = ?', { charid })
    logActivity(m.gangid, 'left', m.name .. ' left', m.name)
    members[charid] = nil
    notify(_source, 'You left the gang.')
    TriggerClientEvent('pup-gangs:refresh', _source)
    -- clear their territory blips now: out of the gang, out of the map
    TriggerClientEvent('pup-gangs:territoriesDirty', _source)
    -- and their view of the gang table (prop + prompt disappear immediately)
    TriggerClientEvent('pup-gangs:tablesDirty', _source)
end)

-- POINTS - the public entry point for the whole economy: exports['pup-gangs']:AwardPoints(source, kind, amount, detail)
local recentOps = {}

local STAT_BY_KIND = { robbery = 'robberies', heist = 'heists', mission = 'missions' }

local function awardPoints(src, kind, amount, detail)
    local ch = Char(src)
    if not ch then return false end
    local charid = ch.charIdentifier
    local m = members[charid]
    if not m then return false end
    local gang = gangs[m.gangid]
    if not gang then return false end

    local base = tonumber(amount) or tonumber(Config.Points[kind]) or 0
    if base <= 0 then return false end

    -- same gang, same operation, inside the window -> already paid
    local window = (tonumber(Config.Points.dedupeMinutes) or 0) * 60
    if window > 0 and detail and detail ~= '' then
        local opkey = gang.id .. '|' .. tostring(kind) .. '|' .. tostring(detail)
        local last = recentOps[opkey]
        if last and (now() - last) < window then
            dbg('dedup', gang.name, kind, detail, 'skipped (same op)')
            return false
        end
        recentOps[opkey] = now()
    end

    local faction = Config.Factions.list[gang.faction]
    local mult = 1.0
    if faction and faction.bonus then
        if kind == 'robbery' or kind == 'heist' then mult = faction.bonus.robberyMult or 1.0
        elseif kind == 'mission' then mult = faction.bonus.missionMult or 1.0
        elseif kind == 'war' or kind == 'warWin' then mult = faction.bonus.warMult or 1.0 end
    end

    local gain = math.floor(base * mult + 0.5)
    gang.points = (gang.points or 0) + gain
    gang.last_activity = now()

    DBExec('UPDATE gangs SET points = ?, last_activity = ? WHERE id = ?', { gang.points, gang.last_activity, gang.id })
    DBExec('UPDATE gang_members SET points = points + ? WHERE charid = ?', { gain, charid })
    -- the same earning scores for the gang's FACTION - this is the three-way war
    addFactionPoints(gang.faction, gain)
    logActivity(gang.id, kind, ('+%d points%s'):format(gain, detail and (' - ' .. detail) or ''), m.name, gain)
    if STAT_BY_KIND[kind] then
        if kind == 'heist' then
            -- a heist pays per LOCKBOX (detail 'valentine #3') but counts as ONE bank job in the record
            local job = tostring(detail or ''):gsub(' #%d+$', '')
            local skey = gang.id .. '|heistjob|' .. job
            if window <= 0 or not recentOps[skey] or (now() - recentOps[skey]) >= window then
                bumpStat(gang, 'heists', 1)
            end
            recentOps[skey] = now()
        else
            bumpStat(gang, STAT_BY_KIND[kind], 1)
        end
    end

    dbg('points', gang.name, kind, '+' .. gain, '=>', gang.points)
    -- quiet by default (Config.Points.announce)
    if Config.Points.announce then
        notify(src, Locale.pointsAwarded .. gain)
    end
    -- radius is derived from points, so the map must be re-pulled
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
    return true, gain
end

-- the dedup memory only needs to cover the window - sweep it occasionally
CreateThread(function()
    while true do
        Wait(600000)
        local window = (tonumber(Config.Points.dedupeMinutes) or 0) * 60
        local t = now()
        for k, ts in pairs(recentOps) do
            if (t - ts) > window then recentOps[k] = nil end
        end
    end
end)

exports('AwardPoints', awardPoints)
exports('GetGangOf', function(charid)
    local m = members[tonumber(charid) or -1]
    if not m then return nil end
    local g = gangs[m.gangid]
    if not g then return nil end
    return { id = g.id, name = g.name, faction = g.faction, points = g.points, rank = m.rank }
end)
exports('GetGangPoints', function(gangid)
    local g = gangs[tonumber(gangid) or -1]
    return g and g.points or 0
end)

-- TERRITORY CLAIMS - the 20-minute public siege
local claims = {}   -- [territoryId] = { gangid, startts, holdFrom, endts, empty, active }
local claimCooldowns = {} -- [territoryId] = ts of last attempt

-- how many LIVING members of `gangid` stand inside this territory right now
local function claimersPresent(gangid, t)
    local radius = radiusFor((gangs[gangid] or {}).points or 0)
    local n = 0
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ch = src and Char(src)
        local m = ch and members[ch.charIdentifier]
        if m and m.gangid == gangid and not ch.isdead then
            local ped = GetPlayerPed(src)
            if ped and ped > 0 then
                local c = GetEntityCoords(ped)
                if #(vector3(c.x, c.y, c.z) - vector3(tonumber(t.x) + 0.0, tonumber(t.y) + 0.0, tonumber(t.z) + 0.0)) <= radius then
                    n = n + 1
                end
            end
        end
    end
    return n
end

-- is anyone from the holding gang online to defend?
local function holderOnline(gangid)
    for _, sid in ipairs(GetPlayers()) do
        local ch = Char(tonumber(sid))
        local m = ch and members[ch.charIdentifier]
        if m and m.gangid == gangid then return true end
    end
    return false
end

local function claimPayload(tid, c)
    local t = territories[tid]
    local g = gangs[c.gangid]
    local holder = t and t.gangid and gangs[t.gangid] or nil
    return {
        territoryId = tid,
        name        = t and t.name or '?',
        x = t and tonumber(t.x) or 0.0, y = t and tonumber(t.y) or 0.0, z = t and tonumber(t.z) or 0.0,
        attacker    = c.gangid,
        attackerTag = g and (g.shortname ~= '' and g.shortname or g.name) or '?',
        defender    = t and t.gangid or nil,
        defenderTag = holder and (holder.shortname ~= '' and holder.shortname or holder.name) or nil,
        endts       = c.endts,
        holdFrom    = c.holdFrom,
        -- remaining seconds at send time: the client counts down with its own game timer
        secondsLeft = math.max(0, (c.endts or 0) - now()),
        graceLeft   = math.max(0, (c.holdFrom or 0) - now()),
        radius      = radiusFor((g or {}).points or 0),
    }
end

RegisterNetEvent('pup-gangs:claimTerritory', function(territoryId)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    if not Config.Claims.enabled then return end
    local charid = ch.charIdentifier
    if not can(charid, 'territory') then return notify(_source, Locale.notAllowed) end

    local tid = tonumber(territoryId) or -1
    local t = territories[tid]
    if not t then return end
    local gangid = members[charid].gangid

    if t.gangid == gangid then return notify(_source, Locale.claimYours) end
    if claims[tid] then return notify(_source, Locale.claimBusy) end
    for otherTid, c in pairs(claims) do
        if c.gangid == gangid then return notify(_source, Locale.claimAlready) end
    end
    local cd = (claimCooldowns[tid] or 0) + (Config.Claims.cooldownMinutes * 60)
    if cd > now() then return notify(_source, Locale.claimCooldown) end
    -- a HELD fort needs someone home to fight for it
    if t.gangid and Config.Claims.defendersOnline and not holderOnline(t.gangid) then
        return notify(_source, Locale.claimNoDefender)
    end

    -- a claim takes a posse - counted through pup-ui's posse
    local needP <const> = tonumber(Config.Claims.minPosse) or 1
    if needP > 1 then
        local okP, riders = pcall(function() return exports['pup-ui']:GetPosseMembers(_source) end)
        local crew = (okP and type(riders) == 'table') and #riders or 0
        if crew < needP then
            return notify(_source, (Locale.claimNeedPosse):format(needP, crew), 7000)
        end
    end

    local grace = Config.Claims.travelGraceMinutes * 60
    local c = {
        gangid   = gangid,
        startts  = now(),
        empty    = 0,
    }
    if Config.Claims.startOnArrival then
        -- ARMED
        c.armed    = true
        c.armUntil = now() + grace
    else
        c.holdFrom = now() + grace                                   -- presence only counts after the ride out
        c.endts    = now() + grace + (Config.Claims.durationMinutes * 60)
    end
    claims[tid] = c

    local g = gangs[gangid]
    logActivity(gangid, 'claim', ('moving on %s'):format(t.name), ch.firstname .. ' ' .. ch.lastname)

    if c.armed then
        -- ARMED is PRIVATE
        notify(_source, (Locale.claimArmed):format(t.name,
            tonumber(Config.Claims.minPosse) or 1, Config.Claims.travelGraceMinutes), 10000)
        dbg('claim ARMED on', t.name, 'by gang', gangid)
        return
    end

    if t.gangid then logActivity(t.gangid, 'claim', ('%s is contesting %s'):format(g and g.name or '?', t.name), '') end
    notify(_source, Locale.claimStarted, 8000)

    -- EVERY gang sees it: a claim is a public act
    TriggerClientEvent('pup-gangs:claimStarted', -1, claimPayload(tid, c))
    dbg('claim started on', t.name, 'by gang', gangid)
end)

-- resolve ONE claim for this tick. Returns nothing; mutates `claims`.
local function tickClaim(tid, c, t0)
    local t = territories[tid]
    if not t then claims[tid] = nil return end

    -- ARMED: the crew has been told to ride and the clock has not started
    if c.armed then
        local onSite = claimersPresent(c.gangid, t)
        local need <const> = tonumber(Config.Claims.minPosse) or 1
        if onSite >= need then
            c.armed = nil
            c.holdFrom = t0
            c.endts = t0 + (Config.Claims.durationMinutes * 60)
            c.empty = 0
            logActivity(c.gangid, 'claim', ('took the ground at %s - the clock is running'):format(t.name), '')
            -- the defenders learn of it HERE, not when it was armed
            if t.gangid then
                local ga = gangs[c.gangid]
                logActivity(t.gangid, 'claim',
                    ('%s is contesting %s'):format(ga and ga.name or '?', t.name), '')
            end
            TriggerClientEvent('pup-gangs:claimStarted', -1, claimPayload(tid, c))
            dbg('claim ARMED -> RUNNING on', t.name, 'with', onSite, 'on site')
        elseif t0 >= (c.armUntil or 0) then
            -- never showed up: the fort takes the cooldown so a crew cannot arm every one of them to lock rivals out
            claims[tid] = nil
            claimCooldowns[tid] = t0
            logActivity(c.gangid, 'claim', ('never rode out to %s'):format(t.name), '', 0)
            TriggerClientEvent('pup-gangs:claimEnded', -1,
                { territoryId = tid, won = false, attacker = c.gangid, name = t.name })
            dbg('claim LAPSED on', t.name, '- nobody arrived')
        end
        return
    end

    -- inside the hold window an empty zone runs the claim down
    if t0 >= c.holdFrom then
        if claimersPresent(c.gangid, t) > 0 then
            c.empty = 0
        else
            c.empty = (c.empty or 0) + 1
            if c.empty >= (Config.Claims.presenceTicks or 3) then
                claims[tid] = nil
                claimCooldowns[tid] = t0
                logActivity(c.gangid, 'claim', ('lost the claim on %s'):format(t.name), '', 0)
                TriggerClientEvent('pup-gangs:claimEnded', -1,
                    { territoryId = tid, won = false, attacker = c.gangid, name = t.name })
                dbg('claim FAILED on', t.name, '- ground abandoned')
                return
            end
        end
    end

    if t0 >= c.endts then
        -- held to the end: the ground changes hands
        claims[tid] = nil
        claimCooldowns[tid] = t0
        local previous = t.gangid
        t.gangid = c.gangid
        t.claimed_at = t0
        DBExec('UPDATE gang_territories SET gangid = ?, claimed_at = ? WHERE id = ?', { c.gangid, t0, tid })

        -- award inline rather than through GangAwardGang
        local g = gangs[c.gangid]
        if g then
            local gain = math.floor(tonumber(Config.Points.territoryCap) or 0)
            if gain > 0 then
                g.points = (g.points or 0) + gain
                g.last_activity = t0
                DBExec('UPDATE gangs SET points = ?, last_activity = ? WHERE id = ?', { g.points, t0, g.id })
                addFactionPoints(g.faction, gain)
                logActivity(c.gangid, 'territory', ('took %s (+%d points)'):format(t.name, gain), '', gain)
            else
                logActivity(c.gangid, 'territory', ('took %s'):format(t.name), '', 0)
            end
            bumpStat(g, 'territories', 1)
        end
        if previous then logActivity(previous, 'territory', ('lost %s'):format(t.name), '', 0) end
        TriggerClientEvent('pup-gangs:claimEnded', -1,
            { territoryId = tid, won = true, attacker = c.gangid, name = t.name })
        TriggerClientEvent('pup-gangs:territoriesDirty', -1)
        dbg('claim WON on', t.name, 'by gang', c.gangid)
    end
end

-- the claim tick: presence, timeout, resolution
CreateThread(function()
    while true do
        Wait((Config.Claims.tickSeconds or 10) * 1000)
        if Config.Claims.enabled then
            local t0 = now()
            for tid, c in pairs(claims) do tickClaim(tid, c, t0) end
        end
    end
end)

-- a client joining mid-siege needs the running claims to draw its timer
VorpCore.Callback.Register('pup-gangs:getClaims', function(source, cb)
    local out = {}
    -- an ARMED claim is private until the crew takes the ground
    for tid, c in pairs(claims) do
        if not c.armed then out[#out + 1] = claimPayload(tid, c) end
    end
    cb(out)
end)

-- claimable ground for the panel's target picker: every territory that is not already ours
VorpCore.Callback.Register('pup-gangs:getClaimTargets', function(source, cb)
    local ch = Char(source)
    if not ch then return cb({}) end
    local m = members[ch.charIdentifier]
    if not m then return cb({}) end
    local out = {}
    for tid, t in pairs(territories) do
        local holder = t.gangid and gangs[t.gangid] or nil
        local blocked = nil
        if t.gangid == m.gangid then blocked = 'yours'
        elseif claims[tid] then blocked = 'contested'
        elseif ((claimCooldowns[tid] or 0) + Config.Claims.cooldownMinutes * 60) > now() then blocked = 'cooldown'
        elseif t.gangid and Config.Claims.defendersOnline and not holderOnline(t.gangid) then blocked = 'nodefender'
        end
        out[#out + 1] = {
            id = tid, name = t.name,
            held = t.gangid ~= nil,
            -- faction stays hidden; the TAG is public
            holderTag = holder and (holder.shortname ~= '' and holder.shortname or holder.name) or nil,
            mine = t.gangid == m.gangid,
            blocked = blocked,
        }
    end
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    cb(out)
end)

-- WARS
local warFiling = {} -- ['a:b'] = true while that war's row is being inserted

RegisterNetEvent('pup-gangs:declareWar', function(targetGangId)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    if not Config.Wars.enabled then return end
    local charid = ch.charIdentifier
    if not can(charid, 'war') then return notify(_source, Locale.notAllowed) end

    local gangid = members[charid].gangid
    local mine = gangs[gangid]
    local theirs = gangs[tonumber(targetGangId) or -1]
    if not mine or not theirs or mine.id == theirs.id then return end

    if not Config.Wars.allowSameFaction and mine.faction == theirs.faction then
        return notify(_source, Locale.warSameFaction)
    end
    for _, w in pairs(wars) do
        if (w.gang_a == mine.id and w.gang_b == theirs.id) or (w.gang_a == theirs.id and w.gang_b == mine.id) then
            return notify(_source, Locale.warActive)
        end
    end
    -- the insert below yields; the war only joins the list above once it is back
    local filing <const> = math.min(mine.id, theirs.id) .. ':' .. math.max(mine.id, theirs.id)
    if warFiling[filing] then return end
    if (tonumber(ch.money) or 0) < Config.Wars.declareCost then
        return notify(_source, Locale.nomoney)
    end

    -- war costs blood money (Config.Blood.perWar)
    local warBlood <const> = (Config.Blood and Config.Blood.enabled)
        and (tonumber(Config.Blood.perWar) or 0) or 0
    if warBlood > 0 then
        if not GangBloodMove then return end
        local bal = GangBloodMove(mine, -warBlood, charid,
            ch.firstname .. ' ' .. ch.lastname, 'war on ' .. theirs.name)
        if not bal then
            return notify(_source, (Locale.bloodShort):format(warBlood, tonumber(mine.bloodmoney) or 0), 7000)
        end
    end

    ch.removeCurrency(0, Config.Wars.declareCost)

    local endts = now() + Config.Wars.durationHours * 3600
    warFiling[filing] = true
    local okInsert, id = pcall(DBInsert,
        'INSERT INTO gang_wars (gang_a, gang_b, score_a, score_b, startts, endts, status) VALUES (?, ?, 0, 0, ?, ?, ?)',
        { mine.id, theirs.id, now(), endts, 'active' })
    warFiling[filing] = nil
    if not okInsert or not id then return end
    wars[id] = { id = id, gang_a = mine.id, gang_b = theirs.id, score_a = 0, score_b = 0, startts = now(), endts = endts, status = 'active' }

    logActivity(mine.id, 'war', 'declared war on ' .. theirs.name, ch.firstname .. ' ' .. ch.lastname)
    logActivity(theirs.id, 'war', mine.name .. ' declared war', '')
    notify(_source, Locale.warDeclared)
    TriggerClientEvent('pup-gangs:refresh', _source)
end)

-- Called by whatever handles PvP death
local function registerKill(killerSrc, victimSrc)
    if not Config.Wars.enabled then return false end
    local kc, vc = Char(killerSrc), Char(victimSrc)
    if not kc or not vc then return false end
    local km, vm = members[kc.charIdentifier], members[vc.charIdentifier]
    if not km or not vm or km.gangid == vm.gangid then return false end

    for _, w in pairs(wars) do
        local a, b = w.gang_a, w.gang_b
        if (a == km.gangid and b == vm.gangid) or (b == km.gangid and a == vm.gangid) then
            local pts = Config.Wars.pointsPerKill
            if a == km.gangid then w.score_a = (w.score_a or 0) + pts else w.score_b = (w.score_b or 0) + pts end
            DBExec('UPDATE gang_wars SET score_a = ?, score_b = ? WHERE id = ?', { w.score_a, w.score_b, w.id })
            -- lifetime kill/death counters for the statistics block
            local kg, vg = gangs[km.gangid], gangs[vm.gangid]
            if kg then bumpStat(kg, 'kills', 1) end
            if vg then bumpStat(vg, 'deaths', 1) end
            logActivity(km.gangid, 'war', ('war kill on %s (+%d war score)'):format(vm.name or 'a rival', pts), km.name, 0)
            dbg('war kill', w.id, 'a=' .. w.score_a, 'b=' .. w.score_b)
            return true
        end
    end
    return false
end
exports('RegisterKill', registerKill)

-- resolve wars whose clock ran out (epoch-based, so a restart cannot lose one)
local function resolveWar(w)
    local winner, loser
    if (w.score_a or 0) > (w.score_b or 0) then winner, loser = w.gang_a, w.gang_b
    elseif (w.score_b or 0) > (w.score_a or 0) then winner, loser = w.gang_b, w.gang_a end

    DBExec("UPDATE gang_wars SET status = 'finished', winner = ? WHERE id = ?", { winner, w.id })
    wars[w.id] = nil

    local function grant(gangid, amount, text, statKey)
        local g = gangs[gangid]
        if not g then return end
        g.points = (g.points or 0) + amount
        DBExec('UPDATE gangs SET points = ? WHERE id = ?', { g.points, g.id })
        -- war results are the biggest single earnings in the system, so they MUST roll up too
        addFactionPoints(g.faction, amount)
        logActivity(g.id, 'war', text .. (' (+%d points)'):format(amount), '', amount)
        if statKey then bumpStat(g, statKey, 1) end
    end

    if winner then
        grant(winner, Config.Points.warWin, 'won the war', 'warsWon')
        grant(loser, Config.Points.warLoss, 'lost the war', 'warsLost')
    else
        grant(w.gang_a, Config.Points.warLoss, 'war ended in a draw')
        grant(w.gang_b, Config.Points.warLoss, 'war ended in a draw')
    end
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
end

CreateThread(function()
    while true do
        Wait(60000) -- once a minute is plenty for hour-scale wars
        local t = now()
        for _, w in pairs(wars) do
            if (tonumber(w.endts) or 0) <= t then resolveWar(w) end
        end
    end
end)

-- POINT DECAY - idle gangs shrink, so the map shows who is actually active
CreateThread(function()
    if not Config.Points.decayEnabled then return end
    while true do
        Wait(3600000) -- hourly
        local t = now()
        for _, g in pairs(gangs) do
            local idleDays = math.floor((t - (tonumber(g.last_activity) or t)) / 86400)
            if idleDays >= 1 and (g.points or 0) > Config.Points.decayFloor then
                local loss = math.min(g.points - Config.Points.decayFloor, Config.Points.decayPerDay * idleDays)
                if loss > 0 then
                    g.points = g.points - loss
                    g.last_activity = t
                    DBExec('UPDATE gangs SET points = ?, last_activity = ? WHERE id = ?', { g.points, t, g.id })
                    logActivity(g.id, 'decay', ('-%d points (inactive %d day(s))'):format(loss, idleDays), '', -loss)
                    dbg('decay', g.name, '-' .. loss)
                end
            end
        end
        TriggerClientEvent('pup-gangs:territoriesDirty', -1)
    end
end)

-- Admin / dev
RegisterCommand('gangpoints', function(src, args)
    if src ~= 0 then
        local u = VorpCore.getUser(src)
        if not u or u.getGroup ~= 'admin' then return end
    end
    local gangid, amount = tonumber(args[1]), tonumber(args[2])
    local g = gangid and gangs[gangid]
    if not g or not amount then return print('usage: gangpoints <gangid> <amount>') end
    g.points = math.max(0, (g.points or 0) + amount)
    DBExec('UPDATE gangs SET points = ? WHERE id = ?', { g.points, g.id })
    logActivity(g.id, 'admin', ('points adjusted by %+d -> %d'):format(amount, g.points), 'admin', amount)
    print(('^2[pup-gangs]^7 %s -> %d points'):format(g.name, g.points))
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
end, false)

AddEventHandler('playerDropped', function()
    -- charIdentifier is checked as well as the character itself
    local ch = Char(source)
    if ch and ch.charIdentifier then invites[ch.charIdentifier] = nil end
end)

-- BRIDGE for server/features.lua - that file owns tables, levels/perks, stashes and plant missions
function GangById(id) return gangs[tonumber(id) or -1] end
function GangAll() return gangs end
function GangFactionStandings() return factionStandings() end
function GangAllTerritories() return territories end
function GangAllWars() return wars end
function GangRadius(points) return radiusFor(points) end

-- SEASON RESET (admin panel). Zeroes the ladders ONLY - rosters, territory,
-- money, dens and anything a gang owns are left alone. Gang points drive the
-- map radius and the perk level, so every reset ends with a territory refresh.
function GangResetPoints(what)
    what = tostring(what or 'all')
    local doGangs   <const> = (what == 'all' or what == 'gangs')
    local doMembers <const> = (what == 'all' or what == 'members')
    local doFaction <const> = (what == 'all' or what == 'factions')
    local out = { gangs = 0, members = 0, factions = 0 }
    local t <const> = now()

    if doGangs then
        for _, g in pairs(gangs) do
            local had = tonumber(g.points) or 0
            if had ~= 0 then
                logActivity(g.id, 'admin', ('season reset - %d point(s) cleared'):format(had), 'admin', -had)
            end
            g.points = 0
            g.last_activity = t
            out.gangs = out.gangs + 1
        end
        -- every UPDATE here carries a WHERE, so a server running MySQL safe-updates does not reject it
        DBExec('UPDATE gangs SET points = 0, last_activity = ? WHERE id > 0', { t })
    end

    if doMembers then
        local row = (DBQuery('SELECT COUNT(*) AS n FROM gang_members WHERE points <> 0') or {})[1]
        out.members = tonumber(row and row.n) or 0
        DBExec('UPDATE gang_members SET points = 0 WHERE points <> 0')
    end

    if doFaction then
        for key in pairs(Config.Factions.list) do
            factionPts[key] = 0
            out.factions = out.factions + 1
        end
        DBExec("UPDATE gang_factions SET points = 0, updated_at = ? WHERE faction <> ''", { t })
    end

    dbg(('season reset (%s): %d gang(s), %d member(s), %d faction(s)')
        :format(what, out.gangs, out.members, out.factions))
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
    TriggerClientEvent('pup-gangs:refresh', -1)
    return out
end

-- drop a disbanded gang from every cache (the admin panel's disband path)
function GangForget(gangid)
    local id = tonumber(gangid)
    if not id then return end
    gangs[id] = nil
    for charid, m in pairs(members) do
        if m.gangid == id then members[charid] = nil end
    end
    for _, t in pairs(territories) do
        if t.gangid == id then t.gangid = nil end
    end
    for wid, w in pairs(wars) do
        if w.gang_a == id or w.gang_b == id then wars[wid] = nil end
    end
end
function GangMemberOf(charid) return members[tonumber(charid) or -1] end

-- How many characters are on a gang's roster
function GangRosterCount(gangid)
    gangid = tonumber(gangid)
    if not gangid then return 0 end
    local n = 0
    for _, m in pairs(members) do
        if m.gangid == gangid then n = n + 1 end
    end
    return n
end
function GangTerritory(id) return territories[tonumber(id) or -1] end
function GangCan(charid, perm) return can(charid, perm) end
function GangLog(gangid, kind, detail, actor, pts) return logActivity(gangid, kind, detail, actor, pts) end
function GangWeeklyEarned() return earnedSince(7) end
function GangActivityLabel(weekly) return activityScore(weekly) end
function GangStatsOf(g) return gangStats(g) end

-- award through the normal path (faction multiplier, activity log, map refresh)
function GangAward(src, kind, amount, detail) return awardPoints(src, kind, amount, detail) end

-- THE PAYOUT (Config.Rewards): gang points through the normal path
-- for risk premiums the caller works out itself (e.g. per-target-member).
-- Returns the points actually awarded.
function GangPayReward(src, rewardKey, detail, bonusPoints)
    local rw = (Config.Rewards or {})[rewardKey]
    if not rw then return 0 end
    local ch = Char(src)
    if not ch then return 0 end

    local pts = math.max(0, math.floor((tonumber(rw.points) or 0) + (tonumber(bonusPoints) or 0)))
    if pts > 0 then awardPoints(src, 'mission', pts, detail) end

    -- BLOOD MONEY on every gang mission (Config.Blood.mission, 1-5 by default)
    if GangBloodMission then
        local n = GangBloodMission(src, detail or rewardKey)
        if n and n > 0 then notify(src, (Locale.bloodEarned):format(n), 5000) end
    end

    if rw.cash and (tonumber(rw.cash.max) or 0) > 0 then
        local lo = math.floor(tonumber(rw.cash.min) or 0)
        local hi = math.floor(tonumber(rw.cash.max) or lo)
        if hi >= lo then
            local amount = math.random(lo, hi)
            if amount > 0 then
                pcall(function() ch.addCurrency(0, amount) end)
                notify(src, ('$%d for the work.'):format(amount), 5000)
            end
        end
    end

    for _, it in ipairs(rw.items or {}) do
        local chance = tonumber(it.chance) or 100
        if math.random(100) <= chance then
            local lo = math.floor(tonumber(it.min) or 1)
            local hi = math.floor(tonumber(it.max) or lo)
            local n = (hi >= lo) and math.random(lo, hi) or lo
            if n > 0 then
                local ok, can = pcall(function()
                    return exports.vorp_inventory:canCarryItem(src, it.item, n)
                end)
                if ok and can then
                    pcall(function() exports.vorp_inventory:addItem(src, it.item, n) end)
                end
            end
        end
    end
    return pts
end

-- award to a GANG with no acting player (a plant that survives its timer)
function GangAwardGang(gangid, amount, detail)
    local g = gangs[tonumber(gangid) or -1]
    if not g then return false end
    local gain = math.floor((tonumber(amount) or 0))
    if gain <= 0 then return false end
    g.points = (g.points or 0) + gain
    g.last_activity = now()
    DBExec('UPDATE gangs SET points = ?, last_activity = ? WHERE id = ?', { g.points, g.last_activity, g.id })
    addFactionPoints(g.faction, gain) -- rolls up to the faction war, same as awardPoints
    logActivity(g.id, 'mission', ('+%d points%s'):format(gain, detail and (' - ' .. detail) or ''), '', gain)
    bumpStat(g, 'missions', 1)
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
    return true
end

-- the panel needs level/perk info, which server/features.lua computes
function GangLevelInfo(points)
    if not GangLevel then return nil end
    local tier = GangLevel(points)
    local nextTier = GangNextLevel(points)
    return {
        level = tier.level, label = tier.label, perks = tier.perks,
        nextAt = nextTier and nextTier.points or nil,
        nextLabel = nextTier and nextTier.label or nil,
    }
end
