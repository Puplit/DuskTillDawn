SelectionActive = false

-- server integration shims

-- vorp_inputs:advancedInput replacement backed by pup-ui's OpenInput; blocks the same way
function AdvancedInput(spec)
	spec = type(spec) == 'table' and spec or {}
	local attr = type(spec.attributes) == 'table' and spec.attributes or {}
	local isNumber = attr.type == 'number'

	local p = promise.new()
	local owner = 'pup_doorlocks:input:' .. tostring(attr.inputHeader or 'input')
	local ev
	ev = AddEventHandler('pup-ui:client:inputDone', function(o, values)
		if o ~= owner then return end
		RemoveEventHandler(ev)
		p:resolve(values)
	end)

	exports['pup-ui']:OpenInput({
		owner = owner,
		title = tostring(attr.inputHeader or ''),
		submit = spec.button,
		fields = { {
			label = tostring(attr.inputHeader or ''),
			type = isNumber and 'number' or 'text',
			default = attr.value,
			placeholder = spec.placeholder,
		} },
	})

	local values = Citizen.Await(p)
	if values == nil then return nil end -- cancelled
	local v = values[1]
	if v == nil then return '' end
	return tostring(v)
end

-- lockpicking minigame: the pin game from the `lockpick` resource while it runs (Config.Lockpicking.pinGame),
-- otherwise pup-minigames. cb(true) won, cb(false) lost, cb(nil) the game never started
--- @param cb function
function LockpickGame(cb)
	local L <const> = Config.Lockpicking or {}

	if L.pinGame ~= false and GetResourceState('lockpick') == 'started' then
		TriggerEvent('vorp:TipRight', L.pinHint or 'Turn the pick to find the sweet spot, then turn the lock', 4000)
		Citizen.Wait(2000) -- let them read it before the game appears
		local ok, res = pcall(function() return exports['lockpick']:lockpick() end)
		if not ok then
			print(('^1[doorlocks]^7 lockpick pin game failed to start: %s'):format(tostring(res)))
			cb(nil)
			return
		end
		cb(res == true)
		return
	end

	local hintText = L.hint or 'Turn the dial slowly - stop when you feel the lock give'
	TriggerEvent('vorp:TipRight', hintText, 4000)
	Citizen.Wait(2000) -- let them read it before the game appears

	-- safe_crack answers true/false, the skill games 'perfect'/'success'/'failed'
	local function done(result)
		cb(result == true or result == 'success' or result == 'perfect')
	end

	local ok, err = pcall(function()
		if L.game == 'skill_bar' then
			local sb <const> = L.skillBar or {}
			exports['pup-minigames']:skill_bar({
				style = 'default',
				icon = 'fa-solid fa-key',
				orientation = 1,
				area_size = tonumber(sb.areaSize) or 20,
				perfect_area_size = tonumber(sb.perfectAreaSize) or 5,
				speed = tonumber(sb.speed) or 0.5,
				moving_icon = false,
				hint = false, -- the tip above is the hint
			}, done)
		elseif L.game == 'skill_circle' then
			local sc <const> = L.skillCircle or {}
			exports['pup-minigames']:skill_circle({
				style = 'default',
				area_size = tonumber(sc.areaSize) or 4,
				speed = tonumber(sc.speed) or 0.02,
			}, done)
		else
			local difficulty = math.floor(tonumber(L.difficultyLocks) or 3)
			if difficulty < 1 then difficulty = 1 end
			if difficulty > 5 then difficulty = 5 end -- the bundled game scuffs above 5

			exports['pup-minigames']:safe_crack({
				style = 'default',
				difficulty = difficulty,
				attempts = tonumber(L.attempts) or 3,
			}, done)
		end
	end)

	if not ok then
		print(('^1[doorlocks]^7 lockpick minigame failed to start: %s'):format(tostring(err)))
		cb(nil)
	end
end

--- Animation that plays when player lockpicks a door
--- @param coords vector3
function LockpickAnimation(coords)
	local dict = 'mech_doors@locked@door_knob@generic@handle_l@hand_l@try_door'
	if not U.LoadDict(dict) then return end

	TaskTurnPedToFaceCoord(U.Cache.Ped, coords.x, coords.y, coords.z, -1)
	Wait(1000)

	TaskPlayAnim(U.Cache.Ped, dict, 'lockpick', 8.0, -8.0, -1, 1, 0, true, false, false)
	RemoveAnimDict(dict)
