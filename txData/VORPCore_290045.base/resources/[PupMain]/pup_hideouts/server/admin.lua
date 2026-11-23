-- pup_hideouts | vorp_admin bridge, hideout counts, debug commands
-- vorp_admin owns its own permissions; these exports trust their caller.

local function names(charids)
    local out = {}
    if #charids == 0 then return out end
    local marks = {}
    for i = 1, #charids do marks[i] = '?' end
    local rows = MySQL.query.await(
        ('SELECT `charidentifier`, `firstname`, `lastname` FROM `characters` WHERE `charidentifier` IN (%s)'):format(table.concat(marks, ',')),
        charids) or {}
    for _, r in ipairs(rows) do
        out[tonumber(r.charidentifier)] = U.trim(('%s %s'):format(r.firstname or '', r.lastname or ''))
    end
    return out
end

exports('AdminList', function()
    local list, wanted, seen = {}, {}, {}
    for _, h in pairs(HX.hideouts) do
        if h.charidentifier and not seen[h.charidentifier] then seen[h.charidentifier] = true; wanted[#wanted + 1] = h.charidentifier end
    end
    local nm = names(wanted)
    local ids = {}
    for id in pairs(HX.hideouts) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local h = HX.hideouts[id]
        if h then
            local inside = {}
            for _, s in ipairs(HX.insideSources(h)) do
                inside[#inside + 1] = { src = s, charid = HX.charId(s), name = HX.nameOf(s) }
            end
            local items, stashTotal = {}, 0
            for _, it in ipairs(h.items) do
                items[#items + 1] = { name = it.name, label = it.label, count = it.count, meta = not U.isEmpty(it.metadata) }
                stashTotal = stashTotal + it.count
            end
            local coowners = {}
            for _, co in ipairs(h.coowners) do coowners[#coowners + 1] = { charid = co.charid, name = co.name } end
            local owner = nil
            if h.owned and h.charidentifier then
                owner = { charid = h.charidentifier, name = nm[h.charidentifier] or 'Unknown' }
            end
            list[#list + 1] = {
                id = h.id, name = h.name, zone = h.zone, theme = h.theme, price = h.price, owned = h.owned == true,
                coords = h.coords, owner = owner, coowners = coowners, inside = inside, ledger = h.ledger,
                items = items, stashTotal = stashTotal, invslots = h.invslots, invlevel = h.invlevel,
                upgrades = h.upgrades, bookie = h.bookie == true, haswebhook = h.webhook ~= nil,
                stilllevel = HX.stillLevel(h), raidOpen = h.justraided, raidOpenedAt = h.raidopenedat,
                raidCooldown = h.raidcooldown, raidDay = h.raidday,
                missionCooldown = HX.Wagons.cooldownEnd(h.id),
                mash = h.mashinfo and { label = h.mashinfo.label, qt = h.mashinfo.qt, endsAt = h.lasttimer } or nil,
                still = h.stillinfo and { label = h.stillinfo.label, qt = h.stillinfo.qt, endsAt = h.lasttimer2 } or nil,
            }
        end
    end
    return { list = list, now = os.time(), raidDays = Config.Raids.protectionDays, raidWindow = Config.Raids.openMinutes }
end)

local function charRow(charid)
    return MySQL.single.await('SELECT `charidentifier`, `identifier`, `firstname`, `lastname` FROM `characters` WHERE `charidentifier` = ?', { charid })
end

local ACTIONS = {}

ACTIONS.setledger = function(h, data)
    local v = tonumber(data.value)
    if not v or v < 0 or v ~= v then return false, 'invalid value' end
    h.ledger = U.round2(v)
    HX.save(h, { 'ledger' })
    HX.changed(h)
    return true, ('ledger of #%d set to $%s'):format(h.id, U.money(h.ledger))
end

ACTIONS.wipeledger = function(h)
    h.ledger = 0
    HX.save(h, { 'ledger' })
    HX.changed(h)
    return true, ('ledger of #%d wiped'):format(h.id)
end

ACTIONS.removeitem = function(h, data)
    local amount = U.posInt(data.amount)
    if type(data.name) ~= 'string' or not amount then return false, 'invalid item or amount' end
    local have = HX.stashCount(h, data.name)
    if have <= 0 then return false, 'item not in stash' end
    amount = math.min(amount, have)
    HX.stashRemove(h, data.name, amount)
    HX.save(h, { 'items' })
    HX.reloadStashInside(h)
    HX.changed(h)
    return true, ('removed %d x %s from #%d'):format(amount, data.name, h.id)
end

ACTIONS.movehere = function(h, data)
    local c = U.plain(data.coords)
    if not c or U.isOrigin(c) then return false, 'invalid coords' end
    h.coords = c
    HX.save(h, { 'coords' })
    HX.changed(h, true)
    return true, ('#%d moved'):format(h.id)
end

ACTIONS.wipestash = function(h)
    h.items = {}
    HX.save(h, { 'items' })
    HX.reloadStashInside(h)
    HX.changed(h)
    return true, ('stash of #%d wiped'):format(h.id)
end

ACTIONS.setowner = function(h, data)
    local cid = U.posInt(data.charid)
    if not cid then return false, 'invalid character id' end
    local row = charRow(cid)
    if not row then return false, 'no such character' end
    h = HX.hideouts[h.id]
    if not h then return false, 'hideout not found' end
    local previous = h.owned and h.charidentifier or nil
    if HX.Reloc.pending[h.id] then HX.Reloc.refund(h.id, 'relocate_called_off') end
    h.owned = true
    h.charidentifier = cid
    h.identifier = row.identifier
    local keep = {}
    for _, co in ipairs(h.coowners) do if tonumber(co.charid) ~= cid then keep[#keep + 1] = co end end
    h.coowners = keep
    HX.save(h, { 'owned', 'charidentifier', 'identifier', 'coowners' })
    HX.changed(h, true)
    if previous and previous ~= cid then HX.lostAccess(h, previous) end
    return true, ('#%d now belongs to %s %s (%d)'):format(h.id, row.firstname or '', row.lastname or '', cid)
end

ACTIONS.addcoowner = function(h, data)
    local cid = U.posInt(data.charid)
    if not cid then return false, 'invalid character id' end
    if HX.isMember(h, cid) then return false, 'already has access' end
    local row = charRow(cid)
    if not row then return false, 'no such character' end
    h = HX.hideouts[h.id]
    if not h then return false, 'hideout not found' end
    if HX.isMember(h, cid) then return false, 'already has access' end
    local name = U.trim(('%s %s'):format(row.firstname or '', row.lastname or ''))
    h.coowners[#h.coowners + 1] = { charid = cid, name = name }
    HX.save(h, { 'coowners' })
    HX.changed(h, true)
    return true, ('%s (%d) added to #%d'):format(name, cid, h.id)
end

ACTIONS.removecoowner = function(h, data)
    local cid = tonumber(data.charid)
    if not cid then return false, 'invalid character id' end
    local keep = {}
    for _, co in ipairs(h.coowners) do if tonumber(co.charid) ~= cid then keep[#keep + 1] = co end end
    if #keep == #h.coowners then return false, 'not a co-owner' end
    h.coowners = keep
    HX.save(h, { 'coowners' })
    HX.changed(h, true)
    HX.lostAccess(h, cid)
    return true, ('co-owner %d removed from #%d'):format(cid, h.id)
end

ACTIONS.endraid = function(h)
    if not h.justraided then return false, 'not open from a raid' end
    HX.Raids.endOpen(h)
    return true, ('raid on #%d ended'):format(h.id)
end

ACTIONS.resetcooldown = function(h)
    h.raidcooldown, h.raidday = false, 0
    HX.save(h, { 'raidcooldown', 'raidday' })
    HX.changed(h)
    return true, ('raid protection of #%d reset'):format(h.id)
end

ACTIONS.clearproduction = function(h)
    HX.clearProduction(h)
    HX.changed(h)
    return true, ('production at #%d cancelled'):format(h.id)
end

ACTIONS.rename = function(h, data)
    local name = U.clipName(data.name, Config.Hideouts.nameMax)
    if name == '' then return false, 'empty name' end
    h.name = name
    HX.save(h, { 'name' })
    HX.changed(h, true)
    return true, ('#%d renamed to %s'):format(h.id, name)
end

ACTIONS.evict = function(h)
    HX.Bookie.refundAll(h.id, 'fight_interrupted2')
    HX.forceOut(h)
    if HX.Reloc.pending[h.id] then HX.Reloc.forget(h.id) end
    HX.Raids.forget(h.id)
    HX.Wagons.forget(h.id)
    local formerOwner, formerCo = h.charidentifier, h.coowners
    h.owned, h.identifier, h.charidentifier = false, nil, nil
    h.coowners, h.ledger, h.webhook, h.items = {}, 0, nil, {}
    h.mashinfo, h.stillinfo, h.lasttimer, h.lasttimer2 = nil, nil, 0, 0
    h.justraided, h.raidopenedat, h.raidcooldown, h.raidday = false, 0, false, 0
    HX.save(h)
    HX.menuLock[h.id], HX.stashLock[h.id] = nil, nil
    if formerOwner then HX.lostAccess(h, formerOwner) end
    for _, co in ipairs(formerCo or {}) do HX.lostAccess(h, co.charid) end
    HX.pushAll()
    HX.blips()
    return true, ('#%d evicted and back on sale'):format(h.id)
end

ACTIONS.delete = function(h)
    HX.deleteHideout(h)
    return true, ('#%d deleted'):format(h.id)
end

exports('AdminAction', function(action, hideoutId, data)
    local fn = ACTIONS[tostring(action or '')]
    if not fn then return false, 'unknown action' end
    local h = HX.hideouts[tonumber(hideoutId)]
    if not h then return false, 'hideout not found' end
    return fn(h, type(data) == 'table' and data or {})
end)

exports('GetPlayerHideoutCount', function(charId)
    return HX.countsFor(charId)
end)

----------------------------------------------------------------------------------------------------
-- debug commands
----------------------------------------------------------------------------------------------------
local function nearestOrGiven(src, arg)
    local id = tonumber(arg)
    if id then return HX.hideouts[id] end
    local pos = HX.pos(src)
    local inside = HX.hideoutByBucket(HX.bucket(src))
    if inside then return inside end
    local best, bd = nil, math.huge
    for _, h in pairs(HX.hideouts) do
        local d = U.dist(pos, h.coords)
        if d < bd then best, bd = h, d end
    end
    return best
end

local function debugCmd(name, fn)
    RegisterCommand(name, function(src, args)
        if src == 0 then return end
        if not Config.Debug then return HX.tip(src, L('debug_disabled')) end
        if not HX.isAdmin(src) then return HX.tip(src, L('no_permission')) end
        local h = nearestOrGiven(src, args[1])
        if not h then return HX.tip(src, L('debug_no_hideout')) end
        fn(src, h)
    end, false)
end

debugCmd('stilltest', function(src, h)
    h.owned, h.charidentifier, h.identifier = true, -1, 'debug'
    h.still = { stilllevel = 3, stilltype = Config.Stills[3].model }
    h.justraided, h.raidopenedat = true, os.time()
    HX.save(h, { 'owned', 'charidentifier', 'identifier', 'still', 'justraided', 'raidopenedat' })
    HX.pushAll()
    HX.tip(src, L('debug_armed', h.id))
end)

debugCmd('stilltestreset', function(src, h)
    h.owned, h.charidentifier, h.identifier = false, nil, nil
    h.still = nil
    h.justraided, h.raidopenedat, h.raidcooldown, h.raidday = false, 0, false, 0
    HX.Raids.forget(h.id)
    HX.save(h, { 'owned', 'charidentifier', 'identifier', 'still', 'justraided', 'raidopenedat', 'raidcooldown', 'raidday' })
    HX.pushAll()
    HX.tip(src, L('debug_reset', h.id))
end)
