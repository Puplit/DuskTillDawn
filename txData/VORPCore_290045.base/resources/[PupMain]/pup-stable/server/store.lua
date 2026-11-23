-- pup-stable | in-memory copy of every horse, component and wagon, and the writes that keep the
-- database in step. The memory copy is authoritative while the resource runs.

Horses, Comps, Wagons = {}, {}, {}
CharHorses, CharComps, CharWagons = {}, {}, {}

local STAT_COLS = { 'distance', 'lastNewShoes', 'bonding', 'stamina', 'health', 'xp', 'speedXP', 'accelerationXP', 'handlingXP', 'focus', 'healthCore', 'staminaCore', 'pedStamina', 'restedAt' }
local HORSE_COLS = { stable = true, name = true, speed = true, acceleration = true, handling = true, favourite = true, isDead = true, isOut = true, scale = true, bred = true, identifier = true, charid = true }
local WAGON_COLS = { stable = true, name = true, isOut = true, identifier = true, charid = true, vehicle_tints = true, vehicle_propsets = true, vehicle_liveries = true, vehicle_lantern_propsets = true, vehicle_extras = true }

local function idx(map, charid)
    map[charid] = map[charid] or {}
    return map[charid]
end

local function b(v) return v == true or v == 1 or v == '1' end

------------------------------------------------------------------------------
-- rows -> memory
------------------------------------------------------------------------------
function HorseFromRow(r)
    local h = {
        id = U.int(r.id), identifier = r.identifier, charid = U.int(r.charid), stable = r.stable, model = r.model,
        isFemale = b(r.isFemale), name = r.name or '', speed = U.int(r.speed, 1), acceleration = U.int(r.acceleration, 1),
        handling = U.int(r.handling, 1), favourite = b(r.favourite), isDead = b(r.isDead), isOut = b(r.isOut),
        baseSpeed = U.int(r.baseSpeed), baseAcceleration = U.int(r.baseAcceleration), baseHandling = U.int(r.baseHandling),
        scale = U.num(r.scale, 1.0), bred = b(r.bred),
        st = {},
    }
    for _, c in ipairs(STAT_COLS) do
        if c == 'focus' then h.st.focus = (type(r.focus) == 'string' and U.FOCUS[r.focus]) and r.focus or ''
        else h.st[c] = U.int(r[c], (c == 'healthCore' or c == 'staminaCore') and 100 or 0) end
    end
    return h
end

function AddHorse(h)
    Horses[h.id] = h
    idx(CharHorses, h.charid)[h.id] = true
end

function DropHorse(h)
    Horses[h.id] = nil
    if CharHorses[h.charid] then CharHorses[h.charid][h.id] = nil end
end

function AddComp(c)
    Comps[c.id] = c
    idx(CharComps, c.charid)[c.id] = true
end

function DropComp(c)
    Comps[c.id] = nil
    if CharComps[c.charid] then CharComps[c.charid][c.id] = nil end
end

function WagonFromRow(r)
    return {
        id = U.int(r.id), identifier = r.identifier, charid = U.int(r.charid), stable = r.stable, model = r.model,
        name = r.name or '', isOut = b(r.isOut),
        vehicle_tints = U.int(r.vehicle_tints, -2), vehicle_propsets = tostring(r.vehicle_propsets or '-1'),
        vehicle_liveries = U.int(r.vehicle_liveries, -1), vehicle_lantern_propsets = tostring(r.vehicle_lantern_propsets or '-1'),
        vehicle_extras = U.int(r.vehicle_extras, -1),
    }
end

function AddWagon(w)
    Wagons[w.id] = w
    idx(CharWagons, w.charid)[w.id] = true
end

function DropWagon(w)
    Wagons[w.id] = nil
    if CharWagons[w.charid] then CharWagons[w.charid][w.id] = nil end
end

