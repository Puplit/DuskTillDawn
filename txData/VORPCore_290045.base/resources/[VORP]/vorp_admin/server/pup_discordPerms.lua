-- Modified by Puppet (Dusk Till Dawn), 2026
-- Discord role -> permission resolution

local cache = {} -- src -> { perms = {key=true} | 'all', at = os.time(), source = 'discord'|'group' }

-- friendly name ("players.kick") -> internal key ("kick_player")
local aliasToKey, groupKeys = {}, {}
CreateThread(function()
	for group, entries in pairs(Config.DiscordPermissions.permissionGroups or {}) do
		groupKeys[group] = {}
		for name, key in pairs(entries) do
			aliasToKey[group .. '.' .. name] = key
			groupKeys[group][#groupKeys[group] + 1] = key
		end
	end
end)

--- One role's perms list -> a set of internal keys, or the string 'all'.
local function expand(perms, into)
	for _, p in ipairs(perms or {}) do
		p = tostring(p)

		if p == 'all' or p == '*' then return 'all' end

		local group, rest = p:match('^([%w_]+)%.(.+)$')
		if group and rest == '*' then
			for _, key in ipairs(groupKeys[group] or {}) do into[key] = true end
		elseif aliasToKey[p] then
			into[aliasToKey[p]] = true
		else
			into[p] = true -- raw internal key
		end
	end
	return into
end

-- nil = could not ask (no token, no linked Discord, API error)
local function discordRolesOf(src)
	local ok, roles = pcall(function()
		return exports.DiscordQueue:GetDiscordRoles(src)
	end)
	if not ok or type(roles) ~= 'table' then return nil end
	return roles
end

-- Union of every matching role's permissions
local function resolveDiscord(src)
	local roles = discordRolesOf(src)
	if not roles then return nil end

	local set = {}
	for _, roleId in ipairs(roles) do
		local entry = Config.DiscordPermissions.roles[tostring(roleId)]
		if entry then
			local r = expand(entry.perms, set)
			if r == 'all' then return 'all' end
			set = r
		end
	end
	return set
end

-- server.lua's Core is a local, so this file needs its own
local Core
local function core()
	if not Core then
		local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
		if ok and type(c) == 'table' then Core = c end
	end
	return Core
end

--- The VORP group table, used as the fallback.
local function resolveGroup(src)
	local c = core()
	if not c then return nil end

	local user = c.getUser(src)
	if not user then return nil end

	local group = Config.Permissions.useCharacterGroup and user.getUsedCharacter.group or user.getGroup
	local entry = Config.Permissions.groups[group]
	if not entry then return {} end
	if entry.actions.all then return 'all' end

	local set = {}
	for key, allowed in pairs(entry.actions) do
		if allowed then set[key] = true end
	end
	return set
end

local function resolve(src)
	local c = cache[src]
	if c and (os.time() - c.at) < (Config.DiscordPermissions.cacheSeconds or 60) then
		return c.perms, c.source
	end

	local perms, from = nil, 'discord'

	if Config.DiscordPermissions.enabled then
		perms = resolveDiscord(src)
	end

	if perms == nil then
		-- Discord off, unreachable, or the player has no Discord linked.
		if Config.DiscordPermissions.enabled and not Config.DiscordPermissions.fallbackToGroups then
			perms, from = {}, 'denied'
		else
			perms, from = resolveGroup(src) or {}, 'group'
		end
	end

	cache[src] = { perms = perms, at = os.time(), source = from }
	return perms, from
end

-- PUBLIC

-- key is an internal action key ("kick_player") or a friendly name ("players.kick")
function HasPermission(source, key)
	if not source or not key then return false end

	local perms = resolve(source)
	if perms == 'all' then return true end

	key = tostring(key)
	return perms[key] == true or (aliasToKey[key] ~= nil and perms[aliasToKey[key]] == true)
end

-- Every key this player holds, for filtering a menu in one pass instead of calling HasPermission once per row
function PermissionSet(source)
	local perms, from = resolve(source)
	return perms, from
end

function ClearPermissionCache(source)
	if source then cache[source] = nil else cache = {} end
end

exports('hasPermission', function(source, key) return HasPermission(source, key) end)
exports('clearPermissionCache', function(source) ClearPermissionCache(source) end)

AddEventHandler('playerDropped', function() cache[source] = nil end)

RegisterCommand('adminperms', function(src)
	if src == 0 then return print('run this in-game') end
	if not HasPermission(src, 'open_menu') then return end

	local perms, from = PermissionSet(src)
	print(('^3[vorp_admin]^7 %s resolved from: %s'):format(GetPlayerName(src), from))
	if perms == 'all' then return print('   ALL permissions') end

	local n = 0
	for k in pairs(perms) do print('   ' .. k); n = n + 1 end
	if n == 0 then print('   (none)') end
end, false)
