money = 0
-- mystress = nil

 RegisterNetEvent("gui:getItems")
 AddEventHandler("gui:getItems", function(THEITEMS)
     SendNUIMessage({
        items = THEITEMS,
     })
 end)

-- pup: the original's commented-out "stress" handlers were removed here.

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local _source = source 
		--TriggerServerEvent("hud:checkmoney")
        Citizen.InvokeNative(0x50C803A4CD5932C5 , true)
        local myhunger = exports["fred_metabolism"]:getHunger()
        local mythirst = exports["fred_metabolism"]:getThirst()

        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        Citizen.InvokeNative(0xB98B78C3768AF6E0,true)
        -- show the EFFECTIVE temperature (ambient + clothing warmth from fred_metabolism
        local ok, temp = pcall(function() return exports["fred_metabolism"]:getEffectiveTemp() end)
        if not ok or temp == nil then
            temp = GetTemperatureAtCoords(coords)
        end
		local _src = source
        -- the food/thirst/temp strip used to hide whenever the minimap was hidden (show = not IsRadarHidden())
        local inCharScreen = false
        local okc, res = pcall(function() return exports.vorp_character:IsInCharacterScreen() end)
        if okc then inCharScreen = res and true or false end
        local hideHud = IsPauseMenuActive() or IsScreenFadedOut() or inCharScreen
        SendNUIMessage({
            action = "updateStatusHud",
                show = not hideHud,
                hunger = myhunger,
                thirst = mythirst,
                --stress = mystress,
                --cash = money,
                -- the player picks the unit in /hud
                temp = (HudSettings and HudSettings.tempUnit == 'F')
                       and (math.floor(temp * 1.8 + 32.0) .. "°F")
                       or  (math.floor(temp) .. "°C"),
		})
        -- 250ms so the thermometer tracks clothing changes instantly (fred_metabolism recomputes on the spot when clothes change)
        Citizen.Wait(Config.Timing.statusUpdateMs)
    end
end)

-- the original's commented-out "stress" system was removed - unused, and its server events do not exist on this build

-- pup: whole-HUD on/off, so /hideUi (vorp_core) and the admin Hide UI take the
-- gauges with them instead of leaving the rings floating over a clean screen.
RegisterNetEvent('fred_hud:setVisible')
AddEventHandler('fred_hud:setVisible', function(show)
    SendNUIMessage({ action = 'hudVisible', show = show ~= false })
end)

-- post-revive weakness countdown (fired by pup-medical's recovery
RegisterNetEvent('fred_hud:recoveryBar')
AddEventHandler('fred_hud:recoveryBar', function(seconds)
    SendNUIMessage({ action = 'recoveryBar', seconds = tonumber(seconds) or 0 })
end)

-- pup: Eco Boost gauge (pup-misc pushes { active, earned, cap } on every change)
RegisterNetEvent('pup-misc:ecoboost', function(data)
    data = data or {}
    -- F8 line so a missing ring can be told apart from a missing event
    print(('[fred_hud] eco boost %s  %s / %s'):format(
        data.active and 'ACTIVE' or 'off', tostring(data.earned or 0), tostring(data.cap or 0)))
    SendNUIMessage({
        action = 'ecoBoost',
        active = data.active == true,
        earned = tonumber(data.earned) or 0,
        cap    = tonumber(data.cap) or 0,
    })
end)

-- pup: bank heist gauges (pup_robbery pushes { active, timer, alarm, alarmMax })
AddEventHandler('fred_hud:heist', function(data)
    data = data or {}
    SendNUIMessage({
        action   = 'heist',
        active   = data.active == true,
        timer    = tonumber(data.timer) or 0,
        alarm    = tonumber(data.alarm) or 0,
        alarmMax = tonumber(data.alarmMax) or Config.Heist.alarmMax,
    })
end)

-- a HUD restart blanks the gauge, so ask for the real state
CreateThread(function()
    Wait(Config.Timing.ecoSyncDelayMs)
    TriggerServerEvent('pup-misc:ecoboost:sync')
end)

-- /hudwhy - says exactly why the food/water/temp strip is hidden
RegisterCommand(Config.General.whyCommand, function()
    local okc, res = pcall(function() return exports.vorp_character:IsInCharacterScreen() end)
    local pause  = IsPauseMenuActive()
    local faded  = IsScreenFadedOut()
    local inChar = okc and (res and true or false) or false
    print(('^3[fred_hud]^7 pauseMenu=%s screenFaded=%s charScreen=%s (export ok=%s)  -> HUD %s')
        :format(tostring(pause), tostring(faded), tostring(inChar), tostring(okc),
                (pause or faded or inChar) and 'HIDDEN' or 'SHOWN'))
    TriggerEvent('vorp:TipBottom', Locale.hudWhy
        :format(tostring(pause), tostring(faded), tostring(inChar)), 8000)
end, false)
