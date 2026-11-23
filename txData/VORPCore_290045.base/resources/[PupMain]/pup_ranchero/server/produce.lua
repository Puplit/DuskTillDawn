-- pup_ranchero | chores, milking, egg collecting, the produce store and pen-animal reports

local REACH = Config.Reach

ChoreRounds = {}     -- [src] = { rid, chore, opened (ms) }
ProduceSessions = {} -- [src] = { rid, kind, opened (ms), expires (os.time) }
local lastStart = {} -- ['charid:kind'] = os.time() of the last produce start
local lastReport = {} -- [src] = os.time() of the last pen-kill report

local function minRoundMs()
    if Config.Minigame.collectGame then
        return (Config.Minigame.roundSeconds - Config.Minigame.graceSeconds) * 1000
    end
    return Config.Minigame.fallbackMinSeconds * 1000
end

local function cdTable(kind, rid)
    Cooldowns[kind][rid] = Cooldowns[kind][rid] or {}
    return Cooldowns[kind][rid]
end

------------------------------------------------------------------------------
-- produce store (vorp_inventory custom container). The id rule must never change.
------------------------------------------------------------------------------
local function storeItems()
    local list, seen = {}, {}
    local function add(name) if not seen[name] then seen[name] = true; list[#list + 1] = name end end
    add(Config.Produce.milkItem)
    add(Config.Produce.eggItem)
    for _, a in pairs(Config.Animals) do
        for _, rw in ipairs(a.rewards or {}) do add(rw.item) end
    end
    return list
end

function EnsureStore(r)
    local id = StoreId(r.id)
    local ok, err = pcall(function()
        exports.vorp_inventory:registerInventory({
            id = id,
            name = ('%s Produce'):format(r.name ~= '' and r.name or ('Ranch #' .. r.id)),
            limit = 0, -- no slot or weight limit
            acceptWeapons = false,
            shared = true,
            ignoreItemStackLimit = true,
            whitelistItems = true,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false,
            webhook = false,
        })
        for _, name in ipairs(storeItems()) do
            exports.vorp_inventory:setCustomInventoryItemLimit(id, name, 0) -- allowed, no per-item cap
        end
    end)
    if not ok then print('[pup_ranchero] produce store register failed: ' .. tostring(err)) end
    return ok
end

-- items = { { name, amount }, ... }
function StoreAdd(r, ctx, items)
    if not EnsureStore(r) then return false end
    local ok, res = pcall(function()
        return exports.vorp_inventory:addItemsToCustomInventory(StoreId(r.id), items, ctx.charid, nil, ctx.identifier)
    end)
    return ok and res == true
end

Rpc('openStore', { gap = 1500 }, function(ctx)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    if not EnsureStore(r) then return false end

    local milk, eggs = r.milk, r.eggs
    if milk > 0 or eggs > 0 then
        -- counters zeroed and saved BEFORE the insert, so two openings cannot both move them
        r.milk, r.eggs = 0, 0
        Save(r, 'milk', 'eggs')
        local items = {}
        if milk > 0 then items[#items + 1] = { name = Config.Produce.milkItem, amount = milk } end
        if eggs > 0 then items[#items + 1] = { name = Config.Produce.eggItem, amount = eggs } end
        if not StoreAdd(r, ctx, items) then
            r.milk, r.eggs = r.milk + milk, r.eggs + eggs
            Save(r, 'milk', 'eggs')
        end
    end
    exports.vorp_inventory:openInventory(ctx.src, StoreId(r.id))
    RefreshRanch(r)
    return true
end)

local function storeEvent(data, invId, src, title, color)
    local rid = (tonumber(invId) or 0) - Config.Store.idBase
    local r = Ranches[rid]
    if not r or type(data) ~= 'table' then return end
    local ctx = Ctx(src)
    local item = tostring(data.name or '?')
    LogEmbed(r, title, color, {
        { 'Rancher', ctx and ctx.name or ('id ' .. tostring(src)), true },
        { 'Amount', ('%s x %s'):format(tostring(math.floor(tonumber(data.amount) or 0)), Config.ItemLabels[item] or data.label or item), true },
        { 'Ranch', ('%s (#%d)'):format(r.name, r.id), true },
    })
end

AddEventHandler('vorp_inventory:Server:OnItemTakenFromCustomInventory', function(data, invId, src)
    storeEvent(data, invId, src, 'Produce Taken', LogColors.orange)
end)

AddEventHandler('vorp_inventory:Server:OnItemMovedToCustomInventory', function(data, invId, src)
    storeEvent(data, invId, src, 'Produce Stored', LogColors.green)
end)

------------------------------------------------------------------------------
-- chores
------------------------------------------------------------------------------
local function choreUntil(rid, charid, chore)
    local t = Cooldowns.chore[rid] and Cooldowns.chore[rid][charid]
    return t and t[chore] or 0
end

Rpc('choreStart', { gap = 1500 }, function(ctx, chore)
    local r = MemberRanch(ctx)
    if not r then return false end
    if type(chore) ~= 'string' or not Config.Chores.list[chore] then return false end
    local spot = r.chores[chore]
    if not spot then return false end
    if choreUntil(r.id, ctx.charid, chore) > os.time() then Notify(ctx.src, L('onCooldown')) return false end
    if not Near(ctx.src, spot.loc, REACH.work) then Notify(ctx.src, L('tooFar')) return false end
    ChoreRounds[ctx.src] = { rid = r.id, chore = chore, opened = GetGameTimer() }
    return true
end)

Rpc('choreFinish', { gap = 1500 }, function(ctx, chore, score)
    local round = ChoreRounds[ctx.src]
    ChoreRounds[ctx.src] = nil
    local r = MemberRanch(ctx)
    if not r or type(chore) ~= 'string' or not Config.Chores.list[chore] then return false end
    local spot = r.chores[chore]
    if not spot then return false end
    if not Near(ctx.src, spot.loc, REACH.work) then Notify(ctx.src, L('tooFar')) return false end
    if choreUntil(r.id, ctx.charid, chore) > os.time() then return false end
    if not round or round.rid ~= r.id or round.chore ~= chore or GetGameTimer() - round.opened < minRoundMs() then
        return false
    end

    score = math.floor(tonumber(score) or 0)
    if score <= 0 then Notify(ctx.src, L('collectedNothing')) return false end
    if Config.Chores.capScore then score = math.min(score, Config.Chores.maxScore) end

    spot.num = spot.num + 1
    local before = r.env
    local cap = tonumber(Config.Environment.max) or 0
    r.env = before + score
    if cap > 0 then r.env = math.min(r.env, cap) end
    Save(r, 'chores', 'q_ranch')
    cdTable('chore', r.id)[ctx.charid] = cdTable('chore', r.id)[ctx.charid] or {}
    Cooldowns.chore[r.id][ctx.charid][chore] = os.time() + Config.Chores.cooldown

    local scale = U.envMax()
    local pct = U.round(r.env / scale * 100)
    Notify(ctx.src, L('taskDone'))
    Stat(ctx, r.id, { chores = 1, chore_score = score })
    Activity(r.id, 'CHORE', ('finished %s (score %d, quality now %d%%)'):format(U.choreLabel(chore), score, pct), ctx.name)
    LogEmbed(r, 'Ranch Chore', LogColors.blue, {
        { 'Rancher', ('%s (char %d)'):format(ctx.name, ctx.charid), true },
        { 'Chore', ('%s (done %d times)'):format(U.choreLabel(chore), spot.num), true },
        { 'Score', ('%d / %d'):format(score, Config.Chores.maxScore), true },
        { 'Environment', ('%d -> %d / %d (%d%%)'):format(before, r.env, scale, pct), true },
        { 'Ranch', ('%s (#%d)'):format(r.name, r.id), true },
    })
    RefreshRanch(r)
    return true
end)

------------------------------------------------------------------------------
-- milking and egg collecting
-- The cooldown starts only when a round is completed; a short start gap stops start/cancel spam.
------------------------------------------------------------------------------
local KINDS = {
    milk = { place = 'cows', cd = 'milk', cooldown = function() return Config.Produce.milkCooldown end,
             missing = 'noPen', onCd = 'milkingCooldown', counter = 'milk', added = 'addedMilk', stat = 'milk',
             activity = 'MILK', title = 'Milk Collected', nothing = 'Milking - Nothing Collected', color = LogColors.green },
    eggs = { place = 'chickens', cd = 'eggs', cooldown = function() return Config.Produce.eggCooldown end,
             missing = 'noCoop', onCd = 'checkingCooldown', counter = 'eggs', added = 'addedEggs', stat = 'eggs',
             activity = 'EGGS', title = 'Eggs Collected', nothing = 'Egg Collection - Nothing Collected', color = LogColors.yellow },
}

Rpc('produceStart', { gap = 1500 }, function(ctx, kind)
    local k = KINDS[kind]
    if not k then return false end
    local r = MemberRanch(ctx)
    if not r then return false end
    if not r[k.place] then Notify(ctx.src, L(k.missing)) return false end
    local until_ = cdTable(k.cd, r.id)[ctx.charid] or 0
    if until_ > os.time() then Notify(ctx.src, L(k.onCd)) return false end
    local key = ctx.charid .. ':' .. kind
    if lastStart[key] and os.time() - lastStart[key] < Config.Produce.startGap then
        Notify(ctx.src, L('startTooSoon'))
        return false
    end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    lastStart[key] = os.time()
    ProduceSessions[ctx.src] = { rid = r.id, kind = kind, opened = GetGameTimer(), expires = os.time() + Config.Produce.session }
    return { loc = r[k.place] }
end)

Rpc('produceCancel', { gap = 0 }, function(ctx)
    ProduceSessions[ctx.src] = nil
    return true
end)

Rpc('produceFinish', { gap = 1500 }, function(ctx, kind, score)
    local s = ProduceSessions[ctx.src]
    ProduceSessions[ctx.src] = nil -- one shot
    local k = KINDS[kind]
    if not s or not k or s.kind ~= kind or os.time() > s.expires then return false end
    local r = MemberRanch(ctx, s.rid)
    if not r or not r[k.place] then return false end
    if GetGameTimer() - s.opened < minRoundMs() then return false end
    if not Near(ctx.src, r[k.place], REACH.work) then Notify(ctx.src, L('tooFar')) return false end

    -- the round is complete: the cooldown starts now
    cdTable(k.cd, r.id)[ctx.charid] = os.time() + k.cooldown()

    local amount = U.yieldFor(score, r.env)
    local scale = U.envMax()
    if amount <= 0 then
        Notify(ctx.src, L('envTooLow'))
        Activity(r.id, k.activity, ('collected 0 (environment %d / %d)'):format(r.env, scale), ctx.name)
        LogEmbed(r, k.nothing, LogColors.red, {
            { 'Rancher', ctx.name, true },
            { 'Environment', ('%d / %d - too low'):format(r.env, scale), true },
            { 'Ranch', ('%s (#%d)'):format(r.name, r.id), true },
        })
        RefreshRanch(r)
        return true
    end

    if GetResourceState('pup-perks') == 'started' then
        local ok, extra = pcall(function() return exports['pup-perks']:Bonus(ctx.src, 'ranch_bonus') end)
        extra = ok and math.floor(tonumber(extra) or 0) or 0
        if extra > 0 then amount = amount + extra end
    end
    r[k.counter] = r[k.counter] + amount
    Save(r, k.counter)
    Notify(ctx.src, L(k.added, amount))
    Stat(ctx, r.id, { [k.stat] = amount })
    Activity(r.id, k.activity, ('collected %d (banked %d)'):format(amount, r[k.counter]), ctx.name)
    LogEmbed(r, k.title, k.color, {
        { 'Rancher', ('%s (char %d)'):format(ctx.name, ctx.charid), true },
        { 'Collected', amount, true },
        { 'Banked', r[k.counter], true },
        { 'Environment', ('%d / %d'):format(r.env, scale), true },
        { 'Ranch', ('%s (#%d)'):format(r.name, r.id), true },
    })
    if GetResourceState('pup-perks') == 'started' then
        pcall(function() exports['pup-perks']:Award(ctx.src, 'ranch') end)
    end
    RefreshRanch(r)
    return true
end)

Rpc('takeMilk', { gap = 1500 }, function(ctx, value)
    local r, role = MemberRanch(ctx)
    if not r or not IsBoss(role) then Notify(ctx.src, L('notAllowed')) return false end
    local amount = tonumber(value)
    if not amount or amount < 1 or amount ~= math.floor(amount) or amount > r.milk then Notify(ctx.src, L('invalidAmount')) return false end
    if not Near(ctx.src, r.coords, REACH.ranch) then Notify(ctx.src, L('tooFar')) return false end
    local can = exports.vorp_inventory:canCarryItem(ctx.src, Config.Produce.milkItem, amount)
    if not can then Notify(ctx.src, L('cantCarry')) return false end
    if amount > r.milk then Notify(ctx.src, L('invalidAmount')) return false end -- re-check after the carry check
    r.milk = r.milk - amount
    Save(r, 'milk')
    exports.vorp_inventory:addItem(ctx.src, Config.Produce.milkItem, amount)
    Notify(ctx.src, L('tookMilk', amount))
    RefreshRanch(r)
    return true
end)

------------------------------------------------------------------------------
-- the pen cow died (reported once by the client)
------------------------------------------------------------------------------
Rpc('penKilled', { gap = 1000 }, function(ctx, killerId)
    local now = os.time()
    if lastReport[ctx.src] and now - lastReport[ctx.src] < Config.Produce.reportGap then return false end
    lastReport[ctx.src] = now
    -- logged under the player's own ranch, not ranch 0
    local r = MemberRanch(ctx)
    if not r or not r.cows then return false end
    local kid = math.floor(tonumber(killerId) or 0)
    if kid <= 0 or kid == ctx.src then
        local taken = 0
        if Config.Livestock.chargeOwnCow then
            taken = U.cents(math.min(Config.Livestock.ownCowCharge, math.max(0, Cash(ctx.src))))
            if taken > 0 then ctx.char.removeCurrency(0, taken) end
            -- the message states what was actually taken
            Notify(ctx.src, L('ownCow', U.money(taken)))
        end
        LogPlain('general', r, 'Ranch Cheater', { ('Player: %s %s'):format(ctx.name, L('logOwnCow')), ('Ranch ID: %d'):format(r.id) }, false)
        Activity(r.id, 'CHEAT_REPORT', ('killed their own pen cow (charged $%s)'):format(U.money(taken)), ctx.name)
    else
        local k = Ctx(kid)
        local kname = k and k.name or (GetPlayerName(kid) or ('id ' .. kid))
        LogPlain('general', r, 'Ranch Cow Killed', { ('Killer: %s %s'):format(kname, L('logPlayersCow')), ('Owner: %s'):format(ctx.name) }, false)
        Activity(r.id, 'PVP_LOSS', ('%s killed the pen cow'):format(kname), ctx.name)
    end
    return true
end)

function DropProduceState(src)
    ChoreRounds[src] = nil
    ProduceSessions[src] = nil
    lastReport[src] = nil
end
