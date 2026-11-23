-- pup-events | The Spring Hunt, server.
-- Patches roll fresh every reset anywhere inside Config.Easter.regions.

local Core = exports.vorp_core:GetCore()

local patches    = {}   -- [i] = { name, centre, eggs = { [id] = egg } }
local generation = 0
local opening    = {}   -- src -> true while a gold egg is being rolled
-- [charId] = { [patch] = eggs taken }; cleared on every roll
local pickedUp   = {}

EVT.easter = EVT.easter or {}

local function live() return EVT.live and EVT.live.easter == true end

local function notify(src, msg, ms) Core.NotifyRightTip(src, msg, ms or 4000) end

local function charOf(src)
    local user = Core.getUser(src)
    return user and user.getUsedCharacter or nil
end

-- ===========================================================================
-- WEBHOOK  (URL from server/config.lua, never from a shared file)
-- ===========================================================================
local hookQueue, hookBusy = {}, false

local function drainHooks()
    if hookBusy or #hookQueue == 0 then return end
    hookBusy = true
    local entry = table.remove(hookQueue, 1)
    PerformHttpRequest(entry.url, function() end, 'POST', json.encode(entry.payload),
        { ['Content-Type'] = 'application/json' })
    SetTimeout(3000, function() hookBusy = false drainHooks() end)
end

local function playerFields(src)
    local ch = charOf(src)
    local name = ch and ((ch.firstname or '') .. ' ' .. (ch.lastname or '')) or 'Unknown'
    local charId = ch and tostring(ch.charIdentifier or 'N/A') or 'N/A'
    local steam, discord = 'N/A', 'N/A'
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 6) == 'steam:' then steam = id
        elseif id:sub(1, 8) == 'discord:' then discord = '<@' .. id:sub(9) .. '>' end
    end
    return {
        { name = 'Character', value = name,    inline = true },
        { name = 'Char ID',   value = charId,  inline = true },
        { name = 'Discord',   value = discord, inline = true },
        { name = 'Steam',     value = steam,   inline = false },
    }, name
end

