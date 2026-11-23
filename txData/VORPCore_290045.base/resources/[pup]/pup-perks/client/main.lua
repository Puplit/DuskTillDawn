-- pup-perks | client: the effect cache other resources read, toasts and the perks panel

local EFF = {}   -- key -> { chance, mult, add }

RegisterNetEvent('pup-perks:sync', function(eff)
    EFF = eff or {}
end)

local function mult(key)
    local e = EFF[key]
    return (e and e.mult) or 1.0
end

local function bonus(key)
    local e = EFF[key]
    return (e and e.add) or 0
end

local function has(key)
    return EFF[key] ~= nil
end

local function roll(key)
    local e = EFF[key]
    if not e or (e.chance or 0) <= 0 then return false end
    return math.random(1, 100) <= e.chance
end

-- The one other resources call: hand it a duration, get back the perk-adjusted duration
local function timed(ms, key)
    ms = tonumber(ms) or 0
    local m
    if key then
        m = mult(key)
    else
        m = mult('dig_speed') * mult('underground_speed')
    end
    if m >= 1.0 then return math.floor(ms) end
    return math.floor(ms * m)
end

exports('Timed', timed)
exports('Mult', mult)
exports('Bonus', bonus)
exports('Has', has)
exports('Roll', roll)

--------------------------------------------------------------------------------
-- toasts (through pup-ui's notification system)
--------------------------------------------------------------------------------

RegisterNetEvent('pup-perks:toast', function(title, msg, tone)
    exports['pup-ui']:Toast({
        title    = title or Locale.perksTitle,
        subtitle = msg or '',
        symbol   = tone == 'red' and 'x' or 'spade',
        tone     = tone == 'red' and 'red' or nil,
        duration = 4200,
    })
end)

-- the panel

local panelOpen = false

-- keep push-to-talk alive while the perks screen is up
local pttActive, pttThread = false, false

local function setFocus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(on and true or false)
    pttActive = on and true or false
    if not pttActive or pttThread then return end
    pttThread = true
    CreateThread(function()
        while pttActive do
            Wait(0)
            DisableAllControlActions(0)
            EnableControlAction(0, `INPUT_PUSH_TO_TALK`, true)
            -- mumble latches the mic with SetControlNormal; re-assert it after the disable
            if LocalPlayer.state.pup_ptt_latched then SetControlNormal(0, `INPUT_PUSH_TO_TALK`, 1.0) end
            if LocalPlayer.state.pup_radio_talking then
                EnableControlAction(0, 249, true)
                SetControlNormal(0, 249, 1.0)
                SetControlNormal(1, 249, 1.0)
                SetControlNormal(2, 249, 1.0)
            end
        end
        pttThread = false
    end)
end

local function closePanel(fromNui)
    if not panelOpen then return end
    panelOpen = false
    setFocus(false)
    if not fromNui then SendNUIMessage({ action = 'perksHide' }) end
end

local function openPanel()
    if panelOpen then return end
    CreateThread(function()
        -- resolved HERE, not at file scope: this resource can start before vorp_core
        local Core = exports.vorp_core:GetCore()
        local data = Core.Callback.TriggerAwait('pup-perks:panel')
        if not data then
            exports['pup-ui']:Toast({
                title = Locale.perksTitle, subtitle = Locale.loadFailed,
                symbol = 'x', tone = 'red', duration = 4000,
            })
            return
        end
        panelOpen = true
        SendNUIMessage({ action = 'perks', data = data })
        setFocus(true)
    end)
end

-- the server repaints after every accepted change
RegisterNetEvent('pup-perks:refresh', function(data)
    if not panelOpen or not data then return end
    SendNUIMessage({ action = 'perksUpdate', data = data })
end)

-- xp gains float on the bar only while the panel is actually up
RegisterNetEvent('pup-perks:xp', function(info)
    if not panelOpen or not info then return end
    SendNUIMessage({ action = 'perksXp', data = { gained = info.gained or 0 } })
end)

-- NUI callbacks

RegisterNUICallback('perksClose', function(_, cb)
    cb('ok')
    closePanel(true)
end)

RegisterNUICallback('perksUpgrade', function(data, cb)
    cb('ok')
    if panelOpen and data and data.id then
        TriggerServerEvent('pup-perks:upgrade', data.id)
    end
end)

RegisterNUICallback('perksEquip', function(data, cb)
    cb('ok')
    if panelOpen and data and data.id then
        TriggerServerEvent('pup-perks:equip', data.id)
    end
end)

RegisterNUICallback('perksReset', function(_, cb)
    cb('ok')
    if panelOpen then TriggerServerEvent('pup-perks:reset') end
end)

RegisterNUICallback('perksChooseTree', function(data, cb)
    cb('ok')
    if panelOpen and data and data.cat then
        TriggerServerEvent('pup-perks:chooseTree', data.cat)
    end
end)

RegisterNUICallback('perksSwitchTree', function(data, cb)
    cb('ok')
    if panelOpen and data and data.cat then
        TriggerServerEvent('pup-perks:switchTree', data.cat)
    end
end)

RegisterNUICallback('perksWeeklyReset', function(_, cb)
    cb('ok')
    if panelOpen then TriggerServerEvent('pup-perks:weeklyReset') end
end)

-- never leave a player stuck with NUI focus and no panel
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if panelOpen then setFocus(false) end
end)

-- /hideui and death both mean "give the player their hands back"
AddEventHandler('pup-ui:HideAllUI', function() closePanel(false) end)

if Config.General.command and Config.General.command ~= '' then
    RegisterCommand(Config.General.command, function()
        openPanel()
    end, false)
end

exports('OpenPanel', openPanel)
