-- pup-medical | the weakness period after a revive

local R = (Config.Medical and Config.Medical.recovery) or {}

local SPRINT <const> = 0x8FFC75D6
local AIM    <const> = 0xF84FA74F
local ATTACK <const> = 0x07CE1E61
local UNARMED <const> = `WEAPON_UNARMED`

local skipNext = false
local running = false
local cancelled = false
local session = 0

local function stopEffect()
    if type(R.effect) == 'string' and R.effect ~= '' then AnimpostfxStop(R.effect) end
end

local function startRecovery()
    if skipNext then
        skipNext = false
        return
    end
    if not R.enabled or running then return end
    local seconds = math.floor(tonumber(R.durationSeconds) or 30)
    if seconds <= 0 then return end

    running = true
    cancelled = false
    session = session + 1
    local mine = session
    TriggerEvent('fred_hud:recoveryBar', seconds)
    TipBottom(L('recoveryStart'), 5000)
    if type(R.effect) == 'string' and R.effect ~= '' then AnimpostfxPlay(R.effect) end

    local ends = GetGameTimer() + seconds * 1000
    local lastNag = 0
    local outcome = 'done'
    while GetGameTimer() < ends do
        Wait(0)
        if cancelled or session ~= mine then outcome = 'cancel' break end
        local ped = PlayerPedId()
        if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then outcome = 'died' break end
        DisableControlAction(0, SPRINT, true)
        DisableControlAction(0, AIM, true)
        DisableControlAction(0, ATTACK, true)
        local _, current = GetCurrentPedWeapon(ped, true, 0, false)
        if current ~= UNARMED then SetCurrentPedWeapon(ped, UNARMED, true, 0, false, false) end
        if IsDisabledControlPressed(0, SPRINT) or IsDisabledControlPressed(0, AIM) then
            local now = GetGameTimer()
            if now - lastNag > 5000 then
                lastNag = now
                TipBottom(L('recoveryStart'), 3000)
            end
        end
    end

    stopEffect()
    if session == mine then running = false end
    if outcome == 'done' then
        TipBottom(L('recoveryEnd'), 4000)
    else
        TriggerEvent('fred_hud:recoveryBar', 0)
    end
end

local function onRevived()
    CreateThread(function()
        DoScreenFadeOut(800)
        local deadline = GetGameTimer() + 3000
        while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(50) end
        Wait(1200)
        DoScreenFadeIn(800)
        startRecovery()
    end)
end

RegisterNetEvent('vorp_core:Client:OnPlayerRevive', onRevived)
RegisterNetEvent('vorp:resurrectPlayer', onRevived)

-- the server marks a respawn when respawns should skip the weakness
RegisterNetEvent('pup-medical:client:skipRecoveryOnce', function()
    skipNext = true
end)

exports('SkipNextRecovery', function()
    skipNext = true
end)

exports('CancelRecovery', function()
    if running then cancelled = true end
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    if running then cancelled = true end
    skipNext = false
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if running then
        stopEffect()
        TriggerEvent('fred_hud:recoveryBar', 0)
    end
end)
