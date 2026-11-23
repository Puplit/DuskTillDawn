-- pup_postoffice | client: mail offices, blips, the floating prompt and the office menu

local MENU_OWNER <const> = 'pup_postoffice:office'

local blips = {}
local menu = nil -- { origin = vector3, actions = { 'register' | 'open', ... } }

--------------------------------------------------------------------------------
-- blips

local function addBlips()
    local B = Config.Blip
    for _, office in ipairs(Config.Offices) do
        if office.blip then
            local c = office.coords
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, B.style, c.x, c.y, c.z) -- BLIP_ADD_FOR_COORDS
            SetBlipSprite(blip, B.sprite, true)
            SetBlipScale(blip, B.scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', B.name)) -- SET_BLIP_NAME
            blips[#blips + 1] = blip
        end
    end
end

local function removeBlips()
    for i = #blips, 1, -1 do
        if DoesBlipExist(blips[i]) then RemoveBlip(blips[i]) end
        blips[i] = nil
    end
end

--------------------------------------------------------------------------------
-- floating text on a dark card

local function drawPrompt(pos, text)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z + 0.25)
    if not onScreen then return end
    local width = 0.012 + (#text * 0.0052)
    DrawRect(sx, sy + 0.0125, width, 0.034, 12, 10, 8, 190, false, false)
    SetTextScale(0.32, 0.32)
    SetTextColor(240, 228, 205, 235)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 200)
    Citizen.InvokeNative(0xD79334A4BB99BAD1, CreateVarString(10, 'LITERAL_STRING', text), sx, sy) -- DISPLAY_TEXT
end

--------------------------------------------------------------------------------
-- office menu (pup-ui ink menu)

local function closeMenu()
    if not menu then return end
    menu = nil
    exports['pup-ui']:HideInkMenu()
end

local function openMenu(origin)
    local options, actions = {}, {}
    if not Mail.box then
        options[#options + 1] = { label = L.menuRegister, description = ('$%s'):format(tostring(Config.BoxPrice)) }
        actions[#actions + 1] = 'register'
    end
    if Config.LocationOnly then
        options[#options + 1] = { label = L.menuOpen }
        actions[#actions + 1] = 'open'
    end
    if #options == 0 then return end
    menu = { origin = origin, actions = actions }
    exports['pup-ui']:OpenInkMenu({ owner = MENU_OWNER, title = L.menuTitle, startIndex = 1, options = options })

    -- close the menu once the player walks away
    CreateThread(function()
        local mine = menu
        while menu == mine do
            Wait(250)
            if menu ~= mine then break end
            local p = GetEntityCoords(PlayerPedId())
            local dx, dy = p.x - origin.x, p.y - origin.y
            if math.sqrt(dx * dx + dy * dy) > Config.MenuCloseDistance then
                closeMenu()
            end
        end
    end)
end

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= MENU_OWNER or not menu then return end
    local action = menu.actions[tonumber(index) or 0]
    closeMenu()
    if action == 'register' then
        TriggerServerEvent('pup_postoffice:register')
    elseif action == 'open' then
        local ped = PlayerPedId()
        if Mail.restrained(ped) then return end
        if not Mail.box then return TriggerEvent('vorp:TipRight', L.needRegister, 4000) end
        Mail.openWindow()
    end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= MENU_OWNER then return end
    menu = nil
end)

--------------------------------------------------------------------------------
-- proximity: a slow scan, and a per-frame loop only while standing at a counter

local function nearestPoint(ped)
    local pos = GetEntityCoords(ped)
    local reach = Config.ClientReach
    for _, office in ipairs(Config.Offices) do
        if #(pos - office.coords) <= reach then return office.coords, false end
    end
    if Config.MailboxProps.enabled then
        local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, reach, joaat(Config.MailboxProps.model), false, false, false)
        if obj and obj ~= 0 then return pos, true end
    end
    return nil
end

local function promptWanted()
    return not Mail.open and not menu and (not Mail.box or Config.LocationOnly)
end

CreateThread(function()
    addBlips()
    local key = Config.InteractKey
    while true do
        local ped = PlayerPedId()
        local point, isProp = nil, false
        if promptWanted() then point, isProp = nearestPoint(ped) end
        if not point then
            Wait(500)
        else
            -- standing at a counter: draw and listen every frame, re-check the spot twice a second
            local until_ = GetGameTimer() + 500
            while GetGameTimer() < until_ and promptWanted() do
                ped = PlayerPedId()
                local at = isProp and GetEntityCoords(ped) or point
                drawPrompt(at, L.promptText)
                if IsControlJustReleased(0, key) and not Mail.busy(ped) then
                    openMenu(GetEntityCoords(ped))
                    break
                end
                Wait(0)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeMenu()
    removeBlips()
end)
