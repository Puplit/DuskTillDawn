-- pup-stable | care: feeding, brushing, stims, bonding rewards, saddlebags, lockers, lanterns, pelts

local Inv = exports.vorp_inventory
local careCooldown = {}   -- [horseId][kind] = os.time() of last reward

------------------------------------------------------------------------------
-- bonding from care (also the export skinanimals calls)
------------------------------------------------------------------------------
local function nearestTracked(src, radius)
    local p = PedPos(src)
    if not p then return nil end
    local best, bestD = nil, radius
    for id, t in pairs(Tracked) do
        if DoesEntityExist(t.ent) then
            local d = #(GetEntityCoords(t.ent) - p)
            if d <= bestD then best, bestD = Horses[id], d end
        end
    end
    return best
end

function CareReward(src, kind, item, horseId)
    local cfg = Config.Bonding[kind]
    if not cfg then return end
    local ctx = Ctx(src)
    if not ctx then return end
    local radius = cfg.radius or 4.0
    local h
    if horseId then
        h = Horses[U.int(horseId, -1)]
        if h and not (HorseEnt[h.id] and EntNear(src, HorseEnt[h.id], radius)) then h = nil end
    end
    h = h or nearestTracked(src, radius)
    if not h or h.isDead then return end
    if cfg.ownerOnly and (h.charid ~= ctx.charid or h.identifier ~= ctx.identifier) then return end
    local itemXP = item and Config.Items[item] and Config.Items[item].xp or 0
    careCooldown[h.id] = careCooldown[h.id] or {}
    local now = os.time()
    local last = careCooldown[h.id][kind]
    if not last or now - last >= cfg.cooldown then
        careCooldown[h.id][kind] = now
        local before = h.st.bonding
        h.st.bonding = U.clamp(before + cfg.points, 0, Config.Stats.bondCeiling)
        h.st.xp = h.st.xp + (h.st.bonding - before)
    end
    if itemXP > 0 then h.st.xp = h.st.xp + itemXP end
    MarkStats(h)
    PublishStats(h)
    TryRanks(h, OwnerSrc(h))
end

exports('HorseCareReward', function(playerServerId, kind, item, horseId)
    local ok, err = pcall(CareReward, tonumber(playerServerId), kind, item, horseId)
    if not ok then print('[pup-stable] HorseCareReward failed: ' .. tostring(err)) end
end)

------------------------------------------------------------------------------
-- items
------------------------------------------------------------------------------
local function count(src, item)
    local ok, n = pcall(function() return Inv:getItemCount(src, nil, item) end)
    return ok and U.int(n, 0) or 0
end

local function take(src, item)
    local ok, done = pcall(function() return Inv:subItem(src, item, 1) end)
    return ok and done ~= false
end

-- the stable horse the client points at: tagged, alive, within the server reach
local function careTarget(ctx, netId)
    local ent = EntFromNet(netId, 1000)
    if not ent or GetEntityType(ent) ~= 1 then return nil end
    local h = HorseOfEnt(ent, ctx)
    if not h then return nil end
    if not EntNear(ctx.src, ent, Config.CareReach.server) then return nil end
    return h, ent
end

for name, it in pairs(Config.Items) do
    pcall(function()
        Inv:registerUsableItem(name, function(data)
            local src = data and data.source
            if not src or not Ctx(src) then return end
            if it.kind == 'coat' then
                TriggerClientEvent('pup-stable:coatChanger', src)
            else
                TriggerClientEvent('pup-stable:useItem', src, name)
            end
            pcall(function() Inv:closeInventory(src) end)
        end, RES)
    end)
end

Rpc('careUse', { gap = 1500 }, function(ctx, item, netId)
    local it = Config.Items[item]
    if not it or it.kind == 'coat' then return false end
    local h = careTarget(ctx, netId)
    if not h then return false, L('noHorseNear') end
    if h.isDead then return false, L('beyondMedicine') end
    if count(ctx.src, item) < 1 then return false, L('noItemTo', it.kind == 'brush' and L('verbBrush') or L('verbFeed')) end
    if it.consume and not take(ctx.src, item) then return false end
    -- re-check after the inventory call
    if not Horses[h.id] or h.isDead then return false end
    if it.kind == 'feed' then CareReward(ctx.src, 'feed', item, h.id)
    elseif it.kind == 'brush' then CareReward(ctx.src, 'brush', item, h.id) end
    return true, it
end)

