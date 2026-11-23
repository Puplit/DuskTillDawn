
local VorpCore = exports.vorp_core:GetCore()

local function GetPlayerIdentifier(serverId, identifierType)
    local identifiers = GetPlayerIdentifiers(serverId)
    if identifiers then
        for _, v in ipairs(identifiers) do
            if string.sub(v, 1, #identifierType) == identifierType then
                return v
            end
        end
    end
    return nil
end

local function GetDiscordId(serverId)
    local discord = GetPlayerIdentifier(serverId, "discord:")
    return discord and string.sub(discord, 9) or nil
end

local function GetSteamId(serverId)
    return GetPlayerIdentifier(serverId, "steam:")
end

local function GetPlayerInfo(serverId)
    local User = VorpCore.getUser(serverId)
    local info = {
        name = GetPlayerName(serverId),
        serverId = serverId,
        steamId = GetSteamId(serverId),
        discordId = GetDiscordId(serverId),
        charId = nil,
        steamName = nil
    }
    
    if User then
        local Character = User.getUsedCharacter
        if Character then
            info.charId = Character.charIdentifier or Character.identifier or "N/A"
            info.steamName = (Character.firstname or "Unknown") .. " " .. (Character.lastname or "Player")
        end
    end
    
    return info
end

-- server-side position at the moment of the log
local function GetCoords(serverId)
    local ped = GetPlayerPed(serverId)
    if not ped or ped == 0 then return "N/A" end
    local c = GetEntityCoords(ped)
    return ("%.1f, %.1f, %.1f"):format(c.x, c.y, c.z)
end

local function FormatPlayerInfo(info)
    local discordMention = info.discordId and "<@" .. info.discordId .. ">" or "N/A"
    local text = ""
    text = text .. "**Name**: " .. (info.steamName or "N/A") .. "\n"
    text = text .. "**Server ID**: " .. (info.serverId or "N/A") .. "\n"
    text = text .. "**Discord**: " .. discordMention .. "\n"
    text = text .. "**Character ID**: " .. (info.charId or "N/A") .. "\n"
    text = text .. "**Steam Name**: " .. (info.name or "N/A") .. "\n"
    text = text .. "**Steam ID**: " .. (info.steamId or "N/A") .. "\n"
    text = text .. "**Coords**: " .. (info.coords or "N/A")
    return text
end

-- the weapon and hit location arrive FROM THE CLIENT, so they are untrusted text going straight into a Discord embed
local function clean(v, max)
    if v == nil then return nil end
    v = tostring(v):gsub("[`\r\n@]", " ")
    if #v > (max or 64) then v = v:sub(1, max or 64) end
    if v:gsub("%s", "") == "" then return nil end
    return v
end

-- Per-type webhook, falling back to the shared one
local function WebhookFor(kind)
    local per = Config.webhooks and Config.webhooks[kind]
    if per and per ~= "" then return per end
    if Config.webhook and Config.webhook ~= "" then return Config.webhook end
    return nil
end

RegisterServerEvent("DiscordBot:playerDied")
AddEventHandler("DiscordBot:playerDied", function(_killedPlayerId, killerPlayerId, deathReason, weapon, hitLocation)
    -- THE VICTIM IS `source`, NOT WHAT THE CLIENT SENT, so no client can log someone
    -- else as the victim. The client only ever sends its own id here anyway.
    local _source = source
    if not _source or _source == 0 then return end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local killedInfo = GetPlayerInfo(_source)
    killedInfo.coords = GetCoords(_source)

    -- the killer is still client-supplied; at least make sure it names somebody who is actually connected before it goes in
    killerPlayerId = tonumber(killerPlayerId)
    if killerPlayerId and GetPlayerName(killerPlayerId) == nil then
        killerPlayerId = nil
    end

    local title, description, color, kind

    if deathReason == 'committed suicide' then
        kind = "suicide"
        title = "SUICIDE"
        description = "**Victim:**\n" .. FormatPlayerInfo(killedInfo)
        color = 16711680
    elseif deathReason == 'died' or not killerPlayerId then
        kind = "natural"
        title = "NATURAL DEATH"
        description = "**Victim:**\n" .. FormatPlayerInfo(killedInfo)
        color = 16776960
    else
        kind = "pvp"
        title = "PVP KILL"
        local killerInfo = GetPlayerInfo(killerPlayerId)
        killerInfo.coords = GetCoords(killerPlayerId)
        description = "**Killer:**\n" .. FormatPlayerInfo(killerInfo) .. "\n\n**Victim:**\n" .. FormatPlayerInfo(killedInfo)
        color = 15158332

        -- how far apart they were, measured here rather than taken from anyone
        local kp, vp = GetPlayerPed(killerPlayerId), GetPlayerPed(_source)
        if kp and vp and kp ~= 0 and vp ~= 0 then
            description = description .. ("\n\n**Distance**: %.1f units"):format(#(GetEntityCoords(kp) - GetEntityCoords(vp)))
        end
    end

    local webhook = WebhookFor(kind)
    if not webhook then return end

    weapon = clean(weapon)
    hitLocation = clean(hitLocation, 24)

    if weapon ~= nil then
        description = description .. "\n**Weapon**: " .. weapon
    end

    if hitLocation ~= nil then
        description = description .. "\n**Hit Location**: " .. hitLocation
    end

    description = description .. "\n**Server Time**: " .. timestamp

    local embed = {
        {
            title = title,
            description = description,
            color = color,
            footer = {text = timestamp},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }

    SendWebhookEmbeds(webhook, embed)
end)

function SendWebhookMessage(webhook, message)
    -- skip blank webhooks
    if not webhook or webhook == "" then return end
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({content = message}), { ['Content-Type'] = 'application/json' })
end

function SendWebhookEmbeds(webhook, embeds)
    if not webhook or webhook == "" then return end
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({username = "Weapon Logger", embeds = embeds}), { ['Content-Type'] = 'application/json' })
end

AddEventHandler('playerDropped', function(reason)
    local _source = source
    if not Config.combatlog then return end

    local webhook = WebhookFor("combatlog")
    if not webhook then return end

    local User = VorpCore.getUser(_source)
    if not User then return end

    -- nil when the player drops before their character has loaded
    local Character = User.getUsedCharacter
    if not Character or not Character.isdead then return end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local playerInfo = GetPlayerInfo(_source)
    playerInfo.coords = GetCoords(_source)
    local description = "**Player:**\n" .. FormatPlayerInfo(playerInfo)
        .. "\n**Disconnect reason**: " .. (clean(reason, 120) or "unknown")
        .. "\n**Server Time**: " .. timestamp

    local embed = {
        {
            title = "COMBAT LOG",
            description = description,
            color = 16711680,
            footer = {text = timestamp},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }

    SendWebhookEmbeds(webhook, embed)
end)
