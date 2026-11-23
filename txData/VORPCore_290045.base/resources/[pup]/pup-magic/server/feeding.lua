-- pup-magic | vampire feeding: putting a player victim down, NPC feeds, rewards and bottled blood
-- A feed is only paid when this server saw it start (pup-magic:putDown or pup-magic:feedNpc),
-- on the same target, about feedMs earlier, with both still close together.

local F <const> = Config.Feeding
local B <const> = Config.Blood
local GAP <const> = math.floor((tonumber(F.cooldownMs) or 0) * 0.9)
local VICTIM_CAP <const> = (tonumber(F.feedMs) or 0) + (tonumber(F.victimExtraMs) or 0) + 2000

local lastPutDown = {} -- [src] = GetGameTimer() of the last accepted feed start (player or NPC)
local lastFeed    = {} -- [src] = GetGameTimer() of the last paid feed
local started     = {} -- [src] = { kind = 'player'|'npc', target = server id | net id, at = ms }
local accepted    = {} -- [src] = true between a paid player feed and its vial step (used once)
local startAsk, doneAsk = {}, {}
local biteMemory  = {} -- ['<vampire char>:<victim char>'] = ms of the last vial

local BENEFIT_ORDER <const> = {
    'hunger', 'thirst', 'metabolism',
    'staminaInner', 'staminaInnerGold', 'staminaOuterGold',
    'healthInner', 'healthInnerGold', 'healthOuterGold',
}

local function feedStartAllowed(src)
    if not IsVampire(src) or not CharOf(src) then return false end
    local last = lastPutDown[src]
    return not last or GetGameTimer() - last >= GAP
end

---------------------------------------------------------------------------
-- feed start: a player victim
---------------------------------------------------------------------------
RegisterNetEvent('pup-magic:putDown', function(victim, durationMs, heading)
    local src = PlayerIdOf(source)
    if not src or not Throttle(startAsk, src, 500) then return end
    if not feedStartAllowed(src) then return end

    victim = PlayerIdOf(victim)
    if not victim or victim == src then return end
    if not PlayersWithin(src, victim, B.maxBiteDistance) then return end

    local dur = tonumber(durationMs)
    if not dur or dur ~= dur or dur <= 0 then dur = tonumber(F.victimDefaultMs) or VICTIM_CAP end
    dur = math.floor(math.min(dur, VICTIM_CAP))

    local h = tonumber(heading)
    if h and (h ~= h or h == math.huge or h == -math.huge) then h = nil end
    if h then h = h % 360.0 end

    local now = GetGameTimer()
    lastPutDown[src] = now
    started[src] = { kind = 'player', target = victim, at = now }
    TriggerClientEvent('pup-magic:victim', victim, dur, h)
end)

---------------------------------------------------------------------------
-- feed start: an NPC
---------------------------------------------------------------------------
local function npcNear(src, netId)
    netId = math.tointeger(tonumber(netId))
    if not netId or netId <= 0 then return nil end
    local ok, ent = pcall(NetworkGetEntityFromNetworkId, netId)
    if not ok or not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return nil end
    local me = PosOf(src)
    if not me or #(me - GetEntityCoords(ent)) > (tonumber(B.maxBiteDistance) or 0) then return nil end
    return netId
end

RegisterNetEvent('pup-magic:feedNpc', function(netId)
    local src = PlayerIdOf(source)
    if not src or not Throttle(startAsk, src, 500) then return end
    if not feedStartAllowed(src) then return end
    netId = npcNear(src, netId)
    if not netId then
        if Config.General.debug then print(('[pup-magic] NPC feed start from %d refused: no such NPC near them'):format(src)) end
        return
    end
    local now = GetGameTimer()
    lastPutDown[src] = now
    started[src] = { kind = 'npc', target = netId, at = now }
end)

---------------------------------------------------------------------------
-- feed done: benefits, items, then (player feeds only) the vial
---------------------------------------------------------------------------
local function giveBenefits(src, kind)
    if GetResourceState('fred_metabolism') ~= 'started' then
        WarnOnce('fred', 'fred_metabolism is not running: feeding gives no food or water')
        return
    end
    local b = F.benefits and F.benefits[kind]
    if type(b) ~= 'table' then return end
    local v = {}
    for i, name in ipairs(BENEFIT_ORDER) do v[i] = tonumber(b[name]) or 0 end
    -- fred_meta:consume is a net event in fred_metabolism, so the server hands over its own numbers
    TriggerClientEvent('fred_meta:consume', src, v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9])
end

