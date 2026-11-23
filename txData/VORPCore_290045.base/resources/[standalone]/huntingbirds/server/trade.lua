-- huntingbirds | player-to-player sale at a sell point next to the seller

local function publicPoint(p)
    return { id = p.id, name = p.name, model = p.model, price = p.price, coords = p.coords, owner = p.owner }
end

-- remove a point everywhere; withPed also asks every client to delete the bird ped
function Srv.removePoint(birdId, withPed)
    local p = Srv.points[birdId]
    if not p then return end
    Srv.points[birdId] = nil
    local s = Srv.sessions[p.owner]
    if s and s.sellPoint == birdId then s.sellPoint = nil end
    if withPed then
        -- the server removes the ped too; clients only clean up what is left
        if p.netId then
            local ent = NetworkGetEntityFromNetworkId(p.netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) and Util.u32(GetEntityModel(ent)) == p.model then
                DeleteEntity(ent)
            end
        end
        TriggerClientEvent('huntingbirds:sell:updatepoints', -1, nil, birdId, p.netId)
    else
        TriggerClientEvent('huntingbirds:sell:updatepoints1', -1, birdId)
    end
end

local function mayTrade(char)
    local jobs = Config.Trade.jobs
    if jobs == nil then return true end
    return Srv.hasJob(char, jobs)
end

RegisterNetEvent('pup_huntingbirds:check_sell', function()
    local src = source
    local char = Srv.char(src)
    if not char then return end
    if not Srv.throttle(src, 'checksell', 1000) then return end
    local s = Srv.session(src, char)
    if not s.activeBird or s.trip or s.sellPoint then return end
    if not mayTrade(char) then
        Srv.notify(src, Locale.noJob, 'red')
        return
    end
    TriggerClientEvent('pup_huntingbirds:start_sell', src)
end)

RegisterNetEvent('huntingbirds:sell:create', function(birdId, price, birdNetId)
    local src = source
    local char = Srv.char(src)
    if not char then return end
    if not Srv.throttle(src, 'sellcreate', 2000) then return end
    birdId = Util.int(birdId, 1)
    price = Util.int(price, 1, tonumber(Config.Trade.maxPrice) or 100000)
    if not birdId or not price then
        BirdLog.refused(src, char, 'start sale', 'bad bird id or price')
        return
    end
    local s = Srv.session(src, char)
    if s.activeBird ~= birdId or s.trip or s.sellPoint or Srv.points[birdId] then return end
    if not mayTrade(char) then
        Srv.notify(src, Locale.noJob, 'red')
        return
    end
    local row = Srv.ownedRow(char, birdId)
    if not row then
        BirdLog.refused(src, char, 'start sale', ('bird %d is not theirs'):format(birdId))
        return
    end
    local coords = Srv.pedCoords(src)
    if not coords then return end

    -- keep the net id only if it is this player's bird ped of the right model
    local netId = Util.int(birdNetId, 1, 0x7FFFFFFF)
    if netId then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if not ent or ent == 0 or not DoesEntityExist(ent)
            or NetworkGetEntityOwner(ent) ~= src
            or Util.u32(GetEntityModel(ent)) ~= Util.u32(row.model) then
            netId = nil
        end
    end

    local p = {
        id = birdId, name = row.name, model = Util.u32(row.model), price = price, coords = coords,
        owner = src, identifier = char.identifier, charid = char.charIdentifier, netId = netId,
    }
    Srv.points[birdId] = p
    s.sellPoint = birdId
    TriggerClientEvent('huntingbirds:sell:updatepoints', -1, publicPoint(p), birdId, nil)
end)

RegisterNetEvent('huntingbirds:sell:stop', function(birdId)
    local src = source
    birdId = Util.int(birdId, 1)
    local p = birdId and Srv.points[birdId]
    if not p or p.owner ~= src then return end
    Srv.removePoint(birdId, false)
end)

RegisterNetEvent('huntingbirds:sell:getpoints', function()
    local src = source
    if not Srv.throttle(src, 'points', 2000) then return end
    local out = {}
    for id, p in pairs(Srv.points) do out[id] = publicPoint(p) end
    TriggerClientEvent('huntingbirds:sell:gotpoints_c', src, out)
end)

