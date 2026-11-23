-- pup_camps | butchers, donations, horse pelts and the per-character hunting-wagon stash
-- Prices are decided here, never by the client: carcasses by their own model, pelts only
-- once registered against the carcass they came from, horse pelts from the server tally.

local SoldIds    = {}  -- [netId] = os.time() of the sale/donation
local PeltBudget = {}  -- [charid] = { value, t }
local Pelts      = {}  -- [pelt netId] = { charid, model, outfit, label, price, big, t }
local PeltCount  = {}  -- [charid] = registered pelts held in Pelts
local UsedCarcass = {} -- [carcass netId] = os.time(): already gave its pelt
local HorseTally = {}  -- [charid] = money value of registered small pelts stowed on horses

local PC = Config.Pelts

local function isPlayerPed(ent)
    for _, s in ipairs(GetPlayers()) do
        if GetPlayerPed(s) == ent then return true end
    end
    return false
end

-- the entity named by the client, if it is real and close to the player
local function bodyNear(src, netId, maxDist)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if isPlayerPed(ent) then return nil, 'player' end
    local pos = PlayerPos(src)
    if pos then
        local c = GetEntityCoords(ent)
        if U.dist3(pos, { x = c.x, y = c.y, z = c.z }) > maxDist then return nil end
    end
    return ent
end

local function recentlySold(netId)
    local t = SoldIds[netId]
    return t and os.time() - t < Config.Butchers.resaleMemory
end

-- the price row of a carcass the server can see: its own model; the client's outfit only
-- picks between rows of that same model
local function carcassRow(ent, outfit)
    if GetEntityType(ent) ~= 1 then return nil end
    return U.animalRow(GetEntityModel(ent), outfit)
end

local function carcassDead(ent)
    return GetEntityHealth(ent) <= 0
end

local function carcassUsed(netId, ent)
    if UsedCarcass[netId] then return true end
    local ok, v = pcall(Integrations.isSkinned, netId)
    if ok and v then return true end
    return Entity(ent).state.skinned == true
end

local function dropPelt(netId)
    local p = Pelts[netId]
    if not p then return nil end
    Pelts[netId] = nil
    PeltCount[p.charid] = math.max(0, (PeltCount[p.charid] or 1) - 1)
    return p
end

local function addPelt(netId, charid, row, model, outfit, price)
    if Pelts[netId] then dropPelt(netId) end
    Pelts[netId] = {
        charid = charid, model = U.signed(model), outfit = tonumber(outfit) or 0,
        label = U.trim(row.label), price = U.round(tonumber(price) or 0, 2), big = row.big == true, t = os.time(),
    }
    PeltCount[charid] = (PeltCount[charid] or 0) + 1
    return Pelts[netId]
end

-- a carcass or registered pelt offered for sale or donation: entity, nil, value, label, model
local function checkBody(src, netId, info)
    netId = tonumber(netId)
    info = type(info) == 'table' and info or {}
    local ent, why = bodyNear(src, netId, Config.Butchers.bodyRange)
    if not ent then return nil, why == 'player' and L('nobody_buys') or L('butcher_refused') end
    if recentlySold(netId) then return nil, L('butcher_refused') end
    local kind = GetEntityType(ent)
    if kind == 3 then
        local p = Pelts[netId]
        if not p then return nil, L('nobody_buys') end
        return ent, nil, p.price, p.label, p.model, true
    elseif kind == 1 then
        local row = carcassRow(ent, info.outfit)
        if not row then return nil, L('nobody_buys') end
        if not carcassDead(ent) or carcassUsed(netId, ent) then return nil, L('butcher_refused') end
        return ent, nil, U.round(row.price[2] or 0, 2), U.trim(row.label), U.signed(GetEntityModel(ent)), false
    end
    return nil, L('nobody_buys')
end

local function ecoBonus(src, placeName, amount)
    local ok, v = pcall(Integrations.ecoBonus, src, placeName, amount)
    v = ok and tonumber(v) or 0
    if v ~= v or v < 0 then v = 0 end
    return U.round(v, 2)
end

-- horse-pelt budget: refills linearly over budgetRefill seconds
local function takeBudget(charid, wanted)
    local cap = U.horsePeltCap()
    local now = os.time()
    local b = PeltBudget[charid] or { value = cap, t = now }
    b.value = math.min(cap, b.value + cap * (now - b.t) / Config.Butchers.budgetRefill)
    b.t = now
    local take = math.max(0, math.min(wanted, cap, b.value))
    b.value = b.value - take
    PeltBudget[charid] = b
    return U.round(take, 2)
