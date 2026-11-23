local ANIM_DICT <const> = "script_common@other@unapproved"
local ANIM_NAME <const> = "door_deal_pay_givedrugs_player"

-- Skip rather than fight whatever already owns the ped
local function cannotAnimate(ped)
	if not ped or ped == 0 or not DoesEntityExist(ped) then return true end
	if IsEntityDead(ped) or IsPedFatallyInjured(ped) then return true end
	if not IsPedHuman(ped) then return true end -- animal form, dict is human-only
	if IsPedInAnyVehicle(ped, false) or IsPedOnMount(ped) then return true end
	if Citizen.InvokeNative(0x3AA24CCC0D451379, ped) then return true end -- hogtied
	if Citizen.InvokeNative(0x74E559B3BC910685, ped) then return true end -- cuffed
	if IsPedRagdoll(ped) then return true end
	if IsPlayerFreeAiming(PlayerId()) then return true end
	return false
end

RegisterNetEvent('vorp_inventory:playgiveanimation', function()
	if cannotAnimate(PlayerPedId()) then return end

	CreateThread(function()
		RequestAnimDict(ANIM_DICT)

		local waited = 0
		while not HasAnimDictLoaded(ANIM_DICT) and waited < 3000 do
			Wait(10)
			waited = waited + 10
		end
		if not HasAnimDictLoaded(ANIM_DICT) then return end

		-- re-checked: a player can be shot or hogtied during the load
		local ped <const> = PlayerPedId()
		if cannotAnimate(ped) then
			RemoveAnimDict(ANIM_DICT)
			return
		end

		-- flag 16 = upper body, so it plays over walking instead of rooting them
		TaskPlayAnim(ped, ANIM_DICT, ANIM_NAME, 1.0, 8.0, -1, 16, 0.0, false, false, false)
		RemoveAnimDict(ANIM_DICT)
	end)
end)
