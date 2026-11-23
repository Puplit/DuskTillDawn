-- Modified by Puppet (Dusk Till Dawn), 2026
local LIB <const> = Import({ "/config", "entities", "prompts" })
local Config <const> = LIB.Config --[[@as vorp_herbs_config]]
local Core <const> = exports.vorp_core:GetCore()
local Object <const> = LIB.Object   ---[[@as ENTITIES]]
local Prompts <const> = LIB.Prompts ---[[@as PROMPTS]]
local isPicking = false
local PLAYER_IS_DEAD = false

-- [configIndex] = true while that plant is on its cooldown. The server owns this and
-- tells everyone, so a picked spot shows no bush and offers no prompt.
local spent = {}

RegisterNetEvent("vorp_herbs:setState", function(key, isSpent)
    spent[key] = isSpent and true or nil
end)

RegisterNetEvent("vorp_herbs:fullState", function(list)
    spent = {}
    for _, k in ipairs(list or {}) do spent[k] = true end
end)

local function PlayerPick(index, plantCoords, isProp)
    if not isPicking then
        isPicking = true

        -- picked FIRST, paid after, so the item never lands before the ped has reached
        -- for it. Same shape as pup_homestead's harvest - a progress bar over the anim.
        local ped <const> = PlayerPedId()
        local dict <const> = "mech_pickup@plant@berries"
        TaskTurnPedToFaceCoord(ped, plantCoords.x, plantCoords.y, plantCoords.z, -1)
        Wait(400)
        pcall(function() exports['pup-ui']:Progress({ label = 'PICKING...', duration = 2000 }) end)
        RequestAnimDict(dict)
        local waited = 0
        while not HasAnimDictLoaded(dict) and waited < 2000 do Wait(50) waited = waited + 50 end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, "base", 8.0, 8.0, 2000, 1, 0, false, false, false)
        end
        Wait(2000)
        ClearPedTasks(ped)
        RemoveAnimDict(dict)

        Core.Callback.TriggerAsync("vorp_herbs:CheckItemsCapacity", function(canCarryAll, looted)
            if canCarryAll then
                -- nothing more to play: the anim already ran
            elseif not canCarryAll and looted then
                Core.NotifyRightTip(Config.Language.cantpick, 4000)
            elseif not canCarryAll then
                Core.NotifyRightTip(Config.Language.NoRoomForItems, 4000)
            end
            Wait(1000)
            isPicking = false
        end, index, plantCoords, isProp)
    end
end

local function getObject(plantModel)
    local gamePool <const> = GetGamePool("CObject")
    local plantEntity = 0
    local distance = math.huge
    for _, object in ipairs(gamePool) do
        if GetEntityModel(object) == plantModel then
            local objectDistance <const> = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(object))
            if objectDistance < distance then
                distance = objectDistance
                plantEntity = object
            end
        end
    end
    return plantEntity
end

local function createPlant(v)
    return Object:Create({
        Model = v.plantModel,
        Pos = v.coords,
        Options = { PlaceOnGround = true },
    })
end

local function createPrompt(v, index, isProp, coords)
    return Prompts:Register({
        locations = { { coords = coords, label = v.name, distance = 2.0 } },
        prompts = { { type = 'Standard', key = Config.ControlAction, label = Config.Language.PromptText, mode = 'Standard' } },
        sleep = 700,
    }, function()
        if not isPicking then
            PlayerPick(index, coords, isProp)
        end
    end, true)
end

-- creates models or uses just location
CreateThread(function()
    repeat Wait(5000) until LocalPlayer.state.IsInSession
    TriggerServerEvent("vorp_herbs:requestState") -- which plants are already picked

    while true do
        local sleep = 1000

        if not PLAYER_IS_DEAD then
            local ped <const> = PlayerPedId()
            local pedCoords <const> = GetEntityCoords(ped)
            for k, v in ipairs(Config.Plants) do
                -- is location for prop or no prop spawn
                if v.coords and v.islocation then
                    local distance <const> = #(pedCoords - v.coords)
                    -- a spent plant is treated exactly like one out of range: no bush, no prompt
                    if distance and distance <= 100 and not spent[k] then
                        if not v.plant and v.placeprop and v.plantModel then
                            v.plant = createPlant(v)
                        end

                        if not v.prompt then
                            v.prompt = createPrompt(v, k, false, v.coords)
                        end
                    else
                        if v.plant then
                            v.plant:Delete()
                            v.plant = nil
                        end
                        if v.prompt then
                            v.prompt:Destroy()
                            v.prompt = nil
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)


CreateThread(function()
    repeat Wait(5000) until LocalPlayer.state.IsInSession

    while true do
        local sleep = 1000

        if not PLAYER_IS_DEAD then
            local ped <const> = PlayerPedId()
            local pedCoords <const> = GetEntityCoords(ped)

            for k, v in ipairs(Config.Plants) do
                -- only for finding world props
                if not v.placeprop and not v.islocation and v.plantModel then
                    local plantModel <const> = GetHashKey(v.plantModel)
                    local plantEntity = 0
                    local plantDetected <const> = DoesObjectOfTypeExistAtCoords(pedCoords.x, pedCoords.y, pedCoords.z, 2.0, plantModel, false)
                    if not isPicking and plantDetected == 1 then
                        if not v.prompt1 then
                            plantEntity = GetClosestObjectOfType(pedCoords.x, pedCoords.y, pedCoords.z, 2.5, plantModel, false, false, false)
                            -- if plantEntity is 0, get the object from the game pool the native is failing to get this object somehow
                            if plantEntity == 0 then
                                plantEntity = getObject(plantModel)
                            end

                            if plantEntity > 0 and DoesEntityExist(plantEntity) then
                                local plantCoords <const> = GetEntityCoords(plantEntity)
                                v.prompt1 = createPrompt(v, k, true, plantCoords)
                            end
                        end
                    end

                    if plantEntity > 0 and DoesEntityExist(plantEntity) then
                        local distance <const> = #(pedCoords - GetEntityCoords(plantEntity))
                        if distance > 2.0 then
                            if v.prompt1 then
                                v.prompt1:Destroy()
                                v.prompt1 = nil
                                plantEntity = 0
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)


AddEventHandler("vorp_core:Client:OnPlayerDeath", function()
    PLAYER_IS_DEAD = true
end)

RegisterNetEvent("vorp_core:Client:OnPlayerRevive", function()
    PLAYER_IS_DEAD = false
end)
