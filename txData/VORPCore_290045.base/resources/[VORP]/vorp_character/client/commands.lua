-- Modified by Puppet (Dusk Till Dawn), 2026
local function toggleComp(hash, item, key)
	IsPedReadyToRender()
	-- empty slot: ApplyShopItemToPed(-1) below is a silent no-op, so say so instead
	if type(item) ~= "table" or item.comp == nil or item.comp == -1 then
		TriggerEvent("vorp:TipRight", "You have nothing to wear in that slot.", 3000)
		return
	end
	if IsMetaPedUsingComponent(hash) then
		RemoveTagFromMetaPed(hash)
		UpdatePedVariation()
		SetResourceKvp(ClothingOffKey(item.comp), "true")
		TriggerEvent("vorp_character:Client:OnClothingRemoved", key, item.comp)
	else
		ApplyShopItemToPed(item.comp)
		UpdatePedVariation()
		if item.drawable then
			SetMetaPedTag(PlayerPedId(), item.drawable, item.albedo, item.normal, item.material, item.palette, item.tint0, item.tint1, item.tint2)
		end
		SetResourceKvp(ClothingOffKey(item.comp), "false")
		TriggerEvent("vorp_character:Client:OnClothingAdded", key, item.comp)
		-- a garment comes back at stock colour; put its dye back
		local c = CachedComponents.colors and CachedComponents.colors[key]
		if type(c) == "table" then
			ApplyCachedColors(PlayerPedId(), { colors = { [key] = c } })
		end
	end
	UpdatePedVariation()
end

-- pup_clothing registers /hat, /coat ... too; two handlers on one command both fire and undo each other
local function pupClothingOwns(cmd)
	if GetResourceState('pup_clothing') ~= 'started' then return false end
	local ok, owns = pcall(function() return exports['pup_clothing']:OwnsToggleCommand(cmd) end)
	return ok and owns == true
end

-- re-wear one saved garment by category hash (pup_clothing asks for this when a knocked-off hat leaves the slot empty)
AddEventHandler("vorp_character:client:wearCategory", function(hash)
	for key, catHash in pairs(Config.ComponentCategories) do
		if catHash == hash then
			local item = CachedComponents[key]
			if type(item) == "table" and item.comp and item.comp ~= -1 and not IsMetaPedUsingComponent(hash) then
				toggleComp(hash, item, key)
			end
			return
		end
	end
end)

CreateThread(function()
	local waited = 0
	while GetResourceState('pup_clothing') ~= 'started' and waited < 15000 do
		Wait(250)
		waited = waited + 250
	end
	for key, v in pairs(Config.commands) do
		if not pupClothingOwns(v.command) then
		RegisterCommand(v.command, function()
			toggleComp(Config.ComponentCategories[key], CachedComponents[key], key)
			if key == "GunBelt" then
				toggleComp(Config.ComponentCategories.Holster, CachedComponents.Holster, key)
			end

			if key == "Vest" and IsMetaPedUsingComponent(Config.ComponentCategories.Shirt) then
				local item = CachedComponents.Shirt
				if item.drawable then
					SetTextureOutfitTints(PlayerPedId(), 'shirts_full', item)
				end
			end

			if key == "Coat" then
				if IsMetaPedUsingComponent(Config.ComponentCategories.Vest) then
					local item = CachedComponents.Vest
					if item.drawable then
						SetTextureOutfitTints(PlayerPedId(), 'vests', item)
					end
				end

				if IsMetaPedUsingComponent(Config.ComponentCategories.Shirt) then
					local item = CachedComponents.Shirt
					if item.drawable then
						SetTextureOutfitTints(PlayerPedId(), 'shirts_full', item)
					end
				end
			end

			if key == "Boots" then
				if IsMetaPedUsingComponent(Config.ComponentCategories.Boots) then
					local item = CachedComponents.Boots
					if item.drawable then
						SetTextureOutfitTints(PlayerPedId(), 'boots', item)
					end
				end

				if IsMetaPedUsingComponent(Config.ComponentCategories.Pant) then
					local item = CachedComponents.Pant
					if item.drawable then
						SetTextureOutfitTints(PlayerPedId(), 'pants', item)
					end
				end
			end

			-- to fix clip with boots and pants
			if key == "Pant" then
				if IsMetaPedUsingComponent(Config.ComponentCategories.Boots) then
					UpdateShopItemWearableState(CachedComponents.Boots.comp, `base`) -- -2081918609
					UpdatePedVariation()
				end
			end
		end, false)
		end
	end
end)

