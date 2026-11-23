-- bank teller: look up an account and move money between two; no deposits, withdrawals or treasury access
-- every transfer needs the sender to accept it on their own screen while at the counter

local Core = {}
TriggerEvent("getCore", function(core) Core = core end)

CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `bank_treasury` (
            `id`            INT           NOT NULL DEFAULT 1,
            `balance`       DECIMAL(14,2) NOT NULL DEFAULT 0,
            `total_tax_in`  DECIMAL(14,2) NOT NULL DEFAULT 0,
            `total_fees_in` DECIMAL(14,2) NOT NULL DEFAULT 0,
            `total_loaned`  DECIMAL(14,2) NOT NULL DEFAULT 0,
            `total_repaid`  DECIMAL(14,2) NOT NULL DEFAULT 0,
            `updated_at`    INT           NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function()
        exports.oxmysql:execute("INSERT IGNORE INTO `bank_treasury` (`id`) VALUES (1)", {})
    end)
end)

local TCfg = Config.Teller or {}

-- serverId -> pending proposal awaiting that player's consent
local awaiting = {}

local function notify(src, text, ms)
    TriggerClientEvent("vorp:TipRight", src, text, ms or 7000)
end

local function charOf(src)
    local user = Core.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter
end

--- is this player on duty as a teller, and what may they move?
local function tellerOf(src)
    if not TCfg.enabled then return nil end
    local ch = charOf(src)
    if not ch then return nil end
    if tostring(ch.job or "") ~= tostring(TCfg.job) then return nil end
    -- vorp_core exposes jobGrade (capital G); lowercase is the DB shape
    local grade = tonumber(ch.jobGrade) or tonumber(ch.jobgrade) or 0
    if grade < (tonumber(TCfg.minGrade) or 0) then return nil end
    local isManager = grade >= (tonumber(TCfg.managerGrade) or 999)
    return {
        charid  = ch.charIdentifier,
        name    = ((ch.firstname or "") .. " " .. (ch.lastname or "")):gsub("^%s+", ""),
        grade   = grade,
        manager = isManager,
        cap     = isManager and (tonumber(TCfg.transferMaxManager) or 0)
                            or (tonumber(TCfg.transferMax) or 0),
    }
end

-- Config.Banks is the whitelist (server/store.lua), so the column name never comes from the client
local columnFor = Store.column

