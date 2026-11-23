-- Modified by Puppet (Dusk Till Dawn), 2026
---@diagnostic disable: undefined-global
-- the creator's location, derived rather than hardcoded

local function scene()
    local c = Config and Config.Creator.scene
    if type(c) ~= 'table' or not c.enabled or type(c.spawn) ~= 'table' then return nil end
    return c
end

function CreatorSceneActive()
    return scene() ~= nil
end

function CreatorSceneGet()
    return scene()
end

-- heading -> unit vectors on the ground plane
local function axes(heading)
    local r <const> = math.rad(tonumber(heading) or 0.0)
    local fx, fy = -math.sin(r), math.cos(r)
    return fx, fy, fy, -fx -- forward x/y, then right x/y (forward rotated 90)
end

-- where the player stands
function CreatorSceneSpawn()
    local c = scene()
    if not c then return nil end
    local s = c.spawn
    return s.x + 0.0, s.y + 0.0, s.z + 0.0, (tonumber(s.heading) or 0.0) + 0.0
end

-- camera position in front of the ped, and the rotation that looks back at it
function CreatorSceneCam(dist, height, lateral)
    local c = scene()
    if not c then return nil end
    local x, y, z, h = CreatorSceneSpawn()
    local fx, fy, rx, ry = axes(h)
    dist = tonumber(dist) or tonumber(c.camDistance) or 2.4
    height = tonumber(height) or tonumber(c.camHeight) or 1.2
    lateral = tonumber(lateral) or 0.0

    -- the camera looks back down the ped's facing, so its heading is turned 180
    local camHeading <const> = ((tonumber(h) or 0.0) + 180.0) % 360.0
    return {
        x = x + fx * dist + rx * lateral,
        y = y + fy * dist + ry * lateral,
        z = z + height,
        rotx = tonumber(c.camPitch) or -4.5,
        roty = 0.0,
        rotz = camHeading,
    }
end

-- gender-selection views, in the order SelectionPeds returns the peds: 1 right, 2 left
function CreatorSceneView(index)
    local c = scene()
    if not c then return nil end
    local side <const> = (index == 2) and -1 or 1
    local v <const> = CreatorSceneCam(nil, nil, side * (tonumber(c.pedSpacing) or 0.75))
    -- same shape as Config.Intro.views, which is what the caller indexes
    return {
        pos = vector3(v.x, v.y, v.z),
        rot = vector3(v.rotx, v.roty, v.rotz),
        fov = tonumber(c.fovIntro) or 45.0,
        focus = 4.0,
    }
end

-- the two gender-selection peds: left and right of centre, facing the camera
function CreatorScenePeds()
    local c = scene()
    if not c then return nil end
    local x, y, z, h = CreatorSceneSpawn()
    local fx, fy, rx, ry = axes(h)
    local spacing <const> = tonumber(c.pedSpacing) or 0.75
    local fwd <const> = tonumber(c.pedForward) or 0.0

    -- facing the camera means they share the player's own heading
    local function at(side)
        return {
            x = x + rx * spacing * side + fx * fwd,
            y = y + ry * spacing * side + fy * fwd,
            z = z,
            heading = h,
        }
    end
    return at(1), at(-1) -- male on the right of centre, female on the left
end

-- travel limits for the editing camera, as absolute Z like the stock config
function CreatorSceneLimits()
    local c = scene()
    if not c then return nil end
    local cam <const> = CreatorSceneCam()
    return {
        maxUp    = cam.z + (tonumber(c.maxUp) or 0.55),
        maxDown  = cam.z + (tonumber(c.maxDown) or -0.95),
        zoomIn   = tonumber(c.zoomIn) or 1.6,
        zoomOut  = tonumber(c.zoomOut) or 1.2,
    }
end

-- load the interior, its entity sets and any imaps the scene needs
function CreatorSceneLoad()
    local c = scene()
    if not c then return false end
    local x, y, z = CreatorSceneSpawn()

    -- both natives: the ipl alone gives a bare shell. IplActive because the
    -- native answers with a number and 0 is truthy in Lua
    for _, m in ipairs(c.imaps or {}) do
        local h <const> = joaat(m)
        if not (IplActive and IplActive(h)) then RequestIplByHash(h) end
        pcall(function() RequestImap(h) end)
    end

    -- an open load scene pins the streamer, so it is stopped again below
    Citizen.InvokeNative(0x513F8AA5BF2F17CF, x, y, z, 50.0, 20) -- load sphere
    local t0 <const> = GetGameTimer()
    repeat Wait(0) until IsLoadSceneLoaded() or GetGameTimer() - t0 > 5000
    LoadSceneStop()

    -- the config's interior id is informational; the coords are what resolve
    local interior = GetInteriorAtCoords(x, y, z)
    if not interior or interior == 0 or IsValidInterior(interior) ~= 1 then
        return true -- exterior, or not streamed yet; entity sets simply do not apply
    end

    local guard = 0
    while IsInteriorReady(interior) ~= 1 and guard < 300 do
        Wait(10)
        guard = guard + 1
    end
    if IsInteriorReady(interior) ~= 1 then return true end

    -- NativeOn: IsInteriorEntitySetActive answers with a number, and 0 is truthy
    for _, set in ipairs(c.entitySets or {}) do
        if IsInteriorEntitySetValid(interior, set) == 1
            and not NativeOn(IsInteriorEntitySetActive(interior, set)) then
            ActivateInteriorEntitySet(interior, set)
        end
    end
    return true
end

function CreatorSceneUnload()
    local c = scene()
    if not c then return end
    -- imaps are left loaded on purpose: RemoveImaps does not actually unload

    -- entity sets stick per client, and pup-gangs' New Austin den shares 78337
    local x, y, z = CreatorSceneSpawn()
    local interior = GetInteriorAtCoords(x, y, z)
    if not interior or interior == 0 or IsValidInterior(interior) ~= 1 then return end
    for _, set in ipairs(c.entitySets or {}) do
        if NativeOn(IsInteriorEntitySetActive(interior, set)) then
            DeactivateInteriorEntitySet(interior, set)
        end
    end
end