-- the game's feed interaction: first feed item the player carries, in priority order
Rpc('feed', { gap = 1500 }, function(ctx, netId)
    local h = careTarget(ctx, netId)
    if not h then return false end
    if h.isDead then return false, L('beyondMedicine') end
    for _, item in ipairs(Config.FeedOrder) do
        if count(ctx.src, item) > 0 then
            local it = Config.Items[item]
            if it.consume and not take(ctx.src, item) then return false end
            CareReward(ctx.src, 'feed', item, h.id)
            return true, item, it
        end
    end
    return false, L('noItemTo', L('verbFeed'))
end)

------------------------------------------------------------------------------
-- custom inventories
------------------------------------------------------------------------------
local watch = {}   -- src -> { inv, ent, misses, staff }

local function register(id, label, size)
    local ok, exists = pcall(function() return Inv:isCustomInventoryRegistered(id) end)
    local data = {
        id = id, name = label, limit = size.slots, acceptWeapons = size.weapons ~= false, shared = true, ignoreItemStackLimit = true,
        whitelistItems = false, UsePermissions = false, UseBlackList = false, whitelistWeapons = false,
    }
    if Config.Saddlebag.enforceWeight and size.weight then data.useWeight, data.weight = true, size.weight + 0.0 end
    if not (ok and exists) then
        pcall(function() Inv:registerInventory(data) end)
    else
        pcall(function() Inv:updateCustomInventorySlots(id, size.slots) end)
    end
end

function BagInvName(compId) return 'saddlebagID_' .. compId end
function LockerInvName(wagonId) return 'wagonID_' .. wagonId end

local function allowed(rule, ctx, ownerCharid, ownerIdent)
    if rule == 2 then return true end
    if rule == 1 then return ctx.charid == ownerCharid and ctx.identifier == ownerIdent end
    return false
end

function OpenBag(src, h, compId, staff)
    local inv = BagInvName(compId)
    register(inv, L('saddlebag'), BagSize(h))
    local ok = pcall(function() Inv:openInventory(src, inv) end)
    if ok then watch[src] = { inv = inv, ent = HorseEnt[h.id], misses = 0, staff = staff } end
    return ok
end

function OpenLocker(src, w, staff)
    local inv = LockerInvName(w.id)
    local size = LockerSize(w)
    register(inv, L('wagon'), size)
    pcall(function() Inv:updateCustomInventorySlots(inv, size.slots) end)
    local ok = pcall(function() Inv:openInventory(src, inv) end)
    if ok then watch[src] = { inv = inv, ent = WagonEnt[w.id], misses = 0, staff = staff } end
    return ok
end

Rpc('openBag', { gap = 800 }, function(ctx, netId)
    local ent = EntFromNet(netId, 1000)
    local h = HorseOfEnt(ent, ctx)
    if not h then return false end
    local bag = HorseCompOf(h, 'horse_saddlebags')
    if not bag then return false, L('noSaddlebag') end
    if not allowed(Config.Saddlebag.access, ctx, h.charid, h.identifier) then return false end
    if not EntNear(ctx.src, ent, Config.Saddlebag.serverReach) then return false end
    return OpenBag(ctx.src, h, bag.id, false)
end)

Rpc('openLocker', { gap = 800 }, function(ctx, netId)
    local ent = EntFromNet(netId, 1000)
    local w = WagonOfEnt(ent, ctx)
    if not w then return false end
    if not allowed(Config.Locker.access, ctx, w.charid, w.identifier) then return false end
    if not EntNear(ctx.src, ent, Config.Locker.serverReach) then return false end
    return OpenLocker(ctx.src, w, false)
end)

