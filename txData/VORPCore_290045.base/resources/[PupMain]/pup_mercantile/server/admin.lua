-- pup_mercantile | staff commands and the exports other resources call

local function reply(src, text)
    if src == 0 then print('[pup_mercantile] ' .. text) else Notify(src, text, 6000) end
end

function DeleteShop(shop)
    Shops[shop.kind][shop.id] = nil
    local tbl = shop.kind == 'player' and 'playershops' or 'society_shops'
    pcall(MySQL.update.await, ('DELETE FROM %s WHERE id = ?'):format(tbl), { shop.id })
    CloseShopForEveryone(shop)
    BroadcastShop(shop, true)
end

local function setRepo(shop, on)
    shop.repo = on
    SaveShop(shop)
    if on then CloseShopForEveryone(shop) end
    BroadcastShop(shop)
end

local function moveShop(shop, coords)
    shop.coords = coords
    SaveShop(shop)
    BroadcastShop(shop)
end

------------------------------------------------------------------------------
-- commands (VORP group admin or the console)
------------------------------------------------------------------------------
local function adminCommand(name, fn)
    RegisterCommand(name, function(src, args)
        if not IsAdmin(src) then return end
        if not ShopsReady then return reply(src, Util.L('shopsLoading')) end
        fn(src, args)
    end, false)
end

adminCommand(Config.Commands.adminMove, function(src, args)
    local id = Util.whole(args[1], 1)
    local c = Util.validCoords({ x = args[2], y = args[3], z = args[4] })
    if not id or not c then return reply(src, Util.L('adminUsageMove')) end
    local shop = Shops.player[id]
    if not shop then return reply(src, Util.L('adminNoShop')) end
    moveShop(shop, c) -- staff placement ignores spacing
    reply(src, Util.L('adminMoved', id))
end)

adminCommand(Config.Commands.repo, function(src, args)
    local id = Util.whole(args[1], 1)
    if not id then return reply(src, Util.L('adminUsageRepo')) end
    local shop = Shops.player[id]
    if not shop then return reply(src, Util.L('adminNoShop')) end
    setRepo(shop, true)
    reply(src, Util.L('adminRepo', id))
end)

adminCommand(Config.Commands.unrepo, function(src, args)
    local id = Util.whole(args[1], 1)
    if not id then return reply(src, Util.L('adminUsageUnrepo')) end
    local shop = Shops.player[id]
    if not shop then return reply(src, Util.L('adminNoShop')) end
    setRepo(shop, false)
    reply(src, Util.L('adminUnrepo', id))
end)

-- /delshop <id> [player|society]: a player shop by default, or a society shop when
-- no player shop has that id or when "society" is given
adminCommand(Config.Commands.delete, function(src, args)
    local id = Util.whole(args[1], 1)
    if not id then return reply(src, Util.L('adminUsageDelete')) end
    local kind = args[2] and tostring(args[2]):lower() or nil
    local shop
    if kind == 'society' or kind == 's' then
        shop = Shops.society[id]
    elseif kind == 'player' or kind == 'p' then
        shop = Shops.player[id]
    else
        shop = Shops.player[id] or Shops.society[id]
    end
    if not shop then return reply(src, Util.L('adminNoShop')) end
    DeleteShop(shop)
    reply(src, Util.L('adminDeleted', id))
end)

