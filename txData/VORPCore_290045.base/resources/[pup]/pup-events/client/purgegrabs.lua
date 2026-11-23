-- pup-events | THE PURGE: shove, tackle, choke and grapple are off while it runs.
-- the flag disables the action on your own ped, so this covers everyone, not just your posse

-- same numbers vorp_core uses: grapple, shove, choke, tackle
local FLAGS <const> = { 1, 5, 6, 33 }

-- only engage if the lock can be undone, or a player could not shove until they respawned
local CAN_CLEAR <const> = type(ClearPedActionDisableFlag) == 'function'

local live = false
local applied = nil -- the ped the flags are currently on

local function release()
    if applied and CAN_CLEAR and DoesEntityExist(applied) then
        for _, f in ipairs(FLAGS) do ClearPedActionDisableFlag(applied, f) end
    end
    applied = nil
end

RegisterNetEvent('pup-events:state', function(key, on)
    if key ~= 'purge' or not CAN_CLEAR then return end
    live = on == true
    if not live then release() end
end)

CreateThread(function()
    if not CAN_CLEAR then
        print('^3[pup-events]^7 purge grapple lock off: this build has no ClearPedActionDisableFlag')
        return
    end

    while true do
        Wait(1000)
        if live then
            local ped <const> = PlayerPedId()
            -- re-applied after a respawn: the flags go with the old ped
            if ped ~= applied and DoesEntityExist(ped) then
                for _, f in ipairs(FLAGS) do SetPedActionDisableFlag(ped, f) end
                applied = ped
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then release() end
end)
