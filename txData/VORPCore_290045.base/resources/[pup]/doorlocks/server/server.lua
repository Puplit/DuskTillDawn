Core = exports.vorp_core:GetCore()
Doors = {}

while not DatabaseReady do
    Wait(100)
end

---Event triggered when player selects their character
AddEventHandler("vorp:SelectedCharacter",function(source)
    TriggerClientEvent('pup-doorlocks:client:LoadData', source, Doors)
end)

-- The prompt shows within 2 m. This leaves room for lag and a double door's width.
local DOOR_REACH <const> = 15.0

-- one open pick per player: a ticket from LockpickDoor, used once by LockpickResult
local picking = {}   -- [src] = { ticket, doorid, itemId, at }
local lastPick = {}
local lastLoad = {}
local ticketSeq = 0

AddEventHandler('playerDropped', function()
    picking[source], lastPick[source], lastLoad[source] = nil, nil, nil
end)

local function nearDoor(src, door, reach)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not door.coords then return false end
    return #(GetEntityCoords(ped) - door.coords) <= (reach or DOOR_REACH)
end

local function pickReach()
    return tonumber(Config.Lockpicking.reach) or 3.0
end

---Event triggered from client when resources is re/started and player is logged in
RegisterNetEvent('pup-doorlocks:server:LoadData', function()
    local _source = source
    -- the whole door list, and a real client asks once
    local nowMs = GetGameTimer()
    if lastLoad[_source] and nowMs - lastLoad[_source] < 5000 then return end
    lastLoad[_source] = nowMs
    TriggerClientEvent('pup-doorlocks:client:LoadData', _source, Doors)
end)

