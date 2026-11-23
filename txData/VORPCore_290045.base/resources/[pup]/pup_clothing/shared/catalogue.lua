-- pup_clothing | the garment catalogue, built once from data/cloth_hash_names.lua on both sides.
--
-- Cat.lists[sex][category] = { hashes... } in store order (the data walked last row to first). Index 1 of a
-- store row is "None", so garment k sits at row value k + 1.
-- Cat.owner[u32 hash][sex .. '|' .. category] = true for every multiplayer garment.

local U = PC.U
local Cat = {
    lists = { male = {}, female = {} },
    owner = {},
    names = {},       -- [u32 hash] = asset name ('' when unknown), for debug output
    catByHash = {},   -- [u32 category hash] = category key
    slotOf = {},      -- category key -> clothes JSON key
    catOfSlot = {},   -- clothes JSON key -> category key
    groupOf = {},     -- category key -> group id
    npc = nil,        -- singleplayer garments, see Cat.loadNpc
    ready = false,
}
PC.Cat = Cat

for cat, slot in pairs(Config.SlotNames) do
    Cat.slotOf[cat] = slot
    Cat.catOfSlot[slot] = cat
end

local restGroup = nil
for _, g in ipairs(Config.Groups) do
    for _, c in ipairs(g.cats) do Cat.groupOf[c] = g.id end
    if g.rest then restGroup = g.id end
