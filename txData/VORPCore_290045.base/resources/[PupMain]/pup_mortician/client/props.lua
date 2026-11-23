-- pup_mortician | local (not networked) prep-table props

Props = {}
local drawn = {} -- key -> { tbl, coffin, body }

local function clear(key)
    local d = drawn[key]
    if not d then return end
    drawn[key] = nil
    DeleteObj(d.body)
    DeleteObj(d.coffin)
    DeleteObj(d.tbl)
end

local function coffinModel(state)
    if not state or state.state == 'empty' then return Config.Models.coffinEmpty end
    if state.state == 'closed' then return Config.Models.coffinClosed end
    if state.laid and #state.laid > 0 then return Config.Models.coffinDecorated end
    return Config.Models.coffinEmpty
end

local function draw(key)
    local cfg = Config.Tables[key]
    local state = TableStates[key] or { state = 'empty' }
    local d = {}
    drawn[key] = d

    -- model loads wait; if the table was cleared or redrawn meanwhile, drop what we made
    local function spawn(model, z)
        local hash = LoadModel(model)
        if not hash or drawn[key] ~= d then return nil end
        local obj = CreateObject(hash, cfg.pos.x, cfg.pos.y, z, false, false, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if drawn[key] ~= d then
            DeleteObj(obj)
            return nil
        end
        return obj
    end

    d.tbl = spawn(Config.Models.table, cfg.pos.z)
    if not d.tbl then return end
    SetEntityHeading(d.tbl, cfg.heading or 0.0)
    PlaceObjectOnGroundProperly(d.tbl, false)
    FreezeEntityPosition(d.tbl, true)

    -- the one carrying this table's casket sees it in their arms, not here
    if Carry.key == key then return end

    d.coffin = spawn(coffinModel(state), cfg.pos.z - 0.2)
    if not d.coffin then return end
    SetEntityHeading(d.coffin, cfg.heading or 0.0)
    SetEntityCollision(d.coffin, false, false)
    FreezeEntityPosition(d.coffin, true)

    if state.state == 'open' then
        d.body = spawn(Config.Models.body, cfg.pos.z)
        if not d.body then return end
        SetEntityCollision(d.body, false, false)
        local o, r = cfg.bodyOffset, cfg.bodyRot
        AttachEntityToEntity(d.body, d.coffin, 0, o.x, o.y, o.z, r.x, r.y, r.z, false, false, false, false, 2, true, false, false)
    end
end

-- redraws one table if it is currently drawn
function Props.Refresh(key)
    if drawn[key] then
        clear(key)
        draw(key)
    end
end

function Props.RefreshAll()
    for key in pairs(Config.Tables) do Props.Refresh(key) end
end

function Props.ClearAll()
    for key in pairs(Config.Tables) do clear(key) end
end

CreateThread(function()
    while true do
        Wait(1000)
        local pos = GetEntityCoords(PlayerPedId())
        for key, cfg in pairs(Config.Tables) do
            local dist = #(pos - cfg.pos)
            if not drawn[key] and dist <= Config.Distance.propsDraw then
                draw(key)
            elseif drawn[key] and dist > Config.Distance.propsClear then
                clear(key)
            end
        end
    end
end)
