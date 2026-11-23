-- pup-misc / bountyhunting - server half
-- The server rolls the contract, owns its purse, accepts only peds the leader's own client
-- created for it, checks every hand-over against the real entity, and pays.
-- All state is in memory: cooldowns and open contracts are gone after a restart.

local Core = exports.vorp_core:GetCore()
local Cfg = BountyConfig
local Data = BountyShared
local Text = BountyLocale

local EV <const> = 'pup-misc:bountyhunting:'

local contracts = {} -- [leaderSrc] = contract
local memberOf  = {} -- [src] = leaderSrc, for the leader and every partner
local pedIndex  = {} -- [netId] = contract, every ped any contract registered
local cooldowns = {} -- [charIdentifier] = os.time() when the character may take work again
local lastHit   = {} -- [src] = { [event] = GetGameTimer() }
local warned    = {}
local nextId    = 0

-- which roles each kind may register, and what pool the role's model must come from
local ROLES <const> = {
    kill   = { hostile = true },
    arrest = { hostile = true, target = true },
    escort = { client = true, attacker = true },
}

local function trace(fmt, ...)
    if Cfg.Debug then print(('[pup-misc:bountyhunting] ' .. fmt):format(...)) end
end

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[pup-misc:bountyhunting]^7 %s'):format(msg))
end

local function limited(src, name, ms)
    local now = GetGameTimer()
    local t = lastHit[src]
    if not t then
        t = {}
        lastHit[src] = t
    end
    if t[name] and now - t[name] < ms then return true end
    t[name] = now
    return false
end

-- model hashes compared as unsigned 32-bit, whatever sign a native hands back
local function modelKey(h)
    h = math.tointeger(tonumber(h) or 0) or 0
    return h % 0x100000000
end

local function isInt(n)
    return type(n) == 'number' and n == math.floor(n)
end

local function online(src)
    return src and GetPlayerName(src) ~= nil
end

