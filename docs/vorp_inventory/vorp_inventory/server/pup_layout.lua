-- Shared item order for custom containers (houses, society containers, saddlebags, wagons, motel rooms)

local LAYOUT = {} -- [invId] = { ["item_standard:123"] = slot, ["item_weapon:45"] = slot }
local loaded = false

local function keyOf(itemType, id)
    return tostring(itemType or "item_standard") .. ":" .. tostring(id)
end

-- One-time move from the old table name: an older database keeps its container layouts.
-- Only when pup_inventory_layout exists and inventory_layout does not; never overwrites anything.
local function renameOldTable(old, new)
    local function has(name)
        return (tonumber(MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })) or 0) > 0
    end
    if not has(old) then return end
    if has(new) then
        print(('^3[vorp_inventory]^7 both %s and %s exist: using %s, the old table is left alone'):format(old, new, new))
        return
    end
    MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(old, new), {})
    print(('^2[vorp_inventory]^7 renamed table %s to %s'):format(old, new))
end

CreateThread(function()
    renameOldTable('pup_inventory_layout', 'inventory_layout')

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `inventory_layout` (
            `inventory_type` VARCHAR(100) NOT NULL,
            `item_key`       VARCHAR(80)  NOT NULL,
            `slot`           INT          NOT NULL DEFAULT 0,
            PRIMARY KEY (`inventory_type`, `item_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local rows = MySQL.query.await("SELECT inventory_type, item_key, slot FROM inventory_layout", {}) or {}
    for _, r in ipairs(rows) do
        LAYOUT[r.inventory_type] = LAYOUT[r.inventory_type] or {}
        LAYOUT[r.inventory_type][r.item_key] = tonumber(r.slot) or 0
    end
    loaded = true
    print(("^2[vorp_inventory]^7 container layouts loaded for %d container(s)"):format(#rows > 0 and (function()
        local n = 0
        for _ in pairs(LAYOUT) do n = n + 1 end
        return n
    end)() or 0))
end)

-- Order a RELOAD item list by the container's saved layout
function PupSortCustomInventory(invId, itemList)
    if type(itemList) ~= "table" then return itemList end
    local saved = LAYOUT[tostring(invId)] or {}
    local BIG <const> = 1000000
    local indexed = {}
    for i, it in ipairs(itemList) do
        local slot = saved[keyOf(it.type, it.id)]
        indexed[#indexed + 1] = {
            item = it,
            slot = slot or BIG,
            weapon = it.type == "item_weapon" and 1 or 0,
            id = tonumber(it.id) or 0,
            i = i,
        }
    end
    table.sort(indexed, function(a, b)
        if a.slot ~= b.slot then return a.slot < b.slot end
        if a.weapon ~= b.weapon then return a.weapon < b.weapon end
        if a.id ~= b.id then return a.id < b.id end
        return a.i < b.i
    end)
    local out = {}
    for i, e in ipairs(indexed) do out[i] = e.item end
    return out
end

-- the player pressed Save on a container grid: replace that container's layout
RegisterNetEvent("vorp_inventory:Server:saveCustomLayout", function(invId, order)
    local _source <const> = source
    invId = tostring(invId or "")
    if invId == "" or type(order) ~= "table" then return end

    -- having it open is not permission to rearrange it for everybody. The opening
    -- resource says who manages this container; absent means no.
    if INVENTORY_IN_USE[_source] ~= invId then return end
    if not INVENTORY_CAN_MANAGE[_source] then return end
    if not CUSTOM_INVENTORIES[invId] then return end

    local map, rows, n = {}, {}, 0
    for _, row in ipairs(order) do
        if type(row) == "table" and row.id ~= nil then
            local k = keyOf(row.t or row.type, row.id)
            if map[k] == nil then
                map[k] = n
                rows[#rows + 1] = { invId, k, n }
                n = n + 1
            end
        end
        if n >= 2000 then break end
    end
    if n == 0 then return end

    LAYOUT[invId] = map

    local queries = { { query = "DELETE FROM inventory_layout WHERE inventory_type = ?", values = { invId } } }
    for _, r in ipairs(rows) do
        queries[#queries + 1] = {
            query = "INSERT INTO inventory_layout (inventory_type, item_key, slot) VALUES (?, ?, ?)",
            values = r,
        }
    end
    MySQL.transaction(queries, function(ok)
        if not ok then print(("^1[vorp_inventory]^7 container layout save failed for %s"):format(invId)) end
    end)

    -- redraw in the saved order for the player who arranged it
    INVENTORY_SERVICE.INVENTORY.RELOAD(_source, invId)
end)

-- a container that is deleted for good takes its layout with it
AddEventHandler("vorp_inventory:Server:customInventoryDeleted", function(invId)
    invId = tostring(invId or "")
    if invId == "" or not LAYOUT[invId] then return end
    LAYOUT[invId] = nil
    MySQL.update("DELETE FROM inventory_layout WHERE inventory_type = ?", { invId })
end)
