-- swing minigame: pup-minigames skill_bar (callback-based), true on success/perfect
function TaskBarMinigame(kind)
    local t = (type(Config) == 'table' and type(Config.MinigameTuning) == 'table') and Config.MinigameTuning or {}
    local icons = type(t.icons) == 'table' and t.icons or {}

    local p = promise.new()
    exports['pup-minigames']:skill_bar({
        style = 'default',
        icon = icons[kind], -- nil falls back to the bar's default crosshair
        orientation = 1,
        area_size = t.area or 20,
        perfect_area_size = t.perfectArea or 6,
        speed = t.speed or 0.75,
        moving_icon = false,
        end_delay = t.endDelay or 400,
    }, function(result)
        p:resolve(result == 'success' or result == 'perfect')
    end)
    return Citizen.Await(p)
end
local thetype 
local itemused 
local durability
local itemobject
local newdura 
local itemmetadata

local prompts = GetRandomIntInRange(0, 0xffffff)
local prompts2 = GetRandomIntInRange(0, 0xffffff)
local startkey 
local stopkey
local swingkey
local started = false 

local gathered = {}
local gatheredcoords = {}
local gatherCounts = {} -- Track how many times each location has been gathered
local locationCooldowns = {} -- Track cooldown timers for each location
local locationAvailableLogged = {} -- Track which locations have been logged as available
local locationLimits = {} -- Track randomized gather limits for each location
local swingcount
local swings = 0

-- which of the TWO gather paths this session started on
local gathermode

Citizen.CreateThread(function()
    local str = language.gather
	startkey = PromptRegisterBegin()
	PromptSetControlAction(startkey, Config.Keys.start)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(startkey, str)
	PromptSetEnabled(startkey, 1)
    PromptSetVisible(startkey, 1)
	PromptSetStandardMode(startkey,1)
    PromptSetHoldMode(startkey, true)
	PromptSetGroup(startkey, prompts)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,startkey,true)
	PromptRegisterEnd(startkey)

    local str = language.swing
	swingkey = PromptRegisterBegin()
	PromptSetControlAction(swingkey, Config.Keys.swing)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(swingkey, str)
	PromptSetEnabled(swingkey, 1)
    PromptSetVisible(swingkey, 1)
	PromptSetStandardMode(swingkey,1)
	PromptSetGroup(swingkey, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,swingkey,true)
	PromptRegisterEnd(swingkey)

    local str = language.stop
	stopkey = PromptRegisterBegin()
	PromptSetControlAction(stopkey, Config.Keys.stop)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(stopkey, str)
	PromptSetEnabled(stopkey, 1)
    PromptSetVisible(stopkey, 1)
	PromptSetStandardMode(stopkey,1)
	PromptSetGroup(stopkey, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,stopkey,true)
	PromptRegisterEnd(stopkey)


end)


