-- pup_ranchero | herding and sale drives: sessions, checkpoints, kills, settlement, rewards

Drives = {}    -- [src] = drive session (one per player)
Vouchers = {}  -- [src] = { animal, count, rid, expires }

local REACH = Config.Reach

local function timeLimit(d)
    if d.kind == 'herd' then return Config.Herding.timeLimit end
    local lim = Config.Sales.timeLimit
    if d.animal == 'chicken' then lim = lim * Config.Sales.chickenFactor end
    return lim
end
DriveLimit = timeLimit -- core.lua uses it for the "time left" shown to the ranch

local function verdict(src, ok, msg, extra)
    local data = extra or {}
    data.ok, data.msg = ok, msg
    TriggerClientEvent('pup_ranchero:driveOver', src, data)
end

------------------------------------------------------------------------------
-- the drive-failure rule (herding, sales, disconnects, character switches, abandoned drives)
------------------------------------------------------------------------------
-- reportedCount/reportedQuality are what the client claims survived; the rule only lets them go down.
-- Once a drive is live the rule applies to the full count: the server cannot verify a client-reported spawn count.
local function failDrive(d, reportedCount, reportedQuality, detail)
    local r = Ranches[d.rid]
    if not r then return 0 end
    local alive = math.max(0, d.count - d.kills)
    local countCap = alive > 1 and U.round(alive / 2) or 0
    local qualityCap = d.startQ / 2 -- not rounded: a fresh 0.1 herd keeps 0.05
    local keep = math.min(math.max(0, math.floor(tonumber(reportedCount) or 0)), countCap)
    local q = math.min(math.max(0, tonumber(reportedQuality) or 0), qualityCap)
    local survivors = keep
    -- nothing of the drive survived: its quality no longer matters, so animals bought meanwhile keep theirs
    local left = ApplyHerd(r, d.animal, d.count - survivors, survivors > 0 and q or nil)
    StartDriveCooldown(r, d.kind, d.driverName)
    local kind = d.kind == 'herd' and 'HERD_FAIL' or 'SALE_FAIL'
    Activity(r.id, kind, detail or ('the %s drive failed; the herd is down to %d'):format(d.animal, left), d.driverName)
    RefreshRanch(r)
    return left
end

------------------------------------------------------------------------------
-- a drive is only valid while its driver still works the ranch it started on
------------------------------------------------------------------------------
local function stillOnRanch(d, identifier)
    local r = Ranches[d.rid]
    if not r then return false end
    if r.charid ~= d.ownerCharid then return false end -- ownership changed (repossessed, resold, transferred)
    return RoleIn(r, d.charid, identifier) ~= nil
end

-- end a drive with no penalty and no reward: flag cleared, no cooldown, voucher dropped
local function freeEnd(src, d, msg)
    if Drives[src] == d then Drives[src] = nil end
    if Vouchers[src] and Vouchers[src].rid == d.rid then Vouchers[src] = nil end
    local r = Ranches[d.rid]
    if r then
        SetDriveFlag(r, d.kind, false)
        RefreshRanch(r)
    end
    if GetPlayerName(src) then verdict(src, false, msg or L('driveVoided')) end
end

-- called whenever a character is removed from a ranch by any path
function EndDrivesOfChar(charid, rid)
    for src, d in pairs(Drives) do
        if d.charid == charid and (rid == nil or d.rid == rid) then freeEnd(src, d) end
    end
    for src, v in pairs(Vouchers) do
        if v.charid == charid and (rid == nil or v.rid == rid) then Vouchers[src] = nil end
    end
end

-- in-game transfer: the hands keep their places, so their running drives follow the new owner
function RebaseRanchDrives(r)
    for _, d in pairs(Drives) do
        if d.rid == r.id then d.ownerCharid = r.charid end
    end
end

-- called when a ranch loses its owner (repossession, admin clear or transfer)
function EndDrivesOfRanch(rid)
    for src, d in pairs(Drives) do
        if d.rid == rid then freeEnd(src, d) end
    end
    for src, v in pairs(Vouchers) do
        if v.rid == rid then Vouchers[src] = nil end
    end
end

