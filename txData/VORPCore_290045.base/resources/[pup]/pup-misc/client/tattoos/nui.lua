-- pup-misc / tattoos - the mirror menu (NUI)

local open     = false
local snapshot = nil     -- the layers as they were on open; Cancel puts them back
local current  = nil     -- layer the right-hand panel is showing

-- eyeliners / shadows / lipsticks are ONE texture with styles inside it
local VARIANTS = { eyeliners = 15, shadows = 5, lipsticks = 7 }
-- these use the texture's own colour, so tints and palette do nothing on them
local NO_TINT  = { scars = true, spots = true, disc = true, complex = true, acne = true,
                   ageing = true, moles = true, freckles = true }

local function label(name)
    return TattooLocale.layers[name] or name
end

local function excluded(name)
    return TattooConfig.Layers.excluded ~= nil and TattooConfig.Layers.excluded[name] == true
end

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- menu sounds are off; a no-op keeps the call sites readable
local function sound(name, set) end

-- a layer the saved row never had gets a sane default instead of a nil index
local function layer(name)
    local info = TattooGetInfo()
    if info[name] == nil then
        info[name] = { visibility = 0, tx_id = 1, var = 0, tx_color_type = NO_TINT[name] and 1 or 0,
            opacity = 1.0, palette_id = 1, palette_color_primary = 0, palette_color_secondary = 0,
            palette_color_tertiary = 0 }
    end
    return info[name]
end

local function categoryOf(name)
    local cats = TattooConfig.Mirror.categories or {}
    for _, cat in ipairs(cats) do
        for _, n in ipairs(cat.layers or {}) do
            if n == name then return cat.id end
        end
    end
    return cats[#cats] and cats[#cats].id or "lifestyle"
end

local function sortedLayers()
    local names = {}
    for name in pairs(TattooGetCatalog()) do
        if not excluded(name) then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return label(a):lower() < label(b):lower() end)
    return names
end

local function buildItems()
    local items, catalog = {}, TattooGetCatalog()
    for _, name in ipairs(sortedLayers()) do
        local l = layer(name)
        local value = 0
        if (tonumber(l.visibility) or 0) ~= 0 then
            value = VARIANTS[name] and 1 or (tonumber(l.tx_id) or 1)
        end
        items[#items + 1] = {
            id = name, name = label(name), category = categoryOf(name),
            totalAmount = #catalog[name], value = value,
        }
    end
    return items
end

