-- pup_mercantile | optional neighbours: pup-misc, pup_postoffice, pup_business tables

Misc = {}

local warned = {}

local function miscCall(key, ...)
    local cfg = Config.Misc
    if not ResourceUp(cfg.resource) then return false, 'down' end
    local name = cfg.exports[key]
    if not name then return false, 'noexport' end
    local args = table.pack(...)
    local res = table.pack(pcall(function()
        local proxy = exports[cfg.resource]
        return proxy[name](proxy, table.unpack(args, 1, args.n))
    end))
    if not res[1] and not warned[name] then
        warned[name] = true
        print(('^3[pup_mercantile]^7 %s export %s failed (%s); check Config.Misc.exports')
            :format(cfg.resource, name, tostring(res[2])))
    end
    return table.unpack(res, 1, res.n)
end

-- Eco Boost bonus on an NPC sale; 0 when pup-misc is absent or the boost is off.
-- pup-misc's ApplyEcoBoostSale(src, placeName, total) records the bonus as earned,
-- so it is called once per paid sale and never for a refused one.
function Misc.ecoBonus(src, storeName, _itemName, _amount, total)
    local ok, v = miscCall('ecoBonus', src, storeName, total)
    v = ok and tonumber(v) or 0
    if v ~= v or v < 0 or v > total * 10 then return 0 end
    return Util.round2(v)
end

function Misc.ecoMultiplier(src, storeName)
    local ok, v = miscCall('ecoMultiplier', src, storeName)
    v = ok and tonumber(v) or 1
    if v ~= v or v < 1 or v > 10 then return 1 end
    return v
end

local boxNames = {}
local boxNamesFromMisc = false
for _, n in ipairs(Config.Misc.fallbackBoxNames) do boxNames[n] = true end

function Misc.isBox(name)
    return boxNames[name] == true
end

CreateThread(function()
    while not boxNamesFromMisc do
        local ok, list = miscCall('boxNames')
        if ok and type(list) == 'table' and next(list) then
            local set = {}
            for k, v in pairs(list) do
                if type(v) == 'string' then set[v] = true
                elseif type(k) == 'string' and v then set[k] = true end
            end
            if next(set) then
                boxNames = set
                boxNamesFromMisc = true
                Dbg('box and pack names loaded from pup-misc')
                break
            end
        end
        Wait(15000)
    end
end)

-- pup-misc's box exports all take the carried box's INVENTORY item id and prove
-- ownership themselves; none takes a raw box id.

-- contents of a carried box: array of { craftedId, name, label, amount, percentage, metadata };
-- nil when pup-misc is down or the box is not the player's (or was never opened)
function Misc.boxContents(src, boxItemId)
    local ok, v = miscCall('boxContents', src, tonumber(boxItemId))
    if not ok or type(v) ~= 'table' then return nil end
    return v
end

-- take one stack (by its craftedId) out of a carried box
function Misc.boxTake(src, boxItemId, craftedId, amount, lease)
    if craftedId == nil then return false end
    local ok, v = LeaseWait(lease, Config.Misc.resource, miscCall, 'boxTake', src, tonumber(boxItemId), craftedId, amount)
    return ok and v == true
end

-- returns the units that landed (pup-misc stamps a never-opened box itself)
function Misc.boxPut(src, boxItemId, name, amount, metadata, lease)
    local ok, v = LeaseWait(lease, Config.Misc.resource, miscCall, 'boxPut', src, tonumber(boxItemId), name, amount, metadata or {})
    if not ok then return 0 end
    v = math.floor(tonumber(v) or 0)
    if v < 0 then return 0 end
    return math.min(v, amount)
end

-- units the box still takes (pup-misc has no per-item figure; a job pack may still refuse the item)
function Misc.boxFree(src, boxItemId)
    local ok, v = miscCall('boxFree', src, tonumber(boxItemId))
    if not ok then return 0 end
    return math.max(0, math.floor(tonumber(v) or 0))
end

function Misc.boxConsume(src, boxItemId)
    local ok, v = miscCall('boxConsume', src, tonumber(boxItemId))
    return ok and v == true
end

-- the carried item with this inventory id when it is a box or pack, else nil
function Misc.boxItem(src, invItemId)
    local item = Inv:getItemByMainId(src, tonumber(invItemId))
    if type(item) ~= 'table' or not Misc.isBox(item.name) then return nil end
    return item
end

-- the box id stamped on a carried box, read from the server's own copy
function Misc.boxIdOf(src, invItemId)
    local item = Inv:getItemByMainId(src, tonumber(invItemId))
    if type(item) ~= 'table' then return nil, nil end
    local meta = item.metadata
    if type(meta) == 'string' then
        local ok, d = pcall(json.decode, meta)
        meta = ok and d or nil
    end
    local boxId = type(meta) == 'table' and meta.boxId or nil
    return boxId, item
end

-- true when a carried box or pack holds nothing; refuses on any doubt
function Misc.packIsEmpty(src, invItemId)
    local ok, empty = WithTimeout(Config.Misc.packCheckTimeout, function()
        local boxId, item = Misc.boxIdOf(src, invItemId)
        if not item then return false end
        if not boxId then return true end -- never opened
        local contents = Misc.boxContents(src, invItemId)
        if contents == nil then return false end
        for _, row in pairs(contents) do
            if type(row) == 'table' and (tonumber(row.count or row.amount) or 1) > 0 then return false end
        end
        return true
    end)
    return ok == true and empty == true
end

