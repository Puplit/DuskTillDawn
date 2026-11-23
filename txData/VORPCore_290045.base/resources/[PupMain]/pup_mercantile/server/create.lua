-- pup_mercantile | opening a new shop with a licence (shoptoken / societytoken)

local pending = {} -- [src] = { kind, at }

local function ownedCount(charid)
    local n = 0
    for _, s in pairs(Shops.player) do
        if s.charid == charid then n = n + 1 end -- repossessed shops still count
    end
    return n
end

local function societyCount(job)
    local n = 0
    for _, s in pairs(Shops.society) do
        if s.society == job then n = n + 1 end
    end
    return n
end

local function hasToken(src, item)
    local ok, n = pcall(function() return Inv:getItemCount(src, nil, item) end)
    return ok and (tonumber(n) or 0) >= 1
end

-- everything that can be checked before the player is asked for a name
local function precheck(src, kind, pos)
    local char = GetChar(src)
    if not char then return nil end
    if not ShopsReady then return nil, 'shopsLoading' end
    if kind == 'player' then
        if not IsAdmin(src) and ownedCount(tonumber(char.charIdentifier)) >= Config.PlayerShops.maxPerPlayer then
            return nil, 'maxShops', Config.PlayerShops.maxPerPlayer
        end
    else
        if not Config.SocietyShops.enabled then return nil end
        if not IsBoss(char, char.job) then return nil, 'bossOnly' end
        if societyCount(char.job) >= Config.SocietyShops.maxPerBusiness then
            return nil, 'maxSocietyShops', Config.SocietyShops.maxPerBusiness
        end
    end
    if pos and TooClose(pos) then return nil, 'tooClose' end
    return char
end

local function useToken(kind, item)
    return function(data)
        local src = tonumber(type(data) == 'table' and data.source)
        if not src then return end
        pcall(function() Inv:closeInventory(src) end)
        local char, why, arg = precheck(src, kind, PlayerPos(src))
        if not char then
            if why then Notify(src, Util.L(why, arg)) end
            return
        end
        if not hasToken(src, item) then return Notify(src, Util.L('noToken')) end
        pending[src] = { kind = kind, at = os.time() }
        TriggerClientEvent('pup_mercantile:create:begin', src, kind, char.job)
    end
end

CreateThread(function()
    Wait(500)
    Inv:registerUsableItem(Config.PlayerShops.token, useToken('player', Config.PlayerShops.token), GetCurrentResourceName())
    Inv:registerUsableItem(Config.SocietyShops.token, useToken('society', Config.SocietyShops.token), GetCurrentResourceName())
end)

RegisterNetEvent('pup_mercantile:create:cancel', function()
    pending[source] = nil
end)

-- one creation at a time, so two players cannot both pass the spacing or
-- business-limit check while the other's insert is still waiting on the database
local creating = false

local function finish(src, p, kind, name, clientCoords, clientJob)
    if not p or p.kind ~= kind or os.time() - p.at > 300 then return end
    local clean = Util.cleanName(name)
    if not clean then return Notify(src, Util.L('badName')) end
    local pos = PlayerPos(src) or Util.validCoords(clientCoords)
    if not pos then return end
    local char, why, arg = precheck(src, kind, pos)
    if not char then
        if why then Notify(src, Util.L(why, arg)) end
        return
    end
    if kind == 'society' and clientJob ~= char.job then return end
    local item = kind == 'player' and Config.PlayerShops.token or Config.SocietyShops.token
    if not hasToken(src, item) then return Notify(src, Util.L('noToken')) end

    local coordsJson = json.encode(pos)
    local okIns, newId
    local pool = kind == 'society' and SharesStock(char.job) and PoolOf(char.job) or nil
    if kind == 'player' then
        okIns, newId = pcall(MySQL.insert.await,
            [[INSERT INTO playershops (identifier, charidentifier, items, weapons, name, slots, coords, owned, blip, ledger, level, taxledger, repo, buyitems, webhook, manager)
              VALUES (?, ?, '[]', '[]', ?, ?, ?, 1, 1, 0, 0, 0, 0, '[]', '', 0)]],
            { char.identifier, char.charIdentifier, clean, Config.PlayerShops.startSlots, coordsJson })
    else
        okIns, newId = pcall(MySQL.insert.await,
            [[INSERT INTO society_shops (society, items, weapons, slots, level, name, coords, `rank`, blip, buyitems, webhook, enabled)
              VALUES (?, '[]', '[]', ?, 0, ?, ?, 0, 1, '[]', '', 1)]],
            { char.job, pool and pool.slots or Config.SocietyShops.startSlots, clean, coordsJson })
    end
    newId = okIns and tonumber(newId) or nil
    if not newId then return Notify(src, Util.L('createFailed')) end

    -- the licence is taken only once the shop exists; if it vanished meanwhile, undo the shop
    local okSub, taken = pcall(function() return Inv:subItem(src, item, 1) end)
    if not okSub or taken ~= true then
        pcall(MySQL.update.await, ('DELETE FROM %s WHERE id = ?'):format(kind == 'player' and 'playershops' or 'society_shops'), { newId })
        return Notify(src, Util.L('noToken'))
    end

    local row = {
        id = newId, name = clean, coords = coordsJson, blip = 1, level = 0, webhook = '',
        items = '[]', weapons = '[]', buyitems = '[]',
    }
    local shop
    if kind == 'player' then
        row.identifier, row.charidentifier = char.identifier, char.charIdentifier
        row.slots, row.ledger, row.taxledger, row.repo, row.manager = Config.PlayerShops.startSlots, 0, 0, 0, 0
        shop = ShopFromRow('player', row)
        Shops.player[shop.id] = shop
    else
        row.society, row.rank, row.enabled = char.job, 0, 1
        row.slots = pool and pool.slots or Config.SocietyShops.startSlots
        shop = ShopFromRow('society', row)
        if pool then
            shop.stock = pool
        elseif SharesStock(char.job) then
            shop.stock.shared = true
            shop.stock.lockKey = 's:' .. char.job
        end
        Shops.society[shop.id] = shop
        SaveShop(shop)
    end
    BroadcastShop(shop)
    Notify(src, Util.L('shopCreated'))
    local fields = {}
    if kind == 'society' then fields[#fields + 1] = { 'Society', char.job } end
    fields[#fields + 1] = { 'Name', clean }
    fields[#fields + 1] = { 'Shop', '#' .. shop.id }
    fields[#fields + 1] = { 'Coordinates', ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z) }
    Log({ title = Util.L('logCreated'), colour = Colours.setup, src = src, staffOnly = true, fields = fields })
end

RegisterNetEvent('pup_mercantile:create:finish', function(kind, name, clientCoords, clientJob)
    local src = source
    local p = pending[src]
    pending[src] = nil
    if not p then return end
    if creating then return Notify(src, Util.L('createBusy')) end
    creating = true
    local ok, err = pcall(finish, src, p, kind, name, clientCoords, clientJob)
    creating = false
    if not ok then print('^1[pup_mercantile]^7 shop creation failed: ' .. tostring(err)) end
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
