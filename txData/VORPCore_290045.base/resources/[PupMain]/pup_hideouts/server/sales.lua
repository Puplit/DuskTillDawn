-- pup_hideouts | contraband sales to locals: bargaining, reports and the sting

local S <const> = Config.Sales
local B <const> = Config.Bargain
local ST <const> = Config.Sting

local sessions = {} -- [src] = haggle session
local stings = {}   -- [src] = armed sting { lawman = bool }
local lootback = {} -- [src] = { item, label, count, coords, expires }
local lastOffer = {}

local function gangsUp() return GetResourceState('pup-gangs') == 'started' end

local function gang(fnName, ...)
    if not gangsUp() then return nil end
    local f = Config.Integrations[fnName]
    if not f then return nil end
    local ok, v = pcall(f, ...)
    if ok then return v end
    U.warnIntegration(fnName, v)
    return nil
end

local function opt(item, key)
    local o = S.overrides[item]
    if o and o[key] ~= nil then return o[key] end
    if B[key] ~= nil then return B[key] end
    return B.fallback[key]
end

local function isLegal(item, isGang)
    if isGang then return false end
    local o = S.overrides[item]
    if o and o.legal ~= nil then return o.legal == true end
    return S.legal[item] == true
end

local function policeCount()
    local n = 0
    for _ in ipairs(HX.policeSources(S.minPoliceOnDuty)) do n = n + 1 end
    return n
end

-- what this player sells: the gang drug first, then the configured list in order
local function pickGoods(src)
    local g = gang('gangOffer', src)
    if type(g) == 'table' and type(g.item) == 'string' and (tonumber(g.price) or 0) > 0 then
        return { item = g.item, label = tostring(g.label or g.item), price = tonumber(g.price), have = tonumber(g.count) or 99, gang = true }
    end
    for _, r in ipairs(Config.Distill) do
        local price = tonumber(S.prices[r.resultitem]) or 0
        if price > 0 then
            local have = HX.itemCount(src, r.resultitem)
            if have > 0 then
                return { item = r.resultitem, label = r.label or HX.itemLabel(r.resultitem), price = price, have = have, gang = false }
            end
        end
    end
    return nil
end

local function rollReport(src, coords)
    if not S.report then return end
    local chance = S.reportChance - HX.perkBonus(src, 'sale_quiet')
    if chance > 0 and math.random(1, 100) <= chance then
        HX.radiusAlert(coords, L('sale_reported'), S.reportRadius)
    end
end

local function logSale(src, label, qty, paid, how, coords)
    local deal = how == 'haggled' and 'Haggled' or how == 'sting' and 'Sting' or 'Instant'
    Logs.send('Sales', 'Drug Sold', ('%s x%d'):format(label, qty), 'drugSold', src, {
        { 'Drug', label, true }, { 'Amount', tostring(qty), true }, { 'Paid', '$' .. U.money(paid), true },
        { 'Deal', deal, true }, { 'Position', ('%.1f, %.1f, %.1f'):format(coords.x, coords.y, coords.z), false },
    }, nil)
    TriggerEvent('pup_hideouts:drugsale_log', src, label, qty, paid, how, coords)
end

-- take the goods off the seller; returns the units actually taken
local function takeGoods(src, goods, qty)
    if goods.gang then
        return math.max(0, math.floor(tonumber(gang('gangTake', src, goods.item, qty)) or 0))
    end
    local have = HX.itemCount(src, goods.item)
    local n = math.min(have, qty)
    if n <= 0 then return 0 end
    if not HX.removeItem(src, goods.item, n) then return 0 end
    return n
end

