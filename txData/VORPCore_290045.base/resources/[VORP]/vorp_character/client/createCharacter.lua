-- Modified by Puppet (Dusk Till Dawn), 2026
---@diagnostic disable: undefined-global
local isMale = true
-- the three prompts that are actually registered
local right
local down
local zoomout

local PromptGroup2 = GetRandomIntInRange(0, 0xffffff)
local Core = exports.vorp_core:GetCore()
T = Translation.Langs[Config.General.language]
InCharacterCreator = false
IsInCharCreation = false
FemalePed = nil
MalePed = nil


-- you must set to true to wait the character scene
local loadingScene = false
AddEventHandler("vorpcharacter:stopLoadingScene", function(value)
	loadingScene = value
end)

function SetupCameraCharacterCreationSelect()
	local camera = CreateCamera(`DEFAULT_SCRIPTED_CAMERA`, true)
	local pos = vec3(-562.15, -3776.22, 239.11)
	local rot = vec3(-4.71, 0.0, -93.14)
	SetCamParams(camera, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 45.0, 0, 1, 1, 2, 1, 1)
	SetCamFocusDistance(camera, 4.0)
	RenderScriptCams(true, false, 3000, true, true, 0)
	return camera
end

-- request char creator imaps
local function Setup()
	local custom <const> = CreatorSceneActive and CreatorSceneActive()

	if custom then
		-- the RDO imaps and its ambient sound zones only exist in that area
		CreatorSceneLoad()
	else
		-- imaps FIRST, or the load scene closes before the room has anything to stream
		RequestImapCreator()
		Citizen.InvokeNative(0x513F8AA5BF2F17CF, -561.4, -3782.6, 237.6, 50.0, 20)                                 -- loadshpere
		-- Wait(50), not 0: a tight spin starves the network thread and times out
		local t0 <const> = GetGameTimer()
		repeat Wait(50) until IsLoadSceneLoaded() or GetGameTimer() - t0 > 3000
		LoadSceneStop()
		Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area", true, true)                   -- load sound
		Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area_Other_Zones_Disable", false, true) -- load sound
	end

	NetworkClockTimeOverride(10, 0, 0, 0, true)
	SetTimecycleModifier('Online_Character_Editor')
	-- the select scene set a modifier STRENGTH too, and that value survives a modifier swap
	Citizen.InvokeNative(0xFDB74C9CC54C3F37, 1.0)

	local sx, sy, sz, sh = -561.22, -3776.26, 239.16, 93.2
	if custom then sx, sy, sz, sh = CreatorSceneSpawn() end

	StartPlayerTeleport(PlayerId(), sx, sy, sz, sh, true, true, true, true)

	-- bounded, so a teleport that never ends cannot hang the creator
	local tp <const> = GetGameTimer()
	repeat Wait(50) until not IsPlayerTeleportActive() or GetGameTimer() - tp > 5000

	-- StartPlayerTeleport fails silently on a half-spawned ped, so verify it landed
	local me <const> = PlayerPedId()
	if #(GetEntityCoords(me) - vector3(sx, sy, sz)) > 5.0 then
		print("^3[vorp_character]^7 creator teleport did not land - placing the ped directly")
		SetEntityCoordsAndHeading(me, sx, sy, sz, sh, false, false, false)
		Wait(250)
	end

	-- the earlier load sphere closed before the teleport, so ask again from the mark
	Citizen.InvokeNative(0x513F8AA5BF2F17CF, sx, sy, sz, 50.0, 20)
	local ls <const> = GetGameTimer()
	repeat Wait(50) until IsLoadSceneLoaded() or GetGameTimer() - ls > 4000
	LoadSceneStop()

	-- RequestCollisionAtCoord is per-frame, so the Wait(0) spin is deliberate
	local col <const> = GetGameTimer()
	while not NativeOn(HasCollisionLoadedAroundEntity(PlayerPedId())) do
		RequestCollisionAtCoord(sx, sy, sz)
		Wait(0)
		if GetGameTimer() - col > 5000 then
			print("^3[vorp_character]^7 collision never loaded at the creator mark - carrying on anyway")
			break
		end
	end

	-- the room is an IPL and one request is no guarantee
	if not custom then
		local t <const> = GetGameTimer()
		local ready = false
		repeat
			RequestImapCreator()
			local i <const> = GetInteriorAtCoords(-561.8157, -3780.966, 239.0805)
			ready = i ~= 0 and IsValidInterior(i) == 1 and IsInteriorReady(i) == 1
			if not ready then Wait(250) end
		until ready or GetGameTimer() - t > 20000
		if not ready then
			print("^1[vorp_character]^7 creator interior never streamed - the creator will open on open ground")
		end
	end

	-- with no anim scene our own ped stands in front of the camera; hide it
	if custom or not Config.Creator.useIntroAnimScene then
		local p <const> = PlayerPedId()
		SetEntityVisible(p, false)
		FreezeEntityPosition(p, true)
		SetEntityInvincible(p, true)
	end

	local cam = SetupCameraCharacterCreationSelect()
	local animscene = -1
	local peds = {}

	-- the intro anim scene is choreographed for the RDO area
	local usingAnimScene = Config.Creator.useIntroAnimScene and not custom
	if usingAnimScene then
		local ls <const> = GetGameTimer()
		repeat Wait(500) until not loadingScene or GetGameTimer() - ls > 10000

		-- guarded: upstream waits forever, so a failure falls back to the selection peds
		local ok <const> = pcall(function()
			animscene, peds = SetupAnimscene()
			LoadAnimScene(animscene)

			local a <const> = GetGameTimer()
			local ready = false
			repeat
				ready = Citizen.InvokeNative(0x477122B8D05E7968, animscene) and true or false
				if not ready then Wait(50) end
			until ready or GetGameTimer() - a > 15000

			if not ready then error("intro anim scene never loaded") end
			StartAnimScene(animscene)
		end)

		if not ok then
			print("^1[vorp_character]^7 intro anim scene failed - falling back to the gender peds")
			animscene = -1
			usingAnimScene = false
			-- without the anim scene our ped stands between the camera and the two peds
			local p <const> = PlayerPedId()
			SetEntityVisible(p, false)
			FreezeEntityPosition(p, true)
			SetEntityInvincible(p, true)
			peds = SelectionPeds()
		end
	else
		peds = SelectionPeds()
	end

	DoScreenFadeIn(3000)
	-- BOUNDED: pup-loading drives fades too, and a fade that never lands hung this.
	local fi <const> = GetGameTimer()
	repeat Wait(50) until IsScreenFadedIn() or GetGameTimer() - fi > 4000

	if usingAnimScene then
		-- BOUNDED, like every other wait in here
		local ap <const> = GetGameTimer()
		repeat Wait(50) until Citizen.InvokeNative(0xCBFC7725DE6CE2E0, animscene)
			or GetGameTimer() - ap > 5000
	end

	if custom then
		local c <const> = CreatorSceneGet()
		local v <const> = CreatorSceneCam()
		SetCamParams(cam, vec3(v.x, v.y, v.z), vec3(v.rotx, v.roty, v.rotz),
			tonumber(c.fovIntro) or 45.0, 0, 1, 1, 2, 1, 1)
	else
		SetCamParams(cam, vec3(-562.15, -3776.22, 239.11), vec3(-4.71, 0.0, -93.14), 45.0, 0, 1, 1, 2, 1, 1)
	end

	Wait(1000)
	SetCamFocusDistance(cam, 4.0)

	local char = 1

	-- GENDER IS A MENU ROW (Config.Creator.genderInMenu)
	if Config.Creator.genderInMenu ~= false then
		UiFeedClearChannel(3, true, false)
		for _, p in pairs(peds) do
			if p and p ~= 0 and DoesEntityExist(p) then SetEntityVisible(p, false) end
		end
		if custom then
			local c <const> = CreatorSceneGet()
			local v <const> = CreatorSceneCam()
			SetCamParams(cam, vec3(v.x, v.y, v.z), vec3(v.rotx, v.roty, v.rotz),
				tonumber(c.fovEdit) or 30.0, 0, 1, 1, 2, 1, 1)
		end
		-- NOT followed by RegisterGenderPrompt(): CreatePlayerModel already registers the prompts and then enables them
		CreatePlayerModel("mp_male", peds)
		return
	end

	Core.NotifyObjective('~INPUT_CREATOR_MENU_TOGGLE~' .. T.Other.GenderChoice .. '~INPUT_CREATOR_ACCEPT~', -1)

	while true do
		if IsControlJustPressed(0, `INPUT_CREATOR_MENU_TOGGLE`) then
			char = (char + 1) % 2
			local view = custom and CreatorSceneView(char + 1) or Config.Intro.views[char + 1]
			if view then
				SetCamParams(cam, view.pos.x, view.pos.y, view.pos.z, view.rot.x, view.rot.y, view.rot.z, view.fov, 1200, 1, 1, 2, 1, 1)
				SetCamFocusDistance(cam, 4.0)

				local transEnd = false
				SetTimeout(1200, function()
					transEnd = true
				end)

				while not transEnd do
					Wait(0)
				end
			end

			local sound = char == 1 and "gender_right" or "gender_left"
			PlaySoundFrontend(sound, "RDRO_Character_Creator_Sounds", true, 0);
		end

		if IsControlJustPressed(0, `INPUT_CREATOR_ACCEPT`) then
			PlaySoundFrontend("SELECT", "RDRO_Character_Creator_Sounds", true, 0);
			break
		end

		Wait(0)
	end

	UiFeedClearChannel(3, true, false)
	local ped = peds[char + 1]
	local gender = IsPedMale(ped) and "Male" or "Female"



	if usingAnimScene then
		Citizen.InvokeNative(0xAB5E7CAB074D6B84, animscene, ("Pl_Start_to_Edit_%s"):format(gender))
		-- BOUNDED: the walk-to-edit phase must not be able to hang the creator
		local pe <const> = GetGameTimer()
		while not (Citizen.InvokeNative(0x3FBC3F51BF12DFBF, animscene, Citizen.ResultAsFloat()) > 0.2) do
			Citizen.Wait(0)
			if GetGameTimer() - pe > 15000 then break end
		end
	elseif custom then
		-- no walk-to-mark: the peds already stand ON the mark
		local px, py, pz, ph = CreatorSceneSpawn()
		FreezeEntityPosition(ped, false) -- SelectionPeds froze them so they could not fall
		ClearPedTasksImmediately(ped)
		SetEntityCoords(ped, px, py, pz, true, true, true, false)
		SetEntityHeading(ped, ph)
		TaskStandStill(ped, -1)
		local guard = 0
		while guard < 60 do
			PointCamAtEntity(cam, ped, 0.0, 0.0, 0.0, true)
			Wait(0)
			guard = guard + 1
		end
	else
		local mx, my, mz, mh <const> = -558.79, -3780.17, 238.59, 183.2
		FreezeEntityPosition(ped, false) -- SelectionPeds froze them, and this path walks
		ClearPedTasksImmediately(ped)
		-- NativeOn, or the request never ran and the walk had no floor to cross
		if not NativeOn(HasCollisionLoadedAroundEntity(ped)) then RequestCollisionAtCoord(mx, my, mz) end
		TaskGoStraightToCoord(ped, mx, my, mz, 1.0, -1, mh, 0)
		-- bounded: with no floor the walk never reports finished and this spun forever
		local w <const> = GetGameTimer()
		while GetScriptTaskStatus(ped, 0x7D8F4411, true) ~= 8 do
			PointCamAtEntity(cam, ped, 0.0, 0.0, 0.0, true)
			Wait(0)
			if GetGameTimer() - w > 8000 then
				print("^3[vorp_character]^7 creator walk never finished - placing the ped on the mark")
				ClearPedTasksImmediately(ped)
				SetEntityCoords(ped, mx, my, mz, true, true, true, false)
				SetEntityHeading(ped, mh)
				TaskStandStill(ped, -1)
				break
			end
		end
	end

	if custom then
		local c <const> = CreatorSceneGet()
		local v <const> = CreatorSceneCam()
		SetCamParams(cam, vec3(v.x, v.y, v.z), vec3(v.rotx, v.roty, v.rotz),
			tonumber(c.fovEdit) or 30.0, 0, 1, 1, 2, 1, 1)
	else
		SetCamParams(cam, vec3(-561.82, -3780.97, 239.08), vec3(-4.21, 0.0, -87.88), 30.0, 0, 1, 1, 2, 1, 1)
	end
	N_0x11f32bb61b756732(cam, 1.0)


	-- usingAnimScene, not the config: animscene is -1 when the scene never loaded
	if usingAnimScene then
		local ae <const> = GetGameTimer()
		while not (N_0xd8254cb2c586412b(animscene) == 1) do
			Citizen.Wait(0)
			if GetGameTimer() - ae > 15000 then break end
		end
		Citizen.InvokeNative(0x84EEDB2C6E650000, animscene) -- delete animscene
	end
	local model = gender == "Male" and "mp_male" or "mp_female"
	-- same as the menu path above: CreatePlayerModel registers AND enables the prompts
	CreatePlayerModel(model, peds)
