-- skinanimals | server/main.lua
-- Checks every skinning claim and pays it from the server's own copy of the animal table.

local Paid = {}        -- [netId] = os.time() when paid
local LastSkin = {}    -- [src] = GetGameTimer() of the last accepted skin
local Unseen = {}      -- [src] = { normal = { times }, legendary = { times } }
local Flood = {}       -- [src] = { start = os.time(), count = n }
local Busy = {}        -- [src] = true while a claim is being paid

local function dbg(fmt, ...)
    if not Config.Debug then return end
    print(('^5[skinanimals]^7 ' .. fmt):format(...))
end

local function notify(src, text, duration, kind)
    TriggerClientEvent('skinanimals:notify', src, text, duration, Locale.title, kind)
end

local function refuse(src, reason)
    local text = Locale.busy
    if reason == 'already' then
        text = Locale.alreadyDone
    elseif Config.Messages.distinctRefusals then
        text = Locale[reason] or Locale.busy
    end
    notify(src, text, Config.Messages.refusalMs, 'error')
end

local function toNetId(v)
    local n = tonumber(v)
    if not n then return nil end
    n = math.tointeger(n)
    -- 0 is "not networked": it can never be marked paid, so it is not a claimable id
    if not n or n <= 0 or n > 0x7FFFFFFF then return nil end
    return n
end

-- The entity for a network id when the server can see it, else nil.
local function visibleEntity(netId)
    if netId == 0 then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return nil
end

local function markPaid(netId, ent)
    if netId == 0 then return end
    Paid[netId] = os.time()
    ent = ent or visibleEntity(netId)
    if ent then Entity(ent).state:set('skinned', true, true) end
end

local function isPaid(netId)
    if not netId or netId == 0 then return false end
    if Paid[netId] then return true end
    local ent = visibleEntity(netId)
    return ent ~= nil and Entity(ent).state.skinned == true
end