local function charOf(src)
    local ok, user = pcall(Core.getUser, src)
    if not ok or not user then return nil end
    local char = user.getUsedCharacter
    if type(char) ~= 'table' or not char.charIdentifier then return nil end
    return char
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function dist(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

local function refuse(src, key, arg)
    TriggerClientEvent(EV .. 'refused', src, key, arg)
end

local function entityAt(netId)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    return ent
end

local function setCooldown(charid)
    local minutes = tonumber(Cfg.Cooldown.Minutes) or 0
    if minutes <= 0 or not charid then return end
    cooldowns[charid] = os.time() + math.floor(minutes * 60)
end

------------------------------------------------------------------------------ peds

-- a registered ped still is the ped it was when it registered (net ids get reused)
local function stillOurs(rec, netId)
    local ent = entityAt(netId)
    if not ent or ent ~= rec.ent then return nil end
    if modelKey(GetEntityModel(ent)) ~= rec.model then return nil end
    return ent
end

local function forgetPed(c, netId)
    if pedIndex[netId] == c then pedIndex[netId] = nil end
end

-- delete every ped of this contract that still exists and is still the same ped
local function sweep(c)
    for netId, rec in pairs(c.peds) do
        local ent = stillOurs(rec, netId)
        if ent and GetEntityType(ent) == 1 and not IsPedAPlayer(ent) then
            DeleteEntity(ent)
        end
        forgetPed(c, netId)
    end
end

------------------------------------------------------------------------------ ending

local function partnersOf(c)
    local list = {}
    for _, m in ipairs(c.members) do
        if m ~= c.leader then list[#list + 1] = m end
    end
    return list
end

-- reason: 'done' | 'abandon' | 'failed' | 'lost' | 'closed'
local function endContract(leader, reason, now)
    local c = contracts[leader]
    if not c then return end
    contracts[leader] = nil
    c.over = true
    trace('contract %d (%s) ended: %s', c.id, c.kind, reason)

    for _, m in ipairs(c.members) do
        if memberOf[m] == leader then memberOf[m] = nil end
        if online(m) then TriggerClientEvent(EV .. 'ended', m, c.id, reason) end
    end

    if Cfg.Cooldown.StartsAt == 'end' then
        setCooldown(c.charid)
        if Cfg.Cooldown.Partners then
            for _, cid in ipairs(c.partnerChars) do setCooldown(cid) end
        end
    end

    -- the leader's client removes its peds after the end pause; the server takes the rest
    if now then
        sweep(c)
    else
        SetTimeout(((tonumber(Cfg.Contracts.EndPauseSeconds) or 5) + 3) * 1000, function() sweep(c) end)
    end
end

-- src stops taking part in whatever contract it is on (character switch, disconnect)
local function leaveAll(src, now)
    if contracts[src] then
        endContract(src, 'closed', now)
        return
    end
    local leader = memberOf[src]
    if not leader then return end
    memberOf[src] = nil
    local c = contracts[leader]
    if not c then return end
    for i = #c.members, 1, -1 do
        if c.members[i] == src then table.remove(c.members, i) end
    end
    if online(src) then TriggerClientEvent(EV .. 'ended', src, c.id, 'closed') end
end

------------------------------------------------------------------------------ payment

local function awardPerk(src)
    local key = Cfg.Payout.PerkKey
    if not key or key == '' then return end
    if GetResourceState('pup-perks') ~= 'started' then
        warnOnce('perks-missing', 'pup-perks is not started; bounty perk XP is skipped')
        return
    end
    local ok, err = pcall(function() exports['pup-perks']:Award(src, key) end)
    if not ok then warnOnce('perks-error', ('pup-perks Award failed: %s'):format(tostring(err))) end
end

local function pay(c, claimant, cash, gold)
    cash = math.max(0, math.min(cash, c.leftCash))
    gold = math.max(0, math.min(gold, c.leftGold))
    c.leftCash = c.leftCash - cash
    c.leftGold = c.leftGold - gold

    local P = Cfg.Payout
    local mult = tonumber(P.Multiplier) or 0
    local amount = math.floor(cash * mult)
    if amount > (P.MaxCash or 0) then amount = P.MaxCash or 0 end
    local goldAmount = gold * mult
    if goldAmount > (P.MaxGold or 0) then goldAmount = P.MaxGold or 0 end
    goldAmount = math.floor(goldAmount * 100) / 100
    if amount <= 0 and goldAmount <= 0 then return end

    local here = pedCoords(claimant)
    if not here then return end
    local radius = tonumber(P.Radius) or 40.0
    local recipients = { claimant }
    for _, m in ipairs(c.members) do
        if m ~= claimant and online(m) then
            local at = pedCoords(m)
            if at and dist(at, here) <= radius then recipients[#recipients + 1] = m end
        end
    end

    if P.SplitAmongPresent and #recipients > 1 then
        amount = math.floor(amount / #recipients)
        goldAmount = math.floor(goldAmount / #recipients * 100) / 100
    end

    for _, r in ipairs(recipients) do
        local char = charOf(r)
        if char then
            if amount > 0 then char.addCurrency(0, amount) end
            if goldAmount > 0 then char.addCurrency(1, goldAmount) end
            TriggerClientEvent('vorp:TipRight', r, Text.paid:format(tostring(amount)), 4000)
            awardPerk(r)
            trace('paid %s $%d gold %.2f (contract %d)', r, amount, goldAmount, c.id)
        end
    end
end

------------------------------------------------------------------------------ contract helpers

-- the leader must still be allowed to hunt; otherwise the contract is called off
local function leaderStillValid(c)
    local char = charOf(c.leader)
    if not char or char.charIdentifier ~= c.charid then
        endContract(c.leader, 'closed', true)
        return false
    end
    if not Data.jobAllowed(char.job) then
        endContract(c.leader, 'closed')
        return false
    end
    return true
end

local function contractOf(src, id)
    local c = contracts[src]
    if not c or c.over or c.id ~= id then return nil end
    return c
end

local function relay(c, name, ...)
    for _, m in ipairs(partnersOf(c)) do
        if online(m) then TriggerClientEvent(EV .. name, m, c.id, ...) end
    end
end

local function roleCap(c, role)
    local block = c.block
    if role == 'hostile' then return type(block.enemies) == 'table' and #block.enemies or 0 end
    if role == 'target' then return type(block.targets) == 'table' and #block.targets or 0 end
    if role == 'client' then return 1 end
    if role == 'attacker' then
        if not c.escortStart then return 0 end
        local perWave = type(block.enemies) == 'table' and #block.enemies or 0
        local interval = math.max(1, tonumber(block.spawnIntervalSeconds) or 100)
        local first = tonumber(Cfg.Contracts.FirstWaveSeconds) or interval
        local elapsed = os.time() - c.escortStart
        if elapsed + 5 < first then return 0 end
        local waves = 1 + math.floor(math.max(0, elapsed - first) / interval) + 1 -- one wave of slack for timing
        return perWave * waves
    end
    return 0
end

local function poolHashes(c, role)
    c.poolCache = c.poolCache or {}
    local name = Data.poolName(c.kind, c.block, role)
    if c.poolCache[name] then return c.poolCache[name] end
    local set = {}
    for _, model in ipairs(Data.pool(name) or {}) do set[modelKey(GetHashKey(model))] = true end
    c.poolCache[name] = set
    return set
end

local function firstOwnerIs(ent, src)
    if not NetworkGetFirstEntityOwner then
        warnOnce('first-owner', 'NetworkGetFirstEntityOwner is not available; ped ownership is checked by model and distance only')
        return true
    end
    local ok, owner = pcall(NetworkGetFirstEntityOwner, ent)
    if not ok then
        warnOnce('first-owner-err', 'NetworkGetFirstEntityOwner failed; ped ownership is checked by model and distance only')
        return true
    end
    return owner == src
end

local function acceptPed(c, role, netId, ent)
    if pedIndex[netId] or c.peds[netId] then return false end
    if GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return false end
    if (c.roleCount[role] or 0) >= roleCap(c, role) then return false end
    local model = modelKey(GetEntityModel(ent))
    if not poolHashes(c, role)[model] then return false end
    if not firstOwnerIs(ent, c.leader) then return false end

    local pos = GetEntityCoords(ent)
    if role == 'attacker' then
        local leaderAt = pedCoords(c.leader)
        if not leaderAt or dist(pos, leaderAt) > 250.0 then return false end
    elseif dist(pos, c.start) > 250.0 then
        return false
    end

    c.peds[netId] = { role = role, ent = ent, model = model }
    c.roleCount[role] = (c.roleCount[role] or 0) + 1
    pedIndex[netId] = c
    return true
end

-- wanted men: done when every one is handed in or lost
local function arrestSettled(c)
    local anyLost = false
    for _, rec in pairs(c.peds) do
        if rec.role == 'target' then
            if not rec.done and not rec.lost then return false end
            if rec.lost then anyLost = true end
        end
    end
    return true, anyLost
end

local function killSettled(c)
    local any = false
    for _, rec in pairs(c.peds) do
        if rec.role == 'hostile' then
            any = true
            if not rec.done then return false end
        end
    end
    return any
end

------------------------------------------------------------------------------ approval

local function roll(town, count)
    local anyHere = false
    local options = {}
    for _, kind in ipairs(Data.KINDS) do
        local list = Data.contracts(kind, town)
        if list and #list > 0 then
            anyHere = true
            local fits = {}
            for i = 1, #list do
                if Data.block(kind, town, i, count) then fits[#fits + 1] = i end
            end
            if #fits > 0 then options[#options + 1] = { kind = kind, list = fits } end
        end
    end
    if #options == 0 then return nil, nil, anyHere and 'notAtRank' or 'noContracts' end
    local pick = options[math.random(#options)]
    return pick.kind, pick.list[math.random(#pick.list)]
end

RegisterNetEvent(EV .. 'request', function(boardIndex, count, partners)
    local src = source
    if limited(src, 'request', 3000) then return end

    boardIndex, count = tonumber(boardIndex), tonumber(count)
    local board = isInt(boardIndex) and Cfg.Boards[boardIndex] or nil
    if not board then return end

    local char = charOf(src)
    if not char then return end

    local at = pedCoords(src)
    if not at or dist(at, board.coords) > (Cfg.BoardPromptDistance + (Cfg.BoardServerSlack or 6.0)) then
        trace('%s asked for work away from board %d', src, boardIndex)
        return
    end

    if memberOf[src] and memberOf[src] ~= src then return refuse(src, 'busy') end

    -- 1. job (leader only, unless PartnersNeedJob)
    if not Data.jobAllowed(char.job) then return refuse(src, 'refused') end

    -- 2. partner ids: every one must be online; duplicates and the leader's own id drop out
    local members, seen = { src }, { [src] = true }
    if type(partners) == 'table' then
        local maxPartners = math.max(0, (Cfg.Party.MaxHunters or 4) - 1)
        for i = 1, maxPartners do
            local raw = partners[i]
            if raw == nil then break end
            local id = tonumber(raw)
            if not isInt(id) or id <= 0 then return refuse(src, 'notOnline', 0) end
            if not online(id) then return refuse(src, 'notOnline', id) end
            -- partners ride with the leader, so they have to be here with them
            local pat = id ~= src and pedCoords(id) or at
            if not pat or dist(pat, at) > (Cfg.Party.PartnerDistance or 10.0) then
                return refuse(src, 'partnerFar', id)
            end
            if not seen[id] then
                seen[id] = true
                members[#members + 1] = id
            end
        end
    end

    -- 3. the party size picked must match the distinct hunters named
    if not isInt(count) or count < 1 or count > (Cfg.Party.MaxHunters or 4) or count ~= #members then
        return refuse(src, 'partyMismatch', math.max(0, (isInt(count) and count or 1) - 1))
    end

    local partnerChars = {}
    for i = 2, #members do
        local id = members[i]
        -- riding with this same leader is fine: that old contract is replaced below
        local leaderOf = memberOf[id]
        if leaderOf and leaderOf ~= src then return refuse(src, 'partnerBusy', id) end
        local pchar = charOf(id)
        if Cfg.Party.PartnersNeedJob and not (pchar and Data.jobAllowed(pchar.job)) then
            return refuse(src, 'partnerNoJob', id)
        end
        if pchar then partnerChars[#partnerChars + 1] = pchar.charIdentifier end
    end

    -- 4. cooldown (per character)
    local charid = char.charIdentifier
    local free = cooldowns[charid]
    if free and free > os.time() then
        local minutes = math.ceil((free - os.time()) / 60)
        return refuse(src, 'cooldown', minutes)
    end

    -- roll before anything is spent: a board with nothing for this party costs nothing
    local kind, idx, why = roll(board.town, count)
    if not kind then return refuse(src, why) end
    local block, ct = Data.block(kind, board.town, idx, count)
    if not block then return refuse(src, 'notAtRank') end

    -- a fresh approval replaces an old contract this leader still had
    if contracts[src] then endContract(src, 'closed', true) end

    nextId = nextId + 1
    local shareCash, shareGold, units = Data.share(kind, block)
    local c = {
        id = nextId,
        leader = src,
        charid = charid,
        partnerChars = partnerChars,
        town = board.town,
        kind = kind,
        idx = idx,
        count = count,
        block = block,
        start = ct.coords,
        drop = ct.dropCoords,
        members = members,
        leftCash = math.max(0, tonumber(block.rewardCash) or 0),
        leftGold = math.max(0, tonumber(block.rewardGold) or 0),
        shareCash = shareCash,
        shareGold = shareGold,
        units = units,
        peds = {},
        roleCount = {},
        stage = 'travel',
    }
    contracts[src] = c
    for _, m in ipairs(members) do memberOf[m] = src end

    if Cfg.Cooldown.StartsAt ~= 'end' then
        setCooldown(charid)
        if Cfg.Cooldown.Partners then
            for _, cid in ipairs(partnerChars) do setCooldown(cid) end
        end
    end

    trace('contract %d: %s %s #%d for %d (leader %s)', c.id, kind, board.town, idx, count, src)
    local payload = { id = c.id, kind = kind, town = board.town, idx = idx, count = count }
    payload.leader = true
    TriggerClientEvent(EV .. 'begin', src, payload)
    payload.leader = false
    for i = 2, #members do TriggerClientEvent(EV .. 'begin', members[i], payload) end
end)

------------------------------------------------------------------------------ the leader's peds

local function afterRegister(c, role, accepted)
    if role == 'hostile' then
        if c.stage == 'travel' then c.stage = (c.kind == 'kill') and 'fight' or c.stage end
        if Cfg.Contracts.HostileMarkers then relay(c, 'marks', 'hostile', accepted, false) end
    elseif role == 'target' then
        c.stage = 'deliver'
        relay(c, 'stage', 'deliver')
        relay(c, 'marks', 'target', accepted, true)
    elseif role == 'client' then
        c.stage = 'escort'
        c.escortStart = os.time()
        relay(c, 'stage', 'escort')
        relay(c, 'marks', 'client', accepted, false)
    elseif role == 'attacker' then
        if Cfg.Contracts.ShareAttackerMarkers then relay(c, 'marks', 'attacker', accepted, false) end
    end
end

-- a contract whose key peds never registered can never pay or settle: close it as failed
-- instead of leaving the leader on a contract that cannot end
local function essential(c, role)
    return role == 'client' or role == 'target' or (role == 'hostile' and c.kind == 'kill')
end

local function noneRegistered(src, c, role)
    if not essential(c, role) or c.roleCount[role] then return end
    trace('contract %d: no %s ped registered, closing it', c.id, role)
    endContract(src, 'failed')
end

RegisterNetEvent(EV .. 'register', function(id, role, list)
    local src = source
    if limited(src, 'register:' .. tostring(role), 300) then return end
    local c = contractOf(src, id)
    if not c then return end
    if type(role) ~= 'string' or not ROLES[c.kind][role] then return end
    if type(list) ~= 'table' or #list == 0 or #list > 40 then return end
    if role == 'client' and c.roleCount.client then return end
    if (role == 'hostile' or role == 'target') and c.roleCount[role] and c.roleCount[role] >= roleCap(c, role) then return end

    local pending = {}
    for i = 1, #list do
        local n = tonumber(list[i])
        if isInt(n) and n > 0 and not pedIndex[n] then pending[#pending + 1] = n end
    end
    if #pending == 0 then return noneRegistered(src, c, role) end

    CreateThread(function()
        local accepted = {}
        -- a freshly made ped can take a moment to reach the server
        for _ = 1, 12 do
            for i = #pending, 1, -1 do
                if contracts[src] ~= c or c.over then return end
                local ent = entityAt(pending[i])
                if ent then
                    local netId = table.remove(pending, i)
                    if acceptPed(c, role, netId, ent) then accepted[#accepted + 1] = netId end
                end
            end
            if #pending == 0 then break end
            Wait(250)
        end
        if contracts[src] ~= c or c.over then
            for _, n in ipairs(accepted) do forgetPed(c, n) end
            return
        end
        if #pending > 0 then trace('contract %d: %d %s ped(s) never reached the server', c.id, #pending, role) end
        if #accepted > 0 then
            afterRegister(c, role, accepted)
        else
            noneRegistered(src, c, role)
        end
    end)
end)

-- kill: every outlaw is down, time to haul the bodies
RegisterNetEvent(EV .. 'cleared', function(id)
    local src = source
    if limited(src, 'cleared', 1000) then return end
    local c = contractOf(src, id)
    if not c or c.kind ~= 'kill' or c.stage ~= 'fight' then return end
    for netId, rec in pairs(c.peds) do
        if rec.role == 'hostile' then
            local ent = stillOurs(rec, netId)
            if ent and GetEntityHealth(ent) > 0 then
                trace('contract %d: cleared refused, %d still alive', c.id, netId)
                return
            end
        end
    end
    c.stage = 'deliver'
    TriggerClientEvent(EV .. 'stage', src, c.id, 'deliver')
    relay(c, 'stage', 'deliver')
end)

------------------------------------------------------------------------------ hand-overs

-- the entity handed in, matched to a registered ped directly or through the hunting
-- wagon's 'network' state (pup_camps puts the original net id on a carcass it gives back)
local function resolveCarried(c, netId)
    local ent = entityAt(netId)
    if not ent then return nil end
    local rec = c.peds[netId]
    if rec and rec.ent == ent then return rec, netId, ent, false end

    local orig = tonumber(Entity(ent).state.network)
    if not isInt(orig) then return nil end
    rec = c.peds[orig]
    if not rec or rec.model ~= modelKey(GetEntityModel(ent)) then return nil end
    -- only when the original is really gone (stowed), never a copy beside the real one
    if stillOurs(rec, orig) then return nil end
    return rec, orig, ent, true
end

RegisterNetEvent(EV .. 'deliver', function(id, netId)
    local src = source
    if limited(src, 'deliver', 2000) then return end
    local c = contractOf(src, id)
    if not c or c.stage ~= 'deliver' or (c.kind ~= 'kill' and c.kind ~= 'arrest') then return end
    netId = tonumber(netId)
    if not isInt(netId) then return end

    local at = pedCoords(src)
    if not at or dist(at, c.drop) > (Cfg.Contracts.HandoverDistance or 10.0) + 5.0 then return end

    local rec, key, ent, viaWagon = resolveCarried(c, netId)
    if not rec or rec.done or rec.lost then return end
    if dist(GetEntityCoords(ent), at) > 10.0 then return end

    if c.kind == 'kill' then
        if rec.role ~= 'hostile' then return end
        if not viaWagon and GetEntityHealth(ent) > 0 then return end
    else
        if rec.role ~= 'target' then return end
        if GetEntityHealth(ent) <= 0 then return end
    end

    if not leaderStillValid(c) then return end

    rec.done = true
    forgetPed(c, key)
    DeleteEntity(ent)
    TriggerClientEvent(EV .. 'delivered', src, c.id, key)
    pay(c, src, c.shareCash, c.shareGold)

    if c.kind == 'kill' then
        if killSettled(c) then endContract(src, 'done') end
    else
        local settled, anyLost = arrestSettled(c)
        if settled then endContract(src, (anyLost and Cfg.Contracts.DeadTargetFails) and 'failed' or 'done') end
    end
end)

-- capture: a wanted man died or vanished
RegisterNetEvent(EV .. 'lost', function(id, netId)
    local src = source
    if limited(src, 'lost', 500) then return end
    local c = contractOf(src, id)
    if not c or c.kind ~= 'arrest' then return end
    netId = tonumber(netId)
    local rec = isInt(netId) and c.peds[netId] or nil
    if not rec or rec.role ~= 'target' or rec.done or rec.lost then return end
    local ent = stillOurs(rec, netId)
    if ent and GetEntityHealth(ent) > 0 then return end

    rec.lost = true
    local settled = arrestSettled(c)
    if settled then
        endContract(src, Cfg.Contracts.DeadTargetFails and 'failed' or 'lost')
    end
end)

-- escort: the client reached the destination
RegisterNetEvent(EV .. 'escortDone', function(id)
    local src = source
    if limited(src, 'escortDone', 2000) then return end
    local c = contractOf(src, id)
    if not c or c.kind ~= 'escort' or c.stage ~= 'escort' then return end

    local clientNet, clientRec
    for netId, rec in pairs(c.peds) do
        if rec.role == 'client' then clientNet, clientRec = netId, rec end
    end
    if not clientRec or clientRec.done then return end
    local ent = stillOurs(clientRec, clientNet)
    if not ent or GetEntityHealth(ent) <= 0 then return end
    if dist(GetEntityCoords(ent), c.drop) > (Cfg.Contracts.EscortArriveDistance or 2.0) + 3.0 then return end
    local at = pedCoords(src)
    if not at or dist(at, c.drop) > (Cfg.Payout.Radius or 40.0) then return end

    if not leaderStillValid(c) then return end

    clientRec.done = true
    forgetPed(c, clientNet)
    DeleteEntity(ent)
    pay(c, src, c.shareCash, c.shareGold)
    endContract(src, 'done')
end)

-- the leader calls it off or reports a failure (death, dead or tied client)
RegisterNetEvent(EV .. 'finish', function(id, reason)
    local src = source
    if limited(src, 'finish', 1000) then return end
    local c = contractOf(src, id)
    if not c then return end
    if reason ~= 'abandon' and reason ~= 'failed' then return end
    endContract(src, reason)
end)

------------------------------------------------------------------------------ world cleanup
-- vorp_admin's "Clear spawned entities". A contract whose outlaw, wanted man or client staff
-- deleted can never be finished, so it is closed (as on a character switch). Only peds seen
-- just before the sweep count: a body already put in a hunting wagon is not there either.
local cleanupSeen = {}

AddEventHandler('vorp_admin:worldCleanup', function()
    cleanupSeen = {}
    for leader, c in pairs(contracts) do
        for netId, rec in pairs(c.peds) do
            if rec.role ~= 'attacker' and not rec.done and not rec.lost and stillOurs(rec, netId) then
                cleanupSeen[#cleanupSeen + 1] = { c = c, leader = leader, netId = netId, rec = rec }
            end
        end
    end
end)

AddEventHandler('vorp_admin:worldCleanupDone', function()
    local ended = {}
    for _, s in ipairs(cleanupSeen) do
        if contracts[s.leader] == s.c and not ended[s.leader] and not s.rec.done and not s.rec.lost
            and not stillOurs(s.rec, s.netId) then
            ended[s.leader] = true
            endContract(s.leader, 'closed', true)
        end
    end
    cleanupSeen = {}
end)

------------------------------------------------------------------------------ lifecycle

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if src then leaveAll(src, true) end
end)

AddEventHandler('vorp:playerJobChange', function(src, newJob)
    src = tonumber(src)
    local c = src and contracts[src]
    if c and not Data.jobAllowed(newJob) then endContract(src, 'closed') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    leaveAll(src, true)
    memberOf[src] = nil
    lastHit[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, c in pairs(contracts) do sweep(c) end
end)

-- expired cooldowns are dropped once an hour so the table cannot grow forever
CreateThread(function()
    while true do
        Wait(3600000)
        local now = os.time()
        for charid, free in pairs(cooldowns) do
            if free <= now then cooldowns[charid] = nil end
        end
    end
end)

-- one look at the data at start: a pool or town name typo shows up in the console, not mid-contract
CreateThread(function()
    local towns = {}
    for _, b in ipairs(Cfg.Boards) do towns[b.town] = true end
    for _, kind in ipairs(Data.KINDS) do
        local key = ({ kill = 'Kill', arrest = 'Arrest', escort = 'Escort' })[kind]
        for town, list in pairs(Cfg[key] or {}) do
            if not towns[town] then
                print(('^3[pup-misc:bountyhunting]^7 %s contracts for "%s" have no board'):format(kind, town))
            end
            for i, ct in ipairs(list) do
                for count in pairs(ct.levels or {}) do
                    if not Data.block(kind, town, i, count) then
                        print(('^3[pup-misc:bountyhunting]^7 %s %s #%d level %s cannot be played (missing pool or peds)'):format(kind, town, i, tostring(count)))
                    end
                end
            end
        end
    end
end)
