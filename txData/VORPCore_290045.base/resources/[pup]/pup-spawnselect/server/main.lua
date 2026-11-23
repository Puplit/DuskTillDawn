-- The teleport is client side, so this gate and the log are the server's whole hold on it.

local Core = exports.vorp_core:GetCore()

-- [src] = charidentifier, kept because vorp_core may have cleared the user by playerDropped
local charOfSrc = {}

local function characterOf(src)
    local user = Core.getUser(src)
    return user and user.getUsedCharacter or nil
end

-- keyholders is a json list of bare charids or tables carrying one
local function holdsKey(raw, charid)
    local ok, list = pcall(json.decode, raw or '[]')
    if not ok or type(list) ~= 'table' then return false end
    for _, k in pairs(list) do
        if tonumber(k) == charid then return true end
        if type(k) == 'table' then
            if tonumber(k.charid) == charid or tonumber(k.charidentifier) == charid then return true end
        end
    end
    return false
end

local function doorOf(raw)
    local ok, door = pcall(json.decode, raw or '[]')
    if not ok or type(door) ~= 'table' then return nil end
    local first = door[1]
    if type(first) ~= 'table' then return nil end
    local x, y, z = tonumber(first.x), tonumber(first.y), tonumber(first.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z, h = tonumber(first.h) or tonumber(first.heading) or 0.0 }
end

---------------------------------------------------------------------------
-- STATE (one row per character)
---------------------------------------------------------------------------

