-- pup-medical | free-look death camera (vorp_core's own is switched off)

local LOOK_LR <const> = 0x6BC904FC
local LOOK_UD <const> = 0x84574AE8
local RADIUS <const> = 3.5
local PAD_SPEED <const> = 2.0     -- degrees per frame at full stick
local MOUSE_SPEED <const> = 32.0  -- about 16x the pad

local cam = nil
local yaw, pitch = 0.0, 15.0

local function usingMouse()
    local ok, v = pcall(Citizen.InvokeNative, 0xA571D46727E2B718, 0, Citizen.ResultAsInteger())
    return ok and v ~= 0 and v ~= false
end

local function destroyCam()
    if not cam then return end
    RenderScriptCams(false, true, 500, true, false, 0)
    DestroyCam(cam, false)
    cam = nil
end

local function createCam()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    yaw = GetEntityHeading(ped) - 90.0
    pitch = 15.0
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z + 1.0, 0.0, 0.0, 0.0, GetGameplayCamFov(), false, 0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1000, true, false, 0)
end

local function placeCam()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local speed = usingMouse() and MOUSE_SPEED or PAD_SPEED
    yaw = (yaw - GetDisabledControlNormal(0, LOOK_LR) * speed) % 360.0
    pitch = math.max(-89.0, math.min(89.0, pitch + GetDisabledControlNormal(0, LOOK_UD) * speed))

    local yr, pr = math.rad(yaw), math.rad(pitch)
    local dir = vector3(math.cos(pr) * math.cos(yr), math.cos(pr) * math.sin(yr), math.sin(pr))
    local origin = vector3(p.x, p.y, p.z + 0.5)
    local want = origin + dir * RADIUS

    local radius = RADIUS
    -- synchronous: an async probe read on the same frame is still pending and
    -- never reports a hit, so the camera would clip through walls
    local probe = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, want.x, want.y, want.z, -1, ped, 0)
    local _, hit, hitAt = GetShapeTestResult(probe)
    if hit == 1 or hit == true then
        local d = #(hitAt - origin)
        if d < radius then radius = math.max(0.5, d - 0.2) end
    end
    local at = origin + dir * radius
    SetCamCoord(cam, at.x, at.y, at.z)
    PointCamAtCoord(cam, p.x, p.y, p.z)
end

CreateThread(function()
    while not LocalPlayer.state.IsInSession do Wait(1000) end
    while true do
        local ped = PlayerPedId()
        local down = IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
        if down and not cam then
            createCam()
            while cam and (IsEntityDead(PlayerPedId()) or IsPedDeadOrDying(PlayerPedId(), true)) do
                Wait(0)
                HideHudAndRadarThisFrame()
                placeCam()
            end
            destroyCam()
        elseif not down and cam then
            destroyCam()
        end
        Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    destroyCam()
end)