-- vorp_admin world cleanup deletes the drive animals: void every drive, no penalty, no cooldown
AddEventHandler('vorp_admin:worldCleanup', function()
    for src, d in pairs(Drives) do freeEnd(src, d) end
end)

------------------------------------------------------------------------------
-- starting
------------------------------------------------------------------------------
local function startDrive(ctx, kind, animal)
    local r = MemberRanch(ctx)
    if not r then Notify(ctx.src, L('notAllowed')) return false end
    local flag = kind == 'herd' and r.herding or r.selling
    if flag == 1 then Notify(ctx.src, DriveBusyText(r.id, kind), 6000) return false end
    if Drives[ctx.src] then return false end
    local a = type(animal) == 'string' and Config.Animals[animal]
    local owned = a and (r.cattle[animal] or 0) or 0
    if not a or owned <= 0 then return false end
    if kind == 'herd' and not r.trail then Notify(ctx.src, L('needTrail')) return false end
    if kind == 'sell' and Config.Sales.requireHerdAfterPurchase and IsFresh(r.id, animal) then
        Notify(ctx.src, L('freshHerd'), 7000)
        return false
    end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    for _, other in pairs(Drives) do
        if other.rid == r.id and other.animal == animal then Notify(ctx.src, L('onCooldown')) return false end
    end

    local count = math.min(owned, Config.Livestock.maxPerType)
    SetDriveFlag(r, kind, true)
    local d = {
        rid = r.id, kind = kind, animal = animal, count = count, kills = 0,
        driverName = ctx.name, charid = ctx.charid, ownerCharid = r.charid,
        startQ = r.qcattle[animal] or 0, startEnv = r.env, dist = r.dist,
        startedAt = os.time(), trail = r.trail, ranchCoords = r.coords,
        live = false, cp = 0, spawned = nil, modelHash = GetHashKey(a.model),
    }
    Drives[ctx.src] = d
    RefreshRanch(r)
    return {
        kind = kind, animal = animal, count = count, model = a.model, outfit = a.outfit,
        dog = (kind == 'herd' and r.dog ~= '0' and r.dog ~= '') and r.dog or nil,
        trail = r.trail, quality = d.startQ, env = r.env, dist = r.dist, limit = timeLimit(d),
        coords = r.coords,
    }
end

Rpc('herdStart', { gap = 2000 }, function(ctx, animal) return startDrive(ctx, 'herd', animal) end)
Rpc('sellStart', { gap = 2000 }, function(ctx, animal) return startDrive(ctx, 'sell', animal) end)

-- before the animals are out, calling a drive off costs nothing
Rpc('driveCancel', { gap = 500 }, function(ctx)
    local d = Drives[ctx.src]
    if not d or d.live then return false end
    Drives[ctx.src] = nil
    local r = Ranches[d.rid]
    if r then SetDriveFlag(r, d.kind, false); RefreshRanch(r) end
    return true
end)

Rpc('driveLive', { gap = 500 }, function(ctx, spawned)
    local d = Drives[ctx.src]
    if not d or d.live then return false end
    spawned = math.floor(tonumber(spawned) or 0)
    if spawned < 1 then return false end
    d.spawned = math.min(spawned, d.count)
    if d.spawned < d.count then
        print(('[pup_ranchero] %s (%d) went live with %d of %d %s spawned; a failure still counts all %d')
            :format(ctx.name, ctx.src, d.spawned, d.count, d.animal, d.count))
    end
    d.live = true
    d.liveAt = os.time()
    -- the rest of the ranch now sees who is out and how long is left
    local r = Ranches[d.rid]
    if r then SetTimeout(0, function() RefreshRanch(r) end) end
    return true
end)

Rpc('driveCheckpoint', { gap = 300 }, function(ctx, index)
    local d = Drives[ctx.src]
    if not d or not d.live or d.kind ~= 'herd' then return false end
    index = math.floor(tonumber(index) or 0)
    if index ~= d.cp + 1 or index > 6 then return false end
    local point = d.trail[U.ROUTE[index]]
    if not Near(ctx.src, point, REACH.checkpoint) then return false end
    d.cp = index
    return true
end)

