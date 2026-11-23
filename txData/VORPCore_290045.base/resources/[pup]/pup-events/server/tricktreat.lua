-- pup-events | Trick or Treat (server). The server owns which doors are live,
-- the roll, and the loot. The client only knocks and renders.

local Core = exports.vorp_core:GetCore()

local doors   = {}   -- [i] = { idx, coords } where idx points into Config.TrickOrTreat.doors
local knocked = {}   -- [charid] = { [doorIndex] = os.time() of the knock }
local gotBlade = {}  -- [charid] = { [bucket] = true } once that rare prize was drawn tonight
local budget  = {}   -- [charid] = knocks this character gets this round, rolled on the first
local used    = {}   -- [charid] = knocks taken so far

EVT.tnt = EVT.tnt or {}

local function live() return EVT.live and EVT.live.deadofnight == true end

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

local function wcol(key, fallback)
    return ((Config.Logs or {}).trickOrTreat or {})[key] or fallback
end

local function playerFields(src)
    local ch = charOf(src)
    local name = ch and ((ch.firstname or '') .. ' ' .. (ch.lastname or '')) or 'Unknown'
    local steam, discord = 'N/A', 'N/A'
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 6) == 'steam:' then steam = id
        elseif id:sub(1, 8) == 'discord:' then discord = '<@' .. id:sub(9) .. '>' end
    end
    return {
        { name = 'Character', value = name, inline = true },
        { name = 'Char ID',   value = ch and tostring(ch.charIdentifier or 'N/A') or 'N/A', inline = true },
        { name = 'Discord',   value = discord, inline = true },
        { name = 'Steam',     value = steam,   inline = false },
    }
end

