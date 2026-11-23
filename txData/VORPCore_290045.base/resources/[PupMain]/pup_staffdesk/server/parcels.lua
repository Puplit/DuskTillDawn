-- pup_staffdesk | parcels: cash, items and weapons staff (or milestones) leave at the desk
-- Claiming is a compare-and-set on the row before anything is handed over, so a parcel is never collected twice.
Parcels = {}

local Inv = exports.vorp_inventory
local OPEN <const> = 'claimed_at IS NULL AND cancelled_at IS NULL'

local function describe(p)
    if p.kind == 'cash' then return ('$%s'):format(Desk.money(p.amount)) end
    if p.kind == 'weapon' then return p.label ~= '' and p.label or p.name end
    return ('%dx %s'):format(math.floor(tonumber(p.amount) or 0), p.label ~= '' and p.label or p.name)
end
Parcels.describe = describe

-- check and normalise what staff asked to send; returns a row or nil, why
function Parcels.build(kind, name, amount)
    kind = tostring(kind or ''):lower()
    if kind == 'cash' or kind == 'money' then
        local cash = Desk.cents(amount)
        if not cash or cash <= 0 then return nil, Locale.badAmount end
        if cash > Config.Parcels.maxCash then return nil, Locale.tooMuchCash:format(Desk.money(Config.Parcels.maxCash)) end
        return { kind = 'cash', name = '', label = '', amount = cash }
    elseif kind == 'item' then
        local count = math.floor(tonumber(amount) or 1)
        if count < 1 or count > Config.Parcels.maxItems then return nil, Locale.badCount:format(Config.Parcels.maxItems) end
        local label = Desk.itemLabel(name)
        if not label then return nil, Locale.noSuchItem:format(tostring(name)) end
        return { kind = 'item', name = name, label = label, amount = count }
    elseif kind == 'weapon' or kind == 'wep' then
        local hash, label = Desk.weapon(name)
        if not hash then return nil, Locale.noSuchWeapon:format(tostring(name)) end
        return { kind = 'weapon', name = hash, label = label, amount = 1 }
    end
    return nil, Locale.badKind
end

-- who gets it: a charid (number) or a Discord id (15+ digits). Returns charid, discordid or nil, why
function Parcels.recipient(target)
    local s = tostring(target or ''):gsub('^@', ''):gsub('[<>@!]', '')
    if s:match('^%d+$') and #s >= 15 then return nil, s end
    local charid = tonumber(s)
    if not charid then return nil, nil, Locale.badTarget end
    local found = MySQL.scalar.await('SELECT charidentifier FROM characters WHERE charidentifier = ?', { charid })
    if not found then return nil, nil, Locale.noSuchChar:format(charid) end
    return charid, nil
end

