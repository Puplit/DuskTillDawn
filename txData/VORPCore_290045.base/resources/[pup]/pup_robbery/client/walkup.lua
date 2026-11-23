-- pup_robbery | walk-up robberies, client side: starting, boxes, the unlock clock, waves and guards

Walk = { job = nil }

local W = Config.Walkup
local TAG = 'walkup'
local bandana, bandanaAt = false, 0
local starting = false
local working = false
local placeBlips = {}

--------------------------------------------------------------------------------
-- the bandana (pup-misc)

AddEventHandler('pup-misc:bandanaState', function(up)
    bandana = up == true
    bandanaAt = GetGameTimer()
end)

local function masked()
    if not Config.MaskRequired then return true end
    local now = GetGameTimer()
    if now - bandanaAt >= (W.bandanaPollMs or 250) then
        bandanaAt = now
        if GetResourceState('pup-misc') == 'started' then
            local ok, up = pcall(function() return exports['pup-misc']:IsBandanaUp() end)
            if ok then bandana = up == true end
        else
            bandana = false
        end
    end
    return bandana
end

--------------------------------------------------------------------------------
-- starting

local function firedGun(ped)
    if not IsPedShooting(ped) then return false end
    local _, weapon = GetCurrentPedWeapon(ped, true, 0, true)
    if not weapon or weapon == 0 then return false end
    local bow = Citizen.InvokeNative(0xC4DEC3CA8C365A5D, weapon)
    local thrown = Citizen.InvokeNative(0x30E7C16B12DA8211, weapon)
    return not (bow == true or bow == 1) and not (thrown == true or thrown == 1)
end

local function attempt(placeId)
    if starting then return end
    starting = true
    CreateThread(function()
        local r = C.cb('pup_robbery:walkup:precheck', placeId)
        if type(r) == 'table' then
            if r.ok then
                TriggerServerEvent('pup_robbery:walkup:start', placeId)
            elseif r.law then
                C.tip(L('notEnoughLaw', r.need or 0), 5000)
                C.tip(L('lawCount', r.have or 0), 5000)
            elseif r.msg then
                C.tip(r.msg, 5000)
            end
        end
        Wait(2000)
        starting = false
    end)
end

local function idleTick()
    local ped = PlayerPedId()
    if C.dead() then return 1000 end
    local pos = GetEntityCoords(ped)
    local nearest, nd = nil, math.huge
    for id, p in pairs(Config.Places) do
        local d = #(pos - p.anchor)
        if d < nd then nearest, nd = id, d end
    end
    if not nearest or nd > 60.0 then return 1000 end
    if not masked() then return 250 end
    local p = Config.Places[nearest]
    if nd > p.startRadius then return 200 end
    if p.start == 'press' then
        C.text2D(L('pressToStart', Config.InteractKeyLabel), 0.5, 0.88, 0.42)
        if C.pressed() then attempt(nearest) end
    else
        C.text2D(L('shootToStart'), 0.5, 0.88, 0.42)
        if firedGun(ped) then attempt(nearest) end
    end
    return 0
end

--------------------------------------------------------------------------------
-- the job

local function stopTimer()
    pcall(function() exports.vorp_core:TimerStop() end)
end

local function clearBoxBlips(job)
    for i, b in pairs(job.boxBlips or {}) do
        C.removeBlip(b)
        job.boxBlips[i] = nil
    end
end

function Walk.finish(report)
    local job = Walk.job
    if not job then return end
    Walk.job = nil
    Guards.clear(TAG)
    Guards.clearRemote()
    clearBoxBlips(job)
    stopTimer()
    TriggerEvent('inv:dropstatus', true)
    TriggerEvent('inv:givestatus', true)
    if working then
        FreezeEntityPosition(PlayerPedId(), false)
        C.stopAnim()
    end
    if report then TriggerServerEvent('pup_robbery:walkup:leave', job.id) end
end

local function startClock(job, seconds)
    if seconds <= 0 then
        job.open = true
        return
    end
    job.unlockAt = GetGameTimer() + seconds * 1000
    pcall(function() exports.vorp_core:TimerStart(seconds, W.timerLowSeconds) end)
    CreateThread(function()
        while Walk.job == job and not job.open do
            local left = math.ceil((job.unlockAt - GetGameTimer()) / 1000)
            if left <= 0 then
                job.open = true
                break
            end
            pcall(function() exports.vorp_core:TimerUpdate(left, W.timerLowSeconds) end)
            Wait(1000)
        end
        stopTimer()
    end)
end

-- the controller: plain guards once, or the waves
local function runControl(job, fromWave)
    local p = job.place
    CreateThread(function()
        if p.waves then
            local posts = U.wavePosts(p)
            for w = math.max(1, fromWave or 1), p.waves.count do
                if Walk.job ~= job or not job.controller then return end
                TriggerServerEvent('pup_robbery:walkup:wave', job.id, w)
                C.tip(L('waveStart', w, p.waves.count), 4000)
                -- repeated only when a staff world cleanup deleted the wave (see guards.lua)
                repeat
                    Guards.wiped = false
                    for _, def in ipairs(posts) do
                        if Walk.job ~= job then return end
                        Guards.spawn(def, TAG)
                    end
                    TriggerServerEvent('pup_robbery:walkup:guards', job.id, Guards.netIds(TAG))
                    while Walk.job == job and Guards.alive(TAG) > 0 do Wait(1000) end
                    if Walk.job ~= job then return end
                    Guards.clear(TAG)
                until not Guards.wiped
                if w < p.waves.count then
                    C.tip(L('waveCleared', p.waves.count - w), 4000)
                    Wait((p.waves.gap or 10) * 1000)
                end
            end
            if Walk.job ~= job then return end
            C.tip(L('lastWave'), 5000)
            TriggerServerEvent('pup_robbery:walkup:open', job.id)
        elseif p.guards and #p.guards > 0 then
            for _, def in ipairs(p.guards) do
                if Walk.job ~= job then return end
                Guards.spawn(def, TAG)
            end
            TriggerServerEvent('pup_robbery:walkup:guards', job.id, Guards.netIds(TAG))
        end
    end)
