-- Opens after vorp_core has placed the character at their saved coords, so "where you left off" is just not moving them.

local open = false
local asking = false
local lastCoords, lastHeading = nil, nil
local seenThisSession = false
local houses = nil
local diedOnLogout = false

-- the server decides whether the menu is offered and sends the house list with its answer
local verdict = nil
RegisterNetEvent('pup-spawnselect:answer', function(data) verdict = data or { allow = false } end)

local function teleport(coords, heading)
    local ped <const> = PlayerPedId()
    SetEntityCoordsAndHeading(ped, coords.x, coords.y, coords.z, heading or 0.0, false, false, false)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    LoadSceneStart(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 40.0, 0)
    local started <const> = GetGameTimer()
    repeat Wait(0) until IsLoadSceneLoaded() ~= 0 or GetGameTimer() - started > 6000
    LoadSceneStop()
end

-- built once per opening so the index the NUI sends back lines up with the cards it was given
local order = {}

local function build()
    order = {}
    local list = {}

    -- x/y ride along so the NUI can place the pin; the map needs world coords
    local function add(entry, coords, heading)
        if coords then
            entry.x = coords.x + 0.0
            entry.y = coords.y + 0.0
        end
        list[#list + 1] = entry
        order[#order + 1] = { coords = coords, heading = heading, label = entry.label }
    end

    -- `short` is what the pin prints; `label` is the full name for the button
    if Config.LastLocation.enabled and lastCoords then
        add({ label = Locale.lastLocationLabel, short = Locale.lastLocationShort, area = Locale.lastLocationArea,
              blurb = Locale.lastLocationBlurb,
              tag = true },
            lastCoords, lastHeading)
    end

    for _, h in ipairs(houses or {}) do
        add({
            label = Locale.houseLabel or 'Your House',
            short = h.owner and Locale.houseOwnerShort or Locale.houseKeyShort,
            area  = h.owner and Locale.houseOwnerArea or Locale.houseKeyArea,
            blurb = h.owner and Locale.houseOwnerBlurb or Locale.houseKeyBlurb,
            tag   = true,
        }, vector3(h.coords.x, h.coords.y, h.coords.z), h.coords.h + 0.0)
    end

    local job = LocalPlayer.state.Character and LocalPlayer.state.Character.Job
    local jobSpawn = job and Config.JobSpawns[job]
    if jobSpawn then
        add({ label = jobSpawn.label, short = Locale.jobShort, area = Locale.jobArea,
              blurb = jobSpawn.blurb or '', tag = true },
            jobSpawn.coords, jobSpawn.heading)
    end

    for _, s in ipairs(Config.Spawns) do
        add({ label = s.label, short = s.label, area = s.area, blurb = s.blurb, image = s.image,
              labelAngle = s.labelAngle, labelDist = s.labelDist },
            s.coords, s.heading)
    end
    return list
end

local function resolve(index)
    local pick = order[index]
    if pick and pick.coords then return pick.coords, pick.heading end
    return lastCoords, lastHeading
end

local function finish(index)
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    local idx <const> = tonumber(index) or 1
    local coords, heading = resolve(idx)
    local ped <const> = PlayerPedId()

    -- reported before the move, so the server can still compare it with the saved position
    if coords then
        TriggerServerEvent('pup-spawnselect:picked',
            (order[idx] and order[idx].label) or '?', coords.x, coords.y, coords.z)
        teleport(coords, heading)
    end

    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    DoScreenFadeIn(1200)
    lastCoords, lastHeading = nil, nil -- so a later open reads the ped again
    TriggerEvent('pup-spawnselect:done')
end

local function show()
    if open or asking then return end
    asking = true

    -- ask before fading or freezing, so a refusal looks like an ordinary login
    verdict = nil
    TriggerServerEvent('pup-spawnselect:request', diedOnLogout)
    local waited = 0
    while verdict == nil and waited < 4000 do Wait(100) waited = waited + 100 end
    asking = false

    -- a silent server leaves them exactly where vorp already put them
    if not verdict or verdict.allow ~= true then return end
    houses = verdict.houses or {}

    open = true

    local ped <const> = PlayerPedId()
    -- fall back to the ped only when something other than initCharacter opened the menu
    if not lastCoords then
        lastCoords  = GetEntityCoords(ped)
        lastHeading = GetEntityHeading(ped)
    end

    if not IsScreenFadedOut() then
        DoScreenFadeOut(400)
        Wait(500)
    end

    -- held still and untouchable while they decide
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    DisplayRadar(false)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        title = Locale.title,
        subtitle = Locale.subtitle,
        accent = Config.Menu.accentColor,
        timeout = Config.Menu.timeoutSeconds or 0,
        spawns = build(),
    })

    CreateThread(function()
        while open do
            Wait(0)
            DisableAllControlActions(0)
        end
        DisplayRadar(true)
    end)
end

RegisterNUICallback('select', function(data, cb)
    cb({ ok = true })
    finish(data and data.index)
end)

-- isdead arrives as a tinyint, and 0 is TRUTHY in lua
local function isTrue(v)
    return v == true or v == 1 or v == '1'
end

-- Opened from initCharacter rather than OnPlayerSpawned, which fires only after the world has faded in.
-- The request is always sent, even when dead, so the server can stamp the disconnect time later.
RegisterNetEvent('vorp:initCharacter')
AddEventHandler('vorp:initCharacter', function(coords, heading, isdead)
    diedOnLogout = isTrue(isdead)
    if Config.General.enabled ~= true then return end
    if not Config.General.everySpawn and seenThisSession then return end
    seenThisSession = true

    if coords then
        lastCoords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
        lastHeading = (tonumber(heading) or 0.0) + 0.0
    end

    CreateThread(function()
        Wait(250) -- let vorp_character drop its own NUI focus first
        show()
    end)
end)

RegisterNetEvent('pup-spawnselect:open', function() CreateThread(show) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if not open then return end
    SetNuiFocus(false, false)
    local ped <const> = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    DoScreenFadeIn(0)
end)
