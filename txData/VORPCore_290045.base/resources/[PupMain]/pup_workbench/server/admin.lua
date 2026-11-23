-- Staff: vorp_admin exports (names and shapes are fixed), /craftloc,
-- and the lock-owner register.

local function joinList(list)
    if not list or #list == 0 then return '' end
    local parts = {}
    for i, v in ipairs(list) do parts[i] = tostring(v) end
    return table.concat(parts, ',')
end

local function copyLines(lines)
    local out = {}
    for i, l in ipairs(lines or {}) do out[i] = { name = l.name, label = l.label, count = l.count } end
    return out
end

local function afterRecipeChange()
    Recipes.load()
    Recipes.addMissingItems()
    Recipes.pushToAll()
end

exports('GetRecipesAdmin', function()
    local out = {}
    for _, r in ipairs(Recipes.list) do
        out[#out + 1] = {
            id = r.id,
            enabled = r.enabled == true,
            name = r.title,
            desc = r.desc,
            category = r.category,
            job = joinList(r.jobs),
            location = joinList(r.stations),
            expreq = r.expreq,
            expadd = r.expadd,
            diff = r.diff or Config.DefaultDifficulty,
            gradelock = r.gradelock,
            materials = copyLines(r.materials),
            rewards = copyLines(r.rewards),
            tools = copyLines(r.tools),
            uinuqe = r.charlock,
            steamlock = r.steamlock and #r.steamlock or nil,
            steamlocks = r.steamlock,
        }
    end
    return out
end)

exports('GetCraftCategories', function()
    local out = {}
    for i, c in ipairs(Config.Categories) do out[i] = { key = c.key, label = c.label } end
    return out
end)

