local LIB <const> = Import 'class' --[[@as CLASS]]
local _EQUIPPED <const> = {}
-- PASSIVE component tracing - every equip prints one [comps] line per saved component to F8
--
-- OWN KEY, not TRACE_COMPONENTS. config/config.lua is a SHARED script, so one shared
-- flag would also put [comps] lines in every player's F8 while diagnosing the
-- server's [compsdb] trace. Set this only when the CLIENT cache is in doubt.
PUP_TRACE_COMPONENTS = (CONFIG and CONFIG.TRACE_COMPONENTS_CLIENT) or false
-- per-comp apply rows (12+ lines per run)
PUP_TRACE_COMPONENTS_VERBOSE = (CONFIG and CONFIG.TRACE_COMPONENTS_VERBOSE) or false

-- set whenever loadComponents is applying
local compsApplyCooldown = 0

-- COMPONENT NATIVES BY RAW HASH, not by name
local function GiveWeaponComponentToEntity(entity, componentHash, weaponHash, equipNow)
	return Citizen.InvokeNative(0x74C9090FDD1BB48E, entity, componentHash, weaponHash, equipNow)
end

local function RemoveWeaponComponentFromPed(ped, componentHash, weaponHash)
	return Citizen.InvokeNative(0x19F70C4D80494FF8, ped, componentHash, weaponHash)
end

local function getObjectIndexFromPed(weapon)
	for attachPoint = 0, 29 do
		local _, _weapon <const> = GetCurrentPedWeapon(CACHE.Ped, true, attachPoint, false)
		if _weapon == weapon then
			return GetObjectIndexFromEntityIndex(GetCurrentPedWeaponEntityIndex(CACHE.Ped, attachPoint))
		end
	end

	return nil
end

function GetGuidFromItemId(inventoryId, itemData, category, slotId)
	local outItem = DataView.ArrayBuffer(8 * 13)

	if not itemData then
		itemData = 0
	end
	--InventoryGetGuidFromItemid
	local success = Citizen.InvokeNative(0x886DFD3E185C8A89, inventoryId, itemData, category, slotId, outItem:Buffer())
	if success then
		return outItem:Buffer() --Seems to not return anythign diff. May need to pull from native above
	else
		return nil
	end
end

function AddWardrobeInventoryItem(itemName, slotHash)
	local itemHash    = joaat(itemName)
	local addReason   = joaat("ADD_REASON_DEFAULT")
	local inventoryId = 1

	-- _ITEMDATABASE_IS_KEY_VALID
	local isValid     = Citizen.InvokeNative(0x6D5D51B188333FD1, itemHash, 0) --ItemdatabaseIsKeyValid
	if not isValid then return end

	local characterItem = GetGuidFromItemId(inventoryId, nil, joaat("CHARACTER"), 0xA1212100)
	if not characterItem then return end

	local wardrobeItem = GetGuidFromItemId(inventoryId, characterItem, joaat("WARDROBE"), 0x3DABBFA7)
	if not wardrobeItem then return end

	local itemData = DataView.ArrayBuffer(8 * 13)

	-- _INVENTORY_ADD_ITEM_WITH_GUID
	local isAdded = Citizen.InvokeNative(0xCB5D11F9508A928D, inventoryId, itemData:Buffer(), wardrobeItem, itemHash, slotHash, 1, addReason)
	if not isAdded then return end

	-- _INVENTORY_EQUIP_ITEM_WITH_GUID
	local equipped = Citizen.InvokeNative(0x734311E2852760D0, inventoryId, itemData:Buffer(), true)
	if not equipped then return end
	-- the guid, so the caller can take the item away again later
	return itemData:Buffer()
end

