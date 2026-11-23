-- search | small helpers both sides load. Only the server makes duty decisions;
-- the client uses the job and Sisika helpers to decide whether to draw a prompt.

local lawSet = {}
for _, j in ipairs(SearchConfig.Law.jobs or {}) do lawSet[j] = true end

function SearchIsLawJob(job)
    return job ~= nil and lawSet[job] == true
end

function SearchJobInList(job, list)
    if job == nil then return false end
    for _, j in ipairs(list or {}) do
        if j == job then return true end
    end
    return false
end

-- point in the Sisika polygon, inside its height band (even-odd ray cast)
function SearchInSisika(x, y, z)
    local zone = SearchConfig.Sisika
    if not zone or not x or not y or not z then return false end
    if z < zone.minZ or z > zone.maxZ then return false end
    local pts = zone.points
    local inside = false
    local j = #pts
    for i = 1, #pts do
        local xi, yi = pts[i].x, pts[i].y
        local xj, yj = pts[j].x, pts[j].y
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function started(res)
    return res ~= nil and GetResourceState(res) == 'started'
end

-- one external duty answer; an error counts as "no" for that source
local function ask(res, ...)
    local args = { ... }
    local ok, on = pcall(function() return exports[res]:IsPlayerOnDuty(table.unpack(args)) end)
    return ok and on == true
end

local function businessFallback(src)
    local res = SearchConfig.Duty.resources.business
    if not started(res) then return SearchConfig.Duty.businessMissingMeansOnDuty == true end
    return ask(res, src)
end

-- is this player on duty for a job category ('Law' or 'Medical'). Server side.
function SearchIsOnDuty(src, category, job)
    if not SearchConfig.Duty.enabled then return true end
    local res = SearchConfig.Duty.resources
    if category == 'Law' then
        if started(res.mdt) and ask(res.mdt, src) then return true end
        return businessFallback(src)
    elseif category == 'Medical' then
        if started(res.medical) and ask(res.medical, src, job) then return true end
        return businessFallback(src)
    end
    return true
end
