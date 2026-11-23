-- pup-stable | server core: players, money, locks, the request channel, logs

VORP = exports.vorp_core:GetCore()
RES = GetCurrentResourceName()
Ready = false

function Debug(...)
    if Config.General.debug then print('[pup-stable]', ...) end
end

local warned = {}
function WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print('^3[pup-stable]^7 ' .. msg)
end

function Running(res) return GetResourceState(res) == 'started' end

------------------------------------------------------------------------------
-- players
------------------------------------------------------------------------------
function Ctx(src)
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return nil end
    local user = VORP.getUser(src)
    if not user then return nil end
    local ch = user.getUsedCharacter
    if type(ch) ~= 'table' then return nil end
    local cid = U.int(ch.charIdentifier)
    if not cid or cid <= 0 or type(ch.identifier) ~= 'string' then return nil end
    return {
        src = src, user = user, char = ch, charid = cid, identifier = ch.identifier,
        name = U.trim(('%s %s'):format(ch.firstname or '', ch.lastname or '')),
        job = ch.job, grade = U.int(ch.jobGrade, 0), group = user.getGroup,
        money = U.num(ch.money, 0), gold = U.num(ch.gold, 0),
    }
end

function SrcOfChar(charid)
    local ok, user = pcall(VORP.getUserByCharId, charid)
    if not ok or not user then return nil end
    local s = tonumber(user.source)
    if s and Ctx(s) and Ctx(s).charid == charid then return s end
    return nil
end

function PedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

-- reach check from the server's own view of the player; refuses when the player cannot be placed
function Near(src, point, reach)
    local p = PedPos(src)
    if not p or not point then return false end
    return #(p - vector3(point.x, point.y, point.z)) <= reach
end

function EntNear(src, ent, reach)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    return Near(src, GetEntityCoords(ent), reach)
end

function Notify(src, msg, ms)
    if not src then return end
    TriggerClientEvent('vorp:TipRight', src, msg, ms or 4000)
end

-- left rank toast with the horse-bond icon
function Toast(src, title, sub, ms)
    TriggerClientEvent('vorp:LeftRank', src, title, sub or '', 'toasts_mp_generic', 'toast_mp_horse_bonding', ms or 5000, 'COLOR_WHITE')
end

function IsStaff(ctx) return ctx and Config.StaffGroups[ctx.group] == true end

