-- Registers one custom inventory per bin and wipes them all on start.

local function invId(key)
    return 'pup_trash_' .. tostring(key)
end

local byId = {}   -- inventory id -> can

local function registerCan(can)
    local id <const> = invId(can.id)
    byId[id] = can

    -- custom inventories persist in the database, so delete before registering
    if Config.General.wipeOnStart then
        pcall(function() exports.vorp_inventory:deleteCustomInventory(id) end)
    end

    exports.vorp_inventory:registerInventory({
        id                   = id,
        name                 = Config.Bins.label,
        limit                = tonumber(Config.Bins.slots) or 50,
        acceptWeapons        = false,
        shared               = true,
        ignoreItemStackLimit = true,
        UseBlackList         = true,
        whitelistItems       = false,
    })

    for _, name in ipairs(Config.Blacklist.items or {}) do
        pcall(function() exports.vorp_inventory:BlackListCustomAny(id, name) end)
    end
end

-- BlackListCustomAny only takes exact names, so prefixes are expanded from the items table.
local function blacklistPrefixes()
    local prefixes = Config.Blacklist.prefixes or {}
    if #prefixes == 0 then return end

    local where, args = {}, {}
    for _, p in ipairs(prefixes) do
        where[#where + 1] = 'item LIKE ?'
        args[#args + 1] = p .. '%'
    end

    exports.oxmysql:execute('SELECT item FROM items WHERE ' .. table.concat(where, ' OR '), args, function(rows)
        local n = 0
        for _, row in ipairs(rows or {}) do
            local name = row.item
            if name then
                n = n + 1
                for id in pairs(byId) do
                    pcall(function() exports.vorp_inventory:BlackListCustomAny(id, name) end)
                end
            end
        end
        print(('^2[pup-trash]^7 %d prefixed item(s) blocked from the bins'):format(n))
    end)
end

CreateThread(function()
    while GetResourceState('vorp_inventory') ~= 'started' do Wait(500) end
    Wait(3000)
    for _, can in ipairs(Config.BinLocations or {}) do
        registerCan(can)
    end
    print(('^2[pup-trash]^7 %d bin(s) registered, emptied for this restart'):format(#(Config.BinLocations or {})))
    blacklistPrefixes()
end)

RegisterServerEvent('pup-trash:open')
AddEventHandler('pup-trash:open', function(key)
    local src = source
    local id <const> = invId(key)
    local can = byId[id]
    if not can then return end

    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local reach <const> = (tonumber(Config.Bins.promptRadius) or 2.0) + 1.5
    if #(GetEntityCoords(ped) - can.coords) > reach then
        return TriggerClientEvent('vorp:TipRight', src, Locale.toofar, 4000)
    end

    exports.vorp_inventory:openInventory(src, id, true)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(byId) do
        pcall(function() exports.vorp_inventory:removeInventory(id) end)
    end
end)
