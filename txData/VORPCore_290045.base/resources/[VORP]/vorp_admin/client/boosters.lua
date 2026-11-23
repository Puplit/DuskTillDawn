-- Modified by Puppet (Dusk Till Dawn), 2026
-- BOOSTERS --------------------------------
local god = false

local goldenCores = false
local infiniteammo = false
local NoClipActive = false
local invis = false
local T = Translation.Langs[Config.General.language]

function GODmode()
    local player = PlayerPedId()
    if not god then
        TriggerEvent('vorp:TipRight', T.Notify.switchedOn, 3000)
        SetEntityCanBeDamaged(player, false)
        SetEntityInvincible(player, true)
        SetPedConfigFlag(player, 2, true) -- No critical hits
        SetPedCanRagdoll(player, false)
        SetPedCanBeTargetted(player, false)
        Citizen.InvokeNative(0x5240864E847C691C, player, false) -- Set ped can be incapacitaded
        -- takes a PLAYER index, not the ped handle: a low ped handle lands on a real
        -- player index and leaves somebody else invincible with nothing to clear it
        SetPlayerInvincible(PlayerId(), true)
        Citizen.InvokeNative(0xFD6943B6DF77E449, player, false) -- Set ped can be lassoed
        TriggerServerEvent("vorp_admin:GodMode")                -- log
        god = true
    else
        TriggerEvent('vorp:TipRight', T.Notify.switchedOff, 3000)
        SetEntityCanBeDamaged(player, true)
        SetEntityInvincible(player, false)
        SetPedConfigFlag(player, 2, false)
        SetPedCanRagdoll(player, true)
        SetPedCanBeTargetted(player, true)
        Citizen.InvokeNative(0x5240864E847C691C, player, true)
        SetPlayerInvincible(PlayerId(), false)
        Citizen.InvokeNative(0xFD6943B6DF77E449, player, true)
        god = false
    end
end

function GoldenCores()
    local player = PlayerPedId()
    if not goldenCores then
        TriggerEvent('vorp:TipRight', T.Notify.switchedOn, 3000)
        -- Inner cores
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, 100)
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, 100)
        -- Citizen.InvokeNative(0xC6258F41D86676E0, player, 2, 100) -- Dead Eye

        -- Outter cores
        Citizen.InvokeNative(0x4AF5A4C7B9157D14, player, 0, 5000.0)
        Citizen.InvokeNative(0x4AF5A4C7B9157D14, player, 1, 5000.0)
        -- Citizen.InvokeNative(0x4AF5A4C7B9157D14, player, 2, 5000.0) -- Dead Eye

        Citizen.InvokeNative(0xF6A7C08DF2E28B28, player, 1, 5000.0)
        -- Citizen.InvokeNative(0xF6A7C08DF2E28B28, player, 2, 5000.0)-- Dead Eye
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, player, 0, 5000.0)
        TriggerServerEvent("vorp_admin:GoldenCores") -- log
        goldenCores = true
    else
        TriggerEvent('vorp:TipRight', T.Notify.switchedOff, 3000)
        -- Inner cores
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, 100)
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, 100)
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 2, 100)

        -- Outter cores
        Citizen.InvokeNative(0x4AF5A4C7B9157D14, player, 0, 0.0)
        Citizen.InvokeNative(0x4AF5A4C7B9157D14, player, 1, 0.0)
        Citizen.InvokeNative(0x4AF5A4C7B9157D14, player, 2, 0.0)

        Citizen.InvokeNative(0xF6A7C08DF2E28B28, player, 1, 0.0)
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, player, 2, 0.0)
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, player, 0, 0.0)
        goldenCores = false
    end
end

function InfiAmmo()
    local player = PlayerPedId()
    local _, weaponHash = GetCurrentPedWeapon(player, false, 0, false)
    if not infiniteammo then
        infiniteammo = true
        local unarmed = -1569615261
        TriggerEvent("vorp:TipRight", T.Notify.switchedOn, 3000)
        if weaponHash == unarmed then
            TriggerEvent("vorp:Tip", T.Notify.needWeaponInHands, 3000)
        else
            SetPedInfiniteAmmo(player, true, weaponHash)
            TriggerServerEvent("vorp_admin:InfiAmmo") -- log
        end
    else
        infiniteammo = false
        TriggerEvent("vorp:TipRight", T.Notify.switchedOff, 3000)
        SetPedInfiniteAmmo(player, false, weaponHash)
    end
