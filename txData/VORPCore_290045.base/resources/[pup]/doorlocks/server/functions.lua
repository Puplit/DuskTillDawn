--- Is this player staff for door purposes?
--- vorp_admin's permission system is the authority (Discord roles, then groups).
--- ACE and the VORP group are only consulted when vorp_admin is not running.
---@param src number
---@param aceName string|nil the ACE fallback for this action
---@param groupName string|nil the VORP group fallback
---@return boolean
function DoorAdmin(src, aceName, groupName)
    if GetResourceState('vorp_admin') == 'started' then
        local ok, allowed = pcall(function()
            return exports['vorp_admin']:hasPermission(src, Config.Integrations.vorpAdmin.permission or 'manage_doorlocks')
        end)
        if ok then return allowed == true end
    end

    if aceName and IsPlayerAceAllowed(src, aceName) then return true end
    if groupName then
        local user = Core.getUser(src)
        if user and user.getGroup == groupName then return true end
    end
    return false
end

---Calculates the center position for double doors and returns the door object
---@param doorid number
---@param data table
---@return table
function InitDoor(doorid, data)
    local response = {}
    response.doorid = doorid
    response.name = data.name

    if data.isDouble or data.doors then
        local doors = data.door or data.doors

        doors[1].coords = vec3(doors[1].coords.x, doors[1].coords.y, doors[1].coords.z)
        doors[2].coords = vec3(doors[2].coords.x, doors[2].coords.y, doors[2].coords.z)

        response.coords = doors[1].coords - ((doors[1].coords - doors[2].coords) / 2)
        response.doors = doors
    else
        response.coords = vec3(data.door.coords.x, data.door.coords.y, data.door.coords.z)
        response.door = data.door
    end

    -- Make sure job access table is the correct format
    for name, rank in next, data.jobAccess do
        data.jobAccess[name] = tonumber(rank) or 0
    end

    response.itemNameAccess = data.itemNameAccess or false
    response.jobAccess = data.jobAccess
    response.charAccess = data.charAccess
    response.locked = data.lockedOnStart
    response.lockedOnStart = data.lockedOnStart
    response.canLockpick = data.canLockpick
    response.alertLaw = data.alertLaw
    response.showPrompt = data.showPrompt

    return response
end

---Updates info about the door annd sends updated info to clients
---@param doorid number
---@param param string
---@param value any
function UpdateDoor(doorid, param, value)
    if not Doors[doorid] then return end
    
    -- a no-op still has to be broadcast so a drifted client is corrected; only the DB write is skipped
    if Doors[doorid][param] == value then
        TriggerClientEvent('pup-doorlocks:client:UpdateDoor', -1, doorid, param, value)
        return
    end

    Doors[doorid][param] = value

    -- BROADCAST FIRST, AND NEVER ON THE DATABASE'S TERMS
    TriggerClientEvent('pup-doorlocks:client:UpdateDoor', -1, doorid, param, value)

    MySQL.update('UPDATE `doorlock_doors` SET `data` = ? WHERE `doorid` = ?',
        {json.encode(Doors[doorid]), doorid})

    if param == 'name' then
        MySQL.update('UPDATE `doorlock_doors` SET `name` = ? WHERE `doorid` = ?', {value, doorid})
    end
end

---Updates the iinfo about a door and sends the updated info to clients
---@param doorid number
---@param data table
function BulkUpdateDoor(doorid, data)
    if not Doors[doorid] then return end

    Doors[doorid].name = data.name
    Doors[doorid].locked = data.locked
    Doors[doorid].coords = data.coords
    Doors[doorid].charAccess = data.charAccess
    Doors[doorid].jobAccess = data.jobAccess
    Doors[doorid].lockedOnStart = data.lockedOnStart
    Doors[doorid].canLockpick = data.canLockpick
    Doors[doorid].showPrompt = data.showPrompt

    MySQL.update('UPDATE `doorlock_doors` SET `data` = ? WHERE `doorid` = ?', {json.encode(Doors[doorid]), doorid},
    function(records)
        if records > 0 then
            TriggerClientEvent('pup-doorlocks:client:UpdatedDoor', -1, Doors[doorid])
        end
    end)
end

--- Deletes a door from the database and sends the info to clients
---@param doorid number
function RemoveDoor(doorid)
    if not Doors[doorid] then return end

    MySQL.update('DELETE FROM `doorlock_doors` WHERE `doorid` = ?', {doorid},
    function(records)
        if records > 0 then
            Doors[doorid] = nil
            TriggerClientEvent('pup-doorlocks:client:DeletedDoor', -1, doorid)
        end
    end)
end

--- Get class for a door by hash
--- @param hash number
--- @return number | nil
function DoorByHash(hash)
    for doorid, data in next, Doors do
        if data.doors then
            for i = 1, 2 do
                if data.doors[i].hash == hash then
                    return doorid
                end
            end
        else
            if data.door.hash == hash then
                return doorid
            end
        end
    end

    return nil
end

--- Get class for a door by name
--- @param name string
--- @return table | nil | table[]
function DoorsByName(name)
    local found = {}
    for doorid, data in next, Doors do
        if data.name == name then
            table.insert(found, doorid)
        end
    end
    return found
end
