-- pup_railroad | server core: identity, database, request dispatch, notices, Discord logs

local Core <const> = exports.vorp_core:GetCore()
local RESOURCE <const> = GetCurrentResourceName()
local L <const> = Rail.L

Srv = {}

-- webhooks: global Secrets, set in server/config.lua
local Secrets <const> = Secrets or {}

--------------------------------------------------------------------------------
-- database (oxmysql, parameterised only)
--------------------------------------------------------------------------------
Srv.db = {}

local function dbAwait(method, sql, params)
    local p = promise.new()
    local ok, err = pcall(function()
        exports.oxmysql[method](exports.oxmysql, sql, params or {}, function(result, failure)
            if failure then
                print(('[pup_railroad] SQL error (%s): %s'):format(method, tostring(failure)))
                p:resolve(nil)
            else
                p:resolve(result)
            end
        end, RESOURCE, true)
    end)
    if not ok then
        print(('[pup_railroad] SQL call failed (%s): %s'):format(method, tostring(err)))
        return nil
    end
    return Citizen.Await(p)
end

function Srv.db.query(sql, params) return dbAwait('query', sql, params) end
function Srv.db.insert(sql, params) return dbAwait('insert', sql, params) end
function Srv.db.update(sql, params) return dbAwait('update', sql, params) end

function Srv.db.single(sql, params)
    local rows = dbAwait('query', sql, params)
    return rows and rows[1] or nil
end

-- fire and forget (used for saves and at resource stop)
function Srv.db.updateAsync(sql, params)
    pcall(function()
        exports.oxmysql:update(sql, params or {}, function() end, RESOURCE, true)
    end)
end

--------------------------------------------------------------------------------
-- identity
--------------------------------------------------------------------------------
function Srv.user(src)
    local ok, user = pcall(Core.getUser, src)
    if ok then return user end
    return nil
end

