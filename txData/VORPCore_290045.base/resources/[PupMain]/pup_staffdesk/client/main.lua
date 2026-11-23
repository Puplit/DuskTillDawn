-- pup_staffdesk | client: desk blips and prompt, height preview, teleports from the bridge
local blips = {}

CreateThread(function()
    for _, d in pairs(Config.Desks) do
        if d.blip then
            local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, d.coords.x, d.coords.y, d.coords.z) -- BLIP_ADD_FOR_COORDS
            SetBlipSprite(b, d.blip, true)
            SetBlipScale(b, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, b, d.name)                                             -- SET_BLIP_NAME
            blips[#blips + 1] = b
        end
    end
end)

local function nearDesk()
    local pos = GetEntityCoords(PlayerPedId())
    for _, d in pairs(Config.Desks) do
        if #(pos - d.coords) <= Config.General.deskDistance then return d end
    end
end

function DeskNear() return nearDesk() ~= nil end

-- the game's own prompt at the desk: the action under the desk's name
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local openPrompt = nil

local function deskPrompt(title)
    if not openPrompt then
        openPrompt = PromptRegisterBegin()
        PromptSetControlAction(openPrompt, Config.Keys.open)
        PromptSetText(openPrompt, CreateVarString(10, 'LITERAL_STRING', Locale.prompt))
        PromptSetEnabled(openPrompt, true)
        PromptSetVisible(openPrompt, true)
        PromptSetStandardMode(openPrompt, true)
        PromptSetGroup(openPrompt, promptGroup)
        PromptRegisterEnd(openPrompt)
    end
    PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', title or Locale.prompt))
    return PromptHasStandardModeCompleted(openPrompt)
end

CreateThread(function()
    while true do
        local wait = 750
        if not DeskPanel.isOpen() and not IsEntityDead(PlayerPedId()) then
            local d = nearDesk()
            if d then
                wait = 0
                if deskPrompt(d.name) then DeskPanel.open('desk', d.name) end
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and openPrompt then PromptDelete(openPrompt) end
end)

RegisterNetEvent('pup_staffdesk:open', function(mode) DeskPanel.open(mode) end)

-------------------------------------------------------------------------------
-- HEIGHT
-------------------------------------------------------------------------------
local previewing = 0

-- SET_PED_SCALE alone is undone by the next redraw of the ped, so redraw it at once
-- (the same three natives vorp_character uses to commit a height)
local function setScale(scale)
    local ped = PlayerPedId()
    Citizen.InvokeNative(0x25ACFC650B65C538, ped, scale + 0.0) -- SET_PED_SCALE
    UpdatePedVariation(ped)
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- show a height for a few seconds, then go back to the saved one
function DeskHeightPreview(scale, back, done)
    previewing = previewing + 1
    local mine = previewing
    setScale(scale)
    TriggerEvent('vorp:TipRight', Locale.previewing:format(math.floor(scale * 100 + 0.5), Config.Height.previewSeconds), 4000)
    SetTimeout(Config.Height.previewSeconds * 1000, function()
        if previewing == mine then
            setScale(back or 1.0)
            if done then done() end
        end
    end)
end

-- the server saved a new height: reload the character so vorp applies it everywhere
RegisterNetEvent('pup_staffdesk:heightChanged', function(scale)
    previewing = previewing + 1
    setScale(scale)
    if DeskPanel.isOpen() then DeskPanel.close() end
    Wait(500)
    ExecuteCommand('rc')
end)

-------------------------------------------------------------------------------
-- TELEPORT  (sent only by the server, from the Discord bridge)
-------------------------------------------------------------------------------
RegisterNetEvent('pup_staffdesk:teleport', function(x, y, z, h)
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    local t = GetGameTimer()
    while not IsScreenFadedOut() and GetGameTimer() - t < 1500 do Wait(0) end

    -- move the horse or wagon with them, or they are pulled out of it
    local ent = ped
    if IsPedOnMount(ped) then ent = GetMount(ped)
    elseif IsPedInAnyVehicle(ped, false) then ent = GetVehiclePedIsIn(ped, false) end
    if not ent or ent == 0 then ent = ped end

    SetEntityCoordsAndHeading(ent, x + 0.0, y + 0.0, z + 0.0, (h or GetEntityHeading(ent)) + 0.0, false, false, false)
    RequestCollisionAtCoord(x, y, z)
    t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() - t < 5000 do Wait(0) end
    Wait(250)
    DoScreenFadeIn(600)
    TriggerEvent('vorp:TipRight', Locale.teleported, 4000)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    if DeskPanel.isOpen() then exports['pup-ui']:CloseApp() end
end)
