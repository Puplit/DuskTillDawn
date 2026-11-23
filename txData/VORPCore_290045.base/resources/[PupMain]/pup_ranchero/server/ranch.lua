-- pup_ranchero | buying, the ranch menu lock, staff, ledger, spots, trail, upgrades, cattle purchases

local REACH = Config.Reach

------------------------------------------------------------------------------
-- data requests
------------------------------------------------------------------------------
Rpc('requestInfo', { gap = 1000, noChar = true }, function(ctx)
    TriggerClientEvent('pup_ranchero:list', ctx.src, ListPayload())
    if ctx.charid then SendInfo(ctx.src) end
    return true
end)

------------------------------------------------------------------------------
-- menu lock: off by default (Config.Timers.menuLock = 0), so the whole ranch can use the menu
-- at once. Every action re-checks the ledger, stock and role on the server, so nothing can be
-- spent twice. Set menuLock above 0 to go back to one player per ranch.
------------------------------------------------------------------------------
MenuLocks = {} -- [rid] = { src, expires }

local function lockOn()
    return (tonumber(Config.Timers.menuLock) or 0) > 0
end

local function lockFree(rid, src)
    local l = MenuLocks[rid]
    if not l or l.src == src then return true end
    if os.time() >= l.expires or not GetPlayerName(l.src) then return true end
    return false
end

function ReleaseLocksOf(src)
    for rid, l in pairs(MenuLocks) do
        if l.src == src then MenuLocks[rid] = nil end
    end
end

Rpc('openMenu', { gap = 800 }, function(ctx)
    local r = MemberRanch(ctx)
    if not r then return false end
    if lockOn() then
        if not lockFree(r.id, ctx.src) then
            Notify(ctx.src, L('menuInUse'))
            return false
        end
        MenuLocks[r.id] = { src = ctx.src, expires = os.time() + Config.Timers.menuLock }
    end
    SendInfo(ctx.src)
    return true
end)

Rpc('closeMenu', { gap = 0 }, function(ctx)
    ReleaseLocksOf(ctx.src)
    return true
end)

------------------------------------------------------------------------------
-- buying a ranch
------------------------------------------------------------------------------
Rpc('buyRanch', { gap = 2000 }, function(ctx, rid)
    local r = Ranches[tonumber(rid) or -1]
    if not r then return false end
    if r.owned == 1 then Notify(ctx.src, L('alreadyOwned')) return false end
    if RanchOf(ctx.charid, ctx.identifier) then Notify(ctx.src, L('youAlreadyRanch')) return false end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    local price = U.cents(r.price)
    if Cash(ctx.src) + 1e-6 < price then Notify(ctx.src, L('noCash')) return false end
    if price > 0 then ctx.char.removeCurrency(0, price) end

    r.identifier, r.charid, r.owned, r.repoed = ctx.identifier, ctx.charid, 1, 0
    Save(r, 'identifier', 'charidentifier', 'owned', 'repoed')

    Notify(ctx.src, L('gotRanch'))
    Activity(r.id, 'BUY', ('bought %s for $%s'):format(RanchTitle(r), U.money(price)), ctx.name)
    LogPlain('general', r, 'Ranch Purchased', {
        ('Buyer: %s'):format(ctx.name), ('Ranch ID: %d'):format(r.id), ('Name: %s'):format(r.name), ('Price: $%s'):format(U.money(price)),
    })
    SendInfo(ctx.src)
    BroadcastList()
    return true
end)

------------------------------------------------------------------------------
-- staff
------------------------------------------------------------------------------
local function staffEmbed(r, title, color, personName, personCid, byName)
    LogEmbed(r, title, color, {
        { 'Person', ('%s (char %d)'):format(personName, personCid), true },
        { 'By', byName, true },
        { 'Ranch', ('%s (#%d)'):format(r.name, r.id), true },
        { 'Staff now', StaffCount(r), true },
    })
end

