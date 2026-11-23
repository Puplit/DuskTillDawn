-- Ledger accounts, payment methods, charges and payouts. Everything is in cents.

Money = {}

---------------------------------------------------------------------------
-- pup-bank
---------------------------------------------------------------------------
local function bankOn()
    return Config.Bank.enabled and GetResourceState('pup-bank') == 'started'
end

-- branch names pup-bank offers right now (empty when the bank is off)
function Money.BankNames()
    if not bankOn() then return {} end
    local ok, names = pcall(function() return exports['pup-bank']:GetBankNames() end)
    if not ok or type(names) ~= 'table' then return {} end
    local out = {}
    for _, n in ipairs(names) do
        if type(n) == 'string' then out[#out + 1] = n end
    end
    return out
end

function Money.ValidBank(name)
    if type(name) ~= 'string' or name == '' then return nil end
    for _, n in ipairs(Money.BankNames()) do
        if n == name then return n end
    end
    return nil
end

-- true on success; nil when the call itself failed (bank down)
local function bankDebit(charid, cents, branch, reason)
    local ok, done = pcall(function()
        return exports['pup-bank']:DebitAccount(charid, TP.FromCents(cents), branch, reason)
    end)
    if not ok then return nil end
    return done == true
end

local function bankCredit(charid, cents, branch, reason)
    local ok, done = pcall(function()
        return exports['pup-bank']:CreditAccount(charid, TP.FromCents(cents), branch, reason)
    end)
    return ok and done == true
end

---------------------------------------------------------------------------
-- accounts
---------------------------------------------------------------------------
-- { balance, lifetime (cents), payWith ('cash'|'bank'), bank (valid branch or nil), storedBank }
function Money.Account(charid)
    local rows = MySQL.query.await(
        'SELECT balance, lifetime, pay_with, bank FROM tradepost_accounts WHERE charid = ?', { charid })
    local row = rows and rows[1]
    local acct = {
        balance = row and TP.ToCents(row.balance) or 0,
        lifetime = row and TP.ToCents(row.lifetime) or 0,
        payWith = (row and row.pay_with == 'bank') and 'bank' or 'cash',
        storedBank = row and row.bank or nil,
    }
    acct.bank = Money.ValidBank(acct.storedBank)
    return acct
end

-- adds to the ledger balance and, for earnings, to lifetime
function Money.CreditLedger(charid, cents, isEarning)
    if cents <= 0 then return true end
    local life = isEarning and cents or 0
    local res = MySQL.update.await(
        'INSERT INTO tradepost_accounts (charid, balance, lifetime) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance), lifetime = lifetime + VALUES(lifetime)',
        { charid, TP.FromCents(cents), TP.FromCents(life) })
    return DB.Affected(res) > 0
end

-- takes cents off the ledger only if the balance still covers it
function Money.TakeLedger(charid, cents)
    local res = MySQL.update.await(
        'UPDATE tradepost_accounts SET balance = balance - ? WHERE charid = ? AND balance >= ?',
        { TP.FromCents(cents), charid, TP.FromCents(cents) })
    return DB.Affected(res) > 0
end

function Money.SetPayWith(charid, payWith, bank)
    if payWith == 'bank' then
        MySQL.update.await(
            'INSERT INTO tradepost_accounts (charid, pay_with, bank) VALUES (?, \'bank\', ?) ON DUPLICATE KEY UPDATE pay_with = \'bank\', bank = VALUES(bank)',
            { charid, bank })
    else
        MySQL.update.await(
            'INSERT INTO tradepost_accounts (charid, pay_with) VALUES (?, \'cash\') ON DUPLICATE KEY UPDATE pay_with = \'cash\'',
            { charid })
    end
end

---------------------------------------------------------------------------
-- charging the acting player
---------------------------------------------------------------------------
local function chargeCash(src, charid, cents)
    local _, char, now = TP.Player(src)
    if not char or now ~= charid then return false, Lang.cantAfford end
    local have = TP.ToCents(char.money) or 0
    if have < cents then return false, Lang.cantAfford end
    char.removeCurrency(0, TP.FromCents(cents))
    return true
end

-- Charges by the character's chosen method. Returns ok, message.
function Money.Charge(src, charid, cents, reason)
    if cents <= 0 then return true end
    local acct = Money.Account(charid)
    if not TP.SameChar(src, charid) then return false, Lang.notOpen end
    if acct.payWith == 'bank' and acct.bank then
        local done = bankDebit(charid, cents, acct.bank, reason)
        if done == nil then return false, Lang.bankClosed end
        if not done then return false, Lang.cantAfford end
        return true
    end
    return chargeCash(src, charid, cents)
end

-- cash to the acting player; false when they are no longer on that character
function Money.GiveCash(src, charid, cents)
    local _, char, now = TP.Player(src)
    if not char or now ~= charid then return false end
    char.addCurrency(0, TP.FromCents(cents))
    return true
end

---------------------------------------------------------------------------
-- payouts and refunds
---------------------------------------------------------------------------

-- seller earnings: ledger, or the bank in 'bank' payout mode
function Money.Payout(charid, cents)
    if cents <= 0 then return end
    if Config.Payout.mode == 'bank' and bankOn() then
        local acct = Money.Account(charid)
        if acct.bank and bankCredit(charid, cents, acct.bank, 'trading post sale') then
            MySQL.update.await(
                'INSERT INTO tradepost_accounts (charid, lifetime) VALUES (?, ?) ON DUPLICATE KEY UPDATE lifetime = lifetime + VALUES(lifetime)',
                { charid, TP.FromCents(cents) })
            return
        end
    end
    Money.CreditLedger(charid, cents, true)
end

-- refunds always land in the ledger (the character may be offline)
function Money.Refund(charid, cents)
    return Money.CreditLedger(charid, cents, false)
end

-- moves the ledger to a bank branch; returns ok, message, cents
function Money.SendToBank(charid, cents, branch)
    if not Money.TakeLedger(charid, cents) then return false, Lang.nothingToTake end
    if not bankCredit(charid, cents, branch, 'trading post ledger') then
        Money.CreditLedger(charid, cents, false)
        return false, Lang.bankClosed
    end
    return true
end
