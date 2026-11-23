-- smokes: usable tobacco/pipe items, editable from the admin panel
local VorpCore = {}
local VorpInv

TriggerEvent("getCore", function(core) VorpCore = core end)
VorpInv = exports.vorp_inventory:vorp_inventoryApi()

-- name -> item table, whatever the current truth is
Smokes = {}
local registered = {}

local function q(sql, params)
    local p = promise.new()
    exports.oxmysql:execute(sql, params or {}, function(r) p:resolve(r) end)
    return Citizen.Await(p)
end

local function bool(v) return (v == true or v == 1 or v == '1') end

-- a DB row back into the shape the client event expects
local function rowToItem(r)
    local effects = {}
    if r.effects and r.effects ~= '' then
        local ok, decoded = pcall(json.decode, r.effects)
        if ok and type(decoded) == 'table' then effects = decoded end
    end
    return {
        pipe           = bool(r.pipe),
        subitem        = bool(r.subitem),
        typeof         = r.typeof or 'cigar',
        high           = bool(r.high),
        hightype       = r.hightype or '',
        highduration   = tonumber(r.highduration) or 0,
        boost          = bool(r.boost),
        healthboost    = tonumber(r.healthboost) or 0.0,
        staminaboost   = tonumber(r.staminaboost) or 0.0,
        drunkamount    = tonumber(r.drunkamount) or 0.0,
        drunkscreen    = tonumber(r.drunkscreen) or 0.0,
        drunkwalk      = tonumber(r.drunkwalk) or 0.0,
        turbo          = bool(r.turbo),
        effectinterval = tonumber(r.effectinterval) or 10,
        effects        = effects,
    }
end

