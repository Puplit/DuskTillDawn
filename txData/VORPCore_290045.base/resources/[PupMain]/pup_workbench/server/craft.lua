-- Crafting: start (token), finish, delivery, tool wear, the timed queue and collection.
Craft = {}

local tokens = {}   -- token -> { src, charid, recipeId, amount, desc, ctx, at }

-- CONTEXT: where the client says the bench was opened. Never trusted on its own:
-- every mode is checked against the player's real position on the server.
function Craft.cleanCtx(ctx)
    if type(ctx) ~= 'table' then return { mode = 'none' } end
    if ctx.mode == 'station' and type(ctx.name) == 'string' then
        return { mode = 'station', name = ctx.name:sub(1, 64) }
    elseif ctx.mode == 'prop' and type(ctx.model) == 'string' and type(ctx.pos) == 'table' then
        local x, y, z = tonumber(ctx.pos.x), tonumber(ctx.pos.y), tonumber(ctx.pos.z)
        if x and y and z then
            return { mode = 'prop', model = ctx.model:lower():sub(1, 64), pos = { x = x, y = y, z = z } }
        end
    elseif ctx.mode == 'kit' and type(ctx.item) == 'string' then
        return { mode = 'kit', item = ctx.item:sub(1, 64) }
    end
    return { mode = 'none' }
end

local function nearProp(pos, ctx, allowed)
    if ctx.mode ~= 'prop' or not Config.StationProps[ctx.model] then return false end
    if allowed and not WB.listHas(allowed, ctx.model) then return false end
    return WB.dist(pos, ctx.pos) <= Config.Server.propReach
end

local function hasKit(src, ctx)
    if ctx.mode ~= 'kit' or not Config.Kits[ctx.item] then return false end
    return (tonumber(Inv:getItemCount(src, nil, ctx.item)) or 0) > 0
end

--- The server checks the bench too, not only named stations.
--- Returns true, or false + violation reason.
local function placeOk(src, r, ctx)
    local pos = PlayerPos(src)
    if not pos then return false, ('recipe %d with no position'):format(r.id) end
    if r.stations then
        if Stations.near(pos, Config.Server.stationReach, r.stations) then return true end
        return false, ('recipe %d away from its station'):format(r.id)
    end
    if r.props then
        if nearProp(pos, ctx, r.props) then return true end
        return false, ('recipe %d away from its prop'):format(r.id)
    end
    if nearProp(pos, ctx, nil) or hasKit(src, ctx) then return true end
    if ctx.mode == 'station' and Stations.near(pos, Config.Server.stationReach, nil) then return true end
    return false, ('recipe %d away from any bench'):format(r.id)
end

local function count(src, name)
    return tonumber(Inv:getItemCount(src, nil, name)) or 0
end

local function materialsOk(src, r, amount)
    for _, m in ipairs(r.materials) do
        if count(src, m.name) < m.count * amount then return false end
    end
    return true
end

local function toolsOk(src, r)
    for _, t in ipairs(r.tools) do
        if count(src, t.name) < t.count then return false, t.label end
    end
    return true
end

local function cleanDescription(desc)
    if not Config.Descriptions.enabled or type(desc) ~= 'string' then return nil end
    desc = WB.trim(WB.cut(desc, 4000))
    if desc == '' then return nil end
    if WB.hasBannedWord(desc) then return false end
    -- cut BEFORE sanitising, so the cut can never leave half a tag behind
    desc = WB.cut(desc, Config.Descriptions.maxLength)
    local ok, clean = pcall(function() return Inv:SanitizeDescription(desc) end)
    if not ok or type(clean) ~= 'string' then
        clean = desc:gsub('<[^>]*>', ''):gsub('<', ''):gsub('>', '')
    end
    clean = WB.trim(clean)
    if clean == '' then return nil end
    return clean
end

