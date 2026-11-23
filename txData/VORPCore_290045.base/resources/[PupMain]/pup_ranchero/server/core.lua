-- pup_ranchero | server core: ranch state, persistence, players, roles, request channel

VORP = exports.vorp_core:GetCore()

Ranches = {}      -- id -> ranch (the authoritative copy)
RanchesReady = false

-- in-memory cooldown deadlines (os.time); all lost on restart by design
Cooldowns = {
    herd  = {},   -- [rid] = until
    sell  = {},   -- [rid] = until
    chore = {},   -- [rid][charid][chore] = until
    milk  = {},   -- [rid][charid] = until
    eggs  = {},   -- [rid][charid] = until
}

-- types bought since their last herding trip, per ranch (not sellable yet)
FreshHerds = {}   -- [rid][type] = true

-- who ran the last herding / sale drive per ranch, shown next to the cooldown (lost on restart)
LastDrive = { herd = {}, sell = {} }   -- [rid] = { name, at }

function Debug(...)
    if Config.General.debug then print('[pup_ranchero]', ...) end
end

------------------------------------------------------------------------------
-- database row <-> ranch
------------------------------------------------------------------------------
local function encodeMap(t)
    if type(t) ~= 'table' or next(t) == nil then return '[]' end
    return json.encode(t)
end

local function readCounts(text, float)
    local out = {}
    for k, v in pairs(U.decode(text)) do
        if type(k) == 'string' then
            local n = U.num(v)
            if n then out[k] = float and n or math.floor(n) end
        end
    end
    return out
end

local function readHired(text)
    local out = {}
    for _, h in ipairs(U.decode(text)) do
        if type(h) == 'table' then
            local cid = U.num(h.charidentifier)
            if cid then
                local m = h.manager
                out[#out + 1] = {
                    identifier = h.identifier and tostring(h.identifier) or nil,
                    charidentifier = math.floor(cid),
                    name = tostring(h.name or ''),
                    manager = (m == true or m == 1 or m == '1' or m == 'true'),
                }
            end
        end
    end
    return out
end

function RanchFromRow(row)
    local chores = {}
    for k, v in pairs(U.decode(row.chores)) do
        if type(k) == 'string' and type(v) == 'table' then
            local loc = U.coords(v.loc)
            if loc then chores[k] = { loc = loc, num = math.floor(U.num(v.num, 0)) } end
        end
    end
    local cows, chickens = U.decode(row.cows), U.decode(row.chickens)
    local cattle = readCounts(row.cattle, false)
    for k, n in pairs(cattle) do if n <= 0 then cattle[k] = nil end end
    return {
        id         = math.floor(U.num(row.id, 0)),
        identifier = row.identifier and tostring(row.identifier) or nil,
        charid     = U.num(row.charidentifier) and math.floor(U.num(row.charidentifier)) or nil,
        name       = tostring(row.name or ''),
        price      = U.num(row.price, 0),
        coords     = U.coords(U.decode(row.coords)),
        owned      = U.num(row.owned, 0) == 1 and 1 or 0,
        trail      = U.trailPoints(U.decode(row.herdtrail)),
        cattle     = cattle,
        qcattle    = readCounts(row.q_cattle, true),
        dist       = U.clamp(math.floor(U.num(row.dist, 1)), 1, 10),
        chores     = chores,
        cows       = U.coords(cows.loc),
        chickens   = U.coords(chickens.loc),
        milk       = math.max(0, math.floor(U.num(row.milk, 0))),
        eggs       = math.max(0, math.floor(U.num(row.eggs, 0))),
        ledger     = U.cents(U.num(row.ledger, 0)),
        dog        = tostring(row.dog or '0'),
        env        = math.max(0, math.floor(U.num(row.q_ranch, 0))),
        repoed     = U.num(row.repoed, 0) == 1 and 1 or 0,
        herding    = 0,
        selling    = 0,
        tax        = math.max(0, math.floor(U.num(row.tax, 0))),
        hired      = readHired(row.hired),
        webhook    = (type(row.webhook) == 'string' and row.webhook ~= '') and row.webhook or nil,
    }
end

local function pointJson(p) return { x = p.x, y = p.y, z = p.z } end

