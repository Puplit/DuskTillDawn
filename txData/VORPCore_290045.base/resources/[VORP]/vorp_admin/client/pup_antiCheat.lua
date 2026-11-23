-- Modified by Puppet (Dusk Till Dawn), 2026
-- Movement detectors

local AC = Config.AntiCheat or {}
local isNormalForm = true

-- Per capability, and both start TRUE: never flag on a guess
local exempt = { teleport = true, noclip = true, freecam = true }

RegisterNetEvent('vorp_admin:ac:setExempt', function(state)
	if type(state) ~= 'table' then return end
	exempt.teleport = state.teleport == true
	exempt.noclip   = state.noclip == true
	-- staff noclip carries the camera away from the body, so whoever is allowed to noclip is allowed to be far from their ped
	exempt.freecam  = state.noclip == true
end)

-- blood-vial / animal form moves differently
RegisterNetEvent('vorpinventory:ammoUpdateToggle', function(state)
	isNormalForm = state
end)

CreateThread(function()
	Wait(10000) -- let the character load before asking
	TriggerServerEvent('vorp_admin:ac:amIExempt')
end)

-- teleport: time a waypoint journey, flag impossible average speed
if (AC.teleport or {}).enabled then
	local T = AC.teleport
	CreateThread(function()
		local active, startCoords, wpCoords, startTime = false, nil, nil, 0

		local function dist2D(a, b)
			return math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
		end

		while true do
			Wait(1000)
			local ped, plyId = PlayerPedId(), PlayerId()

			if IsWaypointActive() and not active then
				active, startCoords, wpCoords, startTime = true, GetEntityCoords(ped), GetWaypointCoords(), GetGameTimer()
			end

			if active then
				local now = GetEntityCoords(ped)
				local toWp = dist2D(now, wpCoords)
				local total = dist2D(startCoords, wpCoords)
				local elapsed = (GetGameTimer() - startTime) / 1000.0

				if toWp <= T.arriveRadius then
					local legit = IsPlayerRidingTrain(plyId) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false)
					if not exempt.teleport and isNormalForm and not legit
						and total >= T.minDistance and elapsed <= T.maxSeconds and elapsed > 0 then
						local speed = total / elapsed
						if speed > T.flagSpeedMps then
							TriggerServerEvent('vorp_admin:ac:flag', 'teleport', {
								dist = math.floor(total), secs = elapsed, speed = speed,
								from = startCoords, to = wpCoords,
							})
						end
					end
					active = false
				elseif elapsed > T.trackSeconds or not IsWaypointActive() then
					active = false
				end
			end
		end
	end)
end

-- noclip: moving too fast AND (through geometry OR hovering)
if (AC.noclip or {}).enabled then
	local N = AC.noclip
	CreateThread(function()
		local lastPos, lastTick, strikes = GetEntityCoords(PlayerPedId()), GetGameTimer(), 0

		-- the native takes six floats; pcall so a failure disables the sweep instead of the thread
		local shapeTestOk = true
		local function hitWorld(a, b, ignore)
			if not shapeTestOk then return false end
			local ok, h = pcall(StartShapeTestSweptSphere,
				a.x, a.y, a.z, b.x, b.y, b.z, N.radius, 1, ignore, 7)
			if not ok or not h then
				shapeTestOk = false
				print('^3[anticheat]^7 swept-sphere test unavailable; noclip falls back to the hover check')
				return false
			end
			local ok2, r, hit = pcall(GetShapeTestResult, h)
			return ok2 and r == 2 and hit == true
		end

		local function hovering(pos, ped, vz)
			if IsPedFalling(ped) or IsPedRagdoll(ped) or IsPedOnVehicle(ped) then return false end
			local _, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
			if gz == 0.0 then return false end
			return (pos.z - gz) >= N.hoverHeight and math.abs(vz) <= N.hoverMaxVerticalMps
		end

		while true do
			Wait(N.tickMs)
			local ped, plyId = PlayerPedId(), PlayerId()

			-- reset and skip on anything that legitimately moves oddly
			if exempt.noclip or not DoesEntityExist(ped)
				or IsPedInAnyVehicle(ped, false) or IsPedOnVehicle(ped)
				or IsPlayerRidingTrain(plyId) or IsEntityInWater(ped) or IsPedHogtied(ped) then
				lastPos, lastTick, strikes = GetEntityCoords(ped), GetGameTimer(), 0
			else
				local now = GetGameTimer()
				local dt = (now - lastTick) / 1000.0
				if dt > 0 then
					local pos = GetEntityCoords(ped)
					local dist = #(pos - lastPos)
					local vz = (pos.z - lastPos.z) / dt
					local vmax = IsPedOnMount(ped) and N.horseSpeedMps or N.footSpeedMps

					if dist > (vmax * dt + 1.0) and (hitWorld(lastPos, pos, ped) or hovering(pos, ped, vz)) then
						strikes = strikes + 1
						if strikes >= N.strikes then
							TriggerServerEvent('vorp_admin:ac:flag', 'noclip', {
								dist = dist, secs = dt, speed = dist / dt, to = pos,
							})
							strikes = 0
						end
					else
						-- DECAY, do not wipe
						if strikes > 0 then strikes = strikes - 1 end
					end

					lastPos, lastTick = pos, now
				end
			end
		end
	end)
end

-- freecam: the CAMERA travels while the ped stays put
if (AC.freecam or {}).enabled then
	local F = AC.freecam
	local FLAG <const> = F.stateBagKey or 'pup_cam_owned'
	CreateThread(function()
		local since = nil   -- when the camera first went long
		local anchor = nil  -- where the body was standing when it did
		while true do
			Wait(F.tickMs or 500)
			local ped = PlayerPedId()

			-- a resource that legitimately owns a long camera, a dead player, or a cutscene: not something to judge
			local owned = LocalPlayer.state and LocalPlayer.state[FLAG]
			-- fades, cutscenes and mounts all move the camera legitimately
			local blind = false
			pcall(function()
				blind = IsScreenFadedOut() or IsScreenFadingOut() or IsScreenFadingIn()
					or (IsCutsceneActive and IsCutsceneActive())
					or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false)
			end)

			if exempt.freecam or owned or blind or not DoesEntityExist(ped)
				or IsPedDeadOrDying(ped, true) or IsPauseMenuActive() then
				since = nil
				anchor = nil
			else
				local okCam, cam = pcall(function() return GetFinalRenderedCamCoord() end)
				if not okCam or not cam then
					since = nil
					anchor = nil
				else
					local here <const> = GetEntityCoords(ped)
					local d = #(here - cam)
					if d >= (F.distance or 40.0) then
						-- a free cam parks the body; a walking ped means the game camera is just lagging
						anchor = anchor or here
						local drift <const> = #(here - anchor)
						if drift > (F.maxBodyDrift or 5.0) then
							since = nil
							anchor = here
						else
							since = since or GetGameTimer()
							local held <const> = (GetGameTimer() - since) / 1000.0
							if held >= (F.holdSeconds or 3.0) then
								TriggerServerEvent('vorp_admin:ac:flag', 'freecam', {
									dist = d, secs = held, speed = 0, to = here,
								})
								since = nil -- one report per episode
								anchor = nil
							end
						end
					else
						since = nil
						anchor = nil
					end
				end
			end
		end
	end)
end