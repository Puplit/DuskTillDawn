-- Modified by Puppet (Dusk Till Dawn), 2026
-- ADMIN WEB PANEL (NUI) -- the primary /admin view
local Core = exports.vorp_core:GetCore()

OpenPupDashboard = OpenMenu

local panelOpen = false

local function pushToPanel(action, data)
    SendNUIMessage({ app = 'panel', action = action, data = data })
end

-- surface an action result INSIDE the panel
RegisterNetEvent('vorp_admin:panelToast', function(text, isError)
    pushToPanel('toast', { text = tostring(text or ''), error = isError and true or false })
end)

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    SetNuiFocus(false, false)
    pushToPanel('close')
end

function OpenAdminPanel()
    if panelOpen then return end
    local info = Core.Callback.TriggerAwait('vorp_admin:Callback:getDashboard')
    if not info then
        return Core.NotifyRightTip('You are not allowed to open this menu', 4000)
    end
    panelOpen = true
    SetNuiFocus(true, true)
    pushToPanel('open', {
        serverName = (info.serverName ~= '' and info.serverName) or 'ADMIN',
        group      = info.group,
        charName   = info.charName, -- footer shows the admin's own character name
        -- what this admin holds, so the panel can hide controls it cannot use
        perms      = info.perms,
        stats      = info,
    })
end

function OpenMenu()
    OpenAdminPanel()
end

-- NUI callbacks
RegisterNUICallback('panelClose', function(_, cb)
    closePanel()
    cb('ok')
end)

-- Preview a screen effect from the consumables editor
local fxPreview = nil
local function stopFxPreview()
    if not fxPreview then return end
    local name = fxPreview
    fxPreview = nil
    pcall(function()
        if AnimpostfxIsRunning(name) then AnimpostfxStop(name) end
    end)
end

RegisterNUICallback('panelFxPreview', function(data, cb)
    local name = tostring(data and data.effect or '')
    local secs = math.max(1, math.min(30, tonumber(data and data.seconds) or 5))

    stopFxPreview()
    if name == '' then cb('ok') return end

    fxPreview = name
    cb('ok')

    CreateThread(function()
        -- hand focus back so the effect is visible over the world, not the panel
        SetNuiFocus(false, false)
        pushToPanel('fxPreviewStart', { effect = name, seconds = secs })

        local ok = pcall(function() AnimpostfxPlay(name) end)
        if not ok then
            pushToPanel('fxPreviewEnd', { bad = true })
            fxPreview = nil
            return
        end

        local until_ = GetGameTimer() + secs * 1000
        while fxPreview == name and GetGameTimer() < until_ do Wait(100) end

        stopFxPreview()
        SetNuiFocus(true, true)
        pushToPanel('fxPreviewEnd', {})
    end)
end)

-- Times a gold-core buff so the unit stops being guesswork
RegisterNUICallback('panelBuffTest', function(data, cb)
    local attr = math.max(0, math.min(2, math.floor(tonumber(data and data.attribute) or 0)))
    local value = tonumber(data and data.value) or 0
    local outer = (data and data.outer) ~= false
    cb('ok')

    CreateThread(function()
        local ped = PlayerPedId()
        local ok = pcall(function()
            if outer then
                Citizen.InvokeNative(0xF6A7C08DF2E28B28, ped, attr, value + 0.0, true)
            else
                Citizen.InvokeNative(0x4AF5A4C7B9157D14, ped, attr, value + 0.0, true)
            end
        end)
        if not ok then
            pushToPanel('buffTest', { done = true, error = 'could not apply the buff' })
            return
        end

        local function isOn()
            local on = false
            pcall(function() on = Citizen.InvokeNative(0x200373A8DF081F22, ped, attr) end)
            return on and true or false
        end

        -- the flag is not set the instant the native returns
        local waited = 0
        while not isOn() and waited < 2000 do Wait(100) waited = waited + 100 end
        if not isOn() then
            pushToPanel('buffTest', { done = true, never = true, value = value })
            return
        end

        local started = GetGameTimer()
        local last = -1
        -- 3 minutes is well past anything sane; stop rather than poll forever
        while (GetGameTimer() - started) < 180000 do
            local secs = math.floor((GetGameTimer() - started) / 1000)
            if not isOn() then
                pushToPanel('buffTest', { done = true, seconds = secs, value = value })
                return
            end
            if secs ~= last then
                last = secs
                pushToPanel('buffTest', { done = false, seconds = secs, value = value })
            end
            Wait(200)
        end
        pushToPanel('buffTest', { done = true, seconds = 180, value = value, capped = true })
    end)
end)

RegisterNUICallback('panelFxStop', function(_, cb)
    stopFxPreview()
    SetNuiFocus(true, true)
    pushToPanel('fxPreviewEnd', {})
    cb('ok')
end)

RegisterNUICallback('panelGameMenu', function(_, cb)
    closePanel()
    cb('ok')
    -- next frame: focus must be fully released before the pup-ui panel takes over
    SetTimeout(0, function() OpenPupDashboard() end)
end)

-- economy aggregates SUM half the database - cache 60s so the 5s stats poll stays cheap
local econCache, econCachedAt = nil, 0

RegisterNUICallback('panelStats', function(_, cb)
    cb('ok')
    CreateThread(function()
        local info = Core.Callback.TriggerAwait('vorp_admin:Callback:getDashboard')
        if not econCache or (GetGameTimer() - econCachedAt) > 60000 then
            econCache = Core.Callback.TriggerAwait('vorp_admin:Callback:getEconomy')
            econCachedAt = GetGameTimer()
        end
        pushToPanel('stats', { info = info or false, econ = econCache or false })
    end)
end)

RegisterNUICallback('panelPlayers', function(data, cb)
    cb('ok')
    local search = type(data) == 'table' and tostring(data.search or '') or ''
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelPlayers', { search = search })
        pushToPanel('players', payload or false)
    end)
end)

RegisterNUICallback('panelMap', function(_, cb)
    cb('ok')
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelMap')
        pushToPanel('map', payload or false)
    end)
end)

-- the property layers change rarely; fetched on demand, not on every player poll
RegisterNUICallback('panelMapLayers', function(_, cb)
    cb('ok')
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelMapLayers')
        pushToPanel('mapLayers', payload or false)
    end)
end)

-- Right-click on the live map: the map only knows x/y, so the ground height is found here.
--
-- ORDER MATTERS. The admin is put ABOVE the spot first, which streams the area in, and
-- only then is the ground read and the drop made. Probing before the move fails (the
-- target has not streamed in), falls back to a height of 300 and drops them from the sky.
RegisterNUICallback('panelMapTeleport', function(data, cb)
    cb('ok')
    local x, y = tonumber(data and data.x), tonumber(data and data.y)
    if not x or not y then return end
    x, y = x + 0.0, y + 0.0
    closePanel()

    CreateThread(function()
        local ped <const> = PlayerPedId()
        local oldCoords <const> = GetEntityCoords(ped)
        local PROBE_Z <const> = 500.0

        DoScreenFadeOut(500)
        Wait(500)

        -- frozen for the whole trip: no fall damage, no ragdoll on landing
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, x, y, PROBE_Z, false, false, false, false)
        RequestCollisionAtCoord(x, y, PROBE_Z)

        local deadline <const> = GetGameTimer() + 8000
        repeat Wait(50) until HasCollisionLoadedAroundEntity(ped) or GetGameTimer() > deadline

        -- walk the probe down: one height rarely answers everywhere on the map
        local groundZ
        for _, from in ipairs({ 500.0, 300.0, 200.0, 150.0, 100.0, 60.0, 30.0, 10.0, 0.0, -20.0 }) do
            RequestCollisionAtCoord(x, y, from)
            Wait(60)
            local ok, gz = GetGroundZFor_3dCoord(x, y, from, false)
            if ok and gz and gz > -200.0 then groundZ = gz break end
        end

        SetEntityCoords(ped, x, y, (groundZ and (groundZ + 1.0)) or PROBE_Z, false, false, false, false)
        Wait(200)
        FreezeEntityPosition(ped, false)
        DoScreenFadeIn(650)

        -- deep water, or a spot with no collision at all: say so instead of leaving
        -- them wondering why they are hanging in the air
        if not groundZ then
            TriggerEvent('vorp:TipRight', 'No ground found there - you are in the air. Use noclip.', 6000)
        end

        TriggerServerEvent("vorp_admin:tptocoords", oldCoords, x, y, (groundZ and (groundZ + 1.0)) or PROBE_Z)
    end)