end

-- The toggles below live HERE because they flip file-local state (NoClipActive / invis)
function ToggleNoClip()
    local player = PlayerPedId()
    if not NoClipActive then
        EnableNoclip(player)
        NoClipActive = true
        VORP.NotifyObjective(T.Notify.switchedOn, -1)
        TriggerServerEvent("vorp_admin:NoClip") -- log
    else
        ResetNoclip(player)
        DisableRagdollingWhileFall()
        NoClipActive = false
        VORP.NotifyObjective(T.Notify.switchedOff, 5000)
    end
end

function ToggleInvisible()
    local player = PlayerPedId()
    if not invis then
        SetEntityVisible(player, false)
        invis = true
    else
        SetEntityVisible(player, true)
        invis = false
    end
end

function SelfHeal()
    TriggerServerEvent('vorp_admin:HealSelf', "selfheal")
    Config.Heal.restoreMetabolism()
    local horse = GetMount(PlayerPedId())
    if horse ~= 0 then
        Citizen.InvokeNative(0xC6258F41D86676E0, horse, 0, 600) -- Health
        Citizen.InvokeNative(0xC6258F41D86676E0, horse, 1, 600) -- Stamina
    end
end

function SpawnWagonModel(wagon_model)
    local player = PlayerPedId()
    local playerCoords = GetEntityCoords(player)
    RequestModel(wagon_model, false)
    repeat Wait(0) until HasModelLoaded(wagon_model)

    local wagon = CreateVehicle(wagon_model, playerCoords.x, playerCoords.y, playerCoords.z, 0, true, true, false, false)
    repeat Wait(0) until DoesEntityExist(wagon)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, wagon, 1, 0)
    SetPedIntoVehicle(player, wagon, -1)

    TriggerServerEvent("vorp_admin:spawnWagon", wagon_model) -- log
end

function SpawnHorseModel(horse_model)
    local player = PlayerPedId()
    local playerCoords = GetEntityCoords(player) + 1
    RequestModel(horse_model, false)
    repeat Wait(0) until HasModelLoaded(horse_model)

    local horse = CreatePed(joaat(horse_model), playerCoords.x, playerCoords.y, playerCoords.z, 0.0, true, true, false, false)
    repeat Wait(0) until DoesEntityExist(horse)

    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, horse, 1, 0)
    Citizen.InvokeNative(0x028F76B6E78246EB, player, horse, -1, true)

    TriggerServerEvent("vorp_admin:spawnHorse", horse_model) -- log
end

-- SPAWN ANY ANIMAL, by model name OR raw hash
local function animalHash(input)
    input = tostring(input or ''):gsub('%s+', '')
    if input == '' then return nil end
    if input:match('^%-?%d+$') then return math.floor(tonumber(input)) end
    return joaat(input)
end

function SpawnAnimalModel(input)
    local hash = animalHash(input)
    if not hash then return end

    -- CHECKED FIRST, unlike the two spawners above: `repeat until HasModelLoaded` never ends for a model that does not exist
    if not IsModelValid(hash) then
        VORP.NotifyObjective('No such model: ' .. tostring(input), 4000)
        return
    end

    RequestModel(hash, false)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end
    if not HasModelLoaded(hash) then
        VORP.NotifyObjective('Model would not load: ' .. tostring(input), 4000)
        return
    end

    -- in front of you, not on top of you: a big animal spawned at your feet shoves the player through whatever is behind them
    local player <const> = PlayerPedId()
    local coords <const> = GetEntityCoords(player)
    local fwd <const> = GetEntityForwardVector(player)
    local x, y, z = coords.x + fwd.x * 3.0, coords.y + fwd.y * 3.0, coords.z

    local ped = CreatePed(hash, x, y, z, GetEntityHeading(player), true, true, false, false)
    local tries = 0
    while not DoesEntityExist(ped) and tries < 100 do Wait(10) tries = tries + 1 end
    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, 1, 0)
    -- without a variation an animal can render untextured
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    SetModelAsNoLongerNeeded(hash)

    TriggerServerEvent("vorp_admin:spawnAnimal", tostring(input)) -- log
