-- pup_id | client
-- Commands, the nearest-person search, the restraint test and the paper overlay.

local HOGTIED <const> = 0x3AA24CCC0D451379 -- IS_PED_HOGTIED
local CUFFED  <const> = 0x74E559B3BC910685 -- IS_PED_CUFFED

local onScreen = false   -- a paper is displayed
local seq = 0            -- number of the paper on screen; the page echoes it when it closes
local polling = false    -- the close-control loop is running
local warned = {}

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[pup_id]^7 %s'):format(msg))
end

local function truthy(v)
    return v == true or v == 1
end

local function restrained(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsEntityDead(ped) then return true end
    -- named natives first where this build has them, the raw hashes otherwise
    if IsPedHogtied and truthy(IsPedHogtied(ped)) then return true end
    if truthy(Citizen.InvokeNative(HOGTIED, ped)) then return true end
    if IsPedCuffed and truthy(IsPedCuffed(ped)) then return true end
    if truthy(Citizen.InvokeNative(CUFFED, ped)) then return true end
    return false
end

-- The closest other active player and the distance to them, or nil.
local function nearestPlayer()
    local me = PlayerId()
    local myPos = GetEntityCoords(PlayerPedId())
    local bestId, bestPed, bestDist
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= me then
            local ped = GetPlayerPed(pl)
            if ped ~= 0 and DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - myPos)
                if not bestDist or d < bestDist then
                    bestId, bestPed, bestDist = pl, ped, d
                end
            end
        end
    end
    if not bestId then return nil end
    return GetPlayerServerId(bestId), bestPed, bestDist
end

local function hidePaper()
    -- clear the flag here as well, so it can never stay set
    onScreen = false
    SendNUIMessage({ action = 'hide' })
end

local function startPolling()
    if polling then return end
    polling = true
    CreateThread(function()
        while onScreen do
            if IsControlJustReleased(0, Config.CloseControl) then
                hidePaper()
                break
            end
            Wait(0)
        end
        polling = false
    end)
end

local pageReady = false -- the page has received its words

-- the paper bundles its own fonts (html/fonts), so only the words are sent
local function pageSetup()
    return { words = Locale.paper }
end

-- The page asks for its words and fonts once it has loaded (and retries if that call fails).
RegisterNUICallback('ready', function(_, cb)
    pageReady = true
    cb(pageSetup())
end)

-- The page finished closing a paper. Ignore it if a newer paper has arrived since.
RegisterNUICallback('closed', function(data, cb)
    if type(data) == 'table' and tonumber(data.seq) == seq then
        onScreen = false
    end
    cb('ok')
end)

RegisterNetEvent('pup_id:show', function(paper)
    if type(paper) ~= 'table' then return end
    seq = seq + 1
    onScreen = true
    SendNUIMessage({
        action = 'show',
        seq = seq,
        paper = {
            name = tostring(paper.name or ''),
            occupation = tostring(paper.occupation or ''),
            age = tonumber(paper.age),
            number = tostring(paper.number or ''),
            issued = tostring(paper.issued or ''),
        },
        -- the page never got its setup (its 'ready' call failed): send it with the paper
        setup = (not pageReady) and pageSetup() or nil,
    })
    startPolling()
end)

-- The server asks whether this player's own ped is restrained (someone wants to read the paper).
RegisterNetEvent('pup_id:restraintQuery', function(token)
    if type(token) ~= 'string' then return end
    TriggerServerEvent('pup_id:restraintReply', token, restrained(PlayerPedId()))
end)

RegisterCommand(Config.Commands.own, function()
    if onScreen then return end
    TriggerServerEvent('pup_id:requestOwn')
end, false)

RegisterCommand(Config.Commands.handOver, function()
    if onScreen then return end
    local serverId, _, dist = nearestPlayer()
    if not serverId or dist > Config.HandOverRange then return end
    TriggerServerEvent('pup_id:handOver', serverId)
end, false)

RegisterCommand(Config.Commands.inspect, function()
    if onScreen then
        hidePaper()
        return
    end
    local serverId, ped, dist = nearestPlayer()
    if not serverId or dist > Config.InspectRange then return end
    if not restrained(ped) then
        TriggerEvent('vorp:TipBottom', Locale.notRestrained, Config.TipMs)
        return
    end
    TriggerServerEvent('pup_id:inspect', serverId)
end, false)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    onScreen = false
end)
