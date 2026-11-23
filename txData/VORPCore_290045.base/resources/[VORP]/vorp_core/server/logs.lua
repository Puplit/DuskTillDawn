-- Modified by Puppet (Dusk Till Dawn), 2026
-- DISCORD --------------------------------------------------------

-- CONNECTION LOGGING

-- [src] = os.time() at the moment they finished joining, for session length
VORP_SESSION_START = {}

local function fmtDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 60 then return ("%ds"):format(seconds) end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return ("%dh %dm %ds"):format(h, m, s) end
    return ("%dm %ds"):format(m, s)
end

-- Every identifier the platform will give us for this player
local function identityFields(src, playerName)
    local steam   = GetPlayerIdentifierByType(src, 'steam')
    local license = GetPlayerIdentifierByType(src, 'license')
    local discord = GetPlayerIdentifierByType(src, 'discord')
    local live    = GetPlayerIdentifierByType(src, 'live')
    local fivem   = GetPlayerIdentifierByType(src, 'fivem')

    local ident = {}
    ident[#ident + 1] = ("Steam `%s`"):format(steam or "none")
    ident[#ident + 1] = ("License `%s`"):format(license or "none")
    if fivem then ident[#ident + 1] = ("FiveM `%s`"):format(fivem) end
    if live then ident[#ident + 1] = ("Live `%s`"):format(live) end

    -- OFF by default
    if Logs and Logs.JoinLogShowIP then
        local ok, ip = pcall(GetPlayerEndpoint, src)
        if ok and ip then ident[#ident + 1] = ("IP `%s`"):format(ip) end
    end

    return {
        {
            name   = "Player",
            value  = ("**%s**\nServer ID `%s`"):format(
                tostring(playerName or GetPlayerName(src) or "Unknown"), tostring(src)),
            inline = true,
        },
        {
            name   = "Discord",
            value  = discord and ("<@%s>\n`%s`"):format(discord:sub(9), discord:sub(9)) or "not linked",
            inline = true,
        },
        {
            name   = "Identifiers",
            value  = table.concat(ident, "\n"),
            inline = false,
        },
    }
end

--- kind: "connecting" | "joined" | "leave"
function VorpConnectionLog(kind, src, playerName, extraFields)
    if not Logs or not Logs.EnableWebhookJoinleave then return end

    local url, title, colour, description
    if kind == "leave" then
        url         = Logs.LeaveWebhookURL
        title       = "Player Leave"
        colour      = 15158332 -- red
        description = ("**%s** left the server."):format(tostring(playerName or GetPlayerName(src) or "Unknown"))
    elseif kind == "joined" then
        url         = (Logs.JoinedWebhookURL and Logs.JoinedWebhookURL ~= "") and Logs.JoinedWebhookURL or Logs.JoinWebhookURL
        title       = "Player Joined"
        colour      = 3066993 -- green
        description = ("**%s** is now in the server."):format(tostring(playerName or GetPlayerName(src) or "Unknown"))
    else
        url         = Logs.JoinWebhookURL
        title       = "Player Connecting"
        colour      = 3447003 -- blue
        description = ("**%s** is connecting."):format(tostring(playerName or GetPlayerName(src) or "Unknown"))
    end

    if not url or url == "" then return end

    local fields = identityFields(src, playerName)
    for _, f in ipairs(extraFields or {}) do fields[#fields + 1] = f end
    fields[#fields + 1] = {
        name   = "Server",
        value  = ("%d / %s online\n`%s`"):format(
            GetNumPlayerIndices(), GetConvar("sv_maxclients", "?"), os.date("%Y-%m-%d %H:%M:%S")),
        inline = true,
    }

    local dense = {}
    for i = 1, 25 do
        local f = fields[i]
        if type(f) == "table" and f.name and f.value then dense[#dense + 1] = f end
    end

    local payload = {
        embeds = { {
            title       = title,
            description = description,
            color       = colour,
            fields      = dense,
            footer      = { text = "VORPcore" },
            timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        } },
    }
    if Config.Avatar and Config.Avatar ~= "" then payload.avatar_url = Config.Avatar end

    PerformHttpRequest(url, function() end, 'POST', json.encode(payload),
        { ['Content-Type'] = 'application/json' })
end

--- Session length for the leave log, and the tidy-up so the table cannot grow
--- for the life of the server.
function VorpSessionLength(src)
    local started = VORP_SESSION_START[src]
    VORP_SESSION_START[src] = nil
    if not started then return nil end
    return fmtDuration(os.time() - started)
end

AddEventHandler('vorp_core:addWebhook', function(title, webhook, description, color, name, logo, footerlogo, avatar)
    if not webhook or webhook == "" then
        return
    end
    local webhookColor = (not color or color == "") and Config.webhookColor or color
    local webhookName = (not name or name == "") and Config.name or name
    local webhookLogo = (not logo or logo == "") and Config.logo or logo
    local webhookFooterLogo = (not footerlogo or footerlogo == "") and Config.footerLogo or footerlogo
    local webhookAvatar = (not avatar or avatar == "") and Config.Avatar or avatar

    -- An empty icon_url still makes Discord draw a broken image, so the key has to be LEFT OUT, not blank
    local author = { name = webhookName }
    if webhookLogo and webhookLogo ~= "" then author.icon_url = webhookLogo end

    local footer = { text = "VORPcore" .. " • " .. os.date("%x %X %p") }
    if webhookFooterLogo and webhookFooterLogo ~= "" then footer.icon_url = webhookFooterLogo end

    local payload = {
        embeds = {
            {
                color = webhookColor,
                author = author,
                title = title,
                description = description,
                footer = footer,
            },
        },
    }
    if webhookAvatar and webhookAvatar ~= "" then payload.avatar_url = webhookAvatar end

    PerformHttpRequest(webhook, function(err, text, headers)

    end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end)
