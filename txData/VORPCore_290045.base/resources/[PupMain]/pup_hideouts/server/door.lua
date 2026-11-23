-- pup_hideouts | the door: buying, knocking, staff create/delete, plans, relocation

local H <const> = Config.Hideouts

----------------------------------------------------------------------------------------------------
-- buying
----------------------------------------------------------------------------------------------------
HX.rpc('buy', function(src, id)
    local c = HX.char(src)
    if not c then return false end
    local cid = tonumber(c.charIdentifier)
    local _, owned, co = HX.countsFor(cid)
    if owned >= H.maxOwned then
        HX.left(src, L('limit_owned', owned))
        return false
    end
    if co >= H.maxCoOwned then
        HX.left(src, L('limit_coowned', co))
        return false
    end
    -- re-read after the database await
    local h = HX.hideouts[tonumber(id)]
    if not h or h.owned then
        HX.tip(src, L('not_for_sale'))
        return false
    end
    if U.dist(HX.pos(src), h.coords) > H.doorReach then
        HX.tip(src, L('too_far'))
        return false
    end
    local price = U.round2(h.price)
    if HX.cash(src) < price then
        HX.tip(src, L('not_enough_money', U.money(price)))
        return false
    end
    if not HX.takeCash(src, price) then return false end
    c = HX.char(src)
    h.owned = true
    h.identifier = c.identifier
    h.charidentifier = cid
    HX.save(h, { 'owned', 'identifier', 'charidentifier' })
    HX.left(src, L('bought'))
    HX.changed(h, true)
    Logs.send('Main', 'Hideout Purchased', ('Bought for $%s'):format(U.money(price)), 'purchase', src,
        { { 'Price', '$' .. U.money(price), true } }, h)
    return true
end, 1500)

----------------------------------------------------------------------------------------------------
-- knocking
----------------------------------------------------------------------------------------------------
local knocks = {} -- [knockerSrc] = { id, asked = { [src] = true }, expires }

local function endKnock(knocker, reasonKey)
    local k = knocks[knocker]
    if not k then return end
    knocks[knocker] = nil
    for s in pairs(k.asked) do TriggerClientEvent('pup_hideouts:knockEnd', s, knocker) end
    if reasonKey and GetPlayerName(knocker) then HX.tip(knocker, L(reasonKey)) end
end

HX.on('knock', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h or not h.owned or knocks[src] then return end
    if U.dist(HX.pos(src), h.coords) > H.knockRadius then return end
    local name = HX.nameOf(src)
    local asked = {}
    for _, s in ipairs(HX.memberSources(h)) do
        if s ~= src then
            asked[s] = true
            TriggerClientEvent('pup_hideouts:knockAsk', s, src, name, h.id)
        end
    end
    if next(asked) == nil then return end
    knocks[src] = { id = h.id, asked = asked, expires = os.time() + H.knockWait }
end, 2000)

HX.on('knockAnswer', function(src, knocker, allow)
    knocker = tonumber(knocker)
    local k = knocker and knocks[knocker]
    local cid = HX.charId(src)
    local h = k and HX.hideouts[k.id]
    if not k or not h or not HX.isMember(h, cid) then
        print(('^3[pup_hideouts]^7 %s [%d] answered a knock that was not theirs to answer (knocker %s)')
            :format(GetPlayerName(src) or '?', src, tostring(knocker)))
        return
    end
    if allow ~= true then
        -- deny only takes the prompt away; the knock times out on its own
        TriggerClientEvent('pup_hideouts:knockEnd', src, knocker)
        return
    end
    endKnock(knocker)
    HX.invites[knocker] = { id = h.id, expires = os.time() + H.inviteSeconds }
    TriggerClientEvent('pup_hideouts:invited', knocker, h.id)
end, 300)

function HX.knockDropped(src)
    endKnock(src)
    for knocker, k in pairs(knocks) do
        if k.asked[src] then
            k.asked[src] = nil
            if next(k.asked) == nil then endKnock(knocker, 'nobody_came') end
        end
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for knocker, k in pairs(knocks) do
            local h = HX.hideouts[k.id]
            if not GetPlayerName(knocker) or not h then
                endKnock(knocker)
            elseif now >= k.expires then
                endKnock(knocker, 'nobody_came')
            elseif U.dist(HX.pos(knocker), h.coords) > H.knockRadius then
                endKnock(knocker, 'walked_from_door')
            end
        end
        for s, inv in pairs(HX.invites) do
            if inv.expires <= now or not GetPlayerName(s) then HX.invites[s] = nil end
        end
    end
end)

----------------------------------------------------------------------------------------------------
-- staff: create and delete
----------------------------------------------------------------------------------------------------
HX.rpc('create', function(src, price, name)
    if not HX.isStaff(src) then return false end
    price = tonumber(price)
    name = U.clipName(name, H.nameMax)
    if not price or price < 0 or price ~= price or name == '' then
        HX.tip(src, L('create_bad'))
        return false
    end
    local pos = HX.pos(src)
    if not pos then return false end
    local id = MySQL.insert.await(
        'INSERT INTO `underground` (`coords`, `zone`, `name`, `price`, `owned`) VALUES (?, ?, ?, ?, 0)',
        { json.encode(U.plain(pos)), Config.DefaultZone, name, U.round2(price) })
    if not id then return false end
    HX.reloadAll()
    HX.pushAll()
    HX.blips()
    HX.tip(src, L('created', id))
    return true
end, 2000)

