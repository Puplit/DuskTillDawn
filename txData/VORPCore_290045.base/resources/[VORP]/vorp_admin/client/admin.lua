-- Modified by Puppet (Dusk Till Dawn), 2026
-- ADMIN ACTIONS -------------------------------------------------
local freeze = false
local lastLocation = {}
local T = Translation.Langs[Config.General.language]

-- same server check, no "you don't have permission" popup. For the key and the
-- command, where a non-staff player should not learn the menu exists.
function IsAdminAllowedQuiet(param)
    return VORP.Callback.TriggerAwait("vorp_admin:CanOpenStaffMenu", param) == true
end

function IsAdminAllowed(param)
    local isAllowed = VORP.Callback.TriggerAwait("vorp_admin:CanOpenStaffMenu", param)
    if not isAllowed then
        VORP.NotifyObjective(T.Notify.noperms, 5000)
    end
    return isAllowed
end

-- Plain-text (pup-ui) player detail block; <br>/<span> from the localized desc become "\n".
local function playerDesc(playersInfo)
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

local function playerLabel(playersInfo)
    return playersInfo.PlayerName .. " - " .. T.Menus.MainPlayerStatus.playerServerID .. " " .. playersInfo.serverId
end

function BuildAdmin()
    local num = 0
    if GlobalState.PlayersInSession then
        num = GlobalState.PlayersInSession
    end
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleAdmin,
        options = {
            {
                label = T.Menus.MainAdminOptions.playersList,
                desc = PlainDesc(T.Menus.MainAdminOptions.playersList_desc) .. "\n\n" .. (num > 0 and num or ""),
                submenu = function() if IsAdminAllowed('players_list_menu') then return BuildPlayerList() end end
            },
            {
                label = T.Menus.MainAdminOptions.adminActions,
                desc = T.Menus.MainAdminOptions.adminActions_desc,
                submenu = function() if IsAdminAllowed('admin_actions_menu') then return BuildActions() end end
            },
            {
                label = T.Menus.MainAdminOptions.offLineActions,
                desc = T.Menus.MainAdminOptions.offLineActions_desc,
                submenu = function() if IsAdminAllowed('offline_actions_menu') then return BuildOffLine() end end
            },
            {
                label = T.Menus.MainAdminOptions.viewReports,
                desc = T.Menus.MainAdminOptions.viewReports_desc,
                action = function()
                    if not IsAdminAllowed('view_reports_menu') then return end
                    PupMenu.Close()
                    TriggerEvent("vorp_admin:viewreports")
                end
            },
            {
                label = T.Menus.MainAdminOptions.searchPlayer,
                desc = T.Menus.MainAdminOptions.searchPlayer_desc,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.MainAdminOptions.MenuAdminInput.title, {
                        { label = T.Menus.MainAdminOptions.MenuAdminInput.placeholder, type = 'number', placeholder = T.Menus.MainAdminOptions.MenuAdminInput.placeholder, required = true }
                    }, T.Menus.MainAdminOptions.MenuAdminInput.errorMsg)
                    if not vals then return end
                    local id = tonumber(vals[1])
                    if id and id > 0 then
                        VORP.Callback.TriggerAsync("vorp_admin:Callback:getplayersinfo", function(cb)
                            if cb then
                                OpenOnePlayerMenu(cb)
                            else
                                VORP.NotifyObjective(T.Notify.userNotExist, 5000)
                            end
                        end, { search = "search", id = id })
                    end
                end
            },
        }
    }
end

function OpenOnePlayerMenu(playersInfo)
    PupMenu.Open({
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleAdmin,
        options = {
            {
                label = playerLabel(playersInfo),
                desc = playerDesc(playersInfo),
                submenu = function() return BuildSubAdminMenu(playersInfo) end
            }
        }
    })
end

