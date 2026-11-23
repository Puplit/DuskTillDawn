-- pup_realestate | furniture catalogue and storage upgrade tables, normalised once on each side

Catalog = { byName = {}, byItem = {}, categories = {} }
Upgrades = { byLevel = {}, count = 0 }

local function modelHash(m)
    if type(m) == 'number' then return math.tointeger(m) or math.floor(m) end
    if type(m) == 'string' and m ~= '' then
        local n = tonumber(m)
        if n then return math.floor(n) end
        return GetHashKey(m) -- model names given as text are hashed
    end
    return nil
end

local function addEntry(category, name, e)
    if type(e) ~= 'table' or type(name) ~= 'string' then return end
    local overrides = Config.Furniture.modelOverrides or {}
    local override = overrides[name] or (e.item and overrides[e.item])
    local model = modelHash(override or e.hash or e.model)
    if not model then
        print(('^3[pup_realestate]^7 furniture "%s" has no model and is skipped'):format(name))
        return
    end
    if Catalog.byName[name] then
        print(('^3[pup_realestate]^7 furniture name "%s" is listed twice; the later one is skipped'):format(name))
        return
    end
    local entry = {
        name = name,
        category = category,
        cost = math.max(0, math.floor(tonumber(e.cost) or 0)),
        model = model,
        item = type(e.item) == 'string' and e.item ~= '' and e.item or nil,
    }
    Catalog.byName[name] = entry
    if entry.item then
        if Catalog.byItem[entry.item] then
            print(('^3[pup_realestate]^7 furniture item "%s" is used by two pieces; "%s" keeps it'):format(entry.item, Catalog.byItem[entry.item].name))
        else
            Catalog.byItem[entry.item] = entry
        end
    end
    local cat = Catalog.categories[category]
    if not cat then
        cat = { name = category, entries = {} }
        Catalog.categories[category] = cat
        Catalog.sortedCategories[#Catalog.sortedCategories + 1] = cat
    end
    cat.entries[#cat.entries + 1] = entry
end

-- natural order: "item2" before "item10"
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        a, b = tostring(a), tostring(b)
        local pa, na = a:match('^(.-)(%d+)$')
        local pb, nb = b:match('^(.-)(%d+)$')
        if pa and pb and pa == pb then return tonumber(na) < tonumber(nb) end
        return a < b
    end)
    return keys
end

local function build()
    -- furniture: sections in config order, then the extra pieces from config/main.lua
    Catalog.sortedCategories = {}
    for _, section in ipairs(Config.Furniture.sections or {}) do
        local title = tostring(section.title or '')
        for _, p in ipairs(section.pieces or {}) do
            -- { item, model, price, label }
            addEntry(title, p[4], { item = p[1], hash = p[2], cost = p[3] })
        end
    end
    for _, category in ipairs(sortedKeys(Config.Furniture.extra)) do
        for _, name in ipairs(sortedKeys(Config.Furniture.extra[category])) do
            addEntry(category, name, Config.Furniture.extra[category][name])
        end
    end
    for _, cat in ipairs(Catalog.sortedCategories) do
        table.sort(cat.entries, function(a, b) return a.name < b.name end)
    end

    -- storage tiers: list position = level
    local labels = Config.UpgradeMaterials or {}
    for level, tier in ipairs(Config.StorageTiers or {}) do
        local mats = {}
        for _, m in ipairs(tier) do
            local name, amount = m[1], m[2]
            if type(name) == 'string' then
                mats[#mats + 1] = {
                    name = name,
                    label = tostring(labels[name] or name),
                    amount = math.max(0, math.floor(tonumber(amount) or 0)),
                }
            end
        end
        Upgrades.byLevel[level] = {
            level = level,
            title = tier.name and tostring(tier.name) or T('upgrade_tier', level),
            materials = mats,
            slots = math.max(0, math.floor(tonumber(tier.slots) or 0)),
        }
        Upgrades.count = level
    end
end

build()
