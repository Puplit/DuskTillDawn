-- pup_gunsmith | gun store counters

local counterById = {}
for _, c in ipairs(Config.ShopCounters) do counterById[c.id] = c end

local function stockOf(counter)
    return counter.stock or Config.ShopStock
end

local function findStock(counter, kind, group, label)
    for _, s in ipairs(stockOf(counter)) do
        if s.kind == kind and s.group == group and s.label == label then return s end
    end
    return nil
end

Srv.rpc('shopOpen', function(src, char, counterId)
    if not Config.Shop.enabled then return { ok = false } end
    local counter = counterById[counterId]
    if not counter then return { ok = false } end
    if not Srv.near(src, counter.coords, Config.Shop.reach) then
        return { ok = false, msg = L('stand_counter') }
    end
    Srv.st(src, char).shop = counter.id
    return { ok = true, cash = tonumber(char.money) or 0 }
end, { throttle = 500 })

Srv.rpc('shopBuy', function(src, char, kind, group, label, amount)
    local st = Srv.st(src, char)
    local counter = st.shop and counterById[st.shop]
    if not counter or not Config.Shop.enabled then return { ok = false, msg = L('stand_counter'), cash = Srv.cash(src) } end
    if not Srv.near(src, counter.coords, Config.Shop.reach) then
        return { ok = false, msg = L('stand_counter'), cash = Srv.cash(src) }
    end
    if (kind ~= 'weapon' and kind ~= 'ammo') or type(group) ~= 'string' or type(label) ~= 'string' then
        return { ok = false, msg = L('shop_not_sold'), cash = Srv.cash(src) }
    end
    local entry = findStock(counter, kind, group, label)
    if not entry then return { ok = false, msg = L('shop_not_sold'), cash = Srv.cash(src) } end

    local n = 1
    if kind == 'ammo' then
        n = GS.int(amount)
        if not n or n < 1 or n > Config.Shop.maxAmount or n ~= tonumber(amount) then
            return { ok = false, msg = L('invalid_amount'), cash = Srv.cash(src) }
        end
    end

    local total = (tonumber(entry.price) or 0) * n
    total = math.floor(total * 100 + 0.5) / 100
    if Srv.cash(src) + 1e-9 < total then
        return { ok = false, msg = L('no_money'), cash = Srv.cash(src) }
    end

    if kind == 'weapon' then
        local weapon = entry.weapon:upper()
        local okC, can = pcall(function() return Inv:canCarryWeapons(src, 1, nil, weapon) end)
        if not okC or not can then return { ok = false, msg = L('cant_carry_weapon'), cash = Srv.cash(src) } end
        if total > 0 and not Srv.takeMoney(src, 0, total) then
            return { ok = false, msg = L('no_money'), cash = Srv.cash(src) }
        end
        local okW, made = pcall(function() return Inv:createWeapon(src, weapon, {}, {}, {}) end)
        if not okW or made ~= true then
            Srv.giveMoney(src, 0, total)
            return { ok = false, msg = L('cant_carry_weapon'), cash = Srv.cash(src) }
        end
        return { ok = true, msg = L('shop_bought_weapon', entry.label), cash = Srv.cash(src) }
    end

    local okC, can = pcall(function() return Inv:canCarryItem(src, entry.item, n) end)
    if not okC or not can then return { ok = false, msg = L('cant_carry_items'), cash = Srv.cash(src) } end
    if total > 0 and not Srv.takeMoney(src, 0, total) then
        return { ok = false, msg = L('no_money'), cash = Srv.cash(src) }
    end
    local okA, added = pcall(function() return Inv:addItem(src, entry.item, n) end)
    if not okA or added == false then
        Srv.giveMoney(src, 0, total)
        return { ok = false, msg = L('cant_carry_items'), cash = Srv.cash(src) }
    end
    return { ok = true, msg = L('shop_bought_ammo', n, entry.label), cash = Srv.cash(src) }
end, { exclusive = true, throttle = 250 })

RegisterNetEvent('pup_gunsmith:shopLeave', function()
    local src = source
    local st = Srv.state[src]
    if st then st.shop = nil end
end)

Srv.onReset(function(_, st) st.shop = nil end)
