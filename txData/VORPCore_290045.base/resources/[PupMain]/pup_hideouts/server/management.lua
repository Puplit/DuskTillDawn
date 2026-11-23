-- pup_hideouts | the books: menu lock, purchases, ledger, members, owner webhook

local H <const> = Config.Hideouts

-- member AND inside that hideout's instance; returns h, charid, role
local function memberInside(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h then return nil end
    local cid = HX.charId(src)
    local role = HX.role(h, cid)
    if not role or not HX.isInside(src, h) then
        HX.tip(src, L('too_far'))
        return nil
    end
    return h, cid, role
end
HX.memberInside = memberInside

local function ownerInside(src, id)
    local h, cid, role = memberInside(src, id)
    if not h then return nil end
    if role ~= 'owner' then HX.tip(src, L('owner_only')) return nil end
    return h, cid
end

----------------------------------------------------------------------------------------------------
-- menu lock (one person in the books / production menu at a time)
----------------------------------------------------------------------------------------------------
HX.rpc('menuLock', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h or not HX.isMember(h, HX.charId(src)) or not HX.isInside(src, h) then return 'denied' end
    local holder = HX.menuLock[h.id]
    if holder and holder ~= src and GetPlayerName(holder) and HX.isInside(holder, h) then return 'busy' end
    HX.menuLock[h.id] = src
    return 'ok'
end, 500)

HX.on('menuUnlock', function(src, id)
    id = tonumber(id)
    if id and HX.menuLock[id] == src then HX.menuLock[id] = nil end
end, 100)

----------------------------------------------------------------------------------------------------
-- purchases (prices always from the config)
----------------------------------------------------------------------------------------------------
local function pay(src, price)
    if HX.cash(src) < price then
        HX.tip(src, L('not_enough_money', U.money(price)))
        return false
    end
    return HX.takeCash(src, price)
end

HX.rpc('buyBookie', function(src, id)
    local h = memberInside(src, id)
    if not h or h.bookie then return false end
    if not pay(src, Config.Bookie.price) then return false end
    h.bookie = true
    HX.save(h, { 'bookie' })
    HX.tip(src, L('purchase_ok'))
    HX.changed(h)
    return true
end, 1000)

HX.rpc('rename', function(src, id, name)
    local h = memberInside(src, id)
    if not h then return false end
    name = U.clipName(name, H.nameMax)
    if name == '' then HX.tip(src, L('bad_name')) return false end
    if not pay(src, H.renamePrice) then return false end
    h.name = name
    HX.save(h, { 'name' })
    HX.tip(src, L('name_changed', name))
    HX.changed(h, true)
    Logs.send('Main', 'Hideout Renamed', ('Renamed to %s'):format(name), 'rename', src,
        { { 'New Name', name, true }, { 'Cost', '$' .. U.money(H.renamePrice), true } }, h)
    return true
end, 1500)

HX.rpc('buyTier', function(src, id, tierName)
    local h = memberInside(src, id)
    if not h then return false end
    local tier = U.tierByName(tierName)
    if not tier or tier.level ~= h.invlevel then return false end
    if HX.cash(src) < tier.price then HX.tip(src, L('not_enough_money', U.money(tier.price))) return false end
    for _, it in ipairs(tier.items) do
        if HX.itemCount(src, it.name) < it.amount then HX.tip(src, L('no_mats')) return false end
    end
    if not HX.takeCash(src, tier.price) then return false end
    local taken = {}
    for _, it in ipairs(tier.items) do
        if not HX.removeItem(src, it.name, it.amount) then
            -- something vanished between the check and the take: put back what we took
            for _, t in ipairs(taken) do HX.addItem(src, t.name, t.amount) end
            HX.giveCash(src, tier.price)
            HX.tip(src, L('no_mats'))
            return false
        end
        taken[#taken + 1] = it
    end
    h.invslots = h.invslots + tier.slots
    h.invlevel = tier.level + 1
    HX.save(h, { 'invslots', 'invlevel' })
    HX.tip(src, L('purchase_ok'))
    HX.changed(h)
    return true
end, 1500)

HX.rpc('buyDecor', function(src, id, set)
    local h = memberInside(src, id)
    if not h then return false end
    local d = U.decoBySet(set)
    if not d then return false end
    if not pay(src, d.price) then return false end
    h.upgrades[d.category] = d.set
    HX.save(h, { 'upgrades' })
    HX.tip(src, L('purchase_applied'))
    HX.changed(h)
    return true
end, 1000)

HX.rpc('removeDecor', function(src, id, category)
    local h = memberInside(src, id)
    if not h or type(category) ~= 'string' or not h.upgrades[category] then return false end
    h.upgrades[category] = nil
    HX.save(h, { 'upgrades' })
    HX.tip(src, L('removal_ok'))
    HX.changed(h)
    return true
end, 1000)

HX.rpc('buyTheme', function(src, id, set)
    local h = memberInside(src, id)
    if not h then return false end
    local t = U.themeBySet(set)
    if not t or h.theme == t.set then return false end
    if not pay(src, t.price) then return false end
    h.theme = t.set
    HX.save(h, { 'theme' })
    HX.tip(src, L('purchase_applied'))
    HX.changed(h)
    return true
end, 1000)

----------------------------------------------------------------------------------------------------
-- ledger
----------------------------------------------------------------------------------------------------
HX.rpc('ledgerWithdraw', function(src, id, amount)
    local h = memberInside(src, id)
    amount = U.posInt(amount)
    if not h then return false end
    if not amount then HX.tip(src, L('bad_amount')) return false end
    if amount > h.ledger then HX.tip(src, L('not_enough_ledger', U.money(h.ledger))) return false end
    h.ledger = U.round2(h.ledger - amount)
    HX.giveCash(src, amount)
    HX.save(h, { 'ledger' })
    HX.tip(src, L('withdrew', amount))
    HX.changed(h)
    Logs.send('Ledger', 'Ledger Withdrawal', ('Took $%d out of the ledger'):format(amount), 'withdrawal', src,
        { { 'Amount', '$' .. amount, true } }, h)
    return true
end, 1000)

HX.rpc('ledgerDeposit', function(src, id, amount)
    local h = memberInside(src, id)
    amount = U.posInt(amount)
    if not h then return false end
    if not amount then HX.tip(src, L('bad_amount')) return false end
    if not HX.takeCash(src, amount) then HX.tip(src, L('not_enough_money', amount)) return false end
    h.ledger = U.round2(h.ledger + amount)
    HX.save(h, { 'ledger' })
    HX.tip(src, L('deposited', amount))
    HX.changed(h)
    Logs.send('Ledger', 'Ledger Deposit', ('Put $%d into the ledger'):format(amount), 'deposit', src,
        { { 'Amount', '$' .. amount, true } }, h)
    return true
end, 1000)

----------------------------------------------------------------------------------------------------
-- co-owners and transfer, with the target's consent
----------------------------------------------------------------------------------------------------
local consents = {} -- [targetSrc] = { kind, id, owner, expires, token }
local tokenSeq = 0

-- nil when allowed, else the locale key to show
local function memberRule(h, kind, ownerSrc, target)
    local ownerCid = HX.charId(ownerSrc)
    if HX.role(h, ownerCid) ~= 'owner' then return 'owner_only' end
    local tcid = target and HX.charId(target)
    if not tcid or target == ownerSrc then return 'invalid_id' end
    if HX.bucket(target) ~= HX.bucketOf(h) or HX.bucket(ownerSrc) ~= HX.bucketOf(h)
        or U.dist(HX.pos(target), HX.pos(ownerSrc)) > H.consentRange then
        return 'need_next_to_you'
    end
    local total, owned, co = HX.countsFor(tcid)
    local role = HX.role(h, tcid)
    if kind == 'coowner' then
        if role then return 'invalid_id' end
        if co >= H.maxCoOwned or total >= H.maxTotal then return 'too_many' end
    else
        if owned >= H.maxOwned then return 'too_many' end
        -- a co-owner taking over swaps one place for another
        local after = total + (role == 'coowner' and 0 or 1)
        if after > H.maxTotal then return 'too_many' end
    end
    return nil
end

local function closeConsent(target, notifyKey)
    local c = consents[target]
    if not c then return end
    consents[target] = nil
    if GetPlayerName(target) then TriggerClientEvent('pup_hideouts:consentClose', target, c.token) end
    if notifyKey and c.owner and GetPlayerName(c.owner) then HX.tip(c.owner, L(notifyKey)) end
end

local function ask(src, id, targetId, kind)
    local h = HX.hideouts[tonumber(id)]
    if not h then return false end
    local target = U.posInt(targetId)
    if target and not GetPlayerName(target) then target = nil end
    if not HX.isInside(src, h) then HX.tip(src, L('too_far')) return false end
    local why = memberRule(h, kind, src, target)
    if why then HX.tip(src, L(why)) return false end
    if consents[target] then HX.tip(src, L('already_deciding')) return false end
    h = HX.hideouts[h.id] -- re-read after the database await
    if not h then return false end
    tokenSeq = tokenSeq + 1
    consents[target] = { kind = kind, id = h.id, owner = src, expires = os.time() + H.consentSeconds, token = tokenSeq }
    local ownerName = HX.nameOf(src)
    local sub = kind == 'coowner' and L('ask_coowner', ownerName, h.name) or L('ask_transfer', ownerName, h.name)
    TriggerClientEvent('pup_hideouts:consentAsk', target, tokenSeq, h.name, sub)
    HX.tip(src, L('asked'))
    return true
end

HX.rpc('addCoowner', function(src, id, target) return ask(src, id, target, 'coowner') end, 1500)
HX.rpc('transfer', function(src, id, target) return ask(src, id, target, 'transfer') end, 1500)

HX.on('consentAnswer', function(src, token, accept)
    local c = consents[src]
    if not c or c.token ~= token then return end
    consents[src] = nil
    local owner = c.owner
    if accept ~= true then
        if GetPlayerName(owner) then HX.tip(owner, L('said_no')) end
        return
    end
    local h = HX.hideouts[c.id]
    if not h or not GetPlayerName(owner) then return end
    local why = memberRule(h, c.kind, owner, src)
    h = HX.hideouts[c.id]
    if why or not h then
        why = why or 'invalid_id'
        HX.tip(owner, L(why))
        HX.tip(src, L(why))
        return
    end
    local ch = HX.char(src)
    if not ch then return end
    local tcid = tonumber(ch.charIdentifier)
    local tname = HX.fullName(ch)
    if c.kind == 'coowner' then
        h.coowners[#h.coowners + 1] = { charid = tcid, name = tname }
        HX.save(h, { 'coowners' })
        HX.tip(owner, L('added_coowner', tname))
        HX.tip(src, L('became_coowner', h.name))
        Logs.send('Main', 'Member Added', ('%s was added as a co-owner'):format(tname), 'memberAdded', owner,
            { { 'Added', ('%s (%d)'):format(tname, tcid), true } }, h)
    else
        Logs.send('Main', 'Hideout Transferred', ('Handed over to %s'):format(tname), 'transfer', owner,
            { { 'New Owner', ('%s (%d)'):format(tname, tcid), true } }, h)
        local oldOwner = h.charidentifier
        h.identifier = ch.identifier
        h.charidentifier = tcid
        local keep = {}
        for _, co in ipairs(h.coowners) do
            if tonumber(co.charid) ~= tcid then keep[#keep + 1] = co end
        end
        h.coowners = keep
        h.webhook = nil
        HX.save(h, { 'identifier', 'charidentifier', 'coowners', 'webhook' })
        HX.tip(owner, L('transferred'))
        HX.tip(src, L('became_owner', h.name))
        -- whatever the old owner had running that needs ownership ends here
        if HX.Reloc.pending[h.id] then HX.Reloc.refund(h.id, 'relocate_called_off') end
        HX.changed(h, true)
        if oldOwner then HX.lostAccess(h, oldOwner) end
        return
    end
    HX.changed(h, true)
end, 300)

function HX.consentDropped(src)
    closeConsent(src, 'no_reply')
    for target, c in pairs(consents) do
        if c.owner == src then closeConsent(target) end
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for target, c in pairs(consents) do
            if now >= c.expires or not GetPlayerName(target) then closeConsent(target, 'no_reply') end
        end
    end
end)

HX.rpc('removeCoowner', function(src, id, charid)
    local h = HX.hideouts[tonumber(id)]
    charid = tonumber(charid)
    if not h or not charid then return false end
    if HX.role(h, HX.charId(src)) ~= 'owner' then HX.tip(src, L('owner_only')) return false end
    local keep, removedName = {}, nil
    for _, co in ipairs(h.coowners) do
        if tonumber(co.charid) == charid then removedName = removedName or co.name
        else keep[#keep + 1] = co end
    end
    if #keep == #h.coowners then return false end
    h.coowners = keep
    HX.save(h, { 'coowners' })
    HX.tip(src, L('removed_coowner'))
    HX.changed(h, true)
    Logs.send('Main', 'Member Removed', ('%s was removed'):format(removedName or 'Unknown'), 'memberRemoved', src,
        { { 'Removed', ('%s (%d)'):format(removedName or 'Unknown', charid), true } }, h)
    HX.lostAccess(h, charid)
    return true
end, 1000)

HX.rpc('leave', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    local cid = HX.charId(src)
    if not h or not cid then return false end
    local role = HX.role(h, cid)
    if role == 'owner' then HX.tip(src, L('owner_cant_leave')) return false end
    if role ~= 'coowner' then return false end
    -- logged first, while the leaver is still a member (so the owner's channel gets it)
    Logs.send('Main', 'Member Left', 'A co-owner gave up their access', 'memberLeft', src, {}, h)
    local keep = {}
    for _, co in ipairs(h.coowners) do
        if tonumber(co.charid) ~= cid then keep[#keep + 1] = co end
    end
    h.coowners = keep
    HX.save(h, { 'coowners' })
    HX.tip(src, L('you_left', h.name))
    local owner = HX.srcOfChar(h.charidentifier)
    if owner then HX.tip(owner, L('gave_up', HX.nameOf(src) or L('a_coowner'), h.name)) end
    HX.changed(h, true)
    HX.lostAccess(h, cid)
    return true
end, 1500)

-- a character lost access: whatever they were holding in that hideout ends
function HX.lostAccess(h, charid)
    local src = HX.srcOfChar(charid)
    if not src then return end
    if HX.menuLock[h.id] == src then HX.menuLock[h.id] = nil end
    if HX.stashLock[h.id] == src then HX.stashLock[h.id] = nil end
    TriggerClientEvent('pup_hideouts:accessLost', src, h.id)
end

----------------------------------------------------------------------------------------------------
-- the owner's own Discord channel
----------------------------------------------------------------------------------------------------
HX.rpc('setWebhook', function(src, id, url)
    if not Config.Logs.ownerWebhooks then return false end
    local h = HX.hideouts[tonumber(id)]
    if not h or HX.role(h, HX.charId(src)) ~= 'owner' then HX.tip(src, L('owner_only')) return false end
    local clean = U.validWebhook(url)
    if not clean then HX.tip(src, L('webhook_invalid')) return false end
    h.webhook = clean
    HX.save(h, { 'webhook' })
    HX.tip(src, L('webhook_set'))
    if not Config.Logs.enabled then
        HX.tip(src, L('logging_off'))
    else
        Logs.direct(clean, 'Hideout Log Connected',
            "This channel will now receive this hideout's logs, raids are not included", 'webhook', src, h)
    end
    HX.changed(h)
    return true
end, 3000)
