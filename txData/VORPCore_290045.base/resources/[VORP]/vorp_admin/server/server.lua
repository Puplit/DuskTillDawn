-- Modified by Puppet (Dusk Till Dawn), 2026
local stafftable = {}
local PlayersTable = {}
local T <const> = Translation.Langs[Config.General.language]

local function checkResourceStarted()
    local has_inventory_started <const> = GetResourceState("vorp_inventory") == "started"
    local has_core_started <const> = GetResourceState("vorp_core") == "started"
    if not has_inventory_started or not has_core_started then
        local resource_stopped <const> = not has_inventory_started and "vorp_inventory" or "vorp_core"
        error(("Resource %s is not started vorp_admin willstop"):format(resource_stopped))
    end
end

checkResourceStarted()

local Core <const> = exports.vorp_core:GetCore()

local function getUserData(User, _source)
    local Character = User.getUsedCharacter
    local group = Character.group

    local playername = (Character.firstname or "no name") .. ' ' .. (Character.lastname or "noname")
    local job = Character.job
    local identifier = Character.identifier
    local PlayerMoney = Character.money
    local PlayerGold = Character.gold
    local JobGrade = Character.jobGrade
    local getid = Core.Whitelist.getEntry(identifier)
    local getstatus = Core.Whitelist.getEntry(identifier)

    local data = {
        serverId = _source,
        name = GetPlayerName(_source),
        Group = group,
        PlayerName = playername,
        Job = job,
        SteamId = identifier,
        Money = PlayerMoney,
        Gold = PlayerGold,
        Grade = JobGrade,
        staticID = getid and tonumber(getid.id) or "no id",
        WLstatus = getstatus and tostring(getstatus.status) or "no status",
    }
    return data
end

-- Register CallBack
Core.Callback.Register("vorp_admin:Callback:getplayersinfo", function(_, cb, args)
    if next(PlayersTable) then
        if args.search == "search" then -- is for unique player
            if PlayersTable[args.id] then
                local User = Core.getUser(args.id)
                if User then
                    local data = getUserData(User, args.id)
                    PlayersTable[args.id] = data
                    return cb(PlayersTable[args.id])
                end
                return cb(false)
            else
                return cb(false)
            end
        end

        for id, _ in pairs(PlayersTable) do
            local User = Core.getUser(id)
            if User then
                local data = getUserData(User, id)
                PlayersTable[id] = data
            end
        end
        return cb(PlayersTable)
    end
    return cb(false)
end)


-- Every permission check in this resource goes through here (~100 call sites)
local function AllowedToExecuteAction(source, action)
    if not Core.getUser(source) then return end
    return HasPermission(source, action)
end

-- exported so other resources can honor the panel's permission keys (pup-societies' isSocietyAdmin accepts manage_society)
exports('allowedToExecuteAction', function(source, action)
    return AllowedToExecuteAction(source, action) == true
end)

-- EVENTS TELEPORTS -----------------------------
RegisterNetEvent("vorp_admin:TpToPlayer", function(targetID, _, name)
    local _source = source

    if not Core.getUser(targetID) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "tp_to_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local targetCoords = GetEntityCoords(GetPlayerPed(targetID))
    -- follow the player into their routing bucket (instanced players would otherwise be invisible at the arrival spot)
    SetPlayerRoutingBucket(_source, GetPlayerRoutingBucket(targetID))
    TriggerClientEvent('vorp_admin:gotoPlayer', _source, targetCoords)

    if name then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminGoto, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedgoto .. "\n> " .. name)
    else
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.teleportToPlayer, T.Webhooks.ActionTeleport.title, T.Webhooks.ActionTeleport.usedtptoplayer .. "\nID: " .. targetID)
    end
end)

-- INSTANCE control (panel "Instance" form). 0 = the shared world
RegisterNetEvent("vorp_admin:setInstance", function(targetID, bucket, name)
    local _source = source
    targetID = tonumber(targetID)
    bucket = math.max(0, math.floor(tonumber(bucket) or 0))

    if not targetID or not Core.getUser(targetID) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end
    if not AllowedToExecuteAction(_source, "tp_to_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    SetPlayerRoutingBucket(targetID, bucket)
    Core.NotifyRightTip(_source, ("Moved %s to instance %d%s"):format(name ~= '' and name or ('player ' .. targetID), bucket, bucket == 0 and " (shared world)" or ""), 5000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminGoto, T.Webhooks.ActionsAdmin.title,
        ("Set instance %d for player ID %s"):format(bucket, targetID))
end)

--SENDBACK
RegisterNetEvent("vorp_admin:sendAdminBack", function()
    local _source = source
    if not AllowedToExecuteAction(_source, "send_player_back") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:sendAdminBack', _source)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.teleportToPlayer, T.Webhooks.ActionTeleport.title,
        "Returned to their previous position")
end)


--FREEZE
RegisterNetEvent("vorp_admin:freeze", function(targetID, freeze, _, name)
    local _source = source
    local _target = targetID
    local state = freeze

    if not Core.getUser(_target) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "freeze_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerClientEvent("vorp_admin:Freezeplayer", targetID, state)

    if name then -- only log when is using freeze
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminFreeze, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedfreeze .. "\n> " .. name)
    end
end)
-- BRING
RegisterNetEvent("vorp_admin:Bring", function(targetID, adminCoords, _, name, target)
    local _source = source

    if not Core.getUser(targetID) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "bring_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    -- pull the player into the ADMIN's routing bucket
    SetPlayerRoutingBucket(targetID, GetPlayerRoutingBucket(_source))
    TriggerClientEvent("vorp_admin:Bring", targetID, adminCoords)

    if name then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminBring, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedbring .. "\n> " .. name)
    end

    if target then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.teleportBringPlayer, T.Webhooks.ActionTeleport.title, T.Webhooks.ActionTeleport.usedbringplayer .. "\nID: " .. target)
    end
end)

--TPBACK
RegisterNetEvent("vorp_admin:TeleportPlayerBack", function(targetID)
    local _source = source

    if not Core.getUser(targetID) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "tp_player_back") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerClientEvent('vorp_admin:TeleportPlayerBack', targetID)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.teleportToPlayer, T.Webhooks.ActionTeleport.title,
        ("Sent player back\nID: %s (%s)"):format(tostring(targetID), GetPlayerName(targetID) or "?"))
end)

-- ADVANCED ADMIN ACTIONS ---------------------------------------

-- KICK
RegisterNetEvent("vorp_admin:kick", function(target, reason, _, name)
    local _source = source

    if not Core.getUser(target) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "kick_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerClientEvent('vorp:updatemissioNotify', target, T.Notify.kickedNotify, T.Notify.kickedNotify, 5000)

    SetTimeout(5000, function()
        DropPlayer(target, reason)
    end)

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminKick, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedkick .. "\n > " .. name .. "\n: " .. reason)
end)


-- BAN
RegisterNetEvent("vorp_admin:BanPlayer", function(target, staticid, time, _, name)
    local _source = source

    local targetStaticId = tonumber(staticid)
    local datetime = os.time(os.date("!*t"))
    local banTime
    if not Core.getUser(target) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "ban_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    if time:sub(-1) == 'd' then
        banTime = tonumber(time:sub(1, -2))
        banTime = banTime * 24
    elseif time:sub(-1) == 'w' then
        banTime = tonumber(time:sub(1, -2))
        banTime = banTime * 168
    elseif time:sub(-1) == 'm' then
        banTime = tonumber(time:sub(1, -2))
        banTime = banTime * 720
    elseif time:sub(-1) == 'y' then
        banTime = tonumber(time:sub(1, -2))
        banTime = banTime * 8760
    else
        banTime = tonumber(time)
    end
    if banTime == 0 then
        datetime = 0
    else
        datetime = datetime + banTime * 3600
    end

    TriggerClientEvent('vorp:updatemissioNotify', target, T.Notify.bannedNotify, T.Notify.bannedNotify, 8000)
    SetTimeout(8000, function()
        TriggerEvent("vorpbans:addtodb", false, targetStaticId, datetime)
    end)

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminBan, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedban .. "\n > " .. name .. "\n: " .. time)
end)

-- RESPAWN
RegisterNetEvent("vorp_admin:respawnPlayer", function(target, _, name)
    local _source = source
    if not Core.getUser(target) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "respawn_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    exports.vorp_inventory:closeInventory(target)

    TriggerClientEvent('vorp:updatemissioNotify', target, T.Notify.respawnedNotify, T.Notify.lostAllItems, 8000)

    SetTimeout(5000, function()
        Core.Player.Respawn(target)
        TriggerClientEvent("vorp_admin:respawn", target) --add effects
    end)

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminRespawn, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedrespawn .. "\n > " .. name)
end)



-- DATABASE GIVE ITEM

RegisterNetEvent("vorp_admin:givePlayer", function(target, action, data1, data2, data3, _, name)
    local _source = source
    -- pup: log lines concatenate name; never let a caller's nil crash the handler
    name = name or GetPlayerName(target) or "?"
    local user <const> = Core.getUser(target)
    if not user then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "give_" .. action) then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local Character <const> = user.getUsedCharacter

    if action == "item" then
        local item <const> = data1
        local qty <const> = data2

        if not qty or not item then
            return Core.NotifyRightTip(_source, T.Notify.invalidAdd, 5000)
        end

        local itemCheck <const> = exports.vorp_inventory:getItemDB(item)
        local canCarryItem <const> = exports.vorp_inventory:canCarryItem(target, item, qty)

        if not itemCheck then
            return Core.NotifyRightTip(_source, T.Notify.doesNotExistInDB, 5000)
        end

        if not canCarryItem then
            return Core.NotifyRightTip(_source, T.Notify.itemLimit, 5000)
        end

        exports.vorp_inventory:addItem(target, item, qty)

        Core.NotifyRightTip(target, T.Notify.receivedItem .. qty .. T.Notify.of .. itemCheck.label .. "~q~", 5000)
        Core.NotifyRightTip(_source, T.Notify.itemGiven, 4000)

        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseGiveItem, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedgiveitem .. "\nPlayer: " .. name .. "\nItem: " .. item .. "\nQTY: " .. qty)

        return
    end

    if action == "weapon" then
        local weapon <const> = data1

        local canCarryWeapons <const> = exports.vorp_inventory:canCarryWeapons(target, 1, nil, weapon)

        if not canCarryWeapons then
            return Core.NotifyRightTip(_source, T.Notify.cantCarryWeapon, 5000)
        end

        exports.vorp_inventory:createWeapon(target, weapon)

        Core.NotifyRightTip(target, T.Notify.receivedWeapon, 5000)
        Core.NotifyRightTip(_source, T.Notify.weaponGiven, 4000)

        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseGiveWeapon, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedgiveweapon .. "\nPlayer: " .. name .. "\nWeapon: " .. weapon)

        return
    end

    if action == "moneygold" then
        local CurrencyType <const> = data1
        local qty <const> = data2

        if not qty then
            return Core.NotifyRightTip(_source, T.Notify.addQuantity, 5000)
        end

        Character.addCurrency(tonumber(CurrencyType), tonumber(qty))

        if CurrencyType == 0 then
            Core.NotifyRightTip(target, T.Notify.receivedItem .. qty .. T.Notify.money, 5000)
        elseif CurrencyType == 1 then
            Core.NotifyRightTip(target, T.Notify.receivedItem .. qty .. T.Notify.gold, 5000)
        elseif CurrencyType == 2 then
            Core.NotifyRightTip(target, T.Notify.receivedItem .. qty .. T.Notify.ofRoll, 5000)
        end
        Core.NotifyRightTip(_source, T.Notify.sent, 4000)

        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseGiveCurrency, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedgivecurrency .. "\nPlayer: " .. name .. "\nCurrency: " .. CurrencyType .. "\nQTY: " .. qty)

        return
    end

    if action == "horse" then
        local identifier <const> = Character.identifier
        local charid <const> = Character.charIdentifier
        local hash <const> = data1
        name = data2
        local sex <const> = data3
        if not Config.Integrations.vorpStables.enabled then
            -- pup: horses live in pup-stable (stable_horses plus its caches), so pup-stable makes the horse
            if GetResourceState("pup-stable") ~= "started" then
                return Core.NotifyRightTip(_source, "pup-stable is not running", 5000)
            end
            local ok, done, why = pcall(function()
                -- the old menu sends 0/1, the panel sends 'male'/'female'
                local female = tonumber(sex) == 1 or tostring(sex):lower() == "female"
                return exports["pup-stable"]:AdminGiveHorse(target, hash, tostring(name), female)
            end)
            if not ok or not done then
                return Core.NotifyRightTip(_source, "Could not give the horse: " .. tostring(ok and why or done), 5000)
            end
        else
            MySQL.insert("INSERT INTO stables ( `identifier`, `charidentifier`, `name`, `modelname`,`type`,`inventory` ) VALUES ( @identifier, @charid, @name, @modelname, @type, @inventory)", {
                identifier = identifier,
                charid = charid,
                name = tostring(name),
                modelname = hash,
                type = "horse",
                inventory = json.encode({})
            })
        end
        Core.NotifyRightTip(target, T.Notify.horseReceived, 5000)
        Core.NotifyRightTip(_source, T.Notify.horseGiven, 4000)

        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseGiveHorse, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedgivehorse .. "\nPlayer: " .. name .. "\nHorse: " .. hash)

        return
    end

    if action == "wagon" then
        local identifier <const> = Character.identifier
        local charid <const> = Character.charIdentifier
        local hash <const> = data1
        name = data2

        if not Config.Integrations.vorpStables.enabled then
            MySQL.insert("INSERT INTO wagons ( `identifier`, `charid`, `name`, `model`) VALUES ( @identifier, @charid, @name, @model)", {
                identifier = identifier,
                charid = charid,
                name = tostring(name),
                model = hash
            })
        else
            MySQL.insert("INSERT INTO stables ( `identifier`, `charidentifier`, `name`, `modelname`,`type`,`inventory` ) VALUES ( @identifier, @charid, @name, @modelname, @type, @inventory)", {
                identifier = identifier,
                charid = charid,
                name = tostring(name),
                modelname = hash,
                type = "wagon",
                inventory = json.encode({})
            })
        end
        Core.NotifyRightTip(target, T.Notify.wagonReceived, 5000)
        Core.NotifyRightTip(_source, T.Notify.weaponGiven, 4000)

        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseGiveWagon, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedgivewagon .. "\nPlayer: " .. name .. "\nWagon: " .. hash)
    end
end)


-- REMOVE DB

RegisterNetEvent("vorp_admin:ClearAllItems", function(type, target, _, name)
    local _source = source

    if not Core.getUser(target) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "clear_inventory") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    exports.vorp_inventory:closeInventory(target)

    if type == "items" then
        local inv <const> = exports.vorp_inventory:getUserInventoryItems(target)
        if not inv then
            return Core.NotifyRightTip(_source, "inventory is empty", 8000)
        end

        for _, inventoryItems in pairs(inv) do
            exports.vorp_inventory:subItem(target, inventoryItems.name, inventoryItems.count)
        end
        Core.NotifyRightTip(_source, T.Notify.itemsWiped, 4000)
        Core.NotifyRightTip(target, T.Notify.itemWipe, 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseClearItems, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedclearitems .. "\nPlayer: " .. name .. "\nID: " .. target)
    end

    if type == "weapons" then
        local weaponsPlayer <const> = exports.vorp_inventory:getUserInventoryWeapons(target)
        for _, value in pairs(weaponsPlayer) do
            local id <const> = value.id
            exports.vorp_inventory:subWeapon(target, id)
            exports.vorp_inventory:deleteWeapon(target, id)
            TriggerClientEvent('pup_gunsmith:removeallammo', target)
            exports.vorp_inventory:removeAllUserAmmo(target)
        end

        Core.NotifyRightTip(_source, T.Notify.weaponsWiped, 4000)
        Core.NotifyRightTip(target, T.Notify.weaponWipe, 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseClearWeapons, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedclearweapons .. "\nPlayer: " .. name .. "\nID: " .. target)
    end
end)

-- GET ITEMS FROM INVENTORY
RegisterNetEvent("vorp_admin:checkInventory", function(targetID)
    local _source = source
    if not Core.getUser(targetID) then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "check_player_inventory") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminSpectate, T.Webhooks.ActionsAdmin.title,
        "viewed the INVENTORY of ID " .. tostring(targetID))

    local inv = exports.vorp_inventory:getUserInventoryItems(targetID)
    TriggerClientEvent("vorp_admin:getplayerInventory", _source, inv)
end)

-- OPEN A PLAYER'S REAL INVENTORY (two-way: the admin can take and put back).
-- Its own key, not check_player_inventory: that one is the read-only list.
RegisterNetEvent("vorp_admin:openLiveInventory", function(targetID)
    local _source = source
    targetID = tonumber(targetID)
    local target <const> = targetID and Core.getUser(targetID)
    if not target then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "open_player_inventory") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    if targetID == _source then
        return Core.NotifyRightTip(_source, "That is your own inventory.", 5000)
    end

    local ch <const> = target.getUsedCharacter
    local title = ch and ((ch.firstname or "") .. " " .. (ch.lastname or "")) or ""
    title = title:gsub("^%s+", ""):gsub("%s+$", "")
    if title == "" then title = "Player " .. tostring(targetID) end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminSpectate, T.Webhooks.ActionsAdmin.title,
        "OPENED THE LIVE INVENTORY of ID " .. tostring(targetID) .. " (can take items)")

    -- no blacklist/itemsLimit: an admin sees and moves everything, and the
    -- panel opens from anywhere on the map, so the 10m move guard is waived
    exports.vorp_inventory:openPlayerInventory({
        source = _source,
        target = targetID,
        title  = title,
        noDistanceCheck = true,
    })
end)

-- REMOVE CURRENCY
RegisterNetEvent("vorp_admin:ClearCurrency", function(targetID, type, _, name)
    local _source = source

    local user <const> = Core.getUser(targetID)
    if not user then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "clear_currency") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local Character <const> = user.getUsedCharacter
    local money <const> = Character.money
    local gold <const> = Character.gold

    if type == "money" then
        Character.removeCurrency(0, money)
        Core.NotifyRightTip(_source, T.Notify.moneyRemoved, 4000)
        Core.NotifyRightTip(targetID, T.Notify.moneyRemovedFromAdmin, 4000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseClearMoney, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedclearmoney .. "\nPlayer: " .. name .. "\nID: " .. targetID .. "\nCurrency: " .. type)
    else
        Character.removeCurrency(1, gold)
        Core.NotifyRightTip(_source, T.Notify.goldRemoved, 4000)
        Core.NotifyRightTip(targetID, T.Notify.goldRemovedFromAdmin, 4000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.databaseClearGold, T.Webhooks.ActionDatabase.title, T.Webhooks.ActionDatabase.usedcleargold .. "\nPlayer: " .. name .. "\nID: " .. targetID .. "\nCurrency: " .. type)
    end
end)

-- ADMIN ACTIONS

-- GROUP
RegisterNetEvent("vorp_admin:setGroup", function(targetID, newgroup, _, name)
    local _source = source
    local _target = targetID
    local NewPlayerGroup = newgroup
    local user <const> = Core.getUser(_target)
    if not user then
        return Core.NotifyRightTip(_source, T.Notify.userNotExist, 8000)
    end

    if not AllowedToExecuteAction(_source, "set_group") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local character <const> = user.getUsedCharacter

    if Config.Permissions.setGroup.character and Config.Permissions.setGroup.user then -- if both true then set both
        character.setGroup(NewPlayerGroup)
        user.setGroup(NewPlayerGroup)
    elseif Config.Permissions.setGroup.character then
        character.setGroup(NewPlayerGroup)
    elseif Config.Permissions.setGroup.user then
        user.setGroup(NewPlayerGroup)
    end
    local group = "none"

    if Config.Permissions.useCharacterGroup then
        if Config.Permissions.setGroup.character then
            group = NewPlayerGroup
        end
    else
        if Config.Permissions.setGroup.user then
            group = NewPlayerGroup
        end
    end

    -- update staff table if group is staff
    if Config.Permissions.groups[group] then
        stafftable[_target] = _target
    else
        return Core.NotifyRightTip(_source, "this group doesnt exist in the AllowedActions table", 8000)
    end

    Core.NotifyRightTip(_target, T.Notify.groupGiven .. group, 5000)

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminSetGroup, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedsetgroup .. "\n > " .. name .. "\nGroup: " .. NewPlayerGroup)
end)

-- JOB
RegisterNetEvent("vorp_admin:setJob", function(targetID, newjob, newgrade, newJobLabel, _, name)
    local _source = source
    local _target = targetID
    local user <const> = Core.getUser(_target)
    if not user then
        return Core.NotifyRightTip(_source, "user not found", 8000)
    end

    if not AllowedToExecuteAction(_source, "set_job") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    -- joblabel is a SEPARATE column, and vorp_core's Joblabel() only writes
    -- `if value then` - so a blank or missing label silently keeps the old one.
    -- That is how a character ends up doing a job while every readout still
    -- says "Unemployed". No label given = use the job name.
    if newJobLabel == nil or tostring(newJobLabel):gsub('%s+', '') == '' then
        newJobLabel = newjob
    end

    local character <const> = user.getUsedCharacter
    character.setJob(newjob)
    character.setJobGrade(newgrade)
    character.setJobLabel(newJobLabel)

    Core.NotifyRightTip(_target, T.Notify.jobGiven .. newjob, 5000)
    Core.NotifyRightTip(_target, T.Notify.gradeGiven .. newgrade, 5000)
    Core.NotifyRightTip(_target, T.Notify.jobLabelGiven .. newJobLabel, 5000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminSetJob, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedsetjob .. "\n > " .. name .. "\nJob:  " .. newjob .. " \nGrade: " .. newgrade)
end)

-- WHITELIST
RegisterNetEvent("vorp_admin:Whitelist", function(_, steam, _, _, name)
    local _source = source

    if not AllowedToExecuteAction(_source, "whitelist_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    Core.Whitelist.unWhitelistUser(steam)

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminUnwhitelist, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedunwhitelist .. "\n > " .. name .. "\n: " .. steam)
end)

