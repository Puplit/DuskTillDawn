-- Modified by Puppet (Dusk Till Dawn), 2026
-- Spawn guard: cancels blocked entity creations before they exist (entityCreating fires before the entity is made).

local G = Config.SpawnGuard or {}
local blocked, recent = 0, {}

-- Boar, cow, pig, snake and the mangy lion are blocked models AND legitimate pets,
-- and a pet ped is created by the client, so it reads as a cheat spawn. A resource
-- that has validated the request server-side opens a window here first.
local grants = {}   -- src -> { [model] = expiresAtMs }

local function grantActive(src, model)
    local byModel = grants[src]
    if not byModel then return false end
    local until_ = byModel[model]
    if not until_ then return false end
    if GetGameTimer() > until_ then
        byModel[model] = nil
        return false
    end
    return true
end

-- exports.vorp_admin:SpawnGuardAllow(src, 'A_C_Pig_01', 8000)
exports('SpawnGuardAllow', function(src, model, ms)
    src = tonumber(src)
    if not src or src <= 0 then return false end
    if type(model) == 'string' then model = GetHashKey(model) end
    model = tonumber(model)
    if not model then return false end
    grants[src] = grants[src] or {}
    -- long enough for the model to stream in on a cold cache, short enough to be useless to a spammer
    grants[src][model] = GetGameTimer() + math.min(tonumber(ms) or 8000, 30000)
    return true
end)

local function townAt(coords)
	for _, t in ipairs(G.towns or {}) do
		if #(coords - vector3(t.x, t.y, coords.z)) <= t.radius then return t.name end
	end
	return nil
end

local function log(msg)
	if G.logToConsole then print('^3[spawnguard]^7 ' .. msg) end
end

local function discord(title, body)
	if not Secrets.Webhooks.spawnGuard or Secrets.Webhooks.spawnGuard == '' then return end
	PerformHttpRequest(Secrets.Webhooks.spawnGuard, function() end, 'POST', json.encode({
		embeds = { {
			title = title,
			description = body,
			color = 15158332,
			footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
		} },
	}), { ['Content-Type'] = 'application/json' })
end

-- Rate-limited so one player spamming spawns cannot flood the console or the webhook
local function shouldReport(src)
	local now = os.time()
	local r = recent[src]
	if not r or (now - r.at) > 10 then
		recent[src] = { at = now, n = 1 }
		return true
	end
	r.n = r.n + 1
	return r.n <= 5
end

-- SPAM GUARD: budget per player per window, model-agnostic
local R = G.spam or {}
-- type 2 is vehicles: in RDR2 that is boats, wagons and carriages
local TYPE_PED <const>, TYPE_VEHICLE <const>, TYPE_OBJECT <const> = 1, 2, 3
local burst = {} -- src -> { ped = slot, object = slot }

-- Highest count seen in any one window, per kind; read it with /spawnpeak to tune the caps.
local peaks = {} -- kind -> { n, who, at }

-- consecutive over-budget windows per player, for the kick
local strikes = {} -- src -> { n, at }

local function modeFor(kind)
	local m = R.modes and R.modes[kind]
	return m or R.mode
end

--- @return boolean overBudget, boolean firstBreachThisWindow
local function tickBudget(src, kind, cap, window)
	local b = burst[src]
	if not b then b = {} burst[src] = b end
	local slot = b[kind]
	local now = os.time()
	if not slot or (now - slot.at) >= window then
		b[kind] = { at = now, n = 1, hit = false }
		return false, false
	end
	slot.n = slot.n + 1

	local pk = peaks[kind]
	if not pk or slot.n > pk.n then
		peaks[kind] = { n = slot.n, who = GetPlayerName(src) or '?', at = now }
	end

	if slot.n <= cap then return false, false end
	local first = not slot.hit
	slot.hit = true
	return true, first
end

local function isStaff(owner)
	if not (G.bypassPermission and HasPermission) then return false end
	return HasPermission(owner, G.bypassPermission) == true
end

-- EXPLOSIONS. Cancelled server side before other players see the blast. Needs OneSync.
local X = G.explosion or {}
local boom = {} -- src -> { at, n, hit }

