-- Modified by Puppet (Dusk Till Dawn), 2026
local PromptGroup <const> = GetRandomIntInRange(0, 0xffffff)
local DeletePrompt
local SelectPrompt
local GoBackPrompt
local selectedChar        = 1
local myChars             = {}
local textureId           = -1
local MaxCharacters
local mainCam
local LastCam
local random
local canContinue         = false
local MalePed
local FemalePed
local characterChosen     = false
Core                      = exports.vorp_core:GetCore()
Custom                    = nil
Peds                      = {}
CachedSkin                = {}
CachedComponents          = {}

-- the pristine key set of the skin table (shared/utils.lua, loaded as a shared_script so it is already here)
SKIN_SCHEMA               = {}
for k in pairs(PlayerSkin or {}) do SKIN_SCHEMA[k] = true end
T                         = Translation.Langs[Config.General.language]
CHARID                    = nil

-- KVP key for "**this garment is toggled off**" - written by /hat, /coat and the rest of Config.commands
function ClothingOffKey(comp)
	-- one canonical hash form for the key (comps arrive signed or unsigned)
	local c = tonumber(comp) or 0
	return ("vorp_character_off_%s_%s"):format(CHARID or 0, tostring(c % 0x100000000))
end

--PROMPTS
CreateThread(function()
	local str = T.PromptLabels.promptdeleteCurrent
	DeletePrompt = UiPromptRegisterBegin()
	UiPromptSetControlAction(DeletePrompt, Config.Keys.prompt_delete.key)
	str = VarString(10, 'LITERAL_STRING', str)
	UiPromptSetText(DeletePrompt, str)
	UiPromptSetEnabled(DeletePrompt, Config.CharacterSelect.allowDelete)
	UiPromptSetVisible(DeletePrompt, Config.CharacterSelect.allowDelete)
	UiPromptSetHoldMode(DeletePrompt, 5000)
	UiPromptSetGroup(DeletePrompt, PromptGroup, 0)
	UiPromptRegisterEnd(DeletePrompt)

	str = T.PromptLabels.promptselectConfirm
	SelectPrompt = UiPromptRegisterBegin()
	UiPromptSetControlAction(SelectPrompt, Config.Keys.prompt_select.key)
	str = VarString(10, 'LITERAL_STRING', str)
	UiPromptSetText(SelectPrompt, str)
	UiPromptSetEnabled(SelectPrompt, true)
	UiPromptSetVisible(SelectPrompt, true)
	UiPromptSetStandardMode(SelectPrompt, true)
	UiPromptSetGroup(SelectPrompt, PromptGroup, 0)
	UiPromptRegisterEnd(SelectPrompt)

	-- the BACKSPACE "go back" prompt is DISABLED
	str = T.PromptLabels.promptback
	GoBackPrompt = UiPromptRegisterBegin()
	UiPromptSetControlAction(GoBackPrompt, Config.Keys.prompt_Back.key)
	str = VarString(10, 'LITERAL_STRING', str)
	UiPromptSetText(GoBackPrompt, str)
	UiPromptSetEnabled(GoBackPrompt, false)
	UiPromptSetVisible(GoBackPrompt, false)
	UiPromptSetStandardMode(GoBackPrompt, true)
	UiPromptSetGroup(GoBackPrompt, PromptGroup, 0)
	UiPromptRegisterEnd(GoBackPrompt)
end)


--EVENTS
RegisterNetEvent("vorpcharacter:spawnUniqueCharacter", function(myChar)
	myChars = myChar
	CharSelect()
end)

RegisterNetEvent("vorpcharacter:selectCharacter", function(myCharacters, mc, rand)
	if #myCharacters < 1 then
		return TriggerEvent("vorpcharacter:startCharacterCreator")
	end

	CreateThread(function()
		-- also ends once a NEW character is in session (creator path never sets characterChosen)
		while not characterChosen and not LocalPlayer.state.IsInSession do
			SetAmbientAnimalDensityMultiplierThisFrame(0.0)
			SetAmbientHumanDensityMultiplierThisFrame(0.0)
			SetAmbientPedDensityMultiplierThisFrame(0.0)
			SetScenarioHumanDensityMultiplierThisFrame(0.0)
			SetScenarioPedDensityMultiplierThisFrame(0.0)
			SetVehicleDensityMultiplierThisFrame(0.0)
			BlockGameplayKeys()   -- no weapon wheel etc. on the selection screen
			Wait(0)
		end
		characterChosen = false
	end)

	random = rand
	myChars = myCharacters
	MaxCharacters = mc
	DoScreenFadeOut(0)
	repeat Wait(0) until IsScreenFadedOut()
	StartSwapCharacters()
end)


RegisterNetEvent("vorpcharacter:updateCache")
AddEventHandler("vorpcharacter:updateCache", function(skin, comps)
	if skin then
		if type(skin) == "table" then
			CachedSkin = skin
		else
			CachedSkin = json.decode(skin)
		end
	end

	if comps then
		if type(comps) == "table" then
			CachedComponents = UpdateCache(comps)
		else
			CachedComponents = UpdateCache(json.decode(comps))
		end
		-- dressing clears the /hat //shirt-style off flags, or the rebuild strips them again
		for _, v in pairs(CachedComponents) do
			if type(v) == "table" and v.comp and v.comp ~= -1 then
				SetResourceKvp(ClothingOffKey(v.comp), "false")
			end
		end
	end
	local newComps = GetNewCompOldStructure(CachedComponents)
	TriggerServerEvent("vorpcharacter:setPlayerCompChange", CachedSkin, newComps)
end)

-- CACHE-ONLY REFRESH
RegisterNetEvent("vorp_character:client:syncComps")
AddEventHandler("vorp_character:client:syncComps", function(comps)
	if not comps then return end

	local t = comps
	if type(t) ~= "table" then
		local ok, decoded = pcall(json.decode, t)
		if not ok or type(decoded) ~= "table" then return end
		t = decoded
	end

	CachedComponents = UpdateCache(t)

	-- being dressed clears the /hat-style off flags, same as updateCache does
	for _, v in pairs(CachedComponents) do
		if type(v) == "table" and v.comp and v.comp ~= -1 then
			SetResourceKvp(ClothingOffKey(v.comp), "false")
		end
	end
end)


