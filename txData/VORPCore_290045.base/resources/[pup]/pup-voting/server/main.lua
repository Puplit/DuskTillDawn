-- Mayoral elections. One election covers every region on one clock.
-- One vote per account per region, enforced by a unique key, not a read-then-write.

local Core <const> = exports.vorp_core:GetCore()

-- the master switch; loaded from election_settings once the tables exist
local enabled = Config.Election.defaultEnabled ~= false

CreateThread(function()
    local sql <const> = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if sql and sql ~= '' then
        for stmt in sql:gmatch('[^;]+') do
            if stmt:match('%S') and (stmt:match('CREATE') or stmt:match('ALTER')) then
                pcall(MySQL.query.await, stmt)
            end
        end
    end
    local ok, v = pcall(MySQL.scalar.await,
        "SELECT v FROM election_settings WHERE k = 'enabled'")
    if ok and v ~= nil then enabled = tostring(v) == '1' end
    print(('^2[pup-voting]^7 ready  -  voting is %s'):format(enabled and 'ON' or 'OFF'))
end)

local function charOf(src)
    local u = Core.getUser(src)
    return u and u.getUsedCharacter or nil
end

-- the account: a second character must not get a second ballot
local function identifierOf(src)
    local ch = charOf(src)
    return ch and ch.identifier or nil
end

local function notify(src, msg, ms)
    Core.NotifyRightTip(src, msg, ms or 5000)
end

local function validRegion(region)
    for _, r in ipairs(Config.Election.regions) do if r == region then return true end end
    return false
end

