-- Modified by Puppet (Dusk Till Dawn), 2026
local Key = Config.Keys.openMenu
local CanOpen = Config.Menu.openWhenDead
local Inmenu
local spectating = false
local lastcoords = { x = 0, y = 0, z = 0 }
local T = Translation.Langs[Config.General.language]
VORP = exports.vorp_core:GetCore()


AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    local player = PlayerPedId()
    ClearPedTasksImmediately(player, true, true) -- Clear tasks
    Closem()                                     -- Close menu
    AdminAllowed = false

    -- stopping mid-spectate must not leave the admin invisible and invincible with no
    -- running script left to undo it
    if spectating then
        SetEntityVisible(player, true)
        SetEntityCanBeDamaged(player, true)
        SetEntityInvincible(player, false)
        FreezeEntityPosition(player, false)
        RenderScriptCams(false, false, 0, true, true, 0)
        DestroyAllCams(true)
        spectating = false
    end
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if not Config.General.debug then return end

    AdminAllowed = false
    local player = GetPlayerServerId(tonumber(PlayerId()))
    Wait(100)
    TriggerServerEvent("vorp_admin:getStaffInfo", player)
end)

local function CanOpenUsersMenu()
    if Config.Scoreboard.usersMenu then
        TriggerServerEvent("vorp_admin:GetGroup")
        OpenUsersMenu()
    end
end

local function OpenAdminMenu()
    -- quiet: pagedown is pressed by everyone, and a non-admin should get nothing
    if IsAdminAllowedQuiet("open_menu") then
        OpenMenu()
        return true
    end
    return false
end


CreateThread(function()
    repeat Wait(3000) until LocalPlayer.state.IsInSession

    if Config.Menu.commandEnabled then
        TriggerEvent('chat:addSuggestion', '/' .. Config.Menu.command, 'Open admin menu or use pagedown', { {} })
        RegisterCommand(Config.Menu.command, function()
            if IsAdminAllowedQuiet("open_menu") then
                OpenMenu()
                return true
            end
        end, false)
    end

    while true do
        local player = PlayerPedId()
        local isDead = IsPedDeadOrDying(player, false)
        if CanOpen then
            if IsControlJustPressed(0, Key) and not Inmenu then
                if not OpenAdminMenu() then
                    CanOpenUsersMenu()
                end
            end
        else
            if IsControlJustPressed(0, Key) and not isDead and not Inmenu then
                if not OpenAdminMenu() then
                    CanOpenUsersMenu()
                end
            end
        end
        Wait(0)
    end
end)

----- EVENTS
RegisterNetEvent("vorp_admin:Freezeplayer", function(state)
    FreezeEntityPosition(PlayerPedId(), state)
end)

RegisterNetEvent("vorp_admin:respawn", function()
    Wait(50)
    DoScreenFadeOut(1000)
    repeat Wait(0) until not IsScreenFadingOut()
    FreezeEntityPosition(PlayerPedId(), true)
    Wait(1000)
    DoScreenFadeIn(4000)
    repeat Wait(0) until not IsScreenFadingIn()
    FreezeEntityPosition(PlayerPedId(), false)
    TriggerEvent('vorp:ShowBottomRight', T.Notify.reviseRules, 10000)
end)


RegisterNetEvent("vorp_admin:spectatePlayer", function(target, targetCoords)
    local admin = PlayerPedId()
    local ped = 0
    if not spectating then
        DoScreenFadeOut(2000)
        repeat Wait(0) until not IsScreenFadingOut()
        lastcoords = GetEntityCoords(admin)
        SetEntityVisible(admin, false)
        SetEntityCanBeDamaged(admin, false)
        SetEntityInvincible(admin, true)
        SetEntityCoords(admin, targetCoords.x + 15, targetCoords.y + 15, targetCoords.z, false, false, false, false)
        Wait(500)
        ped = GetPlayersClient(target)
        Wait(500)
        Camera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        AttachCamToEntity(Camera, ped, 0.0, -2.0, 1.0, false)
        SetCamActive(Camera, true)
        RenderScriptCams(true, true, 1, true, true, 0)
        DoScreenFadeIn(2000)
        repeat Wait(0) until IsScreenFadingIn()
        spectating = true
    else
        DoScreenFadeOut(2000)
        repeat Wait(0) until not IsScreenFadingOut()
        RenderScriptCams(true, false, 1, true, true, 0)
        DestroyCam(Camera, true)
        DestroyAllCams(true)
        SetEntityCoords(admin, lastcoords.x, lastcoords.y, lastcoords.z - 1, false, false, false, false)
        -- undo what the branch above set, or the admin stays unkillable
        SetEntityVisible(admin, true)
        SetEntityCanBeDamaged(admin, true)
        SetEntityInvincible(admin, false)
        DoScreenFadeIn(2000)
        repeat Wait(0) until IsScreenFadingIn()
        spectating = false
    end
end)

