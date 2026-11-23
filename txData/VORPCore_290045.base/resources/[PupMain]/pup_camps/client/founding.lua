-- pup_camps | founding a camp with the flag item, and moving a camp

Founding = {}

local inScene = false   -- pup-scene says the player is inside an interior scene

-- pup-scene only tells us when a scene ends; the interior native covers the start
AddEventHandler('pup-scene:stopscene', function()
    inScene = false
end)

local function nearRoad(pos)
    local ok, node = GetClosestVehicleNode(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, 1, 3.0, 0)
    if not ok or ok == 0 or not node then return false end
    return U.dist2(pos, { x = node.x, y = node.y }) < Config.Camp.roadDistance
end

local function inRegion(pos)
    local lock = Config.Camp.regionLock
    if not lock or #lock == 0 then return true end
    for _, r in ipairs(lock) do
        if U.dist3(pos, r) <= (tonumber(r.radius) or Config.Camp.regionDefaultRadius) then return true end
    end
    return false
end

local function nearMission(pos)
    for _, anchor in pairs(CampMissionRegions or {}) do
        if U.dist3(pos, anchor) <= Config.Missions.arriveDistance then return true end
    end
    return false
end

local function inTown(pos)
    local zone = N(0x43AD8FC02B429D33, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, 1)
    if zone and zone ~= 0 then return true end
    if GetInteriorFromEntity(PlayerPedId()) ~= 0 then return true end
    return inScene
end

-- the site checks shared by founding and moving; others = list of { id, coords }
local function siteProblem(pos, others, ignoreId, checkMembership)
    if checkMembership and (State.myCamp or 0) ~= 0 then return L('found_in_camp') end
    if nearRoad(pos) then return L('found_road') end
    if not inRegion(pos) then return L('found_region') end
    if nearMission(pos) then return L('found_mission') end
    if inTown(pos) then return L('found_town') end
    for _, c in ipairs(others) do
        if c.id ~= ignoreId and U.dist3(pos, c.coords) < Config.Camp.spacing then return L('found_other_camp') end
    end
    if IsEntityInWater(PlayerPedId()) then return L('found_water') end
    return nil
end

local function progress(label, ms)
    local done = false
    local shown = false
    if UiRunning() then
        shown = exports['pup-ui']:Progress({ label = label, duration = ms }, function() done = true end) == true
    end
    if not shown then
        Wait(ms)
        return
    end
    local t = GetGameTimer() + ms + 2000
    while not done and GetGameTimer() < t do Wait(100) end
end

------------------------------------------------------------------------------ founding

RegisterNetEvent('pup_camps:cl:found', function(list)
    if State.busy or type(list) ~= 'table' then return end
    local pos = PedPos()
    local why = siteProblem(pos, list, nil, true)
    if why then return Notify(why) end
    State.busy = true
    local ok, err = pcall(function()
        local vals = Menu.input(L('found_name_title'), { { label = L('found_name_field'), type = 'text', maxlength = Config.Camp.nameMax, required = true } })
        local name = vals and U.trim(tostring(vals[1] or '')) or ''
        if name == '' then return end
        Scenario(Config.Anim.hammer, Config.Camp.setupSeconds * 1000)
        progress(L('found_progress'), Config.Camp.setupSeconds * 1000)
        StopScenario()
        Ask('found', pos, name)
    end)
    State.busy = false
    if not ok then print('^1[pup_camps]^7 founding failed: ' .. tostring(err)) end
end)

------------------------------------------------------------------------------ moving

local moving = nil  -- campId while in moving mode

function Founding.startMoving(id)
    if moving then return end
    moving = id
    Notify(L('move_hint', Config.Commands.moveCamp), 8000)
    CreateThread(function()
        while moving == id do
            DrawHint(L('move_hint', Config.Commands.moveCamp), 0.86)
            DrawHint(L('move_cancel_hint'), 0.90)
            if IsControlJustPressed(0, Config.Keys.cancel) or IsDisabledControlJustPressed(0, Config.Keys.cancel) then
                moving = nil
                Notify(L('move_stopped'))
                break
            end
            if IsDeadOrDying() then moving = nil break end
            Wait(0)
        end
    end)
end

RegisterCommand(Config.Commands.moveCamp, function()
    local id = moving
    if not id or State.busy then return end
    local pos = PedPos()
    local others = {}
    for cid, c in pairs(State.camps) do others[#others + 1] = { id = cid, coords = c.coords } end
    local why = siteProblem(pos, others, id, false)
    if why then return Notify(why) end
    CreateThread(function()
        State.busy = true
        local ok = Ask('relocate', id, pos)
        if ok then
            moving = nil
            Scenario(Config.Anim.hammer, 4000)
            Wait(4000)
            StopScenario()
        end
        State.busy = false
    end)
end, false)

OnState('mycamp', function() moving = nil end)
OnState('stop', function() moving = nil end)