-- column -> value; the ONLY column names that ever reach SQL
local COLUMNS = {
    identifier     = function(r) return r.identifier end,
    charidentifier = function(r) return r.charid end,
    name           = function(r) return r.name end,
    price          = function(r) return r.price end,
    coords         = function(r) return r.coords and json.encode(pointJson(r.coords)) or '[]' end,
    owned          = function(r) return r.owned end,
    herdtrail      = function(r)
        if not r.trail then return '[]' end
        local t = {}
        for i = 1, 4 do t['loc' .. i] = pointJson(r.trail[i]) end
        return json.encode({ t })
    end,
    cattle         = function(r) return encodeMap(r.cattle) end,
    q_cattle       = function(r) return encodeMap(r.qcattle) end,
    dist           = function(r) return r.dist end,
    chores         = function(r)
        local t = {}
        for k, v in pairs(r.chores) do t[k] = { loc = pointJson(v.loc), num = v.num } end
        return encodeMap(t)
    end,
    cows           = function(r) return r.cows and json.encode({ loc = pointJson(r.cows) }) or '[]' end,
    chickens       = function(r) return r.chickens and json.encode({ loc = pointJson(r.chickens) }) or '[]' end,
    milk           = function(r) return r.milk end,
    eggs           = function(r) return r.eggs end,
    ledger         = function(r) return r.ledger end,
    dog            = function(r) return r.dog end,
    q_ranch        = function(r) return r.env end,
    repoed         = function(r) return r.repoed end,
    herding        = function(r) return r.herding end,
    selling        = function(r) return r.selling end,
    tax            = function(r) return r.tax end,
    hired          = function(r)
        if #r.hired == 0 then return '[]' end
        local list = {}
        for i, h in ipairs(r.hired) do
            list[i] = { identifier = h.identifier, charidentifier = h.charidentifier, name = h.name, manager = h.manager == true }
        end
        return json.encode(list)
    end,
    webhook        = function(r) return r.webhook end,
}

-- writes are queued and run one at a time, reading the CURRENT values when they run,
-- so two quick changes can never land in the wrong order
local pending, pendingOrder, writerBusy = {}, {}, false