-- refund bets, drop the row, tell everyone
function HX.deleteHideout(h)
    if HX.Bookie then HX.Bookie.refundAll(h.id, 'fight_interrupted2') end
    HX.forceOut(h)
    MySQL.query.await('DELETE FROM `underground` WHERE `id` = ?', { h.id })
    HX.hideouts[h.id] = nil
    HX.occupants[h.id], HX.menuLock[h.id], HX.stashLock[h.id] = nil, nil, nil
    if HX.Raids then HX.Raids.forget(h.id) end
    if HX.Wagons then HX.Wagons.forget(h.id) end
    HX.Reloc.forget(h.id)
    HX.pushRemoved(h.id)
    HX.blips()
end

HX.rpc('delete', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h then return false end
    local admin = HX.isAdmin(src)
    if not admin and not (HX.isStaffJob(src) and not h.owned) then return false end
    Logs.send('Main', 'Hideout Deleted', ('Hideout #%d was deleted'):format(h.id), 'delete', src, {}, h)
    HX.deleteHideout(h)
    HX.tip(src, L('deleted'))
    return true
end, 2000)

----------------------------------------------------------------------------------------------------
-- spacing (plans and relocation)
----------------------------------------------------------------------------------------------------
-- nil when the spot is fine, else distance and the needed distance of the nearest offender
function HX.spacingProblem(pos, exceptId)
    for _, h in pairs(HX.hideouts) do
        if h.id ~= exceptId and not U.isOrigin(h.coords) then
            local need = h.owned and H.spacingOwned or H.spacingUnowned
            local d = U.dist(pos, h.coords)
            if d < need then return math.floor(d), math.floor(need) end
        end
    end
    return nil
end

