-- pup-stable | what the stable menu's rows preview and what their actions do

Menus.palCtx = nil
local previewComp = nil   -- { hash } applied on the preview horse for a tack row

local function coins()
    pcall(function() PlaySoundFrontend('PURCHASE', 'Ledger_Sounds', true, 0) end)
end

local function suspendAsk(title, max, kind)
    Ui.suspend()
    local v = Ask(title, max, kind)
    Ui.resume()
    if v == '' then return nil end
    return v
end

------------------------------------------------------------------------------
-- previews
------------------------------------------------------------------------------
local function coatModel(ref)
    local b = Config.BreedById[ref.breed]
    return b and b.coats[ref.coat] and b.coats[ref.coat].model
end

-- after a shop coat appears: read its stats once per breed and show them on every coat of the breed.
-- A reading whose ranks never filled in is not cached: the next coat shown tries again.
local function cacheBreed(ped, breedId)
    if Stable.statsCache[breedId] then return end
    local stats, ready = Look.readStats(ped, 2500)
    if not ready or not DoesEntityExist(ped) or Stable.statsCache[breedId] then return end
    Stable.statsCache[breedId] = stats
    local m = Menus.build('coats:' .. breedId)
    if m and Ui.menus[m.id] then Ui.menu(m) end
end

local function showOwnHorse(id, after)
    local h = Me.horses[id]
    if not h then return nil end
    return Stable.showHorse('own:' .. id, h.model, 'own', function(ped, fresh)
        if fresh then
            Look.sex(ped, h.isFemale)
            if h.scale and math.abs(h.scale - 1.0) > 0.001 then N.scale(ped, h.scale) end
            Look.dress(ped, h.comps, true)
            previewComp = nil
        end
        if after then after(ped, fresh) end
    end)
end

-- the horse tack is shown on: the selected horse, else the favourite, else the first shop horse
local function tackHorse(after)
    local id = Menus.selHorse or (FavouriteHorse() or {}).id
    if id and Me.horses[id] then return showOwnHorse(id, after) end
    local b = Config.Breeds[1]
    return Stable.showHorse('tack:default', b.coats[1].model, 'own', after)
end

local function tryComp(cat, hash, color)
    tackHorse(function(ped)
        if previewComp then Look.removeComp(ped, previewComp) end
        if cat == 'horse_outfits' then N.outfit(ped, hash) else N.applyComp(ped, hash) end
        N.update(ped)
        previewComp = hash
        if color then
            Wait(50)
            Look.paintIndexOf(ped, hash, color.palette, color.tint0, color.tint1, color.tint2)
        end
    end)
end

