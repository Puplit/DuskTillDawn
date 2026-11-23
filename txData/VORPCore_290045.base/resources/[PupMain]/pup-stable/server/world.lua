-- pup-stable | horses and wagons out in the world: entity links, tags, distance, points, cores,
-- deaths, the vet, whistle checks, entity delete requests and private routing buckets

HorseEnt, EntHorse = {}, {}    -- horse id <-> entity
WagonEnt, EntWagon = {}, {}    -- wagon id <-> entity
SpawnedBy = {}                 -- horse id -> server id that brought it out
WagonSpawnedBy = {}
Tracked = {}                   -- horse id -> tracking record
DeathTime = {}                 -- horse id -> os.time() of death (memory only)
PlayerChar = {}                -- src -> { charid, identifier } (still known after a drop)

local reviveBusy, whistleBusy = {}, {}

------------------------------------------------------------------------------
-- links
------------------------------------------------------------------------------
function LinkHorse(id, ent, src)
    local old = HorseEnt[id]
    if old and old ~= ent then
        EntHorse[old] = nil
        SafeDelete(old)
    end
    HorseEnt[id], EntHorse[ent], SpawnedBy[id] = ent, id, src
end

function UnlinkHorse(id, delete)
    local ent = HorseEnt[id]
    if ent then
        EntHorse[ent] = nil
        if delete then SafeDelete(ent) end
    end
    HorseEnt[id], SpawnedBy[id], Tracked[id] = nil, nil, nil
end

function LinkWagon(id, ent, src)
    local old = WagonEnt[id]
    if old and old ~= ent then
        EntWagon[old] = nil
        SafeDelete(old)
    end
    WagonEnt[id], EntWagon[ent], WagonSpawnedBy[id] = ent, id, src
end

function UnlinkWagon(id, delete)
    local ent = WagonEnt[id]
    if ent then
        EntWagon[ent] = nil
        if delete then SafeDelete(ent) end
    end
    WagonEnt[id], WagonSpawnedBy[id] = nil, nil
end

-- entity -> horse: the server's own link first; an id tag only for the caller's own, unlinked horse
function HorseOfEnt(ent, ctx)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    local id = EntHorse[ent]
    if id then return Horses[id] end
    if ctx then
        local tag = U.int(Entity(ent).state.pup_stable_horseID)
        local h = tag and OwnedHorse(ctx, tag)
        if h and not HorseEnt[h.id] then
            LinkHorse(h.id, ent, ctx.src)
            return h
        end
    end
    return nil
end

function WagonOfEnt(ent, ctx)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    local id = EntWagon[ent]
    if id then return Wagons[id] end
    if ctx then
        local tag = U.int(Entity(ent).state.pup_stable_wagonID)
        local w = tag and OwnedWagon(ctx, tag)
        if w and not WagonEnt[w.id] then
            LinkWagon(w.id, ent, ctx.src)
            return w
        end
    end
    return nil
end

function OwnerSrc(h) return SrcOfChar(h.charid) end

------------------------------------------------------------------------------
-- entity tags
------------------------------------------------------------------------------
function StatsTag(h)
    return {
        bonding = h.st.bonding, health = h.st.health, stamina = h.st.stamina,
        speed = h.speed, acceleration = h.acceleration, handling = h.handling,
        baseSpeed = h.baseSpeed or h.speed, baseAcceleration = h.baseAcceleration or h.acceleration, baseHandling = h.baseHandling or h.handling,
        level = U.level(h.st.xp),
    }
end

function PublishStats(h)
    local ent = HorseEnt[h.id]
    if ent and DoesEntityExist(ent) then Entity(ent).state:set('pup_stable_horse_stats', StatsTag(h), true) end
end

function TagHorse(h, ent, src)
    local st = Entity(ent).state
    local bag, lantern = HorseCompOf(h, 'horse_saddlebags'), HorseCompOf(h, 'saddle_lanterns')
    st:set('pup_stable_horseID', h.id, true)
    st:set('pup_stable_horseOwner', src, true)
    st:set('pup_stable_horseIsFemale', h.isFemale, true)
    st:set('pup_stable_horseRandom', math.random(1, 2147483646), true)
    st:set('pup_stable_isDead', h.isDead, true)
    st:set('pup_stable_saddlebagID', bag and bag.id or false, true)
    st:set('pup_stable_lanternID', lantern and lantern.id or false, true)
    st:set('pup_stable_horse_stats', StatsTag(h), true)
    st:set('pup_stable_stat_distance', h.st.distance, true)
    st:set('pup_stable_stat_lastNewShoes', h.st.lastNewShoes, true)
    st:set('pup_stable_horseScale', (h.scale and math.abs(h.scale - 1.0) > 0.001) and h.scale or false, true)
    if st.pup_stable_stow == nil then st:set('pup_stable_stow', {}, true) end
