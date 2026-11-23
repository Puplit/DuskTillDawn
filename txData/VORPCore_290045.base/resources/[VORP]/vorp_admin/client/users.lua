-- Modified by Puppet (Dusk Till Dawn), 2026
-- USERS MENU ------------------------------------------------

local hideUI = false

local T = Translation.Langs[Config.General.language]

function OpenUsersMenu()
    local options = {
        {
            label = T.Menus.MainUserOptions.playerReport,
            desc = T.Menus.MainUserOptions.playerReport_desc,
            action = function()
                if not Config.Integrations.qwReports.enabled then
                    Report()
                else
                    TriggerEvent("vorp_admin:CreateReport")
                end
            end
        },
        {
            label = T.Menus.MainUserOptions.playerRequestStaff,
            desc = T.Menus.MainUserOptions.playerRequestStaff_desc,
            submenu = function() return BuildRequestStaff() end
        },
        {
            label = T.Menus.MainUserOptions.selfShowInfo,
            desc = T.Menus.MainUserOptions.selfShowInfo_desc,
            action = function()
                VORP.NotifyRightTip(T.Notify.notAvailable, 4000)
            end
        },
        {
            label = T.Menus.MainUserOptions.playerCommands,
            desc = T.Menus.MainUserOptions.playerCommands_desc,
            submenu = function() return BuildOpenCommands() end
        },
        {
            label = T.Menus.MainUserOptions.playerWalkAndClothesStyle,
            desc = T.Menus.MainUserOptions.playerWalkAndClothesStyle_desc,
            close = true,
            action = function()
                TriggerEvent("vorp_walkanim:OpenMenu")
            end
        },
    }
    if Config.Scoreboard.playerListEnabled then
        options[#options + 1] = {
            label = T.Menus.DefaultsMenusTitle.menuSubTitleScoreboard,
            desc = T.Menus.DefaultsMenusTitle.menuSubTitleScoreboard,
            submenu = function() return BuildScoreBoard() end
        }
    end

    PupMenu.Open({
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleScoreboard,
        options = options
    })
end

function BuildScoreBoard()
    local result = VORP.Callback.TriggerAwait("vorp_admin:Callback:getplayersinfo", { search = "all" })
    if not result then
        return
    end

    local options = {}
    for _, playersInfo in pairs(result) do
        local info = ""
        if Config.Scoreboard.showInfo == "showAll" then
            info = T.Menus.MainPlayerStatus.playerServerID .. " " .. playersInfo.serverId ..
                "\n" .. T.Menus.MainPlayerStatus.playerGroup .. " " .. playersInfo.Group ..
                "\n" .. T.Menus.MainPlayerStatus.playerJob .. " " .. playersInfo.Job
        elseif Config.Scoreboard.showInfo == "showJob" then
            info = T.Menus.MainPlayerStatus.playerJob .. " " .. playersInfo.Job
        elseif Config.Scoreboard.showInfo == "showGroup" then
            info = T.Menus.MainPlayerStatus.playerGroup .. " " .. playersInfo.Group
        elseif Config.Scoreboard.showInfo == "showID" then
            info = T.Menus.MainPlayerStatus.playerServerID .. " " .. playersInfo.serverId
        end
        options[#options + 1] = {
            label = playersInfo.PlayerName,
            desc = info
        }
    end

    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleScoreboard,
        options = options
    }
end

function Report()
    PupMenu.Close()
    local vals = AskInput(T.Menus.MainUserOptions.ReportInput.title, {
        { label = T.Menus.MainUserOptions.ReportInput.placeholder, type = 'text', placeholder = T.Menus.MainUserOptions.ReportInput.placeholder, required = true }
    }, T.Menus.MainUserOptions.ReportInput.errorMsg)
    if not vals then return end
    local report = tostring(vals[1])
    if report and report ~= "" then
        -- sent unconditionally; the report webhooks live server-side in server/config.lua
        VORP.NotifySimpleTop(T.Notify.reportTitle, T.Notify.reportSent, 3000)
        TriggerServerEvent("vorp_admin:alertstaff", report)
    end
