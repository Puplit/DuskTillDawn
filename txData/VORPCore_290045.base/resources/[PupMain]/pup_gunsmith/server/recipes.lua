-- pup_gunsmith | recipes: database-backed, edited live from vorp_admin
-- Live recipes are grouped kind -> category -> display name. Only enabled rows are live.

Recipes = {
    live = { weapon = {}, ammo = {} },
}

local KINDS <const> = { weapon = true, ammo = true }

---------------------------------------------------------------------------
-- JSON with exact 64-bit check values
-- guncheck / guncheck2 would be rounded as floats, so their raw text is kept aside
-- when decoding and written back verbatim when encoding.
---------------------------------------------------------------------------
local RAW_FIELDS <const> = { 'guncheck', 'guncheck2' }

local function isRawNumber(s)
    return type(s) == 'string' and s:match('^%-?%d+%.?%d*$') ~= nil
end

local function extractRaw(text)
    local raw = {}
    if type(text) ~= 'string' then return raw end
    for _, f in ipairs(RAW_FIELDS) do
        local v = text:match('"' .. f .. '"%s*:%s*(%-?[%d%.]+)[%s,}]')
        if isRawNumber(v) then raw[f] = v end
    end
    return raw
end

--- encodes recipe data, writing raw check values back exactly
function Recipes.encode(data, raw)
    local copy = GS.copy(data)
    raw = raw or {}
    for _, f in ipairs(RAW_FIELDS) do
        if raw[f] then copy[f] = '@@RAW_' .. f .. '@@' end
    end
    local out = json.encode(copy)
    for _, f in ipairs(RAW_FIELDS) do
        if raw[f] then
            out = out:gsub('"@@RAW_' .. f .. '@@"', raw[f])
        end
    end
    return out
end

function Recipes.decode(text)
    if type(text) ~= 'string' or text == '' then return nil, {} end
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= 'table' then return nil, {} end
    return data, extractRaw(text)
end

