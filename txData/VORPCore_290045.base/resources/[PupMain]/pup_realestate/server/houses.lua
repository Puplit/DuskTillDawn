-- pup_realestate | houses: ownership, buying, selling, ledgers, keys, spots, doors, viewing, creating, deleting

-- character ids that can get in right now
function S.accessSet(h)
    local set = {}
    if h.owned and (h.buyerChar or 0) > 0 then set[h.buyerChar] = true end
    if h.owned then
        for _, k in ipairs(h.keys) do
            local cid = tonumber(k.charidentifier or k.charid)
            if cid then set[cid] = true end
        end
    end
    return set
end

-- put an occupant back in the world (their client runs the leave sequence; the server
-- makes sure of the bucket if the client never answers)
function S.forceLeave(src, rowId, msg)
    TriggerClientEvent('pup_realestate:cl_forceLeave', src, rowId)
    if msg then Tip(src, msg) end
    SetTimeout(15000, function()
        if S.insideRow(src, rowId) then
            SetPlayerRoutingBucket(tostring(src), 0)
            if S.clearInside then S.clearInside(src) end
        end
    end)
end

-- after keys or ownership changed: anyone who lost access loses their menu, stash and,
-- in a teleporter house, their place inside
function S.afterAccessChange(h, before, ownerChanged)
    local after = S.accessSet(h)
    for charid in pairs(before or {}) do
        if not after[charid] then
            local src = S.sourceOf(charid)
            if src then
                if S.lockHolder(h.id) == src then
                    S.locks[h.id] = nil
                    TriggerClientEvent('pup_realestate:cl_closeMenus', src, h.id)
                end
                S.closeStashOf(src, h.id)
            end
        end
    end
    local occ = S.occupants[h.id]
    if occ then
        for src in pairs(occ) do
            local ch = S.char(src)
            local lost = not ch or (before and before[ch.charid] and not after[ch.charid])
            local guest = ch and not after[ch.charid] and not (before and before[ch.charid])
            if lost or (ownerChanged and guest) or not h.owned then
                S.forceLeave(src, h.id)
            end
        end
    end
    if ownerChanged then
        for src, pass in pairs(S.passes) do
            if pass.house == h.id then S.passes[src] = nil end
        end
        S.knocks[h.id] = nil
    end
end

-- shared by a door purchase and an auction win
function S.completeSale(h, buyer, price)
    if not h.repo then
        local share = math.floor(price * (tonumber(Config.Sale.sellerShare) or 0))
        if share > 0 and (h.sellerChar or 0) > 0 then
            MySQL.insert('INSERT INTO playerhousing_sold_home_ledger (id, identifier, charidentifier, amount) VALUES (?, ?, ?, ?)',
                { h.id, h.sellerIdent or '', h.sellerChar, share })
        end
        local soc = math.floor(price * (tonumber(Config.Sale.societyShare) or 0))
        if Config.Sale.society and soc > 0 then
            if GetResourceState('pup_business') == 'started' then
                local ok, res, why = pcall(function()
                    return exports.pup_business:AddToLedger(Config.Sale.societyJob, soc, 'House sale', 'Housing')
                end)
                if not ok or res == false then
                    Warn('pup_business refused the house sale share for house %s: %s', h.id, tostring(ok and why or res))
                end
            else
                Warn('pup_business is not started; the society share of house %s was not paid', h.id)
            end
        end
    end
    local before = S.accessSet(h)
    h.owned = true
    h.buyerChar = buyer.charid
    h.buyerIdent = buyer.ident ~= '' and buyer.ident or '0'
    h.keys = {}
    h.repo = false
    S.viewing[h.id] = nil
    S.save(h, 'owned', 'buyerChar', 'buyer', 'keys', 'repo')
    S.bridgeSync(h)
    S.sendHouse(h)
    S.afterAccessChange(h, before, true)
end

-- clear the owner (sell, seize, repossess)
function S.clearOwner(h, opts)
    opts = opts or {}
    local before = S.accessSet(h)
    h.owned = false
    h.buyerChar = 0
    h.buyerIdent = '0'
    h.keys = {}
    h.repo = opts.repo == true
    S.save(h, 'owned', 'buyerChar', 'buyer', 'keys', 'repo')
    S.bridgeSync(h)
    S.afterAccessChange(h, before, true)