local function giveRewards(src, isPlayer)
    local list = isPlayer and F.playerRewards or F.npcRewards
    for _, r in ipairs(type(list) == 'table' and list or {}) do
        if type(r) == 'table' then
            local name = r.name
            local count = (type(r.count) == 'number') and math.floor(r.count) or 1
            if type(name) == 'string' and name:match('%S') and count > 0 then
                if Inv.canCarry(src, name, count) then
                    Inv.add(src, name, count)
                elseif Config.General.debug then
                    print(('[pup-magic] %d had no room for %dx %s'):format(src, count, name))
                end
            end
        end
    end
    local msg = isPlayer and Locale.feedPlayerReward or Locale.feedNpcReward
    local ms = tonumber(isPlayer and F.playerTipMs or F.npcTipMs) or 3000
    if type(msg) == 'string' and msg ~= '' then TipBottom(src, msg, ms) end
end

local function vialsHeld(src)
    if MagicLimits.countNpcVials ~= false then return Inv.count(src, B.item) end
    local n = 0
    for _, it in ipairs(Inv.items(src)) do
        if type(it) == 'table' and it.name == B.item and type(it.metadata) == 'table' and it.metadata.bloodChar then
            n = n + (tonumber(it.count) or 1)
        end
    end
    return n
end

local function bottleBlood(src, victim)
    if not accepted[src] then return end
    accepted[src] = nil

    if victim == src or not Online(victim) then return end
    local vamp, prey = CharOf(src), CharOf(victim)
    if not vamp or not prey or vamp.id == prey.id then return end

    local pa, pb = PosOf(src), PosOf(victim)
    if pa and pb and not AtOrigin(pa) and not AtOrigin(pb) and #(pa - pb) > (tonumber(B.maxBiteDistance) or 0) then return end

    local pair = vamp.id .. ':' .. prey.id
    local now = GetGameTimer()
    local wait = tonumber(B.sameVictimCooldownMs) or 0
    if wait > 0 and biteMemory[pair] and now - biteMemory[pair] < wait then
        TipBottom(src, Locale.vialAlready, 4000)
        return
    end

    local name = Trim((prey.first or '') .. ' ' .. (prey.last or ''))
    if name == '' then name = Locale.aStranger end

    local max = tonumber(B.maxVials) or 0
    if max > 0 and vialsHeld(src) >= max then
        TipBottom(src, Locale.vialFull, 4000)
        return
    end
    if not Inv.canCarry(src, B.item, 1) then
        TipBottom(src, Locale.vialNoRoom, 4000)
        return
    end

    -- the inventory calls can wait: the vampire must still be the same character
    local still = CharOf(src)
    if not still or still.id ~= vamp.id then return end

    -- forget pairs whose wait is over, so the memory cannot grow for the whole uptime
    for k, at in pairs(biteMemory) do
        if now - at >= wait then biteMemory[k] = nil end
    end
    biteMemory[pair] = now
    local shown = EscapeHtml(name) -- label and description are drawn as HTML by the inventory
    local ok = Inv.add(src, B.item, 1, {
        label       = Locale.vialLabel:format(shown),
        description = Locale.vialDesc:format(shown),
        image       = 'drugvialofblood',
        bloodChar   = prey.id,
        bloodName   = name,
    })
    if ok then TipBottom(src, Locale.vialBottled, 4000) end
end

RegisterNetEvent('pup-magic:feedDone', function(kind, target)
    local src = PlayerIdOf(source)
    if not src then return end
    accepted[src] = nil
    if not Throttle(doneAsk, src, 1000) then return end
    if not IsVampire(src) or not CharOf(src) then return end

    local now = GetGameTimer()
    if lastFeed[src] and now - lastFeed[src] < GAP then return end

    local isPlayer = (kind == 'player')
    local s = started[src]
    started[src] = nil
    if not s or s.kind ~= (isPlayer and 'player' or 'npc') then return end

    -- the client waits feedMs between start and done; allow some drift either way
    local elapsed = now - s.at
    local feedMs = tonumber(F.feedMs) or 0
    if elapsed < feedMs * 0.8 or elapsed > VICTIM_CAP + 10000 then return end

    local victim
    if isPlayer then
        victim = PlayerIdOf(target)
        if not victim or victim ~= s.target or victim == src then return end
        if not PlayersWithin(src, victim, B.maxBiteDistance) then return end
    else
        if not npcNear(src, s.target) then return end
    end

    lastFeed[src] = now
    accepted[src] = true

    giveBenefits(src, isPlayer and 'player' or 'npc')
    giveRewards(src, isPlayer)
    if isPlayer then
        bottleBlood(src, victim)
    else
        accepted[src] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = math.tointeger(tonumber(source))
    if not src then return end
    lastPutDown[src], lastFeed[src], started[src], accepted[src] = nil, nil, nil, nil
    startAsk[src], doneAsk[src] = nil, nil
end)