end


local function setInteriors(male)
	-- the mp_char_*_mirror sets belong to the RDO creator interior and do not exist anywhere else
	if CreatorSceneActive and CreatorSceneActive() then return end

	local interiorAtCoords = GetInteriorAtCoords(-561.8157, -3780.966, 239.0805)

	if IsValidInterior(interiorAtCoords) ~= 1 then return end
	if IsInteriorReady(interiorAtCoords) ~= 1 then return end

	-- IsInteriorEntitySetActive answers with a number, so NativeOn and not a bare test
	local function setMirror(name, on)
		if IsInteriorEntitySetValid(interiorAtCoords, name) ~= 1 then return end
		local active <const> = NativeOn(IsInteriorEntitySetActive(interiorAtCoords, name))
		if on and not active then
			ActivateInteriorEntitySet(interiorAtCoords, name, 0)
		elseif not on and active then
			DeactivateInteriorEntitySet(interiorAtCoords, name, true)
		end
	end

	setMirror("mp_char_male_mirror", male)
	setMirror("mp_char_female_mirror", not male)
end


RegisterNetEvent("vorpcharacter:startCharacterCreator")
AddEventHandler("vorpcharacter:startCharacterCreator", function()
	AnimpostfxStopAll() -- clear any screen effect still running

	-- hide the world HUD while building a character - money, ID
	TriggerEvent("vorp:showUi", false)
	DisplayRadar(false)

	pcall(function() exports.weathersync:setSyncEnabled(false) end) -- weathersync is optional

	-- pin the sky so the creator is not lit by live weather
	pcall(function()
		exports.weathersync:setMyWeather(Config.CreatorWeather or 'sunny', 0, false)
	end)

	ShutdownLoadingScreen()

	-- nothing faded out, so the player watched the room stream in piece by piece
	DoScreenFadeOut(500)
	local fo <const> = GetGameTimer()
	repeat Wait(50) until IsScreenFadedOut() or GetGameTimer() - fo > 2000

	-- no fade watchdog: Setup and CreatePlayerModel each end on a bounded fade in
	ShowBusyspinnerWithText(T.Other.spinnertext2)
	Wait(500)
	InCharacterCreator = true
	Wait(2000)

	-- StartPlayerTeleport silently does nothing on the half-spawned ped of a new account
	local t0 <const> = GetGameTimer()
	local ready = false
	repeat
		Wait(100)
		local ped <const> = PlayerPedId()
		ready = ped and ped ~= 0 and DoesEntityExist(ped)
			and NetworkIsPlayerActive(PlayerId())
			and not IsPlayerTeleportActive()
	until ready or GetGameTimer() - t0 > 20000
	if not ready then
		print("^1[vorp_character]^7 player ped never settled before the creator - continuing anyway")
	end

	BusyspinnerOff()
	Setup()
end)

