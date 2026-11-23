-- huntingbirds | shop: opening, buying, selling back to the shop

local function shopAllowed(src, char, shopIndex)
    local shop = Config.Shops[shopIndex]
    if not shop then return nil, 'unknown shop' end
    if not Srv.near(src, shop.coords, tonumber(Config.Shop.useDistance) or 5.0) then return nil, 'too far from the shop' end
    if shop.jobRequired and not Srv.hasJob(char, shop.jobs) then return nil, 'job' end
    return shop
end

RegisterNetEvent('huntingbirds:checkmenujob', function(shopIndex)
    local src = source
    shopIndex = Util.int(shopIndex, 1)
    local char = Srv.char(src)
    if not shopIndex or not char then return end
    if not Srv.throttle(src, 'shop', 1000) then return end
    Srv.session(src, char)
    local shop, why = shopAllowed(src, char, shopIndex)
    if not shop then
        if why == 'job' then Srv.notify(src, Locale.noJob, 'red') else Srv.dbg('src=%d shop %d refused: %s', src, shopIndex, why) end
        return
    end
    TriggerClientEvent('huntingbirds:openshop', src, shopIndex)
end)

-- trim, drop control and markup characters, collapse spaces; nil when not 1..32 characters
local function cleanName(raw)
    if type(raw) ~= 'string' then return nil end
    local s = raw:gsub('%c', ' '):gsub('[<>@`*_~|\\]', ''):gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')
    local len = utf8.len(s)
    if not len or len < 1 or len > 32 then return nil end
    return s
end

RegisterNetEvent('huntingbirds:buybird', function(shopIndex, categoryIndex, variantIndex, name)
    local src = source
    local char = Srv.char(src)
    if not char then return end
    if not Srv.throttle(src, 'buy', 2000) then return end
    Srv.session(src, char)

    shopIndex, categoryIndex, variantIndex = Util.int(shopIndex, 1), Util.int(categoryIndex, 1), Util.int(variantIndex, 1)
    local cat, variant = nil, nil
    if categoryIndex and variantIndex then cat, variant = Util.variant(categoryIndex, variantIndex) end
    if not shopIndex or not variant then
        BirdLog.refused(src, char, 'buy bird', ('unknown shop/variant %s/%s/%s'):format(tostring(shopIndex), tostring(categoryIndex), tostring(variantIndex)))
        return
    end
    local shop, why = shopAllowed(src, char, shopIndex)
    if not shop then
        if why == 'job' then Srv.notify(src, Locale.noJob, 'red') else Srv.dbg('src=%d buy refused: %s', src, why) end
        return
    end

    local clean = cleanName(name)
    if not clean then
        Srv.notify(src, Locale.invalidName, 'red')
        return
    end

    local price = Util.finalPrice(shop, variant)
    if price < 0 then return end
    if (tonumber(char.money) or 0) < price then
        Srv.notify(src, Locale.shopNoMoney, 'red')
        return
    end

    char.removeCurrency(0, price)
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO `birds` (`identifier`, `charid`, `model`, `name`, `preset`, `xp`, `price`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { char.identifier, char.charIdentifier, Util.s32(variant.model), clean, variant.preset, variant.startXp, price })
    if not ok or not id then
        local again = Srv.char(src)
        if again and again.charIdentifier == char.charIdentifier then again.addCurrency(0, price) end
        print(('^1[%s]^7 saving a bought bird failed: %s'):format(GetCurrentResourceName(), tostring(id)))
        Srv.notify(src, Locale.error, 'red')
        return
    end

    Srv.notify(src, Locale.birdBought, 'gold')
    local odd = price < (tonumber(variant.price) or 0)
    BirdLog.post(src, odd and 'Bird bought - needs a check (price under base)' or 'Bird bought', odd and 'red' or 'green', {
        { 'Player', BirdLog.who(src, char) },
        { 'Shop', shop.name },
        { 'Bird', ('%s (%s, %s)'):format(BirdLog.clean(clean), variant.name, cat.name) },
        { 'Price', '$' .. Util.money(price) },
        { 'Bird ID', id },
    })
end)

-- sell back to the shop: the row is deleted first and paid only if that worked
RegisterNetEvent('huntingbirds:DeleteBird', function(birdId)
    local src = source
    local char = Srv.char(src)
    if not char then return end
    birdId = Util.int(birdId, 1)
    if not birdId then
        BirdLog.refused(src, char, 'sell back', 'bad bird id')
        return
    end
    if not Srv.throttle(src, 'sellback', 2000) then return end
    local s = Srv.session(src, char)
    if s.activeBird == birdId or Srv.points[birdId] then
        Srv.notify(src, Locale.sendHomeFirst, 'red')
        return
    end
    local row = Srv.ownedRow(char, birdId)
    if not row then
        BirdLog.refused(src, char, 'sell back', ('bird %d is not theirs'):format(birdId))
        return
    end

    local ok, affected = pcall(MySQL.update.await,
        'DELETE FROM `birds` WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
        { birdId, char.identifier, char.charIdentifier })
    if not ok or tonumber(affected) ~= 1 then
        BirdLog.post(src, 'Sell-back needs a check', 'red', {
            { 'Player', BirdLog.who(src, char) },
            { 'Bird ID', birdId },
            { 'Detail', 'no row was removed; nothing paid' },
        })
        return
    end

    local amount = Srv.sellValue(row.price)
    local now = Srv.char(src)
    if amount > 0 and now and now.charIdentifier == char.charIdentifier then now.addCurrency(0, amount) end
    Srv.notify(src, Locale.soldBird:format(Util.money(amount)), 'gold')
    BirdLog.post(src, 'Bird sold back', 'blue', {
        { 'Player', BirdLog.who(src, char) },
        { 'Bird', ('%s (ID %d)'):format(BirdLog.clean(row.name), birdId) },
        { 'Paid', '$' .. Util.money(amount) },
    })
end)
