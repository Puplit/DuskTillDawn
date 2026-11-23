-- pup-perks | server: owns xp, perk ranks and the equipped loadout

local Core   -- resolved lazily: this resource must not touch vorp_core at load

local function core()
    if not Core then Core = exports.vorp_core:GetCore() end
    return Core
end

local function dbg(fmt, ...)
    if not Config.General.debug then return end
    print(('^2[pup-perks]^7 ' .. fmt):format(...))
end

-- config indexes + validation

local PERK = {}          -- id -> perk
local CAT = {}           -- catKey -> category (with .side)
local CAT_HAS_PERKS = {} -- catKey -> true

for _, c in ipairs(Config.Trees.list) do
    CAT[c.key] = c
end

for _, p in ipairs(Config.Perks) do
    if PERK[p.id] then
        print(("^1[pup-perks] duplicate perk id '%s' - the later one wins^7"):format(p.id))
    end
    if type(p.ranks) ~= 'table' or #p.ranks == 0 then
        print(("^1[pup-perks] perk '%s' has no ranks - it will never be buyable^7"):format(tostring(p.id)))
    end

    -- resolve the perk's side ONCE at load: normally it comes from its tree
    local cat = CAT[p.cat]
    if not cat then
        print(("^1[pup-perks] perk '%s' has unknown cat '%s' - it will not appear^7")
            :format(tostring(p.id), tostring(p.cat)))
    elseif cat.side == 'both' then
        if p.side ~= 'civ' and p.side ~= 'crime' then
            print(("^1[pup-perks] perk '%s' sits in the '%s' tree (side 'both') so it MUST set side = 'civ' or 'crime'. Defaulting to civ.^7")
                :format(tostring(p.id), tostring(p.cat)))
            p.side = 'civ'
        end
    else
        p.side = cat and cat.side or 'civ'
    end

    PERK[p.id] = p
    if p.cat then CAT_HAS_PERKS[p.cat] = true end
end

-- a 'both' tree is always open; every other tree has to be chosen
local function catIsOpen(catKey)
    local c = CAT[catKey]
    return c ~= nil and c.side == 'both'
end

local MAX_LEVEL = #Config.Progression.levelXp

local function levelForXP(xp)
    xp = tonumber(xp) or 0
    local lvl = 1
    for i, need in ipairs(Config.Progression.levelXp) do
        if xp >= need then lvl = i end
    end
    return lvl
end

-- total perk points a character of this level has been granted
local function pointsAtLevel(lvl)
    local total = 0
    for i = 1, lvl do
        total = total + (Config.Progression.pointsPerLevel or 1) + (Config.Progression.bonusPoints[i] or 0)
    end
    return total
end

