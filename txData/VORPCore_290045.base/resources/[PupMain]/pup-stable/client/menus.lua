-- pup-stable | the stable menu: every page, what each row previews and what each action does

Menus = { selHorse = nil, female = false, builders = {} }
local B = Menus.builders

local function act(a, label, key, hold, danger) return { act = a, label = label, key = key, hold = hold, danger = danger } end
local SELECT = act('open', 'select', 'Enter')

local function stableCfg() return Config.Stables[Stable.id] end

local function catalogueTitle(cat, i, entry)
    if entry and entry.title and Locale.outfits[entry.title] then return Locale.outfits[entry.title] end
    return L('number', i)
end

local function horseName(id)
    local h = Me.horses[id]
    return h and h.name or ('#' .. tostring(id))
end

local function priceOf(cat, index)
    local over = Config.Prices.componentOverrides[cat]
    return (over and over[index]) or Config.Prices.components[cat] or 0
end

------------------------------------------------------------------------------
-- statistics card
------------------------------------------------------------------------------
local function bar(cur, base, cap)
    local cells = {}
    for i = 1, 10 do
        if i <= cur then cells[i] = (base and i > base) and 'gold' or 'filled'
        elseif i <= (cap or cur) then cells[i] = 'faded'
        else cells[i] = '' end
    end
    return cells
end

