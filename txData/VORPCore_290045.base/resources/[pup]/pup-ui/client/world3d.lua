-- pup-ui | 3D interaction labels: floating pills anchored to world positions, plus native 3D text helpers

local points = {} -- id -> { coords = vec3, text, icon, distance }
local visibleLast = false

local function toVec3(c)
    local t = type(c)
    if t == 'vector3' or t == 'vector4' then return vector3(c.x, c.y, c.z) end
    if t == 'table' then
        local x = tonumber(c.x or c[1])
        local y = tonumber(c.y or c[2])
        local z = tonumber(c.z or c[3])
        if x and y and z then return vector3(x + 0.0, y + 0.0, z + 0.0) end
    end
    return nil
end

function Add3DInteraction(id, data)
    if id == nil or type(data) ~= 'table' then return false end
    local coords = toVec3(data.coords)
    if not coords then
        UiLog(('Add3DInteraction "%s" REJECTED: bad coords'):format(tostring(id)))
        return false
    end
    points[id] = {
        coords = coords,
        text = tostring(data.text or ''),
        icon = data.icon,
        distance = tonumber(data.distance) or 6.0,
        style = data.style,
    }
    UiLog(('Add3DInteraction "%s" (%.1f %.1f %.1f) dist %.1f'):format(
        tostring(id), coords.x, coords.y, coords.z, points[id].distance))
    return true
end

function Remove3DInteraction(id)
    if points[id] then
        points[id] = nil
        UiLog(('Remove3DInteraction "%s"'):format(tostring(id)))
    end
end

function Clear3DInteractions()
    points = {}
    UiLog('Clear3DInteractions')
end

exports('Add3DInteraction', Add3DInteraction)
exports('Remove3DInteraction', Remove3DInteraction)
exports('Clear3DInteractions', Clear3DInteractions)

-- native 3D text, drawn per frame without NUI
local function draw3DText(coords, text, zOrText, legacyText, legacyStyle)
    local x, y, z, str, style
    if type(coords) == 'number' then -- legacy (x, y, z, text [, style])
        x, y, z, str, style = coords, tonumber(text), tonumber(zOrText), legacyText, legacyStyle
    else                             -- (coords, text [, style])
        local v = toVec3(coords)
        if not v then return end
        x, y, z, str, style = v.x, v.y, v.z, text, zOrText
    end
    if not (x and y and z) or str == nil then return end
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    -- optional { r, g, b, a, scale }; any field left out keeps the white default
    if type(style) ~= 'table' then style = nil end
    SetTextScale(0.0, style and tonumber(style.scale) or 0.35)
    SetTextColor(
        style and tonumber(style.r) or 255,
        style and tonumber(style.g) or 255,
        style and tonumber(style.b) or 255,
        style and tonumber(style.a) or 215)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 200)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', tostring(str)), screenX, screenY)
end

exports('Draw3DText', draw3DText)

-- HUD PANEL: native-text editor panel; call DrawHudPanel every frame while it is open

local PANEL <const> = {
    x = 0.15, y = 0.26,
    line = 0.028,
    gap = 0.008,          -- extra space after the title and before the footer
    scaleW = 0.1, scaleH = 0.3,
    sel = { r = 255, g = 214, b = 130 }, -- gold: the row you are changing
    dim = { r = 210, g = 210, b = 210 }, -- everything else
}

local function panelRow(text, y, selected)
    local c <const> = selected and PANEL.sel or PANEL.dim
    SetTextScale(PANEL.scaleW, PANEL.scaleH)
    SetTextColor(c.r, c.g, c.b, 255)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', tostring(text)), PANEL.x, y)
end

local function drawHudPanel(data)
    if type(data) ~= 'table' then return end

    local x <const> = tonumber(data.x) or PANEL.x
    local y = tonumber(data.y) or PANEL.y
    local savedX <const> = PANEL.x
    PANEL.x = x

    if data.title then
        panelRow(data.title, y, true)
        y = y + PANEL.line + PANEL.gap
    end

    for _, row in ipairs(data.rows or {}) do
        if type(row) == 'string' then
            -- '' is a deliberate spacer; a non-empty string is a plain row
            if row ~= '' then panelRow(row, y, false) end
            y = y + PANEL.line
        elseif type(row) == 'table' then
            local sel <const> = row.selected == true
            local text
            if row.text then
                text = row.text
            else
                -- >  LABEL  <  VALUE  >  on the active row
                text = ('%s %-8s  %s %s %s'):format(
                    sel and '>' or ' ', tostring(row.label or ''),
                    sel and '<' or ' ', tostring(row.value or ''),
                    sel and '>' or ' ')
            end
            panelRow(text, y, sel)
            y = y + PANEL.line
        end
    end

    if data.footer then
        y = y + PANEL.gap
        panelRow(data.footer, y, false)
    end

    PANEL.x = savedX
end

exports('DrawHudPanel', drawHudPanel)

-- scan/draw thread: sleeps while nothing is registered or nothing is in range
local function hidePills()
    if visibleLast then
        visibleLast = false
        SendNUIMessage({ action = 'world3dHide' })
    end
end

CreateThread(function()
    while true do
        -- world layers draw last in the page, so they land on top of any open menu
        if IsNuiFocused() then
            hidePills()
            Wait(250)
        elseif next(points) == nil then
            hidePills()
            Wait(500)
        else
            local pCoords = GetEntityCoords(PlayerPedId())
            local anyNear = false
            for _, p in pairs(points) do
                if #(pCoords - p.coords) <= p.distance then
                    anyNear = true
                    break
                end
            end
            if not anyNear then
                hidePills()
                Wait(500)
            else
                local items = {}
                for id, p in pairs(points) do
                    local dist = #(pCoords - p.coords)
                    if dist <= p.distance then
                        local onScreen, sx, sy = GetScreenCoordFromWorldCoord(p.coords.x, p.coords.y, p.coords.z)
                        if onScreen then
                            -- fade + shrink with distance: 1.0 up close -> 0.35 at the edge
                            local a = 1.15 - (dist / p.distance)
                            if a > 1.0 then a = 1.0 elseif a < 0.35 then a = 0.35 end
                            items[#items + 1] = {
                                id = tostring(id),
                                x = sx, y = sy,
                                text = p.text, icon = p.icon, style = p.style,
                                a = math.floor(a * 100) / 100,
                            }
                        end
                    end
                end
                if #items > 0 then
                    visibleLast = true
                    SendNUIMessage({ action = 'world3d', data = { items = items } })
                else
                    hidePills() -- near, but every point is behind the camera
                end
                Wait(0)
            end
        end
    end
end)

-- scene labels: the caller sends one batch per frame, already projected to screen space
local sceneShown = false
exports('DrawSceneLabels', function(items)
    -- same as the pills: a label would sit on top of whatever menu is open
    if type(items) ~= 'table' or #items == 0 or IsNuiFocused() then
        if sceneShown then
            sceneShown = false
            SendNUIMessage({ action = 'sceneLabelsHide' })
        end
        return
    end
    sceneShown = true
    SendNUIMessage({ action = 'sceneLabels', data = { items = items } })
end)

exports('HideSceneLabels', function()
    if not sceneShown then return end
    sceneShown = false
    SendNUIMessage({ action = 'sceneLabelsHide' })
end)

-- a pup-ui stop must not leave pills painted on a page that outlives us
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SendNUIMessage({ action = 'world3dHide' })
        SendNUIMessage({ action = 'sceneLabelsHide' })
    end
end)
