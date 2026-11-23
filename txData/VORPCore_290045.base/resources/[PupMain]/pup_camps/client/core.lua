-- pup_camps | client core: state from the server, request helper, small game helpers

State = {
    started  = false,
    charid   = nil,
    myCamp   = 0,
    camps    = {},     -- [id] = view sent by the server (what this player may know)
    busy     = false,  -- a camp menu, placement, founding or similar is running
    invites  = {},     -- [campId] = name (this session)
}

------------------------------------------------------------------------------ requests
-- Every call to the server goes through one net event and comes back with a token.
-- The server decides; the client only shows the answer.

local pending, nextToken = {}, 0

function Request(name, ...)
    nextToken = nextToken + 1
    local token = nextToken
    local p = promise.new()
    pending[token] = p
    TriggerServerEvent('pup_camps:sv:req', token, name, ...)
    SetTimeout(15000, function()
        if pending[token] then
            pending[token] = nil
            p:resolve({ n = 0 })
        end
    end)
    local r = Citizen.Await(p)
    return r[1], r[2]
end

RegisterNetEvent('pup_camps:cl:reply', function(token, a, b)
    local p = pending[token]
    if not p then return end
    pending[token] = nil
    p:resolve({ a, b, n = 2 })
end)

-- a request whose refusal message (second value) is shown to the player
function Ask(name, ...)
    local a, b = Request(name, ...)
    if not a and type(b) == 'string' and b ~= '' then Notify(b) end
    return a, b
end

------------------------------------------------------------------------------ notices

function Notify(msg, ms)
    if not msg or msg == '' then return end
    TriggerEvent('vorp:TipRight', tostring(msg), ms or 5000)
end

function NotifyBottom(msg, ms)
    if not msg or msg == '' then return end
    TriggerEvent('vorp:TipBottom', tostring(msg), ms or 6000)
end

function DrawHint(text, y)
    SetTextScale(0.38, 0.38)
    SetTextColor(255, 255, 255, 235)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 200)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), 0.5, y or 0.88)
end

function UiRunning()
    return GetResourceState('pup-ui') == 'started'
end

------------------------------------------------------------------------------ positions

function PedPos()
    local c = GetEntityCoords(PlayerPedId())
    return { x = c.x, y = c.y, z = c.z }
end

function ToVec(t)
    return vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0)
end

function MyCamp()
    if not State.myCamp or State.myCamp == 0 then return nil end
    return State.camps[State.myCamp]
end

-- camp a player stands at (flag within the given distance)
function CampNear(pos, dist)
    local best, bestD
    for _, camp in pairs(State.camps) do
        if not camp.repo then
            local d = U.dist3(pos, camp.coords)
            if d <= dist and (not bestD or d < bestD) then best, bestD = camp, d end
        end
    end
    return best, bestD
end

------------------------------------------------------------------------------ game helpers

-- guarded native call: a native that is missing on this game build must not kill a thread
function N(hash, ...)
    local ok, a, b, c = pcall(Citizen.InvokeNative, hash, ...)
    if ok then return a, b, c end
    U.debug('native failed', hash, a)
    return nil
end

function LoadModel(model)
    if type(model) == 'string' then model = GetHashKey(model) end
    model = U.signed(model)
    if model == 0 or not IsModelValid(model) then return nil end
    if HasModelLoaded(model) then return model end
    RequestModel(model, false)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > t then return nil end
        Wait(20)
    end
    return model
end

function LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(20)
    end
    return true
end

function Scenario(name, ms)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    TaskStartScenarioInPlace(ped, GetHashKey(name), ms or -1, true, false, false, false)
end

function StopScenario()
    ClearPedTasks(PlayerPedId())
end

function FaceEntity(ent)
    local ped = PlayerPedId()
    if ent and DoesEntityExist(ent) then
        TaskTurnPedToFaceEntity(ped, ent, 1000)
        Wait(900)
    end
end

function FadeOut(ms)
    DoScreenFadeOut(ms or 500)
    local t = GetGameTimer() + (ms or 500) + 1500
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(10) end
end

function FadeIn(ms)
    DoScreenFadeIn(ms or 500)
end

