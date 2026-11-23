-- pup_tailor | dressing peds, the mannequin, its light and the camera.
local U = Tailor.U
local Cat = Tailor.Cat
local Ped = {}
Tailor.Ped = Ped

local N <const> = {
    categoryUsed  = 0xFB4891BD7578CDC1,
    removeTag     = 0xD710A5007C2AC539,
    clearCategory = 0x59BD177A1A48600A,
    applyShopItem = 0xD3A7B003ED343FD9,
    setMetaTag    = 0xBC6DF00D7A4A6819,
    refreshA      = 0xAAB86462966168CE,
    refreshB      = 0x704C908E9C405136,
    refreshC      = 0xCC8CA3E88256E58F,
    tint          = 0x4EFC1F8FF1AD94DE,
    preset        = 0x77FF8D35EEC6BBC4,
    strip         = 0x0BFA1BD465CDFEFD,
    variation     = 0x283978A15512B2FE,
    ready         = 0xA0BC8FAED8CFEB3C,
    hogtied       = 0x3AA24CCC0D451379,
    cuffed        = 0x74E559B3BC910685,
}

---------------------------------------------------------------------------
-- garments
---------------------------------------------------------------------------
local function truthy(r) return r == true or (type(r) == 'number' and r ~= 0) end

function Ped.isReady(ped)
    return truthy(Citizen.InvokeNative(N.ready, ped))
end

function Ped.waitReady(ped, frames)
    for _ = 1, frames or 100 do
        if not DoesEntityExist(ped) or Ped.isReady(ped) then return end
        Wait(0)
    end
end

function Ped.refresh(ped)
    Citizen.InvokeNative(N.refreshA, ped, true)
    Citizen.InvokeNative(N.refreshB, ped)
    Citizen.InvokeNative(N.refreshC, ped, false, true, true, true, false)
end

local function isFemale(ped)
    return not IsPedMale(ped)
end

function Ped.sexOf(ped)
    return IsPedMale(ped) and 'male' or 'female'
end

function Ped.removeSlot(ped, slot)
    local catHash = Cat.categoryHash(slot)
    if not catHash then return end
    if truthy(Citizen.InvokeNative(N.categoryUsed, ped, catHash)) then
        Citizen.InvokeNative(N.removeTag, ped, catHash, 0)
    end
end

-- put one garment on: value is the outfit's hash (multiplayer) or drawable (singleplayer)
function Ped.putOn(ped, slot, value, sex)
    local catHash = Cat.categoryHash(slot)
    local sp = Cat.spEntry(sex or Ped.sexOf(ped), value)
    if catHash then Ped.removeSlot(ped, slot) end
    if sp then
        Ped.waitReady(ped, 100)
        local r = sp.row
        local t = r.t or { 0, 0, 0 }
        Citizen.InvokeNative(N.setMetaTag, ped, r.d, r.a or 0, r.n or 0, r.m or 0, r.p or 0,
            t[1] or 0, t[2] or 0, t[3] or 0)
        Ped.refresh(ped)
        return
    end
    local h = U.unsigned(value)
    if not h then return end
    if catHash then Citizen.InvokeNative(N.clearCategory, ped, catHash) end
    local female = isFemale(ped)
    Citizen.InvokeNative(N.applyShopItem, ped, h, false, true, female)
    Citizen.InvokeNative(N.applyShopItem, ped, h, true, true, female)
end

function Ped.tint(ped, slot, palette, c1, c2, c3)
    local catHash = Cat.categoryHash(slot)
    if not catHash then return end
    Citizen.InvokeNative(N.tint, ped, catHash, Cat.resolvePalette(palette),
        U.int(c1) or 0, U.int(c2) or 0, U.int(c3) or 0)
    Ped.refresh(ped)
end

function Ped.applyColours(ped, colours)
    for slot, c in pairs(colours or {}) do
        Ped.tint(ped, slot, c.palette, c.color1, c.color2, c.color3)
    end
end

function Ped.blocked(ped)
    ped = ped or PlayerPedId()
    return IsEntityDead(ped)
        or truthy(Citizen.InvokeNative(N.hogtied, ped))
        or truthy(Citizen.InvokeNative(N.cuffed, ped))
end

---------------------------------------------------------------------------
-- mannequin, light and camera
---------------------------------------------------------------------------
local mannequin = nil   -- { ped, sex, bench, baseHeading }
local cam = nil
local camState = { zoom = 0, raise = 0, side = 1 }
local lightOn = false
local spawnToken = 0

function Ped.mannequin() return mannequin and mannequin.ped or nil end
function Ped.mannequinSex() return mannequin and mannequin.sex or nil end

local function placeCamera()
    if not cam or not mannequin or not DoesEntityExist(mannequin.ped) then return end
    local pos = GetEntityCoords(mannequin.ped)
    local a = math.rad(mannequin.baseHeading + 45.0)
    local dir = vector3(-math.sin(a), math.cos(a), 0.0)
    local camPos = vector3(pos.x + dir.x * camState.zoom, pos.y + dir.y * camState.zoom, pos.z + camState.raise)
    -- look-at point pushed to the camera's right, so the ped stands left of the menu
    local right = vector3(dir.y, -dir.x, 0.0)
    local side = Config.Camera.sideOffset * (camState.zoom / Config.Camera.zoomMax) * camState.side
    local look = vector3(pos.x - right.x * side, pos.y - right.y * side, pos.z + camState.raise)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, look.x, look.y, look.z)
end

function Ped.resetCamera()
    camState.zoom = Config.Camera.zoomStart
    camState.raise = Config.Camera.raiseStart
    placeCamera()
end

-- 1: ped left of frame (menu on the right); -1: ped right of frame (panel on the left)
function Ped.setCameraSide(s)
    camState.side = (s == -1) and -1 or 1
    placeCamera()
