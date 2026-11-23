-- Discord API (Badger_Discord_API by JaredScar - MIT)
local FormattedToken = "Bot " .. tostring(Secrets.Discord and Secrets.Discord.botToken or "")

local error_codes_defined = {
	[200] = 'OK - The request was completed successfully..!',
	[204] = 'OK - No Content',
	[400] = "Error - The request was improperly formatted, or the server couldn't understand it..!",
	[401] = 'Error - The Authorization header was missing or invalid..! Your Discord Token is probably wrong or does not have correct permissions attributed to it.',
	[403] = 'Error - The Authorization token you passed did not have permission to the resource..! Your Discord Token is probably wrong or does not have correct permissions attributed to it.',
	[404] = "Error - The resource at the location specified doesn't exist.",
	[429] = 'Error - Too many requests, you hit the Discord rate limit. https://discord.com/developers/docs/topics/rate-limits',
	[502] = 'Error - Discord API may be down?...'
};

function sendDebugMessage(msg)
	print("^1[^5Badger_Discord_API^1] ^3" .. msg);
end

tracked = {}

function GetIdentifier(source, id_type)
    if type(id_type) ~= "string" then return; end
    for _, identifier in pairs(GetPlayerIdentifiers(source)) do
        if string.find(identifier, id_type) then
            return identifier
        end
    end
    return nil
end

function GetGuildId (guildName)
  local result = tostring(Config.Discord.guildId)
  if guildName and Config.Discord.guilds[guildName] then
    result = tostring(Config.Discord.guilds[guildName])
  end
  return result
end

