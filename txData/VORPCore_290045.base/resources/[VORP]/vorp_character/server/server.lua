-- Modified by Puppet (Dusk Till Dawn), 2026
local T = Translation.Langs[Config.General.language]
local random = math.random(1, #Config.SpawnPosition)
local Core = exports.vorp_core:GetCore()


local function ConvertTable(comps, compTints)
	local NewComps = {}

	for k, comp in pairs(comps) do
		-- dyed-outfit colours ride inside compPlayer as a `colors` table
		if k == "colors" then
			if type(comp) == "table" and next(comp) then NewComps.colors = comp end
			goto continue
		end
		NewComps[k] = { comp = comp, tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 }

		if compTints and compTints[k] and compTints[k][tostring(comp)] then
			local compTint = compTints[k][tostring(comp)]
			NewComps[k].tint0 = compTint.tint0 or 0
			NewComps[k].tint1 = compTint.tint1 or 0
			NewComps[k].tint2 = compTint.tint2 or 0
			NewComps[k].palette = compTint.palette or 0
		end
		::continue::
	end

	return NewComps
end

local function Checkmissingkeys(data, key)
	local switch = false
	if key == "skin" then
		for k, v in pairs(PlayerSkin) do
			if data[k] == nil then
				switch = true
				data[k] = v
			end
			if data.Eyes == 0 then
				switch = true
				if data.sex == "mp_male" then
					data.Eyes = 612262189
				else
					data.Eyes = 928002221
				end
			end
		end
		return data, switch
	end
	if key == "comps" then
		for k, v in pairs(PlayerClothing) do
			if data[k] == nil then
				data[k] = v.comp
			end
		end
		return data, switch
	end
end

local function UpdateDatabase(character)
	local json_skin = json.decode(character.skin)
	local json_comps = json.decode(character.comps)
	local compTints = json.decode(character.compTints)
	local skin, updateSkin = Checkmissingkeys(json_skin, "skin")
	local comps, updateComp = Checkmissingkeys(json_comps, "comps")

	if updateSkin then
		character.updateSkin((json.encode(skin)))
	end

	if updateComp then
		character.updateComps(json.encode(comps))
	end

	local NewComps = ConvertTable(comps, compTints)

	return skin, NewComps
end

local function GetPlayerData(source)
	local User = Core.getUser(source)

	if not User then
		return false
	end
	local Characters = User.getUserCharacters

	-- saved body adjustments (pup-misc column), so the selection preview shows them
	local expressionsById = {}
	local rows = MySQL.query.await("SELECT charidentifier, expressions FROM characters WHERE identifier = ?", { User.getIdentifier() })
	for _, r in ipairs(rows or {}) do expressionsById[r.charidentifier] = r.expressions end

	-- card extras (last played, jail) in one query rather than two per character
	local charIds, jobKeys = {}, {}
	for _, characters in pairs(Characters) do
		charIds[#charIds + 1] = tonumber(characters.charIdentifier)
		jobKeys[#jobKeys + 1] = characters.job
	end
	local extras = PupCardData and PupCardData(charIds) or {}
	local jobNames = PupCardJobNames and PupCardJobNames(jobKeys) or {}

	local userCharacters = {}
	for _, characters in pairs(Characters) do
		local skin, comps = UpdateDatabase(characters)
		local coords = json.decode(characters.coords)
		local extra = extras[tonumber(characters.charIdentifier)] or {}
		local userChars = {
			expressions = expressionsById[characters.charIdentifier],
			charIdentifier = characters.charIdentifier,
			money = characters.money,
			gold = characters.gold,
			firstname = characters.firstname,
			lastname = characters.lastname,
			skin = skin,
			components = comps,
			coords = coords,
			isDead = characters.isdead,
			-- the shop name behind the job key, not the joblabel column
			job = jobNames[tostring(characters.job or "")] or characters.job or "Unemployed",
			grade = characters.jobGrade or "",
			group = characters.group or "",
			age = characters.age or "",
			nickname = characters.nickname or "",
			gender = characters.gender or "",
			charDesc = characters.charDescription or "",
			-- select-card fields
			where = PupCardWhere and PupCardWhere(coords) or nil,
			lastPlayed = extra.lastPlayed,
			jailMinutes = extra.jailMinutes,
		}
		userCharacters[#userCharacters + 1] = userChars
	end
	return userCharacters
end

AddEventHandler("vorp_CreateNewCharacter", function(source)
	TriggerClientEvent("vorpcharacter:startCharacterCreator", source)
end)

-- `chosen` is the index the player picked at the end of creation
local function iniSpawn(chosen)
	local numSpawns = #Config.SpawnCoords
	if numSpawns == 0 then return print("update config file") end

	local index = tonumber(chosen)
	if not (Config.SpawnPicker.enabled and index and index >= 1 and index <= numSpawns and index % 1 == 0) then
		index = math.random(1, numSpawns)
	end
	local selectedSpawn = Config.SpawnCoords[index]

	return selectedSpawn.position, selectedSpawn.heading
end

RegisterServerEvent("vorpcharacter:saveCharacter", function(data, chosenSpawn)
	local _source = source
	Core.getUser(_source).addCharacter(data)
	Wait(600)
	local iniPos, iniHead = iniSpawn(chosenSpawn)
	TriggerClientEvent("vorp:initCharacter", _source, iniPos, iniHead, false)
	SetTimeout(3000, function()
		TriggerEvent("vorp_NewCharacter", _source)
	end)
end)

RegisterServerEvent("vorpcharacter:deleteCharacter", function(selectedChar)
	local _source = source
	local user = Core.getUser(_source)
	if user then
		local charid = selectedChar.charIdentifier
		local SteamName = GetPlayerName(_source)
		local SteamId = GetPlayerIdentifiers(_source)[1]
		local description = "SteamID : " .. SteamId .. "\n" .. "Steam Name : " .. SteamName .. "\n" ..
			"Playername : " .. selectedChar.firstname .. " " .. selectedChar.lastname .. "\n" .. "Character Description : " ..
			selectedChar.charDesc
		Core.AddWebhook(Config.Logs.deleteCharacter.title, Secrets.Webhooks.deleteCharacter, description, Config.Logs.color, Config.Logs.deleteCharacter.webhookName, Config.Logs.logo, Config.Logs.footerLogo, Config.Logs.avatar)
		user.removeCharacter(charid)
	end
end)

-- only allow the player to use this once since they have to leave to change characters, can be removed once theres a way to allow changing characters in run time
local charSelected <const> = {}
RegisterServerEvent("vorp_CharSelectedCharacter", function(charid)
	local _source = source
	if charSelected[_source] then return print("player has already selected a character") end

	-- player exists
	local user <const> = Core.getUser(_source)
	if user then
		charSelected[_source] = true
		user.setUsedCharacter(charid)
	end
end)



RegisterNetEvent("vorpcharacter:setPlayerCompChange", function(skinValues, compsValues)
	local _source = source
	local user = Core.getUser(_source)
	if user then
		local character = user.getUsedCharacter
		if compsValues then
			character.updateComps(json.encode(compsValues))
		end

		if skinValues then
			character.updateSkin(json.encode(skinValues))
		end
	end
end)


AddEventHandler("vorp_character:server:SpawnUniqueCharacter", function(source)
	local userCharacters = GetPlayerData(source)
	if not userCharacters then
		return
	end
	TriggerClientEvent("vorpcharacter:spawnUniqueCharacter", source, userCharacters)
end)

if Config.General.devMode then
	RegisterServerEvent("vorp_character:server:GoToSelectionMenu")
end

AddEventHandler("vorp_character:server:GoToSelectionMenu", function(src)
	local _source = Config.General.devMode and source or src

	if not Config.General.devMode then
		if Player(_source).state.IsInSession then
			return print("player is past selection")
		end
	end

	local UserCharacters = GetPlayerData(_source)

	if not UserCharacters then
		return
	end

	local MaxCharacters = Core.maxCharacters(_source)
	if not MaxCharacters then
		return
	end

	TriggerClientEvent("vorpcharacter:selectCharacter", _source, UserCharacters, MaxCharacters, random)
end)


Core.Callback.Register("vorp_characters:getMaxCharacters", function(source, cb)
	local MaxCharacters = Core.maxCharacters(source)

	if not MaxCharacters then
		return
	end

	cb(#MaxCharacters)
end)

Core.Callback.Register("vorp_character:callback:PayToShop", function(source, callback, arguments)
	local user = Core.getUser(source)
	if not user then
		return callback(false)
	end
	local character = user.getUsedCharacter
	local money = character.money
	local amountToPay = tonumber(arguments.amount)

	if money < amountToPay then
		SetTimeout(5000, function()
			Core.NotifyRightTip(source, string.format(T.PayToShop.DontMoney, amountToPay), 6000)
		end)
		return callback(false)
	end

	SetTimeout(5000, function()
		Core.NotifyRightTip(source, string.format(T.PayToShop.Youpaid, amountToPay), 6000)
	end)

	character.removeCurrency(0, amountToPay)

	if arguments.skin then
		character.updateSkin((json.encode(arguments.skin)))
	end

	if arguments.comps then
		character.updateComps(json.encode(arguments.comps))
	end

	if arguments.compTints then
		character.updateCompTints(json.encode(arguments.compTints))
	end

	if arguments.Result and arguments.Result ~= '' then
		local Parameters = { character.identifier, character.charIdentifier, arguments.Result, json.encode(arguments.comps), json.encode(arguments.compTints) }

		---@diagnostic disable-next-line: undefined-global
		MySQL.insert("INSERT INTO outfits (identifier, charidentifier, title, comps, compTints) VALUES (?, ?, ? ,?, ?)", Parameters)
	end

	return callback(true)
end)

-- true when this character's looks cannot be written right now; `where` only
-- shapes the console line. Checked at every entry point.
function SecondChanceBlocked(source, character, where)
	if not character then return true end
	local locked = false
	if character.appearanceLocked then
		local ok, res = pcall(character.appearanceLocked)
		locked = ok and res == true
	else
		-- older vorp_core without the helper: read the flag directly
		locked = GlobalState[("pup_disguise_%s"):format(tostring(character.charIdentifier))] == true
	end
	if not locked then return false end

	print(("^3[vorp_character]^7 second chance BLOCKED at %s for char %s (%s) - wearing a borrowed face")
		:format(tostring(where), tostring(character.charIdentifier), GetPlayerName(source) or "?"))
	Core.NotifyRightTip(source,
		"You cannot change your appearance while wearing another face. Wait for it to wear off.", 8000)
	return true
end

local function CanProcceed(user, source)
	-- an item-funded second chance has already been paid for - by the item
	if SECOND_CHANCE_BY_ITEM and SECOND_CHANCE_BY_ITEM[source] then
		return true
	end

	local character = user.getUsedCharacter
	local money = Config.Shops.secondChance.currency == 0 and character.money or Config.Shops.secondChance.currency == 1 and character.gold or Config.Shops.secondChance.currency == 2 and character.rol
	local amountToPay = Config.Shops.secondChance.price
	local moneyType = Config.Shops.secondChance.currency == 0 and "money" or Config.Shops.secondChance.currency == 1 and "gold" or Config.Shops.secondChance.currency == 2 and "rol"

	if money < amountToPay then
		Core.NotifyRightTip(source, string.format(T.PayToShop.notenoughtMoney, moneyType, Config.Shops.secondChance.price), 6000)
		return false
	end

	return true
end

Core.Callback.Register("vorp_character:callback:CanPayForSecondChance", function(source, callback)
	local user = Core.getUser(source)

	if not user then
		return callback(false)
	end

	if SecondChanceBlocked(source, user.getUsedCharacter, "shop prompt") then
		return callback(false)
	end

	if not CanProcceed(user, source) then
		return callback(false)
	end

	return callback(true)
end)

Core.Callback.Register("vorp_character:callback:PayForSecondChance", function(source, callback, data)
	local user = Core.getUser(source)

	if not user then
		return callback(false)
	end
	local character = user.getUsedCharacter

	if not CanProcceed(user, source) then
		return callback(false)
	end

	-- refuse before anything is taken: vorp_core discards appearance writes
	-- while a borrowed face is worn, so charging first loses the item
	if SecondChanceBlocked(source, character, "confirm") then
		return callback(false)
	end

	-- WRITE FIRST, AND CHECK IT LANDED.
	local failed = {}
	if data.comps and not character.updateComps(json.encode(data.comps)) then
		failed[#failed + 1] = "comps"
	end
	local wantSkin = nil
	if data.skin then
		wantSkin = json.encode(data.skin)
		if not character.updateSkin(wantSkin) then
			failed[#failed + 1] = "skin"
		end
	end
	if data.compTints and not character.updateCompTints(json.encode(data.compTints)) then
		failed[#failed + 1] = "compTints"
	end

	-- read the column back in a thread of its own: this handler is a function
	-- reference held by vorp_core and must never yield
	if wantSkin and #failed == 0 then
		local charid <const> = character.charIdentifier
		local who <const> = GetPlayerName(source) or "?"
		CreateThread(function()
			local stored
			for _ = 1, 3 do
				Wait(400)
				stored = MySQL.scalar.await("SELECT skinPlayer FROM characters WHERE charidentifier = ?",
					{ charid })
				if stored == wantSkin then return end
			end
			print(("^1[vorp_character]^7 second chance READ-BACK MISMATCH for char %s (%s) - wrote %d chars, column has %d. THEY WERE CHARGED.")
				:format(tostring(charid), who, #wantSkin, stored and #stored or 0))
		end)
	end

	if #failed > 0 then
		-- something refused the write between the check above and now. Charge
		-- nothing: a free retry is far cheaper than a lost item.
		print(("^1[vorp_character]^7 SECOND CHANCE NOT SAVED for char %s (%s) - failed: %s. Nothing was taken.")
			:format(tostring(character.charIdentifier), GetPlayerName(source) or "?", table.concat(failed, ", ")))
		Core.NotifyRightTip(source, "Your appearance could not be saved. Nothing was taken - try again.", 8000)
		return callback(false)
	end

	-- ONLY NOW take the payment
	local byItem <const> = SECOND_CHANCE_BY_ITEM and SECOND_CHANCE_BY_ITEM[source]
	if byItem then
		if not (SecondChanceTakeItem and SecondChanceTakeItem(source)) then
			-- saved but the item had gone: they keep the change, we say so out loud
			print(("^3[vorp_character]^7 second chance saved for char %s but the item could not be taken")
				:format(tostring(character.charIdentifier)))
		end
	else
		character.removeCurrency(Config.Shops.secondChance.currency, Config.Shops.secondChance.price)
	end

	print(("^2[vorp_character]^7 second chance saved for char %s (%s)")
		:format(tostring(character.charIdentifier), GetPlayerName(source) or "?"))
	return callback(true)
end)

Core.Callback.Register("vorp_character:callback:GetOutfits", function(source, callback)
	local character = Core.getUser(source).getUsedCharacter

	MySQL.query("SELECT * FROM outfits WHERE `charidentifier` = ?", { character.charIdentifier }, function(Outfits)
		return callback(Outfits)
	end)
end)

Core.Callback.Register("vorp_character:callback:SetOutfit", function(source, callback, arguments)
	local user = Core.getUser(source)
	if not user then return callback(false) end

	local character = user.getUsedCharacter
	local unpacked = msgpack.unpack(arguments.Outfit)
	arguments.Outfit = unpacked

	if type(arguments.Outfit.comps) ~= "string" then
		arguments.Outfit.comps = json.encode(arguments.Outfit.comps)
	end

	if type(arguments.Outfit.compTints) ~= "string" then
		arguments.Outfit.compTints = json.encode(arguments.Outfit.compTints)
	end

	character.updateComps(arguments.Outfit.comps or '{}')
	character.updateCompTints(arguments.Outfit.compTints or '{}')

	return callback(true)
end)

Core.Callback.Register("vorp_character:callback:DeleteOutfit", function(source, callback, arguments)
	local user = Core.getUser(source)
	if not user then return callback(false) end

	local character = user.getUsedCharacter
	-- why is it using steam? each character should have its own set of outfits
	MySQL.query.await("DELETE FROM outfits WHERE charidentifier = ? AND id = ?", { character.charIdentifier, arguments.id })

	return callback(true)
end)

-- EXPORT TO OPEN MENU THROUGH OTHER SCRIPTS
exports("OpenOutfitsMenu", function(source)
	local user = Core.getUser(source)
	if not user then return end
	local character = user.getUsedCharacter

	local result = MySQL.query.await("SELECT id, title, comps, compTints FROM outfits WHERE `charidentifier` = ?", { character.charIdentifier })
	if not result then return end

	local packed = msgpack.pack(result)
	TriggerClientEvent("vorp_character:Client:OpenOutfitsMenu", source, packed)
	return true
end)