end)

-- WHERE THE ADMIN IS STANDING, for the Teleports page readout. Everything a
-- config file might want: raw position, heading, the ground under their feet,
-- the zone name, and the interior id when they are inside one.
RegisterNUICallback('panelMyPos', function(_, cb)
    cb('ok')
    local ped <const> = PlayerPedId()
    local c <const> = GetEntityCoords(ped)
    local h <const> = GetEntityHeading(ped)

    -- probe from just above their feet: from high up this returns a roof when indoors
    local okG, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)

    local zone
    pcall(function()
        if GetResourceState('pup-mdt') == 'started' then
            zone = exports['pup-mdt']:GetZoneName({ x = c.x, y = c.y, z = c.z })
        end
    end)

    pushToPanel('mypos', {
        x = c.x, y = c.y, z = c.z, h = h,
        groundZ  = (okG and gz) or nil,
        interior = GetInteriorAtCoords(c.x, c.y, c.z),
        zone     = zone,
        mounted  = IsPedOnMount(ped) and true or false,
    })
end)

RegisterNUICallback('panelPlayerDetail', function(data, cb)
    cb('ok')
    local charid = type(data) == 'table' and tonumber(data.charid) or nil
    if not charid then return end
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelPlayerDetail', { charid = charid })
        pushToPanel('detail', payload or false)
    end)
end)

-- actions: every one relays to an EXISTING vorp_admin server event
-- RECEIVED BY THE TARGET, not the admin. This file loads for every player, so
-- the handler is here with the rest of the panel plumbing.
--
-- It runs the COMMAND rather than rebuilding the ped directly: vorp_character's
-- `rc` refuses while a character is being created and while pup_hideouts has
-- them mid-robbery, and those guards exist for good reasons. Going around them
-- to save a line would reintroduce exactly what they were added to stop.
-- "rc" is vorp_character's Config.Reload.command. Its Config is a different
-- table from ours, so the name is written out here; change it in both if it ever
-- moves (vorp_character/config/main.lua).
RegisterNetEvent('vorp_admin:forceReloadChar', function()
    ExecuteCommand('rc')
end)

RegisterNUICallback('panelAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local action = tostring(data.action or '')
    local target = tonumber(data.target)
    local name   = tostring(data.name or '')
    if not target then return end

    if action == 'bring' then
        TriggerServerEvent('vorp_admin:Bring', target, GetEntityCoords(PlayerPedId()), 'vorp.staff.Bring', name)
    elseif action == 'goto' then
        closePanel()
        TriggerServerEvent('vorp_admin:TpToPlayer', target, 'vorp.staff.GoTo', name)
    elseif action == 'heal' then
        TriggerServerEvent('vorp_admin:heal', target, 'vorp.staff.Heal', name)
    elseif action == 'reloadchar' then
        -- makes THEM run /rc; fixes a ped that came back wrong
        TriggerServerEvent('vorp_admin:forceReload', target)
    elseif action == 'revive' then
        TriggerServerEvent('vorp_admin:revive', target, 'vorp.staff.Revive', name)
    elseif action == 'freeze' then
        TriggerServerEvent('vorp_admin:freeze', target, data.state == true, 'vorp.staff.Frezee', name)
    elseif action == 'spectate' then
        closePanel()
        TriggerServerEvent('vorp_admin:spectate', target, 'vorp.staff.Spectate', name)
    elseif action == 'kick' then
        TriggerServerEvent('vorp_admin:kick', target, tostring(data.reason or 'kicked by admin'), 'vorp.staff.Kick', name)
    -- NOTE givePlayer's signature is (target, action, data1, data2, data3, _, name) - SEVEN params
    elseif action == 'giveitem' then
        local item, qty = tostring(data.item or ''), tonumber(data.qty)
        if item ~= '' and qty and qty > 0 then
            TriggerServerEvent('vorp_admin:givePlayer', target, 'item', item, qty, nil, nil, name)
        end
    elseif action == 'givemoney' then
        local amount = tonumber(data.amount)
        if amount and amount > 0 then
            TriggerServerEvent('vorp_admin:givePlayer', target, 'moneygold', 0, amount, nil, nil, name)
        end
    elseif action == 'givegold' then
        local amount = tonumber(data.amount)
        if amount and amount > 0 then
            TriggerServerEvent('vorp_admin:givePlayer', target, 'moneygold', 1, amount, nil, nil, name)
        end
    elseif action == 'clearmoney' then
        TriggerServerEvent('vorp_admin:ClearCurrency', target, 'money', nil, name)
    elseif action == 'cleargold' then
        TriggerServerEvent('vorp_admin:ClearCurrency', target, 'gold', nil, name)
    elseif action == 'respawn' then
        TriggerServerEvent('vorp_admin:respawnPlayer', target, nil, name)
    elseif action == 'tpback' then
        TriggerServerEvent('vorp_admin:TeleportPlayerBack', target)
    elseif action == 'instance' then
        TriggerServerEvent('vorp_admin:setInstance', target, tonumber(data.bucket) or 0, name)
    elseif action == 'liveinv' then
        -- the inventory UI needs the NUI focus this panel is holding
        closePanel()
        TriggerServerEvent('vorp_admin:openLiveInventory', target)
    elseif action == 'clearitems' then
        local what = data.what == 'weapons' and 'weapons' or 'items'
        TriggerServerEvent('vorp_admin:ClearAllItems', what, target, nil, name)
    elseif action == 'giveweapon' then
        local weapon = tostring(data.weapon or '')
        if weapon ~= '' then
            TriggerServerEvent('vorp_admin:givePlayer', target, 'weapon', weapon, nil, nil, nil, name)
        end
    elseif action == 'givehorse' then
        local model = tostring(data.model or '')
        if model ~= '' then
            TriggerServerEvent('vorp_admin:givePlayer', target, 'horse', model,
                tostring(data.hname or 'Horse'), tostring(data.sex or 'male'), nil, name)
        end
    elseif action == 'givewagon' then
        local model = tostring(data.model or '')
        if model ~= '' then
            TriggerServerEvent('vorp_admin:givePlayer', target, 'wagon', model,
                tostring(data.wname or 'Wagon'), nil, nil, name)
        end
    elseif action == 'setjob' then
        local job, grade = tostring(data.job or ''), tonumber(data.grade)
        if job ~= '' and grade then
            TriggerServerEvent('vorp_admin:setJob', target, job, grade, tostring(data.label or job), nil, name)
        end
    elseif action == 'setgroup' then
        local group = tostring(data.group or '')
        if group ~= '' then
            TriggerServerEvent('vorp_admin:setGroup', target, group, nil, name)
        end
    elseif action == 'ban' then
        local staticid = tonumber(data.staticid)
        local time = tostring(data.time or '')
        -- time format the server parses: <n>d / <n>w / <n>m / <n>y
        if staticid and time:match('^%d+[dwmy]$') then
            TriggerServerEvent('vorp_admin:BanPlayer', target, staticid, time, nil, name)
        end
    elseif action == 'setpobox' then
        -- pup: mail PO Box, keyed by CHARID so it works on offline characters
        local charid, box = tonumber(data.charid), tonumber(data.box)
        if charid and box then
            TriggerServerEvent('vorp_admin:panelSetPoBox', charid, box)
        end
    elseif action == 'createpobox' then
        local charid = tonumber(data.charid)
        if charid then
            -- box may be nil: the mail resource then picks the next free number
            TriggerServerEvent('vorp_admin:panelCreatePoBox', charid, tonumber(data.box))
        end
    elseif action == 'deletecharacter' then
        -- keyed by CHARID, not the server id - this is an offline action
        local charid = tonumber(data.charid)
        if charid then
            TriggerServerEvent('vorp_admin:panelDeleteCharacter', charid)
        end
    elseif action == 'setscale' then
        -- height change: keyed by CHARID (works for offline characters too)
        local charid, scale = tonumber(data.charid), tonumber(data.scale)
        if charid and scale then
            TriggerServerEvent('vorp_admin:panelSetScale', charid, scale)
        end
    elseif action == 'troll' then
        local TROLLS <const> = {
            kill      = 'vorp_admin:ServerTrollKillPlayerHandler',
            lightning = 'vorp_admin:ServerTrollLightningStrikePlayerHandler',
            fire      = 'vorp_admin:ServerTrollSetPlayerOnFireHandler',
            heaven    = 'vorp_admin:ServerTrollTPToHeavenHandler',
            ragdoll   = 'vorp_admin:ServerTrollRagdollPlayerHandler',
            handcuff  = 'vorp_admin:ServerHandcuffPlayerHandler',
            drainstam = 'vorp_admin:ServerDrainPlayerStamHandler',
        }
        local ev = TROLLS[tostring(data.kind or '')]
        if ev then TriggerServerEvent(ev, target) end
    end
end)