------------------------------------------------------------------------------
-- pup_postoffice
------------------------------------------------------------------------------
-- fromName is optional; the store office signs when it is left out
function SendMail(charid, subject, body, fromName)
    local res = Config.Integrations.postoffice
    if not ResourceUp(res) then return false end
    local ok, sent = pcall(function()
        return exports[res]:SendSystemMail(charid, subject, body, fromName or Config.Tax.mailFrom)
    end)
    return ok and sent == true
end

------------------------------------------------------------------------------
-- pup_business: boss ranks and the society ledger
------------------------------------------------------------------------------
BossRanks = {}

local function ranksFromConfigFile()
    local out = {}
    local res = Config.Integrations.business
    local raw = LoadResourceFile(res, 'config/main.lua')
    if not raw or raw == '' then return out end
    -- a data-only sandbox: the file can build tables but reach nothing else
    local env = {
        Config = {}, vector3 = vector3, vec3 = vec3, vector4 = vector4, vec4 = vec4,
        pairs = pairs, ipairs = ipairs, tonumber = tonumber, tostring = tostring, type = type,
        string = string, math = math, table = table, json = json,
    }
    local chunk = load(raw, '@' .. res .. '/config/main.lua', 't', env)
    if not chunk then return out end
    if not pcall(chunk) then return out end
    local list = env.Config and env.Config.Businesses
    if type(list) ~= 'table' then return out end
    for k, v in pairs(list) do
        if type(v) == 'table' then
            local job = type(v.job) == 'string' and v.job or (type(k) == 'string' and k or nil)
            local rank = tonumber(v.bossrank or v.bossRank or v.BossRank)
            if job and rank then out[job] = math.floor(rank) end
        end
    end
    return out
end

function RefreshBossRanks()
    local ranks = ranksFromConfigFile()
    local ok, rows = pcall(MySQL.query.await, 'SELECT job, bossrank FROM society_business')
    if ok and type(rows) == 'table' then
        for _, r in ipairs(rows) do
            local rank = tonumber(r.bossrank)
            -- pup_business treats a stored boss rank below 1 as 1; match it
            if r.job and rank then ranks[tostring(r.job)] = math.max(1, math.floor(rank)) end
        end
    end
    local ok2, rows2 = pcall(MySQL.query.await, 'SELECT job, MAX(jobgrade) AS top FROM society GROUP BY job')
    if ok2 and type(rows2) == 'table' then
        for _, r in ipairs(rows2) do
            local job = r.job and tostring(r.job)
            if job and ranks[job] == nil and tonumber(r.top) then ranks[job] = math.floor(tonumber(r.top)) end
        end
    end
    BossRanks = ranks
    Dbg('boss ranks loaded')
end

function IsBoss(char, job)
    if not char or not job or char.job ~= job then return false end
    local rank = BossRanks[job]
    if rank == nil then return false end
    return (tonumber(char.jobGrade) or -1) >= rank
end

-- society_ledger holds whole dollars. Cents are carried here so no money is made
-- or lost by rounding; the carry is per business and lasts until restart.
local carry = {}

local function ledgerAdd(job, whole)
    if whole <= 0 then return true end
    -- LIMIT 1: society_ledger has no guaranteed unique key on job (pup_business adds one
    -- only when no duplicates exist), so never credit more than one row
    local ok, n = pcall(MySQL.update.await, 'UPDATE society_ledger SET ledger = ledger + ? WHERE job = ? LIMIT 1', { whole, job })
    if ok and (tonumber(n) or 0) > 0 then return true end
    -- no row yet: create the same empty row shape pup_business creates, only if still missing
    pcall(MySQL.query.await,
        "INSERT INTO society_ledger (job, ledger, webhook, invaccess) SELECT ?, 0, '', 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM society_ledger WHERE job = ?)",
        { job, job })
    local ok2, n2 = pcall(MySQL.update.await, 'UPDATE society_ledger SET ledger = ledger + ? WHERE job = ? LIMIT 1', { whole, job })
    return ok2 and (tonumber(n2) or 0) > 0
end

function SocietyCredit(job, amount, shopName)
    amount = Util.round2(amount)
    if amount <= 0 then return true end
    local total = Util.round2((carry[job] or 0) + amount)
    local whole = math.floor(total)
    carry[job] = Util.round2(total - whole)
    local ok = ledgerAdd(job, whole)
    if shopName then
        pcall(MySQL.insert.await,
            'INSERT INTO society_activity (job, ts, type, detail, actor) VALUES (?, ?, ?, ?, ?)',
            { job, os.time(), 'SHOPSALE', ('%s: +$%s'):format(shopName, Util.fmt(amount)), 'Store' })
    end
    return ok
end

-- guarded debit: succeeds only when the ledger covers it, so two sellers cannot overdraw
function SocietyDebit(job, amount)
    amount = Util.round2(amount)
    if amount <= 0 then return true end
    local have = carry[job] or 0
    if have >= amount then
        carry[job] = Util.round2(have - amount)
        return true
    end
    -- take the carried cents now: other credits and debits may run while the update waits
    carry[job] = 0
    local need = Util.round2(amount - have)
    local whole = math.ceil(need - 0.000001)
    local ok, n = pcall(MySQL.update.await,
        'UPDATE society_ledger SET ledger = ledger - ? WHERE job = ? AND ledger >= ? LIMIT 1', { whole, job, whole })
    if not ok or (tonumber(n) or 0) < 1 then
        carry[job] = Util.round2((carry[job] or 0) + have)
        return false
    end
    carry[job] = Util.round2((carry[job] or 0) + (whole - need))
    return true
end

function SocietyFunds(job)
    local ok, v = pcall(MySQL.scalar.await, 'SELECT ledger FROM society_ledger WHERE job = ? LIMIT 1', { job })
    return Util.round2((ok and tonumber(v) or 0) + (carry[job] or 0))
end