function DiscordRequest(method, endpoint, jsondata, reason)
    local data = nil
    PerformHttpRequest("https://discord.com/api/"..endpoint, function(errorCode, resultData, resultHeaders)
		data = {data=resultData, code=errorCode, headers=resultHeaders}
    end, method, #jsondata > 0 and jsondata or "", {["Content-Type"] = "application/json", ["Authorization"] = FormattedToken, ['X-Audit-Log-Reason'] = reason})

    while data == nil do
        Citizen.Wait(0)
    end
	
    return data
end

function GetRoleIdFromRoleName(name, guild --[[optional]])
  local guildId = GetGuildId(guild)
	if (Caches.RoleList[guildId] ~= nil) then 
		return tonumber(Caches.RoleList[guildId][name]);
	else 
		local roles = GetGuildRoleList(guild);
		return tonumber(roles[name]);
	end
end

function FetchRoleID(roleID2Check, guild --[[optional]])
    -- You gave me an ID, here it is back to you.
    if type(roleID2Check) == "number" then return roleID2Check end
    -- You gave me a non-string, non-number. I can't help you.
    if type(roleID2Check) ~= "string" then return nil end

	if type(roleID2Check) == "string" then 
		if (tonumber(roleID2Check) ~= nil) then 
			return tonumber(roleID2Check);
		end
	end

    -- It's a string, therefore name -- search config rolelist
    local rolesListFromConfig = Config.Discord.roleList
    if rolesListFromConfig[roleID2Check] then
      -- It's a named role in the config. Here you go!
      return tonumber(rolesListFromConfig[roleID2Check])
    end
    -- Oops, didn't find in config rolelist, search by name in current guild
    if (guild ~= nil) then 
        local fetchedRolesList = GetGuildRoleList(guild)
        if fetchedRolesList[roleID2Check] then
			-- We found it in the current guild. Here you go!
	    	return tonumber(fetchedRolesList[roleID2Check])
		end
    end
    -- Okay, still no luck. Search Main guild for role by name (if main isn't current guild)
    if GetGuildId(guild) ~= tostring(Config.Discord.guildId) then
    	local mainRolesList = GetGuildRoleList()
    	if mainRolesList[roleID2Check] then
        	-- We found it in the current guild. Here you go!
        	return tonumber(mainRolesList[roleID2Check])
      	end
    end
    -- Big oops, didn't find in current guild, or main guild. Search by name in all guilds!
    --[[
    -- Due to a security flaw in the below code, it was redacted for good reason...
    if (Config.Discord.multiguild and not roleFound) then
      for guildName, guildID in pairs(Config.Discord.guilds) do
        local thisRolesList = GetGuildRoleList(guildName)
        if thisRolesList[roleID2Check] then
          -- We found it in the current guild. Here you go!
          return tonumber(thisRolesList[roleID2Check])
        end
      end
    end
    ]]--
    return nil -- Sorry, couldn't find anywhere
end

function CheckEqual(role1, role2, guild --[[optional]])
    local roleID1 = FetchRoleID(role1, guild);
    local roleID2 = FetchRoleID(role2, guild);
	-- If they are the same exact name or ID & same type, they are equal
    if (type(roleID1) ~= "nil" and type(roleID2) ~= "nil") and roleID1 == roleID2 then
		return true
    end
	-- If they can be forced to number and they are the same ID, they are equal
    if ((tonumber(roleID1) ~= nil) and (tonumber(roleID1) == tonumber(roleID2))) then
        return true
    end

    return false
end

function IsDiscordEmailVerified(user) 
    local discordId = nil
    local isVerified = false;
    for _, id in ipairs(GetPlayerIdentifiers(user)) do
        if string.match(id, "discord:") then
            discordId = string.gsub(id, "discord:", "")
            break
        end
    end
    if discordId then 
        local endpoint = ("users/%s"):format(discordId)
        local member = DiscordRequest("GET", endpoint, {})
        if member.code == 200 then
            local data = json.decode(member.data)
            if data ~= nil then 
                -- It is valid data 
                isVerified = data.verified;
            end
        else 
        	sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. DETAILS: " .. error_codes_defined[member.code]);
        end
    end
    return isVerified;
end

function GetDiscordEmail(user) 
    local discordId = nil
    local emailData = nil;
    for _, id in ipairs(GetPlayerIdentifiers(user)) do
        if string.match(id, "discord:") then
            discordId = string.gsub(id, "discord:", "")
            break
        end
    end
    if discordId then 
        local endpoint = ("users/%s"):format(discordId)
        local member = DiscordRequest("GET", endpoint, {})
        if member.code == 200 then
            local data = json.decode(member.data)
            if data ~= nil then 
                -- It is valid data 
                emailData = data.email;
            end
        else 
        	sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. DETAILS: " .. error_codes_defined[member.code])
        end
    end
    return emailData;
end

function GetDiscordName(user) 
    local discordId = nil
    local nameData = nil;
    for _, id in ipairs(GetPlayerIdentifiers(user)) do
        if string.match(id, "discord:") then
            discordId = string.gsub(id, "discord:", "")
            break
        end
    end
    if discordId then 
        local endpoint = ("users/%s"):format(discordId)
        local member = DiscordRequest("GET", endpoint, {})
        if member.code == 200 then
            local data = json.decode(member.data)
            if data ~= nil then 
			-- It is valid data 
			if data.discriminator == 0 or data.discriminator == "0" then 
				return data.username 
			end			
				nameData = data.username .. "#" .. data.discriminator;
			end
		else 
			sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. DETAILS: " .. error_codes_defined[member.code])
		end
    end
    return nameData;
end

function GetGuildIcon(guild --[[optional]])
  local guildId = GetGuildId(guild)
	local guild = DiscordRequest("GET", "guilds/"..guildId, {})
	if guild.code == 200 then
		local data = json.decode(guild.data)
		if (data.icon:sub(1, 1) and data.icon:sub(2, 2) == "_") then 
			-- It's a gif 
			return 'https://cdn.discordapp.com/icons/' .. Config.Discord.guildId .. "/" .. data.icon .. ".gif";
		else 
			-- Image 
			return 'https://cdn.discordapp.com/icons/' .. Config.Discord.guildId .. "/" .. data.icon .. ".png";
		end 
	else
		sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(guild.data or guild.code)) 
	end
	return nil;
end

function GetGuildSplash(guild --[[optional]])
  local guildId = GetGuildId(guild)
	local guild = DiscordRequest("GET", "guilds/"..guildId, {})
	if guild.code == 200 then
		local data = json.decode(guild.data)
		-- Image 
		return 'https://cdn.discordapp.com/splashes/' .. Config.Discord.guildId .. "/" .. data.icon .. ".png";
	else
		sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(guild.data or guild.code)) 
	end
	return nil;
