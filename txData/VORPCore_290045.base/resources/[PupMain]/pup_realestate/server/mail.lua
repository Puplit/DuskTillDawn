-- pup_realestate | letters through pup_postoffice's tables, and pup-bank branch accounts

-- a letter from the Housing Team to a character's PO box (none without a box)
function S.sendLetter(charid, subject, body)
    charid = U.int(charid)
    if not charid then return end
    CreateThread(function()
        local ok, address = pcall(MySQL.scalar.await, 'SELECT address FROM mail WHERE charidentifier = ? ORDER BY address ASC LIMIT 1', { charid })
        if not ok or address == nil then return end
        local addr = tostring(address)
        local to = json.encode({ addr })
        local date = os.date('!%Y-%m-%dT%H:%M:%S') .. '.000Z'
        local okI, id = pcall(MySQL.insert.await, [[
            INSERT INTO mails (anon, `read`, `from`, `to`, subject, body, folder, fromName, toNames, `date`, hidesent, copyTo)
            VALUES (0, 0, '0', ?, ?, ?, 'Inbox', 'Housing Team', '[]', ?, 0, ?)]],
            { to, subject, body, date, addr })
        if not okI or not id then return end
        local src = S.sourceOf(charid)
        if src then
            TriggerClientEvent('pup_postoffice:rec_addedMailid', src, {
                id = id, anon = 0, read = 0, from = '0', to = { addr }, subject = subject, body = body,
                folder = 'Inbox', fromName = 'Housing Team', toNames = {}, date = date,
                hidesent = 0, copyTo = addr,
            }, true)
        end
    end)
end

-- bank branches: the keys of pup-bank's Config.Banks, read once from its config file
local branches

function S.branches()
    if branches then return branches end
    branches = {}
    if GetResourceState('pup-bank') ~= 'missing' then
        local code = LoadResourceFile('pup-bank', 'config/banks.lua')
        if code then
            local seen = {}
            for name in code:gmatch('%[%s*["\']([^"\']+)["\']%s*%]%s*=%s*{') do
                if not seen[name] then
                    seen[name] = true
                    branches[#branches + 1] = name
                end
            end
        end
    end
    if #branches == 0 then branches = { Config.Auctions.refundBank } end
    table.sort(branches)
    return branches
end

function S.knownBranch(name)
    for _, b in ipairs(S.branches()) do
        if b == name then return b end
    end
    return nil
end

-- "Saint Denis Bank" -> saintdenis_money (only known branches, only safe characters)
function S.branchColumn(name)
    local b = S.knownBranch(name) or Config.Auctions.refundBank
    local col = b:lower():gsub(' bank', ''):gsub('%s', '') .. '_money'
    if not col:match('^[a-z0-9_]+$') then return nil, b end
    return col, b
end

function S.balances(charid)
    local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM bank_users WHERE charidentifier = ? LIMIT 1', { charid })
    if not ok then return nil end
    local row = rows and rows[1]
    local list = {}
    if not row then return list end
    for _, b in ipairs(S.branches()) do
        local col = S.branchColumn(b)
        if col and row[col] ~= nil then
            list[#list + 1] = { bank = b, balance = math.floor(tonumber(row[col]) or 0) }
        end
    end
    return list
end

local function bankActivity(charid, bank, kind, amount, after)
    MySQL.insert('INSERT INTO bank_activity (charidentifier, bank, ts, type, amount, balance_after, actor) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { charid, bank, Now(), kind, amount, after or 0, 'Housing Auction' })
end

-- guarded withdrawal: true only when this exact update took the money
function S.bankTake(charid, bankName, amount)
    local col, bank = S.branchColumn(bankName)
    if not col then return false end
    local ok, n = pcall(MySQL.update.await,
        ('UPDATE bank_users SET `%s` = `%s` - ?, total_money = total_money - ? WHERE charidentifier = ? AND `%s` >= ?'):format(col, col, col),
        { amount, amount, charid, amount })
    if not ok or n ~= 1 then return false end
    local okB, after = pcall(MySQL.scalar.await, ('SELECT `%s` FROM bank_users WHERE charidentifier = ?'):format(col), { charid })
    bankActivity(charid, bank, 'withdraw', amount, okB and tonumber(after) or 0)
    return true, bank
end

-- refund into a branch, opening an account if the character has none
function S.bankRefund(charid, bankName, amount, note)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    local col, bank = S.branchColumn(bankName)
    if not col then col, bank = S.branchColumn(Config.Auctions.refundBank) end
    if not col then return Warn('refund of $%s to char %s failed: no usable bank column', amount, charid) end
    local ok, n = pcall(MySQL.update.await,
        ('UPDATE bank_users SET `%s` = `%s` + ?, total_money = total_money + ? WHERE charidentifier = ?'):format(col, col),
        { amount, amount, charid })
    if not ok then return Warn('refund of $%s to char %s failed', amount, charid) end
    if n ~= 1 then
        local okC, rows = pcall(MySQL.query.await, 'SELECT identifier, steamname FROM characters WHERE charidentifier = ? LIMIT 1', { charid })
        local c = okC and rows and rows[1] or {}
        local okI = pcall(MySQL.insert.await,
            ('INSERT INTO bank_users (charidentifier, identifier, steamname, `%s`, total_money) VALUES (?, ?, ?, ?, ?)'):format(col),
            { charid, c.identifier or '', c.steamname or '', amount, amount })
        if not okI then return Warn('refund of $%s to char %s failed: could not open an account', amount, charid) end
    end
    local okB, after = pcall(MySQL.scalar.await, ('SELECT `%s` FROM bank_users WHERE charidentifier = ?'):format(col), { charid })
    bankActivity(charid, bank, 'deposit', amount, okB and tonumber(after) or amount)
    local src = S.sourceOf(charid)
    if src then Tip(src, ('%s - $%s went back into your %s account'):format(note or 'Refund', U.money(amount), bank), 8000) end
end