RegisterNetEvent("vorp_admin:Whitelistoffline", function(steam, type)
    local _source = source

    if not AllowedToExecuteAction(_source, "whitelist_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminWhitelist, T.Webhooks.ActionsAdmin.title,
        ("%s (offline) %s"):format(type == "whiteList" and "WHITELISTED" or "UNWHITELISTED", tostring(steam)))

    --only offline players can be whitelisted
    if type == "whiteList" then
        Core.Whitelist.whitelistUser(steam)
    else
        Core.Whitelist.unWhitelistUser(steam)
    end
end)

-- REVIVE
RegisterNetEvent("vorp_admin:revive", function(target, _, name)
    local _source = source

    if not Core.getUser(target) then
        return Core.NotifyRightTip(_source, "user not found", 8000)
    end

    if not AllowedToExecuteAction(_source, "revive_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    if name then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminRevive, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedreviveplayer .. "\n> " .. name)
    end

    Core.Player.Revive(target)
end)

-- HEAL
RegisterNetEvent("vorp_admin:heal", function(target, _, name)
    local _source = source

    if not Core.getUser(target) then
        return Core.NotifyRightTip(_source, "user not found", 8000)
    end

    if not AllowedToExecuteAction(_source, "heal_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    if name then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminHeal, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedhealplayer .. "\n> " .. name)
    end

    Core.Player.Heal(target)
end)

-- JUST FOR LOGS
RegisterNetEvent("vorp_admin:spawnHorse", function(horse)
    local _source = source
    -- just incase they want to flood the logs
    if not AllowedToExecuteAction(_source, "spawn_horse") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterSpawnHorse, T.Webhooks.ActionBoosters.title, "Horse: " .. horse)
end)

-- SPAWN ANIMAL
RegisterNetEvent("vorp_admin:spawnAnimal", function(model)
    local _source = source
    if not AllowedToExecuteAction(_source, "spawn_horse") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterSpawnHorse, T.Webhooks.ActionBoosters.title, "Animal: " .. tostring(model))
end)

-- SPAWN WAGON
RegisterNetEvent("vorp_admin:spawnWagon", function(wagon)
    local _source = source
    -- just incase they want to flood the logs
    if not AllowedToExecuteAction(_source, "spawn_wagon") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterSpawnWagon, T.Webhooks.ActionBoosters.title, "Wagon: " .. wagon)
end)

-- GODMODE
RegisterNetEvent("vorp_admin:GodMode", function()
    local _source = source
    -- just incase they want to flood the logs
    if not AllowedToExecuteAction(_source, "godmode") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterGodMode, T.Webhooks.ActionBoosters.title, T.Webhooks.ActionBoosters.usedgod)
end)

-- GOLDEN CORES
RegisterNetEvent("vorp_admin:GoldenCores", function()
    local _source = source
    -- just incase they want to flood the logs
    if not AllowedToExecuteAction(_source, "golden_cores") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterGoldenCores, T.Webhooks.ActionBoosters.title, T.Webhooks.ActionBoosters.usedgoldcores)
end)

-- INFINITE AMMO
RegisterNetEvent("vorp_admin:InfiAmmo", function()
    local _source = source
    -- just incase they want to flood the logs
    if not AllowedToExecuteAction(_source, "infinite_ammo") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterInfiniteAmmo, T.Webhooks.ActionBoosters.title, T.Webhooks.ActionBoosters.usedinfinitammo)
end)

-- NOCLIP
RegisterNetEvent("vorp_admin:NoClip", function()
    local _source = source
    -- just incase they want to flood the logs
    if not AllowedToExecuteAction(_source, "noclip") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterNoClip, T.Webhooks.ActionBoosters.title, T.Webhooks.ActionBoosters.usednoclip)
end)

-- SPECTATE
RegisterNetEvent("vorp_admin:spectate", function(targetID, _, name)
    local _source = source

    if not AllowedToExecuteAction(_source, "spectate") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local targetCoords = GetEntityCoords(GetPlayerPed(targetID))
    TriggerClientEvent("vorp_admin:spectatePlayer", _source, targetID, targetCoords)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminSpectate, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedspectate .. "\n > " .. name)
end)


RegisterNetEvent("vorp_admin:announce", function(announce)
    local _source = source
    if not AllowedToExecuteAction(_source, "allow_announce") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminAnnounce, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedannounce .. "\n > " .. announce)

    Core.NotifySimpleTop(-1, T.Notify.announce, announce, 10000)
end)

RegisterNetEvent('vorp_admin:HealSelf', function()
    local _source = source
    if not AllowedToExecuteAction(_source, "selfheal") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local name = Player(_source).state.Character.FirstName .. Player(_source).state.Character.LastName
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterSelfHeal, T.Webhooks.ActionBoosters.title, T.Webhooks.ActionBoosters.usedheal .. "\n> " .. name)

    Core.Player.Heal(_source)
end)

RegisterNetEvent('vorp_admin:ReviveSelf', function()
    local _source = source
    if not AllowedToExecuteAction(_source, "selfrevive") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local name = Player(_source).state.Character.FirstName .. Player(_source).state.Character.LastName
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.boosterSelfRevive, T.Webhooks.ActionBoosters.title, T.Webhooks.ActionBoosters.usedrevive .. "\n> " .. name)
    Core.Player.Revive(_source)
end)

RegisterNetEvent("vorp_admin:Unban", function(staticid, _, name)
    local _source = source
    if not AllowedToExecuteAction(_source, "unban_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminUnban, T.Webhooks.ActionsAdmin.title, T.Webhooks.ActionsAdmin.usedunban .. "\n > " .. name .. "\n: " .. staticid)

    TriggerEvent("vorpbans:addtodb", false, staticid, 0)
end)

RegisterNetEvent("vorp_admin:BanOffline", function(staticid, time)
    local _source = source
    if not AllowedToExecuteAction(_source, "ban_offline") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    TriggerEvent("vorpbans:addtodb", false, staticid, time)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminBan, T.Webhooks.ActionsAdmin.title,
        ("Banned OFFLINE identifier: %s\nLength: %s"):format(tostring(staticid), tostring(time)))
end)

RegisterNetEvent('vorp:teleportWayPoint', function(_, coords, waypointCoords)
    local _source = source
    if not AllowedToExecuteAction(_source, "tp_to_waypoint") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local description = T.Webhooks.ActionTeleport.usedtpm .. "\nWaypoint teleported to " .. tostring(waypointCoords) .. "\nfrom Coords : " .. tostring(coords)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.teleportWaypoint, T.Webhooks.ActionTeleport.title, description)

    TriggerClientEvent('vorp:teleportWayPoint', _source, coords)
end)

RegisterNetEvent('vorp_admin:tptocoords', function(oldCoords, x, y, z)
    local _source = source
    if not AllowedToExecuteAction(_source, "tp_to_coords") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local description = T.Webhooks.ActionTeleport.usedtptocoords .. "\nfrom coords: " .. tostring(oldCoords) .. "\nto coords: " .. tostring(vector3(x, y, z))
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.teleportCoords, T.Webhooks.ActionTeleport.title, description)
end)

-- PERMISSIONS
Core.Callback.Register('vorp_admin:CanOpenStaffMenu', function(source, CB, action)
    local _source = source
    local user <const> = Core.getUser(_source)
    if not user then return end

    CB(AllowedToExecuteAction(_source, action))
end)

-- Troll Actions
-- every one of these is done TO a player, so every one of them is logged
local function trollLog(src, what, targetId)
    TriggerEvent("vorp_admin:logs", src, Secrets.Webhooks.adminTroll, T.Webhooks.ActionsAdmin.title,
        ("Troll: %s\nTarget ID: %s (%s)"):format(what, tostring(targetId), GetPlayerName(targetId) or "?"))
end

RegisterNetEvent('vorp_admin:ServerTrollKillPlayerHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_kill_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:ClientTrollKillPlayerHandler', playerserverid)
    trollLog(_source, "KILLED player", playerserverid)
end)

RegisterNetEvent('vorp_admin:ServerTrollInvisibleHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_invisible") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:ClientTrollInvisbleHandler', playerserverid)
    trollLog(_source, "made player INVISIBLE", playerserverid)
end)

RegisterNetEvent('vorp_admin:ServerTrollLightningStrikePlayerHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_lightning_strike") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end

    local playerPed = GetPlayerPed(playerserverid)
    local coords = GetEntityCoords(playerPed)
    TriggerClientEvent('vorp_admin:ClientTrollLightningStrikePlayerHandler', -1, coords)
    trollLog(_source, "LIGHTNING STRIKE on player", playerserverid)
end)

RegisterNetEvent('vorp_admin:ServerTrollSetPlayerOnFireHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_set_player_on_fire") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:ClientTrollSetPlayerOnFireHandler', playerserverid)
    trollLog(_source, "set player ON FIRE", playerserverid)
end)

RegisterNetEvent('vorp_admin:ServerTrollTPToHeavenHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_tp_to_heaven") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:ClientTrollTPToHeavenHandler', playerserverid)
    trollLog(_source, "sent player TO HEAVEN", playerserverid)
end)

RegisterNetEvent('vorp_admin:ServerTrollRagdollPlayerHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_ragdoll_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:ClientTrollRagdollPlayerHandler', playerserverid)
    trollLog(_source, "RAGDOLLED player", playerserverid)
end)

RegisterNetEvent('vorp_admin:ServerDrainPlayerStamHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_drain_player_stam") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:ClientDrainPlayerStamHandler', playerserverid)
    trollLog(_source, "DRAINED player stamina", playerserverid)
end)

RegisterNetEvent('vorp_admin:ServerHandcuffPlayerHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_handcuff_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:ClientHandcuffPlayerHandler', playerserverid)
    trollLog(_source, "HANDCUFFED player", playerserverid)
end)