-- Events page. Gated on manage_events server side; the callback answers false
-- when it refuses, which the page renders as "no access".
-- WEATHER. The panel page drives the same weathersync server events as
-- /weatherui, so the ace check on command.weatherui still decides who may
-- actually change anything.
local weatherState = nil

-- weathersync answers requestUpdatedAdminUi with this; time arrives as seconds.
-- RegisterNetEvent is NOT optional and is per resource: weathersync registers
-- this name in its own client, which does nothing for us. Without it the
-- server's reply never reaches this handler and the page stays empty.
RegisterNetEvent('weathersync:updateAdminUi')
AddEventHandler('weathersync:updateAdminUi', function(weather, time, timescale, windDirection, windSpeed, syncDelay)
    local secs = tonumber(time) or 0
    weatherState = {
        weather       = weather,
        day           = math.floor(secs / 86400),
        hour          = math.floor(secs / 3600) % 24,
        minute        = math.floor(secs / 60) % 60,
        second        = secs % 60,
        timescale     = timescale,
        windDirection = windDirection,
        windSpeed     = windSpeed,
        syncDelay     = syncDelay,
    }
    pushToPanel('weather', weatherState)
end)

RegisterNUICallback('panelWeather', function(_, cb)
    cb('ok')
    -- the answer comes back on updateAdminUi above, which does the push
    TriggerServerEvent('weathersync:requestUpdatedAdminUi')
    -- something to draw on the very first open, before the first answer lands
    if weatherState then pushToPanel('weather', weatherState) end
end)

RegisterNUICallback('panelWeatherSet', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local action = tostring(data.action or '')

    local function num(v, fallback)
        return tonumber(v) or fallback
    end

    if action == 'weather' then
        TriggerServerEvent('weathersync:setWeather', tostring(data.weather or ''),
            num(data.transition, 15) * 1.0, data.frozen and true or false,
            data.snow and true or false)
    elseif action == 'resetWeather' then
        TriggerServerEvent('weathersync:resetWeather')
    elseif action == 'time' then
        TriggerServerEvent('weathersync:setTime',
            math.floor(num(data.day, 0)), math.floor(num(data.hour, 0)),
            math.floor(num(data.minute, 0)), 0, 0, data.frozen and true or false)
    elseif action == 'resetTime' then
        TriggerServerEvent('weathersync:resetTime')
    elseif action == 'wind' then
        TriggerServerEvent('weathersync:setWind',
            num(data.direction, 0) * 1.0, num(data.speed, 0) * 1.0,
            data.frozen and true or false)
    elseif action == 'resetWind' then
        TriggerServerEvent('weathersync:resetWind')
    elseif action == 'timescale' then
        TriggerServerEvent('weathersync:setTimescale', num(data.scale, 0) * 1.0)
    elseif action == 'resetTimescale' then
        TriggerServerEvent('weathersync:resetTimescale')
    elseif action == 'syncDelay' then
        TriggerServerEvent('weathersync:setSyncDelay', math.floor(num(data.delay, 0)))
    elseif action == 'resetSyncDelay' then
        TriggerServerEvent('weathersync:resetSyncDelay')
    else
        return
    end

    -- read the new state straight back so the readouts do not wait for the tick
    TriggerServerEvent('weathersync:requestUpdatedAdminUi')
end)
RegisterNUICallback('panelEvents', function(_, cb)
    cb('ok')
    CreateThread(function()
        pushToPanel('events', Core.Callback.TriggerAwait('vorp_admin:Callback:eventsSnapshot'))
    end)
end)

RegisterNUICallback('panelEventsAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local action = tostring(data.action or '')

    if action == 'force' then
        TriggerServerEvent('vorp_admin:events:force', tostring(data.key or ''), tostring(data.mode or ''))
    elseif action == 'window' then
        TriggerServerEvent('vorp_admin:events:setWindow', tostring(data.key or ''),
            tostring(data.from or ''), tostring(data.to or ''),
            tonumber(data.hourFrom), tonumber(data.hourTo))
    elseif action == 'hour' then
        TriggerServerEvent('vorp_admin:events:setHour', tonumber(data.hour))
    else
        return
    end

    -- repaint from the server rather than guessing what changed
    CreateThread(function()
        Wait(400)
        pushToPanel('events', Core.Callback.TriggerAwait('vorp_admin:Callback:eventsSnapshot'))
    end)
end)

-- Anti-Cheat page
RegisterNUICallback('panelSecurity', function(_, cb)
    cb('ok')
    CreateThread(function()
        pushToPanel('security', Core.Callback.TriggerAwait('vorp_admin:Callback:getFlags'))
    end)
end)

-- bans & whitelist page (works on OFFLINE ids - same events as the in-world menus)
RegisterNUICallback('panelBans', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local action = tostring(data.action or '')
    if action == 'banoffline' then
        local staticid = tonumber(data.staticid)
        local time = tostring(data.time or '')
        if staticid and time:match('^%d+[dwmy]$') then
            TriggerServerEvent('vorp_admin:BanOffline', staticid, time, 'vorp.staff.Ban')
        end
    elseif action == 'unban' then
        local staticid = tonumber(data.staticid)
        if staticid then
            -- NOTE: the server event is "Unban" (server.lua), not "UnBan"
            TriggerServerEvent('vorp_admin:Unban', staticid, 'vorp.staff.Unban')
        end
    elseif action == 'whitelist' then
        local steam = tostring(data.steam or '')
        if steam ~= '' then
            TriggerServerEvent('vorp_admin:Whitelistoffline', steam, data.add and 'whiteList' or 'unwhiteList')
        end
    end
end)

