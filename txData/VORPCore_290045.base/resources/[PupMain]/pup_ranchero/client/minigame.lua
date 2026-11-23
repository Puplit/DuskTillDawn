-- pup_ranchero | the collecting minigame (own NUI page) and the pup-minigames skill-bar fallback

local MG = Config.Minigame
local result = nil   -- the page's answer for the running round
local running = false

RegisterNUICallback('gameDone', function(data, cb)
    cb('ok')
    if running and type(data) == 'table' then
        result = { clicks = math.max(0, math.floor(tonumber(data.clicks) or 0)), spawned = math.max(0, math.floor(tonumber(data.spawned) or 0)) }
    end
end)

local function themeForPage()
    local ok, theme = pcall(function() return exports['pup-ui']:GetTheme() end)
    if ok and type(theme) == 'table' then return { colors = theme.colors, fonts = theme.fonts } end
    return nil
end

local function collectScore(clicks, spawned, ratio)
    if spawned <= 0 then return 0 end
    local target = math.max(1, U.round(spawned * ratio))
    return U.round(math.min(1, clicks / target) * Config.Chores.maxScore)
end

local function collectGame(art, overrideKey, label)
    local o = MG.overrides[overrideKey] or {}
    local cfg = {
        seconds = MG.roundSeconds,
        spawnMs = o.spawnMs or MG.spawnMs,
        riseMin = MG.riseMin, riseMax = MG.riseMax,
        speedUp = MG.speedUp, spawnShrink = MG.spawnShrink,
    }
    local ratio = o.catchRatio or MG.catchRatio
    result, running = nil, true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'start', art = art, label = label, cfg = cfg, theme = themeForPage() })

    local stop = GetGameTimer() + (MG.roundSeconds + MG.safetySeconds) * 1000
    while not result and GetGameTimer() < stop do Wait(100) end
    if not result then
        SendNUIMessage({ action = 'stop' })
        local grace = GetGameTimer() + 1000
        while not result and GetGameTimer() < grace do Wait(50) end
    end
    running = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    if not result then return 0 end
    return collectScore(result.clicks, result.spawned, ratio)
end

local function skillBarRound()
    local sb = MG.skillBar
    local zone = math.max(sb.minZone, sb.baseZone - sb.zoneStep * sb.difficulty)
    local speed = math.min(sb.maxSpeed, sb.baseSpeed + sb.speedStep * sb.difficulty)
    local p, settled = promise.new(), false
    local function settle(v)
        if settled then return end
        settled = true
        p:resolve(v)
    end
    local ok = pcall(function()
        exports['pup-minigames']:skill_bar({
            style = 'default', orientation = 1, area_size = zone, perfect_area_size = sb.perfectZone,
            speed = speed, moving_icon = false,
        }, settle)
    end)
    if not ok then return 0 end
    SetTimeout(sb.roundTimeout * 1000, function() settle('timeout') end)
    local outcome = Citizen.Await(p)
    if outcome == 'perfect' then return 2 end
    if outcome == 'success' then return 1 end
    return 0
end

local function skillBarGame(roundsKind)
    local rounds = MG.skillBar.rounds[roundsKind] or MG.skillBar.rounds.chore
    if rounds > 1 then TipBottom(L('roundsTip', rounds)) end
    local points = 0
    for _ = 1, rounds do
        points = points + skillBarRound()
        Wait(400)
    end
    return U.round(points / (rounds * 2) * Config.Chores.maxScore)
end

-- art: bales|dung|sack|hay|bucket|pails|basket ; overrideKey: chore name, 'milk' or 'eggs'
function PlayMinigame(art, overrideKey, label, roundsKind)
    if MG.collectGame then return collectGame(art, overrideKey, label) end
    return skillBarGame(roundsKind)
end

Cleanups[#Cleanups + 1] = function()
    if running then
        running = false
        result = { clicks = 0, spawned = 0 }
        SendNUIMessage({ action = 'hide' })
        SetNuiFocus(false, false)
    end
end