CreateThread(function()
    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS `spawnselect` (
        `charidentifier` INT(11) NOT NULL,
        `last_pick` INT(11) NOT NULL DEFAULT 0,
        `last_drop` INT(11) NOT NULL DEFAULT 0,
        `picks` INT(11) NOT NULL DEFAULT 0,
        `last_label` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`charidentifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end)

local function readRow(charid, cb)
    exports.oxmysql:execute(
        'SELECT last_pick, last_drop, picks FROM spawnselect WHERE charidentifier = ?', { charid },
        function(rows)
            local r = rows and rows[1]
            cb({
                last_pick = tonumber(r and r.last_pick) or 0,
                last_drop = tonumber(r and r.last_drop) or 0,
                picks     = tonumber(r and r.picks) or 0,
            })
        end)
end

---------------------------------------------------------------------------
-- LOG
---------------------------------------------------------------------------

local function ago(seconds)
    seconds = tonumber(seconds) or -1
    if seconds < 0 then return 'never' end
    if seconds < 60 then return seconds .. 's' end
    if seconds < 3600 then return math.floor(seconds / 60) .. 'm' end
    if seconds < 86400 then return ('%.1fh'):format(seconds / 3600) end
    return ('%.1fd'):format(seconds / 86400)
end

local function sendLog(fields)
    local hook = Secrets.Webhooks and Secrets.Webhooks.spawnPicked
    if not hook or hook == '' then return end
    for _, f in ipairs(fields) do f.inline = false end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({
        username = (Config.Logging.webhookName ~= '' and Config.Logging.webhookName) or 'Spawn Select',
        embeds = { {
            title     = 'Spawn Picked',
            color     = 0xb8863b,
            fields    = fields,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }), { ['Content-Type'] = 'application/json' })
end

---------------------------------------------------------------------------
-- THE GATE (allow or refuse, with the house list)
---------------------------------------------------------------------------

-- pup-mdt resumes a sentence a few seconds after spawn, so jailed characters must not be moved first.
-- charidentifier is stored as a string there.
local function isJailed(charid, cb)
    if GetResourceState('pup-mdt') ~= 'started' then return cb(false) end
    exports.oxmysql:execute(
        'SELECT 1 FROM mdt_prison_records WHERE charidentifier = ? AND status = "active" AND jail_time > 0 LIMIT 1',
        { tostring(charid) },
        function(rows) cb(type(rows) == 'table' and #rows > 0) end)
end

local function answer(src, data)
    TriggerClientEvent('pup-spawnselect:answer', src, data)
end

-- one-shot token set by the gate and spent by the pick report, so the log cannot be spammed
local mayReport = {}

local function allowWithHouses(src, charid)
    mayReport[src] = true
    if not Config.Integrations.realestate.enabled or GetResourceState('pup_realestate') ~= 'started' then
        return answer(src, { allow = true, houses = {} })
    end

    exports.oxmysql:execute(
        'SELECT id, primarydoor, keyholders, buyercharidentifier FROM playerhousing WHERE owned = 1', {},
        function(rows)
            local out = {}
            for _, r in ipairs(rows or {}) do
                local mine <const> = tonumber(r.buyercharidentifier) == charid
                if mine or holdsKey(r.keyholders, charid) then
                    local door = doorOf(r.primarydoor)
                    if door then
                        out[#out + 1] = { id = tonumber(r.id), owner = mine, coords = door }
                    end
                end
            end
            answer(src, { allow = true, houses = out })
        end)
end

local lastRequest = {}

RegisterServerEvent('pup-spawnselect:request')
AddEventHandler('pup-spawnselect:request', function(dead)
    local src <const> = source
    local ch = characterOf(src)
    local charid = ch and tonumber(ch.charIdentifier)
    if not charid then return answer(src, { allow = false, reason = 'no character' }) end

    -- each ask reads every house, and a client only asks once per login
    local nowMs <const> = GetGameTimer()
    if lastRequest[src] and nowMs - lastRequest[src] < 2000 then
        return answer(src, { allow = false, reason = 'asked again too soon' })
    end
    lastRequest[src] = nowMs

    -- claimed here so the drop stamp works for a dead or refused login too
    charOfSrc[src] = charid

    -- the character record counts too, not only what the client says
    if dead == true or ch.isdead == true or ch.isdead == 1 then return answer(src, { allow = false, reason = 'dead' }) end

    isJailed(charid, function(jailed)
        if jailed then return answer(src, { allow = false, reason = 'serving a sentence' }) end

        readRow(charid, function(row)
            local t <const> = os.time()
            local grace <const> = tonumber(Config.Guards.dropGraceSeconds) or 0
            local cool <const> = (tonumber(Config.Guards.cooldownMinutes) or 0) * 60

            if grace > 0 and row.last_drop > 0 and (t - row.last_drop) < grace then
                return answer(src, { allow = false, reason = 'dropped ' .. ago(t - row.last_drop) .. ' ago' })
            end

            if cool > 0 and row.last_pick > 0 and (t - row.last_pick) < cool then
                return answer(src, { allow = false, reason = 'picked ' .. ago(t - row.last_pick) .. ' ago' })
            end

            allowWithHouses(src, charid)
        end)
    end)
end)

---------------------------------------------------------------------------
-- THE PICK (stamps the cooldown and writes the log)
---------------------------------------------------------------------------

-- within this of where they logged out counts as carrying on, not travelling
local RESUME_RADIUS <const> = 15.0
-- a reported resume is re-checked after this long; further than TRAVELLED_RADIUS by then counts as a move
local CHECK_AFTER_MS <const> = 5000
local TRAVELLED_RADIUS <const> = 200.0

-- the column holds json, both on load and on save
local function savedCoords(ch)
    local raw = ch.Coords and ch.Coords() or nil
    if type(raw) == 'string' then
        local ok, t = pcall(json.decode, raw)
        raw = ok and t or nil
    end
    if type(raw) ~= 'table' or not tonumber(raw.x) then return nil end
    return { x = tonumber(raw.x), y = tonumber(raw.y) or 0.0, z = tonumber(raw.z) or 0.0 }
end

RegisterServerEvent('pup-spawnselect:picked')
AddEventHandler('pup-spawnselect:picked', function(label, x, y, z)
    local src <const> = source
    if not mayReport[src] then return end
    mayReport[src] = nil

    local ch = characterOf(src)
    local charid = ch and tonumber(ch.charIdentifier)
    if not charid then return end

    label = tostring(label or '?'):sub(1, 64)
    x, y, z = tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0

    -- a resume does not spend the cooldown
    local moved = true
    local saved <const> = savedCoords(ch)
    if saved then
        local dx, dy, dz = x - saved.x, y - saved.y, z - saved.z
        moved = (dx * dx + dy * dy + dz * dz) > (RESUME_RADIUS * RESUME_RADIUS)
    end

    local t <const> = os.time()

    -- saved is read above, before vorp_core's save loop replaces it
    local function record()
        if not moved and saved then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local c = GetEntityCoords(ped)
                if c and not (c.x == 0 and c.y == 0 and c.z == 0) then
                    local dx, dy, dz = c.x - saved.x, c.y - saved.y, c.z - saved.z
                    if dx * dx + dy * dy + dz * dz > TRAVELLED_RADIUS * TRAVELLED_RADIUS then
                        moved = true
                        x, y, z = c.x, c.y, c.z
                    end
                end
            end
        end
    readRow(charid, function(row)
        if moved then
            exports.oxmysql:execute(
                [[INSERT INTO spawnselect (charidentifier, last_pick, picks, last_label)
                  VALUES (?, ?, 1, ?)
                  ON DUPLICATE KEY UPDATE last_pick = VALUES(last_pick), picks = picks + 1,
                                          last_label = VALUES(last_label)]],
                { charid, t, label })
        end

        sendLog({
            { name = 'Character', value = ('%s %s (charid %d)'):format(
                tostring(ch.firstname or '?'), tostring(ch.lastname or '?'), charid) },
            { name = 'Identifier', value = '`' .. tostring(ch.identifier or '?') .. '`' },
            { name = 'Spawn', value = moved and label or (label .. '  (resumed, no cooldown)') },
            { name = 'Coords', value = ('%.1f, %.1f, %.1f'):format(x, y, z) },
            { name = 'Last move', value = row.last_pick > 0 and (ago(t - row.last_pick) .. ' ago') or 'first time' },
            { name = 'Disconnected', value = row.last_drop > 0 and (ago(t - row.last_drop) .. ' ago') or 'no record' },
            { name = 'Moves total', value = tostring(row.picks + (moved and 1 or 0)) },
        })
    end)
    end

    if moved then record() else SetTimeout(CHECK_AFTER_MS, record) end
end)

---------------------------------------------------------------------------
-- DROP (stamp read by the relog grace window)
---------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local src <const> = source
    local charid = charOfSrc[src]
    charOfSrc[src] = nil
    mayReport[src] = nil
    lastRequest[src] = nil
    if not charid then return end
    exports.oxmysql:execute(
        [[INSERT INTO spawnselect (charidentifier, last_drop)
          VALUES (?, ?) ON DUPLICATE KEY UPDATE last_drop = VALUES(last_drop)]],
        { charid, os.time() })
end)