local Weapon <const> = LIB.Class:Create({
	constructor = function(self, data)
		-- NIL-SAFE, same trap as the server WeaponClass
		local value <const>         = SHARED_DATA.WEAPONS[data.name] or {}
		self.id                     = data.id or 0
		self.name                   = data.name or ''
		self.label                  = data.label or ''
		self.desc                   = data.desc or ''
		self.propietary             = data.propietary or 0
		self.ammo                   = data.ammo or {}
		self.components             = data.components or {}
		self.used                   = data.used or false
		self.used2                  = data.used2 or false
		self.currInv                = data.currInv or ''
		self.group                  = data.group or 5
		self.weight                 = data.weight or 0.25
		self.custom_label           = data.custom_label or ''
		self.custom_desc            = data.custom_desc or ''
		self.serial_number          = data.serial_number or ''
		self.source                 = data.source
		self.defaultClipSize        = value.DefaultClipSize or 0
		self.componentCategoryCount = (value and value.ComponentCategoryCount) or 0
		self.defaultAttachments     = {}
		self.degradation            = data.degradation or 0.0
		self.damage                 = data.damage or 0.0
		self.dirt                   = data.dirt or 0.0
		self.soot                   = data.soot or 0.0
		-- the master switch wins over the per-weapon NoDegradation flag, so the
		-- tooltip bars and every other consumer agree when wear is turned off
		self.canDegrade             = CONFIG.USE_WEAPON_DEGRADATION and value.NoDegradation ~= true or false
	end,


	_getGuidFromItemId = function(_, inventoryId, itemData, category, slotId)
		local outItem <const> = DataView.ArrayBuffer(8 * 13)
		--INVENTORY_GET_GUID_FROM_ITEMID
		local success <const> = Citizen.InvokeNative(0x886DFD3E185C8A89, inventoryId, itemData and itemData or 0, category, slotId, outItem:Buffer())
		return success and outItem or nil
	end,

	_moveInventoryItem = function(_, inventoryId, old, new, slot)
		local outGUID <const> = DataView.ArrayBuffer(8 * 13)
		if not slot then slot = 1 end
		local sHash <const>   = "SLOTID_WEAPON_" .. tostring(slot)
		--_INVENTORY_MOVE_INVENTORY_ITEM
		local success <const> = Citizen.InvokeNative(0xDCCAA7C3BFD88862, inventoryId, old, new, joaat(sHash), 1, outGUID:Buffer())
		return success and outGUID or nil
	end,

	_addWeapon = function(self, weapon, slot, id)
		if slot == 0 and id then
			if #_EQUIPPED > 0 then
				slot = 1
			end
		end
		local weaponHash      = joaat(weapon)
		local sHash           = "SLOTID_WEAPON_" .. tostring(slot)
		local reason          = joaat("ADD_REASON_DEFAULT")
		local inventoryId     = 1
		local slotHash        = joaat(sHash)
		local move            = false
		--_ITEMDATABASE_IS_KEY_VALID
		local isValid <const> = Citizen.InvokeNative(0x6D5D51B188333FD1, weaponHash, 0)
		if not isValid then
			print("Non valid weapon")
			return false
		end

		local characterItem <const> = self:_getGuidFromItemId(inventoryId, nil, `CHARACTER`, `SLOTID_NONE`)
		if not characterItem then
			print("no characterItem")
			return false
		end

		local weaponItem <const> = self:_getGuidFromItemId(inventoryId, characterItem:Buffer(), `CARRIED_WEAPONS`, `SLOTID_CARRIED_WEAPONS`)
		if not weaponItem then
			print("no weaponItem")
			return false
		end

		if slot == 1 and id then
			if #_EQUIPPED > 0 then
				local newGUID <const> = self:_moveInventoryItem(inventoryId, _EQUIPPED[1].guid, weaponItem:Buffer())
				if not newGUID then
					print("can't move item")
					return false
				end
				slotHash = joaat('SLOTID_WEAPON_0')
				slot     = 0
				move     = true
			else
				slotHash = joaat('SLOTID_WEAPON_0')
				slot     = 0
			end
		end
		--_INVENTORY_ADD_ITEM_WITH_GUID
		local itemData <const> = DataView.ArrayBuffer(8 * 13)
		local isAdded <const>  = Citizen.InvokeNative(0xCB5D11F9508A928D, inventoryId, itemData:Buffer(), weaponItem:Buffer(), weaponHash, slotHash, 1, reason)
		if not isAdded then
			print("Not added")
			return false
		end
		--_INVENTORY_EQUIP_ITEM_WITH_GUID
		local equipped <const> = Citizen.InvokeNative(0x734311E2852760D0, inventoryId, itemData:Buffer(), true)
		if not equipped then
			print("not able to equip")
			return false
		end
		--SET_CURRENT_PED_WEAPON_BY_GUID
		Citizen.InvokeNative(0x12FB95FE3D579238, CACHE.Ped, itemData:Buffer(), true, slot, false, false)
		if move then
			--SET_CURRENT_PED_WEAPON_BY_GUID
			Citizen.InvokeNative(0x12FB95FE3D579238, CACHE.Ped, _EQUIPPED[1].guid, true, 1, false, false)
			TriggerServerEvent("pup_gunsmith:applyDupeTint", id, itemData:Buffer(), weaponHash)
		end
		if id then
			table.insert(_EQUIPPED, { id = id, guid = itemData:Buffer() })
		end
		-- dual-wield re-apply
		if CONFIG.USE_WEAPON_COMPONENTS then
			CreateThread(function()
				Wait(250) -- let the game finish seating both weapons first
				local seen = {}
				for _, entry in ipairs(_EQUIPPED) do
					local w = entry.id and PLAYER_INVENTORY.WEAPONS[entry.id]
					if w and not seen[entry.id] and next(w.components or {}) then
						seen[entry.id] = true
						w:loadComponents(true)
					end
				end
			end)
		end

		return true
	end,

	get = {

		getId                     = function(self)
			return self.id
		end,

		getName                   = function(self)
			return self.name
		end,

		getLabel                  = function(self)
			return self.label
		end,

		getDesc                   = function(self)
			return self.desc
		end,

		getPropietary             = function(self)
			return self.propietary
		end,

		getCurrInv                = function(self)
			return self.currInv
		end,

		getGroup                  = function(self)
			return self.group
		end,

		getWeight                 = function(self)
			return self.weight
		end,

		getCustomLabel            = function(self)
			return self.custom_label
		end,

		getCustomDesc             = function(self)
			return self.custom_desc
		end,

		getSerialNumber           = function(self)
			return self.serial_number
		end,

		getUsed                   = function(self)
			return self.used
		end,

		getUsed2                  = function(self)
			return self.used2
		end,

		getAllAmmo                = function(self)
			return self.ammo or {}
		end,

		getAllComponents          = function(self)
			if not CONFIG.USE_WEAPON_COMPONENTS then return {} end
			return self.components
		end,

		-- this is right but also not used
		getAmmo                   = function(self, type)
			if self.ammo[type] then
				return self.ammo[type]
			end
			return 0
		end,

		getDefaultClipSize        = function(self)
			return self.defaultClipSize
		end,

		getComponentCategoryCount = function(self)
			if not CONFIG.USE_WEAPON_COMPONENTS then return 0 end
			return self.componentCategoryCount
		end,

		getStatus                 = function(self)
			if not CONFIG.USE_WEAPON_DEGRADATION then return {} end
			-- a just-equipped weapon is a FRESH object with zero wear until setStatus re-applies the stored condition ~1-2s later
			if self.statusFreshUntil and GetGameTimer() < self.statusFreshUntil then
				return {
					degradation = self.degradation or 0.0,
					damage      = self.damage or 0.0,
					dirt        = self.dirt or 0.0,
					soot        = self.soot or 0.0,
				}
			end
			local weaponObject <const> = getObjectIndexFromPed(joaat(self.name))
			if not weaponObject then return {} end
			local function normalize(v)
				v = tonumber(v)
				if not v then return 0.0 end
				if v <= 0.0 then return 0.0 end
				if v >= 1.0 then return 1.0 end
				return v
			end

			self.degradation = tonumber(string.format("%.2f", GetWeaponDegradation(weaponObject)))
			self.damage = tonumber(string.format("%.2f", GetWeaponDamage(weaponObject)))
			self.dirt = tonumber(string.format("%.2f", GetWeaponDirt(weaponObject)))
			self.soot = tonumber(string.format("%.2f", GetWeaponSoot(weaponObject)))

			self.degradation = normalize(self.degradation)
			self.damage = normalize(self.damage)
			self.dirt = normalize(self.dirt)
			self.soot = normalize(self.soot)

			return { degradation = self.degradation, damage = self.damage, dirt = self.dirt, soot = self.soot }
		end,

	},

	set = {
		setDefaultAttachments = function(self)
			if not CONFIG.USE_WEAPON_COMPONENTS then return end
			local attachments <const> = SHARED_DATA.WEAPONS[self.name]?.Components
			if not attachments then return end

			if not next(self.defaultAttachments) then
				self.defaultAttachments = {}
			end

			for category, value in pairs(attachments) do
				if category ~= "SCOPE" then
					for component, _ in pairs(value) do
						if HasPedGotWeaponComponent(CACHE.Ped, joaat(component), joaat(self.name)) == 1 then
							self.defaultAttachments[category] = component
						end
					end
				end
			end
		end,

		UnequipWeapon         = function(self, skipTrigger)
			local function setLeftWeapon()
				-- WEAPON LEFT MUST BE SET TO NON DUAL WEAPON
				for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
					local isWeaponOneHanded <const> = IsWeaponOneHanded(joaat(weapon:getName())) == 1
					local isWeaponAGun <const> = Citizen.InvokeNative(0x705BE297EEBDB95D, joaat(weapon:getName()))
					if self.name ~= weapon:getName() and isWeaponOneHanded and isWeaponAGun and weapon:getUsed() then
						weapon:setUsed2(false) -- updates server because bellow wont update if true
						weapon:loadAmmo()
						SetCurrentPedWeapon(CACHE.Ped, joaat(weapon:getName()), true, 2, false, false)
						return true
					end
				end
			end

			if CONFIG.DUAL_WIELD then
				setLeftWeapon()
			end

			self:setUsed(false, true)
			self:setUsed2(false, true)
			-- pair broken? take the temp off-hand holster back off the ped
			local stillDual = false
			for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
				if weapon:getUsed2() then stillDual = true break end
			end
			if not stillDual then
				INVENTORY_SERVICE.REMOVE_OFF_HAND_HOLSTER()
			end


			if not skipTrigger then
				TriggerServerEvent("vorpinventory:setUsedWeapon", self.id, self:getUsed(), self:getUsed2())
			end

			local isLantern = IsWeaponLantern(joaat(self.name)) == 1
			local isFishingRod = joaat(self.name) == `WEAPON_FISHINGROD`
			local iskItWeapon = IsWeaponKit(joaat(self.name)) == 1

			if not isLantern and not isFishingRod and not iskItWeapon then
				if not self.used2 then
					HolsterPedWeapons(CACHE.Ped, true, false, true, false)
					Wait(1000)
				end
			end

			self:RemoveWeaponFromPed()

			SetPedAmmo(CACHE.Ped, joaat(self.name), 0)
			for k, _ in pairs(self:getAllAmmo()) do
				SetPedAmmoByType(CACHE.Ped, joaat(k), 0)
			end
			-- forget the apply state
			
self.compsLastSig = nil
			
self.compsLastApply = 0
			
self.compsApplied = {}
		end,

		RemoveWeaponFromPed   = function(self)
			if joaat(self.name) == `WEAPON_FISHINGROD` then
				TriggerEvent("vorp_fishing:resetFishing")
			end

			local isWeaponAGun <const>      = Citizen.InvokeNative(0x705BE297EEBDB95D, joaat(self.name))
			local isWeaponOneHanded <const> = Citizen.InvokeNative(0xD955FEE4B87AFA07, joaat(self.name))
			local move                      = false
			local inventoryId               = 1

			if isWeaponAGun and isWeaponOneHanded then
				for k, v in pairs(_EQUIPPED) do
					if v.id == self.id then
						if #_EQUIPPED > 1 then
							Citizen.InvokeNative(0x3E4E811480B3AE79, 1, v.guid, 1, joaat("ADD_REASON_DEFAULT"))
							move = true
						end
						table.remove(_EQUIPPED, k)
					end
				end
			end
			if move then
				local characterItem <const> = self:_getGuidFromItemId(1, nil, joaat("CHARACTER"), 0xA1212100)
				if not characterItem then return false end

				local weaponItem <const> = self:_getGuidFromItemId(1, characterItem:Buffer(), 923904168, -740156546)
				if not weaponItem then return false end

				self:_moveInventoryItem(inventoryId, _EQUIPPED[1].guid, weaponItem:Buffer(), 0)
				Citizen.InvokeNative(0x12FB95FE3D579238, CACHE.Ped, _EQUIPPED[1].guid, true, 0, false, false)
			else
				RemoveWeaponFromPed(CACHE.Ped, joaat(self.name), true, 0)
			end

			if not self.used2 then
				SetCurrentPedWeapon(CACHE.Ped, joaat("WEAPON_UNARMED"), false, 0, false, false);
			else
				SetCurrentPedWeapon(CACHE.Ped, joaat("WEAPON_UNARMED"), false, 1, false, false)
			end
		end,

		equipwep              = function(self)
			-- this equip is about to create a FRESH weapon object with zero wear
			-- until setStatus re-applies it; the window self-expires for weapons
			-- that never get a setStatus (melee/throwables).
			self.statusFreshUntil = GetGameTimer() + 12000
			local weaponHash_0 <const>      = joaat(self.name)
			local isWeaponMelee <const>     = Citizen.InvokeNative(0x959383DCD42040DA, weaponHash_0)
			local isWeaponThrowable <const> = Citizen.InvokeNative(0x30E7C16B12DA8211, weaponHash_0)
			local isWeaponAGun <const>      = Citizen.InvokeNative(0x705BE297EEBDB95D, weaponHash_0)
			local isWeaponOneHanded <const> = Citizen.InvokeNative(0xD955FEE4B87AFA07, weaponHash_0)
			local isWeaponPetrolCan         = weaponHash_0 == `WEAPON_MOONSHINEJUG_MP`
			local isLantern                 = IsWeaponLantern(weaponHash_0) == 1
			local isFishingRod              = weaponHash_0 == `WEAPON_FISHINGROD`
			local iskItWeapon               = IsWeaponKit(weaponHash_0) == 1
			local ammoCount                 = 0

			if SHARED_DATA.WEAPONS[self.name] and SHARED_DATA.WEAPONS[self.name].NoAmmo then
				ammoCount = 1
			end
			-- NoAmmo means "not ammo-backed" - right for lanterns and melee, wrong for a throwable
			local THROWABLE_AMMO <const> = {
				[`WEAPON_THROWN_BOLAS`] = "AMMO_BOLAS",
				[`WEAPON_THROWN_BOLAS_HAWKMOTH`] = "AMMO_BOLAS_HAWKMOTH",
				[`WEAPON_THROWN_BOLAS_INTERTWINED`] = "AMMO_BOLAS_INTERTWINED",
				[`WEAPON_THROWN_BOLAS_IRONSPIKED`] = "AMMO_BOLAS_IRONSPIKED",
				[`WEAPON_THROWN_TOMAHAWK`] = "AMMO_TOMAHAWK",
				[`WEAPON_THROWN_TOMAHAWK_ANCIENT`] = "AMMO_TOMAHAWK",
				[`WEAPON_THROWN_MOLOTOV`] = "AMMO_MOLOTOV",
				[`WEAPON_THROWN_POISONBOTTLE`] = "AMMO_POISONBOTTLE",
				[`WEAPON_THROWN_DYNAMITE`] = "AMMO_DYNAMITE",
				[`WEAPON_THROWN_THROWING_KNIVES`] = "AMMO_THROWING_KNIVES",
			}

			if isWeaponThrowable then
				local ammoType <const> = THROWABLE_AMMO[weaponHash_0]
				if ammoType then
					ammoCount = math.max(0, tonumber(self:getAmmo(ammoType)) or 0)
				else
					-- a throwable not in the map: sum is the best guess, and the trim below cannot help without knowing its type
					ammoCount = 0
					for _, owned in pairs(self:getAllAmmo() or {}) do
						ammoCount = ammoCount + math.max(0, tonumber(owned) or 0)
					end
					-- THE CLEAVER AND THE HATCHETS. The engine calls them throwable, they
					-- are not in the map above, and they hold no ammo rows - so the sum is
					-- 0 and this flattens the ammoCount = 1 that NoAmmo set further up.
					-- With no ammo one can be equipped but never used. They are not
					-- ammo-backed: the weapon IS the ammo, so put the 1 back.
					if ammoCount == 0 and SHARED_DATA.WEAPONS[self.name]
						and SHARED_DATA.WEAPONS[self.name].NoAmmo then
						ammoCount = 1
					end
				end
			end


			if isWeaponMelee or isWeaponThrowable or isWeaponPetrolCan or isLantern or isFishingRod or iskItWeapon then
				if isWeaponPetrolCan then
					ammoCount = math.max(0, self:getAmmo("AMMO_MOONSHINEJUG_MP"))
				end

				local function addAmmoToKnives()
					-- must add a count or knives wont be added to inventory if 0
					local ammoType <const> = "AMMO_THROWING_KNIVES"
					local ammo <const> = self:getAmmo(ammoType)
					-- if ammo is 0 get it from gun belt so we dont have to reload?
					GiveDelayedWeaponToPed(CACHE.Ped, weaponHash_0, ammo, true, 0)
					local ammoInClip <const> = GetAmmoInPedWeapon(CACHE.Ped, weaponHash_0)
					if ammoInClip > self:getDefaultClipSize() then
						-- somehow it adds more than what we have so we remove it based on the default clip size
						local amountToRemove <const> = ammoInClip - self:getDefaultClipSize()
						RemoveAmmoFromPedByType(CACHE.Ped, joaat(ammoType), amountToRemove, `REMOVE_REASON_DROPPED`)
						self:subAmmo(ammoType, amountToRemove) -- update ammo
					end
				end

				if weaponHash_0 == `WEAPON_THROWN_THROWING_KNIVES` and CONFIG.MANUAL_WEAPON_RELOAD then
					return addAmmoToKnives()
				end

				GiveDelayedWeaponToPed(CACHE.Ped, weaponHash_0, ammoCount, true, 0)

				local weapons <const> = THROWABLE_AMMO

				-- RUNS UNCONDITIONALLY, and clamps to what is OWNED
				if weapons[weaponHash_0] then
					local ammoType <const> = weapons[weaponHash_0]
					local owned <const> = math.max(0, tonumber(self:getAmmo(ammoType)) or 0)
					local ammoInWeapon <const> = GetAmmoInPedWeapon(CACHE.Ped, weaponHash_0)
					if ammoInWeapon > owned then
						RemoveAmmoFromPedByType(CACHE.Ped, joaat(ammoType), ammoInWeapon - owned, `REMOVE_REASON_DROPPED`)
					end
				end

				if isLantern or isFishingRod or iskItWeapon then
					SetTimeout(500, function()
						SetCurrentPedWeapon(CACHE.Ped, weaponHash_0, false, 0, false, false)
					end)
				end

				if isWeaponPetrolCan and CONFIG.MANUAL_WEAPON_RELOAD then
					local ammoType <const> = "AMMO_MOONSHINEJUG_MP"
					local ammoInWeapon <const> = GetAmmoInPedWeapon(CACHE.Ped, weaponHash_0)
					local maxAllowed <const> = self:getAmmo(ammoType)
					if ammoInWeapon > maxAllowed then
						RemoveAmmoFromPedByType(CACHE.Ped, joaat(ammoType), ammoInWeapon - maxAllowed, `REMOVE_REASON_DROPPED`)
					end
				end
			else
				local function checkForDual()
					for id, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
						if id ~= self.id then
						for _, equipped in pairs(_EQUIPPED) do
							if equipped.id == id then
								return true, weapon
							end
						end
					end
				end

					return false, nil
				end
				if self.used2 and CONFIG.DUAL_WIELD then
					if isWeaponAGun and isWeaponOneHanded then
						INVENTORY_SERVICE.APPLY_OFF_HAND_HOLSTER()


						self:_addWeapon(self.name, 1, self.id)
						if not CONFIG.MANUAL_WEAPON_RELOAD then
							return
						end

						local ammo = {}
						local weaponUsed = nil
						ammo[#ammo + 1] = self:getAllAmmo()
						if self.used2 then
							local bool, weapon = checkForDual()
							if bool then
								ammo[#ammo + 1] = weapon:getAllAmmo()
								weaponUsed = weapon
							end
						end

						--self:holsterDualWieldSlots()
						-- NIL GUARD. weaponUsed stays nil whenever checkForDual finds no
						-- partner; indexing it throws "attempt to index a nil value", which
						-- kills the rest of equipwep: no ammo, no MakePedReload, and the
						-- dual wield left half applied.
						if not weaponUsed then
							self:loadAmmo()
						elseif self.name ~= weaponUsed.name then
							local ammoTotal = {} -- ONLY IF GUNS ARE DIFERENT
							for _, ammotable in pairs(ammo) do
								for ammoType, amount in pairs(ammotable) do
									if SHARED_DATA.AMMO_TYPE_HASH[joaat(ammoType)] then
										if not ammoTotal[ammoType] then
											ammoTotal[ammoType] = amount
										else
											ammoTotal[ammoType] = ammoTotal[ammoType] + amount
										end
									end
								end
							end

							for ammoType, amount in pairs(ammoTotal) do
								SetPedAmmoByType(CACHE.Ped, joaat(ammoType), amount)

								if weaponUsed:getUsed() and not weaponUsed:getUsed2() then
									SetPedAmmo(CACHE.Ped, joaat(weaponUsed.name), amount)
								end

								if self:getUsed2() then
									SetPedAmmo(CACHE.Ped, joaat(self.name), amount)
								end
							end
						else
							-- WEAPON IS THE SAME
							local ammoTotal = 0
							for _, ammotable in pairs(ammo) do
								for ammoType, amount in pairs(ammotable) do
									if SHARED_DATA.AMMO_TYPE_HASH[joaat(ammoType)] then
										SetPedAmmoByType(CACHE.Ped, joaat(ammoType), amount)
										ammoTotal = ammoTotal + amount
									end
								end
							end
							SetPedAmmo(CACHE.Ped, joaat(self.name), ammoTotal)
						end

						Wait(1000)
						MakePedReload(CACHE.Ped) -- adds the ammo to clip
					end
				else
					if isWeaponAGun and isWeaponOneHanded and CONFIG.DUAL_WIELD then
						self:_addWeapon(self.name, 0, self.id)
						self:loadAmmo()
					else
						-- the stock 13-arg GiveWeaponToPed (the same call the melee path in InventoryService.lua uses)
						GiveWeaponToPed(CACHE.Ped, joaat(self.name), ammoCount, false, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
						self:loadAmmo()
					end
				end
			end
		end,

		addWeaponDualWield    = function(self, name, slot, id)
			self:_addWeapon(name, slot, id)
		end,

		loadComponents        = function(self, force)
			if not CONFIG.USE_WEAPON_COMPONENTS then return end
			-- debounce identical re-applies only
			local nowMs <const> = GetGameTimer()
			local sig = {}
			for category, component in pairs(self.components or {}) do
				sig[#sig + 1] = tostring(category) .. '=' .. tostring(component)
			end
			table.sort(sig)
			sig = table.concat(sig, ';')
			self.compsLastApply = self.compsLastApply or 0
			if not force and sig == self.compsLastSig and nowMs - self.compsLastApply < 3000 then
				return
			end
			self.compsLastApply = nowMs
			self.compsLastSig = sig
			local value <const> = SHARED_DATA.WEAPONS[self.name]

			if not next(self.components) then
				-- this early-out is the ONLY trace-free path through here
				if PUP_TRACE_COMPONENTS then
					print(("^1[comps]^7 %s (id %s): client map EMPTY at equip - nothing to apply"):format(self.name, tostring(self.id)))
				end
				if not value then return end
				local scopes = value?.Components?.SCOPE or {}
				local stripped = false
				for component, _ in pairs(scopes) do
					local hasComponent <const> = HasPedGotWeaponComponent(CACHE.Ped, joaat(component), joaat(self.name)) == 1
					if hasComponent then
						RemoveWeaponComponentFromPed(CACHE.Ped, joaat(component), joaat(self.name))
						stripped = true
					end
				end
				-- a removal needs the same redraw an apply does, or the scope stays on screen after it is already gone from the ped's set
				if stripped then Citizen.InvokeNative(0x76A18844E743BF91, CACHE.Ped) end
				return
			end

			-- a thread straight away, not a SetTimeout(1000, ...)
		CreateThread(function()
				-- suppress the draw/holster watcher while we work (see top of file)
				compsApplyCooldown = GetGameTimer() + 5000

				-- WAIT FOR THE WEAPON TO ACTUALLY LAND ON THE PED FIRST
				local gateHash <const> = joaat(self.name)
				local waited = 0
				while HasPedGotWeapon(CACHE.Ped, gateHash, 0, false) ~= 1 and waited < 200 do
					waited = waited + 1
					Wait(10) -- ~2s ceiling
				end
				if PUP_TRACE_COMPONENTS then
					print(("^3[comps]^7 %s: ped has weapon after %dms%s"):format(
						self.name, waited * 10,
						(waited >= 200) and " ^1<- NEVER ARRIVED, applies will no-op^7" or ""))
				end

				-- apply EVERY saved component
				local base, finish, tint = {}, {}, {}
				for category, component in pairs(self.components) do
					-- non-string junk (legacy {nothing=0} rows) would make joaat throw and abort the whole loop
					if type(component) == 'string' and component ~= '' and component ~= 'nothing' then
						local cat <const> = tostring(category):upper()
						local bucket
						if cat:find('TINT', 1, true) then
							bucket = tint
						elseif cat:find('MATERIAL', 1, true) or cat:find('ENGRAVING', 1, true) then
							bucket = finish
						else
							bucket = base
						end
						bucket[#bucket + 1] = { cat = cat, component = component }
					end
				end
				local function byCategory(a, b) return a.cat < b.cat end
				table.sort(base, byCategory)
				table.sort(finish, byCategory)
				table.sort(tint, byCategory)

				local weaponHash <const> = joaat(self.name)

				-- drive the weapon OBJECT, not the ped - the same native against the ped only lands the last component. weaponHash is -1
				local weaponObject
				for _ = 1, 40 do -- ~2s ceiling
					weaponObject = getObjectIndexFromPed(weaponHash)
					if weaponObject and weaponObject ~= 0 then break end
					Wait(50)
				end
				-- IN HAND decides the apply STRATEGY (see apply() below): a ped-side Give with equipNow=true RE-SEATS the weapon
				local _, curW = GetCurrentPedWeapon(CACHE.Ped, true, 0, false)
				local inHand = (curW == weaponHash)
				if PUP_TRACE_COMPONENTS then
					print(("^3[comps]^7 %s: weapon object %s, IN HAND=%s"):format(
						self.name, (weaponObject and weaponObject ~= 0) and tostring(weaponObject) or "^1NOT FOUND^7",
						tostring(inHand)))
				end

				local appliedCount, modelFails = 0, {}
				local function apply(entry)
					local component <const> = entry.component
					local compHash <const> = joaat(component)
					-- NO MODEL REQUEST HERE - every model is streamed in the pre-pass above, because a RequestModel wait inside this
					-- function would yield BETWEEN the clear and the re-attach and let
					-- the game seat its defaults back into the freed slots.
					appliedCount = appliedCount + 1
					-- No HasPedGotWeaponComponent guard: MATERIAL/TINT/ENGRAVING always report "occupied" because the game seats a default
					GiveWeaponComponentToEntity(CACHE.Ped, compHash, weaponHash, true)
					-- shop item / ped-variation push (rsg-weaponcomp's inhands.lua does this after every ped give). 0xD3A7B003ED343FD9 =
					Citizen.InvokeNative(0xD3A7B003ED343FD9, CACHE.Ped, compHash, true, true, true)
					-- the object give happens in PASS 2 below, not here
					if PUP_TRACE_COMPONENTS and PUP_TRACE_COMPONENTS_VERBOSE then
						-- HasPedGotWeaponComponent reports the LOGICAL set, not what is rendered
						print(("^3[comps]^7 %s  %-34s %-38s ped:%s object:%s"):format(
							self.name, entry.cat, component,
							HasPedGotWeaponComponent(CACHE.Ped, compHash, weaponHash) == 1 and "^2y^7" or "^1n^7",
							(weaponObject and weaponObject ~= 0) and "^2y^7" or "^1NO OBJECT^7"))
					end
				end

				if PUP_TRACE_COMPONENTS then
					print(("^3[comps]^7 %s: applying %d base / %d finish / %d tint"):format(self.name, #base, #finish, #tint))
				end
				-- PRE-STREAM every model BEFORE the clear below
				for _, list in ipairs({ base, finish, tint }) do
					for _, entry in ipairs(list) do
						local model <const> = Citizen.InvokeNative(0x59DE03442B6C9598, joaat(entry.component))
						if model and model ~= 0 and model ~= false then
							RequestModel(model)
							local tries = 0
							while not HasModelLoaded(model) and tries < 100 do
								tries = tries + 1
								Wait(10)
							end
							if not HasModelLoaded(model) then
								modelFails[#modelFails + 1] = entry.component
							end
						end
					end
				end

				-- FULL CLEAR
				-- A slot can render empty while HasPedGotWeaponComponent still reports "present",
				-- so audits cannot be trusted. Wanted components are cleared too: the slot must be EMPTY for the give.
				do
					local seen, cleared = {}, 0
					local function drop(name)
						if type(name) ~= 'string' or name == '' or seen[name] then return end
						seen[name] = true
						local ch <const> = joaat(name)
						if HasPedGotWeaponComponent(CACHE.Ped, ch, gateHash) == 1 then
							RemoveWeaponComponentFromPed(CACHE.Ped, ch, gateHash)
							cleared = cleared + 1
						end
					end
					-- everything we are about to apply (free its slot first)...
					for _, list in ipairs({ base, finish, tint }) do
						for _, entry in ipairs(list) do drop(entry.component) end
					end
					-- ...everything this weapon's catalog knows about...
					local catalog = value and value.Components
					if type(catalog) == 'table' then
						for _, comps in pairs(catalog) do
							if type(comps) == 'table' then
								for component in pairs(comps) do drop(tostring(component)) end
							end
						end
					end
					-- ...and anything WE put on in an earlier run (the catalog only lists GRIP/SIGHT/WRAP/SCOPE)
					for component in pairs(self.compsApplied or {}) do drop(component) end
					if PUP_TRACE_COMPONENTS then
						print(("^3[comps]^7 %s: cleared %d component slot(s) on ped before re-attach"):format(self.name, cleared))
					end
				end

				-- SETTLE GAP
				Wait(500)

				-- PASS 1 - the ped (logical set + shop item), in tier order
				for _, entry in ipairs(base) do apply(entry) end
				for _, entry in ipairs(finish) do apply(entry) end
				for _, entry in ipairs(tint) do apply(entry) end

				-- PASS 2 - the weapon OBJECT, re-resolved AFTER the ped gives
				local liveObject = getObjectIndexFromPed(weaponHash)
				if PUP_TRACE_COMPONENTS and liveObject ~= weaponObject then
					print(("^3[comps]^7 %s: weapon object CHANGED during ped applies %s -> %s%s"):format(
						self.name, tostring(weaponObject), tostring(liveObject),
						" ^1(every object give in the old single-pass loop after this point was lost)^7"))
				end
				if liveObject and liveObject ~= 0 then
					for _, list in ipairs({ base, finish, tint }) do
						for _, entry in ipairs(list) do
							GiveWeaponComponentToEntity(liveObject, joaat(entry.component), -1, true)
						end
					end
					weaponObject = liveObject -- so the trace below reports what we decorated
				end

				-- ONE refresh after the whole set, never per component
				Citizen.InvokeNative(0x76A18844E743BF91, CACHE.Ped)

				-- force the drawn weapon to rebuild
				if inHand then
					SetCurrentPedWeapon(CACHE.Ped, weaponHash, true, 0, false, false)
				end

				-- remember exactly what we put on the ped, so the NEXT run can strip whatever the player has since removed at the station
				self.compsApplied = {}
				for _, list in ipairs({ base, finish, tint }) do
					for _, entry in ipairs(list) do
						self.compsApplied[entry.component] = true
					end
				end

				if PUP_TRACE_COMPONENTS then
					local catalog = value and value.Components
					local saved, extra, missing = {}, {}, {}
					for _, component in pairs(self.components) do
						if type(component) == 'string' and component ~= '' then
							saved[component:upper()] = component
						end
					end
					local seen = {}
					if type(catalog) == 'table' then
						for _, comps in pairs(catalog) do
							if type(comps) == 'table' then
								for component in pairs(comps) do
									local cname = tostring(component)
									seen[cname:upper()] = true
									if HasPedGotWeaponComponent(CACHE.Ped, joaat(cname), gateHash) == 1
										and not saved[cname:upper()] then
										extra[#extra + 1] = cname
									end
								end
							end
						end
					end
					for up, cname in pairs(saved) do
						if HasPedGotWeaponComponent(CACHE.Ped, joaat(cname), gateHash) ~= 1 then
							missing[#missing + 1] = cname
						end
					end
					print(("^3[comps-audit]^7 %s: ped EXTRA(not saved)=%s | ped MISSING(saved but absent)=%s"):format(
						self.name,
						(#extra > 0) and ("^1" .. table.concat(extra, ", ") .. "^7") or "none",
						(#missing > 0) and ("^1" .. table.concat(missing, ", ") .. "^7") or "none"))
				end

				if PUP_TRACE_COMPONENTS then
					print(("^3[comps]^7 %s: run done [shopitem+refresh] - %d comps -> %s (%s)%s"):format(
						self.name, appliedCount,
						(weaponObject and weaponObject ~= 0) and ("object " .. tostring(weaponObject)) or "^1NO OBJECT^7",
						inHand and "in hand: ped+entity" or "holstered: ped+entity",
						(#modelFails > 0) and (" ^1models never streamed: " .. table.concat(modelFails, ", ") .. "^7") or ""))
				end

				-- the game settles the equip-state flips our applies caused over the next few frames
				compsApplyCooldown = GetGameTimer() + 1500
			end)
		end,


		removeComponent      = function(self, component, category)
			self.components[category] = nil

			if not CONFIG.USE_WEAPON_COMPONENTS then return end
			local NON_REPLACEABLE_COMPONENTS <const> = {
				COMPONENT_RIFLE_SCOPE02 = true,
				COMPONENT_RIFLE_SCOPE03 = true,
				COMPONENT_RIFLE_SCOPE04 = true,
			}

			local NON_REPLACEABLE_CATEGORIES <const> = {
				WRAP = true,
				FRAME_VERTDATA = true,
			}

			local _component <const> = self.components[category]
			if _component and _component == component then
				self.components[category] = nil
				if NON_REPLACEABLE_COMPONENTS[component] or NON_REPLACEABLE_CATEGORIES[category] then
					RemoveWeaponComponentFromPed(CACHE.Ped, joaat(component), joaat(self.name))
					--? needs to be documented official vorp event
					TriggerEvent("vorp_inventory:componentRemoved", self.id, component, category)
				else
					-- add default component for this weapon because we cannot leave it without a component
					local defaultComponents <const> = self.defaultAttachments[category]
					if defaultComponents then
						GiveWeaponComponentToEntity(CACHE.Ped, joaat(defaultComponents), joaat(self.name), true)
						--? needs to be documented official vorp event
						TriggerEvent("vorp_inventory:componentAdded", self.id, defaultComponents, category)
					end
				end

				return true
			end
			return false
		end,

		addComponent         = function(self, component, category)
			self.components[category] = component
			if not CONFIG.USE_WEAPON_COMPONENTS then return end
			local weaponHash <const> = joaat(self.name)
			local compHash <const> = joaat(component)
			-- ped keeps the logical set; the object is what actually renders
			if HasPedGotWeaponComponent(CACHE.Ped, compHash, weaponHash) == 1 then
				RemoveWeaponComponentFromPed(CACHE.Ped, compHash, weaponHash)
			end
			GiveWeaponComponentToEntity(CACHE.Ped, compHash, weaponHash, true)
			Citizen.InvokeNative(0xD3A7B003ED343FD9, CACHE.Ped, compHash, true, true, true)
			local weaponObject <const> = getObjectIndexFromPed(weaponHash)
			if weaponObject and weaponObject ~= 0 then
				GiveWeaponComponentToEntity(weaponObject, compHash, -1, true)
			end
			Citizen.InvokeNative(0x76A18844E743BF91, CACHE.Ped)
			--? needs to be documented official vorp event
			TriggerEvent("vorp_inventory:componentAdded", self.id, component, category)
		end,

		setId                = function(self, id)
			self.id = id
		end,

		setName              = function(self, name)
			self.name = name
		end,

		setLabel             = function(self, label)
			self.label = label
		end,

		setDesc              = function(self, desc)
			self.desc = desc
		end,

		setPropietary        = function(self, propietary)
			self.propietary = propietary
		end,

		setCurrInv           = function(self, invId)
			self.currInv = invId
		end,

		setCustomLabel       = function(self, v)
			self.custom_label = v
		end,

		setCustomDesc        = function(self, v)
			self.custom_desc = v
		end,

		setSerialNumber      = function(self, v)
			self.serial_number = v
		end,
		setUsed              = function(self, used, skipTrigger)
			self.used = used
			if not skipTrigger then
				TriggerServerEvent("vorpinventory:setUsedWeapon", self.id, self.used, self.used2)
			end
		end,

		setUsed2             = function(self, used2, skipTrigger)
			self.used2 = used2
			if not skipTrigger then
				TriggerServerEvent("vorpinventory:setUsedWeapon", self.id, self.used, self.used2)
			end
		end,
		-- on aupdate check if we ned to add new ammo type and rounds
		addAmmo              = function(self, type, amount)
			if self.ammo[type] then
				self.ammo[type] = math.min(self.ammo[type] + tonumber(amount), self:getDefaultClipSize())
			else
				self.ammo[type] = math.min(tonumber(amount), self:getDefaultClipSize())
			end
		end,
		-- on update check if we need to remove ammo type and rounds
		subAmmo              = function(self, type, amount)
			if not self.ammo[type] then return end

			self.ammo[type] = math.max(0, self.ammo[type] - tonumber(amount))

			if self.ammo[type] <= 0 then
				self.ammo[type] = nil
			end
		end,
		-- FOR BULLETS ONLY
		-- can only be used if player has the weapon in hand
		addAmmoToClip        = function(self, type, amount, skipTrigger)
			if not self.ammo[type] then
				self.ammo[type] = amount
			end
			if self.defaultClipSize > 0 then
				self.ammo[type] = math.min(self.ammo[type] + amount, self.defaultClipSize)
			else
				self.ammo[type] = self.ammo[type] + amount
			end
			-- update server when we reload
			if not skipTrigger then
				-- if true we didnt reload we picked up something
				TriggerServerEvent("vorpinventory:weaponReloaded", { weaponId = self.id, ammoType = type, amount = amount })
			end
		end,

		subAmmoFromClip      = function(self, type, amount)
			if not self.ammo[type] then return end
			self.ammo[type] = math.max(0, self.ammo[type] - tonumber(amount))
		end,

		cleanAmmoFromClip    = function(self, type)
			if not self.ammo[type] then return end
			self.ammo[type] = nil
		end,

		cleanAllAmmoFromClip = function(self)
			for ammoType, _ in pairs(self.ammo) do
				self.ammo[ammoType] = nil
			end
		end,

		-- called once on player load
		loadAmmo             = function(self)
			-- need a config to disable certain ammo types from weapons like dynamite etc
			--	DisableAmmoTypeForPedWeapon(CACHE.Ped, joaat(self.name), joaat(type))
			if not CONFIG.MANUAL_WEAPON_RELOAD then
				return
			end

			for type, amount in pairs(self.ammo) do
				if SHARED_DATA.AMMO_TYPE_HASH[joaat(type)] then
					SetAmmoTypeForPedWeapon(CACHE.Ped, joaat(self.name), joaat(type))
					SetPedAmmoByType(CACHE.Ped, joaat(type), amount)
					local bows <const> = { [`WEAPON_BOW`] = true, [`WEAPON_BOW_IMPROVED`] = true }
					if bows[joaat(self.name)] then
						if amount > 0 then
							SetPedAmmoByType(CACHE.Ped, joaat(type), math.min(amount, self:getDefaultClipSize()))
						end
					else
						if amount > 0 then
							if amount >= GetMaxAmmoInClip(CACHE.Ped, joaat(self.name), true) then
								SetPedAmmoByType(CACHE.Ped, joaat(type), math.min(amount, GetMaxAmmoInClip(CACHE.Ped, joaat(self.name), true)))
							else
								SetPedAmmoByType(CACHE.Ped, joaat(type), amount)
							end
						else
							SetPedAmmo(CACHE.Ped, joaat(self.name), 0)
							SetPedAmmoByType(CACHE.Ped, joaat(type), 0)
						end

						local ammoInWeapon <const> = GetAmmoInPedWeapon(CACHE.Ped, joaat(self.name))
						local maxAllowed           = amount
						if self:getDefaultClipSize() > 0 then
							maxAllowed = self:getDefaultClipSize()
						end


						if ammoInWeapon > maxAllowed then
							RemoveAmmoFromPedByType(CACHE.Ped, joaat(type), ammoInWeapon - maxAllowed, `REMOVE_REASON_DROPPED`)
						elseif ammoInWeapon > amount then
							RemoveAmmoFromPedByType(CACHE.Ped, joaat(type), ammoInWeapon - amount, `REMOVE_REASON_DROPPED`)
						end
					end
				end
			end
		end,

		-- called once a startup to set the status of the weapon
		setStatus            = function(self)
			if not CONFIG.USE_WEAPON_DEGRADATION then return end
			if not self.used and not self.used2 then return print("weapon not used") end
			if not self.canDegrade then return end

			-- the ped's weapon object can lag behind the give - retry instead of giving up
			local weaponObject = getObjectIndexFromPed(joaat(self.name))
			local tries = 0
			while not weaponObject and tries < 12 do
				Wait(500)
				tries = tries + 1
				if not self.used and not self.used2 then return end -- unequipped meanwhile
				weaponObject = getObjectIndexFromPed(joaat(self.name))
			end
			if not weaponObject then return print("weapon object not found", self.name) end


			SetWeaponDegradation(weaponObject, self.degradation)
			SetWeaponDamage(weaponObject, self.damage, false)
			SetWeaponDirt(weaponObject, self.dirt, false)
			SetWeaponSoot(weaponObject, self.soot, false)
			self.statusFreshUntil = nil -- stored condition is ON the object
			self:getStatus()
		end,

		updateStatus         = function(self)
			if not CONFIG.USE_WEAPON_DEGRADATION then return end
			-- updates the status of each weapon attached to player or not, but only weapons that are marked as used or used2
			if not self.used and not self.used2 then return end
			if not self.canDegrade then return end

			local weaponObject <const> = getObjectIndexFromPed(joaat(self.name))
			if not weaponObject then return end
			self:getStatus()
		end,

		saveStatus           = function(self)
			if not self.used and not self.used2 then return end
			if not self.canDegrade then return end
			TriggerServerEvent("vorpinventory:saveWeaponStatus", { [self.id] = self:getStatus() })
		end,
	},
}, "CLIENT_WEAPON")

---@class WEAPON_CLIENT
---@field public New fun(self: WEAPON_CLIENT, data: table): WEAPON_CLIENT
---@field public Register fun(self: WEAPON_CLIENT, data: table): WEAPON_CLIENT
WEAPON = Weapon


function WEAPON:Register(data)
	local weaponClass <const> = WEAPON:New(data)
	PLAYER_INVENTORY.WEAPONS[data.id] = weaponClass
	return weaponClass
end

-- WHEN LOADING IN IF DUAL WIELDING IS ACTIVE DO THIS HACKY WAY TO ADD THE AMMO
function AddOffhandHolster()
	if not CONFIG.DUAL_WIELD_ADD_HOLSTER then return end
	AddWardrobeInventoryItem("CLOTHING_ITEM_M_OFFHAND_000_TINT_004", 0xF20B6B4A)
	AddWardrobeInventoryItem("UPGRADE_OFFHAND_HOLSTER", 0x39E57B01)
end
function WEAPON:AddDualWield(weapons)
	if not CONFIG.DUAL_WIELD then return end

	if CONFIG.DUAL_WIELD_HOLSTER_NEEDED then
		local hasLeftHolster = INVENTORY_SERVICE.HAS_LEFT_HOLSTER()
		if not hasLeftHolster then
			-- dont let it equipp if they dont have a left holster
			for k, weaponId in pairs(weapons) do
				local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
				if weapon and weapon:getUsed2() then
					weapon:setUsed2(false)
					-- remove from weapons
					table.remove(weapons, k)
					break
				end
			end
		else
			INVENTORY_SERVICE.APPLY_OFF_HAND_HOLSTER()
		end
	else
		-- temp holster on the ped while the pair is equipped (see InventoryService)
		INVENTORY_SERVICE.APPLY_OFF_HAND_HOLSTER()
	end

	-- announce the equip so pup-weaponsV2 can apply saved components. vorp_inventory's own loadComponents is off here
	local function announceEquip(weapon)
		if not weapon then return end
		TriggerServerEvent("pup_gunsmith:weaponused", {
			id = weapon:getId(),
			name = weapon:getName(),
			type = "item_weapon",
			hash = joaat(weapon:getName()),
		})
	end

	if #weapons == 1 then
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[weapons[1]]
		if weapon then
			weapon:addWeaponDualWield(weapon:getName(), 0, weapon:getId())
			-- dual wielding ONE weapon type sets used AND used2 on the same row (NUIService.lua:71-72)
			if weapon:getUsed() and weapon:getUsed2() then
				weapon:addWeaponDualWield(weapon:getName(), 1, weapon:getId())
			end
			weapon:loadComponents() -- single-gun early return skips the loop below
			announceEquip(weapon)
		end
		return
	end

	local getUsed = {}
	local getUsed2 = {}
	local ammo = {}
	for _, weapon in pairs(weapons) do
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[weapon]
		if weapon then
			if not weapon:getUsed2() then
				table.insert(getUsed, weapon:getId())
				ammo[#ammo + 1] = weapon:getAllAmmo()
			else
				table.insert(getUsed2, weapon:getId())
				ammo[#ammo + 1] = weapon:getAllAmmo()
			end
		end
	end

	for _, weapon in pairs(getUsed) do
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[weapon]
		if weapon then
			weapon:addWeaponDualWield(weapon:getName(), 0, weapon:getId())
			break
		end
	end

	for _, weapon in pairs(getUsed2) do
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[weapon]
		if weapon then
			weapon:addWeaponDualWield(weapon:getName(), 1, weapon:getId())
			break
		end
	end
	-- every equipped weapon re-applies its own components, so a dual-wield pair does not share one set
	for _, weaponId in pairs(weapons) do
		local weapon <const> = PLAYER_INVENTORY.WEAPONS[weaponId]
		if weapon then
			weapon:loadComponents()
			-- ...and the handshake pup-weaponsV2 actually listens to
			announceEquip(weapon)
		end
	end

	if not CONFIG.MANUAL_WEAPON_RELOAD then
		return
	end

	Wait(1000)

	local DUAL_AMMO = {}
	for _, ammotable in pairs(ammo) do
		for ammoType, amount in pairs(ammotable) do
			if SHARED_DATA.AMMO_TYPE_HASH[joaat(ammoType)] then
				if not DUAL_AMMO[ammoType] then
					DUAL_AMMO[ammoType] = amount
				else
					DUAL_AMMO[ammoType] = DUAL_AMMO[ammoType] + amount
				end
			end
		end
	end

	for ammoType, amount in pairs(DUAL_AMMO) do
		SetPedAmmoByType(CACHE.Ped, joaat(ammoType), amount)

		for _, weapon in pairs(getUsed2) do
			local weapon <const> = PLAYER_INVENTORY.WEAPONS[weapon]
			if weapon then
				SetPedAmmo(CACHE.Ped, joaat(weapon:getName()), amount)
			end
		end

		for _, weapon in pairs(getUsed) do
			local weapon <const> = PLAYER_INVENTORY.WEAPONS[weapon]
			if weapon then
				SetPedAmmo(CACHE.Ped, joaat(weapon:getName()), amount)
			end
		end
	end
	Wait(1000)
	MakePedReload(CACHE.Ped)
end
-- DRAW/HOLSTER WATCHER
local function InHandSet(ped)
	local seen, list = {}, {}
	for attachPoint = 0, 29 do
		local _, w = GetCurrentPedWeapon(ped, true, attachPoint, false)
		if w and w ~= 0 and w ~= `WEAPON_UNARMED` and not seen[w] then
			seen[w] = true
			list[#list + 1] = w
		end
	end
	table.sort(list)
	return table.concat(list, ","), seen
end

CreateThread(function()
	local lastSig, lastSet = nil, {}
	local holsterTick = 0
	while true do
		Wait(250)
		local sig, heldSet = InHandSet(CACHE.Ped)

		-- keep the off-hand holster alive while a pair is equipped
		holsterTick = holsterTick + 1
		if holsterTick >= 4 then
			holsterTick = 0
			local dualActive = false
			for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
				if weapon:getUsed2() then dualActive = true break end
			end
			if dualActive and not INVENTORY_SERVICE.HAS_LEFT_HOLSTER() then
				-- a missing visual means the engine inventory was wiped, so the tracked guids are stale too - refresh, don't top up
				INVENTORY_SERVICE.REFRESH_OFF_HAND_HOLSTER()
			end
		end

		if sig ~= lastSig then
			local prevSet <const> = lastSet
			local firstPass <const> = (lastSig == nil)
			lastSig, lastSet = sig, heldSet -- ALWAYS record, even during cooldown, so apply-
			-- caused flips are absorbed silently; the very first pass (login) only records
			if not firstPass and GetGameTimer() > compsApplyCooldown then
				for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
					if (weapon:getUsed() or weapon:getUsed2()) and next(weapon.components or {}) then
						-- only the weapon involved in this transition: the one just drawn, or the one just holstered (its back prop rebuilt)
						local h <const> = joaat(weapon.name)
						if heldSet[h] or prevSet[h] then
							if PUP_TRACE_COMPONENTS then
								print(("^3[comps]^7 draw/holster change -> re-applying %s"):format(weapon.name))
							end
							-- force past the identical-set debounce: a real draw builds a NEW weapon entity that needs the same set applied to it
							weapon:loadComponents(true)
						end
					end
				end
			end
		end
	end
end)
