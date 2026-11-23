-- pup_ranchero | staff: /createranch, the in-game dashboard, and the vorp_admin bridge exports

------------------------------------------------------------------------------
-- /createranch (vorp group 'admin' only)
------------------------------------------------------------------------------
local function isAdminGroup(src)
    local user = VORP.getUser(src)
    return user ~= nil and user.getGroup == 'admin'
end

RegisterCommand(Config.General.createCommand, function(src)
    if src == 0 then
        print('[pup_ranchero] /' .. Config.General.createCommand .. ' has to be used in game')
        return
    end
    if not isAdminGroup(src) then
        Notify(src, L('notAllowed'))
        return
    end
    TriggerClientEvent('pup_ranchero:openCreate', src)
end, false)

Rpc('createRanch', { gap = 2000 }, function(ctx, name, price, tax, pos)
    if not isAdminGroup(ctx.src) then Notify(ctx.src, L('notAllowed')) return false end
    name = U.cut(U.trim(name), Config.General.maxNameLength)
    price, tax = U.num(price), U.num(tax)
    local coords = PlayerPos(ctx.src) or U.coords(pos)
    if name == '' or not coords or not price or price < 0 or not tax or tax < 0 then
        Notify(ctx.src, L('invalidAmount'))
        return false
    end
    tax = math.floor(tax)
    local coordsJson = json.encode({ x = coords.x, y = coords.y, z = coords.z })
    local id = MySQL.insert.await(
        "INSERT INTO player_ranch (name, price, coords, owned, herdtrail, cattle, q_cattle, dist, chores, cows, chickens, milk, eggs, ledger, dog, q_ranch, repoed, herding, selling, milking, checking, tax, hired) "
        .. "VALUES (?, ?, ?, 0, '[]', '[]', '[]', 1, '[]', '[]', '[]', 0, 0, 0, '0', 0, 0, 0, 0, 0, 0, ?, '[]')",
        { name, price, coordsJson, tax })
    if not id then return false end
    Ranches[id] = RanchFromRow({
        id = id, name = name, price = price, coords = coordsJson, owned = 0, dist = 1, tax = tax, dog = '0',
    })
    Notify(ctx.src, L('createDone', id))
    BroadcastList()
    return id
end)

------------------------------------------------------------------------------
-- in-game dashboard
------------------------------------------------------------------------------
local function isRanchAdmin(ctx)
    if ctx.group == 'admin' then return true end
    if GetResourceState('vorp_admin') == 'started' then
        local ok, allowed = pcall(function() return exports.vorp_admin:allowedToExecuteAction(ctx.src, 'manage_ranch') end)
        if ok and allowed == true then return true end
    end
    for _, j in ipairs(Config.General.adminJobs) do
        if ctx.job == j then return true end
    end
    return false
end

local function ownerNames(ids)
    local names = {}
    if #ids == 0 then return names end
    local marks = {}
    for i = 1, #ids do marks[i] = '?' end
    local ok, rows = pcall(MySQL.query.await,
        ('SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier IN (%s)'):format(table.concat(marks, ',')), ids)
    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            names[tonumber(row.charidentifier)] = U.trim(('%s %s'):format(row.firstname or '', row.lastname or ''))
        end
    end
    return names
end

