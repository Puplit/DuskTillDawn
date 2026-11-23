-- pup_postoffice | renting a box, sending, filing, contacts and folders

local LIM = Config.Letters
local BOX = Config.Mailbox
local FILE_CAP = 200
local FOLDER_BYTES = 64
local CONTACT_BOX_BYTES = 32
local NAME_BYTES = 64
local RESERVED_FOLDERS = { inbox = true, sent = true, trash = true }

--------------------------------------------------------------------------------
-- renting a personal box

RegisterNetEvent('pup_postoffice:register', function()
    local src, _, cid = PO.caller(source)
    if not src then return end
    local p = PO.player(src)
    if p.registering then return end
    if not PO.allow(src, 'register', 3, 5000) then return end
    p.registering = true

    local ok, err = pcall(function()
        if not PO.nearOffice(src) then
            return PO.tip(src, L.needOffice)
        end
        local existing = PO.boxOfChar(cid)
        -- re-check the character after the read
        local char, nowCid = PO.getChar(src)
        if not char or nowCid ~= cid then return end
        if existing then
            p.charid, p.box = cid, existing
            return PO.tip(src, L.alreadyHaveBox:format(Config.Command))
        end

        local price = math.max(0, PO.toInt(Config.BoxPrice) or 0)
        if price > 0 then
            if (tonumber(char.money) or 0) < price then
                return PO.tip(src, L.notEnoughCash)
            end
            char.removeCurrency(0, price)
        end

        local box = PO.insert('INSERT INTO mail (charidentifier) VALUES (?)', { cid })
        box = PO.toInt(box)
        if not box or box <= 0 then
            if price > 0 then
                local refundTo = PO.getChar(src)
                if refundTo then refundTo.addCurrency(0, price) end
            end
            return PO.tip(src, L.registerFailed)
        end

        p.charid, p.box = cid, box
        TriggerClientEvent('pup_postoffice:boxNumber', src, box)
        PO.sendMailbox(src)
        PO.tip(src, L.registered:format(box))
    end)
    p.registering = false
    if not ok then print(('[pup_postoffice] register error: %s'):format(tostring(err))) end
end)

--------------------------------------------------------------------------------
-- sending

local function sendResult(src, req, ok)
    TriggerClientEvent('pup_postoffice:sendResult', src, req, ok)
end