function LoadAll()
    Horses, Comps, Wagons, CharHorses, CharComps, CharWagons = {}, {}, {}, {}, {}, {}
    local rows = MySQL.query.await([[SELECT h.*, s.distance, s.lastNewShoes, s.bonding, s.stamina, s.health, s.xp, s.speedXP,
        s.accelerationXP, s.handlingXP, s.focus, s.healthCore, s.staminaCore, s.pedStamina, s.restedAt
        FROM stable_horses h LEFT JOIN stable_horse_stats s ON s.horseid = h.id]]) or {}
    for _, r in ipairs(rows) do AddHorse(HorseFromRow(r)) end
    local comps = MySQL.query.await([[SELECT b.*, c.drawable, c.albedo, c.normal, c.material, c.palette, c.tint0, c.tint1, c.tint2,
        c.id AS colorId FROM stable_bought b LEFT JOIN stable_color c ON c.id = b.id]]) or {}
    for _, r in ipairs(comps) do
        local c = { id = U.int(r.id), identifier = r.identifier, charid = U.int(r.charid), category = r.category, hash = U.s32(r.hash), on = U.int(r.equiped_on, 0) }
        if r.colorId then
            c.color = { drawable = U.int(r.drawable), albedo = U.int(r.albedo), normal = U.int(r.normal), material = U.int(r.material),
                palette = r.palette, tint0 = U.int(r.tint0, 0), tint1 = U.int(r.tint1, 0), tint2 = U.int(r.tint2, 0) }
        end
        AddComp(c)
    end
    local wagons = MySQL.query.await('SELECT * FROM stable_wagons') or {}
    for _, r in ipairs(wagons) do AddWagon(WagonFromRow(r)) end
    local nh, nc, nw = 0, 0, 0
    for _ in pairs(Horses) do nh = nh + 1 end
    for _ in pairs(Comps) do nc = nc + 1 end
    for _ in pairs(Wagons) do nw = nw + 1 end
    print(('[pup-stable] loaded %d horses, %d components, %d wagons'):format(nh, nc, nw))
end

------------------------------------------------------------------------------
-- ownership
------------------------------------------------------------------------------
function OwnedHorse(ctx, id)
    local h = Horses[U.int(id, -1)]
    if h and ctx and h.charid == ctx.charid and h.identifier == ctx.identifier then return h end
    return nil
end

function OwnedWagon(ctx, id)
    local w = Wagons[U.int(id, -1)]
    if w and ctx and w.charid == ctx.charid and w.identifier == ctx.identifier then return w end
    return nil
end

function OwnedComp(ctx, id)
    local c = Comps[U.int(id, -1)]
    if c and ctx and c.charid == ctx.charid and c.identifier == ctx.identifier then return c end
    return nil
end

