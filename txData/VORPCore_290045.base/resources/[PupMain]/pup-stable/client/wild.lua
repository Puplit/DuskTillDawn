-- pup-stable | wild horse spots: spawning on request, behaviour, taming and the hand-in

Wild = {}
local W = Config.Wild
local spawned = {}   -- ent -> GetGameTimer() at creation (untagged ones are removed after 20 s)
local blips = {}

if W.blips then
    CreateThread(function()
        for i, s in ipairs(W.spots) do
            local b = N.blipCoords(1664425300, s.coords.x, s.coords.y, s.coords.z)
            if b and b ~= 0 then N.blipSprite(b, -1327110633) N.blipName(b, L('wh_blip')) blips[i] = b end
        end
    end)
end

RegisterNetEvent('pup-stable:wildSpawn', function(i, model, c)
    if not W.enabled or type(c) ~= 'table' and type(c) ~= 'vector4' then return end
    local hash = LoadModel(model)
    if not hash then return end
    local z = Look.ground(c.x, c.y, c.z)
    local ped = CreatePed(hash, c.x, c.y, z, c.w or 0.0, true, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    PlaceEntityOnGroundProperly(ped, true)
    spawned[ped] = GetGameTimer()
    local net = NetIdOf(ped)
    if net then
        SetNetworkIdExistsOnAllMachines(net, true)
        Call('wildSpawned', i, net)
    end
end)

-- behaviour, run by whichever client controls the horse
CreateThread(function()
    local lastWander = {}
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for ent, at in pairs(spawned) do
            if not DoesEntityExist(ent) then spawned[ent] = nil
            elseif not Entity(ent).state.wildhorse and now - at > 20000 then
                DeleteEntity(ent)
                spawned[ent] = nil
            end
        end
        local me = PlayerPedId()
        for _, ped in ipairs(GetGamePool('CPed')) do
            local tag = Entity(ped).state.wildhorse
            if type(tag) == 'table' and not tag.tamer and NetworkHasControlOfEntity(ped) and not IsEntityDead(ped) then
                local spot = W.spots[tag.spot]
                if spot and not IsPedAPlayer(GetPedInVehicleSeat(ped, -1)) and GetMount(me) ~= ped then
                    local close = nil
                    for _, pl in ipairs(GetActivePlayers()) do
                        local pp = GetPlayerPed(pl)
                        local d = #(GetEntityCoords(pp) - GetEntityCoords(ped))
                        local onFootSlow = not IsPedOnMount(pp) and GetEntitySpeed(pp) < W.spook.sneakSpeed
                        if d <= (onFootSlow and W.spook.sneak or W.spook.normal) then close = pp end
                    end
                    if close then
                        TaskSmartFleePed(ped, close, W.fleeDistance, 6000, 0, 0, 0)
                    elseif not lastWander[ped] or now - lastWander[ped] > 30000 then
                        lastWander[ped] = now
                        TaskWanderInArea(ped, spot.coords.x, spot.coords.y, spot.coords.z, W.wander, 1.0, 1.0, 0)
                    end
                end
            end
        end
    end
end)

------------------------------------------------------------------------------
-- taming
------------------------------------------------------------------------------
local taming = false

local function throw(horse, msg)
    local me = PlayerPedId()
    if msg then Tip(msg) end
    if DoesEntityExist(horse) then
        Citizen.InvokeNative(0x48E92D3DDE23C23A, me, 0, 0, 0, 0, 0) -- knock off the mount
        SetPedToRagdoll(me, 3000, 3000, 0, false, false, false)
        TaskSmartFleePed(horse, me, W.throwFlee, 10000, 0, 0, 0)
    end
end

local function tame(horse)
    taming = true
    local net = NetIdOf(horse)
    local ok, why = Call('tameStart', net)
    if not ok then
        throw(horse, why)
        taming = false
        return
    end
    if not Running('pup-minigames') then
        WarnOnce('minigames', 'pup-minigames is not running: wild horses cannot be tamed')
        throw(horse)
        taming = false
        return
    end
    for round = 1, W.rounds do
        Tip(L('wh_hold', round, W.rounds), 2500)
        local p = promise.new()
        local started = pcall(function()
            exports['pup-minigames']:skill_bar({ style = 'default', icon = 'fa-solid fa-horse', orientation = 2,
                area_size = W.skillBar.area_size, perfect_area_size = W.skillBar.perfect_area_size, speed = W.skillBar.speed,
                moving_icon = true, icon_speed = W.skillBar.icon_speed }, function(result) p:resolve(result) end)
        end)
        if not started then p:resolve('failed') end
        -- skill_bar silently ignores a call while another game runs; never wait forever
        SetTimeout(60000, function() p:resolve('failed') end)
        local result = Citizen.Await(p)
        if result ~= 'success' and result ~= 'perfect' or GetMount(PlayerPedId()) ~= horse then
            throw(horse, L('wh_thrown'))
            taming = false
            return
        end
    end
    CallTip('tameDone', net)
    taming = false
end

CreateThread(function()
    while true do
        Wait(500)
        local me = PlayerPedId()
        local mount = GetMount(me)
        if not taming and mount ~= 0 then
            local tag = Entity(mount).state.wildhorse
            if type(tag) == 'table' and not tag.tamer then tame(mount) end
        end
    end
end)

------------------------------------------------------------------------------
-- the hand-in at a stable
------------------------------------------------------------------------------
function Wild.handIn(stableId, horse)
    local net = NetIdOf(horse)
    if not net then return end
    local choice = Choose(L('wh_title'), nil, {
        { label = L('wh_keep'), desc = L('wh_keepDesc'), value = 'keep', disabled = not W.keep },
        { label = L('wh_sell'), desc = L('wh_sellDesc'), value = 'sell' },
    })
    if choice == 'sell' then
        CallTip('wildSell', net, stableId)
    elseif choice == 'keep' then
        local name = Ask(L('wh_name'), W.nameMax)
        if name == nil then return end
        if not CallTip('wildKeepGrant', net, stableId, name) then return end
        local stats = Look.readStats(horse)
        local ok, payload = CallTip('wildKeep', { speed = stats.speed, acceleration = stats.acceleration, handling = stats.handling, female = false })
        if ok then SetHorse(payload) end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for _, b in pairs(blips) do N.blipRemove(b) end
    for ent in pairs(spawned) do if DoesEntityExist(ent) then DeleteEntity(ent) end end
end)