function BuildPlayerList()
    local result = VORP.Callback.TriggerAwait("vorp_admin:Callback:getplayersinfo", { search = "all" })
    if not result then
        return
    end

    local sortedPlayers = {} -- Create a new table to store the sorted player list
    for _, playersInfo in pairs(result) do
        sortedPlayers[#sortedPlayers + 1] = playersInfo
    end

    -- Sort players by serverId in ascending order
    table.sort(sortedPlayers, function(a, b)
        return a.serverId < b.serverId
    end)

    local options = {}
    for _, playersInfo in ipairs(sortedPlayers) do
        options[#options + 1] = {
            label = playerLabel(playersInfo),
            desc = playerDesc(playersInfo),
            submenu = function()
                if IsAdminAllowed('players_list_submenu') then
                    return BuildSubAdminMenu(playersInfo)
                end
            end
        }
    end

    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleAdmin,
        options = options
    }
end

function BuildSubAdminMenu(Player)
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleAdmin,
        options = {
            {
                label = T.Menus.SubAdminOptions.simpleActions,
                desc = T.Menus.SubAdminOptions.simpleActions_desc,
                submenu = function() if IsAdminAllowed('simple_actions_menu') then return BuildSimpleActionMenu(Player) end end
            },
            {
                label = T.Menus.SubAdminOptions.advancedActions,
                desc = T.Menus.SubAdminOptions.advancedActions_desc,
                submenu = function() if IsAdminAllowed('advanced_actions_menu') then return BuildAdvancedActions(Player) end end
            },
            {
                label = T.Menus.SubAdminOptions.trollActions,
                desc = T.Menus.SubAdminOptions.trollActions_desc,
                submenu = function() if IsAdminAllowed('troll_actions_menu') then return BuildTrollActions(Player) end end
            },
        }
    }
end

function BuildTrollActions(PlayerInfo)
    local function trollOpt(label, desc, event, ace)
        return {
            label = label,
            desc = desc .. " " .. PlayerInfo.PlayerName,
            action = function()
                TriggerServerEvent(event, PlayerInfo.serverId, ace)
            end
        }
    end
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleAdmin,
        options = {
            trollOpt(T.Menus.SubTrollOptions.killPlayer, T.Menus.SubTrollOptions.killPlayer_desc, 'vorp_admin:ServerTrollKillPlayerHandler', 'vorp.staff.KillPlayer'),
            trollOpt(T.Menus.SubTrollOptions.invisPlayer, T.Menus.SubTrollOptions.invisPlayer_desc, 'vorp_admin:ServerTrollInvisibleHandler', 'vorp.staff.InvisPlayer'),
            trollOpt(T.Menus.SubTrollOptions.lightningStrikePlayer, T.Menus.SubTrollOptions.lightningStrikePlayer_desc, 'vorp_admin:ServerTrollLightningStrikePlayerHandler', 'vorp.staff.LightningStrikePlayer'),
            trollOpt(T.Menus.SubTrollOptions.setPlayerOnFire, T.Menus.SubTrollOptions.setPlayerOnFire_desc, 'vorp_admin:ServerTrollSetPlayerOnFireHandler', 'vorp.staff.SetPlayerOnFire'),
            trollOpt(T.Menus.SubTrollOptions.teleportToHeaven, T.Menus.SubTrollOptions.teleportToHeaven_desc, 'vorp_admin:ServerTrollTPToHeavenHandler', 'vorp.staff.TPToHeaven'),
            trollOpt(T.Menus.SubTrollOptions.ragdollPlayer, T.Menus.SubTrollOptions.ragdollPlayer_desc, 'vorp_admin:ServerTrollRagdollPlayerHandler', 'vorp.staff.RagdollPlayer'),
            trollOpt(T.Menus.SubTrollOptions.drainPlayerStam, T.Menus.SubTrollOptions.drainPlayerStam_desc, 'vorp_admin:ServerDrainPlayerStamHandler', 'vorp.staff.DrainPlayerStam'),
            trollOpt(T.Menus.SubTrollOptions.cuffPlayer, T.Menus.SubTrollOptions.cuffPlayer_desc, 'vorp_admin:ServerHandcuffPlayerHandler', 'vorp.staff.CuffPlayer'),
            trollOpt(T.Menus.SubTrollOptions.tempHighPlayer, T.Menus.SubTrollOptions.tempHighPlayer_desc, 'vorp_admin:ServerTempHighPlayerHandler', 'vorp.staff.PlayerTempHigh'),
        }
    }
