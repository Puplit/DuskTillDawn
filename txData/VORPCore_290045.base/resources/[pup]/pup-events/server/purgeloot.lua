-- pup-events | THE PURGE: loot caches, server half.
-- One cache at a time, announced in chat, and it stands open a while once cracked.
-- Each is a custom inventory, deleted and re-registered on spawn so nothing carries over.

local Core = exports.vorp_core:GetCore()

local live = false
local active = nil     -- key of the cache currently out, or nil between spawns
local nextAt = 0       -- os.time() the next one is due
local expireAt = 0     -- os.time() the current one gives up waiting, 0 = never
local queue = {}       -- sites still to come this cycle, in shuffled order
local lastKey = nil    -- the one that just ran, so a new cycle cannot repeat it
local stocked = {}     -- key -> true once its loot has been rolled
local cracked = false  -- the one that is out has been forced and is standing open

local function invId(key)
    return 'pup_purge_' .. tostring(key)
end

local function siteByKey(key)
    for _, site in ipairs(Config.PurgeCaches.sites or {}) do
        if tostring(site.key) == tostring(key) then return site end
    end
end

-- only sites with real coordinates take part
local function rotation()
    local out = {}
    for _, site in ipairs(Config.PurgeCaches.sites or {}) do
        if PurgeLootConfigured(site) then out[#out + 1] = site end
    end
    return out
end

local function charIdOf(src)
    local ok, user = pcall(function() return Core.getUser(src) end)
    if not ok or not user then return nil end
    local ch = user.getUsedCharacter
    if type(ch) ~= 'table' then return nil end
    return tonumber(ch.charIdentifier)
end

-- top notification titled with the cache name, and chat as well so anyone looking
-- away still has it to scroll back to
local function announce(line, where)
    TriggerClientEvent('vorp:ShowTopNotification', -1, where or (Locale.purgeCaches.chatTitle or 'PURGE'), line, 7000)
    TriggerClientEvent('chat:addMessage', -1, {
        args = { Locale.purgeCaches.chatTitle or 'PURGE', line }
    })
end

local function minutes(n, fallback)
    return (tonumber(n) or fallback) * 60
end

-- SPAWN / DESPAWN ---------------------------------------------------------

-- the registration must outlive the crack: vorp_inventory indexes it again from a DB callback
local function releaseInventory(key)
    SetTimeout(300000, function()
        if active == tostring(key) then return end -- came round again, leave it alone
        pcall(function() exports.vorp_inventory:removeInventory(invId(key)) end)
    end)
end

local function despawn(reason)
    if not active then return end
    local key <const> = active
    active, expireAt, cracked = nil, 0, false
    stocked[key] = nil
    releaseInventory(key)
    TriggerClientEvent('pup-events:purgeloot:active', -1, nil)
    TriggerEvent('pup-events:purgeloot:despawned', key, reason)
    nextAt = os.time() + minutes(Config.PurgeCaches.respawnMinutes, 20)
end

local function spawn(site)
    local id <const> = invId(site.key)
    stocked[site.key] = nil
    -- DELETE FIRST: the contents live in the database
    pcall(function() exports.vorp_inventory:deleteCustomInventory(id) end)
    exports.vorp_inventory:registerInventory({
        id                   = id,
        name                 = site.label or Locale.purgeCaches.group,
        limit                = tonumber(Config.PurgeCaches.limit) or 40,
        -- guns go in the crate like anything else
        acceptWeapons        = true,
        shared               = true,
        ignoreItemStackLimit = true,
        UseBlackList         = false,
        whitelistItems       = false,
    })

    active, cracked = site.key, false
    local hold <const> = tonumber(Config.PurgeCaches.expireMinutes) or 0
    expireAt = hold > 0 and (os.time() + hold * 60) or 0

    TriggerClientEvent('pup-events:purgeloot:active', -1, site.key)
    announce((Locale.purgeCaches.spawned):format(site.label or site.key), site.label or site.key)
    TriggerEvent('pup-events:purgeloot:spawned', site.key)
end

-- Fisher-Yates: every site gets one turn per cycle, in a different order
local function reshuffle(list)
    local q = {}
    for i = 1, #list do q[i] = list[i] end
    for i = #q, 2, -1 do
        local j <const> = math.random(i)
        q[i], q[j] = q[j], q[i]
    end
    -- a new cycle must not open on the site the last one closed with
    if #q > 1 and lastKey and q[1].key == lastKey then
        q[1], q[#q] = q[#q], q[1]
    end
    return q
end

local function spawnNext()
    local list <const> = rotation()
    if #list == 0 then return end
    if #queue == 0 then queue = reshuffle(list) end

    local site = table.remove(queue, 1)
    -- edited out of the config since the cycle was drawn
    if not site or not PurgeLootConfigured(site) then return end
    lastKey = site.key
    spawn(site)
end

-- LOOTING -----------------------------------------------------------------

local working = {}   -- key -> src, one cracker at a time
local workingSince = {}   -- key -> GetGameTimer() when they started

-- the client holds a cracker still until the result returns, so one who left does not block others
local function heldByOther(site, src)
    local who <const> = working[site.key]
    if not who or who == src or not GetPlayerName(who) then return false end
    local ped <const> = GetPlayerPed(who)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - site.pos) <= (tonumber(Config.PurgeCaches.distance) or 2.0) + 4.5
end

local function toolOf(site)
    return site.lockpickitem or Config.PurgeCaches.lockpickitem or {}
end

-- live, spawned, and actually standing there
local function usable(src, key)
    if not live or Config.PurgeCaches.enabled == false then return nil end
    if active ~= tostring(key) then return nil end
    local site = siteByKey(key)
    if not site or not PurgeLootConfigured(site) then return nil end

    local okUser, user = pcall(function() return Core.getUser(src) end)
    local who = okUser and user and user.getUsedCharacter
    if type(who) ~= 'table' or who.isdead == true or who.isdead == 1 then return nil end

    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local reach <const> = (tonumber(Config.PurgeCaches.distance) or 2.0) + 1.5
    if #(GetEntityCoords(ped) - site.pos) > reach then
        TriggerClientEvent('vorp:TipRight', src, Locale.purgeCaches.toofar, 4000)
        return nil
    end
    return site
end

-- cash goes to whoever cracked it, once. Items stay in the crate for the crew.
local function payout(src, site)
    local money <const> = tonumber(site.money) or 0
    if money <= 0 then return end
    local ok, user = pcall(function() return Core.getUser(src) end)
    local ch = ok and user and user.getUsedCharacter
    if type(ch) ~= 'table' then return end
    ch.addCurrency(0, money)
    TriggerClientEvent('vorp:TipRight', src, (Locale.purgeCaches.tookmoney):format(money), 5000)
end

-- `done` runs once the loot is in the crate; opening before the DB writes land shows an empty box
local function stock(site, src, done)
    done = done or function() end

    local fired = false
    local function finish()
        if fired then return end
        fired = true
        done()
    end
    -- the callbacks are not guaranteed; a cracked cache must never go unopened
    SetTimeout(4000, finish)

    if stocked[site.key] then return finish() end
    stocked[site.key] = true

    local charid <const> = charIdOf(src)
    if not charid then
        stocked[site.key] = nil
        return finish()
    end

    payout(src, site)

    local roll = {}
    for _, entry in ipairs(site.items or {}) do
        local chance <const> = tonumber(entry.chance) or 100
        local amount <const> = math.floor(tonumber(entry.amount) or 1)
        if amount > 0 and math.random(100) <= chance then
            roll[#roll + 1] = { name = entry.name, amount = amount }
        end
    end
    -- guns are a separate call: weapons live in `loadout`, not the item table
    local guns = {}
    for _, entry in ipairs(site.weapons or {}) do
        local chance <const> = tonumber(entry.chance) or 100
        if entry.name and math.random(100) <= chance then
            guns[#guns + 1] = { name = entry.name }
        end
    end

    -- weapons after the items, then the window: one write at a time, in order
    local function addGuns()
        if #guns == 0 then return finish() end
        local ok <const> = pcall(function()
            exports.vorp_inventory:addWeaponsToCustomInventory(invId(site.key), guns, charid, finish)
        end)
        if not ok then finish() end
    end

    if #roll == 0 then return addGuns() end
    local ok <const> = pcall(function()
        exports.vorp_inventory:addItemsToCustomInventory(invId(site.key), roll, charid, addGuns)
    end)
    if not ok then addGuns() end
end

-- PHASE 1: may they start? The tool is counted HERE, never on the client.
RegisterNetEvent('pup-events:purgeloot:try', function(key)
    local src <const> = source
    local site = usable(src, key)
    if not site then return end

    -- already forced and still standing: no tool, no minigame, just reach in
    if cracked then
        return exports.vorp_inventory:openInventory(src, invId(site.key))
    end

    if heldByOther(site, src) then
        return TriggerClientEvent('vorp:TipRight', src, Locale.purgeCaches.busy, 4000)
    end

    local tool <const> = toolOf(site)
    exports.vorp_inventory:getItemCount(src, function(count)
        if (tonumber(count) or 0) < 1 then
            return TriggerClientEvent('vorp:TipRight', src,
                (Locale.purgeCaches.noitem):format(tool.label or tool.name or 'tool'), 5000)
        end
        -- the count comes back from another resource: look again at what it was asked about
        if active ~= site.key or cracked or heldByOther(site, src) then return end
        if working[site.key] ~= src then
            working[site.key], workingSince[site.key] = src, GetGameTimer()
        end
        TriggerClientEvent('pup-events:purgeloot:begin', src, site.key,
            site.minigame ~= nil and site.minigame or Config.PurgeCaches.minigame,
            tonumber(site.difficulty) or tonumber(Config.PurgeCaches.difficulty) or 3,
            tonumber(site.pryTime) or tonumber(Config.PurgeCaches.pryTime) or 8000)
    end, tool.name)
end)

-- PHASE 2. Distance re-checked, so walking off mid-minigame opens nothing.
RegisterNetEvent('pup-events:purgeloot:result', function(key, success)
    local src <const> = source
    local site = siteByKey(key)
    if not site or working[site.key] ~= src then return end
    -- a success comes after the pry bar, which alone runs for pryTime on the client
    local pry <const> = tonumber(site.pryTime) or tonumber(Config.PurgeCaches.pryTime) or 8000
    if success == true and GetGameTimer() - (workingSince[site.key] or 0) < pry * 0.75 then return end
    working[site.key] = nil

    local tool <const> = toolOf(site)
    if success ~= true then
        pcall(function() exports.vorp_inventory:subItem(src, tool.name, 1) end)
        return TriggerClientEvent('vorp:TipRight', src,
            (Locale.purgeCaches.broke):format(tool.label or tool.name or 'tool'), 5000)
    end

    if not usable(src, key) then return end
    -- expiry off: a cracked crate must not report itself as never visited
    cracked, expireAt = true, 0
    -- opened only once the loot is in it
    stock(site, src, function()
        exports.vorp_inventory:openInventory(src, invId(site.key))
    end)

    announce((Locale.purgeCaches.cracked):format(site.label or site.key), site.label or site.key)

    -- the crate stands open a while so the crew can clear it out, THEN it goes
    local linger <const> = math.max(0, tonumber(Config.PurgeCaches.lingerSeconds) or 60)
    local was <const> = active
    SetTimeout(linger * 1000, function()
        if active == was then despawn('looted') end
    end)
end)

-- ROTATION ----------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(15000)
        if live then
            local now <const> = os.time()
            if active and expireAt > 0 and now >= expireAt then
                local label <const> = (siteByKey(active) or {}).label or active
                announce((Locale.purgeCaches.movedon):format(label), label)
                despawn('expired')
            elseif not active and now >= nextAt then
                spawnNext()
            end
        end
    end
end)

AddEventHandler('pup-events:server:state', function(key, on)
    if key ~= 'purge' or Config.PurgeCaches.enabled == false then return end
    if on == true then
        -- the first cache waits, so its banner does not land on top of the event's own announcement
        -- queue emptied so the first cache of the purge draws a fresh shuffled cycle
        live, queue = true, {}
        nextAt = os.time() + minutes(Config.PurgeCaches.firstCacheMinutes, 2)
        print(('^3[pup-events]^7 purge caches live - first one in %s min, then one at a time')
            :format(tostring(tonumber(Config.PurgeCaches.firstCacheMinutes) or 2)))
    else
        despawn('purge over')
        live, active, nextAt, expireAt, cracked = false, nil, 0, 0, false
        for _, site in ipairs(Config.PurgeCaches.sites or {}) do
            stocked[site.key] = nil
            pcall(function() exports.vorp_inventory:removeInventory(invId(site.key)) end)
        end
        TriggerClientEvent('pup-events:purgeloot:active', -1, nil)
        print('^3[pup-events]^7 purge caches closed')
    end
end)

-- someone joining mid-purge still needs the blip
AddEventHandler('vorp:SelectedCharacter', function(src)
    if src and live and active then
        TriggerClientEvent('pup-events:purgeloot:active', src, active)
    end
end)

-- GUARDS. One client spawns them for everyone; the server picks who, so two
-- arrivals cannot each spawn a set. Deleted by net id afterwards.
local host = {}    -- key -> src running the guards
local nets = {}    -- key -> { netId, ... }

-- read the way client/purgeloot.lua reads it
local function guardCfg(site)
    local d <const> = Config.PurgeCaches.guardDefaults or {}
    local g <const> = type(site.guards) == 'table' and site.guards or {}
    return {
        count   = math.floor(tonumber(g.count) or tonumber(d.count) or 6),
        trigger = tonumber(g.trigger) or tonumber(d.trigger) or 80.0,
        models  = g.models or d.models or {},
    }
end

-- net ids come from a client and get deleted, so only a ped of a guard model qualifies, never a player
local function isGuard(ent, site)
    if not site or GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return false end
    local model <const> = GetEntityModel(ent) % 4294967296.0
    for _, name in ipairs(guardCfg(site).models) do
        if GetHashKey(name) % 4294967296.0 == model then return true end
    end
    return false
end

local function dropGuards(key)
    local site <const> = siteByKey(key)
    for _, netId in ipairs(nets[key] or {}) do
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) and isGuard(ent, site) then DeleteEntity(ent) end
    end
    nets[key] = nil
    host[key] = nil
end

RegisterNetEvent('pup-events:purgeloot:claim', function(key)
    local src <const> = source
    -- only the cache that is actually out can be defended
    if not live or active ~= tostring(key) then return end
    local site = siteByKey(key)
    if not site or not site.guards then return end
    if host[site.key] and GetPlayerName(host[site.key]) then return end
    -- the client asks at the trigger range; the rest is room for lag on a fast horse
    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - site.pos) > guardCfg(site).trigger + 50.0 then return end
    host[site.key] = src
    TriggerClientEvent('pup-events:purgeloot:spawnguards', src, site.key)
end)