end

------------------------------------------------------------------------------ pelt registration

-- the client saw a pelt appear in its hands next to a carcass it just skinned
Handle('peltBind', function(ctx, carcassNet, peltNet, outfit, quality)
    carcassNet, peltNet = tonumber(carcassNet), tonumber(peltNet)
    if not carcassNet or not peltNet or carcassNet == peltNet then return nil end
    if Pelts[peltNet] then
        local p = Pelts[peltNet]
        if p.charid ~= ctx.charid then return nil end
        return { price = p.price, big = p.big }
    end
    if (PeltCount[ctx.charid] or 0) >= PC.maxPerChar then return nil end
    local pelt = bodyNear(ctx.src, peltNet, PC.peltRange)
    if not pelt or GetEntityType(pelt) ~= 3 then return nil end
    if recentlySold(peltNet) then return nil end
    local carcass = bodyNear(ctx.src, carcassNet, PC.skinRange)
    if not carcass or not carcassDead(carcass) then return nil end
    if UsedCarcass[carcassNet] then return nil end
    local row = carcassRow(carcass, outfit)
    if not row then return nil end
    UsedCarcass[carcassNet] = os.time()
    -- the quality only picks one of THIS row's listed quality hashes; anything else is poor
    local price = U.peltPrice(row, quality)
    local p = addPelt(peltNet, ctx.charid, row, GetEntityModel(carcass), outfit, price)
    return { price = p.price, big = p.big }
end, { gapMs = 250 })

-- a registered small pelt went onto the player's horse
Handle('peltStow', function(ctx, peltNet)
    peltNet = tonumber(peltNet)
    local p = peltNet and Pelts[peltNet]
    if not p or p.charid ~= ctx.charid or p.big then return false end
    dropPelt(peltNet)
    HorseTally[ctx.charid] = U.round((HorseTally[ctx.charid] or 0) + p.price, 2)
    return true
end, { gapMs = 250 })

------------------------------------------------------------------------------ butcher sales

Handle('sell', function(ctx, idx, netId, info)
    if not Config.Butchers.enabled then return false end
    local b = CampButchers[tonumber(idx) or -1]
    if not b then return false end
    if not NearPoint(ctx.src, b.pos, Config.Butchers.range) then return false, L('too_far') end
    local ent, why, value, label, model, isPelt = checkBody(ctx.src, netId, info)
    if not ent then return false, why end
    netId = tonumber(netId)
    SoldIds[netId] = os.time()
    if isPelt then dropPelt(netId) else UsedCarcass[netId] = os.time() end
    DeleteEntity(ent)
    local bonus = ecoBonus(ctx.src, b.name, value)
    local paid = U.round(value + bonus, 2)
    if paid > 0 then GiveCash(ctx, paid) end
    if Config.Butchers.rewardItems and not isPelt then
        local row = U.animalRow(model, type(info) == 'table' and info.outfit or nil)
        for _, it in ipairs(row and row.items or {}) do
            if exports.vorp_inventory:canCarryItem(ctx.src, it.name, it.count) then
                exports.vorp_inventory:addItem(ctx.src, it.name, it.count)
            end
        end
    end
    Notify(ctx.src, L('sold_for', label, U.money(paid)))
    ButcherLog('Animal Sold', LogColour.green, {
        { 'Seller', Who(ctx.src) },
        { 'Model', tostring(U.h32(model)) .. (isPelt and ' (pelt)' or ''), true },
        { 'Butcher', b.name, true },
        { 'Paid', U.money(paid) .. (bonus > 0 and (' (Eco Boost ' .. U.money(bonus) .. ')') or ''), true },
    })
    return true
end, { gapMs = 2000 })

-- horse pelts: the server's own tally of registered pelts; the client's number is ignored
local function horsePelts(ctx)
    local tally = HorseTally[ctx.charid] or 0
    if tally <= 0 then return 0 end
    local amount = takeBudget(ctx.charid, math.min(tally, U.horsePeltCap()))
    if amount > 0 then HorseTally[ctx.charid] = nil end
    return amount
end

