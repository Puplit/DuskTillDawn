-- pup_mercantile | box trade from the grid, and stocking from a container (pup-misc boxes)

local function maxDegradation(name)
    local ok, def = pcall(function() return Inv:getItemDB(name) end)
    if not ok or type(def) ~= 'table' then return 0 end
    return tonumber(def.maxDegradation or def.degradation) or 0
end

local function boxStackDecayed(row)
    if not Config.Decay.enabled then return false end
    if maxDegradation(row.name) <= 0 then return false end
    local p = tonumber(row.percentage or (type(row.metadata) == 'table' and row.metadata.percentage))
    return p ~= nil and p < Config.Decay.minimum
end

-- the venue for a box trade: the live visit (within reach), else the NPC store hint
local function boxVenue(src, storeHint)
    -- a staff viewer from vorp_admin is nowhere near the counter: no box trade
    if Viewers[src] and Viewers[src].admin then return nil end
    if Visits[src] then
        local visit, shop, char, manage = LiveVisit(src)
        if not visit then return nil end
        if shop.kind == 'society' and not Config.SocietyShops.enabled then return nil end
        local pos = PlayerPos(src)
        if pos and Util.dist(pos, shop.coords) > Config.Shops.boxReach then return nil end
        return { shop = shop, char = char, manage = manage }
    end
    local store, char = NpcCheck(src, storeHint)
    if not store then return nil end
    return { store = store, char = char }
end

local function npcBuyEntry(store, name)
    for _, e in ipairs(store.buy) do
        if e.name == name then return e end
    end
    return nil
end

local function npcSellEntry(store, name)
    for _, e in ipairs(store.sell) do
        if e.name == name then return e end
    end
    return nil
end

