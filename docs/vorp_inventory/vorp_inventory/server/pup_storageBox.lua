-- custom-inventory helpers that pup_StorageBox depends on

-- Which custom inventory (if any) this player currently has open
---@param src number
---@return string|nil
exports("getOpenCustomInventory", function(src)
    return INVENTORY_IN_USE[src]
end)

-- Re-render an already-open custom inventory panel without changing its type
---@param source number
---@param id string custom inventory id
exports("reloadCustomInventory", function(source, id)
    local _source <const> = source

    if not CUSTOM_INVENTORIES[id] then
        -- Not a registered custom inventory
        if USERS_ITEMS[id] then
            INVENTORY_SERVICE.INVENTORY.RELOAD(_source, id)
        end
        return
    end

    local function rebuildFromDB(inventory)
        local characterInventory <const> = {}
        for _, item in pairs(inventory or {}) do
            local dbItem <const> = SERVER_ITEMS[item.item]
            if dbItem then
                characterInventory[item.id] = ITEM:Register({
                    count          = tonumber(item.amount),
                    id             = item.id,
                    limit          = dbItem.limit,
                    label          = dbItem.label,
                    metadata       = SHARED_UTILS.MERGE_TABLES(dbItem.metadata, item.metadata),
                    name           = dbItem.item,
                    type           = dbItem.type,
                    canUse         = dbItem.canUse,
                    canRemove      = dbItem.canRemove,
                    createdAt      = item.created_at,
                    owner          = item.character_id,
                    desc           = dbItem.desc,
                    group          = dbItem.group,
                    rarity         = dbItem.rarity,
                    durability     = item.durability,
                    instruction    = dbItem.instruction,
                    weight         = dbItem.weight,
                    degradation    = item.degradation,
                    maxDegradation = dbItem.maxDegradation,
                    percentage     = item.percentage,
                })
            end
        end
        return characterInventory
    end

    if CUSTOM_INVENTORIES[id]:isShared() then
        DB_SERVICE.GET.SHARED_INVENTORY(id, function(inventory)
            USERS_ITEMS[id] = rebuildFromDB(inventory)
            INVENTORY_SERVICE.INVENTORY.RELOAD(_source, id)
        end)
        return
    end

    local character <const> = CORE.getUser(_source)?.getUsedCharacter
    if not character then
        INVENTORY_SERVICE.INVENTORY.RELOAD(_source, id)
        return
    end

    DB_SERVICE.GET.INVENTORY(character.charIdentifier, id, function(inventory)
        USERS_ITEMS[id] = USERS_ITEMS[id] or {}
        USERS_ITEMS[id][character.identifier] = rebuildFromDB(inventory)
        INVENTORY_SERVICE.INVENTORY.RELOAD(_source, id)
    end)
end)
