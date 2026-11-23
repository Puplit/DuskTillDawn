-- pup_clothing | the wardrobe: a list of saved outfits to wear or delete.

local U, Ped = PC.U, PC.Ped
local Wardrobe = {}
PC.Wardrobe = Wardrobe

local W = { open = false, gen = 0, asked = 0 }

function Wardrobe.isOpen() return W.open end

local function focusLoop(gen)
    CreateThread(function()
        local K = Config.Keys
        while W.open and W.gen == gen do
            DisableAllControlActions(0)
            EnableControlAction(0, K.pushToTalk, true)
            local state = LocalPlayer.state
            if state.pup_ptt_latched then SetControlNormal(0, K.pushToTalk, 1.0) end
            if state.pup_radio_talking then
                EnableControlAction(0, K.radioTalk, true)
                SetControlNormal(0, K.radioTalk, 1.0)
            end
            if IsEntityDead(PlayerPedId()) then
                Wardrobe.close()
                break
            end
            Wait(0)
        end
    end)
end

local function show(list)
    W.open = true
    W.gen = W.gen + 1
    SendNUIMessage({ action = 'openWardrobe', outfits = list, text = Locale.page })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    TriggerEvent('vorp_inventory:Client:DisableInventory', true)
    PC.Main.promptHidden(true)
    focusLoop(W.gen)
end

-- close the list; tellServer = false when the server already ended the visit
function Wardrobe.close(tellServer)
    if not W.open then return end
    W.open = false
    W.gen = W.gen + 1
    SendNUIMessage({ action = 'closeWardrobe' })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    TriggerEvent('vorp_inventory:Client:DisableInventory', false)
    PC.Main.promptHidden(false)
    if tellServer ~= false then TriggerServerEvent('pup_clothing:closed') end
end

function Wardrobe.request()
    if W.open or (PC.Store and PC.Store.isOpen()) then return end
    W.asked = GetGameTimer()
    TriggerServerEvent('pup_clothing:openWardrobe')
end

local function cleanList(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, o in ipairs(list) do
        local id = U.int(o.id)
        if id then out[#out + 1] = { id = id, title = tostring(o.title or '') } end
    end
    return out
end

RegisterNetEvent('pup_clothing:outfits', function(list)
    list = cleanList(list)
    if W.open then
        SendNUIMessage({ action = 'outfits', outfits = list })
    elseif GetGameTimer() - W.asked < 10000 and not (PC.Store and PC.Store.isOpen()) then
        W.asked = 0
        show(list)
    end
end)

RegisterNUICallback('wardrobe:close', function(_, cb)
    cb({})
    Wardrobe.close()
end)

RegisterNUICallback('wardrobe:delete', function(data, cb)
    cb({})
    local id = type(data) == 'table' and U.int(data.id) or nil
    if not W.open or not id then return end
    TriggerServerEvent('pup_clothing:deleteOutfit', id)
end)

RegisterNUICallback('wardrobe:wear', function(data, cb)
    cb({})
    local id = type(data) == 'table' and U.int(data.id) or nil
    if not W.open or not id then return end
    Wardrobe.close(false)
    TriggerServerEvent('pup_clothing:wearOutfit', id)
end)

-- the server has saved the outfit as the current clothes
RegisterNetEvent('pup_clothing:worn', function(compsJson, extrasJson)
    if type(compsJson) ~= 'string' then return end
    CreateThread(function()
        Ped.rebuildWith(compsJson)
        if type(extrasJson) == 'string' and extrasJson ~= '' then
            local map = PC.Extras.parse(extrasJson)
            PC.Extras.own = map
            PC.Extras.foreign = false
            PC.Extras.apply(map)
            SetTimeout(Config.Timing.outfitReapplyMs, function()
                if not PC.Extras.foreign then PC.Extras.apply(PC.Extras.own) end
            end)
        end
        Ped.clean(PlayerPedId())
    end)
end)
