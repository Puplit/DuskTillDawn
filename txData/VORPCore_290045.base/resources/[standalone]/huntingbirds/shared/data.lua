-- huntingbirds | turns data/*.json into Config tables (model names hashed here)

local RES <const> = GetCurrentResourceName()
local IS_SERVER <const> = IsDuplicityVersion()

local function readJson(path)
    local text = LoadResourceFile(RES, path)
    if not text or text == '' then
        print(('^1[%s]^7 %s is missing'):format(RES, path))
        return nil
    end
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= 'table' then
        print(('^1[%s]^7 %s is not valid JSON'):format(RES, path))
        return nil
    end
    return data
end

local function vec3(t)
    t = type(t) == 'table' and t or {}
    return vector3((tonumber(t[1] or t.x) or 0) + 0.0, (tonumber(t[2] or t.y) or 0) + 0.0, (tonumber(t[3] or t.z) or 0) + 0.0)
end

-------------------------------------------------------------------------------- catalog
Config.BirdCatalog = {}
do
    local data = readJson('data/bird_catalog.json') or {}
    for _, cat in ipairs(data.categories or {}) do
        local out = { name = tostring(cat.name or '?'), variants = {} }
        for _, v in ipairs(cat.variants or {}) do
            out.variants[#out.variants + 1] = {
                name      = tostring(v.name or '?'),
                modelName = tostring(v.model),
                model     = Util.hash(v.model),
                preset    = math.tointeger(tonumber(v.preset) or 0) or 0,
                price     = tonumber(v.price) or 0,
                startXp   = math.tointeger(tonumber(v.startXp) or 0) or 0,
                type      = tostring(v.type or ''),
            }
        end
        if #out.variants > 0 then Config.BirdCatalog[#Config.BirdCatalog + 1] = out end
    end
end

-------------------------------------------------------------------------------- roles
Config.BirdRoles = {}
do
    local data = readJson('data/bird_roles.json') or {}
    for _, role in ipairs({ 'hunting', 'scavenging', 'fishing' }) do
        for _, name in ipairs(data[role] or {}) do
            Config.BirdRoles[Util.hash(name)] = role
        end
    end
end

-------------------------------------------------------------------------------- shoulder offsets
Config.ShoulderOffsets = {}
do
    local data = readJson('data/shoulder_offsets.json') or {}
    for name, entry in pairs(data.models or {}) do
        local out = {}
        for _, sex in ipairs({ 'male', 'female' }) do
            local s = entry[sex]
            if type(s) == 'table' then
                out[sex] = { bone = math.tointeger(tonumber(s.bone) or 0) or 0, offset = vec3(s.offset), rotation = vec3(s.rotation) }
            end
        end
        out.male = out.male or out.female
        out.female = out.female or out.male
        if out.male then Config.ShoulderOffsets[Util.hash(name)] = out end
    end
    Config.ShoulderDefault = Config.ShoulderOffsets[Util.hash('a_c_hawk_01')]
end

-------------------------------------------------------------------------------- shops
Config.Shops = {}
do
    local data = readJson('data/shops.json') or {}
    for _, s in ipairs(data.shops or {}) do
        local c, p = s.coords or {}, s.previewPos or s.coords or {}
        local jobs = {}
        for _, j in ipairs(s.jobs or {}) do jobs[#jobs + 1] = tostring(j) end
        Config.Shops[#Config.Shops + 1] = {
            name        = tostring(s.name or 'Bird Shop'),
            jobRequired = s.jobRequired == true,
            jobs        = jobs,
            blip        = { show = type(s.blip) == 'table' and s.blip.show == true, sprite = type(s.blip) == 'table' and tonumber(s.blip.sprite) or 0 },
            taxPercent  = tonumber(s.taxPercent) or 0,
            coords      = vector3((tonumber(c.x) or 0) + 0.0, (tonumber(c.y) or 0) + 0.0, (tonumber(c.z) or 0) + 0.0),
            previewPos  = vector4((tonumber(p.x) or 0) + 0.0, (tonumber(p.y) or 0) + 0.0, (tonumber(p.z) or 0) + 0.0, (tonumber(p.h) or 0) + 0.0),
        }
    end
end

-------------------------------------------------------------------------------- hunt zones
-- byHash merges the three levels; a place wins over an area, an area over a district
Config.HuntZones = { levels = {}, byHash = {} }
do
    local data = readJson('data/hunt_zones.json') or {}
    Config.HuntZones.fallbackHash = Util.u32(data.fallbackHash) or 0
    for _, lvl in ipairs({ { key = 'places', type = 12 }, { key = 'areas', type = 11 }, { key = 'districts', type = 10 } }) do
        local map = {}
        for _, z in ipairs(data[lvl.key] or {}) do
            local h = Util.u32(z.hash)
            if h then
                local entry = {
                    hash = h,
                    label = tostring(z.label or z.zone or '?'),
                    huntable = z.huntable == true,
                    prey = type(z.prey) == 'string' and z.prey or false,
                }
                map[h] = entry
                if not Config.HuntZones.byHash[h] then Config.HuntZones.byHash[h] = entry end
            end
        end
        Config.HuntZones.levels[#Config.HuntZones.levels + 1] = { type = lvl.type, byHash = map }
    end
    Config.HuntZones.fallback = Config.HuntZones.levels[3] and Config.HuntZones.levels[3].byHash[Config.HuntZones.fallbackHash] or nil
end

-------------------------------------------------------------------------------- talking
Config.TalkModels = {}
for _, name in ipairs(Config.Talking.models or {}) do Config.TalkModels[Util.hash(name)] = true end

Config.ParrotSpeech = {}
if not IS_SERVER then
    local data = readJson('data/parrot_speech.json') or {}
    for _, b in ipairs(data.banks or {}) do
        if type(b.bank) == 'string' and type(b.lines) == 'table' and #b.lines > 0 then
            Config.ParrotSpeech[#Config.ParrotSpeech + 1] = { bank = b.bank, lines = b.lines }
        end
    end
end

-------------------------------------------------------------------------------- catches (server only)
if IS_SERVER then
    Config.PreyLists = {}
    local prey = readJson('data/prey_lists.json') or {}
    for name, list in pairs(prey.lists or {}) do
        local out = {}
        for _, e in ipairs(list) do
            out[#out + 1] = {
                model = Util.hash(e.model), modelName = tostring(e.model),
                preset = math.tointeger(tonumber(e.preset) or 0) or 0,
                xp = tonumber(e.xp) or 0, xpRequired = tonumber(e.xpRequired) or 0,
            }
        end
        Config.PreyLists[name] = out
    end

    Config.ScavengeItems = {}
    local scav = readJson('data/scavenge_items.json') or {}
    for _, e in ipairs(scav.items or {}) do
        if type(e.item) == 'string' and e.item ~= '' then
            Config.ScavengeItems[#Config.ScavengeItems + 1] = {
                item = e.item, amount = math.tointeger(tonumber(e.amount) or 1) or 1,
                xp = tonumber(e.xp) or 0, xpRequired = tonumber(e.xpRequired) or 0,
            }
        end
    end

    Config.FishCatches = {}
    local fish = readJson('data/fish_catches.json') or {}
    for _, e in ipairs(fish.fish or {}) do
        Config.FishCatches[#Config.FishCatches + 1] = {
            model = Util.hash(e.model), modelName = tostring(e.model), preset = 0,
            xp = tonumber(e.xp) or 0, xpRequired = tonumber(e.xpRequired) or 0,
        }
    end
end
