-- pup_hideouts | going in and out, the look of the shack, its doors, the prompts inside

local N <const> = {
    activateSet   = 0x174D0AAB11CED739, -- _ACTIVATE_INTERIOR_ENTITY_SET
    deactivateSet = 0x33B81A2C07A51FFF, -- _DEACTIVATE_INTERIOR_ENTITY_SET
    isSetActive   = 0x32810CA2125F5842, -- _IS_INTERIOR_ENTITY_SET_ACTIVE
    refresh       = 0x41F37C3427C75AE0, -- REFRESH_INTERIOR
    addDoor       = 0xD99229FE93B46286, -- _ADD_DOOR_TO_SYSTEM_NEW
    doorRegistered = 0xC153C43EA202C8C1, -- IS_DOOR_REGISTERED_WITH_SYSTEM
    doorState     = 0x6BAB9442830C7F53, -- DOOR_SYSTEM_SET_DOOR_STATE
    doorRatio     = 0xB6E6FBA95C7324AC, -- DOOR_SYSTEM_SET_OPEN_RATIO
}

local lastDoor = {}  -- [id] = door coords (kept if the row vanishes while we are inside)
HX.stashOpenId = nil

----------------------------------------------------------------------------------------------------
-- the look: theme and decoration entity sets
----------------------------------------------------------------------------------------------------
local applied = {}  -- [set] = true, what we switched on
local lookInterior = nil

local function setActive(interior, set)
    return Citizen.InvokeNative(N.isSetActive, interior, set) == 1 or Citizen.InvokeNative(N.isSetActive, interior, set) == true
end

function HX.applyLook(r)
    if not r then return end
    local zone = U.zone(r.zone)
    local interior = zone.interior
    local want = {}
    if r.theme then want[r.theme] = true end
    for _, set in pairs(r.upgrades or {}) do
        if type(set) == 'string' then want[set] = true end
    end
    local changed = false
    for _, t in ipairs(Config.Themes) do
        if not want[t.set] and setActive(interior, t.set) then
            Citizen.InvokeNative(N.deactivateSet, interior, t.set, true)
            changed = true
        end
    end
    for set in pairs(applied) do
        if not want[set] and setActive(interior, set) then
            Citizen.InvokeNative(N.deactivateSet, interior, set, true)
            changed = true
        end
    end
    for set in pairs(want) do
        if not setActive(interior, set) then
            Citizen.InvokeNative(N.activateSet, interior, set, 0)
            changed = true
        end
    end
    applied = want
    lookInterior = interior
    if changed then Citizen.InvokeNative(N.refresh, interior) end
end

function HX.clearLook()
    if not lookInterior then return end
    local changed = false
    for set in pairs(applied) do
        if setActive(lookInterior, set) then
            Citizen.InvokeNative(N.deactivateSet, lookInterior, set, true)
            changed = true
        end
    end
    if changed then Citizen.InvokeNative(N.refresh, lookInterior) end
    applied, lookInterior = {}, nil
end

----------------------------------------------------------------------------------------------------
-- doors inside
----------------------------------------------------------------------------------------------------
local registered = {}

local function ensureDoor(hash)
    if registered[hash] then return end
    if Citizen.InvokeNative(N.doorRegistered, hash) ~= 1 then
        Citizen.InvokeNative(N.addDoor, hash, true, true, false, 0, 0, false)
    end
    registered[hash] = true
end

local function holdDoors(r)
    local zone = U.zone(r.zone)
    for _, d in ipairs(zone.lockedDoors) do
        ensureDoor(d.hash)
        Citizen.InvokeNative(N.doorState, d.hash, 1)
        Citizen.InvokeNative(N.doorRatio, d.hash, 0.0, true)
    end
    for _, d in ipairs(zone.themeDoors) do
        ensureDoor(d.hash)
        if r.theme then
            Citizen.InvokeNative(N.doorState, d.hash, 0)
        else
            Citizen.InvokeNative(N.doorState, d.hash, 1)
            Citizen.InvokeNative(N.doorRatio, d.hash, 0.0, true)
        end
    end
end

----------------------------------------------------------------------------------------------------
-- in and out
----------------------------------------------------------------------------------------------------
local entering = false

