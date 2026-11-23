-- pup-gangs | server/fortraid.lua: the fort raid, the PvE half of the gang loop

local VorpCore = {}
TriggerEvent("getCore", function(core) VorpCore = core end)
if not VorpCore or not VorpCore.getUser then
    VorpCore = exports.vorp_core:GetCore()
end

local function dbg(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-gangs]^7 " .. table.concat(parts, " "))
end

local function Char(src)
    local user = VorpCore.getUser(src)
    return user and user.getUsedCharacter or nil
end
local function notify(src, msg, dur) VorpCore.NotifyRightTip(src, msg, dur or 4000) end
local function now() return os.time() end

-- [fortIndex] = { gangid, leader(src), stage, wave, alive, startts, cooldownAt }
local raids = {}
local fortCooldowns = {}   -- [fortIndex] = ts
local gangCooldowns = {}   -- [gangid]    = ts

local function fortAt(index)
    return (Config.FortRaid.forts or {})[tonumber(index) or -1]
end

-- living members of `gangid` inside the arena
local function crewOnSite(gangid, fort)
    local n, list = 0, {}
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ch = src and Char(src)
        local m = ch and GangMemberOf(ch.charIdentifier)
        if m and m.gangid == gangid and not ch.isdead then
            local ped = GetPlayerPed(src)
            if ped and ped > 0 then
                local c = GetEntityCoords(ped)
                if #(vector3(c.x, c.y, c.z) - vector3(fort.x + 0.0, fort.y + 0.0, fort.z + 0.0))
                    <= Config.FortRaid.arenaRadius then
                    n = n + 1
                    list[#list + 1] = src
                end
            end
        end
    end
    return n, list
end

local function tellCrew(gangid, event, payload)
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ch = src and Char(src)
        local m = ch and GangMemberOf(ch.charIdentifier)
        if m and m.gangid == gangid then
            TriggerClientEvent(event, src, payload)
        end
    end
end

local function endRaid(index, won)
    local r = raids[index]
    if not r then return end
    raids[index] = nil
    fortCooldowns[index] = now()
    gangCooldowns[r.gangid] = now()
    tellCrew(r.gangid, 'pup-gangs:fortRaidEnded', { index = index, won = won })
    -- the leader tears down whatever peds are still standing
    if r.leader then TriggerClientEvent('pup-gangs:fortCleanup', r.leader) end
    GangLog(r.gangid, 'fort', won and ('took the strongbox at ' .. r.fortLabel)
        or ('the raid on ' .. r.fortLabel .. ' fell apart'), '', 0)
    dbg('fort raid ended', index, won and 'WON' or 'LOST')
end

-- The leader's client reports the kills, so the server can't tell a real fight from a false report.
-- It can hold the box shut until a raid has run this long. The crew see it on the game's own timer.
local function minRaidSeconds()
    return math.max(0, math.floor((tonumber(Config.FortRaid.minRaidMinutes) or 0) * 60))
end

-- send the next wave (or the boss) to the leader's client
local function pushStage(index)
    local r = raids[index]
    if not r then return end
    local fort = fortAt(index)
    if not fort then return endRaid(index, false) end

    if r.wave <= #(Config.FortRaid.waves or {}) then
        local w = Config.FortRaid.waves[r.wave]
        r.alive = w.count
        r.stage = 'wave'
        r.spawnReported = nil
        tellCrew(r.gangid, 'pup-gangs:fortWave', {
            index = index, wave = r.wave, total = #Config.FortRaid.waves,
            spawn = (r.leader == nil) and false or true,
            x = fort.x, y = fort.y, z = fort.z, cfg = w,
        })
        -- only the LEADER spawns; everyone else just gets the banner
        if r.leader then
            TriggerClientEvent('pup-gangs:fortSpawnWave', r.leader,
                { index = index, wave = r.wave, x = fort.x, y = fort.y, z = fort.z, cfg = w })
        end
        dbg('fort', index, 'wave', r.wave, 'of', #Config.FortRaid.waves)
    elseif Config.FortRaid.boss.enabled and not r.bossDone then
        r.stage = 'boss'
        r.alive = 1
        tellCrew(r.gangid, 'pup-gangs:fortBoss', { index = index, name = Config.FortRaid.boss.name })
        if r.leader then
            TriggerClientEvent('pup-gangs:fortSpawnBoss', r.leader,
                { index = index, x = fort.x, y = fort.y, z = fort.z, cfg = Config.FortRaid.boss })
        end
        dbg('fort', index, 'BOSS')
    else
        -- everything is dead: drop the strongbox
        r.stage = 'loot'
        r.lootAt = r.lootAt or now()
        tellCrew(r.gangid, 'pup-gangs:fortLoot', {
            index = index, x = r.lootX or fort.x, y = r.lootY or fort.y, z = r.lootZ or fort.z,
            prop = Config.FortRaid.lootProp, seconds = Config.FortRaid.lootSeconds,
        })
        dbg('fort', index, 'strongbox up')
    end
end

RegisterNetEvent('pup-gangs:startFortRaid', function(index)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    if not Config.FortRaid.enabled then return end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return notify(_source, Locale.noGang) end
    local gang = GangById(m.gangid)
    if not gang then return end

    if Config.FortRaid.unlock and not GangHasPerk(gang, Config.FortRaid.unlock) then
        return notify(_source, Locale.lockedPerk)
    end
    if (m.rank or 1) < (tonumber(Config.FortRaid.minRank) or 1) then
        return notify(_source, Locale.notAllowed)
    end

    index = tonumber(index) or -1
    local fort = fortAt(index)
    if not fort then return end
    if raids[index] then return notify(_source, Locale.fortBusy) end
    for _, r in pairs(raids) do
        if r.gangid == m.gangid then return notify(_source, Locale.fortAlready) end
    end
    if ((fortCooldowns[index] or 0) + Config.FortRaid.cooldownMinutes * 60) > now() then
        return notify(_source, Locale.fortCooldown)
    end
    if ((gangCooldowns[m.gangid] or 0) + Config.FortRaid.gangCooldownMinutes * 60) > now() then
        return notify(_source, Locale.fortCooldown)
    end

    -- call it, then ride out
    local arm <const> = (tonumber(Config.FortRaid.armMinutes) or 0) * 60
    if arm <= 0 then
        -- armMinutes = 0: be there or be refused
        local ped = GetPlayerPed(_source)
        local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
        if not pc or #(vector3(pc.x, pc.y, pc.z) - vector3(fort.x + 0.0, fort.y + 0.0, fort.z + 0.0))
            > Config.FortRaid.startRadius then
            return notify(_source, Locale.fortTooFar, 6000)
        end
        local crew = crewOnSite(m.gangid, fort)
        if crew < (Config.FortRaid.minCrew or 1) then
            return notify(_source, (Locale.fortNeedCrew):format(Config.FortRaid.minCrew or 1), 6000)
        end
        raids[index] = {
            gangid = m.gangid, leader = _source, stage = 'starting', wave = 1,
            alive = 0, startts = now(), fortLabel = fort.label, empty = 0,
            boxOpensAt = now() + minRaidSeconds(),
        }
        GangLog(m.gangid, 'fort', ('rode on %s'):format(fort.label), ch.firstname .. ' ' .. ch.lastname)
        tellCrew(m.gangid, 'pup-gangs:fortRaidStarted', {
            index = index, label = fort.label, x = fort.x, y = fort.y, z = fort.z,
            waves = #(Config.FortRaid.waves or {}), minSeconds = minRaidSeconds(),
        })
        return pushStage(index)
    end

    raids[index] = {
        gangid = m.gangid, leader = _source, stage = 'armed', wave = 1,
        alive = 0, startts = now(), armUntil = now() + arm,
        fortLabel = fort.label, empty = 0,
    }
    GangLog(m.gangid, 'fort', ('called the raid on %s'):format(fort.label), ch.firstname .. ' ' .. ch.lastname)
    tellCrew(m.gangid, 'pup-gangs:fortRaidArmed', {
        index = index, label = fort.label, x = fort.x, y = fort.y, z = fort.z,
        minutes = Config.FortRaid.armMinutes, crew = Config.FortRaid.minCrew or 1,
    })
    notify(_source, (Locale.fortArmed):format(fort.label, Config.FortRaid.minCrew or 1), 9000)
    dbg('fort raid ARMED on', fort.label, 'by gang', m.gangid)
end)

-- The leader reports how many peds actually came out of a wave (pushStage sets alive = w.count up front)
RegisterNetEvent('pup-gangs:fortWaveSpawned', function(index, wave, made)
    local _source = source
    local r = raids[tonumber(index) or -1]
    if not r or r.leader ~= _source then return end
    if r.stage ~= 'wave' or r.wave ~= tonumber(wave) then return end
    -- one report per wave push; pushStage clears this when it sends a wave
    if r.spawnReported then return end
    r.spawnReported = true

    made = math.max(0, math.floor(tonumber(made) or 0))
    if made < (r.alive or 0) then
        dbg('fort', index, 'wave', wave, 'only spawned', made, 'of', r.alive, '- correcting')
        r.alive = made
        if made == 0 then
            -- nothing came out at all: skip straight on rather than deadlock
            r.wave = r.wave + 1
            pushStage(tonumber(index))
        end
    end
end)

-- the leader reports a kill; the server counts down the wave
RegisterNetEvent('pup-gangs:fortKill', function(index, isBoss, x, y, z)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local r = raids[tonumber(index) or -1]
    if not r or r.leader ~= _source then return end

    if isBoss then
        if r.stage ~= 'boss' then return end
        r.bossDone = true
        r.alive = 0
        -- the box drops where the boss fell, if that is at the fort; otherwise at the fort itself.
        -- The leader's client sends this, and "<=" also refuses NaN.
        local bx, by, bz, fort = tonumber(x), tonumber(y), tonumber(z), fortAt(index)
        if fort and bx and by and bz
            and #(vector3(bx + 0.0, by + 0.0, bz + 0.0) - vector3(fort.x + 0.0, fort.y + 0.0, fort.z + 0.0))
                <= Config.FortRaid.arenaRadius + 60.0 then
            r.lootX, r.lootY, r.lootZ = bx, by, bz
        end
        r.wave = r.wave + 1
        pushStage(tonumber(index))
    else
        if r.stage ~= 'wave' then return end
        -- the wave is already down and the break is running: a late report must not skip the next one
        if (r.alive or 0) <= 0 then return end
        r.alive = math.max(0, (r.alive or 1) - 1)
        if r.alive <= 0 then
            r.wave = r.wave + 1
            local brk = (Config.FortRaid.waveBreakSeconds or 12)
            tellCrew(r.gangid, 'pup-gangs:fortWaveCleared', { index = tonumber(index), nextIn = brk })
            SetTimeout(brk * 1000, function()
                if raids[tonumber(index)] == r then pushStage(tonumber(index)) end
            end)
        end
    end
end)

-- THE STRONGBOX CONTENTS (Config.FortRaid.loot)
local function rollStrongbox(src, ch, r)
    local cfg = (Config.FortRaid.loot or {})
    local pool = cfg.table or {}
    if #pool == 0 then return {} end

    -- shuffle so the `rolls` cap does not always favour the top of the list
    local order = {}
    for i = 1, #pool do order[i] = i end
    for i = #order, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end

    local maxRolls = tonumber(cfg.rolls) or #pool
    local won, got = {}, {}
    for _, idx in ipairs(order) do
        if #won >= maxRolls then break end
        local e = pool[idx]
        if e and e.item and math.random(100) <= (tonumber(e.chance) or 0) then
            local lo = math.floor(tonumber(e.min) or 1)
            local hi = math.max(lo, math.floor(tonumber(e.max) or lo))
            local n  = math.random(lo, hi)
            if n > 0 then
                won[#won + 1] = { item = e.item, count = n }
                got[#got + 1] = ('%dx %s'):format(n, e.item)
            end
        end
    end
    if #won == 0 then return {} end

    -- INTO THE DEN if the crew has one
    local denCid = nil
    if Config.FortRaid.lootToDen ~= false then
        local gang = GangById(r.gangid)
        local held = (GangDensOf and GangDensOf(r.gangid)) or {}
        if gang and #held > 0 and GangDenStashId then
            denCid = GangDenStashId(gang)
        end
    end

    if denCid then
        local items = {}
        for _, w in ipairs(won) do items[#items + 1] = { name = w.item, amount = w.count } end
        local ok = pcall(function()
            exports.vorp_inventory:addItemsToCustomInventory(tostring(denCid), items, ch.charIdentifier)
        end)
        if ok then
            dbg('strongbox -> den inventory', #won, 'stack(s)')
            return got
        end
        -- the den was full: fall through and hand it over rather than lose it
        dbg('strongbox: den inventory refused, handing to player')
    end

    for _, w in ipairs(won) do
        pcall(function() exports.vorp_inventory:addItem(src, w.item, w.count) end)
    end
    return got
end

-- cracking the strongbox pays the raid out
RegisterNetEvent('pup-gangs:fortLooted', function(index)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    index = tonumber(index) or -1
    local r = raids[index]
    if not r or r.stage ~= 'loot' then return end
    local m = GangMemberOf(ch.charIdentifier)
    if not m or m.gangid ~= r.gangid then return end
    -- the prompt is a hold of lootSeconds and cannot finish sooner; 2 seconds spare for clock rounding
    if now() - (r.lootAt or 0) < (tonumber(Config.FortRaid.lootSeconds) or 0) - 2 then return end
    if r.boxOpensAt and now() < r.boxOpensAt then
        -- the client gave up its prompt to send this, so it has to be told it can try again
        TriggerClientEvent('pup-gangs:fortBoxStillShut', _source, r.boxOpensAt - now())
        return
    end

    local fort = fortAt(index)
    local ped = GetPlayerPed(_source)
    local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
    if not pc or not fort then return end
    if #(vector3(pc.x, pc.y, pc.z) - vector3((r.lootX or fort.x) + 0.0, (r.lootY or fort.y) + 0.0, (r.lootZ or fort.z) + 0.0)) > 6.0 then
        return
    end

    -- the box pays once: the payout below waits on the inventory, so a second copy of this
    -- event would otherwise pass the stage check while the first is still paying
    r.stage = 'paid'

    -- points + cash through the normal path (faction multiplier, activity log)
    GangPayReward(_source, 'fort', 'raided ' .. r.fortLabel)
    -- then the physical contents of the box (Config.FortRaid.loot)
    local got = rollStrongbox(_source, ch, r)
    notify(_source, Locale.fortWon, 6000)
    if #got > 0 then
        notify(_source, (Locale.fortLootList):format(table.concat(got, ', ')), 9000)
    end
    if raids[index] == r then endRaid(index, true) end
end)

-- /raidwhere - why has nothing spawned?
if Config.General.debug then
    RegisterCommand('raidwhere', function(src)
        if src == 0 then return end
        local ch = Char(src)
        if not ch then return end
        local m = GangMemberOf(ch.charIdentifier)
        local ped = GetPlayerPed(src)
        local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
        local t0 = now()

        print('^3[raidwhere]^7 ------------------------------------------')
        print(('  gang           : %s'):format(m and tostring(m.gangid) or '^1none - no raid possible^7'))
        print(('  minCrew        : %d      armMinutes: %s')
            :format(Config.FortRaid.minCrew or 1, tostring(Config.FortRaid.armMinutes)))
        print(('  arenaRadius    : %.0f  (the arrival check uses THIS)'):format(Config.FortRaid.arenaRadius or 120))

        local any = false
        for i, r in pairs(raids) do
            any = true
            local fort = fortAt(i)
            local n = fort and crewOnSite(r.gangid, fort) or 0
            print(('  RAID on %s: stage=%s gang=%s crew_on_site=%d leader=%s%s')
                :format(fort and fort.label or ('#' .. tostring(i)), tostring(r.stage),
                    tostring(r.gangid), n, tostring(r.leader),
                    r.stage == 'armed' and (' armed_for=' .. math.max(0, (r.armUntil or 0) - t0) .. 's') or ''))
        end
        if not any then print('  no raid running or armed') end

        for i, f in ipairs(Config.FortRaid.forts or {}) do
            local d = pc and #(vector3(pc.x, pc.y, pc.z) - vector3(f.x + 0.0, f.y + 0.0, f.z + 0.0)) or -1
            local fcd = math.max(0, ((fortCooldowns[i] or 0) + Config.FortRaid.cooldownMinutes * 60) - t0)
            local gcd = m and math.max(0, ((gangCooldowns[m.gangid] or 0) + Config.FortRaid.gangCooldownMinutes * 60) - t0) or 0
            print(('  [%d] %-14s you are %sm away %s  fort_cd=%ds  gang_cd=%ds')
                :format(i, f.label,
                    d >= 0 and ('%.0f'):format(d) or '?',
                    (d >= 0 and d <= (Config.FortRaid.arenaRadius or 120)) and '^2IN RANGE^7' or '',
                    fcd, gcd))
        end
        print('^3[raidwhere]^7 ------------------------------------------')
    end, false)
end

-- ABANDONMENT: a raid with nobody alive on the ground falls apart
CreateThread(function()
    while true do
        Wait(15000)
        for index, r in pairs(raids) do
            local fort = fortAt(index)
            if not fort then
                endRaid(index, false)
            elseif r.stage == 'armed' then
                -- ARMED: waiting for the crew to actually reach the fort
                local n, onSite = crewOnSite(r.gangid, fort)
                if n >= (Config.FortRaid.minCrew or 1) then
                    r.stage = 'starting'
                    r.startts = now()
                    r.boxOpensAt = now() + minRaidSeconds()
                    r.empty = 0
                    -- the leader is whoever actually got there: the caller may be dead or still riding
                    r.leader = onSite[1] or r.leader
                    tellCrew(r.gangid, 'pup-gangs:fortRaidStarted', {
                        index = index, label = fort.label, x = fort.x, y = fort.y, z = fort.z,
                        waves = #(Config.FortRaid.waves or {}), minSeconds = minRaidSeconds(),
                    })
                    dbg('fort raid ARMED -> RUNNING on', fort.label, 'with', n, 'on site')
                    pushStage(index)
                elseif now() >= (r.armUntil or 0) then
                    -- never rode out
                    tellCrew(r.gangid, 'pup-gangs:fortAbandoned', { index = index })
                    dbg('fort raid LAPSED on', fort.label, '- nobody arrived')
                    endRaid(index, false)
                end
            elseif r.stage ~= 'starting' then
                local n = crewOnSite(r.gangid, fort)
                if n > 0 then
                    r.empty = 0
                else
                    r.empty = (r.empty or 0) + 15
                    if r.empty >= (Config.FortRaid.abandonSeconds or 45) then
                        tellCrew(r.gangid, 'pup-gangs:fortAbandoned', { index = index })
                        endRaid(index, false)
                    end
                end
            end
        end
    end
end)

-- The leader's client owns the peds: if he drops, hand the job to somebody still
-- standing in the arena, and only call it off when there is nobody left.
AddEventHandler('playerDropped', function()
    local src = source
    for index, r in pairs(raids) do
        if r.leader == src then
            local fort = fortAt(index)
            local onSite
            if fort then
                local _, list = crewOnSite(r.gangid, fort)
                onSite = list
            end
            local heir = onSite and onSite[1]
            -- the dropped player can still be listed for a moment: skip past him
            if heir == src then heir = onSite[2] end

            if heir then
                r.leader = heir
                -- the old client took its peds with it; respawn the current stage
                r.alive = 0
                tellCrew(r.gangid, 'pup-gangs:fortLeaderLeft', { index = index })
                pushStage(index)
                dbg('fort', index, 'leader dropped - handed to', heir)
            else
                endRaid(index, false)
            end
        end
    end
end)

-- vorp_admin world cleanup deleted the locals (the leader's client forgot them first, so no
-- kills were counted): send the current wave or boss again, as when the leader drops
AddEventHandler('vorp_admin:worldCleanupDone', function()
    for index, r in pairs(raids) do
        -- alive 0 is the break between waves: the next one is already on its timer
        if r.leader and (r.stage == 'wave' or r.stage == 'boss') and (r.alive or 0) > 0 then
            r.alive = 0
            pushStage(index)
        end
    end
end)

-- what the panel shows on the Raids page
VorpCore.Callback.Register('pup-gangs:getForts', function(source, cb)
    local ch = Char(source)
    if not ch then return cb({}) end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return cb({}) end
    local out = {}
    for i, f in ipairs(Config.FortRaid.forts or {}) do
        local r = raids[i]
        local blocked
        if r then blocked = (r.gangid == m.gangid) and 'yours' or 'busy'
        elseif ((fortCooldowns[i] or 0) + Config.FortRaid.cooldownMinutes * 60) > now() then blocked = 'cooldown'
        elseif ((gangCooldowns[m.gangid] or 0) + Config.FortRaid.gangCooldownMinutes * 60) > now() then blocked = 'gangcooldown'
        end
        out[#out + 1] = { index = i, label = f.label, x = f.x, y = f.y, z = f.z, blocked = blocked }
    end
    cb(out)
end)
