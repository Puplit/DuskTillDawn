-- holds all items from the server to be accessed by the client
CLIENT_ITEMS = {}
-- holds all items and weapons from the player from the server
PLAYER_INVENTORY = {
	ITEMS = {},
	WEAPONS = {},
	HasItem = function(_, itemName)
		for id, item in pairs(PLAYER_INVENTORY.ITEMS) do
			if item:getName() == itemName then
				return true, id
			end
		end
		return false
	end,
}

local inventory <const> = {
	RECEIVE_ITEM = function(name, id, amount, metadata, degradation, percentage, durability)
		if not name or not CLIENT_ITEMS[name] then
			return
		end

		local item <const> = PLAYER_INVENTORY.ITEMS[id]
		if item then
			item:addCount(amount)
		else
			local newItem <const> = ITEM:Register({
				id = id,
				count = amount,
				limit = CLIENT_ITEMS[name].limit,
				label = CLIENT_ITEMS[name].label,
				name = name,
				metadata = SHARED_UTILS.MERGE_TABLES(CLIENT_ITEMS[name].metadata, metadata),
				type = "item_standard",
				canUse = CLIENT_ITEMS[name].canUse,
				canRemove = CLIENT_ITEMS[name].canRemove,
				desc = CLIENT_ITEMS[name].desc,
				group = CLIENT_ITEMS[name].group or 1,
				rarity = CLIENT_ITEMS[name].rarity or 1,
				durability = durability or CLIENT_ITEMS[name].durability,
				instruction = CLIENT_ITEMS[name].instruction,
				weight = CLIENT_ITEMS[name].weight or 0.25,
				degradation = degradation,
				maxDegradation = CLIENT_ITEMS[name].maxDegradation,
				percentage = percentage
			})
			PLAYER_INVENTORY.ITEMS[id] = newItem
		end
		NUI_SERVICE.INVENTORY.UPDATE_ITEM(id)
	end,
	REMOVE_ITEM = function(id, count)
		local item <const> = PLAYER_INVENTORY.ITEMS[id]
		if not item then return end
		item:quitCount(count)

		if item:getCount() <= 0 then
			NUI_SERVICE.SHARED.REMOVE(id, item.type)
			PLAYER_INVENTORY.ITEMS[id] = nil
		else
			NUI_SERVICE.INVENTORY.UPDATE_ITEM(id)
		end
	end,
	RECEIVE_WEAPON = function(id, propietary, name, ammos, label, serial_number, custom_label, source, custom_desc, weight, components, status)
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[id]
		if weapon then return print("Weapon already exists in inventory") end

		local newWeapon <const> = WEAPON:Register({
			id = id,
			propietary = propietary,
			name = name,
			label = custom_label or label,
			ammo = ammos,
			components = components or {},
			currInv = "default",
			dropped = 0,
			used = false,
			used2 = false,
			desc = custom_desc or UTILS.WEAPONS.GET_DEFAULT_DESC(name),
			group = 5,
			source = source,
			serial_number = serial_number,
			custom_label = custom_label,
			custom_desc = custom_desc,
			weight = weight,
			degradation = status?.degradation,
			damage = status?.damage,
			dirt = status?.dirt,
			soot = status?.soot,
		})


		local isPetrolCan = GetWeapontypeGroup(name) == joaat("GROUP_PETROLCAN")
		if isPetrolCan then
			local defaultClipSize <const> = SHARED_DATA.WEAPONS[name] and SHARED_DATA.WEAPONS[name].DefaultClipSize or 20
			newWeapon:addAmmo("AMMO_MOONSHINEJUG_MP", defaultClipSize)
		end

		local isGun = IsWeaponAGun(name) == 1
		if isGun then
			newWeapon:setDefaultAttachments()
			newWeapon:loadAmmo()
		end

		NUI_SERVICE.INVENTORY.UPDATE_WEAPON(id)
	end,
	SET_WEAPON_CUSTOM_LABEL = function(id, label)
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[id]
		if not weapon then return end
		weapon:setCustomLabel(label)
	end,
	SET_WEAPON_CUSTOM_DESC = function(id, desc)
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[id]
		if not weapon then return end
		weapon:setCustomDesc(desc)
	end,
	SET_WEAPON_SERIAL_NUMBER = function(id, serial_number)
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[id]
		if not weapon then return end
		weapon:setSerialNumber(serial_number)
	end,
	ON_SELECTED_CHARACTER = function()
		-- ped rebuilt: the old guids point into a discarded engine inventory
		INVENTORY_SERVICE.OFFHAND_GUIDS = {}
		SetNuiFocus(false, false)
		SendNUIMessage({ action = "hide" })
		-- new character, new grid: the old cells must not be saved under the new layout key
		SendNUIMessage({ action = "resetMainGrid" })
		TriggerServerEvent("vorpinventory:getItemsTable")
		Wait(300)
		TriggerServerEvent("vorpinventory:getInventory")
		TriggerServerEvent("vorpCore:LoadAllAmmo")
		print("Inventory loaded")
	end,
	PROCESS_ITEMS = function(items)
		CLIENT_ITEMS = {}
		local data = msgpack.unpack(items)
		for _, item in pairs(data) do
			local newItem <const> = ITEM:Register(item)
			CLIENT_ITEMS[item.item] = newItem
		end
	end,

	HAS_LEFT_HOLSTER = function()
		local function getCategoryOfComponentAtIndex(ped, componentIndex)
			return Citizen.InvokeNative(0x9b90842304c938a7, ped, componentIndex, 0, Citizen.ResultAsInteger())
		end
		local function getNumComponentsInPed(ped)
			return Citizen.InvokeNative(0x90403E8107B60E81, ped, Citizen.ResultAsInteger())
		end

		local function getComponent()
			local ped = CACHE.Ped
			local numComponents = getNumComponentsInPed(ped)
			if not numComponents or numComponents < 1 then
				return false
			end
			for componentIndex = 0, numComponents - 1, 1 do
				local componentCategory = getCategoryOfComponentAtIndex(ped, componentIndex)
				if componentCategory == `holsters_left` then
					return true
				end
			end

			return false
		end
		return getComponent()
	end,

	-- Dual wield needs TWO engine items in the ped's wardrobe inventory
	OFFHAND_GUIDS = {},

	APPLY_OFF_HAND_HOLSTER = function()
		local S = INVENTORY_SERVICE
		if #S.OFFHAND_GUIDS == 0 then
			local g = AddWardrobeInventoryItem("UPGRADE_OFFHAND_HOLSTER", 0x39E57B01)
			if g then S.OFFHAND_GUIDS[#S.OFFHAND_GUIDS + 1] = g end
		end
		-- visible holster only if they are not already wearing one of their own
		if not S.HAS_LEFT_HOLSTER() then
			local gender = IsPedMale(CACHE.Ped) and "M" or "F"
			local g = AddWardrobeInventoryItem("CLOTHING_ITEM_" .. gender .. "_OFFHAND_000_TINT_004", 0xF20B6B4A)
			if g then S.OFFHAND_GUIDS[#S.OFFHAND_GUIDS + 1] = g end
		end
	end,

	-- called when no equipped weapon has used2
	REMOVE_OFF_HAND_HOLSTER = function()
		local S = INVENTORY_SERVICE
		if #S.OFFHAND_GUIDS == 0 then return end
		for _, guid in ipairs(S.OFFHAND_GUIDS) do
			-- _INVENTORY_REMOVE_GUID (same native the weapon path uses)
			Citizen.InvokeNative(0x3E4E811480B3AE79, 1, guid, 1, joaat("ADD_REASON_DEFAULT"))
		end
		S.OFFHAND_GUIDS = {}
		local ped = CACHE.Ped
		Citizen.InvokeNative(0xD710A5007C2AC539, ped, `holsters_left`, 0) -- strip the visual
		Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
		Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
	end,

	-- PUT IT AWAY AND CHECK THAT IT WENT.
	--
	-- Dual wield draws both guns on purpose (SET_CURRENT_PED_WEAPON_BY_GUID with
	-- equipNow), so the loadout always ends armed and something has to holster.
	-- HolsterPedWeapons' last arg is `immediately`; false gives an animated
	-- holster that a still-settling respawned ped interrupts, leaving the gun out.
	-- So: wait out any holster animation already running, ask for an instant one,
	-- then verify with _IS_PED_CURRENT_WEAPON_HOLSTERED instead of hoping.
	ENSURE_HOLSTERED = function(tries)
		CreateThread(function()
			for _ = 1, (tonumber(tries) or 6) do
				-- never fight an in-flight holster: the call would be swallowed
				local spin = 0
				while Citizen.InvokeNative(0x2387D6E9C6B478AA, CACHE.Ped) and spin < 20 do
					Wait(50)
					spin = spin + 1
				end
				if Citizen.InvokeNative(0xBDD9C235D8D1052E, CACHE.Ped) then return end
				if not DoesEntityExist(CACHE.Ped) then return end
				-- _SET_WEAPON_HOLSTERED(ped, disableAnim) - no animation to interrupt
				Citizen.InvokeNative(0x4820A6939D7CEF28, CACHE.Ped, true)
				HolsterPedWeapons(CACHE.Ped, true, false, true, true)
				Wait(400)
			end
		end)
	end,

	-- a ped rebuild wipes the engine inventory: drop stale guids and re-add both items
	REFRESH_OFF_HAND_HOLSTER = function()
		local S = INVENTORY_SERVICE
		local dualActive = false
		for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
			if weapon:getUsed2() then dualActive = true break end
		end
		S.OFFHAND_GUIDS = {}
		if dualActive then
			S.APPLY_OFF_HAND_HOLSTER()
		end
	end,
	GET_LOADOUT = function(loadout)
		RemoveAllPedWeapons(CACHE.Ped, true, true)
		Wait(1000)

		-- per-weapon isolation, the client mirror of itemsDatabase.loadWeaponRow
		local function registerOne(weapon)
			if weapon.currInv == "default" and (weapon.dropped == nil or weapon.dropped == 0) then
				local newWeapon <const> = WEAPON:Register({
					id = tonumber(weapon.id),
					identifier = weapon.identifier,
					label = weapon.custom_label or UTILS.WEAPONS.GET_DEFAULT_LABEL(weapon.name),
					name = weapon.name,
					ammo = weapon.ammo,
					components = weapon.components,
					used = weapon.used,
					used2 = weapon.used2,
					desc = weapon.custom_desc or UTILS.WEAPONS.GET_DEFAULT_DESC(weapon.name),
					currInv = weapon.curr_inv,
					dropped = 0,
					group = 5,
					custom_label = weapon.custom_label,
					serial_number = weapon.serial_number,
					custom_desc = weapon.custom_desc,
					weight = weapon.weight,
					degradation = weapon.degradation,
					damage = weapon.damage,
					dirt = weapon.dirt,
					soot = weapon.soot,
				})

				if CONFIG.AUTO_EQUIP_USED_WEAPONS then
					if newWeapon:getUsed() or newWeapon:getUsed2() then
						if INVENTORY_SERVICE.IS_WEAPON_EQUIP_BLOCKED_BY_LIMIT(newWeapon:getId(), newWeapon:getName()) then
							newWeapon:setUsed(false)
							newWeapon:setUsed2(false)
						else
							if newWeapon:getUsed() and not newWeapon:getUsed2() then
								if not CONFIG.DUAL_WIELD then
									INVENTORY_SERVICE.SET_WEAPONS_ON_PLAYER(newWeapon:getId())
								else
									local oneHanded <const> = IsWeaponOneHanded(joaat(newWeapon:getName())) == 1
									if not oneHanded then
										INVENTORY_SERVICE.SET_WEAPONS_ON_PLAYER(newWeapon:getId())
									end
								end
							end
						end
					end
				end
			end
		end

		for _, weapon in ipairs(loadout) do
			local ok, err = pcall(registerOne, weapon)
			if not ok then
				print(("^1[vorp_inventory]^7 GET_LOADOUT: skipped weapon id=%s name=%s - %s"):format(
					tostring(weapon and weapon.id), tostring(weapon and weapon.name), tostring(err)))
			end
		end

		local dualCount = 0
		if CONFIG.DUAL_WIELD then
			-- must apply after the non dual weapons are added
			local dual = {}
			for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
				if weapon:getUsed2() or weapon:getUsed() then
					local oneHanded = IsWeaponOneHanded(joaat(weapon:getName())) == 1
					local isWeaponAGun = Citizen.InvokeNative(0x705BE297EEBDB95D, joaat(weapon:getName()))
					if isWeaponAGun and oneHanded then
						table.insert(dual, weapon:getId())
					end
				end
			end
			dualCount = #dual
			WEAPON:AddDualWield(dual)
		end

		-- HOLSTER WHATEVER THE LOADOUT JUST DREW - not only the dual pair
		local equipped = false
		for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
			if weapon:getUsed() or weapon:getUsed2() then equipped = true break end
		end
		if equipped or dualCount > 0 then
			local waited = 0
			while waited < 3000 and not IsPedArmed(CACHE.Ped, 7) do
				Wait(100)
				waited = waited + 100
			end
			Wait(300) -- let the last give settle before asking for the holster
			INVENTORY_SERVICE.ENSURE_HOLSTERED()
		end

		Wait(2000)
		if CONFIG.USE_WEAPON_DEGRADATION then
			-- need another loop because of get status method
			local weaponsToSetStatus <const> = {}
			for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
				if (weapon:getUsed() or weapon:getUsed2()) then
					local payload = {
						degradation = weapon.degradation,
						damage = weapon.damage,
						dirt = weapon.dirt,
						soot = weapon.soot,
					}
					LAST_CLIENT_WEAPON_STATUS[weapon:getId()] = json.encode(payload)
					-- EVERY equipped weapon was just re-created as a fresh zero-wear object, whatever give path it took
					weapon.statusFreshUntil = GetGameTimer() + 30000
					table.insert(weaponsToSetStatus, weapon:getId())
				end
			end

			SetTimeout(4000, function()
				for _, weaponId in pairs(weaponsToSetStatus) do
					Wait(500)
					local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
					if weapon then
						weapon:setStatus()
					end
				end
				table.wipe(weaponsToSetStatus)
			end)
		end

		NUI_SERVICE.INVENTORY.GET_LOAD()
	end,
	IS_WEAPON_EQUIP_BLOCKED_BY_LIMIT = function(weaponId, weaponName)
		local shared <const> = SHARED_DATA.WEAPONS[weaponName]
		if not shared then return end

		local cfg <const> = CONFIG.EQUIP_WEAPONS
		if not cfg then return end

		local function getCount(categoryKey)
			local count = 0
			for id, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
				if id ~= weaponId and (weapon:getUsed() or weapon:getUsed2()) then
					local _shared <const> = SHARED_DATA.WEAPONS[weapon:getName()]
					if _shared and _shared[categoryKey] then
						-- only count guns ACTUALLY on the ped: a stale used flag from an old session otherwise blocks equips forever
						if HasPedGotWeapon(CACHE.Ped, joaat(weapon:getName()), 0, false) == 1 then
						count = count + 1
					end
				end
			end
			end
			return count
		end

		if shared.LongWeapon and cfg.LONG_WEAPONS and cfg.LONG_WEAPONS > 0 then
			if getCount("LongWeapon") >= cfg.LONG_WEAPONS then
				return true, "long", cfg.LONG_WEAPONS
			end
		end

		if shared.ShortWeapon and cfg.SHORT_WEAPONS and cfg.SHORT_WEAPONS > 0 then
			if getCount("ShortWeapon") >= cfg.SHORT_WEAPONS then
				return true, "short", cfg.SHORT_WEAPONS
			end
		end

		return false
	end,

	SET_WEAPON_USED = function(id, used)
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[id]
		if not weapon then return end
		weapon:setUsed(used)
		NUI_SERVICE.INVENTORY.UPDATE_WEAPON(id)
		weapon:equipwep()
		-- this is the server-driven equip path (vorpInventory:setWeaponUsed)
		if used then
			weapon:loadComponents(true)
		end
	end,
	SET_WEAPONS_ON_PLAYER = function(id)
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[id]
		if not weapon then return print("Weapon not found 1") end

		local isMelee <const> = IsWeaponMeleeWeapon(weapon:getName()) == 1
		local isThrowable <const> = IsWeaponThrowable(weapon:getName()) == 1
		local isPetrolCan <const> = GetWeapontypeGroup(weapon:getName()) == joaat("GROUP_PETROLCAN")
		local isKit <const> = IsWeaponKit(weapon:getName()) == 1
		local isLantern <const> = IsWeaponLantern(weapon:getName()) == 1
		local isFishingRod <const> = weapon:getName() == `WEAPON_FISHINGROD`

		if isMelee or isThrowable or isPetrolCan or isKit or isLantern or isFishingRod then
			local ammoCount = 1
			if joaat(weapon:getName()) == `WEAPON_THROWN_THROWING_KNIVES` then
				ammoCount = weapon:getAmmo("AMMO_THROWING_KNIVES")
			elseif isThrowable then
				-- DO NOT HAND OUT A FREE ROUND
				ammoCount = 0
				for _, amount in pairs(weapon:getAllAmmo() or {}) do
					ammoCount = ammoCount + (tonumber(amount) or 0)
				end
			end

			if isPetrolCan then
				local defaultClipSize <const> = SHARED_DATA.WEAPONS[weapon:getName()] and SHARED_DATA.WEAPONS[weapon:getName()].DefaultClipSize or 20
				weapon:addAmmo("AMMO_MOONSHINEJUG_MP", defaultClipSize)
				ammoCount = weapon:getAmmo("AMMO_MOONSHINEJUG_MP")
			end
			-- pup: fresh object here too - stored condition stays authoritative
			-- until a setStatus lands (melee/throwables mostly cannot degrade,
			-- but the ones that can must not have their wear zero-read)
			weapon.statusFreshUntil = GetGameTimer() + 12000

			GiveWeaponToPed(CACHE.Ped, joaat(weapon:getName()), ammoCount, false, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
			local timer = GetGameTimer()
			repeat Wait(0) until HasPedGotWeapon(CACHE.Ped, joaat(weapon:getName()), 0, false) == 1 or GetGameTimer() - timer > 10000
			if GetGameTimer() - timer > 10000 then
				print("weapon not on ped after 10 seconds")
			end
		else
			-- stock 13-arg give: GiveDelayedWeaponToPed does not put the weapon on here
			weapon.statusFreshUntil = GetGameTimer() + 12000
			GiveWeaponToPed(CACHE.Ped, joaat(weapon:getName()), 0, false, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)

			if not isMelee and not isThrowable then
				weapon:setDefaultAttachments()
				weapon:loadAmmo()
				-- forced for the same reason as SET_WEAPON_USED above: the GiveWeaponToPed on the line above created a fresh, stock weapon
				weapon:loadComponents(true)
				SetTimeout(2000, function()
					weapon:setStatus()
				end)
			end
		end

		local serial = weapon:getSerialNumber()
		local info = { weaponId = id, serialNumber = serial }
		local weapName = joaat(weapon:getName())
		local key = string.format("GetEquippedWeaponData_%d", weapName)
		LocalPlayer.state:set(key, info, true)

		TriggerServerEvent("pup_gunsmith:weaponused", { id = id, name = weapon:getName(), type = "item_weapon", hash = weapName })
		TriggerEvent("vorp_inventory:onWeaponEquipped", weapon:getAllComponents(), id, weapon:getName(), false, weapon.defaultAttachments)
	end,

	GET_INVENTORY = function(inventory)
		PLAYER_INVENTORY.ITEMS = {}
		local inventoryItems <const> = msgpack.unpack(inventory)

		for _, item in pairs(inventoryItems) do
			local newItem <const> = ITEM:Register({
				id = item.id,
				count = item.count,
				limit = item.limit,
				label = item.label,
				name = item.name,
				metadata = item.metadata,
				type = item.type,
				canUse = item.canUse,
				canRemove = item.canRemove,
				desc = item.desc,
				owner = item.owner,
				group = item.group,
				rarity = item.rarity,
				durability = item.durability,
				instruction = item.instruction,
				weight = item.weight,
				degradation = item.degradation,
				maxDegradation = item.maxDegradation,
				percentage = item.percentage
			})
			PLAYER_INVENTORY.ITEMS[item.id] = newItem
		end
	end,
	ASK_TO_GIVE_ITEMS = function(cb, data)
		local giveLabel
		if data.type == "item_money" then
			giveLabel = data.amount .. "$"
		elseif data.type == "item_gold" then
			giveLabel = data.amount .. " gold"
		elseif data.type == "item_ammo" then
			giveLabel = data.amount .. " ammo"
		elseif data.type == "item_standard" then
			local itemName <const> = data.itemName
			local itemCount <const> = data.itemCount
			local itemLabel <const> = CLIENT_ITEMS[itemName] and CLIENT_ITEMS[itemName].label or itemName
			giveLabel = itemCount .. " " .. itemLabel
		elseif data.type == "item_weapon" then
			local weaponName <const> = data.weaponName
			local weaponLabel <const> = SHARED_DATA.WEAPONS[weaponName] and SHARED_DATA.WEAPONS[weaponName].label or weaponName
			giveLabel = weaponLabel
		else
			giveLabel = "something"
		end
		CORE.NotifyObjective(LANG.someoneWantsToGiveYouSomething, 5000)

		local timeoutMs <const> = 5000
		local timer <const> = GetGameTimer()
		local group <const> = GetRandomIntInRange(0, 0xffffff)
		local function createPrompt(control, label)
			local prompt <const> = UiPromptRegisterBegin()
			UiPromptSetControlAction(prompt, control)
			UiPromptSetText(prompt, VarString(10, 'LITERAL_STRING', label))
			UiPromptSetEnabled(prompt, true)
			UiPromptSetVisible(prompt, true)
			UiPromptSetStandardMode(prompt, true)
			UiPromptSetGroup(prompt, group, 0)
			UiPromptRegisterEnd(prompt)
			return prompt
		end

		local acceptPrompt <const> = createPrompt(`INPUT_FRONTEND_ACCEPT`, "Accept")
		local cancelPrompt <const> = createPrompt(`INPUT_FRONTEND_CANCEL`, "Deny")
		local accepted = false

		repeat
			Wait(0)
			local remainingSec <const> = math.max(0, math.ceil((timeoutMs - (GetGameTimer() - timer)) / 1000))
			local label <const> = VarString(10, 'LITERAL_STRING', ("Receive %s (%ds)"):format(giveLabel, remainingSec))
			UiPromptSetActiveGroupThisFrame(group, label, 0, 0, 0, 0)

			if UiPromptHasStandardModeCompleted(acceptPrompt, 0) then
				accepted = true
				break
			end

			if UiPromptHasStandardModeCompleted(cancelPrompt, 0) then
				accepted = false
				break
			end
		until GetGameTimer() - timer > timeoutMs

		UiPromptDelete(cancelPrompt)
		UiPromptDelete(acceptPrompt)

		return cb(accepted)
	end
}

INVENTORY_SERVICE = inventory
