-- pup-misc / hogtie - hogtie detection, lasso removal and the restrained checks

-- RESTRAINT CHECK - the one place that answers "is this player tied up"
local function truthy(v) return v == true or v == 1 end

local function nativeSays(fn)
    local ok, res = pcall(fn)
    return ok and truthy(res)
end

--- True while the player is lassoed, being hogtied, hogtied or cuffed.
function PupIsRestrained(ped)
    ped = ped or PlayerPedId()
    if not ped or ped == 0 then return false end

    if nativeSays(function() return Citizen.InvokeNative(0x3AA24CCC0D451379, ped) end) then return true end
    if nativeSays(function() return IsPedHogtied and IsPedHogtied(ped) end) then return true end
    if nativeSays(function() return IsPedBeingHogtied and IsPedBeingHogtied(ped) end) then return true end
    if nativeSays(function() return Citizen.InvokeNative(0x3BDFCF25B58B0415, ped) end) then return true end
    if nativeSays(function() return IsPedCuffed and IsPedCuffed(ped) end) then return true end
    if nativeSays(function()
        return DecorExistOn and DecorExistOn(ped, 'IsHogtied') and DecorGetBool(ped, 'IsHogtied')
    end) then return true end

    return false
end

-- cross-resource: exports['pup-misc']:IsRestrained()
exports('IsRestrained', function(ped) return PupIsRestrained(ped) end)

--- Shared refusal. Returns true when the command should be BLOCKED.
function PupBlockIfRestrained(message)
    if not PupIsRestrained() then return false end
    TriggerEvent('vorp:TipRight', message or HogtieLocale.tiedUp, 3000)
    return true
end
exports('BlockIfRestrained', function(message) return PupBlockIfRestrained(message) end)

-- Listener for lasso removal notification from the server
RegisterNetEvent("pup-misc:hogtie:lassoRemoved")
AddEventHandler("pup-misc:hogtie:lassoRemoved", function(weapon)
	TriggerEvent("vorp:TipRight", HogtieLocale.lassoUsed, 5000)
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(5) 
		local size = GetNumberOfEvents(0)   
		if size > 0 then 
			for i = 0, size - 1 do
				local eventAtIndex = GetEventAtIndex(0, i)
				-- Detect the EVENT_ENTITY_HOGTIED (0x57EC5FA4D4D6AFCA)
                if eventAtIndex == GetHashKey("EVENT_ENTITY_HOGTIED") then 
                    local eventDataSize = 3
                    local eventDataStruct = DataView.ArrayBuffer(24)
                    eventDataStruct:SetInt32(0 ,0)
                    eventDataStruct:SetInt32(8 ,0) 
                    eventDataStruct:SetInt32(16 ,0)
                    local is_data_exists = Citizen.InvokeNative(0x57EC5FA4D4D6AFCA,0,i,eventDataStruct:Buffer(),eventDataSize)
                    if is_data_exists then
                        if PlayerPedId() == eventDataStruct:GetInt32(0) then
                            local hogtied = eventDataStruct:GetInt32(0)
                            local hogtier = eventDataStruct:GetInt32(8)
                            local isplayer = IsPedAPlayer(hogtied)
                            if isplayer then 
                                local playerindex = NetworkGetPlayerIndexFromPed(hogtier)                                
                                local hogtierserverid = GetPlayerServerId(playerindex)
                                local pedweapon = Citizen.InvokeNative(0x8425C5F057012DAB,hogtier) -- GET_SELECTED_PED_WEAPON
                                for k,v in pairs(HogtieConfig.Lasso.removeWeapons) do 
                                    if pedweapon == GetHashKey(v) then 
										-- Trigger server event to remove the lasso (server will check for job whitelist)
                                        TriggerServerEvent("pup-misc:hogtie:removelasso",hogtierserverid,v)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- players within range: used to decide whether the player can break free
function GetPlayersInRange(range)
    local playersInRange = {}
    local playerPed = PlayerPedId()
    local playerId = PlayerId()
    local coords = GetEntityCoords(playerPed)

    for _, player in ipairs(GetActivePlayers()) do
        local tgt = GetPlayerPed(player)

        if player ~= playerId then
            local isTargetHogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, tgt)
            if not isTargetHogtied and not IsEntityDead(tgt) and not IsPedDeadOrDying(tgt) then
                local targetCoords = GetEntityCoords(tgt)
                local distance = #(coords - targetCoords)

                if distance <= range then
                    table.insert(playersInRange, GetPlayerServerId(player))
                end
            end
        end
    end

    return playersInRange
end

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        -- Check if the player is hogtied using IS_PED_HOGTIED (0x3AA24CCC0D451379)
        local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, playerPed)

        if hogtied then
            Citizen.Wait(0)

            -- Disable control action (0x6E9734E8) - commonly used to prevent certain movements/actions
            DisableControlAction(1, 0x6E9734E8, true)
            -- Set Ped Action Disable Flag (0xB8DE69D9473B7593) to lock animations
            Citizen.InvokeNative(0xB8DE69D9473B7593, playerPed, 15)

            local playersInRange = GetPlayersInRange(HogtieConfig.BreakFree.blockRadius)

            if #playersInRange > 0 then
                -- Disable break free control action (0x295175BF)
                DisableControlAction(1, 0x295175BF, true)
            end
        else
            Citizen.Wait(1000)
        end
    end
end)