end

Net('sv_buy', 1500, function(src, ch, id)
    local h = S.house(id)
    if not h or h.owned then return end
    if S.auctioned[h.id] then return Tip(src, Locale.house_auctioned) end
    if S.ownedCount(ch.charid) >= Config.MaxHousesPerCharacter then
        return Tip(src, T('house_cap', Config.MaxHousesPerCharacter))
    end
    local price = math.floor(tonumber(h.price) or 0)
    if price <= 0 then return end
    if not S.takeCash(ch, price) then return Tip(src, Locale.cant_afford_house) end
    S.completeSale(h, { charid = ch.charid, ident = ch.ident, name = ch.name }, price)
    Tip(src, Locale.bought)
    Activity(h.id, 'BUY', ('$%s'):format(price), S.actor(ch))
    AdminLog(('%s (%s) bought a house id: %s for $%s'):format(ch.name, ch.ident, h.id, price))
end)

-- viewing (works without the doorlocks bridge)
local viewToken = {}

Net('sv_view', 2000, function(src, _, id)
    local h = S.house(id)
    if not h or h.owned then return end
    if Config.Doorlocks.enabled and h.kind == KIND_REAL then
        S.viewing[h.id] = Now() + Config.Timers.viewing
        S.bridgeSync(h)
        Tip(src, Locale.view_open)
    elseif h.kind == KIND_REAL then
        S.viewing[h.id] = Now() + Config.Timers.viewing
        S.sendHouse(h)
        Tip(src, Locale.view_open)
    elseif h.kind == KIND_TELE and U.interior(h) then
        S.passes[src] = { house = h.id, expires = Now() + Config.Timers.viewing, viewing = true }
        TriggerClientEvent('pup_realestate:cl_letIn', src, h.id)
        Tip(src, Locale.view_open)
        SetTimeout(Config.Timers.viewing * 1000, function()
            local ch = S.char(src)
            if S.insideRow(src, h.id) and not (ch and S.houses[h.id] and S.hasAccess(S.houses[h.id], ch.charid)) then
                S.forceLeave(src, h.id, Locale.view_over)
            end
        end)
        return
    else
        return Tip(src, Locale.view_none)
    end
    local token = (viewToken[h.id] or 0) + 1
    viewToken[h.id] = token
    SetTimeout(Config.Timers.viewing * 1000, function()
        if viewToken[h.id] ~= token then return end -- a newer viewing restarted the clock
        viewToken[h.id] = nil
        S.viewing[h.id] = nil
        local cur = S.houses[h.id]
        if not cur or cur.owned then return end
        if Config.Doorlocks.enabled then S.bridgeSync(cur) else S.sendHouse(cur) end
    end)
end)

Net('sv_sell', 3000, function(src, ch, id)
    local h = S.house(id)
    if not h or not S.isOwner(h, ch.charid) then return end
    if (tonumber(h.price) or 0) <= 0 then return Tip(src, Locale.no_price) end
    -- clearOwner sends every occupant out (the house is no longer owned)
    if Config.Rules.sellEmptiesLedgers then
        h.ledger, h.taxledger = 0, 0
        S.save(h, 'ledger', 'taxledger')
    end
    h.sellerIdent, h.sellerChar = ch.ident, ch.charid
    S.save(h, 'seller', 'sellerChar')
    S.clearOwner(h)
    S.sendHouse(h)
    Tip(src, Locale.put_for_sale)
    Activity(h.id, 'SELL', 'Put back on the market', S.actor(ch))
    AdminLog(('%s (%s) house put for sale id: %s'):format(ch.name, ch.ident, h.id))
end)

-- ledgers (in memory, written through; every check and change happens without waiting)
Rpc('sv_balances', 300, function(_, ch, id)
    local h = S.house(id)
    if not h or not S.hasAccess(h, ch.charid) then return 0, 0 end
    return h.ledger, h.taxledger
end)