end

function TagWagon(w, ent, src)
    local st = Entity(ent).state
    st:set('pup_stable_wagonID', w.id, true)
    st:set('pup_stable_wagonOwner', src, true)
    st:set('pup_stable_wagonName', WagonLabel(w), true)
    st:set('pup_stable_wagonRandom', math.random(1, 2147483646), true)
    st:set('pup_stable_wagon_draft', {}, true)
end

------------------------------------------------------------------------------
-- rest recovery and cores
------------------------------------------------------------------------------
function CreditRest(h)
    local r = Config.Bonding.rest
    if not r.enabled or h.st.restedAt <= 0 then return end
    local now = os.time()
    local steps = math.floor((now - h.st.restedAt) / r.everySec)
    if steps <= 0 then return end
    local gain = steps * r.points
    h.st.healthCore = U.clamp(h.st.healthCore + gain, 0, 100)
    h.st.staminaCore = U.clamp(h.st.staminaCore + gain, 0, 100)
    if r.restoreInner and h.st.staminaCore >= 100 then h.st.pedStamina = 0 end
    h.st.restedAt = h.st.restedAt + steps * r.everySec
    MarkStats(h)
end

function FullCores(h)
    h.st.healthCore, h.st.staminaCore, h.st.pedStamina = 100, 100, 0
    MarkStats(h)
end

local function startTracking(h, ent)
    local p = GetEntityCoords(ent)
    Tracked[h.id] = {
        ent = ent, last = p, acc = 0.0, walkMark = h.st.distance, rideSecs = 0,
        minuteStart = os.time(), minuteXP = 0, pool = 0, poolAt = os.time(), poolGains = {},
    }
end

------------------------------------------------------------------------------
-- a horse comes out
------------------------------------------------------------------------------
Rpc('horseOut', { gap = 500 }, function(ctx, horseId, netId)
    local h = OwnedHorse(ctx, horseId)
    if not h then return false end
    if h.isDead then return false, L('favouriteDead') end
    local busy = TransferBusy('horse', h.id)
    if busy then return false, L('stillTransferring') end
    local ent = EntFromNet(netId, 5000)
    if not ent or GetEntityType(ent) ~= 1 then return false end
    -- re-check after the wait
    h = OwnedHorse(ctx, horseId)
    if not h or h.isDead or not DoesEntityExist(ent) then return false end
    if GetEntityModel(ent) ~= joaat(h.model) then return false end
    if not EntNear(ctx.src, ent, 120.0) then return false end
    local other = EntHorse[ent]
    if other and other ~= h.id then return false end

    LinkHorse(h.id, ent, ctx.src)
    TagHorse(h, ent, ctx.src)
    if not h.isOut then h.isOut = true; SaveHorse(h, 'isOut') end
    CreditRest(h)
    h.st.restedAt = 0
    MarkStats(h)
    startTracking(h, ent)

    local hid = h.id
    SetTimeout(1500, function()
        local cur = Horses[hid]
        if cur and HorseEnt[hid] == ent and DoesEntityExist(ent) then
            TriggerClientEvent('pup-stable:redress', ctx.src, NetworkGetNetworkIdFromEntity(ent), HorsePayload(cur))
        end
    end)
    return true, { healthCore = h.st.healthCore, staminaCore = h.st.staminaCore, pedStamina = h.st.pedStamina }
end)

-- cores captured by the owner's client
Rpc('saveCores', { gap = 1000 }, function(ctx, horseId, hc, sc, inner)
    local h = OwnedHorse(ctx, horseId)
    if not h then return false end
    h.st.healthCore = U.clamp(U.int(hc, h.st.healthCore), 0, 100)
    h.st.staminaCore = U.clamp(U.int(sc, h.st.staminaCore), 0, 100)
    h.st.pedStamina = U.clamp(U.int(inner, h.st.pedStamina), 0, 1000)
    MarkStats(h)
    return true
end)

Rpc('getCores', { gap = 500 }, function(ctx, horseId)
    local h = OwnedHorse(ctx, horseId)
    if not h then return false end
    CreditRest(h)
    return true, { healthCore = h.st.healthCore, staminaCore = h.st.staminaCore, pedStamina = h.st.pedStamina }
end)