end

--- lock / unlock / denied click. pup-ui owns the sound.
--- @param kind string
function DoorSound(kind)
	if Config.Integrations.pupUi and Config.Integrations.pupUi.doorSound == false then return end
	pcall(function() exports['pup-ui']:DoorSound(kind) end)
end

-- Draw a blip on the map for a certain radius https://rdr3natives.com/?_0x45F13B7E0A15C880
--- @param blipHash number
--- @param x number
--- @param y number
--- @param z number
--- @param radius number
--- @return number
function BlipAddForRadius(blipHash, x, y, z, radius)
	return Citizen.InvokeNative(0x45f13b7e0a15c880, blipHash, x, y, z, radius)
end

--- Floating key cap on the door. pup-ui draws it, so it matches the server UI.
--- @param coords vector3
--- @param state table { key, text, tone }
--- @return boolean drawn
function DrawDoorMarker(coords, state)
	if not coords then return false end
	local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
	if not onScreen then return false end

	pcall(function()
		exports['pup-ui']:WorldKey({
			x = screenX, y = screenY,
			key = state.key, text = state.text, tone = state.tone,
		})
	end)
	return true
end

function HideDoorMarker()
	pcall(function() exports['pup-ui']:WorldKeyHide() end)
end

--- Calculates the center point of the model
--- @param entity number
--- @param model number | nil
--- @return vector2
function CalculateModelCenterPoint(entity, model)
	-- If the model is not provided or is invalid, get the model from the entity
	if not model or not IsModelValid(model) then
		model = GetEntityModel(entity)
	end

	local minimum, maximum = GetModelDimensions(model)
                            
	local corners = {}
	-- Get the offset of 8 corners of the object in 3D space
	corners[1] = GetOffsetFromEntityInWorldCoords(entity, minimum.x, minimum.y, minimum.z).xy
	corners[2] = GetOffsetFromEntityInWorldCoords(entity, minimum.x, minimum.y, maximum.z).xy
	corners[3] = GetOffsetFromEntityInWorldCoords(entity, minimum.x, maximum.y, maximum.z).xy
	corners[4] = GetOffsetFromEntityInWorldCoords(entity, minimum.x, maximum.y, minimum.z).xy
	corners[5] = GetOffsetFromEntityInWorldCoords(entity, maximum.x, minimum.y, minimum.z).xy
	corners[6] = GetOffsetFromEntityInWorldCoords(entity, maximum.x, minimum.y, maximum.z).xy
	corners[7] = GetOffsetFromEntityInWorldCoords(entity, maximum.x, maximum.y, maximum.z).xy
	corners[8] = GetOffsetFromEntityInWorldCoords(entity, maximum.x, maximum.y, minimum.z).xy

	local center = vec2(0, 0)
	
	for i = 1, 8 do
		center += corners[i]
	end

	return center / 8
end

---Checks if an entity is a door
---@param entity number
---@return number | boolean
function IsDoor(entity)
	if not entity then return false end

	local doorid = DoorEnities[entity]

	if doorid and Doors[doorid] then
		return doorid
	end

	return false
end

--- comment Calculate the direction of a rotation
--- @param rotation vector3
--- @return table
local function RotationToDirection(rotation)
	local adjustedRotation = 
	{ 
		x = (math.pi / 180) * rotation.x, 
		y = (math.pi / 180) * rotation.y, 
		z = (math.pi / 180) * rotation.z 
	}
	local direction = 
	{
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), 
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), 
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

--- Raycasts and shapetests from players cam position to "endpoint" to check if the player is at a valid entity
--- @return boolean
--- @return integer
function RayCastGamePlayCamera()
	local maxDist = 20.0 -- I think 10.0 meters is a good distance
	
	local cameraCoord = GetFinalRenderedCamCoord()
	local direction = RotationToDirection(GetFinalRenderedCamRot(2))
	local endCoords = {
        x = cameraCoord.x + direction.x * maxDist,
        y = cameraCoord.y + direction.y * maxDist,
        z = cameraCoord.z + direction.z * maxDist
    }

	local handle = StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, endCoords.x, endCoords.y, endCoords.z, 511, U.Cache.Ped, 4)
    local _, hit, _, _, _, entityHit = GetShapeTestResultIncludingMaterial(handle)

	return hit, entityHit
