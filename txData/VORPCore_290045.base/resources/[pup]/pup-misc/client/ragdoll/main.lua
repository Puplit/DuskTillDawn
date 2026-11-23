-- pup-misc / ragdoll - press the key (default Z) to flop, press it again to get up.
-- It never starts while the ped is already ragdolling for any reason, and the sustain loop
-- drops out the moment another state takes over

local ragdoll    = false
local lastToggle = 0

-- is the ped in a state some OTHER system owns?
local function isBusy(ped)
    if RagdollConfig.Blocks.dead and IsPedDeadOrDying(ped, true) then return true end

    if RagdollConfig.Blocks.hogtied then
        local ok, tied = pcall(function()
            return Citizen.InvokeNative(0x3AA24CCC0D451379, ped)
        end)
        if ok and tied then return true end
    end

    if RagdollConfig.Blocks.mounted then
        if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return true end
    end

    if RagdollConfig.Blocks.inWater then
        local ok, swimming = pcall(function() return IsPedSwimming(ped) end)
        if ok and swimming then return true end
    end

    -- CUFFED COUNTS AS BUSY
    local okCuff, cuffed = pcall(function()
        return Citizen.InvokeNative(0x74E559B3BC910685, ped)
    end)
    if okCuff and cuffed then return true end

    return false
end

local function toggleRagdoll()
    if not RagdollConfig.General.enabled then return end

    -- not while a UI has the keyboard
    if IsNuiFocused() then return end

    local now = GetGameTimer()
    if (now - lastToggle) < (RagdollConfig.General.cooldownMs or 200) then return end
    lastToggle = now

    -- getting up is ALWAYS allowed: never trap a player down
    if ragdoll then ragdoll = false return end

    local ped = PlayerPedId()
    if isBusy(ped) then return end

    -- do not start on top of a ragdoll somebody else owns (knockout, a fall, a wagon crash)
    if RagdollConfig.Blocks.alreadyRagdolled then
        local ok, already = pcall(function() return IsPedRagdoll(ped) end)
        if ok and already then return end
    end

    ragdoll = true
    local ms = RagdollConfig.Ragdoll.pulseMs or 1000
    SetPedToRagdoll(ped, ms, ms, 0, 0, 0, 0)
end

local CMD <const> = RagdollConfig.General.command or 'ragdoll'
RegisterCommand(CMD, toggleRagdoll, false)
RegisterKeyMapping(CMD, RagdollLocale.keyLabel or 'Ragdoll', 'keyboard', RagdollConfig.Keys.toggle or 'Z')

-- the sustain loop: keeps the ped down until the toggle is released
Citizen.CreateThread(function()
    if not RagdollConfig.General.enabled then return end
    while true do
        Citizen.Wait(ragdoll and 0 or 200)
        if ragdoll then
            local ped = PlayerPedId()
            -- hand the ped straight back if another system takes it over (knocked out, hogtied, killed, mounted) - it owns them now
            if isBusy(ped) then
                ragdoll = false
            else
                local ms = RagdollConfig.Ragdoll.pulseMs or 1000
                SetPedToRagdoll(ped, ms, ms, 0, 0, 0, 0)
                ResetPedRagdollTimer(ped)
            end
        end
    end
end)

-- never leave somebody face down because the resource restarted
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if ragdoll then
        ragdoll = false
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then SetPedToRagdoll(ped, 0, 0, 0, false, false, false) end
    end
end)
