Queue = {}
Queue.Players = {}
Queue.PlayerInfo = {}
Queue.SortedKeys = {}
Queue.Messages = {}
debugg = false;

-- CRASH PRIORITY
Queue.Activated = {}    -- [license] = true while they are past the queue and in-session
Queue.RecentDrops = {}  -- [license] = os.time() of an IN-SESSION disconnect

-- best (lowest) priority anyone can hold from Config.RolePriority
local function bestConfiguredPrio()
	local best = tonumber(Config.Queue.defaultPriority) or 200
	for _, list in pairs(Config.RolePriority or {}) do
		local p = tonumber(list.priority)
		if p and p < best then best = p end
	end
	return best
end

function Queue:MarkActivated(license)
	if license then Queue.Activated[license] = true end
end

-- Called from playerDropped
function Queue:NoteDrop(license)
	if not license then return end
	local cfg = Config.CrashPriority
	if not cfg or not cfg.enabled then
		Queue.Activated[license] = nil
		return
	end
	if Queue.Activated[license] then
		Queue.RecentDrops[license] = os.time()
	end
	Queue.Activated[license] = nil
end

-- Returns the priority improvement this license has earned
function Queue:TakeCrashBonus(license)
	local cfg = Config.CrashPriority
	if not cfg or not cfg.enabled or not license then return 0 end
	local at = Queue.RecentDrops[license]
	if not at then return 0 end
	Queue.RecentDrops[license] = nil
	if (os.time() - at) > (tonumber(cfg.windowSeconds) or 300) then return 0 end
	return tonumber(cfg.bonus) or 0
end

-- Apply the bonus to the BASE priority, not the stored value
function Queue:ApplyCrashBonus(license, queueIndex)
	local bonus = Queue:TakeCrashBonus(license)
	if bonus <= 0 then return false end
	local current = tonumber(Queue.Players[license])
	if not current then return false end
	local base = current - (tonumber(queueIndex) or 0)
	-- floor is one step BELOW the top tier, not equal to it: at an equal base the queueIndex tiebreak decides
	local improved = math.max(bestConfiguredPrio() + 1, base - bonus)
	if improved >= base then return false end -- already better than the boost
	Queue.Players[license] = improved + (tonumber(queueIndex) or 0)
	return true
end



function getKeysSortedByValue(tbl, sortFunction)
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end

  table.sort(keys, function(a, b)
    return sortFunction(tbl[a], tbl[b])
  end)

  return keys
end

function Queue:Contains(license)
    if Queue.Players[license] ~= nil then 
        return true;
    end
    return false;
end

function Queue:IsWhitelisted(user)
	local discordId = nil;
	local license = nil;

	for _, id in ipairs(GetPlayerIdentifiers(user)) do
	    if string.match(id, "discord:") then
	        discordId = string.gsub(id, "discord:", "")
	        --print("Found discord id: "..discordId)
	    end
	    if string.match(id, "license:") then 
	    	license = string.gsub(id, "license:", "")
	    end
	end
	local identifierDiscord = discordId;

	if identifierDiscord then
		local roles = GetDiscordRoles(user);
		if not (roles == false) then 
			for i = 1, #roles do 
				for roleID, list in pairs(Config.RolePriority) do
					if CheckEqual(roles[i], roleID) then 
						return true;
					end
				end
			end
		end
	end
	return false;
end