-- put away without a stable (flee, cull, despawn): the horse is in again, resting
function PutAway(h, stableId)
    UnlinkHorse(h.id, true)
    h.isOut = false
    if stableId then h.stable = stableId end
    h.st.restedAt = os.time()
    MarkStats(h)
    SaveHorse(h, 'isOut', 'stable')
    SaveStats(h)
end

Rpc('horseGone', { gap = 300 }, function(ctx, horseId)
    local h = OwnedHorse(ctx, horseId)
    if not h then return false end
    PutAway(h, nil)
    return true
end)

------------------------------------------------------------------------------
-- deaths
------------------------------------------------------------------------------
Rpc('horseDied', { gap = 500 }, function(ctx, netId)
    local ent = EntFromNet(netId, 1000)
    local h = HorseOfEnt(ent, ctx)
    if not h or h.isDead then return false end
    local mine = h.charid == ctx.charid and h.identifier == ctx.identifier
    if not mine and GetEntityHealth(ent) > 0 then return false end
    h.isDead = true
    DeathTime[h.id] = os.time()
    SaveHorse(h, 'isDead')
    if DoesEntityExist(ent) then Entity(ent).state:set('pup_stable_isDead', true, true) end
    local owner = OwnerSrc(h)
    if owner then TriggerClientEvent('pup-stable:listChanged', owner) end
    return true
end)

local function reviveCore(h, src, gold, auto)
    if reviveBusy[h.id] then return false, L('busy') end
    reviveBusy[h.id] = true
    local price = gold and Config.Vet.goldPrice or Config.Vet.price
    local currency = gold and 1 or 0
    local ok, msg = false, nil
    if not h.isDead then
        msg = L('horseNotDead')
    elseif not Charge(src, price, currency) then
        msg = not auto and L('noMoney') or nil
    else
        local row = MySQL.update.await('UPDATE stable_horses SET isDead = 0, isOut = 0 WHERE id = ?', { h.id })
        if U.int(row, 0) <= 0 or not Horses[h.id] then
            Refund(src, price, currency)
            msg = L('vetRefund')
            if auto then reviveBusy[h.id] = 'gone' return false, msg end
        else
            h.isDead, h.isOut = false, false
            DeathTime[h.id] = nil
            FullCores(h)
            UnlinkHorse(h.id, true)
            ok = true
        end
    end
    if reviveBusy[h.id] == true then reviveBusy[h.id] = nil end
    return ok, msg, price
end

Rpc('revive', { gap = 1000 }, function(ctx, horseId, gold)
    local h = Horses[U.int(horseId, -1)]
    if not h or h.charid ~= ctx.charid or h.identifier ~= ctx.identifier then return false, L('horseNotFound') end
    if gold and not Config.Vet.goldPrice then return false end
    local ok, msg = reviveCore(h, ctx.src, gold == true, false)
    if ok then
        Notify(ctx.src, L('revived', h.name))
        return true
    end
    return false, msg
end)

Rpc('whistleRevive', { gap = 1000 }, function(ctx, horseId)
    local h = OwnedHorse(ctx, horseId)
    if not h or not h.isDead then return false end
    local died = DeathTime[h.id]
    if died then
        local left = Config.Vet.deathDelay - (os.time() - died)
        if left > 0 then return false, L('stillDown', left) end
    end
    local keep = { h.st.healthCore, h.st.staminaCore, h.st.pedStamina }
    local ok, msg = reviveCore(h, ctx.src, false, false)
    if not ok then return false, msg end
    if not Config.Vet.whistleResetsCores then
        -- a whistle revive leaves the rings where they were
        h.st.healthCore, h.st.staminaCore, h.st.pedStamina = keep[1], keep[2], keep[3]
        MarkStats(h)
    end
    return true, HorsePayload(h)
end)

-- automatic vet
local lastRemind = {}
CreateThread(function()
    while true do
        Wait(Config.Vet.sweepEvery * 1000)
        if Ready and Config.Vet.autoRevive then
            local now = os.time()
            for id, h in pairs(Horses) do
                if h.isDead and reviveBusy[id] ~= 'gone' then
                    local died = DeathTime[id]
                    if not died and not Config.Vet.reviveDeadAfterRestartAtOnce then
                        DeathTime[id] = now
                        died = now
                    end
                    if not died or now - died >= Config.Vet.deathDelay then
                        local src = OwnerSrc(h)
                        if src then
                            local ctx = Ctx(src)
                            local price = Config.Vet.price
                            if ctx and ctx.money >= price then
                                local ok, msg = reviveCore(h, src, false, true)
                                if ok then
                                    Notify(src, price > 0 and L('vetPaid', h.name, U.money(price)) or L('vetFree', h.name))
                                    TriggerClientEvent('pup-stable:listChanged', src)
                                elseif msg then
                                    Notify(src, msg)
                                end
                            elseif not lastRemind[id] or now - lastRemind[id] >= Config.Vet.remindEvery then
                                lastRemind[id] = now
                                Notify(src, L('vetHolding', h.name, U.money(price)))
                            end
                        end
                    end
                end
            end
        end
    end
end)

