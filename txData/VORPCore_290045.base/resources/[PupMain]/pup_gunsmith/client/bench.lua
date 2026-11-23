-- pup_gunsmith | customization bench (bench user's side): the page, the camera, the gun on the bench
-- The page (html/bench.*) draws everything; this file owns the game side and talks to the server.

BenchCl = {}

local S = nil      -- the open bench session
local session = 0  -- bumped on every open, so a stale frame loop stops

local PTT <const> = `INPUT_PUSH_TO_TALK`
local RADIO <const> = 249

local TYPE_CHECKS <const> = {
    knife    = 0x792E3EF76C911959,
    repeater = 0xDDB2578E95EF7138,
    rifle    = 0x0A82317B7EBFC420,
    sniper   = 0x6AD66548840472E5,
    shotgun  = 0xC75386174ECE95D5,
    pistol   = 0xDDC64F5E31EEDAB6,
    revolver = 0xC212F1D05A8232BB,
}

local function isType(kind, hash)
    local ok, r = pcall(Citizen.InvokeNative, TYPE_CHECKS[kind], hash, Citizen.ResultAsInteger())
    return ok and r == 1
end

-- thrown blades have no type check of their own
local THROWN_BLADES <const> = { 'WEAPON_THROWN_TOMAHAWK', 'WEAPON_THROWN_THROWING_KNIVES' }

--- the gun's family from the game's weapon-type checks
function BenchCl.familyOf(hash, name)
    local up = tostring(name or ''):upper()
    if isType('knife', hash) then return 'MELEE_BLADE' end
    for _, p in ipairs(THROWN_BLADES) do
        if up:sub(1, #p) == p then return 'MELEE_BLADE' end
    end
    if isType('repeater', hash) or isType('rifle', hash) or isType('sniper', hash) then return 'LONGARM' end
    if isType('shotgun', hash) then return 'SHOTGUN' end
    if isType('pistol', hash) or isType('revolver', hash) then return 'SHORTARM' end
    return nil
end

---------------------------------------------------------------------------
-- HUD: hidden only if the radar was showing; only what we hid comes back
---------------------------------------------------------------------------
local hudHidden = false

local function setHud(show)
    if GetResourceState('vorp_core') == 'started' and pcall(function() exports.vorp_core:SetAllUI(show) end) then
        return
    end
    DisplayRadar(show)
    DisplayHud(show)
    TriggerEvent('fred_hud:setVisible', show)
end

local function hideHud()
    if hudHidden or IsRadarHidden() then return end
    hudHidden = true
    setHud(false)
end

local function restoreHud()
    if not hudHidden then return end
    hudHidden = false
    setHud(true)
end

-- pup-ui hid everything on purpose: it is no longer ours to give back
AddEventHandler('pup-ui:HideAllUI', function() hudHidden = false end)

---------------------------------------------------------------------------
-- camera and view
---------------------------------------------------------------------------
local CAM = Config.Bench.camera

local function resetView()
    if not S then return end
    S.view = { elev = CAM.startElev, zoom = 1.0, yaw = 0.0, roll = 0.0, pitch = 0.0 }
    S.turnDirty = true
end

local function camGoal()
    local g, v = S.gun, S.view
    local dist = S.baseDist * v.zoom
    local e = math.rad(v.elev)
    return g.pivot + vector3(math.cos(e) * math.cos(S.camYaw) * dist, math.cos(e) * math.sin(S.camYaw) * dist, math.sin(e) * dist)
end

local function createCamera()
    local g = S.gun
    -- the camera sits on the player's side of the bench, so it never ends up in a wall
    local me = GetEntityCoords(PlayerPedId())
    S.camYaw = math.atan(me.y - g.pivot.y, me.x - g.pivot.x)
    S.baseDist = GS.clamp(g.size * 1.25, 0.45, 2.2)
    local pos = camGoal()
    S.camPos = pos
    if not S.cam then
        S.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, CAM.fov + 0.0, false, 0)
        SetCamActive(S.cam, true)
        PointCamAtCoord(S.cam, g.pivot.x, g.pivot.y, g.pivot.z)
        RenderScriptCams(true, true, CAM.easeIn, true, true, 0)
    else
        SetCamCoord(S.cam, pos.x, pos.y, pos.z)
        PointCamAtCoord(S.cam, g.pivot.x, g.pivot.y, g.pivot.z)
    end
end

local function releaseCamera(st, instant)
    local cam = st.cam
    st.cam = nil
    if not cam then return end
    if instant then
        RenderScriptCams(false, false, 0, true, true, 0)
        DestroyCam(cam, false)
        return
    end
    RenderScriptCams(false, true, CAM.easeOut, true, true, 0)
    SetTimeout(CAM.easeOut + 100, function() DestroyCam(cam, false) end)
end

---------------------------------------------------------------------------
-- the gun on the bench
---------------------------------------------------------------------------
local function clearGun(st)
    if st.gun then
        GunObj.delete(st.gun)
        st.gun = nil
    end
end

local function variantsOf(cat)
    return GunObj.variants(S.catalogue, cat, S.fitted[cat])
end

local function refitTints()
    for cat, comp in pairs(S.sel) do
        if Catalogue.isTint(cat) then GunObj.fit(S.gun, comp) end
    end
end

-- a part is acceptable when it is in this gun's catalogue, or it is exactly what is fitted
local function acceptable(cat, comp)
    if comp == nil then return cat ~= 'GRIP' end
    return Catalogue.find(cat, comp, S.catalogue) ~= nil or S.fitted[cat] == comp
end

local function relayPart(cat)
    TriggerServerEvent('pup_gunsmith:benchPart', cat, S.sel[cat] or false)
end

---------------------------------------------------------------------------
-- per-frame work while the bench is open
---------------------------------------------------------------------------
local function frameLoop(mySession)
    CreateThread(function()
        local lastTurnSent = 0
        while S and session == mySession do
            local dt = GetFrameTime()
            local ped = PlayerPedId()

            -- the player can still talk; everything else is the page's
            DisableAllControlActions(0)
            EnableControlAction(0, PTT, true)
            if LocalPlayer.state.pup_ptt_latched then SetControlNormal(0, PTT, 1.0) end
            if LocalPlayer.state.pup_radio_talking then EnableControlAction(0, RADIO, true) end

            if IsEntityDead(ped) then
                BenchCl.close(true, true)
                break
            end

            if S.gun and S.cam then
                local v, ax = S.view, S.axis
                if ax.turn ~= 0 or ax.roll ~= 0 then
                    v.yaw = (v.yaw + ax.turn * CAM.turnSpeed * dt) % 360
                    v.roll = (v.roll + ax.roll * CAM.turnSpeed * dt) % 360
                    S.turnDirty = true
                end
                if ax.tilt ~= 0 then
                    v.elev = GS.clamp(v.elev + ax.tilt * CAM.tiltSpeed * dt, CAM.minElev, CAM.maxElev)
                end
                if S.turnDirty then
                    GunObj.rotate(S.gun, v.pitch, v.roll, v.yaw)
                end

                local goal = camGoal()
                local k = math.min(1.0, dt * CAM.glide)
                S.camPos = S.camPos + (goal - S.camPos) * k
                SetCamCoord(S.cam, S.camPos.x, S.camPos.y, S.camPos.z)
                PointCamAtCoord(S.cam, S.gun.pivot.x, S.gun.pivot.y, S.gun.pivot.z)

                local L0 = Config.Bench.light
                local p = S.gun.pivot
                Citizen.InvokeNative(0xD2D9E04C0DF927F4, p.x, p.y, p.z + L0.height, L0.r, L0.g, L0.b, L0.range, L0.intensity) -- DRAW_LIGHT_WITH_RANGE

                -- watchers get the turn at most every 120 ms, and only when it changed
                local now = GetGameTimer()
                if S.turnDirty and now - lastTurnSent >= 120 then
                    lastTurnSent = now
                    S.turnDirty = false
                    TriggerServerEvent('pup_gunsmith:benchTurn', v.pitch, v.roll, v.yaw)
                end
            end
            Wait(0)
        end
    end)
end

---------------------------------------------------------------------------
-- open / close
---------------------------------------------------------------------------
local function pageGuns(guns)
    local out = {}
    for _, g in ipairs(guns or {}) do
        out[#out + 1] = {
            id = g.id, name = g.name, label = g.label, serial = g.serial,
            parts = GS.count(g.parts),
        }
    end
    return out
end

function BenchCl.open(bench)
    local res = Cl.rpc('benchOpen', bench.id)
    if not res or not res.ok then
        Cl.busy = nil
        Cl.tip((res and res.msg) or L('no_job_bench'))
        return
    end
    session = session + 1
    S = {
        bench = bench, guns = res.guns or {}, wallet = res.wallet or {},
        gun = nil, catalogue = {}, fitted = {}, sel = {},
        axis = { turn = 0, tilt = 0, roll = 0 },
        working = false,
    }
    Cl.busy = 'bench'

    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    SetEntityHeading(ped, (math.deg(math.atan(bench.gun.y - me.y, bench.gun.x - me.x)) - 90.0) % 360)
    FreezeEntityPosition(ped, true)
    hideHud()

    local theme = nil
    pcall(function() theme = exports['pup-ui']:GetTheme() end)
    -- the player's menu side; without pup-ui the bench keeps its panel on the right
    local side = 'right'
    pcall(function() if exports['pup-ui']:GetMenuSide() == 'left' then side = 'left' end end)

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        type = 'open',
        side = side,
        bench = res.bench,
        guns = pageGuns(res.guns),
        wallet = res.wallet,
        wear = res.wear == true,
        text = BenchText,
        names = { weapons = Config.WeaponNames, categories = Config.CategoryNames },
        cfg = {
            workMs = Config.Bench.workMs,
            repairMs = Config.Repair.workMs,
            tierMs = Config.Tier.workMs,
            tierMax = Config.Tier.max,
            maxParts = Config.Bench.maxParts,
            presetLimit = Config.Bench.presetLimit,
        },
        theme = theme,
    })
    frameLoop(session)