------------------------------------------------------------------------------
-- sell the contents of a box
------------------------------------------------------------------------------
local function sellBox(src, venue, boxItemId, contents, lease)
    local shop, store = venue.shop, venue.store
    local stock = shop and shop.stock
    local funds = math.huge
    if shop and shop.kind == 'player' then funds = shop.ledger end
    if shop and shop.kind == 'society' then funds = SocietyFunds(shop.society) end
    local free = stock and FreeSlots(stock) or math.huge

    local lines, wantLeft, stopped = {}, {}, nil
    for _, row in ipairs(contents) do
        if type(row) == 'table' and type(row.name) == 'string' then
            local count = math.floor(tonumber(row.count or row.amount) or 0)
            local entry = stock and FindBuy(stock, row.name) or (store and npcBuyEntry(store, row.name))
            local isWeapon = row.type == 'item_weapon' or IsWeaponName(row.name)
            if count > 0 and not isWeapon and entry and entry.price > 0
                and not Util.blacklisted(row.name) and not boxStackDecayed(row) then
                local take = count
                if stock then
                    local left = wantLeft[row.name] or entry.amount
                    if left < take then stopped = stopped or 'boxStopWanted' take = math.max(0, left) end
                    if free < take then stopped = stopped or 'boxStopSlots' take = free end
                end
                local affordable = math.floor((funds + 0.0001) / entry.price)
                if affordable < take then stopped = stopped or 'boxStopFunds' take = affordable end
                if take > 0 then
                    lines[#lines + 1] = {
                        craftedId = row.craftedId,
                        name = row.name, label = tostring(row.label or ItemLabel(row.name)),
                        metadata = type(row.metadata) == 'table' and row.metadata or {},
                        qty = take, price = entry.price,
                    }
                    if stock then
                        wantLeft[row.name] = (wantLeft[row.name] or entry.amount) - take
                        free = free - take
                    end
                    funds = funds - Util.round2(take * entry.price)
                end
            end
        end
    end
    if #lines == 0 then
        return Notify(src, Util.L(stopped or 'boxNothing'))
    end

    local total = 0
    for _, l in ipairs(lines) do total = Util.round2(total + l.qty * l.price) end

    -- the venue pays up front
    if shop and shop.kind == 'player' then
        if shop.ledger < total then return Notify(src, Util.L('shopBroke')) end
        shop.ledger = Util.round2(shop.ledger - total)
    elseif shop then
        if not SocietyDebit(shop.society, total) then return Notify(src, Util.L('shopBroke')) end
    end

    local paid, units, bonus, sold = 0, 0, 0, {}
    for _, l in ipairs(lines) do
        local lineTotal = Util.round2(l.qty * l.price)
        -- a lost lease (pup-misc stopped or the seller left while a take waited) starts no
        -- further take; a take that did answer is still shelved and paid below
        local live = not lease or LeaseLive(lease)
        if live and Misc.boxTake(src, boxItemId, l.craftedId, l.qty, lease) then
            paid = Util.round2(paid + lineTotal)
            units = units + l.qty
            local newCount
            if stock then
                local row = ShelveIncoming(stock, l.name, l.qty, l.metadata, l.label, l.price)
                ReduceBuyOrder(stock, l.name, l.qty)
                newCount = row.itemcount
            else
                bonus = Util.round2(bonus + Misc.ecoBonus(src, store.name, l.name, l.qty, lineTotal))
            end
            sold[#sold + 1] = { line = l, count = newCount }
        elseif shop and shop.kind == 'player' then
            shop.ledger = Util.round2(shop.ledger + lineTotal)
        elseif shop then
            SocietyCredit(shop.society, lineTotal)
        end
    end
    if shop then SaveShop(shop) ScheduleRefresh(shop) end
    if paid <= 0 then return Notify(src, Util.L('boxRefused')) end

    GiveCash(src, paid + bonus)
    Notify(src, Util.L('boxSold', Util.fmt(paid + bonus)))
    local consumed = Misc.boxConsume(src, boxItemId)
    if consumed then Notify(src, Util.L('boxConsumed')) end

    local fields = {
        { 'Lines sold', #sold }, { 'Units sold', units }, { 'Total paid', '$' .. Util.fmt(paid + bonus) },
        { 'Eco Boost', '$' .. Util.fmt(bonus) }, { 'Stopped early', stopped and Util.L(stopped) or 'no' },
        { 'Container consumed', tostring(consumed) },
    }
    if store then table.insert(fields, 1, { 'Store', store.name }) end
    for i, s in ipairs(sold) do
        if i > 12 then
            fields[#fields + 1] = { '...', Util.L('logAndMore', #sold - 12) }
            break
        end
        local value = ItemField(s.line.label, s.line.name)
        if s.count then value = value .. '\nnew count ' .. s.count end
        fields[#fields + 1] = { ('x%d @ $%s'):format(s.line.qty, Util.fmt(s.line.price)), value }
    end
    Log({ title = Util.L('logBoxSell'), colour = Colours.sale, src = src, shop = shop, staffOnly = store ~= nil, fields = fields })
end

RegisterNetEvent('pup_mercantile:box:gridSell', function(storeHint, boxItemId)
    local src = source
    if not GetChar(src) then return PushGrid(src, true) end
    if not RateOk(src) then return PushGrid(src) end
    local ok, err = pcall(function()
        local venue = boxVenue(src, storeHint)
        if not venue then return end
        if not Misc.boxItem(src, boxItemId) then return Notify(src, Util.L('boxEmpty')) end
        local contents = Misc.boxContents(src, boxItemId)
        if type(contents) ~= 'table' or not next(contents) then return Notify(src, Util.L('boxEmpty')) end
        if venue.shop then
            WithLock(src, venue.shop, function(lease)
                if not ShopLive(venue.shop) then return end
                -- read again under the lock: another trade may have changed the box
                local fresh = Misc.boxContents(src, boxItemId)
                if type(fresh) ~= 'table' or not next(fresh) then return Notify(src, Util.L('boxEmpty')) end
                sellBox(src, venue, boxItemId, fresh, lease)
            end)
        else
            sellBox(src, venue, boxItemId, contents, nil)
        end
    end)
    if not ok then print('^1[pup_mercantile]^7 box sale failed: ' .. tostring(err)) end
    PushGrid(src)
end)

------------------------------------------------------------------------------
-- buy straight into a box
------------------------------------------------------------------------------
local function buyIntoBoxNpc(src, store, boxItemId, rowName, qty)
    local e = npcSellEntry(store, rowName)
    if not e or e.type == 'item_weapon' or e.price <= 0 then return Notify(src, Util.L('notForSale')) end
    local free = Misc.boxFree(src, boxItemId)
    if free <= 0 then return Notify(src, Util.L('boxFull')) end
    qty = math.min(qty, free)
    local total = Util.round2(e.price * qty)
    if not TakeCash(src, total) then return Notify(src, Util.L('noMoney', Util.fmt(total))) end
    local landed = Misc.boxPut(src, boxItemId, e.name, qty, {}, nil)
    if landed < qty then GiveCash(src, Util.round2((qty - landed) * e.price)) end
    if landed <= 0 then return Notify(src, Util.L('boxRefused')) end
    local paid = Util.round2(landed * e.price)
    Notify(src, Util.L('boxBought', Util.fmt(paid)))
    Log({ title = Util.L('logBoxBuy'), colour = Colours.sale, src = src, staffOnly = true, fields = {
        { 'Store', store.name }, { 'Item', ItemField(e.label, e.name) }, { 'Amount', landed },
        { 'Unit price', '$' .. Util.fmt(e.price) } } })
end

local function buyIntoBoxShop(src, shop, boxItemId, rowId, rowName, qty, lease)
    local stock = shop.stock
    local char = GetChar(src)
    local manage = CanManage(char, shop)
    local row = FindItemRow(stock, rowId)
    if not row or row.itemname ~= rowName then return Notify(src, Util.L('notForSale')) end
    if not row.forsale and not manage then return Notify(src, Util.L('notForSale')) end
    if qty > row.itemcount then return Notify(src, Util.L('badQuantity')) end
    local free = Misc.boxFree(src, boxItemId)
    if free <= 0 then return Notify(src, Util.L('boxFull')) end
    qty = math.min(qty, free)
    if qty > row.itemcount then return Notify(src, Util.L('badQuantity')) end
    local unit = manage and 0 or row.price
    local total = Util.round2(unit * qty)
    -- paid and taken off the shelf before pup-misc is asked, so an answer that comes
    -- after the lock was released (see LeaseWait) can never hand over unpaid goods
    if not TakeCash(src, total) then return Notify(src, Util.L('noMoney', Util.fmt(total))) end
    row.itemcount = row.itemcount - qty
    local landed = Misc.boxPut(src, boxItemId, row.itemname, qty, Util.copy(row.metadata), lease)
    if landed < qty then
        if FindItemRow(stock, row.uid) == row then
            row.itemcount = row.itemcount + (qty - landed)
        else
            -- the lock was lost while waiting and another trade removed the emptied row
            ShelveIncoming(stock, row.itemname, qty - landed, row.metadata, row.label, row.price)
        end
        GiveCash(src, Util.round2((qty - landed) * unit))
    end
    if landed <= 0 then return Notify(src, Util.L('boxRefused')) end
    local paid = Util.round2(landed * unit)
    if paid > 0 then
        if shop.kind == 'player' then shop.ledger = Util.round2(shop.ledger + paid)
        else SocietyCredit(shop.society, paid, shop.name) end
    end
    local remaining = row.itemcount
    DropIfEmpty(stock, row)
    SaveShop(shop)
    if manage then Notify(src, Util.L('boxMoved', landed)) else Notify(src, Util.L('boxBought', Util.fmt(paid))) end
    Log({ title = Util.L('logBoxBuy'), colour = Colours.sale, src = src, shop = shop, fields = {
        { 'Item', ItemField(row.label, row.itemname) }, { 'Amount', landed },
        { 'Unit price', manage and Util.L('logOwnerMove') or ('$' .. Util.fmt(unit)) }, { 'Remaining', remaining } } })
end

RegisterNetEvent('pup_mercantile:box:gridBuy', function(storeHint, boxItemId, rowId, rowName, amount)
    local src = source
    if not GetChar(src) then return PushGrid(src, true) end
    if not RateOk(src) then return PushGrid(src) end
    local ok, err = pcall(function()
        local qty = Util.whole(amount, 1, 1000000)
        if not qty then return Notify(src, Util.L('badQuantity')) end
        if type(rowName) ~= 'string' then return end
        local venue = boxVenue(src, storeHint)
        if not venue then return end
        -- a never-opened box has no box id yet; pup-misc stamps it when goods go in
        if not Misc.boxItem(src, boxItemId) then return Notify(src, Util.L('boxRefused')) end
        if venue.store then return buyIntoBoxNpc(src, venue.store, boxItemId, rowName, qty) end
        WithLock(src, venue.shop, function(lease)
            if not ShopLive(venue.shop) then return end
            buyIntoBoxShop(src, venue.shop, boxItemId, rowId, rowName, qty, lease)
        end)
        ScheduleRefresh(venue.shop)
    end)
    if not ok then print('^1[pup_mercantile]^7 box purchase failed: ' .. tostring(err)) end
    PushGrid(src)
end)

------------------------------------------------------------------------------
-- export: an owner tipped a box onto their own shelves (called by pup-misc)
------------------------------------------------------------------------------
exports('StockFromContainer', function(src, rows)
    src = tonumber(src)
    if not src or not GetChar(src) then return { ok = false, reason = 'nochar' } end
    if not ShopsReady or not Visits[src] then return { ok = false, reason = 'noshop' } end
    local visit, shop, _, manage = LiveVisit(src)
    if not visit then return { ok = false, reason = 'noshop' } end
    if not manage then return { ok = false, reason = 'notowner' } end

    local stacks, units = {}, 0
    for _, r in ipairs(type(rows) == 'table' and rows or {}) do
        if type(r) == 'table' and type(r.name) == 'string' then
            local n = math.floor(tonumber(r.amount or r.count) or 0)
            if n > 0 then
                if r.type == 'item_weapon' or IsWeaponName(r.name) then
                    Notify(src, Util.L('stockWeapon'))
                    return { ok = false, reason = 'weapon' }
                end
                if Util.blacklisted(r.name) then
                    Notify(src, Util.L('stockBlacklisted', tostring(r.label or ItemLabel(r.name))))
                    return { ok = false, reason = 'blacklisted' }
                end
                stacks[#stacks + 1] = { name = r.name, n = n, meta = type(r.metadata) == 'table' and r.metadata or {},
                    label = tostring(r.label or ItemLabel(r.name)) }
                units = units + n
            end
        end
    end
    if #stacks == 0 then
        Notify(src, Util.L('stockNothing'))
        return { ok = false, reason = 'empty' }
    end
    local stock = shop.stock
    -- a purchase or sale on this pool may be mid-way (waiting on another resource);
    -- stocking now could overfill the capacity it already checked, so wait for it
    local lease = TryLock(shop, src)
    if not lease then
        Notify(src, Util.L('busy'))
        return { ok = false, reason = 'noshop' }
    end
    Unlock(lease) -- nothing below waits, so knowing no transaction is in flight is enough
    if units > FreeSlots(stock) then
        Notify(src, Util.L('slotsFull', stock.slots))
        return { ok = false, reason = 'full' }
    end

    local merged, shelved, lines = 0, 0, {}
    for _, s in ipairs(stacks) do
        local row = FindIdentityRow(stock, s.name, s.meta)
        if row then
            row.itemcount = row.itemcount + s.n
            merged = merged + 1
            lines[#lines + 1] = Util.L('logRestocked', s.label, s.n, Util.fmt(row.price))
        else
            NewItemRow(stock, s.name, s.n, 0, s.meta, s.label, false)
            shelved = shelved + 1
            lines[#lines + 1] = Util.L('logShelved', s.label, s.n)
        end
    end
    SaveShop(shop)
    local msg = Util.L('stockDone', #stacks)
    if shelved > 0 then msg = msg .. Util.L('stockNeedPrice', shelved) end
    Notify(src, msg, 6000)
    Log({ title = Util.L('logContainer'), colour = Colours.stock, src = src, shop = shop, fields = {
        { 'Stacks', table.concat(lines, '\n') }, { 'Restocked', merged }, { 'Shelved', shelved } } })
    ScheduleRefresh(shop)
    return { ok = true, merged = merged, shelved = shelved, moved = units }
end)