end

function BuildBoost()
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleBooster,
        options = {
            {
                label = T.Menus.MainBoostOptions.selfGodMode,
                desc = T.Menus.MainBoostOptions.selfGodMode_desc,
                action = function()
                    if IsAdminAllowed("godmode") then
                        GODmode()
                    end
                end
            },
            {
                label = T.Menus.MainBoostOptions.selfNoClip,
                desc = T.Menus.MainBoostOptions.selfNoClip_desc .. "\n" .. T.Menus.MainBoostOptions.move .. "\n" .. T.Menus.MainBoostOptions.speedMode .. "\n" .. T.Menus.MainBoostOptions.cammode,
                action = function()
                    if IsAdminAllowed("noclip") then
                        ToggleNoClip()
                    end
                end
            },
            {
                label = T.Menus.MainBoostOptions.selfGoldCores,
                desc = T.Menus.MainBoostOptions.selfGoldCores_desc,
                action = function()
                    if IsAdminAllowed("golden_cores") then
                        GoldenCores()
                    end
                end
            },
            {
                label = T.Menus.MainBoostOptions.enabledInfinityAmmo,
                desc = T.Menus.MainBoostOptions.enabledInfinityAmmo_desc,
                action = function()
                    if IsAdminAllowed("infinite_ammo") then
                        InfiAmmo()
                    end
                end
            },
            {
                label = T.Menus.MainBoostOptions.spawnWagon,
                desc = T.Menus.MainBoostOptions.spawnWagon_desc,
                action = function()
                    if not IsAdminAllowed("spawn_wagon") then return end
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.MainBoostOptions.SpawnWagonInput.title, {
                        { label = T.Menus.MainBoostOptions.SpawnWagonInput.placeholder, type = 'text', placeholder = T.Menus.MainBoostOptions.SpawnWagonInput.placeholder, required = true }
                    }, T.Menus.MainBoostOptions.SpawnWagonInput.errorMsg)
                    if not vals then return end
                    local wagon_model = tostring(vals[1])
                    if wagon_model ~= "" then
                        SpawnWagonModel(wagon_model)
                    else
                        VORP.NotifyObjective(T.Notify.empty, 3000)
                    end
                end
            },
            {
                label = T.Menus.MainBoostOptions.spawnHorse,
                desc = T.Menus.MainBoostOptions.spawnHorse_desc,
                action = function()
                    if not IsAdminAllowed("spawn_horse") then return end
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.MainBoostOptions.SpawnHorseInput.title, {
                        { label = T.Menus.MainBoostOptions.SpawnHorseInput.placeholder, type = 'text', placeholder = T.Menus.MainBoostOptions.SpawnHorseInput.placeholder, required = true }
                    }, T.Menus.MainBoostOptions.SpawnHorseInput.errorMsg)
                    if not vals then return end
                    local horse_model = tostring(vals[1])
                    if horse_model ~= "" then
                        SpawnHorseModel(horse_model)
                    else
                        VORP.NotifyObjective(T.Notify.empty, 3000)
                    end
                end
            },
            {
                label = T.Menus.MainBoostOptions.selfHeal,
                desc = T.Menus.MainBoostOptions.selfHeal_desc,
                action = function()
                    SelfHeal()
                end
            },
            {
                label = T.Menus.MainBoostOptions.selfRevive,
                desc = T.Menus.MainBoostOptions.selfRevive_desc,
                action = function()
                    TriggerServerEvent('vorp_admin:ReviveSelf', "selfrevive")
                end
            },
            {
                label = T.Menus.MainBoostOptions.selfInvisible,
                desc = T.Menus.MainBoostOptions.selfInvisible_desc,
                action = function()
                    if IsAdminAllowed("invisibility") then
                        ToggleInvisible()
                    end
                end
            },
        }
    }
end

local function DisableControls()
    DisableControlAction(0, 0xB238FE0B, true) -- Disable controls here
    DisableControlAction(0, 0x3C0A40F2, true) -- Disable controls here
end


local Prompt1 = 0
local Prompt2 = 0
local Prompt4 = 0
local Prompt6 = 0
local PromptGroup = GetRandomIntInRange(0, 0xffffff)