queueIndex = 0;
function Queue:SetupPriority(user) 
	local discordId = nil;
	local license = nil;

	for _, id in ipairs(GetPlayerIdentifiers(user)) do
	    if string.match(id, "discord:") then
	        discordId = string.gsub(id, "discord:", "")
	        --print("Found discord id: "..discordId)
	    end
	    if string.match(id, "license:") then 
	    	license = string.gsub(id, "license:", "")
	    end
	end
	if license ~= nil then 
		-- Reset their account
		Queue.Players[license] = nil;
		local identifierDiscord = discordId;
		queueIndex = queueIndex + 1;
		theirPrios = {};
		msgs = {};
		--local roleName = (unused default role name);
		local roleName = '';
		if identifierDiscord and (Queue.Players[license] == nil) then
			local roles = GetDiscordRoles(user)
			local lastRolePrio = 99999999999999999999;
			local msg = nil;
			if not (roles == false) then
				for i = 1, #roles do
					for roleID, list in pairs(Config.RolePriority) do
						local rolePrio = list.priority;
						if CheckEqual(roles[i], roleID) then
							-- Return the index back to the Client script
							table.insert(theirPrios, rolePrio);
							if lastRolePrio > tonumber(rolePrio) then 
								msg = list.message;
								lastRolePrio = rolePrio;
								--roleName = list[3]; -- Only for AdaptiveCards version
							end 
						end
					end
				end
			else
				Queue.Players[license] = tonumber(Config.Queue.defaultPriority) + queueIndex;;
				Queue.Messages[license] = Locale.connecting;
			end
			if #theirPrios > 0 then 
				table.sort(theirPrios);
				Queue.Players[license] = tonumber(theirPrios[1])  + queueIndex;
			end 
			if msg ~= nil then 
				Queue.Messages[license] = msg;
			end
		elseif identifierDiscord == nil then
			Queue.Players[license] = tonumber(Config.Queue.defaultPriority) + queueIndex;
			Queue.Messages[license] = Locale.connecting;
		end
		if Queue.Players[license] == nil then 
			Queue.Players[license] = tonumber(Config.Queue.defaultPriority) + queueIndex;
		end
		if Queue.Messages[license] == nil then
			Queue.Messages[license] = Locale.connecting;
		end
		-- crash priority, applied AFTER every branch above has settled a value so it works for role holders
		if Queue:ApplyCrashBonus(license, queueIndex) then
			if Locale.crashPriority then
				Queue.Messages[license] = Locale.crashPriority;
			end
			if Config.General.debug then
				print(("[DiscordQueue] crash priority applied to %s -> %s"):format(license, tostring(Queue.Players[license])));
			end
		end
		local SortedKeys = getKeysSortedByValue(Queue.Players, function(a, b) return a < b end)
		Queue.SortedKeys = SortedKeys;
		local username = GetPlayerName(user);
		if identifierDiscord then 
			local discordName = GetDiscordName(user);
			Queue.PlayerInfo[license] = { username, Queue.Players[license], roleName, discordName};
		else 
			Queue.PlayerInfo[license] = { username, Queue.Players[license], roleName };
		end 
		if debugg then 
			for identifier, data in pairs(Queue.PlayerInfo) do 
				--print("[DEBUG] " .. tostring(data[1]) .. " has priority of: " .. tostring(data[2]) );
			end
		end 
	end -- License == nil, don't run
end
function GetMessage(user)
	local discordId = nil;
	local license = nil;

	for _, id in ipairs(GetPlayerIdentifiers(user)) do
	    if string.match(id, "discord:") then
	        discordId = string.gsub(id, "discord:", "")
	        --print("Found discord id: "..discordId)
	    end
	    if string.match(id, "license:") then 
	    	license = string.gsub(id, "license:", "")
	    end
	end
	local msg = Locale.connecting;
	if (Queue.Messages[license] ~= nil) then 
		return Queue.Messages[license];
	else 
		return msg;
	end
end

function Queue:IsSetUp(user)
	local discordId = nil;
	local license = nil;

	for _, id in ipairs(GetPlayerIdentifiers(user)) do
	    if string.match(id, "discord:") then
	        discordId = string.gsub(id, "discord:", "")
	        --print("Found discord id: "..discordId)
	    end
	    if string.match(id, "license:") then 
	    	license = string.gsub(id, "license:", "")
	    end
	end
	if (Queue.Players[license] ~= nil) then 
		return true;
	end 
	return false;
end

