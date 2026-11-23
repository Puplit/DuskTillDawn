-- The "open menu" prompt, start-up requests, character select and shutdown.

PC = PC or {}

local promptGroup = 0
local prompt = nil

local function makePrompt()
    promptGroup = GetRandomIntInRange(0, 0xffffff)
    prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, Config.Keys.openMenu)
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', Lang.promptLabel))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetStandardMode(prompt, true)
    UiPromptSetGroup(prompt, promptGroup, 0)
    UiPromptRegisterEnd(prompt)
end

-- the client-side mirror of the job lock; only hides the prompt, the server re-checks
local function mayUse(p)
    if PC.IsStaff or p.job == '' then return true end
    local c = LocalPlayer.state.Character
    if type(c) ~= 'table' or type(c.Job) ~= 'string' then return false end
    return c.Job:lower() == p.job:lower() and (tonumber(c.Grade) or 0) >= p.rank
end

-- the nearest usable spawned phonograph within prompt range, or nil
local function nearby(pos)
    local best, bestD = nil, Config.Ranges.prompt
    for id, ent in pairs(PC.Spawned) do
        local p = PC.Phonos[id]
        if p and DoesEntityExist(ent) then
            local d = #(pos - GetEntityCoords(ent))
            if d <= bestD and mayUse(p) then best, bestD = id, d end
        end
    end
    return best
end

CreateThread(function()
    makePrompt()
    while true do
        local sleep = 400
        if not PC.Placing and next(PC.Spawned) ~= nil then
            local ped = PlayerPedId()
            if not IsEntityDead(ped) then
                local id = nearby(GetEntityCoords(ped))
                if id then
                    sleep = 0
                    TriggerEvent('pup:promptYield', 250)
                    UiPromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', Lang.promptGroup), 0, 0, 0, 0)
                    if UiPromptHasStandardModeCompleted(prompt, 0) then
                        TriggerServerEvent('pup-phonograph:server:openMenu', id)
                        sleep = 500
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('pup-phonograph:client:staff', function(isStaff)
    PC.IsStaff = isStaff == true
end)

-- start-up: the phonograph list, staff status and whatever is playing nearby
CreateThread(function()
    TriggerServerEvent('pup-phonograph:server:requestList')
    TriggerServerEvent('pup-phonograph:server:requestStaff')
    TriggerServerEvent('pup-phonograph:server:resync')
end)

-- one handler for character select / switch
RegisterNetEvent('vorp:SelectedCharacter', function()
    PC.AbortPlacement()
    PC.StopAllSounds()
    TriggerServerEvent('pup-phonograph:server:resync')
    -- the server sends staff status itself on character select
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= PC.Res then return end
    PC.AbortPlacement()
    PC.StopAllSounds()
    PC.DespawnAll()
    if prompt then UiPromptDelete(prompt) end
    prompt = nil
end)