function Srv.char(src)
    local user = Srv.user(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if not char or not char.charIdentifier then return nil end
    return char
end

-- the current character, only while it is still the one a request started with
function Srv.sameChar(src, charId)
    local char = Srv.char(src)
    if char and char.charIdentifier == charId then return char end
    return nil
end

function Srv.isStaff(src)
    local user = Srv.user(src)
    if not user then return false end
    local char = user.getUsedCharacter
    return user.getGroup == 'admin' or (char and char.group == 'admin') or false
end

function Srv.identity(char)
    return {
        first = char.firstname or '', last = char.lastname or '',
        charId = char.charIdentifier, identifier = char.identifier, job = char.job or '',
    }
end

function Srv.notify(src, msg)
    TriggerClientEvent('vorp:TipRight', src, msg, 4000)
end

-- refusal helper: tells the player why and gives the client a "no"
function Srv.fail(src, key, ...)
    if key then Srv.notify(src, L(key, ...)) end
    return { ok = false }
end

--------------------------------------------------------------------------------
-- positions (OneSync); unknown positions count as near
--------------------------------------------------------------------------------
local function known(c)
    if not c then return nil end
    if c.x == 0.0 and c.y == 0.0 and c.z == 0.0 then return nil end
    return c
end

function Srv.playerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return known(GetEntityCoords(ped))
end

function Srv.entityPos(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    return known(GetEntityCoords(ent))
end

-- strict: an unknown position counts as far (train work, lockbox, delivery pay)
function Srv.within(a, b, dist, strict)
    if not a or not b then return not strict end
    return #(a - b) <= dist
end

function Srv.nearOwnStation(src, job)
    if not Rail.jobHasStation(job) then return false end
    local pos = Srv.playerPos(src)
    if not pos then return true end
    for i = 1, #Config.Stations do
        local st = Config.Stations[i]
        if st.job == job and #(pos - st.coords) <= Config.Reach.station then return true end
    end
    return false
end

function Srv.hasKey(src)
    local ok, count = pcall(function()
        return exports.vorp_inventory:getItemCount(src, nil, Config.KeyItem)
    end)
    return ok and (tonumber(count) or 0) >= 1
end

--------------------------------------------------------------------------------
-- request dispatch
-- client: TriggerServerEvent('pup_railroad:call', name, reqId | nil, ...)
-- server: TriggerClientEvent('pup_railroad:reply', src, reqId, result)
--------------------------------------------------------------------------------
local handlers = {}
local lastCall = {} -- [src][name] = ms

--- Register a request handler.
--- opts.gap: minimum ms between two calls of this name from one player (spam guard)
--- fn(src, char, ...) returns a result table (or nil for a plain "no")
function Srv.on(name, opts, fn)
    handlers[name] = { gap = opts.gap or 300, fn = fn }
end

RegisterNetEvent('pup_railroad:call', function(name, reqId, ...)
    local src = source
    if type(name) ~= 'string' then return end
    local h = handlers[name]
    if not h then return end
    if reqId ~= nil and (math.type(reqId) ~= 'integer' or reqId < 1 or reqId > 0x7FFFFFFF) then return end

    local function reply(result)
        if reqId then TriggerClientEvent('pup_railroad:reply', src, reqId, result or { ok = false }) end
    end

    local now = GetGameTimer()
    local mine = lastCall[src]
    if not mine then mine = {}; lastCall[src] = mine end
    if mine[name] and now - mine[name] < h.gap then
        return reply({ ok = false, limited = true })
    end
    mine[name] = now

    local char = Srv.char(src)
    if not char then return reply({ ok = false }) end

    local ok, result = pcall(h.fn, src, char, ...)
    if not ok then
        print(('[pup_railroad] handler %s failed: %s'):format(name, tostring(result)))
        result = { ok = false }
    end
    reply(result)
end)

AddEventHandler('playerDropped', function()
    lastCall[source] = nil
end)

--------------------------------------------------------------------------------
-- Discord logs
--------------------------------------------------------------------------------
local function isDiscordHook(url)
    if type(url) ~= 'string' or url == '' then return false end
    return url:match('^https://discord%.com/api/webhooks/') ~= nil
        or url:match('^https://discordapp%.com/api/webhooks/') ~= nil
        or url:match('^https://ptb%.discord%.com/api/webhooks/') ~= nil
        or url:match('^https://canary%.discord%.com/api/webhooks/') ~= nil
end

local function staffHook()
    local hooks = Secrets.Webhooks
    local url = type(hooks) == 'table' and hooks.train or nil
    if isDiscordHook(url) then return url end
    return nil
end

local function companyHook(job)
    if GetResourceState('pup_business') ~= 'started' then return nil end
    local ok, url = pcall(function() return exports['pup_business']:GetJobWebhook(job) end)
    if ok and isDiscordHook(url) then return url end
    return nil
end

--- identity: from Srv.identity; extras: { {name, value}, ... }
function Srv.log(identity, title, colour, extras)
    if not identity or not identity.charId then return end
    local staff = staffHook()
    local company = companyHook(identity.job)
    if company == staff then company = nil end
    if not staff and not company then return end

    CreateThread(function()
        local discord = 'Not linked'
        if identity.identifier then
            local row = Srv.db.single('SELECT discordid FROM characters WHERE identifier = ? LIMIT 1', { identity.identifier })
            local id = row and row.discordid and tostring(row.discordid) or ''
            if id:match('^%d+$') then discord = ('<@%s>'):format(id) end
        end

        local fullName = (identity.first .. ' ' .. identity.last):match('^%s*(.-)%s*$')
        if fullName == '' then fullName = '-' end
        local job = tostring(identity.job):gsub('`', '')

        local fields = {
            { name = 'Character Name', value = fullName, inline = true },
            { name = 'Character ID', value = tostring(identity.charId), inline = true },
            { name = 'Discord', value = discord, inline = true },
        }
        for i = 1, #(extras or {}) do
            fields[#fields + 1] = { name = extras[i][1], value = tostring(extras[i][2]), inline = true }
        end
        fields[#fields + 1] = { name = 'Company', value = '`' .. job .. '`', inline = true }

        local body = json.encode({
            username = 'Train Tracker',
            embeds = { {
                title = title,
                color = colour,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                fields = fields,
            } },
        })
        local headers = { ['Content-Type'] = 'application/json' }
        if staff then PerformHttpRequest(staff, function() end, 'POST', body, headers) end
        if company then PerformHttpRequest(company, function() end, 'POST', body, headers) end
    end)
end