function HX.enter(id)
    if entering or HX.insideId then return end
    entering = true
    local ok, fresh = HX.call('row', 2000, id)
    if ok and type(fresh) == 'table' and fresh.id then HX.rows[fresh.id] = fresh end
    local r = HX.rows[id]
    if not r then entering = false return end
    local bucket = id + Config.InstanceOffset
    local answered, got = HX.call('setBucket', 4000, bucket)
    if not answered or got ~= bucket then
        HX.bottom(L('cant_go_in'))
        entering = false
        return
    end
    local pos = HX.pos()
    TriggerServerEvent('pup_hideouts:sendlastcoords', HX.charId, { x = pos.x, y = pos.y, z = pos.z })
    -- pup-misc's handler stores the argument as "scenes allowed": false blocks /scene while inside,
    -- every way out sends true again
    TriggerEvent('pup-scene:stopscene', false)
    -- lets a stable resource put the horse away (a no-op when nothing listens)
    TriggerEvent('pup-stable:deletehorse')
    lastDoor[id] = r.coords
    HX.insideId = id
    HX.send('entered', id)
    HX.applyLook(r)
    local zone = U.zone(r.zone)
    HX.fade(true)
    HX.teleport(zone.inside, zone.insideHeading)
    HX.fade(false)
    entering = false
    TriggerEvent('pup_hideouts:enteredHideout', id)
end

-- safe to call any time; does nothing when not inside
function HX.leave(doorCoords)
    local id = HX.insideId
    if not id or HX.leaving then return end
    HX.leaving = true
    HX.menuClose()
    if HX.stashOpenId then
        TriggerEvent('vorp_inventory:CloseInv')
        HX.send('stashClosed')
        HX.stashOpenId = nil
    end
    HX.clearLook()
    TriggerEvent('pup-scene:stopscene', true)
    TriggerEvent('pup_hideouts:leavingHideout', id)
    HX.send('left', id)
    HX.insideId = nil
    local r = HX.rows[id]
    local door = U.vec(doorCoords) or U.vec(r and r.coords) or U.vec(lastDoor[id])
    CreateThread(function()
        -- a refused or rate-limited answer would leave us at the door but still in the instance
        for _ = 1, 3 do
            local ok, got = HX.call('setBucket', 4000, 0)
            if ok and got == 0 then break end
            Wait(700)
        end
        HX.fade(true)
        if door then HX.teleport(door) end
        HX.fade(false)
        HX.leaving = false
    end)
end

RegisterNetEvent('pup_hideouts:forceLeave', function(id, coords)
    if HX.insideId == id then HX.leave(coords) end
end)

RegisterNetEvent('pup_hideouts:invited', function(id)
    CreateThread(function() HX.enter(id) end)
end)

RegisterNetEvent('pup_hideouts:accessLost', function(id)
    if HX.insideId == id then
        HX.menuClose()
        if HX.stashOpenId == id then
            TriggerEvent('vorp_inventory:CloseInv')
            HX.send('stashClosed')
            HX.stashOpenId = nil
        end
    end
end)

-- the server opened a stash for us from the vorp_admin panel (AdminOpenStash): remember it so
-- the close is reported back (stashClosed) like an ordinary one
RegisterNetEvent('pup_hideouts:staffStash', function(id)
    HX.stashOpenId = tonumber(id)
end)

AddEventHandler('pup:closeinv', function()
    if HX.stashOpenId then
        HX.stashOpenId = nil
        HX.send('stashClosed')
    end
end)

----------------------------------------------------------------------------------------------------
-- the stash panel
----------------------------------------------------------------------------------------------------
local stashOpening = false
function HX.openStash(id)
    -- the prompt stays on screen while we wait: one request at a time
    if stashOpening or HX.stashOpenId then return end
    stashOpening = true
    local ok, busy = HX.call('stashBusy', 5000, id)
    if not ok then stashOpening = false return HX.tip(L('no_answer')) end
    if busy then stashOpening = false return HX.tip(L('menu_in_use')) end
    local answered, opened, slots = HX.call('stashOpen', 5000, id)
    stashOpening = false
    if not answered then return HX.tip(L('no_answer')) end
    if not opened or HX.insideId ~= id then return end
    HX.stashOpenId = id
    TriggerEvent('vorp_inventory:OpenHideoutInventory', L('stash_limit', tonumber(slots) or 0), id, tonumber(slots) or 0)
end

----------------------------------------------------------------------------------------------------
-- every frame inside
----------------------------------------------------------------------------------------------------
local function near(a, b, d) return U.dist(a, b) <= d end

