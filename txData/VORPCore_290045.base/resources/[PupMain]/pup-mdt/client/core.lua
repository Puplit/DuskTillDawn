-- pup-mdt client | shared helpers: RPC with request ids, notifications, page messages, fades, blips, zones

MdtC = MdtC or {}
MdtC.mdtOpen = false
MdtC.onDuty = false
MdtC.isLawyer = false
MdtC.region = nil

local Core = nil
local function core()
    if not Core then
        local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
        if ok then Core = c end
    end
    return Core
end
MdtC.core = core

---------------------------------------------------------------------------
-- RPC: one request id per call, so overlapping requests never swap answers
---------------------------------------------------------------------------
local reqSeq, pending = 0, {}

-- MdtC.rpc(name, payload, timeoutMs, fallback, cb): cb(result) runs once, with fallback on timeout
function MdtC.rpc(name, payload, timeoutMs, fallback, cb)
    reqSeq = reqSeq + 1
    local id = reqSeq
    pending[id] = cb or function() end
    TriggerServerEvent('pup-mdt:server:rpc', id, name, payload)
    SetTimeout(timeoutMs or 8000, function()
        local f = pending[id]
        if f then
            pending[id] = nil
            f(fallback)
        end
    end)
end

RegisterNetEvent('pup-mdt:client:rpc', function(id, result)
    local f = pending[id]
    if not f then return end
    pending[id] = nil
    f(result)
end)

---------------------------------------------------------------------------
-- page messages
---------------------------------------------------------------------------
function MdtC.send(msg)
    SendNUIMessage(msg)
end

-- tip while nothing is open, the page's own slip while the MDT is open
function MdtC.notify(text, ms)
    if text == nil or text == '' then return end
    ms = tonumber(ms) or (Config.Notify and Config.Notify.defaultMs) or 4000
    if MdtC.mdtOpen then
        SendNUIMessage({ action = 'mdtToast', message = tostring(text), duration = ms })
        return
    end
    local c = core()
    if c and c.NotifyRightTip then
        c.NotifyRightTip(tostring(text), ms)
    else
        TriggerEvent('vorp:TipRight', tostring(text), ms)
    end
end

-- the resource's notification dispatcher (local event other code may fire)
AddEventHandler('mdt:tip', function(text, ms) MdtC.notify(text, ms) end)
RegisterNetEvent('pup-mdt:client:notify', function(text, ms) MdtC.notify(text, ms) end)

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------
-- x, y, z, heading from a vector3/vector4 or a {x,y,z,h} table
-- (vectors are read only through x/y/z/w: any other field name on a vector raises an error)
function MdtC.xyzh(p)
    local t = type(p)
    local x, y, z, hd
    if t == 'vector3' or t == 'vector4' then
        x, y, z = p.x, p.y, p.z
        if t == 'vector4' then hd = p.w end
    elseif t == 'table' then
        x, y, z = tonumber(p.x or p[1]), tonumber(p.y or p[2]), tonumber(p.z or p[3])
        hd = tonumber(p.h or p.heading or p.w or p[4])
    else
        return nil
    end
    if not x or not y or not z then return nil end
    return x + 0.0, y + 0.0, z + 0.0, (tonumber(hd) or 0.0) + 0.0
end

-- a boolean native read as an integer (0 is false)
function MdtC.nativeTrue(hash, ...)
    local args = table.pack(...)
    args[args.n + 1] = Citizen.ResultAsInteger()
    local v = Citizen.InvokeNative(hash, table.unpack(args, 1, args.n + 1))
    return v ~= nil and v ~= 0 and v ~= false
end

function MdtC.dist(a, x, y, z)
    local dx, dy, dz = a.x - x, a.y - y, a.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function MdtC.loadModel(model, timeoutMs)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer() + (timeoutMs or 10000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil end
        Wait(20)
    end
    return hash
end

function MdtC.loadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(20)
    end
    return true
end

function MdtC.fadeOut(ms)
    DoScreenFadeOut(ms)
    local t = GetGameTimer() + ms + 1500
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(10) end
end

function MdtC.fadeIn(ms)
    DoScreenFadeIn(ms)
end

-- ground z near a point: `tries` attempts `gap` ms apart, probing from `above` metres up
function MdtC.groundZ(x, y, z, tries, gap, above)
    RequestCollisionAtCoord(x, y, z)
    for _ = 1, tries or 10 do
        local found, gz = GetGroundZFor_3dCoord(x, y, z + (above or 10.0), false)
        if found and gz and gz ~= 0.0 then return gz end
        Wait(gap or 100)
    end
    return z
end

-- fade, ground-snap and place the ped; `lift` metres above the ground
function MdtC.teleport(point, opts)
    local x, y, z, hd = MdtC.xyzh(point)
    if not x then return end
    opts = opts or {}
    local ped = PlayerPedId()
    MdtC.fadeOut(opts.fade or 600)
    if opts.wait then Wait(opts.wait) end
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    local gz = MdtC.groundZ(x, y, z, opts.tries or 10, opts.gap or 100, opts.above or 10.0)
    SetEntityCoords(ped, x, y, gz + (opts.lift or 1.0), false, false, false, false)
    SetEntityHeading(ped, hd)
    if opts.pause then Wait(opts.pause) end
    MdtC.fadeIn(opts.fade or 600)
end

---------------------------------------------------------------------------
-- blips
---------------------------------------------------------------------------
local function hashOf(v)
    if type(v) == 'number' then return v end
    return joaat(tostring(v))
end

function MdtC.blip(x, y, z, sprite, scale, name)
    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, x + 0.0, y + 0.0, z + 0.0)
    SetBlipSprite(b, hashOf(sprite), true)
    SetBlipScale(b, (scale or 0.2) + 0.0)
    if name then
        Citizen.InvokeNative(0x9CB1A1623062F402, b, CreateVarString(10, 'LITERAL_STRING', tostring(name)))
    end
    return b
