-- Modified by Puppet (Dusk Till Dawn), 2026
local vorpShowUI = true
local ShowUI = true
local T <const> = Translation[Lang].MessageOfSystem.PlayerMenu
local N <const> = Translation[Lang].Notify

function CoreAction.Utils.ToggleVorpUI()
    vorpShowUI = not vorpShowUI
    TriggerEvent("vorp:showUi", vorpShowUI)
end

-- pup: SET rather than toggle, so a resource that hides the UI for a shot can
-- put it back without ShowUI drifting out of step with what is on screen. The
-- toggle below is just a caller of it.
function CoreAction.Utils.SetAllUI(show)
    ShowUI = show and true or false
    DisplayRadar(ShowUI)
    -- pup: /hideUi is the screenshot command, so it takes EVERYTHING - the
    -- game's own health/stamina cores and fred_hud's gauge ring as well as the
    -- minimap and the vorp money/gold strip.
    DisplayHud(ShowUI)
    TriggerEvent("fred_hud:setVisible", ShowUI)
    TriggerEvent("pup-displayrange", ShowUI)
    TriggerEvent("vorp:showUi", ShowUI)
end

function CoreAction.Utils.ToggleAllUI()
    CoreAction.Utils.SetAllUI(not ShowUI)
end

-- for pup-camera and anything else that needs a clean screen for a shot
exports('SetAllUI', function(show) CoreAction.Utils.SetAllUI(show) end)

RegisterNetEvent('vorp:updateUi', function(stringJson)
    SendNUIMessage(json.decode(stringJson))
end)

RegisterNetEvent('vorp:showUi', function(active)
    vorpShowUI = active
    local jsonpost = { type = "ui", action = "hide" }
    if active then jsonpost = { type = "ui", action = "show" } end

    SendNUIMessage(jsonpost)
end)

RegisterNetEvent('vorp:setPVPUi', function(active)
    SendNUIMessage({ type = "ui", action = "setpvp", pvp = active })
end)

-- MOVABLE HUD. fred_hud owns the layout menu and the saved positions
AddEventHandler('vorp_core:hudLayout', function(layout)
    if type(layout) ~= "table" then return end
    local money = type(layout.money) == "table" and layout.money or {}
    local id    = type(layout.id) == "table" and layout.id or {}
    SendNUIMessage({
        type = "ui", action = "hudlayout",
        moneydx = tonumber(money.dx) or 0, moneydy = tonumber(money.dy) or 0,
        iddx    = tonumber(id.dx) or 0,    iddy    = tonumber(id.dy) or 0,
        hidemoney = layout.hideMoney == true,
        moneyfont = tostring(layout.moneyFont or 'lino'),
        moneysize = tostring(layout.moneySize or 'm'),
    })
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    Wait(10000)
    SendNUIMessage({
        type = "ui",
        action = "initiate",
        hidegold = Config.HideGold,
        hidemoney = Config.HideMoney,
        hidelevel = Config.HideLevel,
        hideid = Config.HideID,
        hidetokens = Config.HideTokens,
        uiposition = Config.UIPosition,
        uilayout = Config.UILayout,
        closeondelay = Config.CloseOnDelay,
        closeondelayms = Config.CloseOnDelayMS,
        hidepvp = Config.HidePVP,
        pvp = Config.PVP
    })

    if Config.HideWithRader then
        local cantoggle = not Config.HideUi

        CreateThread(function()
            while true do
                if IsRadarHidden() then
                    cantoggle = true
                    SendNUIMessage({ type = "ui", action = "hide" })
                    vorpShowUI = false
                elseif cantoggle and Config.OpenAfterRader then
                    cantoggle = false
                    SendNUIMessage({ type = "ui", action = "show" })
                    vorpShowUI = true
                end

                Wait(1000)
            end
        end)
    end
end)

RegisterNUICallback('close', function(_, cb)
    vorpShowUI = false
    cb('ok')
end)


local function formatCooldown(seconds)
    local totalSeconds <const> = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes <const> = math.max(1, math.ceil(totalSeconds / 60))
    return minutes .. " min"
end

