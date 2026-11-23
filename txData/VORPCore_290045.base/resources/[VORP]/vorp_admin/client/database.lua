-- Modified by Puppet (Dusk Till Dawn), 2026
local T = Translation.Langs[Config.General.language]

-- Plain-text player detail block (mirrors the admin.lua builder; <br>/<span> -> "\n").
local function dbPlayerDesc(playersInfo)
    return T.Menus.MainPlayerStatus.playerSteamName .. " " .. (playersInfo.name or "") ..
        "\n" .. T.Menus.MainPlayerStatus.playerServerID .. " " .. (playersInfo.serverId or 0) ..
        "\n" .. T.Menus.MainPlayerStatus.playerGroup .. " " .. (playersInfo.Group or 0) ..
        "\n" .. T.Menus.MainPlayerStatus.playerJob .. " " .. (playersInfo.Job or "") ..
        " " .. T.Menus.MainPlayerStatus.playerGrade .. " " .. (playersInfo.Grade or 0) ..
        "\n" .. T.Menus.MainPlayerStatus.playerIdentifier .. " " .. (playersInfo.SteamId or "") ..
        "\n" .. T.Menus.MainPlayerStatus.playerMoney .. " " .. (playersInfo.Money or 0) ..
        "\n" .. T.Menus.MainPlayerStatus.playerGold .. " " .. (playersInfo.Gold or 0) ..
        "\n" .. T.Menus.MainPlayerStatus.playerWhitelist .. " " .. (playersInfo.WLstatus or "")
end

-- DATABASE ----------------------------------------------------------------
function BuildDataBase()
    local result = VORP.Callback.TriggerAwait("vorp_admin:Callback:getplayersinfo", { search = "all" })
    if not result then
        return
    end

    local options = {}
    for _, playersInfo in pairs(result) do
        options[#options + 1] = {
            label = playersInfo.PlayerName,
            desc = dbPlayerDesc(playersInfo),
            submenu = function()
                if IsAdminAllowed("open_database_menu") then
                    return BuildDatabasePlayers(playersInfo)
                end
            end
        }
    end

    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleDatabase,
        options = options
    }
end

function BuildDatabasePlayers(PlayerData)
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleDatabase,
        options = {
            {
                label = T.Menus.MainDatabaseOptions.give,
                desc = T.Menus.MainDatabaseOptions.give_desc,
                submenu = function() if IsAdminAllowed("give_items_menu") then return BuildGivePlayers(PlayerData) end end
            },
            {
                label = T.Menus.MainDatabaseOptions.remove,
                desc = T.Menus.MainDatabaseOptions.remove_desc,
                submenu = function() if IsAdminAllowed("remove_items_menu") then return BuildRemovePlayers(PlayerData) end end
            },
        }
    }
end