end

function MdtC.blipModifier(b, modifier)
    if b and modifier then Citizen.InvokeNative(0x662D364ABF16DE2F, b, hashOf(modifier)) end
end

function MdtC.radiusBlip(x, y, z, radius)
    return Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, x + 0.0, y + 0.0, z + 0.0, (radius or 50.0) + 0.0)
end

function MdtC.removeBlip(b)
    if b and DoesBlipExist(b) then RemoveBlip(b) end
end

---------------------------------------------------------------------------
-- GPS routes: one owner at a time, so one system never clears another's route
---------------------------------------------------------------------------
local routeOwner = nil

function MdtC.setRoute(owner, x, y, z, colour)
    ClearGpsMultiRoute()
    StartGpsMultiRoute(joaat(colour or 'COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(x + 0.0, y + 0.0, z + 0.0)
    SetGpsMultiRouteRender(true)
    routeOwner = owner
end

function MdtC.clearRoute(owner)
    if owner and routeOwner ~= owner then return end
    ClearGpsMultiRoute()
    routeOwner = nil
end

function MdtC.routeOwner() return routeOwner end

---------------------------------------------------------------------------
-- on-screen text lines (reminders)
---------------------------------------------------------------------------
-- western game font with a hard shadow; start the text with ~e~ for red (scaleY defaults to scale)
function MdtC.drawText(text, x, y, scale, scaleY)
    SetTextFontForCurrentCommand(1)
    SetTextScale(scale or 0.3, scaleY or scale or 0.3)
    SetTextColor(255, 255, 255, 255)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextCentre(false)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), x, y)
end

---------------------------------------------------------------------------
-- zones and client exports
---------------------------------------------------------------------------
function MdtC.zoneName(coords, types)
    local x, y, z = MdtC.xyzh(coords)
    if not x then return PupMdtZones and PupMdtZones.unknown or 'Unknown Zone' end
    if PupMdtZones then
        for _, l in ipairs(PupMdtZones.landmarks or {}) do
            local dx, dy = x - l.coords.x, y - l.coords.y
            if math.sqrt(dx * dx + dy * dy) <= l.radius then return l.name end
        end
    end
    for _, t in ipairs(types or (Config.Zones and Config.Zones.lookupTypes) or { 0, 12, 13, 10, 1 }) do
        local h = Citizen.InvokeNative(0x43AD8FC02B429D33, x, y, z, t)
        local name = PupMdtZones and PupMdtZones.nameFromHash(h)
        if name then return name end
    end
    if PupMdtZones then return PupMdtZones.nameFromCoords({ x = x, y = y, z = z }) end
    return 'Unknown Zone'
end

exports('GetZoneName', function(coords) return MdtC.zoneName(coords) end)
-- law duty only, like the server's IsPlayerOnDuty: attorneys on duty answer false
exports('IsOnDuty', function() return MdtC.onDuty == true and MdtC.dutyLawyer ~= true end)
exports('GetEvidenceStations', function()
    local out = {}
    for _, s in ipairs((Config.Evidence and Config.Evidence.stations) or {}) do
        out[#out + 1] = { id = s.id, label = s.label }
    end
    return out
end)

function MdtC.myCoords()
    local c = GetEntityCoords(PlayerPedId())
    return { x = c.x, y = c.y, z = c.z }
end

-- does pup-ui exist and run
function MdtC.pupUi()
    return GetResourceState('pup-ui') == 'started'
end

-- the pill lives 800 ms per refresh, so callers in a per-frame loop only refresh it every 300 ms
local promptLabel, promptAt = nil, 0
function MdtC.prompt(label)
    local now = GetGameTimer()
    if label == promptLabel and now - promptAt < 300 then return end
    promptLabel, promptAt = label, now
    if MdtC.pupUi() then
        exports['pup-ui']:Prompt({ key = 'G', label = label, ttl = 800 })
    end
end

function MdtC.promptHide()
    promptLabel, promptAt = nil, 0
    if MdtC.pupUi() then exports['pup-ui']:PromptHide() end
end

-- a kiosk or board page holds the cursor ('pending' means only a request is in flight)
function MdtC.pageHoldsFocus()
    return MdtC.kioskOpen == true or MdtC.boardOpen == 'bh' or MdtC.boardOpen == 'jr'
end
