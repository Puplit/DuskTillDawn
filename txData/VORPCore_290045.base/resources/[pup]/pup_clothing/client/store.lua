-- pup_clothing | the clothing store: preview, camera, colours, save and cancel.

local U, Cat, Ped = PC.U, PC.Cat, PC.Ped
local Store = {}
PC.Store = Store

local St = {
    open = false,
    creator = false,
    free = false,
    sex = 'male',
    items = {},      -- [cat] = { 'None' slot implied at 1; items[k] is garment k (u32 hash or npc row) }
    sel = {},        -- [cat] = row value (1 = None)
    colours = {},    -- [cat] = { p, c = {c1,c2,c3} } for this visit
    snapshot = {},   -- colours when the store opened
    saved = {},      -- colours already paid for (for billing only new or changed ones)
    body = 0, legs = 0,
    cam = nil, baseHeading = 0.0, zoom = 0.0, height = 0.0,
    heading = nil,   -- remembered between visits
    dialog = false,  -- a name or confirm box is up on the page
    side = 'left',
    gen = 0,
}

local pendingBuy = nil -- { token } while the server decides a purchase

function Store.isOpen() return St.open end
function Store.isCreator() return St.open and St.creator end

local function copyColours(src)
    local out = {}
    for k, v in pairs(src or {}) do
        out[k] = { p = v.p, c = { v.c[1], v.c[2], v.c[3] } }
    end
    return out
end