local function paletteColor(sl, mode)
    local pals = Config.Colors.palettes
    local p = pals[(U.int(sl[1], 0) % #pals) + 1]
    if mode == 'tack' then
        return { palette = 'metaped_' .. p.id, tint0 = U.int(sl[2], 0), tint1 = U.int(sl[3], 0), tint2 = U.int(sl[4], 0) }, p
    end
    return { palette = 'metaped_' .. p.id, tint0 = U.int(sl[2], 0), tint1 = U.int(sl[3], 0), tint2 = U.int(sl[4], 0),
        bodyTint1 = U.int(sl[5], 0), bodyTint2 = U.int(sl[6], 0) }, p
end

-- palette switch: retarget every tint slider to the new strip, reset its tints
local lastPal = {}
local function syncPaletteSliders(menuId, it, p)
    if lastPal[menuId] == p.id then return end
    lastPal[menuId] = p.id
    local fields = { sliders = {} }
    for i, s in ipairs(it.sliders) do
        if i > 1 then
            s.palette, s.max, s.index = p.id, p.tints, 0
            fields.sliders[i] = { palette = p.id, max = p.tints, index = 0 }
        else
            fields.sliders[i] = false
        end
    end
    Ui.send('item', { menu = menuId, item = it.id, fields = fields })
end

function Menus.onPreview(menuId, it, sl)
    local k = it.k
    if k == 'coat' then
        local model = coatModel(it.ref)
        if model then
            Stable.showHorse('coat:' .. it.ref.breed .. ':' .. it.ref.coat, model, 'shop', function(ped, fresh)
                Look.sex(ped, Menus.female)
                if fresh then cacheBreed(ped, it.ref.breed) end
            end)
        end
    elseif k == 'horse' then
        local h = Me.horses[it.ref]
        if h and not h.isDead then Menus.selHorse = h.id end
        showOwnHorse(it.ref)
    elseif k == 'catalogue' then
        local entry = HorseComponents[it.ref.cat][it.ref.index]
        local v = (U.int(sl[1], 0) % #entry.variations) + 1
        tryComp(it.ref.cat, entry.variations[v])
    elseif k == 'owned' then
        for _, c in ipairs(Me.comps) do
            if c.id == it.ref then tryComp(c.category, c.hash, c.color) end
        end
    elseif k == 'palette' then
        local color, p = paletteColor(sl, it.ref)
        syncPaletteSliders(menuId, it, p)
        local ctx = Menus.palCtx
        if not ctx then return end
        if it.ref == 'tack' then
            tryComp(ctx.cat, ctx.hash, color)
        else
            local ped = Stable.preview
            if ped and DoesEntityExist(ped) then
                Look.paintCoat(ped, color.palette, color.tint0, color.tint1, color.tint2, color.bodyTint1, color.bodyTint2)
            end
        end
    elseif k == 'wagonDef' then
        local w = Config.WagonCategoryById[it.ref.cat].wagons[it.ref.index]
        Stable.showWagon('wdef:' .. w.model, w.model)
    elseif k == 'wagon' then
        local w = Me.wagons[it.ref]
        if w then Stable.showWagon('wown:' .. w.id, w.model, function(veh, fresh) if fresh then Look.wagon(veh, w) end end) end
    elseif k == 'wopt' then
        local w = Me.wagons[it.ref.wagon]
        if w then
            local look = U.copy(w)
            local key = ({ vehicle_tints = 'tint', vehicle_propsets = 'propset', vehicle_liveries = 'livery', vehicle_lantern_propsets = 'lantern', vehicle_extras = 'extra' })[it.ref.col]
            look[key] = it.ref.value
            Stable.clearPreview()
            Stable.showWagon('wopt:' .. w.id .. ':' .. tostring(it.ref.value), w.model, function(veh) Look.wagon(veh, look) end)
        end
    elseif k and k:match('^br%u') then
        Breeding.onPreview(menuId, it, sl)
    end
end

------------------------------------------------------------------------------
-- buying
------------------------------------------------------------------------------
local function buyHorse(ref, gold, coatColor)
    local key = 'coat:' .. ref.breed .. ':' .. ref.coat
    local ped = Stable.previewKey == key and Stable.preview or nil
    local name = suspendAsk(L('askHorseName'), Config.General.nameMax)
    if not name then return end
    local req = { stable = Stable.id, breed = ref.breed, coat = ref.coat, name = name, gold = gold, female = Menus.female }
    if ped and DoesEntityExist(ped) then
        local stats, ready = Look.readStats(ped, 2500)
        -- an unfilled reading would save a 1/1/1 horse: use the breed's cached reading instead
        if not ready then stats = Stable.statsCache[ref.breed] end
        req.stats = stats
        req.look = Look.readLook(ped)
        if coatColor then coatColor.head, coatColor.body = Look.coatGuids(ped) end
    end
    req.coatColor = coatColor
    local ok, payload = CallTip('buyHorse', req)
    if not ok then return end
    coins()
    SetHorse(payload)
    Ui.cash()
    Menus.refresh('owned')
    if Menus.palCtx then Ui.back() end
end

local function buyComp(ref, variationIndex, gold, color)
    local entry = HorseComponents[ref.cat][ref.index]
    local hash = entry.variations[(U.int(variationIndex, 0) % #entry.variations) + 1]
    local horse = Menus.selHorse or 0
    local ok, comp, horsePayload = CallTip('buyComp', { stable = Stable.id, category = ref.cat, hash = hash, horse = horse, gold = gold, color = color })
    if not ok then return end
    coins()
    Me.comps[#Me.comps + 1] = comp
    if horsePayload then SetHorse(horsePayload) end
    previewComp = nil
    Ui.cash()
    Menus.refreshAll()
end

------------------------------------------------------------------------------
-- retrieving
------------------------------------------------------------------------------
local function retrieveHorse(id)
    local row = Me.horses[id]
    local s = Config.Stables[Stable.id]
    if not row or not s then return end
    if Horse.peds[id] then Horse.despawn(id, false) end
    Ui.hide(true)
    DoScreenFadeOut(500)
    Wait(600)
    local spot = s.retrieve or s.ownPreview
    RequestCollisionAtCoord(spot.x, spot.y, spot.z)
    local deadline = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < deadline do Wait(50) end
    local ped = Look.spawnHorse(row, spot, true, true, true)
    if ped then
        Horse.adopt(row, ped)
        for _, delay in ipairs({ 600, 1200 }) do
            Wait(delay)
            if DoesEntityExist(ped) then Look.dress(ped, row.comps, true) end
        end
        local me = PlayerPedId()
        local side = GetOffsetFromEntityInWorldCoords(ped, -1.2, 0.0, 0.0)
        SetEntityCoords(me, side.x, side.y, side.z - 1.0, false, false, false, false)
        SetEntityHeading(me, spot.w or 0.0)
    end
    DoScreenFadeIn(600)
end

local function retrieveWagon(id)
    local row = Me.wagons[id]
    local s = Config.Stables[Stable.id]
    if not row or not s then return end
    local spot = s.wagonSpawn
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(v) - vector3(spot.x, spot.y, spot.z)) <= Config.Wagon.safeSpawn then return Tip(L('spawnBusy')) end
    end
    Ui.hide(true)
    if Wagon.cur and DoesEntityExist(Wagon.cur.veh) and Wagon.cur.id == id then Wagon.forget(true) end
    local veh = Look.spawnWagon(row, spot, true, true)
    if not veh then return end
    Wagon.adopt(row, veh)
    local me = PlayerPedId()
    for _ = 1, 10 do
        if GetPedInVehicleSeat(veh, -1) == me then break end
        SetPedIntoVehicle(me, veh, -1)
        Wait(100)
    end
end

------------------------------------------------------------------------------
-- actions
------------------------------------------------------------------------------
local function after(fnName, ...)
    local ok = Call(fnName, ...)
    return ok
end

function Menus.onAction(menuId, it, a, sl)
    local k = it.k
    -- breeding rows are 'br' + a capital (brFoal, brSire...); the shop's 'breed' rows are not
    if k and k:match('^br%u') then return Breeding.onAction(menuId, it, a, sl) end

    if a == 'open' then
        if k == 'sex' then Menus.female = it.ref == true end
        if k == 'horseCtx' then Menus.selHorse = it.ref end
        if it.child then Menus.show(it.child, true) end
        return
    end
    if a == 'outfit' then
        Ui.hide(true)
        TriggerEvent('pup-misc:outfitter:shop')
        return
    end
    if a == 'buy' or a == 'buyGold' then
        local gold = a == 'buyGold'
        if k == 'coat' then return buyHorse(it.ref, gold, nil) end
        if k == 'catalogue' then return buyComp(it.ref, sl[1], gold, nil) end
        if k == 'palette' then
            local ctx = Menus.palCtx
            if not ctx then return end
            local color = paletteColor(sl, it.ref)
            if it.ref == 'coatBuy' then return buyHorse(ctx.ref, gold, color) end
            if it.ref == 'tack' then return buyComp(ctx.ref, ctx.variation, gold, color) end
            return
        end
        if k == 'wagonDef' then
            local name = suspendAsk(L('askWagonName'), Config.General.nameMax)
            if not name then return end
            local v = Stable.preview
            local look = {}
            if v and DoesEntityExist(v) and Stable.previewKind == 'wagon' then
                look.tint = N.vehTintNow(v)
                look.livery = N.vehLiveryNow(v)
            end
            local ok, payload = CallTip('buyWagon', { stable = Stable.id, cat = it.ref.cat, index = it.ref.index, name = name, look = look })
            if ok then coins(); SetWagon(payload); Ui.cash(); Menus.refresh('ownedWagons') end
            return
        end
        if k == 'wopt' then
            local ok, payload = CallTip('customiseWagon', it.ref.wagon, it.ref.col, it.ref.value, it.ref.index, Stable.id)
            if ok then coins(); SetWagon(payload); Ui.cash(); Menus.refresh(menuId) end
            return
        end
        return
    end
    if a == 'color' then
        if not Me.canColor then return Tip(L('noPalette')) end
        if k == 'coat' then
            Menus.palCtx = { mode = 'coatBuy', ref = it.ref }
            lastPal['palette:coatBuy'] = nil
            return Menus.show('palette:coatBuy', true)
        elseif k == 'catalogue' then
            local entry = HorseComponents[it.ref.cat][it.ref.index]
            local v = U.int(sl[1], 0)
            Menus.palCtx = { mode = 'tack', ref = it.ref, cat = it.ref.cat, variation = v, hash = entry.variations[(v % #entry.variations) + 1] }
            lastPal['palette:tack'] = nil
            return Menus.show('palette:tack', true)
        elseif k == 'coatEdit' then
            Menus.palCtx = { mode = 'coatSave', horse = it.ref }
            lastPal['palette:coatSave'] = nil
            showOwnHorse(it.ref)
            return Menus.show('palette:coatSave', true)
        end
        return
    end
    if a == 'save' and k == 'palette' then
        local ctx = Menus.palCtx
        if not ctx or not ctx.horse then return end
        local color = paletteColor(sl, 'coat')
        local ped = Stable.preview
        if ped and DoesEntityExist(ped) then color.head, color.body = Look.coatGuids(ped) end
        local ok, payload = CallTip('saveCoat', ctx.horse, color)
        if ok then SetHorse(payload); Ui.back() end
        return
    end

    local id = it.ref
    if a == 'manage' then
        if k == 'horse' then Menus.selHorse = id; return Menus.show('horse:' .. id, true) end
        if k == 'wagon' then return Menus.show('wagon:' .. id, true) end
    elseif a == 'favourite' then
        if after('favourite', id) then
            for _, h in pairs(Me.horses) do h.favourite = h.id == id end
            Menus.refresh('owned')
        end
    elseif a == 'retrieve' then
        if k == 'horse' then return retrieveHorse(id) end
        if k == 'wagon' then return retrieveWagon(id) end
    elseif a == 'transfer' then
        local target = suspendAsk(L('askTransferTo'), 6, 'number')
        if not target then return end
        local wagon = k == 'wagon' or k == 'transferW'
        local ok = CallTip(wagon and 'transferWagon' or 'transferHorse', id, U.int(target))
        if ok then
            if wagon then Me.wagons[id] = nil; Menus.show('ownedWagons') else
                if Horse.peds[id] then Horse.forget(id, true) end
                Me.horses[id] = nil
                Menus.show('owned')
            end
            Menus.refreshAll()
        end
    elseif a == 'release' or a == 'delete' then
        if CallTip('releaseHorse', id) then
            if Horse.peds[id] then Horse.forget(id, false) end
            Me.horses[id] = nil
            Stable.clearPreview()
            Menus.show('owned')
            Menus.refreshAll()
        end
    elseif a == 'destroy' then
        if CallTip('destroyWagon', id) then
            if Wagon.cur and Wagon.cur.id == id then Wagon.forget(false) end
            Me.wagons[id] = nil
            Stable.clearPreview()
            Menus.show('ownedWagons')
        end
    elseif a == 'revive' or a == 'reviveGold' then
        if CallTip('revive', id, a == 'reviveGold') then
            if Me.horses[id] then Me.horses[id].isDead = false end
            if Horse.peds[id] then Horse.forget(id, true) end
            Ui.cash()
            Menus.refresh('owned')
        end
    elseif a == 'rename' then
        local wagon = k == 'renameW'
        local name = suspendAsk(wagon and L('askNewWagonName') or L('askNewHorseName'), Config.General.nameMax)
        if not name then return end
        if CallTip(wagon and 'renameWagon' or 'renameHorse', id, name) then
            if wagon and Me.wagons[id] then Me.wagons[id].name, Me.wagons[id].label = name, name end
            if not wagon and Me.horses[id] then Me.horses[id].name = name end
            Menus.refreshAll()
        end
    elseif a == 'equip' then
        local horse = Menus.selHorse
        local comp = nil
        for _, c in ipairs(Me.comps) do if c.id == id then comp = c end end
        if not horse or not comp then return end
        local ok, payload = CallTip('equipComp', id, horse, comp.category)
        if ok then
            for _, c in ipairs(Me.comps) do
                if c.category == comp.category and c.on == horse then c.on = 0 end
            end
            comp.on = horse
            SetHorse(payload)
            Stable.clearPreview()
            Menus.refreshAll()
        end
    elseif a == 'unequip' then
        local ok, payload = CallTip('unequipComp', id)
        if ok then
            for _, c in ipairs(Me.comps) do if c.id == id then c.on = 0 end end
            SetHorse(payload)
            Stable.clearPreview()
            Menus.refreshAll()
        end
    elseif a == 'shoes' then
        local ok, payload = CallTip('buyShoes', id, Stable.id)
        if ok then SetHorse(payload); Ui.cash() end
    elseif a == 'transferHere' then
        local kind = k == 'wagon' and 'wagon' or 'horse'
        local ok, payload = CallTip('stableTransfer', kind, id, Stable.id, 'bring')
        if ok then
            if kind == 'horse' then SetHorse(payload) else SetWagon(payload) end
            Ui.cash()
            Menus.refreshAll()
        end
    elseif a == 'sendAway' then
        local ok, payload = CallTip('stableTransfer', id.kind, id.id, id.to, 'send')
        if ok then
            if id.kind == 'horse' then SetHorse(payload) else SetWagon(payload) end
            if id.kind == 'horse' and Stable.previewKind == 'horse' then Stable.rideOff(Stable.preview) end
            Ui.cash()
            Menus.refreshAll()
            Ui.back()
        end
    end
end

-- a stablehand clone rides the sent horse out of sight, then both go
function Stable.rideOff(ped)
    if not ped or not DoesEntityExist(ped) or not Stable.hand then return end
    Stable.preview, Stable.previewKey = nil, nil
    local s = Config.Stables[Stable.id]
    CreateThread(function()
        local hash = LoadModel(s.stablehand)
        if not hash then DeleteEntity(ped) return end
        local c = GetEntityCoords(ped)
        local rider = CreatePed(hash, c.x, c.y, c.z, 0.0, false, false, false, false)
        Citizen.InvokeNative(0x283978A15512B2FE, rider, true)
        FreezeEntityPosition(ped, false)
        N.putOnMount(rider, ped, -1)
        local away = GetOffsetFromEntityInWorldCoords(ped, 0.0, 300.0, 0.0)
        TaskGoStraightToCoord(rider, away.x, away.y, away.z, 3.0, 60000, 0.0, 1.0)
        local t0 = GetGameTimer()
        while GetGameTimer() - t0 < 60000 do
            Wait(1000)
            if not IsEntityOnScreen(ped) then break end
        end
        if DoesEntityExist(rider) then DeleteEntity(rider) end
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end)
end
