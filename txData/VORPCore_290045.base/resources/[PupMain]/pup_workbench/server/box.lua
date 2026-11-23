-- The personal crafting box: a take-only custom inventory, id 9000000 + charid.
Box = {}

local anchors = {}   -- charid -> { x, y, z } where an empty box was first filled (memory only)

function Box.id(charid)
    return tostring(Config.Box.idOffset + charid)
end

function Box.ensure(charid)
    local id = Box.id(charid)
    if Inv:isCustomInventoryRegistered(id) then return id end
    Inv:registerInventory({
        id = id,
        name = L('box_name'),
        limit = 0,                    -- 0 or less is unlimited
        acceptWeapons = false,
        shared = false,
        ignoreItemStackLimit = true,
        whitelistItems = false,
        UsePermissions = false,
        UseBlackList = false,
        whitelistWeapons = false,
    })
    return id
end

--- Total item count in a character's box.
function Box.count(charid)
    local id = Box.ensure(charid)
    local items = Inv:getCustomInventoryItems(id)
    local n = 0
    if type(items) == 'table' then
        for _, it in ipairs(items) do n = n + (tonumber(it.amount) or 0) end
    end
    return n
end

local function placeName(anchor, here)
    local s = Stations.nearest(anchor, Config.Box.stationSearch)
    if s then return s.name:upper(), true end
    return math.floor((here and WB.dist(anchor, here) or 0) + 0.5), false
end

--- Put goods in the box. Returns true when the box took them.
function Box.deposit(src, who, rewards, metadata)
    local id = Box.ensure(who.charid)
    local before = Box.count(who.charid)
    local here = PlayerPos(src)
    local anchor = anchors[who.charid]
    local setAnchor = false

    if before == 0 then
        if here then
            anchors[who.charid] = here
            setAnchor = true
        end
    elseif anchor and here and WB.dist(anchor, here) > Config.Box.anchorRadius then
        local where, isStation = placeName(anchor, here)
        local place = isStation and where or L('box_elsewhere_far', where)
        Notify(src, L('box_holds_elsewhere', place), 7000)
    end

    local items = {}
    for _, r in ipairs(rewards) do
        local entry = { name = r.name, amount = r.count }
        if metadata then entry.metadata = metadata end
        items[#items + 1] = entry
    end
    local ok, res = pcall(function()
        return Inv:addItemsToCustomInventory(id, items, who.charid, nil, who.identifier)
    end)
    local took = ok and res == true
    if not took and setAnchor then anchors[who.charid] = nil end
    return took
end

--- Open the box for the player, if they stand where it was filled.
function Box.open(src, who)
    local id = Box.ensure(who.charid)
    local n = Box.count(who.charid)
    if n == 0 then
        anchors[who.charid] = nil
    else
        local anchor = anchors[who.charid]
        local here = PlayerPos(src)
        if anchor and here and WB.dist(anchor, here) > Config.Box.anchorRadius then
            local where, isStation = placeName(anchor, here)
            if isStation then return false, L('box_at_station', where) end
            return false, L('box_far', where)
        end
    end
    Inv:openInventory(src, id)
    return true
end

--- pup-gangs kept its gang stashes at 9000000 + gangid*10 + n until a one-time move to
--- 13000000 (marked by gang_meta 'stash_offset_13m'). Until that move is recorded,
--- the 9000000 range may still hold gang stashes, so the wipe must not run.
local function gangStashesMoved()
    if not DB.tableExists('gangs') then return true end
    if not DB.tableExists('gang_meta') then return false end
    local v = MySQL.scalar.await("SELECT v FROM gang_meta WHERE k = 'stash_offset_13m'")
    return v ~= nil
end

--- Empty every crafting box (9000000 to 9999999).
function Box.wipeAll()
    local lo, hi = Config.Box.idOffset, Config.Box.idOffset + 999999
    local okG, moved = pcall(gangStashesMoved)
    if not okG or not moved then
        Warn('crafting boxes NOT emptied: pup-gangs has not recorded moving its stashes out of the 9000000 range (%s)',
            okG and 'gang_meta stash_offset_13m missing' or tostring(moved))
        return
    end
    local ok, err = pcall(function()
        local rows = MySQL.query.await(
            [[SELECT DISTINCT inventory_type FROM character_inventories
              WHERE inventory_type REGEXP '^[0-9]+$' AND CAST(inventory_type AS UNSIGNED) BETWEEN ? AND ?]],
            { lo, hi }) or {}
        if #rows == 0 then return end
        local ids = {}
        for _, row in ipairs(rows) do ids[#ids + 1] = tostring(row.inventory_type) end

        local crafted = MySQL.query.await(
            'SELECT item_crafted_id FROM character_inventories WHERE inventory_type IN (?) AND item_crafted_id IS NOT NULL',
            { ids }) or {}
        MySQL.update.await('DELETE FROM character_inventories WHERE inventory_type IN (?)', { ids })
        local craftedIds = {}
        for _, row in ipairs(crafted) do craftedIds[#craftedIds + 1] = row.item_crafted_id end
        for i = 1, #craftedIds, 500 do
            local chunk = { table.unpack(craftedIds, i, math.min(i + 499, #craftedIds)) }
            MySQL.update.await('DELETE FROM items_crafted WHERE id IN (?)', { chunk })
        end
        for _, id in ipairs(ids) do
            if Inv:isCustomInventoryRegistered(id) then Inv:removeInventory(id) end
        end
        print(('[pup_workbench] emptied %d crafting boxes'):format(#ids))
    end)
    if not ok then Warn('crafting boxes could not be emptied: %s', tostring(err)) end
    anchors = {}
end
