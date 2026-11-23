-- pup-medical | the death screen, the hold-to-respawn prompt and the teleport

local D = Config.Death or {}

local screenUp = false
local lastHint = nil

local function hintFor(prompt, timerRunning)
    local cmd = prompt.alertCommand or 'alertmedic'
    if not prompt.respawnEnabled then return L('hintNoRespawn', cmd) end
    if timerRunning then return L('hintWaiting', cmd) end
    return L('hintReady', cmd)
end

local function showScreen(seconds, hint)
    screenUp = true
    lastHint = hint
    SendNUIMessage({ action = 'deathShow', title = L('deathTitle'), seconds = seconds, label = L('countdownLabel'), hint = hint })
end

local function updateHint(hint)
    if hint == lastHint then return end
    lastHint = hint
    SendNUIMessage({ action = 'deathHint', hint = hint })
end

local function hideScreen()
    if not screenUp then return end
    screenUp = false
    lastHint = nil
    SendNUIMessage({ action = 'deathHide' })
end

local function makeRespawnPrompt(group, prompt)
    return MakePrompt(group, Config.Keys.respawn, L('respawnLabel'), math.floor(tonumber(prompt.holdMs) or 2000))
end

-- one death: from the first dead frame until alive again
local function whileDown()
    local prompt = D.prompt or {}
    local delay = math.floor(tonumber(prompt.respawnDelaySeconds) or 0)   -- read fresh: the purge changes it
    local readyAt = GetGameTimer() + delay * 1000
    local timerRunning = delay > 0
    showScreen(timerRunning and delay or 0, hintFor(prompt, timerRunning))

    local group = GetRandomIntInRange(0, 0xffffff)
    local respawnPrompt = prompt.respawnEnabled and makeRespawnPrompt(group, prompt) or nil
    local ignoreUntil = 0

    while IsDownNow() do
        Wait(0)
        local now = GetGameTimer()
        if timerRunning and now >= readyAt then
            timerRunning = false
            updateHint(hintFor(prompt, false))
        end

        if respawnPrompt then
            UiPromptSetEnabled(respawnPrompt, not timerRunning and now >= ignoreUntil)
        elseif prompt.respawnEnabled and now >= ignoreUntil then
            respawnPrompt = makeRespawnPrompt(group, prompt)
        end
        ShowGroup(group, L('deathTitle'))

        if respawnPrompt and not timerRunning and now >= ignoreUntil and UiPromptHasHoldModeCompleted(respawnPrompt) then
            local told = ToldNoDoctors ~= nil
            ToldNoDoctors = nil
            TriggerServerEvent('pup-medical:server:respawn', InWater(), told)
            -- a fresh prompt after the pause, so the completed hold resets
            UiPromptDelete(respawnPrompt)
            respawnPrompt = nil
            ignoreUntil = now + 5000
        end
    end

    if respawnPrompt then UiPromptDelete(respawnPrompt) end
    hideScreen()
    AlertsOnAlive()
end

CreateThread(function()
    while true do
        local prompt = D.prompt or {}
        if prompt.enabled and LocalPlayer.state.IsInSession and IsDownNow() then
            whileDown()
        end
        Wait(500)
    end
end)

-- the server picked the nearest respawn point
RegisterNetEvent('pup-medical:client:respawnTeleport', function(point)
    if type(point) ~= 'table' then return end
    local x, y, z = tonumber(point.x), tonumber(point.y), tonumber(point.z)
    if not x or not y or not z then return end
    DoScreenFadeOut(500)
    local deadline = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(50) end
    SetEntityCoords(PlayerPedId(), x, y, z, false, false, false, false)
    Wait(1500)
    DoScreenFadeIn(800)
end)

-- vorp_core's own respawn path, if it ever runs: report the losses claim
AddEventHandler('vorp:PlayerForceRespawn', function()
    local told = ToldNoDoctors ~= nil
    ToldNoDoctors = nil
    TriggerServerEvent('pup-medical:server:forceRespawnLosses', InWater(), told)
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    hideScreen()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    SendNUIMessage({ action = 'deathHide' })
end)
