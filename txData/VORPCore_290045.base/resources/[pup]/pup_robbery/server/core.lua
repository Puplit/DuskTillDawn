-- pup_robbery | server core: VORP access, guarded calls into other resources, positions, rate limits

S = {}

local RES = GetCurrentResourceName()
local core = nil

function S.core()
    if core then return core end
    local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and c then
        core = c
        return core
    end
    TriggerEvent('getCore', function(c2) core = c2 end)
    return core
end

function S.dbg(fmt, ...)
    if not Config.Debug then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print(('^5[%s]^7 %s'):format(RES, ok and msg or tostring(fmt)))
end

function S.warn(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print(('^3[%s]^7 %s'):format(RES, ok and msg or tostring(fmt)))
end

--------------------------------------------------------------------------------
-- players and characters

function S.online(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and GetPlayerName(src) ~= nil
end

function S.user(src)
    local c = S.core()
    if not c or not S.online(src) then return nil end
    local ok, u = pcall(c.getUser, tonumber(src))
    if ok then return u end
    return nil
end

function S.char(src)
    local u = S.user(src)
    if not u then return nil end
    local ok, ch = pcall(function() return u.getUsedCharacter end)
    if ok then return ch end
    return nil
end

function S.charId(src)
    local ch = S.char(src)
    return ch and tonumber(ch.charIdentifier) or nil
end

function S.charName(src)
    local ch = S.char(src)
    if not ch then return GetPlayerName(src) or ('#' .. tostring(src)) end
    local n = ((ch.firstname or '') .. ' ' .. (ch.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if n == '' then n = GetPlayerName(src) or ('#' .. tostring(src)) end
    return n
end

function S.job(src)
    local ch = S.char(src)
    return ch and ch.job or nil
end

function S.jobBlocked(src)
    local job = S.job(src)
    return job ~= nil and Config.BlockedJobs[job] == true
end

function S.isAdmin(src)
    src = tonumber(src)
    if src == 0 then return true end
    local u = S.user(src)
    if not u then return false end
    local group = nil
    pcall(function() group = u.getGroup end)
    if group and Config.AdminGroups[group] then return true end
    local ch = S.char(src)
    return ch ~= nil and ch.group ~= nil and Config.AdminGroups[ch.group] == true
end

function S.srcForChar(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if s and S.charId(s) == charid then return s end
    end
    return nil
end

--------------------------------------------------------------------------------
-- messages

function S.tip(src, text, ms)
    if not src then return end
    TriggerClientEvent('vorp:TipRight', src, tostring(text), ms or 4000)
end

function S.toast(src, text)
    if not src then return end
    TriggerClientEvent('pup_robbery:toast', src, tostring(text))
end

--------------------------------------------------------------------------------
-- positions

function S.oneSync()
    local v = GetConvar('onesync', 'off')
    return v ~= 'off' and v ~= 'false'
end

-- position, or nil. With OneSync off the second value is true (positions cannot be checked).
function S.pos(src)
    if not S.oneSync() then return nil, true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, false end
    local c = GetEntityCoords(ped)
    if not c then return nil, false end
    return vector3(c.x, c.y, c.z), false
end

-- true when the player is within `range` of `point` (or OneSync is off and positions cannot be checked)
function S.near(src, point, range)
    local p, unchecked = S.pos(src)
    if unchecked then return true end
    if not p then return false end
    return U.dist(p, point) <= range
end

function S.alive(src)
    if not S.oneSync() then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return GetEntityHealth(ped) > 0
end

--------------------------------------------------------------------------------
-- guarded calls into optional resources

local warned = {}

function S.up(res)
    return GetResourceState(res) == 'started'
end

-- calls exports[res][fn](...) inside pcall; prints one warning per resource/function on failure
function S.call(res, fn, ...)
    if not S.up(res) then return false end
    local args = table.pack(...)
    local ok, a, b, c = pcall(function()
        local proxy = exports[res]
        return proxy[fn](proxy, table.unpack(args, 1, args.n))
    end)
    if not ok then
        local key = res .. ':' .. fn
        if not warned[key] then
            warned[key] = true
            S.warn('%s:%s failed (%s) - carrying on without it', res, fn, tostring(a))
        end
        return false
    end
    return true, a, b, c
end

--------------------------------------------------------------------------------
-- rate limits

local gates = {}

function S.rate(src, key, ms)
    local now = GetGameTimer()
    gates[src] = gates[src] or {}
    local last = gates[src][key]
    if last and now - last < ms then return false end
    gates[src][key] = now
    return true
end

function S.forget(src)
    gates[src] = nil
end

--------------------------------------------------------------------------------
-- inventory (vorp_inventory exports, called directly)

function S.itemCount(src, item)
    local ok, n = pcall(function() return exports.vorp_inventory:getItemCount(src, nil, item) end)
    return ok and tonumber(n) or 0
end

function S.takeItem(src, item, amount)
    local ok, r = pcall(function() return exports.vorp_inventory:subItem(src, item, amount or 1) end)
    return ok and r == true
end

-- canCarryItem checks the item limit and the satchel weight; canCarryItems answers false for unlimited capacity (-1)
function S.canCarry(src, item, amount)
    local ok, one = pcall(function() return exports.vorp_inventory:canCarryItem(src, item, amount) end)
    return ok and one == true
end

function S.giveItem(src, item, amount, metadata)
    local ok, r = pcall(function() return exports.vorp_inventory:addItem(src, item, amount, metadata or {}) end)
    return ok and r == true
end

local labels = {}
function S.itemLabel(item, fallback)
    if labels[item] then return labels[item] end
    local ok, def = pcall(function() return exports.vorp_inventory:getItemDB(item) end)
    local label = nil
    if ok and type(def) == 'table' then
        label = def.label
        if not label and type(def.getLabel) == 'function' then
            local ok2, l = pcall(def.getLabel, def)
            if ok2 then label = l end
        end
    end
    if type(label) == 'string' and label ~= '' then
        labels[item] = label
        return label
    end
    return fallback or item
end

function S.addCash(src, amount, currency)
    local ch = S.char(src)
    if not ch or amount <= 0 then return false end
    local ok = pcall(function() ch.addCurrency(currency or 0, amount) end)
    return ok
end

--------------------------------------------------------------------------------
-- posse (pup-ui)

function S.posseMembers(src)
    local ok, list = S.call('pup-ui', 'GetPosseMembers', src)
    if ok and type(list) == 'table' and #list > 0 then
        local out = {}
        for _, s in ipairs(list) do
            s = tonumber(s)
            if s and S.online(s) then out[#out + 1] = s end
        end
        return out
    end
    return { src }
end

function S.posseInfo(src)
    local ok, p = S.call('pup-ui', 'GetPosse', src)
    if ok and type(p) == 'table' then return p end
    return { inPosse = false }
end

function S.posseMax()
    local ok, cfg = S.call('pup-ui', 'GetPosseLocalConfig')
    if ok and type(cfg) == 'table' and tonumber(cfg.maxSize) then return tonumber(cfg.maxSize) end
    return 5
end

function S.posseCommand()
    local ok, cfg = S.call('pup-ui', 'GetPosseLocalConfig')
    if ok and type(cfg) == 'table' and type(cfg.command) == 'string' then return cfg.command end
    return Config.PosseCommand
end

--------------------------------------------------------------------------------
-- perks (pup-perks)

local P = Config.Perks

function S.perkHas(src, key)
    local ok, v = S.call('pup-perks', 'Has', src, key)
    return ok and v == true
end

function S.perkRoll(src, key)
    local ok, v = S.call('pup-perks', 'Roll', src, key)
    return ok and v == true
end

function S.perkMult(src, key)
    local ok, v = S.call('pup-perks', 'Mult', src, key)
    return ok and tonumber(v) or 1.0
end

function S.perkBonus(src, key)
    local ok, v = S.call('pup-perks', 'Bonus', src, key)
    return ok and tonumber(v) or 0
end

function S.perkRank(src, perkId)
    local ok, v = S.call('pup-perks', 'GetRank', src, perkId)
    return ok and tonumber(v) or 0
end

function S.award(src, kind)
    S.call('pup-perks', 'Award', src, kind)
end

-- XP to the looter and every online posse rider within the share range
function S.awardShared(src, kind)
    S.award(src, kind)
    local range = tonumber(Config.Walkup.xpShareRange) or 0
    local me = S.pos(src)
    for _, m in ipairs(S.posseMembers(src)) do
        if m ~= src then
            local ok = true
            if range > 0 and me then
                local p = S.pos(m)
                ok = p ~= nil and U.dist(me, p) <= range
            end
            if ok then S.award(m, kind) end
        end
    end
end

-- a personal clock length in seconds, shortened once by Cool Head when the character is online
function S.personalSeconds(minutes, src)
    local mult = 1.0
    if src and S.online(src) then
        mult = U.clamp(S.perkMult(src, P.cooldown), Config.CooldownPerkClamp.min, Config.CooldownPerkClamp.max)
    end
    return math.floor(minutes * 60 * mult)
end

function S.lone(src)
    return S.perkHas(src, P.solo)
end

-- gang points: { min, max } gives a whole number between them (min at least 1),
-- a number N gives 40% of N up to N, nothing gives 0
function S.rollPoints(spec)
    if type(spec) == 'table' then
        local lo = math.max(1, math.floor(tonumber(spec[1] or spec.min) or 1))
        local hi = math.max(lo, math.floor(tonumber(spec[2] or spec.max) or lo))
        return math.random(lo, hi)
    end
    local n = tonumber(spec)
    if n and n > 0 then
        local lo = math.max(1, math.floor(n * 0.4))
        return math.random(lo, math.max(lo, math.floor(n)))
    end
    return 0
end

--------------------------------------------------------------------------------
-- lawmen (pup-mdt)

-- on-duty lawmen in any of the regions (nil = every region): count and a set of server ids
function S.lawmen(regions)
    local set, n = {}, 0
    if not S.up('pup-mdt') then return 0, set end
    local list = regions
    if type(list) ~= 'table' or #list == 0 then list = { false } end
    for _, region in ipairs(list) do
        local ok, rows = S.call('pup-mdt', 'GetPlayersOnDuty', region or nil)
        if ok and type(rows) == 'table' then
            for _, r in ipairs(rows) do
                local s = tonumber(type(r) == 'table' and r.source or r)
                if s and S.online(s) and not set[s] then
                    set[s] = true
                    n = n + 1
                end
            end
        end
    end
    return n, set
end

function S.lawOk(regions, need)
    if Config.TestMode.ignoreLaw then return true, 0 end
    local n = S.lawmen(regions)
    return n >= (tonumber(need) or 0), n
end

--------------------------------------------------------------------------------
-- server callbacks (VORP), registered once the core is up

local pendingCallbacks = {}
local callbacksLive = false

local function registerCallback(name, fn)
    S.core().Callback.Register(name, function(source, reply, ...)
        local ok, a = pcall(fn, source, ...)
        if not ok then
            S.warn('callback %s failed: %s', name, tostring(a))
            return reply(false)
        end
        reply(a)
    end)
end

function S.callback(name, fn)
    if callbacksLive then return registerCallback(name, fn) end
    pendingCallbacks[#pendingCallbacks + 1] = { name = name, fn = fn }
end

CreateThread(function()
    local tries = 0
    while not S.core() do
        tries = tries + 1
        if tries == 40 then S.warn('still waiting for vorp_core') end
        Wait(500)
    end
    for _, cb in ipairs(pendingCallbacks) do registerCallback(cb.name, cb.fn) end
    pendingCallbacks = {}
    callbacksLive = true
end)
