local time = 10000
local scenes = {}
local players = {}
local ghosts = {}          -- [serverId] = someone else's in-progress scene
local isplay = false
local allowscene = true
local allowscene2 = true

function GetPlayers()
	local players = {}
	for i = 0, 256 do
		if NetworkIsPlayerActive(i) then
			table.insert(players, GetPlayerServerId(i))
		end
	end
	return players
end

-- SceneConfig keys may be a raw control hash or an "INPUT_..." name; resolve both.
local function keyHash(k)
	if type(k) == 'number' then return k end
	return joaat(tostring(k))
end

local K = {}
for name, value in pairs(SceneConfig.Keys) do K[name] = keyHash(value) end

-- 0x580417101DDB492F is IS_CONTROL_JUST_PRESSED - the ENABLED-only variant
local HAS_DISABLED_JUST_PRESSED <const> = (type(IsDisabledControlJustPressed) == 'function')

function SceneKeyPressed(key)
	local h <const> = keyHash(key)
	if Citizen.InvokeNative(0x580417101DDB492F, 0, h) then return true end
	if HAS_DISABLED_JUST_PRESSED and IsDisabledControlJustPressed(0, h) then return true end
	return false
end

local function keyHeld(key)
	local h <const> = keyHash(key)
	return IsControlPressed(0, h) or IsDisabledControlPressed(0, h)
end

-- Style A scene stores RESOLVED values (rgb / scale / font id / backing opacity / range)

local function defaultStyle()
	local c <const> = SceneConfig.Styles.palette[1]
	return {
		r = c.r, g = c.g, b = c.b,
		scale   = 0.30,
		font    = 1,
		back    = 0.0,
		range   = SceneConfig.Display.defaultRange + 0.0,
		accent  = '',      -- SceneConfig.Styles.inlineColours key, '' = no accent
		pattern = 'none',  -- SceneConfig.Styles.patterns id
	}
end

local function normStyle(s)
	local d <const> = defaultStyle()
	if type(s) ~= 'table' then return d end
	local function num(v, fallback) local n = tonumber(v) return n or fallback end

	local accent = tostring(s.accent or ''):lower()
	if accent ~= '' and not SceneConfig.Styles.inlineColours[accent] then accent = '' end

	local pattern = tostring(s.pattern or 'none')
	local known = false
	for _, p in ipairs(SceneConfig.Styles.patterns) do if p.id == pattern then known = true break end end
	if not known then pattern = 'none' end

	return {
		r       = math.floor(math.max(0, math.min(255, num(s.r, d.r)))),
		g       = math.floor(math.max(0, math.min(255, num(s.g, d.g)))),
		b       = math.floor(math.max(0, math.min(255, num(s.b, d.b)))),
		scale   = math.max(SceneConfig.Limits.minScale, math.min(SceneConfig.Limits.maxScale, num(s.scale, d.scale))),
		font    = math.floor(math.max(0, math.min(9, num(s.font, d.font)))),
		back    = math.max(0.0, math.min(1.0, num(s.back, d.back))),
		range   = math.max(1.0, math.min(SceneConfig.Limits.maxRange, num(s.range, d.range))),
		accent  = accent,
		pattern = pattern,
	}
end

-- Labels are drawn by pup-ui's overlay page, not the game text natives: those have no glyphs for decorative Unicode
-- and paint boxes. Every caller queues its label here and one thread hands the frame's batch over.
local frameLabels = {}
local frameAuto = 0
local segCache = {} -- text .. style key -> coloured runs, rebuilt only when the text or style changes

local function labelSegments(text, st)
	local key <const> = ("%s|%d,%d,%d|%s|%s"):format(text, st.r, st.g, st.b, tostring(st.accent), tostring(st.pattern))
	local segs = segCache[key]
	if not segs then
		segs = SceneMarkupSegments(text, st)
		segCache[key] = segs
	end
	return segs
end