local function hook(which, title, desc, color, fields)
    local W = (Config.Logs or {}).easter or {}
    local hooks = (Secrets or {}).Webhooks or {}
    local url = ({ goldPickup = hooks.easterGoldPickup, goldOpen = hooks.easterGoldOpen })[which]
    if type(url) ~= 'string' or url == '' then return end
    hookQueue[#hookQueue + 1] = { url = url, payload = {
        content = (W.pingEveryone and which == 'goldPickup') and '@everyone' or '',
        embeds = { {
            title = title, description = desc, color = color, fields = fields,
            footer = { text = ((Config.Logs or {}).serverName or 'Server') .. ' - Spring Hunt' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    } }
    drainHooks()
end

-- ===========================================================================
-- ROLLING THE PATCHES
-- ===========================================================================
local function randomIn(region)
    return vector3(
        region.x1 + math.random() * (region.x2 - region.x1),
        region.y1 + math.random() * (region.y2 - region.y1),
        0.0)
end

local function scatter(centre, n)
    local out, id = {}, 0
    for _ = 1, n do
        local ok
        for _ = 1, 20 do
            local a = math.random() * math.pi * 2.0
            local d = math.sqrt(math.random()) * Config.Easter.patches.radius
            local p = vector3(centre.x + math.cos(a) * d, centre.y + math.sin(a) * d, 0.0)
            local clear = true
            for _, e in pairs(out) do
                if #(vector2(p.x, p.y) - vector2(e.x, e.y)) < (Config.Easter.patches.minSpacing or 2.0) then
                    clear = false break
                end
            end
            if clear then ok = p break end
        end
        if ok then
            id = id + 1
            out[id] = { id = id, x = ok.x, y = ok.y,
                        model = Config.Easter.eggModels[math.random(#Config.Easter.eggModels)],
                        heading = math.random() * 360.0 }
        end
    end
    return out
end

local function rollPatches()
    patches = {}
    generation = generation + 1
    pickedUp = {}

    local lo, hi = Config.Easter.patches.count[1], Config.Easter.patches.count[2]
    local total = 0
    for i = 1, math.random(lo, hi) do
        local region <const> = Config.Easter.regions[math.random(#Config.Easter.regions)]
        local centre <const> = randomIn(region)
        local eggs <const> = scatter(centre, math.random(Config.Easter.patches.eggs[1], Config.Easter.patches.eggs[2]))
        local n = 0
        for _ in pairs(eggs) do n = n + 1 end
        total = total + n
        patches[i] = { name = region.name, centre = centre, eggs = eggs }
    end

    EVT.easter.patches = patches
    EVT.easter.generation = generation

    -- everyone re-reads the map; the pickup limits belong to the old generation
    TriggerClientEvent('pup-events:easter:patches', -1, patches, generation)
    print(('^2[spring hunt]^7 generation %d: %d patches, %d eggs'):format(generation, #patches, total))
end

local function clearPatches()
    patches = {}
    EVT.easter.patches = patches
    TriggerClientEvent('pup-events:easter:patches', -1, {}, generation)
end

-- ===========================================================================
-- LIFECYCLE
-- ===========================================================================
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `easter_limits` (
            `charidentifier` INT NOT NULL,
            `patch` INT NOT NULL,
            `generation` INT NOT NULL,
            `count` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`charidentifier`, `patch`, `generation`)
        )
    ]])

    local wasLive = false
    while true do
        Wait(5000)
        local now <const> = live()
        if now and not wasLive then
            rollPatches()
            MySQL.query('DELETE FROM easter_limits')
        elseif not now and wasLive then
            clearPatches()
        end
        wasLive = now
    end
end)

-- re-roll on a timer while the event is up
CreateThread(function()
    while true do
        Wait(math.max(5, Config.Easter.patches.resetMinutes or 60) * 60 * 1000)
        if live() then
            rollPatches()
            MySQL.query('DELETE FROM easter_limits WHERE generation < ?', { generation })
        end
    end
end)

RegisterNetEvent('pup-events:easter:sync', function()
    local src = source
    TriggerClientEvent('pup-events:easter:patches', src, live() and patches or {}, generation)
end)

-- ===========================================================================
-- PICKUP
-- ===========================================================================
RegisterNetEvent('pup-events:easter:begin', function(patchIdx, eggId, coords)
    local src = source
    if not live() then return end

    local p = patches[tonumber(patchIdx) or 0]
    local egg = p and p.eggs[tonumber(eggId) or 0]
    if not egg then return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.eggGone) end
    if egg.reservedBy and egg.reservedBy ~= src then
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.eggReserved)
    end

    -- the server decides where the player is, not the payload
    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local me <const> = GetEntityCoords(ped)
    if #(vector2(me.x, me.y) - vector2(egg.x, egg.y)) > (Config.Easter.pickup.validationDistance or 3.0) then
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.eggTooFar)
    end

    local ch = charOf(src)
    if not ch then return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.charNotReady) end
    if ch.isdead == true or ch.isdead == 1 then return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.down) end

    local taken <const> = (pickedUp[ch.charIdentifier] or {})[tonumber(patchIdx)] or 0
    if taken >= (Config.Easter.patches.pickupLimit or 5) then
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.patchLimit)
    end

    if not exports.vorp_inventory:canCarryItem(src, Config.Easter.itemName, Config.Easter.itemAmount) then
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.inventoryFull)
    end

    local stamp <const> = GetGameTimer()
    egg.reservedBy, egg.reservedAt = src, stamp
    TriggerClientEvent('pup-events:easter:approved', src, patchIdx, eggId)
    -- the client's pickup can take 14.8s with its anim and model loads at their timeouts
    SetTimeout(16000, function()
        local cur = patches[tonumber(patchIdx) or 0]
        local e = cur and cur.eggs[tonumber(eggId) or 0]
        if e and e.reservedBy == src and e.reservedAt == stamp then e.reservedBy = nil end
    end)
end)

RegisterNetEvent('pup-events:easter:finish', function(patchIdx, eggId)
    local src = source
    if not live() then return end

    patchIdx, eggId = tonumber(patchIdx), tonumber(eggId)
    local p = patches[patchIdx or 0]
    local egg = p and p.eggs[eggId or 0]
    if not egg or egg.reservedBy ~= src then
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.eggUnavailable)
    end

    -- the client plays the whole pickup before it sends this
    local A <const> = Config.Easter.pickup.anim or {}
    if GetGameTimer() - (egg.reservedAt or 0) < (A.handoffMs or 3500) + (A.propRemoveMs or 2300) - 1000 then return end

    -- the reservation proved the distance a moment ago; prove it again so the
    -- pickup cannot be finished from somewhere else
    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local me <const> = GetEntityCoords(ped)
    if #(vector2(me.x, me.y) - vector2(egg.x, egg.y)) > (Config.Easter.pickup.validationDistance or 3.0) + 2.0 then
        egg.reservedBy = nil
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.eggTooFar)
    end

    local ch = charOf(src)
    if ch and (ch.isdead == true or ch.isdead == 1) then
        egg.reservedBy = nil
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.down)
    end
    if not ch then
        egg.reservedBy = nil
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.charNotReady)
    end

    -- read again here: several eggs can be reserved at once, and each passed begin on the same count
    local mine = pickedUp[ch.charIdentifier] or {}
    if (mine[patchIdx] or 0) >= (Config.Easter.patches.pickupLimit or 5) then
        egg.reservedBy = nil
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.patchLimit)
    end

    -- begin only asked about a normal egg, and the pack can have filled since. A refused egg stays on the ground.
    local gold <const> = (math.random() * 100) < (Config.Easter.goldEggChance or 0.5)
    local item <const> = gold and Config.Easter.goldItemName or Config.Easter.itemName
    if not exports.vorp_inventory:canCarryItem(src, item, Config.Easter.itemAmount) then
        egg.reservedBy = nil
        return TriggerClientEvent('pup-events:easter:failed', src, Locale.easter.inventoryFull)
    end

    p.eggs[eggId] = nil
    mine[patchIdx] = (mine[patchIdx] or 0) + 1
    pickedUp[ch.charIdentifier] = mine

    MySQL.query([[
        INSERT INTO easter_limits (charidentifier, patch, generation, count)
        VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE count = count + 1
    ]], { ch.charIdentifier, patchIdx, generation })

    exports.vorp_inventory:addItem(src, item, Config.Easter.itemAmount, {})
    notify(src, gold and Locale.easter.pickupGold or Locale.easter.pickupNormal)

    if gold then
        local fields, name = playerFields(src)
        fields[#fields + 1] = { name = 'Found At',
            value = ('**%s** `[%.1f, %.1f]`'):format(p.name or '?', egg.x, egg.y), inline = false }
        hook('goldPickup', 'Golden Egg Found', ('**%s** found a **Golden Egg**.'):format(name),
            ((Config.Logs or {}).easter or {}).colorGold or 16766720, fields)
    end

    TriggerClientEvent('pup-events:easter:removeEgg', -1, patchIdx, eggId)
