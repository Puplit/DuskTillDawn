-- river + wash barrel | server: the usable items, bottle fill / boil / drink, river
-- drinking, and the poison state (kept per character in the resource KVP so it survives
-- a relog). The client only asks; every swap, roll and cooldown is decided here.

local CFG <const> = WaterConfig
local L <const> = WaterLocale
local ITEMS <const> = CFG.Items
local INV <const> = exports.vorp_inventory

local EV <const> = 'pup-misc:water:'
local KVP_PREFIX <const> = 'water_poison:'

local core = nil

local function dbg(...)
    if CFG.General.debug then print('[pup-misc/river]', ...) end
end

local function getCore()
    if core then return core end
    local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and c then core = c end
    if not core then TriggerEvent('getCore', function(c2) core = c2 end) end
    return core
end

local function charOf(src)
    local c = getCore()
    if not c or not src then return nil end
    local ok, user = pcall(c.getUser, src)
    if not ok or not user then return nil end
    local ch = user.getUsedCharacter
    if not ch or not ch.charIdentifier then return nil end
    return ch
end

local function tip(src, text, ms)
    if text then TriggerClientEvent('vorp:TipRight', src, text, ms or 5000) end
end

local function count(src, item)
    local ok, n = pcall(function() return INV:getItemCount(src, nil, item) end)
    return ok and tonumber(n) or 0
end

local function take(src, item)
    local ok, done = pcall(function() return INV:subItem(src, item, 1) end)
    return ok and done == true
end

local function give(src, item)
    local ok, done = pcall(function() return INV:addItem(src, item, 1) end)
    return ok and done == true
end

-- swap one `from` for one `to`; the `from` is handed back if the add fails
local function swap(src, from, to)
    if not take(src, from) then return false end
    if give(src, to) then return true end
    give(src, from)
    return false
end

local function isBottle(item)
    return item == ITEMS.dirtyBottle or item == ITEMS.cleanBottle
end

local function containerMode()
    return type(ITEMS.emptyBottle) == 'string' and ITEMS.emptyBottle ~= ''
end

-- ------------------------------------------------------------------ poison

local poisoned = {}   -- [src] = { charId, expires } (expires 0 = no time limit)

local function kvpKey(charId) return KVP_PREFIX .. tostring(charId) end

local function secondsLeft(p)
    if not p or p.expires == 0 then return 0 end
    return math.max(1, p.expires - os.time())
end

local function sendPoison(src)
    local p = poisoned[src]
    TriggerClientEvent(EV .. 'poison', src, p ~= nil, secondsLeft(p))
end

local function loadPoison(src, charId)
    poisoned[src] = nil
    if charId then
        local stored = tonumber(GetResourceKvpString(kvpKey(charId)) or '')
        if stored and (stored == 0 or stored > os.time()) then
            poisoned[src] = { charId = charId, expires = stored }
        elseif stored then
            DeleteResourceKvp(kvpKey(charId))
        end
    end
    sendPoison(src)
end

local function setPoison(src, ch)
    local mins = tonumber(CFG.Poison.durationMinutes) or 0
    local expires = mins > 0 and (os.time() + math.floor(mins * 60)) or 0
    local p = poisoned[src]
    -- a fresh dose restarts the clock, it never shortens it
    if p and p.charId == ch.charIdentifier and (p.expires == 0 or (expires ~= 0 and p.expires > expires)) then
        expires = p.expires
    end
    poisoned[src] = { charId = ch.charIdentifier, expires = expires }
    SetResourceKvp(kvpKey(ch.charIdentifier), tostring(expires))
    dbg('poisoned', src, ch.charIdentifier, expires)
    sendPoison(src)
end

local function clearPoison(src)
    local p = poisoned[src]
    if not p then return end
    DeleteResourceKvp(kvpKey(p.charId))
    poisoned[src] = nil
    sendPoison(src)
end

-- the poisoned table only ever holds the character the player is on
local function poisonFor(src, ch)
    local p = poisoned[src]
    if p and ch and p.charId ~= ch.charIdentifier then
        poisoned[src] = nil
        return nil
    end
    return p
end

CreateThread(function()
    while true do
        Wait(10000)
        local t = os.time()
        for src, p in pairs(poisoned) do
            if p.expires ~= 0 and p.expires <= t then
                clearPoison(src)
                tip(src, L.woreOff, 8000)
            end
        end
    end
end)

AddEventHandler('vorp:SelectedCharacter', function(src, character)
    loadPoison(src, character and character.charIdentifier)
end)

local lastSync = {}
RegisterNetEvent(EV .. 'sync', function()
    local src = source
    local t = GetGameTimer()
    if lastSync[src] and t - lastSync[src] < 2000 then return end
    lastSync[src] = t
    local ch = charOf(src)
    if not ch then return end
    loadPoison(src, ch.charIdentifier)
end)

-- ------------------------------------------------------------------ bottles

local used = {}       -- [src] = { item, at } : the last bottle used from the satchel