end

------ REQUEST STAFF ---------------------------------

local cooldown = false
local timer = Config.Scoreboard.requestStaffCooldownSeconds

function BuildRequestStaff()
    local function staffOpt(label, desc, kind)
        return {
            label = label,
            desc = desc,
            action = function()
                if not cooldown then
                    TriggerServerEvent("vorp_admin:requeststaff", kind)
                    VORP.NotifyRightTip(T.Notify.requestSent, 4000)
                    cooldown = true
                else
                    VORP.NotifyRightTip(T.Notify.waitToReportAgain .. " " .. timer, 5000)
                end
            end
        }
    end
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleRequestStaff,
        options = {
            staffOpt(T.Menus.SubUserOptions.needHelp, T.Menus.SubUserOptions.needHelp_desc, "new"),
            staffOpt(T.Menus.SubUserOptions.foundBug, T.Menus.SubUserOptions.foundBug_desc, "bug"),
            staffOpt(T.Menus.SubUserOptions.rulesBroken, T.Menus.SubUserOptions.rulesBroken_desc, "rules"),
            staffOpt(T.Menus.SubUserOptions.someoneCheating, T.Menus.SubUserOptions.someoneCheating_desc, "cheating"),
        }
    }
end

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    while true do
        Wait(10)
        if timer >= 0 and cooldown then
            Wait(1000)
            if timer > 0 then
                timer = timer - 1
            end
            if 0 >= timer and cooldown then
                cooldown = false
                timer = Config.Scoreboard.requestStaffCooldownSeconds
            end
        end
    end
end)

---------------------------------------------------------------------------------------------------------

function BuildOpenCommands()
    return {
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitleCommands,
        options = {
            {
                label = T.Menus.SubUserOptions.delHorse,
                desc = T.Menus.SubUserOptions.delHorse_desc,
                action = function() DelHorse() end
            },
            {
                label = T.Menus.SubUserOptions.delWagon,
                desc = T.Menus.SubUserOptions.delWagon_desc,
                action = function() Delwagon() end
            },
            {
                label = T.Menus.SubUserOptions.hideUi,
                desc = T.Menus.SubUserOptions.hideUi_desc,
                action = function() HideUI() end
            },
            {
                label = T.Menus.SubUserOptions.cancelAnimation,
                desc = T.Menus.SubUserOptions.cancelAnimation_desc,
                action = function()
                    local player = PlayerPedId()
                    ClearPedTasksImmediately(player)
                end
            },
        }
    }
end

function DelHorse()
    local player = PlayerPedId()
    local mount  = GetMount(player)
    if IsPedOnMount(player) then
        DeleteEntity(mount)
    else
        TriggerEvent("vorp:TipRight", T.Notify.youNeedtoSeatead, 3000)
    end
end

function Delwagon()
    local player = PlayerPedId()
    local wagon = GetVehiclePedIsIn(player, true)

    if IsPedInAnyVehicle(player, true) then
        wagon = GetVehiclePedIsIn(player, true)
    end
    if DoesEntityExist(wagon) then
        DeleteVehicle(wagon)
        DeleteEntity(wagon)
        TriggerEvent('vorp:TipRight', T.Notify.youDeletedWagon, 3000)
    else
        TriggerEvent('vorp:TipRight', T.Notify.youNeedtoSeatead, 3000)
    end
end

function HideUI()
    if not hideUI then
        DisplayRadar(false)
        DisplayHud(false)
        TriggerEvent("fred_hud:setVisible", false)
        TriggerEvent("pup-displayrange", false)
        TriggerEvent("vorp:showUi", false)
        hideUI = true
    else
        DisplayRadar(true)
        DisplayHud(true)
        TriggerEvent("fred_hud:setVisible", true)
        TriggerEvent("pup-displayrange", true)
        TriggerEvent("vorp:showUi", true)
        hideUI = false
    end
end
