-- pup_camps | furniture: listing, adding, placing, removing

local function pieceLine(p)
    return ('%s (%s)'):format(p.label or '?', p.item or '?')
end

-- furniture items the player carries, sorted by label
Handle('furniItems', function(ctx, campId)
    local camp, why = Can(ctx, campId, 'furniture')
    if not camp then return nil, why end
    local items = exports.vorp_inventory:getUserInventoryItems(ctx.src) or {}
    local counts = {}
    for _, it in pairs(items) do
        local def = CampFurniture[it.name]
        if def then counts[it.name] = (counts[it.name] or 0) + (tonumber(it.count) or 0) end
    end
    local list = {}
    for name, n in pairs(counts) do
        if n > 0 then list[#list + 1] = { item = name, label = CampFurniture[name].label, count = n } end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end)

Handle('furniAdd', function(ctx, campId, item)
    local camp, why = Can(ctx, campId, 'furniture')
    if not camp then return nil, why end
    local def = type(item) == 'string' and CampFurniture[item] or nil
    if not def or item == Config.Camp.flagItem then return nil, L('furni_bad_prop') end
    local placed = U.placedCount(camp.furni)
    if placed >= Config.Camp.maxPieces then
        return nil, L('furni_limit', placed, Config.Camp.maxPieces)
    end
    if (tonumber(exports.vorp_inventory:getItemCount(ctx.src, nil, item)) or 0) < 1 then
        return nil, L('furni_no_item')
    end
    if not exports.vorp_inventory:subItem(ctx.src, item, 1) then return nil, L('furni_no_item') end
    -- the camp may have changed while the item was taken; re-check what matters
    if Camps[camp.id] ~= camp or U.placedCount(camp.furni) >= Config.Camp.maxPieces then
        exports.vorp_inventory:addItem(ctx.src, item, 1)
        return nil, L('furni_limit', U.placedCount(camp.furni), Config.Camp.maxPieces)
    end
    local kind = def.kind == 'set' and 'set' or 'prop'
    local id = NextPieceId(camp)
    camp.furni[id] = {
        id = id, item = item, prop = U.signed(def.model), label = def.label, cata = kind,
        functional = kind == 'set' and 'none' or (U.UseToStored[def.use] or 'none'),
        active = false, grounded = true,
        coords = { x = camp.coords.x, y = camp.coords.y, z = camp.coords.z }, heading = 0.0,
    }
    RecomputeStorage(camp)
    Save(camp)
    local p = camp.furni[id]
    CampLog(camp, 'furniture', 'Furniture Placed', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Piece', pieceLine(p) },
        { 'Pieces', ('%d / %d'):format(U.placedCount(camp.furni), Config.Camp.maxPieces), true },
        { 'Storage slots', tostring(camp.invlimit), true },
    }, { actor = ctx.src })
    PushCamp(camp, true)
    return PieceView(p)
end, { gapMs = 1000 })

-- take a placed piece down so it can be moved (it disappears for everyone)
Handle('furniLift', function(ctx, campId, pieceId)
    local camp, why = Can(ctx, campId, 'furniture')
    if not camp then return false, why end
    local p = camp.furni[tonumber(pieceId) or -1]
    if not p then return false end
    if p.item == Config.Camp.flagItem then return false end
    if p.active then
        p.active = false
        Save(camp)
        PushCamp(camp, true)
    end
    return true
end, { gapMs = 300 })

Handle('furniPlace', function(ctx, campId, pieceId, place)
    local camp, why = Can(ctx, campId, 'furniture')
    if not camp then return false, why end
    local p = camp.furni[tonumber(pieceId) or -1]
    if not p or p.item == Config.Camp.flagItem then return false end
    local pos = ValidPos(place)
    if not pos then return false end
    if U.dist2(pos, camp.coords) > Config.Camp.furnitureRadius + Config.Camp.placeSlack then
        return false, L('furni_out_of_area')
    end
    local heading = (tonumber(place.heading) or 0.0) % 360.0
    p.coords = pos
    p.heading = heading
    p.grounded = place.grounded == true
    p.active = true
    Save(camp)
    CampLog(camp, 'furniture', 'Furniture Moved', LogColour.blue, {
        { 'Who', Who(ctx.src, camp) }, { 'Piece', pieceLine(p) },
        { 'Position', ('%.2f, %.2f, %.2f (%.0f deg)'):format(pos.x, pos.y, pos.z, heading), true },
    }, { actor = ctx.src })
    PushCamp(camp, true)
    return true
end, { gapMs = 500 })

Handle('furniRemove', function(ctx, campId, pieceId)
    local camp, why = Can(ctx, campId, 'furniture')
    if not camp then return false, why end
    local id = tonumber(pieceId) or -1
    local p = camp.furni[id]
    if not p or p.item == Config.Camp.flagItem then return false end
    if not exports.vorp_inventory:canCarryItem(ctx.src, p.item, 1) then return false, L('furni_cant_carry') end
    -- remove first, then give; nothing awaits in between
    camp.furni[id] = nil
    RecomputeStorage(camp)
    if not exports.vorp_inventory:addItem(ctx.src, p.item, 1) then
        camp.furni[id] = p
        RecomputeStorage(camp)
        return false, L('furni_cant_carry')
    end
    Save(camp)
    Notify(ctx.src, L('furni_removed'))
    CampLog(camp, 'furniture', 'Furniture Removed', LogColour.red, {
        { 'Who', Who(ctx.src, camp) }, { 'Piece', pieceLine(p) },
        { 'Pieces', ('%d / %d'):format(U.placedCount(camp.furni), Config.Camp.maxPieces), true },
        { 'Storage slots', tostring(camp.invlimit), true },
    }, { actor = ctx.src })
    PushCamp(camp, true)
    return true
end, { gapMs = 1000 })