RegisterCommand("ringsL", function()
	if CachedComponents.RingLh.comp ~= -1 then
		return
	end
	toggleComp(0x7A6BBD0B, CachedComponents.RingLh, "RingLh")
end, false)

RegisterCommand("ringsR", function()
	if CachedComponents.RingRh.comp ~= -1 then
		return
	end
	toggleComp(0xF16A1D23, CachedComponents.RingRh, "RingRh")
end, false)

-- no /undress: the Clothing row does its own stripping

RegisterCommand("dress", function()
	if not next(CachedComponents) then
		return
	end
	IsPedReadyToRender()
	for _, Components in pairs(CachedComponents) do
		if type(Components) == "table" and Components.comp and Components.comp ~= -1 then
			ApplyShopItemToPed(Components.comp)
			UpdatePedVariation()
			if Components.drawable then
				SetMetaPedTag(PlayerPedId(), Components.drawable, Components.albedo, Components.normal, Components.material, Components.palette, Components.tint0, Components.tint1, Components.tint2)
			end
			UpdatePedVariation()
		end
	end
	ApplyCachedColors(PlayerPedId(), CachedComponents)
	-- CachedComponents carries no palette for pup_clothing's custom tints and cannot render its singleplayer garments at all
	TriggerEvent("pup_clothing:client:dressExtras")
	-- re-applying a garment hands it back in its default state, so rolled sleeves are put back after
	ReassertRolledClothing()
	CreatorClothesOn = true
end, false)


-- no /bandanaon: the mask toggle is /bandana in pup_robbery, which also feeds the robbery bandana requirement


local sleeves = true
local collar = true -- pup: hoisted from below /sleeves2 so BOTH sleeve commands see both states

-- a shirt has THREE wearable states, not four: base sleeves down
local function applyShirtWearable()
	local Components = CachedComponents.Shirt
	if Components.comp == -1 then return end

	local state
	if sleeves and collar then
		state = joaat("base")
	elseif collar then
		state = joaat("Closed_Collar_Rolled_Sleeve")
	else
		state = joaat("open_collar_rolled_sleeve") -- open collar is always rolled
	end
	-- the skin goes on first, or a shirt that stops rendering leaves a hole
	if EnsureBodySkin then EnsureBodySkin() end

	UpdateShopItemWearableState(Components.comp, state)

	if Components.drawable then
		if sleeves and collar then
			SetMetaPedTag(PlayerPedId(), Components.drawable, Components.albedo, Components.normal, Components.material,
				Components.palette, Components.tint0, Components.tint1, Components.tint2)
		else
			SetTextureOutfitTints(PlayerPedId(), 'shirts_full', Components)
		end
	end
	UpdatePedVariation()
	ApplyCachedColors(PlayerPedId(), CachedComponents)
end

-- Both keys are written by BOTH commands: either one can move the other flag
local function persistSleeveState()
	SetResourceKvp(("sleeves_%s"):format(CHARID or 0), not sleeves and "false" or "true")
	SetResourceKvp(("collar_%s"):format(CHARID or 0), not collar and "false" or "true")
	TriggerEvent("pup-clothing:sleevestoggle", not sleeves, not collar)
end

RegisterCommand("sleeves", function()
	local Components = CachedComponents.Shirt
	if Components.comp == -1 then return end

	sleeves = not sleeves
	if sleeves then collar = true end -- sleeves down only exists with the collar closed
	applyShirtWearable()
	persistSleeveState()
end, false)

RegisterCommand("sleeves2", function()
	local Components = CachedComponents.Shirt
	if Components.comp == -1 then return end

	collar = not collar
	if not collar then sleeves = false end -- an open collar only exists with sleeves rolled
	applyShirtWearable()
	persistSleeveState()
end, false)

