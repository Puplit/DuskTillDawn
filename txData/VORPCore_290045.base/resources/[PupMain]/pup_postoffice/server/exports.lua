-- pup_postoffice | exports: system letters from other resources, and vorp_admin's box tools

local MAX_BOX = 2147483647
local A = L.admin

local function validBox(v)
    local n = tonumber(v)
    if not n or n ~= math.floor(n) or n < 1 or n > MAX_BOX then return nil end
    return math.floor(n)
end

--------------------------------------------------------------------------------
-- system letters

exports('SendSystemMail', function(charid, subject, body, fromName)
    local cid = PO.toInt(charid)
    if not cid then return false end
    local box = PO.boxOfChar(cid)
    if not box then return false end
    local token = tostring(box)
    local date = PO.isoNow()
    subject = PO.cutBytes(subject ~= nil and tostring(subject) or '', Config.Letters.maxSubject)
    body = body ~= nil and tostring(body) or ''
    fromName = fromName ~= nil and tostring(fromName) or ''
    local id = PO.toInt(PO.insert(
        'INSERT INTO mails (anon, `read`, `from`, `to`, subject, body, folder, fromName, toNames, `date`, hidesent, copyTo) VALUES (0, 0, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)',
        { 'system', json.encode({ token }), subject, body, 'Inbox', fromName, '[]', date, token }))
    if not id then return false end
    local s = PO.srcForBox(box)
    if s then
        PO.pushLetter(s, {
            id = id, anon = 0, read = 0, from = 'system', to = { token }, subject = subject, body = body, folder = 'Inbox',
            fromName = fromName, toNames = {}, date = date, hidesent = 0, copyTo = token,
        }, true)
    end
    return true
end)

--------------------------------------------------------------------------------
-- admin: reading

exports('AdminGetAddress', function(src)
    src = tonumber(src)
    if not src then return nil end
    -- only the number: getBox also returns the character object, which must not cross the export boundary
    local box = PO.getBox(src)
    return box
end)

exports('AdminGetAddressByChar', function(charid)
    local cid = PO.toInt(charid)
    if not cid then return nil end
    return PO.boxOfChar(cid)
end)

--------------------------------------------------------------------------------
-- admin: moving a box

local function tellOwner(cid, box, message)
    local s = PO.srcForChar(cid)
    if not s then return end
    local p = PO.player(s)
    local _, nowCid = PO.getChar(s)
    if nowCid ~= cid then return end
    p.charid, p.box = cid, box
    TriggerClientEvent('pup_postoffice:boxNumber', s, box)
    PO.sendMailbox(s)
    PO.tip(s, message)
end

