-- The Craft prompt near named stations and station props.
Stations = {}

-- seed list from config until the server sends the live one
for i, s in ipairs(Config.SeedStations) do
    Stations[i] = { name = s.name, x = s.x, y = s.y, z = s.z }
end

RegisterNetEvent('pup_workbench:stations', function(list)
    if type(list) ~= 'table' then return end
    local out = {}
    for _, s in ipairs(list) do
        if type(s) == 'table' and type(s.name) == 'string' and tonumber(s.x) and tonumber(s.y) and tonumber(s.z) then
            out[#out + 1] = { name = s.name, x = tonumber(s.x), y = tonumber(s.y), z = tonumber(s.z) }
        end
    end
    Stations = out
end)

local propModels = {}
for model, label in pairs(Config.StationProps) do
    propModels[#propModels + 1] = { model = model, hash = joaat(model), label = label }
end

local prompt, group = nil, nil

local function makePrompt()
    group = GetRandomIntInRange(0, 0xffffff)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.Prompt.key)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', L('prompt_craft')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetStandardMode(prompt, true)
    PromptSetGroup(prompt, group, 0)
    PromptRegisterEnd(prompt)
end

local function canUse(ped)
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return false end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return false end
    if Bench.open or Craft.busy then return false end
    return true
end

--- What bench is the player standing at, if any? Named stations win.
local function scan(ped)
    local c = GetEntityCoords(ped)
    local here = { x = c.x, y = c.y, z = c.z }
    for _, s in ipairs(Stations) do
        if WB.dist(here, s) <= Config.Prompt.stationReach then
            return { mode = 'station', name = s.name, label = s.name:upper() }
        end
    end
    for _, p in ipairs(propModels) do
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, Config.Prompt.propReach, p.hash, false, false, false)
        if obj and obj ~= 0 then
            local oc = GetEntityCoords(obj)
            return { mode = 'prop', model = p.model, label = p.label or L('bench_prop'),
                     pos = { x = oc.x, y = oc.y, z = oc.z } }
        end
    end
    return nil
end

CreateThread(function()
    makePrompt()
    local found, nextScan = nil, 0
    while true do
        local ped = PlayerPedId()
        if not canUse(ped) then
            found = nil
            Wait(Config.Prompt.idleCheckMs)
        else
            local now = GetGameTimer()
            if now >= nextScan then
                found = scan(ped)
                nextScan = now + (found and 250 or 0)
            end
            if found then
                PromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', found.label))
                if PromptHasStandardModeCompleted(prompt) then
                    local at = found
                    found = nil
                    Bench.openAt(at)
                    Wait(500)
                end
                Wait(0)
            else
                Wait(Config.Prompt.idleCheckMs)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if prompt then PromptDelete(prompt) end
end)