-- Queues a scene label exactly as it will look once placed; `id` keeps the same element between frames
local function DrawSceneText(x, y, z, text, st, alphaMul, id)
	local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
	if not onScreen then return end
	if not id then
		frameAuto = frameAuto + 1
		id = 'auto' .. frameAuto
	end
	frameLabels[#frameLabels + 1] = {
		id    = tostring(id),
		x     = sx, y = sy,
		segs  = labelSegments(text, st),
		scale = st.scale,
		back  = st.back or 0.0,
		a     = alphaMul or 1.0,
		font  = st.font or 1,
	}
end

CreateThread(function()
	while true do
		Wait(0)
		if #frameLabels > 0 then
			exports['pup-ui']:DrawSceneLabels(frameLabels)
			frameLabels = {}
			frameAuto = 0
		else
			exports['pup-ui']:HideSceneLabels()
		end
		-- the cache only ever grows while people keep typing new labels; a hard reset is cheaper than bookkeeping
		if next(segCache) ~= nil then
			local n = 0
			for _ in pairs(segCache) do n = n + 1 if n > 200 then segCache = {} break end end
		end
	end
end)

-- Style bar: one row per property

local function cycle(i, n, dir)
	i = i + dir
	if i < 1 then return n end
	if i > n then return 1 end
	return i
end

--- index of the list entry closest to `v` (styles hold values, not indices)
local function nearestIndex(list, v, get)
	local best, bestd = 1, math.huge
	for i, entry in ipairs(list) do
		local d <const> = math.abs((get and get(entry) or entry) - v)
		if d < bestd then best, bestd = i, d end
	end
	return best
end

--- Apply a whole preset. Named lookups so config keeps one source of truth.
local function applyPreset(st, preset)
	for _, c in ipairs(SceneConfig.Styles.palette) do
		if c.name == preset.colour then st.r, st.g, st.b = c.r, c.g, c.b break end
	end
	for _, bk in ipairs(SceneConfig.Styles.backings) do
		if bk.name == preset.backing then st.back = bk.a break end
	end
	st.scale   = tonumber(preset.size) or st.scale
	st.font    = tonumber(preset.font) or st.font
	st.accent  = preset.accent or ''
	st.pattern = preset.effect or 'none'
end

-- Which preset does this style currently match, if any?
local function presetIndex(st)
	for i, p in ipairs(SceneConfig.Styles.presets) do
		local colour, backing
		for _, c in ipairs(SceneConfig.Styles.palette) do if c.name == p.colour then colour = c break end end
		for _, bk in ipairs(SceneConfig.Styles.backings) do if bk.name == p.backing then backing = bk break end end
		if colour and backing
			and st.r == colour.r and st.g == colour.g and st.b == colour.b
			and math.abs(st.back - backing.a) < 0.001
			and math.abs(st.scale - (tonumber(p.size) or -1)) < 0.001
			and st.font == (tonumber(p.font) or -1)
			and st.accent == (p.accent or '')
			and st.pattern == (p.effect or 'none')
		then
			return i
		end
	end
	return nil
end

