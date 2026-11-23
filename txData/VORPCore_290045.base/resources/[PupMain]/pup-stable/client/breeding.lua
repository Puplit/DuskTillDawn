-- pup-stable | breeding: home rows, the foal board, the pairing wizard and the paddock scenery

Breeding = { state = {}, builders = {}, parents = {}, wiz = nil }
local BR = Config.Breeding
local B = Breeding.builders

local function act(a, label, key, hold, danger) return { act = a, label = label, key = key, hold = hold, danger = danger } end

function Breeding.load(stableId)
    if not BR.enabled or not stableId then return end
    local ok, st = Call('breedState', stableId)
    if ok and type(st) == 'table' then
        st.clock = GetGameTimer()
        Breeding.state[stableId] = st
    end
end

AddEventHandler('pup-stable:zoneEntered', function(id) CreateThread(function() Breeding.load(id) end) end)
RegisterNetEvent('pup-stable:breedRefresh', function(id)
    if id ~= Stable.zone and id ~= Stable.id then return end
    CreateThread(function()
        Breeding.load(id)
        if Ui.open and Stable.id == id then
            Menus.refresh('home')
            Menus.refresh('special')
            Menus.refresh('breeds')
        end
    end)
end)

local function dueIn(secs)
    secs = math.max(0, secs)
    local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
    if h > 0 then return ('%dh %02dm'):format(h, m) end
    return ('%dm'):format(m)
end

