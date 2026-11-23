-- pup-stable | wagons: buying, customising, destroying, calling out and stabling

local CUSTOM = { vehicle_tints = 'int', vehicle_propsets = 'str', vehicle_liveries = 'int', vehicle_lantern_propsets = 'str', vehicle_extras = 'int' }

local function atStable(ctx, stableId)
    local s = StableById(stableId)
    if not s or not Near(ctx.src, s.location, 40.0) then return nil end
    if not Config.Hooks.canAccessStable(ctx.src, stableId) then return nil end
    return s
end

local function coerce(kind, v)
    if kind == 'int' then return U.clamp(U.int(v, -1), -2, 255) end
    v = tostring(v or '-1')
    if not v:match('^[%w_%-]+$') then return nil end
    return U.cut(v, 50)
end

Rpc('buyWagon', { gap = 1000 }, function(ctx, req)
    if type(req) ~= 'table' then return false end
    local cat = Config.WagonCategoryById[U.int(req.cat, -1)]
    local def = cat and cat.wagons[U.int(req.index, -1)]
    if not def then return false end
    local s = atStable(ctx, req.stable)
    if not s or not s.sellWagons then return false end
    local name = U.cleanName(req.name, Config.General.nameMax)
    if not name then return false, L('invalidName') end
    if not (not def.job or ctx.job == def.job) then return false, L('jobLocked', def.job) end
    local max = Config.Wagon.maxPerCharacter
    if max > 0 and #WagonsOf(ctx.charid) >= max then return false, L('maxWagons') end
    local gold = req.gold == true and Config.General.useGold
    local price = gold and def.gold or (def.price or cat.price or Config.General.wagonFallbackPrice)
    if price == nil or U.num(price, -1) < 0 then return false, L('noMoney') end
    -- "not for sale" wagons stay listed for owners but can never be bought
    if U.num(price, 0) >= Config.NotForSale then return false, L('notForSale') end
    if not Lock(ctx.src, 'buy') then return false, L('busy') end
    if not Charge(ctx.src, price, gold and 1 or 0) then Unlock(ctx.src, 'buy') return false, L('noMoney') end
    -- only looks this model really offers (a client could otherwise store any propset,
    -- including the explosive ones the catalogue leaves out); anything else gets the defaults
    local look = type(req.look) == 'table' and req.look or {}
    local function pick(col, v, def0)
        v = v == nil and def0 or v
        if U.wagonOptionIndex(def.model, col, v) == nil then return def0 end
        return v
    end
    local tint = U.int(pick('vehicle_tints', U.int(look.tint), 0), 0)
    local extra = U.int(pick('vehicle_extras', U.int(look.extra), -1), -1)
    local livery = U.int(pick('vehicle_liveries', U.int(look.livery), 0), 0)
    local propset = look.propset ~= nil and U.wagonOptionIndex(def.model, 'vehicle_propsets', tostring(look.propset)) and tostring(look.propset) or '0'
    local lantern = look.lantern ~= nil and U.wagonOptionIndex(def.model, 'vehicle_lantern_propsets', tostring(look.lantern)) and tostring(look.lantern) or '-1'
    local ok, id = pcall(MySQL.insert.await, [[INSERT INTO stable_wagons (identifier, charid, stable, model, name, vehicle_tints, vehicle_propsets,
        vehicle_liveries, vehicle_lantern_propsets, vehicle_extras, isOut) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)]],
        { ctx.identifier, ctx.charid, s.id, def.model, name, tint, propset, livery, lantern, extra })
    id = ok and U.int(id) or nil
    Unlock(ctx.src, 'buy')
    if not id or id <= 0 then
        Refund(ctx.src, price, gold and 1 or 0)
        return false, L('transferFailed')
    end
    local w = WagonFromRow({ id = id, identifier = ctx.identifier, charid = ctx.charid, stable = s.id, model = def.model, name = name,
        vehicle_tints = tint, vehicle_propsets = propset, vehicle_liveries = livery, vehicle_lantern_propsets = lantern, vehicle_extras = extra })
    AddWagon(w)
    Notify(ctx.src, L('boughtWagon'))
    StableLog(ctx, 'Wagon Bought', ('Bought wagon %s (%s) for %s (%s)'):format(name, def.model, U.money(price), gold and 'Gold' or 'Cash'))
    return true, WagonPayload(w)
