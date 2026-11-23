-- pup_homestead | the farming rules: planting, working a plant, growth, rain
-- The client only asks. Every check (items, reach, owner, limits, spacing) happens here.
Field = {}

local Core = exports.vorp_core:GetCore()
local Inv = exports.vorp_inventory
Field.Core = Core

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------
function Field.char(src)
    local u = Core.getUser(tonumber(src))
    return u and u.getUsedCharacter or nil
end

function Field.tip(src, msg) if msg then Core.NotifyRightTip(src, msg, 4500) end end

local function count(src, item) return tonumber(Inv:getItemCount(src, nil, item)) or 0 end
Field.count = count

local function pos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- pup-perks, optional: a stopped or restarting pup-perks must never break farming
local function perk(fn, ...)
    if GetResourceState('pup-perks') ~= 'started' then return nil end
    local args = { ... }
    local ok, res = pcall(function() return exports['pup-perks'][fn](exports['pup-perks'], table.unpack(args)) end)
    return ok and res or nil
end
local function perkBonus(src, key) return tonumber(perk('Bonus', src, key)) or 0 end
local function perkHas(src, key) return perk('Has', src, key) == true end
local function award(src, kind) perk('Award', src, kind) end

-- what this character gets from perks + job
function Field.bonuses(src)
    local ch = Field.char(src)
    local job = ch and ch.job
    local function best(perkKey, jobField)
        local a, b = perkBonus(src, perkKey), Farm.jobBonus(job, jobField) or 0
        return a > b and a or b
    end
    return {
        limit = perkBonus(src, 'farm_limit') + (Farm.jobBonus(job, 'limit') or 0),
        yield = perkBonus(src, 'farm_bonus'),
        waterRadius = (perkHas(src, 'farm_water_radius') or (Farm.jobBonus(job, 'radius') or 0) > 0) and best('farm_water_radius', 'radius') or 0,
        fertRadius = best('farm_fert_radius', 'fertRadius'),
    }
end

-- one log: who did it first, then the fields for what they did
local function log(src, ch, title, description, color, extra)
    local hook = Secrets.Webhooks and Secrets.Webhooks.admin
    if not hook or hook == '' then return end
    local discord = GetPlayerIdentifierByType(src, 'discord')
    local fields = { {
        name = 'Player Information',
        value = ('Char ID: %s\nName: %s %s\nDiscord: %s\nSteam Name: %s\nServer ID: %s'):format(
            tostring(ch.charIdentifier), ch.firstname or '', ch.lastname or '',
            discord and ('<@%s>'):format(discord:sub(9)) or 'Not Linked', GetPlayerName(src) or '', tostring(src)),
        inline = false,
    } }
    for _, f in ipairs(extra or {}) do fields[#fields + 1] = f end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({ username = 'Farming Tracker', embeds = { {
        title = title, description = description, color = color or 5814783, fields = fields,
        footer = { text = 'pup_homestead' }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } } }),
        { ['Content-Type'] = 'application/json' })
end

