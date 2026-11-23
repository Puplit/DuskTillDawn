-- pup_homestead | client: plants near you, their props and prompts, planting, and working a plant
Homestead = { plants = {}, mine = {}, me = nil, holding = false, busy = false }

local Core = exports.vorp_core:GetCore()
local H = Homestead
local props = {}   -- [id] = object handle
local blips = {}   -- [id] = blip handle

function H.ask(req) return Core.Callback.TriggerAwait('pup_homestead:ask', req) end
function H.tip(msg) if msg then TriggerEvent('vorp:TipRight', msg, 4500) end end

-------------------------------------------------------------------------------
-- PERK / JOB TIMING  (pup-perks, optional)
-------------------------------------------------------------------------------
function H.timed(ms)
    local out = ms
    if GetResourceState('pup-perks') == 'started' then
        local ok, res = pcall(function() return exports['pup-perks']:Timed(ms, 'farm_speed') end)
        if ok and tonumber(res) then out = tonumber(res) end
    end
    local mult = Farm.jobBonus(H.job, 'speed') -- the server sends the job with every nearby sync
    if mult and mult > 0 and mult < 1 then out = out * mult end
    return math.floor(math.max(out, ms * Config.JobBonus.speedFloor))
end

-------------------------------------------------------------------------------
-- SKILL BAR AND ANIMATIONS
-------------------------------------------------------------------------------
function H.skill(difficulty)
    if not Config.Minigame.enabled then return true end
    local t = Config.MinigameTuning
    local d = tonumber(difficulty) or 1
    local p = promise.new()
    exports['pup-minigames']:skill_bar({
        style = 'default', icon = 'fa-solid fa-seedling', orientation = 1, moving_icon = false,
        area_size = math.max(t.minArea, math.min(t.baseArea, t.baseArea - d * t.areaLoss)),
        perfect_area_size = t.perfectArea,
        speed = math.max(t.baseSpeed, math.min(t.maxSpeed, t.baseSpeed + d * t.speedGain)),
    }, function(result) p:resolve(result == 'success' or result == 'perfect') end)
    local ok = Citizen.Await(p)
    if not ok and Config.Minigame.ragdollOnFail then SetPedToRagdoll(PlayerPedId(), 1000, 1000, 0, false, false, false) end
    return ok
end

local function play(dict, name, ms, flag)
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - t < 3000 do Wait(50) end
    TaskPlayAnim(PlayerPedId(), dict, name, 1.0, 1.0, ms, flag or 1, 0, false, false, false)
end

local function holdProp(model, bone, off, rot)
    local ped = PlayerPedId()
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 3000 do Wait(50) end
    local c = GetEntityCoords(ped)
    local o = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    AttachEntityToEntity(o, ped, GetEntityBoneIndexByName(ped, bone), off[1], off[2], off[3], rot[1], rot[2], rot[3], false, false, true, false, 0, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    return o
end

-- the animations each action plays (ms scaled by perks / job)
local ANIMS = {
    water   = function(ms) TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_PLAYER_CHORES_BUCKET_POUR_HIGH'), math.floor(ms * 1.16), true, false, false, false) end,
    trim    = function(ms) play('mech_pickup@plant@gold_currant', 'exit', ms) end,
    feed    = function(ms) play('mech_pickup@plant@orchid_plant', 'base', ms) end,
    harvest = function(ms) play('mech_pickup@plant@berries', 'base', ms) end,
    clear   = function(ms) play('amb_camp@world_camp_fire@stomp@male_a@wip_base', 'wip_base', -1) end,
}
local BASE_MS = { water = 6000, trim = 2500, feed = 2500, harvest = 2500, clear = 10000 }
local LABEL = { water = 'progWater', trim = 'progTrim', feed = 'progFeed', harvest = 'progHarvest', clear = 'progClear' }

function H.animate(kind)
    local ms = H.timed(BASE_MS[kind])
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    exports['pup-ui']:Progress({ label = Locale[LABEL[kind]], duration = ms })
    ANIMS[kind](ms)
    Wait(ms)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

-------------------------------------------------------------------------------
-- PLANT CACHE  (only plants near you; the server pushes changes)
-------------------------------------------------------------------------------
local function despawn(id)
    if props[id] then
        if DoesEntityExist(props[id]) then DeleteObject(props[id]) end
        props[id] = nil
    end
end

local function setBlip(id, p)
    if blips[id] then RemoveBlip(blips[id]) blips[id] = nil end
    if p and Config.Plants.blips then
        local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, p.x, p.y, p.z) -- BLIP_ADD_FOR_COORDS
        SetBlipSprite(b, Config.Plants.blipSprite, true)
        SetBlipScale(b, 0.1)
        Citizen.InvokeNative(0x9CB1A1623062F402, b, p.crop) -- SET_BLIP_NAME
        blips[id] = b
    end
end

RegisterNetEvent('pup_homestead:plant', function(id, data)
    H.plants[id] = data
    if not data then despawn(id) end
end)

RegisterNetEvent('pup_homestead:mine', function(id, data)
    H.mine[id] = data
    setBlip(id, data)
end)

local function sync()
    local res = H.ask({ op = 'nearby' })
    if not res then return end
    H.me, H.job = res.me, res.job
    local fresh = {}
    for _, p in ipairs(res.plants) do fresh[p.id] = p end
    for id in pairs(H.plants) do if not fresh[id] then despawn(id) end end
    H.plants = fresh
end

local function syncMine()
    local res = H.ask({ op = 'mine' })
    if not res then return end
    for id in pairs(H.mine) do setBlip(id, nil) end
    H.mine = {}
    for _, p in ipairs(res.plants) do H.mine[p.id] = p setBlip(p.id, p) end
end

