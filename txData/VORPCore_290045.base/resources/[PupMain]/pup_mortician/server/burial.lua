-- pup_mortician | the undertaker's work: laying out, goods, closing, burying,
-- graveyard burials and the settlement that pays for them.

local D = Config.Distance
Actions = Actions or {}

local function fail(key, ...) return { ok = false, msg = L(key, ...) } end
local function okMsg(key, ...) return { ok = true, msg = L(key, ...) } end

-- a dead, non-player ped within reach of the player, or nil
local function checkCorpse(src, net)
    net = tonumber(net)
    if not net then return nil end
    local ent = NetworkGetEntityFromNetworkId(net)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return nil end
    if GetEntityHealth(ent) > 0 then return nil end
    local pos = PlayerPos(src)
    if not pos or #(GetEntityCoords(ent) - pos) > D.corpse then return nil end
    return ent
end

---------------------------------------------------------------------------
-- Settlement (both burial kinds)
---------------------------------------------------------------------------
local function ledgerRowExists(job)
    if not Config.HouseCut.verifyLedgerRow then return true end
    local ok, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM society_ledger WHERE job = ?', { job })
    return ok and (tonumber(n) or 0) > 0
end

-- the cut only counts as banked when the business can hold it; otherwise the undertaker gets it
local function depositHouse(job, amount, who)
    if not Started('pup_business') then return false, 'pup_business not running' end
    if not ledgerRowExists(job) then return false, 'no society_ledger row' end
    local ok, res, why = pcall(function() return exports.pup_business:AddToLedger(job, amount, 'Burial', who) end)
    if not ok then return false, tostring(res) end
    if res ~= true then return false, tostring(why or 'refused') end
    return true
end

local function payPlayer(ctx, amount)
    if amount <= 0 then return true end
    local now = StillSame(ctx)
    if not now then
        Warn(('could not pay $%d to char %s: no longer online'):format(amount, tostring(ctx.charId)))
        return false
    end
    now.char.addCurrency(0, amount)
    return true
end

