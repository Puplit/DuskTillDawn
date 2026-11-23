-- pup_railroad | client: driving (key check, prompts, throttle lock, cruise, coal),
-- repairs and upgrades

local L <const> = Rail.L
local K <const> = Config.Keys
local MPH <const> = 2.23694 -- metres per second to miles per hour

local drive = nil -- state while this player is in a train's driver seat
Cl.drivingNow = false

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------
local function jobIn(list)
    return Cl.job ~= nil and Rail.inList(list, Cl.job)
end

local function refreshJob()
    CreateThread(function()
        local me = Cl.call('whoami', 5000)
        if me and me.ok then Cl.job, Cl.cash = me.job, me.cash end
    end)
end

local function nearestJunction(veh)
    local pos = GetEntityCoords(veh)
    local best, bestIndex, bestDist
    for i = 1, #Config.Junctions do
        local j = Config.Junctions[i]
        local dx, dy = pos.x - j.pos.x, pos.y - j.pos.y
        local d = dx * dx + dy * dy
        if not bestDist or d < bestDist then best, bestIndex, bestDist = j, i, d end
    end
    if best and bestDist <= Config.Reach.junctionPrompt ^ 2
        and Rail.headingMatches(GetEntityHeading(veh), best.heading) then
        return bestIndex
    end
    return nil
end

--------------------------------------------------------------------------------
-- repair / upgrade work: 30 s crouch with a progress bar
--------------------------------------------------------------------------------
local function doWork(label, send)
    Cl.busy = true
    Wait(500)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    FreezeEntityPosition(ped, true)
    Cl.native('TaskStartScenarioInPlaceHash', 0x524B54361229154F, ped, GetHashKey(Config.WorkScenario), -1, true, 0, -1.0, false)

    local finished, cancelled = false, false
    exports['pup-ui']:Progress({ label = label, duration = Config.Timings.workDuration }, function() finished = true end)
    local deadline = GetGameTimer() + Config.Timings.workDuration + 5000
    while not finished do
        Wait(250)
        if Cl.incapacitated(ped) then
            cancelled = true
            exports['pup-ui']:ProgressCancel()
            break
        end
        if GetGameTimer() > deadline then -- the progress bar never answered: send nothing
            cancelled = true
            break
        end
    end

    if finished and not cancelled then send() end

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    if Config.Upgrades.exitAfterWork and veh ~= 0 and DoesEntityExist(veh) then
        TaskLeaveVehicle(ped, veh, 0)
    end
    Cl.busy = false
end

local function startRepair(entry)
    if entry.maint > Config.Maintenance.repairAtOrBelow then return Cl.notify(L('not_needed')) end
    doWork(L('fixing'), function()
        local r = Cl.call('repair', 6000, entry.id)
        if not r then return Cl.officeSilent() end
        if r.ok then Cl.notify(L('fixed')) end
    end)
end

local function tierMenu(entry, kind, tier, def)
    local mats = {}
    for i = 1, #def.materials do mats[i] = def.materials[i] end
    table.sort(mats, function(a, b) return a.label < b.label end)
    local rows = {}
    for i = 1, #mats do rows[i] = { label = L('material_row', mats[i].label, mats[i].count) } end
    rows[#rows + 1] = {
        label = L('confirm'),
        action = function()
            Cl.closeMenu()
            doWork(L('upgrading'), function()
                local r = Cl.call('upgrade', 6000, entry.id, kind, tier)
                if not r then return Cl.officeSilent() end
                if r.ok then Cl.notify(L('upgraded')) end
            end)
        end,
    }
    Cl.openMenu({ title = kind == 'speed' and L('row_speedup') or L('row_engine'), subtitle = entry.name, rows = rows })
end