end
Cat.restGroup = restGroup or Config.Groups[#Config.Groups].id

function Cat.slotName(cat) return Cat.slotOf[cat] or cat end
function Cat.categoryOf(key) return Cat.catOfSlot[key] or key end
-- the data spells a few categories in capitals (MASKS_LARGE); groups and labels are matched lower-case
function Cat.group(cat) return Cat.groupOf[cat] or Cat.groupOf[tostring(cat):lower()] or Cat.restGroup end

function Cat.label(cat)
    return Config.Labels[cat] or Config.Labels[tostring(cat):lower()] or U.prettyKey(cat, Locale.page.special)
end

Cat.hashOfCat = {} -- [category key] = u32 category hash from the data

-- the game's category hash for a category key (signed). The data's own hash wins, because a few
-- category names do not hash back to their category; otherwise the joaat of the name.
function Cat.categoryHash(cat)
    local h = Cat.hashOfCat[cat]
    if h then return U.s32(h) end
    return GetHashKey(cat)
end

-- the hash vorp_character uses for a category: the joaat of its name, as its `HATS` style constants
function Cat.vorpCategoryHash(cat)
    return GetHashKey(cat)
end

-- any multiplayer garment at all?
function Cat.known(hash)
    return Cat.owner[U.u32(hash) or -1] ~= nil
end

-- is this hash a multiplayer garment of this sex in this category (either sex when sex is nil)?
function Cat.fits(hash, sex, cat)
    local o = Cat.owner[U.u32(hash) or -1]
    if not o then return false end
    if sex then return o[sex .. '|' .. cat] == true end
    return o['male|' .. cat] == true or o['female|' .. cat] == true
end

local function build()
    local rows = cloth_hash_names
    if type(rows) ~= 'table' then
        print('^1[pup_clothing]^7 data/cloth_hash_names.lua did not load; the store has no garments')
        return
    end
    for i = #rows, 1, -1 do
        local r = rows[i]
        local cat = r.category_hashname
        local catHash = U.u32(r.category_hash)
        if type(cat) == 'string' and cat ~= '' and catHash then
            Cat.catByHash[catHash] = Cat.catByHash[catHash] or cat
            Cat.hashOfCat[cat] = Cat.hashOfCat[cat] or catHash
        end
        if type(cat) == 'string' and cat ~= '' and not Config.SkipCategories[cat]
            and r.is_multiplayer == true
            and (r.ped_type == 'male' or r.ped_type == 'female')
            and not (Config.Store.hideUnnamed and (r.hashname or '') == '') then
            local h = U.u32(r.hash)
            if h then
                local list = Cat.lists[r.ped_type][cat]
                if not list then
                    list = {}
                    Cat.lists[r.ped_type][cat] = list
                end
                local key = r.ped_type .. '|' .. cat
                local o = Cat.owner[h]
                if not o then
                    o = {}
                    Cat.owner[h] = o
                end
                if not o[key] then
                    o[key] = true
                    list[#list + 1] = h
                end
                Cat.names[h] = Cat.names[h] or r.hashname or ''
            end
        end
    end
    -- the raw rows are not needed again
    cloth_hash_names = nil
    Cat.ready = true
end

---------------------------------------------------------------------------
-- singleplayer garments (optional, read from another resource's data file)
---------------------------------------------------------------------------
local npcWarned = false
local function npcWarn(msg)
    if npcWarned then return end
    npcWarned = true
    print(('^3[pup_clothing]^7 singleplayer garment list unavailable (%s); only colours will be put back'):format(msg))
end

-- Cat.npc.bySex[sex][u32 drawable] = { cat, d, a, n, m, p, t }
-- Cat.npc.lists[sex][cat] = { rows... } (only used when Config.Npc.inStore)
function Cat.loadNpc()
    local cfg = Config.Npc
    if not (cfg.useForExtras or cfg.inStore) then return end
    if GetResourceState(cfg.resource) == 'missing' then return npcWarn(cfg.resource .. ' is not installed') end
    local src = LoadResourceFile(cfg.resource, cfg.file)
    if type(src) ~= 'string' or src == '' then return npcWarn(cfg.resource .. '/' .. cfg.file .. ' not found') end
    -- data only: the chunk runs with nothing but the table helpers
    local env = { pairs = pairs, ipairs = ipairs, table = table, tonumber = tonumber, tostring = tostring, type = type }
    local chunk, err = load(src, '@' .. cfg.resource .. '/' .. cfg.file, 't', env)
    if not chunk then return npcWarn(tostring(err)) end
    local ok, runErr = pcall(chunk)
    if not ok then return npcWarn(tostring(runErr)) end

    local npc = { bySex = { male = {}, female = {} }, lists = { male = {}, female = {} } }
    local function add(sex, cat, r)
        if (sex ~= 'male' and sex ~= 'female') or type(cat) ~= 'string' or type(r) ~= 'table' then return end
        local d = U.u32(r.d)
        if not d or d == 0 then return end
        if npc.bySex[sex][d] then return end
        local row = {
            cat = cat, d = U.s32(r.d), a = U.s32(r.a) or 0, n = U.s32(r.n) or 0, m = U.s32(r.m) or 0,
            p = U.s32(r.p) or 0, t = type(r.t) == 'table' and r.t or { 0, 0, 0 },
        }
        npc.bySex[sex][d] = row
        local l = npc.lists[sex][cat]
        if not l then
            l = {}
            npc.lists[sex][cat] = l
        end
        l[#l + 1] = row
    end
    local main = env.NPC_CLOTHING
    if type(main) == 'table' then
        for sex, cats in pairs(main) do
            if type(cats) == 'table' then
                for cat, list in pairs(cats) do
                    if type(list) == 'table' then
                        for _, r in ipairs(list) do add(sex, cat, r) end
                    end
                end
            end
        end
    end
    for _, extra in ipairs({ env.NPC_CLOTHING_UNIQUE, env.NPC_CLOTHING_EXTRA }) do
        if type(extra) == 'table' then
            for _, r in ipairs(extra) do add(r.sex, r.cat, r) end
        end
    end
    if not next(npc.bySex.male) and not next(npc.bySex.female) then
        return npcWarn('the file holds no rows')
    end
    -- singleplayer-only categories (some with generated names that do not hash back) need their real hash
    -- for removing and tinting; the multiplayer data's own hash still wins where it has one
    if type(env.NPC_CLOTHING_CATEGORY_HASH) == 'table' then
        for cat, h in pairs(env.NPC_CLOTHING_CATEGORY_HASH) do
            local uh = U.u32(h)
            if type(cat) == 'string' and uh and not Cat.hashOfCat[cat] then Cat.hashOfCat[cat] = uh end
        end
    end
    Cat.npc = npc
end

-- the singleplayer row for a drawable, or nil
function Cat.npcRow(sex, drawable)
    if not Cat.npc then return nil end
    local d = U.u32(drawable)
    if not d then return nil end
    if sex then return Cat.npc.bySex[sex][d] end
    return Cat.npc.bySex.male[d] or Cat.npc.bySex.female[d]
end

-- the other resource may start after this one; give it up to 15 s
function Cat.loadNpcWhenReady(onDone)
    local cfg = Config.Npc
    if not (cfg.useForExtras or cfg.inStore) then return end
    CreateThread(function()
        local waited = 0
        while GetResourceState(cfg.resource) ~= 'started' and waited < 15000 do
            if GetResourceState(cfg.resource) == 'missing' then break end
            Wait(500)
            waited = waited + 500
        end
        Cat.loadNpc()
        if onDone then onDone() end
    end)
end

build()