RegisterNetEvent('huntingbirds:sell:buyoffer', function(birdId)
    local src = source
    local buyer = Srv.char(src)
    if not buyer then return end
    if not Srv.throttle(src, 'buyoffer', 2000) then return end
    birdId = Util.int(birdId, 1)
    local p = birdId and Srv.points[birdId]
    if not p or p.busy then return end
    if p.owner == src or (buyer.identifier == p.identifier and buyer.charIdentifier == p.charid) then return end
    if not Srv.near(src, p.coords, tonumber(Config.Trade.buyDistance) or 3.0) then
        Srv.notify(src, Locale.tooFar, 'red')
        return
    end
    local seller = Srv.char(p.owner)
    if not seller or seller.identifier ~= p.identifier or seller.charIdentifier ~= p.charid then
        Srv.removePoint(birdId, true)
        return
    end
    if (tonumber(buyer.money) or 0) < p.price then
        Srv.notify(src, Locale.tradeNoMoney, 'red')
        Srv.notify(p.owner, Locale.tradeBuyerNoMoney, 'red')
        return
    end

    p.busy = true
    local ok, affected = pcall(MySQL.update.await,
        'UPDATE `birds` SET `identifier` = ?, `charid` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
        { buyer.identifier, buyer.charIdentifier, birdId, p.identifier, p.charid })
    local sellerSrc, price = p.owner, p.price
    if not ok or tonumber(affected) ~= 1 then
        Srv.removePoint(birdId, false)
        BirdLog.post(src, 'Trade needs a check', 'red', {
            { 'Buyer', BirdLog.who(src, buyer) },
            { 'Seller', BirdLog.who(sellerSrc, seller) },
            { 'Bird ID', birdId },
            { 'Detail', 'the bird row did not change owner; no money moved' },
        })
        return
    end

    -- the database wait can let either side leave or spend the money; then the bird goes back
    local b, sl = Srv.char(src), Srv.char(sellerSrc)
    local bOk = b and b.identifier == buyer.identifier and b.charIdentifier == buyer.charIdentifier
        and (tonumber(b.money) or 0) >= price
    local sOk = sl and sl.identifier == p.identifier and sl.charIdentifier == p.charid
    if not bOk or not sOk then
        pcall(MySQL.update.await,
            'UPDATE `birds` SET `identifier` = ?, `charid` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
            { p.identifier, p.charid, birdId, buyer.identifier, buyer.charIdentifier })
        Srv.removePoint(birdId, false)
        BirdLog.post(src, 'Trade needs a check', 'red', {
            { 'Buyer', BirdLog.who(src, buyer) },
            { 'Seller', BirdLog.who(sellerSrc, seller) },
            { 'Bird ID', birdId },
            { 'Detail', 'a side left or the buyer could no longer pay; the bird was given back, no money moved' },
        })
        return
    end
    b.removeCurrency(0, price)
    sl.addCurrency(0, price)
    Srv.notify(src, Locale.tradeBought, 'gold')
    Srv.notify(sellerSrc, Locale.tradeSold:format(Util.money(price)), 'gold')

    Srv.removePoint(birdId, false)
    local ss = Srv.sessions[sellerSrc]
    if ss and ss.activeBird == birdId then ss.activeBird, ss.activeModel, ss.trip = nil, nil, nil end
    TriggerClientEvent('huntingbirds:sell:finishsell', sellerSrc)

    BirdLog.post(src, 'Bird traded', 'blue', {
        { 'Buyer', BirdLog.who(src, buyer) },
        { 'Seller', BirdLog.who(sellerSrc, seller) },
        { 'Bird', ('%s (ID %d)'):format(BirdLog.clean(p.name), birdId) },
        { 'Price', '$' .. Util.money(price) },
    })
end)

-- a sale ends when the seller walks off, dies or leaves
CreateThread(function()
    while true do
        Wait(1000)
        local leave = tonumber(Config.Trade.leaveDistance) or 3.0
        for id, p in pairs(Srv.points) do
            if not p.busy then
                local ped = GetPlayerPed(p.owner)
                local gone = GetPlayerName(p.owner) == nil or not ped or ped == 0 or not DoesEntityExist(ped)
                local char = not gone and Srv.char(p.owner) or nil
                local dead = not gone and (GetEntityHealth(ped) <= 0 or (char ~= nil and (char.isdead == true or char.isdead == 1)))
                local moved = not gone and #(GetEntityCoords(ped) - p.coords) > leave
                if gone then
                    Srv.removePoint(id, true)
                elseif dead or moved then
                    Srv.removePoint(id, false)
                    Srv.notify(p.owner, Locale.saleEnded, 'red')
                end
            end
        end
    end
end)
