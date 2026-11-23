-- pup_camps | camp stash (vorp_inventory clan panel) and the storage-box bridge for pup-misc

local Viewers = {}  -- [campId] = { [src] = true } players with the panel open
local StaffView = {} -- [src] = campId: staff who opened this stash from vorp_admin (AdminOpenStash)

-- a staff viewer of this camp's stash, while vorp_admin still grants manage_camps
local function staffViewing(src, campId)
    local id = StaffView[src]
    if not id or id ~= tonumber(campId) then return false end
    local ok, yes = pcall(Integrations.adminAllowed, src, 'manage_camps')
    if ok and yes then return true end
    StaffView[src] = nil
    return false
end

------------------------------------------------------------------------------ metadata

-- the panel's own container descriptor counts as "no metadata"
local function cleanMeta(m)
    if type(m) ~= 'table' then return {} end
    local n = 0
    for _ in pairs(m) do n = n + 1 end
    if n == 0 then return {} end
    if n == 2 and m.type == 'clan' and m.id ~= nil then return {} end
    return m
end
CleanMeta = cleanMeta

local function canon(v)
    local t = type(v)
    if t ~= 'table' then return t .. ':' .. tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. '=' .. canon(v[k]) end
    return '{' .. table.concat(parts, ',') .. '}'
end

local function metaEqual(a, b)
    return canon(cleanMeta(a)) == canon(cleanMeta(b))
end
MetaEqual = metaEqual

local function hasMeta(m) return next(cleanMeta(m)) ~= nil end

------------------------------------------------------------------------------ helpers

local function stashTotal(camp)
    local n = 0
    for _, e in ipairs(camp.inventory) do n = n + e.count end
    return n
end
StashTotal = stashTotal

local function stashList(camp)
    local list = {}
    for i, e in ipairs(camp.inventory) do
        list[i] = { name = e.name, label = e.label, count = e.count, type = e.type, metadata = e.metadata, id = e.id, limit = e.count }
    end
    return list
end
StashList = stashList

-- may this context use the stash for `what` ('open', 'put', 'take')? returns camp, looting, message
local function access(ctx, campId, what)
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return nil end
    -- staff opened it from the admin panel: owner rights, from anywhere, repossessed or not
    if staffViewing(ctx.src, camp.id) then return camp, false end
    local rank, leader = RankOf(camp, ctx.charid, ctx.identifier)
    local member = rank ~= nil or leader
    local looting = false
    if member then
        if camp.repo then return nil, false, L('camp_shut') end
        local need = Config.Permissions[what == 'open' and 'stashOpen' or (what == 'put' and 'stashPut' or 'stashTake')]
        if not U.meets(rank, leader, need) then return nil, false, L('rank_too_low', U.rankLabel(need)) end
    else
        if camp.repo or not LootAllowed(camp, ctx.src, ctx.charid) then return nil, false, L('not_member') end
        looting = true
    end
    if not AtCamp(ctx.src, camp) then return nil, false, L('too_far') end
    return camp, looting
end
StashAccess = access

local function reloadFor(src, camp)
    local payload = {
        action = 'setSecondInventoryItems',
        itemList = stashList(camp),
        info = { clan = camp.id, isowner = 1, capacity = camp.invlimit },
    }
    TriggerClientEvent('vorp_inventory:ReloadClanInventory', src, json.encode(payload))
end

function ReloadStashViewers(camp)
    local v = Viewers[camp.id]
    if not v then return end
    for src in pairs(v) do
        if GetPlayerName(src) then reloadFor(src, camp) else v[src] = nil end
    end
end

local function blocked(name)
    if Config.Camp.stashBlacklist[name] then return L('storage_blacklisted') end
    local ok, why = pcall(function() return exports.vorp_inventory:IsItemRestricted('clan', name) end)
    if ok and type(why) == 'string' and why ~= '' then return why end
    return nil
end