local function contextual(name)
    local l = layer(name)
    local tints, advanced = {}, {
        { valueName = "Opacity", valueId = 1, valueValue = math.floor((tonumber(l.opacity) or 1.0) * 100 + 0.5), maxValue = 100, minValue = 0 },
    }
    if (tonumber(l.tx_color_type) or 0) == 0 then
        tints = {
            { tintId = 1, value = tonumber(l.palette_color_primary) or 0 },
            { tintId = 2, value = tonumber(l.palette_color_secondary) or 0 },
            { tintId = 3, value = tonumber(l.palette_color_tertiary) or 0 },
        }
        advanced[#advanced + 1] = { valueName = "Palette", valueId = 2, valueValue = tonumber(l.palette_id) or 1, maxValue = 25, minValue = 1 }
    end
    SendNUIMessage({ type = "contextualDatas", data = {
        category = name, name = label(name),
        variationAmount = VARIANTS[name] or 1, variationValue = tonumber(l.var) or 0,
        tints = tints, advancedValues = advanced,
    } })
end

-- camera: orbits the head, driven by the page's H / Z / R sliders
local cam = nil
local camOffset, camFov, camZoom, camR = 0.0, 40.0, 0.7, 180
local baseHeading, angleOffset = nil, nil

-- declared up here, not with the page state below: camRig reads it and a later
-- `local` would leave this a nil global that always picked the face camera
local bodyMode = false

-- Body Adjustments frames the whole ped; the face pages frame the head
-- minZoom/maxZoom and minOff/maxOff are the travel the keyboard is allowed
local BODY_CAM <const> = { bone = "SKEL_Spine2", zoom = 3.2, fov = 45.0, offset = 0.15,
    minZoom = 1.2, maxZoom = 6.0, minOff = -0.9, maxOff = 1.0 }
local FACE_CAM <const> = { bone = "skel_head",   zoom = 0.7, fov = 40.0, offset = 0.0,
    minZoom = 0.35, maxZoom = 1.8, minOff = -0.3, maxOff = 0.3 }

local function camRig()
    return bodyMode and BODY_CAM or FACE_CAM
end

local function placeCamera()
    local ped = PlayerPedId()
    local rig <const> = camRig()
    local idx = GetEntityBoneIndexByName(ped, rig.bone)
    if idx == -1 then idx = GetEntityBoneIndexByName(ped, "skel_head") end
    local bone = GetWorldPositionOfEntityBone(ped, idx)
    if not baseHeading then
        baseHeading = GetEntityHeading(ped)
        angleOffset = 90 - baseHeading
    end
    local angle = math.rad((camR - angleOffset) % 360)
    local x = bone.x + camZoom * math.cos(angle)
    local y = bone.y + camZoom * math.sin(angle)
    local z = bone.z + camOffset
    -- the target rises WITH the camera. Aiming at the bone while the camera
    -- climbs tilts the shot down instead of lifting it.
    local new = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", x, y, z, 0.0, 0.0, 0.0, camFov, false, 0)
    PointCamAtCoord(new, bone.x, bone.y, z)
    SetCamActive(new, true)
    if cam then
        SetCamActiveWithInterp(new, cam, 0)
        Wait(10)
        SetCamActive(cam, false)
        DestroyCam(cam, false)
    else
        RenderScriptCams(true, true, 800, true, true)
        DisplayHud(false)
        DisplayRadar(false)
    end
    cam = new
end

local function startCamera()
    DestroyAllCams(true)
    cam = nil
    baseHeading, angleOffset = nil, nil
    local rig <const> = camRig()
    camOffset, camFov, camZoom, camR = rig.offset, rig.fov, rig.zoom, 180
    placeCamera()
end

--- Re-frame without restarting the session, for the swap between face and body.
local function reframeCamera()
    local rig <const> = camRig()
    camOffset, camFov, camZoom = rig.offset, rig.fov, rig.zoom
    placeCamera()
end

-- KEYBOARD CAMERA. Same keys as the character creator: A/D orbits, W/S raises
-- and lowers, SHIFT/CTRL pulls in and out.

-- the zoom keys also tighten the field of view; rig.zoom is the resting distance,
-- so this is exactly rig.fov wherever the page opens
local function fovForZoom(rig)
    local t <const> = camZoom / math.max(0.001, rig.zoom)
    local f <const> = rig.fov * (0.75 + 0.25 * t)
    if f < 25.0 then return 25.0 elseif f > 55.0 then return 55.0 end
    return f
end

-- placeCamera builds a new camera and interpolates to it, which is far too heavy
-- to run on a held key. This moves the live one instead.
local function moveCamera()
    if not cam then return placeCamera() end
    local ped <const> = PlayerPedId()
    local rig <const> = camRig()
    local idx = GetEntityBoneIndexByName(ped, rig.bone)
    if idx == -1 then idx = GetEntityBoneIndexByName(ped, "skel_head") end
    local bone <const> = GetWorldPositionOfEntityBone(ped, idx)
    local angle <const> = math.rad((camR - (angleOffset or 0)) % 360)
    local z <const> = bone.z + camOffset
    SetCamCoord(cam, bone.x + camZoom * math.cos(angle), bone.y + camZoom * math.sin(angle), z)
    PointCamAtCoord(cam, bone.x, bone.y, z)
    camFov = fovForZoom(rig)
    SetCamFov(cam, camFov)
end

local CAM_LEFT  <const> = `INPUT_MOVE_LEFT_ONLY`
local CAM_RIGHT <const> = `INPUT_MOVE_RIGHT_ONLY`
local CAM_UP    <const> = `INPUT_MOVE_UP_ONLY`
local CAM_DOWN  <const> = `INPUT_MOVE_DOWN_ONLY`
local CAM_IN    <const> = `INPUT_SPRINT`
local CAM_OUT   <const> = `INPUT_DUCK`

-- the ped is frozen while the page is up, but the axes still fire animations and
-- the wheel keys still open menus over the top of it
local CAM_BLOCKED <const> = {
    CAM_LEFT, CAM_RIGHT, CAM_UP, CAM_DOWN, CAM_IN, CAM_OUT,
    `INPUT_MOVE_LR`, `INPUT_MOVE_UD`, `INPUT_JUMP`, `INPUT_ATTACK`, `INPUT_AIM`,
    `INPUT_OPEN_WHEEL_MENU`, `INPUT_OPEN_SATCHEL_MENU`, `INPUT_OPEN_EMOTE_WHEEL`,
    `INPUT_OPEN_JOURNAL`, `INPUT_MAP`, `INPUT_PLAYER_MENU`, `INPUT_RELOAD`,
    `INPUT_WHISTLE`, `INPUT_TOGGLE_HOLSTER`, `INPUT_ENTER`,
}

local TURN_STEP <const> = 1.5  -- degrees per frame
local VERT_STEP <const> = 0.01 -- metres
local ZOOM_STEP <const> = 0.03 -- metres

local function clampTo(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local camKeysRunning = false

local function startCamKeys()
    if camKeysRunning then return end
    camKeysRunning = true
    CreateThread(function()
        while open do
            Wait(0)
            for _, c in ipairs(CAM_BLOCKED) do DisableControlAction(0, c, true) end

            local rig <const> = camRig()
            local moved = false

            if IsDisabledControlPressed(2, CAM_LEFT) then
                camR = (camR - TURN_STEP) % 360 moved = true
            end
            if IsDisabledControlPressed(2, CAM_RIGHT) then
                camR = (camR + TURN_STEP) % 360 moved = true
            end
            if IsDisabledControlPressed(2, CAM_UP) then
                camOffset = clampTo(camOffset + VERT_STEP, rig.minOff, rig.maxOff) moved = true
            end
            if IsDisabledControlPressed(2, CAM_DOWN) then
                camOffset = clampTo(camOffset - VERT_STEP, rig.minOff, rig.maxOff) moved = true
            end
            if IsDisabledControlPressed(2, CAM_IN) then
                camZoom = clampTo(camZoom - ZOOM_STEP, rig.minZoom, rig.maxZoom) moved = true
            end
            if IsDisabledControlPressed(2, CAM_OUT) then
                camZoom = clampTo(camZoom + ZOOM_STEP, rig.minZoom, rig.maxZoom) moved = true
            end

            if moved then moveCamera() end
        end
        camKeysRunning = false
    end)
end

-- light: two lamps attached to the head, faded in, day / night strength
local lightOn = false
local lamps = {}

local function light(on)
    if not on then lightOn = false return end
    if lightOn then return end
    lightOn = true
    CreateThread(function()
        local ped = PlayerPedId()
        local model = `p_lamphanging06x`
        RequestModel(model)
        local tries = 0
        while not HasModelLoaded(model) and tries < 100 do Wait(50) tries = tries + 1 end
        if not lightOn or not HasModelLoaded(model) then return end
        local at = GetOffsetFromEntityInWorldCoords(ped, 1.2, 1.2, 0.5)
        local head = GetEntityBoneIndexByName(ped, "skel_head")
        local spec = {
            { -1.4, 1.3, 1.5, -36.0, -29.0, 21.0, 800.0, 100.0 },
            {  1.0, -1.1, 1.3, 22.0, 39.0, -10.0, 700.0, 60.0 },
        }
        for i, s in ipairs(spec) do
            local lamp = CreateObject(model, at.x, at.y, at.z, false, true, true)
            SetEntityLightsEnabled(lamp, true)
            SetLightsTypeForEntity(lamp, 20)
            SetLightsColorForEntity(lamp, 255, 200, 170)
            SetLightsIntensityForEntity(lamp, 0.0)
            AttachEntityToEntity(lamp, ped, head, s[1], s[2], s[3], s[4], s[5], s[6], false, false, false, false, 0, false)
            SetEntityAlpha(lamp, 0, false)
            lamps[i] = { ent = lamp, day = s[7], night = s[8] }
        end
        SetModelAsNoLongerNeeded(model)
        for step = 1, 25 do
            if not lightOn then break end
            for _, l in ipairs(lamps) do SetLightsIntensityForEntity(l.ent, (step / 25) * l.day) end
            Wait(20)
        end
        while lightOn do
            local h = GetClockHours()
            local day = h >= 6 and h <= 20
            for _, l in ipairs(lamps) do
                SetLightsIntensityForEntity(l.ent, day and l.day or l.night)
                UpdateLightsOnEntity(l.ent)
            end
            Wait(100)
        end
        for _, l in ipairs(lamps) do DeleteObject(l.ent) end
        lamps = {}
    end)
end

-- open / close  (bodyMode is declared with the camera rigs above)

function TattooNuiOpen()
    if open then return end
    open = true
    bodyMode = false
    current = nil
    snapshot = copy(TattooGetInfo())
    TattooSetCamx(false)   -- the page owns the camera while it is up
    local cats = {}
    for _, c in ipairs(TattooConfig.Mirror.categories or {}) do
        cats[#cats + 1] = { id = c.id, name = c.label or c.id }
    end
    startCamera()
    light(true)
    SendNUIMessage({
        type = "open",
        title = TattooLocale.menuTitle,
        categories = cats,
        items = buildItems(),
        price = TattooConfig.Prices.layers or 0,
        body = not TattooHasMirror(),
    })
    SetNuiFocus(true, true)
    -- the page keeps the mouse; the game still sees the keys, which is what the
    -- camera thread reads. The page has no text fields to steal them.
    SetNuiFocusKeepInput(true)
    startCamKeys()
    sound("INFO", "HUD_SHOP_SOUNDSET")
end

local function closeMenu(restore)
    if not open then return end
    open = false
    bodyMode = false
    current = nil
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
    sound("INFO_HIDE", "HUD_SHOP_SOUNDSET")
    if restore and snapshot then
        TattooSetInfo(snapshot)
        TattooApply()
    end
    snapshot = nil
    light(false)
    TattooClearMirror()
    TattooSetInMenu(false)
    TattooExistAndReset()   -- unfreezes, drops the camera, tells expression.lua
end

-- Body Adjustments as a page view; the session stays up, only the content swaps
local function bodyOpen()
    bodyMode = true
    current = nil
    reframeCamera() -- pull back off the face; this page is about the whole ped
    local d = ExpressionPageData()
    SendNUIMessage({
        type = "open",
        title = TattooLocale.bodyTitle,
        chips = true,
        categories = d.categories,
        items = d.items,
        price = d.price,
        body = true,
        bodyLabel = TattooLocale.backTo .. TattooLocale.menuTitle,
    })
    SendNUIMessage({ type = "hidecontextualDatas" })
end

-- page callbacks
RegisterNUICallback("tattoo_item", function(body, cb)
    cb("ok")
    if not open then return end
    if bodyMode then
        ExpressionPageSet(body.category, tonumber(body.item))
        return
    end
    local name = body.category
    local catalog = TattooGetCatalog()
    if type(name) ~= "string" or not catalog[name] or excluded(name) then return end
    local l = layer(name)
    local value = tonumber(body.item)
    if value ~= nil then
        if value <= 0 then
            l.visibility = 0
        else
            l.visibility = 1
            if not VARIANTS[name] then l.tx_id = math.max(1, math.min(#catalog[name], math.floor(value))) end
        end
        TattooApply()
        sound("Amount_Increase", "HUD_Donate_Sounds")
    end
    current = name
    if (tonumber(l.visibility) or 0) ~= 0 then
        contextual(name)
    else
        SendNUIMessage({ type = "hidecontextualDatas" })
    end
end)

RegisterNUICallback("tattoo_var", function(body, cb)
    cb("ok")
    if not open then return end
    local name = body.category or current
    if type(name) ~= "string" or not TattooGetCatalog()[name] then return end
    local l = layer(name)
    if body.advancedValue == "Opacity" then
        l.opacity = math.max(0.0, math.min(1.0, (tonumber(body.itemValue) or 100) / 100)) + 0.0
    elseif body.advancedValue == "Palette" then
        l.palette_id = math.max(1, math.min(25, math.floor(tonumber(body.itemValue) or 1)))
    elseif body.item ~= nil then
        l.var = math.max(0, math.min(VARIANTS[name] or 0, math.floor(tonumber(body.item) or 0)))
    end
    l.visibility = 1
    TattooApply()
end)

RegisterNUICallback("tattoo_tint", function(body, cb)
    cb("ok")
    if not open then return end
    local name = body.category or current
    if type(name) ~= "string" or not TattooGetCatalog()[name] then return end
    local l = layer(name)
    local v = math.max(0, math.min(254, math.floor(tonumber(body.value) or 0)))
    local id = tonumber(body.tintId)
    if id == 1 then l.palette_color_primary = v
    elseif id == 2 then l.palette_color_secondary = v
    elseif id == 3 then l.palette_color_tertiary = v end
    l.visibility = 1
    TattooApply()
end)

-- kept across the save so a refused purchase can put the old layers back
local pendingSnapshot = nil

RegisterNUICallback("tattoo_save", function(_, cb)
    cb("ok")
    if not open then return end
    if bodyMode then
        -- pays server-side; false = nothing changed. Saved -> the session closes
        if not ExpressionPageSave() then
            TriggerEvent("vorp:TipRight", TattooLocale.noBodyChanges, 3000)
            return
        end
        closeMenu(false)
        return
    end
    pendingSnapshot = snapshot
    TattooApplyAndSave()   -- the server charges TattooConfig.Prices.layers and writes the row
    snapshot = nil
    closeMenu(false)
end)

-- the server's verdict on that save: paid and written, or refused
RegisterNetEvent("pup-misc:overlay:saveResult", function(ok)
    if ok then
        pendingSnapshot = nil
        sound("PURCHASE", "Ledger_Sounds")
        return
    end
    sound("UNAFFORDABLE", "Ledger_Sounds")
    if pendingSnapshot then
        TattooSetInfo(pendingSnapshot)
        pendingSnapshot = nil
        TattooApply()
    end
end)

-- a ped rebuild (spawn, revive, /rc) re-applies the head component, which wipes the overlay texture
AddEventHandler("vorp_character:client:reloadedComponents", function()
    if not TattooLoaded then return end
    local waited = 0
    while waited < 5000 do
        local ped = PlayerPedId()
        if ped ~= 0 and Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) then break end
        Wait(100)
        waited = waited + 100
    end
    Wait(250)
    TattooApply()
    TriggerEvent("pup-misc:overlay:applyExpressionsToPed")
end)

RegisterNUICallback("tattoo_reset", function(_, cb)
    cb("ok")
    if not open then return end
    if bodyMode then
        ExpressionPageResetAll()
        SendNUIMessage({ type = "items", items = ExpressionPageData().items })
        return
    end
    for name, l in pairs(TattooGetInfo()) do
        if not excluded(name) then l.visibility = 0 end
    end
    TattooApply()
    current = nil
    SendNUIMessage({ type = "items", items = buildItems() })
    SendNUIMessage({ type = "hidecontextualDatas" })
    sound("UNAFFORDABLE", "Ledger_Sounds")
end)

RegisterNUICallback("tattoo_cancel", function(_, cb)
    cb("ok")
    closeMenu(true)
end)

-- toggles between the overlay view and Body Adjustments
RegisterNUICallback("tattoo_body", function(_, cb)
    cb("ok")
    if not open then return end
    if bodyMode then
        -- back to the overlay view
        bodyMode = false
        reframeCamera() -- back in close on the face
        current = nil
        local cats = {}
        for _, c in ipairs(TattooConfig.Mirror.categories or {}) do
            cats[#cats + 1] = { id = c.id, name = c.label or c.id }
        end
        SendNUIMessage({
            type = "open",
            title = TattooLocale.menuTitle,
            categories = cats,
            items = buildItems(),
            price = TattooConfig.Prices.layers or 0,
            body = not TattooHasMirror(),
        })
        SendNUIMessage({ type = "hidecontextualDatas" })
    else
        bodyOpen()
    end
end)

-- whichever way the session ends, the lamps go with it
AddEventHandler("pup-misc:overlay:overlayMenuClosed", function()
    light(false)
end)

-- /hud "Menus: Left / Right" (fred_hud) - this page follows it like pup-ui does
AddEventHandler("pup-ui:menuSide", function(side)
    SendNUIMessage({ type = "menuSide", side = (side == "right") and "right" or "left" })
end)
CreateThread(function()
    Wait(1500)
    TriggerEvent("fred_hud:reapplyLayout")
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    if open then
        open = false
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
    light(false)
    for _, l in ipairs(lamps) do DeleteObject(l.ent) end
end)
