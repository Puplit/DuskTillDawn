-- pup_gunsmith | server foundation: core object, player state, guards and helpers

Core = exports.vorp_core:GetCore()

Srv = {
    state = {},     -- [src] = per-player state, see Srv.st
    resetters = {}, -- functions run when a player's state must be dropped
}

---------------------------------------------------------------------------
-- logging
---------------------------------------------------------------------------
function Srv.debug(fmt, ...)
    if not Config.Debug.general then return end
    print(('[pup_gunsmith] ' .. fmt):format(...))
end

function Srv.who(src)
    return ('%s [%s]'):format(GetPlayerName(src) or '?', tostring(src))
end

function Srv.security(src, fmt, ...)
    print(('^1[pup_gunsmith SECURITY]^7 %s: ' .. fmt):format(Srv.who(src), ...))
end

---------------------------------------------------------------------------
-- players and characters
---------------------------------------------------------------------------
function Srv.validSource(src)
    return type(src) == 'number' and src > 0 and GetPlayerName(src) ~= nil
end

--- the player's current character, or nil
function Srv.char(src)
    local user = Core.getUser(src)
    if not user then return nil end
    local c = user.getUsedCharacter
    if not c or not c.charIdentifier then return nil end
    return c
end

function Srv.grade(c)
    return tonumber(c.jobGrade or c.jobgrade or c.grade) or 0
end

function Srv.fullName(c)
    return GS.trim(('%s %s'):format(c.firstname or '', c.lastname or ''))
end

--- per-player state; created on demand and bound to the character it was made for
function Srv.st(src, char)
    local s = Srv.state[src]
    if s and char then
        if s.charId == nil then
            s.charId = char.charIdentifier
        elseif s.charId ~= char.charIdentifier then
            Srv.reset(src, 'character changed')
            s = nil
        end
    end
    if not s then
        s = { charId = char and char.charIdentifier or nil, throttle = {} }
        Srv.state[src] = s
    end
    return s
end

