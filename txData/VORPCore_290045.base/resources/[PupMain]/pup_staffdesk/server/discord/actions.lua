-- pup_staffdesk | Discord commands that DO something: give, parcel, move, heal, kick, jobs, names, points
local Core = Desk.Core
local code = Bridge.code

-- an online player by server id -> { src, char } or nil, why
local function online(id)
    id = tonumber(id)
    if not id then return nil, Locale.dServerId end
    if not GetPlayerName(id) then return nil, Locale.dNobody:format(id) end
    local ch = Desk.char(id)
    if not ch then return nil, Locale.dNoChar:format(id) end
    return { src = id, char = ch, name = GetPlayerName(id) }
end

local function usage(name)
    local c = Bridge.commands[name]
    return Locale.dUsage:format(code(Bridge.prefix() .. name .. (c.usage ~= '' and (' ' .. c.usage) or '')))
end

-------------------------------------------------------------------------------
-- HELP
-------------------------------------------------------------------------------
Bridge.add('help', { group = 'OTHER', help = 'This list', audit = false }, function(_, who)
    local groups, order = {}, {}
    local wName, wArgs = 0, 0
    local pfx = Bridge.prefix()
    for _, n in ipairs(Bridge.order) do
        local c = Bridge.commands[n]
        if not groups[c.group] then groups[c.group] = {} order[#order + 1] = c.group end
        table.insert(groups[c.group], n)
        wName = math.max(wName, #(pfx .. n))
        wArgs = math.max(wArgs, #c.usage)
    end
    local fields = {}
    for _, g in ipairs(order) do
        local lines = {}
        for _, n in ipairs(groups[g]) do
            local c = Bridge.commands[n]
            lines[#lines + 1] = (('%-' .. wName .. 's  %-' .. wArgs .. 's  %s'):format(pfx .. n, c.usage, c.help):gsub('%s+$', ''))
        end
        Bridge.fields(fields, g, lines)
    end
    local spots = {}
    for k in pairs(Config.Discord.spots or {}) do spots[#spots + 1] = k end
    table.sort(spots)
    if #spots > 0 then fields[#fields + 1] = { name = 'TELEPORT SPOTS', value = Bridge.block(table.concat(spots, ', ')) } end
    Bridge.embed({ title = 'Staff Desk commands', description = 'Example: ' .. code(pfx .. 'kick 3 combat logging'),
        fields = fields, footer = { text = 'asked by ' .. who } })
end)

-------------------------------------------------------------------------------
-- PARCELS AND POINTS
-------------------------------------------------------------------------------
Bridge.add('parcel', { group = 'PARCELS', usage = '<charid|discord> <cash|item|weapon> ...', help = 'Leave something at the desk' },
    function(a, who)
        local ok, msg = Desk.parcelCommand(0, { table.unpack(a, 2) }, who)
        if not ok and msg == Locale.parcelUsage:format(Config.Staff.commands.parcel) then
            return false, usage('parcel') .. '\n' .. code('cash <amount> [note]') .. ' / ' .. code('item <name> <count> [note]') .. ' / ' .. code('weapon <HASH> [note]')
        end
        return ok, msg
    end)

-- older wording: recomp <discordid> <cash|item|weapon> <value> [count]
Bridge.add('recomp', { group = 'PARCELS', usage = '<discord> <type> <value> [count]', help = 'Old name for parcel' }, function(a, who)
    local kind = tostring(a[3] or ''):lower()
    local mapped = kind == 'item' and { a[2], 'item', a[4], a[5] } or { a[2], kind, a[4] }
    return Desk.parcelCommand(0, mapped, who)
end)

Bridge.add('parcels', { group = 'PARCELS', usage = '[charid|discord|word]', help = 'What is waiting to be collected', audit = false }, function(a, who)
    local rows = Parcels.pending(table.concat(a, ' ', 2), 60)
    local lines = {}
    for _, p in ipairs(rows) do
        lines[#lines + 1] = ('#%-5d %-10s %-28s %s'):format(p.id, p.charid and ('char ' .. p.charid) or 'discord', Parcels.describe(p):sub(1, 28), (p.note or ''):sub(1, 30))
    end
    local fields = {}
    Bridge.fields(fields, 'Waiting', lines, 'nothing waiting')
    Bridge.embed({ title = ('Parcels (%d)'):format(#rows), description = 'Cancel one with ' .. code(Bridge.prefix() .. 'cancel <id>'),
        fields = fields, footer = { text = 'asked by ' .. who } })
end)

Bridge.add('cancel', { group = 'PARCELS', usage = '<parcel id>', help = 'Take a parcel back' }, function(a, who)
    if not tonumber(a[2]) then return false, usage('cancel') end
    return Parcels.cancel(a[2], who)
end)

Bridge.add('points', { group = 'PARCELS', usage = '<charid> [+n|-n] [reason]', help = 'Bug bounty points: check, give or take' }, function(a, who)
    local charid = tonumber(a[2])
    if not charid then return false, usage('points') end
    local n = tonumber(a[3])
    if not n then
        local b = Bounty.balance(charid)
        return true, Locale.bountyCheck:format(charid, b.points, b.earned, b.spent)
    end
    local bal, name = Bounty.change(charid, n, table.concat(a, ' ', 4), who)
    if not bal then return false, name end
    return true, Locale.pointsSet:format(name, bal)
end)

-------------------------------------------------------------------------------
-- GIVE STRAIGHT AWAY  (the player must be online)
-------------------------------------------------------------------------------
Bridge.add('givecash', { group = 'GIVE NOW', usage = '<id> <amount>', help = 'Cash into their pocket' }, function(a, who)
    local p, why = online(a[2])
    if not p then return false, why end
    local amount = Desk.cents(a[3])
    if not amount or amount <= 0 or amount > Config.Parcels.maxCash then return false, usage('givecash') end
    p.char.addCurrency(0, amount)
    Desk.log('Cash Given', ('$%s given to %s\n\n**Executed by:** %s'):format(Desk.money(amount), Desk.whoLog(p.src), who), 3066993)
    return true, ('gave $%s to %s (%d)'):format(Desk.money(amount), p.name, p.src)
end)

Bridge.add('giveitem', { group = 'GIVE NOW', usage = '<id> <item> [count]', help = 'An item into their satchel' }, function(a, who)
    local p, why = online(a[2])
    if not p then return false, why end
    local count = math.floor(tonumber(a[4]) or 1)
    local label = Desk.itemLabel(a[3])
    if not label then return false, Locale.noSuchItem:format(tostring(a[3])) end
    if count < 1 or count > Config.Parcels.maxItems then return false, Locale.badCount:format(Config.Parcels.maxItems) end
    if not exports.vorp_inventory:canCarryItem(p.src, a[3], count) then return false, Locale.dCantCarry:format(p.name) end
    exports.vorp_inventory:addItem(p.src, a[3], count)
    Desk.log('Item Given', ('%dx %s given to %s\n\n**Executed by:** %s'):format(count, label, Desk.whoLog(p.src), who), 3066993)
    return true, ('gave %dx %s to %s (%d)'):format(count, label, p.name, p.src)
end)

Bridge.add('givewep', { group = 'GIVE NOW', usage = '<id> <WEAPON_HASH>', help = 'A weapon into their satchel' }, function(a, who)
    local p, why = online(a[2])
    if not p then return false, why end
    local hash, label = Desk.weapon(a[3])
    if not hash then return false, Locale.noSuchWeapon:format(tostring(a[3])) end
    if not exports.vorp_inventory:canCarryWeapons(p.src, 1, nil, hash) then return false, Locale.dCantCarry:format(p.name) end
    exports.vorp_inventory:createWeapon(p.src, hash, {}, {})
    Desk.log('Weapon Given', ('%s given to %s\n\n**Executed by:** %s'):format(label, Desk.whoLog(p.src), who), 3066993)
    return true, ('gave %s to %s (%d)'):format(label, p.name, p.src)
end)

-------------------------------------------------------------------------------
-- PLAYER
-------------------------------------------------------------------------------
Bridge.add('online', { group = 'PLAYER', help = 'Who is on, with server id and charid', audit = false }, function(_, who)
    local lines = {}
    for _, s in ipairs(GetPlayers()) do
        local ch = Desk.char(s)
        lines[#lines + 1] = ch and ('%-4s #%-6s %-24s %s'):format(s, ch.charIdentifier, Desk.trim((ch.firstname or '') .. ' ' .. (ch.lastname or '')):sub(1, 24), ch.job or '')
            or ('%-4s %s (choosing a character)'):format(s, GetPlayerName(s) or '?')
    end
    local fields = {}
    Bridge.fields(fields, 'Online', lines, 'nobody')
    Bridge.embed({ title = ('Online (%d)'):format(#lines), fields = fields, footer = { text = 'asked by ' .. who } })
end)

Bridge.add('res', { group = 'PLAYER', usage = '<id>', help = 'Revive them' }, function(a, who)
    local p, why = online(a[2])
    if not p then return false, why end
    Core.Player.Revive(p.src, true)
    Desk.log('Player Revived', ('%s was revived\n\n**Executed by:** %s'):format(Desk.whoLog(p.src), who))
    return true, ('revived %s (%d)'):format(p.name, p.src)
end)

Bridge.add('hp', { group = 'PLAYER', usage = '<id>', help = 'Heal them to full' }, function(a, who)
    local p, why = online(a[2])
    if not p then return false, why end
    Core.Player.Heal(p.src)
    Desk.log('Player Healed', ('%s was healed\n\n**Executed by:** %s'):format(Desk.whoLog(p.src), who))
    return true, ('healed %s (%d)'):format(p.name, p.src)
end)

Bridge.add('tp', { group = 'PLAYER', usage = '<id> <spot|x y z [h]>', help = 'Move them (with their horse or wagon)' }, function(a, who)
    local p, why = online(a[2])
    if not p then return false, why end
    local x, y, z, h, where = tonumber(a[3]), tonumber(a[4]), tonumber(a[5]), tonumber(a[6]), nil
    if x and y and z then
        where = ('%.1f, %.1f, %.1f'):format(x, y, z)
    else
        local spot = (Config.Discord.spots or {})[tostring(a[3] or ''):lower()]
        if not spot then
            local names = {}
            for k in pairs(Config.Discord.spots or {}) do names[#names + 1] = k end
            table.sort(names)
            return false, usage('tp') .. '\nspots: ' .. table.concat(names, ', ')
        end
        x, y, z, h, where = spot[1] or spot.x, spot[2] or spot.y, spot[3] or spot.z, spot[4] or spot.h, a[3]:lower()
    end
    TriggerClientEvent('pup_staffdesk:teleport', p.src, x, y, z, h)
    Desk.log('Player Teleported', ('%s was moved to %s\n\n**Executed by:** %s'):format(Desk.whoLog(p.src), where, who))
    return true, ('moved %s (%d) to %s'):format(p.name, p.src, where)
end)

Bridge.add('kick', { group = 'PLAYER', usage = '<id> [reason]', help = 'Kick them off the server' }, function(a, who)
    local p, why = online(a[2])
    if not p then return false, why end
    local reason = table.concat(a, ' ', 3)
    if reason == '' then reason = 'No reason given' end
    DropPlayer(tostring(p.src), 'Kicked: ' .. reason)
    Desk.log('Kicked', ('%s - %s - by %s'):format(p.name, reason, who), 15158332)
    return true, ('kicked %s (%d): %s'):format(p.name, p.src, reason)
end)

-- the job must be one a business resource knows about (when one is installed), and the grade must exist
Bridge.add('setjob', { group = 'PLAYER', usage = '<id> <job> [grade]', help = 'Set their job and grade' }, function(a, who)
    local p, why = online(a[2])
    if not p then return false, why end
    local job = a[3] and a[3]:lower()
    local grade = tonumber(a[4]) or 0
    if not job then return false, usage('setjob') end
    if grade < 0 or grade ~= math.floor(grade) then return false, Locale.dGrade end
    local label = job
    if job ~= 'unemployed' and Desk.hasTable('society_business') then
        local b = MySQL.single.await('SELECT name FROM society_business WHERE job = ?', { job })
        if not b then return false, Locale.dNoJob:format(code(job), code(Bridge.prefix() .. 'society')) end
        label = b.name or job
        if Desk.hasTable('society_ranks') then
            local top = tonumber(MySQL.scalar.await('SELECT MAX(grade) FROM society_ranks WHERE job = ?', { job }))
            if top and grade > top then return false, Locale.dTopGrade:format(label, top) end
        end
    end
    p.char.setJob(job)
    p.char.setJobGrade(grade)
    -- the setters only change the live character, so write it through too
    MySQL.update.await('UPDATE characters SET job = ?, jobgrade = ? WHERE charidentifier = ?', { job, grade, p.char.charIdentifier })
    Desk.log('Job Set', ('%s is now %s (grade %d)\n\n**Executed by:** %s'):format(Desk.whoLog(p.src), label, grade, who))
    return true, ('%s (%d) is now %s grade %d'):format(p.name, p.src, label, grade)
end)

-- the old name is required, so a typo never renames the wrong character
Bridge.add('namechange', { group = 'PLAYER', usage = '<charid|discord> <oldfirst> <oldlast> <newfirst> <newlast>', help = 'Rename a character' }, function(a, who)
    local key = tostring(a[2] or '')
    if not (key:match('^%d+$') and a[6]) then return false, usage('namechange') end
    local row
    if #key >= 15 then -- a Discord id: the old name picks which of their characters
        row = MySQL.single.await('SELECT charidentifier, firstname, lastname FROM characters WHERE discordid = ? AND firstname = ? AND lastname = ?', { key, a[3], a[4] })
        if not row then return false, Locale.dNoNamed:format(a[3], a[4], key) end
    else
        row = MySQL.single.await('SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier = ?', { tonumber(key) })
        if not row then return false, Locale.noSuchChar:format(key) end
    end
    local charid = tonumber(row.charidentifier)
    if tostring(row.firstname):lower() ~= a[3]:lower() or tostring(row.lastname):lower() ~= a[4]:lower() then
        return false, Locale.dOldName:format(charid, row.firstname, row.lastname)
    end
    local f, l = Changes.cleanName(a[5]), Changes.cleanName(a[6])
    if not f or not l then return false, Locale.badName:format(Config.Rename.minLength, Config.Rename.maxLength) end
    local s = Desk.sourceOfChar(charid)
    Changes.writeName(charid, s and Desk.char(s), f, l)
    Desk.log(Locale.logRename, ('%s %s is now **%s %s** (charid %d, by %s)'):format(row.firstname, row.lastname, f, l, charid, who))
    return true, ('renamed %s %s -> %s %s%s'):format(row.firstname, row.lastname, f, l, s and ' (live)' or '')
end)

Bridge.add('playtime', { group = 'LOOK UP', usage = '<charid>', help = 'Hours played on a character', audit = false }, function(a)
    local charid = tonumber(a[2])
    if not charid then return false, usage('playtime') end
    return true, ('charid %d has played %s'):format(charid, Desk.hours(Playtime.of(charid)))
end)

Bridge.add('audit', { group = 'OTHER', usage = '[count]', help = 'The last commands run here and in game', audit = false }, function(a, who)
    local n = math.min(math.max(math.floor(tonumber(a[2]) or 15), 1), 40)
    local lines = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM staffdesk_audit ORDER BY id DESC LIMIT ' .. n) or {}) do
        lines[#lines + 1] = ('%s %s %-8s %-10s %s'):format(os.date('%d/%m %H:%M', tonumber(r.at)), (tonumber(r.ok) == 1) and ' ' or 'X',
            tostring(r.via), tostring(r.command), (tostring(r.actor) .. ': ' .. tostring(r.args)):sub(1, 60))
    end
    local fields = {}
    Bridge.fields(fields, 'Recent', lines, 'nothing logged yet')
    Bridge.embed({ title = 'Audit', fields = fields, footer = { text = 'asked by ' .. who } })
end)