local PROPS <const> = {
	{
		label = 'propPreset',
		count = function() return #SceneConfig.Styles.presets end,
		read  = function(st)
			local i <const> = presetIndex(st)
			if i then return i, SceneConfig.Styles.presets[i].name end
			-- nothing matches: show Custom but keep the cursor somewhere sane so scrolling from here lands on a real preset
			return 1, SceneLocale.presetCustom
		end,
		write = function(st, i) applyPreset(st, SceneConfig.Styles.presets[i]) end,
	},
	{
		label = 'propColour',
		count = function() return #SceneConfig.Styles.palette end,
		read  = function(st)
			for i, c in ipairs(SceneConfig.Styles.palette) do
				if c.r == st.r and c.g == st.g and c.b == st.b then return i, c.name end
			end
			return 1, ("%d,%d,%d"):format(st.r, st.g, st.b)
		end,
		write = function(st, i)
			local c <const> = SceneConfig.Styles.palette[i]
			st.r, st.g, st.b = c.r, c.g, c.b
		end,
	},
	{
		label = 'propAccent',
		count = function() return #SceneConfig.Styles.accentOrder + 1 end, -- +1 = Off
		read  = function(st)
			if st.accent == '' then return 1, SceneLocale.accentOff end
			for i, key in ipairs(SceneConfig.Styles.accentOrder) do
				if key == st.accent then return i + 1, key end
			end
			return 1, SceneLocale.accentOff
		end,
		write = function(st, i)
			st.accent = (i == 1) and '' or (SceneConfig.Styles.accentOrder[i - 1] or '')
			-- an accent with no effect would never show, so give it one
			if st.accent ~= '' and st.pattern == 'none' then st.pattern = 'first' end
		end,
	},
	{
		label = 'propEffect',
		count = function() return #SceneConfig.Styles.patterns end,
		read  = function(st)
			for i, p in ipairs(SceneConfig.Styles.patterns) do
				if p.id == st.pattern then return i, p.name end
			end
			return 1, SceneConfig.Styles.patterns[1].name
		end,
		write = function(st, i)
			st.pattern = SceneConfig.Styles.patterns[i].id
			-- likewise: an effect needs a colour to paint with
			if st.pattern ~= 'none' and st.accent == '' then
				st.accent = SceneConfig.Styles.accentOrder[1] or ''
			end
		end,
	},
	{
		label = 'propSize',
		count = function() return #SceneConfig.Styles.sizes end,
		read  = function(st)
			local i <const> = nearestIndex(SceneConfig.Styles.sizes, st.scale)
			return i, ("%.2f"):format(SceneConfig.Styles.sizes[i])
		end,
		write = function(st, i) st.scale = SceneConfig.Styles.sizes[i] end,
	},
	{
		label = 'propFont',
		count = function() return #SceneConfig.Styles.fonts end,
		read  = function(st)
			for i, f in ipairs(SceneConfig.Styles.fonts) do
				if f.id == st.font then return i, f.name end
			end
			return 1, SceneConfig.Styles.fonts[1].name
		end,
		write = function(st, i) st.font = SceneConfig.Styles.fonts[i].id end,
	},
	{
		label = 'propBacking',
		count = function() return #SceneConfig.Styles.backings end,
		read  = function(st)
			local i <const> = nearestIndex(SceneConfig.Styles.backings, st.back, function(e) return e.a end)
			return i, SceneConfig.Styles.backings[i].name
		end,
		write = function(st, i) st.back = SceneConfig.Styles.backings[i].a end,
	},
	{
		label = 'propRange',
		count = function() return #SceneConfig.Styles.ranges end,
		read  = function(st)
			local i <const> = nearestIndex(SceneConfig.Styles.ranges, st.range)
			return i, ("%dm"):format(math.floor(SceneConfig.Styles.ranges[i]))
		end,
		write = function(st, i) st.range = SceneConfig.Styles.ranges[i] end,
	},
}

-- Placement session

local MODE_AIM   <const> = 1
local MODE_FREE  <const> = 2
local MODE_STYLE <const> = 3
local MODE_LABEL <const> = { 'modeAim', 'modeFree', 'modeStyle' }
local MODE_HINT  <const> = { 'hintAim', 'hintFree', 'hintStyle' }

local place = {
	active = false,
	mode   = MODE_AIM,
	text   = '',
	pos    = nil,
	style  = nil,
	prop   = 1,
	push   = 0,
}

-- ONLY the height keys are suppressed
-- repeat for as long as you slide the label - and they are read exclusively via
-- keyHeld, which already checks the disabled variant
local PLACE_CONTROLS <const> = { K.raise, K.lower }

local hold = {}

-- current speed for a held direction key: starts slow so a tap nudges
local function heldSpeed(key, dt)
	local h <const> = keyHash(key)
	if keyHeld(h) then
		hold[h] = (hold[h] or 0) + dt
		local t <const> = math.min(hold[h] / SceneConfig.Place.moveRamp, 1.0)
		return SceneConfig.Place.moveSpeed + (SceneConfig.Place.moveSpeedMax - SceneConfig.Place.moveSpeed) * t
	end
	hold[h] = 0
	return 0.0
end

local function axis(kPos, kNeg, dt)
	local a <const> = heldSpeed(kPos, dt)
	local b <const> = heldSpeed(kNeg, dt)
	return a - b
end

