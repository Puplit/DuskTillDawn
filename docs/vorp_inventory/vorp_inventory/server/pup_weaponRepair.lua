-- Weapon full repair (restore to like-new), shared by the `repair_kit` item and the gunsmith
--   exports.vorp_inventory:RepairWeaponById(source, weaponId)  -> bool  (gunsmith: selected weapon)
--   exports.vorp_inventory:RepairEquippedWeapon(source)        -> bool  (repair_kit: equipped weapon)
--   exports.vorp_inventory:GetWeaponStatusById(source, weaponId) -> table|nil (stats panel)
-----------------------------------------------------------------------------------------

local PRISTINE <const> = { degradation = 0.0, damage = 0.0, dirt = 0.0, soot = 0.0 }

local function charOf(source)
	local user <const> = CORE.getUser(source)
	return user and user.getUsedCharacter or nil
end

local function repairWeaponObject(source, weapon)
	-- nothing wears out while the system is off, so a repair must not "succeed"
	-- and let the gunsmith take the fee for it
	if not CONFIG.USE_WEAPON_DEGRADATION then return false end
	if not weapon or not weapon.canDegrade then return false end
	weapon:updateStatus(PRISTINE)
	-- send the weapon id so the client can sync ITS copy of the condition too
	TriggerClientEvent('vorp_inventory:client:repairVisual', source, weapon:getId())
	return true
end

-- find an owned weapon by loadout id ACROSS every inventory bucket
local function findOwnedWeapon(character, weaponId)
	local direct = USERS_WEAPONS.default[tonumber(weaponId) or weaponId]
		or USERS_WEAPONS.default[tostring(weaponId)]
	if direct and direct:getPropietary() == character.identifier then return direct end
	local wid <const> = tostring(weaponId)
	for _, inv in pairs(USERS_WEAPONS) do
		if type(inv) == "table" then
			for id, weapon in pairs(inv) do
				if tostring(id) == wid then
					if weapon.getPropietary and weapon:getPropietary() == character.identifier then
						return weapon
					end
					return nil -- found, but someone else's - stop here
				end
			end
		end
	end
	return nil
end

--- Repair one owned weapon by its loadout id (ownership-checked). Used by the gunsmith.
local function repairById(source, weaponId)
	local character <const> = charOf(source)
	if not character then return false end
	local weapon <const> = findOwnedWeapon(character, weaponId)
	if not weapon then return false end
	return repairWeaponObject(source, weapon)
end

--- Repair the player's currently-equipped weapon(s). Used by the repair_kit item.
local function repairEquipped(source)
	local character <const> = charOf(source)
	if not character then return false end
	local ok = false
	for _, weapon in pairs(USERS_WEAPONS.default) do
		if weapon:getPropietary() == character.identifier and (weapon:getUsed() or weapon:getUsed2()) then
			if repairWeaponObject(source, weapon) then ok = true end
		end
	end
	return ok
end

--- Stored condition + upgrade count of an owned weapon (for the stats panel). nil if not owned.
local function statusById(source, weaponId)
	local character <const> = charOf(source)
	if not character then return nil end
	weaponId = tonumber(weaponId) or weaponId
	local weapon <const> = findOwnedWeapon(character, weaponId)
	if not weapon then return nil end
	local s <const> = weapon:getStatus()
	local comps <const> = weapon:getAllComponents() or {}
	local upgrades = 0
	for _ in pairs(comps) do upgrades = upgrades + 1 end
	local tier = 0
	pcall(function() tier = tonumber(MySQL.scalar.await('SELECT tier FROM loadout WHERE id = ?', { weaponId })) or 0 end)
	return {
		label       = weapon:getCustomLabel() or weapon:getLabel() or weapon:getName(),
		degradation = s.degradation or 0.0,
		damage      = s.damage or 0.0,
		dirt        = s.dirt or 0.0,
		soot        = s.soot or 0.0,
		upgrades    = upgrades,
		tier        = tier,
		-- the master switch counts too, or the gunsmith panel shows stale wear
		-- figures for a weapon that cannot degrade while wear is off
		canDegrade  = CONFIG.USE_WEAPON_DEGRADATION and weapon.canDegrade == true or false,
	}
end

exports('RepairWeaponById', repairById)
exports('RepairEquippedWeapon', repairEquipped)
exports('GetWeaponStatusById', statusById)

--- Is weapon wear switched on at all? Other resources read this to hide
--- condition readouts instead of showing figures that can never change.
exports('IsWeaponDegradationEnabled', function()
	return CONFIG.USE_WEAPON_DEGRADATION == true
end)

-- weapon UPGRADE TIERS (stored in loadout.tier, the customizations table)
--   exports.vorp_inventory:GetWeaponTier(source, weaponId)       -> number (0 if none/not owned)
-- exports.vorp_inventory:SetWeaponTier(source, weaponId, tier) -> bool
local function ownsWeaponCharId(source, weaponId)
	local character <const> = charOf(source)
	if not character then return nil end
	local owner = nil
	pcall(function() owner = MySQL.scalar.await('SELECT charidentifier FROM loadout WHERE id = ?', { weaponId }) end)
	if owner == nil or tostring(owner) ~= tostring(character.charIdentifier) then return nil end
	return character
end

local function getTier(source, weaponId)
	weaponId = tonumber(weaponId) or weaponId
	if not ownsWeaponCharId(source, weaponId) then return 0 end
	local t = 0
	pcall(function() t = tonumber(MySQL.scalar.await('SELECT tier FROM loadout WHERE id = ?', { weaponId })) or 0 end)
	return t
end

local function setTier(source, weaponId, tier)
	weaponId = tonumber(weaponId) or weaponId
	tier = math.max(0, math.floor(tonumber(tier) or 0))
	if not ownsWeaponCharId(source, weaponId) then return false end
	local ok = false
	pcall(function()
		MySQL.update.await('UPDATE loadout SET tier = ? WHERE id = ?', { tier, weaponId })
		ok = true
	end)
	if not ok then return false end
	local weapon <const> = USERS_WEAPONS.default[weaponId]
	if weapon then weapon.tier = tier end
	TriggerClientEvent('vorp_inventory:pup:setTierCache', source, weaponId, tier)
	return true
end

exports('GetWeaponTier', getTier)
exports('SetWeaponTier', setTier)

-- the client slow-degradation loop fetches a weapon's tier on first sight
CORE.Callback.Register('vorp_inventory:pup:getWeaponTier', function(source, cb, weaponId)
	cb(getTier(source, weaponId))
end)