-- tools/teleports: the SAME client globals + server events the pup-ui dashboard main tab fires (boosters.lua)
RegisterNUICallback('panelTool', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local id = tostring(data.id or '')

    if id == 'godmode' then
        if IsAdminAllowed('godmode') then GODmode() end
    elseif id == 'invisible' then
        if IsAdminAllowed('invisibility') then ToggleInvisible() end
    elseif id == 'noclip' then
        if not IsAdminAllowed('noclip') then return end
        closePanel()
        ToggleNoClip()
    elseif id == 'infiammo' then
        if IsAdminAllowed('infinite_ammo') then InfiAmmo() end
    elseif id == 'goldencores' then
        if IsAdminAllowed('golden_cores') then GoldenCores() end
    elseif id == 'healself' then
        if not IsAdminAllowed('selfheal') then return end
        SelfHeal()
    elseif id == 'reviveself' then
        -- also checked server side (server.lua); this only hides the failure
        if not IsAdminAllowed('selfrevive') then return end
        TriggerServerEvent('vorp_admin:ReviveSelf', 'selfrevive')
    elseif id == 'devlaser' then
        if not IsAdminAllowed('devtools_menu') then return end
        closePanel()
        ToggleDevLaser()
    elseif id == 'pedmenu' then
        if not IsAdminAllowed('ped_menu') then return end
        -- the ped list is a pup-ui menu, so the panel has to let go of the screen
        closePanel()
        if BuildPedRoot then PupMenu.Open(BuildPedRoot()) end
    elseif id == 'stableadmin' then
        if not IsAdminAllowed('stable_admin') then return end
        closePanel()
        if BuildStableAdminRoot then
            local root = BuildStableAdminRoot()
            if root then PupMenu.Open(root) end
        end
    elseif id == 'placeprop' then
        -- prop placer: pup-ui's placement gizmo (see dashboard.lua PlaceProp)
        if not IsAdminAllowed('devtools_menu') then return end
        local model = tostring(data.model or '')
        if model == '' then model = LastPlaceModel end
        if model and model ~= '' then
            closePanel()
            PlaceProp(model)
        else
            TriggerEvent('vorp:TipRight', 'Enter a prop model first.', 3000)
        end
    elseif id == 'placepropgizmo' then
        -- same tool, vorp_lib's drag gizmo instead of the crosshair raycast: this one can set pitch and roll, not just a heading
        if not IsAdminAllowed('devtools_menu') then return end
        local model = tostring(data.model or '')
        if model == '' then model = LastPlaceModel end
        if model and model ~= '' then
            closePanel()
            PlacePropGizmo(model)
        else
            TriggerEvent('vorp:TipRight', 'Enter a prop model first.', 3000)
        end
    elseif id == 'spawnhorse' then
        if not IsAdminAllowed('spawn_horse') then return end
        local model = tostring(data.model or '')
        if model ~= '' then closePanel() SpawnHorseModel(model) end
    elseif id == 'spawnwagon' then
        if not IsAdminAllowed('spawn_wagon') then return end
        local model = tostring(data.model or '')
        if model ~= '' then closePanel() SpawnWagonModel(model) end
    elseif id == 'spawnanimal' then
        -- no dedicated key exists; an animal spawn is gated as a horse spawn
        if not IsAdminAllowed('spawn_horse') then return end
        -- panel STAYS OPEN: you are not being put on the animal, and spawning a few in a row is the normal case
        local model = tostring(data.model or '')
        if model ~= '' then SpawnAnimalModel(model) end
    elseif id == 'announce' then
        -- also checked server side (server.lua)
        if not IsAdminAllowed('allow_announce') then return end
        local text = tostring(data.text or '')
        if text ~= '' then TriggerServerEvent('vorp_admin:announce', text) end
    elseif id == 'tpwaypoint' then
        if not IsAdminAllowed('tp_to_waypoint') then return end
        closePanel()
        TpToWaypoint()
    elseif id == 'autotpm' then
        if not IsAdminAllowed('tp_to_waypoint') then return end
        ToggleAutoTPM()
    elseif id == 'tpback' then
        if not IsAdminAllowed('tp_player_back') then return end
        closePanel()
        TriggerServerEvent('vorp_admin:sendAdminBack')
    elseif id == 'guarma' then
        if not IsAdminAllowed('teleport_to_guarma') then return end
        closePanel()
        ToggleGuarma()
    elseif id == 'tpcoords' then
        if not IsAdminAllowed('tp_to_coords') then return end
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        local h = tonumber(data.h)
        if x and y and z then
            closePanel()
            TeleportToCoords(x, y, z)
            -- optional: face a direction on arrival, so a saved vector4 lands exactly
            if h then SetEntityHeading(PlayerPedId(), h + 0.0) end
        end

    -- ZONE CREATOR: drives PolyZone's own creation flow. Its events are client
    -- side and fire across resources, so nothing in PolyZone has to change.
    elseif id == 'pzcreate' then
        if not IsAdminAllowed('devtools_menu') then return end
        if GetResourceState('PolyZone') ~= 'started' then
            return TriggerEvent('vorp:TipRight', 'PolyZone is not running.', 4000)
        end
        local kind = tostring(data.kind or '')
        if kind ~= 'poly' and kind ~= 'box' and kind ~= 'circle' then return end
        -- spaces would split into extra command args on PolyZone's side
        local zname = tostring(data.zname or ''):gsub('%s+', '_')
        if zname == '' then
            return TriggerEvent('vorp:TipRight', 'Name the zone first.', 3000)
        end
        -- PolyZone reads the sizes out of the command arg list, and asks on screen
        -- for anything missing; passing them here skips that keyboard prompt
        local args = { kind, zname }
        if kind == 'circle' then
            args[3] = tostring(tonumber(data.a) or 10.0)
        elseif kind == 'box' then
            args[3] = tostring(tonumber(data.a) or 10.0)
            args[4] = tostring(tonumber(data.b) or 10.0)
        end
        closePanel()
        TriggerEvent('polyzone:pzcreate', kind, zname, args)
    elseif id == 'pzadd' or id == 'pzundo' or id == 'pzfinish'
        or id == 'pzcancel' or id == 'pzlast' or id == 'pzcomboinfo' then
        if not IsAdminAllowed('devtools_menu') then return end
        if GetResourceState('PolyZone') ~= 'started' then return end
        -- finishing or cancelling from the panel means the shape is done with, so
        -- there is nothing left to walk around and look at
        if id == 'pzfinish' or id == 'pzcancel' then closePanel() end
        TriggerEvent('polyzone:' .. id)
    end
end)

-- items DB editor: reuses the existing dashboard callbacks/events verbatim (browse gated on open_menu)
RegisterNUICallback('panelItemsSearch', function(data, cb)
    cb('ok')
    local term = type(data) == 'table' and tostring(data.term or '') or ''
    local page = type(data) == 'table' and tonumber(data.page) or 0
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:itemsSearch', { term = term, page = page })
        pushToPanel('items', payload or false)
    end)
end)