-- doors and floating text: always, even with a menu open
function HX.insideMaintain()
    local r = HX.rows[HX.insideId]
    if not r then return end
    holdDoors(r)
    local zone = U.zone(r.zone)
    local pos = HX.pos()
    if r.mashinfo and near(pos, zone.mashSpot.coords, 2.0) then
        HX.text3d(zone.mashSpot.coords, L('mash_timer', HX.secsLeft(r, 'mash')))
    end
    if r.stillinfo and near(pos, zone.stillSpot.coords, 2.0) then
        HX.text3d(zone.stillSpot.coords, L('distill_timer', HX.secsLeft(r, 'distill')))
    end
    if (r.member or r.isCrew) and near(pos, zone.seat.coords, 2.0) then
        HX.text3d(zone.ledgerText, L('ledger_amount', U.money(r.ledger or 0)))
    end
    if HX.Bookie then HX.Bookie.drawLabels() end
end

-- seconds left on a batch, counted locally from the server's last number
local stamp = {}
function HX.secsLeft(r, kind)
    local key = r.id .. kind
    local base = kind == 'mash' and r.mashLeft or r.distillLeft
    local s = stamp[key]
    if not s or s.base ~= base then s = { base = base, at = GetGameTimer() }; stamp[key] = s end
    return math.max(0, math.floor(base - (GetGameTimer() - s.at) / 1000))
end

-- one prompt group, highest priority first
function HX.insidePrompts()
    local id = HX.insideId
    local r = HX.rows[id]
    if not r then return end
    local zone = U.zone(r.zone)
    local pos = HX.pos()

    if near(pos, zone.inside, 2.0) then
        if HX.prompt(L('title_hideout'), L('exit_hideout')) then HX.leave() end
        return
    end
    if near(pos, zone.seat.coords, 2.0) then
        if r.member then
            if HX.prompt(L('title_management'), L('open_books')) then CreateThread(function() HX.openBooks(id) end) end
            return
        elseif r.isCrew then
            if HX.prompt(L('title_ledger'), L('take_cash')) then
                CreateThread(function() HX.busy = true; HX.call('takeLedger', 5000, id); HX.busy = false end)
            end
            return
        end
    end
    if (r.invlevel or 0) ~= 0 and (r.member or r.isCrew) and near(pos, zone.stash, 2.0) then
        if HX.prompt(L('title_inventory'), L('open_inventory')) then CreateThread(function() HX.openStash(id) end) end
        return
    end
    if r.bookie and near(pos, zone.bookie, 2.0) then
        if HX.prompt(L('title_bookie'), L('open_bookie')) then CreateThread(function() HX.Bookie.openMenu(id) end) end
        return
    end
    if not HX.Bar.poured() and near(pos, zone.bar.coords, 2.0) then
        local p = HX.prompt(L('title_bar'), L('pour_moonshine'), L('eat_almonds'))
        if p == 'primary' then CreateThread(HX.Bar.pour) elseif p == 'secondary' then CreateThread(HX.Bar.almonds) end
        return
    end
    if near(pos, zone.wash, 1.0) then
        if HX.prompt(L('title_barrel'), L('wash_face')) then CreateThread(HX.Bar.wash) end
        return
    end
    if HX.Bar.poured() then
        if HX.prompt(L('title_moonshine'), L('drink_moonshine')) then CreateThread(HX.Bar.drink) end
        return
    end
    if HX.Teardown and HX.Teardown.prompt(r, zone, pos) then return end
    if r.member and r.still and (r.still.stilllevel or 0) > 0 and near(pos, zone.still, 1.5) then
        if HX.prompt(L('title_still'), L('brew_moonshine')) then CreateThread(function() HX.openProduction(id) end) end
        return
    end
end

----------------------------------------------------------------------------------------------------
-- death closes menus and the stash
----------------------------------------------------------------------------------------------------
CreateThread(function()
    local wasDead = false
    while true do
        Wait(500)
        local dead = HX.dead()
        if dead and not wasDead then
            HX.menuClose()
            if HX.stashOpenId then
                TriggerEvent('vorp_inventory:CloseInv')
                HX.send('stashClosed')
                HX.stashOpenId = nil
            end
        end
        wasDead = dead
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    HX.clearLook()
    if HX.insideId then
        DoScreenFadeIn(0)
        TriggerEvent('pup-scene:stopscene', true) -- give /scene back
    end
end)