-- Spectate hides and protects the ped, so anything that interrupts it mid-way (a resource
-- restart, a death, a new ped on respawn) must not leave someone invisible or invincible.
local function endSpectateState()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true)
    SetEntityCanBeDamaged(ped, true)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    -- only while we own the camera: another resource's cutscene or shop cam is not ours to drop
    if spectating then
        RenderScriptCams(false, false, 0, true, true, 0)
        DestroyAllCams(true)
    end
    spectating = false
end

-- manual recovery for anyone left invisible or invincible by an interrupted spectate
RegisterCommand('unspectate', function()
    endSpectateState()
    TriggerEvent('vorp:TipRight', 'Spectate state cleared.', 4000)
end, false)

-- RegisterNetEvent is per resource: vorp_core registering it does not deliver it here
RegisterNetEvent('vorp_core:Client:OnPlayerRevive')
AddEventHandler('vorp_core:Client:OnPlayerRevive', function()
    -- dying mid-spectate never reaches the stop branch. VORP's own HealPlayer re-enables
    -- SetEntityCanBeDamaged but never clears SetEntityInvincible, so a respawn does not
    -- undo it either. Guarded so it cannot switch off an admin's godmode booster.
    if spectating then endSpectateState() end
end)
local lastLocation = nil
------------------------- TELEPORT  EVENTS FROM SERVER  -------------------------------
RegisterNetEvent("vorp_admin:gotoPlayer", function(targetCoords)
    lastLocation = GetEntityCoords(PlayerPedId())
    SetEntityCoords(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
end)

RegisterNetEvent("vorp_admin:sendAdminBack", function()
    if lastLocation then
        SetEntityCoords(PlayerPedId(), lastLocation.x, lastLocation.y, lastLocation.z, false, false, false, false)
        lastLocation = nil
    end
end)

RegisterNetEvent("vorp_admin:Bring", function(adminCoords)
    lastLocation = GetEntityCoords(PlayerPedId())
    SetEntityCoords(PlayerPedId(), adminCoords.x, adminCoords.y, adminCoords.z, false, false, false, false)
end)

RegisterNetEvent("vorp_admin:TeleportPlayerBack", function()
    if lastLocation then
        SetEntityCoords(PlayerPedId(), lastLocation.x, lastLocation.y, lastLocation.z, false, false, false, false)
        lastLocation = nil
    end
end)
-----------------------------------------------------------------------------

-- Show items inventory
RegisterNetEvent("vorp_admin:getplayerInventory", function(inventorydata)
    OpenInventory(inventorydata)
end)

-------------------------- Troll Actions Events ------------------------------
RegisterNetEvent('vorp_admin:ClientTrollKillPlayerHandler', function()
    SetEntityHealth(PlayerPedId(), 0, 0)
end)

RegisterNetEvent('vorp_admin:ClientTrollInvisbleHandler', function()
    local player = PlayerPedId()
    if IsEntityVisible(player) then
        SetEntityVisible(player, false)
    else
        SetEntityVisible(player, true)
    end
end)

RegisterNetEvent('vorp_admin:ClientTrollLightningStrikePlayerHandler', function(coords)
    ForceLightningFlashAtCoords(coords.x, coords.y, coords.z, -1.0)
end)

RegisterNetEvent('vorp_admin:ClientTrollSetPlayerOnFireHandler', function()
    local model = 'p_campfire02xb'
    if not HasModelLoaded(model) then
        RequestModel(model, false)
        repeat Wait(0) until HasModelLoaded(model)
    end
    local object = CreateObject(joaat(model), 0, 0, 0, false, false, false)
    repeat Wait(0) until DoesEntityExist(object)
    AttachEntityToEntity(object, PlayerPedId(), 41, 1000, 1000, 10000, 0, 0, 0, false, false, true, false, 1000, false, false, false)
    Wait(5000)
    DeleteObject(object)
end)

RegisterNetEvent('vorp_admin:ClientTrollTPToHeavenHandler', function()
    local pl = GetEntityCoords(PlayerPedId())
    SetEntityCoords(PlayerPedId(), pl.x, pl.y, pl.z + 200, false, false, false, false)
end)

RegisterNetEvent('vorp_admin:ClientTrollRagdollPlayerHandler', function()
    SetPedToRagdoll(PlayerPedId(), 5000, 5000, 0, false, false, false)
end)

RegisterNetEvent('vorp_admin:ClientDrainPlayerStamHandler', function()
    Citizen.InvokeNative(0xC3D4B754C0E86B9E, PlayerPedId(), -1000.0)
end)

RegisterNetEvent('vorp_admin:ClientHandcuffPlayerHandler', function()
    local player = PlayerPedId()
    if not IsPedCuffed(player) then
        SetEnableHandcuffs(player, true, false)
    else
        SetEnableHandcuffs(player, false, false)
    end
end)

RegisterNetEvent('vorp_admin:ClientTempHighPlayerHandler', function()
    AnimpostfxPlay('MP_BountyLagrasSwamp')
    Wait(15000)
    AnimpostfxStop('MP_BountyLagrasSwamp')
end)
