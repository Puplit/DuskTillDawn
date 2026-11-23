-- pup_homestead | items, the client callback, the Almanac, staff commands, exports
local Core = Field.Core
local Inv = exports.vorp_inventory
local RES <const> = GetCurrentResourceName()

CreateThread(function()
    Store.init()
    print(('^2[pup_homestead]^7 %d plants in the ground'):format((function() local n = 0 for _ in pairs(Store.plants) do n = n + 1 end return n end)()))
end)

-- growth once a minute, the countdown written every 5
CreateThread(function()
    local n = 0
    while true do
        Wait(60000)
        if Store.ready then
            Field.tick()
            n = n + 1
            if n % 5 == 0 then Store.flush() end
        end
    end
end)

AddEventHandler('onResourceStop', function(res) if res == RES and Store.ready then Store.flush() end end)

-------------------------------------------------------------------------------
-- ITEMS
-------------------------------------------------------------------------------
for name, c in pairs(Config.Crops) do
    Inv:registerUsableItem(c.seed, function(data)
        Inv:closeInventory(data.source)
        Field.useSeed(data.source, name)
    end, RES)
end

for _, can in ipairs(Config.Items.wateringCans) do
    Inv:registerUsableItem(can, function(data)
        local src = data.source
        if Field.count(src, can) < 1 then return end
        Inv:closeInventory(src)
        Field.hold(src, can)
        TriggerClientEvent('pup_homestead:holdCan', src, true)
    end, RES)
end

-- an empty can: the client checks the player is standing in water, then asks
Inv:registerUsableItem(Config.Items.emptyCan, function(data)
    Inv:closeInventory(data.source)
    TriggerClientEvent('pup_homestead:tryRiver', data.source)
end, RES)

RegisterNetEvent('pup_homestead:dropCan', function() Field.drop(source) end)
RegisterNetEvent('pup_homestead:cancelSeed', function() Field.cancelSeed(source) end)

-------------------------------------------------------------------------------
-- ONE CALLBACK FOR EVERYTHING THE CLIENT ASKS
-------------------------------------------------------------------------------
local ask = {}

function ask.nearby(src)
    local ch = Field.char(src)
    return { plants = Field.nearby(src), me = ch and tonumber(ch.charIdentifier), job = ch and ch.job }
end
function ask.mine(src) return { plants = Field.mine(src) } end

function ask.plant(src, d)
    local ok, msg = Field.plant(src, d.spot)
    return { ok = ok, msg = msg }
end

function ask.act(src, d)
    local ok, msg, anim = Field.act(src, d.action, d.id)
    if ok and d.action == 'water' then TriggerClientEvent('pup_homestead:holdCan', src, false) end
    return { ok = ok, msg = msg, anim = anim }
end

function ask.pump(src) local ok, msg = Water.pump(src) return { ok = ok, msg = msg } end
function ask.river(src) local ok, msg = Water.river(src) return { ok = ok, msg = msg } end
function ask.pour(src, d)
    local ok, msg = Water.pour(src, d.net, d.river == true)
    if ok then TriggerClientEvent('pup_homestead:holdCan', src, false) end
    return { ok = ok, msg = msg }
end
function ask.draw(src, d)
    local ok, msg = Water.draw(src, d.net)
    if ok then -- the full can goes straight into their hand
        Field.hold(src, Config.Items.cleanWaterCan)
        TriggerClientEvent('pup_homestead:holdCan', src, true)
    end
    return { ok = ok, msg = msg }
end
function ask.wagon(src, d) return { level = Water.wagonLevel(d.net) } end
-- a pump / wagon chore is only started when it would work
function ask.check(src, d)
    local ok, msg = Water.check(src, d.what, d.net, d.river == true)
    return { ok = ok, msg = msg }
end