end

function Ped.moveCamera(dZoom, dRaise)
    local c = Config.Camera
    camState.zoom = math.min(c.zoomMax, math.max(c.zoomMin, camState.zoom + (dZoom or 0)))
    camState.raise = math.min(c.raiseMax, math.max(c.raiseMin, camState.raise + (dRaise or 0)))
    placeCamera()
end

function Ped.turn(deg)
    local p = Ped.mannequin()
    if p and DoesEntityExist(p) then SetEntityHeading(p, (GetEntityHeading(p) + deg) % 360.0) end
end

-- one light thread at a time: a generation number retires the old thread when a
-- mannequin is removed and another spawned before the old thread saw lightOn go false
local lightGen = 0
local function startLight()
    if lightOn then return end
    lightOn = true
    lightGen = lightGen + 1
    local gen = lightGen
    CreateThread(function()
        local l = Config.Mannequin.light
        while lightOn and lightGen == gen and mannequin and DoesEntityExist(mannequin.ped) do
            local pos = GetEntityCoords(mannequin.ped)
            DrawLightWithRange(pos.x + 1.0, pos.y, pos.z + 1.0, 255, 255, 255, l.range, l.intensity)
            DrawLightWithRange(pos.x, pos.y + 1.0, pos.z + 1.0, 255, 255, 255, l.range, l.intensity)
            Wait(0)
        end
        if lightGen == gen then lightOn = false end
    end)
end

local function createCamera()
    if cam then return end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, Config.Camera.fov)
    Ped.resetCamera()
    SetCamActive(cam, true)
    RenderScriptCams(true, true, Config.Camera.easeMs, true, true)
    DisplayHud(false)
    DisplayRadar(false)
end

local function destroyCamera()
    if not cam then return end
    RenderScriptCams(false, true, Config.Camera.easeMs, true, true)
    SetCamActive(cam, false)
    DestroyCam(cam, false)
    cam = nil
    DisplayHud(true)
    DisplayRadar(true)
end

function Ped.removeMannequin()
    spawnToken = spawnToken + 1
    lightOn = false
    if mannequin and DoesEntityExist(mannequin.ped) then
        SetEntityAsMissionEntity(mannequin.ped, true, true)
        DeletePed(mannequin.ped)
    end
    mannequin = nil
    destroyCamera()
end

-- undressed base body
local function baseBody(ped, sex)
    Citizen.InvokeNative(N.preset, ped, 0, false)
    Ped.waitReady(ped, 100)
    Citizen.InvokeNative(N.strip, ped)
    local female = sex == 'female'
    for _, h in ipairs(Config.Mannequin.basePieces[sex] or {}) do
        Citizen.InvokeNative(N.applyShopItem, ped, h, true, true, female)
    end
    for _, catHash in ipairs(Config.Mannequin.removeCategories) do
        Citizen.InvokeNative(N.removeTag, ped, catHash, 0)
    end
    Ped.refresh(ped)
end

-- spawn a fresh mannequin of a sex at a bench. stillWanted() is asked after each wait.
-- returns the ped or nil
function Ped.spawnMannequin(bench, sex, stillWanted)
    Ped.removeMannequin()
    local token = spawnToken
    local model = GetHashKey(Config.Mannequin.models[sex] or 'mp_male')
    RequestModel(model, false)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(model) or token ~= spawnToken or not stillWanted() then
        SetModelAsNoLongerNeeded(model)
        return nil
    end
    local m = bench.mannequin
    local z = bench.floorZ or (m.z - Config.Mannequin.zDrop)
    local ped = CreatePed(model, m.x, m.y, z, m.w, true, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then return nil end
    if token ~= spawnToken or not stillWanted() then
        DeletePed(ped)
        return nil
    end
    Citizen.InvokeNative(N.variation, ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    mannequin = { ped = ped, sex = sex, bench = bench, baseHeading = m.w }
    baseBody(ped, sex)
    if token ~= spawnToken or not stillWanted() then
        Ped.removeMannequin()
        return nil
    end
    createCamera()
    startLight()
    return ped
end

---------------------------------------------------------------------------
-- showroom keys (outfit screen): checked every frame while on
---------------------------------------------------------------------------
local showroomOn = false
local showroomGen = 0
function Ped.showroom(on)
    on = on == true
    if on == showroomOn then return end
    showroomOn = on
    showroomGen = showroomGen + 1
    if not on then return end
    local gen = showroomGen
    CreateThread(function()
        local k, s = Config.Keys, Config.Camera.showroom
        local keys = { k.turnLeft, k.turnRight, k.zoomIn, k.zoomOut, k.camUp, k.camDown, k.reset }
        -- the generation check stops an older thread when off/on happen within one frame
        while showroomOn and showroomGen == gen do
            for _, key in ipairs(keys) do DisableControlAction(0, key, true) end
            for _, key in ipairs(Config.ShowroomExtraDisabled) do DisableControlAction(0, key, true) end
            if IsDisabledControlPressed(0, k.turnLeft) then Ped.turn(s.turn) end
            if IsDisabledControlPressed(0, k.turnRight) then Ped.turn(-s.turn) end
            if IsDisabledControlPressed(0, k.zoomIn) then Ped.moveCamera(-s.zoom, 0) end
            if IsDisabledControlPressed(0, k.zoomOut) then Ped.moveCamera(s.zoom, 0) end
            if IsDisabledControlPressed(0, k.camUp) then Ped.moveCamera(0, s.raise) end
            if IsDisabledControlPressed(0, k.camDown) then Ped.moveCamera(0, -s.raise) end
            if IsDisabledControlJustPressed(0, k.reset) then Ped.resetCamera() end
            Wait(0)
        end
    end)
end
