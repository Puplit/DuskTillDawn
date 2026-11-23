Core = exports.vorp_core:GetCore()
-- MenuData is ALREADY SET by client/aa_menucompat.lua (loads first via the glob)
MenuData = MenuData or nil
local function fetchMenuData()
    -- the LOCAL copy (aa_menucompat.lua) already set MenuData; never replace a working table
    if MenuData ~= nil then return end
    local ok, data = pcall(function() return exports['pup-ui']:GetMenuData() end)
    if ok and type(data) == 'table' and data.Open ~= nil then
        MenuData = data
        return
    end
    TriggerEvent('menuapi:getData', function(data2) MenuData = data2 end)
end
fetchMenuData()

AddEventHandler('onClientResourceStart', function(res)
    if res == 'pup-ui' then
        CreateThread(function()
            -- do NOT nil MenuData here - it points at the LOCAL compat copy
            Wait(1000)
            fetchMenuData()
        end)
    end
end)

-- Global: menu.lua gates every menu open on this
function EnsureMenuData()
    if MenuData ~= nil then return true end
    for _ = 1, 100 do -- ~2s ceiling
        fetchMenuData()
        if MenuData ~= nil then return true end
        Wait(20)
    end
    -- self-diagnose: report it if pup-ui is started but not answering
    print(('^1[doorlocks]^7 pup-ui never answered menuapi:getData. pup-ui state: %s. If "started", menucompat.lua failed to load - check F8 for its sentinel line.'):format(tostring(GetResourceState('pup-ui'))))
    return false
end
Doors = {}
DoorEnities = {}
ClosestDoor = nil

local Blips = {}

-- no RDR2 prompt bar: the floating key cap (pup-ui) is the whole UI

---Event triggered when player selects their character
---@param doors table
RegisterNetEvent('pup-doorlocks:client:LoadData', function(doors)
    DevPrint('Loading doors', json.encode(doors))

    for doorid, door in next, doors do
        Doors[doorid] = door
        SetupDoor(door)
    end
end)

---Event triggered when a new door is added
---@param data table
RegisterNetEvent('pup-doorlocks:client:AddedDoor', function(data)
    DevPrint('Added door', json.encode(data))

    -- record it even out of session, or later locks are dropped by the `not Doors[doorid]` guard
    Doors[data.doorid] = data
    if LocalPlayer.state.IsInSession then SetupDoor(data) end
end)

---Event triggered when a door is updated (single param)
---@param doorid number
---@param param string
---@param value any
RegisterNetEvent('pup-doorlocks:client:UpdateDoor', function(doorid, param, value)
    DevPrint('Updated door', doorid, param, value)

    if not Doors[doorid] then return end

    -- RECORD THE CHANGE EVEN WHEN OUT OF SESSION
    Doors[doorid][param] = value

    if param == 'locked' and LocalPlayer.state.IsInSession then
        UpdateDoorState(doorid)
    end
end)

-- catch the world up after time out of session; updates that arrived meanwhile could not touch the door natives
CreateThread(function()
    local was = LocalPlayer.state.IsInSession
    while true do
        Wait(1000)
        local now = LocalPlayer.state.IsInSession
        if now and not was then
            DevPrint('back in session - re-asserting door states')
            -- a new character can have different staff rights
            RefreshStaffOverride()
            for doorid in next, Doors do
                UpdateDoorState(doorid)
            end
        end
        was = now
    end
end)

-- first resolve: the session watcher only fires on a transition
CreateThread(function()
    while not LocalPlayer.state.IsInSession do Wait(500) end
    Wait(2000) -- let vorp_admin finish loading its permissions
    RefreshStaffOverride()
end)

---Event triggered when a door is updated (full table)
---@param data table
RegisterNetEvent('pup-doorlocks:client:UpdatedDoor', function(data)
    DevPrint('Updated door', json.encode(data))

    Doors[data.doorid] = data
    if LocalPlayer.state.IsInSession then UpdateDoorState(data.doorid) end
end)

---Event triggered when a door is removed
---@param doorid number
RegisterNetEvent('pup-doorlocks:client:DeletedDoor', function(doorid)
    DevPrint('Removed door', doorid)
    if not LocalPlayer.state.IsInSession then return end
    RemoveDoor(doorid)
    Doors[doorid] = nil
end)

-- Event triggered when the create door command is executed
RegisterNetEvent('pup-doorlocks:client:CreateDoor', function()
    OpenLockMenu(true)
end)

