-- pup_mercantile | visits, NPC stores, the vorp_inventory grid and live refresh

Visits = {}   -- [src] = { kind, id, charid, startName, startBlip, startCoords, pendingName, pendingBlip, moving }
Viewers = {}  -- [src] = { kind = 'npc'|'player'|'society', id }

local lastTransfer = {}

function ShopReach()
    return Config.Shops.promptDistance + Config.ServerSlack
end

function NpcReach()
    return Config.NpcStores.promptDistance + Config.ServerSlack
end

-- one grid transfer or box trade per player every 200 ms
function RateOk(src)
    local now = GetGameTimer()
    if lastTransfer[src] and now - lastTransfer[src] < 200 then return false end
    lastTransfer[src] = now
    return true
end

------------------------------------------------------------------------------
-- NPC stores (config/stores.lua via shared/stores.lua; pup_robbery may change position and lists)
------------------------------------------------------------------------------
NpcStores = {}

function NormStoreList(list)
    local out = {}
    for _, e in ipairs(type(list) == 'table' and list or {}) do
        if type(e) == 'table' and type(e.name) == 'string' then
            out[#out + 1] = {
                name = e.name,
                label = tostring(e.label or e.name),
                price = Util.round2(tonumber(e.price) or 0),
                type = e.type == 'item_weapon' and 'item_weapon' or 'item_standard',
            }
        end
    end
    return out
end

for i, s in ipairs(NpcStoreList) do
    local jobs = {}
    for _, j in ipairs(s.jobs or {}) do jobs[j] = true end
    NpcStores[i] = {
        idx = i,
        name = s.name,
        pos = Util.validCoords(s.pos) or { x = 0.0, y = 0.0, z = 0.0 },
        jobs = next(jobs) and jobs or nil,
        sell = NormStoreList(s.sell),
        buy = NormStoreList(s.buy),
        gate = type(s.gate) == 'table' and s.gate or nil,
    }
end

function NpcByName(name)
    for _, s in ipairs(NpcStores) do
        if s.name == name then return s end
    end
    return nil
end

local function jobAllowed(store, char)
    return not store.jobs or (char and store.jobs[char.job] == true)
end

local function gateAllows(store, src)
    if not store.gate then return true end
    local res, exp = store.gate.resource, store.gate.export
    if not ResourceUp(res) or type(exp) ~= 'string' then return false end
    local ok, v = pcall(function()
        local proxy = exports[res]
        return proxy[exp](proxy, src)
    end)
    return ok and v == true
end

-- the full NPC-store check: character, distance, job and gate
function NpcCheck(src, idx, quiet)
    local store = NpcStores[tonumber(idx) or -1]
    if not store then return nil end
    local char = GetChar(src)
    if not char then return nil end
    local pos = PlayerPos(src)
    if pos and Util.dist(pos, store.pos) > NpcReach() then return nil end
    if not jobAllowed(store, char) then
        if not quiet then Notify(src, Util.L('wrongJob')) end
        return nil
    end
    if not gateAllows(store, src) then return nil end
    return store, char
end

------------------------------------------------------------------------------
-- grid rows
------------------------------------------------------------------------------
local function priceLine(p)
    return ('<span style="color:%s;">%s</span>'):format(Config.PriceColour, Util.escape(Util.L('gridPrice', Util.fmt(p))))
end

local function sendRows(src, rows)
    TriggerClientEvent('vorp_inventory:ReloadStoreInventory', src, json.encode({ itemList = rows, action = 'setSecondInventoryItems' }))
end

local function npcRows(store)
    local rows = {}
    for i, e in ipairs(store.sell) do
        local isWeapon = e.type == 'item_weapon'
        local desc = priceLine(e.price)
        rows[#rows + 1] = {
            id = i,
            name = e.name,
            label = isWeapon and WeaponLabel(e.name) or e.label,
            count = isWeapon and 1 or Config.NpcStores.shownStock,
            limit = isWeapon and 1 or -1,
            type = e.type,
            price = e.price,
            desc = desc,
            metadata = { description = desc },
            sortingnumber = i,
            forsale = true,
            infinite = not isWeapon,
        }
    end
    return rows