--PROMPTS
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    FreezeEntityPosition(PlayerPedId(), false)

    local str = T.Menus.MainBoostOptions.Prompts.down .. "/" .. T.Menus.MainBoostOptions.Prompts.up

    Prompt1 = UiPromptRegisterBegin()
    UiPromptSetControlAction(Prompt1, Config.Keys.noclipDown)
    UiPromptSetControlAction(Prompt1, Config.Keys.noclipUp)
    str = VarString(10, 'LITERAL_STRING', str)
    UiPromptSetText(Prompt1, str)
    UiPromptSetEnabled(Prompt1, true)
    UiPromptSetVisible(Prompt1, true)
    UiPromptSetStandardMode(Prompt1, true)
    UiPromptSetGroup(Prompt1, PromptGroup, 0)
    UiPromptRegisterEnd(Prompt1)

    str = T.Menus.MainBoostOptions.Prompts.speed
    Prompt2 = UiPromptRegisterBegin()
    UiPromptSetControlAction(Prompt2, Config.Keys.noclipSpeed) -- shift
    str = VarString(10, 'LITERAL_STRING', str)
    UiPromptSetText(Prompt2, str)
    UiPromptSetEnabled(Prompt2, true)
    UiPromptSetVisible(Prompt2, true)
    UiPromptSetStandardMode(Prompt2, true)
    UiPromptSetGroup(Prompt2, PromptGroup, 0)
    UiPromptRegisterEnd(Prompt2)

    str = T.Menus.MainBoostOptions.Prompts.backward .. "/" .. T.Menus.MainBoostOptions.Prompts.forward
    Prompt4 = UiPromptRegisterBegin()
    UiPromptSetControlAction(Prompt4, Config.Keys.noclipBackward)
    UiPromptSetControlAction(Prompt4, Config.Keys.noclipForward)
    str = VarString(10, 'LITERAL_STRING', str)
    UiPromptSetText(Prompt4, str)
    UiPromptSetEnabled(Prompt4, true)
    UiPromptSetVisible(Prompt4, true)
    UiPromptSetStandardMode(Prompt4, true)
    UiPromptSetGroup(Prompt4, PromptGroup, 0)
    UiPromptRegisterEnd(Prompt4)

    str = T.Menus.MainBoostOptions.Prompts.cancel
    Prompt6 = UiPromptRegisterBegin()
    UiPromptSetControlAction(Prompt6, Config.Keys.noclipCancel)
    str = VarString(10, 'LITERAL_STRING', str)
    UiPromptSetText(Prompt6, str)
    UiPromptSetEnabled(Prompt6, true)
    UiPromptSetVisible(Prompt6, true)
    UiPromptSetStandardMode(Prompt6, true)
    UiPromptSetGroup(Prompt6, PromptGroup, 0)
    UiPromptRegisterEnd(Prompt6)
end)

function ResetNoclip(ped)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true)
    SetEveryoneIgnorePlayer(PlayerId(), false)
    SetPedCanBeTargetted(ped, true)
    SetGameplayCamInitialHeading(0.0)
    SetPlayerLockon(PlayerId(), true)
    ClearPedTasks(ped, true, true)
end

function EnableNoclip(ped)
    ClearPedTasks(ped, true, true)
    SetGameplayCamInitialHeading(0.0)
    SetPlayerLockon(PlayerId(), false)
    SetEntityCollision(ped, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false)
    SetEveryoneIgnorePlayer(PlayerId(), true)
    SetPedCanBeTargetted(ped, false)
end

-- credits to txAdmin for the function
local function getFallImpulse(H)
    local coefficient = 1.6428571428571428
    local intercept = 3.5714285714285836
    return coefficient * H + intercept
end