-- Event triggered when the edit door command is executed
RegisterNetEvent('pup-doorlocks:client:EditDoor', function()
    if not ClosestDoor then
        DoorNotify('interaction', _('no_door_nearby'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
        return
    end

    -- Format the door data for the menu
    local data <const> = Doors[ClosestDoor.doorid]

    local edit = {
        doorid = data.doorid,
        name = data.name,
        jobAccess = data.jobAccess,
        charAccess = data.charAccess,
        itemNameAccess = data.itemNameAccess,
        lockedOnStart = data.lockedOnStart,
        canLockpick = data.canLockpick,
        alertLaw = data.alertLaw,
        showPrompt = data.showPrompt
    }

    OpenLockMenu(edit)
end)

---Event triggered when an alert is triggered for law enforcement
---@param doorid number
RegisterNetEvent('pup-doorlocks:client:AlertLaw', function(doorid)
    if not LocalPlayer.state.IsInSession then return end
    if not Doors[doorid] then return end
    
    local data = Doors[doorid]
    local coords = data.coords

    -- Check if the player is within the alert distance
    if #(U.Cache.Coords - coords) > Config.LawAlert.radius then
        return
    end

    -- Check if the player has the required job
    if not U.table.contains(Config.LawAlert.jobs, LocalPlayer.state.Character.Job) then
        return
    end

    local notification = Config.LawAlert.notification
    local blip =  Config.LawAlert.blip

    -- Notify the player
    Core.NotifyLeft(notification.title, notification.title, notification.dict, notification.icon, notification.durationMs, notification.color)

    -- Create a blip for the alert (This will be wiped on resource stop and periodically in a thread below)
    local rawBlip = BlipAddForRadius(blip.hash, coords.x, coords.y, coords.z, blip.radius)
    SetBlipName(rawBlip, notification.title)
    Blips[#Blips+1] = {
        blip = rawBlip,
        time = GetGameTimer() + blip.durationMs
    }
end)

local pickBusy = false

---The server accepted a pick: play it and send the result back with its ticket
---@param doorid number
---@param ticket string
RegisterNetEvent('pup-doorlocks:client:LockpickDoor', function(doorid, ticket)
    if not LocalPlayer.state.IsInSession then return end
    local data = Doors[doorid]
    if not data or not data.locked or pickBusy then return end
    pickBusy = true

    LockpickAnimation(data.coords)

    -- the server decides the door and the lockpick
    local settled = false
    local function finish(success)
        if settled then return end
        settled = true
        ClearPedTasks(U.Cache.Ped)
        pickBusy = false
        TriggerServerEvent('pup-doorlocks:server:LockpickResult', ticket, success)
    end
    -- a game that never answers must not leave the pick stuck
    SetTimeout(tonumber(Config.Lockpicking.maxTimeMs) or 180000, function() finish(nil) end)

    if Config.Lockpicking.minigame then
        LockpickGame(finish)
    else
        Wait(2500)
        finish(true)
    end
end)

---@param opened boolean
RegisterNetEvent('pup-doorlocks:client:LockpickDone', function(opened)
    if opened then
        DoorSound('unlock')
        return
    end
    DoorSound('denied')
    DoorNotify('lockpick', _('lockpick_fail'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
end)

-- the lockpick item is the only way in without a key; the server re-checks the door and the item
RegisterNetEvent('pup-doorlocks:client:UseLockpick', function()
    if not LocalPlayer.state.IsInSession then return end

    local function refuse(key)
        DoorNotify('lockpick', _(key), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    end

    if not ClosestDoor then return refuse('no_door_nearby') end

    local data <const> = Doors[ClosestDoor.doorid]
    if not data then return refuse('no_door_nearby') end

    local reach = tonumber(Config.Interaction.reachRadius) or Config.Interaction.markerRadius
    if reach > Config.Interaction.markerRadius then reach = Config.Interaction.markerRadius end
    if ClosestDoor.distance > reach then return refuse('no_door_nearby') end

    if not data.locked or not data.canLockpick then return refuse('cannot_lockpick') end

    -- a keyholder has no reason to pick their own lock
    if (HasJobAccess(data.jobAccess) and HasCharAccess(data.charAccess)) or HasStaffOverride() then
        return refuse('cannot_lockpick')
    end

    DevPrint('Lockpicking door', data.doorid)
    TriggerServerEvent('pup-doorlocks:server:LockpickDoor', data.doorid)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        HideDoorMarker()

        --- Clear/Remove doors
        for doorid, door in next, Doors do
            RemoveDoor(doorid)
        end

        --- Clear any blips so they dont get stuck
        for i = 1, #Blips do
            RemoveBlip(Blips[i].blip)
        end

    end
end)

-- SetupDoor sets a door's state when it loads and the toggle sets it again when it changes
local EnforceList = {}  -- refreshed by the scan loop: locked doors within range
local ClosedRot = {}    -- [hash] = rotation captured while the door was properly shut

local Registered = {}   -- [hash] = GetGameTimer() of the last AddDoorToSystem

local function enforceDoorHash(hash)
    if not hash then return end

    -- register before reading: an unregistered door reports ratio 0.0 (shut) even when open; re-asserted every 2s
    local now = GetGameTimer()
    if not Registered[hash] or (now - Registered[hash]) > 2000 then
        AddDoorToSystem(hash, true, true, false, 0, 0, false)
        Registered[hash] = now
    end

    local entity = GetEntityByDoorhash(hash, 0)
    local ratio = DoorSystemGetOpenRatio(hash)

    if ratio == 0.0 then
        -- learn what "closed" looks like, so a drifted door can be put back
        if entity ~= 0 and not ClosedRot[hash] then
            ClosedRot[hash] = GetEntityRotation(entity, 2)
        end
    else
        -- shut it before locking it: a locked door will not move
        DoorSystemSetDoorState(hash, 0)
        DoorSystemSetOpenRatio(hash, 0.0, false, false)
        local rot = ClosedRot[hash]
        if entity ~= 0 and rot then
            SetEntityRotation(entity, rot.x, rot.y, rot.z, 2, true)
        end
    end

    if DoorSystemGetDoorState(hash) ~= 1 then
        DoorSystemSetDoorState(hash, 1)
    end
end

CreateThread(function()
    while true do
        Wait(Config.Enforcement.intervalMs or 200)
        if Config.Enforcement.enabled ~= false and LocalPlayer.state.IsInSession then
            for i = 1, #EnforceList do
                local e = EnforceList[i]
                -- RE-CHECK the lock here, do not trust the list
                local door = Doors[e.doorid]
                if door and door.locked then
                    enforceDoorHash(e.hash)
                end
            end
        end
    end
end)

CreateThread(function()
    if LocalPlayer.state.IsInSession then
        Wait(2500)
        TriggerServerEvent('pup-doorlocks:server:LoadData')
    end

    while true do
        Wait(1000)

        local Closest = nil
        local ClosestDist = nil
        
        if not LocalPlayer.state.IsInSession then
            goto continue
        end

        table.wipe(DoorEnities) -- Clear the door entities, memory performance?
        table.wipe(EnforceList) -- rebuilt below with the locked doors in range

        local enforceDist = Config.Enforcement.radius or 25.0

        for doorid, data in next, Doors do
            -- Ignore anything > 50 meters. No need to check everything in existance... performance?
            local dist = #(U.Cache.Coords - data.coords)
            if dist < 50 then

                if data.doors then
                    for i = 1, 2 do
                        local entity = GetEntityByDoorhash(data.doors[i].hash, 0)

                        if entity ~= 0 then
                            DoorEnities[entity] = doorid
                        end
                    end

                    -- Find the objects center point to place the sprite (if enabled) (Calculated server-side)
                    data.center = vec3(data.coords.x, data.coords.y, data.coords.z + 1.0)
                else
                    local entity = GetEntityByDoorhash(data.door.hash, 0)

                    if entity ~= 0 then
                        DoorEnities[entity] = doorid

                        -- Find the objects center point to place the sprite (if enabled)
                        local calc = CalculateModelCenterPoint(entity, data.door.model)
                        data.center = vec3(calc.x, calc.y, data.coords.z + 1.0)
                    end
                end

                -- queue locked doors in range for the enforcement thread
                if data.locked and dist < enforceDist then
                    if data.doors then
                        EnforceList[#EnforceList + 1] = { doorid = doorid, hash = data.doors[1].hash }
                        EnforceList[#EnforceList + 1] = { doorid = doorid, hash = data.doors[2].hash }
                    else
                        EnforceList[#EnforceList + 1] = { doorid = doorid, hash = data.door.hash }
                    end
                end

                -- Find the closest door to the player... I'm sure theres a million ways to do this

                if not ClosestDist or dist < ClosestDist then
                    ClosestDist = dist
                    Closest = {doorid = doorid, distance = dist}
                end
            end
        end

        -- Clear blips that have expired
        if #Blips > 0 then
            for k, v in next, Blips do
                if v.time < GetGameTimer() then
                    RemoveBlip(v.blip)
                    table.remove(Blips, k)
                end
            end
        end

        ClosestDoor = Closest

        ::continue::
    end
end)

-- does this character hold a key? compare as numbers: "7" and 7 never match with ==
function HasJobAccess(jobAccess)
    if type(jobAccess) ~= 'table' then return true end
    if next(jobAccess) == nil then return true end

    local char <const> = LocalPlayer.state.Character
    if not char then return false end

    local required <const> = jobAccess[char.Job]
    if required ~= nil then
        return (tonumber(char.Grade) or 0) >= (tonumber(required) or 0)
    end

    -- a door saved before the map shape existed stored a plain list of job names with no grade
    return U.table.contains(jobAccess, char.Job)
end

-- staff who may open anything (Config.Admin.openAll); cached, since the marker loop runs every frame
local staffOverride = false

function RefreshStaffOverride()
    if not (Config.Admin.openAll and Config.Admin.openAll.enabled) then
        staffOverride = false
        return
    end

    if GetResourceState('vorp_admin') == 'started' then
        local ok, allowed = pcall(function()
            return Core.Callback.TriggerAwait('vorp_admin:CanOpenStaffMenu',
                Config.Integrations.vorpAdmin.permission or 'manage_doorlocks')
        end)
        if ok and allowed == true then
            staffOverride = true
            return
        end
    end

    local char <const> = LocalPlayer.state.Character
    staffOverride = (char and char.Group ~= nil and char.Group == Config.Admin.openAll.group) or false
end

function HasStaffOverride()
    return staffOverride
end

function HasCharAccess(charAccess)
    if type(charAccess) ~= 'table' then return true end
    if #charAccess == 0 then return true end

    local char <const> = LocalPlayer.state.Character
    local myChar <const> = tonumber(char and char.CharId)
    if not myChar then return false end

    for i = 1, #charAccess do
        if tonumber(charAccess[i]) == myChar then return true end
    end
    return false
end

local function DoorKeyPressed()
    return IsControlJustReleased(0, Config.Keys.toggleLock)
end

-- what the key cap should read, or nil for nothing; lockpicking starts from the inventory item
local function MarkerState(data, hasAccess)
    local M <const> = Config.Marker or {}
    local L <const> = M.labels or {}

    if hasAccess then
        return { key = M.key or 'E', text = data.locked and (L.unlock or 'Unlock') or (L.lock or 'Lock') }
    end
    if not data.locked then return nil end
    -- locked and no key: say so, offer nothing. labels.locked = false to say nothing.
    if not L.locked then return nil end
    return { text = L.locked, tone = 'denied' }
end

CreateThread(function()
    local drawn = false
    while true do
        local sleep = 1000
        local showing = false

        if ClosestDoor and ClosestDoor.distance <= Config.Interaction.markerRadius then
            local data = Doors[ClosestDoor.doorid]

            -- showPrompt is not consulted, so doors saved with it off stay usable
            if data and not IsPedDeadOrDying(U.Cache.Ped, false) and not SelectionActive then
                sleep = 0

                local isJob <const> = HasJobAccess(data.jobAccess)
                local isChar <const> = HasCharAccess(data.charAccess)
                local hasAccess <const> = (isJob and isChar) or HasStaffOverride()

                local promptDist = tonumber(Config.Interaction.reachRadius) or Config.Interaction.markerRadius
                if promptDist > Config.Interaction.markerRadius then promptDist = Config.Interaction.markerRadius end
                local inReach <const> = ClosestDoor.distance <= promptDist

                if (Config.Marker or {}).enabled ~= false then
                    local state <const> = MarkerState(data, hasAccess)
                    if state then showing = DrawDoorMarker(data.center, state) end
                end

                if inReach and DoorKeyPressed() then
                    if hasAccess then
                        DevPrint('Toggling door', data.doorid)
                        DoorSound(data.locked and 'unlock' or 'lock')
                        TriggerServerEvent('pup-doorlocks:server:ToggleDoorStatus', data.doorid, not data.locked)
                    elseif data.locked then
                        DoorSound('denied') -- the handle moves, the bolt does not
                    end
                end
            end
        end

        if drawn and not showing then HideDoorMarker() end
        drawn = showing
        Wait(sleep)
    end
end)

RegisterCommand(Config.General.toggleCommand, function()
    if not ClosestDoor then
        DoorNotify('interaction', _('no_door_nearby'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
        return
    end

    local data = Doors[ClosestDoor.doorid]

    -- THE SERVER DECIDES, NOT THIS
    local believesAccess = (HasJobAccess(data.jobAccess) and HasCharAccess(data.charAccess))
        or HasStaffOverride()

    if believesAccess then
        DoorSound(data.locked and 'unlock' or 'lock')
    end
    TriggerServerEvent('pup-doorlocks:server:ToggleDoorStatus', data.doorid, not data.locked)
end)
