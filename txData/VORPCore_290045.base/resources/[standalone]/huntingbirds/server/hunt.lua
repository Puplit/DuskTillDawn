-- huntingbirds | trips: the server picks the catch at the start and pays it once on return

local function formatWait(ms)
    local total = math.max(1, math.ceil(ms / 1000))
    local m, s = total // 60, total % 60
    if m > 0 then return Locale.minutesSeconds:format(m, s) end
    return Locale.seconds:format(s)
end

-- the zone entry for a hash sent by the client: unknown hashes and prey-less zones use the fallback
local function resolveZone(zoneHash)
    local Z = Config.HuntZones
    local zone = (zoneHash and Z.byHash[zoneHash]) or Z.fallback
    if not zone then return nil end
    if not zone.huntable then return zone, nil end
    if not zone.prey then
        local fb = Z.fallback
        if not fb or not fb.prey then return zone, nil end
        return fb, fb.prey
    end
    return zone, zone.prey
end

local function pick(list, xp)
    local candidates = {}
    for i, e in ipairs(list or {}) do
        if e.xpRequired <= xp then candidates[#candidates + 1] = i end
    end
    if #candidates == 0 then return nil end
    local i = candidates[math.random(#candidates)]
    return i, list[i]
end

local function tripMs()
    return ((tonumber(Config.Hunting.flyAwaySeconds) or 0) + (tonumber(Config.Hunting.huntSeconds) or 0) - 5) * 1000
end

RegisterNetEvent('huntingbirds:checkhunt', function(zoneHash)
    local src = source
    local char = Srv.char(src)
    if not char then return end
    if not Srv.throttle(src, 'hunt', 1000) then return end
    local s = Srv.session(src, char)
    if not s.activeBird or s.sellPoint then return end
    -- a trip whose return never came in is forfeited after a generous grace time
    if s.trip and GetGameTimer() - s.trip.startedAt > tripMs() + 300000 then s.trip = nil end
    if s.trip then return end

    local H = Config.Hunting
    if H.jobRequired and not Srv.hasJob(char, H.jobs) then
        Srv.notify(src, Locale.noJob, 'red')
        return
    end

    local now = GetGameTimer()
    local last = Srv.cooldowns[s.key]
    local cd = tonumber(H.cooldownMs) or 0
    if last and now - last < cd then
        Srv.notify(src, Locale.huntCooldown:format(formatWait(cd - (now - last))), 'red')
        return
    end

    local row = Srv.ownedRow(char, s.activeBird)
    if not row then
        s.activeBird, s.activeModel = nil, nil
        return
    end
    local xp = tonumber(row.xp) or 0

    local zone, preyName = resolveZone(Util.u32(zoneHash))
    if not zone or not preyName then
        Srv.notify(src, Locale.noHunt, 'red')
        return
    end

    local role = Util.roleOf(row.model)
    local trip = { birdId = row.id, role = role, startedAt = now }
    local reply = { birdId = row.id, role = role, zoneLabel = zone.label }
    if role == 'hunting' then
        local i, e = pick(Config.PreyLists[preyName], xp)
        if not i then Srv.notify(src, Locale.noHunt, 'red') return end
        trip.xp = e.xp
        reply.catchModel, reply.catchPreset = e.model, e.preset
    elseif role == 'scavenging' then
        local i, e = pick(Config.ScavengeItems, xp)
        if not i then Srv.notify(src, Locale.noHunt, 'red') return end
        trip.xp, trip.item, trip.amount = e.xp, e.item, e.amount
    elseif role == 'fishing' then
        local i, e = pick(Config.FishCatches, xp)
        if not i then Srv.notify(src, Locale.noHunt, 'red') return end
        trip.xp = e.xp
        reply.catchModel, reply.catchPreset = e.model, 0
    else
        trip.xp = 0 -- a bird with no role flies the trip and brings nothing
    end
    trip.xpOwed = (trip.xp or 0) > 0 or (H.extraXp and Srv.hasJob(char, H.jobs)) or false
    trip.itemOwed = trip.item ~= nil

    s.trip = trip
    Srv.cooldowns[s.key] = now
    Srv.dbg('src=%d trip bird %d role %s zone %s', src, row.id, tostring(role), zone.label)
    TriggerClientEvent('huntingbirds:starthunt', src, reply)
end)

-- the running trip for this bird when it is due; nil otherwise
local function dueTrip(src, char, birdId)
    local s = Srv.session(src, char)
    local trip = s.trip
    if not trip or trip.birdId ~= birdId or s.activeBird ~= birdId then return nil end
    if GetGameTimer() - trip.startedAt < tripMs() then
        Srv.dbg('src=%d trip return for bird %d came early', src, birdId)
        return nil
    end
    return trip, s
end

local function finish(s, trip)
    if not trip.xpOwed and not trip.itemOwed and s.trip == trip then s.trip = nil end
end

RegisterNetEvent('huntingbirds:addxp', function(birdId)
    local src = source
    local char = Srv.char(src)
    birdId = Util.int(birdId, 1)
    if not char or not birdId then return end
    local trip, s = dueTrip(src, char, birdId)
    if not trip then return end
    if not trip.xpOwed then
        finish(s, trip) -- a trip that owes nothing (no role, 0 XP) still has to end
        return
    end
    trip.xpOwed = false -- before any wait, so a second request finds nothing

    local H = Config.Hunting
    local gain = tonumber(trip.xp) or 0
    if H.extraXp and Srv.hasJob(char, H.jobs) then gain = gain + (tonumber(H.extraXp) or 0) end
    gain = math.floor(gain * Srv.perkMult(src) + 0.5)
    finish(s, trip)
    if gain <= 0 then return end

    local row = Srv.ownedRow(char, birdId)
    if not row then return end
    local maxXp = tonumber(Config.Progression.maxXp) or 1000
    local newXp = math.min(maxXp, (tonumber(row.xp) or 0) + gain)
    if newXp == row.xp then return end
    local ok = pcall(MySQL.update.await, 'UPDATE `birds` SET `xp` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
        { newXp, birdId, char.identifier, char.charIdentifier })
    if ok then TriggerClientEvent('huntingbirds:xpupdate', src, birdId, newXp) end
end)

RegisterNetEvent('huntingbirds:addscavengeditem', function(birdId)
    local src = source
    local char = Srv.char(src)
    birdId = Util.int(birdId, 1)
    if not char or not birdId then return end
    local trip, s = dueTrip(src, char, birdId)
    if not trip or not trip.itemOwed then return end
    trip.itemOwed = false
    finish(s, trip)

    local item, amount = trip.item, trip.amount or 1
    local okCarry, can = pcall(function() return exports.vorp_inventory:canCarryItem(src, item, amount) end)
    if not okCarry or not can then
        Srv.notify(src, Locale.noRoom, 'red')
        return
    end
    local okAdd, added = pcall(function() return exports.vorp_inventory:addItem(src, item, amount) end)
    if not okAdd or added == false then
        Srv.notify(src, Locale.noRoom, 'red')
        return
    end
    local label = (Locale.itemLabels and Locale.itemLabels[item]) or item
    Srv.notify(src, Locale.foundScavItem:format(label), 'gold')
end)
