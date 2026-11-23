-- pup-magic | a player being fed on: drained, held down, then staggering for a while

local F <const> = Config.Feeding
local A <const> = Config.Integrations.animations

local SCREEN_FX <const> = { 'MP_DeathInk_Color10', 'OJDominoBlur', 'KingsCastleRed' }

local active = false  -- the whole sequence, drunk walk included
local frozen = false

local function bloodScreen(on)
    for _, fx in ipairs(SCREEN_FX) do
        if on then AnimpostfxPlay(fx) elseif AnimpostfxIsRunning(fx) then AnimpostfxStop(fx) end
    end
    if on then ShakeGameplayCam('VIBRATE_SHAKE', 1.0) else StopGameplayCamShaking(true) end
end

local function finish()
    bloodScreen(false)
    SetDrunk(PlayerPedId(), false, 0.0)
    if frozen then FreezeEntityPosition(PlayerPedId(), false) frozen = false end
end

RegisterNetEvent('pup-magic:victim', function(durationMs, heading)
    if active then return end
    local cap = F.feedMs + F.victimExtraMs + 2000
    local ms = math.floor(math.min(math.max(tonumber(durationMs) or F.victimDefaultMs, 0), cap))
    local h = tonumber(heading)
    active = true

    CreateThread(function()
        local ped = PlayerPedId()
        -- drained, never killed: a nearly dead victim keeps 1 health
        SetEntityHealth(ped, math.max(1, math.floor(GetEntityHealth(ped) * 0.3)), 0)
        SetCoreValue(ped, 0, CoreValue(ped, 0) * 0.3)
        SetCoreValue(ped, 1, CoreValue(ped, 1) * 0.3)

        bloodScreen(true)
        TipBottom(Locale.victimDrained, 7000)

        FreezeEntityPosition(ped, true)
        frozen = true
        ClearPedTasksImmediately(ped)
        if h then SetEntityHeading(ped, h + 0.0) end
        StartVorpAnim(A.victim)

        Wait(ms)
        if not active then return end

        TipBottom(Locale.victimBlur, 7000)
        EndVorpAnim(A.victim)
        ped = PlayerPedId()
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        frozen = false

        -- the stagger: blood screen stays on, a small shake now and then
        local stop = GetGameTimer() + F.drunkMs
        while active and GetGameTimer() < stop do
            SetDrunk(PlayerPedId(), true, 0.95)
            if math.random() < 0.5 then ShakeGameplayCam('VIBRATE_SHAKE', 0.25) end
            Wait(math.min(5000, math.max(0, stop - GetGameTimer())))
        end
        if not active then return end

        finish()
        ClearPedTasks(PlayerPedId())
        TipBottom(Locale.victimRecover, 4000)
        active = false
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not active then return end
    active = false
    EndVorpAnim(A.victim)
    finish()
end)
