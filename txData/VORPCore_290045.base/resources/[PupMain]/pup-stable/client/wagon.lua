-- pup-stable | your wagon in the world: calling, fleeing, repairing, stabling, the U menu and the locker

Wagon = { cur = nil, calling = false, blip = nil }
local W = Config.Wagon

local function setBlip(veh, label)
    N.blipRemove(Wagon.blip)
    local b = N.blipEntity(joaat('BLIP_STYLE_PLAYER_COACH'), veh)
    if b and b ~= 0 then N.blipName(b, label) Wagon.blip = b end
end

function Wagon.adopt(row, veh)
    Wagon.cur = { id = row.id, veh = veh, row = row }
    if not W.canBeDamaged then
        SetEntityInvincible(veh, true)
        SetVehicleCanBreak(veh, false)
    end
    setBlip(veh, (row.name and row.name ~= '') and row.name or L('blipWagon'))
end

function Wagon.forget(delete)
    local c = Wagon.cur
    if c and delete and DoesEntityExist(c.veh) then
        SetEntityAsMissionEntity(c.veh, true, true)
        DeleteEntity(c.veh)
    end
    N.blipRemove(Wagon.blip)
    Wagon.blip, Wagon.cur = nil, nil
end

function Wagon.refind()
    local myId = GetPlayerServerId(PlayerId())
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local st = Entity(veh).state
        local id = U.int(st.pup_stable_wagonID)
        if id and st.pup_stable_wagonOwner == myId and Me.wagons[id] then
            Wagon.adopt(Me.wagons[id], veh)
            return
        end
    end
end

------------------------------------------------------------------------------
-- calling a wagon
------------------------------------------------------------------------------
local function spawnSpot()
    local me = PlayerPedId()
    local p = GetEntityCoords(me)
    local fwd = GetEntityForwardVector(me)
    local want = p + fwd * W.callAhead
    local radius = W.callSearch * 2.0
    if InTown(p, W.noCallTowns) then radius = radius / 1.75 end
    local ok, node = GetClosestVehicleNode(want.x, want.y, want.z, 1, 3.0, 0.0)
    if ok and node and #(node - want) <= radius then return vector4(node.x, node.y, node.z, GetEntityHeading(me)) end
    local okG, gz = GetGroundZFor_3dCoord(want.x, want.y, want.z + 10.0, false)
    return vector4(want.x, want.y, okG and gz or p.z, GetEntityHeading(me))
end