end

function BuildSimpleActionMenu(PlayerInfo)
    local target = PlayerInfo.serverId
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleAdmin,
        options = {
            {
                label = T.Menus.SubSimpleActionOptions.playerSpectate,
                desc = T.Menus.SubSimpleActionOptions.playerSpectate_desc .. " " .. PlayerInfo.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:spectate", target, 'vorp.staff.Spectate', PlayerInfo.PlayerName)
                end
            },
            {
                label = T.Menus.SubSimpleActionOptions.playerFreeze,
                desc = T.Menus.SubSimpleActionOptions.playerFreeze_desc .. " " .. PlayerInfo.PlayerName,
                action = function()
                    if target then
                        if not freeze then
                            freeze = true
                            TriggerServerEvent("vorp_admin:freeze", target, freeze, 'vorp.staff.Frezee', PlayerInfo.PlayerName)
                            TriggerEvent("vorp:TipRight", T.Notify.switchedOn, 3000)
                        else
                            freeze = false
                            TriggerServerEvent("vorp_admin:freeze", target, freeze, 'vorp.staff.Frezee')
                            TriggerEvent("vorp:TipRight", T.Notify.switchedOff, 3000)
                        end
                    end
                end
            },
            {
                label = T.Menus.SubSimpleActionOptions.playerRevive,
                desc = T.Menus.SubSimpleActionOptions.playerRevive_desc .. " " .. PlayerInfo.PlayerName,
                action = function()
                    TriggerServerEvent('vorp_admin:revive', target, 'vorp.staff.Revive', PlayerInfo.PlayerName)
                end
            },
            {
                label = T.Menus.SubSimpleActionOptions.playerHeal,
                desc = T.Menus.SubSimpleActionOptions.playerHeal_desc .. " " .. PlayerInfo.PlayerName,
                action = function()
                    TriggerServerEvent('vorp_admin:heal', target, 'vorp.staff.Heal', PlayerInfo.PlayerName)
                end
            },
            {
                label = T.Menus.SubSimpleActionOptions.playerGoTo,
                desc = T.Menus.SubSimpleActionOptions.playerGoTo_desc .. " " .. PlayerInfo.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:TpToPlayer", target, 'vorp.staff.GoTo', PlayerInfo.PlayerName)
                end
            },
            {
                label = T.Menus.SubSimpleActionOptions.playerGoBack,
                desc = T.Menus.SubSimpleActionOptions.playerGoBack_desc .. " " .. PlayerInfo.PlayerName,
                action = function()
                    if lastLocation then
                        TriggerServerEvent("vorp_admin:sendAdminBack", 'vorp.staff.GoTo')
                    end
                end
            },
            {
                label = T.Menus.SubSimpleActionOptions.playerBring,
                desc = T.Menus.SubSimpleActionOptions.playerBring_desc .. " " .. PlayerInfo.PlayerName,
                action = function()
                    local adminCoords = GetEntityCoords(PlayerPedId())
                    TriggerServerEvent("vorp_admin:Bring", target, adminCoords, 'vorp.staff.Bring', PlayerInfo.PlayerName)
                end
            },
            {
                label = T.Menus.SubSimpleActionOptions.playerSendBack,
                desc = T.Menus.SubSimpleActionOptions.playerSendBack_desc .. " " .. PlayerInfo.PlayerName,
                action = function()
                    if lastLocation then
                        TriggerServerEvent("vorp_admin:TeleportPlayerBack", target, 'vorp.staff.Bring')
                    end
                end
            },
        }
    }
