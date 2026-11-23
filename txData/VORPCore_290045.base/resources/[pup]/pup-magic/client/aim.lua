-- pup-magic | aiming for the spell kit: the camera ray, the player lock and the »« marker

Aim = {
    marker = false, -- the aim marker toggle (aimdot)
    locked = nil,   -- a player index, kept while they stay in the narrow cone
}

local LOCK_LEN <const> = 250.0
local NARROW <const> = { side = 1.5, cone = 0.03 }
local WIDE <const> = { side = 4.0, cone = 0.12 }
local FADE_FRAMES <const> = 15
local RAY_RADIUS <const> = 0.35

local fade = 0
local aimPoint = nil

function Aim.camera()
    local from = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(pitch))
    return from, vector3(-math.sin(yaw) * c, math.cos(yaw) * c, math.sin(pitch))
end

local function livingOthers()
    local me = PlayerId()
    local out = {}
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local ped = GetPlayerPed(player)
            if ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then out[#out + 1] = { player = player, ped = ped } end
        end
    end
    return out
end

-- how far a point sits off the camera line, or nil when it is behind or past `len`
local function offLine(from, dir, len, p)
    local v = p - from
    local along = v.x * dir.x + v.y * dir.y + v.z * dir.z
    if along <= 0 or along > len then return nil end
    local side = #(v - dir * along)
    return side, along
end

local function fits(side, along, shape)
    return side <= math.max(shape.side, along * math.tan(shape.cone))
end

-- the player closest to the camera line inside `shape`, as { player, ped } or nil
function Aim.playerInCone(from, dir, len, shape)
    local best, bestScore = nil, nil
    for _, o in ipairs(livingOthers()) do
        local side, along = offLine(from, dir, len, ChestOf(o.ped))
        if side and fits(side, along, shape) then
            local score = side / along
            if not bestScore or score < bestScore then best, bestScore = o, score end
        end
    end
    return best
end

local function playerInShape(player, from, dir, len, shape)
    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    local side, along = offLine(from, dir, len, ChestOf(ped))
    return side ~= nil and fits(side, along, shape)
end

function Aim.nearestPlayerTo(point, maxDist)
    local best, bestD = nil, nil
    for _, o in ipairs(livingOthers()) do
        local d = #(GetEntityCoords(o.ped) - point)
        if d <= maxDist and (not bestD or d < bestD) then best, bestD = o, d end
    end
    return best
end

-- the camera ray: a capsule test against everything but me.
-- Returns hit point, hit entity (0 for none) and whether anything was hit at all.
function Aim.ray(len)
    local from, dir = Aim.camera()
    local to = from + dir * len
    local me = PlayerPedId()
    -- the capsule native is not used anywhere else on this server: fall back to a plain ray if it is missing
    local okCap, handle = pcall(StartShapeTestCapsule, from.x, from.y, from.z, to.x, to.y, to.z, RAY_RADIUS, 511, me, 7)
    if not okCap or not handle then
        WarnOnce('aim.capsule', 'capsule shape test unavailable, using a plain ray')
        handle = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 511, me, 7)
    end
    local state, hit, coords, normal, entity
    for _ = 1, 5 do
        state, hit, coords, normal, entity = GetShapeTestResult(handle)
        if state ~= 1 then break end
        Wait(0)
    end
    if state == 2 and (hit == 1 or hit == true) and normal then
        if entity and entity ~= 0 and DoesEntityExist(entity) then return coords, entity, true end
        local snap = Aim.nearestPlayerTo(coords, 1.0)
        return coords, snap and snap.ped or 0, true
    end
    -- nothing hit: walk the ray every 3 m looking for ground
    for d = 3.0, len, 3.0 do
        local p = from + dir * d
        local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z, false)
        if found and gz and p.z <= gz + 0.5 then return vector3(p.x, p.y, gz), 0, false end
    end
    local myZ = GetEntityCoords(me).z
    return vector3(to.x, to.y, myZ), 0, false
end

local function isLivingOtherPlayerPed(ent)
    return ent and ent ~= 0 and DoesEntityExist(ent) and IsEntityAPed(ent) and IsPedAPlayer(ent)
        and ent ~= PlayerPedId() and not IsEntityDead(ent)
end

-- the spell target: locked player, else the ped the ray hit (players only), else the narrow cone,
-- else (with nearHit) the nearest player within that many metres of the hit point.
-- Returns target ped (or nil), aim point, server id (or nil)
function Aim.pick(len, nearHit)
    local point, ent = Aim.ray(len)
    local ped

    if Aim.locked then
        local lp = GetPlayerPed(Aim.locked)
        if lp ~= 0 and DoesEntityExist(lp) and not IsEntityDead(lp) then ped = lp end
    end
    if not ped and isLivingOtherPlayerPed(ent) then ped = ent end
    if not ped then
        local from, dir = Aim.camera()
        local o = Aim.playerInCone(from, dir, len, NARROW)
        if o then ped = o.ped end
    end
    if not ped and nearHit then
        local o = Aim.nearestPlayerTo(point, nearHit)
        if o then ped = o.ped end
    end

    if ped then return ped, ChestOf(ped), ServerIdOfPed(ped) end
    return nil, point, nil
end

function Aim.lockedServerId()
    if not Aim.locked then return nil end
    local ped = GetPlayerPed(Aim.locked)
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then return nil end
    return ServerIdOfPed(ped)
end

local function updateLock()
    local from, dir = Aim.camera()
    if Aim.locked and playerInShape(Aim.locked, from, dir, LOCK_LEN, NARROW) then
        fade = FADE_FRAMES
    else
        local o = Aim.playerInCone(from, dir, LOCK_LEN, NARROW) or Aim.playerInCone(from, dir, LOCK_LEN, WIDE)
        if o then
            Aim.locked, fade = o.player, FADE_FRAMES
        elseif Aim.locked then
            fade = fade - 1
            if fade <= 0 then Aim.locked = nil end
        end
    end

    -- where the marker sits when nobody is locked
    local point, ent = Aim.ray(LOCK_LEN)
    if ent ~= 0 and IsEntityAPed(ent) then point = ChestOf(ent) end
    local o = Aim.playerInCone(from, dir, LOCK_LEN, NARROW)
    if o then point = ChestOf(o.ped) end
    aimPoint = point
end

local function drawMarker(p, locked)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(p.x, p.y, p.z + 0.10)
    if not onScreen then return end
    SetTextScale(0.45, 0.45)
    if locked then SetTextColor(220, 40, 40, 255) else SetTextColor(255, 255, 255, 255) end
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', Locale.aimMarker), sx, sy)
end

-- the lock: the shape test can take a few frames, so it runs apart from the drawing
CreateThread(function()
    while true do
        if not Aim.marker then
            aimPoint = nil
            Wait(250)
        else
            updateLock()
            Wait(0)
        end
    end
end)

-- the marker is text, so it is drawn every frame from the last lock result
CreateThread(function()
    while true do
        if not Aim.marker then
            Wait(250)
        else
            local lp = Aim.locked and GetPlayerPed(Aim.locked) or 0
            if lp ~= 0 and DoesEntityExist(lp) then
                drawMarker(ChestOf(lp), true)
            elseif aimPoint then
                drawMarker(aimPoint, false)
            end
            Wait(0)
        end
    end
end)
