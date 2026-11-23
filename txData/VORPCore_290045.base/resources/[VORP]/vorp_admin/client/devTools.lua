-- Modified by Puppet (Dusk Till Dawn), 2026
local T = Translation.Langs[Config.General.language]
local active = false
-- DEV TOOLS ------------------------------------------------------

local function loadModel(ped)
    if not IsModelInCdimage(ped) then
        print("invalid model")
        return
    end

    if not HasModelLoaded(ped) then
        RequestModel(ped, false)
        repeat Wait(0) until HasModelLoaded(ped)
    end
end

local devAimEnabled = false
local laserThreadRunning = false
local StartDevLaserLoop -- forward declaration

function ToggleDevLaser() -- global: called by the admin menu's Dev Tools AND client/dashboard.lua
    devAimEnabled = not devAimEnabled
    if devAimEnabled then
        TriggerEvent("vorp:TipRight", "Dev Laser ON (aim at an entity)", 3000)
        StartDevLaserLoop()
    else
        -- graceful stop: loop will exit on next tick
        TriggerEvent("vorp:TipRight", "Dev Laser OFF", 2500)
    end
end


function BuildDevTools()
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleDevTools,
        options = {
            {
                label = T.Menus.MainDevToolsOptions.spawnPedWithList,
                desc = T.Menus.MainDevToolsOptions.spawnPedWithList_desc,
                submenu = function() return BuildSpawnPeds("peds") end
            },
            {
                label = T.Menus.MainDevToolsOptions.spawnPedWithInput,
                desc = T.Menus.MainDevToolsOptions.spawnPedWithInput_desc,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.MainDevToolsOptions.SpawnPedInput.title, {
                        { label = T.Menus.MainDevToolsOptions.SpawnPedInput.placeholder, type = 'text', placeholder = T.Menus.MainDevToolsOptions.SpawnPedInput.placeholder, required = true }
                    }, T.Menus.MainDevToolsOptions.SpawnPedInput.errorMsg)
                    if not vals then return end
                    local ped = tostring(vals[1])
                    if ped ~= "" then
                        loadModel(ped)
                        local offset = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 5.0, 0.0)
                        local npc = CreatePed(joaat(ped), offset.x, offset.y, offset.z, 0.0, true, true, true, false)
                        repeat Wait(0) until DoesEntityExist(npc)

                        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, npc, 1, 0)
                        SetModelAsNoLongerNeeded(ped)
                        SetEntityAsNoLongerNeeded(npc)
                    else
                        TriggerEvent('vorp:TipRight', T.Notify.empty, 3000)
                    end
                end
            },
            {
                label = T.Menus.MainDevToolsOptions.coordsMenu,
                desc = T.Menus.MainDevToolsOptions.coordsMenu_desc,
                submenu = function() return BuildCoordsMenu() end
            },
            {
                label = T.Menus.MainDevToolsOptions.spawnWagonWithInput,
                desc = T.Menus.MainDevToolsOptions.spawnWagonWithInput_desc,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.MainDevToolsOptions.SpawnWagonInput.title, {
                        { label = T.Menus.MainDevToolsOptions.SpawnWagonInput.placeholder, type = 'text', placeholder = T.Menus.MainDevToolsOptions.SpawnWagonInput.placeholder, required = true }
                    }, T.Menus.MainDevToolsOptions.SpawnWagonInput.errorMsg)
                    if not vals then return end
                    local wagon = tostring(vals[1])
                    local player = PlayerPedId()
                    local playerCoords = GetOffsetFromEntityInWorldCoords(player, 0.0, 5.0, 0.0)
                    if wagon ~= "" then
                        loadModel(wagon)
                        local Wagon = CreateVehicle(wagon, playerCoords.x, playerCoords.y, playerCoords.z, 0, true, true, true)
                        repeat Wait(0) until DoesEntityExist(Wagon)
                        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, Wagon, 1, 0)
                        SetPedIntoVehicle(player, Wagon, -1)
                        SetModelAsNoLongerNeeded(wagon)
                        SetEntityAsNoLongerNeeded(Wagon)
                    else
                        TriggerEvent('vorp:TipRight', T.Notify.empty, 3000)
                    end
                end
            },
            {
                label = T.Menus.MainDevToolsOptions.spawnWagonWithList,
                desc = T.Menus.MainDevToolsOptions.spawnWagonWithList_desc,
                submenu = function() return BuildSpawnPeds("wagons") end
            },
            {
                label = T.Menus.MainDevToolsOptions.objectMenu,
                desc = T.Menus.MainDevToolsOptions.objectMenu_desc,
                submenu = function() return BuildObjMenu() end
            },
            {
                label = T.Menus.MainDevToolsOptions.imapViwer,
                desc = T.Menus.MainDevToolsOptions.imapViwer_desc,
                action = function()
                    ExecuteCommand("imapview")
                end
            },
            {
                label = T.Menus.MainDevToolsOptions.scenarioHashViwer,
                desc = T.Menus.MainDevToolsOptions.scenarioHashViwer_desc,
                action = function()
                    active = not active
                    while active do
                        Wait(1000)
                        local ped = PlayerPedId()
                        local retval = IsPedUsingAnyScenario(ped)
                        if retval then
                            local hash = Citizen.InvokeNative(0x569F1E1237508DEB, ped)
                            print("scenario Hash", hash)
                        end
                    end
                end
            },
            {
                label = T.Menus.MainDevToolsOptions.interiorId,
                desc = T.Menus.MainDevToolsOptions.interiorId_desc,
                action = function()
                    local interiorId = GetInteriorFromEntity(PlayerPedId())
                    print("interiorId", interiorId)
                end
            },
        }
    }