end)

-- price of one customisation; index = position in the option list (0 = the "No ..." row),
-- as U.wagonOptionIndex works it out (the client's own index is never trusted)
function WagonCustomPrice(column, index)
    local over = Config.Prices.wagonCustomOverrides[column]
    if index == 0 and not Config.Prices.noneOptionCharged then return 0 end
    return (over and over[index]) or Config.Prices.wagonCustom[column] or 0
end

Rpc('customiseWagon', { gap = 600 }, function(ctx, wagonId, column, value, _, stableId)
    local kind = CUSTOM[column]
    if not kind then return false end
    local w = OwnedWagon(ctx, wagonId)
    if not w or not atStable(ctx, stableId) then return false end
    local v = coerce(kind, value)
    if v == nil then return false end
    local index = U.wagonOptionIndex(w.model, column, v)
    if index == nil then return false end
    local price = WagonCustomPrice(column, index)
    if not Charge(ctx.src, price, 0) then return false, L('noMoney') end
    w[column] = v
    SaveWagon(w, column)
    return true, WagonPayload(w)
end)

Rpc('destroyWagon', { gap = 1000 }, function(ctx, wagonId)
    local w = OwnedWagon(ctx, wagonId)
    if not w then return false end
    UnlinkWagon(w.id, true)
    local ok = pcall(DeleteWagonRow, w)
    if not ok then return false end
    Notify(ctx.src, L('wagonDeleted'))
    return true
end)

Rpc('wagonOut', { gap = 800 }, function(ctx, wagonId, netId)
    local w = OwnedWagon(ctx, wagonId)
    if not w or TransferBusy('wagon', w.id) then return false end
    local ent = EntFromNet(netId, 5000)
    w = OwnedWagon(ctx, wagonId)
    if not w or not ent or GetEntityType(ent) ~= 2 then return false end
    if GetEntityModel(ent) ~= joaat(w.model) or not EntNear(ctx.src, ent, 120.0) then return false end
    if EntWagon[ent] and EntWagon[ent] ~= w.id then return false end
    LinkWagon(w.id, ent, ctx.src)
    TagWagon(w, ent, ctx.src)
    if not w.isOut then w.isOut = true; SaveWagon(w, 'isOut') end
    return true
end)

function PutWagonAway(w, stableId)
    UnlinkWagon(w.id, true)
    w.isOut = false
    if stableId then w.stable = stableId end
    SaveWagon(w, 'isOut', 'stable')
end

Rpc('stableWagon', { gap = 800 }, function(ctx, netId, stableId)
    local s = atStable(ctx, stableId)
    if not s then return false end
    local ent = EntFromNet(netId, 1000)
    local w = WagonOfEnt(ent, ctx)
    if not w or w.charid ~= ctx.charid or w.identifier ~= ctx.identifier then return false, L('notYourWagon') end
    -- draft horses the server can prove are the player's go in with it
    local draft = ent and Entity(ent).state.pup_stable_wagon_draft or {}
    for _, hid in ipairs(type(draft) == 'table' and draft or {}) do
        local h = OwnedHorse(ctx, hid)
        if h and h.isOut then PutAway(h, s.id) end
    end
    PutWagonAway(w, s.id)
    return true
end)

-- a fled wagon is stabled at the stable nearest the player
Rpc('wagonFled', { gap = 800 }, function(ctx, wagonId)
    local w = OwnedWagon(ctx, wagonId)
    if not w then return false end
    local p = PedPos(ctx.src)
    local best, bestD = w.stable, math.huge
    if p then
        for id, s in pairs(Config.Stables) do
            local d = #(p - vector3(s.location.x, s.location.y, s.location.z))
            if d < bestD then best, bestD = id, d end
        end
    end
    PutWagonAway(w, best)
    return true
end)