--- Turn typed tokens into box numbers and business jobs.
local function resolveTokens(list)
    local boxes, jobs, order, invalid = {}, {}, {}, {}
    local seen = {}
    for _, raw in ipairs(list) do
        local t = PO.trim(type(raw) == 'number' and tostring(raw) or (type(raw) == 'string' and raw or ''))
        if t ~= '' then
            local n = tonumber(t)
            if n and t:match('^%d+%.?%d*$') then
                n = math.floor(n)
                local key = tostring(n)
                if n > 0 and n <= 2147483647 then
                    if not seen[key] then
                        seen[key] = true
                        boxes[#boxes + 1] = n
                        order[#order + 1] = key
                    end
                else
                    invalid[#invalid + 1] = t
                end
            else
                local job = PO.handleJobs[t:lower()]
                if not job and PO.handles[t] then job = t end
                if job then
                    if not seen[job] then
                        seen[job] = true
                        jobs[#jobs + 1] = job
                        order[#order + 1] = job
                    end
                else
                    invalid[#invalid + 1] = PO.cutBytes(t, 40)
                end
            end
        end
    end
    return boxes, jobs, order, invalid
end

local function postAnonymousLog(senderLabel, recipients, subject, body)
    local url = PO.secret('Webhooks', 'anonymousLetters')
    if not url then return end
    local function field(name, value)
        value = PO.cutBytes(value ~= '' and value or '(none)', 1000)
        return { name = name, value = value, inline = false }
    end
    local payload = {
        username = 'Anonymous Mail Log',
        allowed_mentions = { parse = {} },
        embeds = { {
            title = 'Anonymous letter sent',
            color = 13632027,
            fields = {
                field('Sender', senderLabel),
                field('Recipients', table.concat(recipients, ', ')),
                field('Subject', subject),
                field('Body', body),
            },
            timestamp = PO.isoNow(),
        } },
    }
    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function handleSend(src, char, cid, data, req)
    local p = PO.player(src)
    local box = PO.getBox(src)
    if not box then return false end

    if type(data.to) ~= 'table' or #data.to == 0 then return false end
    if Config.LocationOnly and not PO.nearOffice(src) then
        PO.tip(src, L.needOffice)
        return false
    end

    -- count without trusting the table size the client claims
    local count = 0
    for _ in ipairs(data.to) do
        count = count + 1
        if count > LIM.maxRecipients then break end
    end
    if count > LIM.maxRecipients then
        PO.tip(src, L.tooManyRecipients:format(LIM.maxRecipients))
        return false
    end

    local body = type(data.body) == 'string' and data.body or ''
    if #body > LIM.maxBody then
        PO.tip(src, L.tooLong)
        return false
    end

    local now = GetGameTimer()
    if p.lastSend and now - p.lastSend < LIM.cooldown * 1000 then
        PO.tip(src, L.cooldown)
        return false
    end

    PO.ensureDirectory()
    local senderToken, senderName, fromJob = tostring(box), PO.charName(char), nil
    local asBusiness = data.asBusiness == true
    local bizJob
    if asBusiness then
        local info = PO.getBusiness(src)
        if not info or not PO.handles[info.job] then
            PO.tip(src, L.bizNoBox)
            return false
        end
        if not info.canSend then
            PO.tip(src, L.bizNoRank:format(info.name))
            return false
        end
        bizJob = info.job
        senderToken, senderName, fromJob = info.job, info.name, info.job
    end
    local anon = data.anon == true

    local boxes, jobs, order, invalid = resolveTokens(data.to)
    -- businesses are reached by chat: business addresses are taken off a letter
    if LIM.businessByChat ~= false and #jobs > 0 then
        local isJob, handles = {}, {}
        for _, j in ipairs(jobs) do isJob[j] = true; handles[#handles + 1] = PO.handles[j] or j end
        local kept = {}
        for _, key in ipairs(order) do if not isJob[key] then kept[#kept + 1] = key end end
        order, jobs = kept, {}
        PO.tip(src, L.bizByChat:format(table.concat(handles, ', ')), 6000)
        if #order == 0 then return false end
    end
    if #boxes > 0 then
        local rows = PO.query(('SELECT address FROM mail WHERE address IN (%s)'):format(PO.placeholders(#boxes)), boxes) or {}
        local exists = {}
        for _, r in ipairs(rows) do exists[PO.toInt(r.address)] = true end
        local kept = {}
        for _, n in ipairs(boxes) do
            if exists[n] then kept[#kept + 1] = n else invalid[#invalid + 1] = tostring(n) end
        end
        boxes = kept
        local finalOrder = {}
        for _, key in ipairs(order) do
            local n = tonumber(key)
            if not n or exists[n] then finalOrder[#finalOrder + 1] = key end
        end
        order = finalOrder
    end

    -- the world may have moved on while we waited for the database
    local nowChar, nowCid = PO.getChar(src)
    if not nowChar or nowCid ~= cid or PO.getBox(src) ~= box then return false end
    if asBusiness then
        local info = PO.getBusiness(src)
        if not info or info.job ~= bizJob or not info.canSend or not PO.handles[bizJob] then return false end
    end

    if #invalid > 0 then
        PO.tip(src, L.invalidAddresses:format(table.concat(invalid, ', ')), 6000)
        if LIM.refuseIfAnyInvalid == true then return false end
    end
    if #order == 0 then return false end

    local subject = PO.cutBytes(type(data.subject) == 'string' and data.subject or '', LIM.maxSubject)
    local names = {}
    if type(data.names) == 'table' then
        for _, n in ipairs(data.names) do
            if #names >= #order then break end
            names[#names + 1] = PO.cutBytes(type(n) == 'string' and n or '', NAME_BYTES)
        end
    end
    local date = PO.isoNow()
    local toJson = json.encode(order)
    local namesJson = json.encode(names)
    if #names == 0 then namesJson = '[]' end

    local shownFrom, shownName, shownJob = senderToken, LIM.showSenderName and senderName or '', fromJob
    if anon then shownFrom, shownName, shownJob = 'Anonymous', 'Anonymous', nil end

    local function row(isRead, from, fromName, copyTo, copyToJob, rowJob)
        return PO.insertRow('mails', {
            { 'anon', anon and 1 or 0 }, { 'read', isRead }, { 'from', from }, { 'to', toJson },
            { 'subject', subject }, { 'body', body }, { 'folder', 'Inbox' }, { 'fromName', fromName },
            { 'toNames', namesJson }, { 'date', date }, { 'hidesent', 0 },
            { 'copyTo', copyTo }, { 'copyToJob', copyToJob }, { 'fromJob', rowJob },
        })
    end
    local deliveries = {}

    local function storeCopy(copyTo, copyToJob)
        local id = row(0, shownFrom, shownName, copyTo, copyToJob, shownJob)
        id = PO.toInt(id)
        if not id then return end
        deliveries[#deliveries + 1] = {
            letter = {
                id = id, anon = anon and 1 or 0, read = 0, from = shownFrom, to = order, subject = subject, body = body,
                folder = 'Inbox', fromName = shownName, toNames = names, date = date, hidesent = 0,
                copyTo = copyTo, copyToJob = copyToJob, fromJob = shownJob,
            },
            box = copyTo and tonumber(copyTo) or nil,
            job = copyToJob,
        }
    end

    for _, n in ipairs(boxes) do storeCopy(tostring(n), nil) end
    for _, job in ipairs(jobs) do storeCopy(nil, job) end
    if #deliveries == 0 then return false end

    -- the cooldown starts only once a letter is actually stored
    p.lastSend = GetGameTimer()

    local sentId = PO.toInt(row(1, senderToken, senderName, nil, nil, fromJob))

    for _, d in ipairs(deliveries) do
        if d.box then
            local s = PO.srcForBox(d.box)
            if s then PO.pushLetter(s, d.letter, true) end
        elseif d.job then
            for _, s in ipairs(PO.employees(d.job)) do PO.pushLetter(s, d.letter, true) end
        end
    end

    if sentId then
        local sentCopy = {
            id = sentId, anon = anon and 1 or 0, read = 1, from = senderToken, to = order, subject = subject, body = body,
            folder = 'Inbox', fromName = senderName, toNames = names, date = date, hidesent = 0,
            fromJob = fromJob,
        }
        if bizJob then
            for _, s in ipairs(PO.employees(bizJob)) do PO.pushLetter(s, sentCopy, false) end
        else
            PO.pushLetter(src, sentCopy, false)
        end
    end

    if anon then
        local who = bizJob and ('%s (%s)'):format(senderName, bizJob) or ('%s (PO Box %d)'):format(senderName, box)
        postAnonymousLog(who, order, subject, body)
    end
    return true
end

RegisterNetEvent('pup_postoffice:send', function(data, req)
    local src, char, cid = PO.caller(source)
    if not src then return end
    if type(data) ~= 'table' then return end
    req = PO.toInt(req) or 0
    local p = PO.player(src)
    -- refused letters do not start the cooldown, so spam is held back here instead
    if not PO.allow(src, 'send', 6, 10000) then
        PO.tip(src, L.cooldown)
        return sendResult(src, req, false)
    end
    if p.sending then
        PO.tip(src, L.cooldown)
        return sendResult(src, req, false)
    end
    p.sending = true
    local ok, result = pcall(handleSend, src, char, cid, data, req)
    p.sending = false
    if not ok then print(('[pup_postoffice] send error: %s'):format(tostring(result))) end
    sendResult(src, req, ok and result == true)
end)

--------------------------------------------------------------------------------
-- filing: read marks, moves, deletes and hidden sent copies

--- SQL that limits rows to the given box tokens: recipient copies of those boxes, or sent copies they wrote.
local function ownClause(personal, job)
    local parts, params = {}, {}
    if personal then
        parts[#parts + 1] = 'copyTo = ?'
        params[#params + 1] = personal
        parts[#parts + 1] = '(copyTo IS NULL AND copyToJob IS NULL AND fromJob IS NULL AND `from` = ?)'
        params[#params + 1] = personal
    end
    if job then
        parts[#parts + 1] = 'copyToJob = ?'
        params[#params + 1] = job
        parts[#parts + 1] = '(copyTo IS NULL AND copyToJob IS NULL AND fromJob = ?)'
        params[#params + 1] = job
    end
    return '(' .. table.concat(parts, ' OR ') .. ')', params
end

local function sentClause(personal, job)
    local parts, params = {}, {}
    if personal then
        parts[#parts + 1] = '(fromJob IS NULL AND `from` = ?)'
        params[#params + 1] = personal
    end
    if job then
        parts[#parts + 1] = 'fromJob = ?'
        params[#params + 1] = job
    end
    return '(copyTo IS NULL AND copyToJob IS NULL AND (' .. table.concat(parts, ' OR ') .. '))', params
end

local function concat(a, b)
    local out = {}
    for _, v in ipairs(a) do out[#out + 1] = v end
    for _, v in ipairs(b) do out[#out + 1] = v end
    return out
end

--- Run an UPDATE/DELETE for one scope. Returns affected rows.
local function runScoped(head, headParams, ids, clause, clauseParams)
    if #ids == 0 then return 0 end
    local sql = ('%s WHERE id IN (%s) AND %s'):format(head, PO.placeholders(#ids), clause)
    return PO.update(sql, concat(concat(headParams, ids), clauseParams)) or 0
end

RegisterNetEvent('pup_postoffice:file', function(data)
    local src = PO.caller(source)
    if not src or type(data) ~= 'table' then return end
    -- every letter opened sends one read mark, so leave room for someone clicking quickly through a list
    if not PO.allow(src, 'file', 30, 5000) then return end

    local box = PO.getBox(src)
    if not box then return end
    local personal = tostring(box)
    local info = PO.getBusiness(src)
    local readJob = (info and PO.handles[info.job]) and info.job or nil
    local manageJob = (readJob and info.canSend) and readJob or nil

    local readIds = PO.idList(data.read, FILE_CAP)
    local delIds = PO.idList(data.del, FILE_CAP)
    local hideIds = PO.idList(data.hide, FILE_CAP)
    local moves = {}
    if type(data.move) == 'table' then
        local n = 0
        for _, m in ipairs(data.move) do
            if n >= FILE_CAP then break end
            if type(m) == 'table' then
                local id = PO.toInt(m.id or m[1])
                local folder = PO.cutBytes(PO.trim(m.folder or m[2]), FOLDER_BYTES)
                if id and id > 0 and folder ~= '' then
                    n = n + 1
                    moves[folder] = moves[folder] or {}
                    table.insert(moves[folder], id)
                end
            end
        end
    end

    local bizChanged = 0
    local function both(head, headParams, ids, canJob, isSent)
        local maker = isSent and sentClause or ownClause
        local c, cp = maker(personal, nil)
        runScoped(head, headParams, ids, c, cp)
        if canJob then
            local bc, bp = maker(nil, canJob)
            bizChanged = bizChanged + runScoped(head, headParams, ids, bc, bp)
        end
    end

    -- every employee can keep the shared read state, not only those who may send
    both('UPDATE mails SET `read` = 1', {}, readIds, readJob, false)
    for folder, ids in pairs(moves) do
        both('UPDATE mails SET folder = ?', { folder }, ids, manageJob, false)
    end
    both('DELETE FROM mails', {}, delIds, manageJob, false)
    both('UPDATE mails SET hidesent = 1', {}, hideIds, manageJob, true)

    -- only bother the rest of the staff when the shared box really changed
    if bizChanged > 0 and readJob then
        PO.resendEmployees(readJob, src)
    end
end)

--------------------------------------------------------------------------------
-- contacts

RegisterNetEvent('pup_postoffice:contacts', function(data)
    local src = PO.caller(source)
    if not src or type(data) ~= 'table' then return end
    if not PO.allow(src, 'contacts', 10, 5000) then return end
    local box = PO.getBox(src)
    if not box then return end
    local cap = BOX.maxContacts

    local function clean(c)
        return PO.cutBytes(PO.trim(c.name), BOX.contactName),
            PO.cutBytes(PO.trim(c.poBox), CONTACT_BOX_BYTES),
            PO.cutBytes(type(c.notes) == 'string' and c.notes or '', BOX.contactNotes)
    end

    if type(data.add) == 'table' and #data.add > 0 then
        local have = PO.toInt(PO.scalar('SELECT COUNT(*) FROM mail_addressbook WHERE address = ?', { box })) or 0
        local full = false
        local n = 0
        for _, c in ipairs(data.add) do
            n = n + 1
            if n > cap then break end
            if type(c) == 'table' then
                local ref = PO.cutBytes(tostring(c.ref or ''), 40)
                local name, poBox, notes = clean(c)
                local id
                if have >= cap then
                    full = true
                elseif name ~= '' then
                    id = PO.toInt(PO.insert('INSERT INTO mail_addressbook (address, name, poBox, notes) VALUES (?, ?, ?, ?)', { box, name, poBox, notes }))
                    if id then have = have + 1 end
                end
                TriggerClientEvent('pup_postoffice:contactAdded', src, ref, id or false, id and { id = id, name = name, poBox = poBox, notes = notes } or nil)
            end
        end
        if full then PO.tip(src, L.bookFull) end
    end

    if type(data.edit) == 'table' then
        local n = 0
        for _, c in ipairs(data.edit) do
            n = n + 1
            if n > cap then break end
            if type(c) == 'table' then
                local id = PO.toInt(c.id)
                local name, poBox, notes = clean(c)
                if id and name ~= '' then
                    PO.update('UPDATE mail_addressbook SET name = ?, poBox = ?, notes = ? WHERE id = ? AND address = ?', { name, poBox, notes, id, box })
                end
            end
        end
    end

    local delIds = PO.idList(data.del, cap)
    if #delIds > 0 then
        local params = concat(delIds, { box })
        PO.update(('DELETE FROM mail_addressbook WHERE id IN (%s) AND address = ?'):format(PO.placeholders(#delIds)), params)
    end
end)

--------------------------------------------------------------------------------
-- custom folders

RegisterNetEvent('pup_postoffice:folders', function(data)
    local src = PO.caller(source)
    if not src or type(data) ~= 'table' then return end
    if not PO.allow(src, 'folders', 10, 5000) then return end
    local box = PO.getBox(src)
    if not box then return end

    local business = data.business == true
    local job
    if business then
        local info = PO.getBusiness(src)
        if not info or not PO.handles[info.job] or not info.canSend then return end
        job = info.job
    end

    -- owner scope for folder rows and for the letters filed in them
    local ownerSql, ownerParams
    if job then ownerSql, ownerParams = 'job = ?', { job }
    else ownerSql, ownerParams = 'address = ? AND job IS NULL', { box } end
    local letterClause, letterParams
    if job then letterClause, letterParams = ownClause(nil, job)
    else letterClause, letterParams = ownClause(tostring(box), nil) end

    local op = data.op
    local ref = PO.cutBytes(tostring(data.ref or ''), 40)

    local function nameOk(name)
        if name == '' or RESERVED_FOLDERS[name:lower()] then return false end
        local rows = PO.query(('SELECT folderName FROM mail_editableFolders WHERE %s'):format(ownerSql), ownerParams) or {}
        for _, r in ipairs(rows) do
            if tostring(r.folderName or ''):lower() == name:lower() then return false end
        end
        return true
    end

    if op == 'add' then
        local name = PO.cutBytes(PO.trim(data.name), FOLDER_BYTES)
        local have = PO.toInt(PO.scalar(('SELECT COUNT(*) FROM mail_editableFolders WHERE %s'):format(ownerSql), ownerParams)) or 0
        local id
        if have >= BOX.maxFolders then
            PO.tip(src, L.folderLimit)
        elseif not nameOk(name) then
            PO.tip(src, L.folderBadName)
        else
            if job then
                id = PO.insert('INSERT INTO mail_editableFolders (address, folderName, job) VALUES (NULL, ?, ?)', { name, job })
            else
                id = PO.insert('INSERT INTO mail_editableFolders (address, folderName, job) VALUES (?, ?, NULL)', { box, name })
            end
            id = PO.toInt(id)
        end
        TriggerClientEvent('pup_postoffice:folderAdded', src, ref, id or false, job ~= nil, id and name or nil)
        if id and job then PO.resendEmployees(job, src) end

    elseif op == 'rename' then
        local id = PO.toInt(data.id)
        local name = PO.cutBytes(PO.trim(data.name), FOLDER_BYTES)
        if not id then return end
        local row = PO.single(('SELECT folderName FROM mail_editableFolders WHERE id = ? AND %s'):format(ownerSql), concat({ id }, ownerParams))
        if not row then return end
        local old = row.folderName or ''
        if old:lower() ~= name:lower() and not nameOk(name) then
            return PO.tip(src, L.folderBadName)
        end
        PO.update(('UPDATE mail_editableFolders SET folderName = ? WHERE id = ? AND %s'):format(ownerSql), concat({ name, id }, ownerParams))
        PO.update(('UPDATE mails SET folder = ? WHERE folder = ? AND %s'):format(letterClause), concat({ name, old }, letterParams))
        if job then PO.resendEmployees(job, src) end

    elseif op == 'del' then
        local id = PO.toInt(data.id)
        if not id then return end
        local row = PO.single(('SELECT folderName FROM mail_editableFolders WHERE id = ? AND %s'):format(ownerSql), concat({ id }, ownerParams))
        if not row then return end
        -- letters inside go to Trash first, so nothing is left in a folder that no longer exists
        PO.update(('UPDATE mails SET folder = ? WHERE folder = ? AND %s'):format(letterClause), concat({ 'Trash', row.folderName or '' }, letterParams))
        PO.update(('DELETE FROM mail_editableFolders WHERE id = ? AND %s'):format(ownerSql), concat({ id }, ownerParams))
        if job then PO.resendEmployees(job, src) end
    end
end)