-- true milk / egg totals (counter + container) for every ranch, one query
local function allStoreTotals()
    local ids, marks, totals = {}, {}, {}
    for rid in pairs(Ranches) do
        ids[#ids + 1] = StoreId(rid)
        marks[#marks + 1] = '?'
    end
    if #ids == 0 then return totals end
    local params = {}
    for _, v in ipairs(ids) do params[#params + 1] = v end
    params[#params + 1] = Config.Produce.milkItem
    params[#params + 1] = Config.Produce.eggItem
    local ok, rows = pcall(MySQL.query.await,
        ('SELECT inventory_type, item_name, SUM(amount) AS total FROM character_inventories WHERE inventory_type IN (%s) AND item_name IN (?, ?) GROUP BY inventory_type, item_name')
        :format(table.concat(marks, ',')), params)
    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            local rid = (tonumber(row.inventory_type) or 0) - Config.Store.idBase
            totals[rid] = totals[rid] or { milk = 0, eggs = 0 }
            if row.item_name == Config.Produce.milkItem then totals[rid].milk = U.num(row.total, 0) end
            if row.item_name == Config.Produce.eggItem then totals[rid].eggs = U.num(row.total, 0) end
        end
    end
    return totals
end

local function activityRows(rid, limit)
    local ok, rows
    if rid then
        ok, rows = pcall(MySQL.query.await, 'SELECT ranchid, ts, type, detail, actor FROM ranch_activity WHERE ranchid = ? ORDER BY id DESC LIMIT ?', { rid, limit })
    else
        ok, rows = pcall(MySQL.query.await, 'SELECT ranchid, ts, type, detail, actor FROM ranch_activity ORDER BY id DESC LIMIT ?', { limit })
    end
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for i, row in ipairs(rows) do
        local r = Ranches[tonumber(row.ranchid) or -1]
        out[i] = {
            ts = tonumber(row.ts) or 0, type = tostring(row.type or ''), detail = tostring(row.detail or ''),
            actor = tostring(row.actor or ''), ranch = r and r.name ~= '' and r.name or ('Ranch #' .. tostring(row.ranchid)),
        }
    end
    return out
end

local function ranchSummaries()
    local ids, seen = {}, {}
    for _, r in pairs(Ranches) do
        if r.charid and not seen[r.charid] then seen[r.charid] = true; ids[#ids + 1] = r.charid end
    end
    local names = ownerNames(ids)
    local totals = allStoreTotals()
    local list = {}
    for _, r in pairs(Ranches) do
        local members = {}
        if r.owned == 1 and r.charid then
            members[#members + 1] = { name = names[r.charid] or ('char ' .. r.charid), role = 'Owner' }
        end
        for _, h in ipairs(r.hired) do
            if not (r.owned == 1 and h.charidentifier == r.charid) then
                members[#members + 1] = { name = h.name, role = h.manager and 'Manager' or 'Ranch Hand' }
            end
        end
        local st = totals[r.id] or { milk = 0, eggs = 0 }
        list[#list + 1] = {
            id = r.id, name = r.name, owned = r.owned, repoed = r.repoed,
            owner = r.owned == 1 and r.charid and (names[r.charid] or ('char ' .. r.charid)) or nil,
            tax = r.tax, ledger = r.ledger, members = members, cattle = TotalCattle(r), env = r.env,
            hasPen = r.cows ~= nil, hasCoop = r.chickens ~= nil,
            milk = r.milk + st.milk, eggs = r.eggs + st.eggs, coords = r.coords,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- one stamp is shared by overview/ranches/activity, so the gap is kept short enough for quick tab switches
Rpc('adminData', { gap = 100 }, function(ctx, what, rid)
    if not isRanchAdmin(ctx) then Notify(ctx.src, L('notAllowed')) return false end
    if what == 'overview' then
        local total, owned, ledger = 0, 0, 0
        for _, r in pairs(Ranches) do
            total = total + 1
            if r.owned == 1 then owned = owned + 1 end
            ledger = ledger + r.ledger
        end
        return { total = total, owned = owned, forSale = total - owned, ledger = ledger, activity = activityRows(nil, 30), now = os.time() }
    elseif what == 'ranches' then
        return { list = ranchSummaries(), envMax = U.envMax() }
    elseif what == 'activity' then
        local id = tonumber(rid)
        if not id then return false end
        return { activity = activityRows(id, 10), now = os.time() }
    end
    return false
end)

------------------------------------------------------------------------------
-- vorp_admin bridge. vorp_admin checks its own permissions; these exports only validate input.
------------------------------------------------------------------------------
local function fail(err) return { ok = false, err = err } end

exports('adminRanchList', function()
    local list = {}
    for _, r in pairs(Ranches) do
        local hired = {}
        for _, h in ipairs(r.hired) do
            -- a stray owner entry in the hired list is not a hand
            if not (r.owned == 1 and h.charidentifier == r.charid) then
                hired[#hired + 1] = { name = h.name, manager = h.manager == true, charid = h.charidentifier }
            end
        end
        list[#list + 1] = {
            id = r.id, name = r.name, price = r.price, tax = r.tax, owned = r.owned, repoed = r.repoed, ledger = r.ledger,
            ownerCharid = r.charid, cattleCount = TotalCattle(r),
            hasCowPen = r.cows ~= nil, hasChickenCoop = r.chickens ~= nil,
            -- uncollected counters only: vorp_admin adds the container totals itself (invId/milkItem/eggItem)
            milk = r.milk, eggs = r.eggs,
            invId = Config.Store.idBase + r.id, milkItem = Config.Produce.milkItem, eggItem = Config.Produce.eggItem,
            quality = r.env, hired = hired,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

local function setNumber(id, value, col, field)
    local r = Ranches[tonumber(id) or -1]
    local v = tonumber(value)
    if not v or v < 0 or v ~= v then return fail('bad values') end
    if not r then return fail('unknown ranch') end
    if col == 'tax' then v = math.floor(v) end
    r[field] = v
    Save(r, col)
    BroadcastList()
    RefreshRanch(r)
    return { ok = true }
end

exports('adminSetRanchPrice', function(id, price) return setNumber(id, price, 'price', 'price') end)
exports('adminSetRanchTax', function(id, tax) return setNumber(id, tax, 'tax', 'tax') end)

exports('adminMoveRanch', function(id, coords, actor)
    local r = Ranches[tonumber(id) or -1]
    if not r then return fail('unknown ranch') end
    local c = U.coords(coords)
    if not c then return fail('bad values') end
    r.coords = c
    Save(r, 'coords')
    Activity(r.id, 'ADMIN_MOVE', ('moved to %.1f, %.1f, %.1f'):format(c.x, c.y, c.z), actor or 'Admin')
    BroadcastList()
    RefreshRanch(r)
    return { ok = true }
end)

local function charRow(charid)
    local ok, rows = pcall(MySQL.query.await, 'SELECT identifier, charidentifier, firstname, lastname FROM characters WHERE charidentifier = ? LIMIT 1', { charid })
    if not ok or type(rows) ~= 'table' or not rows[1] then return nil end
    local row = rows[1]
    return { identifier = row.identifier, charid = tonumber(row.charidentifier), name = U.trim(('%s %s'):format(row.firstname or '', row.lastname or '')) }
end

exports('adminTransferRanch', function(id, charid, actor)
    local r = Ranches[tonumber(id) or -1]
    if not r then return fail('unknown ranch') end
    actor = actor or 'Admin'
    local cid = math.floor(tonumber(charid) or 0)
    local was = r.charid
    local oldMembers = {}
    for _, h in ipairs(r.hired) do oldMembers[#oldMembers + 1] = h.charidentifier end

    if cid <= 0 then
        EndDrivesOfRanch(r.id) -- owner and hands all lose their places
        r.identifier, r.charid, r.owned, r.repoed, r.hired, r.webhook = nil, nil, 0, 1, {}, nil
        Save(r, 'identifier', 'charidentifier', 'owned', 'repoed', 'hired', 'webhook')
        Activity(r.id, 'ADMIN_TRANSFER', ('owner cleared (was char %s) - back on sale'):format(tostring(was or 0)), actor)
    else
        local c = charRow(cid)
        if not c then return fail('no such character') end
        if Ranches[r.id] ~= r then return fail('unknown ranch') end -- deleted while we waited
        -- the one-ranch rule covers hands as well as owners, on any other ranch
        for _, other in pairs(Ranches) do
            if other.id ~= r.id then
                local role = RoleIn(other, cid)
                if role == 'owner' then return fail(('that character already owns ranch #%d'):format(other.id)) end
                if role then return fail(('that character is already the hired hand of ranch #%d'):format(other.id)) end
            end
        end
        EndDrivesOfRanch(r.id) -- the hired list is emptied, so every running drive ends for free
        was = r.charid
        r.identifier, r.charid, r.owned, r.repoed, r.hired, r.webhook = c.identifier, cid, 1, 0, {}, nil
        Save(r, 'identifier', 'charidentifier', 'owned', 'repoed', 'hired', 'webhook')
        Activity(r.id, 'ADMIN_TRANSFER', ('owner set to %s (char %d), was char %s'):format(c.name, cid, tostring(was or 0)), actor)
        LogPlain('general', r, 'Ranch Transferred (admin)', {
            ('By: %s'):format(actor), ('Ranch ID: %d'):format(r.id), ('Name: %s'):format(r.name), ('New owner: %s (char %d)'):format(c.name, cid),
        })
        RefreshChar(cid)
    end
    RefreshChar(was)
    for _, m in ipairs(oldMembers) do RefreshChar(m) end
    BroadcastList()
    return { ok = true }
end)

exports('adminDeleteRanch', function(id, actor)
    local r = Ranches[tonumber(id) or -1]
    if not r then return fail('unknown ranch') end
    actor = actor or 'Admin'
    local title, ownerCid = RanchTitle(r), r.owned == 1 and r.charid or nil
    local members = {}
    for _, h in ipairs(r.hired) do members[#members + 1] = h.charidentifier end
    Ranches[r.id] = nil
    MenuLocks[r.id] = nil
    FreshHerds[r.id] = nil
    MySQL.update('DELETE FROM player_ranch WHERE id = ?', { r.id })
    MySQL.update('DELETE FROM ranch_fresh WHERE ranchid = ?', { r.id })
    Activity(r.id, 'ADMIN_DELETE', ('deleted %s'):format(title), actor)
    LogPlain('general', r, 'Ranch Deleted', { ('By: %s'):format(actor), ('Ranch ID: %d'):format(r.id), ('Ranch: %s'):format(title) }, false)
    if ownerCid and GetResourceState('pup_postoffice') == 'started' then
        pcall(function()
            exports['pup_postoffice']:SendSystemMail(ownerCid, ('Ranch Closed: %s'):format(title),
                ('%s has been closed by the land office. Its livestock, buildings, stored produce and ledger are gone with it.\n\nPlease speak to staff if you have questions.'):format(title),
                Config.Tax.mailFrom)
        end)
    end
    EndDrivesOfRanch(r.id)
    RefreshChar(ownerCid)
    for _, m in ipairs(members) do RefreshChar(m) end
    BroadcastList()
    return { ok = true }
end)

exports('adminHireToRanch', function(id, charid, actor)
    local r = Ranches[tonumber(id) or -1]
    if not r then return fail('unknown ranch') end
    local cid = math.floor(tonumber(charid) or 0)
    if cid <= 0 then return fail('bad values') end
    local function oneRanchRule()
        for _, other in pairs(Ranches) do
            local role = RoleIn(other, cid)
            if role then
                local what = role == 'owner' and 'the owner' or 'the hired hand'
                if other.id == r.id then return ('they are already %s here'):format(what) end
                return ('they are already %s of ranch #%d'):format(what, other.id)
            end
        end
        return nil
    end
    local err = oneRanchRule()
    if err then return fail(err) end
    local c = charRow(cid)
    if not c then return fail('no such character') end
    -- re-checked after the database wait: the ranch or the character may have changed meanwhile
    if Ranches[r.id] ~= r then return fail('unknown ranch') end
    err = oneRanchRule()
    if err then return fail(err) end
    r.hired[#r.hired + 1] = { identifier = c.identifier, charidentifier = cid, name = c.name, manager = false }
    Save(r, 'hired')
    Activity(r.id, 'ADMIN_HIRE', ('hired %s'):format(c.name), actor or 'Admin')
    LogEmbed(r, 'Ranch Hire (admin)', LogColors.green, {
        { 'Person', ('%s (char %d)'):format(c.name, cid), true }, { 'By', actor or 'Admin', true }, { 'Staff now', StaffCount(r), true },
    })
    RefreshRanch(r)
    BroadcastList()
    return { ok = true, name = c.name }
end)

exports('adminFireFromRanch', function(id, charid, actor)
    local r = Ranches[tonumber(id) or -1]
    if not r then return fail('unknown ranch') end
    local cid = math.floor(tonumber(charid) or 0)
    local idx, h = HiredIndex(r, cid)
    if not idx then return fail('they are not hired here') end
    table.remove(r.hired, idx)
    Save(r, 'hired')
    EndDrivesOfChar(cid, r.id)
    Activity(r.id, 'ADMIN_FIRE', ('let %s go'):format(h.name), actor or 'Admin')
    LogEmbed(r, 'Ranch Fire (admin)', LogColors.red, {
        { 'Person', ('%s (char %d)'):format(h.name, cid), true }, { 'By', actor or 'Admin', true }, { 'Staff now', StaffCount(r), true },
    })
    RefreshRanch(r)
    RefreshChar(cid)
    BroadcastList()
    return { ok = true, name = h.name }
end)

exports('adminSetRanchManager', function(id, charid, makeManager, actor)
    local r = Ranches[tonumber(id) or -1]
    if not r then return fail('unknown ranch') end
    local _, h = HiredIndex(r, math.floor(tonumber(charid) or 0))
    if not h then return fail('they are not hired here') end
    local want = makeManager == true
    if want and h.manager then return fail('already a manager') end
    if not want and not h.manager then return fail('already a ranch hand') end
    h.manager = want
    Save(r, 'hired')
    Activity(r.id, 'ADMIN_RANK', ('%s is now %s'):format(h.name, want and 'a manager' or 'a ranch hand'), actor or 'Admin')
    RefreshRanch(r)
    BroadcastList()
    return { ok = true, name = h.name, manager = want }
end)
