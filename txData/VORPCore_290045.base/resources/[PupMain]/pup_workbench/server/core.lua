-- Shared server state: VORP core, secrets, the Discord log and player lookups.
Core = exports.vorp_core:GetCore()
Inv = exports.vorp_inventory

Server = {
    ready = false,   -- set once start-up has finished; requests are refused before that
}

function Dbg(fmt, ...)
    if not Config.Debug then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print(('[pup_workbench] %s'):format(ok and msg or tostring(fmt)))
end

function Warn(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print(('^3[pup_workbench]^7 %s'):format(ok and msg or tostring(fmt)))
end

-- SECRETS: global Secrets, set in server/config.lua
local function webhookUrl()
    local hooks = type(Secrets) == 'table' and type(Secrets.webhooks) == 'table' and Secrets.webhooks or {}
    local url = type(hooks.crafting) == 'string' and hooks.crafting or ''
    if url == '' then return nil end
    if not url:find('^https://discord%.com/api/webhooks/') and not url:find('^https://discordapp%.com/api/webhooks/')
        and not url:find('^https://[%w%.]*discord%.com/api/webhooks/') then
        return nil
    end
    return url
end

local function postEmbed(title, colour, fields)
    local url = webhookUrl()
    if not url then return end
    local embed = {
        title = title,
        color = colour,
        fields = fields,
        footer = { text = Config.Log.footer },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    PerformHttpRequest(url, function() end, 'POST',
        json.encode({ username = Config.Log.botName, embeds = { embed } }),
        { ['Content-Type'] = 'application/json' })
end

local function field(name, value)
    local v = tostring(value == nil and 'N/A' or value)
    if v == '' then v = 'N/A' end
    if #v > 1000 then v = v:sub(1, 1000) .. '...' end
    return { name = name, value = v, inline = false }
end

--- "Nx item" joined by commas, or N/A.
local function itemsText(lines)
    local parts = {}
    for _, l in ipairs(lines or {}) do
        parts[#parts + 1] = ('%dx %s'):format(math.floor(tonumber(l.count) or 0), tostring(l.name))
    end
    if #parts == 0 then return 'N/A' end
    return table.concat(parts, ', ')
end

--- Craft completed.
function LogCraft(who, made, used, recipeTitle)
    postEmbed(Config.Log.title, Config.Log.colour, {
        field('Character', ('%s (%s)'):format(who.name, who.charid)),
        field('Items crafted', itemsText(made)),
        field('Items used', itemsText(used)),
        field('Recipe', recipeTitle),
        field('Steam name', who.steamname),
        field('Steam identifier', who.identifier),
    })
end

--- Security violation. `who` may be nil (no character), then src fills in.
function LogViolation(src, who, reason)
    Dbg('violation src=%s: %s', tostring(src), tostring(reason))
    local steamname = who and who.steamname or (GetPlayerName(src) or 'N/A')
    local ident = who and who.identifier or 'N/A'
    postEmbed(Config.Log.title .. ' - Security Violation', Config.Log.violationColour, {
        field('Character', who and ('%s (%s)'):format(who.name, who.charid) or 'N/A'),
        field('Reason', reason),
        field('Steam name', steamname),
        field('Steam identifier', ident),
    })
end

-- PLAYERS
local function discordId(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local d = id:match('^discord:(%d+)$')
        if d then return d end
    end
    return nil
end

--- Everything the rules need about a player's selected character, or nil.
function Who(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local user = Core.getUser(src)
    if not user then return nil end
    local ch = user.getUsedCharacter
    if not ch then return nil end
    local charid = tonumber(ch.charIdentifier)
    if not charid or charid <= 0 then return nil end
    return {
        src = src,
        charid = charid,
        identifier = tostring(ch.identifier or ''),
        job = tostring(ch.job or ''),
        grade = tonumber(ch.jobGrade) or 0,
        name = ('%s %s'):format(tostring(ch.firstname or ''), tostring(ch.lastname or '')),
        steamname = GetPlayerName(src) or '',
        discord = discordId(src),
        group = tostring(user.getGroup or ''),
    }
end

function Notify(src, text, ms)
    Core.NotifyRightTip(src, tostring(text), ms or 4000)
end

function PlayerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- pup-perks, optional: never let it break a craft
function PerkRoll(src, key)
    if GetResourceState('pup-perks') ~= 'started' then return false end
    local ok, hit = pcall(function() return exports['pup-perks']:Roll(src, key) end)
    return ok and hit == true
end

function PerkAward(src, kind)
    if GetResourceState('pup-perks') ~= 'started' then return end
    pcall(function() exports['pup-perks']:Award(src, kind) end)
end
