-- pup_realestate | furniture, storage upgrades, wardrobe

local INV = exports.vorp_inventory

local function nextPieceId(h)
    local top = 0
    for _, p in ipairs(h.furniture) do
        local n = U.int(p.id) or 0
        if n > top then top = n end
    end
    return top + 1
end

local function findPiece(h, pieceId)
    pieceId = U.int(pieceId)
    if not pieceId then return nil end
    for i, p in ipairs(h.furniture) do
        if U.int(p.id) == pieceId then return p, i end
    end
    return nil
end

local function inventoryCounts(src)
    local counts = {}
    local ok, items = pcall(function() return INV:getUserInventoryItems(src) end)
    if ok and type(items) == 'table' then
        for _, it in pairs(items) do
            if type(it) == 'table' and it.name then
                counts[it.name] = (counts[it.name] or 0) + (tonumber(it.count) or 0)
            end
        end
    end
    return counts
end

-- item mode: the catalogue pieces the player carries
Rpc('sv_furnList', 1000, function(src, ch, id)
    local h = S.house(id)
    if not h or not S.mayKeyholder(h, ch.charid, 'keyholderFurniture') then return {} end
    local counts = inventoryCounts(src)
    local list = {}
    for item, e in pairs(Catalog.byItem) do
        if (counts[item] or 0) >= 1 then
            list[#list + 1] = { name = e.name, item = item, model = e.model }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end)

Net('sv_furnPlace', 800, function(src, ch, id, key, pos, heading)
    local h = S.house(id)
    if not h or not S.mayKeyholder(h, ch.charid, 'keyholderFurniture') then return end
    if type(key) ~= 'string' then return end
    local max = Config.Furniture.maxPieces
    if #h.furniture >= max then return Tip(src, T('furniture_cap', max)) end
    pos = U.vec(pos)
    heading = tonumber(heading)
    if not pos or not heading or heading ~= heading then return end
    heading = heading % 360.0
    -- the server checks the spot is part of the house, and near the placer
    local ped = S.pedPos(src)
    if not ped or #(ped - pos) > Config.Reach.serverPieceFromPlayer then return end
    if not S.inHouseArea(src, h, pos) then return Tip(src, Locale.out_of_range) end

    local entry, fromItem
    if Config.Furniture.useItems then
        entry = Catalog.byItem[key]
        if not entry then return end
        local okC, count = pcall(function() return INV:getItemCount(src, nil, entry.item) end)
        if not okC or (tonumber(count) or 0) < 1 then return end
        local okS, removed = pcall(function() return INV:subItem(src, entry.item, 1) end)
        if not okS or not removed then return end
        fromItem = true
    else
        entry = Catalog.byName[key]
        if not entry then return end
        if not S.takeCash(ch, entry.cost) then return Tip(src, Locale.cant_afford_item) end
    end

    -- anything may have changed while the inventory answered: re-check, and give it back if so
    local cur = S.houses[h.id]
    if not cur or not S.mayKeyholder(cur, ch.charid, 'keyholderFurniture') or #cur.furniture >= max then
        if fromItem then pcall(function() INV:addItem(src, entry.item, 1) end) else S.giveCash(ch, entry.cost) end
        return
    end
    local piece = {
        id = nextPieceId(cur), name = entry.name, price = entry.cost,
        x = pos.x, y = pos.y, z = pos.z, h = heading, furnitem = entry.model,
    }
    if fromItem then piece.item = entry.item end
    cur.furniture[#cur.furniture + 1] = piece
    S.save(cur, 'furniture')
    Tip(src, fromItem and Locale.placed_item or Locale.bought_item)
    S.sendHouseNear(cur, true, src)
end)

Net('sv_furnRemove', 800, function(src, ch, id, pieceId)
    local h = S.house(id)
    if not h or not S.mayKeyholder(h, ch.charid, 'keyholderFurniture') then return end
    local piece = findPiece(h, pieceId)
    if not piece then return end
    if piece.item then
        local okC, can = pcall(function() return INV:canCarryItem(src, piece.item, 1) end)
        if not okC or not can then return Tip(src, Locale.cant_carry) end
    end
    -- the inventory call may have yielded: look the piece up again, then claim it so two
    -- quick presses cannot both get it back
    local cur = S.houses[h.id]
    if cur ~= h or not S.mayKeyholder(h, ch.charid, 'keyholderFurniture') then return end
    local index
    piece, index = findPiece(h, pieceId)
    if not piece then return end
    table.remove(h.furniture, index)
    if piece.item then
        local okA, added = pcall(function() return INV:addItem(src, piece.item, 1) end)
        if not okA or added == false then
            h.furniture[#h.furniture + 1] = piece
            return Tip(src, Locale.cant_carry)
        end
        local e = Catalog.byItem[piece.item]
        Tip(src, T('withdrew_item', e and e.name or piece.name or piece.item))
    else
        Tip(src, Locale.no_item_back)
    end
    S.save(h, 'furniture')
    S.sendHouseNear(h, true, src)
end)

Net('sv_furnSell', 800, function(src, ch, id, pieceId)
    local h = S.house(id)
    if not h or not S.mayKeyholder(h, ch.charid, 'keyholderFurniture') then return end
    local piece, index = findPiece(h, pieceId)
    if not piece then return end
    if piece.item then return Tip(src, Locale.use_remove) end
    local refund = math.floor((tonumber(piece.price) or 0) * (tonumber(Config.Furniture.sellRate) or 0))
    table.remove(h.furniture, index)
    if refund > 0 and not S.giveCash(ch, refund) then
        h.furniture[#h.furniture + 1] = piece
        return
    end
    S.save(h, 'furniture')
    Tip(src, T('sold_item', refund))
    S.sendHouseNear(h, true, src)
end)

-- storage upgrades: materials come out of the house container
local upgrading = {}

Net('sv_upgrade', 3000, function(src, ch, id)
    local h = S.house(id)
    if not h or not S.mayKeyholder(h, ch.charid, 'keyholderUpgrades') then return end
    if upgrading[h.id] then return end
    local level = Upgrades.byLevel[(h.upgrade or 0) + 1]
    if not level then return end
    upgrading[h.id] = true
    local ok, err = pcall(function()
        local cid = S.containerId(h.id)
        S.ensureContainer(h.id)
        S.migrate(h.id)
        local okI, items = pcall(function() return INV:getCustomInventoryItems(cid) end)
        if not okI or type(items) ~= 'table' then items = {} end
        local have = {}
        for _, it in pairs(items) do
            if type(it) == 'table' and it.name then
                have[it.name] = (have[it.name] or 0) + (tonumber(it.amount or it.count) or 0)
            end
        end
        local need, order = {}, {}
        for _, m in ipairs(level.materials) do
            if not need[m.name] then order[#order + 1] = m.name end
            need[m.name] = (need[m.name] or 0) + m.amount
        end
        for name, amount in pairs(need) do
            if (have[name] or 0) < amount then return Tip(src, Locale.upgrade_short) end
        end
        -- re-check after the waits
        local cur = S.houses[h.id]
        if cur ~= h or (h.upgrade or 0) + 1 ~= level.level or not S.mayKeyholder(h, ch.charid, 'keyholderUpgrades') then return end
        -- take each material; if one cannot be taken (someone emptied the stash meanwhile) the
        -- upgrade is refused and what was already taken goes back into the container
        local taken = {}
        for _, name in ipairs(order) do
            if need[name] > 0 then
                local okR, removed = pcall(function() return INV:removeItemFromCustomInventory(cid, name, need[name], nil) end)
                if not okR or removed ~= true then
                    Warn('house %s upgrade: removing %s x%s from the container failed - upgrade refused', h.id, name, need[name])
                    if #taken > 0 then
                        local back = (h.owned and h.buyerChar or 0) > 0 and h.buyerChar or ch.charid
                        pcall(function() INV:addItemsToCustomInventory(cid, taken, back) end)
                    end
                    pcall(function() INV:reloadCustomInventory(src, cid) end)
                    return Tip(src, Locale.upgrade_short)
                end
                taken[#taken + 1] = { name = name, amount = need[name], metadata = {} }
            end
        end
        pcall(function() INV:reloadCustomInventory(src, cid) end)
        S.rewriteReports({ [h.id] = true }, { [h.id] = S.actor(ch) })
        h.upgrade = level.level
        h.slots = U.slotCap((h.slots or 0) + level.slots)
        S.save(h, 'upgrade', 'slots')
        S.updateSlots(h.id)
        Tip(src, Locale.upgraded)
        S.sendHouse(h)
        AdminLog(('%s upgraded the storage of house %s to level %s (+%s slots)'):format(ch.name, h.id, level.level, level.slots))
    end)
    upgrading[h.id] = nil
    if not ok then Warn('upgrade of house %s failed: %s', h.id, tostring(err)) end
end)

-- wardrobe: saved outfits from vorp_character
local function wardrobeAllowed(src, ch, rowId)
    local r, isMotel = S.row(rowId)
    if not r then return false end
    local spot
    if isMotel then
        if r.owner ~= ch.charid or not S.insideRow(src, r.id) then return false end
        spot = Config.MotelRoom.wardrobe
    else
        if not S.hasAccess(r, ch.charid) then return false end
        spot = U.vec(r.changing)
    end
    local ped = S.pedPos(src)
    return spot and ped and #(ped - spot) <= Config.Reach.serverStash + 1.5
end

local function outfits(charid)
    local ok, rows = pcall(MySQL.query.await, 'SELECT title, comps FROM outfits WHERE charidentifier = ? ORDER BY title', { charid })
    if not ok then return nil end
    return rows or {}
end

Rpc('sv_outfits', 1000, function(src, ch, rowId)
    if not wardrobeAllowed(src, ch, rowId) then return nil end
    local rows = outfits(ch.charid)
    if not rows then return nil end
    local list = {}
    for i, r in ipairs(rows) do list[i] = { index = i, title = tostring(r.title or ('Outfit ' .. i)) } end
    return list
end)

Net('sv_outfit', 1500, function(src, ch, rowId, index, title)
    index = U.int(index)
    if not index or not wardrobeAllowed(src, ch, rowId) then return end
    local rows = outfits(ch.charid)
    local row = rows and rows[index]
    if not row or tostring(row.title) ~= tostring(title) or type(row.comps) ~= 'string' then return end
    local again = S.char(src)
    if not again or again.charid ~= ch.charid then return end
    TriggerClientEvent('pup_realestate:cl_dress', src, row.comps)
    if GlobalState['pup_disguise_' .. ch.charid] == true then return end
    MySQL.update('UPDATE characters SET compPlayer = ? WHERE charidentifier = ?', { row.comps, ch.charid })
end)
