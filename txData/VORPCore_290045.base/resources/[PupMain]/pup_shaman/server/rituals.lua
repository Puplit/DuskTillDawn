-- pup_shaman | rituals: The Unbinding (lift a curse) and The Binding (give one)
-- The server runs every session; clients only show the scene and send presses.

Rituals = {}

local R <const> = Config.Ritual
local sessions = {}   -- id -> session
local member = {}     -- src -> session id (leader, target or helper)
local leaderRest = {} -- charId -> os.time() when they may lead again
local nextId = 0
local ticking = false

function Rituals.InSession(src)
    return member[src] ~= nil
end

-- tribe and rank -----------------------------------------------------------

--- The tribe and the highest rank the character's grade reaches, or nil.
local function rankOf(char)
    if not char then return nil end
    local tribe = Config.Tribes[char.job]
    if not tribe then return nil end
    local grade = tonumber(char.jobGrade) or 0
    local best
    for _, r in ipairs(tribe.ranks or {}) do
        if grade >= r.grade and (not best or r.grade > best.grade) then best = r end
    end
    if not best then return nil end
    return tribe, best
end

--- Price and offering for a ceremony: one source used for the quote, the check and the charge.
local function terms(tribe, kind)
    local lift = tribe.lift or {}
    if kind == 'lift' then
        return math.max(0, math.floor(tonumber(lift.price) or 0)), lift.offering or {}
    end
    local bind = tribe.bind or {}
    local price = bind.price
    if price == nil then price = lift.price end
    return math.max(0, math.floor(tonumber(price) or 0)), bind.offering or lift.offering or {}
end

local function listHas(list, key)
    for _, k in ipairs(list or {}) do
        if k == key then return true end
    end
    return false
end

local function itemCount(src, item)
    local ok, n = pcall(function() return exports.vorp_inventory:getItemCount(src, nil, item) end)
    return ok and tonumber(n) or 0
end

local function nearTree(pos)
    for _, t in ipairs(Config.Trees) do
        if #(pos - t.coords) <= R.treeReach then return true end
    end
    return false
end

local function money(char)
    return tonumber(char and char.money) or 0
end

-- leading -----------------------------------------------------------------

--- Every leading check. Returns char, tribe, rank, or nil after telling the player why.
local function mayLead(src)
    if not R.enabled or not Shaman.Online(src) then return nil end
    local char = Shaman.Character(src)
    if not char then return nil end
    local tribe, rank = rankOf(char)
    if not rank then
        Shaman.Notify(src, L('rit_no_rank'))
        return nil
    end
    if not rank.lead then
        Shaman.Notify(src, L('rit_cannot_lead', rank.title))
        return nil
    end
    if member[src] or Shaman.Form(src) or Trees.IsDreaming(src) then
        Shaman.Notify(src, L('rit_busy'))
        return nil
    end
    local restUntil = leaderRest[tonumber(char.charIdentifier)]
    local now = os.time()
    if restUntil and now < restUntil then
        Shaman.Notify(src, L('rit_rest', math.ceil((restUntil - now) / 60)))
        return nil
    end
    if R.needTree then
        local pos = Shaman.Coords(src)
        if not pos or not nearTree(pos) then
            Shaman.Notify(src, L('rit_need_tree'))
            return nil
        end
    end
    return char, tribe, rank
end

