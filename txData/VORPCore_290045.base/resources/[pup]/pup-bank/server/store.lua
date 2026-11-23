-- pup-bank | the account tables. Every read and write of bank_users and bank_activity
-- on the player side goes through Store, so the column whitelist lives in one place.
--   bank_users    : one row per character, one balance column per branch, plus total_money
--   bank_activity : the ledger; one row per movement, with the balance it left behind

Store = {}

local sql = exports.oxmysql

-- branch name -> balance column, built once from Config.Banks. A name that is not a key
-- here never reaches a query, so nothing a client sends can pick a column.
local columnOf = {}
for name in pairs(Config.Banks) do
    columnOf[name] = (name:lower():gsub(" bank", ""):gsub("%s", "")) .. "_money"
end

function Store.column(branch)
    if type(branch) ~= "string" then return nil end
    return columnOf[branch]
end

function Store.branches()
    local list = {}
    for name in pairs(columnOf) do list[#list + 1] = name end
    table.sort(list)
    return list
end

-- an UPDATE reports through oxmysql either as a number or as { affectedRows = n }
function Store.changed(result)
    if type(result) == "table" then return (tonumber(result.affectedRows) or 0) > 0 end
    return (tonumber(result) or 0) > 0
end

-- what a bank_users row holds at one branch (0 when there is no row)
function Store.held(row, branch)
    local col = columnOf[branch]
    return (row and col and tonumber(row[col])) or 0
end

-- async: the character's whole row, or nil
function Store.fetch(charid, done)
    sql:execute("SELECT * FROM bank_users WHERE charidentifier = ?", { charid }, function(rows)
        done(rows and rows[1] or nil)
    end)
end

-- async: a first visit gets an empty row; balances start at the column defaults
function Store.open(charid, identifier, steamname)
    sql:execute("INSERT IGNORE INTO bank_users (identifier, steamname, charidentifier) VALUES (?, ?, ?)",
        { identifier, steamname, charid })
end

-- async: pay in; done(true) only when a row took the money
function Store.credit(charid, branch, amount, done)
    local col = columnOf[branch]
    sql:update(("UPDATE bank_users SET `%s` = `%s` + ?, total_money = total_money + ? WHERE charidentifier = ?")
        :format(col, col), { amount, amount, charid }, function(res)
        done(Store.changed(res))
    end)
end

-- async: take out. The balance test sits in the WHERE, so two requests at once can never
-- both be paid and the column never goes below zero.
function Store.debit(charid, branch, amount, done)
    local col = columnOf[branch]
    sql:update(("UPDATE bank_users SET `%s` = `%s` - ?, total_money = total_money - ? WHERE charidentifier = ? AND `%s` >= ?")
        :format(col, col, col), { amount, amount, charid, amount }, function(res)
        done(Store.changed(res))
    end)
end

-- async: one branch's balance right now
function Store.balance(charid, branch, done)
    local col = columnOf[branch]
    sql:execute(("SELECT `%s` AS held FROM bank_users WHERE charidentifier = ?"):format(col), { charid }, function(rows)
        done((rows and rows[1] and tonumber(rows[1].held)) or 0)
    end)
end

-- async: one ledger row; done (optional) runs once it is written
function Store.record(charid, branch, kind, amount, after, actor, done)
    sql:execute([[
        INSERT INTO bank_activity (charidentifier, bank, ts, type, amount, balance_after, actor)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { charid, tostring(branch), os.time(), tostring(kind), tonumber(amount) or 0, tonumber(after) or 0, tostring(actor or "") },
    function() if done then done() end end)
end

-- the newest 15 ledger rows a player can still see at one branch: rows older than their
-- last "Clear Statement" are hidden, never deleted
function Store.statement(charid, branch, done)
    sql:execute([[
        SELECT a.ts, a.type, a.amount, a.balance_after
          FROM bank_activity a
          LEFT JOIN bank_statement_clears c ON c.charidentifier = a.charidentifier AND c.bank = a.bank
         WHERE a.charidentifier = ? AND a.bank = ? AND a.ts > COALESCE(c.cleared_at, 0)
         ORDER BY a.id DESC
         LIMIT 15
    ]], { charid, branch }, function(rows) done(rows or {}) end)
end

-- async: hide everything written so far at this branch from this player's statement
function Store.clearStatement(charid, branch, done)
    sql:execute([[
        INSERT INTO bank_statement_clears (charidentifier, bank, cleared_at) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE cleared_at = VALUES(cleared_at)
    ]], { charid, branch, os.time() }, function() if done then done() end end)
end

-- synchronous versions for the exports, which answer their caller directly
Store.sync = {}

function Store.sync.ensure(charid)
    local have = sql:executeSync("SELECT 1 FROM bank_users WHERE charidentifier = ?", { charid })
    if have and have[1] then return end
    sql:executeSync([[
        INSERT IGNORE INTO bank_users (identifier, charidentifier)
        SELECT identifier, charidentifier FROM characters WHERE charidentifier = ?
    ]], { charid })
end

function Store.sync.credit(charid, branch, amount)
    local col = columnOf[branch]
    return Store.changed(sql:executeSync(
        ("UPDATE bank_users SET `%s` = `%s` + ?, total_money = total_money + ? WHERE charidentifier = ?"):format(col, col),
        { amount, amount, charid }))
end

function Store.sync.debit(charid, branch, amount)
    local col = columnOf[branch]
    return Store.changed(sql:executeSync(
        ("UPDATE bank_users SET `%s` = `%s` - ?, total_money = total_money - ? WHERE charidentifier = ? AND `%s` >= ?"):format(col, col, col),
        { amount, amount, charid, amount }))
end

function Store.sync.balance(charid, branch)
    local col = columnOf[branch]
    local rows = sql:executeSync(("SELECT `%s` AS held FROM bank_users WHERE charidentifier = ?"):format(col), { charid })
    return (rows and rows[1] and tonumber(rows[1].held)) or 0
end

-- the ledger keeps about 90 days: trimmed once at start, then every six hours
local KEEP_SECONDS = 90 * 24 * 3600
CreateThread(function()
    Wait(10000)
    while true do
        sql:execute("DELETE FROM bank_activity WHERE ts < ?", { os.time() - KEEP_SECONDS })
        Wait(6 * 3600 * 1000)
    end
end)
