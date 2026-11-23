-- knockout | losing a fist fight, or a horse kick, puts you on the ground instead of killing you.
-- A small state machine on the game clock: UP -> DOWN (until a deadline, healing on a timer) -> UP.
-- Being killed while down, or dying any other way, is left to the death system (pup-medical).

local Cfg = KnockoutConfig

local IS_PED_IN_MELEE_COMBAT = 0x4E209B2C1EAD5159
local IS_THIS_MODEL_A_HORSE  = 0x772A1969F649E902

local ko = {
    down       = false, -- on the ground right now
    standAt    = 0,     -- game time the player gets back up
    healAt     = 0,     -- game time of the next heal
    shieldTill = 0,     -- invincible until this time
    labelTill  = 0,     -- the "knocked out" text shows until this time
    horseAt    = 0,     -- last time a horse hurt us (0 = none pending)
    announced  = false, -- what the scene label and the inventory lock were last told
}

-- the scene KO label and the inventory lock always flip together
local function announce(down)
    down = down and true or false
    if ko.announced == down then return end
    ko.announced = down
    TriggerServerEvent("pup-scene:setKO", down)
    TriggerEvent("vorp_inventory:blockInventory", down)
end

-- never leave the inventory locked with nothing running to unlock it
AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() and ko.announced then
        TriggerServerEvent("pup-scene:setKO", false)
        TriggerEvent("vorp_inventory:blockInventory", false)
    end
end)

local function horse(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not IsEntityAPed(ent) then return false end
    local yes = Citizen.InvokeNative(IS_THIS_MODEL_A_HORSE, GetEntityModel(ent))
    return yes == true or yes == 1
end

local function drawLabel(text)
    SetTextScale(0.6, 0.6)
    SetTextColor(161, 3, 0, 255)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), 0.5, 0.9)
end

local function knockDown(ped, shieldMs)
    if ko.down then return end
    -- a dead player belongs to pup-medical; knocking them out as well left them invisible
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return end

    local now = GetGameTimer()
    local rec = Cfg.Recovery
    ko.down       = true
    ko.healAt     = now + rec.stepMs
    ko.standAt    = now + rec.steps * rec.stepMs
    ko.shieldTill = now + (shieldMs or 0)
    ko.labelTill  = now + (Cfg.Display.labelMs or 0)

    SetEntityHealth(ped, rec.startHealth)
    SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
    announce(true)
end

-- back to normal; used for getting up and for being killed while down
local function release()
    ko.down, ko.standAt, ko.healAt, ko.shieldTill, ko.labelTill = false, 0, 0, 0, 0
    SetPlayerInvincible(PlayerId(), false)
    announce(false)
end

-- a horse hit only stamps the time; the loop decides, so the two cannot race
AddEventHandler("gameEventTriggered", function(name, args)
    if not Cfg.HorseKick.enabled or name ~= "CEventNetworkEntityDamage" or type(args) ~= "table" then return end
    if args[1] == PlayerPedId() and horse(args[2]) then
        ko.horseAt = GetGameTimer()
    end
end)

-- while UP: should this frame knock us down?
local function watch(ped, now)
    local kick = Cfg.HorseKick

    if kick.enabled then
        -- a kick can kill from full health: stand them back up where they fell, then knock out
        if IsEntityDead(ped) and horse(GetPedSourceOfDeath(ped)) then
            ko.horseAt = 0
            local at = GetEntityCoords(ped)
            NetworkResurrectLocalPlayer(at.x, at.y, at.z, GetEntityHeading(ped), true, false)
            SetEntityHealth(ped, Cfg.Recovery.startHealth)
            ClearPedTasksImmediately(ped)
            knockDown(PlayerPedId(), kick.protectMs)
            return
        end
        -- checked before melee, so a kick that leaves you above the melee line still counts
        if ko.horseAt > 0 then
            if now - ko.horseAt > kick.graceMs then
                ko.horseAt = 0
            elseif GetEntityHealth(ped) < kick.healthThreshold then
                ko.horseAt = 0
                knockDown(ped, kick.protectMs)
                return
            end
        end
    end

    -- scripted fights opt out (pup-events sets this while its mimics are alive)
    if LocalPlayer.state.pupNoMeleeKO then return end
    if Citizen.InvokeNative(IS_PED_IN_MELEE_COMBAT, ped) and GetEntityHealth(ped) < Cfg.Melee.healthThreshold then
        knockDown(ped, Cfg.Melee.shieldMs)
    end
end

-- while DOWN: keep them on the ground, heal on the clock, get up at the deadline
local function hold(ped, now)
    if IsPedDeadOrDying(ped, true) then
        -- killed while down: let go completely so the death system can respawn cleanly
        release()
        return
    end

    -- a downed player can be killed; only the shield window protects them
    SetPlayerInvincible(PlayerId(), now < ko.shieldTill)
    DisablePlayerFiring(PlayerId(), true)
    SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
    ResetPedRagdollTimer(ped)

    local rec = Cfg.Recovery
    while ko.healAt <= ko.standAt and now >= ko.healAt do
        SetEntityHealth(ped, GetEntityHealth(ped) + rec.healPerStep)
        ko.healAt = ko.healAt + rec.stepMs
    end

    if now >= ko.standAt then
        release()
    elseif now < ko.labelTill then
        drawLabel(KnockoutLocale.knockedOut)
    end
end

CreateThread(function()
    while true do
        local ped, now = PlayerPedId(), GetGameTimer()
        if ko.down then hold(ped, now) else watch(ped, now) end
        Wait(0)
    end
end)