RegisterNetEvent('vorp_admin:ServerTempHighPlayerHandler', function(playerserverid)
    local _source = source
    if not AllowedToExecuteAction(_source, "troll_temp_high_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 8000)
    end
    TriggerClientEvent('vorp_admin:ClientTempHighPlayerHandler', playerserverid)
    trollLog(_source, "TEMP HIGH on player", playerserverid)
end)


-- shared admin log: callers pass their own webhook; a blank one falls back to a default
AddEventHandler('vorp_admin:logs', function(source, webhook, title, description)
    local _source = tonumber(source) or 0
    description = tostring(description or "")
    title = tostring(title or "Admin Panel")

    local hook = (type(webhook) == "string" and webhook ~= "") and webhook or Secrets.Webhooks.default

    -- source is 0 for console/scripted actions, and GetPlayer* return nil there
    -- no IP here on purpose: an admin log is read by more people than a ban log
    local steamName, license, steamId = "console", "server", "none"
    local discordId, group = nil, "console"
    local charLine, whereLine = "", ""

    if _source > 0 then
        steamName = GetPlayerName(_source) or "unknown"
        -- by TYPE, not by index: identifier 1 is whatever the engine happened to list first
        license = GetPlayerIdentifierByType(_source, "license") or "unknown"
        steamId = GetPlayerIdentifierByType(_source, "steam") or "none"
        local d = GetPlayerIdentifierByType(_source, "discord")
        if d then discordId = string.sub(d, 9) end

        -- who they were PLAYING as, and what authority they used
        local ok, user = pcall(function() return Core.getUser(_source) end)
        if ok and user then
            local char = user.getUsedCharacter
            if type(char) == "table" and char.firstname then
                charLine = ("**Character:** `%s %s`  ·  charid `%s`  ·  job `%s`"):format(
                    char.firstname, char.lastname or "", tostring(char.charIdentifier or "?"),
                    tostring(char.job or "none"))
            end
            local g = Config.Permissions.useCharacterGroup and type(char) == "table" and char.group or user.getGroup
            group = tostring(g or "user")
        end

        -- where they were standing: an admin action without a place is half a record
        local ped = GetPlayerPed(_source)
        if ped and ped ~= 0 then
            local okc, c = pcall(GetEntityCoords, ped)
            if okc and c then
                whereLine = ("**Where:** `%.1f, %.1f, %.1f`"):format(c.x, c.y, c.z)
            end
        end
    end

    if Config.Logs.printToConsole then
        print(("^3[vorp_admin]^7 %s | %s [%d] (%s) | %s"):format(
            title, steamName, _source, group, description))
    end

    -- a category left blank goes to the catch-all instead of being dropped
    if not hook or hook == "" then hook = Secrets.Webhooks.default end
    if not hook or hook == "" then return end

    -- the <t:unix:F> tags render in each reader's OWN timezone, so a log read in
    -- another country still says when it actually happened
    local now <const> = os.time()
    local lines = {
        ("**Action:** %s"):format(description ~= "" and description or "(none given)"),
        "",
        ("**Staff:** `%s`  ·  server id `%s`  ·  group `%s`"):format(steamName, tostring(_source), group),
    }
    if charLine ~= "" then lines[#lines + 1] = charLine end
    if whereLine ~= "" then lines[#lines + 1] = whereLine end
    lines[#lines + 1] = ("**Discord:** %s"):format(
        discordId and ("<@%s> (`%s`)"):format(discordId, discordId) or "`not running`")
    lines[#lines + 1] = ("**Licence:** `%s`"):format(license)
    lines[#lines + 1] = ("**Steam:** `%s`"):format(steamId)
    lines[#lines + 1] = ("**When:** <t:%d:F> (<t:%d:R>)  ·  %d player(s) online"):format(
        now, now, #(GetPlayers() or {}))

    Core.AddWebhook(title, hook, table.concat(lines, "\n"),
        Config.Logs.embedColor, Config.Logs.embedName, Config.Logs.logo, Config.Logs.footerLogo, Config.Logs.avatar)
end)


-- Alert staff of report
RegisterNetEvent('vorp_admin:alertstaff', function(report)
    local _source = source
    local user <const> = Core.getUser(_source)
    if not user then return end

    local character = user.getUsedCharacter
    local playername = character.firstname .. ' ' .. character.lastname

    for _, staff in pairs(stafftable) do
        Core.NotifyRightTip(staff, T.Notify.player .. playername .. T.Notify.reportedToDiscord, 4000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.reportPlayer, T.Webhooks.ActionScoreBoard.title, T.Webhooks.ActionScoreBoard.playerreported .. report)
end)



AddEventHandler("vorp:SelectedCharacter", function(source)
    local _source = source

    if Config.General.debug then
        return print("^1DevMode is enabled, disable on live servers^7")
    end

    local user <const> = Core.getUser(_source)
    if not user then return end
    local user_group = Config.Permissions.useCharacterGroup and user.getUsedCharacter.group or user.getGroup

    if Config.Permissions.groups[user_group] then -- only admins
        stafftable[_source] = _source
    end

    local data = getUserData(user, _source)
    PlayersTable[_source] = data
end)

if Config.General.debug then
    RegisterNetEvent("vorp_admin:getStaffInfo", function(source)
        local _source = source
        local user <const> = Core.getUser(_source)
        if not user then return end
        local user_group = Config.Permissions.useCharacterGroup and user.getUsedCharacter.group or user.getGroup

        if Config.Permissions.groups[user_group] then
            stafftable[_source] = _source
        end

        local data = getUserData(user, _source)
        PlayersTable[_source] = data
    end)
end

RegisterNetEvent("vorp_admin:requeststaff", function(type)
    local _source = source
    local user <const> = Core.getUser(_source)
    if not user then return end

    local character = user.getUsedCharacter
    local playername = character.firstname .. ' ' .. character.lastname

    for _, staff in pairs(stafftable) do
        if type == "new" then
            Core.NotifyRightTip(staff, playername .. " ID: " .. _source .. T.Notify.requestingAssistance .. T.Notify.new, 4000)
        elseif type == "bug" then
            Core.NotifyRightTip(staff, playername .. " ID: " .. _source .. T.Notify.requestingAssistance .. T.Notify.foundBug, 4000)
        elseif type == "rules" then
            Core.NotifyRightTip(staff, playername .. " ID: " .. _source .. T.Notify.requestingAssistance .. T.Notify.someoneBrokerules, 4000)
        elseif type == "cheating" then
            Core.NotifyRightTip(staff, playername .. " ID: " .. _source .. T.Notify.requestingAssistance .. T.Notify.someoneCheating, 4000)
        end
    end
    if type == "new" then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.reportRequestStaff, T.Webhooks.ActionScoreBoard.title, T.Webhooks.ActionScoreBoard.requeststaff_disc)
    elseif type == "bug" then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.reportBug, T.Webhooks.ActionScoreBoard.title, T.Webhooks.ActionScoreBoard.requeststaff_bug)
    elseif type == "rules" then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.reportRulesBroken, T.Webhooks.ActionScoreBoard.title, T.Webhooks.ActionScoreBoard.requeststaff_rulesbroke)
    elseif type == "cheating" then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.reportCheating, T.Webhooks.ActionScoreBoard.title, T.Webhooks.ActionScoreBoard.requeststaff_cheating)
    end
end)


AddEventHandler('playerDropped', function()
    local _source = source

    if stafftable[_source] then
        stafftable[_source] = nil
    end
    if PlayersTable[_source] then
        PlayersTable[_source] = nil
    end
end)

-----------------------------------------------------------------------------------------------------------------
-- DASHBOARD (pup-ui app) -- read-only overview data for client/dashboard.lua.
-- Permission: the SAME AllowedToExecuteAction gate every other handler uses
local dashboardStartTime <const> = os.time()

-- PLAYER-COUNT HISTORY (txAdmin-style dashboard chart): sample every 5 minutes, keep 24h
local HISTORY_FILE <const> = "panel_history.json"
local HISTORY_STEP <const> = 300      -- seconds between samples
local HISTORY_KEEP <const> = 86400    -- window size in seconds
local playerHistory = {}

do
    local raw = LoadResourceFile(GetCurrentResourceName(), HISTORY_FILE)
    if raw then
        local ok, saved = pcall(json.decode, raw)
        if ok and type(saved) == "table" then playerHistory = saved end
    end
end

CreateThread(function()
    while true do
        local now = os.time()
        playerHistory[#playerHistory + 1] = { t = now, n = #GetPlayers() }
        while playerHistory[1] and playerHistory[1].t < (now - HISTORY_KEEP) do
            table.remove(playerHistory, 1)
        end
        SaveResourceFile(GetCurrentResourceName(), HISTORY_FILE, json.encode(playerHistory), -1)
        Wait(HISTORY_STEP * 1000)
    end
end)

Core.Callback.Register("vorp_admin:Callback:getDashboard", function(source, cb)
    local _source = source
    local user <const> = Core.getUser(_source)
    if not user then return cb(false) end

    if not AllowedToExecuteAction(_source, "open_menu") then
        return cb(false)
    end

    local group = Config.Permissions.useCharacterGroup and user.getUsedCharacter.group or user.getGroup

    -- staff online = anyone whose GROUP has admin permissions (the stafftable only tracks toggled-on staff duty)
    local staffCount = 0
    for _, sid in ipairs(GetPlayers()) do
        local u = Core.getUser(tonumber(sid))
        if u then
            local g = Config.Permissions.useCharacterGroup and u.getUsedCharacter and u.getUsedCharacter.group or u.getGroup
            if g and Config.Permissions.groups[g] then staffCount = staffCount + 1 end
        end
    end

    -- panel title: Config.General.panelTitle wins; otherwise the server's own name from the sv_projectName convar
    local serverName = tostring(Config.General.panelTitle or "")
    if serverName == "" then
        serverName = GetConvar("sv_projectName", "")
    end
    serverName = serverName:gsub("%^%d", ""):gsub("^%s+", ""):gsub("%s+$", "")

    local charName
    do
        local ch = user.getUsedCharacter
        if ch then
            charName = ((ch.firstname or "") .. " " .. (ch.lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")
        end
    end

    -- txAdmin-style activity cards
    local now <const> = os.time()
    local okA, active24 = pcall(MySQL.scalar.await,
        "SELECT COUNT(*) FROM characters WHERE CAST(`LastLogin` AS UNSIGNED) > ?", { now - 86400 })
    local okN, new7d = pcall(MySQL.scalar.await,
        "SELECT COUNT(*) FROM characters WHERE `character_created` > DATE_SUB(NOW(), INTERVAL 7 DAY)")
    local okT, totalChars = pcall(MySQL.scalar.await, "SELECT COUNT(*) FROM characters")

    -- what this player is allowed to see
    local permSet, permSource = PermissionSet(_source)
    local perms = {}
    if permSet == 'all' then
        perms.all = true
    else
        for key in pairs(permSet or {}) do perms[key] = true end
    end

    cb({
        perms       = perms,
        permSource  = permSource,
        playerCount = #GetPlayers(),
        maxPlayers  = GetConvarInt("sv_maxclients", 32),
        uptime      = os.time() - dashboardStartTime, -- seconds since this resource started
        staffCount  = staffCount,
        group       = tostring(group or "user"),
        serverName  = serverName,
        charName    = charName,
        history     = playerHistory,
        now         = now,
        active24    = okA and tonumber(active24) or nil,
        new7d       = okN and tonumber(new7d) or nil,
        totalChars  = okT and tonumber(totalChars) or nil,
    })
end)

-----------------------------------------------------------------------------------------------------------------
-- ECONOMY (pup-ui app "Economy" tab) -- READ-ONLY server-wide money analytics for client/dashboard.lua.
-- Same AllowedToExecuteAction("open_menu") gate as getDashboard
--   clan.cash (tinytext numeric) / .taxmoney        (pup-clan/db.sql)
--   underground.name / .ledger                      (pup-underground/db.sql)
--   playerhousing.ledger / .taxledger               (pup-housing sql)
--   bills.amount                                    (pup-societies/society.sql)
-- society_shops has NO ledger column (verified) -> society shop money lives in society_ledger already.

local function econRound(v)
    v = tonumber(v) or 0
    return math.floor(v * 100 + 0.5) / 100
end

-- single-value aggregate; nil = block unavailable (bad table/column), never a guess
local function econScalar(query)
    local ok, result = pcall(MySQL.scalar.await, query)
    if not ok then return nil end
    return econRound(result or 0)
end

local function econRows(query)
    local ok, result = pcall(MySQL.query.await, query)
    if not ok or type(result) ~= "table" then return nil end
    return result
end

-- SERVER-SIDE CACHE, because this is 17 sequential round trips
local ECON_TTL <const> = 60
local econCache, econAt, econBusy = nil, 0, false

local function buildEconomy()
    local totals = {}
    local missing = {}
    local function put(key, value)
        if value == nil then
            missing[#missing + 1] = key
        else
            totals[key] = value
        end
    end

    ---------------------------------------------------------------- characters: cash + gold
    do
        local ok, row = pcall(MySQL.single.await,
            "SELECT COALESCE(SUM(`money`),0) AS cash, COALESCE(SUM(`gold`),0) AS gold FROM characters")
        if ok and row then
            put('cash', econRound(row.cash))
            put('gold', econRound(row.gold))
        else
            put('cash', nil)
            put('gold', nil)
        end
    end

    ---------------------------------------------------------------- bank (total_money is maintained on every deposit/withdraw)
    put('banked', econScalar("SELECT COALESCE(SUM(`total_money`),0) FROM bank_users"))

    ---------------------------------------------------------------- societies (list + total from the same rows)
    local societies = nil
    do
        local rows = econRows("SELECT `job`, COALESCE(`ledger`,0) AS ledger FROM society_ledger ORDER BY ledger DESC")
        if rows then
            societies = {}
            local total = 0
            for _, r in ipairs(rows) do
                local ledger = econRound(r.ledger)
                total = total + ledger
                societies[#societies + 1] = { job = tostring(r.job or "?"), ledger = ledger }
            end
            put('societies', econRound(total))
        else
            put('societies', nil)
        end
    end

    ---------------------------------------------------------------- player shops (ledger + taxledger both held in the shop)
    local playerShopsTotal = econScalar(
        "SELECT COALESCE(SUM(COALESCE(`ledger`,0) + COALESCE(`taxledger`,0)),0) FROM playershops")
    if playerShopsTotal == nil then -- legacy install without the taxledger migration
        playerShopsTotal = econScalar("SELECT COALESCE(SUM(COALESCE(`ledger`,0)),0) FROM playershops")
    end
    put('playerShops', playerShopsTotal)

    local shops = nil
    do
        local rows = econRows([[SELECT `name`, (COALESCE(`ledger`,0) + COALESCE(`taxledger`,0)) AS ledger
            FROM playershops WHERE (COALESCE(`ledger`,0) + COALESCE(`taxledger`,0)) > 0
            ORDER BY ledger DESC LIMIT 10]])
        if not rows then
            rows = econRows([[SELECT `name`, COALESCE(`ledger`,0) AS ledger
                FROM playershops WHERE COALESCE(`ledger`,0) > 0 ORDER BY ledger DESC LIMIT 10]])
        end
        if rows then
            shops = {}
            for _, r in ipairs(rows) do
                shops[#shops + 1] = { name = tostring(r.name or "?"), ledger = econRound(r.ledger), type = 'player' }
            end
        end
    end
    -- society_shops: no ledger/taxledger column exists (schema verified) -> nothing to aggregate there

    ---------------------------------------------------------------- ranches
    put('ranches', econScalar("SELECT COALESCE(SUM(COALESCE(`ledger`,0)),0) FROM player_ranch"))
    local ranches = nil
    do
        local rows = econRows([[SELECT `name`, COALESCE(`ledger`,0) AS ledger
            FROM player_ranch WHERE COALESCE(`ledger`,0) > 0 ORDER BY ledger DESC LIMIT 10]])
        if rows then
            ranches = {}
            for _, r in ipairs(rows) do
                ranches[#ranches + 1] = { name = tostring(r.name or "?"), ledger = econRound(r.ledger) }
            end
        end
    end

    ---------------------------------------------------------------- clans (cash is tinytext -> CAST) + tax holdings
    put('clans', econScalar([[SELECT COALESCE(SUM(CAST(`cash` AS DECIMAL(14,2))),0) + COALESCE(SUM(`taxmoney`),0) FROM clan]]))

    ---------------------------------------------------------------- underground (moonshine shack ledgers)
    put('underground', econScalar("SELECT COALESCE(SUM(COALESCE(`ledger`,0)),0) FROM underground"))

    ---------------------------------------------------------------- housing (taxledger guarded separately: NEW-migration only)
    do
        local housingLedger = econScalar("SELECT COALESCE(SUM(`ledger`),0) FROM playerhousing")
        if housingLedger ~= nil then
            local housingTax = econScalar("SELECT COALESCE(SUM(`taxledger`),0) FROM playerhousing") or 0
            put('housing', econRound(housingLedger + housingTax))
        else
            put('housing', nil)
        end
    end

    ---------------------------------------------------------------- side currencies (NOT in grand: not dollars in circulation)
    put('billsOutstanding', econScalar("SELECT COALESCE(SUM(`amount`),0) FROM bills"))

    ---------------------------------------------------------------- grand total: every dollar actually held somewhere
    do
        local grand = 0
        for _, k in ipairs({ 'cash', 'banked', 'societies', 'playerShops', 'ranches', 'clans', 'underground', 'housing' }) do
            grand = grand + (totals[k] or 0)
        end
        totals.grand = econRound(grand)
    end

    ---------------------------------------------------------------- top holders: cash + bank per character
    local topHolders = nil
    do
        local rows = econRows([[SELECT CONCAT(c.`firstname`, ' ', c.`lastname`) AS name,
                COALESCE(c.`money`,0) AS cash,
                COALESCE(b.`total_money`,0) AS banked,
                (COALESCE(c.`money`,0) + COALESCE(b.`total_money`,0)) AS total
            FROM characters c
            LEFT JOIN bank_users b ON b.`charidentifier` = c.`charidentifier`
            ORDER BY total DESC LIMIT 15]])
        if not rows then -- bank table unavailable: rank by cash alone rather than dropping the block
            rows = econRows([[SELECT CONCAT(`firstname`, ' ', `lastname`) AS name,
                    COALESCE(`money`,0) AS cash, 0 AS banked, COALESCE(`money`,0) AS total
                FROM characters ORDER BY total DESC LIMIT 15]])
        end
        if rows then
            topHolders = {}
            for _, r in ipairs(rows) do
                topHolders[#topHolders + 1] = {
                    name   = tostring(r.name or "?"),
                    cash   = econRound(r.cash),
                    banked = econRound(r.banked),
                    total  = econRound(r.total),
                }
            end
        end
    end

    return {
        totals     = totals,
        missing    = missing,
        societies  = societies,
        topHolders = topHolders,
        shops      = shops,
        ranches    = ranches,
        computedAt = os.time(),
    }
end

local function refreshEconomy()
    if econBusy then return end
    econBusy = true
    CreateThread(function()
        local ok, payload = pcall(buildEconomy)
        if ok and payload then econCache, econAt = payload, os.time() end
        econBusy = false
    end)
end

Core.Callback.Register("vorp_admin:Callback:getEconomy", function(source, cb)
    local _source = source
    local user <const> = Core.getUser(_source)
    if not user then return cb(false) end

    if not AllowedToExecuteAction(_source, "open_menu") then
        return cb(false)
    end

    -- stamped at serve time, not build time, so the panel can say how old the figures are
    local age = os.time() - econAt
    if econCache and age < ECON_TTL then
        econCache.ageSeconds = age
        return cb(econCache)                 -- fresh: instant
    end
    if econCache then
        econCache.ageSeconds = age
        refreshEconomy()                     -- stale: answer now, recompute behind it
        return cb(econCache)
    end

    -- cold start: nothing to serve, so this one caller waits for the real thing
    local ok, payload = pcall(buildEconomy)
    if not ok or not payload then return cb(false) end
    econCache, econAt = payload, os.time()
    payload.ageSeconds = 0
    cb(payload)
end)

-- ITEMS DB MANAGER (pup-ui dashboard "Items" tab, client/dashboard.lua): browse, search and edit the `items` table
Core.Callback.Register("vorp_admin:Callback:itemsSearch", function(source, cb, data)
    local _source = source
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end
    local term = (type(data) == "table" and type(data.term) == "string") and data.term or ""
    -- PAGINATION - 0-based page, 30 rows per page
    local page = math.floor(math.max(tonumber(type(data) == "table" and data.page or 0) or 0, 0))
    local offset = page * 30

    local sql, params, cntSql, cntParams
    if term == "" then
        sql, params = "SELECT item, label, `limit`, weight, type, usable FROM items ORDER BY item LIMIT 30 OFFSET " .. offset, {}
        cntSql, cntParams = "SELECT COUNT(*) AS n FROM items", {}
    else
        local like = "%" .. term .. "%"
        sql = "SELECT item, label, `limit`, weight, type, usable FROM items WHERE item LIKE ? OR label LIKE ? ORDER BY item LIMIT 30 OFFSET " .. offset
        params = { like, like }
        cntSql = "SELECT COUNT(*) AS n FROM items WHERE item LIKE ? OR label LIKE ?"
        cntParams = { like, like }
    end

    MySQL.query(sql, params, function(rows)
        MySQL.query(cntSql, cntParams, function(cnt)
            cb({ rows = rows or {}, total = (cnt and cnt[1] and tonumber(cnt[1].n)) or 0, page = page })
        end)
    end)
end)

-- full row for the detail page
Core.Callback.Register("vorp_admin:Callback:itemsGet", function(source, cb, data)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then return cb(false) end
    local item = type(data) == "table" and tostring(data.item or "") or ""
    if item == "" then return cb(false) end
    MySQL.query("SELECT * FROM items WHERE item = ?", { item }, function(rows)
        cb(rows and rows[1] or false)
    end)
end)

-- every editable column, with how to validate it
local ITEM_FIELDS <const> = {
    label       = { kind = "text",   max = 50 },
    ["limit"]   = { kind = "int",    min = -1 },      -- -1 = unlimited
    can_remove  = { kind = "bool" },
    type        = { kind = "text",   max = 50 },
    usable      = { kind = "bool" },
    useExpired  = { kind = "bool" },
    groupId     = { kind = "int",    min = 0 },
    rarityId    = { kind = "int",    min = 0 },
    metadata    = { kind = "json" },
    desc        = { kind = "text",   max = 5550 },
    degradation = { kind = "int",    min = 0 },       -- 0 = no decay
    durability  = { kind = "intnull", min = 0 },      -- -1 sets NULL
    instructions= { kind = "textnull" },              -- "" sets NULL
    weight      = { kind = "number", min = 0 },
}

-- Create an item row
RegisterServerEvent("vorp_admin:items:create")
AddEventHandler("vorp_admin:items:create", function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then return end
    if type(data) ~= "table" then return end

    local function tip(msg) TriggerClientEvent("vorp:TipRight", _source, msg, 6000) end

    local item = data.item
    if type(item) ~= "string" then return end
    item = item:gsub("%s+", "")
    -- the item name is a primary key and is used as a filename for its icon
    if item == "" or #item > 50 or item:match("[^%w_]") then
        return tip("Item name must be letters, numbers or underscore only (max 50)")
    end

    local label = data.label
    if type(label) ~= "string" or label == "" or #label > 50 then
        return tip("Label is required (max 50 characters)")
    end

    -- -1 is the table's "unlimited" sentinel; anything else below 1 is a typo
    local limit = math.floor(tonumber(data.limit) or 10)
    if limit < -1 or limit == 0 then limit = 1 end

    -- 1.0, not 0: slots are counted through weight here, so a weight-0 item is free
    local weight = tonumber(data.weight) or 1.0
    if weight < 0 then weight = 1.0 end

    local usable = (data.usable == 1 or data.usable == "1" or data.usable == true) and 1 or 0

    -- only the two types vorp_inventory actually understands
    local itype = tostring(data.type or "item_standard")
    if itype ~= "item_standard" and itype ~= "item_weapon" then itype = "item_standard" end

    local desc = data.desc
    if type(desc) ~= "string" or desc == "" then desc = label end
    if #desc > 5550 then desc = desc:sub(1, 5550) end

    local exists = MySQL.scalar.await("SELECT item FROM items WHERE item = ?", { item })
    if exists then
        return tip(("An item called '%s' already exists"):format(item))
    end

    -- can_remove/type/weight/desc named explicitly: some are NOT NULL in this schema
    MySQL.insert(
        "INSERT INTO items (item, label, `limit`, can_remove, type, usable, weight, `desc`) " ..
        "VALUES (?, ?, ?, 1, ?, ?, ?, ?)",
        { item, label, limit, itype, usable, weight, desc }, function()
            tip(("Item '%s' created - restart vorp_inventory to apply in-game"):format(item))
        end)

    print(("^3[vorp_admin]^7 items: src %s created item '%s' (label '%s', limit %d, weight %s, usable %d, type %s)")
        :format(_source, item, label, limit, tostring(weight), usable, itype))
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelItems, "Admin Panel - Items",
        ("Created item: %s\nLabel: %s\nLimit: %d\nWeight: %s\nUsable: %d\nType: %s")
        :format(item, label, limit, tostring(weight), usable, itype))
end)

RegisterServerEvent("vorp_admin:items:update")
AddEventHandler("vorp_admin:items:update", function(item, field, value)
    local _source = source
    -- writes use the STRONGER gate: same key as the Main admin-actions menu
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then return end
    if type(item) ~= "string" or item == "" or #item > 100 then return end

    local function done(msg)
        TriggerClientEvent("vorp:TipRight", _source,
            msg .. " - restart vorp_inventory to apply in-game", 6000)
    end

    if field == "delete" then
        -- dropping an item row orphans every copy players are holding: its own key
        if not AllowedToExecuteAction(_source, "delete_item") then
            print(('^1[vorp_admin]^7 %s tried to DELETE item %s without delete_item')
                :format(GetPlayerName(_source) or _source, item))
            return TriggerClientEvent("vorp:TipRight", _source, "That is Management only.", 5000)
        end
        MySQL.update("DELETE FROM items WHERE item = ?", { item }, function(a)
            if a and a > 0 then
                done(("Item '%s' DELETED from the database"):format(item))
                -- deleting the definition leaves whatever players are holding behind: items_crafted rows survive and load with no name
                TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelItems, "Admin Panel - Items",
                    ("Deleted item: %s\nCopies already in player inventories were NOT removed "):format(item)
                    .. "and now point at a row that no longer exists.")
            else
                TriggerClientEvent("vorp:TipRight", _source,
                    ("No item called '%s' to delete"):format(item), 5000)
            end
        end)
        print(("^3[vorp_admin]^7 items: src %s deleted item '%s'"):format(_source, item))
        return
    end

    local spec = ITEM_FIELDS[field]
    if not spec then return end

    -- validate/coerce per kind; v = final value (NULL sentinel handled below)
    local v
    if spec.kind == "text" or spec.kind == "textnull" then
        if type(value) ~= "string" then return end
        if spec.kind == "textnull" and value == "" then v = nil
        else
            if value == "" or (spec.max and #value > spec.max) then return end
            v = value
        end
    elseif spec.kind == "json" then
        if type(value) ~= "string" or value == "" then return end
        local ok = pcall(json.decode, value)
        if not ok then
            TriggerClientEvent("vorp:TipRight", _source, "metadata rejected - not valid JSON", 5000)
            return
        end
        v = value
    elseif spec.kind == "bool" then
        v = (value == 1 or value == "1" or value == true) and 1 or 0
    elseif spec.kind == "int" or spec.kind == "intnull" then
        local n = math.floor(tonumber(value) or -999999)
        if spec.kind == "intnull" and n == -1 then v = nil
        else
            if spec.min and n < spec.min then return end
            v = n
        end
    elseif spec.kind == "number" then
        local n = tonumber(value)
        if not n or (spec.min and n < spec.min) then return end
        v = n
    else
        return
    end

    -- column name comes from OUR whitelist keys, never from the client
    local sql = ("UPDATE items SET `%s` = ? WHERE item = ?"):format(field)
    MySQL.update(sql, { v, item }, function(a)
        if a and a > 0 then
            done(("'%s'.%s set to %s"):format(item, field, v == nil and "NULL" or tostring(v)))
            -- every field edit is logged: price, weight, limit and metadata all matter
            TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelItems, "Admin Panel - Items",
                ("Item %s: %s set to %s"):format(item, field, v == nil and "NULL" or tostring(v)))
        end
    end)
end)

-- WEB PANEL (client/panel.lua NUI) -- read-only data feeds

-- dates in this DB are epoch SECONDS in date-typed columns
local function panelDate(v, withTime)
    local n = tonumber(v)
    if n and n > 100000000 then
        if n > 1e12 then n = math.floor(n / 1000) end
        return os.date(withTime and "%Y-%m-%d %H:%M" or "%Y-%m-%d", n)
    end
    local s = tostring(v or "")
    if s == "" or s == "0" then return "" end
    return s:sub(1, withTime and 16 or 10)
end

-- staff = any group that has admin permissions configured
local function panelIsStaffGroup(group)
    return group ~= nil and Config.Permissions.groups[group] ~= nil
end

-- STAFF BY PERMISSION, NOT BY GROUP COLUMN
local function panelIsStaff(src, group)
    if src and HasPermission and HasPermission(src, 'open_menu') then return true end
    return panelIsStaffGroup(group)
end

-- [charidentifier] = serverId for everyone currently in-game
local function panelOnlineCharacters()
    local online = {}
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local user = Core.getUser(s)
        if user then
            local ch = user.getUsedCharacter
            if ch and ch.charIdentifier then
                online[tonumber(ch.charIdentifier)] = s
            end
        end
    end
    return online
end

Core.Callback.Register("vorp_admin:Callback:panelPlayers", function(source, cb, data)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end

    local search = ""
    if type(data) == "table" and type(data.search) == "string" then
        search = data.search:sub(1, 40)
    end

    local online = panelOnlineCharacters()

    -- THE TAB IS ONLINE-ONLY until you search: with no search term the list is
    -- simply whoever is connected, so a poll does not query the whole table.
    local where, args = "", {}
    local SEARCH_COLS <const> =
        "firstname LIKE @s OR lastname LIKE @s OR CONCAT(firstname,' ',lastname) LIKE @s" ..
        " OR job LIKE @s OR steamname LIKE @s OR discordid LIKE @s OR identifier LIKE @s"

    local orderBy = "`money` DESC"
    if search ~= "" then
        -- digits could be a character id, a Discord snowflake or part of a name,
        -- so an exact charid match is ADDED to the text match, never swapped for it
        if search:match("^%d+$") then
            where = "WHERE `charidentifier` = @id OR " .. SEARCH_COLS
            args["@id"] = math.floor(tonumber(search))
            -- "1" substring-matches hundreds of ids; without this the character
            -- actually numbered 1 can be pushed past LIMIT 100 by richer ones
            orderBy = "(`charidentifier` = @id) DESC, `money` DESC"
        else
            where = "WHERE " .. SEARCH_COLS
        end
        args["@s"] = "%" .. search .. "%"
    else
        local ids = {}
        for cid in pairs(online) do ids[#ids + 1] = tonumber(cid) end
        if #ids == 0 then
            local okt, tot = pcall(MySQL.scalar.await, "SELECT COUNT(*) FROM characters")
            return cb({ rows = {}, totalCharacters = okt and tonumber(tot) or 0,
                        onlineCount = 0, searching = false })
        end
        local marks = {}
        for i = 1, #ids do marks[i] = "?" end
        where = ("WHERE `charidentifier` IN (%s)"):format(table.concat(marks, ","))
        args = ids
    end

    local ok, rows = pcall(MySQL.query.await,
        ("SELECT `charidentifier`,`firstname`,`lastname`,`job`,`money`,`gold`,`LastLogin`,`group`,`steamname`,`discordid`,`identifier` FROM characters %s ORDER BY %s LIMIT 100")
            :format(where, orderBy), args)
    if not ok or type(rows) ~= "table" then return cb(false) end

    local okc, total = pcall(MySQL.scalar.await, "SELECT COUNT(*) FROM characters")

    local out = {}
    for i = 1, #rows do
        local r = rows[i]
        local charid = tonumber(r.charidentifier)
        local sid = charid and online[charid] or nil
        -- ping is the whole live payload: one native, no extra file
        local live = nil
        if sid then
            local okp, ping = pcall(GetPlayerPing, sid)
            live = { ping = (okp and tonumber(ping)) or 0 }
        end
        out[#out + 1] = {
            charid    = charid,
            name      = ((r.firstname or "") .. " " .. (r.lastname or "")):gsub("^%s+", ""):gsub("%s+$", ""),
            job       = r.job or "unemployed",
            money     = tonumber(r.money) or 0,
            gold      = tonumber(r.gold) or 0,
            lastlogin = panelDate(r.LastLogin),
            online    = sid or false,
            live      = live,
            -- shown on a search hit, so staff can tell two same-named characters apart
            steamname = r.steamname or "",
            discordid = tostring(r.discordid or ""),
            steamid   = tostring(r.identifier or ""),
            -- pup: Discord permissions, same as the live map. `sid` is nil
            -- for an offline character, and panelIsStaff falls back to the group
            -- column there - a Discord role cannot be resolved for somebody who is not connected
            staff     = panelIsStaff(sid, r.group),
        }
    end

    -- Online first, then richest
    table.sort(out, function(a, b)
        local ao = a.online and 1 or 0
        local bo = b.online and 1 or 0
        if ao ~= bo then return ao > bo end
        if a.money ~= b.money then return a.money > b.money end
        return (a.charid or 0) < (b.charid or 0)
    end)

    cb({
        rows            = out,
        totalCharacters = okc and tonumber(total) or #out,
        onlineCount     = #GetPlayers(),
        searching       = search ~= "",
    })
end)

-- PED MENU: relay only. Nothing is saved - the target's own client re-checks the
-- model against its ped list, and a relog or death restores the real character.
RegisterNetEvent("vorp_admin:server:setPlayerPed", function(targetId, model)
    local _source = source
    if not AllowedToExecuteAction(_source, "ped_menu_others") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end

    targetId = tonumber(targetId)
    if not targetId then return end
    model = tostring(model or "")
    -- shape check so nothing odd reaches the target's ExecuteCommand; the allowlist
    -- check itself happens on the receiving client, which is where Peds lives
    if model ~= "" and not model:match("^[%w_]+$") then return end
    if not Core.getUser(targetId) then
        return Core.NotifyRightTip(_source, "that player is not online", 4000)
    end

    TriggerClientEvent("vorp_admin:client:setPed", targetId, model)
    Core.NotifyRightTip(_source,
        model ~= "" and ("ped set on " .. targetId) or ("ped cleared on " .. targetId), 4000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Ped Menu",
        ("Set ped of id %s to %s"):format(targetId, model ~= "" and model or "their own character"))
end)

-- STABLE ADMIN: pup-stable owns the data and its caches, this owns the gate.
local function stableCharId(targetId)
    local user = Core.getUser(targetId)
    local ch = user and user.getUsedCharacter
    if type(ch) ~= "table" then return nil end
    return ch.charIdentifier
end

local function stableCall(name, ...)
    local ok, a, b, c = pcall(function(...) return exports['pup-stable'][name](exports['pup-stable'], ...) end, ...)
    if not ok then return false, "pup-stable is not running" end
    return a, b, c
end

Core.Callback.Register("vorp_admin:Callback:stableAssets", function(source, cb, data)
    local _source = source
    if not AllowedToExecuteAction(_source, "stable_admin") then return cb(false) end
    if type(data) ~= "table" then return cb(false) end
    local charid, name
    -- by character id (works for offline characters too), or by an online player's server id
    local byChar = tonumber(data.charid)
    if byChar and byChar > 0 and byChar == math.floor(byChar) then
        local ok, row = pcall(MySQL.single.await,
            "SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier = ? LIMIT 1", { byChar })
        if not ok or type(row) ~= "table" then return cb({ notFound = true }) end
        charid = tonumber(row.charidentifier)
        name = ("%s %s"):format(tostring(row.firstname or ""), tostring(row.lastname or ""))
    else
        local targetId = tonumber(data.serverId)
        if not targetId then return cb(false) end
        charid = stableCharId(targetId)
    end
    if not charid then return cb(false) end

    local assets = stableCall("GetPlayerStableAssets", charid)
    if type(assets) ~= "table" then return cb(false) end
    assets.charid = charid
    assets.name = name
    cb(assets)
end)

RegisterNetEvent("vorp_admin:server:stableTransfer", function(kind, assetId, targetId)
    local _source = source
    if not AllowedToExecuteAction(_source, "stable_admin") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    assetId, targetId = tonumber(assetId), tonumber(targetId)
    if not assetId or not targetId then return end
    if kind ~= "horse" and kind ~= "wagon" then return end
    if not Core.getUser(targetId) then
        return Core.NotifyRightTip(_source, "that player is not online", 4000)
    end

    local ok, name, from = stableCall(kind == "horse" and "AdminTransferHorse" or "AdminTransferWagon", assetId, targetId)
    if not ok then return Core.NotifyRightTip(_source, tostring(name or "transfer failed"), 4000) end

    Core.NotifyRightTip(_source, ("%s transferred to %s"):format(tostring(name), targetId), 4000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Stable Admin",
        ("Transferred %s %s (%s) from %s to id %s"):format(kind, assetId, tostring(name), tostring(from), targetId))
end)

RegisterNetEvent("vorp_admin:server:stableDelete", function(kind, assetId)
    local _source = source
    if not AllowedToExecuteAction(_source, "stable_admin") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    assetId = tonumber(assetId)
    if not assetId then return end
    if kind ~= "horse" and kind ~= "wagon" then return end

    local ok, name = stableCall(kind == "horse" and "AdminDeleteHorse" or "AdminDeleteWagon", assetId, _source)
    if not ok then return Core.NotifyRightTip(_source, tostring(name or "delete failed"), 4000) end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Stable Admin",
        ("Deleted %s %s (%s)"):format(kind, assetId, tostring(name)))
end)

RegisterNetEvent("vorp_admin:server:stableTrain", function(assetId)
    local _source = source
    if not AllowedToExecuteAction(_source, "stable_admin") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    assetId = tonumber(assetId)
    if not assetId then return end

    local ok, name = stableCall("AdminFullyTrainHorse", assetId)
    if not ok then return Core.NotifyRightTip(_source, tostring(name or "train failed"), 4000) end

    Core.NotifyRightTip(_source, ("%s fully trained"):format(tostring(name)), 4000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Stable Admin",
        ("Fully trained horse %s (%s)"):format(assetId, tostring(name)))
end)

RegisterNetEvent("vorp_admin:server:stableResetColor", function(assetId)
    local _source = source
    if not AllowedToExecuteAction(_source, "stable_admin") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    assetId = tonumber(assetId)
    if not assetId then return end

    local ok, name = stableCall("AdminResetHorseColor", assetId)
    if not ok then return Core.NotifyRightTip(_source, tostring(name or "reset failed"), 4000) end

    Core.NotifyRightTip(_source, ("%s coat colour reset"):format(tostring(name)), 4000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Stable Admin",
        ("Reset coat colour on horse %s (%s)"):format(assetId, tostring(name)))
end)

-- open a horse's saddlebag or a wagon's locker; staff can look and take items out
RegisterNetEvent("vorp_admin:server:stableStorage", function(kind, assetId)
    local _source = source
    if not AllowedToExecuteAction(_source, "stable_admin") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    assetId = tonumber(assetId)
    if not assetId then return end
    if kind ~= "horse" and kind ~= "wagon" then return end

    local ok, name = stableCall("AdminOpenStorage", kind, assetId, _source)
    if not ok then return Core.NotifyRightTip(_source, tostring(name or "could not open storage"), 4000) end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Stable Admin",
        ("Opened the %s of %s %s (%s)"):format(kind == "horse" and "saddlebag" or "locker", kind, assetId, tostring(name)))
end)

-- PED OUTFITS: relay only, same gate as the ped itself. -1 = random variation.
RegisterNetEvent("vorp_admin:server:setPlayerOutfit", function(targetId, preset)
    local _source = source
    if not AllowedToExecuteAction(_source, "ped_menu_others") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end

    targetId = tonumber(targetId)
    preset = tonumber(preset)
    if not targetId or not preset then return end
    if preset < -1 or preset > 60 or preset % 1 ~= 0 then return end
    if not Core.getUser(targetId) then
        return Core.NotifyRightTip(_source, "that player is not online", 4000)
    end

    TriggerClientEvent("vorp_admin:client:setOutfit", targetId, preset >= 0 and preset or nil)
    Core.NotifyRightTip(_source, ("outfit set on " .. targetId), 4000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Ped Menu",
        ("Set outfit of id %s to %s"):format(targetId, preset >= 0 and preset or "random"))
end)

-- HEIGHT (ped scale): writes the Scale key inside characters.skinPlayer
RegisterNetEvent("vorp_admin:panelSetScale", function(charid, scale)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end

    charid = tonumber(charid)
    scale = tonumber(scale)
    if not charid or not scale then return end
    -- staff choice: no gameplay clamp, only a sanity bound so 0/negative/absurd values can't corrupt the skin
    if scale < 0.1 then scale = 0.1 end
    if scale > 5.0 then scale = 5.0 end

    local okr, raw = pcall(MySQL.scalar.await, "SELECT skinPlayer FROM characters WHERE charidentifier = ?", { charid })
    if not okr then return end

    local sid = panelOnlineCharacters()[charid]
    if sid then
        -- ONLINE: must go through the core's updateSkin. vorp_core keeps the skin in MEMORY (character.skin) and would re-save it over a direct SQL write
        local user = Core.getUser(sid)
        local character = user and user.getUsedCharacter
        if not character then return end
        local src <const> = character.skin or raw
        local okj, skin = pcall(json.decode, src or "")
        if not okj or type(skin) ~= "table" then
            return Core.NotifyRightTip(_source, "no skin saved for that character", 5000)
        end
        skin.Scale = scale
        character.updateSkin(json.encode(skin))
        TriggerClientEvent('vorp_character:adminSetScale', sid, scale)
        -- the line above only reaches the TARGET's own client - SetPedScale is local, so RefreshHeight updates everyone else
        pcall(function() exports.vorp_character:RefreshHeight(sid) end)
        Core.NotifyRightTip(_source, ("height set to %.2f, applied and saved"):format(scale), 4000)
    else
        -- OFFLINE: nothing holds this character in memory, direct SQL is the save
        local okj, skin = pcall(json.decode, raw or "")
        if not okj or type(skin) ~= "table" then
            return Core.NotifyRightTip(_source, "no skin saved for that character", 5000)
        end
        skin.Scale = scale
        MySQL.update("UPDATE characters SET skinPlayer = ? WHERE charidentifier = ?", { json.encode(skin), charid })
        Core.NotifyRightTip(_source, ("height set to %.2f - applies on their next login"):format(scale), 4000)
    end

    -- one log, after the write
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelHeight, "Admin Panel - Height",
        ("Set height of charid %s to %.2f (%s)"):format(charid, scale, sid and "online" or "offline"))
end)

-- STORES MANAGEMENT (player-owned shops, pup-stores)
Core.Callback.Register("vorp_admin:Callback:panelStores", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_stores") then return cb(false) end

    -- live cache first: it carries repo/blip/slots/stock that the DB read cannot
    if GetResourceState('pup_mercantile') == 'started' then
        local ok, payload = pcall(function() return exports['pup_mercantile']:adminStoreList() end)
        if ok and type(payload) == 'table' and type(payload.shops) == 'table' then
            local list = {}
            for _, s in ipairs(payload.shops) do
                list[#list + 1] = {
                    id = s.id,
                    name = tostring(s.name or ("Shop #" .. tostring(s.id))),
                    ownerCharid = tonumber(s.charid) or 0,
                    ownerName = s.owner,
                    ownerDiscord = s.discord,
                    ledger = tonumber(s.ledger) or 0,
                    taxledger = tonumber(s.taxledger) or 0,
                    repo = s.repo and true or false,
                    blip = (tonumber(s.blip) or 0) == 1,
                    slots = tonumber(s.slots) or 0,
                    level = tonumber(s.level) or 0,
                    items = tonumber(s.items) or 0,
                    weapons = tonumber(s.weapons) or 0,
                    coords = s.coords, -- so the panel can offer "Go to shop"
                    live = true,
                }
            end
            return cb({ list = list, stats = payload.stats })
        end
    end

    -- fallback: pup_mercantile down or still loading, so read-only from the DB
    local ok, rows = pcall(MySQL.query.await, [[SELECT p.id, p.name, p.charidentifier, p.ledger, p.taxledger,
            c.firstname, c.lastname
        FROM playershops p
        LEFT JOIN characters c ON c.charidentifier = p.charidentifier]])
    if not ok or type(rows) ~= 'table' then return cb({ list = {} }) end

    local list = {}
    for _, r in ipairs(rows) do
        local ownerName = ((r.firstname or "") .. " " .. (r.lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")
        list[#list + 1] = {
            id = r.id,
            name = tostring(r.name or ("Shop #" .. tostring(r.id))),
            ownerCharid = tonumber(r.charidentifier) or 0,
            ownerName = ownerName ~= "" and ownerName or nil,
            ledger = tonumber(r.ledger) or 0,
            taxledger = tonumber(r.taxledger) or 0,
            live = false,
        }
    end
    cb({ list = list })
end)

-- what one shop is holding: on sale, shelved, and its buy orders
Core.Callback.Register("vorp_admin:Callback:panelStoreStock", function(source, cb, id)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_stores") then return cb(false) end
    if GetResourceState('pup_mercantile') ~= 'started' then return cb(false) end

    local ok, payload = pcall(function() return exports['pup_mercantile']:adminStoreStock(id) end)
    if not ok or type(payload) ~= 'table' then return cb(false) end
    cb(payload)
end)

-- shop admin actions
-- readable log lines per action, so the feed says what changed and not just its name.
-- Lua has no positional format specifiers, so each entry takes (id, value) in order.
local STORE_LOG <const> = {
    repo    = "REPOSSESSED shop #%d from its owner",
    unrepo  = "Returned shop #%d to its owner",
    rename  = "Renamed shop #%d to %s",
    blip    = "Map blip on shop #%d set to %s",
    move    = "Moved shop #%d to where they were standing",
    slots   = "Stock slots on shop #%d set to %s",
    delete  = "DELETED shop #%d and all of its stock",
}

local GANG_LOG <const> = {
    points  = "Adjusted gang #%d points by %s",
    disband = "DISBANDED gang #%d - removed from every member",
}

local RANCH_LOG <const> = {
    setprice = "Ranch #%d price set to $%s",
    settax   = "Ranch #%d tax set to %s",
    move     = "Ranch #%d MOVED to %s",
    transfer = "Ranch #%d ownership set to char %s",
    delete   = "Ranch #%d DELETED (%s)",
    hire     = "Ranch #%d HIRED char %s",
    fire     = "Ranch #%d FIRED char %s",
    rank     = "Ranch #%d rank changed for char %s",
}

local function actionLine(tbl, noun, action, id, value)
    local t = tbl[action]
    if t then
        local ok, line = pcall(string.format, t, id, tostring(value))
        if ok then return line end
    end
    return ("%s on %s #%d (value %s)"):format(action, noun, id, tostring(value))
end

-- the teleport itself already happened client-side; this is the audit line
RegisterNetEvent('vorp_admin:store:goto', function(id)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_stores") then return end
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelStores, "Admin Panel - Stores",
        ("Teleported to shop #%s"):format(tostring(tonumber(id) or "?")))
end)

RegisterNetEvent('vorp_admin:store:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_stores") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    if GetResourceState('pup_mercantile') ~= 'started' then
        return Core.NotifyRightTip(_source, "pup_mercantile is not running", 5000)
    end

    local id = tonumber(data.id)
    local action = tostring(data.action or '')
    if not id or action == '' then return end

    -- running a shop is one thing; deleting it or taking it off its owner is another
    local STORE_DESTRUCTIVE <const> = { delete = true, repo = true }
    if STORE_DESTRUCTIVE[action] and not AllowedToExecuteAction(_source, "delete_store") then
        print(('^1[vorp_admin]^7 %s tried %s on shop %d without delete_store')
            :format(GetPlayerName(_source) or _source, action, id))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end

    local ok, done, why = pcall(function()
        return exports['pup_mercantile']:adminStoreAction(id, action, data.value)
    end)
    if not ok or done == false then
        return Core.NotifyRightTip(_source,
            "Shop action failed: " .. tostring(why or "error"), 6000)
    end

    Core.NotifyRightTip(_source, ("Shop %d: %s done"):format(id, action), 5000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelStores, "Admin Panel - Stores",
        actionLine(STORE_LOG, "shop", action, id, data.value))
end)

-- open the shop's real stock grid for this admin (owner controls, from anywhere).
-- pup_mercantile checks manage_stores again through allowedToExecuteAction.
RegisterNetEvent('vorp_admin:store:openStock', function(id)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_stores") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if GetResourceState('pup_mercantile') ~= 'started' then
        return Core.NotifyRightTip(_source, "pup_mercantile is not running", 5000)
    end
    id = tonumber(id)
    if not id then return end

    local ok, done, why = pcall(function()
        return exports['pup_mercantile']:adminOpenStock(_source, id)
    end)
    if not ok or done ~= true then
        return Core.NotifyRightTip(_source,
            "Could not open the shop stock: " .. tostring(why or "error"), 6000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelStores, "Admin Panel - Stores",
        ("Opened the stock grid of shop #%d"):format(id))
end)

-- RANCH MANAGEMENT (pup-ranch bridge)
Core.Callback.Register("vorp_admin:Callback:panelGangs", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_gangs") then return cb(false) end
    if GetResourceState('pup-gangs') ~= 'started' then return cb({ missing = true }) end

    local ok, payload = pcall(function() return exports['pup-gangs']:adminGangList() end)
    if not ok or type(payload) ~= 'table' then return cb(false) end
    cb(payload)
end)

RegisterNetEvent('vorp_admin:gang:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_gangs") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    local action = tostring(data.action or '')
    if not id then return end

    -- running a gang and dissolving one are different powers
    if action == 'disband' and not AllowedToExecuteAction(_source, "delete_gang") then
        print(('^1[vorp_admin]^7 %s tried to DISBAND gang %d without delete_gang')
            :format(GetPlayerName(_source) or _source, id))
        TriggerClientEvent('vorp_admin:panelToast', _source, 'Disbanding a gang is Management only.', true)
        return Core.NotifyRightTip(_source, "Disbanding a gang is Management only.", 5000)
    end

    local GANG_ACTIONS <const> = {
        points  = function() return exports['pup-gangs']:adminAdjustPoints(id, tonumber(data.value)) end,
        disband = function() return exports['pup-gangs']:adminDisbandGang(id) end,
    }
    local fn = GANG_ACTIONS[action]
    if not fn then return end
    local okc, res = pcall(fn)
    if okc and type(res) == 'table' and res.ok then
        Core.NotifyRightTip(_source, ("Gang %d: %s done"):format(id, action), 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelGangs, "Admin Panel - Gangs",
            actionLine(GANG_LOG, "gang", action, id, data.value))
    else
        Core.NotifyRightTip(_source, "Gang action failed: " .. tostring(type(res) == 'table' and res.err or "error"), 6000)
    end
end)

-- SEASON RESET - wipes every ladder at once, so it needs its own key rather than
-- riding on manage_gangs like the per-gang controls do
RegisterNetEvent('vorp_admin:gang:reset', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_gangs") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if not AllowedToExecuteAction(_source, "reset_gang_points") then
        print(('^1[vorp_admin]^7 %s tried to RESET gang points without reset_gang_points')
            :format(GetPlayerName(_source) or _source))
        TriggerClientEvent('vorp_admin:panelToast', _source, 'Resetting the season is Management only.', true)
        return Core.NotifyRightTip(_source, "Resetting the season is Management only.", 5000)
    end
    if GetResourceState('pup-gangs') ~= 'started' then
        return Core.NotifyRightTip(_source, "pup-gangs is not running.", 5000)
    end

    local scope = tostring(type(data) == 'table' and data.scope or '')
    local SCOPES <const> = { gangs = true, members = true, factions = true, all = true }
    if not SCOPES[scope] then return end

    local ok, res = pcall(function() return exports['pup-gangs']:adminResetPoints(scope) end)
    if ok and type(res) == 'table' and res.ok then
        local line = ("%d gang(s), %d member(s), %d faction(s) reset"):format(
            res.gangs or 0, res.members or 0, res.factions or 0)
        Core.NotifyRightTip(_source, line, 6000)
        TriggerClientEvent('vorp_admin:panelToast', _source, line, false)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelGangs, "Admin Panel - Gangs",
            ("SEASON RESET (%s) - %s"):format(scope, line))
    else
        Core.NotifyRightTip(_source, "Reset failed: " .. tostring(type(res) == 'table' and res.err or "error"), 6000)
    end
end)

-- PERK MANAGEMENT (pup-perks bridge)
Core.Callback.Register("vorp_admin:Callback:panelPerks", function(source, cb, search)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_perks") then return cb(false) end
    if GetResourceState('pup-perks') ~= 'started' then return cb({ missing = true }) end

    local ok, list = pcall(function()
        return exports['pup-perks']:adminPerkList(type(search) == 'string' and search or '')
    end)
    if not ok or type(list) ~= 'table' then return cb(false) end
    cb({ list = list })
end)

Core.Callback.Register("vorp_admin:Callback:panelPerkDetail", function(source, cb, charid)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_perks") then return cb(false) end
    if GetResourceState('pup-perks') ~= 'started' then return cb(false) end

    local ok, detail = pcall(function() return exports['pup-perks']:adminPerkGet(tonumber(charid)) end)
    if not ok or type(detail) ~= 'table' then return cb(false) end
    cb(detail)
end)

RegisterNetEvent('vorp_admin:perks:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_perks") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local charid = tonumber(data.charid)
    local action = tostring(data.action or '')
    if not charid then return end

    -- points are per SIDE (civ / crime); the panel sends which one
    local PERK_ACTIONS <const> = {
        points = function() return exports['pup-perks']:adminAdjustPoints(charid, tostring(data.track or ''), tonumber(data.value)) end,
        xp     = function() return exports['pup-perks']:adminAddXP(charid, tostring(data.track or ''), tonumber(data.value)) end,
        reset  = function() return exports['pup-perks']:adminResetPerks(charid) end,
    }
    local fn = PERK_ACTIONS[action]
    if not fn then return end

    local okc, res = pcall(fn)
    if okc and type(res) == 'table' and res.ok then
        Core.NotifyRightTip(_source, ("Perks: %s applied to character %d"):format(action, charid), 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelPerks, "Admin Panel - Perks",
            ("Perk %s on character %d value %s%s"):format(
                action, charid, tostring(data.value),
                data.track and (" track " .. tostring(data.track)) or ""))
    else
        Core.NotifyRightTip(_source, "Perk action failed: " ..
            tostring(type(res) == 'table' and res.err or "error"), 6000)
    end
end)

Core.Callback.Register("vorp_admin:Callback:panelRanches", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_ranch") then return cb(false) end
    if GetResourceState('pup_ranchero') ~= 'started' then return cb({ missing = true }) end

    local ok, list = pcall(function() return exports['pup_ranchero']:adminRanchList() end)
    if not ok or type(list) ~= 'table' then return cb(false) end

    -- owner names in one query
    local ids, seen = {}, {}
    for _, r in ipairs(list) do
        local cid = tonumber(r.ownerCharid)
        if cid and cid > 0 and not seen[cid] then
            seen[cid] = true
            ids[#ids + 1] = cid
        end
    end
    local names = {}
    if #ids > 0 then
        local okn, rows = pcall(MySQL.query.await,
            ("SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier IN (%s)"):format(table.concat(ids, ",")))
        if okn and type(rows) == 'table' then
            for _, r in ipairs(rows) do
                -- STRING key on purpose
                names[tostring(r.charidentifier)] = ((r.firstname or "") .. " " .. (r.lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")
            end
        end
    end

    -- TRUE produce totals. pup-ranch's milk/eggs fields are only the uncollected counters
    local invIds, invOf = {}, {}
    for _, r in ipairs(list) do
        local iid = tonumber(r.invId)
        if iid then
            invIds[#invIds + 1] = ("'%d'"):format(iid)
            invOf[tostring(iid)] = r
        end
    end
    if #invIds > 0 then
        local okp, rows = pcall(MySQL.query.await,
            ("SELECT inventory_type, item_name, SUM(amount) AS amount FROM character_inventories WHERE inventory_type IN (%s) GROUP BY inventory_type, item_name")
            :format(table.concat(invIds, ",")))
        if okp and type(rows) == 'table' then
            for _, row in ipairs(rows) do
                local r = invOf[tostring(row.inventory_type)]
                if r then
                    local amt = tonumber(row.amount) or 0
                    if row.item_name == r.milkItem then
                        r.milk = (tonumber(r.milk) or 0) + amt
                    elseif row.item_name == r.eggItem then
                        r.eggs = (tonumber(r.eggs) or 0) + amt
                    end
                end
            end
        end
    end

    -- the latest 300 activity rows across all ranches
    local activity = {}
    pcall(function()
        activity = MySQL.query.await(
            "SELECT ranchid, ts, type, detail, actor FROM ranch_activity ORDER BY id DESC LIMIT 300") or {}
    end)

    -- resolve the actor NAME to a character id so the panel can be searched by charid. ranch_activity stores only a name
    if #activity > 0 then
        local want, list2 = {}, {}
        for _, a in ipairs(activity) do
            local nm = tostring(a.actor or '')
            if nm ~= '' and not want[nm] then want[nm] = true; list2[#list2 + 1] = nm end
        end
        if #list2 > 0 then
            local okc, rows = pcall(MySQL.query.await,
                'SELECT charidentifier, firstname, lastname FROM characters')
            if okc and type(rows) == 'table' then
                local byName = {}
                for _, r in ipairs(rows) do
                    local nm = ((r.firstname or '') .. ' ' .. (r.lastname or '')):gsub('^%s+', '')
                    if nm ~= '' then byName[nm] = tonumber(r.charidentifier) end
                end
                for _, a in ipairs(activity) do
                    a.charid = byName[tostring(a.actor or '')]
                end
            end
        end
    end

    cb({ list = list, names = names, activity = activity, now = os.time() })
end)

RegisterNetEvent('vorp_admin:ranch:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_ranch") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    local action = tostring(data.action or '')
    if not id then return end

    -- Setting a price is one thing; deleting a ranch or taking it off its owner is
    -- another. Same split the shop page makes with delete_store.
    local RANCH_DESTRUCTIVE <const> = { delete = true, transfer = true, move = true }
    if RANCH_DESTRUCTIVE[action] and not AllowedToExecuteAction(_source, "delete_ranch") then
        print(('^1[vorp_admin]^7 %s tried %s on ranch %d without delete_ranch')
            :format(GetPlayerName(_source) or _source, action, id))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end

    -- who did it, for pup_ranchero's own activity log
    local actor = "Admin"
    do
        local user = Core.getUser(_source)
        local ch = user and user.getUsedCharacter
        if ch then actor = ("%s %s"):format(ch.firstname or "", ch.lastname or "") end
    end

    local RANCH_ACTIONS <const> = {
        setprice = function() return exports['pup_ranchero']:adminSetRanchPrice(id, tonumber(data.value)) end,
        settax   = function() return exports['pup_ranchero']:adminSetRanchTax(id, tonumber(data.value)) end,

        -- the admin's own position: a panel cannot pick a spot on its own
        move = function()
            local ped <const> = GetPlayerPed(_source)
            if not ped or ped == 0 then return { ok = false, err = "you must be in game" } end
            local c <const> = GetEntityCoords(ped)
            data.value = ("%.1f, %.1f, %.1f"):format(c.x, c.y, c.z)
            return exports['pup_ranchero']:adminMoveRanch(id, { x = c.x, y = c.y, z = c.z }, actor)
        end,

        -- charid 0 clears the owner and puts it back on sale
        transfer = function()
            return exports['pup_ranchero']:adminTransferRanch(id, tonumber(data.value), actor)
        end,

        -- NO UNDO: cattle, pens, stored produce and the ledger all go with the row
        delete = function()
            if tostring(data.confirm or '') ~= 'DELETE' then
                return { ok = false, err = "not confirmed" }
            end
            return exports['pup_ranchero']:adminDeleteRanch(id, actor)
        end,

        -- STAFF. By charid, so a roster can be fixed while they are offline -
        -- the in-game boss menu only works on someone currently connected.
        hire = function()
            return exports['pup_ranchero']:adminHireToRanch(id, tonumber(data.value), actor)
        end,
        fire = function()
            return exports['pup_ranchero']:adminFireFromRanch(id, tonumber(data.value), actor)
        end,
        rank = function()
            return exports['pup_ranchero']:adminSetRanchManager(
                id, tonumber(data.value), data.manager == true, actor)
        end,
    }
    local fn = RANCH_ACTIONS[action]
    if not fn then return end
    local ok, res = pcall(fn)
    if ok and type(res) == 'table' and res.ok then
        Core.NotifyRightTip(_source, ("Ranch %d: %s done"):format(id, action), 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelRanch, "Admin Panel - Ranch",
            actionLine(RANCH_LOG, "ranch", action, id, data.value))
    else
        Core.NotifyRightTip(_source, "Ranch action failed: " .. tostring(type(res) == 'table' and res.err or "error"), 6000)
    end
end)

-- SOCIETY MANAGEMENT (pup-societies bridge)
Core.Callback.Register("vorp_admin:Callback:panelSociety", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_society") then return cb(false) end
    if GetResourceState('pup_business') ~= 'started' then return cb({ missing = true }) end
    local ok, list = pcall(function() return exports['pup_business']:adminOverview() end)
    if not ok or type(list) ~= 'table' then return cb(false) end
    cb({ list = list, now = os.time() })
end)

Core.Callback.Register("vorp_admin:Callback:panelSocietyShops", function(source, cb, data)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_society") then return cb(false) end
    local job = type(data) == 'table' and tostring(data.job or '') or ''
    if job == '' then return cb(false) end
    local ok, res = pcall(function() return exports['pup_business']:adminShops(job) end)
    cb(ok and res or false)
end)

-- HOUSING MANAGEMENT (pup-housing bridge)
Core.Callback.Register("vorp_admin:Callback:panelHousing", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_housing") then return cb(false) end
    if GetResourceState('pup_realestate') ~= 'started' then return cb({ missing = true }) end

    local ok, list = pcall(function() return exports['pup_realestate']:adminHousingList() end)
    if not ok or type(list) ~= 'table' then return cb(false) end

    -- motel rooms are NOT houses
    do
        local houses = {}
        for _, h in ipairs(list) do
            if not h.motel then houses[#houses + 1] = h end
        end
        list = houses
    end

    -- resolve owner + keyholder names in one query
    local ids, seen = {}, {}
    local function want(cid)
        cid = tonumber(cid)
        if cid and cid > 0 and not seen[cid] then
            seen[cid] = true
            ids[#ids + 1] = cid
        end
    end
    for _, h in ipairs(list) do
        want(h.ownerCharid)
        for _, k in ipairs(h.keyholders or {}) do
            want(type(k) == 'table' and (k.charid or k.charidentifier) or k)
        end
    end
    local names = {}
    if #ids > 0 then
        local okn, rows = pcall(MySQL.query.await,
            ("SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier IN (%s)"):format(table.concat(ids, ",")))
        if okn and type(rows) == 'table' then
            for _, r in ipairs(rows) do
                -- STRING key on purpose
                names[tostring(r.charidentifier)] = ((r.firstname or "") .. " " .. (r.lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")
            end
        end
    end

    -- LIVE auctions only, keyed by house id (defensive about the column name)
    local auctions = {}
    pcall(function()
        local rows = MySQL.query.await("SELECT * FROM housing_auctions WHERE status = 'open'") or {}
        for _, a in ipairs(rows) do
            local hid = tonumber(a.houseid or a.house_id or a.hid)
            -- `id` is the AUCTION row: cancelling needs it, not the house id
            if hid then
                auctions[tostring(hid)] = {
                    id = tonumber(a.id),
                    endts = tonumber(a.endts) or 0,
                    minbid = tonumber(a.minbid or a.min_bid) or 0,
                }
            end
        end
    end)

    cb({ list = list, names = names, auctions = auctions, now = os.time() })
end)

RegisterNetEvent('vorp_admin:housing:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_housing") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local action = tostring(data.action or '')
    local id = tonumber(data.id)
    if not id then return end

    -- Editing a house is not the same as taking it off its owner. manage_housing
    -- lets the housing team run the estate; anything that costs someone their
    -- house needs delete_housing. Roles with "all" hold both.
    local HOUSING_DESTRUCTIVE <const> = {
        delete    = true,
        seize     = true, -- takes the house off whoever owns it
        transfer  = true, -- and hands it to somebody else
        repo      = true, -- marks it repossessed
        removekey = true, -- strips a keyholder's access
    }
    if HOUSING_DESTRUCTIVE[action] and not AllowedToExecuteAction(_source, "delete_housing") then
        print(('^1[vorp_admin]^7 %s tried %s on house %d without delete_housing')
            :format(GetPlayerName(_source) or _source, action, id))
        TriggerClientEvent('vorp_admin:panelToast', _source,
            'That is Management only.', true)
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end

    local HOUSING_ACTIONS <const> = {
        setprice  = function() return exports['pup_realestate']:adminSetHousePrice(id, tonumber(data.value)) end,
        settax    = function() return exports['pup_realestate']:adminSetHouseTax(id, tonumber(data.value)) end,
        -- furniture placement radius and storage slots
        setrange  = function() return exports['pup_realestate']:adminSetHouseRange(id, tonumber(data.value)) end,
        setslots  = function() return exports['pup_realestate']:adminSetHouseSlots(id, tonumber(data.value)) end,
        repo      = function() return exports['pup_realestate']:adminSetHouseRepo(id, data.state == true) end,
        seize     = function() return exports['pup_realestate']:adminSeizeHouse(id) end,
        delete    = function() return exports['pup_realestate']:adminDeleteHouse(id) end,
        transfer  = function() return exports['pup_realestate']:adminTransferHouse(id, tonumber(data.charid)) end,
        removekey = function() return exports['pup_realestate']:adminRemoveKeyholder(id, tonumber(data.charid)) end,
    }
    local fn = HOUSING_ACTIONS[action]
    if not fn then return end

    local ok, res = pcall(fn)
    if ok and type(res) == 'table' and res.ok then
        -- `value` is what the export ACTUALLY stored
        local applied = res.value
        local msg = applied ~= nil
            and ("Housing: %s on house %d -> %s"):format(action, id, tostring(applied))
            or ("Housing: %s on house %d done"):format(action, id)
        Core.NotifyRightTip(_source, msg, 5000)
        TriggerClientEvent('vorp_admin:panelToast', _source, msg, false)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelHousing, "Admin Panel - Housing",
            ("Housing %s on house %d %s"):format(action, id, data.value and ("value " .. tostring(data.value)) or (data.charid and ("charid " .. tostring(data.charid)) or "")))
    else
        -- a pcall failure here is almost always a MISSING EXPORT, i.e. pup-housing was not restarted after the export was added
        local why = type(res) == 'table' and res.err or tostring(res or "error")
        if not ok then why = "pup_realestate rejected the call (is it restarted?): " .. why end
        Core.NotifyRightTip(_source, "Housing action failed: " .. why, 6000)
        TriggerClientEvent('vorp_admin:panelToast', _source, "Housing action failed: " .. why, true)
    end
end)

-- open the house's real storage container for this admin (owner controls, from anywhere).
-- pup_realestate checks manage_housing again through allowedToExecuteAction.
RegisterNetEvent('vorp_admin:housing:openStorage', function(id)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_housing") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if GetResourceState('pup_realestate') ~= 'started' then
        return Core.NotifyRightTip(_source, "pup_realestate is not running", 5000)
    end
    id = tonumber(id)
    if not id then return end

    local ok, done, why = pcall(function()
        return exports['pup_realestate']:adminOpenStorage(_source, id)
    end)
    if not ok or done ~= true then
        return Core.NotifyRightTip(_source,
            "Could not open the house storage: " .. tostring(why or "error"), 6000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelHousing, "Admin Panel - Housing",
        ("Opened the storage of house %d"):format(id))
end)

-- BANKS (pup-bank bridge): every character's branch balances and cash, gated manage_bank. pup-bank reads the DB on
-- every operation, so writing bank_users directly is safe; cash goes through the live character when they are online.

-- branch columns straight from the table, so a new bank in pup-bank shows up without touching this
local function bankColumns()
    local cols = {}
    local rows = MySQL.query.await("SHOW COLUMNS FROM bank_users") or {}
    for _, r in ipairs(rows) do
        local f = tostring(r.Field or "")
        if f:sub(-6) == "_money" and f ~= "total_money" then cols[#cols + 1] = f end
    end
    table.sort(cols)
    return cols
end

local function bankLabel(col)
    local name = col:gsub("_money$", "")
    local PRETTY <const> = { saintdenis = "Saint Denis" }
    return PRETTY[name] or (name:sub(1, 1):upper() .. name:sub(2))
end

local function onlineSourceByCharId(charid)
    for _, sid in ipairs(GetPlayers()) do
        local u = Core.getUser(tonumber(sid))
        local ch = u and u.getUsedCharacter
        if ch and tonumber(ch.charIdentifier) == charid then return tonumber(sid), ch end
    end
    return nil
end

Core.Callback.Register("vorp_admin:Callback:panelBanks", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_bank") then return cb(false) end

    local cols = bankColumns()
    local banks = {}
    for i, c in ipairs(cols) do banks[i] = { col = c, label = bankLabel(c) } end

    local sel = "c.charidentifier, c.firstname, c.lastname, c.money AS cash, c.gold"
    for _, c in ipairs(cols) do sel = sel .. ", b." .. c end
    local rows = MySQL.query.await(
        "SELECT " .. sel .. " FROM characters c LEFT JOIN bank_users b ON b.charidentifier = c.charidentifier") or {}

    local list = {}
    for _, r in ipairs(rows) do
        local branches, total = {}, 0
        for _, c in ipairs(cols) do
            local v = tonumber(r[c]) or 0
            branches[c] = v
            total = total + v
        end
        list[#list + 1] = {
            charid   = tonumber(r.charidentifier),
            name     = ((r.firstname or "") .. " " .. (r.lastname or "")):gsub("^%s+", ""):gsub("%s+$", ""),
            cash     = tonumber(r.cash) or 0,
            gold     = tonumber(r.gold) or 0,
            bank     = total,
            branches = branches,
        }
    end
    table.sort(list, function(a, b) return a.bank > b.bank end)

    -- names for the ledger rows; bank_activity stores the charid
    local names = {}
    for _, e in ipairs(list) do names[tostring(e.charid)] = e.name end
    local activity = MySQL.query.await(
        "SELECT charidentifier, bank, ts, type, amount, balance_after, actor FROM bank_activity ORDER BY id DESC LIMIT 400") or {}
    for _, a in ipairs(activity) do
        a.charid = tonumber(a.charidentifier)
        a.charidentifier = nil
        a.name = names[tostring(a.charid)] or ("char " .. tostring(a.charid))
    end

    cb({ list = list, banks = banks, activity = activity, now = os.time() })
end)

RegisterNetEvent('vorp_admin:bank:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_bank") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local action = tostring(data.action or '')
    local charid = tonumber(data.charid)
    if not charid then return end

    -- setting a balance is correctable; wiping one is not. setbank/setcash run
    -- the SAME code path as the wipes with the value swapped in, so setting 0
    -- is a wipe by another name and has to clear the same gate.
    local isWipe = (action == 'wipebank' or action == 'wipecash')
        or ((action == 'setbank' or action == 'setcash') and (tonumber(data.value) or 0) <= 0)
    if isWipe and not AllowedToExecuteAction(_source, "wipe_money") then
        print(('^1[vorp_admin]^7 %s tried %s (value %s) on char %d without wipe_money')
            :format(GetPlayerName(_source) or _source, action, tostring(data.value), charid))
        return TriggerClientEvent('vorp_admin:panelToast', _source,
            'Wiping money is Management only.', true)
    end

    local admin = Core.getUser(_source)
    local adminChar = admin and admin.getUsedCharacter
    local actor = "ADMIN " .. (adminChar and ((adminChar.firstname or "") .. " " .. (adminChar.lastname or "")) or (GetPlayerName(_source) or "?"))

    local function ledger(bankName, typ, amount, after)
        MySQL.insert("INSERT INTO bank_activity (charidentifier, bank, ts, type, amount, balance_after, actor) VALUES (?, ?, ?, ?, ?, ?, ?)",
            { charid, bankName, os.time(), typ, amount, after, actor })
    end

    local cols = bankColumns()
    local colSet = {}
    for _, c in ipairs(cols) do colSet[c] = true end

    local msg
    if action == 'wipebank' or action == 'setbank' then
        local value = action == 'wipebank' and 0 or tonumber(data.value)
        if not value or value < 0 then return end
        local targets = {}
        if data.bank and data.bank ~= '' then
            if not colSet[tostring(data.bank)] then return end
            targets[1] = tostring(data.bank)
        elseif action == 'wipebank' then
            targets = cols
        else
            return
        end
        local row = MySQL.single.await("SELECT * FROM bank_users WHERE charidentifier = ?", { charid })
        if not row then
            local c = MySQL.single.await("SELECT identifier FROM characters WHERE charidentifier = ?", { charid })
            if not c then return end
            MySQL.insert.await("INSERT INTO bank_users (identifier, steamname, charidentifier) VALUES (?, ?, ?)", { c.identifier, "", charid })
            row = {}
        end
        local set, params = {}, {}
        for _, c in ipairs(targets) do
            local before = tonumber(row[c]) or 0
            set[#set + 1] = "`" .. c .. "` = ?"
            params[#params + 1] = value
            if before ~= value then ledger(bankLabel(c) .. " Bank", action == 'wipebank' and "adminwipe" or "adminset", value - before, value) end
        end
        -- total_money is a running sum in pup-bank; rebuild it from the branches
        local total = 0
        for _, c in ipairs(cols) do
            local v = tonumber(row[c]) or 0
            for _, t in ipairs(targets) do if t == c then v = value end end
            total = total + v
        end
        set[#set + 1] = "`total_money` = ?"
        params[#params + 1] = total
        params[#params + 1] = charid
        MySQL.update.await("UPDATE bank_users SET " .. table.concat(set, ", ") .. " WHERE charidentifier = ?", params)
        msg = action == 'wipebank'
            and ("Bank: wiped %s for char %d"):format(#targets == #cols and "every branch" or bankLabel(targets[1]), charid)
            or ("Bank: %s set to $%.2f for char %d"):format(bankLabel(targets[1]), value, charid)

    elseif action == 'wipecash' or action == 'setcash' then
        local value = action == 'wipecash' and 0 or tonumber(data.value)
        if not value or value < 0 then return end
        local src, ch = onlineSourceByCharId(charid)
        if ch then
            local cur = tonumber(ch.money) or 0
            if value < cur then ch.removeCurrency(0, cur - value) elseif value > cur then ch.addCurrency(0, value - cur) end
        else
            MySQL.update.await("UPDATE characters SET money = ? WHERE charidentifier = ?", { value, charid })
        end
        msg = ("Cash: set to $%.2f for char %d%s"):format(value, charid, ch and " (online)" or " (offline)")
    else
        return
    end

    Core.NotifyRightTip(_source, msg, 5000)
    TriggerClientEvent('vorp_admin:panelToast', _source, msg, false)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelBank, "Admin Panel - Banks", msg)
end)

-- HIDEOUTS (pup_hideouts bridge): the resource keeps every hideout in memory, so reads and writes go through its
-- exports and reach players in-game at once. Gated manage_hideouts.
Core.Callback.Register("vorp_admin:Callback:panelHideouts", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_hideouts") then return cb(false) end
    if GetResourceState('pup_hideouts') ~= 'started' then return cb({ missing = true }) end
    local ok, res = pcall(function() return exports['pup_hideouts']:AdminList() end)
    if not ok or type(res) ~= 'table' then return cb(false) end
    cb(res)
end)

RegisterNetEvent('vorp_admin:hideout:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_hideouts") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    if GetResourceState('pup_hideouts') ~= 'started' then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "pup_hideouts is not running", true)
    end

    -- running a hideout is one thing; emptying its stash or deleting it is another
    local HIDEOUT_DESTRUCTIVE <const> = {
        delete = true, wipestash = true, wipeledger = true, clearproduction = true,
        setledger     = true, -- shares wipeledger's code path: a value of 0 IS a wipe
        removeitem    = true, -- pulls an item out of someone else's stash
        evict         = true, -- throws the owner out
        setowner      = true, -- hands the hideout to somebody else
        removecoowner = true,
    }
    local action <const> = tostring(data.action or '')
    if HIDEOUT_DESTRUCTIVE[action] and not AllowedToExecuteAction(_source, "delete_hideout") then
        print(('^1[vorp_admin]^7 %s tried %s on hideout %s without delete_hideout')
            :format(GetPlayerName(_source) or _source, action, tostring(data.id)))
        return TriggerClientEvent('vorp_admin:panelToast', _source,
            'That is Management only.', true)
    end

    -- "move it to where I am standing": the coords are read off the admin's ped
    -- HERE rather than taken from the panel, so they cannot be dictated by a client
    if action == 'movehere' then
        local ped <const> = GetPlayerPed(_source)
        if not ped or ped == 0 then
            return TriggerClientEvent('vorp_admin:panelToast', _source, 'Could not read your position.', true)
        end
        local c <const> = GetEntityCoords(ped)
        data.coords = { x = c.x, y = c.y, z = c.z }
    end

    local ok, done, why = pcall(function()
        return exports['pup_hideouts']:AdminAction(action, tonumber(data.id), data)
    end)
    if not ok then done, why = false, tostring(done) end
    if not done then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "Hideout action failed: " .. tostring(why or 'unknown'), true)
    end
    local msg = "Hideout: " .. tostring(why)
    Core.NotifyRightTip(_source, msg, 5000)
    TriggerClientEvent('vorp_admin:panelToast', _source, msg, false)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelHideouts, "Admin Panel - Hideouts", msg)
end)

-- open the hideout's real stash panel for this admin (owner controls, from anywhere).
-- pup_hideouts checks manage_hideouts again, on the open and on every take or deposit.
RegisterNetEvent('vorp_admin:hideout:openStash', function(id)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_hideouts") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if GetResourceState('pup_hideouts') ~= 'started' then
        return Core.NotifyRightTip(_source, "pup_hideouts is not running", 5000)
    end
    id = tonumber(id)
    if not id then return end

    local ok, done, why = pcall(function()
        return exports['pup_hideouts']:AdminOpenStash(_source, id)
    end)
    if not ok or done ~= true then
        return Core.NotifyRightTip(_source,
            "Could not open the hideout stash: " .. tostring(why or "error"), 6000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelHideouts, "Admin Panel - Hideouts",
        ("Opened the stash of hideout #%d"):format(id))
end)

-- CURSES (pup_shaman bridge): who carries what; give, ease or cleanse. Gated manage_curses.
Core.Callback.Register("vorp_admin:Callback:panelCurses", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_curses") then return cb(false) end
    if GetResourceState('pup_shaman') ~= 'started' then return cb({ missing = true }) end
    local ok, res = pcall(function() return exports['pup_shaman']:AdminList() end)
    if not ok or type(res) ~= 'table' then return cb(false) end
    cb(res)
end)

RegisterNetEvent('vorp_admin:curse:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_curses") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    if GetResourceState('pup_shaman') ~= 'started' then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "pup_shaman is not running", true)
    end
    local ok, done, why = pcall(function() return exports['pup_shaman']:AdminAction(tostring(data.action or ''), data) end)
    if not ok then done, why = false, tostring(done) end
    if not done then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "Curse action failed: " .. tostring(why or 'unknown'), true)
    end
    local msg = "Curses: " .. tostring(why)
    TriggerClientEvent('vorp_admin:panelToast', _source, msg, false)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCurses, "Admin Panel - Curses", msg)
end)

-- FARMS (pup_homestead bridge): every plant in the ground; pull up one or all of a character's. Gated manage_farms.
Core.Callback.Register("vorp_admin:Callback:panelFarms", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_farms") then return cb(false) end
    if GetResourceState('pup_homestead') ~= 'started' then return cb({ missing = true }) end
    local ok, res = pcall(function() return exports['pup_homestead']:AdminList() end)
    if not ok or type(res) ~= 'table' then return cb(false) end
    cb(res)
end)

RegisterNetEvent('vorp_admin:farm:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_farms") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    if GetResourceState('pup_homestead') ~= 'started' then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "pup_homestead is not running", true)
    end
    local ok, done, why = pcall(function() return exports['pup_homestead']:AdminAction(tostring(data.action or ''), data) end)
    if not ok then done, why = false, tostring(done) end
    if not done then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "Farm action failed: " .. tostring(why or 'unknown'), true)
    end
    local msg = "Farms: " .. tostring(why)
    TriggerClientEvent('vorp_admin:panelToast', _source, msg, false)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelFarms, "Admin Panel - Farms", msg)
end)

-- CAMPS (pup_camps bridge): the resource keeps every camp in memory, so reads and writes go through
-- its exports and reach players in-game at once. Gated manage_camps.
Core.Callback.Register("vorp_admin:Callback:panelCamps", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_camps") then return cb(false) end
    if GetResourceState('pup_camps') ~= 'started' then return cb({ missing = true }) end
    local ok, res = pcall(function() return exports['pup_camps']:AdminList() end)
    if not ok or type(res) ~= 'table' then return cb(false) end
    cb(res)
end)

RegisterNetEvent('vorp_admin:camp:action', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_camps") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    if GetResourceState('pup_camps') ~= 'started' then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "pup_camps is not running", true)
    end

    -- running a camp is one thing; emptying its stash or disbanding it is another
    local CAMP_DESTRUCTIVE <const> = {
        delete = true, wipestash = true, wipeledger = true, wipetax = true, repo = true,
        setledger    = true, -- shares wipeledger's code path: a value of 0 IS a wipe
        settax       = true, -- same, for wipetax
        removeitem   = true, -- pulls an item out of the camp stash
        removemember = true, -- throws a member out of the camp
        setleader    = true, -- hands the camp to somebody else
    }
    local action <const> = tostring(data.action or '')
    if CAMP_DESTRUCTIVE[action] and not AllowedToExecuteAction(_source, "delete_camp") then
        print(('^1[vorp_admin]^7 %s tried %s on camp %s without delete_camp')
            :format(GetPlayerName(_source) or _source, action, tostring(data.id)))
        return TriggerClientEvent('vorp_admin:panelToast', _source,
            'That is Management only.', true)
    end

    local ok, done, why = pcall(function()
        return exports['pup_camps']:AdminAction(action, tonumber(data.id), data)
    end)
    if not ok then done, why = false, tostring(done) end
    if not done then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "Camp action failed: " .. tostring(why or 'unknown'), true)
    end
    local msg = "Camp: " .. tostring(why)
    Core.NotifyRightTip(_source, msg, 5000)
    TriggerClientEvent('vorp_admin:panelToast', _source, msg, false)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCamps, "Admin Panel - Camps", msg)
end)

-- open the camp's real stash panel for this admin (leader controls, from anywhere).
-- pup_camps checks manage_camps again, on the open and on every take or deposit.
RegisterNetEvent('vorp_admin:camp:openStash', function(id)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_camps") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if GetResourceState('pup_camps') ~= 'started' then
        return Core.NotifyRightTip(_source, "pup_camps is not running", 5000)
    end
    id = tonumber(id)
    if not id then return end

    local ok, done, why = pcall(function()
        return exports['pup_camps']:AdminOpenStash(_source, id)
    end)
    if not ok or done ~= true then
        return Core.NotifyRightTip(_source,
            "Could not open the camp stash: " .. tostring(why or "error"), 6000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCamps, "Admin Panel - Camps",
        ("Opened the stash of camp #%d"):format(id))
end)

-- WORLD PROPS (pup-props bridge): browse gated list_world_props, delete gated delete_world_prop
Core.Callback.Register("vorp_admin:Callback:panelProps", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "list_world_props") then return cb(false) end
    if GetResourceState('pup-props') ~= 'started' then return cb({ missing = true }) end
    local ok, res = pcall(function() return exports['pup-props']:adminList() end)
    if not ok or type(res) ~= 'table' then return cb(false) end
    cb({ list = res, canDelete = AllowedToExecuteAction(_source, "delete_world_prop") == true })
end)

RegisterNetEvent('vorp_admin:prop:delete', function(id)
    local _source = source
    -- deleting is a permanent map change: its own key, never manage.*
    if not AllowedToExecuteAction(_source, "delete_world_prop") then
        print(('^1[vorp_admin]^7 %s tried to delete world prop %s without delete_world_prop')
            :format(GetPlayerName(_source) or _source, tostring(id)))
        return TriggerClientEvent('vorp_admin:panelToast', _source, 'That is Management only.', true)
    end
    if GetResourceState('pup-props') ~= 'started' then
        return TriggerClientEvent('vorp_admin:panelToast', _source, 'pup-props is not running', true)
    end

    local ok, done = pcall(function() return exports['pup-props']:adminDelete(tonumber(id), _source) end)
    if not ok or not done then
        return TriggerClientEvent('vorp_admin:panelToast', _source, 'That prop is already gone.', true)
    end
    local msg = ('World prop #%s removed'):format(tostring(id))
    Core.NotifyRightTip(_source, msg, 5000)
    TriggerClientEvent('vorp_admin:panelToast', _source, msg, false)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelProps, "Admin Panel - World Props", msg)
end)

-- CONSUMABLES (fred_metabolism bridge): browse gated open_menu, writes gated admin_actions_menu
Core.Callback.Register("vorp_admin:Callback:consumablesList", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end
    if GetResourceState('fred_metabolism') ~= 'started' then return cb({ missing = true }) end
    local ok, res = pcall(function() return exports['fred_metabolism']:getConsumables() end)
    if not ok or type(res) ~= 'table' then return cb(false) end

    -- image audit for EVERY consumable, not just on save
    local images = {}
    for _, it in ipairs(res.items or {}) do
        local n = tostring(it.Name or '')
        if n ~= '' then
            images[n] = LoadResourceFile('vorp_inventory', 'html/img/items/' .. n .. '.png') ~= nil
        end
    end
    res.images = images
    cb(res)
end)

-- smokes: the smokes table, owned by pup-misc
local function smokesExport(fn, arg)
    local ok, a, b = pcall(function() return exports['pup-misc'][fn](exports['pup-misc'], arg) end)
    if not ok then return nil, 'pup-misc is not running' end
    return a, b
end

RegisterNetEvent('vorp_admin:smokes:list', function()
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then return end
    local list = smokesExport('smokesList')
    TriggerClientEvent('vorp_admin:smokes:recv', _source, type(list) == 'table' and list or {})
end)

RegisterNetEvent('vorp_admin:smokes:save', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local ok, note = smokesExport('smokesSave', data)
    if not ok then
        return Core.NotifyRightTip(_source, "smoke save failed: " .. tostring(note or 'unknown'), 6000)
    end
    Core.NotifyRightTip(_source, "Smoke saved and pushed live" .. (note and (" | " .. note) or ""), 9000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelConsumables, "Admin Panel - Smokes",
        ("Smoke saved: %s"):format(tostring(data.Name)))
end)

RegisterNetEvent('vorp_admin:smokes:delete', function(name)
    local _source = source
    if not AllowedToExecuteAction(_source, "delete_consumable") then
        print(('^1[vorp_admin]^7 %s tried to DELETE smoke %s without delete_consumable')
            :format(GetPlayerName(_source) or _source, tostring(name)))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end
    local ok, err = smokesExport('smokesDelete', tostring(name or ''))
    Core.NotifyRightTip(_source, ok and "Smoke removed" or ("delete failed: " .. tostring(err or 'unknown')), 6000)
    if ok then
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelConsumables, "Admin Panel - Smokes",
            ("Smoke deleted: %s"):format(tostring(name)))
    end
end)

RegisterNetEvent('vorp_admin:consumables:save', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local ok, res = pcall(function() return exports['fred_metabolism']:upsertConsumable(data) end)
    if not ok or type(res) ~= 'table' then
        return Core.NotifyRightTip(_source, "consumable save failed (is fred_metabolism running?)", 6000)
    end
    if not res.ok then
        return Core.NotifyRightTip(_source, "consumable save failed: " .. tostring(res.err), 6000)
    end
    local msg = "Consumable saved and pushed live"
    if res.createdItem then msg = msg .. " | item row created - restart vorp_inventory to carry it" end
    if res.imageMissing then msg = msg .. " | no image: add html/img/items/" .. tostring(data.Name) .. ".png in vorp_inventory" end
    Core.NotifyRightTip(_source, msg, 9000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelConsumables, "Admin Panel - Consumables",
        ("Consumable upserted: %s"):format(tostring(data.Name)))
end)

RegisterNetEvent('vorp_admin:consumables:delete', function(name)
    local _source = source
    if not AllowedToExecuteAction(_source, "delete_consumable") then
        print(('^1[vorp_admin]^7 %s tried to DELETE consumable %s without delete_consumable')
            :format(GetPlayerName(_source) or _source, tostring(name)))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end
    local ok, res = pcall(function() return exports['fred_metabolism']:deleteConsumable(tostring(name or '')) end)
    if ok and type(res) == 'table' and res.ok then
        Core.NotifyRightTip(_source, "Consumable deleted and pushed live", 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelConsumables, "Admin Panel - Consumables",
            ("Consumable deleted: %s"):format(tostring(name)))
    else
        Core.NotifyRightTip(_source, "Delete failed: " .. tostring(type(res) == 'table' and res.err or "error"), 6000)
    end
end)

-- CRAFTING RECIPES (pup-crafting bridge): browse gated open_menu, writes gated manage_crafting
Core.Callback.Register("vorp_admin:Callback:craftRecipesList", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end
    if GetResourceState('pup_workbench') ~= 'started' then return cb({ missing = true }) end
    local ok, recipes = pcall(function() return exports['pup_workbench']:GetRecipesAdmin() end)
    if not ok or type(recipes) ~= 'table' then return cb(false) end
    local cats = {}
    pcall(function() cats = exports['pup_workbench']:GetCraftCategories() end)
    -- station names go with the recipes so the editor can list what is valid to type in the Stations field
    local locNames = {}
    pcall(function()
        for _, l in ipairs(exports['pup_workbench']:GetLocationsAdmin() or {}) do
            if l.enabled ~= false then locNames[#locNames + 1] = l.name end
        end
    end)
    table.sort(locNames)
    cb({ recipes = recipes, categories = cats, locationNames = locNames,
        canWrite = AllowedToExecuteAction(_source, "manage_crafting") })
end)

RegisterNetEvent('vorp_admin:craft:save', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_crafting") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local ok, id = pcall(function() return exports['pup_workbench']:UpsertRecipe(data) end)
    if ok and id then
        Core.NotifyRightTip(_source, "Recipe saved - live when a player re-opens a station", 7000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCrafting, "Admin Panel - Crafting",
            ("Craft recipe upserted: %s (id %s)"):format(tostring(data.name), tostring(id)))
    else
        Core.NotifyRightTip(_source, "Recipe save failed (name, category, at least one material AND reward required)", 7000)
    end
end)

RegisterNetEvent('vorp_admin:craft:setEnabled', function(id, enabled)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_crafting") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    local ok = pcall(function() return exports['pup_workbench']:SetRecipeEnabled(id, enabled and true or false) end)
    if ok then
        Core.NotifyRightTip(_source, enabled and "Recipe enabled" or "Recipe disabled", 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCrafting, "Admin Panel - Crafting",
            ("Craft recipe %s: id %s"):format(enabled and "enabled" or "disabled", tostring(id)))
    end
end)

-- Item autocomplete for the recipe editors (crafting + weapon crafting): substring search on the items DB
Core.Callback.Register("vorp_admin:Callback:craftItemSearch", function(source, cb, q)
    local _source = source
    if not Core.getUser(_source) then return cb({}) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb({}) end
    q = tostring(q or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #q < 2 then return cb({}) end
    local like = '%' .. q .. '%'
    MySQL.query("SELECT item, label FROM items WHERE item LIKE ? OR label LIKE ? ORDER BY item LIMIT 12",
        { like, like }, function(rows)
            cb(rows or {})
        end)
end)

-- charid -> character name, for the recipe character-lock editor
Core.Callback.Register("vorp_admin:Callback:craftCharLookup", function(source, cb, charid)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end
    charid = tonumber(charid)
    if not charid or charid <= 0 then return cb(false) end
    MySQL.query("SELECT firstname, lastname FROM characters WHERE charidentifier = ?", { charid }, function(rows)
        if rows and rows[1] then
            cb({ charid = charid, name = ((rows[1].firstname or '') .. ' ' .. (rows[1].lastname or '')):gsub('^%s+', ''):gsub('%s+$', '') })
        else
            cb(false)
        end
    end)
end)

-- WEAPON CRAFTING STATIONS (pup_gunsmith bridge). Live: every write is pushed
-- to players by that resource, so nothing here needs a restart.
Core.Callback.Register("vorp_admin:Callback:weaponCraftLocations", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "manage_crafting") then return cb(false) end
    if GetResourceState('pup_gunsmith') ~= 'started' then return cb({ missing = true }) end
    local ok, rows = pcall(function() return exports['pup_gunsmith']:GetWeaponCraftLocations() end)
    if not ok or type(rows) ~= 'table' then return cb(false) end
    for _, r in ipairs(rows) do
        r.enabled = (r.enabled == true) or (tonumber(r.enabled) == 1)
        local okj, j = pcall(json.decode, r.job or '[]')
        r.jobs = (okj and type(j) == 'table') and table.concat(j, ', ') or tostring(r.job or '')
        r.job = nil
    end
    cb({ rows = rows, canWrite = true })
end)

RegisterNetEvent('vorp_admin:weaponCraft:location', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_crafting") then
        print(('^1[vorp_admin]^7 %s tried to change a weapon station without manage_crafting')
            :format(GetPlayerName(_source) or _source))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end
    if type(data) ~= 'table' then return end
    local act <const> = tostring(data.act or '')
    local name <const> = tostring(data.name or '')
    local ok, res

    if act == 'enable' or act == 'disable' then
        ok, res = pcall(function()
            return exports['pup_gunsmith']:SetWeaponCraftLocationEnabled(name, act == 'enable')
        end)
    elseif act == 'delete' then
        ok, res = pcall(function() return exports['pup_gunsmith']:DeleteWeaponCraftLocation(name) end)
    elseif act == 'jobs' or act == 'move' then
        local cur = nil
        for _, r in ipairs(exports['pup_gunsmith']:GetWeaponCraftLocations() or {}) do
            if r.name == name then cur = r break end
        end
        if not cur then return Core.NotifyRightTip(_source, "No station by that name", 5000) end

        -- 'move' carries a new position; 'jobs' keeps the one it has
        local x = (act == 'move') and tonumber(data.x) or tonumber(cur.x)
        local y = (act == 'move') and tonumber(data.y) or tonumber(cur.y)
        local z = (act == 'move') and tonumber(data.z) or tonumber(cur.z)
        if not x or not y or not z then
            return Core.NotifyRightTip(_source, "Those coordinates are not numbers", 5000)
        end

        ok, res = pcall(function()
            return exports['pup_gunsmith']:UpsertWeaponCraftLocation(name, x, y, z, data.jobs or '')
        end)
    else
        return
    end

    if ok and res then
        Core.NotifyRightTip(_source, "Station updated - live now", 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Weapon Crafting",
            ("Station %s: %s"):format(name, act))
    else
        Core.NotifyRightTip(_source, "That did not work", 5000)
    end
end)

-- SERVER BANS: the list, the search, and lifting one. Engine is server/bans.lua.
Core.Callback.Register("vorp_admin:Callback:bansList", function(source, cb, search, showLifted)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "server_bans_view") then return cb(false) end

    search = tostring(search or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local where, args = {}, {}
    if not showLifted then where[#where + 1] = 'active = 1' end
    if search ~= '' then
        local like = '%' .. search .. '%'
        where[#where + 1] = '(ban_id LIKE ? OR playername LIKE ? OR charname LIKE ? OR steam LIKE ? OR discord LIKE ? OR license LIKE ? OR ip LIKE ? OR reason LIKE ?)'
        for _ = 1, 8 do args[#args + 1] = like end
    end
    local sql = 'SELECT * FROM admin_bans'
    if #where > 0 then sql = sql .. ' WHERE ' .. table.concat(where, ' AND ') end
    sql = sql .. ' ORDER BY id DESC LIMIT 200'

    local rows = MySQL.query.await(sql, args) or {}
    for _, r in ipairs(rows) do
        -- oxmysql returns TINYINT(1) as a boolean, so accept both shapes
        r.active = (r.active == true) or (tonumber(r.active) == 1)
        local okt, t = pcall(json.decode, r.tokens or '[]')
        r.tokenCount = (okt and type(t) == 'table') and #t or 0
        r.tokens = nil -- the panel only needs the count, never the values
    end
    -- the header figures, counted across the whole table rather than this page
    local stats = MySQL.single.await([[
        SELECT
          COUNT(*)                                                            AS total,
          SUM(active = 1)                                                     AS inforce,
          SUM(active = 0)                                                     AS lifted,
          SUM(created >= DATE_SUB(NOW(), INTERVAL 7 DAY))                     AS last7d
        FROM admin_bans
    ]], {}) or {}

    -- who has issued one, for the "By any admin" filter
    local admins = {}
    for _, a in ipairs(MySQL.query.await("SELECT DISTINCT staff FROM admin_bans WHERE staff <> '' ORDER BY staff", {}) or {}) do
        admins[#admins + 1] = a.staff
    end

    cb({ rows = rows, canWrite = AllowedToExecuteAction(_source, "server_unban"),
         admins = admins,
         stats = {
            total   = tonumber(stats.total) or 0,
            inforce = tonumber(stats.inforce) or 0,
            lifted  = tonumber(stats.lifted) or 0,
            last7d  = tonumber(stats.last7d) or 0,
         } })
end)

-- Find someone to ban: a live server id, a char id, a name, or any identifier.
-- Online hits are richer - only a live session gives us licence and hardware tokens.
Core.Callback.Register("vorp_admin:Callback:banLookup", function(source, cb, term)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "server_ban") then return cb(false) end
    term = tostring(term or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if term == '' then return cb({ rows = {} }) end

    local found, seen = {}, {}
    local function add(row)
        local key = tostring(row.charid or row.steam or row.online)
        if key ~= 'nil' and not seen[key] then seen[key] = true found[#found + 1] = row end
    end

    -- anyone online whose server id, name or identifier matches
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local user = Core.getUser(src)
        local ch = user and user.getUsedCharacter
        local name = GetPlayerName(src) or ''
        local idents = table.concat(GetPlayerIdentifiers(src) or {}, ' ')
        local cname = ch and ((ch.firstname or '') .. ' ' .. (ch.lastname or '')) or ''
        if tostring(src) == term
            or (ch and tostring(ch.charIdentifier) == term)
            or name:lower():find(term:lower(), 1, true)
            or cname:lower():find(term:lower(), 1, true)
            or idents:lower():find(term:lower(), 1, true) then
            add({ charid = ch and ch.charIdentifier, charname = cname, playername = name,
                  steam = ch and ch.identifier or '', online = src })
        end
    end

    -- and the database, so an offline player can still be banned
    local like = '%' .. term .. '%'
    local rows = MySQL.query.await([[
        SELECT charidentifier, identifier, steamname, firstname, lastname
        FROM characters
        WHERE charidentifier = ? OR identifier LIKE ? OR steamname LIKE ?
           OR CONCAT(firstname, ' ', lastname) LIKE ?
        ORDER BY charidentifier LIMIT 25
    ]], { tonumber(term) or -1, like, like, like }) or {}
    for _, r in ipairs(rows) do
        add({ charid = r.charidentifier, steam = r.identifier,
              charname = ((r.firstname or '') .. ' ' .. (r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
              playername = r.steamname or '', online = nil })
    end

    cb({ rows = found })
end)

-- Ban from the Bans page: by live server id when they are on, by identifiers when not.
RegisterNetEvent('vorp_admin:bans:banLookup', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "server_ban") then
        print(('^1[vorp_admin]^7 %s tried to BAN without server_ban'):format(GetPlayerName(_source) or _source))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end
    if type(data) ~= 'table' then return end
    local staff = GetPlayerName(_source) or tostring(_source)

    local target
    if tonumber(data.online) then
        target = tonumber(data.online)
    else
        -- offline: no licence and no hardware tokens exist to record, only what the
        -- database knows. Said plainly in the panel so it is not a surprise later.
        target = { steam = tostring(data.steam or ''), name = tostring(data.playername or ''),
                   license = '', discord = '', ip = '', tokens = {} }
    end

    local ok, id, why = pcall(function()
        return exports['vorp_admin']:BanPlayer(target, data.reason, staff, tonumber(data.seconds))
    end)
    if ok and id then
        Core.NotifyRightTip(_source, "Banned - ban id " .. tostring(id), 6000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Bans",
            ("Banned %s: %s - %s"):format(tostring(data.charname or data.playername or '?'), tostring(id), tostring(data.reason)))
    else
        Core.NotifyRightTip(_source, "Ban failed: " .. tostring(why or id or "error"), 6000)
    end
end)

RegisterNetEvent('vorp_admin:bans:unban', function(banId)
    local _source = source
    if not AllowedToExecuteAction(_source, "server_unban") then
        print(('^1[vorp_admin]^7 %s tried to UNBAN %s without server_unban')
            :format(GetPlayerName(_source) or _source, tostring(banId)))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end
    local ok, res, why = pcall(function()
        return exports['vorp_admin']:UnbanPlayer(banId, GetPlayerName(_source) or tostring(_source))
    end)
    if ok and res then
        Core.NotifyRightTip(_source, "Ban " .. tostring(banId) .. " lifted", 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Bans",
            ("Ban %s lifted"):format(tostring(banId)))
    else
        Core.NotifyRightTip(_source, "Could not lift it: " .. tostring(why or "error"), 6000)
    end
end)

RegisterNetEvent('vorp_admin:bans:ban', function(targetSrc, reason, seconds)
    local _source = source
    if not AllowedToExecuteAction(_source, "server_ban") then
        print(('^1[vorp_admin]^7 %s tried to BAN %s without server_ban')
            :format(GetPlayerName(_source) or _source, tostring(targetSrc)))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end
    local staff = GetPlayerName(_source) or tostring(_source)
    local ok, id, why = pcall(function()
        return exports['vorp_admin']:BanPlayer(tonumber(targetSrc), reason, staff, tonumber(seconds))
    end)
    if ok and id then
        Core.NotifyRightTip(_source, "Banned - ban id " .. tostring(id), 6000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.adminBan or Secrets.Webhooks.panelCharacter,
            "Admin Panel - Bans", ("Banned: %s - %s"):format(tostring(id), tostring(reason)))
    else
        Core.NotifyRightTip(_source, "Ban failed: " .. tostring(why or id or "error"), 6000)
    end
end)

-- DEATH LOSSES (pup-medical bridge): what a respawn took, and giving it back
Core.Callback.Register("vorp_admin:Callback:deathLossesList", function(source, cb, charid)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end
    if GetResourceState('pup-medical') ~= 'started' then return cb({ missing = true }) end
    local ok, rows = pcall(function()
        return exports['pup-medical']:GetDeathLosses(100, tonumber(charid))
    end)
    if not ok or type(rows) ~= 'table' then return cb(false) end
    cb({ rows = rows, canWrite = AllowedToExecuteAction(_source, "give_item") })
end)

RegisterNetEvent('vorp_admin:deaths:restore', function(id)
    local _source = source
    if not AllowedToExecuteAction(_source, "give_item") then
        print(('^1[vorp_admin]^7 %s tried to RESTORE death %s without give_item')
            :format(GetPlayerName(_source) or _source, tostring(id)))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end
    local who = GetPlayerName(_source) or tostring(_source)
    local ok, res, why = pcall(function()
        return exports['pup-medical']:RestoreDeathLoss(tonumber(id), who)
    end)
    if ok and res then
        Core.NotifyRightTip(_source, "Belongings returned", 5000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter,
            "Admin Panel - Deaths", ("Death #%s restored - belongings returned"):format(tostring(id)))
    else
        Core.NotifyRightTip(_source, "Restore failed: " .. tostring(why or res or "error"), 6000)
    end
end)

-- steam hex -> steam name and every character on that account, for migrating a legacy steam lock
Core.Callback.Register("vorp_admin:Callback:craftSteamLookup", function(source, cb, hex)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end
    hex = tostring(hex or '')
    if hex == '' then return cb(false) end
    MySQL.query("SELECT charidentifier, steamname, firstname, lastname FROM characters WHERE identifier = ? ORDER BY charidentifier",
        { hex }, function(rows)
            local chars, steamname, have = {}, nil, {}
            for _, r in ipairs(rows or {}) do
                steamname = steamname or r.steamname
                have[r.charidentifier] = true
                chars[#chars + 1] = {
                    charid = r.charidentifier,
                    name = ((r.firstname or '') .. ' ' .. (r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                }
            end
            -- characters that have since been deleted still show, from what pup_workbench
            -- wrote down the last time that account played
            MySQL.query("SELECT charidentifier, steamname, charname, lastseen FROM crafting_lock_owner WHERE identifier = ? ORDER BY charidentifier",
                { hex }, function(hist)
                    for _, r in ipairs(hist or {}) do
                        if steamname == nil or steamname == '' then steamname = r.steamname end
                        if not have[r.charidentifier] then
                            chars[#chars + 1] = { charid = r.charidentifier, name = r.charname or '',
                                                  gone = true, lastseen = tostring(r.lastseen or '') }
                        end
                    end
                    cb({ hex = hex, steamname = steamname, chars = chars })
                end)
        end)
end)

-- CRAFTING LOCATIONS (pup-crafting bridge)
Core.Callback.Register("vorp_admin:Callback:craftLocationsList", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end
    if GetResourceState('pup_workbench') ~= 'started' then return cb({ missing = true }) end
    local ok, locs = pcall(function() return exports['pup_workbench']:GetLocationsAdmin() end)
    if not ok then return cb(false) end
    cb({ locations = locs or {}, canWrite = AllowedToExecuteAction(_source, "manage_crafting") })
end)

RegisterNetEvent('vorp_admin:craft:saveLocation', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_crafting") then
        TriggerClientEvent('vorp_admin:panelToast', _source, "You do not have manage_crafting", true)
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    if GetResourceState('pup_workbench') ~= 'started' then
        return TriggerClientEvent('vorp_admin:panelToast', _source, "pup_workbench is not running", true)
    end
    local ok, name = pcall(function() return exports['pup_workbench']:UpsertLocation(data) end)
    if not ok then
        print(("^1[vorp_admin]^7 craft:saveLocation: %s"):format(tostring(name)))
    end
    -- panelToast, NOT NotifyRightTip
    if ok and name then
        local msg = ("Location saved: %s at %.2f, %.2f, %.2f")
            :format(tostring(name), tonumber(data.x) or 0, tonumber(data.y) or 0, tonumber(data.z) or 0)
        TriggerClientEvent('vorp_admin:panelToast', _source, msg, false)
        Core.NotifyRightTip(_source, msg, 6000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCrafting, "Admin Panel - Crafting",
            ("Craft location saved: %s"):format(tostring(name)))
    else
        local msg = "Location save FAILED - see the server console for the reason"
        TriggerClientEvent('vorp_admin:panelToast', _source, msg, true)
        Core.NotifyRightTip(_source, msg, 6000)
    end
end)

RegisterNetEvent('vorp_admin:craft:setLocationEnabled', function(name, enabled)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_crafting") then
        TriggerClientEvent('vorp_admin:panelToast', _source, "You do not have manage_crafting", true)
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    local ok = pcall(function() exports['pup_workbench']:SetLocationEnabled(tostring(name), enabled and true or false) end)
    local msg = ok and (("%s %s"):format(tostring(name), enabled and "enabled" or "disabled"))
        or ("Could not change " .. tostring(name))
    TriggerClientEvent('vorp_admin:panelToast', _source, msg, not ok)
    Core.NotifyRightTip(_source, msg, 5000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCrafting, "Admin Panel - Crafting",
        ("Craft location %s: %s"):format(enabled and "enabled" or "disabled", tostring(name)))
end)

-- WEAPON CRAFTING RECIPES (pup-weapons bridge). Same manage_crafting gate.
Core.Callback.Register("vorp_admin:Callback:weaponRecipesList", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end
    if GetResourceState('pup_gunsmith') ~= 'started' then return cb({ missing = true }) end
    local ok, recipes = pcall(function() return exports['pup_gunsmith']:GetWeaponRecipesAdmin() end)
    if not ok or type(recipes) ~= 'table' then return cb(false) end
    local cats = { weapon = {}, ammo = {} }
    pcall(function() cats = exports['pup_gunsmith']:GetWeaponCategories() end)
    cb({ recipes = recipes, categories = cats, canWrite = AllowedToExecuteAction(_source, "manage_crafting") })
end)

RegisterNetEvent('vorp_admin:weapon:save', function(data)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_crafting") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if type(data) ~= 'table' then return end
    local ok, res = pcall(function() return exports['pup_gunsmith']:UpsertWeaponRecipe(data) end)
    if ok and res then
        Core.NotifyRightTip(_source, "Weapon recipe saved - live when a player re-opens a gunsmith", 7000)
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelWeapons, "Admin Panel - Weapons",
            ("Weapon recipe upserted: %s / %s"):format(tostring(data.category), tostring(data.label)))
    else
        Core.NotifyRightTip(_source, "Weapon recipe save failed (category, label, hashname/item+key and at least one material required)", 8000)
    end
end)

RegisterNetEvent('vorp_admin:weapon:setEnabled', function(id, enabled)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_crafting") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    pcall(function() exports['pup_gunsmith']:SetWeaponRecipeEnabled(id, enabled and true or false) end)
    Core.NotifyRightTip(_source, enabled and "Weapon recipe enabled" or "Weapon recipe disabled", 5000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelWeapons, "Admin Panel - Weapons",
        ("Weapon recipe %s: id %s"):format(enabled and "enabled" or "disabled", tostring(id)))
end)

Core.Callback.Register("vorp_admin:Callback:panelMap", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "live_map") then return cb(false) end

    local players = {}
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local ped = GetPlayerPed(sid)
        if ped and ped > 0 then
            local c = GetEntityCoords(ped)
            local name = GetPlayerName(sid) or ("ID " .. sid)
            local job, isStaff, charid
            local user = Core.getUser(s)
            if user then
                local ch = user.getUsedCharacter
                if ch then
                    local full = ((ch.firstname or "") .. " " .. (ch.lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")
                    if full ~= "" then name = full end
                    job = ch.job
                    charid = tonumber(ch.charIdentifier)
                    isStaff = panelIsStaff(s, Config.Permissions.useCharacterGroup and ch.group or user.getGroup)
                end
            end
            players[#players + 1] = {
                id = s, name = name, job = job, charid = charid,
                x = math.floor(c.x + 0.5), y = math.floor(c.y + 0.5),
                h = math.floor(GetEntityHeading(ped) + 0.5),
                staff = isStaff or false,
            }
        end
    end

    cb({ players = players, me = _source, now = os.time() })
end)

-- PROPERTY LAYERS for the live map: houses, doors, hideouts, camps, shops, ranches. Fetched on demand, not per poll
Core.Callback.Register("vorp_admin:Callback:panelMapLayers", function(source, cb)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "live_map") then return cb(false) end

    local houses = {}
    pcall(function()
        local rows = MySQL.query.await([[SELECT h.id, h.primarydoor, h.buyercharidentifier,
                c.firstname, c.lastname
            FROM playerhousing h
            LEFT JOIN characters c ON c.charidentifier = h.buyercharidentifier]]) or {}
        for _, h in ipairs(rows) do
            local okj, pd = pcall(json.decode, h.primarydoor or "")
            local door = okj and type(pd) == "table" and type(pd[1]) == "table" and pd[1] or nil
            if door and tonumber(door.x) then
                local charid = tonumber(h.buyercharidentifier) or 0
                local ownerName = ((h.firstname or "") .. " " .. (h.lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")
                houses[#houses + 1] = {
                    id = h.id,
                    x = math.floor(door.x + 0.5), y = math.floor(door.y + 0.5),
                    owned = charid > 0,
                    ownerCharid = charid > 0 and charid or nil,
                    ownerName = (charid > 0 and ownerName ~= "") and ownerName or nil,
                }
            end
        end
    end)

    local doors = {}
    pcall(function()
        local rows = MySQL.query.await("SELECT doorid, data FROM doorlock_doors") or {}
        for _, r in ipairs(rows) do
            local okj, dd = pcall(json.decode, r.data or "")
            local first = okj and type(dd) == "table" and type(dd.doors) == "table" and dd.doors[1] or nil
            local cc = first and first.coords or nil
            if type(cc) == "table" and tonumber(cc.x) then
                doors[#doors + 1] = { id = r.doorid, x = math.floor(cc.x + 0.5), y = math.floor(cc.y + 0.5) }
            end
        end
    end)

    -- hideouts: underground rows carry their own coords JSON + owner charid
    local hideouts = {}
    pcall(function()
        local rows = MySQL.query.await([[SELECT u.id, u.charidentifier, u.coords,
                c.firstname, c.lastname
            FROM underground u
            LEFT JOIN characters c ON c.charidentifier = u.charidentifier]]) or {}
        for _, r in ipairs(rows) do
            local okj, cc = pcall(json.decode, r.coords or "")
            if okj and type(cc) == "table" then
                local x = tonumber(cc.x) or (type(cc[1]) == "number" and cc[1]) or nil
                local y = tonumber(cc.y) or (type(cc[2]) == "number" and cc[2]) or nil
                if x and y then
                    local charid = tonumber(r.charidentifier) or 0
                    local ownerName = ((r.firstname or "") .. " " .. (r.lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")
                    hideouts[#hideouts + 1] = {
                        id = r.id,
                        x = math.floor(x + 0.5), y = math.floor(y + 0.5),
                        ownerCharid = charid > 0 and charid or nil,
                        ownerName = ownerName ~= "" and ownerName or nil,
                    }
                end
            end
        end
    end)

    -- clan camps: position + name live inside clan.info JSON; the creator is the first member of info.members
    local clans = {}
    pcall(function()
        local rows = MySQL.query.await("SELECT id, info FROM clan") or {}
        for _, r in ipairs(rows) do
            local okj, info = pcall(json.decode, r.info or "")
            if okj and type(info) == "table" and type(info.coords) == "table" then
                local x, y = tonumber(info.coords.x), tonumber(info.coords.y)
                if x and y then
                    local leader = type(info.members) == "table" and type(info.members[1]) == "table" and info.members[1] or nil
                    clans[#clans + 1] = {
                        id = r.id,
                        name = tostring(info.name or ("Clan #" .. r.id)),
                        x = math.floor(x + 0.5), y = math.floor(y + 0.5),
                        ownerCharid = leader and tonumber(leader.charid) or nil,
                        ownerName = leader and tostring(leader.name or "") or nil,
                        members = type(info.members) == "table" and #info.members or 0,
                    }
                end
            end
        end
    end)

    -- PLAYER SHOPS
    local shops = {}
    pcall(function()
        local rows = MySQL.query.await([[SELECT s.id, s.name, s.coords, s.charidentifier, s.repo,
                s.ledger, c.firstname, c.lastname
            FROM playershops s
            LEFT JOIN characters c ON c.charidentifier = s.charidentifier]]) or {}
        for _, r in ipairs(rows) do
            local okj, cc = pcall(json.decode, r.coords or "")
            if okj and type(cc) == "table" then
                local x, y = tonumber(cc.x), tonumber(cc.y)
                if x and y then
                    local charid = tonumber(r.charidentifier) or 0
                    local ownerName = ((tostring(r.firstname or "") .. " " .. tostring(r.lastname or "")):gsub("^%s+", ""))
                    local repoed = (tonumber(r.repo) or 0) == 1
                    shops[#shops + 1] = {
                        id = r.id,
                        name = (r.name ~= nil and r.name ~= "") and r.name or ("Shop #" .. tostring(r.id)),
                        x = math.floor(x + 0.5), y = math.floor(y + 0.5),
                        owned = (not repoed) and charid > 0,
                        repoed = repoed,
                        ledger = math.floor(tonumber(r.ledger) or 0),
                        ownerCharid = (not repoed and charid > 0) and charid or nil,
                        ownerName = (not repoed and charid > 0 and ownerName ~= "") and ownerName or nil,
                    }
                end
            end
        end
    end)

    -- SOCIETY SHOPS - owned by a JOB, not a character, so there is no owner profile to click through to
    local socshops = {}
    pcall(function()
        local rows = MySQL.query.await("SELECT id, name, coords, society, rank FROM society_shops") or {}
        for _, r in ipairs(rows) do
            local okj, cc = pcall(json.decode, r.coords or "")
            if okj and type(cc) == "table" then
                local x, y = tonumber(cc.x), tonumber(cc.y)
                if x and y then
                    socshops[#socshops + 1] = {
                        id = r.id,
                        name = (r.name ~= nil and r.name ~= "") and r.name or ("Shop #" .. tostring(r.id)),
                        x = math.floor(x + 0.5), y = math.floor(y + 0.5),
                        society = tostring(r.society or ""),
                        rank = tonumber(r.rank) or 0,
                    }
                end
            end
        end
    end)

    -- RANCHES. player_ranch keeps coords as a JSON blob like the rest
    local ranches = {}
    pcall(function()
        local rows = MySQL.query.await([[SELECT r.id, r.name, r.coords, r.owned, r.repoed,
                r.charidentifier, r.ledger, c.firstname, c.lastname
            FROM player_ranch r
            LEFT JOIN characters c ON c.charidentifier = r.charidentifier]]) or {}
        for _, r in ipairs(rows) do
            local okj, cc = pcall(json.decode, r.coords or "")
            local x, y
            if okj and type(cc) == "table" then
                x = tonumber(cc.x) or tonumber(cc[1])
                y = tonumber(cc.y) or tonumber(cc[2])
            end
            if x and y then
                local charid = tonumber(r.charidentifier) or 0
                local ownerName = ((tostring(r.firstname or "") .. " " .. tostring(r.lastname or "")):gsub("^%s+", ""))
                local owned = (tonumber(r.owned) or 0) == 1
                ranches[#ranches + 1] = {
                    id = r.id,
                    name = (r.name ~= nil and r.name ~= "") and r.name or ("Ranch #" .. tostring(r.id)),
                    x = math.floor(x + 0.5), y = math.floor(y + 0.5),
                    owned = owned,
                    repoed = (tonumber(r.repoed) or 0) == 1,
                    ledger = math.floor(tonumber(r.ledger) or 0),
                    ownerCharid = (owned and charid > 0) and charid or nil,
                    ownerName = (owned and charid > 0 and ownerName ~= "") and ownerName or nil,
                }
            end
        end
    end)

    cb({
        houses = houses, doors = doors, hideouts = hideouts, clans = clans,
        shops = shops, socshops = socshops, ranches = ranches, now = os.time(),
    })
end)

-- FULL CHARACTER PROFILE: everything hanging off one charidentifier
Core.Callback.Register("vorp_admin:Callback:panelPlayerDetail", function(source, cb, data)
    local _source = source
    if not Core.getUser(_source) then return cb(false) end
    if not AllowedToExecuteAction(_source, "open_menu") then return cb(false) end

    local charid = type(data) == "table" and tonumber(data.charid) or nil
    if not charid then return cb(false) end

    local okc, row = pcall(MySQL.single.await, "SELECT * FROM characters WHERE charidentifier = ?", { charid })
    if not okc or not row then return cb(false) end

    local missing = {}
    local function grab(label, fn)
        local ok, result = pcall(fn)
        if ok then return result end
        missing[#missing + 1] = label
        return nil
    end

    -- does a decoded json list contain this charid (numbers or strings)?
    local function listHasChar(jsonStr)
        if type(jsonStr) ~= "string" or jsonStr == "" or jsonStr == "[]" then return false end
        local ok, list = pcall(json.decode, jsonStr)
        if not ok or type(list) ~= "table" then return false end
        for _, v in pairs(list) do
            if tonumber(v) == charid then return true end
            if type(v) == "table" and (tonumber(v.charid) == charid or tonumber(v.charidentifier) == charid) then return true end
        end
        return false
    end

    ---------------------------------------------------------------- identity + core stats
    local char = {
        charid     = charid,
        identifier = row.identifier,
        steamname  = row.steamname,
        group      = row.group or "user",
        firstname  = row.firstname, lastname = row.lastname,
        gender     = row.gender, age = tonumber(row.age) or 0,
        job        = row.job, joblabel = row.joblabel, jobgrade = tonumber(row.jobgrade) or 0,
        money      = tonumber(row.money) or 0,
        gold       = tonumber(row.gold) or 0,
        rol        = tonumber(row.rol) or 0,
        xp         = tonumber(row.xp) or 0,
        hours      = tonumber(row.hours) or 0,
        gunsmith   = tonumber(row.gunsmith) or 0,
        discordid  = tostring(row.discordid or "0"),
        lastlogin  = panelDate(row.LastLogin, true),
        created    = panelDate(row.character_created, true),
        clanid     = tonumber(row.clan) or 0,
    }

    -- staticID + whitelist status: same source as the admin.lua menu (whitelist entry)
    do
        local okw, entry = pcall(function() return Core.Whitelist.getEntry(row.identifier) end)
        if okw and entry then
            char.staticid = tonumber(entry.id)
            char.wlstatus = tostring(entry.status)
        end
    end

    -- pup-crafting skill xp lives as JSON in characters.crafting; gunsmith (DOUBLE) is the pup-weaponsV2 weapon-crafting xp
    do
        local okj, craft = pcall(json.decode, row.crafting or "")
        if okj and type(craft) == "table" then char.crafting = craft end
    end

    -- height = the Scale key inside the skinPlayer JSON (0.95 short / 1.0 / 1.05 tall)
    do
        local okj, skin = pcall(json.decode, row.skinPlayer or "")
        if okj and type(skin) == "table" and tonumber(skin.Scale) then
            char.scale = tonumber(skin.Scale)
        end
    end

    -- mail PO Box. nil = never registered one. grab() so a stopped mail resource just omits it and lands in payload.missing
    char.mailbox = grab("mail", function()
        return exports['pup_postoffice']:AdminGetAddressByChar(charid)
    end)

    ---------------------------------------------------------------- bank accounts
    local bank = grab("bank", function()
        local b = MySQL.single.await("SELECT * FROM bank_users WHERE charidentifier = ?", { charid })
        if not b then return nil end
        local accounts = {}
        for col, v in pairs(b) do
            if col:find("_money", 1, true) and col ~= "total_money" and tonumber(v) and tonumber(v) ~= 0 then
                accounts[#accounts + 1] = { name = col:gsub("_money", ""), amount = tonumber(v) }
            end
        end
        return { total = tonumber(b.total_money) or 0, accounts = accounts }
    end)

    ---------------------------------------------------------------- houses (owner + keyholder)
    -- MOTEL ROOMS ARE NOT HOUSES.
    -- `motel` is NOT a flag - it is a longtext holding a TOWN NAME ('Valentine',
    -- 'sd', 'rhodes'), and '0' when it is a real house. A `motel = 0` filter
    -- makes MySQL cast 'Valentine' to 0 and match, letting every motel room in
    -- as a house. `type` is the real discriminator:
    -- 0 = house, 1 = motel room.
    local houses = grab("housing", function()
        local out = {}
        local owned = MySQL.query.await(
            "SELECT id, price, tax, ledger, taxledger, invspace, upgrade, repoed, keyholders FROM playerhousing WHERE buyercharidentifier = ? AND `type` = 0", { charid }) or {}
        for _, h in ipairs(owned) do
            local keys = 0
            local okk, kl = pcall(json.decode, h.keyholders or "[]")
            if okk and type(kl) == "table" then for _ in pairs(kl) do keys = keys + 1 end end
            out[#out + 1] = {
                id = tonumber(h.id), role = "owner",
                price = tonumber(h.price) or 0,
                ledger = tonumber(h.ledger) or 0,
                tax = tonumber(h.tax) or 0,
                taxowed = tonumber(h.taxledger) or 0,
                invspace = tonumber(h.invspace) or 0,
                upgrade = tonumber(h.upgrade) or 0,
                repoed = (tonumber(h.repoed) or 0) == 1,
                keys = keys,
            }
        end
        local keyed = MySQL.query.await(
            "SELECT id, keyholders FROM playerhousing WHERE `type` = 0 AND keyholders IS NOT NULL AND keyholders != '[]'") or {}
        for _, h in ipairs(keyed) do
            if listHasChar(h.keyholders) then
                out[#out + 1] = { id = tonumber(h.id), role = "keyholder" }
            end
        end
        return out
    end)

    ---------------------------------------------------------------- hideouts (owner + coowner)
    local hideouts = grab("hideouts", function()
        local out = {}
        local owned = MySQL.query.await("SELECT * FROM underground WHERE charidentifier = ?", { charid }) or {}
        for _, h in ipairs(owned) do
            out[#out + 1] = { id = h.id, level = tonumber(h.level or h.still or 0) or 0,
                ledger = tonumber(h.ledger) or 0, role = "owner" }
        end
        local co = MySQL.query.await("SELECT id, coowners FROM underground WHERE coowners IS NOT NULL AND coowners != ''") or {}
        for _, h in ipairs(co) do
            if listHasChar(h.coowners) then
                out[#out + 1] = { id = h.id, role = "co-owner" }
            end
        end
        return out
    end)

    ---------------------------------------------------------------- horses + wagons (pup-stable, legacy fallback)
    local horses = grab("horses", function()
        local ok1, rows1 = pcall(MySQL.query.await, "SELECT * FROM stable_horses WHERE charid = ?", { charid })
        if not ok1 or type(rows1) ~= "table" then rows1 = MySQL.query.await("SELECT * FROM horses WHERE charid = ?", { charid }) or {} end
        local out = {}
        for _, h in ipairs(rows1) do
            out[#out + 1] = { name = h.name or "horse", model = h.model or h.modelname or "?",
                out = tonumber(h.isOut or 0) == 1 }
        end
        return out
    end)

    local wagons = grab("wagons", function()
        local ok1, rows1 = pcall(MySQL.query.await, "SELECT * FROM stable_wagons WHERE charid = ?", { charid })
        if not ok1 or type(rows1) ~= "table" then rows1 = MySQL.query.await("SELECT * FROM wagons WHERE charid = ?", { charid }) or {} end
        local out = {}
        for _, w in ipairs(rows1) do
            out[#out + 1] = { name = w.name or "wagon", model = w.model or w.modelname or "?" }
        end
        return out
    end)

    -- clan membership truth is the members list inside clan.info (pup-clan updates characters.clan too, but it drifts
    -- for exactly that). Accept EITHER signal so the profile never misses it.
    local clan = grab("clan", function()
        local rows = MySQL.query.await("SELECT id, info, cash FROM clan") or {}
        for _, cRow in ipairs(rows) do
            local okj, info = pcall(json.decode, cRow.info or "")
            if okj and type(info) == "table" then
                local isMember = (tonumber(cRow.id) == char.clanid and char.clanid > 0)
                local role
                if type(info.members) == "table" then
                    for _, m in ipairs(info.members) do
                        if type(m) == "table" and tonumber(m.charid) == charid then
                            isMember = true
                            role = m.rank or m.role
                            break
                        end
                    end
                end
                if isMember then
                    return {
                        id      = cRow.id,
                        name    = tostring(info.name or ("Clan #" .. cRow.id)),
                        members = type(info.members) == "table" and #info.members or 0,
                        cash    = tonumber(cRow.cash) or 0,
                        role    = role and tostring(role) or nil,
                    }
                end
            end
        end
        return nil
    end)

    ---------------------------------------------------------------- business (society)
    -- their job IS the business; boss is grade >= the business's bossrank
    local business = grab("society", function()
        local j = tostring(row.job or "")
        if j == "" or j == "unemployed" then return nil end
        local b = MySQL.single.await(
            "SELECT job, name, bossrank, containername, billing, salary, tax FROM society_business WHERE job = ?", { j })
        if not b then return nil end
        local led = MySQL.single.await(
            "SELECT ledger FROM society_ledger WHERE job = ?", { j })
        local grade = tonumber(row.jobgrade) or 0
        local bossrank = tonumber(b.bossrank) or 999

        -- their own rank's pay, not the whole wage table
        local rank = MySQL.single.await(
            "SELECT salary, tax, taxperiod FROM society_ranks WHERE job = ? AND grade = ?", { j, grade })

        -- who else works there, and who actually owns it
        local staff = MySQL.scalar.await(
            "SELECT COUNT(*) FROM characters WHERE job = ?", { j })
        local owner = MySQL.single.await(
            "SELECT firstname, lastname, charidentifier FROM characters WHERE job = ? AND jobgrade >= ? ORDER BY jobgrade DESC LIMIT 1",
            { j, bossrank })

        return {
            job       = b.job,
            name      = (b.name ~= nil and tostring(b.name) ~= "") and b.name or b.job,
            grade     = grade,
            bossrank  = bossrank,
            isBoss    = grade >= bossrank,
            ledger    = led and tonumber(led.ledger) or 0,
            staff     = tonumber(staff) or 0,
            salary    = rank and tonumber(rank.salary) or 0,
            taxperiod = rank and tostring(rank.taxperiod or "") or "",
            billing   = (tonumber(b.billing) or 0) == 1,
            taxed     = (tonumber(b.tax) or 0) == 1,
            stash     = (b.containername ~= nil and tostring(b.containername) ~= "") and tostring(b.containername) or nil,
            owner     = owner and (((owner.firstname or "") .. " " .. (owner.lastname or "")):gsub("^%s+", "")) or nil,
            ownerid   = owner and tonumber(owner.charidentifier) or nil,
        }
    end)

    ---------------------------------------------------------------- ranches (owned + hired on)
    local ranches = grab("ranch", function()
        local out = {}
        for _, r in ipairs(MySQL.query.await(
            "SELECT id, name, charidentifier, ledger, tax, repoed, milk, eggs, cows, chickens, cattle, hired FROM player_ranch WHERE owned = 1") or {}) do
            local mine = tonumber(r.charidentifier) == charid
            local hiredOn = (not mine) and listHasChar(r.hired) or false
            if mine or hiredOn then
                -- `cattle` is a MAP of type -> head ({"Ram":5,"cow":5}), not a list,
                -- so # on it is always 0. Sum the values and keep the breakdown.
                local head, kinds = 0, {}
                local okd, cat = pcall(json.decode, r.cattle or "{}")
                if okd and type(cat) == "table" then
                    local names = {}
                    for k in pairs(cat) do names[#names + 1] = tostring(k) end
                    table.sort(names)
                    for _, k in ipairs(names) do
                        local n = tonumber(cat[k]) or 0
                        head = head + n
                        kinds[#kinds + 1] = ("%s %d"):format(k, n)
                    end
                end

                -- hired is a list of {charidentifier, name, manager}
                local staffN, isMgr, mgrs, hands = 0, false, {}, {}
                local okh, hl = pcall(json.decode, r.hired or "[]")
                if okh and type(hl) == "table" then
                    for _, m in pairs(hl) do
                        if type(m) == "table" then
                            staffN = staffN + 1
                            local nm = tostring(m.name or "?")
                            if m.manager == true then
                                mgrs[#mgrs + 1] = nm
                                if tonumber(m.charidentifier) == charid then isMgr = true end
                            else
                                hands[#hands + 1] = nm
                            end
                        end
                    end
                end
                table.sort(mgrs); table.sort(hands)

                out[#out + 1] = {
                    id        = tonumber(r.id),
                    name      = (r.name ~= nil and tostring(r.name) ~= "") and tostring(r.name) or ("Ranch #" .. tostring(r.id)),
                    role      = mine and "owner" or (isMgr and "manager" or "hired"),
                    ledger    = tonumber(r.ledger) or 0,
                    tax       = tonumber(r.tax) or 0,
                    repoed    = (tonumber(r.repoed) or 0) == 1,
                    milk      = tonumber(r.milk) or 0,
                    eggs      = tonumber(r.eggs) or 0,
                    livestock = head,
                    breakdown = table.concat(kinds, ", "),
                    staff     = staffN,
                    managers  = table.concat(mgrs, ", "),
                    hands     = table.concat(hands, ", "),
                }
            end
        end
        return out
    end)

    ---------------------------------------------------------------- player-owned shops
    local shops = grab("stores", function()
        local out = {}
        for _, s in ipairs(MySQL.query.await(
            "SELECT id, name, charidentifier, manager, ledger, taxledger, level, repo FROM playershops WHERE owned = 1") or {}) do
            local mine = tonumber(s.charidentifier) == charid
            local mgr = tonumber(s.manager) == charid
            if mine or mgr then
                out[#out + 1] = {
                    id     = tonumber(s.id),
                    name   = (s.name ~= nil and tostring(s.name) ~= "") and tostring(s.name) or ("Shop #" .. tostring(s.id)),
                    role   = mine and "owner" or "manager",
                    ledger = tonumber(s.ledger) or 0,
                    tax    = tonumber(s.taxledger) or 0,
                    level  = tonumber(s.level) or 0,
                    repo   = (tonumber(s.repo) or 0) == 1,
                }
            end
        end
        return out
    end)

    ---------------------------------------------------------------- online state (for the actions bar)
    local sid = panelOnlineCharacters()[charid]

    cb({
        char     = char,
        bank     = bank,
        houses   = houses or {},
        hideouts = hideouts or {},
        horses   = horses or {},
        wagons   = wagons or {},
        business = business,
        ranches  = ranches or {},
        shops    = shops or {},
        clan     = clan,
        online   = sid or false,
        staff    = panelIsStaff(sid, row.group), -- pup: Discord perms, see panelIsStaff
        missing  = missing,
    })
end)

-- mail PO Box administration (dashboard -> player row -> PO BOX) The number is the PRIMARY KEY of the `mail` table
Core.Callback.Register("vorp_admin:Callback:getPoBox", function(source, cb, target)
    if not AllowedToExecuteAction(source, "admin_actions_menu") then return cb(nil) end
    local ok, address = pcall(function()
        return exports['pup_postoffice']:AdminGetAddress(tonumber(target))
    end)
    return cb(ok and address or nil)
end)

RegisterServerEvent("vorp_admin:setPoBox")
AddEventHandler("vorp_admin:setPoBox", function(target, newAddress, targetName)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then return end

    target = tonumber(target)
    newAddress = tonumber(newAddress)
    if not target or not newAddress then return end

    -- mail may be stopped; a missing export must not take the panel down
    local called, ok, err = pcall(function()
        return exports['pup_postoffice']:AdminSetAddress(target, newAddress)
    end)
    if not called then
        return TriggerClientEvent("vorp:TipRight", _source, "mail resource is not running", 4000)
    end
    if not ok then
        return TriggerClientEvent("vorp:TipRight", _source, tostring(err or "could not change PO Box"), 5000)
    end

    TriggerClientEvent("vorp:TipRight", _source,
        ("PO Box for %s is now %d"):format(tostring(targetName or target), newAddress), 4000)
    print(("^3[vorp_admin]^7 %s set PO Box of %s to %d"):format(
        GetPlayerName(_source) or "?", tostring(targetName or target), newAddress))
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Mail",
        ("Set PO Box of %s to %d"):format(tostring(targetName or target), newAddress))
end)

-- register a box for someone who has none
RegisterServerEvent("vorp_admin:createPoBox")
AddEventHandler("vorp_admin:createPoBox", function(target, wantedAddress, targetName)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then return end

    target = tonumber(target)
    if not target then return end
    wantedAddress = tonumber(wantedAddress) -- nil = next free number

    local called, ok, err = pcall(function()
        return exports['pup_postoffice']:AdminCreateAddress(target, wantedAddress)
    end)
    if not called then
        return TriggerClientEvent("vorp:TipRight", _source, "mail resource is not running", 4000)
    end
    if not ok then
        return TriggerClientEvent("vorp:TipRight", _source, tostring(err or "could not register a PO Box"), 5000)
    end

    TriggerClientEvent("vorp:TipRight", _source,
        ("Registered a PO Box for %s"):format(tostring(targetName or target)), 4000)
    print(("^3[vorp_admin]^7 %s registered a PO Box for %s"):format(
        GetPlayerName(_source) or "?", tostring(targetName or target)))
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Mail",
        ("Registered a PO Box for %s"):format(tostring(targetName or target)))
end)

-- DELETE A CHARACTER from the database (admin panel -> character detail). Mirrors vorp_core's own character delete.
RegisterNetEvent("vorp_admin:panelDeleteCharacter", function(charid)
    local _source = source
    -- wiping someone's character is not an "admin action", it is its own key
    if not AllowedToExecuteAction(_source, "delete_character") then
        print(('^1[vorp_admin]^7 %s tried to DELETE character %s without delete_character')
            :format(GetPlayerName(_source) or _source, tostring(charid)))
        return Core.NotifyRightTip(_source, "That is Management only.", 5000)
    end

    charid = tonumber(charid)
    if not charid then return end

    -- online? refuse: the loaded character object would outlive its row
    for _, sid in ipairs(GetPlayers()) do
        local u = Core.getUser(tonumber(sid))
        local ch = u and u.getUsedCharacter
        if ch and tonumber(ch.charIdentifier) == charid then
            return Core.NotifyRightTip(_source,
                "That character is online - kick them first, then delete.", 6000)
        end
    end

    local ok, row = pcall(MySQL.query.await,
        "SELECT `identifier`, `firstname`, `lastname` FROM characters WHERE `charidentifier` = ?", { charid })
    if not ok or type(row) ~= "table" or not row[1] then
        return Core.NotifyRightTip(_source, "No character " .. charid .. " in the database.", 5000)
    end

    local who = ((row[1].firstname or "") .. " " .. (row[1].lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")

    local okd = pcall(MySQL.query.await,
        "DELETE FROM characters WHERE `identifier` = ? AND `charidentifier` = ?",
        { row[1].identifier, charid })
    if not okd then
        return Core.NotifyRightTip(_source, "Delete failed - see the server console.", 5000)
    end

    Core.NotifyRightTip(_source, ("Deleted character %d (%s)"):format(charid, who), 5000)
    print(("^1[vorp_admin]^7 %s DELETED character %d (%s) identifier %s"):format(
        GetPlayerName(_source) or "?", charid, who, tostring(row[1].identifier)))
    -- logged only after the delete has gone through
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Character",
        ("DELETED character %d (%s) identifier %s"):format(charid, who, tostring(row[1].identifier)))
end)

-- mail PO Box from the WEB PANEL (character detail -> Mail card) Keyed by CHARID, not a server id
local function panelMailReply(src, called, ok, err, goodMsg)
    if not called then
        return Core.NotifyRightTip(src, "mail resource is not running", 4000)
    end
    if not ok then
        return Core.NotifyRightTip(src, tostring(err or "could not change the PO Box"), 5000)
    end
    Core.NotifyRightTip(src, goodMsg, 4000)
end

RegisterNetEvent("vorp_admin:panelSetPoBox", function(charid, newAddress)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    charid, newAddress = tonumber(charid), tonumber(newAddress)
    if not charid or not newAddress then return end

    local called, ok, err = pcall(function()
        return exports['pup_postoffice']:AdminSetAddressByChar(charid, newAddress)
    end)
    panelMailReply(_source, called, ok, err, ("PO Box for char %d is now %d"):format(charid, newAddress))
    if called and ok then
        print(("^3[vorp_admin]^7 %s set PO Box of char %d to %d"):format(
            GetPlayerName(_source) or "?", charid, newAddress))
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Mail",
            ("Set PO Box of charid %d to %d"):format(charid, newAddress))
    end
end)

-- society STASH SLOTS from the WEB PANEL. The in-game upgrade buys slots off the
-- society ledger; this sets the figure and charges nothing, because it is staff
-- correcting a number rather than a business spending its money.
RegisterNetEvent("vorp_admin:society:setSlots", function(job, slots)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_society") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    job, slots = tostring(job or ''), tonumber(slots)
    if job == '' or not slots then return end

    local called, res = pcall(function()
        return exports['pup_business']:adminSetSocietySlots(job, slots)
    end)
    if not called or type(res) ~= 'table' or not res.ok then
        return Core.NotifyRightTip(_source,
            "Storage slots failed: " .. tostring(type(res) == 'table' and res.err or "error"), 6000)
    end

    Core.NotifyRightTip(_source,
        ("%s storage: %d bought, %d total"):format(job, res.slots or 0, res.total or 0), 5000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("Set purchased storage slots on %s to %d (total %d)")
            :format(job, res.slots or 0, res.total or 0))
end)

-- business PO address from the WEB PANEL (society detail -> Settings). Keyed by
-- JOB, so it survives the boss changing, and it bypasses the in-game ledger fee.
RegisterNetEvent("vorp_admin:society:setMailHandle", function(job, handle)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_society") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    job, handle = tostring(job or ''), tostring(handle or '')
    if job == '' or handle == '' then return end

    -- read the old address FIRST, so the log can say what it changed FROM
    local _, prev = pcall(function() return exports['pup_postoffice']:AdminGetBusinessHandle(job) end)
    local before = (type(prev) == 'string' and prev ~= '') and prev or 'none'

    -- second return is the reason on failure, the normalised handle on success
    local called, ok, res = pcall(function()
        return exports['pup_postoffice']:AdminSetBusinessHandle(job, handle)
    end)
    local shown = (ok and res) and tostring(res) or handle
    panelMailReply(_source, called, ok, res, ("PO address for %s is now %s"):format(job, shown))
    if called and ok then
        print(("^3[vorp_admin]^7 %s set PO address of %s: %s -> %s"):format(
            GetPlayerName(_source) or "?", job, before, shown))
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
            ("%s the business PO address of %s\nFrom: %s\nTo: %s"):format(
                before == 'none' and 'REGISTERED' or 'Changed', job, before, shown))
    end
end)

-- open the business stash for this admin (boss controls, from anywhere, no job change).
-- pup_business checks manage_society again through allowedToExecuteAction.
RegisterNetEvent("vorp_admin:society:openStash", function(job)
    local _source = source
    if not AllowedToExecuteAction(_source, "manage_society") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    if GetResourceState('pup_business') ~= 'started' then
        return Core.NotifyRightTip(_source, "pup_business is not running", 5000)
    end
    job = tostring(job or '')
    if job == '' or #job > 50 then return end

    local ok, done, why = pcall(function()
        return exports['pup_business']:adminOpenStash(_source, job)
    end)
    if not ok or done ~= true then
        return Core.NotifyRightTip(_source,
            "Could not open the business storage: " .. tostring(why or "error"), 6000)
    end

    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelSociety, "Admin Panel - Business",
        ("Opened the storage of %s"):format(job))
end)

-- Make a player reload their own character (vorp_character's /rc). Fixes a ped
-- that came back wrong - missing clothes, lost tints, an outfit that did not
-- apply - without them having to know the command exists.
RegisterNetEvent("vorp_admin:forceReload", function(target)
    local _source = source
    if not AllowedToExecuteAction(_source, "heal_player") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    target = tonumber(target)
    if not target or not GetPlayerName(target) then
        return Core.NotifyRightTip(_source, "that player is not online", 4000)
    end

    TriggerClientEvent("vorp_admin:forceReloadChar", target)
    Core.NotifyRightTip(_source, ("Told %s to reload their character."):format(GetPlayerName(target)), 4000)
    TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Player",
        ("Forced a character reload (/rc) on %s [%d]"):format(GetPlayerName(target) or "?", target))
end)

RegisterNetEvent("vorp_admin:panelCreatePoBox", function(charid, wantedAddress)
    local _source = source
    if not AllowedToExecuteAction(_source, "admin_actions_menu") then
        return Core.NotifyRightTip(_source, "you are not allowed to use this command", 5000)
    end
    charid = tonumber(charid)
    if not charid then return end
    wantedAddress = tonumber(wantedAddress) -- nil = next free number

    local called, ok, err = pcall(function()
        return exports['pup_postoffice']:AdminCreateAddressByChar(charid, wantedAddress)
    end)
    panelMailReply(_source, called, ok, err, ("Registered a PO Box for char %d"):format(charid))
    if called and ok then
        print(("^3[vorp_admin]^7 %s registered a PO Box for char %d"):format(
            GetPlayerName(_source) or "?", charid))
        TriggerEvent("vorp_admin:logs", _source, Secrets.Webhooks.panelCharacter, "Admin Panel - Mail",
            ("Registered a PO Box for charid %d"):format(charid))
    end
end)