------------------------------------------------------------------------------
-- whistle: is the favourite already out?
------------------------------------------------------------------------------
Rpc('whistle', { gap = 800 }, function(ctx)
    local h = FavouriteOf(ctx.charid)
    if not h or h.identifier ~= ctx.identifier then return false, L('noFavourite') end
    if h.isDead then return false, L('favouriteDead'), h.id end
    if TransferBusy('horse', h.id) then return false, L('stillTransferring') end
    if whistleBusy[h.id] then return false end
    whistleBusy[h.id] = true
    local ent = HorseEnt[h.id]
    local out = ent and DoesEntityExist(ent) and EntNear(ctx.src, ent, Config.Horse.whistleTeleport)
    whistleBusy[h.id] = nil
    if out then return false, L('favouriteOut') end
    if ent then UnlinkHorse(h.id, true) end
    if h.isOut then h.isOut = false; SaveHorse(h, 'isOut') end
    return true, HorsePayload(h)
end)

------------------------------------------------------------------------------
-- distance, walking points and riding XP
------------------------------------------------------------------------------
local function walkAllowed(h, ownerCtx)
    local gate = Config.Stats.walkGate
    if gate == 'everyone' then return true end
    if not ownerCtx then return false end
    if gate == 'jobs' then
        for _, j in ipairs(Config.Stats.walkJobs) do if ownerCtx.job == j then return true end end
        return false
    end
    if not Config.Training.trainersOnly then return true end
    return IsTrainer(ownerCtx)
end

local function addPoints(h, key, n)
    local cap = key == 'bonding' and Config.Stats.bondCeiling or Config.Stats.pointCeiling
    local before = h.st[key]
    h.st[key] = U.clamp(before + n, 0, cap)
    return h.st[key] - before
end

local function fullyTrained(h)
    local c = Config.Training.ceilings
    return h.speed >= c.speed and h.acceleration >= c.acceleration and h.handling >= c.handling
        and h.st.health >= Config.Stats.pointCeiling and h.st.stamina >= Config.Stats.pointCeiling and h.st.bonding >= Config.Stats.bondCeiling
end

local STAT_TITLE = { speed = 'speed', acceleration = 'acceleration', handling = 'handling' }

-- spend wallets into ranks where the horse's level allows it
function TryRanks(h, src)
    local lv = U.level(h.st.xp)
    local cap = Config.Training.capPerLevel[lv] or 10
    local changed = false
    for stat, cost in pairs(Config.Training.rankCost) do
        local wallet = stat .. 'XP'
        local ceiling = Config.Training.ceilings[stat]
        local limit = stat == 'handling' and ceiling or math.min(ceiling, cap)
        while h.st[wallet] >= cost and h[stat] < limit do
            h.st[wallet] = h.st[wallet] - cost
            h[stat] = h[stat] + 1
            changed = true
            if src and Config.Stats.levelToasts then Toast(src, L(STAT_TITLE[stat]), L('levelUp')) end
        end
        if h[stat] >= limit and h.st[wallet] > cost then h.st[wallet] = cost end
    end
    if changed then
        SaveHorse(h, 'speed', 'acceleration', 'handling')
        MarkStats(h)
        PublishStats(h)
    end
end

