-- pup_realestate | the in-world house creator (opened by vorp_admin's Housing page)
-- form -> capture doors (real-door houses) -> move the prompt spot -> summary -> save

local CR = nil -- the running creation, or nil
local LBL = 'pup_realestate:cr:'

local function justPressed(c) return IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c) end

local function u32(n)
    n = U.int(n)
    if not n then return nil end
    return n & 0xFFFFFFFF
end

-- door list (client/doors.lua) indexed by model, built once on first use
local byModel = nil

local function doorIndex()
    if byModel then return byModel end
    byModel = {}
    for _, group in ipairs(DOOR_LIST or {}) do
        local name, model = tostring(group[1] or ''), U.int(group[2])
        if model then
            local m = u32(model)
            local list = byModel[m] or {}
            byModel[m] = list
            for i = 3, #group do
                local d = group[i]
                if type(d) == 'table' and d[1] and d[4] then
                    list[#list + 1] = { hash = U.int(d[1]), model = model, name = name, pos = vector3(d[2] + 0.0, d[3] + 0.0, d[4] + 0.0) }
                end
            end
        end
    end
    return byModel
end

local function family(name)
    name = tostring(name or ''):lower()
    for _, suffix in ipairs({ '_lx', '_rx', '_l', '_r' }) do
        if name:sub(-#suffix) == suffix then return name:sub(1, -#suffix - 1) end
    end
    return name
end

-- optional hook for doors that are not in the list (see README): a function(entity) -> door-system hash
local hookCache = {}
local function fromHook(ent)
    if hookCache[ent] ~= nil then return hookCache[ent] or nil end
    local fn = Config.Creator.findDoorHash
    local hash = nil
    if type(fn) == 'function' then
        local ok, res = pcall(fn, ent)
        if ok then hash = U.int(res) end
    end
    hookCache[ent] = hash or false
    return hash
end

-- what door (if any) an entity is
local function identify(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 3 then return nil end
    local model = GetEntityModel(ent)
    local pos = GetEntityCoords(ent)
    local best, bestD
    for _, d in ipairs(doorIndex()[u32(model)] or {}) do
        local dist = #(d.pos - pos)
        if dist <= 2.0 and (not best or dist < bestD) then best, bestD = d, dist end
    end
    if best then return { hash = best.hash, model = best.model, name = best.name, entity = ent } end
    local hash = fromHook(ent)
    if hash and hash ~= 0 then
        return { hash = hash, model = U.int(model), name = ('door_%s'):format(U.int(model)), entity = ent }
    end
    return nil
end

local function aimedEntity()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local reach = #(cam - C.pos()) + Config.Creator.probeDistance
    local to = cam + dir * reach
    local ray = StartShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, -1, C.ped(), 0)
    local status, hit, _, _, ent = GetShapeTestResult(ray)
    local t = 0
    while status == 1 and t < 10 do
        Wait(0)
        status, hit, _, _, ent = GetShapeTestResult(ray)
        t = t + 1
    end
    if hit == 1 or hit == true then return ent end
    return nil
end

local function taken(hash)
    for _, d in ipairs(CR.doors) do
        if d.objc == hash then return true end
    end
    return false
end

local function label(key, pos, text, icon)
    UI:Add3DInteraction(LBL .. key, { coords = vector3(pos.x, pos.y, pos.z + 1.0), text = text, icon = icon, distance = 10.0 })
    CR.labels[LBL .. key] = true
end

local function unlabel(key)
    UI:Remove3DInteraction(LBL .. key)
    if CR then CR.labels[LBL .. key] = nil end
end

local function clearLabels()
    if not CR then return end
    for id in pairs(CR.labels) do UI:Remove3DInteraction(id) end
    CR.labels = {}
end

-- the other half of a double door, from the list
local function findPair(door)
    local fam = family(door.doorname)
    local best, bestD
    for _, list in pairs(doorIndex()) do
        for _, d in ipairs(list) do
            if d.hash ~= door.objc and not taken(d.hash) and (u32(d.model) == u32(door.doorhash) or family(d.name) == fam) then
                local dist = #(d.pos - vector3(door.x, door.y, door.z))
                if dist <= 3.0 and (not best or dist < bestD) then best, bestD = d, dist end
            end
        end
    end
    return best, bestD
end

local function capture(info)
    if taken(info.hash) then return C.tip(Locale.already_taken) end
    local pos = GetEntityCoords(info.entity)
    local rot = GetEntityRotation(info.entity, 2)
    local d = {
        x = pos.x, y = pos.y, z = pos.z, o = pos.x, p = pos.y, q = pos.z,
        doorname = info.name, doorhash = info.model, objc = info.hash,
        objYaw1 = rot.x, objYaw2 = rot.y, objYaw3 = rot.z, locked = true,
    }
    CR.doors[#CR.doors + 1] = d
    local n = #CR.doors
    if n == 1 then
        label('d' .. n, pos, T('front_label', info.name), 'home')
        C.tip(T('front_taken', info.name), 6000)
    else
        label('d' .. n, pos, T('extra_label', info.name, n - 1), 'key')
        C.tip(T('extra_taken', n - 1, info.name), 6000)
    end
    unlabel('pair')
    local pair, dist = findPair(d)
    if pair then
        label('pair', pair.pos, T('pair_label', pair.name), 'key')
        C.tip(T('pair_found', pair.name, dist), 8000)
    end
end

local function stop(msg)
    clearLabels()
    UI:PromptHide()
    CR = nil
    C.creating = false
    if msg then C.tip(msg) end
end

function C.cancelCreator(silent)
    if not CR then return end
    CR.cancelled = true
    if Menu.isOpen() then Menu.close() end
    stop(not silent and Locale.creation_cancelled or nil)
end

-- step 1: capture doors; returns 'next' or 'cancel'
local function captureStep()
    local lastAim, lastInfo = nil, nil
    while CR and not CR.cancelled do
        Wait(0)
        DisableControlAction(0, Config.Keys.interact, true)
        local rows = {}
        for i, d in ipairs(CR.doors) do
            rows[#rows + 1] = i == 1 and T('front_door_row', d.doorname) or T('other_door_row', i - 1, d.doorname)
        end
        UI:DrawHudPanel({
            title = Locale.capture_title, rows = rows,
            footer = #CR.doors == 0 and Locale.capture_footer_first or Locale.capture_footer,
        })
        local ent = aimedEntity()
        if ent ~= lastAim then
            lastAim = ent
            lastInfo = identify(ent)
            if lastInfo then
                local p = GetEntityCoords(ent)
                label('aim', p, taken(lastInfo.hash) and T('taken_label', lastInfo.name) or T('door_label', lastInfo.name),
                    taken(lastInfo.hash) and 'lock' or 'check')
            else
                unlabel('aim')
            end
        end
        if justPressed(Config.Keys.interact) then
            if lastInfo then
                capture(lastInfo)
                lastAim = nil -- redraw the aim label (it may be TAKEN now)
            elseif ent and ent ~= 0 then
                C.tip(Locale.unknown_door, 6000)
            else
                C.tip(Locale.look_at_door)
            end
        elseif justPressed(Config.Keys.confirm) then
            if #CR.doors > 0 then
                unlabel('aim')
                unlabel('pair')
                return 'next'
            end
            C.tip(Locale.look_at_door)
        elseif justPressed(Config.Keys.back) then
            return 'cancel'
        end
    end
    return 'cancel'
end

-- step 2: nudge the prompt spot; returns 'next' or 'cancel'
local function spotStep()
    local step = 0.1
    while CR and not CR.cancelled do
        Wait(0)
        local s = CR.spot
        if justPressed(Config.Keys.up) then s.z = s.z + step
        elseif justPressed(Config.Keys.down) then s.z = s.z - step
        elseif justPressed(Config.Keys.yPlus) then s.y = s.y + step
        elseif justPressed(Config.Keys.yMinus) then s.y = s.y - step
        elseif justPressed(Config.Keys.right) then s.x = s.x + step
        elseif justPressed(Config.Keys.left) then s.x = s.x - step
        end
        UI:DrawHudPanel({ title = Locale.spot_title, rows = { T('spot_row', s.x, s.y, s.z) }, footer = Locale.spot_footer })
        if not CR.lastSpot or CR.lastSpot.x ~= s.x or CR.lastSpot.y ~= s.y or CR.lastSpot.z ~= s.z then
            CR.lastSpot = { x = s.x, y = s.y, z = s.z }
            UI:Add3DInteraction(LBL .. 'spot', { coords = vector3(s.x, s.y, s.z), text = Locale.prompt_here, icon = 'home', distance = 15.0 })
            CR.labels[LBL .. 'spot'] = true
        end
        if justPressed(Config.Keys.confirm) then return 'next' end
        if justPressed(Config.Keys.back) then return 'cancel' end
    end
    return 'cancel'
end

local function typeText()
    if CR.kind == KIND_REAL then return Locale.type_real end
    if CR.kind == KIND_MARKER then return Locale.type_marker end
    return T('type_teleporter', CR.interior)
end

-- step 3: summary menu; returns 'save', 'cancel', 'doors', 'spot' or 'esc'
local function summaryStep()
    local p = promise.new()
    local choice = nil
    local function pick(c)
        choice = c
        Menu.close()
    end
    Menu.open(function()
        local opts = {
            { label = T('type_row', typeText()) },
            { label = T('price_row', U.money(CR.price)) },
            { label = T('tax_row', U.money(CR.tax)) },
            { label = T('range_row', CR.range) },
            { label = T('space_row', CR.slots) },
        }
        if CR.kind == KIND_REAL then
            for i, d in ipairs(CR.doors) do
                opts[#opts + 1] = { label = i == 1 and T('front_door_row', d.doorname) or T('other_door_row', i - 1, d.doorname) }
            end
            opts[#opts + 1] = { label = Locale.add_doors, select = function() pick('doors') end }
        end
        opts[#opts + 1] = { label = Locale.move_spot, select = function() pick('spot') end }
        opts[#opts + 1] = { label = Locale.save_house, select = function()
            Menu.confirm(Locale.save_house, Locale.are_you_sure, function() pick('save') end)
        end }
        opts[#opts + 1] = { label = Locale.cancel, select = function()
            Menu.confirm(Locale.cancel, Locale.are_you_sure, function() pick('cancel') end)
        end }
        local sub = CR.kind == KIND_REAL and T('doors_captured', #CR.doors) or typeText()
        return { title = Locale.create_menu, subtitle = sub, options = opts }
    end, function() p:resolve(choice or 'esc') end)
    return Citizen.Await(p)
end

local function save()
    local data = { kind = CR.kind, price = CR.price, tax = CR.tax, range = CR.range, slots = CR.slots }
    if CR.kind == KIND_REAL then
        local front = CR.doors[1]
        front.o, front.p, front.q = CR.spot.x, CR.spot.y, CR.spot.z
        data.doors = { front }
        data.other = {}
        for i = 2, #CR.doors do
            local d = CR.doors[i]
            d.secondarydoorid = i - 1
            data.other[#data.other + 1] = d
        end
    else
        data.doors = { { x = CR.spot.x, y = CR.spot.y, z = CR.spot.z } }
        data.other = CR.kind == KIND_TELE and { CR.interior } or {}
    end
    Send('sv_create', data)
end

local function run()
    local fields = {
        { label = Locale.form_price, type = 'number', min = 1, required = true },
        { label = Locale.form_tax, type = 'number', default = 0, min = 0 },
        { label = Locale.form_range, type = 'number', default = 20, min = 0 },
        { label = Locale.form_slots, type = 'number', min = 1, required = true },
    }
    local types = { { label = Locale.type_real, value = 'real' }, { label = Locale.type_marker, value = 'marker' } }
    local names = {}
    for name in pairs(Config.Interiors) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do types[#types + 1] = { label = T('type_teleporter', name), value = 'tele:' .. name } end
    fields[#fields + 1] = { label = Locale.form_type, type = 'select', default = 'real', options = types }

    local v = Ask(Locale.create_menu, fields)
    if not CR or CR.cancelled then return end
    if not v then return stop(Locale.creation_cancelled) end
    local price, tax, range, slots = U.int(v[1]), U.int(v[2]) or 0, U.int(v[3]), U.int(v[4])
    if not price or not slots or price <= 0 or slots <= 0 or tax < 0 then return stop(Locale.invalid_values) end
    if not range or range < 0 then range = 20 end
    CR.price, CR.tax, CR.range, CR.slots = price, tax, range, slots
    local kind = tostring(v[5] or 'real')
    if kind == 'real' then
        CR.kind = KIND_REAL
    elseif kind == 'marker' then
        CR.kind = KIND_MARKER
    else
        local name = kind:match('^tele:(.+)$')
        if not name or not Config.Interiors[name] then return stop(Locale.invalid_values) end
        CR.kind, CR.interior = KIND_TELE, name
    end

    local state = CR.kind == KIND_REAL and 'doors' or 'spot'
    if CR.kind ~= KIND_REAL then
        local p = C.pos()
        CR.spot = { x = p.x, y = p.y, z = p.z }
    end
    while CR and not CR.cancelled do
        if state == 'doors' then
            if captureStep() ~= 'next' then return stop(Locale.creation_cancelled) end
            local f = CR.doors[1]
            if not CR.spot then CR.spot = { x = f.o, y = f.p, z = f.q } end
            state = 'spot'
        elseif state == 'spot' then
            if spotStep() ~= 'next' then return stop(Locale.creation_cancelled) end
            state = 'summary'
        elseif state == 'summary' then
            local choice = summaryStep()
            if not CR or CR.cancelled then return end
            if choice == 'save' then
                save()
                return stop(nil)
            elseif choice == 'cancel' then
                return stop(Locale.creation_cancelled)
            elseif choice == 'doors' then
                state = 'doors'
            elseif choice == 'spot' then
                state = 'spot'
            else
                C.tip(Locale.creation_still, 6000)
                state = 'spot'
            end
        end
    end
end

AddEventHandler('pup_realestate:openCreation', function()
    if CR then return C.cancelCreator(false) end
    if not C.charid then return end
    if Menu.isOpen() then Menu.close() end
    CR = { doors = {}, labels = {} }
    C.creating = true
    CreateThread(function()
        local ok, err = pcall(run)
        if not ok then
            print('^1[pup_realestate]^7 creator: ' .. tostring(err))
            if CR then stop(Locale.creation_cancelled) end
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if CR then clearLabels() end
end)
