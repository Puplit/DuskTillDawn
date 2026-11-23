-- Modified by Puppet (Dusk Till Dawn), 2026
IsInClothingStore = false
local group       = GetRandomIntInRange(0, 0xffffff)
ShopType          = ""


local GetEntityCoords                  = GetEntityCoords
local DeleteEntity                     = DeleteEntity
local Wait                             = Wait
local UiPromptSetActiveGroupThisFrame  = UiPromptSetActiveGroupThisFrame
local UiPromptHasStandardModeCompleted = UiPromptHasStandardModeCompleted
local VarString                        = VarString

local function CreatePrompt(shopType)
    local str <const> = VarString(10, 'LITERAL_STRING', shopType.label)
    local prompt <const> = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, shopType.input)
    UiPromptSetText(prompt, str)
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetStandardMode(prompt, true)
    UiPromptSetGroup(prompt, group, 0)
    UiPromptRegisterEnd(prompt)
    return prompt
end


local function createBlips()
    for _, value in ipairs(Config.Shops.locations) do
        if value.Blip.Enable then
            local blip <const> = BlipAddForCoords(1664425300, value.Prompt.Position.x, value.Prompt.Position.y, value.Prompt.Position.z)
            if value.Blip.Color then
                BlipAddModifier(blip, joaat(value.Blip.Color))
            end
            SetBlipSprite(blip, value.Blip.Sprite, true)
            SetBlipName(blip, value.Blip.Name)
            value.Blip.Entity = blip
        end
    end
end

