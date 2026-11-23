-- pup-medical | respawn requests and what a respawn costs

Respawn = {}

local D = Config.Death or {}
local deathAt  = {}   -- [src] = os.time() vorp_core reported the death
local lastAsk  = {}   -- [src] = os.time() of the last respawn request that ran
local lastLoss = {}   -- [src] = os.time() the losses last ran

-- the ped itself, not the isdead flag: vorp_core sets that flag from this same client event
local function pedDead(src)
    local ped = GetPlayerPed(src)
    return ped ~= nil and ped ~= 0 and DoesEntityExist(ped) and GetEntityHealth(ped) <= 0
end

-- vorp_core's client reports deaths and revives with this
RegisterNetEvent('vorp:ImDead', function(isDead)
    local src = source
    if isDead == true then
        if deathAt[src] then return end
        -- the death is only timed once the server sees the ped dead; health can sync a moment late
        local tries = 0
        local function check()
            if deathAt[src] or not GetPlayerName(src) then return end
            if pedDead(src) then
                deathAt[src] = os.time()
            elseif tries < 5 then
                tries = tries + 1
                SetTimeout(1000, check)
            end
        end
        check()
    else
        deathAt[src] = nil
    end
end)

function Respawn.OnRevived(src)
    deathAt[src] = nil
end

-- any revive (admin, script, medic) shows up as a living ped; drop the old death time then
CreateThread(function()
    while true do
        Wait(10000)
        for src in pairs(deathAt) do
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and DoesEntityExist(ped) and GetEntityHealth(ped) > 0 then
                deathAt[src] = nil
            end
        end
    end
end)

OnPlayerLeft(function(src)
    deathAt[src] = nil
    lastAsk[src] = nil
    lastLoss[src] = nil
end)

local function nearestPoint(pos)
    local best, bestD = nil, math.huge
    for _, p in ipairs(D.respawnPoints or {}) do
        local d = pos and #(pos - p) or 0
        if d < bestD then best, bestD = p, d end
    end
    return best
end

-- the jobs that count as medics for the loss rule
local function medicJobs()
    if Config.Switches.medicsFromAlertType then
        local def = AlertType(MEDICAL_TYPE)
        if def and type(def.jobs) == 'table' and #def.jobs > 0 then return def.jobs end
    end
    return { 'doctor', 'pharmacist' }
end

local function medicsOnDuty(exclude)
    local perJob, others = {}, 0
    local jobs = medicJobs()
    for _, j in ipairs(jobs) do perJob[j] = 0 end
    for _, p in ipairs(OnlinePlayers()) do
        local pc = GetCtx(p)
        if pc and perJob[pc.job] ~= nil and IsOnDuty(p, pc.job) then
            perJob[pc.job] = perJob[pc.job] + 1
            if p ~= exclude then others = others + 1 end
        end
    end
    return perJob, others, jobs
end

