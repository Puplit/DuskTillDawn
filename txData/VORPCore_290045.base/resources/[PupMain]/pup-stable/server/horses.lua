-- pup-stable | horse ownership actions: buying, tack, colours, names, release, transfers, stabling

local Inv = exports.vorp_inventory
local transferTimers = { horse = {}, wagon = {} }   -- memory only (stable-to-stable "Transfer here")

function TransferBusy(kind, id)
    local t = transferTimers[kind] and transferTimers[kind][id]
    if t and GetGameTimer() < t then return math.ceil((t - GetGameTimer()) / 1000) end
    return nil
end

local function atStable(ctx, stableId, reach)
    local s = StableById(stableId)
    if not s then return nil end
    if not Near(ctx.src, s.location, reach or 40.0) then return nil end
    if not Config.Hooks.canAccessStable(ctx.src, stableId) then return nil end
    return s
end

local function jobOk(ctx, job)
    return not job or ctx.job == job
end

local function count(map, charid)
    local n = 0
    for _ in pairs(map[charid] or {}) do n = n + 1 end
    return n
end

------------------------------------------------------------------------------
-- lists
------------------------------------------------------------------------------
Rpc('myHorses', { gap = 300 }, function(ctx)
    local horses, comps = {}, {}
    for _, h in ipairs(HorsesOf(ctx.charid)) do
        if h.identifier == ctx.identifier then horses[#horses + 1] = HorsePayload(h) end
    end
    for _, c in ipairs(CompsOf(ctx.charid)) do
        if c.identifier == ctx.identifier and not U.UNIQUE[c.category] then comps[#comps + 1] = CompPayload(c) end
    end
    return true, horses, comps, CanColor(ctx), ctx.job
end)

Rpc('myWagons', { gap = 300 }, function(ctx)
    local out = {}
    for _, w in ipairs(WagonsOf(ctx.charid)) do
        if w.identifier == ctx.identifier then out[#out + 1] = WagonPayload(w) end
    end
    return true, out
end)

Rpc('colorPermission', { gap = 500 }, function(ctx) return true, CanColor(ctx) end)

------------------------------------------------------------------------------
-- buying a horse
------------------------------------------------------------------------------
-- ranks from config/horse_stats.lua for this model, else the most common among its breed's coats there
local function listedBirth(model, br)
    local T = Config.HorseBirthStats or {}
    local r = T[model:lower()]
    if not r and br then
        local tally, best, bestN = {}, nil, 0
        for _, c in ipairs(br.coats) do
            local v = T[c.model:lower()]
            if v then
                local k = ('%d:%d:%d'):format(U.int(v[1], 1), U.int(v[2], 1), U.int(v[3], 1))
                tally[k] = (tally[k] or 0) + 1
                if tally[k] > bestN then best, bestN = v, tally[k] end
            end
        end
        r = best
    end
    if not r then return nil end
    return U.int(r[1]), U.int(r[2]), U.int(r[3])
end

-- birth stats of a new horse of this model, decided here. The game's base ranks live on the ped and
-- the server cannot read them, so the source is, in order: `stats = { speed, acceleration, handling,
-- health, stamina }` on the coat or breed in config/horses.lua, config/horse_stats.lua (the model,
-- then its breed), then Config.Starter's ranks. Returns speed, acceleration, handling, health, stamina.
function BirthStats(model)
    model = tostring(model or '')
    local br, coat = BreedOfModel(model)
    local fixed = (coat and type(coat.stats) == 'table' and coat.stats) or (br and type(br.stats) == 'table' and br.stats) or nil
    local sp, ac, hd
    if fixed then
        sp, ac, hd = U.int(fixed.speed), U.int(fixed.acceleration), U.int(fixed.handling)
    else
        sp, ac, hd = listedBirth(model, br)
        if not sp then
            local S = Config.Starter
            sp, ac, hd = S.speed, S.acceleration, S.handling
            WarnOnce('birth:' .. model:lower(), ('no birth ranks known for %s: using Config.Starter ranks (set stats on its breed in config/horses.lua)'):format(model))
        end
    end
    local c = Config.Training.ceilings
    fixed = fixed or {}
    return U.clamp(U.int(sp, 1), 1, c.speed), U.clamp(U.int(ac, 1), 1, c.acceleration), U.clamp(U.int(hd, 1), 1, c.handling),
        U.clamp(U.int(fixed.health, 0), 0, 5000), U.clamp(U.int(fixed.stamina, 0), 0, 5000)
end

local LOOK_CATS = { mane = 'horse_manes', tail = 'horse_tails', mustache = 'horse_mustache', shoes = 'horse_shoes' }

-- the horse's own look rows; coat colour only for players allowed custom colours
local function writeLook(ctx, h, look, coatColor)
    look = type(look) == 'table' and look or {}
    for key, cat in pairs(LOOK_CATS) do
        local hash = U.int(look[key])
        if hash and hash ~= 0 and U.catalogueIndex(cat, hash) then CreateComp(ctx, cat, hash, h.id, nil) end
    end
    if type(coatColor) == 'table' then
        local headGuid = type(coatColor.head) == 'table' and coatColor.head or {}
        local bodyGuid = type(coatColor.body) == 'table' and coatColor.body or {}
        local pal = U.cleanName(coatColor.palette, 100)
        if pal then
            if not pal:find('^metaped_') then pal = 'metaped_' .. pal end
            CreateComp(ctx, 'horse_heads', 0, h.id, { drawable = headGuid.drawable, albedo = headGuid.albedo, normal = headGuid.normal, material = headGuid.material,
                palette = pal, tint0 = coatColor.tint0, tint1 = coatColor.tint1, tint2 = coatColor.tint2 })
            CreateComp(ctx, 'horse_bodies', 0, h.id, { drawable = bodyGuid.drawable, albedo = bodyGuid.albedo, normal = bodyGuid.normal, material = bodyGuid.material,
                palette = pal, tint0 = coatColor.tint0, tint1 = coatColor.bodyTint1, tint2 = coatColor.bodyTint2 })
        end
    end
end

Rpc('buyHorse', { gap = 1000 }, function(ctx, req)
    if type(req) ~= 'table' then return false end
    local br = Config.BreedById[U.int(req.breed, -1)]
    local coat = br and br.coats[U.int(req.coat, -1)]
    if not coat then return false end
    local s = atStable(ctx, req.stable)
    if not s or not s.sellHorses then return false end
    local name = U.cleanName(req.name, Config.General.nameMax)
    if not name then return false, L('invalidName') end
    local job = coat.job or br.job
    if not jobOk(ctx, job) then return false, L('jobLocked', job) end
    local max = Config.Horse.maxPerCharacter
    if max > 0 and count(CharHorses, ctx.charid) >= max then return false, L('maxHorses') end
    local gold = req.gold == true and Config.General.useGold
    local price
    if gold then price = coat.gold or br.gold else price = coat.price or br.price or Config.General.horseFallbackPrice end
    if price == nil then return false, L('noMoney') end
    price = Config.Hooks.horsePrice(ctx.src, br.id, U.int(req.coat), price) or price
    if U.num(price, -1) < 0 then return false, L('noMoney') end
    if not Lock(ctx.src, 'buy') then return false, L('busy') end

    -- stats are decided here; the client's reading (req.stats) is not used
    local sp, ac, hd, hp, sta = BirthStats(coat.model)
    local custom = (req.coatColor and CanColor(ctx) and Config.Colors.onCoat) and req.coatColor or coat.color

    if not Charge(ctx.src, price, gold and 1 or 0) then Unlock(ctx.src, 'buy') return false, L('noMoney') end
    local ok, h = pcall(CreateHorse, {
        identifier = ctx.identifier, charid = ctx.charid, stable = s.id, model = coat.model, isFemale = req.female == true, name = name,
        speed = sp, acceleration = ac, handling = hd, favourite = FavouriteOf(ctx.charid) == nil,
        health = hp, stamina = sta,
    })
    if not ok or not h then
        Refund(ctx.src, price, gold and 1 or 0)
        Unlock(ctx.src, 'buy')
        return false, L('transferFailed')
    end
    pcall(writeLook, ctx, h, req.look, custom)
    Unlock(ctx.src, 'buy')
    Notify(ctx.src, L('boughtHorse'))
    StableLog(ctx, 'Horse Bought', ('Bought horse %s (%s) for %s (%s)'):format(name, coat.model, U.money(price), gold and 'Gold' or 'Cash'))
    return true, HorsePayload(h)
end)

------------------------------------------------------------------------------
-- tack
------------------------------------------------------------------------------
local SELLABLE = { horse_manes = true, horse_tails = true, horse_mustache = true, horse_shoes = true }

local function cleanColor(c)
    if type(c) ~= 'table' then return nil end
    local pal = U.cleanName(c.palette, 100)
    if not pal then return nil end
    if not pal:find('^metaped_') then pal = 'metaped_' .. pal end
    return { palette = pal, tint0 = c.tint0, tint1 = c.tint1, tint2 = c.tint2, drawable = c.drawable, albedo = c.albedo, normal = c.normal, material = c.material }
end

-- equip c on h; replaces whatever of that category the horse wore
local function equipOn(h, c)
    for _, other in ipairs(HorseComps(h)) do
        if other.id ~= c.id and other.category == c.category then
            if U.UNIQUE[other.category] then
                MySQL.update.await('DELETE FROM stable_bought WHERE id = ?', { other.id })
                DropComp(other)
            else
                SetCompOn(other, 0)
            end
        end
    end
    SetCompOn(c, h.id)
    local ent = HorseEnt[h.id]
    if ent and DoesEntityExist(ent) then
        local bag, lantern = HorseCompOf(h, 'horse_saddlebags'), HorseCompOf(h, 'saddle_lanterns')
        Entity(ent).state:set('pup_stable_saddlebagID', bag and bag.id or false, true)
        Entity(ent).state:set('pup_stable_lanternID', lantern and lantern.id or false, true)
    end
end

Rpc('buyComp', { gap = 800 }, function(ctx, req)
    if type(req) ~= 'table' then return false end
    local cat = req.category
    if type(cat) ~= 'string' or not (U.TACK_SET[cat] or SELLABLE[cat]) then return false end
    local s = atStable(ctx, req.stable)
    if not s or not s.sellComponents then return false end
    local index = U.catalogueIndex(cat, req.hash)
    if not index then return false end
    local horseId = U.int(req.horse, 0)
    local h = nil
    if horseId ~= 0 then
        h = OwnedHorse(ctx, horseId)
        if not h then return false, L('notYourHorse') end
    elseif SELLABLE[cat] then
        return false
    end
    local gold = req.gold == true and Config.General.useGold
    local over = Config.Prices.componentOverrides[cat]
    local price
    if gold then price = Config.Prices.componentGold[cat] else price = (over and over[index]) or Config.Prices.components[cat] end
    if price == nil then return false, L('noMoney') end
    price = Config.Hooks.componentPrice(ctx.src, cat, index, price) or price
    if U.num(price, -1) < 0 then return false, L('noMoney') end
    local color = (req.color and CanColor(ctx) and Config.Colors.onTack) and cleanColor(req.color) or nil
    if not Lock(ctx.src, 'tack') then return false, L('busy') end
    if not Charge(ctx.src, price, gold and 1 or 0) then Unlock(ctx.src, 'tack') return false, L('noMoney') end
    local ok, c = pcall(CreateComp, ctx, cat, req.hash, 0, color)
    if not ok or not c then
        Refund(ctx.src, price, gold and 1 or 0)
        Unlock(ctx.src, 'tack')
        return false
    end
    h = h and OwnedHorse(ctx, h.id)
    if h then equipOn(h, c) end
    Unlock(ctx.src, 'tack')
    Notify(ctx.src, L('boughtComponent'))
    return true, CompPayload(c), h and HorsePayload(h) or nil
end)

Rpc('equipComp', { gap = 400 }, function(ctx, compId, horseId, category)
    local c = OwnedComp(ctx, compId)
    local h = OwnedHorse(ctx, horseId)
    if not c or not h or U.UNIQUE[c.category] then return false end
    if category ~= nil and category ~= c.category then return false end
    if c.on == -1 then return false end
    equipOn(h, c)
    return true, HorsePayload(h)
end)

Rpc('unequipComp', { gap = 400 }, function(ctx, compId)
    local c = OwnedComp(ctx, compId)
    if not c or U.UNIQUE[c.category] or c.on <= 0 then return false end
    local h = OwnedHorse(ctx, c.on)
    if not h then return false end
    SetCompOn(c, 0)
    local ent = HorseEnt[h.id]
    if ent and DoesEntityExist(ent) then
        if c.category == 'horse_saddlebags' then Entity(ent).state:set('pup_stable_saddlebagID', false, true) end
        if c.category == 'saddle_lanterns' then Entity(ent).state:set('pup_stable_lanternID', false, true) end
    end
    return true, HorsePayload(h)
end)

------------------------------------------------------------------------------
-- coat colour on an owned horse
------------------------------------------------------------------------------
Rpc('saveCoat', { gap = 1000 }, function(ctx, horseId, color)
    local h = OwnedHorse(ctx, horseId)
    if not h or type(color) ~= 'table' then return false end
    local pal = U.cleanName(color.palette, 100)
    if not pal then return false, L('noPalette') end
    if not pal:find('^metaped_') then pal = 'metaped_' .. pal end
    if not Lock(ctx.src, 'color') then return false, L('busy') end
    local item = Config.Colors.coatChangerItem
    local paid = false
    if not CanColor(ctx) then
        local ok, done = pcall(function() return Inv:subItem(ctx.src, item, 1) end)
        if not ok or done == false then Unlock(ctx.src, 'color') return false end
        paid = true
    end
    local good = pcall(function()
        local head, body = HorseCompOf(h, 'horse_heads'), HorseCompOf(h, 'horse_bodies')
        local hg = type(color.head) == 'table' and color.head or {}
        local bg = type(color.body) == 'table' and color.body or {}
        local hc = { drawable = hg.drawable, albedo = hg.albedo, normal = hg.normal, material = hg.material, palette = pal, tint0 = color.tint0, tint1 = color.tint1, tint2 = color.tint2 }
        local bc = { drawable = bg.drawable, albedo = bg.albedo, normal = bg.normal, material = bg.material, palette = pal, tint0 = color.tint0, tint1 = color.bodyTint1, tint2 = color.bodyTint2 }
        if head then SetCompColor(head, hc, true) else assert(CreateComp(ctx, 'horse_heads', 0, h.id, hc)) end
        if body then SetCompColor(body, bc, true) else assert(CreateComp(ctx, 'horse_bodies', 0, h.id, bc)) end
    end)
    Unlock(ctx.src, 'color')
    if not good then
        if paid then pcall(function() Inv:addItem(ctx.src, item, 1) end) end
        return false
    end
    local ent = HorseEnt[h.id]
    if ent and DoesEntityExist(ent) and SpawnedBy[h.id] then
        TriggerClientEvent('pup-stable:redress', SpawnedBy[h.id], NetworkGetNetworkIdFromEntity(ent), HorsePayload(h))
    end
    Notify(ctx.src, L('congrats'))
    return true, HorsePayload(h)
end)

------------------------------------------------------------------------------
-- favourite, rename, release, shoes, focus
------------------------------------------------------------------------------
function SetFavourite(ctx, horseId)
    local h = OwnedHorse(ctx, horseId)
    if not h then return false end
    if Config.Horse.realistic then return false end
    for _, o in ipairs(HorsesOf(ctx.charid)) do
        if o.favourite and o.id ~= h.id then o.favourite = false; SaveHorse(o, 'favourite') end
    end
    if not h.favourite then h.favourite = true; SaveHorse(h, 'favourite') end
    return true
end

Rpc('favourite', { gap = 500 }, function(ctx, horseId) return SetFavourite(ctx, horseId) end)

RegisterNetEvent('pup-stable:server:newFavourite', function(horseId)
    local src = source
    if not Ready or not Throttle(src, 'fav', 500) then return end
    local ctx = Ctx(src)
    if ctx and SetFavourite(ctx, horseId) then TriggerClientEvent('pup-stable:listChanged', src) end
end)

function RenameHorse(ctx, horseId, name)
    local h = OwnedHorse(ctx, horseId)
    name = U.cleanName(name, Config.General.nameMax)
    if not h or not name then return false, L('invalidName') end
    h.name = name
    SaveHorse(h, 'name')
    Notify(ctx.src, L('renamedHorse', name))
    return true
end

function RenameWagon(ctx, wagonId, name)
    local w = OwnedWagon(ctx, wagonId)
    name = U.cleanName(name, Config.General.nameMax)
    if not w or not name then return false, L('invalidName') end
    w.name = name
    SaveWagon(w, 'name')
    local ent = WagonEnt[w.id]
    if ent and DoesEntityExist(ent) then Entity(ent).state:set('pup_stable_wagonName', WagonLabel(w), true) end
    Notify(ctx.src, L('renamedWagon', name))
    return true
end

Rpc('renameHorse', { gap = 800 }, RenameHorse)
Rpc('renameWagon', { gap = 800 }, RenameWagon)

RegisterNetEvent('pup-stable:server:renameHorse', function(horseId, name)
    local src = source
    if not Ready or not Throttle(src, 'renameH', 800) then return end
    local ctx = Ctx(src)
    if ctx and RenameHorse(ctx, horseId, name) then TriggerClientEvent('pup-stable:listChanged', src) end
end)

RegisterNetEvent('pup-stable:server:renameWagon', function(wagonId, name)
    local src = source
    if not Ready or not Throttle(src, 'renameW', 800) then return end
    local ctx = Ctx(src)
    if ctx and RenameWagon(ctx, wagonId, name) then TriggerClientEvent('pup-stable:listChanged', src, 'wagons') end
end)

Rpc('releaseHorse', { gap = 1000 }, function(ctx, horseId)
    local h = OwnedHorse(ctx, horseId)
    if not h then return false end
    if not Lock(ctx.src, 'release') then return false, L('busy') end
    local dead, name = h.isDead, h.name
    UnlinkHorse(h.id, true)
    local ok = pcall(DeleteHorseRow, h)
    Unlock(ctx.src, 'release')
    if not ok then return false end
    Notify(ctx.src, dead and L('deletedHorse', name) or L('released', name))
    return true
end)

Rpc('buyShoes', { gap = 1000 }, function(ctx, horseId, stableId)
    if not Config.Shoes.enabled then return false, L('disabled') end
    local h = OwnedHorse(ctx, horseId)
    if not h or not atStable(ctx, stableId) then return false end
    if not Charge(ctx.src, Config.Shoes.price, 0) then return false, L('noMoney') end
    h.st.lastNewShoes = h.st.distance
    MarkStats(h)
    local ent = HorseEnt[h.id]
    if ent and DoesEntityExist(ent) then Entity(ent).state:set('pup_stable_stat_lastNewShoes', h.st.lastNewShoes, true) end
    Notify(ctx.src, L('shoesReady', Config.Shoes.lifeKm))
    return true, HorsePayload(h)
end)

-- the U menu: horse panel (own horse, within reach)
Rpc('horsePanel', { gap = 600 }, function(ctx, netId)
    local ent = EntFromNet(netId, 1000)
    local h = HorseOfEnt(ent, ctx)
    if not h or h.charid ~= ctx.charid or h.identifier ~= ctx.identifier then return false end
    if not EntNear(ctx.src, ent, Config.Training.trainerDistance) then return false end
    local p = HorsePayload(h)
    p.wallets = { speed = h.st.speedXP, acceleration = h.st.accelerationXP, handling = h.st.handlingXP }
    p.level = U.level(h.st.xp)
    return true, p, IsTrainer(ctx)
end)

Rpc('setFocus', { gap = 500 }, function(ctx, netId, stat)
    if not IsTrainer(ctx) or type(stat) ~= 'string' or not U.FOCUS[stat] then return false end
    local ent = EntFromNet(netId, 1000)
    local h = HorseOfEnt(ent, ctx)
    if not h or h.charid ~= ctx.charid or h.identifier ~= ctx.identifier then return false end
    if not EntNear(ctx.src, ent, Config.Training.trainerDistance) then return false end
    h.st.focus = h.st.focus == stat and '' or stat
    MarkStats(h)
    return true, h.st.focus
end)

------------------------------------------------------------------------------
-- player to player transfer
------------------------------------------------------------------------------
local function transferTarget(ctx, target)
    target = U.int(target)
    if not target then return nil, L('playerAbsent') end
    if target == ctx.src then return nil, L('ownId') end
    local tctx = Ctx(target)
    if not tctx or not PedPos(target) then return nil, L('playerAbsent') end
    local a, b = PedPos(ctx.src), PedPos(target)
    if not a or #(a - b) > Config.General.transferDistance then return nil, L('tooFar') end
    return tctx
end

Rpc('transferHorse', { gap = 1000 }, function(ctx, horseId, target)
    local tctx, err = transferTarget(ctx, target)
    if not tctx then return false, err end
    local h = OwnedHorse(ctx, horseId)
    if not h then return false, L('notYourHorse') end
    if not Config.Hooks.canTransferHorse(ctx.src, h.id, tctx.src) then return false, L('cantTransfer') end
    if not Lock(ctx.src, 'transfer') then return false, L('busy') end
    local fav = FavouriteOf(tctx.charid) == nil
    local bag = HorseCompOf(h, 'horse_saddlebags')
    local queries = {
        { query = 'UPDATE stable_horses SET identifier = ?, charid = ?, favourite = ?, isOut = 0 WHERE id = ? AND charid = ?', values = { tctx.identifier, tctx.charid, fav and 1 or 0, h.id, ctx.charid } },
        { query = 'UPDATE stable_bought SET identifier = ?, charid = ? WHERE equiped_on = ? AND charid = ?', values = { tctx.identifier, tctx.charid, h.id, ctx.charid } },
    }
    if bag then
        queries[#queries + 1] = { query = 'UPDATE character_inventories SET character_id = ? WHERE inventory_type = ?', values = { tctx.charid, BagInvName(bag.id) } }
    end
    local ok, res = pcall(MySQL.transaction.await, queries)
    -- re-check after the await
    if not ok or not res or not OwnedHorse(ctx, h.id) or not Ctx(tctx.src) then
        Unlock(ctx.src, 'transfer')
        return false, L('transferFailed')
    end
    UnlinkHorse(h.id, true)
    local moved = HorseComps(h)
    DropHorse(h)
    h.identifier, h.charid, h.favourite, h.isOut = tctx.identifier, tctx.charid, fav, false
    AddHorse(h)
    for _, c in ipairs(moved) do
        DropComp(c)
        c.identifier, c.charid = tctx.identifier, tctx.charid
        AddComp(c)
    end
    Unlock(ctx.src, 'transfer')
    Notify(ctx.src, L('transferred', h.name, tctx.name))
    Notify(tctx.src, L('receivedHorse', ctx.name))
    TriggerClientEvent('pup-stable:listChanged', tctx.src)
    StableLog(ctx, 'Horse Transferred', ('Transferred horse %s (%s) to %s (ID: %d)'):format(h.name, h.model, tctx.name, tctx.src))
    return true
end)

Rpc('transferWagon', { gap = 1000 }, function(ctx, wagonId, target)
    local tctx, err = transferTarget(ctx, target)
    if not tctx then return false, err end
    local w = OwnedWagon(ctx, wagonId)
    if not w then return false, L('notYourWagon') end
    if not Lock(ctx.src, 'transfer') then return false, L('busy') end
    local ok, res = pcall(MySQL.transaction.await, {
        { query = 'UPDATE stable_wagons SET identifier = ?, charid = ?, isOut = 0 WHERE id = ? AND charid = ?', values = { tctx.identifier, tctx.charid, w.id, ctx.charid } },
        { query = 'UPDATE character_inventories SET character_id = ? WHERE inventory_type = ?', values = { tctx.charid, LockerInvName(w.id) } },
    })
    if not ok or not res or not OwnedWagon(ctx, w.id) or not Ctx(tctx.src) then
        Unlock(ctx.src, 'transfer')
        return false, L('transferFailed')
    end
    -- the given wagon leaves the world with its old owner tag
    UnlinkWagon(w.id, true)
    DropWagon(w)
    w.identifier, w.charid, w.isOut = tctx.identifier, tctx.charid, false
    AddWagon(w)
    Unlock(ctx.src, 'transfer')
    Notify(ctx.src, L('transferred', WagonLabel(w), tctx.name))
    Notify(tctx.src, L('receivedWagon', ctx.name))
    TriggerClientEvent('pup-stable:listChanged', tctx.src, 'wagons')
    StableLog(ctx, 'Wagon Transferred', ('Transferred wagon %s (%s) to %s (ID: %d)'):format(WagonLabel(w), w.model, tctx.name, tctx.src))
    return true
end)

------------------------------------------------------------------------------
-- stable to stable (realistic mode only)
------------------------------------------------------------------------------
function StableTransferPrice(fromId, toId)
    local a, b = StableById(fromId), StableById(toId)
    if not a or not b then return nil end
    if Config.Transfer.flatPrice then return Config.Transfer.flatPrice end
    local km = #(vector3(a.location.x, a.location.y, a.location.z) - vector3(b.location.x, b.location.y, b.location.z)) / 1000.0
    return math.floor(km * Config.Transfer.pricePerKm * 100) / 100
end

-- mode 'send': instant, to `toStable`; mode 'bring': to the stable the player stands at, busy for a while
Rpc('stableTransfer', { gap = 1000 }, function(ctx, kind, id, toStable, mode)
    local realistic = kind == 'wagon' and Config.Wagon.realistic or Config.Horse.realistic
    if not realistic then return false, L('disabled') end
    local item = kind == 'horse' and OwnedHorse(ctx, id) or (kind == 'wagon' and OwnedWagon(ctx, id)) or nil
    if not item or item.isOut then return false end
    if mode == 'bring' then
        local s = atStable(ctx, toStable)
        if not s then return false end
    end
    if not StableById(toStable) or item.stable == toStable then return false end
    local price = StableTransferPrice(item.stable, toStable)
    if not price or not Charge(ctx.src, price, 0) then return false, L('noMoney') end
    item.stable = toStable
    if kind == 'horse' then SaveHorse(item, 'stable') else SaveWagon(item, 'stable') end
    if mode == 'bring' then transferTimers[kind][item.id] = GetGameTimer() + Config.Transfer.durationMs end
    return true, kind == 'horse' and HorsePayload(item) or WagonPayload(item)
end)

------------------------------------------------------------------------------
-- stabling a horse at a stable
------------------------------------------------------------------------------
Rpc('stableHorse', { gap = 800 }, function(ctx, netId, stableId)
    local s = atStable(ctx, stableId)
    if not s then return false end
    local ent = EntFromNet(netId, 1000)
    if not ent then return false end
    local h = HorseOfEnt(ent, ctx)
    if not h then
        -- not a stable horse: maybe a wild one this player broke in
        local verdict = WildHandInCheck and WildHandInCheck(ctx, ent) or nil
        if verdict == 'mine' then return false, 'wild' end
        if verdict == 'untamed' then return false, L('wh_breakFirst') end
        if verdict == 'other' then return false, L('wh_notTamer') end
        return false, L('cantStable')
    end
    if h.charid ~= ctx.charid or h.identifier ~= ctx.identifier then return false, L('cantStable') end
    PutAway(h, s.id)
    return true
end)

-- the delete-horse local event other resources fire maps here
Rpc('putAwayCurrent', { gap = 1000 }, function(ctx, horseId)
    if not Config.Horse.putAwayOnInteriorEvent then return false end
    local h = OwnedHorse(ctx, horseId)
    if not h then return false end
    PutAway(h, nil)
    return true
end)