end

function BuildAdvancedActions(Player)
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = Player.PlayerName, -- Char player name
        options = {
            {
                label = T.Menus.SubAdvancedActionOptions.playerKick,
                desc = T.Menus.SubAdvancedActionOptions.playerKick_desc .. " " .. Player.PlayerName,
                action = function()
                    local targetGroup = Player.Group
                    local targetID = Player.serverId
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubAdvancedActionOptions.KickInput.title, {
                        { label = T.Menus.SubAdvancedActionOptions.KickInput.placeholder, type = 'text', placeholder = T.Menus.SubAdvancedActionOptions.KickInput.placeholder, required = true }
                    }, T.Menus.SubAdvancedActionOptions.KickInput.errorMsg)
                    if not vals then return end
                    local reason = tostring(vals[1])
                    if reason ~= "" then
                        if targetGroup ~= "user" then
                            TriggerEvent("vorp:TipRight", T.Notify.cantKickStaff, 4000)
                        else
                            TriggerServerEvent("vorp_admin:kick", targetID, reason, 'vorp.staff.Kick', Player.PlayerName)
                        end
                    else
                        VORP.NotifyObjective(T.Notify.empty, 5000)
                    end
                end
            },
            {
                label = T.Menus.SubAdvancedActionOptions.playerBan,
                desc = T.Menus.SubAdvancedActionOptions.playerBan_desc .. " " .. Player.PlayerName,
                action = function()
                    local group = Player.Group
                    local staticID = Player.staticID
                    local target = Player.serverId
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubAdvancedActionOptions.BanInput.title, {
                        { label = T.Menus.SubAdvancedActionOptions.BanInput.placeholder, type = 'text', placeholder = T.Menus.SubAdvancedActionOptions.BanInput.placeholder, required = true }
                    }, T.Menus.SubAdvancedActionOptions.BanInput.errorMsg)
                    if not vals then return end
                    local time = tostring(vals[1])
                    if time ~= "" then
                        if group ~= "user" then
                            TriggerEvent("vorp:TipRight", T.Notify.cantBanStaff, 4000)
                        else
                            TriggerServerEvent("vorp_admin:BanPlayer", target, staticID, time, 'vorp.staff.Ban', Player.PlayerName)
                        end
                    else
                        VORP.NotifyObjective(T.Notify.empty, 5000)
                    end
                end
            },
            {
                label = T.Menus.SubAdvancedActionOptions.playerUnBan,
                desc = T.Menus.SubAdvancedActionOptions.playerUnBan_desc .. " " .. Player.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:UnBan", Player.staticID, 'vorp.staff.Unban', Player.PlayerName)
                end
            },
            {
                label = T.Menus.SubAdvancedActionOptions.playerRespawn,
                desc = T.Menus.SubAdvancedActionOptions.playerRespawn_desc .. " " .. Player.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:respawnPlayer", Player.serverId, 'vorp.staff.Respawn', Player.PlayerName)
                end
            },
            {
                label = T.Menus.SubAdvancedActionOptions.playerUnWhitelist,
                desc = T.Menus.SubAdvancedActionOptions.playerUnWhitelist_desc .. " " .. Player.PlayerName,
                action = function()
                    TriggerServerEvent("vorp_admin:Whitelist", Player.serverId, Player.SteamId, "removewhitelist", 'vorp.staff.Unwhitelist', Player.PlayerName)
                    VORP.NotifyObjective(T.Notify.whiteRemoved, 5000)
                end
            },
            {
                label = T.Menus.SubAdvancedActionOptions.playerSetJob,
                desc = T.Menus.SubAdvancedActionOptions.playerSetJob_desc .. " " .. Player.PlayerName,
                action = function()
                    local target = Player.serverId
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubAdvancedActionOptions.JobInput.title, {
                        { label = 'Job Name', type = 'text', placeholder = 'police', required = true },
                        { label = 'Grade', type = 'number', placeholder = '1', required = true },
                        { label = 'Job Label', type = 'text', placeholder = 'Sheriff' },
                    }, T.Menus.SubAdvancedActionOptions.JobInput.errorMsg)
                    if not vals then return end
                    local jobname = tostring(vals[1])
                    local jobgrade = tonumber(vals[2])
                    local joblabel = vals[3] and tostring(vals[3]) or ""
                    if jobname and jobgrade then
                        TriggerServerEvent("vorp_admin:setJob", target, jobname, jobgrade, joblabel, 'vorp.staff.Setjob', Player.PlayerName)
                    end
                end
            },
            {
                label = T.Menus.SubAdvancedActionOptions.playerSetGroup,
                desc = T.Menus.SubAdvancedActionOptions.playerSetGroup_desc .. " " .. Player.PlayerName,
                action = function()
                    local target = Player.serverId
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubAdvancedActionOptions.GroupInput.title, {
                        { label = T.Menus.SubAdvancedActionOptions.GroupInput.placeholder, type = 'text', placeholder = T.Menus.SubAdvancedActionOptions.GroupInput.placeholder, required = true }
                    }, T.Menus.SubAdvancedActionOptions.GroupInput.errorMsg)
                    if not vals then return end
                    local result = tostring(vals[1])
                    if result ~= "" then
                        TriggerServerEvent("vorp_admin:setGroup", target, result, 'vorp.staff.Setgroup', Player.PlayerName)
                    else
                        VORP.NotifyObjective(T.Notify.empty, 5000)
                    end
                end
            },
        }
    }
