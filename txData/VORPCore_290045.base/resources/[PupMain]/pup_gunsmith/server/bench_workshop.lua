-- pup_gunsmith | Workshop tab: condition, repair and tier upgrades ("tempering")
-- Condition and tiers live in vorp_inventory, which checks ownership itself.

Workshop = {}

local function repairFee()
    local fee = tonumber(Config.Repair and Config.Repair.fee) or 0 -- missing means free
    return math.max(0, fee)
end

local function wearOn()
    local ok, v = pcall(function() return Inv:IsWeaponDegradationEnabled() end)
    return ok and v == true
end

local function tierOf(src, gun)
    local ok, t = pcall(function() return Inv:GetWeaponTier(src, gun.id) end)
    return ok and (tonumber(t) or 0) or 0
end

local function tierCost(tier)
    local c = Config.Tier.costs[tier]
    local mats = {}
    for _, m in ipairs((c and c.materials) or {}) do
        mats[#mats + 1] = { name = m.item, label = m.label, amount = m.amount }
    end
    return (c and tonumber(c.cash)) or 0, mats
end

function Workshop.card(src, gun)
    local okS, status = pcall(function() return Inv:GetWeaponStatusById(src, gun.id) end)
    status = okS and type(status) == 'table' and status or nil
    local tier = status and tonumber(status.tier) or tierOf(src, gun)
    local card = {
        wear = wearOn(),
        fee = repairFee(),
        status = status and {
            degradation = tonumber(status.degradation) or 0,
            damage = tonumber(status.damage) or 0,
            dirt = tonumber(status.dirt) or 0,
            soot = tonumber(status.soot) or 0,
            canDegrade = status.canDegrade == true,
        } or nil,
        tier = tier,
        maxTier = Config.Tier.max,
    }
    if tier < Config.Tier.max then
        local nextTier = tier + 1
        local cash, mats = tierCost(nextTier)
        local list = {}
        for _, m in ipairs(mats) do
            list[#list + 1] = { label = m.label, need = m.amount, have = Srv.count(src, m.name) }
        end
        card.next = {
            tier = nextTier,
            cash = cash,
            materials = list,
            slower = math.floor(nextTier * Config.Tier.slowPerTier * 100 + 0.5),
        }
    end
    return card
end

Srv.rpc('benchCard', function(src, char)
    local s = Bench.active(src, char, true)
    if not s then return { ok = false, msg = L('stand_bench') } end
    return { ok = true, card = Workshop.card(src, s.gun), wallet = Srv.wallet(src) }
end, { throttle = 300 })

Srv.rpc('benchRepair', function(src, char)
    local s = Bench.active(src, char, true)
    if not s then return { ok = false, msg = L('stand_bench') } end
    local gun = s.gun
    local fee = repairFee()
    if Srv.cash(src) + 1e-9 < fee then
        return { ok = false, msg = L('no_money'), card = Workshop.card(src, gun), wallet = Srv.wallet(src) }
    end
    local okR, repaired = pcall(function() return Inv:RepairWeaponById(src, gun.id) end)
    local msg
    if okR and repaired == true then
        if fee > 0 and Srv.takeMoney(src, 0, fee) then
            msg = L('repaired_fee', GS.dollars(fee):sub(2))
        else
            msg = L('repaired')
        end
        Discord.repair({ src = src, char = char, gun = gun, fee = fee })
    else
        msg = L('repair_failed')
    end
    return { ok = okR and repaired == true, msg = msg, card = Workshop.card(src, gun), wallet = Srv.wallet(src) }
end, { exclusive = true, throttle = 1000 })

Srv.rpc('benchTier', function(src, char)
    local s = Bench.active(src, char, true)
    if not s then return { ok = false, msg = L('stand_bench') } end
    local gun = s.gun
    local function reply(ok, msg)
        return { ok = ok, msg = msg, card = Workshop.card(src, gun), wallet = Srv.wallet(src) }
    end

    local current = tierOf(src, gun)
    if not Srv.same(src, char) or Bench.sessions[src] ~= s then return { ok = false, msg = L('stand_bench') } end
    if current >= Config.Tier.max then return reply(false, L('tier_max')) end
    local target = current + 1
    local cash, mats = tierCost(target)

    if Srv.cash(src) + 1e-9 < cash then return reply(false, L('no_money')) end
    local short = {}
    for _, m in ipairs(mats) do
        local have = Srv.count(src, m.name)
        if have < m.amount then short[#short + 1] = ('%dx %s'):format(m.amount - have, m.label) end
    end
    if #short > 0 then return reply(false, L('tier_needs', target, table.concat(short, ', '))) end

    -- taken first and handed back if vorp_inventory refuses the new tier
    if not Srv.takeMoney(src, 0, cash) then return reply(false, L('no_money')) end
    if not Srv.takeMaterials(src, mats, 1) then
        Srv.giveMoney(src, 0, cash)
        return reply(false, L('tier_needs', target, '?'))
    end
    local okT, set = pcall(function() return Inv:SetWeaponTier(src, gun.id, target) end)
    if not okT or set ~= true then
        Srv.giveMoney(src, 0, cash)
        Srv.giveMaterials(src, mats, 1)
        return reply(false, L('tier_failed'))
    end
    Discord.tier({ src = src, char = char, gun = gun, tier = target, cash = cash, mats = mats })
    local slower = math.floor(target * Config.Tier.slowPerTier * 100 + 0.5)
    return reply(true, L('tier_done', target, slower))
end, { exclusive = true, throttle = 1000 })