-- network an entity and return its id (0 when it could not be networked)
function NetOf(ent, timeoutMs)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return 0 end
    if not NetworkGetEntityIsNetworked(ent) then NetworkRegisterEntityAsNetworked(ent) end
    local t = GetGameTimer() + (timeoutMs or 2000)
    while not NetworkGetEntityIsNetworked(ent) and GetGameTimer() < t do Wait(25) end
    if not NetworkGetEntityIsNetworked(ent) then return 0 end
    local net = NetworkGetNetworkIdFromEntity(ent)
    if net and net ~= 0 then SetNetworkIdExistsOnAllMachines(net, true) end
    return net or 0
end

function TakeControl(ent, ms)
    if not ent or not DoesEntityExist(ent) then return false end
    if NetworkHasControlOfEntity(ent) then return true end
    NetworkRequestControlOfEntity(ent)
    local t = GetGameTimer() + (ms or 1500)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < t do
        Wait(25)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

function DeleteEnt(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    TakeControl(ent, 800)
    SetEntityAsMissionEntity(ent, true, true)
    if IsEntityAVehicle(ent) then DeleteVehicle(ent) elseif IsEntityAPed(ent) then DeletePed(ent) else DeleteObject(ent) end
    if DoesEntityExist(ent) then DeleteEntity(ent) end
end

function IsDeadOrDying()
    local ped = PlayerPedId()
    return IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
end

------------------------------------------------------------------------------ blips

function BlipCoords(sprite, pos, name)
    local blip = N(0x554D9D53F696D002, U.signed(sprite), pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    if blip and name then N(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', name)) end
    return blip
end

function BlipEntity(ent, name)
    local blip = N(0x23F74C2FDA6E7C61, -1230993421, ent)
    if blip and name then N(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', name)) end
    return blip
end

function BlipRadius(pos, radius)
    return N(0x45F13B7E0A15C880, -1282792512, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, radius + 0.0)
end

function BlipModifier(blip, name)
    if blip then N(0x662D364ABF16DE2F, blip, GetHashKey(name)) end
end

function DropBlip(blip)
    if blip and blip ~= 0 and DoesBlipExist(blip) then RemoveBlip(blip) end
end

function Route(pos)
    ClearGpsMultiRoute()
    StartGpsMultiRoute(GetHashKey('COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    SetGpsMultiRouteRender(true)
end

function ClearRoute()
    ClearGpsMultiRoute()
end

------------------------------------------------------------------------------ server pushes

local listeners = { start = {}, camp = {}, gone = {}, mycamp = {}, stop = {} }

function OnState(kind, fn)
    listeners[kind][#listeners[kind] + 1] = fn
end

local function fire(kind, ...)
    for _, fn in ipairs(listeners[kind]) do
        local ok, err = pcall(fn, ...)
        if not ok then print(('^1[pup_camps]^7 %s listener failed: %s'):format(kind, tostring(err))) end
    end
end

RegisterNetEvent('pup_camps:cl:start', function(data)
    if type(data) ~= 'table' then return end
    -- another character on this client: invites were for the old one
    if State.charid ~= nil and State.charid ~= data.charid then State.invites = {} end
    State.charid = data.charid
    State.myCamp = tonumber(data.camp) or 0
    State.camps = {}
    for _, v in ipairs(data.camps or {}) do State.camps[v.id] = v end
    local first = not State.started
    State.started = true
    fire('start', first, tonumber(data.poisonDelay) or 10)
end)

RegisterNetEvent('pup_camps:cl:camp', function(view, rebuild)
    if type(view) ~= 'table' or not view.id then return end
    State.camps[view.id] = view
    fire('camp', view, rebuild == true)
end)

RegisterNetEvent('pup_camps:cl:campGone', function(id)
    State.camps[id] = nil
    fire('gone', id)
end)

RegisterNetEvent('pup_camps:cl:myCamp', function(id)
    local old = State.myCamp
    State.myCamp = tonumber(id) or 0
    fire('mycamp', State.myCamp, old)
end)

------------------------------------------------------------------------------ start-up

-- after the character is chosen (the server also starts us on its own)
RegisterNetEvent('vorp:SelectedCharacter', function()
    SetTimeout(7000, function()
        if not State.started then Request('hello', false) end
    end)
end)

-- after a resource restart while already playing
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(4000)
        local ch = LocalPlayer.state.Character
        if type(ch) == 'table' and ch.CharId then Request('hello', true) end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    fire('stop')
end)