local function atBank(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    local range = Config.Counter.serverRange or 15.0
    for name, b in pairs(Config.Banks) do
        if #(c - b.counter) < range then return name end
    end
    return nil
end

-- server/main.lua puts this in every view of the app, so a firing or promotion applies at the next visit
function TellerAllowed(src)
    return tellerOf(src) ~= nil
end

-- opening the desk: the job and the counter are checked HERE, never on the client
RegisterServerEvent("pup-bank:teller:request")
AddEventHandler("pup-bank:teller:request", function()
    local src = source
    if not tellerOf(src) then
        return notify(src, "You are not on the bank teller job.")
    end
    if not atBank(src) then
        return notify(src, "You must be stood at a bank counter.")
    end
    TriggerClientEvent("pup-bank:teller:open", src)
end)

-- both sides get a ledger row with the teller named as the actor
function TellerLog(job)
    local actor = ("teller %s"):format(job.tellerName or "?")
    local function row(charid, bankname, typ, amount)
        Store.balance(charid, bankname, function(after)
            Store.record(charid, bankname, typ, amount, after, actor)
        end)
    end
    row(job.fromCharid, job.fromBank, "transfer_out", job.amount + job.fee)
    row(job.toCharid,   job.toBank,   "transfer_in",  job.amount)

    local hook = Secrets.Webhooks.admin
    if type(hook) ~= "string" or hook == "" then return end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({
        username = "Bank",
        embeds = { {
            title = "🏦 TELLER TRANSFER",
            color = 3447003,
            description = ("**Teller:** %s (char %s)\n**From:** char %s — %s\n**To:** char %s — %s\n**Amount:** $%d\n**Fee:** $%d")
                :format(tostring(job.tellerName), tostring(job.tellerCharid),
                        tostring(job.fromCharid), job.fromBank,
                        tostring(job.toCharid), job.toBank, job.amount, job.fee),
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

-- account lookup: read-only, every branch, never pocket cash
RegisterServerEvent("pup-bank:teller:lookup")
AddEventHandler("pup-bank:teller:lookup", function(charid)
    local src = source
    if not tellerOf(src) then return end
    if not atBank(src) then return notify(src, "You must be at a counter.") end

    charid = tonumber(charid)
    if not charid then return notify(src, "Enter a character ID.") end

    exports.oxmysql:execute(
        "SELECT firstname, lastname FROM characters WHERE charidentifier = ?", { charid },
        function(who)
            if not who or not who[1] then
                return notify(src, ("No character with ID %d."):format(charid))
            end
            local name = ((who[1].firstname or "") .. " " .. (who[1].lastname or "")):gsub("^%s+", "")
            exports.oxmysql:execute(
                "SELECT * FROM bank_users WHERE charidentifier = ?", { charid },
                function(rows)
                    local branches = {}
                    local row = rows and rows[1]
                    for bankname in pairs(Config.Banks) do
                        branches[bankname] = Store.held(row, bankname)
                    end
                    TriggerClientEvent("pup-bank:teller:lookupResult", src, {
                        charid   = charid,
                        name     = name,
                        branches = branches,
                        hasAccount = row ~= nil,
                    })
                end)
        end)
end)

-- who is stood close enough to be served
RegisterServerEvent("pup-bank:teller:nearby")
AddEventHandler("pup-bank:teller:nearby", function()
    local src = source
    if not tellerOf(src) then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local me = GetEntityCoords(ped)
    local range = tonumber(TCfg.nearbyRange) or 5.0

    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local pid = tonumber(id)
        if pid and pid ~= src then
            local p = GetPlayerPed(pid)
            if p and p ~= 0 and #(me - GetEntityCoords(p)) <= range then
                local ch = charOf(pid)
                if ch then
                    out[#out + 1] = {
                        serverId = pid,
                        charid   = ch.charIdentifier,
                        name     = ((ch.firstname or "") .. " " .. (ch.lastname or "")):gsub("^%s+", ""),
                    }
                end
            end
        end
    end
    TriggerClientEvent("pup-bank:teller:nearbyResult", src, out)
end)

-- propose: validated here, then sent to the sender to accept; nothing moves until they do
RegisterServerEvent("pup-bank:teller:propose")
AddEventHandler("pup-bank:teller:propose", function(data)
    local src = source
    local teller = tellerOf(src)
    if not teller then return end
    if type(data) ~= "table" then return end
    local branch = atBank(src)
    if not branch then return notify(src, "You must be at a counter.") end

    local fromSrc   = tonumber(data.fromServerId)
    local fromBank  = tostring(data.fromBank or "")
    local toCharid  = tonumber(data.toCharid)
    local toBank    = tostring(data.toBank or "")
    local amount    = math.floor(tonumber(data.amount) or 0)
    local fee       = math.floor(tonumber(data.fee) or 0)

    if not fromSrc or not toCharid then return notify(src, "Missing sender or recipient.") end
    if amount ~= amount or fee ~= fee then return notify(src, "Amount is too small.") end
    if not columnFor(fromBank) or not columnFor(toBank) then return notify(src, "Unknown branch.") end

    local fromCh = charOf(fromSrc)
    if not fromCh then return notify(src, "That sender is no longer online.") end
    if tonumber(fromCh.charIdentifier) == toCharid then
        return notify(src, "Sender and recipient are the same account.")
    end
    -- a teller moving money to or from THEMSELVES is the thing consent cannot catch
    if tonumber(fromCh.charIdentifier) == tonumber(teller.charid)
        or toCharid == tonumber(teller.charid) then
        return notify(src, "You cannot bank for your own character.")
    end

    -- the sender has to actually be at the counter with them
    local tp, fp = GetPlayerPed(src), GetPlayerPed(fromSrc)
    if not tp or not fp or tp == 0 or fp == 0
        or #(GetEntityCoords(tp) - GetEntityCoords(fp)) > (tonumber(TCfg.nearbyRange) or 5.0) then
        return notify(src, "They must be stood at your counter.")
    end

    if amount < (tonumber(TCfg.transferMin) or 1) then return notify(src, "Amount is too small.") end
    if amount > teller.cap then
        return notify(src, ("Your grade may move at most $%d."):format(teller.cap))
    end
    local feeCap = math.min(tonumber(TCfg.feeMax) or 0,
        math.floor(amount * ((tonumber(TCfg.feeMaxPct) or 0) / 100)))
    if fee < (tonumber(TCfg.feeMin) or 0) or fee > feeCap then
        return notify(src, ("Fee must be between $%d and $%d for that amount.")
            :format(tonumber(TCfg.feeMin) or 0, feeCap))
    end

    -- A second offer must not replace one already on their screen: they could read $10 and accept $10,000.
    if awaiting[fromSrc] and os.time() <= awaiting[fromSrc].expires then
        return notify(src, "They are already looking at a transfer.")
    end

    awaiting[fromSrc] = {
        teller = src, tellerName = teller.name, tellerCharid = teller.charid,
        fromCharid = fromCh.charIdentifier, fromBank = fromBank,
        toCharid = toCharid, toBank = toBank,
        amount = amount, fee = fee,
        expires = os.time() + (tonumber(TCfg.consentSeconds) or 45),
    }

    exports.oxmysql:execute(
        "SELECT firstname, lastname FROM characters WHERE charidentifier = ?", { toCharid },
        function(who)
            local toName = who and who[1]
                and (((who[1].firstname or "") .. " " .. (who[1].lastname or "")):gsub("^%s+", ""))
                or ("char " .. toCharid)
            TriggerClientEvent("pup-bank:teller:consent", fromSrc, {
                teller = teller.name,
                fromBank = fromBank, toBank = toBank,
                toName = toName, toCharid = toCharid,
                amount = amount, fee = fee, total = amount + fee,
                seconds = tonumber(TCfg.consentSeconds) or 45,
            })
            notify(src, ("Waiting for %s to accept."):format(
                ((fromCh.firstname or "") .. " " .. (fromCh.lastname or "")):gsub("^%s+", "")))
        end)
end)

-- respond: the debit carries its own guard; a failed credit puts the money straight back
RegisterServerEvent("pup-bank:teller:respond")
AddEventHandler("pup-bank:teller:respond", function(accept)
    local src = source
    local job = awaiting[src]
    awaiting[src] = nil
    if not job then return end

    if os.time() > job.expires then
        notify(src, "That transfer request expired.")
        if GetPlayerName(job.teller) then notify(job.teller, "The request expired.") end
        return
    end
    if not accept then
        notify(src, "You declined the transfer.")
        if GetPlayerName(job.teller) then notify(job.teller, "They declined.") end
        return
    end

    local fromCol, toCol = columnFor(job.fromBank), columnFor(job.toBank)
    if not fromCol or not toCol then return end
    local total = job.amount + job.fee

    -- the WHERE only debits if the money is there; `update` returns affected rows
    exports.oxmysql:update(
        ("UPDATE bank_users SET `%s` = `%s` - ?, `total_money` = `total_money` - ? WHERE charidentifier = ? AND `%s` >= ?")
            :format(fromCol, fromCol, fromCol),
        { total, total, job.fromCharid, total },
        function(affected)
            if (tonumber(affected) or 0) < 1 then
                notify(src, "Not enough in that branch to cover the amount and fee.")
                if GetPlayerName(job.teller) then notify(job.teller, "Their branch could not cover it.") end
                return
            end

            exports.oxmysql:update(
                ("UPDATE bank_users SET `%s` = `%s` + ?, `total_money` = `total_money` + ? WHERE charidentifier = ?")
                    :format(toCol, toCol),
                { job.amount, job.amount, job.toCharid },
                function(credited)
                    if (tonumber(credited) or 0) < 1 then
                        -- recipient row vanished: put the sender's money back rather than lose it
                        exports.oxmysql:execute(
                            ("UPDATE bank_users SET `%s` = `%s` + ?, `total_money` = `total_money` + ? WHERE charidentifier = ?")
                                :format(fromCol, fromCol),
                            { total, total, job.fromCharid })
                        notify(src, "That account could not be credited. Nothing was taken.")
                        if GetPlayerName(job.teller) then notify(job.teller, "Recipient has no account. Reversed.") end
                        return
                    end

                    if job.fee > 0 then
                        exports.oxmysql:execute([[
                            UPDATE bank_treasury
                            SET balance = balance + ?, total_fees_in = total_fees_in + ?, updated_at = ?
                            WHERE id = 1
                        ]], { job.fee, job.fee, os.time() })
                    end

                    TellerLog(job)
                    notify(src, ("Sent $%d. Fee $%d."):format(job.amount, job.fee))
                    if GetPlayerName(job.teller) then
                        notify(job.teller, ("Transfer complete: $%d to char %d."):format(job.amount, job.toCharid))
                        TriggerClientEvent("pup-bank:teller:done", job.teller)
                    end
                end)
        end)
end)

AddEventHandler("playerDropped", function()
    awaiting[source] = nil
end)