end

-- Actions

function BuildActions()
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleAdmin,
        options = {
            {
                label = T.Menus.SubActionsAdminOptions.deleteMountHorse,
                desc = T.Menus.SubActionsAdminOptions.deleteMountHorse_desc,
                action = function()
                    if IsAdminAllowed('delete_horse') then
                        TriggerEvent("vorp:delHorse") -- TODO Make Server Side
                    end
                end
            },
            {
                label = T.Menus.SubActionsAdminOptions.deleteMountWagon,
                desc = T.Menus.SubActionsAdminOptions.deleteMountWagon_desc,
                action = function()
                    if IsAdminAllowed('delete_wagon') then
                        Delwagon()
                    end
                end
            },
            {
                label = T.Menus.SubActionsAdminOptions.deleteWagonInRadius,
                desc = T.Menus.SubActionsAdminOptions.deleteWagonInRadius_desc,
                action = function()
                    if not IsAdminAllowed('delete_wagons_radius') then return end
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubActionsAdminOptions.DelWagonRadiusInput.title, {
                        { label = T.Menus.SubActionsAdminOptions.DelWagonRadiusInput.placeholder, type = 'number', placeholder = T.Menus.SubActionsAdminOptions.DelWagonRadiusInput.placeholder, required = true }
                    }, T.Menus.SubActionsAdminOptions.DelWagonRadiusInput.errorMsg)
                    if not vals then return end
                    local radius = tonumber(vals[1])
                    if radius then
                        TriggerEvent("vorp:deleteVehicle", radius) -- TODO Make Server Side
                    else
                        VORP.NotifyObjective(T.Notify.empty, 5000)
                    end
                end
            },
            {
                label = T.Menus.SubActionsAdminOptions.getCoords,
                desc = T.Menus.SubActionsAdminOptions.getCoords_desc,
                submenu = function() if IsAdminAllowed('get_coords') then return BuildCoordsMenu() end end
            },
            {
                label = T.Menus.SubActionsAdminOptions.adminAnnounce,
                desc = T.Menus.SubActionsAdminOptions.adminAnnounce_desc,
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubActionsAdminOptions.AnnounceInput.title, {
                        { label = T.Menus.SubActionsAdminOptions.AnnounceInput.placeholder, type = 'text', placeholder = T.Menus.SubActionsAdminOptions.AnnounceInput.placeholder, required = true }
                    }, T.Menus.SubActionsAdminOptions.AnnounceInput.errorMsg)
                    if not vals then return end
                    local announce = vals[1]
                    if announce and announce ~= "" then
                        TriggerServerEvent("vorp_admin:announce", announce)
                    else
                        VORP.NotifyObjective(T.Notify.empty, 5000)
                    end
                end
            },
        }
    }
