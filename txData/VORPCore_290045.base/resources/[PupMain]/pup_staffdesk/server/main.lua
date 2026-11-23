-- pup_staffdesk | the desk panel callback, staff commands and exports
local Core = Desk.Core

CreateThread(function() DeskDB.init() end)

-------------------------------------------------------------------------------
-- PANEL
-------------------------------------------------------------------------------
local function when(t)
    t = tonumber(t)
    return t and os.date('%d %b %H:%M', t) or ''
end

local function parcelRow(p)
    return { id = tonumber(p.id), kind = p.kind, name = p.name, label = p.label, amount = p.amount,
             what = Parcels.describe(p), note = p.note or '', by = p.sent_by or '', when = when(p.created_at),
             to = p.charid and ('#' .. p.charid) or ('@' .. tostring(p.discordid)) }
end

local ops = {}

function ops.overview(src)
    local ch = Desk.char(src)
    local charid = tonumber(ch.charIdentifier)
    return {
        name = Desk.trim((ch.firstname or '') .. ' ' .. (ch.lastname or '')), charid = charid,
        cash = tonumber(ch.money) or 0, waiting = #Parcels.waiting(src),
        points = Bounty.balance(charid).points, hours = Playtime.of(charid),
        staff = Desk.isStaff(src), discord = Desk.discordOf(src) ~= nil,
    }
end