end

-- Config.CustomDoorList carries names, not hashes, so they stay readable. Resolved once.
-- Some map packs ship the resolved hash instead of the name, so `hash` is taken as given.
local customDoors = nil
local function customDoorList()
	if customDoors then return customDoors end
	customDoors = {}
	for _, d in ipairs(Config.CustomDoorList or {}) do
		if (d.door or d.hash) and d.model and d.coords then
			customDoors[#customDoors + 1] = {
				hash = tonumber(d.hash) or GetHashKey(d.door),
				model = GetHashKey(d.model),
				coords = d.coords,
				radius = tonumber(d.radius), -- double doors sit closer than the default
			}
		end
	end
	return customDoors
end

--- Doors the game never reports: match by model and catalogue position.
local function CustomDoorHash(entity)
	local list <const> = customDoorList()
	if #list == 0 then return false end
	local model <const> = GetEntityModel(entity)
	local pos <const> = GetEntityCoords(entity)
	local radius <const> = tonumber(Config.CustomDoors and Config.CustomDoors.matchRadius) or 1.5
	for i = 1, #list do
		if list[i].model == model and #(pos - list[i].coords) < (list[i].radius or radius) then
			return list[i].hash
		end
	end
	return false
end

---Checks if a door is registered
---@param entity number
---@return number | boolean
function IsRegisteredDoor(entity)
	local HashToEntity = DoorSystemGetActive()

	for i = 1, #HashToEntity do
		if HashToEntity[i][2] == entity then
			return HashToEntity[i][1]
		end
	end

	-- DoorSystemGetActive only knows doors the game registered, so MLO doors are matched separately
	return CustomDoorHash(entity)
end

---Looks up the door hash in the door system table
---@param hash number
---@return number | boolean
function GetSytemDoorId(hash)
	for doorid, data in next, Doors do
		if data.doors then
			if data.doors[1].hash == hash or data.doors[2].hash == hash then
				return doorid
			end
		else
			if data.door.hash == hash then
				return doorid
			end
		end
	end

	return false
end

-- Adds a door to the door system AddDoorToSystemNew Native https://rdr3natives.com/?_0xD99229FE93B46286
---@param hash number
---@param p1 boolean
---@param p2 boolean
---@param p3 boolean
---@param threadId number
---@param p5 number
---@param p6 boolean
function AddDoorToSystem(hash, p1, p2, p3, threadId, p5, p6)
	Citizen.InvokeNative(0xD99229FE93B46286, hash, p1, p2, p3, threadId, p5, p6)
end

-- Sets the state of a door DoorSystemSetDoorState Native https://rdr3natives.com/?_0x6BAB9442830C7F53
---@param hash number
---@param state number
function DoorSystemSetDoorState(hash, state)
	Citizen.InvokeNative(0x6BAB9442830C7F53, hash, state)
end