---Create Door
---@param data table
---@param isExport boolean
RegisterNetEvent('pup-doorlocks:server:CreateDoor', function(data, isExport)
    local _source = source
    local User <const> = Core.getUser(_source)
    if not User then return end
    local Group <const> = User.getGroup

    if not DoorAdmin(_source, Config.Admin.create.ace, Config.Admin.create.group) then
        return
    end

    local insertId = MySQL.insert.await('INSERT INTO `doorlock_doors` ( `name` ) VALUES ( ? )', { data.name })

    if insertId then
        local door = InitDoor(insertId, data)
        
        MySQL.update('UPDATE doorlock_doors SET data = ? WHERE doorid = ?', {json.encode(door), insertId})

        Doors[insertId] = door

        TriggerClientEvent('pup-doorlocks:client:AddedDoor', -1, door)

        if isExport then
            TriggerClientEvent('pup-doorlocks:client:AddedDoorExport', _source, insertId)
        end

        DoorNotify('admin', _source, _('door_created'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_GREEN', 1500)
    else

        if isExport then
            TriggerClientEvent('pup-doorlocks:client:AddedDoorExport', _source)
        end

        DoorNotify('admin', _source, _('failed_to_update'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    end
end)

---Delete Door
---@param doorid number
RegisterNetEvent('pup-doorlocks:server:DeleteDoor', function(doorid)
    local _source = source
    local User <const> = Core.getUser(_source)
    if not User then return end
    local Group <const> = User.getGroup

    if not DoorAdmin(_source, Config.Admin.create.ace, Config.Admin.create.group) then
        return
    end

    local door = Doors[doorid]

    if not door then
        DoorNotify('admin', _source, _('door_not_found'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
        return
    end

    MySQL.update('DELETE FROM doorlock_doors WHERE doorid = ?', {doorid},
    function(records)
        if records > 0 then
            Doors[doorid] = nil
            TriggerClientEvent('pup-doorlocks:client:DeletedDoor', -1, doorid)
            DoorNotify('admin', _source, _('door_deleted'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_GREEN', 1500)
        else
            DoorNotify('admin', _source, _('failed_to_update'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
        end
    end)
    
end)

---Update Door
---@param data table
RegisterNetEvent('pup-doorlocks:server:UpdateDoor', function(data)
    local _source = source
    local User <const> = Core.getUser(_source)
    if not User then return end
    local Group <const> = User.getGroup

    if not DoorAdmin(_source, Config.Admin.create.ace, Config.Admin.create.group) then
        return
    end

    local door = Doors[data.doorid]

    if not door then
        DoorNotify('admin', _source, _('door_not_found'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
        return
    end 

    door.name = data.name
    door.jobAccess = data.jobAccess
    door.charAccess = data.charAccess
    door.itemNameAccess = data.itemNameAccess
    door.lockedOnStart = data.lockedOnStart
    door.canLockpick = data.canLockpick
    door.alertLaw = data.alertLaw
    door.showPrompt = data.showPrompt

    MySQL.update('UPDATE doorlock_doors SET data = ? WHERE doorid = ?', {json.encode(door), data.doorid},
    function(records)
        if records > 0 then
            TriggerClientEvent('pup-doorlocks:client:UpdatedDoor', -1, door)
            DoorNotify('admin', _source, _('door_updated'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_GREEN', 1500)
        else
            DoorNotify('admin', _source, _('failed_to_update'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
        end
    end)
end)

-- keys, jobs, items and staff only; a lockpick opens a door through LockpickResult
RegisterNetEvent('pup-doorlocks:server:ToggleDoorStatus', function(doorid, status)
    local _source = source
    local User <const> = Core.getUser(_source)
    if not User then return end

    local Character <const> = User.getUsedCharacter
    if not Character then return end

    local Group <const> = User.getGroup
    local Job <const> = Character.job
    local JobGrade <const> = Character.jobGrade

    local door = Doors[doorid]

    if not door then return end

    local CanAccess = false

    if door.itemNameAccess then
        if exports.vorp_inventory:getItemByName(_source, door.itemNameAccess) then
            CanAccess = true
            DevPrint('Item Access', door.itemNameAccess, 'Door', doorid)
        end
    end

    if not CanAccess and door.jobAccess and door.jobAccess[Job] and door.jobAccess[Job] <= (tonumber(JobGrade) or 0) then
        CanAccess = true
        DevPrint('Job Access', Job, 'Door', doorid)
    end

    if not CanAccess and door.charAccess and #door.charAccess > 0 and U.table.contains(door.charAccess, Character.charIdentifier) then
        CanAccess = true
        DevPrint('Character Access', Character.charIdentifier, 'Door', doorid)
    end

    local byStaff = false
    if not CanAccess and Config.Admin.openAll.enabled then
        if DoorAdmin(_source, Config.Admin.openAll.ace, Config.Admin.openAll.group) then
            CanAccess = true
            byStaff = true
            if Config.Admin.openAll.consoleLog then
                print('Player', _source, 'Opened/Closed Door', doorid, 'With OpenAllDoors')
            end
        end
    end

    if not CanAccess then 
        return DoorNotify('interaction', _source, _('no_perms'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    end

    -- keys work at the door, not from across the map. Staff's open-all still reaches anywhere.
    if not byStaff and not nearDoor(_source, door) then
        return DoorNotify('interaction', _source, _('no_perms'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    end

    status = status == true

    UpdateDoor(doorid, 'locked', status)

    if door.locked then
        DoorNotify('interaction', _source, _('locked'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    else
        DoorNotify('interaction', _source, _('unlocked'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_GREEN', 1500)  
    end
end)

-- lockpicking starts from the item; the client picks the nearest door and this re-checks it
CreateThread(function()
    local item <const> = Config.Lockpicking and Config.Lockpicking.itemName
    if not item or item == '' then return end
    while GetResourceState('vorp_inventory') ~= 'started' do Wait(250) end

    exports.vorp_inventory:registerUsableItem(item, function(data)
        local _source <const> = data.source
        exports.vorp_inventory:closeInventory(_source)
        TriggerClientEvent('pup-doorlocks:client:UseLockpick', _source)
    end)
end)

---Lockpick Door
---@param doorid number
RegisterNetEvent('pup-doorlocks:server:LockpickDoor', function(doorid)
    local _source = source
    local User <const> = Core.getUser(_source)
    if not User then return end

    local Character <const> = User.getUsedCharacter
    if not Character then return end

    local door = Doors[doorid]
    local L <const> = Config.Lockpicking

    if not door then return end
    if not L.itemName or L.itemName == '' then return end
    if not door.canLockpick or not door.locked then
        return DoorNotify('lockpick', _source, _('cannot_lockpick'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    end
    if not nearDoor(_source, door, pickReach()) then
        return DoorNotify('lockpick', _source, _('no_door_nearby'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    end

    -- each start can call the law, so a client can't fire it over and over
    local nowMs = GetGameTimer()
    if lastPick[_source] and nowMs - lastPick[_source] < (tonumber(L.cooldownMs) or 5000) then
        return DoorNotify('lockpick', _source, _('lockpick_wait'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    end
    lastPick[_source] = nowMs

    local lockpick = exports.vorp_inventory:getItemByName(_source, L.itemName)

    if lockpick then
        -- a new ticket replaces any open one
        ticketSeq = ticketSeq + 1
        local ticket = ('%d:%d'):format(ticketSeq, math.random(100000, 999999))
        picking[_source] = { ticket = ticket, doorid = doorid, itemId = lockpick.id, at = nowMs }
        TriggerClientEvent('pup-doorlocks:client:LockpickDoor', _source, doorid, ticket)

        -- Alert Law Enforcement
        if door.alertLaw and math.random(1, 100) <= Config.LawAlert.chance then
            -- through pup-mdt when it is running
            local sent = false
            if GetResourceState('pup-mdt') == 'started' then
                local okAlert = pcall(function()
                    -- door.coords is the stored centre (functions.lua computes it as the midpoint for double doors)
                    local c = door.coords or (door.doors and door.doors[1] and door.doors[1].coords)
                    exports['pup-mdt']:SendPoliceAlert(
                        c and { x = c.x, y = c.y, z = c.z } or nil,
                        ('Lock being picked%s'):format(door.name and door.name ~= '' and (' - ' .. door.name) or ''),
                        false,
                        false, -- anonymous: the dispatch does not name the lockpicker
                        door.name or 'Locked door'
                    )
                end)
                sent = okAlert
            end
            -- fallback when pup-mdt is stopped or restarting
            if not sent then
                TriggerClientEvent('pup-doorlocks:client:AlertLaw', -1, doorid)
            end
        end
    else
        DoorNotify('interaction', _source, _('no_lockpick'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
    end
end)

local function useUpLockpick(src, itemId)
    if exports.vorp_inventory:subItemById(src, itemId, nil, true, 1) then
        DoorNotify('interaction', src, _('lockpick_removed'), 'itemtype_textures', 'itemtype_all', 'COLOR_RED', 1500)
        return true
    end
    return false
end

---Lockpick result. The client only says won or lost; this decides the door and the lockpick.
---@param ticket string from LockpickDoor
---@param success boolean | nil nil = the game never started
RegisterNetEvent('pup-doorlocks:server:LockpickResult', function(ticket, success)
    local _source = source
    local pick = picking[_source]
    if not pick or type(ticket) ~= 'string' or ticket ~= pick.ticket then return end
    picking[_source] = nil -- used once, whatever the answer

    local L <const> = Config.Lockpicking
    local door = Doors[pick.doorid]
    local age = GetGameTimer() - pick.at

    if not door or age > (tonumber(L.maxTimeMs) or 180000) then return end
    if success == nil then return end -- no game, no cost
    if not door.locked then return end -- someone opened it meanwhile

    -- still carrying a lockpick (the stack id can change when items move)
    if not exports.vorp_inventory:getItemById(_source, pick.itemId) then
        local again = exports.vorp_inventory:getItemByName(_source, L.itemName)
        if not again then
            return DoorNotify('lockpick', _source, _('no_lockpick'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_RED', 1500)
        end
        pick.itemId = again.id
    end

    -- the quickest real game; with the minigame off the client waits about 2.5 s
    local minMs = tonumber(L.minTimeMs) or 4000
    if not L.minigame then minMs = math.min(minMs, 2000) end

    local opened = success == true
    if opened and age < minMs then
        print(('^3[doorlocks]^7 player %s reported a picked lock after %d ms (minimum %d); counted as a fail'):format(_source, math.floor(age), math.floor(minMs)))
        opened = false
    end
    if opened and (not door.canLockpick or not nearDoor(_source, door, pickReach())) then
        DevPrint('Lockpick refused: not lockpickable or too far', _source, pick.doorid)
        opened = false
    end

    if opened then
        if L.removeOnUse and not useUpLockpick(_source, pick.itemId) then opened = false end
    elseif L.removeOnFail then
        useUpLockpick(_source, pick.itemId)
    end

    if opened then
        UpdateDoor(pick.doorid, 'locked', false)
        DoorNotify('interaction', _source, _('unlocked'), 'BLIPS', 'blip_proc_home_locked', 'COLOR_GREEN', 1500)
    end

    TriggerClientEvent('pup-doorlocks:client:LockpickDone', _source, opened)
end)

if Config.Admin.create.enabled then
    RegisterCommand(Config.Admin.create.command, function(source, args)
        local hasPermission = false

        local User <const> = Core.getUser(source)
        if not User then return end
        local Group <const> = User.getGroup
        
        if DoorAdmin(source, Config.Admin.create.ace, Config.Admin.create.group) then
            hasPermission = true
        end

        if Group == Config.Admin.create.group then
            hasPermission = true
        end

        if not hasPermission then
            return
        end

        TriggerClientEvent('pup-doorlocks:client:CreateDoor', source)
    end)
end

if Config.Admin.edit.enabled then
    RegisterCommand(Config.Admin.edit.command, function(source, args)
        local hasPermission = false

        local User <const> = Core.getUser(source)
        if not User then return end
        local Group <const> = User.getGroup
        
        if DoorAdmin(source, Config.Admin.edit.ace, Config.Admin.edit.group) then
            hasPermission = true
        end

        if Group == Config.Admin.edit.group then
            hasPermission = true
        end

        if not hasPermission then
            return
        end

        TriggerClientEvent('pup-doorlocks:client:EditDoor', source)
    end)
end
