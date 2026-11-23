-- pup_id | server
-- Builds every identity paper from the server's own VORP data and decides who sees it.
-- Clients only name a target; they never supply anything that is printed.

local RESOURCE <const> = GetCurrentResourceName()
local MAX_TEXT <const> = 64

local core            -- vorp_core's object, fetched on first use
local warned = {}     -- one-time console warnings
local lastOwn, lastHandOver, lastInspect = {}, {}, {}
local busy = {}       -- [src] = true while an inspect waits for an answer
local pending = {}    -- [token] = { target = id, p = promise }
local tokenCounter = 0

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^1[%s]^7 %s'):format(RESOURCE, msg))
end

local function getCore()
    if core then return core end
    local ok, obj = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and type(obj) == 'table' then
        core = obj
        return core
    end
    -- older cores only answer the getCore event
    TriggerEvent('getCore', function(c) if type(c) == 'table' then core = c end end)
    if not core then warnOnce('core', 'vorp_core did not hand over its core object; papers cannot be built.') end
    return core
end

-- A connected player's server id as a number, or nil. Rejects -1, 0, fractions and strangers.
local function toPlayerId(v)
    local n = tonumber(v)
    if not n or n <= 0 or n ~= math.floor(n) then return nil end
    if GetPlayerName(tostring(n)) == nil then return nil end
    return n
end