-- award ride XP into the six channels; returns total gained
local function awardRide(h, ownerCtx, src)
    local t = Tracked[h.id]
    local now = os.time()
    if now - t.minuteStart >= 60 then t.minuteStart, t.minuteXP = now, 0 end
    local room = Config.Training.xpPerMinute - t.minuteXP
    if room <= 0 then return 0 end
    local trainer = IsTrainer(ownerCtx)
    local lvBefore = U.level(h.st.xp)
    local total = 0
    local c = Config.Training.ceilings
    for _, stat in ipairs({ 'speed', 'acceleration', 'handling', 'health', 'stamina', 'bonding' }) do
        local amount = Config.Training.rideXP * (h.st.focus == stat and Config.Training.focusMult or 1)
        amount = math.min(amount, room - total)
        if amount <= 0 then break end
        local gained = 0
        if stat == 'speed' or stat == 'acceleration' or stat == 'handling' then
            if h[stat] < c[stat] then
                h.st[stat .. 'XP'] = h.st[stat .. 'XP'] + amount
                gained = amount
            end
        else
            gained = addPoints(h, stat, amount)
        end
        if gained > 0 then
            total = total + gained
            t.poolGains[stat] = (t.poolGains[stat] or 0) + gained
        end
    end
    if total <= 0 then return 0 end
    t.minuteXP = t.minuteXP + total
    h.st.xp = h.st.xp + total
    MarkStats(h)
    local lv = U.level(h.st.xp)
    if lv > lvBefore and src and Config.Stats.levelToasts then Toast(src, L('horseLevel', lv), L('grewXP')) end
    TryRanks(h, src)
    if fullyTrained(h) and not h.fullToast and src then
        h.fullToast = true
        Toast(src, L('fullyTrained'), L('fullyTrainedSub'))
    end
    if trainer and src and Config.Training.feedback.toast then
        t.pool = t.pool + total
        if t.pool >= Config.Training.feedback.minimum or now - t.poolAt >= Config.Training.feedback.everySec then
            TriggerClientEvent('pup-stable:xpFeedback', src, h.id, t.pool, t.poolGains)
            t.pool, t.poolAt, t.poolGains = 0, now, {}
        end
    end
    PublishStats(h)
    return total
end

local function walkPayout(h, ownerCtx, src)
    local t = Tracked[h.id]
    local every = Config.Stats.walkEvery
    while h.st.distance - t.walkMark >= every do
        t.walkMark = t.walkMark + every
        if walkAllowed(h, ownerCtx) then
            local pts = Config.Stats.walkPoints
            local bondPts = pts
            if h.st.focus == 'bonding' and IsTrainer(ownerCtx) then bondPts = pts * 2 end
            local before = { U.rankFromPoints(h.st.bonding, Config.Stats.bondCeiling), U.rankFromPoints(h.st.health), U.rankFromPoints(h.st.stamina) }
            local gb = addPoints(h, 'bonding', bondPts)
            addPoints(h, 'health', pts)
            addPoints(h, 'stamina', pts)
            h.st.xp = h.st.xp + gb
            MarkStats(h)
            PublishStats(h)
            if src and Config.Stats.levelToasts then
                local after = { U.rankFromPoints(h.st.bonding, Config.Stats.bondCeiling), U.rankFromPoints(h.st.health), U.rankFromPoints(h.st.stamina) }
                if after[1] > before[1] then Toast(src, L('bonding'), L('levelN', after[1])) end
                if after[2] > before[2] then Toast(src, L('healthUp'), L('levelN', after[2])) end
                if after[3] > before[3] then Toast(src, L('staminaUp'), L('levelN', after[3])) end
            end
        end
    end
end

CreateThread(function()
    local tick = Config.Stats.tickMs
    while true do
        Wait(tick)
        if Ready then
            for id, t in pairs(Tracked) do
                local h = Horses[id]
                if not h or not DoesEntityExist(t.ent) or HorseEnt[id] ~= t.ent then
                    Tracked[id] = nil
                else
                    local p = GetEntityCoords(t.ent)
                    local d = #(p - t.last)
                    t.last = p
                    -- a move of more than ~30 m per second of tick is a teleport, not a walk
                    if d <= 30.0 * math.max(tick, 1000) / 1000 and not h.isDead then
                        t.acc = t.acc + d
                        if t.acc >= 1.0 then
                            local whole = math.floor(t.acc)
                            t.acc = t.acc - whole
                            h.st.distance = h.st.distance + whole
                            MarkStats(h)
                            Entity(t.ent).state:set('pup_stable_stat_distance', h.st.distance, true)
                        end
                        local src = OwnerSrc(h)
                        local ownerCtx = src and Ctx(src)
                        walkPayout(h, ownerCtx, src)
                        local speed = d / (tick / 1000)
                        local trainerRidden = ownerCtx and (not Config.Training.trainersOnly or IsTrainer(ownerCtx))
                        if trainerRidden and speed >= Config.Training.minSpeed and speed < Config.Training.maxSpeed then
                            t.rideSecs = t.rideSecs + tick / 1000
                            if t.rideSecs >= Config.Training.rideEvery then
                                t.rideSecs = t.rideSecs - Config.Training.rideEvery
                                awardRide(h, ownerCtx, src)
                            end
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Stats.saveMs)
        if Ready then SaveAllStats(false) end
    end
