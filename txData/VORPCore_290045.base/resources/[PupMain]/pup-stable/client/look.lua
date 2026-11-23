-- pup-stable | how a horse or wagon looks: components, colours, height, stats; spawning

Look = {}

-- horse sex expression (face feature index and the two values)
local SEX_FEATURE, MALE_V, FEMALE_V = 41611, 0.0, 1.0

local HAIR = { horse_manes = true, horse_tails = true, horse_mustache = true }

-- the index on the ped currently wearing a catalogue entry of `category`
local function indexOfCategory(ped, category)
    for i = 0, (N.numComps(ped) or 0) - 1 do
        local h = N.compAt(ped, i)
        if h and h ~= 0 and U.catalogueIndex(category, h) then return i end
    end
    return nil
end

local function indexOfHash(ped, hash)
    local want = U.u32(hash)
    for i = 0, (N.numComps(ped) or 0) - 1 do
        local h = N.compAt(ped, i)
        if h and U.u32(h) == want then return i end
    end
    return nil
end

-- coat parts: the first two components that are not catalogue tack or hair (head, then body)
local function coatIndices(ped)
    local out = {}
    for i = 0, (N.numComps(ped) or 0) - 1 do
        local h = N.compAt(ped, i)
        local known = false
        for cat in pairs(HorseComponents) do
            if U.catalogueIndex(cat, h) then known = true break end
        end
        if not known then out[#out + 1] = i end
        if #out >= 2 then break end
    end
    return out
end

local function paint(ped, index, color)
    if not index or type(color) ~= 'table' or not color.palette or color.palette == '' then return end
    local d, a, n, m = N.guids(ped, index)
    d = color.drawable or d
    a = color.albedo or a
    n = color.normal or n
    m = color.material or m
    N.setTag(ped, d, a, n, m, joaat(color.palette), color.tint0 or 0, color.tint1 or 0, color.tint2 or 0)
end

function Look.removeComp(ped, hash)
    local cat = N.compCategory(hash, N.metaType(ped))
    if cat and cat ~= 0 then N.removeTag(ped, cat) end
end

function Look.applyComp(ped, c)
    if c.category == 'horse_outfits' then
        N.outfit(ped, c.hash)
        return
    end
    if c.hash and c.hash ~= 0 then N.applyComp(ped, c.hash) end
end

-- coat colour: match by stored drawable, else head/body by position
local function paintCoat(ped, comps)
    local head, body
    for _, c in ipairs(comps) do
        if c.category == 'horse_heads' then head = c elseif c.category == 'horse_bodies' then body = c end
    end
    if not head and not body then return end
    local idx = coatIndices(ped)
    for _, c in ipairs({ head, body }) do
        if c and c.color then
            local target = nil
            if c.color.drawable then
                for _, i in ipairs(idx) do
                    local d = N.guids(ped, i)
                    if d == c.color.drawable then target = i end
                end
            end
            target = target or (c == head and idx[1] or idx[2])
            paint(ped, target, c.color)
        end
    end
end

-- dress a horse ped from its component list (rows from the server)
function Look.dress(ped, comps, withTack)
    if not DoesEntityExist(ped) then return end
    comps = comps or {}
    for _, c in ipairs(comps) do
        if (U.UNIQUE[c.category] and c.hash ~= 0) or (withTack and U.TACK_SET[c.category]) then Look.applyComp(ped, c) end
    end
    N.update(ped)
    Wait(50)
    for _, c in ipairs(comps) do
        if c.color and c.category ~= 'horse_heads' and c.category ~= 'horse_bodies' then
            local i = (c.hash ~= 0) and indexOfHash(ped, c.hash) or (HAIR[c.category] and indexOfCategory(ped, c.category))
            if i then paint(ped, i, c.color) end
        end
    end
    paintCoat(ped, comps)
    N.update(ped)
end

-- strip tack that is not part of the horse's own look
function Look.stripTack(ped, comps)
    for _, c in ipairs(comps or {}) do
        if U.TACK_SET[c.category] and c.hash ~= 0 and c.category ~= 'horse_outfits' then Look.removeComp(ped, c.hash) end
    end
    N.update(ped)
end

function Look.sex(ped, female) N.faceFeature(ped, SEX_FEATURE, female and FEMALE_V or MALE_V) end

-- stats published on the entity -> the ped
function Look.applyStats(ped, st)
    if type(st) ~= 'table' or not DoesEntityExist(ped) then return end
    local A = N.ATTR
    N.setPoints(ped, A.health, U.int(st.health, 0))
    N.setPoints(ped, A.stamina, U.int(st.stamina, 0))
    N.setPoints(ped, A.bonding, U.int(st.bonding, 0))
    N.setPoints(ped, A.courage, U.int(st.bonding, 0))
    if st.speed then N.setBaseRank(ped, A.speed, st.speed) end
    if st.acceleration then N.setBaseRank(ped, A.acceleration, st.acceleration) end
    if st.handling then N.setBaseRank(ped, A.handling, U.HANDLING_RANK[U.clamp(st.handling, 1, 4)] or 1) end
end

-- base rank, else the current rank (a fresh ped can report 0 for a few frames)
local function rankOf(ped, a)
    local r = U.int(N.baseRank(ped, a), 0)
    if r <= 0 then r = U.int(N.rank(ped, a), 0) end
    return r
end

-- read a ped's native stats (preview horses, wild horses, parents).
-- waitMs > 0 polls until speed and acceleration read non-zero. Returns stats, ready.
-- health/stamina/bonding are training points (what a bought horse starts with);
-- healthRank/staminaRank are the breed's own ranks (0..10) for the shop card.
function Look.readStats(ped, waitMs)
    local A = N.ATTR
    local deadline = GetGameTimer() + (waitMs or 0)
    local ready = false
    while true do
        if not DoesEntityExist(ped) then break end
        ready = rankOf(ped, A.speed) > 0 and rankOf(ped, A.acceleration) > 0
        if ready or GetGameTimer() >= deadline then break end
        Wait(100)
    end
    local hr = rankOf(ped, A.handling)
    local level = 1
    for i, r in ipairs(U.HANDLING_RANK) do if hr >= r then level = i end end
    return {
        speed = U.clamp(rankOf(ped, A.speed), 1, 10), acceleration = U.clamp(rankOf(ped, A.acceleration), 1, 10),
        handling = level, health = N.points(ped, A.health) or 0, stamina = N.points(ped, A.stamina) or 0, bonding = N.points(ped, A.bonding) or 0,
        healthRank = U.clamp(rankOf(ped, A.health), 0, 10), staminaRank = U.clamp(rankOf(ped, A.stamina), 0, 10),
    }, ready
end

-- the non-coat look of a preview ped
function Look.readLook(ped)
    local out = {}
    for key, cat in pairs({ mane = 'horse_manes', tail = 'horse_tails', mustache = 'horse_mustache', shoes = 'horse_shoes' }) do
        local i = indexOfCategory(ped, cat)
        if i then out[key] = N.compAt(ped, i) end
    end
    return out
end

-- guids of head and body (for a custom coat)
function Look.coatGuids(ped)
    local idx = coatIndices(ped)
    local function g(i)
        if not i then return nil end
        local d, a, n, m = N.guids(ped, i)
        return { drawable = d, albedo = a, normal = n, material = m }
    end
    return g(idx[1]), g(idx[2])
end

-- live coat paint for previews (no rows yet)
function Look.paintCoat(ped, palette, t0, t1, t2, b1, b2)
    local idx = coatIndices(ped)
    if idx[1] then paint(ped, idx[1], { palette = palette, tint0 = t0, tint1 = t1, tint2 = t2 }) end
    if idx[2] then paint(ped, idx[2], { palette = palette, tint0 = t0, tint1 = b1 or t1, tint2 = b2 or t2 }) end
    N.update(ped)
end

function Look.paintHair(ped, palette, t0, t1, t2)
    for _, cat in ipairs({ 'horse_manes', 'horse_tails' }) do
        local i = indexOfCategory(ped, cat)
        if i then paint(ped, i, { palette = palette, tint0 = t0, tint1 = t1, tint2 = t2 }) end
    end
    N.update(ped)
end

function Look.paintIndexOf(ped, hash, palette, t0, t1, t2)
    local i = indexOfHash(ped, hash)
    if i then paint(ped, i, { palette = palette, tint0 = t0, tint1 = t1, tint2 = t2 }) N.update(ped) end
    return i ~= nil
end

------------------------------------------------------------------------------
-- spawning
------------------------------------------------------------------------------
local function ground(x, y, z)
    for _, dz in ipairs({ 0.0, 5.0, 25.0, 100.0 }) do
        local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + dz, false)
        if ok and gz ~= 0.0 then return gz end
    end
    return z
