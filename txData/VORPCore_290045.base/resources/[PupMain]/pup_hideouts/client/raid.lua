-- pup_hideouts | raids on the client: the crew's countdown, the lock, and tearing down a still

local R <const> = Config.Raids
local T <const> = Config.Teardown

HX.Raid = {}
local run = nil -- { id, door, baseLeft, at, timer }

local function secondsLeft()
    if not run then return 0 end
    return math.max(0, math.floor(run.baseLeft - (GetGameTimer() - run.at) / 1000))
end

local function timerStart(left)
    local ok, shown = pcall(function() return exports.vorp_core:TimerStart(left, R.redAtSeconds) end)
    if run then run.timer = ok and shown ~= false end
end

local function timerStop()
    pcall(function() exports.vorp_core:TimerStop() end)
end

function HX.Raid.active() return run ~= nil end

function HX.Raid.clear()
    if run then timerStop() end
    run = nil
end

RegisterNetEvent('pup_hideouts:raidJoin', function(id, door, left)
    run = { id = tonumber(id), door = U.vec(door), baseLeft = tonumber(left) or 0, at = GetGameTimer() }
    timerStart(run.baseLeft)
    HX.tip(L('raid_begun'))
end)

RegisterNetEvent('pup_hideouts:raidClock', function(id, left)
    if not run or run.id ~= tonumber(id) then return end
    run.baseLeft, run.at = tonumber(left) or 0, GetGameTimer()
end)

RegisterNetEvent('pup_hideouts:raidEnd', function(id)
    if run and run.id == tonumber(id) then HX.Raid.clear() end
end)

-- local countdown between the server's syncs (one tick a second, no per-frame loop)
CreateThread(function()
    while true do
        Wait(1000)
        if run then
            local left = secondsLeft()
            if run.timer then
                pcall(function() exports.vorp_core:TimerUpdate(left, R.redAtSeconds) end)
            end
        end
    end
end)

----------------------------------------------------------------------------------------------------
-- the lock
----------------------------------------------------------------------------------------------------
local picking = false

local function pickLock(id)
    if picking then return end
    picking = true
    HX.busy = true
    local answered, count = HX.call('lockpickCount', 3000)
    if not answered then
        HX.tip(L('no_answer'))
    elseif (tonumber(count) or 0) < 1 then
        HX.tip(L('need_lockpick'))
    else
        local ped = PlayerPedId()
        local a = Config.Anims.picklock
        if HX.loadDict(a.dict) then TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, -1, 1, 0, false, false, false) end
        local won
        if GetResourceState('lockpick') == 'started' then
            HX.bottom(L('hint_pins'), R.crackHintMs)
            local ok, res = pcall(Config.Integrations.lockpick)
            if not ok then U.warnIntegration('lockpick', res) end
            won = ok and res == true
        else
            HX.bottom(L('hint_dial'), R.crackHintMs)
            won = HX.safeCrack(R.safeCrackLevel)
        end
        ClearPedTasks(ped)
        if not won then
            HX.send('pickSnapped')
            HX.tip(L('pick_snapped'))
        else
            local ok, opened = HX.call('breakIn', 5000, id)
            if not ok then
                HX.tip(L('no_answer'))
            elseif opened then
                HX.send('startProtection', id) -- protection already started on the server; harmless
                HX.busy, picking = false, false
                HX.enter(id)
                return
            end
        end
    end
    HX.busy, picking = false, false
end

-- the crew's prompts at the raided door; true when shown
function HX.Raid.doorPrompts(r)
    if not run or run.id ~= r.id then return false end
    if secondsLeft() > 0 then
        if HX.prompt(L('raiding'), L('stop_raid')) then HX.send('raidStop', r.id) end
    else
        if HX.prompt(L('raid_now'), L('pick_lock')) then CreateThread(function() pickLock(r.id) end) end
    end
    return true
end

RegisterNetEvent('pup_hideouts:lootRevoked', function(id)
    local r = HX.rows[tonumber(id)]
    if r and not r.member then r.isCrew = false; r.ledger = nil end
end)

----------------------------------------------------------------------------------------------------
-- tearing down the still (raiders inside a cracked hideout)
----------------------------------------------------------------------------------------------------
HX.Teardown = {}
local td = { state = 'idle', id = nil } -- idle | busy | running | loose

local function tdReset()
    if td.state == 'running' then HX.progressCancel() end
    td.state, td.id = 'idle', nil
end

local function tdStart(id)
    td.state, td.id = 'busy', id
    local ok, has = HX.call('hasTool', 4000)
    if not ok then HX.tip(L('no_answer')) return tdReset() end
    if not has then HX.tip(L('missing_tool')) return tdReset() end
    HX.bottom(L('pry_hint'), 4000)
    if not HX.buttonMash(T.mashLevel) then HX.tip(L('lock_held')) return tdReset() end
    local answered, started, secs = HX.call('teardownStart', 5000, id)
    if not answered then HX.tip(L('no_answer')) return tdReset() end
    if not started or td.id ~= id then return tdReset() end
    td.state = 'running'
    HX.progress(L('tearing_down'), (tonumber(secs) or T.seconds) * 1000)
end

local function tdClaim(id)
    td.state = 'busy'
    local ok, done = HX.call('teardownClaim', 6000, id)
    if ok and done then tdReset() else td.state = 'loose' end
end

RegisterNetEvent('pup_hideouts:teardownLoose', function(id)
    if td.id ~= tonumber(id) then return end
    td.state = 'loose'
    HX.tip(L('still_loose'))
end)

RegisterNetEvent('pup_hideouts:teardownCancel', function(id)
    if td.id == tonumber(id) then tdReset() end
end)

AddEventHandler('pup_hideouts:leavingHideout', function(id)
    if td.id == id and td.state ~= 'loose' then tdReset() end
end)

-- returns true when it showed a prompt
function HX.Teardown.prompt(r, zone, pos)
    if not r.justraided or r.member or not r.still or (r.still.stilllevel or 0) <= 0 then return false end
    if U.dist(pos, zone.still) > T.range then return false end
    if td.state == 'busy' or td.state == 'running' then return false end
    if td.state == 'loose' and td.id == r.id then
        if HX.prompt(L('title_still'), L('take_parts')) then CreateThread(function() tdClaim(r.id) end) end
        return true
    end
    if HX.prompt(L('title_still'), L('tear_down')) then CreateThread(function() tdStart(r.id) end) end
    return true
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if run then timerStop() end
end)
