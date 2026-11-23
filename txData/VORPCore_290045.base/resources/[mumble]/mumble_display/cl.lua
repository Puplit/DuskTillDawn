-- mumble_display | mic indicator + voice-range gauge

-- fill level per voice mode: whisper / normal / shouting / riding
local FILL = { '30%', '0%', '-25%', '-50%' }

-- metres per voice mode, mirroring mumble's Cfg.voiceModes. Only a fallback:
-- the state bag below is preferred, so editing that config is enough.
local RANGE = { 2, 5, 15, 32 }

local talking = false
local visible = true
local mode    = 2

-- how far they carry right now, as the gauge prints it
local function rangeText()
    local index = math.min(math.max(mode, 1), #RANGE)
    local metres = RANGE[index]

    -- mumble publishes the real distance with the mode it belongs to; trust it
    -- only while the two agree, so a half-applied cycle never shows a stale one
    local prox = LocalPlayer.state.proximity
    if type(prox) == 'table' and tonumber(prox.index) == mode and tonumber(prox.distance) then
        metres = tonumber(prox.distance)
    end

    if not metres then return '' end
    return ('%dM'):format(math.floor(metres + 0.5))
end

local function push()
    SendNUIMessage({
        visible = visible,
        talking = talking,
        fill    = FILL[math.min(math.max(mode, 1), #FILL)],
        range   = rangeText(),
    })
end

-- pup: MOVABLE VOICE GAUGE. fred_hud's /hud editor stores the offset and pushes
-- it here. This is the gauge the player actually sees: mumble's own .voiceInfo
-- is off (`setr voice_enableUi 0`), so this is the one to move.
AddEventHandler('mumble:hudPos', function(dx, dy)
    SendNUIMessage({ action = 'pupVoicePos',
        dx = tonumber(dx) or 0, dy = tonumber(dy) or 0 })
end)

-- fred_hud applies the layout before this page is up, so ask for it again
CreateThread(function()
    Wait(4000)
    TriggerEvent('fred_hud:reapplyLayout')
end)

-- pma-voice cycles the mode with F11 and fires this
AddEventHandler('pma-voice:setTalkingMode', function(newMode)
    mode = tonumber(newMode) or mode
    push()
end)

-- let other resources hide the gauge (a fullscreen menu, a cutscene)
RegisterNetEvent('mumble_display:setVisible', function(state)
    visible = state and true or false
    push()
end)
AddEventHandler('mumble_display:setVisible', function(state)
    visible = state and true or false
    push()
end)

CreateThread(function()
    -- pma-voice publishes the mode it restored on join
    Wait(2000)
    local prox = LocalPlayer.state.proximity
    if type(prox) == 'table' and prox.index then
        mode = tonumber(prox.index) or mode
    end
    push()

    local playerId = PlayerId()
    while true do
        Wait(150)
        local now = MumbleIsPlayerTalking(playerId) == 1
        if now ~= talking then
            talking = now
            push()
        end
    end
end)