Net('sv_ledger', 700, function(src, ch, id, op, amount)
    local h = S.house(id)
    amount = U.int(amount)
    if not h or not amount or amount <= 0 or amount > 100000000 then return end
    if not S.isOwner(h, ch.charid) then return Tip(src, Locale.owner_only) end
    if op == 'deposit' then
        if Config.Ledger.disabled then return end
        local cap = tonumber(Config.Ledger.cap) or 0
        if cap > 0 and h.ledger + amount > cap then return Tip(src, T('ledger_cap', cap)) end
        if not S.takeCash(ch, amount) then return Tip(src, Locale.cant_afford_deposit) end
        h.ledger = h.ledger + amount
        S.save(h, 'ledger')
        Tip(src, T('deposited', amount))
        Activity(h.id, 'DEPOSIT', ('$%s'):format(amount), S.actor(ch))
        AdminLog(('%s (%s) deposited $%s into the ledger of house %s'):format(ch.name, ch.ident, amount, h.id))
    elseif op == 'tax' then
        if not Config.Ledger.taxLedger then return end
        if h.taxledger + amount > h.tax then return Tip(src, T('tax_cap', h.tax)) end
        if not S.takeCash(ch, amount) then return Tip(src, Locale.cant_afford_deposit) end
        h.taxledger = h.taxledger + amount
        S.save(h, 'taxledger')
        Tip(src, T('deposited_tax', amount))
        Activity(h.id, 'TAX', ('$%s'):format(amount), S.actor(ch))
        AdminLog(('%s (%s) deposited $%s into the tax ledger of house %s'):format(ch.name, ch.ident, amount, h.id))
    elseif op == 'withdraw' then
        if Config.Ledger.disabled then return end
        if amount > h.ledger then return end
        h.ledger = h.ledger - amount
        if not S.giveCash(ch, amount) then
            h.ledger = h.ledger + amount
            return
        end
        S.save(h, 'ledger')
        Tip(src, T('withdrew', amount))
        Activity(h.id, 'WITHDRAW', ('$%s'):format(amount), S.actor(ch))
        AdminLog(('%s (%s) withdrew $%s from the ledger of house %s'):format(ch.name, ch.ident, amount, h.id))
    end
end)

