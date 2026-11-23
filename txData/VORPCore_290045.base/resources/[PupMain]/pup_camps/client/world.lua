-- pup_camps | camps in the world: local props, prop sets, blips

World = {}

local rendered = {}     -- [campId] = { objects = { [pieceId] = handle }, sets = { [pieceId] = handle }, nameBlip, radiusBlip }
local ownBlip = nil     -- { id, blip }
local pokerSent = {}    -- [campId] = true once per session
local previewColour = nil

local POKER_SET <const> = GetHashKey('pg_mg_poker')

local function isFlag(p) return p.item == Config.Camp.flagItem end

------------------------------------------------------------------------------ props

local function spawnProp(p)
    local model = LoadModel(p.prop)
    if not model then return nil end
    local obj = CreateObject(model, p.coords.x + 0.0, p.coords.y + 0.0, p.coords.z + 0.0, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return nil end
    SetEntityHeading(obj, (p.heading or 0.0) + 0.0)
    if isFlag(p) then PlaceObjectOnGroundProperly(obj, true) end
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    return obj
end

local function spawnSet(p)
    local hash = U.signed(p.prop)
    if hash == 0 then return nil end
    N(0xF3DE57A46D5585E9, hash)                       -- request the prop set
    local t = GetGameTimer() + 5000
    while not N(0x48A88FC684C55FDC, hash) and GetGameTimer() < t do Wait(25) end
    local set = N(0x899C97A1CCE7D483, hash, p.coords.x + 0.0, p.coords.y + 0.0, p.coords.z + 0.0, 0, (p.heading or 0.0) + 0.0, 1200.0, false, true)
    if not set or set == 0 then return nil end
    return set
end

local function dropSet(set)
    if set and set ~= 0 and N(0x7DDDCF815E650FF5, set) then N(0x58AC173A55D9D7B4, set, false, false) end
end

local function campPieces(camp)
    local list = {}
    for _, p in ipairs(camp.furni or {}) do list[#list + 1] = p end
    table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return list
end

local function nameBlipFor(camp)
    local blip = BlipCoords(Config.Camp.blipSprite, camp.coords, camp.name)
    BlipModifier(blip, ('BLIP_MODIFIER_MP_COLOR_%d'):format(camp.bcolor or 1))
    return blip
end

local function build(camp)
    local r = { objects = {}, sets = {} }
    rendered[camp.id] = r
    for _, p in ipairs(campPieces(camp)) do
        if p.active and p.coords then
            if p.cata == 'set' then
                r.sets[p.id] = spawnSet(p)
                if U.h32(p.prop) == U.h32(POKER_SET) and not pokerSent[camp.id] then
                    pokerSent[camp.id] = true
                    pcall(Integrations.pokerTable, camp.id, p.coords, p.heading or 0.0)
                end
            else
                r.objects[p.id] = spawnProp(p)
            end
        end
        if rendered[camp.id] ~= r then
            -- dropped while spawning (camp left, removed or rebuilt): undo what was made
            for _, o in pairs(r.objects) do if o and DoesEntityExist(o) then DeleteObject(o) end end
            for _, s in pairs(r.sets) do dropSet(s) end
            return
        end
    end
    r.radiusBlip = BlipRadius(camp.coords, Config.Camp.furnitureRadius)
    if camp.id ~= State.myCamp then r.nameBlip = nameBlipFor(camp) end
end

local function drop(id)
    local r = rendered[id]
    if not r then return end
    rendered[id] = nil
    for _, o in pairs(r.objects) do if o and DoesEntityExist(o) then DeleteObject(o) end end
    for _, s in pairs(r.sets) do dropSet(s) end
    DropBlip(r.nameBlip)
    DropBlip(r.radiusBlip)
end

function World.object(campId, pieceId)
    local r = rendered[campId]
    return r and r.objects[pieceId] or nil
end

function World.isRendered(campId)
    return rendered[campId] ~= nil
end

-- the rendered camp whose flag is nearest, within dist
function World.renderedNear(pos, dist)
    local best, bestD
    for id in pairs(rendered) do
        local camp = State.camps[id]
        if camp then
            local d = U.dist3(pos, camp.coords)
            if d <= dist and (not bestD or d < bestD) then best, bestD = camp, d end
        end
    end
    return best, bestD
end

function World.rebuild(id)
    drop(id)
end

------------------------------------------------------------------------------ own camp blip

local function refreshOwnBlip()
    local camp = MyCamp()
    if ownBlip then
        DropBlip(ownBlip.blip)
        ownBlip = nil
    end
    if not camp or camp.repo then return end
    local view = { name = camp.name, coords = camp.coords, bcolor = previewColour or camp.bcolor }
    ownBlip = { id = camp.id, blip = nameBlipFor(view) }
end
World.refreshOwnBlip = refreshOwnBlip

-- the blip colour slider previews on the player's own blip only
function World.previewColour(n)
    previewColour = n
    refreshOwnBlip()
end

------------------------------------------------------------------------------ loop

CreateThread(function()
    while true do
        Wait(1000)
        if State.started then
            local pos = PedPos()
            for id, camp in pairs(State.camps) do
                local near = not camp.repo and U.dist3(pos, camp.coords) <= Config.Camp.renderDistance
                if near and not rendered[id] then
                    build(camp)
                elseif not near and rendered[id] then
                    drop(id)
                end
            end
            for id in pairs(rendered) do
                if not State.camps[id] then drop(id) end
            end
        end
    end
end)

OnState('start', function()
    for id in pairs(rendered) do drop(id) end
    refreshOwnBlip()
end)

OnState('camp', function(view, rebuild)
    if rebuild or view.repo then drop(view.id) end
    local r = rendered[view.id]
    if r and r.nameBlip then
        DropBlip(r.nameBlip)
        r.nameBlip = view.id ~= State.myCamp and nameBlipFor(view) or nil
    end
    if view.id == State.myCamp then refreshOwnBlip() end
end)

OnState('gone', function(id)
    drop(id)
    if ownBlip and ownBlip.id == id then refreshOwnBlip() end
end)

OnState('mycamp', function()
    for id in pairs(rendered) do drop(id) end
    refreshOwnBlip()
end)

OnState('stop', function()
    for id in pairs(rendered) do drop(id) end
    if ownBlip then DropBlip(ownBlip.blip) end
    ownBlip = nil
end)
