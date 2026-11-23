-- legendaryhunt | Discord log of a hunt starting
-- One webhook (HuntSecrets.hunts in server/config.lua). Empty means no log at all.

HuntLog = {}

-- client text: to string, no control characters, no @ < >, at most 64 characters
local function cleanZone(v)
    if v == nil then return '?' end
    local s = tostring(v):gsub('%c', ''):gsub('[@<>]', '')
    s = s:sub(1, 64)
    if s == '' then return '?' end
    return s
end

-- names come from the database; keep them from pinging anyone either
local function cleanName(v)
    local s = tostring(v or ''):gsub('%c', ''):gsub('[@<>`]', '')
    return s
end

function HuntLog.hunt(src, char, animalName, zoneName)
    local url = HuntSecrets and HuntSecrets.hunts or ''
    if url == '' then return end

    local steam = GetPlayerIdentifierByType(src, 'steam')
    local discord = GetPlayerIdentifierByType(src, 'discord')
    local discordId = discord and discord:match('^discord:(%d+)$')

    local who = table.concat({
        '**Player Information**',
        ('Char ID: %s'):format(char.charIdentifier ~= nil and tostring(char.charIdentifier) or 'N/A'),
        ('Name: %s %s'):format(cleanName(char.firstname), cleanName(char.lastname)),
        ('Steam ID: %s'):format(steam or 'N/A'),
        ('Discord ID: %s'):format(discordId and ('<@' .. discordId .. '>') or 'N/A'),
    }, '\n')
    local what = table.concat({
        '**Hunt Information**',
        ('Animal: %s'):format(cleanName(animalName)),
        ('Area: %s'):format(cleanZone(zoneName)),
        ('Time: %s'):format(os.date('%m/%d/%Y %I:%M:%S %p')),
    }, '\n')

    local payload = {
        username = 'Legendary Hunt',
        content = '',
        embeds = { {
            title = 'Legendary Hunt Activated',
            color = 16711680,
            description = who .. '\n\n' .. what,
        } },
    }
    local avatar = Config.Discord.avatar
    if type(avatar) == 'string' and avatar ~= '' then payload.avatar_url = avatar end

    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end