end
Look.ground = ground

-- generic horse spawn; row = a horse from getMyHorses
function Look.spawnHorse(row, loc, fixLocation, withComponents, networked)
    if type(row) ~= 'table' or not row.model then return nil end
    local hash = LoadModel(row.model)
    if not hash then return nil end
    local x, y, z, hdg = loc.x, loc.y, loc.z, loc.w or 0.0
    if fixLocation ~= false then z = ground(x, y, z) end
    local ped = CreatePed(hash, x, y, z, hdg, networked ~= false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- outfit variation so the ped is drawn
    if fixLocation ~= false then PlaceEntityOnGroundProperly(ped, true) end
    Look.sex(ped, row.isFemale)
    if row.scale and math.abs(row.scale - 1.0) > 0.001 then N.scale(ped, row.scale) end
    if withComponents ~= false then Look.dress(ped, row.comps, true) else Look.dress(ped, row.comps, false) end
    N.promptName(ped, row.name or '')
    Look.applyStats(ped, row)
    if networked ~= false then
        local net = NetIdOf(ped)
        if net then
            SetNetworkIdExistsOnAllMachines(net, true)
            local ok, cores = Call('horseOut', row.id, net)
            if not ok then
                -- refused (dead, still on its way, not yours): leave no untracked horse behind
                if type(cores) == 'string' then Tip(cores) end
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
                return nil
            end
            if type(cores) == 'table' then Cores.apply(ped, cores) end
            row.isOut = true
        end
    end
    return ped
end

exports('SpawnHorse', function(horseRow, location, fixLocation, withComponents, networked)
    local ok, ped = pcall(Look.spawnHorse, horseRow, location, fixLocation, withComponents, networked)
    if ok and ped and ped ~= 0 then
        if networked ~= false then Horse.adopt(horseRow, ped) end
        return ped
    end
    return nil
end)

function Look.wagon(veh, row)
    local model = tostring(row.model or ''):lower()
    if row.tint and row.tint >= 0 then N.vehTint(veh, row.tint) end
    if row.livery and row.livery >= 0 then N.vehLivery(veh, row.livery) end
    if row.propset and row.propset ~= '-1' and row.propset ~= '0' then N.vehPropset(veh, joaat(row.propset)) end
    if row.lantern and row.lantern ~= '-1' then N.vehLanternPropset(veh, joaat(row.lantern)) end
    if row.extra and row.extra >= 0 then
        for e = 0, 15 do if DoesExtraExist(veh, e) then N.vehExtra(veh, e, e == row.extra) end end
    end
    if not Config.Wagon.canBeDamaged then
        SetEntityInvincible(veh, true)
        SetVehicleCanBreak(veh, false)
    end
    Debug('wagon look', model)
end

function Look.spawnWagon(row, loc, fixLocation, networked)
    if type(row) ~= 'table' or not row.model then return nil end
    local hash = LoadModel(row.model)
    if not hash then return nil end
    local z = loc.z
    if fixLocation ~= false then z = ground(loc.x, loc.y, loc.z) end
    local veh = CreateVehicle(hash, loc.x, loc.y, z, loc.w or 0.0, networked ~= false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then return nil end
    if fixLocation ~= false then SetVehicleOnGroundProperly(veh) end
    Look.wagon(veh, row)
    if networked ~= false then
        local net = NetIdOf(veh)
        if net then
            SetNetworkIdExistsOnAllMachines(net, true)
            if not Call('wagonOut', row.id, net) then
                -- refused by the server: no untagged wagon left in the world
                SetEntityAsMissionEntity(veh, true, true)
                DeleteEntity(veh)
                return nil
            end
        end
    end
    return veh
end

exports('SpawnWagon', function(wagonRow, location, fixLocation, networked)
    local ok, veh = pcall(Look.spawnWagon, wagonRow, location, fixLocation, networked)
    if ok and veh and veh ~= 0 then
        if networked ~= false then Wagon.adopt(wagonRow, veh) end
        return veh
    end
    return nil
end)
