-- Modified by Puppet (Dusk Till Dawn), 2026
local Lib <const> = Import "/config"
local Config <const> = Lib.Config --[[@as vorp_herbs_config]]
local Core <const> = exports.vorp_core:GetCore()
local CoordsLooted <const> = {}
local PropsLooted <const> = {}

local function coordsKey(coords)
    return string.format("%.3f_%.3f_%.3f", coords.x, coords.y, coords.z)
end

-- The cooldown is kept here and broadcast, so clients hide a picked plant's
-- prompt and bush instead of only refusing on press.
local function broadcast(key, spent)
    TriggerClientEvent("vorp_herbs:setState", -1, key, spent)
end

RegisterNetEvent("vorp_herbs:requestState", function()
    local out <const> = {}
    for k in pairs(CoordsLooted) do out[#out + 1] = k end
    TriggerClientEvent("vorp_herbs:fullState", source, out)
end)

Core.Callback.Register("vorp_herbs:CheckItemsCapacity", function(source, callback, key, plantCoords, isProp)
    local _source = source
    local itemsToGive <const> = {}

    local value <const> = Config.Plants[key]
    if not value then
        return callback(false)
    end

    -- Anti-cheat: Distance validation
    local playerPed = GetPlayerPed(_source)
    local playerCoords = GetEntityCoords(playerPed)
    local dist = #(playerCoords - plantCoords)

    if dist > 10.0 then
        print(string.format("[vorp_herbs] Player %s (ID: %s) tried to loot plant from far distance (Distance: %.2f)!", GetPlayerName(_source), _source, dist))
        return callback(false)
    end

    if isProp then
        local propKey <const> = coordsKey(plantCoords)
        if PropsLooted[propKey] then
            return callback(false, true)
        end
    else
        if CoordsLooted[key] then
            return callback(false, true)
        end
    end

    -- a Farmer's Pack takes the crop when the satchel is full or filtered to it
    local function packTakes(name, count)
        if GetResourceState('pup-misc') ~= 'started' then return false end
        local ok, can = pcall(function()
            return exports['pup-misc']:PackCanStore(_source, "farming", name, count)
        end)
        return ok and can == true
    end

    local rewardAmount <const> = math.random(value.minReward, value.maxReward)
    for _, rewardItem in ipairs(value.reward) do
        local canCarryItem <const> = exports.vorp_inventory:canCarryItem(_source, rewardItem, rewardAmount)
        -- the pack is checked too, or a full satchel drops the pick entirely
        if canCarryItem or packTakes(rewardItem, rewardAmount) then
            local iteminfo <const> = exports.vorp_inventory:getItemDB(rewardItem)
            table.insert(itemsToGive, { name = rewardItem, count = rewardAmount, label = iteminfo.label })
        end
    end

    if #itemsToGive > 0 then
        for _, item in ipairs(itemsToGive) do
            local packed, packLabel = false, nil
            pcall(function()
                if GetResourceState('pup-misc') == 'started' then
                    packed, packLabel = exports['pup-misc']:PackStore(_source, "farming", item.name, item.count)
                end
            end)
            if packed then
                Core.NotifyRightTip(_source, Config.Language.yougot .. item.count .. "x " .. item.label
                    .. " - packed into your " .. tostring(packLabel or "pack"), 4000)
            elseif exports.vorp_inventory:canCarryItem(_source, item.name, item.count) then
                exports.vorp_inventory:addItem(_source, item.name, item.count)
                Core.NotifyRightTip(_source, Config.Language.yougot .. item.count .. "x " .. item.label, 4000)
            else
                Core.NotifyRightTip(_source, Config.Language.noenoughspace, 4000)
            end
        end
        table.wipe(itemsToGive)
        if isProp then
            local propKey <const> = coordsKey(plantCoords)
            PropsLooted[propKey] = true
            SetTimeout(value.cooldown * 60000, function()
                PropsLooted[propKey] = nil
            end)
        else
            CoordsLooted[key] = true
            broadcast(key, true)
            SetTimeout(value.cooldown * 60000, function()
                CoordsLooted[key] = nil
                broadcast(key, false)
            end)
        end
        return callback(true)
    end

    return callback(false)
end)