AddEventHandler('explosionEvent', function(sender, ev)
	if not X.enabled then return end
	local src = tonumber(sender)
	if not src or src <= 0 then return end
	if isStaff(src) then return end

	local now = os.time()
	local b = boom[src]
	if not b or (now - b.at) >= (X.windowSeconds or 10) then
		boom[src] = { at = now, n = 1, hit = false }
		return
	end
	b.n = b.n + 1
	if b.n <= (X.perWindow or 5) then return end

	CancelEvent()
	blocked = blocked + 1

	-- one report per window however many they set off
	if not b.hit then
		b.hit = true
		local who = ('%s [%s]'):format(GetPlayerName(src) or '?', src)
		local coords = vector3(tonumber(ev.posX) or 0.0, tonumber(ev.posY) or 0.0, tonumber(ev.posZ) or 0.0)
		local town = townAt(coords)
		local detail = ('%d+ explosions in %ds (type %s) %s'):format(
			X.perWindow or 5, X.windowSeconds or 10, tostring(ev.explosionType),
			town and ('in ' .. town) or ('at %.0f, %.0f'):format(coords.x, coords.y))
		log(('BLOCKED explosion spam by %s - %s'):format(who, detail))
		if RecordFlag then RecordFlag(src, 'spam', detail) end
		discord('Explosion spam blocked', ('**%s** - %s'):format(who, detail))
	end
end)

AddEventHandler('entityCreating', function(entity)
	if not G.enabled then return end

	-- NetworkGetEntityOwner is the client that asked for it. 0/-1 means the server created it, which is our own scripts
	local owner = NetworkGetEntityOwner(entity)
	if not owner or owner <= 0 then return end

	local model = GetEntityModel(entity)
	-- the always list ignores `mode` entirely; the models list obeys it
	local always = G.alwaysBlocked and G.alwaysBlocked[model]
	local label = always or (G.blockedModels and G.blockedModels[model])

	-- runs for every networked entity, so permissions are only checked once a budget is blown
	if R.enabled then
		local etype = GetEntityType(entity)
		local kind = (etype == TYPE_PED and 'ped')
			or (etype == TYPE_VEHICLE and 'vehicle')
			or (etype == TYPE_OBJECT and 'object') or nil
		if kind then
			-- a player legitimately produces one horse or wagon at a time, so the
			-- vehicle budget is far tighter than peds or props
			local cap = (kind == 'ped' and (R.pedPerWindow or 40))
				or (kind == 'vehicle' and (R.vehiclePerWindow or 6))
				or (R.objectPerWindow or 25)
			local over, first = tickBudget(owner, kind, cap, R.windowSeconds or 10)
			if over and not isStaff(owner) then
				local coords = GetEntityCoords(entity)
				local town = townAt(coords)
				local mode = modeFor(kind)
				local cancel = mode == 'everywhere' or (mode == 'towns' and town ~= nil)
				if cancel then
					CancelEvent()
					blocked = blocked + 1
				end
				-- once per window however far over they go: a spammer must not be able to write hundreds of rows into the flag table
				if first then
					local who = ('%s [%s]'):format(GetPlayerName(owner) or '?', owner)
					local where = town and ('in ' .. town) or ('at %.0f, %.0f'):format(coords.x, coords.y)
					local detail = ('%s+ %ss in %ds %s'):format(cap, kind, R.windowSeconds or 10, where)
					log(('%s spam by %s - %s'):format(cancel and 'BLOCKED' or 'observed (mode=' .. tostring(mode) .. ')', who, detail))
					if cancel and R.recordFlag ~= false and RecordFlag then
						RecordFlag(owner, 'spam', detail)
					end
					if cancel then
						discord('Spawn spam blocked', ('**%s** - %s'):format(who, detail))
					end

					-- strikes only count a window we actually acted on
					local K = R.kick or {}
					if cancel and K.enabled then
						local now = os.time()
						local s = strikes[owner]
						-- a quiet minute clears it, so an honest streaming spike never adds up
						if not s or (now - s.at) > ((R.windowSeconds or 10) * 6) then
							s = { n = 0, at = now }
							strikes[owner] = s
						end
						s.n, s.at = s.n + 1, now
						if s.n >= (tonumber(K.afterWindows) or 3) then
							strikes[owner] = nil
							log(('KICKED %s - %d over-budget windows'):format(who, s.n))
							discord('Kicked for entity spam', ('**%s** - %s'):format(who, detail))
							DropPlayer(owner, K.message or 'Kicked for entity spam.')
						end
					end
				end
				if cancel then return end
			end
		end
	end

	if not label then return end
	if isStaff(owner) then return end
	-- a pet this player was already cleared for, server-side
	if grantActive(owner, model) then return end

	local coords = GetEntityCoords(entity)
	local town = townAt(coords)

	local cancel = false
	if always then
		cancel = true -- nowhere is an acceptable place for one of these
	elseif G.mode == 'everywhere' then
		cancel = true
	elseif G.mode == 'towns' then
		cancel = town ~= nil
	end

	if cancel then
		CancelEvent()
		blocked = blocked + 1
	end

	if shouldReport(owner) then
		local who = ('%s [%s]'):format(GetPlayerName(owner) or '?', owner)
		local where = town and ('in ' .. town) or ('at %.0f, %.0f'):format(coords.x, coords.y)
		local verb = cancel and 'BLOCKED' or 'allowed (mode=' .. tostring(G.mode) .. ')'
		log(('%s %s spawned by %s %s'):format(verb, label, who, where))

		-- an animal's owner may just be whoever streamed it in, so only always-list blocks are always flagged
		local report <const> = cancel and (always ~= nil or G.flagBlocks)
		if report and RecordFlag then
			RecordFlag(owner, 'spawn', ('%s %s'):format(label, where))
		end
		if report then
			discord('Spawn blocked', ('**%s** tried to spawn **%s** %s'):format(who, label, where))
		end
	end
end)

