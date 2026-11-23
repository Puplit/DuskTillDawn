-- pup_business | txAdmin restart lock: Config.RestartLockMinutes before a scheduled
-- restart everyone on duty here is clocked off and nobody can clock back on

local locked = false

function BizRestartLocked() return locked end

-- the same off-duty path as /offduty (SetDuty), plus the badge /offduty puts away
local function clockOff(src, message)
    SetDuty(src, false, nil, { message = message })
    TriggerClientEvent('pup-misc:police:takeoffbadge', src)
end

local function lock(message)
    if locked then return end
    locked = true
    local list = {}
    for s in pairs(Duty) do list[#list + 1] = s end
    for _, s in ipairs(list) do
        local ok, err = pcall(clockOff, s, message)
        if not ok then print(('^1[%s]^7 restart clock-off failed for %s: %s'):format(RES, tostring(s), tostring(err))) end
    end
end

AddEventHandler('txAdmin:events:scheduledRestart', function(e)
    local mins = tonumber(Config.RestartLockMinutes) or 5
    local s = type(e) == 'table' and tonumber(e.secondsRemaining)
    if mins > 0 and s and s <= mins * 60 then
        lock(L('restart_clocked_off', math.max(1, math.ceil(s / 60))))
    end
end)

AddEventHandler('txAdmin:events:scheduledRestartSkipped', function()
    locked = false
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    lock(L('restart_clocked_off_now'))
end)