function RegisterGenderPrompt()
	local C = Config.Keys
	-- a nil label makes VarString throw, which would abort this function part-way and leave some prompts unregistered
	local L <const> = T.PromptLabels or {}
	local str = L.promptUpDownCam or "Camera Up / Down"
	down = UiPromptRegisterBegin()
	UiPromptSetControlAction(down, C.prompt_camera_ws.key)
	UiPromptSetControlAction(down, C.prompt_camera_ws.key2)
	str = VarString(10, 'LITERAL_STRING', str)
	UiPromptSetText(down, str)
	UiPromptSetEnabled(down, false)
	UiPromptSetVisible(down, false)
	UiPromptSetStandardMode(down, true)
	UiPromptSetGroup(down, PromptGroup2, 0)
	UiPromptRegisterEnd(down)


	str = L.promptrotateCam or "Rotate Character"
	right = UiPromptRegisterBegin()
	UiPromptSetControlAction(right, 0x7065027D)
	UiPromptSetControlAction(right, 0xB4E465B4)
	str = VarString(10, 'LITERAL_STRING', str)
	UiPromptSetText(right, str)
	UiPromptSetEnabled(right, false)
	UiPromptSetVisible(right, false)
	UiPromptSetStandardMode(right, true)
	UiPromptSetGroup(right, PromptGroup2, 0)
	UiPromptRegisterEnd(right)

	str = L.promptzoomCam or "Zoom In / Out"
	zoomout = UiPromptRegisterBegin()
	-- pup: zoom is on keys - arrows, set in Config.Keys
	UiPromptSetControlAction(zoomout, C.prompt_camera_zoom.key)
	UiPromptSetControlAction(zoomout, C.prompt_camera_zoom.key2)
	str = VarString(10, 'LITERAL_STRING', str)
	UiPromptSetText(zoomout, str)
	UiPromptSetEnabled(zoomout, true)
	UiPromptSetVisible(zoomout, true)
	UiPromptSetStandardMode(zoomout, true)
	UiPromptSetGroup(zoomout, PromptGroup2, 0)
	UiPromptRegisterEnd(zoomout)