local function runWriter()
    if writerBusy then return end
    writerBusy = true
    CreateThread(function()
        while #pendingOrder > 0 do
            local rid = table.remove(pendingOrder, 1)
            local cols = pending[rid]
            pending[rid] = nil
            local r = Ranches[rid]
            if r and cols then
                local sets, params = {}, {}
                for col in pairs(cols) do
                    sets[#sets + 1] = ('`%s` = ?'):format(col)
                    params[#params + 1] = COLUMNS[col](r)
                end
                params[#params + 1] = rid
                local ok, err = pcall(MySQL.update.await, ('UPDATE player_ranch SET %s WHERE id = ?'):format(table.concat(sets, ', ')), params)
                if not ok then print('^1[pup_ranchero]^7 save failed for ranch ' .. rid .. ': ' .. tostring(err)) end
            end
        end
        writerBusy = false
    end)
end

function Save(r, ...)
    if not r or not Ranches[r.id] then return end
    local cols = pending[r.id]
    if not cols then
        cols = {}
        pending[r.id] = cols
        pendingOrder[#pendingOrder + 1] = r.id
    end
    for _, col in ipairs({ ... }) do
        if COLUMNS[col] then cols[col] = true else print('[pup_ranchero] unknown column ' .. tostring(col)) end
    end
    runWriter()
end

------------------------------------------------------------------------------
-- players
------------------------------------------------------------------------------
function Ctx(src)
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return nil end
    local user = VORP.getUser(src)
    if not user then return nil end
    local ch = user.getUsedCharacter
    if type(ch) ~= 'table' then return nil end
    local cid = U.num(ch.charIdentifier)
    if not cid or cid <= 0 then return nil end
    return {
        src = src,
        user = user,
        char = ch,
        charid = math.floor(cid),
        identifier = ch.identifier,
        name = U.trim(('%s %s'):format(ch.firstname or '', ch.lastname or '')),
        job = ch.job,
        grade = ch.jobGrade,
        group = user.getGroup,
    }
end

-- fresh character read for money checks (the character table is a snapshot)
function Cash(src)
    local c = Ctx(src)
    return c and U.num(c.char.money, 0) or 0
end

function SrcOfChar(charid)
    local user = VORP.getUserByCharId(charid)
    return user and tonumber(user.source) or nil
end

function PlayerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 and c.z == 0.0 then return nil end
    return { x = c.x, y = c.y, z = c.z }
end

-- 3D reach from the player's real position; passes when the server cannot place the player
function Near(src, point, reach)
    if not point then return false end
    local p = PlayerPos(src)
    if not p then return true end
    return U.dist3(p, point) <= reach
end

function Notify(src, msg, ms)
    TriggerClientEvent('vorp:TipRight', src, msg, ms or 4000)
end

------------------------------------------------------------------------------
-- roles
------------------------------------------------------------------------------
function IsOwner(r, charid, identifier)
    if r.owned ~= 1 or r.charid ~= charid then return false end
    if identifier ~= nil and r.identifier ~= nil and r.identifier ~= identifier then return false end
    return true
end

function HiredIndex(r, charid)
    for i, h in ipairs(r.hired) do
        if h.charidentifier == charid then return i, h end
    end
    return nil
end

-- 'owner' | 'manager' | 'hand' | nil ; the owner role wins over a stray hired entry
function RoleIn(r, charid, identifier)
    if IsOwner(r, charid, identifier) then return 'owner' end
    local _, h = HiredIndex(r, charid)
    if h then return h.manager and 'manager' or 'hand' end
    return nil
end

function RanchOf(charid, identifier)
    for _, r in pairs(Ranches) do
        local role = RoleIn(r, charid, identifier)
        if role then return r, role end
    end
    return nil
end

-- the caller's ranch and role, optionally requiring a specific ranch id
function MemberRanch(ctx, rid)
    local r, role = RanchOf(ctx.charid, ctx.identifier)
    if not r then return nil end
    if rid ~= nil and r.id ~= tonumber(rid) then return nil end
    return r, role
end

function IsBoss(role) return role == 'owner' or role == 'manager' end

-- staff count: hands not counting a stray owner entry
function StaffCount(r)
    local n = 0
    for _, h in ipairs(r.hired) do
        if not (r.owned == 1 and h.charidentifier == r.charid) then n = n + 1 end
    end
    return n
end

function RanchTitle(r)
    if r.name and r.name ~= '' then return ('%s (Ranch #%d)'):format(r.name, r.id) end
    return ('Ranch #%d'):format(r.id)
end

function StoreId(rid)
    return tostring(Config.Store.idBase + rid)
end

function TotalCattle(r)
    local n = 0
    for _, c in pairs(r.cattle) do n = n + c end
    return n
end

------------------------------------------------------------------------------
-- livestock changes (always applied as differences so concurrent purchases survive)
------------------------------------------------------------------------------
function SetFresh(r, animal, on)
    FreshHerds[r.id] = FreshHerds[r.id] or {}
    local was = FreshHerds[r.id][animal] == true
    if on and not was then
        FreshHerds[r.id][animal] = true
        MySQL.insert('INSERT IGNORE INTO ranch_fresh (ranchid, animal) VALUES (?, ?)', { r.id, animal })
    elseif not on and was then
        FreshHerds[r.id][animal] = nil
        MySQL.update('DELETE FROM ranch_fresh WHERE ranchid = ? AND animal = ?', { r.id, animal })
    end
end

function IsFresh(rid, animal)
    return FreshHerds[rid] ~= nil and FreshHerds[rid][animal] == true
end

-- remove `lost` head of a type; quality = new herd quality or nil to keep it
function ApplyHerd(r, animal, lost, quality)
    local count = (r.cattle[animal] or 0) - lost
    local q = quality
    if q == nil then q = r.qcattle[animal] or 0 end
    if count <= 0 or q <= 0 then
        r.cattle[animal] = nil
        r.qcattle[animal] = nil
        SetFresh(r, animal, false)
    else
        r.cattle[animal] = math.floor(count)
        r.qcattle[animal] = q
    end
    Save(r, 'cattle', 'q_cattle')
    return r.cattle[animal] or 0
end

------------------------------------------------------------------------------
-- request channel: client -> server calls with a reply
------------------------------------------------------------------------------
local handlers = {}
local stamps = {}   -- [src][name] = last call (GetGameTimer)

-- opts.gap: minimum ms between two calls of this name by one player
-- opts.noChar: allowed without a loaded character
function Rpc(name, opts, fn)
    handlers[name] = { fn = fn, gap = opts.gap or 300, noChar = opts.noChar == true }
end

RegisterNetEvent('pup_ranchero:rpc', function(reqId, name, ...)
    local src = source
    if type(name) ~= 'string' then return end
    local h = handlers[name]
    reqId = math.floor(tonumber(reqId) or 0)
    local function reply(...)
        if reqId > 0 then TriggerClientEvent('pup_ranchero:reply', src, reqId, ...) end
    end
    if not h or not RanchesReady then return reply(false) end

    local now = GetGameTimer()
    stamps[src] = stamps[src] or {}
    local last = stamps[src][name]
    if last and now - last < h.gap then return reply(false) end
    stamps[src][name] = now

    local ctx = Ctx(src)
    if not ctx then
        if not h.noChar then return reply(false) end
        ctx = { src = src }
    end

    local args = table.pack(...)
    CreateThread(function()
        local res = table.pack(pcall(h.fn, ctx, table.unpack(args, 1, args.n)))
        if not res[1] then
            print(('^1[pup_ranchero]^7 %s failed: %s'):format(name, tostring(res[2])))
            return reply(false)
        end
        reply(table.unpack(res, 2, res.n))
    end)
end)

function DropStamps(src) stamps[src] = nil end

------------------------------------------------------------------------------
-- what clients get told
------------------------------------------------------------------------------
function ListPayload()
    local out = {}
    for _, r in pairs(Ranches) do
        out[#out + 1] = { id = r.id, name = r.name, price = r.price, tax = r.tax, owned = r.owned, coords = r.coords }
    end
    return out
end

function BroadcastList()
    TriggerClientEvent('pup_ranchero:list', -1, ListPayload())
end

-- milk and egg totals sitting in the produce container
function StoreTotals(rid)
    local milk, eggs = 0, 0
    local ok, rows = pcall(MySQL.query.await,
        'SELECT item_name, SUM(amount) AS total FROM character_inventories WHERE inventory_type = ? AND item_name IN (?, ?) GROUP BY item_name',
        { StoreId(rid), Config.Produce.milkItem, Config.Produce.eggItem })
    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if row.item_name == Config.Produce.milkItem then milk = U.num(row.total, 0) end
            if row.item_name == Config.Produce.eggItem then eggs = U.num(row.total, 0) end
        end
    end
    return milk, eggs
end

local function left(untilTs)
    if not untilTs then return 0 end
    return math.max(0, untilTs - os.time())
end

-- the drive of this kind running on a ranch right now, if any
function RunningDrive(rid, kind)
    for _, d in pairs(Drives or {}) do
        if d.rid == rid and d.kind == kind then return d end
    end
    return nil
end

-- who is on (or last ran) a drive, for the cooldown lines: { by, running, live, left } or nil
function DriveWho(rid, kind)
    local d = RunningDrive(rid, kind)
    if d then
        local secs
        if d.live and d.liveAt and DriveLimit then secs = math.max(0, d.liveAt + DriveLimit(d) - os.time()) end
        return { by = d.driverName, running = true, live = d.live == true, left = secs }
    end
    local last = LastDrive[kind][rid]
    if last and Cooldowns[kind][rid] then return { by = last.name } end
    return nil
end

-- "Name is out on the trail" style refusal text for a busy drive
function DriveBusyText(rid, kind)
    local w = DriveWho(rid, kind)
    if not w or not w.by then return L('onCooldown') end
    if w.running then return L(kind == 'herd' and 'herdTakenBy' or 'sellTakenBy', w.by) end
    return L('driveDoneBy', w.by, U.shortTime(left(Cooldowns[kind][rid])))
end

function SendInfo(src)
    local ctx = Ctx(src)
    if not ctx then return end
    local r, role = RanchOf(ctx.charid, ctx.identifier)
    local base = { charid = ctx.charid, job = ctx.job, grade = ctx.grade }
    if not r then
        base.id = 0
        TriggerClientEvent('pup_ranchero:info', src, base)
        return
    end
    local sMilk, sEggs = StoreTotals(r.id)
    if not Ranches[r.id] then return SendInfo(src) end -- deleted while we waited

    local hired = {}
    for _, h in ipairs(r.hired) do
        if not (r.owned == 1 and h.charidentifier == r.charid) then
            hired[#hired + 1] = { charidentifier = h.charidentifier, name = h.name, manager = h.manager }
        end
    end
    local choreLeft = {}
    local mine = Cooldowns.chore[r.id] and Cooldowns.chore[r.id][ctx.charid] or {}
    for name in pairs(Config.Chores.list) do
        local l = left(mine[name])
        if l > 0 then choreLeft[name] = l end
    end
    local fresh = {}
    for k in pairs(FreshHerds[r.id] or {}) do fresh[k] = true end

    base.id = r.id
    base.role = role
    base.ranchName = r.name
    base.ranchTax = r.tax
    base.ranchQuality = r.env
    base.ledger = r.ledger
    base.milk = r.milk + sMilk
    base.eggs = r.eggs + sEggs
    base.uncollectedMilk = r.milk
    base.uncollectedEggs = r.eggs
    base.dog = r.dog
    base.ranchOwner = r.charid
    base.hired = hired
    base.trail = r.trail
    base.cattle = r.cattle
    base.cattleQuality = r.qcattle
    base.dist = r.dist
    base.chores = r.chores
    base.cows = r.cows
    base.chickens = r.chickens
    base.coords = r.coords
    base.herding = r.herding == 1
    base.herdLeft = r.herding == 1 and (Cooldowns.herd[r.id] and left(Cooldowns.herd[r.id]) or -1) or 0
    base.selling = r.selling == 1
    base.sellLeft = r.selling == 1 and (Cooldowns.sell[r.id] and left(Cooldowns.sell[r.id]) or -1) or 0
    base.herdBy = DriveWho(r.id, 'herd')
    base.sellBy = DriveWho(r.id, 'sell')
    base.milkLeft = left(Cooldowns.milk[r.id] and Cooldowns.milk[r.id][ctx.charid])
    base.eggLeft = left(Cooldowns.eggs[r.id] and Cooldowns.eggs[r.id][ctx.charid])
    base.choreLeft = choreLeft
    base.fresh = fresh
    TriggerClientEvent('pup_ranchero:info', src, base)
end

-- refresh every online member of a ranch (and anyone else listed)
function RefreshRanch(r, ...)
    local done = {}
    for _, s in ipairs({ ... }) do
        if s and not done[s] then done[s] = true; SendInfo(s) end
    end
    if not r then return end
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        if not done[s] then
            local ctx = Ctx(s)
            if ctx and RoleIn(r, ctx.charid, ctx.identifier) then
                done[s] = true
                SendInfo(s)
            end
        end
    end
end

function RefreshChar(charid)
    local s = charid and SrcOfChar(charid)
    if s then SendInfo(s) end
end

------------------------------------------------------------------------------
-- ranch-wide drive flags and their cooldowns
------------------------------------------------------------------------------
local flagGen = { herd = {}, sell = {} }

function SetDriveFlag(r, kind, on)
    local col = kind == 'herd' and 'herding' or 'selling'
    r[col] = on and 1 or 0
    if not on then Cooldowns[kind][r.id] = nil end
    flagGen[kind][r.id] = (flagGen[kind][r.id] or 0) + 1
    Save(r, col)
end

-- who: name of the driver, shown with the cooldown
function StartDriveCooldown(r, kind, who)
    if who then LastDrive[kind][r.id] = { name = who, at = os.time() } end
    local col = kind == 'herd' and 'herding' or 'selling'
    local secs = kind == 'herd' and Config.Herding.cooldown or Config.Sales.cooldown
    r[col] = 1
    Save(r, col)
    Cooldowns[kind][r.id] = os.time() + secs
    flagGen[kind][r.id] = (flagGen[kind][r.id] or 0) + 1
    local gen, rid = flagGen[kind][r.id], r.id
    SetTimeout(secs * 1000, function()
        local cur = Ranches[rid]
        if cur and flagGen[kind][rid] == gen then
            cur[col] = 0
            Cooldowns[kind][rid] = nil
            Save(cur, col)
            RefreshRanch(cur)
        end
    end)
end
