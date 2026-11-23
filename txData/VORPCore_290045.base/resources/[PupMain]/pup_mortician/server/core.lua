-- pup_mortician | server plumbing: VORP handles, player context, rate limits,
-- and Discord logging. Loaded after server/config.lua; every other server file uses it.

Core = exports.vorp_core:GetCore()
Inv = exports.vorp_inventory
RES = GetCurrentResourceName()

local function dbg(...)
    if Config.Debug then print(('[%s]'):format(RES), ...) end
end
Dbg = dbg

function Warn(msg)
    print(('^3[%s] %s^7'):format(RES, tostring(msg)))
end

function Trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

---------------------------------------------------------------------------
-- Sessions: the character each player was last seen on, so disconnect
-- cleanup never depends on VORP still knowing who the player was.
---------------------------------------------------------------------------
Sessions = {}

-- set by main.lua: frees everything the character held (casket, posting, dig)
OnCharacterLeft = function(_, _) end

-- returns nil when the player has no loaded character
function GetCtx(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local user = Core.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if type(char) ~= 'table' or char.charIdentifier == nil then return nil end
    local charId = tonumber(char.charIdentifier)
    if not charId then return nil end

    local prev = Sessions[src]
    if prev and prev.charId ~= charId then
        -- the player switched character without us seeing the event
        OnCharacterLeft(src, prev.charId)
    end
    local name = Trim(('%s %s'):format(char.firstname or '', char.lastname or ''))
    Sessions[src] = { charId = charId, job = char.job, name = name }
    return { src = src, char = char, charId = charId, job = char.job, name = name }
end

-- the same character is still online on this source (re-checked after every await)
function StillSame(ctx)
    local now = GetCtx(ctx.src)
    if not now or now.charId ~= ctx.charId then return nil end
    return now
end

---------------------------------------------------------------------------
-- Rate limiting: one gap per player per request kind
---------------------------------------------------------------------------
local lastCall = {}

function RateOk(src, kind)
    local gap = Config.RateLimit[kind] or Config.RateLimit.default
    local now = GetGameTimer()
    local per = lastCall[src]
    if not per then per = {}; lastCall[src] = per end
    if per[kind] and now - per[kind] < gap then return false end
    per[kind] = now
    return true
end

function ForgetRate(src)
    lastCall[src] = nil
end

---------------------------------------------------------------------------
-- Positions (always the server's own view of the ped)
---------------------------------------------------------------------------
function PlayerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

-- distance from the player to a point; huge when unknown
function DistTo(src, point)
    local p = PlayerPos(src)
    if not p or not point then return math.huge end
    return #(p - point)
end

---------------------------------------------------------------------------
-- Inventory helpers
---------------------------------------------------------------------------
function ItemCount(src, item)
    local ok, n = pcall(function() return Inv:getItemCount(src, nil, item) end)
    return (ok and tonumber(n)) or 0
end

function HasShovel(src)
    for _, name in ipairs(Config.Shovel.items) do
        if ItemCount(src, name) > 0 then return true end
    end
    return false
end

function Tip(src, text)
    Core.NotifyRightTip(src, text, 5000)
end

---------------------------------------------------------------------------
-- Optional resources
---------------------------------------------------------------------------
function Started(name)
    return GetResourceState(name) == 'started'
end

function PerkMult(src, key)
    if not Started('pup-perks') then return 1.0 end
    local ok, m = pcall(function() return exports['pup-perks']:Mult(src, key) end)
    m = ok and tonumber(m) or 1.0
    if not m or m <= 0 then m = 1.0 end
    return m
end

function PerkAward(src, kind)
    if not Started('pup-perks') then return end
    pcall(function() exports['pup-perks']:Award(src, kind) end)
end

function BusinessInfo(src)
    if not Started('pup_business') then return nil end
    local ok, info = pcall(function() return exports.pup_business:GetBusinessInfo(src) end)
    if ok and type(info) == 'table' then return info end
    return nil
end

-- boss of the given job, as pup_business decides it
function IsBossOf(src, job)
    local info = BusinessInfo(src)
    return info ~= nil and info.isBoss == true and info.job == job
end

---------------------------------------------------------------------------
-- Discord (the webhook is Secrets.logs, set in server/config.lua)
---------------------------------------------------------------------------
local SENDER <const> = 'Undertaker Tracker'
local FOOTER <const> = 'Undertaker Logs'

Colors = { blue = 3447003, green = 3066993, gold = 15844367 }

local function post(url, embed)
    if type(url) ~= 'string' or url == '' then return end
    embed.footer = { text = FOOTER }
    embed.timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    PerformHttpRequest(url, function(code)
        if code and (code < 200 or code >= 300) then
            dbg('webhook answered', code)
        end
    end, 'POST', json.encode({ username = SENDER, embeds = { embed } }), { ['Content-Type'] = 'application/json' })
end

local function playerField(ctx)
    local steam = GetPlayerIdentifierByType(tostring(ctx.src), 'steam') or 'N/A'
    local discord = GetPlayerIdentifierByType(tostring(ctx.src), 'discord')
    local mention = discord and ('<@%s>'):format((discord:gsub('^discord:', ''))) or 'Not Linked'
    return {
        name = 'Player Information',
        value = ('Char ID: %s\nName: %s\nSteam: %s\nDiscord: %s\nSteam name: %s'):format(
            tostring(ctx.charId), ctx.name ~= '' and ctx.name or '-', steam, mention, GetPlayerName(ctx.src) or '-'),
        inline = false,
    }
end

-- staff log: always opens with the player block
function StaffLog(ctx, title, description, fields, color)
    local url = Secrets.logs
    if type(url) ~= 'string' or url == '' then return end
    local all = { playerField(ctx) }
    for _, f in ipairs(fields or {}) do
        all[#all + 1] = { name = f[1], value = tostring(f[2]), inline = f[3] ~= false }
    end
    post(url, { title = title, description = description, color = color, fields = all })
end

-- business report to a boss-set webhook
function BusinessReport(url, title, description, fields, color)
    local all = {}
    for _, f in ipairs(fields or {}) do
        all[#all + 1] = { name = f[1], value = tostring(f[2]), inline = f[3] ~= false }
    end
    post(url, { title = title, description = description, color = color, fields = all })
end