---------------------------------------------------------------------------
-- catalogue rows for a sex (multiplayer first, singleplayer appended when offered)
---------------------------------------------------------------------------
local itemCache = {}
local function itemsFor(sex)
    if itemCache[sex] then return itemCache[sex] end
    local out = {}
    for cat, list in pairs(Cat.lists[sex] or {}) do
        local l = {}
        for i, h in ipairs(list) do l[i] = h end
        out[cat] = l
    end
    if Config.Npc.inStore and Cat.npc then
        for cat, rows in pairs(Cat.npc.lists[sex] or {}) do
            if not Config.SkipCategories[cat] then
                local l = out[cat]
                if not l then
                    l = {}
                    out[cat] = l
                end
                for _, r in ipairs(rows) do l[#l + 1] = r end
            end
        end
    end
    itemCache[sex] = out
    return out
end

function Store.dropItemCache() itemCache = {} end

local function indexOfHash(cat, hash)
    local l = St.items[cat]
    local h = U.u32(hash)
    if not l or not h then return nil end
    for i, it in ipairs(l) do
        if type(it) == 'number' and it == h then return i + 1 end
    end
    return nil
end

local function indexOfNpc(cat, drawable)
    local l = St.items[cat]
    local d = U.u32(drawable)
    if not l or not d then return nil end
    for i, it in ipairs(l) do
        if type(it) == 'table' and U.u32(it.d) == d then return i + 1 end
    end
    return nil
end

local function itemAt(cat)
    local v = St.sel[cat] or 1
    if v <= 1 then return nil end
    return St.items[cat] and St.items[cat][v - 1] or nil
end

---------------------------------------------------------------------------
-- price shown on the Save button (the server works out the real one)
---------------------------------------------------------------------------
local function tintPrice(cat)
    return tonumber(Config.Tints.prices[cat]) or tonumber(Config.Tints.defaultPrice) or 0
end

local function sameColour(a, b)
    if not a or not b or a.p ~= b.p then return false end
    return a.c[1] == b.c[1] and a.c[2] == b.c[2] and a.c[3] == b.c[3]
end

local function runningPrice()
    if St.creator or St.free then return 0 end
    local price = Config.Store.price
    if Config.Tints.enabled then
        for cat, col in pairs(St.colours) do
            if (St.sel[cat] or 1) > 1 and col.p > 0
                and (Config.Tints.chargeUnchanged or not sameColour(col, St.saved[cat])) then
                price = price + tintPrice(cat)
            end
        end
    end
    return price
end

local function rowState(cat)
    return { key = cat, value = St.sel[cat] or 1, tinted = St.colours[cat] ~= nil }
end

local function pushPrice()
    SendNUIMessage({ action = 'price', price = runningPrice() })
end

---------------------------------------------------------------------------
-- dressing the preview
---------------------------------------------------------------------------
local function bareBody(ped, cat)
    local which = Config.BareBody[cat]
    if not which then return end
    local h = which == 'BodyType' and St.body or St.legs
    if h and h ~= 0 then Ped.applyHash(ped, h) end
end

local function paint(ped, cat)
    local col = St.colours[cat]
    local it = itemAt(cat)
    if not col or not it then return end
    if type(it) == 'table' then
        Ped.applyNpc(ped, it, col)
    else
        Ped.tintCategory(ped, cat, col.p, col.c)
    end
end

local function dress(cat)
    local ped = PlayerPedId()
    local it = itemAt(cat)
    if not it then
        Ped.remove(ped, cat)
        bareBody(ped, cat)
        Ped.dbg('preview %s: none', cat)
    elseif type(it) == 'table' then
        Ped.remove(ped, cat)
        Ped.applyNpc(ped, it, nil)
        Ped.dbg('preview %s: singleplayer %s', cat, tostring(it.d))
    else
        Ped.applyHash(ped, it)
        local name = Cat.names[it]
        Ped.dbg('preview %s: %s (%s)', cat, tostring(it), (name and name ~= '') and name or 'NO CATALOGUE NAME')
    end
    Ped.refresh(ped)
    paint(ped, cat)
    Ped.refresh(ped)
end

---------------------------------------------------------------------------
-- camera
---------------------------------------------------------------------------
local function placeCam()
    if not St.cam then return end
    local C = Config.Camera
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local angle = St.creator and C.creatorAngle or C.angle
    local a = math.rad(St.baseHeading + angle)
    local dx, dy = -math.sin(a), math.cos(a)
    local cx, cy, cz = pos.x + dx * St.zoom, pos.y + dy * St.zoom, pos.z + St.height
    local lx, ly = pos.x, pos.y
    if not St.creator then
        -- move the aim sideways so the ped stands clear of the panel
        local side = (St.side == 'right') and -1.0 or 1.0
        local off = C.sideOffset * (St.zoom / C.zoomMax) * side
        lx, ly = pos.x - dy * off, pos.y + dx * off
    end
    SetCamCoord(St.cam, cx, cy, cz)
    PointCamAtCoord(St.cam, lx, ly, pos.z + St.height)
    if Config.Debug.client then
        Ped.dbg('camera zoom %.2f height %.2f angle %.0f', St.zoom, St.height, angle)
    end
end

local function startCam()
    local C = Config.Camera
    St.zoom, St.height = C.zoomDefault, C.heightDefault
    St.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(St.cam, St.creator and C.creatorFov or C.fov)
    placeCam()
    SetCamActive(St.cam, true)
    RenderScriptCams(true, true, C.easeMs, true, true)
    if not St.creator then
        DisplayHud(false)
        DisplayRadar(false)
    end
end

local function stopCam()
    if not St.cam then return end
    RenderScriptCams(false, true, Config.Camera.easeMs, true, true)
    SetCamActive(St.cam, false)
    DestroyCam(St.cam, false)
    St.cam = nil
    if not St.creator then
        DisplayHud(true)
        DisplayRadar(true)
    end
end

---------------------------------------------------------------------------
-- open
---------------------------------------------------------------------------
local function seed(compsJson, ownExtras)
    St.sel = {}
    for cat in pairs(St.items) do St.sel[cat] = 1 end

    -- the saved clothes first
    local saved = U.decodeObject(compsJson, 64000) or {}
    for slot, hash in pairs(saved) do
        local cat = Cat.categoryOf(slot)
        local idx = St.items[cat] and indexOfHash(cat, hash)
        if idx then St.sel[cat] = idx end
    end

    -- then what the ped really wears, which beats a stale record
    local ped = PlayerPedId()
    local worn = Ped.scan(ped)
    if #worn > 0 then
        local seen = {}
        for _, w in ipairs(worn) do
            local cat = w.cat
            if cat and St.items[cat] then
                local idx = (w.shop ~= 0) and indexOfHash(cat, w.shop) or nil
                if not idx and Config.Npc.inStore then
                    local t = Ped.tuple(ped, w.index)
                    idx = indexOfNpc(cat, t.d)
                end
                if idx then
                    St.sel[cat] = idx
                    seen[cat] = true
                end
            end
        end
        for cat in pairs(St.items) do
            if not seen[cat] then St.sel[cat] = 1 end
        end
        Ped.dbg('seeded %d worn categories from the ped', U.count(seen))
    end

    -- singleplayer pieces kept in the extras, when the store offers them
    if Config.Npc.inStore then
        for cat, e in pairs(ownExtras or {}) do
            if e.h and St.items[cat] then
                local idx = indexOfNpc(cat, e.h)
                if idx then St.sel[cat] = idx end
            end
        end
    end
end

local function pageRows()
    local rows = {}
    for cat, list in pairs(St.items) do
        rows[#rows + 1] = {
            key = cat, label = Cat.label(cat), group = Cat.group(cat),
            count = #list + 1, value = St.sel[cat] or 1, tinted = St.colours[cat] ~= nil,
        }
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    local present, groups = {}, {}
    for _, r in ipairs(rows) do present[r.group] = true end
    for _, g in ipairs(Config.Groups) do
        if present[g.id] then groups[#groups + 1] = { id = g.id, label = g.label } end
    end
    return rows, groups
end

local frameLoop -- forward

local function begin(data, creator)
    if St.open then return false end
    local ped = PlayerPedId()
    St.open = true
    St.creator = creator == true
    St.free = data.free == true
    St.gen = St.gen + 1
    St.sex = Ped.sex(ped)
    St.items = itemsFor(St.sex)
    St.body, St.legs = U.int(data.body) or 0, U.int(data.legs) or 0
    St.dialog = false

    local own = data.extras and PC.Extras.parse(data.extras) or {}
    St.colours = {}
    for cat, e in pairs(own) do
        if e.p > 0 then St.colours[cat] = { p = e.p, c = { e.c[1], e.c[2], e.c[3] } } end
    end
    St.snapshot = copyColours(St.colours)
    St.saved = copyColours(St.colours)
    seed(data.comps or '{}', own)

    TriggerEvent('vorp_inventory:Client:DisableInventory', true)
    FreezeEntityPosition(ped, true)
    if not St.creator then
        St.heading = St.heading or Config.Camera.startHeading
        SetEntityHeading(ped, St.heading)
    end
    St.baseHeading = GetEntityHeading(ped)
    local okSide, side = pcall(function() return exports['pup-ui']:GetMenuSide() end)
    if okSide and (side == 'left' or side == 'right') then St.side = side end
    startCam()

    local rows, groups = pageRows()
    SendNUIMessage({
        action = 'openStore',
        text = Locale.page,
        title = L('storeTitle'),
        sex = St.sex,
        creator = St.creator,
        tints = Config.Tints.enabled,
        palettes = #Config.Palettes,
        channelMax = Config.Tints.channelMax,
        nameMax = Config.Outfits.nameBoxMax,
        price = runningPrice(),
        rows = rows,
        groups = groups,
        side = St.side,
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    PC.Main.promptHidden(true)
    frameLoop(St.gen)
    return true
end

-- close the page and give the player back; does not touch the clothes
local function shut()
    if not St.open then return end
    St.open = false
    St.gen = St.gen + 1
    St.dialog = false
    SendNUIMessage({ action = 'closeStore' })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    TriggerEvent('vorp_inventory:Client:DisableInventory', false)
    FreezeEntityPosition(PlayerPedId(), false)
    stopCam()
end

function Store.cancel(reason)
    if not St.open then return end
    local creator = St.creator
    shut()
    St.colours = copyColours(St.snapshot)
    if creator then
        PC.Main.promptHidden(false)
        TriggerEvent('pup_clothing:creatorCancelled')
        return
    end
    TriggerServerEvent('pup_clothing:closed')
    if reason == 'failsafe' then TriggerEvent('vorp:TipRight', L('leftStore'), 4000) end
    SetTimeout(Config.Timing.cancelRcMs, function()
        ExecuteCommand('rc')
        PC.Main.promptHidden(false)
    end)
end

local function buildPayload()
    local clothes, extras = {}, {}
    local forced = {}
    if St.sex == 'male' then
        for _, slot in ipairs(Config.Store.maleForceNone) do forced[slot] = true end
    end
    for cat in pairs(St.items) do
        local slot = Cat.slotName(cat)
        local it = itemAt(cat)
        if type(it) == 'number' and not forced[slot] then
            clothes[slot] = it
        else
            clothes[slot] = -1
        end
        if type(it) == 'table' then
            extras[cat] = { h = it.d, p = 0, c = { 0, 0, 0 } }
        end
        local col = St.colours[cat]
        if col and it then
            local e = extras[cat] or { h = false }
            e.p, e.c = col.p, { col.c[1], col.c[2], col.c[3] }
            extras[cat] = e
        end
    end
    return json.encode(clothes), U.encodeObject(extras)
end

function Store.save(name)
    if not St.open then return end
    local creator = St.creator
    local clothesJson, extrasJson = buildPayload()
    shut()
    if creator then
        PC.Main.promptHidden(false)
        TriggerEvent('pup_clothing:creatorDone', clothesJson, extrasJson)
        return
    end
    local token = {}
    pendingBuy = token
    TriggerServerEvent('pup_clothing:buy', clothesJson, type(name) == 'string' and name or '', extrasJson)
    -- no answer at all (dropped as too fast, or the server is gone): undo the preview
    SetTimeout(15000, function()
        if pendingBuy == token then
            pendingBuy = nil
            ExecuteCommand('rc')
            PC.Main.promptHidden(false)
        end
    end)
end

RegisterNetEvent('pup_clothing:bought', function(compsJson, extrasJson)
    if not pendingBuy then return end
    pendingBuy = nil
    CreateThread(function()
        Ped.rebuildWith(compsJson)
        local map = PC.Extras.parse(extrasJson)
        PC.Extras.own = map
        PC.Extras.foreign = false
        PC.Extras.apply(map)
        PC.Toggles.clear()
        TriggerEvent('pup_clothing:client:pedRebuilt')
        PC.Main.promptHidden(false)
    end)
end)

RegisterNetEvent('pup_clothing:buyFailed', function()
    if not pendingBuy then return end
    pendingBuy = nil
    -- the preview is still on the ped: put the saved clothes back
    ExecuteCommand('rc')
    PC.Main.promptHidden(false)
end)

---------------------------------------------------------------------------
-- every frame while open
---------------------------------------------------------------------------
frameLoop = function(gen)
    CreateThread(function()
        local K, C, Lt = Config.Keys, Config.Camera, Config.Light
        local heldSince = nil
        while St.open and St.gen == gen do
            local ped = PlayerPedId()
            DisableAllControlActions(0)
            for _, ctl in ipairs(Config.DisabledControls) do DisableControlAction(0, ctl, true) end

            -- voice keeps working
            EnableControlAction(0, K.pushToTalk, true)
            local state = LocalPlayer.state
            if state.pup_ptt_latched then SetControlNormal(0, K.pushToTalk, 1.0) end
            if state.pup_radio_talking then
                EnableControlAction(0, K.radioTalk, true)
                SetControlNormal(0, K.radioTalk, 1.0)
            end

            if not St.dialog then
                local turned, moved = false, false
                if IsDisabledControlPressed(0, K.turnLeft) then
                    SetEntityHeading(ped, (GetEntityHeading(ped) + C.turnStep) % 360.0)
                    turned = true
                elseif IsDisabledControlPressed(0, K.turnRight) then
                    SetEntityHeading(ped, (GetEntityHeading(ped) - C.turnStep) % 360.0)
                    turned = true
                end
                if turned and not St.creator then St.heading = GetEntityHeading(ped) end
                local z = St.zoom
                if IsDisabledControlPressed(0, K.zoomIn) then z = z - C.zoomStep end
                if IsDisabledControlPressed(0, K.zoomOut) then z = z + C.zoomStep end
                if z ~= St.zoom and z >= C.zoomMin and z <= C.zoomMax then
                    St.zoom = z
                    moved = true
                end
                local h = St.height
                if IsDisabledControlPressed(0, K.raise) then h = h + C.heightStep end
                if IsDisabledControlPressed(0, K.lower) then h = h - C.heightStep end
                if h ~= St.height and h >= C.heightMin and h <= C.heightMax then
                    St.height = h
                    moved = true
                end
                if moved then placeCam() end
            end

            local p = GetEntityCoords(ped)
            DrawLightWithRange(p.x + Lt.offset, p.y + Lt.offset, p.z + Lt.offset, 255, 255, 255, Lt.range, Lt.intensity)

            -- the way out that always works
            if IsDisabledControlPressed(0, Config.Store.failsafeKey) then
                heldSince = heldSince or GetGameTimer()
                if GetGameTimer() - heldSince >= Config.Store.failsafeHoldMs then
                    Store.cancel('failsafe')
                    break
                end
            else
                heldSince = nil
            end

            if IsEntityDead(ped) then
                Store.cancel()
                break
            end
            Wait(0)
        end
    end)
end

---------------------------------------------------------------------------
-- page callbacks
---------------------------------------------------------------------------
local function catOf(data)
    local cat = type(data) == 'table' and data.key or nil
    if type(cat) ~= 'string' or not St.items[cat] then return nil end
    return cat
end

RegisterNUICallback('store:change', function(data, cb)
    local cat = catOf(data)
    if not St.open or not cat then return cb({}) end
    local v = U.int(data.value) or 1
    v = U.clamp(v, 1, #St.items[cat] + 1)
    St.sel[cat] = v
    dress(cat)
    pushPrice()
    cb(rowState(cat))
end)

local function colourState(cat)
    local col = St.colours[cat]
    return {
        key = cat, label = Cat.label(cat), price = tintPrice(cat),
        palette = col and col.p or 1, c = col and col.c or { 0, 0, 0 }, has = col ~= nil,
    }
end

RegisterNUICallback('store:select', function(data, cb)
    local cat = catOf(data)
    if not St.open or not cat or not Config.Tints.enabled or (St.sel[cat] or 1) <= 1 then
        return cb({ show = false })
    end
    local s = colourState(cat)
    s.show = true
    cb(s)
end)

RegisterNUICallback('store:tint', function(data, cb)
    local cat = catOf(data)
    if not St.open or not cat or not Config.Tints.enabled or (St.sel[cat] or 1) <= 1 then return cb({}) end
    local col = St.colours[cat] or { p = 1, c = { 0, 0, 0 } }
    local max = Config.Tints.channelMax
    col.p = U.clamp(U.int(data.palette) or col.p, 1, #Config.Palettes)
    local c = type(data.c) == 'table' and data.c or {}
    col.c = {
        U.clamp(U.int(c[1]) or col.c[1], 0, max),
        U.clamp(U.int(c[2]) or col.c[2], 0, max),
        U.clamp(U.int(c[3]) or col.c[3], 0, max),
    }
    St.colours[cat] = col
    local ped = PlayerPedId()
    paint(ped, cat)
    Ped.refresh(ped)
    pushPrice()
    local s = colourState(cat)
    s.row = rowState(cat)
    cb(s)
end)

RegisterNUICallback('store:removeTint', function(data, cb)
    local cat = catOf(data)
    if not St.open or not cat then return cb({}) end
    St.colours[cat] = nil
    dress(cat) -- the garment as it ships
    pushPrice()
    cb(rowState(cat))
end)

RegisterNUICallback('store:reset', function(_, cb)
    if not St.open then return cb({}) end
    local ped = PlayerPedId()
    for cat in pairs(St.items) do
        St.sel[cat] = 1
        Ped.remove(ped, cat)
    end
    St.colours = {}
    bareBody(ped, 'shirts_full')
    bareBody(ped, 'pants')
    Ped.refresh(ped)
    local rows = pageRows()
    cb({ rows = rows, price = runningPrice() })
end)

RegisterNUICallback('store:dialog', function(data, cb)
    St.dialog = type(data) == 'table' and data.open == true
    cb({})
end)

RegisterNUICallback('store:save', function(data, cb)
    cb({})
    local name = type(data) == 'table' and data.name or nil
    if type(name) == 'string' then
        name = U.utf8Cut(U.trim(name), Config.Outfits.nameBoxMax)
        if name == '' then name = Locale.page.defaultName end
    else
        name = nil
    end
    if St.creator then name = nil end
    Store.save(name)
end)

RegisterNUICallback('store:cancel', function(_, cb)
    cb({})
    Store.cancel()
end)

---------------------------------------------------------------------------
-- opening
---------------------------------------------------------------------------
local wantStore = 0 -- GetGameTimer() of the last request
function Store.request()
    if St.open or pendingBuy then return end
    wantStore = GetGameTimer()
    TriggerServerEvent('pup_clothing:openStore')
end

RegisterNetEvent('pup_clothing:storeData', function(data)
    if type(data) ~= 'table' or St.open or pendingBuy then return end
    local asked = GetGameTimer() - wantStore < 10000
    if not asked and not data.free then return end
    wantStore = 0
    if PC.Wardrobe and PC.Wardrobe.isOpen() then return end
    begin(data, false)
end)

exports('OpenCreatorFitting', function(clothesJson)
    if not Config.Creator.enabled then return false end
    if St.open then return false end
    if type(clothesJson) ~= 'string' or clothesJson == '' then clothesJson = '{}' end
    return begin({ comps = clothesJson, extras = '{}', free = true }, true)
end)

exports('IsCreatorFitting', function()
    return St.open and St.creator
end)

-- page focus and the ped must never be left behind (character switch). A purchase still waiting for its
-- answer belongs to the previous character, so its answer is ignored; the prompt always comes back.
function Store.forceClose()
    pendingBuy = nil
    if St.open then
        if St.creator then
            Store.cancel()
        else
            shut()
            TriggerServerEvent('pup_clothing:closed')
        end
    end
    PC.Main.promptHidden(false)
end

AddEventHandler('pup-ui:menuSide', function(side)
    St.side = (side == 'right') and 'right' or 'left'
    if St.open then placeCam() end
end)
