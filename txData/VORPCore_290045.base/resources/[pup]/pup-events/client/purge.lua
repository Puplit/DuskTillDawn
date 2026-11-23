-- THE PURGE | what it changes about your own ped while live.
-- config flags are set once, but a ped rebuild drops them, so the handle is watched

-- 263 NoCriticalHits: a head hit lands as ordinary damage, so headshots are not instant kills
-- 245 is the flag that actually stops a shove; 124 is its opposite and must stay off.
local ON <const> = {
    { flag = 263, value = true },   -- NoCriticalHits
    { flag = 245, value = true },   -- DontActivateRagdollFromAnyPedImpact
    { flag = 124, value = false },  -- ActivateRagdollFromMinorPlayerContact
}

-- only what we turned on is turned back off; 124 was never raised, so it is left alone
local OFF <const> = {
    { flag = 263, value = false },
    { flag = 245, value = false },
}

local applied = false
local appliedPed = 0

local function setFlags(ped, list)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    for _, f in ipairs(list) do
        pcall(SetPedConfigFlag, ped, f.flag, f.value)
    end
    return true
end

local function sync()
    local want <const> = EVC.isLive('purge')
    local ped <const> = PlayerPedId()

    if want then
        -- re-assert after /rc, a respawn or any other rebuild
        if not applied or appliedPed ~= ped then
            if setFlags(ped, ON) then
                applied, appliedPed = true, ped
            end
        end
    elseif applied then
        setFlags(ped, OFF)
        applied, appliedPed = false, 0
    end
end

RegisterNetEvent('pup-events:state', function(key)
    if key == 'purge' then sync() end
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    while true do
        sync()
        Wait(applied and 1000 or 3000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and applied then
        setFlags(PlayerPedId(), OFF)
    end
end)
