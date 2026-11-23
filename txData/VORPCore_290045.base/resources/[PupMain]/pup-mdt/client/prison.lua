-- pup-mdt client | serving a sentence: arrival, countdown display, roam limit, disarm, labour, release.
-- The server owns the clock: this side only shows the time and asks for things.

MdtC = MdtC or {}

local P = Config.Prison
local serving = nil -- { recordId, remaining, centre = vector3, radius, exit, used = {}, max, graceUntil }

local function inmateNotify(key, ms, ...)
    MdtC.notify(L(key, ...), ms)
end

local function setDisplay(seconds)
    if serving then serving.remaining = math.max(0, math.floor(tonumber(seconds) or 0)) end
    MdtC.send({ action = 'updateJailTime', jailTime = math.max(0, math.floor(tonumber(seconds) or 0)) })
end

local function centreOf(d)
    local x, y, z = MdtC.xyzh(d.centre)
    if x then return vector3(x, y, z) end
    return vector3(P.centre.x, P.centre.y, P.centre.z)
end

---------------------------------------------------------------------------
-- start / resume
---------------------------------------------------------------------------
RegisterNetEvent('pup-mdt:client:jailStart', function(d)
    if type(d) ~= 'table' then return end
    if serving and serving.recordId == d.recordId then return end
    local used = {}
    for _, i in ipairs(d.labourUsed or {}) do used[tonumber(i)] = true end
    serving = {
        recordId = d.recordId,
        remaining = math.floor(tonumber(d.seconds) or 0),
        centre = centreOf(d),
        radius = tonumber(d.radius) or P.radius or 150.0,
        exit = d.exit or P.exit,
        used = used,
        max = tonumber(d.labourMax) or (P.labour and P.labour.maxUses) or 3,
        graceUntil = GetGameTimer() + 5000,
    }
    if MdtC.mdtOpen then MdtC.closeMdt(true) end
    if d.arrival and P.autoJail ~= false then
        MdtC.teleport(d.arrival, { fade = 800, tries = 10, gap = 100, above = 5.0, lift = d.resume and 1.0 or 0.5, pause = 300 })
        serving.graceUntil = GetGameTimer() + 5000
    end
    local s = serving.remaining
    if d.resume then
        inmateNotify('ps_still_serving', 8000, math.floor(s / 60), s % 60)
    else
        inmateNotify('ps_sentenced', 8000, tonumber(d.sentenceMinutes) or math.ceil(s / 60))
    end
    setDisplay(s)
    MdtC.startServing()
end)

RegisterNetEvent('pup-mdt:client:jailTime', function(seconds, reasonKey, minutes)
    if not serving then return end
    setDisplay(seconds)
    if reasonKey == 'extended' then inmateNotify('ps_extended', 6000, tonumber(minutes) or 0)
    elseif reasonKey == 'appeal' then inmateNotify('ps_appeal_reduced', 6000, tonumber(minutes) or 0) end
end)

---------------------------------------------------------------------------
-- release
---------------------------------------------------------------------------
-- offline == true: released while away, delivered on the next jailCheck; act wherever the ped is
-- (a station cell is far from the main prison)
RegisterNetEvent('pup-mdt:client:jailRelease', function(kind, exit, offline)
    if not serving then
        -- the server only sends this to its own prisoner; when this side lost track
        -- (resource restart, missed start) still clear the timer and walk out if inside
        MdtC.send({ action = 'clearJailTime' })
        if offline ~= true then
            local c = GetEntityCoords(PlayerPedId())
            if #(c - vector3(P.centre.x, P.centre.y, P.centre.z)) > (P.radius or 150.0) + 50.0 then return end
        end
    end
    serving = nil
    MdtC.send({ action = 'clearJailTime' })
    TriggerEvent('vorp_inventory:pup:restoreBeltToPed')
    local ped = PlayerPedId()
    if kind == 'forced' then
        TriggerEvent('pup_worldint:clear')
        ClearPedTasks(ped)
        MdtC.teleport(exit or P.exit, { fade = 800, wait = 1000, lift = 0.5 })
        inmateNotify('ps_freedom', 5000)
    else
        inmateNotify('ps_served', 7000)
        MdtC.teleport(exit or P.exit, { fade = 800, wait = 1000, lift = 0.5 })
        ClearPedTasks(ped)
        inmateNotify('ps_released', 5000)
    end
end)

