-- pup-stable | society breeding: pairings, the foal board and buying a foal

local B = Config.Breeding
Bred = {}                    -- listing id -> row
local stableBusy = {}        -- stable id -> true while a pairing is written

local function rowFrom(r)
    local o = {}
    for k, v in pairs(r) do o[k] = v end
    for _, k in ipairs({ 'id', 'horseid', 'variation', 'price', 'tint0', 'tint1', 'tint2', 'stock', 'sold', 'bredat', 'active', 'htint0', 'htint1', 'htint2', 'readyat' }) do
        o[k] = U.int(r[k], 0)
    end
    for _, k in ipairs({ 'speed', 'acceleration', 'handling', 'health', 'stamina' }) do o[k] = U.int(r[k]) end
    o.scale = U.num(r.scale, 1.0)
    return o
end

function LoadBred()
    Bred = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM stable_bred') or {}) do
        local o = rowFrom(r)
        Bred[o.id] = o
    end
end

local function activateDue()
    local now = os.time()
    local any = false
    for _, r in pairs(Bred) do
        if r.active == 0 and r.readyat > 0 and r.readyat <= now then r.active = 1; any = true end
    end
    if any then MySQL.update('UPDATE stable_bred SET active = 1 WHERE active = 0 AND readyat > 0 AND readyat <= ?', { now }) end
end

CreateThread(function()
    while true do
        Wait(60000)
        if Ready then activateDue() end
    end
end)

------------------------------------------------------------------------------
-- who may breed
------------------------------------------------------------------------------
function BreedAllowed(ctx, stableId)
    if not B.enabled then return false, L('br_off') end
    local s = StableById(stableId)
    if not s then return false, L('br_noStable') end
    if IsStaff(ctx) then return true end
    if not s.job then return false, L('br_noOwner') end
    if not Running('pup_business') then return false, L('br_noService') end
    local okP, perm = pcall(function() return exports['pup_business']:HasPerm(ctx.src, B.permKey) end)
    if not okP then WarnOnce('bizperm', 'pup_business HasPerm failed; breeding refused') return false, L('br_noService') end
    if not perm then return false, L('br_notYours') end
    local okI, info = pcall(function() return exports['pup_business']:GetBusinessInfo(ctx.src) end)
    if not okI or type(info) ~= 'table' or info.job ~= s.job then return false, L('br_notYours') end
    if U.int(info.grade, ctx.grade) < B.minGrade then return false, L('br_grade', B.minGrade) end
    return true
end

local function cooldownLeft(stableId)
    local newest = 0
    for _, r in pairs(Bred) do
        if r.stableid == stableId then
            local retired = r.active == 0 and r.readyat == 0
            if not (retired and B.cooldownIgnoresRetired) and r.bredat > newest then newest = r.bredat end
        end
    end
    if newest == 0 then return 0 end
    return math.max(0, newest + B.cooldownDays * 86400 - os.time())
end

local function listing(r)
    return {
        id = r.id, horseid = r.horseid, variation = r.variation, model = r.model, name = r.name, price = r.price,
        palette = r.palette, tint0 = r.tint0, tint1 = r.tint1, tint2 = r.tint2, scale = r.scale, stock = r.stock, sold = r.sold,
        hairpalette = r.hairpalette, htint0 = r.htint0, htint1 = r.htint1, htint2 = r.htint2, sirebreed = r.sirebreed, dambreed = r.dambreed,
        speed = r.speed, acceleration = r.acceleration, handling = r.handling, health = r.health, stamina = r.stamina,
        bredat = r.bredat, readyat = r.readyat, siremodel = r.siremodel, dammodel = r.dammodel, mine = nil,
    }
end

