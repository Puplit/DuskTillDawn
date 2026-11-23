-- pup_robbery | bank heists: a server-driven run per bank

Heist = {}

local H = Config.Heist
local Runs = {}       -- [bankId] = run
local CrewOf = {}     -- [src] = bankId
local DoorOpen = {}   -- [hash] = true while a live run holds it open
local runSeq = 0

local function bank(id) return type(id) == 'string' and Config.Banks[id] or nil end

function Heist.run(id) return Runs[id] end
function Heist.crewBank(src) return CrewOf[src] end

function Heist.runForPosse(posseId)
    if not posseId then return nil end
    for _, run in pairs(Runs) do
        if run.posseId == posseId then return run end
    end
    return nil
end

function Heist.bankLeft(id) return DB.clockLeft('heist', id) end
function Heist.personalLeft(charid)
    if not charid then return 0 end
    return DB.clockLeft('player', charid)
end

--------------------------------------------------------------------------------
-- doors

local function sendDoors(changes, target)
    TriggerClientEvent('pup_robbery:doors:set', target or -1, changes)
end

local function setDoors(hashes, open)
    local changes = {}
    for _, h in ipairs(hashes or {}) do
        h = tonumber(h)
        if h then
            DoorOpen[h] = open or nil
            changes[#changes + 1] = { h, open == true }
        end
    end
    if #changes > 0 then sendDoors(changes) end
end

local function lockBank(b)
    setDoors(U.bankDoors(b), false)
end

S.callback('pup_robbery:doors:get', function()
    local out = {}
    for _, id in ipairs(Config.BankOrder) do
        local b = Config.Banks[id]
        if b then
            for _, h in ipairs(U.bankDoors(b)) do out[#out + 1] = { h, DoorOpen[h] == true } end
        end
    end
    return out
end)

--------------------------------------------------------------------------------
-- snapshots: what each crew client sees (the current step only, never the plan)

local function stageDef(run)
    local idx = run.plan and run.plan[run.step]
    return idx and run.bank.stages[idx] or nil, idx
end

local function altAllowed(run, stage)
    return stage and stage.alt ~= nil and U.routeAllows(stage.alt, run.entry, run.quiet)
end

local function lootAllowed(run, i)
    local spot = run.bank.loot[i]
    return spot ~= nil and U.routeAllows(spot, run.entry, run.quiet)
end

local function allowedLootCount(run)
    local n = 0
    for i in ipairs(run.bank.loot) do
        if lootAllowed(run, i) then n = n + 1 end
    end
    return n
end

local function insideLeft(run)
    if not run.insideEnds then return nil end
    return math.max(0, run.insideEnds - os.time())
end

local function vec(p) return p and { x = p.x, y = p.y, z = p.z } or nil end

local function buildSnapshot(run)
    local b = run.bank
    local snap = {
        bank = b.id, snapId = run.snapId, stage = run.stage, alarm = run.alarm, alarmMax = H.alarmMax,
        insideLeft = insideLeft(run), insideTotal = (b.insideMinutes or 0) * 60,
        prepDone = run.prepDone, entry = run.entry, lootTaken = run.lootTaken,
    }
    if run.stage == 'claimed' then
        if b.prep and not run.prepDone then
            local boxes = {}
            for i, box in ipairs(b.prep.boxes) do
                boxes[i] = { i = i, pos = vec(box.pos), prop = box.prop and { model = box.prop.model, pos = vec(box.prop.pos or box.pos), rot = vec(box.prop.rot), heading = box.prop.heading } or nil }
            end
            snap.prep = { label = b.prep.label, tool = b.prep.tool, boxes = boxes }
        end
        local entries = {}
        for _, key in ipairs(b.entryOrder or {}) do
            local e = b.entries[key]
            if e then
                entries[#entries + 1] = {
                    key = key, pos = vec(e.pos), label = e.label, tool = e.tool, lock = e.game ~= nil,
                    walkIn = e.walkIn == true, blocked = Heist.entryBlocked(run, e),
                }
            end
        end
        snap.entries = entries
    end
    if run.stage == 'vault' then
        local st, idx = stageDef(run)
        if st then
            local alt = altAllowed(run, st) and st.alt or nil
            snap.step = {
                idx = idx, label = st.label, pos = vec(st.pos), game = st.game, tool = st.tool, armed = run.armed ~= nil,
                alt = alt and { label = alt.label, tool = alt.tool, toolLabel = alt.tool and S.itemLabel(alt.tool, alt.tool) or nil } or nil,
            }
        end
    end
    if run.stage == 'vault' or run.stage == 'looting' then
        if b.clue and not run.clueFound then
            snap.clue = { pos = vec(b.clue.pos), label = b.clue.label, tool = b.clue.tool, game = b.clue.game }
        end
        local doors = {}
        for i, d in ipairs(b.extraDoors) do
            if not run.doorsDone[i] and U.routeAllows(d, run.entry, run.quiet) then
                doors[#doors + 1] = { i = i, pos = vec(d.pos), label = d.label, tool = d.tool }
            end
        end
        snap.doors = doors
    end
    if run.stage == 'looting' then
        local spots = {}
        for i, spot in ipairs(b.loot) do
            if lootAllowed(run, i) and not run.taken[i] then
                spots[#spots + 1] = {
                    i = i, pos = vec(spot.pos), label = spot.label, safe = spot.safe == true, tool = spot.tool,
                    prop = spot.prop and { model = spot.prop.model, offset = vec(spot.prop.offset), heading = spot.prop.heading, rot = vec(spot.prop.rot), ground = spot.prop.ground } or nil,
                }
            end
        end
        snap.loot = spots
    end
    if (run.stage == 'looting' or run.stage == 'escape') and (run.lootTaken > 0 or allowedLootCount(run) == 0) then
        local zones = {}
        for i, z in ipairs(b.escapeZones) do zones[i] = { i = i, pos = vec(z.pos), radius = z.radius, label = z.label } end
        snap.getaway = { anchor = vec(b.anchor), range = b.getawayRange, zones = zones }
    end
    return snap
end

local function push(run)
    run.snapId = run.snapId + 1
    local snap = buildSnapshot(run)
    for s in pairs(run.crew) do
        snap.leader = (s == run.leader)
        TriggerClientEvent('pup_robbery:heist:snapshot', s, snap)
    end
end
Heist.push = push

local function clearScreen(src)
    TriggerClientEvent('pup_robbery:heist:snapshot', src, false)
end

local function toCrew(run, text, ms)
    for s in pairs(run.crew) do S.tip(s, text, ms or 5000) end
end

--------------------------------------------------------------------------------
-- prep gating (an entry's needsPrep = false counts only with Config.Heist.honourEntryNeedsPrep)

function Heist.entryBlocked(run, e)
    if not run.bank.prep or run.prepDone then return false end
    if H.honourEntryNeedsPrep and e.needsPrep == false then return false end
    return true
end

--------------------------------------------------------------------------------
-- alarm

local function sendBoard(run, level)
    local b = run.bank
    local pc = H.police
    if run.alertSent and pc.once then return end
    if level < (pc.fromLevel or 4) then return end
    local text = pc.fixedText
    local lt = pc.levelTexts[level] or {}
    if not text or text == '' then text = (lt.text or '%s'):format(b.dispatchLabel or b.label) end
    local location = lt.vague and b.region or (b.dispatchLocation or b.label)
    if Police.board(b.anchor, text, pc.persistent, location, b.region) then run.alertSent = true end
end

local function spawnGuards(run)
    if run.guardsSpawned then return end
    run.guardsSpawned = true
    if run.leader then
        run.guardOwner = run.leader
        TriggerClientEvent('pup_robbery:heist:guards', run.leader, run.bank.id)
    end
end

function Heist.raiseAlarm(run, level, quiet)
    level = math.min(H.alarmMax, math.floor(tonumber(level) or 0))
    if level <= run.alarm then return end
    run.alarm = level
    if level > run.alarmPeak then run.alarmPeak = level end
    local b = run.bank
    if run.brokeIn and b.guardsAtAlarm and level >= b.guardsAtAlarm then spawnGuards(run) end
    sendBoard(run, level)
    if H.publicAlarm.enabled and level >= H.publicAlarm.fromLevel and not run.publicSent then
        run.publicSent = true
        Police.alert('heist:' .. b.id, b.anchor, b.label, { b.region }, run.crew)
    end
    if not quiet then push(run) end
end

local function addAlarm(run, step)
    step = tonumber(step) or 0
    if step <= 0 then return end
    Heist.raiseAlarm(run, run.alarm + step)
end

--------------------------------------------------------------------------------
-- claiming (the fence path)

local function newCode(difficulty)
    local digits = 3 + math.max(1, math.floor(difficulty or 1))
    local t = {}
    for i = 1, digits do t[i] = tostring(math.random(0, 9)) end
    return table.concat(t)
end

function Heist.claim(bankId, leader, members, posseId)
    local b = bank(bankId)
    if not b then return false, 'unknown bank' end
    if Runs[bankId] then return false, 'running' end
    if Heist.bankLeft(bankId) > 0 then return false, 'on cooldown' end
    runSeq = runSeq + 1
    local run = {
        seq = runSeq, bank = b, posseId = posseId, stage = 'claimed', crew = {}, chars = {}, leader = leader,
        claimedAt = os.time(), deadline = os.time() + (b.jobLimit or 45) * 60,
        prepDone = b.prep == nil, alarm = 0, alarmPeak = 0, step = 0, plan = {},
        taken = {}, lootTaken = 0, doorsDone = {}, warned = {}, downed = {}, downSeen = {},
        code = newCode(H.pinDifficulty), clueFound = false, clueMask = nil, counter = 0, snapId = 0,
        riders = {},
    }
    for _, s in ipairs(members) do
        local cid = S.charId(s)
        if cid and not CrewOf[s] then
            run.crew[s] = cid
            run.chars[cid] = true
            run.riders[s] = true
            CrewOf[s] = bankId
        end
    end
    if not run.crew[leader] then
        for s in pairs(run.crew) do CrewOf[s] = nil end
        return false, 'leader has no character'
    end
    Runs[bankId] = run
    push(run)
    S.dbg('run %d claimed at %s', run.seq, bankId)
    return true
end

--------------------------------------------------------------------------------
-- ending (one idempotent path)

local function clearPosseTask(run)
    local key = 'heist:' .. run.bank.id
    local tried = {}
    local function try(s)
        if tried[s] or not S.online(s) then return false end
        tried[s] = true
        local ok, task = S.call('pup-ui', 'GetPosseTask', s)
        if ok and task == key then
            S.call('pup-ui', 'ClearPosseTask', s)
            return true
        end
        return false
    end
    for s in pairs(run.crew) do
        if try(s) then return end
    end
    if H.clearTaskOnWipe then
        for s in pairs(run.riders) do
            if try(s) then return end
        end
    end
end

local function crewNames(run)
    local lines = {}
    for s in pairs(run.riders) do
        local name = S.online(s) and S.charName(s) or 'disconnected'
        lines[#lines + 1] = ('- `%s` (ID %d)%s'):format(Logs.clean(name), s, s == run.leader and ' **leader**' or '')
    end
    return #lines > 0 and table.concat(lines, '\n') or '-'
end

function Heist.finish(run, outcome, silent)
    if not run or run.ended then return end
    run.ended = true
    local b = run.bank
    if Runs[b.id] == run then Runs[b.id] = nil end
    run.token = nil

    local lockMinutes = 0
    if not silent then
        local scale = H.cooldownScale[outcome] or 1.0
        if outcome == 'abandoned' and not run.brokeIn then scale = 0 end
        lockMinutes = math.floor((b.cooldown or 0) * scale)
        if lockMinutes > 0 then DB.setClock('heist', b.id, os.time() + lockMinutes * 60) end
    end

    if run.brokeIn and H.doorGrace > 0 and not silent then
        toCrew(run, L('doorsSeal', H.doorGrace), 6000)
        local crew = {}
        for s in pairs(run.crew) do crew[#crew + 1] = s end
        local seq = run.seq
        SetTimeout(math.max(0, (H.doorGrace - H.doorFinalWarn) * 1000), function()
            for _, s in ipairs(crew) do
                if S.online(s) then S.tip(s, L('doorsSealSoon', H.doorFinalWarn), 4000) end
            end
        end)
        SetTimeout(H.doorGrace * 1000, function()
            local live = Runs[b.id]
            if live and live.seq ~= seq then return end
            lockBank(b)
        end)
    else
        lockBank(b)
    end

    clearPosseTask(run)
    Police.clear('heist:' .. b.id)

    local line = Locale.outcomes[outcome] or outcome
    for s in pairs(run.crew) do
        CrewOf[s] = nil
        if not silent then S.tip(s, line, 7000) end
        clearScreen(s)
    end
    for s in pairs(run.downed) do
        if CrewOf[s] == b.id then CrewOf[s] = nil end
        clearScreen(s)
    end
    -- the client that spawned the guards removes them a little later
    if run.guardOwner and S.online(run.guardOwner) then
        TriggerClientEvent('pup_robbery:heist:ended', run.guardOwner, b.id)
    end

    if silent then return end

    local chars = {}
    for cid in pairs(run.chars) do chars[#chars + 1] = cid end
    table.sort(chars)
    local duration = run.brokeInAt and (os.time() - run.brokeInAt) or 0
    local total = run.brokeIn and allowedLootCount(run) or #b.loot
    DB.history({ bank = b.id, outcome = outcome, crew = chars, lootTaken = run.lootTaken, lootTotal = total,
        alarmPeak = run.alarmPeak, duration = duration, at = os.time() })

    local riderMinutes = run.brokeIn and Config.PersonalClocks.bank or nil
    Logs.send('🏦 Heist Settled', outcome == 'full' and Logs.BANK_GREEN or Logs.ORANGE, table.concat({
        ('**Bank:** `%s`'):format(b.label),
        ('**Outcome:** `%s`'):format(outcome),
        ('**Loot spots:** %d/%d'):format(run.lootTaken, total),
        ('**Alarm peak:** %d/%d'):format(run.alarmPeak, H.alarmMax),
        ('**Time inside:** %dm %02ds'):format(math.floor(duration / 60), duration % 60),
        ('**Crew:** %d (chars %s)'):format(#chars, table.concat(chars, ', ')),
        ('**Bank lock:** %s'):format(lockMinutes > 0 and (lockMinutes .. ' min') or 'not locked'),
        ('**Rider cooldown:** %s'):format(riderMinutes and (riderMinutes .. ' min') or 'off'),
        '**CREW**', crewNames(run), '', Logs.robber(run.leader),
    }, '\n'))
end

--------------------------------------------------------------------------------
-- crew

local function passLead(run)
    if run.crew[run.leader] then return end
    run.leader = nil
    for s in pairs(run.crew) do
        run.leader = s
        break
    end
    if run.leader then S.tip(run.leader, L('nowLeading'), 5000) end
end

function Heist.dropMember(run, src, why)
    if not run.crew[src] then return end
    run.crew[src] = nil
    if CrewOf[src] == run.bank.id then CrewOf[src] = nil end
    if run.token and run.token.src == src then run.token = nil end
    clearScreen(src)
    if why == 'down' then
        run.downed[src] = true
        toCrew(run, L('riderDown'))
        TriggerClientEvent('pup_robbery:heist:downed', src, run.bank.id)
    end
    if next(run.crew) == nil then
        return Heist.finish(run, 'crew_wipe')
    end
    passLead(run)
    push(run)
end

local function addMember(run, s)
    local cid = S.charId(s)
    if not cid or CrewOf[s] then return end
    run.crew[s] = cid
    run.chars[cid] = true
    run.riders[s] = true
    CrewOf[s] = run.bank.id
    run.downed[s] = nil
    if run.brokeIn then
        DB.setClock('player', cid, os.time() + S.personalSeconds(Config.PersonalClocks.bank, s))
    end
end

AddEventHandler('pup-ui:posse:serverChanged', function(posseId, members)
    local run = Heist.runForPosse(posseId)
    if not run or run.ended or type(members) ~= 'table' then return end
    local present = {}
    for _, s in ipairs(members) do
        s = tonumber(s)
        if s then present[s] = true end
    end
    for s in pairs(run.crew) do
        if not present[s] and s ~= run.leader then
            Heist.dropMember(run, s, 'left')
            if run.ended then return end
        end
    end
    for s in pairs(present) do
        if not run.crew[s] and not run.downed[s] and S.online(s) and not CrewOf[s] then
            addMember(run, s)
            S.tip(s, L('nowRiding'), 5000)
        end
    end
    push(run)
end)

RegisterNetEvent('pup_robbery:heist:down', function(bankId, snapId)
    local src = source
    local run = Runs[bankId]
    if not run or not run.crew[src] then return end
    if run.downSeen[src] == snapId then return end
    run.downSeen[src] = snapId
    Heist.dropMember(run, src, 'down')
end)

-- a revived rider rejoins (the server checks the ped is alive)
RegisterNetEvent('pup_robbery:heist:revived', function(bankId)
    local src = source
    if not H.reviveRejoins or not S.rate(src, 'heistRevive', 3000) then return end
    local run = Runs[bankId]
    if not run or not run.downed[src] or CrewOf[src] then return end
    if not S.alive(src) then return end
    local posse = S.posseInfo(src)
    if posse.id ~= run.posseId then return end
    addMember(run, src)
    S.tip(src, L('backOnJob'), 5000)
    push(run)
end)

--------------------------------------------------------------------------------
-- break-in and the vault plan

local function buildPlan(run)
    local b = run.bank
    local eligible, always, others = {}, {}, {}
    for i, st in ipairs(b.stages) do
        if U.routeAllows(st, run.entry, run.quiet) then
            eligible[#eligible + 1] = i
            if st.always then always[#always + 1] = i else others[#others + 1] = i end
        end
    end
    local want = math.min(b.stageCount or #eligible, #eligible)
    local chosen = {}
    for _, i in ipairs(always) do chosen[i] = true end
    U.shuffle(others)
    local n = #always
    for _, i in ipairs(others) do
        if n >= want then break end
        chosen[i] = true
        n = n + 1
    end
    local plan, tail = {}, {}
    for i, st in ipairs(b.stages) do
        if chosen[i] then
            if st.last then tail[#tail + 1] = i else plan[#plan + 1] = i end
        end
    end
    for _, i in ipairs(tail) do plan[#plan + 1] = i end
    return plan
end

local function enterLooting(run)
    run.stage = 'looting'
    if not run.vaultOpen then
        run.vaultOpen = true
        setDoors({ run.bank.vaultDoor }, true)
    end
    toCrew(run, L('vaultOpen'))
    if allowedLootCount(run) == 0 then
        run.stage = 'escape'
    end
end

local function breakIn(run, entryKey)
    local b = run.bank
    local e = b.entries[entryKey]
    run.entry = entryKey
    run.quiet = run.prepDone and b.prep ~= nil
    run.brokeIn = true
    run.brokeInAt = os.time()
    run.insideEnds = os.time() + (b.insideMinutes or 25) * 60
    setDoors(e.doors, true)
    run.plan = buildPlan(run)
    run.step = 1
    run.stage = 'vault'
    for s, cid in pairs(run.crew) do
        DB.setClock('player', cid, os.time() + S.personalSeconds(Config.PersonalClocks.bank, s))
    end
    local level = e.alarm or 0
    if not run.prepDone and e.noPrepAlarm then level = e.noPrepAlarm end
    Heist.raiseAlarm(run, level, true)
    if not b.guardsAtAlarm or run.alarm >= b.guardsAtAlarm then spawnGuards(run) end
    toCrew(run, L('brokeIn', b.label))
    if #run.plan == 0 then enterLooting(run) end
    push(run)
end

local function advance(run, opensVault)
    local st = stageDef(run)
    if st and st.doors then setDoors(st.doors, true) end
    if opensVault and not run.vaultOpen then
        run.vaultOpen = true
        setDoors({ run.bank.vaultDoor }, true)
        toCrew(run, L('vaultSwings'))
    end
    run.armed = nil
    run.step = run.step + 1
    local nxt = stageDef(run)
    if nxt then
        toCrew(run, L('stageNext', nxt.label))
    else
        enterLooting(run)
    end
    push(run)
end

--------------------------------------------------------------------------------
-- common checks

local function lawStillThere(run)
    local b = run.bank
    return S.lawOk({ b.region }, b.lawmen or 0)
end

local function reach(run)
    return run.brokeIn and run.bank.insideRange or run.bank.interactRange
end

local function checkDeadline(run)
    if run.stage == 'claimed' and os.time() > run.deadline then
        toCrew(run, L('jobTooSlow'), 7000)
        Heist.finish(run, 'abandoned')
        return false
    end
    return true
end

local function member(src, bankId)
    local run = Runs[bankId]
    if not run or run.ended or not run.crew[src] then return nil end
    if not S.charId(src) then return nil end
    return run
end

local function tokenLive(run)
    local t = run.token
    if not t then return false end
    if os.time() > t.expires or not S.online(t.src) or not run.crew[t.src] then return false end
    return true
end

local function itemLabel(item) return S.itemLabel(item, item) end

--------------------------------------------------------------------------------
-- what an attempt targets: returns a target table or nil, message

local function resolve(run, src, kind, ref, useAlt)
    local b = run.bank
    if kind == 'prep' then
        if run.stage ~= 'claimed' or run.prepDone or not b.prep then return nil end
        local box = b.prep.boxes[tonumber(ref) or 0]
        if not box then return nil end
        return { pos = box.pos, tool = b.prep.tool, game = b.prep.game, key = 'prep', consumeOnStart = false, failStep = b.prep.failStep }
    elseif kind == 'entry' then
        if run.stage ~= 'claimed' then return nil end
        local e = b.entries[tostring(ref)]
        if not e or not e.game then return nil end
        if Heist.entryBlocked(run, e) then return nil, L('prepFirst', (b.prep.label or ''):lower()) end
        if S.jobBlocked(src) then return nil, L('blockedJob') end
        if not lawStillThere(run) then return nil, L('notEnoughLaw', b.lawmen or 0) end
        return { pos = e.pos, tool = e.tool, game = e.game, key = 'entry:' .. tostring(ref), consumeOnStart = true, failStep = e.failStep }
    elseif kind == 'stage' then
        if run.stage ~= 'vault' then return nil end
        local st, idx = stageDef(run)
        if not st or idx ~= tonumber(ref) then return nil end
        if run.armed then return nil, L('chargeArmed') end
        local def = st
        if useAlt then
            if not altAllowed(run, st) then return nil end
            def = st.alt
        end
        return { pos = st.pos, tool = def.tool, game = def.game, key = ('stage:%d:%s'):format(idx, useAlt and 'alt' or 'main'),
                 def = def, failStep = def.failStep, alt = useAlt == true }
    elseif kind == 'door' then
        if run.stage ~= 'vault' and run.stage ~= 'looting' then return nil end
        local i = tonumber(ref)
        local d = i and b.extraDoors[i]
        if not d or run.doorsDone[i] or not U.routeAllows(d, run.entry, run.quiet) then return nil end
        return { pos = d.pos, tool = d.tool, keepTool = true, game = d.game or 'button_mash', key = 'door:' .. i, failStep = d.failStep or 1 }
    elseif kind == 'clue' then
        if run.stage ~= 'vault' and run.stage ~= 'looting' then return nil end
        if not b.clue or run.clueFound or not b.clue.game then return nil end
        return { pos = b.clue.pos, tool = b.clue.tool, keepTool = true, game = b.clue.game, key = 'clue', failStep = b.clue.failStep or 1 }
    elseif kind == 'safe' then
        if run.stage ~= 'looting' then return nil end
        local i = tonumber(ref)
        local spot = i and b.loot[i]
        if not spot or not spot.safe or run.taken[i] or not lootAllowed(run, i) then return nil end
        return { pos = spot.pos, tool = spot.tool, keepTool = true, game = spot.game or 'safe_crack', key = 'safe:' .. i, failStep = spot.failStep or 1 }
    end
    return nil
end

local function gameOptions(run, target)
    local g = target.game
    if g == 'pincode' then
        local bonus = run.clueFound and (run.bank.clue and run.bank.clue.bonusGuesses or 0) or 0
        return { difficulty = H.pinDifficulty, guesses = H.pinGuesses + bonus, code = run.code, hint = run.clueMask }
    end
    return {}
end

--------------------------------------------------------------------------------
-- the token flow

local failure -- defined below

-- an attempt nobody reported back counts as a failure
local function expireToken(run)
    local t = run.token
    if not t or os.time() <= t.expires then return end
    run.token = nil
    if S.online(t.src) and run.crew[t.src] then failure(run, t.src, t) end
end

S.callback('pup_robbery:heist:attempt', function(src, bankId, kind, ref, useAlt)
    if not S.rate(src, 'heistAttempt', 500) then return { ok = false, msg = L('notNow') } end
    local run = member(src, bankId)
    if not run then return { ok = false, msg = L('notNow') } end
    if not checkDeadline(run) then return { ok = false } end
    expireToken(run)
    if run.ended then return { ok = false } end
    if tokenLive(run) then return { ok = false, msg = L('busyToken') } end
    run.token = nil
    local target, msg = resolve(run, src, tostring(kind), ref, useAlt == true)
    if not target then return { ok = false, msg = msg or L('notNow') } end
    if not S.near(src, target.pos, reach(run)) then return { ok = false, msg = L('notNow') } end
    if target.tool and S.itemCount(src, target.tool) < 1 then
        return { ok = false, msg = L('needTool', itemLabel(target.tool)) }
    end
    -- the token is taken before the tool, so a second rider cannot slip in while the item export runs
    run.counter = run.counter + 1
    local id = ('%s:%d:%s:%d'):format(run.bank.id, run.seq, target.key, run.counter)
    local token = { id = id, src = src, kind = tostring(kind), ref = ref, alt = target.alt, key = target.key,
                    expires = os.time() + H.tokenLifetime, target = target }
    run.token = token
    if target.consumeOnStart and target.tool then
        if not S.takeItem(src, target.tool, 1) then
            if run.token == token then run.token = nil end
            return { ok = false, msg = L('needTool', itemLabel(target.tool)) }
        end
    end
    local def = target.def or {}
    return {
        ok = true, token = id, game = target.game, opts = gameOptions(run, target),
        placement = def.placement, anim = def.anim, fuse = def.fuse,
    }
end)

failure = function(run, src, t)
    local target = t.target
    if t.kind == 'prep' then
        if target.tool then S.takeItem(src, target.tool, 1) end
        S.tip(src, L('prepFailed'))
        addAlarm(run, target.failStep)
    elseif t.kind == 'entry' then
        S.tip(src, L('lockHolds'))
        addAlarm(run, target.failStep)
    elseif t.kind == 'stage' then
        if target.tool then
            S.takeItem(src, target.tool, 1)
            if target.game == 'dynamite' then S.tip(src, L('chargeWasted')) else S.tip(src, L('toolBroke', itemLabel(target.tool))) end
        end
        addAlarm(run, target.failStep)
    elseif t.kind == 'door' or t.kind == 'clue' then
        S.tip(src, L('holdsTryAgain'))
        addAlarm(run, target.failStep)
    elseif t.kind == 'safe' then
        S.tip(src, L('safeHolds'))
        addAlarm(run, target.failStep)
    end
end

local function giveRolled(src, item, count, label)
    if S.canCarry(src, item, count) and S.giveItem(src, item, count, {}) then
        S.tip(src, L('lootGain', count, S.itemLabel(item, label)))
        return true
    end
    return false
end

local function grantSpot(run, src, i)
    local b = run.bank
    run.taken[i] = true
    run.lootTaken = run.lootTaken + 1
    local any = false
    for _, line in ipairs(b.lootTable) do
        if math.random(1, 100) <= (line.chance or 0) then
            local n = math.random(line.min or 1, math.max(line.min or 1, line.max or 1))
            if giveRolled(src, line.item, n, line.label) then any = true end
        end
    end
    if not any then S.tip(src, L('lootNothing')) end
    S.awardShared(src, Config.Perks.xpRobbery)
    if S.up('pup-gangs') then
        local pts = S.rollPoints(H.gangPoints)
        if pts > 0 then S.call('pup-gangs', 'AwardPoints', src, 'heist', pts, ('%s #%d'):format(b.id, i)) end
    end
    if run.ended then return end
    local left = 0
    for j in ipairs(b.loot) do
        if lootAllowed(run, j) and not run.taken[j] then left = left + 1 end
    end
    if left == 0 then
        run.stage = 'escape'
        toCrew(run, #b.escapeZones > 0 and L('allTakenZones') or L('allTaken'), 7000)
    end
    push(run)
end

local function findClue(run, src)
    local c = run.bank.clue
    run.clueFound = true
    local digits = {}
    for d in run.code:gmatch('%d') do digits[#digits + 1] = d end
    local idx = {}
    for i = 1, #digits do idx[i] = i end
    U.shuffle(idx)
    local show = {}
    for k = 1, math.min(c.reveal or 2, #digits) do show[idx[k]] = true end
    local mask = {}
    for i, d in ipairs(digits) do mask[i] = show[i] and d or '_' end
    run.clueMask = table.concat(mask, ' ')
    toCrew(run, L('clueShown', c.doneText or c.label, run.clueMask), 10000)
    if c.reward then
        local n = math.random(c.reward.min or 1, math.max(c.reward.min or 1, c.reward.max or 1))
        if S.canCarry(src, c.reward.item, n) and S.giveItem(src, c.reward.item, n, {}) then
            S.tip(src, L('clueReward', n, S.itemLabel(c.reward.item, c.reward.label)))
        else
            S.tip(src, L('noRoomClue'))
        end
    end
    if not run.ended then push(run) end
end

local function armCharge(run, src, def)
    local st, idx = stageDef(run)
    if not S.takeItem(src, def.tool or 'dynamite', 1) then
        return S.tip(src, L('needTool', itemLabel(def.tool or 'dynamite')))
    end
    local fuse = tonumber(def.fuse) or H.defaultFuse
    run.armed = { step = run.step, seq = run.seq }
    if def.alarmTo then Heist.raiseAlarm(run, def.alarmTo, true) end
    local pos = vec(st.pos)
    TriggerClientEvent('pup_robbery:heist:fx', -1, 'charge', { pos = pos, fuse = fuse, planter = src })
    toCrew(run, L('chargeSet', fuse), 6000)
    S.toast(src, L('chargeToast'))
    push(run)
    local seq, step = run.seq, run.step
    SetTimeout(fuse * 1000, function()
        TriggerClientEvent('pup_robbery:heist:fx', -1, 'blast', { pos = pos })
        local live = Runs[run.bank.id]
        if live ~= run or run.ended or run.seq ~= seq or run.step ~= step or run.stage ~= 'vault' then return end
        Heist.raiseAlarm(run, 4, true)
        if not run.vaultOpen then
            run.vaultOpen = true
            setDoors({ run.bank.vaultDoor }, true)
        end
        advance(run, false)
    end)
    S.dbg('charge armed at %s stage %d', run.bank.id, idx or -1)
end

RegisterNetEvent('pup_robbery:heist:report', function(bankId, tokenId, success)
    local src = source
    if not S.rate(src, 'heistReport', 300) then return end
    local run = member(src, bankId)
    if not run then return end
    local t = run.token
    if not t or t.src ~= src or t.id ~= tokenId then return end
    run.token = nil
    -- a late report is not honoured; it costs what an unreported attempt costs
    if os.time() > t.expires then return failure(run, src, t) end
    -- the step must still be the one the token was cut for
    local now = resolve(run, src, t.kind, t.ref, t.alt)
    if not now or now.key ~= t.key then return end
    if success ~= true then return failure(run, src, t) end

    if t.kind == 'prep' then
        run.prepDone = true
        toCrew(run, L('prepDone', run.bank.prep.doneText or run.bank.prep.label))
        Heist.raiseAlarm(run, 1, true)
        push(run)
    elseif t.kind == 'entry' then
        if not checkDeadline(run) then return end
        breakIn(run, tostring(t.ref))
    elseif t.kind == 'stage' then
        local def = t.target.def
        if def.game == 'dynamite' then return armCharge(run, src, def) end
        advance(run, def.opensVault == true)
    elseif t.kind == 'door' then
        local i = tonumber(t.ref)
        local d = run.bank.extraDoors[i]
        run.doorsDone[i] = true
        setDoors(d.doors, true)
        toCrew(run, d.doneText or L('doorGives'))
        push(run)
    elseif t.kind == 'clue' then
        findClue(run, src)
    elseif t.kind == 'safe' then
        grantSpot(run, src, tonumber(t.ref))
    end
end)

--------------------------------------------------------------------------------
-- steps without a minigame

RegisterNetEvent('pup_robbery:heist:enter', function(bankId, entryKey)
    local src = source
    if not S.rate(src, 'heistEnter', 1000) then return end
    local run = member(src, bankId)
    if not run or run.stage ~= 'claimed' then return end
    if not checkDeadline(run) then return end
    local b = run.bank
    local e = b.entries[tostring(entryKey)]
    if not e or e.game then return end
    if not S.near(src, e.pos, b.interactRange) then return end
    if S.jobBlocked(src) then return S.tip(src, L('blockedJob')) end
    if not lawStillThere(run) then return S.tip(src, L('notEnoughLaw', b.lawmen or 0)) end
    if Heist.entryBlocked(run, e) then return S.tip(src, L('prepFirst', (b.prep.label or ''):lower())) end
    if e.tool then
        if not S.takeItem(src, e.tool, 1) then return S.toast(src, L('needTool', itemLabel(e.tool))) end
    end
    if run.ended or run.stage ~= 'claimed' then return end
    breakIn(run, tostring(entryKey))
end)

RegisterNetEvent('pup_robbery:heist:clue', function(bankId)
    local src = source
    if not S.rate(src, 'heistClue', 1000) then return end
    local run = member(src, bankId)
    if not run or (run.stage ~= 'vault' and run.stage ~= 'looting') then return end
    local c = run.bank.clue
    if not c or c.game or run.clueFound then return end
    if not S.near(src, c.pos, reach(run)) then return end
    findClue(run, src)
end)

RegisterNetEvent('pup_robbery:heist:grab', function(bankId, i)
    local src = source
    if not S.rate(src, 'heistGrab', 1000) then return end
    local run = member(src, bankId)
    if not run or run.stage ~= 'looting' then return end
    i = tonumber(i)
    local spot = i and run.bank.loot[i]
    if not spot or spot.safe or run.taken[i] or not lootAllowed(run, i) then return end
    if not S.near(src, spot.pos, reach(run)) then return end
    grantSpot(run, src, i)
end)

RegisterNetEvent('pup_robbery:heist:getaway', function(bankId, zone)
    local src = source
    if not S.rate(src, 'heistGetaway', 2000) then return end
    local run = member(src, bankId)
    if not run or (run.stage ~= 'looting' and run.stage ~= 'escape') then return end
    -- a route that allows no loot spot at all would otherwise leave the crew with no way out
    if run.lootTaken < 1 and allowedLootCount(run) > 0 then return end
    local b = run.bank
    if #b.escapeZones > 0 then
        local z = b.escapeZones[tonumber(zone) or 0]
        if not z or not S.near(src, z.pos, (z.radius or 10) + H.escapeZoneSlack) then return end
    else
        local p, unchecked = S.pos(src)
        if not unchecked then
            if not p or U.dist(p, b.anchor) < b.getawayRange then return end
        end
    end
    local outcome = run.lootTaken >= allowedLootCount(run) and 'full' or 'partial'
    Heist.finish(run, outcome)
end)

--------------------------------------------------------------------------------
-- the heist tools as usable items: the client picks the target

function Heist.useItem(src, item)
    pcall(function() exports.vorp_inventory:closeInventory(src) end)
    local id = CrewOf[src]
    if not id or not Runs[id] then
        -- doorlocks registers the same usable item; vorp_inventory keeps only the last registration,
        -- so a lockpick used away from a heist is handed to doorlocks' own client handler
        local fb = H.lockpickFallback
        if fb and item == fb.item and S.up(fb.resource) then
            return TriggerClientEvent(fb.event, src)
        end
        return S.toast(src, L('nothingToUse'))
    end
    TriggerClientEvent('pup_robbery:heist:useItem', src, item)
end

--------------------------------------------------------------------------------
-- the clock: deadlines, time warnings, token expiry

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for _, run in pairs(Runs) do
            if not run.ended then
                if run.stage == 'claimed' then
                    checkDeadline(run)
                elseif run.insideEnds then
                    local left = run.insideEnds - now
                    if left <= 0 then
                        toCrew(run, L('timeUp'), 7000)
                        Heist.finish(run, 'failed')
                    else
                        for _, m in ipairs(H.timeWarnings) do
                            if left <= m * 60 and not run.warned[m] then
                                run.warned[m] = true
                                toCrew(run, m == 1 and L('timeLastMinute') or L('timeLeft', m), 6000)
                            end
                        end
                    end
                end
                if not run.ended then expireToken(run) end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- disconnects, start-up and shutdown

AddEventHandler('playerDropped', function()
    local src = source
    local id = CrewOf[src]
    local run = id and Runs[id]
    if run then Heist.dropMember(run, src, 'left') end
    CrewOf[src] = nil
    for _, r in pairs(Runs) do r.downed[src] = nil end
end)

CreateThread(function()
    Wait(5000)
    for _, id in ipairs(Config.BankOrder) do
        local b = Config.Banks[id]
        if b and not Runs[id] then lockBank(b) end
    end
end)

function Heist.shutdown()
    for _, run in pairs(Runs) do Heist.finish(run, 'abandoned', true) end
end

--------------------------------------------------------------------------------
-- admin helpers

function Heist.adminAlarm(bankId, level)
    local run = Runs[bankId]
    if not run then return false end
    Heist.raiseAlarm(run, level)
    return true
end

function Heist.resetBank(bankId)
    DB.clearClock('heist', bankId)
end

function Heist.resetAll()
    local n = 0
    for _, id in ipairs(Config.BankOrder) do
        if Heist.bankLeft(id) > 0 then n = n + 1 end
        DB.clearClock('heist', id)
    end
    DB.clearScope('player')
    DB.clearScope('walkup')
    return n
end

function Heist.code(bankId)
    local run = Runs[bankId]
    if not run then return nil end
    return run.code, run.clueMask
end

function Heist.cancel(bankId)
    local run = Runs[bankId]
    if not run then return false end
    Heist.finish(run, 'abandoned')
    return true
end