end

function BuildSpawnPeds(action)
    local options = {}
    local list = action == "peds" and Peds or Vehicles
    local rowDesc = action == "peds" and T.Menus.MainDevToolsOptions.spawnPeds_desc or T.Menus.MainDevToolsOptions.spawnVehicle_desc
    for _, value in ipairs(list) do
        options[#options + 1] = {
            label = value,
            desc = rowDesc,
            action = function()
                local player = PlayerPedId()
                local playerCoords = GetOffsetFromEntityInWorldCoords(player, 0.0, 5.0, 0.0)
                loadModel(value)
                if action == "peds" then
                    local npc = CreatePed(joaat(value), playerCoords.x, playerCoords.y, playerCoords.z, 0.0, true, true, false, false)
                    repeat Wait(0) until DoesEntityExist(npc)
                    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, npc, true, 0) -- variation
                else
                    local Wagon = CreateVehicle(joaat(value), playerCoords.x, playerCoords.y, playerCoords.z, 0.0, true, true)
                    repeat Wait(0) until DoesEntityExist(Wagon)
                    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, Wagon, true, 0)
                    SetPedIntoVehicle(player, Wagon, -1)
                end
                SetModelAsNoLongerNeeded(value)
            end
        }
    end

    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleDevTools,
        options = options
    }
end

function BuildObjMenu()
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleDevTools,
        options = {
            {
                label = T.Menus.SubDevToolsOptions.printModel,
                desc = T.Menus.SubDevToolsOptions.printModel_desc,
                action = function()
                    local player = PlayerPedId()
                    local coords = GetEntityCoords(player)
                    local closestObject, distance = GetClosestObject(coords)
                    local objectCoords = GetEntityCoords(closestObject)
                    local model = GetEntityModel(closestObject)
                    print(T.Notify.closesObject .. " " .. model, objectCoords)
                    TriggerEvent("vorp:TipRight", T.Notify.closesObject .. " " .. model, 6000)
                end
            },
            {
                label = T.Menus.SubDevToolsOptions.deleteModel,
                desc = T.Menus.SubDevToolsOptions.deleteModel_desc,
                action = function()
                    local player = PlayerPedId()
                    local coords = GetEntityCoords(player)
                    local closestObject, distance = GetClosestObject(coords)
                    TriggerEvent("vorp:TipRight", T.Notify.closesObject .. " " .. closestObject, 4000)
                    DeleteObject(closestObject)
                end
            },
            {
                label = T.Menus.SubDevToolsOptions.coordsMenu,
                desc = T.Menus.SubDevToolsOptions.coordsMenu_desc,
                submenu = function() return BuildCoordsMenu() end
            },
            {
                label = T.Menus.SubDevToolsOptions.devtoolOn,
                desc = T.Menus.SubDevToolsOptions.devtool_desc,
                action = function()
                    ToggleDevLaser()
                end
            },
        }
    }