local function board(stableId, charid)
    local out = {}
    for _, r in pairs(Bred) do
        if r.stableid == stableId and r.active == 1 and r.stock > 0 and (r.price > 0 or r.bredby == tostring(charid)) then
            local l = listing(r)
            l.mine = r.bredby == tostring(charid)
            out[#out + 1] = l
        end
    end
    table.sort(out, function(a, b) return a.bredat > b.bredat or (a.bredat == b.bredat and a.id > b.id) end)
    return out
end

-- pairings still carrying here, one entry per pairing (litter + breeder foal counted together)
local function carrying(stableId)
    local now, groups, out = os.time(), {}, {}
    for _, r in pairs(Bred) do
        if r.stableid == stableId and r.active == 0 and r.readyat > now then
            local key = ('%s:%d'):format(tostring(r.bredby), r.bredat)
            local g = groups[key]
            if not g then
                g = listing(r)
                g.due = 0
                groups[key] = g
                out[#out + 1] = g
            end
            g.due = g.due + r.stock
            if r.price > 0 then g.price = r.price end
        end
    end
    table.sort(out, function(a, b) return a.bredat < b.bredat end)
    return out
end

Rpc('breedState', { gap = 500 }, function(ctx, stableId)
    if not StableById(stableId) then return false end
    activateDue()
    local ok, reason = BreedAllowed(ctx, stableId)
    return true, {
        allowed = ok, reason = reason, cooldown = cooldownLeft(stableId), board = board(stableId, ctx.charid),
        minPrice = B.minPrice, maxPrice = B.maxPrice, height = B.height, litter = B.litter, cut = B.cut, minGrade = B.minGrade,
        carrying = carrying(stableId), gestation = B.gestationHours, now = os.time(),
    }
end)

Rpc('paddock', { gap = 2000 }, function(_, stableId)
    if not StableById(stableId) then return false end
    return true, carrying(stableId), os.time()
end)

------------------------------------------------------------------------------
-- a new pairing
------------------------------------------------------------------------------
-- a parent is a breed (its first coat, the one the client previews); its figures are the
-- server's birth stats for that model (BirthStats), never the client's reading
local function parentFigures(breed)
    local pc = B.cross.pointCeiling
    local sp, ac, hd, hp, sta = BirthStats(breed.coats[1].model)
    return {
        speed = sp, acceleration = ac, handling = hd,
        health = U.clamp(hp, 0, pc), stamina = U.clamp(sta, 0, pc),
    }
end

-- each stat from one parent or the other; then trim the group back to the better parent's total
local function rollGroup(a, b, keys, step)
    local out = {}
    for _, k in ipairs(keys) do out[k] = math.random(2) == 1 and a[k] or b[k] end
    local function total(t) local n = 0 for _, k in ipairs(keys) do n = n + t[k] end return n end
    local limit = math.max(total(a), total(b))
    local guard = 0
    while total(out) > limit and guard < 1000 do
        guard = guard + 1
        local can = {}
        for _, k in ipairs(keys) do
            if out[k] > math.min(a[k], b[k]) then can[#can + 1] = k end
        end
        if #can == 0 then break end
        local k = can[math.random(#can)]
        out[k] = out[k] - step
    end
    return out
end

local function rollFoal(sire, dam, cross)
    local ranks = rollGroup(sire, dam, { 'speed', 'acceleration', 'handling' }, 1)
    local points = rollGroup(sire, dam, { 'health', 'stamina' }, 10)
    if cross and B.cross.enabled then
        points.health = math.floor(points.health * (1 + B.cross.health))
        points.stamina = math.floor(points.stamina * (1 + B.cross.stamina))
    end
    local c = Config.Training.ceilings
    return {
        speed = U.clamp(ranks.speed, 1, c.speed), acceleration = U.clamp(ranks.acceleration, 1, c.acceleration),
        handling = U.clamp(ranks.handling, 1, c.handling),
        health = U.clamp(points.health, 0, B.cross.pointCeiling), stamina = U.clamp(points.stamina, 0, B.cross.pointCeiling),
    }
end

local function boardName(stableId)
    local used = {}
    for _, r in pairs(Bred) do if r.stableid == stableId and r.stock > 0 then used[r.name] = true end end
    local free = {}
    for _, n in ipairs(B.names) do if not used[n] then free[#free + 1] = n end end
    if #free == 0 then free = B.names end
    return free[math.random(#free)]
end

local function insertListing(o)
    local id = MySQL.insert.await([[INSERT INTO stable_bred (stableid, job, horseid, variation, model, name, price, palette, tint0, tint1, tint2,
        scale, stock, sold, bredby, bredat, active, hairpalette, htint0, htint1, htint2, sirebreed, dambreed, speed, acceleration, handling,
        health, stamina, readyat, siremodel, dammodel) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        o.stableid, o.job, o.horseid, o.variation, o.model, o.name, o.price, o.palette, o.tint0, o.tint1, o.tint2,
        o.scale, o.stock, o.bredby, o.bredat, o.active, o.hairpalette, o.htint0, o.htint1, o.htint2, o.sirebreed, o.dambreed,
        o.speed, o.acceleration, o.handling, o.health, o.stamina, o.readyat, o.siremodel, o.dammodel })
    id = U.int(id)
    if not id or id <= 0 then return nil end
    o.id, o.sold = id, 0
    Bred[id] = o
    return o
end

Rpc('breed', { gap = 2000 }, function(ctx, stableId, req)
    if type(req) ~= 'table' then return false end
    local s = StableById(stableId)
    if not s or not Near(ctx.src, s.location, 40.0) then return false end
    if stableBusy[stableId] or not Lock(ctx.src, 'breed') then return false, L('br_busy') end
    stableBusy[stableId] = true
    local function done(...) stableBusy[stableId] = nil; Unlock(ctx.src, 'breed'); return ... end

    local ok, reason = BreedAllowed(ctx, stableId)
    if not ok then return done(false, reason) end
    local left = cooldownLeft(stableId)
    if left > 0 then return done(false, L('br_cooldown', math.ceil(left / 86400))) end
    local foalBreed = Config.BreedById[U.int(req.breed, -1)]
    local coat = foalBreed and foalBreed.coats[U.int(req.coat, -1)]
    if not coat then return done(false, L('br_noBreed')) end
    local price = math.max(B.minPrice, U.int(req.price, 0))
    if B.maxPrice > 0 then price = math.min(price, B.maxPrice) end
    local scale = U.clamp(U.num(req.scale, 1.0), B.height.min, B.height.max)
    local sireBreed = Config.BreedById[U.int(req.sire, -1)] or foalBreed
    local damBreed = Config.BreedById[U.int(req.dam, -1)] or foalBreed
    local sire = parentFigures(sireBreed)
    local dam = parentFigures(damBreed)
    local cross = sireBreed.id ~= damBreed.id
    local now = os.time()
    local ready = B.gestationHours > 0 and (now + B.gestationHours * 3600) or 0
    local function pal(v) local p = U.cleanName(v, 64) if p then p = p:gsub('^metaped_', '') end return p end
    local base = {
        stableid = stableId, job = s.job or '', horseid = foalBreed.id, variation = U.int(req.coat), model = coat.model,
        palette = pal(req.palette), tint0 = math.max(0, U.int(req.tint0, 0)), tint1 = math.max(0, U.int(req.tint1, 0)), tint2 = math.max(0, U.int(req.tint2, 0)),
        hairpalette = pal(req.hairpalette), htint0 = math.max(0, U.int(req.htint0, 0)), htint1 = math.max(0, U.int(req.htint1, 0)), htint2 = math.max(0, U.int(req.htint2, 0)),
        scale = scale, bredby = tostring(ctx.charid), bredat = now, active = ready == 0 and 1 or 0, readyat = ready,
        sirebreed = sireBreed.label or '', dambreed = damBreed.label or '',
        siremodel = sireBreed.coats[1].model, dammodel = damBreed.coats[1].model,
    }
    local function make(stock, p)
        local o = U.copy(base)
        local st = rollFoal(sire, dam, cross)
        for k, v in pairs(st) do o[k] = v end
        o.stock, o.price, o.name = stock, p, boardName(stableId)
        return insertListing(o)
    end
    local good = pcall(function()
        if B.oneListingPerFoal then
            for _ = 1, B.litter do assert(make(1, price)) end
        else
            assert(make(B.litter, price))
        end
        if B.breederFoal then assert(make(1, 0)) end
    end)
    if not good then return done(false) end
    local msg = ready > 0 and (L('br_inFoal', B.litter, B.gestationHours) .. (B.breederFoal and L('br_yours') or '')) or L('br_onBoard', B.litter)
    Notify(ctx.src, msg)
    TriggerClientEvent('pup-stable:breedRefresh', -1, stableId)
    return done(true)
end)

------------------------------------------------------------------------------
-- buying and retiring
------------------------------------------------------------------------------
local function hairRows(ctx, h, r)
    local cpal = r.palette and r.palette ~= '' and ('metaped_' .. r.palette) or nil
    if cpal then
        CreateComp(ctx, 'horse_heads', 0, h.id, { palette = cpal, tint0 = r.tint0, tint1 = r.tint1, tint2 = r.tint2 })
        CreateComp(ctx, 'horse_bodies', 0, h.id, { palette = cpal, tint0 = r.tint0, tint1 = r.tint1, tint2 = r.tint2 })
    end
    local hpal = r.hairpalette and r.hairpalette ~= '' and ('metaped_' .. r.hairpalette) or nil
    if hpal then
        CreateComp(ctx, 'horse_manes', 0, h.id, { palette = hpal, tint0 = r.htint0, tint1 = r.htint1, tint2 = r.htint2 })
        CreateComp(ctx, 'horse_tails', 0, h.id, { palette = hpal, tint0 = r.htint0, tint1 = r.htint1, tint2 = r.htint2 })
    end
end

Rpc('buyFoal', { gap = 1500 }, function(ctx, stableId, listingId, name, clientStats, female)
    local r = Bred[U.int(listingId, -1)]
    if not r or r.active ~= 1 or r.stock <= 0 then return false, L('br_gone') end
    if r.stableid ~= stableId then return false, L('br_notHere') end
    if r.price <= 0 and r.bredby ~= tostring(ctx.charid) then return false, L('br_spoken') end
    if B.buyNeedsStable then
        local s = StableById(stableId)
        if not s or not Near(ctx.src, s.location, B.buyReach) then return false end
    end
    local max = Config.Horse.maxPerCharacter
    if max > 0 and #HorsesOf(ctx.charid) >= max then return false, L('maxHorses') end
    name = U.cleanName(name, Config.General.nameMax) or r.name
    if not Lock(ctx.src, 'buy') then return false, L('busy') end
    if not Charge(ctx.src, r.price, 0) then Unlock(ctx.src, 'buy') return false, L('noMoney') end
    local claimed = MySQL.update.await('UPDATE stable_bred SET stock = stock - 1, sold = sold + 1 WHERE id = ? AND stock > 0 AND active = 1', { r.id })
    if U.int(claimed, 0) <= 0 then
        Refund(ctx.src, r.price, 0)
        Unlock(ctx.src, 'buy')
        return false, L('br_gone')
    end
    r.stock, r.sold = r.stock - 1, r.sold + 1
    -- a listing without stored stats falls back to the server's birth stats of its model
    local bs, ba, bh, bhp, bst = BirthStats(r.model)
    local ok, h = pcall(CreateHorse, {
        identifier = ctx.identifier, charid = ctx.charid, stable = r.stableid, model = r.model, isFemale = female == true, name = name,
        speed = r.speed or bs, acceleration = r.acceleration or ba,
        handling = r.handling or bh, favourite = FavouriteOf(ctx.charid) == nil,
        health = r.health or bhp, stamina = r.stamina or bst,
        scale = r.scale, bred = true,
    })
    if not ok or not h then
        MySQL.update.await('UPDATE stable_bred SET stock = stock + 1, sold = sold - 1 WHERE id = ?', { r.id })
        r.stock, r.sold = r.stock + 1, r.sold - 1
        Refund(ctx.src, r.price, 0)
        Unlock(ctx.src, 'buy')
        return false, L('br_failed')
    end
    pcall(hairRows, ctx, h, r)
    Unlock(ctx.src, 'buy')
    local cut = math.floor(r.price * B.cut)
    if cut > 0 and r.job ~= '' then
        local okL, n = pcall(MySQL.update.await, 'UPDATE society_ledger SET ledger = ledger + ? WHERE job = ?', { cut, r.job })
        if not okL or U.int(n, 0) <= 0 then print(('[pup-stable] no society_ledger row for %s: breeding cut of $%d not paid'):format(r.job, cut)) end
    end
    Notify(ctx.src, L('boughtHorse'))
    TriggerClientEvent('pup-stable:breedRefresh', -1, stableId)
    return true, HorsePayload(h)
end)

Rpc('retireFoal', { gap = 1000 }, function(ctx, stableId, listingId)
    local r = Bred[U.int(listingId, -1)]
    if not r or r.stableid ~= stableId then return false end
    local ok, reason = BreedAllowed(ctx, stableId)
    if not ok then return false, reason end
    r.active, r.readyat = 0, 0
    MySQL.update('UPDATE stable_bred SET active = 0, readyat = 0 WHERE id = ?', { r.id })
    Notify(ctx.src, L('br_retired'))
    TriggerClientEvent('pup-stable:breedRefresh', -1, stableId)
    return true
end)