function HorsesOf(charid)
    local out = {}
    for id in pairs(CharHorses[charid] or {}) do if Horses[id] then out[#out + 1] = Horses[id] end end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end

function WagonsOf(charid)
    local out = {}
    for id in pairs(CharWagons[charid] or {}) do if Wagons[id] then out[#out + 1] = Wagons[id] end end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end

function CompsOf(charid)
    local out = {}
    for id in pairs(CharComps[charid] or {}) do if Comps[id] then out[#out + 1] = Comps[id] end end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end

-- components equipped on a horse (unique look slots and tack)
function HorseComps(h)
    local out = {}
    for id in pairs(CharComps[h.charid] or {}) do
        local c = Comps[id]
        if c and c.on == h.id then out[#out + 1] = c end
    end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end

function HorseCompOf(h, category)
    for _, c in ipairs(HorseComps(h)) do if c.category == category then return c end end
    return nil
end

function FavouriteOf(charid)
    for id in pairs(CharHorses[charid] or {}) do
        local h = Horses[id]
        if h and h.favourite then return h end
    end
    return nil
end

function BreedOfModel(model)
    local hit = Config.BreedByModel[tostring(model or ''):lower()]
    if not hit then return nil end
    local br = Config.BreedById[hit.breed]
    return br, br and br.coats[hit.coat], hit.coat
end

function WagonDef(model)
    local hit = Config.WagonByModel[tostring(model or ''):lower()]
    if not hit then return nil end
    local cat = Config.WagonCategoryById[hit.cat]
    return cat and cat.wagons[hit.index], cat
end

function WagonLabel(w)
    if w.name and w.name ~= '' then return w.name end
    return Config.WagonDefaultNames[tostring(w.model):lower()] or w.model
end

------------------------------------------------------------------------------
-- writes
------------------------------------------------------------------------------
local function val(v)
    if v == true then return 1 elseif v == false then return 0 end
    return v
end

function SaveHorse(h, ...)
    local sets, params = {}, {}
    for _, col in ipairs({ ... }) do
        if HORSE_COLS[col] then
            sets[#sets + 1] = ('`%s` = ?'):format(col)
            params[#params + 1] = val(h[col])
        end
    end
    if #sets == 0 then return end
    params[#params + 1] = h.id
    MySQL.update(('UPDATE stable_horses SET %s WHERE id = ?'):format(table.concat(sets, ', ')), params)
end

function SaveWagon(w, ...)
    local sets, params = {}, {}
    for _, col in ipairs({ ... }) do
        if WAGON_COLS[col] then
            sets[#sets + 1] = ('`%s` = ?'):format(col)
            params[#params + 1] = val(w[col])
        end
    end
    if #sets == 0 then return end
    params[#params + 1] = w.id
    MySQL.update(('UPDATE stable_wagons SET %s WHERE id = ?'):format(table.concat(sets, ', ')), params)
end

function SaveStats(h, await)
    local sets, params = {}, {}
    for _, c in ipairs(STAT_COLS) do
        sets[#sets + 1] = ('`%s` = ?'):format(c)
        params[#params + 1] = h.st[c]
    end
    params[#params + 1] = h.id
    local sql = ('UPDATE stable_horse_stats SET %s WHERE horseid = ?'):format(table.concat(sets, ', '))
    h.statsDirty = nil
    if await then pcall(MySQL.update.await, sql, params) else MySQL.update(sql, params) end
end

function SaveAllStats(await)
    for _, h in pairs(Horses) do
        if h.statsDirty then SaveStats(h, await) end
    end
end

function MarkStats(h) h.statsDirty = true end

-- create a horse; data = { identifier, charid, stable, model, isFemale, name, speed, acceleration, handling,
-- favourite, base*, scale, bred, bonding, health, stamina }
function CreateHorse(data)
    local id = MySQL.insert.await([[INSERT INTO stable_horses (identifier, charid, stable, model, isFemale, name, speed, acceleration,
        handling, favourite, isDead, isOut, baseSpeed, baseAcceleration, baseHandling, scale, bred)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?)]], {
        data.identifier, data.charid, data.stable, data.model, data.isFemale and 1 or 0, data.name, data.speed, data.acceleration,
        data.handling, data.favourite and 1 or 0, data.baseSpeed or data.speed, data.baseAcceleration or data.acceleration,
        data.baseHandling or data.handling, data.scale or 1.0, data.bred and 1 or 0 })
    id = U.int(id)
    if not id or id <= 0 then return nil end
    -- the trigger made the stats row; make sure of it and fill the starting points
    MySQL.insert.await('INSERT IGNORE INTO stable_horse_stats (horseid) VALUES (?)', { id })
    MySQL.update.await('UPDATE stable_horse_stats SET bonding = ?, health = ?, stamina = ?, xp = ? WHERE horseid = ?',
        { data.bonding or 0, data.health or 0, data.stamina or 0, data.bonding or 0, id })
    local h = HorseFromRow({
        id = id, identifier = data.identifier, charid = data.charid, stable = data.stable, model = data.model, isFemale = data.isFemale,
        name = data.name, speed = data.speed, acceleration = data.acceleration, handling = data.handling, favourite = data.favourite,
        isDead = false, isOut = false, baseSpeed = data.baseSpeed or data.speed, baseAcceleration = data.baseAcceleration or data.acceleration,
        baseHandling = data.baseHandling or data.handling, scale = data.scale or 1.0, bred = data.bred,
        bonding = data.bonding or 0, health = data.health or 0, stamina = data.stamina or 0, xp = data.bonding or 0,
        healthCore = 100, staminaCore = 100,
    })
    AddHorse(h)
    return h
end

-- add a component row (and its colour); returns the component
function CreateComp(owner, category, hash, on, color)
    local id = MySQL.insert.await('INSERT INTO stable_bought (identifier, charid, category, hash, equiped_on) VALUES (?, ?, ?, ?, ?)',
        { owner.identifier, owner.charid, category, U.s32(hash), on or 0 })
    id = U.int(id)
    if not id or id <= 0 then return nil end
    local c = { id = id, identifier = owner.identifier, charid = owner.charid, category = category, hash = U.s32(hash), on = on or 0 }
    if color then
        SetCompColor(c, color, true)
    end
    AddComp(c)
    return c
end

function SetCompColor(c, color, await)
    c.color = {
        drawable = U.int(color.drawable), albedo = U.int(color.albedo), normal = U.int(color.normal), material = U.int(color.material),
        palette = color.palette and U.cut(tostring(color.palette), 100) or nil,
        tint0 = U.clamp(U.int(color.tint0, 0), 0, 255), tint1 = U.clamp(U.int(color.tint1, 0), 0, 255), tint2 = U.clamp(U.int(color.tint2, 0), 0, 255),
    }
    local sql = [[INSERT INTO stable_color (id, drawable, albedo, normal, material, palette, tint0, tint1, tint2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE drawable = VALUES(drawable), albedo = VALUES(albedo), normal = VALUES(normal), material = VALUES(material),
        palette = VALUES(palette), tint0 = VALUES(tint0), tint1 = VALUES(tint1), tint2 = VALUES(tint2)]]
    local p = { c.id, c.color.drawable, c.color.albedo, c.color.normal, c.color.material, c.color.palette, c.color.tint0, c.color.tint1, c.color.tint2 }
    if await then MySQL.insert.await(sql, p) else MySQL.insert(sql, p) end
end

function SetCompOn(c, on)
    c.on = on
    MySQL.update('UPDATE stable_bought SET equiped_on = ? WHERE id = ?', { on, c.id })
end

-- remove a horse for good: its own-look rows go, its tack goes back to storage
function DeleteHorseRow(h)
    local look = {}
    for _, c in ipairs(HorseComps(h)) do
        if U.UNIQUE[c.category] then look[#look + 1] = c.id else c.on = 0 end
    end
    if #look > 0 then
        MySQL.update.await('DELETE FROM stable_bought WHERE id IN (?)', { look })
        for _, cid in ipairs(look) do if Comps[cid] then DropComp(Comps[cid]) end end
    end
    MySQL.update.await('UPDATE stable_bought SET equiped_on = 0 WHERE equiped_on = ?', { h.id })
    MySQL.update.await('DELETE FROM stable_horses WHERE id = ?', { h.id })
    DropHorse(h)
end

function DeleteWagonRow(w)
    MySQL.update.await('DELETE FROM stable_wagons WHERE id = ?', { w.id })
    DropWagon(w)
end

------------------------------------------------------------------------------
-- what the client gets
------------------------------------------------------------------------------
function CompPayload(c)
    return { id = c.id, category = c.category, hash = c.hash, on = c.on, color = c.color }
end

function HorsePayload(h)
    local br, coat, coatIndex = BreedOfModel(h.model)
    local comps = {}
    local bagId
    for _, c in ipairs(HorseComps(h)) do
        comps[#comps + 1] = CompPayload(c)
        if c.category == 'horse_saddlebags' then bagId = c.id end
    end
    local bag = BagSize(h)
    return {
        id = h.id, name = h.name, model = h.model, isFemale = h.isFemale, stable = h.stable,
        speed = h.speed, acceleration = h.acceleration, handling = h.handling,
        baseSpeed = h.baseSpeed or h.speed, baseAcceleration = h.baseAcceleration or h.acceleration, baseHandling = h.baseHandling or h.handling,
        favourite = h.favourite, isDead = h.isDead, isOut = h.isOut, scale = h.scale, bred = h.bred,
        bonding = h.st.bonding, health = h.st.health, stamina = h.st.stamina, xp = h.st.xp, distance = h.st.distance,
        lastNewShoes = h.st.lastNewShoes, focus = h.st.focus,
        breed = br and br.id or nil, breedLabel = br and br.label or nil, coat = coatIndex, coatLabel = coat and coat.label or nil,
        comps = comps, bagId = bagId, bag = bag,
        busyUntil = TransferBusy and TransferBusy('horse', h.id) or nil,
    }
end

function WagonPayload(w)
    local def = WagonDef(w.model)
    return {
        id = w.id, name = w.name, label = WagonLabel(w), model = w.model, stable = w.stable, isOut = w.isOut,
        tint = w.vehicle_tints, propset = w.vehicle_propsets, livery = w.vehicle_liveries, lantern = w.vehicle_lantern_propsets, extra = w.vehicle_extras,
        locker = LockerSize(w), seatsHint = def and def.seatsHint, horsesHint = def and def.horsesHint,
        busyUntil = TransferBusy and TransferBusy('wagon', w.id) or nil,
    }
end

function BagSize(h)
    if h.bred then return Config.Breeding.foalBag end
    local br, coat = BreedOfModel(h.model)
    return (coat and coat.bag) or (br and br.bag) or Config.Saddlebag.default
end

function LockerSize(w)
    local def = WagonDef(w.model)
    return (def and def.locker) or Config.Locker.default
end
