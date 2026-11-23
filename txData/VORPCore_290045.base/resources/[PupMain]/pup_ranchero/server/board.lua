-- pup_ranchero | managers' tools in the Boss Actions menu: who is working right now, and the
-- ranch leaderboard (milk, eggs, chores and herding trips per person, from ranch_stats)

local function bossRanch(ctx)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return nil end
    return r
end

-- a chore round the client never finished stops counting after this long
local function choreRoundMs()
    local mg = Config.Minigame
    return ((tonumber(mg.roundSeconds) or 60) + (tonumber(mg.safetySeconds) or 10) + 30) * 1000
end

-- what a member is doing right now: status key, optional detail
local function statusOf(r, src)
    if not src then return 'offline' end
    local d = Drives[src]
    if d and d.rid == r.id then
        if d.kind == 'herd' then return d.live and 'herding' or 'herdPrep', d.animal end
        return d.live and 'selling' or 'sellPrep', d.animal
    end
    local c = ChoreRounds[src]
    if c and c.rid == r.id and GetGameTimer() - c.opened < choreRoundMs() then
        return 'chore', U.choreLabel(c.chore)
    end
    local p = ProduceSessions[src]
    if p and p.rid == r.id and os.time() <= p.expires then
        return p.kind == 'milk' and 'milking' or 'eggs'
    end
    local pos = PlayerPos(src)
    if pos and r.coords and U.dist3(pos, r.coords) <= (tonumber(Config.Board.nearRanch) or 150) then return 'idleNear' end
    return 'idleAway'
end

-- busy first, then idle at the ranch, idle elsewhere, offline
local ORDER = {
    herding = 1, selling = 1, chore = 1, milking = 1, eggs = 1,
    herdPrep = 2, sellPrep = 2, idleNear = 3, idleAway = 4, offline = 5,
}

-- source of a member who is online on that character, or nil
local function onlineSrc(charid)
    local s = SrcOfChar(charid)
    if not s then return nil end
    local c = Ctx(s)
    if c and c.charid == charid then return s, c end
    return nil
end

-- [charid] = { name, last } from ranch_stats for this ranch
local function statRows(rid)
    local out = {}
    local ok, rows = pcall(MySQL.query.await,
        'SELECT charid, name, milk, eggs, chores, herds, last_ts FROM ranch_stats WHERE ranchid = ?', { rid })
    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            local cid = math.floor(tonumber(row.charid) or 0)
            if cid > 0 then
                out[cid] = {
                    name = tostring(row.name or ''), last = math.floor(tonumber(row.last_ts) or 0),
                    milk = math.floor(tonumber(row.milk) or 0), eggs = math.floor(tonumber(row.eggs) or 0),
                    chores = math.floor(tonumber(row.chores) or 0), herds = math.floor(tonumber(row.herds) or 0),
                }
            end
        end
    end
    return out
end

-- the owner's name is not stored on the ranch: online character, then the characters table, then stats
local function ownerName(r, stats)
    local _, c = onlineSrc(r.charid)
    if c then return c.name end
    local ok, rows = pcall(MySQL.query.await, 'SELECT firstname, lastname FROM characters WHERE charidentifier = ? LIMIT 1', { r.charid })
    if ok and type(rows) == 'table' and rows[1] then
        local n = U.trim(('%s %s'):format(rows[1].firstname or '', rows[1].lastname or ''))
        if n ~= '' then return n end
    end
    local s = stats[r.charid]
    if s and s.name ~= '' then return s.name end
    return '#' .. tostring(r.charid)
end

-- everyone on the books: { charid, name, role }
local function members(r, stats)
    local list = {}
    if r.owned == 1 and r.charid then
        list[#list + 1] = { charid = r.charid, name = ownerName(r, stats), role = 'owner' }
    end
    for _, h in ipairs(r.hired) do
        if not (r.owned == 1 and h.charidentifier == r.charid) then
            list[#list + 1] = { charid = h.charidentifier, name = h.name, role = h.manager and 'manager' or 'hand' }
        end
    end
    return list
end

Rpc('boardWho', { gap = 1500 }, function(ctx)
    local r = bossRanch(ctx)
    if not r then return false end
    local rid = r.id
    local stats = statRows(rid)
    r = Ranches[rid]
    if not r then return false end -- deleted while we waited
    local out = {}
    for _, m in ipairs(members(r, stats)) do
        local src = onlineSrc(m.charid)
        local status, detail = statusOf(r, src)
        local s = stats[m.charid]
        out[#out + 1] = { name = m.name, role = m.role, status = status, detail = detail, last = s and s.last or 0 }
    end
    table.sort(out, function(a, b)
        local oa, ob = ORDER[a.status] or 9, ORDER[b.status] or 9
        if oa ~= ob then return oa < ob end
        return a.name:lower() < b.name:lower()
    end)
    return { now = os.time(), list = out }
end)

Rpc('boardStats', { gap = 1500 }, function(ctx)
    local r = bossRanch(ctx)
    if not r then return false end
    local rid = r.id
    local stats = statRows(rid)
    r = Ranches[rid]
    if not r then return false end
    local current = {}
    for _, m in ipairs(members(r, stats)) do current[m.charid] = m.name end
    local rows = {}
    for cid, s in pairs(stats) do
        rows[#rows + 1] = {
            name = current[cid] or (s.name ~= '' and s.name or ('#' .. cid)),
            member = current[cid] ~= nil,
            milk = s.milk, eggs = s.eggs, chores = s.chores, herds = s.herds,
        }
    end
    table.sort(rows, function(a, b) return a.chores > b.chores end)
    local cap = math.floor(tonumber(Config.Board.maxRows) or 50)
    while #rows > cap do table.remove(rows) end
    return { rows = rows }
end)