-- t = { charid | discordid, kind, name, amount, note, by, origin } -> id or nil, why
function Parcels.send(t)
    if not t.charid and not t.discordid then return nil, Locale.badTarget end
    local row, why = Parcels.build(t.kind, t.name, t.amount)
    if not row then return nil, why end
    local note = Desk.trim(t.note):sub(1, Config.Parcels.noteLength)
    -- one column or the other, never a nil inside the parameter list
    local column, who = 'charid', t.charid
    if not t.charid then column, who = 'discordid', tostring(t.discordid) end
    local id = MySQL.insert.await(([[INSERT INTO staffdesk_parcels
        (%s, kind, name, label, amount, note, sent_by, origin, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]]):format(column),
        { who, row.kind, row.name, row.label, row.amount, note,
          tostring(t.by or 'Staff'):sub(1, 100), tostring(t.origin or 'staff'):sub(1, 16), os.time() })
    if not id or id == 0 then return nil, Locale.failed end
    row.id, row.note = id, note

    -- tell them: a tip if online, a letter either way
    local what = describe(row)
    local chars = {}
    if t.charid then
        chars[1] = t.charid
        local s = Desk.sourceOfChar(t.charid)
        if s then Desk.tip(s, Locale.parcelArrived:format(what), 7000) end
    else
        for _, s in ipairs(Desk.sourcesOfDiscord(t.discordid)) do Desk.tip(s, Locale.parcelArrived:format(what), 7000) end
        for _, r in ipairs(MySQL.query.await('SELECT charidentifier FROM characters WHERE discordid = ? LIMIT 5', { t.discordid }) or {}) do
            chars[#chars + 1] = tonumber(r.charidentifier)
        end
    end
    for _, c in ipairs(chars) do
        Desk.mail(c, Locale.mailSubject, Locale.mailBody:format(what, note ~= '' and note or Locale.noNote))
    end

    local lines = { ('**%s** for %s'):format(what, t.charid and ('charid ' .. t.charid) or ('<@' .. t.discordid .. '>')) }
    if note ~= '' then lines[#lines + 1] = 'Note: ' .. note end
    lines[#lines + 1] = ('Sent by %s - parcel #%d'):format(tostring(t.by or 'Staff'), id)
    Desk.log(Locale.logSent, lines, 3066993)
    return id
end

-- parcels waiting for this player (their character, or their Discord account)
function Parcels.waiting(src)
    local charid = Desk.charid(src)
    if not charid then return {} end
    local discord = Desk.discordOf(src) or '-'
    local rows = MySQL.query.await(('SELECT * FROM staffdesk_parcels WHERE %s AND (charid = ? OR (charid IS NULL AND discordid = ?)) ORDER BY id'):format(OPEN),
        { charid, discord }) or {}
    for _, r in ipairs(rows) do r.amount = tonumber(r.amount) or 0 end
    return rows
end

local function mine(src, id)
    for _, r in ipairs(Parcels.waiting(src)) do
        if tonumber(r.id) == tonumber(id) then return r end
    end
end

-- the largest part of a stack that fits (vorp checks both the item limit and the weight)
local function room(src, item, want)
    if Inv:canCarryItem(src, item, want) then return want end
    local lo, hi = 0, want - 1
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if Inv:canCarryItem(src, item, mid) then lo = mid else hi = mid - 1 end
    end
    return lo
end

local function take(id, charid)
    return (MySQL.update.await(('UPDATE staffdesk_parcels SET claimed_at = ?, claimed_by = ? WHERE id = ? AND %s'):format(OPEN),
        { os.time(), charid, id }) or 0) == 1
end

local function untake(id)
    MySQL.update.await('UPDATE staffdesk_parcels SET claimed_at = NULL, claimed_by = NULL WHERE id = ?', { id })
end

-- hand one parcel over. Returns ok, message
function Parcels.claim(src, id)
    local ch = Desk.char(src)
    if not ch then return false, Locale.failed end
    local charid = tonumber(ch.charIdentifier)
    local p = mine(src, id)
    if not p then return false, Locale.parcelGone end
    local what = describe(p)

    if p.kind == 'cash' then
        if not take(p.id, charid) then return false, Locale.parcelGone end
        ch.addCurrency(0, p.amount)

    elseif p.kind == 'weapon' then
        if not Inv:canCarryWeapons(src, 1, nil, p.name) then return false, Locale.noRoom end
        if not take(p.id, charid) then return false, Locale.parcelGone end
        if Inv:createWeapon(src, p.name, {}, {}) == false then
            untake(p.id)
            return false, Locale.noRoom
        end

    else
        local want = math.floor(p.amount)
        local n = room(src, p.name, want)
        if n < 1 then return false, Locale.noRoom end
        if n == want then
            if not take(p.id, charid) then return false, Locale.parcelGone end
        else
            -- take part: shrink the parcel only if nobody else changed it meanwhile
            local changed = MySQL.update.await(('UPDATE staffdesk_parcels SET amount = amount - ? WHERE id = ? AND amount = ? AND %s'):format(OPEN),
                { n, p.id, want }) or 0
            if changed ~= 1 then return false, Locale.parcelGone end
        end
        if not Inv:addItem(src, p.name, n) then
            if n == want then untake(p.id)
            else MySQL.update.await('UPDATE staffdesk_parcels SET amount = amount + ? WHERE id = ?', { n, p.id }) end
            return false, Locale.noRoom
        end
        if n < want then
            what = ('%dx %s'):format(n, p.label ~= '' and p.label or p.name)
            Desk.log(Locale.logClaimed, ('%s took %s from parcel #%d (%d left)'):format(Desk.whoLog(src), what, p.id, want - n), 3447003)
            return true, Locale.claimedPart:format(what, want - n), true
        end
    end

    Desk.log(Locale.logClaimed, ('%s collected %s (parcel #%d)'):format(Desk.whoLog(src), what, p.id), 3447003)
    return true, Locale.claimed:format(what)
end

-- everything that fits. Returns ok, message
function Parcels.claimAll(src)
    local list = Parcels.waiting(src)
    if #list == 0 then return false, Locale.nothingWaiting end
    local got, left = 0, 0
    for _, p in ipairs(list) do
        local ok, _, partial = Parcels.claim(src, p.id)
        if ok then
            got = got + 1
            if partial then left = left + 1 end
        else
            left = left + 1
        end
    end
    if got == 0 then return false, Locale.noRoom end
    if left > 0 then return true, Locale.claimedSome:format(got, left) end
    return true, Locale.claimedAll:format(got)
end

function Parcels.cancel(id, by)
    local p = MySQL.single.await('SELECT * FROM staffdesk_parcels WHERE id = ?', { tonumber(id) })
    if not p then return false, Locale.parcelGone end
    local done = (MySQL.update.await(('UPDATE staffdesk_parcels SET cancelled_at = ? WHERE id = ? AND %s'):format(OPEN),
        { os.time(), p.id }) or 0) == 1
    if not done then return false, Locale.parcelGone end
    p.amount = tonumber(p.amount) or 0
    Desk.log(Locale.logCancelled, ('%s cancelled parcel #%d (%s)'):format(tostring(by), p.id, describe(p)), 15158332)
    return true, Locale.cancelled:format(p.id)
end

-- staff view: open parcels, newest first. query = charid, discord id or part of a name/label
function Parcels.pending(query, limit)
    query = Desk.trim(query)
    limit = math.min(tonumber(limit) or 100, 200)
    local rows
    if query == '' then
        rows = MySQL.query.await(('SELECT * FROM staffdesk_parcels WHERE %s ORDER BY id DESC LIMIT %d'):format(OPEN, limit))
    elseif query:match('^%d+$') then
        rows = MySQL.query.await(('SELECT * FROM staffdesk_parcels WHERE %s AND (charid = ? OR discordid = ?) ORDER BY id DESC LIMIT %d'):format(OPEN, limit),
            { tonumber(query), query })
    else
        local like = '%' .. query .. '%'
        rows = MySQL.query.await(('SELECT * FROM staffdesk_parcels WHERE %s AND (label LIKE ? OR name LIKE ? OR note LIKE ? OR sent_by LIKE ?) ORDER BY id DESC LIMIT %d'):format(OPEN, limit),
            { like, like, like, like })
    end
    rows = rows or {}
    for _, r in ipairs(rows) do r.amount = tonumber(r.amount) or 0 end
    return rows
end
