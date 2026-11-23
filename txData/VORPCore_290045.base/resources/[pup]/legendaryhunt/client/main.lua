-- legendaryhunt | client: the frame loop, the one-second tick and cleanup
-- the frame loop sleeps up to a second unless something needs drawing or a prompt is in reach

local RES <const> = GetCurrentResourceName()

CreateThread(function()
    -- wait for the player ped before making the trapper
    while not NetworkIsPlayerActive(PlayerId()) do Wait(1000) end
    Trapper.spawn()
end)

CreateThread(function()
    while true do
        local sleep = 1000
        Menu.stale()

        if Trap.state == 'holding' then
            sleep = 0
            Trap.holdFrame()
        elseif Trap.state == 'placed' then
            local d = Trap.distance()
            if d and d <= Config.Trap.useRange and not Menu.isOpen() then
                sleep = 0
                Trap.placedFrame()
            elseif d and d < 25.0 then
                sleep = 250
            end
        end

        if Trapper.ped then
            local d = Trapper.distance()
            if d <= Config.Trapper.useRange and not Menu.isOpen() and Trap.state ~= 'holding' then
                sleep = 0
                Trapper.frame()
            elseif d < 30.0 and sleep > 250 then
                sleep = 250
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        Trap.tick()
    end
end)

-- a different character: the server owes the trap to the one that set it; forget it here
RegisterNetEvent('vorp:SelectedCharacter', function()
    Trap.reset(false)
    -- hand a living legendary over to the game so it is not kept as this script's entity forever
    if Trap.legendary and DoesEntityExist(Trap.legendary) then SetEntityAsNoLongerNeeded(Trap.legendary) end
    Trap.legendary = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    local ours = Trap.state ~= 'idle' or Menu.isOpen() -- only undo tasks this resource set
    Trap.reset(true)
    Trapper.remove()
    if ours then ClearPedTasks(PlayerPedId()) end
end)
