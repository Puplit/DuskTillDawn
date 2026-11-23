-- pup-misc / pomade (client) Applies the "POMADE" hair wearable state, with the matching apply animation

local function badPed(p)
    return not IsPedHuman(p)
        or IsEntityDead(p)
        or IsPedRagdoll(p)
        or IsPedOnMount(p)
        or IsPedInAnyVehicle(p, false)
        or Citizen.InvokeNative(0x3AA24CCC0D451379, p)   -- hogtied
        or Citizen.InvokeNative(0x74E559B3BC910685, p)   -- cuffed
end

RegisterNetEvent("pup_pomade:apply", function()
    local ped = PlayerPedId()
    if badPed(ped) then return end

    local hasHat = Citizen.InvokeNative(0xFB4891BD7578CDC1, ped, `hats`)
    TaskItemInteraction(ped, 0, GetHashKey(hasHat and "APPLY_POMADE_WITH_HAT" or "APPLY_POMADE_WITH_NO_HAT"), 1, 0, -1082130432)
    Wait(1500)

    -- find the hair component and flip its wearable state
    local n = Citizen.InvokeNative(0x90403E8107B60E81, ped, Citizen.ResultAsInteger()) or 0
    for i = 0, n - 1 do
        local cat = Citizen.InvokeNative(0x9B90842304C938A7, ped, i, 0, Citizen.ResultAsInteger())
        if cat == `hair` then
            local buf = DataView.ArrayBuffer(6 * 8)
            local hash = Citizen.InvokeNative(0x77BA37622E22023B, ped, i, true, buf:Buffer(), buf:Buffer(), Citizen.ResultAsInteger())
            if hash and hash ~= 0 then
                Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, hash, GetHashKey("POMADE"), 0, true, 1)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            end
            break
        end
    end
end)
