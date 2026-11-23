-- pup_hideouts | server core: identity, cache, persistence, views, net plumbing

Core = exports.vorp_core:GetCore()
Inv  = exports.vorp_inventory

HX = {
    hideouts  = {},  -- [id] = row (see load_row)
    online    = {},  -- [src] = charid
    occupants = {},  -- [id] = { [src] = true }
    menuLock  = {},  -- [id] = src
    stashLock = {},  -- [id] = src
    invites   = {},  -- [src] = { id, expires }
    buckets   = {},  -- [src] = last bucket we saw
    ready     = false,
}

local RES <const> = GetCurrentResourceName()

----------------------------------------------------------------------------------------------------
-- identity (always from VORP, never from the client)
----------------------------------------------------------------------------------------------------
function HX.user(src)
    if not src then return nil end
    local ok, u = pcall(Core.getUser, src)
    if ok then return u end
    return nil
end

function HX.char(src)
    local u = HX.user(src)
    return u and u.getUsedCharacter or nil
end

function HX.charId(src)
    local c = HX.char(src)
    return c and tonumber(c.charIdentifier) or nil
end

function HX.fullName(c)
    if not c then return 'Unknown' end
    local n = U.trim(('%s %s'):format(tostring(c.firstname or ''), tostring(c.lastname or '')))
    return n ~= '' and n or 'Unknown'
end

function HX.nameOf(src) return HX.fullName(HX.char(src)) end

function HX.isAdmin(src)
    local u = HX.user(src)
    if not u then return false end
    local c = u.getUsedCharacter
    return (c and c.group == 'admin') or u.getGroup == 'admin'
end

function HX.jobOf(src)
    local c = HX.char(src)
    return c and c.job or nil
end

function HX.isStaffJob(src) return U.inList(Config.StaffJobs, HX.jobOf(src)) end
function HX.isStaff(src) return HX.isAdmin(src) or HX.isStaffJob(src) end
function HX.isPoliceJob(src) return U.inList(Config.PoliceJobs, HX.jobOf(src)) end

