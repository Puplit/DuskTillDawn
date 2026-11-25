-- fred_hud / hudmove.lua (pup, Aug 2026) MOVABLE HUD

local KVP_KEY = 'fred_hud:layout'

-- What can be moved. Names shown in the editor come from Locale.element<Key>.
-- money / id live in vorp_core's page, mail in pup_postoffice, progress in pup-ui, voice in mumble_display.
local ELEMENTS = {
    { key = 'hunger' }, { key = 'thirst' }, { key = 'temp' }, { key = 'recovery' },
    { key = 'money' }, { key = 'id' }, { key = 'mail' }, { key = 'eco' },
    { key = 'heist' }, { key = 'alarm' }, { key = 'progress' }, { key = 'voice' },
}

local layout   = {}
local editing  = nil   -- true while the editor is open
local editBase = nil   -- the layout as it was when it opened, for a cancel

-- the player's display settings, defaults from Config.Settings
local SETTING_DEFS = {}
for _, def in ipairs(Config.Settings) do SETTING_DEFS[def.key] = def end
local NUMERIC_SETTINGS = { hunger = true, thirst = true }  -- 0-100 thresholds, any value kept

-- GLOBAL on purpose: client.lua's gauge loop reads HudSettings.tempUnit every tick
HudSettings = {}
for _, def in ipairs(Config.Settings) do HudSettings[def.key] = def.default end

local function entry(key)
    layout[key] = layout[key] or { dx = 0, dy = 0 }
    return layout[key]
end

-- what the NUI page needs from config: look, choices, timings and every string
local function nuiConfig()
    return {
        gauges   = Config.Gauges,
        settings = Config.Settings,
        recovery = Config.Recovery,
        heist    = Config.Heist,
        locale   = Locale,
    }
end

-- the page asks for it as soon as it loads
RegisterNUICallback('hudConfig', function(_, cb)
    cb(nuiConfig())
end)

-- apply + persist

-- Split by frame: our own gauges go straight to our NUI, money/ID belong to vorp_core's page and are handed over by event
local function applyLayout()
    SendNUIMessage({ action = 'hudLayout', layout = layout, settings = HudSettings })
    TriggerEvent('vorp_core:hudLayout', {
        money     = layout.money or { dx = 0, dy = 0 },
        id        = layout.id    or { dx = 0, dy = 0 },
        hideMoney = HudSettings.money == 'hidden',
        moneyFont = HudSettings.moneyFont,
        moneySize = HudSettings.moneySize,
    })

    -- the envelope is a third frame again: the mail resource's own page
    local mail = layout.mail or { dx = 0, dy = 0 }
    TriggerEvent('mail:hudIconPos', mail.dx or 0, mail.dy or 0, editing == true)

    -- which side pup-ui opens its menus on (barber, stores, creator, ...)
    TriggerEvent('pup-ui:menuSide', HudSettings.menuSide)

    -- the progress bar is pup-ui's frame, same handover as money/ID and mail
    local prog = layout.progress or { dx = 0, dy = 0 }
    TriggerEvent('pup-ui:progressStyle', HudSettings.progressStyle)
    TriggerEvent('pup-ui:progressPos', prog.dx or 0, prog.dy or 0, editing == true)

    -- the voice readout is mumble's frame
    local voice = layout.voice or { dx = 0, dy = 0 }
    TriggerEvent('mumble:hudPos', voice.dx or 0, voice.dy or 0)
end

local function saveLayout()
    SetResourceKvp(KVP_KEY, json.encode({ layout = layout, settings = HudSettings }))
end

-- only known keys, of the right shape; anything else falls back to the default
local function adoptSettings(incoming)
    if type(incoming) ~= 'table' then return end
    for key, def in pairs(SETTING_DEFS) do
        if NUMERIC_SETTINGS[key] then
            local v = math.floor(tonumber(incoming[key]) or 0)
            HudSettings[key] = (v >= 0 and v <= 100) and v or def.default
        else
            local v = tostring(incoming[key] or '')
            local value = def.default
            for _, choice in ipairs(def.choices) do
                if v == tostring(choice) then value = choice break end
            end
            HudSettings[key] = value
        end
    end
end

local function loadLayout()
    layout = {}
    local raw = GetResourceKvpString(KVP_KEY)
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            -- the original format was the bare layout map; the current one wraps it alongside settings
            local src = decoded.layout or decoded
            for k, v in pairs(src) do
                if type(v) == 'table' and v.dx ~= nil then
                    layout[k] = { dx = tonumber(v.dx) or 0, dy = tonumber(v.dy) or 0 }
                end
            end
            adoptSettings(decoded.settings)
        end
    end
    SendNUIMessage({ action = 'hudConfig', config = nuiConfig() })
    applyLayout()
end

-- the NUI frame is not ready the instant the resource starts, and vorp_core's may not be either
CreateThread(function()
    Wait(Config.Timing.layoutLoadDelayMs)
    loadLayout()
end)

RegisterNetEvent('vorp:SelectedCharacter')
AddEventHandler('vorp:SelectedCharacter', function()
    -- re-apply after a character swap: vorp_core rebuilds its HUD there
    CreateThread(function() Wait(Config.Timing.characterReapplyDelayMs) applyLayout() end)
end)

-- a foreign page that restarted (pup-ui) asks for its offsets again
AddEventHandler('fred_hud:reapplyLayout', function()
    applyLayout()
end)

-- the editor - ps-hud style: turn it on, grab a thing, drag it

local function openEditor()
    if editing then return end
    editing = true
    -- both halves are snapshotted: Close must undo settings as well as drags
    editBase = json.encode({ layout = layout, settings = HudSettings })
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'hudEdit', on = true, layout = layout, settings = HudSettings })
    applyLayout() -- re-push so the mail icon is forced visible for the edit
end

local function closeEditor()
    editing = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hudEdit', on = false })
    applyLayout() -- and again, so the mail icon goes back to its real state
end

-- accept a layout the page reports, keeping only the shape we expect
local function adopt(incoming)
    local clean = {}
    if type(incoming) == 'table' then
        for _, e in ipairs(ELEMENTS) do
            local v = incoming[e.key]
            if type(v) == 'table' then
                local dx, dy = tonumber(v.dx) or 0, tonumber(v.dy) or 0
                if dx ~= 0 or dy ~= 0 then clean[e.key] = { dx = dx, dy = dy } end
            end
        end
    end
    layout = clean
end

-- every mouse move while dragging: apply but do NOT write to disk
RegisterNUICallback('hudLive', function(data, cb)
    adopt(data and data.layout)
    adoptSettings(data and data.settings)
    applyLayout()
    cb('ok')
end)

RegisterNUICallback('hudSave', function(data, cb)
    adopt(data and data.layout)
    adoptSettings(data and data.settings)
    applyLayout()
    saveLayout()
    closeEditor()
    TriggerEvent('vorp:TipBottom', Locale.hudSaved, 3000)
    cb('ok')
end)

RegisterNUICallback('hudCancel', function(_, cb)
    -- put back whatever was there when the editor opened, settings included
    local ok, prev = pcall(json.decode, editBase or '{}')
    if ok and type(prev) == 'table' then
        layout = type(prev.layout) == 'table' and prev.layout or {}
        adoptSettings(prev.settings)
    else
        layout = {}
    end
    applyLayout()
    closeEditor()
    cb('ok')
end)

-- TOGGLE, not open
RegisterCommand(Config.General.editCommand, function()
    if editing then closeEditor() else openEditor() end
end, false)

-- focus is a thing that can strand a player
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and editing then
        SetNuiFocus(false, false)
    end
end)
