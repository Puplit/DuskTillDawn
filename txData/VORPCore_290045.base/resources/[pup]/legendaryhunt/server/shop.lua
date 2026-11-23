-- legendaryhunt | server: the trapper's buy and sell counter
-- Item lists and prices come from the server's own copy of config/shop.lua; the client only names an item.

local function nearTrapper(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = Config.Trapper.coords
    return #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= (tonumber(Config.Trapper.serverRange) or 10.0)
end

local function money(v)
    v = tonumber(v) or 0
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return ('%.2f'):format(v)
end

-- pup-misc Eco Boost extra on a trapper sale; 0 when pup-misc is missing or fails
local function ecoExtra(src, price)
    local res = Config.Integrations.ecoBoost
    if GetResourceState(res) ~= 'started' then return 0 end
    local ok, extra = pcall(function()
        return exports[res]:ApplyEcoBoostSale(src, Config.Integrations.ecoBoostPlace, price)
    end)
    if not ok then
        Srv.warnOnce('eco', ('%s ApplyEcoBoostSale failed: %s'):format(res, tostring(extra)))
        return 0
    end
    extra = tonumber(extra) or 0
    if extra ~= extra or extra < 0 then return 0 end
    return extra
end

RegisterNetEvent('legendaryhunt:buy', function(item)
    local src = source
    if not Srv.valid(src) or type(item) ~= 'string' or not Srv.allow(src, 'shop', 500) then return end
    local row = Rules.buy[item]
    if not row or not nearTrapper(src) then return end
    local char = Srv.character(src)
    if not char then return end
    local cid, price = char.charIdentifier, row.price

    if (tonumber(char.money) or 0) < price then
        Srv.tip(src, Rules.text('noMoneyBuy') .. money(price))
        return
    end
    if not Srv.canCarry(src, item, 1) then
        Srv.tip(src, Rules.text('trapLimit'))
        return
    end

    char.removeCurrency(0, price)
    local added = Srv.giveItem(src, item, 1)
    -- re-check after the inventory await before deciding on a refund
    local now = Srv.character(src)
    if added then
        Srv.tip(src, Rules.text('bought'))
    elseif now and now.charIdentifier == cid then
        now.addCurrency(0, price)
        Srv.tip(src, Rules.text('trapLimit'))
    else
        -- switched or left mid-sale: refund the character that paid
        char.addCurrency(0, price)
    end
end)

RegisterNetEvent('legendaryhunt:sell', function(item)
    local src = source
    if not Srv.valid(src) or type(item) ~= 'string' or not Srv.allow(src, 'shop', 500) then return end
    local row = Rules.sell[item]
    if not row or not nearTrapper(src) then return end
    local char = Srv.character(src)
    if not char then return end
    local cid = char.charIdentifier

    if not Srv.subItem(src, item, 1) then
        Srv.tip(src, Rules.text('noItemSell') .. ' ' .. row.label)
        return
    end
    -- pay the character whose item was taken, even if they switched during the await
    local total = row.price + ecoExtra(src, row.price)
    local now = Srv.character(src)
    local payee = (now and now.charIdentifier == cid) and now or char
    payee.addCurrency(0, total)
    if payee == now then Srv.tip(src, Rules.text('itemSold') .. money(total)) end
end)
