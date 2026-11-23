-- pup_business | duty commands, stations and the AFK clock-off
-- The client's duty state always follows the server's (pup_business:dutyState).

local onDuty = false
local region = nil
local delayToken = 0

local function setLocal(on, reg)
    local changed = on ~= onDuty
    onDuty, region = on, on and reg or nil
    if changed then TriggerEvent('pup-medic:onduty', on) end
end

RegisterNetEvent('pup_business:dutyState', function(on, reg)
    if not on then delayToken = delayToken + 1 end
    setLocal(on == true, type(reg) == 'string' and reg or nil)
end)

local function mdtJob()
    return Me.job and Config.MdtJobs[Me.job] and GetResourceState('pup-mdt') == 'started'
end

local function restrained()
    local ped = PlayerPedId()
    local dead = IsPedDeadOrDying(ped, true)
    if dead == true or dead == 1 then return true end
    -- read as integers: a bare boolean read can come back as 0, which Lua treats as true
    if Citizen.InvokeNative(0x3AA24CCC0D451379, ped, Citizen.ResultAsInteger()) ~= 0 then return true end -- IsPedHogtied
    if Citizen.InvokeNative(0x74E559B3BC910685, ped, Citizen.ResultAsInteger()) ~= 0 then return true end -- IsPedCuffed
    return false
end

local function usesStations(job)
    return Config.DutyStationsEnabled and job ~= nil and Config.StationJobs[job] == true
end

local function stationsFor(job)
    local out = {}
    for _, st in ipairs(Config.DutyStations or {}) do
        for _, j in ipairs(st.jobs or {}) do
            if j == job then out[#out + 1] = st break end
        end
    end
    return out
end

-- asks the server; the answer arrives as pup_business:dutyState
local function clockOn(reg)
    if Config.InstantDuty then
        Send('dutyOn', reg)
        return
    end
    delayToken = delayToken + 1
    local token = delayToken
    Tip(L('duty_wait', Config.DutyDelaySeconds))
    SetTimeout(Config.DutyDelaySeconds * 1000, function()
        if token ~= delayToken or onDuty then return end
        Send('dutyOn', reg)
    end)
end

RegisterCommand(Config.DutyCommands.on, function()
    if mdtJob() then
        TriggerServerEvent('mdt:server:dutyCommand', true)
        return
    end
    if restrained() then return Tip(L('duty_restrained')) end
    if onDuty then return Tip(L('already_on_duty')) end

    if usesStations(Me.job) and Config.RegionMenu then
        local opts = {}
        for _, st in ipairs(stationsFor(Me.job)) do
            opts[#opts + 1] = { label = st.label or st.region, onSelect = function() clockOn(st.region) end }
        end
        if #opts == 0 then opts[1] = { label = L('none_available'), disabled = true } end
        UI.List({ title = L('duty_regions_title', Me.job), options = opts })
        return
    end
    if usesStations(Me.job) then return Tip(L('duty_station_only')) end
    clockOn(nil)
end, false)

RegisterCommand(Config.DutyCommands.off, function()
    if mdtJob() then
        TriggerServerEvent('mdt:server:dutyCommand', false)
        return
    end
    delayToken = delayToken + 1
    Send('dutyOff', region, false)
    TriggerEvent('pup-medic:onduty', false)
    TriggerEvent('pup-misc:police:takeoffbadge')
end, false)

---------------------------------------------------------------------------
-- AFK clock-off: Config.AfkMinutes minutes barely moving
---------------------------------------------------------------------------

CreateThread(function()
    local still, last = 0, nil
    while true do
        Wait(60000)
        if onDuty and Config.AfkMinutes > 0 then
            local pos = GetEntityCoords(PlayerPedId())
            if last and #(pos - last) < Config.AfkMoveMetres then
                still = still + 1
            else
                still = 0
            end
            last = pos
            if still >= Config.AfkMinutes then
                still, last = 0, nil
                Send('dutyOff', region, true)
            end
        else
            still, last = 0, nil
        end
    end
end)

---------------------------------------------------------------------------
-- duty stations (only when enabled)
---------------------------------------------------------------------------

if Config.DutyStationsEnabled then
    CreateThread(function()
        while true do
            local wait = 1000
            local job = Me.job
            if job and usesStations(job) and not onDuty and not UI.AnyOpen() then
                local pos = GetEntityCoords(PlayerPedId())
                for _, st in ipairs(stationsFor(job)) do
                    local d = #(pos - st.coords)
                    if d < 15.0 then wait = math.min(wait, d <= Config.JobMenuDistance + 1.0 and 0 or 200) end
                    if d <= Config.JobMenuDistance then
                        local b = MyBusiness()
                        if BizPrompt.show(L('prompt_station', st.region), b and b.name or nil) then
                            if restrained() then Tip(L('duty_restrained')) else Send('dutyOn', st.region) end
                        end
                        break
                    end
                end
            end
            Wait(wait)
        end
    end)
end

---------------------------------------------------------------------------
-- start-up and character switch
---------------------------------------------------------------------------

CreateThread(function()
    Wait(2500)
    local st = Call('dutyState')
    if type(st) == 'table' then setLocal(st.on == true, st.region) end
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    delayToken = delayToken + 1
    setLocal(false, nil)
end)