local function mergeIn(camp, name, label, count, meta)
    meta = cleanMeta(meta)
    for _, e in ipairs(camp.inventory) do
        if e.name == name and e.type ~= 'item_weapon' and metaEqual(e.metadata, meta) then
            e.count = e.count + count
            return e
        end
    end
    local e = { name = name, label = label or name, count = count, type = 'item_standard', metadata = meta, id = NextStashId(camp) }
    camp.inventory[#camp.inventory + 1] = e
    return e
end

local function decodeArg(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or #raw > 30000 then return nil end
    local ok, v = pcall(json.decode, raw)
    if ok and type(v) == 'table' then return v end
    return nil
end

local gate = {}  -- [src] = last stash action (ms)
local function slow(src)
    local now = GetGameTimer()
    if gate[src] and now - gate[src] < 250 then return true end
    gate[src] = now
    return false
end

------------------------------------------------------------------------------ open / close

Handle('stashOpen', function(ctx, campId)
    local camp, _, why = access(ctx, campId, 'open')
    if not camp then return false, why end
    if MenuLocks[camp.id] and MenuLocks[camp.id] ~= ctx.src and not LockFree(camp.id, ctx.src) then
        return false, L('menu_in_use')
    end
    MenuLocks[camp.id] = ctx.src
    Viewers[camp.id] = Viewers[camp.id] or {}
    Viewers[camp.id][ctx.src] = true
    TriggerClientEvent('vorp_inventory:OpenClanInventory', ctx.src, L('storage_title'), camp.id, camp.invlimit)
    reloadFor(ctx.src, camp)
    return true
end, { gapMs = 1000 })

Handle('stashClosed', function(ctx)
    for id, v in pairs(Viewers) do
        if v[ctx.src] then
            v[ctx.src] = nil
            if MenuLocks[id] == ctx.src then MenuLocks[id] = nil end
        end
    end
    StaffView[ctx.src] = nil
    return true
end)

-- vorp_admin "Open storage": the real stash panel with the leader's controls, from anywhere.
-- manage_camps is checked again here and on every take, deposit and reorder.
exports('AdminOpenStash', function(src, campId)
    src = tonumber(src)
    if not Ready then return false, 'pup_camps is still loading.' end
    local ctx = src and Ctx(src)
    if not ctx then return false, 'No character loaded.' end
    local okP, yes = pcall(Integrations.adminAllowed, src, 'manage_camps')
    if not okP or not yes then return false, 'Not allowed (manage_camps).' end
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return false, 'No camp with that id.' end

    -- leave any stash panel this player had open first
    for id, v in pairs(Viewers) do
        if v[src] then
            v[src] = nil
            if MenuLocks[id] == src then MenuLocks[id] = nil end
        end
    end
    StaffView[src] = camp.id
    Viewers[camp.id] = Viewers[camp.id] or {}
    Viewers[camp.id][src] = true
    -- the client reports the close back (stashClosed) only for a panel it knows about
    TriggerClientEvent('pup_camps:cl:staffStash', src, camp.id)
    TriggerClientEvent('vorp_inventory:OpenClanInventory', src, L('storage_title'), camp.id, camp.invlimit)
    reloadFor(src, camp)
    CampLog(camp, 'stash', 'Admin Opened Stash', LogColour.orange, {
        { 'Who', Who(src, camp) },
        { 'Used', ('%d / %d'):format(stashTotal(camp), camp.invlimit or 0), true },
    }, { actor = src, description = 'Opened from the vorp_admin panel with the leader\'s controls.' })
    return true
end)

-- close the panel of every viewer who may no longer see this stash (kicked, left, camp
-- shut down or deleted, raid loot window over); otherwise they keep getting its contents
function StashPrune(campId)
    local v = Viewers[campId]
    if not v then return end
    local camp = Camps[campId]
    for src in pairs(v) do
        local keep = false
        local p = Players[src]
        if camp and GetPlayerName(src) and staffViewing(src, campId) then
            keep = true
        elseif camp and p and GetPlayerName(src) then
            local rank, leader = RankOf(camp, p.charid, p.identifier)
            if rank ~= nil or leader then
                keep = not camp.repo and U.meets(rank, leader, Config.Permissions.stashOpen)
            else
                keep = not camp.repo and LootAllowed(camp, src, p.charid)
            end
        end
        if not keep then
            v[src] = nil
            if StaffView[src] == campId then StaffView[src] = nil end
            if MenuLocks[campId] == src then MenuLocks[campId] = nil end
            if GetPlayerName(src) then TriggerClientEvent('vorp_inventory:CloseInv', src) end
        end
    end
    if next(v) == nil or not camp then Viewers[campId] = nil end
end

function StashForget(src)
    for _, v in pairs(Viewers) do v[src] = nil end
    StaffView[src] = nil
    gate[src] = nil
end

------------------------------------------------------------------------------ panel events

RegisterNetEvent('pup_camps:MoveToClan', function(raw)
    local src = source
    if slow(src) then return end
    local data = decodeArg(raw)
    local ctx = Ctx(src)
    if not data or not ctx or type(data.item) ~= 'table' then return end
    local camp, looting, why = access(ctx, data.clan, 'put')
    if not camp then if why then Notify(src, why) end return end

    local item = data.item
    local name = item.name or item.item
    if type(name) ~= 'string' then return end
    if item.type == 'item_weapon' or data.type == 'item_weapon' then return Notify(src, L('storage_weapon')) end
    local bad = blocked(name)
    if bad then return Notify(src, bad) end
    if (camp.invlimit or 0) <= 0 then return Notify(src, L('storage_no_chest')) end
    local amount = math.floor(tonumber(data.number) or 1)
    if amount < 1 then amount = 1 end
    if stashTotal(camp) + amount > camp.invlimit then return Notify(src, L('storage_full')) end

    -- the player's real stack, by the id the panel clicked; never the client's metadata
    local real
    local pid = tonumber(item.id)
    for _, it in pairs(exports.vorp_inventory:getUserInventoryItems(src) or {}) do
        if it.name == name and (pid == nil or tonumber(it.id) == pid) then
            if not real or tonumber(it.id) == pid then real = it end
            if pid then break end
        end
    end
    if not real or (tonumber(real.count) or 0) < amount then return Notify(src, L('storage_not_held')) end
    if real.type == 'item_weapon' then return Notify(src, L('storage_weapon')) end

    local removed = exports.vorp_inventory:subItemById(src, real.id, nil, nil, amount)
    if not removed then return Notify(src, L('storage_not_held')) end
    -- the camp may have been touched while the inventory call ran
    if Camps[camp.id] ~= camp then
        exports.vorp_inventory:addItem(src, name, amount, hasMeta(real.metadata) and real.metadata or nil)
        return
    end
    mergeIn(camp, name, real.label or item.label, amount, real.metadata)
    Save(camp)
    ReloadStashViewers(camp)
    local fields = {
        { 'Who', Who(src, camp) }, { 'Item', ('%s (%s)'):format(real.label or name, name) },
        { 'Amount', tostring(amount), true }, { 'Used', ('%d / %d'):format(stashTotal(camp), camp.invlimit), true },
    }
    if looting then RaidLog(camp, 'Stash Deposit (Raider)', LogColour.purple, fields)
    else
        local title = StaffView[src] == camp.id and 'Stash Deposit (Admin)' or 'Stash Deposit'
        CampLog(camp, 'stash', title, LogColour.green, fields, { actor = src })
    end
end)

-- the panel locks itself after a take until it is reloaded, so every refusal answers with
-- a reload (or closes the panel when the player may not see the stash at all)
local function refuse(src, camp, msg)
    if msg then Notify(src, msg) end
    if camp then reloadFor(src, camp) else TriggerClientEvent('vorp_inventory:CloseInv', src) end
end

RegisterNetEvent('pup_camps:TakeFromClan', function(raw)
    local src = source
    local data = decodeArg(raw)
    local known = data and Camps[tonumber(data.clan) or -1]
    if slow(src) then return refuse(src, known and Viewers[known.id] and Viewers[known.id][src] and known or nil) end
    local ctx = Ctx(src)
    if not data or not ctx or type(data.item) ~= 'table' then return refuse(src, nil) end
    local camp, looting, why = access(ctx, data.clan, 'take')
    if not camp then return refuse(src, nil, why) end

    local item = data.item
    local name = item.name or item.item
    if type(name) ~= 'string' then return refuse(src, camp) end
    local amount = math.floor(tonumber(data.number) or 1)
    if amount < 1 then amount = 1 end

    -- the clicked stack: by our entry id, else by name + metadata
    local entry
    local eid = tonumber(item.id)
    for _, e in ipairs(camp.inventory) do
        if eid and e.id == eid and e.name == name then entry = e break end
    end
    if not entry then
        for _, e in ipairs(camp.inventory) do
            if e.name == name and metaEqual(e.metadata, item.metadata) then entry = e break end
        end
    end
    if not entry then return refuse(src, camp, L('storage_gone')) end
    if entry.type == 'item_weapon' then return refuse(src, camp, L('storage_weapon_stuck')) end
    if amount > entry.count then amount = entry.count end
    if not exports.vorp_inventory:canCarryItem(src, name, amount) then return refuse(src, camp, L('storage_cant_carry')) end

    entry.count = entry.count - amount
    if entry.count <= 0 then
        for i, e in ipairs(camp.inventory) do
            if e == entry then table.remove(camp.inventory, i) break end
        end
    end
    local meta = hasMeta(entry.metadata) and entry.metadata or nil
    if not exports.vorp_inventory:addItem(src, name, amount, meta) then
        mergeIn(camp, name, entry.label, amount, entry.metadata)
        Save(camp)
        return refuse(src, camp, L('storage_cant_carry'))
    end
    Save(camp)
    ReloadStashViewers(camp)
    local left = 0
    for _, e in ipairs(camp.inventory) do if e.name == name then left = left + e.count end end
    local fields = {
        { 'Who', Who(src, camp) }, { 'Item', ('%s (%s)'):format(entry.label or name, name) },
        { 'Amount', tostring(amount), true }, { 'Left in stash', tostring(left), true },
    }
    if looting then RaidLog(camp, 'Stash Looted', LogColour.red, fields)
    else
        local title = StaffView[src] == camp.id and 'Stash Withdrawal (Admin)' or 'Stash Withdrawal'
        CampLog(camp, 'stash', title, LogColour.red, fields, { actor = src })
    end
end)

RegisterNetEvent('pup_camps:SortClanInventory', function(raw)
    local src = source
    if slow(src) then return end
    local data = decodeArg(raw)
    local ctx = Ctx(src)
    if not data or not ctx then return end
    local camp, looting = access(ctx, data.clan, 'open')
    if not camp or looting then return end
    table.sort(camp.inventory, function(a, b)
        local wa, wb = a.type == 'item_weapon', b.type == 'item_weapon'
        if wa ~= wb then return wb end
        local la, lb = tostring(a.label):lower(), tostring(b.label):lower()
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    Save(camp)
    ReloadStashViewers(camp)
end)

RegisterNetEvent('pup_camps:ChangeOrderClan', function(raw)
    local src = source
    if slow(src) then return end
    local data = decodeArg(raw)
    local ctx = Ctx(src)
    if not data or not ctx or type(data.inventoryItems) ~= 'table' then return end
    local camp, looting = access(ctx, data.clan, 'open')
    if not camp or looting then return end
    if #data.inventoryItems > #camp.inventory then return end
    local byId = {}
    for _, e in ipairs(camp.inventory) do byId[e.id] = e end
    local out, used = {}, {}
    for _, o in ipairs(data.inventoryItems) do
        local id = type(o) == 'table' and tonumber(o.id) or nil
        local e = id and byId[id]
        if not e then return end           -- counts do not line up: change nothing
        if not used[id] then
            used[id] = true
            out[#out + 1] = e
        end
    end
    for _, e in ipairs(camp.inventory) do
        if not used[e.id] then out[#out + 1] = e end
    end
    camp.inventory = out
    Save(camp)
    ReloadStashViewers(camp)
end)

------------------------------------------------------------------------------ storage boxes (pup-misc)

local function boxCtx(src)
    src = tonumber(src)
    if not src then return nil end
    return Ctx(src)
end

exports('BoxStashItems', function(src, clanId)
    local ctx = boxCtx(src)
    if not ctx then return nil end
    local camp = access(ctx, clanId, 'take')
    if not camp then return nil end
    return stashList(camp)
end)

-- the stash entry id from BoxStashItems is matched first, then name + metadata
exports('BoxStashTake', function(src, clanId, entryId, name, metadata, amount)
    local ctx = boxCtx(src)
    if not ctx or type(name) ~= 'string' then return false end
    local camp = access(ctx, clanId, 'take')
    if not camp then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return false end
    local order = {}
    local wantId = tonumber(entryId)
    for i, e in ipairs(camp.inventory) do
        if wantId and e.id == wantId and e.name == name then table.insert(order, 1, i) else order[#order + 1] = i end
    end
    for _, i in ipairs(order) do
        local e = camp.inventory[i]
        if e.name == name and e.type ~= 'item_weapon' and ((wantId and e.id == wantId) or metaEqual(e.metadata, metadata)) then
            if e.count < amount then return false end
            e.count = e.count - amount
            if e.count <= 0 then table.remove(camp.inventory, i) end
            Save(camp)
            ReloadStashViewers(camp)
            return true, stashList(camp)
        end
    end
    return false
end)

exports('BoxStashReturn', function(clanId, name, metadata, amount, label)
    local camp = Camps[tonumber(clanId) or -1]
    amount = math.floor(tonumber(amount) or 0)
    if not camp or type(name) ~= 'string' or amount < 1 then return false end
    if type(label) ~= 'string' then
        -- pup-misc calls this with four arguments; take the label from the item list
        local ok, db = pcall(function() return exports.vorp_inventory:getItemDB(name) end)
        label = ok and type(db) == 'table' and db.label or nil
    end
    mergeIn(camp, name, label, amount, metadata)
    Save(camp)
    ReloadStashViewers(camp)
    return true
end)

exports('BoxStashPut', function(src, clanId, items)
    local ctx = boxCtx(src)
    if not ctx or type(items) ~= 'table' then return false end
    local camp = access(ctx, clanId, 'put')
    if not camp then return false end
    if (camp.invlimit or 0) <= 0 then return false end
    local total = 0
    for _, it in ipairs(items) do
        if type(it) ~= 'table' or type(it.name) ~= 'string' then return false end
        local n = math.floor(tonumber(it.count) or 0)
        if n < 1 then return false end
        if it.type == 'item_weapon' or blocked(it.name) then return false end
        if tostring(it.name):lower():sub(1, 7) == 'weapon_' then return false end
        total = total + n
    end
    if stashTotal(camp) + total > camp.invlimit then return false end
    for _, it in ipairs(items) do
        mergeIn(camp, it.name, it.label, math.floor(tonumber(it.count)), it.metadata)
    end
    Save(camp)
    ReloadStashViewers(camp)
    return true
end)

-- pup-misc fires this (server-local) after moving stash items into a storage box
AddEventHandler('pup_camps:stashtaken_log', function(src, clanId, itemName, itemLabel, amount)
    local camp = Camps[tonumber(clanId) or -1]
    if not camp then return end
    CampLog(camp, 'stash', 'Stash Withdrawal', LogColour.red, {
        { 'Who', Who(tonumber(src), camp) },
        { 'Item', ('%s (%s)'):format(tostring(itemLabel or itemName), tostring(itemName)) },
        { 'Amount', tostring(amount), true },
    }, { actor = tonumber(src), description = 'Taken into a storage box.' })
end)