end 

function GetGuildName(guild --[[optional]])
  local guildId = GetGuildId(guild)
	local guild = DiscordRequest("GET", "guilds/"..guildId, {})
	if guild.code == 200 then
		local data = json.decode(guild.data)
		-- Image 
		return data.name;
	else
		sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(guild.data or guild.code)) 
	end
	return nil;
end

function GetGuildDescription(guild --[[optional]])
  local guildId = GetGuildId(guild)
	local guild = DiscordRequest("GET", "guilds/"..guildId, {})
	if guild.code == 200 then
		local data = json.decode(guild.data)
		-- Image 
		return data.description;
	else
		sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(guild.data or guild.code)) 
	end
	return nil;
end

function GetGuildMemberCount(guild --[[optional]])
  local guildId = GetGuildId(guild)
	local guild = DiscordRequest("GET", "guilds/"..guildId.."?with_counts=true", {})
	if guild.code == 200 then
		local data = json.decode(guild.data)
		-- Image 
		return data.approximate_member_count;
	else
		sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(guild.data or guild.code)) 
	end
	return nil;
end

function GetGuildOnlineMemberCount(guild --[[optional]])
  local guildId = GetGuildId(guild)
	local guild = DiscordRequest("GET", "guilds/"..guildId.."?with_counts=true", {})
	if guild.code == 200 then
		local data = json.decode(guild.data)
		return data.approximate_presence_count;
	else
		sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(guild.data or guild.code)) 
	end
	return nil;
end

function GetDiscordAvatar(user) 
    local discordId = nil
    local imgURL = nil;
    for _, id in ipairs(GetPlayerIdentifiers(user)) do
        if string.match(id, "discord:") then
            discordId = string.gsub(id, "discord:", "")
            break
        end
	end
	if discordId then 
		if Caches.Avatars[discordId] == nil then 
			local endpoint = ("users/%s"):format(discordId)
			local member = DiscordRequest("GET", endpoint, {})
			if member.code == 200 then
				local data = json.decode(member.data)
				if data ~= nil and data.avatar ~= nil then 
					-- It is valid data 
					if (data.avatar:sub(1, 1) and data.avatar:sub(2, 2) == "_") then 
						imgURL = "https://cdn.discordapp.com/avatars/" .. discordId .. "/" .. data.avatar .. ".gif";
					else 
						imgURL = "https://cdn.discordapp.com/avatars/" .. discordId .. "/" .. data.avatar .. ".png"
					end
				end
			else 
				sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. DETAILS: " .. error_codes_defined[member.code])
			end
			Caches.Avatars[discordId] = imgURL;
		else 
			imgURL = Caches.Avatars[discordId];
		end 
	else 
		sendDebugMessage("[Badger_Discord_API] ERROR: Discord ID was not found...")
	end
    return imgURL;
end

Caches = {
	Avatars = {},
  RoleList = {}
}
function ResetCaches()
	Caches = {
    Avatars = {},
    RoleList = {},
  };
end

function GetGuildRoleList(guild --[[optional]])
  local guildId = GetGuildId(guild)
	if (Caches.RoleList[guildId] == nil) then 
		local guild = DiscordRequest("GET", "guilds/"..guildId, {})
		if guild.code == 200 then
			local data = json.decode(guild.data)
			-- Image 
			local roles = data.roles;
			local roleList = {};
			for i = 1, #roles do 
				roleList[roles[i].name] = roles[i].id;
			end
			Caches.RoleList[guildId] = roleList;
		else
			sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(guild.data or guild.code)) 
			Caches.RoleList[guildId] = nil;
		end
	end
	return Caches.RoleList[guildId];
end

recent_role_cache = {}

function ClearCache(discordId) 
	if (discordId ~= nil) then 
		recent_role_cache[discordId] = {};
	end
end

