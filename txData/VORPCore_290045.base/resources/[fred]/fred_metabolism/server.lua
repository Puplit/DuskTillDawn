local VorpCore = {}

TriggerEvent("getCore", function(core)
    VorpCore = core
end)
-- `VORP = exports.vorp_core:vorpAPI()` was here and is gone
VorpInv = exports.vorp_inventory:vorp_inventoryApi()

-- pup: debug gated on Config.General.debug (config/main.lua)
local function dbg(msg)
    if Config.General.debug then
        print(("^3[fred_meta]^7 %s"):format(msg))
    end
end

local function charIdOf(src)
    local user = VorpCore.getUser and VorpCore.getUser(src)
    if not user then return nil end
    local ch = user.getUsedCharacter
    return ch and tonumber(ch.charIdentifier) or nil
end

-- REGISTER USABLES--

-- usables are registered BY NAME and resolve their config index at USE time
local registeredUsables = {}

local function registerConsumable(name)
    if not name or registeredUsables[name] then return end
    registeredUsables[name] = true
    VorpInv.RegisterUsableItem(name, function(data)
        local index, item
        for i, it in ipairs(Config.Consumables) do
            if it.Name == name then
                index, item = i, it
                break
            end
        end
        if not index then return end -- deleted since registration; do nothing
        TriggerClientEvent("fred_meta:useItem", data.source, index)
        VorpInv.subItem(data.source, name, 1)
        TriggerClientEvent("vorp:TipRight", data.source, Locale.consumedPrefix .. (item.DisplayName or name), 5000)
        dbg(("%s used %s (index %d)"):format(GetPlayerName(data.source), name, index))
    end)
end

Citizen.CreateThread(function()
    for i = 1, #Config.Consumables do
        registerConsumable(Config.Consumables[i]["Name"])
    end
    dbg(("registered %d usable items"):format(#Config.Consumables))
end)


-- STATUS SYNC - this half of the resource was MISSING entirely
local Status = {} -- [charIdentifier] = { food, water, metabolism }

-- DB persistence - without it every server restart reset everyone to 100/100 ("i always join with max hunger")
CreateThread(function()
    Wait(2000)
    pcall(function()
        exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS fred_metabolism (
            charid INT NOT NULL PRIMARY KEY,
            food FLOAT NOT NULL DEFAULT 100,
            water FLOAT NOT NULL DEFAULT 100,
            metabolism INT NOT NULL DEFAULT 3500
        )]], {}, function() dbg("fred_metabolism table ready") end)
    end)
end)

RegisterServerEvent("fred_meta:setStatus")
AddEventHandler("fred_meta:setStatus", function(food, water, metabolism)
    local _source = source
    local charid = charIdOf(_source)
    if not charid then return end
    Status[charid] = {
        food = tonumber(food) or Config.Needs.initialFood,
        water = tonumber(water) or Config.Needs.initialWater,
        metabolism = tonumber(metabolism) or Config.Metabolism.initial,
    }
    local s = Status[charid]
    pcall(function()
        exports.oxmysql:execute(
            "INSERT INTO fred_metabolism (charid, food, water, metabolism) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE food = VALUES(food), water = VALUES(water), metabolism = VALUES(metabolism)",
            { charid, s.food, s.water, s.metabolism })
    end)
    dbg(("setStatus char %s: food %.1f water %.1f metabolism %d"):format(
        charid, s.food, s.water, s.metabolism))
end)

RegisterServerEvent("fred_meta:checkStatus")
AddEventHandler("fred_meta:checkStatus", function()
    local _source = source
    -- joiners need the LIVE consumables list (config + admin-managed entries)
    TriggerClientEvent("fred_meta:updateconfig", _source, Config.Consumables)
    local charid = charIdOf(_source)
    local s = charid and Status[charid] or nil

    local function reply(st, from)
        local food = st and st.food or Config.Needs.initialFood
        local water = st and st.water or Config.Needs.initialWater
        local metabolism = st and st.metabolism or Config.Metabolism.initial
        TriggerClientEvent("fred_meta:applyChanges", _source, food, water, metabolism)
        dbg(("checkStatus char %s -> food %.1f water %.1f (%s)"):format(
            tostring(charid), food, water, from))
    end

    if s then return reply(s, "restored from memory") end
    if not charid then return reply(nil, "no character - initial values") end

    -- cold start (post server restart): pull the persisted row
    exports.oxmysql:single("SELECT food, water, metabolism FROM fred_metabolism WHERE charid = ?", { charid }, function(row)
        if row then
            s = {
                food = tonumber(row.food) or Config.Needs.initialFood,
                water = tonumber(row.water) or Config.Needs.initialWater,
                metabolism = tonumber(row.metabolism) or Config.Metabolism.initial,
            }
            Status[charid] = s
            reply(s, "restored from DB")
        else
            reply(nil, "first time - initial values")
        end
    end)
end)