function Wagon.call()
    if Wagon.calling then return Tip(L('wagonOnWay')) end
    if InTown(GetEntityCoords(PlayerPedId()), W.noCallTowns) then return Tip(L('noWagonInTown')) end
    Wagon.calling = true
    local ok = false
    local p = promise.new()
    CreateThread(function() p:resolve(RefreshWagons()) end)
    SetTimeout(8000, function() p:resolve(false) end)
    ok = Citizen.Await(p)
    if not ok then Wagon.calling = false return Tip(L('stableUnreachable')) end
    local options = {}
    local ids = {}
    for _, w in pairs(Me.wagons) do ids[#ids + 1] = w end
    table.sort(ids, function(a, b) return a.label:lower() < b.label:lower() end)
    for _, w in ipairs(ids) do
        local def = WagonDefOf(w.model)
        local parts = { w.model }
        if def and def.seatsHint then parts[#parts + 1] = ('%s: %d'):format(L('seats'), def.seatsHint) end
        if def and def.horsesHint then parts[#parts + 1] = ('%s: %d'):format(L('harness'), def.horsesHint) end
        if w.locker then parts[#parts + 1] = L('slots', w.locker.slots) end
        options[#options + 1] = { label = w.label, desc = table.concat(parts, ' | '), value = w.id }
    end
    if #options == 0 then Wagon.calling = false return Tip(L('noWagon')) end
    local pick = Choose(L('callWagon'), nil, options)
    if not pick then Wagon.calling = false return end
    if InTown(GetEntityCoords(PlayerPedId()), W.noCallTowns) then Wagon.calling = false return Tip(L('noWagonInTown')) end
    local row = Me.wagons[pick]
    if not row then Wagon.calling = false return end
    local me = PlayerPedId()
    if W.whistle and not IsPedInAnyVehicle(me, false) then
        Horse.ignoreFollow(3000)
        TaskWhistleAnim(me, joaat('WHISTLEHORSELONG'), joaat('UNSPECIFIED'))
        Wait(W.whistleMs)
    end
    if Wagon.cur and Wagon.cur.id == pick then Wagon.forget(true) end
    local veh = Look.spawnWagon(row, spawnSpot(), true, true)
    if veh then
        SetEntityAlpha(veh, 0, false)
        Wagon.adopt(row, veh)
        for a = 0, 255, 51 do SetEntityAlpha(veh, a, false) Wait(60) end
        ResetEntityAlpha(veh)
    end
    SetTimeout(W.callLockMs, function() Wagon.calling = false end)
end

if Config.Commands.callWagon then RegisterCommand(Config.Commands.callWagon, function() CreateThread(Wagon.call) end, false) end

------------------------------------------------------------------------------
-- stabling, fleeing, repairing
------------------------------------------------------------------------------
function Wagon.stableIt(stableId, veh)
    if not veh or veh == 0 then return end
    local net = NetIdOf(veh)
    if not net then return Tip(L('cantStableWagon')) end
    local ok = CallTip('stableWagon', net, stableId)
    if not ok then return end
    local me = PlayerPedId()
    TaskLeaveVehicle(me, veh, 0)
    Wait(1500)
    if Wagon.cur and Wagon.cur.veh == veh then Wagon.forget(true) elseif DoesEntityExist(veh) then DeleteEntity(veh) end
end

local function nearestVehicle(radius)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD = nil, radius
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - me)
        if d <= bestD then best, bestD = v, d end
    end
    return best
end
Wagon.nearestVehicle = nearestVehicle

local function myWagon(veh)
    local st = Entity(veh).state
    return st.pup_stable_wagonOwner == GetPlayerServerId(PlayerId()) and U.int(st.pup_stable_wagonID) or nil
end

if Config.Commands.fleeWagon then
    RegisterCommand(Config.Commands.fleeWagon, function()
        local veh = nearestVehicle(10.0)
        if not veh then return Tip(L('noWagonNear')) end
        local id = myWagon(veh)
        if not id then return Tip(L('cantFleeWagon')) end
        local me = PlayerPedId()
        if GetVehiclePedIsIn(me, false) == veh then
            TaskLeaveVehicle(me, veh, 0)
            Wait(1500)
        end
        local driver = GetPedInVehicleSeat(veh, -1)
        local p = GetEntityCoords(veh)
        local ok, node = GetClosestVehicleNode(p.x + math.random(-200, 200), p.y + math.random(-200, 200), p.z, 1, 3.0, 0.0)
        if driver ~= 0 and not IsPedAPlayer(driver) and ok then
            TaskVehicleDriveToCoord(driver, veh, node.x, node.y, node.z, 8.0, 0, GetEntityModel(veh), 786603, 5.0, 0)
        end
        local t0 = GetGameTimer()
        while GetGameTimer() - t0 < 5000 and IsEntityOnScreen(veh) do Wait(250) end
        for a = 255, 0, -51 do if DoesEntityExist(veh) then SetEntityAlpha(veh, a, false) end Wait(60) end
        Call('wagonFled', id)
        if Wagon.cur and Wagon.cur.veh == veh then Wagon.forget(true) elseif DoesEntityExist(veh) then DeleteEntity(veh) end
    end, false)
end

if Config.Commands.fixWagon then
    RegisterCommand(Config.Commands.fixWagon, function()
        local veh = nearestVehicle(5.0)
        if not veh then return Tip(L('noWagonNear')) end
        local id = myWagon(veh)
        if not id then
            SetVehicleFixed(veh)
            return
        end
        local row = Me.wagons[id]
        local net = NetIdOf(veh)
        if not row or not net then return end
        local p, h = GetEntityCoords(veh), GetEntityHeading(veh)
        if not Call('deleteEntity', net, 'repair') then return end
        if Wagon.cur and Wagon.cur.id == id then Wagon.forget(false) end
        Wait(300)
        local fresh = Look.spawnWagon(row, vector4(p.x, p.y, p.z, h), true, true)
        if fresh then Wagon.adopt(row, fresh) end
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.fixWagon, L('fixWagonHelp'))
end

------------------------------------------------------------------------------
-- keys: J (call), U (wagon menu) and the local flag that tells pup-misc U is ours
------------------------------------------------------------------------------
local function stableWagonNear(radius)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD = nil, radius
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if Entity(v).state.pup_stable_wagonID then
            local d = #(GetEntityCoords(v) - me)
            if d <= bestD then best, bestD = v, d end
        end
    end
    return best
end
Wagon.stableWagonNear = stableWagonNear

local function canOpenLocker(veh)
    if Config.Locker.access == 2 then return true end
    if Config.Locker.access == 1 then return myWagon(veh) ~= nil end
    return false
end

function Wagon.openLocker(veh)
    local net = NetIdOf(veh)
    if net then CallTip('openLocker', net) end
end

local function wagonMenu(veh)
    local name = Entity(veh).state.pup_stable_wagonName or L('wagon')
    local items = { { id = 'st', title = 'openStorage', icon = 'bag', actions = { { act = 'storage', label = 'select', key = 'Enter' } } } }
    if Running('pup-misc') and LocalPlayer.state.pupOutfitterEnabled then
        items[#items + 1] = { id = 'of', title = 'outfitter', icon = 'saddle', desc = L('outfitterDesc'), actions = { { act = 'outfit', label = 'select', key = 'Enter' } } }
    end
    Ui.menus = {}
    Ui.menu({ id = 'wmenu', title = name, raw = true, items = items })
    Ui.header('wagon')
    Ui.root('wmenu')
    Ui.show({
        onAction = function(_, it, a)
            Ui.hide(true)
            if a == 'storage' and it.id == 'st' then Wagon.openLocker(veh)
            elseif a == 'outfit' and it.id == 'of' then TriggerEvent('pup-misc:outfitter:kit') end
        end,
    })
end

local menuWagon = nil

CreateThread(function()
    local flagged = false
    while true do
        local me = PlayerPedId()
        local onFoot = not IsPedOnMount(me) and not N.leading(me) and not IsPedInAnyVehicle(me, false)
        local veh = onFoot and stableWagonNear(W.promptDistance) or nil
        local want = veh ~= nil and canOpenLocker(veh)
        menuWagon = want and veh or nil
        if want ~= flagged then
            flagged = want
            LocalPlayer.state:set('pupWagonMenu', want, false)
        end
        Wait(400)
    end
end)

Keys.on(Config.Keys.callWagon, function() Wagon.call() end)
Keys.on(Config.Keys.menu, function()
    local veh = menuWagon
    if veh and DoesEntityExist(veh) and not IsPedOnMount(PlayerPedId()) then wagonMenu(veh) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    N.blipRemove(Wagon.blip)
    LocalPlayer.state:set('pupWagonMenu', false, false)
end)
