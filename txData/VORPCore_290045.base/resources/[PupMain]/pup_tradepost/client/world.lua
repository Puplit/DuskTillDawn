-- Map blips and the counter prompt.

local BLIP_STYLE <const> = 1664425300 -- plain coordinate blip

local blips = {}
local promptGroup = 0
local prompt = nil

local function makeBlips()
    for _, m in ipairs(Config.Markets) do
        if m.blip then
            local c = m.coords
            local blip = BlipAddForCoords(BLIP_STYLE, c.x, c.y, c.z)
            SetBlipSprite(blip, m.blip.sprite, true)
            SetBlipScale(blip, m.blip.scale or 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, m.name) -- SetBlipName
            blips[#blips + 1] = blip
        end
    end
end

local function makePrompt()
    promptGroup = GetRandomIntInRange(0, 0xffffff)
    prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, Config.Prompt.key)
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', Lang.prompt))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetStandardMode(prompt, true)
    UiPromptSetGroup(prompt, promptGroup, 0)
    UiPromptRegisterEnd(prompt)
end

-- the first counter within reach, or nil
local function counterInReach(pos)
    local reach = Config.Prompt.distance
    for _, m in ipairs(Config.Markets) do
        if #(pos - m.coords) <= reach then return m end
    end
    return nil
end

CreateThread(function()
    makeBlips()
    makePrompt()
    while true do
        local sleep = Config.Prompt.farPoll
        local ped = PlayerPedId()
        if not TP.PanelOpen() and not IsEntityDead(ped) then
            local m = counterInReach(GetEntityCoords(ped))
            if m then
                sleep = 0
                UiPromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', m.name or Lang.panelTitle), 0, 0, 0, 0)
                TriggerEvent('pup:promptYield', 250)
                if UiPromptHasStandardModeCompleted(prompt, 0) then
                    TP.OpenPanel(m.key)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= TP.Res then return end
    for _, b in ipairs(blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blips = {}
    if prompt then UiPromptDelete(prompt) end
    prompt = nil
    TP.ClosePanel()
end)
