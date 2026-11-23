-- Recipes: loading, the one visibility rule, the client view and missing items.
Recipes = {
    list = {},      -- every loaded recipe (enabled or not), sorted by id
    byId = {},
    fromConfig = false,
}

-- READING THE STORED JSON
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        if na then return true end
        if nb then return false end
        return tostring(a) < tostring(b)
    end)
    return keys
end

--- A material, reward or tool list. Tolerates arrays and key-indexed objects.
function Recipes.readLines(v)
    local out = {}
    if type(v) ~= 'table' then return out end
    for _, k in ipairs(sortedKeys(v)) do
        local l = v[k]
        if type(l) == 'table' then
            local name = WB.nospace(l.name or l[1])
            if name ~= '' then
                local count = WB.int(l.count or l[3]) or 1
                if count < 1 then count = 1 end
                local label = l.label or l[2]
                label = (type(label) == 'string' and label ~= '') and label or name
                out[#out + 1] = { name = name, label = label, count = count }
            end
        end
    end
    return out
end

local function idList(v)
    if type(v) ~= 'table' then return nil end
    local out, seen = {}, {}
    for _, x in pairs(v) do
        local n = WB.int(x)
        if n and n > 0 and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    table.sort(out)
    return out
end

local function stringList(v)
    if type(v) ~= 'table' then return nil end
    local out, seen = {}, {}
    for _, x in pairs(v) do
        if type(x) == 'string' or type(x) == 'number' then
            local s = WB.trim(tostring(x))
            if s ~= '' and not seen[s] then
                seen[s] = true
                out[#out + 1] = s
            end
        end
    end
    return out
end

local function lowerList(list)
    if not list then return nil end
    local out = {}
    for i, s in ipairs(list) do out[i] = s:lower() end
    return out
end

--- Turn one stored row into the internal recipe shape.
function Recipes.parse(id, enabled, data)
    if type(data) == 'string' then
        local ok, dec = pcall(json.decode, data)
        data = ok and dec or nil
    end
    if type(data) ~= 'table' then return nil end
    local P = type(data.Param) == 'table' and data.Param or {}
    local r = {
        id = id,
        enabled = enabled,
        title = type(data.Text) == 'string' and data.Text or tostring(data.Text or ''),
        desc = type(data.Desc) == 'string' and data.Desc or '',
        category = tostring(P.catagory or ''),
        materials = Recipes.readLines(P.Item),
        rewards = Recipes.readLines(P.Reward),
        tools = Recipes.readLines(P.Tools),
        jobs = WB.nameList(P.Job),
        gradelock = WB.int(P.gradelock),
        charlock = idList(P.uinuqe),
        steamlock = stringList(P.uinuqesteam),
        discord = stringList(P.discorduniq),
        stations = WB.nameList(P.location),
        props = lowerList(WB.nameList(P.prop)),
        expreq = math.max(0, WB.int(P.expreq) or 0),
        expadd = math.max(0, WB.int(P.expadd) or 0),
        diff = WB.int(P.diff) or Config.DefaultDifficulty,
        time = tonumber(P.time),
        raw = data,
    }
    if r.time and r.time <= 0 then r.time = nil end
    return r
end

-- BUILDING THE STORED JSON
local function linesOut(lines)
    local out = {}
    for i, l in ipairs(lines or {}) do
        out[i] = { name = l.name, label = l.label, count = l.count }
    end
    return out
end

--- Rebuild the data column from the recipe. Param keys we do not know are kept.
function Recipes.encode(r)
    local oldP = (type(r.raw) == 'table' and type(r.raw.Param) == 'table') and r.raw.Param or {}
    local P = {}
    for k, v in pairs(oldP) do P[k] = v end
    P.catagory = r.category
    P.Item = linesOut(r.materials)
    P.Reward = linesOut(r.rewards)
    if r.tools and #r.tools > 0 then P.Tools = linesOut(r.tools) else P.Tools = nil end
    P.Job = (r.jobs and #r.jobs > 0) and r.jobs or 0
    P.gradelock = r.gradelock
    P.uinuqe = r.charlock
    P.uinuqesteam = r.steamlock
    P.discorduniq = r.discord
    if r.stations and #r.stations > 0 then
        P.location = (#r.stations == 1) and r.stations[1] or r.stations
    else
        P.location = 0
    end
    if r.props and #r.props > 0 then
        P.prop = (#r.props == 1) and r.props[1] or r.props
    else
        P.prop = 0
    end
    P.expreq = r.expreq
    P.expadd = r.expadd
    P.diff = r.diff
    P.time = r.time
    return json.encode({ Text = r.title, Desc = r.desc, Param = P })
end

function Recipes.save(r)
    local data = Recipes.encode(r)
    local ok, res = pcall(MySQL.query.await,
        [[INSERT INTO crafting_recipes (id, name, category, enabled, data) VALUES (?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE name = VALUES(name), category = VALUES(category), enabled = VALUES(enabled), data = VALUES(data)]],
        { r.id, WB.cut(r.title, 128), WB.cut(r.category, 64), r.enabled and 1 or 0, data })
    if not ok or not res then
        Warn('recipe %s could not be saved: %s', tostring(r.id), tostring(res))
        return false
    end
    return true
end

-- LOADING
-- every material and tool name any recipe uses: the only names a client may ask counts for
local countable = {}

local function indexItemNames()
    local set = {}
    for _, r in ipairs(Recipes.list) do
        for _, l in ipairs(r.materials) do set[l.name] = true end
        for _, l in ipairs(r.tools) do set[l.name] = true end
    end
    countable = set
end

function Recipes.isCountable(name)
    return countable[name] == true
end

local function useConfigList()
    Recipes.list, Recipes.byId = {}, {}
    for i, entry in ipairs(Config.SeedRecipes or {}) do
        local r = Recipes.parse(i, true, entry)
        if r then
            Recipes.list[#Recipes.list + 1] = r
            Recipes.byId[r.id] = r
        end
    end
    Recipes.fromConfig = true
    indexItemNames()
end

--- Seed an empty table from Config.SeedRecipes (ids by position).
function Recipes.seedIfEmpty()
    if #(Config.SeedRecipes or {}) == 0 then return end
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM crafting_recipes')
    if (tonumber(n) or 0) > 0 then return end
    for i, entry in ipairs(Config.SeedRecipes) do
        local r = Recipes.parse(i, true, entry)
        if r then Recipes.save(r) end
    end
    print(('[pup_workbench] seeded %d recipes from config'):format(#Config.SeedRecipes))
end

function Recipes.load()
    local ok, rows = pcall(MySQL.query.await, 'SELECT id, enabled, data FROM crafting_recipes ORDER BY id')
    if not ok or type(rows) ~= 'table' or #rows == 0 then
        if not ok then Warn('recipe table unreadable, using the config list: %s', tostring(rows)) end
        useConfigList()
        return
    end
    local list, byId = {}, {}
    for _, row in ipairs(rows) do
        local id = WB.int(row.id)
        local r = id and Recipes.parse(id, WB.flag(row.enabled), row.data)
        if r then
            list[#list + 1] = r
            byId[id] = r
        else
            Warn('recipe %s has unreadable data and was skipped', tostring(row.id))
        end
    end
    Recipes.list, Recipes.byId, Recipes.fromConfig = list, byId, false
    indexItemNames()
end

-- THE ONE RULE: 'ok', 'locked' (+ reason) or 'hidden'
local function inCharLock(r, who)
    if r.charlock then
        for _, id in ipairs(r.charlock) do
            if tostring(id) == tostring(who.charid) then return true end
        end
    end
    if r.steamlock then
        for _, s in ipairs(r.steamlock) do
            if s == who.identifier then return true end
        end
    end
    return false
end

local function gradeCheck(r, who)
    if r.gradelock and who.grade < r.gradelock then
        return 'locked', L('needs_grade', r.gradelock)
    end
    return 'ok'
end

function Recipes.access(r, who, xp)
    if not r or not r.enabled then return 'hidden' end
    local cat = WB.categoryByKey(r.category)
    if cat and type(cat.jobs) == 'table' and #cat.jobs > 0 and not WB.listHas(cat.jobs, who.job) then
        return 'hidden'
    end
    local have = tonumber(xp and xp[r.category]) or 0
    if have < r.expreq then
        if Config.Rules.showRecipesAboveXp then return 'locked', L('needs_xp', r.expreq) end
        return 'hidden'
    end

    local hasJob = r.jobs ~= nil and #r.jobs > 0
    local hasCS = r.charlock ~= nil or r.steamlock ~= nil
    local inJob = hasJob and WB.listHas(r.jobs, who.job)

    if hasJob and hasCS then
        if inCharLock(r, who) then return 'ok' end
        if inJob then return gradeCheck(r, who) end
        return 'hidden'
    elseif hasCS then
        return inCharLock(r, who) and 'ok' or 'hidden'
    elseif r.discord and #r.discord > 0 then
        return (who.discord and WB.listHas(r.discord, who.discord)) and 'ok' or 'hidden'
    elseif hasJob then
        if inJob then return gradeCheck(r, who) end
        return 'hidden'
    end
    return 'ok'
end

function Recipes.secondsPerUnit(r)
    return r.time or Config.Timed.defaultSecondsPerUnit
end

--- The recipes this character may see, without any lock lists.
function Recipes.viewFor(who, xp)
    local out = {}
    for _, r in ipairs(Recipes.list) do
        local state, reason = Recipes.access(r, who, xp)
        if state ~= 'hidden' then
            out[#out + 1] = {
                id = r.id, title = r.title, desc = r.desc, category = r.category,
                materials = r.materials, tools = r.tools, rewards = r.rewards,
                expadd = r.expadd, expreq = r.expreq,
                time = Recipes.secondsPerUnit(r),
                stations = r.stations, props = r.props,
                locked = state == 'locked', reason = reason,
            }
        end
    end
    return out
end

--- Distinct experience thresholds per category, across every recipe.
function Recipes.thresholds()
    local sets, out = {}, {}
    for _, r in ipairs(Recipes.list) do
        sets[r.category] = sets[r.category] or {}
        sets[r.category][r.expreq] = true
    end
    for cat, set in pairs(sets) do
        local list = {}
        for v in pairs(set) do list[#list + 1] = v end
        table.sort(list)
        out[cat] = list
    end
    return out
end

-- MISSING ITEMS
local function prettyName(name)
    local s = name:gsub('_', ' ')
    return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end

function Recipes.addMissingItems()
    local wanted, order, seen = {}, {}, {}
    local function want(name, label)
        if not seen[name] then
            seen[name] = true
            order[#order + 1] = name
        end
        if not wanted[name] and label then wanted[name] = label end
    end
    for _, r in ipairs(Recipes.list) do
        for _, group in ipairs({ r.materials, r.tools, r.rewards }) do
            for _, l in ipairs(group) do
                local label = (l.label ~= l.name) and l.label or nil
                if not label and group == r.rewards and #r.rewards == 1 and r.title ~= '' then label = r.title end
                want(l.name, label)
            end
        end
    end
    if #order == 0 then return end

    local ok, rows = pcall(MySQL.query.await, 'SELECT item FROM items WHERE item IN (?)', { order })
    if not ok or type(rows) ~= 'table' then
        Warn('items table could not be checked: %s', tostring(rows))
        return
    end
    local have = {}
    for _, row in ipairs(rows) do have[row.item] = true end

    local added = {}
    for _, name in ipairs(order) do
        if not have[name] and #name <= 50 then
            local label = wanted[name] or prettyName(name)
            local okIns, n = pcall(MySQL.update.await,
                'INSERT IGNORE INTO items (`item`, `label`, `limit`, `can_remove`, `type`, `usable`) VALUES (?, ?, 25, 1, ?, 0)',
                { name, label:sub(1, 50), 'item_standard' })
            if okIns and (tonumber(n) or 0) > 0 then added[#added + 1] = name end
        end
    end
    if #added > 0 then
        print(('[pup_workbench] added %d missing items: %s. Restart vorp_inventory to use them.')
            :format(#added, table.concat(added, ', ')))
    end
end

--- Every player gets told to refetch; each player's list is filtered when it is asked for.
function Recipes.pushToAll()
    TriggerClientEvent('pup_workbench:recipesChanged', -1)
end