--- Every reward must be an item vorp_inventory has loaded. Items the bench adds to the
--- items table only load when vorp_inventory restarts; until then they cannot be given.
local function rewardsKnown(lines)
    for _, l in ipairs(lines) do
        local ok, def = pcall(function() return Inv:getItemDB(l.name) end)
        if not ok or type(def) ~= 'table' then
            Warn('reward item %s is not loaded in vorp_inventory (restart vorp_inventory)', tostring(l.name))
            return false
        end
    end
    return true
end

local function totalSeconds(r, amount)
    local t = math.floor(Recipes.secondsPerUnit(r) * amount)
    return math.max(1, math.min(Config.Timed.batchCapSeconds, t))
end

local function runningCount(charid)
    local sql = Config.Timed.countReadyTowardLimit
        and 'SELECT COUNT(*) FROM crafting_queue WHERE charidentifier = ? AND claimed = 0'
        or 'SELECT COUNT(*) FROM crafting_queue WHERE charidentifier = ? AND claimed = 0 AND ready_at > ?'
    return tonumber(MySQL.scalar.await(sql, { charid, os.time() })) or 0
end

local function newToken()
    return ('%08x%08x%04x'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff), math.random(0, 0xffff))
end

-- START
function Craft.start(src, who, payload)
    if type(payload) ~= 'table' then return { ok = false, msg = L('cannot_craft') } end
    local r = Recipes.byId[WB.int(payload.id) or -1]
    if not r then return { ok = false, msg = L('recipe_gone') } end
    local amount = WB.int(payload.amount)
    if not amount or amount < 1 then return { ok = false, msg = L('not_amount') } end
    amount = math.min(amount, Config.MaxUnitsPerCraft)
    local ctx = Craft.cleanCtx(payload.ctx)

    local xp = Progress.getXp(who.charid)
    -- the read above waited on the database: is this still the same character?
    local now = Who(src)
    if not now or now.charid ~= who.charid then return { ok = false, msg = L('cannot_craft') } end

    local state, reason = Recipes.access(r, who, xp)
    if state ~= 'ok' then
        LogViolation(src, who, ('recipe %d not allowed'):format(r.id))
        return { ok = false, msg = reason or L('cannot_craft') }
    end
    local placed, why = placeOk(src, r, ctx)
    if not placed then
        LogViolation(src, who, why)
        return { ok = false, msg = L('cannot_here') }
    end
    if not materialsOk(src, r, amount) then return { ok = false, msg = L('no_materials') } end
    local tOk, tLabel = toolsOk(src, r)
    if not tOk then return { ok = false, msg = L('need_tool', tLabel) } end
    if not rewardsKnown(r.rewards) then return { ok = false, msg = L('cannot_craft') } end

    local desc = cleanDescription(payload.desc)
    if desc == false then return { ok = false, msg = L('banned_words') } end

    if Config.Timed.enabled then
        local n = runningCount(who.charid)
        if n >= Config.Timed.maxRunning then return { ok = false, msg = L('too_many_running', n) } end
        local again = Who(src)
        if not again or again.charid ~= who.charid then return { ok = false, msg = L('cannot_craft') } end
    end

    -- one craft in flight per player: a new start replaces an older token
    for tok, t in pairs(tokens) do
        if t.src == src then tokens[tok] = nil end
    end
    local token = newToken()
    tokens[token] = {
        src = src, charid = who.charid, recipeId = r.id, amount = amount,
        desc = desc, ctx = ctx, at = os.time(),
    }
    return { ok = true, token = token, diff = r.diff or Config.DefaultDifficulty, seconds = totalSeconds(r, amount) }
end

function Craft.cancel(src, token)
    local t = type(token) == 'string' and tokens[token]
    if t and t.src == src then tokens[token] = nil end
    return { ok = true }
end

-- DELIVERY
local function satchelFits(src, rewards)
    for _, rw in ipairs(rewards) do
        if not Inv:canCarryItem(src, rw.name, rw.count) then return false end
    end
    return true
