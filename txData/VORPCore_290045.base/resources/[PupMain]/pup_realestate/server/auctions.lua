-- pup_realestate | auctions: escrowed bank bids at the town hall, resolved by a one-minute clock

local busy = {} -- auction id -> true while a bid, cancel or resolution runs
S.auctionStamp = 0 -- bumped whenever an auction is created or cancelled

local function withAuction(aid, fn)
    local waited = 0
    while busy[aid] and waited < 10000 do
        Wait(100)
        waited = waited + 100
    end
    if busy[aid] then return false end
    busy[aid] = true
    local ok, err = pcall(fn)
    busy[aid] = nil
    if not ok then Warn('auction %s: %s', aid, tostring(err)) end
    return true
end

local function auctionRow(aid)
    local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM housing_auctions WHERE id = ? LIMIT 1', { aid })
    return ok and rows and rows[1] or nil
end

local function titleOf(houseId)
    local h = S.houses[houseId]
    if h then return U.title(h) end
    return ('House #%s'):format(houseId)
end

local function broadcastAuctioned()
    TriggerClientEvent('pup_realestate:cl_auctioned', -1, S.auctionedList())
end

local function endsIn(sec)
    sec = math.max(0, sec)
    local d, h, m = sec // 86400, (sec % 86400) // 3600, (sec % 3600) // 60
    if d > 0 then return ('Ends in %dd %dh'):format(d, h) end
    if h > 0 then return ('Ends in %dh %dm'):format(h, m) end
    return ('Ends in %dm'):format(math.max(1, m))
end

