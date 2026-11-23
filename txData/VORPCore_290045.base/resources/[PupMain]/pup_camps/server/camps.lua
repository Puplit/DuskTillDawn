-- pup_camps | founding, menu lock, ledger, members, invites, name/blip, relocation, disband

Invites = {}  -- [charid] = { [campId] = expiresAt }

local function wholeAmount(v)
    local n = tonumber(v)
    if not n or n ~= n or n < 1 or n > 1000000000 or n ~= math.floor(n) then return nil end
    return math.floor(n)
end
WholeAmount = wholeAmount

local function inRegion(pos)
    local lock = Config.Camp.regionLock
    if not lock or #lock == 0 then return true end
    for _, r in ipairs(lock) do
        local radius = tonumber(r.radius) or Config.Camp.regionDefaultRadius
        if U.dist3(pos, r) <= radius then return true end
    end
    return false
end
InRegion = inRegion

local function spacingOk(pos, ignoreId)
    for id, camp in pairs(Camps) do
        if id ~= ignoreId and U.dist2(pos, camp.coords) < Config.Camp.spacing then return false end
    end
    return true
end
SpacingOk = spacingOk

local function validPos(p)
    if type(p) ~= 'table' then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not x or not y or not z then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    return { x = x, y = y, z = z }
end
ValidPos = validPos

------------------------------------------------------------------------------ founding

local founding = {}  -- [charid] = true while a create is in flight