local function moveBox(cid, newAddress, byPlayer)
    local new = validBox(newAddress)
    if not new then return false, A.badNumber end

    local holder = PO.toInt(PO.scalar('SELECT charidentifier FROM mail WHERE address = ? LIMIT 1', { new }))
    if holder and holder ~= cid then return false, A.taken:format(new) end
    if holder == cid then return true end
    if PO.scalar('SELECT address FROM mail WHERE address = ? LIMIT 1', { new }) then
        -- a row with no owner still blocks the number
        return false, A.taken:format(new)
    end

    local old = PO.boxOfChar(cid)
    if not old then return false, byPlayer and A.playerNoBox or A.charNoBox end

    local o, n = tostring(old), tostring(new)
    local quotedOld, quotedNew = '"' .. o .. '"', '"' .. n .. '"'
    local queries = {
        { query = 'INSERT INTO mail (address, charidentifier) VALUES (?, ?)', values = { new, cid } },
        { query = 'UPDATE mail_addressbook SET address = ? WHERE address = ?', values = { new, old } },
        { query = 'UPDATE mail_editableFolders SET address = ? WHERE address = ?', values = { new, old } },
        { query = 'UPDATE mails SET copyTo = ? WHERE copyTo = ?', values = { n, o } },
        { query = 'UPDATE mails SET `from` = ? WHERE `from` = ?', values = { n, o } },
        -- exact quoted value only, so box 12 never matches inside 123
        { query = 'UPDATE mails SET `to` = REPLACE(`to`, ?, ?) WHERE `to` LIKE ?', values = { quotedOld, quotedNew, '%' .. quotedOld .. '%' } },
        { query = 'UPDATE mail_addressbook SET poBox = ? WHERE TRIM(poBox) = ?', values = { n, o } },
    }
    for _, q in ipairs(PO.moveGroupAddress(old, new)) do queries[#queries + 1] = q end
    queries[#queries + 1] = { query = 'DELETE FROM mail WHERE address = ?', values = { old } }

    local ok, done = pcall(MySQL.transaction.await, queries)
    if not ok or not done then
        print(('[pup_postoffice] box move %d -> %d failed: %s'):format(old, new, tostring(done)))
        return false, A.dbFailed
    end

    -- any cached copy of the old number is stale now
    for _, p in pairs(PO.players) do
        if p.box == old then p.box = nil end
    end
    tellOwner(cid, new, L.adminMoved:format(new))
    print(('[pup_postoffice] PO Box %d moved to %d (character %d)'):format(old, new, cid))
    return true
end

local function createBox(cid, wanted)
    local existing = PO.boxOfChar(cid)
    if existing then return false, A.hasBox:format(existing) end

    local box
    if wanted ~= nil and wanted ~= '' then
        local n = validBox(wanted)
        if not n then return false, A.badNumber end
        if PO.scalar('SELECT address FROM mail WHERE address = ? LIMIT 1', { n }) then return false, A.taken:format(n) end
        local inserted = PO.insert('INSERT INTO mail (address, charidentifier) VALUES (?, ?)', { n, cid })
        if inserted == nil then return false, A.dbFailed end
        box = n
    else
        box = PO.toInt(PO.insert('INSERT INTO mail (charidentifier) VALUES (?)', { cid }))
        if not box then return false, A.dbFailed end
    end

    tellOwner(cid, box, L.adminCreated:format(box))
    print(('[pup_postoffice] PO Box %d created for character %d'):format(box, cid))
    return true
end

local function playerChar(src)
    src = tonumber(src)
    if not src then return nil, A.noTarget end
    local user = PO.Core.getUser(src)
    local char = user and user.getUsedCharacter
    if type(char) ~= 'table' then return nil, A.notLoaded end
    local cid = PO.toInt(char.charIdentifier)
    if not cid or cid <= 0 then return nil, A.noCharacter end
    return cid
end

exports('AdminSetAddress', function(src, newAddress)
    local cid, why = playerChar(src)
    if not cid then return false, why end
    return moveBox(cid, newAddress, true)
end)

exports('AdminSetAddressByChar', function(charid, newAddress)
    local cid = PO.toInt(charid)
    if not cid or cid <= 0 then return false, A.noCharacter end
    return moveBox(cid, newAddress, false)
end)

exports('AdminCreateAddress', function(src, wanted)
    local cid, why = playerChar(src)
    if not cid then return false, why end
    return createBox(cid, wanted)
end)

exports('AdminCreateAddressByChar', function(charid, wanted)
    local cid = PO.toInt(charid)
    if not cid or cid <= 0 then return false, A.noCharacter end
    return createBox(cid, wanted)
end)

--------------------------------------------------------------------------------
-- admin: business handles (no boss check and no fee, by design)

exports('AdminGetBusinessHandle', function(job)
    if type(job) ~= 'string' or job == '' then return nil end
    local h = PO.scalar('SELECT handle FROM mail_business WHERE job = ? LIMIT 1', { job })
    return h and tostring(h) or nil
end)

exports('AdminSetBusinessHandle', function(job, text)
    if type(job) ~= 'string' or PO.trim(job) == '' then return false, A.noBusiness end
    job = PO.trim(job)
    local want, why = PO.normaliseHandle(text)
    if not want then return false, why == 'empty' and L.bizEmpty or L.bizFormat end

    local current = PO.scalar('SELECT handle FROM mail_business WHERE job = ? LIMIT 1', { job })
    if current and tostring(current):lower() == want then return true, want end

    local owner = PO.handleOwner(want)
    if owner and owner ~= job then
        local free = PO.suggestHandle(want)
        return false, free and A.takenFree:format(want, free) or A.takenNone:format(want)
    end

    if current then
        PO.update('UPDATE IGNORE mail_business SET handle = ? WHERE job = ?', { want, job })
    else
        PO.insert('INSERT IGNORE INTO mail_business (job, handle) VALUES (?, ?)', { job, want })
    end
    local stored = PO.scalar('SELECT handle FROM mail_business WHERE job = ? LIMIT 1', { job })
    if not stored or tostring(stored):lower() ~= want then return false, A.setFailed end

    PO.afterHandleChange(job, nil)
    return true, want
end)
