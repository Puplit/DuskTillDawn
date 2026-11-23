-- river | client: wash and drink prompts in river / lake water, bottle fill / boil /
-- drink, and the vomiting while poisoned. The server decides every outcome; this file
-- plays the animations and applies fred_metabolism's stat changes.
-- Publishes WaterClient (busy flag, the clean set, helpers), which washbarrel.lua uses.

local CFG <const> = WaterConfig
local L <const> = WaterLocale
local EV <const> = 'pup-misc:water:'

WaterClient = { busy = false, nearBarrel = false }
local W <const> = WaterClient

local function dbg(...)
    if CFG.General.debug then print('[pup-misc/river]', ...) end
end

local function truthy(v) return v == true or v == 1 end

function W.tip(text, ms)
    if text then TriggerEvent('vorp:TipRight', text, ms or 8000) end
end
local tip <const> = W.tip

local function stats(set)
    local v = CFG.Stats[set]
    if v then TriggerEvent('fred_meta:consume', table.unpack(v, 1, 9)) end
end

function W.onFoot(ped)
    return not truthy(IsPedOnMount(ped)) and not truthy(IsPedInAnyVehicle(ped, false))
end

function W.dead(ped)
    return truthy(IsEntityDead(ped)) or truthy(IsPedDeadOrDying(ped, true))
end

function W.loadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

-- the clean set: dirt, blood, decals, wetness
function W.cleanPed(ped)
    Citizen.InvokeNative(0x6585D955A68452A5, ped)
    Citizen.InvokeNative(0x8FE22675A5A45817, ped)
    Citizen.InvokeNative(0xE3144B932DFDFF65, ped, 0.0, -1, true, true)
    Citizen.InvokeNative(0x523C79AEEFCC4A2A, ped, 10, 'ALL')
    Citizen.InvokeNative(0x7F5D88333EE8A86F, ped, 1)
    Citizen.InvokeNative(0x9C720776DAA43E7E, ped)
end

-- tells fred_metabolism (and anything else) that the player washed
function W.washed()
    TriggerEvent('pup_camps:washedface')
end

local function scenario(name, ms)
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, GetHashKey(name), ms or -1, true, false, false, false)
end

-- ------------------------------------------------------------------ water check

local zoneSet = {}
for _, z in ipairs(CFG.River.zones or {}) do
    zoneSet[z] = true
    zoneSet[z & 0xFFFFFFFF] = true
end

local function atSpot(coords)
    for _, s in ipairs(CFG.Spots or {}) do
        if #(coords - s.coords) <= (s.radius or 2.0) then return true end
    end
    return false
end

-- in river / lake water or at a custom spot
local function atWater(ped)
    local coords = GetEntityCoords(ped)
    if atSpot(coords) then return true end
    if not truthy(IsEntityInWater(ped)) then return false end
    if not CFG.River.restrictZones then return true end
    local zone = Citizen.InvokeNative(0x5BA7A68A346A5A91, coords.x, coords.y, coords.z, Citizen.ResultAsInteger())
    return zone ~= nil and zoneSet[zone] == true
end

local function nearFire(ped)
    local c = GetEntityCoords(ped)
    local r = CFG.Boil.radius or 2.0
    for _, m in ipairs(CFG.Boil.models or {}) do
        local hash = type(m) == 'number' and m or GetHashKey(m)
        if GetClosestObjectOfType(c.x, c.y, c.z, r, hash, false, false, false) ~= 0 then return true end
    end
    return false
end

-- ------------------------------------------------------------------ poison

local poisoned = false
local nextVomitAt = 0

local function vomitBlocked(ped)
    local skip = CFG.Poison.skipWhen or {}
    if skip.dead and W.dead(ped) then return true end
    if skip.mounted and truthy(IsPedOnMount(ped)) then return true end
    if skip.vehicle and truthy(IsPedInAnyVehicle(ped, false)) then return true end
    return false
end

local function vomit()
    scenario(CFG.Anims.vomit, CFG.Anims.vomitMs)
    Wait(CFG.Anims.vomitMs)
end

local function poisonTips(all)
    tip(L.poisoned, 8000)
    if all then tip(L.poisonRisk, 8000) end
    tip(L.getAntidote, 8000)
end

RegisterNetEvent(EV .. 'poison', function(state, secs)
    local was = poisoned
    poisoned = state == true
    if poisoned and not was then
        nextVomitAt = GetGameTimer() + CFG.Poison.vomitIntervalMs
    end
    dbg('poison', poisoned, secs)
end)

