-- pup-medical | txAdmin restart lock: Config.Duty.RestartLockMinutes before a scheduled restart every medic is clocked off and /duty can't put anyone on
local locked = false

function MedicalRestartLocked() return locked end

-- mins = minutes left, nil when the server is going down now
local function lock(reason, mins)
    if locked then return end
    locked = true
    local text = (mins and mins > 1) and L('dutyRestartOff', mins) or L('dutyRestartNow')
    local done = Duty.ClockOffAll('restart lock (' .. reason .. ')')
    for _, src in ipairs(done) do
        if Online(src) then TipBottom(src, text, 8000) end
    end
    Debug('duty', ('restart lock (%s): %d clocked off'):format(reason, #done))
end

AddEventHandler('txAdmin:events:scheduledRestart', function(e)
    local mins = tonumber(Config.Duty and Config.Duty.RestartLockMinutes) or 5
    local s = type(e) == 'table' and tonumber(e.secondsRemaining)
    if mins > 0 and s and s <= mins * 60 then lock('scheduled', math.ceil(s / 60)) end
end)

AddEventHandler('txAdmin:events:scheduledRestartSkipped', function() locked = false end)

AddEventHandler('txAdmin:events:serverShuttingDown', function() lock('shutdown', nil) end)