function Srv.onReset(fn)
    Srv.resetters[#Srv.resetters + 1] = fn
end

function Srv.reset(src, why)
    local s = Srv.state[src]
    if not s then return end
    for _, fn in ipairs(Srv.resetters) do
        local ok, err = pcall(fn, src, s, why)
        if not ok then print(('^1[pup_gunsmith]^7 reset hook failed: %s'):format(tostring(err))) end
    end
    Srv.state[src] = nil
end

AddEventHandler('playerDropped', function()
    Srv.reset(source, 'dropped')
end)

-- vorp_core fires this server-locally (src, character) on every character select
AddEventHandler('vorp:SelectedCharacter', function(src)
    if type(src) == 'number' then Srv.reset(src, 'character select') end
end)

---------------------------------------------------------------------------
-- job / grade access
---------------------------------------------------------------------------
function Srv.hasAccess(char, jobs, minGrade)
    if not Config.JobOnly then return true end
    if not GS.inList(jobs, char.job) then return false end
    return Srv.grade(char) >= (minGrade or 0)
end

---------------------------------------------------------------------------
-- distance (OneSync). Without a server-side position every check passes,
-- with one warning per area.
---------------------------------------------------------------------------
local noOneSyncWarned = {}

function Srv.near(src, pos, reach, area)
    local ped = GetPlayerPed(src)
    local c = (ped and ped ~= 0) and GetEntityCoords(ped) or nil
    if not c or (c.x == 0.0 and c.y == 0.0 and c.z == 0.0) then
        area = area or 'general'
        if not noOneSyncWarned[area] then
            noOneSyncWarned[area] = true
            print(('^3[pup_gunsmith]^7 the server cannot see player positions (%s); distance checks are passing. Is OneSync on?'):format(area))
        end
        return true
    end
    return #(c - pos) <= reach
end

function Srv.coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 and c.z == 0.0 then return nil end
    return c
end

---------------------------------------------------------------------------
-- spam guards
---------------------------------------------------------------------------
--- true when the call may go ahead; false when the same key ran less than `ms` ago
function Srv.throttle(src, key, ms)
    local s = Srv.state[src] or Srv.st(src, nil)
    local now = GetGameTimer()
    local last = s.throttle[key]
    if last and now - last < ms then return false end
    s.throttle[key] = now
    return true
end

-- one money/inventory action at a time per player
local busy = {}
function Srv.tryLock(src)
    if busy[src] then return false end
    busy[src] = true
    return true
end
function Srv.unlock(src) busy[src] = nil end
Srv.onReset(function(src) busy[src] = nil end)

---------------------------------------------------------------------------
-- callbacks
---------------------------------------------------------------------------
--- Registers pup_gunsmith:<name>. The handler receives (src, char, ...) and returns one value.
--- opts.exclusive: refuse while another exclusive call of this player is running.
--- opts.throttle: minimum ms between calls.
function Srv.rpc(name, handler, opts)
    opts = opts or {}
    Core.Callback.Register('pup_gunsmith:' .. name, function(source, cb, ...)
        local src = source
        if not Srv.validSource(src) then return cb(nil) end
        local char = Srv.char(src)
        if not char then return cb({ ok = false }) end
        Srv.st(src, char)
        if opts.throttle and not Srv.throttle(src, 'rpc:' .. name, opts.throttle) then
            return cb({ ok = false, busy = true })
        end
        if opts.exclusive and not Srv.tryLock(src) then
            return cb({ ok = false, busy = true })
        end
        local ok, res = pcall(handler, src, char, ...)
        if opts.exclusive then Srv.unlock(src) end
        if not ok then
            print(('^1[pup_gunsmith]^7 %s failed: %s'):format(name, tostring(res)))
            res = { ok = false }
        end
        cb(res)
    end)
end

--- the character is still the one this call started with (after an await)
function Srv.same(src, char)
    local now = Srv.char(src)
    return now ~= nil and now.charIdentifier == char.charIdentifier
end

---------------------------------------------------------------------------
-- notifications and money
---------------------------------------------------------------------------
function Srv.tip(src, msg, ms)
    TriggerClientEvent('vorp:TipRight', src, msg, ms or 4000)
end

function Srv.cash(src)
    local c = Srv.char(src)
    return c and (tonumber(c.money) or 0) or 0
end

function Srv.gold(src)
    local c = Srv.char(src)
    return c and (tonumber(c.gold) or 0) or 0
end

function Srv.wallet(src)
    return { cash = Srv.cash(src), gold = Srv.gold(src) }
end

function Srv.takeMoney(src, currency, amount)
    if amount <= 0 then return true end
    local user = Core.getUser(src)
    local c = user and user.getUsedCharacter
    if not c then return false end
    local have = currency == 1 and (tonumber(c.gold) or 0) or (tonumber(c.money) or 0)
    if have + 1e-9 < amount then return false end
    c.removeCurrency(currency, amount)
    return true
end

function Srv.giveMoney(src, currency, amount)
    if amount <= 0 then return end
    local user = Core.getUser(src)
    local c = user and user.getUsedCharacter
    if c then c.addCurrency(currency, amount) end
end

---------------------------------------------------------------------------
-- inventory helpers
---------------------------------------------------------------------------
Inv = exports.vorp_inventory

function Srv.count(src, item)
    local ok, n = pcall(function() return Inv:getItemCount(src, nil, item) end)
    return ok and (tonumber(n) or 0) or 0
end

--- materials list { {name, label, amount} } times `times`; true when all are held
function Srv.hasMaterials(src, mats, times)
    for _, m in ipairs(mats) do
        if Srv.count(src, m.name) < m.amount * times then return false end
    end
    return true
end

--- removes materials; on a partial failure puts back what was taken. Returns success.
function Srv.takeMaterials(src, mats, times)
    local taken = {}
    for _, m in ipairs(mats) do
        local amount = m.amount * times
        if amount > 0 then
            local ok, res = pcall(function() return Inv:subItem(src, m.name, amount) end)
            if not ok or not res then
                for _, t in ipairs(taken) do
                    pcall(function() Inv:addItem(src, t.name, t.amount) end)
                end
                return false
            end
            taken[#taken + 1] = { name = m.name, amount = amount }
        end
    end
    return true
end

function Srv.giveMaterials(src, mats, times)
    for _, m in ipairs(mats) do
        local amount = m.amount * times
        if amount > 0 then pcall(function() Inv:addItem(src, m.name, amount) end) end
    end
end

---------------------------------------------------------------------------
-- small JSON helpers
---------------------------------------------------------------------------
function Srv.decode(s, fallback)
    if type(s) ~= 'string' or s == '' then return fallback end
    local ok, v = pcall(json.decode, s)
    if ok and v ~= nil then return v end
    return fallback
end
