-- pup-misc / tattoos - server: overlay and expression storage, charging and loading

local VORPcore = exports.vorp_core:GetCore()

-- Ensure VORP is ready
Citizen.CreateThread(function()
    while VORPcore == nil do
        Citizen.Wait(100)
        VORPcore = exports.vorp_core:GetCore()
    end
end)

-- this feature keeps its data in two columns on `characters`
local function DebugPrint(msg)
    if TattooConfig.General.debug then
        print("^2[DEBUG]^7 " .. msg)
    end
end
-- the columns this feature needs on `characters`, added when missing
local REQUIRED_COLUMNS <const> = {
    overlay     = "LONGTEXT NULL DEFAULT NULL",
    expressions = "LONGTEXT NULL DEFAULT NULL",
}

local function ensureColumn(column, definition)
    exports.oxmysql:scalar(
        "SELECT COUNT(*) FROM information_schema.COLUMNS " ..
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters' AND COLUMN_NAME = ?",
        { column },
        function(count)
            if tonumber(count) and tonumber(count) > 0 then
                DebugPrint(("column characters.%s present"):format(column))
                return
            end

            print(("^3[pup-misc/tattoos]^7 characters.%s missing - creating it."):format(column))
            exports.oxmysql:execute(
                ("ALTER TABLE characters ADD COLUMN %s %s"):format(column, definition), {},
                function()
                    print(("^2[pup-misc/tattoos]^7 created characters.%s"):format(column))
                end)
        end)
end

CreateThread(function()
    Wait(3000)
    for column, definition in pairs(REQUIRED_COLUMNS) do
        ensureColumn(column, definition)
        Wait(250)
    end
end)

-- if a murphy_barber table exists, mirror saves blank its overlay rows so they stop repainting
local hasMurphyBarber = false
CreateThread(function()
    Wait(3500)
    exports.oxmysql:scalar(
        "SELECT COUNT(*) FROM information_schema.TABLES " ..
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'murphy_barber'",
        {},
        function(count)
            hasMurphyBarber = (tonumber(count) or 0) > 0
            if hasMurphyBarber then
                DebugPrint("murphy_barber present - mirror saves take over its overlays")
            end
        end)
end)

local MAX_OVERLAY_BYTES <const> = 65536

-- per-player gap between the load requests a client can send
local lastLoad = {}
local function tooFast(src, kind, gap)
    local now = GetGameTimer()
    local mine = lastLoad[src]
    if not mine then mine = {}; lastLoad[src] = mine end
    if mine[kind] and now - mine[kind] < gap then return true end
    mine[kind] = now
    return false
end
AddEventHandler("playerDropped", function() lastLoad[source] = nil end)

-- A failed query never calls an oxmysql callback (it only logs), so anything charged before a
-- save has to wait on the result. Rows changed, or nil if the save failed.
local function saveRows(sql, params)
    local ok, rows = pcall(MySQL.update.await, sql, params)
    if not ok then return nil end
    return tonumber(rows)
end

-- Handle character selection to load data. vorp_core fires this on the server, so it needs no net registration:
-- registering it here would open every handler of this event in pup-misc to clients.
AddEventHandler("vorp:SelectedCharacter", function(source, character)
    local _source = source
    -- Trigger initial load for overlays and expressions
    TriggerEvent("pup-misc:overlay:walkanim", _source)
end)

