-- pup_mercantile | buying, selling, stocking and arranging through the store grid

------------------------------------------------------------------------------
-- shared checks
------------------------------------------------------------------------------

-- why this player cannot take qty of an item, or nil when they can
function CarryProblem(src, name, qty)
    local okd, def = pcall(function() return Inv:getItemDB(name) end)
    local limit = okd and type(def) == 'table' and tonumber(def.limit) or -1
    if limit and limit ~= -1 then
        local okc, have = pcall(function() return Inv:getItemCount(src, nil, name) end)
        have = okc and tonumber(have) or 0
        if have + qty > limit then return 'itemLimit' end
    end
    local oka, room = pcall(function() return Inv:canCarryAmount(src, name, qty) end)
    -- canCarryAmount is only in the patched vorp_inventory; without it canCarryItem below decides alone
    if oka and (tonumber(room) or 0) < qty then return 'cantCarry' end
    local okb, can = pcall(function() return Inv:canCarryItem(src, name, qty) end)
    if not okb or can ~= true then return 'cantCarry' end
    return nil
end

function CanCarryWeapon(src, name)
    local ok, v = pcall(function() return Inv:canCarryWeapons(src, 1, nil, name) end)
    return ok and v == true
end

-- the server's own copy of an inventory item, when it is what the client says
function ServerItem(src, invId, name)
    invId = tonumber(invId)
    if not invId then return nil end
    local ok, it = pcall(function() return Inv:getItemByMainId(src, invId) end)
    if not ok or type(it) ~= 'table' or it.name ~= name then return nil end
    it.count = tonumber(it.count) or 0
    if type(it.metadata) ~= 'table' then it.metadata = {} end
    return it
end

function Decayed(it)
    if not Config.Decay.enabled or not it then return false end
    if not it.isDegradable then return false end
    return (tonumber(it.percentage) or 100) < Config.Decay.minimum
end

local function removeItem(src, invId, qty)
    local ok, v = pcall(function() return Inv:subItemById(src, tonumber(invId), nil, nil, qty) end)
    return ok and v == true
end

local function addItem(src, name, qty, metadata)
    local ok, v = pcall(function() return Inv:addItem(src, name, qty, metadata or {}) end)
    return ok and v == true
end

-- refuses a loaded box or pack going into any store grid
local function packGate(src, it)
    if not Misc.isBox(it.name) then return true end
    if Misc.packIsEmpty(src, it.id) then return true end
    Notify(src, Util.L('packNotEmpty'))
    return false
end

-- hands a stocked weapon (serial, condition and all) to a player
function HandOverWeapon(src, serial, name)
    local char = GetChar(src)
    if not char then return false end
    local okw, w = pcall(function() return Inv:getUserWeapon(src, nil, serial) end)
    if okw and type(w) == 'table' then
        local okg, given = pcall(function() return Inv:giveWeapon(src, serial, 0) end)
        return okg and given == true
    end
    -- not in vorp_inventory's memory (a restart since it was stocked): move it in the database,
    -- so the same weapon arrives the next time the character loads
    local okx, exists = pcall(MySQL.scalar.await, 'SELECT id FROM loadout WHERE id = ?', { serial })
    if okx and exists then
        local oku, n = pcall(MySQL.update.await,
            "UPDATE loadout SET identifier = ?, charidentifier = ?, curr_inv = 'default' WHERE id = ?",
            { char.identifier, char.charIdentifier, serial })
        if oku and (tonumber(n) or 0) > 0 then
            Notify(src, Util.L('weaponDeferred'), 8000)
            return true
        end
        return false
    end
    -- the stored weapon is gone from the database entirely: nothing to orphan, give a fresh one
    local okc, created = pcall(function() return Inv:createWeapon(src, name, {}, nil, {}) end)
    return okc and created == true
end

local function creditShop(shop, amount)
    if shop.kind == 'player' then
        shop.ledger = Util.round2(shop.ledger + amount)
    else
        SocietyCredit(shop.society, amount, shop.name)
    end
end

