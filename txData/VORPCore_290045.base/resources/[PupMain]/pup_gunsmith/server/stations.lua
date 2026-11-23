-- pup_gunsmith | crafting stations: database-backed, live-edited, pushed to every client

Stations = {
    live = {}, -- name -> { name, coords, jobs } (enabled only)
}

local function decodeJobs(text)
    if type(text) ~= 'string' or text == '' then return {} end
    local ok, v = pcall(json.decode, text)
    if ok and type(v) == 'table' then
        local out = {}
        for _, j in ipairs(v) do
            local s = GS.trim(tostring(j))
            if s ~= '' then out[#out + 1] = s end
        end
        return out
    end
    local out = {}
    for part in text:gmatch('[^,]+') do
        local s = GS.trim(part)
        if s ~= '' then out[#out + 1] = s end
    end
    return out
end

local function clientList()
    local out = {}
    for _, st in pairs(Stations.live) do
        out[#out + 1] = { name = st.name, x = st.coords.x, y = st.coords.y, z = st.coords.z, jobs = st.jobs }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function Stations.broadcast(target)
    TriggerClientEvent('pup_gunsmith:stations', target or -1, clientList())
end

function Stations.seedIfEmpty()
    local ok, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM weapon_craft_locations')
    if not ok or tonumber(n) ~= 0 then return end
    local added = 0
    for _, s in ipairs(Seeds.Stations) do
        local okI = pcall(MySQL.insert.await,
            'INSERT IGNORE INTO weapon_craft_locations (name, x, y, z, job, enabled) VALUES (?, ?, ?, ?, ?, 1)',
            { s.name, s.x, s.y, s.z, json.encode(s.jobs) })
        if okI then added = added + 1 end
    end
    if Config.Debug.general or added > 0 then
        print(('[pup_gunsmith] seeded %d crafting stations'):format(added))
    end
end

function Stations.load()
    local ok, rows = pcall(MySQL.query.await,
        'SELECT name, x, y, z, job FROM weapon_craft_locations WHERE enabled = 1')
    if not ok or type(rows) ~= 'table' then
        print(('^1[pup_gunsmith]^7 could not read the crafting stations: %s'):format(tostring(rows)))
        return false
    end
    local live = {}
    for _, r in ipairs(rows) do
        local x, y, z = tonumber(r.x), tonumber(r.y), tonumber(r.z)
        if x and y and z and type(r.name) == 'string' then
            live[r.name] = { name = r.name, coords = vector3(x, y, z), jobs = decodeJobs(r.job) }
        end
    end
    Stations.live = live
    print(('[pup_gunsmith] %d crafting stations live'):format(GS.count(live)))
    Stations.broadcast(-1)
    return true
end

function Stations.get(name)
    if type(name) ~= 'string' then return nil end
    return Stations.live[name]
end

--- creates or moves a station. jobs: table or comma string; nil keeps the stored list.
--- Returns the saved name, or false and a reason.
function Stations.upsert(name, x, y, z, jobs)
    name = GS.noSpace(tostring(name or ''))
    if name == '' then return false, 'no name' end
    if #name > 64 then return false, 'name too long' end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return false, 'coords were not numbers' end

    local list
    if jobs == nil then
        local okS, stored = pcall(MySQL.scalar.await, 'SELECT job FROM weapon_craft_locations WHERE name = ?', { name })
        list = okS and decodeJobs(stored) or {}
    else
        list = GS.splitJobs(jobs)
    end

    local ok, err = pcall(MySQL.query.await, [[INSERT INTO weapon_craft_locations (name, x, y, z, job, enabled)
        VALUES (?, ?, ?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), job = VALUES(job), enabled = 1]],
        { name, x, y, z, json.encode(list) })
    if not ok then return false, 'database error: ' .. tostring(err) end
    Stations.load()
    return name
end

--- true when a station of that name exists (and was switched)
function Stations.setEnabled(name, enabled)
    name = GS.noSpace(tostring(name or ''))
    if name == '' then return false end
    local ok, exists = pcall(MySQL.scalar.await, 'SELECT name FROM weapon_craft_locations WHERE name = ?', { name })
    if not ok or not exists then return false end
    local okU = pcall(MySQL.update.await, 'UPDATE weapon_craft_locations SET enabled = ? WHERE name = ?',
        { enabled and 1 or 0, name })
    if not okU then return false end
    Stations.load()
    return true
end

function Stations.delete(name)
    name = GS.noSpace(tostring(name or ''))
    if name == '' then return false end
    local ok, n = pcall(MySQL.update.await, 'DELETE FROM weapon_craft_locations WHERE name = ?', { name })
    if not ok then return false end
    Stations.load()
    return (tonumber(n) or 0) > 0
end

---------------------------------------------------------------------------
-- vorp_admin bridge
---------------------------------------------------------------------------
exports('GetWeaponCraftLocations', function()
    local ok, rows = pcall(MySQL.query.await,
        'SELECT name, x, y, z, job, enabled FROM weapon_craft_locations ORDER BY name')
    if not ok or type(rows) ~= 'table' then return {} end
    return rows
end)

exports('UpsertWeaponCraftLocation', function(name, x, y, z, jobs)
    return Stations.upsert(name, x, y, z, jobs)
end)

exports('SetWeaponCraftLocationEnabled', function(name, enabled)
    return Stations.setEnabled(name, enabled == true)
end)

exports('DeleteWeaponCraftLocation', function(name)
    return Stations.delete(name)
end)

---------------------------------------------------------------------------
-- admin commands (vorp_admin's manage_crafting; the console always may)
---------------------------------------------------------------------------
local function allowed(src)
    if src == 0 then return true end
    if GetResourceState('vorp_admin') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.vorp_admin:allowedToExecuteAction(src, 'manage_crafting') end)
    return ok and res == true
end

local function reply(src, msg)
    if src == 0 then print('[pup_gunsmith] ' .. msg) else Srv.tip(src, msg, 6000) end
end

RegisterCommand('weaponcraftloc', function(src, args)
    if not allowed(src) then return end
    if src == 0 then return reply(0, L('cmd_ingame')) end
    local name = GS.noSpace(table.concat({ args[1] or '' }, ''))
    if name == '' then return reply(src, L('cmd_usage')) end
    local c = Srv.coords(src)
    if not c then return reply(src, L('cmd_failed', 'coords were not numbers')) end
    local jobs = args[2] and table.concat(args, ',', 2) or nil
    CreateThread(function()
        local saved, why = Stations.upsert(name, c.x, c.y, c.z, jobs)
        if saved then
            reply(src, L('cmd_saved', saved))
        else
            reply(src, L('cmd_failed', why or '?'))
        end
    end)
end, false)

local function toggleCommand(cmd, enabled)
    RegisterCommand(cmd, function(src, args)
        if not allowed(src) then return end
        local name = GS.noSpace(args[1] or '')
        if name == '' then return reply(src, L('cmd_usage_toggle', cmd)) end
        CreateThread(function()
            if Stations.setEnabled(name, enabled) then
                reply(src, enabled and L('cmd_on', name) or L('cmd_off', name))
            else
                reply(src, L('cmd_unknown', name))
            end
        end)
    end, false)
end
toggleCommand('weaponcraftloc_off', false)
toggleCommand('weaponcraftloc_on', true)

-- a client asks for the list shortly after it loads
RegisterNetEvent('pup_gunsmith:stationsRequest', function()
    local src = source
    if not Srv.validSource(src) then return end
    if not Srv.throttle(src, 'stationsRequest', 5000) then return end
    Stations.broadcast(src)
end)
