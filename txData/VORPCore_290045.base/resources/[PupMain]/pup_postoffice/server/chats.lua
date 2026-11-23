-- pup_postoffice | chats: direct, group and business conversations between PO boxes
-- Every conversation lives in the group tables. kind: 'group' (owner tools), 'direct' (two boxes),
-- 'business' (one customer box and a business; ref = the job). Players only ever see box numbers:
-- the page puts the viewer's own saved contact names on them.

local C = Config.Chat
local MSG_BYTES = C.maxMessage or 500
local PAGE = C.pageSize or 30
local MAX_MEMBERS = C.maxGroupMembers or 20
local MAX_OWNED = C.maxOwnedGroups or 5
local POST_GAP = C.cooldownMs or 800
local LIST_LIMIT = C.listLimit or 150
local TITLE_BYTES = 40
local TYPING_GAP = 2500
local MAX_BLOCKS = 200

local function push(src, payload)
    TriggerClientEvent('pup_postoffice:chat', src, payload)
end

local function int(v) return PO.toInt(v) end

--------------------------------------------------------------------------------
-- who is asking: their own box, or (view 'b') the business they may write for

local function sideOf(src, view)
    local box = PO.getBox(src)
    if not box then return nil end
    if view == 'b' then
        local info = PO.getBusiness(src)
        if not info or not info.canSend or not PO.handles[info.job] then return nil end
        return { box = box, job = info.job, biz = true, view = 'b' }
    end
    return { box = box, view = 'p' }
end

local function convRow(id)
    local g = PO.single('SELECT id, kind, title, owner, ref, handled, bizRead FROM mail_groups WHERE id = ? LIMIT 1', { id })
    if g then g.kind = g.kind or 'group' end
    return g
end

local function memberRow(id, box)
    return PO.single('SELECT id, notify, lastRead, pinned FROM mail_group_members WHERE groupId = ? AND address = ? LIMIT 1', { id, box })
end

--- The conversation if this side may use it, plus the member row (nil for business staff).
local function access(s, id)
    id = int(id)
    if not id then return nil end
    local g = convRow(id)
    if not g then return nil end
    if s.biz then
        if g.kind ~= 'business' or g.ref ~= s.job then return nil end
        -- a chat with a customer the business blocked is closed to staff until they unblock
        if PO.bizBlocksReady and PO.scalar([[SELECT bb.id FROM mail_business_blocks bb
            JOIN mail_group_members bm ON bm.groupId = ? AND bm.address = bb.address WHERE bb.job = ? LIMIT 1]], { g.id, s.job }) then
            return nil
        end
        return g, nil
    end
    local me = memberRow(id, s.box)
    if not me then return nil end
    return g, me
end