-- editor lines: name without whitespace (empty dropped), label defaults to name, count >= 1
local function editorLines(v)
    local out = {}
    if type(v) ~= 'table' then return out end
    for _, l in ipairs(v) do
        if type(l) == 'table' then
            local name = WB.nospace(l.name)
            if name ~= '' then
                local label = type(l.label) == 'string' and WB.trim(l.label) or ''
                if label == '' then label = name end
                local count = WB.int(l.count) or 1
                if count < 1 then count = 1 end
                out[#out + 1] = { name = name, label = label, count = count }
            end
        end
    end
    return out
end

local function wholeAtLeast0(v, default)
    local n = WB.int(v)
    if not n then return default end
    return math.max(0, n)
end

local function splitAny(v)
    if type(v) == 'table' then return v end
    if type(v) == 'string' or type(v) == 'number' then
        local out = {}
        for part in tostring(v):gmatch('[^,]+') do out[#out + 1] = part end
        return out
    end
    return {}
end

local function charLockList(v)
    local out, seen = {}, {}
    for _, x in ipairs(splitAny(v)) do
        local n = WB.int(type(x) == 'string' and WB.nospace(x) or x)
        if n and n > 0 and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    if #out == 0 then return nil end
    return out
end

local function steamLockList(v)
    local out, seen = {}, {}
    for _, x in ipairs(splitAny(v)) do
        if type(x) == 'string' or type(x) == 'number' then
            local s = WB.nospace(x)
            if s ~= '' and not seen[s] then
                seen[s] = true
                out[#out + 1] = s
            end
        end
    end
    if #out == 0 then return nil end
    return out
end

-- one recipe save at a time: two creates must never read the same MAX(id)
local saving = false

local function upsertRecipe(data)
    if type(data) ~= 'table' then return false end
    local title = type(data.name) == 'string' and WB.trim(data.name) or ''
    local category = type(data.category) == 'string' and WB.trim(data.category) or ''
    local materials = editorLines(data.materials)
    local rewards = editorLines(data.rewards)
    if title == '' or category == '' or #materials == 0 or #rewards == 0 then return false end

    local id = WB.int(data.id)
    if id and id < 1 then return false end
    local live = id and Recipes.byId[id] or nil
    local r
    if live then
        -- work on a copy, so a failed save leaves the live recipe untouched
        r = {}
        for k, v in pairs(live) do r[k] = v end
    else
        if not id then
            local maxId = MySQL.scalar.await('SELECT MAX(id) FROM crafting_recipes')
            id = (tonumber(maxId) or 0) + 1
        end
        r = { id = id, enabled = true, raw = nil, props = nil, time = nil,
              charlock = nil, steamlock = nil, discord = nil, stations = nil, tools = {} }
    end

    r.title = title
    r.category = category
    r.desc = type(data.desc) == 'string' and data.desc or ''
    r.materials = materials
    r.rewards = rewards
    if data.tools ~= nil then r.tools = editorLines(data.tools) end
    r.expreq = wholeAtLeast0(data.expreq, 0)
    r.expadd = wholeAtLeast0(data.expadd, 0)
    r.diff = wholeAtLeast0(data.diff, Config.DefaultDifficulty)

    if data.job ~= nil then
        local jobs = WB.nameList(type(data.job) == 'table' and data.job or tostring(data.job))
        r.jobs = jobs
        if not jobs then
            r.gradelock = nil
        else
            local g = WB.int(data.gradelock)
            r.gradelock = (g and g >= 0) and g or nil
        end
    end
    if data.location ~= nil then
        r.stations = WB.nameList(type(data.location) == 'table' and data.location or tostring(data.location))
    end
    if data.uinuqe ~= nil then r.charlock = charLockList(data.uinuqe) end
    if data.uinuqesteam ~= nil then r.steamlock = steamLockList(data.uinuqesteam) end

    if not Recipes.save(r) then return false end
    afterRecipeChange()
    return id
end

exports('UpsertRecipe', function(data)
    local waited = 0
    while saving and waited < 10000 do
        Wait(50)
        waited = waited + 50
    end
    if saving then return false end
    saving = true
    local ok, res = pcall(upsertRecipe, data)
    saving = false
    if not ok then
        print(('^1[pup_workbench]^7 UpsertRecipe failed: %s'):format(tostring(res)))
        return false
    end
    return res
end)

exports('SetRecipeEnabled', function(id, enabled)
    id = WB.int(id)
    if not id then return false end
    local ok = pcall(MySQL.update.await, 'UPDATE crafting_recipes SET enabled = ? WHERE id = ?', { enabled and 1 or 0, id })
    if not ok then return false end
    Recipes.load()
    Recipes.pushToAll()
    return true
end)

exports('GetLocationsAdmin', function()
    local out = {}
    for i, s in ipairs(Stations.all) do
        out[i] = { name = s.name, x = s.x, y = s.y, z = s.z, enabled = s.enabled }
    end
    return out
end)

exports('UpsertLocation', function(data)
    return Stations.upsert(data)
end)

exports('SetLocationEnabled', function(name, enabled)
    return Stations.setEnabled(name, enabled)
end)

-- /craftloc <name>: VORP "admin" group only; everyone else gets no answer
RegisterCommand('craftloc', function(src, args)
    if src == 0 then
        print('[pup_workbench] ' .. L('craftloc_console'))
        return
    end
    local user = Core.getUser(src)
    if not user or user.getGroup ~= 'admin' then return end
    local name = WB.nospace(args[1] or '')
    if name == '' then
        Notify(src, L('craftloc_usage'), 5000)
        return
    end
    local pos = PlayerPos(src)
    if not pos then
        Notify(src, L('station_failed'), 5000)
        return
    end
    local saved = Stations.upsert({ name = name, x = pos.x, y = pos.y, z = pos.z })
    if saved then
        Notify(src, L('station_saved', saved), 5000)
    else
        Notify(src, L('station_failed'), 5000)
    end
end, false)

-- LOCK OWNERS
--- Character locks held by deleted characters on this account move to the new one.
function MoveDeadLocks(who)
    local rows = MySQL.query.await(
        [[SELECT lo.charidentifier FROM crafting_lock_owner lo
          LEFT JOIN characters c ON c.charidentifier = lo.charidentifier
          WHERE lo.identifier = ? AND c.charidentifier IS NULL]], { who.identifier }) or {}
    if #rows == 0 then return end
    local dead = {}
    for _, row in ipairs(rows) do dead[tonumber(row.charidentifier)] = true end

    -- share the recipe-save lock with UpsertRecipe so neither overwrites the other
    local waited = 0
    while saving and waited < 10000 do
        Wait(50)
        waited = waited + 50
    end
    if saving then return end
    saving = true
    local ok, moved = pcall(function()
        local n = 0
        for _, r in ipairs(Recipes.list) do
            if r.charlock then
                local changed, out, seen = false, {}, {}
                for _, id in ipairs(r.charlock) do
                    local m = dead[id] and who.charid or id
                    if m ~= id then changed = true end
                    if m > 0 and not seen[m] then
                        seen[m] = true
                        out[#out + 1] = m
                    end
                end
                if changed then
                    r.charlock = out
                    if Recipes.save(r) then n = n + 1 end
                end
            end
        end
        return n
    end)
    saving = false
    if not ok then error(moved) end
    if moved > 0 then
        Recipes.load()
        Recipes.pushToAll()
        print(('[pup_workbench] moved character locks on %d recipes to character %d (%s)')
            :format(moved, who.charid, who.identifier))
    end
end

--- Write down who holds a lock, so vorp_admin still knows after a character is deleted.
function RegisterLockOwner(who)
    local holds = false
    for _, r in ipairs(Recipes.list) do
        if (r.steamlock and WB.listHas(r.steamlock, who.identifier)) or (r.charlock and WB.listHas(r.charlock, who.charid)) then
            holds = true
            break
        end
    end
    if not holds then return end
    MySQL.query.await(
        [[INSERT INTO crafting_lock_owner (identifier, charidentifier, steamname, charname) VALUES (?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE steamname = VALUES(steamname), charname = VALUES(charname), lastseen = CURRENT_TIMESTAMP]],
        { who.identifier:sub(1, 50), who.charid, who.steamname:sub(1, 50), who.name:sub(1, 100) })
end
