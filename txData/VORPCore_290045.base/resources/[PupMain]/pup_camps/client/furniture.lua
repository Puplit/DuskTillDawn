-- pup_camps | furniture menu and placement

Furniture = {}

local PLACE_OWNER <const> = 'pup_camps:furni'
local focused = nil     -- { campId, pieceId, selected = bool } piece marked in the manage list
local placing = nil     -- promise while pup-ui placement runs

local function camp(id) return State.camps[id] end

local function piecesOf(v)
    local list = {}
    for _, p in ipairs(v.furni or {}) do
        if p.item ~= Config.Camp.flagItem then list[#list + 1] = p end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function pieceById(id, pieceId)
    local v = camp(id)
    if not v then return nil end
    for _, p in ipairs(v.furni or {}) do if p.id == pieceId then return p end end
    return nil
end

------------------------------------------------------------------------------ marker over the focused piece

local function drawText3D(pos, text)
    local on, sx, sy = GetScreenCoordFromWorldCoord(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    if not on then return end
    SetTextScale(0.35, 0.35)
    SetTextColor(255, 230, 160, 255)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), sx, sy)
end

local function startMarker()
    CreateThread(function()
        while focused and Menu.isOpen() do
            local p = pieceById(focused.campId, focused.pieceId)
            if p and p.coords then
                N(0x2A32FAA57B937173, 0x94FDAE17, p.coords.x + 0.0, p.coords.y + 0.0, p.coords.z + 1.6,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.6, 0.15, 240, 190, 60, 170, false, false, 2, false, nil, nil, false)
                if focused.selected then drawText3D({ x = p.coords.x, y = p.coords.y, z = p.coords.z + 2.0 }, L('furni_selected')) end
            end
            Wait(0)
        end
        focused = nil
    end)
end

local function focus(campId, pieceId, selected)
    local was = focused
    focused = { campId = campId, pieceId = pieceId, selected = selected == true }
    if not was then startMarker() end
end

------------------------------------------------------------------------------ placement

AddEventHandler('pup-ui:client:placeConfirm', function(owner, place)
    if owner ~= PLACE_OWNER or not placing then return end
    local p = placing
    placing = nil
    p:resolve(place)
end)

AddEventHandler('pup-ui:client:placeCancel', function(owner)
    if owner ~= PLACE_OWNER or not placing then return end
    local p = placing
    placing = nil
    p:resolve(nil)
end)

-- vorp_lib drag gizmo on a local ghost 1.5 m in front of the player.
-- Returns a spot, nil when cancelled, or false when the gizmo cannot be used.
local function gizmoSpot(model, heading)
    if not Config.Camp.useGizmo or not Integrations.running('vorp_lib') then return false end
    local hash = LoadModel(model)
    if not hash then return false end
    local ped = PlayerPedId()
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    local ghost = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ghost or ghost == 0 then return false end
    SetEntityHeading(ghost, (heading or GetEntityHeading(ped)) + 0.0)
    SetEntityCollision(ghost, false, false)
    local res = Integrations.gizmo(ghost, Config.Camp.gizmoRange)
    if DoesEntityExist(ghost) then DeleteObject(ghost) end
    if res == false then return false end
    if type(res) ~= 'table' or not res.position then return nil end
    local pos, rot = res.position, res.rotation
    return { x = pos.x, y = pos.y, z = pos.z, heading = rot and rot.z or heading or 0.0, grounded = false }
end