local tuck = true
RegisterCommand("tuck", function()
	local ComponentB = CachedComponents.Boots
	if ComponentB.comp == -1 then return end
	local ComponentP = CachedComponents.Pant

	tuck = not tuck
	local wearableState = tuck and joaat("base") or -2081918609
	UpdateShopItemWearableState(ComponentB.comp, wearableState)

	if not tuck and ComponentP.drawable then
		SetTextureOutfitTints(PlayerPedId(), 'pants', ComponentP)
	end
	if not tuck and ComponentB.drawable then
		SetTextureOutfitTints(PlayerPedId(), 'boots', ComponentB)
	end

	if tuck and ComponentB.drawable then
		if ComponentP.comp == 1939930032 then -- dont ask me why
			SetMetaPedTag(PlayerPedId(), ComponentP.drawable, ComponentP.albedo, ComponentP.normal, ComponentP.material, ComponentP.palette, ComponentP.tint0, ComponentP.tint1, ComponentP.tint2)
		else
			SetTextureOutfitTints(PlayerPedId(), 'pants', ComponentP)
		end
	end
	ApplyCachedColors(PlayerPedId(), CachedComponents) -- tucking redraws boots and pants at stock tint

	local value = not tuck and "false" or "true"
	SetResourceKvp(("tuck_%s"):format(CHARID or 0), value)
	UpdatePedVariation()
end, false)

function ApplyRolledClothingStatus()
	local value = GetResourceKvpString(("sleeves_%s"):format(CHARID or 0))
	local value2 = GetResourceKvpString(("collar_%s"):format(CHARID or 0))
	local value3 = GetResourceKvpString(("tuck_%s"):format(CHARID or 0))
	-- kvp "false" = rolled/open/tucked, "true" = base, nil = never used the command
	local shirt = CachedComponents.Shirt
	if not shirt or not shirt.comp or shirt.comp == -1 then
		sleeves = true
		collar = true
	else
		if value == "false" then
			sleeves = true
			ExecuteCommand("sleeves")
		else
			sleeves = false
			ExecuteCommand("sleeves")
		end

		if value2 == "false" then
			collar = true
			ExecuteCommand("sleeves2")
		else
			collar = false
			ExecuteCommand("sleeves2")
		end
	end

	local boots = CachedComponents.Boots
	if boots and boots.comp and boots.comp ~= -1 then
		if value3 == "false" then
			tuck = true
			ExecuteCommand("tuck")
		else
			tuck = false
			ExecuteCommand("tuck")
		end
	else
		tuck = true
	end

	-- sync fred_metabolism's warmth penalty with the final state
	TriggerEvent("pup-clothing:sleevestoggle", not sleeves, not collar)
end

-- PUT THE ROLLED STATE BACK AFTER A CLOTHES CHANGE
local reassertQueued = false
function ReassertRolledClothing()
	if reassertQueued then return end
	reassertQueued = true
	CreateThread(function()
		Wait(250)
		reassertQueued = false
		if next(CachedComponents) then
			ApplyRolledClothingStatus()
		end
	end)
end

-- cross-resource entry point: pup_clothing (and anything else that dresses the player) fires this once it has finished
AddEventHandler("vorp_character:client:reassertRolledClothing", function()
	ReassertRolledClothing()
end)

-- /rc trace, one line per phase
local function rcDebugOn()
	return Config and Config.General.devMode == true
end

local function RcSnap(tag)
	if not rcDebugOn() then return end
	local ped <const> = PlayerPedId()
	print(("^3[rc:%-12s]^7 ped=%-8s model=%-12s health=%-4s core0=%-4s core1=%-4s cachedScale=%s")
		:format(tag,
			tostring(ped),
			tostring(GetEntityModel(ped)),
			tostring(GetEntityHealth(ped)),
			tostring(Citizen.InvokeNative(0x36731AC041289BB1, ped, 0, Citizen.ResultAsInteger())),
			tostring(Citizen.InvokeNative(0x36731AC041289BB1, ped, 1, Citizen.ResultAsInteger())),
			tostring(type(CachedSkin) == "table" and CachedSkin.Scale or nil)))
end

-- watch the core VALUES across the whole reload and print only when they CHANGE
local function rcWatchCores()
	if not rcDebugOn() then return end
	CreateThread(function()
		local t0 <const> = GetGameTimer()
		local lastH, lastS, lastPed
		while GetGameTimer() - t0 < 6000 do
			local ped <const> = PlayerPedId()
			local h <const> = Citizen.InvokeNative(0x36731AC041289BB1, ped, 0, Citizen.ResultAsInteger())
			local s <const> = Citizen.InvokeNative(0x36731AC041289BB1, ped, 1, Citizen.ResultAsInteger())
			if h ~= lastH or s ~= lastS or ped ~= lastPed then
				print(("^3[rc:core %5dms]^7 ped=%-8s core0=%-5s core1=%-5s health=%s%s")
					:format(GetGameTimer() - t0, tostring(ped), tostring(h), tostring(s),
						tostring(GetEntityHealth(ped)),
						(lastPed and ped ~= lastPed) and "   <- NEW PED" or ""))
				lastH, lastS, lastPed = h, s, ped
			end
			Wait(50)
		end
		print("^3[rc:core]^7 watch ended")
	end)