local function plantFields(p, more)
    local fields = {
        { name = 'Plant', value = tostring(p.crop), inline = true },
        { name = 'Render ID', value = tostring(p.id), inline = true },
        { name = 'Owner Char ID', value = tostring(p.charid), inline = true },
    }
    for _, f in ipairs(more or {}) do fields[#fields + 1] = f end
    return fields
end

-- what a client may know about a plant
function Field.public(p)
    return { id = p.id, owner = p.charid, crop = p.crop, x = p.x, y = p.y, z = p.z, left = p.left,
             watered = p.watered, fert = p.fert, trim = p.trim, health = p.health, difficulty = p.difficulty }
end

-- tell everyone near the plant what changed (nil = it is gone)
function Field.push(p, gone)
    local data = not gone and Field.public(p) or nil
    local here = { x = p.x, y = p.y, z = p.z }
    for _, s in ipairs(GetPlayers()) do
        local at = pos(s)
        if at and Farm.dist(at, here) <= Config.Plants.syncDistance then
            TriggerClientEvent('pup_homestead:plant', tonumber(s), p.id, data)
        end
    end
    -- the owner keeps their blip wherever they are
    for _, s in ipairs(GetPlayers()) do
        local ch = Field.char(s)
        if ch and tonumber(ch.charIdentifier) == p.charid then TriggerClientEvent('pup_homestead:mine', tonumber(s), p.id, data) end
    end
end

function Field.nearby(src)
    local at = pos(src)
    local out = {}
    if not at then return out end
    for _, p in pairs(Store.plants) do
        if Farm.dist(at, p) <= Config.Plants.syncDistance then out[#out + 1] = Field.public(p) end
    end
    return out
end

function Field.mine(src)
    local ch = Field.char(src)
    local out = {}
    if not ch then return out end
    for _, p in ipairs(Store.ofChar(tonumber(ch.charIdentifier))) do out[#out + 1] = Field.public(p) end
    return out
end

-------------------------------------------------------------------------------
-- PLANTING
-------------------------------------------------------------------------------
local pendingSeed = {} -- [src] = { crop, at }: a seed was used and the client is planting it

local function isGang(c) return c.gang and GetResourceState('pup-gangs') == 'started' end

-- everything that must be true before a seed goes in. Returns ok, why
function Field.canPlant(src, cropName)
    local c = Config.Crops[cropName]
    local ch = Field.char(src)
    if not c or not ch then return false end
    if c.gang then
        if not isGang(c) then return false end
        local ok = false
        pcall(function() ok = exports['pup-gangs']:DrugCanPlant(src) == true end)
        if not ok then return false end
    end
    if count(src, Config.Items.hoe) < 1 then return false, Locale.noHoe end
    if count(src, c.seed) < c.seeds then return false, Locale.noSeeds end
    if not Farm.jobAllowed(c, ch.job) then return false, Locale.jobLocked end
    local b = Field.bonuses(src)
    local mine, ofKind = 0, 0
    for _, p in pairs(Store.plants) do
        if p.charid == tonumber(ch.charIdentifier) then
            mine = mine + 1
            if p.crop == cropName then ofKind = ofKind + 1 end
        end
    end
    if ofKind >= c.max + b.limit then return false, Locale.tooManyKind end
    if mine >= Config.Planting.maxPlantsTotal + b.limit * 2 then return false, Locale.tooMany end
    return true
end

-- a seed item was used: check, then let the client do the town / water checks and the skill bar
function Field.useSeed(src, cropName)
    if HomesteadRestartLocked and HomesteadRestartLocked() then return Field.tip(src, Locale.restartLock) end
    local p = pendingSeed[src]
    if p and os.time() - p.at < 120 then return Field.tip(src, Locale.busy) end
    local ok, why = Field.canPlant(src, cropName)
    if not ok then return Field.tip(src, why) end
    pendingSeed[src] = { crop = cropName, at = os.time() }
    TriggerClientEvent('pup_homestead:startPlanting', src, cropName)
end

function Field.cancelSeed(src) pendingSeed[src] = nil end

-- the client finished the planting animation at `spot`
function Field.plant(src, spot)
    local pend = pendingSeed[src]
    pendingSeed[src] = nil
    if not pend or type(spot) ~= 'table' then return false end
    -- a seed already going in when the restart lock came finishes; a stale one does not
    if HomesteadRestartLocked and HomesteadRestartLocked() and os.time() - pend.at >= 120 then return false, Locale.restartLock end
    local ch = Field.char(src)
    local c = Config.Crops[pend.crop]
    if not ch or not c then return false end
    local ok, why = Field.canPlant(src, pend.crop)
    if not ok then return false, why end

    spot = { x = tonumber(spot.x), y = tonumber(spot.y), z = tonumber(spot.z) }
    local at = pos(src)
    if not (spot.x and spot.y and spot.z) or not at or Farm.dist(at, spot) > 3.0 then return false, Locale.tooFar end
    for _, p in pairs(Store.plants) do
        if Farm.dist(p, spot) < Config.Planting.minSpacing then return false, Locale.tooClose end
    end

    -- the gang seed is taken off the planter's OWN gang's stack by pup-gangs
    if isGang(c) then
        local took = false
        pcall(function() took = exports['pup-gangs']:DrugTakeSeed(src, c.seeds) == true end)
        if not took then return false, Locale.noSeeds end
    elseif not Inv:subItem(src, c.seed, c.seeds) then
        return false, Locale.noSeeds
    end

    local p = Store.add(tonumber(ch.charIdentifier), pend.crop, spot)
    if not p then return false end
    Field.push(p)
    award(src, 'farm_plant')
    log(src, ch, 'Crop sown', 'A new plant went into the ground.', 65280, plantFields(p, {
        { name = 'Coords', value = ('%.2f, %.2f, %.2f'):format(p.x, p.y, p.z), inline = false },
    }))
    return true, Locale.planted:format(p.crop)
end

-------------------------------------------------------------------------------
-- WORKING A PLANT
-------------------------------------------------------------------------------
local holding = {} -- [src] = the full can item they are holding
function Field.hold(src, can) holding[src] = can end
function Field.holding(src) return holding[src] end
function Field.drop(src) holding[src] = nil end

-- the plant, if this player may do `action` to it from where they stand
local function reachable(src, id, action)
    local p = Store.get(id)
    if not p then return nil, Locale.gone end
    local ch = Field.char(src)
    if not ch then return nil end
    local at = pos(src)
    if not at or Farm.dist(at, p) > Config.Plants.reach + 1.0 then return nil, Locale.tooFar end
    if p.charid ~= tonumber(ch.charIdentifier) and not Config.Plants.others[action] then return nil, Locale.notYours end
    return p, nil, ch
end

-- the plant and the others in `radius` that `want(p)`
local function around(first, radius, want)
    local list = { first }
    if radius <= 0 then return list end
    for _, p in pairs(Store.plants) do
        if p ~= first and want(p) and Farm.dist(p, first) <= radius then list[#list + 1] = p end
    end
    return list
end

local actions = {}

function actions.water(src, p)
    if p.watered then return false, Locale.alreadyWet end
    if p.left <= 0 then return false, Locale.notReady end
    local can = holding[src]
    if not can or count(src, can) < 1 then return false, Locale.noCan end
    holding[src] = nil
    if not Inv:subItem(src, can, 1) then return false, Locale.noCan end
    Inv:addItem(src, Config.Items.emptyCan, 1)
    local list = around(p, Field.bonuses(src).waterRadius, function(o) return not o.watered and o.left > 0 end)
    for _, o in ipairs(list) do
        o.watered = true
        Store.save(o)
        Field.push(o)
    end
    award(src, 'farm_water')
    return true, #list > 1 and Locale.wateredMore:format(#list) or Locale.watered, 'water'
end

function actions.fertilise(src, p)
    local c = Config.Crops[p.crop]
    if p.fert then return false, Locale.alreadyFed end
    if p.left <= 0 then return false, Locale.notReady end
    if count(src, c.fertiliser) < 1 or not Inv:subItem(src, c.fertiliser, 1) then
        return false, Locale.noFertiliser:format(c.fertiliser)
    end
    -- one bag feeds the bed around it when the perk or job allows (same fertiliser only)
    local list = around(p, Field.bonuses(src).fertRadius, function(o)
        return not o.fert and o.left > 0 and Config.Crops[o.crop].fertiliser == c.fertiliser
    end)
    for _, o in ipairs(list) do
        o.fert = true
        local oc = Config.Crops[o.crop]
        -- feeding skips the wait up to the watering point
        if o.left > oc.waterAt then o.left = oc.waterAt end
        Store.save(o)
        Field.push(o)
    end
    return true, #list > 1 and Locale.fedMore:format(#list) or Locale.fed, 'feed'
end

function actions.trim(src, p)
    if p.trim then return false, Locale.alreadyTrim end
    if count(src, Config.Items.trimmer) < 1 then return false, Locale.noTrimmer end
    p.trim = true
    Store.save(p)
    Field.push(p)
    award(src, 'farm_trim')
    return true, Locale.trimmed, 'trim'
end

-- what a harvest gives: the base, +trim, +feed, -poor health (never under 1), then the perk on top
local function yieldOf(src, p)
    local c = Config.Crops[p.crop]
    local extra = Field.bonuses(src).yield
    local out = {}
    for _, r in ipairs(c.yield) do
        local n = r.count
        if p.trim then n = n + c.trimBonus end
        if p.fert then n = n + (tonumber(c.fertBonus) or Config.Fertiliser.bonus) end
        if p.health <= Config.PlantHealth.unhealthyAt then n = n - Config.PlantHealth.unhealthyLoss end
        out[#out + 1] = { item = r.item, label = r.label, count = math.max(1, n) + extra }
    end
    return out, extra
end
Field.yieldOf = yieldOf

local function packFits(src, item, n)
    if GetResourceState('pup-misc') ~= 'started' then return false end
    local ok, res = pcall(function() return exports['pup-misc']:PackCanStore(src, 'farming', item, n) end)
    return ok and res == true
end

function actions.harvest(src, p, ch)
    if HomesteadRestartLocked and HomesteadRestartLocked() then return false, Locale.restartHarvest end
    if p.left > 0 then return false, Locale.notReady end
    local c = Config.Crops[p.crop]
    local rewards, extra = yieldOf(src, p)
    local gang = isGang(c)

    -- everything must fit before anything is given
    for _, r in ipairs(rewards) do
        if gang then
            local fits = 0
            pcall(function() fits = tonumber((exports['pup-gangs']:DrugHarvest(src, r.count, true) or {}).count) or 0 end)
            if fits < 1 then return false, Locale.noRoom end
        else
            r.pack = packFits(src, r.item, r.count)
            if not r.pack and not Inv:canCarryItem(src, r.item, r.count) then return false, Locale.noRoom end
        end
    end

    -- the plant goes first, so a second harvest of the same plant finds nothing
    Store.remove(p)
    Field.push(p, true)

    local got, total = {}, 0
    for _, r in ipairs(rewards) do
        local label, note = r.label, ''
        if gang then
            local res
            pcall(function() res = exports['pup-gangs']:DrugHarvest(src, r.count) end)
            r.count = tonumber(res and res.count) or 0
            label = res and res.label or label
        elseif r.pack then
            local ok, packed, packName = pcall(function() return exports['pup-misc']:PackStore(src, 'farming', r.item, r.count) end)
            if ok and packed then note = Locale.packed:format(tostring(packName or 'pack'))
            else Inv:addItem(src, r.item, r.count) end
        else
            Inv:addItem(src, r.item, r.count)
        end
        if r.count > 0 then
            got[#got + 1] = ('%d %s%s'):format(r.count, label, note)
            total = total + r.count
        end
    end
    if #got == 0 then return false, Locale.gangNo end

    Store.count(p.charid, p.crop, 'harvested', 1)
    Store.count(tonumber(ch.charIdentifier), p.crop, 'gathered', total)
    award(src, 'farm')
    if extra > 0 then Field.tip(src, Locale.greenThumb:format(extra)) end
    log(src, ch, 'Crop picked', 'A ripe plant was harvested.', 5814783, plantFields(p, {
        { name = 'Harvest', value = table.concat(got, ', '), inline = false },
    }))
    return true, Locale.harvested:format(table.concat(got, ', ')), 'harvest'
end

-- a failed skill bar hurts the plant
local lastFail = {} -- [src] = os.time() of their last failed task
function actions.fail(src, p, ch)
    local now = os.time()
    local wait = tonumber(Config.PlantHealth.failCooldown) or 8
    if lastFail[src] and now - lastFail[src] < wait then return false end
    lastFail[src] = now
    local loss = Config.PlantHealth.lossOnFail
    -- someone else's slip can hurt the plant but not kill it (unless the config allows it)
    if p.charid ~= tonumber(ch.charIdentifier) and not Config.PlantHealth.othersCanKill then
        loss = math.min(loss, math.max(0, p.health - 1))
    end
    p.health = p.health - loss
    p.difficulty = math.max(p.difficulty, Config.PlantHealth.hardAfterFail)
    if p.health <= 0 then
        Store.remove(p)
        Field.push(p, true)
        log(src, ch, 'Plant Destroyed', 'A plant was destroyed after failed tasks.', 16711680, plantFields(p))
        return true, Locale.killed
    end
    Store.save(p)
    Field.push(p)
    return true, Locale.hurt
end

function actions.remove(src, p, ch)
    Store.remove(p)
    Field.push(p, true)
    log(src, ch, 'Plant pulled up', 'A plant was pulled up.', 16753920, plantFields(p))
    return true, Locale.removed, 'clear'
end

-- the permission key each action is checked against in Config.Plants.others
local KEY <const> = { water = 'water', fertilise = 'fertilise', trim = 'trim', harvest = 'harvest', remove = 'remove', fail = 'check' }

-- returns ok, message, anim
function Field.act(src, action, id)
    local fn = actions[action]
    if not fn then return false end
    local p, why, ch = reachable(src, id, KEY[action])
    if not p then return false, why end
    return fn(src, p, ch)
end

-------------------------------------------------------------------------------
-- GROWTH, RAIN, WITHERING  (once a minute)
-------------------------------------------------------------------------------
local function raining()
    if not Config.Watering.rain or GetResourceState('weathersync') ~= 'started' then return false end
    local ok, w = pcall(function() return exports.weathersync:getWeather() end)
    if not ok or type(w) ~= 'string' then return false end
    w = w:lower()
    for _, t in ipairs(Config.Watering.rainTypes) do if w == t then return true end end
    return false
end
Field.raining = raining

function Field.tick()
    local rain = raining()
    local rained = {}
    for _, p in pairs(Store.plants) do
        local c = Config.Crops[p.crop]
        if p.left > 0 then
            if rain and not p.watered then
                p.watered = true
                Store.save(p)
                Field.push(p)
                rained[p.charid] = true
            end
            -- growth stops at the watering point until someone waters it
            if p.watered or p.left > c.waterAt then
                p.left = p.left - 1
                Store.touch(p)
                if p.left == 0 or p.left == c.waterAt then Field.push(p) end
            end
        elseif Config.Plants.witherMinutes > 0 then
            p.ripe = p.ripe + 1
            Store.touch(p)
            if p.ripe >= Config.Plants.witherMinutes then
                Store.remove(p)
                Field.push(p, true)
                local s = Field.sourceOfChar(p.charid)
                if s then Field.tip(s, Locale.withered:format(p.crop)) end
            end
        end
    end
    for charid in pairs(rained) do
        local s = Field.sourceOfChar(charid)
        if s then Field.tip(s, Locale.rainWatered) end
    end
end

function Field.sourceOfChar(charid)
    for _, s in ipairs(GetPlayers()) do
        local ch = Field.char(s)
        if ch and tonumber(ch.charIdentifier) == charid then return tonumber(s) end
    end
end

AddEventHandler('playerDropped', function()
    pendingSeed[source], holding[source], lastFail[source] = nil, nil, nil
end)