-- the server saw us too far out
RegisterNetEvent('pup-mdt:client:jailReturn', function(point)
    if not serving then return end
    MdtC.teleport(point, { fade = 500, tries = 10, gap = 50, lift = 0.5 })
    serving.graceUntil = GetGameTimer() + 5000
    inmateNotify('ps_escape', 5000)
end)

-- a lawman moved us to a cell or a station. The roam limit follows a move outside the
-- current area: optional centre/radius from the server, else a matching Config station, else the point.
RegisterNetEvent('pup-mdt:client:jailToCell', function(point, centre, radius)
    if serving then serving.graceUntil = GetGameTimer() + 60000 end
    MdtC.teleport(point, { fade = 600, tries = 10, gap = 100, above = 10.0, lift = 1.0 })
    if not serving then return end
    local px, py, pz = MdtC.xyzh(point)
    local cx, cy, cz = MdtC.xyzh(centre)
    if cx then
        serving.centre = vector3(cx, cy, cz)
        serving.radius = tonumber(radius) or serving.radius
    elseif px and #(vector3(px, py, pz) - serving.centre) > serving.radius then
        local r = 25.0
        for _, st in ipairs(P.stations or {}) do
            local sx, sy, sz = MdtC.xyzh(st.coords)
            if sx and #(vector3(sx, sy, sz) - vector3(px, py, pz)) < 3.0 then r = tonumber(st.radius) or r break end
        end
        serving.centre = vector3(px, py, pz)
        serving.radius = r
    end
    serving.graceUntil = GetGameTimer() + 5000
end)

-- a new character starts clean; the server answers jailCheck if this one is serving
RegisterNetEvent('vorp:SelectedCharacter', function()
    if not serving then return end
    serving = nil
    MdtC.send({ action = 'clearJailTime' })
end)

---------------------------------------------------------------------------
-- loops while serving
---------------------------------------------------------------------------
local loopsRunning = false

function MdtC.startServing()
    if loopsRunning then return end
    loopsRunning = true
    -- one-second tick: local countdown for display decisions and the roam limit
    CreateThread(function()
        while serving do
            Wait(1000)
            if not serving then break end
            if serving.remaining > 0 then serving.remaining = serving.remaining - 1 end
            if GetGameTimer() > serving.graceUntil then
                local c = GetEntityCoords(PlayerPedId())
                if #(c - serving.centre) > serving.radius then
                    local ctr = serving.centre
                    MdtC.teleport({ x = ctr.x, y = ctr.y, z = ctr.z }, { fade = 500, tries = 10, gap = 50, lift = 0.5 })
                    serving.graceUntil = GetGameTimer() + 5000
                    inmateNotify('ps_escape', 5000)
                end
            end
        end
        loopsRunning = false
    end)
    -- every frame: no fighting
    CreateThread(function()
        local unarmed = joaat('WEAPON_UNARMED')
        local nextCheck, nextAmmo = 0, 0
        while serving do
            Wait(0)
            local ped = PlayerPedId()
            for _, c in ipairs(P.attackControls or {}) do DisableControlAction(0, c, true) end
            if P.disarm ~= false then
                local now = GetGameTimer()
                if now >= nextCheck then
                    nextCheck = now + 250
                    local _, cur = GetCurrentPedWeapon(ped, true, 0, false)
                    if cur and cur ~= unarmed then
                        SetCurrentPedWeapon(ped, unarmed, true, 0, false, false)
                        Citizen.InvokeNative(0xF25DF915FA38C5F3, ped, true, true) -- remove the ped's weapons; the inventory keeps them
                    end
                end
                if now >= nextAmmo then
                    nextAmmo = now + 2000
                    TriggerEvent('vorp_inventory:pup:holdAmmoReconcile', 3000)
                end
            end
        end
    end)