------------------------------------------------------------------------------
-- NPC stores
------------------------------------------------------------------------------
local function npcBuy(src, store, char, data)
    local entry
    for _, e in ipairs(store.sell) do
        if e.name == data.item.name then entry = e break end
    end
    if not entry or entry.price <= 0 then return Notify(src, Util.L('notForSale')) end

    if entry.type == 'item_weapon' then
        if not CanCarryWeapon(src, entry.name) then return Notify(src, Util.L('cantCarryWeapon')) end
        if not TakeCash(src, entry.price) then return Notify(src, Util.L('noMoney', Util.fmt(entry.price))) end
        local ok, created = pcall(function() return Inv:createWeapon(src, entry.name, {}, nil, {}) end)
        if not ok or created ~= true then
            GiveCash(src, entry.price)
            return Notify(src, Util.L('cantCarryWeapon'))
        end
        Notify(src, Util.L('bought', WeaponLabel(entry.name), Util.fmt(entry.price)))
        Log({ title = Util.L('logBought'), colour = Colours.sale, src = src, staffOnly = true, fields = {
            { 'Store', store.name }, { 'Weapon', ItemField(WeaponLabel(entry.name), entry.name) },
            { 'Amount', 1 }, { 'Unit price', '$' .. Util.fmt(entry.price) } } })
        return
    end

    local qty = Util.whole(data.number, 1, 1000000)
    if not qty then return Notify(src, Util.L('badQuantity')) end
    local total = Util.round2(entry.price * qty)
    if Cash(src) < total then return Notify(src, Util.L('noMoney', Util.fmt(total))) end
    local why = CarryProblem(src, entry.name, qty)
    if why then return Notify(src, Util.L(why)) end
    if not TakeCash(src, total) then return Notify(src, Util.L('noMoney', Util.fmt(total))) end
    if not addItem(src, entry.name, qty, {}) then
        GiveCash(src, total)
        return Notify(src, Util.L('cantCarry'))
    end
    Notify(src, Util.L('bought', ('%s x%d'):format(entry.label, qty), Util.fmt(total)))
    Log({ title = Util.L('logBought'), colour = Colours.sale, src = src, staffOnly = true, fields = {
        { 'Store', store.name }, { 'Item', ItemField(entry.label, entry.name) },
        { 'Amount', qty }, { 'Unit price', '$' .. Util.fmt(entry.price) } } })
end