RegisterNetEvent('pup-events:purgeloot:guardnets', function(key, list)
    local src <const> = source
    -- the client sends its set once, and a second list would strand the first
    if host[key] ~= src or type(list) ~= 'table' or nets[key] then return end
    local site <const> = siteByKey(key)
    if not site then return end
    local most <const> = guardCfg(site).count
    local clean = {}
    for _, n in ipairs(list) do
        local netId = tonumber(n)
        if netId and netId > 0 then clean[#clean + 1] = netId end
        if #clean >= most then break end
    end
    nets[key] = clean
end)

-- the cache going away takes its guards with it
-- and anyone mid-crack: if the site comes round again that start no longer counts
AddEventHandler('pup-events:purgeloot:despawned', function(key)
    dropGuards(key)
    working[key] = nil
end)

AddEventHandler('playerDropped', function()
    for k, src in pairs(working) do
        if src == source then working[k] = nil end
    end
    -- the host leaving must not strand its guards
    for k, src in pairs(host) do
        if src == source then dropGuards(k) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for k in pairs(host) do dropGuards(k) end
    for _, site in ipairs(Config.PurgeCaches.sites or {}) do
        pcall(function() exports.vorp_inventory:removeInventory(invId(site.key)) end)
    end
end)

-- vorp_admin world cleanup: staff deleted the guards. A cache with none left forgets its
-- host, so the next player to ride up claims it again and the guards come back.
AddEventHandler('vorp_admin:worldCleanupDone', function()
    for key, list in pairs(nets) do
        local any = false
        for _, netId in ipairs(list) do
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) then any = true break end
        end
        if not any then
            nets[key] = nil
            host[key] = nil
        end
    end
end)