-- Times in list that are still inside the window.
local function prune(list, window, now)
    local keep = {}
    for _, t in ipairs(list) do
        if now - t < window then keep[#keep + 1] = t end
    end
    return keep
end

-- Rolling-window counter; returns true when one more is allowed (and records it).
local function takeSlot(list, max, window, now)
    local keep = prune(list, window, now)
    if #keep >= max then return false, keep end
    keep[#keep + 1] = now
    return true, keep
end

local function flooded(src)
    local now = os.time()
    local f = Flood[src]
    if not f or now - f.start >= Config.Rules.floodWindowSec then
        Flood[src] = { start = now, count = 1 }
        return false
    end
    f.count = f.count + 1
    return f.count > Config.Rules.floodMax
end

-- Debug only: read-only check that an item row exists in the items table.
local function debugItemRow(name)
    if not Config.Debug or GetResourceState('oxmysql') ~= 'started' then return end
    local ok, err = pcall(MySQL.scalar, 'SELECT 1 FROM `items` WHERE `item` = ? LIMIT 1', { name }, function(found)
        dbg('items table has %s: %s', name, found and 'yes' or 'NO')
    end)
    if not ok then dbg('items table lookup for %s failed: %s', name, tostring(err)) end
end

local function playerConnected(src)
    return GetPlayerName(src) ~= nil
end

------------------------------------------------------------------------------- checks
local function stillAlive(ent)
    if not Config.Rules.requireDeadCarcass then return false end
    local ok, hp = pcall(GetEntityHealth, ent)
    return ok and type(hp) == 'number' and hp > 0
end

-- Returns the carcass entity (or nil) on acceptance, or false plus a reason.
local function check(src, rowIndex, netId, legendary)
    local R = Config.Rules
    local ref = SkinUtil.rows[rowIndex]
    if not ref then return false, 'wrongAnimal' end

    if isPaid(netId) then return false, 'already' end

    local now = GetGameTimer()
    if LastSkin[src] and now - LastSkin[src] < R.cooldownSec * 1000 then return false, 'busy' end

    local ent = visibleEntity(netId)
    if ent then
        local model = SkinUtil.u32(GetEntityModel(ent))
        if model == nil or model ~= ref.model then return false, 'wrongAnimal' end
        -- a living animal is not a carcass (stops claiming every animal of a herd in reach)
        if stillAlive(ent) then return false, 'notDead' end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return false, 'tooFar' end
        if #(GetEntityCoords(ped) - GetEntityCoords(ent)) > R.reach then return false, 'tooFar' end
    elseif legendary or not R.allowUnseen then
        -- a Legendary row is only paid for a carcass the server can see
        return false, 'notAllowed'
    end

    -- The server cannot read outfits, so Legendary claims are limited even when the carcass is seen.
    local t = os.time()
    local u = Unseen[src] or { normal = {}, legendary = {} }
    Unseen[src] = u
    local ok = true
    if legendary and (not ent or R.limitLegendarySeen) then
        ok, u.legendary = takeSlot(u.legendary, R.unseenLegendaryMax, R.unseenLegendaryWindowSec, t)
    elseif not ent and not legendary then
        ok, u.normal = takeSlot(u.normal, R.unseenMax, R.unseenWindowSec, t)
    end
    if not ok then return false, 'tooMany' end
    return ent
end

------------------------------------------------------------------------------- payout
local function payout(src, charId, row, legendary)
    local items = SkinUtil.rowItems(row)
    if #items == 0 then
        notify(src, Locale.noItems, Config.Messages.resultMs, 'error')
        dbg('src=%d row "%s" lists no items', src, tostring(row.name))
        return false
    end

    local perkKey = legendary and 'skin_legendary_double' or 'skin_double'
    if Config.Debug then
        dbg('src=%d perk %s active=%s', src, perkKey, tostring(Ext.perkHas(src, perkKey)))
    end
    local doubled = Ext.perkRoll(src, perkKey)
    dbg('src=%d perk %s roll=%s', src, perkKey, doubled and 'hit' or 'miss')
    local qty = doubled and 2 or 1

    local given, refused = {}, {}
    for _, it in ipairs(items) do
        -- stop if the player left or switched character while items were being given
        local char = Ext.character(src)
        if not playerConnected(src) or not char or char.charIdentifier ~= charId then
            dbg('src=%d character changed or left - payout stopped', src)
            return false
        end

        debugItemRow(it.name)
        local canCarry = Ext.canCarry(src, it.name, qty)
        local added = canCarry and Ext.addItem(src, it.name, qty)
        if added then
            given[#given + 1] = { name = it.name, label = it.label, qty = qty }
            dbg('src=%d granted %dx %s', src, qty, it.name)
        else
            local exists = Ext.itemExists(it.name)
            refused[#refused + 1] = exists and Locale.noRoom:format(it.label) or Locale.unknownItem:format(it.name)
            dbg('src=%d refused %s: %s', src, it.name,
                not exists and 'not in the item database'
                or not canCarry and 'canCarryItem said no (weight or item limit)'
                or 'addItem returned false')
        end
    end

    if not playerConnected(src) then return #given > 0 end

    if #given > 0 then
        local labels = {}
        for i, g in ipairs(given) do labels[i] = g.label end
        local text = Locale.gotPrefix .. table.concat(labels, Locale.listJoin)
        if doubled then text = text .. Locale.doubled end
        if #refused > 0 then text = text .. Locale.refusalJoin .. table.concat(refused, Locale.listJoin) end
        notify(src, text, Config.Messages.resultMs, 'success')

        Ext.perkAward(src, legendary and 'skin_legendary' or 'skin')
        local char = Ext.character(src)
        if char and char.charIdentifier == charId then SkinLog.post(src, char, row, given) end
        return true
    end

    local text = #refused > 0 and table.concat(refused, Locale.listJoin) or Locale.nothing
    notify(src, text, Config.Messages.resultMs, 'error')
    return false
end

------------------------------------------------------------------------------- claim event
RegisterNetEvent('skinanimals:claim', function(rowIndex, rawNetId)
    local src = tonumber(source)
    if not src or src <= 0 then return end
    if flooded(src) then dbg('src=%d claim dropped (flood)', src) return end

    rowIndex = math.tointeger(tonumber(rowIndex) or -1)
    local row = rowIndex and SkinUtil.list[rowIndex]
    local netId = toNetId(rawNetId)
    if row and tonumber(rawNetId) == 0 then
        -- a carcass that is not networked: nothing the server can check or mark as paid
        refuse(src, 'notAllowed')
        dbg('src=%d refused row %d "%s": carcass not networked', src, rowIndex, tostring(row.name))
        TriggerClientEvent('skinanimals:claimDone', src, 0)
        return
    end
    if not row or not netId then
        dbg('src=%d claim dropped (unknown row %s / net id %s)', src, tostring(rowIndex), tostring(rawNetId))
        return
    end

    local char = Ext.character(src)
    if not char then dbg('src=%d claim dropped (no active character)', src) return end
    local charId = char.charIdentifier

    if Busy[src] then
        refuse(src, 'busy')
        dbg('src=%d refused: previous claim still being paid', src)
        TriggerClientEvent('skinanimals:claimDone', src, netId)
        return
    end

    local legendary = SkinUtil.rowIsLegendary(row)
    local ent, reason = check(src, rowIndex, netId, legendary)
    if ent == false then
        refuse(src, reason)
        dbg('src=%d refused row %d "%s" net %d: %s', src, rowIndex, tostring(row.name), netId, reason)
        TriggerClientEvent('skinanimals:claimDone', src, netId)
        return
    end

    -- accepted
    LastSkin[src] = GetGameTimer()
    markPaid(netId, ent)
    dbg('src=%d accepted row %d "%s" net %d (%s)', src, rowIndex, tostring(row.name), netId, ent and 'seen' or 'unseen')
    TriggerClientEvent('skinanimals:claimDone', src, netId)

    if not Config.Integrations.bondOnlyWhenItemGiven then Ext.horseBond(src) end

    Busy[src] = true
    local ok, anyGiven = pcall(payout, src, charId, row, legendary)
    Busy[src] = nil
    if not ok then
        print('^1[skinanimals]^7 payout failed: ' .. tostring(anyGiven))
        return
    end
    if anyGiven and Config.Integrations.bondOnlyWhenItemGiven and playerConnected(src) then Ext.horseBond(src) end
end)

------------------------------------------------------------------------------- exports
exports('IsCarcassSkinned', function(netId)
    local n = toNetId(netId)
    if not n or n == 0 then return false end
    return isPaid(n)
end)

exports('MarkCarcassSkinned', function(netId)
    local n = toNetId(netId)
    if not n or n == 0 then return end
    markPaid(n, nil)
end)

------------------------------------------------------------------------------- housekeeping
CreateThread(function()
    while true do
        Wait(Config.Rules.paidSweepSec * 1000)
        local now = os.time()
        for id, t in pairs(Paid) do
            if now - t > Config.Rules.paidLifetimeSec then Paid[id] = nil end
        end
        for src, u in pairs(Unseen) do
            local n = prune(u.normal, Config.Rules.unseenWindowSec, now)
            local l = prune(u.legendary, Config.Rules.unseenLegendaryWindowSec, now)
            if #n == 0 and #l == 0 then Unseen[src] = nil else u.normal, u.legendary = n, l end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if not src then return end
    LastSkin[src], Unseen[src], Flood[src], Busy[src] = nil, nil, nil, nil
end)

-- vorp_admin world cleanup: the deleted carcasses' network ids get handed out again, so a
-- paid mark on one that is gone would refuse the next animal that inherits the id
AddEventHandler('vorp_admin:worldCleanupDone', function()
    for id in pairs(Paid) do
        if not visibleEntity(id) then Paid[id] = nil end
    end
end)
