-- pup_postoffice | boxes, businesses and the mailbox payload

--------------------------------------------------------------------------------
-- personal boxes

--- The box of the caller's CURRENT character. Returns box (number) or nil, plus char and charid.
--- The cache is dropped the moment the character id no longer matches, so a box never follows a player.
function PO.getBox(src)
    local char, cid = PO.getChar(src)
    if not char then return nil end
    local p = PO.player(src)
    if p.charid ~= cid then
        p.charid = cid
        p.box = nil
    end
    if p.box == nil then
        local box = PO.scalar('SELECT address FROM mail WHERE charidentifier = ? ORDER BY address ASC LIMIT 1', { cid })
        -- the character may have switched while we waited
        local _, nowCid = PO.getChar(src)
        if nowCid ~= cid then return nil end
        p.box = PO.toInt(box) or false
    end
    return p.box or nil, char, cid
end

function PO.boxOfChar(cid)
    return PO.toInt(PO.scalar('SELECT address FROM mail WHERE charidentifier = ? ORDER BY address ASC LIMIT 1', { cid }))
end

--- Online player whose loaded character owns `box`.
function PO.srcForBox(box)
    for src, p in pairs(PO.players) do
        if p.box == box then
            local _, cid = PO.getChar(src)
            if cid and cid == p.charid then return src end
        end
    end
    return nil
end

function PO.srcForChar(cid)
    local user = PO.Core.getUserByCharId and PO.Core.getUserByCharId(cid)
    if user and user.source then return user.source end
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local _, c = PO.getChar(s)
        if c == cid then return s end
    end
    return nil
end

--------------------------------------------------------------------------------
-- businesses (pup_business is optional)

local function businessStarted()
    return GetResourceState('pup_business') == 'started'
end

--- { job, name, isBoss, canSend } or nil.
function PO.getBusiness(src)
    if not businessStarted() then return nil end
    local ok, info = pcall(function() return exports.pup_business:GetBusinessInfo(src) end)
    if not ok or type(info) ~= 'table' then return nil end
    local job = type(info.job) == 'string' and info.job or nil
    if not job or job == '' then return nil end
    return {
        job = job,
        name = (type(info.name) == 'string' and info.name ~= '') and info.name or job,
        -- accept 1 / '1' as well as true, in case the flags come straight from a database row
        isBoss = PO.truthy(info.isBoss),
        canSend = PO.truthy(info.canSend),
    }
end

function PO.businessName(job)
    if businessStarted() then
        local ok, name = pcall(function() return exports.pup_business:GetBusinessName(job) end)
        if ok and type(name) == 'string' and name ~= '' then return name end
    end
    return job
end

-- job -> handle, and handle -> job, mirrored from mail_business
PO.handles = {}
PO.handleJobs = {}

function PO.loadDirectory()
    local rows = PO.query('SELECT job, handle FROM mail_business', {})
    if not rows then return end
    local handles, jobs = {}, {}
    for _, r in ipairs(rows) do
        if r.job and r.handle then
            local h = tostring(r.handle):lower()
            handles[r.job] = h
            jobs[h] = r.job
        end
    end
    PO.handles, PO.handleJobs = handles, jobs
    PO.directoryLoaded = true
end

function PO.ensureDirectory()
    if not PO.directoryLoaded then PO.loadDirectory() end
end

--- Every registered business box keyed by job: { name, handle }.
function PO.directoryPayload()
    local out = {}
    for job, handle in pairs(PO.handles) do
        out[job] = { name = PO.businessName(job), handle = handle }
    end
    return out
end

function PO.broadcastDirectory()
    TriggerClientEvent('pup_postoffice:directory', -1, PO.directoryPayload())
end

--- The business object sent to the page and to pup_business. nil without a business.
function PO.businessPayload(src, info)
    info = info or PO.getBusiness(src)
    if not info then return nil end
    local handle = PO.handles[info.job]
    if not handle then
        return { job = info.job, name = info.name, isBoss = info.isBoss }
    end
    return {
        job = info.job,
        name = info.name,
        isBoss = info.isBoss,
        token = info.job,
        handle = handle,
        label = info.name,
        canSend = info.canSend,
        changeCost = Config.BusinessChangeCost,
    }
end

