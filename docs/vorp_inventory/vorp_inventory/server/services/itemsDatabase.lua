-- CONTAINS SERVER ITEMS DATA
SERVER_ITEMS  = {}
-- CONTAINS USERS WEAPONS DATA
USERS_WEAPONS = {
	default = {}
}

local function normalize(v)
	v = tonumber(v)
	if not v then return 0.0 end
	if v <= 0.0 then return 0.0 end
	if v >= 1.0 then return 1.0 end
	return v
end

-- PASSIVE comps DB tracing ([compsdb] in the SERVER console)
PUP_TRACE_COMPS_DB = (CONFIG and CONFIG.TRACE_COMPONENTS) or false

-- json.decode THROWS on nil and on malformed text - it does not return nil
local function decodeColumn(raw)
	if type(raw) ~= "string" or raw == "" then return {} end
	local ok, decoded = pcall(json.decode, raw)
	if ok and type(decoded) == "table" then return decoded end
	return {}
end

local function loadAllWeapons(db_weapon)
	local ammo <const> = decodeColumn(db_weapon.ammo)
	local comp         = decodeColumn(db_weapon.comps)
	local rawN = 0
	for _ in pairs(comp) do rawN = rawN + 1 end

	-- DIAGNOSTIC BLIND SPOT. decodeColumn swallows a malformed column and hands back {}, so trace it here
	if PUP_TRACE_COMPS_DB and rawN == 0 then
		local raw = db_weapon.comps
		if type(raw) == "string" and raw ~= "" and raw ~= "{}" and raw ~= "[]" then
			print(("^1[compsdb]^7 LOAD weapon %s (%s): comps column is NOT READABLE as a table - nothing applied. raw: %s")
				:format(tostring(db_weapon.id), tostring(db_weapon.name), raw))
		end
	end
	-- legacy rows carry junk - "nothing" as an array value AND ["nothing"]=0 as a map key; strip both
	local cleaned = {}
	for k, v in pairs(comp) do
		if type(v) == "string" and v ~= "" and v ~= "nothing" and k ~= "nothing" then
			cleaned[k] = v
		end
	end
	comp = cleaned

	if PUP_TRACE_COMPS_DB and rawN > 0 then
		local cleanN, cats = 0, {}
		for k in pairs(comp) do cleanN = cleanN + 1 cats[#cats + 1] = k end
		print(("^6[compsdb]^7 LOAD weapon %s (%s): DB had %d categories, %d after scrub [%s]%s")
			:format(tostring(db_weapon.id), tostring(db_weapon.name), rawN, cleanN,
				table.concat(cats, ","),
				(cleanN < rawN)
					and (" ^1<- SCRUB DROPPED ENTRIES! raw: " .. tostring(db_weapon.comps) .. "^7")
					or ""))
	end

	if db_weapon.dropped == 0 then
		local label = db_weapon.custom_label or db_weapon.label
		local weight = SV_UTILS.WEAPONS.GET_WEAPON_WEIGHT(db_weapon.name)

		local weapon <const> = WEAPON:Register({
			id = db_weapon.id,
			propietary = db_weapon.identifier,
			name = db_weapon.name,
			ammo = ammo,
			components = comp,
			used = CONFIG.AUTO_EQUIP_USED_WEAPONS and db_weapon.used == 1 or false,
			used2 = CONFIG.AUTO_EQUIP_USED_WEAPONS and db_weapon.used2 == 1 or false,
			charId = db_weapon.charidentifier,
			currInv = db_weapon.curr_inv,
			dropped = db_weapon.dropped,
			group = 5,
			label = label,
			serial_number = db_weapon.serial_number,
			custom_label = db_weapon.custom_label,
			custom_desc = db_weapon.custom_desc,
			weight = weight,
			degradation = normalize(db_weapon.degradation),
			damage = normalize(db_weapon.damage),
			dirt = normalize(db_weapon.dirt),
			soot = normalize(db_weapon.soot),

		})

		if not USERS_WEAPONS[db_weapon.curr_inv] then
			USERS_WEAPONS[db_weapon.curr_inv] = {}
		end

		USERS_WEAPONS[db_weapon.curr_inv][weapon:getId()] = weapon

		if weapon:getCurrInv() == "default" then
			LAST_SAVED_WEAPON_AMMO[weapon:getId()] = json.encode(weapon:getAllAmmo())
			if CONFIG.USE_WEAPON_DEGRADATION then
				local st <const> = weapon:getStatus()
				LAST_SAVED_WEAPON_DATA[weapon:getId()] = json.encode({
					degradation = st.degradation,
					damage = st.damage,
					dirt = st.dirt,
					soot = st.soot,
				})
			end
		end
	else
		DB_SERVICE.ASYNC.DELETE('DELETE FROM loadout WHERE id = @id', { id = db_weapon.id }, function() end)
	end
end
-- ONE BAD ROW MUST NOT EAT THE REST OF THE BELT
local function loadWeaponRow(db_weapon, where)
	local ok, err = pcall(loadAllWeapons, db_weapon)
	if not ok then
		print(("^1[vorp_inventory]^7 %s: FAILED to load loadout row id=%s name=%s charid=%s inv=%s\n" ..
			"  %s\n" ..
			"  This row was skipped. Every other weapon still loads."):format(
			where, tostring(db_weapon and db_weapon.id), tostring(db_weapon and db_weapon.name),
			tostring(db_weapon and db_weapon.charidentifier), tostring(db_weapon and db_weapon.curr_inv),
			tostring(err)))
	end
	return ok
end

local function loadPlayerWeapons(source, character)
	local _source = source

	DB_SERVICE.ASYNC.QUERY('SELECT * FROM loadout WHERE charidentifier = ? ', { character.charIdentifier },
		function(result)
			if next(result) then
				local loaded, failed = 0, 0
				for _, db_weapon in pairs(result) do
					if db_weapon.charidentifier and db_weapon.curr_inv == "default" then -- only load default inventory
						if loadWeaponRow(db_weapon, "loadPlayerWeapons") then
							loaded = loaded + 1
						else
							failed = failed + 1
					end
				end
			end
				if failed > 0 then
					print(("^1[vorp_inventory]^7 charid %s: %d weapon(s) loaded, %d SKIPPED (see above)."):format(
						tostring(character.charIdentifier), loaded, failed))
				end
			end
		end)
end

-- convert json string to pure lua table
local function luaTable(value)
	if type(value) == "table" then
		local t = {}
		for k, v in pairs(value) do
			t[k] = luaTable(v)
		end
		return t
	else
		return value
	end
end


MySQL.ready(function()
	-- load all items from database
	DB_SERVICE.ASYNC.QUERY("SELECT * FROM items", {}, function(result)
		for _, db_item in pairs(result) do
			if db_item.id then
				local meta = {}
				if db_item.metadata ~= "{}" then
					meta = luaTable(json.decode(db_item.metadata))
				end

				local item <const> = ITEM:Register({
					id = db_item.id,
					item = db_item.item,
					name = db_item.item,
					metadata = meta,
					label = db_item.label,
					limit = db_item.limit,
					type = db_item.type,
					canUse = db_item.usable,
					canRemove = db_item.can_remove,
					desc = db_item.desc,
					group = db_item.groupId,
					rarity = db_item.rarityId,
					durability = db_item.durability,
					instruction = db_item.instructions,
					weight = db_item.weight,
					maxDegradation = db_item.degradation,
					useExpired = db_item.useExpired == 1,
				})
				SERVER_ITEMS[item.item] = item
			end
		end
	end)

	--load all secondary inventory weapons from database
	DB_SERVICE.ASYNC.QUERY("SELECT * FROM loadout", {}, function(result)
		for _, db_weapon in pairs(result) do
			if db_weapon.curr_inv ~= "default" then
				-- same isolation as loadPlayerWeapons: a single bad row must not abort boot hydration for every secondary inventory
				loadWeaponRow(db_weapon, "boot secondary-inventory hydration")
			end
		end
	end)
end)

local function cacheImages()
	-- only items from the database because items folder can contain duplicates or unused images
	local newtable = {}
	for k, v in pairs(SERVER_ITEMS) do
		newtable[k] = v.item
	end
	-- all weapon images from config because items folder can contain duplicates or unused images
	for k, _ in pairs(SHARED_DATA.WEAPONS) do
		newtable[k] = k
	end
	local packed = msgpack.pack(newtable)

	return packed
end

-- on player select character event
AddEventHandler("vorp:SelectedCharacter", function(source, char)
	loadPlayerWeapons(source, char)

	local packed = cacheImages()
	TriggerClientEvent("vorp_inventory:server:CacheImages", source, packed)
end)

-- reload on script restart for testing
if CONFIG.DEV_MODE then
	RegisterNetEvent("DEV:loadweapons", function()
		local _source = source
		local character = CORE.getUser(_source).getUsedCharacter
		loadPlayerWeapons(_source, character)

		local packed = cacheImages()
		TriggerClientEvent("vorp_inventory:server:CacheImages", _source, packed)
	end)
end
