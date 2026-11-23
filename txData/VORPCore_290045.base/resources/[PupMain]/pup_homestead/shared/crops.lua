-- pup_homestead | crop lookups shared by client and server
Farm = Farm or {}

-- fill every crop from the defaults, once, so the rest of the code reads plain fields
for name, c in pairs(Config.Crops) do
    for k, v in pairs(Config.CropDefaults) do
        if c[k] == nil then c[k] = v end
    end
    c.name = name
end

function Farm.crop(name) return Config.Crops[name] end

function Farm.jobAllowed(crop, job)
    if not crop.jobs then return true end
    for _, j in ipairs(crop.jobs) do if j == job then return true end end
    return false
end

function Farm.jobBonus(job, field)
    local b = job and Config.JobBonus.jobs[job]
    return b and tonumber(b[field]) or nil
end

-- 'growing' | 'thirsty' (stopped, needs water) | 'ready'
function Farm.stage(p)
    if (p.left or 0) <= 0 then return 'ready' end
    local c = Config.Crops[p.crop]
    if not p.watered and c and p.left <= c.waterAt then return 'thirsty' end
    return 'growing'
end

function Farm.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