end

local function stillSame(src, who)
    local now = Who(src)
    return now ~= nil and now.charid == who.charid
end

--- Box first (when on), then the satchel only if everything fits.
--- Returns 'box', 'satchel' or nil.
local function deliver(src, who, rewards, metadata)
    if not stillSame(src, who) then return nil end
    if Config.Box.enabled and Box.deposit(src, who, rewards, metadata) then return 'box' end
    if not stillSame(src, who) or not satchelFits(src, rewards) then return nil end
    for i, rw in ipairs(rewards) do
        if not Inv:addItem(src, rw.name, rw.count, metadata) then
            if i == 1 then return nil end -- nothing handed over yet: the caller keeps the goods
            Warn('character %d: %dx %s could not be added to the satchel', who.charid, rw.count, rw.name)
        end
    end
    return 'satchel'
end

local function queueInsert(who, label, category, amount, rewards, exp, metadata, readyAt)
    local ok, id = pcall(MySQL.insert.await,
        [[INSERT INTO crafting_queue (charidentifier, label, catagory, count, rewards, exp, metadata, queued_at, ready_at, claimed)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)]],
        { who.charid, WB.cut(label, 96), WB.cut(category, 64), amount, json.encode(rewards), exp,
          metadata and json.encode(metadata) or '', os.time(), readyAt })
    return ok and id and id > 0
end

local function refund(src, lines)
    for _, l in ipairs(lines) do Inv:addItem(src, l.name, l.count) end
end

-- TOOL WEAR
local function conditionText(desc, remaining)
    local prefix = L('condition_prefix')
    local line = prefix .. tostring(remaining)
    if type(desc) ~= 'string' or desc == '' then return line end
    local pat = prefix:gsub('%p', '%%%0') .. '%d+'
    if desc:find(pat) then
        return (desc:gsub(pat, line, 1))
    end
    return desc .. Config.ToolWear.conditionSeparator .. line
end

local function wearTools(src, r, amount)
    if not Config.ToolWear.enabled then return end
    local inv
    for _, t in ipairs(r.tools) do
        local maxD = Config.ToolWear.tools[t.name]
        if maxD then
            inv = inv or Inv:getUserInventoryItems(src) or {}
            local best, bestD
            for _, it in ipairs(inv) do
                if it.name == t.name then
                    local d = tonumber(type(it.metadata) == 'table' and it.metadata.durability) or maxD
                    if not bestD or d < bestD then best, bestD = it, d end
                end
            end
            if best then
                local drain = tonumber(Config.ToolWear.overrides[t.name]) or Config.ToolWear.drain
                if Config.ToolWear.perUnit then drain = drain * amount end
                local remaining = math.floor(bestD - drain)
                if remaining <= 0 then
                    Inv:subItemById(src, best.id, nil, nil, 1)
                    Notify(src, L('tool_broke', t.label), 5000)
                else
                    local meta = {}
                    if type(best.metadata) == 'table' then
                        for k, v in pairs(best.metadata) do meta[k] = v end
                    end
                    meta.durability = remaining
                    meta.description = conditionText(meta.description, remaining)
                    Inv:setItemMetadata(src, best.id, meta, 1)
                    -- a single item keeps its id; a split stack gets a new one we cannot see yet
                    if (tonumber(best.count) or 1) <= 1 then
                        local pct = math.max(0, math.min(100, math.floor(remaining / maxD * 100)))
                        Inv:setItemDurability(src, best.id, pct)
                    end
                end
                inv = nil -- ids may have changed; read again for the next tool
            end
        end
    end
end

