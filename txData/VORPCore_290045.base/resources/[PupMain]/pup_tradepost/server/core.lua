-- Server plumbing: core handle, secrets, player lookups, spam guard, notices.

Core = exports.vorp_core:GetCore()

---------------------------------------------------------------------------
-- secrets (global Secrets, set in server/config.lua)
---------------------------------------------------------------------------
local Secrets = type(Secrets) == 'table' and Secrets or {}

local function webhook(key)
    local hooks = type(Secrets.Webhooks) == 'table' and Secrets.Webhooks or {}
    local url = hooks[key]
    if type(url) ~= 'string' or url == '' then return nil end
    return url
end

---------------------------------------------------------------------------
-- players
---------------------------------------------------------------------------

-- the user and active character for a source, or nil
function TP.Player(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local user = Core.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if not char then return nil end
    local charid = tonumber(char.charIdentifier)
    if not charid or charid <= 0 then return nil end
    return user, char, charid
end

-- true while this source still plays the same character (call after every await)
function TP.SameChar(src, charid)
    local _, _, now = TP.Player(src)
    return now ~= nil and now == charid
end

-- the server id of whoever is playing a character right now, or nil
function TP.SourceOfChar(charid)
    local user = Core.getUserByCharId(charid)
    if not user then return nil end
    local src = tonumber(user.source)
    if not src or GetPlayerName(src) == nil then return nil end
    return src
end

function TP.NearMarket(src, marketKey)
    local m = TP.MarketByKey[marketKey]
    if not m then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    return #(pos - m.coords) <= (Config.Prompt.distance + Config.ActionSlack)
end

local staffGroups = {}
for _, g in ipairs(Config.Staff.groups) do staffGroups[g] = true end

function TP.IsStaff(src)
    if GetResourceState('vorp_admin') == 'started' then
        local ok, yes = pcall(function()
            return exports.vorp_admin:hasPermission(src, Config.Staff.permission)
        end)
        if ok and yes then return true end
    end
    local user, char = TP.Player(src)
    if not user then return false end
    if staffGroups[tostring(user.getGroup or '')] then return true end
    if staffGroups[tostring(char.group or '')] then return true end
    return false
end

---------------------------------------------------------------------------
-- spam guard
---------------------------------------------------------------------------
local hits = {}        -- [src] = { times... }
local lastWrite = {}   -- [src] = ms
local writing = {}     -- [charid] = true while a money/goods action runs

-- false when this source sent too much in the window
function TP.AllowRequest(src)
    local now = GetGameTimer()
    local list = hits[src]
    if not list then list = {}; hits[src] = list end
    local keep = {}
    for _, t in ipairs(list) do
        if now - t < Config.RateLimit.windowMs then keep[#keep + 1] = t end
    end
    if #keep >= Config.RateLimit.maxRequests then
        hits[src] = keep
        return false
    end
    keep[#keep + 1] = now
    hits[src] = keep
    return true
end

-- takes the per-character write slot; returns false when one is already running
function TP.BeginWrite(src, charid)
    local now = GetGameTimer()
    if writing[charid] then return false end
    if lastWrite[src] and now - lastWrite[src] < Config.RateLimit.writeGapMs then return false end
    writing[charid] = true
    lastWrite[src] = now
    return true
end

function TP.EndWrite(charid)
    writing[charid] = nil
end

AddEventHandler('playerDropped', function()
    local src = source
    hits[src] = nil
    lastWrite[src] = nil
end)

---------------------------------------------------------------------------
-- notices
---------------------------------------------------------------------------

-- the tip shown to whoever acted
function TP.Tip(src, msg)
    TriggerClientEvent('vorp:TipRight', src, msg, 4000)
end

-- a tip to the other side of a trade, if they are online
function TP.ToastChar(charid, msg)
    if not Config.ToastOtherTrader then return end
    local src = TP.SourceOfChar(charid)
    if src then Core.NotifyRightTip(src, msg, 4500) end
end

-- a letter through pup_postoffice; never blocks the caller, errors ignored
function TP.Mail(charid, subject, body)
    if not Config.Mail.enabled then return end
    if GetResourceState('pup_postoffice') ~= 'started' then return end
    CreateThread(function()
        pcall(function()
            exports.pup_postoffice:SendSystemMail(charid, subject, body, Config.Mail.sender)
        end)
    end)
end

-- one Discord embed for a finished money/goods action
function TP.Log(src, title, colour, msg)
    local url = webhook('market')
    if not url then return end

    local first, last, charid = 'Unknown', '', 0
    local _, char, cid = TP.Player(src)
    if char then
        first = tostring(char.firstname or 'Unknown')
        last = tostring(char.lastname or '')
        charid = cid
    end

    local discord = 'N/A'
    local raw = src and GetPlayerIdentifierByType(tostring(src), 'discord')
    if raw then discord = '<@' .. raw:gsub('^discord:', '') .. '>' end

    local description = table.concat({
        tostring(msg or ''),
        '',
        '**Character:** ' .. first .. ' ' .. last,
        '**Discord:** ' .. discord,
        '**Character ID:** ' .. tostring(charid),
        '**Player:** ' .. tostring(src and GetPlayerName(src) or 'N/A'),
        '**Server ID:** ' .. tostring(src or 'N/A'),
        '**Resource:** ' .. TP.Res,
    }, '\n')

    local payload = {
        username = Config.Discord.botName,
        embeds = { {
            title = title,
            color = colour,
            description = description,
            footer = { text = TP.Res .. ' - ' .. os.date('%Y-%m-%d %H:%M:%S') },
        } },
    }
    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end
