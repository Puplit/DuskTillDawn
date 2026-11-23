-- pup_mercantile | the management dashboard's server side, and the paid move

local managerNames = {} -- [charid] = "First Last"

local function charName(charid)
    charid = tonumber(charid)
    if not charid or charid == 0 then return nil end
    if managerNames[charid] then return managerNames[charid] end
    local ok, row = pcall(MySQL.single.await, 'SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { charid })
    if not ok or not row then return nil end
    local name = ((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    managerNames[charid] = name
    return name
end

local function dashData(shop, char)
    local buy = {}
    for _, b in ipairs(shop.stock.buyitems) do
        buy[#buy + 1] = { name = b.name, label = b.label, price = b.price, amount = b.amount }
    end
    local d = {
        kind = shop.kind, id = shop.id, name = shop.name, blip = shop.blip,
        slots = shop.stock.slots, level = shop.level, buyitems = buy,
        slotPrice = Config.Shops.pricePerSlot, movePrice = Config.Shops.movePrice,
        webhooks = Config.Shops.ownerWebhooks, taxCap = Config.Tax.amount,
        cash = Util.round2(char.money or 0),
    }
    if shop.kind == 'player' then
        d.ledger = shop.ledger
        d.taxledger = shop.taxledger
        d.isOwner = IsTrueOwner(char, shop)
        d.manager = shop.manager
        d.managerName = shop.manager ~= 0 and (charName(shop.manager) or ('#' .. shop.manager)) or nil
    else
        d.society = shop.society
        d.rank = shop.rank
        d.isBoss = IsBoss(char, shop.society)
    end
    return d
end

local function pushDash(src, shop, char)
    TriggerClientEvent('pup_mercantile:dash:data', src, dashData(shop, char or GetChar(src)))
end

-- every dashboard action: rate limit, live visit, manager rights
local function managed(src, playerOnly)
    if not RateOk(src) then return nil end
    local visit, shop, char = LiveVisit(src, true)
    if not visit or visit.moving then return nil end
    if playerOnly and shop.kind ~= 'player' then return nil end
    return shop, char, visit
end

RegisterNetEvent('pup_mercantile:dash:get', function()
    local src = source
    local visit, shop, char = LiveVisit(src, true)
    if not visit then return TriggerClientEvent('pup_mercantile:dash:data', src, nil) end
    pushDash(src, shop, char)
end)

RegisterNetEvent('pup_mercantile:dash:deposit', function(amount)
    local src = source
    local shop, char = managed(src, true)
    if not shop then return end
    local n = Util.money(amount)
    if not n then return Notify(src, Util.L('badAmount')) end
    if not TakeCash(src, n) then return Notify(src, Util.L('noMoney', Util.fmt(n))) end
    shop.ledger = Util.round2(shop.ledger + n)
    SaveShop(shop)
    Notify(src, Util.L('deposited', Util.fmt(n)))
    Log({ title = Util.L('logLedgerIn'), colour = Colours.money, src = src, shop = shop, fields = {
        { 'Shop', '#' .. shop.id }, { 'Amount', '$' .. Util.fmt(n) }, { 'Ledger', '$' .. Util.fmt(shop.ledger) } } })
    pushDash(src, shop, char)
end)

RegisterNetEvent('pup_mercantile:dash:withdraw', function(amount)
    local src = source
    local shop = managed(src, true)
    if not shop then return end
    local n = Util.money(amount)
    if not n or n > shop.ledger then return Notify(src, Util.L('badAmount')) end
    shop.ledger = Util.round2(shop.ledger - n)
    if not GiveCash(src, n) then
        shop.ledger = Util.round2(shop.ledger + n)
        return
    end
    SaveShop(shop)
    Notify(src, Util.L('withdrewMoney', Util.fmt(n)))
    Log({ title = Util.L('logLedgerOut'), colour = Colours.money, src = src, shop = shop, fields = {
        { 'Shop', '#' .. shop.id }, { 'Amount', '$' .. Util.fmt(n) }, { 'Ledger', '$' .. Util.fmt(shop.ledger) } } })
    pushDash(src, shop)
end)

RegisterNetEvent('pup_mercantile:dash:tax', function(amount)
    local src = source
    local shop = managed(src, true)
    if not shop then return end
    local n = Util.money(amount)
    if not n then return Notify(src, Util.L('badAmount')) end
    if Util.round2(shop.taxledger + n) > Config.Tax.amount then
        return Notify(src, Util.L('taxCap', Util.fmt(Config.Tax.amount)))
    end
    if not TakeCash(src, n) then return Notify(src, Util.L('noMoney', Util.fmt(n))) end
    shop.taxledger = Util.round2(shop.taxledger + n)
    SaveShop(shop)
    Notify(src, Util.L('taxDeposited', Util.fmt(n)))
    Log({ title = Util.L('logTax'), colour = Colours.money, src = src, shop = shop, fields = {
        { 'Amount', '$' .. Util.fmt(n) }, { 'Tax ledger', '$' .. Util.fmt(shop.taxledger) } } })
    pushDash(src, shop)
end)

RegisterNetEvent('pup_mercantile:dash:slots', function(count)
    local src = source
    local shop = managed(src, false)
    if not shop then return end
    local n = Util.whole(count, 1, 100000)
    if not n then return Notify(src, Util.L('badAmount')) end
    local cost = Util.round2(n * Config.Shops.pricePerSlot)
    if not TakeCash(src, cost) then return Notify(src, Util.L('upgradeCash', Util.fmt(cost))) end
    shop.stock.slots = shop.stock.slots + n -- shared pools change for every sibling at once
    shop.level = shop.level + 1
    SaveShop(shop)
    Notify(src, Util.L('slotsAdded', n))
    Log({ title = Util.L('logSlots'), colour = Colours.setup, src = src, shop = shop, fields = {
        { 'Shop', '#' .. shop.id }, { 'Slots added', n }, { 'Upgrade level', shop.level }, { 'Total slots', shop.stock.slots } } })
    pushDash(src, shop)
    ScheduleRefresh(shop)
end)

RegisterNetEvent('pup_mercantile:dash:rank', function(rank)
    local src = source
    local shop, char = managed(src, false)
    if not shop or shop.kind ~= 'society' or not IsBoss(char, shop.society) then return end
    local n = Util.whole(rank, 0, 100)
    if not n then return Notify(src, Util.L('badAmount')) end
    shop.rank = n
    SaveShop(shop)
    BroadcastShop(shop)
    Notify(src, Util.L('rankSet', n))
    pushDash(src, shop, char)
end)

RegisterNetEvent('pup_mercantile:dash:webhook', function(url)
    local src = source
    local shop = managed(src, false)
    if not shop or not Config.Shops.ownerWebhooks then return end
    if not Util.validWebhook(url) then return Notify(src, Util.L('badUrl')) end
    shop.webhook = url
    SaveShop(shop)
    Notify(src, Util.L('webhookAdded'))
    Log({ title = Util.L('logWebhook'), colour = Colours.setup, src = src, shop = shop, fields = {
        { 'Shop', '#' .. shop.id }, { 'Note', Util.L('logWebhookNote') } } })
end)

local function buyArgs(src, name, amount, price)
    local n = Util.whole(amount, 1, 999999999)
    local p = Util.money(price)
    if not n or not p then
        Notify(src, Util.L('badAmount'))
        return nil
    end
    return n, p
end

RegisterNetEvent('pup_mercantile:dash:buyAdd', function(name, amount, price)
    local src = source
    local shop = managed(src, false)
    if not shop or type(name) ~= 'string' then return end
    local cat = CatalogueByName[name]
    if not cat then return Notify(src, Util.L('notBuying', name)) end
    if cat.type == 'item_weapon' or IsWeaponName(name) then return Notify(src, Util.L('noWeaponsBuy')) end
    if Util.blacklisted(name) then return Notify(src, Util.L('blacklisted')) end
    local n, p = buyArgs(src, name, amount, price)
    if not n then return end
    local b = FindBuy(shop.stock, name)
    if b then
        b.amount, b.price = n, p
    else
        shop.stock.buyitems[#shop.stock.buyitems + 1] = { name = name, label = cat.label, price = p, amount = n }
    end
    SaveShop(shop)
    pushDash(src, shop)
end)

RegisterNetEvent('pup_mercantile:dash:buyEdit', function(name, amount, price)
    local src = source
    local shop = managed(src, false)
    if not shop or type(name) ~= 'string' then return end
    local b = FindBuy(shop.stock, name)
    if not b then return end
    local n, p = buyArgs(src, name, amount, price)
    if not n then return end
    b.amount, b.price = n, p
    SaveShop(shop)
    pushDash(src, shop)
end)

RegisterNetEvent('pup_mercantile:dash:buyRemove', function(name)
    local src = source
    local shop = managed(src, false)
    if not shop or type(name) ~= 'string' then return end
    local _, i = FindBuy(shop.stock, name)
    if not i then return end
    table.remove(shop.stock.buyitems, i)
    SaveShop(shop)
    pushDash(src, shop)
end)

RegisterNetEvent('pup_mercantile:dash:manager', function(value)
    local src = source
    local shop, char = managed(src, true)
    if not shop or not IsTrueOwner(char, shop) then return end
    local id = tonumber(value)
    if value == nil or value == '' or id == 0 then
        local old = shop.manager
        if old == 0 then return Notify(src, Util.L('managerRemoved')) end
        shop.manager = 0
        SaveShop(shop)
        BroadcastShop(shop)
        Notify(src, Util.L('managerRemoved'))
        Log({ title = Util.L('logManagerRemoved'), colour = Colours.setup, src = src, shop = shop, fields = {
            { 'Shop', '#' .. shop.id }, { 'Manager', ('%s (#%d)'):format(charName(old) or '?', old) } } })
        return pushDash(src, shop, char)
    end
    id = Util.whole(id, 1, 2147483647)
    if not id then return Notify(src, Util.L('noCharacter')) end
    if id == shop.charid then return Notify(src, Util.L('alreadyOwner')) end
    managerNames[id] = nil
    local name = charName(id)
    if not name then return Notify(src, Util.L('noCharacter')) end
    -- the lookup waited on the database; make sure nothing changed hands meanwhile
    local live, s2, c2 = LiveVisit(src, true)
    if not live or s2 ~= shop or not IsTrueOwner(c2, shop) then return end
    shop.manager = id
    SaveShop(shop)
    BroadcastShop(shop)
    Notify(src, Util.L('managerSet', name))
    local online = OnlineByCharId(id)
    if online then Notify(online, Util.L('nowManage', shop.name), 6000) end
    Log({ title = Util.L('logManagerSet'), colour = Colours.setup, src = src, shop = shop, fields = {
        { 'Shop', '#' .. shop.id }, { 'Manager', ('%s (#%d)'):format(name, id) } } })
    pushDash(src, shop, c2)
end)

------------------------------------------------------------------------------
-- paid move: approve, then place at the server-side position (fee and move are one step)
------------------------------------------------------------------------------
RegisterNetEvent('pup_mercantile:move:request', function()
    local src = source
    local visit, shop = LiveVisit(src, true)
    if not visit then return TriggerClientEvent('pup_mercantile:visit:ended', src) end
    local price = Config.Shops.movePrice
    if Cash(src) < price then
        Notify(src, Util.L('moveCash', Util.fmt(price)))
        return EndVisit(src, true)
    end
    visit.moving = true
    TriggerClientEvent('pup_mercantile:move:approved', src, shop.kind, shop.id)
end)

RegisterNetEvent('pup_mercantile:move:confirm', function(clientCoords)
    local src = source
    local v = Visits[src]
    if not v or not v.moving then return end
    local visit, shop = LiveVisit(src, true, true)
    if not visit then return end
    local pos = PlayerPos(src) or Util.validCoords(clientCoords)
    if not pos then return end
    if TooClose(pos, shop) then
        Notify(src, Util.L('tooClose'))
        return TriggerClientEvent('pup_mercantile:move:retry', src)
    end
    local price = Config.Shops.movePrice
    if not TakeCash(src, price) then
        Notify(src, Util.L('moveCash', Util.fmt(price)))
        visit.moving = false
        return EndVisit(src, true)
    end
    shop.coords = { x = pos.x + 0.0, y = pos.y + 0.0, z = pos.z + 0.0 }
    SaveShop(shop)
    BroadcastShop(shop)
    Notify(src, Util.L('moved', Util.fmt(price)))
    Log({ title = Util.L('logMoved'), colour = Colours.setup, src = src, shop = shop, fields = {
        { 'Shop', '#' .. shop.id }, { 'Fee', '$' .. Util.fmt(price) },
        { 'Coordinates', ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z) } } })
    visit.moving = false
    EndVisit(src, true)
end)

RegisterNetEvent('pup_mercantile:move:cancel', function()
    local src = source
    local v = Visits[src]
    if not v then return end
    v.moving = false
    Notify(src, Util.L('moveCancelled'))
    EndVisit(src, true)
end)
