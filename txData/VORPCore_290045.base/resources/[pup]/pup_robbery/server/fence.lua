-- pup_robbery | the fence: where he stands, his menu, jobs, the drop crate, payouts, talk and letters

Fence = {}

local F = Config.Fence
local P = Config.Perks

local state = {
    stop = nil, nextStop = nil, deck = {}, rate = 0.7, movedAt = 0, moveAt = 0,
    sellers = {},     -- [charid] = true, sold at the current stop
}
local repCache = {}   -- [charid] = { rep, sales, value }
local repOwner = {}   -- [src] = charid whose standing was read, so a disconnect can drop it
local rumourCd = {}   -- [src] = os.time() of the last rumour
local busy = {}       -- [charid] = true while a sale or a collection runs

--------------------------------------------------------------------------------
-- where he stands

local function stopDef(i) return i and F.stops[i] or nil end

local function draw(leaving)
    if #state.deck == 0 then
        for i = 1, #F.stops do state.deck[i] = i end
        U.shuffle(state.deck)
        -- a new deck never starts on the stop he is leaving
        if #state.deck > 1 and state.deck[#state.deck] == leaving then
            state.deck[1], state.deck[#state.deck] = state.deck[#state.deck], state.deck[1]
        end
    end
    return table.remove(state.deck)
end

local function rollRate()
    local r = F.payRate
    if type(r) == 'number' then return r end
    return r.min + math.random() * (r.max - r.min)
end

function Fence.spot()
    local s = stopDef(state.stop)
    if not s then return nil end
    local prompt = s.prompt or s.pos
    return {
        coords = { x = s.pos.x, y = s.pos.y, z = s.pos.z, h = s.heading },
        promptcoords = { x = prompt.x, y = prompt.y, z = prompt.z },
        label = s.label, region = s.region,
    }
end

local function clientSpot()
    local s = stopDef(state.stop)
    if not s then return false end
    return { pos = { x = s.pos.x, y = s.pos.y, z = s.pos.z }, heading = state.heading or s.heading,
             prompt = s.prompt and { x = s.prompt.x, y = s.prompt.y, z = s.prompt.z } or nil }
end

local function pushStall()
    if not F.stall.enabled or not S.up('pup_mercantile') then return end
    S.call('pup_mercantile', 'SetStoreStock', F.stall.storeName, F.stall.stock)
    local s = stopDef(state.stop)
    if s then S.call('pup_mercantile', 'SetStorePos', F.stall.storeName, { x = s.pos.x, y = s.pos.y, z = s.pos.z }) end
end

local function nextNames()
    local n = stopDef(state.nextStop)
    return (n and n.region) or F.rumours.fallbackRegion, (n and n.label) or F.rumours.fallbackLandmark
end

local function tellSellers(oldSellers)
    if not F.rumours.moveNotice then return end
    local s = stopDef(state.stop)
    local region = s and s.region or F.rumours.fallbackRegion
    local label = s and s.label or F.rumours.fallbackLandmark
    for cid in pairs(oldSellers) do
        local src = S.srcForChar(cid)
        local landmark = src and S.perkRank(src, P.streetword) >= F.rumours.landmarkRank
        if F.rumours.moveMail and S.up('pup_postoffice') then
            local body = U.fill(landmark and F.rumours.letterLandmark or F.rumours.letterRegion, { region = region, label = label })
            S.call('pup_postoffice', 'SendSystemMail', cid, F.rumours.mailSubject, body, F.rumours.mailFrom)
        end
        if src then
            S.tip(src, U.fill(landmark and F.rumours.screenLandmark or F.rumours.screenRegion, { region = region, label = label }), 8000)
        end
    end
end

function Fence.move()
    local leaving = state.stop
    state.stop = state.nextStop or draw(leaving)
    state.nextStop = draw(state.stop)
    state.rate = rollRate()
    state.heading = nil
    state.movedAt = os.time()
    state.moveAt = os.time() + F.stayMinutes * 60
    local old = state.sellers
    state.sellers = {}
    pushStall()
    TriggerClientEvent('pup_robbery:fence:spot', -1, clientSpot())
    tellSellers(old)
    local s = stopDef(state.stop)
    print(('[pup_robbery] fence at %s (%s), paying %d%%, stop %d'):format(s.label, s.region, U.round(state.rate * 100), state.stop))
    return s
end

S.callback('pup_robbery:fence:where', function()
    return clientSpot()
end)

--------------------------------------------------------------------------------
-- gate, reach

function Fence.knows(src)
    if not F.jobs.needsPerk then return true end
    if Config.TestMode.enabled and Config.TestMode.soloCrew and S.isAdmin(src) then return true end
    return S.perkHas(src, P.access)
end

local function brushOff()
    local list = F.brushOffs or {}
    if #list == 0 then return F.brushOffFallback end
    return list[math.random(1, #list)]
end

function Fence.near(src)
    local s = stopDef(state.stop)
    if not s then return false end
    return S.near(src, s.pos, F.reach) or (s.prompt ~= nil and S.near(src, s.prompt, F.reach))
end

-- the gate and the distance, shared by every action at the fence
local function atFence(src)
    if not S.charId(src) then return false end
    if not Fence.near(src) then
        S.tip(src, L('fenceGone'))
        return false
    end
    if not Fence.knows(src) then
        S.tip(src, brushOff(), 6000)
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- reputation

local function repLevel(rep)
    local levels = F.reputation.levels
    local cur, nxt = levels[1], nil
    for i, lv in ipairs(levels) do
        if rep >= lv.from then
            cur = lv
            nxt = levels[i + 1]
        end
    end
    return cur, nxt
end

local function loadRep(cid)
    if repCache[cid] then return repCache[cid] end
    local row = DB.single('SELECT rep, sales, value FROM robbery_fence_rep WHERE charidentifier = ?', { cid })
    local r = { rep = row and tonumber(row.rep) or 0, sales = row and tonumber(row.sales) or 0, value = row and tonumber(row.value) or 0 }
    repCache[cid] = r
    return r
end

local function keepsPercent(keeps)
    return U.round((1 - state.rate) * keeps * 100)
end

--------------------------------------------------------------------------------
-- sin of the day

local function sinOfDay()
    if not F.sins.enabled or #F.sins.lines == 0 then return nil end
    local d = os.date('*t')
    local n = d.year * 366 + d.yday
    return F.sins.lines[(n % #F.sins.lines) + 1]
end

--------------------------------------------------------------------------------
-- the drop crate (a vorp_inventory custom inventory per character)

local function crateId(cid) return F.buyer.cratePrefix .. tostring(cid) end

local function ensureCrate(cid)
    local id = crateId(cid)
    local ok, reg = pcall(function() return exports.vorp_inventory:isCustomInventoryRegistered(id) end)
    if ok and reg then return id end
    pcall(function()
        exports.vorp_inventory:registerInventory({
            id = id, name = F.buyer.crateName, limit = F.buyer.crateSlots, acceptWeapons = false,
            shared = false, ignoreItemStackLimit = true,
        })
    end)
    return id
end

local function crateItems(id)
    local ok, items = pcall(function() return exports.vorp_inventory:getCustomInventoryItems(id) end)
    if ok and type(items) == 'table' then return items end
    return {}
end

--------------------------------------------------------------------------------
-- the menu

S.callback('pup_robbery:fence:menu', function(src)
    local cid = S.charId(src)
    if not cid then return false end
    if not Fence.near(src) then return { gone = true } end
    if not Fence.knows(src) then return { brush = brushOff() } end
    local out = {}
    repOwner[src] = cid
    if F.reputation.enabled then
        local r = loadRep(cid)
        local cur, nxt = repLevel(r.rep)
        out.standing = { level = cur.name, rep = r.rep, keeps = keepsPercent(cur.keeps), next = nxt and nxt.name, nextAt = nxt and nxt.from, keepsNothing = cur.keeps <= 0 }
    end
    local posse = S.posseInfo(src)
    out.inPosse = posse.inPosse == true
    out.isLeader = posse.isLeader == true
    out.task = posse.task
    out.posseCommand = S.posseCommand()
    if Heist.runForPosse(posse.id) and not out.task then out.task = 'heist:' .. Heist.runForPosse(posse.id).bank.id end
    if F.buyer.enabled then
        out.buyer = true
        local id = crateId(cid)
        local ok, reg = pcall(function() return exports.vorp_inventory:isCustomInventoryRegistered(id) end)
        if ok and reg then
            out.crateHasItems = #crateItems(id) > 0
        else
            local row = DB.single('SELECT COUNT(*) AS n FROM character_inventories WHERE inventory_type = ?', { id })
            out.crateHasItems = row ~= nil and (tonumber(row.n) or 0) > 0
        end
        local pay = DB.single('SELECT amount, readyAt FROM robbery_fence_payouts WHERE charidentifier = ?', { cid })
        if pay and (tonumber(pay.amount) or 0) > 0 then
            local left = (tonumber(pay.readyAt) or 0) - os.time()
            out.payout = { amount = tonumber(pay.amount), ready = left <= 0, minutes = U.minutesUp(left) }
        end
    end
    local sin = sinOfDay()
    if sin then out.sin = { text = sin.text, icon = sin.sin:lower() } end
    out.stall = F.stall.enabled
    out.gangs = S.up('pup-gangs')
    return out
end)

--------------------------------------------------------------------------------
-- jobs

local function jobLetter(src, label, riders, lawmen, minutes)
    local law = (lawmen or 0) > 0 and L('jobLetterLaw', lawmen) or ''
    Fence.letter(S.charId(src), F.jobs.letterSubject, L('jobLetter', label, riders, law, minutes))
end

-- the jobs on offer for this posse: list of { key, label, kind, id }, and whether a bank was held back for the law
local function offers(src, crewSize, solo)
    local list, heldForLaw = {}, false
    for id, p in pairs(Config.Places) do
        if F.jobs.categories[p.category] and Walkup.placeLeft(id) <= 0 and not Walkup.isActive(id)
            and (solo or crewSize >= U.placeSettings(p).riders) then
            list[#list + 1] = { key = id, label = id, kind = 'walkup', id = id, riders = U.placeSettings(p).riders, lawmen = U.placeSettings(p).lawmen, limit = U.placeSettings(p).jobLimit or 30 }
        end
    end
    if Fence.knows(src) or solo then
        for _, id in ipairs(Config.BankOrder) do
            local b = Config.Banks[id]
            if b and Heist.bankLeft(id) <= 0 and not Heist.run(id) and (solo or crewSize >= (b.riders or 1)) then
                if S.lawOk({ b.region }, b.lawmen or 0) then
                    list[#list + 1] = { key = 'heist:' .. id, label = b.label, kind = 'bank', id = id, riders = b.riders, lawmen = b.lawmen, limit = b.jobLimit or 45 }
                else
                    heldForLaw = true
                end
            end
        end
    end
    return list, heldForLaw
end

local function whyNot(key, crewSize, solo)
    local bankId = key:match('^heist:(.+)$')
    if bankId then
        local b = Config.Banks[bankId]
        if not b then return L('unknownKey', key) end
        if Heist.run(bankId) then return 'running' end
        if Heist.bankLeft(bankId) > 0 then return ('on cooldown (%s)'):format(U.hm(Heist.bankLeft(bankId))) end
        if not S.lawOk({ b.region }, b.lawmen or 0) then return ('needs %d lawmen'):format(b.lawmen or 0) end
        if not solo and crewSize < (b.riders or 1) then return ('needs %d riders'):format(b.riders or 1) end
        return 'not on offer'
    end
    local p = Config.Places[key]
    if not p then return L('unknownKey', key) end
    if Walkup.isActive(key) then return 'running' end
    if Walkup.placeLeft(key) > 0 then return 'on cooldown' end
    if not F.jobs.categories[p.category] then return 'not a fence job' end
    return ('needs %d riders'):format(U.placeSettings(p).riders)
end

-- hands one job to the asker's posse; `forced` = a key picked by an admin
local function handOut(src, forced)
    local posse = S.posseInfo(src)
    local members = S.posseMembers(src)
    local solo = Config.TestMode.enabled and Config.TestMode.soloCrew and S.isAdmin(src)
    local crewSize = solo and math.max(#members, S.posseMax()) or #members
    local list, heldForLaw = offers(src, crewSize, solo)
    local pick = nil
    if forced then
        for _, o in ipairs(list) do
            if o.key == forced then pick = o end
        end
        if not pick then return S.tip(src, L('jobRefused', whyNot(forced, crewSize, solo)), 6000) end
    else
        if #list == 0 then
            if heldForLaw then return S.tip(src, L('thinLaw'), 6000) end
            if not Fence.knows(src) then return S.tip(src, brushOff(), 6000) end
            return S.tip(src, L('nothingGoing', crewSize), 6000)
        end
        pick = list[math.random(1, #list)]
    end

    local ok, allowed, reason = S.call('pup-ui', 'SetPosseTask', src, pick.key, pick.label)
    if not ok then return S.tip(src, L('posseService')) end
    if not allowed then return S.tip(src, tostring(reason or L('posseService'))) end

    if pick.kind == 'bank' then
        local claimed, why = Heist.claim(pick.id, src, members, posse.id)
        if not claimed then
            S.call('pup-ui', 'ClearPosseTask', src)
            return S.tip(src, L('jobRefused', tostring(why)), 6000)
        end
    else
        if posse.id then Walkup.FenceDeadlines[posse.id] = { key = pick.key, at = os.time() + pick.limit * 60, src = src } end
    end

    jobLetter(src, pick.label, pick.riders or 1, pick.lawmen or 0, pick.limit)
    S.tip(src, forced and L('jobHanded', pick.label) or L('fenceNods', pick.limit), 7000)
end
Fence.handOut = handOut

RegisterNetEvent('pup_robbery:fence:askWork', function()
    local src = source
    if not S.rate(src, 'fenceAsk', F.askThrottleMs) then return end
    if not S.charId(src) then return end
    if not S.up('pup-ui') then return S.tip(src, L('posseService')) end
    local okLead, isLeader = S.call('pup-ui', 'IsPosseLeader', src)
    if not okLead or not isLeader then return S.tip(src, L('leaderOnly')) end
    if S.jobBlocked(src) then return S.tip(src, L('blockedJob')) end
    local posse = S.posseInfo(src)
    if posse.task or Heist.runForPosse(posse.id) then return S.tip(src, L('haveJob'), 6000) end
    local waiting = {}
    for _, m in ipairs(S.posseMembers(src)) do
        local left = Heist.personalLeft(S.charId(m))
        if left > 0 then waiting[#waiting + 1] = ('%s (%s)'):format(S.charName(m), U.hm(left)) end
    end
    if #waiting > 0 then return S.tip(src, L('bankCooldown', table.concat(waiting, ', ')), 7000) end
    if not atFence(src) then return end
    handOut(src, nil)
end)

-- admin: a named job through the same path (in game only, the blocked-job check skipped)
-- clearStale (/heiststart): a task left over with no live run behind it is cleared first
function Fence.adminJob(src, key, clearStale)
    local posse = S.posseInfo(src)
    if clearStale and posse.task and not Heist.runForPosse(posse.id) then
        S.call('pup-ui', 'ClearPosseTask', src)
        posse = S.posseInfo(src)
    end
    -- same rule as asking for work: SetPosseTask would overwrite the task of a run already under way
    if posse.task or Heist.runForPosse(posse.id) then return S.tip(src, L('haveJob'), 6000) end
    handOut(src, key)
end

RegisterNetEvent('pup_robbery:fence:walkAway', function()
    local src = source
    if not S.rate(src, 'fenceWalk', 1500) then return end
    if not S.charId(src) then return end
    local okLead, isLeader = S.call('pup-ui', 'IsPosseLeader', src)
    if not okLead or not isLeader then return S.tip(src, L('leaderOnlyDrop')) end
    if not atFence(src) then return end
    local posse = S.posseInfo(src)
    local run = Heist.runForPosse(posse.id)
    local task = posse.task
    if not task and not run then return S.tip(src, L('noJobToDrop')) end
    if run then
        Heist.finish(run, 'abandoned')
    end
    if task then S.call('pup-ui', 'ClearPosseTask', src) end
    if posse.id then Walkup.FenceDeadlines[posse.id] = nil end
    TriggerClientEvent('pup_robbery:fence:jobDropped', src)
    S.tip(src, L('jobDropped'))
end)

-- walk-up fence jobs that were never started
CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for posseId, dl in pairs(Walkup.FenceDeadlines) do
            if now > dl.at and not Walkup.isActive(dl.key) then
                Walkup.FenceDeadlines[posseId] = nil
                local anchor = S.online(dl.src) and dl.src or nil
                if anchor then
                    local ok, task = S.call('pup-ui', 'GetPosseTask', anchor)
                    if ok and task == dl.key then
                        S.call('pup-ui', 'ClearPosseTask', anchor)
                        for _, m in ipairs(S.posseMembers(anchor)) do S.tip(m, L('jobTooSlow'), 7000) end
                    end
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- selling

RegisterNetEvent('pup_robbery:fence:openCrate', function()
    local src = source
    if not S.rate(src, 'fenceCrate', 1500) or not F.buyer.enabled then return end
    if not atFence(src) then return end
    local cid = S.charId(src)
    local id = ensureCrate(cid)
    pcall(function() exports.vorp_inventory:openInventory(src, id) end)
end)

local function saleTip(src, readyAt)
    local s = stopDef(state.nextStop)
    local landmark = S.perkRoll(src, P.fenceNext)
    local where = s and (landmark and s.label or s.region) or F.rumours.fallbackWhere
    local text = U.fill(landmark and F.rumours.saleLandmark or F.rumours.saleRegion, { where = where })
    if readyAt > state.moveAt then
        text = text .. ' ' .. F.rumours.saleChase:format(U.minutesUp(readyAt - os.time()))
    end
    S.tip(src, text, 9000)
end

local function sell(src, cid)
    local id = ensureCrate(cid)
    pcall(function() exports.vorp_inventory:closeInventory(src, id) end)
    local items = crateItems(id)
    if #items == 0 then return S.tip(src, L('crateEmpty')) end

    local buy, back = {}, {}
    for _, it in ipairs(items) do
        local amount = math.floor(tonumber(it.amount) or 0)
        if amount > 0 then
            local price = F.buyer.prices[it.name]
            local hasMeta = type(it.metadata) == 'table' and next(it.metadata) ~= nil
            local lot = { name = it.name, amount = amount, crafted = hasMeta and it.crafted_id or nil, metadata = it.metadata, label = it.label or it.name, price = price }
            if price then buy[#buy + 1] = lot else back[#back + 1] = lot end
        end
    end
    for _, lot in ipairs(back) do
        if not S.canCarry(src, lot.name, lot.amount) then
            return S.tip(src, L('crateFull', lot.label), 7000)
        end
    end
    if #buy == 0 then return S.tip(src, L('crateJunk'), 6000) end

    local gross, sold, returned = 0, {}, {}
    for _, lot in ipairs(buy) do
        local ok, removed = pcall(function()
            return exports.vorp_inventory:removeItemFromCustomInventory(id, lot.name, lot.amount, lot.crafted)
        end)
        if ok and removed then
            gross = gross + lot.price * lot.amount
            sold[#sold + 1] = lot
        end
    end
    for _, lot in ipairs(back) do
        local ok, removed = pcall(function()
            return exports.vorp_inventory:removeItemFromCustomInventory(id, lot.name, lot.amount, lot.crafted)
        end)
        if ok and removed then
            S.giveItem(src, lot.name, lot.amount, lot.metadata)
            returned[#returned + 1] = lot
        end
    end
    if #returned > 0 then S.tip(src, L('handedBack'), 5000) end

    -- whatever is left reloads from the database the next time the crate opens
    if #crateItems(id) == 0 then
        pcall(function() exports.vorp_inventory:deleteCustomInventory(id) end)
    end
    pcall(function() exports.vorp_inventory:removeInventory(id) end)

    if gross <= 0 then return S.tip(src, L('crateJunk'), 6000) end

    local rate = math.min(1.0, state.rate * S.perkMult(src, P.fenceCut))
    local level = nil
    local r = nil
    if F.reputation.enabled then
        r = loadRep(cid)
        level = repLevel(r.rep)
        rate = 1 - (1 - rate) * level.keeps
    end
    local payout = math.max(1, math.floor(gross * rate))
    local readyAt = os.time() + F.buyer.payoutMinutes * 60
    DB.update('INSERT INTO robbery_fence_payouts (charidentifier, amount, readyAt, mailed) VALUES (?, ?, ?, 0) ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount), readyAt = VALUES(readyAt), mailed = 0',
        { cid, payout, readyAt })
    S.tip(src, L('saleDone'), 7000)
    S.award(src, P.xpFence)
    state.sellers[cid] = true

    if r then
        local gain = math.max(F.reputation.minPerSale, math.floor(gross * F.reputation.perDollar))
        DB.update('INSERT INTO robbery_fence_rep (charidentifier, rep, sales, value) VALUES (?, ?, 1, ?) ON DUPLICATE KEY UPDATE rep = rep + VALUES(rep), sales = sales + 1, value = value + VALUES(value)',
            { cid, gain, gross })
        r.rep, r.sales, r.value = r.rep + gain, r.sales + 1, r.value + gross
        local after = repLevel(r.rep)
        if after ~= level then S.tip(src, L('repLevel', after.name), 7000) end
    end

    local lines = {}
    for _, lot in ipairs(sold) do lines[#lines + 1] = ('%s ×%d = $%d'):format(Logs.clean(lot.name), lot.amount, lot.price * lot.amount) end
    for _, lot in ipairs(returned) do lines[#lines + 1] = ('~~%s ×%d~~'):format(Logs.clean(lot.name), lot.amount) end
    local s = stopDef(state.stop)
    Logs.send('Fence - goods taken in', Logs.GREEN, ('%s\n\n**Lots**\n%s\n\n**Deal:** gross $%d, rate %d%%, payout $%d\n**Standing:** %s (%s rep)\n**Fence:** %s, %s\n**Ready in:** %d min'):format(
        Logs.robber(src), table.concat(lines, '\n'), gross, U.round(rate * 100), payout,
        level and level.name or '-', r and tostring(r.rep) or '-', s and s.label or '?', s and s.region or '?', F.buyer.payoutMinutes))

    SetTimeout(F.buyer.tipDelayMs, function()
        if S.online(src) then saleTip(src, readyAt) end
    end)
end

RegisterNetEvent('pup_robbery:fence:offer', function()
    local src = source
    if not S.rate(src, 'fenceOffer', 2000) or not F.buyer.enabled then return end
    local cid = S.charId(src)
    if not cid then return end
    if busy[cid] then return S.tip(src, L('busy')) end
    if not atFence(src) then return end
    busy[cid] = true
    local ok, err = pcall(sell, src, cid)
    busy[cid] = nil
    if not ok then S.warn('sale failed: %s', tostring(err)) end
end)

--------------------------------------------------------------------------------
-- collecting

RegisterNetEvent('pup_robbery:fence:collect', function()
    local src = source
    if not S.rate(src, 'fenceCollect', 2000) or not F.buyer.enabled then return end
    local cid = S.charId(src)
    if not cid then return end
    if busy[cid] then return S.tip(src, L('busy')) end
    if not atFence(src) then return end
    busy[cid] = true
    local row = DB.single('SELECT amount, readyAt FROM robbery_fence_payouts WHERE charidentifier = ?', { cid })
    if not row or (tonumber(row.amount) or 0) <= 0 then
        busy[cid] = nil
        return S.tip(src, L('noMoney'))
    end
    if (tonumber(row.readyAt) or 0) > os.time() then
        busy[cid] = nil
        return S.tip(src, L('notReady'))
    end
    local amount = tonumber(row.amount)
    if S.charId(src) ~= cid then
        busy[cid] = nil
        return
    end
    local gone = DB.update('DELETE FROM robbery_fence_payouts WHERE charidentifier = ? AND amount = ?', { cid, amount })
    if gone == 1 then
        if S.charId(src) == cid and S.addCash(src, amount, 0) then
            S.tip(src, L('paid', amount), 6000)
            Logs.send('Fence - payout collected', Logs.GOLD, ('%s\n\n**Amount:** $%d'):format(Logs.robber(src), amount))
        else
            -- the character changed (or left) while the row was being taken: put the money back
            DB.update('INSERT INTO robbery_fence_payouts (charidentifier, amount, readyAt, mailed) VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)',
                { cid, amount, os.time() })
        end
    end
    busy[cid] = nil
end)

-- payout letters
CreateThread(function()
    while true do
        Wait(F.buyer.sweepSeconds * 1000)
        if F.buyer.enabled and DB.ready then
            local rows = DB.query('SELECT charidentifier, amount FROM robbery_fence_payouts WHERE mailed = 0 AND readyAt <= ?', { os.time() }) or {}
            for _, r in ipairs(rows) do
                local n = DB.update('UPDATE robbery_fence_payouts SET mailed = 1 WHERE charidentifier = ? AND mailed = 0', { r.charidentifier })
                if n == 1 then
                    Fence.letter(r.charidentifier, F.letters.payoutSubject, L('payoutLetter', tonumber(r.amount) or 0))
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- letters straight into pup_postoffice's tables

local function isoNow()
    local ms = GetGameTimer() % 1000
    return os.date('!%Y-%m-%dT%H:%M:%S') .. ('.%03dZ'):format(ms)
end

function Fence.letter(charid, subject, body)
    charid = tonumber(charid)
    if not charid then return false end
    local row = DB.single('SELECT address FROM mail WHERE charidentifier = ? LIMIT 1', { charid })
    if not row or not row.address then return false end
    local box = tostring(row.address)
    local date = isoNow()
    local id = DB.insert('INSERT INTO mails (anon, `read`, `from`, `to`, subject, body, folder, fromName, toNames, `date`, hidesent, copyTo) VALUES (1, 0, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)',
        { '0', json.encode({ box }), subject, body, 'Inbox', F.letters.from, '[]', date, box })
    if not id then return false end
    local src = S.srcForChar(charid)
    if src then
        TriggerClientEvent('pup_postoffice:rec_addedMailid', src, {
            id = id, anon = 1, read = 0, from = '0', to = { box }, subject = subject, body = body, folder = 'Inbox',
            fromName = F.letters.from, toNames = {}, date = date, hidesent = 0, copyTo = box,
        }, true)
    end
    return true
end

--------------------------------------------------------------------------------
-- rumours from pup_hideouts' drug sales

AddEventHandler('pup_hideouts:drugsale_log', function(seller, _, _, _, how)
    if not F.rumours.enabled or how == 'sting' then return end
    seller = tonumber(seller)
    if not seller or not S.online(seller) then return end
    local now = os.time()
    if rumourCd[seller] and now - rumourCd[seller] < F.rumours.cooldownMinutes * 60 then return end
    rumourCd[seller] = now
    local chance = F.rumours.chance + S.perkBonus(seller, P.fenceWord)
    if math.random(1, 100) > chance then return end
    local region, label = nextNames()
    local text
    if S.perkRank(seller, P.streetword) >= F.rumours.landmarkRank then
        text = U.fill(F.rumours.landmarkLines[math.random(1, #F.rumours.landmarkLines)], { label = label })
    else
        text = U.fill(F.rumours.regionLines[math.random(1, #F.rumours.regionLines)], { region = region })
    end
    S.tip(seller, text, F.rumours.showMs)
end)

--------------------------------------------------------------------------------
-- admin

function Fence.face(src, heading)
    state.heading = (tonumber(heading) or 0) % 360
    TriggerClientEvent('pup_robbery:fence:spot', -1, clientSpot())
    S.tip(src, L('fenceFaced', state.heading), 8000)
    print(('[pup_robbery] fence heading at stop %d: %.2f'):format(state.stop or 0, state.heading))
end

function Fence.rateNow() return state.rate end

--------------------------------------------------------------------------------
-- life cycle

CreateThread(function()
    Fence.move()
    Wait(F.stall.pushDelayMs)
    pushStall()
    TriggerClientEvent('pup_robbery:fence:spot', -1, clientSpot())
    while true do
        Wait(30000)
        if os.time() >= state.moveAt then Fence.move() end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'pup_mercantile' then SetTimeout(1000, pushStall) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local cid = repOwner[src] or S.charId(src)
    if cid then repCache[cid] = nil end
    repOwner[src] = nil
    rumourCd[src] = nil
end)

exports('FenceKnowsYou', function(src)
    src = tonumber(src)
    if not src then return false end
    return Fence.knows(src)
end)

exports('FenceSpot', function()
    return Fence.spot()
end)
