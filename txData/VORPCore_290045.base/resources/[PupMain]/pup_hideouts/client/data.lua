-- pup_hideouts | rows from the server, map blips, police / owner alerts

local blips = {}
local blipTimer = nil

local function clearBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
end

-- staff jobs see every hideout; admins only when the setting says so (flags come from the server)
local function seesAll()
    local f = HX.flags or {}
    if U.inList(Config.StaffJobs, f.job) then return true end
    return Config.Hideouts.adminsSeeAllBlips and f.admin == true
end

function HX.rebuildBlips()
    clearBlips()
    local all = seesAll()
    for _, r in pairs(HX.rows) do
        if (all or r.member) and r.coords then
            local b = BlipAddForCoords(Config.Hideouts.blipStyle, r.coords.x, r.coords.y, r.coords.z)
            SetBlipSprite(b, Config.Hideouts.blipSprite, true)
            SetBlipScale(b, 0.2) -- small
            Citizen.InvokeNative(0x9CB1A1623062F402, b, CreateVarString(10, 'LITERAL_STRING', r.name or 'Hideout')) -- SET_BLIP_NAME
            blips[#blips + 1] = b
        end
    end
end

-- half a second after the signal, so a burst of changes builds once
function HX.blipsSoon()
    if blipTimer then return end
    blipTimer = true
    SetTimeout(500, function()
        blipTimer = nil
        HX.rebuildBlips()
    end)
end

RegisterNetEvent('pup_hideouts:blips', function() HX.blipsSoon() end)

RegisterNetEvent('pup_hideouts:hello', function(charId)
    HX.charId = charId
end)

RegisterNetEvent('pup_hideouts:rows', function(list)
    local fresh = {}
    for _, r in ipairs(type(list) == 'table' and list or {}) do
        if r.id then fresh[r.id] = r end
    end
    HX.rows = fresh
    HX.blipsSoon()
    TriggerEvent('pup_hideouts:rowsChanged')
    if HX.insideId then
        if not HX.rows[HX.insideId] then HX.leave() else HX.applyLook(HX.rows[HX.insideId]) end
    end
end)

RegisterNetEvent('pup_hideouts:row', function(r)
    if type(r) ~= 'table' or not r.id then return end
    local before = HX.rows[r.id]
    HX.rows[r.id] = r
    if not before or before.member ~= r.member or before.name ~= r.name
        or U.dist(before.coords, r.coords) > 0.1 then
        HX.blipsSoon()
    end
    TriggerEvent('pup_hideouts:rowChanged', r.id)
    if HX.insideId == r.id then HX.applyLook(r) end
end)

RegisterNetEvent('pup_hideouts:removed', function(id)
    HX.rows[id] = nil
    HX.blipsSoon()
    if HX.insideId == id then HX.leave() end
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    HX.rows = {}
    clearBlips()
    CreateThread(function()
        Wait(2000)
        HX.call('rows', 5000)
    end)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, imap in ipairs(Config.Imaps) do RequestImap(joaat(imap)) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
end)

----------------------------------------------------------------------------------------------------
-- alerts (police fallback and owners' raid alerts)
----------------------------------------------------------------------------------------------------
local alert = { blips = {}, text = nil, until_ = 0, running = false }

local function clearAlerts()
    for _, b in ipairs(alert.blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    alert.blips, alert.text, alert.until_ = {}, nil, 0
end

local function drawLine(text, y)
    SetTextScale(0.0, 0.42)
    SetTextColor(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), 0.5, y)
end

local function showAlert(coords, text)
    local c = U.vec(coords)
    if c then
        local b = BlipAddForCoords(1664425300, c.x, c.y, c.z)
        SetBlipSprite(b, Config.AlertBlip.sprite, true)
        Citizen.InvokeNative(0x662D364ABF16DE2F, b, Config.AlertBlip.color) -- BLIP_ADD_MODIFIER
        alert.blips[#alert.blips + 1] = b
    end
    alert.text = text
    alert.until_ = GetGameTimer() + Config.AlertMinutes * 60000
    if alert.running then return end
    alert.running = true
    CreateThread(function()
        while alert.text and GetGameTimer() < alert.until_ do
            Wait(0)
            drawLine(alert.text, 0.04)
            drawLine(L('alert_footer', Config.AlertCommand), 0.075)
        end
        clearAlerts()
        alert.running = false
    end)
end

RegisterNetEvent('pup_hideouts:alert', function(coords, text)
    showAlert(coords, text or L('crime_reported'))
end)

RegisterNetEvent('pup_hideouts:ownerAlert', function(coords, text)
    showAlert(coords, text or L('raid_alert_plain'))
end)

RegisterCommand(Config.AlertCommand, function()
    alert.text = nil
    clearAlerts()
end, false)
