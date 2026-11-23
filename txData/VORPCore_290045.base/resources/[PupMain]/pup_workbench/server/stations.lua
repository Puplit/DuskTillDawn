-- Named stations: fixed map points kept in crafting_locations.
Stations = {
    all = {},      -- every row, enabled or not: { name, x, y, z, enabled }
    active = {},   -- the enabled ones; what players can use
}

local function useConfigList()
    local all = {}
    for _, s in ipairs(Config.SeedStations or {}) do
        all[#all + 1] = { name = s.name, x = s.x + 0.0, y = s.y + 0.0, z = s.z + 0.0, enabled = true }
    end
    table.sort(all, function(a, b) return a.name < b.name end)
    Stations.all = all
    Stations.active = all
end

function Stations.seedIfEmpty()
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM crafting_locations')
    if (tonumber(n) or 0) > 0 then return end
    local count = 0
    for _, s in ipairs(Config.SeedStations or {}) do
        MySQL.query.await('INSERT IGNORE INTO crafting_locations (name, x, y, z, enabled) VALUES (?, ?, ?, ?, 1)',
            { s.name, s.x, s.y, s.z })
        count = count + 1
    end
    if count > 0 then print(('[pup_workbench] seeded %d stations from config'):format(count)) end
end

function Stations.load()
    local ok, rows = pcall(MySQL.query.await, 'SELECT name, x, y, z, enabled FROM crafting_locations')
    if not ok or type(rows) ~= 'table' or #rows == 0 then
        if not ok then Warn('station table unreadable, using the config list: %s', tostring(rows)) end
        useConfigList()
        return
    end
    local all, active = {}, {}
    for _, row in ipairs(rows) do
        local s = {
            name = tostring(row.name),
            x = tonumber(row.x) or 0.0, y = tonumber(row.y) or 0.0, z = tonumber(row.z) or 0.0,
            enabled = WB.flag(row.enabled),
        }
        all[#all + 1] = s
        if s.enabled then active[#active + 1] = s end
    end
    table.sort(all, function(a, b) return a.name < b.name end)
    Stations.all, Stations.active = all, active
end

function Stations.byName(name)
    for _, s in ipairs(Stations.active) do
        if s.name == name then return s end
    end
    return nil
end

--- What clients get: names and positions only.
function Stations.clientList()
    local out = {}
    for i, s in ipairs(Stations.active) do
        out[i] = { name = s.name, x = s.x, y = s.y, z = s.z }
    end
    return out
end

function Stations.pushTo(target)
    TriggerClientEvent('pup_workbench:stations', target, Stations.clientList())
end

--- Is pos within `reach` of an enabled station? With `names`, only those count.
function Stations.near(pos, reach, names)
    for _, s in ipairs(Stations.active) do
        if (not names or WB.listHas(names, s.name)) and WB.dist(pos, s) <= reach then
            return s
        end
    end
    return nil
end

--- The closest enabled station within `reach` of pos, or nil.
function Stations.nearest(pos, reach)
    local best, bestD = nil, reach
    for _, s in ipairs(Stations.active) do
        local d = WB.dist(pos, s)
        if d <= bestD then best, bestD = s, d end
    end
    return best
end

-- the shared save rule used by the export and /craftloc
function Stations.upsert(data)
    if type(data) ~= 'table' then return false end
    local name = WB.nospace(data.name)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if name == '' then
        print('[pup_workbench] UpsertLocation: a station needs a name')
        return false
    end
    if #name > 64 then
        print('[pup_workbench] UpsertLocation: a station name is at most 64 characters')
        return false
    end
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then
        print(('[pup_workbench] UpsertLocation: x, y and z must be numbers (station %s)'):format(name))
        return false
    end
    local ok, err = pcall(MySQL.query.await,
        [[INSERT INTO crafting_locations (name, x, y, z, enabled) VALUES (?, ?, ?, ?, 1)
          ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), enabled = 1]],
        { name, x, y, z })
    if not ok then
        print(('[pup_workbench] UpsertLocation: %s'):format(tostring(err)))
        return false
    end
    Stations.load()
    Stations.pushTo(-1)
    return name
end

function Stations.setEnabled(name, enabled)
    name = WB.nospace(name)
    if name == '' then return false end
    local ok, err = pcall(MySQL.update.await, 'UPDATE crafting_locations SET enabled = ? WHERE name = ?',
        { enabled and 1 or 0, name })
    if not ok then
        print(('[pup_workbench] SetLocationEnabled: %s'):format(tostring(err)))
        return false
    end
    Stations.load()
    Stations.pushTo(-1)
    return true
end
