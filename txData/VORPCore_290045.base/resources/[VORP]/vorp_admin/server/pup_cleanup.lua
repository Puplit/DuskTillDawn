-- Modified by Puppet (Dusk Till Dawn), 2026
-- CLEANUP SWEEP. The spawn guard cancels a flood before the entities exist, which is
-- always better. This is the other half: clearing what is already on the ground when
-- something got through, or when the guard was off.

local C = (Config.SpawnGuard or {}).cleanup or {}

local TYPE_PED <const>, TYPE_VEHICLE <const>, TYPE_OBJECT <const> = 1, 2, 3

local function allowed(src)
    if src == 0 then return true end -- server console
    if not HasPermission then return false end
    return HasPermission(src, C.permission or 'admin_actions_menu') == true
end

local function say(src, msg)
    print('^3[cleanup]^7 ' .. msg)
    if src and src > 0 then TriggerClientEvent('vorp:TipRight', src, msg, 7000) end
end

local function discord(title, body)
    if not Secrets.Webhooks.spawnGuard or Secrets.Webhooks.spawnGuard == '' then return end
    PerformHttpRequest(Secrets.Webhooks.spawnGuard, function() end, 'POST', json.encode({
        embeds = { {
            title = title,
            description = body,
            color = 15105570,
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

-- the two spellings differ between builds; take whichever this server has
local function netIdOf(entity)
    if type(NetworkGetNetworkIdFromEntity) == 'function' then return NetworkGetNetworkIdFromEntity(entity) end
    if type(GetNetworkIdFromEntity) == 'function' then return GetNetworkIdFromEntity(entity) end
    return nil
end

-- "all", or any of objects / peds / vehicles. Objects alone by default: that is the
-- crash vector, and the other two are where the horses and wagons live.
local function parseKinds(arg)
    local k = { object = false, ped = false, vehicle = false }
    local a = tostring(arg or ''):lower()
    if a == '' then
        k.object = true
    elseif a == 'all' then
        k.object, k.ped, k.vehicle = true, true, true
    else
        if a:find('obj') then k.object = true end
        if a:find('ped') then k.ped = true end
        if a:find('veh') then k.vehicle = true end
        if not (k.object or k.ped or k.vehicle) then k.object = true end
    end
    return k
end

local function playerPedSet()
    local set = {}
    for _, pid in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 then set[ped] = true end
    end
    return set
end

local function protectedEntity(entity, peds)
    if peds[entity] then return true end
    local keys = C.protectStateKeys
    if type(keys) ~= 'table' or #keys == 0 then return false end
    local ok, st = pcall(function() return Entity(entity).state end)
    if not ok or not st then return false end
    for _, key in ipairs(keys) do
        if st[key] ~= nil then return true end
    end
    return false
end

local function gather(kinds)
    local out, missing = {}, {}
    local function add(fn, name, want)
        if not want then return end
        if type(fn) ~= 'function' then missing[#missing + 1] = name return end
        for _, e in pairs(fn()) do out[#out + 1] = e end
    end
    add(GetAllObjects, 'GetAllObjects', kinds.object)
    add(GetAllPeds, 'GetAllPeds', kinds.ped)
    add(GetAllVehicles, 'GetAllVehicles', kinds.vehicle)
    return out, missing
end

-- DeleteEntity first. When the server cannot remove one, the client that owns it is
-- asked to take control and delete it there, which is the only route for the rest.
local function removeEntity(entity)
    if not DoesEntityExist(entity) then return 'gone' end
    local netId = netIdOf(entity)
    local owner = NetworkGetEntityOwner(entity)
    local isVehicle = GetEntityType(entity) == TYPE_VEHICLE

    DeleteEntity(entity)
    if not DoesEntityExist(entity) then return 'deleted' end

    if owner and owner > 0 and netId and netId > 0 then
        TriggerClientEvent('vorp_admin:cleanup:deleteNetId', owner, netId, isVehicle)
        return 'asked'
    end
    return 'failed'
end

--- @param filter function(entity) -> boolean
local function sweep(src, kinds, filter, label)
    local list, missing = gather(kinds)
    if #missing > 0 then
        say(src, ('this build has no %s - that kind cannot be swept'):format(table.concat(missing, ', ')))
    end
    if #list == 0 then return say(src, 'nothing to sweep') end

    local peds = playerPedSet()
    local deleted, asked, failed, kept, looked = 0, 0, 0, 0, 0

    for _, e in ipairs(list) do
        if DoesEntityExist(e) then
            looked = looked + 1
            if protectedEntity(e, peds) then
                kept = kept + 1
            elseif filter(e) then
                local r = removeEntity(e)
                if r == 'deleted' or r == 'gone' then deleted = deleted + 1
                elseif r == 'asked' then asked = asked + 1
                else failed = failed + 1 end
            end
            -- a flood can be thousands of entities; yield so the tick does not stall
            if looked % 200 == 0 then Wait(0) end
        end
    end

    local report = ('%s - %d deleted, %d handed to the owner, %d could not be removed, %d protected (%d checked)')
        :format(label, deleted, asked, failed, kept, looked)
    say(src, report)
    discord('Cleanup sweep', ('**%s** ran a sweep: %s'):format(
        src > 0 and (GetPlayerName(src) or src) or 'console', report))
end

RegisterCommand('cleanarea', function(src, args)
    src = tonumber(src) or 0
    if not allowed(src) then return end

    local radius = math.min(tonumber(args[1]) or (tonumber(C.defaultRadius) or 60.0),
        tonumber(C.maxRadius) or 500.0)
    local kinds = parseKinds(args[2])

    local centre
    if src > 0 then
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        centre = GetEntityCoords(ped)
    else
        return say(0, 'run /cleanarea in game, or use /cleanowner <id> from the console')
    end

    CreateThread(function()
        sweep(src, kinds, function(e)
            return #(GetEntityCoords(e) - centre) <= radius
        end, ('%.0fm sweep'):format(radius))
    end)
end, false)

-- The surgical one. Everything a single player currently owns, map wide, which is what
-- you want pointed at a cheater rather than a radius over a populated town.
RegisterCommand('cleanowner', function(src, args)
    src = tonumber(src) or 0
    if not allowed(src) then return end

    local target = tonumber(args[1])
    if not target or target <= 0 then
        return say(src, 'usage: /cleanowner <playerId> [objects|peds|vehicles|all]')
    end
    local kinds = parseKinds(args[2])

    CreateThread(function()
        sweep(src, kinds, function(e)
            return NetworkGetEntityOwner(e) == target
        end, ('sweep of everything owned by %s [%d]'):format(GetPlayerName(target) or '?', target))
    end)
end, false)

CreateThread(function()
    Wait(3000)
    local have = {}
    for name, fn in pairs({ GetAllObjects = GetAllObjects, GetAllPeds = GetAllPeds, GetAllVehicles = GetAllVehicles }) do
        if type(fn) == 'function' then have[#have + 1] = name end
    end
    table.sort(have)
    print(('^3[cleanup]^7 /cleanarea and /cleanowner ready - %s'):format(
        #have > 0 and table.concat(have, ', ') or 'NO collector natives on this build'))
end)