-- autocomplete feed for "give item" inputs: same search callback as the Items DB page
RegisterNUICallback('panelPropSuggest', function(data, cb)
    cb('ok')
    local term = type(data) == 'table' and tostring(data.term or '') or ''
    if term == '' then return end
    term = term:lower()

    local rows, exact = {}, {}
    for i = 1, #(Props or {}) do
        local name = Props[i]
        local lower = name:lower()
        if lower == term then
            exact[#exact + 1] = name
        elseif lower:find(term, 1, true) then
            rows[#rows + 1] = name
            if #rows >= 60 then break end -- plenty to rank; the UI shows 10
        end
    end

    -- names that START with what was typed are what you meant far more often than ones that merely contain it somewhere
    table.sort(rows, function(a, b)
        local sa = a:lower():sub(1, #term) == term
        local sb = b:lower():sub(1, #term) == term
        if sa ~= sb then return sa end
        if #a ~= #b then return #a < #b end
        return a < b
    end)
    for i = 1, #rows do exact[#exact + 1] = rows[i] end

    pushToPanel('propSuggest', { rows = exact })
end)

RegisterNUICallback('panelItemSuggest', function(data, cb)
    cb('ok')
    local term = type(data) == 'table' and tostring(data.term or '') or ''
    if term == '' then return end
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:itemsSearch', { term = term })
        pushToPanel('itemSuggest', payload or false)
    end)
end)

-- gang management (pup-gangs bridge)
local function pushGangs()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelGangs')
        pushToPanel('gangs', payload or false)
    end)
end

RegisterNUICallback('panelGangs', function(_, cb)
    cb('ok')
    pushGangs()
end)

RegisterNUICallback('panelGangAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:gang:action', data)
    SetTimeout(700, pushGangs)
end)

RegisterNUICallback('panelGangReset', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:gang:reset', data)
    SetTimeout(900, pushGangs)
end)

-- perk management (pup-perks bridge; server gates with manage_perks)
local perkSearch = ''

local function pushPerks()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelPerks', perkSearch)
        pushToPanel('perks', payload or false)
    end)
end

RegisterNUICallback('panelPerks', function(data, cb)
    cb('ok')
    if type(data) == 'table' and data.search ~= nil then
        perkSearch = tostring(data.search or '')
    end
    pushPerks()
end)

RegisterNUICallback('panelPerkDetail', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or not data.charid then return end
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelPerkDetail', tonumber(data.charid))
        pushToPanel('perkDetail', payload or false)
    end)
end)

RegisterNUICallback('panelPerkAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:perks:action', data)
    -- the mutation lands server-side, so give it a beat before re-reading both the list and the open detail view
    SetTimeout(700, function()
        pushPerks()
        if data.charid then
            CreateThread(function()
                local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelPerkDetail', tonumber(data.charid))
                pushToPanel('perkDetail', payload or false)
            end)
        end
    end)
end)

-- stores management (player shops; server gates with manage_stores)
local function pushStores()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelStores')
        pushToPanel('stores', payload or false)
    end)
end

RegisterNUICallback('panelStores', function(_, cb)
    cb('ok')
    pushStores()
end)

RegisterNUICallback('panelStoreAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:store:action', data)
    SetTimeout(700, pushStores)
end)

-- move a shop to where the admin is standing; the panel has no world access
RegisterNUICallback('panelStoreMoveHere', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('vorp_admin:store:action', {
        id = data.id, action = 'move',
        value = { x = c.x, y = c.y, z = c.z },
    })
    SetTimeout(700, pushStores)
end)

-- what the shop is holding; the panel asks when the detail opens
RegisterNUICallback('panelStoreStock', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local id = data.id
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelStoreStock', id)
        pushToPanel('storeStock', { id = id, stock = payload or false })
    end)
end)

-- open the shop's real stock grid. The panel closes first so the inventory
-- window can take the focus; the server checks the permission again.
RegisterNUICallback('panelStoreOpenStock', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    closePanel()
    SetTimeout(200, function()
        TriggerServerEvent('vorp_admin:store:openStock', id)
    end)
end)

-- stand the admin at the shop. The panel has no world access, so the coords
-- come back from the list it was already given.
RegisterNUICallback('panelStoreGoto', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or type(data.coords) ~= 'table' then return end
    local x, y, z = tonumber(data.coords.x), tonumber(data.coords.y), tonumber(data.coords.z)
    if not x or not y or not z then return end
    closePanel()
    SetTimeout(200, function()
        -- SetEntityCoords, not the NoOffset form: that one places by the centre and buries you
        SetEntityCoords(PlayerPedId(), x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
        TriggerServerEvent('vorp_admin:store:goto', data.id)
    end)
end)

-- the panel's door into the remaining IN-WORLD admin tools (creation flows)
RegisterNUICallback('panelOpenTool', function(data, cb)
    cb('ok')
    local TOOLS <const> = {
        housing = 'pup_realestate:openCreation', -- door CAPTURE only; everything else is panel-native
        society = 'pup_business:openAdminTool',
        ranch   = 'pup_ranchero:openAdminTool',
    }
    local ev = TOOLS[type(data) == 'table' and tostring(data.tool or '') or '']
    if not ev then return end
    closePanel()
    SetTimeout(0, function() TriggerEvent(ev) end)
end)

-- ranch management (pup-ranch bridge; server gates with manage_ranch)
local function pushRanches()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelRanches')
        pushToPanel('ranches', payload or false)
    end)
end

RegisterNUICallback('panelRanches', function(_, cb)
    cb('ok')
    pushRanches()
end)

RegisterNUICallback('panelRanchAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:ranch:action', data)
    SetTimeout(700, pushRanches)
end)

-- society management (pup-societies bridge; server gates with manage_society)
local function pushSociety()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelSociety')
        pushToPanel('society', payload or false)
    end)
end

RegisterNUICallback('panelSociety', function(_, cb)
    cb('ok')
    pushSociety()
end)

RegisterNUICallback('panelSocietyShops', function(data, cb)
    cb('ok')
    local job = type(data) == 'table' and tostring(data.job or '') or ''
    if job == '' then return end
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelSocietyShops', { job = job })
        pushToPanel('societyShops', { job = job, data = payload or false })
    end)
end)

-- open the business stash. The panel closes first so the inventory window can
-- take the focus; the server checks manage_society again.
RegisterNUICallback('panelSocietyOpenStash', function(data, cb)
    cb('ok')
    local job = type(data) == 'table' and tostring(data.job or '') or ''
    if job == '' then return end
    closePanel()
    SetTimeout(200, function()
        TriggerServerEvent('vorp_admin:society:openStash', job)
    end)
end)