-- save overlay data and charge the player
RegisterServerEvent("pup-misc:overlay:savetodb")
AddEventHandler("pup-misc:overlay:savetodb", function(info)
    local _source = source
    if type(info) ~= "string" or #info > MAX_OVERLAY_BYTES then return end
    local User = VORPcore.getUser(_source)
    if not User then return end
    
    local Character = User.getUsedCharacter
    
    -- nil-safety
    if not Character then 
        DebugPrint("Save failed: Character not found for source " .. _source)
        return 
    end

    local charid = Character.charIdentifier
    local cash = Character.money
    local price = TattooConfig.Prices.layers or 0

    -- A save always costs; the client doesn't get a say
    if cash < price then
        VORPcore.NotifyLeft(_source, TattooLocale.errorTitle, TattooLocale.notEnoughMoney, "generic_textures", "tick", 4000)
        TriggerClientEvent("pup-misc:overlay:saveResult", _source, false)
        return
    end

    Character.removeCurrency(0, price)
    DebugPrint("Charged player " .. charid .. " amount: " .. price)

    local rows = saveRows("UPDATE characters SET overlay = ? WHERE charidentifier = ?", {info, charid})
    if rows == nil then
        Character.addCurrency(0, price)
        print(("^1[pup-misc/tattoos]^7 SAVE FAILED for charid %s - the UPDATE returned nothing. Refunded."):format(charid))
        print("^1[pup-misc/tattoos]^7 Usually characters.overlay does not exist. Check the startup lines above.")
        VORPcore.NotifyLeft(_source, TattooLocale.errorTitle, TattooLocale.saveFailed, "generic_textures", "tick", 5000)
        TriggerClientEvent("pup-misc:overlay:saveResult", _source, false)
        return
    end
    -- rows == 0 is normal when the layers are identical to what is already stored: MySQL reports 0 changed rows
    DebugPrint(("Saved overlay for charid %s (%d row(s) changed)"):format(charid, rows))
    VORPcore.NotifyLeft(_source, TattooLocale.successTitle, TattooLocale.saved, "generic_textures", "tick", 4000)
    TriggerClientEvent("pup-misc:overlay:saveResult", _source, true)
    if hasMurphyBarber then
        exports.oxmysql:update(
            "UPDATE murphy_barber SET overlays = '', permanentoverlay = '' WHERE charid = ?",
            { charid })
    end
end)

-- silent save (no charge), only for a character with no overlay saved yet: the client sends it once to seed an empty row
RegisterServerEvent("pup-misc:overlay:savetodb2")
AddEventHandler("pup-misc:overlay:savetodb2", function(info)
    local _source = source
    if type(info) ~= "string" or #info > MAX_OVERLAY_BYTES then return end
    local User = VORPcore.getUser(_source)
    if not User then return end
    
    local Character = User.getUsedCharacter
    if not Character then return end

    local charid = Character.charIdentifier

    -- :update, so the row count is a number
    exports.oxmysql:update("UPDATE characters SET overlay = ? WHERE charidentifier = ? AND (overlay IS NULL OR overlay = '' OR overlay = '{}' OR overlay = '[]')", {info, charid}, function(result)
        DebugPrint(("Silent saved overlay for charid %s from source %s (%s row(s))")
            :format(charid, _source, tostring(result)))
    end)
end)

-- request overlay/expression data on load; from the client or from other server events
RegisterServerEvent("pup-misc:overlay:walkanim")
AddEventHandler("pup-misc:overlay:walkanim", function(targetSource)
    -- a player only ever reloads themselves; the server names a target when it calls this itself
    local caller = tonumber(source)
    local _source = (caller and caller > 0) and caller or tonumber(targetSource)
    if not _source then return end
    -- only client requests are spaced out; the server's own load on character select always runs.
    -- one request inside the gap is run once the gap is over, so a reload is never lost
    if caller and caller > 0 and tooFast(_source, "walkanim", 2000) then
        local mine = lastLoad[_source]
        if mine.walkanimQueued then return end
        mine.walkanimQueued = true
        SetTimeout(2000, function()
            if lastLoad[_source] then lastLoad[_source].walkanimQueued = nil end
            if GetPlayerName(_source) then TriggerEvent("pup-misc:overlay:walkanim", _source) end
        end)
        return
    end
    local User = VORPcore.getUser(_source)
    if not User then return end
    
    local Character = User.getUsedCharacter
    
    -- nil-safety
    if not Character then 
        DebugPrint("Load failed: Character not found for source " .. _source)
        return 
    end

    local charid = Character.charIdentifier

    -- overlay, skin and expressions from the characters table
    exports.oxmysql:execute("SELECT overlay, skinPlayer AS skin, expressions FROM characters WHERE charidentifier = ?", {charid}, function(result)
        if result and result[1] then
            local overlay = result[1].overlay or "{}"
            local skin = result[1].skin or "{}"
            local expressions = result[1].expressions or "{}"
            
            -- Send data back to client to apply visuals
            TriggerClientEvent('pup-misc:overlay:recinfo', _source, skin, overlay)
            TriggerClientEvent('pup-misc:overlay:receiveExpressions', _source, json.decode(expressions))
            DebugPrint("Successfully sent character data to source " .. _source .. " for charid: " .. charid)
        else
            DebugPrint("No character data found for charid: " .. charid)
        end
    end)
end)

