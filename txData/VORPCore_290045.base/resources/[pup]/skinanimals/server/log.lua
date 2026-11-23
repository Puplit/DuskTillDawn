-- skinanimals | server/log.lua
-- Discord skinning log. The webhook URL never leaves the server.

SkinLog = {}

local function identifierOf(src, kind)
    local ok, v = pcall(GetPlayerIdentifierByType, src, kind)
    if ok and type(v) == 'string' and v ~= '' then return v end
    return nil
end

-- given: list of { name, label, qty }
function SkinLog.post(src, char, row, given)
    if not Config.SkinningLog.enabled then return end
    local url = SkinSecrets.skinningLog
    if type(url) ~= 'string' or url == '' then return end
    if not char or #given == 0 then return end

    local steam = identifierOf(src, 'steam') or 'Unknown'
    local discord = identifierOf(src, 'discord')
    local discordText = discord and ('<@' .. discord:gsub('^discord:', '') .. '>') or 'Unknown'

    local itemLines = {}
    for i, g in ipairs(given) do
        itemLines[i] = ('%dx %s (%s)'):format(g.qty, g.label, g.name)
    end

    local payload = {
        embeds = {
            {
                title = 'Animal Skinning Log',
                color = 3447003,
                fields = {
                    {
                        name = 'Player Information',
                        inline = false,
                        value = table.concat({
                            '**Char ID:** ' .. tostring(char.charIdentifier),
                            '**Name:** ' .. tostring(char.firstname or '') .. ' ' .. tostring(char.lastname or ''),
                            '**Steam ID:** ' .. steam,
                            '**Discord ID:** ' .. discordText,
                        }, '\n'),
                    },
                    {
                        name = 'Hunt Information',
                        value = table.concat({
                            '**Animal:** ' .. tostring(row.name or '?'),
                            '**Time:** ' .. os.date('%m/%d/%Y %I:%M:%S %p'),
                        }, '\n'),
                    },
                    {
                        name = 'Items Obtained',
                        value = table.concat(itemLines, '\n'),
                    },
                },
            },
        },
    }

    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end