-- actions fire pup-societies' OWN admin events (server re-gates every one via isSocietyAdmin)
RegisterNUICallback('panelSocietyAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local action = tostring(data.action or '')
    local job = tostring(data.job or '')

    if action == 'create' and job ~= '' then
        -- no blip point on create: only a job menu point at the admin's spot
        local p = GetEntityCoords(PlayerPedId())
        local here = { x = p.x, y = p.y, z = p.z }
        TriggerServerEvent('pup_business:admin:create', {
            job       = job,
            name      = (data.name ~= nil and data.name ~= '') and tostring(data.name) or job,
            bossrank  = tonumber(data.bossrank) or 1,
            positions = {},
            jobmenu   = { here },
        })
    elseif action == 'points' and job ~= '' then
        -- positions / jobmenu management: NUI sends the desired list; 'addhere' appends the admin's current spot
        local key = data.key == 'jobmenu' and 'jobmenu' or 'positions'
        local list = {}
        for _, pt in ipairs(type(data.points) == 'table' and data.points or {}) do
            local x, y, z = tonumber(pt.x), tonumber(pt.y), tonumber(pt.z)
            if x and y and z then list[#list + 1] = { x = x, y = y, z = z } end
        end
        if data.addhere then
            local p = GetEntityCoords(PlayerPedId())
            list[#list + 1] = { x = p.x, y = p.y, z = p.z }
        end
        TriggerServerEvent('pup_business:admin:update', job, { [key] = list })
    elseif action == 'update' and job ~= '' and type(data.changes) == 'table' then
        -- whitelist the settable keys; positions/jobmenu stay in-world
        local ALLOWED <const> = {
            name = true, containername = true, blipsprite = true, showblip = true,
            billing = true, webhook = true, salary = true, tax = true,
            recruitmentrank = true, bossrank = true,
        }
        local changes = {}
        for k, v in pairs(data.changes) do
            if ALLOWED[k] then changes[k] = v end
        end
        if next(changes) then
            TriggerServerEvent('pup_business:admin:update', job, changes)
        end
    elseif action == 'setslots' and job ~= '' then
        -- the society stash's PURCHASED slots; pup_business re-registers the container
        local n = tonumber(data.value)
        if n then TriggerServerEvent('vorp_admin:society:setSlots', job, math.floor(n)) end
    elseif action == 'setmailhandle' and job ~= '' then
        -- the business PO address; pup_postoffice validates the format and uniqueness
        local handle = tostring(data.handle or '')
        if handle ~= '' then
            TriggerServerEvent('vorp_admin:society:setMailHandle', job, handle)
        end
    elseif action == 'clear' and job ~= '' then
        -- hand a business over clean: empty the storage, or drop its shop fronts
        local kind = tostring(data.kind or '')
        if kind == 'stash' or kind == 'shops' then
            TriggerServerEvent('pup_business:admin:clear', job, kind)
            SetTimeout(700, function()
                TriggerServerEvent('pup_business:admin:shops', job)
            end)
        end
    elseif action == 'delete' and job ~= '' then
        TriggerServerEvent('pup_business:admin:delete', job)
    elseif action == 'hire' and job ~= '' then
        local sid = tonumber(data.serverId)
        if sid then TriggerServerEvent('pup_business:hire', math.floor(sid), job) end
    elseif action == 'fire' then
        local charid = tonumber(data.charid)
        if charid then TriggerServerEvent('pup_business:fire', charid, job ~= '' and job or nil) end
    elseif action == 'setrank' and job ~= '' then
        local grade, charid = tonumber(data.grade), tonumber(data.charid)
        if grade and charid then
            TriggerServerEvent('pup_business:admin:setSelfRank', job, grade, charid)
        end
    elseif action == 'shop' and job ~= '' then
        local shopId = tonumber(data.shopId)
        local act = tostring(data.act or '')
        local SHOP_ACTS <const> = { rename = true, rank = true, delete = true, blip = true, disable = true, price = true, move = true, slots = true }
        if shopId and SHOP_ACTS[act] then
            local value = data.value
            -- "Move Here" - the coordinates are filled in HERE, not in the page.
            -- pup_mercantile refuses bad coords ('badcoords') or a spot too close to
            -- another shop ('tooclose'). Both already report back to the admin.
            if act == 'move' then
                local c = GetEntityCoords(PlayerPedId())
                value = { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
            end
            TriggerServerEvent('pup_business:admin:shopAction', job, shopId, act, value)
        end
    end
    SetTimeout(800, pushSociety)
end)

-- housing management (pup-housing bridge; server gates with manage_housing)
local function pushHousing()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelHousing')
        pushToPanel('housing', payload or false)
    end)
end

RegisterNUICallback('panelHousing', function(_, cb)
    cb('ok')
    pushHousing()
end)

RegisterNUICallback('panelHousingAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:housing:action', data)
    SetTimeout(700, pushHousing)
end)

-- auctions are pure server events in pup-housing (no in-world part) - fire them directly
RegisterNUICallback('panelHousingAuction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    if data.act == 'create' then
        local minbid, hours = tonumber(data.minbid), tonumber(data.hours)
        if minbid and minbid >= 0 and hours and hours > 0 then
            TriggerServerEvent('pup_realestate:auctionCreate', id, minbid, hours)
        end
    elseif data.act == 'cancel' then
        -- auctionCancel wants the AUCTION id, not the house id
        local aucid = tonumber(data.aucid)
        if not aucid then return end
        TriggerServerEvent('pup_realestate:auctionCancel', aucid)
    end
    SetTimeout(800, pushHousing)
end)

-- open the house's real storage container. The panel closes first so the
-- inventory window can take the focus; the server checks manage_housing again.
RegisterNUICallback('panelHousingOpenStorage', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    closePanel()
    SetTimeout(200, function()
        TriggerServerEvent('vorp_admin:housing:openStorage', id)
    end)
end)

-- banks (pup-bank bridge; server gates with manage_bank)
local function pushBanks()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelBanks')
        pushToPanel('banks', payload or false)
    end)
end

RegisterNUICallback('panelBanks', function(_, cb)
    cb('ok')
    pushBanks()
end)

RegisterNUICallback('panelBankAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:bank:action', data)
    SetTimeout(700, pushBanks)
end)

-- hideouts (pup_hideouts bridge; server gates with manage_hideouts)
local function pushHideouts()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelHideouts')
        pushToPanel('hideouts', payload or false)
    end)
end

RegisterNUICallback('panelHideouts', function(_, cb)
    cb('ok')
    pushHideouts()
end)

RegisterNUICallback('panelHideoutAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:hideout:action', data)
    SetTimeout(700, pushHideouts)
end)

-- open the hideout's real stash panel. The panel closes first so the inventory
-- window can take the focus; the server checks manage_hideouts again.
RegisterNUICallback('panelHideoutOpenStash', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    closePanel()
    SetTimeout(200, function()
        TriggerServerEvent('vorp_admin:hideout:openStash', id)
    end)
end)

-- teleport to a hideout entrance
RegisterNUICallback('panelHideoutGoto', function(data, cb)
    cb('ok')
    local x, y, z = tonumber(data and data.x), tonumber(data and data.y), tonumber(data and data.z)
    if not x or not y or not z then return end
    closePanel()
    TeleportToCoords(x + 0.0, y + 0.0, z + 0.0)
end)

-- curses (pup_shaman bridge; server gates with manage_curses)
local function pushCurses()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelCurses')
        pushToPanel('curses', payload or false)
    end)
end

RegisterNUICallback('panelCurses', function(_, cb)
    cb('ok')
    pushCurses()
end)

RegisterNUICallback('panelCurseAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:curse:action', data)
    SetTimeout(700, pushCurses)
end)

-- farms (pup_homestead bridge; server gates with manage_farms)
local function pushFarms()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelFarms')
        pushToPanel('farms', payload or false)
    end)
end

RegisterNUICallback('panelFarms', function(_, cb)
    cb('ok')
    pushFarms()
end)

RegisterNUICallback('panelFarmAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:farm:action', data)
    SetTimeout(700, pushFarms)
end)

-- camps (pup_camps bridge; server gates with manage_camps)
local function pushCamps()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelCamps')
        pushToPanel('camps', payload or false)
    end)
end

RegisterNUICallback('panelCamps', function(_, cb)
    cb('ok')
    pushCamps()
end)

RegisterNUICallback('panelCampAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:camp:action', data)
    SetTimeout(700, pushCamps)
end)

-- open the camp's real stash panel. The panel closes first so the inventory
-- window can take the focus; the server checks manage_camps again.
RegisterNUICallback('panelCampOpenStash', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    closePanel()
    SetTimeout(200, function()
        TriggerServerEvent('vorp_admin:camp:openStash', id)
    end)
end)

