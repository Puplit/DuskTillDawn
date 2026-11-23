-- pup_hideouts | bare-knuckle betting table

local BK <const> = Config.Bookie

HX.Bookie = {}
local tables = {} -- [hideoutId] = { bets = { [charid] = { A, B } }, pot, totals = { A, B }, firstAt, fight }

-- ids first: refunds await the database, and a bet placed meanwhile must not upset the walk
local function tableIds()
    local ids = {}
    for id in pairs(tables) do ids[#ids + 1] = id end
    return ids
end

local function tbl(id)
    local t = tables[id]
    if not t then
        t = { bets = {}, pot = 0, totals = { A = 0, B = 0 }, firstAt = nil, fight = nil }
        tables[id] = t
    end
    return t
end

local function statePayload(t)
    return {
        pot = U.round2(t.pot), a = U.round2(t.totals.A), b = U.round2(t.totals.B),
        fight = t.fight ~= nil, netIds = t.fight and t.fight.netIds or nil,
    }
end

function HX.Bookie.sendState(id, src)
    local t = tables[id]
    if not t or (t.pot <= 0 and not t.fight) then return end
    TriggerClientEvent('pup_hideouts:bookieState', src, id, statePayload(t))
end

local function broadcast(id)
    local t = tables[id]
    local h = HX.hideouts[id]
    if not h then return end
    local payload = t and statePayload(t) or { pot = 0, a = 0, b = 0, fight = false }
    for _, s in ipairs(HX.insideSources(h)) do
        TriggerClientEvent('pup_hideouts:bookieState', s, id, payload)
    end
end

-- take the table off the room first, so nothing can pay out of it twice while we await the database
local function detach(id)
    local t = tables[id]
    tables[id] = nil
    if t and t.fight and t.fight.starter and GetPlayerName(t.fight.starter) then
        local starter = t.fight.starter
        SetTimeout(5000, function() TriggerClientEvent('pup_hideouts:bookieCleanup', starter, id) end)
    end
    broadcast(id)
    return t
end

-- give every stake back (online by cash, offline into the characters table)
function HX.Bookie.refundAll(id, msgKey)
    local t = detach(id)
    if not t then return end
    for cid, b in pairs(t.bets) do
        local amount = U.round2((b.A or 0) + (b.B or 0))
        if amount > 0 then
            local s = HX.payChar(cid, amount)
            if s then HX.tip(s, L(msgKey or 'fight_off')) end
        end
    end
end

HX.rpc('bet', function(src, id, side, amount)
    local h = HX.hideouts[tonumber(id)]
    amount = U.posInt(amount)
    if not h or not h.bookie or (side ~= 'A' and side ~= 'B') then return false end
    if not amount then HX.tip(src, L('bad_amount')) return false end
    if not HX.isInside(src, h) then HX.tip(src, L('too_far')) return false end
    local t = tbl(h.id)
    if t.fight then HX.tip(src, L('fight_on')) return false end
    if not HX.takeCash(src, amount) then HX.tip(src, L('bet_no_money', amount)) return false end
    local cid = HX.charId(src)
    t.bets[cid] = t.bets[cid] or { A = 0, B = 0 }
    t.bets[cid][side] = t.bets[cid][side] + amount
    t.totals[side] = t.totals[side] + amount
    t.pot = t.pot + amount
    t.firstAt = t.firstAt or os.time()
    HX.tip(src, L('bet_placed'))
    broadcast(h.id)
    Logs.send('Main', 'Bet Placed', ('$%d on fighter %s'):format(amount, side), 'betPlaced', src,
        { { 'Amount', '$' .. amount, true }, { 'Fighter', side, true } }, h)
    return true
end, 1000)

HX.rpc('fightStart', function(src, id)
    local h = HX.memberInside(src, id)
    if not h or not h.bookie then return false end
    local t = tables[h.id]
    if not t or t.pot <= 0 then return false end
    if t.fight then HX.tip(src, L('fight_on')) return false end
    t.fight = {
        starter = src, winner = math.random(2) == 1 and 'A' or 'B',
        duration = math.random(BK.fightMin, BK.fightMax), startedAt = os.time(), netIds = nil,
    }
    broadcast(h.id)
    -- the winner stays on the server until the end: a starter who knew it could call the fight
    -- off (leave, or report a dead fighter) whenever his own side was going to lose
    TriggerClientEvent('pup_hideouts:bookieStage', src, h.id, t.fight.duration)
    for _, s in ipairs(HX.insideSources(h)) do HX.tip(s, L('fight_started')) end
    Logs.send('Main', 'Fight Started', 'The fighters squared up', 'fightStarted', src, {}, h)
    return true
end, 2000)

HX.on('bookieFighters', function(src, id, netA, netB)
    local t = tables[tonumber(id)]
    if not t or not t.fight or t.fight.starter ~= src then return end
    t.fight.netIds = { A = tonumber(netA), B = tonumber(netB) }
    broadcast(tonumber(id))
end, 1000)

-- a fighter really died, or they could not be spawned: everything back
HX.on('bookieAbort', function(src, id)
    local t = tables[tonumber(id)]
    if not t or not t.fight or t.fight.starter ~= src then return end
    HX.Bookie.refundAll(tonumber(id), 'fight_off')
end, 1000)

local function settle(id)
    local h = HX.hideouts[id]
    if not h or not tables[id] or not tables[id].fight then return end
    local t = detach(id)
    local winner = t.fight.winner
    for _, s in ipairs(HX.insideSources(h)) do HX.tip(s, L('fighter_wins', winner)) end
    if t.fight.starter and GetPlayerName(t.fight.starter) then
        TriggerClientEvent('pup_hideouts:bookieFinish', t.fight.starter, id, winner)
    end
    local winTotal = t.totals[winner]
    local pot = t.pot
    if winTotal <= 0 then
        h.ledger = U.round2(h.ledger + pot)
    else
        local share = pot * (1 - BK.houseCut)
        h.ledger = U.round2(h.ledger + pot * BK.houseCut)
        for cid, b in pairs(t.bets) do
            local stake = b[winner] or 0
            if stake > 0 then
                local win = U.round2(share * stake / winTotal)
                local s = HX.payChar(cid, win)
                if s then HX.tip(s, L('you_won', U.money(win))) end
            end
        end
    end
    h = HX.hideouts[id] or h
    HX.save(h, { 'ledger' })
    HX.changed(h)
end

-- the starter left the room mid-fight
function HX.Bookie.onLeft(src, nowInId)
    for _, id in ipairs(tableIds()) do
        local t = tables[id]
        if t and t.fight and t.fight.starter == src and nowInId ~= id then
            HX.Bookie.refundAll(id, 'fight_interrupted')
        end
    end
end

function HX.Bookie.dropped(src)
    HX.Bookie.onLeft(src, nil)
end

-- scheduled restart: every table with a pot is refunded
function HX.Bookie.refundEverything()
    for _, id in ipairs(tableIds()) do
        local t = tables[id]
        if t and t.pot > 0 then HX.Bookie.refundAll(id, 'fight_interrupted2') end
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        for _, id in ipairs(tableIds()) do
            local t = tables[id]
            local now = os.time()
            if t and t.fight then
                if now >= t.fight.startedAt + BK.startDelay + t.fight.duration then settle(id) end
            elseif t and t.firstAt and now - t.firstAt >= BK.betExpiryMinutes * 60 then
                HX.Bookie.refundAll(id, 'fight_interrupted2')
            end
        end
    end
end)
