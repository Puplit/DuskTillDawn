-- Modified by Puppet (Dusk Till Dawn), 2026
-- Flag store: what the anti-cheat panel reads

-- the panel is a live log, not an archive
local MAX_LIVE <const>   = 150            -- newest first; the panel never shows more
local LIVE_WINDOW <const> = 2 * 60 * 60   -- seconds a flag stays in the menu
local live = {}
local counts = {} -- charid -> total, across restarts once loaded

-- Drop anything past the window
local function pruneLive()
	local cutoff <const> = os.time() - LIVE_WINDOW
	for i = #live, 1, -1 do
		if (tonumber(live[i].at) or 0) >= cutoff then break end
		table.remove(live, i)
	end
end

CreateThread(function()
	MySQL.query.await([[CREATE TABLE IF NOT EXISTS `vorp_admin_flags` (
		`id` INT NOT NULL AUTO_INCREMENT,
		`charid` INT NULL,
		`identifier` VARCHAR(100) NOT NULL DEFAULT '',
		`name` VARCHAR(100) NOT NULL DEFAULT '',
		`kind` VARCHAR(32) NOT NULL,
		`detail` VARCHAR(255) NOT NULL DEFAULT '',
		`at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
		PRIMARY KEY (`id`),
		KEY `charid` (`charid`),
		KEY `at` (`at`)
	)]])

	-- keep it from growing forever; 30 days is plenty to spot a pattern
	MySQL.query("DELETE FROM vorp_admin_flags WHERE at < NOW() - INTERVAL 30 DAY")

	-- warm the per-character totals so the panel keeps history across restarts
	local rows = MySQL.query.await("SELECT charid, COUNT(*) AS n FROM vorp_admin_flags WHERE charid IS NOT NULL GROUP BY charid")
	for _, r in ipairs(rows or {}) do counts[tonumber(r.charid)] = tonumber(r.n) end

	-- the live list is NOT seeded from the table on purpose
end)

-- keep the window honest on a server that never restarts
CreateThread(function()
	while true do
		Wait(60000)
		pruneLive()
	end
end)

--- kind: 'teleport' | 'noclip' | 'spawn'
function RecordFlag(src, kind, detail)
	local charid, name, identifier
	local ok = pcall(function()
		local user = exports.vorp_core:GetCore().getUser(src)
		local ch = user and user.getUsedCharacter
		if ch then
			charid = tonumber(ch.charIdentifier)
			name = ((ch.firstname or '') .. ' ' .. (ch.lastname or '')):gsub('^%s+', '')
			identifier = ch.identifier
		end
	end)
	if not ok or not name or name == '' then name = GetPlayerName(src) or ('id ' .. tostring(src)) end

	-- the panel shows the Steam name
	local steam = GetPlayerName(src)
	if not steam or steam == '' then steam = name end

	local rec = {
		charid = charid,
		name = steam,      -- what the panel shows
		charName = name,   -- kept so the row can still say who the character was
		kind = kind,
		detail = detail or '',
		at = os.time(),
		serverId = src,
	}

	table.insert(live, 1, rec)
	pruneLive()
	while #live > MAX_LIVE do table.remove(live) end

	if charid then counts[charid] = (counts[charid] or 0) + 1 end

	pcall(function()
		MySQL.insert('INSERT INTO vorp_admin_flags (charid, identifier, name, kind, detail) VALUES (?, ?, ?, ?, ?)',
			{ charid, identifier or '', name, kind, rec.detail })
	end)
end

--- Is the id this flag was raised against STILL the same character?
--- Server ids get recycled, so acting on a stale one would freeze or spectate
--- whoever inherited it. The charid has to match too.
local function stillOnline(f)
	if not f.serverId or not f.charid then return false end
	if not GetPlayerName(f.serverId) then return false end
	local cid
	local ok = pcall(function()
		local user = exports.vorp_core:GetCore().getUser(f.serverId)
		local ch = user and user.getUsedCharacter
		if ch then cid = tonumber(ch.charIdentifier) end
	end)
	return ok and cid ~= nil and cid == f.charid
end

function GetFlags(limit)
	pruneLive() -- so an admin opening the tab never sees a stale row
	local out = {}
	for i = 1, math.min(limit or 50, #live) do
		local f = live[i]
		out[#out + 1] = {
			charid = f.charid, name = f.name, kind = f.kind,
			detail = f.detail, at = f.at, serverId = f.serverId,
			total = f.charid and counts[f.charid] or nil,
			-- drives the Spectate / Freeze buttons on the Anti-Cheat tab
			online = stillOnline(f),
		}
	end
	return out
end

--- total flags ever recorded for a character, for the Players tab badge
function FlagCount(charid)
	return counts[tonumber(charid) or 0] or 0
end

exports('recordFlag', function(src, kind, detail) RecordFlag(src, kind, detail) end)
exports('flagCount', function(charid) return FlagCount(charid) end)

-- panel callback
CreateThread(function()
	local Core = exports.vorp_core:GetCore()

	Core.Callback.Register('vorp_admin:Callback:getFlags', function(source, cb)
		if not HasPermission or not HasPermission(source, 'anticheat_panel') then
			return cb(false)
		end

		local guardMode = (Config.SpawnGuard or {}).mode or 'off'
		local ac = Config.AntiCheat or {}
		cb({
			flags = GetFlags(60),
			guardMode = guardMode,
			spamMode = (Config.SpawnGuard or {}).spam and Config.SpawnGuard.spam.enabled
				and Config.SpawnGuard.spam.mode or 'off',
			guardBlocked = exports.vorp_admin:spawnGuardBlocked(),
			teleportOn = (ac.teleport or {}).enabled == true,
			noclipOn = (ac.noclip or {}).enabled == true,
			freecamOn = (ac.freecam or {}).enabled == true,
			kickOn = (ac.response or {}).kick == true,
			-- "Clear spawned entities" (server/pup_worldCleanup.lua): the button shows only for holders
			canCleanup = (Config.WorldCleanup or {}).enabled ~= false
				and HasPermission(source, (Config.WorldCleanup or {}).permission or 'anticheat_cleanup') == true,
			cleanup = WorldCleanupStatus and WorldCleanupStatus() or nil,
		})
	end)
end)