-- pup_mortician | small rule helpers used on both sides

local undertakerSet, digSet = {}, {}
for _, j in ipairs(Config.UndertakerJobs) do undertakerSet[j] = true end
for _, j in ipairs(Config.DigJobs) do digSet[j] = true end

Rules = {}

function Rules.IsUndertaker(job)
    return job ~= nil and undertakerSet[job] == true
end

-- an empty dig list means anyone with a shovel may dig
function Rules.MayDig(job)
    if #Config.DigJobs == 0 then return true end
    return job ~= nil and digSet[job] == true
end

-- the own-table rule: a table's key is the job that works it
function Rules.CanWorkTable(job, key)
    if not Rules.IsUndertaker(job) or not Config.Tables[key] then return false end
    if Config.AnyUndertakerAnyTable then return true end
    return job == key
end

function Rules.IsShovel(name)
    for _, s in ipairs(Config.Shovel.items) do
        if s == name then return true end
    end
    return false
end

-- flat (x, y) distance
function Rules.Flat(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
