-- pup_mercantile | client state, shop list, blips, prompts and shopkeepers

St = {
    shops = { player = {}, society = {} },
    catalogue = nil,
    charid = nil,
    job = nil,
    inStore = false,    -- standing at a counter (frozen)
    venue = nil,        -- { kind = 'npc'|'player'|'society', id }
    gridOpen = false,
    returnToDash = false,
    moveMode = false,
    creating = false,
    sceneBlocked = false,
    raidJobs = nil,     -- { [job] = true } from pup-mdt, for the raid prompt only
    adminView = nil,    -- { kind, id } while staff look at a shop grid from vorp_admin
}

local function setRaidJobs(list)
    if type(list) ~= 'table' then return end
    local set = {}
    for _, j in pairs(list) do
        if type(j) == 'string' then set[j] = true end
    end
    St.raidJobs = set
end

function Tip(text, ms)
    TriggerEvent('vorp:TipBottom', tostring(text), ms or 4000)
end

------------------------------------------------------------------------------
-- blips
------------------------------------------------------------------------------
local blips = {} -- [key] = handle

local function removeBlip(key)
    if blips[key] then
        RemoveBlip(blips[key])
        blips[key] = nil
    end
end

local function addBlip(key, coords, sprite, name)
    removeBlip(key)
    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0) -- BlipAddForCoords
    if not b or b == 0 then return end
    SetBlipSprite(b, sprite, true)
    SetBlipScale(b, Config.BlipScale)
    Citizen.InvokeNative(0x9CB1A1623062F402, b, tostring(name)) -- SetBlipName
    blips[key] = b
end

local function shopKey(kind, id) return kind .. ':' .. tostring(id) end

local function refreshShopBlip(e)
    local key = shopKey(e.kind, e.id)
    if not e.blip then return removeBlip(key) end
    local sprite = e.kind == 'player' and Config.PlayerShops.blipSprite or Config.SocietyShops.blipSprite
    addBlip(key, e.coords, sprite, e.name)
end

local function npcBlips()
    for i, s in ipairs(NpcStoreList) do
        if s.blip and s.pos then addBlip('npc:' .. i, s.pos, s.blip, s.name) end
    end
end

------------------------------------------------------------------------------
-- shop list from the server (never carries owner or manager ids)
------------------------------------------------------------------------------
local function setShops(list)
    for _, kind in ipairs({ 'player', 'society' }) do
        for id in pairs(St.shops[kind]) do removeBlip(shopKey(kind, id)) end
        St.shops[kind] = {}
    end
    for _, e in ipairs(list or {}) do
        if St.shops[e.kind] then
            St.shops[e.kind][e.id] = e
            refreshShopBlip(e)
        end
    end
end

function ShopEntry(kind, id)
    return St.shops[kind] and St.shops[kind][id] or nil
end

-- the dashboard renames or hides a shop locally at once; the server saves it when the visit ends
function LocalShopUpdate(kind, id, fields)
    local e = ShopEntry(kind, id)
    if not e then return end
    for k, v in pairs(fields) do e[k] = v end
    refreshShopBlip(e)
end

-- early warning only (the server re-checks): any known shop of either kind too close to pos
function NearOtherShop(pos, ignoreKind, ignoreId)
    local min = Config.Shops.minSpacing
    for _, kind in ipairs({ 'player', 'society' }) do
        for id, e in pairs(St.shops[kind]) do
            if not (kind == ignoreKind and id == ignoreId) then
                local d = #(pos - vector3(e.coords.x, e.coords.y, e.coords.z))
                if d < min then return true end
            end
        end
    end
    return false
end

RegisterNetEvent('pup_mercantile:init', function(data)
    if type(data) ~= 'table' then return end
    St.charid, St.job = data.charid, data.job
    if type(data.catalogue) == 'table' then St.catalogue = data.catalogue end
    setRaidJobs(data.raidJobs)
    setShops(data.shops)
end)

RegisterNetEvent('pup_mercantile:raid:jobs', function(list)
    setRaidJobs(list)
end)

local requestInit

RegisterNetEvent('pup_mercantile:shops:full', function(list)
    setShops(list)
    -- on a resource restart the first init can arrive before the server is ready,
    -- which leaves the Add Items catalogue empty; ask again now that it is
    if St.catalogue == nil and requestInit then requestInit() end
end)

RegisterNetEvent('pup_mercantile:shop:upsert', function(e)
    if type(e) ~= 'table' or not St.shops[e.kind] then return end
    St.shops[e.kind][e.id] = e
    refreshShopBlip(e)
end)

RegisterNetEvent('pup_mercantile:shop:remove', function(kind, id)
    if not St.shops[kind] then return end
    St.shops[kind][id] = nil
    removeBlip(shopKey(kind, id))
end)

requestInit = function()
    TriggerServerEvent('pup_mercantile:init', St.catalogue == nil)
end

CreateThread(function()
    Wait(1000)
    npcBlips()
    requestInit()
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    LeaveEverything()
    SetTimeout(1000, requestInit)
end)

-- registered as a net event so it is heard whether pup-scene fires it locally or from the server
RegisterNetEvent('pup-scene:stopscene', function(allowed)
    St.sceneBlocked = allowed == false
end)

------------------------------------------------------------------------------
-- prompts: idle checks twice a second, per-frame work only while one is shown
------------------------------------------------------------------------------
local function idleOk(ped)
    return not St.inStore and not St.moveMode and not St.creating and not St.sceneBlocked
        and not St.adminView and not IsPedOnMount(ped) and not IsEntityDead(ped)
