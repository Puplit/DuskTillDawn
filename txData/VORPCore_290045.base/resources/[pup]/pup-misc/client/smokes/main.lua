local isPlayerHigh = false
local highStartTime = 0

-- the prompts are grouped so the group header can name the item being smoked
SmokeGroup = GetRandomIntInRange(0, 0xffffff)
local smokeLabel = nil

function SetSmokeLabel(label)
    smokeLabel = (type(label) == 'string' and label ~= '') and label or nil
end

-- a grouped prompt only draws while its group is made active, every frame
Citizen.CreateThread(function()
    while true do
        if proppromptdisplayed and smokeLabel then
            PromptSetActiveGroupThisFrame(SmokeGroup,
                CreateVarString(10, 'LITERAL_STRING', smokeLabel), 1, 0, 0, 0)
            Wait(0)
        else
            Wait(200)
        end
    end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName == GetCurrentResourceName() then
        LocalPlayer.state:set('pupSmoking', false, true)
        if hightypex ~= nil then 
            Citizen.InvokeNative(0x516C6ABD18322B63, PlayerPedId(), false)
            Citizen.InvokeNative(0x95D2D383D5396B8A, PlayerPedId(), false)
            if Citizen.InvokeNative(0x4A123E85D7C4CA0B,hightypex) then 
	    		Citizen.InvokeNative(0xB4FD7446BAB2F394,hightypex)
	    	end
        end
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(500)
        if isPlayerHigh and IsEntityDead(PlayerPedId()) then
            isPlayerHigh = false
            ClearTimecycleModifier()
            Citizen.InvokeNative(0x516C6ABD18322B63, PlayerPedId(), false)
            Citizen.InvokeNative(0x95D2D383D5396B8A, PlayerPedId(), false)
            if hightypex ~= nil and Citizen.InvokeNative(0x4A123E85D7C4CA0B,hightypex) then 
                Citizen.InvokeNative(0xB4FD7446BAB2F394,hightypex)
                hightypex = nil
            end
            TriggerEvent("pup-smoke:setwalk",0.0)
        end
    end
end)
function FPrompt(text, button, hold)
    Citizen.CreateThread(function()
        proppromptdisplayed=false
        PropPrompt=nil
        local str = text or SmokesLocale.putAway
        local buttonhash = button or SmokesConfig.Keys.putAway
        local holdbutton = hold or false
        PropPrompt = PromptRegisterBegin()
        PromptSetControlAction(PropPrompt, buttonhash)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(PropPrompt, str)
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetHoldMode(PropPrompt, holdbutton)
        PromptSetGroup(PropPrompt, SmokeGroup, 0) -- before RegisterEnd
        PromptRegisterEnd(PropPrompt)
    end)
end

function Anim(actor, dict, body, duration, flags, introtiming, exittiming)
    Citizen.CreateThread(function()
        RequestAnimDict(dict)
        local dur = duration or -1
        local flag = flags or 1
        local intro = tonumber(introtiming) or 1.0
        local exit = tonumber(exittiming) or 1.0
        timeout = 5
        while (not HasAnimDictLoaded(dict) and timeout>0) do
            timeout = timeout-1
            if timeout == 0 then 
                print("Animation Failed to Load")
            end
            Citizen.Wait(300)
        end
        TaskPlayAnim(actor, dict, body, intro, exit, dur, flag --[[1 for repeat--]], 1, false, false, false, 0, true)
        end)
    end
    
    function StopAnim(dict, body)
    Citizen.CreateThread(function()
        StopAnimTask(PlayerPedId(), dict, body, 1.0)
    end)
end

function LMPrompt(text, button, hold)
    Citizen.CreateThread(function()
        UsePrompt=nil
        local str = text or SmokesLocale.use
        local buttonhash = button or SmokesConfig.Keys.use
        local holdbutton = hold or false
        UsePrompt = PromptRegisterBegin()
        PromptSetControlAction(UsePrompt, buttonhash)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(UsePrompt, str)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetHoldMode(UsePrompt, holdbutton)
        PromptSetGroup(UsePrompt, SmokeGroup, 0)
        PromptRegisterEnd(UsePrompt)
    end)
end

function EPrompt(text, button, hold)
    Citizen.CreateThread(function()
        ChangeStance=nil
        local str = text or SmokesLocale.use
        local buttonhash = button or SmokesConfig.Keys.stance
        local holdbutton = hold or false
        ChangeStance = PromptRegisterBegin()
        PromptSetControlAction(ChangeStance, buttonhash)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(ChangeStance, str)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)
        PromptSetHoldMode(ChangeStance, holdbutton)
        PromptSetGroup(ChangeStance, SmokeGroup, 0)
        PromptRegisterEnd(ChangeStance)
    end)
end