local function rotToDir(rot)
	local z <const> = math.rad(rot.z)
	local x <const> = math.rad(rot.x)
	local num <const> = math.abs(math.cos(x))
	return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- AIM: the label rides the camera ray and lands on whatever it hits
local function aimUpdate()
	local cam <const> = GetGameplayCamCoord()
	local dir <const> = rotToDir(GetGameplayCamRot(2))
	local dest <const> = cam + (dir * SceneConfig.Place.aimDistance)

	local ray <const> = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
	local _, hit, endCoords, normal = GetShapeTestResult(ray)

	if (hit == 1 or hit == true) and endCoords then
		local n = normal
		if not n or (n.x == 0.0 and n.y == 0.0 and n.z == 0.0) then n = vector3(0.0, 0.0, 1.0) end
		place.pos = vector3(endCoords.x, endCoords.y, endCoords.z) + (n * SceneConfig.Place.surfaceOffset)
	else
		place.pos = dest
	end
end

-- FREE: CAMERA-RELATIVE
local function freeUpdate(dt)
	local rot <const> = GetGameplayCamRot(2)
	local h <const> = math.rad(rot.z)
	local fwd <const> = vector3(-math.sin(h), math.cos(h), 0.0)
	local right <const> = vector3(math.cos(h), math.sin(h), 0.0)

	local f <const> = axis(K.up, K.down, dt)
	local s <const> = axis(K.right, K.left, dt)
	local u <const> = axis(K.raise, K.lower, dt)

	if f ~= 0.0 or s ~= 0.0 or u ~= 0.0 then
		place.pos = place.pos + (fwd * (f * dt)) + (right * (s * dt)) + vector3(0.0, 0.0, u * dt)
	end
end