-- Catches always-blocked models that got past entityCreating and deletes them.
AddEventHandler('entityCreated', function(entity)
	if not G.enabled or not G.alwaysBlocked then return end
	if not entity or entity == 0 or not DoesEntityExist(entity) then return end

	local label = G.alwaysBlocked[GetEntityModel(entity)]
	if not label then return end

	local owner = NetworkGetEntityOwner(entity)
	if owner and owner > 0 and isStaff(owner) then return end
	if owner and owner > 0 and grantActive(owner, GetEntityModel(entity)) then return end

	DeleteEntity(entity)
	blocked = blocked + 1

	local who = (owner and owner > 0)
		and ('%s [%s]'):format(GetPlayerName(owner) or '?', owner) or 'unknown'
	log(('DELETED %s that got past the spawn guard - owner %s'):format(label, who))
	if owner and owner > 0 and shouldReport(owner) then
		if RecordFlag then RecordFlag(owner, 'spawn', label .. ' (deleted after creation)') end
		discord('Blocked model deleted', ('**%s** - %s was created and has been removed'):format(who, label))
	end
end)

AddEventHandler('playerDropped', function()
	recent[source] = nil
	burst[source] = nil
	grants[source] = nil
	strikes[source] = nil
	boom[source] = nil
end)

-- startup only, so it ignores logToConsole: one line, and it confirms the config loaded
CreateThread(function()
	Wait(3000)
	if not G.enabled then return print('^3[spawnguard]^7 disabled in config') end
	local n, a = 0, 0
	for _ in pairs(G.blockedModels or {}) do n = n + 1 end
	for _ in pairs(G.alwaysBlocked or {}) do a = a + 1 end
	print(('^3[spawnguard]^7 armed - %d models mode=%s, %d blocked everywhere, %d towns'):format(
		n, tostring(G.mode), a, #(G.towns or {})))
	if R.enabled then
		print(('^3[spawnguard]^7 spam guard - peds %d (%s) / vehicles %d (%s) / objects %d (%s) per %ds%s'):format(
			R.pedPerWindow or 40, modeFor('ped'), R.vehiclePerWindow or 6, modeFor('vehicle'),
			R.objectPerWindow or 25, modeFor('object'), R.windowSeconds or 10,
			(R.kick and R.kick.enabled) and (', kick after ' .. (R.kick.afterWindows or 3) .. ' windows') or ''))
	end
end)

-- /spawnpeak - busiest window since restart, per kind, against its cap
RegisterCommand('spawnpeak', function(src)
	src = tonumber(src) or 0
	if src > 0 and not IsPlayerAceAllowed(src, 'command.spawnpeak') then return end

	local caps = { ped = R.pedPerWindow or 40, vehicle = R.vehiclePerWindow or 6, object = R.objectPerWindow or 25 }
	print(('^3[spawnguard]^7 busiest %ds window since restart:'):format(R.windowSeconds or 10))
	for kind, cap in pairs(caps) do
		local pk = peaks[kind]
		if pk then
			print(('  %-8s peak %d (cap %d)%s - %s at %s'):format(
				kind, pk.n, cap, pk.n > cap and '  ^1OVER^7' or '',
				pk.who, os.date('%H:%M:%S', pk.at)))
		else
			print(('  %-8s no data yet (cap %d)'):format(kind, cap))
		end
	end
	if src > 0 then
		TriggerClientEvent('vorp:TipRight', src, 'Spawn peaks printed to the server console.', 5000)
	end
end, false)

exports('spawnGuardBlocked', function() return blocked end)