local function npcSell(src, store, char, data)
    if data.item.type == 'item_weapon' then return Notify(src, Util.L('noWeaponsBuy')) end
    local qty = Util.whole(data.number, 1, 1000000)
    if not qty then return Notify(src, Util.L('badQuantity')) end
    local entry
    for _, e in ipairs(store.buy) do
        if e.name == data.item.name then entry = e break end
    end
    local it = ServerItem(src, data.item.id, data.item.name)
    local label = (it and it.label) or ItemLabel(data.item.name)
    if not entry or entry.price <= 0 then return Notify(src, Util.L('notBuying', label)) end
    if Util.blacklisted(entry.name) then return Notify(src, Util.L('blacklisted')) end
    if not it or it.count < qty then return Notify(src, Util.L('badQuantity')) end
    if Decayed(it) then return Notify(src, Util.L('decayed', Config.Decay.minimum)) end
    if not packGate(src, it) then return end
    -- the pack check may have waited; read the item again before taking it
    it = ServerItem(src, data.item.id, data.item.name)
    if not it or it.count < qty then return Notify(src, Util.L('badQuantity')) end
    if not removeItem(src, it.id, qty) then return end
    local total = Util.round2(entry.price * qty)
    local bonus = Misc.ecoBonus(src, store.name, entry.name, qty, total)
    GiveCash(src, total + bonus)
    if bonus > 0 then
        Notify(src, Util.L('soldBonus', ('%s x%d'):format(label, qty), Util.fmt(total + bonus), Util.fmt(bonus)))
    else
        Notify(src, Util.L('sold', ('%s x%d'):format(label, qty), Util.fmt(total)))
    end
    local fields = {
        { 'Store', store.name }, { 'Item', ItemField(label, entry.name) },
        { 'Amount', qty }, { 'Unit price', '$' .. Util.fmt(entry.price) },
    }
    if bonus > 0 then fields[#fields + 1] = { 'Eco Boost', '$' .. Util.fmt(bonus) } end
    Log({ title = Util.L('logSoldNpc'), colour = Colours.sale, src = src, staffOnly = true, fields = fields })
end

------------------------------------------------------------------------------
-- player and society shops: customers
------------------------------------------------------------------------------
local function customerBuy(src, shop, char, data)
    local stock = shop.stock
    if data.item.type == 'item_weapon' then
        if shop.kind == 'player' then return Notify(src, Util.L('noWeaponsPlayer')) end
        local w, wi = FindWeapon(stock, data.item.id)
        if not w or w.name ~= data.item.name then return Notify(src, Util.L('notForSale')) end
        if not w.forsale then return Notify(src, Util.L('notForSale')) end
        if not CanCarryWeapon(src, w.name) then return Notify(src, Util.L('cantCarryWeapon')) end
        if not TakeCash(src, w.price) then return Notify(src, Util.L('noMoney', Util.fmt(w.price))) end
        table.remove(stock.weapons, wi)
        if not HandOverWeapon(src, w.id, w.name) then
            table.insert(stock.weapons, w)
            GiveCash(src, w.price)
            return Notify(src, Util.L('cantCarryWeapon'))
        end
        creditShop(shop, w.price)
        SaveShop(shop)
        Notify(src, Util.L('bought', WeaponLabel(w.name), Util.fmt(w.price)))
        Log({ title = Util.L('logBought'), colour = Colours.sale, src = src, shop = shop, fields = {
            { 'Weapon', ItemField(WeaponLabel(w.name), w.name) }, { 'Serial', w.id },
            { 'Amount', 1 }, { 'Unit price', '$' .. Util.fmt(w.price) }, { 'Remaining', 0 } } })
        return
    end

    local row = FindItemRow(stock, data.item.id)
    if not row or row.itemname ~= data.item.name then return Notify(src, Util.L('notForSale')) end
    if not row.forsale then return Notify(src, Util.L('notForSale')) end
    local qty = Util.whole(data.number, 1, row.itemcount)
    if not qty then return Notify(src, Util.L('badQuantity')) end
    local why = CarryProblem(src, row.itemname, qty)
    if why then return Notify(src, Util.L(why)) end
    local total = Util.round2(row.price * qty)
    if not TakeCash(src, total) then return Notify(src, Util.L('noMoney', Util.fmt(total))) end
    row.itemcount = row.itemcount - qty -- reserved while the item is handed over
    if not addItem(src, row.itemname, qty, Util.copy(row.metadata)) then
        row.itemcount = row.itemcount + qty
        GiveCash(src, total)
        return Notify(src, Util.L('cantCarry'))
    end
    creditShop(shop, total)
    local remaining = row.itemcount
    DropIfEmpty(stock, row)
    SaveShop(shop)
    Notify(src, Util.L('bought', ('%s x%d'):format(row.label, qty), Util.fmt(total)))
    Log({ title = Util.L('logBought'), colour = Colours.sale, src = src, shop = shop, fields = {
        { 'Item', ItemField(row.label, row.itemname) }, { 'Amount', qty },
        { 'Unit price', '$' .. Util.fmt(row.price) }, { 'Remaining', remaining } } })
end

local function customerSell(src, shop, char, data)
    local stock = shop.stock
    if data.item.type == 'item_weapon' then return Notify(src, Util.L('noWeaponsBuy')) end
    local name = data.item.name
    local it = ServerItem(src, data.item.id, name)
    local label = (it and it.label) or ItemLabel(name)
    local b = FindBuy(stock, name)
    if not b or b.price <= 0 then return Notify(src, Util.L('notBuying', label)) end
    if Util.blacklisted(name) then return Notify(src, Util.L('blacklisted')) end
    local qty = Util.whole(data.number, 1, 1000000)
    if not qty then return Notify(src, Util.L('badQuantity')) end
    if qty > b.amount then return Notify(src, Util.L('onlyBuying', b.amount)) end
    if not it or it.count < qty then return Notify(src, Util.L('badQuantity')) end
    if Decayed(it) then return Notify(src, Util.L('decayed', Config.Decay.minimum)) end
    if not packGate(src, it) then return end
    if FreeSlots(stock) < qty then return Notify(src, Util.L('slotsFull', stock.slots)) end
    local total = Util.round2(b.price * qty)

    if shop.kind == 'player' then
        if shop.ledger < total then return Notify(src, Util.L('shopBroke')) end
        it = ServerItem(src, data.item.id, name)
        if not it or it.count < qty then return Notify(src, Util.L('badQuantity')) end
        shop.ledger = Util.round2(shop.ledger - total)
        if not removeItem(src, it.id, qty) then
            shop.ledger = Util.round2(shop.ledger + total)
            return
        end
    else
        if not SocietyDebit(shop.society, total) then return Notify(src, Util.L('shopBroke')) end
        it = ServerItem(src, data.item.id, name)
        if not it or it.count < qty or not removeItem(src, it.id, qty) then
            SocietyCredit(shop.society, total)
            return Notify(src, Util.L('badQuantity'))
        end
    end
    GiveCash(src, total)
    local row = ShelveIncoming(stock, name, qty, it.metadata, label, b.price)
    ReduceBuyOrder(stock, name, qty)
    SaveShop(shop)
    Notify(src, Util.L('sold', ('%s x%d'):format(label, qty), Util.fmt(total)))
    Log({ title = Util.L('logSoldShop'), colour = Colours.sale, src = src, shop = shop, fields = {
        { 'Item', ItemField(label, name) }, { 'Amount', qty },
        { 'Unit price', '$' .. Util.fmt(b.price) }, { 'Shelved count', row.itemcount } } })
end

------------------------------------------------------------------------------
-- player and society shops: owners and managers
-- (staff = true: a vorp_admin viewer using the owner's controls; staff-only log)
------------------------------------------------------------------------------
local function logTitle(key, staff)
    if staff then return Util.L('logAdmin', Util.L(key)) end
    return Util.L(key)
end

local function ownerDeposit(src, shop, char, data, staff)
    local stock = shop.stock
    local price = Util.money(data.price)
    if data.item.type == 'item_weapon' then
        if shop.kind == 'player' then return Notify(src, Util.L('noWeaponsPlayer')) end
        if not price then return Notify(src, Util.L('badAmount')) end
        local serial = tonumber(data.item.id)
        local okw, list = pcall(function() return Inv:getUserInventoryWeapons(src) end)
        local mine
        for _, w in ipairs(okw and type(list) == 'table' and list or {}) do
            if tonumber(w.id) == serial then mine = w break end
        end
        if not mine then return Notify(src, Util.L('badQuantity')) end
        if FreeSlots(stock) < 1 then return Notify(src, Util.L('slotsFull', stock.slots)) end
        local okr, removed = pcall(function() return Inv:subWeapon(src, serial) end)
        if not okr or removed ~= true then return end
        stock.weapons[#stock.weapons + 1] = {
            name = tostring(mine.name):upper(), price = price, id = serial,
            sortingnumber = NextSortNumber(stock), forsale = true,
        }
        SaveShop(shop)
        Notify(src, Util.L('stocked', WeaponLabel(mine.name), Util.fmt(price)))
        Log({ title = logTitle('logStockAdded', staff), colour = Colours.stock, src = src, shop = shop, staffOnly = staff, fields = {
            { 'Weapon', ItemField(WeaponLabel(mine.name), mine.name) }, { 'Serial', serial }, { 'Price', '$' .. Util.fmt(price) } } })
        return
    end

    local name = data.item.name
    local qty = Util.whole(data.number, 1, 1000000)
    if not qty then return Notify(src, Util.L('badQuantity')) end
    if Util.blacklisted(name) then return Notify(src, Util.L('blacklisted')) end
    if not price then return Notify(src, Util.L('badAmount')) end
    local it = ServerItem(src, data.item.id, name)
    if not it or it.count < qty then return Notify(src, Util.L('badQuantity')) end
    if Decayed(it) then return Notify(src, Util.L('decayed', Config.Decay.minimum)) end
    if not packGate(src, it) then return end
    if FreeSlots(stock) < qty then return Notify(src, Util.L('slotsFull', stock.slots)) end
    it = ServerItem(src, data.item.id, name)
    if not it or it.count < qty or not removeItem(src, it.id, qty) then return Notify(src, Util.L('badQuantity')) end
    local row = FindIdentityRow(stock, name, it.metadata)
    if row then
        row.itemcount = row.itemcount + qty
        row.price = price
    else
        row = NewItemRow(stock, name, qty, price, it.metadata, it.label or ItemLabel(name), true)
    end
    SaveShop(shop)
    Notify(src, Util.L('stocked', ('%s x%d'):format(row.label, qty), Util.fmt(price)))
    Log({ title = logTitle('logStockAdded', staff), colour = Colours.stock, src = src, shop = shop, staffOnly = staff, fields = {
        { 'Item', ItemField(row.label, name) }, { 'Price', '$' .. Util.fmt(price) }, { 'New count', row.itemcount } } })
end

local function ownerWithdraw(src, shop, char, data, staff)
    local stock = shop.stock
    if data.item.type == 'item_weapon' then
        local w, wi = FindWeapon(stock, data.item.id)
        if not w then return Notify(src, Util.L('badQuantity')) end
        if not CanCarryWeapon(src, w.name) then return Notify(src, Util.L('cantCarryWeapon')) end
        table.remove(stock.weapons, wi)
        if not HandOverWeapon(src, w.id, w.name) then
            table.insert(stock.weapons, w)
            return Notify(src, Util.L('cantCarryWeapon'))
        end
        SaveShop(shop)
        Notify(src, Util.L('withdrewItem', WeaponLabel(w.name)))
        Log({ title = logTitle('logWithdraw', staff), colour = Colours.stock, src = src, shop = shop, staffOnly = staff, fields = {
            { 'Weapon', ItemField(WeaponLabel(w.name), w.name) }, { 'Serial', w.id } } })
        return
    end
    local row = FindItemRow(stock, data.item.id)
    if not row or row.itemname ~= data.item.name then return Notify(src, Util.L('badQuantity')) end
    local qty = Util.whole(data.number, 1, row.itemcount)
    if not qty then return Notify(src, Util.L('badQuantity')) end
    local why = CarryProblem(src, row.itemname, qty)
    if why then return Notify(src, Util.L(why)) end
    row.itemcount = row.itemcount - qty
    if not addItem(src, row.itemname, qty, Util.copy(row.metadata)) then
        row.itemcount = row.itemcount + qty
        return Notify(src, Util.L('cantCarry'))
    end
    local remaining = row.itemcount
    DropIfEmpty(stock, row)
    SaveShop(shop)
    Notify(src, Util.L('withdrewItem', ('%s x%d'):format(row.label, qty)))
    Log({ title = logTitle('logWithdraw', staff), colour = Colours.stock, src = src, shop = shop, staffOnly = staff, fields = {
        { 'Item', ItemField(row.label, row.itemname) }, { 'Amount', qty }, { 'Remaining', remaining } } })
end

------------------------------------------------------------------------------
-- the grid's transfer events
------------------------------------------------------------------------------
local function decodePayload(p)
    if type(p) == 'string' then
        local ok, d = pcall(json.decode, p)
        p = ok and d or nil
    end
    if type(p) ~= 'table' or type(p.item) ~= 'table' or type(p.item.name) ~= 'string' then return nil end
    p.item.type = p.item.type == 'item_weapon' and 'item_weapon' or 'item_standard'
    return p
end

local function transfer(src, payload, dir)
    local data = decodePayload(payload)
    if not data or not GetChar(src) then return PushGrid(src, true) end
    if not RateOk(src) then return PushGrid(src) end

    local ok, err = pcall(function()
        local vw = Viewers[src]
        if vw and vw.admin then
            -- staff from vorp_admin: the owner's moves, no visit and no distance
            local shop = AdminViewShop(src)
            if not shop then return end
            WithLock(src, shop, function()
                if Viewers[src] ~= vw or GetShop(vw.kind, vw.id) ~= shop then return end
                local char = GetChar(src)
                if not char then return end
                if dir == 'move' then ownerDeposit(src, shop, char, data, true) else ownerWithdraw(src, shop, char, data, true) end
            end)
            ScheduleRefresh(shop)
            return
        end
        if vw and vw.kind ~= 'npc' then
            if not ShopsReady then return end
            local visit, shop, char, manage = LiveVisit(src)
            if not visit or visit.kind ~= vw.kind or visit.id ~= vw.id then return end
            WithLock(src, shop, function()
                if not ShopLive(shop) then return end
                char = GetChar(src)
                manage = CanManage(char, shop)
                if dir == 'move' then
                    if manage then ownerDeposit(src, shop, char, data) else customerSell(src, shop, char, data) end
                else
                    if manage then ownerWithdraw(src, shop, char, data) else customerBuy(src, shop, char, data) end
                end
            end)
            ScheduleRefresh(shop)
            return
        end
        local store, char = NpcCheck(src, (vw and vw.id) or data.store)
        if not store then return end
        if dir == 'move' then npcSell(src, store, char, data) else npcBuy(src, store, char, data) end
    end)
    if not ok then print('^1[pup_mercantile]^7 transfer failed: ' .. tostring(err)) end
    PushGrid(src)
end

RegisterNetEvent('pup_mercantile:MoveToStore', function(payload)
    transfer(source, payload, 'move')
end)

RegisterNetEvent('pup_mercantile:TakeFromStore', function(payload)
    transfer(source, payload, 'take')
end)

------------------------------------------------------------------------------
-- owner tools inside the grid: arrange, sale state, price
------------------------------------------------------------------------------
-- the shop whose owner tools this player may use now; staff is true for a vorp_admin viewer
local function ownerShop(src)
    local vw = Viewers[src]
    if not vw or vw.kind == 'npc' or not ShopsReady then return nil end
    if vw.admin then
        local shop = AdminViewShop(src)
        if not shop then return nil end
        return shop, GetChar(src), true
    end
    local visit, shop, char = LiveVisit(src, true)
    if not visit or visit.kind ~= vw.kind or visit.id ~= vw.id then return nil end
    return shop, char, false
end

local function findRow(stock, id, rtype)
    if rtype == 'item_weapon' then
        local w = FindWeapon(stock, id)
        return w, w and WeaponLabel(w.name)
    end
    local r = FindItemRow(stock, id)
    return r, r and r.label
end

RegisterNetEvent('pup_mercantile:changeorder', function(payload)
    local src = source
    if not RateOk(src) then return PushGrid(src) end
    if type(payload) ~= 'table' then return PushGrid(src, true) end -- malformed: empty list
    local shop = ownerShop(src)
    if not shop then return PushGrid(src) end
    local list = payload.inventoryItems or payload.items or payload.order or payload.list
    if type(list) ~= 'table' and payload[1] then list = payload end
    if type(list) ~= 'table' then return PushGrid(src, true) end
    local matched = 0
    for i, e in ipairs(list) do
        if type(e) == 'table' then
            local rtype = e.t or e.type
            local row = findRow(shop.stock, e.id, rtype == 'item_weapon' and 'item_weapon' or 'item_standard')
            if row then
                row.sortingnumber = i - 1
                matched = matched + 1
            end
        end
    end
    if matched > 0 then
        SaveShop(shop)
        ScheduleRefresh(shop)
    end
    PushGrid(src)
end)

RegisterNetEvent('pup_mercantile:togglesale', function(id, rtype)
    local src = source
    if not RateOk(src) then return PushGrid(src) end
    local shop, _, staff = ownerShop(src)
    if not shop then return PushGrid(src) end
    local row, label = findRow(shop.stock, id, rtype == 'item_weapon' and 'item_weapon' or 'item_standard')
    if row then
        row.forsale = not row.forsale
        SaveShop(shop)
        Notify(src, Util.L(row.forsale and 'backOnSale' or 'offSale', label))
        Log({ title = logTitle('logSaleState', staff), colour = Colours.stock, src = src, shop = shop, staffOnly = staff, fields = {
            { 'Item', ItemField(label, row.itemname or row.name) }, { 'On sale', tostring(row.forsale) } } })
        ScheduleRefresh(shop)
    end
    PushGrid(src)
end)

RegisterNetEvent('pup_mercantile:setprice', function(id, rtype, price)
    local src = source
    if not RateOk(src) then return PushGrid(src) end
    local shop, _, staff = ownerShop(src)
    if not shop then return PushGrid(src) end
    local new = Util.money(price)
    local row, label = findRow(shop.stock, id, rtype == 'item_weapon' and 'item_weapon' or 'item_standard')
    if row and not new then Notify(src, Util.L('badAmount')) end
    if row and new and new ~= row.price then
        local old = row.price
        row.price = new
        SaveShop(shop)
        Notify(src, Util.L('priceSet', Util.fmt(new), label))
        Log({ title = logTitle('logPrice', staff), colour = Colours.stock, src = src, shop = shop, staffOnly = staff, fields = {
            { 'Item', ItemField(label, row.itemname or row.name) }, { 'Old price', '$' .. Util.fmt(old) }, { 'New price', '$' .. Util.fmt(new) } } })
        ScheduleRefresh(shop)
    end
    PushGrid(src)
end)