local function openUpgrades(entry)
    local rows = {}
    local engineTier = entry.coalup + 1
    local engineDef = entry.coalcon > 0 and Config.Upgrades.engine[engineTier] or nil
    if engineDef then
        rows[#rows + 1] = { label = L('row_engine'), action = function() tierMenu(entry, 'engine', engineTier, engineDef) end }
    end
    local speedTier = entry.speedup + 1
    local speedDef = entry.speed < Config.Upgrades.speedCap and Config.Upgrades.speed[speedTier] or nil
    if speedDef then
        rows[#rows + 1] = { label = L('row_speedup'), action = function() tierMenu(entry, 'speed', speedTier, speedDef) end }
    end
    if #rows == 0 then return Cl.notify(L('no_upgrades')) end
    Cl.openMenu({ title = L('upgrades_title'), subtitle = entry.name, rows = rows })
end

local function loadCoal(entry)
    local values = Cl.ask(L('coal_title'), { { label = L('amount'), type = 'number', min = 0, required = true } })
    local amount = values and tonumber(values[1])
    amount = amount and math.floor(amount) or 0
    if amount <= 0 then return Cl.notify(L('invalid')) end
    local live = Cl.byId[entry.id] or entry
    if amount > live.coalcap - live.coal then return Cl.notify(L('coal_too_much')) end
    local r = Cl.call('addCoal', 6000, entry.id, amount)
    if not r then return Cl.officeSilent() end
    if r.ok then Cl.notify(L('coal_loaded', r.amount or amount)) end
end

--------------------------------------------------------------------------------
-- key check
--------------------------------------------------------------------------------
local function checkKey(state, veh)
    if state.keyBusy then return end
    state.keyBusy = true
    CreateThread(function()
        local r = Cl.call('hasKey', 5000)
        state.keyBusy = false
        state.lastKeyCheck = GetGameTimer()
        if not r or not r.ok then
            state.retrySoon = true -- no answer never throws anyone out
            return
        end
        state.retrySoon = false
        state.keyOk = r.has == true
        if not state.keyOk then
            local ped = PlayerPedId()
            if veh and DoesEntityExist(veh) and IsPedInVehicle(ped, veh, false) then
                TaskLeaveVehicle(ped, veh, 0)
            else
                ClearPedTasks(ped)
            end
        end
    end)
end

local boarding = { keyBusy = false, lastKeyCheck = 0 }

local function boardingCheck(ped)
    if not Config.KeyCheckOnBoarding then return end
    -- GET_VEHICLE_PED_IS_ENTERING (RedM has no GetVehiclePedIsTryingToEnter)
    local target = Citizen.InvokeNative(0xF92691AED837A5FC, ped, Citizen.ResultAsInteger()) or 0
    if target == 0 or not Cl.isTrain(target) then return end
    if GetGameTimer() - boarding.lastKeyCheck < 3000 then return end
    boarding.lastKeyCheck = GetGameTimer()
    checkKey(boarding, target)
end

--------------------------------------------------------------------------------
-- upgrades reach the running train at once
--------------------------------------------------------------------------------
Cl.onTrainChanged(function(entry)
    if drive and drive.veh and DoesEntityExist(drive.veh) and Cl.entryForVehicle(drive.veh) == entry then
        Cl.train.setMax(drive.veh, entry.speed or 0)
    end
end)

--------------------------------------------------------------------------------
-- main loop
--------------------------------------------------------------------------------
CreateThread(function()
    local group = Cl.newGroup()
    local P = {
        cruise   = Cl.newPrompt(K.cruise, L('speed_label', 0, L('off')), group),
        left     = Cl.newPrompt(K.switchLeft, L('switch_left'), group),
        right    = Cl.newPrompt(K.switchRight, L('switch_right'), group),
        coal     = Cl.newPrompt(K.coal, L('coal_label', 0, 0), group),
        lockbox  = Cl.newPrompt(K.lockbox, L('inventory'), group),
        maint    = Cl.newPrompt(K.maintenance, L('maint_label', 100), group),
        upgrade  = Cl.newPrompt(K.upgrade, L('upgrade_prompt'), group),
        announce = Cl.newPrompt(K.announce, L('announce'), group),
        view     = Cl.newPrompt(K.viewMission, L('view_mission'), group),
        cancel   = Cl.newPrompt(K.cancelMission, L('cancel_mission'), group),
        deliver  = Cl.newPrompt(K.deliver, L('deliver'), group),
    }
    for _, p in pairs(P) do Cl.promptShow(p, false) end
    Cl.onCleanup(function()
        for _, p in pairs(P) do Cl.deletePrompt(p) end
    end)

    local stopped <const> = Config.Timings.stopped
    local maintOn <const> = Config.Maintenance.enabled

    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and Cl.isTrain(veh) and GetPedInVehicleSeat(veh, -1) == ped then
            local now = GetGameTimer()
            if not drive or drive.veh ~= veh then
                -- a new seat or train ends cruise and every other driving state
                drive = { veh = veh, keyOk = nil, keyBusy = false, lastKeyCheck = 0, cruise = false,
                          burnMs = 0, lastTick = now, reportedId = nil }
                refreshJob()
                checkKey(drive, veh)
            elseif not drive.keyBusy and now - drive.lastKeyCheck >= (drive.retrySoon and 5000 or Config.Timings.keyRecheck) then
                checkKey(drive, veh)
            end

            local entry = Cl.entryForVehicle(veh)
            local speed = GetEntitySpeed(veh)
            local dt = math.min(now - drive.lastTick, 1000)
            drive.lastTick = now
            Cl.drivingNow = drive.keyOk == true

            if drive.keyOk then
                if entry and drive.reportedId ~= entry.id then
                    drive.reportedId = entry.id
                    Cl.tell('driving', entry.id)
                end

                local outOfCoal = entry and entry.coalcon > 0 and entry.coal <= 0
                local broken = entry and maintOn and entry.maint <= 0
                local dead = outOfCoal or broken

                -- throttle lock
                if dead or Cl.menuOpen then
                    DisableControlAction(0, K.throttle, true)
                    if speed < stopped then DisableControlAction(0, K.brake, true) end
                end

                -- cruise control
                if drive.cruise then
                    if dead then
                        drive.cruise = false
                    else
                        local braking = IsControlPressed(0, K.brake) or IsDisabledControlPressed(0, K.brake)
                        if braking then
                            drive.braked = true
                        else
                            if drive.braked then drive.braked, drive.resuming = false, true end
                            if speed < stopped and not drive.resuming then
                                drive.cruise = false
                            elseif speed < drive.cruiseSpeed - 0.3 then
                                Cl.train.setSpeed(veh, math.min(drive.cruiseSpeed, speed + 0.08))
                            else
                                Cl.train.setSpeed(veh, drive.cruiseSpeed)
                                drive.resuming = false
                            end
                        end
                    end
                end

                -- coal burn: seconds of movement, reported one coal at a time
                if entry and entry.coalcon > 0 and entry.coal > 0 and not broken and speed > stopped then
                    drive.burnMs = drive.burnMs + dt
                    if drive.burnMs >= entry.coalcon * 1000 then
                        drive.burnMs = 0
                        Cl.tell('burn', entry.id)
                    end
                end

                -- prompts
                local free = Cl.idle()
                local isStopped = speed < stopped
                local junction = nearestJunction(veh)
                local onRoute = entry and Cl.route and Cl.route.trainId == entry.id
                local ann = Config.Announcements

                Cl.promptShow(P.cruise, free and Config.CruiseControl)
                Cl.promptShow(P.left, free and junction ~= nil)
                Cl.promptShow(P.right, free and junction ~= nil)
                Cl.promptShow(P.coal, free and entry ~= nil and entry.coalcon > 0)
                Cl.promptShow(P.lockbox, free and entry ~= nil)
                Cl.promptShow(P.maint, free and entry ~= nil and maintOn and jobIn(Config.Maintenance.jobs)
                    and entry.maint <= Config.Maintenance.promptAtOrBelow and isStopped)
                Cl.promptShow(P.upgrade, free and entry ~= nil and jobIn(Config.Upgrades.jobs) and isStopped)
                Cl.promptShow(P.announce, free and entry ~= nil and ann.enabled and ann.boardEnabled and Cl.job == ann.job)
                Cl.promptShow(P.view, free and onRoute and true or false)
                Cl.promptShow(P.cancel, free and onRoute and true or false)
                Cl.promptShow(P.deliver, free and Cl.deliverReady ~= nil)

                if free then
                    Cl.promptText(P.cruise, L('speed_label', Rail.round(speed * MPH), drive.cruise and L('on') or L('off')))
                    if entry then
                        Cl.promptText(P.coal, L('coal_label', entry.coal, entry.coalcap))
                        Cl.promptText(P.maint, L('maint_label', Rail.round(entry.maint)))
                    end
                    Cl.showGroup(group, entry and entry.name or L('group_train'))

                    if Cl.promptPressed(P.cruise) then
                        if drive.cruise then
                            drive.cruise = false
                        elseif not isStopped then
                            drive.cruise, drive.cruiseSpeed, drive.braked, drive.resuming = true, speed, false, false
                        end
                    end
                    if junction and Cl.promptPressed(P.left) then Cl.tell('switch', junction, 'left') end
                    if junction and Cl.promptPressed(P.right) then Cl.tell('switch', junction, 'right') end
                    if entry then
                        local e = entry
                        if Cl.promptPressed(P.coal) then CreateThread(function() loadCoal(e) end) end
                        if Cl.promptPressed(P.lockbox) then Cl.tell('openLockbox', e.id) end
                        if Cl.promptPressed(P.maint) then CreateThread(function() startRepair(e) end) end
                        if Cl.promptPressed(P.upgrade) then openUpgrades(e) end
                        if Cl.promptPressed(P.announce) and Cl.openBoard then Cl.openBoard() end
                        if onRoute and Cl.promptPressed(P.view) then Cl.viewMission() end
                        if onRoute and Cl.promptPressed(P.cancel) then Cl.cancelMission() end
                    end
                    if Cl.deliverReady and Cl.promptPressed(P.deliver) then Cl.deliverStop(Cl.deliverReady) end
                end
            end
            Wait(0)
        else
            if drive then
                drive = nil
                Cl.drivingNow = false
            end
            boardingCheck(ped)
            Wait(250)
        end
    end
end)

-- a new character starts with no driving state
RegisterNetEvent('vorp:SelectedCharacter', function()
    drive = nil
    Cl.drivingNow = false
end)