---Starts the door creation process
---@param isDouble boolean
---@return any
function SelectDoorThread(isDouble)
	local SelectedDoor = nil
	local DoubleDoors = {}
	local PromptGroup = U.Prompts:SetupPromptGroup()
	local AddDoorPrompt = PromptGroup:RegisterPrompt(_('add_door'), Config.Keys.selectDoor, false, true, false, 'click', {})
	local CancelDoorPrompt = PromptGroup:RegisterPrompt(_('cancel'), Config.Keys.cancel, true, true, false, 'click', {})

	while SelectionActive and not IsPedDeadOrDying(U.Cache.Ped, false) do
		Wait(5)
		
		PromptGroup:ShowGroup(_('doorlock'))

		if CancelDoorPrompt:HasCompleted() then
			SelectionActive = false
			SelectedDoor = nil
			DoorNotify('admin', _('canceled'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
			break
		end

		if true then

			local retval, entity = RayCastGamePlayCamera()

			if retval then
				local model = GetEntityModel(entity)
				local isDoor = IsDoor(entity)
				local isRegistered = IsRegisteredDoor(entity)

				DevPrint('Entity:', entity, 'Model:', model, 'IsDoor:', isDoor, 'IsRegistered:', isRegistered)

				if not isDoor and not DoubleDoors[entity] and isRegistered then
					AddDoorPrompt:EnabledPrompt(true)

					if AddDoorPrompt:HasCompleted() then
						if not isDouble then

							SelectedDoor = {
								hash = isRegistered,
								model = GetEntityModel(entity),
								coords = GetEntityCoords(entity),
								heading = GetEntityHeading(entity)
							}

							break
						else
							DoubleDoors[entity] = true

							SelectedDoor = SelectedDoor or {}

							table.insert(SelectedDoor, {
								hash = isRegistered,
								model = GetEntityModel(entity),
								coords = GetEntityCoords(entity),
								heading = GetEntityHeading(entity)
							})

							if #SelectedDoor == 2 then
								break
							end
						end
						
					end
				else
					AddDoorPrompt:EnabledPrompt(false)
				end

			else
				AddDoorPrompt:EnabledPrompt(false)
			end
		else
			AddDoorPrompt:EnabledPrompt(false)
		end
	end

	SelectionActive = false

	AddDoorPrompt:DeletePrompt()

	DevPrint('IsDouble:', isDouble, 'Selected Door:', json.encode(SelectedDoor))

	if SelectedDoor then
		DoorNotify('admin', _('selected'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_GREEN', 1500)
	end

	return SelectedDoor
end

---Starts the select door thread
---@return any
function SelectDoorIdThread()
	local SelectedDoor = nil
	local PromptGroup = U.Prompts:SetupPromptGroup()
	local AddDoorPrompt = PromptGroup:RegisterPrompt(_('select_door'), Config.Keys.selectDoor, false, true, false, 'click', {})
	local CancelDoorPrompt = PromptGroup:RegisterPrompt(_('cancel'), Config.Keys.cancel, true, true, false, 'click', {})

	while not IsPedDeadOrDying(U.Cache.Ped, false) do
		Wait(5)
		
		PromptGroup:ShowGroup(_('doorlock'))

		if CancelDoorPrompt:HasCompleted() then
			SelectedDoor = nil
			DoorNotify('admin', _('canceled'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
			break
		end

		local retval, entity = RayCastGamePlayCamera()

		if retval then
			local isDoor = IsDoor(entity)

			if isDoor then
				AddDoorPrompt:EnabledPrompt(true)

				if AddDoorPrompt:HasCompleted() then
					local doorid = DoorEnities[entity]
					print('Selected DoorID:', doorid)
					SelectedDoor = doorid
					break
				end
			else
				AddDoorPrompt:EnabledPrompt(false)
			end

		else
			AddDoorPrompt:EnabledPrompt(false)
		end
	end

	AddDoorPrompt:DeletePrompt()

	if SelectedDoor then
		DoorNotify('admin', _('selected_id', SelectedDoor), 'BLIPS', 'blip_proc_home_locked', 'COLOR_GREEN', 1500)
	end

	return SelectedDoor
end

---Sets the door up in the door system
---@param data table
--- Close, then lock: a locked door refuses to move.
local function applyDoor(hash, locked)
	AddDoorToSystem(hash, true, true, false, 0, 0, false)
	if locked then
		DoorSystemSetOpenRatio(hash, 0.0, false, false)
		DoorSystemSetDoorState(hash, 1)
	else
		DoorSystemSetDoorState(hash, 0)
	end
end

function SetupDoor(data)
	if data.doors then
		for i = 1, 2 do
			applyDoor(data.doors[i].hash, data.locked)
		end
	else
		applyDoor(data.door.hash, data.locked)
	end
end

---Updates the state of a door
---@param doorid number
function UpdateDoorState(doorid)
	if not Doors[doorid] then return end

	-- SetupDoor, not a bare SetDoorState: a streamed-out door is unregistered and ignores Set calls
	SetupDoor(Doors[doorid])
end

---Removes a door from the door system
---@param doorid number
function RemoveDoor(doorid)
	if not Doors[doorid] then return end

	local data = Doors[doorid]

	if data.doors then
		for i = 1, 2 do
			DoorSystemSetDoorState(data.doors[i].hash, 0)
			Wait(100) -- Wait for the door to be removed?
			RemoveDoorFromSystem(data.doors[i].hash)
		end
	else
		DoorSystemSetDoorState(data.door.hash, 0)
		Wait(100) -- Wait for the door to be removed?
		RemoveDoorFromSystem(data.door.hash)
	end
end
