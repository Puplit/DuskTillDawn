-- pup: txAdmin restart lock for the inventory (CONFIG.RESTART_LOCK_MINUTES before a scheduled restart)
-- While locked, server/controllers/inventoryController.lua refuses every give to a player and every
-- move between inventories. Drops are untouched: with DELETE_ON_DROP they only delete.
local locked = false

function InvRestartLocked() return locked end

AddEventHandler('txAdmin:events:scheduledRestart', function(e)
    local mins = tonumber(CONFIG.RESTART_LOCK_MINUTES) or 5
    local s = type(e) == 'table' and tonumber(e.secondsRemaining)
    if mins > 0 and s and s <= mins * 60 then locked = true end
end)

AddEventHandler('txAdmin:events:scheduledRestartSkipped', function() locked = false end)

AddEventHandler('txAdmin:events:serverShuttingDown', function() locked = true end)