-- STARTUP VALIDATION - every Config.Consumables entry must exist in the items DB table or using/registering it can never
Citizen.CreateThread(function()
    Wait(3000) -- let vorp_inventory finish loading its item cache
    local missing = 0
    for i = 1, #Config.Consumables do
        local name = Config.Consumables[i]["Name"]
        local ok, item = pcall(function() return exports.vorp_inventory:getItemDB(name) end)
        if ok and item then
            dbg(("item OK in DB: %s (%s)"):format(name, item.label or "?"))
        else
            missing = missing + 1
            print(("^1[fred_meta]^7 item '%s' is NOT in the items DB table - add it (vorp_admin panel > Items DB) or players can never use it"):format(name))
        end
    end
    if missing == 0 then
        print(("^2[fred_meta]^7 all %d consumables exist in the items DB"):format(#Config.Consumables))
    end
end)

-- ADMIN-MANAGED CONSUMABLES (vorp_admin panel "Consumables" page)
local managedConsumables = {} -- [name] = true for DB-managed entries

local function rowToItem(r)
    return {
        Name = r.name,
        DisplayName = (r.displayname ~= "" and r.displayname) or r.name,
        Hunger = tonumber(r.hunger) or 0,
        Thirst = tonumber(r.thirst) or 0,
        Metabolism = tonumber(r.metabolism) or 0,
        Animation = r.animation or "",
        PropName = r.propname or "",
        Effect = r.effect or "",
        EffectDuration = tonumber(r.effectduration) or 0,
        InnerCoreStamina = tonumber(r.innercorestamina) or 0,
        InnerCoreStaminaGold = tonumber(r.innercorestaminagold) or 0.0,
        OuterCoreStaminaGold = tonumber(r.outercorestaminagold) or 0.0,
        InnerCoreHealth = tonumber(r.innercorehealth) or 0,
        InnerCoreHealthGold = tonumber(r.innercorehealthgold) or 0.0,
        OuterCoreHealthGold = tonumber(r.outercorehealthgold) or 0.0,
        InnerCoreDeadeye = tonumber(r.innercoredeadeye) or 0,
        InnerCoreDeadeyeGold = tonumber(r.innercoredeadeyegold) or 0.0,
        OuterCoreDeadeyeGold = tonumber(r.outercoredeadeyegold) or 0.0,
        Diff = tonumber(r.diff) or 0,   -- 0 = no skill check
    }
end

local function putItem(item)
    for i, it in ipairs(Config.Consumables) do
        if it.Name == item.Name then
            Config.Consumables[i] = item
            return
        end
    end
    Config.Consumables[#Config.Consumables + 1] = item
end

local function broadcastConsumables()
    TriggerClientEvent("fred_meta:updateconfig", -1, Config.Consumables)
end

CreateThread(function()
    Wait(2500)
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS fred_consumables (
        name VARCHAR(50) NOT NULL PRIMARY KEY,
        displayname VARCHAR(64) NOT NULL DEFAULT '',
        hunger FLOAT NOT NULL DEFAULT 0,
        thirst FLOAT NOT NULL DEFAULT 0,
        metabolism INT NOT NULL DEFAULT 0,
        animation VARCHAR(32) NOT NULL DEFAULT '',
        propname VARCHAR(64) NOT NULL DEFAULT '',
        effect VARCHAR(64) NOT NULL DEFAULT '',
        effectduration INT NOT NULL DEFAULT 0,
        innercorestamina FLOAT NOT NULL DEFAULT 0,
        innercorestaminagold FLOAT NOT NULL DEFAULT 0,
        outercorestaminagold FLOAT NOT NULL DEFAULT 0,
        innercorehealth FLOAT NOT NULL DEFAULT 0,
        innercorehealthgold FLOAT NOT NULL DEFAULT 0,
        outercorehealthgold FLOAT NOT NULL DEFAULT 0,
        innercoredeadeye FLOAT NOT NULL DEFAULT 0,
        innercoredeadeyegold FLOAT NOT NULL DEFAULT 0,
        outercoredeadeyegold FLOAT NOT NULL DEFAULT 0,
        diff INT NOT NULL DEFAULT 0
    )]])
    -- installs that created the table before the DeadEye buff columns existed
    MySQL.query.await([[ALTER TABLE fred_consumables
        ADD COLUMN IF NOT EXISTS innercoredeadeye FLOAT NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS innercoredeadeyegold FLOAT NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS outercoredeadeyegold FLOAT NOT NULL DEFAULT 0]])
    -- `diff` = pup-minigames skill-bar difficulty. 0 (the default, and what every existing row gets) means NO minigame
    MySQL.query.await([[ALTER TABLE fred_consumables
        ADD COLUMN IF NOT EXISTS diff INT NOT NULL DEFAULT 0]])
    local rows = MySQL.query.await("SELECT * FROM fred_consumables") or {}
    for _, r in ipairs(rows) do
        managedConsumables[r.name] = true
        putItem(rowToItem(r))
        registerConsumable(r.name)
    end
    if #rows > 0 then
        broadcastConsumables()
    end
    dbg(("loaded %d admin-managed consumables"):format(#rows))
end)

-- panel data feed: the full live list + which names the panel may edit/delete
exports('getConsumables', function()
    return { items = Config.Consumables, managed = managedConsumables }
end)

exports('upsertConsumable', function(data)
    if type(data) ~= "table" then return { ok = false, err = "bad payload" } end
    local name = tostring(data.Name or ""):lower():gsub("[^a-z0-9_]", "")
    if name == "" or #name > 50 then return { ok = false, err = "bad item name (a-z, 0-9, _ only)" } end

    local item = {
        Name = name,
        DisplayName = tostring(data.DisplayName or name):sub(1, 64),
        Hunger = tonumber(data.Hunger) or 0,
        Thirst = tonumber(data.Thirst) or 0,
        Metabolism = math.floor(tonumber(data.Metabolism) or 0),
        Animation = tostring(data.Animation or ""):sub(1, 32),
        PropName = tostring(data.PropName or ""):sub(1, 64),
        Effect = tostring(data.Effect or ""):sub(1, 64),
        EffectDuration = math.floor(tonumber(data.EffectDuration) or 0),
        InnerCoreStamina = tonumber(data.InnerCoreStamina) or 0,
        InnerCoreStaminaGold = tonumber(data.InnerCoreStaminaGold) or 0.0,
        OuterCoreStaminaGold = tonumber(data.OuterCoreStaminaGold) or 0.0,
        InnerCoreHealth = tonumber(data.InnerCoreHealth) or 0,
        InnerCoreHealthGold = tonumber(data.InnerCoreHealthGold) or 0.0,
        OuterCoreHealthGold = tonumber(data.OuterCoreHealthGold) or 0.0,
        InnerCoreDeadeye = tonumber(data.InnerCoreDeadeye) or 0,
        InnerCoreDeadeyeGold = tonumber(data.InnerCoreDeadeyeGold) or 0.0,
        OuterCoreDeadeyeGold = tonumber(data.OuterCoreDeadeyeGold) or 0.0,
        Diff = math.max(0, math.floor(tonumber(data.Diff) or 0)),
    }

    MySQL.query.await([[INSERT INTO fred_consumables
        (name, displayname, hunger, thirst, metabolism, animation, propname, effect, effectduration,
         innercorestamina, innercorestaminagold, outercorestaminagold,
         innercorehealth, innercorehealthgold, outercorehealthgold,
         innercoredeadeye, innercoredeadeyegold, outercoredeadeyegold, diff)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
         displayname = VALUES(displayname), hunger = VALUES(hunger), thirst = VALUES(thirst),
         metabolism = VALUES(metabolism), animation = VALUES(animation), propname = VALUES(propname),
         effect = VALUES(effect), effectduration = VALUES(effectduration),
         innercorestamina = VALUES(innercorestamina), innercorestaminagold = VALUES(innercorestaminagold),
         outercorestaminagold = VALUES(outercorestaminagold), innercorehealth = VALUES(innercorehealth),
         innercorehealthgold = VALUES(innercorehealthgold), outercorehealthgold = VALUES(outercorehealthgold),
         innercoredeadeye = VALUES(innercoredeadeye), innercoredeadeyegold = VALUES(innercoredeadeyegold),
         outercoredeadeyegold = VALUES(outercoredeadeyegold), diff = VALUES(diff)]],
        { item.Name, item.DisplayName, item.Hunger, item.Thirst, item.Metabolism,
          item.Animation, item.PropName, item.Effect, item.EffectDuration,
          item.InnerCoreStamina, item.InnerCoreStaminaGold, item.OuterCoreStaminaGold,
          item.InnerCoreHealth, item.InnerCoreHealthGold, item.OuterCoreHealthGold,
          item.InnerCoreDeadeye, item.InnerCoreDeadeyeGold, item.OuterCoreDeadeyeGold,
          item.Diff })

    managedConsumables[name] = true
    putItem(item)
    registerConsumable(name)

    -- auto-create the inventory item row when missing (usable, sane defaults)
    local createdItem = false
    local okGet, existing = pcall(function() return exports.vorp_inventory:getItemDB(name) end)
    if not (okGet and existing) then
        MySQL.query.await(
            "INSERT IGNORE INTO items (item, label, `limit`, can_remove, type, usable, `desc`, weight) VALUES (?, ?, 10, 1, 'item_standard', 1, ?, 0.25)",
            { name, item.DisplayName, "Consumable: " .. item.DisplayName })
        createdItem = true
    end

    local imageMissing = LoadResourceFile("vorp_inventory", "html/img/items/" .. name .. ".png") == nil

    broadcastConsumables()
    dbg(("consumable upserted: %s (item row created: %s, image missing: %s)"):format(
        name, tostring(createdItem), tostring(imageMissing)))
    return { ok = true, createdItem = createdItem, imageMissing = imageMissing }
end)

exports('deleteConsumable', function(name)
    name = tostring(name or "")
    if not managedConsumables[name] then
        return { ok = false, err = "not an admin-managed consumable (config/consumables.lua entries are file-managed)" }
    end
    MySQL.query.await("DELETE FROM fred_consumables WHERE name = ?", { name })
    managedConsumables[name] = nil
    for i, it in ipairs(Config.Consumables) do
        if it.Name == name then
            table.remove(Config.Consumables, i)
            break
        end
    end
    broadcastConsumables()
    dbg("consumable deleted: " .. name)
    return { ok = true }
end)