-- Export bridge

-- Is the API usable at all?
local function isConfigured()
	return type(Secrets) == 'table' and type(Secrets.Discord) == 'table'
		and type(Secrets.Discord.botToken) == 'string' and Secrets.Discord.botToken ~= ''
		and tostring(Config.Discord.guildId or '') ~= ''
end

-- Role ids for a connected player, or nil when they cannot be determined (nil = unknown, {} = no roles)
exports('GetDiscordRoles', function(source)
	if not isConfigured() then return nil end

	local ok, roles = pcall(GetDiscordRoles, source)
	if not ok or type(roles) ~= 'table' then return nil end

	local out = {}
	for _, id in pairs(roles) do out[#out + 1] = tostring(id) end
	return out
end)

exports('IsDiscordConfigured', isConfigured)

exports('ClearDiscordRoleCache', function(discordId)
	if discordId then pcall(ClearCache, tostring(discordId)) end
end)

CreateThread(function()
	Wait(5000)
	if not isConfigured() then
		print('^3[DiscordQueue]^7 Secrets.Discord.botToken (server/config.lua) / Config.Discord.guildId not set - role lookups return nil.')
	end
end)
