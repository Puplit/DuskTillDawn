-- Staff photo and cinematic camera. It rides an invisible prop so anti-aliasing survives movement.

local active      = false
local cam         = nil
local controller  = nil
local anchor      = nil          -- where it was opened; range is measured from here
local maxRange    = 500.0
local pos         = vector3(0, 0, 0)
local pitch, yaw, roll = 0.0, 0.0, 0.0
local fov         = 50.0
local showOverlay = true         -- Q: the camera's own header, help and grid
local showGrid    = false
local showHelp    = true
local filterIdx   = 1
local points      = {}           -- saved cinematic positions
local dollying    = false

local dollyCount   = nil         -- countdown number, nil once the move starts
local letterbox    = false
local scaleIdx     = 1           -- index into Config.TimeScales
local pedVisible   = false       -- show your own character, for self portraits
local worldTouched = false       -- true once time or weather was overridden
local timeName     = "Live"
local weatherName  = "Live"
local dofOn        = false
local dofNear, dofFar = 0.4, 30.0

-- analog sticks / axes
local C = {
    lookLR = `INPUT_LOOK_LR`,    lookUD = `INPUT_LOOK_UD`,
    moveLR = `INPUT_MOVE_LR`,    moveUD = `INPUT_MOVE_UD`,
}

-- ACTION KEYS: raw virtual-key codes first, control name as fallback (RedM maps INPUT_* to different letters than GTA V)
local KEYS = {
    menu      = { vk = tonumber(Config.Keys.menu) or 77, ctrl = `INPUT_MAP` }, -- M by default
    savePoint = { vk = 69,  ctrl = `INPUT_ENTER`           }, -- E
    clearPts  = { vk = 67,  ctrl = `INPUT_LOOK_BEHIND`     }, -- C
    resetRoll = { vk = 82,  ctrl = `INPUT_RELOAD`          }, -- R
    nextStyle = { vk = 71,  ctrl = `INPUT_INTERACT_ANIMAL` }, -- G
    grid      = { vk = 72,  ctrl = `INPUT_WHISTLE`         }, -- H
    hud       = { vk = 81,  ctrl = `INPUT_COVER`           }, -- Q
    dolly     = { vk = 80 },                                  -- P (no fallback: INPUT_FRONTEND_PAUSE opens the pause menu)
    help      = { vk = tonumber(Config.Keys.help) or 114 },     -- F3 by default
    rollL     = { vk = 219 },                                 -- [
    rollR     = { vk = 221 },                                 -- ]
    zoomIn    = { vk = 33 },                                  -- PageUp
    zoomIn2   = { vk = 187 },                                 -- =
    zoomOut   = { vk = 34 },                                  -- PageDown
    zoomOut2  = { vk = 189 },                                 -- -
    up        = { vk = 32,  ctrl = `INPUT_JUMP`            }, -- Space
    down      = { vk = 17,  ctrl = `INPUT_DUCK`            }, -- Ctrl
    boost     = { vk = 16,  ctrl = `INPUT_SPRINT`          }, -- Shift
    -- not Alt: Left Alt is bound to radio talk, so holding it here would key the mic
    slow      = { vk = 86,  ctrl = `INPUT_AIM`             }, -- V
    exit      = { vk = 8,   ctrl = `INPUT_FRONTEND_CANCEL` }, -- Backspace
}

local rawOk  = pcall(function() return IsRawKeyPressed(112) end)
local rawWas = {}   -- IsRawKeyPressed is level-triggered, so edges are tracked here

local function justPressed(k)
    if rawOk and k.vk then
        local down <const> = IsRawKeyPressed(k.vk) and true or false
        local was <const> = rawWas[k.vk]
        rawWas[k.vk] = down
        if down and not was then return true end
    end
    return k.ctrl ~= nil and IsDisabledControlJustPressed(0, k.ctrl)
end

local function held(k)
    if rawOk and k.vk and IsRawKeyPressed(k.vk) then return true end
    return k.ctrl ~= nil and IsDisabledControlPressed(0, k.ctrl)
end

local function notify(msg)
    TriggerEvent("vorp:TipRight", msg, 4000)
end

-- WORLD ----------------------------------------------------------------------