RegisterNetEvent('pup-smoke:gethigh')
AddEventHandler('pup-smoke:gethigh', function(hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk) 
    isPlayerHigh = true
    Wait(5000)
    if not turbo then 
        if drunkwalk > 0.0 then 
            TriggerEvent("pup-smoke:setwalk",drunkwalk)
        end
        hightypex = hightype
        local playerPed = PlayerPedId()
        Citizen.InvokeNative(0x516C6ABD18322B63, playerPed, true)
        Citizen.InvokeNative(0x95D2D383D5396B8A, playerPed, true) 
        AnimpostfxPlay(hightype)
        Citizen.InvokeNative(0xFDB74C9CC54C3F37, dscreen)
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < highduration * 1000 do
            local elapsedMs = GetGameTimer() - startTime
            local elapsedSec = math.floor(elapsedMs / 1000)
            if drunkwalk > 0.0 then 
                Citizen.InvokeNative(0x406CCF555B04FAD3, playerPed, true, drunkwalk)
            end
            Wait(100)
        end
        local totalElapsedMs = GetGameTimer() - startTime
        local totalElapsedSec = math.floor(totalElapsedMs / 1000)
        AnimpostfxStop(hightype)
        if currentFilter then
            AnimpostfxStop(currentFilter)
        end
        Citizen.InvokeNative(0xFDB74C9CC54C3F37, 0.0)
        Citizen.InvokeNative(0x516C6ABD18322B63, playerPed, false)
        Citizen.InvokeNative(0x95D2D383D5396B8A, playerPed, false)
        if drunkwalk > 0.0 then 
            TriggerEvent("pup-smoke:setwalk",0.0)
        end
    else
        ClearTimecycleModifier()
        local playerPed = PlayerPedId()
        -- array length only: filters also carries the .interval field
        local totalfilters = #filters
        local cycleMs = (tonumber(filters.interval) or 10) * 1000
        Citizen.InvokeNative(0x516C6ABD18322B63, playerPed, true)
        Citizen.InvokeNative(0x95D2D383D5396B8A, playerPed, true) 
        if drunkwalk > 0.0 then 
            TriggerEvent("pup-smoke:setwalk",drunkwalk)
        end
        local startTime = GetGameTimer()
        local lastFilterIndex = 0
        local initialEffectDuration = 10000
        local currentFilter = nil
        AnimpostfxPlay(hightype)
        Citizen.InvokeNative(0xFDB74C9CC54C3F37, dscreen)
        while GetGameTimer() - startTime < highduration * 1000 do
            local elapsedTime = GetGameTimer() - startTime
            local elapsedSec = math.floor(elapsedTime / 1000)
            
            if elapsedTime < initialEffectDuration then
            else
                if lastFilterIndex == 0 then
                    AnimpostfxStop(hightype)
                end
                local timeSinceEffects = elapsedTime - initialEffectDuration
                local filterIndex = (math.floor(timeSinceEffects / cycleMs) % totalfilters) + 1
                if filterIndex ~= lastFilterIndex then
                    if currentFilter then
                        AnimpostfxStop(currentFilter)
                    end
                    if filters[filterIndex] then
                        currentFilter = filters[filterIndex]
                        AnimpostfxPlay(currentFilter)
                    end
                    lastFilterIndex = filterIndex
                end
            end
            if drunkwalk > 0.0 then 
                Citizen.InvokeNative(0x406CCF555B04FAD3, playerPed, true, drunkwalk)
            end
            Wait(100)
        end
        local totalElapsedMs = GetGameTimer() - startTime
        local totalElapsedSec = math.floor(totalElapsedMs / 1000)
        AnimpostfxStop(hightype)
        if currentFilter then
            AnimpostfxStop(currentFilter)
        end
        ClearTimecycleModifier()
        Citizen.InvokeNative(0xFDB74C9CC54C3F37, 0.0)
        if drunkwalk > 0.0 then 
            TriggerEvent("pup-smoke:setwalk",0.0)
        end
        Citizen.InvokeNative(0x516C6ABD18322B63, playerPed, false)
        Citizen.InvokeNative(0x95D2D383D5396B8A, playerPed, false)
    end
    isPlayerHigh = false
end)

function keysx(table)
    local keys = 0
    for k,v in pairs(table) do
       keys = keys + 1
    end
    return keys
end

RegisterNetEvent('pup-smoke:setwalk')
AddEventHandler('pup-smoke:setwalk', function(amount)
    print("^2DEBUG: setwalk called with amount = ^7" .. tostring(amount))
    if amount > 0.0 then  
        print("^2DEBUG: Setting drunkwalk to ^7" .. tostring(amount))
        Citizen.InvokeNative(0x406CCF555B04FAD3, PlayerPedId(), true, amount)
    else
        print("^2DEBUG: Clearing drunkwalk")
        Citizen.InvokeNative(0x406CCF555B04FAD3 , PlayerPedId(), false, amount)
    end
end)

-- the buffs land when the smoke is put away, not the moment it is lit
local function applySmokeBuffs(high,hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk)
    if high then
        TriggerEvent("pup-smoke:gethigh",hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk)
    end
    if hboost ~= 0 then
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, PlayerPedId(), 0, hboost + 0.0, true)
    end
    if sboost ~= 0 then
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, PlayerPedId(), 1, sboost + 0.0, true)
    end
end

