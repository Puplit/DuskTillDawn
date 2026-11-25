-- fred_metabolism | animations.lua - every consume animation in one place. client.lua's useItem handler delegates here

local animDone = true
local PropPrompt = nil

local function hideWeapons(ped)
    Citizen.InvokeNative(0xFCCC886EDE3C63EC, ped, 2, 1) -- HidePedWeapons
end

function isAnimDone()
    return animDone
end

function playAnimation(anim)
    local ped = PlayerPedId()
    if not DoesAnimDictExist(anim.dict) then
        return
    end

    RequestAnimDict(anim.dict)

    while not HasAnimDictLoaded(anim.dict) do
        Wait(0)
    end

    TaskPlayAnim(ped, anim.dict, anim.name, 1.0, 1.0, -1, anim.flag, 0, false, false, false, '', false)

    RemoveAnimDict(anim.dict)
end

function screenEffect(effect, time)
    AnimpostfxPlay(effect)
    Citizen.Wait(time * 1000)
    AnimpostfxStop(effect)
end

local SET_OBJECT_PROMPT_NAME <const> = 0xAEE6C800E124CFE1

function setPromptName(prop, label)
    if not prop or prop == 0 or type(label) ~= "string" or label == "" then return end
    pcall(Citizen.InvokeNative, SET_OBJECT_PROMPT_NAME, prop, label)
end

-- WHAT NAMES THE DRINK PROMPT.
--
-- Not the item hash: coffee and water pass the same one and read differently.
-- The game resolves a GXT key named after the prop - p_mugCoffee01x -> COFFEE,
-- p_bottleJD01x -> WHISKEY - and prints that entry, which is why a bottle of
-- water read "Whiskey". Overwriting the entry is the only way in, so each flow
-- swaps its key to the item's own label for the length of the drink and puts
-- the original back afterwards. GXT entries are global; leaving one rewritten
-- would rename the real item everywhere it appears.
local PROMPT_KEYS <const> = {
    longbottle  = "WHISKEY",
    shortbottle = "BEER",
    drink_cup   = "COFFEE",
    bowl        = "STEW",
}
local originalLabel = {}

local function labelText(key)
    return Citizen.InvokeNative(0x3429670F9B9EF2D3, key, Citizen.ResultAsString())
end

local function claimPromptLabel(key, label)
    if not key or type(label) ~= "string" or label == "" then return nil end
    if originalLabel[key] == nil then originalLabel[key] = labelText(key) or key end
    AddTextEntry(key, label)
    return key
end

local function releasePromptLabel(key)
    if key and originalLabel[key] ~= nil then AddTextEntry(key, originalLabel[key]) end
end

function executeAnimation(animKey, propName, label)
    if propName == "" then propName = nil end
    local promptKey <const> = PROMPT_KEYS[animKey]

    -- claimed before the task starts, so the prompt it builds reads the new text
    local claimed <const> = claimPromptLabel(promptKey, label)

    if (animKey == "eat" or animKey == "drink") and propName then playStandarAnim(animKey, propName)
    elseif animKey == "drink_cup" then playDrinkCupAnim(label)
    elseif animKey == "bowl" then playBowlAnim(label)
    elseif animKey == "syringe" then playSyringeAnim()
    elseif animKey == "berry" then playBerryAnim()
    elseif animKey == "shortbottle" and propName then playShortBottleAnim(propName, label)
    elseif animKey == "longbottle" and propName then playLongBottleAnim(propName, label)
    -- no `and propName`: a cigar with no prop set still smokes, it just has nothing in its hand
    elseif animKey == "smoke" then playSmokeAnim(propName)
    elseif animKey == "sponge" then playSpongeAnim()
    end

    releasePromptLabel(claimed)
end

-- washes the player
function playSpongeAnim()
    animDone = false
    local ped = PlayerPedId()
    hideWeapons(ped)

    local dict, name
    if IsPedMale(ped) then
        dict, name = "mp_amb_player@prop_player_wash_face_barrel@sober@male_a@base", "base"
    else
        dict, name = "amb_misc@world_human_wash_face_bucket@table@female_a@idle_d", "idle_j"
    end
    playAnimation({ dict = dict, name = name, flag = 0 })
    Citizen.Wait(2500)

    -- raw hashes, not the named wrappers: ClearPedEnvDirt is only DEFINED in pup-stable/client/natives.lua
    Citizen.InvokeNative(0x6585D955A68452A5, ped)          -- clear env dirt
    Citizen.InvokeNative(0x8FE22675A5A45817, ped)          -- clear blood damage
    Citizen.InvokeNative(0xE3144B932DFDFF65, ped, 0.0, -1, 1, 1)
    Citizen.InvokeNative(0x523C79AEEFCC4A2A, ped, 10, "ALL") -- clear decals by zone
    Citizen.InvokeNative(0x7F5D88333EE8A86F, ped, 1)
    Citizen.InvokeNative(0x9C720776DAA43E7E, ped)
    TriggerEvent("pup_camps:washedface")

    ClearPedSecondaryTask(ped)
    animDone = true