local function useBottle(data)
    local src = data and data.source
    if not src or not charOf(src) then return end
    local item = data.item and data.item.name
    if type(item) ~= 'string' then return end
    used[src] = { item = item, at = GetGameTimer() }
    pcall(function() INV:closeInventory(src) end)

    local kind = (item == ITEMS.cleanBottle and 'clean') or (item == ITEMS.dirtyBottle and 'dirty') or 'empty'
    TriggerClientEvent(EV .. 'bottle', src, kind, containerMode())
end

-- the recorded use, cleared on read; nil when missing or outside [minMs, maxMs]
local function claimUse(src, minMs, maxMs)
    local u = used[src]
    used[src] = nil
    if not u then return nil end
    local age = GetGameTimer() - u.at
    if age < minMs or age > maxMs then
        dbg('use outside window', src, u.item, age)
        return nil
    end
    return u
end

RegisterNetEvent(EV .. 'fill', function()
    local src = source
    if not charOf(src) then return end
    local w = CFG.Bottles.fillWindow
    local u = claimUse(src, w.min * 1000, w.max * 1000)
    if not u then return end

    -- container mode fills an empty bottle; without it only a dirty bottle is "refilled"
    -- (a clean one is drunk instead, so filling never turns clean water dirty)
    local okItem
    if containerMode() then okItem = u.item == ITEMS.emptyBottle else okItem = u.item == ITEMS.dirtyBottle end
    if not okItem or count(src, u.item) < 1 then return end

    if u.item == ITEMS.dirtyBottle then
        tip(src, L.filled, 5000)   -- already dirty water: nothing to swap
    elseif swap(src, u.item, ITEMS.dirtyBottle) then
        tip(src, L.filled, 5000)
    else
        tip(src, L.failed, 5000)
    end
end)

RegisterNetEvent(EV .. 'boil', function()
    local src = source
    if not CFG.Boil.enabled or not charOf(src) then return end
    local dur = tonumber(CFG.Boil.durationMs) or 10000
    local u = claimUse(src, dur - 1000, dur + (tonumber(CFG.Boil.serverSlackMs) or 15000))
    if not u or u.item ~= ITEMS.dirtyBottle or count(src, u.item) < 1 then return end

    if swap(src, ITEMS.dirtyBottle, ITEMS.cleanBottle) then
        tip(src, L.boiled, 5000)
    else
        tip(src, L.failed, 5000)
    end
end)

RegisterNetEvent(EV .. 'drink', function()
    local src = source
    local ch = charOf(src)
    if not ch then return end
    local u = claimUse(src, 0, (tonumber(CFG.Bottles.useWindowSeconds) or 20) * 1000)
    if not u or not isBottle(u.item) or count(src, u.item) < 1 then return end
    if not take(src, u.item) then return end
    if containerMode() then give(src, ITEMS.emptyBottle) end

    local dirty = u.item == ITEMS.dirtyBottle
    local sick = dirty and math.random(1, math.max(1, CFG.Poison.bottleOdds)) == 1
    if sick then setPoison(src, ch) end
    TriggerClientEvent(EV .. 'drank', src, dirty and 'dirty' or 'clean', sick)
end)

-- ------------------------------------------------------------------ river

local riverAt = {}    -- [src] = GetGameTimer() of the last river drink

RegisterNetEvent(EV .. 'river', function()
    local src = source
    local ch = charOf(src)
    if not ch then return end
    local t = GetGameTimer()
    local cd = (tonumber(CFG.River.drinkCooldownSeconds) or 0) * 1000
    if riverAt[src] and t - riverAt[src] < cd then
        TriggerClientEvent(EV .. 'riverResult', src, nil)
        return
    end
    riverAt[src] = t

    local sick = math.random(1, math.max(1, CFG.Poison.riverOdds)) == 1
    if sick then setPoison(src, ch) end
    TriggerClientEvent(EV .. 'riverResult', src, sick, math.random(1, #L.riverDrank))
end)

-- ------------------------------------------------------------------ antidote

local function useAntidote(data)
    local src = data and data.source
    local ch = src and charOf(src)
    if not ch then return end
    if not poisonFor(src, ch) then
        tip(src, L.notPoisoned, 5000)
        return
    end
    pcall(function() INV:closeInventory(src) end)
    if not take(src, ITEMS.antidote) then return end
    clearPoison(src)
    TriggerClientEvent(EV .. 'cured', src)
    tip(src, L.usedAntidote, 5000)
end

-- ------------------------------------------------------------------ setup

CreateThread(function()
    while GetResourceState('vorp_inventory') ~= 'started' do Wait(100) end
    local res = GetCurrentResourceName()
    INV:registerUsableItem(ITEMS.dirtyBottle, useBottle, res)
    INV:registerUsableItem(ITEMS.cleanBottle, useBottle, res)
    if containerMode() then INV:registerUsableItem(ITEMS.emptyBottle, useBottle, res) end
    INV:registerUsableItem(ITEMS.antidote, useAntidote, res)
    dbg('items registered')
end)

AddEventHandler('playerDropped', function()
    local src = source
    used[src], riverAt[src], poisoned[src], lastSync[src] = nil, nil, nil, nil
end)