-- close an open bag/locker when its animal or wagon is gone or the player walked off
CreateThread(function()
    while true do
        Wait(Config.InventoryWatch.everyMs)
        for src, w in pairs(watch) do
            local open = nil
            local ok, cur = pcall(function() return Inv:getOpenCustomInventory(src) end)
            if ok then open = cur end
            if open ~= w.inv then
                watch[src] = nil
            elseif not w.staff then
                local fine = w.ent and DoesEntityExist(w.ent) and EntNear(src, w.ent, Config.InventoryWatch.distance)
                w.misses = fine and 0 or (w.misses + 1)
                if w.misses >= Config.InventoryWatch.polls then
                    watch[src] = nil
                    pcall(function() Inv:closeInventory(src, w.inv) end)
                end
            end
        end
    end
end)

function DropWatch(src) watch[src] = nil end

------------------------------------------------------------------------------
-- carrying the saddlebag or the lantern
------------------------------------------------------------------------------
local function carry(src) return Player(src).state.pup_stable_carry or {} end

local function setCarry(src, key, compId)
    local c = carry(src)
    local n = { saddlebag = c.saddlebag, lantern = c.lantern }
    n[key] = compId or nil
    Player(src).state:set('pup_stable_carry', n, true)
end

local function takeOff(ctx, netId, category, key, reach)
    local ent = EntFromNet(netId, 1000)
    local h = HorseOfEnt(ent, ctx)
    if not h or h.charid ~= ctx.charid or h.identifier ~= ctx.identifier then return false, L('notYourHorse') end
    if not EntNear(ctx.src, ent, reach) then return false end
    if carry(ctx.src)[key] then return false, key == 'saddlebag' and L('hasSatchel') or nil end
    local c = HorseCompOf(h, category)
    if not c then return false, key == 'saddlebag' and L('noSaddlebag') or nil end
    SetCompOn(c, -1)
    setCarry(ctx.src, key, c.id)
    Entity(ent).state:set(key == 'saddlebag' and 'pup_stable_saddlebagID' or 'pup_stable_lanternID', false, true)
    return true, CompPayload(c)
end

local function putBack(ctx, netId, category, key, reach)
    local compId = carry(ctx.src)[key]
    local c = compId and OwnedComp(ctx, compId)
    if not c or c.category ~= category then setCarry(ctx.src, key, nil) return false end
    local ent = EntFromNet(netId, 1000)
    local h = HorseOfEnt(ent, ctx)
    if not h or h.charid ~= ctx.charid or h.identifier ~= ctx.identifier then return false, L('notYourHorse') end
    if not EntNear(ctx.src, ent, reach) then return false end
    if HorseCompOf(h, category) then return false, key == 'saddlebag' and L('hasSaddlebag') or nil end
    SetCompOn(c, h.id)
    setCarry(ctx.src, key, nil)
    Entity(ent).state:set(key == 'saddlebag' and 'pup_stable_saddlebagID' or 'pup_stable_lanternID', c.id, true)
    return true, CompPayload(c)
end

Rpc('takeBag', { gap = 1000 }, function(ctx, netId) return takeOff(ctx, netId, 'horse_saddlebags', 'saddlebag', Config.Saddlebag.serverReach) end)
Rpc('putBag', { gap = 1000 }, function(ctx, netId) return putBack(ctx, netId, 'horse_saddlebags', 'saddlebag', Config.Saddlebag.serverReach) end)
Rpc('takeLantern', { gap = 1000 }, function(ctx, netId) return takeOff(ctx, netId, 'saddle_lanterns', 'lantern', Config.Lantern.serverReach) end)
Rpc('putLantern', { gap = 1000 }, function(ctx, netId) return putBack(ctx, netId, 'saddle_lanterns', 'lantern', Config.Lantern.serverReach) end)

