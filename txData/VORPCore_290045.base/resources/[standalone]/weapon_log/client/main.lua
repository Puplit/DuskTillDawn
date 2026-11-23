local HeadBones = {
    [21030] = true, -- SKEL_Head
    [14283] = true, -- SKEL_Neck0
    [53042] = true, -- SKEL_Neck1
    [53043] = true, -- SKEL_Neck2
    [53044] = true, -- SKEL_Neck3
    [53045] = true, -- SKEL_Neck4
    [53046] = true, -- SKEL_Neck5
    [34338] = true, -- SKEL_HeadBody
    [43336] = true, -- SKEL_Neck0Body
}

Citizen.CreateThread(function()
	local DeathReason, Killer, KillerServerId, DeathCauseHash, Weapon, HitLocation

	while true do
		Citizen.Wait(250) -- a death is still readable a moment later, no need to ask every frame
		if IsEntityDead(PlayerPedId()) then
			Citizen.Wait(500)
			local ped = PlayerPedId()
			local PedKiller = GetPedSourceOfDeath(ped)
			DeathCauseHash = GetPedCauseOfDeath(ped)
			Weapon = WeaponNames[tostring(DeathCauseHash)]

            local found, bone = GetPedLastDamageBone(ped)
            if found and HeadBones[bone] then
                HitLocation = "Headshot"
            else
                HitLocation = "Body"
            end

			if IsEntityAPed(PedKiller) and IsPedAPlayer(PedKiller) then
				KillerServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(PedKiller))
				Killer = NetworkGetPlayerIndexFromPed(PedKiller)
			elseif IsEntityAVehicle(PedKiller) and IsEntityAPed(GetPedInVehicleSeat(PedKiller, -1)) and IsPedAPlayer(GetPedInVehicleSeat(PedKiller, -1)) then
				KillerServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(GetPedInVehicleSeat(PedKiller, -1)))
				Killer = NetworkGetPlayerIndexFromPed(GetPedInVehicleSeat(PedKiller, -1))
			end
			
			if (Killer == PlayerId()) then
				DeathReason = 'committed suicide'
			elseif (Killer == nil) then
				DeathReason = 'died'
			else
				DeathReason = 'killed'
			end
			if DeathReason == 'committed suicide' or DeathReason == 'died' then
				TriggerServerEvent('DiscordBot:playerDied', GetPlayerServerId(PlayerId()), nil, DeathReason, Weapon, HitLocation)
			else
				TriggerServerEvent('DiscordBot:playerDied', GetPlayerServerId(PlayerId()), KillerServerId, DeathReason, Weapon, HitLocation)
			end
			Killer = nil
			KillerServerId = nil
			DeathReason = nil
			DeathCauseHash = nil
			Weapon = nil
			HitLocation = nil
		end
		while IsEntityDead(PlayerPedId()) do
			Citizen.Wait(250)
		end
	end
end)