CreateThread(function()
    while true do
        Wait(500)
        if poisoned and GetGameTimer() >= nextVomitAt then
            local ped = PlayerPedId()
            if W.busy or vomitBlocked(ped) then
                nextVomitAt = GetGameTimer() + 2000
            else
                W.busy = true
                tip(L.poisoned, 8000)
                tip(L.getAntidote, 8000)
                vomit()
                W.busy = false
                nextVomitAt = GetGameTimer() + CFG.Poison.vomitIntervalMs
            end
        end
    end
end)

-- ------------------------------------------------------------------ bottle drink animation

local function setLabelEntry(key, text)
    if not key then return nil end
    local old = Citizen.InvokeNative(0x3429670F9B9EF2D3, key, Citizen.ResultAsString())
    -- only swap what can be put back, or the real item would stay renamed (a missing
    -- entry can come back empty, as the key itself or as 'NULL')
    if type(old) ~= 'string' or old == '' or old == key or old == 'NULL' then return nil end
    AddTextEntry(key, text)
    return old
end

local function bottleAnim()
    local B = CFG.Bottles
    local ped = PlayerPedId()
    local model = GetHashKey(B.prop)
    RequestModel(model)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(model) then Wait(B.drinkAnimMs) return end

    local prop = CreateObject(model, GetEntityCoords(ped), false, true, false, false, true)
    SetModelAsNoLongerNeeded(model)
    pcall(Citizen.InvokeNative, 0xAEE6C800E124CFE1, prop, L.bottleName)
    local entry = B.labelEntry or nil
    local old = entry and setLabelEntry(entry, L.bottleName)

    TaskItemInteraction_2(ped, B.itemKey, prop, GetHashKey(B.grip), GetHashKey(B.interaction), 1, 0, -1.0)
    Wait(B.drinkAnimMs)
    ClearPedTasks(ped)
    if DoesEntityExist(prop) then DeleteObject(prop) end
    if entry and old and old ~= '' then AddTextEntry(entry, old) end
end

-- ------------------------------------------------------------------ bottles

local function fill()
    local ped = PlayerPedId()
    tip(L.filling, CFG.Bottles.fillMs)
    scenario(CFG.Anims.fill, CFG.Bottles.fillMs)
    Wait(CFG.Bottles.fillMs)
    ClearPedTasksImmediately(ped)
    TriggerServerEvent(EV .. 'fill')
end

local function boil()
    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    local dur = CFG.Boil.durationMs
    pcall(function() exports['pup-ui']:Progress({ label = L.boiling, duration = dur }) end)
    scenario(CFG.Anims.boil, -1)

    local ends = GetGameTimer() + dur
    local ok = true
    while GetGameTimer() < ends do
        Wait(200)
        ped = PlayerPedId()
        if W.dead(ped) or #(GetEntityCoords(ped) - start) > (CFG.Boil.moveLimit or 2.5) then
            ok = false
            break
        end
    end
    ClearPedTasks(ped)
    if not ok then
        pcall(function() exports['pup-ui']:ProgressCancel() end)
        tip(L.boilCancelled, 5000)
        return
    end
    TriggerServerEvent(EV .. 'boil')
end

RegisterNetEvent(EV .. 'bottle', function(kind, container)
    if W.busy then return end
    local ped = PlayerPedId()
    if W.dead(ped) then return end
    W.busy = true

    if kind == 'empty' then
        if atWater(ped) then fill() else tip(L.needWater, 5000) end
    elseif kind == 'dirty' and CFG.Boil.enabled and W.onFoot(ped) and nearFire(ped) then
        boil()
    elseif kind == 'dirty' and not container and atWater(ped) then
        -- no empty bottle in use: a dirty bottle in water is refilled (the old behaviour).
        -- A clean bottle is drunk instead, so filling never spoils clean water.
        fill()
    else
        TriggerServerEvent(EV .. 'drink')
    end
    W.busy = false
end)

RegisterNetEvent(EV .. 'drank', function(kind, sick)
    -- the server already took the bottle: wait out a vomit (8 s) rather than lose the drink
    local deadline = GetGameTimer() + CFG.Anims.vomitMs + 2000
    while W.busy and GetGameTimer() < deadline do Wait(50) end
    W.busy = true
    if kind == 'clean' then
        stats('drink')
        bottleAnim()
    elseif not sick then
        stats('drink')
        tip(L.poisonRisk, 8000)
        bottleAnim()
    else
        stats('poisoned')
        poisonTips(true)
        bottleAnim()
        Wait(CFG.Bottles.vomitDelayMs)
        vomit()
        nextVomitAt = GetGameTimer() + CFG.Poison.vomitIntervalMs
    end
    W.busy = false
end)