end

function BuildCoordsMenu()
    local function copyOpt(label, desc, dataType)
        return {
            label = label,
            desc = desc,
            action = function()
                CopyToClipboard(dataType)
            end
        }
    end
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleCoords,
        options = {
            copyOpt(T.Menus.SubCoordsMenu.getCoordsXYZ, T.Menus.SubCoordsMenu.getCoordsXYZ_desc, 'v2'),
            copyOpt(T.Menus.SubCoordsMenu.getCoordsVec3, T.Menus.SubCoordsMenu.getCoordsVec3_desc, 'v3'),
            copyOpt(T.Menus.SubCoordsMenu.getCoordsVec4, T.Menus.SubCoordsMenu.getCoordsVec4_desc, 'v4'),
            copyOpt(T.Menus.SubCoordsMenu.getHeading, T.Menus.SubCoordsMenu.getHeading_desc, 'heading'),
        }
    }
end

--to test
function BuildOffLine()
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleAdmin,
        options = {
            {
                label = T.Menus.SubOfflineOptions.banOrUnban,
                -- desc: <br> tags from the localized desc become "\n"
                desc = PlainDesc(T.Menus.SubOfflineOptions.banOrUnban_desc),
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubOfflineOptions.BanTypeInput.title, {
                        { label = 'Type (ban / unban)', type = 'text', placeholder = 'ban / unban', required = true },
                        { label = 'Static ID', type = 'number', placeholder = 'ID', required = true },
                        { label = 'Time (1h/1d/1w/1m/1y, 0 = perma)', type = 'text', placeholder = '1d' },
                    }, T.Menus.SubOfflineOptions.BanTypeInput.errorMsg)
                    if not vals then return end
                    local btype = tostring(vals[1])
                    local StaticID = tonumber(vals[2])
                    local time = vals[3] and tostring(vals[3]) or ""
                    if btype and StaticID then
                        if btype == "ban" then
                            TriggerServerEvent("vorp_admin:BanOffline", StaticID, time, 'vorp.staff.Ban')
                        elseif btype == "unban" then
                            TriggerServerEvent("vorp_admin:UnBan", StaticID, 'vorp.staff.Unban')
                        else
                            VORP.NotifyObjective(T.Notify.incorrectType, 5000)
                        end
                    else
                        VORP.NotifyObjective(T.Notify.missingArgument, 5000)
                    end
                end
            },
            {
                label = T.Menus.SubOfflineOptions.whiteOrUnwhite,
                desc = PlainDesc(T.Menus.SubOfflineOptions.whiteOrUnwhite_desc),
                action = function()
                    PupMenu.Close()
                    local vals = AskInput(T.Menus.SubOfflineOptions.WhiteTypeInput.title, {
                        { label = 'Type (whitelist)', type = 'text', placeholder = 'whitelist', required = true },
                        { label = 'Steam ID', type = 'text', placeholder = 'steam:...', required = true },
                    }, T.Menus.SubOfflineOptions.WhiteTypeInput.errorMsg)
                    if not vals then return end
                    local wtype = tostring(vals[1])
                    local steam = tostring(vals[2])
                    if wtype and steam then
                        if wtype == "whitelist" then
                            TriggerServerEvent("vorp_admin:Whitelistoffline", steam, wtype)
                        else
                            VORP.NotifyObjective(T.Notify.incorrectType, 5000)
                        end
                    else
                        VORP.NotifyObjective(T.Notify.missingArgument, 5000)
                    end
                end
            },
        }
    }
end