--- Online players employed by `job`.
function PO.employees(job)
    local out = {}
    if not businessStarted() then return out end
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local info = PO.getBusiness(s)
        if info and info.job == job then out[#out + 1] = s end
    end
    return out
end

--------------------------------------------------------------------------------
-- letters

--- Row from `mails` into the shape the page and other resources use.
function PO.letterOut(r)
    return {
        id = PO.toInt(r.id),
        anon = PO.truthy(r.anon) and 1 or 0,
        read = PO.truthy(r.read) and 1 or 0,
        from = r.from ~= nil and tostring(r.from) or '',
        to = PO.decodeList(r.to),
        subject = r.subject or '',
        body = r.body or '',
        folder = r.folder or 'Inbox',
        fromName = r.fromName or '',
        toNames = PO.decodeList(r.toNames),
        date = r.date or '',
        hidesent = PO.truthy(r.hidesent) and 1 or 0,
        copyTo = r.copyTo,
        copyToJob = r.copyToJob,
        fromJob = r.fromJob,
    }
end

local LETTER_COLS = 'id, anon, `read`, `from`, `to`, subject, body, folder, fromName, toNames, `date`, hidesent, copyTo, copyToJob, fromJob'
PO.LETTER_COLS = LETTER_COLS

local function lettersFor(sql, params)
    local rows = PO.query(sql, params) or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = PO.letterOut(r) end
    return out
end

local function folderList(rows)
    local out = {}
    for _, r in ipairs(rows or {}) do
        out[#out + 1] = { id = PO.toInt(r.id), name = r.folderName or '' }
    end
    return out
end

function PO.buildMailbox(src)
    local box = PO.getBox(src)
    if not box then return nil end
    PO.ensureDirectory()
    local token = tostring(box)

    local payload = {
        box = box,
        letters = lettersFor(
            ('SELECT %s FROM mails WHERE copyTo = ? OR (copyTo IS NULL AND copyToJob IS NULL AND fromJob IS NULL AND `from` = ? AND hidesent = 0) ORDER BY id ASC'):format(LETTER_COLS),
            { token, token }),
        contacts = {},
        folders = folderList(PO.query('SELECT id, folderName FROM mail_editableFolders WHERE address = ? AND job IS NULL ORDER BY id ASC', { box })),
        directory = PO.directoryPayload(),
    }

    for _, r in ipairs(PO.query('SELECT id, name, poBox, notes FROM mail_addressbook WHERE address = ? ORDER BY id ASC', { box }) or {}) do
        payload.contacts[#payload.contacts + 1] = {
            id = PO.toInt(r.id), name = r.name or '', poBox = r.poBox or '', notes = r.notes or '',
        }
    end

    local info = PO.getBusiness(src)
    payload.business = PO.businessPayload(src, info)
    if info and PO.handles[info.job] then
        payload.businessLetters = lettersFor(
            ('SELECT %s FROM mails WHERE copyToJob = ? OR (copyTo IS NULL AND copyToJob IS NULL AND fromJob = ? AND hidesent = 0) ORDER BY id ASC'):format(LETTER_COLS),
            { info.job, info.job })
        payload.businessFolders = folderList(PO.query('SELECT id, folderName FROM mail_editableFolders WHERE job = ? ORDER BY id ASC', { info.job }))
    end

    -- the character may have switched during the reads above
    local _, cid = PO.getChar(src)
    if cid ~= PO.player(src).charid then return nil end
    return payload
end

function PO.sendMailbox(src)
    if not GetPlayerName(src) then return end
    local payload = PO.buildMailbox(src)
    TriggerClientEvent('pup_postoffice:mailbox', src, payload or false)
end

function PO.resendEmployees(job, except)
    for _, s in ipairs(PO.employees(job)) do
        if s ~= except then PO.sendMailbox(s) end
    end
end

--- Push one letter live. isIncoming = someone sent you mail; false = your own sent copy.
function PO.pushLetter(src, letter, isIncoming)
    TriggerClientEvent('pup_postoffice:rec_addedMailid', src, letter, isIncoming)
end

--------------------------------------------------------------------------------
-- net events

RegisterNetEvent('pup_postoffice:requestMailbox', function()
    local src = PO.caller(source)
    if not src then return end
    local p = PO.player(src)
    local now = GetGameTimer()
    if p.lastMailboxReq and now - p.lastMailboxReq < 2000 then return end
    p.lastMailboxReq = now
    PO.sendMailbox(src)
end)

local function jobChanged(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return end
    -- let VORP finish applying the new job first
    SetTimeout(250, function()
        if PO.players[src] then PO.sendMailbox(src) end
    end)
end

AddEventHandler('vorp:playerJobChange', jobChanged)
AddEventHandler('vorp:playerJobGradeChange', jobChanged)

-- a new character: drop the cached box straight away
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    local p = PO.players[src]
    if p then
        p.charid, p.box = nil, nil
        p.lastSend, p.sending, p.lastPost = nil, nil, nil
    end
end)

AddEventHandler('playerDropped', function()
    PO.forget(source)
end)