end

---------------------------------------------------------------------------
-- reconnect: ask whether a sentence is still running
---------------------------------------------------------------------------
local function askJail(delay)
    SetTimeout(delay, function()
        if not serving then TriggerServerEvent('pup-mdt:server:jailCheck') end
    end)
end

AddEventHandler('playerSpawned', function() askJail(2000) end)
RegisterNetEvent('vorp:SelectedCharacter', function() askJail(3000) end)
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    askJail(3000)
    askJail(15000)
end)

---------------------------------------------------------------------------
-- prison labour (wood chopping)
---------------------------------------------------------------------------
local L_CFG = P.labour or {}
local stumps = {}
local working = nil -- { spot, token, startedAt, began }
local lastPress = 0

local CLEAR_NEAR = { 'p_log01x', 'p_log02x', 'p_log03x', 'p_logpile01x', 'p_logpile02x', 'p_stump01x', 'p_stump02x', 'p_woodplank01x', 'p_woodplank02x' }

local function clearAround(pos, models, radius)
    for _, m in ipairs(models) do
        local h = joaat(m)
        for _ = 1, 4 do
            local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, radius, h, false, false, false)
            if obj == 0 or not DoesEntityExist(obj) then break end
            if not IsEntityAMissionEntity(obj) then SetEntityAsMissionEntity(obj, true, true) end
            DeleteObject(obj)
        end
    end
end