-- teleport to a camp
RegisterNUICallback('panelCampGoto', function(data, cb)
    cb('ok')
    local x, y, z = tonumber(data and data.x), tonumber(data and data.y), tonumber(data and data.z)
    if not x or not y or not z then return end
    closePanel()
    TeleportToCoords(x + 0.0, y + 0.0, z + 0.0)
end)

-- world props (pup-props bridge)
local function pushProps()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:panelProps')
        pushToPanel('props', payload or false)
    end)
end

RegisterNUICallback('panelProps', function(_, cb)
    cb('ok')
    pushProps()
end)

RegisterNUICallback('panelPropDelete', function(data, cb)
    cb('ok')
    local id = tonumber(data and data.id)
    if not id then return end
    TriggerServerEvent('vorp_admin:prop:delete', id)
    SetTimeout(700, pushProps)
end)

RegisterNUICallback('panelPropGoto', function(data, cb)
    cb('ok')
    local x, y, z = tonumber(data and data.x), tonumber(data and data.y), tonumber(data and data.z)
    if not x or not y or not z then return end
    closePanel()
    TeleportToCoords(x + 0.0, y + 0.0, z + 0.0)
end)

-- consumables manager (fred_metabolism bridge)
local function pushConsumables()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:consumablesList')
        pushToPanel('consumables', payload or false)
    end)
end

RegisterNUICallback('panelConsumables', function(_, cb)
    cb('ok')
    pushConsumables()
end)

RegisterNUICallback('panelConsumableSave', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:consumables:save', data)
    SetTimeout(700, pushConsumables) -- refresh the list with the saved entry
end)

RegisterNUICallback('panelConsumableDelete', function(data, cb)
    cb('ok')
    local name = type(data) == 'table' and tostring(data.name or '') or ''
    if name == '' then return end
    TriggerServerEvent('vorp_admin:consumables:delete', name)
    SetTimeout(700, pushConsumables)
end)

-- smokes manager (pup-misc/smokes bridge)
local function pushSmokes()
    TriggerServerEvent('vorp_admin:smokes:list')
end

RegisterNUICallback('panelSmokes', function(_, cb)
    cb('ok')
    pushSmokes()
end)

RegisterNUICallback('panelSmokeSave', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:smokes:save', data)
    SetTimeout(700, pushSmokes)
end)

RegisterNUICallback('panelSmokeDelete', function(data, cb)
    cb('ok')
    local name = type(data) == 'table' and tostring(data.name or '') or ''
    if name == '' then return end
    TriggerServerEvent('vorp_admin:smokes:delete', name)
    SetTimeout(700, pushSmokes)
end)

RegisterNetEvent('vorp_admin:smokes:recv', function(list)
    pushToPanel('smokes', list or {})
end)

-- crafting recipe manager (pup-crafting bridge)
local function pushCraftRecipes()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:craftRecipesList')
        pushToPanel('craftRecipes', payload or false)
    end)
end

RegisterNUICallback('panelCraftRecipes', function(_, cb)
    cb('ok')
    pushCraftRecipes()
end)

RegisterNUICallback('panelCraftSave', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:craft:save', data)
    SetTimeout(800, pushCraftRecipes)
end)

RegisterNUICallback('panelCraftSetEnabled', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:craft:setEnabled', tonumber(data.id), data.enabled and true or false)
    SetTimeout(800, pushCraftRecipes)
end)

-- crafting LOCATIONS
local function pushCraftLocations()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:craftLocationsList')
        pushToPanel('craftLocations', payload or false)
    end)
end

RegisterNUICallback('panelCraftLocations', function(_, cb)
    cb('ok')
    pushCraftLocations()
end)

RegisterNUICallback('panelCraftMyPos', function(_, cb)
    -- hand the admin's own world position back to the editor
    local c = GetEntityCoords(PlayerPedId())
    cb({ x = c.x, y = c.y, z = c.z })
end)

-- item autocomplete for the recipe editors: results come back as a push so the NUI callback itself never has to yield
RegisterNUICallback('panelItemSearch', function(data, cb)
    cb('ok')
    local q = tostring(data and data.q or '')
    local seq = tonumber(data and data.seq) or 0
    CreateThread(function()
        local rows = Core.Callback.TriggerAwait('vorp_admin:Callback:craftItemSearch', q)
        pushToPanel('itemSearch', { q = q, seq = seq, rows = rows or {} })
    end)
end)

-- charid -> name lookup for the character-lock editor. intent 'add' = the admin typed an id to add
RegisterNUICallback('panelCraftCharLookup', function(data, cb)
    cb('ok')
    local charid = tonumber(data and data.charid)
    local intent = tostring(data and data.intent or 'add')
    if not charid then return end
    CreateThread(function()
        local info = Core.Callback.TriggerAwait('vorp_admin:Callback:craftCharLookup', charid)
        pushToPanel('craftCharInfo', { charid = charid, intent = intent, info = info or false })
    end)
end)

-- WEAPON CRAFTING STATIONS
local function pushWeaponCraftLocs()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:weaponCraftLocations')
        pushToPanel('weaponCraftLocations', payload or false)
    end)
end

RegisterNUICallback('panelWeaponCraftLocations', function(_, cb)
    cb('ok')
    pushWeaponCraftLocs()
end)

RegisterNUICallback('panelWeaponCraftLocAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:weaponCraft:location', data)
    SetTimeout(900, pushWeaponCraftLocs)
end)

-- DOOR LOCKS
local doorSearch = ''

local function pushDoorLocks()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:doorLocks', doorSearch)
        pushToPanel('doorLocks', payload or false)
    end)
end

RegisterNUICallback('panelDoorLocks', function(data, cb)
    cb('ok')
    doorSearch = (type(data) == 'table' and tostring(data.search or '')) or ''
    pushDoorLocks()
end)

RegisterNUICallback('panelDoorLockAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:doorlocks:action', data)
    SetTimeout(900, pushDoorLocks)
end)

-- closes the panel first, the same as every other teleport out of it
RegisterNUICallback('panelDoorGoto', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    if not IsAdminAllowed('tp_to_coords') then return end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not (x and y and z) then return end
    closePanel()
    TeleportToCoords(x, y, z)
end)

-- SERVER BANS
local function pushBans(search, showLifted)
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:bansList', search, showLifted)
        pushToPanel('serverBans', payload or false)
    end)
end

RegisterNUICallback('panelServerBans', function(data, cb)
    cb('ok')
    pushBans(tostring(data and data.search or ''), data and data.showLifted and true or false)
end)

RegisterNUICallback('panelBanUnban', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:bans:unban', tostring(data.banId or ''))
    SetTimeout(900, function() pushBans(tostring(data.search or ''), data.showLifted and true or false) end)
end)

RegisterNUICallback('panelBanLookup', function(data, cb)
    cb('ok')
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:banLookup', tostring(data and data.term or ''))
        pushToPanel('banLookup', payload or false)
    end)
end)

RegisterNUICallback('panelBanIssue', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:bans:banLookup', data)
    SetTimeout(1200, function() pushBans('', false) end)
end)

RegisterNUICallback('panelBanPlayer', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:bans:ban', tonumber(data.target), tostring(data.reason or ''), tonumber(data.seconds) or 0)
    SetTimeout(1200, function() pushBans('', false) end)
end)

-- what a respawn took off players, and the button that gives it back
local function pushDeathLosses(charid)
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:deathLossesList', charid)
        pushToPanel('deathLosses', payload or false)
    end)