local function inList(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

function IsTrainer(ctx) return ctx ~= nil and inList(Config.TrainerJobs, ctx.job) end
function IsStableJob(ctx) return ctx ~= nil and inList(Config.StableJobs, ctx.job) end

function CanColor(ctx)
    if not ctx then return false end
    if IsTrainer(ctx) then return true end
    return inList(Config.ColorAllowList, ctx.identifier)
end

-- take money; currency 0 cash / 1 gold. Reads the live character every time.
function Charge(src, amount, currency)
    amount = U.num(amount, -1)
    if amount < 0 then return false end
    if amount == 0 then return true end
    local ctx = Ctx(src)
    if not ctx then return false end
    local have = currency == 1 and ctx.gold or ctx.money
    if have < amount then return false end
    ctx.char.removeCurrency(currency == 1 and 1 or 0, amount)
    return true
end

function Refund(src, amount, currency)
    amount = U.num(amount, 0)
    if amount <= 0 then return end
    local ctx = Ctx(src)
    if ctx then ctx.char.addCurrency(currency == 1 and 1 or 0, amount) end
end

------------------------------------------------------------------------------
-- one action per player per kind; expires after the busy window
------------------------------------------------------------------------------
local locks = {}

function Lock(src, kind)
    locks[src] = locks[src] or {}
    local now = GetGameTimer()
    local at = locks[src][kind]
    if at and now - at < Config.General.busyLockMs then return false end
    locks[src][kind] = now
    return true
end

function Unlock(src, kind)
    if locks[src] then locks[src][kind] = nil end
end

function DropLocks(src) locks[src] = nil end

------------------------------------------------------------------------------
-- request channel: client -> server calls with one reply
------------------------------------------------------------------------------
local handlers, stamps = {}, {}

-- opts.gap = minimum ms between calls of this name per player
function Rpc(name, opts, fn)
    handlers[name] = { fn = fn, gap = opts.gap or 250 }
end

RegisterNetEvent('pup-stable:rpc', function(reqId, name, ...)
    local src = source
    if type(name) ~= 'string' then return end
    reqId = U.int(reqId, 0)
    local function reply(...)
        if reqId > 0 then TriggerClientEvent('pup-stable:reply', src, reqId, ...) end
    end
    local h = handlers[name]
    if not h or not Ready then return reply(false) end
    local now = GetGameTimer()
    stamps[src] = stamps[src] or {}
    local last = stamps[src][name]
    if last and now - last < h.gap then return reply(false) end
    stamps[src][name] = now
    local ctx = Ctx(src)
    if not ctx then return reply(false) end
    local args = table.pack(...)
    CreateThread(function()
        local res = table.pack(pcall(h.fn, ctx, table.unpack(args, 1, args.n)))
        if not res[1] then
            print(('^1[pup-stable]^7 %s failed: %s'):format(name, tostring(res[2])))
            return reply(false)
        end
        reply(table.unpack(res, 2, res.n))
    end)
end)

function DropStamps(src) stamps[src] = nil end

-- simple throttle for plain net events
function Throttle(src, key, gap)
    stamps[src] = stamps[src] or {}
    local now = GetGameTimer()
    local last = stamps[src]['ev:' .. key]
    if last and now - last < gap then return false end
    stamps[src]['ev:' .. key] = now
    return true
end

------------------------------------------------------------------------------
-- Discord
------------------------------------------------------------------------------
local function playerBlock(ctx)
    local lines = {
        ('**Character ID:** %s'):format(ctx.charid),
        ('**Name:** %s'):format(ctx.name),
    }
    if Config.Logs.sendSteamAndDiscord then
        local discord = GetPlayerIdentifierByType(ctx.src, 'discord')
        lines[#lines + 1] = ('**Steam:** %s'):format(ctx.identifier)
        lines[#lines + 1] = ('**Discord:** %s'):format(discord and ('<@' .. discord:gsub('^discord:', '') .. '>') or '-')
        lines[#lines + 1] = ('**Steam name:** %s'):format(GetPlayerName(ctx.src) or '-')
    end
    return table.concat(lines, '\n')
end

function StableLog(ctx, title, line)
    local hook = Secrets.stableWebhook
    if type(hook) ~= 'string' or hook == '' or not ctx then return end
    local body = json.encode({
        username = Config.Logs.username,
        embeds = { {
            title = title, color = Config.Logs.colour,
            description = '**Player Information**\n' .. playerBlock(ctx) .. '\n\n' .. line,
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        } },
    })
    PerformHttpRequest(hook, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

function WildLog(ctx, amount)
    local hook = Secrets.wildWebhook
    if type(hook) ~= 'string' or hook == '' or not ctx then return end
    local text = ('Seller: %s\nServer id: %d\nAmount: $%d'):format(Config.Logs.sendSteamAndDiscord and ctx.identifier or ctx.name, ctx.src, amount)
    pcall(VORP.AddWebhook, 'Wild Horse Sold', hook, text, Config.Logs.colour, Config.Logs.username)
end

------------------------------------------------------------------------------
-- entity helpers
------------------------------------------------------------------------------
function EntFromNet(netId, timeoutMs)
    netId = U.int(netId)
    if not netId or netId <= 0 then return nil end
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while GetGameTimer() < deadline do
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
        Wait(100)
    end
    return nil
end

function SafeDelete(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
end

function StableById(id)
    if type(id) ~= 'string' then return nil end
    return Config.Stables[id]
end