function DisableRagdollingWhileFall()
    CreateThread(function()
        local ped = PlayerPedId()
        local pedHeight = GetEntityHeightAboveGround(ped)
        if pedHeight == nil or pedHeight < 4.0 then
            return
        end

        SetEntityInvincible(ped, true)
        SetRagdollBlockingFlags(ped, (1 << 9)) --RBF_FALLING
        local downForce = getFallImpulse(pedHeight)
        ApplyForceToEntity(ped, 3, 0.0, 0.0, -downForce, 0.0, 0.0, 0.0, 0, true, true, false, true, false)

        local fallAwaitLimit = 1000
        local fallAwaitStep = 25
        local fallAwaitElapsed = 0
        while not IsPedFalling(ped) do
            if fallAwaitElapsed >= fallAwaitLimit then
                SetEntityInvincible(ped, false)

                return
            end
            fallAwaitElapsed = fallAwaitElapsed + fallAwaitStep
            Wait(fallAwaitStep)
        end

        repeat
            Wait(50)
        until not IsPedFalling(ped)
        Wait(750)
        SetEntityInvincible(ped, false)
        ClearRagdollBlockingFlags(ped, (1 << 9)) --RBF_FALLIN
    end)
end

CreateThread(function()
    repeat Wait(2000) until LocalPlayer.state.IsInSession

    local index = 1
    local CurrentSpeed = Config.NoClip.speeds[index].speed
    local Label = Config.NoClip.speeds[index].label

    while true do
        local sleep = 1000

        if NoClipActive then
            sleep = 0
            local player = PlayerPedId()
            local yoff = 0.0
            local zoff = 0.0

            DisableControls()
            SetEntityVisible(player, false)

            local label = VarString(10, 'LITERAL_STRING', T.Menus.MainBoostOptions.Prompts.speed_desc .. Label .. " " .. CurrentSpeed)
            UiPromptSetActiveGroupThisFrame(PromptGroup, label, 0, 0, 0, 0)

            if IsDisabledControlJustPressed(1, Config.Keys.noclipSpeed) then
                if index ~= #Config.NoClip.speeds then
                    index = index + 1
                    CurrentSpeed = Config.NoClip.speeds[index].speed
                    Label = Config.NoClip.speeds[index].label
                else
                    CurrentSpeed = Config.NoClip.speeds[1].speed
                    index = 1
                    Label = Config.NoClip.speeds[index].label
                end
            end

            if IsDisabledControlPressed(0, Config.Keys.noclipForward) then
                yoff = Config.NoClip.forwardMultiplier
                SetEntityRotation(player, 0.0, 0.0, 0.0, 2, false)
                local heading = GetGameplayCamRelativeHeading()
                SetEntityHeading(player, heading)
            end

            if IsDisabledControlPressed(0, Config.Keys.noclipBackward) then
                yoff = -Config.NoClip.forwardMultiplier
                SetEntityRotation(player, 0.0, 0.0, 0.0, 2, false)
                local heading = GetGameplayCamRelativeHeading()
                SetEntityHeading(player, heading)
            end

            if IsDisabledControlPressed(0, Config.Keys.noclipUp) then
                zoff = Config.NoClip.verticalMultiplier
                local newPos = GetOffsetFromEntityInWorldCoords(player, 0.0, yoff * (CurrentSpeed + 0.3), zoff * (CurrentSpeed + 0.3))
                SetEntityCoordsNoOffset(player, newPos.x, newPos.y, newPos.z, NoClipActive, NoClipActive, NoClipActive)
            end

            if IsDisabledControlPressed(0, Config.Keys.noclipDown) then
                zoff = -Config.NoClip.verticalMultiplier
                local newPos = GetOffsetFromEntityInWorldCoords(player, 0.0, yoff * (CurrentSpeed + 0.3), zoff * (CurrentSpeed + 0.3))
                SetEntityCoordsNoOffset(player, newPos.x, newPos.y, newPos.z, NoClipActive, NoClipActive, NoClipActive)
            end

            if IsDisabledControlPressed(0, Config.Keys.noclipCancel) then
                VORP.NotifyObjective(T.Notify.switchedOff, 5000)
                NoClipActive = false
                ResetNoclip(player)
                DisableRagdollingWhileFall()
            end


            local newPos = GetOffsetFromEntityInWorldCoords(player, 0.0, yoff * (CurrentSpeed + 0.3), zoff * (CurrentSpeed + 0.3))
            SetEntityCoordsNoOffset(player, newPos.x, newPos.y, newPos.z, NoClipActive, NoClipActive, NoClipActive)
        end
        Wait(sleep)
    end
end)