-- places a piece (vorp_lib gizmo when available, else pup-ui's placement tool);
-- true when the server stored the new spot
local function place(id, piece)
    local v = camp(id)
    if not v or placing then return false end
    local model = piece.cata == 'set' and Config.Camp.setTentModel or piece.prop
    local gspot = gizmoSpot(type(model) == 'number' and U.signed(model) or model, piece.heading)
    if gspot ~= false then
        if not gspot then return false end
        if U.dist3(gspot, v.coords) > Config.Camp.furnitureRadius then
            Notify(L('furni_out_of_area'))
            return false
        end
        local ok = Ask('furniPlace', id, piece.id, gspot)
        if ok then Notify(L('furni_placed')) end
        return ok
    end
    local p = promise.new()
    placing = p
    local started = exports['pup-ui']:StartPlacement({
        owner = PLACE_OWNER, model = type(model) == 'number' and U.signed(model) or model,
        heading = piece.heading or 0.0, grounded = true,
        title = L('placing_title', piece.label or piece.item),
        bounds = { x = v.coords.x, y = v.coords.y, z = v.coords.z, radius = Config.Camp.furnitureRadius },
    })
    if not started then
        placing = nil
        Notify(L('furni_bad_prop'))
        return false
    end
    -- pup-ui ends a placement WITHOUT an event when another resource starts its own or
    -- calls CancelPlacement; without this the menu would stay hidden and the player frozen
    CreateThread(function()
        while placing == p do
            Wait(500)
            local ok, still = pcall(function() return exports['pup-ui']:IsPlacing() end)
            if placing == p and (not ok or still ~= true) then
                placing = nil
                p:resolve(nil)
            end
        end
    end)
    local spot = Citizen.Await(p)
    if not spot then return false end
    if U.dist3(spot, v.coords) > Config.Camp.furnitureRadius then
        Notify(L('furni_out_of_area'))
        return false
    end
    local ok = Ask('furniPlace', id, piece.id, { x = spot.x, y = spot.y, z = spot.z, heading = spot.heading, grounded = spot.grounded == true })
    if ok then Notify(L('furni_placed')) end
    return ok
end

------------------------------------------------------------------------------ pages

local managePage

local function piecePage(id, pieceId)
    local piece = pieceById(id, pieceId)
    if not piece then return nil end
    return {
        title = piece.label, subtitle = L('furni_piece_desc', piece.id, tostring(piece.active == true)),
        onBack = function()
            if focused then focused.selected = false end
            Menu.back()
            Menu.replace(managePage(id))
        end,
        rows = {
            { label = L('furni_move'), onSelect = function()
                local cur = pieceById(id, pieceId)
                if not cur then return end
                if cur.active and not Ask('furniLift', id, pieceId) then return end
                Menu.hide()
                place(id, cur)
                Menu.back()
                Menu.replace(managePage(id))
            end },
            { label = L('furni_remove'), onSelect = function()
                Menu.confirm(L('confirm_title'), piece.label, function()
                    Ask('furniRemove', id, pieceId)
                    Menu.back()
                    Menu.back()
                    Menu.replace(managePage(id))
                end)
            end },
        },
    }
end

managePage = function(id)
    local v = camp(id)
    if not v then return nil end
    local rows = {}
    for _, p in ipairs(piecesOf(v)) do
        rows[#rows + 1] = {
            label = (p.active and '✓ ' or '○ ') .. (p.label or p.item),
            description = L('furni_piece_desc', p.id, tostring(p.active == true)),
            onFocus = function() focus(id, p.id, false) end,
            onSelect = function()
                local page = piecePage(id, p.id)
                if page then
                    focus(id, p.id, true)
                    Menu.push(page)
                end
            end,
        }
    end
    if #rows == 0 then rows[1] = { label = L('furni_none_placed'), disabled = true } end
    local first = piecesOf(v)[1]
    if first then focus(id, first.id, false) end
    return { title = L('furni_manage'), subtitle = L('furni_count', #piecesOf(v), Config.Camp.maxPieces), rows = rows,
        onBack = function()
            focused = nil
            Menu.back()
        end }
end

local function addPage(id)
    local list = Request('furniItems', id)
    if type(list) ~= 'table' then return nil end
    local rows = {}
    for _, it in ipairs(list) do
        rows[#rows + 1] = { label = it.label, description = L('count', it.count), onSelect = function()
            local piece = Ask('furniAdd', id, it.item)
            if type(piece) ~= 'table' then return end
            Menu.hide()
            place(id, piece)
            Menu.back()
            Menu.replace(Furniture.page(id))
        end }
    end
    if #rows == 0 then rows[1] = { label = L('furni_none'), disabled = true } end
    return { title = L('furni_add'), rows = rows }
end

function Furniture.page(id)
    local v = camp(id)
    if not v then return nil end
    local count = #piecesOf(v)
    return {
        title = L('furniture'), subtitle = L('furni_count', count, Config.Camp.maxPieces),
        rows = {
            { label = L('furni_add'), description = L('furni_add_desc'), onSelect = function()
                local cur = camp(id)
                local n = cur and #piecesOf(cur) or 0
                if n >= Config.Camp.maxPieces then return Notify(L('furni_limit', n, Config.Camp.maxPieces)) end
                local page = addPage(id)
                if page then Menu.push(page) end
            end },
            { label = L('furni_manage'), description = L('furni_manage_desc'), onSelect = function()
                local page = managePage(id)
                if page then Menu.push(page) end
            end },
        },
    }
end

function Furniture.openMenu(id)
    local page = Furniture.page(id)
    if page then Menu.push(page) end
end

OnState('stop', function()
    focused = nil
    if placing then pcall(function() exports['pup-ui']:CancelPlacement() end) end
end)