local function styleUpdate()
	if SceneKeyPressed(K.up) then
		place.prop = cycle(place.prop, #PROPS, -1)
	elseif SceneKeyPressed(K.down) then
		place.prop = cycle(place.prop, #PROPS, 1)
	end

	local dir = 0
	if SceneKeyPressed(K.right) then dir = 1 elseif SceneKeyPressed(K.left) then dir = -1 end
	if dir ~= 0 then
		local p <const> = PROPS[place.prop]
		local i <const> = p.read(place.style)
		p.write(place.style, cycle(i, p.count(), dir))
	end
end

local function drawPlacement()
	DrawSceneText(place.pos.x, place.pos.y, place.pos.z, place.text, place.style, 1.0, 'place')

	local L <const> = SceneLocale

	-- this panel's renderer lives in pup-ui as DrawHudPanel
	local rows = {}
	if place.mode == MODE_STYLE then
		for i, p in ipairs(PROPS) do
			local _, valueName = p.read(place.style)
			rows[#rows + 1] = {
				label = L[p.label],
				value = valueName,
				selected = (i == place.prop),
			}
		end
	end

	exports['pup-ui']:DrawHudPanel({
		title = ("[ %s ]   %s"):format(L[MODE_LABEL[place.mode]], L[MODE_HINT[place.mode]]),
		rows = rows,
		footer = ("%s    %s    %s"):format(L.hintMode, L.hintPlace, L.hintClose),
	})
end

local function pushPreview(force)
	local now <const> = GetGameTimer()
	local interval <const> = math.floor(1000 / math.max(1, SceneConfig.Place.previewHz or 6))
	if not force and (now - place.push) < interval then return end
	place.push = now
	TriggerServerEvent('pup-scene:preview', place.pos.x, place.pos.y, place.pos.z, place.text, place.style)
end

local function endPlacement(confirm)
	local wasActive <const> = place.active
	place.active = false
	hold = {}
	if not wasActive then return end

	if confirm then
		TriggerServerEvent("pup-scene:savescene",
			{ x = place.pos.x, y = place.pos.y, z = place.pos.z }, place.text, place.style)
	end
	-- clear everyone else's ghost either way
	TriggerServerEvent('pup-scene:previewEnd')
end

local function beginPlacement(text)
	place.active = true
	place.mode   = MODE_AIM
	place.text   = text
	place.style  = defaultStyle()
	place.prop   = 1
	place.push   = 0
	place.pos    = GetEntityCoords(PlayerPedId())
	hold = {}
end

CreateThread(function()
	while true do
		if not place.active then
			Wait(200)
		else
			local dt <const> = GetFrameTime()

			-- see PLACE_CONTROLS: height keys only, never the confirm/cancel/mode keys
			for _, k in ipairs(PLACE_CONTROLS) do
				DisableControlAction(0, k, true)
			end

			if SceneKeyPressed(K.cancel) then
				endPlacement(false)
			elseif SceneKeyPressed(K.place) then
				endPlacement(true)
			else
				if SceneKeyPressed(K.mode) then
					place.mode = cycle(place.mode, 3, 1)
				end

				if place.mode == MODE_AIM then
					aimUpdate()
				elseif place.mode == MODE_FREE then
					freeUpdate(dt)
				else
					styleUpdate()
				end

				drawPlacement()
				pushPreview(false)
			end

			Wait(0)
		end
	end
end)

-- /scene

RegisterNetEvent('pup-scene:stopscene')
AddEventHandler('pup-scene:stopscene', function(x)
	allowscene2 = x
end)

local SCENE_INPUT <const> = 'pup-scene:text'

-- Server-confirmed job access
canPlaceScene  = not SceneConfig.Access.jobLock
canRemoveScene = not SceneConfig.Access.jobLock

local accessSeq = 0
RegisterNetEvent("pup-scene:setAccess")
AddEventHandler("pup-scene:setAccess", function(canPlace, canRemove)
	canPlaceScene  = canPlace == true
	canRemoveScene = canRemove == true
	accessSeq = accessSeq + 1
end)

-- ask the server again right before a command runs: a job taken after logging in is not in the cached answer
local function refreshAccess()
	local before <const> = accessSeq
	TriggerServerEvent("pup-scene:requestAccess")
	local deadline <const> = GetGameTimer() + 1000
	while accessSeq == before and GetGameTimer() < deadline do Wait(50) end
end

Citizen.CreateThread(function()
	Wait(3000)
	TriggerServerEvent("pup-scene:requestAccess")
end)
RegisterNetEvent("vorp:SelectedCharacter", function()
	TriggerServerEvent("pup-scene:requestAccess")
end)

RegisterCommand(SceneConfig.General.commands.place, function()
	if place.active then return end
	refreshAccess()
	if not canPlaceScene then
		TriggerEvent("vorp:TipBottom", SceneLocale.notjob, 4000)
		return
	end
	if not (allowscene and allowscene2) then
		TriggerEvent("vorp:TipBottom", SceneLocale.notinhideout, 4000)
		return
	end

	local handler
	handler = AddEventHandler('pup-ui:client:inputDone', function(owner, values)
		if owner ~= SCENE_INPUT then return end
		RemoveEventHandler(handler)

		local body = values and values[1] and tostring(values[1]) or ''
		if body ~= '' and body ~= 'close' then
			beginPlacement(body)
		else
			TriggerEvent("vorp:TipBottom", SceneLocale.invalid, 4000)
		end
	end)

	exports['pup-ui']:OpenInput({
		owner    = SCENE_INPUT,
		title    = SceneLocale.displaytext,
		subtitle = SceneLocale.colourhint,
		submit   = SceneLocale.confirm,
		fields   = { { label = SceneLocale.displaytext, type = 'textarea', rows = 8, maxlength = SceneConfig.Limits.maxTextLength } },
	})
end, false)

-- scene list + other players' in-progress ghosts

RegisterNetEvent('pup-scene:getscenes')
AddEventHandler('pup-scene:getscenes', function(list)
	local out = {}
	for _, v in ipairs(list or {}) do
		v.style = normStyle(v.style)
		out[#out + 1] = v
	end
	scenes = out
end)

RegisterNetEvent('pup-scene:getscenes2')
AddEventHandler('pup-scene:getscenes2', function()
	TriggerServerEvent("pup-scene:pullscenes", 1, 0)
end)

RegisterNetEvent('pup-scene:previewFrom')
AddEventHandler('pup-scene:previewFrom', function(from, x, y, z, text, style)
	ghosts[from] = {
		x = x, y = y, z = z,
		text = text,
		style = normStyle(style),
		expires = GetGameTimer() + 1500, -- a placer who crashes must not leave a ghost
	}
end)

RegisterNetEvent('pup-scene:previewEnd')
AddEventHandler('pup-scene:previewEnd', function(from)
	ghosts[from] = nil
end)

RegisterNetEvent("vorp:SelectedCharacter")
AddEventHandler("vorp:SelectedCharacter", function()
	Wait(1000)
	TriggerServerEvent("pup-scene:pullscenes", 1, 0)
	TriggerServerEvent("pup-scene:getstatus")
end)

AddEventHandler("onResourceStart", function(resourceName)
	if resourceName == GetCurrentResourceName() then
		Wait(1000)
		TriggerServerEvent("pup-scene:pullscenes", 1, 0)
		TriggerServerEvent("pup-scene:getstatus")
	end
end)

Citizen.CreateThread(function()
	while true do
		local wait = 500
		if SceneConfig.Access.hideout.enabled then
			local coords <const> = GetEntityCoords(PlayerPedId())
			local h <const> = SceneConfig.Access.hideout
			allowscene = GetDistanceBetweenCoords(coords, h.coords.x, h.coords.y, h.coords.z, true) >= h.radius
			wait = 250
		end
		Wait(wait)
	end
end)

Citizen.CreateThread(function()
	while true do
		local wait = 500
		local pc <const> = GetEntityCoords(PlayerPedId())

		if allowscene and allowscene2 then
			for _, v in pairs(scenes) do
				local st <const> = v.style
				local d <const> = GetDistanceBetweenCoords(pc.x, pc.y, pc.z, v.coords.x, v.coords.y, v.coords.z, true)
				if d < st.range then
					wait = 0
					DrawSceneText(v.coords.x, v.coords.y, v.coords.z, v.text, st, 1.0, 's' .. tostring(v.id))
					-- the remove key doubles as the placement mode key, so it must not fire while a placement session owns the input
					if d < 1.5 and not place.active then
						SceneDrawText(SceneLocale.pressg2, 0.15, 0.30, 0.1, 0.3, true, 255, 255, 255, 255, true)
						if SceneKeyPressed(K.mode) then
							TriggerServerEvent("pup-scene:removescene", v.id, v.charid, GetPlayers())
							Wait(2500)
						end
					end
				end
			end
		end

		local now <const> = GetGameTimer()
		for from, g in pairs(ghosts) do
			if g.expires < now then
				ghosts[from] = nil
			else
				local d <const> = GetDistanceBetweenCoords(pc.x, pc.y, pc.z, g.x, g.y, g.z, true)
				if d < SceneConfig.Place.previewRange then
					wait = 0
					-- deliberately faded: a bystander should be able to tell at a glance that this one is still being placed and is not there
					DrawSceneText(g.x, g.y, g.z, g.text, g.style, 0.55, 'g' .. tostring(from))
				end
			end
		end

		Wait(wait)
	end
end)

-- /scenes - aim at a scene and remove it, for scenes out of walk-up reach (rooftops, cliffs, water):
-- every scene in range is projected onto the camera's aim and the one nearest the centre is picked
local delMode = false

local function camForward()
	local rot <const> = GetGameplayCamRot(2)
	local rz <const> = math.rad(rot.z)
	local rx <const> = math.rad(rot.x)
	local cosx <const> = math.abs(math.cos(rx))
	return vector3(-math.sin(rz) * cosx, math.cos(rz) * cosx, math.sin(rx))
end

-- the scene nearest the middle of the screen, or nil
local function sceneUnderAim()
	local cam <const> = GetGameplayCamCoord()
	local fwd <const> = camForward()
	local maxD <const> = tonumber(SceneConfig.Removal.aimRange) or 60.0
	local minDot <const> = tonumber(SceneConfig.Removal.aimDot) or 0.995

	local best, bestDot
	for _, v in pairs(scenes) do
		local to = vector3(v.coords.x - cam.x, v.coords.y - cam.y, v.coords.z - cam.z)
		local len = #to
		if len > 0.5 and len <= maxD then
			local dot = ((to.x / len) * fwd.x) + ((to.y / len) * fwd.y) + ((to.z / len) * fwd.z)
			if dot >= minDot and (not bestDot or dot > bestDot) then
				best, bestDot = v, dot
			end
		end
	end
	return best
end

RegisterCommand(SceneConfig.General.commands.removeAim, function()
	if not delMode then refreshAccess() end
	if not canRemoveScene then
		delMode = false
		TriggerEvent("vorp:TipBottom", SceneLocale.notjob, 4000)
		return
	end
	delMode = not delMode
	TriggerEvent('vorp:TipRight',
		delMode and SceneLocale.delModeOn or SceneLocale.delModeOff, 5000)
end, false)

Citizen.CreateThread(function()
	while true do
		local wait = 500
		-- access can be revoked mid-session by a job change
		if delMode and not canRemoveScene then delMode = false end
		if delMode then
			wait = 0
			local target <const> = sceneUnderAim()

			SceneDrawText(SceneLocale.delAimHint, 0.5, 0.92, 0.4, 0.4, true, 255, 255, 255, 220, true)

			if target then
				-- mark it so there is no doubt which one is about to go
				DrawSceneText(target.coords.x, target.coords.y, target.coords.z + 0.25,
					SceneLocale.delTarget, target.style, 1.0, 'del')
				if SceneKeyPressed(K.place) then
					TriggerServerEvent("pup-scene:removescene", target.id, target.charid, GetPlayers())
					Wait(1200)
				end
			end

			-- B is the same Cancel the placement session uses; ESC also works
			if SceneKeyPressed(K.cancel) or IsControlJustPressed(0, 0x156F7119) then
				delMode = false
				TriggerEvent('vorp:TipRight', SceneLocale.delModeOff, 3000)
			end
		end
		Wait(wait)
	end
end)

-- /me /ooc /id /cash /status /cstatus

RegisterCommand(SceneConfig.General.commands.me, function(source, args)
	local text = ''
	for i = 1, #args do
		text = text .. ' ' .. args[i]
	end
	text = text .. ' '
	TriggerServerEvent('pup-scene:shareDisplay', text, GetPlayers())
end)

RegisterCommand(SceneConfig.General.commands.ooc, function(source, args)
	local text = SceneLocale.ooc
	for i = 1, #args do
		text = text .. ' ' .. args[i]
	end
	text = text .. ' '
	TriggerServerEvent('pup-scene:shareDisplay', text, GetPlayers())
end)

RegisterCommand(SceneConfig.General.commands.id, function()
	local text = SceneLocale.id .. GetPlayerServerId(GetPlayerIndex())
	TriggerServerEvent('pup-scene:shareDisplay', text, GetPlayers())
end)

RegisterCommand(SceneConfig.General.commands.cash, function()
	TriggerServerEvent('pup-scene:shareDisplay3', SceneLocale.cash, GetPlayers())
end)

RegisterCommand(SceneConfig.General.commands.status, function(source, args)
	if isplay then
		TriggerServerEvent('pup-scene:stopdisplay', GetPlayers())
		Wait(1000)
	end
	isplay = true
	local text = SceneLocale.stat
	for i = 1, #args do
		text = text .. ' ' .. args[i]
	end
	text = text .. ' '
	TriggerServerEvent('pup-scene:shareDisplay2', text, GetPlayers())
end)

RegisterCommand(SceneConfig.General.commands.stopStatus, function()
	if isplay then
		TriggerServerEvent('pup-scene:stopdisplay', GetPlayers())
		Wait(1000)
	end
end)

RegisterNetEvent('pup-scene:triggerDisplay')
AddEventHandler('pup-scene:triggerDisplay', function(text, source)
	Display(GetPlayerFromServerId(source), text)
end)

RegisterNetEvent('pup-scene:triggerDisplay2')
AddEventHandler('pup-scene:triggerDisplay2', function(playersstatus)
	players = playersstatus
end)

-- who is currently knocked out, by server id
local kos = {}

RegisterNetEvent('pup-scene:koList')
AddEventHandler('pup-scene:koList', function(list)
	kos = {}
	for _, id in ipairs(list or {}) do kos[tonumber(id) or -1] = true end
end)

-- ped for a server id, or nil when they are not streamed in
local function pedOfServerId(id)
	local plyIdx <const> = GetPlayerFromServerId(tonumber(id) or -1)
	if plyIdx == nil or plyIdx == -1 then return nil end
	local ped <const> = GetPlayerPed(plyIdx)
	if not ped or ped == 0 or ped == PlayerPedId() then return nil end
	return ped
end

-- like pedOfServerId, but your own server id resolves to your own ped
local function pedOfServerIdOrSelf(id)
	local wanted <const> = tonumber(id) or -1
	if wanted == GetPlayerServerId(PlayerId()) then
		return PlayerPedId()
	end
	return pedOfServerId(wanted)
end

local koStyle = nil
local function getKoStyle()
	if koStyle then return koStyle end
	local k <const> = SceneConfig.KnockedOut or {}
	koStyle = normStyle({
		r = k.r, g = k.g, b = k.b,
		scale = k.scale, font = k.font, back = k.back, range = k.range,
	})
	return koStyle
end

Citizen.CreateThread(function()
	while true do
		Wait(10)
		local coords <const> = GetEntityCoords(PlayerPedId(), false)

		for _, v in pairs(players) do
			-- ...OrSelf: you need to see your own status, or there is no way to
			-- tell it is still up. Same call the Knocked Out text already uses.
			local ped <const> = pedOfServerIdOrSelf(v.id)
			if ped then
				local coordsMe <const> = GetEntityCoords(ped, false)
				if GetDistanceBetweenCoords(coords, coordsMe, true) < SceneConfig.Display.defaultRange then
					SceneDrawText3D(coordsMe['x'], coordsMe['y'], coordsMe['z'], v.texts, 'st' .. tostring(v.id))
				end
			end
		end

		-- knocked out: drawn through DrawSceneText so it gets the same colour / size / backing plate treatment as a placed scene
		if next(kos) ~= nil then
			local k <const> = SceneConfig.KnockedOut or {}
			local st <const> = getKoStyle()
			for id in pairs(kos) do
				local ped <const> = pedOfServerIdOrSelf(id)
				if ped then
					local c <const> = GetEntityCoords(ped, false)
					if #(coords - c) < st.range then
						DrawSceneText(c.x, c.y, c.z + (k.height or 1.0), SceneLocale.knockedOut, st, 1.0, 'ko' .. tostring(id))
					end
				end
			end
		end
	end
end)

function Display(mePlayer, text)
	local displaying = true
	Citizen.CreateThread(function()
		Wait(time)
		displaying = false
	end)
	Citizen.CreateThread(function()
		while displaying do
			Wait(0)
			local coordsMe <const> = GetEntityCoords(GetPlayerPed(mePlayer), false)
			local coords <const> = GetEntityCoords(PlayerPedId(), false)
			if Vdist2(coordsMe, coords) < 20 then
				SceneDrawText3D(coordsMe['x'], coordsMe['y'], coordsMe['z'], text, 'me' .. tostring(mePlayer))
			end
		end
	end)
end

function SceneDrawText(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
	local str <const> = CreateVarString(10, "LITERAL_STRING", str, Citizen.ResultAsLong())
	SetTextScale(w, h)
	SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
	SetTextCentre(centre)
	if enableShadow then
		SetTextDropshadow(1, 0, 0, 0, 255)
	end
	Citizen.InvokeNative(0xADA9255D, 10)
	DisplayText(str, x, y)
end

-- /me, /status and friends: plain white through the same overlay, so symbols work there too
local plainStyle = nil
function SceneDrawText3D(x, y, z, text, id)
	plainStyle = plainStyle or defaultStyle()
	DrawSceneText(x, y, z, tostring(text or ''), plainStyle, 1.0, id)
end

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end
	if place.active then endPlacement(false) end
	pcall(function() exports['pup-ui']:HideSceneLabels() end)
end)