RegisterNetEvent(EV .. 'cured', function()
    poisoned = false
    tip(L.cured, 8000)
    if W.busy then return end
    W.busy = true
    bottleAnim()
    W.busy = false
end)

-- ------------------------------------------------------------------ river wash / drink

local function riverWash()
    local ped = PlayerPedId()
    local a = CFG.Anims.riverWash
    if W.loadDict(a.dict) then
        TaskPlayAnim(ped, a.dict, a.clip, 1.0, 8.0, CFG.River.washMs, 0, 0, false, false, false, '', false)
        RemoveAnimDict(a.dict)
    end
    Wait(CFG.River.washMs)
    ClearPedTasks(ped)
    W.cleanPed(ped)
    W.washed()
end

local riverWaiting = 0     -- GetGameTimer() deadline while a river drink waits for the server
local riverReadyAt = 0     -- local copy of the server cooldown, so the prompt does not spam

local function riverDrink()
    if GetGameTimer() < riverReadyAt then
        tip(L.drinkCooldown, 4000)
        return
    end
    riverWaiting = GetGameTimer() + 3000
    TriggerServerEvent(EV .. 'river')
end

RegisterNetEvent(EV .. 'riverResult', function(sick, variant)
    riverWaiting = 0
    if sick == nil then
        tip(L.drinkCooldown, 4000)
        return
    end
    riverReadyAt = GetGameTimer() + (CFG.River.drinkCooldownSeconds or 0) * 1000
    -- the server already rolled and used the cooldown: wait out a vomit rather than drop it
    local deadline = GetGameTimer() + CFG.Anims.vomitMs + 2000
    while W.busy and GetGameTimer() < deadline do Wait(50) end
    if W.busy then return end
    W.busy = true
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    scenario(CFG.Anims.riverDrink, -1)
    Wait(CFG.River.drinkMs)
    ClearPedTasks(ped)
    if sick then
        stats('poisoned')
        poisonTips(true)
        vomit()
        nextVomitAt = GetGameTimer() + CFG.Poison.vomitIntervalMs
    else
        stats('drink')
        tip(L.riverDrank[variant] or L.riverDrank[1], 8000)
    end
    W.busy = false
end)

-- ------------------------------------------------------------------ prompts

local GROUP <const> = GetRandomIntInRange(0, 0xffffff)
local washPrompt, drinkPrompt

local function makePrompt(key, label)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', label))
    PromptSetEnabled(p, 1)
    PromptSetVisible(p, 1)
    PromptSetHoldMode(p, CFG.Prompts.holdMs or 800)
    PromptSetGroup(p, GROUP)
    PromptRegisterEnd(p)
    return p
end

function W.modifierOk()
    if not CFG.Prompts.requireModifier then return true end
    return truthy(IsControlPressed(0, CFG.Keys.modifier)) or truthy(IsDisabledControlPressed(0, CFG.Keys.modifier))
end
local modifierOk <const> = W.modifierOk

CreateThread(function()
    washPrompt = makePrompt(CFG.Keys.riverWash, L.wash)
    drinkPrompt = makePrompt(CFG.Keys.riverDrink, L.drink)
    local label = CreateVarString(10, 'LITERAL_STRING', L.groupRiver)

    local here, checkAt = false, 0
    while true do
        local ped = PlayerPedId()
        local t = GetGameTimer()
        local ready = not W.busy and riverWaiting < t and W.onFoot(ped)
            and not W.dead(ped) and not truthy(IsPedSwimming(ped))

        if not ready then
            here = false
            Wait(CFG.River.scanMs)
        else
            if t >= checkAt then
                here = atWater(ped)
                checkAt = t + (here and CFG.River.recheckMs or 0)
            end
            -- a trough / barrel in reach takes the wash, so the river group stays hidden
            if here and not W.nearBarrel and modifierOk() then
                PromptSetActiveGroupThisFrame(GROUP, label)
                if PromptHasHoldModeCompleted(washPrompt) then
                    W.busy = true
                    riverWash()
                    W.busy = false
                elseif PromptHasHoldModeCompleted(drinkPrompt) then
                    riverDrink()
                end
                Wait(0)
            elseif here then
                Wait(0)
            else
                Wait(CFG.River.scanMs)
            end
        end
    end
end)

-- ------------------------------------------------------------------ start / stop

CreateThread(function()
    Wait(3000)
    TriggerServerEvent(EV .. 'sync')
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    poisoned = false
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if washPrompt then PromptDelete(washPrompt) end
    if drinkPrompt then PromptDelete(drinkPrompt) end
end)
