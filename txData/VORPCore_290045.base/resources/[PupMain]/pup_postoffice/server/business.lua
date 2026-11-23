-- pup_postoffice | business PO addresses (pup_business dashboard and vorp_admin)

local jobLocks = {}

--- Normalise typed text into a handle. Returns handle, or nil plus a reason key ('empty' | 'format').
function PO.normaliseHandle(text)
    local s = (type(text) == 'string' and text or (text ~= nil and tostring(text) or '')):gsub('%s', ''):lower()
    if s == '' then return nil, 'empty' end
    if not s:match('^[a-z][a-z][a-z][0-9][0-9][0-9]$') then return nil, 'format' end
    return s
end

--- Job that holds `handle`, from the database (the real source of truth).
function PO.handleOwner(handle)
    return PO.scalar('SELECT job FROM mail_business WHERE handle = ? LIMIT 1', { handle })
end

--- Up to 25 random free handles with the same three letters. Returns one, or nil.
function PO.suggestHandle(want)
    local letters = want:sub(1, 3)
    local used = {}
    for _, r in ipairs(PO.query('SELECT handle FROM mail_business WHERE handle LIKE ?', { letters .. '%' }) or {}) do
        used[tostring(r.handle):lower()] = true
    end
    for _ = 1, 25 do
        local candidate = ('%s%03d'):format(letters, math.random(0, 999))
        if not used[candidate] then return candidate end
    end
    return nil
end

local function formatReason(key)
    return key == 'empty' and L.bizEmpty or L.bizFormat
end

local function takenMessage(want, admin)
    local free = PO.suggestHandle(want)
    if admin then
        return free and L.admin.takenFree:format(want, free) or L.admin.takenNone:format(want)
    end
    return free and L.bizTakenFree:format(want, free) or L.bizTakenNone:format(want)
end

--- After any change to a business box: refresh the mirror, every employee's mailbox and every directory.
local function afterHandleChange(job, requester)
    PO.loadDirectory()
    PO.resendEmployees(job, nil)
    PO.broadcastDirectory()
    if requester then
        TriggerClientEvent('mail:business:state', requester, PO.businessPayload(requester))
    end
end
PO.afterHandleChange = afterHandleChange

--------------------------------------------------------------------------------
-- dashboard events

RegisterNetEvent('mail:business:request', function()
    local src = PO.caller(source)
    if not src then return end
    if not PO.allow(src, 'bizstate', 4, 2000) then return end
    TriggerClientEvent('mail:business:state', src, PO.businessPayload(src))
end)

RegisterNetEvent('mail:business:register', function(text)
    local src = PO.caller(source)
    if not src then return end
    if not PO.allow(src, 'bizwrite', 2, 2000) then return end

    local info = PO.getBusiness(src)
    if not info then return PO.tip(src, L.bizNotEmployed) end
    if not info.isBoss then return PO.tip(src, L.bizNotBoss) end

    local current = PO.scalar('SELECT handle FROM mail_business WHERE job = ? LIMIT 1', { info.job })
    if current then return PO.tip(src, L.bizHasBox:format(info.name)) end

    local want, why = PO.normaliseHandle(text)
    if not want then return PO.tip(src, formatReason(why)) end

    local owner = PO.handleOwner(want)
    if owner then return PO.tip(src, takenMessage(want, false), 6000) end

    -- still the boss of the same business after the reads?
    local again = PO.getBusiness(src)
    if not again or again.job ~= info.job or not again.isBoss then return end

    -- the unique index decides a race between two bosses
    PO.insert('INSERT IGNORE INTO mail_business (job, handle) VALUES (?, ?)', { info.job, want })
    local stored = PO.scalar('SELECT handle FROM mail_business WHERE job = ? LIMIT 1', { info.job })
    if not stored or tostring(stored):lower() ~= want then
        return PO.tip(src, L.bizRegisterFail)
    end

    PO.tip(src, L.bizRegistered:format(info.name, want))
    afterHandleChange(info.job, src)
end)

RegisterNetEvent('mail:business:setHandle', function(text)
    local src, char = PO.caller(source)
    if not src then return end
    if not PO.allow(src, 'bizwrite', 2, 2000) then return end

    local info = PO.getBusiness(src)
    if not info or not info.isBoss then return end
    local job = info.job

    local current = PO.scalar('SELECT handle FROM mail_business WHERE job = ? LIMIT 1', { job })
    if not current then return PO.tip(src, L.bizRegisterFirst) end
    current = tostring(current):lower()

    local want, why = PO.normaliseHandle(text)
    if not want then return PO.tip(src, formatReason(why)) end
    if want == current then return PO.tip(src, L.bizSame) end

    local now = GetGameTimer()
    if jobLocks[job] and now < jobLocks[job] then return end
    jobLocks[job] = now + 5000

    local owner = PO.handleOwner(want)
    if owner and owner ~= job then return PO.tip(src, takenMessage(want, false), 6000) end

    -- still the boss of the same business after the reads? (they may have been demoted or left)
    local again = PO.getBusiness(src)
    if not again or again.job ~= job or not again.isBoss then return end
    char = PO.getChar(src) or char

    local cost = math.max(0, PO.toInt(Config.BusinessChangeCost) or 0)
    if cost > 0 then
        local ledger = PO.scalar('SELECT ledger FROM society_ledger WHERE job = ? LIMIT 1', { job })
        if ledger == nil then return PO.tip(src, L.bizNoLedger) end
        local taken = PO.update('UPDATE society_ledger SET ledger = ledger - ? WHERE job = ? AND ledger >= ?', { cost, job, cost })
        if not taken or taken < 1 then
            local balance = PO.toInt(PO.scalar('SELECT ledger FROM society_ledger WHERE job = ? LIMIT 1', { job })) or 0
            return PO.tip(src, L.bizCantAfford:format(cost, balance), 6000)
        end
    end

    PO.update('UPDATE IGNORE mail_business SET handle = ? WHERE job = ?', { want, job })
    local stored = PO.scalar('SELECT handle FROM mail_business WHERE job = ? LIMIT 1', { job })
    if not stored or tostring(stored):lower() ~= want then
        if cost > 0 then
            PO.update('UPDATE society_ledger SET ledger = ledger + ? WHERE job = ?', { cost, job })
        end
        return PO.tip(src, L.bizChangeFail)
    end

    if cost > 0 then
        local actor = PO.charName(char)
        if actor == '' then actor = GetPlayerName(src) or '' end
        PO.insert('INSERT INTO society_activity (job, ts, type, detail, actor) VALUES (?, ?, ?, ?, ?)', {
            job, os.time(), 'MAIL', PO.cutBytes(L.bizActivity:format(current, want, cost), 255), PO.cutBytes(actor, 100),
        })
        PO.tip(src, L.bizChangedPaid:format(want, cost))
    else
        PO.tip(src, L.bizChanged:format(want))
    end
    afterHandleChange(job, src)
end)