------------------------------------------------------------------------------
-- kills by other players
------------------------------------------------------------------------------
-- no gap: several animals can die at once, and kills are capped at the number spawned anyway
Rpc('driveKill', { gap = 0 }, function(ctx, animal, killerId)
    if not Config.Livestock.killReward then return false end
    local d = Drives[ctx.src]
    if not d or not d.live or animal ~= d.animal then return false end
    if d.kills >= (d.spawned or d.count) then return false end
    d.kills = d.kills + 1 -- counts whatever the outcome: naming a friend still costs the animal

    local kid = math.floor(tonumber(killerId) or 0)
    if kid <= 0 or kid == ctx.src then return true end
    local k = Ctx(kid)
    if not k then return true end
    local r = Ranches[d.rid]
    if not r or RoleIn(r, k.charid, k.identifier) then return true end
    local kp, mp = PlayerPos(kid), PlayerPos(ctx.src)
    if not kp or not mp or U.dist3(kp, mp) > REACH.bounty then return true end

    local a = Config.Animals[d.animal]
    local reward = U.round((a.price or 0) / 2)
    if reward > 0 then k.char.addCurrency(0, reward) end
    Notify(kid, L('bounty', d.animal, U.money(reward)))
    LogPlain('general', r, 'Herd Animal Killed', {
        ('Killer: %s %s'):format(k.name, L('logKilledHerd')), ('Type: %s'):format(d.animal), ('Drive of: %s'):format(d.driverName),
    }, false)
    Activity(r.id, 'PVP_LOSS', ('%s killed a %s on the drive'):format(k.name, d.animal), d.driverName)
    return true
end)

------------------------------------------------------------------------------
-- what the server itself sees of a live drive: the driver's own script animals of the drive's model
------------------------------------------------------------------------------
local WATCH_RADIUS <const> = 150.0

local function sameHash(a, b) return a and b and (a & 0xFFFFFFFF) == (b & 0xFFFFFFFF) end

local function scriptPed(ent)
    local ok, kind = pcall(GetEntityPopulationType, ent)
    return not ok or kind == nil or kind == 7 -- 7 = created by a script
end

local function watchDrive(src, d)
    local me = PlayerPos(src)
    if not me then return end
    d.seen, d.dead = d.seen or {}, d.dead or {}
    for _, ent in ipairs(GetAllPeds()) do
        if d.seen[ent] then
            if GetEntityHealth(ent) <= 0 then d.dead[ent] = true end
        elseif sameHash(GetEntityModel(ent), d.modelHash) and NetworkGetEntityOwner(ent) == src
            and GetEntityHealth(ent) > 0 and scriptPed(ent) then
            local c = GetEntityCoords(ent)
            if U.dist3(me, { x = c.x, y = c.y, z = c.z }) <= WATCH_RADIUS then d.seen[ent] = true end
        end
    end
end

CreateThread(function()
    while true do
        Wait(2000)
        if Config.Livestock.verifyAnimals ~= false then
            for src, d in pairs(Drives) do
                if d.live then pcall(watchDrive, src, d) end
            end
        end
    end
end)

-- the most animals that can have arrived: never more than the server saw alive, minus those it saw die
local function seenCap(ctx, d, alive)
    if Config.Livestock.verifyAnimals == false then return alive, 0 end
    local seen, dead = 0, 0
    for _ in pairs(d.seen or {}) do seen = seen + 1 end
    for _ in pairs(d.dead or {}) do dead = dead + 1 end
    if seen == 0 then
        print(('[pup_ranchero] %s (%d): the server saw none of the %s on this drive'):format(ctx.name, ctx.src, d.animal))
        if Config.Livestock.unseenAsFailed then return 0, 0 end
        return alive, 0
    end
    return math.max(0, math.min(alive, seen - dead)), dead
end

------------------------------------------------------------------------------
-- settlement
------------------------------------------------------------------------------
local function pathLength(d)
    local t, total = d.trail, U.dist2(d.ranchCoords, d.trail[1])
    total = total + 2 * (U.dist2(t[1], t[2]) + U.dist2(t[2], t[3]) + U.dist2(t[3], t[4]))
    return total
end

