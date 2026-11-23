-- refresh the live in-hand weapon after a repair

RegisterNetEvent('vorp_inventory:client:repairVisual', function(weaponId)
	-- sync the CLIENT-side WeaponClass condition too
	weaponId = tonumber(weaponId) or weaponId
	local weapon = weaponId and PLAYER_INVENTORY and PLAYER_INVENTORY.WEAPONS
		and PLAYER_INVENTORY.WEAPONS[weaponId] or nil
	if weapon then
		weapon.degradation, weapon.damage, weapon.dirt, weapon.soot = 0.0, 0.0, 0.0, 0.0
		weapon.statusFreshUntil = nil -- pristine IS the truth
	end

	-- wipe the in-hand object only when it is this weapon, not a stashed one being repaired
	local isThisInHand = true
	if weapon then
		isThisInHand = (weapon:getUsed() or weapon:getUsed2())
			and CACHE.Weapon == joaat(weapon:getName())
	end
	if isThisInHand then
		local ped <const> = PlayerPedId()
		local weaponObject <const> = GetPedWeaponObject(ped, true)
		if weaponObject and weaponObject ~= 0 then
			SetWeaponDirt(weaponObject, 0.0, false)
			SetWeaponSoot(weaponObject, 0.0, false)
			SetWeaponDamage(weaponObject, 0.0, false)
			SetWeaponDegradation(weaponObject, 0.0)
			-- the weapon wheel's Condition bar keeps a DARK segment for PERMANENT degradation
			pcall(function() SetWeaponPermanentDegradation(weaponObject, 0.0) end)
		end
	end
end)

-- weapon TIER slow-degradation
local SLOW_PER_TIER <const> = 0.10

PUP_WEAPON_TIERS = PUP_WEAPON_TIERS or {} -- [loadoutId] = tier (pushed from the server / fetched lazily)

RegisterNetEvent('vorp_inventory:pup:setTierCache', function(weaponId, tier)
	PUP_WEAPON_TIERS[tonumber(weaponId) or weaponId] = tonumber(tier) or 0
end)

if CONFIG.USE_WEAPON_DEGRADATION then
	CreateThread(function()
		repeat Wait(5000) until LocalPlayer.state.IsInSession
		local Core <const> = exports.vorp_core:GetCore()
		local prevSample = {} -- [loadoutId] = { degradation, damage, dirt, soot } after our last correction
		local pending = {}    -- [loadoutId] = true while a tier fetch is in flight

		local function equippedInHand()
			for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS or {}) do
				if weapon.canDegrade and weapon:getUsed() then return weapon end
			end
			return nil
		end

		local function slowed(prev, cur, factor)
			if cur > prev then return prev + (cur - prev) * factor end
			return cur -- a drop (cleaning / repair) applies in full
		end

		while true do
			Wait(2500)
			local weapon = (not CACHE.IsDead) and equippedInHand() or nil
			if weapon then
				local id <const> = weapon:getId()
				local tier = PUP_WEAPON_TIERS[id]
				if tier == nil then
					if not pending[id] then
						pending[id] = true
						CreateThread(function()
							PUP_WEAPON_TIERS[id] = tonumber(Core.Callback.TriggerAwait('vorp_inventory:pup:getWeaponTier', id)) or 0
							pending[id] = nil
						end)
					end
				elseif tier > 0 then
					local obj <const> = GetPedWeaponObject(PlayerPedId(), true)
					if obj and obj ~= 0 then
						local factor <const> = math.max(0.0, 1.0 - tier * SLOW_PER_TIER)
						local cur <const> = {
							degradation = GetWeaponDegradation(obj),
							damage      = GetWeaponDamage(obj),
							dirt        = GetWeaponDirt(obj),
							soot        = GetWeaponSoot(obj),
						}
						local prev = prevSample[id]
						if prev then
							local nd    <const> = slowed(prev.degradation, cur.degradation, factor)
							local ndmg  <const> = slowed(prev.damage, cur.damage, factor)
							local ndirt <const> = slowed(prev.dirt, cur.dirt, factor)
							local nsoot <const> = slowed(prev.soot, cur.soot, factor)
							if nd ~= cur.degradation then SetWeaponDegradation(obj, nd) end
							if ndmg ~= cur.damage then SetWeaponDamage(obj, ndmg, false) end
							if ndirt ~= cur.dirt then SetWeaponDirt(obj, ndirt, false) end
							if nsoot ~= cur.soot then SetWeaponSoot(obj, nsoot, false) end
							prevSample[id] = { degradation = nd, damage = ndmg, dirt = ndirt, soot = nsoot }
						else
							prevSample[id] = cur
						end
					end
				end
			end
		end
	end)
end
