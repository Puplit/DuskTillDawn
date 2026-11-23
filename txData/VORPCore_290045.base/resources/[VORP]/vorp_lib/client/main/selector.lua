local isInSelection = false
local playerSelected = 0

---@param options {allow_self: boolean, amount_of_players: number, distance: number, allow_in_vehicle: boolean, allow_on_horse: boolean}
---@return number | false
local function selector(options)
    if isInSelection then return false end
    isInSelection = true
    playerSelected = 0

    local playerPed <const> = PlayerPedId()
    local isInVehicle <const> = IsPedInAnyVehicle(playerPed, false) -- perhaps add option to allow this

    if isInVehicle and not options.allow_in_vehicle then
        print("cant do this while in vehicle or mounted on horse?")
        isInSelection = false
        return false
    end

    local isInHorse <const> = IsPedOnMount(playerPed)
    if isInHorse and not options.allow_on_horse then
        print("cant do this while mounted on horse?")
        isInSelection = false
        return false
    end

    local activePlayers <const> = GetActivePlayers()

    local function getDistanceBetweenCoords(playerPos, targetPos)
        local dx <const> = targetPos.x - playerPos.x
        local dy <const> = targetPos.y - playerPos.y
        local dz <const> = targetPos.z - playerPos.z
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    local playersNeeded <const> = {}
    local amount_of_players <const> = options.amount_of_players or 4 -- fallback to default value

    local interior2 <const> = GetInteriorFromEntity(playerPed)
    for _, player in ipairs(activePlayers) do
        if #playersNeeded < amount_of_players then
            local playerPos <const> = GetEntityCoords(playerPed)
            local targetPed <const> = GetPlayerPed(player)
            local targetPos <const> = GetEntityCoords(targetPed)
            local interior <const> = GetInteriorFromEntity(targetPed)
            if interior == interior2 then
                local isInLineOfSight <const> = HasEntityClearLosToEntityInFront(playerPed, targetPed, 3167)
                if isInLineOfSight then
                    local dist <const> = #(playerPos - targetPos)
                    if dist <= (options.distance or 8.0) then -- option for distance?
                        if options.allow_self and player == PlayerId() then
                            playersNeeded[#playersNeeded + 1] = player
                        else
                            if player ~= PlayerId() then
                                playersNeeded[#playersNeeded + 1] = player
                            end
                        end
                    end
                end
            end
        else
            break
        end
    end

    if #playersNeeded == 0 then
        isInSelection = false
        return false
    end

    -- THE DISTANCE CHECK ONLY RAN ONCE
    local LEAVE_GRACE <const> = 1.0
    local maxDist <const> = (options.distance or 8.0) + LEAVE_GRACE

    local set = false
    SetNuiFocus(true, true)
    repeat
        local players <const> = {}
        local playerPos <const> = GetEntityCoords(playerPed) -- who used item
        -- counted separately from `players`: that list only holds targets who are ALSO on screen
        local inRange = 0

        for _, player in ipairs(playersNeeded) do
            local targetPed <const> = GetPlayerPed(player)
            -- the target can disconnect or stream out mid-selection
            if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
                local targetPos <const> = GetEntityCoords(targetPed)
                local interior <const> = GetInteriorFromEntity(targetPed)
                local dist <const> = #(playerPos - targetPos)

                if interior == interior2 and dist <= maxDist then
                    inRange = inRange + 1
                    local coords <const> = GetWorldPositionOfEntityBone(targetPed, GetPedBoneIndex(targetPed, 21030))
                    local onScreen <const>, _x <const>, _y <const> = GetScreenCoordFromWorldCoord(coords.x, coords.y,
                        coords.z + .3)
                    if onScreen then
                        players[#players + 1] = {
                            id = GetPlayerServerId(player),
                            x = _x,
                            y = _y,
                            distance = getDistanceBetweenCoords(playerPos, targetPos)
                        }
                    end
                end
            end
        end

        if IsPlayerDead(PlayerId()) then
            playerSelected = -1
        end

        if playerSelected == -1 then
            break
        end

        if not set then
            set = true
            SendNUIMessage({ data = { type = "select", players = players } })
        end

        SendNUIMessage({ data = { type = "update", players = players } }) -- update postion if they move?

        -- everyone has walked out of range (or disconnected) - there is nothing left to pick
        if inRange == 0 then
            playerSelected = -1
            break
        end

        Wait(0)
    until playerSelected > 0

    table.wipe(playersNeeded)

    -- TELL THE PAGE
    SendNUIMessage({ data = { type = "cancel" } })

    SetNuiFocus(false, false)
    isInSelection = false

    -- was cancelled pressed ESC
    if playerSelected == -1 then
        return false
    end

    return playerSelected
end

RegisterNUICallback("selector", function(data, cb)
    playerSelected = data.id
    cb("ok")
end)

RegisterNUICallback("selectorSound", function(_, cb)
    PlaySoundFrontend("SELECT", "HUD_SHOP_SOUNDSET", true, 0)
    cb("ok")
end)


exports("Select", selector)

--[[
 local result <const> = exports.vorp_lib:Select({
        allow_self = true, -- option to allow self selection
        amount_of_players = 4,
        distance = 8.0,
        allow_in_vehicle = true, -- option to allow selection in vehicle
        allow_on_horse = true -- option to allow selection on horse
    })
]]
