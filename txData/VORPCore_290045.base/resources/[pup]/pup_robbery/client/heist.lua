-- pup_robbery | bank heists, client side: draws what the server snapshot shows and reports actions

Hst = { snap = nil }

local H = Config.Heist
local TAG = 'heist'
local busy = false
local props = {}        -- [key] = object, locally spawned prep and loot props
local escapeBlips = {}
local downedBank = nil
local lastGetaway = 0
local lastWalkIn = 0
local reportedDown = nil
local fx = {}           -- live effects: { obj, ptfx, untilMs, planter, pos, fuseEnds }

local function bankCfg() return Hst.snap and Config.Banks[Hst.snap.bank] or nil end

--------------------------------------------------------------------------------
-- props

local function dropProp(key)
    local o = props[key]
    if o and DoesEntityExist(o) then DeleteObject(o) end
    props[key] = nil
end

local function clearProps()
    for k in pairs(props) do dropProp(k) end
end

local function placeProp(key, model, pos, rot, heading, ground)
    if props[key] and DoesEntityExist(props[key]) then return end
    local hash = C.loadModel(model, 3000)
    if not hash then return end
    local o = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not o or o == 0 then return end
    if rot then SetEntityRotation(o, rot.x, rot.y, rot.z, 2, true)
    elseif heading then SetEntityHeading(o, heading + 0.0) end
    if ground then PlaceObjectOnGroundProperly(o, true) end
    FreezeEntityPosition(o, true)
    props[key] = o
end

local function refreshProps()
    local snap = Hst.snap
    local me = C.myPos()
    local range = H.effects.propRange
    local want = {}
    if snap and snap.prep then
        for _, box in ipairs(snap.prep.boxes) do
            if box.prop then
                local pos = C.v3(box.prop.pos)
                local key = 'prep' .. box.i
                if #(me - pos) <= range then
                    want[key] = true
                    placeProp(key, box.prop.model, pos, C.v3(box.prop.rot), box.prop.heading, false)
                end
            end
        end
    end
    if snap and snap.loot then
        for _, spot in ipairs(snap.loot) do
            if spot.prop then
                local pos = C.v3(spot.pos)
                if spot.prop.offset then pos = pos + C.v3(spot.prop.offset) end
                local key = 'loot' .. spot.i
                if #(me - pos) <= range then
                    want[key] = true
                    placeProp(key, spot.prop.model, pos, C.v3(spot.prop.rot), spot.prop.heading, spot.prop.ground)
                end
            end
        end
    end
    for k in pairs(props) do
        if not want[k] then dropProp(k) end
    end
end

CreateThread(function()
    while true do
        if Hst.snap then
            refreshProps()
            Wait(Hst.snap.stage == 'looting' and H.lootPropRefreshMs or H.propRefreshMs)
        else
            if next(props) then clearProps() end
            Wait(2000)
        end
    end
end)

--------------------------------------------------------------------------------
-- escape blips

local function clearEscape()
    for _, b in ipairs(escapeBlips) do C.removeBlip(b) end
    escapeBlips = {}
end

