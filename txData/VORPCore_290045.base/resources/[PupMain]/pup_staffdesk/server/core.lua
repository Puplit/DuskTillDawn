-- pup_staffdesk | server basics: who is who, staff checks, tips, logs, letters
Desk = Desk or {}

local Core = exports.vorp_core:GetCore()
Desk.Core = Core

function Desk.char(src)
    local user = Core.getUser(tonumber(src))
    return user and user.getUsedCharacter or nil
end

function Desk.charid(src)
    local ch = Desk.char(src)
    return ch and tonumber(ch.charIdentifier) or nil
end

-- the Discord id on the player's connection, digits only, or nil
function Desk.discordOf(src)
    local ok, id = pcall(GetPlayerIdentifierByType, tostring(src), 'discord')
    if not ok or type(id) ~= 'string' then return nil end
    id = id:gsub('^discord:', '')
    return id ~= '' and id or nil
end

-- server id of whoever is playing a character right now
function Desk.sourceOfChar(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    for _, s in ipairs(GetPlayers()) do
        if Desk.charid(s) == charid then return tonumber(s) end
    end
    return nil
end

function Desk.sourcesOfDiscord(discordid)
    local out = {}
    if not discordid then return out end
    for _, s in ipairs(GetPlayers()) do
        if Desk.discordOf(s) == tostring(discordid) then out[#out + 1] = tonumber(s) end
    end
    return out
end

-- staff: anyone holding this vorp_admin permission (Discord role or group, see its PERMISSIONS.md)
local function holdsAdminPermission(src)
    if GetResourceState('vorp_admin') ~= 'started' then return false end
    local ok, allowed = pcall(function() return exports.vorp_admin:hasPermission(src, Config.Staff.permission) end)
    return ok and allowed == true
end

-- the console, a vorp_admin permission, or a VORP group from Config.Staff.groups
function Desk.isStaff(src)
    src = tonumber(src)
    if not src or src == 0 then return src == 0 end
    if holdsAdminPermission(src) then return true end
    local user = Core.getUser(src)
    local group = user and user.getGroup
    for _, g in ipairs(Config.Staff.groups or {}) do
        if group == g then return true end
    end
    return false
end

-- "Jane Doe (3)" for logs, "Console" for the console
function Desk.who(src)
    src = tonumber(src)
    if not src or src == 0 then return 'Console' end
    local ch = Desk.char(src)
    local name = ch and ((ch.firstname or '') .. ' ' .. (ch.lastname or '')) or (GetPlayerName(src) or '?')
    return ('%s (%d)'):format(Desk.trim(name), src)
end

-- the same, with the Discord tag and Steam name, for Discord logs only (never saved or shown in game)
function Desk.whoLog(src)
    src = tonumber(src)
    if not src or src == 0 then return 'Console' end
    local discord = GetPlayerIdentifierByType(src, 'discord')
    return ('%s %s [Steam: %s]'):format(Desk.who(src), discord and ('<@%s>'):format(discord:sub(9)) or '(no Discord)', GetPlayerName(src) or '?')
end

function Desk.tip(src, msg, ms)
    src = tonumber(src)
    if not msg or not src then return end
    if src == 0 then return print('[pup_staffdesk] ' .. tostring(msg)) end
    Core.NotifyRightTip(src, msg, ms or 4500)
end

-- the desk a player stands at, or nil
function Desk.atDesk(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    local reach = (Config.General.deskDistance or 2.0) + 1.5 -- a little slack for movement while the panel is open
    for key, d in pairs(Config.Desks) do
        if #(pos - d.coords) <= reach then return key end
    end
    return nil
end

-- one line in the Discord log webhook. lines = { 'a', 'b' } or a string
function Desk.log(title, lines, color)
    local hook = Secrets.Webhooks.log or Secrets.Webhooks.reply
    if not hook or hook == '' then return end
    local text = type(lines) == 'table' and table.concat(lines, '\n') or tostring(lines or '')
    PerformHttpRequest(hook, function() end, 'POST', json.encode({
        username = 'Staff Desk',
        avatar_url = (Config.General.logAvatar ~= '' and Config.General.logAvatar) or nil,
        embeds = { { title = title, description = text, color = color or 9067051, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } },
    }), { ['Content-Type'] = 'application/json' })
end

-- a letter through pup_postoffice, when it runs
function Desk.mail(charid, subject, body)
    local m = Config.Parcels.mail
    if not (m and m.enabled) or GetResourceState('pup_postoffice') ~= 'started' then return end
    pcall(function() exports.pup_postoffice:SendSystemMail(charid, subject, body, m.fromName) end)
end

-- does a table exist in this database? (cached: other resources' tables are optional)
local known = {}
function Desk.hasTable(name)
    if known[name] == nil then
        local n = MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })
        known[name] = tonumber(n) == 1
    end
    return known[name]
end

-- an item's label, or nil if the item does not exist
function Desk.itemLabel(name)
    if type(name) ~= 'string' or name == '' then return nil end
    return MySQL.scalar.await('SELECT label FROM items WHERE item = ?', { name })
end

-- a weapon hash in Config.WeaponLabels, normalised to upper case, with its label
function Desk.weapon(hash)
    if type(hash) ~= 'string' then return nil end
    local h = hash:upper()
    local label = Config.WeaponLabels[h]
    if not label then return nil end
    return h, label
end