-- tints handed over by another resource (pup_tailor) in the compTints shape
RegisterNetEvent("vorpcharacter:savetints")
AddEventHandler("vorpcharacter:savetints", function(tints)
	if type(tints) ~= "table" then return end
	for cat, byComp in pairs(tints) do
		local cur = CachedComponents[cat]
		if cur and cur.comp and cur.comp ~= -1 and type(byComp) == "table" then
			local t = byComp[tostring(cur.comp)]
			if t then
				cur.tint0   = tonumber(t.tint0) or 0
				cur.tint1   = tonumber(t.tint1) or 0
				cur.tint2   = tonumber(t.tint2) or 0
				cur.palette = tonumber(t.palette) or 0
			end
		end
	end
end)

RegisterNetEvent("vorpcharacter:savenew")
AddEventHandler("vorpcharacter:savenew", function(comps, skin)
	if comps then
		local t = comps
		if type(t) ~= "table" then t = json.decode(t) end
		-- a full outfit replaces the dye set; one without colours clears it
		CachedComponents.colors = nil
		CachedComponents = UpdateCache(t)
		-- CLEAR THE "TOGGLED OFF" FLAGS, same as updateCache above does. /mask, /glove
		for _, v in pairs(CachedComponents) do
			if type(v) == "table" and v.comp and v.comp ~= -1 then
				SetResourceKvp(ClothingOffKey(v.comp), "false")
			end
		end
	end

	if skin then
		local skinz
		if type(skin) == "table" then
			skinz = skin
		else
			skinz = json.decode(skin)
		end
		-- the key must already exist, so another resource cannot pollute skinPlayer
		for k, v in pairs(skinz) do
			if CachedSkin[k] ~= nil or SKIN_SCHEMA[k] then
				CachedSkin[k] = v
			end
		end
	end
	local newComps = GetNewCompOldStructure(CachedComponents)
	TriggerServerEvent("vorpcharacter:setPlayerCompChange", CachedSkin, newComps)
end)


--FUNCTIONS
local function LoadFaceFeatures(ped, skin)
	for _, value in pairs(Config.FaceFeatures) do
		for _, v in pairs(value) do
			if skin[v.comp] and skin[v.comp] ~= 0 then
				SetCharExpression(ped, v.hash, skin[v.comp])
			end
		end
	end
end

local function ApplyFaceOverlays(skin)
	for _, n in ipairs({"scars","spots","disc","complex","acne","ageing","freckles","moles"}) do
		FaceOverlay(n, skin[n.."_visibility"], skin[n.."_tx_id"], 0, 0, 1, 1.0, 0, 0, 0, 0, 0, 1, skin[n.."_opacity"])
	end
	local V = function(k) return type(k)=="number" and k or skin[k] end
	for _, o in ipairs({
		-- tx_id comes from the save: a literal 1 would put stubble on every character
		{"beardstabble","beardstabble","beardstabble_tx_id","beardstabble_color_primary",0,0,1},
		{"hair","hair","hair_tx_id","hair_color_primary",0,0,1},
		{"shadows","shadows",1,"shadows_palette_color_primary","shadows_palette_color_secondary","shadows_palette_color_tertiary","shadows_palette_id"},
		{"eyebrows","eyebrows","eyebrows_tx_id","eyebrows_color",0,0,1},
		{"eyeliners","eyeliner","eyeliner_tx_id","eyeliner_color_primary",0,0,"eyeliner_palette_id"},
		{"blush","blush","blush_tx_id","blush_palette_color_primary",0,0,1},
		{"lipsticks","lipsticks",1,"lipsticks_palette_color_primary","lipsticks_palette_color_secondary","lipsticks_palette_color_tertiary","lipsticks_palette_id"},
	}) do
		FaceOverlay(o[1], skin[o[2].."_visibility"], V(o[3]), 1, 0, 0, 1.0, 0, 1, V(o[4]), V(o[5]), V(o[6]), V(o[7]), skin[o[2].."_opacity"])
	end
end

-- PUT THE FACE BACK
function ReapplyFaceOverlays()
	local skin = CachedSkin
	if not skin or not next(skin) then return end
	canContinue = false
	ApplyFaceOverlays(skin)
	canContinue = true
	FaceOverlay("grime", skin.grime_visibility, skin.grime_tx_id, 0, 0, 0, 1.0, 0, 1, 0, 0, 0, 1, skin.grime_opacity)
end

-- the saved body adjustments (characters.expressions), written by the mirror's Body Adjustments menu
local function ApplyExpressions(ped, packed)
	if not ped or not DoesEntityExist(ped) then return end
	if type(packed) ~= "string" or packed == "" then return end
	local ok, ex = pcall(json.decode, packed)
	-- the column is DOUBLE-ENCODED - a JSON string whose contents are the JSON object
	if ok and type(ex) == "string" then
		ok, ex = pcall(json.decode, ex)
	end
	if not ok or type(ex) ~= "table" then return end
	for idx, v in pairs(ex) do
		local i, f = tonumber(idx), tonumber(v)
		if i and f then Citizen.InvokeNative(0x5653AB26C82938CF, ped, i, f + 0.0) end
	end
	UpdatePedVariation(ped)
end