end

local function SetUpCameraCharacterMovement(x, y, z, heading, fov)
	DestroyAllCams(true)
	local cam <const> = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", x, y, z, -4.2146, -0.0007, heading, fov, true, 0)
	SetCamActive(cam, true)
	RenderScriptCams(true, false, 3000, true, false, 0)
	ShakeCam(cam, "HAND_SHAKE", 0.04)
	return cam
end


local function RotationToDirection(rot)
	local pitch <const> = math.rad(rot.x)
	local yaw <const>   = math.rad(rot.z)
	local cp <const>    = math.cos(pitch)
	return vector3(-math.sin(yaw) * cp, math.cos(yaw) * cp, math.sin(pitch))
end

-- gameplay keys blocked every frame while the creator / shop camera is up
local BLOCKED_INPUTS = {
	`INPUT_ATTACK`, `INPUT_AIM`, `INPUT_JUMP`, `INPUT_MELEE_ATTACK`, `INPUT_RELOAD`,
	`INPUT_ENTER`, `INPUT_WHISTLE`, `INPUT_COVER`, `INPUT_QUICK_USE_ITEM`,
	`INPUT_OPEN_JOURNAL`, `INPUT_OPEN_SATCHEL_MENU`, `INPUT_OPEN_WHEEL_MENU`,
	`INPUT_OPEN_EMOTE_WHEEL`, `INPUT_MAP`, `INPUT_PLAYER_MENU`,
	`INPUT_SELECT_NEXT_WEAPON`, `INPUT_SELECT_PREV_WEAPON`, `INPUT_INTERACT_ANIMAL`,
	`INPUT_DUCK`, `INPUT_SPRINT`, `INPUT_MOVE_UP_ONLY`, `INPUT_MOVE_DOWN_ONLY`,
	`INPUT_MOVE_LEFT_ONLY`, `INPUT_MOVE_RIGHT_ONLY`, `INPUT_LOOK_BEHIND`,
	-- the axes are what actually walk the ped; the _ONLY keys above do not cover them
	`INPUT_MOVE_LR`, `INPUT_MOVE_UD`,
	`INPUT_TOGGLE_HOLSTER`, `INPUT_OPEN_SATCHEL_FILTER_MENU`,
}

