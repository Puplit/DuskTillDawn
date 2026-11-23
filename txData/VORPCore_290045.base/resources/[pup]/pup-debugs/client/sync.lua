-- instanced-player check, client half: a player with no networked ped on the server
-- only two complete failure signatures count, each must repeat; anything inconclusive resets

local check = nil    -- the run in progress, or nil once settled
local warning = false
local generation = 0

local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < math.huge
end

local function read(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function validCoords(c)
    return type(c) == 'table' and finite(c.x) and finite(c.y) and finite(c.z)
end

local function readCoords(ped)
    local c = read(GetEntityCoords, ped)
    if c and finite(c.x) and finite(c.y) and finite(c.z) then
        return { x = c.x, y = c.y, z = c.z }
    end
end

-- read the awkward way on purpose: GetPlayerPed(PlayerId()) fails on an instanced client
local function readSelfPed()
    if type(GetPlayerPed) ~= 'function' then return nil, 'unavailable' end
    local ok, ped = pcall(GetPlayerPed, PlayerId())
    if not ok then return nil, 'error' end
    if not finite(ped) or ped <= 0 or ped ~= math.floor(ped) then return ped, 'invalid' end
    return ped, 'ok'
end

local function failedRead(status)
    return status == 'error' or status == 'invalid'
end

local function sampleLocal()
    local ped = read(PlayerPedId)
    local selfPed, selfStatus = readSelfPed()
    local out = { selfPed = selfPed, selfStatus = selfStatus }

    if not ped or ped == 0 or read(DoesEntityExist, ped) ~= true then
        return ped or 0, 0, out
    end

    out.model = read(GetEntityModel, ped)
    out.coords = readCoords(ped)

    if read(NetworkGetEntityIsNetworked, ped) ~= true then return ped, 0, out end
    local netId = read(NetworkGetNetworkIdFromEntity, ped)
    if not finite(netId) or netId <= 0 then return ped, 0, out end
    return ped, netId, out
end

local function resetEvidence()
    if not check then return end
    check.good, check.bad, check.lastIdentity = 0, 0, nil
end

RegisterNetEvent('pup-debugs:syncReply', function(gen, sequence, charId, serverNetId, serverSample)
    local c = check
    local pending = c and c.pending
    if not pending or c.generation ~= gen or pending.sequence ~= sequence or c.charId ~= charId then return end
    c.pending = nil

    local ped, netId, mine = sampleLocal()

    -- the world moved while we waited, so this answer describes something else
    if GetGameTimer() - pending.sentAt > (Config.SyncCheck.timeoutSeconds or 10) * 1000
        or ped ~= pending.ped or netId ~= pending.netId
        or mine.model ~= pending.sample.model
        or mine.selfPed ~= pending.sample.selfPed
        or mine.selfStatus ~= pending.sample.selfStatus then
        resetEvidence()
        warning = false
        return
    end

    if type(serverSample) ~= 'table' or serverSample.version ~= 1
        or not finite(serverNetId) or serverNetId < 0 then
        resetEvidence()
        warning = false
        return
    end

    -- the same fault twice in a row only counts if it is the same fault
    local identity <const> = table.concat({
        tostring(ped), tostring(netId), tostring(serverNetId),
        tostring(serverSample.model), tostring(mine.selfPed),
        tostring(mine.selfStatus), tostring(serverSample.coordsStatus),
        tostring(serverSample.pedStatus),
    }, ':')
    if c.lastIdentity ~= identity then
        resetEvidence()
        warning = false
    end
    c.lastIdentity = identity

    local clientCoordsWork <const> = validCoords(mine.coords) and validCoords(pending.sample.coords)
    local clientPedFails   <const> = failedRead(mine.selfStatus) and failedRead(pending.sample.selfStatus)
    local serverPedWorks   <const> = serverSample.pedExists == true
    local serverCoordsFail <const> = failedRead(serverSample.coordsStatus) and serverSample.coords == nil

    -- 1. the natives disagree about who exists
    local asymmetry <const> = clientCoordsWork and clientPedFails and serverPedWorks and serverCoordsFail
    -- 2. we have a networked ped, the server has nothing
    local noServerPed <const> = clientCoordsWork and mine.selfStatus == 'ok' and mine.selfPed == ped
        and netId > 0 and serverNetId == 0 and serverSample.pedExists == false
        and serverSample.pedStatus == 'missing' and serverSample.coordsStatus == 'not_checked'

    local healthy <const> = clientCoordsWork and mine.selfStatus == 'ok' and mine.selfPed == ped
        and serverPedWorks and serverSample.coordsStatus == 'ok' and validCoords(serverSample.coords)

    if healthy then
        warning = false
        c.bad = 0
        c.good = c.good + 1
        if c.good >= (Config.SyncCheck.clearSamples or 3) then check = nil end

    elseif asymmetry or noServerPed then
        c.good = 0
        c.bad = c.bad + 1
        if c.bad >= (Config.SyncCheck.strikes or 3) and not warning then
            warning = true
            -- one line, once: this is a real fault worth a record
            print(('^1[pup-debugs]^7 instanced: char=%s clientNet=%s serverNet=%s serverPed=%s (%s)')
                :format(tostring(c.charId), tostring(netId), tostring(serverNetId),
                    tostring(serverSample.pedStatus), noServerPed and 'no server ped' or 'native asymmetry'))
            TriggerServerEvent('pup-debugs:syncFailed', c.charId, netId, serverNetId,
                noServerPed and 'no server ped' or 'native asymmetry')
        end

    else
        -- neither a clean pass nor a complete failure: prove nothing
        resetEvidence()
        warning = false
    end
end)

RegisterNetEvent('vorp:SelectedCharacter', function(charId)
    if Config.SyncCheck.enabled == false then return end
    charId = tonumber(charId)
    if not charId or charId < 1 then return end

    generation = generation + 1
    local c = { generation = generation, charId = charId, sequence = 0, good = 0, bad = 0 }
    check = c
    warning = false

    CreateThread(function()
        Wait((Config.SyncCheck.graceSeconds or 45) * 1000)
        while check == c and (c.sequence < (Config.SyncCheck.maxProbes or 36) or warning) do
            local timeout <const> = (Config.SyncCheck.timeoutSeconds or 10) * 1000
            if c.pending and GetGameTimer() - c.pending.sentAt >= timeout then
                c.pending = nil
                resetEvidence()
                warning = false
            end
            if not c.pending then
                local ped, netId, mine = sampleLocal()
                c.sequence = c.sequence + 1
                c.pending = { sequence = c.sequence, ped = ped, netId = netId, sample = mine, sentAt = GetGameTimer() }
                TriggerServerEvent('pup-debugs:syncProbe', c.generation, c.sequence, c.charId)
            end
            Wait((Config.SyncCheck.intervalSeconds or 5) * 1000)
        end
        if check == c then check = nil end
    end)
end)

CreateThread(function()
    while true do
        if warning then
            local text <const> = CreateVarString(10, 'LITERAL_STRING', Locale.instancedWarning or 'YOU ARE INSTANCED')
            local col <const> = Config.SyncCheck.color or { 255, 40, 40 }
            SetTextScale(0.45, 0.45)
            SetTextColor(col[1], col[2], col[3], 255)
            SetTextCentre(true)
            SetTextDropshadow(1, 0, 0, 0, 255)
            Citizen.InvokeNative(0xADA9255D, 1) -- SetTextFontForCurrentCommand
            DisplayText(text, Config.SyncCheck.x or 0.5, Config.SyncCheck.y or 0.18)
            Wait(0)
        else
            Wait(500)
        end
    end
end)