local function ApplyAllComponents(category, value, ped, set)
	-- a half-built cache has holes in it
	if type(value) ~= "table" or value.comp == nil or value.comp == -1 then
		return
	end

	-- Config.Reload.wearsEverything = true makes /rc put EVERY saved garment back, ignoring the /hat //mask style toggles
	local status = "false"
	if set and not (Config and Config.Reload.wearsEverything) then
		status = GetResourceKvpString(ClothingOffKey(value.comp))
	end
	if status == "true" then
		if Config and Config.General.devMode then
			print(("^3[rc:%-12s]^7 %s NOT applied - toggled off by /%s"):format(
				"skipped", tostring(category),
				(Config.commands[category] and Config.commands[category].command) or "?"))
		end
		return RemoveTagFromMetaPed(Config.ComponentCategories[category])
	end

	ApplyShopItemToPed(value.comp, ped)

	if category ~= "Boots" then
		UpdateShopItemWearableState(value.comp, `base`)
	end

	Citizen.InvokeNative(0xAAB86462966168CE, ped, 1)
	UpdatePedVariation(ped)
	IsPedReadyToRender(ped)

	if value.palette ~= 0 then
		local TagData = GetMetaPedData(category == "Boots" and "boots" or category, ped)
		if TagData then
			local palette = (value.palette ~= 0) and value.palette or TagData.palette
			local tint0 = (value.tint0 ~= 0) and value.tint0 or TagData.tint0
			local tint1 = (value.tint1 ~= 0) and value.tint1 or TagData.tint1
			local tint2 = (value.tint2 ~= 0) and value.tint2 or TagData.tint2

			SetMetaPedTag(ped, TagData.drawable, TagData.albedo, TagData.normal, TagData.material, palette, tint0, tint1, tint2)
			-- the texture tint too (what dyed outfits use), inline with the garment so a rebuild never shows the stock colour first
			local catHash = Config.ComponentCategories[category]
			if catHash then
				Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, ped, catHash, palette, tint0, tint1, tint2)
				Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
			end
			if IsPedAPlayer(ped) and CachedComponents[category] then
				CachedComponents[category].drawable = TagData.drawable
				CachedComponents[category].albedo = TagData.albedo
				CachedComponents[category].normal = TagData.normal
				CachedComponents[category].material = TagData.material
				CachedComponents[category].palette = palette
			end
		end
	end
end

-- see below
function ApplyCachedColors(ped, components)
	local colors = components and components.colors
	if type(colors) ~= "table" or next(colors) == nil then return end
	for k, v in pairs(colors) do
		local hash = Config.ComponentCategories[k]
		if hash and type(v) == "table" then
			Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, ped, hash, tonumber(v.palette) or 0,
				math.floor(tonumber(v.color1) or 0), math.floor(tonumber(v.color2) or 0), math.floor(tonumber(v.color3) or 0))
		end
	end
	Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
	UpdatePedVariation(ped)
end

function LoadComps(ped, components, set)
	for category, value in pairs(components) do
		ApplyAllComponents(category, value, ped, set)
	end
	ApplyAllComponents("Shirt", components.Shirt, ped, set)
	ApplyAllComponents("Vest", components.Vest, ped, set)
	ApplyAllComponents("Boots", components.Boots, ped, set)

	UpdatePedVariation(ped)
end

---Remove all meta tags from ped
local function removeMetaTags(ped)
	for _, tag in pairs(Config.ComponentCategories) do
		RemoveTagFromMetaPed(tag, ped)
		UpdatePedVariation(ped)
	end
end

-- if values are 0 then we need to make everything same color
local function setDefaultSkin(gender, skin)
	for _, value in pairs(Config.DefaultChar) do
		local albedo = joaat(value.Albedo[1]:format(gender))
		if albedo == skin.albedo then
			-- the tone pickers keep Torso in step, so only an unset one is filled in

			if skin.HeadType and skin.HeadType == 0 then
				skin.HeadType = joaat(value.Heads[1]:format(gender))
			end

			if skin.BodyType and skin.BodyType == 0 then
				skin.BodyType = joaat(value.Body[1]:format(gender))
			end

			if skin.LegsType and skin.LegsType == 0 then
				skin.LegsType = joaat(value.Legs[1]:format(gender))
			end

			if skin.Torso and skin.Torso == 0 then
				skin.Torso = joaat(value.Body[1]:format(gender))
			end
			break
		end
	end

	return skin
end

function LoadAll(gender, ped, pedskin, components, set)
	removeMetaTags(ped)
	IsPedReadyToRender(ped)
	ResetPedComponents(ped)
	local skin = setDefaultSkin(gender, pedskin)
	ApplyShopItemToPed(skin.HeadType, ped)
	ApplyShopItemToPed(skin.BodyType, ped)
	ApplyShopItemToPed(skin.LegsType, ped)
	ApplyShopItemToPed(skin.Eyes, ped)
	ApplyShopItemToPed(skin.Legs, ped)
	ApplyShopItemToPed(skin.Hair, ped)
	ApplyShopItemToPed(skin.Beard, ped)
	ApplyShopItemToPed(skin.Torso, ped)
	EquipMetaPedOutfit(skin.Waist, ped)
	EquipMetaPedOutfit(skin.Body, ped)
	Citizen.InvokeNative(0xAAB86462966168CE, ped, 1)
	LoadFaceFeatures(ped, skin)
	UpdatePedVariation(ped)
	IsPedReadyToRender(ped)
	-- repaint the saved hair tint
	if ApplyHairTint then ApplyHairTint(ped, skin) end
	-- and rebuild a saved story-ped beard, which is a tag rather than a shop item
	if ApplyBeardTag then ApplyBeardTag(ped, skin) end
	LoadComps(ped, components, set)
	SetPedScale(ped, skin.Scale)
	UpdatePedVariation(ped)
	-- selection-screen preview peds show their dye too (reference LoadComps)
	ApplyCachedColors(ped, components)
	return skin
end

local function LoadCharacterSelect(ped, skin, components)
	local gender = skin.sex == "mp_male" and "M" or "F"

	if skin.sex ~= "mp_male" then
		EquipMetaPedOutfitPreset(ped, 7)
	else
		EquipMetaPedOutfitPreset(ped, 4)
	end

	LoadAll(gender, ped, skin, components, false)
	SetAttributeCoreValue(ped, 1, 100)
	SetAttributeCoreValue(ped, 0, 100)