end

--- tellServer: end the server session too; instant: no camera ease (death, stop)
function BenchCl.close(tellServer, instant)
    local st = S
    if not st then return end
    S = nil
    SendNUIMessage({ type = 'close' })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    releaseCamera(st, instant)
    clearGun(st)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    restoreHud()
    if tellServer then TriggerServerEvent('pup_gunsmith:benchLeave') end
    if Cl.busy == 'bench' then Cl.busy = nil end
end

function BenchCl.isOpen() return S ~= nil end

-- the server ended the session (job lost, walked off, character change)
RegisterNetEvent('pup_gunsmith:benchClose', function()
    BenchCl.close(false, false)
end)

---------------------------------------------------------------------------
-- page callbacks
---------------------------------------------------------------------------
local function reply(cb, t) cb(t or { ok = false }) end

RegisterNUICallback('leave', function(_, cb)
    if not S or S.working then return reply(cb) end
    BenchCl.close(true, false)
    reply(cb, { ok = true })
end)

RegisterNUICallback('pick', function(data, cb)
    if not S or S.working or S.picking then return reply(cb) end
    local id = tonumber(type(data) == 'table' and data.id)
    local gun
    for _, g in ipairs(S.guns) do if g.id == id then gun = g break end end
    if not gun then return reply(cb, { ok = false, msg = L('not_carrying') }) end

    local st = S
    st.picking = true
    local hash = joaat(gun.name:upper())
    local family = BenchCl.familyOf(hash, gun.name)
    local res = Cl.rpc('benchSelect', gun.id, family)
    if S ~= st then return reply(cb) end
    if not res or not res.ok then
        st.picking = false
        return reply(cb, { ok = false, msg = res and res.msg })
    end

    clearGun(st)
    local obj = GunObj.spawn(hash, st.bench.gun)
    st.picking = false
    if S ~= st then
        GunObj.delete(obj)
        return reply(cb)
    end
    if not obj then
        CreateThread(function() Cl.rpc('benchPutAway') end)
        return reply(cb, { ok = false, msg = BenchText.spawnFailed })
    end

    st.gun = obj
    st.gunId = gun.id
    st.catalogue = type(res.catalogue) == 'table' and res.catalogue or {}
    st.fitted = GS.cleanParts(res.fitted, Config.Bench.maxParts)
    st.sel = GS.copy(st.fitted)
    GunObj.fitAll(obj, st.catalogue, st.sel, st.fitted)
    resetView()
    createCamera()
    reply(cb, {
        ok = true,
        fitted = st.fitted,
        catalogue = st.catalogue,
        card = res.card,
        wallet = res.wallet,
        presets = res.presets,
    })
end)

