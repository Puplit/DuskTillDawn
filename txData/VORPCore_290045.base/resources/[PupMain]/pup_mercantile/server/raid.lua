-- pup_mercantile | law raids on player shops
-- Only rows on sale are seized; shelved rows and weapons are never touched.

local lastShopRaid = {}  -- [shopId] = os.time() of the last raid
local lastAsk = {}       -- [src] = GetGameTimer() of the last raid request
local raiding = {}       -- [shopId] = true while a raid runs

local function mdtRes() return Config.Raid.mdtResource end

local function mdtCall(name, ...)
    local res = mdtRes()
    if not ResourceUp(res) then return false, 'down' end
    local args = table.pack(...)
    return pcall(function()
        local proxy = exports[res]
        return proxy[name](proxy, table.unpack(args, 1, args.n))
    end)
end

-- pup-mdt's law jobs as a set, or nil when pup-mdt cannot answer
local function lawJobs()
    local ok, list = mdtCall('GetLawJobs')
    if not ok or type(list) ~= 'table' then return nil end
    local set = {}
    for _, j in pairs(list) do
        if type(j) == 'string' then set[j] = true end
    end
    return set
end

-- pup-mdt's CONTRABAND list as { [name] = label }, or nil when pup-mdt cannot answer
local function contraband()
    local ok, list = mdtCall('GetContrabandItems')
    if not ok or type(list) ~= 'table' then return nil end
    local set = {}
    for k, v in pairs(list) do
        if type(k) == 'string' then set[k] = tostring(v) end
    end
    return set
end

