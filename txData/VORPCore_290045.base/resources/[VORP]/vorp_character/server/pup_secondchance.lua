-- Modified by Puppet (Dusk Till Dawn), 2026
-- second chance as a usable item

-- [src] = true while in an item-funded second chance; global for server.lua's CanProcceed
SECOND_CHANCE_BY_ITEM = {}

local Core <const> = exports.vorp_core:GetCore() -- server.lua's Core is local to that file
local ITEM <const> = tostring(Config.Shops.secondChance.item or "")

if ITEM ~= "" then
    CreateThread(function()
        -- vorp_inventory registers usable items through vorp_core's event
        while GetResourceState('vorp_inventory') ~= 'started' do Wait(250) end
        Wait(500)

        TriggerEvent("vorpCore:registerUsableItem", ITEM, function(data)
            local src <const> = data.source

            -- close the inventory first, or the creator opens behind it
            pcall(function() exports.vorp_inventory:closeInventory(src) end)
            TriggerClientEvent("vorp_inventory:CloseInv", src)

            local user <const> = Core.getUser(src)
            if not user then return end
            local character <const> = user.getUsedCharacter
            if not character or not character.charIdentifier then return end

            if SECOND_CHANCE_BY_ITEM[src] then
                Core.NotifyRightTip(src, "You are already making a change.", 4000)
                return
            end

            -- repeated here: the item route never reaches CanPayForSecondChance
            if SecondChanceBlocked and SecondChanceBlocked(src, character, "item use") then
                return
            end

            -- not consumed here: SecondChanceTakeItem does that on confirm
            SECOND_CHANCE_BY_ITEM[src] = true
            TriggerClientEvent('vorp_character:openWardrobe', src, "secondchance")
        end)

        print(("^2[vorp_character]^7 second chance item registered: '%s'"):format(ITEM))
    end)
end

-- consume the item that funded this session
function SecondChanceTakeItem(src)
    if not SECOND_CHANCE_BY_ITEM[src] then return false end
    if ITEM == "" then return false end

    local ok, count = pcall(function()
        return exports.vorp_inventory:getItemCount(src, nil, ITEM)
    end)
    if not ok or (tonumber(count) or 0) < 1 then
        SECOND_CHANCE_BY_ITEM[src] = nil
        Core.NotifyRightTip(src, "You no longer have that item.", 4000)
        return false
    end

    pcall(function() exports.vorp_inventory:subItem(src, ITEM, 1) end)
    SECOND_CHANCE_BY_ITEM[src] = nil
    return true
end

-- source ids are recycled, so a mid-change disconnect must clear the flag
AddEventHandler('playerDropped', function()
    SECOND_CHANCE_BY_ITEM[source] = nil
end)

-- fired when the creator is closed without confirming
RegisterNetEvent('vorp_character:server:secondChanceCancelled', function()
    SECOND_CHANCE_BY_ITEM[source] = nil
end)
