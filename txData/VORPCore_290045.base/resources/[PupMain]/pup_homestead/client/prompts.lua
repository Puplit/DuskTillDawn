-- pup_homestead | client: the prompts at a plant, a water pump and a water wagon
local H = Homestead

local function register(group, key, label, hold)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', label))
    PromptSetEnabled(p, false)
    PromptSetVisible(p, false)
    if hold then PromptSetHoldMode(p, 1000) else PromptSetStandardMode(p, true) end
    PromptSetGroup(p, group)
    PromptRegisterEnd(p)
    return p
end

local plantGroup, pumpGroup, wagonGroup = GetRandomIntInRange(0, 0xffffff), GetRandomIntInRange(0, 0xffffff), GetRandomIntInRange(0, 0xffffff)
local P = nil

-- each plant prompt, the action it runs, and when it shows
local DEFS = {
    { action = 'harvest',   key = 'harvest',   when = function(p) return p.left <= 0 end },
    { action = 'water',     key = 'water',     when = function(p) return H.holding and not p.watered and p.left > 0 end },
    { action = 'fertilise', key = 'fertilise', when = function(p) return not H.holding and not p.fert and p.left > 0 end },
    { action = 'trim',      key = 'trim',      when = function(p) return not H.holding and not p.trim and p.left > 0 end },
    { action = 'remove',    key = 'remove',    when = function() return true end, hold = true },
}

local function setup()
    if P then return end
    P = { plant = {} }
    for i, d in ipairs(DEFS) do P.plant[i] = register(plantGroup, Config.Keys[d.key], Locale[d.action], d.hold) end
    P.pump = register(pumpGroup, Config.Keys.pump, Locale.pump)
    P.pour = register(wagonGroup, Config.Keys.wagonFill, Locale.wagonFill)
    P.draw = register(wagonGroup, Config.Keys.wagonDraw, Locale.wagonDraw)
end

local function show(p, on)
    PromptSetEnabled(p, on)
    PromptSetVisible(p, on)
end

local function nearestPlant(me)
    local best, bestD
    for _, p in pairs(H.plants) do
        local d = #(me - vector3(p.x, p.y, p.z))
        if d <= Config.Plants.reach and (not bestD or d < bestD) then best, bestD = p, d end
    end
    return best
end

local wagonHash = {}
for model, cap in pairs(Config.Watering.wagons) do wagonHash[GetHashKey(model)] = { name = model, cap = cap } end

local function nearestWagon(me)
    local best, bestD, info
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local w = wagonHash[GetEntityModel(v)]
        if w then
            local d = #(me - GetEntityCoords(v))
            if d <= 4.0 and (not bestD or d < bestD) then best, bestD, info = v, d, w end
        end
    end
    return best, info
end

-- a short chore at a pump or wagon, then the server answers
local function chore(req, after)
    if H.busy then return end
    H.busy = true
    CreateThread(function()
        -- ask first: no animation or progress bar for a fill that cannot happen
        local pre = H.ask({ op = 'check', what = req.op, net = req.net, river = req.river })
        if not pre or not pre.ok then
            H.tip(pre and pre.msg)
            H.busy = false
            return
        end
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        RequestAnimDict('amb_work@prop_human_pump_water@female_b@idle_a')
        local t = GetGameTimer()
        while not HasAnimDictLoaded('amb_work@prop_human_pump_water@female_b@idle_a') and GetGameTimer() - t < 3000 do Wait(50) end
        TaskPlayAnim(ped, 'amb_work@prop_human_pump_water@female_b@idle_a', 'idle_a', 1.0, 1.0, -1, 1, 0, false, false, false)
        exports['pup-ui']:Progress({ label = Locale.progWater, duration = 4000 })
        Wait(4000)
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        local res = H.ask(req)
        H.tip(res and res.msg)
        if after and res and res.ok then after() end
        H.busy = false
    end)
end

