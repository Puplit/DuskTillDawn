-- pup-bank | the counter: what a player sees at a branch, deposits, withdrawals, the
-- statement, the exports other resources pay through, and the Discord log.
-- The client only asks; every amount, distance and balance is decided here.

local Core = {}
TriggerEvent("getCore", function(core) Core = core end)

local function trace(...)
    if not Config.General.debug then return end
    local out = {}
    for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end
    print("^5[pup-bank]^7 " .. table.concat(out, " "))
end

local function tip(src, text)
    TriggerClientEvent("vorp:TipRight", src, text, 10000)
end

-- the player behind a request, or nil when they have no character loaded
local function customer(src)
    local user = Core.getUser and Core.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if not char then return nil end
    return {
        src        = src,
        char       = char,
        charid     = char.charIdentifier,
        identifier = user.getIdentifier(),
        steam      = GetPlayerName(src) or "?",
        name       = ((char.firstname or "") .. " " .. (char.lastname or "")):gsub("^%s+", ""),
    }
end

local function atCounter(src, branch)
    local bank = Config.Banks[branch]
    local ped = GetPlayerPed(src)
    if not bank or not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - bank.counter) < (Config.Counter.serverRange or 15.0)
end

-- a usable amount: a real positive number under a billion, cut to whole cents (the columns
-- store cents, so anything finer would vanish in the DB but not from the pocket)
local function cents(v)
    if type(v) ~= "number" or v ~= v or v <= 0 or v >= 1e9 then return nil end
    local c = math.floor(v * 100 + 1e-6) / 100
    if c < 0.01 then return nil end
    return math.tointeger(c) or c -- $100 reads as 100, not 100.0
end

-- one move of each kind per half second per player; an honest client waits for its reply anyway
local lastMove = {}
local function tooFast(src, kind, gap)
    local now = GetGameTimer()
    local mine = lastMove[src]
    if not mine then mine = {}; lastMove[src] = mine end
    if mine[kind] and now - mine[kind] < (gap or 500) then return true end
    mine[kind] = now
    return false
end

local viewPending = {}

AddEventHandler("playerDropped", function()
    lastMove[source] = nil
    viewPending[source] = nil
end)

-------------------------------------------------------------------------------
-- the statement as the app shows it
-------------------------------------------------------------------------------