local function ensureTable()
    q([[
        CREATE TABLE IF NOT EXISTS smokes (
            name           VARCHAR(64)  NOT NULL,
            pipe           TINYINT(1)   NOT NULL DEFAULT 0,
            subitem        TINYINT(1)   NOT NULL DEFAULT 1,
            typeof         VARCHAR(16)  NOT NULL DEFAULT 'cigar',
            high           TINYINT(1)   NOT NULL DEFAULT 0,
            hightype       VARCHAR(64)  NOT NULL DEFAULT '',
            highduration   INT          NOT NULL DEFAULT 0,
            boost          TINYINT(1)   NOT NULL DEFAULT 0,
            healthboost    FLOAT        NOT NULL DEFAULT 0,
            staminaboost   FLOAT        NOT NULL DEFAULT 0,
            drunkamount    FLOAT        NOT NULL DEFAULT 0,
            drunkscreen    FLOAT        NOT NULL DEFAULT 0,
            drunkwalk      FLOAT        NOT NULL DEFAULT 0,
            turbo          TINYINT(1)   NOT NULL DEFAULT 0,
            effectinterval INT          NOT NULL DEFAULT 10,
            effects        LONGTEXT     NULL,
            PRIMARY KEY (name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

local function saveRow(name, it)
    q([[
        INSERT INTO smokes
            (name, pipe, subitem, typeof, high, hightype, highduration, boost,
             healthboost, staminaboost, drunkamount, drunkscreen, drunkwalk,
             turbo, effectinterval, effects)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE
            pipe=VALUES(pipe), subitem=VALUES(subitem), typeof=VALUES(typeof),
            high=VALUES(high), hightype=VALUES(hightype), highduration=VALUES(highduration),
            boost=VALUES(boost), healthboost=VALUES(healthboost), staminaboost=VALUES(staminaboost),
            drunkamount=VALUES(drunkamount), drunkscreen=VALUES(drunkscreen), drunkwalk=VALUES(drunkwalk),
            turbo=VALUES(turbo), effectinterval=VALUES(effectinterval), effects=VALUES(effects)
    ]], {
        name, it.pipe and 1 or 0, it.subitem and 1 or 0, it.typeof or 'cigar',
        it.high and 1 or 0, it.hightype or '', math.floor(tonumber(it.highduration) or 0),
        it.boost and 1 or 0, tonumber(it.healthboost) or 0.0, tonumber(it.staminaboost) or 0.0,
        tonumber(it.drunkamount) or 0.0, tonumber(it.drunkscreen) or 0.0, tonumber(it.drunkwalk) or 0.0,
        it.turbo and 1 or 0, math.floor(tonumber(it.effectinterval) or 10),
        json.encode(it.effects or {}),
    })
end

-- the inventory row owns the display name; smokes only stores behaviour
local labelCache = {}
local function labelFor(name)
    if labelCache[name] ~= nil then return labelCache[name] end
    local ok, row = pcall(function() return exports.vorp_inventory:getItemDB(name) end)
    local label = (ok and type(row) == 'table' and row.label) or name
    labelCache[name] = label
    return label
end

local lastSmoke = {}
AddEventHandler('playerDropped', function() lastSmoke[source] = nil end)

-- The item handler is registered once per name and then reads Smokes[name]
local function registerItem(name)
    if registered[name] then return end
    registered[name] = true
    VorpInv.RegisterUsableItem(name, function(data)
        local cfg = Smokes[name]
        if not cfg then return end

        -- one at a time: the client reports through its state bag while a smoke runs. The short gap covers
        -- a double click, which arrives before that report does. Refused here, so the item isn't used up.
        local now = GetGameTimer()
        if lastSmoke[data.source] and now - lastSmoke[data.source] < 3000 then return end
        if Player(data.source).state.pupSmoking then
            TriggerClientEvent("vorp:TipRight", data.source, SmokesLocale.alreadySmoking, 4000)
            return
        end

        if cfg.pipe then
            local hasPipe = VorpInv.getItem(data.source, SmokesConfig.Pipe.item)
            local pipeAmount = hasPipe and (hasPipe.amount or hasPipe.count or 0) or 0
            if pipeAmount < 1 then
                TriggerClientEvent("vorp:TipRight", data.source, SmokesLocale.needpipe, 5000)
                return
            end
        end

        lastSmoke[data.source] = now
        VorpInv.subItem(data.source, name, 1)

        local filters = {}
        for i, v in ipairs(cfg.effects or {}) do filters[i] = v end
        filters.interval = tonumber(cfg.effectinterval) or 10

        -- the health/stamina boost only applies when the boost flag is on
        local hb = cfg.boost and (tonumber(cfg.healthboost) or 0) or 0
        local sb = cfg.boost and (tonumber(cfg.staminaboost) or 0) or 0

        TriggerClientEvent('pup-smoke:inhale', data.source,
            cfg.typeof, cfg.high or false, cfg.hightype or '', cfg.highduration or 0,
            hb, sb, cfg.drunkamount or 0,
            cfg.drunkscreen or 0, cfg.turbo or false, filters, cfg.drunkwalk or 0,
            labelFor(name))
    end)
end

local function loadAll()
    local rows = q('SELECT * FROM smokes')
    if type(rows) ~= 'table' then return false end

    if #rows == 0 then
        local n = 0
        for name, it in pairs(SmokesConfig.Seed or {}) do
            saveRow(name, it)
            n = n + 1
        end
        if n > 0 then
            print(('^2[pup-misc/smokes]^7 seeded smokes with %d items from config'):format(n))
            rows = q('SELECT * FROM smokes') or {}
        else
            print('^3[pup-misc/smokes]^7 smokes is empty - run sql/smokes/install.sql to restore the stock list')
        end
    end

    Smokes = {}
    for _, r in ipairs(rows) do Smokes[r.name] = rowToItem(r) end
    for name in pairs(Smokes) do registerItem(name) end
    return true
end

CreateThread(function()
    Wait(1000) -- let oxmysql and vorp_inventory come up
    local ok = pcall(function()
        ensureTable()
        if not loadAll() then error('no rows returned') end
    end)
    if not ok then
        -- the database is down: use SmokesConfig.Seed (normally empty)
        Smokes = {}
        local n = 0
        for name, it in pairs(SmokesConfig.Seed or {}) do
            Smokes[name] = it
            registerItem(name)
            n = n + 1
        end
        print(('^1[pup-misc/smokes]^7 DATABASE UNAVAILABLE - %d smoke(s) from config, smoking is otherwise off')
            :format(n))
        return
    end
    local n = 0
    for _ in pairs(Smokes) do n = n + 1 end
    print(('^2[pup-misc/smokes]^7 %d smokes loaded from smokes'):format(n))
end)

-- ============================================================ admin panel API

exports('smokesList', function()
    local out = {}
    for name, it in pairs(Smokes) do
        local copy = {}
        for k, v in pairs(it) do copy[k] = v end
        copy.Name = name
        out[#out + 1] = copy
    end
    table.sort(out, function(a, b) return a.Name < b.Name end)
    return out
end)

exports('smokesSave', function(data)
    if type(data) ~= 'table' then return false, 'bad payload' end
    local name = tostring(data.Name or ''):lower():gsub('[^a-z0-9_]', '')
    if name == '' then return false, 'name required' end

    local effects = {}
    if type(data.effects) == 'table' then
        for _, v in ipairs(data.effects) do
            v = tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')
            if v ~= '' then effects[#effects + 1] = v end
        end
    end

    local it = {
        pipe = data.pipe and true or false,
        subitem = data.subitem ~= false,
        typeof = tostring(data.typeof or 'cigar'),
        high = data.high and true or false,
        hightype = tostring(data.hightype or ''),
        highduration = math.floor(tonumber(data.highduration) or 0),
        boost = data.boost and true or false,
        healthboost = tonumber(data.healthboost) or 0.0,
        staminaboost = tonumber(data.staminaboost) or 0.0,
        drunkamount = tonumber(data.drunkamount) or 0.0,
        drunkscreen = tonumber(data.drunkscreen) or 0.0,
        drunkwalk = tonumber(data.drunkwalk) or 0.0,
        turbo = data.turbo and true or false,
        effectinterval = math.floor(tonumber(data.effectinterval) or 10),
        effects = effects,
    }

    local ok = pcall(function() saveRow(name, it) end)
    if not ok then return false, 'could not write to the database' end

    Smokes[name] = it
    labelCache[name] = nil -- the panel may have renamed it
    registerItem(name)

    -- a smoke nobody can carry is useless, so the inventory row is created here
    local note
    local okGet, existing = pcall(function() return exports.vorp_inventory:getItemDB(name) end)
    if not (okGet and existing) then
        q([[INSERT IGNORE INTO items (item, label, `limit`, can_remove, type, usable, `desc`, weight)
            VALUES (?, ?, 10, 1, 'item_standard', 1, ?, 0.25)]],
          { name, tostring(data.label or name), 'Smoke: ' .. name })
        note = 'item row created - restart vorp_inventory to carry it'
    end
    if LoadResourceFile('vorp_inventory', 'html/img/items/' .. name .. '.png') == nil then
        note = (note and (note .. ' | ') or '') ..
            'no image: add vorp_inventory/html/img/items/' .. name .. '.png'
    end
    return true, note
end)

exports('smokesDelete', function(name)
    name = tostring(name or '')
    if name == '' or not Smokes[name] then return false, 'no such smoke' end
    local ok = pcall(function() q('DELETE FROM smokes WHERE name = ?', { name }) end)
    if not ok then return false, 'could not write to the database' end
    Smokes[name] = nil
    -- the usable-item handler stays registered but now finds no config and returns; re-adding the same name later reuses it
    return true
end)