function BuildGivePlayers(PlayerData)
    local targetID = PlayerData.serverId
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = PlayerData.PlayerName,
        options = {
            {
                label = T.Menus.SubDatabaseGiveOptions.showInventory,
                desc = PlainDesc(T.Menus.SubDatabaseGiveOptions.showInventory_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:checkInventory", targetID, "vorp.staff.ShowInvGive")
                end
            },
            {
                label = T.Menus.SubDatabaseGiveOptions.giveItem,
                desc = PlainDesc(T.Menus.SubDatabaseGiveOptions.giveItem_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubDatabaseGiveOptions.GiveItemInput.title, {
                        { label = 'Item', type = 'text', placeholder = 'itemname', required = true },
                        { label = 'Quantity', type = 'number', placeholder = '1', default = 1 },
                    }, T.Menus.SubDatabaseGiveOptions.GiveItemInput.errorMsg)
                    if not vals then return end
                    local itemName = tostring(vals[1])
                    local itemQuantity = tonumber(vals[2]) or 1
                    if itemName and itemName ~= "" then
                        TriggerServerEvent("vorp_admin:givePlayer", targetID, "item", itemName, itemQuantity, nil, "vorp.staff.Giveitems", PlayerData.PlayerName)
                    else
                        VORP.NotifyObjective(T.Notify.missingArgument, 4000)
                    end
                end
            },
            {
                label = T.Menus.SubDatabaseGiveOptions.giveWeapon,
                desc = PlainDesc(T.Menus.SubDatabaseGiveOptions.giveWeapon_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubDatabaseGiveOptions.GiveWeaponInput.title, {
                        { label = T.Menus.SubDatabaseGiveOptions.GiveWeaponInput.placeholder, type = 'text', placeholder = T.Menus.SubDatabaseGiveOptions.GiveWeaponInput.placeholder, required = true }
                    }, T.Menus.SubDatabaseGiveOptions.GiveWeaponInput.errorMsg)
                    if not vals then return end
                    local weaponName = tostring(vals[1])
                    if weaponName ~= "" then
                        TriggerServerEvent("vorp_admin:givePlayer", targetID, "weapon", weaponName, nil, nil, "vorp.staff.GiveWeapons", PlayerData.PlayerName)
                    else
                        VORP.NotifyObjective(T.Notify.empty, 4000)
                    end
                end
            },
            {
                label = T.Menus.SubDatabaseGiveOptions.giveMoneyOrGold,
                desc = PlainDesc(T.Menus.SubDatabaseGiveOptions.giveMoneyOrGold_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubDatabaseGiveOptions.GiveCurrencyInput.title, {
                        { label = 'Currency (0 = Cash, 1 = Gold)', type = 'number', placeholder = '0', required = true },
                        { label = 'Quantity', type = 'number', placeholder = '100', required = true },
                    }, T.Menus.SubDatabaseGiveOptions.GiveCurrencyInput.errorMsg)
                    if not vals then return end
                    local moneyType = tonumber(vals[1])
                    local Quantity = tonumber(vals[2])
                    if moneyType and Quantity then
                        TriggerServerEvent("vorp_admin:givePlayer", targetID, "moneygold", moneyType, Quantity, nil, "vorp.staff.GiveCurrency", PlayerData.PlayerName)
                    else
                        TriggerEvent("vorp:TipRight", T.Notify.missingArgument, 4000)
                    end
                end
            },
            {
                label = T.Menus.SubDatabaseGiveOptions.giveHorse,
                desc = PlainDesc(T.Menus.SubDatabaseGiveOptions.giveHorse_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubDatabaseGiveOptions.GiveHorseInput.title, {
                        { label = 'Hash', type = 'text', placeholder = 'model hash', required = true },
                        { label = 'Name', type = 'text', placeholder = 'horse name', required = true },
                        { label = 'Sex', type = 'number', placeholder = '0/1', required = true },
                    }, T.Menus.SubDatabaseGiveOptions.GiveHorseInput.errorMsg)
                    if not vals then return end
                    local Hashname = tostring(vals[1])
                    local Horsename = tostring(vals[2])
                    local Horsesex = tonumber(vals[3])
                    if Hashname and Horsename and Horsesex then
                        TriggerServerEvent("vorp_admin:givePlayer", targetID, "horse", Hashname, Horsename, Horsesex, "vorp.staff.GiveHorse", PlayerData.PlayerName)
                    else
                        TriggerEvent("vorp:TipRight", T.Notify.missingArgument, 4000)
                    end
                end
            },
            {
                label = T.Menus.SubDatabaseGiveOptions.giveWagon,
                desc = PlainDesc(T.Menus.SubDatabaseGiveOptions.giveWagon_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubDatabaseGiveOptions.GiveWagonInput.title, {
                        { label = 'Hash', type = 'text', placeholder = 'model hash', required = true },
                        { label = 'Name', type = 'text', placeholder = 'wagon name', required = true },
                    }, T.Menus.SubDatabaseGiveOptions.GiveWagonInput.errorMsg)
                    if not vals then return end
                    local Modelname = tostring(vals[1])
                    local Wagonname = tostring(vals[2])
                    if Modelname and Wagonname then
                        TriggerServerEvent("vorp_admin:givePlayer", targetID, "wagon", Modelname, Wagonname, nil, "vorp.staff.GiveWagons", PlayerData.PlayerName)
                    else
                        TriggerEvent("vorp:TipRight", T.Notify.missingArgument, 4000)
                    end
                end
            },
        }
    }
