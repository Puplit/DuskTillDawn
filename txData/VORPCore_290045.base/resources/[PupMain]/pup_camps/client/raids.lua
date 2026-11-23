-- pup_camps | raids on the client: crew countdown, lockpick window, defender alerts

Raid = {}

local R = Config.Raids
local mine = nil      -- { campId, phase = 'prep'|'lock', coords, timer }
local alerts = {}     -- [campId] = { blip, expires }
local picking = false

function Raid.waiting(campId)
    return mine ~= nil and mine.campId == campId and mine.phase == 'prep'
end

function Raid.canPick(campId)
    return mine ~= nil and mine.campId == campId and mine.phase == 'lock'
end

function Raid.ownCampUnderRaid()
    return State.myCamp ~= 0 and alerts[State.myCamp] ~= nil
end

local function stopTimer()
    if mine and mine.timer then pcall(function() exports.vorp_core:TimerStop() end) end
    if mine then mine.timer = false end
end

local function leave()
    stopTimer()
    mine = nil
end

local function setTimer(left)
    if not mine then return end
    if not mine.timer then
        mine.timer = exports.vorp_core:TimerStart(left, R.lowSeconds) == true
    else
        exports.vorp_core:TimerUpdate(left, R.lowSeconds)
    end
end

local function watch(m)
    CreateThread(function()
        while mine == m do
            Wait(1000)
            if mine ~= m then break end
            local out = IsDeadOrDying()
            if not out and m.coords and U.dist3(PedPos(), m.coords) > R.leaveDistance then out = true end
            if out then
                Notify(L('raid_failed'))
                leave()
                Request('raidOut', m.campId)
                break
            end
        end
    end)
end

RegisterNetEvent('pup_camps:cl:raid', function(campId, phase, left, coords)
    if mine and mine.campId ~= campId then leave() end
    if not mine then
        mine = { campId = campId, phase = phase, coords = coords, timer = false }
        watch(mine)
    end
    mine.phase = phase
    mine.coords = coords or mine.coords
    setTimer(left)
    if phase == 'lock' then Notify(L('wait_over', R.lockpickMinutes), 8000) end
end)

RegisterNetEvent('pup_camps:cl:raidTick', function(campId, phase, left)
    if not mine or mine.campId ~= campId then return end
    if phase == 'lock' and mine.phase == 'prep' then
        mine.phase = 'lock'
        Notify(L('wait_over', R.lockpickMinutes), 8000)
    end
    setTimer(left)
end)

RegisterNetEvent('pup_camps:cl:raidEnd', function(campId)
    if mine and mine.campId == campId then leave() end
end)

------------------------------------------------------------------------------ lockpick

local function minigame()
    local p = promise.new()
    local settled = false
    local function settle(v)
        if settled then return end
        settled = true
        p:resolve(v == true)
    end
    local handled = false
    local ok = pcall(function()
        handled = Integrations.lockpick(settle) == true
    end)
    if not ok or not handled then
        if GetResourceState('pup-minigames') ~= 'started' then return false end
        local difficulty = math.max(1, math.min(5, R.safeCrackDifficulty))
        exports['pup-minigames']:safe_crack({ style = 'default', difficulty = difficulty }, function(success)
            settle(success == true)
        end)
    end
    SetTimeout(R.minigameTimeoutSec * 1000, function() settle(false) end)
    return Citizen.Await(p)
end

function Raid.pick(campId)
    if picking or not Raid.canPick(campId) then return end
    picking = true
    local ok, err = pcall(function()
        if not Ask('raidPickCheck', campId) then return end
        NotifyBottom(L('lockpick_hint'), 8000)
        local ped = PlayerPedId()
        local anim = Config.Anim.lockpick
        if LoadDict(anim[1]) then TaskPlayAnim(ped, anim[1], anim[2], 4.0, -4.0, -1, 1, 0.0, false, false, false) end
        local success = minigame()
        ClearPedTasks(ped)
        if Ask('raidPick', campId, success) then Notify(L('box_unlocked')) end
    end)
    picking = false
    if not ok then print('^1[pup_camps]^7 lockpick failed: ' .. tostring(err)) end
end

------------------------------------------------------------------------------ defenders

local function clearAlert(campId)
    local a = alerts[campId]
    if not a then return end
    alerts[campId] = nil
    DropBlip(a.blip)
end

RegisterNetEvent('pup_camps:cl:raidAlert', function(campId, coords, seconds)
    if type(coords) ~= 'table' then return end
    clearAlert(campId)
    local blip = BlipCoords(R.alertSprite, coords, L('raid_alert_blip'))
    BlipModifier(blip, 'BLIP_MODIFIER_MP_COLOR_8')
    local a = { blip = blip }
    alerts[campId] = a
    SetTimeout(math.max(1, tonumber(seconds) or 0) * 1000, function()
        if alerts[campId] == a then clearAlert(campId) end
    end)
end)

RegisterNetEvent('pup_camps:cl:raidAlertClear', function(campId)
    clearAlert(campId)
end)

OnState('stop', function()
    stopTimer()
    mine = nil
    for id in pairs(alerts) do clearAlert(id) end
end)
