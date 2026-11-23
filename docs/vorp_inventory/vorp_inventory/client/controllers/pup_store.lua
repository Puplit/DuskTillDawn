-- store owner tools that live in the shop grid (html/js/pup_store.js)
RegisterNUICallback("PupStoreToggleSale", function(data, cb)
    if cb then cb("ok") end
    if type(data) ~= "table" or data.id == nil then return end
    TriggerServerEvent("pup_mercantile:togglesale", data.id, tostring(data.type or "item_standard"))
end)

RegisterNUICallback("PupStoreSetPrice", function(data, cb)
    if cb then cb("ok") end
    if type(data) ~= "table" or data.id == nil then return end
    local price = tonumber(data.price)
    if not price then return end
    TriggerServerEvent("pup_mercantile:setprice", data.id, tostring(data.type or "item_standard"), price)
end)

-- Box trade from the grid. pup_mercantile decides the venue from the open session,
-- so a forged store id buys nothing.
RegisterNUICallback("PupStoreBuyIntoBox", function(data, cb)
    if cb then cb("ok") end
    if type(data) ~= "table" then return end
    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 or data.boxItemId == nil then return end
    TriggerServerEvent("pup_mercantile:box:gridBuy", data.store, tonumber(data.boxItemId),
        data.rowId, tostring(data.rowName or ""), amount)
end)

RegisterNUICallback("PupStoreSellBox", function(data, cb)
    if cb then cb("ok") end
    if type(data) ~= "table" or data.boxItemId == nil then return end
    TriggerServerEvent("pup_mercantile:box:gridSell", data.store, tonumber(data.boxItemId))
end)
