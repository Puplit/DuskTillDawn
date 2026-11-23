-- pup_postoffice | client: mail window, writing pose, send-off and the bridge to the page

local KVP_KEY <const> = 'pup_postoffice:display'
local KVP_MAX <const> = 16384

Mail = {
    box = nil,          -- PO box number of the current character, nil when unknown or none
    open = false,       -- window showing (or opening)
    sendOff = false,    -- the kneel-and-pigeon animation is playing
}

local lastMailboxRequest = 0
local openToken = 0
local props = {}
local pigeons = {}

--------------------------------------------------------------------------------
-- helpers

local function tip(msg, ms)
    TriggerEvent('vorp:TipRight', msg, ms or 4000)
end

local function nui(msg)
    SendNUIMessage(msg)
end

-- RedM natives answer 0/1 on some builds, and 0 is truthy in Lua: only true or 1 means yes
local function yes(v) return v == true or v == 1 end

function Mail.restrained(ped)
    ped = ped or PlayerPedId()
    return yes(IsPedHogtied(ped)) or yes(IsPedBeingHogtied(ped)) or yes(IsPedCuffed(ped)) or yes(IsEntityDead(ped))
end

local function hogtied(ped)
    return yes(IsPedHogtied(ped)) or yes(IsPedBeingHogtied(ped))
end

function Mail.busy(ped)
    ped = ped or PlayerPedId()
    return Mail.restrained(ped) or yes(IsPedFalling(ped)) or yes(IsPedRagdoll(ped)) or yes(IsPedGettingUp(ped)) or yes(IsPedInMeleeCombat(ped))
end

local function onFoot(ped)
    return not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)
end

local function loadModel(name)
    local hash = type(name) == 'number' and name or joaat(name)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(20)
    end
    return hash
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(20)
    end
    return true
end

local function deleteEntity(ent)
    if ent and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

--------------------------------------------------------------------------------
-- writing pose

local function removeProps()
    for i = #props, 1, -1 do
        deleteEntity(props[i])
        props[i] = nil
    end
end