function Queue:CheckQueue(user, currentConnectors, slots) 
	local discordId = nil;
	local license = nil;

	for _, id in ipairs(GetPlayerIdentifiers(user)) do
	    if string.match(id, "discord:") then
	        discordId = string.gsub(id, "discord:", "")
	        --print("Found discord id: "..discordId)
	    end
	    if string.match(id, "license:") then 
	    	license = string.gsub(id, "license:", "")
	    end
	end
	if (tostring(Queue.SortedKeys[1]) == tostring(license) ) then 
		return true; -- They can login 
	end
	-- Added 12/10/20
	--[[]]-- 120 - 72 - 30 = 18
	local openSlots = (slots - GetNumPlayerIndices()) - currentConnectors;
	local count = 1;
	for k, v in pairs(Queue.SortedKeys) do 
		if Queue.SortedKeys[count] == license and count <= openSlots then 
			return true;
		end
		count = count + 1;
	end
	--[[]]--
	-- End add
	return false; -- Still waiting in queue, not next in line 
end 

function Queue:GetMax()
	local cout = 0;
	for identifier, prio in pairs(Queue.Players) do 
		cout = cout + 1;
	end
	return cout;
end

function Queue:GetQueueNum(user)
	local discordId = nil;
	local license = nil;
	for _, id in ipairs(GetPlayerIdentifiers(user)) do
	    if string.match(id, "discord:") then
	        discordId = string.gsub(id, "discord:", "")
	        --print("Found discord id: "..discordId)
	    end
	    if string.match(id, "license:") then 
	    	license = string.gsub(id, "license:", "")
	    end
	end
	local cout = 1;
	for i = 1, #Queue.SortedKeys do 
		local identifier = Queue.SortedKeys[i];
		if identifier == license then 
			return cout;
		end
		cout = cout + 1;
	end
	return 1;
end

function Queue:PopLicense(license)
	-- Pop them off the Queue 
	local tempQueue = {};
	lic = license:gsub("license:", "");
	--[[
	for id, prio in pairs(Queue.Players) do 
		if tostring(id) ~= tostring(lic) then 
			tempQueue[id] = prio;
		end
	end
	]]--
	Queue.Messages[lic] = nil;
	Queue.Players[lic] = nil;
	--Queue.Players = tempQueue;
	Queue.PlayerInfo[lic] = nil;
	if debugg then 
		--print("[DEBUG] " .. tostring(lic) .. " has been POPPED from QUEUE")
    end
	local SortedKeys = getKeysSortedByValue(Queue.Players, function(a, b) return a < b end)
    Queue.SortedKeys = SortedKeys;
end

function Queue:GetUserAt(index)
	local licenseKey = Queue.SortedKeys[index];
	if licenseKey ~= nil and Queue.PlayerInfo[licenseKey] ~= nil then 
		local playerInfo = Queue.PlayerInfo[licenseKey];
		local name = playerInfo[1];
		local roleName = playerInfo[3];
		if #playerInfo == 4 then 
			local discordName = playerInfo[4] 
			return {name, roleName, discordName};
		else 
			return {name, roleName};
		end
	end
	return false; -- None there 
end

function Queue:Pop(user)
	-- Pop them off the Queue 
	local lic = nil;

	for _, id in ipairs(GetPlayerIdentifiers(user)) do
	    if string.match(id, "license:") then 
	    	lic = string.gsub(id, "license:", "")
	    end
	end
	local tempQueue = {};
	--[[
	for id, prio in pairs(Queue.Players) do 
		if tostring(id) ~= tostring(lic) then 
			tempQueue[id] = prio;
		end
	end
	]]--
	Queue.Messages[lic] = nil;
	Queue.Players[lic] = nil;
	--Queue.Players = tempQueue;
	Queue.PlayerInfo[lic] = nil;
	local SortedKeys = getKeysSortedByValue(Queue.Players, function(a, b) return a < b end)
    Queue.SortedKeys = SortedKeys;
    if debugg then 
    	--print("[DEBUG] " .. GetPlayerName(user) .. " has been POPPED from QUEUE")
    end
    if debugg then 
	    for identifier, data in pairs(Queue.PlayerInfo) do 
	    	--print("[DEBUG] " .. tostring(data[1]) .. " has priority of: " .. tostring(data[2]) );
	    end
	end 
end
