-- pup_shaman | server core: helpers shared by the server modules, schema and the player lifecycle

Core = exports.vorp_core:GetCore()

Shaman = {
    ready = false,      -- schema checked and online players loaded
    leaveHooks = {},    -- fn(src, reason, oldCharId) on drop ('drop') or character switch ('switch')
    selectHooks = {},   -- fn(src, char) after a character is selected
}

local RESOURCE <const> = GetCurrentResourceName()

function Shaman.Debug(fmt, ...)
    if not Config.Debug then return end
    local ok, text = pcall(string.format, fmt, ...)
    print(('[%s] %s'):format(RESOURCE, ok and text or fmt))
end

function Shaman.Online(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and GetPlayerName(src) ~= nil
end

--- The player's active character (a fresh snapshot), or nil.
function Shaman.Character(src)
    src = tonumber(src)
    if not src or not Shaman.Online(src) then return nil end
    local user = Core.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if type(char) ~= 'table' or not char.charIdentifier then return nil end
    return char
end

function Shaman.CharId(src)
    local char = Shaman.Character(src)
    return char and tonumber(char.charIdentifier) or nil
end

--- True while src still has the character charId loaded.
function Shaman.SameChar(src, charId)
    return charId ~= nil and Shaman.CharId(src) == tonumber(charId)
end

function Shaman.Notify(src, msg, ms)
    if not Shaman.Online(src) or not msg or msg == '' then return end
    Core.NotifyRightTip(src, msg, ms or 4000)
end

function Shaman.Ped(src)
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and DoesEntityExist(ped) then return ped end
    return nil
end

function Shaman.Coords(src)
    local ped = Shaman.Ped(src)
    return ped and GetEntityCoords(ped) or nil
end

function Shaman.Distance(srcA, srcB)
    local a, b = Shaman.Coords(srcA), Shaman.Coords(srcB)
    if not a or not b then return math.huge end
    return #(a - b)
end

--- Dead by the character flag or by the ped's health.
function Shaman.IsDead(src, char)
    char = char or Shaman.Character(src)
    if not char then return true end
    if char.isdead == true or char.isdead == 1 then return true end
    local ped = Shaman.Ped(src)
    return not ped or GetEntityHealth(ped) <= 0
end

function Shaman.FullName(char)
    if not char then return '?' end
    local name = ('%s %s'):format(char.firstname or '', char.lastname or '')
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or '?'
end

--- The form key in the pup_form state bag, or nil.
function Shaman.Form(src)
    local v = Player(src).state.pup_form
    if type(v) == 'string' and v ~= '' then return v end
    return nil
end

function Shaman.SetForm(src, key)
    if not Shaman.Online(src) then return end
    Player(src).state:set('pup_form', key, true)
end

--- Per-player rate limit: true when the action may go ahead.
local stamps = {}
function Shaman.Throttle(src, key, ms)
    local now = GetGameTimer()
    local t = stamps[src]
    if not t then t = {}; stamps[src] = t end
    if t[key] and now - t[key] < ms then return false end
    t[key] = now
    return true
end

--- Is pup-bloodmoon's blood moon up? Any error counts as no.
function Shaman.BloodMoon()
    local bm = Config.BloodMoon
    if not bm.enabled or GetResourceState(bm.resource) ~= 'started' then return false end
    local ok, up = pcall(function() return exports[bm.resource]:IsBloodMoon() end)
    return ok and up == true
end

--- The other online players, as numbers.
function Shaman.Players()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local n = tonumber(id)
        if n then list[#list + 1] = n end
    end
    return list
end

function Shaman.OnLeave(fn) Shaman.leaveHooks[#Shaman.leaveHooks + 1] = fn end
function Shaman.OnSelect(fn) Shaman.selectHooks[#Shaman.selectHooks + 1] = fn end

local function runLeave(src, reason, oldCharId)
    for _, fn in ipairs(Shaman.leaveHooks) do
        local ok, err = pcall(fn, src, reason, oldCharId)
        if not ok then print(('[%s] leave hook failed: %s'):format(RESOURCE, tostring(err))) end
    end
end

-- schema (additive only)
local function ensureSchema()
    local has = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters' AND COLUMN_NAME = 'curse'
    ]])
    if tonumber(has) == 0 then
        MySQL.query.await('ALTER TABLE `characters` ADD COLUMN `curse` VARCHAR(255) DEFAULT NULL')
        print(('[%s] added characters.curse'):format(RESOURCE))
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `shaman_afflictions` (
            `charid` INT(11) NOT NULL,
            `curse` VARCHAR(32) NOT NULL,
            `started_at` INT(11) NOT NULL,
            PRIMARY KEY (`charid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

-- lifecycle
-- the last character each server id had loaded, so a switch knows what it is leaving
local lastChar = {}

AddEventHandler('onResourceStart', function(res)
    if res ~= RESOURCE then return end
    CreateThread(function()
        local ok, err = pcall(ensureSchema)
        if not ok then print(('[%s] schema check failed: %s'):format(RESOURCE, tostring(err))) end
        -- no one is in a form after a restart: the clients went back to human when we stopped
        for _, src in ipairs(Shaman.Players()) do
            Shaman.SetForm(src, nil)
        end
        for _, src in ipairs(Shaman.Players()) do
            local char = Shaman.Character(src)
            if char then
                lastChar[src] = tonumber(char.charIdentifier)
                Store.Load(src)
            end
        end
        Shaman.ready = true
    end)
end)

-- the client finished starting (resource start or a late join) and asks for its state
RegisterNetEvent('pup_shaman:server:hello', function()
    local src = source
    if not Shaman.Online(src) or not Shaman.Throttle(src, 'hello', 5000) then return end
    -- a client that has just started is human
    Shaman.SetForm(src, nil)
    local char = Shaman.Character(src)
    if not char then return end
    lastChar[src] = tonumber(char.charIdentifier)
    Store.Drop(src)
    Store.Load(src)
end)

AddEventHandler('vorp:SelectedCharacter', function(src, char)
    src = tonumber(src)
    if not src then return end
    local old = lastChar[src]
    lastChar[src] = char and tonumber(char.charIdentifier) or nil
    -- whatever the last character was doing ends here
    runLeave(src, 'switch', old)
    Shaman.SetForm(src, nil)
    TriggerClientEvent('pup_shaman:client:reset', src)
    Store.Drop(src)
    CreateThread(function()
        Store.Load(src)
        local now = Shaman.Character(src)
        if not now then return end
        for _, fn in ipairs(Shaman.selectHooks) do
            local ok, err = pcall(fn, src, now)
            if not ok then print(('[%s] select hook failed: %s'):format(RESOURCE, tostring(err))) end
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    runLeave(src, 'drop', lastChar[src])
    lastChar[src] = nil
    stamps[src] = nil
    Store.Drop(src)
end)