function Menus.statsCard(h, extra)
    local ceil = Config.Training.ceilings
    local out = {
        { kind = 'bar', label = 'speed', cells = bar(h.speed or 1, h.baseSpeed, ceil.speed) },
        { kind = 'bar', label = 'acceleration', cells = bar(h.acceleration or 1, h.baseAcceleration, ceil.acceleration) },
        -- shop horses carry the breed's ranks; owned horses show their stored points
        { kind = 'icons', label = 'health', icon = 'heart', count = h.healthRank or U.rankFromPoints(h.health or 0), max = 10 },
        { kind = 'icons', label = 'stamina', icon = 'bolt', count = h.staminaRank or U.rankFromPoints(h.stamina or 0), max = 10 },
        { kind = 'text', label = 'handling', value = Locale.handlingGrades[U.clamp(h.handling or 1, 1, 4)] },
        { kind = 'icons', label = 'bondingLevel', icon = 'horse', count = U.bondLevel(h.bonding or 0), max = 4 },
    }
    local bag = h.bag
    if bag then
        local parts = {}
        if Config.Saddlebag.showSlots then parts[#parts + 1] = L('slots', bag.slots) end
        if Config.Saddlebag.showWeight then parts[#parts + 1] = L('kg', bag.weight) end
        out[#out + 1] = { kind = 'text', label = 'saddlebagSize', value = table.concat(parts, ' / ') }
    end
    if Config.Shoes.enabled and h.distance then
        local state = 1 - ((h.distance - (h.lastNewShoes or 0)) / (Config.Shoes.lifeKm * 1000))
        out[#out + 1] = { kind = 'fraction', label = 'shoesState', cur = math.max(0, math.floor(state * 100)), max = 100 }
    end
    for _, e in ipairs(extra or {}) do out[#out + 1] = e end
    return out
end

------------------------------------------------------------------------------
-- pages
------------------------------------------------------------------------------
B.home = function()
    local s = stableCfg()
    local items = {}
    if s.horseMenu then items[#items + 1] = { id = 'h', title = 'horseManager', icon = 'horse', child = 'horses', desc = L('homeDesc') } end
    if s.wagonMenu then items[#items + 1] = { id = 'w', title = 'wagonManager', icon = 'wagon', child = 'wagons' } end
    if Running('pup-misc') then
        items[#items + 1] = { id = 'o', title = 'outfitter', icon = 'bag', desc = L('outfitterDesc'), actions = { act('outfit', 'select', 'Enter') } }
    end
    for _, it in ipairs(Breeding.homeRows(Stable.id)) do items[#items + 1] = it end
    return { id = 'home', title = 'menu', items = items, actions = { SELECT } }
end

B.horses = function()
    local s = stableCfg()
    local items = {}
    if s.sellHorses then items[#items + 1] = { id = 'buy', title = 'buyHorse', icon = 'plus', child = 'sex' } end
    items[#items + 1] = { id = 'owned', title = 'manageHorses', icon = 'list', child = 'owned', desc = L('manageHorsesDesc') }
    if s.sellComponents then items[#items + 1] = { id = 'comp', title = 'buyComponent', icon = 'saddle', child = 'compCats' } end
    items[#items + 1] = { id = 'mine', title = 'ownedComponents', icon = 'book', child = 'ownedCats', desc = L('ownedComponentsDesc') }
    return { id = 'horses', title = 'horseManager', items = items, actions = { SELECT } }
end

B.sex = function()
    return { id = 'sex', title = 'chooseSex', actions = { SELECT }, items = {
        { id = 'm', title = 'male', icon = 'male', child = 'breeds', k = 'sex', ref = false },
        { id = 'f', title = 'female', icon = 'female', child = 'breeds', k = 'sex', ref = true },
    } }
end

B.breeds = function()
    local items = {}
    if Breeding.hasBoard() then items[#items + 1] = { id = 'special', title = 'special', icon = 'star', child = 'special', desc = L('specialDesc') } end
    local sorted = {}
    for _, b in ipairs(Config.Breeds) do sorted[#sorted + 1] = b end
    table.sort(sorted, function(a, b) return a.label < b.label end)
    for _, b in ipairs(sorted) do
        items[#items + 1] = { id = 'b' .. b.id, title = b.label, raw = true, child = 'coats:' .. b.id, price = b.price, k = 'breed', ref = b.id }
    end
    return { id = 'breeds', title = 'buyHorses', items = items, actions = { SELECT }, rows = 10 }
end

local function coatActions(coat, b)
    local a = { act('buy', 'buy', 'Enter', 1000) }
    if Config.General.useGold and (coat.gold or b.gold) then a[#a + 1] = act('buyGold', 'buyWith', 'G', 1000) end
    if Me.canColor and Config.Colors.onCoat then a[#a + 1] = act('color', 'colorPalette', 'C', 1000) end
    return a
end

B.coats = function(breedId)
    local b = Config.BreedById[breedId]
    local items = {}
    for i, c in ipairs(b.coats) do
        local cached = Stable.statsCache[b.id]
        local card = cached and Menus.statsCard({ speed = cached.speed, acceleration = cached.acceleration, handling = cached.handling,
            health = cached.health, stamina = cached.stamina, healthRank = cached.healthRank, staminaRank = cached.staminaRank,
            bonding = cached.bonding, bag = c.bag or b.bag }) or nil
        items[#items + 1] = { id = 'c' .. i, title = c.label, raw = true, price = c.price or b.price, gold = c.gold or b.gold,
            stats = card, k = 'coat', ref = { breed = b.id, coat = i }, actions = coatActions(c, b) }
    end
    return { id = 'coats:' .. breedId, title = b.label, raw = true, items = items, rotate = true }
end

local function horseRowActions(h)
    local s = stableCfg()
    if h.isDead then
        local a = { act('delete', 'delete', 'X', 3000, true), act('revive', 'revive', 'R', 2000) }
        if Config.Vet.goldPrice then a[#a + 1] = act('reviveGold', 'reviveGold', 'G', 2000) end
        return a
    end
    if Config.Horse.realistic and h.stable ~= s.id then
        return { act('transferHere', 'transferHere', 'Enter', 2000) }
    end
    local a = { act('manage', 'manage', 'Enter'), act('retrieve', 'retrieve', 'R', 1000), act('transfer', 'transfer', 'T', 1000), act('release', 'release', 'X', 3000, true) }
    if not h.favourite and not Config.Horse.realistic then table.insert(a, 2, act('favourite', 'favourite', 'F', 1000)) end
    return a
end

B.owned = function()
    local list = {}
    for _, h in pairs(Me.horses) do list[#list + 1] = h end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    local items = {}
    local s = stableCfg()
    for _, h in ipairs(list) do
        local it = { id = 'h' .. h.id, title = h.name, raw = true, k = 'horse', ref = h.id, actions = horseRowActions(h), stats = Menus.statsCard(h, {
            { kind = 'text', label = 'race', value = h.breedLabel or h.model },
            { kind = 'text', label = 'coat', value = h.coatLabel or '-' },
            { kind = 'text', label = 'sex', value = h.isFemale and L('female') or L('male') },
        }) }
        if h.favourite then it.prefix = 'star' end
        if h.isDead then
            it.title, it.tone, it.icon, it.priceAlt, it.price = h.name .. ' (' .. L('dead') .. ')', 'red', 'grave', 'reviveFor', Config.Vet.price
        elseif Config.Horse.realistic and h.stable ~= s.id then
            local other = Config.Stables[h.stable]
            it.prefix, it.sub = 'lock', L('locked', other and other.name or h.stable)
        elseif h.isOut then
            it.sub = L('outside')
        end
        items[#items + 1] = it
    end
    if #items == 0 then items[1] = { id = 'none', title = 'noHorse', disabled = true } end
    return { id = 'owned', title = 'yourHorses', items = items, rotate = true, rows = Running('pup_stable_horse-age') and 7 or 8 }
end

B.horse = function(id)
    local h = Me.horses[id]
    if not h then return nil end
    local items = {
        { id = 'eq', title = 'manageEquiped', icon = 'saddle', child = 'ownedCats', k = 'horseCtx', ref = id },
    }
    if not Config.NoHairModels[h.model:lower()] then
        items[#items + 1] = { id = 'hair', title = 'changeHair', icon = 'horse', desc = L('manageHair'), child = 'hair:' .. id }
    end
    if Me.canColor and Config.Colors.onCoat then
        items[#items + 1] = { id = 'coat', title = 'changeCoat', icon = 'palette', k = 'coatEdit', ref = id, actions = { act('color', 'changeCoat', 'Enter', 1000) } }
    end
    if Config.Shoes.enabled then
        items[#items + 1] = { id = 'shoes', title = 'changeShoes', icon = 'horseshoe', desc = L('changeShoesDesc'), price = Config.Shoes.price, k = 'shoes', ref = id, actions = { act('shoes', 'buy', 'Enter', 1000) } }
    end
    if Config.Horse.realistic then
        items[#items + 1] = { id = 'st', title = 'transferAway', icon = 'swap', child = 'stables:horse:' .. id }
    end
    items[#items + 1] = { id = 'rn', title = 'renameHorse', icon = 'pencil', desc = L('renameHorseDesc'), k = 'rename', ref = id, actions = { act('rename', 'confirm', 'Enter', 1000) } }
    items[#items + 1] = { id = 'tr', title = L('transferName', h.name), raw = true, icon = 'swap', desc = L('transferDesc'), k = 'transfer', ref = id, actions = { act('transfer', 'confirm', 'Enter', 1000) } }
    items[#items + 1] = { id = 'rl', title = L('releaseName', h.name), raw = true, icon = 'cross', tone = 'red', desc = L('releaseDesc'), k = 'release', ref = id, actions = { act('release', 'confirm', 'Enter', 3000, true) } }
    return { id = 'horse:' .. id, title = h.name, raw = true, items = items, actions = { SELECT }, rotate = true }
end

B.hair = function(id)
    return { id = 'hair:' .. id, title = 'changeHair', actions = { SELECT }, items = {
        { id = 'm', title = 'changeMane', child = 'compList:horse_manes' },
        { id = 't', title = 'changeTail', child = 'compList:horse_tails' },
        { id = 'u', title = 'changeMustache', child = 'compList:horse_mustache' },
    } }
end

B.compCats = function()
    local items = {}
    for _, cat in ipairs(U.TACK) do
        if HorseComponents[cat] and #HorseComponents[cat] > 0 then
            items[#items + 1] = { id = cat, title = Locale.cat[cat] or cat, raw = true, child = 'compList:' .. cat }
        end
    end
    return { id = 'compCats', title = 'categories', items = items, actions = { SELECT } }
end

B.compList = function(cat)
    local items = {}
    local acts = { act('buy', 'buy', 'Enter', 1000) }
    if Config.General.useGold and Config.Prices.componentGold[cat] then acts[#acts + 1] = act('buyGold', 'buyWith', 'G', 1000) end
    if Me.canColor and Config.Colors.onTack then acts[#acts + 1] = act('color', 'colorPalette', 'C', 1000) end
    for i, entry in ipairs(HorseComponents[cat] or {}) do
        local vals = {}
        for v = 1, #entry.variations do vals[v] = tostring(v) end
        items[#items + 1] = { id = 'e' .. i, title = catalogueTitle(cat, i, entry), raw = true, price = priceOf(cat, i), gold = Config.Prices.componentGold[cat],
            k = 'catalogue', ref = { cat = cat, index = i }, actions = acts,
            sliders = #vals > 1 and { { id = 'v', label = 'variation', type = 'list', values = vals, index = 0, rawValues = true } } or nil }
    end
    return { id = 'compList:' .. cat, title = Locale.cat[cat] or cat, raw = true, items = items, rotate = true }
end

B.ownedCats = function()
    local seen, items = {}, {}
    for _, c in ipairs(Me.comps) do seen[c.category] = true end
    for _, cat in ipairs(U.TACK) do
        if seen[cat] then items[#items + 1] = { id = cat, title = Locale.cat[cat] or cat, raw = true, child = 'ownedList:' .. cat } end
    end
    if #items == 0 then items[1] = { id = 'none', title = 'noComponent', disabled = true } end
    if Menus.selHorse and stableCfg().sellComponents then
        items[#items + 1] = { id = 'buy', title = 'buyComponent', icon = 'plus', child = 'compCats' }
    end
    return { id = 'ownedCats', title = 'ownedComponents', items = items, actions = { SELECT } }
end

B.ownedList = function(cat)
    local items = {}
    for _, c in ipairs(Me.comps) do
        if c.category == cat then
            local idx = U.catalogueIndex(cat, c.hash) or 0
            local entry = HorseComponents[cat] and HorseComponents[cat][idx]
            local it = { id = 'c' .. c.id, title = catalogueTitle(cat, idx, entry), raw = true, k = 'owned', ref = c.id, equipped = c.on > 0 }
            local a = {}
            if c.on > 0 then
                it.tone, it.sub = 'gold', L('equipedOn', horseName(c.on))
                a[#a + 1] = act('unequip', 'unequip', 'X', 1000)
            elseif c.on == -1 then
                it.tone, it.sub = 'red', '(' .. L('outside') .. ')'
            elseif Menus.selHorse then
                a[#a + 1] = act('equip', 'equip', 'Enter', 1000)
            end
            it.actions = a
            items[#items + 1] = it
        end
    end
    if #items == 0 then items[1] = { id = 'none', title = 'noComponent', disabled = true } end
    return { id = 'ownedList:' .. cat, title = Locale.cat[cat] or cat, raw = true, items = items, rotate = true }
end

-- colour palette page. mode: 'coatBuy' | 'coatSave' | 'tack'
B.palette = function(mode)
    local pals, names = Config.Colors.palettes, {}
    for i, p in ipairs(pals) do names[i] = L(p.key) end
    local function tint(label, n)
        return { id = label .. n, label = label == 'h' and L('headTint', n) or (label == 'b' and L('bodyTint', n) or L('tintN', n)), raw = true,
            type = 'palette', palette = pals[1].id, max = pals[1].tints, index = 0, zero = true }
    end
    local sl = { { id = 'pal', label = 'palette', type = 'list', values = names, index = 0, rawValues = true } }
    if mode == 'tack' then
        for n = 0, 2 do sl[#sl + 1] = tint('t', n) end
    else
        for n = 0, 2 do sl[#sl + 1] = tint('h', n) end
        for n = 1, 2 do sl[#sl + 1] = tint('b', n) end
    end
    local acts
    if mode == 'coatSave' then acts = { act('save', 'saveColor', 'Enter', 1000) }
    else
        acts = { act('buy', 'buy', 'Enter', 1000) }
        if Config.General.useGold and mode == 'tack' and Menus.palCtx and Config.Prices.componentGold[Menus.palCtx.cat] then acts[#acts + 1] = act('buyGold', 'buyWith', 'G', 1000) end
    end
    return { id = 'palette:' .. mode, title = mode == 'tack' and 'customColor' or 'customCoat', rotate = true,
        items = { { id = 'p', title = 'color', k = 'palette', ref = mode, sliders = sl, actions = acts } } }
end

-- wagons ---------------------------------------------------------------------
B.wagons = function()
    local s = stableCfg()
    local items = {}
    if s.sellWagons then items[#items + 1] = { id = 'buy', title = 'buyWagon', icon = 'plus', child = 'wagonCats' } end
    items[#items + 1] = { id = 'owned', title = 'manageWagons', icon = 'wagon', child = 'ownedWagons', desc = L('manageWagonsDesc') }
    return { id = 'wagons', title = 'wagonManager', items = items, actions = { SELECT } }
end

B.wagonCats = function()
    local items = {}
    for _, c in ipairs(Config.WagonCategories) do items[#items + 1] = { id = 'c' .. c.id, title = c.label, raw = true, child = 'wagonList:' .. c.id } end
    return { id = 'wagonCats', title = 'buyWagons', items = items, actions = { SELECT } }
end

local function wagonStats(def, locker)
    local seats = N.vehSeats(joaat(def.model))
    if not seats or seats <= 0 then seats = def.seatsHint end
    local out = {}
    if seats then out[#out + 1] = { kind = 'icons', label = 'seats', icon = 'door', count = seats, max = seats } end
    if def.horsesHint then out[#out + 1] = { kind = 'icons', label = 'harness', icon = 'horse', count = def.horsesHint, max = def.horsesHint } end
    locker = locker or def.locker or Config.Locker.default
    local parts = {}
    if Config.Locker.showSlots then parts[#parts + 1] = L('slots', locker.slots) end
    if Config.Locker.showWeight then parts[#parts + 1] = L('kg', locker.weight) end
    if #parts > 0 then out[#out + 1] = { kind = 'text', label = 'storage', value = table.concat(parts, ' / ') } end
    return out
end

B.wagonList = function(catId)
    local cat = Config.WagonCategoryById[catId]
    local items = {}
    for i, w in ipairs(cat.wagons) do
        local nfs = w.price >= Config.NotForSale
        items[#items + 1] = { id = 'w' .. i, title = w.label, raw = true, price = not nfs and w.price or nil, priceAlt = nfs and 'notForSale' or nil,
            disabled = nfs, k = 'wagonDef', ref = { cat = catId, index = i }, stats = wagonStats(w),
            actions = not nfs and { act('buy', 'buy', 'Enter', 1000) } or {} }
    end
    return { id = 'wagonList:' .. catId, title = cat.label, raw = true, items = items, rotate = true }
end

B.ownedWagons = function()
    local items = {}
    local s = stableCfg()
    for _, w in pairs(Me.wagons) do
        local it = { id = 'w' .. w.id, title = w.label, raw = true, k = 'wagon', ref = w.id, stats = wagonStats(WagonDefOf(w.model) or { model = w.model }, w.locker),
            actions = { act('manage', 'manage', 'Enter'), act('retrieve', 'retrieve', 'R', 1000), act('transfer', 'transfer', 'T', 1000), act('destroy', 'destroy', 'X', 3000, true) } }
        if Config.Wagon.realistic and w.stable ~= s.id then
            local other = Config.Stables[w.stable]
            it.prefix, it.sub, it.actions = 'lock', L('locked', other and other.name or w.stable), { act('transferHere', 'transferHere', 'Enter', 2000) }
        elseif w.isOut then
            it.sub = L('outside')
        end
        items[#items + 1] = it
    end
    table.sort(items, function(a, b) return a.title:lower() < b.title:lower() end)
    if #items == 0 then items[1] = { id = 'none', title = 'noWagon', disabled = true } end
    return { id = 'ownedWagons', title = 'yourWagons', items = items, rotate = true }
end

local CUSTOM_COLS = {
    { col = 'vehicle_tints', key = 'tints', none = 'noTint' },
    { col = 'vehicle_propsets', key = 'propset', none = 'noPropset' },
    { col = 'vehicle_liveries', key = 'livery', none = 'noLivery' },
    { col = 'vehicle_lantern_propsets', key = 'lantern', none = 'noLantern' },
    { col = 'vehicle_extras', key = 'extra', none = 'noExtra' },
}

-- the options of one customisation column for a model: { { label, value } }, first = "No ..."
function Menus.wagonOptions(model, col)
    model = tostring(model):lower()
    local out = {}
    if col == 'vehicle_tints' then
        local n = WagonsData.vehicle_tints[model] or 0
        out[1] = { 'noTint', -2 }
        for i = 0, n - 1 do out[#out + 1] = { L('tintN', i + 1), i } end
    elseif col == 'vehicle_propsets' then
        out[1] = { 'noPropset', '-1' }
        for i, p in ipairs(WagonsData.vehicle_propsets[model] or {}) do out[#out + 1] = { L('number', i), p } end
    elseif col == 'vehicle_liveries' then
        out[1] = { 'noLivery', 254 }
        for _, g in ipairs(WagonsData.vehicle_liveries[model] or {}) do
            local label = Locale.liveries[tostring(g.label):lower()] or tostring(g.label)
            for n, id in ipairs(g.ids or {}) do out[#out + 1] = { #g.ids > 1 and ('%s %d'):format(label, n) or label, id } end
        end
    elseif col == 'vehicle_lantern_propsets' then
        out[1] = { 'noLantern', '-1' }
        for i, p in ipairs(WagonsData.vehicle_lantern_propsets[model] or {}) do out[#out + 1] = { L('number', i), p } end
    elseif col == 'vehicle_extras' then
        out[1] = { 'noExtra', -1 }
        local v = Stable.previewKind == 'wagon' and Stable.preview
        for e = 0, 15 do
            if v and DoesEntityExist(v) and DoesExtraExist(v, e) then out[#out + 1] = { L('number', e), e } end
        end
    end
    return out
end

B.wagon = function(id)
    local w = Me.wagons[id]
    if not w then return nil end
    local items = {}
    for _, c in ipairs(CUSTOM_COLS) do
        if #Menus.wagonOptions(w.model, c.col) > 1 then
            items[#items + 1] = { id = c.col, title = c.key, icon = 'wheel', child = 'wcust:' .. id .. ':' .. c.col }
        end
    end
    if Config.Wagon.realistic then items[#items + 1] = { id = 'st', title = 'transferAway', icon = 'swap', child = 'stables:wagon:' .. id } end
    items[#items + 1] = { id = 'rn', title = 'renameWagon', icon = 'pencil', desc = L('renameWagonDesc'), k = 'renameW', ref = id, actions = { act('rename', 'confirm', 'Enter', 1000) } }
    items[#items + 1] = { id = 'tr', title = L('transferName', w.label), raw = true, icon = 'swap', desc = L('transferWagonDesc'), k = 'transferW', ref = id, actions = { act('transfer', 'confirm', 'Enter', 1000) } }
    items[#items + 1] = { id = 'ds', title = L('destroyName', w.label), raw = true, icon = 'cross', tone = 'red', desc = L('destroyDesc'), k = 'destroyW', ref = id, actions = { act('destroy', 'confirm', 'Enter', 3000, true) } }
    return { id = 'wagon:' .. id, title = w.label, raw = true, items = items, actions = { SELECT }, rotate = true }
end

B.wcust = function(id, col)
    local w = Me.wagons[id]
    if not w then return nil end
    local items = {}
    for i, o in ipairs(Menus.wagonOptions(w.model, col)) do
        local current = w[({ vehicle_tints = 'tint', vehicle_propsets = 'propset', vehicle_liveries = 'livery', vehicle_lantern_propsets = 'lantern', vehicle_extras = 'extra' })[col]]
        -- the same index the server prices by
        local idx = U.wagonOptionIndex(w.model, col, o[2]) or (i - 1)
        local price = (idx == 0 and not Config.Prices.noneOptionCharged) and 0 or ((Config.Prices.wagonCustomOverrides[col] or {})[idx] or Config.Prices.wagonCustom[col])
        items[#items + 1] = { id = 'o' .. i, title = o[1], raw = i > 1, price = price, equipped = tostring(current) == tostring(o[2]),
            k = 'wopt', ref = { wagon = id, col = col, value = o[2], index = i - 1 }, actions = { act('buy', 'buy', 'Enter', 1000) } }
    end
    return { id = 'wcust:' .. id .. ':' .. col, title = col:gsub('^vehicle_', ''), raw = true, items = items, rotate = true }
end

B.stables = function(kind, id)
    local row = kind == 'horse' and Me.horses[id] or Me.wagons[id]
    if not row then return nil end
    local items = {}
    for sid, s in pairs(Config.Stables) do
        if sid ~= row.stable then
            local a, b = Config.Stables[row.stable], s
            local price = Config.Transfer.flatPrice
            if not price and a then
                local km = #(vector3(a.location.x, a.location.y, a.location.z) - vector3(b.location.x, b.location.y, b.location.z)) / 1000.0
                price = math.floor(km * Config.Transfer.pricePerKm * 100) / 100
            end
            items[#items + 1] = { id = sid, title = L('transferToStable', s.name), raw = true, price = price, k = 'sendAway', ref = { kind = kind, id = id, to = sid },
                actions = { act('sendAway', 'transfer', 'Enter', 1000) } }
        end
    end
    table.sort(items, function(x, y) return x.title < y.title end)
    return { id = ('stables:%s:%d'):format(kind, id), title = 'selectStable', items = items }
end

------------------------------------------------------------------------------
-- building and showing pages by id
------------------------------------------------------------------------------
function WagonDefOf(model)
    local hit = Config.WagonByModel[tostring(model or ''):lower()]
    if not hit then return nil end
    return Config.WagonCategoryById[hit.cat].wagons[hit.index]
end

function Menus.build(id)
    local name, a, b, c = id:match('^([%w]+):?([%w_]*):?([%w_]*):?([%w_]*)$')
    if not name then return nil end
    local f = B[name] or Breeding.builders[name]
    if not f then return nil end
    if name == 'coats' or name == 'horse' or name == 'hair' or name == 'wagonList' or name == 'wagon' then return f(tonumber(a)) end
    if name == 'wcust' then return f(tonumber(a), b) end
    if name == 'stables' then return f(a, tonumber(b)) end
    if name == 'compList' or name == 'ownedList' or name == 'palette' then return f(a) end
    return f(a ~= '' and a or nil, b ~= '' and b or nil, c ~= '' and c or nil)
end

function Menus.show(id, reset)
    local m = Menus.build(id)
    if not m then return end
    Ui.menu(m)
    Ui.go(id, reset)
end

-- rebuild a page in place (after a purchase or a change)
function Menus.refresh(id)
    if not Ui.menus[id] then return end
    local m = Menus.build(id)
    if m then Ui.menu(m) end
end

function Menus.refreshAll()
    for id in pairs(Ui.menus) do Menus.refresh(id) end
end

function Menus.openHome(stableId)
    Menus.selHorse = (FavouriteHorse() or {}).id
    Ui.menus = {}
    local home = B.home()
    Ui.menu(home)
    Ui.header('stable')
    Ui.root('home')
    Ui.show({
        onAction = Menus.onAction, onPreview = Menus.onPreview, onRotate = Stable.rotate,
        onBack = function(menuId) Menus.onBack(menuId) end,
        onClose = function() Stable.onClosed() end,
    })
    Debug('opened', stableId)
end

function Menus.onBack(menuId)
    if menuId == 'home' or menuId == 'horses' or menuId == 'wagons' then Stable.clearPreview() end
end