local function needsLine(src, offering, price)
    local parts = {}
    for _, o in ipairs(offering) do
        parts[#parts + 1] = L('rit_needs_item', o.label or o.item, itemCount(src, o.item), o.count)
    end
    local text = #parts > 0 and L('rit_needs', table.concat(parts, ', ')) or L('rit_needs_none')
    if price > 0 then text = text .. ' ' .. L('rit_pays', price) end
    return text
end

local function openMenu(src)
    local char, tribe, rank = mayLead(src)
    if not char then return end
    local options = {}

    local liftable = {}
    for _, k in ipairs(Rules.SortedCurseKeys(rank.lift or {})) do
        liftable[#liftable + 1] = Config.Curses[k].label
    end
    if #liftable > 0 then
        local price, offering = terms(tribe, 'lift')
        options[#options + 1] = {
            label = L('rit_opt_lift'),
            description = L('rit_opt_lift_desc', table.concat(liftable, ', ')) .. ' ' .. needsLine(src, offering, price),
            choice = 'lift',
        }
    end

    local bindPrice, bindOffering = terms(tribe, 'bind')
    for _, k in ipairs(Rules.SortedCurseKeys(rank.give or {})) do
        local label = Config.Curses[k].label
        options[#options + 1] = {
            label = L('rit_opt_give', label),
            description = L('rit_opt_give_desc', label) .. ' ' .. needsLine(src, bindOffering, bindPrice),
            choice = 'give:' .. k,
        }
    end

    if #options == 0 then
        return Shaman.Notify(src, L('rit_cannot_lead', rank.title))
    end
    TriggerClientEvent('pup_shaman:client:ritualMenu', src, L('rit_menu_title'), L('rit_menu_sub', rank.title, tribe.label), options)
end

if R.enabled then
    RegisterCommand(R.command, function(src)
        src = tonumber(src)
        if not src or src <= 0 or not Shaman.Throttle(src, 'ritualMenu', 1000) then return end
        openMenu(src)
    end, false)
end

-- scene -------------------------------------------------------------------

local function titleOf(s)
    return s.kind == 'lift' and L('rit_unbinding') or L('rit_binding')
end

local function helperList(s)
    local list = {}
    for h in pairs(s.helpers) do list[#list + 1] = h end
    return list
end

local function helperCount(s)
    local n = 0
    for _ in pairs(s.helpers) do n = n + 1 end
    return n
end

local function sceneOf(s)
    return {
        id = s.id, kind = s.kind, title = titleOf(s), stage = s.stage,
        center = s.center, marks = s.marks, walked = s.nextMark - 1,
        leader = s.leader, target = s.target, helpers = helperList(s),
    }
end

local function refresh(s)
    local scene = sceneOf(s)
    for v in pairs(s.viewers) do
        TriggerClientEvent('pup_shaman:client:ritualScene', v, scene)
    end
end

--- Removes the session and tells everyone who saw it.
local function close(s, outcome)
    if sessions[s.id] ~= s then return end
    sessions[s.id] = nil
    s.stage = 'closed'
    for src, id in pairs(member) do
        if id == s.id then member[src] = nil end
    end
    local told = {}
    for v in pairs(s.viewers) do told[v] = true end
    told[s.target] = true -- closes the ask menu if it is still up
    told[s.leader] = true
    for v in pairs(told) do
        TriggerClientEvent('pup_shaman:client:ritualEnd', v, s.id, outcome)
    end
end

local function broken(s)
    Shaman.Notify(s.leader, L('rit_broken'))
    Shaman.Notify(s.target, L('rit_broken'))
    close(s, 'broken')
end

local function gone(s)
    Shaman.Notify(s.leader, s.kind == 'lift' and L('rit_gone') or L('rit_has_curse'))
    close(s, 'gone')
end

local function chantLines(s)
    local key = s.kind == 'lift' and 'unbinding' or 'binding'
    return (s.tribe.chant and s.tribe.chant[key]) or R.chant[key]
end

local enter -- forward

local function nextVerse(s)
    s.verse = s.verse + 1
    local lines = chantLines(s)
    if s.verse > #lines then return enter(s, 'draw') end
    s.verseToken = math.random(1, 2147483647)
    s.verseAt = GetGameTimer()
    s.deadline = s.verseAt + R.verseSeconds * 1000
    s.answered = false
    local title, line = titleOf(s), lines[s.verse]
    for v in pairs(s.viewers) do
        TriggerClientEvent('pup_shaman:client:ritualVerse', v, s.id, title, line)
    end
    local width = math.min(s.rank.barWidth + R.helperWidth * helperCount(s), R.widestZone)
    TriggerClientEvent('pup_shaman:client:ritualBar', s.leader, s.id, s.verseToken, width, R.perfectZone, s.rank.barSpeed)
end

enter = function(s, stage)
    s.stage = stage
    local now = GetGameTimer()
    if stage == 'kindle' then
        s.deadline = now + R.kindleSeconds * 1000
        Shaman.Notify(s.leader, L('rit_kindle_leader'))
        Shaman.Notify(s.target, L('rit_kindle_target'))
    elseif stage == 'circle' then
        s.deadline = now + R.circleSeconds * 1000
        Shaman.Notify(s.leader, L('rit_circle'))
    elseif stage == 'draw' then
        s.deadline = now + R.drawSeconds * 1000
    end
    refresh(s)
    if stage == 'chant' then
        s.verse = 0
        nextVerse(s)
    end
end

-- outcomes ----------------------------------------------------------------

local function failed(s)
    Shaman.Notify(s.target, L('rit_failed_target'))
    Shaman.Notify(s.leader, L('rit_failed_leader'))
    TriggerClientEvent('pup_shaman:client:ritualBacklash', s.leader)
    close(s, 'failed')
end

--- Moves the price from the target to the leader. False if either is gone or the target is short.
local function charge(s)
    if s.price <= 0 then return true end
    local tchar, lchar = Shaman.Character(s.target), Shaman.Character(s.leader)
    if not tchar or not lchar or money(tchar) < s.price then return false end
    tchar.removeCurrency(0, s.price)
    lchar.addCurrency(0, s.price)
    return true
end

local function canPay(s)
    if s.price <= 0 then return true end
    local tchar, lchar = Shaman.Character(s.target), Shaman.Character(s.leader)
    return tchar ~= nil and lchar ~= nil and money(tchar) >= s.price
end

local function verdict(s)
    s.stage = 'verdict'
    local current = Store.Get(s.target)
    if sessions[s.id] ~= s then return end
    if current ~= s.expected then return gone(s) end
    local strength = s.points

    if s.kind == 'lift' then
        if strength >= R.liftAt then
            if not charge(s) then
                Shaman.Notify(s.leader, L('rit_cannot_pay'))
                return broken(s)
            end
            Store.Clear(s.target, 'quiet')
            Shaman.Notify(s.target, L('rit_lifted_target'))
            Shaman.Notify(s.leader, L('rit_lifted_leader', s.targetName))
            return close(s, 'lifted')
        end
        if strength >= R.easeAt and Rules.CourseOf(s.expected) and Store.Ease(s.target) then
            if sessions[s.id] ~= s then return end
            Shaman.Notify(s.target, L('rit_eased_target'))
            Shaman.Notify(s.leader, L('rit_eased_leader', s.targetName))
            return close(s, 'eased')
        end
        if sessions[s.id] ~= s then return end
        return failed(s)
    end

    -- binding: all or nothing
    if strength < R.liftAt then return failed(s) end
    if not canPay(s) then
        Shaman.Notify(s.leader, L('rit_cannot_pay'))
        return broken(s)
    end
    if not Store.Set(s.target, s.curse, 'quiet') then
        return broken(s)
    end
    if sessions[s.id] ~= s then return end
    charge(s)
    local label = Config.Curses[s.curse].label
    Shaman.Notify(s.target, L('rit_given_target', label))
    Shaman.Notify(s.leader, L('rit_given_leader', label, s.targetName))
    close(s, 'given')
end

-- the per-second check -----------------------------------------------------

local function eligible(s, src)
    if src == s.leader or src == s.target or member[src] then return false end
    if s.stage ~= 'kindle' and s.stage ~= 'circle' then return false end
    if helperCount(s) >= R.maxHelpers then return false end
    if Shaman.Form(src) or Trees.IsDreaming(src) then return false end
    local _, rank = rankOf(Shaman.Character(src))
    return rank ~= nil
end

local function tick(s)
    local now = GetGameTimer()
    local lchar, tchar = Shaman.Character(s.leader), Shaman.Character(s.target)
    if not lchar or not tchar
        or tonumber(lchar.charIdentifier) ~= s.leaderChar or tonumber(tchar.charIdentifier) ~= s.targetChar
        or not Shaman.Ped(s.leader) or not Shaman.Ped(s.target) then
        return broken(s)
    end

    if s.stage == 'ask' then
        if Shaman.Distance(s.leader, s.target) > R.stayRange then
            Shaman.Notify(s.leader, L('rit_broken'))
            return close(s, 'broken')
        end
        if now >= s.deadline then
            Shaman.Notify(s.leader, L('rit_no_answer', s.targetName))
            return close(s, 'refused')
        end
        return
    end
    if s.stage == 'accepting' then
        if now >= s.deadline then return broken(s) end
        return
    end
    if s.stage == 'verdict' then return end

    -- the leader lost the old ways (job or grade changed) mid-ritual
    local _, rank = rankOf(lchar)
    if not rank or not rank.lead then return broken(s) end
    if Shaman.IsDead(s.leader, lchar) or Shaman.IsDead(s.target, tchar) then return broken(s) end
    local lpos, tpos = Shaman.Coords(s.leader), Shaman.Coords(s.target)
    if not lpos or not tpos or #(lpos - s.center) > R.stayRange or #(tpos - s.center) > R.stayRange then
        return broken(s)
    end
    if Store.Peek(s.target) ~= s.expected then return gone(s) end

    -- helpers who left or walked away stop counting
    local changed = false
    for h in pairs(s.helpers) do
        local hpos = Shaman.Character(h) and Shaman.Coords(h)
        if not hpos or #(hpos - s.center) > R.stayRange then
            s.helpers[h] = nil
            if member[h] == s.id then member[h] = nil end
            changed = true
        end
    end

    -- new viewers get the scene; everyone's join prompt follows the live rules
    for _, p in ipairs(Shaman.Players()) do
        if not s.viewers[p] then
            local pos = Shaman.Coords(p)
            if pos and #(pos - s.center) <= R.viewRange then
                s.viewers[p] = true
                TriggerClientEvent('pup_shaman:client:ritualScene', p, sceneOf(s))
            end
        end
        if s.viewers[p] then
            local e = eligible(s, p)
            if s.joinable[p] ~= e then
                s.joinable[p] = e
                TriggerClientEvent('pup_shaman:client:ritualJoinable', p, s.id, e)
            end
        end
    end
    if changed then refresh(s) end

    if now < (s.deadline or 0) then return end
    if s.stage == 'kindle' then
        enter(s, 'circle')
    elseif s.stage == 'circle' then
        Shaman.Notify(s.leader, L('rit_circle_fail'))
        Shaman.Notify(s.target, L('rit_circle_fail'))
        close(s, 'broken')
    elseif s.stage == 'chant' then
        s.answered = true -- no answer in time scores nothing
        nextVerse(s)
    elseif s.stage == 'draw' then
        verdict(s)
    end
end

local function startTicker()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while next(sessions) do
            Wait(1000)
            local list = {}
            for _, s in pairs(sessions) do list[#list + 1] = s end
            for _, s in ipairs(list) do
                if sessions[s.id] == s then
                    local ok, err = pcall(tick, s)
                    if not ok then
                        print(('[pup_shaman] ritual %d failed: %s'):format(s.id, tostring(err)))
                        if sessions[s.id] == s then close(s, 'broken') end
                    end
                end
            end
        end
        ticking = false
    end)
end

-- choosing the person and asking -------------------------------------------

local function ask(src, char, tribe, rank, kind, target, curseKey)
    local price, offering = terms(tribe, kind)
    for _, o in ipairs(offering) do
        if itemCount(src, o.item) < o.count then
            return Shaman.Notify(src, L('rit_need_item', o.count, o.label or o.item))
        end
    end
    local tchar = Shaman.Character(target)
    if not tchar then return end
    if price > 0 and money(tchar) < price then
        return Shaman.Notify(src, L('rit_cannot_pay'))
    end
    -- the awaits above may have let someone else start something
    if member[src] or member[target] or not Shaman.SameChar(src, char.charIdentifier) then
        return Shaman.Notify(src, L('rit_busy'))
    end

    nextId = nextId + 1
    local s = {
        id = nextId, kind = kind, tribe = tribe, rank = rank,
        leader = src, leaderChar = tonumber(char.charIdentifier), leaderName = Shaman.FullName(char),
        target = target, targetChar = tonumber(tchar.charIdentifier), targetName = Shaman.FullName(tchar),
        curse = curseKey, expected = kind == 'lift' and curseKey or '',
        price = price, offering = offering,
        stage = 'ask', deadline = GetGameTimer() + R.answerSeconds * 1000,
        center = Shaman.Coords(target), marks = {}, nextMark = 1,
        viewers = {}, joinable = {}, helpers = {}, verse = 0, points = 0,
    }
    sessions[s.id] = s
    member[src] = s.id
    member[target] = s.id

    local label = Config.Curses[curseKey] and Config.Curses[curseKey].label or curseKey
    local text
    if kind == 'lift' then
        text = L('rit_ask_lift', rank.title, s.leaderName, label)
    else
        text = L('rit_ask_bind', rank.title, s.leaderName, label)
    end
    if price > 0 then text = text .. L('rit_ask_cost', price) end
    TriggerClientEvent('pup_shaman:client:ritualAsk', target, s.id, titleOf(s), text)
    Shaman.Notify(src, L('rit_asking', s.targetName))
    startTicker()
end

local function beginLift(src)
    local char, tribe, rank = mayLead(src)
    if not char then return end
    local pos = Shaman.Coords(src)
    if not pos then return end
    local best, bestDist, bestKey, beyond
    for _, other in ipairs(Shaman.Players()) do
        if other ~= src then
            local opos = Shaman.Coords(other)
            local d = opos and #(pos - opos)
            if d and d <= R.beginRange then
                local key = Store.Get(other)
                if key ~= '' then
                    if not listHas(rank.lift, key) then
                        beyond = true
                    elseif not member[other] and not Shaman.Form(other) and (not best or d < bestDist) then
                        best, bestDist, bestKey = other, d, key
                    end
                end
            end
        end
    end
    if not best then
        return Shaman.Notify(src, beyond and L('rit_beyond') or L('rit_no_help'))
    end
    ask(src, char, tribe, rank, 'lift', best, bestKey)
end

local function beginBind(src, curseKey)
    local char, tribe, rank = mayLead(src)
    if not char then return end
    if not rank.give or #rank.give == 0 then
        return Shaman.Notify(src, L('rit_cannot_give'))
    end
    if not listHas(rank.give, curseKey) or not Config.Curses[curseKey] then return end
    local pos = Shaman.Coords(src)
    if not pos then return end
    local best, bestDist, sawCursed
    for _, other in ipairs(Shaman.Players()) do
        if other ~= src then
            local opos = Shaman.Coords(other)
            local d = opos and #(pos - opos)
            local ochar = d and d <= R.beginRange and Shaman.Character(other)
            if ochar and not Shaman.IsDead(other, ochar) then
                if Store.Get(other) ~= '' then
                    sawCursed = true
                elseif not member[other] and not Shaman.Form(other) and (not best or d < bestDist) then
                    best, bestDist = other, d
                end
            end
        end
    end
    if not best then
        return Shaman.Notify(src, sawCursed and L('rit_has_curse') or L('rit_no_receiver'))
    end
    ask(src, char, tribe, rank, 'bind', best, curseKey)
end

RegisterNetEvent('pup_shaman:server:ritualChoose', function(choice)
    local src = source
    if type(choice) ~= 'string' or not Shaman.Throttle(src, 'ritualChoose', 1500) then return end
    if choice == 'lift' then return beginLift(src) end
    local key = choice:match('^give:([%w_]+)$')
    if key then beginBind(src, key) end
end)

RegisterNetEvent('pup_shaman:server:ritualAnswer', function(id, accept)
    local src = source
    local s = sessions[tonumber(id) or -1]
    if not s or s.target ~= src or s.stage ~= 'ask' then return end
    if accept ~= true then
        Shaman.Notify(s.leader, L('rit_refused', s.targetName))
        return close(s, 'refused')
    end
    s.stage = 'accepting'
    s.deadline = GetGameTimer() + 30000 -- an accept that never finishes is broken by the ticker
    local lchar, tchar = Shaman.Character(s.leader), Shaman.Character(s.target)
    if not lchar or not tchar
        or tonumber(lchar.charIdentifier) ~= s.leaderChar or tonumber(tchar.charIdentifier) ~= s.targetChar
        or Shaman.IsDead(s.leader, lchar) or Shaman.IsDead(s.target, tchar) then
        return broken(s)
    end
    local current = Store.Get(s.target)
    if sessions[s.id] ~= s then return end
    if current ~= s.expected then return gone(s) end

    -- burn the whole offering at once, or none of it
    local taken = {}
    for _, o in ipairs(s.offering) do
        if exports.vorp_inventory:subItem(s.leader, o.item, o.count) then
            taken[#taken + 1] = o
        else
            for _, t in ipairs(taken) do
                exports.vorp_inventory:addItem(s.leader, t.item, t.count)
            end
            local missing
            for _, m in ipairs(s.offering) do
                if itemCount(s.leader, m.item) < m.count then missing = m; break end
            end
            if missing then
                Shaman.Notify(s.leader, L('rit_need_item', missing.count, missing.label or missing.item))
            else
                Shaman.Notify(s.leader, L('rit_broken'))
            end
            Shaman.Notify(s.target, L('rit_broken'))
            return close(s, 'broken')
        end
    end

    -- the leader or target may have left while the offering was being taken: give it back
    if sessions[s.id] ~= s or not Shaman.SameChar(s.leader, s.leaderChar) or not Shaman.SameChar(s.target, s.targetChar) then
        if Shaman.SameChar(s.leader, s.leaderChar) then
            for _, t in ipairs(taken) do
                exports.vorp_inventory:addItem(s.leader, t.item, t.count)
            end
        end
        if sessions[s.id] == s then broken(s) end
        return
    end

    s.center = Shaman.Coords(s.target) or s.center
    local base = math.random() * math.pi * 2
    for i = 1, R.marks do
        local a = base + (i - 1) * (math.pi * 2 / R.marks)
        s.marks[i] = vector3(s.center.x + math.cos(a) * R.ringRadius, s.center.y + math.sin(a) * R.ringRadius, s.center.z)
    end
    leaderRest[s.leaderChar] = os.time() + (s.rank.cooldownMinutes or 0) * 60
    s.viewers[s.leader] = true
    s.viewers[s.target] = true
    enter(s, 'kindle')
end)

RegisterNetEvent('pup_shaman:server:ritualMark', function(id, index)
    local src = source
    if not Shaman.Throttle(src, 'ritualMark', 1000) then return end
    local s = sessions[tonumber(id) or -1]
    if not s or s.leader ~= src or s.stage ~= 'circle' or tonumber(index) ~= s.nextMark then return end
    local mark, pos = s.marks[s.nextMark], Shaman.Coords(src)
    if not mark or not pos or Rules.Flat(pos, mark) > R.markReach + R.markSlack then return end
    s.nextMark = s.nextMark + 1
    if s.nextMark > #s.marks then
        enter(s, 'chant')
    else
        refresh(s)
    end
end)

RegisterNetEvent('pup_shaman:server:ritualVerseResult', function(id, token, result)
    local src = source
    local s = sessions[tonumber(id) or -1]
    if not s or s.leader ~= src or s.stage ~= 'chant' or s.answered or token ~= s.verseToken then return end
    s.answered = true
    local took = GetGameTimer() - (s.verseAt or 0)
    local pts = 0
    if took >= R.verseMinMs then
        if result == 'perfect' then
            pts = took >= R.perfectMinMs and R.points.perfect or R.points.success
        elseif result == 'success' then
            pts = R.points.success
        end
    end
    s.points = s.points + pts
    nextVerse(s)
end)

RegisterNetEvent('pup_shaman:server:ritualJoin', function(id)
    local src = source
    if not Shaman.Throttle(src, 'ritualJoin', 1000) then return end
    local s = sessions[tonumber(id) or -1]
    if not s or not s.viewers[src] or not eligible(s, src) then return end
    local pos = Shaman.Coords(src)
    if not pos or #(pos - s.center) > R.stayRange then return end
    s.helpers[src] = true
    member[src] = s.id
    refresh(s)
end)

-- someone left: the session breaks if they were leading or receiving it
Shaman.OnLeave(function(src)
    local id = member[src]
    local s = id and sessions[id]
    if s then
        if src == s.leader or src == s.target then
            local other = src == s.leader and s.target or s.leader
            Shaman.Notify(other, L('rit_broken'))
            close(s, 'broken')
        else
            s.helpers[src] = nil
            member[src] = nil
            refresh(s)
        end
    end
    member[src] = nil
    for _, other in pairs(sessions) do
        other.viewers[src] = nil
        other.joinable[src] = nil
    end
end)
