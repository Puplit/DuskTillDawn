-- Modified by Puppet (Dusk Till Dawn), 2026
-- TELEPORTS ---------------------------------------------------------
local lastLocation = {}
local autotpm = false
local lastCoords = nil
local T = Translation.Langs[Config.General.language]

--- Returns true when the player is currently in a Guarma area.
local function isPlayerInGuarma()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local area = GetMapZoneAtCoords(pedCoords, 10)
    return Config.Guarma.areaHashes[area] == true
end

--- Applies Guarma world state and minimap settings.
local function setGuarmaWorldState(enabled)
    if enabled then
        Citizen.InvokeNative(0x74E2261D2A66849A, true)
        Citizen.InvokeNative(0xE8770EE02AEE45C2, 1)
        Citizen.InvokeNative(0xA657EC9DBC6CC900, 1935063277)
        return
    end

    Citizen.InvokeNative(0x74E2261D2A66849A, false)
    Citizen.InvokeNative(0xE8770EE02AEE45C2, 0)
    Citizen.InvokeNative(0xA657EC9DBC6CC900, -1868977180)
end

--- Teleports the ped after a fade transition.
local function teleportPedToCoords(ped, coords)
    DoScreenFadeOut(500)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    Wait(1000)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    repeat Wait(0) until HasCollisionLoadedAroundEntity(ped)
    Wait(1000)
    DoScreenFadeIn(650)
end

-- Extracted action bodies (globals): they flip file-local state (autotpm / lastCoords) or use file-local helpers
function ToggleAutoTPM()
    if autotpm == false then
        autotpm = true
        TriggerEvent('vorp:TipRight', T.Notify.switchedOn, 3000)
        while autotpm do
            Wait(2000)
            TriggerServerEvent('vorp:teleportWayPoint')
        end
    else
        TriggerEvent('vorp:TipRight', T.Notify.switchedOff, 3000)
        autotpm = false
    end
end

function TpToWaypoint()
    local coords = GetEntityCoords(PlayerPedId())
    local waypointCoords = GetWaypointCoords()
    local waypoint = IsWaypointActive()
    if not waypoint then
        return VORP.NotifyObjective("theres no waypoint set", 5000)
    end

    TriggerServerEvent('vorp:teleportWayPoint', "", coords, waypointCoords)
end

function TeleportToCoords(x, y, z)
    local admin = PlayerPedId()
    local oldCoords = GetEntityCoords(admin)
    teleportPedToCoords(admin, { x = x, y = y, z = z })
    TriggerServerEvent("vorp_admin:tptocoords", oldCoords, x, y, z)
end

function ToggleGuarma()
    local admin = PlayerPedId()
    if isPlayerInGuarma() then
        local returnCoords = lastCoords or Config.Guarma.mainlandCoords

        setGuarmaWorldState(false)
        teleportPedToCoords(admin, returnCoords)
        lastCoords = nil
    else
        lastCoords = GetEntityCoords(admin)

        setGuarmaWorldState(true)
        teleportPedToCoords(admin, Config.Guarma.coords)
    end
end

function BuildTeleport()
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleTeleport,
        options = {
            {
                label = T.Menus.MainTeleportOptions.tpmAuto,
                desc = T.Menus.MainTeleportOptions.tpmAuto_desc,
                action = function()
                    ToggleAutoTPM()
                end
            },
            {
                label = T.Menus.MainTeleportOptions.tpmToMarker,
                desc = T.Menus.MainTeleportOptions.tpmToMarker_desc,
                action = function()
                    TpToWaypoint()
                end
            },
            {
                label = T.Menus.MainTeleportOptions.tpToCoords,
                desc = T.Menus.MainTeleportOptions.tpToCoords_desc,
                action = function()
                    if not IsAdminAllowed("tp_to_coords") then return end
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.MainTeleportOptions.InsertCoordsInput.title, {
                        { label = 'X', type = 'number', placeholder = 'X', required = true },
                        { label = 'Y', type = 'number', placeholder = 'Y', required = true },
                        { label = 'Z', type = 'number', placeholder = 'Z', required = true },
                    }, T.Menus.MainTeleportOptions.InsertCoordsInput.errorMsg)
                    if not vals then return end
                    local x, y, z = tonumber(vals[1]), tonumber(vals[2]), tonumber(vals[3])
                    if x and y and z then
                        TeleportToCoords(x, y, z)
                    else
                        VORP.NotifyObjective(T.Notify.empty, 5000)
                    end
                end
            },
            {
                label = T.Menus.MainTeleportOptions.tpToPlayer,
                desc = T.Menus.MainTeleportOptions.tpToPlayer_desc,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.DefaultsInputs.confirm, {
                        { label = T.Menus.DefaultsInputs.serverID, type = 'number', placeholder = T.Menus.DefaultsInputs.serverID, required = true }
                    })
                    if not vals then return end
                    local TargetID = tonumber(vals[1])
                    if TargetID then
                        TriggerServerEvent("vorp_admin:TpToPlayer", TargetID)
                    else
                        VORP.NotifyObjective(T.Notify.empty, 5000)
                    end
                end
            },
            {
                label = T.Menus.MainTeleportOptions.adminGoBackLastLocation,
                desc = T.Menus.MainTeleportOptions.adminGoBackLastLocation_desc,
                action = function()
                    if lastLocation then
                        TriggerServerEvent("vorp_admin:sendAdminBack")
                    end
                end
            },
            {
                label = T.Menus.MainTeleportOptions.bringPlayer,
                desc = T.Menus.MainTeleportOptions.bringPlayer_desc,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.DefaultsInputs.confirm, {
                        { label = T.Menus.DefaultsInputs.serverID, type = 'number', placeholder = T.Menus.DefaultsInputs.serverID, required = true }
                    })
                    if not vals then return end
                    local TargetID = tonumber(vals[1])
                    if TargetID and lastLocation then
                        local adminCoords = GetEntityCoords(PlayerPedId())
                        TriggerServerEvent("vorp_admin:Bring", TargetID, adminCoords, "", nil, TargetID)
                    else
                        VORP.NotifyObjective(T.Notify.empty, 5000)
                    end
                end
            },
            {
                label = T.Menus.MainTeleportOptions.sendPlayerToLastLocation,
                desc = T.Menus.MainTeleportOptions.sendPlayerToLastLocation_desc,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.DefaultsInputs.confirm, {
                        { label = T.Menus.DefaultsInputs.serverID, type = 'number', placeholder = T.Menus.DefaultsInputs.serverID, required = true }
                    })
                    if not vals then return end
                    local TargetID = tonumber(vals[1])
                    if TargetID and lastLocation then
                        TriggerServerEvent("vorp_admin:TeleportPlayerBack", TargetID)
                    else
                        TriggerEvent("vorp:TipRight", T.Notify.goToPlayerFirst, 4000)
                    end
                end
            },
            {
                label = T.Menus.MainTeleportOptions.teleportToGuarma,
                desc = T.Menus.MainTeleportOptions.teleportToGuarma_desc,
                action = function()
                    if not IsAdminAllowed("teleport_to_guarma") then return end
                    ToggleGuarma()
                end
            },
        }
    }
end