local function drawEscape(snap)
    clearEscape()
    if not snap or not snap.getaway then return end
    for _, z in ipairs(snap.getaway.zones or {}) do
        escapeBlips[#escapeBlips + 1] = C.blipAt(C.v3(z.pos), 90287351, 0.8, L('escapeBlip', z.label or ''))
    end
end

--------------------------------------------------------------------------------
-- snapshots

local function hudOff()
    TriggerEvent('fred_hud:heist', { active = false })
end

RegisterNetEvent('pup_robbery:heist:snapshot', function(snap)
    if not snap then
        if Hst.snap then
            Hst.snap = nil
            clearProps()
            clearEscape()
            hudOff()
        end
        downedBank = nil
        return
    end
    downedBank = nil
    snap.receivedAt = GetGameTimer()
    Hst.snap = snap
    drawEscape(snap)
end)

RegisterNetEvent('pup_robbery:heist:downed', function(bankId)
    downedBank = bankId
end)

-- fred_hud gauges
CreateThread(function()
    while true do
        local snap = Hst.snap
        if snap then
            local pct = 100
            if snap.insideLeft and snap.insideTotal and snap.insideTotal > 0 then
                local left = snap.insideLeft - (GetGameTimer() - snap.receivedAt) / 1000
                pct = math.max(0, math.min(100, left / snap.insideTotal * 100))
            end
            TriggerEvent('fred_hud:heist', { active = true, timer = pct, alarm = snap.alarm or 0, alarmMax = snap.alarmMax or H.alarmMax })
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

--------------------------------------------------------------------------------
-- attempts (the token flow)

local function holdDynamite()
    local hash = C.loadModel('p_dynamite01x', 2000)
    if not hash then return nil end
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local o = CreateObject(hash, p.x, p.y, p.z, false, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    local bone = GetEntityBoneIndexByName(ped, 'SKEL_R_Hand')
    AttachEntityToEntity(o, ped, bone, 0.08, 0.02, -0.02, 0.0, 0.0, 0.0, false, false, false, false, 2, true, false, false)
    return o
end

local function attempt(kind, ref, useAlt)
    if busy or not Hst.snap then return end
    busy = true
    local bank = Hst.snap.bank
    CreateThread(function()
        local r = C.cb('pup_robbery:heist:attempt', bank, kind, ref, useAlt == true)
        if type(r) ~= 'table' or not r.ok then
            if type(r) == 'table' and r.msg then C.toast(r.msg) end
            busy = false
            return
        end
        local ped = PlayerPedId()
        local won
        FreezeEntityPosition(ped, true)
        if r.game == 'dynamite' then
            won = true
            if r.placement then
                C.playAnim(r.anim or H.inspectAnim)
                won = C.heistGame(r.placement, nil)
            end
            if won then
                local stick = holdDynamite()
                C.playAnim(r.anim or H.inspectAnim)
                Wait(H.chargeAnimMs)
                if stick and DoesEntityExist(stick) then DeleteObject(stick) end
            end
        else
            C.playAnim(r.anim or H.defaultAnim)
            won = C.heistGame(r.game, r.opts)
        end
        FreezeEntityPosition(ped, false)
        C.stopAnim()
        TriggerServerEvent('pup_robbery:heist:report', bank, r.token, won == true)
        busy = false
    end)
end

local function grab(i)
    if busy or not Hst.snap then return end
    busy = true
    local bank = Hst.snap.bank
    CreateThread(function()
        local a = C.playAnim(H.grabAnim, false)
        if a then Wait(1500) end
        C.stopAnim()
        TriggerServerEvent('pup_robbery:heist:grab', bank, i)
        busy = false
    end)
end

--------------------------------------------------------------------------------
-- the heist tools as usable items

RegisterNetEvent('pup_robbery:heist:useItem', function(item)
    local snap, b = Hst.snap, bankCfg()
    if not snap or not b then return C.toast(L('nothingToUse')) end
    local me = C.myPos()
    local reachIn = snap.entry and b.insideRange or b.interactRange
    if snap.stage == 'claimed' then
        if snap.prep and snap.prep.tool == item then
            for _, box in ipairs(snap.prep.boxes) do
                if #(me - C.v3(box.pos)) <= b.interactRange then return attempt('prep', box.i, false) end
            end
        end
        for _, e in ipairs(snap.entries or {}) do
            if e.tool == item and #(me - C.v3(e.pos)) <= b.interactRange then
                if e.blocked then return C.toast(L('alarmLive')) end
                if e.lock then return attempt('entry', e.key, false) end
                return TriggerServerEvent('pup_robbery:heist:enter', snap.bank, e.key)
            end
        end
    end
    if snap.stage == 'vault' or snap.stage == 'looting' then
        for _, d in ipairs(snap.doors or {}) do
            if d.tool == item and #(me - C.v3(d.pos)) <= reachIn then return attempt('door', d.i, false) end
        end
    end
    if snap.stage == 'vault' and snap.step and #(me - C.v3(snap.step.pos)) <= reachIn then
        if snap.step.alt and snap.step.alt.tool == item then return attempt('stage', snap.step.idx, true) end
        if snap.step.tool == item then return attempt('stage', snap.step.idx, false) end
    end
    local fb = H.lockpickFallback
    if fb and item == fb.item and GetResourceState(fb.resource) == 'started' then
        return TriggerEvent(fb.event)
    end
    C.toast(L('notHere'))
end)

--------------------------------------------------------------------------------
-- guards, at the alarm level the bank holds them for (leader's client)

local guardSweep = 0

RegisterNetEvent('pup_robbery:heist:guards', function(bankId)
    local b = Config.Banks[bankId]
    if not b then return end
    guardSweep = guardSweep + 1 -- a new set of guards cancels any pending clean-up
    CreateThread(function()
        for _, def in ipairs(b.guards or {}) do Guards.spawn(def, TAG) end
    end)
end)

-- the run is over: the guards this client spawned go once it is clear of the bank, or after a while
RegisterNetEvent('pup_robbery:heist:ended', function(bankId)
    local b = Config.Banks[bankId]
    guardSweep = guardSweep + 1
    local mine = guardSweep
    CreateThread(function()
        local untilMs = GetGameTimer() + (H.guardLingerMs or 120000)
        while GetGameTimer() < untilMs and guardSweep == mine do
            if b and #(C.myPos() - b.anchor) > (H.guardClearRange or 150.0) then break end
            Wait(2000)
        end
        if guardSweep == mine then Guards.clear(TAG) end
    end)
end)

--------------------------------------------------------------------------------
-- world effects: the charge and the blast

local function loopFx(asset, name, pos, scale)
    local handle = nil
    pcall(function()
        local h = GetHashKey(asset)
        RequestNamedPtfxAsset(h)
        local t = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded(h) and GetGameTimer() < t do Wait(10) end
        UseParticleFxAsset(asset)
        handle = StartParticleFxLoopedAtCoord(name, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, scale or 1.0, false, false, false, false)
    end)
    return handle
end

local function stopFx(handle)
    if handle then pcall(StopParticleFxLooped, handle, false) end
end

RegisterNetEvent('pup_robbery:heist:fx', function(kind, data)
    if type(data) ~= 'table' or not data.pos then return end
    local pos = C.v3(data.pos)
    local d = #(C.myPos() - pos)
    if kind == 'charge' then
        if d > H.effects.propRange then return end
        local e = { pos = pos, fuseEnds = GetGameTimer() + (tonumber(data.fuse) or H.defaultFuse) * 1000,
                    planter = data.planter == GetPlayerServerId(PlayerId()) }
        local hash = C.loadModel('p_dynamite01x', 2000)
        if hash then
            e.obj = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            PlaceObjectOnGroundProperly(e.obj, true)
        end
        e.ptfx = loopFx('core', 'ent_sht_electrical_box', pos, 0.6)
        fx[#fx + 1] = e
        if e.planter then
            CreateThread(function()
                while GetGameTimer() < e.fuseEnds do
                    if #(C.myPos() - pos) <= H.effects.fuseBarRange then
                        local frac = (e.fuseEnds - GetGameTimer()) / ((tonumber(data.fuse) or H.defaultFuse) * 1000)
                        DrawRect(0.5, 0.93, 0.2, 0.014, 0, 0, 0, 170, false, false)
                        DrawRect(0.5 - 0.1 + 0.1 * frac, 0.93, 0.2 * frac, 0.01, 220, 120, 30, 230, false, false)
                        Wait(0)
                    else
                        Wait(250)
                    end
                end
            end)
        end
    elseif kind == 'blast' then
        for i = #fx, 1, -1 do
            local e = fx[i]
            if #(e.pos - pos) < 1.0 then
                stopFx(e.ptfx)
                if e.obj and DoesEntityExist(e.obj) then DeleteObject(e.obj) end
                table.remove(fx, i)
            end
        end
        if d > H.effects.blastRange then return end
        AddExplosion(pos.x, pos.y, pos.z, H.effects.explosionType, 1.0, true, false, H.effects.cameraShake)
        local smoke = loopFx('scr_odd_fellows', 'scr_river5_magician_smoke_loop', pos, 1.0)
        SetTimeout(H.effects.smokeSeconds * 1000, function() stopFx(smoke) end)
    end
end)

local function clearFx()
    for _, e in ipairs(fx) do
        stopFx(e.ptfx)
        if e.obj and DoesEntityExist(e.obj) then DeleteObject(e.obj) end
    end
    fx = {}
end

--------------------------------------------------------------------------------
-- the frame loop: prompts for the current step only

local function label(pos, text, r, g, b)
    C.text3D(pos + vector3(0.0, 0.0, 0.35), text, r, g, b)
end

local function tick(snap, b)
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    local sleep = 500

    if C.dead() then
        if reportedDown ~= snap.snapId then
            reportedDown = snap.snapId
            TriggerServerEvent('pup_robbery:heist:down', snap.bank, snap.snapId)
        end
        return 1000
    end

    if #(me - b.anchor) > (b.getawayRange + 300.0) and snap.stage ~= 'looting' and snap.stage ~= 'escape' and snap.stage ~= 'claimed' then
        return 1000
    end

    local reachIn = snap.entry and b.insideRange or b.interactRange
    local key = Config.InteractKeyLabel

    if snap.stage == 'claimed' then
        if snap.prep then
            for _, box in ipairs(snap.prep.boxes) do
                local pos = C.v3(box.pos)
                local d = #(me - pos)
                if d < b.promptRange then
                    sleep = 0
                    if d <= b.interactRange and not busy then
                        label(pos, ('[%s] %s'):format(key, snap.prep.label))
                        if C.pressed() then attempt('prep', box.i, false) end
                    end
                end
            end
        end
        for _, e in ipairs(snap.entries or {}) do
            local pos = C.v3(e.pos)
            local d = #(me - pos)
            if d < b.promptRange then
                sleep = 0
                if d <= b.interactRange and not busy then
                    if e.blocked then
                        label(pos, e.label .. ' ' .. L('alarmFirst'), 200, 60, 60)
                    elseif e.walkIn then
                        if GetGameTimer() - lastWalkIn > H.walkInDebounceMs then
                            lastWalkIn = GetGameTimer()
                            TriggerServerEvent('pup_robbery:heist:enter', snap.bank, e.key)
                        end
                    else
                        label(pos, ('[%s] %s'):format(key, e.label))
                        if C.pressed() then
                            if e.lock then attempt('entry', e.key, false)
                            else TriggerServerEvent('pup_robbery:heist:enter', snap.bank, e.key) end
                        end
                    end
                end
            end
        end
    end

    if snap.stage == 'vault' and snap.step then
        local st = snap.step
        local pos = C.v3(st.pos)
        local d = #(me - pos)
        if d < b.promptRange then
            sleep = 0
            if b.stagePrompts and d > reachIn then label(pos, st.label, 200, 200, 200) end
            if d <= reachIn and not busy and not st.armed then
                if st.alt then
                    C.text3D(pos + vector3(0.0, 0.0, 0.55), L('useAltLine', st.alt.toolLabel or st.alt.tool, st.alt.label), 220, 180, 90)
                end
                label(pos, ('[%s] %s'):format(key, st.label))
                if C.pressed() then attempt('stage', st.idx, false) end
            end
        end
    end

    if snap.stage == 'vault' or snap.stage == 'looting' then
        if snap.clue then
            local pos = C.v3(snap.clue.pos)
            local d = #(me - pos)
            if d < b.promptRange then
                sleep = 0
                if d <= reachIn and not busy and C.clearSight('clue', pos) then
                    label(pos, ('[%s] %s'):format(key, snap.clue.label))
                    if C.pressed() then
                        if snap.clue.game then attempt('clue', 0, false)
                        else TriggerServerEvent('pup_robbery:heist:clue', snap.bank) end
                    end
                end
            end
        end
        for _, door in ipairs(snap.doors or {}) do
            local pos = C.v3(door.pos)
            local d = #(me - pos)
            if d < b.promptRange then
                sleep = 0
                if d <= reachIn and not busy then
                    label(pos, ('[%s] %s'):format(key, door.label or ''))
                    if C.pressed() then attempt('door', door.i, false) end
                end
            end
        end
    end

    if snap.stage == 'looting' and H.lootPrompts then
        for _, spot in ipairs(snap.loot or {}) do
            local pos = C.v3(spot.pos)
            local d = #(me - pos)
            if d < b.lootRange + 2.0 then
                sleep = 0
                if d <= b.lootRange and not busy and C.clearSight('loot' .. spot.i, pos) then
                    label(pos, ('[%s] %s'):format(key, spot.safe and spot.label or L('grabPrompt')))
                    if C.pressed() then
                        if spot.safe then attempt('safe', spot.i, false) else grab(spot.i) end
                    end
                end
            end
        end
    end

    if snap.getaway then
        local ga = snap.getaway
        if #(ga.zones or {}) > 0 then
            for _, z in ipairs(ga.zones) do
                if #(me - C.v3(z.pos)) <= (z.radius or 10.0) and GetGameTimer() - lastGetaway > H.getawayReportMs then
                    lastGetaway = GetGameTimer()
                    TriggerServerEvent('pup_robbery:heist:getaway', snap.bank, z.i)
                end
            end
        else
            local d = #(me - C.v3(ga.anchor))
            if d >= ga.range then
                if GetGameTimer() - lastGetaway > H.getawayReportMs then
                    lastGetaway = GetGameTimer()
                    TriggerServerEvent('pup_robbery:heist:getaway', snap.bank, nil)
                end
            elseif snap.stage == 'escape' then
                C.text2D(L('toClear', math.ceil(ga.range - d)), 0.5, 0.05, 0.42)
                sleep = 0
            end
        end
    end

    return sleep
end

CreateThread(function()
    while true do
        local snap, b = Hst.snap, bankCfg()
        if snap and b then
            Wait(tick(snap, b))
        elseif downedBank then
            -- a downed rider who gets back up asks to rejoin
            if not C.dead() then TriggerServerEvent('pup_robbery:heist:revived', downedBank) end
            Wait(5000)
        else
            Wait(1000)
        end
    end
end)

function Hst.cleanup()
    clearProps()
    clearEscape()
    clearFx()
    Guards.clear(TAG)
    hudOff()
    if busy then
        FreezeEntityPosition(PlayerPedId(), false)
        C.stopAnim()
    end
end
