-- goldpan | client: taking the pan out, the prompt group and putting it away

local RES <const> = GetCurrentResourceName()
local P <const> = Config.Prompts

local group = GetRandomIntInRange(0, 0xffffff)
local searchPrompt, stopPrompt

CreateThread(function()
    searchPrompt = Cli.prompt(P.PanPrompt, P.PanName, group)
    stopPrompt = Cli.prompt(P.StopPrompt, P.StopName, group)
end)

local function mounted(ped)
    return Cli.yes(IsPedOnMount(ped)) or Cli.yes(IsPedInAnyVehicle(ped, false))
end

-- states in which the pan cannot be held
local function blocked(ped)
    return Cli.yes(IsEntityDead(ped)) or Cli.yes(IsPedSwimming(ped)) or Cli.yes(IsPedClimbing(ped))
        or Cli.yes(IsPedFalling(ped)) or mounted(ped)
end

-- put the pan away, abandoning any load being worked
function Pan.putAway()
    local ped = PlayerPedId()
    if Pan.working then
        Pan.session = Pan.session + 1
        Pan.cancelToken()
        ClearPedTasks(ped)
    end
    Cli.deleteEntity(Pan.prop)
    Pan.prop = nil
    Pan.out = false
    Pan.working = false
    Pan.token = nil
    TriggerEvent('panning:panning', false)
end

local function takeOut()
    local ped = PlayerPedId()
    if Pan.out or blocked(ped) then Cli.say('NoPan') return end
    local hash = Cli.loadModel(Config.Options.PanModel)
    if not hash then Cli.say('NoPan') return end
    -- re-check after the model load wait
    if Pan.out or blocked(ped) then SetModelAsNoLongerNeeded(hash) Cli.say('NoPan') return end
    local c = GetEntityCoords(ped)
    local prop = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not prop or prop == 0 then Cli.say('NoPan') return end
    SetEntityCollision(prop, false, false)
    Cli.attach(prop, ped, 'carry')
    Pan.prop = prop
    Pan.out = true
end

RegisterNetEvent('pup_goldpan:add', function()
    takeOut()
end)

-- local only: fired by the shovel resource while a dig runs
AddEventHandler('shoveling:shoveling', function(on)
    Pan.digging = on == true
end)

CreateThread(function()
    while true do
        if not Pan.out then
            Wait(200)
        else
            Wait(0)
            local ped = PlayerPedId()
            if blocked(ped) or not Cli.yes(DoesEntityExist(Pan.prop or 0)) then
                Pan.putAway()
            else
                PromptSetActiveGroupThisFrame(group, Cli.varString(P.Title))
                if Pan.working then
                    for _, control in ipairs(Config.BlockedWhileWorking) do
                        DisableControlAction(0, control, true)
                    end
                end
                if Cli.pressed(stopPrompt) then
                    Pan.putAway()
                elseif Cli.pressed(searchPrompt) and not mounted(ped) then
                    CreateThread(Pan.search)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    if Pan.working then ClearPedTasks(PlayerPedId()) end
    Pan.cancelToken()
    Cli.deleteEntity(Pan.prop)
    Pan.prop, Pan.out, Pan.working = nil, false, false
    TriggerEvent('panning:panning', false)
end)
