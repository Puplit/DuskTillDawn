-- pup-medical | the death_losses table and the two exports vorp_admin uses

Losses = {}

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `death_losses` (
                `id`             INT NOT NULL AUTO_INCREMENT,
                `charidentifier` INT NOT NULL,
                `identifier`     VARCHAR(50)  NOT NULL DEFAULT '',
                `charname`       VARCHAR(100) NOT NULL DEFAULT '',
                `steamname`      VARCHAR(50)  NOT NULL DEFAULT '',
                `weapons`        LONGTEXT NULL,
                `items`          LONGTEXT NULL,
                `cash`           DOUBLE NOT NULL DEFAULT 0,
                `gold`           DOUBLE NOT NULL DEFAULT 0,
                `restored`       TINYINT(1) NOT NULL DEFAULT 0,
                `restoredby`     VARCHAR(100) NULL,
                `created`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                KEY `charid_idx` (`charidentifier`),
                KEY `created_idx` (`created`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
    end)
    if not ok then Warn('could not create death_losses: ' .. tostring(err)) end
end)

local function decodeList(text)
    if type(text) ~= 'string' or text == '' then return {} end
    local ok, v = pcall(json.decode, text)
    if ok and type(v) == 'table' then return v end
    return {}
end

local function decodeTable(text)
    if type(text) == 'table' then return text end
    if type(text) ~= 'string' or text == '' then return {} end
    local ok, v = pcall(json.decode, text)
    if ok and type(v) == 'table' then return v end
    return {}
end

function Losses.Record(ctx, weapons, items, cash, gold)
    local steam = GetPlayerName(ctx.src) or ''
    local ok, err = pcall(function()
        MySQL.insert.await(
            'INSERT INTO death_losses (charidentifier, identifier, charname, steamname, weapons, items, cash, gold) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { ctx.charId, tostring(ctx.identifier or ''):sub(1, 50), ctx.name:sub(1, 100), steam:sub(1, 50),
              json.encode(weapons), json.encode(items), cash or 0, gold or 0 })
    end)
    if not ok then Warn('could not record a death loss: ' .. tostring(err)) end
end

exports('GetDeathLosses', function(limit, charid)
    limit = math.floor(tonumber(limit) or 50)
    if limit < 1 then limit = 1 elseif limit > 200 then limit = 200 end
    charid = tonumber(charid)
    local rows
    if charid then
        rows = MySQL.query.await('SELECT * FROM death_losses WHERE charidentifier = ? ORDER BY id DESC LIMIT ?', { charid, limit })
    else
        rows = MySQL.query.await('SELECT * FROM death_losses ORDER BY id DESC LIMIT ?', { limit })
    end
    local out = {}
    for _, r in ipairs(rows or {}) do
        r.weapons = decodeList(r.weapons)
        r.items = decodeList(r.items)
        r.restored = r.restored == true or tonumber(r.restored) == 1
        out[#out + 1] = r
    end
    return out
end)

exports('RestoreDeathLoss', function(id, adminName)
    id = tonumber(id)
    if not id or id <= 0 then return false, 'bad id' end
    local row = MySQL.single.await('SELECT * FROM death_losses WHERE id = ?', { id })
    if not row then return false, 'no such death' end
    if row.restored == true or tonumber(row.restored) == 1 then return false, 'already restored' end

    local charid = tonumber(row.charidentifier)
    local user = charid and Core.getUserByCharId(charid)
    local src = user and tonumber(user.source)
    local ctx = src and GetCtx(src)
    if not ctx or ctx.charId ~= charid then return false, 'that character is not online' end

    local by = tostring(adminName or 'staff'):sub(1, 100)
    local changed = MySQL.update.await('UPDATE death_losses SET restored = 1, restoredby = ? WHERE id = ? AND restored = 0', { by, id })
    if tonumber(changed) ~= 1 then return false, 'already restored' end
    -- the claim was an await: if the player left or switched character in the
    -- meantime, nothing can be handed over, so give the row back
    local still = StillSame(ctx)
    if not still then
        pcall(function()
            MySQL.update.await('UPDATE death_losses SET restored = 0, restoredby = NULL WHERE id = ?', { id })
        end)
        return false, 'that character is not online'
    end

    -- weapons
    local statusUpdates = {}
    for _, w in ipairs(decodeList(row.weapons)) do
        if type(w) == 'string' then
            pcall(function() Inv:createWeapon(src, w, {}, {}, {}) end)
        elseif type(w) == 'table' and type(w.name) == 'string' then
            local serial = (type(w.serial) == 'string' and w.serial ~= '') and w.serial or nil
            local label = (type(w.customLabel) == 'string' and w.customLabel ~= '') and w.customLabel or nil
            local desc = (type(w.customDesc) == 'string' and w.customDesc ~= '') and w.customDesc or nil
            local ok, err = pcall(function()
                Inv:createWeapon(src, w.name, decodeTable(w.ammo), decodeTable(w.components), decodeTable(w.comps),
                    nil, nil, serial, label, desc)
            end)
            if not ok then Warn(('restore %d: weapon %s failed: %s'):format(id, w.name, tostring(err))) end
            local five = {
                tonumber(w.tier) or 0, tonumber(w.degradation) or 0, tonumber(w.dirt) or 0,
                tonumber(w.soot) or 0, tonumber(w.damage) or 0,
            }
            if five[1] > 0 or five[2] > 0 or five[3] > 0 or five[4] > 0 or five[5] > 0 then
                statusUpdates[#statusUpdates + 1] = { name = w.name:upper(), serial = serial, values = five }
            end
        end
    end

    -- items
    for _, it in ipairs(decodeList(row.items)) do
        if type(it) == 'table' and type(it.name) == 'string' then
            local count = math.max(1, math.floor(tonumber(it.count) or 1))
            local meta = type(it.metadata) == 'table' and it.metadata or nil
            local ok, err = pcall(function() Inv:addItem(src, it.name, count, meta) end)
            if not ok then Warn(('restore %d: item %s failed: %s'):format(id, it.name, tostring(err))) end
        end
    end

    -- money
    local now = GetCtx(src)
    if now and now.charId == charid then
        local cash, gold = tonumber(row.cash) or 0, tonumber(row.gold) or 0
        if cash > 0 then now.char.addCurrency(0, cash) end
        if gold > 0 then now.char.addCurrency(1, gold) end
    end

    -- the weapon rows are written by vorp_inventory a moment after createWeapon
    if #statusUpdates > 0 then
        SetTimeout(2000, function()
            for _, u in ipairs(statusUpdates) do
                local v = u.values
                local ok, err = pcall(function()
                    if u.serial then
                        MySQL.update.await(
                            'UPDATE loadout SET tier = ?, degradation = ?, dirt = ?, soot = ?, damage = ? WHERE charidentifier = ? AND name = ? AND serial_number = ? ORDER BY id DESC LIMIT 1',
                            { v[1], v[2], v[3], v[4], v[5], charid, u.name, u.serial })
                    else
                        MySQL.update.await(
                            'UPDATE loadout SET tier = ?, degradation = ?, dirt = ?, soot = ?, damage = ? WHERE charidentifier = ? AND name = ? ORDER BY id DESC LIMIT 1',
                            { v[1], v[2], v[3], v[4], v[5], charid, u.name })
                    end
                end)
                if not ok then Warn(('restore %d: weapon status failed: %s'):format(id, tostring(err))) end
            end
        end)
    end

    TipBottom(src, L('restored'), 6000)
    print(('[pup-medical] death loss %d restored to %s (char %d) by %s'):format(id, ctx.name, charid, by))
    return true, 'restored'
end)