-- FINISH
function Craft.finish(src, who, token)
    local t = type(token) == 'string' and tokens[token] or nil
    if not t or t.src ~= src then
        LogViolation(src, who, 'unknown or reused craft token')
        return { ok = false, msg = L('cannot_craft') }
    end
    tokens[token] = nil -- spent first: one token, one craft
    if os.time() - t.at > Config.TokenLifetime then return { ok = false, msg = L('cannot_craft') } end

    -- the craft belongs to the character who started it
    if t.charid ~= who.charid then return { ok = false, msg = L('cannot_craft') } end
    local r = Recipes.byId[t.recipeId]
    if not r then return { ok = false, msg = L('recipe_gone') } end
    local amount = t.amount

    local xp = Progress.getXp(who.charid)
    if not stillSame(src, who) then return { ok = false, msg = L('cannot_craft') } end
    local state, reason = Recipes.access(r, who, xp)
    if state ~= 'ok' then return { ok = false, msg = reason or L('cannot_craft') } end
    if not placeOk(src, r, t.ctx) then return { ok = false, msg = L('cannot_here') } end
    if not materialsOk(src, r, amount) then return { ok = false, msg = L('no_materials') } end
    local tOk, tLabel = toolsOk(src, r)
    if not tOk then return { ok = false, msg = L('need_tool', tLabel) } end

    local mult = 1
    if PerkRoll(src, 'craft_double') then
        mult = 2
        Notify(src, L('double_yield'), 4000)
    end
    local rewards = {}
    for _, rw in ipairs(r.rewards) do
        local n = rw.count * amount * mult
        if n > 0 then rewards[#rewards + 1] = { name = rw.name, count = n } end
    end

    if not rewardsKnown(rewards) then return { ok = false, msg = L('cannot_craft') } end
    if not Config.Box.enabled and not Config.Timed.enabled and not satchelFits(src, rewards) then
        return { ok = false, msg = L('cannot_carry') }
    end

    -- take the materials; any failure puts back what was taken
    local used, taken = {}, {}
    for _, m in ipairs(r.materials) do
        local n = m.count * amount
        used[#used + 1] = { name = m.name, count = n }
        if not Inv:subItem(src, m.name, n) then
            refund(src, taken)
            return { ok = false, msg = L('no_materials') }
        end
        taken[#taken + 1] = { name = m.name, count = n }
    end
    wearTools(src, r, amount)

    LogCraft(who, rewards, used, r.title)
    PerkAward(src, 'craft')

    local earned = r.expadd * amount * ((Config.Rules.perkDoublesXp and mult) or 1)
    local metadata = t.desc and { description = t.desc, crafter = who.charid } or nil
    local label = (r.title ~= '' and r.title) or 'Craft'

    if Config.Timed.enabled then
        local total = totalSeconds(r, amount)
        if queueInsert(who, label, r.category, amount, rewards, earned, metadata, os.time() + total) then
            return { ok = true, msg = L('started', WB.fmtTime(total)), queued = true }
        end
        Warn('queue write failed for character %d, delivering now', who.charid)
    end

    local where = deliver(src, who, rewards, metadata)
    if where then
        Progress.addXp(who.charid, r.category, earned)
        return { ok = true, msg = where == 'box' and L('crafted_box') or L('crafted') }
    end
    -- nowhere to put it: keep it on the shelf, ready now
    if queueInsert(who, label, r.category, amount, rewards, earned, metadata, os.time()) then
        return { ok = true, msg = L('kept_pending'), queued = true }
    end
    refund(src, taken)
    return { ok = false, msg = L('cannot_carry') }
end

-- THE PENDING SHELF
function Craft.pending(charid)
    local rows = MySQL.query.await(
        [[SELECT id, label, catagory, count, rewards, queued_at, ready_at FROM crafting_queue
          WHERE charidentifier = ? AND claimed = 0 ORDER BY ready_at ASC, id ASC]], { charid }) or {}
    local out = {}
    for _, row in ipairs(rows) do
        local first
        local ok, list = pcall(json.decode, row.rewards or '[]')
        if ok and type(list) == 'table' and type(list[1]) == 'table' then first = list[1].name end
        out[#out + 1] = {
            id = row.id, label = row.label, category = row.catagory, count = row.count,
            img = first, queued = row.queued_at, ready = row.ready_at,
        }
    end
    return out
end

local function collectRow(src, who, row)
    local now = os.time()
    -- claimed is tinyint(1): oxmysql hands it back as a boolean, not 0/1
    if not row or WB.flag(row.claimed) then return false, L('craft_gone') end
    if (tonumber(row.ready_at) or 0) > now then return false, L('still_making') end

    local okR, rewards = pcall(json.decode, row.rewards or '[]')
    if not okR or type(rewards) ~= 'table' then return false, L('craft_gone') end
    local clean = {}
    for _, rw in ipairs(rewards) do
        local n = WB.int(type(rw) == 'table' and rw.count)
        if n and n > 0 and type(rw.name) == 'string' then clean[#clean + 1] = { name = rw.name, count = n } end
    end
    local metadata
    if type(row.metadata) == 'string' and row.metadata ~= '' then
        local okM, m = pcall(json.decode, row.metadata)
        if okM and type(m) == 'table' and next(m) then metadata = m end
    end

    if not rewardsKnown(clean) then return false, L('cannot_carry') end
    if not Config.Box.enabled and not satchelFits(src, clean) then return false, L('cannot_carry') end

    -- claim first, guarded, so it can only happen once
    local n = MySQL.update.await('UPDATE crafting_queue SET claimed = 1 WHERE id = ? AND charidentifier = ? AND claimed = 0',
        { row.id, who.charid })
    if (tonumber(n) or 0) ~= 1 then return false, L('craft_gone') end

    local where = deliver(src, who, clean, metadata)
    if not where then
        MySQL.update.await('UPDATE crafting_queue SET claimed = 0 WHERE id = ?', { row.id })
        return false, L('cannot_carry')
    end
    Progress.addXp(who.charid, row.catagory, tonumber(row.exp) or 0)
    return true, L('collected', row.label)
end

function Craft.collect(src, who, id)
    id = WB.int(id)
    if not id then return { ok = false, msg = L('craft_gone') } end
    local row = MySQL.single.await('SELECT * FROM crafting_queue WHERE id = ? AND charidentifier = ?', { id, who.charid })
    if not stillSame(src, who) then return { ok = false, msg = L('cannot_craft') } end
    local ok, msg = collectRow(src, who, row)
    return { ok = ok, msg = msg }
end

--- Try every ready craft, not just up to the first failure.
function Craft.collectAll(src, who)
    local rows = MySQL.query.await(
        'SELECT * FROM crafting_queue WHERE charidentifier = ? AND claimed = 0 AND ready_at <= ? ORDER BY ready_at ASC, id ASC',
        { who.charid, os.time() }) or {}
    if #rows == 0 then return { ok = false, msg = L('nothing_ready') } end
    local done, lastErr = 0, nil
    for _, row in ipairs(rows) do
        if not stillSame(src, who) then break end
        local ok, msg = collectRow(src, who, row)
        if ok then done = done + 1 else lastErr = msg end
    end
    if done > 0 then return { ok = true, msg = L('collected_n', done) } end
    return { ok = false, msg = lastErr or L('nothing_ready') }
end

-- HOUSEKEEPING
function Craft.dropPlayer(src)
    for tok, t in pairs(tokens) do
        if t.src == src then tokens[tok] = nil end
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        local cutoff = os.time() - Config.TokenLifetime
        for tok, t in pairs(tokens) do
            if t.at < cutoff then tokens[tok] = nil end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Timed.sweepEveryMs)
        if Server.ready then
            local cutoff = os.time() - Config.Timed.keepCollectedDays * 86400
            pcall(MySQL.update.await, 'DELETE FROM crafting_queue WHERE claimed = 1 AND ready_at < ?', { cutoff })
        end
    end
end)
