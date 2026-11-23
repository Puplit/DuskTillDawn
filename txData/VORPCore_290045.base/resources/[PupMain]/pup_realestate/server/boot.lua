-- pup_realestate | startup, loading and the periodic save

function S.newHouse(f)
    return {
        id = f.id, kind = f.kind or KIND_REAL,
        doors = f.doors or {}, other = f.other or {},
        range = f.range or 0, price = f.price or 0, tax = f.tax or 0,
        slots = U.slotCap(f.slots or 0), upgrade = f.upgrade or 0,
        furniture = f.furniture or {}, changing = f.changing, stash = f.stash,
        sellerIdent = f.sellerIdent or '', sellerChar = f.sellerChar or 0,
        owned = f.owned == true, buyerIdent = f.buyerIdent or '0', buyerChar = f.buyerChar or 0,
        keys = f.keys or {}, repo = f.repo == true,
        ledger = f.ledger or 0, taxledger = f.taxledger or 0,
        _dirty = {},
    }
end

local function spot(raw)
    local v = S.decode(raw, nil)
    if type(v) == 'table' and tonumber(v.x) and tonumber(v.y) and tonumber(v.z) then
        return { x = tonumber(v.x), y = tonumber(v.y), z = tonumber(v.z) }
    end
    return nil
end

local function list(raw)
    local v = S.decode(raw, {})
    return type(v) == 'table' and v or {}
end

local function houseFromRow(r)
    local furniture = list(r.furniture)
    return S.newHouse({
        id = U.int(r.id), kind = U.int(r.type) or KIND_REAL,
        doors = list(r.primarydoor), other = list(r.otherdoors),
        range = U.int(r.range) or 0, price = U.int(r.price) or 0, tax = U.int(r.tax) or 0,
        slots = U.int(r.invspace) or 0, upgrade = U.int(r.upgrade) or 0,
        furniture = furniture, changing = spot(r.changingroom), stash = spot(r.inventorylocation),
        sellerIdent = tostring(r.selleridentifier or ''), sellerChar = U.int(r.sellercharidentifier) or 0,
        owned = tonumber(r.owned) == 1, buyerIdent = tostring(r.buyeridentifier or '0'),
        buyerChar = U.int(r.buyercharidentifier) or 0, keys = list(r.keyholders), repo = tonumber(r.repoed) == 1,
        ledger = tonumber(r.ledger) or 0, taxledger = tonumber(r.taxledger) or 0,
    })
end

-- an unowned $0 house given a price again by the admin panel
function S.relist(id, price)
    local row = S.delisted[id]
    if not row then return nil end
    local h = houseFromRow(row)
    h.price = price
    S.delisted[id] = nil
    S.houses[id] = h
    S.readItemsColumn(id, row.items)
    S.save(h, 'price')
    S.ensureContainer(id)
    S.bridgeSync(h)
    return h
end

local function ensureSchema()
    local stmts = {
        [[CREATE TABLE IF NOT EXISTS `cron_state` (
            `name` varchar(64) NOT NULL, `lastrun` varchar(16) NOT NULL DEFAULT '', PRIMARY KEY (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
        'ALTER TABLE `housing_auctions` ADD COLUMN IF NOT EXISTS `topbank` varchar(50) DEFAULT NULL',
        'ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `motel` longtext DEFAULT NULL',
    }
    for _, q in ipairs(stmts) do
        local ok, err = pcall(MySQL.query.await, q)
        if not ok then Warn('schema step failed: %s', tostring(err)) end
    end
end

local function loadAll()
    local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM playerhousing')
    if not ok then
        Warn('could not read playerhousing: %s', tostring(rows))
        return false
    end
    for _, r in ipairs(rows or {}) do
        local id = U.int(r.id)
        local motelKey = tostring(r.motel or '0')
        if id then
            if motelKey ~= '0' and motelKey ~= '' then
                local m = U.motel(motelKey)
                S.motels[id] = {
                    id = id, motel = motelKey, owner = U.int(r.buyercharidentifier) or 0,
                    ownerIdent = tostring(r.buyeridentifier or ''),
                    slots = m and m.slots or (U.int(r.invspace) or 0),
                }
                S.readItemsColumn(id, r.items)
            elseif tonumber(r.owned) ~= 1 and (tonumber(r.price) or 0) <= 0 then
                S.delisted[id] = r
                print(('[pup_realestate] house %s cleared from the menu for being set to $0 (row kept; set a price in the admin panel to relist it)'):format(id))
            else
                S.houses[id] = houseFromRow(r)
                S.readItemsColumn(id, r.items)
            end
        end
    end
    return true
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(250) end
    Wait(500)
    ensureSchema()
    if not loadAll() then return end

    local waited = 0
    while GetResourceState('vorp_inventory') ~= 'started' and waited < 30000 do
        Wait(500)
        waited = waited + 500
    end
    for id in pairs(S.houses) do S.ensureContainer(id) end
    for id in pairs(S.motels) do S.ensureContainer(id) end

    S.ready = true
    S.bridgeBoot()
    S.rewriteReports(nil)
    local nh, nm = 0, 0
    for _ in pairs(S.houses) do nh = nh + 1 end
    for _ in pairs(S.motels) do nm = nm + 1 end
    print(('[pup_realestate] loaded %s houses and %s motel rooms'):format(nh, nm))
    Wait(2000)
    S.sendFull()
end)

-- periodic save: furniture from memory, and every storage report
CreateThread(function()
    while not S.ready do Wait(1000) end
    while true do
        Wait(math.max(1, Config.SaveIntervalMinutes) * 60000)
        for _, h in pairs(S.houses) do S.save(h, 'furniture') end
        S.rewriteReports(nil)
    end
end)
