-- Modified by Puppet (Dusk Till Dawn), 2026
-- Movement flag handler

local AC = Config.AntiCheat or {}
local R = AC.response or {}
local recent = {}

-- Holding any key in the list exempts
local function isExempt(src, kind)
	if not HasPermission then return false end
	local E = AC.exempt or {}

	for _, key in ipairs(E.any or {}) do
		if HasPermission(src, key) then return true end
	end
	for _, key in ipairs(E[kind] or {}) do
		if HasPermission(src, key) then return true end
	end
	return false
end

local function pushExempt(src)
	TriggerClientEvent('vorp_admin:ac:setExempt', src, {
		teleport = isExempt(src, 'teleport'),
		noclip   = isExempt(src, 'noclip'),
	})
end

RegisterNetEvent('vorp_admin:ac:amIExempt', function()
	pushExempt(source)
end)

-- perms can change mid-session (role added, cache expiry) - re-push
exports('refreshAntiCheatExempt', function(src) pushExempt(src) end)

local function discord(title, body)
	local hook = Secrets.Webhooks.spawnGuard
	if not hook or hook == '' then return end
	PerformHttpRequest(hook, function() end, 'POST', json.encode({
		embeds = { { title = title, description = body, color = 15105570,
			footer = { text = os.date('%Y-%m-%d %H:%M:%S') } } },
	}), { ['Content-Type'] = 'application/json' })
end

RegisterNetEvent('vorp_admin:ac:flag', function(kind, data)
	local src = source
	if type(kind) ~= 'string' or type(data) ~= 'table' then return end

	-- re-checked server-side against the SAME capability the flag is about: the client decides when to report
	if isExempt(src, kind) then return end

	-- one player cannot spam the log or the webhook
	local now = os.time()
	local r = recent[src]
	if r and (now - r.at) < 15 then
		r.n = r.n + 1
		if r.n > 3 then return end
	else
		recent[src] = { at = now, n = 1 }
		r = recent[src]
	end

	local name = ('%s [%s]'):format(GetPlayerName(src) or '?', src)
	local detail
	if kind == 'teleport' then
		detail = ('%dm in %.1fs (%.0f m/s)'):format(data.dist or 0, data.secs or 0, data.speed or 0)
	elseif kind == 'freecam' then
		-- speed is meaningless here: the ped is not moving, the camera is
		detail = ('camera %.0fm from body, held %.1fs'):format(data.dist or 0, data.secs or 0)
	else
		detail = ('%.1fm in %.2fs (%.0f m/s)'):format(data.dist or 0, data.secs or 0, data.speed or 0)
	end

	local where = ''
	if type(data.to) == 'table' or type(data.to) == 'vector3' then
		local t = data.to
		where = (' at %.0f, %.0f'):format(t.x or 0, t.y or 0)
	end

	if RecordFlag then RecordFlag(src, kind, detail .. where) end

	discord(('Movement flag: %s'):format(kind), ('**%s**\n%s%s\nstrike %d in this window'):format(name, detail, where, r.n))

	-- opt-in only
	if R.kick and r.n >= (R.kickAfterFlags or 3) then
		DropPlayer(src, R.kickMessage or 'Movement check failed. Open a ticket if this was a mistake.')
	end
end)

AddEventHandler('playerDropped', function() recent[source] = nil end)

CreateThread(function()
	Wait(3000)
	local on = {}
	if (AC.teleport or {}).enabled then on[#on + 1] = 'teleport' end
	if (AC.noclip or {}).enabled then on[#on + 1] = 'noclip' end
	if #on == 0 then return print('^3[anticheat]^7 both detectors disabled') end
	print(('^3[anticheat]^7 armed - %s, response=%s'):format(table.concat(on, ' + '), R.kick and 'KICK' or 'log only'))
end)
