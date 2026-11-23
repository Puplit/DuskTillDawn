-- pup_staffdesk | Discord look-ups: read-only reports on a character, a business, a camp, a ranch
-- Each section is shown only when the tables behind it exist, so a server without
-- (say) a ranch resource simply gets no ranch section instead of an error.
local code, row, has = Bridge.code, Bridge.row, Desk.hasTable
local money = function(n) return '$' .. Desk.money(n) end

local function truthy(v) return v == 1 or v == true or v == '1' end
local function fullName(r) return Desk.trim((r.firstname or '?') .. ' ' .. (r.lastname or '')) end

-- a character from a charid or a Discord id (when that account has only one)
local function resolve(arg)
    local s = tostring(arg or ''):gsub('[<@!>]', '')
    if s:match('^%d+$') and #s >= 15 then
        local rows = MySQL.query.await('SELECT * FROM characters WHERE discordid = ? ORDER BY charidentifier', { s }) or {}
        if #rows == 0 then return nil, Locale.dNoDiscordChar:format(code(s)) end
        if #rows > 1 then
            local list = {}
            for _, r in ipairs(rows) do list[#list + 1] = ('%-6s %s'):format(r.charidentifier, fullName(r)) end
            return nil, Locale.dManyChars:format(#rows) .. '\n' .. Bridge.block(list)
        end
        return rows[1]
    end
    local id = tonumber(s)
    if not id then return nil, Locale.dCharArg end
    local r = MySQL.single.await('SELECT * FROM characters WHERE charidentifier = ?', { id })
    if not r then return nil, Locale.noSuchChar:format(id) end
    return r
end

-- ms or s epoch, or a date string
local function stamp(v)
    local n = tonumber(v)
    if not n or n <= 0 then return v and tostring(v) or '-' end
    if n > 1e12 then n = n / 1000 end
    return os.date('%Y-%m-%d %H:%M', math.floor(n))
end

local BRANCHES <const> = {
    { 'Valentine', 'valentine_money' }, { 'Blackwater', 'blackwater_money' }, { 'Saint Denis', 'saintdenis_money' },
    { 'Rhodes', 'rhodes_money' }, { 'Strawberry', 'strawberry_money' }, { 'Armadillo', 'armadillo_money' },
    { 'Annesburg', 'annesburg_money' },
}

-- money held in property ledgers, as lines + a total
local function ledgers(id)
    local lines, total = {}, 0
    if has('playershops') then
        for _, s in ipairs(MySQL.query.await('SELECT name, ledger FROM playershops WHERE charidentifier = ? AND owned = 1', { id }) or {}) do
            total = total + (tonumber(s.ledger) or 0)
            lines[#lines + 1] = row('Shop ' .. tostring(s.name), money(s.ledger), 22)
        end
    end
    if has('player_ranch') then
        for _, r in ipairs(MySQL.query.await('SELECT name, ledger FROM player_ranch WHERE charidentifier = ? AND owned = 1', { id }) or {}) do
            total = total + (tonumber(r.ledger) or 0)
            lines[#lines + 1] = row('Ranch ' .. tostring(r.name), money(r.ledger), 22)
        end
    end
    if has('playerhousing') then
        for _, h in ipairs(MySQL.query.await('SELECT id, type, ledger FROM playerhousing WHERE buyercharidentifier = ? AND owned = 1', { id }) or {}) do
            local v = tonumber(h.ledger) or 0
            if v ~= 0 then
                total = total + v
                lines[#lines + 1] = row(('%s #%s'):format(tonumber(h.type) == 1 and 'Room' or 'House', h.id), money(v), 22)
            end
        end
    end
    return lines, total
end

local function gangOf(id)
    if not (has('gang_members') and has('gangs')) then return nil end
    return MySQL.single.await('SELECT g.name, g.faction, g.money, g.bloodmoney, m.rank, m.points FROM gang_members m JOIN gangs g ON g.id = m.gangid WHERE m.charid = ? LIMIT 1', { id })
end

-------------------------------------------------------------------------------
Bridge.add('bank', { group = 'LOOK UP', usage = '<charid|discord>', help = 'Cash, bank branches and ledgers', audit = false }, function(a, who)
    local c, why = resolve(a[2])
    if not c then return false, why end
    local id = tonumber(c.charidentifier)
    local cash = tonumber(c.money) or 0
    local fields = { { name = 'On hand', inline = true, value = Bridge.block({
        row('Cash', money(cash)), row('Gold', ('%.2f'):format(tonumber(c.gold) or 0)), row('Rol', ('%.2f'):format(tonumber(c.rol) or 0)) }) } }

    local banked = 0
    if has('bank_users') then
        local b = MySQL.single.await('SELECT * FROM bank_users WHERE charidentifier = ? LIMIT 1', { id })
        local lines = {}
        for _, br in ipairs(BRANCHES) do
            local v = b and tonumber(b[br[2]]) or 0
            banked = banked + v
            lines[#lines + 1] = row(br[1], money(v))
        end
        lines[#lines + 1] = row('TOTAL', money(banked))
        -- the stored total can drift from the branches; worth seeing when it does
        if b and math.abs((tonumber(b.total_money) or 0) - banked) > 0.01 then lines[#lines + 1] = row('stored', money(b.total_money) .. '  (drifted)') end
        if not b then lines[#lines + 1] = '(no bank account)' end
        fields[#fields + 1] = { name = 'Bank', inline = true, value = Bridge.block(lines) }
    end

    local led, held = ledgers(id)
    fields[#fields + 1] = { name = 'Property ledgers', value = Bridge.block(led, 'none') }
    fields[#fields + 1] = { name = 'Total', value = '**' .. money(cash + banked + held) .. '**' }
    local g = gangOf(id)
    if g then fields[#fields + 1] = { name = 'Gang funds (not theirs)', value = Bridge.block({ row(g.name, money(g.money)), row('blood money', money(g.bloodmoney)) }) } end

    Bridge.embed({ title = ('Money - %s (charid %d)'):format(fullName(c), id), color = 15844367, fields = fields, footer = { text = 'asked by ' .. who } })
end)

-------------------------------------------------------------------------------
Bridge.add('info', { group = 'LOOK UP', usage = '<charid|discord>', help = 'Character sheet and what they own', audit = false }, function(a, who)
    local c, why = resolve(a[2])
    if not c then return false, why end
    local id = tonumber(c.charidentifier)

    local identity = {
        row('Name', fullName(c)), row('Charid', id), row('Gender', c.gender or '-'), row('Age', c.age or '-'),
        row('Group', c.group or 'user'), row('Steam', c.steamname or '-'),
    }
    local standing = {
        row('Job', ('%s (grade %s)'):format(c.job or 'unemployed', c.jobgrade or 0)),
        row('Playtime', Desk.hours(Playtime.of(id))),
        row('State', truthy(c.isdead) and 'DEAD' or 'alive'),
        row('Created', stamp(c.character_created)), row('Last seen', stamp(c.LastLogin)),
        row('Bounty pts', Bounty.balance(id).points),
    }
    local fields = {
        { name = 'Identity', value = Bridge.block(identity), inline = true },
        { name = 'Standing', value = Bridge.block(standing), inline = true },
    }

    local own = {}
    if has('playerhousing') then
        for _, h in ipairs(MySQL.query.await('SELECT id, type, motel, invspace FROM playerhousing WHERE buyercharidentifier = ? AND owned = 1 ORDER BY type, id', { id }) or {}) do
            own[#own + 1] = tonumber(h.type) == 1 and ('Room   #%s %s'):format(h.id, h.motel or '') or ('House  #%s (%s slots)'):format(h.id, h.invspace or 0)
        end
    end
    if has('playershops') then
        for _, s in ipairs(MySQL.query.await('SELECT name, level FROM playershops WHERE charidentifier = ? AND owned = 1', { id }) or {}) do
            own[#own + 1] = ('Shop   %s (level %s)'):format(s.name or '?', s.level or 0)
        end
    end
    if has('player_ranch') then
        for _, r in ipairs(MySQL.query.await('SELECT name FROM player_ranch WHERE charidentifier = ? AND owned = 1', { id }) or {}) do
            own[#own + 1] = 'Ranch  ' .. tostring(r.name)
        end
    end
    if has('clan') then
        -- camp membership sits inside each camp's info json
        for _, cr in ipairs(MySQL.query.await('SELECT id, info FROM clan') or {}) do
            local ok, inf = pcall(json.decode, cr.info or '{}')
            if ok and type(inf) == 'table' then
                for _, m in ipairs(inf.members or {}) do
                    if tonumber(m.charid) == id then
                        own[#own + 1] = ('Camp   %s%s'):format(inf.name or ('#' .. cr.id), tonumber(inf.leader) == id and ' (leader)' or '')
                        break
                    end
                end
            end
        end
    end
    Bridge.fields(fields, 'Property', own, 'owns nothing')

    local stock = {}
    if has('stable_horses') then
        for _, h in ipairs(MySQL.query.await('SELECT name, isDead FROM stable_horses WHERE charid = ?', { id }) or {}) do
            stock[#stock + 1] = ('Horse  %s%s'):format(h.name or '?', truthy(h.isDead) and ' (dead)' or '')
        end
    end
    if has('stable_wagons') then
        for _, w in ipairs(MySQL.query.await('SELECT name, model FROM stable_wagons WHERE charid = ?', { id }) or {}) do
            stock[#stock + 1] = ('Wagon  %s %s'):format(w.name or '?', w.model or '')
        end
    end
    if #stock > 0 then Bridge.fields(fields, 'Horses and wagons', stock) end

    local g = gangOf(id)
    if g then fields[#fields + 1] = { name = 'Gang', inline = true, value = Bridge.block({ row('Gang', g.name), row('Faction', g.faction or '-'), row('Rank', g.rank or 0), row('Points', g.points or 0) }) } end
    if has('perks') then
        local pk = MySQL.single.await('SELECT civxp, crimexp, bonuspoints FROM perks WHERE charidentifier = ? LIMIT 1', { id })
        if pk then fields[#fields + 1] = { name = 'Perks', inline = true, value = Bridge.block({ row('Civ XP', pk.civxp or 0), row('Crime XP', pk.crimexp or 0), row('Spare pts', pk.bonuspoints or 0) }) } end
    end
    local waiting = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM staffdesk_parcels WHERE claimed_at IS NULL AND cancelled_at IS NULL AND charid = ?', { id })) or 0
    if waiting > 0 then fields[#fields + 1] = { name = 'Parcels waiting', inline = true, value = Bridge.block(tostring(waiting)) } end

    Bridge.embed({ title = ('%s (charid %d)'):format(fullName(c), id), color = 3447003,
        description = (c.discordid and c.discordid ~= '') and ('<@%s>'):format(c.discordid) or nil,
        fields = fields, footer = { text = 'asked by ' .. who } })
end)

-------------------------------------------------------------------------------
Bridge.add('inv', { group = 'LOOK UP', usage = '<charid|discord>', help = 'What they carry, and their weapons', audit = false }, function(a, who)
    local c, why = resolve(a[2])
    if not c then return false, why end
    local id = tonumber(c.charidentifier)

    -- the running inventory when they are online: the database copy lags a logged-in player
    local lines, total, from = {}, 0, 'saved copy (offline)'
    local s = Desk.sourceOfChar(id)
    local live = s and exports.vorp_inventory:getUserInventoryItems(s)
    if type(live) == 'table' then
        local counts, labels = {}, {}
        for _, it in pairs(live) do
            local n = tonumber(it.count) or 0
            if it.name and n > 0 then counts[it.name] = (counts[it.name] or 0) + n labels[it.name] = it.label end
        end
        local names = {}
        for n in pairs(counts) do names[#names + 1] = n end
        table.sort(names, function(x, y) if counts[x] ~= counts[y] then return counts[x] > counts[y] end return x < y end)
        for _, n in ipairs(names) do
            total = total + counts[n]
            lines[#lines + 1] = ('%5dx %s'):format(counts[n], labels[n] or n)
        end
        from = 'live'
    elseif has('character_inventories') then
        for _, r in ipairs(MySQL.query.await([[SELECT ci.item_name, ci.amount, i.label FROM character_inventories ci
            LEFT JOIN items i ON i.item = ci.item_name WHERE ci.character_id = ? AND ci.inventory_type = 'default' AND ci.amount > 0
            ORDER BY ci.amount DESC, ci.item_name]], { id }) or {}) do
            total = total + (tonumber(r.amount) or 0)
            lines[#lines + 1] = ('%5dx %s'):format(tonumber(r.amount) or 0, r.label or r.item_name)
        end
    end

    -- the same rule vorp uses to put a weapon in a satchel: owner, character, place and not dropped all match
    local weps = {}
    for _, w in ipairs(MySQL.query.await([[SELECT l.name, l.label, l.custom_label, l.serial_number FROM loadout l
        JOIN characters c ON c.charidentifier = l.charidentifier
        WHERE l.charidentifier = ? AND l.dropped = 0 AND l.curr_inv = 'default' AND l.identifier = c.identifier ORDER BY l.name]], { id }) or {}) do
        local label = (w.custom_label and w.custom_label ~= '' and w.custom_label) or w.label or Config.WeaponLabels[w.name] or w.name
        weps[#weps + 1] = ('%-26s %s'):format(label, w.serial_number or '')
    end

    local stores = {}
    if has('character_inventories') then
        for _, r in ipairs(MySQL.query.await([[SELECT inventory_type, COUNT(*) AS kinds, COALESCE(SUM(amount), 0) AS total
            FROM character_inventories WHERE character_id = ? AND inventory_type <> 'default' AND amount > 0 GROUP BY inventory_type]], { id }) or {}) do
            stores[#stores + 1] = ('%-18s %s kinds / %s items'):format(r.inventory_type, r.kinds, math.floor(tonumber(r.total) or 0))
        end
    end

    local fields = {}
    Bridge.fields(fields, 'Carried', lines, 'empty pockets')
    Bridge.fields(fields, 'Weapons', weps, 'unarmed')
    Bridge.fields(fields, 'Storages', stores, 'none')
    Bridge.embed({ title = ('Inventory - %s (charid %d)'):format(fullName(c), id), color = 10181046,
        description = ('%d kinds, %d items, %d weapons (%s)'):format(#lines, total, #weps, from),
        fields = fields, footer = { text = 'asked by ' .. who } })
end)

-------------------------------------------------------------------------------
Bridge.add('society', { group = 'ORGANISATIONS', usage = '[job]', help = 'Businesses, ledgers and staff', audit = false }, function(a, who)
    if not has('society_business') then return false, Locale.dNoResource:format('business') end
    local q = Desk.trim(table.concat(a, ' ', 2))
    local hasLedger = has('society_ledger')
    if q == '' then
        local lines = {}
        local rows = MySQL.query.await([[SELECT b.job, b.name, (SELECT COUNT(*) FROM characters c WHERE c.job = b.job) AS staff
            FROM society_business b ORDER BY b.name]]) or {}
        for _, r in ipairs(rows) do
            local led = hasLedger and MySQL.scalar.await('SELECT ledger FROM society_ledger WHERE job = ? LIMIT 1', { r.job }) or 0
            lines[#lines + 1] = ('%-30s %-14s %3s staff  %s'):format(tostring(r.name or r.job):sub(1, 30), r.job, r.staff, money(led))
        end
        local fields = {}
        Bridge.fields(fields, 'Businesses', lines, 'none')
        return Bridge.embed({ title = ('Businesses (%d)'):format(#rows), description = code(Bridge.prefix() .. 'society <job>') .. ' for one',
            fields = fields, footer = { text = 'asked by ' .. who } })
    end
    local b = MySQL.single.await('SELECT * FROM society_business WHERE job = ? OR name LIKE ? LIMIT 1', { q, '%' .. q .. '%' })
    if not b then return false, Locale.dNoBusiness:format(code(q)) end
    local led = hasLedger and MySQL.scalar.await('SELECT ledger FROM society_ledger WHERE job = ? LIMIT 1', { b.job }) or 0
    local boss = tonumber(b.bossrank) or 0
    local staff, bosses = {}, {}
    for _, s in ipairs(MySQL.query.await('SELECT charidentifier, firstname, lastname, jobgrade FROM characters WHERE job = ? ORDER BY jobgrade DESC', { b.job }) or {}) do
        local line = ('%-24s #%-6s grade %s'):format(fullName(s):sub(1, 24), s.charidentifier, s.jobgrade or 0)
        staff[#staff + 1] = line
        if boss > 0 and (tonumber(s.jobgrade) or 0) >= boss then bosses[#bosses + 1] = line end
    end
    local fields = { { name = 'Business', value = Bridge.block({
        row('Job', b.job), row('Ledger', money(led)), row('Boss rank', b.bossrank or '-'), row('Recruit at', b.recruitmentrank or '-'),
        row('Salary', money(b.salary)), row('Tax', tostring(b.tax or 0) .. '%'), row('Staff', #staff) }) } }
    Bridge.fields(fields, 'Bosses', bosses, 'nobody at boss rank')
    Bridge.fields(fields, 'Staff', staff, 'nobody employed')
    Bridge.embed({ title = tostring(b.name or b.job), color = 3447003, fields = fields, footer = { text = 'asked by ' .. who } })
end)

-------------------------------------------------------------------------------
Bridge.add('camp', { group = 'ORGANISATIONS', usage = '[id]', help = 'Camps, members and supplies', audit = false }, function(a, who)
    if not has('clan') then return false, Locale.dNoResource:format('camps') end
    local camps = {}
    for _, r in ipairs(MySQL.query.await('SELECT id, info, cash, invlimit FROM clan ORDER BY id') or {}) do
        local ok, inf = pcall(json.decode, r.info or '{}')
        if ok and type(inf) == 'table' then camps[#camps + 1] = { id = tonumber(r.id), cash = r.cash, invlimit = r.invlimit, i = inf } end
    end
    local want = tonumber(a[2])
    if not want then
        local lines = {}
        for _, c in ipairs(camps) do lines[#lines + 1] = ('#%-5s %-24s %2d members  %s'):format(c.id, tostring(c.i.name or 'unnamed'):sub(1, 24), #(c.i.members or {}), money(c.cash)) end
        local fields = {}
        Bridge.fields(fields, 'Camps', lines, 'no camps')
        return Bridge.embed({ title = ('Camps (%d)'):format(#camps), description = code(Bridge.prefix() .. 'camp <id>') .. ' for one',
            color = 10181046, fields = fields, footer = { text = 'asked by ' .. who } })
    end
    local c
    for _, x in ipairs(camps) do if x.id == want then c = x break end end
    if not c then return false, Locale.dNoCamp:format(want) end
    local members, leader = {}, nil
    for _, m in ipairs(c.i.members or {}) do
        local isLeader = tonumber(m.charid) == tonumber(c.i.leader)
        if isLeader then leader = m.name end
        members[#members + 1] = ('%-24s #%-6s%s'):format(tostring(m.name or '?'):sub(1, 24), m.charid, isLeader and ' LEADER' or '')
    end
    local fields = { { name = 'Camp', value = Bridge.block({
        row('Camp id', c.id), row('Leader', leader or ('#' .. tostring(c.i.leader or '?'))), row('Cash', money(c.cash)),
        row('Stock', ('%s / %s'):format(c.i.stock or 0, c.i.maxstock or 0)), row('Supply', c.i.supply or 0), row('Material', c.i.material or 0),
        row('Stew', c.i.stewlevel or 0), row('Inv limit', c.invlimit or 0) }) } }
    Bridge.fields(fields, 'Members', members, 'nobody')
    Bridge.embed({ title = tostring(c.i.name or ('Camp #' .. c.id)), color = 10181046, fields = fields, footer = { text = 'asked by ' .. who } })
end)

-------------------------------------------------------------------------------
Bridge.add('ranch', { group = 'ORGANISATIONS', usage = '[charid]', help = 'Ranches, ledgers and herd stats', audit = false }, function(a, who)
    if not has('player_ranch') then return false, Locale.dNoResource:format('ranches') end
    local want = tonumber(a[2])
    if not want then
        local lines = {}
        local rows = MySQL.query.await([[SELECT r.name, r.ledger, r.charidentifier, c.firstname, c.lastname FROM player_ranch r
            LEFT JOIN characters c ON c.charidentifier = r.charidentifier WHERE r.owned = 1 ORDER BY r.id]]) or {}
        for _, r in ipairs(rows) do lines[#lines + 1] = ('%-22s %-22s #%-6s %s'):format(tostring(r.name):sub(1, 22), fullName(r):sub(1, 22), r.charidentifier, money(r.ledger)) end
        local fields = {}
        Bridge.fields(fields, 'Ranches', lines, 'none owned')
        return Bridge.embed({ title = ('Ranches (%d)'):format(#rows), description = code(Bridge.prefix() .. 'ranch <charid>') .. ' for one',
            color = 5763719, fields = fields, footer = { text = 'asked by ' .. who } })
    end
    local r = MySQL.single.await('SELECT * FROM player_ranch WHERE charidentifier = ? AND owned = 1 LIMIT 1', { want })
    if not r then return false, Locale.dNoRanch:format(want) end
    local owner = MySQL.single.await('SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { want })
    local fields = { { name = 'Ranch', value = Bridge.block({
        row('Ranch', r.name or '?'), row('Owner', owner and fullName(owner) or '?'), row('Charid', want),
        row('Ledger', money(r.ledger)), row('Milk', r.milk or 0), row('Eggs', r.eggs or 0), row('Tax', r.tax or 0) }) } }
    if has('ranch_stats') then
        local st = MySQL.single.await('SELECT milk, eggs, chores, herds, herd_animals, cattle_money FROM ranch_stats WHERE charid = ? LIMIT 1', { want })
        if st then fields[#fields + 1] = { name = 'Lifetime', value = Bridge.block({
            row('Milk', st.milk or 0), row('Eggs', st.eggs or 0), row('Chores', st.chores or 0), row('Herds', st.herds or 0),
            row('Herd animals', st.herd_animals or 0), row('Cattle money', money(st.cattle_money)) }) } end
    end
    Bridge.embed({ title = tostring(r.name or 'Ranch'), color = 5763719, fields = fields, footer = { text = 'asked by ' .. who } })
end)
