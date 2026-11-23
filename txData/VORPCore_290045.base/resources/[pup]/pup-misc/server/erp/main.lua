-- pup-misc | erp, server half. Holds the pending invite and is the only thing
-- that tells a client to play: a sender cannot start anything on its own.

local pending = {}  -- [targetSrc] = { from = src, key = , at = os.time() }
local lastUse = {}  -- [src] = GetGameTimer()

local function emoteByKey(key)
    for _, e in ipairs(ErpConfig.Emotes or {}) do
        if e.key == key then return e end
    end
end

local function tip(src, msg)
    TriggerClientEvent('vorp:TipRight', src, msg, 4000)
end

local function pedCoords(src)
    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- the server can only check the spot list: map districts are a client native.
-- Each client re-checks its own district before it plays, and both of them have
-- to agree for anything to happen
local function spotAllowed(coords, emote)
    local z <const> = ErpConfig.Zones or {}
    if z.enforce == false then return true end
    -- hug, slap and kiss are ordinary roleplay and are not held to the zone list
    if emote and emote.anywhere then return true end
    if #(z.spots or {}) == 0 then return nil end -- nothing to say, defer to the clients
    for _, s in ipairs(z.spots) do
        local dx, dy, dz = coords.x - s.x, coords.y - s.y, coords.z - s.z
        local r <const> = tonumber(s.radius) or 20.0
        if (dx * dx + dy * dy + dz * dz) <= (r * r) then return true end
    end
    return nil -- might still be inside an allowed district
end

local function bothInRange(a, b)
    local ca, cb = pedCoords(a), pedCoords(b)
    if not ca or not cb then return false end
    return #(ca - cb) <= ((tonumber(ErpConfig.Invite.range) or 3.0) + 0.5)
end

RegisterNetEvent('pup-misc:erp:invite', function(targetSrc, key)
    local src <const> = source
    targetSrc = tonumber(targetSrc)
    if not targetSrc or targetSrc == src or not GetPlayerName(targetSrc) then return end

    local gap <const> = (tonumber(ErpConfig.Invite.cooldownSeconds) or 3) * 1000
    if GetGameTimer() - (lastUse[src] or 0) < gap then return end
    lastUse[src] = GetGameTimer()

    local e <const> = emoteByKey(key)
    if not e then return end
    if not bothInRange(src, targetSrc) then return tip(src, ErpLocale.tooFar) end

    local here <const> = pedCoords(src)
    if here and spotAllowed(here, e) == false then return tip(src, ErpLocale.notHere) end

    -- an invite already waiting on them is not replaced, so nobody can be spammed
    local p = pending[targetSrc]
    if p and (os.time() - p.at) < (tonumber(ErpConfig.Invite.timeoutSeconds) or 20) then
        return tip(src, ErpLocale.alreadyWaiting)
    end

    local entry <const> = { from = src, key = key, at = os.time() }
    pending[targetSrc] = entry
    TriggerClientEvent('pup-misc:erp:incoming', targetSrc, src, key, GetPlayerName(src))
    tip(src, ErpLocale.sent)

    -- nobody answered: the sender hears about it and the slot is free again
    SetTimeout((tonumber(ErpConfig.Invite.timeoutSeconds) or 20) * 1000, function()
        if pending[targetSrc] ~= entry then return end
        pending[targetSrc] = nil
        tip(src, ErpLocale.noAnswer)
    end)
end)

RegisterNetEvent('pup-misc:erp:answer', function(yes)
    local src <const> = source
    local p <const> = pending[src]
    pending[src] = nil
    if not p then return end

    if (os.time() - p.at) >= (tonumber(ErpConfig.Invite.timeoutSeconds) or 20) then return end
    if not GetPlayerName(p.from) then return end

    if yes ~= true then
        return tip(p.from, ErpLocale.declined)
    end

    -- re-checked on acceptance: they may have walked off while deciding
    if not bothInRange(src, p.from) then
        tip(p.from, ErpLocale.movedAway)
        return tip(src, ErpLocale.tooFarNow)
    end

    local e <const> = emoteByKey(p.key)
    if not e then return end

    TriggerClientEvent('pup-misc:erp:play', p.from, p.key, 'player', src)
    TriggerClientEvent('pup-misc:erp:play', src, p.key, 'target', p.from)
end)

AddEventHandler('playerDropped', function()
    local src <const> = source
    pending[src] = nil
    for target, p in pairs(pending) do
        if p.from == src then pending[target] = nil end
    end
    lastUse[src] = nil
end)