RegisterNetEvent('pup-smoke:inhale')
local function runInhale(typeof,high,hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk,label)
    TriggerEvent("vorp_inventory:CloseInv")
    SetSmokeLabel(label) -- the header above the prompts
    if typeof == "peace" then
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)

        FPrompt(SmokesLocale.putAway, SmokesConfig.Keys.putAway, false)
        LMPrompt(SmokesLocale.use, SmokesConfig.Keys.use, false)
        EPrompt(SmokesLocale.pose, SmokesConfig.Keys.stance, false)
        ExecuteCommand('close')
        local ped = PlayerPedId()
        local male = IsPedMale(ped)
        local x,y,z = table.unpack(GetEntityCoords(ped, true))
        local pipe = CreateObject(GetHashKey("p_peacepipe01x"), x, y, z + 0.2, true, true, true)
        local righthand = GetEntityBoneIndexByName(ped, "SKEL_R_Finger13")
        AttachEntityToEntity(pipe, ped, righthand, -0.06, -0.025, 0.15, -170.0, 20.0, -22.0, true, true, false, false, 1, true)
        Anim(ped,"script_story@ntv1@ig@ig_8","ig8_loop_p_peacepipe02",-1,30)
        Wait(9000)
        Anim(ped,"amb_rest@world_human_smoking@male_b@base","base",-1,31)
    
        while not IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@male_b@base","base", 3) do
            Wait(100)
        end
    
        if proppromptdisplayed == false then
            PromptSetEnabled(PropPrompt, true)
            PromptSetVisible(PropPrompt, true)
            PromptSetEnabled(UsePrompt, true)
            PromptSetVisible(UsePrompt, true)
            PromptSetEnabled(ChangeStance, true)
            PromptSetVisible(ChangeStance, true)
            proppromptdisplayed = true
        end
    
        while IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@male_b@base","base", 3) do
    
            Wait(5)
            if IsControlJustReleased(0, SmokesConfig.Keys.putAway) then
                PromptSetEnabled(PropPrompt, false)
                PromptSetVisible(PropPrompt, false)
                PromptSetEnabled(UsePrompt, false)
                PromptSetVisible(UsePrompt, false)
                PromptSetEnabled(ChangeStance, false)
                PromptSetVisible(ChangeStance, false)
                proppromptdisplayed = false
    
                Anim(ped, "amb_wander@code_human_smoking_wander@male_b@trans", "pipe_trans_nopipe", -1, 30)
                Wait(6066)
                DeleteEntity(pipe)
                ClearPedSecondaryTask(ped)
                ClearPedTasks(ped)
                Wait(10)
            end
            
            if IsControlJustReleased(0, SmokesConfig.Keys.stance) then
                Anim(ped, "amb_rest@world_human_smoking@pipe@proper@male_d@wip_base", "wip_base", -1, 30)
                Wait(5000)
                Anim(ped, "amb_rest@world_human_smoking@male_b@base","base", -1, 31)
                Wait(100)
            end
    
            if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                Wait(500)
                if IsControlPressed(0, SmokesConfig.Keys.use) then
                    Anim(ped, "amb_rest@world_human_smoking@male_b@idle_b","idle_d", -1, 30, 0)
                    Wait(15599)
                    Anim(ped, "amb_rest@world_human_smoking@male_b@base","base", -1, 31, 0)
                    Wait(100)
                else
                    Anim(ped, "amb_rest@world_human_smoking@male_b@idle_a","idle_a", -1, 30, 0)
                    Wait(22600)
                    Anim(ped, "amb_rest@world_human_smoking@male_b@base","base", -1, 31, 0)
                    Wait(100)
                end
            end
        end
    
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)
        proppromptdisplayed = false
    
        DetachEntity(pipe, true, true)
        ClearPedSecondaryTask(ped)
        RemoveAnimDict("amb_wander@code_human_smoking_wander@male_b@trans")
        RemoveAnimDict("amb_rest@world_human_smoking@male_b@base")
        RemoveAnimDict("amb_rest@world_human_smoking@pipe@proper@male_d@wip_base")
        RemoveAnimDict("amb_rest@world_human_smoking@male_b@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@male_b@idle_b")
        Wait(100)
        ClearPedTasks(ped)
        applySmokeBuffs(high,hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk)
    elseif typeof == "chew" then
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)

        FPrompt(SmokesLocale.finish, SmokesConfig.Keys.putAway, false)
        LMPrompt(SmokesLocale.doSomething, SmokesConfig.Keys.use, false)
        EPrompt(SmokesLocale.changeStance, SmokesConfig.Keys.stance, false)
        local ped = PlayerPedId()
        local x,y,z = table.unpack(GetEntityCoords(ped, true))
        local righthand = GetEntityBoneIndexByName(ped, "SKEL_R_Finger13")
    
        local basedict = "amb_misc@world_human_chew_tobacco@male_a@base"
        local basedictB = "amb_misc@world_human_chew_tobacco@male_b@base"
        local MaleA =
            { 
                [1] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_a", ['anim'] = "idle_a"},
                [2] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_a", ['anim'] = "idle_b"},
                [3] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_a", ['anim'] = "idle_c"},
                [4] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_b", ['anim'] = "idle_d"},
                [5] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_b", ['anim'] = "idle_e"},
                [6] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_b", ['anim'] = "idle_f"},
                [7] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_c", ['anim'] = "idle_g"},
                [8] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_c", ['anim'] = "idle_h"},
                [9] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_c", ['anim'] = "idle_i"},
                [7] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_d", ['anim'] = "idle_j"},
                [8] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_d", ['anim'] = "idle_k"},
                [9] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_a@idle_d", ['anim'] = "idle_l"}
            }
        local MaleB =
            { 
                [1] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_a", ['anim'] = "idle_a"},
                [2] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_a", ['anim'] = "idle_b"},
                [3] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_a", ['anim'] = "idle_c"},
                [4] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_b", ['anim'] = "idle_d"},
                [5] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_b", ['anim'] = "idle_e"},
                [6] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_b", ['anim'] = "idle_f"},
                [7] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_c", ['anim'] = "idle_g"},
                [8] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_c", ['anim'] = "idle_h"},
                [9] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_c", ['anim'] = "idle_i"},
                [7] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_d", ['anim'] = "idle_j"},
                [8] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_d", ['anim'] = "idle_k"},
                [9] = { ['dict'] = "amb_misc@world_human_chew_tobacco@male_b@idle_d", ['anim'] = "idle_l"}
            }
        local stance = "MaleA"
    
        RequestAnimDict("amb_misc@world_human_chew_tobacco@male_a@idle_a")
        RequestAnimDict("amb_misc@world_human_chew_tobacco@male_a@idle_b")
        RequestAnimDict("amb_misc@world_human_chew_tobacco@male_a@idle_c")
        RequestAnimDict("amb_misc@world_human_chew_tobacco@male_a@idle_d")
        RequestAnimDict("amb_misc@world_human_chew_tobacco@male_b@idle_a")
        RequestAnimDict("amb_misc@world_human_chew_tobacco@male_b@idle_b")
        RequestAnimDict("amb_misc@world_human_chew_tobacco@male_b@idle_c")
        RequestAnimDict("amb_misc@world_human_chew_tobacco@male_b@idle_d")
    
        Anim(ped,"amb_misc@world_human_chew_tobacco@male_a@stand_enter","enter_back",-1,30)
        Wait(2500)
        local chewingtobacco = CreateObject(GetHashKey('S_TOBACCOTIN01X'), x, y, z + 0.2, true, true, true)
        Wait(10)
        AttachEntityToEntity(chewingtobacco, ped, righthand, 0.0, -0.05, 0.02,  30.0, 180.0, 0.0, true, true, false, true, 1, true)
        Wait(6000)
        DeleteEntity(chewingtobacco)
        Wait(3500)
        Anim(ped,basedict,"base",-1,31, 0)
        
        while not IsEntityPlayingAnim(ped,basedict,"base", 3) do
            Wait(100)
        end
    
        if proppromptdisplayed == false then
            PromptSetEnabled(PropPrompt, true)
            PromptSetVisible(PropPrompt, true)
            PromptSetEnabled(UsePrompt, true)
            PromptSetVisible(UsePrompt, true)
            PromptSetEnabled(ChangeStance, true)
            PromptSetVisible(ChangeStance, true)
            proppromptdisplayed = true
        end
    
        while IsEntityPlayingAnim(ped, basedict,"base", 3) or IsEntityPlayingAnim(ped, basedictB,"base", 3) do
    
            Wait(5)
            if IsControlJustReleased(0, SmokesConfig.Keys.putAway) then
                PromptSetEnabled(PropPrompt, false)
                PromptSetVisible(PropPrompt, false)
                PromptSetEnabled(UsePrompt, false)
                PromptSetVisible(UsePrompt, false)
                PromptSetEnabled(ChangeStance, false)
                PromptSetVisible(ChangeStance, false)
                proppromptdisplayed = false
    
                Anim(ped, "amb_misc@world_human_chew_tobacco@male_b@idle_b", "idle_d", 5500, 30)
                Wait(5500)
                ClearPedSecondaryTask(ped)
                ClearPedTasks(ped)
                Wait(10)
            end
            
            if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                local random = math.random(1,9)
                if stance == "MaleA" then
                    randomdict = MaleA[random]['dict']
                    randomanim = MaleA[random]['anim']
                else
                    randomdict = MaleB[random]['dict']
                    randomanim = MaleB[random]['anim']
                end
                animduration = GetAnimDuration(randomdict, randomanim)*1000
                Wait(100)
                PromptSetEnabled(PropPrompt, false)
                PromptSetVisible(PropPrompt, false)
                PromptSetEnabled(UsePrompt, false)
                PromptSetVisible(UsePrompt, false)
                PromptSetEnabled(ChangeStance, false)
                PromptSetVisible(ChangeStance, false)
                Anim(ped, randomdict, randomanim, -1, 30, 0)
                Wait(animduration)
                if stance == "MaleA" then
                    Anim(ped, basedict,"base", -1, 31, 0)
                else
                    Anim(ped, basedictB,"base", -1, 31, 0)
                end
                PromptSetEnabled(PropPrompt, true)
                PromptSetVisible(PropPrompt, true)
                PromptSetEnabled(UsePrompt, true)
                PromptSetVisible(UsePrompt, true)
                PromptSetEnabled(ChangeStance, true)
                PromptSetVisible(ChangeStance, true)
                Wait(100)
            end
    
            if IsControlJustReleased(0, SmokesConfig.Keys.stance) then
                if stance=="MaleA" then
                    Anim(ped, "amb_misc@world_human_chew_tobacco@male_a@trans", "a_trans_b", -1, 30)
                    PromptSetEnabled(PropPrompt, false)
                    PromptSetVisible(PropPrompt, false)
                    PromptSetEnabled(UsePrompt, false)
                    PromptSetVisible(UsePrompt, false)
                    PromptSetEnabled(ChangeStance, false)
                    PromptSetVisible(ChangeStance, false)
                    Wait(7333)
                    Anim(ped, basedictB, "base", -1, 30, 0)
                    while not IsEntityPlayingAnim(ped,basedictB, "base", 3) do
                        Wait(100)
                    end    
                    PromptSetEnabled(PropPrompt, true)
                    PromptSetVisible(PropPrompt, true)
                    PromptSetEnabled(UsePrompt, true)
                    PromptSetVisible(UsePrompt, true)
                    PromptSetEnabled(ChangeStance, true)
                    PromptSetVisible(ChangeStance, true)
                    stance="MaleB"
                else
                    Anim(ped, "amb_misc@world_human_chew_tobacco@male_b@trans", "b_trans_a", -1, 30)
                    PromptSetEnabled(PropPrompt, false)
                    PromptSetVisible(PropPrompt, false)
                    PromptSetEnabled(UsePrompt, false)
                    PromptSetVisible(UsePrompt, false)
                    PromptSetEnabled(ChangeStance, false)
                    PromptSetVisible(ChangeStance, false)
                    Wait(5833)
                    Anim(ped, basedict, "base", -1, 30, 0)
                    while not IsEntityPlayingAnim(ped,basedict,"base", 3) do
                        Wait(100)
                    end
                    PromptSetEnabled(PropPrompt, true)
                    PromptSetVisible(PropPrompt, true)
                    PromptSetEnabled(UsePrompt, true)
                    PromptSetVisible(UsePrompt, true)
                    PromptSetEnabled(ChangeStance, true)
                    PromptSetVisible(ChangeStance, true)
                    stance="MaleA"
                end
            end
    
        end
    
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)
        proppromptdisplayed = false
    
        DetachEntity(chewingtobacco, true, true)
        ClearPedSecondaryTask(ped)
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_a@stand_enter")
        RemoveAnimDict(base)
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_a@idle_a")
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_a@idle_b")
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_a@idle_c")
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_a@idle_d")
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_b@idle_a")
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_b@idle_b")
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_b@idle_c")
        RemoveAnimDict("amb_misc@world_human_chew_tobacco@male_b@idle_d")
        Wait(100)
        ClearPedTasks(ped)
        applySmokeBuffs(high,hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk)
    elseif typeof == "cigarette" then
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)

        FPrompt(SmokesLocale.finishSmoking, SmokesConfig.Keys.putAway, false)
        LMPrompt(SmokesLocale.inhale, SmokesConfig.Keys.use, false)
        EPrompt(SmokesLocale.changeStance, SmokesConfig.Keys.stance, false)
        ExecuteCommand('close')
        local ped = PlayerPedId()
        local male = IsPedMale(ped)
        local x,y,z = table.unpack(GetEntityCoords(ped, true))
        local cigarette = CreateObject(GetHashKey('P_CIGARETTE01X'), x, y, z + 0.2, true, true, true)
        local righthand = GetEntityBoneIndexByName(ped, "SKEL_R_Finger13")
        local mouth = GetEntityBoneIndexByName(ped, "skel_head")
        
        if male then
            AttachEntityToEntity(cigarette, ped, mouth, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            Anim(ped,"amb_rest@world_human_smoking@male_c@stand_enter","enter_back_rf",9400,0)
            Wait(1000)
            AttachEntityToEntity(cigarette, ped, righthand, 0.03, -0.01, 0.0, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
            Wait(1000)
            AttachEntityToEntity(cigarette, ped, mouth, -0.017, 0.1, -0.01, 0.0, 90.0, -90.0, true, true, false, true, 1, true)
            Wait(3000)
            AttachEntityToEntity(cigarette, ped, righthand, 0.017, -0.01, -0.01, 0.0, 120.0, 10.0, true, true, false, true, 1, true)
            Wait(1000)
            Anim(ped,"amb_rest@world_human_smoking@male_c@base","base",-1,30)
            RemoveAnimDict("amb_rest@world_human_smoking@male_c@stand_enter")
            Wait(1000)
        else 
            AttachEntityToEntity(cigarette, ped, mouth, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            Anim(ped,"amb_rest@world_human_smoking@female_c@base","base",-1,30)
            Wait(1000)
            AttachEntityToEntity(cigarette, ped, righthand, 0.01, 0.0, 0.01, 0.0, -160.0, -130.0, true, true, false, true, 1, true)
            Wait(2500)
        end
    
        local stance="c"
    
        if proppromptdisplayed == false then
            PromptSetEnabled(PropPrompt, true)
            PromptSetVisible(PropPrompt, true)
            PromptSetEnabled(UsePrompt, true)
            PromptSetVisible(UsePrompt, true)
            PromptSetEnabled(ChangeStance, true)
            PromptSetVisible(ChangeStance, true)
            proppromptdisplayed = true
        end
    
        if male then
            while  IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@male_c@base","base", 3)
                or IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@base","base", 3)
                or IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@male_d@base","base", 3)
                or IsEntityPlayingAnim(ped, "amb_wander@code_human_smoking_wander@male_a@base","base", 3) do
    
                Wait(5)
                if IsControlJustReleased(0, SmokesConfig.Keys.putAway) then
                    PromptSetEnabled(PropPrompt, false)
                    PromptSetVisible(PropPrompt, false)
                    PromptSetEnabled(UsePrompt, false)
                    PromptSetVisible(UsePrompt, false)
                    PromptSetEnabled(ChangeStance, false)
                    PromptSetVisible(ChangeStance, false)
                    proppromptdisplayed = false
    
                    ClearPedSecondaryTask(ped)
                    Anim(ped, "amb_rest@world_human_smoking@male_a@stand_exit", "exit_back", -1, 1)
                    Wait(2800)
                    DetachEntity(cigarette, true, true)
                    SetEntityVelocity(cigarette, 0.0,0.0,-1.0)
                    Wait(1500)
                    ClearPedSecondaryTask(ped)
                    ClearPedTasks(ped)
                    Wait(10)
                end
                if IsControlJustReleased(0, SmokesConfig.Keys.stance) then
                    if stance=="c" then
                        Anim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@base", "base", -1, 30)
                        Wait(1000)
                        while not IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@nervous_stressed@male_b@base", "base", 3) do
                            Wait(100)
                        end    
                        stance="b"
                    elseif stance=="b" then
                        Anim(ped, "amb_rest@world_human_smoking@male_d@base", "base", -1, 30)
                        Wait(1000)
                        while not IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@male_d@base","base", 3) do
                            Wait(100)
                        end
                        stance="d"
                    elseif stance=="d" then
                        Anim(ped, "amb_rest@world_human_smoking@male_d@trans", "d_trans_a", -1, 30)
                        Wait(4000)
                        Anim(ped, "amb_wander@code_human_smoking_wander@male_a@base", "base", -1, 30, 0)
                        while not IsEntityPlayingAnim(ped,"amb_wander@code_human_smoking_wander@male_a@base","base", 3) do
                            Wait(100)
                        end
                        stance="a"
                    else 
                        Anim(ped, "amb_rest@world_human_smoking@male_a@trans", "a_trans_c", -1, 30)
                        Wait(4233)
                        Anim(ped,"amb_rest@world_human_smoking@male_c@base","base",-1,30,0)
                        while not IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@male_c@base","base", 3) do
                            Wait(100)
                        end
                        stance="c"
                    end
                end
            
                if stance=="c" then
                    if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                        Wait(500)
                        if IsControlPressed(0, SmokesConfig.Keys.use) then
                            Anim(ped, "amb_rest@world_human_smoking@male_c@idle_a","idle_b", -1, 30, 0)
                            Wait(21166)
                            Anim(ped, "amb_rest@world_human_smoking@male_c@base","base", -1, 30, 0)
                            Wait(100)
                        else
                            Anim(ped, "amb_rest@world_human_smoking@male_c@idle_a","idle_a", -1, 30, 0)
                            Wait(8500)
                            Anim(ped, "amb_rest@world_human_smoking@male_c@base","base", -1, 30, 0)
                            Wait(100)
                        end
                    end
                elseif stance=="b" then
                    if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                        Wait(500)
                        if IsControlPressed(0, SmokesConfig.Keys.use) then
                            Anim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@idle_c","idle_g", -1, 30, 0)
                            Wait(13433)
                            Anim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@base", "base", -1, 30, 0)
                            Wait(100)
                        else
                            Anim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@idle_a", "idle_a", -1, 30, 0)
                            Wait(3199)
                            Anim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@base", "base", -1, 30, 0)
                            Wait(100)
                        end
                    end
                elseif stance=="d" then
                    if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                        Wait(500)
                        if IsControlPressed(0, SmokesConfig.Keys.use) then
                            Anim(ped, "amb_rest@world_human_smoking@male_d@idle_a","idle_b", -1, 30, 0)
                            Wait(7366)
                            Anim(ped, "amb_rest@world_human_smoking@male_d@base", "base", -1, 30, 0)
                            Wait(100)
                        else
                            Anim(ped, "amb_rest@world_human_smoking@male_d@idle_c", "idle_g", -1, 30, 0)
                            Wait(7866)
                            Anim(ped, "amb_rest@world_human_smoking@male_d@base", "base", -1, 30, 0)
                            Wait(100)
                        end
                    end
                else 
                    if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                        Wait(500)
                        if IsControlPressed(0, SmokesConfig.Keys.use) then
                            Anim(ped, "amb_rest@world_human_smoking@male_a@idle_a", "idle_b", -1, 30, 0)
                            Wait(12533)
                            Anim(ped, "amb_wander@code_human_smoking_wander@male_a@base", "base", -1, 30, 0)
                            Wait(100)
                        else
                            Anim(ped, "amb_rest@world_human_smoking@male_a@idle_a","idle_a", -1, 30, 0)
                            Wait(8200)
                            Anim(ped, "amb_wander@code_human_smoking_wander@male_a@base", "base", -1, 30, 0)
                            Wait(100)
                        end
                    end
                end
            end
        else 
            while  IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@female_c@base", "base", 3) 
                or IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@female_b@base", "base", 3)
                or IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@female_a@base", "base", 3)do
    
                Wait(5)
                if IsControlJustReleased(0, SmokesConfig.Keys.putAway) then
                    PromptSetEnabled(PropPrompt, false)
                    PromptSetVisible(PropPrompt, false)
                    PromptSetEnabled(UsePrompt, false)
                    PromptSetVisible(UsePrompt, false)
                    PromptSetEnabled(ChangeStance, false)
                    PromptSetVisible(ChangeStance, false)
                    proppromptdisplayed = false
    
                    ClearPedSecondaryTask(ped)
                    Anim(ped, "amb_rest@world_human_smoking@female_b@trans", "b_trans_fire_stand_a", -1, 1)
                    Wait(3800)
                    DetachEntity(cigarette, true, true)
                    Wait(800)
                    ClearPedSecondaryTask(ped)
                    ClearPedTasks(ped)
                    Wait(10)
                end
                if IsControlJustReleased(0, SmokesConfig.Keys.stance) then
                    if stance=="c" then
                        Anim(ped, "amb_rest@world_human_smoking@female_b@base", "base", -1, 30)
                        Wait(1000)
                        while not IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@female_b@base", "base", 3) do
                            Wait(100)
                        end    
                        stance="b"
                    elseif stance=="b" then
                        Anim(ped, "amb_rest@world_human_smoking@female_b@trans", "b_trans_a", -1, 30)
                        Wait(5733)
                        Anim(ped, "amb_rest@world_human_smoking@female_a@base", "base", -1, 30, 0)
                        while not IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@female_a@base","base", 3) do
                            Wait(100)
                        end
                        stance="a"
                    else 
                        Anim(ped,"amb_rest@world_human_smoking@female_c@base","base",-1,30)
                        Wait(1000)
                        while not IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@female_c@base","base", 3) do
                            Wait(100)
                        end
                        stance="c"
                    end
                end
            
                if stance=="c" then
                    if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                        Wait(500)
                        if IsControlPressed(0, SmokesConfig.Keys.use) then
                            Anim(ped, "amb_rest@world_human_smoking@female_c@idle_a","idle_a", -1, 30, 0)
                            Wait(9566)
                            Anim(ped, "amb_rest@world_human_smoking@female_c@base","base", -1, 30, 0)
                            Wait(100)
                        else
                            Anim(ped, "amb_rest@world_human_smoking@female_c@idle_b","idle_f", -1, 30, 0)
                            Wait(8133)
                            Anim(ped, "amb_rest@world_human_smoking@female_c@base","base", -1, 30, 0)
                            Wait(100)
                        end
                    end
                elseif stance=="b" then
                    if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                        Wait(500)
                        if IsControlPressed(0, SmokesConfig.Keys.use) then
                            Anim(ped, "amb_rest@world_human_smoking@female_b@idle_b","idle_f", -1, 30, 0)
                            Wait(8033)
                            Anim(ped, "amb_rest@world_human_smoking@female_b@base", "base", -1, 30, 0)
                            Wait(100)
                        else
                            Anim(ped, "amb_rest@world_human_smoking@female_b@idle_a", "idle_b", -1, 30, 0)
                            Wait(4266)
                            Anim(ped, "amb_rest@world_human_smoking@female_b@base", "base", -1, 30, 0)
                            Wait(100)
                        end
                    end
                else 
                    if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                        Wait(500)
                        if IsControlPressed(0, SmokesConfig.Keys.use) then
                            Anim(ped, "amb_rest@world_human_smoking@female_a@idle_b", "idle_d", -1, 30, 0)
                            Wait(14566)
                            Anim(ped, "amb_rest@world_human_smoking@female_a@base", "base", -1, 30, 0)
                            Wait(100)
                        else
                            Anim(ped, "amb_rest@world_human_smoking@female_a@idle_a","idle_b", -1, 30, 0)
                            Wait(6100)
                            Anim(ped, "amb_rest@world_human_smoking@female_a@base", "base", -1, 30, 0)
                            Wait(100)
                        end
                    end
                end
            end
        end
    
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)
        proppromptdisplayed = false
    
        DetachEntity(cigarette, true, true)
        ClearPedSecondaryTask(ped)
        RemoveAnimDict("amb_wander@code_human_smoking_wander@male_a@base")
        RemoveAnimDict("amb_rest@world_human_smoking@male_a@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@nervous_stressed@male_b@base")
        RemoveAnimDict("amb_rest@world_human_smoking@nervous_stressed@male_b@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@nervous_stressed@male_b@idle_g")
        RemoveAnimDict("amb_rest@world_human_smoking@male_c@base")
        RemoveAnimDict("amb_rest@world_human_smoking@male_c@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@male_d@base")
        RemoveAnimDict("amb_rest@world_human_smoking@male_d@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@male_d@idle_c")
        RemoveAnimDict("amb_rest@world_human_smoking@male_a@trans")
        RemoveAnimDict("amb_rest@world_human_smoking@male_c@trans")
        RemoveAnimDict("amb_rest@world_human_smoking@male_d@trans")
        RemoveAnimDict("amb_rest@world_human_smoking@female_a@base")
        RemoveAnimDict("amb_rest@world_human_smoking@female_a@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@female_a@idle_b")
        RemoveAnimDict("amb_rest@world_human_smoking@female_b@base")
        RemoveAnimDict("amb_rest@world_human_smoking@female_b@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@female_b@idle_b")
        RemoveAnimDict("amb_rest@world_human_smoking@female_c@base")
        RemoveAnimDict("amb_rest@world_human_smoking@female_c@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@female_c@idle_b")
        RemoveAnimDict("amb_rest@world_human_smoking@female_b@trans")
        Wait(100)
        ClearPedTasks(ped)
        applySmokeBuffs(high,hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk)
    elseif typeof == "cigar" then
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)

        ExecuteCommand('close')
        FPrompt(SmokesLocale.stopSmoking, SmokesConfig.Keys.putAway, false)
        local prop_name = 'P_CIGAR01X'
        local ped = PlayerPedId()
        local dict = 'amb_rest@world_human_smoke_cigar@male_a@idle_b'
        local anim = 'idle_d'
        local x,y,z = table.unpack(GetEntityCoords(ped, true))
        local prop = CreateObject(GetHashKey(prop_name), x, y, z + 0.2, true, true, true)
        local boneIndex = GetEntityBoneIndexByName(ped, 'SKEL_R_Finger12')
        local smoking = false
        
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
            AttachEntityToEntity(prop, ped,boneIndex, 0.01, -0.00500, 0.01550, 0.024, 300.0, -40.0, true, true, false, true, 1, true)
            TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 31, 0, true, 0, false, 0, false)
            Wait(1000)

            if proppromptdisplayed == false then
	    	    PromptSetEnabled(PropPrompt, true)
	    	    PromptSetVisible(PropPrompt, true)
	    	    proppromptdisplayed = true
            end

            smoking = true
            while smoking do
                if IsEntityPlayingAnim(ped, dict, anim, 3) then

                    DisableControlAction(0, 0x07CE1E61, true)
                    DisableControlAction(0, 0xF84FA74F, true)
                    DisableControlAction(0, 0xCEE12B50, true)
                    DisableControlAction(0, 0xB2F377E8, true)
                    DisableControlAction(0, 0x8FFC75D6, true)
                    DisableControlAction(0, 0xD9D0E1C0, true)

                    if IsControlPressed(0, SmokesConfig.Keys.putAway) then
                        PromptSetEnabled(PropPrompt, false)
                        PromptSetVisible(PropPrompt, false)
                        proppromptdisplayed = false
                        smoking = false
                        ClearPedSecondaryTask(ped)
                        DeleteObject(prop)
                        RemoveAnimDict(dict)
                        break
                    end
                else
                    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 31, 0, true, 0, false, 0, false)
                end
                Wait(0)
            end
        end
        applySmokeBuffs(high,hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk)
    elseif typeof == "pipe" then
        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)

        FPrompt(SmokesLocale.putAway, SmokesConfig.Keys.putAway, false)
        LMPrompt(SmokesLocale.use, SmokesConfig.Keys.use, false)
        EPrompt(SmokesLocale.pose, SmokesConfig.Keys.stance, false)
        ExecuteCommand('close')
        local ped = PlayerPedId()
        local male = IsPedMale(ped)
        local x,y,z = table.unpack(GetEntityCoords(ped, true))
        local pipe = CreateObject(GetHashKey('P_PIPE01X'), x, y, z + 0.2, true, true, true)
        local righthand = GetEntityBoneIndexByName(ped, "SKEL_R_Finger13")
        AttachEntityToEntity(pipe, ped, righthand, 0.005, -0.045, 0.0, -170.0, 10.0, -15.0, true, true, false, true, 1, true)
        Anim(ped,"amb_wander@code_human_smoking_wander@male_b@trans","nopipe_trans_pipe",-1,30)
        Wait(9000)
        Anim(ped,"amb_rest@world_human_smoking@male_b@base","base",-1,31)
        PlaySoundFrontend("Core_Fill_Up", "Consumption_Sounds", true, 0)

        while not IsEntityPlayingAnim(ped,"amb_rest@world_human_smoking@male_b@base","base", 3) do
            Wait(100)
        end

        if proppromptdisplayed == false then
            PromptSetEnabled(PropPrompt, true)
            PromptSetVisible(PropPrompt, true)
            PromptSetEnabled(UsePrompt, true)
            PromptSetVisible(UsePrompt, true)
            PromptSetEnabled(ChangeStance, true)
            PromptSetVisible(ChangeStance, true)
            proppromptdisplayed = true
	    end

        while IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@male_b@base","base", 3) do

            Wait(5)
	    	if IsControlJustReleased(0, SmokesConfig.Keys.putAway) then
                PromptSetEnabled(PropPrompt, false)
                PromptSetVisible(PropPrompt, false)
                PromptSetEnabled(UsePrompt, false)
                PromptSetVisible(UsePrompt, false)
                PromptSetEnabled(ChangeStance, false)
                PromptSetVisible(ChangeStance, false)
                proppromptdisplayed = false

                Anim(ped, "amb_wander@code_human_smoking_wander@male_b@trans", "pipe_trans_nopipe", -1, 30)
                Wait(6066)
                DeleteEntity(pipe)
                ClearPedSecondaryTask(ped)
                ClearPedTasks(ped)
                Wait(10)
	    	end

            if IsControlJustReleased(0, SmokesConfig.Keys.stance) then
                Anim(ped, "amb_rest@world_human_smoking@pipe@proper@male_d@wip_base", "wip_base", -1, 30)
                Wait(5000)
                Anim(ped, "amb_rest@world_human_smoking@male_b@base","base", -1, 31)
                Wait(100)
            end

            if IsControlJustReleased(0, SmokesConfig.Keys.use) then
                Wait(500)
                if IsControlPressed(0, SmokesConfig.Keys.use) then
                    Anim(ped, "amb_rest@world_human_smoking@male_b@idle_b","idle_d", -1, 30, 0)
                    Wait(15599)
                    Anim(ped, "amb_rest@world_human_smoking@male_b@base","base", -1, 31, 0)
                    Wait(100)
                else
                    Anim(ped, "amb_rest@world_human_smoking@male_b@idle_a","idle_a", -1, 30, 0)
                    Wait(22600)
                    Anim(ped, "amb_rest@world_human_smoking@male_b@base","base", -1, 31, 0)
                    Wait(100)
                end
            end
        end

        PromptSetEnabled(PropPrompt, false)
        PromptSetVisible(PropPrompt, false)
        PromptSetEnabled(UsePrompt, false)
        PromptSetVisible(UsePrompt, false)
        PromptSetEnabled(ChangeStance, false)
        PromptSetVisible(ChangeStance, false)
        proppromptdisplayed = false

        DetachEntity(pipe, true, true)
        ClearPedSecondaryTask(ped)
        RemoveAnimDict("amb_wander@code_human_smoking_wander@male_b@trans")
        RemoveAnimDict("amb_rest@world_human_smoking@male_b@base")
        RemoveAnimDict("amb_rest@world_human_smoking@pipe@proper@male_d@wip_base")
        RemoveAnimDict("amb_rest@world_human_smoking@male_b@idle_a")
        RemoveAnimDict("amb_rest@world_human_smoking@male_b@idle_b")
        Wait(100)
        ClearPedTasks(ped)
        applySmokeBuffs(high,hightype,highduration,hboost,sboost,damount,dscreen,turbo,filters,drunkwalk)
    end
end

-- One smoke at a time. pupSmoking tells the server, which refuses the next one before taking the item.
local smokingSince = nil
local function setSmoking(on)
    smokingSince = on and GetGameTimer() or nil
    LocalPlayer.state:set('pupSmoking', on == true, true)
end
setSmoking(false) -- a restart mid-smoke leaves it set

AddEventHandler('pup-smoke:inhale', function(...)
    if smokingSince then return end
    setSmoking(true)
    local ok, err = pcall(runInhale, ...)
    setSmoking(false)
    if not ok then print('^1[pup-misc/smokes]^7 ' .. tostring(err)) end
end)

-- runInhale waits on animations that can never start, for a ped that died or was replaced. That must not
-- stop this player smoking for the rest of the session. Lighting up takes under 15 s before the prompts show.
Citizen.CreateThread(function()
    local quiet = 0
    while true do
        Wait(5000)
        if smokingSince then
            quiet = proppromptdisplayed and 0 or quiet + 5
            if quiet >= 45 or IsEntityDead(PlayerPedId()) or GetGameTimer() - smokingSince > 1800000 then
                quiet = 0
                setSmoking(false)
            end
        else
            quiet = 0
        end
    end
end)