end

local function weaponConditions(stock)
    if #stock.weapons == 0 then return {} end
    local ok, on = pcall(function() return Inv:IsWeaponDegradationEnabled() end)
    if not ok or not on then return {} end
    local ids, marks = {}, {}
    for _, w in ipairs(stock.weapons) do
        ids[#ids + 1] = w.id
        marks[#marks + 1] = '?'
    end
    local okq, rows = pcall(MySQL.query.await,
        'SELECT id, degradation, damage, dirt, soot, tier FROM loadout WHERE id IN (' .. table.concat(marks, ',') .. ')', ids)
    local out = {}
    if okq and type(rows) == 'table' then
        for _, r in ipairs(rows) do out[tonumber(r.id)] = r end
    end
    return out
end

local function pct(v)
    v = tonumber(v) or 0
    return math.max(0, math.min(100, math.floor(v * 100 + 0.5)))
end

-- vorp_inventory puts labels, metadata.tooltip and metadata.image into its HTML
-- unescaped. Stocked metadata comes from players, so the copy shown to other
-- players is made inert here (the stored metadata is not touched).
local function safeLabel(s)
    return (tostring(s or ''):gsub('[<>"\'`&]', ''))
end

local function safeDisplayMeta(meta)
    if type(meta.label) == 'string' then meta.label = safeLabel(meta.label) end
    if meta.tooltip ~= nil then meta.tooltip = Util.escape(tostring(meta.tooltip)) end
    if meta.image ~= nil and not tostring(meta.image):match('^[%w_%-%.]+$') then meta.image = nil end
    return meta
end

function ShopRows(shop, isOwner)
    local stock = shop.stock
    local rows = {}
    local notForSale = ('<span style="color:#c0392b;">%s</span> '):format(Util.escape(Util.L('gridNotForSale')))
    for _, r in ipairs(stock.items) do
        if r.forsale or isOwner then
            local desc = priceLine(r.price)
            local own = type(r.metadata) == 'table' and r.metadata.description
            if type(own) == 'string' and own ~= '' then desc = desc .. '<br>' .. Util.escape(own) end
            if not r.forsale then desc = notForSale .. desc end
            local meta = safeDisplayMeta(Util.copy(r.metadata))
            meta.description = desc
            meta.orgdescription = nil
            rows[#rows + 1] = {
                id = r.uid, name = r.itemname, label = safeLabel(type(meta.label) == 'string' and meta.label or r.label),
                count = r.itemcount, limit = -1, type = 'item_standard', price = r.price,
                desc = desc, metadata = meta, sortingnumber = r.sortingnumber, forsale = r.forsale, infinite = false,
            }
        end
    end
    local cond = weaponConditions(stock)
    for _, w in ipairs(stock.weapons) do
        if w.forsale or isOwner then
            local desc = priceLine(w.price)
            local c = cond[w.id]
            if c then
                desc = desc .. '<br>' .. Util.escape(Util.L('gridCondition', pct(c.degradation), pct(c.damage), pct(c.dirt), pct(c.soot), math.floor(tonumber(c.tier) or 0)))
            end
            if not w.forsale then desc = notForSale .. desc end
            rows[#rows + 1] = {
                id = w.id, name = w.name, label = WeaponLabel(w.name), count = 1, limit = 1, type = 'item_weapon',
                price = w.price, desc = desc, metadata = { description = desc }, sortingnumber = w.sortingnumber,
                forsale = w.forsale, infinite = false,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.sortingnumber ~= b.sortingnumber then return a.sortingnumber < b.sortingnumber end
        if a.type ~= b.type then return a.type == 'item_standard' end
        return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
    end)
    return rows
end

-- re-send the grid this player has open (an empty list when nothing valid is open)
function PushGrid(src, empty)
    if empty then return sendRows(src, {}) end
    local v = Viewers[src]
    if not v then return sendRows(src, {}) end
    if v.kind == 'npc' then
        local store = NpcStores[v.id]
        return sendRows(src, store and npcRows(store) or {})
    end
    local shop = GetShop(v.kind, v.id)
    -- staff opened it from vorp_admin: the owner's view, repossessed shops included
    if v.admin then return sendRows(src, shop and ShopRows(shop, true) or {}) end
    if not shop or not ShopLive(shop) then return sendRows(src, {}) end
    sendRows(src, ShopRows(shop, CanManage(GetChar(src), shop)))
end

-- every other viewer of the same pool gets a refresh ~250 ms later, coalesced
local pendingPools = {}
function ScheduleRefresh(shop)
    local stock = shop.stock
    if pendingPools[stock] then return end
    pendingPools[stock] = true
    SetTimeout(250, function()
        pendingPools[stock] = nil
        for src, v in pairs(Viewers) do
            if v.kind ~= 'npc' then
                local s = GetShop(v.kind, v.id)
                if s and s.stock == stock then PushGrid(src) end
            end
        end
    end)
end

------------------------------------------------------------------------------
-- visits
------------------------------------------------------------------------------
local function tellEnded(src)
    if GetPlayerName(src) then TriggerClientEvent('pup_mercantile:visit:ended', src) end
end

-- apply what the visitor changed (name, blip) and log it; then forget the visit
function EndVisit(src, notifyClient)
    local v = Visits[src]
    if not v then return end
    Visits[src] = nil
    local vw = Viewers[src]
    if vw and vw.kind == v.kind and vw.id == v.id then Viewers[src] = nil end

    local shop = GetShop(v.kind, v.id)
    if shop then
        local changed = false
        if v.pendingName and v.pendingName ~= shop.name then shop.name = v.pendingName changed = true end
        if v.pendingBlip ~= nil and v.pendingBlip ~= shop.blip then shop.blip = v.pendingBlip changed = true end
        local moved = Util.dist(v.startCoords, shop.coords) > 0.01
        if changed then
            SaveShop(shop)
            BroadcastShop(shop)
        end
        if changed or moved then
            local function c(t) return ('%.2f, %.2f, %.2f'):format(t.x, t.y, t.z) end
            Log({
                title = Util.L('logInfo', shop.name), colour = Colours.setup, src = src, shop = shop,
                fields = {
                    { 'Name', v.startName .. ' -> ' .. shop.name },
                    { 'Visible', tostring(v.startBlip == 1) .. ' -> ' .. tostring(shop.blip == 1) },
                    { 'Coordinates', c(v.startCoords) .. ' -> ' .. c(shop.coords) },
                },
            })
        end
    end
    if notifyClient then tellEnded(src) end
end

-- the visit, its shop and character, when the visitor may still act on it
-- a visit in paid-move mode only answers the move itself (allowMoving)
function LiveVisit(src, needManage, allowMoving)
    local v = Visits[src]
    if not v then return nil end
    if v.moving and not allowMoving then return nil end
    local char = GetChar(src)
    if not char or tonumber(char.charIdentifier) ~= v.charid then
        EndVisit(src, true)
        return nil
    end
    local shop = GetShop(v.kind, v.id)
    if not shop or not ShopLive(shop) then
        EndVisit(src, true)
        return nil
    end
    if not v.moving then
        local pos = PlayerPos(src)
        if pos and Util.dist(pos, shop.coords) > ShopReach() then
            EndVisit(src, true)
            return nil
        end
    end
    local manage = CanManage(char, shop)
    if needManage and not manage then return nil end
    return v, shop, char, manage
end

local function startVisit(src, shop, char)
    if Visits[src] then EndVisit(src, false) end
    Visits[src] = {
        kind = shop.kind, id = shop.id, charid = tonumber(char.charIdentifier),
        manage = CanManage(char, shop),
        startName = shop.name, startBlip = shop.blip,
        startCoords = { x = shop.coords.x, y = shop.coords.y, z = shop.coords.z },
    }
    return Visits[src]
end

-- end every visit and open grid on a shop that has closed (repo, disabled, deleted)
function CloseShopForEveryone(shop)
    for src, v in pairs(Visits) do
        if v.kind == shop.kind and v.id == shop.id then EndVisit(src, true) end
    end
    for src, v in pairs(Viewers) do
        if v.kind == shop.kind and v.id == shop.id then
            Viewers[src] = nil
            TriggerClientEvent('pup_mercantile:visit:ended', src)
        end
    end
end

local function gridInfo(shop, owner)
    local buy = {}
    for _, b in ipairs(shop.stock.buyitems) do
        buy[#buy + 1] = { name = b.name, price = b.price, label = b.label, amount = b.amount }
    end
    return {
        shoptype = shop.kind == 'player' and 2 or 3,
        isowner = owner and 1 or 0,
        buyitems = buy,
        society = shop.kind == 'society' and shop.society or nil,
    }
end

function OpenShopGrid(src, shop, char)
    local info = gridInfo(shop, CanManage(char, shop))
    Viewers[src] = { kind = shop.kind, id = shop.id }
    TriggerClientEvent('vorp_inventory:OpenStoreInventory', src, shop.name, shop.id, shop.stock.slots, info)
    PushGrid(src)
end

-- staff, from vorp_admin: the shop's real grid with the owner's controls, from anywhere.
-- No visit is started and nobody becomes owner; the viewer row carries admin = true.
function OpenAdminGrid(src, shop)
    Viewers[src] = { kind = shop.kind, id = shop.id, admin = true }
    TriggerClientEvent('pup_mercantile:admin:viewing', src, shop.kind, shop.id)
    TriggerClientEvent('vorp_inventory:OpenStoreInventory', src, shop.name, shop.id, shop.stock.slots, gridInfo(shop, true))
    PushGrid(src)
end

-- the shop a staff viewer has open, while they still hold the vorp_admin permission.
-- The permission check may wait, so the viewer row is read again afterwards.
function AdminViewShop(src)
    local v = Viewers[src]
    if not v or not v.admin or not ShopsReady or not GetChar(src) then return nil end
    if not StaffMayManage(src) then
        if Viewers[src] == v then
            Viewers[src] = nil
            Notify(src, Util.L('adminViewEnded'))
            TriggerClientEvent('pup_mercantile:visit:ended', src)
        end
        return nil
    end
    if Viewers[src] ~= v then return nil end
    return GetShop(v.kind, v.id), v
end

------------------------------------------------------------------------------
-- net events: visits and grids
------------------------------------------------------------------------------
local function nearestShopWithId(src, id)
    local pos = PlayerPos(src)
    local best, bestD
    for _, kind in ipairs({ 'player', 'society' }) do
        local s = GetShop(kind, id)
        if s and ShopLive(s) then
            local d = pos and Util.dist(pos, s.coords) or 0
            if d <= ShopReach() and (not bestD or d < bestD) then best, bestD = s, d end
        end
    end
    return best
end

RegisterNetEvent('pup_mercantile:visit:begin', function(kind, id)
    local src = source
    local char = GetChar(src)
    if not ShopsReady or not char then
        if char then Notify(src, Util.L('shopsLoading')) end
        return TriggerClientEvent('pup_mercantile:visit:refused', src)
    end
    local shop = GetShop(kind, id)
    local pos = PlayerPos(src)
    if not shop or not ShopLive(shop) or (pos and Util.dist(pos, shop.coords) > ShopReach()) then
        return TriggerClientEvent('pup_mercantile:visit:refused', src)
    end
    startVisit(src, shop, char)
    TriggerClientEvent('pup_mercantile:visit:started', src, shop.kind, shop.id, CanManage(char, shop))
end)

-- name and blip changes from the dashboard; written when the visit ends
RegisterNetEvent('pup_mercantile:visit:pending', function(name, blip)
    local src = source
    local v = LiveVisit(src, true)
    if not v then return end
    if name ~= nil then
        local clean = Util.cleanName(name)
        if clean then v.pendingName = clean end
    end
    if blip ~= nil then v.pendingBlip = (blip == true or tonumber(blip) == 1) and 1 or 0 end
end)

RegisterNetEvent('pup_mercantile:visit:end', function()
    EndVisit(source, false)
end)

RegisterNetEvent('pup_mercantile:grid:open', function(kind, id)
    local src = source
    local char = GetChar(src)
    if not ShopsReady or not char then return TriggerClientEvent('pup_mercantile:visit:refused', src) end
    local v = Visits[src]
    local shop
    if v then
        local _, s = LiveVisit(src)
        shop = s
    else
        -- adopt a visit at whichever shop with this id the player is standing at
        local s = (kind and GetShop(kind, id)) or nil
        if s then
            local pos = PlayerPos(src)
            if not ShopLive(s) or (pos and Util.dist(pos, s.coords) > ShopReach()) then s = nil end
        end
        shop = s or nearestShopWithId(src, id)
        if shop then startVisit(src, shop, char) end
    end
    if not shop or not ShopLive(shop) then
        return TriggerClientEvent('pup_mercantile:visit:refused', src)
    end
    OpenShopGrid(src, shop, char)
end)

RegisterNetEvent('pup_mercantile:grid:closed', function()
    Viewers[source] = nil
end)

RegisterNetEvent('pup_mercantile:npc:open', function(idx)
    local src = source
    local store = NpcCheck(src, idx)
    if not store then return TriggerClientEvent('pup_mercantile:visit:refused', src) end
    local mult = Misc.ecoMultiplier(src, store.name)
    local buy, sell = {}, {}
    for _, b in ipairs(store.buy) do
        buy[#buy + 1] = { name = b.name, price = Util.fmt(b.price * mult) }
    end
    for _, e in ipairs(store.sell) do
        sell[#sell + 1] = { name = e.name, label = e.label, price = e.price, type = e.type }
    end
    Viewers[src] = { kind = 'npc', id = store.idx }
    TriggerClientEvent('vorp_inventory:OpenStoreInventory', src, store.name, store.idx, #store.sell,
        { shoptype = 1, isowner = 0, buyitems = buy, sellitems = sell })
    PushGrid(src)
end)

-- With an NPC store index the player is not viewing, opens it through the normal
-- NPC flow (all checks run again); otherwise redraws the open grid.
RegisterNetEvent('pup_mercantile:reloadStoreInventory', function(storeIdx)
    local src = source
    if not GetChar(src) then return end
    local idx = tonumber(storeIdx)
    local v = Viewers[src]
    if idx and NpcStores[idx] and not (v and v.kind == 'npc' and v.id == idx) then
        if not RateOk(src) then return end
        if not NpcCheck(src, idx) then return end
        return TriggerClientEvent('pup_mercantile:openStore', src, idx)
    end
    PushGrid(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    EndVisit(src, false)
    Viewers[src] = nil
    lastTransfer[src] = nil
end)

-- a character switch ends whatever the previous character had open
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    if Visits[src] then
        Visits[src].pendingName, Visits[src].pendingBlip = nil, nil
        EndVisit(src, true)
    end
    Viewers[src] = nil
end)

-- shops that close while someone is inside, or staff who lose their rank, are caught here
CreateThread(function()
    while true do
        Wait(5000)
        for src, v in pairs(Visits) do
            if not GetPlayerName(src) then
                Visits[src] = nil
            else
                local live, _, _, manage = LiveVisit(src, false, true)
                if live and live.manage and not manage then EndVisit(src, true) end
            end
        end
    end
end)
