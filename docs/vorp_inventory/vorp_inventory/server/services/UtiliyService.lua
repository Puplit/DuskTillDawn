-- PROCESSING USERS MAKING TRANSACTIONS
local PROCESSING_USERS <const> = {}
-- Cosmetic metadata keys that must never split a stack. They are ignored when MATCHING an
-- incoming item against an existing stack, but are still written and kept on the row itself,
-- so an item that does not merge keeps its description.
local COSMETIC_META <const> = { description = true, orgdescription = true }

-- a copy with the cosmetic keys removed; used for comparison only, never for storage
local function stripCosmetic(svItem, metadata)
    if type(metadata) ~= "table" or not next(metadata) then return metadata end
    local out, dropped = {}, false
    for k, v in pairs(metadata) do
        -- a label that only repeats the item's own label is noise too
        if COSMETIC_META[k] or (k == "label" and svItem and v == svItem:getLabel()) then
            dropped = true
        else
            out[k] = v
        end
    end
    if not dropped then return metadata end
    return out
end

math.randomseed(GetGameTimer())
local SvUtils = {

    GENERATE_UNIQUE_ID = function()
        local time = os.time()
        local randomNum = math.random(1000000, 9999999)
        return tostring(time) .. tostring(randomNum)
    end,

    DISCORD_LOG = function(data)
        if not data.webhook or data.webhook == "" then return end

        -- field-per-fact embeds; the caller's own body rides along as Details
        if PUP_INVLOG then
            return PUP_INVLOG.Send(data)
        end
        CORE.AddWebhook(data.title, data.webhook, data.description, data.color, data.name)
    end,

    WEAPONS = {
        GET_ALL_BY_NAME = function(invId, name)
            local userWeapons <const> = USERS_WEAPONS[invId]
            local weapons <const> = {}

            if userWeapons == nil then
                return {}
            end

            for _, weapon in pairs(userWeapons) do
                if name == weapon:getName() then
                    weapons[#weapons + 1] = weapon
                end
            end

            return weapons
        end,

        GENERATE_WEAPON_LABEL = function(name)
            return SHARED_DATA.WEAPONS[name] and SHARED_DATA.WEAPONS[name].Name or ""
        end,

        FILTER_WEAPONS_SERIAL_NUMBER = function(name)
            return SHARED_DATA.WEAPONS[name] and SHARED_DATA.WEAPONS[name].NoSerialNumber
        end,
        GENERATE_SERIAL_NUMBER = function(name)
            if SV_UTILS.WEAPONS.FILTER_WEAPONS_SERIAL_NUMBER(name) then
                return ""
            end
            local timeStamp = os.time()
            local randomNumber = math.random(1000, 9999)
            return string.format("%s-%s", timeStamp, randomNumber)
        end,
        GET_WEAPON_WEIGHT = function(name)
            local weaponName = nil
            if type(name) == "number" then
                for _, value in pairs(SHARED_DATA.WEAPONS) do
                    if joaat(value.HashName) == name then
                        weaponName = value.HashName
                        break
                    end
                end
            else
                weaponName = name
            end
            return SHARED_DATA.WEAPONS[weaponName] and SHARED_DATA.WEAPONS[weaponName].Weight or 1
        end,
    },
    ITEMS = {
        GET_ALL_BY_NAME = function(invId, identifier, name)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            local items <const> = {}

            if not userInventory then
                return items
            end

            for _, item in pairs(userInventory) do
                if name == item:getName() then
                    items[#items + 1] = item
                end
            end

            return items
        end,

        GET_ITEM = function(invId, identifier, name)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not userInventory then return nil end

            for _, item in pairs(userInventory) do
                if name == item:getName() then
                    return item
                end
            end

            return nil
        end,

        GET_ITEM_BY_METADATA = function(invId, identifier, name, metadata)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not userInventory then
                return nil
            end

            if metadata then
                for _, item in pairs(userInventory) do
                    if name == item:getName() and SHARED_UTILS.TABLE_EQUALS(metadata, item:getMetadata()) then
                        return item
                    end
                end
            else
                -- this returns the first item that matches the name, not carring for metadata
                for _, item in pairs(userInventory) do
                    if name == item:getName() then
                        return item
                    end
                end
            end

            return nil
        end,

        -- Stack lookup for the ADD paths. Cosmetic keys are ignored on BOTH sides, so a described
        -- item joins a plain stack and vice versa. The row that is found keeps its own metadata -
        -- only the units merging into it take on the destination's description.
        GET_ITEM_FOR_STACKING = function(invId, identifier, name, metadata, svItem)
            local inv <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not inv then return nil end

            local want <const> = stripCosmetic(svItem, metadata or {}) or {}
            for _, item in pairs(inv) do
                if name == item:getName() then
                    local have <const> = stripCosmetic(svItem, item:getMetadata() or {}) or {}
                    if SHARED_UTILS.TABLE_EQUALS(want, have) then return item end
                end
            end
            return nil
        end,
        GET_ITEM_NO_METADATA = function(invId, identifier, name)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not userInventory then return nil end

            for _, item in pairs(userInventory) do
                if name == item:getName() and not next(item:getMetadata()) then
                    return item
                end
            end

            return nil
        end,

        GET_ITEM_COUNT = function(invId, identifier, name, percentage)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]

            if not userInventory then return 0 end

            --get item count  by percentage , this allows to control get expired items or at a desired percentage
            local count = 0
            for _, item in pairs(userInventory) do
                if percentage then
                    local expiredPercentage = true
                    -- items with decay detection
                    if percentage == 0 then
                        expiredPercentage = item:getPercentage() == 0
                    else
                        expiredPercentage = item:getPercentage() >= percentage
                    end

                    if name == item:getName() and expiredPercentage then
                        count = count + item:getCount()
                    end
                else
                    -- detect any items because if we change this it breaks other scripts that are using it wrong
                    if name == item:getName() then
                        -- by not allowing decay items in here we are getting the count of only normal items
                        -- in conjunction with subItem that will only delete items that dont have decay if decay detection is not passed this allows to function normal as before
                        count = count + item:getCount()
                    end
                end
            end

            return count
        end,

        GET_ITEM_MATCHING_METADATA = function(invId, identifier, name, metadata)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not userInventory then return nil end

            for _, item in pairs(userInventory) do
                if name == item:getName() and SHARED_UTILS.TABLE_CONTAINS(item:getMetadata(), metadata) then
                    return item
                end
            end

            return nil
        end,

        DOES_ITEM_EXIST = function(itemName, api)
            if SERVER_ITEMS[itemName] then
                return SERVER_ITEMS[itemName]
            end
            print("[^2" .. api .. "7^] Item [^3" .. tostring(itemName) .. "^7] does not exist in DB.")
            return false
        end,

        -- Kept for callers that want the stripped form. Storage paths must NOT use this on the
        -- value they save, or a description is destroyed even when nothing merges.
        STRIP_REDUNDANT_METADATA = function(svItem, metadata)
            return stripCosmetic(svItem, metadata)
        end,
    },

    PROCESS = {
        ADD_USER = function(id)
            PROCESSING_USERS[id] = true
        end,
        USER_IN_PROCESSING = function(id)
            return PROCESSING_USERS[id]
        end,
        REMOVE_USER = function(id)
            PROCESSING_USERS[id] = nil
            TriggerClientEvent("vorp_inventory:ProcessingReady", id)
        end,
    }
}

SV_UTILS      = SvUtils


AddEventHandler("playerDropped", function()
    local _source = source
    PROCESSING_USERS[_source] = nil
end)
