-- SHOW ITEM - relay for the held-up item card.
-- Re-checks that the player holds the item and re-reads its label, so a crafted
-- NUI post cannot show something they do not have, or rename it.

local CFG <const> = (CONFIG and CONFIG.SHOW_ITEM) or {}
local RANGE <const> = tonumber(CFG.RANGE) or 8.0
local COOLDOWN <const> = tonumber(CFG.COOLDOWN) or 3

local lastShow = {} -- src -> os.time of the last accepted show

-- false, or true plus the image key and label, resolved as the satchel resolves
-- them so a renamed or re-skinned item reads the same on the card
local function holdsItem(src, name)
    local okItem, item = pcall(function()
        return INVENTORY_API.MAIN.GET_ITEM(src, name)
    end)
    if okItem and item and (tonumber(item.count) or 0) > 0 then
        local meta = type(item.metadata) == 'table' and item.metadata or {}
        -- GET_ITEM already folded metadata.label into item.label
        return true, tostring(meta.image or name), tostring(item.label or name)
    end

    local character = CORE.getUser(src)?.getUsedCharacter
    if not character then return false end
    for _, weapon in pairs(USERS_WEAPONS.default or {}) do
        if weapon:getPropietary() == character.identifier and weapon:getName() == name then
            local custom = weapon.getCustomLabel and weapon:getCustomLabel() or nil
            local base   = weapon.getLabel and weapon:getLabel() or nil
            return true, name, tostring(custom or base or name)
        end
    end
    return false
end

RegisterServerEvent('vorp_inventory:pupShowItem')
AddEventHandler('vorp_inventory:pupShowItem', function(name)
    local _source <const> = source
    name = tostring(name or '')
    if name == '' then return end

    local now <const> = os.time()
    if lastShow[_source] and (now - lastShow[_source]) < COOLDOWN then return end

    -- the label and image come from the player's real item, never from the client
    if not SERVER_ITEMS[name] then return end
    local holds, image, label = holdsItem(_source, name)
    if not holds then return end
    lastShow[_source] = now

    local origin <const> = GetEntityCoords(GetPlayerPed(_source))

    for _, id in ipairs(GetPlayers()) do
        local target <const> = tonumber(id)
        local ped <const> = target and GetPlayerPed(target)
        if ped and ped ~= 0 and #(origin - GetEntityCoords(ped)) <= RANGE then
            TriggerClientEvent('vorp_inventory:pupShowItemSync', target, _source, image, label)
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastShow[source] = nil
end)