------------------------------------------------------------------------------
-- vorp_admin: player shops
------------------------------------------------------------------------------
exports('adminStoreList', function()
    if not ShopsReady then return nil end
    local ids, marks = {}, {}
    for _, s in pairs(Shops.player) do
        if s.charid ~= 0 then ids[#ids + 1] = s.charid marks[#marks + 1] = '?' end
    end
    local people = {}
    if #ids > 0 then
        local ok, rows = pcall(MySQL.query.await,
            'SELECT charidentifier, firstname, lastname, discordid FROM characters WHERE charidentifier IN (' .. table.concat(marks, ',') .. ')', ids)
        for _, r in ipairs(ok and rows or {}) do
            local d = r.discordid and tostring(r.discordid):gsub('^discord:', '') or nil
            if d == '' or d == '0' then d = nil end
            people[tonumber(r.charidentifier)] = {
                name = ((r.firstname or '') .. ' ' .. (r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                discord = d,
            }
        end
    end
    local shops, stats = {}, { total = 0, active = 0, repo = 0, ledger = 0, maxper = Config.PlayerShops.maxPerPlayer }
    for _, s in pairs(Shops.player) do
        local p = people[s.charid] or {}
        shops[#shops + 1] = {
            id = s.id, name = s.name, coords = s.coords, slots = s.stock.slots, ledger = s.ledger,
            taxledger = s.taxledger, level = s.level, blip = s.blip, repo = s.repo, charid = s.charid,
            owner = p.name, discord = p.discord, items = #s.stock.items, weapons = #s.stock.weapons,
        }
        stats.total = stats.total + 1
        if s.repo then stats.repo = stats.repo + 1 else stats.active = stats.active + 1 end
        stats.ledger = Util.round2(stats.ledger + s.ledger)
    end
    table.sort(shops, function(a, b) return a.id < b.id end)
    return { shops = shops, stats = stats }
end)

exports('adminStoreStock', function(id)
    if not ShopsReady then return nil end
    local shop = Shops.player[tonumber(id) or -1]
    if not shop then return nil end
    local items, weapons, buying = {}, {}, {}
    for _, r in ipairs(shop.stock.items) do
        items[#items + 1] = { name = r.itemname, label = r.label, count = r.itemcount, price = r.price, forsale = r.forsale }
    end
    for _, w in ipairs(shop.stock.weapons) do
        weapons[#weapons + 1] = { name = w.name, label = WeaponLabel(w.name), serial = w.id, price = w.price, forsale = w.forsale }
    end
    for _, b in ipairs(shop.stock.buyitems) do
        buying[#buying + 1] = { name = b.name, price = b.price, amount = b.amount }
    end
    table.sort(items, function(a, b) return Util.naturalLess(a.label, b.label) end)
    table.sort(weapons, function(a, b) return Util.naturalLess(a.label, b.label) end)
    table.sort(buying, function(a, b) return a.name < b.name end)
    return { items = items, weapons = weapons, buying = buying }
end)

local function onValue(v)
    return v == true or v == 1 or v == '1' or v == 'true' or v == 'on'
end

exports('adminStoreAction', function(id, action, value)
    if not ShopsReady then return false, 'shops are still loading' end
    id = Util.whole(id, 1)
    if not id or type(action) ~= 'string' then return false, 'bad request' end
    local shop = Shops.player[id]
    if not shop then return false, 'no such shop' end
    if action == 'repo' then
        setRepo(shop, true)
    elseif action == 'unrepo' then
        setRepo(shop, false)
    elseif action == 'rename' then
        local n = Util.cleanName(value)
        if not n then return false, 'invalid name' end
        shop.name = n
        SaveShop(shop)
        BroadcastShop(shop)
    elseif action == 'blip' then
        shop.blip = onValue(value) and 1 or 0
        SaveShop(shop)
        BroadcastShop(shop)
    elseif action == 'move' then
        local c = Util.validCoords(value)
        if not c then return false, 'bad coordinates' end
        if TooClose(c, shop) then return false, 'too close to another shop' end
        moveShop(shop, c)
    elseif action == 'slots' then
        local n = tonumber(value)
        if not n or n ~= n then return false, 'bad request' end
        shop.stock.slots = math.max(1, math.min(1000000, math.floor(n)))
        SaveShop(shop)
        ScheduleRefresh(shop)
    elseif action == 'delete' then
        DeleteShop(shop)
    else
        return false, 'unknown action'
    end
    return true
end)

-- re-checks vorp_admin's own permission key; refuses when vorp_admin is not running
function StaffMayManage(src)
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return false end
    local res = Config.Admin.resource
    if not ResourceUp(res) then return false end
    local ok, allowed = pcall(function()
        return exports[res]:allowedToExecuteAction(src, Config.Admin.permission)
    end)
    return ok and allowed == true
end

-- vorp_admin "Open shop inventory": the shop's real grid for staff, owner controls,
-- from anywhere, without a visit and without becoming the owner
exports('adminOpenStock', function(src, id)
    src = tonumber(src)
    if not ShopsReady then return false, 'shops are still loading' end
    id = Util.whole(id, 1)
    if not src or not id then return false, 'bad request' end
    if not GetChar(src) then return false, 'no character loaded' end
    if not StaffMayManage(src) then return false, 'not allowed' end
    -- read again: the permission check may have waited
    local shop = Shops.player[id]
    if not shop then return false, 'no such shop' end
    if Visits[src] or (Viewers[src] and not Viewers[src].admin) then
        return false, 'close the store you are standing at first'
    end
    OpenAdminGrid(src, shop)
    Notify(src, Util.L('adminStockOpened', shop.id, shop.name))
    Log({ title = Util.L('logAdminOpen'), colour = Colours.setup, src = src, shop = shop, staffOnly = true, fields = {
        { 'Shop', ('%s (#%d)'):format(shop.name, shop.id) },
        { 'Owner charid', shop.charid },
        { 'Repossessed', tostring(shop.repo) },
    } })
    return true
end)

------------------------------------------------------------------------------
-- pup_business: society shops
------------------------------------------------------------------------------
local function society(id)
    if not ShopsReady then return nil end
    return Shops.society[tonumber(id) or -1]
end

exports('RefreshSocietyBossRanks', function()
    RefreshBossRanks()
    if ShopsReady then BroadcastAll() end
end)

exports('AdminListSocietyShops', function(job)
    if not ShopsReady then return nil end
    local out = {}
    for _, s in pairs(Shops.society) do
        if not job or s.society == job then
            out[#out + 1] = {
                id = s.id, society = s.society, name = s.name, coords = s.coords, rank = s.rank, blip = s.blip,
                slots = s.stock.slots, level = s.level, enabled = s.enabled, items = #s.stock.items, weapons = #s.stock.weapons,
            }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

exports('AdminSetSocietyShopEnabled', function(id, on)
    local s = society(id)
    if not s then return false end
    s.enabled = on == true
    SaveShop(s)
    if not s.enabled then CloseShopForEveryone(s) end
    BroadcastShop(s)
    return true
end)

exports('AdminRenameSocietyShop', function(id, name)
    local s = society(id)
    local n = Util.cleanName(name)
    if not s or not n then return false end
    s.name = n
    SaveShop(s)
    BroadcastShop(s)
    return true
end)

exports('AdminSetSocietyShopRank', function(id, rank)
    local s = society(id)
    local n = tonumber(rank)
    if not s or not n or n ~= n then return false end
    s.rank = math.max(0, math.min(100, math.floor(n)))
    SaveShop(s)
    BroadcastShop(s)
    return true
end)

exports('AdminSetSocietyShopSlots', function(id, slots)
    local s = society(id)
    local n = tonumber(slots)
    if not s or not n or n ~= n then return false end
    s.stock.slots = math.max(1, math.min(1000000, math.floor(n))) -- the whole pool shares it
    SaveShop(s)
    ScheduleRefresh(s)
    return true, s.stock.slots
end)

exports('AdminSetSocietyShopBlip', function(id, on)
    local s = society(id)
    if not s then return false end
    s.blip = on == true and 1 or 0
    SaveShop(s)
    BroadcastShop(s)
    return true
end)

exports('AdminMoveSocietyShop', function(id, coords)
    local s = society(id)
    if not s then return false, 'noshop' end
    local c = Util.validCoords(coords)
    if not c then return false, 'badcoords' end
    if TooClose(c, s) then return false, 'tooclose' end
    moveShop(s, c)
    return true
end)

exports('AdminDeleteSocietyShop', function(id)
    local s = society(id)
    if not s then return false end
    DeleteShop(s)
    return true
end)

exports('AdminClearSocietyShopStock', function(id)
    local s = society(id)
    if not s then return false end
    local st = s.stock
    for i = #st.items, 1, -1 do st.items[i] = nil end
    for i = #st.weapons, 1, -1 do st.weapons[i] = nil end
    for i = #st.buyitems, 1, -1 do st.buyitems[i] = nil end
    SaveShop(s)
    ScheduleRefresh(s)
    return true
end)

------------------------------------------------------------------------------
-- pup_robbery: The Fence's position and stock, until the next restart
------------------------------------------------------------------------------
exports('SetStorePos', function(storeName, pos)
    local store = NpcByName(storeName)
    local c = Util.validCoords(pos)
    if not store or not c then return false end
    store.pos = c
    return true
end)

exports('SetStoreStock', function(storeName, sellList, buyList)
    local store = NpcByName(storeName)
    if not store then return false end
    if type(sellList) == 'table' then store.sell = NormStoreList(sellList) end
    if type(buyList) == 'table' then store.buy = NormStoreList(buyList) end
    return true
end)