---------------------------------------------------------------------------
-- Losses. Returns true when the respawn may go ahead.
---------------------------------------------------------------------------
local function takeWeapons(ctx)
    local lost = {}
    local ok, weapons = pcall(function() return Inv:getUserInventoryWeapons(ctx.src) end)
    if not ok or type(weapons) ~= 'table' then
        WarnOnce('getUserInventoryWeapons', 'vorp_inventory getUserInventoryWeapons failed: ' .. tostring(weapons))
        return lost
    end
    local rows = {}
    local okRows, res = pcall(function()
        return MySQL.query.await('SELECT * FROM loadout WHERE charidentifier = ?', { ctx.charId })
    end)
    if okRows and type(res) == 'table' then
        for _, r in ipairs(res) do rows[tonumber(r.id)] = r end
    end

    local keep = {}
    for _, n in ipairs(D.keepWeapons or {}) do keep[tostring(n):upper()] = true end

    for _, w in ipairs(weapons) do
        local name = tostring(w.name or ''):upper()
        local wid = tonumber(w.id)
        if wid and name ~= '' and not keep[name] then
            local r = rows[wid] or {}
            local record = {
                name        = r.name or name,
                label       = r.label or w.label or name,
                ammo        = r.ammo or '{}',
                components  = r.components or '[]',
                comps       = r.comps or '{}',
                serial      = r.serial_number or w.serial_number or '',
                customLabel = r.custom_label or w.custom_label or '',
                customDesc  = r.custom_desc or w.custom_desc or '',
                tier        = tonumber(r.tier) or 0,
                degradation = tonumber(r.degradation) or 0,
                dirt        = tonumber(r.dirt) or 0,
                soot        = tonumber(r.soot) or 0,
                damage      = tonumber(r.damage) or 0,
            }
            local okSub, subbed = pcall(function() return Inv:subWeapon(ctx.src, wid) end)
            local okDel, deleted = pcall(function() return Inv:deleteWeapon(ctx.src, wid) end)
            if not (okDel and deleted) then
                pcall(function() MySQL.update.await('DELETE FROM loadout WHERE id = ?', { wid }) end)
            end
            -- only record what was really taken, so a restore never hands out a copy
            if (okSub and subbed == true) or (okDel and deleted == true) then lost[#lost + 1] = record end
        end
    end
    return lost
end

local function takeItems(ctx)
    local lost = {}
    local ok, items = pcall(function() return Inv:getUserInventoryItems(ctx.src) end)
    if not ok or type(items) ~= 'table' then
        WarnOnce('getUserInventoryItems', 'vorp_inventory getUserInventoryItems failed: ' .. tostring(items))
        return lost
    end
    local keep = {}
    for _, n in ipairs(D.keepItems or {}) do keep[n] = true end
    for _, it in ipairs(items) do
        local count = math.floor(tonumber(it.count) or 0)
        if it.id and count > 0 and not keep[it.name] then
            -- removed by stack id, so the record matches exactly what was taken
            local okSub, removed = pcall(function() return Inv:subItemById(ctx.src, it.id, nil, false, count) end)
            if okSub and removed then
                local rec = { name = it.name, label = it.label or it.name, count = count }
                if type(it.metadata) == 'table' and next(it.metadata) ~= nil then rec.metadata = it.metadata end
                lost[#lost + 1] = rec
            end
        end
    end
    return lost
end

local function deathLog(ctx, perJob, jobs, inWater, weapons, items, money)
    local wl, il = {}, {}
    for _, w in ipairs(weapons) do wl[#wl + 1] = (w.customLabel ~= '' and w.customLabel) or w.label or w.name end
    for _, i in ipairs(items) do il[#il + 1] = ('%s (x%d)'):format(i.label or i.name, i.count) end
    local counts = {}
    for _, j in ipairs(jobs) do counts[#counts + 1] = ('%s: %d'):format(j, perJob[j] or 0) end
    local steamName = GetPlayerName(ctx.src) or 'unknown'

    local player = ('Char ID: %s\nName: %s\nSteam name: %s\nSteam: %s\nDiscord: %s\nOn-duty medics: %s'):format(
        tostring(ctx.charId), ctx.name, steamName,
        GetPlayerIdentifierByType(tostring(ctx.src), 'steam') or 'n/a', DiscordId(ctx.src),
        table.concat(counts, ', '))

    PostWebhook(Hook('death'), {
        title  = inWater and 'Lost to the water' or 'Player respawned',
        color  = inWater and Colors.blue or Colors.red,
        fields = {
            Field('Player', player, false),
            Field('Weapons lost', #wl > 0 and table.concat(wl, '\n') or 'none', false),
            Field('Items lost', #il > 0 and table.concat(il, '\n') or 'none', false),
            Field('Currency lost', ('cash %s, gold %s, rol %s'):format(money.cash, money.gold, money.rol), false),
        },
    }, steamName)
end

function Respawn.RunLosses(src, inWater, toldNoDoctors)
    local ctx = GetCtx(src)
    if not ctx then return false end
    if not ctx.dead then
        Warn(('respawn losses refused for %d: not flagged dead'):format(src))
        return false
    end
    local now = os.time()
    if lastLoss[src] and now - lastLoss[src] < 10 then
        Debug('death', ('%d: losses ran %ds ago, skipped'):format(src, now - lastLoss[src]))
        return true
    end
    lastLoss[src] = now

    local told = false
    if toldNoDoctors then
        told = Alerts.SafeToRespawn(src)
        if not told then Debug('death', ('%d claimed "no doctors" but the server disagrees'):format(src)) end
    end

    local perJob, others, jobs = medicsOnDuty(src)
    local apply = inWater or (not told and others > 0)
    Debug('death', ('%d: water=%s told=%s other medics=%d -> losses %s'):format(
        src, tostring(inWater), tostring(told), others, apply and 'apply' or 'waived'))

    local weapons, items = {}, {}
    local money = { cash = 0, gold = 0, rol = 0 }
    if apply then
        local loss = D.loss or {}
        if loss.weapons and not InList(D.lawJobs, ctx.job) then weapons = takeWeapons(ctx) end
        if loss.items then items = takeItems(ctx) end
        local fresh = StillSame(ctx)
        if fresh then
            local c = fresh.char
            if loss.cash and (tonumber(c.money) or 0) > 0 then money.cash = tonumber(c.money); c.removeCurrency(0, money.cash) end
            if loss.gold and (tonumber(c.gold) or 0) > 0 then money.gold = tonumber(c.gold); c.removeCurrency(1, money.gold) end
            if loss.rol and (tonumber(c.rol) or 0) > 0 then money.rol = tonumber(c.rol); c.removeCurrency(2, money.rol) end
        end
        if #weapons > 0 or #items > 0 or money.cash > 0 or money.gold > 0 then
            Losses.Record(ctx, weapons, items, money.cash, money.gold)
        end
    end

    deathLog(ctx, perJob, jobs, inWater, weapons, items, money)
    Alerts.ClearRespawnState(src)
    return true
end

---------------------------------------------------------------------------
-- The respawn request from the hold prompt
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:server:respawn', function(inWater, toldNoDoctors)
    local src = source
    inWater = inWater == true
    toldNoDoctors = toldNoDoctors == true
    if not RateOk(src, 'respawnAsk', 1000) then return end
    local ctx = GetCtx(src)
    if not ctx then return end

    local prompt = D.prompt or {}
    if not prompt.enabled or not prompt.respawnEnabled then return end
    local delay = tonumber(prompt.respawnDelaySeconds) or 0
    local now = os.time()
    if delay > 0 and ctx.dead then
        if not deathAt[src] then deathAt[src] = now end
        local left = delay - 5 - (now - deathAt[src])
        if left > 0 then
            TipBottom(src, L('respawnIn', math.ceil(left)), 4000)
            if toldNoDoctors then TriggerClientEvent('pup-medical:client:keepToldNoDoctors', src) end
            return
        end
    end

    if lastAsk[src] and now - lastAsk[src] < 5 then return end
    lastAsk[src] = now

    if not Respawn.RunLosses(src, inWater, toldNoDoctors) then return end

    local point = nearestPoint(Pos(src))
    if point then
        TriggerClientEvent('pup-medical:client:respawnTeleport', src, { x = point.x, y = point.y, z = point.z })
    end
    Wait(2500)
    ctx = StillSame(ctx)
    -- a doctor may have revived them during the teleport; that revive already
    -- cleared everything, so a second one would only replay the fade
    if not ctx or not ctx.dead then return end
    if not Config.Switches.recoveryOnRespawn then
        TriggerClientEvent('pup-medical:client:skipRecoveryOnce', src)
    end
    Core.Player.Revive(src)
    deathAt[src] = nil
    Alerts.ClearRespawnState(src)
    -- written only once the revive has gone out, so a failed respawn never
    -- leaves the database saying "alive" while the player lies dead
    pcall(function()
        MySQL.update.await('UPDATE characters SET isdead = 0 WHERE identifier = ? AND charidentifier = ?',
            { ctx.identifier, ctx.charId })
    end)
end)

-- vorp_core's own respawn path (normally switched off): losses only
RegisterNetEvent('pup-medical:server:forceRespawnLosses', function(inWater, toldNoDoctors)
    local src = source
    if not RateOk(src, 'forceRespawn', 5000) then return end
    local ctx = GetCtx(src)
    if not ctx then return end
    Respawn.RunLosses(src, inWater == true, toldNoDoctors == true)
end)
