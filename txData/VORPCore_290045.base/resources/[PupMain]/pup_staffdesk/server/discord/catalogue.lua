-- pup_staffdesk | Discord spawn-code search: !items, !ammo, !weapons
-- So staff writing a parcel can find "bread" from "Bread Loaf". Built from the items table and
-- vorp_inventory's weapon list, refreshed every 15 minutes (or with !items reload).
local code = Bridge.code
local PER_PAGE <const> = 15
local CAT = { items = {}, ammo = {}, weapons = {}, at = 0 }

local GROUPS <const> = {
    { 'REVOLVER', 'Revolver' }, { 'PISTOL', 'Pistol' }, { 'REPEATER', 'Repeater' }, { 'SNIPERRIFLE', 'Sniper Rifle' },
    { 'RIFLE', 'Rifle' }, { 'SHOTGUN', 'Shotgun' }, { 'BOW', 'Bow' }, { 'MELEE', 'Melee' }, { 'THROWN', 'Thrown' }, { 'LASSO', 'Lasso' },
}
local function groupOf(hash)
    local h = hash:upper():gsub('^WEAPON_', '')
    for _, g in ipairs(GROUPS) do if h:sub(1, #g[1]) == g[1] then return g[2] end end
    return 'Other'
end

-- vorp_inventory's weapon table, read in a sandbox (it only assigns data)
local function vorpWeapons()
    local text = LoadResourceFile('vorp_inventory', 'config/weapons.lua')
    if not text then return {} end
    local env = { SHARED_DATA = {}, GetHashKey = function(s) return s end, joaat = function(s) return s end,
        math = math, string = string, table = table, pairs = pairs, ipairs = ipairs, tostring = tostring, tonumber = tonumber, type = type }
    local chunk = load(text, '@vorp_inventory/config/weapons.lua', 't', env)
    if not chunk or not pcall(chunk) then return {} end
    return env.SHARED_DATA.WEAPONS or {}
end

local function build()
    local items, ammo, offset = {}, {}, 0
    repeat -- pages of 500: oxmysql warns about very large result sets
        local page = MySQL.query.await('SELECT item, label FROM items ORDER BY label, item LIMIT 500 OFFSET ' .. offset) or {}
        for _, r in ipairs(page) do
            local e = { code = r.item, label = r.label or r.item }
            items[#items + 1] = e
            if tostring(r.item):lower():sub(1, 4) == 'ammo' then ammo[#ammo + 1] = e end
        end
        offset = offset + 500
    until #page < 500

    local seen, weapons = {}, {}
    for hash, w in pairs(vorpWeapons()) do
        seen[tostring(hash):upper()] = true
        weapons[#weapons + 1] = { label = type(w) == 'table' and w.Name or hash, code = hash, group = groupOf(tostring(hash)) }
    end
    for hash, label in pairs(Config.WeaponLabels) do
        if not seen[hash:upper()] then weapons[#weapons + 1] = { label = label, code = hash, group = groupOf(hash) } end
    end
    table.sort(weapons, function(x, y) if x.group ~= y.group then return x.group < y.group end return x.label < y.label end)
    CAT = { items = items, ammo = ammo, weapons = weapons, at = os.time() }
end

CreateThread(function()
    Wait(8000)
    while true do
        local ok, err = pcall(build)
        if not ok then print('^1[pup_staffdesk/catalogue]^7 ' .. tostring(err)) end
        Wait(15 * 60 * 1000)
    end
end)

-- every word must appear; whole and leading matches rank first
local function search(list, q)
    local words = {}
    for w in q:lower():gmatch('%S+') do words[#words + 1] = w end
    local joined = table.concat(words, ' ')
    local hits = {}
    for _, e in ipairs(list) do
        local label, c = tostring(e.label):lower(), tostring(e.code):lower()
        local hay = label .. ' ' .. c
        local all = true
        for _, w in ipairs(words) do if not hay:find(w, 1, true) then all = false break end end
        if all then
            local rank = 4
            if joined == '' then rank = 4
            elseif label == joined or c == joined then rank = 0
            elseif label:sub(1, #joined) == joined then rank = 1
            elseif label:find(joined, 1, true) then rank = 2
            elseif c:find(joined, 1, true) then rank = 3 end
            hits[#hits + 1] = { r = rank, e = e, l = label }
        end
    end
    table.sort(hits, function(x, y) if x.r ~= y.r then return x.r < y.r end return x.l < y.l end)
    local out = {}
    for i, h in ipairs(hits) do out[i] = h.e end
    return out
end

-- "rope 2" -> "rope", page 2
local function queryAndPage(a)
    local parts = { table.unpack(a, 2) }
    local page = 1
    if #parts >= 2 and parts[#parts]:match('^%d%d?%d?$') then page = tonumber(table.remove(parts)) end
    return table.concat(parts, ' '), math.max(1, page)
end

local function show(title, lines, page, who)
    local pages = math.max(1, math.ceil(#lines / PER_PAGE))
    page = math.min(page, pages)
    local slice = {}
    for i = (page - 1) * PER_PAGE + 1, math.min(#lines, page * PER_PAGE) do slice[#slice + 1] = lines[i] end
    Bridge.embed({ title = title, description = #slice > 0 and table.concat(slice, '\n') or '_nothing matched_',
        footer = { text = ('%d found - page %d/%d%s - asked by %s'):format(#lines, page, pages, pages > 1 and ' (add a page number)' or '', who) } })
end

local function ready() if CAT.at == 0 then return false, Locale.dCatalogueLoading end return true end

Bridge.add('items', { group = 'SPAWN CODES', usage = '<search> [page]', help = 'Item name -> spawn code', audit = false }, function(a, who)
    local ok, why = ready()
    if not ok then return false, why end
    if tostring(a[2] or ''):lower() == 'reload' then
        build()
        return true, ('catalogue rebuilt: %d items, %d ammo, %d weapons'):format(#CAT.items, #CAT.ammo, #CAT.weapons)
    end
    local q, page = queryAndPage(a)
    if q == '' then return false, ('%d items. Search with %s'):format(#CAT.items, code(Bridge.prefix() .. 'items <words>')) end
    local lines = {}
    for _, e in ipairs(search(CAT.items, q)) do lines[#lines + 1] = ('**%s** - %s'):format(e.label, code(e.code)) end
    show(('Items: "%s"'):format(q:sub(1, 40)), lines, page, who)
end)

Bridge.add('ammo', { group = 'SPAWN CODES', usage = '[search] [page]', help = 'Ammo boxes -> spawn code', audit = false }, function(a, who)
    local ok, why = ready()
    if not ok then return false, why end
    local q, page = queryAndPage(a)
    local lines = {}
    for _, e in ipairs(search(CAT.ammo, q)) do lines[#lines + 1] = ('**%s** - %s'):format(e.label, code(e.code)) end
    show(q ~= '' and ('Ammo: "%s"'):format(q:sub(1, 40)) or 'Ammo', lines, page, who)
end)

Bridge.add('weapons', { group = 'SPAWN CODES', usage = '[search] [page]', help = 'Weapon name -> weapon hash', audit = false }, function(a, who)
    local ok, why = ready()
    if not ok then return false, why end
    local q, page = queryAndPage(a)
    local lines = {}
    for _, e in ipairs(search(CAT.weapons, q)) do lines[#lines + 1] = ('**%s** - %s - %s'):format(e.label, code(e.code), e.group) end
    show(q ~= '' and ('Weapons: "%s"'):format(q:sub(1, 40)) or 'Weapons', lines, page, who)
end)