function GetDiscordRoles(user, guild --[[optional]])
  local discordId = nil
  local guildId = GetGuildId(guild)
  local roles = nil
	for _, id in ipairs(GetPlayerIdentifiers(user)) do
		if string.match(id, "discord:") then
			discordId = string.gsub(id, "discord:", "")
			break;
		end
	end

	if discordId then
		-- Get roles for specified guild (or main guild if not specified)
		roles = GetUserRolesInGuild(discordId, guildId)
		-- If specified guild or disabled multiguild option, just return this one
		if guild or Config.Discord.multiguild == false then
			return roles
		end

		-- MULTIGUILD SECTION
		
		-- For some reason, referencing roles again will use the global reference that is returned... because of that
		resetRoles = {}
		for _, role_id in pairs(roles) do 
			table.insert(resetRoles, role_id);
		end
		roles = resetRoles
		local checkedGuilds = {}
		-- Loop through guilds in config and get the roles from each one.
		for _,id in pairs(Config.Discord.guilds) do
			-- If it's the main guild, we already fetched these roles
			if tostring(id) == guildId then goto skip end
			if checkedGuilds[id] then goto skip end
			-- Fetch roles for this guild
			local guildRoles = GetUserRolesInGuild(discordId, id)
			checkedGuilds[id] = true
			-- If it didnt return false due to error, add the roles to the list
			if type(guildRoles) == "table" then
				-- Insert each role into roles list
				for _,v in pairs(guildRoles) do
					table.insert(roles, v)
				end
			end
			::skip::
		end
		return roles
	else
		sendDebugMessage("[Badger_Discord_API] ERROR: Discord was not connected to user's Fivem account...")
		return false
	end
	return false
end

function GetUserRolesInGuild (user, guild)
	-- Error check before starting operation
	if not user then
		sendDebugMessage("[Badger_Discord_API] ERROR: GetUserRolesInGuild requires discord ID")
		return false
	end
	if not guild or tostring(guild) == '' then
		sendDebugMessage("[Badger_Discord_API] ERROR: GetUserRolesInGuild requires guild ID")
		return false
	end
	-- not set up yet (no bot token): skip the request instead of asking Discord
	if not (Secrets.Discord and Secrets.Discord.botToken and Secrets.Discord.botToken ~= '') then
		return false
	end

	-- Check for cached roles
	if Config.Discord.cacheRoles and recent_role_cache[user] and recent_role_cache[user][guild] then
		return recent_role_cache[user][guild]
	end

	-- Request roles for user id
	local endpoint = ("guilds/%s/members/%s"):format(guild, user)
	local member = DiscordRequest("GET", endpoint, {})
	if member.code == 200 then
		local data = json.decode(member.data)
		local roles = data.roles
		if Config.Discord.cacheRoles then
			recent_role_cache[user] = recent_role_cache[user] or {}
			recent_role_cache[user][guild] = roles
			Citizen.SetTimeout(((Config.Discord.cacheRolesSeconds or 60)*1000), function() recent_role_cache[user][guild] = nil end)
		end
		return roles
	else
		sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached... Returning false. [Member Data NOT FOUND] DETAILS: " .. tostring(error_codes_defined[member.code] or member.code))
		return false
	end
end

function GetDiscordNickname(user, guild --[[optional]])
  local discordId = nil
  local guildId = GetGuildId(guild)
	for _, id in ipairs(GetPlayerIdentifiers(user)) do
		if string.match(id, "discord:") then
			discordId = string.gsub(id, "discord:", "")
			break
		end
	end

	if discordId then
		local endpoint = ("guilds/%s/members/%s"):format(guildId, discordId)
		local member = DiscordRequest("GET", endpoint, {})
		if member.code == 200 then
			local data = json.decode(member.data)
			local nickname = data.nick
			return nickname;
		else
			sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. Error Code: " .. error_codes_defined[member.code])
			return nil;
		end
	else
		sendDebugMessage("[Badger_Discord_API] ERROR: Discord was not connected to user's Fivem account...")
		return nil;
	end
	return nil;
end