end

-- a hint for showing the raid prompt: law job and rank from the character state.
-- Duty, distance and everything else are decided by the server.
local function mayRaidHint()
    if not Config.Raid.enabled or not St.raidJobs then return false end
    local ch = LocalPlayer.state.Character
    if type(ch) ~= 'table' then return false end
    return St.raidJobs[tostring(ch.Job)] == true and (tonumber(ch.Grade) or -1) >= Config.Raid.minGrade
end

local function findTarget(pos)
    local best, bestD
    local npcR = Config.NpcStores.promptDistance
    for i, s in ipairs(NpcStoreList) do
        if not s.menuOnly and s.pos then
            local d = #(pos - vector3(s.pos.x, s.pos.y, s.pos.z))
            if d <= npcR and (not bestD or d < bestD) then
                best, bestD = { kind = 'npc', id = i, title = s.name, label = Util.L('promptMenu'), at = s.pos }, d
            end
        end
    end
    local shopR = Config.Shops.promptDistance
    local raider = mayRaidHint()
    for _, kind in ipairs({ 'player', 'society' }) do
        for id, e in pairs(St.shops[kind]) do
            local d = #(pos - vector3(e.coords.x, e.coords.y, e.coords.z))
            if d <= shopR and (not bestD or d < bestD) then
                local title = e.name
                if kind == 'society' then title = title .. Util.L('suffixSociety')
                elseif e.mine then title = title .. Util.L('suffixMine') end
                best, bestD = {
                    kind = kind, id = id, title = title, at = e.coords, manage = e.mine == true,
                    label = e.mine and Util.L('promptManage') or Util.L('promptBrowse'),
                    raid = raider and kind == 'player' and not e.mine,
                }, d
            end
        end
    end
    return best
end

local function makePrompt(group, text)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, Config.InteractKey)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', text))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

local promptHandle, raidHandle

-- the held raid prompt, in the same group as the counter prompt
local function makeRaidPrompt(group)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, Config.Raid.key)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', Util.L('promptRaid')))
    PromptSetEnabled(p, false)
    PromptSetVisible(p, false)
    PromptSetHoldMode(p, Config.Raid.holdMs)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

local function showRaid(on)
    PromptSetEnabled(raidHandle, on)
    PromptSetVisible(raidHandle, on)
end

CreateThread(function()
    local group = GetRandomIntInRange(0, 0xffffff)
    local label = Util.L('promptMenu')
    promptHandle = makePrompt(group, label)
    raidHandle = makeRaidPrompt(group)
    while true do
        local ped = PlayerPedId()
        local target = idleOk(ped) and findTarget(GetEntityCoords(ped)) or nil
        if not target then
            Wait(500)
        else
            if target.label ~= label then
                label = target.label
                PromptSetText(promptHandle, CreateVarString(10, 'LITERAL_STRING', label))
            end
            showRaid(target.raid == true)
            local titleVar = CreateVarString(10, 'LITERAL_STRING', target.title)
            local nextCheck, nextYield = 0, 0
            while true do
                local now = GetGameTimer()
                if now >= nextCheck then
                    nextCheck = now + 250
                    ped = PlayerPedId()
                    local again = idleOk(ped) and findTarget(GetEntityCoords(ped)) or nil
                    if not again or again.kind ~= target.kind or again.id ~= target.id or again.label ~= target.label
                        or again.raid ~= target.raid then break end
                end
                if now >= nextYield then
                    nextYield = now + 200
                    TriggerEvent('pup:promptYield', 250)
                end
                PromptSetActiveGroupThisFrame(group, titleVar)
                if PromptHasStandardModeCompleted(promptHandle) then
                    if target.kind == 'npc' then OpenNpcStore(target.id) else EnterShop(target.kind, target.id, target.manage) end
                    Wait(300)
                    break
                end
                if target.raid and PromptHasHoldModeCompleted(raidHandle) then
                    TriggerServerEvent('pup_mercantile:raid:start', target.id)
                    Wait(1000)
                    break
                end
                Wait(0)
            end
            showRaid(false)
        end
    end
end)

------------------------------------------------------------------------------
-- optional shopkeepers
------------------------------------------------------------------------------
local peds = {}

local function spawnKeeper(i, k)
    local model = type(k.model) == 'number' and k.model or joaat(k.model)
    if not IsModelValid(model) then return end
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(model) then return end
    local x, y, z = k.pos.x + 0.0, k.pos.y + 0.0, k.pos.z + 0.0
    if k.snapToGround then
        local found, gz = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
        if found then z = gz end
    end
    local ped = CreatePed(model, x, y, z, (k.heading or 0.0) + 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    peds[i] = ped
end

CreateThread(function()
    if #(Config.Shopkeepers or {}) == 0 then return end
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, k in ipairs(Config.Shopkeepers) do
            local d = #(pos - vector3(k.pos.x, k.pos.y, k.pos.z))
            local radius = k.radius or 60.0
            if d <= radius and not peds[i] then
                spawnKeeper(i, k)
            elseif d > radius * 1.2 and peds[i] then
                DeletePed(peds[i])
                peds[i] = nil
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(blips) do removeBlip(key) end
    for i, p in pairs(peds) do
        if DoesEntityExist(p) then DeletePed(p) end
        peds[i] = nil
    end
    LeaveEverything(true)
end)

exports('StoreIdByName', function(storeName)
    for i, s in ipairs(NpcStoreList) do
        if s.name == storeName then return i end
    end
    return nil
end)