-- '0xDDB2...' -> exact unsigned decimal text
local function hexToDecimal(hex)
    local digits = { 0 }
    for c in hex:gmatch('%x') do
        local carry = tonumber(c, 16)
        for i = 1, #digits do
            local v = digits[i] * 16 + carry
            digits[i] = v % 10
            carry = v // 10
        end
        while carry > 0 do
            digits[#digits + 1] = carry % 10
            carry = carry // 10
        end
    end
    local out = {}
    for i = #digits, 1, -1 do out[#out + 1] = tostring(digits[i]) end
    local s = table.concat(out):gsub('^0+', '')
    return s == '' and '0' or s
end

-- a check value from the admin form -> raw text, or nil when it should not replace the stored one
local function formCheckValue(v, storedRaw)
    if v == nil then return nil end
    if type(v) == 'number' then
        if v ~= v then return nil end
        -- a float that only echoes the stored value back must not overwrite the exact text
        if storedRaw and tonumber(storedRaw) and math.abs(tonumber(storedRaw) - v) <= math.abs(v) * 1e-12 then
            return nil
        end
        if math.type(v) == 'integer' then return tostring(v) end
        return ('%.0f'):format(v)
    end
    local s = GS.trim(tostring(v))
    if s == '' then return nil end
    if s:match('^0[xX]%x+$') then return hexToDecimal(s:sub(3)) end
    if isRawNumber(s) then return s end
    return nil
end

---------------------------------------------------------------------------
-- normalising stored data into what the code uses
---------------------------------------------------------------------------
local function keyOrder(a, b)
    local sa, sb = tostring(a), tostring(b)
    local na, nb = tonumber(sa:match('(%d+)$')), tonumber(sb:match('(%d+)$'))
    local pa, pb = sa:gsub('%d+$', ''), sb:gsub('%d+$', '')
    if pa ~= pb then return pa < pb end
    if na and nb and na ~= nb then return na < nb end
    return sa < sb
end

function Recipes.materialList(materials)
    local keys = {}
    if type(materials) ~= 'table' then return {} end
    for k, v in pairs(materials) do
        if type(v) == 'table' and type(v.name) == 'string' and v.name ~= '' then keys[#keys + 1] = k end
    end
    table.sort(keys, keyOrder)
    local out = {}
    for _, k in ipairs(keys) do
        local v = materials[k]
        out[#out + 1] = {
            name = v.name,
            label = tostring(v.label or v.name),
            amount = math.max(1, GS.int(v.amount) or 1),
        }
    end
    return out
end

local function normalise(id, kind, category, label, data)
    local jobs = {}
    if type(data.jobs) == 'table' then
        for _, j in ipairs(data.jobs) do jobs[#jobs + 1] = tostring(j) end
    elseif type(data.jobs) == 'string' then
        jobs = GS.splitJobs(data.jobs)
    end
    local rec = {
        id = id, kind = kind, category = category, label = label,
        expadd = tonumber(data.expadd) or 0,
        expreq = tonumber(data.expreq) or 0,
        diff = tonumber(data.diff) or 3000,
        letcraft = data.letcraft ~= false,
        jobonly = data.jobonly == true,
        jobs = jobs,
        mats = Recipes.materialList(data.materials),
    }
    if kind == 'weapon' then
        rec.hashname = type(data.hashname) == 'string' and data.hashname or nil
        if not rec.hashname then return nil end
    else
        rec.item = type(data.item) == 'string' and data.item or nil
        rec.key = type(data.key) == 'string' and data.key or nil
        rec.qt = math.max(1, GS.int(data.qt) or 1)
        rec.maxammo = GS.int(data.maxammo) or 0
        if not rec.item or not rec.key then return nil end
    end
    return rec
end

local function place(set, rec)
    set[rec.kind][rec.category] = set[rec.kind][rec.category] or {}
    set[rec.kind][rec.category][rec.label] = rec
end

-- until the database answers, the seed recipes are live
do
    local set = { weapon = {}, ammo = {} }
    for _, list in ipairs({ Seeds.Weapons, Seeds.Ammo }) do
        for _, s in ipairs(list) do
            local rec = normalise(nil, s.kind, s.category, s.label, s.data)
            if rec then place(set, rec) end
        end
    end
    Recipes.live = set
end

---------------------------------------------------------------------------
-- loading
---------------------------------------------------------------------------
function Recipes.seedIfEmpty()
    local ok, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM weapon_recipes')
    if not ok or tonumber(n) ~= 0 then return end
    local added = 0
    -- weapons first, then ammo, so ids follow the order in config/seeds.lua
    for _, list in ipairs({ Seeds.Weapons, Seeds.Ammo }) do
        for _, s in ipairs(list) do
            local text = Recipes.encode(s.data, s.rawChecks)
            local okI = pcall(MySQL.insert.await,
                'INSERT IGNORE INTO weapon_recipes (kind, category, label, enabled, data) VALUES (?, ?, ?, 1, ?)',
                { s.kind, s.category, s.label, text })
            if okI then added = added + 1 end
        end
    end
    print(('[pup_gunsmith] seeded %d recipes into weapon_recipes'):format(added))
end

--- reads the enabled recipes. A read that succeeds replaces the live set, even when a
--- kind comes back empty (disabling every recipe of a kind takes effect at once).
--- A read that fails keeps what is live.
function Recipes.load()
    local ok, rows = pcall(MySQL.query.await,
        'SELECT id, kind, category, label, data FROM weapon_recipes WHERE enabled = 1')
    if not ok or type(rows) ~= 'table' then
        print(('^1[pup_gunsmith]^7 could not read the recipes (%s) - keeping the current set'):format(tostring(rows)))
        return false
    end
    local set, n = { weapon = {}, ammo = {} }, 0
    for _, row in ipairs(rows) do
        if KINDS[row.kind] then
            local data = Recipes.decode(row.data)
            if data then
                local rec = normalise(row.id, row.kind, row.category, row.label, data)
                if rec then
                    place(set, rec)
                    n = n + 1
                end
            end
        end
    end
    Recipes.live = set
    Recipes.loadedOnce = true
    Srv.debug('loaded %d live recipes', n)
    if Ammo and Ammo.refresh then Ammo.refresh() end
    return true
end

function Recipes.get(kind, category, label)
    if not KINDS[kind] or type(category) ~= 'string' or type(label) ~= 'string' then return nil end
    local cat = Recipes.live[kind][category]
    return cat and cat[label] or nil
end

function Recipes.ammoByItem(item)
    for _, cat in pairs(Recipes.live.ammo) do
        for _, rec in pairs(cat) do
            if rec.item == item then return rec end
        end
    end
    return nil
end

--- may this character craft this recipe (job of the recipe, not grade; experience)
function Recipes.allowed(rec, char, xp)
    if not rec.letcraft then return false end
    if rec.jobonly and not GS.inList(rec.jobs, char.job) then return false end
    return (rec.expreq or 0) <= (xp or 0)
end

---------------------------------------------------------------------------
-- vorp_admin bridge
---------------------------------------------------------------------------
exports('GetWeaponRecipesAdmin', function()
    local ok, rows = pcall(MySQL.query.await,
        'SELECT id, kind, category, label, enabled, data FROM weapon_recipes ORDER BY kind, category, label')
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for _, row in ipairs(rows) do
        local data, raw = Recipes.decode(row.data)
        data = data or {}
        local jobs = {}
        if type(data.jobs) == 'table' then
            for _, j in ipairs(data.jobs) do jobs[#jobs + 1] = tostring(j) end
        end
        local mats = {}
        for _, m in ipairs(Recipes.materialList(data.materials)) do
            mats[#mats + 1] = { name = m.name, label = m.label, amount = m.amount }
        end
        out[#out + 1] = {
            id = row.id,
            kind = row.kind,
            category = row.category,
            label = row.label,
            enabled = tonumber(row.enabled) == 1 or row.enabled == true,
            hashname = data.hashname,
            item = data.item,
            key = data.key,
            qt = data.qt,
            maxammo = data.maxammo,
            guncheck = raw.guncheck or data.guncheck,
            letcraft = data.letcraft ~= false,
            jobonly = data.jobonly == true,
            jobs = table.concat(jobs, ','),
            expreq = tonumber(data.expreq) or 0,
            expadd = tonumber(data.expadd) or 0,
            diff = tonumber(data.diff) or 3000,
            materials = mats,
        }
    end
    return out
end)

-- every category in the table, enabled or not, so an all-disabled category stays pickable
exports('GetWeaponCategories', function()
    local out = { weapon = {}, ammo = {} }
    local ok, rows = pcall(MySQL.query.await,
        'SELECT DISTINCT kind, category FROM weapon_recipes ORDER BY category')
    if ok and type(rows) == 'table' then
        for _, r in ipairs(rows) do
            if out[r.kind] then out[r.kind][#out[r.kind] + 1] = r.category end
        end
        return out
    end
    for kind, cats in pairs(Recipes.live) do
        for cat in pairs(cats) do out[kind][#out[kind] + 1] = cat end
        table.sort(out[kind])
    end
    return out
end)

local function upsert(form)
    if type(form) ~= 'table' then return false end
    local kind = form.kind == 'ammo' and 'ammo' or 'weapon'
    local category = GS.trim(tostring(form.category or ''))
    local label = GS.trim(tostring(form.label or ''))
    if category == '' or label == '' or #category > 64 or #label > 128 then return false end

    -- materials: a list in, a keyed map out (item1..itemN in input order)
    local materials, n = {}, 0
    if type(form.materials) == 'table' then
        for _, m in ipairs(form.materials) do
            if type(m) == 'table' then
                local name = GS.noSpace(tostring(m.name or ''))
                if name ~= '' then
                    n = n + 1
                    local lbl = GS.trim(tostring(m.label or ''))
                    materials['item' .. n] = {
                        name = name,
                        label = lbl ~= '' and lbl or name,
                        amount = math.max(1, GS.int(m.amount) or 1),
                    }
                end
            end
        end
    end
    if n == 0 then return false end

    local id = GS.int(form.id)
    local data, raw, found = {}, {}, false
    if id then
        local row = MySQL.single.await('SELECT kind, data FROM weapon_recipes WHERE id = ?', { id })
        if row then
            found = true
            kind = row.kind == 'ammo' and 'ammo' or 'weapon'
            local stored, storedRaw = Recipes.decode(row.data)
            data, raw = stored or {}, storedRaw
        end
    end

    data.materials = materials
    data.letcraft = form.letcraft ~= false
    data.jobonly = form.jobonly == true
    data.expreq = math.max(0, GS.int(form.expreq) or 0)
    data.expadd = math.max(0, GS.int(form.expadd) or 0)
    data.diff = math.max(0, GS.int(form.diff) or 3000)
    data.jobs = GS.splitJobs(type(form.jobs) == 'table' and form.jobs or tostring(form.jobs or ''))

    if kind == 'weapon' then
        local hash = GS.trim(tostring(form.hashname or ''))
        if hash == '' then hash = type(data.hashname) == 'string' and data.hashname or '' end
        if hash == '' then return false end
        data.hashname = hash
    else
        local item = GS.noSpace(tostring(form.item or ''))
        if item == '' then item = type(data.item) == 'string' and data.item or '' end
        local key = GS.noSpace(tostring(form.key or ''))
        if key == '' then key = type(data.key) == 'string' and data.key or '' end
        if item == '' or key == '' then return false end
        data.item, data.key = item, key
        data.qt = math.max(1, GS.int(form.qt) or GS.int(data.qt) or 1)
        -- the form's belt cap is saved on every edit; without one the stored value (or 200) stays
        local cap = GS.int(form.maxammo)
        if cap and cap > 0 then
            data.maxammo = cap
        elseif not GS.int(data.maxammo) then
            data.maxammo = 200
        end
        local check = formCheckValue(form.guncheck, raw.guncheck)
        if check then raw.guncheck = check end
    end

    local text = Recipes.encode(data, raw)
    if found then
        -- a rename onto another recipe's kind/category/name is refused cleanly
        local clash = MySQL.scalar.await(
            'SELECT id FROM weapon_recipes WHERE kind = ? AND category = ? AND label = ? AND id <> ? LIMIT 1',
            { kind, category, label, id })
        if clash then return false end
        MySQL.update.await('UPDATE weapon_recipes SET category = ?, label = ?, data = ? WHERE id = ?',
            { category, label, text, id })
    else
        MySQL.insert.await([[INSERT INTO weapon_recipes (kind, category, label, enabled, data)
            VALUES (?, ?, ?, 1, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)]], { kind, category, label, text })
    end
    Recipes.load()
    return true
end

exports('UpsertWeaponRecipe', function(form)
    local ok, res = pcall(upsert, form)
    if not ok then
        print(('^1[pup_gunsmith]^7 UpsertWeaponRecipe failed: %s'):format(tostring(res)))
        return false
    end
    return res == true
end)

exports('SetWeaponRecipeEnabled', function(id, enabled)
    id = GS.int(id)
    if not id or id <= 0 then return false end
    local ok, res = pcall(function()
        local exists = MySQL.scalar.await('SELECT id FROM weapon_recipes WHERE id = ?', { id })
        if not exists then return false end
        MySQL.update.await('UPDATE weapon_recipes SET enabled = ? WHERE id = ?', { enabled and 1 or 0, id })
        Recipes.load()
        return true
    end)
    return ok and res == true
end)