local function buildJobsContextDescription(payload)
    local cooldownRemaining <const> = tonumber(payload.cooldownRemaining) or 0
    if cooldownRemaining > 0 then
        return T.switchCooldown .. " " .. formatCooldown(cooldownRemaining)
    end

    return nil
end


local function normalizeMenuPayload(payload)
    if type(payload) ~= "table" then
        return nil
    end

    if payload.skills then
        return payload
    end

    return {
        skills = payload,
        jobs = {},
        activeJob = {},
        cooldownRemaining = 0,
    }
end

local function buildSkillsSpec(payload)
    local skills <const> = payload.skills or {}
    local options <const> = {}

    for skillName, skillData in pairs(skills) do
        options[#options + 1] = {
            label = skillName .. " " .. skillData.Level,
            value = skillName,
            disabled = true,
            desc = skillData.Label ..
                "\n" .. T.currentExp .. " " .. skillData.Exp ..
                "\n" .. T.currentLevel .. " (" .. skillData.Level .. " / " .. skillData.MaxLevel .. ")" ..
                "\n" .. T.nextLevelAt .. " " .. skillData.NextLevel .. " " .. T.exp,
        }
    end

    if #options == 0 then
        options[1] = {
            label = T.noSkillsLabel,
            value = "no_skills",
            disabled = true,
            desc = T.noSkillsDesc
        }
    end

    return {
        title = T.skillsTitle,
        subtitle = T.skillsSubtext,
        options = options,
    }
end

local function buildJobsSpec(payload)
    local options <const> = {}
    local jobs <const> = payload.jobs or {}
    local contextDescription <const> = buildJobsContextDescription(payload)
    local cooldownRemaining <const> = tonumber(payload.cooldownRemaining) or 0

    for jobName, jobData in pairs(jobs) do
        local isActive <const> = payload.activeJob and payload.activeJob.name == jobName
        local isDisabled <const> = cooldownRemaining > 0 and not isActive
        local label = jobData.label or jobName
        if isActive then
            label = label .. " [" .. T.activeTag .. "]"
        end

        local desc = T.job .. " " .. jobName .. "\n" .. T.grade .. " " .. tostring(jobData.grade or 0)
        if contextDescription then
            desc = desc .. "\n" .. contextDescription
        end
        if isDisabled then
            desc = desc .. "\n" .. T.cooldownBlockedDescription
        end
        local footerText <const> = not isActive and not isDisabled and T.applyMultiJobFooterText or nil
        if footerText then
            desc = desc .. "\n" .. footerText
        end

        options[#options + 1] = {
            label = label,
            value = jobName,
            desc = desc,
            disabled = isDisabled,
            action = function()
                if payload.activeJob and payload.activeJob.name == jobName then
                    VorpNotification:NotifyRightTip(T.alreadyEquipped, 4000)
                    return
                end

                if cooldownRemaining > 0 then
                    VorpNotification:NotifyRightTip(N.MultiJob.CoolDownMJob .. formatCooldown(cooldownRemaining), 4000)
                    return
                end

                TriggerServerEvent("vorp:SwitchMultiJobMenu", jobName)
                PupMenu.Close()
            end,
        }
    end

    return {
        title = T.jobsTitle,
        subtitle = T.jobsSubtext,
        options = options,
    }
end

function OpenPlayerMenuUI(payload)
    local menuPayload <const> = normalizeMenuPayload(payload)
    if not menuPayload then
        return
    end

    local hasJobs <const> = menuPayload.jobs and next(menuPayload.jobs) ~= nil
    local options <const> = {
        {
            label = T.skillsLabel,
            value = "skills",
            desc = T.skillsDescription .. "\n" .. T.moreOptionsFooterText,
            submenu = function() return buildSkillsSpec(payload) end,
        },
        {
            label = T.jobsLabel,
            value = "jobs",
            desc = hasJobs and (T.jobsDescription .. "\n" .. T.moreOptionsFooterText) or T.jobsDescriptionEmpty,
            submenu = function() return buildJobsSpec(payload) end,
        }
    }

    if not hasJobs then
        table.remove(options, 2)
    end

    PupMenu.Open({
        title = T.title,
        subtitle = T.subtext,
        options = options,
    })
end

RegisterNetEvent('vorp:OpenPlayerMenu', function(payload)
    OpenPlayerMenuUI(payload)
end)