-- who did it, for the log line
local function whoIs(src)
    local ch = charOf(src)
    local name = ch and ((ch.firstname or '') .. ' ' .. (ch.lastname or '')) or '?'
    local bits = { ('%s (#%s)'):format(name, tostring(ch and ch.charIdentifier or '?')) }
    bits[#bits + 1] = ('%s [%s]'):format(GetPlayerName(src) or '?', tostring(src))
    if Config.Logging and Config.Logging.identifiers then
        bits[#bits + 1] = tostring(identifierOf(src) or '?')
    end
    return table.concat(bits, '  |  ')
end

-- the standings region by region, so a closed or deleted election leaves its result behind
local function tally(electionId)
    local ok, rows = pcall(MySQL.query.await, [[
        SELECT c.region, c.name, COUNT(v.id) AS votes
        FROM election_candidates c
        LEFT JOIN election_votes v ON v.candidate_id = c.id
        WHERE c.election_id = ?
        GROUP BY c.id, c.region, c.name
        ORDER BY c.region ASC, votes DESC, c.name ASC ]], { electionId })
    if not ok or not rows or #rows == 0 then return '**Result:** no candidates' end

    local out, region, total = {}, nil, 0
    for _, r in ipairs(rows) do
        if r.region ~= region then
            region = r.region
            out[#out + 1] = ('**%s**'):format(region)
        end
        local n = tonumber(r.votes) or 0
        total = total + n
        out[#out + 1] = ('   %s - %d'):format(r.name, n)
    end
    return ('**Result** (%d vote(s))\n%s'):format(total, table.concat(out, '\n'))
end

local function logit(title, lines)
    local cfg = Config.Logging
    local url = Secrets.Webhooks and Secrets.Webhooks.election
    if type(url) ~= 'string' or url == '' then return end
    pcall(function()
        Core.AddWebhook(title, url, table.concat(lines, '\n'),
            cfg.colour, cfg.name, cfg.logo, cfg.footer, cfg.avatar)
    end)
end

local function isStaff(src)
    if src == 0 then return true end
    if GetResourceState('vorp_admin') == 'started' then
        local ok, allowed = pcall(function()
            return exports.vorp_admin:allowedToExecuteAction(src, Config.Integrations.vorpAdmin.action)
        end)
        if ok and allowed == true then return true end
    end
    local u = Core.getUser(src)
    return u ~= nil and u.getGroup == 'admin'
end

-- ------------------------------------------------------------------ reads

-- the one election staff are working on: a draft, or the one running
local function workingElection()
    local ok, row = pcall(MySQL.single.await,
        'SELECT id, open, hours, started_at FROM election ORDER BY id DESC LIMIT 1')
    if not ok or not row then return nil end
    local draft <const> = row.started_at == nil
    local running <const> = (row.open == true or tonumber(row.open) == 1)
    if draft or running then
        return { id = row.id, draft = draft, running = running,
            hours = tonumber(row.hours) or Config.Election.defaultDurationHours }
    end
    return nil
end

-- the last few elections, each with its regions and tallies, in three round trips
local function snapshot(src, staffView)
    local cycles, byId, ids = {}, {}, {}

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT id, open, hours,
               UNIX_TIMESTAMP(started_at) AS started_at,
               UNIX_TIMESTAMP(ends_at) AS ends_at,
               (UNIX_TIMESTAMP(ends_at) - UNIX_TIMESTAMP(NOW())) AS ends_left
        FROM election ORDER BY id DESC LIMIT 6 ]])
    if not ok then return cycles end

    for _, r in ipairs(rows or {}) do
        local c = {
            id = r.id,
            open = (r.open == true or tonumber(r.open) == 1),
            started = r.started_at ~= nil,
            hours = tonumber(r.hours) or Config.Election.defaultDurationHours,
            endsAt = tonumber(r.ends_at),
            endsLeft = tonumber(r.ends_left),
            regions = {}, total = 0,
        }
        c.draft = not c.started
        c.live = c.open and c.started and (c.endsLeft == nil or c.endsLeft > 0)
        byId[r.id] = c
        ids[#ids + 1] = r.id
        cycles[#cycles + 1] = c
    end
    if #ids == 0 then return cycles end

    -- ids come straight out of our own table, so they are safe to splice in
    local idList <const> = table.concat(ids, ',')
    local index = {} -- [electionId][region] = bucket

    local okC, cands = pcall(MySQL.query.await, ([[
        SELECT c.id, c.election_id, c.region, c.name, COUNT(v.id) AS votes
        FROM election_candidates c
        LEFT JOIN election_votes v ON v.candidate_id = c.id
        WHERE c.election_id IN (%s)
        GROUP BY c.id, c.election_id, c.region, c.name
        ORDER BY votes DESC, c.name ASC ]]):format(idList))
    if okC then
        for _, row in ipairs(cands or {}) do
            local c = byId[row.election_id]
            if c then
                index[row.election_id] = index[row.election_id] or {}
                local bucket = index[row.election_id][row.region]
                if not bucket then
                    bucket = { region = row.region, candidates = {}, total = 0 }
                    index[row.election_id][row.region] = bucket
                    c.regions[#c.regions + 1] = bucket
                end
                local n = tonumber(row.votes) or 0
                bucket.candidates[#bucket.candidates + 1] =
                    { id = row.id, name = row.name, votes = n }
                bucket.total = bucket.total + n
                c.total = c.total + n
            end
        end
    end

    -- this account's vote in each region of each election
    local ident = identifierOf(src)
    if ident then
        local okV, mine = pcall(MySQL.query.await, ([[
            SELECT election_id, region, candidate_id FROM election_votes
            WHERE identifier = ? AND election_id IN (%s) ]]):format(idList), { ident })
        if okV then
            for _, v in ipairs(mine or {}) do
                local bucket = index[v.election_id] and index[v.election_id][v.region]
                if bucket then bucket.myVote = v.candidate_id end
            end
        end
    end

    -- config order, so every screen reads the regions the same way
    local order = {}
    for i, r in ipairs(Config.Election.regions) do order[r] = i end
    for _, c in ipairs(cycles) do
        table.sort(c.regions, function(a, b)
            return (order[a.region] or 99) < (order[b.region] or 99)
        end)

        -- a running election sends no tallies to any client
        if c.live then
            c.total = 0
            for _, b in ipairs(c.regions) do
                b.total = 0
                for _, cand in ipairs(b.candidates) do cand.votes = 0 end
            end
        end

        -- players get shares and the leader only; raw counts stay on the server
        local minShareVotes <const> = tonumber(Config.Election.minVotesForShare) or 0
        for _, b in ipairs(c.regions) do
            local best = 0
            for _, cand in ipairs(b.candidates) do
                if cand.votes > best then best = cand.votes end
            end
            b.counted = b.total > 0
            for _, cand in ipairs(b.candidates) do
                cand.percent = b.counted and math.floor(cand.votes / b.total * 100 + 0.5) or 0
                cand.lead = b.counted and cand.votes == best
                if not staffView then
                    cand.votes = nil
                    -- on a handful of votes a share gives the count away
                    if b.total < minShareVotes then cand.percent = nil end
                end
            end
            if not staffView then b.total = nil end
        end
        if not staffView then c.total = nil end
    end

    return cycles
end

local function push(src)
    local staffView <const> = isStaff(src)
    TriggerClientEvent('pup-voting:client:state', src, snapshot(src, staffView), staffView, enabled)
end

-- each answer is three queries; a repeat ask within a second is answered once, a moment later
local lastGet, getQueued = {}, {}

-- per-player gap for the other requests that read or write the database
local lastAct = {}
local function tooFast(src, kind, gap)
    local nowMs <const> = GetGameTimer()
    local mine = lastAct[src]
    if not mine then mine = {}; lastAct[src] = mine end
    if mine[kind] and nowMs - mine[kind] < gap then return true end
    mine[kind] = nowMs
    return false
end

RegisterNetEvent('pup-voting:server:get', function()
    local src <const> = source
    local nowMs <const> = GetGameTimer()
    if lastGet[src] and nowMs - lastGet[src] < 1000 then
        if not getQueued[src] then
            getQueued[src] = true
            SetTimeout(1000, function()
                getQueued[src] = nil
                if GetPlayerName(src) then
                    lastGet[src] = GetGameTimer()
                    push(src)
                end
            end)
        end
        return
    end
    lastGet[src] = nowMs
    push(src)
end)

AddEventHandler('playerDropped', function()
    lastGet[source], getQueued[source], lastAct[source] = nil, nil, nil
end)

-- every spawn is sent the switch state; a client that never hears stays closed
AddEventHandler('vorp:SelectedCharacter', function(src)
    local s = tonumber(src)
    if not s then return end
    SetTimeout(2000, function()
        if GetPlayerName(s) then push(s) end
    end)
end)

RegisterNetEvent('pup-voting:server:voters', function(electionId, region)
    local src <const> = source
    -- who voted for whom is for staff checking a result. Players see percentages.
    if tooFast(src, 'voters', 1500) then return end
    if not isStaff(src) then return notify(src, Locale.noPermission) end
    electionId = tonumber(electionId)
    if not electionId then return end

    -- the voter list is a tally in disguise, so it waits for the polls to close
    local okE, e = pcall(MySQL.single.await, [[
        SELECT open, started_at, (UNIX_TIMESTAMP(ends_at) - UNIX_TIMESTAMP(NOW())) AS ends_left
        FROM election WHERE id = ? ]], { electionId })
    if okE and e and (e.open == true or tonumber(e.open) == 1) and e.started_at ~= nil
        and (e.ends_left == nil or tonumber(e.ends_left) > 0) then
        return TriggerClientEvent('pup-voting:client:voters', src, electionId, region, {})
    end

    local sql = [[
        SELECT v.voter_name, v.region, c.name AS candidate
        FROM election_votes v
        JOIN election_candidates c ON c.id = v.candidate_id
        WHERE v.election_id = ? ]]
    local args = { electionId }
    if type(region) == 'string' and region ~= '' then
        sql = sql .. ' AND v.region = ?'
        args[#args + 1] = region
    end
    sql = sql .. ' ORDER BY v.region ASC, v.voted_at ASC'

    local ok, rows = pcall(MySQL.query.await, sql, args)
    TriggerClientEvent('pup-voting:client:voters', src, electionId, region, (ok and rows) or {})
end)

-- ------------------------------------------------------------------ voting

RegisterNetEvent('pup-voting:server:vote', function(candidateId)
    local src <const> = source
    if tooFast(src, 'vote', 2000) then return end
    candidateId = tonumber(candidateId)
    if not candidateId then return end

    -- the switch is checked here too: hiding the menu is not the same as refusing the vote
    if not enabled then
        notify(src, Locale.votingOff)
        return push(src)
    end

    local ident <const> = identifierOf(src)
    local ch <const> = charOf(src)
    if not ident then return end

    -- the region comes off the candidate, never off the client
    local okC, cand = pcall(MySQL.single.await, [[
        SELECT c.election_id, c.region, c.name,
               e.open, e.started_at,
               (UNIX_TIMESTAMP(e.ends_at) - UNIX_TIMESTAMP(NOW())) AS ends_left
        FROM election_candidates c
        JOIN election e ON e.id = c.election_id
        WHERE c.id = ? ]], { candidateId })
    if not okC or not cand then return end

    local live <const> = (cand.open == true or tonumber(cand.open) == 1) and cand.started_at ~= nil
        and (cand.ends_left == nil or tonumber(cand.ends_left) > 0)
    if not live then
        notify(src, Locale.closed)
        return push(src)
    end

    local name <const> = ch and ((ch.firstname or '') .. ' ' .. (ch.lastname or '')) or GetPlayerName(src)
    local okV = pcall(MySQL.update.await, [[
        INSERT INTO election_votes
            (election_id, region, candidate_id, identifier, charid, voter_name)
        VALUES (?, ?, ?, ?, ?, ?) ]],
        { cand.election_id, cand.region, candidateId, ident, ch and ch.charIdentifier or nil, name })

    -- the unique key refuses a second ballot in that region, so a failure means "already voted"
    if not okV then
        notify(src, Locale.alreadyVoted)
        return push(src)
    end

    notify(src, Locale.voteCast)

    if Config.Logging and Config.Logging.votes then
        logit('Vote cast', {
            ('**Region:** %s'):format(cand.region),
            ('**Voted for:** %s'):format(cand.name),
            ('**Voter:** %s'):format(whoIs(src)),
            ('**Election:** #%d'):format(cand.election_id),
        })
    end

    push(src)
end)

-- ------------------------------------------------------------------- staff

local function staffGate(src)
    if isStaff(src) then return true end
    notify(src, Locale.noPermission)
    return false
end

RegisterNetEvent('pup-voting:server:setEnabled', function(on)
    local src <const> = source
    if not staffGate(src) then return end
    on = on and true or false
    if on == enabled then return end
    enabled = on

    pcall(MySQL.update.await,
        "INSERT INTO election_settings (k, v) VALUES ('enabled', ?) ON DUPLICATE KEY UPDATE v = VALUES(v)",
        { on and '1' or '0' })

    logit(on and 'Voting opened' or 'Voting closed', {
        ('**By:** %s'):format(whoIs(src)),
    })

    -- everyone, so the polling prompt appears or goes away without a relog
    TriggerClientEvent('pup-voting:client:enabled', -1, enabled)
    notify(src, enabled and Locale.turnedOn or Locale.turnedOff)
    push(src)
end)

-- a fresh draft: candidates go in region by region before the polls open
RegisterNetEvent('pup-voting:server:createDraft', function()
    local src <const> = source
    if not staffGate(src) then return end
    if workingElection() then
        notify(src, Locale.alreadyOne)
        return push(src)
    end

    pcall(MySQL.update.await,
        'INSERT INTO election (hours, open, created_by) VALUES (?, 0, ?)',
        { Config.Election.defaultDurationHours, GetPlayerName(src) or 'staff' })
    push(src)
end)

-- candidates are real characters: search by id or name, then pick the match
RegisterNetEvent('pup-voting:server:findCandidate', function(region, term)
    local src <const> = source
    if not staffGate(src) then return end
    if not validRegion(region) then return end
    term = tostring(term or ''):gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if term == '' then return end

    local rows
    local asId <const> = tonumber(term)
    if asId then
        local ok, r = pcall(MySQL.query.await,
            'SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier = ?', { asId })
        rows = ok and r or {}
    else
        local ok, r = pcall(MySQL.query.await, [[
            SELECT charidentifier, firstname, lastname FROM characters
            WHERE CONCAT(firstname, ' ', lastname) LIKE ?
            ORDER BY firstname, lastname LIMIT 20 ]], { '%' .. term .. '%' })
        rows = ok and r or {}
    end

    local out = {}
    for _, r in ipairs(rows or {}) do
        out[#out + 1] = {
            charid = tonumber(r.charidentifier),
            name = ((r.firstname or '') .. ' ' .. (r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        }
    end
    TriggerClientEvent('pup-voting:client:candidates', src, region, out)
end)

RegisterNetEvent('pup-voting:server:addCandidate', function(region, charid)
    local src <const> = source
    if not staffGate(src) then return end
    charid = tonumber(charid)
    if not charid or not validRegion(region) then return end

    local cur <const> = workingElection()
    -- the ballot is fixed once the polls open, so only a draft takes candidates
    if not cur or not cur.draft then
        notify(src, Locale.draftOnly)
        return push(src)
    end

    -- the name is read from the character row, not sent by the client
    local ok, row = pcall(MySQL.single.await,
        'SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { charid })
    if not ok or not row then return notify(src, Locale.noSuchChar) end

    local name = ((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = ('#%d'):format(charid) end
    if #name > 64 then name = name:sub(1, 64) end

    -- the unique key refuses the same character twice in one election
    if not pcall(MySQL.update.await,
        'INSERT INTO election_candidates (election_id, region, charid, name) VALUES (?, ?, ?, ?)',
        { cur.id, region, charid, name }) then
        return notify(src, Locale.alreadyStanding)
    end
    push(src)
end)

RegisterNetEvent('pup-voting:server:removeCandidate', function(candidateId)
    local src <const> = source
    if not staffGate(src) then return end
    candidateId = tonumber(candidateId)
    if not candidateId then return end

    local cur <const> = workingElection()
    if not cur or not cur.draft then
        notify(src, Locale.draftOnly)
        return push(src)
    end
    pcall(MySQL.update.await,
        'DELETE FROM election_candidates WHERE id = ? AND election_id = ?', { candidateId, cur.id })
    push(src)
end)

RegisterNetEvent('pup-voting:server:setDuration', function(hours)
    local src <const> = source
    if not staffGate(src) then return end
    hours = tonumber(hours)
    if not hours or hours ~= hours or hours < 1 or hours > 24 * 60 then return end
    hours = math.floor(hours)

    local cur <const> = workingElection()
    if not cur then return end

    if cur.running then
        -- already open: the clock is reset from now, every region together
        pcall(MySQL.update.await,
            'UPDATE election SET hours = ?, ends_at = DATE_ADD(NOW(), INTERVAL ? HOUR) WHERE id = ?',
            { hours, hours, cur.id })
        logit('Election rescheduled', {
            ('**Election:** #%d'):format(cur.id),
            ('**Now runs for:** %d hours from now'):format(hours),
            ('**By:** %s'):format(whoIs(src)),
        })
    else
        pcall(MySQL.update.await, 'UPDATE election SET hours = ? WHERE id = ?', { hours, cur.id })
    end
    push(src)
end)

-- the whole thing opens at once, so every region shares one clock
RegisterNetEvent('pup-voting:server:start', function()
    local src <const> = source
    if not staffGate(src) then return end

    local cur <const> = workingElection()
    if not cur or not cur.draft then return end

    local okN, n = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM election_candidates WHERE election_id = ?', { cur.id })
    if not okN or (tonumber(n) or 0) == 0 then
        notify(src, Locale.needCandidates)
        return push(src)
    end

    pcall(MySQL.update.await, [[
        UPDATE election
        SET open = 1, started_at = NOW(), ends_at = DATE_ADD(NOW(), INTERVAL ? HOUR)
        WHERE id = ? ]], { cur.hours, cur.id })

    logit('Election opened', {
        ('**Election:** #%d'):format(cur.id),
        ('**Runs for:** %d hours'):format(cur.hours),
        ('**Candidates:** %d'):format(tonumber(n) or 0),
        ('**Opened by:** %s'):format(whoIs(src)),
    })
    notify(src, Locale.started)
    push(src)
end)

RegisterNetEvent('pup-voting:server:setOpen', function(electionId, open)
    local src <const> = source
    if not staffGate(src) then return end
    electionId = tonumber(electionId)
    if not electionId then return end

    if open then
        -- reopening restarts the shared clock; a past end date would close it again at once
        pcall(MySQL.update.await, [[
            UPDATE election
            SET open = 1, started_at = COALESCE(started_at, NOW()),
                ends_at = DATE_ADD(NOW(), INTERVAL hours HOUR)
            WHERE id = ? ]], { electionId })
    else
        pcall(MySQL.update.await, 'UPDATE election SET open = 0 WHERE id = ?', { electionId })
    end

    logit(open and 'Election reopened' or 'Election closed', {
        ('**Election:** #%d'):format(electionId),
        ('**By:** %s'):format(whoIs(src)),
        tally(electionId),
    })
    push(src)
end)

-- closes expired elections (every region at once) and posts the result
CreateThread(function()
    while true do
        Wait(60000)
        local ok, rows = pcall(MySQL.query.await,
            'SELECT id FROM election WHERE open = 1 AND ends_at IS NOT NULL AND ends_at <= NOW()')
        for _, r in ipairs((ok and rows) or {}) do
            pcall(MySQL.update.await, 'UPDATE election SET open = 0 WHERE id = ?', { r.id })
            logit('Election ended', {
                ('**Election:** #%d'):format(r.id),
                tally(r.id),
            })
        end
    end
end)

RegisterNetEvent('pup-voting:server:delete', function(electionId)
    local src <const> = source
    if not staffGate(src) then return end
    electionId = tonumber(electionId)
    if not electionId then return end

    -- logged before the delete, while the result still exists
    logit('Election deleted', {
        ('**Election:** #%d'):format(electionId),
        ('**By:** %s'):format(whoIs(src)),
        tally(electionId),
    })

    pcall(MySQL.update.await, 'DELETE FROM election_votes WHERE election_id = ?', { electionId })
    pcall(MySQL.update.await, 'DELETE FROM election_candidates WHERE election_id = ?', { electionId })
    pcall(MySQL.update.await, 'DELETE FROM election WHERE id = ?', { electionId })
    push(src)
end)