end)

-- drop links to entities that no longer exist
CreateThread(function()
    while true do
        Wait(60000)
        for id, ent in pairs(HorseEnt) do if not DoesEntityExist(ent) then UnlinkHorse(id, false) end end
        for id, ent in pairs(WagonEnt) do if not DoesEntityExist(ent) then UnlinkWagon(id, false) end end
    end
end)

------------------------------------------------------------------------------
-- entity delete requests from clients
------------------------------------------------------------------------------
-- only the repair path, and only for the caller's own tagged wagon/horse within reach
Rpc('deleteEntity', { gap = 300 }, function(ctx, netId, mode)
    if mode ~= 'repair' then return false end
    local ent = EntFromNet(netId, 1000)
    if not ent then return false end
    if GetEntityType(ent) == 1 and IsPedAPlayer(ent) then return false end
    if not EntNear(ctx.src, ent, 15.0) then return false end
    local w = WagonOfEnt(ent, ctx)
    local h = HorseOfEnt(ent, ctx)
    local mine = (w and w.charid == ctx.charid and w.identifier == ctx.identifier) or (h and h.charid == ctx.charid and h.identifier == ctx.identifier)
    if not mine then return false end
    if w then UnlinkWagon(w.id, false) end
    if h then UnlinkHorse(h.id, false) end
    SafeDelete(ent)
    return true
end)

------------------------------------------------------------------------------
-- private routing buckets for stables flagged "needs instance"
------------------------------------------------------------------------------
local instanced = {}

Rpc('instance', { gap = 500 }, function(ctx, on, stableId, horseNet, wagonNet)
    local s = StableById(stableId)
    local src = ctx.src
    if on then
        if not s or not s.needsInstance or not Near(src, s.location, 40.0) then return false end
        local bucket = 1000 + src
        local ents = { GetPlayerPed(src) }
        local hEnt = horseNet and EntFromNet(horseNet, 500)
        if hEnt and HorseOfEnt(hEnt) and OwnedHorse(ctx, EntHorse[hEnt]) then ents[#ents + 1] = hEnt end
        local wEnt = wagonNet and EntFromNet(wagonNet, 500)
        if wEnt and WagonOfEnt(wEnt) and OwnedWagon(ctx, EntWagon[wEnt]) then ents[#ents + 1] = wEnt end
        instanced[src] = { ents = ents, from = GetPlayerRoutingBucket(src) }
        for _, e in ipairs(ents) do SetEntityRoutingBucket(e, bucket) end
        SetPlayerRoutingBucket(src, bucket)
        return true
    end
    return LeaveInstance(src)
end)

function LeaveInstance(src)
    local rec = instanced[src]
    if not rec then return false end
    instanced[src] = nil
    for _, e in ipairs(rec.ents) do
        if DoesEntityExist(e) then SetEntityRoutingBucket(e, rec.from) end
    end
    if GetPlayerName(src) then SetPlayerRoutingBucket(src, rec.from) end
    return true
end

function LeaveAllInstances()
    for src in pairs(instanced) do LeaveInstance(src) end
end

------------------------------------------------------------------------------
-- vorp_admin world cleanup: whatever was swept counts as put away, so the owner
-- can call it again. One a player is still riding or driving survives and stays out.
------------------------------------------------------------------------------
AddEventHandler('vorp_admin:worldCleanupDone', function()
    if not Ready then return end
    local owners = {}
    for id, h in pairs(Horses) do
        local ent = HorseEnt[id]
        if h.isOut and not h.isDead and not (ent and DoesEntityExist(ent)) then
            local src = SpawnedBy[id] or OwnerSrc(h)
            PutAway(h, nil)
            if src then owners[src] = true end
        end
    end
    local wagonOwners = {}
    for id, w in pairs(Wagons) do
        local ent = WagonEnt[id]
        if w.isOut and not (ent and DoesEntityExist(ent)) then
            local src = WagonSpawnedBy[id] or SrcOfChar(w.charid)
            PutWagonAway(w, nil)
            if src then wagonOwners[src] = true end
        end
    end
    for src in pairs(owners) do TriggerClientEvent('pup-stable:listChanged', src) end
    for src in pairs(wagonOwners) do TriggerClientEvent('pup-stable:listChanged', src, 'wagons') end
end)