end

function playStandarAnim(animKey, propName)
    animDone = false
    local Anims = {
        ["eat"] = {
            dict = "mech_inventory@eating@multi_bite@sphere_d8-2_sandwich",
            name = "quick_left_hand",
            flag = 24,
            bone = "SKEL_L_Finger12",
        },
        ["drink"] = {
            dict = "amb_rest_drunk@world_human_drinking@male_a@idle_a",
            name = "idle_a",
            flag = 24,
            bone = "SKEL_R_Finger12",
        },
    }
    local animation = Anims[animKey]
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(GetHashKey(propName), coords.x, coords.y, coords.z + 0.2, true, true, false, false, true)
    local boneIndex = GetEntityBoneIndexByName(ped, animation.bone)
    Citizen.Wait(0)
    hideWeapons(ped)
    playAnimation(animation)
    if prop and prop ~= 0 then
        AttachEntityToEntity(prop, ped, boneIndex, 0.02, 0.028, 0.001, 15.0, 175.0, 0.0, true, true, false, true, 1, true)
    end
    Citizen.Wait(1000)
    if prop and prop ~= 0 then DeleteEntity(prop) end
    ClearPedSecondaryTask(ped)
    animDone = true
end

function playDrinkCupAnim(label)
    animDone = false
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    hideWeapons(ped)
    local prop = CreateObject(GetHashKey('p_mugCoffee01x'), coords, true, true, true)
    setPromptName(prop, label)
    TaskItemInteraction_2(ped, -1199896558, prop, GetHashKey('p_mugCOFFEE01x_ph_r_hand'), GetHashKey('DRINK_COFFEE_HOLD'), 3, 0, -1.0)
    Citizen.Wait(10000)
    ClearPedSecondaryTask(ped)
    if DoesEntityExist(prop) then DeleteEntity(prop) end
    animDone = true
end

function playBowlAnim(label)
    animDone = false
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    hideWeapons(ped)
    local bowl = CreateObject("p_bowl04x_stew", coords, true, true, true)
    local spoon = CreateObject("p_spoon01x", coords, true, true, true)
    Citizen.InvokeNative(0x669655FFB29EF1A9, bowl, 0, "Stew_Fill", 1.0)
    Citizen.InvokeNative(0xCAAF2BCCFEF37F77, bowl, 20)
    Citizen.InvokeNative(0xCAAF2BCCFEF37F77, spoon, 82)
    setPromptName(bowl, label)
    TaskItemInteraction_2(ped, 599184882, bowl, GetHashKey("p_bowl04x_stew_ph_l_hand"), -583731576, 3, 0, -1.0)
    TaskItemInteraction_2(ped, 599184882, spoon, GetHashKey("p_spoon01x_ph_r_hand"), -583731576, 3, 0, -1.0)
    Citizen.InvokeNative(0xB35370D5353995CB, ped, -583731576, 1.0)
    Citizen.Wait(20000)
    if DoesEntityExist(bowl) then DeleteEntity(bowl) end
    if DoesEntityExist(spoon) then DeleteEntity(spoon) end
    ClearPedTasks(ped)
    animDone = true
end

function playSyringeAnim()
    animDone = false
    local ped = PlayerPedId()
    local animation = {
        dict = "mech_inventory@item@stimulants@inject@quick",
        name = "quick_stimulant_inject_lhand",
        flag = 0,
    }
    playAnimation(animation)
    Wait(5000)
    ClearPedTasks(ped)
    animDone = true
end

function playBerryAnim()
    animDone = false
    local ped = PlayerPedId()
    local animation = {
        dict = "mech_pickup@plant@berries",
        name = "exit_eat",
        flag = 0,
    }
    playAnimation(animation)
    Wait(2500)
    ClearPedTasks(ped)
    animDone = true
end

-- the interaction task deletes the bottle when the drink finishes
function waitBottleGone(propEntity)
    local deadline = GetGameTimer() + 30000
    while DoesEntityExist(propEntity) do
        Wait(100)
        if GetGameTimer() > deadline then
            DeleteEntity(propEntity)
            break
        end
    end
end

function playShortBottleAnim(propName, label)
    animDone = false
    local ped = PlayerPedId()
    local propEntity = CreateObject(GetHashKey(propName), GetEntityCoords(ped), false, true, false, false, true)
    setPromptName(propEntity, label)
    TaskItemInteraction_2(ped, -1199896558, propEntity, GetHashKey('p_bottleBeer01x_PH_R_HAND'), GetHashKey('DRINK_BOTTLE@Bottle_Cylinder_D1-55_H18_Neck_A8_B1-8_TABLE_HOLD'), 1, 0, -1.0)
    waitBottleGone(propEntity)
    animDone = true
