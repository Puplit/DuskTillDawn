-- pup-events | Trick or Treat (client). Renders the doors and handles the knock.
-- The server decides which doors are live and what is behind each one.

local Core = exports.vorp_core:GetCore()

local doors   = {}   -- from the server
local props   = {}   -- [n] = object
local blips   = {}
local mobs    = {}   -- [n] = { peds }
local knocking = false
local prompt, promptGroup

local function dropProp(n)
    if props[n] then EVC.deleteEntity(props[n]) props[n] = nil end
end

local function dropAllProps()
    for n in pairs(props) do dropProp(n) end
end

local function buildProp(n, d)
    if props[n] then return end
    local list <const> = d.trick and Config.TrickOrTreat.props.trick or Config.TrickOrTreat.props.treat
    local hash <const> = EVC.loadModel(list[math.random(#list)], 5000)
    if not hash then return end

    -- just outside the door, so it is not inside the wall
    local rad <const> = math.rad(d.w or 0.0)
    local x, y = d.x + math.sin(rad) * 0.6, d.y + math.cos(rad) * 0.6
    local z = EVC.groundAt(x, y, d.z) or d.z

    local obj = CreateObject(hash, x, y, z + 0.2, false, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return end
    Citizen.InvokeNative(0x58A850EAEE20FAA3, obj, false) -- PlaceObjectOnGroundProperly
    SetEntityHeading(obj, d.w or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityCanBeDamaged(obj, false)
    props[n] = obj
end

local function clearBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function drawBlips()
    clearBlips()
    if not (Config.TrickOrTreat.blips and Config.TrickOrTreat.blips.enabled) then return end
    for _, d in ipairs(doors) do
        local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, d.x, d.y, d.z)
        SetBlipSprite(b, joaat(Config.TrickOrTreat.blips.sprite), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, b, Config.TrickOrTreat.blips.label or 'Trick or Treat')
        blips[#blips + 1] = b
    end
end

RegisterNetEvent('pup-events:tnt:doors', function(list)
    dropAllProps()
    doors = list or {}
    drawBlips()
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    Wait(4000)
    TriggerServerEvent('pup-events:tnt:sync')
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    Wait(4000)
    TriggerServerEvent('pup-events:tnt:sync')
end)

-- ===========================================================================
-- THE MOB BEHIND THE DOOR
-- ===========================================================================
local function dropMob(n)
    for _, ped in ipairs(mobs[n] or {}) do EVC.deleteEntity(ped) end
    mobs[n] = nil
end

-- the brawl knockout stands down while they are out, or a machete kill becomes a knockout
local function anyMimicAlive()
    for _, list in pairs(mobs) do
        for _, ped in ipairs(list) do
            if DoesEntityExist(ped) and not IsEntityDead(ped) then return true end
        end
    end
    return false
end

CreateThread(function()
    local on = false
    while true do
        local want <const> = anyMimicAlive()
        if want ~= on then
            on = want
            LocalPlayer.state:set('pupNoMeleeKO', want, false)
        end
        Wait(400)
    end
end)

-- the flag must not outlive the resource, or melee KOs stay off for the session
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        LocalPlayer.state:set('pupNoMeleeKO', false, false)
    end
end)

-- a native missing on this build must not take the whole spawn down with it
local function try(fn, ...) pcall(fn, ...) end

-- no executions: a mimic's takedown can leave the player stuck in a grapple; RESET flags, re-applied every frame
local TAKEDOWN_FLAGS <const> = {
    187, -- PRF_PreventAllMeleeTakedowns
    188, -- PRF_PreventFailedMeleeTakedowns
    438, -- PRF_SuppressTakedownMeleeActions
    457, -- PRF_PreventAllStealthKills
}

CreateThread(function()
    while true do
        if anyMimicAlive() then
            local me <const> = PlayerPedId()
            for _, flag in ipairs(TAKEDOWN_FLAGS) do try(SetPedResetFlag, me, flag, true) end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- ClonePed leaves the height behind, so read it off our own statebag
local function myScale()
    local v = LocalPlayer.state.pupHeight
    if type(v) == 'table' then v = v.s end
    v = tonumber(v)
    if v and v >= 0.1 and v <= 5.0 then return v end
    return nil
end

-- ClonePed carries the whole metaped across, so the copy needs no dressing
local function spawnMimic(d, me, T)
    local clone = ClonePed(me, false, false, true)
    if not clone or clone == 0 then return nil end

    -- out of the doorway, slightly spread
    local a <const> = math.random() * math.pi * 2.0
    local x, y = d.x + math.cos(a) * 1.4, d.y + math.sin(a) * 1.4
    local z <const> = EVC.groundAt(x, y, d.z) or d.z
    SetEntityCoordsNoOffset(clone, x, y, z, false, false, false)
    SetEntityHeading(clone, d.w or 0.0)
    Wait(0)

    SetEntityAsMissionEntity(clone, true, true)
    SetBlockingOfNonTemporaryEvents(clone, false)
    SetEntityInvincible(clone, false)
    if EVC.relGroup then SetPedRelationshipGroupHash(clone, EVC.relGroup) end

    -- your height; the nudge makes the engine redraw it
    local s <const> = myScale()
    if s then
        SetPedScale(clone, s + 0.01)
        try(UpdatePedVariation, clone)
        SetPedScale(clone, s)
        try(UpdatePedVariation, clone)
    end

    -- SetPedMaxHealth, not SetEntityMaxHealth: the entity one does not raise a ped's cap
    local hp <const> = T.health or 400
    SetPedMaxHealth(clone, hp)
    SetEntityHealth(clone, hp, 0)
    if T.gore then EVC.gore(clone, 'SCR_Torture', 60.0, 1.0) end

    if T.noRagdoll then try(SetPedCanRagdoll, clone, false) end
    if T.moveRate then try(SetPedMoveRateOverride, clone, T.moveRate + 0.0) end

    -- NO SHOVING. 245 is the one that matters; 124 is its opposite and must stay off.
    if T.noShove then
        SetPedConfigFlag(clone, 245, true)   -- DontActivateRagdollFromAnyPedImpact
        SetPedConfigFlag(clone, 124, false)  -- ActivateRagdollFromMinorPlayerContact
        SetPedConfigFlag(clone, 29, true)    -- DisableMeleeHitReactions
        SetPedConfigFlag(clone, 169, true)   -- DisableGrappleByPlayer
        SetPedConfigFlag(clone, 340, true)   -- DisableAllMeleeTakedowns
        SetPedConfigFlag(clone, 87, true)    -- DisablePedAvoidance
        SetPedConfigFlag(clone, 174, true)   -- DisableEvasiveStep
        SetPedConfigFlag(clone, 296, true)   -- DisableAllAvoidance
    end

    -- beefy: 263 is the real no-one-shot flag, not SetPedSuffersCriticalHits
    if T.noCriticals then
        SetPedConfigFlag(clone, 263, true)   -- NoCriticalHits
        SetPedConfigFlag(clone, 16, true)    -- DontActivateRagdollFromBulletImpact
    end

    -- AGGRESSIVE. Never flees, never takes cover, always picks the fight.
    SetPedCombatAttributes(clone, 46, true)
    SetPedCombatAttributes(clone, 5, true)
    SetPedCombatAttributes(clone, 0, false)
    SetPedCombatAttributes(clone, 17, false)
    SetPedFleeAttributes(clone, 0, false)
    try(SetPedCombatMovement, clone, 3)
    try(SetPedCombatAbility, clone, 2)
    try(SetPedCombatRange, clone, 0)
    try(SetPedAlertness, clone, 3)
    SetPedSeeingRange(clone, T.sense or 60.0)
    SetPedHearingRange(clone, (T.sense or 60.0) * 1.2)

    -- the machete and nothing else, whatever you happen to be carrying
    Citizen.InvokeNative(0x5E3BDDBCB83F3D84, clone,
        GetHashKey(T.weapon or 'WEAPON_MELEE_MACHETE_HORROR'), 1,
        true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)

    -- SET_PED_TO_PLAYER_WEAPON_DAMAGE_MODIFIER: cuts what this ped does to the player at the source
    local dmg <const> = tonumber(T.damageModifier)
    if dmg and dmg > 0 then
        try(Citizen.InvokeNative, 0xD77AE48611B7B10A, clone, dmg + 0.0)
    end

    -- it looks at you wearing your own face first, then it comes
    TaskTurnPedToFaceEntity(clone, me, 2000)
    local stare <const> = T.stareMs and math.random(T.stareMs[1], T.stareMs[2]) or 1200
    SetTimeout(stare, function()
        if DoesEntityExist(clone) and not IsEntityDead(clone) then
            TaskCombatPed(clone, me, 0, 16)
        end
    end)
    return clone
end

-- caps what one swing can take, only while a living mimic is in range
local function capMimicDamage(n, T)
    local frac <const> = tonumber(T.maxHitFraction) or 0
    if frac <= 0 then return end
    CreateThread(function()
        local last = GetEntityHealth(PlayerPedId())
        while mobs[n] and #mobs[n] > 0 do
            Wait(0)
            local me <const> = PlayerPedId()
            local hp = GetEntityHealth(me)
            if hp < last then
                local here <const> = GetEntityCoords(me)
                local inRange = false
                for _, ped in ipairs(mobs[n] or {}) do
                    if DoesEntityExist(ped) and not IsEntityDead(ped)
                        and #(here - GetEntityCoords(ped)) < 3.5 then
                        inRange = true
                        break
                    end
                end
                local cap <const> = math.floor((GetEntityMaxHealth(me) or 200) * frac)
                -- a player already below the cap still dies: only the blow is limited
                if inRange and (last - hp) > cap then
                    hp = last - cap
                    SetEntityHealth(me, hp, 0)
                end
            end
            last = hp
        end
    end)
end

-- they give up eventually, so a door mob cannot follow you across the county
local function scheduleDespawn(n, T)
    local secs <const> = T.despawnSeconds or 90
    SetTimeout(secs * 1000, function()
        for _, ped in ipairs(mobs[n] or {}) do
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                TaskWanderStandard(ped, 10.0, 10)
                SetTimeout(20000, function() EVC.deleteEntity(ped) end)
            end
        end
        mobs[n] = nil
    end)
end

RegisterNetEvent('pup-events:tnt:trick', function(n)
    local d = doors[n]
    if not d or mobs[n] then return end
    mobs[n] = {}

    local T <const> = Config.TrickOrTreat.trick
    local me <const> = PlayerPedId()

    for _ = 1, math.random(T.count[1], T.count[2]) do
        local clone = spawnMimic(d, me, T)
        if clone then mobs[n][#mobs[n] + 1] = clone end
        Wait(60)
    end

    -- nothing came out, so let the door be knocked again rather than stay dead
    if #mobs[n] == 0 then
        mobs[n] = nil
        return
    end

    capMimicDamage(n, T)
    scheduleDespawn(n, T)
end)

RegisterNetEvent('pup-events:tnt:treat', function(n)
    -- the sack is handed over, so the one outside goes
    dropProp(n)
end)

-- ===========================================================================
-- STREAMING AND THE PROMPT
-- ===========================================================================
local function ensurePrompt()
    if prompt then return end
    promptGroup = GetRandomIntInRange(0, 0x7FFFFFFF)
    prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, joaat(Config.Keys.trickOrTreat))
    UiPromptSetText(prompt, VarString(10, 'LITERAL_STRING', Locale.trickOrTreat.prompt))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetHoldMode(prompt, Config.TrickOrTreat.promptHoldMs or 700)
    UiPromptSetGroup(prompt, promptGroup, 0)
    UiPromptRegisterEnd(prompt)
end

--- Turn to the door, rap on it, wait out the bar, and only then ask the server.
--- They knock where they stand: the scenario starts without an enter animation and the position is pinned.
local function doKnock(n, d)
    local K <const> = Config.TrickOrTreat.knock or {}
    local ms <const> = math.max(500, math.floor((tonumber(K.seconds) or 3.5) * 1000))
    local ped <const> = PlayerPedId()
    local spot <const> = GetEntityCoords(ped)

    -- a short turn to face the door, not one that runs the whole knock
    TaskTurnPedToFaceCoord(ped, d.x + 0.0, d.y + 0.0, d.z + 0.0, 600)
    Wait(600)

    if K.scenario then
        -- 4th arg false = no enter animation, so they do not step to a scenario point
        TaskStartScenarioInPlace(ped, joaat(K.scenario), ms, false, false, false, false)
    end
    if K.sound then PlaySoundFrontend(K.sound, 0, true, 0) end

    -- belt and braces: the scenario can still drift, so hold them on the spot
    SetEntityCoordsNoOffset(ped, spot.x, spot.y, spot.z, false, false, false)
    FreezeEntityPosition(ped, true)

    local answered = false
    local function answer()
        if answered then return end
        answered = true
        local me <const> = PlayerPedId()
        FreezeEntityPosition(me, false)
        ClearPedTasks(me)
        TriggerServerEvent('pup-events:tnt:knock', n)
        knocking = false
    end

    -- the floor goes down first, so a missing or failing Progress export cannot leave the knock unresolved
    SetTimeout(ms + 2000, answer)
    pcall(function()
        exports['pup-ui']:Progress({ label = K.label or 'Knocking...', duration = ms }, answer)
    end)
end

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    while true do
        local wait = 1000

        if Config.TrickOrTreat and Config.TrickOrTreat.enabled and EVC.isLive('deadofnight') and #doors > 0 then
            local me <const> = GetEntityCoords(PlayerPedId())
            local near, nearN

            for n, d in ipairs(doors) do
                local dist <const> = #(me - vector3(d.x, d.y, d.z))
                if dist <= (Config.TrickOrTreat.detectRadius or 70.0) then
                    buildProp(n, d)
                    if dist <= (Config.TrickOrTreat.promptDistance or 2.2) then near, nearN = d, n end
                elseif props[n] and dist > (Config.TrickOrTreat.detectRadius or 70.0) * 1.3 then
                    dropProp(n)
                end
            end

            if near and not knocking then
                wait = 0
                ensurePrompt()
                UiPromptSetActiveGroupThisFrame(promptGroup,
                    VarString(10, 'LITERAL_STRING', Locale.trickOrTreat.promptName), 0, 0, 0, 0)
                if UiPromptHasHoldModeCompleted(prompt) then
                    knocking = true
                    doKnock(nearN, near)
                end
            end
        elseif next(props) or #blips > 0 then
            dropAllProps()
            clearBlips()
            for n in pairs(mobs) do dropMob(n) end
            doors = {}
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- never leave somebody frozen mid-knock
    FreezeEntityPosition(PlayerPedId(), false)
    dropAllProps()
    clearBlips()
    for n in pairs(mobs) do dropMob(n) end
end)