-- Save current MetaPed expressions to the database
RegisterServerEvent("pup-misc:overlay:saveExpressions")
AddEventHandler("pup-misc:overlay:saveExpressions", function(payload)
    local _source = source
    local User = VORPcore.getUser(_source)
    if not User then return end
    
    local Character = User.getUsedCharacter
    if not Character then 
        TriggerClientEvent("pup-misc:overlay:expressionSaveResult", _source, false, "Character not found")
        return 
    end

    -- do not re-encode: buildPayload (client/tattoos/expression.lua) already returns a JSON string
    local expressionData = type(payload) == "string" and payload or json.encode(payload)
    if #expressionData > MAX_OVERLAY_BYTES then return end

    local charid = Character.charIdentifier
    local cash = Character.money
    local price = TattooConfig.Prices.bodyAdjustments or 0

    -- Security validation: Ensure player has enough funds on the server side
    if cash < price then
        TriggerClientEvent("pup-misc:overlay:expressionSaveResult", _source, false, "funds")
        return
    end

    -- Process payment
    Character.removeCurrency(0, price)

    local rows = saveRows("UPDATE characters SET expressions = ? WHERE charidentifier = ?", {expressionData, charid})
    if rows == nil then
        Character.addCurrency(0, price)
        print(("^1[pup-misc/tattoos]^7 EXPRESSION SAVE FAILED for charid %s - UPDATE returned nothing. Refunded."):format(charid))
        print("^1[pup-misc/tattoos]^7 Usually characters.expressions does not exist. Check the startup lines above.")
        TriggerClientEvent("pup-misc:overlay:expressionSaveResult", _source, false, "Database error")
        return
    end
    -- 0 is normal when they saved the same values back, but it is also what a
    -- charid that matches no row looks like, so it does not pass quietly
    if rows == 0 then
        print(("^3[pup-misc/tattoos]^7 expression save changed NO row for charid %s - identical values, or no such character")
            :format(charid))
    end
    DebugPrint(("Saved expressions for charid %s (%d row(s) changed)"):format(charid, rows))
    TriggerClientEvent("pup-misc:overlay:expressionSaveResult", _source, true)
end)

-- Fetch expressions from DB on request
RegisterServerEvent("pup-misc:overlay:requestExpressions")
AddEventHandler("pup-misc:overlay:requestExpressions", function()
    local _source = source
    if tooFast(_source, "expressions", 2000) then return end
    local User = VORPcore.getUser(_source)
    if not User then return end
    
    local Character = User.getUsedCharacter
    if not Character then return end
    
    local charid = Character.charIdentifier

    exports.oxmysql:execute("SELECT expressions FROM characters WHERE charidentifier = ?", {charid}, function(result)
        if result and result[1] then
            local expressions = result[1].expressions or "{}"
            TriggerClientEvent('pup-misc:overlay:receiveExpressions', _source, json.decode(expressions))
            DebugPrint("Successfully sent expressions to source " .. _source .. " for charid: " .. charid)
        end
    end)
end)
