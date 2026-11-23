-- pup_staffdesk | bug bounty: staff award points, players spend them on rewards
-- Every change goes through Bounty.change, which also writes the history.
Bounty = {}

local Inv = exports.vorp_inventory

function Bounty.reward(item)
    for _, r in ipairs(Config.Bounty.rewards) do
        if r.item == item and (tonumber(r.cost) or 0) > 0 then return r end
    end
end

function Bounty.balance(charid)
    local row = MySQL.single.await('SELECT points, earned, spent FROM staffdesk_bounty WHERE charid = ?', { charid })
    return row and { points = tonumber(row.points) or 0, earned = tonumber(row.earned) or 0, spent = tonumber(row.spent) or 0 }
        or { points = 0, earned = 0, spent = 0 }
end

function Bounty.history(charid, limit)
    return MySQL.query.await('SELECT delta, reason, by_name, at FROM staffdesk_ledger WHERE charid = ? ORDER BY id DESC LIMIT ' ..
        math.floor(tonumber(limit) or 20), { charid }) or {}
end

-- staff: add (delta > 0) or take back (delta < 0); the balance never goes below 0. Returns new balance or nil, why
function Bounty.change(charid, delta, reason, by)
    charid, delta = tonumber(charid), math.floor(tonumber(delta) or 0)
    if not charid or delta == 0 then return nil, Locale.badAmount end
    local who = MySQL.single.await('SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { charid })
    if not who then return nil, Locale.noSuchChar:format(charid) end

    local before = Bounty.balance(charid).points
    local applied = delta < 0 and -math.min(before, -delta) or delta
    MySQL.update.await([[INSERT INTO staffdesk_bounty (charid, points, earned) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE points = points + ?, earned = earned + ?]],
        { charid, math.max(applied, 0), math.max(applied, 0), applied, math.max(applied, 0) })
    reason = Desk.trim(reason):sub(1, 160)
    MySQL.insert.await('INSERT INTO staffdesk_ledger (charid, delta, reason, by_name, at) VALUES (?, ?, ?, ?, ?)',
        { charid, applied, reason, tostring(by or 'Staff'):sub(1, 100), os.time() })

    local now = before + applied
    local name = Desk.trim((who.firstname or '') .. ' ' .. (who.lastname or ''))
    local s = Desk.sourceOfChar(charid)
    if s then
        Desk.tip(s, (applied >= 0 and Locale.pointsEarned or Locale.pointsLost):format(math.abs(applied), now), 7000)
    end
    Desk.log(Locale.logBounty, ('%s %d points %s %s (charid %d)\nReason: %s\nBalance: %d\nBy %s'):format(
        applied >= 0 and 'Gave' or 'Took', math.abs(applied), applied >= 0 and 'to' or 'from', name, charid,
        reason ~= '' and reason or '-', now, tostring(by)), applied >= 0 and 3066993 or 15105570)
    return now, name
end

-- a player buys a reward. Returns ok, message
function Bounty.redeem(src, item)
    if not Config.Bounty.enabled then return false, Locale.off end
    local r = Bounty.reward(item)
    if not r then return false, Locale.noReward end
    local charid = Desk.charid(src)
    if not charid then return false, Locale.failed end

    -- every check before the points move, so a full satchel never eats a balance
    local held = tonumber(Inv:getItemCount(src, nil, r.item)) or 0
    if r.maxHeld and held >= r.maxHeld then return false, Locale.alreadyHave:format(r.label) end
    if not Inv:canCarryItem(src, r.item, 1) then return false, Locale.noRoom end

    -- the WHERE is the guard: two clicks in flight cannot both spend the same points
    local paid = MySQL.update.await('UPDATE staffdesk_bounty SET points = points - ?, spent = spent + ? WHERE charid = ? AND points >= ?',
        { r.cost, r.cost, charid, r.cost }) or 0
    if paid ~= 1 then return false, Locale.noPoints end
    if not Inv:addItem(src, r.item, 1) then
        MySQL.update.await('UPDATE staffdesk_bounty SET points = points + ?, spent = spent - ? WHERE charid = ?', { r.cost, r.cost, charid })
        return false, Locale.noRoom
    end
    MySQL.insert.await('INSERT INTO staffdesk_ledger (charid, delta, reason, by_name, at) VALUES (?, ?, ?, ?, ?)',
        { charid, -r.cost, Locale.redeemedFor:format(r.label), Desk.who(src), os.time() })
    local left = Bounty.balance(charid).points
    Desk.log(Locale.logBounty, ('%s redeemed **%s** for %d points (%d left)'):format(Desk.whoLog(src), r.label, r.cost, left), 3066993)
    return true, Locale.redeemed:format(r.label, left)
end
