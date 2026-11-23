-- pup_mercantile | the shop model: memory, stock rules, saving and world sync

Shops = { player = {}, society = {} }
ShopsReady = false
Catalogue = {}      -- array of { name, label } from the items table
CatalogueByName = {}

-- unique stock row ids: start at start-up time in ms and count up
local uidCounter = os.time() * 1000
function NextUid()
    uidCounter = uidCounter + 1
    return uidCounter
end

function WeaponLabel(name)
    return (Config.WeaponLabels and Config.WeaponLabels[name]) or name
end

function ItemLabel(name)
    local c = CatalogueByName[name]
    return c and c.label or name
end

function IsWeaponName(name)
    if type(name) ~= 'string' then return false end
    if name:upper():sub(1, 7) == 'WEAPON_' then return true end
    local c = CatalogueByName[name]
    return c ~= nil and c.type == 'item_weapon'
end

------------------------------------------------------------------------------
-- JSON in and out
------------------------------------------------------------------------------
local function decode(str, default)
    if type(str) ~= 'string' or str == '' then return default end
    local ok, v = pcall(json.decode, str)
    if not ok or type(v) ~= 'table' then return default end
    return v
end

local function encodeArray(t)
    if type(t) ~= 'table' or #t == 0 then return '[]' end
    return json.encode(t)
end

local function normItems(list)
    local out = {}
    for _, r in ipairs(type(list) == 'table' and list or {}) do
        if type(r) == 'table' and type(r.itemname) == 'string' then
            local meta = r.metadata
            if type(meta) == 'string' then meta = decode(meta, {}) end
            out[#out + 1] = {
                itemname = r.itemname,
                itemcount = math.max(0, math.floor(tonumber(r.itemcount) or 0)),
                price = Util.round2(tonumber(r.price) or 0),
                metadata = type(meta) == 'table' and meta or {},
                label = tostring(r.label or r.itemname),
                sortingnumber = math.floor(tonumber(r.sortingnumber) or 0),
                forsale = r.forsale ~= false,
                uid = tonumber(r.uid),
            }
        end
    end
    return out
end

local function normWeapons(list)
    local out = {}
    for _, w in ipairs(type(list) == 'table' and list or {}) do
        if type(w) == 'table' and type(w.name) == 'string' and tonumber(w.id) then
            out[#out + 1] = {
                name = w.name,
                price = Util.round2(tonumber(w.price) or 0),
                id = math.floor(tonumber(w.id)),
                sortingnumber = math.floor(tonumber(w.sortingnumber) or 0),
                forsale = w.forsale ~= false,
            }
        end
    end
    return out
end

