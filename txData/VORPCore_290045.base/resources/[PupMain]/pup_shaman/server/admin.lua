-- pup_shaman | staff bridge used by vorp_admin's Curses page
-- vorp_admin checks its own permission (manage_curses) and does the Discord logging with the message we return.

local function curseList()
    local list = {}
    for _, key in ipairs(Rules.SortedCurseKeys()) do
        local def = Config.Curses[key]
        list[#list + 1] = { key = key, label = def.label, harmful = def.course ~= nil }
    end
    return list
end

exports('AdminList', function()
    local players, online = {}, {}
    for _, src in ipairs(Shaman.Players()) do
        local char = Shaman.Character(src)
        if char then
            local charId = tonumber(char.charIdentifier)
            online[charId] = true
            players[#players + 1] = {
                src = src,
                steam = GetPlayerName(src) or '?',
                charid = charId,
                name = Shaman.FullName(char),
                curse = Store.Get(src),
            }
        end
    end

    local offline = {}
    local rows = MySQL.query.await([[
        SELECT `charidentifier`, `curse`, `firstname`, `lastname` FROM `characters`
        WHERE `curse` IS NOT NULL AND `curse` <> ''
    ]]) or {}
    for _, row in ipairs(rows) do
        local charId = tonumber(row.charidentifier)
        if charId and not online[charId] then
            local name = ('%s %s'):format(row.firstname or '', row.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
            offline[#offline + 1] = { charid = charId, curse = row.curse, name = name }
        end
    end

    return { curses = curseList(), players = players, offline = offline }
end)

--- The online player who has this character loaded, or nil.
local function srcOfChar(charId)
    for _, src in ipairs(Shaman.Players()) do
        if Shaman.CharId(src) == charId then return src end
    end
    return nil
end

exports('AdminAction', function(action, data)
    if type(data) ~= 'table' then data = {} end
    action = tostring(action or '')
    local src = tonumber(data.src)

    if action == 'cleanse' and not src then
        local charId = tonumber(data.charid)
        if not charId then return false, 'No character given.' end
        src = srcOfChar(charId)
        if not src then
            local ok, err = pcall(Store.ClearOffline, charId)
            if not ok then return false, 'Database error: ' .. tostring(err) end
            return true, ('Cleansed character %d (offline).'):format(charId)
        end
    end

    if not src or not Shaman.Character(src) then
        return false, 'That player is not online.'
    end
    local who = ('%s (%d)'):format(GetPlayerName(src) or '?', src)

    if action == 'give' then
        local key = data.curse
        if type(key) ~= 'string' or not Config.Curses[key] then return false, 'Unknown curse.' end
        if not Store.Set(src, key, 'change') then return false, 'That player is not online.' end
        return true, ('Gave %s to %s.'):format(Config.Curses[key].label, who)
    elseif action == 'cleanse' then
        Store.Clear(src, 'change')
        return true, ('Cleansed %s.'):format(who)
    elseif action == 'ease' then
        if not Store.Ease(src) then return false, 'That player has no harmful curse to ease.' end
        return true, ('Eased the curse on %s.'):format(who)
    end
    return false, 'Unknown action.'
end)