-- which door, and how much of their nightly allowance is gone
local function knockFields(src, door, id)
    local f = playerFields(src)
    f[#f + 1] = { name = 'Door',   value = ('#%d - %.1f %.1f %.1f'):format(door.idx, door.x, door.y, door.z), inline = true }
    f[#f + 1] = { name = 'Knocks', value = ('%d / %d'):format(used[id] or 0, budget[id] or 0), inline = true }
    return f
end

-- one channel for the lot; `which` only decides whether it pings
local function hook(which, title, desc, color, fields)
    local W = (Config.Logs or {}).trickOrTreat or {}
    local url = ((Secrets or {}).Webhooks or {}).trickOrTreat
    if type(url) ~= 'string' or url == '' then return end
    hookQueue[#hookQueue + 1] = { url = url, payload = {
        content = (W.pingEveryone and which == 'rare') and '@everyone' or '',
        embeds = { {
            title = title, description = desc, color = color, fields = fields,
            footer = { text = ((Config.Logs or {}).serverName or 'Server') .. ' - Trick or Treat' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    } }
    drainHooks()
end

local function rollDoors()
    doors = {}
    -- cooldowns outlive a re-roll; only expired entries are dropped
    local cutoff <const> = os.time() - ((Config.TrickOrTreat.cooldownMinutes or 20) * 60)
    for id, byDoor in pairs(knocked) do
        for idx, t in pairs(byDoor) do
            if t < cutoff then byDoor[idx] = nil end
        end
        if next(byDoor) == nil then knocked[id] = nil end
    end
    -- gotBlade is not cleared either, so once per night means once per night.
    -- budget/used last the whole night too; they are cleared when the night starts or ends

    local pool = {}
    for i = 1, #Config.TrickOrTreat.doors do pool[i] = i end

    -- no doorsPerNight = every door is knockable and the per-character cap limits a round
    local want = #pool
    if Config.TrickOrTreat.doorsPerNight then
        for i = #pool, 2, -1 do
            local j = math.random(i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        want = math.min(#pool, math.random(Config.TrickOrTreat.doorsPerNight[1], Config.TrickOrTreat.doorsPerNight[2]))
    end

    for n = 1, want do
        local idx <const> = pool[n]
        local c <const> = Config.TrickOrTreat.doors[idx]
        -- the kind is decided now, so the prop outside matches what is behind the door
        doors[n] = {
            idx   = idx,
            x = c.x, y = c.y, z = c.z, w = c.w,
            trick = (math.random(100) <= (Config.TrickOrTreat.trickChance or 45)),
        }
    end

    EVT.tnt.doors = doors
    TriggerClientEvent('pup-events:tnt:doors', -1, doors)
    local K <const> = Config.TrickOrTreat.knocksPerCharacter
    local cap <const> = K and ('%d-%d knocks'):format(K[1], K[2]) or 'no cap'
    print(('^3[trick or treat]^7 %d doors live tonight, %s per character'):format(#doors, cap))
    local tricks = 0
    for _, d in pairs(doors) do if d.trick then tricks = tricks + 1 end end
    hook('round', 'Doors are live', nil, wcol('colorRound', 3092790), {
        { name = 'Doors',  value = tostring(#doors), inline = true },
        { name = 'Sacks',  value = ('%d sack / %d pumpkin'):format(#doors - tricks, tricks), inline = true },
        { name = 'Allowance', value = cap .. ' per character', inline = true },
    })
end

-- a new night (or the end of one) gives everyone a fresh allowance
local function newNight()
    budget = {}
    used = {}
end

local function clearDoors()
    doors = {}
    EVT.tnt.doors = doors
    TriggerClientEvent('pup-events:tnt:doors', -1, {})
end

CreateThread(function()
    local was = false
    while true do
        Wait(5000)
        if not (Config.TrickOrTreat and Config.TrickOrTreat.enabled) then goto continue end
        local now <const> = live()
        if now and not was then newNight() rollDoors()
        elseif not now and was then newNight() clearDoors() end
        was = now
        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(math.max(5, Config.TrickOrTreat.resetMinutes or 60) * 60 * 1000)
        if Config.TrickOrTreat.enabled and live() then rollDoors() end
    end
end)

RegisterNetEvent('pup-events:tnt:sync', function()
    TriggerClientEvent('pup-events:tnt:doors', source, live() and doors or {})
end)

-- the knock: `chance` is a percentage; the total is summed, so drift skews rather than breaks
local function rollLoot()
    local total = 0
    for _, e in ipairs(Config.TrickOrTreat.treat.loot) do total = total + (tonumber(e.chance) or 0) end
    if total <= 0 then return Config.TrickOrTreat.treat.loot[1] end
    local roll, sum = math.random() * total, 0
    for _, e in ipairs(Config.TrickOrTreat.treat.loot) do
        sum = sum + (tonumber(e.chance) or 0)
        if roll <= sum then return e end
    end
    return Config.TrickOrTreat.treat.loot[#Config.TrickOrTreat.treat.loot]
end

local function kindOf(e)
    return e.kind or (e.item == 'money' and 'money') or 'item'
end

local function bucketOf(e, kind)
    return e.once or (kind == 'weapon' and Config.TrickOrTreat.treat.weaponOncePerNight and 'blade') or nil
end

-- createWeapon does NOT check capacity, unlike addItem's canCarryItem gate
local function canTake(src, e, kind)
    if kind == 'money' then return true end
    if kind == 'weapon' then
        return exports.vorp_inventory:canCarryWeapons(src, 1, nil, tostring(e.item):upper()) == true
    end
    return exports.vorp_inventory:canCarryItem(src, e.item, e.amount) == true
end

-- say so at boot rather than let the numbers quietly stop meaning percentages
CreateThread(function()
    if not (Config.TrickOrTreat and Config.TrickOrTreat.treat and Config.TrickOrTreat.treat.loot) then return end
    local total = 0
    for _, e in ipairs(Config.TrickOrTreat.treat.loot) do total = total + (tonumber(e.chance) or 0) end
    if math.abs(total - 100) > 0.001 then
        print(('^3[trick or treat]^7 loot chances add up to %s, not 100 - they are still relative, but the numbers are no longer percentages')
            :format(tostring(total)))
    end
end)

RegisterNetEvent('pup-events:tnt:knock', function(n)
    local src = source
    if not (Config.TrickOrTreat and Config.TrickOrTreat.enabled) or not live() then return end

    local door = doors[tonumber(n) or 0]
    if not door then return end

    -- the server decides where they are, not the client
    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - vector3(door.x, door.y, door.z)) > (Config.TrickOrTreat.promptDistance or 2.2) + 3.0 then return end

    local ch = charOf(src)
    if not ch or ch.isdead == true or ch.isdead == 1 then return end
    local id <const> = ch.charIdentifier

    knocked[id] = knocked[id] or {}
    local last <const> = knocked[id][door.idx]
    if last and (os.time() - last) < ((Config.TrickOrTreat.cooldownMinutes or 20) * 60) then
        return Core.NotifyRightTip(src, Locale.trickOrTreat.onCooldown, 4000)
    end

    -- their share for the round, rolled on the first knock, after the cooldown check
    local K <const> = Config.TrickOrTreat.knocksPerCharacter
    if K then
        budget[id] = budget[id] or math.random(K[1], K[2])
        if (used[id] or 0) >= budget[id] then
            return Core.NotifyRightTip(src, Locale.trickOrTreat.doneForTonight, 5000)
        end
        used[id] = (used[id] or 0) + 1
    end

    knocked[id][door.idx] = os.time()

    if door.trick then
        Core.NotifyRightTip(src, Locale.trickOrTreat.trick, 5000)
        hook('trick', 'Knocked a pumpkin door', nil, wcol('colorTrick', 10038562), knockFields(src, door, id))
        TriggerClientEvent('pup-events:tnt:trick', src, n)
        return
    end

    -- TREAT. Rolled and given here; the client is only told what happened.
    local given, rare = {}, nil
    for _ = 1, math.random(Config.TrickOrTreat.treat.rolls[1], Config.TrickOrTreat.treat.rolls[2]) do
        -- limit-1 props and spent `once` buckets are dead draws, so re-roll before falling back to cash
        local e, kind, bucket
        for _ = 1, (Config.TrickOrTreat.treat.rerollTries or 3) + 1 do
            local pick <const> = rollLoot()
            local k <const> = kindOf(pick)
            local b <const> = bucketOf(pick, k)
            local spent <const> = b and gotBlade[id] and gotBlade[id][b]
            if not spent and canTake(src, pick, k) then
                e, kind, bucket = pick, k, b
                break
            end
        end

        local pay <const> = tonumber(Config.TrickOrTreat.treat.deadDrawPay) or 25

        if not e then
            ch.addCurrency(0, pay)
            given[#given + 1] = '$' .. pay

        elseif kind == 'money' then
            ch.addCurrency(0, e.amount)
            given[#given + 1] = '$' .. e.amount

        elseif kind == 'weapon' then
            exports.vorp_inventory:createWeapon(src, e.item, {}, {})
            given[#given + 1] = e.item
            rare = e.item

        else
            exports.vorp_inventory:addItem(src, e.item, e.amount, {})
            given[#given + 1] = e.item .. ' x' .. e.amount
        end

        -- spent only on something actually handed over, so a full pack never burns the night
        if e and bucket then
            gotBlade[id] = gotBlade[id] or {}
            gotBlade[id][bucket] = true
        end

        -- the line only reads well if they actually got the thing
        if e and e.announce then
            SetTimeout(1200, function()
                TriggerClientEvent('vorp:TipRight', src, e.announce, 7000)
            end)
        end
    end

    if #given > 0 then
        local f = knockFields(src, door, id)
        f[#f + 1] = { name = 'Got', value = '`' .. table.concat(given, '`  `') .. '`', inline = false }
        -- a weapon draw is the same message, just loud enough to find later
        if rare then
            hook('rare', 'A weapon came out of the sack', '`' .. rare .. '`', wcol('colorRare', 10181046), f)
        else
            hook('treat', 'Opened a sack', nil, wcol('colorTreat', 16747520), f)
        end
    end

    Core.NotifyRightTip(src, Locale.trickOrTreat.treat, 4000)
    local flavour <const> = Locale.trickOrTreat.flavour
    if flavour and #flavour > 0 then
        SetTimeout(2500, function()
            TriggerClientEvent('vorp:TipRight', src, flavour[math.random(#flavour)], 6000)
        end)
    end
    TriggerClientEvent('pup-events:tnt:treat', src, n)
end)

AddEventHandler('playerDropped', function() end)