exports.vorp_inventory:registerUsableItem(Config.Camp.flagItem, function(data)
    local src = data.source
    local ctx = Ctx(src)
    if not ctx then return end
    TriggerClientEvent('vorp_inventory:CloseInv', src)
    local list = {}
    for id, camp in pairs(Camps) do list[#list + 1] = { id = id, coords = camp.coords } end
    TriggerClientEvent('pup_camps:cl:found', src, list)
end, GetCurrentResourceName())

Handle('found', function(ctx, pos, name)
    pos = validPos(pos)
    if not pos then return false end
    if ctx.camp then return false, L('found_in_camp') end
    if founding[ctx.charid] then return false end
    if (tonumber(exports.vorp_inventory:getItemCount(ctx.src, nil, Config.Camp.flagItem)) or 0) < 1 then
        return false, L('found_need_flag')
    end
    if not NearPoint(ctx.src, pos, Config.Camp.claimDistance) then return false, L('too_far') end
    if not spacingOk(pos) then return false, L('found_other_camp') end
    if not inRegion(pos) then return false, L('found_region') end

    name = U.trim(type(name) == 'string' and name or '')
    if name == '' then name = Config.Camp.defaultName end
    name = name:sub(1, Config.Camp.nameMax)

    founding[ctx.charid] = true
    local ok, res, msg = pcall(function()
        if not exports.vorp_inventory:subItem(ctx.src, Config.Camp.flagItem, 1) then
            return false, L('found_need_flag')
        end
        local flag = {
            id = 1, item = Config.Camp.flagItem, prop = GetHashKey(Config.Camp.flagProp), label = L('flag'),
            cata = 'prop', functional = 'none', active = true, grounded = true,
            coords = { x = pos.x, y = pos.y, z = pos.z }, heading = 0.0,
        }
        local info = {
            name = name, bcolor = 1, leader = ctx.charid,
            members = { { name = ctx.name, charid = ctx.charid, rank = Config.Ranks[1].id } },
            coords = pos, furni = { ['1'] = flag },
            raid = 0, lifecycle = 0, stewlevel = 0, material = 0, stock = 0,
            maxstock = Config.Economy.stockCap, supply = 0, hwagon = 0,
        }
        local id = NewCampRow(json.encode(info))
        if not id or id == 0 then
            exports.vorp_inventory:addItem(ctx.src, Config.Camp.flagItem, 1)
            return false, L('found_failed')
        end
        -- re-check after the awaits: did this character join somewhere meanwhile?
        if CampOfChar(ctx.charid, ctx.identifier) or not spacingOk(pos) then
            DeleteCampRow(id)
            exports.vorp_inventory:addItem(ctx.src, Config.Camp.flagItem, 1)
            return false, L('found_failed')
        end
        local camp = ReadCamp({ id = id, info = json.encode(info), cash = '0', inventory = '[]', invlimit = 0, repo = 0, taxmoney = 0 })
        Camps[id] = camp
        RecomputeStorage(camp)
        SetCharClan(ctx.charid, id)
        Save(camp)
        Notify(ctx.src, L('found_done', camp.name))
        CampLog(camp, 'camp', 'Camp Created', LogColour.green, {
            { 'Founder', Who(ctx.src, camp) },
            { 'Name', camp.name, true },
            { 'Location', ('%.1f, %.1f, %.1f'):format(pos.x, pos.y, pos.z), true },
        }, { actor = ctx.src })
        PushCamp(camp, true)
        PushMyCamp(ctx.src)
        return true
    end)
    founding[ctx.charid] = nil
    if not ok then
        print('^1[pup_camps]^7 founding failed: ' .. tostring(res))
        return false, L('found_failed')
    end
    return res, msg
end, { gapMs = 2000 })

------------------------------------------------------------------------------ menu lock

Handle('lock', function(ctx, campId)
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return false end
    local rank, leader = RankOf(camp, ctx.charid, ctx.identifier)
    local member = rank ~= nil or leader
    if not member and not LootAllowed(camp, ctx.src, ctx.charid) then return false end
    if not AtCamp(ctx.src, camp) then return false, L('too_far') end
    if not LockFree(camp.id, ctx.src) then return false, L('menu_in_use') end
    MenuLocks[camp.id] = ctx.src
    return true
end)

Handle('unlock', function(ctx, campId)
    local id = tonumber(campId)
    if id and MenuLocks[id] == ctx.src then MenuLocks[id] = nil end
    return true
end)

-- what an outsider standing at a flag may see
Handle('outsider', function(ctx, campId)
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return nil end
    local open = LootAllowed(camp, ctx.src, ctx.charid)
    return {
        cooldown = Config.Raids.cooldownStarts > 0 and camp.raid > 0,
        open = open,
        cash = open and camp.cash or nil,
        running = RaidRuns and RaidRuns[camp.id] ~= nil or false,
    }
end)

------------------------------------------------------------------------------ ledger

Handle('withdraw', function(ctx, campId, amount)
    local n = wholeAmount(amount)
    if not n then return false, L('invalid_amount') end
    local camp, why = Can(ctx, campId, 'withdraw')
    if not camp then return false, why end
    if camp.cash < n then return false, L('not_enough_safe') end
    camp.cash = U.round(camp.cash - n, 2)
    if not GiveCash(ctx, n) then
        camp.cash = U.round(camp.cash + n, 2)
        return false
    end
    Save(camp)
    Notify(ctx.src, L('withdrew', U.money(n)))
    CampLog(camp, 'money', 'Safe Withdrawal', LogColour.red, {
        { 'Who', Who(ctx.src, camp) }, { 'Amount', U.money(n), true }, { 'Safe', U.money(camp.cash), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 500 })

Handle('deposit', function(ctx, campId, amount)
    local n = wholeAmount(amount)
    if not n then return false, L('invalid_amount') end
    local camp, why = Can(ctx, campId, 'deposit')
    if not camp then return false, why end
    if not TakeCash(ctx, n) then return false, L('not_enough_cash') end
    camp.cash = U.round(camp.cash + n, 2)
    Save(camp)
    Notify(ctx.src, L('deposited', U.money(n)))
    CampLog(camp, 'money', 'Safe Deposit', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Amount', U.money(n), true }, { 'Safe', U.money(camp.cash), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 500 })

Handle('tax', function(ctx, campId, amount)
    local n = wholeAmount(amount)
    if not n then return false, L('invalid_amount') end
    local target = Camps[tonumber(campId) or -1]
    local camp, why = Can(ctx, campId, 'tax', { allowRepo = true, noDistance = target and target.repo })
    if not camp then return false, why end
    if camp.taxmoney + n > Config.Tax.ledgerCap then return false, L('tax_cap', U.money(Config.Tax.ledgerCap)) end
    if not TakeCash(ctx, n) then return false, L('not_enough_cash') end
    camp.taxmoney = camp.taxmoney + n
    Save(camp)
    Notify(ctx.src, L('tax_paid', U.money(camp.taxmoney)))
    if camp.repo then Notify(ctx.src, L('debt_noted'), 8000) end
    CampLog(camp, 'money', 'Tax Ledger Deposit', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Amount', U.money(n), true },
        { 'Ledger', ('%s / %s'):format(U.money(camp.taxmoney), U.money(Config.Tax.ledgerCap)), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 500 })

-- paid in one step on the server (no client claim), so a disconnect cannot lose it
Handle('takeAll', function(ctx, campId)
    local camp, why = Can(ctx, campId, 'takeAll')
    if not camp then return false, why end
    local amount = math.floor(camp.cash)
    if amount <= 0 then return false, L('nothing_to_take') end
    camp.cash = U.round(camp.cash - amount, 2)
    if not GiveCash(ctx, amount) then
        camp.cash = U.round(camp.cash + amount, 2)
        return false
    end
    Save(camp)
    Notify(ctx.src, L('took_all', U.money(amount)))
    CampLog(camp, 'money', 'Safe Emptied', LogColour.red, {
        { 'Who', Who(ctx.src, camp) }, { 'Amount', U.money(amount), true }, { 'Safe', U.money(camp.cash), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 1000 })

------------------------------------------------------------------------------ members

local function rosterText(camp)
    local names = {}
    for _, m in ipairs(camp.members) do names[#names + 1] = ('%s (%s)'):format(m.name, tostring(m.charid)) end
    return Clip(table.concat(names, ', '), 1000)
end

Handle('invite', function(ctx, campId, target)
    local camp, why = Can(ctx, campId, 'invite')
    if not camp then return false, why end
    if CampFull(camp) then return false, L('camp_full', Config.Camp.maxMembers) end
    target = tonumber(target)
    if not target or target == ctx.src or not GetPlayerName(target) then return false, L('player_offline') end
    local tctx = Ctx(target)
    if not tctx then return false, L('player_offline') end
    if tctx.camp then return false, L('already_in_camp', tctx.name) end
    Invites[tctx.charid] = Invites[tctx.charid] or {}
    Invites[tctx.charid][camp.id] = os.time() + Config.Invites.hours * 3600
    TriggerClientEvent('pup_camps:cl:invite', target, camp.id, camp.name)
    Notify(target, L('invite_got', camp.name, Config.Commands.invites), 10000)
    Notify(ctx.src, L('invite_sent', tctx.name))
    CampLog(camp, 'members', 'Invite Sent', LogColour.blue, {
        { 'By', Who(ctx.src, camp) }, { 'Invited', ('%s (char %d)'):format(tctx.name, tctx.charid) },
    }, { actor = ctx.src })
    return true
end, { gapMs = 1000 })

Handle('acceptInvite', function(ctx, campId)
    campId = tonumber(campId)
    if ctx.camp then return false, L('you_in_camp') end
    local mine = Invites[ctx.charid]
    local exp = mine and campId and mine[campId]
    if not exp or exp < os.time() then
        if mine and campId then mine[campId] = nil end
        return false, L('invite_invalid')
    end
    local camp = Camps[campId]
    if not camp or camp.repo then mine[campId] = nil return false, L('invite_invalid') end
    if CampFull(camp) then return false, L('camp_full', Config.Camp.maxMembers) end
    mine[campId] = nil
    camp.members[#camp.members + 1] = { name = ctx.name, charid = ctx.charid, rank = Config.Ranks[1].id }
    SetCharClan(ctx.charid, camp.id)
    Save(camp)
    for _, s in ipairs(OnlineMembers(camp)) do
        if s ~= ctx.src then Notify(s, L('joined_other', ctx.name)) end
    end
    Notify(ctx.src, L('joined_you', camp.name))
    CampLog(camp, 'members', 'Member Joined', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Roster size', tostring(#camp.members), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    PushMyCamp(ctx.src)
    return true
end, { gapMs = 1000 })

local function removeMember(camp, index)
    local m = table.remove(camp.members, index)
    if m and tonumber(m.charid) then SetCharClan(m.charid, 0) end
    return m
end

Handle('kick', function(ctx, campId, targetCharid)
    local camp, why = Can(ctx, campId, 'kick')
    if not camp then return false, why end
    targetCharid = tonumber(targetCharid)
    local idx, target = FindMember(camp, targetCharid)
    if not idx then return false, L('rank_not_in_camp') end
    if IsLeader(camp, targetCharid) then return false, L('kick_leader') end
    local myRank, iLead = RankOf(camp, ctx.charid, ctx.identifier)
    if not iLead then
        local theirs = U.validRank(target.rank) and target.rank or Config.Ranks[1].id
        if U.rankIndex(theirs) >= U.rankIndex(myRank) then return false, L('kick_rank') end
    end
    removeMember(camp, idx)
    Save(camp)
    local tsrc = SrcOfChar(targetCharid)
    if tsrc then
        Notify(tsrc, L('kicked_you', camp.name))
        PushMyCamp(tsrc)
        ReleaseLocksOf(tsrc)
    end
    Notify(ctx.src, L('kicked_done', target.name))
    CampLog(camp, 'members', 'Member Removed', LogColour.red, {
        { 'By', Who(ctx.src, camp) },
        { 'Removed', ('%s (char %s, %s)'):format(target.name, tostring(target.charid), U.rankLabel(target.rank)) },
        { 'Roster', rosterText(camp) },
    }, { actor = ctx.src })
    OnMembershipLost(targetCharid, camp.id)
    PushCamp(camp)
    return true
end, { gapMs = 1000 })

Handle('setRank', function(ctx, campId, targetCharid, rankId)
    local camp, why = Can(ctx, campId, 'setRank')
    if not camp then return false, why end
    targetCharid = tonumber(targetCharid)
    if IsLeader(camp, targetCharid) then return false, L('rank_leader') end
    if type(rankId) ~= 'string' or not U.validRank(rankId) then return false, L('rank_invalid') end
    local idx, target = FindMember(camp, targetCharid)
    if not idx then return false, L('rank_not_in_camp') end
    local myRank, iLead = RankOf(camp, ctx.charid, ctx.identifier)
    if not iLead and U.rankIndex(rankId) >= U.rankIndex(myRank) then return false, L('rank_grant_high') end
    local old = target.rank
    target.rank = rankId
    Save(camp)
    local tsrc = SrcOfChar(targetCharid)
    if tsrc then Notify(tsrc, L('rank_yours', U.rankLabel(rankId))) end
    StashPrune(camp.id)  -- a demotion below the stash rank closes their open panel
    Notify(ctx.src, L('rank_now', target.name, U.rankLabel(rankId)))
    CampLog(camp, 'members', 'Rank Changed', LogColour.blue, {
        { 'By', Who(ctx.src, camp) }, { 'Member', ('%s (char %s)'):format(target.name, tostring(target.charid)) },
        { 'Rank', ('%s -> %s'):format(U.rankLabel(old), U.rankLabel(rankId)), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 500 })

Handle('transfer', function(ctx, campId, targetCharid)
    local camp, why = Can(ctx, campId, 'transfer')
    if not camp then return false, why end
    targetCharid = tonumber(targetCharid)
    if not targetCharid or targetCharid == ctx.charid then return false, L('rank_not_in_camp') end
    local idx, target = FindMember(camp, targetCharid)
    if not idx then return false, L('rank_not_in_camp') end
    camp.leader = targetCharid
    Save(camp)
    Notify(ctx.src, L('leadership_moved', target.name))
    local tsrc = SrcOfChar(targetCharid)
    if tsrc then Notify(tsrc, L('leadership_yours', camp.name)) end
    CampLog(camp, 'members', 'Leadership Transferred', LogColour.orange, {
        { 'Handed over by', Who(ctx.src, camp) },
        { 'New leader', ('%s (char %d)'):format(target.name, targetCharid) },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 1000 })

Handle('leave', function(ctx, campId)
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return false end
    local idx = FindMember(camp, ctx.charid, ctx.identifier)
    if IsLeader(camp, ctx.charid) then return false, L('leave_leader') end
    if not idx then return false, L('not_member') end
    if camp.repo then return false, L('camp_shut') end
    removeMember(camp, idx)
    Save(camp)
    ReleaseLocksOf(ctx.src)
    Notify(ctx.src, L('left_done'))
    CampLog(camp, 'members', 'Member Left', LogColour.orange, {
        { 'Who', Who(ctx.src, nil) }, { 'Roster size', tostring(#camp.members), true },
    }, { actor = ctx.src, system = true })
    OnMembershipLost(ctx.charid, camp.id)
    PushCamp(camp)
    PushMyCamp(ctx.src)
    return true
end, { gapMs = 1000 })

------------------------------------------------------------------------------ name & blip

Handle('blipSave', function(ctx, campId, name, colour)
    local camp, why = Can(ctx, campId, 'blip')
    if not camp then return false, why end
    colour = math.floor(tonumber(colour) or camp.bcolor)
    if colour < 1 or colour > Config.Camp.blipColours then colour = camp.bcolor end
    name = U.trim(type(name) == 'string' and name or '')
    if name == '' then name = camp.name end
    name = name:sub(1, Config.Camp.nameMax)
    local paid = PayFromSafeOrPlayer(ctx, camp, Config.Camp.blipPrice)
    if not paid then return false, L('not_enough_cash') end
    local oldName = camp.name
    camp.name, camp.bcolor = name, colour
    Save(camp)
    Notify(ctx.src, L('blip_saved'))
    CampLog(camp, 'camp', 'Camp Blip Changed', LogColour.blue, {
        { 'By', Who(ctx.src, camp) }, { 'Name', ('%s -> %s'):format(oldName, name) },
        { 'Colour', tostring(colour), true }, { 'Cost', U.money(Config.Camp.blipPrice) .. (paid == 'safe' and ' (safe)' or ' (own pocket)'), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 1500 })

------------------------------------------------------------------------------ relocation

Handle('relocateCheck', function(ctx, campId)
    local camp, why = Can(ctx, campId, 'relocate')
    if not camp then return false, why end
    if camp.cash < Config.Camp.relocatePrice and Money(ctx) < Config.Camp.relocatePrice then
        return false, L('not_enough_cash')
    end
    return true
end)

Handle('relocate', function(ctx, campId, pos)
    pos = validPos(pos)
    if not pos then return false end
    local camp, why = Can(ctx, campId, 'relocate', { noDistance = true })
    if not camp then return false, why end
    if not NearPoint(ctx.src, pos, Config.Camp.claimDistance) then return false, L('too_far') end
    if not spacingOk(pos, camp.id) then return false, L('found_other_camp') end
    if not inRegion(pos) then return false, L('found_region') end
    local paid = PayFromSafeOrPlayer(ctx, camp, Config.Camp.relocatePrice)
    if not paid then return false, L('not_enough_cash') end
    local from = camp.coords
    camp.coords = pos
    for _, p in pairs(camp.furni) do
        if p.item == Config.Camp.flagItem then
            p.coords = { x = pos.x, y = pos.y, z = pos.z }
        elseif Config.Camp.unplaceOnRelocate then
            p.active = false
        end
    end
    if MenuLocks[camp.id] then MenuLocks[camp.id] = nil end
    Save(camp)
    Notify(ctx.src, L('moved_done'))
    CampLog(camp, 'camp', 'Camp Relocated', LogColour.orange, {
        { 'By', Who(ctx.src, camp) },
        { 'From', ('%.1f, %.1f, %.1f'):format(from.x, from.y, from.z), true },
        { 'To', ('%.1f, %.1f, %.1f'):format(pos.x, pos.y, pos.z), true },
        { 'Cost', U.money(Config.Camp.relocatePrice), true },
    }, { actor = ctx.src })
    PushCamp(camp, true)
    return true
end, { gapMs = 2000 })

------------------------------------------------------------------------------ disband

-- shared by the leader's disband and the admin panel's delete
function DisbandCamp(camp, title, actorSrc)
    local stacks = #camp.inventory
    CampLog(camp, 'camp', title, LogColour.red, {
        { 'By', actorSrc and Who(actorSrc, camp) or 'Staff' },
        { 'Members released', tostring(#camp.members), true },
        { 'Safe balance', U.money(camp.cash), true },
        { 'Stash stacks', tostring(stacks), true },
    }, { actor = actorSrc, system = true })
    local ids = {}
    for _, m in ipairs(camp.members) do
        if tonumber(m.charid) then ids[#ids + 1] = tonumber(m.charid) end
    end
    if tonumber(camp.leader) then ids[#ids + 1] = tonumber(camp.leader) end
    Camps[camp.id] = nil
    MenuLocks[camp.id] = nil
    for _, cid in ipairs(ids) do
        SetCharClan(cid, 0)
        OnMembershipLost(cid, camp.id)
        local s = SrcOfChar(cid)
        if s then
            Notify(s, L('no_camp_now'))
            PushMyCamp(s)
        end
    end
    DeleteCampRow(camp.id)
    OnCampGone(camp.id)
    PushGone(camp.id)
end

Handle('disband', function(ctx, campId)
    local camp, why = Can(ctx, campId, 'disband')
    if not camp then return false, why end
    DisbandCamp(camp, 'Camp Disbanded', ctx.src)
    Notify(ctx.src, L('disbanded'))
    return true
end, { gapMs = 2000 })

------------------------------------------------------------------------------ webhook

Handle('webhook', function(ctx, campId, url)
    if not Config.Logs.campWebhooks then return false end
    local camp, why = Can(ctx, campId, 'webhook')
    if not camp then return false, why end
    url = type(url) == 'string' and url:gsub('%s+', '') or ''
    if #url > 300 or not U.isWebhook(url) then return false, L('webhook_invalid') end
    camp.webhook = url
    Save(camp)
    Notify(ctx.src, L('webhook_set'))
    if not Config.Logs.enabled then Notify(ctx.src, L('webhook_logs_off'), 8000) end
    ConnectLog(camp, ctx.src)
    PushCamp(camp)
    return true
end, { gapMs = 3000 })