function Breeding.homeRows(stableId)
    local st = Breeding.state[stableId]
    local out = {}
    if not st then return out end
    local first = st.carrying and st.carrying[1]
    if first then
        local left = first.readyat - (st.now + math.floor((GetGameTimer() - st.clock) / 1000))
        out[#out + 1] = { id = 'infoal', title = L('inFoalRow', first.sirebreed or '?', first.dambreed or '?', first.due or 0, dueIn(left)), raw = true, icon = 'heart', disabled = true, sub = L('inFoal') }
    end
    if st.allowed then
        out[#out + 1] = { id = 'breed', title = 'breedHorse', icon = 'plus', desc = L('breedHorseDesc'), k = 'brStart', actions = { act('select', 'select', 'Enter') } }
    end
    return out
end

function Breeding.hasBoard()
    local st = Breeding.state[Stable.id]
    return st ~= nil and st.board ~= nil and #st.board > 0
end

------------------------------------------------------------------------------
-- pages
------------------------------------------------------------------------------
local function foalCard(f)
    local extra = { { kind = 'text', label = 'lineage', value = (f.sirebreed ~= '' and f.dambreed ~= '' and f.sirebreed ~= f.dambreed) and (f.sirebreed .. ' x ' .. f.dambreed) or (f.sirebreed ~= '' and f.sirebreed or (f.dambreed or '-')) } }
    if f.stock > 1 then extra[#extra + 1] = { kind = 'text', label = L('remaining', f.stock, f.stock + f.sold), raw = true, value = '' } end
    return Menus.statsCard({ speed = f.speed or 1, acceleration = f.acceleration or 1, handling = f.handling or 1, health = f.health or 0, stamina = f.stamina or 0, bonding = 0, bag = BR.foalBag }, extra)
end

B.special = function()
    local st = Breeding.state[Stable.id] or {}
    local items = {}
    for _, f in ipairs(st.board or {}) do
        local a = { act('buy', 'buy', 'Enter', 1000) }
        if st.allowed then a[#a + 1] = act('retire', 'retire', 'X', 2000, true) end
        items[#items + 1] = { id = 'f' .. f.id, title = f.name, raw = true, price = f.price, k = 'brFoal', ref = f.id, stats = foalCard(f), actions = a }
    end
    if #items == 0 then items[1] = { id = 'none', title = 'boardEmpty', disabled = true } end
    return { id = 'special', title = 'bredFoals', items = items, rotate = true }
end

local function breedPage(id, title, kind)
    local items = {}
    local sorted = {}
    for _, b in ipairs(Config.Breeds) do sorted[#sorted + 1] = b end
    table.sort(sorted, function(a, b) return a.label < b.label end)
    for _, b in ipairs(sorted) do
        items[#items + 1] = { id = 'b' .. b.id, title = b.label, raw = true, k = kind, ref = b.id, actions = { act('select', 'select', 'Enter') } }
    end
    return { id = id, title = title, items = items, rotate = true, rows = 10 }
end

B.brSire = function() return breedPage('brSire', 'sire', 'brSire') end
B.brDam = function() return breedPage('brDam', 'dam', 'brDam') end

B.brLine = function()
    local w = Breeding.wiz
    if not w or not w.sire or not w.dam then return nil end
    local items = {}
    local function add(breedId, label)
        local b = Config.BreedById[breedId]
        for i, c in ipairs(b.coats) do
            items[#items + 1] = { id = ('c%d_%d'):format(breedId, i), title = c.label, raw = true, sub = L(label), k = 'brLineCoat', ref = { breed = breedId, coat = i }, actions = { act('select', 'select', 'Enter') } }
        end
    end
    add(w.sire, 'afterSire')
    if w.dam ~= w.sire then add(w.dam, 'afterDam') end
    return { id = 'brLine', title = 'whichLine', items = items, rotate = true }
end

local function palSlider(id, label, p, raw)
    return { id = id, label = label, raw = raw, type = 'palette', palette = p.id, max = p.tints, index = 0, zero = true }
end

local function heightValues()
    local vals, std = {}, 0
    local h = BR.height
    local n = math.floor((h.max - h.min) / h.step + 0.5)
    for i = 0, n do
        local s = h.min + i * h.step
        local pct = math.floor((s - 1.0) * 100 + (s >= 1 and 0.5 or -0.5))
        if pct == 0 then vals[#vals + 1] = L('heightStd') std = i
        elseif pct > 0 then vals[#vals + 1] = L('taller', pct)
        else vals[#vals + 1] = L('shorter', pct) end
    end
    return vals, std
end

B.brCoat = function()
    local pals = Config.Colors.palettes
    local names = {}
    for i, p in ipairs(pals) do names[i] = L(p.key) end
    local hairIdx = 2
    local hv, std = heightValues()
    local sl = {
        { id = 'cp', label = 'palette', type = 'list', values = names, index = 0, rawValues = true },
        palSlider('h0', L('headTint', 0), pals[1], true), palSlider('h1', L('headTint', 1), pals[1], true), palSlider('h2', L('headTint', 2), pals[1], true),
        palSlider('b1', L('bodyTint', 1), pals[1], true), palSlider('b2', L('bodyTint', 2), pals[1], true),
        { id = 'hp', label = 'hairPalette', type = 'list', values = names, index = hairIdx - 1, rawValues = true },
        palSlider('t0', L('hairTint', 0), pals[hairIdx], true), palSlider('t1', L('hairTint', 1), pals[hairIdx], true), palSlider('t2', L('hairTint', 2), pals[hairIdx], true),
        { id = 'ht', label = 'height', type = 'list', values = hv, index = std, rawValues = true },
    }
    return { id = 'brCoat', title = 'coat', rotate = true, items = {
        { id = 'coat', title = 'priceIt', desc = L('heightDesc') .. '<br>' .. L('priceItDesc'), k = 'brCoatEdit', sliders = sl, actions = { act('price', 'priceIt', 'Enter', 1000) } },
    } }
end

------------------------------------------------------------------------------
-- previews
------------------------------------------------------------------------------
local function readSliders(sl)
    local pals = Config.Colors.palettes
    local cp = pals[(U.int(sl[1], 0) % #pals) + 1]
    local hp = pals[(U.int(sl[7], 1) % #pals) + 1]
    local scale = BR.height.min + U.int(sl[11], 0) * BR.height.step
    return {
        palette = cp.id, tint0 = U.int(sl[2], 0), tint1 = U.int(sl[3], 0), tint2 = U.int(sl[4], 0), bodyTint1 = U.int(sl[5], 0), bodyTint2 = U.int(sl[6], 0),
        hairpalette = hp.id, htint0 = U.int(sl[8], 0), htint1 = U.int(sl[9], 0), htint2 = U.int(sl[10], 0), scale = scale,
    }, cp, hp
end

local lastPals = {}
local function retarget(menuId, it, idx, p, range)
    if lastPals[idx] == p.id then return end
    lastPals[idx] = p.id
    local fields = { sliders = {} }
    for i = 1, #it.sliders do fields.sliders[i] = false end
    for _, i in ipairs(range) do
        local s = it.sliders[i]
        s.palette, s.max, s.index = p.id, p.tints, 0
        fields.sliders[i] = { palette = p.id, max = p.tints, index = 0 }
    end
    Ui.send('item', { menu = menuId, item = it.id, fields = fields })
end

local function parentPreview(breedId)
    local b = Config.BreedById[breedId]
    Stable.showHorse('brp:' .. breedId, b.coats[1].model, 'shop', function(ped, fresh)
        if fresh then
            Wait(300)
            local stats = Look.readStats(ped, 2500)   -- waits for the ranks to fill in
            if DoesEntityExist(ped) then Breeding.parents[breedId] = stats end
        end
    end)
end

function Breeding.onPreview(menuId, it, sl)
    local k = it.k
    if k == 'brSire' or k == 'brDam' then
        parentPreview(it.ref)
    elseif k == 'brLineCoat' then
        local b = Config.BreedById[it.ref.breed]
        Stable.showHorse('brl:' .. it.ref.breed .. ':' .. it.ref.coat, b.coats[it.ref.coat].model, 'shop')
    elseif k == 'brCoatEdit' then
        local v, cp, hp = readSliders(sl)
        retarget(menuId, it, 'coat', cp, { 2, 3, 4, 5, 6 })
        retarget(menuId, it, 'hair', hp, { 8, 9, 10 })
        local ped = Stable.preview
        if ped and DoesEntityExist(ped) then
            Look.paintCoat(ped, 'metaped_' .. v.palette, v.tint0, v.tint1, v.tint2, v.bodyTint1, v.bodyTint2)
            Look.paintHair(ped, 'metaped_' .. v.hairpalette, v.htint0, v.htint1, v.htint2)
            N.scale(ped, v.scale)
        end
    elseif k == 'brFoal' then
        local st = Breeding.state[Stable.id] or {}
        for _, f in ipairs(st.board or {}) do
            if f.id == it.ref then
                Stable.showHorse('foal:' .. f.id, f.model, 'shop', function(ped, fresh)
                    if not fresh then return end
                    if f.palette and f.palette ~= '' then Look.paintCoat(ped, 'metaped_' .. f.palette, f.tint0, f.tint1, f.tint2, f.tint1, f.tint2) end
                    if f.hairpalette and f.hairpalette ~= '' then Look.paintHair(ped, 'metaped_' .. f.hairpalette, f.htint0, f.htint1, f.htint2) end
                    N.scale(ped, f.scale or 1.0)
                end)
            end
        end
    end
end

------------------------------------------------------------------------------
-- actions
------------------------------------------------------------------------------
local function askText(title, max, kind)
    Ui.suspend()
    local v = Ask(title, max, kind)
    Ui.resume()
    return v
end

function Breeding.onAction(menuId, it, a, sl)
    local k = it.k
    if k == 'brStart' then
        local st = Breeding.state[Stable.id]
        if st and st.cooldown and st.cooldown > 0 then return Tip(L('br_cooldown', math.ceil(st.cooldown / 86400))) end
        Breeding.wiz = {}
        lastPals = {}
        return Menus.show('brSire', true)
    elseif k == 'brSire' then
        Breeding.wiz = Breeding.wiz or {}
        Breeding.wiz.sire = it.ref
        return Menus.show('brDam', true)
    elseif k == 'brDam' then
        if not Breeding.wiz or not Breeding.wiz.sire then return Tip(L('pickSire')) end
        Breeding.wiz.dam = it.ref
        return Menus.show('brLine', true)
    elseif k == 'brLineCoat' then
        if not Breeding.wiz then return Tip(L('pickBreed')) end
        Breeding.wiz.breed, Breeding.wiz.coat = it.ref.breed, it.ref.coat
        lastPals = {}
        return Menus.show('brCoat', true)
    elseif k == 'brCoatEdit' and a == 'price' then
        local w = Breeding.wiz
        if not w or not w.breed then return Tip(L('pickBreed')) end
        if not Breeding.parents[w.sire] or not Breeding.parents[w.dam] then return Tip(L('lookParents')) end
        local raw = askText(L('askPrice', BR.minPrice), 9, 'number')
        if raw == nil or raw == '' then return end
        local price = tonumber(raw)
        if not price then return Tip(L('notPrice')) end
        if price < BR.minPrice then return Tip(L('priceFloor', BR.minPrice)) end
        local v = readSliders(sl)
        local req = { breed = w.breed, coat = w.coat, sire = w.sire, dam = w.dam, price = math.floor(price), scale = v.scale,
            palette = v.palette, tint0 = v.tint0, tint1 = v.tint1, tint2 = v.tint2,
            hairpalette = v.hairpalette, htint0 = v.htint0, htint1 = v.htint1, htint2 = v.htint2,
            sireStats = Breeding.parents[w.sire], damStats = Breeding.parents[w.dam] }
        if CallTip('breed', Stable.id, req) then
            Breeding.wiz = nil
            Breeding.load(Stable.id)
            Menus.refresh('home')
            Ui.go('home')
        end
    elseif k == 'brFoal' then
        if a == 'retire' then
            if CallTip('retireFoal', Stable.id, it.ref) then Breeding.load(Stable.id) Menus.refresh('special') end
            return
        end
        if a ~= 'buy' then return end
        local st = Breeding.state[Stable.id] or {}
        local foal
        for _, f in ipairs(st.board or {}) do if f.id == it.ref then foal = f end end
        if not foal then return end
        local name = askText(L('askFoalName'), Config.General.nameMax)
        if name == nil then return end
        local ped = Stable.previewKey == 'foal:' .. foal.id and Stable.preview or nil
        local stats = ped and DoesEntityExist(ped) and Look.readStats(ped) or nil
        local ok, payload = CallTip('buyFoal', Stable.id, foal.id, name, stats, Menus.female)
        if ok then
            SetHorse(payload)
            Ui.cash()
            Breeding.load(Stable.id)
            Menus.refresh('special')
            Menus.refresh('owned')
        end
    end
end

------------------------------------------------------------------------------
-- the paddock: the carrying family, seen by everyone nearby (local peds only)
------------------------------------------------------------------------------
local paddock = { stable = nil, peds = {}, data = nil, at = 0, clock = 0 }

local function clearPaddock()
    for _, p in pairs(paddock.peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    paddock.peds, paddock.stable, paddock.data = {}, nil, nil
end

local function spawnAnimal(model, at, scale, lying)
    local hash = LoadModel(model)
    if not hash then return nil end
    local ped = CreatePed(hash, at.x, at.y, at.z, at.w or 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    if BR.paddock.randomCoat then Citizen.InvokeNative(0x283978A15512B2FE, ped, true) else Citizen.InvokeNative(0x283978A15512B2FE, ped, false) end
    PlaceEntityOnGroundProperly(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedSeeingRange(ped, 0.0)
    SetPedHearingRange(ped, 0.0)
    if scale then N.scale(ped, scale) end
    TaskStartScenarioInPlace(ped, joaat(lying and 'WORLD_ANIMAL_HORSE_SLEEPING' or 'WORLD_ANIMAL_HORSE_GRAZING'), -1, true, false, false, false)
    return ped
end

local function spots(s)
    if s.paddock then return s.paddock end
    local base = s.horsePreview
    local h = math.rad((base.w or 0.0) + 90.0)
    local off = BR.paddock.offset
    local function at(i)
        local d = (i - 2) * BR.paddock.spacing
        return vector4(base.x + math.cos(h) * off + math.cos(h - math.pi / 2) * d, base.y + math.sin(h) * off + math.sin(h - math.pi / 2) * d, base.z, base.w or 0.0)
    end
    return { sire = at(1), dam = at(2), foal = at(3) }
end

local function foalScale(p, now)
    local full = p.scale or 1.0
    local start = BR.paddock.foalStart * full
    local span = math.max(1, p.readyat - p.bredat)
    local t = U.clamp((now - p.bredat) / span, 0, 1)
    return start + (full - start) * t
end

CreateThread(function()
    while true do
        Wait(1000)
        if BR.enabled and BR.paddock.enabled then
            local me = GetEntityCoords(PlayerPedId())
            local near = nil
            for id, s in pairs(Config.Stables) do
                if #(me - vector3(s.horsePreview.x, s.horsePreview.y, s.horsePreview.z)) <= BR.paddock.range then near = id end
            end
            if near ~= paddock.stable then clearPaddock() paddock.stable = near end
            if near and GetGameTimer() - paddock.at >= BR.paddock.reaskSec * 1000 then
                paddock.at = GetGameTimer()
                local ok, list, now = Call('paddock', near)
                if ok and paddock.stable == near then
                    local p = type(list) == 'table' and list[1] or nil
                    paddock.clock, paddock.now = GetGameTimer(), now
                    if not p then clearPaddock() paddock.stable = near
                    elseif not paddock.data or paddock.data.bredat ~= p.bredat then
                        clearPaddock()
                        paddock.stable, paddock.data = near, p
                        local sp = spots(Config.Stables[near])
                        paddock.peds.sire = spawnAnimal(p.siremodel or p.model, sp.sire, nil, false)
                        paddock.peds.dam = spawnAnimal(p.dammodel or p.model, sp.dam, nil, true)
                        if BR.paddock.foal then
                            paddock.foalScale = foalScale(p, now)
                            paddock.peds.foal = spawnAnimal(p.model, sp.foal, paddock.foalScale, false)
                            local f = paddock.peds.foal
                            if f then
                                if p.palette and p.palette ~= '' then Look.paintCoat(f, 'metaped_' .. p.palette, p.tint0, p.tint1, p.tint2, p.tint1, p.tint2) end
                                if p.hairpalette and p.hairpalette ~= '' then Look.paintHair(f, 'metaped_' .. p.hairpalette, p.htint0, p.htint1, p.htint2) end
                            end
                        end
                    end
                end
            end
            -- grow the foal; the family rests together for a while every few minutes
            local p = paddock.data
            if p and paddock.peds.foal and DoesEntityExist(paddock.peds.foal) then
                local now = paddock.now + math.floor((GetGameTimer() - paddock.clock) / 1000)
                local sc = foalScale(p, now)
                if math.abs(sc - (paddock.foalScale or sc)) / sc > 0.01 then paddock.foalScale = sc N.scale(paddock.peds.foal, sc) end
                local cycle = now % BR.paddock.restEvery
                local lying = BR.paddock.restFor > 0 and cycle < BR.paddock.restFor
                if lying ~= paddock.lying then
                    paddock.lying = lying
                    for key, ped in pairs(paddock.peds) do
                        if DoesEntityExist(ped) and key ~= 'dam' then
                            ClearPedTasks(ped)
                            TaskStartScenarioInPlace(ped, joaat(lying and 'WORLD_ANIMAL_HORSE_SLEEPING' or 'WORLD_ANIMAL_HORSE_GRAZING'), -1, true, false, false, false)
                        end
                    end
                end
            end
            local mount = GetMount(PlayerPedId())
            for _, ped in pairs(paddock.peds) do
                if mount ~= 0 and mount == ped then
                    TaskDismountAnimal(PlayerPedId(), 0, 0, 0, 0, 0)
                    Tip(L('leaveHer'))
                end
            end
        elseif paddock.stable then
            clearPaddock()
        end
    end
end)

AddEventHandler('onResourceStop', function(res) if res == RES then clearPaddock() end end)
