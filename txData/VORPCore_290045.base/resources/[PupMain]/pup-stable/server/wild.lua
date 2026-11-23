-- pup-stable | wild horse spots: keep them filled, taming, and handing the horse in

local Spots = {}           -- [i] = { ent, model, respawnAt, asked, askedAt }
local Tamed = {}           -- [ent] = { charid, src, model, spot }
local workedUntil = {}     -- [charid] = os.time() the sale cooldown ends
local attemptAt = {}       -- [ent] = GetGameTimer() of the last taming attempt
local grants = {}          -- [src] = { stable, name, model, ent, expires }
local WildEnt = {}         -- [ent] = spot index: the server's own record of the horses it asked for
local attemptBy = {}       -- [ent] = { src, at } of the taming attempt the server accepted

local W = Config.Wild

for i = 1, #W.spots do Spots[i] = { respawnAt = 0 } end

-- the entity tag can be written by the client that owns the ped, so a horse only counts
-- as wild when the server itself registered it in wildSpawned
local function spotOf(ent)
    if not ent or not DoesEntityExist(ent) then return nil end
    local i = WildEnt[ent]
    if not i then return nil end
    return { spot = i }
end

local function nearestPlayer(coords, range)
    local best, bestD = nil, range
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local p = PedPos(src)
        if p then
            local d = #(p - coords)
            if d <= bestD and Ctx(src) then best, bestD = src, d end
        end
    end
    return best
end