function HX.srcOfChar(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    for src, cid in pairs(HX.online) do
        if cid == charid and GetPlayerName(src) then return src end
    end
    return nil
end

function HX.pos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function HX.alive(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return GetEntityHealth(ped) > 0
end

function HX.bucket(src) return GetPlayerRoutingBucket(src) end
function HX.bucketOf(h) return h.id + Config.InstanceOffset end
function HX.isInside(src, h) return h and HX.bucket(src) == HX.bucketOf(h) end

function HX.hideoutByBucket(b)
    local id = (tonumber(b) or 0) - Config.InstanceOffset
    return HX.hideouts[id]
end

----------------------------------------------------------------------------------------------------
-- notifications
----------------------------------------------------------------------------------------------------
function HX.tip(src, text, ms) TriggerClientEvent('vorp:TipRight', src, text, ms or 5000) end
function HX.bottom(src, text, ms) TriggerClientEvent('vorp:TipBottom', src, text, ms or 5000) end
function HX.left(src, text, ms)
    Core.NotifyLeft(src, L('title_hideout'), text, 'generic_textures', 'tick', ms or 5000, 'COLOR_WHITE')
end

----------------------------------------------------------------------------------------------------
-- membership
----------------------------------------------------------------------------------------------------
function HX.role(h, charid)
    charid = tonumber(charid)
    if not h or not charid then return nil end
    if h.owned and tonumber(h.charidentifier) == charid then return 'owner' end
    for _, co in ipairs(h.coowners) do
        if tonumber(co.charid) == charid then return 'coowner' end
    end
    return nil
end

function HX.isMember(h, charid) return HX.role(h, charid) ~= nil end

function HX.memberSources(h)
    local out, seen = {}, {}
    for src, cid in pairs(HX.online) do
        if not seen[src] and HX.isMember(h, cid) and GetPlayerName(src) then
            seen[src] = true
            out[#out + 1] = src
        end
    end
    return out
end

-- loot crew of a hideout that is open from a raid (raids.lua keeps the list)
function HX.isCrew(h, charid)
    if not h or not h.justraided then return false end
    return HX.Raids and HX.Raids.isLootCrew(h.id, charid) or false
end

----------------------------------------------------------------------------------------------------
-- rows: load / save
----------------------------------------------------------------------------------------------------
local function bool(v) return v == true or tonumber(v) == 1 end

local function parse_coords(raw)
    local v = U.decode(raw, nil)
    return U.plain(v) or { x = 0.0, y = 0.0, z = 0.0 }
end

local function parse_upgrades(raw)
    local v = U.decode(raw, {})
    local out = {}
    if type(v) ~= 'table' then return out end
    for k, set in pairs(v) do
        if type(k) == 'string' and type(set) == 'string' and set ~= '' then
            out[k] = set
        elseif type(set) == 'string' then
            local d = U.decoBySet(set)
            if d then out[d.category] = set end
        end
    end
    return out
end

local function normalize_items(list)
    local out, maxId = {}, 0
    for _, it in ipairs(type(list) == 'table' and list or {}) do
        local id = tonumber(it.id)
        if id and id > maxId then maxId = id end
    end
    local used = {}
    for _, it in ipairs(type(list) == 'table' and list or {}) do
        local count = math.floor(tonumber(it.count) or 0)
        if type(it.name) == 'string' and count > 0 then
            local id = tonumber(it.id)
            if not id or used[id] then
                maxId = maxId + 1
                id = maxId
            end
            used[id] = true
            out[#out + 1] = {
                id = id, name = it.name, label = tostring(it.label or it.name), count = count,
                limit = tonumber(it.limit) or 100, type = it.type or 'item_standard',
                metadata = type(it.metadata) == 'table' and it.metadata or {},
            }
        end
    end
    return out
end
HX.normalizeItems = normalize_items

local function parse_info(raw)
    local v = U.decode(raw, nil)
    if type(v) ~= 'table' or not v.resultitem then return nil end
    return v
end

local function parse_still(raw)
    local v = U.decode(raw, nil)
    if type(v) ~= 'table' then return nil end
    local lvl = tonumber(v.stilllevel)
    if not lvl or lvl < 1 then return nil end
    return { stilllevel = math.floor(lvl), stilltype = v.stilltype }
end

local function parse_coowners(raw)
    local v = U.decode(raw, {})
    local out = {}
    for _, e in ipairs(type(v) == 'table' and v or {}) do
        if type(e) == 'number' or type(e) == 'string' then
            local n = tonumber(e)
            if n then out[#out + 1] = { charid = n, name = 'Unknown' } end
        elseif type(e) == 'table' and tonumber(e.charid) then
            out[#out + 1] = { charid = tonumber(e.charid), name = tostring(e.name or 'Unknown') }
        end
    end
    return out
end
HX.parseCoowners = parse_coowners

function HX.loadRow(r)
    return {
        id = tonumber(r.id),
        identifier = r.identifier,
        charidentifier = tonumber(r.charidentifier),
        coords = parse_coords(r.coords),
        zone = r.zone or Config.DefaultZone,
        name = (r.name and r.name ~= '') and r.name or 'Hideout',
        theme = (r.theme and r.theme ~= '') and r.theme or nil,
        price = tonumber(r.price) or 0,
        upgrades = parse_upgrades(r.upgrades),
        owned = bool(r.owned),
        ledger = tonumber(r.ledger) or 0,
        items = normalize_items(U.decode(r.items, {})),
        invslots = math.floor(tonumber(r.invslots) or 0),
        invlevel = math.floor(tonumber(r.invlevel) or 0),
        bookie = bool(r.bookie),
        justraided = bool(r.justraided),
        raidcooldown = bool(r.raidcooldown),
        raidday = math.floor(tonumber(r.raidday) or 0),
        lasttimer = math.floor(tonumber(r.lasttimer) or 0),
        lasttimer2 = math.floor(tonumber(r.lasttimer2) or 0),
        mashinfo = parse_info(r.mashinfo),
        stillinfo = parse_info(r.stillinfo),
        still = parse_still(r.still),
        coowners = parse_coowners(r.coowners),
        webhook = (r.webhook and r.webhook ~= '') and r.webhook or nil,
        raidopenedat = math.floor(tonumber(r.raidopenedat) or 0),
    }
end

local function enc(t, emptyAs)
    if t == nil or (type(t) == 'table' and next(t) == nil) then return emptyAs or '[]' end
    return json.encode(t)
end

-- column -> serialiser
local COLS <const> = {
    identifier = function(h) return h.identifier end,
    charidentifier = function(h) return h.charidentifier end,
    coords = function(h) return json.encode({ x = h.coords.x, y = h.coords.y, z = h.coords.z }) end,
    zone = function(h) return h.zone end,
    name = function(h) return h.name end,
    theme = function(h) return h.theme end,
    price = function(h) return h.price end,
    upgrades = function(h) return enc(h.upgrades) end,
    owned = function(h) return h.owned and 1 or 0 end,
    ledger = function(h) return U.round2(h.ledger) end,
    items = function(h) return enc(h.items) end,
    invslots = function(h) return h.invslots end,
    invlevel = function(h) return h.invlevel end,
    bookie = function(h) return h.bookie and 1 or 0 end,
    justraided = function(h) return h.justraided and 1 or 0 end,
    raidcooldown = function(h) return h.raidcooldown and 1 or 0 end,
    raidday = function(h) return h.raidday end,
    lasttimer = function(h) return h.lasttimer end,
    lasttimer2 = function(h) return h.lasttimer2 end,
    mashinfo = function(h) return enc(h.mashinfo) end,
    stillinfo = function(h) return enc(h.stillinfo) end,
    still = function(h) return enc(h.still) end,
    coowners = function(h) return enc(h.coowners) end,
    webhook = function(h) return h.webhook end,
    raidopenedat = function(h) return h.raidopenedat end,
}

-- save the named columns (all when cols is nil); returns the oxmysql promise result
function HX.save(h, cols)
    if not h then return end
    local names = cols
    if not names then
        names = {}
        for k in pairs(COLS) do names[#names + 1] = k end
    end
    local sets, params = {}, {}
    for _, c in ipairs(names) do
        local f = COLS[c]
        if f then
            sets[#sets + 1] = ('`%s` = ?'):format(c)
            params[#params + 1] = f(h)
        end
    end
    if #sets == 0 then return end
    params[#params + 1] = h.id
    return MySQL.update.await(('UPDATE `underground` SET %s WHERE `id` = ?'):format(table.concat(sets, ', ')), params)
end

function HX.reloadAll()
    local rows = MySQL.query.await('SELECT * FROM `underground`', {}) or {}
    local fresh = {}
    for _, r in ipairs(rows) do
        local h = HX.loadRow(r)
        if h.id then fresh[h.id] = h end
    end
    HX.hideouts = fresh
end

function HX.reloadOne(id)
    local r = MySQL.single.await('SELECT * FROM `underground` WHERE `id` = ?', { id })
    if not r then
        HX.hideouts[id] = nil
        return nil
    end
    local h = HX.loadRow(r)
    HX.hideouts[id] = h
    return h
end

-- owned / co-owned counts for a character, read from the database
function HX.countsFor(charid)
    charid = tonumber(charid)
    if not charid then return 0, 0, 0 end
    local rows = MySQL.query.await(
        'SELECT `charidentifier`, `coowners`, `owned` FROM `underground` WHERE `charidentifier` = ? OR `coowners` LIKE ?',
        { charid, '%' .. tostring(charid) .. '%' }) or {}
    local owned, co = 0, 0
    for _, r in ipairs(rows) do
        if tonumber(r.charidentifier) == charid and bool(r.owned) then
            owned = owned + 1
        else
            for _, e in ipairs(parse_coowners(r.coowners)) do
                if tonumber(e.charid) == charid then co = co + 1 break end
            end
        end
    end
    return owned + co, owned, co
end

----------------------------------------------------------------------------------------------------
-- views: what each player is allowed to see
----------------------------------------------------------------------------------------------------
local function secsLeft(t)
    local left = (tonumber(t) or 0) - os.time()
    return left > 0 and left or 0
end

function HX.viewFor(h, src)
    local cid = HX.online[src]
    local role = HX.role(h, cid)
    if role then
        return {
            id = h.id, coords = h.coords, zone = h.zone, name = h.name, theme = h.theme, price = h.price,
            upgrades = h.upgrades, owned = h.owned, ledger = h.ledger, items = h.items, invslots = h.invslots,
            invlevel = h.invlevel, bookie = h.bookie, justraided = h.justraided, raidcooldown = h.raidcooldown,
            raidday = h.raidday, lasttimer = h.lasttimer, lasttimer2 = h.lasttimer2,
            mashinfo = h.mashinfo, stillinfo = h.stillinfo, still = h.still, coowners = h.coowners,
            charidentifier = h.charidentifier, raidopenedat = h.raidopenedat,
            role = role, member = true, haswebhook = h.webhook ~= nil,
            mashLeft = h.mashinfo and secsLeft(h.lasttimer) or 0,
            distillLeft = h.stillinfo and secsLeft(h.lasttimer2) or 0,
            jobCooldown = HX.Wagons and HX.Wagons.onCooldown(h.id) or false,
            isCrew = false,
        }
    end
    local crew = HX.isCrew(h, cid)
    return {
        id = h.id, coords = h.coords, owned = h.owned, price = h.price, zone = h.zone, name = h.name,
        theme = h.theme, upgrades = h.upgrades, justraided = h.justraided, raidcooldown = h.raidcooldown,
        bookie = h.bookie, invlevel = h.invlevel, invslots = h.invslots,
        still = h.still and { stilllevel = h.still.stilllevel } or nil,
        coowners = {}, member = false, haswebhook = false, mashLeft = 0, distillLeft = 0, jobCooldown = false,
        isCrew = crew, ledger = crew and h.ledger or nil,
    }
end

function HX.pushRow(h)
    if not h then return end
    for src in pairs(HX.online) do
        if GetPlayerName(src) then
            TriggerClientEvent('pup_hideouts:row', src, HX.viewFor(h, src))
        end
    end
end

function HX.pushAllTo(src)
    local list = {}
    for _, h in pairs(HX.hideouts) do list[#list + 1] = HX.viewFor(h, src) end
    TriggerClientEvent('pup_hideouts:rows', src, list)
end

function HX.pushAll()
    for src in pairs(HX.online) do
        if GetPlayerName(src) then HX.pushAllTo(src) end
    end
end

function HX.pushRemoved(id)
    TriggerClientEvent('pup_hideouts:removed', -1, id)
end

function HX.blips()
    TriggerClientEvent('pup_hideouts:blips', -1)
end

-- a row changed: tell everyone and refresh blips
function HX.changed(h, blips)
    HX.pushRow(h)
    if blips then HX.blips() end
end

----------------------------------------------------------------------------------------------------
-- net plumbing: validated events and request/response calls
----------------------------------------------------------------------------------------------------
local lastHit = {} -- [src] = { [key] = ms }

function HX.rateOk(src, key, ms)
    local now = GetGameTimer()
    local t = lastHit[src]
    if not t then t = {}; lastHit[src] = t end
    if t[key] and now - t[key] < ms then return false end
    t[key] = now
    return true
end

local function validSource(src)
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return nil end
    return src
end

-- RegisterNetEvent with a session/character check and a per-player rate limit
function HX.on(name, handler, rateMs)
    RegisterNetEvent('pup_hideouts:' .. name, function(...)
        local src = validSource(source)
        if not src or not HX.ready then return end
        if not HX.char(src) then return end
        if rateMs and not HX.rateOk(src, name, rateMs) then return end
        handler(src, ...)
    end)
end

local RPC = {}

-- handler(src, ...) returns the values sent back to the caller
function HX.rpc(name, handler, rateMs)
    RPC[name] = { fn = handler, rate = rateMs or 250 }
end

RegisterNetEvent('pup_hideouts:rpc', function(name, reqId, ...)
    local src = validSource(source)
    if not src or type(name) ~= 'string' then return end
    local entry = RPC[name]
    if not entry or not HX.ready or not HX.char(src) then
        TriggerClientEvent('pup_hideouts:rpcReply', src, reqId, nil)
        return
    end
    if not HX.rateOk(src, 'rpc:' .. name, entry.rate) then
        TriggerClientEvent('pup_hideouts:rpcReply', src, reqId, nil)
        return
    end
    local results = table.pack(pcall(entry.fn, src, ...))
    if not results[1] then
        print(('^1[%s]^7 %s failed: %s'):format(RES, name, tostring(results[2])))
        TriggerClientEvent('pup_hideouts:rpcReply', src, reqId, nil)
        return
    end
    TriggerClientEvent('pup_hideouts:rpcReply', src, reqId, table.unpack(results, 2, results.n))
end)

function HX.forgetRate(src) lastHit[src] = nil end

----------------------------------------------------------------------------------------------------
-- money helpers (cash = currency 0)
----------------------------------------------------------------------------------------------------
function HX.cash(src)
    local c = HX.char(src)
    return c and (tonumber(c.money) or 0) or 0
end

-- take cash only when the player still has it; returns true on success
function HX.takeCash(src, amount)
    amount = U.round2(amount)
    if amount <= 0 then return true end
    local c = HX.char(src)
    if not c or (tonumber(c.money) or 0) < amount then return false end
    c.removeCurrency(0, amount)
    return true
end

function HX.giveCash(src, amount)
    amount = U.round2(amount)
    if amount <= 0 then return end
    local c = HX.char(src)
    if c then c.addCurrency(0, amount) end
end

-- pay a character, online or offline
function HX.payChar(charid, amount)
    amount = U.round2(amount)
    if amount <= 0 then return end
    local src = HX.srcOfChar(charid)
    if src and HX.charId(src) == tonumber(charid) then
        HX.giveCash(src, amount)
        return src
    end
    local q = 'UPDATE `characters` SET `money` = `money` + ? WHERE `charidentifier` = ?'
    if HX.stopping then
        MySQL.update(q, { amount, charid }) -- no awaiting while the resource shuts down
    else
        MySQL.update.await(q, { amount, charid })
    end
    return nil
end

----------------------------------------------------------------------------------------------------
-- perks (optional, fail safe)
----------------------------------------------------------------------------------------------------
local function perksUp() return GetResourceState('pup-perks') == 'started' end

function HX.perkMult(src, key)
    if not perksUp() then return 1.0 end
    local ok, v = pcall(function() return exports['pup-perks']:Mult(src, key) end)
    v = ok and tonumber(v) or 1.0
    if not v or v <= 0 then v = 1.0 end
    return v
end

function HX.perkBonus(src, key)
    if not perksUp() then return 0 end
    local ok, v = pcall(function() return exports['pup-perks']:Bonus(src, key) end)
    return ok and (tonumber(v) or 0) or 0
end

function HX.perkAward(src, kind)
    if not perksUp() then return end
    pcall(function() exports['pup-perks']:Award(src, kind) end)
end

----------------------------------------------------------------------------------------------------
-- inventory helpers
----------------------------------------------------------------------------------------------------
function HX.itemCount(src, name)
    local ok, n = pcall(function() return Inv:getItemCount(src, nil, name) end)
    return ok and (tonumber(n) or 0) or 0
end

function HX.removeItem(src, name, amount)
    if HX.itemCount(src, name) < amount then return false end
    local ok, done = pcall(function() return Inv:subItem(src, name, amount) end)
    return ok and done == true
end

function HX.canCarry(src, name, amount)
    local ok, v = pcall(function() return Inv:canCarryItem(src, name, amount) end)
    return ok and v == true
end

function HX.canCarryTotal(src, amount)
    local ok, v = pcall(function() return Inv:canCarryItems(src, amount) end)
    return ok and v == true
end

function HX.addItem(src, name, amount, metadata)
    local ok, done = pcall(function() return Inv:addItem(src, name, amount, metadata) end)
    return ok and done == true
end

function HX.itemLabel(name)
    local ok, it = pcall(function() return Inv:getItemDB(name) end)
    if ok and type(it) == 'table' and it.label then return tostring(it.label) end
    return name
end

----------------------------------------------------------------------------------------------------
-- police
----------------------------------------------------------------------------------------------------
local function mdtUp() return GetResourceState('pup-mdt') == 'started' end

function HX.onDuty(src)
    if not HX.isPoliceJob(src) then return false end
    if not mdtUp() then return true end
    local ok, v = pcall(Config.Integrations.mdtOnDuty, src)
    if not ok then U.warnIntegration('mdtOnDuty', v) return true end
    return v == true
end

function HX.policeSources(dutyOnly)
    local out = {}
    for src in pairs(HX.online) do
        if GetPlayerName(src) and HX.isPoliceJob(src) and (not dutyOnly or HX.onDuty(src)) then
            out[#out + 1] = src
        end
    end
    return out
end

-- our own fallback alert: a blip and screen text on every on-duty police client
function HX.fallbackAlert(coords, text)
    for _, s in ipairs(HX.policeSources(true)) do
        TriggerClientEvent('pup_hideouts:alert', s, U.plain(coords), text or L('crime_reported'))
    end
end

-- feed alert (anonymous); falls back to our own when pup-mdt is down or refuses
function HX.policeAlert(coords, text)
    if mdtUp() then
        local ok, accepted = pcall(Config.Integrations.mdtAlert, U.plain(coords), text)
        if not ok then U.warnIntegration('mdtAlert', accepted) end
        if ok and accepted ~= false and accepted ~= nil then return end
    end
    HX.fallbackAlert(coords, L('crime_reported'))
end

function HX.radiusAlert(coords, text, radius)
    if mdtUp() then
        local ok, err = pcall(Config.Integrations.mdtRadius, U.plain(coords), text, radius)
        if ok then return end -- false = pup-mdt's own chance roll said no; accepted
        U.warnIntegration('mdtRadius', err)
    end
    HX.fallbackAlert(coords, L('crime_reported'))
end

function HX.zoneName(coords)
    if not mdtUp() then return nil end
    local ok, z = pcall(Config.Integrations.mdtZone, U.plain(coords))
    if not ok then U.warnIntegration('mdtZone', z) return nil end
    return z
end
