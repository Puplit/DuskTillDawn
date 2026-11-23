-- Owns the placed props; clients only render what they are told.

local VorpCore = exports.vorp_core:GetCore()

local props = {}  -- [id] = row
local count = 0

local function notify(src, msg, dur)
    TriggerClientEvent('vorp:TipRight', src, msg, dur or 5000)
end

local function charOf(src)
    local user = VorpCore.getUser(src)
    return user and user.getUsedCharacter or nil
end

local function may(src, key)
    local ok, allowed = pcall(function()
        return exports.vorp_admin:allowedToExecuteAction(src, key)
    end)
    return ok and allowed == true
end

local function row(r)
    return {
        id = tonumber(r.id),
        model = r.model,
        x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z),
        rx = tonumber(r.rx) or 0.0, ry = tonumber(r.ry) or 0.0, rz = tonumber(r.rz) or 0.0,
        frozen = tonumber(r.frozen) == 1,
        collision = tonumber(r.collision) == 1,
        label = r.label,
        placed_by_name = r.placed_by_name,
        created_at = r.created_at and tostring(r.created_at) or nil,
    }
end

-- who placed a prop is not sent to clients; staff read it through adminList
local function forClients(p)
    return {
        id = p.id, model = p.model, x = p.x, y = p.y, z = p.z, rx = p.rx, ry = p.ry, rz = p.rz,
        frozen = p.frozen, collision = p.collision, label = p.label,
    }
end

local function allForClients()
    local out = {}
    for id, p in pairs(props) do out[id] = forClients(p) end
    return out
end

CreateThread(function()
    MySQL.query([[CREATE TABLE IF NOT EXISTS `world_props` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `model` VARCHAR(100) NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
        `rx` DOUBLE NOT NULL DEFAULT 0, `ry` DOUBLE NOT NULL DEFAULT 0, `rz` DOUBLE NOT NULL DEFAULT 0,
        `frozen` TINYINT NOT NULL DEFAULT 1,
        `collision` TINYINT NOT NULL DEFAULT 1,
        `label` VARCHAR(100) DEFAULT NULL,
        `placed_by` INT DEFAULT NULL,
        `placed_by_name` VARCHAR(100) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `bypos` (`x`, `y`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]], {}, function()
        MySQL.query('SELECT * FROM world_props', {}, function(rows)
            for _, r in ipairs(rows or {}) do
                props[tonumber(r.id)] = row(r)
                count = count + 1
            end
            print(('^2[pup-props]^7 %d placed prop(s) loaded'):format(count))
            TriggerClientEvent('pup-props:all', -1, allForClients())
        end)
    end)
end)

local lastHello = {}
AddEventHandler('playerDropped', function() lastHello[source] = nil end)

RegisterNetEvent('pup-props:hello', function()
    local src = source
    local now = GetGameTimer()
    if lastHello[src] and now - lastHello[src] < 5000 then return end
    lastHello[src] = now
    TriggerClientEvent('pup-props:all', src, allForClients())
end)

RegisterNetEvent('pup-props:place', function(data)
    local src = source
    if not may(src, 'place_world_props') then
        return notify(src, Locale.notAllowedPlace)
    end
    if type(data) ~= 'table' then return end

    local model = tostring(data.model or ''):gsub('%s+', '')
    if model == '' or #model > 100 then return end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return end
    if type(data.label) ~= 'string' then data.label = nil end

    local ch = charOf(src)
    local who = ch and ('%s %s'):format(ch.firstname or '?', ch.lastname or '?') or 'console'

    local frozen = (data.frozen ~= false) and 1 or 0
    local collision = (data.collision ~= false) and 1 or 0

    MySQL.insert([[INSERT INTO world_props
        (model, x, y, z, rx, ry, rz, frozen, collision, label, placed_by, placed_by_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { model, x, y, z, tonumber(data.rx) or 0.0, tonumber(data.ry) or 0.0, tonumber(data.rz) or 0.0,
          frozen, collision, data.label, ch and ch.charIdentifier or nil, who },
        function(id)
            if not id then return notify(src, Locale.saveFailed) end
            props[id] = {
                id = id, model = model, x = x, y = y, z = z,
                rx = tonumber(data.rx) or 0.0, ry = tonumber(data.ry) or 0.0, rz = tonumber(data.rz) or 0.0,
                frozen = frozen == 1, collision = collision == 1, label = data.label,
                placed_by_name = who, created_at = os.date('%Y-%m-%d %H:%M:%S'),
            }
            count = count + 1
            TriggerClientEvent('pup-props:added', -1, forClients(props[id]))
            notify(src, Locale.placed:format(model, id))
            print(('^2[pup-props]^7 %s placed %s at %.2f %.2f %.2f (#%d)')
                :format(who, model, x, y, z, id))
        end)
end)

RegisterNetEvent('pup-props:delete', function(id)
    local src = source
    if not may(src, 'delete_world_prop') then
        return notify(src, Locale.notAllowedRemove)
    end
    id = tonumber(id)
    local p = id and props[id]
    if not p then return end

    props[id] = nil
    count = math.max(0, count - 1)
    MySQL.query('DELETE FROM world_props WHERE id = ?', { id })
    TriggerClientEvent('pup-props:removed', -1, id)

    local ch = charOf(src)
    notify(src, Locale.removed:format(p.model, id))
    print(('^3[pup-props]^7 %s %s removed %s (#%d)'):format(
        ch and ch.firstname or 'console', ch and ch.lastname or '', p.model, id))
end)

-- used by vorp_admin's World Props page
exports('adminList', function()
    local out = {}
    for _, p in pairs(props) do out[#out + 1] = p end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

exports('adminCount', function() return count end)

exports('adminDelete', function(id, bySrc)
    id = tonumber(id)
    if not id or not props[id] then return false end
    props[id] = nil
    count = math.max(0, count - 1)
    MySQL.query('DELETE FROM world_props WHERE id = ?', { id })
    TriggerClientEvent('pup-props:removed', -1, id)
    return true
end)