end

-- true while the character selection list or the creator is on screen; fred_hud
-- reads it through the export below, since the usual natives are false here
CharScreenOpen = false
exports('IsInCharacterScreen', function()
	return CharScreenOpen or InCharacterCreator or IsInCharCreation or false
end)

-- safety net: the flag is cleared in CharSelect() (existing character) and in FinishCreation() (new one)
RegisterNetEvent('vorp:SelectedCharacter')
AddEventHandler('vorp:SelectedCharacter', function()
	CharScreenOpen = false
end)

function CharSelect()
	CharScreenOpen = false
	DoScreenFadeOut(0)
	repeat Wait(0) until IsScreenFadedOut()

	local charIdentifier = myChars[selectedChar].charIdentifier
	CHARID = charIdentifier
	local nModel = tostring(myChars[selectedChar].skin.sex)
	CachedSkin = myChars[selectedChar].skin
	CachedComponents = myChars[selectedChar].components

	SetCachedSkin()
	TriggerServerEvent("vorp_CharSelectedCharacter", charIdentifier)

	if not HasModelLoaded(nModel) then
		RequestModel(nModel, false)
		repeat Wait(0) until HasModelLoaded(nModel)
	end

	SetPlayerModel(PlayerId(), joaat(nModel), false)
	local ped = PlayerPedId()
	LoadPlayerComponents(ped, CachedSkin, CachedComponents)
	NetworkClearClockTimeOverride()
	FreezeEntityPosition(ped, false)
	-- first spawn of the session: tells pup_clothing this rebuild is done, so it does not race it
	TriggerEvent('vorp_character:client:reloadedComponents')
	SetEntityVisible(ped, true)
	SetPlayerInvincible(ped, false)
	SetEntityCanBeDamaged(ped, true)

	local coords = myChars[selectedChar].coords
	if not coords.x or not coords.y or not coords.z or not coords.heading then
		print("No coords found send back to original")
		coords = Config.SpawnCoords[math.random(#Config.SpawnCoords)].position
	end

	local playerCoords = vector3(tonumber(coords.x), tonumber(coords.y), tonumber(coords.z))
	local heading = coords.heading
	local isDead = myChars[selectedChar].isDead
	-- pup: hand the HUD back before the world appears
	TriggerEvent("vorp:showUi", true)
	DisplayRadar(true)

	TriggerEvent("vorp:initCharacter", playerCoords, heading, isDead)
	characterChosen = true
	SetModelAsNoLongerNeeded(nModel)
end

function StartSwapCharacters()
	-- same as the creator - no money/ID/gold readout or minimap over the character selection. vorp_core's own switch
	TriggerEvent("vorp:showUi", false)
	DisplayRadar(false)
	ShowBusyspinnerWithText(T.Other.spinnertext)
	local options = Config.SpawnPosition[random].options
	pcall(function() -- weathersync is optional
		exports.weathersync:setSyncEnabled(false)
		exports.weathersync:setMyWeather(options.weather.type, options.weather.transition, options.weather.snow)
		exports.weathersync:setMyTime(options.time.hour, 0, 0, options.time.transition, true)
	end)
	SetTimecycleModifier(options.timecycle.name)
	Citizen.InvokeNative(0xFDB74C9CC54C3F37, options.timecycle.strength)
	StartPlayerTeleport(PlayerId(), options.playerpos.x, options.playerpos.y, options.playerpos.z, 0.0, true, true, true, true)
	repeat Wait(0) until not IsPlayerTeleportActive()
	SetEntityCoords(PlayerPedId(), options.playerpos.x, options.playerpos.y, options.playerpos.z, false, false, false, false) -- sometimes it doesnt tp with devmode. so we enforce
	PrepareMusicEvent(options.music)
	Wait(100)
	TriggerMusicEvent(options.music)
	Wait(200)

	-- requested unconditionally: an `if not` guard would read a NUMBER, and 0 is truthy
	RequestCollisionAtCoord(options.playerpos.x, options.playerpos.y, options.playerpos.z)

	-- bounded: a streaming failure must not hang login on a spinner
	local colw <const> = GetGameTimer()
	repeat
		RequestCollisionAtCoord(options.playerpos.x, options.playerpos.y, options.playerpos.z)
		Wait(0)
	until NativeOn(HasCollisionLoadedAroundEntity(PlayerPedId())) or GetGameTimer() - colw > 10000
	FreezeEntityPosition(PlayerPedId(), true)
	SetEntityVisible(PlayerPedId(), false)
	SetEntityInvincible(PlayerPedId(), true)

	-- pup: settle after collision reported loaded, not a load wait.
	Wait(300)
	for key, value in pairs(myChars) do
		LoadPlayer(value.skin.sex)
		local data = Config.SpawnPosition[random].positions[key]
		if not data then
			return error("your config spawn locations doesnt have enough spawn locations you need to add: " .. #myChars .. "Spawn locations")
		end

		local modelHash = joaat(value.skin.sex)
		SetPlayerModel(PlayerId(), modelHash, false)
		local playerPed = PlayerPedId()

		LoadCharacterSelect(playerPed, value.skin, value.components)
		CachedSkin = value.skin
		canContinue = false
		ApplyFaceOverlays(value.skin)
		canContinue = true
		FaceOverlay("grime", value.skin.grime_visibility, value.skin.grime_tx_id, 0, 0, 0, 1.0, 0, 1, 0, 0, 0, 1, value.skin.grime_opacity)
		-- the mirror's saved body adjustments (characters.expressions) on the preview
		ApplyExpressions(playerPed, value.expressions)
		Wait(500)

		data.PedHandler = ClonePed(playerPed, false, false, false, false)

		if not data.PedHandler or not DoesEntityExist(data.PedHandler) then
			data.PedHandler = CreatePed(modelHash, data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w, false, false, false, false)
			LoadCharacterSelect(data.PedHandler, value.skin, value.components)
		else
			SetEntityCoords(data.PedHandler, data.spawn.x, data.spawn.y, data.spawn.z, false, false, false, false)
			SetEntityHeading(data.PedHandler, data.spawn.w)
		end

		-- BODY ADJUSTMENTS ON THE PED YOU ACTUALLY SEE
		ApplyExpressions(data.PedHandler, value.expressions)

		SetEntityVisible(playerPed, false)
		FreezeEntityPosition(playerPed, true)

		data.Cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", data.camera.x, data.camera.y, data.camera.z, data.camera.rotx, data.camera.roty, data.camera.rotz, data.camera.fov, false, 2)
		-- the wait above only covered options.playerpos; these stand up to 10m off it
		RequestCollisionAtCoord(data.spawn.x, data.spawn.y, data.spawn.z)
		-- left unfrozen so gravity seats the feet, then pinned once below
		FreezeEntityPosition(data.PedHandler, false)
		SetEntityInvincible(data.PedHandler, true)
		ClearPedTasks(data.PedHandler)
		Wait(100)
		local randomScenario = math.random(1, #data.scenario[value.skin.sex])
		Citizen.InvokeNative(0x524B54361229154F, data.PedHandler, joaat(data.scenario[value.skin.sex][randomScenario]), -1, false, joaat(data.scenario[value.skin.sex][randomScenario]), -1.0, 0)
		Peds[#Peds + 1] = data.PedHandler
		SetPedCanBeTargetted(data.PedHandler, false)
	end

	mainCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", options.mainCam.x, options.mainCam.y, options.mainCam.z, options.mainCam.rotx, options.mainCam.roty, options.mainCam.rotz, options.mainCam.fov, false, 0)
	SetCamActive(mainCam, true)
	RenderScriptCams(true, false, 0, true, true, 0)
	repeat Wait(0) until IsCamActive(mainCam)
	Wait(250)

	-- pinned once seated: an unfrozen preview ped fights its own scenario anchor while
	-- it is still falling, which is the hovering, twitching character
	for _, ped in ipairs(Peds) do
		if DoesEntityExist(ped) then FreezeEntityPosition(ped, true) end
	end

	DoScreenFadeIn(1000)
	BusyspinnerOff()
	AnimpostfxPlay('PhotoMode_FilterGame06')
	repeat Wait(50) until IsScreenFadedIn()
	OpenMenuSelect()
end

local function finishSelection(boolean)
	-- THE choke point - every way out of the selection UI ends here
	CharScreenOpen = false
	Form.CloseAll()
	if boolean then
		DoScreenFadeOut(1000)
		repeat Wait(0) until IsScreenFadedOut()
	end
	Wait(400)
	CreateThread(function()
		Wait(2000)
		for _, value in pairs(Peds) do
			DeleteEntity(value)
		end
		DestroyAllCams(true)
	end)
	Citizen.InvokeNative(0x706D57B0F50DA710, "MC_MUSIC_STOP")
end


local function createMainCam()
	local data = Config.SpawnPosition[random].options
	mainCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", data.mainCam.x, data.mainCam.y, data.mainCam.z, data.mainCam.rotx, data.mainCam.roty, data.mainCam.rotz, data.mainCam.fov, false, 2)
	SetCamActive(mainCam, true)
	RenderScriptCams(true, false, 0, true, true, 0)
end

-- takes no menu argument: the NUI list is rebuilt from myChars by OpenMenuSelect()
local function DeleleteSelectedChaacter()
	local dataConfig = Config.SpawnPosition[random].positions[selectedChar]
	DeleteEntity(dataConfig.PedHandler)

	for i, ped in ipairs(Peds) do
		if ped == dataConfig.PedHandler then
			table.remove(Peds, i)
			break
		end
	end

	TriggerServerEvent("vorpcharacter:deleteCharacter", myChars[selectedChar])
	table.remove(myChars, selectedChar)

	if #myChars == 0 or myChars == nil then
		TriggerEvent("vorpcharacter:startCharacterCreator")
		return finishSelection(false)
	end

	for i = selectedChar, #myChars do
		local currentData = Config.SpawnPosition[random].positions[i]
		local nextData = Config.SpawnPosition[random].positions[i + 1]

		if nextData and nextData.PedHandler then
			currentData.PedHandler = nextData.PedHandler
			currentData.Cam = nextData.Cam
			nextData.PedHandler = nil
			nextData.Cam = nil
		end
	end

	local lastPosition = Config.SpawnPosition[random].positions[#myChars + 1]
	if lastPosition then
		lastPosition.PedHandler = nil
		lastPosition.Cam = nil
	end

	createMainCam()
	PlaySoundFrontend('TITLE_SCREEN_EXIT', 'DEATH_FAIL_RESPAWN_SOUNDS', true, 0)
	AnimpostfxPlay("RespawnPulse01")
	SetCamActiveWithInterp(mainCam, dataConfig.Cam, 1500, 500, 500)
	SetCamFocusDistance(mainCam, 1.0)
	LastCam = nil -- the per-ped cams were just reshuffled; don't interp from a stale one
end

-- GetCharacterDescDetails built the card's money table as HTML




local WhileSwaping = false

-- selection is a NUI page (ui/charselect.*)
local function closeCharSelectNui()
	SetNuiFocus(false, false)
	SendNUIMessage({ type = "cs:close" })
end

local function charGender(v)
	local g <const> = tostring(v.gender or ""):lower():sub(1, 1)
	if g == "m" then return "Male" end
	if g == "f" then return "Female" end
	return nil
end

-- the shop name the server resolved, with no grade appended: jobgrade is a bare
-- number on this server and "Valentine Tailor - 5" reads as noise
local function charJob(v)
	local job <const> = tostring(v.job or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if job == "" or job == "unemployed" then return nil end
	return job
end

local function charSelectList()
	local list = {}
	for i, v in ipairs(myChars) do
		list[#list + 1] = {
			index      = i,
			firstname  = v.firstname,
			lastname   = v.lastname,
			money      = v.money,
			gold       = v.gold,
			gender     = charGender(v),
			isDead     = v.isDead == 1 or v.isDead == true,
			charId     = v.charIdentifier,
			job        = charJob(v),
			where      = v.where,
			lastPlayed = v.lastPlayed,
			jail       = v.jailMinutes,
		}
	end
	return list
end

function OpenMenuSelect()
	Form.CloseAll()

	AnimpostfxStop('PhotoMode_FilterGame06')
	AnimpostfxPlay("RespawnPulse01")
	PlaySoundFrontend("Ready_Up_Flash", "RDRO_In_Game_Menu_Sounds", true, 0)

	CharScreenOpen = true -- pup: selection is up; HUDs stay off (see the export above)
	SetNuiFocus(true, true)
	SendNUIMessage({
		type       = "cs:open",
		title      = T.MenuCreation.title1,
		characters = charSelectList(),
		max        = MaxCharacters,
		showGold   = Config.CharacterSelect.showGold and true or false,
		canDelete  = Config.CharacterSelect.allowDelete and true or false,
	})
end

-- highlight moved: frame that character's ped
RegisterNUICallback("cs_look", function(data, cb)
	cb({})
	local i <const> = tonumber(data and data.index)
	if not i or not myChars[i] then return end
	local cfg <const> = Config.SpawnPosition[random] and Config.SpawnPosition[random].positions[i]
	if not cfg or not cfg.Cam then return end

	selectedChar = i
	SetCamActiveWithInterp(cfg.Cam, LastCam or mainCam, 900, 500, 500)
	SetCamFocusDistance(cfg.Cam, 4.0)
	LastCam = cfg.Cam
	if mainCam and IsCamActive(mainCam) then SetCamActive(mainCam, false) end
	PlaySoundFrontend("HIGHLIGHT_NAV_UP", "RDRO_Character_Creator_Sounds", true, 0)
end)

-- play as the highlighted character
RegisterNUICallback("cs_play", function(data, cb)
	cb({})
	local i <const> = tonumber(data and data.index)
	if not i or not myChars[i] or WhileSwaping then return end

	selectedChar = i
	WhileSwaping = true
	closeCharSelectNui()

	CreateThread(function()
		UiFeedClearChannel(3, true, false)
		AnimpostfxPlay("RespawnPulse01")
		PlaySoundFrontend("Ready_Up_Flash", "RDRO_In_Game_Menu_Sounds", true, 0)
		ClearPedTasks(PlayerPedId(), false, false)
		Wait(1000)
		AnimpostfxPlay('PhotoMode_FilterGame06')
		finishSelection(true)
		AnimpostfxStop('PhotoMode_FilterGame06')
		ClearTimecycleModifier()
		pcall(function() exports.weathersync:setSyncEnabled(true) end) -- weathersync is optional
		CharSelect()
		WhileSwaping = false
	end)
end)

-- an empty slot goes straight into the creator
RegisterNUICallback("cs_create", function(_, cb)
	cb({})
	if WhileSwaping then return end
	WhileSwaping = true
	closeCharSelectNui()

	CreateThread(function()
		UiFeedClearChannel(3, true, false)
		AnimpostfxPlay('PhotoMode_FilterGame06')
		finishSelection(true)
		Wait(2000)
		AnimpostfxStop('PhotoMode_FilterGame06')
		-- hand over a CLEAN scene, the same way cs_play does
		ClearTimecycleModifier()
		TriggerEvent("vorpcharacter:startCharacterCreator")
	end)
end)

RegisterNUICallback("cs_delete", function(data, cb)
	cb({})
	local i <const> = tonumber(data and data.index)
	if not i or not myChars[i] or WhileSwaping then return end
	if not Config.CharacterSelect.allowDelete then return end

	selectedChar = i
	closeCharSelectNui()

	CreateThread(function()
		DeleleteSelectedChaacter()
		-- none left: DeleleteSelectedChaacter already sent them to the creator
		if #myChars > 0 then OpenMenuSelect() end
	end)
end)

AddEventHandler("vorpcharacter:reloadafterdeath", function()
	local player = PlayerPedId()
	local getPedModel = GetEntityModel(player)
	local reload = false
	if getPedModel ~= joaat("mp_female") and getPedModel ~= joaat("mp_male") then
		-- Not a mp model convert to this model before reload to player model?
		Wait(5000)
		LoadPlayer(joaat("CS_dutch"))
		SetPlayerModel(PlayerId(), joaat("CS_dutch"), false)
		IsPedReadyToRender(player)
		SetModelAsNoLongerNeeded(joaat("CS_dutch"))
		reload = true
	end

	if CachedSkin and CachedComponents then
		LoadPlayerComponents(player, CachedSkin, CachedComponents, reload)
	end

	SetAttributeCoreValue(player, 0, 100)
	SetEntityHealth(player, 600, 1)
	SetAttributeCoreValue(player, 1, 100)
	RestorePedStamina(player, 1065330373)
	-- a revive re-applies every garment from compPlayer
	TriggerEvent('vorp_character:client:reloadedComponents')
end)



function LoadPlayerComponents(ped, skin, components, reload)
	-- "M"/"F", NOT "Male"/"Female"
	local gender = skin.sex == "mp_male" and "M" or "F"
	local getPedModel = GetEntityModel(ped)

	-- Ours forced it on every /rc, and SetPlayerModel destroys the ped to build a new one
	local targetModel = (not Custom and skin.sex or Custom)
	if type(targetModel) == "string" then targetModel = joaat(targetModel) end
	-- PupForceRebuild: one-shot from pup_height.lua - after a carry
	local willRebuild <const> = targetModel ~= getPedModel or PupForceRebuild == true
	PupForceRebuild = false

	if Config and Config.General.devMode then
		print(("^3[rc:%-12s]^7 reload=%-6s pedModel=%-12s isOwnModel=%-6s -> rebuild=%s")
			:format("decide", tostring(reload), tostring(getPedModel),
				tostring(getPedModel == joaat("mp_male") or getPedModel == joaat("mp_female")),
				tostring(willRebuild)))
	end

	if willRebuild then
		-- is npc model convert to player model
		local skinS = not Custom and skin.sex or Custom
		if type(skinS) == "string" then skinS = joaat(skinS) end
		local previous <const> = ped
		LoadPlayer(skinS)
		SetPlayerModel(PlayerId(), skinS, false)

		-- SetPlayerModel does NOT swap on the calling frame
		local t0 = GetGameTimer()
		while PlayerPedId() == previous and GetGameTimer() - t0 < 3000 do
			Wait(0)
		end
		while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, PlayerPedId()) and GetGameTimer() - t0 < 5000 do
			Wait(0)
		end

		ped = PlayerPedId()
		SetEntityFadeIn(ped)
		SetModelAsNoLongerNeeded(skinS)
		Custom = nil
		if Config and Config.General.devMode then
			print(("^3[rc:%-12s]^7 SetPlayerModel ran, swap took %dms  old=%s new=%s")
				:format("rebuild", GetGameTimer() - t0, tostring(previous), tostring(ped)))
		end
	end

	-- a story model carries no metaped tags, so everything below would strip it
	-- bare; give it its own outfit preset instead and stop here
	local nowModel <const> = GetEntityModel(ped)
	if nowModel ~= joaat("mp_male") and nowModel ~= joaat("mp_female") then
		-- read by commands.lua, so the /rc tail skips its re-decorate chain
		PupStoryPed = true
		Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
		Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, 0) -- preset 0, so a ped looks the same every time
		Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
		if CachedSkin and tonumber(CachedSkin.Scale) then
			SetPedScale(ped, CachedSkin.Scale)
			if PupNoteSelfScale and ped == PlayerPedId() then PupNoteSelfScale(ped, CachedSkin.Scale) end
		end
		if Config and Config.General.devMode then
			print(("^3[rc:%-12s]^7 story ped %s - MP component pass skipped"):format("storyped", tostring(nowModel)))
		end
		return
	end
	PupStoryPed = false

	if skin.sex ~= "mp_male" then
		EquipMetaPedOutfitPreset(ped, 7)
	else
		EquipMetaPedOutfitPreset(ped, 4)
	end

	if Config and Config.General.devMode then
		print(("^3[rc:%-12s]^7 scale=%s about to be applied by LoadAll")
			:format("loadall", tostring(skin.Scale)))
	end

	skin = LoadAll(gender, ped, skin, components, true)
	RegisterBodyIndexs(skin)
	ApplyRolledClothingStatus()
	canContinue = false
	ApplyFaceOverlays(skin)
	canContinue = true
	FaceOverlay("grime", skin.grime_visibility, skin.grime_tx_id, 0, 0, 0, 1.0, 0, 1, 0, 0, 0, 1, skin.grime_opacity)
	Wait(200)
	TriggerServerEvent("vorpcharacter:reloadedskinlistener")
	RemoveTagFromMetaPed(Config.ComponentCategories.AmmoPistol)
	SetPedScale(ped, CachedSkin.Scale)
	-- SetPedScale does not redraw the ped on its own
	UpdatePedVariation(ped)
	ApplyCachedColors(ped, components)
	-- pup_height: this ped already wears its height, so the follow-up height push needs no redraw (no blink)
	if PupNoteSelfScale and ped == PlayerPedId() then PupNoteSelfScale(ped, CachedSkin.Scale) end
end

-- other resources that flip a garment's wearable state (pup-misc /bandana) ask for the dye back
AddEventHandler("vorp_character:client:reapplyColors", function()
	ApplyCachedColors(PlayerPedId(), CachedComponents)
end)

-- the game redraws the hat on knock-off / re-equip, dropping its dye
CreateThread(function()
	while true do
		Wait(0)
		local size = GetNumberOfEvents(0)
		for i = 0, size - 1 do
			local ev = GetEventAtIndex(0, i)
			if ev == `EVENT_PLAYER_HAT_KNOCKED_OFF` or ev == `EVENT_PLAYER_HAT_EQUIPPED` then
				ApplyCachedColors(PlayerPedId(), CachedComponents)
			end
		end
	end
end)

function FaceOverlay(name, visibility, tx_id, tx_normal, tx_material, tx_color_type, tx_opacity, tx_unk, palette_id, palette_color_primary, palette_color_secondary, palette_color_tertiary, var, opacity)
	visibility = visibility or 0
	tx_id = tx_id or 0
	palette_color_primary = palette_color_primary or 0
	opacity = opacity or 1.0

	for _, v in ipairs(Config.overlay_all_layers) do
		if v.name == name then
			v.visibility = visibility
			if visibility ~= 0 then
				v.tx_normal = tx_normal
				v.tx_material = tx_material
				v.tx_color_type = tx_color_type
				v.tx_opacity = tx_opacity
				v.tx_unk = tx_unk

				if tx_color_type == 0 then
					v.palette = Config.color_palettes[name][palette_id]
					v.palette_color_primary = palette_color_primary == 0 and 0x3F6E70FF or palette_color_primary
					v.palette_color_secondary = palette_color_secondary or 0
					v.palette_color_tertiary = palette_color_tertiary or 0
				end

				v.var = 0
				v.tx_id = tx_id == 0 and Config.overlays_info[name][1].id or Config.overlays_info[name][tx_id].id

				if name == "shadows" or name == "eyeliners" or name == "lipsticks" then
					v.var = var or 0
					v.tx_id = Config.overlays_info[name][1].id
				end

				v.opacity = opacity == 0 and 1.0 or opacity

				if name == "grime" then
					v.visibility = 0
				end
			end
		end
	end

	if canContinue then
		canContinue = false
		CreateThread(StartOverlay)
	end
end

function StartOverlay()
	local current_texture_settings = Config.texture_types.Male

	if CachedSkin.sex ~= tostring("mp_male") then
		current_texture_settings = Config.texture_types.Female
	end

	if textureId ~= -1 then
		Citizen.InvokeNative(0xB63B9178D0F58D82, textureId) -- reset texture
		Citizen.InvokeNative(0x6BEFAA907B076859, textureId) -- remove texture
	end

	if CachedSkin.albedo and CachedSkin.albedo == 0 then
		CachedSkin.albedo = current_texture_settings.albedo
	end

	textureId = Citizen.InvokeNative(0xC5E7204F322E49EB, CachedSkin.albedo, current_texture_settings.normal, current_texture_settings.material)
	for k, v in ipairs(Config.overlay_all_layers) do
		if v.visibility ~= 0 then
			local overlay_id = Citizen.InvokeNative(0x86BB5FF45F193A02, textureId, v.tx_id, v.tx_normal, v.tx_material, v.tx_color_type, v.tx_opacity, v.tx_unk)
			if v.tx_color_type == 0 then
				Citizen.InvokeNative(0x1ED8588524AC9BE1, textureId, overlay_id, v.palette);                                                       -- apply palette
				Citizen.InvokeNative(0x2DF59FFE6FFD6044, textureId, overlay_id, v.palette_color_primary, v.palette_color_secondary, v.palette_color_tertiary) -- apply palette colours
			end
			Citizen.InvokeNative(0x3329AAE2882FC8E4, textureId, overlay_id, v.var)                                                                -- apply overlay variant
			Citizen.InvokeNative(0x6C76BC24F8BB709A, textureId, overlay_id, v.opacity)                                                            -- apply overlay opacity
		end
	end

	-- BOUNDED
	local deadline = GetGameTimer() + 5000
	while not Citizen.InvokeNative(0x31DC8D3F216D8509, textureId) and GetGameTimer() < deadline do
		Wait(0)
	end
	if not Citizen.InvokeNative(0x31DC8D3F216D8509, textureId) then
		print(("^1[vorp_character]^7 overlay texture %s never became valid after 5s - face overlays not applied this pass")
			:format(tostring(textureId)))
		return
	end

	-- read here, not at the top, so a rebuild during the texture wait is picked up
	local ped = PlayerPedId()
	Citizen.InvokeNative(0x0B46E25761519058, ped, joaat("heads"), textureId)  -- apply texture to category "heads"
	Citizen.InvokeNative(0x92DAABA2C1C10B0E, textureId)                       -- update texture
	Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)          -- refresh ped components
end

-- work arround to fix scale issues: re-applies the saved Scale every second, refreshing the ped only when it changes
CreateThread(function()
	repeat Wait(2000) until LocalPlayer.state.IsInSession
	local lastApplied, lastPed
	while true do
		local ped = PlayerPedId()
		local dead = IsEntityDead(ped)
		-- NOT while transformed
		if CachedSkin and IsPedHuman(ped) then
			local PlayerHeight = CachedSkin.Scale
			if PlayerHeight and not dead then
				SetPedScale(ped, PlayerHeight)
				if PlayerHeight ~= lastApplied or ped ~= lastPed then
					UpdatePedVariation(ped)
					lastApplied, lastPed = PlayerHeight, ped
				end
			end
		end
		Wait(1000)
	end
end)


AddEventHandler('onClientResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end

	if Config.General.devMode then
		print("^3VORP Character Selector is in ^1DevMode^7 dont use in live servers")
		TriggerServerEvent("vorp_character:server:GoToSelectionMenu")
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end

	for _, value in ipairs(Peds) do
		DeleteEntity(value)
	end

	ResetPedComponents(PlayerPedId())
	Citizen.InvokeNative(0xB63B9178D0F58D82, textureId) -- reset texture
	Citizen.InvokeNative(0x6BEFAA907B076859, textureId) -- remove texture
	DeleteEntity(MalePed)
	DeleteEntity(FemalePed)
	DoScreenFadeIn(100)
	RemoveImaps()
	Citizen.InvokeNative(0x706D57B0F50DA710, "MC_MUSIC_STOP")
	Form.CloseAll()
	DestroyAllCams(true)
	UiFeedClearChannel(3, true, false)
	AnimpostfxStopAll()
	Citizen.InvokeNative(0x120C48C614909FA4, "AZL_RDRO_Character_Creation_Area", true)                  -- CLEAR_AMBIENT_ZONE_LIST_STATE
	Citizen.InvokeNative(0x9D5A25BADB742ACD, "AZL_RDRO_Character_Creation_Area_Other_Zones_Disable", true) -- CLEAR_AMBIENT_ZONE_LIST_STATE
	EnableControlAction(2, `INPUT_CREATOR_MENU_TOGGLE`, true)
	FreezeEntityPosition(PlayerPedId(), false)
end)

-- apply whistle data on character selected
RegisterNetEvent("vorp:SelectedCharacter", function(charid)
	CHARID = charid
	-- if it exists set is current values that were saved when player first made a character
	local whistleData <const> = GetResourceKvpString(("vorp_character_whistle_%s"):format(charid))
	if whistleData then
		local data <const> = json.decode(whistleData)
		local ped <const> = PlayerPedId()
		if data.pitch and data.pitch > 0 then
			SetWhistleConfigForPed(ped, "Ped.WhistlePitch", data.pitch)
		elseif data.clarity and data.clarity > 0 then
			SetWhistleConfigForPed(ped, "Ped.WhistleClarity", data.clarity)
		elseif data.style and data.style > 0 then
			SetWhistleConfigForPed(ped, "Ped.WhistleShape", data.style)
		end
	else
		if (WHISTLE.clarity and WHISTLE.clarity > 0) or (WHISTLE.pitch and WHISTLE.pitch > 0) or (WHISTLE.style and WHISTLE.style > 0) then
			SetResourceKvpNoSync(("vorp_character_whistle_%s"):format(charid), json.encode({
				clarity = WHISTLE.clarity,
				pitch = WHISTLE.pitch,
				style = WHISTLE.style
			}))
		end
	end
end)