-- the Almanac
function ask.almanac(src)
    local ch = Field.char(src)
    local charid = tonumber(ch.charIdentifier)
    local b = Field.bonuses(src)
    local plots = {}
    for _, p in ipairs(Store.ofChar(charid)) do
        plots[#plots + 1] = { id = p.id, crop = p.crop, left = p.left, stage = Farm.stage(p), x = p.x, y = p.y, z = p.z,
            watered = p.watered, fert = p.fert, trim = p.trim, health = p.health }
    end
    local stats = {}
    for _, r in ipairs(Store.stats(charid)) do
        stats[#stats + 1] = { crop = r.crop, planted = tonumber(r.planted) or 0, harvested = tonumber(r.harvested) or 0, gathered = tonumber(r.gathered) or 0 }
    end
    return { plots = plots, cap = Config.Planting.maxPlantsTotal + b.limit * 2, bonus = b, stats = stats, job = ch.job }
end

Core.Callback.Register('pup_homestead:ask', function(src, cb, d)
    d = type(d) == 'table' and d or {}
    local fn = ask[d.op]
    if not fn or not Field.char(src) or not Store.ready then return cb(nil) end
    local ok, res = pcall(fn, src, d)
    if not ok then
        print('^1[pup_homestead]^7 ' .. tostring(res))
        return cb({ ok = false })
    end
    cb(res)
end)

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------
-- GetPlants(charid) -> list of { id, crop, x, y, z, left, watered, fert, trim, health }
exports('GetPlants', function(charid)
    local out = {}
    for _, p in ipairs(Store.ofChar(tonumber(charid))) do out[#out + 1] = Field.public(p) end
    return out
end)

exports('RemovePlant', function(id)
    local p = Store.get(id)
    if not p then return false end
    Store.remove(p)
    Field.push(p, true)
    return true
end)

-- vorp_admin's Farms page; vorp_admin checks manage_farms first
exports('AdminList', function()
    local plants, ids, seen = {}, {}, {}
    for _, p in pairs(Store.plants) do
        local row = Field.public(p)
        row.ripe = p.left <= 0
        row.gang = Config.Crops[p.crop] and Config.Crops[p.crop].gang == true or false
        plants[#plants + 1] = row
        if not seen[p.charid] then
            seen[p.charid] = true
            ids[#ids + 1] = p.charid
        end
    end
    table.sort(plants, function(a, b) return a.id < b.id end)

    local names = {}
    if #ids > 0 then
        local marks = {}
        for i = 1, #ids do marks[i] = '?' end
        local rows = MySQL.query.await('SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier IN (' .. table.concat(marks, ',') .. ')', ids) or {}
        for _, r in ipairs(rows) do
            names[tonumber(r.charidentifier)] = tostring(r.firstname or '') .. ' ' .. tostring(r.lastname or '')
        end
    end
    local online = {}
    for _, s in ipairs(GetPlayers()) do
        local ch = Field.char(s)
        if ch then online[tonumber(ch.charIdentifier)] = true end
    end

    local growers = {}
    for _, id in ipairs(ids) do
        growers[#growers + 1] = { charid = id, name = names[id] or ('Character ' .. id), online = online[id] == true }
    end
    table.sort(growers, function(a, b) return a.name < b.name end)
    return { plants = plants, growers = growers }
end)

-- returns ok, message
exports('AdminAction', function(action, data)
    data = type(data) == 'table' and data or {}
    if action == 'remove' then
        local p = Store.get(data.id)
        if not p then return false, 'That plant is already gone.' end
        Store.remove(p)
        Field.push(p, true)
        return true, ('Removed %s (plant %d) of character %d.'):format(p.crop, p.id, p.charid)
    elseif action == 'clearchar' then
        local charid = tonumber(data.charid)
        if not charid then return false, 'No character given.' end
        local n = 0
        for _, p in ipairs(Store.ofChar(charid)) do
            Store.remove(p)
            Field.push(p, true)
            n = n + 1
        end
        return true, Locale.cleared:format(n, charid)
    end
    return false, 'Unknown action.'
end)

exports('IsRaining', function() return Field.raining() end)