RegisterNetEvent('vorp:SelectedCharacter', function()
    Wait(3000)
    sync()
    syncMine()
end)

CreateThread(function()
    Wait(2000)
    syncMine() -- after a resource restart; on login vorp:SelectedCharacter does it
    while true do
        sync()
        Wait(Config.Plants.syncSeconds * 1000)
    end
end)

-------------------------------------------------------------------------------
-- PROPS
-------------------------------------------------------------------------------
local badModel = {}

local function spawn(p)
    local c = Config.Crops[p.crop]
    if not c or badModel[c.prop] then return end
    local hash = GetHashKey(c.prop)
    if not IsModelValid(hash) and not IsModelInCdimage(hash) then
        badModel[c.prop] = true
        print(('^1[pup_homestead]^7 %s uses prop %s, which this game does not have'):format(p.crop, c.prop))
        return
    end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 3000 do Wait(50) end
    if not HasModelLoaded(hash) or not H.plants[p.id] then return end
    local o = CreateObject(hash, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not o or o == 0 then return end
    PlaceObjectOnGroundProperly(o)
    if c.sink ~= 0 then
        local at = GetEntityCoords(o)
        SetEntityCoords(o, at.x, at.y, at.z - c.sink, false, false, false, false)
    end
    FreezeEntityPosition(o, true)
    SetEntityAsMissionEntity(o, true, true)
    props[p.id] = o
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for id, p in pairs(H.plants) do
            local near = #(me - vector3(p.x, p.y, p.z)) <= Config.Plants.renderDistance
            if near and not props[id] then spawn(p)
            elseif not near and props[id] then despawn(id) end
        end
        Wait(500)
    end
end)

-------------------------------------------------------------------------------
-- WORKING A PLANT
-------------------------------------------------------------------------------
function H.may(p, action) return p.owner == H.me or Config.Plants.others[action] == true end

function H.status(p)
    local c = Config.Crops[p.crop]
    local stage = Farm.stage(p)
    local t = p.left .. ' min'
    if stage == 'ready' then return Locale.stReady:format(p.crop) end
    if stage == 'thirsty' then return Locale.stThirsty:format(p.crop) end
    if p.watered and p.fert and p.trim then return Locale.stThriving:format(p.crop, t) end
    if p.watered then return Locale.stWatered:format(p.crop, t) end
    return Locale.stGrowing:format(p.crop, t)
end

-- skill bar, animation, then the server decides
function H.work(action, p)
    if H.busy then return end
    -- restart lock (server/restart.lua): say so before the skill bar; the server refuses it anyway
    if action == 'harvest' and GlobalState.homesteadRestartLock then return H.tip(Locale.restartHarvest) end
    H.busy = true
    CreateThread(function()
        local ok, err = pcall(function()
            if action ~= 'remove' and not H.skill(p.difficulty) then
                local res = H.ask({ op = 'act', action = 'fail', id = p.id })
                if action == 'water' then H.holdCan(false) end
                H.tip(res and res.msg)
                return
            end
            local kind = ({ water = 'water', trim = 'trim', fertilise = 'feed', harvest = 'harvest', remove = 'clear' })[action]
            H.animate(kind)
            local res = H.ask({ op = 'act', action = action, id = p.id })
            H.tip(res and res.msg)
        end)
        if not ok then print('^1[pup_homestead]^7 ' .. tostring(err)) end
        H.busy = false
    end)
end

-------------------------------------------------------------------------------
-- PLANTING
-------------------------------------------------------------------------------
local function townBlocked(at)
    local town = Citizen.InvokeNative(0x43AD8FC02B429D33, at.x, at.y, at.z, 1) -- GET_MAP_ZONE_AT_COORDS (town)
    for _, name in ipairs(Config.Planting.blockedTowns) do
        if town == GetHashKey(name) then return true end
    end
    return false
end

local function tooClose(at)
    for _, p in pairs(H.plants) do
        if #(at - vector3(p.x, p.y, p.z)) < Config.Planting.minSpacing then return true end
    end
    return false
end

RegisterNetEvent('pup_homestead:startPlanting', function(cropName)
    local c = Config.Crops[cropName]
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    local why
    if H.busy then why = Locale.busy
    elseif townBlocked(at) then why = Locale.inTown
    elseif IsEntityInWater(ped) then why = Locale.inWater
    elseif tooClose(at) then why = Locale.tooClose end
    if why then
        TriggerServerEvent('pup_homestead:cancelSeed')
        return H.tip(why)
    end

    H.busy = true
    if not H.skill(c.difficulty) then
        TriggerServerEvent('pup_homestead:cancelSeed')
        H.busy = false
        return H.tip(Locale.plantFailed)
    end

    -- rake, then sow
    local ms = H.timed(15000)
    FreezeEntityPosition(ped, true)
    exports['pup-ui']:Progress({ label = Locale.progPlant, duration = ms * 2 + 1400 })
    play('amb_work@world_human_farmer_rake@male_a@idle_a', 'idle_a', -1)
    Wait(700)
    local rake = holdProp('p_rake02x', 'PH_R_Hand', { 0.0, 0.0, 0.19 }, { 0.0, 0.0, 0.0 })
    Wait(ms)
    DeleteEntity(rake)
    play('amb_work@world_human_feed_chickens@female_a@base', 'base', -1)
    Wait(700)
    local bag = holdProp('p_feedbag01bx', 'PH_L_Hand', { 0.0, 0.0, 0.0 }, { 0.0, 0.0, 0.0 })
    Wait(ms)
    DeleteEntity(bag)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    local res = H.ask({ op = 'plant', spot = { x = at.x, y = at.y, z = at.z } })
    H.tip(res and res.msg)
    H.busy = false
    sync()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(props) do despawn(id) end
    for id in pairs(blips) do RemoveBlip(blips[id]) end
end)