-- the sting fires at the handover: nobody pays, the lawman keeps the goods
local function fireSting(src, sting, goods, taken, coords)
    local crooked = math.random(1, 100) <= ST.crookedChance
    local drank = crooked and math.min(taken, ST.crookedDrinks) or 0
    local carried = goods.gang and 0 or (taken - drank)
    if carried > 0 then
        lootback[src] = { item = goods.item, label = goods.label, count = carried, coords = coords, expires = os.time() + ST.lootMinutes * 60 }
    end
    if crooked then
        TriggerClientEvent('pup_hideouts:stingFire', src, 'crooked', Config.CrookedLines[math.random(#Config.CrookedLines)])
        logSale(src, ('CROOKED LAWMAN - %s (drank %d, %d on him)'):format(goods.label, drank, carried), taken, 0, 'sting', coords)
        return
    end
    TriggerClientEvent('pup_hideouts:stingFire', src, sting.lawman and 'lawman' or 'undercover', L('he_keeps', taken))
    local zone = HX.zoneName(coords)
    HX.policeAlert(coords, zone and (L('sting_alert') .. ' (' .. tostring(zone) .. ')') or L('sting_alert'))
    logSale(src, ('STING - %s (%s)'):format(goods.label, sting.lawman and 'uniformed lawman' or 'undercover buyer'), taken, 0, 'sting', coords)
end

local function award(src, goods, qty, paid, coords)
    if goods.gang then
        gang('gangSaleDone', src, goods.item, qty, paid, coords)
    end
    gang('gangBloodMoney', src, 'drugSale', paid)
    HX.perkAward(src, 'drugsale')
end

local function gangMult(src, goods, coords)
    if not goods.gang then return 1.0 end
    local m = tonumber(gang('gangMultiplier', src, coords))
    if not m or m <= 0 then return 1.0 end
    return m
end

----------------------------------------------------------------------------------------------------
-- an offer to a local
----------------------------------------------------------------------------------------------------
local LAWMEN = {}
for _, m in ipairs(Config.LawmanModels) do LAWMEN[joaat(m)] = true end

-- the client says whether the buyer wears a badge; when the ped is networked the server looks itself
local function lawmanBuyer(claimed, pedNet)
    pedNet = tonumber(pedNet)
    if pedNet and pedNet > 0 then
        local ent = NetworkGetEntityFromNetworkId(pedNet)
        if ent and ent ~= 0 and DoesEntityExist(ent) then return LAWMEN[GetEntityModel(ent)] == true end
    end
    return claimed == true
end

HX.rpc('saleOffer', function(src, isLawman, pedNet)
    if not S.enabled then return { kind = 'none' } end
    isLawman = lawmanBuyer(isLawman, pedNet)
    if S.minPolice ~= false and S.minPolice and S.minPolice > 0 and policeCount() < S.minPolice then
        HX.tip(src, L('not_enough_police'))
        return { kind = 'none' }
    end
    local now = os.time()
    if lastOffer[src] and now - lastOffer[src] < S.offerCooldown then return { kind = 'none' } end
    lastOffer[src] = now
    if HX.bucket(src) ~= 0 then return { kind = 'none' } end
    local pos = HX.pos(src)
    if not pos then return { kind = 'none' } end
    local coords = U.plain(pos)
    sessions[src], stings[src] = nil, nil

    local goods = pickGoods(src)
    if not goods then HX.tip(src, L('nothing_to_sell')) return { kind = 'none' } end
    local legal = isLegal(goods.item, goods.gang)

    -- arm the sting
    if ST.enabled and not legal then
        if isLawman == true and ST.lawmanAlways then
            stings[src] = { lawman = true }
        else
            local chance = ST.chance - HX.perkBonus(src, 'sale_quiet')
            if chance > 0 and math.random(1, 100) <= chance then stings[src] = { lawman = false } end
        end
    end

    if not B.enabled then
        -- instant sale: the local may simply refuse (rolled here, not on the client)
        if math.random(1, 10) <= S.instantRefuse then
            stings[src] = nil
            return { kind = 'refused' }
        end
        -- one unit, list price x perk (x gang)
        local taken = takeGoods(src, goods, 1)
        if taken < 1 then stings[src] = nil HX.tip(src, L('wave_off')) return { kind = 'none' } end
        local sting = stings[src]
        stings[src] = nil
        if sting then
            fireSting(src, sting, goods, taken, coords)
            return { kind = 'sting' }
        end
        local paid = U.round2(goods.price * HX.perkMult(src, 'drug_payout') * gangMult(src, goods, coords))
        HX.giveCash(src, paid)
        HX.tip(src, L('sold', goods.label, 1, U.money(paid)))
        award(src, goods, 1, paid, coords)
        if not legal then rollReport(src, coords) end
        logSale(src, goods.label, 1, paid, 'instant', coords)
        return { kind = 'instant' }
    end

    -- bargaining: how many, the band, the opening
    local maxUnits = math.max(1, math.floor(opt(goods.item, 'maxUnits')))
    local weights = opt(goods.item, 'weights') or { 100 }
    local sumW, pick, roll = 0, 1, 0
    for i = 1, math.min(#weights, maxUnits) do sumW = sumW + weights[i] end
    roll = math.random() * sumW
    for i = 1, math.min(#weights, maxUnits) do
        roll = roll - weights[i]
        if roll <= 0 then pick = i break end
    end
    local qty = math.max(1, math.min(pick, goods.have))
    local total = goods.price * qty
    local ceil = total * opt(goods.item, 'ceiling')
    local floor = total * opt(goods.item, 'floor') * HX.perkMult(src, 'drug_payout')
    if floor >= ceil then floor = ceil * 0.95 end
    local open = total * (opt(goods.item, 'opening') + (math.random() * 2 - 1) * opt(goods.item, 'jitter'))
    open = math.max(floor, math.min(ceil, open))

    local sess = {
        goods = goods, qty = qty, floor = U.round2(floor), ceil = U.round2(ceil), offer = U.round2(open),
        tries = 0, expires = now + B.sessionSeconds, coords = coords, legal = legal, accepted = nil,
    }
    sessions[src] = sess
    local steps = B.notches
    local notch = math.floor((sess.offer - sess.floor) / math.max(0.01, sess.ceil - sess.floor) * steps + 0.5)
    return {
        kind = 'haggle', label = goods.label, qty = qty, min = sess.floor, max = sess.ceil, steps = steps,
        notch = math.max(0, math.min(steps, notch)), offer = sess.offer,
    }
end, 1000)

HX.rpc('saleAsk', function(src, notch)
    local sess = sessions[src]
    notch = U.int(notch)
    if not sess or sess.accepted or not notch then return { kind = 'gone' } end
    if os.time() > sess.expires then
        sessions[src], stings[src] = nil, nil
        return { kind = 'gone' }
    end
    notch = math.max(0, math.min(B.notches, notch))
    local ask = U.round2(sess.floor + (sess.ceil - sess.floor) * notch / B.notches)
    local accepted = ask <= sess.offer
    local t = (ask - sess.floor) / math.max(0.01, sess.ceil - sess.floor)
    local tolerance = math.max(0, math.min(1, HX.perkBonus(src, 'sale_scam') / 10))
    if not accepted then
        local chance = math.max(0.02, math.min(0.97, 1 - t ^ 1.3))
        chance = chance + (1 - chance) * tolerance
        accepted = math.random() < chance
    end
    if accepted then
        sess.accepted = { price = ask, at = GetGameTimer() }
        return { kind = 'accept', price = ask }
    end
    sess.tries = sess.tries + 1
    local walkAt = B.walkAbove + (1 - B.walkAbove) * tolerance
    if sess.tries > B.counters or t > walkAt then
        sessions[src], stings[src] = nil, nil
        return { kind = 'walk' }
    end
    local frac = 0.30 + math.random() * 0.35
    sess.offer = U.round2(sess.offer + (ask - sess.offer) * frac)
    local n = math.floor((sess.offer - sess.floor) / math.max(0.01, sess.ceil - sess.floor) * B.notches + 0.5)
    return { kind = 'counter', offer = sess.offer, notch = math.max(0, math.min(B.notches, n)) }
end, 400)

HX.rpc('saleHandover', function(src)
    local sess = sessions[src]
    if not sess or not sess.accepted then return false end
    if GetGameTimer() - sess.accepted.at < B.handoffMs - 500 then return false end
    sessions[src] = nil -- spent, no replay
    local sting = stings[src]
    stings[src] = nil
    local pos = HX.pos(src)
    if not pos or U.dist(pos, sess.coords) > S.sessionRange then HX.tip(src, L('lost_interest')) return false end
    local goods = sess.goods
    local taken = takeGoods(src, goods, sess.qty)
    if taken < 1 then HX.tip(src, L('wave_off')) return false end
    if sting then
        fireSting(src, sting, goods, taken, sess.coords)
        return 'sting'
    end
    local paid = sess.accepted.price
    if taken < sess.qty then paid = paid * taken / sess.qty end
    paid = U.round2(paid * gangMult(src, goods, sess.coords))
    HX.giveCash(src, paid)
    HX.tip(src, L('sold', goods.label, taken, U.money(paid)))
    award(src, goods, taken, paid, sess.coords)
    -- one report roll, here, for a finished non-legal sale
    if not sess.legal then rollReport(src, sess.coords) end
    logSale(src, goods.label, taken, paid, 'haggled', sess.coords)
    return true
end, 1000)

HX.on('saleQuit', function(src)
    sessions[src], stings[src] = nil, nil
end, 200)

----------------------------------------------------------------------------------------------------
-- taking it back off a dead lawman
----------------------------------------------------------------------------------------------------
HX.on('stingLooted', function(src)
    local lb = lootback[src]
    if not lb then return end
    if os.time() > lb.expires then lootback[src] = nil return end
    if HX.bucket(src) ~= 0 or U.dist(HX.pos(src), lb.coords) > ST.lootRange then return end
    lootback[src] = nil
    if HX.canCarry(src, lb.item, lb.count) and HX.addItem(src, lb.item, lb.count) then
        HX.tip(src, L('take_back', lb.count, lb.label))
    else
        HX.tip(src, L('no_room_back'))
    end
end, 2000)

CreateThread(function()
    while true do
        Wait(5 * 60000)
        local now = os.time()
        for s, lb in pairs(lootback) do
            if now > lb.expires or not GetPlayerName(s) then lootback[s] = nil end
        end
    end
end)

function HX.salesDropped(src)
    sessions[src], stings[src], lootback[src], lastOffer[src] = nil, nil, nil, nil
end

function HX.salesSwitch(src)
    sessions[src], stings[src] = nil, nil
end

-- startup: name every sale item without a price
function HX.salesCheck()
    for _, r in ipairs(Config.Distill) do
        if not ((tonumber(S.prices[r.resultitem]) or 0) > 0) then
            print(('^3[pup_hideouts]^7 sale item "%s" has no price - locals will never buy it'):format(r.resultitem))
        end
    end
end