end

function playLongBottleAnim(propName, label)
    animDone = false
    local ped = PlayerPedId()
    local propEntity = CreateObject(GetHashKey(propName), GetEntityCoords(ped), false, true, false, false, true)
    setPromptName(propEntity, label)
    TaskItemInteraction_2(ped, -1199896558, propEntity, GetHashKey('p_bottleJD01x_ph_r_hand'), GetHashKey('DRINK_BOTTLE@Bottle_Cylinder_D1-3_H30-5_Neck_A13_B2-5_TABLE_HOLD'), 1, 0, -1.0)
    waitBottleGone(propEntity)
    animDone = true
end

function playSmokeAnim(propName)
    animDone = false
    local ped = PlayerPedId()
    PlaySoundFrontend("Core_Full", "Consumption_Sounds", true, 0)

    local dict = 'amb_rest@world_human_smoke_cigar@male_a@idle_b'
    local anim = 'idle_d'
    local x, y, z = table.unpack(GetEntityCoords(ped, true))
    -- No prop configured falls back to a cigar rather than smoking thin air
    local fallback = (type(Config) == "table" and Config.Smoking and Config.Smoking.defaultProp) or "P_CIGAR01X"
    local model = (propName and propName ~= "") and propName or fallback
    local prop = nil
    if model and model ~= "" then
        prop = CreateObject(GetHashKey(model), x, y, z + 0.2, true, true, true)
    end
    local boneIndex = GetEntityBoneIndexByName(ped, 'SKEL_R_Finger12')
    local smoking = false
    local proppromptdisplayed = false

    -- Create the prompt if it doesn't exist
    if not PropPrompt then
        local promptText = CreateVarString(10, "LITERAL_STRING", Locale.stopSmoking)
        PropPrompt = UiPromptRegisterBegin()
        UiPromptSetControlAction(PropPrompt, 0x3B24C470) -- F key
        UiPromptSetText(PropPrompt, promptText)
        UiPromptSetEnabled(PropPrompt, false)
        UiPromptSetVisible(PropPrompt, false)
        UiPromptSetStandardMode(PropPrompt, true)
        UiPromptSetGroup(PropPrompt, 0, 0)
        UiPromptRegisterEnd(PropPrompt)
    end

    if not IsEntityPlayingAnim(ped, dict, anim, 3) then
        local waiting = 0
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            waiting = waiting + 100
            Citizen.Wait(100)
            if waiting > 5000 then
                print('RedM Fucked up this animation')
                break
            end
        end

        Wait(100)
        if prop then
            AttachEntityToEntity(prop, ped, boneIndex, 0.01, -0.00500, 0.01550, 0.024, 300.0, -40.0, true, true, false, true, 1, true)
        end
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 31, 0, true, 0, false, 0, false)
        Wait(1000)

        if not proppromptdisplayed then
            UiPromptSetEnabled(PropPrompt, true)
            UiPromptSetVisible(PropPrompt, true)
            proppromptdisplayed = true
        end

        smoking = true
        local startTime = GetGameTimer()
        local maxSmokingTime = 300000 -- 5 minutes maximum smoking time as safety

        while smoking do
            local currentTime = GetGameTimer()

            -- Safety timeout to prevent infinite smoking
            if (currentTime - startTime) > maxSmokingTime then
                smoking = false
                break
            end

            if IsEntityPlayingAnim(ped, dict, anim, 3) then
                DisableControlAction(0, 0x07CE1E61, true)
                DisableControlAction(0, 0xF84FA74F, true)
                DisableControlAction(0, 0xCEE12B50, true)
                DisableControlAction(0, 0xB2F377E8, true)
                DisableControlAction(0, 0x8FFC75D6, true)
                DisableControlAction(0, 0xD9D0E1C0, true)

                -- Check for F key prompt completion
                if UiPromptHasStandardModeCompleted(PropPrompt, 0) then
                    UiPromptSetEnabled(PropPrompt, false)
                    UiPromptSetVisible(PropPrompt, false)
                    proppromptdisplayed = false
                    smoking = false
                    ClearPedSecondaryTask(ped)
                    if prop then DeleteObject(prop) end
                    RemoveAnimDict(dict)
                    break
                end
            else
                TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 31, 0, true, 0, false, 0, false)
            end
            Wait(0)
        end
    end

    -- Ensure cleanup regardless of how the smoking ended
    if proppromptdisplayed and PropPrompt then
        UiPromptSetEnabled(PropPrompt, false)
        UiPromptSetVisible(PropPrompt, false)
    end

    if prop and DoesEntityExist(prop) then
        DeleteObject(prop)
    end

    ClearPedTasks(ped)
    RemoveAnimDict(dict)
    animDone = true
end

exports('isAnimDone', isAnimDone)
