-- pup_gunsmith | crafting at a station: open, start (ticket), finish, the crafting box

Craft = {}

local ticketCounter = 0

local noSerial = {}
for _, w in ipairs(Config.Craft.noSerial) do noSerial[w:upper()] = true end

local function readXp(charId)
    local ok, v = pcall(MySQL.scalar.await, 'SELECT gunsmith FROM characters WHERE charidentifier = ?', { charId })
    return ok and (tonumber(v) or 0) or 0
end

local function stationAccess(char, station)
    return Srv.hasAccess(char, station.jobs, Config.Craft.minGrade)
end

local function boxId(charId)
    return tostring(Config.Craft.boxBase + (tonumber(charId) or 0))
end

local function registerBox(charId)
    local id = boxId(charId)
    pcall(function()
        Inv:registerInventory({
            id = id,
            name = L('box_name'),
            limit = 0, -- no slot limit
            acceptWeapons = false,
            shared = true,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false,
        })
    end)
    return id
end

--- the recipe as the client sees it (no experience values, no job lists)
local function clientRecipe(rec)
    local mats = {}
    for _, m in ipairs(rec.mats) do mats[#mats + 1] = { name = m.name, label = m.label, amount = m.amount } end
    return {
        label = rec.label,
        weapon = rec.hashname,
        item = rec.item,
        qt = rec.qt,
        diff = rec.diff,
        mats = mats,
    }
end

-- player's visible recipes and the counts of every material they use
local function visibleRecipes(src, char, xp)
    local out = { weapon = {}, ammo = {} }
    local need = {}
    for kind, cats in pairs(Recipes.live) do
        for cat, list in pairs(cats) do
            for _, rec in pairs(list) do
                if Recipes.allowed(rec, char, xp) then
                    out[kind][cat] = out[kind][cat] or {}
                    table.insert(out[kind][cat], clientRecipe(rec))
                    for _, m in ipairs(rec.mats) do need[m.name] = true end
                end
            end
        end
    end
    local counts = {}
    for item in pairs(need) do counts[item] = Srv.count(src, item) end
    return out, counts
end

---------------------------------------------------------------------------
-- open
---------------------------------------------------------------------------
Srv.rpc('stationOpen', function(src, char, name)
    local station = Stations.get(name)
    if not station then return { ok = false } end
    if not Srv.near(src, station.coords, Config.Craft.reach) then return { ok = false } end
    if not stationAccess(char, station) then return { ok = false, msg = L('no_job_craft') } end

    local st = Srv.st(src, char)
    st.station = station.name

    local xp = readXp(char.charIdentifier)
    if not Srv.same(src, char) then return { ok = false } end
    local recipes, counts = visibleRecipes(src, char, xp)
    return {
        ok = true,
        xp = xp,
        weapons = recipes.weapon,
        ammo = recipes.ammo,
        counts = counts,
        jobs = station.jobs,
        jobOnly = Config.JobOnly,
        box = Config.Craft.useBox,
    }
end, { throttle = 750 })

---------------------------------------------------------------------------
-- start: every rule checked, a single-use ticket issued
---------------------------------------------------------------------------
local function cleanCustom(kind, rec, custom)
    if kind ~= 'weapon' or type(custom) ~= 'table' then return nil end
    local out, any = {}, false
    local opts, max = Config.Craft.custom, Config.Craft.customMax
    local function take(key, field)
        if not opts[key] then return end
        local v = GS.cut(GS.cleanText(custom[field]), max[key])
        v = GS.trim(v)
        if v ~= '' then out[field] = v; any = true end
    end
    take('serial', 'serial')
    take('label', 'label')
    take('description', 'description')
    if out.serial and noSerial[(rec.hashname or ''):upper()] then out.serial = nil end
    if not (out.serial or out.label or out.description) then any = false end
    return any and out or nil
end

-- the shared checks of start and finish; returns rec or nil, message
local function checkCraft(src, char, stationName, kind, category, label, amount)
    local station = Stations.get(stationName)
    if not station or not Srv.near(src, station.coords, Config.Craft.reach) then
        return nil, L('stand_station')
    end
    if not stationAccess(char, station) then return nil, L('no_job_craft') end
    local rec = Recipes.get(kind, category, label)
    if not rec then return nil, L('craft_cant'), true end
    local xp = readXp(char.charIdentifier)
    if not Srv.same(src, char) then return nil, L('craft_cant') end
    if not Srv.near(src, station.coords, Config.Craft.reach) then return nil, L('stand_station') end
    if not Recipes.allowed(rec, char, xp) then
        return nil, rec.jobonly and L('no_job_craft') or L('craft_cant')
    end
    if not Srv.hasMaterials(src, rec.mats, amount) then return nil, L('no_materials') end
    return rec
end

Srv.rpc('craftStart', function(src, char, kind, category, label, amount, custom)
    local st = Srv.st(src, char)
    if not st.station then return { ok = false, msg = L('stand_station') } end
    if kind ~= 'weapon' and kind ~= 'ammo' then return { ok = false, msg = L('craft_cant') } end
    if type(category) ~= 'string' or type(label) ~= 'string' then return { ok = false, msg = L('craft_cant') } end

    if not Recipes.get(kind, category, label) then
        Srv.security(src, 'asked to craft an unknown recipe %s / %s / %s', tostring(kind), category:sub(1, 64), label:sub(1, 128))
        return { ok = false, msg = L('craft_cant') }
    end

    local n = 1
    if kind == 'ammo' then
        n = GS.int(amount)
        if not n or n < 1 or n > Config.Craft.maxAmount or n ~= tonumber(amount) then
            return { ok = false, msg = L('invalid_amount') }
        end
    end

    local rec, msg = checkCraft(src, char, st.station, kind, category, label, n)
    if not rec then return { ok = false, msg = msg } end

    ticketCounter = ticketCounter + 1
    st.ticket = {
        no = ticketCounter,
        kind = kind, category = category, label = label, amount = n,
        station = st.station,
        custom = cleanCustom(kind, rec, custom),
        expires = os.time() + Config.Craft.ticketSeconds,
    }
    return { ok = true, ticket = ticketCounter, diff = rec.diff }
end, { exclusive = true, throttle = 500 })

---------------------------------------------------------------------------
-- finish
---------------------------------------------------------------------------
local function grantXp(src, char, rec, amount)
    local gained = (tonumber(rec.expadd) or 0) * amount
    if gained > 0 then
        pcall(MySQL.update.await, 'UPDATE characters SET gunsmith = COALESCE(gunsmith, 0) + ? WHERE charidentifier = ?',
            { gained, char.charIdentifier })
    end
    if Config.Craft.perksAward and GetResourceState('pup-perks') == 'started' then
        pcall(function() exports['pup-perks']:Award(src, 'gunsmith') end)
    end
    return gained, readXp(char.charIdentifier)
end

local function depositToBox(src, char, item, amount)
    local id = registerBox(char.charIdentifier)
    local ok, res = pcall(function()
        return Inv:addItemsToCustomInventory(id, { { name = item, amount = amount } }, char.charIdentifier, nil, char.identifier)
    end)
    return ok and res == true
end

local function finishWon(src, char, rec, t)
    local n = t.amount
    local note = nil

    if rec.kind == 'ammo' then
        if not Config.Craft.useBox then
            local okC, can = pcall(function() return Inv:canCarryItem(src, rec.item, n) end)
            if not okC or not can then return { ok = false, msg = L('cant_carry_items') } end
        end
        if not Srv.takeMaterials(src, rec.mats, n) then return { ok = false, msg = L('no_materials') } end
        local placed = false
        if Config.Craft.useBox then
            placed = depositToBox(src, char, rec.item, n)
            if placed then note = L('craft_into_box') end
        end
        if not placed then
            -- the satchel fallback checks room first; with no room the materials go back
            local okC, can = pcall(function() return Inv:canCarryItem(src, rec.item, n) end)
            local added = false
            if okC and can then
                local okA, res = pcall(function() return Inv:addItem(src, rec.item, n) end)
                added = okA and res ~= false
            end
            if not added then
                Srv.giveMaterials(src, rec.mats, n)
                return { ok = false, msg = L('cant_carry_items') }
            end
        end
    else
        local weapon = rec.hashname:upper()
        local okC, can = pcall(function() return Inv:canCarryWeapons(src, 1, nil, weapon) end)
        if not okC or not can then return { ok = false, msg = L('cant_carry_weapon') } end
        if not Srv.takeMaterials(src, rec.mats, 1) then return { ok = false, msg = L('no_materials') } end
        local c = t.custom or {}
        local okW, made = pcall(function()
            return Inv:createWeapon(src, weapon, {}, {}, {}, nil, nil, c.serial, c.label, c.description)
        end)
        if not okW or made ~= true then
            Srv.giveMaterials(src, rec.mats, 1)
            return { ok = false, msg = L('cant_carry_weapon') }
        end
    end

    local gained, total = grantXp(src, char, rec, n)
    Discord.craft({ src = src, char = char, recipe = rec, amount = n, won = true, consumed = true,
        gained = gained, total = total, custom = t.custom })
    return { ok = true, msg = L('craft_success'), note = note, gained = gained, total = total }
end

Srv.rpc('craftFinish', function(src, char, ticketNo, won)
    local st = Srv.st(src, char)
    -- the ticket is used up before anything else
    local t = st.ticket
    st.ticket = nil
    if not t or t.no ~= ticketNo then
        Srv.security(src, 'craft finish without a matching ticket (duplicate or forged): %s', tostring(ticketNo))
        return { ok = false }
    end
    if os.time() > t.expires then return { ok = false, msg = L('craft_cant') } end
    local station = Stations.get(t.station)
    if not station or not Srv.near(src, station.coords, Config.Craft.reach) then
        return { ok = false, msg = L('craft_cant') }
    end

    local rec, msg = checkCraft(src, char, t.station, t.kind, t.category, t.label, t.amount)
    if not rec then return { ok = false, msg = msg } end

    -- pup-minigames reports 'success', 'perfect' or 'failed'; the client relays it
    if won ~= true then
        local consumed = false
        if Config.Craft.failConsumes then
            consumed = Srv.takeMaterials(src, rec.mats, t.amount)
        end
        Discord.craft({ src = src, char = char, recipe = rec, amount = t.amount, won = false, consumed = consumed })
        return { ok = false, msg = L('craft_failed') }
    end
    return finishWon(src, char, rec, t)
end, { exclusive = true })

---------------------------------------------------------------------------
-- crafting box
---------------------------------------------------------------------------
Srv.rpc('openBox', function(src, char)
    if not Config.Craft.useBox then return { ok = false } end
    local st = Srv.st(src, char)
    local station = st.station and Stations.get(st.station)
    if not station or not Srv.near(src, station.coords, Config.Craft.reach) then
        return { ok = false, msg = L('stand_station') }
    end
    local id = registerBox(char.charIdentifier)
    local ok = pcall(function() Inv:openInventory(src, id) end)
    return { ok = ok }
end, { throttle = 1000 })

Srv.onReset(function(_, st)
    st.station = nil
    st.ticket = nil
end)