CreateThread(function()
    while true do
        local wait = 600
        local ped = PlayerPedId()
        if not H.busy and not IsEntityDead(ped) and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) then
            local me = GetEntityCoords(ped)
            local p = nearestPlant(me)
            if p then
                wait = 0
                setup()
                local pressed
                for i, d in ipairs(DEFS) do
                    local on = d.when(p) and H.may(p, d.action)
                    show(P.plant[i], on)
                    if on and not pressed then
                        local done = d.hold and PromptHasHoldModeCompleted(P.plant[i]) or (not d.hold and PromptHasStandardModeCompleted(P.plant[i]))
                        if done then pressed = d.action end
                    end
                end
                -- the prompt title carries the state unless the coloured text alone shows it
                local st = Config.Plants.status
                local title = (st and st.show == 'drawtext') and p.crop or H.status(p)
                PromptSetActiveGroupThisFrame(plantGroup, CreateVarString(10, 'LITERAL_STRING', title))
                if pressed then H.work(pressed, p) end
            else
                local pump = GetClosestObjectOfType(me.x, me.y, me.z, 2.0, Config.Watering.pumpModel, false, false, false)
                local wagon, info = nearestWagon(me)
                if pump and pump ~= 0 then
                    wait = 0
                    setup()
                    show(P.pump, true)
                    PromptSetActiveGroupThisFrame(pumpGroup, CreateVarString(10, 'LITERAL_STRING', Locale.pump))
                    if PromptHasStandardModeCompleted(P.pump) then chore({ op = 'pump' }) end
                elseif wagon then
                    wait = 0
                    setup()
                    local net = NetworkGetNetworkIdFromEntity(wagon)
                    local inWater = IsEntityInWater(wagon)
                    show(P.pour, H.holding or inWater)
                    show(P.draw, not H.holding)
                    H.wagonLevel = H.wagonLevel or {}
                    local level = H.wagonLevel[net] or 0
                    PromptSetActiveGroupThisFrame(wagonGroup, CreateVarString(10, 'LITERAL_STRING', Locale.wagonHolds:format(info.name, level, info.cap)))
                    if (H.holding or inWater) and PromptHasStandardModeCompleted(P.pour) then
                        chore({ op = 'pour', net = net, river = inWater and not H.holding }, function() H.holdCan(false) end)
                    elseif not H.holding and PromptHasStandardModeCompleted(P.draw) then
                        chore({ op = 'draw', net = net })
                    end
                end
            end
        end
        Wait(wait)
    end
end)

-- the coloured state over every plant near you (Config.Plants.status):
-- white growing, red needs water, blue watered, gold ready
local function stateColour(p, colours)
    local stage = Farm.stage(p)
    if stage == 'ready' then return colours.ready end
    if stage == 'thirsty' then return colours.thirsty end
    if p.watered then return colours.watered end
    return colours.growing
end

CreateThread(function()
    local st = Config.Plants.status
    if not st or (st.show ~= 'drawtext' and st.show ~= 'both') then return end
    local reach = tonumber(st.distance) or 6.0
    local height = tonumber(st.height) or 0.4
    local scale = tonumber(st.scale) or 0.35
    local colours = st.colours or {}
    while true do
        local wait = 500
        local ped = PlayerPedId()
        if not IsEntityDead(ped) then
            local me = GetEntityCoords(ped)
            for _, p in pairs(H.plants) do
                if #(me - vector3(p.x, p.y, p.z)) <= reach then
                    wait = 0
                    local c = stateColour(p, colours) or { 255, 255, 255 }
                    exports['pup-ui']:Draw3DText(vector3(p.x, p.y, p.z + height), H.status(p),
                        { r = c[1] or 255, g = c[2] or 255, b = c[3] or 255, a = 255, scale = scale })
                end
            end
        end
        Wait(wait)
    end
end)

-- the wagon's level, asked once a second while you stand by one
CreateThread(function()
    while true do
        Wait(1000)
        local wagon = nearestWagon(GetEntityCoords(PlayerPedId()))
        if wagon then
            local net = NetworkGetNetworkIdFromEntity(wagon)
            local res = H.ask({ op = 'wagon', net = net })
            H.wagonLevel = H.wagonLevel or {}
            if res then H.wagonLevel[net] = res.level end
        end
    end
end)
