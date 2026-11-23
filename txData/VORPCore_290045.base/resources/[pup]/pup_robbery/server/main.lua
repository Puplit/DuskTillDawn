-- pup_robbery | server wiring: usable tools, admin and test commands, character switch, shutdown

local RES = GetCurrentResourceName()

--------------------------------------------------------------------------------
-- usable heist tools

CreateThread(function()
    Wait(1000)
    for _, item in ipairs(Config.UsableTools) do
        local name = item
        local ok, err = pcall(function()
            exports.vorp_inventory:registerUsableItem(name, function(data)
                local src = tonumber(data and data.source)
                if not src or not S.rate(src, 'useTool', 750) then return end
                Heist.useItem(src, name)
            end, RES)
        end)
        if not ok then S.warn('could not register usable item %s: %s', name, tostring(err)) end
    end
end)

--------------------------------------------------------------------------------
-- small callbacks

S.callback('pup_robbery:isAdmin', function(src)
    return S.isAdmin(src)
end)

-- /testenemy needs debug mode and an admin
S.callback('pup_robbery:canTestEnemy', function(src)
    return Config.Debug == true and S.isAdmin(src)
end)

--------------------------------------------------------------------------------
-- command helpers

local function reply(src, text)
    if src == 0 then print('[pup_robbery] ' .. text) else S.tip(src, text, 8000) end
end

local function adminOnly(src)
    if src == 0 or S.isAdmin(src) then return true end
    reply(src, L('noPermission'))
    return false
end

local function testOnly(src)
    if not adminOnly(src) then return false end
    if not Config.TestMode.enabled then
        reply(src, L('testOff'))
        return false
    end
    return true
end

local function bankArg(src, key)
    if key and Config.Banks[key] then return key end
    if not key and src > 0 then
        local mine = Heist.crewBank(src)
        if mine then return mine end
    end
    if not key then
        local only = nil
        for _, id in ipairs(Config.BankOrder) do
            if Heist.run(id) then
                if only then return nil end
                only = id
            end
        end
        return only
    end
    return nil
end

--------------------------------------------------------------------------------
-- walk-up

RegisterCommand('resetrobbery', function(source, args)
    local src = tonumber(source) or 0
    if not adminOnly(src) then return end
    local name = #args > 0 and table.concat(args, ' ') or nil
    reply(src, L('resetPlaces', Walkup.resetPlaces(name)))
end, false)

--------------------------------------------------------------------------------
-- fence

RegisterCommand('fencemove', function(source)
    local src = tonumber(source) or 0
    if not adminOnly(src) then return end
    local s = Fence.move()
    reply(src, L('fenceMoved', s.label, s.region, U.round(Fence.rateNow() * 100)))
end, false)

RegisterNetEvent('pup_robbery:fence:face', function(heading)
    local src = source
    if not S.rate(src, 'fenceFace', 1000) then return end
    if not S.isAdmin(src) then return S.tip(src, L('noPermission')) end
    Fence.face(src, heading)
end)

RegisterCommand('fencejob', function(source, args)
    local src = tonumber(source) or 0
    if src == 0 then return print('[pup_robbery] /fencejob is for in-game admins') end
    if not adminOnly(src) then return end
    local key = args[1]
    if not key then
        local lines = {}
        for _, id in ipairs(Config.BankOrder) do
            local b = Config.Banks[id]
            local st = Heist.run(id) and 'running' or (Heist.bankLeft(id) > 0 and ('cooldown ' .. U.hm(Heist.bankLeft(id))) or 'ready')
            lines[#lines + 1] = ('heist:%s (%d riders, %s)'):format(id, b.riders or 1, st)
        end
        return reply(src, table.concat(lines, ' | '))
    end
    Fence.adminJob(src, key)
end, false)

--------------------------------------------------------------------------------
-- heist test tools

RegisterCommand('heists', function(source)
    local src = tonumber(source) or 0
    if not testOnly(src) then return end
    for _, id in ipairs(Config.BankOrder) do
        local b = Config.Banks[id]
        print(('[pup_robbery] %-10s %-18s riders %d  lawmen %d  cooldown %-8s  running %s'):format(
            id, b.label, b.riders or 1, b.lawmen or 0, Heist.bankLeft(id) > 0 and U.hm(Heist.bankLeft(id)) or 'no', Heist.run(id) and 'yes' or 'no'))
    end
end, false)

RegisterCommand('heiststart', function(source, args)
    local src = tonumber(source) or 0
    if src == 0 then return print('[pup_robbery] /heiststart is for in-game admins') end
    if not testOnly(src) then return end
    local key = args[1]
    if not key or not Config.Banks[key] then return reply(src, L('unknownKey', tostring(key))) end
    Heist.resetBank(key)
    Fence.adminJob(src, 'heist:' .. key, true)
end, false)

RegisterCommand('heistreset', function(source, args)
    local src = tonumber(source) or 0
    if not testOnly(src) then return end
    local key = args[1]
    if key then
        if not Config.Banks[key] then return reply(src, L('unknownKey', key)) end
        local n = Heist.bankLeft(key) > 0 and 1 or 0
        Heist.resetBank(key)
        return reply(src, L('heistReset', n, ''))
    end
    reply(src, L('heistReset', Heist.resetAll(), L('heistResetRiders')))
end, false)

RegisterCommand('heistcancel', function(source, args)
    local src = tonumber(source) or 0
    if not testOnly(src) then return end
    local key = args[1]
    if not key or not Config.Banks[key] then return reply(src, L('unknownKey', tostring(key))) end
    if not Heist.cancel(key) then reply(src, L('noRun', key)) end
end, false)

RegisterCommand('heistalarm', function(source, args)
    local src = tonumber(source) or 0
    if not testOnly(src) then return end
    local level = math.floor(tonumber(args[1]) or 0)
    if level < 1 or level > Config.Heist.alarmMax then return reply(src, 'Usage: /heistalarm 1-4 [bank]') end
    local key = bankArg(src, args[2])
    if not key or not Heist.adminAlarm(key, level) then return reply(src, L('noRun', tostring(args[2] or '?'))) end
    reply(src, L('alarmRaised', key, Heist.run(key) and Heist.run(key).alarm or level))
end, false)

RegisterCommand('vaultcode', function(source, args)
    local src = tonumber(source) or 0
    if not testOnly(src) then return end
    local key = bankArg(src, args[1])
    local code, mask = Heist.code(key or '')
    if not code then return reply(src, L('noRun', tostring(args[1] or '?'))) end
    reply(src, ('%s vault code %s, note %s'):format(key, code, mask or 'not found'))
end, false)

--------------------------------------------------------------------------------
-- character switch: the old character's seat on a job goes (the clocks follow the character)

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    if Walkup.jobOf(src) then
        TriggerClientEvent('pup_robbery:walkup:forceEnd', src)
        Walkup.leave(src, false)
    end
    local bankId = Heist.crewBank(src)
    local run = bankId and Heist.run(bankId)
    if run then Heist.dropMember(run, src, 'left') end
end)

AddEventHandler('playerDropped', function()
    S.forget(source)
end)

--------------------------------------------------------------------------------
-- shutdown: runs are released with no cooldown and no history row

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    pcall(Heist.shutdown)
    pcall(Walkup.shutdown)
    pcall(Police.clearAll)
    for _, item in ipairs(Config.UsableTools) do
        pcall(function() exports.vorp_inventory:unRegisterUsableItem(item) end)
    end
end)
