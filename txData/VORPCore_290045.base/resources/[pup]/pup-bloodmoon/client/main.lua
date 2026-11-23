local up       = false
local wantLook = nil

local function suspendSync()
    pcall(function() exports['weathersync']:setSyncEnabled(false) end)
end

local function resumeSync()
    pcall(function() exports['weathersync']:setSyncEnabled(true) end)
end

local function lookAt(n)
    return (Config.Looks or {})[tonumber(n) or 0] or (Config.Looks or {})[1]
        or { weather = 'sunny' }
end

-- (weather type, variation name), both strings: one argument or a hash faults the native
local VARIATIONS = {
    { 'MISTY',        'misty_MP_Pred' },
    { 'SHOWER',       'shower_MP_Pred' },
    { 'FOG',          'fog_MP_Pred' },
    { 'THUNDERSTORM', 'THUNDERSTORM_MP_Pred' },
}

-- the binding persists, so without this every later misty, fog or shower sky stays red
local function clearVariations()
    for _, v in ipairs(VARIATIONS) do
        Citizen.InvokeNative(0x0E71C80FA4EC8147, v[1], true)
    end
end

local function setSky(transition, look)
    if not look.variation then clearVariations() end
    Citizen.InvokeNative(0x59174F1AFE095B5A, GetHashKey(look.weather or 'sunny'),
        true, true, true, (tonumber(transition) or 0.0) + 0.0, false)
    -- binds each type to its red variant; this is what carries the red
    if look.variation then
        for _, v in ipairs(VARIATIONS) do
            Citizen.InvokeNative(0x3373779BAF7CAF48, v[1], v[2])
        end
    end
end

-- the red lives in the sky only: no timecycle grade and no fullscreen postfx
local function paint(transition, look)
    setSky(transition, look)
end

local function wipe()
    up, wantLook = false, nil
    clearVariations()
    Citizen.InvokeNative(0x59174F1AFE095B5A, GetHashKey('CLEAR'),
        true, true, true, (tonumber(Config.Moon.transitionOutSeconds) or 0.0) + 0.0, false)
    Citizen.InvokeNative(0x80A398F16FFE3CC3)
    ClearWeatherTypePersist()
end

RegisterNetEvent('pup-bloodmoon:set', function(transition, lookIdx)
    up = true
    wantLook = lookAt(lookIdx or Config.Moon.defaultLook)
    suspendSync()
    paint(transition or Config.Moon.transitionInSeconds, wantLook)
end)

RegisterNetEvent('pup-bloodmoon:clear', function()
    wipe()
    resumeSync()
end)

-- a moon already up on join: the server's join event fires before client scripts can hear it
AddEventHandler('onClientResourceStart', function(name)
    if name == GetCurrentResourceName() then SetTimeout(2000, function() TriggerServerEvent('pup-bloodmoon:sync') end) end
end)
RegisterNetEvent('vorp:SelectedCharacter', function()
    SetTimeout(2000, function() TriggerServerEvent('pup-bloodmoon:sync') end)
end)

-- weather is per-client and gets dropped by world reloads
CreateThread(function()
    while true do
        Wait(30000)
        if up then paint(0.0, wantLook or lookAt(Config.Moon.defaultLook)) end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    wipe()
    resumeSync()
end)

if Config.Howl and Config.Howl.enabled then
    AddEventHandler('pup_shaman:howled', function()
        TriggerServerEvent('pup-bloodmoon:howl')
    end)
end