-- Functions that come through another resource's export arrive as callable tables, not functions.
-- (the call itself is pcall'd, so a table that turns out not to be callable just yields nil)
local function callable(f)
    return type(f) == 'function' or type(f) == 'table'
end

-- The active character of a player, or nil when they have none.
local function activeCharacter(src)
    local c = getCore()
    if not c or not callable(c.getUser) then return nil end
    local ok, user = pcall(c.getUser, src)
    if not ok or type(user) ~= 'table' then return nil end
    local ch = user.getUsedCharacter
    if type(ch) ~= 'table' or ch.charIdentifier == nil then return nil end
    return ch
end

local function clip(v)
    local s = tostring(v or '')
    if #s > MAX_TEXT then s = s:sub(1, MAX_TEXT) end
    return s
end

local function cooldownPassed(store, src, ms)
    local now = GetGameTimer()
    local last = store[src]
    if last and now - last < ms then return false end
    store[src] = now
    return true
end

local function pedsWithin(a, b, range)
    local pa, pb = GetPlayerPed(tostring(a)), GetPlayerPed(tostring(b))
    if not pa or pa == 0 or not pb or pb == 0 then return nil end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= range
end

-- The printed occupation: the job key itself for the plain jobs, otherwise the name of the
-- lowest-id society shop of that job with a non-empty name (as vorp_character's cards do).
local function occupationFor(job)
    local key = tostring(job or '')
    if key == '' or Config.PlainJobs[key] then return key end
    if GetResourceState('oxmysql') ~= 'started' or type(MySQL) ~= 'table' then
        warnOnce('oxmysql', 'oxmysql is not started; occupations fall back to the job key.')
        return key
    end
    local ok, name = pcall(MySQL.scalar.await,
        "SELECT `name` FROM `society_shops` WHERE `society` = ? AND `name` IS NOT NULL AND `name` <> '' ORDER BY `id` LIMIT 1",
        { key })
    if ok and type(name) == 'string' and name ~= '' then return name end
    return key
end

-- Builds the paper of `src`'s active character. Returns paper and the character id it was built for.
local function buildPaper(src)
    local ch = activeCharacter(src)
    if not ch then return nil end
    local charId = ch.charIdentifier
    local occupation = occupationFor(ch.job)
    -- the query awaited: make sure the same character is still in use
    local again = activeCharacter(src)
    if not again or again.charIdentifier ~= charId then return nil end
    local age = tonumber(again.age)
    if age and (age <= 0 or age ~= age) then age = nil end
    return {
        name = clip(('%s %s'):format(tostring(again.firstname or ''), tostring(again.lastname or ''))),
        occupation = clip(occupation),
        age = age and math.floor(age) or nil,
        number = clip(charId),
        issued = clip(Config.IssueDate),
    }
end

local function send(target, paper)
    TriggerClientEvent('pup_id:show', target, paper)
end

local function validSource(raw)
    local src = tonumber(raw)
    if not src or src <= 0 then return nil end
    if GetPlayerName(tostring(src)) == nil then return nil end
    return src
end

-- look at your own
RegisterNetEvent('pup_id:requestOwn', function()
    local src = validSource(source)
    if not src then return end
    if not activeCharacter(src) then return end
    if not cooldownPassed(lastOwn, src, Config.OwnCooldownMs) then return end
    local paper = buildPaper(src)
    if not paper or not validSource(src) then return end
    send(src, paper)
end)

-- hand yours over
RegisterNetEvent('pup_id:handOver', function(rawTarget)
    local src = validSource(source)
    if not src then return end
    local target = toPlayerId(rawTarget)
    if not target or target == src then return end
    if pedsWithin(src, target, Config.ServerRange) ~= true then return end
    if not cooldownPassed(lastHandOver, src, Config.HandOverCooldownMs) then return end
    if not activeCharacter(src) then return end

    local paper = buildPaper(src)
    if not paper then return end
    -- re-check after the await: both still here and still close
    if not validSource(src) or not toPlayerId(target) then return end
    if pedsWithin(src, target, Config.ServerRange) ~= true then return end
    send(target, paper)
    send(src, paper)
end)

local function newToken()
    tokenCounter = tokenCounter + 1
    return ('%d-%d-%d'):format(tokenCounter, GetGameTimer(), math.random(100000, 999999))
end

-- Asks the target's own game whether its ped is hog-tied, cuffed or dead. Only the target may
-- answer; a target can only refuse, which protects nobody but themself.
local function askRestrained(target)
    local token = newToken()
    local p = promise.new()
    pending[token] = { target = target, p = p }
    SetTimeout(Config.RestraintReplyTimeoutMs, function()
        local entry = pending[token]
        if entry then
            pending[token] = nil
            entry.p:resolve(false)
        end
    end)
    TriggerClientEvent('pup_id:restraintQuery', target, token)
    return Citizen.Await(p)
end

RegisterNetEvent('pup_id:restraintReply', function(token, restrained)
    local src = validSource(source)
    if not src or type(token) ~= 'string' then return end
    local entry = pending[token]
    if not entry or entry.target ~= src then return end
    pending[token] = nil
    entry.p:resolve(restrained == true)
end)

local function isRestrained(target, ch)
    -- isdead is a boolean once vorp:ImDead has run, but may still be the database's 0/1 before that
    if ch.isdead == true or ch.isdead == 1 then return true end
    local ped = GetPlayerPed(tostring(target))
    if ped and ped ~= 0 and GetEntityHealth(ped) <= 0 then return true end
    return askRestrained(target)
end

-- inspect someone else's
RegisterNetEvent('pup_id:inspect', function(rawTarget)
    local src = validSource(source)
    if not src then return end
    if busy[src] then return end
    local target = toPlayerId(rawTarget)
    if not target or target == src then return end
    if not activeCharacter(src) then return end
    if not cooldownPassed(lastInspect, src, Config.InspectCooldownMs) then return end

    local near = pedsWithin(src, target, Config.ServerRange)
    if near == nil then return end
    if near == false then
        print(('^3[%s]^7 %s (%d) asked for the paper of %s from beyond %.1f m; refused.'):format(
            RESOURCE, GetPlayerName(tostring(src)) or '?', src, GetPlayerName(tostring(target)) or '?', Config.ServerRange))
        return
    end

    local ch = activeCharacter(target)
    if not ch then return end
    local charId = ch.charIdentifier

    busy[src] = true
    local ok, err = pcall(function()
        if Config.ServerRestraintCheck and not isRestrained(target, ch) then
            if validSource(src) then
                TriggerClientEvent('vorp:TipBottom', src, Locale.notRestrained, Config.TipMs)
            end
            return
        end
        local paper = buildPaper(target)
        if not paper then return end
        -- re-check after every await: same people, same character, still close
        if not validSource(src) or not toPlayerId(target) then return end
        local now = activeCharacter(target)
        if not now or now.charIdentifier ~= charId then return end
        if pedsWithin(src, target, Config.ServerRange) ~= true then return end
        send(src, paper)
    end)
    busy[src] = nil
    if not ok then print(('^1[%s]^7 inspect failed: %s'):format(RESOURCE, tostring(err))) end
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if not src then return end
    lastOwn[src], lastHandOver[src], lastInspect[src], busy[src] = nil, nil, nil, nil
    for token, entry in pairs(pending) do
        if entry.target == src then
            pending[token] = nil
            entry.p:resolve(false)
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= RESOURCE then return end
    for token, entry in pairs(pending) do
        pending[token] = nil
        entry.p:resolve(false)
    end
end)