local function settleHerd(ctx, d, report)
    local r = Ranches[d.rid]
    if not r then return verdict(ctx.src, false, L('reasonFailed')) end
    local spawned = d.spawned or d.count
    local unspawned = math.max(0, d.count - spawned)
    local alive = math.max(0, spawned - d.kills)

    if report.failed then
        local left = failDrive(d, report.left, report.quality)
        return verdict(ctx.src, false, left > 0 and L('driveFailedLeft', left) or L('driveLost'))
    end

    local cap, seenDead = seenCap(ctx, d, alive)
    local arrived = U.clamp(math.floor(tonumber(report.arrived) or 0), 0, cap)
    local reason
    if arrived <= 0 then
        reason = L('reasonNoneHome')
    elseif d.cp < 6 then
        reason = L('reasonCheckpoints')
    elseif os.time() - d.startedAt < math.max(Config.Herding.minSeconds, d.count + pathLength(d) / Config.Herding.sanitySpeed) then
        reason = L('reasonTooFast')
    elseif not Near(ctx.src, d.trail[1], REACH.driveEnd) then
        reason = L('reasonFarAway')
    end
    if reason then
        local left = failDrive(d, arrived, report.quality)
        return verdict(ctx.src, false, L('herdRejected', reason, left))
    end

    local lv = Config.Livestock
    local ceiling = U.herdQuality(d.startQ, arrived, d.dist, math.max(d.startEnv, r.env)) * 1.01 + 0.01
    ceiling = math.min(ceiling, lv.maxQuality)
    local q = math.min(math.max(0, tonumber(report.quality) or 0), ceiling)
    local survivors = arrived + unspawned
    ApplyHerd(r, d.animal, d.count - survivors, q)
    if r.cattle[d.animal] then SetFresh(r, d.animal, false) end

    Vouchers[ctx.src] = { animal = d.animal, count = arrived, rid = r.id, charid = ctx.charid, expires = os.time() + Config.Herding.voucherSeconds }

    local pct = q / lv.maxQuality * 100
    Stat(ctx, r.id, { herds = 1, herd_animals = arrived, herd_lost = spawned - arrived, herd_quality = pct })
    MySQL.insert('INSERT INTO ranch_herds (ranchid, charid, name, animal, started, survived, quality, ts) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { r.id, ctx.charid, U.cut(ctx.name, 100), d.animal, spawned, arrived, pct, os.time() })
    Activity(r.id, 'HERD', ('herded %d of %d %s home (quality %d%%)'):format(arrived, spawned, d.animal, U.round(pct)), ctx.name)
    LogEmbed(r, 'Herding Successful', LogColors.green, {
        { 'Rancher', ctx.name, true },
        { d.animal, ('%d of %d'):format(arrived, spawned), true },
        { 'Ranch ID', r.id, true },
        { 'Herd quality', ('%d%%'):format(U.round(pct)), true },
    })
    StartDriveCooldown(r, 'herd', ctx.name)
    RefreshRanch(r)
    local deaths = U.clamp(math.max(math.floor(tonumber(report.deaths) or 0), seenDead), 0, spawned)
    verdict(ctx.src, true, L('herdOk', survivors, deaths), { reward = true, animal = d.animal, count = arrived })
end

local function nearestBarn(pos)
    local best, bestDist
    for _, b in ipairs(Config.SaleBarns) do
        if not b.disabled then
            local dd = U.dist3(pos, b)
            if not bestDist or dd < bestDist then best, bestDist = b, dd end
        end
    end
    return best, bestDist
end

local function settleSale(ctx, d, report)
    local r = Ranches[d.rid]
    if not r then return verdict(ctx.src, false, L('reasonFailed')) end
    if report.failed then
        local left = failDrive(d, report.left, report.quality)
        return verdict(ctx.src, false, left > 0 and L('driveFailedLeft', left) or L('driveLost'))
    end

    local spawned = d.spawned or d.count
    local alive = math.max(0, spawned - d.kills)
    local num = U.clamp(math.floor(tonumber(report.arrived) or 0), 0, (seenCap(ctx, d, alive)))

    -- a refused claim fails the drive at once and the player is told why
    local pos = PlayerPos(ctx.src)
    local barn
    if pos then
        local dd
        barn, dd = nearestBarn(pos)
        if not barn or dd > REACH.barn then
            failDrive(d, num, report.quality)
            return verdict(ctx.src, false, L('saleRefusedFar'))
        end
    else
        barn = nearestBarn(d.ranchCoords)
    end
    local minTime = d.count + U.dist2(d.ranchCoords, barn) / Config.Herding.sanitySpeed
    if os.time() - d.startedAt < minTime then
        print(('[pup_ranchero] sale by %s (%d) refused: %ds is too quick (needs %ds)'):format(ctx.name, ctx.src, os.time() - d.startedAt, math.ceil(minTime)))
        failDrive(d, num, report.quality)
        return verdict(ctx.src, false, L('saleRefusedFast'))
    end

    local q = U.clamp(tonumber(report.quality) or 0, 0, d.startQ)
    local mult = tonumber(Config.Sales.payoutMult)
    if not mult or mult == 0 then mult = 1 end
    local price = Config.Animals[d.animal].price or 0
    local payout = U.round(price / 100 * q * num * mult)

    -- the whole drive leaves the ranch, sold or lost; animals bought meanwhile stay
    ApplyHerd(r, d.animal, spawned, nil)
    if payout > 0 then
        r.ledger = U.cents(r.ledger + payout)
        Save(r, 'ledger')
        Activity(r.id, 'INCOME', ('$%s from selling %d %s (ledger $%s)'):format(U.money(payout), num, d.animal, U.money(r.ledger)), ctx.name)
        LogLedger(r, 'Ranch Income', ctx.name, payout, ('sale of %d %s'):format(num, d.animal))
    end
    Stat(ctx, r.id, { cattle_money = payout })
    Notify(ctx.src, L('cattleSold', U.money(payout)))
    Activity(r.id, 'SALE', ('sold %d %s at %s for $%s'):format(num, d.animal, barn.town, U.money(payout)), ctx.name)
    LogPlain('general', r, 'Cattle Sold', {
        ('Who: %s'):format(ctx.name), ('Count: %d'):format(num), ('Type: %s'):format(d.animal),
        ('Payout: $%s'):format(U.money(payout)), ('Ranch ID: %d'):format(r.id),
    })
    StartDriveCooldown(r, 'sell', ctx.name)
    RefreshRanch(r)
    verdict(ctx.src, true, L('finishedPrefix'))
end

Rpc('driveFinish', { gap = 1000 }, function(ctx, report)
    local d = Drives[ctx.src]
    if not d or type(report) ~= 'table' then return false end
    if not d.live then return false end
    Drives[ctx.src] = nil
    if d.charid ~= ctx.charid then
        failDrive(d, d.count - d.kills, d.startQ)
        verdict(ctx.src, false, L('driveCharSwitch'))
        return true
    end
    -- the driver left or was removed, or the ranch changed hands: no settlement, no penalty, no reward
    if not stillOnRanch(d, ctx.identifier) then
        freeEnd(ctx.src, d)
        return true
    end
    if d.kind == 'herd' then settleHerd(ctx, d, report) else settleSale(ctx, d, report) end
    return true
end)

------------------------------------------------------------------------------
-- herding rewards (one-shot voucher)
------------------------------------------------------------------------------
function GiveRewards(ctx, r, animal, n)
    local items = {}
    for _, rw in ipairs(Config.Animals[animal].rewards or {}) do
        local amount = rw.per * n
        if amount > 0 then items[#items + 1] = { name = rw.item, amount = amount } end
    end
    if #items == 0 then return end

    local function describe(list)
        local parts = {}
        for _, it in ipairs(list) do parts[#parts + 1] = ('%d %s'):format(it.amount, it.name) end
        return table.concat(parts, ', ')
    end

    if Config.Herding.rewardsToStore then
        if StoreAdd(r, ctx, items) then
            Notify(ctx.src, L('hauledToStore'))
            Activity(r.id, 'HERD', 'stored ' .. describe(items), ctx.name)
            return
        end
        for _, it in ipairs(items) do exports.vorp_inventory:addItem(ctx.src, it.name, it.amount) end
        return
    end

    local overflow = {}
    for _, it in ipairs(items) do
        -- canCarryAmount is only in the patched vorp_inventory; stock falls back to canCarryItem (all or nothing)
        local okA, can = pcall(function() return exports.vorp_inventory:canCarryAmount(ctx.src, it.name, it.amount) end)
        if not okA then
            local okC, fits = pcall(function() return exports.vorp_inventory:canCarryItem(ctx.src, it.name, it.amount) end)
            can = (okC and fits == true) and it.amount or 0
        end
        can = tonumber(can) or 0
        can = U.clamp(math.floor(can), 0, it.amount)
        if can > 0 then exports.vorp_inventory:addItem(ctx.src, it.name, can) end
        if it.amount - can > 0 then overflow[#overflow + 1] = { name = it.name, amount = it.amount - can } end
    end
    if #overflow > 0 then
        if StoreAdd(r, ctx, overflow) then
            Notify(ctx.src, L('satchelOverflow'))
            Activity(r.id, 'HERD', 'stored ' .. describe(overflow) .. ' (satchel full)', ctx.name)
        else
            Notify(ctx.src, L('cantCarry'))
        end
    end
end

Rpc('claimReward', { gap = 1000 }, function(ctx, animal, n)
    local v = Vouchers[ctx.src]
    Vouchers[ctx.src] = nil -- one shot, whatever happens next
    if not v or os.time() > v.expires or v.animal ~= animal then return false end
    local r = Ranches[v.rid]
    if not r or v.charid ~= ctx.charid or not RoleIn(r, ctx.charid, ctx.identifier) then return false end
    n = U.clamp(math.floor(tonumber(n) or 0), 0, v.count)
    if n <= 0 then return false end
    GiveRewards(ctx, r, animal, n)
    return true
end)

------------------------------------------------------------------------------
-- abrupt ends: disconnect, character switch, abandoned drives
------------------------------------------------------------------------------
-- one rule for all of them: the failure rule, as if every living animal were reported at the starting quality.
-- Returns 'free' (nothing lost), 'failed' (rule applied) or nil (no drive).
function EndDriveAbruptly(src, why)
    local d = Drives[src]
    if not d then return nil end
    Drives[src] = nil
    local r = Ranches[d.rid]
    if not r then return 'free' end
    -- not live yet, or the driver no longer works this ranch: free, so a new owner never pays for it
    if not d.live or not stillOnRanch(d, nil) then
        SetDriveFlag(r, d.kind, false)
        RefreshRanch(r)
        return 'free'
    end
    local herd = d.kind == 'herd'
    local detail
    if why == 'timeout' then
        detail = ('the %s drive ran out of time'):format(d.animal)
    elseif why == 'switch' then
        detail = ('changed character mid-%s; half the drive was lost'):format(herd and 'herd' or 'sale')
    else
        detail = ('disconnected mid-%s; half the drive was lost'):format(herd and 'herd' or 'sale')
    end
    failDrive(d, d.count - d.kills, d.startQ, detail)
    if why == 'drop' or why == 'switch' then
        local what
        if why == 'drop' then what = herd and L('logOffHerd') or L('logOffSell')
        else what = herd and L('logSwitchHerd') or L('logSwitchSell') end
        LogPlain('general', r, 'Drive Abandoned', {
            ('%s %s'):format(d.driverName, what), ('Ranch ID: %d'):format(r.id),
        }, false)
    end
    return 'failed'
end

CreateThread(function()
    while true do
        Wait(Config.Timers.sweepEvery * 1000)
        local now = os.time()
        for src, d in pairs(Drives) do
            if now - d.startedAt > 2 * timeLimit(d) + Config.Timers.abandonExtra then
                local outcome = EndDriveAbruptly(src, 'timeout')
                if GetPlayerName(src) then
                    if outcome == 'failed' then
                        local r = Ranches[d.rid]
                        verdict(src, false, L('driveFailedLeft', r and (r.cattle[d.animal] or 0) or 0))
                    else
                        verdict(src, false, L('driveVoided'))
                    end
                end
            end
        end
        for src, v in pairs(Vouchers) do
            if now > v.expires then Vouchers[src] = nil end
        end
    end
end)