end

-- DEV SPHERE AIM: shows small sphere at raycast hit + entity info + hotkey copy coords /devlaser → toggle ON/OFF H → copy
local lastHit = { coords = nil, entity = nil }
local lastOutlined = nil

-- build hash->name dictionary з datapeds.lua
local PedModelsByHash = {}
if Peds then
    for _, model in ipairs(Peds) do
        PedModelsByHash[GetHashKey(model:lower())] = model
    end
end

-- build hash->name dictionary з dataprops.lua
local PropModelsByHash = {}
if Props then
    for _, model in ipairs(Props) do
        PropModelsByHash[GetHashKey(model:lower())] = model
    end
end

-- Draw text
local function DrawText2D(txt, x, y, scale, r, g, b, a)
    local str = CreateVarString(10, "LITERAL_STRING", txt)
    SetTextFontForCurrentCommand(0)
    SetTextScale(scale, scale)
    SetTextColor(r or 255, g or 255, b or 255, a or 255)
    SetTextCentre(true)
    DisplayText(str, x, y)
end

-- Rotation → direction
local function RotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local cosx = math.cos(x)
    return vector3(-math.sin(z) * cosx, math.cos(z) * cosx, math.sin(x))
end

-- Start raycast from eyes
local function GetEyesOrigin(ped)
    return GetPedBoneCoords(ped, 21030, 0.0, 0.05, 0.02) -- SKEL_Head
end

-- Copy helper
local function CopyToClipboard(str)
    local ok = pcall(function() SendNUIMessage({ string = str }) end)
    if ok then
        TriggerEvent("vorp:TipRight", "Copied to clipboard", 2000)
    else
        TriggerEvent("chat:addMessage", { args = { "^2COPY", str } })
        TriggerEvent("vorp:TipRight", "Copied text printed to console", 2500)
        print(str)
    end
end

local INPUT_ATTACK <const> = GetHashKey("INPUT_ATTACK") -- left mouse

-- Delete whatever the laser is on
local function DeleteAimedEntity(entity)
    if not DoesEntityExist(entity) then return end

    local model <const> = GetEntityModel(entity)
    local etype <const> = GetEntityType(entity) -- 1 ped, 2 vehicle, 3 object
    local name <const> = PedModelsByHash[model] or PropModelsByHash[model] or tostring(model)

    -- a player's ped is never a prop to be cleaned up
    if etype == 1 and IsPedAPlayer(entity) then
        TriggerEvent("vorp:TipRight", "That is a player - refusing", 3000)
        return
    end

    CreateThread(function()
        local tries = 0
        while not NetworkHasControlOfEntity(entity) and tries < 20 and DoesEntityExist(entity) do
            NetworkRequestControlOfEntity(entity)
            Wait(50)
            tries = tries + 1
        end
        if not DoesEntityExist(entity) then return end

        SetEntityAsMissionEntity(entity, true, true)
        if etype == 1 then
            DeletePed(entity)
        elseif etype == 2 then
            DeleteVehicle(entity)
        elseif etype == 3 then
            DeleteObject(entity)
        end
        -- catch-all for anything the typed natives would not touch
        if DoesEntityExist(entity) then DeleteEntity(entity) end

        if DoesEntityExist(entity) then
            TriggerEvent("vorp:TipRight", ("Could not delete %s (no network control)"):format(name), 4000)
        else
            TriggerEvent("vorp:TipRight", ("Deleted %s"):format(name), 3000)
        end
    end)
