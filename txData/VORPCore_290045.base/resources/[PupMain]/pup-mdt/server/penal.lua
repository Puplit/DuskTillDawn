-- pup-mdt | penal code, arrests, fines

Penal = { arrestCooldown = {} }

local function decodeRow(r)
    r.burdens = MDT.jdec(r.burdens, {})
    r.definitions = MDT.jdec(r.definitions, {})
    r.tiers = MDT.jdec(r.tiers, {})
    r.months = tonumber(r.months) or 0
    r.fine = tonumber(r.fine) or 0
    return r
end

-- every charge, cached 5 minutes
function Penal.all()
    local c = Cache.get('penal')
    if c then return c end
    local rows = DB.q('SELECT code, label, charge_class, months, fine, color, description, category, burdens, definitions, tiers FROM mdt_penal_codes ORDER BY code ASC')
    for _, r in ipairs(rows) do decodeRow(r) end
    Cache.set('penal', rows, 300)
    return rows
end

function Penal.byCode()
    local map = {}
    for _, r in ipairs(Penal.all()) do map[r.code] = r end
    return map
end

MDT.rpc('getPenalCodes', { perm = 'criminals', staff = true, deny = {} }, function()
    return Penal.all()
end)

MDT.rpc('savePenalCode', { perm = 'managecharges', law = true, duty = true }, function(actor, p)
    local code = MDT.str(p.code, 20)
    local label = MDT.str(p.label, 100)
    if code == '' or label == '' then return { success = false, message = L('pc_required') } end
    local class = MDT.enum(p.charge_class, { 'felony', 'misdemeanor', 'infraction' }, 'misdemeanor')
    local color = MDT.enum(p.color, { 'green', 'orange', 'red' }, 'green')
    local months = MDT.int(p.months, 0, Config.Jail.maxMinutes, 0)
    local fine = MDT.int(p.fine, 0, 10000000, 0)
    -- New Charge never overwrites an existing code
    if MDT.bool(p.isNew) and DB.val('SELECT code FROM mdt_penal_codes WHERE code = ?', { code }) ~= nil then
        return { success = false, message = L('pc_exists', code) }
    end
    DB.q([[INSERT INTO mdt_penal_codes (code, label, charge_class, months, fine, color, description) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), charge_class = VALUES(charge_class), months = VALUES(months),
        fine = VALUES(fine), color = VALUES(color), description = VALUES(description)]],
        { code, label, class, months, fine, color, MDT.str(p.description, 255) })
    Cache.clear('penal')
    MDT.audit(actor, 'penal_code_saved', nil, nil, ('%s %s: $%d, %d months'):format(code, label, fine, months))
    return { success = true }
end)

MDT.rpc('deletePenalCode', { perm = 'managecharges', law = true, duty = true }, function(actor, p)
    local code = MDT.str(p.code, 20)
    local n = DB.upd('DELETE FROM mdt_penal_codes WHERE code = ?', { code })
    if n == 0 then return { success = false, message = L('pc_not_found') } end
    Cache.clear('penal')
    MDT.audit(actor, 'penal_code_deleted', nil, nil, code)
    return { success = true }
end)

MDT.rpc('getFines', { perm = 'fines', law = true, deny = {} }, function()
    local c = Cache.get('finetypes')
    if c then return c end
    local rows = DB.q('SELECT * FROM mdt_fine_types ORDER BY category, name')
    Cache.set('finetypes', rows, 120)
    return rows
end)

---------------------------------------------------------------------------
-- Fines: taken from cash, never below zero; only what was taken is credited
---------------------------------------------------------------------------
-- returns the amount actually taken (0 when nothing was)
function Penal.applyFine(targetSrc, amount, reason, officer)
    amount = MDT.int(amount, 0, nil, 0)
    if amount <= 0 then return 0 end
    local ch = MDT.char(targetSrc)
    if not ch then return 0 end
    local cash = math.floor(tonumber(ch.money) or 0)
    local taken = math.max(0, math.min(amount, cash))
    if taken <= 0 then
        MDT.notify(targetSrc, L('fine_no_cash', amount, reason or ''), 6000)
        return 0
    end
    local ok = pcall(ch.removeCurrency, 0, taken)
    if not ok then
        MDT.notify(targetSrc, L('fine_apply_failed'), 5000)
        return 0
    end
    MDT.notify(targetSrc, L('was_fined', taken, reason or ''), 6000)
    local job = officer and officer.job or Config.LawJobs[1]
    if not MDT.isLawJob(job) then job = Config.LawJobs[1] end
    if Config.Ledger.enabled and Config.Ledger.creditFines then
        Ledger.credit(job, taken, 'fine', officer and officer.name or 'System', reason)
    elseif Config.Ledger.externalFineCredit.enabled then
        local e = Config.Ledger.externalFineCredit
        DB.upd(('UPDATE `%s` SET `%s` = `%s` + ? WHERE `%s` = ?'):format(e.table, e.amountColumn, e.amountColumn, e.jobColumn), { taken, e.job })
    end
    MDT.log('fines', 'Fine applied', ('%s fined %s $%d, collected $%d (%s)'):format(officer and officer.name or 'System', MDT.player(targetSrc) and MDT.player(targetSrc).name or tostring(targetSrc), amount, taken, reason or ''), 'orange')
    return taken