local function memberList(id)
    local out = {}
    for _, r in ipairs(PO.query('SELECT address, lastRead FROM mail_group_members WHERE groupId = ? ORDER BY id ASC', { id }) or {}) do
        out[#out + 1] = { box = int(r.address), lastRead = int(r.lastRead) or 0 }
    end
    return out
end

local function memberBoxes(id)
    local out = {}
    for _, m in ipairs(memberList(id)) do out[#out + 1] = m.box end
    return out
end

--------------------------------------------------------------------------------
-- blocks: a viewer never sees messages written by a box they blocked

local function blocksOf(box)
    local out = {}
    for _, r in ipairs(PO.query('SELECT blocked FROM mail_blocks WHERE address = ? ORDER BY id ASC', { box }) or {}) do
        out[#out + 1] = int(r.blocked)
    end
    return out
end

local function blockSet(box)
    local set = {}
    for _, b in ipairs(blocksOf(box)) do set[b] = true end
    return set
end

--------------------------------------------------------------------------------
-- business blocks: a box a business blocked cannot write to that business's chat

local MAX_BIZ_BLOCKS = 500

local function bizBlocked(job, box)
    if not PO.bizBlocksReady or not job or not box then return false end
    return PO.scalar('SELECT id FROM mail_business_blocks WHERE job = ? AND address = ? LIMIT 1', { job, box }) ~= nil
end

--- SQL that leaves out business chats whose customer the business blocked (g = mail_groups).
local function notBizBlockedSql()
    if not PO.bizBlocksReady then return '' end
    return [[ AND NOT EXISTS (SELECT 1 FROM mail_business_blocks bb JOIN mail_group_members bm ON bm.groupId = g.id AND bm.address = bb.address WHERE bb.job = g.ref)]]
end

--------------------------------------------------------------------------------
-- who is online for a conversation

--- { src, view, box } for every online member, and (business chats) every online employee who may write for it.
local function audience(g, boxes)
    local out = {}
    for _, b in ipairs(boxes or memberBoxes(g.id)) do
        local s = PO.srcForBox(b)
        if s then out[#out + 1] = { src = s, view = 'p', box = b } end
    end
    if g.kind == 'business' and g.ref then
        for _, s in ipairs(PO.employees(g.ref)) do
            local info = PO.getBusiness(s)
            if info and info.canSend then out[#out + 1] = { src = s, view = 'b' } end
        end
    end
    return out
end

--- A message row as one viewer may see it. Customers never learn which employee wrote for a business.
local function msgOut(r, forStaff)
    local asJob = (r.asJob ~= nil and r.asJob ~= '') and tostring(r.asJob) or nil
    local box = int(r.address)
    if asJob and not forStaff then box = nil end
    return { id = int(r.id), box = box, asJob = asJob, text = r.body or '', date = r.date or '', parentId = int(r.parentId) }
end

--- The message columns to select (parentId only once the thread upgrade has run).
local function msgCols(prefix)
    local p = prefix or ''
    local cols = ('%sid, %saddress, %sasJob, %sbody, %s`date`'):format(p, p, p, p, p)
    if PO.threadsReady then cols = cols .. (', %sparentId'):format(p) end
    return cols
end

--------------------------------------------------------------------------------
-- reactions

local REACTIONS = {}
for i, e in ipairs(C.reactions or {}) do
    if i > 12 then break end
    if type(e) == 'string' and e ~= '' and #e <= 32 then REACTIONS[e] = true end
end
local REACT_GAP = 250

local function whoOf(s)
    return s.biz and ('b:' .. s.job) or ('p%d'):format(s.box)
end

local function reactionRows(ids)
    if not PO.threadsReady or #ids == 0 then return {} end
    return PO.query(('SELECT messageId, who, address, emoji FROM mail_group_reactions WHERE messageId IN (%s) ORDER BY id ASC'):format(PO.placeholders(#ids)), ids) or {}
end

--- messageId -> { { e, n, mine, by = { boxes }, biz } } as one viewer may see it.
--- Customers see a business reaction as the business, never as the employee who made it.
local function reactionsFor(rows, me, blocked)
    local out, slots = {}, {}
    for _, r in ipairs(rows) do
        local who = tostring(r.who or '')
        local isBiz = who:sub(1, 2) == 'b:'
        local box = (not isBiz) and int(who:sub(2)) or nil
        if isBiz or not (box and blocked[box]) then
            local mid = int(r.messageId)
            local key = mid .. '|' .. r.emoji
            local slot = slots[key]
            if not slot then
                slot = { e = r.emoji, n = 0, mine = false, by = {} }
                slots[key] = slot
                out[mid] = out[mid] or {}
                table.insert(out[mid], slot)
            end
            slot.n = slot.n + 1
            if who == me then slot.mine = true end
            if isBiz then slot.biz = true elseif box then slot.by[#slot.by + 1] = box end
        end
    end
    return out
end

--- Adds reply counts and reactions to a page of messages for one viewer.
local function decorate(messages, s, blocked, withReplies)
    if not PO.threadsReady or #messages == 0 then return end
    local ids, byId = {}, {}
    for _, m in ipairs(messages) do ids[#ids + 1] = m.id; byId[m.id] = m end
    if withReplies then
        local rows = PO.query(('SELECT parentId, address, asJob, COUNT(*) AS n, MAX(id) AS lastId, MAX(`date`) AS lastDate FROM mail_group_messages WHERE parentId IN (%s) GROUP BY parentId, address, asJob'):format(PO.placeholders(#ids)), ids) or {}
        for _, r in ipairs(rows) do
            local isBiz = r.asJob ~= nil and r.asJob ~= ''
            local m = byId[int(r.parentId)]
            if m and (isBiz or not blocked[int(r.address)]) then
                m.replies = (m.replies or 0) + (int(r.n) or 0)
                local li = int(r.lastId) or 0
                if li > (m.lastReply or 0) then m.lastReply = li; m.lastReplyDate = r.lastDate end
            end
        end
    end
    local reacts = reactionsFor(reactionRows(ids), whoOf(s), blocked)
    for id, list in pairs(reacts) do byId[id].reactions = list end
end

--- Deletes the reactions on every message of a chat (before the messages themselves go).
local function dropReactions(groupId)
    if not PO.threadsReady then return end
    PO.update('DELETE r FROM mail_group_reactions r JOIN mail_group_messages m ON m.id = r.messageId WHERE m.groupId = ?', { groupId })
end

local function info(g, s, me, members)
    local out = {
        id = int(g.id), kind = g.kind, title = g.title or '', owner = int(g.owner),
        handled = PO.truthy(g.handled), bizRead = int(g.bizRead) or 0,
        muted = me and not PO.truthy(me.notify) or false,
        pinned = me and PO.truthy(me.pinned) or false,
    }
    if g.kind == 'business' then
        out.job = g.ref
        out.handle = PO.handles[g.ref]
        out.name = PO.businessName(g.ref)
    end
    -- the page labels boxes itself; customers of a business only ever see their own box
    out.members = {}
    for _, m in ipairs(members or memberList(g.id)) do
        out.members[#out.members + 1] = { box = m.box, lastRead = m.lastRead }
    end
    return out
end

--------------------------------------------------------------------------------
-- the chat list

local function lastMessages(ids)
    local out = {}
    if #ids == 0 then return out end
    local rows = PO.query(('SELECT %s, groupId FROM mail_group_messages WHERE id IN (%s)'):format(msgCols(), PO.placeholders(#ids)), ids) or {}
    for _, r in ipairs(rows) do out[int(r.groupId)] = r end
    return out
end

local function membersByConv(ids)
    local out = {}
    if #ids == 0 then return out end
    local rows = PO.query(('SELECT groupId, address, lastRead FROM mail_group_members WHERE groupId IN (%s) ORDER BY id ASC'):format(PO.placeholders(#ids)), ids) or {}
    for _, r in ipairs(rows) do
        local gid = int(r.groupId)
        out[gid] = out[gid] or {}
        table.insert(out[gid], { box = int(r.address), lastRead = int(r.lastRead) or 0 })
    end
    return out
end

local function buildList(s)
    local rows, unreadRows
    if s.biz then
        rows = PO.query([[
            SELECT t.* FROM (
                SELECT g.id, g.kind, g.title, g.owner, g.ref, g.handled, g.bizRead,
                    (SELECT MAX(z.id) FROM mail_group_messages z WHERE z.groupId = g.id) AS lastId
                FROM mail_groups g
                WHERE g.kind = 'business' AND g.ref = ?]] .. notBizBlockedSql() .. [[
            ) t
            WHERE t.lastId IS NOT NULL
            ORDER BY t.lastId DESC
            LIMIT ?]], { s.job, LIST_LIMIT }) or {}
        unreadRows = PO.query([[
            SELECT x.groupId, COUNT(*) AS n
            FROM mail_group_messages x JOIN mail_groups g ON g.id = x.groupId
            WHERE g.kind = 'business' AND g.ref = ? AND x.id > g.bizRead AND x.asJob IS NULL]] .. notBizBlockedSql() .. [[
            GROUP BY x.groupId]], { s.job }) or {}
    else
        rows = PO.query([[
            SELECT t.* FROM (
                SELECT g.id, g.kind, g.title, g.owner, g.ref, g.handled, g.bizRead, m.notify, m.pinned, m.lastRead,
                    (SELECT MAX(z.id) FROM mail_group_messages z WHERE z.groupId = g.id) AS lastId
                FROM mail_group_members m JOIN mail_groups g ON g.id = m.groupId
                WHERE m.address = ?
            ) t
            ORDER BY (t.lastId IS NULL) ASC, t.lastId DESC, t.id DESC
            LIMIT ?]], { s.box, LIST_LIMIT }) or {}
        unreadRows = PO.query([[
            SELECT x.groupId, x.address, x.asJob, COUNT(*) AS n
            FROM mail_group_messages x JOIN mail_group_members m ON m.groupId = x.groupId AND m.address = ?
            WHERE x.id > m.lastRead AND NOT (x.address = ? AND x.asJob IS NULL)
            GROUP BY x.groupId, x.address, x.asJob]], { s.box, s.box }) or {}
    end

    local blocked = s.biz and {} or blockSet(s.box)
    local unread = {}
    for _, r in ipairs(unreadRows) do
        local gid = int(r.groupId)
        local hidden = (r.asJob == nil or r.asJob == '') and r.address and blocked[int(r.address)]
        if not hidden then unread[gid] = (unread[gid] or 0) + (int(r.n) or 0) end
    end

    local ids, lastIds = {}, {}
    for _, r in ipairs(rows) do
        ids[#ids + 1] = int(r.id)
        if r.lastId then lastIds[#lastIds + 1] = int(r.lastId) end
    end
    local lasts = lastMessages(lastIds)
    local members = membersByConv(ids)

    local list, badge = {}, 0
    for _, r in ipairs(rows) do
        local gid = int(r.id)
        local kind = r.kind or 'group'
        -- a direct or business chat with nothing in it yet only shows to the one who opened it
        if r.lastId or kind == 'group' or int(r.owner) == s.box then
            local me = (not s.biz) and { notify = r.notify, pinned = r.pinned } or nil
            local item = info({ id = gid, kind = kind, title = r.title, owner = r.owner, ref = r.ref, handled = r.handled, bizRead = r.bizRead }, s, me, members[gid] or {})
            item.unread = unread[gid] or 0
            item.lastRead = int(r.lastRead) or 0
            local lm = lasts[gid]
            if lm then
                local out = msgOut(lm, s.biz)
                if not out.asJob and out.box and blocked[out.box] then out.text = ''; out.hidden = true end
                item.last = out
            end
            if not item.muted then badge = badge + item.unread end
            list[#list + 1] = item
        end
    end
    return list, badge
end

local function sendList(src, s)
    local list, badge = buildList(s)
    push(src, { type = 'list', view = s.view, list = list, badge = badge, blocks = (not s.biz) and blocksOf(s.box) or nil })
end

local function changed(g, boxes, except)
    for _, a in ipairs(audience(g, boxes)) do
        if a.src ~= except then push(a.src, { type = 'changed', id = int(g.id), view = a.view }) end
    end
end

--------------------------------------------------------------------------------
-- reading

local function markRead(s, g, upTo)
    upTo = int(upTo)
    if not upTo or upTo <= 0 then return end
    local newest = int(PO.scalar('SELECT MAX(id) FROM mail_group_messages WHERE groupId = ?', { g.id })) or 0
    if upTo > newest then upTo = newest end
    if upTo <= 0 then return end
    local n
    if s.biz then
        n = PO.update('UPDATE mail_groups SET bizRead = ? WHERE id = ? AND bizRead < ?', { upTo, g.id, upTo })
    else
        n = PO.update('UPDATE mail_group_members SET lastRead = ? WHERE groupId = ? AND address = ? AND lastRead < ?', { upTo, g.id, s.box, upTo })
    end
    if not n or n < 1 then return end
    -- the others see their messages turn to "opened"; customers never learn which employee read it
    for _, a in ipairs(audience(g)) do
        if not (a.view == s.view and (s.biz or a.box == s.box)) then
            push(a.src, { type = 'read', id = int(g.id), view = a.view, box = (not s.biz) and s.box or nil, biz = s.biz or nil, upTo = upTo })
        end
    end
end

local ops = {}

function ops.list(src, s)
    sendList(src, s)
end

function ops.open(src, s, d)
    local g, me = access(s, d.id)
    if not g then return push(src, { type = 'gone', id = int(d.id), view = s.view }) end
    local before = int(d.before)
    -- the main chat holds top-level messages only; replies load with their thread
    local top = PO.threadsReady and ' AND parentId IS NULL' or ''
    local rows
    if before and before > 0 then
        rows = PO.query(('SELECT %s FROM mail_group_messages WHERE groupId = ?%s AND id < ? ORDER BY id DESC LIMIT ?'):format(msgCols(), top), { g.id, before, PAGE + 1 }) or {}
    else
        rows = PO.query(('SELECT %s FROM mail_group_messages WHERE groupId = ?%s ORDER BY id DESC LIMIT ?'):format(msgCols(), top), { g.id, PAGE + 1 }) or {}
    end
    local hasMore = #rows > PAGE
    if hasMore then rows[#rows] = nil end
    local blocked = s.biz and {} or blockSet(s.box)
    local messages = {}
    for i = #rows, 1, -1 do
        local m = msgOut(rows[i], s.biz)
        if not (not m.asJob and m.box and blocked[m.box]) then messages[#messages + 1] = m end
    end
    decorate(messages, s, blocked, true)
    local members = memberList(g.id)
    -- what this side had read before opening: the page marks threads with newer replies
    local seen = s.biz and (int(g.bizRead) or 0) or (me and int(me.lastRead) or 0)
    push(src, {
        type = 'thread', view = s.view, info = info(g, s, me, members),
        messages = messages, hasMore = hasMore, older = (before and before > 0) or false,
        threads = PO.threadsReady or nil, seen = seen,
    })
    -- opening a chat reads everything in it, thread replies too
    if not before and d.markRead ~= false then markRead(s, g, 2147483647) end
end

--- One reply thread: the message it hangs under, then its replies (oldest first, paged like the main chat).
function ops.replies(src, s, d)
    if not PO.threadsReady then return end
    local g = access(s, d.id)
    if not g then return push(src, { type = 'gone', id = int(d.id), view = s.view }) end
    local pid = int(d.parent)
    if not pid then return end
    local parentRow = PO.single(('SELECT %s FROM mail_group_messages WHERE id = ? AND groupId = ? AND parentId IS NULL LIMIT 1'):format(msgCols()), { pid, g.id })
    if not parentRow then return push(src, { type = 'replies', view = s.view, id = int(g.id), parent = pid, missing = true }) end
    local before = int(d.before)
    local rows
    if before and before > 0 then
        rows = PO.query(('SELECT %s FROM mail_group_messages WHERE groupId = ? AND parentId = ? AND id < ? ORDER BY id DESC LIMIT ?'):format(msgCols()), { g.id, pid, before, PAGE + 1 }) or {}
    else
        rows = PO.query(('SELECT %s FROM mail_group_messages WHERE groupId = ? AND parentId = ? ORDER BY id DESC LIMIT ?'):format(msgCols()), { g.id, pid, PAGE + 1 }) or {}
    end
    local hasMore = #rows > PAGE
    if hasMore then rows[#rows] = nil end
    local blocked = s.biz and {} or blockSet(s.box)
    local replies = {}
    for i = #rows, 1, -1 do
        local m = msgOut(rows[i], s.biz)
        if not (not m.asJob and m.box and blocked[m.box]) then replies[#replies + 1] = m end
    end
    local parent = msgOut(parentRow, s.biz)
    local hiddenParent = not parent.asJob and parent.box and blocked[parent.box]
    if hiddenParent then parent.text = ''; parent.hidden = true end
    decorate({ parent }, s, blocked, true)
    decorate(replies, s, blocked, false)
    push(src, {
        type = 'replies', view = s.view, id = int(g.id), parent = pid, message = parent,
        replies = replies, hasMore = hasMore, older = (before and before > 0) or false,
    })
    if not before and rows[1] then markRead(s, g, rows[1].id) end
end

function ops.read(src, s, d)
    local g = access(s, d.id)
    if g then markRead(s, g, d.upTo) end
end

--- Anti-spam: nil when the message may go, or the tip to show.
local function spamCheck(p, text, now)
    if p.chatMutedUntil and now < p.chatMutedUntil then
        return L.chatSlowDown:format(math.ceil((p.chatMutedUntil - now) / 1000))
    end
    if p.lastChat and now - p.lastChat < POST_GAP then return '' end
    local chars = utf8.len(text) or #text
    if chars < (C.minLength or 2) then return L.chatTooShort end
    if p.lastChatText == text and p.lastChat and now - p.lastChat < (C.repeatSeconds or 30) * 1000 then return L.chatRepeat end
    -- burst: more than burstCount messages inside burstSeconds earns a short mute
    local window = (C.burstSeconds or 15) * 1000
    local times = p.chatTimes or {}
    local kept = {}
    for _, t in ipairs(times) do if now - t < window then kept[#kept + 1] = t end end
    p.chatTimes = kept
    if #kept >= (C.burstCount or 6) then
        p.chatMutedUntil = now + (C.muteSeconds or 20) * 1000
        p.chatTimes = {}
        return L.chatSlowDown:format(C.muteSeconds or 20)
    end
    return nil
end

function ops.post(src, s, d)
    local p = PO.player(src)
    local now = GetGameTimer()
    local text = PO.cutBytes(PO.trim(d.text), MSG_BYTES)
    local refused = { type = 'posted', ref = d.ref, ok = false, id = int(d.id), view = s.view }
    if text == '' then return push(src, refused) end
    local why = spamCheck(p, text, now)
    if why then
        if why ~= '' then PO.tip(src, why); refused.reason = why end
        return push(src, refused)
    end
    local g = access(s, d.id)
    if not g then return push(src, refused) end
    if g.kind == 'business' and not s.biz and bizBlocked(g.ref, s.box) then
        refused.reason = L.bizBlockedYou
        PO.tip(src, L.bizBlockedYou)
        return push(src, refused)
    end
    -- a thread reply: the parent must be a top-level message of this chat (no replies to replies)
    local parentId = nil
    if d.parent ~= nil then
        parentId = int(d.parent)
        if not PO.threadsReady or not parentId then return push(src, refused) end
        if not PO.scalar('SELECT id FROM mail_group_messages WHERE id = ? AND groupId = ? AND parentId IS NULL LIMIT 1', { parentId, g.id }) then
            refused.reason = L.chatNoThread
            PO.tip(src, L.chatNoThread)
            return push(src, refused)
        end
    end
    p.lastChat = now
    p.lastChatText = text
    p.chatTimes[#p.chatTimes + 1] = now
    local date = PO.isoNow()
    local cols = {
        { 'groupId', g.id }, { 'address', s.box }, { 'body', text }, { 'date', date }, { 'asJob', s.biz and s.job or nil },
    }
    if parentId then cols[#cols + 1] = { 'parentId', parentId } end
    local msgId = int(PO.insertRow('mail_group_messages', cols))
    if not msgId then return push(src, { type = 'posted', ref = d.ref, ok = false, id = int(g.id), view = s.view }) end

    if s.biz then
        PO.update('UPDATE mail_groups SET bizRead = GREATEST(bizRead, ?) WHERE id = ?', { msgId, g.id })
    else
        PO.update('UPDATE mail_group_members SET lastRead = GREATEST(lastRead, ?) WHERE groupId = ? AND address = ?', { msgId, g.id, s.box })
        -- a new word from the customer reopens a business chat
        if g.kind == 'business' then PO.update('UPDATE mail_groups SET handled = 0 WHERE id = ?', { g.id }) end
    end

    local row = { id = msgId, address = s.box, asJob = s.biz and s.job or nil, body = text, date = date, parentId = parentId }
    push(src, { type = 'posted', ref = d.ref, ok = true, id = int(g.id), view = s.view, message = msgOut(row, s.biz) })

    local boxes = memberBoxes(g.id)
    for _, a in ipairs(audience(g, boxes)) do
        if a.src ~= src then
            push(a.src, { type = 'msg', id = int(g.id), view = a.view, message = msgOut(row, a.view == 'b'), kind = g.kind })
        end
    end
end

function ops.typing(src, s, d)
    local p = PO.player(src)
    local now = GetGameTimer()
    if p.lastTyping and now - p.lastTyping < TYPING_GAP then return end
    p.lastTyping = now
    local g = access(s, d.id)
    if not g then return end
    if g.kind == 'business' and not s.biz and bizBlocked(g.ref, s.box) then return end
    for _, a in ipairs(audience(g)) do
        if a.src ~= src then
            push(a.src, { type = 'typing', id = int(g.id), view = a.view, box = (not s.biz) and s.box or nil, biz = s.biz or nil })
        end
    end
end

--- Put a reaction on a message, or take it off. Everyone in the chat sees the new counts.
function ops.react(src, s, d)
    if not PO.threadsReady then return end
    local emoji = type(d.emoji) == 'string' and d.emoji or ''
    if not REACTIONS[emoji] then return end
    local p = PO.player(src)
    local now = GetGameTimer()
    if p.lastReact and now - p.lastReact < REACT_GAP then return end
    p.lastReact = now
    local g = access(s, d.id)
    if not g then return end
    local mid = int(d.msg)
    if not mid then return end
    local msg = PO.single('SELECT id, address, asJob FROM mail_group_messages WHERE id = ? AND groupId = ? LIMIT 1', { mid, g.id })
    if not msg then return end
    if g.kind == 'business' and not s.biz and bizBlocked(g.ref, s.box) then return end
    -- no reacting to a message you cannot see
    if not s.biz and (msg.asJob == nil or msg.asJob == '') and blockSet(s.box)[int(msg.address)] then return end
    local who = whoOf(s)
    if d.on == true then
        PO.insert('INSERT IGNORE INTO mail_group_reactions (messageId, who, address, emoji) VALUES (?, ?, ?, ?)', { mid, who, s.box, emoji })
    else
        PO.update('DELETE FROM mail_group_reactions WHERE messageId = ? AND who = ? AND emoji = ?', { mid, who, emoji })
    end
    local rows = reactionRows({ mid })
    local blockCache = {}
    for _, a in ipairs(audience(g)) do
        local blocked, me
        if a.view == 'b' then
            blocked, me = {}, 'b:' .. tostring(g.ref)
        else
            blockCache[a.box] = blockCache[a.box] or blockSet(a.box)
            blocked, me = blockCache[a.box], ('p%d'):format(a.box)
        end
        local list = reactionsFor(rows, me, blocked)[mid] or {}
        push(a.src, { type = 'react', id = int(g.id), view = a.view, msg = mid, reactions = list })
    end
end

function ops.mute(src, s, d)
    if s.biz then return end
    local g = access(s, d.id)
    if not g then return end
    PO.update('UPDATE mail_group_members SET notify = ? WHERE groupId = ? AND address = ?', { d.on == true and 0 or 1, g.id, s.box })
    sendList(src, s)
end

function ops.pin(src, s, d)
    if s.biz then return end
    local g = access(s, d.id)
    if not g then return end
    PO.update('UPDATE mail_group_members SET pinned = ? WHERE groupId = ? AND address = ?', { d.on == true and 1 or 0, g.id, s.box })
    sendList(src, s)
end

function ops.handled(src, s, d)
    if not s.biz then return end
    local g = access(s, d.id)
    if not g then return end
    PO.update('UPDATE mail_groups SET handled = ? WHERE id = ?', { d.on == true and 1 or 0, g.id })
    for _, a in ipairs(audience(g, {})) do
        local as = sideOf(a.src, 'b')
        if as then sendList(a.src, as) end
    end
end

--------------------------------------------------------------------------------
-- starting a chat with a box or a business

local starting = {}

local function findDirect(a, b)
    return int(PO.scalar([[
        SELECT g.id FROM mail_groups g
        JOIN mail_group_members x ON x.groupId = g.id AND x.address = ?
        JOIN mail_group_members y ON y.groupId = g.id AND y.address = ?
        WHERE g.kind = 'direct' ORDER BY g.id ASC LIMIT 1]], { a, b }))
end

function ops.start(src, s, d)
    if s.biz then return end
    local raw = PO.trim(type(d.target) == 'number' and tostring(d.target) or d.target)
    local ref = PO.cutBytes(tostring(d.ref or ''), 40)
    local function done(id) push(src, { type = 'started', ref = ref, id = id or false }) end
    if raw == '' then return done(nil) end

    if raw:match('^%d+$') then
        local target = int(raw)
        if not target or target <= 0 or target > 2147483647 then PO.tip(src, L.grpNotNumber); return done(nil) end
        if target == s.box then PO.tip(src, L.chatSelf); return done(nil) end
        if blockSet(s.box)[target] then PO.tip(src, L.chatBlocked:format(target)); return done(nil) end
        if not PO.scalar('SELECT address FROM mail WHERE address = ? LIMIT 1', { target }) then
            PO.tip(src, L.grpNoSuchBox:format(target)); return done(nil)
        end
        local key = ('d:%d:%d'):format(math.min(s.box, target), math.max(s.box, target))
        while starting[key] do Wait(50) end
        starting[key] = true
        local ok, id = pcall(function()
            local found = findDirect(s.box, target)
            if found then return found end
            local newId = int(PO.insertRow('mail_groups', { { 'title', '' }, { 'owner', s.box }, { 'kind', 'direct' } }))
            if not newId then return nil end
            PO.insert('INSERT IGNORE INTO mail_group_members (groupId, address, notify, lastRead) VALUES (?, ?, 1, 0)', { newId, s.box })
            PO.insert('INSERT IGNORE INTO mail_group_members (groupId, address, notify, lastRead) VALUES (?, ?, 1, 0)', { newId, target })
            return newId
        end)
        starting[key] = nil
        if not ok then print(('[pup_postoffice] chat start error: %s'):format(tostring(id))) end
        sendList(src, s)
        return done(ok and id or nil)
    end

    -- a business address such as val556
    PO.ensureDirectory()
    local handle = raw:lower()
    local job = PO.handleJobs[handle]
    if not job then PO.tip(src, L.chatNoSuchBiz:format(PO.cutBytes(raw, 24))); return done(nil) end
    local mine = PO.getBusiness(src)
    if mine and mine.job == job then PO.tip(src, L.chatOwnBiz); return done(nil) end
    if bizBlocked(job, s.box) then PO.tip(src, L.bizBlockedYou); return done(nil) end
    local key = ('b:%s:%d'):format(job, s.box)
    while starting[key] do Wait(50) end
    starting[key] = true
    local ok, id = pcall(function()
        local found = int(PO.scalar([[
            SELECT g.id FROM mail_groups g JOIN mail_group_members x ON x.groupId = g.id AND x.address = ?
            WHERE g.kind = 'business' AND g.ref = ? ORDER BY g.id ASC LIMIT 1]], { s.box, job }))
        if found then return found end
        local newId = int(PO.insertRow('mail_groups', { { 'title', '' }, { 'owner', s.box }, { 'kind', 'business' }, { 'ref', job } }))
        if not newId then return nil end
        PO.insert('INSERT IGNORE INTO mail_group_members (groupId, address, notify, lastRead) VALUES (?, ?, 1, 0)', { newId, s.box })
        return newId
    end)
    starting[key] = nil
    if not ok then print(('[pup_postoffice] chat start error: %s'):format(tostring(id))) end
    sendList(src, s)
    done(ok and id or nil)
end

--------------------------------------------------------------------------------
-- groups (owner tools)

local function groupFor(src, s, id, ownerMsg)
    local g = access(s, id)
    if not g or g.kind ~= 'group' then return nil end
    if ownerMsg and int(g.owner) ~= s.box then
        PO.tip(src, ownerMsg)
        return nil
    end
    return g
end

local function addMember(src, s, g, raw)
    raw = PO.trim(type(raw) == 'number' and tostring(raw) or raw)
    local target = raw:match('^%d+$') and int(raw) or nil
    if not target then PO.tip(src, L.grpNotNumber); return false end
    if target == s.box then return false end
    if not PO.scalar('SELECT address FROM mail WHERE address = ? LIMIT 1', { target }) then
        PO.tip(src, L.grpNoSuchBox:format(target)); return false
    end
    local boxes = memberBoxes(g.id)
    if #boxes >= MAX_MEMBERS then PO.tip(src, L.grpFull); return false end
    for _, b in ipairs(boxes) do
        if b == target then PO.tip(src, L.grpAlready); return false end
    end
    local newest = int(PO.scalar('SELECT MAX(id) FROM mail_group_messages WHERE groupId = ?', { g.id })) or 0
    PO.insert('INSERT IGNORE INTO mail_group_members (groupId, address, notify, lastRead) VALUES (?, ?, 1, ?)', { g.id, target, newest })
    local ts = PO.srcForBox(target)
    if ts then
        PO.tip(ts, L.grpAdded:format(g.title or ''))
        local ss = sideOf(ts, 'p')
        if ss then sendList(ts, ss) end
    end
    return true, boxes
end

function ops.create(src, s, d)
    if s.biz then return end
    local ref = PO.cutBytes(tostring(d.ref or ''), 40)
    local title = PO.cutBytes(PO.trim(d.title), TITLE_BYTES)
    if title == '' then PO.tip(src, L.grpNoTitle); return push(src, { type = 'started', ref = ref, id = false }) end
    local owned = int(PO.scalar("SELECT COUNT(*) FROM mail_groups WHERE owner = ? AND kind = 'group'", { s.box })) or 0
    if owned >= MAX_OWNED then PO.tip(src, L.grpTooMany:format(MAX_OWNED)); return push(src, { type = 'started', ref = ref, id = false }) end
    local id = int(PO.insertRow('mail_groups', { { 'title', title }, { 'owner', s.box }, { 'kind', 'group' } }))
    if not id then return push(src, { type = 'started', ref = ref, id = false }) end
    PO.insert('INSERT INTO mail_group_members (groupId, address, notify, lastRead) VALUES (?, ?, 1, 0)', { id, s.box })
    local first = PO.trim(type(d.target) == 'number' and tostring(d.target) or d.target)
    if first ~= '' then addMember(src, s, { id = id, title = title }, first) end
    sendList(src, s)
    push(src, { type = 'started', ref = ref, id = id })
end

function ops.rename(src, s, d)
    local g = groupFor(src, s, d.id, L.grpOwnerRename)
    if not g then return end
    local title = PO.cutBytes(PO.trim(d.title), TITLE_BYTES)
    if title == '' then return PO.tip(src, L.grpNoTitle) end
    PO.update('UPDATE mail_groups SET title = ? WHERE id = ?', { title, g.id })
    sendList(src, s)
    push(src, { type = 'changed', id = int(g.id), view = 'p' })
    changed(g, nil, src)
end

function ops.add(src, s, d)
    local g = groupFor(src, s, d.id, L.grpOwnerAdd)
    if not g then return end
    local ok, before = addMember(src, s, g, d.target)
    if not ok then return end
    sendList(src, s)
    push(src, { type = 'changed', id = int(g.id), view = 'p' })
    changed(g, before, src)
end

function ops.remove(src, s, d)
    local g = groupFor(src, s, d.id, L.grpOwnerRemove)
    local target = int(d.target)
    if not g or not target or target == s.box then return end
    local removed = PO.update('DELETE FROM mail_group_members WHERE groupId = ? AND address = ?', { g.id, target })
    if not removed or removed < 1 then return end
    local ts = PO.srcForBox(target)
    if ts then
        push(ts, { type = 'gone', id = int(g.id), view = 'p' })
        local ss = sideOf(ts, 'p')
        if ss then sendList(ts, ss) end
    end
    sendList(src, s)
    push(src, { type = 'changed', id = int(g.id), view = 'p' })
    changed(g, nil, src)
end

function ops.leave(src, s, d)
    local g = groupFor(src, s, d.id)
    if not g then return end
    PO.update('DELETE FROM mail_group_members WHERE groupId = ? AND address = ?', { g.id, s.box })
    local left = memberBoxes(g.id)
    if #left == 0 then
        dropReactions(g.id)
        PO.update('DELETE FROM mail_group_messages WHERE groupId = ?', { g.id })
        PO.update('DELETE FROM mail_groups WHERE id = ?', { g.id })
    elseif int(g.owner) == s.box then
        -- the longest-standing member (lowest member row id) takes over
        PO.update('UPDATE mail_groups SET owner = ? WHERE id = ?', { left[1], g.id })
    end
    push(src, { type = 'gone', id = int(g.id), view = 'p', quiet = true })
    sendList(src, s)
    changed(g, left, src)
end

function ops.disband(src, s, d)
    local g = groupFor(src, s, d.id, L.grpOwnerDisband)
    if not g then return end
    local boxes = memberBoxes(g.id)
    dropReactions(g.id)
    PO.update('DELETE FROM mail_group_messages WHERE groupId = ?', { g.id })
    PO.update('DELETE FROM mail_group_members WHERE groupId = ?', { g.id })
    PO.update('DELETE FROM mail_groups WHERE id = ?', { g.id })
    for _, b in ipairs(boxes) do
        local ts = PO.srcForBox(b)
        if ts and ts ~= src then
            push(ts, { type = 'gone', id = int(g.id), view = 'p' })
            local ss = sideOf(ts, 'p')
            if ss then sendList(ts, ss) end
        end
    end
    push(src, { type = 'gone', id = int(g.id), view = 'p', quiet = true })
    sendList(src, s)
end

--------------------------------------------------------------------------------
-- blocking

function ops.block(src, s, d)
    if s.biz then return end
    local target = int(d.box)
    if not target or target <= 0 or target == s.box then return end
    if d.on == true then
        local have = int(PO.scalar('SELECT COUNT(*) FROM mail_blocks WHERE address = ?', { s.box })) or 0
        if have >= MAX_BLOCKS then PO.tip(src, L.chatBlockFull) else
            PO.insert('INSERT IGNORE INTO mail_blocks (address, blocked) VALUES (?, ?)', { s.box, target })
        end
    else
        PO.update('DELETE FROM mail_blocks WHERE address = ? AND blocked = ?', { s.box, target })
    end
    sendList(src, s)
end

--------------------------------------------------------------------------------
-- business blocking (staff who may write for the business)

local function bizBlockList(job)
    local out = {}
    if not PO.bizBlocksReady then return out end
    for _, r in ipairs(PO.query('SELECT address, `date` FROM mail_business_blocks WHERE job = ? ORDER BY id DESC', { job }) or {}) do
        out[#out + 1] = { box = int(r.address), date = r.date or '' }
    end
    return out
end

--- Every online employee who may write for the business gets the new list and chat list.
local function bizBlocksChanged(job, goneIds)
    local list = bizBlockList(job)
    for _, st in ipairs(PO.employees(job)) do
        local ss = sideOf(st, 'b')
        if ss then
            for _, gid in ipairs(goneIds or {}) do push(st, { type = 'gone', id = gid, view = 'b', quiet = true }) end
            push(st, { type = 'bizblocks', view = 'b', list = list })
            sendList(st, ss)
        end
    end
end

function ops.bizblocks(src, s)
    if not s.biz then return end
    push(src, { type = 'bizblocks', view = 'b', list = bizBlockList(s.job) })
end

function ops.bizblock(src, s, d)
    if not s.biz or not PO.bizBlocksReady then return end
    local target = int(d.box)
    if not target or target <= 0 then return end
    if d.on == true then
        local have = int(PO.scalar('SELECT COUNT(*) FROM mail_business_blocks WHERE job = ?', { s.job })) or 0
        if have >= MAX_BIZ_BLOCKS then return PO.tip(src, L.bizBlockFull) end
        PO.insert('INSERT IGNORE INTO mail_business_blocks (job, address, blockedBy, `date`) VALUES (?, ?, ?, ?)', { s.job, target, s.box, PO.isoNow() })
        PO.tip(src, L.bizBlocked:format(target))
    else
        PO.update('DELETE FROM mail_business_blocks WHERE job = ? AND address = ?', { s.job, target })
        PO.tip(src, L.bizUnblocked:format(target))
    end
    -- the customer's chat closes for staff that have it open
    local gone = {}
    if d.on == true then
        for _, r in ipairs(PO.query([[SELECT g.id FROM mail_groups g JOIN mail_group_members m ON m.groupId = g.id
            WHERE g.kind = 'business' AND g.ref = ? AND m.address = ?]], { s.job, target }) or {}) do
            gone[#gone + 1] = int(r.id)
        end
    end
    bizBlocksChanged(s.job, gone)
end

--------------------------------------------------------------------------------

-- ops a business employee may use from the business side
local STAFF_OPS = { list = true, open = true, read = true, post = true, typing = true, handled = true, replies = true, react = true, bizblock = true, bizblocks = true }

RegisterNetEvent('pup_postoffice:chat', function(op, d)
    local src = PO.caller(source)
    if not src or type(op) ~= 'string' or not ops[op] then return end
    if type(d) ~= 'table' then d = {} end
    if not PO.allow(src, 'chat', 40, 5000) then return end
    if not PO.chatReady then
        if op == 'start' or op == 'create' or op == 'post' then PO.tip(src, L.chatLoading) end
        return
    end
    local view = d.view == 'b' and 'b' or 'p'
    if view == 'b' and not STAFF_OPS[op] then return end
    local s = sideOf(src, view)
    if not s then
        if op == 'start' or op == 'create' then PO.tip(src, L.grpNeedBox) end
        if view == 'b' then push(src, { type = 'list', view = 'b', list = {}, badge = 0 }) end
        return
    end
    local ok, err = pcall(ops[op], src, s, d)
    if not ok then print(('[pup_postoffice] chat %s error: %s'):format(op, tostring(err))) end
end)

--------------------------------------------------------------------------------
-- used by an admin box move (one transaction, see exports.lua)

function PO.moveGroupAddress(old, new)
    local q = {
        { query = 'UPDATE mail_groups SET owner = ? WHERE owner = ?', values = { new, old } },
        { query = 'UPDATE IGNORE mail_group_members SET address = ? WHERE address = ?', values = { new, old } },
        { query = 'DELETE FROM mail_group_members WHERE address = ?', values = { old } },
        { query = 'UPDATE mail_group_messages SET address = ? WHERE address = ?', values = { new, old } },
    }
    -- only once the chat upgrade has run, so a box move never fails on a missing table
    if PO.chatReady then
        q[#q + 1] = { query = 'UPDATE IGNORE mail_blocks SET address = ? WHERE address = ?', values = { new, old } }
        q[#q + 1] = { query = 'DELETE FROM mail_blocks WHERE address = ?', values = { old } }
        q[#q + 1] = { query = 'UPDATE IGNORE mail_blocks SET blocked = ? WHERE blocked = ?', values = { new, old } }
        q[#q + 1] = { query = 'DELETE FROM mail_blocks WHERE blocked = ?', values = { old } }
    end
    if PO.bizBlocksReady then
        q[#q + 1] = { query = 'UPDATE IGNORE mail_business_blocks SET address = ? WHERE address = ?', values = { new, old } }
        q[#q + 1] = { query = 'DELETE FROM mail_business_blocks WHERE address = ?', values = { old } }
        q[#q + 1] = { query = 'UPDATE mail_business_blocks SET blockedBy = ? WHERE blockedBy = ?', values = { new, old } }
    end
    if PO.threadsReady then
        local oldWho, newWho = ('p%d'):format(old), ('p%d'):format(new)
        q[#q + 1] = { query = 'UPDATE IGNORE mail_group_reactions SET who = ?, address = ? WHERE who = ?', values = { newWho, new, oldWho } }
        q[#q + 1] = { query = 'DELETE FROM mail_group_reactions WHERE who = ?', values = { oldWho } }
        -- reactions made for a business keep the employee's box only for the record
        q[#q + 1] = { query = 'UPDATE mail_group_reactions SET address = ? WHERE address = ?', values = { new, old } }
    end
    return q
end