local function attachProp(ped, model, bone, offset)
    local hash = loadModel(model)
    if not hash then return end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return end
    local boneIndex = GetEntityBoneIndexByName(ped, bone)
    AttachEntityToEntity(obj, ped, boneIndex, offset[1], offset[2], offset[3], offset[4], offset[5], offset[6],
        false, false, false, false, 1, true, false, false)
    props[#props + 1] = obj
end

local function startPose()
    local ped = PlayerPedId()
    if not onFoot(ped) or Mail.restrained(ped) then return end
    removeProps()
    local P = Config.Pose
    attachProp(ped, P.letterProp, P.letterBone, P.letterOffset)
    attachProp(ped, P.penProp, P.penBone, P.penOffset)
    if loadDict(P.animDict) and Mail.open and not Mail.sendOff then
        TaskPlayAnim(ped, P.animDict, P.animName, 4.0, -4.0, -1, P.animFlag, 0.0, false, false, false)
    end
end

local function stopPose(hadPose)
    removeProps()
    if not hadPose then return end
    local ped = PlayerPedId()
    if Mail.restrained(ped) or Mail.sendOff then return end
    StopAnimTask(ped, Config.Pose.animDict, Config.Pose.animName, 2.0)
    ClearPedTasks(ped, true, false)
end

--------------------------------------------------------------------------------
-- window

local poseActive = false

function Mail.closeWindow(fromPage)
    if not Mail.open then return end
    Mail.open = false
    openToken = openToken + 1
    SetNuiFocus(false, false)
    if not fromPage then nui({ type = 'close' }) end
    local had = poseActive
    poseActive = false
    stopPose(had)
end

function Mail.openWindow()
    if Mail.open then return end
    Mail.open = true
    openToken = openToken + 1
    local token = openToken
    local ped = PlayerPedId()
    poseActive = onFoot(ped)

    nui({ type = 'open', box = Mail.box })
    SetNuiFocus(true, true)
    if poseActive then CreateThread(startPose) end

    -- the page has 4 seconds to say it is up
    Mail.pageConfirmed = false
    SetTimeout(4000, function()
        if openToken == token and Mail.open and not Mail.pageConfirmed then
            Mail.closeWindow(false)
            tip(L.windowFailed)
        end
    end)

    -- close if the character gets tied, cuffed or killed
    CreateThread(function()
        while Mail.open and openToken == token do
            Wait(500)
            if Mail.open and openToken == token and Mail.restrained(PlayerPedId()) then
                Mail.closeWindow(false)
            end
        end
    end)
end

function Mail.requestMailbox(force)
    local now = GetGameTimer()
    if not force and now - lastMailboxRequest < 5000 then return end
    lastMailboxRequest = now
    TriggerServerEvent('pup_postoffice:requestMailbox')
end

--------------------------------------------------------------------------------
-- send-off: kneel, a pigeon takes the letter

local function playSendOff()
    local ped = PlayerPedId()
    if Mail.sendOff or not onFoot(ped) or Mail.restrained(ped) then return end
    Mail.sendOff = true
    CreateThread(function()
        local S = Config.SendOff
        removeProps()
        ClearPedTasks(ped, true, false)
        Citizen.InvokeNative(0x524B54361229154F, ped, joaat(S.scenario), -1, true, false, false, false) -- TASK_START_SCENARIO_IN_PLACE_HASH
        Wait(S.pigeonAtMs)

        local hash = loadModel(S.pigeonModel)
        if hash then
            local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.7, 0.1)
            local bird = CreatePed(hash, pos.x, pos.y, pos.z, GetEntityHeading(ped), true, true, false, false)
            SetModelAsNoLongerNeeded(hash)
            if bird and bird ~= 0 then
                -- give the bird its outfit so it is visible, then let it fly
                Citizen.InvokeNative(0x283978A15512B2FE, bird, true)
                SetBlockingOfNonTemporaryEvents(bird, true)
                Citizen.InvokeNative(0xE86A537B5A3C297C, bird, ped) -- TASK_FLY_AWAY
                pigeons[#pigeons + 1] = bird
                SetTimeout(S.pigeonLifeMs, function()
                    for i, b in ipairs(pigeons) do
                        if b == bird then table.remove(pigeons, i) break end
                    end
                    deleteEntity(bird)
                end)
            end
        end

        Wait(math.max(0, S.kneelMs - S.pigeonAtMs))
        ped = PlayerPedId()
        if not Mail.restrained(ped) then ClearPedTasks(ped, true, false) end
        Mail.sendOff = false
        if Mail.open and poseActive then
            Wait(600)
            if Mail.open and not Mail.sendOff then startPose() end
        end
    end)
end

--------------------------------------------------------------------------------
-- /mail

RegisterCommand(Config.Command, function()
    CreateThread(function()
        if Mail.open then return end
        local ped = PlayerPedId()
        if hogtied(ped) then return tip(L.restrained) end

        if not Mail.box then
            Mail.requestMailbox(false)
            local deadline = GetGameTimer() + 3000
            while not Mail.box and GetGameTimer() < deadline do Wait(100) end
            if not Mail.box then return tip(L.needRegister) end
        end
        if Config.LocationOnly then return tip(L.needOffice) end
        if Mail.busy(PlayerPedId()) then return end
        Mail.openWindow()
    end)
end, false)

--------------------------------------------------------------------------------
-- server -> client

RegisterNetEvent('pup_postoffice:mailbox', function(payload)
    if type(payload) == 'table' and tonumber(payload.box) then
        Mail.box = tonumber(payload.box)
        nui({ type = 'mailbox', data = payload })
    else
        Mail.box = nil
        nui({ type = 'mailbox', data = false })
        Mail.closeWindow(false)
    end
end)

RegisterNetEvent('pup_postoffice:boxNumber', function(box)
    Mail.box = tonumber(box)
    nui({ type = 'boxNumber', box = Mail.box })
end)

-- also fired by other resources after they insert a letter of their own
RegisterNetEvent('pup_postoffice:rec_addedMailid', function(letter, isIncoming)
    if type(letter) ~= 'table' then return end
    nui({ type = 'letter', letter = letter, incoming = isIncoming == true, open = Mail.open })
end)

RegisterNetEvent('pup_postoffice:sendResult', function(req, ok)
    nui({ type = 'sendResult', req = req, ok = ok == true })
    if ok == true then playSendOff() end
end)

RegisterNetEvent('pup_postoffice:contactAdded', function(ref, id, contact)
    nui({ type = 'contactAdded', ref = ref, id = id or false, contact = contact })
end)

RegisterNetEvent('pup_postoffice:folderAdded', function(ref, id, business, name)
    nui({ type = 'folderAdded', ref = ref, id = id or false, business = business == true, name = name })
end)

RegisterNetEvent('pup_postoffice:directory', function(dir)
    nui({ type = 'directory', data = type(dir) == 'table' and dir or {} })
end)

-- every chat update: list, thread, replies, msg, posted, react, read, typing, started, changed, gone
RegisterNetEvent('pup_postoffice:chat', function(data)
    if type(data) ~= 'table' or type(data.type) ~= 'string' then return end
    -- chat messages go by telegraph: the kneel-and-pigeon send-off is only for letters (sendResult below)
    nui({ type = 'chat', data = data, open = Mail.open })
end)

-- fred_hud's layout editor moves the envelope
AddEventHandler('mail:hudIconPos', function(dx, dy, preview)
    nui({ type = 'hudPos', dx = tonumber(dx) or 0, dy = tonumber(dy) or 0, preview = preview == true })
end)

--------------------------------------------------------------------------------
-- page -> client

local function reply(cb, value)
    if cb then cb(value == nil and 'ok' or value) end
end

RegisterNUICallback('ready', function(_, cb)
    Mail.pageConfirmed = true
    reply(cb)
end)

RegisterNUICallback('close', function(_, cb)
    Mail.closeWindow(true)
    reply(cb)
end)

RegisterNUICallback('requestMailbox', function(_, cb)
    Mail.requestMailbox(false)
    reply(cb)
end)

RegisterNUICallback('send', function(data, cb)
    if type(data) == 'table' and Mail.box then
        TriggerServerEvent('pup_postoffice:send', {
            to = data.to, names = data.names, subject = data.subject, body = data.body,
            anon = data.anon == true, asBusiness = data.asBusiness == true,
        }, tonumber(data.req) or 0)
    end
    reply(cb)
end)

RegisterNUICallback('file', function(data, cb)
    if type(data) == 'table' then TriggerServerEvent('pup_postoffice:file', data) end
    reply(cb)
end)

RegisterNUICallback('contacts', function(data, cb)
    if type(data) == 'table' then TriggerServerEvent('pup_postoffice:contacts', data) end
    reply(cb)
end)

RegisterNUICallback('folders', function(data, cb)
    if type(data) == 'table' then TriggerServerEvent('pup_postoffice:folders', data) end
    reply(cb)
end)

RegisterNUICallback('chat', function(data, cb)
    if type(data) == 'table' and type(data.op) == 'string' and Mail.box then
        TriggerServerEvent('pup_postoffice:chat', data.op, type(data.data) == 'table' and data.data or {})
    end
    reply(cb)
end)

RegisterNUICallback('saveSettings', function(data, cb)
    local raw = type(data) == 'table' and data.json
    if type(raw) == 'string' and #raw <= KVP_MAX then
        SetResourceKvp(KVP_KEY, raw)
    end
    reply(cb)
end)

--------------------------------------------------------------------------------
-- start-up, character selection, stop

local function pageConfig()
    return {
        branding = Config.Branding,
        command = Config.Command,
        limits = {
            page = Config.PageLimits,
            maxRecipients = Config.Letters.maxRecipients,
            businessByChat = Config.Letters.businessByChat ~= false,
            maxBody = Config.Letters.maxBody,
            maxSubject = Config.Letters.maxSubject,
            maxContacts = Config.Mailbox.maxContacts,
            maxFolders = Config.Mailbox.maxFolders,
        },
        changeCost = Config.BusinessChangeCost,
        reactions = Config.Chat.reactions,
    }
end

local function signIn(afterRestart)
    Mail.box = nil
    nui({ type = 'forgetBox' })
    Mail.requestMailbox(true)
    SetTimeout(4000, function()
        if not Mail.box then return end
        TriggerServerEvent('pup_postoffice:chat', 'list', { view = 'p' })
        TriggerServerEvent('pup_postoffice:chat', 'list', { view = 'b' })
    end)
    if afterRestart then TriggerEvent('fred_hud:reapplyLayout') end
end

local function sendInit()
    nui({ type = 'init', config = pageConfig(), settings = GetResourceKvpString(KVP_KEY) })
end

-- the page says it has loaded: a message sent before that may have been lost, so send the set-up again
RegisterNUICallback('boot', function(_, cb)
    sendInit()
    -- the mailbox may also have arrived before the page could hear it
    if Mail.box then Mail.requestMailbox(true) end
    reply(cb)
end)

CreateThread(function()
    sendInit()
    Wait(2000)
    signIn(true)
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    Mail.closeWindow(false)
    signIn(false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Mail.open then
        Mail.open = false
        SetNuiFocus(false, false)
    end
    removeProps()
    for _, b in ipairs(pigeons) do deleteEntity(b) end
    if poseActive then
        local ped = PlayerPedId()
        if not Mail.restrained(ped) then ClearPedTasks(ped, true, false) end
    end
end)