end

function BuildRemovePlayers(PlayerData)
    local targetID = PlayerData.serverId
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleDatabase,
        options = {
            {
                label = T.Menus.SubDatabaseRemoveOptions.showInventory,
                desc = PlainDesc(T.Menus.SubDatabaseRemoveOptions.showInventory_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:checkInventory", targetID, "vorp.staff.ShowInvRemove")
                end
            },
            {
                label = T.Menus.SubDatabaseRemoveOptions.removeMoney,
                desc = PlainDesc(T.Menus.SubDatabaseRemoveOptions.removeMoney_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:ClearCurrency", targetID, "money", "vorp.staff.RemoveAllMoney", PlayerData.PlayerName)
                end
            },
            {
                label = T.Menus.SubDatabaseRemoveOptions.removeGold,
                desc = PlainDesc(T.Menus.SubDatabaseRemoveOptions.removeGold_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:ClearCurrency", targetID, "gold", "vorp.staff.RemoveAllGold", PlayerData.PlayerName)
                end
            },
            {
                label = T.Menus.SubDatabaseRemoveOptions.clearAllItems,
                desc = PlainDesc(T.Menus.SubDatabaseRemoveOptions.clearAllItems_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubDatabaseRemoveOptions.RemoveAllItemInput.title, {
                        { label = T.Menus.SubDatabaseRemoveOptions.RemoveAllItemInput.placeholder, type = 'text', placeholder = T.Menus.SubDatabaseRemoveOptions.RemoveAllItemInput.placeholder, required = true }
                    }, T.Menus.SubDatabaseRemoveOptions.RemoveAllItemInput.errorMsg)
                    if not vals then return end
                    local result = tostring(vals[1])
                    if result ~= "" then
                        if result == "yes" then
                            TriggerServerEvent("vorp_admin:ClearAllItems", "items", targetID, "vorp.staff.RemoveAllItems", PlayerData.PlayerName)
                        else
                            TriggerEvent("vorp:TipRight", T.Notify.actionCancell, 4000)
                        end
                    else
                        VORP.NotifyObjective(T.Notify.empty, 4000)
                    end
                end
            },
            {
                label = T.Menus.SubDatabaseRemoveOptions.clearAllWeapons,
                desc = PlainDesc(T.Menus.SubDatabaseRemoveOptions.clearAllWeapons_desc) .. " " .. PlayerData.PlayerName,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubDatabaseRemoveOptions.RemoveAllWeaponInput.title, {
                        { label = T.Menus.SubDatabaseRemoveOptions.RemoveAllWeaponInput.placeholder, type = 'text', placeholder = T.Menus.SubDatabaseRemoveOptions.RemoveAllWeaponInput.placeholder, required = true }
                    }, T.Menus.SubDatabaseRemoveOptions.RemoveAllWeaponInput.errorMsg)
                    if not vals then return end
                    local result = tostring(vals[1])
                    if result ~= "" then
                        if result == "yes" then
                            TriggerServerEvent("vorp_admin:ClearAllItems", "weapons", targetID, "vorp.staff.RemoveAllWeapons", PlayerData.PlayerName)
                        else
                            TriggerEvent("vorp:TipRight", T.Notify.actionCancell, 4000)
                        end
                    else
                        VORP.NotifyObjective(T.Notify.empty, 4000)
                    end
                end
            },
        }
    }
end

function OpenInventory(inventorydata)
    local options = {}
    for _, dataItems in pairs(inventorydata) do -- to prevent menu from opening empty and give errors
        options[#options + 1] = {
            label = dataItems.label .. "  x" .. dataItems.count,
            desc = dataItems.label
        }
    end
    PupMenu.Open({
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleDatabase,
        options = options
    })
end
