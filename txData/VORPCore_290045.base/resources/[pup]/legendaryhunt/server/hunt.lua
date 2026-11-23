-- legendaryhunt | server: trap item, lures, cooldowns and the spawn gate
-- the spawn happens on the hunter's client; the server only decides, once per approval, who may start a cooldown and a log line

local TRAP <const> = Config.Items.trap
local APPROVAL_MS <const> = 120000

local function cooldownMs()
    return math.floor((tonumber(Config.Hunt.cooldownMinutes) or 120) * 60000)
end

-- pup-perks server multiplier on the trap waits; 1.0 when pup-perks is missing or fails
local function perkMult(src)
    local res = Config.Integrations.perks
    if GetResourceState(res) ~= 'started' then return 1.0 end
    local ok, m = pcall(function() return exports[res]:Mult(src, Config.Integrations.perkKey) end)
    m = ok and tonumber(m) or nil
    if not m or m ~= m or m <= 0 then return 1.0 end
    return m
end

-- shortest honest time from taking a trap out to the spawn check (both perk-scaled waits, less 10%); sooner gets no approval
local function minWaitMs(src)
    if Config.Hunt.serverMinWait == false then return 0 end
    local m = perkMult(src)
    local function scaled(s) return math.max(1, math.floor((tonumber(s) or 0) * m)) end
    local secs = scaled(Config.Hunt.callSeconds) + scaled(Config.Hunt.activateSeconds)
    return math.floor(secs * 900) -- 90% of secs, in ms
end

local function activeUntil(map, key, now)
    local t = map[key]
    if t and t > now then return t end
    if t then map[key] = nil end
    return nil
end

-- the trap item: using it asks the client whether a trap can be taken out now
CreateThread(function()
    Wait(500) -- let vorp_inventory finish starting
    local ok, err = pcall(function()
        exports.vorp_inventory:registerUsableItem(TRAP, function(data)
            local src = data and tonumber(data.source)
            if not src or not Srv.character(src) then return end
            Srv.UseGrant[src] = GetGameTimer()
            TriggerClientEvent('legendaryhunt:useTrap', src)
        end, GetCurrentResourceName())
    end)
    if not ok then Srv.warnOnce('register', 'could not register the trap item as usable: ' .. tostring(err)) end
end)

-- the client has started holding a trap: take one from the satchel or make it give the trap back
RegisterNetEvent('legendaryhunt:takeTrap', function()
    local src = source
    if not Srv.valid(src) then return end
    local function reply(ok) TriggerClientEvent('legendaryhunt:takeResult', src, ok) end

    local grant = Srv.UseGrant[src]
    Srv.UseGrant[src] = nil
    if not grant or GetGameTimer() - grant > 15000 or not Srv.allow(src, 'take', 1500) then return reply(false) end

    local char = Srv.character(src)
    if not char then return reply(false) end
    local cid = char.charIdentifier

    if Srv.Out[src] then
        Srv.tip(src, Rules.text('trapAlreadyPlaced'))
        return reply(false)
    end

    local entry = { charId = cid, busy = true }
    Srv.Out[src] = entry
    local removed = Srv.subItem(src, TRAP, 1)

    -- re-check after the await: dropped, switched or stopped while vorp_inventory worked
    if entry.cancelled or Srv.Out[src] ~= entry then
        if removed then Srv.owe(cid, 1) end
        return
    end
    if not removed then
        Srv.Out[src] = nil
        Srv.tip(src, Rules.text('noTrapItem'))
        return reply(false)
    end
    if Srv.charId(src) ~= cid then
        Srv.Out[src] = nil
        Srv.owe(cid, 1)
        return reply(false)
    end
    entry.busy = nil
    entry.at = GetGameTimer()
    reply(true)
end)

-- the trap comes back: only one the server saw leave this character's satchel
RegisterNetEvent('legendaryhunt:returnTrap', function()
    local src = source
    if not Srv.valid(src) or not Srv.allow(src, 'return', 1000) then return end
    local out = Srv.Out[src]
    if not out or out.busy then return end
    local cid = Srv.charId(src)

    Srv.Out[src] = nil
    Srv.Approval[src] = nil
    if cid == nil or cid ~= out.charId then
        Srv.owe(out.charId, 1)
        return
    end
    if Srv.giveItem(src, TRAP, 1) then
        Srv.tip(src, Rules.text('trapReturned'))
    else
        -- kept as owed: handed back automatically once the satchel has room
        Srv.owe(cid, 1)
        Srv.tip(src, Config.Text.noRoomReturn)
    end
end)

