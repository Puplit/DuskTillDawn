-- pup_business | admin: overview, create / update / delete, ranks, storage, shops

local function mercRunning() return GetResourceState('pup_mercantile') == 'started' end

local function merc(fn, ...)
    if not mercRunning() then return false end
    local args = table.pack(...)
    local ok, a, b = pcall(function() return exports.pup_mercantile[fn](exports.pup_mercantile, table.unpack(args, 1, args.n)) end)
    if not ok then
        print(('^3[%s]^7 pup_mercantile:%s failed: %s'):format(RES, fn, tostring(a)))
        return false
    end
    return a, b
end

function ShopsOf(job)
    if type(job) ~= 'string' or job == '' or not mercRunning() then return {} end
    local list = merc('AdminListSocietyShops', job)
    return type(list) == 'table' and list or {}
end

---------------------------------------------------------------------------
-- overview (export for vorp_admin and the in-world app)
---------------------------------------------------------------------------

function BuildOverview()
    WaitLoaded(5000)
    local jobs = {}
    for job in pairs(Biz) do jobs[#jobs + 1] = job end
    if #jobs == 0 then return {} end

    local staffRows = MySQL.query.await(
        'SELECT charidentifier, firstname, lastname, job, jobgrade, identifier, discordid FROM characters WHERE job IN (?)',
        { jobs }) or {}
    local ledgerRows = MySQL.query.await('SELECT job, ledger, invaccess FROM society_ledger WHERE job IN (?)', { jobs }) or {}
    local cids = {}
    for _, b in pairs(Biz) do if b.containerid then cids[#cids + 1] = b.containerid end end
    local contRows = #cids > 0 and (MySQL.query.await('SELECT id, invslots FROM container WHERE id IN (?)', { cids }) or {}) or {}
    local mailRows = {}
    if GetResourceState('pup_postoffice') == 'started' then
        local ok, rows = pcall(MySQL.query.await, 'SELECT job, handle FROM mail_business WHERE job IN (?)', { jobs })
        if ok and type(rows) == 'table' then mailRows = rows end
    end

    local staffBy, ledgerBy, slotsBy, mailBy = {}, {}, {}, {}
    for _, r in ipairs(staffRows) do
        staffBy[r.job] = staffBy[r.job] or {}
        local discord = type(r.discordid) == 'string' and r.discordid:gsub('^discord:', '') or nil
        if discord == '' then discord = nil end
        table.insert(staffBy[r.job], {
            name = (('%s %s'):format(r.firstname or '', r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
            grade = tonumber(r.jobgrade) or 0,
            charid = tonumber(r.charidentifier),
            discord = discord,
            steam = r.identifier,
        })
    end
    for _, r in ipairs(ledgerRows) do
        if not ledgerBy[r.job] then ledgerBy[r.job] = r end
    end
    for _, r in ipairs(contRows) do slotsBy[tonumber(r.id)] = tonumber(r.invslots) or 0 end
    for _, r in ipairs(mailRows) do mailBy[r.job] = r.handle end

    local out, actors = {}, {}
    for _, job in ipairs(jobs) do
        local b = Biz[job]
        local acts = MySQL.query.await(
            "SELECT ts, type, detail, actor FROM society_activity WHERE job = ? AND type <> 'DUTY' ORDER BY ts DESC, id DESC LIMIT ?",
            { job, Config.AdminActivityPerBusiness }) or {}
        local activity = {}
        for _, a in ipairs(acts) do
            activity[#activity + 1] = { ts = tonumber(a.ts) or 0, type = a.type, detail = a.detail, actor = a.actor }
            if a.actor and a.actor ~= '' then actors[a.actor] = true end
        end
        local staff = staffBy[job] or {}
        table.sort(staff, function(x, y)
            if x.grade ~= y.grade then return x.grade > y.grade end
            return x.name < y.name
        end)
        local owner
        for _, s in ipairs(staff) do
            if s.grade >= b.bossrank then owner = s.name break end
        end
        local led = ledgerBy[job]
        out[#out + 1] = {
            owner = owner,
            boughtslots = b.containerid and slotsBy[b.containerid] or 0,
            baseSlots = Config.BaseSlots,
            lastactive = activity[1] and activity[1].ts or 0,
            activity = activity,
            job = job,
            name = b.name,
            blipsprite = b.blipsprite,
            showblip = b.showblip,
            recruitmentrank = b.recruitmentrank,
            bossrank = b.bossrank,
            containerid = b.containerid,
            containername = b.containername,
            mailhandle = mailBy[job] or '',
            billing = b.billing,
            webhook = b.webhook,
            salary = b.salary,
            tax = b.tax,
            positions = b.positions,
            jobmenu = b.jobmenu,
            ledger = led and tonumber(led.ledger) or 0,
            invaccess = led and tonumber(led.invaccess) or 0,
            staff = staff,
            staffcount = #staff,
        }
    end

    -- activity actor -> char id by exact full name
    local names = {}
    for n in pairs(actors) do names[#names + 1] = n end
    if #names > 0 then
        local rows = MySQL.query.await(
            "SELECT charidentifier, CONCAT(firstname, ' ', lastname) AS fullname FROM characters WHERE CONCAT(firstname, ' ', lastname) IN (?)",
            { names }) or {}
        local byName = {}
        for _, r in ipairs(rows) do
            if r.fullname and not byName[r.fullname] then byName[r.fullname] = tonumber(r.charidentifier) end
        end
        for _, e in ipairs(out) do
            for _, a in ipairs(e.activity) do a.charid = byName[a.actor] end
        end
    end

    table.sort(out, function(x, y)
        local nx = (x.name ~= '' and x.name or x.job):lower()
        local ny = (y.name ~= '' and y.name or y.job):lower()
        if nx ~= ny then return nx < ny end
        return x.job < y.job
    end)
    return out
end

Handle('adminOverview', 500, function(src)
    if not IsPanelAdmin(src) then return nil end
    return { list = BuildOverview(), now = Now(), management = IsManagement(src) }
end)

-- after every admin change: reload, push to everyone, refresh the caller's app
local function afterAdmin(src)
    ReloadAndPush()
    if src then
        TriggerClientEvent('pup_business:adminData', src, { list = BuildOverview(), now = Now(), management = IsManagement(src) })
    end
end

local function gate(src)
    if not GetChar(src) then return false end
    if not IsPanelAdmin(src) then
        Notify(src, L('no_permission'))
        return false
    end
    return true
end

-- jobs only the VORP admin groups and manage_society may create or set ranks in
local function lockedFor(src, job)
    if not (Config.PanelAdminJobs[job] or (Config.PanelAdminLockedJobs or {})[job]) then return false end
    return not IsServerPanelAdmin(src)
end

---------------------------------------------------------------------------
-- create
---------------------------------------------------------------------------

local function nextContainerId()
    local maxBiz = tonumber(MySQL.scalar.await('SELECT COALESCE(MAX(containerid), 0) FROM society_business')) or 0
    local maxRow = tonumber(MySQL.scalar.await('SELECT COALESCE(MAX(id), 0) FROM container')) or 0
    return math.max(maxBiz, maxRow) + 1
end

local function writeRankRows(job, bossrank)
    for g = 0, bossrank do
        local perms = g >= bossrank and AllPerms() or {}
        local legacy = PB.int(MySQL.scalar.await('SELECT salary FROM society WHERE job = ? AND jobgrade = ? LIMIT 1', { job, g }))
        MySQL.update.await([[
            INSERT INTO society_ranks (job, grade, salary, perms, tax, taxperiod, taxsince) VALUES (?, ?, ?, ?, 0, 'weekly', 0)
            ON DUPLICATE KEY UPDATE perms = VALUES(perms)
        ]], { job, g, legacy or 0, EncodePerms(perms) })
        if legacy == nil then
            MySQL.insert.await('INSERT INTO society (job, jobgrade, salary) VALUES (?, ?, 0)', { job, g })
        end
    end
end

local function boolOr(v, default)
    if v == nil then return default end
    return PB.bool(v)
end

RegisterNetEvent('pup_business:admin:create', function(data)
    local src = source
    if not Throttle(src, 'admin:create', 2000) or not gate(src) then return end
    if type(data) ~= 'table' then return end
    local job = PB.jobCode(data.job)
    if job == '' then return Notify(src, L('admin_bad_job')) end
    if lockedFor(src, job) then return Notify(src, L('admin_job_locked')) end
    WaitLoaded(5000)
    if Biz[job] or MySQL.scalar.await('SELECT 1 FROM society_business WHERE job = ? LIMIT 1', { job }) then
        return Notify(src, L('admin_job_exists'))
    end
    local bossrank = math.max(1, PB.int(data.bossrank) or 1)
    local name = PB.cleanText(data.name, 100)
    if name == '' then name = job end
    local stash = PB.cleanText(data.containername, 100)
    if stash == '' then stash = name .. ' Inv.' end
    local recruit = math.max(0, PB.int(data.recruitmentrank) or Config.DefaultRecruiterGrade)
    local ch = GetChar(src)

    if not Lock('admin:create') then return Notify(src, L('admin_busy')) end
    local ok, err = pcall(function()
        local cid = nextContainerId()
        MySQL.insert.await([[
            INSERT INTO society_business
                (job, name, blipsprite, showblip, recruitmentrank, bossrank, containerid, containername,
                 billing, webhook, salary, positions, jobmenu, created_by, tax)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        ]], {
            job, name, PB.int(data.blipsprite) or Config.DefaultBlipSprite, boolOr(data.showblip, true) and 1 or 0,
            recruit, bossrank, cid, stash,
            boolOr(data.billing, true) and 1 or 0, boolOr(data.webhook, false) and 1 or 0, boolOr(data.salary, true) and 1 or 0,
            json.encode(PB.points(data.positions)), json.encode(PB.points(data.jobmenu)),
            ch and ch.identifier or nil,
        })
        MySQL.insert.await("INSERT IGNORE INTO container (id, name, items, invslots) VALUES (?, ?, '[]', 0)", { cid, job })
        LedgerEnsure(job)
        writeRankRows(job, bossrank)
    end)
    Unlock('admin:create')
    if not ok then
        print(('^1[%s]^7 create %s failed: %s'):format(RES, job, tostring(err)))
        return Notify(src, L('action_failed'))
    end
    Dbg('created', job, 'by', src)
    Notify(src, L('admin_created', name))
    afterAdmin(src)
    RegisterStash(job)
end)

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------

RegisterNetEvent('pup_business:admin:update', function(job, changes)
    local src = source
    if not Throttle(src, 'admin:update', 300) or not gate(src) then return end
    if type(job) ~= 'string' or type(changes) ~= 'table' then return end
    local b = Biz[job]
    if not b then return Notify(src, L('not_business')) end

    local set, vals = {}, {}
    local function put(col, v) set[#set + 1] = ('`%s` = ?'):format(col); vals[#vals + 1] = v end

    local newName
    if changes.name ~= nil then
        newName = PB.cleanText(changes.name, 100)
        if newName == '' then newName = job end
        put('name', newName)
    end
    local newStash
    if changes.containername ~= nil then
        newStash = PB.cleanText(changes.containername, 100)
        if newStash == '' then newStash = nil end
    end
    if newName and not newStash then newStash = newName .. ' Inv.' end
    if newStash then put('containername', newStash) end

    if changes.blipsprite ~= nil then
        local s = PB.int(changes.blipsprite)
        if s then put('blipsprite', s) end
    end
    for _, k in ipairs({ 'showblip', 'billing', 'webhook', 'salary', 'tax' }) do
        if changes[k] ~= nil then put(k, PB.bool(changes[k]) and 1 or 0) end
    end
    local newBoss
    if changes.bossrank ~= nil then
        newBoss = math.max(1, PB.int(changes.bossrank) or b.bossrank)
        put('bossrank', newBoss)
    end
    if changes.recruitmentrank ~= nil then
        local r = PB.int(changes.recruitmentrank)
        if r then put('recruitmentrank', math.max(0, r)) end
    end
    if changes.positions ~= nil then put('positions', json.encode(PB.points(changes.positions))) end
    if changes.jobmenu ~= nil then put('jobmenu', json.encode(PB.points(changes.jobmenu))) end

    if #set == 0 then return end
    vals[#vals + 1] = job
    MySQL.update.await(('UPDATE society_business SET %s WHERE job = ?'):format(table.concat(set, ', ')), vals)
    Dbg('updated', job, json.encode(changes))

    if newBoss and newBoss > b.bossrank then
        -- the new boss grade starts with every permission
        MySQL.update.await([[
            INSERT INTO society_ranks (job, grade, salary, perms, tax, taxperiod, taxsince) VALUES (?, ?, 0, ?, 0, 'weekly', 0)
            ON DUPLICATE KEY UPDATE perms = VALUES(perms)
        ]], { job, newBoss, EncodePerms(AllPerms()) })
    end

    if newStash and b.containerid and GetResourceState('vorp_inventory') == 'started' then
        pcall(function() exports.vorp_inventory:updateCustomInventoryData(tostring(b.containerid), { name = newStash }) end)
    end
    Notify(src, L('admin_updated'))
    afterAdmin(src)
end)

---------------------------------------------------------------------------
-- set rank (admin rank setter: self or any character, one boss per business)
---------------------------------------------------------------------------

RegisterNetEvent('pup_business:admin:setSelfRank', function(job, grade, charid)
    local src = source
    if not Throttle(src, 'admin:rank', 750) or not gate(src) then return end
    local b = type(job) == 'string' and Biz[job]
    if not b then return Notify(src, L('not_business')) end
    if lockedFor(src, job) then return Notify(src, L('admin_job_locked')) end
    grade = math.max(0, math.min(PB.int(grade) or 0, b.bossrank))
    local ch = GetChar(src)
    local myCharid = CharId(ch)
    charid = PB.int(charid)
    if not charid then charid = myCharid end
    local self = charid == myCharid
    local adminName = FullName(ch)
    local bname = DisplayName(job)

    if not Lock('rank:' .. job) then return Notify(src, L('admin_busy')) end
    local ok, err = pcall(function()
        -- one boss: everyone else at or above the boss grade steps down one
        if grade >= b.bossrank then
            local others = MySQL.query.await(
                'SELECT charidentifier, firstname, lastname FROM characters WHERE job = ? AND jobgrade >= ? AND charidentifier <> ?',
                { job, b.bossrank, charid }) or {}
            for _, o in ipairs(others) do
                local ocid = tonumber(o.charidentifier)
                local osrc = SourceOfChar(ocid)
                local oname = (('%s %s'):format(o.firstname or '', o.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
                if osrc then
                    ApplyJob(osrc, job, b.bossrank - 1)
                    Notify(osrc, L('no_longer_owner', bname))
                else
                    MySQL.update.await('UPDATE characters SET jobgrade = ? WHERE charidentifier = ? AND job = ?', { b.bossrank - 1, ocid, job })
                end
                Activity(job, 'RANK', ('%s set to grade %d'):format(oname, b.bossrank - 1), adminName)
            end
        end

        local tsrc = self and src or SourceOfChar(charid)
        local tname
        if tsrc then
            local tch = GetChar(tsrc)
            tname = FullName(tch)
            ApplyJob(tsrc, job, grade)
        else
            local row = MySQL.single.await('SELECT firstname, lastname FROM characters WHERE charidentifier = ? LIMIT 1', { charid })
            if not row then error('nochar') end
            tname = (('%s %s'):format(row.firstname or '', row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
            MySQL.update.await('UPDATE characters SET job = ?, jobgrade = ? WHERE charidentifier = ?', { job, grade, charid })
        end

        if self then
            Notify(src, L('admin_self_rank', bname, grade))
        else
            if tsrc then Notify(tsrc, L('admin_rank_set_target', grade)) end
            Notify(src, L('admin_rank_set', grade))
        end
        Activity(job, 'RANK', ('%s set to grade %d%s'):format(tname, grade, grade >= b.bossrank and ' (OWNER)' or ''), adminName)
    end)
    Unlock('rank:' .. job)
    if not ok then
        if tostring(err):find('nochar', 1, true) then return Notify(src, L('admin_no_char')) end
        print(('^1[%s]^7 admin set rank failed: %s'):format(RES, tostring(err)))
        return Notify(src, L('action_failed'))
    end
    afterAdmin(src)
end)

---------------------------------------------------------------------------
-- delete (Management only)
---------------------------------------------------------------------------

RegisterNetEvent('pup_business:admin:delete', function(job)
    local src = source
    if not Throttle(src, 'admin:delete', 2000) or not gate(src) then return end
    if not IsManagement(src) then
        print(('^3[%s]^7 %s tried to delete business %s without delete_society'):format(RES, tostring(src), tostring(job)))
        return Notify(src, L('admin_delete_mgmt'))
    end
    local b = type(job) == 'string' and Biz[job]
    if not b then return Notify(src, L('not_business')) end
    local bname = DisplayName(job)
    local unemployed = Config.UnemployedJob

    if not Lock('rank:' .. job) then return Notify(src, L('admin_busy')) end
    local released, shopsRemoved = 0, 0
    local ok, err = pcall(function()
        -- counted once, before anyone is moved, so online members are not counted twice
        released = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE job = ?', { job })) or 0
        for _, m in ipairs(OnlineMembers(job)) do
            ApplyJob(m.id, unemployed, 0)
            Notify(m.id, L('business_closed', bname))
        end
        MySQL.update.await('UPDATE characters SET job = ?, jobgrade = 0 WHERE job = ?', { unemployed, job })

        for _, shop in ipairs(ShopsOf(job)) do
            if merc('AdminDeleteSocietyShop', shop.id) then shopsRemoved = shopsRemoved + 1 end
        end

        ClearStash(job)
        if b.containerid then
            if GetResourceState('vorp_inventory') == 'started' then
                pcall(function() exports.vorp_inventory:removeInventory(tostring(b.containerid)) end)
            end
            MySQL.update.await('DELETE FROM container WHERE id = ?', { b.containerid })
        end
        MySQL.update.await('DELETE FROM society_business WHERE job = ?', { job })
        MySQL.update.await('DELETE FROM society_ranks WHERE job = ?', { job })
        MySQL.update.await('DELETE FROM society WHERE job = ?', { job })
        MySQL.update.await('DELETE FROM society_ledger WHERE job = ?', { job })
        MySQL.update.await('DELETE FROM society_activity WHERE job = ?', { job })
        MySQL.update.await('DELETE FROM society_tax WHERE job = ?', { job })
        MySQL.update.await('DELETE FROM bills WHERE job = ?', { job })
    end)
    -- nothing of the old business may linger in memory
    Biz[job], Ranks[job], LedgerInfo[job] = nil, nil, nil
    Unlock('rank:' .. job)
    if not ok then
        print(('^1[%s]^7 delete %s failed part way: %s'):format(RES, job, tostring(err)))
        Notify(src, L('action_failed'))
    else
        Dbg('deleted', job, 'by', src)
        Notify(src, L('admin_deleted', released, shopsRemoved), 7000)
    end
    afterAdmin(src)
end)

---------------------------------------------------------------------------
-- clear storage or shop stock (Management only)
---------------------------------------------------------------------------

RegisterNetEvent('pup_business:admin:clear', function(job, kind)
    local src = source
    if not Throttle(src, 'admin:clear', 2000) or not gate(src) then return end
    if not IsManagement(src) then return Notify(src, L('admin_mgmt_only')) end
    local b = type(job) == 'string' and Biz[job]
    if not b then return Notify(src, L('not_business')) end
    if kind == 'stash' then
        if not b.containerid then return Notify(src, L('admin_no_storage')) end
        local n = ClearStash(job) or 0
        Notify(src, L('admin_stash_cleared', n))
    elseif kind == 'shops' then
        local n = 0
        for _, shop in ipairs(ShopsOf(job)) do
            if merc('AdminClearSocietyShopStock', shop.id) then n = n + 1 end
        end
        Notify(src, L('admin_shops_cleared', n))
    else
        return
    end
    afterAdmin(src)
end)

---------------------------------------------------------------------------
-- society shops (pup_mercantile)
---------------------------------------------------------------------------

local function sendShops(src, job)
    TriggerClientEvent('pup_business:adminShops', src, job, { ready = mercRunning(), shops = ShopsOf(job) })
end

RegisterNetEvent('pup_business:admin:shops', function(job)
    local src = source
    if not Throttle(src, 'admin:shops', 500) or not gate(src) then return end
    if type(job) ~= 'string' then return end
    sendShops(src, job)
end)

local SHOP_ACTIONS <const> = {
    enable = function(id) return merc('AdminSetSocietyShopEnabled', id, true) end,
    disable = function(id) return merc('AdminSetSocietyShopEnabled', id, false) end,
    rename = function(id, v)
        v = PB.cleanText(v, 50)
        if v == '' then return false end
        return merc('AdminRenameSocietyShop', id, v)
    end,
    rank = function(id, v)
        v = PB.int(v)
        if not v then return false end
        return merc('AdminSetSocietyShopRank', id, math.max(0, math.min(v, 100)))
    end,
    slots = function(id, v)
        v = PB.int(v)
        if not v then return false end
        return merc('AdminSetSocietyShopSlots', id, v)
    end,
    blip = function(id, v) return merc('AdminSetSocietyShopBlip', id, PB.bool(v)) end,
    move = function(id, v)
        local pts = PB.points({ v })
        if not pts[1] then return false, 'badcoords' end
        return merc('AdminMoveSocietyShop', id, pts[1])
    end,
    delete = function(id) return merc('AdminDeleteSocietyShop', id) end,
}

RegisterNetEvent('pup_business:admin:shopAction', function(job, shopId, action, value)
    local src = source
    if not Throttle(src, 'admin:shopAction', 400) or not gate(src) then return end
    if type(job) ~= 'string' or not Biz[job] then return Notify(src, L('not_business')) end
    if not mercRunning() then return Notify(src, L('admin_shops_down')) end
    shopId = PB.int(shopId)
    if not shopId then return sendShops(src, job) end
    local mine = false
    for _, s in ipairs(ShopsOf(job)) do
        if PB.int(s.id) == shopId then mine = true break end
    end
    if not mine then
        Notify(src, L('admin_shop_not_yours'))
        return sendShops(src, job)
    end

    action = tostring(action or '')
    if action == 'price' then
        Notify(src, L('admin_shop_price_unsupported'))
        return sendShops(src, job)
    end
    local fn = SHOP_ACTIONS[action]
    if not fn then return sendShops(src, job) end
    if action == 'delete' and not IsManagement(src) then
        Notify(src, L('admin_shop_delete_mgmt'))
        return sendShops(src, job)
    end

    local ok, reason = fn(shopId, value)
    if ok then
        local ch = GetChar(src)
        Activity(job, 'shop', ('Shop #%d: %s%s'):format(shopId, action,
            (value ~= nil and type(value) ~= 'table') and (' ' .. tostring(value):sub(1, 50)) or ''), FullName(ch))
        Notify(src, L('admin_shop_done'))
    elseif reason == 'tooclose' then
        Notify(src, L('admin_shop_tooclose'))
    elseif reason == 'badcoords' then
        Notify(src, L('admin_shop_badcoords'))
    else
        Notify(src, L('admin_shop_failed'))
    end
    sendShops(src, job)
end)

---------------------------------------------------------------------------
-- exports for vorp_admin
---------------------------------------------------------------------------

exports('adminOverview', function()
    return BuildOverview()
end)

exports('adminShops', function(job)
    if type(job) ~= 'string' or job == '' then return { ready = false, shops = {} } end
    return { ready = mercRunning(), shops = ShopsOf(job) }
end)

-- vorp_admin "Open storage": opens a business stash for staff with the boss's controls; returns true, or false and a reason
exports('adminOpenStash', function(src, job)
    src = PB.int(src)
    if not src or not GetChar(src) then return false, 'no character loaded' end
    if not VorpAdminAllows(src, 'manage_society') then return false, 'not allowed (manage_society)' end
    local b = type(job) == 'string' and Biz[job]
    if not b then return false, 'unknown business' end
    if not b.containerid then return false, 'business has no container' end
    if GetResourceState('vorp_inventory') ~= 'started' then return false, 'vorp_inventory is not running' end
    local inv = exports.vorp_inventory
    local okO, already = pcall(function() return inv:getOpenCustomInventory(src) end)
    if okO and already then return false, 'you already have a storage open - close it first' end

    EnsureContainerRow(job)
    if not RegisterStash(job) then return false, 'could not register the storage container' end
    -- the database waits above: check again
    if not GetChar(src) or Biz[job] ~= b then return false, 'the business changed while opening' end

    local id = tostring(b.containerid)
    StashOpenBy[src] = id
    StaffStash[src] = id
    inv:openInventory(src, id, true)
    local okN, nowOpen = pcall(function() return inv:getOpenCustomInventory(src) end)
    -- getOpenCustomInventory is only in the patched vorp_inventory; without it trust openInventory
    if okN and nowOpen ~= id then
        StashOpenBy[src] = nil
        StaffStash[src] = nil
        return false, 'vorp_inventory did not open the container'
    end

    -- staff channel only (job nil), so the business does not see a staff look as its own
    SendLog(nil, 'Admin opened storage', COLOUR.yellow, table.pack(
        F('Who', WhoText(src)), F('Business', job, true), F('Container', b.containerid, true)),
        'Opened from the vorp_admin panel with the boss\'s controls.')
    return true
end)

exports('adminSetSocietySlots', function(job, slots)
    slots = tonumber(slots)
    if not slots or slots ~= slots or slots < 0 then return { ok = false, err = 'bad values' } end
    slots = math.floor(slots)
    if slots > Config.MaxSlotPurchase then return { ok = false, err = 'that is more slots than anyone needs' } end
    local b = type(job) == 'string' and Biz[job]
    if not b then return { ok = false, err = 'unknown business' } end
    if not b.containerid then return { ok = false, err = 'business has no container' } end
    EnsureContainerRow(job)
    MySQL.update.await('UPDATE container SET invslots = ? WHERE id = ?', { slots, b.containerid })
    RegisterStash(job, slots)
    return { ok = true, slots = slots, total = Config.BaseSlots + slots }
end)