end

Penal.billCooldown = {}

RegisterCommand('mdtbill', function(src, args)
    if src <= 0 then return end
    local a = MDT.player(src)
    if not a or not a.isLaw then return MDT.notify(src, L('no_permission'), 4000) end
    if not Duty.isOn(src) then return MDT.notify(src, L('cmd_must_be_on_duty'), 4000) end
    if not MDT.can(a, 'fines') then return MDT.notify(src, L('bill_no_permission'), 4000) end
    local amount = MDT.int(args[1], 1, nil, nil)
    local target = MDT.int(args[2], 1, nil, nil)
    if not amount or not target then return MDT.notify(src, L('bill_usage'), 5000) end
    if amount > Config.Fines.maxDirectBill then return MDT.notify(src, L('bill_max', Config.Fines.maxDirectBill), 5000) end
    local t = MDT.player(target)
    if not t then return MDT.notify(src, L('player_not_found'), 4000) end
    if target == src then return MDT.notify(src, L('bill_self'), 4000) end
    if MDT.dist(MDT.coords(src), MDT.coords(target)) > Config.Fines.billDistance then
        return MDT.notify(src, L('target_too_far', Config.Fines.billDistance), 4000)
    end
    -- one bill per citizen every Config.Fines.billCooldownSeconds
    local last = Penal.billCooldown[t.cid]
    local wait = (tonumber(Config.Fines.billCooldownSeconds) or 0) - (os.time() - (last or 0))
    if last and wait > 0 then return MDT.notify(src, L('bill_cooldown', t.name, wait), 4000) end
    Penal.billCooldown[t.cid] = os.time()
    local taken = Penal.applyFine(target, amount, L('bill_direct_reason'), a)
    if taken > 0 then
        Lawmen.bumpStat(a.cid, 'fines_applied', 1)
        MDT.audit(a, 'fine_direct', t.cid, t.name, ('/mdtbill $%d, collected $%d'):format(amount, taken))
        if taken < amount then
            MDT.notify(src, L('bill_partial', taken, amount, t.name), 6000)
        else
            MDT.notify(src, L('bill_success', taken, t.name), 5000)
        end
    else
        MDT.notify(src, L('bill_nothing', t.name), 5000)
    end
end, false)

