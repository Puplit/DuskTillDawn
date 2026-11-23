-- pup_homestead | watering cans: filling at pumps, rivers and water wagons
Water = {}

local Inv = exports.vorp_inventory
local I = Config.Items
local wagons = {}  -- [netId] = cans of water stored (kept while the wagon exists)
local last = {}    -- [src] = GetGameTimer() of the last fill, so a held key cannot farm cans

local function slow(src)
    local now = GetGameTimer()
    if last[src] and now - last[src] < 2500 then return true end
    last[src] = now
    return false
end

-- empty can -> full can of `kind`
local function fill(src, full)
    if Field.count(src, I.emptyCan) < 1 then return false, Locale.needEmpty end
    if not Inv:subItem(src, I.emptyCan, 1) then return false, Locale.needEmpty end
    Inv:addItem(src, full, 1)
    return true, Locale.canFilled
end

function Water.pump(src)
    if slow(src) then return false end
    return fill(src, I.cleanWaterCan)
end

function Water.river(src)
    if slow(src) then return false end
    return fill(src, I.dirtyWaterCan)
end

-- the wagon behind a network id, if it is a water wagon close to this player
local function wagonOf(src, netId)
    netId = tonumber(netId)
    if not netId then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    local model = GetEntityModel(ent)
    local cap
    for name, holds in pairs(Config.Watering.wagons) do
        if GetHashKey(name) == model then cap = holds break end
    end
    if not cap then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(ent)) > 8.0 then return nil end
    return netId, cap
end

function Water.wagonLevel(netId) return wagons[tonumber(netId)] or 0 end

-- pour the can in hand into the wagon, or (river = true) let a wagon standing in water take some in
function Water.pour(src, netId, river)
    local id, cap = wagonOf(src, netId)
    if not id then return false end
    local have = wagons[id] or 0
    if have >= cap then return false, Locale.wagonFull end
    if river and not Field.holding(src) then
        if slow(src) then return false end
        wagons[id] = have + 1
        return true, Locale.wagonPoured:format(wagons[id], cap)
    end
    local can = Field.holding(src)
    if not can or Field.count(src, can) < 1 then return false, Locale.noCan end
    Field.drop(src)
    if not Inv:subItem(src, can, 1) then return false, Locale.noCan end
    Inv:addItem(src, I.emptyCan, 1)
    wagons[id] = have + 1
    return true, Locale.wagonPoured:format(wagons[id], cap)
end

-- fill an empty can from the wagon (clean water)
function Water.draw(src, netId)
    local id = wagonOf(src, netId)
    if not id then return false end
    if (wagons[id] or 0) <= 0 then return false, Locale.wagonEmpty end
    local ok, msg = fill(src, I.cleanWaterCan)
    if not ok then return false, msg end
    wagons[id] = wagons[id] - 1
    return true, Locale.wagonDrawn:format(wagons[id])
end

-- before the chore starts: would this pump / wagon action work? Takes and gives nothing,
-- so the player hears "no empty can" at once instead of after the animation.
-- The real action checks everything again.
function Water.check(src, op, netId, river)
    if op == 'pump' then
        if Field.count(src, I.emptyCan) < 1 then return false, Locale.needEmpty end
        return true
    elseif op == 'draw' then
        local id = wagonOf(src, netId)
        if not id then return false end
        if (wagons[id] or 0) <= 0 then return false, Locale.wagonEmpty end
        if Field.count(src, I.emptyCan) < 1 then return false, Locale.needEmpty end
        return true
    elseif op == 'pour' then
        local id, cap = wagonOf(src, netId)
        if not id then return false end
        if (wagons[id] or 0) >= cap then return false, Locale.wagonFull end
        if river and not Field.holding(src) then return true end
        local can = Field.holding(src)
        if not can or Field.count(src, can) < 1 then return false, Locale.noCan end
        return true
    end
    return true
end

AddEventHandler('playerDropped', function() last[source] = nil end)

-- forget wagons that no longer exist
CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        for id in pairs(wagons) do
            local ent = NetworkGetEntityFromNetworkId(id)
            if not ent or ent == 0 or not DoesEntityExist(ent) then wagons[id] = nil end
        end
    end
end)