local function spawnStump(i)
    local spot = L_CFG.spots[i]
    if not spot then return end
    if stumps[i] and DoesEntityExist(stumps[i]) then return end
    local hash = MdtC.loadModel(L_CFG.stumpModel or 'p_stumpwoodsplit02x', 10000)
    if not hash then return end
    local obj = CreateObject(hash, spot.x, spot.y, spot.z - 1.0, false, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(hash)
    stumps[i] = obj
end

local function deleteStump(i)
    if stumps[i] and DoesEntityExist(stumps[i]) then DeleteObject(stumps[i]) end
    stumps[i] = nil
end

local SCENARIOS = {}
for _, s in ipairs(L_CFG.scenarios or {}) do SCENARIOS[joaat(s)] = true end

local function usingScenario(ped)
    return Citizen.InvokeNative(0x57AB4A3080F85143, ped, Citizen.ResultAsInteger()) ~= 0
end

-- first chop scenario point within the configured radius
local function chopPoint(pos)
    local max = 10
    local buffer = string.rep('\0', 8 * (max + 1) + 8)
    local count = Citizen.InvokeNative(0x345EC3B7EBDE1CB5, pos.x, pos.y, pos.z, (L_CFG.scenarioRadius or 2.0) + 0.0, buffer, max, Citizen.ResultAsInteger())
    count = math.min(tonumber(count) or 0, max)
    for i = 1, count do
        local point = string.unpack('<i4', buffer, 8 * i + 1)
        if point and point ~= 0 then
            local kind = Citizen.InvokeNative(0xA92450B5AE687AAF, point, Citizen.ResultAsInteger())
            if SCENARIOS[kind] then return point end
        end
    end
    return nil
end

RegisterNetEvent('pup-mdt:client:labourGo', function(spot, token)
    if not serving or working then
        TriggerServerEvent('pup-mdt:server:labourAbort', token)
        return
    end
    local ped = PlayerPedId()
    local point = chopPoint(GetEntityCoords(ped))
    if not point then
        inmateNotify('ps_chop_no_point', 4000)
        TriggerServerEvent('pup-mdt:server:labourAbort', token)
        return
    end
    working = { spot = spot, token = token, startedAt = GetGameTimer(), began = false }
    Citizen.InvokeNative(0xCCDAE6324B6A821C, ped, point, '', -1.0, true, false, 0, false, -1.0, true) -- TASK_USE_SCENARIO_POINT
    CreateThread(function()
        local w = working
        -- the scenario must actually start
        local deadline = GetGameTimer() + 4000
        while working == w and not usingScenario(PlayerPedId()) do
            if GetGameTimer() > deadline then
                working = nil
                TriggerServerEvent('pup-mdt:server:labourAbort', w.token)
                return
            end
            Wait(100)
        end
        w.began = true
        -- reward only when the ped finishes the scenario
        local maxMs = ((L_CFG.maxScenarioSeconds or 180) - 2) * 1000
        while working == w and usingScenario(PlayerPedId()) do
            if GetGameTimer() - w.startedAt > maxMs then break end
            Wait(250)
        end
        if working ~= w then return end
        working = nil
        if not serving then return end
        TriggerServerEvent('pup-mdt:server:labourDone', w.token)
    end)
end)

RegisterNetEvent('pup-mdt:client:labourResult', function(r)
    if type(r) ~= 'table' or not serving then return end
    local spot = tonumber(r.spotIndex)
    if spot then serving.used[spot] = true end
    setDisplay(r.seconds)
    if (tonumber(r.reducedMinutes) or 0) > 0 then
        local left = math.floor((tonumber(r.seconds) or 0) / 60)
        inmateNotify('ps_chop_reduced', 8000, r.reducedMinutes, r.used, r.max, left)
    end
    if r.atLimit then inmateNotify('ps_chop_limit', 6000) end
    if r.atFloor then inmateNotify('ps_chop_floor_reached', 6000) end
    if spot then
        SetTimeout(10000, function()
            deleteStump(spot)
            SetTimeout(2000, function() spawnStump(spot) end)
        end)
    end
end)

-- the prompt near the next free spot
CreateThread(function()
    if L_CFG.enabled == false or not L_CFG.spots then return end
    while true do
        local sleep = 500
        if serving and not working then
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            local nearest, nd = nil, (L_CFG.promptDistance or 1.8)
            for i, s in ipairs(L_CFG.spots) do
                local d = #(c - vector3(s.x, s.y, s.z))
                if d <= nd then nearest, nd = i, d end
            end
            if nearest and not usingScenario(ped) then
                sleep = 0
                local usedCount = 0
                for _ in pairs(serving.used) do usedCount = usedCount + 1 end
                local floor = (L_CFG.floorMinutes or 15) * 60
                local label, canChop
                if usedCount >= serving.max then label = L('ps_chop_limit')
                elseif serving.used[nearest] or nearest ~= usedCount + 1 then label = L('ps_chop_used')
                elseif serving.remaining <= floor then label = L('ps_chop_floor')
                else label, canChop = L('ps_chop_prompt'), true end
                MdtC.prompt(label)
                if canChop and IsControlJustReleased(0, Config.Keys.interact) and GetGameTimer() - lastPress > ((L_CFG.cooldownSeconds or 2) * 1000) then
                    lastPress = GetGameTimer()
                    MdtC.promptHide()
                    TriggerServerEvent('pup-mdt:server:labourStart', nearest)
                end
            end
        end
        Wait(sleep)
    end
end)

-- stumps for everyone near the yard
CreateThread(function()
    if L_CFG.enabled == false or not L_CFG.spots then return end
    Wait(1000)
    for _, s in ipairs(L_CFG.spots) do
        clearAround(s, { L_CFG.stumpModel or 'p_stumpwoodsplit02x' }, 10.0)
        clearAround(s, CLEAR_NEAR, 15.0)
    end
    Wait(1000)
    for i = 1, #L_CFG.spots do spawnStump(i) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i in pairs(stumps) do deleteStump(i) end
end)

function MdtC.isServing() return serving ~= nil end