CreateThread(function()
    while true do
        Wait(5000)
        if Ready and W.enabled then
            local now = os.time()
            for ent in pairs(WildEnt) do
                if not DoesEntityExist(ent) then WildEnt[ent], Tamed[ent], attemptAt[ent], attemptBy[ent] = nil, nil, nil, nil end
            end
            for i, s in ipairs(Spots) do
                if s.ent and not DoesEntityExist(s.ent) then
                    WildEnt[s.ent] = nil
                    s.ent = nil
                    s.respawnAt = now + 30
                end
                if not s.ent and now >= s.respawnAt and (not s.asked or now - s.askedAt >= 15) then
                    local c = W.spots[i].coords
                    local src = nearestPlayer(vector3(c.x, c.y, c.z), W.spawnRange)
                    if src then
                        local models = W.spots[i].models
                        s.model = models[math.random(1, #models)]
                        s.asked, s.askedAt = src, now
                        TriggerClientEvent('pup-stable:wildSpawn', src, i, s.model, c)
                    else
                        s.asked = nil
                    end
                end
            end
        end
    end
end)

Rpc('wildSpawned', { gap = 500 }, function(ctx, i, netId)
    i = U.int(i, -1)
    local s = Spots[i]
    if not s or s.asked ~= ctx.src or s.ent then return false end
    local ent = EntFromNet(netId, 5000)
    s.asked = nil
    if not ent or GetEntityType(ent) ~= 1 or GetEntityModel(ent) ~= joaat(s.model or '') then
        s.respawnAt = os.time() + 30
        if ent then SafeDelete(ent) end
        return false
    end
    s.ent = ent
    WildEnt[ent] = i
    Entity(ent).state:set('wildhorse', { spot = i }, true)
    return true
end)

function WildHandInCheck(ctx, ent)
    local tag = spotOf(ent)
    if not tag then return nil end
    local t = Tamed[ent]
    if not t then return 'untamed' end
    if t.charid == ctx.charid then return 'mine' end
    return 'other'
end

local function onCooldown(ctx)
    local u = workedUntil[ctx.charid]
    return u and os.time() < u
end

Rpc('tameStart', { gap = 1000 }, function(ctx, netId)
    if not IsTrainer(ctx) then return false, L('wh_noSkill') end
    if onCooldown(ctx) then return false, L('wh_cooldown') end
    local ent = EntFromNet(netId, 1000)
    local tag = spotOf(ent)
    if not tag then return false, L('wh_notWild') end
    if Tamed[ent] then return false, L('wh_notTamer') end
    local last = attemptAt[ent]
    if last and GetGameTimer() - last < 10000 then return false end
    attemptAt[ent] = GetGameTimer()
    attemptBy[ent] = { src = ctx.src, at = GetGameTimer() }
    return true
end)

Rpc('tameDone', { gap = 1000 }, function(ctx, netId)
    if not IsTrainer(ctx) then return false, L('wh_noSkill') end
    if onCooldown(ctx) then return false, L('wh_cooldown') end
    local ent = EntFromNet(netId, 1000)
    local tag = spotOf(ent)
    if not tag then return false, L('wh_notWild') end
    if Tamed[ent] then return false, L('wh_notTamer') end
    if not EntNear(ctx.src, ent, W.tameReach) then return false end
    -- only after an attempt this player started here, and not faster than the rounds can be played
    local a = attemptBy[ent]
    local took = a and (GetGameTimer() - a.at) or -1
    if not a or a.src ~= ctx.src or took < W.rounds * 1000 or took > 300000 then return false end
    attemptBy[ent] = nil
    local s = Spots[tag.spot]
    Tamed[ent] = { charid = ctx.charid, src = ctx.src, model = s and s.model, spot = tag.spot }
    Entity(ent).state:set('wildhorse', { spot = tag.spot, tamer = ctx.charid }, true)
    if s and s.ent == ent then
        s.ent = nil
        s.respawnAt = os.time() + W.refillMin * 60
    end
    Notify(ctx.src, L('wh_tamed'))
    return true
end)

local function handInChecks(ctx, netId, stableId)
    local st = StableById(stableId)
    if not st or not Near(ctx.src, st.location, W.serverHandIn) then return nil end
    if not IsTrainer(ctx) then return nil, L('wh_noSkill') end
    local ent = EntFromNet(netId, 1000)
    local t = ent and Tamed[ent]
    if not t then return nil, L('wh_breakFirst') end
    if t.charid ~= ctx.charid then return nil, L('wh_notTamer') end
    if not EntNear(ctx.src, ent, W.horseNear) then return nil end
    return ent, t, st
end

local function award(src)
    if Running('pup-perks') then pcall(function() exports['pup-perks']:Award(src, 'tame') end)
    else WarnOnce('perks', 'pup-perks is not running: no "tame" award') end
end

local function dropTamed(ent)
    Tamed[ent] = nil
    attemptAt[ent], attemptBy[ent], WildEnt[ent] = nil, nil, nil
    SafeDelete(ent)
end

Rpc('wildSell', { gap = 1500 }, function(ctx, netId, stableId)
    if onCooldown(ctx) then return false, L('wh_cooldown') end
    local ent, err = handInChecks(ctx, netId, stableId)
    if not ent then return false, err end
    local pay = math.random(W.salePrice[1], W.salePrice[2])
    Tamed[ent] = nil
    -- a sold horse can no longer be kept through a grant issued before the sale
    for s, g in pairs(grants) do if g.ent == ent then grants[s] = nil end end
    workedUntil[ctx.charid] = os.time() + W.cooldownMin * 60
    ctx.char.addCurrency(0, pay)
    award(ctx.src)
    Notify(ctx.src, L('wh_sold', pay))
    WildLog(ctx, pay)
    SetTimeout(3000, function() dropTamed(ent) end)
    return true
end)

Rpc('wildKeepGrant', { gap = 1000 }, function(ctx, netId, stableId, name)
    if not W.keep then return false, L('disabled') end
    local ent, t, st = handInChecks(ctx, netId, stableId)
    if not ent then return false, t end
    local br = t.model and BreedOfModel(t.model)
    if not br then return false, L('wh_noPapers') end
    name = U.cleanName(name, W.nameMax) or W.defaultName
    grants[ctx.src] = { stable = st.id, name = name, model = t.model, ent = ent, charid = ctx.charid, expires = os.time() + W.grantSec }
    return true
end)

Rpc('wildKeep', { gap = 1000 }, function(ctx, stats)
    local g = grants[ctx.src]
    if not g or g.charid ~= ctx.charid or os.time() > g.expires then grants[ctx.src] = nil return false end
    local max = Config.Horse.maxPerCharacter
    if max > 0 and #HorsesOf(ctx.charid) >= max then return false, L('maxHorses') end
    stats = type(stats) == 'table' and stats or {}
    -- ranks come from the model the server spawned at the spot (BirthStats), not from the client
    local sp, ac, hd = BirthStats(g.model)
    -- the horse must still be this player's tamed one (not sold, not already kept);
    -- it stops being tamed now so neither a sale nor a second grant can follow
    local t = Tamed[g.ent]
    if not t or t.charid ~= ctx.charid then grants[ctx.src] = nil return false, L('wh_notTamer') end
    grants[ctx.src] = nil
    Tamed[g.ent] = nil
    local ok, h = pcall(CreateHorse, {
        identifier = ctx.identifier, charid = ctx.charid, stable = g.stable, model = g.model, isFemale = stats.female == true, name = g.name,
        speed = sp, acceleration = ac, handling = hd, favourite = FavouriteOf(ctx.charid) == nil,
    })
    if not ok or not h then Tamed[g.ent] = t return false end
    Notify(ctx.src, L('addedToStable', g.name))
    local ent, src = g.ent, ctx.src
    SetTimeout(3500, function()
        dropTamed(ent)
        award(src)
        Notify(src, L('wh_yours'))
    end)
    return true, HorsePayload(h)
end)

function WildDrop(src)
    grants[src] = nil
    for ent, t in pairs(Tamed) do
        if t.src == src then dropTamed(ent) end
    end
end

function WildStop()
    for ent in pairs(Tamed) do SafeDelete(ent) end
    for ent in pairs(WildEnt) do SafeDelete(ent) end
    for _, s in ipairs(Spots) do SafeDelete(s.ent) end
end

if Config.Commands.wildhorses then
    RegisterCommand(Config.Commands.wildhorses, function(src)
        if src ~= 0 then return end
        local now = os.time()
        for i, s in ipairs(Spots) do
            print(('[pup-stable] spot %d: %s, model %s, respawn in %ds'):format(i, s.ent and DoesEntityExist(s.ent) and 'filled' or 'empty',
                tostring(s.model), math.max(0, (s.respawnAt or 0) - now)))
        end
        for ent, t in pairs(Tamed) do
            print(('[pup-stable] tamed horse %d by char %d (%s)'):format(ent, t.charid, tostring(t.model)))
        end
    end, true)
end