local function ago(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return "-" end
    local secs = math.max(0, os.time() - ts)
    if secs < 60 then return Locale.agoNow end
    if secs < 3600 then return Locale.agoMinutes:format(math.floor(secs / 60)) end
    if secs < 86400 then return Locale.agoHours:format(math.floor(secs / 3600)) end
    return Locale.agoDays:format(math.floor(secs / 86400))
end

-- entry type -> label and direction. Exports log their own reasons; those read as credit or
-- debit by the sign of the amount.
local ENTRY = {
    deposit      = { label = "entryIn",      incoming = true },
    withdraw     = { label = "entryOut",     incoming = false },
    transfer_in  = { label = "entryXferIn",  incoming = true },
    transfer_out = { label = "entryXferOut", incoming = false },
}

local function entryLine(r)
    local amount = tonumber(r.amount) or 0
    local known = ENTRY[tostring(r.type)]
    local incoming, label
    if known then
        incoming, label = known.incoming, Locale[known.label]
    else
        incoming = amount >= 0
        label = incoming and Locale.entryCredit or Locale.entryDebit
    end
    return {
        when     = ago(r.ts),
        label    = label,
        incoming = incoming,
        amount   = ("%s$%.2f"):format(incoming and "+" or "-", math.abs(amount)),
        balance  = ("$%.2f"):format(tonumber(r.balance_after) or 0),
    }
end

-- everything the app needs in one reply: this branch, every branch, the statement and
-- whether the Teller tab belongs on the strip
local function sendView(p, branch)
    Store.fetch(p.charid, function(row)
        if not row then Store.open(p.charid, p.identifier, p.steam) end
        local balances = {}
        for _, name in ipairs(Store.branches()) do
            balances[name] = Store.held(row, name)
        end
        Store.statement(p.charid, branch, function(rows)
            local lines = {}
            for i, r in ipairs(rows) do lines[i] = entryLine(r) end
            trace("view", "src=" .. p.src, branch, "#lines=" .. #lines)
            TriggerClientEvent("pup-bank:cl:view", p.src, {
                branch   = branch,
                balances = balances,
                lines    = lines,
                teller   = TellerAllowed ~= nil and TellerAllowed(p.src) or false,
            })
        end)
    end)
end

-------------------------------------------------------------------------------
-- Discord
-------------------------------------------------------------------------------

local lastPing = {}

local function postToDiscord(kind, p, branch, amount)
    local hook = Secrets and Secrets.Webhooks and Secrets.Webhooks.admin
    if type(hook) ~= "string" or hook == "" then return end

    local avatar = Config.Logs.avatarUrl
    if avatar == "" then avatar = nil end -- blank = Discord's default avatar

    local steamId, discordId = "N/A", "N/A"
    for _, id in ipairs(GetPlayerIdentifiers(p.src) or {}) do
        if id:sub(1, 8) == "discord:" then discordId = id:sub(9)
        elseif id:sub(1, 6) == "steam:" then steamId = id end
    end

    local incoming = kind == "deposit"
    local heading = incoming and "💰 DEPOSIT" or "🏧 WITHDRAW"

    -- @everyone only for a big deposit, and only once per five minutes per character, so
    -- cycling the same money cannot spam the staff server
    local mention = ""
    local key = tostring(p.charid)
    if incoming and amount >= (Config.Logs.pingStaffAbove or 30000)
        and (not lastPing[key] or os.time() - lastPing[key] >= 300) then
        lastPing[key] = os.time()
        mention = "@everyone"
    end

    local embed = {
        title = heading .. " - " .. branch,
        color = incoming and 3066993 or 15158332,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        fields = {
            { name = "Transaction", inline = false, value = table.concat({
                "**Branch:** " .. branch,
                "**Type:** " .. heading,
                "**Amount:** $" .. tostring(amount),
            }, "\n") },
            { name = "Customer", inline = false, value = table.concat({
                "**Character:** " .. p.name .. " (" .. tostring(p.charid) .. ")",
                "**Steam:** " .. p.steam .. " / " .. steamId,
                "**Discord:** <@" .. discordId .. ">",
            }, "\n") },
        },
    }

    PerformHttpRequest(hook, function() end, "POST",
        json.encode({ username = p.steam, avatar_url = avatar, content = mention, embeds = { embed } }),
        { ["Content-Type"] = "application/json" })
end

-------------------------------------------------------------------------------
-- player requests
-------------------------------------------------------------------------------

-- open / refresh the app at a branch
RegisterNetEvent("pup-bank:sv:view", function(branch)
    local src = source
    if not Store.column(branch) then return end
    -- one view a second; a request inside that gap is answered once the gap is over
    if tooFast(src, "view", 1000) then
        if viewPending[src] then return end
        viewPending[src] = true
        SetTimeout(1000, function()
            viewPending[src] = nil
            local q = customer(src)
            if q then sendView(q, branch) end
        end)
        return
    end
    local p = customer(src)
    if not p then return end
    trace("view request", "src=" .. src, branch)
    sendView(p, branch)
end)

-- after the money has moved: ledger row with the new balance, the log, then a fresh view
local function settle(p, branch, kind, amount)
    Store.balance(p.charid, branch, function(after)
        Store.record(p.charid, branch, kind, amount, after, p.name, function()
            sendView(p, branch)
        end)
    end)
    postToDiscord(kind, p, branch, amount)
end

local function payIn(p, branch, amount)
    if (tonumber(p.char.money) or 0) < amount then
        tip(p.src, Locale.refused)
        return sendView(p, branch)
    end
    -- the cash leaves first; if no row takes it, it comes straight back
    p.char.removeCurrency(0, amount)
    Store.credit(p.charid, branch, amount, function(ok)
        if not ok then
            p.char.addCurrency(0, amount)
            tip(p.src, Locale.refused)
            return sendView(p, branch)
        end
        trace("deposit", "src=" .. p.src, "$" .. tostring(amount))
        tip(p.src, Locale.paidIn:format(tostring(amount)))
        settle(p, branch, "deposit", amount)
        -- large deposits also land in vorp_admin's Anti-Cheat tab
        pcall(TriggerEvent, "vorp_admin:ac:bankDeposit", p.src, amount, branch)
    end)
end

local function takeOut(p, branch, amount)
    Store.debit(p.charid, branch, amount, function(ok)
        if not ok then
            tip(p.src, Locale.refused)
            return sendView(p, branch)
        end
        trace("withdraw", "src=" .. p.src, "$" .. tostring(amount))
        p.char.addCurrency(0, amount)
        tip(p.src, Locale.tookOut:format(tostring(amount)))
        settle(p, branch, "withdraw", amount)
    end)
end

RegisterNetEvent("pup-bank:sv:move", function(kind, amount, branch)
    local src = source
    if kind ~= "deposit" and kind ~= "withdraw" then return end
    if not Store.column(branch) then return end
    if not atCounter(src, branch) then
        print(("[pup-bank] %s sent a %s from away from the %s counter"):format(GetPlayerName(src) or src, kind, branch))
        return
    end
    local p = customer(src)
    if not p then return end
    trace("move", "src=" .. src, kind, tostring(amount), branch)

    local value = cents(amount)
    if not value then
        tip(src, Locale.refused)
        return sendView(p, branch)
    end
    if tooFast(src, kind) then return sendView(p, branch) end

    if kind == "deposit" then payIn(p, branch, value) else takeOut(p, branch, value) end
end)

-- "Clear Statement": hides rows only; they still age out on the 90 day trim
RegisterNetEvent("pup-bank:sv:clear", function(branch)
    local src = source
    if not Store.column(branch) then return end
    if tooFast(src, "clear", 2000) then return end
    local p = customer(src)
    if not p then return end
    Store.clearStatement(p.charid, branch, function() sendView(p, branch) end)
end)

-------------------------------------------------------------------------------
-- exports (charid = VORP character id, bankname = a key of Config.Banks)
-------------------------------------------------------------------------------

-- pay into an account with no cash changing hands; a true answer means the caller hands
-- the money over and stops holding it
exports("CreditAccount", function(charid, amount, bankname, reason)
    charid, amount = tonumber(charid), tonumber(amount)
    if not charid or not amount or amount <= 0 then return false, "bad arguments" end
    bankname = tostring(bankname or "")
    if not Store.column(bankname) then return false, "unknown bank" end

    Store.sync.ensure(charid) -- the UPDATE needs a row to land in
    if not Store.sync.credit(charid, bankname, amount) then return false, "no account" end

    local balance = Store.sync.balance(charid, bankname)
    local why = tostring(reason or "credit")
    Store.record(charid, bankname, why, amount, balance, why)
    return true, balance
end)

-- take money out of an account without it becoming cash; never below zero
exports("DebitAccount", function(charid, amount, bankname, reason)
    charid, amount = tonumber(charid), tonumber(amount)
    if not charid or not amount or amount <= 0 then return false, "bad arguments" end
    bankname = tostring(bankname or "")
    if not Store.column(bankname) then return false, "unknown bank" end

    if not Store.sync.debit(charid, bankname, amount) then return false, "insufficient funds" end

    local balance = Store.sync.balance(charid, bankname)
    local why = tostring(reason or "debit")
    Store.record(charid, bankname, why, -amount, balance, why)
    return true, balance
end)

-- what an account holds at one branch; nil for an unknown branch
exports("GetAccountBalance", function(charid, bankname)
    charid = tonumber(charid)
    bankname = tostring(bankname or "")
    if not charid or not Store.column(bankname) then return nil end
    return Store.sync.balance(charid, bankname)
end)

-- branch names, sorted, for another resource's picker
exports("GetBankNames", function()
    return Store.branches()
end)