end

RegisterNUICallback('panelDeaths', function(data, cb)
    cb('ok')
    pushDeathLosses(tonumber(data and data.charid))
end)

RegisterNUICallback('panelDeathRestore', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:deaths:restore', tonumber(data.id))
    SetTimeout(900, function() pushDeathLosses(nil) end)
end)

-- steam hex -> steam name + the characters on that account, for migrating a legacy lock
RegisterNUICallback('panelCraftSteamLookup', function(data, cb)
    cb('ok')
    local hex = tostring(data and data.hex or '')
    if hex == '' then return end
    CreateThread(function()
        local info = Core.Callback.TriggerAwait('vorp_admin:Callback:craftSteamLookup', hex)
        pushToPanel('craftSteamInfo', { hex = hex, info = info or false })
    end)
end)

RegisterNUICallback('panelCraftSaveLocation', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:craft:saveLocation', data)
    SetTimeout(800, pushCraftLocations)
end)

RegisterNUICallback('panelCraftSetLocationEnabled', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:craft:setLocationEnabled', tostring(data.name), data.enabled and true or false)
    SetTimeout(800, pushCraftLocations)
end)

-- weapon crafting recipe manager (pup-weapons bridge)
local function pushWeaponRecipes()
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:weaponRecipesList')
        pushToPanel('weaponRecipes', payload or false)
    end)
end

RegisterNUICallback('panelWeaponRecipes', function(_, cb)
    cb('ok')
    pushWeaponRecipes()
end)

RegisterNUICallback('panelWeaponSave', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:weapon:save', data)
    SetTimeout(800, pushWeaponRecipes)
end)

RegisterNUICallback('panelWeaponSetEnabled', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:weapon:setEnabled', tonumber(data.id), data.enabled and true or false)
    SetTimeout(800, pushWeaponRecipes)
end)

RegisterNUICallback('panelItemsGet', function(data, cb)
    cb('ok')
    local item = type(data) == 'table' and tostring(data.item or '') or ''
    if item == '' then return end
    CreateThread(function()
        local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:itemsGet', { item = item })
        pushToPanel('itemDetail', payload or false)
    end)
end)

RegisterNUICallback('panelItemsUpdate', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local item = tostring(data.item or '')
    if item == '' then return end
    if data.delete then
        TriggerServerEvent('vorp_admin:items:update', item, 'delete')
    else
        local col = tostring(data.col or '')
        if col == '' then return end
        TriggerServerEvent('vorp_admin:items:update', item, col, tostring(data.value or ''))
    end
end)

-- new item row
RegisterNUICallback('panelItemsCreate', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    TriggerServerEvent('vorp_admin:items:create', {
        item   = tostring(data.item or ''),
        label  = tostring(data.label or ''),
        limit  = tonumber(data.limit) or 10,
        weight = tonumber(data.weight) or 0,
        usable = data.usable and 1 or 0,
        type   = tostring(data.type or 'item_standard'),
        desc   = tostring(data.desc or ''),
    })
    -- give the insert a moment, then refresh the list so the new row shows
    SetTimeout(600, function()
        CreateThread(function()
            local payload = Core.Callback.TriggerAwait('vorp_admin:Callback:itemsSearch',
                { term = tostring(data.item or ''), page = 0 })
            pushToPanel('items', payload or false)
        end)
    end)
end)

-- ADMIN OVERLAYS: player IDs (name / id / health above every player) and player blips (everyone on the map)
local showPlayerIds = false
local showPlayerBlips = false
local playerBlips = {} -- [serverId] = blip handle

local function overlayText3D(x, y, z, text)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    local str = CreateVarString(10, 'LITERAL_STRING', text, Citizen.ResultAsLong())
    SetTextScale(0.32, 0.32)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 255, 255, 220)
    SetTextCentre(1)
    DisplayText(str, sx, sy)
    local factor = (#text) / 225
    DrawSprite('feeds', 'hud_menu_4a', sx, sy + 0.0125, 0.015 + factor, 0.03, 0.1, 25, 25, 25, 200, 0)
end

CreateThread(function()
    while true do
        if not showPlayerIds then
            Wait(500)
        else
            Wait(0)
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            for _, plyr in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(plyr)
                -- SELF INCLUDED (txAdmin behaviour) - your own tag shows over your head in third person
                if ped and ped ~= 0 and DoesEntityExist(ped) then
                    local c = GetEntityCoords(ped)
                    local dist = #(myCoords - c)
                    if dist < 60.0 then
                        local sid = GetPlayerServerId(plyr)
                        local hp = math.floor(GetEntityHealth(ped) or 0)
                        -- anchor on the HEAD BONE, not entity coords + a guessed offset - entity coords sit at the FEET
                        local hx, hy, hz = table.unpack(GetPedBoneCoords(ped, 0x796E, 0.0, 0.0, 0.0))
                        if not hz or hz == 0.0 then
                            hx, hy, hz = c.x, c.y, c.z + 1.0
                        end
                        overlayText3D(hx, hy, hz + 0.28,
                            ('[%d] %s  HP %d'):format(sid, GetPlayerName(plyr) or '?', hp))
                    end
                end
            end
        end
    end
end)

local function clearPlayerBlips()
    for sid, blip in pairs(playerBlips) do
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
        playerBlips[sid] = nil
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        if showPlayerBlips then
            local seen = {}
            for _, plyr in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(plyr)
                local sid = GetPlayerServerId(plyr)
                -- SELF INCLUDED - your own labelled blip shows on the map too (txAdmin behaviour)
                if ped and ped ~= 0 and DoesEntityExist(ped) then
                    seen[sid] = true
                    if not playerBlips[sid] or not DoesBlipExist(playerBlips[sid]) then
                        -- PLAYER sprite from Config.LiveMap (default blip_player)
                        local sprite = joaat(Config.LiveMap.playerBlipSprite or 'blip_player')
                        local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, sprite, ped)
                        if blip and blip ~= 0 then
                            pcall(function() SetBlipSprite(blip, sprite, 1) end)
                            pcall(function() SetBlipScale(blip, 0.85) end)
                            Citizen.InvokeNative(0x9CB1A1623062F402, blip,
                                CreateVarString(10, 'LITERAL_STRING', ('[%d] %s'):format(sid, GetPlayerName(plyr) or '?')))
                            playerBlips[sid] = blip
                        end
                    end
                end
            end
            -- drop blips of players who left / went out of scope
            for sid, blip in pairs(playerBlips) do
                if not seen[sid] then
                    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
                    playerBlips[sid] = nil
                end
            end
        elseif next(playerBlips) then
            clearPlayerBlips()
        end
    end
end)

RegisterNUICallback('panelOverlay', function(data, cb)
    local which = type(data) == 'table' and tostring(data.which or '') or ''
    if which == 'ids' then
        showPlayerIds = not showPlayerIds
        Core.NotifyRightTip(('Player IDs %s'):format(showPlayerIds and 'ON' or 'OFF'), 3000)
    elseif which == 'blips' then
        showPlayerBlips = not showPlayerBlips
        if not showPlayerBlips then clearPlayerBlips() end
        Core.NotifyRightTip(('Player blips %s'):format(showPlayerBlips and 'ON' or 'OFF'), 3000)
    end
    cb({ ids = showPlayerIds, blips = showPlayerBlips })
end)

-- panel dies with the resource: never leave the player focus-trapped, and never leave stray blips behind
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if panelOpen then SetNuiFocus(false, false) end
    clearPlayerBlips()
end)
