-- pup_clothing | blips, the prompt, page set-up and the client's lifecycle.

local Cat = PC.Cat
local Main = {}
PC.Main = Main

local hidden = false
function Main.promptHidden(v) hidden = v == true end

---------------------------------------------------------------------------
-- blips
---------------------------------------------------------------------------
local blips = {}
local function addBlip(pt, look, name)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, Config.Blips.style, pt.x, pt.y, pt.z)
    if not blip or blip == 0 then return end
    SetBlipSprite(blip, look.sprite, true)
    SetBlipScale(blip, look.scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, name)
    blips[#blips + 1] = blip
end

CreateThread(function()
    for _, pt in ipairs(Config.Stores) do
        if pt.enabled ~= false and pt.blip then addBlip(pt, Config.Blips.store, L('blipStore')) end
    end
    for _, pt in ipairs(Config.Wardrobes) do
        if pt.enabled ~= false and pt.blip then addBlip(pt, Config.Blips.wardrobe, L('blipWardrobe')) end
    end
end)

---------------------------------------------------------------------------
-- the prompt: one hold prompt shared by stores and wardrobes
---------------------------------------------------------------------------
local group, prompt = nil, nil

local function buildPrompt()
    group = GetRandomIntInRange(0, 0xffffff)
    prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, Config.Prompt.key)
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', L('promptOpen')))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetHoldMode(prompt, Config.Prompt.holdMs)
    UiPromptSetGroup(prompt, group, 0)
    UiPromptRegisterEnd(prompt)
end

local function nearest(pos, list)
    local best, bestD = nil, nil
    for _, pt in ipairs(list) do
        if pt.enabled ~= false then
            local dx, dy, dz = pos.x - pt.x, pos.y - pt.y, pos.z - pt.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if not bestD or d < bestD then best, bestD = pt, d end
        end
    end
    return best, bestD
end

CreateThread(function()
    if Config.Timing.promptDelayMs > 0 then Wait(Config.Timing.promptDelayMs) end
    buildPrompt()
    local P = Config.Prompt
    local cooldownUntil = 0
    while true do
        local sleep = P.farSleep
        if not hidden and not IsEntityDead(PlayerPedId()) then
            local pos = GetEntityCoords(PlayerPedId())
            local sPt, sD = nearest(pos, Config.Stores)
            local wPt, wD = nearest(pos, Config.Wardrobes)
            local nearD = math.min(sD or math.huge, wD or math.huge)
            if nearD <= P.nearMargin then sleep = P.nearSleep end

            local kind = nil
            if sPt and sD <= (sPt.tight and P.tightRadius or P.radius) then
                kind = 'store'
            elseif wPt and wD <= (wPt.tight and P.tightRadius or P.radius) then
                kind = 'wardrobe'
            end
            if kind then
                local title = kind == 'store' and L('storeTitle') or L('wardrobeTitle')
                UiPromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', title), 0, 0, 0, 0)
                if GetGameTimer() > cooldownUntil and UiPromptHasHoldModeCompleted(prompt) then
                    cooldownUntil = GetGameTimer() + 1500
                    if kind == 'store' then PC.Store.request() else PC.Wardrobe.request() end
                end
            end
        else
            sleep = 500
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- page set-up: theme, words and menu side
---------------------------------------------------------------------------
RegisterNUICallback('ready', function(_, cb)
    local theme = nil
    pcall(function() theme = exports['pup-ui']:GetTheme() end)
    local side = 'left'
    pcall(function() side = exports['pup-ui']:GetMenuSide() or 'left' end)
    cb({ theme = theme, text = Locale.page, side = side })
end)

AddEventHandler('pup-ui:menuSide', function(side)
    SendNUIMessage({ action = 'menuSide', side = (side == 'right') and 'right' or 'left' })
end)

CreateThread(function()
    Wait(Config.Timing.hudAskMs)
    TriggerEvent('fred_hud:reapplyLayout')
end)

---------------------------------------------------------------------------
-- characters
---------------------------------------------------------------------------
local selectGen = 0
RegisterNetEvent('vorp:SelectedCharacter', function()
    selectGen = selectGen + 1
    local gen = selectGen
    -- a new character starts with nothing of the last one
    PC.Store.forceClose()
    PC.Wardrobe.close(false)
    PC.Toggles.clear()
    PC.Extras.own = {}
    PC.Extras.foreign = false
    SetTimeout(Config.Timing.extrasAfterSelect, function()
        if gen == selectGen then PC.Extras.request(true) end
    end)
end)

AddEventHandler('vorp:initNewCharacter', function()
    if not Config.Starter.enabled then return end
    SetTimeout(Config.Starter.delayMs, function()
        TriggerServerEvent('pup_clothing:starter')
    end)
end)

---------------------------------------------------------------------------
-- /closeui: leave the store or the wardrobe, whatever state the page is in
---------------------------------------------------------------------------
RegisterCommand('closeui', function()
    if PC.Store.isOpen() then
        PC.Store.cancel()
    elseif PC.Wardrobe.isOpen() then
        PC.Wardrobe.close()
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        hidden = false
    end
end, false)

---------------------------------------------------------------------------
-- singleplayer garments, then let the page know the store can list them
---------------------------------------------------------------------------
Cat.loadNpcWhenReady(function()
    PC.Store.dropItemCache()
end)

---------------------------------------------------------------------------
-- stop
---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local storeOpen = PC.Store.isOpen()
    local wardrobeOpen = PC.Wardrobe.isOpen()
    if storeOpen or wardrobeOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        TriggerEvent('vorp_inventory:Client:DisableInventory', false)
    end
    if storeOpen then
        FreezeEntityPosition(PlayerPedId(), false)
        RenderScriptCams(false, false, 0, true, true)
        DisplayHud(true)
        DisplayRadar(true)
    end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    if prompt then UiPromptDelete(prompt) end
end)
