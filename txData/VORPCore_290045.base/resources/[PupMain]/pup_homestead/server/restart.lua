-- pup_homestead | txAdmin restart lock: Config.Planting.RestartLockMinutes before a scheduled restart
-- no new seed can be started and nothing can be harvested
local locked = false

function HomesteadRestartLocked() return locked end

-- clients read this so they refuse before the skill bar instead of after it
local function set(v)
    locked = v
    GlobalState.homesteadRestartLock = v
end
set(false)

AddEventHandler('txAdmin:events:scheduledRestart', function(e)
    local mins = tonumber(Config.Planting and Config.Planting.RestartLockMinutes) or 5
    local s = type(e) == 'table' and tonumber(e.secondsRemaining)
    if mins > 0 and s and s <= mins * 60 then set(true) end
end)

AddEventHandler('txAdmin:events:scheduledRestartSkipped', function() set(false) end)

AddEventHandler('txAdmin:events:serverShuttingDown', function() set(true) end)