end

RegisterCommand(Config.Reload.command, function(_, args)
	-- never mid-creation
	if CharScreenOpen or InCharacterCreator or IsInCharCreation then
		TriggerEvent("vorp:TipRight", "You cannot do that while creating a character.", 3000)
		return
	end

	-- pup_hideouts sets this while the wagon charge or robbery bar runs
	if LocalPlayer.state.undergroundBusy then
		TriggerEvent("vorp:TipRight", "You cannot do that right now.", 3000)
		return
	end

	local __player = PlayerPedId()
	RcSnap("before")
	rcWatchCores()
	local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, __player)
	local cuffed = Citizen.InvokeNative(0x74E559B3BC910685, __player)
	local dead = IsEntityDead(__player)

	-- CAUGHT IN A LASSO COUNTS TOO
	local okGrab, grappled = pcall(function()
		return Citizen.InvokeNative(0x3BDFCF25B58B0415, __player)
	end)
	local lassoed = okGrab and (grappled == true or grappled == 1)
	local beingTied = false
	do
		local ok, v = pcall(function() return IsPedBeingHogtied and IsPedBeingHogtied(__player) end)
		beingTied = ok and (v == true or v == 1)
	end

	-- bolas: the native is thrower-side, so ask every nearby player's ped; ragdoll covers the struggle on the ground
	local bolaed = false
	pcall(function()
		for _, pid in ipairs(GetActivePlayers()) do
			local other = GetPlayerPed(pid)
			if other ~= 0 and other ~= __player then
				local hit = Citizen.InvokeNative(0x8D50F43298AB9545, other, __player)
				if hit == true or hit == 1 then bolaed = true return end
			end
		end
	end)
	if not bolaed and IsPedRagdoll(__player) then bolaed = true end

	if lassoed or beingTied or bolaed then
		TriggerEvent("vorp:TipRight", "You cannot do that while you are restrained.", 3000)
		return
	end

	if not Config.Reload.canRun() then
		return
	end

	if not hogtied and not cuffed and not dead then
		if not next(CachedSkin) and not next(CachedComponents) then
			return
		end

		if args[1] ~= "" then
			Custom = args[1]
		end
		LocalPlayer.state:set("IsBandanaOn", false, true)

		-- reload = true forces SetPlayerModel (client.lua:772), which builds a NEW ped
		local prevMount      <const> = IsPedOnMount(__player) and GetMount(__player) or nil
		local prevVehicle    <const> = (not prevMount) and GetVehiclePedIsIn(__player, false) or nil
		local prevSeat = -1
		if prevVehicle and prevVehicle ~= 0 then
			for seat = -1, 6 do
				if GetPedInVehicleSeat(prevVehicle, seat) == __player then
					prevSeat = seat
					break
				end
			end
		end

		local before         <const> = __player
		local prevHealth     <const> = GetEntityHealth(before)
		local prevHealthCore <const> = Citizen.InvokeNative(0x36731AC041289BB1, before, 0, Citizen.ResultAsInteger())
		local prevStamCore   <const> = Citizen.InvokeNative(0x36731AC041289BB1, before, 1, Citizen.ResultAsInteger())
		-- the stamina BAR (the outer sprint ring), 0.0-1.0
		local prevStamNorm   <const> = Citizen.InvokeNative(0x22F2A386D43048A9, before, Citizen.ResultAsFloat()) or 1.0

		-- Putting the values back, used in two places below.
		local function restoreVitals(ped)
			if not ped or not DoesEntityExist(ped) then return false end
			Citizen.InvokeNative(0xC6258F41D86676E0, ped, 0, prevHealthCore > 0 and prevHealthCore or 100)
			-- stamina is written too, but a trace showed core1 is never actually disturbed by the rebuild - this is belt and braces
			Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, prevStamCore > 0 and prevStamCore or 100)
			if prevHealth > 0 then
				SetEntityHealth(ped, prevHealth, 0)
			end

			-- DO NOT HAND OUT A FREE SPRINT BAR
			local nowNorm = Citizen.InvokeNative(0x22F2A386D43048A9, ped, Citizen.ResultAsFloat())
			if type(nowNorm) == 'number' and type(prevStamNorm) == 'number'
				and prevStamNorm > 0.0 and nowNorm < prevStamNorm then
				RestorePedStamina(ped, prevStamNorm)
			end
			return true
		end

		-- CATCH THE NEW PED ON THE FRAME IT APPEARS
		CreateThread(function()
			local t0 <const> = GetGameTimer()
			while GetGameTimer() - t0 < 5000 do
				Wait(0)
				local ped <const> = PlayerPedId()
				if ped ~= before and DoesEntityExist(ped) then
					local core <const> = Citizen.InvokeNative(0x36731AC041289BB1, ped, 0, Citizen.ResultAsInteger())
					if core >= prevHealthCore and GetEntityHealth(ped) >= prevHealth then
						break -- it stuck; nothing left to fix
					end
					restoreVitals(ped)
				end
			end
		end)

		LoadPlayerComponents(__player, CachedSkin, CachedComponents, true)
		RcSnap("after-load")

		CreateThread(function()
			-- Wait for the swap to actually land, not for a guessed number of milliseconds
			local waited = 0
			while PlayerPedId() == before and waited < 5000 do
				Wait(50)
				waited = waited + 50
			end
			if rcDebugOn() then
				print(("^3[rc:%-12s]^7 waited %dms  swapped=%s")
					:format("ped-swap", waited, tostring(PlayerPedId() ~= before)))
			end
			RcSnap("swapped")

			local ped = PlayerPedId()
			waited = 0
			while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and waited < 5000 do
				Wait(50)
				waited = waited + 50
				ped = PlayerPedId()
			end
			Wait(500)

			-- back on the horse / wagon before anything else touches the ped
			ped = PlayerPedId()
			if prevMount and DoesEntityExist(prevMount) then
				-- SetPedOntoMount is NOT a runtime global (pup-stable has to wrap it in client/natives.lua)
				Citizen.InvokeNative(0x028F76B6E78246EB, ped, prevMount, -1, false)
			elseif prevVehicle and prevVehicle ~= 0 and DoesEntityExist(prevVehicle) then
				TaskWarpPedIntoVehicle(ped, prevVehicle, prevSeat)
			end

			ped = PlayerPedId()
			if not restoreVitals(ped) then return end
			if rcDebugOn() then
				print(("^3[rc:%-12s]^7 wrote back  health=%s core0=%s core1=%s")
					:format("restore", tostring(prevHealth), tostring(prevHealthCore), tostring(prevStamCore)))
			end
			RcSnap("after-restore")

			-- a story ped wears nothing of ours: skip the whole re-decorate chain
			if PupStoryPed then return end

			-- tell everyone else the ped was rebuilt
			TriggerEvent('vorp_character:client:reloadedComponents')

			-- last, after every listener above has re-decorated the ped
			Wait(750)
			if ReapplyFaceOverlays then ReapplyFaceOverlays() end

			-- AND THEN LET pup-misc HAVE THE LAST WORD, or the makeup goes
			if GetResourceState('pup-misc') == 'started' then
				pcall(function() exports['pup-misc']:ReapplyOverlayTexture() end)
			end
		end)

		-- LoadPlayerComponents re-applies CachedSkin.Scale, which is a CLIENT cache - if it has drifted
		if PupResetHeight then PupResetHeight() end
	end
end, false)

-- /body1 .. /bodyN - the BUILD, for garments that clip
local function applyBuild(index)
	if not next(CachedSkin) then return end

	local builds <const> = Config.BodyType and Config.BodyType.Body
	local hash <const> = builds and builds[index]
	if not hash then return end

	-- temporary: applied on a copy so the cache (and /rc) keeps the saved build
	local temp = {}
	for k, v in pairs(CachedSkin) do temp[k] = v end
	temp.Body = hash
	LoadPlayerComponents(PlayerPedId(), temp, CachedComponents, false)
	-- components were rebuilt: let pup_clothing put NPC garments + tints back
	TriggerEvent('vorp_character:client:reloadedComponents')
end

for i = 1, #((Config.BodyType or {}).Body or {}) do
	RegisterCommand("body" .. i, function()
		applyBuild(i)
	end, false)
end

-- admin-panel height change (vorp_admin player profile)
RegisterNetEvent('vorp_character:adminSetScale', function(scale)
	scale = tonumber(scale)
	if not scale then return end
	if next(CachedSkin) then
		CachedSkin.Scale = scale
	end
	local ped = PlayerPedId()
	SetPedScale(ped, scale)
	-- without this the new height is stored but never rendered
	UpdatePedVariation(ped)
end)