-- how many points sit in a perk at `rank` (ranks 1..rank inclusive)
local function spentOn(perk, rank)
    local total = 0
    -- clamped to the CARD cap, not the raw rank list
    local cap = math.min(#perk.ranks, math.max(1, math.floor(tonumber(Config.Cards.maxLevel) or 3)))
    for i = 1, math.min(rank, cap) do
        total = total + (tonumber(perk.ranks[i].cost) or 0)
    end
    return total
end

-- The character level a rank of a perk needs (always 1 when Config.Progression.requireLevels = false)
local function rankReq(perk, rankIndex)
    if Config.Progression.requireLevels == false then return 1 end
    local r = perk.ranks[rankIndex]
    return (r and tonumber(r.req)) or tonumber(perk.req) or 1
end

-- THE CARD LOADOUT
local function slotTypeOf(p)
    return (p and p.slot == 'special') and 'special' or 'passive'
end

local function slotCap(kind)
    local n = tonumber(Config.Cards.loadout and Config.Cards.loadout[kind])
    return math.max(0, math.floor(n or (kind == 'special' and 1 or 3)))
end

-- how many of `kind` the character currently has equipped
local function equippedCount(st, kind)
    local n = 0
    for _, id in ipairs(st.equipped) do
        local p = PERK[id]
        if p and slotTypeOf(p) == kind then n = n + 1 end
    end
    return n
end

-- total loadout size, for the panel header
local function slotsAtLevel()
    return slotCap('special') + slotCap('passive')
end

-- cards stop at Config.Cards.maxLevel even if their rank list is longer
local function maxLevelOf(p)
    local cap = tonumber(Config.Cards.maxLevel) or 3
    return math.min(#p.ranks, math.max(1, math.floor(cap)))
end

-- state
-- cache[src] = { charid, civxp, crimexp, ranks = {id=rank}, equipped = {id,...}, eff = {} }

local cache = {}

-- per-player gap between actions that write the perks row
local lastAction = {}
local function tooFast(src)
    local now = GetGameTimer()
    local gap = tonumber(Config.ActionCooldownMs) or 2000
    if lastAction[src] and now - lastAction[src] < gap then return true end
    lastAction[src] = now
    return false
end

-- Collapse the equipped perks (at their current ranks) into a flat effect table: chance highest wins, mult multiplies, add sums
local function activeIds(st)
    if Config.Cards.autoEquip == false then return st.equipped end
    local ids = {}
    for id, rank in pairs(st.ranks) do
        if (tonumber(rank) or 0) > 0 then ids[#ids + 1] = id end
    end
    return ids
end

local function resolve(st)
    local eff = {}
    for _, id in ipairs(activeIds(st)) do
        local p = PERK[id]
        local rank = st.ranks[id] or 0
        local r = p and rank > 0 and p.ranks[rank] or nil
        if p and r and p.effect and p.effect.key then
            local key = p.effect.key
            local slot = eff[key]
            if not slot then
                slot = { chance = 0, mult = 1.0, add = 0 }
                eff[key] = slot
            end
            if r.chance and r.chance > slot.chance then slot.chance = r.chance end
            if r.mult then slot.mult = slot.mult * r.mult end
            if r.add then slot.add = slot.add + r.add end
        end
    end
    return eff
end

local function totalXP(st)
    return (st.civxp or 0) + (st.crimexp or 0)
end

-- Player level (lifetime, per side) and specialist level (the committed tree's own xp) are different things

local function baseOf(st, side)
    return (side == 'crime' and st.crimebase or st.civbase) or 0
end

local function sideXP(st, side)
    return (side == 'crime' and st.crimexp or st.civxp) or 0
end

-- which tree this character committed to on a side, or nil (an if, not `cond and A or B`, since A may be nil)
local function treeOf(st, side)
    if side == 'crime' then return st.crimetree end
    return st.civtree
end

-- xp earned in one tree: a speciality levels on its own work
local function treeXP(st, key)
    if not key or type(st.treexp) ~= 'table' then return nil end
    return tonumber(st.treexp[key]) or 0
end

-- SPECIALIST level: what perks are gated on and what pays for them.
local function levelOfSide(st, side)
    -- no speciality, no specialist level; work still counts toward the lifetime side total
    if not treeOf(st, side) then return levelForXP(0) end
    return levelForXP(treeXP(st, treeOf(st, side)) or 0)
end

-- PLAYER level on one side: lifetime, ignores the specialist baseline.
local function playerLevelOfSide(st, side)
    return levelForXP(sideXP(st, side))
end

-- Equip slots are shared, so they unlock on whichever side is further along
local function levelOf(st)
    return math.max(playerLevelOfSide(st, 'civ'), playerLevelOfSide(st, 'crime'))
end

-- Points spent ON ONE SIDE
local function pointsSpent(st, side)
    local total = 0
    for id, rank in pairs(st.ranks) do
        local p = PERK[id]
        if p and (side == nil or p.side == side) then
            total = total + spentOn(p, rank)
        end
    end
    return total
end

-- bonusciv / bonuscrime are what an admin granted or took on that side; they ride on top of what levelling gave
local function bonusOf(st, side)
    return (side == 'crime' and st.bonuscrime or st.bonusciv) or 0
end

local function pointsFree(st, side)
    return pointsAtLevel(levelOfSide(st, side)) + bonusOf(st, side) - pointsSpent(st, side)
end

-- weekly free-respec cooldown
local function weeklyWindow()
    return math.max(1, math.floor(tonumber(Config.Reset and Config.Reset.freeCooldownSeconds) or (7 * 24 * 60 * 60)))
end

-- unix time the next FREE reset unlocks; 0 = available now
local function resetReadyAt(st)
    local last = tonumber(st.lastreset) or 0
    if last <= 0 then return 0 end
    return last + weeklyWindow()
end

-- writeState takes a state table rather than a source
local function writeState(st)
    if not st or not st.charid then return end
    MySQL.update('INSERT INTO perks (charidentifier, civxp, crimexp, bonusciv, bonuscrime, civtree, crimetree, ranks, equipped, civbase, crimebase, lastreset, treexp) ' ..
                 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ' ..
                 'ON DUPLICATE KEY UPDATE civxp = VALUES(civxp), crimexp = VALUES(crimexp), ' ..
                 'treexp = VALUES(treexp), ' ..
                 'bonusciv = VALUES(bonusciv), bonuscrime = VALUES(bonuscrime), ' ..
                 'civtree = VALUES(civtree), crimetree = VALUES(crimetree), ' ..
                 'ranks = VALUES(ranks), equipped = VALUES(equipped), ' ..
                 'civbase = VALUES(civbase), crimebase = VALUES(crimebase), lastreset = VALUES(lastreset)',
        -- '' NOT nil: a nil here ends the array and drops every later parameter.
        -- Both trees are nil between a reset and picking again. validTree reads '' as nil.
        { st.charid, st.civxp, st.crimexp, st.bonusciv or 0, st.bonuscrime or 0,
          st.civtree or '', st.crimetree or '', json.encode(st.ranks), json.encode(st.equipped),
          st.civbase or 0, st.crimebase or 0, st.lastreset or 0,
          json.encode(st.treexp or {}) })
end

local function save(src)
    writeState(cache[src])
end

-- The client keeps its own copy of the resolved effects so progress bars can shorten without a server round trip
local function push(src)
    local st = cache[src]
    if not st then return end
    TriggerClientEvent('pup-perks:sync', src, st.eff)
end

-- Read one character's row into a state table
local function readState(charid)
    local row = MySQL.single.await(
        'SELECT civxp, crimexp, bonusciv, bonuscrime, civtree, crimetree, ranks, equipped, ' ..
        'civbase, crimebase, lastreset, treexp ' ..
        'FROM perks WHERE charidentifier = ?', { charid })

    local ranks, equipped = {}, {}

    if row and row.ranks then
        local ok, decoded = pcall(json.decode, row.ranks)
        if ok and type(decoded) == 'table' then
            for id, rank in pairs(decoded) do
                local p = PERK[id]
                rank = tonumber(rank) or 0
                -- clamp: the config may have shrunk a perk's rank list since. clamps to the CARD CAP too
                if p and rank > 0 then
                    local cap = math.min(#p.ranks, math.max(1, math.floor(tonumber(Config.Cards.maxLevel) or 3)))
                    ranks[id] = math.min(rank, cap)
                end
            end
        end
    end

    if row and row.equipped then
        local ok, decoded = pcall(json.decode, row.equipped)
        if ok and type(decoded) == 'table' then
            for _, id in ipairs(decoded) do
                if PERK[id] and (ranks[id] or 0) > 0 then equipped[#equipped + 1] = id end
            end
        end
    end

    -- a stored tree that no longer exists in the config is dropped
    local function validTree(v, side)
        if type(v) ~= 'string' or v == '' then return nil end
        local c = CAT[v]
        if not c or c.side ~= side or not CAT_HAS_PERKS[v] then return nil end
        return v
    end

    local st = {
        charid     = charid,
        civxp      = (row and tonumber(row.civxp)) or 0,
        crimexp    = (row and tonumber(row.crimexp)) or 0,
        bonusciv   = (row and tonumber(row.bonusciv)) or 0,
        bonuscrime = (row and tonumber(row.bonuscrime)) or 0,
        civtree    = row and validTree(row.civtree, 'civ') or nil,
        crimetree  = row and validTree(row.crimetree, 'crime') or nil,
        ranks      = ranks,
        equipped   = equipped,
        -- xp banked when the current specialist was chosen (see levelOfSide)
        civbase    = (row and tonumber(row.civbase)) or 0,
        crimebase  = (row and tonumber(row.crimebase)) or 0,
        -- os.time() of the last weekly reset; 0 = never
        lastreset  = (row and tonumber(row.lastreset)) or 0,
    }

    -- a base can never exceed the xp it offsets
    if st.civbase   > st.civxp   then st.civbase   = st.civxp   end
    if st.crimebase > st.crimexp then st.crimebase = st.crimexp end

    -- per-tree xp
    if row and row.treexp then
        local ok, decoded = pcall(json.decode, row.treexp)
        if ok and type(decoded) == 'table' then
            st.treexp = {}
            for k, v in pairs(decoded) do
                if CAT[k] then st.treexp[k] = tonumber(v) or 0 end
            end
        end
    end
    -- no per-tree xp stored yet: the specialist xp on each side becomes the committed tree's xp, so the level is kept
    if st.treexp == nil then
        st.treexp = {}
        for _, side in ipairs({ 'civ', 'crime' }) do
            local tree = (side == 'crime') and st.crimetree or st.civtree
            if tree then
                local xp = (side == 'crime') and st.crimexp or st.civxp
                local base = (side == 'crime') and st.crimebase or st.civbase
                st.treexp[tree] = math.max(0, (xp or 0) - (base or 0))
            end
        end
        dbg('migrated char %s to per-tree xp: %s', tostring(charid), json.encode(st.treexp))
    end

    -- bring the committed tree up to that side's best; the other trees keep what they had
    for _, side in ipairs({ 'civ', 'crime' }) do
        local tree = (side == 'crime') and st.crimetree or st.civtree
        if tree then
            local best = 0
            for key, cat in pairs(CAT) do
                if cat.side == side then best = math.max(best, tonumber(st.treexp[key]) or 0) end
            end
            if best > (tonumber(st.treexp[tree]) or 0) then st.treexp[tree] = best end
        end
    end

    -- a level loss (a config retune, or an admin taking points back) can leave more equipped than there are slots
    local maxSlots = slotsAtLevel(levelOf(st))
    while #st.equipped > maxSlots do table.remove(st.equipped) end

    st.eff = resolve(st)
    return st, (row ~= nil)
end

local function load(src, charid)
    charid = tonumber(charid)
    if not charid then return end

    local st, existed = readState(charid)
    cache[src] = st

    if not existed then save(src) end   -- first login: create the row

    dbg('loaded src=%s charid=%s civ=L%d/%dp[%s] crime=L%d/%dp[%s] equipped=%d',
        src, charid,
        levelOfSide(st, 'civ'), pointsFree(st, 'civ'), tostring(st.civtree or '-'),
        levelOfSide(st, 'crime'), pointsFree(st, 'crime'), tostring(st.crimetree or '-'),
        #st.equipped)
    push(src)
end

local function notify(src, title, msg, tone)
    TriggerClientEvent('pup-perks:toast', src, title, msg, tone)
end

--- VORP's right-hand tip. Used for levelling up, which should read like every
--- other reward on the server rather than opening a pup-ui card.
local function notifyTip(src, msg, ms)
    local ok = pcall(function() core().NotifyRightTip(src, msg, ms or 5000) end)
    if not ok then notify(src, Locale.perksTitle, msg, 'gold') end
end

-- lifecycle

AddEventHandler('vorp:SelectedCharacter', function(source, character)
    if not character then return end
    load(source, character.charIdentifier or character.charidentifier)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastAction[src] = nil
    if cache[src] then
        save(src)
        cache[src] = nil
    end
end)

-- re-hydrate anyone already in the world when this resource restarts
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- schema columns added here, so sql/install.sql never has to be re-imported
    CreateThread(function()
        for _, col in ipairs({
            { 'civbase',   'INT(11) NOT NULL DEFAULT 0' },
            { 'crimebase', 'INT(11) NOT NULL DEFAULT 0' },
            { 'lastreset', 'INT(11) NOT NULL DEFAULT 0' },
            -- xp banked per tree, so a speciality levels on its own work
            { 'treexp',    'TEXT NULL' },
        }) do
            local ok = pcall(function()
                local n = MySQL.scalar.await([[
                    SELECT COUNT(*) FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'perks' AND COLUMN_NAME = ?
                ]], { col[1] })
                if (tonumber(n) or 0) == 0 then
                    MySQL.query.await(('ALTER TABLE `perks` ADD COLUMN `%s` %s'):format(col[1], col[2]))
                    print(('^2[pup-perks]^7 added column `%s`'):format(col[1]))
                end
            end)
            if not ok then
                print(('^1[pup-perks]^7 could not add column `%s` - import sql/install.sql by hand'):format(col[1]))
            end
        end
    end)

    CreateThread(function()
        Wait(2000)   -- let vorp_core come up if this is a cold boot
        for _, src in ipairs(GetPlayers()) do
            src = tonumber(src)
            local user = core().getUser(src)
            local ch = user and user.getUsedCharacter
            if ch then load(src, ch.charIdentifier) end
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(cache) do save(src) end
end)

-- panel payload

-- THE CARD LOADOUT ROW (1 special + 3 passive)
local function slotView(st)
    local out = {}

    -- with AutoEquip on there is no loadout to build
    if Config.Cards.autoEquip ~= false then
        local ids = activeIds(st)
        table.sort(ids, function(a, b)
            local pa, pb = PERK[a], PERK[b]
            return ((pa and pa.name) or a) < ((pb and pb.name) or b)
        end)
        for _, id in ipairs(ids) do
            local p = PERK[id]
            if p then
                out[#out + 1] = {
                    kind = slotTypeOf(p), state = 'filled', id = id,
                    name = p.name, glyph = p.glyph,
                    rank = st.ranks[id] or 0, maxRank = maxLevelOf(p),
                }
            end
        end
        return out
    end

    for _, kind in ipairs({ 'special', 'passive' }) do
        -- the cards of this kind the character is actually wearing, in the order they equipped them
        local worn = {}
        for _, id in ipairs(st.equipped) do
            local p = PERK[id]
            if p and slotTypeOf(p) == kind then worn[#worn + 1] = id end
        end

        for i = 1, slotCap(kind) do
            local id = worn[i]
            local p  = id and PERK[id]
            if p then
                out[#out + 1] = {
                    kind = kind, state = 'filled', id = id,
                    name = p.name, glyph = p.glyph, cat = p.cat,
                    rank = st.ranks[id] or 0, maxRank = maxLevelOf(p),
                }
            else
                out[#out + 1] = { kind = kind, state = 'empty' }
            end
        end
    end
    return out
end

-- Is this perk's tree available to spend in?
local function treeOpenFor(st, p)
    if catIsOpen(p.cat) then return true end
    return treeOf(st, p.side) == p.cat
end

-- Optional prerequisite (p.requires)
local function requiresMet(st, p)
    local rq = p.requires
    if type(rq) ~= 'table' or not rq.perk then return true, nil end

    local need = math.max(1, tonumber(rq.rank) or 1)
    local other = PERK[rq.perk]
    if not other then
        -- a prerequisite pointing at a deleted perk would lock the capstone forever and silently; say so loudly instead
        print(("^1[pup-perks] perk '%s' requires unknown perk '%s' - treating as met^7")
            :format(tostring(p.id), tostring(rq.perk)))
        return true, nil
    end

    local have = st.ranks[rq.perk] or 0
    if have >= need then return true, nil end

    return false, Locale.blockedNeedsPerk:format(other.name, need)
end

local function perkView(st)
    local out = {}
    for _, p in ipairs(Config.Perks) do
        local side    = p.side
        local lvl     = levelOfSide(st, side)   -- gated on ITS OWN side's level
        local free    = pointsFree(st, side)    -- paid from ITS OWN side's pool
        local rank    = st.ranks[p.id] or 0
        local maxRank = maxLevelOf(p)
        local owned   = rank > 0
        local maxed   = rank >= maxRank
        local inTree  = treeOpenFor(st, p)

        local cur  = owned and p.ranks[rank] or nil
        local nxt  = (not maxed) and p.ranks[rank + 1] or nil
        local nreq = (not maxed) and rankReq(p, rank + 1) or nil
        local cost = nxt and (tonumber(nxt.cost) or 0) or nil

        local isEquipped = false
        for _, id in ipairs(st.equipped) do
            if id == p.id then isEquipped = true break end
        end

        local catRow    = CAT[p.cat]
        local treeLabel = catRow and catRow.label or p.cat
        local sideLabel = Config.Trees.sideLabels[side] or side

        local reqOk, reqText = requiresMet(st, p)

        -- why can this player not buy the next rank right now?
        local blocked = nil
        if not maxed then
            if not reqOk and inTree then
                blocked = reqText
            elseif not inTree then
                local chosen = treeOf(st, side)
                blocked = chosen
                    and Locale.blockedCommitted:format(
                        (CAT[chosen] and CAT[chosen].label) or chosen, sideLabel:lower())
                    or Locale.blockedChooseTree:format(treeLabel, sideLabel:lower())
            elseif lvl < nreq then
                blocked = Locale.blockedLevel:format(sideLabel, nreq)
            elseif free < cost then
                blocked = Locale.blockedPoints:format(cost, sideLabel:lower(), cost == 1 and '' or 's')
            end
        end

        out[#out + 1] = {
            id        = p.id,
            name      = p.name,
            desc      = p.desc,
            cat       = p.cat,
            side      = side,
            sideLabel = sideLabel,
            glyph     = p.glyph,
            -- which loadout slot this card belongs in
            slot      = slotTypeOf(p),
            rank      = rank,
            maxRank   = maxRank,
            owned     = owned,
            maxed     = maxed,
            equipped  = isEquipped,
            inTree    = inTree,
            -- locked greys the card out: wrong tree, unmet prerequisite, or too low a level
            locked    = (not owned) and (not inTree or not reqOk or lvl < rankReq(p, 1)),
            req       = rankReq(p, 1),
            -- the prerequisite, so the detail panel can show it as its own row
            reqPerk   = (type(p.requires) == 'table' and p.requires.perk) or nil,
            reqPerkName = (type(p.requires) == 'table' and PERK[p.requires.perk] and PERK[p.requires.perk].name) or nil,
            reqPerkRank = (type(p.requires) == 'table' and math.max(1, tonumber(p.requires.rank) or 1)) or nil,
            reqPerkOk = reqOk,
            -- a prerequisite IS the tree edge
            parent    = p.parent or (type(p.requires) == 'table' and p.requires.perk) or nil,
            -- the WHOLE ladder, so a player can read what a tree actually gives before committing to it
            tiers     = (function()
                local t = {}
                for i, r in ipairs(p.ranks) do
                    t[i] = { rank = i, text = r.text, cost = tonumber(r.cost) or 0, req = rankReq(p, i) }
                end
                return t
            end)(),
            current   = cur and cur.text or nil,
            nextText  = nxt and nxt.text or nil,
            nextCost  = cost,
            nextReq   = nreq,
            canBuy    = (not maxed) and blocked == nil,
            blocked   = blocked,
        }
    end
    return out
end

-- One side's whole progression: level, xp bar, point pool, chosen tree.
local function sideView(st, side)
    -- the bar and the level must be on the same scale: read xp the way levelOfSide does
    local tree = treeOf(st, side)
    local lvl  = levelOfSide(st, side)
    -- no speciality, no bar: levelOfSide reads 0 there, so the two must agree
    local xp   = tree and (treeXP(st, tree) or 0) or 0
    local base = Config.Progression.levelXp[lvl] or 0
    local nxt  = Config.Progression.levelXp[lvl + 1]

    return {
        side     = side,
        label    = Config.Trees.sideLabels[side] or side,
        -- SPECIALIST level - what perks are gated on and what buys them
        level    = lvl,
        -- the CHARACTER's own level on this side
        playerLevel = playerLevelOfSide(st, side),
        -- lifetime xp on this side, untouched by any switch
        lifetimeXp = sideXP(st, side),
        -- true once the specialist has been rebased at least once
        rebased  = baseOf(st, side) > 0,
        maxLevel = MAX_LEVEL,
        -- specialist-relative and clamped, so the bar never reports a negative
        xp       = xp,
        xpInto   = math.max(0, xp - base),               -- xp earned inside this level
        xpSpan   = nxt and math.max(1, nxt - base) or nil, -- what the whole level is worth
        xpToNext = nxt and math.max(0, nxt - xp) or nil,   -- nil at max level
        points   = pointsFree(st, side),
        spent    = pointsSpent(st, side),
        bonus    = bonusOf(st, side),
        tree     = tree,
        treeLabel = tree and ((CAT[tree] and CAT[tree].label) or tree) or nil,
    }
end

-- The Guide's words from config/guide.lua, with the real settings filled in. Built once.
local guideCache
local function guideView()
    if guideCache or not Config.Guide then return guideCache end
    local levels = {}
    for lvl in pairs(Config.Progression.bonusPoints or {}) do levels[#levels + 1] = lvl end
    table.sort(levels)
    local vars = {
        pointsPerLevel = Config.Progression.pointsPerLevel or 1,
        bonusLevels    = table.concat(levels, ', '),
        maxLevel       = MAX_LEVEL,
        maxRank        = Config.Cards.maxLevel,
        resetDays      = math.floor(weeklyWindow() / 86400),
        resetPrice     = tonumber(Config.Reset.price) or 0,
    }
    local function fill(v)
        if type(v) == 'string' then
            return (v:gsub('{(%w+)}', function(k)
                if vars[k] ~= nil then return tostring(vars[k]) end
            end))
        end
        if type(v) ~= 'table' then return v end
        local out = {}
        for k, x in pairs(v) do out[k] = fill(x) end
        return out
    end
    guideCache = fill(Config.Guide)
    return guideCache
end

local function panelData(src)
    local st = cache[src]
    if not st then return nil end

    local perks = perkView(st)

    -- sidebar counts, and only trees that actually hold perks
    local counts = {}
    for _, v in ipairs(perks) do
        local c = counts[v.cat] or { total = 0, owned = 0 }
        c.total = c.total + 1
        if v.owned then c.owned = c.owned + 1 end
        counts[v.cat] = c
    end

    local cats = {}
    for _, c in ipairs(Config.Trees.list) do
        -- an empty tree would just be a dead tab; it reappears on its own the moment a perk with that `cat` is added to the config
        if CAT_HAS_PERKS[c.key] then
            local n = counts[c.key] or { total = 0, owned = 0 }
            local chosen = (c.side ~= 'both') and (treeOf(st, c.side) == c.key) or false
            cats[#cats + 1] = {
                key    = c.key,
                label  = c.label,
                desc   = c.desc,
                glyph  = c.glyph,
                side   = c.side,
                total  = n.total,
                owned  = n.owned,
                always = c.side == 'both',                 -- never needs choosing
                chosen = chosen,
                -- can this tree still be claimed? (side undecided, and not 'both')
                claimable = (c.side ~= 'both') and treeOf(st, c.side) == nil or false,
                -- SWITCHABLE - this side is already committed to something ELSE
                switchable = (c.side ~= 'both')
                    and treeOf(st, c.side) ~= nil
                    and treeOf(st, c.side) ~= c.key or false,
                -- what a switch to this tree would cost the player right now
                switchCost = (c.side ~= 'both') and pointsSpent(st, c.side) or 0,
                switchLevel = (c.side ~= 'both') and levelOfSide(st, c.side) or 0,
                -- the level this tree's own experience is worth, which is where a switch lands
                bankedLevel = levelForXP(treeXP(st, c.key) or 0),
            }
        end
    end

    -- WEEKLY RESET STATE for the confirm dialog
    local now      = os.time()
    local readyAt  = resetReadyAt(st)
    local invested = pointsSpent(st, nil)

    local slotLvl = levelOf(st)   -- slots run off the BETTER side
    return {
        sides     = { civ = sideView(st, 'civ'), crime = sideView(st, 'crime') },
        sideOrder = { 'civ', 'crime' },
        level     = slotLvl,       -- headline / slot level only
        maxLevel  = MAX_LEVEL,
        slots     = slotView(st),
        -- the loadout's shape, so the page can lay out the special row and the passive row without hard-coding 1 and 3
        loadout   = { special = slotCap('special'), passive = slotCap('passive') },
        cats      = cats,
        perks     = perks,
        guide     = guideView(),
        -- the UI must not advertise rules the server is not enforcing
        requireLevels = Config.Progression.requireLevels ~= false,
        autoEquip     = Config.Cards.autoEquip ~= false,
        reset     = {
            enabled   = Config.Reset.enabled ~= false,
            ready     = now >= readyAt,
            readyAt   = readyAt,               -- unix time, 0 = never used
            inSeconds = math.max(0, readyAt - now),
            refund    = invested,              -- what a reset would hand back
            everyDays = math.floor(weeklyWindow() / 86400),
            fullCost  = tonumber(Config.Reset.price) or 0,
            -- the same value under the name the full-reset dialog reads (d.reset.cost)
            cost      = tonumber(Config.Reset.price) or 0,
        },
    }
end

local function repaint(src)
    TriggerClientEvent('pup-perks:refresh', src, panelData(src))
end

-- xp

local function addXP(src, track, amount, treeKey)
    src = tonumber(src)
    amount = tonumber(amount) or 0
    if amount <= 0 then return 0 end
    if track ~= 'civ' and track ~= 'crime' then return 0 end

    local st = cache[src]
    if not st then return 0 end

    -- the xp perks feed themselves; that is intended
    local e = st.eff[track == 'civ' and 'civ_xp' or 'crime_xp']
    if e and e.mult then amount = amount * e.mult end
    amount = math.floor(amount + 0.5)

    -- levels are per side, so this only ever moves ONE of the two
    local field  = track == 'civ' and 'civxp' or 'crimexp'
    local before = levelOfSide(st, track)
    st[field] = st[field] + amount
    -- all of a side's work feeds the committed tree, whatever the activity was tagged as; no commitment, no specialist progress
    local tree = treeOf(st, track)
    if tree then
        st.treexp = st.treexp or {}
        st.treexp[tree] = (tonumber(st.treexp[tree]) or 0) + amount
    end
    local after  = levelOfSide(st, track)

    save(src)
    dbg('xp src=%s track=%s +%d -> %d (%s level %d)', src, track, amount, st[field], track, after)

    -- nothing banked without a speciality, so nothing to show on the bar
    TriggerClientEvent('pup-perks:xp', src, {
        gained = tree and amount or 0, track = track,
        level = after, levelUp = after > before,
    })

    if after > before then
        local gained = pointsAtLevel(after) - pointsAtLevel(before)
        local label = Config.Trees.sideLabels[track] or track
        notifyTip(src, gained > 0
            and Locale.levelUpPoints:format(label, after, gained, gained == 1 and '' or 's')
            or Locale.levelUp:format(label, after), 6000)
        push(src)
        repaint(src)
    end

    return st[field]
end

-- A Config.XpSources entry gives either a flat `xp` or a `min`/`max` range rolled per action
local function xpFor(entry)
    if entry.min or entry.max then
        local lo = math.floor(tonumber(entry.min) or tonumber(entry.max) or 0)
        local hi = math.floor(tonumber(entry.max) or lo)
        if hi < lo then lo, hi = hi, lo end
        return math.random(lo, hi)
    end
    return tonumber(entry.xp) or 0
end

local function award(src, kind)
    local entry = Config.XpSources[kind]
    if not entry then
        print(("^1[pup-perks] Award() called with unknown kind '%s' - add it to Config.XpSources^7"):format(tostring(kind)))
        return 0
    end

    -- `track = 'both'` feeds BOTH ladders from one action, each into its own tree
    if entry.track == 'both' then
        local total = xpFor(entry)
        if total <= 0 then return 0 end
        local civ, crime = total, total
        if entry.split ~= false then
            civ = math.floor(total / 2)
            crime = total - civ -- odd totals put the spare point on the crime side
        end
        addXP(src, 'civ', civ)
        return addXP(src, 'crime', crime)
    end

    return addXP(src, entry.track, xpFor(entry))
end

-- effect queries

local function effOf(src, key)
    local st = cache[tonumber(src)]
    return st and st.eff[key] or nil
end

local function has(src, key)
    return effOf(src, key) ~= nil
end

local function roll(src, key)
    local e = effOf(src, key)
    if not e or e.chance <= 0 then return false end
    local r = math.random(1, 100)
    local hit = r <= e.chance
    dbg('roll src=%s key=%s chance=%d%% roll=%d -> %s', src, key, e.chance, r, hit and 'HIT' or 'miss')
    return hit
end

local function mult(src, key)
    local e = effOf(src, key)
    return (e and e.mult) or 1.0
end

local function bonus(src, key)
    local e = effOf(src, key)
    return (e and e.add) or 0
end

exports('Roll', roll)
exports('Has', has)
exports('Mult', mult)
exports('Bonus', bonus)
exports('Award', award)
exports('AddXP', addXP)
-- GetLevel(src)          -> the better of the two sides (the headline level)
-- GetLevel(src, 'civ')   -> that side's level specifically
exports('GetLevel', function(src, side)
    local st = cache[tonumber(src)]
    if not st then return 1 end
    if side == 'civ' or side == 'crime' then return levelOfSide(st, side) end
    return levelOf(st)
end)
-- which tree this character committed to on a side, or nil
exports('GetTree', function(src, side)
    local st = cache[tonumber(src)]
    return st and treeOf(st, side == 'crime' and 'crime' or 'civ') or nil
end)
exports('GetXP', function(src, track)
    local st = cache[tonumber(src)]
    if not st then return 0 end
    if track == 'civ' then return st.civxp end
    if track == 'crime' then return st.crimexp end
    return totalXP(st)
end)
exports('GetRank', function(src, perkId)
    local st = cache[tonumber(src)]
    return st and (st.ranks[perkId] or 0) or 0
end)

-- client intents (nothing here trusts the client)

CreateThread(function()
    -- deferred by a tick: vorp_core must not be touched at file scope
    core().Callback.Register('pup-perks:panel', function(src, cb)
        -- a mid-session restart of THIS resource can leave a logged-in player uncached
        if not cache[src] then
            local user = core().getUser(src)
            local ch = user and user.getUsedCharacter
            if ch then load(src, ch.charIdentifier) end
        end
        cb(panelData(src) or false)
    end)
end)

RegisterNetEvent('pup-perks:upgrade', function(perkId)
    local src = source
    local st  = cache[src]
    local p   = PERK[perkId]
    if not st or not p then return end
    if tooFast(src) then return end

    local rank = st.ranks[perkId] or 0
    -- against the card cap, not the raw rank list
    if rank >= maxLevelOf(p) then
        notify(src, Locale.maxedTitle, Locale.maxed:format(p.name), 'red')
        return
    end

    local side      = p.side
    local sideLabel = Config.Trees.sideLabels[side] or side

    -- the tree gate comes first: a perk outside your committed tree cannot be bought at any level or price
    if not treeOpenFor(st, p) then
        local chosen = treeOf(st, side)
        notify(src, Locale.differentTreeTitle, chosen
            and Locale.committedTo:format(
                (CAT[chosen] and CAT[chosen].label) or chosen, sideLabel:lower())
            or Locale.chooseTreeFirst:format(sideLabel:lower()), 'red')
        return
    end

    -- prerequisite before anything else it could cost you
    local reqOk, reqText = requiresMet(st, p)
    if not reqOk then
        notify(src, Locale.lockedTitle, Locale.lockedPrereq:format(reqText, p.name), 'red')
        return
    end

    local nextRank = rank + 1
    local lvl      = levelOfSide(st, side)
    local need     = rankReq(p, nextRank)
    if lvl < need then
        notify(src, Locale.lockedTitle,
            Locale.rankNeedsLevel:format(p.name, nextRank, sideLabel, need), 'red')
        return
    end

    local cost = tonumber(p.ranks[nextRank].cost) or 0
    if pointsFree(st, side) < cost then
        notify(src, Locale.notEnoughPointsTitle,
            Locale.rankCosts:format(nextRank, cost, sideLabel:lower(), cost == 1 and '' or 's'), 'red')
        return
    end

    st.ranks[perkId] = nextRank
    st.eff = resolve(st)
    save(src)
    push(src)
    repaint(src)

    dbg('upgrade src=%s perk=%s -> rank %d (cost %d)', src, perkId, nextRank, cost)
    notify(src, p.name,
        nextRank == 1 and Locale.perkUnlocked or Locale.upgradedTo:format(nextRank), 'gold')
end)

RegisterNetEvent('pup-perks:equip', function(perkId)
    local src = source
    local st  = cache[src]
    local p   = PERK[perkId]
    if not st or not p then return end
    if tooFast(src) then return end

    -- nothing to equip when every unlocked perk is already live
    if Config.Cards.autoEquip ~= false then
        notify(src, p.name, Locale.autoEquipOn, 'gold')
        return
    end

    if (st.ranks[perkId] or 0) < 1 then
        notify(src, Locale.lockedTitle, Locale.notUnlocked:format(p.name), 'red')
        return
    end

    -- already equipped -> unequip
    for i, id in ipairs(st.equipped) do
        if id == perkId then
            table.remove(st.equipped, i)
            st.eff = resolve(st)
            save(src); push(src); repaint(src)
            dbg('unequip src=%s perk=%s', src, perkId)
            notify(src, p.name, Locale.unequipped, 'gold')
            return
        end
    end

    -- TYPED SLOTS
    local kind    = slotTypeOf(p)
    local cap     = slotCap(kind)
    local inUse   = equippedCount(st, kind)

    if cap <= 0 then
        notify(src, p.name, Locale.noSlotKind, 'red')
        return
    end
    if inUse >= cap then
        if kind == 'special' then
            notify(src, Locale.specialTakenTitle,
                Locale.specialTaken, 'red')
        else
            notify(src, Locale.noFreeSlotTitle,
                Locale.noFreeSlot:format(cap), 'red')
        end
        return
    end

    st.equipped[#st.equipped + 1] = perkId
    st.eff = resolve(st)
    save(src); push(src); repaint(src)
    dbg('equip src=%s perk=%s (%s %d/%d)', src, perkId, kind, inUse + 1, cap)
    notify(src, p.name, Locale.equipped, 'gold')
end)

RegisterNetEvent('pup-perks:reset', function()
    local src = source
    local st  = cache[src]
    if not st then return end
    if tooFast(src) then return end

    if not Config.Reset.enabled then
        notify(src, Locale.unavailableTitle, Locale.resetsDisabled, 'red')
        return
    end

    -- a committed tree alone is worth resetting even with nothing bought yet
    if next(st.ranks) == nil and not st.civtree and not st.crimetree then
        notify(src, Locale.nothingToResetTitle, Locale.nothingSpentOrChosen, 'red')
        return
    end

    local cost = tonumber(Config.Reset.price) or 0
    local Character
    if cost > 0 then
        local user = core().getUser(src)
        Character = user and user.getUsedCharacter
        if not Character then return end
        if (tonumber(Character.money) or 0) < cost then
            notify(src, Locale.cannotAffordTitle, Locale.resetCosts:format(cost), 'red')
            return
        end
    end

    -- charge only once every check has passed
    if cost > 0 and Character then Character.removeCurrency(0, cost) end

    local refundCiv   = pointsSpent(st, 'civ')
    local refundCrime = pointsSpent(st, 'crime')
    st.ranks     = {}
    st.equipped  = {}
    st.civtree   = nil   -- the whole point of a reset: pick your trees again
    st.crimetree = nil
    st.eff       = resolve(st)
    save(src); push(src); repaint(src)

    dbg('reset src=%s refunded civ=%d crime=%d cost=%d', src, refundCiv, refundCrime, cost)
    notify(src, Locale.resetDoneTitle,
        Locale.resetDone
            :format(refundCiv, refundCrime, (refundCiv + refundCrime) == 1 and '' or 's'), 'gold')
end)

-- Commit to a tree
RegisterNetEvent('pup-perks:chooseTree', function(catKey)
    local src = source
    local st  = cache[src]
    if not st then return end
    if tooFast(src) then return end

    local c = CAT[catKey]
    if not c or not CAT_HAS_PERKS[catKey] then return end
    if c.side ~= 'civ' and c.side ~= 'crime' then
        notify(src, Locale.alwaysOpenTitle, Locale.alwaysOpen:format(c.label), 'red')
        return
    end

    local sideLabel = Config.Trees.sideLabels[c.side] or c.side
    local current = treeOf(st, c.side)
    if current then
        notify(src, Locale.alreadyCommittedTitle,
            Locale.alreadyCommitted
                :format(sideLabel:lower(), (CAT[current] and CAT[current].label) or current), 'red')
        return
    end

    if c.side == 'crime' then st.crimetree = catKey else st.civtree = catKey end
    save(src); repaint(src)

    dbg('tree src=%s side=%s -> %s', src, c.side, catKey)
    notify(src, Locale.treeTitle:format(sideLabel, c.label),
        Locale.treeCommitted:format(c.label), 'gold')
end)

-- SWITCH SPECIALIST - distinct from chooseTree (first commitment) and the weekly reset
RegisterNetEvent('pup-perks:switchTree', function(catKey)
    local src = source
    local st  = cache[src]
    if not st then return end
    if tooFast(src) then return end

    local c = CAT[catKey]
    if not c or not CAT_HAS_PERKS[catKey] then return end
    if c.side ~= 'civ' and c.side ~= 'crime' then
        notify(src, Locale.alwaysOpenTitle, Locale.alwaysOpen:format(c.label), 'red')
        return
    end

    local side      = c.side
    local sideLabel = Config.Trees.sideLabels[side] or side
    local current   = treeOf(st, side)

    if not current then
        -- nothing committed yet: this is a first choice, not a switch
        if side == 'crime' then st.crimetree = catKey else st.civtree = catKey end
        save(src); repaint(src)
        notify(src, Locale.treeTitle:format(sideLabel, c.label), Locale.specialistChosen, 'gold')
        return
    end
    if current == catKey then
        notify(src, Locale.alreadySpecialistTitle, Locale.alreadySpecialist:format(c.label), 'red')
        return
    end

    -- clear only THIS side's perks; the other side keeps everything
    local lost = pointsSpent(st, side)

    -- the cleared points come back when switching back, so a switch with points
    -- spent uses up the free weekly reset like any other respec
    local now = os.time()
    if lost > 0 then
        local ready = resetReadyAt(st)
        if now < ready then
            local left = ready - now
            local d, h = math.floor(left / 86400), math.floor((left % 86400) / 3600)
            notify(src, Locale.notYetTitle, Locale.nextFreeReset:format(d, h), 'red')
            return
        end
        st.lastreset = now
    end

    for id in pairs(st.ranks) do
        local p = PERK[id]
        if p and p.side == side then st.ranks[id] = nil end
    end
    for i = #st.equipped, 1, -1 do
        local p = PERK[st.equipped[i]]
        if p and p.side == side then table.remove(st.equipped, i) end
    end

    -- the base only matters while no tree is committed; a specialist's level is read from that tree's own banked xp
    if side == 'crime' then st.crimebase = 0 else st.civbase = 0 end
    if side == 'crime' then st.crimetree = catKey else st.civtree = catKey end

    st.eff = resolve(st)
    save(src); push(src); repaint(src)

    dbg('switch src=%s side=%s %s -> %s (cleared %d spent)', src, side, current, catKey, lost)
    notify(src, Locale.treeTitle:format(sideLabel, c.label),
        Locale.specialistChanged
            :format(lost, lost == 1 and '' or 's', sideLabel:lower()), 'gold')
end)

-- Weekly reset (respec, keeping your specialist): refunds every point invested
RegisterNetEvent('pup-perks:weeklyReset', function()
    local src = source
    local st  = cache[src]
    if not st then return end
    if tooFast(src) then return end

    if not Config.Reset.enabled then
        notify(src, Locale.unavailableTitle, Locale.resetsDisabled, 'red')
        return
    end

    local now   = os.time()
    local ready = resetReadyAt(st)
    if now < ready then
        local left = ready - now
        local d, h = math.floor(left / 86400), math.floor((left % 86400) / 3600)
        notify(src, Locale.notYetTitle,
            Locale.nextFreeReset:format(d, h), 'red')
        return
    end

    local refund = pointsSpent(st, nil)
    if refund <= 0 then
        notify(src, Locale.nothingToResetTitle, Locale.nothingSpent, 'red')
        return
    end

    -- ranks go, specialists and xp STAY - that is the whole difference between this and the full reset below
    st.ranks    = {}
    st.equipped = {}
    st.lastreset = now
    st.eff      = resolve(st)
    save(src); push(src); repaint(src)

    dbg('weeklyReset src=%s refunded=%d', src, refund)
    notify(src, Locale.resetDoneTitle,
        Locale.weeklyResetDone
            :format(refund, refund == 1 and '' or 's'), 'gold')
end)

-- Admin bridge (vorp_admin's Perks page): works on a character id, online or offline

local function sourceOf(charid)
    for src, st in pairs(cache) do
        if st.charid == charid then return src end
    end
    return nil
end

-- Load the character (cache when online, DB when not), hand it to `mutate`, and persist + resync whatever that changed
local function adminApply(charid, mutate)
    charid = tonumber(charid)
    if not charid then return { ok = false, err = 'bad character id' } end

    local src = sourceOf(charid)
    local st = src and cache[src] or readState(charid)
    if not st then return { ok = false, err = 'no perk record' } end

    local res = mutate(st)
    if type(res) == 'table' and res.ok == false then return res end

    -- taking points away can drop a character below their equipped slot count
    local maxSlots = slotsAtLevel(levelOf(st))
    while #st.equipped > maxSlots do table.remove(st.equipped) end
    st.eff = resolve(st)

    writeState(st)
    if src then
        push(src)
        repaint(src)
    end
    return type(res) == 'table' and res or { ok = true }
end

-- One row per character that has ever earned anything, newest activity first
local function adminList(search)
    local rows
    search = (type(search) == 'string') and search:gsub('^%s+', ''):gsub('%s+$', '') or ''

    local COLS <const> = [[
        SELECT p.charidentifier, p.civxp, p.crimexp, p.bonusciv, p.bonuscrime,
               p.civtree, p.crimetree, p.ranks, p.equipped,
               c.firstname, c.lastname
        FROM perks p
        LEFT JOIN characters c ON c.charidentifier = p.charidentifier
    ]]

    if search ~= '' then
        local like = '%' .. search .. '%'
        rows = MySQL.query.await(COLS .. [[
            WHERE c.firstname LIKE ? OR c.lastname LIKE ?
               OR CONCAT(c.firstname, ' ', c.lastname) LIKE ?
               OR p.charidentifier = ?
            ORDER BY (p.civxp + p.crimexp) DESC
            LIMIT 60
        ]], { like, like, like, tonumber(search) or -1 })
    else
        rows = MySQL.query.await(COLS .. [[
            ORDER BY (p.civxp + p.crimexp) DESC
            LIMIT 60
        ]], {})
    end

    local out = {}
    for _, r in ipairs(rows or {}) do
        local charid = tonumber(r.charidentifier)

        -- an online character's cache is authoritative; the row may be a moment stale
        local src = sourceOf(charid)
        local st = src and cache[src] or nil

        local civxp      = st and st.civxp or (tonumber(r.civxp) or 0)
        local crimexp    = st and st.crimexp or (tonumber(r.crimexp) or 0)
        local bonusciv   = st and st.bonusciv or (tonumber(r.bonusciv) or 0)
        local bonuscrime = st and st.bonuscrime or (tonumber(r.bonuscrime) or 0)
        local civtree    = st and st.civtree or r.civtree
        local crimetree  = st and st.crimetree or r.crimetree

        local ranks = st and st.ranks or nil
        if not ranks then
            ranks = {}
            if r.ranks then
                local ok, decoded = pcall(json.decode, r.ranks)
                if ok and type(decoded) == 'table' then
                    for id, rk in pairs(decoded) do
                        if PERK[id] then ranks[id] = tonumber(rk) or 0 end
                    end
                end
            end
        end

        -- spend is tallied PER SIDE, the same split the player sees
        local spentCiv, spentCrime, owned = 0, 0, 0
        for id, rk in pairs(ranks) do
            local p = PERK[id]
            if p and rk > 0 then
                local s = spentOn(p, rk)
                if p.side == 'crime' then spentCrime = spentCrime + s else spentCiv = spentCiv + s end
                owned = owned + 1
            end
        end

        local civLvl   = levelForXP(civxp)
        local crimeLvl = levelForXP(crimexp)
        local treeLabel = function(k) return k and ((CAT[k] and CAT[k].label) or k) or nil end

        out[#out + 1] = {
            charid     = charid,
            name       = ((r.firstname or '') .. ' ' .. (r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
            online     = src ~= nil,
            civLevel   = civLvl,
            crimeLevel = crimeLvl,
            civxp      = civxp,
            crimexp    = crimexp,
            xp         = civxp + crimexp,
            civPoints   = pointsAtLevel(civLvl) + bonusciv - spentCiv,
            crimePoints = pointsAtLevel(crimeLvl) + bonuscrime - spentCrime,
            bonusciv    = bonusciv,
            bonuscrime  = bonuscrime,
            civTree     = treeLabel(civtree),
            crimeTree   = treeLabel(crimetree),
            owned       = owned,
        }
    end
    return out
end

-- Full detail for one character: their level, both xp pools, and every perk they own with its current rank
local function adminGet(charid)
    charid = tonumber(charid)
    if not charid then return nil end

    local src = sourceOf(charid)
    local st = src and cache[src] or readState(charid)
    if not st then return nil end

    local row = MySQL.single.await(
        'SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { charid })

    local perks = {}
    for _, p in ipairs(Config.Perks) do
        local rank = st.ranks[p.id] or 0
        if rank > 0 then
            local isEquipped = false
            for _, id in ipairs(st.equipped) do
                if id == p.id then isEquipped = true break end
            end
            perks[#perks + 1] = {
                id = p.id, name = p.name, cat = p.cat, glyph = p.glyph,
                side = p.side, sideLabel = Config.Trees.sideLabels[p.side] or p.side,
                rank = rank, maxRank = maxLevelOf(p),
                spent = spentOn(p, rank), equipped = isEquipped,
            }
        end
    end

    local treeLabel = function(k) return k and ((CAT[k] and CAT[k].label) or k) or nil end

    return {
        charid   = charid,
        name     = row and ((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '') or '',
        online   = src ~= nil,
        maxLevel = MAX_LEVEL,
        xp       = totalXP(st),
        -- each side keeps its own level, pool and tree; nothing is combined
        civ = {
            label = Config.Trees.sideLabels.civ, level = levelOfSide(st, 'civ'),
            xp = st.civxp, points = pointsFree(st, 'civ'),
            spent = pointsSpent(st, 'civ'), bonus = bonusOf(st, 'civ'),
            tree = st.civtree, treeLabel = treeLabel(st.civtree),
        },
        crime = {
            label = Config.Trees.sideLabels.crime, level = levelOfSide(st, 'crime'),
            xp = st.crimexp, points = pointsFree(st, 'crime'),
            spent = pointsSpent(st, 'crime'), bonus = bonusOf(st, 'crime'),
            tree = st.crimetree, treeLabel = treeLabel(st.crimetree),
        },
        slots    = slotsAtLevel(levelOf(st)),
        equipped = #st.equipped,
        perks    = perks,
    }
end

exports('adminPerkList', adminList)
exports('adminPerkGet', adminGet)

-- Grant or take perk points ON ONE SIDE
exports('adminAdjustPoints', function(charid, side, delta)
    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return { ok = false, err = 'no amount given' } end
    if side ~= 'civ' and side ~= 'crime' then return { ok = false, err = 'side must be civ or crime' } end

    return adminApply(charid, function(st)
        local free = pointsFree(st, side)
        local applied = delta
        if delta < 0 and (free + delta) < 0 then applied = -free end
        if applied == 0 then
            return { ok = false, err = 'that side has no unspent points to take' }
        end

        if side == 'crime' then
            st.bonuscrime = (st.bonuscrime or 0) + applied
        else
            st.bonusciv = (st.bonusciv or 0) + applied
        end

        local label = Config.Trees.sideLabels[side] or side
        local src = sourceOf(st.charid)
        if src then
            notify(src, Locale.adminPointsTitle,
                applied > 0 and Locale.adminGrantedPoints:format(applied, label:lower(), applied == 1 and '' or 's')
                             or Locale.adminRemovedPoints:format(-applied, label:lower(), applied == -1 and '' or 's'),
                applied > 0 and 'gold' or 'red')
        end
        dbg('admin: charid=%s %s points %+d (asked %+d)', st.charid, side, applied, delta)
        return { ok = true, applied = applied }
    end)
end)

-- Grant xp on a track
exports('adminAddXP', function(charid, track, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return { ok = false, err = 'no amount given' } end
    if track ~= 'civ' and track ~= 'crime' then return { ok = false, err = 'track must be civ or crime' } end

    return adminApply(charid, function(st)
        local field = track == 'civ' and 'civxp' or 'crimexp'
        local before = levelOfSide(st, track)
        st[field] = math.max(0, st[field] + amount)

        -- and into the committed tree, the same as earned xp: the level is read from that bucket
        local tree = treeOf(st, track)
        if tree then
            st.treexp = st.treexp or {}
            st.treexp[tree] = math.max(0, (tonumber(st.treexp[tree]) or 0) + amount)
        end

        local after = levelOfSide(st, track)

        local src = sourceOf(st.charid)
        if src then
            notify(src, Locale.adminXpTitle,
                amount > 0 and Locale.adminGrantedXp:format(amount, track == 'civ' and Locale.xpNameCiv or Locale.xpNameCrime)
                            or Locale.adminRemovedXp:format(-amount, track == 'civ' and Locale.xpNameCiv or Locale.xpNameCrime),
                amount > 0 and 'gold' or 'red')
        end
        dbg('admin: charid=%s %s xp %+d (level %d -> %d)', st.charid, track, amount, before, after)
        return { ok = true, level = after }
    end)
end)

-- Wipe every rank, equip AND both tree choices
exports('adminResetPerks', function(charid)
    return adminApply(charid, function(st)
        local hadCiv, hadCrime = st.civxp or 0, st.crimexp or 0

        st.civxp      = 0
        st.crimexp    = 0
        st.bonusciv   = 0
        st.bonuscrime = 0
        st.civbase    = 0
        st.crimebase  = 0
        st.ranks      = {}
        st.equipped   = {}
        st.civtree    = nil
        st.crimetree  = nil
        st.lastreset  = 0
        -- levels are read from here, so it is cleared too
        st.treexp     = {}

        local src = sourceOf(st.charid)
        if src then
            notify(src, Locale.adminWipedTitle,
                Locale.adminWiped,
                'gold')
        end
        dbg('admin: charid=%s FULL WIPE (was %d civ / %d crime xp)', st.charid, hadCiv, hadCrime)
        return { ok = true, wiped = true, civxp = hadCiv, crimexp = hadCrime }
    end)
end)