local function createModel(model, position, index)
    LoadPlayer(model)
    local npc <const> = CreatePed(model, position.x, position.y, position.z, position.w, false, false, false, false)
    repeat Wait(0) until DoesEntityExist(npc)
    SetRandomOutfitVariation(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedCanBeTargetted(npc, false)
    SetEntityInvincible(npc, true)
    Config.Shops.locations[index].Npc.Entity = npc
    if Config.Shops.locations[index].Npc.Scenario then
        TaskStartScenarioInPlaceHash(npc, joaat(Config.Shops.locations[index].Npc.Scenario), 0, true, 0, 0, false)
    end
    SetTimeout(1000, function()
        FreezeEntityPosition(npc, true)
    end)
end

CreateThread(function()
    if not Config.Shops.enabled then
        return
    end

    repeat Wait(5000) until LocalPlayer.state.IsInSession
    createBlips()

    while true do
        local sleep = 1000

        if not IsInCharCreation and not IsInClothingStore then
            for index, value in ipairs(Config.Shops.locations) do
                local coords <const> = GetEntityCoords(PlayerPedId())
                local distance <const> = #(coords - value.Prompt.Position)

                if distance < 100 then
                    if value.Npc.Enable and not value.Npc.Entity then
                        createModel(value.Npc.Model, value.Npc.Position, index)
                    end
                else
                    if value.Npc.Enable and value.Npc.Entity then
                        DeleteEntity(value.Npc.Entity)
                        value.Npc.Entity = nil
                    end
                end

                if distance < 5.0 then
                    for _, prompt in ipairs(value.TypeOfShop) do
                        if not prompt.promptHandle then
                            prompt.promptHandle = CreatePrompt(prompt)
                        end
                    end
                else
                    for _, prompt in ipairs(value.TypeOfShop) do
                        if prompt.promptHandle then
                            UiPromptDelete(prompt.promptHandle)
                            prompt.promptHandle = nil
                        end
                    end
                end

                if distance < 1.5 then
                    sleep = 0

                    local label <const> = VarString(10, 'LITERAL_STRING', value.Prompt.Label)
                    UiPromptSetActiveGroupThisFrame(group, label, 0, 0, 0, 0)
                    for _, prompt in ipairs(value.TypeOfShop) do
                        if UiPromptHasStandardModeCompleted(prompt.promptHandle, 0) then
                            local shopType <const> = prompt.type
                            -- the player stays where they are; the camera is built
                            -- around them rather than from the shop's own mark
                            local inPlace <const> = BuildInPlaceStore(value.DrawLight)
                            if shopType == "secondchance" then
                                local result = Core.Callback.TriggerAwait("vorp_character:callback:CanPayForSecondChance")
                                if result then
                                    PrepareClothingStore(inPlace, shopType)
                                end
                            else
                                PrepareClothingStore(inPlace, shopType)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- clean up
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    for _, value in ipairs(Config.Shops.locations) do
        if value.Blip.Entity and DoesBlipExist(value.Blip.Entity) then
            RemoveBlip(value.Blip.Entity)
        end
        if value.Npc.Entity and DoesEntityExist(value.Npc.Entity) then
            DeleteEntity(value.Npc.Entity)
        end
    end
end)


-- edit where they stand: the config's EditCharacter mark threw you across the room,
-- so build the shot from the ped's own position instead
function BuildInPlaceStore(drawLight)
    local ped <const> = PlayerPedId()
    local coords <const> = GetEntityCoords(ped)
    local heading <const> = GetEntityHeading(ped)
    local rad <const> = math.rad(heading)
    local fx, fy = -math.sin(rad), math.cos(rad) -- forward vector

    -- reuse whatever camera is already framing this ped, so opening the clothes does
    -- not move the view; only a wardrobe item out in the world falls through
    local camPos, camHeading
    local cur <const> = GetRenderingCam()
    if cur and cur ~= 0 and cur ~= -1 and DoesCamExist(cur) then
        local cc <const> = GetCamCoord(cur)
        local cr <const> = GetCamRot(cur, 2)
        camPos, camHeading = vector3(cc.x, cc.y, cc.z), cr.z
    else
        local camDist <const> = 3.3
        camPos = vector3(coords.x + fx * camDist, coords.y + fy * camDist, coords.z + 1.5)
        camHeading = (heading + 180.0) % 360.0
    end

    return {
        EditCharacter  = { Position = vector4(coords.x, coords.y, coords.z, heading) },
        SpawnBack      = { Position = vector4(coords.x, coords.y, coords.z, heading) },
        CameraPosition = {
            Position     = camPos,
            Heading      = camHeading,
            MaxUp        = coords.z + 1.9,
            MaxDown      = coords.z - 0.2,
            ZoomInRange  = 2.0,
            ZoomOutRange = 1.6,
        },
        DrawLight = drawLight and true or false,
    }
end

function PrepareClothingStore(value, shopType)
    ShopType = shopType
    DoScreenFadeOut(1000)
    -- bounded: an unbounded Wait(0) spin here hung the store if the fade never landed
    local fo <const> = GetGameTimer()
    repeat Wait(50) until IsScreenFadedOut() or GetGameTimer() - fo > 3000
    Core.instancePlayers(GetPlayerServerId(PlayerId()) + 4440)
    DisplayRadar(false)
    IsInClothingStore = true
    local Gender = IsPedMale(PlayerPedId()) and "male" or "female"
    FreezeEntityPosition(PlayerPedId(), true)
    Wait(1000)
    -- no re-placing: these coords came from the ped itself, and feeding them back to
    -- the offsetting SetEntityCoords lifts it a metre before grounding it on terrain
    SetEntityHeading(PlayerPedId(), value.EditCharacter.Position.w)
    RegisterGenderPrompt()
    CreateThread(function()
        -- in the creator pass nothing: StartPrompts then rebuilds the creator's own
        -- camera, where passing ours built a second one and the view jumped
        StartPrompts(IsInCharCreation and nil or value.CameraPosition)
    end)
    EnableCharCreationPrompts(true)
    local Clothing = OrganiseClothingData(Gender)
    SetEntityVisible(PlayerPedId(), true)
    SetEntityInvincible(PlayerPedId(), true)
    RenderScriptCams(true, true, 1000, true, true, 0)
    CreateThread(function()
        if value.DrawLight then
            DrawLight(value.CameraPosition.Position)
        end
    end)
    SetCachedClothingIndex()
    Wait(1000)
    TaskStandStill(PlayerPedId(), -1)
    DoScreenFadeIn(1000)
    LocalPlayer.state:set('PlayerIsInCharacterShops', true, true) -- this can be used in other resources to disable Huds or metabolism scripts apply effects etc
    -- BOUNDED, same reason as the fade out above
    local fi <const> = GetGameTimer()
    repeat Wait(50) until IsScreenFadedIn() or GetGameTimer() - fi > 4000
    SetTimeout(1000, function()
        FreezeEntityPosition(PlayerPedId(), false)
    end)

    if shopType == "secondchance" then
        OpenCharCreationMenu(Clothing, value)
    elseif shopType == "clothing" then
        local result = Core.Callback.TriggerAwait("vorp_character:callback:GetOutfits")
        if result then
            OpenClothingMenu(Clothing, value, result)
        end
    elseif shopType == "hair" then
        OpenHairMenu(Clothing, value)
    elseif shopType == "makeup" then
        OpenMakeupMenu(Clothing, value)
    elseif shopType == "face" then
        OpenFaceMenu(Clothing, value)
    elseif ShopType == "lifestyle" then
        OpenLifeStyleMenu(Clothing, value)
    end
end

-- open the clothing menu at the player's CURRENT spot (used by the pup-clothing resource's /wardrobe command + item)
RegisterNetEvent('vorp_character:openWardrobe', function(shopType)
    -- a bare return here is indistinguishable from a broken item, so say it out loud
    if IsInCharCreation or IsInClothingStore then
        TriggerEvent("vorp:TipRight", "You are already changing your appearance.", 4000)
        return
    end
    local ped <const> = PlayerPedId()
    if IsPedDeadOrDying(ped, true) then return end
    -- the satchel is still up when this comes from a used item; the menu must not open behind it
    TriggerEvent("vorp_inventory:CloseInv")
    Wait(150)
    -- same builder the shop prompts use
    PrepareClothingStore(BuildInPlaceStore(false), shopType or "clothing")
end)