function HX.spacingList()
    local out = {}
    for _, h in pairs(HX.hideouts) do
        if not U.isOrigin(h.coords) then out[#out + 1] = { c = h.coords, owned = h.owned } end
    end
    return out
end

----------------------------------------------------------------------------------------------------
-- founding with plans
----------------------------------------------------------------------------------------------------
local function plansLimits(src)
    local cid = HX.charId(src)
    local total, owned = HX.countsFor(cid)
    if owned >= H.maxOwned then return L('own_one') end
    if total >= H.maxTotal then return L('too_many_parts') end
    return nil
end

CreateThread(function()
    while not HX.ready do Wait(500) end
    Inv:registerUsableItem(H.plansItem, function(data)
        local src = data and data.source
        if not src or not HX.char(src) then return end
        pcall(function() Inv:closeInventory(src) end)
        local why = plansLimits(src)
        if why then return HX.tip(src, why) end
        TriggerClientEvent('pup_hideouts:plansBegin', src, HX.spacingList())
    end, GetCurrentResourceName())
end)

local plansBusy = false -- one founding at a time, so two players cannot both pass the spacing check

HX.rpc('plansFound', function(src, coords, name)
    if plansBusy then HX.tip(src, L('no_answer')) return false end
    plansBusy = true
    local ok, res = pcall(HX.foundWithPlans, src, coords, name)
    plansBusy = false
    if not ok then error(res) end
    return res
end, 3000)

function HX.foundWithPlans(src, coords, name)
    local why = plansLimits(src)
    if why then HX.tip(src, why) return false end
    local c = U.plain(coords)
    local pos = HX.pos(src)
    if not c or not pos or U.isOrigin(c) or U.dist(c, pos) > H.plansReach then
        HX.tip(src, L('too_far'))
        return false
    end
    if HX.bucket(src) ~= 0 then HX.tip(src, L('relocate_inside')) return false end
    local d, need = HX.spacingProblem(c)
    if d then HX.tip(src, L('too_close_other', d, need)) return false end
    if not HX.removeItem(src, H.plansItem, 1) then HX.tip(src, L('no_plans')) return false end
    local ch = HX.char(src)
    if not ch then return false end
    name = U.clipName(name, H.nameMax)
    if name == '' then name = 'Hideout' end
    local id = MySQL.insert.await(
        'INSERT INTO `underground` (`identifier`, `charidentifier`, `coords`, `zone`, `name`, `price`, `owned`) VALUES (?, ?, ?, ?, ?, ?, 1)',
        { ch.identifier, tonumber(ch.charIdentifier), json.encode(c), Config.DefaultZone, name, H.plansPrice })
    if not id then return false end
    HX.reloadAll()
    HX.tip(src, L('plans_spent'))
    HX.pushAll()
    HX.blips()
    print(('[pup_hideouts] %s (char %s) founded hideout #%d "%s" with plans'):format(GetPlayerName(src) or '?', tostring(ch.charIdentifier), id, name))
    return true
end

----------------------------------------------------------------------------------------------------
-- relocation. The fee leaves the ledger at once; the pending move is kept in resource KVP so a
-- restart refunds it.
----------------------------------------------------------------------------------------------------
HX.Reloc = { pending = {} } -- [id] = { src, charid, fee, at }

local function kvpKey(id) return ('reloc:%d'):format(id) end

local function persist(id, p)
    if p then SetResourceKvp(kvpKey(id), json.encode({ charid = p.charid, fee = p.fee, at = p.at }))
    else DeleteResourceKvp(kvpKey(id)) end
end

function HX.Reloc.refund(id, notifyKey, ...)
    local p = HX.Reloc.pending[id]
    if not p then return end
    HX.Reloc.pending[id] = nil
    persist(id, nil)
    local h = HX.hideouts[id]
    if h then
        h.ledger = U.round2(h.ledger + p.fee)
        HX.save(h, { 'ledger' })
        HX.changed(h)
    end
    if notifyKey and p.src and GetPlayerName(p.src) then
        HX.tip(p.src, L(notifyKey, ...))
        TriggerClientEvent('pup_hideouts:relocateEnd', p.src)
    end
end

function HX.Reloc.forget(id)
    HX.Reloc.pending[id] = nil
    persist(id, nil)
end

function HX.Reloc.dropped(src)
    for id, p in pairs(HX.Reloc.pending) do
        if p.src == src then HX.Reloc.refund(id) end
    end
end

-- a restart lost every pending move; give the fees back
function HX.Reloc.recover()
    local handle = StartFindKvp('reloc:')
    local keys = {}
    if handle and handle ~= -1 then
        while true do
            local k = FindKvp(handle)
            if not k then break end
            keys[#keys + 1] = k
        end
        EndFindKvp(handle)
    end
    for _, k in ipairs(keys) do
        local id = tonumber(k:match('reloc:(%d+)'))
        local p = U.decode(GetResourceKvpString(k), nil)
        DeleteResourceKvp(k)
        local h = id and HX.hideouts[id]
        if h and p and tonumber(p.fee) then
            h.ledger = U.round2(h.ledger + tonumber(p.fee))
            HX.save(h, { 'ledger' })
            print(('[pup_hideouts] refunded $%s to hideout #%d: its move was pending when the resource stopped'):format(U.money(p.fee), id))
        end
    end
end

HX.rpc('relocateStart', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h or HX.role(h, HX.charId(src)) ~= 'owner' then HX.tip(src, L('owner_only')) return false end
    if not HX.isInside(src, h) then HX.tip(src, L('too_far')) return false end
    local p = HX.Reloc.pending[h.id]
    if p then
        if p.src == src then
            TriggerClientEvent('pup_hideouts:relocateBegin', src, h.id)
            return true
        end
        HX.tip(src, L('menu_in_use'))
        return false
    end
    local fee = H.relocatePrice
    if h.ledger < fee then HX.tip(src, L('not_enough_ledger_move', fee)) return false end
    h.ledger = U.round2(h.ledger - fee)
    HX.save(h, { 'ledger' })
    HX.Reloc.pending[h.id] = { src = src, charid = HX.charId(src), fee = fee, at = os.time() }
    persist(h.id, HX.Reloc.pending[h.id])
    HX.changed(h)
    TriggerClientEvent('pup_hideouts:relocateBegin', src, h.id)
    return true
end, 1500)

local function pendingOf(src)
    for id, p in pairs(HX.Reloc.pending) do
        if p.src == src then return id, p end
    end
    return nil
end

HX.rpc('relocateHere', function(src, coords)
    local id = pendingOf(src)
    if not id then HX.tip(src, L('no_relocation')) return false end
    local h = HX.hideouts[id]
    if not h or HX.role(h, HX.charId(src)) ~= 'owner' then
        HX.Reloc.refund(id, 'relocate_failed')
        return false
    end
    local c = U.plain(coords)
    local pos = HX.pos(src)
    if HX.bucket(src) ~= 0 or not c or not pos or U.isOrigin(c) or U.dist(c, pos) > H.plansReach then
        HX.Reloc.refund(id, 'relocate_failed')
        return false
    end
    local d, need = HX.spacingProblem(c, id)
    if d then
        HX.Reloc.refund(id, 'relocate_failed_d', d, need)
        return false
    end
    HX.Reloc.pending[id] = nil
    persist(id, nil)
    h.coords = c
    HX.save(h, { 'coords' })
    HX.tip(src, L('relocated'))
    TriggerClientEvent('pup_hideouts:relocateEnd', src)
    HX.changed(h, true)
    return true
end, 2000)

HX.rpc('relocateCancel', function(src)
    local id = pendingOf(src)
    if not id then HX.tip(src, L('no_relocation')) return false end
    HX.Reloc.refund(id, 'relocate_called_off')
    return true
end, 1000)

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, p in pairs(HX.Reloc.pending) do
            if now - p.at >= H.relocateMinutes * 60 then HX.Reloc.refund(id, 'relocate_expired') end
        end
    end
end)
