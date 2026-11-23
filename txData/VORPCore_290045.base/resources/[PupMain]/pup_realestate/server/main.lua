-- pup_realestate | server core: state, players, persistence, broadcasting, net plumbing

Core = exports.vorp_core:GetCore()
RES = GetCurrentResourceName()

S = {
    ready = false,
    houses = {},      -- id -> house
    delisted = {},    -- id -> raw row of an unowned $0 house (kept out of the game)
    motels = {},      -- row id -> { id, motel, owner, slots }
    players = {},     -- src -> { charid, inside, near = {}, ... }
    near = {},        -- house id -> { [src] = true }
    occupants = {},   -- house id -> { [src] = true }
    knocks = {},      -- house id -> { [src] = os.time() }
    passes = {},      -- src -> { house, expires }
    locks = {},       -- house id -> { src, at }
    viewing = {},     -- house id -> expiry (os.time)
    openStash = {},   -- src -> row id
    auctioned = {},   -- house id -> auction id
}

function Dbg(fmt, ...)
    if Config.Debug then print(('^5[pup_realestate]^7 ' .. fmt):format(...)) end
end

function Warn(fmt, ...)
    print(('^3[pup_realestate]^7 ' .. fmt):format(...))
end

function Now() return os.time() end

function Tip(src, text, ms)
    if not src or src <= 0 then return end
    TriggerClientEvent('vorp:TipRight', src, text, ms or 4000)
end

function TipBottom(src, text, ms)
    if not src or src <= 0 then return end
    TriggerClientEvent('vorp:TipBottom', src, text, ms or 4000)
end

local function decode(s, fallback)
    if type(s) ~= 'string' or s == '' then return fallback end
    local ok, v = pcall(json.decode, s)
    if ok and v ~= nil then return v end
    return fallback
end
S.decode = decode