function SetNickname(user, nickname, reason)
	local discordId = nil
	for _, id in ipairs(GetPlayerIdentifiers(user)) do
		if string.match(id, 'discord:') then
			discordId = string.gsub(id, 'discord:', '')
			break
		end
	end

	if discordId then
		local name = nickname or ""
		local endpoint = ("guilds/%s/members/%s"):format(Config.Discord.guildId, discordId)
		local member = DiscordRequest("PATCH", endpoint, json.encode({nick = tostring(name)}), reason)
		if member.code ~= 200 and member.code ~= 204 then
			sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. Error Code: " .. error_codes_defined[member.code])
		end
	end
end

function AddRole(user, roleId, reason)
	local discordId = nil
	for _, id in ipairs(GetPlayerIdentifiers(user)) do
		if string.match(id, 'discord:') then
			discordId = string.gsub(id, 'discord:', '')
			break
		end
	end

	if discordId then
		local roles = GetDiscordRoles(user) or {}
		local endpoint = ("guilds/%s/members/%s"):format(Config.Discord.guildId, discordId)
		table.insert(roles, roleId)
		local member = DiscordRequest("PATCH", endpoint, json.encode({roles = roles}), reason)
		if member.code ~= 200 then
			sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. Error Code: " .. error_codes_defined[member.code])
		end
	end
end

function RemoveRole(user, roleId, reason)
	local discordId = nil
	for _, id in ipairs(GetPlayerIdentifiers(user)) do
		if string.match(id, 'discord:') then
			discordId = string.gsub(id, 'discord:', '')
			break
		end
	end

	if discordId then
		local roles = GetDiscordRoles(user) or {}
		local endpoint = ("guilds/%s/members/%s"):format(Config.Discord.guildId, discordId)

		for k, v in pairs(roles) do
			if v == roleId then
				roles[k] = nil
			end
		end

		local member = DiscordRequest("PATCH", endpoint, json.encode({roles = roles}), reason)
		if member.code ~= 200 then
			sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. Error Code: " .. error_codes_defined[member.code])
		end
	end
end

function SetRoles(user, roleList, reason)
	local discordId = nil
	for _, id in ipairs(GetPlayerIdentifiers(user)) do
		if string.match(id, 'discord:') then
			discordId = string.gsub(id, 'discord:', '')
			break
		end
	end

	if discordId then
		local endpoint = ("guilds/%s/members/%s"):format(Config.Discord.guildId, discordId)
		local member = DiscordRequest("PATCH", endpoint, json.encode({roles = roleList}), reason)
		if member.code ~= 200 then
			sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. Error Code: " .. error_codes_defined[member.code])
		end
	end
end

function ChangeDiscordVoice(user, voice, reason)
	local discordId = nil
	for _, id in ipairs(GetPlayerIdentifiers(user)) do
		if string.match(id, "discord:") then
			discordId = string.gsub(id, "discord:", "")
		end
	end

	if discordId then
		local endpoint = ("guilds/%s/members/%s"):format(Config.Discord.guildId, discordId)
		local member = DiscordRequest("PATCH", endpoint, json.encode({channel_id = voice}), reason)
		if member.code ~= 200 then
			sendDebugMessage("[Badger_Discord_API] ERROR: Code 200 was not reached. Error Code: " .. error_codes_defined[member.code])
		end
	end
end

Citizen.CreateThread(function()
  local mguild = DiscordRequest("GET", "guilds/"..Config.Discord.guildId, {})
  if mguild.code == 200 then
    local data = json.decode(mguild.data)
    sendDebugMessage("[Badger_Discord_API] Successful connection to Guild : "..data.name.." ("..data.id..")")
  else
    sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(mguild.data and json.decode(mguild.data) or mguild.code)) 
  end
  if (Config.Discord.multiguild) then 
    for _,guildID in pairs(Config.Discord.guilds) do
      local guild = DiscordRequest("GET", "guilds/"..guildID, {})
      if guild.code == 200 then
        local data = json.decode(guild.data)
        sendDebugMessage("[Badger_Discord_API] Successful connection to Guild : "..data.name.." ("..data.id..")")
      else
        sendDebugMessage("[Badger_Discord_API] An error occured, please check your config and ensure everything is correct. Error: "..(guild.data and json.decode(guild.data) or guild.code)) 
      end
    end
  end
end)
