-- Move one weapon out of a player's loadout into a container. MOVE_TO only ever
-- moves the caller's own, and USERS_WEAPONS / DB_SERVICE are internal, so a
-- seizure needs its own door. Modelled on the weapon branch of MOVE_TO.
---@return boolean ok, string|nil err
exports('seizeWeaponToCustomInventory', function(ownerSrc, weaponId, invId)
    ownerSrc = tonumber(ownerSrc)
    weaponId = tonumber(weaponId)
    invId    = tostring(invId or "")

    if not ownerSrc or not weaponId or invId == "" then return false, "bad arguments" end

    local inv <const> = CUSTOM_INVENTORIES[invId]
    if not inv then return false, "inventory not registered" end
    if not inv:doesAcceptWeapons() then return false, "inventory does not take weapons" end

    local character <const> = CORE.getUser(ownerSrc)?.getUsedCharacter
    if not character then return false, "owner has no character" end

    local weapon <const> = USERS_WEAPONS.default[weaponId]
    if not weapon then return false, "weapon is not in a satchel" end
    if tonumber(weapon.charId) ~= tonumber(character.charIdentifier) then
        return false, "weapon does not belong to that character"
    end

    USERS_WEAPONS[invId] = USERS_WEAPONS[invId] or {}

    local status <const> = weapon:getStatus() or {}
    DB_SERVICE.ASYNC.UPDATE(
        "UPDATE loadout SET identifier = '', curr_inv = @invId, degradation = @degradation, " ..
        "damage = @damage, dirt = @dirt, soot = @soot WHERE charidentifier = @charid AND id = @weaponId",
        {
            invId       = invId,
            charid      = character.charIdentifier,
            weaponId    = weaponId,
            degradation = status.degradation or 0.0,
            damage      = status.damage or 0.0,
            dirt        = status.dirt or 0.0,
            soot        = status.soot or 0.0,
        })

    weapon:setCurrInv(invId)
    USERS_WEAPONS[invId][weaponId] = weapon
    USERS_WEAPONS.default[weaponId] = nil

    -- unequips, drops it from their cache and clears the row from their UI
    TriggerClientEvent("vorpCoreClient:subWeapon", ownerSrc, weaponId)

    local row <const> = {
        id            = weaponId,
        name          = weapon:getName(),
        label         = weapon:getCustomLabel() or weapon:getLabel() or weapon:getName(),
        type          = "item_weapon",
        desc          = weapon:getCustomDesc() or weapon:getDesc(),
        serial_number = weapon:getSerialNumber(),
        custom_label  = weapon:getCustomLabel(),
        custom_desc   = weapon:getCustomDesc(),
        ammo          = weapon:getAllAmmo(),
        used          = weapon:getUsed(),
        used2         = weapon:getUsed2(),
    }
    for src, openId in pairs(INVENTORY_IN_USE) do
        if openId == invId then
            TriggerClientEvent("vorp_inventory:client:secondaryItemAdded", src, row)
        end
    end

    TriggerEvent("vorp_inventory:Server:OnItemMovedToCustomInventory", {
        id = weaponId, name = weapon:getName(), amount = 1,
        type = "item_weapon", serial = weapon:getSerialNumber(),
        label = weapon:getCustomLabel() or weapon:getLabel(),
    }, invId, ownerSrc)

    return true
end)