RegisterNUICallback('putAway', function(_, cb)
    if not S or S.working or not S.gun then return reply(cb) end
    local st = S
    clearGun(st)
    releaseCamera(st, false)
    st.sel, st.fitted, st.catalogue = {}, {}, {}
    st.axis = { turn = 0, tilt = 0, roll = 0 }
    CreateThread(function() Cl.rpc('benchPutAway') end)
    reply(cb, { ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    if not S or not S.gun or type(data) ~= 'table' or type(data.cat) ~= 'string' then return reply(cb) end
    local cat = data.cat:upper()
    local comp = type(data.comp) == 'string' and data.comp:upper() or nil
    if not acceptable(cat, comp) then return reply(cb) end
    S.sel[cat] = comp
    GunObj.swap(S.gun, variantsOf(cat), comp)
    if not Catalogue.isTint(cat) then refitTints() end
    relayPart(cat)
    reply(cb, { ok = true })
end)

-- a whole look at once (undo all, a preset laid out)
RegisterNUICallback('refit', function(data, cb)
    if not S or not S.gun or type(data) ~= 'table' then return reply(cb) end
    local set = {}
    for cat, comp in pairs(GS.cleanParts(data.set, Config.Bench.maxParts)) do
        if acceptable(cat, comp) then set[cat] = comp end
    end
    if S.fitted.GRIP and not set.GRIP then set.GRIP = S.fitted.GRIP end
    S.sel = set
    GunObj.fitAll(S.gun, S.catalogue, S.sel, S.fitted)
    if type(data.changed) == 'table' then
        local n = 0
        for _, cat in ipairs(data.changed) do
            if type(cat) == 'string' and n < Config.Bench.maxParts then
                n = n + 1
                relayPart(cat:upper())
            end
        end
    end
    reply(cb, { ok = true, set = S.sel })
end)

-- the notebook scenario plays only while a change, repair or temper is being worked
local function workAnim(on)
    local ped = PlayerPedId()
    if on then
        TaskStartScenarioInPlaceHash(ped, joaat(Config.Bench.scenario), -1, true, false, false, false)
    else
        ClearPedTasks(ped)
    end
end

RegisterNUICallback('busy', function(data, cb)
    if S then
        S.working = type(data) == 'table' and data.on == true
        workAnim(S.working)
    end
    reply(cb, { ok = true })
end)

-- a server action that may take money; the session counts as working until it answers
local function serverWork(name, ...)
    if not S then return nil end
    if not S.gun then
        S.working = false -- the page may have flagged work already; never leave it stuck
        workAnim(false)
        return nil
    end
    local st = S
    st.working = true
    local res = Cl.rpc(name, ...)
    if S == st then
        st.working = false
        workAnim(false)
    end
    return res
end

RegisterNUICallback('confirm', function(data, cb)
    local set = type(data) == 'table' and data.set or nil
    local res = serverWork('benchConfirm', set)
    if res and res.ok and S and S.gun then
        S.fitted = GS.cleanParts(res.set, Config.Bench.maxParts)
        S.sel = GS.copy(S.fitted)
        for _, g in ipairs(S.guns) do
            if g.id == S.gunId then g.parts = GS.copy(S.fitted) end
        end
    end
    reply(cb, res)
end)

RegisterNUICallback('card', function(_, cb)
    if not S or not S.gun then return reply(cb) end
    reply(cb, Cl.rpc('benchCard'))
end)

RegisterNUICallback('repair', function(_, cb)
    reply(cb, serverWork('benchRepair'))
end)

RegisterNUICallback('tier', function(_, cb)
    reply(cb, serverWork('benchTier'))
end)

RegisterNUICallback('presetSave', function(data, cb)
    if not S or not S.gun or type(data) ~= 'table' then return reply(cb) end
    reply(cb, Cl.rpc('benchPresetSave', data.name, data.set))
end)

RegisterNUICallback('presetDelete', function(data, cb)
    if not S or not S.gun or type(data) ~= 'table' then return reply(cb) end
    reply(cb, Cl.rpc('benchPresetDelete', data.id))
end)

-- held keys arrive as axes (-1, 0, 1), only when they change
RegisterNUICallback('axis', function(data, cb)
    if S and type(data) == 'table' then
        local function axis(v) v = tonumber(v) or 0; return v > 0 and 1 or (v < 0 and -1 or 0) end
        S.axis = { turn = axis(data.turn), tilt = axis(data.tilt), roll = axis(data.roll) }
    end
    reply(cb, { ok = true })
end)

RegisterNUICallback('drag', function(data, cb)
    if S and S.gun and S.view and type(data) == 'table' then
        local dx, dy = tonumber(data.dx) or 0, tonumber(data.dy) or 0
        dx, dy = GS.clamp(dx, -2000, 2000), GS.clamp(dy, -2000, 2000)
        S.view.yaw = (S.view.yaw + dx * 0.35) % 360
        S.view.elev = GS.clamp(S.view.elev + dy * 0.25, CAM.minElev, CAM.maxElev)
        S.turnDirty = true
    end
    reply(cb, { ok = true })
end)

RegisterNUICallback('zoom', function(data, cb)
    if S and S.view and type(data) == 'table' then
        local n = GS.clamp(tonumber(data.notches) or 0, -10, 10)
        S.view.zoom = GS.clamp(S.view.zoom + n * 0.08, CAM.zoomMin, CAM.zoomMax)
    end
    reply(cb, { ok = true })
end)

RegisterNUICallback('reset', function(_, cb)
    if S and S.gun then resetView() end
    reply(cb, { ok = true })
end)

-- while a preset name is typed, the game gets no keys at all
RegisterNUICallback('typing', function(data, cb)
    if S then SetNuiFocusKeepInput(not (type(data) == 'table' and data.on == true)) end
    reply(cb, { ok = true })
end)

---------------------------------------------------------------------------
-- stop: release everything at once
---------------------------------------------------------------------------
function BenchCl.stop()
    BenchCl.close(false, true)
end
