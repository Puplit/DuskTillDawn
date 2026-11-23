-- pup_shaman | small rules both sides agree on

Rules = {}

function Rules.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- The curse definition for a key, or nil.
function Rules.Curse(key)
    if type(key) ~= 'string' or key == '' then return nil end
    return Config.Curses[key]
end

--- The form a curse grants, or nil.
function Rules.FormOf(curseKey)
    local def = Rules.Curse(curseKey)
    return def and def.form or nil
end

--- The harmful course a curse runs, or nil.
function Rules.CourseOf(curseKey)
    local def = Rules.Curse(curseKey)
    return def and def.course and Config.Courses[def.course] or nil
end

--- Is the in-game hour inside the form's night window (which may wrap midnight)?
function Rules.InNightWindow(form, hour)
    if not form.nightOnly then return true end
    local w = form.night or { from = 20, to = 5 }
    hour = tonumber(hour)
    if not hour then return false end
    if w.from <= w.to then
        return hour >= w.from and hour < w.to
    end
    return hour >= w.from or hour < w.to
end

--- Clamps a requested coat for a form (nil = the default coat, or 0).
function Rules.Coat(form, coat)
    coat = tonumber(coat)
    -- NaN and infinities from a modified client fall back to the default
    if not coat or coat ~= coat or coat == math.huge or coat == -math.huge then
        coat = form.defaultCoat or 0
    end
    coat = math.floor(coat)
    if coat < 0 then coat = 0 end
    local max = form.maxCoat or 0x7FFFFFFF -- "no upper limit" still has to fit the native's int argument
    if coat > max then coat = max end
    return math.tointeger(coat) or 0
end

--- Ped scale for a form and coat, with the blood moon factor when it applies.
function Rules.Size(form, coat, bloodMoon)
    local size = (coat and form.coatSizes and form.coatSizes[coat]) or form.size or 1.0
    size = Rules.Clamp(size, Config.Shift.minSize, Config.Shift.maxSize)
    if bloodMoon and form.bloodMoon and form.bloodMoon.size then
        size = size * form.bloodMoon.size
    end
    return size
end

--- A form's attack with the defaults filled in, or nil.
function Rules.Attack(form)
    local a = form and form.abilities and form.abilities.attack
    if not a then return nil end
    local d = Config.Shift.attackDefaults
    return {
        dict = a.dict, clip = a.clip, ms = a.ms,
        range = a.range or d.range,
        damage = a.damage or d.damage,
        cooldownSeconds = a.cooldownSeconds or d.cooldownSeconds,
        ragdollMs = a.ragdollMs or d.ragdollMs,
    }
end

--- Curse keys sorted by label.
function Rules.SortedCurseKeys(keys)
    local list = {}
    if keys then
        for _, k in ipairs(keys) do
            if Config.Curses[k] then list[#list + 1] = k end
        end
    else
        for k in pairs(Config.Curses) do list[#list + 1] = k end
    end
    table.sort(list, function(a, b) return Config.Curses[a].label < Config.Curses[b].label end)
    return list
end

--- Horizontal distance between two vectors.
function Rules.Flat(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
