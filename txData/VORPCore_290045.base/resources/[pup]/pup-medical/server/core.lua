-- pup-medical | server plumbing: VORP handles, webhooks, player context,
-- rate limits, tips and Discord. Loaded before every other server file.

Core = exports.vorp_core:GetCore()
Inv  = exports.vorp_inventory
RES  = GetCurrentResourceName()

function Debug(area, ...)
    local d = Config.General and Config.General.debug
    if not (d and d[area]) then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print(('[pup-medical:%s] %s'):format(area, table.concat(parts, ' ')))
end

function Warn(msg)
    print(('^3[pup-medical] %s^7'):format(tostring(msg)))
end

local warned = {}
function WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Warn(msg)
end

function Started(name)
    return type(name) == 'string' and GetResourceState(name) == 'started'
end

---------------------------------------------------------------------------
-- Webhooks. Hooks is set by server/config.lua (server only, loaded first).
---------------------------------------------------------------------------
Hooks = Hooks or {}

-- Hook('alerts', 'Medical', 'default') -> the URL string, or nil
function Hook(...)
    local node = Hooks
    for i = 1, select('#', ...) do
        if type(node) ~= 'table' then return nil end
        node = node[select(i, ...)]
    end
    if type(node) == 'string' and node ~= '' then return node end
    return nil
end

---------------------------------------------------------------------------
-- Discord
---------------------------------------------------------------------------
Colors = { green = 3066993, red = 15158332, orange = 15105570, blue = 3447003 }

function PostWebhook(url, embed, username, avatar)
    if type(url) ~= 'string' or url == '' then return end
    embed.timestamp = embed.timestamp or os.date('!%Y-%m-%dT%H:%M:%SZ')
    embed.footer = embed.footer or { text = 'pup-medical' }
    local body = { username = username or 'Medical Records', embeds = { embed } }
    if type(avatar) == 'string' and avatar ~= '' then body.avatar_url = avatar end
    local ok, payload = pcall(json.encode, body)
    if not ok then return end
    PerformHttpRequest(url, function(code)
        if code and (code < 200 or code >= 300) then
            Debug('alerts', 'webhook answered', code)
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

local function discordMention(src)
    local id = GetPlayerIdentifierByType(tostring(src), 'discord')
    if not id then return 'not linked' end
    return ('<@%s>'):format((id:gsub('^discord:', '')))
end

function DiscordId(src)
    local id = GetPlayerIdentifierByType(tostring(src), 'discord')
    if not id then return 'not linked' end
    return (id:gsub('^discord:', ''))
end

-- "who is this" block for embeds
function PersonField(title, ctx)
    local value
    if ctx then
        value = ('Char ID: %s\nName: %s\nSteam: %s\nDiscord: %s'):format(
            tostring(ctx.charId), ctx.name ~= '' and ctx.name or '-',
            GetPlayerIdentifierByType(tostring(ctx.src), 'steam') or 'n/a',
            discordMention(ctx.src))
    else
        value = 'unknown'
    end
    return { name = title, value = value, inline = false }
end

function Field(name, value, inline)
    local v = tostring(value == nil and '-' or value)
    if v == '' then v = '-' end
    if #v > 1000 then v = v:sub(1, 997) .. '...' end
    return { name = name, value = v, inline = inline ~= false }
end

---------------------------------------------------------------------------
-- Player context. Sessions remembers which character each player was on,
-- so a character switch is noticed even if the VORP event is missed.
---------------------------------------------------------------------------
Sessions = {}
local leaveHandlers = {}

-- modules register what they hold per player; called on drop and character switch
function OnPlayerLeft(fn)
    leaveHandlers[#leaveHandlers + 1] = fn
end

function ForgetPlayer(src, reason)
    for _, fn in ipairs(leaveHandlers) do
        local ok, err = pcall(fn, src, reason)
        if not ok then Warn(('cleanup failed: %s'):format(tostring(err))) end
    end
end

function IsDeadFlag(v)
    return v == true or v == 1
end

function GetCtx(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local user = Core.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if type(char) ~= 'table' or char.charIdentifier == nil then return nil end
    local charId = tonumber(char.charIdentifier)
    if not charId then return nil end

    local known = Sessions[src]
    if known and known ~= charId then
        Sessions[src] = charId
        ForgetPlayer(src, 'character switch')
    end
    Sessions[src] = charId

    local name = (('%s %s'):format(char.firstname or '', char.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return {
        src        = src,
        user       = user,
        char       = char,
        charId     = charId,
        identifier = char.identifier,
        job        = char.job,
        name       = name,
        dead       = IsDeadFlag(char.isdead),
    }
end

-- the same character is still on this source (used after every await)
function StillSame(ctx)
    local now = GetCtx(ctx.src)
    if not now or now.charId ~= ctx.charId then return nil end
    return now
end

---------------------------------------------------------------------------
-- Rate limits and positions
---------------------------------------------------------------------------
local lastHit = {}

function RateOk(src, kind, ms)
    local now = GetGameTimer()
    local per = lastHit[src]
    if not per then per = {}; lastHit[src] = per end
    if per[kind] and now - per[kind] < ms then return false end
    per[kind] = now
    return true
end

OnPlayerLeft(function(src) lastHit[src] = nil end)

function Pos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

function DistBetween(a, b)
    local pa, pb = Pos(a), Pos(b)
    if not pa or not pb then return math.huge end
    return #(pa - pb)
end

function Online(src)
    return src and GetPlayerName(src) ~= nil
end

function OnlinePlayers()
    local out = {}
    for _, s in ipairs(GetPlayers()) do out[#out + 1] = tonumber(s) end
    return out
end

---------------------------------------------------------------------------
-- Tips
---------------------------------------------------------------------------
function TipRight(src, text, ms)
    TriggerClientEvent('vorp:TipRight', src, text, ms or 8000)
end

function TipBottom(src, text, ms)
    TriggerClientEvent('vorp:TipBottom', src, text, ms or 5000)
end

---------------------------------------------------------------------------
-- Inventory wrappers: a missing or broken export counts as "no"
---------------------------------------------------------------------------
function ItemCount(src, item)
    local ok, n = pcall(function() return Inv:getItemCount(src, nil, item) end)
    if not ok then WarnOnce('getItemCount', 'vorp_inventory getItemCount failed: ' .. tostring(n)) end
    return (ok and tonumber(n)) or 0
end

function TakeItem(src, item, amount)
    local ok, res = pcall(function() return Inv:subItem(src, item, amount or 1) end)
    if not ok then WarnOnce('subItem', 'vorp_inventory subItem failed: ' .. tostring(res)) end
    return ok and res == true
end

function ItemLabel(item)
    local ok, db = pcall(function() return Inv:getItemDB(item) end)
    if ok and type(db) == 'table' and type(db.label) == 'string' and db.label ~= '' then return db.label end
    return item
end
