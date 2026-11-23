-- The ballot box and the election office, both on pup-ui's list menu.

local OWNER <const> = 'pup-voting:menu'
local L <const> = Locale

local cycles = {}         -- elections, newest first
local staff = false
local enabled = false     -- fails closed until the server's first state arrives
local gotState = false    -- the server has answered at least once
local stateAt = 0         -- GetGameTimer() when the state landed, for the local countdown

local level = nil         -- what the open menu is showing
local ctx = {}            -- one entry per option row, always in lockstep
local rerender = nil      -- redraws the open screen, for the live countdown
local backFn = nil        -- where ESC goes from here
local fromOffice = false  -- results were opened by staff, so ESC goes back there

local pollPrompt = nil

-- ------------------------------------------------------------------ helpers

local function fmtLeft(secs)
    secs = tonumber(secs) or 0
    if secs <= 0 then return nil end
    local d = math.floor(secs / 86400)
    local h = math.floor((secs % 86400) / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    if d > 0 then return ('%dd %dh'):format(d, h) end
    if h > 0 then return ('%dh %dm'):format(h, m) end
    if m > 0 then return ('%dm %ds'):format(m, s) end
    return ('%ds'):format(s)
end

-- the server sends one snapshot; the seconds since then come off it locally
local function secsLeft(c)
    if not c or not c.live then return 0 end
    return (tonumber(c.endsLeft) or 0) - math.floor((GetGameTimer() - stateAt) / 1000)
end

local function isLive(c)
    if not c or not c.live then return false end
    if c.endsLeft == nil then return true end
    return secsLeft(c) > 0
end

local function statusOf(c)
    local left = fmtLeft(secsLeft(c))
    return left and L.endsIn:format(left) or L.endedAt
end

local function timeValue(c)
    local left = fmtLeft(secsLeft(c))
    return left and L.leftShort:format(left) or nil
end

-- the draft or the open election (open, not live, matching the server, so an expired one awaiting the sweep still counts)
local function working()
    local c = cycles[1]
    if c and (c.draft or c.open) then return c end
    return nil
end

-- the shared clock, first thing on every screen
local function clockLine()
    local c = working() or cycles[1]
    if not c then return L.noElections end
    if c.draft then return L.draftTitle end
    if isLive(c) then return statusOf(c) end
    return L.endedAt
end

local function topLine(extra)
    local clock <const> = clockLine()
    if extra and extra ~= '' then return ('%s   -   %s'):format(clock, extra) end
    return clock
end

local function topIcon()
    if not enabled then return 'lock' end
    local c = working()
    return (c and isLive(c)) and 'clock' or 'star'
end

local function cycleById(id)
    for _, c in ipairs(cycles) do if c.id == id then return c end end
end

local function bucketOf(c, region)
    for _, b in ipairs(c and c.regions or {}) do
        if b.region == region then return b end
    end
    return nil
end

local function standingText(b)
    local n = b and #(b.candidates or {}) or 0
    if n == 0 then return L.nobodyYet end
    if n == 1 then return L.oneStanding end
    return L.standing:format(n)
end

-- everyone level on top, so a tie reads as a tie rather than an arbitrary pick
local function leaders(b)
    local names = {}
    for _, c in ipairs(b and b.candidates or {}) do
        if c.lead then names[#names + 1] = c.name end
    end
    return names
end

local function outcomeOf(b)
    if not b or not b.counted then return L.noVotes end
    local names = leaders(b)
    if #names > 1 then return L.tied:format(table.concat(names, ', ')) end
    return L.winner:format(names[1] or '?')
end

local function anyLive()
    for _, c in ipairs(cycles) do if isLive(c) then return true end end
    return false
end

local function byName(list)
    local out = {}
    for _, v in ipairs(list or {}) do out[#out + 1] = v end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function open(data)
    -- an all-disabled screen would leave the keyboard dead, so add a way back
    local any = false
    for _, o in ipairs(data.options or {}) do
        if not o.disabled then any = true break end
    end
    if not any then
        -- pinned, so a search box on the same screen cannot filter the way out away
        data.options[#data.options + 1] = { label = L.goBack, desc = '', icon = 'x', pinned = true }
        ctx[#data.options] = { kind = 'back' }
    end
    data.owner = OWNER
    data.keyboard = true
    data.subtitleIcon = data.subtitleIcon or topIcon()
    exports['pup-ui']:OpenListMenu(data)
end

-- ------------------------------------------------------------------ screens

local openBallot, openResults, openVoters, openConfirm
local openOffice, openRegion, openDurations, openMatches

-- THE BALLOT: the people standing come first, their region underneath
openBallot = function(keep)
    level = 'ballot'
    ctx = {}
    local options = {}
    local function add(opt, pick)
        options[#options + 1] = opt
        ctx[#options] = pick or false
    end

    if staff then
        add({ label = L.office, desc = L.officeDesc, icon = 'key',
            value = enabled and L.on or L.off }, { kind = 'office' })
    end
    if not enabled then
        add({ label = L.votingOff, desc = L.closed, icon = 'lock', disabled = true })
    end

    local live <const> = isLive(cycles[1]) and cycles[1] or nil
    if live then
        local tv <const> = timeValue(live)
        for _, b in ipairs(live.regions) do
            for _, c in ipairs(byName(b.candidates)) do
                local mine <const> = (c.id == b.myVote)
                local desc = b.region
                if mine then desc = ('%s   -   %s'):format(b.region, L.yourVote)
                elseif b.myVote then desc = ('%s   -   %s'):format(b.region, L.alreadyHere) end
                add({
                    label = c.name,
                    desc = desc,
                    icon = mine and 'check' or 'user',
                    value = tv,
                    disabled = (b.myVote ~= nil or not enabled) or nil,
                }, { kind = 'candidate', candidate = c.id, name = c.name })
            end
        end
    else
        add({ label = L.noElections, desc = '', icon = 'info', disabled = true })
    end

    -- the last finished election's result, so players read the outcome here too
    for _, c in ipairs(cycles) do
        if c.started and not isLive(c) then
            add({ label = L.results, desc = c.total and L.totalVotes:format(c.total) or L.resultsDesc, icon = 'medal' },
                { kind = 'results', id = c.id })
            break
        end
    end

    open({
        title = L.ballot,
        subtitle = topLine(L.pickName),
        options = options,
        keepCursor = keep or nil,
    })
    rerender = function(k) openBallot(k) end
    backFn = nil
end

-- RESULTS: every region, the winner first, then everyone with their number
openResults = function(id, keep, staffSide)
    local c = cycleById(id)
    if not c then return staffSide and openOffice() or openBallot() end
    level = 'results'
    fromOffice = staffSide and true or false
    ctx = {}
    local options = {}
    local function add(opt, pick)
        options[#options + 1] = opt
        ctx[#options] = pick or false
    end

    -- an open ballot shows names only, so an early lead cannot steer the remaining voters
    local sealed <const> = isLive(c)

    for _, b in ipairs(c.regions) do
        add({
            label = b.region,
            desc = sealed and L.sealed or outcomeOf(b),
            icon = sealed and 'lock' or 'medal',
            value = (not sealed and b.total) and L.totalVotes:format(b.total) or nil,
            disabled = true,
        })
        -- by name while sealed: vote order would give the standings away on its own
        for _, cand in ipairs(sealed and byName(b.candidates) or (b.candidates or {})) do
            local pct = cand.percent or 0
            local won = not sealed and cand.lead
            -- staff are sent the count as well; players get the share, or nothing on a small count
            local share = cand.votes and L.share:format(pct, cand.votes)
                or cand.percent and L.shareOnly:format(pct)
                or L.tooFewVotes
            add({
                label = cand.name,
                desc = sealed and ''
                    or (won and ('%s   -   %s'):format(share, L.leaderTag) or share),
                icon = won and 'star' or 'user',
                value = (not sealed) and (cand.votes and tostring(cand.votes) or cand.percent and L.shareOnly:format(pct)) or nil,
                disabled = true,
            })
        end
    end

    if #c.regions == 0 then
        add({ label = L.noCandidates, desc = '', icon = 'info', disabled = true })
    end

    if not sealed and staff then
        add({ label = L.whoVoted, desc = L.totalVotes:format(c.total or 0), icon = 'doc' },
            { kind = 'voters', id = c.id })
    end

    open({
        title = L.results,
        subtitle = topLine(),
        options = options,
        keepCursor = keep or nil,
    })
    rerender = function(k) openResults(id, k, staffSide) end
    backFn = function()
        if staffSide then return openOffice() end
        openBallot()
    end
end

-- the rows are held so the countdown above them can redraw without asking again
local voterRows, voterId, voterSide = nil, nil, false

openVoters = function(id, rows, staffSide, keep)
    if rows then voterRows, voterId, voterSide = rows, id, staffSide and true or false end
    level = 'voters'
    ctx = {}
    local options = {}
    local region = nil
    for _, r in ipairs(voterRows or {}) do
        if r.region ~= region then
            region = r.region
            options[#options + 1] = { label = region, desc = '', icon = 'flag', disabled = true }
            ctx[#options] = false
        end
        options[#options + 1] = {
            label = r.voter_name or '?',
            desc = r.candidate or '',
            icon = 'user',
            disabled = true,
        }
        ctx[#options] = false
    end
    if #options == 0 then
        options[1] = { label = L.noVotes, desc = '', icon = 'info', disabled = true }
        ctx[1] = false
    end

    local c <const> = cycleById(voterId)
    open({
        title = L.whoVoted,
        subtitle = topLine(L.totalVotes:format(c and c.total or 0)),
        options = options,
        search = #options > 12 and L.searchVoters or nil,
        keepCursor = keep or nil,
    })
    rerender = function(k) openVoters(voterId, nil, voterSide, k) end
    backFn = function() openResults(voterId, nil, voterSide) end
end

local confirmCand, confirmName = nil, nil

openConfirm = function(candidate, name, keep)
    if candidate then confirmCand, confirmName = candidate, name end
    level = 'confirm'
    ctx = {
        { kind = 'confirmYes', candidate = confirmCand },
        { kind = 'confirmNo' },
    }
    open({
        title = L.ballot,
        subtitle = topLine(L.confirmVote:format(confirmName or '?')),
        options = {
            { label = L.confirmYes, desc = L.onePerAccount, icon = 'check' },
            { label = L.confirmNo,  desc = '', icon = 'x' },
        },
        keepCursor = keep or nil,
    })
    rerender = function(k) openConfirm(nil, nil, k) end
    backFn = function() openBallot() end
end

-- ------------------------------------------------------------------- office

openOffice = function(keep)
    level = 'office'
    ctx = {}
    local options = {}
    local function add(opt, pick)
        options[#options + 1] = opt
        ctx[#options] = pick or false
    end

    add({
        label = enabled and L.turnOff or L.turnOn,
        desc = enabled and L.switchOffDesc or L.switchOnDesc,
        icon = enabled and 'check' or 'lock',
        value = enabled and L.on or L.off,
    }, { kind = 'toggle' })

    local cur <const> = working()

    if not cur then
        add({ label = cycles[1] and L.setUpAgain or L.setUp, desc = L.setUpDesc, icon = 'plus' },
            { kind = 'setUp' })

    elseif cur.draft then
        local total = 0
        for _, b in ipairs(cur.regions) do total = total + #(b.candidates or {}) end
        add({
            label = L.openPolls,
            desc = total > 0 and L.openPollsDesc or L.needCandidates,
            icon = 'star',
            value = L.hours:format(cur.hours),
            disabled = total == 0 or nil,
        }, { kind = 'start' })
        add({ label = L.setDuration, desc = '', icon = 'clock',
            value = L.hours:format(cur.hours) }, { kind = 'duration' })
        for _, region in ipairs(Config.Election.regions) do
            add({ label = region, desc = standingText(bucketOf(cur, region)), icon = 'user' },
                { kind = 'region', region = region })
        end
        add({ label = L.scrapIt, desc = L.confirmDelete, icon = 'x' },
            { kind = 'delete', id = cur.id })

    else -- open; the clock may have run out, the sweep closes it within a minute
        -- no tallies for anyone, staff included, until the polls shut
        local ticking <const> = isLive(cur)
        add({ label = ticking and L.running or L.endedAt,
            desc = ticking and statusOf(cur) or '',
            icon = ticking and 'clock' or 'medal',
            value = ticking and nil or L.totalVotes:format(cur.total or 0),
            disabled = true })
        if not ticking then
            add({ label = L.results, desc = '', icon = 'chart' }, { kind = 'results', id = cur.id })
        end
        add({ label = L.setDuration, desc = statusOf(cur), icon = 'clock',
            value = L.hours:format(cur.hours) }, { kind = 'duration' })
        add({ label = L.closeNow, desc = '', icon = 'lock' },
            { kind = 'close', id = cur.id })
        for _, b in ipairs(cur.regions) do
            add({ label = b.region, desc = standingText(b), icon = 'user',
                value = ticking and nil or L.totalVotes:format(b.total or 0), disabled = true })
        end
        add({ label = L.deleteIt, desc = L.confirmDelete, icon = 'x' },
            { kind = 'delete', id = cur.id })
    end

    -- the last finished election, skipping cur (an expired-but-open one matches too)
    for _, c in ipairs(cycles) do
        if c ~= cur and c.started and not isLive(c) then
            add({ label = L.results, desc = L.endedAt, icon = 'medal',
                value = L.totalVotes:format(c.total or 0) }, { kind = 'results', id = c.id })
            add({ label = L.reopen, desc = L.hours:format(c.hours), icon = 'star' },
                { kind = 'reopen', id = c.id })
            add({ label = L.deleteIt, desc = L.confirmDelete, icon = 'x' },
                { kind = 'delete', id = c.id })
            break
        end
    end

    open({
        title = L.office,
        subtitle = topLine(),
        options = options,
        keepCursor = keep or nil,
    })
    rerender = function(k) openOffice(k) end
    backFn = nil
end

-- one region of the draft
openRegion = function(region, keep)
    local cur <const> = working()
    if not cur or not cur.draft then return openOffice() end
    level = 'region'
    ctx = {}
    local options = {}
    local function add(opt, pick)
        options[#options + 1] = opt
        ctx[#options] = pick or false
    end

    add({ label = L.addCandidate, desc = L.candidateSearch, icon = 'plus' },
        { kind = 'add', region = region })

    local b <const> = bucketOf(cur, region)
    for _, c in ipairs(b and b.candidates or {}) do
        add({ label = c.name, desc = L.removeOne, icon = 'user' },
            { kind = 'remove', region = region, candidate = c.id })
    end

    open({
        title = L.office,
        subtitle = topLine(('%s   -   %s'):format(region, standingText(b))),
        options = options,
        keepCursor = keep or nil,
    })
    rerender = function(k) openRegion(region, k) end
    backFn = function() openOffice() end
end

openDurations = function(keep)
    level = 'duration'
    ctx = {}
    local options = {}
    for _, h in ipairs(Config.Election.durationsHours) do
        options[#options + 1] = { label = L.hours:format(h), desc = '', icon = 'clock' }
        ctx[#options] = { kind = 'setDuration', hours = h }
    end
    open({
        title = L.office,
        subtitle = topLine(L.setDuration),
        options = options,
        keepCursor = keep or nil,
    })
    rerender = function(k) openDurations(k) end
    backFn = function() openOffice() end
end

local matchRows, matchRegion = nil, nil

openMatches = function(region, matches, keep)
    if matches then matchRows, matchRegion = matches, region end
    level = 'candidates'
    ctx = {}
    local options = {}
    for _, m in ipairs(matchRows or {}) do
        options[#options + 1] = { label = m.name, desc = ('#%d'):format(m.charid), icon = 'user' }
        ctx[#options] = { kind = 'addMatch', region = matchRegion, charid = m.charid }
    end
    open({
        title = L.office,
        subtitle = topLine(('%s   -   %s'):format(matchRegion, L.pickCandidate)),
        options = options,
        search = #options > 12 or nil,
        keepCursor = keep or nil,
    })
    rerender = function(k) openMatches(nil, nil, k) end
    backFn = function() openRegion(matchRegion) end
end

-- ------------------------------------------------------------------ handlers

-- OpenInput answers on pup-ui:client:inputDone; it does not return the value
local inputPending = nil

local function askText(title, done)
    inputPending = done
    exports['pup-ui']:OpenInput({
        owner = OWNER,
        title = title,
        submit = L.confirmYes,
        fields = { { label = title, type = 'text', placeholder = title } },
    })
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= OWNER then return end
    local cb = inputPending
    inputPending = nil
    if not cb then return end
    cb((type(values) == 'table') and tostring(values[1] or '') or '')
end)

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= OWNER then return end
    local pick = ctx[index]
    if not pick then return end

    if pick.kind == 'toggle' then
        return TriggerServerEvent('pup-voting:server:setEnabled', not enabled)

    elseif pick.kind == 'office' then
        if not staff then return TriggerEvent('vorp:TipRight', L.noPermission, 4000) end
        return openOffice()

    elseif pick.kind == 'setUp' then
        return TriggerServerEvent('pup-voting:server:createDraft')

    elseif pick.kind == 'region' then
        return openRegion(pick.region)

    elseif pick.kind == 'add' then
        return askText(L.candidateSearch, function(term)
            if term == '' then return openRegion(pick.region) end
            TriggerServerEvent('pup-voting:server:findCandidate', pick.region, term)
        end)

    elseif pick.kind == 'remove' then
        return TriggerServerEvent('pup-voting:server:removeCandidate', pick.candidate)

    elseif pick.kind == 'addMatch' then
        TriggerServerEvent('pup-voting:server:addCandidate', pick.region, pick.charid)
        return SetTimeout(400, function() openRegion(pick.region) end)

    elseif pick.kind == 'duration' then
        return openDurations()

    elseif pick.kind == 'setDuration' then
        -- the duration list redraws itself, so step back to the office by hand
        TriggerServerEvent('pup-voting:server:setDuration', pick.hours)
        return SetTimeout(400, function() openOffice() end)

    elseif pick.kind == 'start' then
        return TriggerServerEvent('pup-voting:server:start')

    elseif pick.kind == 'close' then
        return TriggerServerEvent('pup-voting:server:setOpen', pick.id, false)

    elseif pick.kind == 'reopen' then
        return TriggerServerEvent('pup-voting:server:setOpen', pick.id, true)

    elseif pick.kind == 'delete' then
        return TriggerServerEvent('pup-voting:server:delete', pick.id)

    elseif pick.kind == 'results' then
        return openResults(pick.id, nil, level == 'office')

    elseif pick.kind == 'voters' then
        return TriggerServerEvent('pup-voting:server:voters', pick.id)

    elseif pick.kind == 'candidate' then
        if not enabled then return TriggerEvent('vorp:TipRight', L.votingOff, 4000) end
        -- a vote cannot be taken back, so it is confirmed before it is sent
        return openConfirm(pick.candidate, pick.name)

    elseif pick.kind == 'confirmYes' then
        TriggerServerEvent('pup-voting:server:vote', pick.candidate)
        level, rerender, backFn = nil, nil, nil
        return exports['pup-ui']:HideListMenu()

    elseif pick.kind == 'confirmNo' or pick.kind == 'back' then
        if backFn then return backFn() end
        level, rerender, backFn = nil, nil, nil
        return exports['pup-ui']:HideListMenu()
    end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= OWNER then return end
    local back = backFn
    if back then return back() end
    level, rerender, backFn = nil, nil, nil
    exports['pup-ui']:HideListMenu()
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= nil and owner ~= OWNER then return end
    level, ctx, rerender, backFn = nil, {}, nil, nil
end)

-- ------------------------------------------------------------------- wiring

RegisterNetEvent('pup-voting:client:state', function(list, isStaff, isEnabled)
    cycles = type(list) == 'table' and list or {}
    staff = isStaff and true or false
    if isEnabled ~= nil then enabled = isEnabled and true or false end
    gotState = true
    stateAt = GetGameTimer()
    if rerender and level and not inputPending then rerender(true) end
end)

RegisterNetEvent('pup-voting:client:enabled', function(isEnabled)
    enabled = isEnabled and true or false
    if rerender and level and not inputPending then rerender(true) end
end)

RegisterNetEvent('pup-voting:client:voters', function(electionId, _, rows)
    openVoters(electionId, rows or {}, fromOffice)
end)

-- the search answered: pick the right character rather than trusting the typing
RegisterNetEvent('pup-voting:client:candidates', function(region, matches)
    if type(matches) ~= 'table' or #matches == 0 then
        TriggerEvent('vorp:TipRight', L.noMatches, 5000)
        return openRegion(region)
    end
    openMatches(region, matches)
end)

-- ------------------------------------------------------------------ commands

-- there is no /vote on purpose: players cast one at a polling station
RegisterCommand(Config.General.command or 'election', function()
    TriggerServerEvent('pup-voting:server:get')
    SetTimeout(400, function()
        if not staff then return TriggerEvent('vorp:TipRight', L.noPermission, 4000) end
        openOffice()
    end)
end, false)

-- the clock ticks locally; the server is asked again every 15 s for fresh state
CreateThread(function()
    local n = 0
    while true do
        Wait(1000)
        if level and rerender and not inputPending then
            n = n + 1
            if n >= 15 then
                n = 0
                TriggerServerEvent('pup-voting:server:get')
            elseif anyLive() then
                rerender(true)
            end
        else
            n = 0
        end
    end
end)

-- ------------------------------------------------------------- polling station

-- keep asking until the server has answered once; no station appears until then
CreateThread(function()
    Wait(3000)
    local tries = 0
    while not gotState and tries < 12 do
        TriggerServerEvent('pup-voting:server:get')
        tries = tries + 1
        Wait(5000)
    end
end)

CreateThread(function()
    Wait(3000)

    if #(Config.Polling.locations or {}) == 0 then return end

    pollPrompt = PromptRegisterBegin()
    PromptSetControlAction(pollPrompt, Config.Keys.vote or 0x760A9C6F)
    PromptSetText(pollPrompt, CreateVarString(10, 'LITERAL_STRING', L.openPrompt))
    PromptSetEnabled(pollPrompt, 1)
    PromptSetVisible(pollPrompt, 1)
    PromptSetStandardMode(pollPrompt, 1)
    PromptRegisterEnd(pollPrompt)
    local group <const> = GetRandomIntInRange(0, 0xffffff)
    PromptSetGroup(pollPrompt, group)

    while true do
        local wait = 500
        local p <const> = GetEntityCoords(PlayerPedId())
        local atPoll = false
        if enabled then
            for _, loc in ipairs(Config.Polling.locations) do
                local dx, dy = p.x - loc.x, p.y - loc.y
                if (dx * dx + dy * dy) <= ((Config.Polling.radius or 2.0) ^ 2)
                    and math.abs(p.z - loc.z) <= 3.0 then
                    atPoll = true
                    break
                end
            end
        end
        if atPoll then
            wait = 0
            -- the group label is only referenced, so it is rebuilt every frame
            PromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', L.ballot))
            if PromptHasStandardModeCompleted(pollPrompt) then
                TriggerServerEvent('pup-voting:server:get')
                SetTimeout(400, function() openBallot() end)
            end
        end
        Wait(wait)
    end
end)
