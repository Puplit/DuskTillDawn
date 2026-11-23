-- pup_tailor | wearing a clothing item: change the ped, then save to VORP, the server and pup_clothing.
local Ped = Tailor.Ped
local S = Tailor.S
local Wear = Tailor.Wear

local function playAnim(ped, a)
    RequestAnimDict(a.dict)
    local deadline = GetGameTimer() + 2000
    while not HasAnimDictLoaded(a.dict) and GetGameTimer() < deadline do Wait(25) end
    if not HasAnimDictLoaded(a.dict) then return end
    TaskPlayAnim(ped, a.dict, a.clip, 5.0, 5.0, -1, 0, 0.0, false, false, false)
end

-- tints twice: once the ped is ready (3 s at most), then 600 ms later; a rebuild drops tints
local function tintTwice(colours)
    if not colours or next(colours) == nil then return end
    local ped = PlayerPedId()
    local deadline = GetGameTimer() + 3000
    while not Ped.isReady(ped) and GetGameTimer() < deadline do Wait(50) end
    Ped.applyColours(ped, colours)
    Wait(600)
    Ped.applyColours(PlayerPedId(), colours)
end

local function save(change, sex)
    local vorp = Wear.toVorp(change.result, change.colors)
    local str = json.encode(vorp)
    -- vorp_character first; our server copy has to land last
    TriggerEvent('vorpcharacter:savenew', str)
    local extras = Wear.extras(change, sex)
    local tints, n = Wear.toTints(vorp)
    SetTimeout(300, function()
        TriggerServerEvent('pup_tailor:saveWorn', str)
        if next(extras) then TriggerServerEvent('pup_clothing:syncExtras', json.encode(extras)) end
        if n > 0 then TriggerServerEvent('pup_tailor:saveTints', json.encode(tints)) end
    end)
    if n > 0 then TriggerEvent('vorpcharacter:savetints', tints) end
end

local function change(data)
    local ped = PlayerPedId()
    local sex = Ped.sexOf(ped)
    local onFoot = not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)

    if onFoot then
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, true)
        pcall(function() exports['pup-ui']:Progress({ label = L('changing'), duration = 3500 }) end)
        Wait(500)
        playAnim(ped, Config.Anims.unholster)
        Wait(3000)
        playAnim(ped, Config.Anims.change)
    else
        Wait(3500)
    end

    local result = Wear.compute({
        whole = data.whole, outfit = data.outfit, dyed = data.dyed,
        sex = data.sex, worn = data.worn, keep = data.keep,
    })
    ped = PlayerPedId()
    for slot in pairs(result.removed) do Ped.removeSlot(ped, slot) end
    for slot, h in pairs(result.putOn) do Ped.putOn(ped, slot, h, sex) end
    Ped.refresh(ped)

    save(result, sex)
    tintTwice(result.colors)

    if onFoot then Wait(1500) end
end

RegisterNetEvent('pup_tailor:wear', function(data)
    TriggerEvent('vorp_inventory:CloseInv')
    if type(data) ~= 'table' or type(data.outfit) ~= 'table' then return end
    local ped = PlayerPedId()
    if S.changing or S.session or Ped.blocked(ped) then
        return Tailor.tip(L('cantChangeNow'), 4000)
    end
    local mySex = Ped.sexOf(ped)
    local itemSex = data.sex == 'female' and 'female' or 'male'
    if itemSex ~= mySex then
        return Tailor.tip(itemSex == 'male' and L('madeForMales') or L('madeForFemales'), 6000)
    end
    S.changing = true
    CreateThread(function()
        local ok, err = pcall(change, data)
        if not ok then print(('[pup_tailor] clothes change failed: %s'):format(tostring(err))) end
        local p = PlayerPedId()
        FreezeEntityPosition(p, false)
        ClearPedTasks(p)
        S.changing = false
    end)
end)

---------------------------------------------------------------------------
-- after a VORP clothing reload, put back the dye of what THIS character wears
---------------------------------------------------------------------------
local reloadSeq = 0

Tailor.Wear.characterChanged = function()
    reloadSeq = reloadSeq + 1
end

AddEventHandler('vorp_character:client:reloadedComponents', function()
    reloadSeq = reloadSeq + 1
    local seq = reloadSeq
    CreateThread(function()
        local colours = Tailor.ask('wornColours', 5000)
        if seq ~= reloadSeq or type(colours) ~= 'table' or next(colours) == nil then return end
        for _ = 1, 2 do Ped.applyColours(PlayerPedId(), colours) end
        Wait(1500)
        if seq ~= reloadSeq then return end
        for _ = 1, 2 do Ped.applyColours(PlayerPedId(), colours) end
    end)
end)