-- character snapshot (fresh every call; vorp builds a new table each time)
function S.char(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local ok, user = pcall(Core.getUser, src)
    if not ok or not user then return nil end
    local c = user.getUsedCharacter
    if not c then return nil end
    local charid = tonumber(c.charIdentifier)
    if not charid or charid <= 0 then return nil end
    return {
        src = src,
        c = c,
        charid = charid,
        ident = tostring(c.identifier or ''),
        name = ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        job = tostring(c.job or ''),
        grade = tonumber(c.jobGrade) or 0,
        group = tostring(user.getGroup or c.group or 'user'),
        money = tonumber(c.money) or 0,
    }
end

function S.discordId(src)
    local id = GetPlayerIdentifierByType(tostring(src), 'discord')
    if id then return (id:gsub('^discord:', '')) end
    return nil
end

function S.online(src)
    return src and GetPlayerName(tostring(src)) ~= nil
end

-- the online source of a character id, if any
function S.sourceOf(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    for src, p in pairs(S.players) do
        if p.charid == charid and S.online(src) then return src end
    end
    for _, sid in ipairs(GetPlayers()) do
        local ch = S.char(tonumber(sid))
        if ch and ch.charid == charid then return ch.src end
    end
    return nil
end

function S.player(src)
    local p = S.players[src]
    if not p then
        p = { near = {}, rate = {} }
        S.players[src] = p
    end
    return p
end

-- cash helpers: check and change in one go, with no wait in between
function S.takeCash(ch, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local fresh = S.char(ch.src)
    if not fresh or fresh.charid ~= ch.charid then return false end
    if fresh.money < amount then return false end
    fresh.c.removeCurrency(0, amount)
    return true
end

function S.giveCash(ch, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local fresh = S.char(ch.src)
    if not fresh or fresh.charid ~= ch.charid then return false end
    fresh.c.addCurrency(0, amount)
    return true
end

-- roles
function S.isGroupAdmin(ch)
    return ch and (ch.group == 'admin' or ch.group == 'superadmin')
end

function S.isHouseAdmin(ch)
    if not ch then return false end
    if S.isGroupAdmin(ch) then return true end
    if U.inList(Config.Jobs.admin, ch.job) then return true end
    if GetResourceState('vorp_admin') == 'started' then
        local ok, allowed = pcall(function() return exports.vorp_admin:allowedToExecuteAction(ch.src, 'manage_housing') end)
        if ok and allowed then return true end
    end
    return false
end

function S.isAuctionRealtor(ch)
    return ch and U.inList(Config.Jobs.auctionRealtors, ch.job)
end

function S.canCreate(ch)
    if not ch then return false end
    if ch.job == Config.Jobs.realtor or S.isGroupAdmin(ch) or S.isHouseAdmin(ch) then return true end
    return Config.Jobs.realtorsMayCreate and S.isAuctionRealtor(ch) or false
end

function S.canDeleteUnsold(ch)
    if not ch then return false end
    if ch.job == Config.Jobs.realtor and ch.grade >= Config.Jobs.realtorDeleteGrade then return true end
    return S.isGroupAdmin(ch)
end

function S.isOwner(h, charid)
    return h and h.owned and charid and h.buyerChar == charid
end

function S.isKeyholder(h, charid)
    if not h or not h.owned or not charid then return false end
    for _, k in ipairs(h.keys) do
        if tonumber(k.charidentifier or k.charid) == charid then return true end
    end
    return false
end

function S.hasAccess(h, charid)
    return S.isOwner(h, charid) or S.isKeyholder(h, charid)
end

-- keyholder rule switches (owner always passes)
function S.mayKeyholder(h, charid, rule)
    if S.isOwner(h, charid) then return true end
    return S.isKeyholder(h, charid) and Config.Rules[rule] ~= false
end

function S.ownedCount(charid)
    local n = 0
    for _, h in pairs(S.houses) do
        if h.owned and h.buyerChar == charid then n = n + 1 end
    end
    return n
end

-- persistence: in-memory state is the truth, the row follows it in order
local COLUMN = {
    kind = { 'type', function(h) return h.kind end },
    doors = { 'primarydoor', function(h) return json.encode(h.doors) end },
    other = { 'otherdoors', function(h) return json.encode(h.other) end },
    range = { 'range', function(h) return h.range end },
    owned = { 'owned', function(h) return h.owned and 1 or 0 end },
    seller = { 'selleridentifier', function(h) return h.sellerIdent or '' end },
    sellerChar = { 'sellercharidentifier', function(h) return h.sellerChar or 0 end },
    ledger = { 'ledger', function(h) return h.ledger end },
    tax = { 'tax', function(h) return h.tax end },
    repo = { 'repoed', function(h) return h.repo and 1 or 0 end },
    slots = { 'invspace', function(h) return h.slots end },
    upgrade = { 'upgrade', function(h) return h.upgrade end },
    keys = { 'keyholders', function(h) return json.encode(h.keys) end },
    changing = { 'changingroom', function(h) return h.changing and json.encode(h.changing) or '[]' end },
    stash = { 'inventorylocation', function(h) return h.stash and json.encode(h.stash) or '[]' end },
    furniture = { 'furniture', function(h) return json.encode(h.furniture) end },
    price = { 'price', function(h) return h.price end },
    buyer = { 'buyeridentifier', function(h) return h.buyerIdent or '0' end },
    buyerChar = { 'buyercharidentifier', function(h) return h.buyerChar or 0 end },
    taxledger = { 'taxledger', function(h) return h.taxledger end },
}

local function flush(h)
    h._saving = true
    while next(h._dirty) do
        local fields = h._dirty
        h._dirty = {}
        local sets, params = {}, {}
        for f in pairs(fields) do
            local col = COLUMN[f]
            if col then
                sets[#sets + 1] = ('`%s` = ?'):format(col[1])
                params[#params + 1] = col[2](h)
            end
        end
        if #sets > 0 then
            params[#params + 1] = h.id
            local ok, err = pcall(MySQL.update.await, ('UPDATE playerhousing SET %s WHERE id = ?'):format(table.concat(sets, ', ')), params)
            if not ok then Warn('saving house %s failed: %s', h.id, tostring(err)) end
        end
    end
    h._saving = false
end

function S.save(h, ...)
    if not h or h.deleted then return end
    for i = 1, select('#', ...) do
        h._dirty[select(i, ...)] = true
    end
    if not h._saving then CreateThread(function() flush(h) end) end
end

-- what clients may know about a house (no Steam identifiers, no ledgers, no webhook)
function S.public(h)
    local viewingDoors = S.viewing[h.id] and S.viewing[h.id] > Now() and not h.owned
    local function door(d)
        if type(d) ~= 'table' then return d end
        local c = {}
        for k, v in pairs(d) do c[k] = v end
        if viewingDoors and c.locked ~= nil then c.locked = false end
        return c
    end
    local doors, other = {}, {}
    for i, d in ipairs(h.doors) do doors[i] = door(d) end
    for i, d in ipairs(h.other) do other[i] = door(d) end
    local keys = {}
    for i, k in ipairs(h.keys) do
        keys[i] = { charid = tonumber(k.charidentifier or k.charid), name = k.name }
    end
    return {
        id = h.id, kind = h.kind, doors = doors, other = other,
        range = h.range, price = h.price, tax = h.tax, slots = h.slots, upgrade = h.upgrade,
        furniture = h.furniture, changing = h.changing, stash = h.stash,
        owned = h.owned, owner = h.owned and h.buyerChar or 0, keys = keys, repo = h.repo,
        viewing = viewingDoors or false,
    }
end

function S.fullList()
    local list = {}
    for _, h in pairs(S.houses) do list[#list + 1] = S.public(h) end
    return list
end

function S.sendFull(target)
    TriggerClientEvent('pup_realestate:cl_full', target or -1, S.fullList())
end

-- one house to everybody
function S.sendHouse(h, refresh)
    TriggerClientEvent('pup_realestate:cl_house', -1, S.public(h), refresh and 1 or 0)
end

-- one house to the players near it plus one extra player
function S.sendHouseNear(h, refresh, extra)
    local data = S.public(h)
    local sent = {}
    local list = S.near[h.id]
    if list then
        for src in pairs(list) do
            if S.online(src) then
                TriggerClientEvent('pup_realestate:cl_house', src, data, refresh and 1 or 0)
                sent[src] = true
            else
                list[src] = nil
            end
        end
    end
    if extra and not sent[extra] then
        TriggerClientEvent('pup_realestate:cl_house', extra, data, refresh and 1 or 0)
    end
end

function S.sendRemoved(id)
    TriggerClientEvent('pup_realestate:cl_removed', -1, id)
end

-- net plumbing: every handler gets a validated source and character, waits for boot,
-- and is rate-limited per player and event
local function throttled(src, name, gap)
    local p = S.player(src)
    local now = GetGameTimer()
    local last = p.rate[name]
    if last and now - last < gap then return true end
    p.rate[name] = now
    return false
end

local function waitReady()
    local t = 0
    while not S.ready and t < 60000 do
        Wait(250)
        t = t + 250
    end
    return S.ready
end

function Net(name, gap, fn)
    RegisterNetEvent('pup_realestate:' .. name, function(...)
        local src = tonumber(source)
        if not src or src <= 0 then return end
        if throttled(src, name, gap or 500) then return end
        if not waitReady() then return end
        local ch = S.char(src)
        if not ch then return end
        local ok, err = pcall(fn, src, ch, ...)
        if not ok then Warn('%s failed: %s', name, tostring(err)) end
    end)
end

-- request/answer: the first argument is the client's request id, and the handler's
-- return values are always sent back (nil on refusal) so the client never hangs
function Rpc(name, gap, fn)
    RegisterNetEvent('pup_realestate:' .. name, function(reqId, ...)
        local src = tonumber(source)
        if not src or src <= 0 then return end
        reqId = U.int(reqId)
        if not reqId then return end
        local function answer(...) TriggerClientEvent('pup_realestate:cl_reply', src, reqId, ...) end
        if throttled(src, name, gap or 500) then return answer() end
        if not waitReady() then return answer() end
        local ch = S.char(src)
        if not ch then return answer() end
        local res = table.pack(pcall(fn, src, ch, ...))
        if not res[1] then
            Warn('%s failed: %s', name, tostring(res[2]))
            return answer()
        end
        answer(table.unpack(res, 2, res.n))
    end)
end

-- house lookup helpers used by handlers
function S.house(id)
    id = U.int(id)
    return id and S.houses[id] or nil
end

function S.pedPos(src)
    local ped = GetPlayerPed(tostring(src))
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- is the player recorded inside this row's interior
function S.insideRow(src, rowId)
    local p = S.players[src]
    return p and p.inside == rowId
end

-- a world position counts as part of the house: within its range of the front door,
-- or (for teleporter houses) inside its interior while the player is in there
function S.inHouseArea(src, h, pos)
    if not pos then return false end
    if h.kind == KIND_TELE then
        if not S.insideRow(src, h.id) then return false end
        local int = U.interior(h)
        if not int then return false end
        return #(pos - int.entry) <= (tonumber(int.range) or 50.0)
    end
    local door = U.frontDoor(h)
    if not door then return false end
    return #(pos - door) <= math.max(0, tonumber(h.range) or 0)
end

-- menu locks
function S.lockHolder(id)
    local l = S.locks[id]
    if not l then return nil end
    if not S.online(l.src) or Now() - l.at > Config.Timers.menuLock then
        S.locks[id] = nil
        return nil
    end
    return l.src
end

function S.releaseLocks(src, id)
    for hid, l in pairs(S.locks) do
        if l.src == src and (not id or id == hid) then S.locks[hid] = nil end
    end
end

Rpc('sv_lock', 200, function(src, ch, id, take)
    local h = S.house(id)
    if not h then return false end
    if take then
        if h.owned and not S.hasAccess(h, ch.charid) then return false end
        local holder = S.lockHolder(h.id)
        if holder and holder ~= src then return false, 'busy' end
        S.locks[h.id] = { src = src, at = Now() }
        return true
    end
    local holder = S.lockHolder(h.id)
    if holder == src then S.locks[h.id] = nil end
    return true
end)

Net('sv_unlockAll', 200, function(src)
    S.releaseLocks(src)
end)

-- the player's near list (door and furniture updates only go to players near a house)
Net('sv_near', 100, function(src, _, ids)
    if type(ids) ~= 'table' then return end
    local p = S.player(src)
    local before = p.near
    for id in pairs(before) do
        if S.near[id] then S.near[id][src] = nil end
    end
    p.near = {}
    local n = 0
    for _, v in ipairs(ids) do
        local id = U.int(v)
        if id and S.houses[id] and n < 64 then
            n = n + 1
            p.near[id] = true
            S.near[id] = S.near[id] or {}
            S.near[id][src] = true
            -- door toggles and furniture changes only go to players near a house, so a player
            -- who just arrived gets the current state (their copy may be stale)
            if not before[id] then
                TriggerClientEvent('pup_realestate:cl_house', src, S.public(S.houses[id]), 1)
            end
        end
    end
end)

Rpc('sv_job', 1000, function(_, ch)
    return { job = ch.job, grade = ch.grade, group = ch.group }
end)

-- forget everything about a player (disconnect or character switch)
function S.dropPlayer(src, keepRecord)
    local p = S.players[src]
    S.releaseLocks(src)
    for id, list in pairs(S.near) do list[src] = nil; if not next(list) then S.near[id] = nil end end
    for id, list in pairs(S.occupants) do list[src] = nil; if not next(list) then S.occupants[id] = nil end end
    for id, list in pairs(S.knocks) do list[src] = nil; if not next(list) then S.knocks[id] = nil end end
    S.passes[src] = nil
    if S.openStash[src] then
        if S.markReport then S.markReport(S.openStash[src], src, S.stashActor and S.stashActor[src]) end
        S.openStash[src] = nil
    end
    if S.stashActor then S.stashActor[src] = nil end
    if p then
        p.inside = nil
        p.near = {}
        if not keepRecord then S.players[src] = nil end
    end
end

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if src then S.dropPlayer(src) end
end)
