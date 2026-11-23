local InventoryApi = {
    ADD_ITEM = function(itemData)
        local itemId <const> = itemData.id
        local itemAmount <const> = itemData.count
        local item <const> = PLAYER_INVENTORY.ITEMS[itemId]

        if item then
            item:setCount(itemAmount)
        else
            local newItem <const> = ITEM:Register(itemData)
            PLAYER_INVENTORY.ITEMS[itemId] = newItem
        end
        NUI_SERVICE.INVENTORY.UPDATE_ITEM(itemId)
    end,

    SUB_ITEM = function(id, qty)
        local item <const> = PLAYER_INVENTORY.ITEMS[id]
        if not item then return end

        item:setCount(qty)
        if item:getCount() == 0 then
            PLAYER_INVENTORY.ITEMS[id] = nil
            NUI_SERVICE.SHARED.REMOVE(id, item.type)
        else
            NUI_SERVICE.INVENTORY.UPDATE_ITEM(id)
        end
    end,

    SET_ITEM_METADATA = function(id, metadata)
        local item <const> = PLAYER_INVENTORY.ITEMS[id]
        if not item then return end

        item:setMetadata(metadata)
        NUI_SERVICE.INVENTORY.UPDATE_ITEM(id)
    end,

    SET_ITEM_DURABILITY = function(id, durability)
        local item <const> = PLAYER_INVENTORY.ITEMS[id]
        if not item then return end
        item:setDurability(durability)
        NUI_SERVICE.INVENTORY.UPDATE_ITEM(id)
    end,

    SUB_WEAPON = function(weaponId)
        local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
        if weapon then
            if weapon:getUsed() then
                weapon:UnequipWeapon(true)
            end
            PLAYER_INVENTORY.WEAPONS[weaponId] = nil
        end
        NUI_SERVICE.SHARED.REMOVE(weaponId, "item_weapon")
    end,

    SUB_WEAPON_BULLETS = function(weaponId, bulletType, qty)
        local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
        if weapon then
            weapon:subAmmo(bulletType, qty)
            if weapon:getUsed() then
                SetPedAmmoByType(CACHE.Ped, joaat(bulletType), weapon:getAmmo(bulletType))
            end
        end
        NUI_SERVICE.INVENTORY.UPDATE_WEAPON(weaponId)
    end,

    ADD_COMPONENT = function(weaponId, component, category)
        local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
        if not weapon then
            if PUP_TRACE_COMPONENTS then print(("^1[comps-sync]^7 addComponent: weapon %s NOT IN CLIENT CACHE - %s lost"):format(tostring(weaponId), tostring(component))) end
            return
        end

        weapon:addComponent(component, category)
        NUI_SERVICE.INVENTORY.UPDATE_WEAPON(weaponId)
    end,
    ADD_COMPONENTS = function(weaponId, components)
        local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
        if not weapon then
            if PUP_TRACE_COMPONENTS then print(("^1[comps-sync]^7 addComponents: weapon %s NOT IN CLIENT CACHE - push lost"):format(tostring(weaponId))) end
            return
        end
        for category, component in pairs(components) do
            weapon:addComponent(component, category)
        end
        if PUP_TRACE_COMPONENTS then
            local n = 0
            for _ in pairs(weapon:getAllComponents() or {}) do n = n + 1 end
            print(("^3[comps-sync]^7 addComponents: weapon %s client map now %d categories"):format(tostring(weaponId), n))
        end
        -- RE-RUN THE ORDERED APPLIER
        if weapon:getUsed() or weapon:getUsed2() then
            weapon:loadComponents(true)
        end
        NUI_SERVICE.INVENTORY.UPDATE_WEAPON(weaponId)
    end,

    SUB_COMPONENT = function(weaponId, component, category)
        local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
        if not weapon then
            if PUP_TRACE_COMPONENTS then print(("^1[comps-sync]^7 subComponent: weapon %s NOT IN CLIENT CACHE"):format(tostring(weaponId))) end
            return
        end

        weapon:removeComponent(component, category)
        NUI_SERVICE.INVENTORY.UPDATE_WEAPON(weaponId)
    end,

    SUB_COMPONENTS = function(weaponId, components)
        local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
        if not weapon then
            if PUP_TRACE_COMPONENTS then print(("^1[comps-sync]^7 subComponents: weapon %s NOT IN CLIENT CACHE"):format(tostring(weaponId))) end
            return
        end
        for category, component in pairs(components) do
            weapon:removeComponent(component, category)
        end
        NUI_SERVICE.INVENTORY.UPDATE_WEAPON(weaponId)
    end,

    -- wholesale re-sync from server truth. pup-weaponsV2 echoes the authoritative comps map back on every equip, so
    -- if an earlier incremental push was lost the map self-heals here, and the
    -- ordered/gated loadComponents applier re-runs while the weapon is out
    SET_COMPONENTS = function(weaponId, components)
        local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
        if not weapon then
            if PUP_TRACE_COMPONENTS then print(("^1[comps-sync]^7 setComponents: weapon %s NOT IN CLIENT CACHE - echo lost"):format(tostring(weaponId))) end
            return
        end
        local map <const> = weapon.components
        local had = 0
        for k in pairs(map) do had = had + 1; map[k] = nil end
        local now = 0
        for k, v in pairs(components or {}) do now = now + 1; map[k] = v end
        if PUP_TRACE_COMPONENTS then
            print(("^3[comps-sync]^7 setComponents: weapon %s map %d -> %d categories (equipped=%s)"):format(
                tostring(weaponId), had, now, tostring(weapon:getUsed() or weapon:getUsed2())))
        end
        if weapon:getUsed() or weapon:getUsed2() then
            weapon:loadComponents()
        end
        NUI_SERVICE.INVENTORY.UPDATE_WEAPON(weaponId)
    end,
}

INVENTORY_API_SERVICE = InventoryApi