-- the creator's own camera keys are the SAME physical keys the game uses to move, sprint and crouch
local function cameraControls()
	local k <const> = Config and Config.Keys
	if not k then return {} end
	local out = {}
	for _, set in ipairs({ k.prompt_camera_ws, k.prompt_camera_rotate, k.prompt_camera_zoom }) do
		if set then
			if set.key then out[#out + 1] = set.key end
			if set.key2 then out[#out + 1] = set.key2 end
		end
	end
	return out
end

function BlockGameplayKeys()
	for _, c in ipairs(BLOCKED_INPUTS) do DisableControlAction(0, c, true) end
	for _, c in ipairs(cameraControls()) do DisableControlAction(0, c, true) end
end

-- camera framings for the face page
local camForward, camVertical = 0, 0
local camLimits = nil -- set by StartPrompts once it knows this scene's ranges

-- presets are defined by WHAT THEY POINT AT, not by camera offsets
local CAM_PRESETS <const> = {
	head  = { target = 1.62, dist = 1.15 },
	torso = { target = 1.15, dist = 2.05 },
	full  = { target = 1.00, dist = 3.40 },
}

local lastCamPreset = nil

local function pedScale()
	local s = tonumber(PlayerSkin and PlayerSkin.Scale)
	if not s or s <= 0 then s = 1.0 end
	return s
end

local function clampTo(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

function SetCreatorCamPreset(name)
	local key <const> = tostring(name):lower()
	local p <const> = CAM_PRESETS[key]
	if not p or not camLimits then return false end
	lastCamPreset = key

	-- measured by StartPrompts, not Config.Creator.scene, which describes only the custom scene
	local restDist <const> = camLimits.restDist or 2.40
	local restHeight <const> = camLimits.restHeight or 1.20

	-- a short character's head is lower, so scale the target with them
	local target <const> = p.target * pedScale()

	-- level with the target: vertical offset is the difference between where we want to be and where the camera rests
	camVertical = clampTo(target - restHeight, camLimits.minV, camLimits.maxV)
	-- positive forward moves TOWARD the ped, so closing to `dist` is rest - dist
	camForward = clampTo(restDist - p.dist, camLimits.minF, camLimits.maxF)
	return true
end

-- re-aim after the character's height changes, so the framing follows them
function RefreshCreatorCamPreset()
	if not lastCamPreset then return false end
	return SetCreatorCamPreset(lastCamPreset)
end

function StartPrompts(value)
	-- with a creator scene configured, the editing camera is anchored to it rather than to the RDO area
	local sc = (not value) and CreatorSceneActive and CreatorSceneActive()
		and { CreatorSceneCam(), CreatorSceneLimits() } or nil

	local baseX <const>        = value and value.Position.x or (sc and sc[1].x) or -561.8157
	local baseY <const>        = value and value.Position.y or (sc and sc[1].y) or -3780.966
	local baseZ <const>        = value and value.Position.z or (sc and sc[1].z) or 239.0805
	local heading              = value and value.Heading or (sc and sc[1].rotz) or -87.8802
	local maxUp <const>        = value and value.MaxUp or (sc and sc[2].maxUp) or 239.55
	local maxDown <const>      = value and value.MaxDown or (sc and sc[2].maxDown) or 238.0
	local zoomInRange <const>  = value and value.ZoomInRange or (sc and sc[2].zoomIn) or 2.5
	local zoomOutRange <const> = value and value.ZoomOutRange or (sc and sc[2].zoomOut) or 1.5
	local zoomStep <const>     = 0.05
	local vertStep <const>     = 0.01
	-- not const: pup_clothing's fitting calls DestroyAllCams
	local cam                  = SetUpCameraCharacterMovement(baseX, baseY, baseZ, heading, 30.0)
	local rot <const>          = GetCamRot(cam, 2)
	local dir <const>          = RotationToDirection(rot)
	local base <const>         = vector3(baseX, baseY, baseZ)
	local minForward <const>   = -zoomOutRange
	local minVertical <const>  = maxDown - baseZ
	local maxVertical <const>  = maxUp - baseZ

	-- measured, not configured: the RDO mark and a custom scene rest at different distances
	local pc <const> = GetEntityCoords(PlayerPedId())
	local dx, dy = baseX - pc.x, baseY - pc.y
	local restDist = math.sqrt(dx * dx + dy * dy)
	local restHeight = baseZ - pc.z
	-- a ped still falling or not yet placed would poison both
	if restDist < 0.8 or restDist > 6.0 then restDist = 2.40 end
	if restHeight < 0.5 or restHeight > 3.0 then restHeight = 1.45 end

	-- zoom stops short of the character instead of ending up inside them
	local maxForward <const> = math.min(zoomInRange, math.max(0.0, restDist - 0.90))

	-- offsets are file-scoped so a camera preset can move them; reset per scene
	camForward, camVertical = 0, 0
	camLimits = {
		minF = minForward, maxF = maxForward,
		minV = minVertical, maxV = maxVertical,
		restDist = restDist, restHeight = restHeight,
	}

	local TotalToPay           = ""
	local wasPaused            = false
	local lastStandStill       = 0

	while true do
		Wait(0)

		-- the clothing fitting owns the screen while it is open
		if CreatorFittingActive then
			wasPaused = true
			goto continue
		end

		if wasPaused then
			wasPaused = false
			-- the wardrobe's teardown runs DestroyAllCams(true), which takes OUR camera with it - rebuild it and restore the framing
			cam = SetUpCameraCharacterMovement(baseX, baseY, baseZ, heading, 30.0)
			SetCamActive(cam, true)
			RenderScriptCams(true, false, 0, true, false, 0)
		end

		BlockGameplayKeys()

		-- TaskStandStill, not a per-frame motion state; a stray step cancels the task
		if (IsInCharCreation or IsInClothingStore) and GetGameTimer() - lastStandStill > 750 then
			lastStandStill = GetGameTimer()
			TaskStandStill(PlayerPedId(), -1)
		end

		if IsInClothingStore and ShopType ~= "secondchance" then
			TotalToPay = T.Other.total .. GetCurrentAmmountToPay() .. "~q~ "
		end

		local label <const> = VarString(10, "LITERAL_STRING", TotalToPay .. (T.PromptLabels.CamAdjustments or "Camera"))
		-- NOTE: this group is registered, enabled and driven every frame - the handles are valid and IsInCharCreation is true
		UiPromptSetActiveGroupThisFrame(PromptGroup2, label, 0, 0, 0, 0)

		if IsDisabledControlPressed(2, Config.Keys.prompt_camera_rotate.key) then
			heading = heading - 1.5
			SetPedDesiredHeading(PlayerPedId(), heading)
		end

		if IsDisabledControlPressed(2, Config.Keys.prompt_camera_rotate.key2) then
			heading = heading + 1.5
			SetPedDesiredHeading(PlayerPedId(), heading)
		end

		if IsDisabledControlPressed(2, Config.Keys.prompt_camera_ws.key) then
			camVertical = math.min(camVertical + vertStep, maxVertical)
		end
		if IsDisabledControlPressed(2, Config.Keys.prompt_camera_ws.key2) then
			camVertical = math.max(camVertical - vertStep, minVertical)
		end

		-- pup: zoom on the arrow keys (Config.Keys.prompt_camera_zoom)
		if IsDisabledControlPressed(2, Config.Keys.prompt_camera_zoom.key) then
			camForward = math.min(camForward + zoomStep, maxForward)
		end
		if IsDisabledControlPressed(2, Config.Keys.prompt_camera_zoom.key2) then
			camForward = math.max(camForward - zoomStep, minForward)
		end

		local newPos = base + dir * camForward + vector3(0, 0, camVertical)
		SetCamCoord(cam, newPos.x, newPos.y, newPos.z)
		SetCamRot(cam, rot.x, rot.y, rot.z, 2)


		if not IsInCharCreation then
			if not IsInClothingStore then
				break
			end
		else
			if IsCharCreationFinished then
				break
			end
		end

		::continue::
	end

	DeleteAllPrompts()
	repeat Wait(0) until not IsInCharCreation and not IsInClothingStore
	DestroyCam(cam, false)
	RenderScriptCams(false, true, 500, true, true, 0)
end

-- swap the character's gender from the menu
function SwitchCreatorGender(male)
	if not IsInCharCreation then return false end
	local want <const> = male and "mp_male" or "mp_female"
	if GetEntityModel(PlayerPedId()) == joaat(want) then return false end

	local x, y, z, h
	if CreatorSceneActive and CreatorSceneActive() then
		x, y, z, h = CreatorSceneSpawn()
	else
		local c <const> = GetEntityCoords(PlayerPedId())
		x, y, z, h = c.x, c.y, c.z, GetEntityHeading(PlayerPedId())
	end

	isMale = male and true or false
	LoadPlayer(want)
	SetPlayerModel(PlayerId(), joaat(want), false)
	SetModelAsNoLongerNeeded(want)

	local ped <const> = PlayerPedId()
	SetEntityCoordsAndHeading(ped, x, y, z, h, true, false, true)
	-- six args as in CreatePlayerModel: the rebuild that makes the swapped model draw
	Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
	DefaultPedSetup(ped, isMale)
	Wait(300)
	SetEntityVisible(ped, true)
	SetEntityInvincible(ped, true)

	-- SetPlayerModel built a NEW ped, and the holds that keep the character standing still live in CreatePlayerModel
	TaskStandStill(ped, -1)
	ForcePedMotionState(ped, `MotionState_DoNothing`, false, 0, false)
	SetFacialIdleAnimOverride(ped, "mood_normal_zoom", "FACE_HUMAN@GEN_MALE@BASE")
	return true
end

function DefaultPedSetup(ped, male)
	local gender                = male and "M" or "F"
	HeadIndexTracker            = male and 8 or 1
	PlayerSkin.Eyes             = joaat(("CLOTHING_ITEM_%s_EYES_001_TINT_014"):format(gender))
	PlayerSkin.BodyType         = joaat(("CLOTHING_ITEM_%s_BODIES_UPPER_001_V_001"):format(gender))
	PlayerSkin.Body             = PlayerSkin.BodyType
	PlayerSkin.HeadType         = joaat(("CLOTHING_ITEM_%s_HEAD_00%d_V_001"):format(gender, HeadIndexTracker))
	PlayerSkin.LegsType         = joaat(("CLOTHING_ITEM_%s_BODIES_LOWER_001_V_001"):format(gender))
	PlayerSkin.albedo           = joaat(("MP_HEAD_%sR1_SC08_C0_000_AB"):format(gender))
	PlayerClothing.Teeth.comp   = joaat(("CLOTHING_ITEM_%s_TEETH_000"):format(gender))
	PlayerClothing.Gunbelt.comp = joaat(("CLOTHING_ITEM_%s_GUNBELT_000_TINT_001"):format(gender))
	PlayerSkin.Hair             = joaat(("CLOTHING_ITEM_%s_HAIR_001_BLONDE"):format(gender))

	SkinColorTracker            = 1

	if not male then
		IsPedReadyToRender()
		EquipMetaPedOutfitPreset(ped, 7)
		UpdatePedVariation()
	end

	if male then
		-- work around to fix skin on char creator
		IsPedReadyToRender()
		UpdateShopItemWearableState(-457866027, -425834297) -- fixes skin
		ApplyShopItemToPed(-218859683)                 -- might be boots cant remember
		ApplyShopItemToPed(PlayerClothing.Gunbelt.comp)
		UpdateShopItemWearableState(-218859683, -2081918609) -- fixes skin
		UpdatePedVariation()
	end

	PlayerSkin.sex                 = male and "mp_male" or "mp_female"
	PlayerSkin.eyebrows_visibility = 1
	PlayerSkin.eyebrows_tx_id      = 1
	PlayerSkin.eyebrows_opacity    = 1.0
	PlayerSkin.eyebrows_color      = 0x3F6E70FF

	ApplyOverlay("eyebrows", 1, 1, 1, 0, 0, 1.0, 0, 1, 0x3F6E70FF, 0, 0, 1, 1.0, PlayerSkin.albedo)

	IsPedReadyToRender()
	EquipMetaPedOutfitPreset(ped, tonumber(Config.Creator.undressPreset) or 3)
	UpdatePedVariation()

	-- this preset IS the undressed state, so the Clothing row must open saying Off
	if Config.Creator.startUndressed ~= false then CreatorClothesOn = false end
end

-- NIL-SAFE
local function setPromptState(p, boolean)
	-- NOT ipairs over a list: `up` is nil, and ipairs stops at the first hole, so a list would skip every prompt after it
	if not p then return end
	UiPromptSetEnabled(p, boolean)
	UiPromptSetVisible(p, boolean)
end

function EnableCharCreationPrompts(boolean)
	setPromptState(down, boolean)
	setPromptState(right, boolean)
	setPromptState(zoomout, boolean)
end

function DeleteAllPrompts()
	local function del(p)
		if p then UiPromptDelete(p) end
	end
	del(down); del(right); del(zoomout)
	down, right, zoomout = nil, nil, nil
end

function CreatePlayerModel(model, peds)
	local Gender = model == "mp_male" and "male" or "female"
	isMale = model == "mp_male" and true or false
	DoScreenFadeOut(10)
	local fo <const> = GetGameTimer()
	repeat Wait(0) until IsScreenFadedOut() or GetGameTimer() - fo > 5000

	ShowBusyspinnerWithText(T.Other.spinnertext2)

	-- DeleteEntity alone is not enough
	for _, value in pairs(peds) do
		if value and value ~= 0 and DoesEntityExist(value) then
			SetEntityAsMissionEntity(value, true, true)
			DeleteEntity(value)
		end
	end
	if ClearSelectionPeds then ClearSelectionPeds() end

	-- SetPlayerModel builds where the old ped stands, so unfreeze it first
	FreezeEntityPosition(PlayerPedId(), false)

	-- the editing mark
	local markX, markY, markZ, markH = -558.5060302734375, -3781.050048828125, 237.60, 93.2
	if CreatorSceneActive and CreatorSceneActive() then
		markX, markY, markZ, markH = CreatorSceneSpawn()
	end
	-- SetPlayerModel builds the new ped where this one stands, so put it on the mark first
	SetEntityCoords(PlayerPedId(), markX, markY, markZ, true, true, true, false)
	SetEntityHeading(PlayerPedId(), markH)
	LoadPlayer(model)
	SetPlayerModel(PlayerId(), joaat(model), false)
	SetModelAsNoLongerNeeded(model)
	-- _UPDATE_PED_VARIATION takes six args; one-arg UpdatePedVariation never draws
	Citizen.InvokeNative(0xCC8CA3E88256E58F, PlayerPedId(), false, true, true, true, false)

	-- collision at the mark: Setup only requests it at the selection spawn 6m away
	local cw <const> = GetGameTimer()
	while not NativeOn(HasCollisionLoadedAroundEntity(PlayerPedId())) do
		RequestCollisionAtCoord(markX, markY, markZ)
		Wait(0)
		if GetGameTimer() - cw > 8000 then
			print("^3[vorp_character]^7 no collision at the editing mark - the character may stand low")
			break
		end
	end

	-- SetEntityCoords, never NoOffset: NoOffset places by the root and buries the ped
	SetEntityCoords(PlayerPedId(), markX, markY, markZ, true, true, true, false)
	SetEntityHeading(PlayerPedId(), markH)
	TaskStandStill(PlayerPedId(), -1)

	RenderScriptCams(false, true, 3000, true, true, 0)
	Wait(1000)
	DefaultPedSetup(PlayerPedId(), isMale)


	Wait(1000)
	IsInCharCreation = true
	IsCharCreationFinished = false
	RegisterGenderPrompt()
	CreateThread(function()
		-- pup-ui InkMenu takes no NUI focus, so the creator camera controls (WASD / zoom) reach the game directly
		StartPrompts()
	end)
	EnableCharCreationPrompts(true)
	Clothing = OrganiseClothingData(Gender)
	RemoveTagFromMetaPed(Config.ComponentCategories.Teeth)
	UpdatePedVariation(PlayerPedId())
	SetEntityVisible(PlayerPedId(), true)
	SetEntityInvincible(PlayerPedId(), true)
	SetPedScale(PlayerPedId(), 1.0)
	RenderScriptCams(true, true, 1000, true, true, 0)
	CreateThread(function()
		-- the fill light defaults to the RDO creator area
		local lx, ly, lz = -560.1646, -3782.066, 238.5975
		if CreatorSceneActive and CreatorSceneActive() then
			local cam <const> = CreatorSceneCam(1.30, 1.45)
			lx, ly, lz = cam.x, cam.y, cam.z
		end
		local c <const> = Config.Creator.scene or {}
		local range <const> = tonumber(c.lightRange) or 7.0
		local power <const> = tonumber(c.lightPower) or 30.0

		-- pup_clothing reads this and keeps the creator's camera instead of its own
		pcall(function() LocalPlayer.state:set('pupInCreator', true, false) end)

		while IsInCharCreation do
			Wait(0)
			local me <const> = PlayerPedId()
			FreezeEntityPosition(me, false)

			-- Setup() hid this ped; the single SetEntityVisible above loses the race
			if not IsEntityVisible(me) then
				SetEntityVisible(me, true)
			end

			DrawLightWithRange(lx, ly, lz, 250, 250, 250, range, power)
		end

		-- loop ended, so creation is over: hand the camera back to pup_clothing
		pcall(function() LocalPlayer.state:set('pupInCreator', false, false) end)
	end)
	Wait(2000)
	ApplyDefaultClothing()
	SetFacialIdleAnimOverride(PlayerPedId(), "mood_normal_zoom", "FACE_HUMAN@GEN_MALE@BASE")
	ForcePedMotionState(PlayerPedId(), `MotionState_DoNothing`, false, 0, false)
	PrepareCreatorMusic()
	setInteriors(isMale)
	OpenCharCreationMenu(Clothing, false)
	BusyspinnerOff()
	DoScreenFadeIn(3000)
	local fi2 <const> = GetGameTimer()
	repeat Wait(0) until IsScreenFadedIn() or GetGameTimer() - fi2 > 8000
end

-- /pedwhere - creator diagnostic: ped position, floor, camera, visibility
RegisterCommand('pedwhere', function()
	local ped = PlayerPedId()
	local pc = GetEntityCoords(ped)
	local model = GetEntityModel(ped)
	print('^3[pedwhere]^7 ---------------------------------------------')
	print(('^3[pedwhere]^7 ped handle=%s exists=%s visible=%s human=%s'):format(
		tostring(ped), tostring(DoesEntityExist(ped)), tostring(IsEntityVisible(ped)), tostring(IsPedHuman(ped))))
	print(('^3[pedwhere]^7 model=%s  (mp_male=%s mp_female=%s)'):format(
		tostring(model), tostring(joaat('mp_male')), tostring(joaat('mp_female'))))
	print(('^3[pedwhere]^7 ped at   %.2f %.2f %.2f'):format(pc.x, pc.y, pc.z))

	-- the creator mark CreatePlayerModel puts them on
	local mx, my, mz = -558.506, -3781.05, 237.60
	print(('^3[pedwhere]^7 mark at  %.2f %.2f %.2f   distance=%.2fm'):format(
		mx, my, mz, #(pc - vector3(mx, my, mz))))

	-- GetEntityCoords reads the centre, so a correctly standing ped reads about +0.9
	local gok, gz = GetGroundZFor_3dCoord(mx, my, mz + 2.0, false)
	print(('^3[pedwhere]^7 ground  found=%s z=%.2f   centre is %.2fm above it (want ~0.90)   collision=%s'):format(
		tostring(gok), gok and gz or -1.0, gok and (pc.z - gz) or -1.0,
		tostring(HasCollisionLoadedAroundEntity(ped))))

	local cam = GetRenderingCam()
	if cam and cam ~= 0 and cam ~= -1 then
		local cc = GetCamCoord(cam)
		print(('^3[pedwhere]^7 camera at %.2f %.2f %.2f  fov=%.1f  distance to ped=%.2fm'):format(
			cc.x, cc.y, cc.z, GetCamFov(cam), #(cc - pc)))
	else
		print('^3[pedwhere]^7 no scripted camera rendering (gameplay cam)')
	end

	-- IsEntityPositionFrozen does NOT exist in RedM - calling it aborted this command
	local interior = GetInteriorFromEntity(ped)
	print(('^3[pedwhere]^7 interior=%s  IsInCharCreation=%s  InCharacterCreator=%s'):format(
		tostring(interior), tostring(IsInCharCreation), tostring(InCharacterCreator)))
	print('^3[pedwhere]^7 ---------------------------------------------')
end, false)