Rpc('hire', { gap = 1500 }, function(ctx, targetId)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    local tid = math.floor(tonumber(targetId) or 0)
    if tid <= 0 then Notify(ctx.src, L('wrongId')) return false end
    local t = Ctx(tid)
    if not t then Notify(ctx.src, L('wrongId')) return false end
    if RanchOf(t.charid, t.identifier) then Notify(ctx.src, L('alreadyHired')) return false end

    r.hired[#r.hired + 1] = { identifier = t.identifier, charidentifier = t.charid, name = t.name, manager = false }
    Save(r, 'hired')
    Notify(ctx.src, L('hiredName', t.name))
    Notify(t.src, L('gotHired'))
    Activity(r.id, 'HIRE', ('hired %s'):format(t.name), ctx.name)
    staffEmbed(r, 'Ranch Hire', LogColors.green, t.name, t.charid, ctx.name)
    RefreshRanch(r, t.src)
    return true
end)

-- the hired list without Steam ids, managers first then by name
Rpc('staffList', { gap = 500 }, function(ctx)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then return false end
    local list = {}
    for _, h in ipairs(r.hired) do
        if not (r.owned == 1 and h.charidentifier == r.charid) then
            list[#list + 1] = { charid = h.charidentifier, name = h.name, manager = h.manager }
        end
    end
    table.sort(list, function(a, b)
        if a.manager ~= b.manager then return a.manager end
        return a.name:lower() < b.name:lower()
    end)
    return list
end)

Rpc('fire', { gap = 1000 }, function(ctx, charid)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    local cid = math.floor(tonumber(charid) or 0)
    if cid == r.charid then return false end
    local idx, h = HiredIndex(r, cid)
    if not idx then return false end
    table.remove(r.hired, idx)
    Save(r, 'hired')
    EndDrivesOfChar(cid, r.id)
    Notify(ctx.src, L('firedName', h.name))
    Activity(r.id, 'FIRE', ('let %s go'):format(h.name), ctx.name)
    staffEmbed(r, 'Ranch Fire', LogColors.red, h.name, cid, ctx.name)
    RefreshRanch(r)
    RefreshChar(cid)
    return true
end)

Rpc('setManager', { gap = 500 }, function(ctx, charid, makeManager)
    local r, role = MemberRanch(ctx)
    if not r or role ~= 'owner' then Notify(ctx.src, L('notAllowed')) return false end
    local _, h = HiredIndex(r, math.floor(tonumber(charid) or 0))
    if not h then return false end
    h.manager = makeManager == true
    Save(r, 'hired')
    Notify(ctx.src, L('managersUpdated'))
    RefreshRanch(r)
    return true
end)

Rpc('quit', { gap = 2000 }, function(ctx)
    local r, role = MemberRanch(ctx)
    if not r or role == 'owner' then return false end
    local idx = HiredIndex(r, ctx.charid)
    if not idx then return false end
    table.remove(r.hired, idx)
    Save(r, 'hired')
    ReleaseLocksOf(ctx.src)
    EndDrivesOfChar(ctx.charid, r.id)
    Activity(r.id, 'QUIT', 'left the ranch', ctx.name)
    staffEmbed(r, 'Ranch Hand Quit', LogColors.orange, ctx.name, ctx.charid, ctx.name)
    RefreshRanch(r, ctx.src)
    return true
end)

Rpc('transfer', { gap = 3000 }, function(ctx, targetId)
    if not Config.General.allowTransfer then return false end
    local r, role = MemberRanch(ctx)
    if not r or role ~= 'owner' then Notify(ctx.src, L('notAllowed')) return false end
    local tid = math.floor(tonumber(targetId) or 0)
    local t = tid > 0 and tid ~= ctx.src and Ctx(tid) or nil
    if not t or t.charid == ctx.charid then Notify(ctx.src, L('wrongId')) return false end
    local other = RanchOf(t.charid, t.identifier)
    if other and other.id ~= r.id then Notify(ctx.src, L('alreadyHired')) return false end
    local idx = HiredIndex(r, t.charid)
    if idx then table.remove(r.hired, idx) end
    -- a stray owner entry in the hired list goes too: the old owner leaves completely
    local oldIdx = HiredIndex(r, ctx.charid)
    if oldIdx then table.remove(r.hired, oldIdx) end

    r.identifier, r.charid, r.webhook = t.identifier, t.charid, nil
    Save(r, 'identifier', 'charidentifier', 'hired', 'webhook')
    ReleaseLocksOf(ctx.src)
    -- the old owner leaves completely; the hands stay, so their drives carry on under the new owner
    EndDrivesOfChar(ctx.charid, r.id)
    RebaseRanchDrives(r)

    Notify(ctx.src, L('transferred'))
    Notify(t.src, L('gotRanch'))
    Activity(r.id, 'TRANSFER', ('signed the ranch over to %s'):format(t.name), ctx.name)
    LogPlain('general', r, 'Ranch Transferred', {
        ('From: %s'):format(ctx.name), ('Ranch ID: %d'):format(r.id), ('To: %s'):format(t.name),
    })
    RefreshRanch(r, ctx.src, t.src)
    return true
end)

local WEBHOOK_PREFIXES = {
    'https://discord.com/api/webhooks/', 'https://discordapp.com/api/webhooks/',
    'https://ptb.discord.com/api/webhooks/', 'https://canary.discord.com/api/webhooks/',
}

Rpc('setWebhook', { gap = 2000 }, function(ctx, url)
    local r, role = MemberRanch(ctx)
    if not r or role ~= 'owner' then Notify(ctx.src, L('notAllowed')) return false end
    url = tostring(url or ''):gsub('%s', '')
    local ok = #url <= 256
    if ok then
        ok = false
        local lower = url:lower()
        for _, p in ipairs(WEBHOOK_PREFIXES) do
            if lower:sub(1, #p) == p then ok = true break end
        end
    end
    if not ok then Notify(ctx.src, L('webhookBad')) return false end
    r.webhook = url
    Save(r, 'webhook')
    Notify(ctx.src, L('webhookSet'))
    return true
end)

------------------------------------------------------------------------------
-- ledger
------------------------------------------------------------------------------
local function amountOf(v)
    local n = U.num(v)
    if not n or n <= 0 then return nil end
    n = U.cents(n)
    if n <= 0 or n > 1e9 then return nil end
    return n
end

Rpc('withdraw', { gap = 1000 }, function(ctx, value)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    local amount = amountOf(value)
    if not amount or amount > r.ledger + 1e-6 then Notify(ctx.src, L('invalidAmount')) return false end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    r.ledger = U.cents(r.ledger - amount)
    Save(r, 'ledger')
    ctx.char.addCurrency(0, amount)
    Notify(ctx.src, L('withdrew', U.money(amount)))
    Activity(r.id, 'WITHDRAW', ('$%s (ledger $%s)'):format(U.money(amount), U.money(r.ledger)), ctx.name)
    LogLedger(r, 'Ledger Withdrawal', ctx.name, amount)
    RefreshRanch(r)
    return true
end)

Rpc('deposit', { gap = 1000 }, function(ctx, value)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    local amount = amountOf(value)
    if not amount then Notify(ctx.src, L('invalidAmount')) return false end
    if Cash(ctx.src) + 1e-6 < amount then Notify(ctx.src, L('noCash')) return false end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    ctx.char.removeCurrency(0, amount)
    r.ledger = U.cents(r.ledger + amount)
    Save(r, 'ledger')
    Notify(ctx.src, L('deposited', U.money(amount)))
    Activity(r.id, 'DEPOSIT', ('$%s (ledger $%s)'):format(U.money(amount), U.money(r.ledger)), ctx.name)
    LogLedger(r, 'Ledger Deposit', ctx.name, amount)
    RefreshRanch(r)
    return true
end)

------------------------------------------------------------------------------
-- spots: chores, trail, pen and coop
------------------------------------------------------------------------------
local function spotOk(ctx, pos)
    local p = U.coords(pos)
    if not p then return nil end
    local me = PlayerPos(ctx.src)
    if me and U.dist3(me, p) > REACH.register then
        Notify(ctx.src, L('tooFar'))
        return nil
    end
    return p
end

Rpc('setChoreSpot', { gap = 1000 }, function(ctx, chore, pos)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    if type(chore) ~= 'string' or not Config.Chores.list[chore] then return false end
    local p = spotOk(ctx, pos)
    if not p then return false end
    local old = r.chores[chore]
    r.chores[chore] = { loc = p, num = old and old.num or 0 }
    Save(r, 'chores')
    Notify(ctx.src, L('choreSpotSaved'))
    RefreshRanch(r)
    return true
end)

Rpc('setTrail', { gap = 2000 }, function(ctx, points)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    if type(points) ~= 'table' or not r.coords then return false end
    local pts = {}
    for i = 1, 4 do
        pts[i] = U.coords(points[i])
        if not pts[i] then Notify(ctx.src, L('invalidAmount')) return false end
    end
    local me = PlayerPos(ctx.src)
    if me and U.dist3(me, pts[4]) > REACH.register then Notify(ctx.src, L('tooFar')) return false end
    local lim = Config.Herding.trail
    local total, prev = 0, r.coords
    for i = 1, 4 do
        local leg = U.dist2(prev, pts[i])
        if leg <= lim.minLeg or leg > lim.maxLeg then Notify(ctx.src, L('invalidAmount')) return false end
        total = total + leg
        prev = pts[i]
    end
    r.trail = pts
    r.dist = U.clamp(U.round(total / 100), 1, 10)
    Save(r, 'herdtrail', 'dist')
    Notify(ctx.src, L('trailSaved'))
    RefreshRanch(r)
    return true
end)

-- a pen or coop must sit near the ranch: milking starts within Reach.ranch of the ranch point,
-- so a pen placed far away would be paid for and never used
local function enclosureSpot(ctx, r, pos)
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return nil end
    local p = spotOk(ctx, pos)
    if not p then return nil end
    if not r.coords or U.dist3(p, r.coords) > REACH.enclosure then Notify(ctx.src, L('tooFar')) return nil end
    return p
end

-- kind: 'cows' | 'chickens'
local function buyEnclosure(ctx, kind, pos)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    if r[kind] then return false end
    local p = enclosureSpot(ctx, r, pos)
    if not p then return false end
    local cost = kind == 'cows' and Config.Upgrades.cowPen or Config.Upgrades.chickenCoop
    local what = kind == 'cows' and 'Cow pen' or 'Chicken coop'
    if not ChargeLedger(r, ctx, cost, what) then Notify(ctx.src, L('ledgerShort')) return false end
    r[kind] = p
    Save(r, kind)
    Notify(ctx.src, kind == 'cows' and L('boughtPen') or L('boughtCoop'))
    RefreshRanch(r)
    return true
end

Rpc('buyPen', { gap = 2000 }, function(ctx, pos) return buyEnclosure(ctx, 'cows', pos) end)
Rpc('buyCoop', { gap = 2000 }, function(ctx, pos) return buyEnclosure(ctx, 'chickens', pos) end)

Rpc('moveEnclosure', { gap = 1500 }, function(ctx, kind, pos)
    if kind ~= 'cows' and kind ~= 'chickens' then return false end
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    if not r[kind] then return false end
    local p = enclosureSpot(ctx, r, pos)
    if not p then return false end
    r[kind] = p
    Save(r, kind)
    Notify(ctx.src, L('locationSaved'))
    RefreshRanch(r)
    return true
end)

Rpc('buyDog', { gap = 2000 }, function(ctx, model)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    if type(model) ~= 'string' then return false end
    local breed
    for _, b in ipairs(Config.Dog.breeds) do
        if b.model:lower() == model:lower() then breed = b break end
    end
    if not breed then return false end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    if not ChargeLedger(r, ctx, breed.price, 'Herding dog (' .. breed.label .. ')') then Notify(ctx.src, L('ledgerShort')) return false end
    r.dog = breed.model
    Save(r, 'dog')
    Notify(ctx.src, L('boughtDog'))
    RefreshRanch(r)
    return true
end)

------------------------------------------------------------------------------
-- buying cattle (paid from the ledger)
------------------------------------------------------------------------------
function JobAllows(animal, job)
    local a = Config.Animals[animal]
    if not a or not a.job then return false end
    return a.job == 'none' or a.job == job
end

Rpc('buyCattle', { gap = 1500 }, function(ctx, animal, count)
    local r = MemberRanch(ctx)
    if not r then Notify(ctx.src, L('notAllowed')) return false end
    count = tonumber(count)
    if not count or count < 1 or count ~= math.floor(count) then Notify(ctx.src, L('invalidAmount')) return false end
    local a = type(animal) == 'string' and Config.Animals[animal]
    if not a or not a.price or not a.model then return false end
    if not JobAllows(animal, ctx.job) then Notify(ctx.src, L('notAllowed')) return false end
    local have = r.cattle[animal] or 0
    if have + count > Config.Livestock.maxPerType then Notify(ctx.src, L('invalidAmount')) return false end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    local price = a.price * count
    if not ChargeLedger(r, ctx, price, ('%d %s'):format(count, animal)) then Notify(ctx.src, L('ledgerShort')) return false end

    local q = r.qcattle[animal] or 0
    local newQ = have > 0 and (have * q + count * Config.Livestock.boughtQuality) / (have + count) or Config.Livestock.boughtQuality
    r.cattle[animal] = have + count
    r.qcattle[animal] = newQ
    Save(r, 'cattle', 'q_cattle')
    SetFresh(r, animal, true)

    Notify(ctx.src, L('boughtCattle', count, animal, U.money(price)))
    LogPlain('general', r, 'Cattle Purchased', {
        ('Who: %s'):format(ctx.name), ('Count: %d'):format(count), ('Type: %s'):format(animal),
        ('Price: $%s'):format(U.money(price)), ('Ranch ID: %d'):format(r.id),
    })
    Activity(r.id, 'CATTLE_BUY', ('bought %d %s for $%s'):format(count, animal, U.money(price)), ctx.name)
    Stat(ctx, r.id, { cattle_money = -price })
    TriggerClientEvent('pup_ranchero:closeMenus', ctx.src)
    RefreshRanch(r)
    return true
end)