---------------------------------------------------------------------------
-- Processing an arrest: totals come from the penal code, never the client
---------------------------------------------------------------------------
-- charges: [{ code, count?, tier? (1-based index) | tierKind? }]
function Penal.compute(charges)
    local map = Penal.byCode()
    local list, fine, months = {}, 0, 0
    if type(charges) ~= 'table' then return nil, L('arr_no_charges') end
    for i, c in ipairs(charges) do
        if i > 50 then break end
        local code = type(c) == 'table' and MDT.str(c.code, 20) or MDT.str(c, 20)
        local pc = map[code]
        if not pc then return nil, L('arr_unknown_charge', code) end
        local count = type(c) == 'table' and MDT.int(c.count, 1, 20, 1) or 1
        local f, m, tierKind = pc.fine, pc.months, nil
        if type(c) == 'table' and type(pc.tiers) == 'table' and #pc.tiers > 0 then
            local tier
            local idx = MDT.int(c.tier, 1, #pc.tiers, nil)
            if idx then tier = pc.tiers[idx] end
            if not tier and c.tierKind then
                for _, t in ipairs(pc.tiers) do if t.kind == c.tierKind then tier = t end end
            end
            if tier then
                f, m, tierKind = tonumber(tier.fine) or f, tonumber(tier.months) or m, tier.kind
            end
        end
        list[#list + 1] = { code = pc.code, label = pc.label, charge_class = pc.charge_class, count = count, fine = f, months = m, tier = tierKind }
        fine = fine + f * count
        months = months + m * count
    end
    if #list == 0 then return nil, L('arr_no_charges') end
    return list, fine, months
end

function Penal.processArrest(actor, p)
    local cid = MDT.str(p.citizenIdentity, 50)
    if cid == '' then return { success = false, message = L('missing_required_data') } end
    local key = actor.cid .. ':' .. cid
    local last = Penal.arrestCooldown[key]
    if last and os.time() - last < Config.Jail.arrestCooldownSeconds then
        return { success = false, message = L('arrest_cooldown') }
    end
    local charges, totalFine, totalMonths = Penal.compute(p.charges)
    if not charges then return { success = false, message = totalFine } end

    -- the target must be the citizen named
    -- 0 or nothing = no chosen target (the page sends 0 for "offline / no target")
    local target = MDT.int(p.targetServerId, nil, nil, nil)
    if target and target < 1 then target = nil end
    if target then
        local t = MDT.player(target)
        if not t or t.cid ~= cid then return { success = false, message = L('arr_target_mismatch') } end
    else
        target = MDT.findByCid(cid)
    end
    local citizenName = MDT.charName(cid) or MDT.str(p.citizenName, 100)

    local maxD = Config.Jail.maxDiscountPercent
    local legacy = MDT.int(p.discountPercent, 0, maxD, 0)
    local fineD = MDT.int(p.fineDiscountPercent, 0, maxD, legacy)
    local jailD = MDT.int(p.jailDiscountPercent, 0, maxD, legacy)
    local finalFine = math.floor(totalFine * (100 - fineD) / 100)
    local finalMonths = math.min(Config.Jail.maxMinutes, math.floor(totalMonths * (100 - jailD) / 100))
    local notes = MDT.str(p.notes, 2000, true)
    local wantFine, wantJail = MDT.bool(p.applyFine), MDT.bool(p.applyJail)

    if target and wantJail and finalMonths > 0 and Prison.isServing(target) then
        return { success = false, message = L('arr_already_serving') }
    end
    -- a fine or sentence is only applied to a citizen standing with the officer
    if target and ((wantFine and finalFine > 0) or (wantJail and finalMonths > 0))
        and MDT.dist(MDT.coords(actor.src), MDT.coords(target)) > Config.Jail.targetDistance then
        return { success = false, message = L('target_too_far', Config.Jail.targetDistance) }
    end

    Penal.arrestCooldown[key] = os.time()
    local fineApplied, jailApplied, fineCollected = false, false, 0
    if wantFine and finalFine > 0 and target then
        fineCollected = Penal.applyFine(target, finalFine, L('fined_by_charges'), actor)
        fineApplied = fineCollected > 0
    end
    if wantJail and finalMonths > 0 and target then
        local station = (MDT.bool(p.serveLocally) and #Config.Prison.stations > 0) and MDT.int(p.stationIndex, 1, #Config.Prison.stations, nil) or nil
        jailApplied = Prison.jail(target, {
            seconds = finalMonths * 60, minutes = finalMonths,
            reason = notes ~= '' and notes or L('arrested_by', actor.name),
            by = actor.name, fine = fineCollected, station = station,
        })
    end

    local arrestId = DB.ins([[INSERT INTO mdt_arrests (citizen_identity, citizen_name, lawman_citizenid, lawman_name, charges, total_fine, total_months,
        discount_percent, fine_discount_percent, jail_discount_percent, final_fine, final_months, notes, fine_applied, jail_applied)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        cid, citizenName, actor.cid, actor.name, MDT.jenc(charges), totalFine, totalMonths,
        legacy, fineD, jailD, finalFine, finalMonths, notes, fineApplied and 1 or 0, jailApplied and 1 or 0 })

    Records.clearWanted(cid)
    Lawmen.bumpStat(actor.cid, 'arrests_made', 1)
    if fineApplied then Lawmen.bumpStat(actor.cid, 'fines_applied', 1) end

    local labels = {}
    for _, c in ipairs(charges) do labels[#labels + 1] = (c.count > 1 and (c.count .. 'x ') or '') .. c.label end
    MDT.log('arrest', 'ARREST PROCESSED', ('%s processed %s (%s)\nCharges: %s\nFine: $%d%s | Jail: %d min%s'):format(
        actor.name, citizenName, cid, table.concat(labels, ', '), finalFine, fineApplied and (' (collected $%d)'):format(fineCollected) or '',
        finalMonths, jailApplied and ' (jailed)' or ''), 'red')
    MDT.audit(actor, 'arrest_made', cid, citizenName, ('Fine $%d (collected $%d), %d months'):format(finalFine, fineCollected, finalMonths), { arrestId = arrestId })
    Records.broadcast()

    local message = L('arr_processed')
    if (wantFine or wantJail) and not target then
        message = L('arr_target_offline')
    elseif wantFine and finalFine > 0 and fineCollected < finalFine then
        message = L('arr_fine_partial', fineCollected, finalFine)
    end
    return { success = true, arrestId = arrestId, finalFine = finalFine, finalMonths = finalMonths, fineCollected = fineCollected,
        fineApplied = fineApplied, jailApplied = jailApplied, message = message }
end

MDT.rpc('processArrest', { perm = 'arrest', law = true, duty = true }, function(actor, p)
    return Penal.processArrest(actor, p)
end)