function ops.parcels(src)
    local out = {}
    for _, p in ipairs(Parcels.waiting(src)) do out[#out + 1] = parcelRow(p) end
    return { list = out, discord = Desk.discordOf(src) ~= nil }
end

function ops.claim(src, d) local ok, msg = Parcels.claim(src, d.id) return { ok = ok, msg = msg } end
function ops.claimAll(src) local ok, msg = Parcels.claimAll(src) return { ok = ok, msg = msg } end

function ops.changes(src)
    local ch = Desk.char(src)
    local charid = tonumber(ch.charIdentifier)
    return {
        height = Config.Height.enabled and { current = Changes.height(src), price = Config.Height.price,
            min = Config.Height.min, max = Config.Height.max } or nil,
        rename = Config.Rename.enabled and { price = Config.Rename.price, wait = Changes.renameLeft(charid),
            first = ch.firstname, last = ch.lastname } or nil,
        pets = Changes.pets(src),
        weapons = Changes.weapons(src),
    }
end

function ops.height(src, d) local ok, msg = Changes.setHeight(src, d.value) return { ok = ok, msg = msg } end
function ops.rename(src, d) local ok, msg = Changes.rename(src, d.first, d.last) return { ok = ok, msg = msg } end
function ops.petName(src, d) local ok, msg = Changes.namePet(src, d.id, d.name, d.desc) return { ok = ok, msg = msg } end
function ops.weaponName(src, d) local ok, msg = Changes.nameWeapon(src, d.id, d.name, d.desc) return { ok = ok, msg = msg } end

function ops.bounty(src)
    local charid = Desk.charid(src)
    local bal = Bounty.balance(charid)
    local rewards = {}
    for _, r in ipairs(Config.Bounty.rewards) do
        if (tonumber(r.cost) or 0) > 0 then rewards[#rewards + 1] = { item = r.item, label = r.label, cost = r.cost, afford = bal.points >= r.cost } end
    end
    local hist = {}
    for _, h in ipairs(Bounty.history(charid, 25)) do
        hist[#hist + 1] = { delta = tonumber(h.delta) or 0, reason = h.reason, by = h.by_name, when = when(h.at) }
    end
    return { balance = bal, rewards = rewards, history = hist }
end

function ops.redeem(src, d) local ok, msg = Bounty.redeem(src, d.item) return { ok = ok, msg = msg } end

function ops.playtime(src)
    local s = Playtime.summary(src) or { mine = 0, total = 0, count = 1 }
    return { mine = s.mine, total = s.total, count = s.count,
             nextHours = s.nextMs and s.nextMs.hours, nextNote = s.nextMs and s.nextMs.note }
end

-- staff only from here
local staffOps = {}

function staffOps.staffPending(src, d)
    local out = {}
    for _, p in ipairs(Parcels.pending(d.query, 100)) do out[#out + 1] = parcelRow(p) end
    return { list = out }
end

function staffOps.staffSend(src, d)
    local charid, discordid, why = Parcels.recipient(d.target)
    if why then return { ok = false, msg = why } end
    local id, err = Parcels.send({ charid = charid, discordid = discordid, kind = d.kind, name = d.name,
        amount = d.amount, note = d.note, by = Desk.who(src) })
    DeskDB.audit('game', Desk.who(src), 'parcel', ('%s %s %s %s'):format(tostring(d.target), tostring(d.kind), tostring(d.name or ''), tostring(d.amount or '')), id ~= nil)
    if not id then return { ok = false, msg = err } end
    return { ok = true, msg = Locale.sent:format(id) }
end

function staffOps.staffCancel(src, d)
    local ok, msg = Parcels.cancel(d.id, Desk.who(src))
    DeskDB.audit('game', Desk.who(src), 'cancel', tostring(d.id), ok)
    return { ok = ok, msg = msg }
end

function staffOps.staffPoints(src, d)
    local bal, name = Bounty.change(d.charid, d.delta, d.reason, Desk.who(src))
    DeskDB.audit('game', Desk.who(src), 'points', ('%s %s'):format(tostring(d.charid), tostring(d.delta)), bal ~= nil)
    if not bal then return { ok = false, msg = name } end
    return { ok = true, msg = Locale.pointsSet:format(name, bal) }
end

function staffOps.staffOnline()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local ch = Desk.char(s)
        if ch then
            out[#out + 1] = { src = tonumber(s), charid = tonumber(ch.charIdentifier),
                name = Desk.trim((ch.firstname or '') .. ' ' .. (ch.lastname or '')), job = ch.job }
        end
    end
    table.sort(out, function(a, b) return a.src < b.src end)
    return { list = out }
end

-- what a staff member opened with /staffdesk (no desk needed for them)
local remote = {}

Core.Callback.Register('pup_staffdesk:panel', function(src, cb, d)
    d = type(d) == 'table' and d or {}
    if not Desk.char(src) then return cb(nil) end
    local staffOp = staffOps[d.op]
    if staffOp then
        if not Desk.isStaff(src) then return cb({ ok = false, msg = Locale.noAccess }) end
        return cb(staffOp(src, d))
    end
    local op = ops[d.op]
    if not op then return cb(nil) end
    -- players must stand at a desk; staff who opened it with the command need not
    if not Desk.atDesk(src) and not (remote[src] and Desk.isStaff(src)) then
        return cb({ ok = false, msg = Locale.notAtDesk })
    end
    local ok, res = pcall(op, src, d)
    if not ok then
        print('^1[pup_staffdesk]^7 ' .. tostring(res))
        return cb({ ok = false, msg = Locale.failed })
    end
    cb(res)
end)

RegisterNetEvent('pup_staffdesk:closed', function() remote[source] = nil end)
AddEventHandler('playerDropped', function() remote[source] = nil end)

-------------------------------------------------------------------------------
-- STAFF COMMANDS
-------------------------------------------------------------------------------
local Cmd = Config.Staff.commands

local function staffOnly(fn)
    return function(src, args)
        if not Desk.isStaff(src) then return Desk.tip(src, Locale.noAccess) end
        fn(src, args or {})
    end
end

RegisterCommand(Cmd.desk, staffOnly(function(src)
    if src == 0 then return end
    remote[src] = true
    TriggerClientEvent('pup_staffdesk:open', src, 'staff')
end))

-- /parcel <target> cash <amount> [note] | item <name> <count> [note] | weapon <HASH> [note]
local function parcelCommand(src, args, via)
    local target, kind = args[1], tostring(args[2] or ''):lower()
    local name, amount, noteAt
    if kind == 'cash' or kind == 'money' then amount, noteAt = args[3], 4
    elseif kind == 'item' then name, amount, noteAt = args[3], args[4] or 1, 5
    elseif kind == 'weapon' or kind == 'wep' then name, noteAt = args[3], 4 end
    if not target or not noteAt then return false, Locale.parcelUsage:format(Cmd.parcel) end

    local charid, discordid, why = Parcels.recipient(target)
    if why then return false, why end
    local note = table.concat(args, ' ', noteAt)
    local id, err = Parcels.send({ charid = charid, discordid = discordid, kind = kind, name = name, amount = amount,
        note = note, by = via or Desk.who(src) })
    if not id then return false, err end
    return true, Locale.sent:format(id)
end
Desk.parcelCommand = parcelCommand

RegisterCommand(Cmd.parcel, staffOnly(function(src, args)
    local ok, msg = parcelCommand(src, args)
    DeskDB.audit('game', Desk.who(src), 'parcel', table.concat(args, ' '), ok)
    Desk.tip(src, msg, 6000)
end))

RegisterCommand(Cmd.parcels, staffOnly(function(src, args)
    local rows = Parcels.pending(args[1] or '', 10)
    if #rows == 0 then return Desk.tip(src, Locale.nothingFound) end
    local parts = {}
    for _, p in ipairs(rows) do parts[#parts + 1] = ('#%d %s'):format(p.id, Parcels.describe(p)) end
    Desk.tip(src, table.concat(parts, ', '), 9000)
end))

-- /bounty add|take|check <charid> [points] [reason]
local function bountyCommand(src, verb, args)
    local charid = tonumber(args[1])
    if not charid then return Desk.tip(src, Locale.bountyUsage:format(Cmd.bounty)) end
    if verb == 'check' then
        local b = Bounty.balance(charid)
        return Desk.tip(src, Locale.bountyCheck:format(charid, b.points, b.earned, b.spent), 6000)
    end
    local n = math.abs(math.floor(tonumber(args[2]) or 0))
    if n == 0 then return Desk.tip(src, Locale.bountyUsage:format(Cmd.bounty)) end
    local bal, name = Bounty.change(charid, verb == 'take' and -n or n, table.concat(args, ' ', 3), Desk.who(src))
    DeskDB.audit('game', Desk.who(src), 'bounty', verb .. ' ' .. table.concat(args, ' '), bal ~= nil)
    Desk.tip(src, bal and Locale.pointsSet:format(name, bal) or name, 6000)
end

RegisterCommand(Cmd.bounty, staffOnly(function(src, args)
    local verb = tostring(args[1] or ''):lower()
    if verb ~= 'add' and verb ~= 'take' and verb ~= 'check' then return Desk.tip(src, Locale.bountyUsage:format(Cmd.bounty)) end
    bountyCommand(src, verb, { table.unpack(args, 2) })
end))

-- /rename <serverid> <first> <last>: free, no cooldown, for fixing names
local function staffRename(src, args)
    local target = tonumber(args[1])
    local ch = target and Desk.char(target)
    if not ch then return Desk.tip(src, Locale.notOnline) end
    local f, l = Changes.cleanName(args[2]), Changes.cleanName(args[3])
    if not f or not l then return Desk.tip(src, Locale.badName:format(Config.Rename.minLength, Config.Rename.maxLength)) end
    Changes.writeName(tonumber(ch.charIdentifier), ch, f, l)
    DeskDB.audit('game', Desk.who(src), 'rename', table.concat(args, ' '), true)
    Desk.log(Locale.logRename, ('%s renamed charid %s to **%s %s**'):format(Desk.whoLog(src), ch.charIdentifier, f, l))
    Desk.tip(src, Locale.renamed:format(f, l))
    if target ~= src then Desk.tip(target, Locale.renamed:format(f, l)) end
end
RegisterCommand(Cmd.rename, staffOnly(staffRename))

-- the older recomp-station commands, so staff habits keep working
if Config.Staff.legacyCommands then
    -- /recomp <discordid> <cash|item|weapon> <value> [count]
    RegisterCommand('recomp', staffOnly(function(src, args)
        local kind = tostring(args[2] or ''):lower()
        local mapped = kind == 'item' and { args[1], 'item', args[3], args[4] } or { args[1], kind, args[3] }
        local ok, msg = parcelCommand(src, mapped)
        DeskDB.audit('game', Desk.who(src), 'recomp', table.concat(args, ' '), ok)
        Desk.tip(src, msg, 6000)
    end))
    for _, name in ipairs({ 'addPoints', 'addpoints' }) do
        RegisterCommand(name, staffOnly(function(src, args)
            local n = math.floor(tonumber(args[2]) or 0)
            bountyCommand(src, n < 0 and 'take' or 'add', { args[1], tostring(math.abs(n)), table.unpack(args, 3) })
        end))
    end
    for _, name in ipairs({ 'removePoints', 'removepoints' }) do
        RegisterCommand(name, staffOnly(function(src, args) bountyCommand(src, 'take', args) end))
    end
    for _, name in ipairs({ 'checkPoints', 'checkpoints' }) do
        RegisterCommand(name, staffOnly(function(src, args) bountyCommand(src, 'check', args) end))
    end
    -- /modifyCharName is not registered here: vorp_core owns that command
end

RegisterCommand(Config.Playtime.command, function(src)
    if src == 0 then return end
    local s = Playtime.summary(src)
    if not s then return Desk.tip(src, Locale.noCharacter) end
    Desk.tip(src, Locale.playtimeMine:format(Desk.hours(s.mine)), 7000)
    if s.count > 1 then Desk.tip(src, Locale.playtimeAll:format(s.count, Desk.hours(s.total)), 7000) end
end)

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------
-- SendParcel({ charid = 12 | discordid = '...', kind = 'cash'|'item'|'weapon', name = 'bread', amount = 5, note = '', by = 'My Script' })
exports('SendParcel', function(t)
    if type(t) ~= 'table' then return nil, Locale.badTarget end
    t.origin = t.origin or GetInvokingResource() or 'export'
    return Parcels.send(t)
end)
exports('GetBountyPoints', function(charid) return Bounty.balance(tonumber(charid)).points end)
exports('AddBountyPoints', function(charid, delta, reason, by) return Bounty.change(charid, delta, reason, by or GetInvokingResource()) end)
exports('GetPlaytime', function(charid) return Playtime.of(charid) end)
-- rename whoever is on server id `src` (no price, no checks beyond a valid name)
exports('ModifyCharName', function(src, first, last)
    local ch = Desk.char(src)
    local f, l = Changes.cleanName(first), Changes.cleanName(last)
    if not ch or not f or not l then return false end
    Changes.writeName(tonumber(ch.charIdentifier), ch, f, l)
    return true
end)
