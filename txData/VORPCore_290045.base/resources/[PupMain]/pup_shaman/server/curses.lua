-- pup_shaman | the curse store: every curse read and write goes through here

Store = {}

local cache = {}    -- src -> curse key ('' = none)
local gen = {}      -- src -> counter, bumped by every write and drop so stale loads never land
local loading = {}  -- src -> true while a load is in flight

local function bump(src)
    gen[src] = (gen[src] or 0) + 1
    return gen[src]
end

--- May this player see tree blips?
local function blipsAllowed(job)
    if not Config.TreeRules.jobLock then return true end
    for _, j in ipairs(Config.TreeRules.blipJobs) do
        if j == job then return true end
    end
    return false
end

function Store.SendBlips(src, job)
    TriggerClientEvent('pup_shaman:client:blips', src, blipsAllowed(job))
end

--- Tells everyone who cares. mode: 'load' (no notice), 'change' (the client gives one notice), 'quiet' (caller gives its own)
local function announce(src, key, elapsed, mode)
    if not Shaman.Online(src) then return end
    Player(src).state:set('pup_curse', key ~= '' and key or nil, true)
    TriggerEvent('pup_shaman:curseChanged', src, key)
    TriggerClientEvent('pup_shaman:client:curse', src, key, elapsed or 0, mode or 'load')
end

--- Forgets the cached value (drop or switch).
function Store.Drop(src)
    cache[src] = nil
    bump(src)
end

--- The cached value without touching the database ('' when nothing is cached).
function Store.Peek(src)
    return cache[src] or ''
end

--- Reads the player's curse from the database, caches it and announces it.
function Store.Load(src)
    src = tonumber(src)
    if not src then return '' end
    -- another load is already running for this player: wait for it
    local waited = 0
    while loading[src] and waited < 10000 do
        Wait(50)
        waited = waited + 50
    end
    if cache[src] ~= nil then return cache[src] end

    local char = Shaman.Character(src)
    if not char then
        cache[src] = ''
        return ''
    end
    local charId = tonumber(char.charIdentifier)
    local g = bump(src)
    loading[src] = true

    local ok, key, elapsed = pcall(function()
        local raw = MySQL.scalar.await('SELECT `curse` FROM `characters` WHERE `charidentifier` = ?', { charId })
        local k = type(raw) == 'string' and raw or ''
        if k ~= '' and not Config.Curses[k] then
            Shaman.Debug('character %d carries unknown curse "%s"; kept as it is', charId, k)
        end
        local e = 0
        local def = Config.Curses[k]
        if def and def.course then
            local row = MySQL.single.await('SELECT `curse`, `started_at` FROM `shaman_afflictions` WHERE `charid` = ?', { charId })
            if row and row.curse == k then
                e = math.max(0, os.time() - (tonumber(row.started_at) or os.time()))
            else
                -- a harmful curse with no course on record starts one now
                MySQL.insert.await([[INSERT INTO `shaman_afflictions` (`charid`, `curse`, `started_at`) VALUES (?, ?, ?)
                    ON DUPLICATE KEY UPDATE `curse` = VALUES(`curse`), `started_at` = VALUES(`started_at`)]],
                    { charId, k, os.time() })
            end
        end
        return k, e
    end)
    loading[src] = nil
    if not ok then
        print(('[pup_shaman] could not load the curse for %d: %s'):format(src, tostring(key)))
        return cache[src] or ''
    end
    -- a write, drop or switch happened meanwhile: theirs wins
    if gen[src] ~= g or not Shaman.SameChar(src, charId) then
        return cache[src] or ''
    end
    cache[src] = key
    announce(src, key, elapsed, 'load')
    Store.SendBlips(src, char.job)
    return key
end

--- The curse key the player carries ('' for none), loading it if needed.
function Store.Get(src)
    src = tonumber(src)
    if not src or not Shaman.Online(src) then return '' end
    local v = cache[src]
    if v ~= nil then return v end
    return Store.Load(src)
end

--- Gives a curse. Refused (false) without a character or for an unknown key.
function Store.Set(src, key, mode)
    src = tonumber(src)
    local char = src and Shaman.Character(src)
    if not char or type(key) ~= 'string' or not Config.Curses[key] then return false end
    local charId = tonumber(char.charIdentifier)
    local def = Config.Curses[key]
    cache[src] = key
    local g = bump(src)
    local ok, err = pcall(function()
        MySQL.update.await('UPDATE `characters` SET `curse` = ? WHERE `charidentifier` = ?', { key, charId })
        if def.course then
            MySQL.insert.await([[INSERT INTO `shaman_afflictions` (`charid`, `curse`, `started_at`) VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE `curse` = VALUES(`curse`), `started_at` = VALUES(`started_at`)]],
                { charId, key, os.time() })
        else
            MySQL.update.await('DELETE FROM `shaman_afflictions` WHERE `charid` = ?', { charId })
        end
    end)
    if not ok then
        print(('[pup_shaman] could not save curse %s for character %d: %s'):format(key, charId, tostring(err)))
    end
    -- a later write for this player announces instead of us
    if gen[src] == g and Shaman.SameChar(src, charId) then
        announce(src, key, 0, mode or 'change')
    end
    return true