-- keys
Net('sv_giveKey', 1500, function(src, ch, id, target)
    local h = S.house(id)
    if not h or not S.isOwner(h, ch.charid) then return end
    target = U.int(target)
    local tch = target and S.char(target)
    if not tch then return Tip(src, Locale.no_such_user) end
    if tch.charid == h.buyerChar then return Tip(src, Locale.already_keys_or_wrong) end
    if S.isKeyholder(h, tch.charid) then
        Tip(tch.src, Locale.already_keys)
        return Tip(src, Locale.already_keys_or_wrong)
    end
    if #h.keys >= 50 then return Tip(src, Locale.already_keys_or_wrong) end
    h.keys[#h.keys + 1] = { identifier = tch.ident, charidentifier = tch.charid, name = tch.name }
    S.save(h, 'keys')
    S.bridgeSync(h)
    S.sendHouse(h)
    Activity(h.id, 'KEY_GIVE', 'Gave keys to ' .. tch.name, S.actor(ch))
    Tip(src, T('gave_keys', tch.name))
    Tip(tch.src, Locale.got_key)
    AdminLog(('%s gave keys of house %s to %s'):format(ch.name, h.id, tch.name))
end)

function S.removeKey(h, charid)
    local kept, removedName = {}, nil
    for _, k in ipairs(h.keys) do
        if tonumber(k.charidentifier or k.charid) == charid then
            removedName = removedName or k.name or tostring(charid)
        else
            kept[#kept + 1] = k
        end
    end
    if not removedName then return nil end
    h.keys = kept
    S.save(h, 'keys')
    S.bridgeSync(h)
    S.sendHouse(h)
    S.afterAccessChange(h, { [charid] = true }, false)
    return removedName
end

Net('sv_takeKey', 1000, function(src, ch, id, charid)
    local h = S.house(id)
    charid = U.int(charid)
    if not h or not charid or not S.isOwner(h, ch.charid) then return end
    local name = S.removeKey(h, charid)
    if not name then return end
    Activity(h.id, 'KEY_TAKE', 'Took keys from ' .. name, S.actor(ch))
    Tip(src, T('took_keys', name))
    AdminLog(('%s took the keys of house %s from %s'):format(ch.name, h.id, name))
end)

-- owner's own Discord log
Net('sv_webhook', 2000, function(src, ch, id, text)
    local h = S.house(id)
    if not h then return end
    if not S.isOwner(h, ch.charid) then return Tip(src, Locale.owner_only) end
    if not Config.OwnerWebhooks then return Tip(src, Locale.log_off) end
    text = tostring(text or ''):gsub('%s', '')
    local low = text:lower()
    if text == '' or low == 'clear' or low == 'off' then
        local ok, n = pcall(MySQL.update.await, 'UPDATE playerhousing SET webhook = NULL WHERE id = ? AND owned = 1 AND buyercharidentifier = ?', { h.id, ch.charid })
        if ok and n == 1 then
            S.setHookCache(h.id, nil)
            Tip(src, Locale.log_disconnected)
        end
        return
    end
    if not S.validHook(text) then return Tip(src, Locale.log_bad_url) end
    local ok, n = pcall(MySQL.update.await, 'UPDATE playerhousing SET webhook = ? WHERE id = ? AND owned = 1 AND buyercharidentifier = ?', { text, h.id, ch.charid })
    if not ok or n ~= 1 then return end
    S.setHookCache(h.id, text)
    Tip(src, Locale.log_connected)
    Activity(h.id, 'LOG', 'House log connected - ledger, tax and storage activity will post here', S.actor(ch))
end)

-- teleporter interior swap
Net('sv_interior', 2000, function(src, ch, id, name)
    if not Config.AllowInteriorChange then return end
    local h = S.house(id)
    if not h or h.kind ~= KIND_TELE or not S.isOwner(h, ch.charid) then return end
    if type(name) ~= 'string' or not Config.Interiors[name] then return end
    if U.interiorName(h) == name then return end
    local price = math.floor(tonumber(Config.Interiors[name].price) or 0)
    if not S.takeCash(ch, price) then return Tip(src, T('not_enough_money', price)) end
    h.other = { name }
    S.save(h, 'other')
    S.sendHouse(h)
    AdminLog(('%s changed the interior of house %s to %s for $%s'):format(ch.name, h.id, name, price))
end)

-- stash and wardrobe spots (the server checks the house range too)
Net('sv_spot', 1000, function(src, ch, id, which, pos)
    local h = S.house(id)
    if not h or not S.mayKeyholder(h, ch.charid, 'keyholderSpots') then return end
    if which ~= 'stash' and which ~= 'changing' then return end
    pos = U.vec(pos)
    local ped = S.pedPos(src)
    if not pos or not ped or #(pos - ped) > Config.Reach.serverSpot then return end
    if not S.inHouseArea(src, h, pos) then return Tip(src, Locale.out_of_range) end
    h[which] = { x = pos.x, y = pos.y, z = pos.z }
    S.save(h, which)
    S.sendHouse(h)
end)

-- door toggles (only at the door)
local function findDoor(h, seq)
    if seq == 0 then return h.doors[1], 'doors' end
    for _, d in ipairs(h.other) do
        if type(d) == 'table' and U.int(d.secondarydoorid) == seq then return d, 'other' end
    end
    return nil
end

Net('sv_door', 400, function(src, ch, id, seq)
    if Config.Doorlocks.enabled then return end
    local h = S.house(id)
    seq = U.int(seq)
    if not h or not seq or h.kind ~= KIND_REAL or not S.hasAccess(h, ch.charid) then return end
    local door, field = findDoor(h, seq)
    local dpos = U.vec(door)
    local ped = S.pedPos(src)
    if not dpos or not ped then return end
    -- at the door itself or at its (nudged) prompt spot
    local spot = (tonumber(door.o) and tonumber(door.p) and tonumber(door.q)) and vector3(door.o + 0.0, door.p + 0.0, door.q + 0.0) or dpos
    if #(ped - dpos) > Config.Reach.serverDoor and #(ped - spot) > Config.Reach.serverDoor then return end
    door.locked = not (door.locked == true)
    S.save(h, field)
    S.sendHouseNear(h, false, src)
end)

-- Sold Home Ledger
local function nearLedgerPoint(src)
    local ped = S.pedPos(src)
    if not ped then return false end
    for _, p in ipairs(Config.LedgerPoints) do
        if #(ped - p.coords) <= Config.Reach.ledger + 3.0 then return true end
    end
    return false
end

local function soldList(charid)
    local ok, rows = pcall(MySQL.query.await, 'SELECT id, amount FROM playerhousing_sold_home_ledger WHERE charidentifier = ?', { charid })
    local list = {}
    if ok then
        for _, r in ipairs(rows or {}) do
            list[#list + 1] = { id = U.int(r.id) or 0, amount = U.int(r.amount) or 0 }
        end
    end
    return list
end

Rpc('sv_soldList', 1000, function(_, ch)
    return soldList(ch.charid)
end)

Net('sv_soldCollect', 1000, function(src, ch, houseId, amount)
    houseId, amount = U.int(houseId), U.int(amount)
    if not houseId or not amount or not nearLedgerPoint(src) then return end
    local ok, rows = pcall(MySQL.query.await,
        'SELECT identifier, amount FROM playerhousing_sold_home_ledger WHERE charidentifier = ? AND id = ? AND amount = ? LIMIT 1',
        { ch.charid, houseId, amount })
    if not ok or not rows or not rows[1] then return end
    local row = rows[1]
    if amount <= 0 then
        MySQL.update('DELETE FROM playerhousing_sold_home_ledger WHERE charidentifier = ? AND id = ? AND amount = ? LIMIT 1', { ch.charid, houseId, amount })
        return
    end
    local okD, n = pcall(MySQL.update.await,
        'DELETE FROM playerhousing_sold_home_ledger WHERE charidentifier = ? AND id = ? AND amount = ? LIMIT 1',
        { ch.charid, houseId, amount })
    if not okD or n ~= 1 then return end -- another press already took it
    if not S.giveCash(ch, amount) then
        -- the character changed while we waited: put the payout back
        MySQL.insert('INSERT INTO playerhousing_sold_home_ledger (id, identifier, charidentifier, amount) VALUES (?, ?, ?, ?)',
            { houseId, row.identifier, ch.charid, amount })
        return
    end
    Tip(src, T('sold_paid', amount))
    AdminLog(('%s (%s) collected $%s from the Sold Home Ledger for house %s'):format(ch.name, ch.ident, amount, houseId))
    TriggerClientEvent('pup_realestate:cl_soldList', src, soldList(ch.charid))
end)

-- creating (from the in-world creator that vorp_admin opens)
local function num(v) v = tonumber(v); if not v or v ~= v or v == math.huge or v == -math.huge then return nil end return v + 0.0 end

local function cleanDoor(d, seq)
    if type(d) ~= 'table' then return nil end
    local x, y, z = num(d.x), num(d.y), num(d.z)
    if not (x and y and z) then return nil end
    local out = {
        x = x, y = y, z = z,
        o = num(d.o) or x, p = num(d.p) or y, q = num(d.q) or z,
        doorname = tostring(d.doorname or ''):sub(1, 64),
        doorhash = U.int(d.doorhash) or 0,
        objc = U.int(d.objc) or 0,
        objYaw1 = num(d.objYaw1) or 0.0, objYaw2 = num(d.objYaw2) or 0.0, objYaw3 = num(d.objYaw3) or 0.0,
        locked = true,
    }
    if seq then out.secondarydoorid = seq end
    return out
end

Net('sv_create', 3000, function(src, ch, data)
    if not S.canCreate(ch) or type(data) ~= 'table' then return end
    local kind = U.int(data.kind)
    if kind ~= KIND_REAL and kind ~= KIND_MARKER and kind ~= KIND_TELE then return end
    if type(data.doors) ~= 'table' or type(data.doors[1]) ~= 'table' then return end
    local price, tax, slots, range = U.int(data.price), U.int(data.tax), U.int(data.slots), U.int(data.range)
    if not price or not tax or not slots or not range then return Tip(src, Locale.invalid_values) end
    slots = U.slotCap(slots)
    if price <= 0 or slots <= 0 or tax < 0 or range < 0 then return Tip(src, Locale.invalid_values) end
    local ped = S.pedPos(src)
    if not ped then return end

    local doors, other = {}, {}
    if kind == KIND_REAL then
        doors[1] = cleanDoor(data.doors[1])
        if not doors[1] then return end
        if type(data.other) == 'table' then
            for i, d in ipairs(data.other) do
                if i > 16 then break end
                local c = cleanDoor(d, i)
                if c then other[#other + 1] = c end
            end
        end
    else
        local p = U.vec(data.doors[1])
        if not p then return end
        doors[1] = { x = p.x, y = p.y, z = p.z }
        if kind == KIND_TELE then
            local name = type(data.other) == 'table' and data.other[1]
            if type(name) ~= 'string' or not Config.Interiors[name] then return end
            other[1] = name
        end
    end
    for _, d in ipairs(doors) do if #(vector3(d.x, d.y, d.z) - ped) > 60.0 then return end end
    for _, d in ipairs(other) do
        if type(d) == 'table' and #(vector3(d.x, d.y, d.z) - ped) > 60.0 then return end
    end
    -- a door that already has a doorlock can't be used for a house
    if kind == KIND_REAL then
        for _, d in ipairs(doors) do if S.doorlocksHas(d.objc) then return Tip(src, Locale.door_has_lock) end end
        for _, d in ipairs(other) do if S.doorlocksHas(d.objc) then return Tip(src, Locale.door_has_lock) end end
    end

    local sellerIdent, sellerChar = '', 0
    if Config.Rules.creatorIsSeller then sellerIdent, sellerChar = ch.ident, ch.charid end
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO playerhousing (`type`, primarydoor, otherdoors, `range`, owned, selleridentifier, sellercharidentifier,
            ledger, tax, repoed, invspace, `upgrade`, keyholders, changingroom, inventorylocation, items, furniture,
            price, buyeridentifier, buyercharidentifier, taxledger, motel)
        VALUES (?, ?, ?, ?, 0, ?, ?, 0, ?, 0, ?, 0, '[]', '[]', '[]', '[]', '[]', ?, '0', 0, 0, '0')]],
        { kind, json.encode(doors), json.encode(other), range, sellerIdent, sellerChar, tax, slots, price })
    id = ok and U.int(id)
    if not id then return Warn('creating a house failed') end
    local h = S.newHouse({
        id = id, kind = kind, doors = doors, other = other, range = range, price = price, tax = tax,
        slots = slots, sellerIdent = sellerIdent, sellerChar = sellerChar,
    })
    S.houses[id] = h
    S.ensureContainer(id)
    S.bridgeSync(h)
    S.sendFull()
    Tip(src, Locale.created)
    Activity(id, 'CREATE', ('kind %s, $%s, tax $%s, %s slots'):format(kind, price, tax, slots), S.actor(ch))
    AdminLog(('%s created house %s (kind %s) price $%s tax $%s slots %s'):format(ch.name, id, kind, price, tax, slots))
end)

-- deleting an unsold house (in game or from the admin panel)
function S.deleteHouse(h, reason)
    if h.owned then return false, 'owned' end
    if S.auctioned[h.id] and S.cancelAuctionsForHouse then
        S.cancelAuctionsForHouse(h.id, reason)
    end
    local cur = S.houses[h.id]
    if not cur or cur.owned then return false, 'owned' end
    h.deleted = true
    S.houses[h.id] = nil
    pcall(MySQL.update.await, 'DELETE FROM playerhousing WHERE id = ?', { h.id })
    S.bridgeRemove(h)
    S.deleteContainer(h.id)
    S.locks[h.id], S.near[h.id], S.knocks[h.id], S.viewing[h.id], S.auctioned[h.id] = nil, nil, nil, nil, nil
    local occ = S.occupants[h.id]
    if occ then for osrc in pairs(occ) do S.forceLeave(osrc, h.id) end end
    for src, pass in pairs(S.passes) do if pass.house == h.id then S.passes[src] = nil end end
    S.forgetHook(h.id)
    S.sendFull()
    return true
end

Net('sv_delete', 3000, function(src, ch, id)
    local h = S.house(id)
    if not h or h.owned or not S.canDeleteUnsold(ch) then return end
    local ok = S.deleteHouse(h, 'House removed by the housing office')
    if not ok then return end
    Tip(src, T('deleted', h.id))
    AdminLog(('%s deleted house %s'):format(ch.name, h.id))
end)
