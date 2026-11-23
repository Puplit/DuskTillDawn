-- pup-misc / props: usable inventory items that attach a prop to the player (canes, pipes, necklaces)

local playerProps = {}

local function charIdOf(src)
    local user = VorpCore and VorpCore.getUser and VorpCore.getUser(src)
    local ch = user and user.getUsedCharacter
    return ch and ch.charIdentifier or nil
end

local OFF_COLS <const> = { "x", "y", "z", "rx", "ry", "rz" }

-- SCHEMA: the offset columns must be FLOAT (INT rounds every offset to 0 and hides the prop);
-- the MODIFY pass below is a no-op when they already are
CreateThread(function()
    Wait(3000)
    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS prop_offsets (
        charidentifier INT(11) NOT NULL,
        item  VARCHAR(64) NOT NULL,
        x  FLOAT NOT NULL DEFAULT 0,
        y  FLOAT NOT NULL DEFAULT 0,
        z  FLOAT NOT NULL DEFAULT 0,
        rx FLOAT NOT NULL DEFAULT 0,
        ry FLOAT NOT NULL DEFAULT 0,
        rz FLOAT NOT NULL DEFAULT 0,
        PRIMARY KEY (charidentifier, item)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    for _, c in ipairs(OFF_COLS) do
        exports.oxmysql:execute(
            ("ALTER TABLE prop_offsets MODIFY COLUMN `%s` FLOAT NOT NULL DEFAULT 0"):format(c))
    end
end)

-- copy of the def with this character's saved offsets applied
local function defFor(src, itemName, def, cb)
    local charid = charIdOf(src)
    local out = {}
    for k, v in pairs(def) do out[k] = v end
    if not charid then return cb(out) end
    exports.oxmysql:single("SELECT x, y, z, rx, ry, rz FROM prop_offsets WHERE charidentifier = ? AND item = ?",
        { charid, itemName }, function(row)
            -- COERCE: a DECIMAL column comes back as a string and NULL as nil; a row that will not convert
            -- cleanly is dropped, so the prop falls back to its built-in offset
            if row then
                local c, ok = {}, true
                for i, k in ipairs(OFF_COLS) do
                    local v = tonumber(row[k])
                    if not v or v ~= v then ok = false break end
                    c[i] = v + 0.0
                end
                if ok then
                    out.custom = c
                else
                    print(("^3[pup-misc/props]^7 unusable saved offset for '%s' (char %s) - using the default")
                        :format(tostring(itemName), tostring(charid)))
                end
            end
            cb(out)
        end)
end

-- the placement part of a PropsConfig.Props entry (everything but the item row fields);
-- this is the `def` table the pup_props:toggle event carries to clients
local ITEM_FIELDS <const> = { item = true, label = true, limit = true }
local function placementOf(entry)
    local def = {}
    for k, v in pairs(entry) do
        if not ITEM_FIELDS[k] then def[k] = v end
    end
    if def.model == nil and def.model_male == nil and not def.animOnly then return nil end
    return def
end

CreateThread(function()
    -- items self-register; the loop is fire-and-forget, oxmysql logs failures
    for _, entry in ipairs(PropsConfig.Props) do
        exports.oxmysql:execute(
            "INSERT INTO items (item, label, `limit`, can_remove, type, usable) VALUES (?, ?, ?, 1, 'item_standard', 1) " ..
            "ON DUPLICATE KEY UPDATE type = 'item_standard', usable = 1, `limit` = VALUES(`limit`), label = VALUES(label)",
            { entry.item, entry.label, entry.limit or 1 })
    end

    for _, entry in ipairs(PropsConfig.Props) do
        local def = placementOf(entry)
        if def then
            exports.vorp_inventory:registerUsableItem(entry.item, function(data)
                local src = data.source
                exports.vorp_inventory:closeInventory(src)
                if not playerProps[src] then playerProps[src] = {} end

                if playerProps[src][entry.item] then
                    playerProps[src][entry.item] = nil
                    TriggerClientEvent("pup_props:toggle", -1, src, entry.item, def, false)
                    return
                end
                defFor(src, entry.item, def, function(d)
                    playerProps[src][entry.item] = d
                    TriggerClientEvent("pup_props:toggle", -1, src, entry.item, d, true)
                end)
            end, GetCurrentResourceName())
        else
            print(("^1[pup-misc/props]^7 no model in PropsConfig.Props for item '%s'")
                :format(tostring(entry.item)))
        end
    end

    print(("^2[pup-misc/props]^7 %d prop item(s) registered as usable"):format(#PropsConfig.Props))
end)

-- late joiner / instance change: send them everything currently worn
RegisterNetEvent("pup_props:requestSync")
AddEventHandler("pup_props:requestSync", function()
    local src = source
    for playerId, props in pairs(playerProps) do
        for itemName, def in pairs(props) do
            TriggerClientEvent("pup_props:toggle", src, playerId, itemName, def, true)
        end
    end
end)

-- what this player wears right now (for the /pa picker)
RegisterNetEvent("pup_props:requestWorn")
AddEventHandler("pup_props:requestWorn", function()
    local src = source
    local list = {}
    for itemName, def in pairs(playerProps[src] or {}) do
        list[#list + 1] = { item = itemName, def = def }
    end
    TriggerClientEvent("pup_props:worn", src, list)
end)

local function validOffsets(o)
    if type(o) ~= "table" then return nil end
    local out = {}
    for i = 1, 6 do
        local v = tonumber(o[i])
        if not v or v ~= v then return nil end
        if i <= 3 and math.abs(v) > 2.0 then return nil end
        out[i] = v + 0.0
    end
    return out
end

local lastOffsetChange = {}
local function offsetTooSoon(src)
    local now = GetGameTimer()
    if lastOffsetChange[src] and now - lastOffsetChange[src] < 1000 then return true end
    lastOffsetChange[src] = now
    return false
end

-- /pa save: only for a prop the player is wearing; re-broadcast so all see it
RegisterNetEvent("pup_props:saveOffset")
AddEventHandler("pup_props:saveOffset", function(itemName, offsets)
    local src = source
    if offsetTooSoon(src) then return end
    local def = playerProps[src] and playerProps[src][itemName]
    local o = validOffsets(offsets)
    local charid = charIdOf(src)
    if not def or not o or not charid then return end
    exports.oxmysql:execute(
        "INSERT INTO prop_offsets (charidentifier, item, x, y, z, rx, ry, rz) VALUES (?, ?, ?, ?, ?, ?, ?, ?) " ..
        "ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), rx = VALUES(rx), ry = VALUES(ry), rz = VALUES(rz)",
        { charid, itemName, o[1], o[2], o[3], o[4], o[5], o[6] })
    def.custom = o
    TriggerClientEvent("pup_props:toggle", -1, src, itemName, def, true)
end)

RegisterNetEvent("pup_props:resetOffset")
AddEventHandler("pup_props:resetOffset", function(itemName)
    local src = source
    if offsetTooSoon(src) then return end
    local def = playerProps[src] and playerProps[src][itemName]
    local charid = charIdOf(src)
    if not def or not charid then return end
    exports.oxmysql:execute("DELETE FROM prop_offsets WHERE charidentifier = ? AND item = ?", { charid, itemName })
    def.custom = nil
    TriggerClientEvent("pup_props:toggle", -1, src, itemName, def, true)
end)

local function takeOff(src, itemName)
    local def = playerProps[src] and playerProps[src][itemName]
    if not def then return end
    playerProps[src][itemName] = nil
    TriggerClientEvent("pup_props:toggle", -1, src, itemName, def, false)
end

-- A worn prop goes when the last of its item does (dropped, given, sold, stashed, lost on death). The count is only
-- right after the removal lands, as the give path fires this before it debits. A count that can't be read leaves it on.
local function checkStillOwned(src, itemName)
    if not (playerProps[src] and playerProps[src][itemName]) then return end
    SetTimeout(400, function()
        local ok, count = pcall(function() return exports.vorp_inventory:getItemCount(src, nil, itemName) end)
        if ok and tonumber(count) == 0 then takeOff(src, itemName) end
    end)
end

AddEventHandler("vorp_inventory:Server:OnItemRemoved", function(data, src)
    if type(data) == "table" and src then checkStillOwned(src, data.name) end
end)

AddEventHandler("vorp_inventory:Server:OnItemMovedToCustomInventory", function(data, _, src)
    if type(data) == "table" and src then checkStillOwned(src, data.name) end
end)

-- the next character doesn't wear what the last one had on. vorp_core fires this on the server.
AddEventHandler("vorp:SelectedCharacter", function(src)
    for itemName in pairs(playerProps[src] or {}) do takeOff(src, itemName) end
end)

AddEventHandler("playerDropped", function()
    local src = source
    lastOffsetChange[src] = nil
    if not playerProps[src] then return end
    for itemName, def in pairs(playerProps[src]) do
        TriggerClientEvent("pup_props:toggle", -1, src, itemName, def, false)
    end
    playerProps[src] = nil
end)