end

function StartDevLaserLoop()
    if laserThreadRunning then return end
    laserThreadRunning = true

    CreateThread(function()
        while devAimEnabled do
            Wait(0)

            local ped   = PlayerPedId()
            local start = GetEyesOrigin(ped)
            local dir   = RotationToDirection(GetGameplayCamRot(2))
            local dest  = start + (dir * 60.0)

            -- laser
            DrawLine(start.x, start.y, start.z, dest.x, dest.y, dest.z, 255, 25, 25, 255)

            -- raycast
            local ray = StartShapeTestRay(start.x, start.y, start.z, dest.x, dest.y, dest.z, -1, ped, 0)
            local _, hit, endCoords, _, entityHit = GetShapeTestResult(ray)

            local info = ("Coords: %.2f, %.2f, %.2f"):format(endCoords.x, endCoords.y, endCoords.z)
            lastHit.coords = endCoords
            lastHit.entity = nil

            if hit == 1 and entityHit ~= 0 and DoesEntityExist(entityHit) then
                lastHit.entity  = entityHit
                local model     = GetEntityModel(entityHit)
                local modelName = PedModelsByHash[model] or PropModelsByHash[model] or "Unknown"
                local ec        = GetEntityCoords(entityHit)
                local heading   = GetEntityHeading(entityHit)
                local rot       = GetEntityRotation(entityHit)

                info            = ("Coords: %.2f, %.2f, %.2f\nModel Hash: %s\nModel Name: %s\nHeading: %.2f\nRotation: %.2f, %.2f, %.2f")
                    :format(ec.x, ec.y, ec.z, tostring(model), modelName, heading, rot.x, rot.y, rot.z)

                -- red cube marker at hit
                DrawBox(
                    endCoords.x - 0.03, endCoords.y - 0.03, endCoords.z - 0.03,
                    endCoords.x + 0.03, endCoords.y + 0.03, endCoords.z + 0.03,
                    255, 50, 50, 200
                )
            end

            -- HUD text
            DrawText2D(info, 0.5, 0.80, 0.40, 255, 255, 255, 235)
            DrawText2D("LEFT CLICK = delete entity | H = copy entity info | G = copy vector3(x, y, z)", 0.5, 0.92, 0.36, 255, 200, 200, 235)

            -- H: copy full info (only if entity)
            if IsControlJustPressed(0, 0x24978A28) and lastHit.entity then
                CopyToClipboard(info)
            end
            -- G: copy just vector3
            if IsControlJustPressed(0, 0x760A9C6F) and lastHit.coords then
                local c = lastHit.coords
                CopyToClipboard(("vector3(%.2f, %.2f, %.2f)"):format(c.x, c.y, c.z))
            end
            -- LEFT CLICK: delete the aimed entity
            DisableControlAction(0, INPUT_ATTACK, true)
            if IsDisabledControlJustPressed(0, INPUT_ATTACK) and lastHit.entity then
                DeleteAimedEntity(lastHit.entity)
            end
        end

        -- cleanup after toggle OFF
        laserThreadRunning = false
        lastHit.coords, lastHit.entity = nil, nil
    end)
end

-- =================== /DEV LASER / INSPECT ===================== --

-- /devgun toggles the same laser as the admin menu's Dev Tools, without walking the menu down to it.
CreateThread(function()
    repeat Wait(3000) until LocalPlayer.state.IsInSession

    TriggerEvent('chat:addSuggestion', '/devgun',
        'Dev laser: aim to read an entity\'s coords, hash, model name and rotation', {})

    -- its own key: the laser only READS an entity, while devtools_menu also carries the
    -- prop placer and zone creator, which change the world. Moderators get the reading
    -- half without the building half. devtools_menu also opens it.
    RegisterCommand('devgun', function()
        if not (IsAdminAllowed('dev_laser') or IsAdminAllowed('devtools_menu')) then return end
        ToggleDevLaser()
    end, false)
end)