local function ago(ts)
    ts = tonumber(ts)
    if not ts or ts <= 0 then return '-' end
    local s = Now() - ts
    if s < 60 then return 'just now' end
    if s < 3600 then return ('%dm ago'):format(s // 60) end
    if s < 86400 then return ('%dh ago'):format(s // 3600) end
    return ('%dd ago'):format(s // 86400)
end

local function canRun(ch)
    return S.isHouseAdmin(ch) or S.isAuctionRealtor(ch)
end

-- create (from vorp_admin's panel)
local creating = {}

Net('auctionCreate', 1000, function(src, ch, houseId, minimum, hours)
    if not canRun(ch) then return Tip(src, 'You are not allowed to do that') end
    local h = S.house(houseId)
    if not h then return Tip(src, 'No such house') end
    if h.owned then return Tip(src, 'That house is owned - only unowned or repossessed houses can go to auction') end
    if creating[h.id] then return end
    minimum = U.int(minimum)
    if not minimum or minimum <= 0 then return Tip(src, 'The minimum bid must be above $0') end
    hours = U.int(hours) or 0
    if hours <= 0 then hours = Config.Auctions.defaultHours end
    if hours > Config.Auctions.maxHours then hours = Config.Auctions.maxHours end
    creating[h.id] = true
    local ok, err = pcall(function()
        local okQ, open = pcall(MySQL.scalar.await, "SELECT id FROM housing_auctions WHERE houseid = ? AND status = 'open' LIMIT 1", { h.id })
        if not okQ then return Tip(src, 'Could not create the auction') end
        if open then return Tip(src, 'That house already has an open auction') end
        local okI, aid = pcall(MySQL.insert.await, [[
            INSERT INTO housing_auctions (houseid, minbid, endts, status, topbid, topcharid, topname, createdby, createdts, topbank)
            VALUES (?, ?, ?, 'open', 0, NULL, '', ?, ?, NULL)]],
            { h.id, minimum, Now() + hours * 3600, ch.name, Now() })
        aid = okI and U.int(aid)
        if not aid then return Tip(src, 'Could not create the auction') end
        S.auctionStamp = S.auctionStamp + 1
        S.auctioned[h.id] = aid
        broadcastAuctioned()
        Activity(h.id, 'AUCTION_START', ('min $%s, %sh'):format(minimum, hours), S.actor(ch))
        AdminLog(('%s started auction %s for house %s: min $%s, %sh'):format(ch.name, aid, h.id, minimum, hours))
        Tip(src, ('Auction started for %s - minimum bid $%s, ends in %sh'):format(U.title(h), U.money(minimum), hours), 6000)
    end)
    creating[h.id] = nil
    if not ok then Warn('auction create: %s', tostring(err)) end
end)

-- cancel: refund the escrowed top bid
local function cancelRow(aid, reasonLetter, note)
    local result
    withAuction(aid, function()
        local row = auctionRow(aid)
        if not row then result = 'missing'; return end
        if row.status ~= 'open' then result = row.status; return end
        local okU, n = pcall(MySQL.update.await, "UPDATE housing_auctions SET status = 'cancelled' WHERE id = ? AND status = 'open'", { aid })
        if not okU or n ~= 1 then result = 'failed'; return end
        local houseId = U.int(row.houseid)
        local top, topChar = math.floor(tonumber(row.topbid) or 0), U.int(row.topcharid)
        local title = titleOf(houseId)
        if top > 0 and topChar then
            S.bankRefund(topChar, row.topbank or Config.Auctions.refundBank, top, note)
            S.sendLetter(topChar, 'Auction Cancelled: ' .. title, table.concat({
                reasonLetter,
                '',
                ('Your bid of $%s has been deposited back into your %s account.'):format(U.money(top), row.topbank or Config.Auctions.refundBank),
                '',
                '- Housing Team',
            }, '\n'))
        end
        S.auctionStamp = S.auctionStamp + 1
        if S.auctioned[houseId] == aid then S.auctioned[houseId] = nil end
        result = { houseId = houseId, refund = top > 0 and top or 0 }
    end)
    return result
end

Net('auctionCancel', 1000, function(src, ch, aid)
    if not canRun(ch) then return Tip(src, 'You are not allowed to do that') end
    aid = U.int(aid)
    if not aid then return end
    local res = cancelRow(aid, 'The housing office has cancelled this auction.', 'House auction cancelled')
    if res == 'missing' or res == nil then return Tip(src, 'That auction no longer exists') end
    if type(res) == 'string' then
        if res == 'failed' then return end
        return Tip(src, ('That auction is already %s'):format(res))
    end
    broadcastAuctioned()
    Activity(res.houseId, 'AUCTION_CANCELLED', res.refund > 0 and ('refunded $%s'):format(res.refund) or 'no bids', S.actor(ch))
    AdminLog(('%s cancelled auction %s on house %s (refund $%s)'):format(ch.name, aid, res.houseId, res.refund))
    Tip(src, 'Auction cancelled' .. (res.refund > 0 and ' - the top bid was refunded' or ''))
end)

-- the house is being deleted
function S.cancelAuctionsForHouse(houseId, reason)
    local ok, rows = pcall(MySQL.query.await, "SELECT id FROM housing_auctions WHERE houseid = ? AND status = 'open'", { houseId })
    if not ok then return end
    for _, r in ipairs(rows or {}) do
        local aid = U.int(r.id)
        local res = aid and cancelRow(aid, reason .. '. The auction has been cancelled.', 'House auction cancelled')
        if type(res) == 'table' then
            Activity(houseId, 'AUCTION_CANCELLED', reason .. (res.refund > 0 and (' - refunded $%s'):format(res.refund) or ''), nil)
            AdminLog(('Auction %s on house %s cancelled because the house was deleted (refund $%s)'):format(aid, houseId, res.refund))
        end
    end
    S.auctioned[houseId] = nil
    broadcastAuctioned()
end

-- resolution
local function bidders(aid)
    local ok, rows = pcall(MySQL.query.await, 'SELECT charidentifier, identifier, amount, ts FROM housing_auction_bids WHERE auctionid = ? ORDER BY ts DESC, id DESC', { aid })
    return ok and rows or {}
end

local function voidWinner(row, houseId, title, why, letterWhy)
    local top, topChar = math.floor(tonumber(row.topbid) or 0), U.int(row.topcharid)
    S.bankRefund(topChar, row.topbank or Config.Auctions.refundBank, top, 'House auction voided')
    S.sendLetter(topChar, 'Auction Cancelled: ' .. title, table.concat({
        letterWhy,
        '',
        ('Your winning bid of $%s has been deposited back into your %s account.'):format(U.money(top), row.topbank or Config.Auctions.refundBank),
        '',
        '- Housing Team',
    }, '\n'))
    Activity(houseId, 'AUCTION_UNSOLD', why, nil)
    AdminLog(('Auction %s on house %s voided: %s (refunded $%s to char %s)'):format(row.id, houseId, why, top, topChar))
end

local function resolve(aid)
    withAuction(aid, function()
        local row = auctionRow(aid)
        if not row or row.status ~= 'open' or (tonumber(row.endts) or 0) > Now() then return end
        local okU, n = pcall(MySQL.update.await, "UPDATE housing_auctions SET status = 'ended' WHERE id = ? AND status = 'open'", { aid })
        if not okU or n ~= 1 then return end
        local houseId = U.int(row.houseid)
        if S.auctioned[houseId] == aid then S.auctioned[houseId] = nil end
        local title = titleOf(houseId)
        local top, topChar = math.floor(tonumber(row.topbid) or 0), U.int(row.topcharid)
        if not topChar or top <= 0 then
            Activity(houseId, 'AUCTION_UNSOLD', 'ended with no bids', nil)
            AdminLog(('Auction %s on house %s ended with no bids'):format(aid, houseId))
            return
        end
        local h = S.houses[houseId]
        if not h or h.owned then
            return voidWinner(row, houseId, title, 'house no longer available - top bid refunded',
                'The auction was voided because the house is no longer available.')
        end
        -- the house cap is checked again when the auction ends
        if S.ownedCount(topChar) >= Config.MaxHousesPerCharacter then
            return voidWinner(row, houseId, title, 'winner already owns the maximum number of houses - top bid refunded',
                ('The auction was voided because you already own the maximum of %s houses.'):format(Config.MaxHousesPerCharacter))
        end
        local list = bidders(aid)
        local ident
        for _, b in ipairs(list) do
            if U.int(b.charidentifier) == topChar and b.identifier and b.identifier ~= '' then ident = b.identifier; break end
        end
        if not ident then
            local okC, v = pcall(MySQL.scalar.await, 'SELECT identifier FROM characters WHERE charidentifier = ?', { topChar })
            ident = okC and v or nil
        end
        local name = row.topname ~= '' and row.topname or ('char ' .. topChar)
        S.completeSale(h, { charid = topChar, ident = tostring(ident or '0'), name = name }, top)
        Activity(houseId, 'AUCTION_WON', ('%s won with $%s'):format(name, top), nil)
        AdminLog(('Auction %s won by %s (char %s): house %s for $%s'):format(aid, name, topChar, houseId, top))
        local wsrc = S.sourceOf(topChar)
        if wsrc then Tip(wsrc, ('You won the auction for %s - the house is yours'):format(title), 10000) end
        S.sendLetter(topChar, 'Auction Won: ' .. title, table.concat({
            ('Congratulations - your bid of $%s won the auction for %s.'):format(U.money(top), title),
            '',
            'The house is now yours. Keep its tax ledger topped up.',
            '',
            '- Housing Team',
        }, '\n'))
        local told = { [topChar] = true }
        for _, b in ipairs(list) do
            local cid = U.int(b.charidentifier)
            if cid and not told[cid] then
                told[cid] = true
                S.sendLetter(cid, 'Auction Ended: ' .. title, table.concat({
                    ('The auction for %s has ended. %s won it with a bid of $%s.'):format(title, name, U.money(top)),
                    '',
                    'Your own bid was deposited back into your bank account when you were outbid.',
                    '',
                    '- Housing Team',
                }, '\n'))
            end
        end
    end)
end

function S.refreshAuctions()
    local stamp = S.auctionStamp
    local ok, rows = pcall(MySQL.query.await, "SELECT id, houseid, endts FROM housing_auctions WHERE status = 'open'")
    if not ok then return end
    local now = Now()
    local set = {}
    for _, r in ipairs(rows or {}) do
        local aid, hid = U.int(r.id), U.int(r.houseid)
        if aid and hid then
            if (tonumber(r.endts) or 0) <= now then resolve(aid) else set[hid] = aid end
        end
    end
    -- an auction was created or cancelled while this ran: the in-memory list is newer than
    -- these rows, so leave it alone this minute (resolutions above already removed theirs)
    if S.auctionStamp ~= stamp then return broadcastAuctioned() end
    local changed = false
    for hid, aid in pairs(set) do if S.auctioned[hid] ~= aid then changed = true end end
    for hid in pairs(S.auctioned) do if not set[hid] then changed = true end end
    S.auctioned = set
    if changed then broadcastAuctioned() end
end

-- the board
local function board(charid)
    local now = Now()
    local okA, active = pcall(MySQL.query.await, "SELECT * FROM housing_auctions WHERE status = 'open' AND endts > ? ORDER BY endts ASC", { now })
    local okF, done = pcall(MySQL.query.await, "SELECT * FROM housing_auctions WHERE status <> 'open' ORDER BY endts DESC LIMIT ?", { Config.Auctions.finishedShown })
    if not okA or not okF then return nil end
    local sealed = Config.Auctions.sealed == true
    local out = { sealed = sealed, active = {}, past = {} }
    for _, r in ipairs(active or {}) do
        local top = math.floor(tonumber(r.topbid) or 0)
        local lead = U.int(r.topcharid) == charid and top > 0
        local e = {
            id = U.int(r.id), title = titleOf(U.int(r.houseid)),
            minimum = math.floor(tonumber(r.minbid) or 0),
            hasBids = top > 0, youLead = lead, yourBid = lead and top or nil,
            timeLeft = endsIn((tonumber(r.endts) or now) - now),
        }
        if not sealed then
            e.top = top
            e.topName = r.topname
        end
        out.active[#out.active + 1] = e
    end
    for _, r in ipairs(done or {}) do
        local top = math.floor(tonumber(r.topbid) or 0)
        local winner
        if r.status == 'cancelled' then winner = 'Cancelled'
        elseif top > 0 and r.topname ~= '' then winner = r.topname
        else winner = 'No bids' end
        out.past[#out.past + 1] = {
            title = titleOf(U.int(r.houseid)), winner = winner,
            amount = (r.status == 'ended' and top > 0) and top or 0,
            when = ago(r.endts),
        }
    end
    return out
end

Rpc('sv_board', 800, function(_, ch)
    return board(ch.charid)
end)

Rpc('sv_banks', 1000, function(_, ch)
    return S.balances(ch.charid)
end)

Net('sv_bid', 1500, function(src, ch, aid, amount, bankName)
    aid, amount = U.int(aid), U.int(amount)
    if not aid or not amount or amount <= 0 or amount > 1000000000 then return end
    if busy[aid] then return Tip(src, 'Another bid is being processed - try again') end
    local bank = S.knownBranch(bankName) or Config.Auctions.refundBank
    withAuction(aid, function()
        local row = auctionRow(aid)
        if not row or row.status ~= 'open' then return Tip(src, 'That auction is no longer open') end
        if (tonumber(row.endts) or 0) <= Now() then return Tip(src, 'That auction has ended') end
        local houseId = U.int(row.houseid)
        local h = S.houses[houseId]
        if not h or h.owned then return Tip(src, 'That house is no longer available') end
        if S.ownedCount(ch.charid) >= Config.MaxHousesPerCharacter then return Tip(src, T('house_cap', Config.MaxHousesPerCharacter)) end
        local top, topChar = math.floor(tonumber(row.topbid) or 0), U.int(row.topcharid)
        if topChar == ch.charid and top > 0 then return Tip(src, 'You already hold the top bid') end
        local minimum = math.floor(tonumber(row.minbid) or 0)
        local need = top > 0 and (top + Config.Auctions.minRaise) or minimum
        if amount < need then
            if Config.Auctions.sealed then
                if amount < minimum then return Tip(src, ('Bids must be at least the reserve of $%s'):format(U.money(minimum))) end
                return Tip(src, 'Your bid was not high enough. Sealed auction - bid what you think it is worth.', 6000)
            end
            return Tip(src, ('Your bid must be at least $%s'):format(U.money(need)))
        end
        local balances = S.balances(ch.charid) or {}
        local have = 0
        for _, b in ipairs(balances) do if b.bank == bank then have = b.balance end end
        if have < amount then return Tip(src, ('Not enough in your %s account - you have $%s'):format(bank, U.money(have))) end
        local took = S.bankTake(ch.charid, bank, amount)
        if not took then return Tip(src, 'Could not take that bid from your bank account - try again') end
        local title = U.title(h)
        Tip(src, ('Bid on %s - $%s held from your %s account'):format(title, U.money(amount), bank), 6000)
        if topChar and top > 0 then
            S.bankRefund(topChar, row.topbank or Config.Auctions.refundBank, top, 'You were outbid on ' .. title)
            local lines = { ('Someone has outbid you on %s.'):format(title), '' }
            if Config.Auctions.sealed then
                lines[#lines + 1] = 'This is a sealed auction, so the standing bid is not disclosed.'
            else
                lines[#lines + 1] = ('The standing bid is now $%s.'):format(U.money(amount))
            end
            lines[#lines + 1] = ('Your bid of $%s has been deposited back into your %s account.'):format(U.money(top), row.topbank or Config.Auctions.refundBank)
            lines[#lines + 1] = ''
            lines[#lines + 1] = '- Housing Team'
            S.sendLetter(topChar, 'Auction: Outbid on ' .. title, table.concat(lines, '\n'))
        end
        MySQL.insert('INSERT INTO housing_auction_bids (auctionid, charidentifier, identifier, name, amount, ts) VALUES (?, ?, ?, ?, ?, ?)',
            { aid, ch.charid, ch.ident, ch.name, amount, Now() })
        pcall(MySQL.update.await, 'UPDATE housing_auctions SET topbid = ?, topcharid = ?, topname = ?, topbank = ? WHERE id = ?',
            { amount, ch.charid, ch.name, bank, aid })
        Activity(houseId, 'AUCTION_BID', ('$%s'):format(amount), S.actor(ch))
        AdminLog(('%s (char %s) bid $%s on auction %s (house %s) from %s'):format(ch.name, ch.charid, amount, aid, houseId, bank))
        Tip(src, ('Bid placed: $%s on %s'):format(U.money(amount), title))
    end)
    TriggerClientEvent('pup_realestate:cl_board', src, board(ch.charid))
end)

CreateThread(function()
    while not S.ready do Wait(1000) end
    while true do
        local ok, err = pcall(S.refreshAuctions)
        if not ok then Warn('auction clock: %s', tostring(err)) end
        Wait(60000)
    end
end)