-- a carried bag/lantern goes back to storage (disconnect, character switch)
function ReturnCarried(src, charid)
    local okS, c = pcall(function() return Player(src).state.pup_stable_carry end)
    if not okS then c = nil end
    if type(c) == 'table' then
        for _, compId in pairs(c) do
            local comp = Comps[U.int(compId, -1)]
            if comp and comp.on == -1 and (not charid or comp.charid == charid) then SetCompOn(comp, 0) end
        end
    end
    -- the player's state bag may already be gone on a drop; sweep that character's
    -- own records as well so nothing stays "carried" until the next restart
    if charid then
        for id in pairs(CharComps[charid] or {}) do
            local comp = Comps[id]
            if comp and comp.on == -1 then SetCompOn(comp, 0) end
        end
    end
    if GetPlayerName(src) then Player(src).state:set('pup_stable_carry', {}, true) end
end

------------------------------------------------------------------------------
-- pelts stowed on a horse
------------------------------------------------------------------------------
-- the server's own list of what was stowed on each horse; the state bag only mirrors it for display
local Stowed = {}    -- [horse entity] = { { type, model }, ... }
local StowedObj = {} -- [pelt object] = true once it went onto a horse (one object stows once)

local function stowedOf(ent)
    for e in pairs(Stowed) do if not DoesEntityExist(e) then Stowed[e] = nil end end
    for o in pairs(StowedObj) do if not DoesEntityExist(o) then StowedObj[o] = nil end end
    Stowed[ent] = Stowed[ent] or {}
    return Stowed[ent]
end

-- the pelt the player holds: a real object of that model right beside them that was not stowed before
local function heldPelt(src, model)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local at = GetEntityCoords(ped)
    for _, obj in ipairs(GetAllObjects()) do
        if not StowedObj[obj] and (GetEntityModel(obj) & 0xFFFFFFFF) == (model & 0xFFFFFFFF)
            and #(GetEntityCoords(obj) - at) <= 4.0 then
            return obj
        end
    end
    return nil
end

Rpc('stowPelt', { gap = 800 }, function(ctx, netId, peltType, peltModel)
    if not Config.Pelts.enabled then return false end
    local ent = EntFromNet(netId, 1000)
    local h = HorseOfEnt(ent, ctx)
    if not h or h.charid ~= ctx.charid or h.identifier ~= ctx.identifier then return false, L('notYourHorse') end
    if not EntNear(ctx.src, ent, Config.Pelts.serverReach) then return false end
    local model = math.tointeger(U.int(peltModel))
    if not model or model == 0 then return false end
    local stowed = stowedOf(ent)
    if #stowed >= Config.Pelts.max then return false end
    if Config.Pelts.requireObject ~= false then
        local obj = heldPelt(ctx.src, model)
        if not obj then return false end
        StowedObj[obj] = true
    end
    stowed[#stowed + 1] = { type = U.int(peltType, 0), model = model }
    Entity(ent).state:set('pup_stable_stow', U.copy(stowed), true)
    CareReward(ctx.src, 'stow', nil, h.id)
    return true, #stowed
end)

Rpc('unstowPelt', { gap = 800 }, function(ctx, netId)
    local ent = EntFromNet(netId, 1000)
    local h = ent and HorseOfEnt(ent, ctx)
    if not h or h.charid ~= ctx.charid or h.identifier ~= ctx.identifier then return false, L('notYourHorse') end
    if not EntNear(ctx.src, ent, Config.Pelts.serverReach) then return false end
    local stowed = stowedOf(ent)
    local top = stowed[#stowed]
    if not top then return false end
    if not top.model or top.model == 0 then return false, L('peltNoModel') end
    stowed[#stowed] = nil
    Entity(ent).state:set('pup_stable_stow', U.copy(stowed), true)
    return true, { type = top.type, model = top.model }
end)

Rpc('clearPelts', { gap = 500 }, function(ctx, netId)
    local ent = EntFromNet(netId, 1000)
    if not ent or not HorseOfEnt(ent) then return false end
    if not EntNear(ctx.src, ent, Config.Pelts.serverReach) then return false end
    local n = #(Entity(ent).state.pup_stable_stow or {})
    Stowed[ent] = nil
    Entity(ent).state:set('pup_stable_stow', {}, true)
    return true, n
end)