end)

RegisterNetEvent('pup-events:easter:cancel', function(patchIdx, eggId)
    local src = source
    local p = patches[tonumber(patchIdx) or 0]
    local egg = p and p.eggs[tonumber(eggId) or 0]
    if egg and egg.reservedBy == src then egg.reservedBy = nil end
end)

AddEventHandler('playerDropped', function()
    local src = source
    opening[src] = nil
    for _, p in pairs(patches) do
        for _, e in pairs(p.eggs) do
            if e.reservedBy == src then e.reservedBy = nil end
        end
    end
end)

-- ===========================================================================
-- OPENING AN EGG
-- ===========================================================================
local function rollLoot(tbl)
    local total = 0
    for _, e in ipairs(tbl) do total = total + e.weight end
    local roll, sum = math.random() * total, 0
    for _, e in ipairs(tbl) do
        sum = sum + e.weight
        if roll <= sum then return e end
    end
    return tbl[#tbl]
end

local function give(src, item, amount)
    if item == 'money' then
        local ch = charOf(src)
        if ch then ch.addCurrency(0, amount) end
    else
        exports.vorp_inventory:addItem(src, item, amount, {})
    end
end

exports.vorp_inventory:registerUsableItem(Config.Easter.itemName, function(data)
    local src <const> = data.source
    exports.vorp_inventory:closeInventory(src)
    -- take it first: giving loot before the item is gone is how one egg pays twice
    if not exports.vorp_inventory:subItem(src, Config.Easter.itemName, 1, nil) then return end
    local result <const> = rollLoot(Config.Easter.normalLoot)
    give(src, result.item, result.amount)
    notify(src, Locale.easter.openNormal:format(result.item, result.amount))
end)

exports.vorp_inventory:registerUsableItem(Config.Easter.goldItemName, function(data)
    local src <const> = data.source
    exports.vorp_inventory:closeInventory(src)

    -- the inventory read below is async; this lock stops one egg being used several times
    if opening[src] then return notify(src, Locale.easter.busy) end
    opening[src] = true

    exports.vorp_inventory:getUserInventoryItems(src, function(items)
        local owned = {}
        for _, inv in pairs(items or {}) do
            if inv.name then owned[inv.name] = inv.count or 0 end
        end

        local allOwned = true
        for _, e in ipairs(Config.Easter.goldLoot) do
            if not owned[e.item] or owned[e.item] == 0 then allOwned = false break end
        end
        if allOwned then
            opening[src] = nil
            return notify(src, Locale.easter.goldAllOwned, 5000)
        end

        local result, rerolled = rollLoot(Config.Easter.goldLoot), false
        for _ = 1, #Config.Easter.goldLoot do
            if not owned[result.item] or owned[result.item] == 0 then break end
            result = rollLoot(Config.Easter.goldLoot)
            rerolled = true
        end

        if not exports.vorp_inventory:subItem(src, Config.Easter.goldItemName, 1, nil) then
            opening[src] = nil
            return
        end

        if rerolled then notify(src, Locale.easter.goldRerolled) end
        give(src, result.item, result.amount)
        notify(src, Locale.easter.openGold:format(result.item, result.amount), 5000)

        local fields, name = playerFields(src)
        local desc = ('**%s** opened a **Golden Egg** and received `%s x%d`.')
            :format(name, result.item, result.amount)
        if rerolled then desc = desc .. '\n*Reward was rerolled - they already owned the first roll.*' end
        hook('goldOpen', 'Golden Egg Opened', desc,
            ((Config.Logs or {}).easter or {}).colorOpenGold or 15844367, fields)

        opening[src] = nil
    end)
end)