-- the law jobs for the client's prompt hint (the server decides again on every raid)
function RaidJobsHint()
    if not Config.Raid.enabled then return nil end
    local set = lawJobs()
    if not set then return nil end
    local out = {}
    for j in pairs(set) do out[#out + 1] = j end
    return out
end

-- pup-mdt came up (or restarted): give every client the law jobs for the prompt
AddEventHandler('onResourceStart', function(res)
    if res ~= mdtRes() then return end
    SetTimeout(3000, function()
        local hint = RaidJobsHint()
        if hint then TriggerClientEvent('pup_mercantile:raid:jobs', -1, hint) end
    end)
end)

-- every rule but the cooldown; returns shop, char or nil, message
local function raidCheck(src, id)
    if not Config.Raid.enabled then return nil, nil, Util.L('raidOff') end
    if not ShopsReady then return nil, nil, Util.L('shopsLoading') end
    local char = GetChar(src)
    if not char then return nil end
    if not ResourceUp(mdtRes()) then return nil, nil, Util.L('raidNoMdt') end
    local jobs = lawJobs()
    if not jobs then return nil, nil, Util.L('raidNoMdt') end
    if not jobs[tostring(char.job)] then return nil, nil, Util.L('raidNotLaw') end
    if (tonumber(char.jobGrade) or -1) < Config.Raid.minGrade then
        return nil, nil, Util.L('raidLowGrade', Config.Raid.minGrade)
    end
    local okd, onDuty = mdtCall('IsPlayerOnDuty', src)
    if not okd then return nil, nil, Util.L('raidNoMdt') end
    if onDuty ~= true then return nil, nil, Util.L('raidOffDuty') end
    -- the calls above went to another resource: read the world again from here on
    char = GetChar(src)
    if not char then return nil end
    local shop = Shops.player[id]
    if not shop or not ShopLive(shop) then return nil, nil, Util.L('raidNoShop') end
    local pos = PlayerPos(src)
    if not pos or Util.dist(pos, shop.coords) > ShopReach() then return nil, nil, Util.L('raidTooFar') end
    return shop, char
end

local function itemList(entries)
    local parts = {}
    for _, e in ipairs(entries) do parts[#parts + 1] = ('%s x%d'):format(e.label, e.count) end
    return table.concat(parts, ', ')
end

local function itemLines(entries)
    local parts = {}
    for _, e in ipairs(entries) do parts[#parts + 1] = ('- %s x%d'):format(e.label, e.count) end
    return table.concat(parts, '\n')
end

local function tellOwner(shop, seized, stationLabel)
    if shop.charid == 0 then return end
    local online = OnlineByCharId(shop.charid)
    if #seized > 0 then
        if online then Notify(online, Util.L('raidOwnerTip', shop.name, itemList(seized)), 10000) end
        SendMail(shop.charid, Util.L('mailRaidSubject', shop.name),
            Util.L('mailRaidBody', shop.name, shop.id, itemLines(seized), stationLabel or '?'), Config.Raid.mailFrom)
    else
        if online then Notify(online, Util.L('raidOwnerNothing', shop.name), 10000) end
        SendMail(shop.charid, Util.L('mailRaidSubject', shop.name),
            Util.L('mailRaidNothing', shop.name, shop.id), Config.Raid.mailFrom)
    end
end

-- puts a reserved amount back on its row (the row is re-added if something removed it)
local function giveBack(stock, e)
    if not FindItemRow(stock, e.row.uid) then stock.items[#stock.items + 1] = e.row end
    e.row.itemcount = e.row.itemcount + e.count
end

-- runs inside the shop's purchase lock
local function seize(src, shop, char, lease, wanted)
    local stock = shop.stock

    -- only what a customer can see can be searched: a shop with nothing on sale is refused
    -- (no cooldown, no letter to the owner, no log)
    local onSale = false
    for _, r in ipairs(stock.items) do
        if r.forsale and r.itemcount > 0 then onSale = true break end
    end
    if not onSale then return Notify(src, Util.L('raidNothingOnSale', shop.name), 6000) end

    -- the rows to take: ON SALE only, contraband only, stackable goods only
    local entries = {}
    for _, r in ipairs(stock.items) do
        if r.forsale and wanted[r.itemname] and r.itemcount > 0 and not IsWeaponName(r.itemname) then
            entries[#entries + 1] = { row = r, name = r.itemname, count = r.itemcount,
                metadata = Util.copy(r.metadata), label = r.label }
        end
    end

    -- reserve everything first, as a sale does, so nothing is sold twice while we wait
    for _, e in ipairs(entries) do e.row.itemcount = e.row.itemcount - e.count end

    local fromName = ('shop "%s" (#%d), owner charid %d'):format(shop.name, shop.id, shop.charid)
    local seized, left = {}, 0
    local stationLabel
    for i, e in ipairs(entries) do
        local stored = false
        -- stop at once if the lock was taken away (pup-mdt stopped) or the shop went
        if LeaseLive(lease) and Shops.player[shop.id] == shop then
            local ok, done, _, label = LeaseWait(lease, mdtRes(), mdtCall, 'SeizeItemToEvidence', src,
                { name = e.name, amount = e.count, metadata = e.metadata, label = e.label },
                { at = shop.coords, fromName = fromName, fromCharid = shop.charid })
            stored = ok and done == true
            if stored then stationLabel = stationLabel or tostring(label or '?') end
        end
        if stored then
            seized[#seized + 1] = e
            DropIfEmpty(stock, e.row)
        else
            giveBack(stock, e)
            left = left + 1
        end
        entries[i] = nil
    end
    SaveShop(shop)
    ScheduleRefresh(shop)
    -- a raid the locker refused outright does not start the cooldown
    if #seized > 0 or left == 0 then lastShopRaid[shop.id] = os.time() end

    -- the lawman hears only about rows that were on sale
    if #seized == 0 and left == 0 then
        Notify(src, Util.L('raidNothing', shop.name), 8000)
    elseif #seized == 0 then
        Notify(src, Util.L('raidFailed'), 8000)
    else
        Notify(src, Util.L('raidSeized', shop.name, itemList(seized), stationLabel or '?'), 12000)
        if left > 0 then Notify(src, Util.L('raidSomeLeft', left), 8000) end
    end

    if #seized > 0 or left == 0 then tellOwner(shop, seized, stationLabel) end

    local fields = {
        { 'Lawman', ('%s (charid %s, job %s %s)'):format(FullName(char), tostring(char.charIdentifier),
            tostring(char.job), tostring(char.jobGrade)) },
        { 'Owner charid', shop.charid },
    }
    if #seized > 0 then
        fields[#fields + 1] = { 'Seized', itemLines(seized) }
        fields[#fields + 1] = { 'Evidence locker', stationLabel or '?' }
    end
    if left > 0 then fields[#fields + 1] = { 'Not stored, left in the shop', left .. ' stack(s)' } end
    Log({
        title = Util.L(#seized > 0 and 'logRaid' or 'logRaidNothing'), colour = Colours.repo,
        src = src, shop = shop, staffOnly = true, fields = fields,
    })
end

RegisterNetEvent('pup_mercantile:raid:start', function(id)
    local src = source
    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < Config.Raid.lawmanSeconds * 1000 then
        return Notify(src, Util.L('raidSlow'))
    end
    lastAsk[src] = now
    id = Util.whole(id, 1)
    if not id then return end

    local shop, char, why = raidCheck(src, id)
    if not shop then
        if why then Notify(src, why, 6000) end
        return
    end
    local last = lastShopRaid[shop.id]
    local wait = last and (last + Config.Raid.cooldownMinutes * 60 - os.time()) or 0
    if wait > 0 then return Notify(src, Util.L('raidCooldown', math.ceil(wait / 60)), 6000) end
    if raiding[shop.id] then return Notify(src, Util.L('raidBusy')) end

    local wanted = contraband()
    if not wanted then return Notify(src, Util.L('raidNoMdt'), 6000) end

    raiding[shop.id] = true
    local ok, err = pcall(function()
        WithLock(src, shop, function(lease)
            -- everything again: the lists above came from another resource
            local again, char2, why2 = raidCheck(src, id)
            if again ~= shop or tonumber(char2.charIdentifier) ~= tonumber(char.charIdentifier) then
                if why2 then Notify(src, why2, 6000) end
                return
            end
            if not LeaseLive(lease) then return end
            seize(src, shop, char2, lease, wanted)
        end)
    end)
    raiding[shop.id] = nil
    if not ok then print('^1[pup_mercantile]^7 raid failed: ' .. tostring(err)) end
end)

AddEventHandler('playerDropped', function()
    lastAsk[source] = nil
end)
