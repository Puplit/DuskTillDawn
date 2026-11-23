-- pup_mercantile | standing at a counter: NPC stores, shop visits and the vorp_inventory grid
-- The server decides everything; this file only freezes the player, opens what
-- the server allows and tidies up afterwards.

local OPEN_TIMEOUT <const> = 6000 -- ms to wait for the server to answer an open request

local function freeze(on)
    local ped = PlayerPedId()
    if on then
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, true)
    else
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
    end
    TriggerEvent('inv:dropstatus', not on)
end

-- forget the counter; tell the server unless it already ended the visit
function LeaveEverything(silent)
    local wasShop = St.venue and St.venue.kind ~= 'npc'
    St.adminView = nil
    if Dash and Dash.open then CloseDashboard() end
    if St.gridOpen then
        St.gridOpen = false
        St.returnToDash = false
        TriggerEvent('vorp_inventory:CloseInv')
    end
    if St.moveMode then StopMoveMode() end
    if St.inStore or St.venue then freeze(false) end
    St.inStore = false
    St.venue = nil
    St.returnToDash = false
    St.waiting = nil
    if wasShop and not silent then TriggerServerEvent('pup_mercantile:visit:end') end
end

-- give up if the server never answers (lost event, server restart)
local function watchOpen(token)
    SetTimeout(OPEN_TIMEOUT, function()
        if St.waiting == token and not St.gridOpen and not (Dash and Dash.open) then
            LeaveEverything(false)
        end
    end)
end

local function begin(venue)
    St.inStore = true
    St.venue = venue
    St.waiting = GetGameTimer()
    freeze(true)
    watchOpen(St.waiting)
end

------------------------------------------------------------------------------
-- NPC stores
------------------------------------------------------------------------------
function OpenNpcStore(idx)
    if St.inStore or St.moveMode then return end
    begin({ kind = 'npc', id = idx })
    TriggerServerEvent('pup_mercantile:npc:open', idx)
end

------------------------------------------------------------------------------
-- player and society shops
------------------------------------------------------------------------------
function EnterShop(kind, id, pressedManage)
    if St.inStore or St.moveMode then return end
    begin({ kind = kind, id = id, pressedManage = pressedManage == true })
    TriggerServerEvent('pup_mercantile:visit:begin', kind, id)
end

RegisterNetEvent('pup_mercantile:visit:started', function(kind, id, canManage)
    local v = St.venue
    if not v or v.kind ~= kind or v.id ~= id then return end
    St.waiting = nil
    if canManage and v.pressedManage then
        OpenDashboard(kind, id, 'overview')
    else
        St.waiting = GetGameTimer()
        watchOpen(St.waiting)
        TriggerServerEvent('pup_mercantile:grid:open', kind, id)
    end
end)

RegisterNetEvent('pup_mercantile:visit:refused', function()
    if St.inStore then LeaveEverything(true) end
end)

-- the server ended the visit (walked away, shop closed, lost the right to manage it)
RegisterNetEvent('pup_mercantile:visit:ended', function()
    if St.adminView and not St.inStore then
        St.adminView = nil
        if St.gridOpen then
            St.gridOpen = false
            TriggerEvent('vorp_inventory:CloseInv')
        end
        return
    end
    if St.inStore or St.moveMode or St.venue then LeaveEverything(true) end
end)

-- staff opened a shop grid from vorp_admin: no counter, no freeze, nothing to tidy but the grid
RegisterNetEvent('pup_mercantile:admin:viewing', function(kind, id)
    if St.inStore or St.moveMode then return end
    local view = { kind = kind, id = id }
    St.adminView = view
    -- the grid never opened (inventory busy): forget it so the counters work again
    SetTimeout(OPEN_TIMEOUT, function()
        if St.adminView == view and not St.gridOpen then
            St.adminView = nil
            TriggerServerEvent('pup_mercantile:grid:closed')
        end
    end)
end)

-- the owner opens the shelves from the dashboard; closing them returns to the dashboard
function OpenOwnerGrid()
    local v = St.venue
    if not v or v.kind == 'npc' then return end
    St.returnToDash = true
    St.waiting = GetGameTimer()
    watchOpen(St.waiting)
    TriggerServerEvent('pup_mercantile:grid:open', v.kind, v.id)
end

------------------------------------------------------------------------------
-- vorp_inventory's store window
------------------------------------------------------------------------------
AddEventHandler('pup_mercantile:setClosedInv', function(open)
    if open and St.inStore then
        St.gridOpen = true
        St.waiting = nil
    elseif open and St.adminView then
        St.gridOpen = true
    end
end)

-- fired by vorp_inventory whenever any of its windows closes
AddEventHandler('pup:closeinv', function()
    if not St.gridOpen then return end
    St.gridOpen = false
    TriggerServerEvent('pup_mercantile:grid:closed')
    if St.adminView and not St.inStore then
        St.adminView = nil
        return
    end
    local v = St.venue
    if St.returnToDash and v and v.kind ~= 'npc' then
        St.returnToDash = false
        OpenDashboard(v.kind, v.id, 'stock')
        return
    end
    LeaveEverything(false)
end)

-- opens an NPC store through the normal flow; the server fires it after its checks
RegisterNetEvent('pup_mercantile:openStore', function(idx)
    idx = tonumber(idx)
    if idx and NpcStoreList[idx] then OpenNpcStore(idx) end
end)
