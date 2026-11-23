-- Modified by Puppet (Dusk Till Dawn), 2026
-- DOOR LOCKS bridge for the web panel. Writes go through doorlocks' own UpdateDoor,
-- which broadcasts to every client, so edits are live with no restart.

local DoorCore
local function core()
    if not DoorCore then
        local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
        if ok then DoorCore = c end
    end
    return DoorCore
end

local PERM <const> = 'manage_doorlocks'

local function allowed(src)
    return HasPermission and HasPermission(src, PERM) == true
end

-- "ValSheriff:0, RhoSheriff:2" <-> { ValSheriff = 0, RhoSheriff = 2 }
local function jobsToText(map)
    local parts = {}
    for name, grade in next, (map or {}) do
        parts[#parts + 1] = ('%s:%d'):format(name, tonumber(grade) or 0)
    end
    table.sort(parts)
    return table.concat(parts, ', ')
end

local function textToJobs(text)
    local out = {}
    for chunk in tostring(text or ''):gmatch('[^,]+') do
        chunk = chunk:gsub('^%s+', ''):gsub('%s+$', '')
        if chunk ~= '' then
            local name, grade = chunk:match('^(.-)%s*:%s*(%-?%d+)$')
            if not name then name, grade = chunk, 0 end
            name = tostring(name):gsub('^%s+', ''):gsub('%s+$', '')
            if name ~= '' then out[name] = math.max(0, math.floor(tonumber(grade) or 0)) end
        end
    end
    return out
end

CreateThread(function()
    local Core
    for _ = 1, 50 do
        Core = core()
        if Core and Core.Callback then break end
        Wait(200)
    end
    if not (Core and Core.Callback) then
        return print('^1[vorp_admin]^7 door locks page: vorp_core never came up')
    end

    Core.Callback.Register('vorp_admin:Callback:doorLocks', function(source, cb, search)
        local _source = source
        if not Core.getUser(_source) then return cb(false) end
        if not allowed(_source) then return cb(false) end
        if GetResourceState('doorlocks') ~= 'started' then return cb({ missing = true }) end

        local ok, list = pcall(function() return exports['doorlocks']:GetDoorList() end)
        if not ok or type(list) ~= 'table' then return cb(false) end

        local needle = tostring(search or ''):lower()
        local rows = {}
        for _, d in ipairs(list) do
            local jobs = jobsToText(d.jobs)
            local hay = (tostring(d.name) .. ' ' .. jobs .. ' ' .. tostring(d.doorid)):lower()
            if needle == '' or hay:find(needle, 1, true) then
                local c = d.coords or {}
                rows[#rows + 1] = {
                    doorid      = d.doorid,
                    name        = d.name,
                    jobs        = jobs,
                    locked      = d.locked,
                    canLockpick = d.canLockpick,
                    double      = d.double,
                    charCount   = d.charCount,
                    x = tonumber(c.x) or 0.0,
                    y = tonumber(c.y) or 0.0,
                    z = tonumber(c.z) or 0.0,
                }
            end
        end

        table.sort(rows, function(a, b)
            if a.name == b.name then return a.doorid < b.doorid end
            return tostring(a.name):lower() < tostring(b.name):lower()
        end)

        cb({ rows = rows, total = #list, canWrite = true })
    end)
end)

RegisterNetEvent('vorp_admin:doorlocks:action', function(data)
    local _source = source
    if not allowed(_source) then
        print(('^1[vorp_admin]^7 %s tried to change a door without %s')
            :format(GetPlayerName(_source) or _source, PERM))
        local Core = core()
        if Core then Core.NotifyRightTip(_source, 'You are not allowed to edit doors.', 5000) end
        return
    end
    if type(data) ~= 'table' then return end
    if GetResourceState('doorlocks') ~= 'started' then return end

    local doorid <const> = tonumber(data.doorid)
    if not doorid then return end
    local act <const> = tostring(data.act or '')
    local Core = core()

    if act == 'jobs' then
        local jobs <const> = textToJobs(data.jobs)
        local ok, res = pcall(function() return exports['doorlocks']:SetDoorJobs(doorid, jobs) end)
        if ok and res then
            local text <const> = jobsToText(jobs)
            if Core then
                Core.NotifyRightTip(_source, ('Door %d jobs: %s'):format(doorid,
                    text ~= '' and text or 'anyone'), 5000)
            end
            TriggerEvent('vorp_admin:logs', _source, Secrets.Webhooks.default,
                'Door Locks', ('Door `%d` job access set to: %s'):format(doorid,
                    text ~= '' and text or 'anyone'))
        elseif Core then
            Core.NotifyRightTip(_source, 'That door no longer exists.', 5000)
        end

    elseif act == 'lock' or act == 'unlock' then
        local want <const> = (act == 'lock')
        local ok, res = pcall(function() return exports['doorlocks']:SetDoorLocked(doorid, want) end)
        if ok and res and Core then
            Core.NotifyRightTip(_source, ('Door %d %s'):format(doorid, want and 'locked' or 'unlocked'), 4000)
        end
    end
end)