-- info = { gross, kind = 'casket'|'grave', place, deceased, cause, goods = {labels} }
-- the burial slot is already reserved by the caller
local function settle(ctx, info)
    local job = ctx.job
    local wanted = 0
    if Config.HouseCut.enabled and Config.Tables[job]
        and not (Config.HouseCut.bossesKeepAll and IsBossOf(ctx.src, job)) then
        wanted = math.floor(info.gross * CutOf(job) / 100)
    end

    -- the undertaker's share first, so nothing can stall it
    local kept = info.gross - wanted
    payPlayer(ctx, kept)

    local house = 0
    if wanted > 0 then
        local banked, why = depositHouse(job, wanted, ctx.name)
        if banked then
            house = wanted
        else
            Warn(('house cut of $%d for %s not banked (%s); paid to the undertaker instead'):format(wanted, job, why or '?'))
            payPlayer(ctx, wanted)
            kept = kept + wanted
        end
    end

    PerkAward(ctx.src, 'undertaker')

    local goodsText = table.concat(info.goods or {}, ', ')
    WriteRegister({
        job = job, charid = ctx.charId, undertaker = ctx.name, deceased = info.deceased, cause = info.cause,
        place = info.place, kind = info.kind, goods = goodsText, paid = kept, house = house,
    })

    local left = BurialsLeft(ctx.charId)
    local isCasket = info.kind == 'casket'
    local fields = {
        { 'Deceased', info.deceased },
        { 'Location', info.place },
        { 'Payment', ('$%d'):format(kept) },
    }
    if house > 0 then fields[#fields + 1] = { 'House cut', ('$%d'):format(house) } end
    fields[#fields + 1] = { 'Job', job }
    if goodsText ~= '' then fields[#fields + 1] = { 'Laid in', goodsText, false } end
    fields[#fields + 1] = { 'Burials left', left }
    StaffLog(ctx, isCasket and 'Casket Buried' or 'Body Buried',
        isCasket and 'A player buried a prepared casket.' or 'A player buried a body.', fields, Colors.green)

    local hook = WebhookOf(job)
    if hook then
        BusinessReport(hook, 'Burial', ('A burial at %s.'):format(job), {
            { 'Undertaker', ctx.name },
            { 'Deceased', info.deceased },
            { 'Kept', ('$%d'):format(kept) },
            { 'House cut', ('$%d'):format(house) },
            { 'Laid in', goodsText ~= '' and goodsText or 'nothing', false },
            { 'Burials left', left },
        }, Colors.green)
    end

    local msg = L('laidToRest', info.deceased, kept)
    if house > 0 then msg = msg .. L('toHouse', house) end
    return msg
end

---------------------------------------------------------------------------
-- Lay the body down
---------------------------------------------------------------------------
Actions.lay = function(ctx, p)
    local key = ValidTableKey(p.key)
    if not key or not Rules.CanWorkTable(ctx.job, key) then return fail('notYourTable') end
    local tablePos = Config.Tables[key].pos
    if DistTo(ctx.src, tablePos) > D.tableServer then return fail('tooFar') end

    -- the only wait comes first; nothing yields after it, so two requests cannot both see the table empty
    BurialsLeft(ctx.charId)
    local now = StillSame(ctx)
    if not now or not Rules.CanWorkTable(now.job, key) then return fail('notYourTable') end
    if DistTo(ctx.src, tablePos) > D.tableServer then return fail('tooFar') end
    ExpireCheck(key)
    local t = Tables[key]
    if t.casket then return fail('tableBusy') end
    if BurialsLeft(ctx.charId) <= 0 then return fail('noBurialsLeft') end -- loaded: answers from memory

    local ent = checkCorpse(ctx.src, p.net)
    if not ent then return fail('notCarrying') end
    local contract = ContractBodyOf(ctx.charId, ent)
    if Config.Contracts.bodiesOnly and not contract then return fail('contractOnly') end

    DeleteEntity(ent)
    t.casket = NewCasket(now, contract)
    if contract then DeliverContractBody(contract, ent) end
    BroadcastTable(key)
    return okMsg('laidOnTable')
end

---------------------------------------------------------------------------
-- Lay in goods
---------------------------------------------------------------------------
Actions.layin = function(ctx, p)
    local key = ValidTableKey(p.key)
    if not key then return fail('noOpenCasket') end
    ExpireCheck(key)
    local c = Tables[key].casket
    if not c or c.closed then return fail('noOpenCasket') end
    if c.owner ~= ctx.charId then return fail('notYoursTend') end
    if DistTo(ctx.src, Config.Tables[key].pos) > D.tableServer then return fail('tooFar') end

    local wantedSet = {}
    for _, idx in ipairs(c.wanted) do wantedSet[idx] = true end

    local added, missing, seen = {}, {}, {}
    local list = type(p.goods) == 'table' and p.goods or {}
    for i = 1, math.min(#list, #Config.Goods) do
        local n = tonumber(list[i])
        local idx = n and math.tointeger(n)
        if idx and not seen[idx] and wantedSet[idx] and not c.laid[idx] and Config.Goods[idx] then
            seen[idx] = true
            local good = Config.Goods[idx]
            if ItemCount(ctx.src, good.item) >= good.amount then
                local okSub, removed = pcall(function() return Inv:subItem(ctx.src, good.item, good.amount) end)
                if okSub and removed then
                    if Tables[key].casket ~= c or c.closed then
                        -- the casket went away while the item was being taken: give it back and stop
                        pcall(function() Inv:addItem(ctx.src, good.item, good.amount) end)
                        return fail('noOpenCasket')
                    end
                    c.laid[idx] = true
                    added[#added + 1] = good.label
                else
                    missing[#missing + 1] = good.label
                end
            else
                missing[#missing + 1] = good.label
            end
        end
    end

    if #added == 0 then
        if #missing > 0 then return fail('missingGoods', table.concat(missing, ', ')) end
        return fail('nothingLeft')
    end

    c.lastActive = os.time()
    BroadcastTable(key)
    local one = #added == 1
    StaffLog(ctx, one and 'Burial Item Added' or 'Burial Items Added',
        one and 'A player added an item to a casket.' or 'A player filled a casket in one go.',
        { { 'Location', key }, { 'Items', #added }, { 'Added', table.concat(added, ', '), false } }, Colors.blue)
    local res = okMsg('goodsLaid', table.concat(added, ', '))
    res.count = #added
    return res
end

---------------------------------------------------------------------------
-- Close the casket
---------------------------------------------------------------------------
Actions.close = function(ctx, p)
    local key = ValidTableKey(p.key)
    if not key then return fail('noOpenCasket') end
    ExpireCheck(key)
    local c = Tables[key].casket
    if not c or c.closed then return fail('noOpenCasket') end
    if c.owner ~= ctx.charId then return fail('notYoursTend') end
    if DistTo(ctx.src, Config.Tables[key].pos) > D.tableServer then return fail('tooFar') end
    c.closed = true
    c.lastActive = os.time()
    BroadcastTable(key)
    return okMsg('casketClosed')
end

---------------------------------------------------------------------------
-- Bury the casket
---------------------------------------------------------------------------
Actions.bury = function(ctx, p)
    local key = ValidTableKey(p.key)
    if not key then return fail('noClosedCasket') end

    -- the only wait comes first; nothing yields after it, so one casket is buried and paid once
    BurialsLeft(ctx.charId)
    local now = StillSame(ctx)
    if not now then return { ok = false, quiet = true } end

    ExpireCheck(key)
    local t = Tables[key]
    local c = t.casket
    if not c or not c.closed then return fail('noClosedCasket') end
    if c.owner ~= ctx.charId then return fail('notYoursBury') end
    local site = Config.Tables[key].burial
    if DistTo(ctx.src, site) > D.burialServer then return fail('tooFar') end
    if not HasShovel(ctx.src) then return fail('needShovel') end
    if not LimitReserve(ctx.charId) then return fail('noBurialsLeft') end

    -- claim: the casket leaves the table before any money moves
    t.casket = nil
    BroadcastTable(key)

    local gross = Config.Pay.casketBase
    for _, idx in ipairs(c.wanted) do
        if c.laid[idx] then gross = gross + (Config.Goods[idx].bonus or 0) end
    end
    if c.contractId then gross = gross + Config.Contracts.bonusPerBody end

    if Config.Shovel.wearOnBurial then WearShovel(ctx.src) end

    local msg = settle(now, {
        gross = gross, kind = 'casket', place = Config.Tables[key].town,
        deceased = c.deceased, cause = c.cause, goods = GoodLabels(c),
    })

    if c.contractId and math.random(1, 100) <= Config.Contracts.keepsakeChance then
        local k = Config.Contracts.keepsakes[math.random(1, #Config.Contracts.keepsakes)]
        local okCarry, can = pcall(function() return Inv:canCarryItem(ctx.src, k.item, k.amount) end)
        if okCarry and can then
            local okAdd, added = pcall(function() return Inv:addItem(ctx.src, k.item, k.amount) end)
            if okAdd and added then msg = msg .. L('keepsake', k.label, k.amount) end
        end
    end
    return { ok = true, msg = msg }
end

---------------------------------------------------------------------------
-- Graveyard burial
---------------------------------------------------------------------------
Actions.grave = function(ctx, p)
    local id = type(p.id) == 'string' and p.id or nil
    local yard = id and Config.Graveyards[id]
    if not yard or not Rules.IsUndertaker(ctx.job) then return fail('notUndertaker') end
    if DistTo(ctx.src, yard) > D.graveServer then return fail('tooFar') end
    if not HasShovel(ctx.src) then return fail('needShovel') end

    local left = BurialsLeft(ctx.charId)
    local now = StillSame(ctx)
    if not now or not Rules.IsUndertaker(now.job) then return fail('notUndertaker') end
    if left <= 0 then return fail('noBurialsLeft') end
    if DistTo(ctx.src, yard) > D.graveServer then return fail('tooFar') end

    -- from here to the deletion nothing waits, so one corpse is buried once
    local ent = checkCorpse(ctx.src, p.net)
    if not ent then return fail('notCarrying') end
    if not LimitReserve(ctx.charId) then return fail('noBurialsLeft') end
    local contract = ContractBodyOf(ctx.charId, ent)
    DeleteEntity(ent)
    if contract then DeliverContractBody(contract, ent) end

    if Config.Shovel.wearOnBurial then WearShovel(ctx.src) end

    local gross = Config.Pay.graveyard + (contract and Config.Contracts.bonusPerBody or 0)
    local msg = settle(now, {
        gross = gross, kind = 'grave', place = id,
        deceased = contract and contract.name or L('unknownSoul'),
        cause = contract and contract.cause or '', goods = {},
    })
    return { ok = true, msg = msg }
end