RegisterNetEvent("pup_miner_lumber:itemused")
AddEventHandler("pup_miner_lumber:itemused", function(item, iteminfo, dura,idx)
    if Config.Debug then print("^2[DEBUG] Item used event triggered - Item: " .. tostring(item) .. ", Type: " .. tostring(iteminfo.type) .. ", Durability: " .. tostring(dura) .. "^7") end
    if itemused ~= nil and item ~= itemused then 
        if Config.Debug then print("^1[DEBUG] Item already in use, unequipping^7") end
        TriggerEvent("vorp:TipRight", language.unequip, 3000)
        return
    end
    TriggerEvent("vorp_inventory:CloseInv")
    if itemobject == nil then 
        if Config.Debug then print("^2[DEBUG] Equipping item - Type: " .. tostring(iteminfo.type) .. "^7") end
        -- the satchel stays usable; the server unequips the tool if it leaves the satchel
        thetype = iteminfo.type
        itemused = item
        itemmetadata = idx
        durability = dura
        newdura = dura
        local pc = GetEntityCoords(PlayerPedId())
        local model
        local boneIndex
        local Attach
        if thetype == "mining" then
            model = GetHashKey("p_pickaxe01x")
        elseif thetype == "lumber" then
            model = GetHashKey("p_axe02x")
        end
        if IsPedMale(PlayerPedId()) then 
            boneIndex = 337
            Attach = {0.06, -0.2, -0.03, -90.0, -6.0, 0.0}
        else
            boneIndex = 396
            Attach = {0.06, -0.22, -0.03, -90.0, -10.0, 0.0}
        end
        if Config.Debug then print("^2[DEBUG] Requesting model for type: " .. tostring(thetype) .. "^7") end
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(10)
        end
        if Config.Debug then print("^2[DEBUG] Model loaded, creating object^7") end
        itemobject = CreateObject(model, pc.x, pc.y, pc.z, true, true, true)
        AttachEntityToEntity(itemobject, PlayerPedId(), boneIndex, Attach[1], Attach[2], Attach[3], Attach[4], Attach[5], Attach[6], true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
        if not HasAnimDictLoaded("amb_rest_sit@prop_human_seat_bench@parasol@female_a@wip_base") then 
            RequestAnimDict("amb_rest_sit@prop_human_seat_bench@parasol@female_a@wip_base")
            while not HasAnimDictLoaded("amb_rest_sit@prop_human_seat_bench@parasol@female_a@wip_base") do 
                Citizen.Wait(1)
            end
        end
        TaskPlayAnim(PlayerPedId(), "amb_rest_sit@prop_human_seat_bench@parasol@female_a@wip_base", "wip_base", 5.0, 5.0, -1, 31, 0)
    else
        if Config.Debug then print("^2[DEBUG] Unequipping item^7") end
        DeleteEntity(itemobject)
        itemobject = nil
        ClearPedTasks(PlayerPedId())
        FreezeEntityPosition(PlayerPedId(),false)
        Citizen.InvokeNative(0x58F7DB5BD8FA2288, PlayerPedId())
        itemused = nil
    end
end)

-- the equipped tool was given away, dropped or sold: put it away
RegisterNetEvent("pup_miner_lumber:forceunequip")
AddEventHandler("pup_miner_lumber:forceunequip", function(item)
    if itemobject == nil or (item and itemused and item ~= itemused) then return end
    DeleteEntity(itemobject)
    itemobject = nil
    itemused = nil
    started = false
    ClearPedTasks(PlayerPedId())
    FreezeEntityPosition(PlayerPedId(), false)
    Citizen.InvokeNative(0x58F7DB5BD8FA2288, PlayerPedId())
end)

function returnattach()
    local boneIndex
    local Attach

    if IsPedMale(PlayerPedId()) then 
        boneIndex = 337
        Attach = {0.06, -0.2, -0.03, -90.0, -6.0, 0.0}
    else
        boneIndex = 396
        Attach = {0.06, -0.22, -0.03, -90.0, -10.0, 0.0}
    end
    Citizen.InvokeNative(0x58F7DB5BD8FA2288, PlayerPedId())
    AttachEntityToEntity(itemobject, PlayerPedId(), boneIndex, Attach[1], Attach[2], Attach[3], Attach[4], Attach[5], Attach[6], true, true, false, true, 1, true)

end

function attachtomine()
    if Config.Debug then print("^2[DEBUG] Attaching to mine/lumber gathering position^7") end
    Citizen.InvokeNative(0x58F7DB5BD8FA2288, PlayerPedId())
    ClearPedTasks(PlayerPedId())            
    Citizen.InvokeNative(0xED00D72F81CF7278, itemobject, 1, 1)
    local boneIndex = GetPedBoneIndex(PlayerPedId(), 7966)
    local Attach = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
    AttachEntityToEntity(itemobject, PlayerPedId(), boneIndex, Attach[1], Attach[2], Attach[3], Attach[4], Attach[5], Attach[6], true, true, false, true, 1, true)
    Citizen.InvokeNative(0x923583741DC87BCE, PlayerPedId(), 'arthur_healthy')
    Citizen.InvokeNative(0x89F5E7ADECCCB49C, PlayerPedId(), "carry_pitchfork")
    Citizen.InvokeNative(0x2208438012482A1A, PlayerPedId(), true, true)
    Citizen.InvokeNative(0x3A50753042B6891B, PlayerPedId(), "PITCH_FORKS")
    ForceEntityAiAndAnimationUpdate(itemobject, 1)
end

Citizen.CreateThread(function()
	while true do
        Wait(1)
        local sleep = true 
        if itemobject ~= nil and not started then
            sleep = false  
            if not IsEntityPlayingAnim(PlayerPedId(), "amb_rest_sit@prop_human_seat_bench@parasol@female_a@wip_base","wip_base", 3) then 
                TaskPlayAnim(PlayerPedId(), "amb_rest_sit@prop_human_seat_bench@parasol@female_a@wip_base", "wip_base", 5.0, 5.0, -1, 31, 0)
            end
        end
        if sleep then 
            Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local sleep = true
        local playerped = PlayerPedId()
        if itemobject ~= nil and not IsPedOnMount(playerped) and not IsPedInAnyVehicle(playerped) and not IsPedDeadOrDying(playerped) then
            local coords = GetEntityCoords(playerped)
            local x, y, z = table.unpack(GetEntityCoords(PlayerPedId()))
            for k,v in pairs(Config.Props[thetype]) do
                local prop = DoesObjectOfTypeExistAtCoords(x, y, z, 1.0, GetHashKey(v), true)
                if prop and not InArray(gathered, tostring(v)) then
                    sleep = false
                    if not started then 
                        local label  = CreateVarString(10, 'LITERAL_STRING', language[thetype])
				        PromptSetActiveGroupThisFrame(prompts, label)
                        if PromptHasHoldModeCompleted(startkey) then
                            if Config.Debug then print("^3[DEBUG] Starting gather on object^7") end
                            attachtomine()
                            table.insert(gathered, tostring(v))
                            swings = 0
                            SetCurrentPedWeapon(playerped, GetHashKey("WEAPON_UNARMED"), true, 0, false, false)
                            swingcount = math.random(Config.Swings.min, Config.Swings.max)
                            if Config.Debug then print("^3[DEBUG] Swings needed: " .. tostring(swingcount) .. "^7") end
                            FreezeEntityPosition(PlayerPedId(), true)
                            started = true
                            gathermode = 'object'
                            TriggerEvent("pup_miner_lumber:removeprop",tostring(v))
                        end
                    end
                end
            end
            for k,v in pairs(Config.Nodes[thetype]) do
                local dist = GetDistanceBetweenCoords(v.x,v.y,v.z, coords.x,coords.y,coords.z, true)
                local detectionRadius = v.radius or Config.NodeDefaults.radius
                
                if detectionRadius >= dist then 
                    -- gather limit: the spot's own, else random from NodeDefaults.limit
                    if locationLimits[tostring(k)] == nil then
                        if v.limit ~= nil then
                            locationLimits[tostring(k)] = v.limit
                        else
                            local lim = Config.NodeDefaults.limit
                            locationLimits[tostring(k)] = math.random(lim.min, lim.max)
                        end
                    end
                    
                    -- Check if location is in cooldown
                    local isOnCooldown = locationCooldowns[tostring(k)] ~= nil and locationCooldowns[tostring(k)] > GetGameTimer()
                    
                    -- Initialize gather count if not exists
                    if gatherCounts[tostring(k)] == nil then
                        gatherCounts[tostring(k)] = 0
                    end
                    
                    -- Check if location has reached gather limit
                    local gatherLimit = locationLimits[tostring(k)]
                    local hasReachedLimit = gatherCounts[tostring(k)] >= gatherLimit
                    
                    if not isOnCooldown and not hasReachedLimit and not InArray(gatheredcoords, k) and not started then
                        if not locationAvailableLogged[tostring(k)] then
                            if Config.Debug then print("^3[DEBUG] Location available - ID=" .. tostring(k) .. " Gathers: " .. tostring(gatherCounts[tostring(k)]) .. "/" .. tostring(gatherLimit or "∞") .. "^7") end
                            locationAvailableLogged[tostring(k)] = true
                        end
                        sleep = false 
                        local label  = CreateVarString(10, 'LITERAL_STRING', language[thetype])
				        PromptSetActiveGroupThisFrame(prompts, label)
                        if PromptHasHoldModeCompleted(startkey) then
                            if Config.Debug then print("^3[DEBUG] Starting gather at location ID=" .. tostring(k) .. "^7") end
                            attachtomine()
                            table.insert(gatheredcoords, k)
                            -- Increment gather count
                            gatherCounts[tostring(k)] = gatherCounts[tostring(k)] + 1
                            
                            swings = 0
                            SetCurrentPedWeapon(playerped, GetHashKey("WEAPON_UNARMED"), true, 0, false, false)
                            swingcount = math.random(Config.Swings.min, Config.Swings.max)
                            if Config.Debug then print("^3[DEBUG] Swings needed: " .. tostring(swingcount) .. "^7") end
                            FreezeEntityPosition(PlayerPedId(), true)
                            started = true
                            gathermode = 'location'

                            -- Check if limit has been reached after increment
                            if gatherCounts[tostring(k)] >= gatherLimit then
                                local cooldown = v.cooldown or Config.NodeDefaults.cooldown
                                if Config.Debug then print("^1[DEBUG] Location limit reached! Starting cooldown for " .. tostring(cooldown) .. "ms^7") end
                                TriggerEvent("pup_miner_lumber:startcooldown", k, cooldown)
                            else
                                if Config.Debug then print("^2[DEBUG] Gathers remaining: " .. tostring(gatherLimit - gatherCounts[tostring(k)]) .. "^7") end
                                TriggerEvent("pup_miner_lumber:removecoords",k)
                            end
                        end
                    elseif isOnCooldown and not started then
                        if Config.Debug then print("^1[DEBUG] Location on cooldown: ID=" .. tostring(k) .. "^7") end
                        sleep = false
                        local remainingTime = math.ceil((locationCooldowns[tostring(k)] - GetGameTimer()) / 1000)
                        local label = CreateVarString(10, 'LITERAL_STRING', "Cooldown: " .. remainingTime .. "s")
                        PromptSetActiveGroupThisFrame(prompts, label)
                    elseif hasReachedLimit and not isOnCooldown and not started then
                        if Config.Debug then print("^1[DEBUG] Location limit reached: ID=" .. tostring(k) .. "^7") end
                        sleep = false
                        local label = CreateVarString(10, 'LITERAL_STRING', "Limit reached!")
                        PromptSetActiveGroupThisFrame(prompts, label)
                    end
                end

            end
        end
        if sleep then
            Citizen.Wait(500)
        end
    end
end)


Citizen.CreateThread(function()
    while true do
        Wait(0)
        local sleep = true
        if started then 
            sleep = false 
            local label  = CreateVarString(10, 'LITERAL_STRING', language[thetype])
            PromptSetActiveGroupThisFrame(prompts2, label)
            if Citizen.InvokeNative(0xC92AC953F0A982AE,swingkey) then
                local tool = Config.Tools[itemused]
                swings = swings + 1
                if Config.Debug then print("^5[DEBUG] Swing #" .. tostring(swings) .. " of " .. tostring(swingcount) .. "^7") end
                ClearPedTasks(PlayerPedId())
                if thetype == "mining" then 
                    Anim(PlayerPedId(),'amb_work@world_human_pickaxe_new@working@male_a@trans','pre_swing_trans_after_swing',-1,0)
                else 
                    Anim(PlayerPedId(),"amb_work@world_human_tree_chop_new@working@pre_swing@male_a@trans","pre_swing_trans_after_swing",-1,0)
                end
                local testplayer = TaskBarMinigame(thetype)
                if testplayer then
                    if Config.Debug then print("^2[DEBUG] Perfect swing! Adding item^7") end
                    TriggerServerEvent('pup_miner_lumber:addItem',thetype,itemused,gathermode)
                else
                    if Config.Debug then print("^1[DEBUG] Swing failed - Score: " .. tostring(testplayer) .. "^7") end
                end
                newdura = newdura - tool.drain
                if Config.Debug then print("^4[DEBUG] Durability: " .. string.format("%.1f", newdura) .. " / " .. tostring(durability) .. "^7") end
                if 0 >= newdura then 
                    if Config.Debug then print("^1[DEBUG] Item broken!^7") end
                    Citizen.InvokeNative(0x58F7DB5BD8FA2288, PlayerPedId())
                    TriggerServerEvent('pup_miner_lumber:removeitem',itemused,itemmetadata)
                    DeleteEntity(itemobject)
                    itemobject = nil
                    itemused = nil
                    ClearPedTasks(PlayerPedId())            
                    started = false 
                    FreezeEntityPosition(PlayerPedId(),false)
                end
                local t = type(Config.MinigameTuning) == 'table' and Config.MinigameTuning or {}
                Wait(t.swingDelay or 150)
            end
            if swings == swingcount or Citizen.InvokeNative(0xC92AC953F0A982AE,stopkey) then
                if Config.Debug then print("^3[DEBUG] Gathering complete - Swings: " .. tostring(swings) .. ", Durability remaining: " .. string.format("%.1f", newdura) .. "^7") end
                returnattach()
                TriggerServerEvent('pup_miner_lumber:updateitem',itemused,newdura,itemmetadata)
                FreezeEntityPosition(PlayerPedId(),false)
                started = false 
            end
        end
        if sleep then
            Wait(500)
        end
    end
end)

RegisterNetEvent("pup_miner_lumber:removeprop")
AddEventHandler("pup_miner_lumber:removeprop", function(prop)
    if Config.Debug then print("^4[DEBUG] Prop respawn scheduled in " .. tostring(Config.PropRespawn) .. "ms: " .. tostring(prop) .. "^7") end
    Wait(Config.PropRespawn)
    if Config.Debug then print("^2[DEBUG] Prop respawning: " .. tostring(prop) .. "^7") end
    table.remove(gathered, GetArrayKey(gathered, tostring(prop)))
end)

RegisterNetEvent("pup_miner_lumber:removecoords")
AddEventHandler("pup_miner_lumber:removecoords", function(prop)
    if Config.Debug then print("^2[DEBUG] Location instantly respawned: ID=" .. tostring(prop) .. "^7") end
    -- Instant respawn for non-limited locations
    table.remove(gatheredcoords, GetArrayKey(gatheredcoords, prop))
end)

RegisterNetEvent("pup_miner_lumber:startcooldown")
AddEventHandler("pup_miner_lumber:startcooldown", function(locationKey, cooldownDuration)
    local cooldownSeconds = cooldownDuration / 1000
    local isLimited = cooldownDuration ~= Config.NodeDefaults.cooldown
    local cooldownType = isLimited and "LIMITED" or "UNLIMITED"
    if Config.Debug then print("^1[DEBUG] Cooldown started [" .. cooldownType .. "] Location ID=" .. tostring(locationKey) .. " Duration: " .. tostring(cooldownSeconds) .. "s^7") end
    -- Set cooldown timer for this location
    locationCooldowns[tostring(locationKey)] = GetGameTimer() + cooldownDuration
    
    -- Remove from gathered coords immediately
    table.remove(gatheredcoords, GetArrayKey(gatheredcoords, locationKey))
    
    -- Reset the availability log flag
    locationAvailableLogged[tostring(locationKey)] = false
    
    -- Start thread to reset after cooldown
    Citizen.CreateThread(function()
        Wait(cooldownDuration)
        if Config.Debug then print("^2[DEBUG] Cooldown ended [" .. cooldownType .. "] Location ID=" .. tostring(locationKey) .. " - Available again^7") end
        -- Reset gather count after cooldown expires
        gatherCounts[tostring(locationKey)] = 0
        locationCooldowns[tostring(locationKey)] = nil
        -- Reset randomized limit for next cycle
        locationLimits[tostring(locationKey)] = nil
    end)
end)


AddEventHandler('onResourceStop', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
	  return
	end
    ClearPedTasks(PlayerPedId())            
    DeleteEntity(itemobject)
    FreezeEntityPosition(PlayerPedId(),false)
end)