-- a lure goes into the trap: only configured lures, label from the server's list
RegisterNetEvent('legendaryhunt:addLure', function(item)
    local src = source
    if not Srv.valid(src) or type(item) ~= 'string' then return end
    local label = Rules.lureLabel[item]
    if not label then return end
    local out = Srv.Out[src]
    if not out or out.busy or not Srv.allow(src, 'lure', 1000) then return end
    local cid = Srv.charId(src)
    if cid == nil or cid ~= out.charId then return end

    local ok = Srv.subItem(src, item, 1)
    if ok and Srv.charId(src) ~= cid then return end -- switched mid-await; the client was reset
    if not ok then Srv.tip(src, Rules.text('noBaitItem')) end
    TriggerClientEvent('legendaryhunt:lureResult', src, ok, item, label)
end)

-- advisory only: tell the hunter right after placing if nothing can come for a while
RegisterNetEvent('legendaryhunt:peek', function(id)
    local src = source
    if not Srv.valid(src) or not Srv.allow(src, 'peek', 3000) then return end
    local animal = Rules.animal(id)
    local cid = Srv.charId(src)
    if not animal or cid == nil then return end
    id = math.floor(tonumber(id))

    local now = GetGameTimer()
    local mine = activeUntil(Srv.HunterCd, cid, now)
    if mine then
        Srv.tipRight(src, Rules.text('peekYou'):format(Rules.minutesLeft(mine - now)), 9000)
        return
    end
    local theirs = activeUntil(Srv.AnimalCd, id, now)
    if theirs then
        local name = type(animal.name) == 'string' and animal.name or Config.Text.fallbackName
        Srv.tipRight(src, Rules.text('peekAnimal'):format(name, Rules.minutesLeft(theirs - now)), 9000)
    end
end)

-- the real check at spawn time; approves this hunter for this one legendary
RegisterNetEvent('legendaryhunt:check', function(id, reqId)
    local src = source
    if not Srv.valid(src) then return end
    Srv.Approval[src] = nil
    reqId = math.floor(tonumber(reqId) or 0)
    local function reply(onCooldown) TriggerClientEvent('legendaryhunt:checkResult', src, reqId, onCooldown) end

    if not Srv.allow(src, 'check', 3000) then return reply(true) end
    local animal = Rules.animal(id)
    local cid = Srv.charId(src)
    local out = Srv.Out[src]
    -- no trap out (never taken, or taken without the item) is a refusal, not a free spawn
    if not animal or cid == nil or not out or out.busy or out.charId ~= cid then return reply(true) end
    id = math.floor(tonumber(id))

    local now = GetGameTimer()
    if not out.at or now - out.at < minWaitMs(src) then return reply(true) end
    if activeUntil(Srv.HunterCd, cid, now) or activeUntil(Srv.AnimalCd, id, now) then return reply(true) end

    Srv.Approval[src] = { id = id, charId = cid, at = now }
    reply(false)
end)

-- the hunt log, only under an approval and at most once a minute per player
RegisterNetEvent('legendaryhunt:log', function(zoneName)
    local src = source
    if not Srv.valid(src) then return end
    local ap = Srv.Approval[src]
    local char = Srv.character(src)
    if not ap or not char or char.charIdentifier ~= ap.charId then return end
    local now = GetGameTimer()
    local last = Srv.LastLog[src]
    local gap = (tonumber(Config.Discord.rateLimitSeconds) or 60) * 1000
    if last and now - last < gap then return end
    Srv.LastLog[src] = now
    local animal = Rules.animal(ap.id)
    HuntLog.hunt(src, char, animal and animal.name or '?', zoneName)
end)

-- the legendary is out: start both cooldowns and spend the approval
RegisterNetEvent('legendaryhunt:spawned', function(id)
    local src = source
    if not Srv.valid(src) then return end
    local ap = Srv.Approval[src]
    id = tonumber(id)
    if not ap or not id or ap.id ~= id then return end
    Srv.Approval[src] = nil
    local now = GetGameTimer()
    if now - ap.at > APPROVAL_MS or Srv.charId(src) ~= ap.charId then return end
    local untilMs = now + cooldownMs()
    Srv.AnimalCd[ap.id] = untilMs
    Srv.HunterCd[ap.charId] = untilMs
end)