end

--- Lifts any curse. Always true.
function Store.Clear(src, mode)
    src = tonumber(src)
    if not src then return true end
    cache[src] = ''
    local g = bump(src)
    local charId = Shaman.CharId(src)
    if charId then
        local ok, err = pcall(function()
            MySQL.update.await('UPDATE `characters` SET `curse` = NULL WHERE `charidentifier` = ?', { charId })
            MySQL.update.await('DELETE FROM `shaman_afflictions` WHERE `charid` = ?', { charId })
        end)
        if not ok then
            print(('[pup_shaman] could not clear the curse of character %d: %s'):format(charId, tostring(err)))
        end
    end
    if gen[src] == g then
        announce(src, '', 0, mode or 'change')
    end
    return true
end

--- Winds a harmful course back to its rewind step. False without a character or a harmful curse.
function Store.Ease(src)
    src = tonumber(src)
    local charId = src and Shaman.CharId(src)
    if not charId then return false end
    local key = Store.Get(src)
    local course = Rules.CourseOf(key)
    if not course or not Shaman.SameChar(src, charId) then return false end
    local elapsed = course.easeToStep * course.stepSeconds
    local ok = pcall(function()
        MySQL.insert.await([[INSERT INTO `shaman_afflictions` (`charid`, `curse`, `started_at`) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE `curse` = VALUES(`curse`), `started_at` = VALUES(`started_at`)]],
            { charId, key, os.time() - elapsed })
    end)
    if not ok then return false end
    if Shaman.SameChar(src, charId) and cache[src] == key then
        TriggerClientEvent('pup_shaman:client:courseElapsed', src, key, elapsed)
    end
    return true
end

--- Offline cleanse by character id.
function Store.ClearOffline(charId)
    MySQL.update.await('UPDATE `characters` SET `curse` = NULL WHERE `charidentifier` = ?', { charId })
    MySQL.update.await('DELETE FROM `shaman_afflictions` WHERE `charid` = ?', { charId })
end

-- exports for other resources
exports('GetCurse', function(src) return Store.Get(src) end)
exports('SetCurse', function(src, curse) return Store.Set(src, curse, 'change') end)
exports('ClearCurse', function(src) return Store.Clear(src, 'change') end)
exports('IsTransformed', function(src)
    src = tonumber(src)
    if not src or not Shaman.Online(src) then return false end
    return Shaman.Form(src) or false
end)

-- job changes refresh the tree blips
AddEventHandler('vorp:playerJobChange', function(src, newJob)
    src = tonumber(src)
    if src and Shaman.Online(src) then Store.SendBlips(src, newJob) end
end)

-- cure items
local cureBusy = {}
local registeredCures = {}

local function registerCures()
    for _, def in pairs(Config.Curses) do
        local item = def.cure
        if item and not registeredCures[item] then
            registeredCures[item] = true
            exports.vorp_inventory:registerUsableItem(item, function(data)
                local src = tonumber(data and data.source)
                if not src or cureBusy[src] or not Shaman.Character(src) then return end
                cureBusy[src] = true
                local key = Store.Get(src)
                local current = Rules.Curse(key)
                if not current or current.cure ~= item or not Shaman.Character(src) then
                    cureBusy[src] = nil
                    return Shaman.Notify(src, L('cure_nothing'))
                end
                if not exports.vorp_inventory:subItem(src, item, 1) then
                    cureBusy[src] = nil
                    return
                end
                exports.vorp_inventory:closeInventory(src)
                Store.Clear(src, 'change')
                TriggerClientEvent('pup_shaman:client:drinkCure', src)
                cureBusy[src] = nil
            end, GetCurrentResourceName())
        end
    end
end

CreateThread(registerCures)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for item in pairs(registeredCures) do
        pcall(function() exports.vorp_inventory:unRegisterUsableItem(item) end)
    end
end)

-- the client reports a death (in a form or while carrying a curse that lifts on death)
RegisterNetEvent('pup_shaman:server:died', function(inForm)
    local src = source
    if not Shaman.Throttle(src, 'died', 3000) then return end
    local char = Shaman.Character(src)
    if not char then return end
    if inForm == true then Shaman.SetForm(src, nil) end
    local def = Rules.Curse(Store.Get(src))
    if not def or not def.liftOnDeath then return end
    -- trust only a ped the server can see and that is really down
    local ped = Shaman.Ped(src)
    if not ped or GetEntityHealth(ped) > 0 then return end
    if not Shaman.SameChar(src, char.charIdentifier) then return end
    Store.Clear(src, 'change')
end)

AddEventHandler('playerDropped', function()
    local src = source
    cureBusy[src] = nil
    loading[src] = nil
    gen[src] = nil
end)