local function normBuy(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, b in ipairs(list) do
        if type(b) == 'table' and type(b.name) == 'string' then
            out[#out + 1] = {
                name = b.name,
                label = tostring(b.label or b.name),
                price = Util.round2(tonumber(b.price) or 0),
                amount = math.floor(tonumber(b.amount) or 0),
                resale = tonumber(b.resale) and Util.round2(tonumber(b.resale)) or nil,
            }
        end
    end
    return out
end

local function normCoords(str)
    local c = decode(str, nil)
    return Util.validCoords(c) or { x = 0.0, y = 0.0, z = 0.0 }
end

local function webhookOf(v)
    if type(v) ~= 'string' or v == '' or v == '{}' or v == '[]' then return '' end
    return v
end

local function boolish(v, default)
    if v == nil then return default end
    if type(v) == 'boolean' then return v end
    return (tonumber(v) or 0) ~= 0
end

function ShopFromRow(kind, r)
    local stock = {
        items = normItems(decode(r.items, {})),
        weapons = normWeapons(decode(r.weapons, {})),
        buyitems = normBuy(decode(r.buyitems, {})),
        slots = math.max(0, math.floor(tonumber(r.slots) or 0)),
    }
    for _, row in ipairs(stock.items) do
        if not row.uid then row.uid = NextUid() end
    end
    local shop = {
        kind = kind,
        id = math.floor(tonumber(r.id)),
        -- vorp_inventory writes the grid title as HTML; legacy names may predate the name rules
        name = (tostring(r.name or ''):gsub('[<>]', '')),
        coords = normCoords(r.coords),
        blip = (tonumber(r.blip) or 0) == 1 and 1 or 0,
        level = math.floor(tonumber(r.level) or 0),
        webhook = webhookOf(r.webhook),
        stock = stock,
    }
    if kind == 'player' then
        shop.identifier = tostring(r.identifier or '0')
        shop.charid = math.floor(tonumber(r.charidentifier) or 0)
        shop.ledger = Util.round2(tonumber(r.ledger) or 0)
        shop.taxledger = Util.round2(tonumber(r.taxledger) or 0)
        shop.repo = (tonumber(r.repo) or 0) == 1
        shop.manager = math.floor(tonumber(r.manager) or 0)
        stock.lockKey = 'p:' .. shop.id
    else
        shop.society = tostring(r.society or '0')
        shop.rank = math.floor(tonumber(r.rank) or 0)
        shop.enabled = boolish(r.enabled, true)
        stock.lockKey = 'S:' .. shop.id
    end
    return shop
end

------------------------------------------------------------------------------
-- shared society stock
------------------------------------------------------------------------------
function SharesStock(job)
    if not Config.SocietyShops.sharedStock then return false end
    for _, j in ipairs(Config.SocietyShops.separateStock or {}) do
        if j == job then return false end
    end
    return true
end

function PoolOf(job)
    for _, s in pairs(Shops.society) do
        if s.society == job and s.stock.shared then return s.stock end
    end
    return nil
end

-- merge every shop of each sharing business into one pool, shops taken in id order
function LinkSharedStock()
    local byJob = {}
    for _, s in pairs(Shops.society) do
        if SharesStock(s.society) then
            byJob[s.society] = byJob[s.society] or {}
            table.insert(byJob[s.society], s)
        end
    end
    for job, list in pairs(byJob) do
        table.sort(list, function(a, b) return a.id < b.id end)
        local pool = { items = {}, weapons = {}, buyitems = {}, slots = 0, shared = true, lockKey = 's:' .. job }
        local seenSerial, seenBuy = {}, {}
        for _, s in ipairs(list) do
            for _, row in ipairs(s.stock.items) do
                local found
                for _, p in ipairs(pool.items) do
                    if p.itemname == row.itemname and Util.sameIdentity(p.metadata, row.metadata) then found = p break end
                end
                if found then
                    if row.itemcount > found.itemcount then found.itemcount = row.itemcount end
                else
                    pool.items[#pool.items + 1] = row
                end
            end
            for _, w in ipairs(s.stock.weapons) do
                if not seenSerial[w.id] then seenSerial[w.id] = true pool.weapons[#pool.weapons + 1] = w end
            end
            for _, b in ipairs(s.stock.buyitems) do
                if not seenBuy[b.name] then seenBuy[b.name] = true pool.buyitems[#pool.buyitems + 1] = b end
            end
            if s.stock.slots > pool.slots then pool.slots = s.stock.slots end
        end
        if pool.slots <= 0 then pool.slots = Config.SocietyShops.startSlots end
        for _, s in ipairs(list) do s.stock = pool end
        if #list > 1 then SaveShop(list[1]) end
    end
end

------------------------------------------------------------------------------
-- stock rules
------------------------------------------------------------------------------
function UsedSlots(stock)
    local n = 0
    for _, r in ipairs(stock.items) do n = n + r.itemcount end
    return n + #stock.weapons
end

function FreeSlots(stock)
    return math.max(0, stock.slots - UsedSlots(stock))
end

function FindItemRow(stock, uid)
    uid = tonumber(uid)
    if not uid then return nil, nil end
    for i, r in ipairs(stock.items) do
        if r.uid == uid then return r, i end
    end
    return nil, nil
end

function FindWeapon(stock, serial)
    serial = tonumber(serial)
    if not serial then return nil, nil end
    for i, w in ipairs(stock.weapons) do
        if w.id == serial then return w, i end
    end
    return nil, nil
end

function FindBuy(stock, name)
    for i, b in ipairs(stock.buyitems) do
        if b.name == name then return b, i end
    end
    return nil, nil
end

function FindIdentityRow(stock, name, metadata, shelvedOnly)
    for _, r in ipairs(stock.items) do
        if r.itemname == name and Util.sameIdentity(r.metadata, metadata)
            and (not shelvedOnly or r.forsale == false) then
            return r
        end
    end
    return nil
end

function NextSortNumber(stock)
    local top = -1
    for _, r in ipairs(stock.items) do if r.sortingnumber > top then top = r.sortingnumber end end
    for _, w in ipairs(stock.weapons) do if w.sortingnumber > top then top = w.sortingnumber end end
    return top + 1
end

function NewItemRow(stock, name, count, price, metadata, label, forsale)
    local row = {
        itemname = name,
        itemcount = count,
        price = Util.round2(price),
        metadata = Util.copy(metadata or {}),
        label = label or ItemLabel(name),
        sortingnumber = NextSortNumber(stock),
        forsale = forsale ~= false,
        uid = NextUid(),
    }
    stock.items[#stock.items + 1] = row
    return row
end

-- the price a freshly bought-in row gets: an existing row's, else the remembered asking price, else the buy price
function PriceForIncoming(stock, name, buyPrice)
    for _, r in ipairs(stock.items) do
        if r.itemname == name and r.price > 0 then return r.price end
    end
    local b = FindBuy(stock, name)
    if b and b.resale and b.resale > 0 then return b.resale end
    return Util.round2(buyPrice)
end

-- goods bought from a customer go onto the shelf, off sale
function ShelveIncoming(stock, name, count, metadata, label, buyPrice)
    local row = FindIdentityRow(stock, name, metadata, true)
    if row then
        row.itemcount = row.itemcount + count
        return row
    end
    return NewItemRow(stock, name, count, PriceForIncoming(stock, name, buyPrice), metadata, label, false)
end

-- a sold-out row is removed; its asking price is remembered on the buy order first
function DropIfEmpty(stock, row)
    if row.itemcount > 0 then return end
    local b = FindBuy(stock, row.itemname)
    if b and row.price > 0 then b.resale = row.price end
    for i, r in ipairs(stock.items) do
        if r == row then table.remove(stock.items, i) break end
    end
end

function ReduceBuyOrder(stock, name, count)
    local b, i = FindBuy(stock, name)
    if not b then return end
    b.amount = b.amount - count
    if b.amount <= 0 then table.remove(stock.buyitems, i) end
end

------------------------------------------------------------------------------
-- who may do what
------------------------------------------------------------------------------
function ShopLive(shop)
    if not shop then return false end
    if Shops[shop.kind][shop.id] ~= shop then return false end
    if shop.kind == 'player' then return not shop.repo end
    return shop.enabled == true
end

function IsTrueOwner(char, shop)
    return char ~= nil and shop.kind == 'player' and tonumber(char.charIdentifier) == shop.charid
end

function CanManage(char, shop)
    if not char or not shop then return false end
    if shop.kind == 'player' then
        local cid = tonumber(char.charIdentifier)
        return cid == shop.charid or (shop.manager ~= 0 and cid == shop.manager)
    end
    if char.job ~= shop.society then return false end
    if IsBoss(char, shop.society) then return true end
    return (tonumber(char.jobGrade) or -1) >= (shop.rank or 0)
end

function GetShop(kind, id)
    id = tonumber(id)
    if not id or (kind ~= 'player' and kind ~= 'society') then return nil end
    return Shops[kind][math.floor(id)]
end

-- every shop that shares this shop's stock (itself included)
function PoolShops(shop)
    if shop.kind ~= 'society' or not shop.stock.shared then return { shop } end
    local out = {}
    for _, s in pairs(Shops.society) do
        if s.stock == shop.stock then out[#out + 1] = s end
    end
    return out
end

-- spacing: every non-repossessed player shop and every society shop, enabled or not
function TooClose(coords, ignore)
    local min = Config.Shops.minSpacing
    for _, s in pairs(Shops.player) do
        if s ~= ignore and not s.repo and Util.dist(s.coords, coords) < min then return true end
    end
    for _, s in pairs(Shops.society) do
        if s ~= ignore and Util.dist(s.coords, coords) < min then return true end
    end
    return false
end

------------------------------------------------------------------------------
-- purchase locks: one transaction per stock pool at a time
------------------------------------------------------------------------------
-- A lease can be taken away while its holder waits on another resource, so a call
-- that never returns cannot block the pool; box trade checks LeaseLive between steps.
local locks = {}  -- [lockKey] = lease

function TryLock(shop, src)
    local key = shop.stock.lockKey
    if locks[key] then return nil end
    local lease = { key = key, src = tonumber(src), live = true, waiting = nil }
    locks[key] = lease
    return lease
end

function Unlock(lease)
    if not lease then return end
    lease.live = false
    if locks[lease.key] == lease then locks[lease.key] = nil end
end

function LeaseLive(lease)
    return lease ~= nil and lease.live and locks[lease.key] == lease
end

-- calls fn while marking the lease as waiting on resource res
function LeaseWait(lease, res, fn, ...)
    if lease then lease.waiting = res end
    local out = table.pack(pcall(fn, ...))
    if lease then lease.waiting = nil end
    if not out[1] then error(out[2], 0) end
    return table.unpack(out, 2, out.n)
end

local function dropLeases(match, why)
    for key, lease in pairs(locks) do
        if match(lease) then
            lease.live = false
            locks[key] = nil
            print(('^3[pup_mercantile]^7 purchase lock on pool %s released: %s (player %s)')
                :format(tostring(key), why, tostring(lease.src)))
        end
    end
end

-- the resource a lease waits on stopped: its call will never answer
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then return end
    dropLeases(function(l) return l.waiting == res end, res .. ' stopped during a box trade')
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    -- only holds parked on a tracked outside call (box trade); other holders finish on their own
    dropLeases(function(l) return l.src == src and l.waiting ~= nil end, 'the holder left during a box trade')
end)

-- run fn(lease) while holding the pool lock; always releases it
function WithLock(src, shop, fn)
    local lease = TryLock(shop, src)
    if not lease then
        Notify(src, Util.L('busy'))
        return false
    end
    local ok, err = pcall(fn, lease)
    Unlock(lease)
    if not ok then print('^1[pup_mercantile]^7 ' .. tostring(err)) end
    return ok
end

------------------------------------------------------------------------------
-- saving: one full row update per change, written one at a time in order
------------------------------------------------------------------------------
local queue, queued, saving = {}, {}, false

local function writeShop(shop)
    if Shops[shop.kind][shop.id] ~= shop then return end
    local st = shop.stock
    local items, weapons, buy = {}, {}, {}
    for _, r in ipairs(st.items) do
        items[#items + 1] = {
            itemname = r.itemname, itemcount = r.itemcount, price = r.price,
            metadata = r.metadata, label = r.label, sortingnumber = r.sortingnumber,
            forsale = r.forsale, uid = r.uid,
        }
    end
    for _, w in ipairs(st.weapons) do
        weapons[#weapons + 1] = { name = w.name, price = w.price, id = w.id, sortingnumber = w.sortingnumber, forsale = w.forsale }
    end
    for _, b in ipairs(st.buyitems) do
        buy[#buy + 1] = { name = b.name, label = b.label, price = b.price, amount = b.amount, resale = b.resale }
    end
    local jItems, jWeapons, jBuy = encodeArray(items), encodeArray(weapons), encodeArray(buy)
    local coords = json.encode({ x = shop.coords.x, y = shop.coords.y, z = shop.coords.z })
    if shop.kind == 'player' then
        MySQL.update.await([[UPDATE playershops SET items = ?, weapons = ?, name = ?, slots = ?, coords = ?, owned = 1,
            blip = ?, ledger = ?, level = ?, taxledger = ?, repo = ?, buyitems = ?, webhook = ?, manager = ? WHERE id = ?]],
            { jItems, jWeapons, shop.name, st.slots, coords, shop.blip, shop.ledger, shop.level, shop.taxledger,
              shop.repo and 1 or 0, jBuy, shop.webhook or '', shop.manager, shop.id })
    else
        MySQL.update.await([[UPDATE society_shops SET items = ?, weapons = ?, slots = ?, level = ?, name = ?, coords = ?,
            `rank` = ?, blip = ?, buyitems = ?, webhook = ?, enabled = ? WHERE id = ?]],
            { jItems, jWeapons, st.slots, shop.level, shop.name, coords, shop.rank, shop.blip, jBuy,
              shop.webhook or '', shop.enabled and 1 or 0, shop.id })
        if st.shared then
            MySQL.update.await('UPDATE society_shops SET items = ?, weapons = ?, buyitems = ?, slots = ? WHERE society = ? AND id <> ?',
                { jItems, jWeapons, jBuy, st.slots, shop.society, shop.id })
        end
    end
end

function SaveShop(shop)
    local key = shop.kind .. ':' .. shop.id
    if queued[key] then return end
    queued[key] = true
    queue[#queue + 1] = shop
    if saving then return end
    saving = true
    CreateThread(function()
        while #queue > 0 do
            local s = table.remove(queue, 1)
            queued[s.kind .. ':' .. s.id] = nil
            local ok, err = pcall(writeShop, s)
            if not ok then print('^1[pup_mercantile]^7 saving shop failed: ' .. tostring(err)) end
        end
        saving = false
    end)
end

------------------------------------------------------------------------------
-- what clients are told about shops (never owner or manager ids)
------------------------------------------------------------------------------
local function visibleToWorld(shop)
    if shop.kind == 'player' then return not shop.repo end
    return shop.enabled == true
end

function ClientEntry(shop, char)
    return {
        kind = shop.kind,
        id = shop.id,
        name = shop.name,
        coords = shop.coords,
        blip = shop.blip == 1,
        mine = CanManage(char, shop),
        society = shop.kind == 'society' and shop.society or nil,
    }
end

function ShopListFor(src)
    local char = GetChar(src)
    local out = {}
    for _, kind in ipairs({ 'player', 'society' }) do
        for _, s in pairs(Shops[kind]) do
            if visibleToWorld(s) then out[#out + 1] = ClientEntry(s, char) end
        end
    end
    return out
end

-- tell every client about one shop (shown, changed, or gone)
function BroadcastShop(shop, removed)
    for _, pid in ipairs(GetPlayers()) do
        local p = tonumber(pid)
        if removed or not visibleToWorld(shop) or Shops[shop.kind][shop.id] ~= shop then
            TriggerClientEvent('pup_mercantile:shop:remove', p, shop.kind, shop.id)
        else
            TriggerClientEvent('pup_mercantile:shop:upsert', p, ClientEntry(shop, GetChar(p)))
        end
    end
end

function BroadcastAll()
    for _, pid in ipairs(GetPlayers()) do
        local p = tonumber(pid)
        TriggerClientEvent('pup_mercantile:shops:full', p, ShopListFor(p))
    end
end