-- STYLES ---------------------------------------------------------------------
-- Styles = timecycle grades. ScreenFx = fullscreen overlays, layered on top.
-- names are validated at boot so a typo warns instead of silently doing nothing

local styles   = {}   -- validated copy of Config.Styles
local screenFx = {}
local allTc    = nil  -- every timecycle the game knows, read on demand
local fxIdx    = 1
local strength = 1.0

local function tcExists(name)
    local ok, idx = pcall(function() return GetTimecycleModifierIndexByName(name) end)
    if not ok then return nil end          -- native missing: cannot say
    return idx ~= nil and idx >= 0
end

local function buildStyles()
    styles = { }
    for _, s in ipairs(Config.Styles or {}) do
        if not s.tc then
            styles[#styles + 1] = s
        else
            local exists = tcExists(s.tc)
            if exists == false then
                print(("^3[pup-camera]^7 style '%s' dropped - no timecycle called '%s'")
                    :format(s.name, s.tc))
            else
                styles[#styles + 1] = s
            end
        end
    end
    if #styles == 0 then styles = { { name = "Off" } } end

    screenFx = {}
    for _, f in ipairs(Config.ScreenFx or {}) do screenFx[#screenFx + 1] = f end
    if #screenFx == 0 then screenFx = { { name = "None" } } end
end

-- every timecycle in the game, for the browser; built once, lazily
local function allTimecycles()
    if allTc then return allTc end
    allTc = {}
    local ok = pcall(function()
        local n = GetTimecycleModifierCount()
        for i = 0, (tonumber(n) or 0) - 1 do
            local nm = GetTimecycleModifierNameByIndex(i)
            if nm and nm ~= "" then allTc[#allTc + 1] = nm end
        end
    end)
    if not ok or #allTc == 0 then allTc = false end   -- natives unavailable here
    return allTc
end

local function stopFx()
    for _, f in ipairs(Config.ScreenFx or {}) do
        if f.fx then pcall(function()
            if AnimpostfxIsRunning(f.fx) then AnimpostfxStop(f.fx) end
        end) end
    end
end

local function applyFilter()
    ClearTimecycleModifier()
    local s = styles[filterIdx]
    if s and s.tc then
        SetTimecycleModifier(s.tc)
        pcall(function() SetTimecycleModifierStrength(s.strength or strength) end)
    end

    stopFx()
    local f = screenFx[fxIdx]
    if f and f.fx then pcall(function() AnimpostfxPlay(f.fx) end) end
end

-- set a raw timecycle straight from the browser, bypassing the curated list
local function applyRawTimecycle(name)
    ClearTimecycleModifier()
    if name then
        SetTimecycleModifier(name)
        pcall(function() SetTimecycleModifierStrength(strength) end)
    end
end

-- THE SERVER'S OWN UI ---------------------------------------------------------
-- the HUD natives miss the NUI overlays, so use vorp_core's /hideUi switch
local function setServerUi(show)
    if GetResourceState("vorp_core") == "started"
        and pcall(function() exports.vorp_core:SetAllUI(show) end) then
        return
    end
    -- core without the export: do what it does, minus its bookkeeping
    DisplayRadar(show)
    DisplayHud(show)
    TriggerEvent("fred_hud:setVisible", show)
    TriggerEvent("pup-displayrange", show)
    TriggerEvent("vorp:showUi", show)
end

local function hidePlayer(hide)
    local ped = PlayerPedId()
    SetEntityVisible(ped, not hide)
    FreezeEntityPosition(ped, hide)
    SetEntityInvincible(ped, hide)
    SetEveryoneIgnorePlayer(PlayerId(), hide)
end

-- CAMERA ---------------------------------------------------------------------

-- the carrier is optional: attaching to entity 0 gives a white screen, so fall back to moving the camera
local function loadCarrier(startPos)
    local tried = {}
    local names = { Config.Carrier.model, "p_door04x", "p_cs_newspaper_02x_noanim" }
    for _, name in ipairs(names) do
        if name and name ~= "" and not tried[name] then
            tried[name] = true
            local m = joaat(name)
            if IsModelInCdimage(m) then
                RequestModel(m)
                local waited = 0
                while not HasModelLoaded(m) and waited < 1500 do Wait(50); waited = waited + 50 end
                if HasModelLoaded(m) then
                    local obj = CreateObjectNoOffset(m, startPos.x, startPos.y, startPos.z, false, false, false)
                    SetModelAsNoLongerNeeded(m)
                    if obj and obj ~= 0 and DoesEntityExist(obj) then
                        return obj, name
                    end
                end
            else
                print(("^3[pup-camera]^7 carrier model '%s' is not in the game files"):format(name))
            end
        end
    end
    return nil
end

local function buildCam(startPos)
    local name
    controller, name = loadCarrier(startPos)

    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamRot(cam, pitch, roll, yaw, 2)
    SetCamFov(cam, fov)

    if controller then
        SetEntityVisible(controller, false)
        SetEntityCollision(controller, false, false)
        FreezeEntityPosition(controller, true)
        AttachCamToEntity(cam, controller, 0.0, 0.0, 0.0, true)
        if Config.General.debug then
            print(("^2[pup-camera]^7 carrier '%s' ok"):format(tostring(name)))
        end
    else
        -- still a working camera, just without the AA trick while it moves
        SetCamCoord(cam, startPos.x, startPos.y, startPos.z)
        print("^3[pup-camera]^7 no carrier prop could be loaded - moving the camera directly. "
            .. "Anti-aliasing will drop while flying. Set a valid Config.Carrier.model to restore it.")
    end

    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

-- move whichever thing is actually driving the view
local function placeCam(p)
    if controller and DoesEntityExist(controller) then
        SetEntityCoordsNoOffset(controller, p.x, p.y, p.z, false, false, false)
    elseif cam then
        SetCamCoord(cam, p.x, p.y, p.z)
    end
end

-- WORLD, LENS, MOTION --------------------------------------------------------
-- weathersync's per-player exports: only your own sky changes, and sync is restored on close

local function weatherSyncReady()
    return GetResourceState("weathersync") == "started"
end

local function setLocalTime(t)
    if not weatherSyncReady() then return notify(Locale.weathersyncOff) end
    if not pcall(function() exports.weathersync:setMyTime(t.hour, t.minute, 0, 0) end) then
        return notify(Locale.timeFailed)
    end
    worldTouched, timeName = true, t.name
end

local function setLocalWeather(name)
    if not weatherSyncReady() then return notify(Locale.weathersyncOff) end
    if not pcall(function() exports.weathersync:setMyWeather(name, 0.5, false) end) then
        return notify(Locale.weatherFailed)
    end
    worldTouched, weatherName = true, name
end

local function restoreWorld()
    if not worldTouched then return end
    pcall(function() exports.weathersync:setSyncEnabled(true) end)
    worldTouched, timeName, weatherName = false, "Live", "Live"
end

local function applyTimeScale()
    SetTimeScale(((Config.TimeScales or {})[scaleIdx] or 1.0) + 0.0)
end

-- DOF natives may be missing (nil globals), so check before use
local dofAvailable <const> =
    SetCamUseShallowDofMode ~= nil and SetCamNearDof ~= nil
    and SetCamFarDof ~= nil and SetCamDofStrength ~= nil

local function applyDof()
    if not (dofAvailable and cam) then return end
    SetCamUseShallowDofMode(cam, dofOn)
    if dofOn then
        SetCamNearDof(cam, dofNear)
        SetCamFarDof(cam, dofFar)
        SetCamDofStrength(cam, 1.0)
    end
end

local function drawLetterbox()
    local h <const> = tonumber(Config.Lens.letterboxHeight) or 0.11
    DrawRect(0.5, h * 0.5, 1.0, h, 0, 0, 0, 255)
    DrawRect(0.5, 1.0 - h * 0.5, 1.0, h, 0, 0, 0, 255)
end

local function setPedVisible(show)
    pedVisible = show and true or false
    SetEntityVisible(PlayerPedId(), pedVisible)
end

local function snapToMe()
    local ped <const> = PlayerPedId()
    pos = GetEntityCoords(ped) + vector3(0.0, 0.0, 1.0)
    yaw, pitch, roll = GetEntityHeading(ped), 0.0, 0.0
    placeCam(pos)
end

-- the ped is frozen while the camera is up, so it has to be released to move
local function bringMeHere()
    local ped <const> = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    FreezeEntityPosition(ped, true)
    anchor = pos   -- range is measured from wherever you now stand
    notify(Locale.movedHere)
end

local function tearDown()
    RenderScriptCams(false, true, 500, true, true)
    if cam then DestroyCam(cam, false); cam = nil end
    if controller and DoesEntityExist(controller) then DeleteObject(controller) end
    controller = nil
end

-- clamp to the allowed radius; 0 means no limit
local function clampToRange(p)
    if not anchor or maxRange <= 0.0 then return p, false end
    local d = #(vector3(p.x, p.y, p.z) - anchor)
    if d <= maxRange then return p, false end
    local dir = (vector3(p.x, p.y, p.z) - anchor) / d
    return anchor + dir * maxRange, true
end

-- MOVEMENT -------------------------------------------------------------------

local function forwardFrom(p, y)
    local pr, yr = math.rad(p), math.rad(y)
    local cp = math.cos(pr)
    return vector3(-math.sin(yr) * cp, math.cos(yr) * cp, math.sin(pr))
end

local function step()
    local dt = GetFrameTime() * 60.0   -- normalise to 60fps so speed is stable

    -- look
    local lr = GetDisabledControlNormal(0, C.lookLR)
    local ud = GetDisabledControlNormal(0, C.lookUD)
    yaw   = (yaw - lr * Config.Movement.lookSensitivity) % 360.0
    pitch = math.max(-89.0, math.min(89.0, pitch - ud * Config.Movement.lookSensitivity))

    -- speed
    local mult = 1.0
    if held(KEYS.boost) then mult = Config.Movement.boostMultiplier end
    if held(KEYS.slow)  then mult = Config.Movement.slowMultiplier end
    local sp = Config.Movement.speed * mult * dt

    -- translate
    local fwd = forwardFrom(pitch, yaw)
    local right = vector3(fwd.y, -fwd.x, 0.0)
    if #right > 0.0 then right = right / #right end

    local mv = -GetDisabledControlNormal(0, C.moveUD)   -- W positive
    local mh =  GetDisabledControlNormal(0, C.moveLR)
    local next_ = pos + fwd * (mv * sp) + right * (mh * sp)
    if held(KEYS.up)   then next_ = next_ + vector3(0, 0, sp) end
    if held(KEYS.down) then next_ = next_ - vector3(0, 0, sp) end

    local clamped, hit = clampToRange(next_)
    pos = clamped
    if hit then notify(Locale.rangeHit) end

    -- zoom
    if held(KEYS.zoomIn)  or held(KEYS.zoomIn2)  then fov = math.max(Config.Lens.fovMin, fov - Config.Lens.fovStep) end
    if held(KEYS.zoomOut) or held(KEYS.zoomOut2) then fov = math.min(Config.Lens.fovMax, fov + Config.Lens.fovStep) end

    placeCam(pos)
    SetCamRot(cam, pitch, roll, yaw, 2)
    SetCamFov(cam, fov)
end

-- HUD ------------------------------------------------------------------------

local function drawText(txt, x, y, scale, centre, alpha)
    SetTextScale(scale or 0.32, scale or 0.32)
    SetTextColor(255, 255, 255, alpha or 200)
    SetTextCentre(centre and true or false)
    DisplayText(CreateVarString(10, "LITERAL_STRING", txt), x, y)
end

-- pre-roll countdown, shown alone until the move starts
local function drawCountdown(n)
    drawText(tostring(n), 0.5, 0.44, 1.10, true, 230)
end

local function drawGrid()
    -- rule of thirds
    DrawRect(0.3333, 0.5, 0.0015, 1.0, 255, 255, 255, 40)
    DrawRect(0.6666, 0.5, 0.0015, 1.0, 255, 255, 255, 40)
    DrawRect(0.5, 0.3333, 1.0, 0.0025, 255, 255, 255, 40)
    DrawRect(0.5, 0.6666, 1.0, 0.0025, 255, 255, 255, 40)
end

local HELP = {
    "M   menu (world, look, lens, dolly)",
    "WASD / Space / Ctrl  move",
    "Shift boost   V slow",
    "PgUp / PgDn  or  = / -   zoom",
    "[ ]  roll        R  reset roll",
    "G  next style    H  grid",
    "E  save point    C  clear points",
    "P  play dolly    BACKSPACE  exit",
    "   while a dolly runs, either one stops it",
    "",
    "Q   CLEAN SHOT - hides all of this",
    "F3  hides this list only",
}

local function drawHelp()
    local st = styles[filterIdx] and styles[filterIdx].name or "Off"
    local fx = screenFx[fxIdx] and screenFx[fxIdx].name or "None"
    drawText(("FOV %.0f   %s%s   points %d")
        :format(fov, st, (fx ~= "None" and (" + " .. fx) or ""), #points), 0.015, 0.02, 0.35)
    -- with the list closed, keep the two keys that bring it back on screen
    if not showHelp then
        drawText("F3  controls        Q  clean shot", 0.015, 0.048, 0.28)
        return
    end
    local y = 0.07
    for _, line in ipairs(HELP) do
        if line ~= "" then drawText(line, 0.015, y, 0.30) end
        y = y + 0.022
    end
end

-- CINEMATIC ------------------------------------------------------------------

local function savePoint()
    points[#points + 1] = { pos = pos, pitch = pitch, yaw = yaw, roll = roll, fov = fov }
    notify(Locale.pointSaved:format(#points))
end

-- each leg is its own interpolation, so the move eases rather than snaps
local function playDolly()
    if #points < 2 then return notify(Locale.needTwo) end
    if dollying then return end
    dollying = true

    -- no notifications during a move: a TipRight would be baked into the recording
    -- counted in tenths so a cancel lands within 100ms
    for i = Config.Dolly.countdownSeconds, 1, -1 do
        if not dollying then break end
        dollyCount = i
        for _ = 1, 10 do
            if not dollying then break end
            Wait(100)
        end
    end
    dollyCount = nil

    local legMs = math.floor((tonumber(Config.Dolly.legSeconds) or 6.0) * 1000)
    for i = 1, #points - 1 do
        -- skip the remaining legs after a cancel
        if not dollying then break end
        local a, b = points[i], points[i + 1]
        local t = 0
        while t < legMs and dollying do
            local k = t / legMs
            k = k * k * (3 - 2 * k)                      -- smoothstep
            local p = a.pos + (b.pos - a.pos) * k
            pos   = p
            pitch = a.pitch + (b.pitch - a.pitch) * k
            roll  = a.roll  + (b.roll  - a.roll)  * k
            fov   = a.fov   + (b.fov   - a.fov)   * k
            -- shortest way round the circle, so 350 -> 10 does not spin 340 degrees
            local dy = ((b.yaw - a.yaw + 180.0) % 360.0) - 180.0
            yaw = (a.yaw + dy * k) % 360.0

            placeCam(pos)
            SetCamRot(cam, pitch, roll, yaw, 2)
            SetCamFov(cam, fov)
            Wait(0)
            t = t + GetFrameTime() * 1000
        end
    end
    dollying = false
    dollyCount = nil
end

-- MENU -----------------------------------------------------------------------
-- the flight loop stops reading controls while the menu is open

local menuOpen = false
-- forward declared: menu actions reference these before they are defined
local openMenu, close
local lookMenu, worldMenu, timeMenu, weatherMenu, lensMenu, motionMenu, subjectMenu

local function pretty(s)
    s = tostring(s or "")
    return (s:gsub("^%l", string.upper))
end

local function styleMenu()
    local opts = {}
    for i, s in ipairs(styles) do
        opts[#opts + 1] = {
            label = (i == filterIdx and "> " or "  ") .. s.name,
            desc = s.tc and ("timecycle: " .. s.tc) or "no grade",
            action = function() filterIdx = i; applyFilter() end,
        }
    end
    return { title = "Style", subtitle = "Colour grade", options = opts }
end

local function fxMenu()
    local opts = {}
    for i, f in ipairs(screenFx) do
        opts[#opts + 1] = {
            label = (i == fxIdx and "> " or "  ") .. f.name,
            desc = f.fx and ("effect: " .. f.fx) or "none",
            action = function() fxIdx = i; applyFilter() end,
        }
    end
    return { title = "Screen Effect", subtitle = "Layered over the style", options = opts }
end

-- every timecycle the game has, for finding new looks
local function browseMenu()
    local list = allTimecycles()
    if not list then
        return { title = "All Timecycles", subtitle = "Unavailable on this build",
                 options = { { label = "This game build does not expose the list", close = true } } }
    end
    local opts = { {
        label = "  Clear", desc = "back to no grade",
        action = function() applyRawTimecycle(nil) end,
    } }
    for _, nm in ipairs(list) do
        opts[#opts + 1] = { label = "  " .. nm, action = function() applyRawTimecycle(nm) end }
    end
    return { title = "All Timecycles",
             subtitle = ("%d found in this build"):format(#list), options = opts }
end

local function presetMenu()
    local opts = {}
    for _, p in ipairs(Config.FeelPresets or {}) do
        opts[#opts + 1] = {
            label = "  " .. p.name,
            desc = ("speed %.2f  fov %d"):format(p.speed, p.fov),
            action = function()
                Config.Movement.speed = p.speed
                Config.Movement.lookSensitivity = p.look
                fov = p.fov
            end,
        }
    end
    return { title = "Camera Feel", subtitle = "Movement and lens", options = opts }
end

local function cineMenu()
    return { title = "Cinematic", subtitle = ("%d point(s) saved"):format(#points), options = {
        { label = "  Save point here", action = savePoint },
        { label = "  Play dolly", desc = ("%.0fs per leg"):format(Config.Dolly.legSeconds),
          action = function() PupMenu.Close(); CreateThread(playDolly) end, close = true },
        { label = "  Faster", desc = "shorter legs",
          action = function() Config.Dolly.legSeconds = math.max(1.0, Config.Dolly.legSeconds - 1.0) end },
        { label = "  Slower", desc = "longer legs",
          action = function() Config.Dolly.legSeconds = Config.Dolly.legSeconds + 1.0 end },
        { label = "  Clear points", action = function() points = {}; notify(Locale.pointsClear) end },
    } }
end

lookMenu = function()
    return { title = "Look", subtitle = "Colour and overlays", options = {
        { label = "  Style",          desc = styles[filterIdx].name, submenu = styleMenu },
        { label = "  Screen Effect",  desc = screenFx[fxIdx].name,   submenu = fxMenu },
        { label = "  All Timecycles", desc = "every grade in the game", submenu = browseMenu },
    } }
end

timeMenu = function()
    local opts = { {
        label = "  Live", desc = "back to the server's clock",
        action = function() restoreWorld(); PupMenu.Refresh(timeMenu()) end,
    } }
    for _, t in ipairs(Config.TimePresets or {}) do
        opts[#opts + 1] = {
            label  = (timeName == t.name and "> " or "  ") .. t.name,
            desc   = ("%02d:%02d"):format(t.hour, t.minute),
            action = function() setLocalTime(t); PupMenu.Refresh(timeMenu()) end,
        }
    end
    return { title = "Time of Day", subtitle = "Yours only", options = opts }
end

weatherMenu = function()
    local opts = { {
        label = "  Live", desc = "back to the server's sky",
        action = function() restoreWorld(); PupMenu.Refresh(weatherMenu()) end,
    } }
    for _, w in ipairs(Config.WeatherPresets or {}) do
        opts[#opts + 1] = {
            label  = (weatherName == w and "> " or "  ") .. pretty(w),
            action = function() setLocalWeather(w); PupMenu.Refresh(weatherMenu()) end,
        }
    end
    return { title = "Weather", subtitle = "Yours only", options = opts }
end

worldMenu = function()
    return { title = "World", subtitle = ("%s  |  %s"):format(timeName, pretty(weatherName)), options = {
        { label = "  Time of Day", desc = timeName, submenu = timeMenu },
        { label = "  Weather",     desc = pretty(weatherName), submenu = weatherMenu },
        { label = "  Restore live sky", desc = "undo both",
          action = function() restoreWorld(); PupMenu.Refresh(worldMenu()) end },
    } }
end

lensMenu = function()
    local opts = {
        { label = ("  Letterbox: %s"):format(letterbox and "on" or "off"),
          desc = "cinematic bars",
          action = function() letterbox = not letterbox; PupMenu.Refresh(lensMenu()) end },
    }
    if dofAvailable then
        opts[#opts + 1] = { label = ("  Depth of field: %s"):format(dofOn and "on" or "off"),
            desc = "blur outside the focus range",
            action = function() dofOn = not dofOn; applyDof(); PupMenu.Refresh(lensMenu()) end }
        opts[#opts + 1] = { label = "  Focus nearer", desc = ("near %.1fm"):format(dofNear),
            action = function() dofNear = math.max(0.1, dofNear - 0.1); applyDof(); PupMenu.Refresh(lensMenu()) end }
        opts[#opts + 1] = { label = "  Focus further", desc = ("far %.0fm"):format(dofFar),
            action = function() dofFar = math.min(300.0, dofFar + 5.0); applyDof(); PupMenu.Refresh(lensMenu()) end }
        opts[#opts + 1] = { label = "  Reset focus", desc = "0.4m to 30m",
            action = function() dofNear, dofFar = 0.4, 30.0; applyDof(); PupMenu.Refresh(lensMenu()) end }
    else
        opts[#opts + 1] = { label = "  Depth of field",
            desc = "not available on this game build", disabled = true }
    end
    opts[#opts + 1] = { label = "  Reset roll", action = function() roll = 0.0 end }
    return { title = "Lens", subtitle = ("FOV %.0f"):format(fov), options = opts }
end

motionMenu = function()
    local opts = {}
    for i, v in ipairs(Config.TimeScales or {}) do
        opts[#opts + 1] = {
            label  = (i == scaleIdx and "> " or "  ") .. ("%d%% speed"):format(math.floor(v * 100 + 0.5)),
            action = function() scaleIdx = i; applyTimeScale(); PupMenu.Refresh(motionMenu()) end,
        }
    end
    return { title = "Slow Motion",
             subtitle = "Slows the whole world, not just the camera", options = opts }
end

subjectMenu = function()
    return { title = "My Character", subtitle = pedVisible and "visible" or "hidden", options = {
        { label = ("  %s my character"):format(pedVisible and "Hide" or "Show"),
          desc = "for self portraits",
          action = function() setPedVisible(not pedVisible); PupMenu.Refresh(subjectMenu()) end },
        { label = "  Snap camera to me", desc = "bring the lens back",
          action = snapToMe },
        { label = "  Move me to the camera", desc = "you end up where the lens is",
          action = bringMeHere },
    } }
end

openMenu = function()
    if not active or menuOpen then return end
    menuOpen = true
    PupMenu.Open({ title = "Camera", subtitle = ("FOV %.0f  |  %s"):format(fov, styles[filterIdx].name), options = {
        { label = "Look",           desc = styles[filterIdx].name, submenu = lookMenu },
        { label = "World",          desc = ("%s, %s"):format(timeName, pretty(weatherName)), submenu = worldMenu },
        { label = "Lens",           desc = letterbox and "letterbox on" or "focus and bars", submenu = lensMenu },
        { label = "Slow Motion",    desc = ("%d%%"):format(math.floor(((Config.TimeScales or {})[scaleIdx] or 1.0) * 100 + 0.5)),
          submenu = motionMenu },
        { label = "My Character",   desc = pedVisible and "visible" or "hidden", submenu = subjectMenu },
        { label = "Camera Feel",    desc = "speed, sensitivity, lens", submenu = presetMenu },
        { label = "Cinematic",      desc = ("%d point(s)"):format(#points), submenu = cineMenu },
        { label = "Grid",           desc = showGrid and "on" or "off",
          action = function() showGrid = not showGrid end },
        { label = "Clean shot",     desc = "hide everything - Q does this too",
          action = function() showOverlay = false; PupMenu.Close() end, close = true },
        { label = "Reset roll",     action = function() roll = 0.0 end },
        { label = "Close camera",   desc = "put it away",
          action = function() PupMenu.Close(); close() end, close = true },
    } })
end

PupMenu.OnClose = function() menuOpen = false end

-- OPEN / CLOSE ---------------------------------------------------------------

close = function()
    if not active then return end
    active, dollying, dollyCount = false, false, nil
    if menuOpen then PupMenu.Close() end
    tearDown()
    ClearTimecycleModifier()
    stopFx()
    -- restore everything the camera changed
    restoreWorld()
    SetTimeScale(1.0)
    scaleIdx, letterbox, dofOn, pedVisible = 1, false, false, false
    hidePlayer(false)
    setServerUi(true)
    points = {}
    TriggerServerEvent("pup-camera:closed")
    notify(Locale.closed)
end

local function open()
    if active then return close() end

    local ped = PlayerPedId()
    local start = GetEntityCoords(ped) + vector3(0.0, 0.0, 1.0)
    anchor = start
    pos = start
    yaw = GetEntityHeading(ped)
    pitch, roll, fov = 0.0, 0.0, Config.Lens.fovDefault
    filterIdx, fxIdx, showOverlay, showGrid, showHelp = 1, 1, true, false, true
    points = {}
    rawWas = {}          -- a key held from before must not count as a fresh press
    letterbox, dofOn, pedVisible, worldTouched = false, false, false, false
    scaleIdx, timeName, weatherName = 1, "Live", "Live"
    dofNear, dofFar = 0.4, 30.0
    buildStyles()

    hidePlayer(true)
    setServerUi(false)
    buildCam(start)
    applyFilter()
    active = true
    TriggerServerEvent("pup-camera:opened")
    notify(Locale.opened)

    CreateThread(function()
        while active do
            Wait(0)
            -- controls stay disabled the whole time: pup-ui keeps game input alive behind the menu
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            -- these stay live so look still reads
            EnableControlAction(0, C.lookLR, true)
            EnableControlAction(0, C.lookUD, true)

            -- a dolly ignores other keys, so Backspace / P stay live to stop it
            if dollying and (justPressed(KEYS.exit) or justPressed(KEYS.dolly)) then
                dollying = false
                notify(Locale.dollyStopped)
            end

            -- the menu owns input while open; raw keys bypass controls, so check the pause menu by hand
            if not dollying and not menuOpen and not IsPauseMenuActive() then
                step()

                if justPressed(KEYS.savePoint) then savePoint() end
                if justPressed(KEYS.clearPts)  then points = {}; notify(Locale.pointsClear) end
                if justPressed(KEYS.rollL)     then roll = roll - 2.0 end
                if justPressed(KEYS.rollR)     then roll = roll + 2.0 end
                if justPressed(KEYS.resetRoll) then roll = 0.0 end
                if justPressed(KEYS.nextStyle) then
                    filterIdx = filterIdx % #styles + 1
                    applyFilter()
                end
                if justPressed(KEYS.menu)  then openMenu() end
                if justPressed(KEYS.grid)  then showGrid = not showGrid end
                if justPressed(KEYS.hud)   then showOverlay = not showOverlay end
                if justPressed(KEYS.help)  then showHelp = not showHelp end
                if justPressed(KEYS.dolly) then CreateThread(playDolly) end
                if justPressed(KEYS.exit)  then close() break end
            end

            -- shallow DOF has to be asked for every frame or the game drops it
            if dofOn and SetUseHiDof then SetUseHiDof() end
            if letterbox then drawLetterbox() end

            -- game HUD and radar stay hidden the whole time the camera is up
            HideHudAndRadarThisFrame()

            -- Q hides our overlays; a dolly always hides them except the countdown and letterbox
            if dollyCount then
                drawCountdown(dollyCount)
            elseif showOverlay and not dollying then
                drawHelp()
                if showGrid then drawGrid() end
            end
        end
    end)
end

-- ENTRY ----------------------------------------------------------------------

RegisterNetEvent("pup-camera:granted", function(data)
    maxRange = tonumber(data and data.maxRange) or 500.0
    open()
end)

RegisterNetEvent("pup-camera:denied", function()
    notify(Locale.noPermission)
end)

RegisterCommand(Config.General.command or "cam", function()
    if active then return close() end
    TriggerServerEvent("pup-camera:request")
end, false)

if Config.General.keybind and Config.General.keybind ~= "" then
    RegisterKeyMapping(Config.General.command or "cam", "Staff Camera", "keyboard", Config.General.keybind)
end

-- never leave somebody stuck in a floating camera
AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() and active then close() end
end)

CreateThread(function()
    if not rawOk then
        print("^3[pup-camera]^7 raw key natives unavailable - falling back to control bindings. "
            .. "[ ] roll, PgUp/PgDn zoom, P dolly and F1 help will not respond on this build.")
    end
    while true do
        Wait(500)
        if active and IsEntityDead(PlayerPedId()) then close() end
    end
end)
