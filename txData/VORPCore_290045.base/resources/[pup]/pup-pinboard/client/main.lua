-- The page names a `reply` message type on each call that wants an answer; the answer goes back under that type.

local open      = false
local here      = nil      -- city of the board being read
local waiting   = {}       -- token -> the page's reply type
local lastToken = 0
local reader    = nil      -- who is reading, pushed by the server when the board is opened

local function remember(replyType)
    lastToken = lastToken + 1
    waiting[lastToken] = replyType
    return lastToken
end

local function answer(token, payload)
    local replyType = waiting[token]
    if not replyType then return end
    waiting[token] = nil
    payload = payload or {}
    payload.type = replyType
    SendNUIMessage(payload)
end

local function boardFor(city)
    for _, b in ipairs(Config.Boards or {}) do
        if b.city == city then return b end
    end
    return nil
end

local function isNight()
    local h = GetClockHours()
    return h >= 20 or h < 6
end

-- open / close

local function closeBoard()
    open = false
    here = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })
end

local function openBoard(city)
    if open then return end
    open = true
    here = city

    SetNuiFocus(true, true)
    SendNUIMessage({
        type     = 'show',
        night    = isNight(),
        settings = Config,
        texts    = Locale or {},
        player   = reader,
        board    = boardFor(city),
    })
end

RegisterNetEvent('pup-pinboard:player', function(p) reader = p end)

-- prompt: one prompt, one group, titled with the town of the nearest board

local PROMPT_GROUP <const> = GetHashKey('pup-pinboard') & 0xFFFFFF
local readPrompt

local function makePrompt()
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, Config.Prompt.key)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', Locale.prompt_read or 'Read'))
    PromptSetEnabled(p, 1)
    PromptSetVisible(p, 1)
    PromptSetStandardMode(p, 1)
    PromptSetGroup(p, PROMPT_GROUP)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C, p, true)
    PromptRegisterEnd(p)
    return p
end

CreateThread(function()
    Wait(500)
    readPrompt = makePrompt()

    local radius = tonumber(Config.Prompt.radius) or 1.6
    while true do
        local sleep = 750
        if not open and readPrompt then
            local me = GetEntityCoords(PlayerPedId())
            for _, b in ipairs(Config.Boards or {}) do
                local d = #(me - vector3(b.coords[1], b.coords[2], b.coords[3]))
                if d < 20.0 then
                    sleep = 0
                    if d < radius then
                        -- built every frame: a cached VarString points into a reused game buffer
                        local title = (Locale.board_title or '%s'):format(b.city)
                        PromptSetActiveGroupThisFrame(PROMPT_GROUP, CreateVarString(10, 'LITERAL_STRING', title))
                        if Citizen.InvokeNative(0xC92AC953F0A982AE, readPrompt) then
                            TriggerServerEvent('pup-pinboard:wake')
                            openBoard(b.city)
                        end
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

-- blips

local function spriteHash(s)
    if type(s) == 'string' and not tonumber(s) then return GetHashKey(s) end
    return tonumber(s) or 0
end

CreateThread(function()
    local cfg = Config.Blip or {}
    if cfg.show == false then return end
    local sprite = spriteHash(cfg.sprite)
    for _, b in ipairs(Config.Boards or {}) do
        if b.blip ~= false then
            -- BLIP_ADD_FOR_COORDS, default blip style
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, b.coords[1], b.coords[2], b.coords[3])
            SetBlipSprite(blip, sprite, 1)
            SetBlipScale(blip, tonumber(cfg.scale) or 1.0)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, cfg.label or b.city) -- _SET_BLIP_NAME
        end
    end
end)

-- page calls: each one that needs the server is forwarded with a token

local function forward(name, event, withCity)
    RegisterNUICallback(name, function(data, cb)
        cb('ok')
        if withCity and not here then return end
        local token = remember(data.reply)
        if withCity then
            TriggerServerEvent(event, here, data, token)
        else
            TriggerServerEvent(event, data, token)
        end
    end)
end

forward('listNotices', 'pup-pinboard:getList',   true)
forward('pinText',     'pup-pinboard:saveText',  true)
forward('pinPicture',  'pup-pinboard:saveImage', true)
forward('unpinNotice', 'pup-pinboard:remove',    false)
forward('ecoStatus',   'pup-pinboard:ecoStatus', false)
forward('ecoActivate', 'pup-pinboard:ecoActivate', false)

RegisterNUICallback('isNight', function(data, cb)
    cb('ok')
    if not data.reply then return end
    SendNUIMessage({ type = data.reply, ok = true, night = isNight() })
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    closeBoard()
end)

-- server replies

RegisterNetEvent('pup-pinboard:list',    function(token, payload) answer(token, payload) end)
RegisterNetEvent('pup-pinboard:saved',   function(token, payload) answer(token, payload) end)
RegisterNetEvent('pup-pinboard:removed', function(token, payload) answer(token, payload) end)
RegisterNetEvent('pup-pinboard:eco',     function(token, payload) answer(token, payload) end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then
        SetNuiFocus(false, false)
    end
end)