end

RegisterNetEvent('pup_robbery:walkup:begin', function(placeId, state, role)
    local p = Config.Places[placeId]
    if not p or type(state) ~= 'table' then return end
    if Walk.job then Walk.finish(false) end
    local job = { id = placeId, place = p, opened = {}, open = state.boxesOpen == true, controller = role and role.controller == true, boxBlips = {} }
    for _, i in ipairs(state.opened or {}) do job.opened[i] = true end
    Walk.job = job
    TriggerEvent('inv:dropstatus', false)
    TriggerEvent('inv:givestatus', false)
    C.tip(L('lootStart'), 5000)
    if p.boxBlips then
        for i, b in ipairs(p.boxes) do
            if not job.opened[i] then job.boxBlips[i] = C.blipAt(b.pos, W.boxBlip.sprite, W.boxBlip.scale, L('boxLocked')) end
        end
    end
    if not p.waves and not job.open then startClock(job, tonumber(state.unlockIn) or 0) end
    if job.controller then
        runControl(job, 1)
    elseif state.guards and #state.guards > 0 then
        Guards.markRemote(state.guards)
    end
end)

RegisterNetEvent('pup_robbery:walkup:control', function(placeId, wave, guardNet)
    local job = Walk.job
    if not job or job.id ~= placeId then return end
    job.controller = true
    if job.place.waves then
        if not job.open then runControl(job, math.max(1, tonumber(wave) or 1)) end
    elseif not Guards.anyAliveRemote(guardNet) then
        runControl(job, 1)
    end
end)

RegisterNetEvent('pup_robbery:walkup:wave', function(placeId, n)
    local job = Walk.job
    if not job or job.id ~= placeId or not job.place.waves then return end
    C.tip(L('waveStart', n, job.place.waves.count), 4000)
end)

RegisterNetEvent('pup_robbery:walkup:guards', function(placeId, ids)
    local job = Walk.job
    if not job or job.id ~= placeId or job.controller then return end
    Guards.markRemote(ids)
end)

RegisterNetEvent('pup_robbery:walkup:unlocked', function(placeId)
    local job = Walk.job
    if not job or job.id ~= placeId then return end
    job.open = true
    stopTimer()
end)

RegisterNetEvent('pup_robbery:walkup:boxOpened', function(placeId, i)
    local job = Walk.job
    if not job or job.id ~= placeId then return end
    job.opened[i] = true
    if job.boxBlips[i] then
        C.removeBlip(job.boxBlips[i])
        job.boxBlips[i] = nil
    end
end)

RegisterNetEvent('pup_robbery:walkup:forceEnd', function()
    Walk.finish(false)
end)

--------------------------------------------------------------------------------
-- boxes

local function openBox(job, i)
    if working then return end
    working = true
    CreateThread(function()
        local r = C.cbWithin(W.claimWaitMs or 3000, 'pup_robbery:walkup:claim', job.id, i)
        if type(r) ~= 'table' then
            C.tip(L('claimTimeout'))
        elseif not r.ok then
            if r.msg then C.tip(r.msg) end
        elseif Walk.job == job then
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            C.playAnim(Config.Heist.defaultAnim)
            local won = C.boxGame(r.opts and r.opts.game or 'normal', r.opts and r.opts.dials)
            FreezeEntityPosition(ped, false)
            C.stopAnim()
            if Walk.job == job then
                TriggerServerEvent('pup_robbery:walkup:result', job.id, i, won == true)
            end
        end
        working = false
    end)
end

local function jobTick(job)
    local p = job.place
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    if C.dead() or #(pos - p.anchor) > (p.stray or 100) then
        Walk.finish(true)
        return 500
    end
    local sleep = 250
    for i, b in ipairs(p.boxes) do
        if not job.opened[i] then
            local d = #(pos - b.pos)
            if d < 10.0 then sleep = 0 end
            if d <= (W.boxPromptRange or 3.0) then
                if not job.open then
                    C.text3D(b.pos + vector3(0.0, 0.0, 0.4), L('boxLocked'), 220, 50, 50)
                elseif not working then
                    C.text3D(b.pos + vector3(0.0, 0.0, 0.4), L('boxPrompt', Config.InteractKeyLabel))
                    if C.pressed() then openBox(job, i) end
                end
            end
        end
    end
    return sleep
end

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    for _, p in pairs(Config.Places) do
        if p.placeBlip then placeBlips[#placeBlips + 1] = C.blipAt(p.anchor, W.placeBlip.sprite, W.placeBlip.scale) end
    end
    while true do
        local sleep
        if Walk.job then sleep = jobTick(Walk.job) else sleep = idleTick() end
        Wait(sleep)
    end
end)

function Walk.cleanup()
    Walk.finish(false)
    for _, b in ipairs(placeBlips) do C.removeBlip(b) end
    placeBlips = {}
end
