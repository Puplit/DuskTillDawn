-- goldpan | client: one load of gravel, from the scoop to the reward request

Pan = {
    out      = false, -- the pan is in hand
    prop     = nil,
    working  = false, -- a load is being worked
    session  = 0,     -- bumped on every Search and every put-away; old work threads stop when it changes
    token    = nil,   -- server session token of the load being worked
    awaiting = nil,   -- session id waiting for pup_goldpan:begun
    reply    = nil,
    digging  = false,
}

local O <const> = Config.Options

-- the work thread for session sid may go on
local function alive(sid)
    return Pan.out and Pan.working and Pan.session == sid
end

-- wait ms, stopping early when the session is abandoned
local function hold(ms, sid)
    local deadline = GetGameTimer() + ms
    while GetGameTimer() < deadline do
        if not alive(sid) then return false end
        Wait(100)
    end
    return alive(sid)
end

function Pan.cancelToken()
    if Pan.token then
        TriggerServerEvent('pup_goldpan:cancel', Pan.token)
        Pan.token = nil
    end
end

RegisterNetEvent('pup_goldpan:begun', function(token, reason)
    if Pan.awaiting and Pan.awaiting == Pan.session and Pan.working then
        Pan.reply = { token = token, reason = reason }
        return
    end
    -- the load was abandoned or timed out while the server answered
    if type(token) == 'string' then TriggerServerEvent('pup_goldpan:cancel', token) end
end)

-- ask the server to open a session; returns the token or nil
local function openSession(sid, zone)
    Pan.reply = nil
    Pan.awaiting = sid
    TriggerServerEvent('pup_goldpan:begin', zone)
    local deadline = GetGameTimer() + (O.ReplyTimeoutMs or 5000)
    while not Pan.reply and GetGameTimer() < deadline and alive(sid) do Wait(50) end
    Pan.awaiting = nil
    local reply = Pan.reply
    Pan.reply = nil
    if not reply then return nil end
    if type(reply.token) ~= 'string' then
        Cli.say(reply.reason or 'NoPan')
        return nil
    end
    if not alive(sid) then
        TriggerServerEvent('pup_goldpan:cancel', reply.token)
        return nil
    end
    return reply.token
end

local function skillBarOptions()
    local T, d = Config.MinigameTuning, tonumber(Config.Minigame.Difficulty) or 0
    return {
        style             = 'default',
        icon              = Config.Minigame.Icon,
        orientation       = 1,
        area_size         = GP.clamp(T.baseArea - d * T.areaLoss, T.minArea, T.baseArea),
        perfect_area_size = T.perfectArea,
        speed             = GP.clamp(T.baseSpeed + d * T.speedGain, T.baseSpeed, T.maxSpeed),
        moving_icon       = false,
    }
end

local function swirlOptions()
    local S = Config.Swirl
    return {
        style      = 'default',
        duration   = S.duration,
        target_min = S.target_min,
        target_max = S.target_max,
        silt_rate  = S.silt_rate,
        gold_rate  = S.gold_rate,
        hint       = S.hint,
        slow_text  = S.slow_text,
        good_text  = S.good_text,
        fast_text  = S.fast_text,
    }
end

-- run the minigame and wait for its score (0.0 - 1.0); 0 on timeout or when abandoned
local function minigame(sid, useSwirl)
    local result
    local function finish(v)
        if Pan.session == sid and result == nil then result = v end
    end

    local waitMs
    local started = false
    if useSwirl then
        started = pcall(function()
            exports['pup-minigames']:gold_pan(swirlOptions(), function(score)
                finish(GP.clamp(tonumber(score) or 0.0, 0.0, 1.0))
            end)
        end)
        waitMs = (tonumber(Config.Swirl.duration) or 15000) + (O.MinigameGraceMs or 10000)
    end
    if not started then
        local ok = pcall(function()
            exports['pup-minigames']:skill_bar(skillBarOptions(), function(res)
                if res == 'perfect' then finish(1.0)
                elseif res == 'success' then finish(0.7)
                else finish(0.0) end
            end)
        end)
        if not ok then return 0.0 end
        waitMs = (tonumber(O.WorkTimer) or 10) * 1000 + (O.MinigameGraceMs or 10000)
    end

    local deadline = GetGameTimer() + waitMs
    while result == nil do
        if not alive(sid) then return 0.0 end
        if GetGameTimer() > deadline then return 0.0 end
        Wait(50)
    end
    return result
end

-- the work thread; every exit path below ends in finish()
function Pan.search()
    if Pan.working then Cli.say('Working') return end
    if Pan.digging then Cli.say('Digging') return end

    local ped = PlayerPedId()
    local zone = 0
    if Cli.yes(IsEntityInWater(ped)) then zone = Cli.waterZone(ped) end
    if zone == 0 or not GP.water(zone) then Cli.say('WrongArea') return end

    Pan.session = Pan.session + 1
    local sid = Pan.session
    Pan.working = true

    local function finish()
        if Pan.session ~= sid then return end -- put away already cleaned up
        local p = PlayerPedId()
        ClearPedTasks(p)
        Cli.attach(Pan.prop, p, 'carry')
        Pan.working = false
        Pan.token = nil
        TriggerEvent('panning:panning', false)
    end

    local token = openSession(sid, zone)
    if not token then
        if Pan.session == sid then Pan.working = false end
        return
    end
    Pan.token = token
    TriggerEvent('panning:panning', true)

    local ok, err = pcall(function()
        -- scoop
        Cli.attach(Pan.prop, ped, 'work')
        local scoopMs = O.ScoopMs or 6000
        Cli.play(ped, O.StartPanningInfo, scoopMs)
        if not hold(scoopMs, sid) then return end

        -- swirl animation runs for the whole minigame
        local useSwirl = Config.UseSwirl == true
        local gameMs = useSwirl and (tonumber(Config.Swirl.duration) or 15000) or (tonumber(O.WorkTimer) or 10) * 1000
        ClearPedTasks(ped)
        Cli.play(ped, O.StartShakeInfo, (O.SettleMs or 1500) + gameMs + (O.SwirlExtraMs or 1500))
        if not hold(O.SettleMs or 1500, sid) then return end

        local score = minigame(sid, useSwirl)
        if not alive(sid) then return end

        if score <= 0 then
            Cli.say('Sloppy')
            Pan.cancelToken()
            return
        end

        if not hold(O.RewardDelayMs or 1200, sid) then return end
        if Pan.token == token then
            TriggerServerEvent('pup_goldpan:reward', token, score)
            Pan.token = nil
        end
    end)
    if not ok then
        Cli.log('pan failed: ' .. tostring(err))
        if Pan.session == sid then Pan.cancelToken() end
    end
    finish()
end
