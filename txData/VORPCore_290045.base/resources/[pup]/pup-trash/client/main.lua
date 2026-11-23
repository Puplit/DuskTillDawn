-- One prompt group for every bin; the server opens them.

local promptGroup = GetRandomIntInRange(0, 0xffffff)
local prompt

CreateThread(function()
    Wait(1000)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.Keys.interact)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', Locale.prompt))
    PromptSetEnabled(prompt, 1)
    PromptSetVisible(prompt, 1)
    PromptSetStandardMode(prompt, 1)
    PromptSetGroup(prompt, promptGroup)
    PromptRegisterEnd(prompt)
end)

CreateThread(function()
    while true do
        local sleep = 500
        if prompt then
            local here <const> = GetEntityCoords(PlayerPedId())
            local reach <const> = tonumber(Config.Bins.promptRadius) or 2.0
            for _, can in ipairs(Config.BinLocations or {}) do
                if #(here - can.coords) <= reach then
                    sleep = 0
                    -- rebuilt every frame: a cached VarString points into a reused game buffer
                    PromptSetActiveGroupThisFrame(promptGroup,
                        CreateVarString(10, 'LITERAL_STRING', Locale.group))
                    if PromptHasStandardModeCompleted(prompt) then
                        TriggerServerEvent('pup-trash:open', can.id)
                        Wait(600)
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)