Handle('sellHorse', function(ctx, idx)
    if not Config.Butchers.enabled then return false end
    local b = CampButchers[tonumber(idx) or -1]
    if not b then return false end
    if not NearPoint(ctx.src, b.pos, Config.Butchers.range) then return false, L('too_far') end
    local amount = horsePelts(ctx)
    if amount <= 0 then return false, L('nothing_to_sell') end
    local bonus = ecoBonus(ctx.src, b.name, amount)
    local paid = U.round(amount + bonus, 2)
    GiveCash(ctx, paid)
    Notify(ctx.src, L('sold_pelts', U.money(paid)))
    ButcherLog('Horse Pelts Sold', LogColour.green, {
        { 'Seller', Who(ctx.src) }, { 'Butcher', b.name, true },
        { 'Paid', U.money(paid) .. (bonus > 0 and (' (Eco Boost ' .. U.money(bonus) .. ')') or ''), true },
    })
    return true
end, { gapMs = 2000 })

------------------------------------------------------------------------------ donations to the trapper

Handle('donate', function(ctx, campId, netId, info)
    local camp, why = Can(ctx, campId, nil)
    if not camp then return false, why end
    local ent, why2, value, label, _, isPelt = checkBody(ctx.src, netId, info)
    if not ent then return false, why2 end
    netId = tonumber(netId)
    SoldIds[netId] = os.time()
    if isPelt then dropPelt(netId) else UsedCarcass[netId] = os.time() end
    DeleteEntity(ent)
    camp.material = U.round(camp.material + value, 4)
    Save(camp)
    Notify(ctx.src, L('donated', ('%.2f'):format(value), ('%.2f'):format(camp.material)))
    CampLog(camp, 'supplies', 'Animal Donated', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Animal', label .. (isPelt and ' (pelt)' or ''), true },
        { 'Materials added', ('%.2f'):format(value), true }, { 'Camp materials', ('%.2f'):format(camp.material), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 2000 })

Handle('donateHorse', function(ctx, campId)
    local camp, why = Can(ctx, campId, nil)
    if not camp then return false, why end
    local amount = horsePelts(ctx)
    if amount <= 0 then return false, L('nothing_to_donate') end
    camp.material = U.round(camp.material + amount, 4)
    Save(camp)
    Notify(ctx.src, L('donated', ('%.2f'):format(amount), ('%.2f'):format(camp.material)))
    CampLog(camp, 'supplies', 'Pelts Donated', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Animal', 'Horse pelts', true },
        { 'Materials added', ('%.2f'):format(amount), true }, { 'Camp materials', ('%.2f'):format(camp.material), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 2000 })

------------------------------------------------------------------------------ hunting-wagon stash

local WStash  = {}  -- [charid] = { [key] = entry }
local Pending = {}  -- [charid] = { key, entry, expires, src }

local function loadStash(charid)
    if WStash[charid] then return WStash[charid] end
    local raw = MySQL.scalar.await('SELECT stash FROM wagon_stash WHERE charid = ?', { charid })
    local t = {}
    local decoded = Decode(raw, {})
    if type(decoded) == 'table' then
        for k, e in pairs(decoded) do
            local key = tonumber(k)
            if key and type(e) == 'table' then t[key] = e end
        end
    end
    WStash[charid] = WStash[charid] or t
    return WStash[charid]
end

local function saveStash(charid)
    local t = WStash[charid] or {}
    local out = {}
    for k, e in pairs(t) do out[tostring(k)] = e end
    MySQL.query.await('INSERT INTO wagon_stash (charid, stash) VALUES (?, ?) ON DUPLICATE KEY UPDATE stash = VALUES(stash)',
        { charid, json.encode(out) })
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function entryName(e)
    if e.humanbody then return L('hw_human') end
    local row = U.animalRow(e.model, e.outfit)
    if not row then return L('hw_unknown') end
    local label = U.trim(row.label)
    return e.isskin and L('hw_skin', label) or L('hw_body', label)
end

local function listOf(t)
    local list = {}
    for k, e in pairs(t) do list[#list + 1] = { key = k, name = entryName(e) } end
    table.sort(list, function(a, b) return a.key < b.key end)
    return { entries = list, count = #list, max = Config.HuntingWagon.maxEntries }
end

local function n(v) local x = tonumber(v) if x and x == x then return x end return 0 end

local function cleanData(kind, d)
    d = type(d) == 'table' and d or {}
    if kind == 'pelt' then
        return { model = n(d.model), model2 = n(d.model2), netid = n(d.netid), peltquality = n(d.peltquality) }
    end
    local tags = {}
    if type(d.metatag) == 'table' then
        for i, t in ipairs(d.metatag) do
            if i > 64 then break end
            if type(t) == 'table' then
                tags[#tags + 1] = {
                    drawable = n(t.drawable), albedo = n(t.albedo), normal = n(t.normal), material = n(t.material),
                    palette = n(t.palette), tint0 = n(t.tint0), tint1 = n(t.tint1), tint2 = n(t.tint2),
                }
            end
        end
    end
    return {
        model = n(d.model), model2 = n(d.model2), netid = n(d.netid), outfit = n(d.outfit),
        skinned = d.skinned == true, quality = n(d.quality), damage = n(d.damage), metatag = tags,
    }
end

local function nearHuntingWagon(src)
    local pos = PlayerPos(src)
    if not pos then return true end
    local want = U.h32(Config.HuntingWagon.model)
    for _, veh in ipairs(GetAllVehicles()) do
        if U.h32(GetEntityModel(veh)) == want then
            local c = GetEntityCoords(veh)
            if U.dist3(pos, { x = c.x, y = c.y, z = c.z }) <= Config.HuntingWagon.nearDistance + 4.0 then return true end
        end
    end
    return false
end

Handle('hwList', function(ctx)
    return listOf(loadStash(ctx.charid))
end, { gapMs = 500 })

Handle('hwPut', function(ctx, netId, rec)
    if type(rec) ~= 'table' then return nil end
    netId = tonumber(netId)
    local kind = rec.kind
    if kind ~= 'pelt' and kind ~= 'carcass' and kind ~= 'human' then return nil end
    local ent = bodyNear(ctx.src, netId, 10.0)
    if not ent then return nil, L('hw_stash_failed') end
    if not nearHuntingWagon(ctx.src) then return nil, L('hw_stash_failed') end
    local peltRec, model, outfit = nil, nil, tonumber(rec.outfit) or 0
    if kind == 'human' then
        if GetEntityType(ent) ~= 1 or GetEntityHealth(ent) > 0 then return nil, L('hw_stash_failed') end
        if U.animalRow(GetEntityModel(ent), nil) then return nil, L('hw_stash_failed') end
        model = GetEntityModel(ent)
    elseif kind == 'pelt' then
        if GetEntityType(ent) ~= 3 then return nil, L('hw_stash_failed') end
        -- only a registered pelt; its animal comes from the server record
        peltRec = Pelts[netId]
        if not peltRec then return nil, L('nobody_buys') end
        model, outfit = peltRec.model, peltRec.outfit
    else
        if GetEntityType(ent) ~= 1 or not carcassDead(ent) then return nil, L('hw_stash_failed') end
        if not carcassRow(ent, rec.outfit) then return nil, L('nobody_buys') end
        model = GetEntityModel(ent)
    end
    if type(rec.data) ~= 'table' then return nil, L('hw_stash_failed') end
    local t = loadStash(ctx.charid)
    if count(t) >= Config.HuntingWagon.maxEntries then return nil, L('hw_full', Config.HuntingWagon.maxEntries) end
    -- a body cannot be stashed twice
    if recentlySold(netId) then return nil, L('hw_stash_failed') end

    local data = cleanData(kind == 'pelt' and 'pelt' or 'carcass', rec.data)
    if kind == 'carcass' then
        data.skinned = carcassUsed(netId, ent)
    elseif kind == 'pelt' then
        data.model = U.signed(model)
    end
    local network = rec.animalnetwork
    if type(network) ~= 'number' and type(network) ~= 'string' then network = nil end
    if type(network) == 'string' then network = network:sub(1, 64) end

    local top = 0
    for k in pairs(t) do if k > top then top = k end end
    t[top + 1] = {
        animalnetwork = network,
        model = U.signed(model),
        outfit = outfit,
        isskin = kind == 'pelt',
        humanbody = kind == 'human',
        peltprice = peltRec and peltRec.price or nil,  -- server-decided; restored on take-out
        data = data,
    }
    SoldIds[netId] = os.time()
    if peltRec then dropPelt(netId) end
    saveStash(ctx.charid)
    -- the body goes only once the stash holds it
    if DoesEntityExist(ent) then DeleteEntity(ent) end
    return listOf(t)
end, { gapMs = Config.HuntingWagon.stashCooldown * 1000 })

Handle('hwTake', function(ctx, key)
    key = tonumber(key)
    if not key then return nil end
    if Pending[ctx.charid] then return nil, L('hw_pending') end
    if not nearHuntingWagon(ctx.src) then return nil, L('hw_busy') end
    local t = loadStash(ctx.charid)
    local e = t[key]
    if not e then return nil, L('hw_gone') end
    t[key] = nil
    local m = (e.data and e.data.model2 ~= 0) and e.data.model2 or e.model
    Pending[ctx.charid] = {
        key = key, entry = e, expires = os.time() + Config.HuntingWagon.pendingTimeout, src = ctx.src,
        models = { [U.h32(m)] = true, [U.h32(e.model)] = true }, spawned = {},
    }
    saveStash(ctx.charid)
    pcall(Integrations.allowSpawn, ctx.src, m, Config.HuntingWagon.pendingTimeout * 1000)
    return e
end, { gapMs = 1000 })

-- The client spawns the body it took out. Every matching entity that player's game creates while
-- the take-out is pending is noted, so an unconfirmed take-out can remove it again: a body is
-- either back in the world or back in the stash, never both.
local function creatorOf(ent)
    local ok, o = pcall(NetworkGetFirstEntityOwner, ent)
    if ok and tonumber(o) and tonumber(o) > 0 then return tonumber(o) end
    return tonumber(NetworkGetEntityOwner(ent))
end

AddEventHandler('entityCreated', function(ent)
    if next(Pending) == nil or not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local owner = creatorOf(ent)
    if not owner or owner <= 0 then return end
    local model = U.h32(GetEntityModel(ent))
    for _, p in pairs(Pending) do
        if p.src == owner and p.models and p.models[model] then
            -- only bodies made right beside the player (wild animals of that kind spawn much further out)
            local pos, c = PlayerPos(owner), GetEntityCoords(ent)
            if not pos or U.dist3(pos, { x = c.x, y = c.y, z = c.z }) <= 15.0 then
                p.spawned[#p.spawned + 1] = ent
            end
            return
        end
    end
end)

local function removeSpawned(p, keep)
    for _, ent in ipairs(p.spawned or {}) do
        if ent ~= keep and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
end

local function restore(charid)
    local p = Pending[charid]
    if not p then return end
    Pending[charid] = nil
    removeSpawned(p, nil)
    -- never drop the entry: reload the stash if it is no longer cached
    local t = WStash[charid] or loadStash(charid)
    local key = p.key
    if t[key] then
        local top = 0
        for k in pairs(t) do if k > top then top = k end end
        key = top + 1
    end
    t[key] = p.entry
    saveStash(charid)
end

Handle('hwTaken', function(ctx, key, netId)
    local p = Pending[ctx.charid]
    if not p or p.key ~= tonumber(key) then return false end
    netId = tonumber(netId) or 0
    if netId == 0 then
        restore(ctx.charid)
        return listOf(loadStash(ctx.charid))
    end
    local ent = NetworkGetEntityFromNetworkId(netId)
    local e = p.entry
    if e.isskin then
        -- the new pelt object must be a real object beside the player before it is registered
        local obj = bodyNear(ctx.src, netId, 10.0)
        if not obj or GetEntityType(obj) ~= 3 then
            restore(ctx.charid)
            return false
        end
    end
    Pending[ctx.charid] = nil
    -- one entry, one body: any extra copy the client made goes
    removeSpawned(p, ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        if e.animalnetwork ~= nil then Entity(ent).state:set('network', e.animalnetwork, true) end
        if e.data and e.data.skinned then
            Entity(ent).state:set('skinned', true, true)
            UsedCarcass[netId] = os.time()
            pcall(Integrations.markSkinned, netId)
        end
    end
    if e.isskin then
        local row = U.animalRow(e.model, e.outfit)
        if not row then return true end
        local price = tonumber(e.peltprice) or U.peltPrice(row, e.data and e.data.peltquality)
        local rec = addPelt(netId, ctx.charid, row, e.model, e.outfit, price)
        return { price = rec.price, big = rec.big }
    end
    return true
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for charid, p in pairs(Pending) do
            if now >= p.expires then restore(charid) end
        end
        for id, t in pairs(SoldIds) do
            if now - t > Config.Butchers.resaleMemory then SoldIds[id] = nil end
        end
        for id, t in pairs(UsedCarcass) do
            if now - t > PC.forgetMin * 60 then UsedCarcass[id] = nil end
        end
        for id, p in pairs(Pelts) do
            -- an old record, or a pelt object gone for a minute (time for a horse stow to
            -- be reported), is forgotten
            local ent = NetworkGetEntityFromNetworkId(id)
            if not ent or ent == 0 or not DoesEntityExist(ent) then
                p.gone = p.gone or now
            else
                p.gone = nil
            end
            if now - p.t > PC.forgetMin * 60 or (p.gone and now - p.gone > 60) then dropPelt(id) end
        end
    end
end)

function HuntingForget(src, charid)
    if charid and Pending[charid] then restore(charid) end
    if charid then
        WStash[charid] = nil
        HorseTally[charid] = nil
    end
end
