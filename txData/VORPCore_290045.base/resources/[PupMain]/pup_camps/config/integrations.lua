-- pup_camps | adapters for optional resources (each runs only when its resource is started)

Integrations = {}

local function running(res)
    return GetResourceState(res) == 'started'
end
Integrations.running = running

-- one console warning per topic, so a missing API is visible without flooding the log
local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[pup_camps]^7 %s'):format(msg))
end
Integrations.warnOnce = warnOnce

-- call an export inside pcall; a failure is reported once and gives nil
local function call(res, key, fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    warnOnce(res .. ':' .. key, ('%s export %s failed: %s'):format(res, key, tostring(a)))
    return nil
end

if IsDuplicityVersion() then
    ------------------------------------------------------------------ server
    -- pup-misc Eco Boost: ApplyEcoBoostSale(src, placeName, total) returns the bonus to pay
    -- on top (0 = none). The place name must contain "Butcher" or "Trapper" to count.
    Integrations.ecoBonus = function(src, placeName, amount)
        if not running('pup-misc') then return 0 end
        local v = call('pup-misc', 'ApplyEcoBoostSale', function()
            return exports['pup-misc']:ApplyEcoBoostSale(src, placeName, amount)
        end)
        return tonumber(v) or 0
    end

    -- skinanimals: was this carcass skinned already? (IsCarcassSkinned(netId) -> bool)
    Integrations.isSkinned = function(netId)
        if not running('skinanimals') then return false end
        return call('skinanimals', 'IsCarcassSkinned', function()
            return exports['skinanimals']:IsCarcassSkinned(netId)
        end) == true
    end

    -- skinanimals: mark a carcass taken out of the wagon as skinned (MarkCarcassSkinned(netId))
    Integrations.markSkinned = function(netId)
        if not running('skinanimals') then return end
        call('skinanimals', 'MarkCarcassSkinned', function()
            exports['skinanimals']:MarkCarcassSkinned(netId)
        end)
    end

    -- pup_postoffice system mail: SendSystemMail(charid, subject, body, fromName) -> true, or
    -- false when the character has no box. It runs two awaited queries, so call it from a thread.
    Integrations.sendMail = function(charid, subject, body, fromName)
        if not running('pup_postoffice') then return false end
        return call('pup_postoffice', 'SendSystemMail', function()
            return exports['pup_postoffice']:SendSystemMail(charid, subject, body, fromName)
        end) == true
    end

    -- pup-perks
    Integrations.perkMult = function(src, key)
        if not running('pup-perks') then return 1.0 end
        return tonumber(exports['pup-perks']:Mult(src, key)) or 1.0
    end
    Integrations.perkAward = function(src, kind)
        if not running('pup-perks') then return end
        exports['pup-perks']:Award(src, kind)
    end

    -- vorp_admin: may this player use the given admin action?
    Integrations.adminAllowed = function(src, action)
        if not running('vorp_admin') then return false end
        return exports['vorp_admin']:allowedToExecuteAction(src, action) == true
    end

    -- vorp_admin spawn guard: let a player's client create this networked model for a moment
    Integrations.allowSpawn = function(src, model, ms)
        if not running('vorp_admin') then return end
        exports['vorp_admin']:SpawnGuardAllow(src, model, ms or 15000)
    end
else
    ------------------------------------------------------------------ client
    -- pup-stable keeps the lists keyed by database id: getMyHorses(waiter, forceRefresh) and
    -- getMyWagons(waiter, forceRefresh). A horse row has id, name, model, isDead, favourite;
    -- a wagon row has id, name, model.
    local function horseMap()
        if not running('pup-stable') then return {} end
        local t = call('pup-stable', 'getMyHorses', function() return exports['pup-stable']:getMyHorses(true, false) end)
        return type(t) == 'table' and t or {}
    end
    local function wagonMap()
        if not running('pup-stable') then return {} end
        local t = call('pup-stable', 'getMyWagons', function() return exports['pup-stable']:getMyWagons(true, false) end)
        return type(t) == 'table' and t or {}
    end
    local function byId(map, id)
        for _, row in pairs(map) do
            if type(row) == 'table' and tonumber(row.id) == tonumber(id) then return row end
        end
        return nil
    end
    local function sorted(list)
        table.sort(list, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
        return list
    end

    -- the player's horses as an array of { id, name, dead, active }
    Integrations.horses = function()
        local out = {}
        for _, h in pairs(horseMap()) do
            if type(h) == 'table' and h.id then
                out[#out + 1] = { id = h.id, name = h.name, dead = h.isDead == true or h.isDead == 1,
                    active = h.favourite == true or h.favourite == 1 }
            end
        end
        return sorted(out)
    end
    -- the player's wagons as an array of { id, name, model }
    Integrations.wagons = function()
        local out = {}
        for _, w in pairs(wagonMap()) do
            if type(w) == 'table' and w.id then out[#out + 1] = { id = w.id, name = w.name, model = w.model } end
        end
        return sorted(out)
    end
    -- SpawnHorse(horseData, vector4, fixLocation, withComponent, isNetworked) -> ped or nil
    Integrations.spawnHorse = function(id, coords, heading)
        if not running('pup-stable') then return false end
        local h = byId(horseMap(), id)
        if not h then return false end
        local data = {}
        for k, v in pairs(h) do data[k] = v end
        local ent = call('pup-stable', 'SpawnHorse', function()
            return exports['pup-stable']:SpawnHorse(data, vector4(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, heading + 0.0), false, true, true)
        end)
        return ent ~= nil and ent ~= 0 and DoesEntityExist(ent)
    end
    -- SpawnWagon(wagonData, vector4, fixLocation, isNetworked) -> vehicle or nil
    Integrations.spawnWagon = function(id, coords, heading)
        if not running('pup-stable') then return false end
        local w = byId(wagonMap(), id)
        if not w then return false end
        local data = {}
        for k, v in pairs(w) do data[k] = v end
        local ent = call('pup-stable', 'SpawnWagon', function()
            return exports['pup-stable']:SpawnWagon(data, vector4(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, heading + 0.0), false, true)
        end)
        return ent ~= nil and ent ~= 0 and DoesEntityExist(ent)
    end
    -- server events of pup-stable: (horseId), (horseId, name), (wagonId, name); ownership checked there
    Integrations.selectFavourite = function(id)
        if not running('pup-stable') then return end
        TriggerServerEvent('pup-stable:server:newFavourite', id)
        -- its client list only refreshes on the next fetch
        call('pup-stable', 'getMyHorses', function() return exports['pup-stable']:getMyHorses(false, true) end)
    end
    Integrations.renameHorse = function(id, name)
        if not running('pup-stable') then return end
        TriggerServerEvent('pup-stable:server:renameHorse', id, name)
    end
    Integrations.renameWagon = function(id, name)
        if not running('pup-stable') then return end
        TriggerServerEvent('pup-stable:server:renameWagon', id, name)
    end
    -- pup-stable ClearStowedPelts(horse) clears the slots and its own record; returns the count.
    -- Returns true when pup-stable handled it; false = we clear the slots ourselves.
    Integrations.clearHorsePelts = function(horse)
        if not running('pup-stable') then return false end
        local n = call('pup-stable', 'ClearStowedPelts', function() return exports['pup-stable']:ClearStowedPelts(horse) end)
        return type(n) == 'number'
    end

    -- lockpick resource: export lockpick() blocks until the NUI answers and returns a bool.
    -- Returns nil when it is not running so pup-minigames is used.
    Integrations.lockpick = function(done)
        if not running('lockpick') then return nil end
        CreateThread(function()
            local ok, res = pcall(function() return exports['lockpick']:lockpick() end)
            if not ok then warnOnce('lockpick', 'lockpick export lockpick() failed: ' .. tostring(res)) end
            done(ok and res == true)
        end)
        return true
    end

    -- poker has no API to register a camp table, so a camp poker set is decoration only
    Integrations.pokerTable = function(campId, coords, heading)
        if not running('poker') then return end
        warnOnce('poker', ('camp %s has a poker set, but the poker resource has no API to register a camp table; the set is decoration only'):format(tostring(campId)))
        return false
    end

    -- fred_metabolism fred_meta:consume(hunger, thirst, metabolism, innerStamina,
    -- innerStaminaGold, outerStaminaGold, innerHealth, innerHealthGold, outerHealthGold)
    Integrations.consume = function(hunger, thirst, metabolism, cores)
        if not running('fred_metabolism') then return end
        TriggerEvent('fred_meta:consume', hunger, thirst, metabolism, cores, cores, cores, cores, cores, cores)
    end

    -- vorp_lib drag gizmo: StartGizmo(handle, alpha, placeOnGround, deleteOnStop, createCam, data)
    -- blocks until done and returns { handle, position, rotation }, or nil when cancelled.
    -- Returns false when vorp_lib cannot be used (the caller falls back to pup-ui).
    Integrations.gizmo = function(ent, range)
        if not running('vorp_lib') then return false end
        local ok, res = pcall(function()
            return exports['vorp_lib']:StartGizmo(ent, 180, true, true, false, { dist = { max = range } })
        end)
        if not ok then
            warnOnce('vorp_lib', 'vorp_lib StartGizmo failed, using pup-ui placement: ' .. tostring(res))
            return false
        end
        return res
    end
end
