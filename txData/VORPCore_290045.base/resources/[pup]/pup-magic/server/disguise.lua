-- pup-magic | drinking a blood vial: wearing another character's face for a while
-- While it lasts, GlobalState['pup_disguise_<real charid>'] = true tells vorp_core, vorp_character,
-- pup_realestate and pup_camps not to save that character's look.

local B <const> = Config.Blood

Disguises = {} -- [src] = { real, borrowed, name, endsAt, warned }

local drinking = {} -- [src] = true while a vial use is being checked (stops a double use)

local function setFlag(charId, on)
    GlobalState:set(('pup_disguise_%s'):format(charId), on and true or false, true)
end

local function jsonOr(v)
    return (type(v) == 'string' and v ~= '') and v or '{}'
end

-- one character's look, or nil. Falls back to fewer columns when pup_clothing or the
-- tattoo columns are missing, so a disguise still works on a leaner database.
local LOOK_QUERIES <const> = {
    [[SELECT c.`firstname`, c.`lastname`, c.`skinPlayer`, c.`compPlayer`, c.`compTints`, c.`overlay`, c.`expressions`, x.`extras`
      FROM `characters` c LEFT JOIN `clothing_extras` x ON x.`charidentifier` = c.`charidentifier`
      WHERE c.`charidentifier` = ? LIMIT 1]],
    [[SELECT c.`firstname`, c.`lastname`, c.`skinPlayer`, c.`compPlayer`, c.`compTints`, c.`overlay`, c.`expressions`
      FROM `characters` c WHERE c.`charidentifier` = ? LIMIT 1]],
    [[SELECT c.`firstname`, c.`lastname`, c.`skinPlayer`, c.`compPlayer`, c.`compTints`
      FROM `characters` c WHERE c.`charidentifier` = ? LIMIT 1]],
}

local function fetchLook(charId)
    for i, q in ipairs(LOOK_QUERIES) do
        local ok, row = pcall(MySQL.single.await, q, { charId })
        if ok then
            if type(row) ~= 'table' then return nil end
            if type(row.skinPlayer) ~= 'string' or row.skinPlayer == '' then return nil end
            return row
        end
        WarnOnce('look' .. i, 'reading a look failed, trying fewer columns: ' .. tostring(row))
    end
    return nil
end

local function sendLook(src, row, event)
    TriggerClientEvent(event, src,
        jsonOr(row.skinPlayer), jsonOr(row.compPlayer), jsonOr(row.compTints),
        jsonOr(row.extras), jsonOr(row.overlay), jsonOr(row.expressions))
end

function VialSmoke(src)
    local p = PosOf(src)
    if not p then return end
    TriggerClientEvent('pup-magic:vialSmoke', -1, p.x + 0.0, p.y + 0.0, p.z + 0.0)
end

-- forget the record and lift the save block first, so nothing can leave saving blocked
local function drop(src)
    local rec = Disguises[src]
    if not rec then return nil end
    Disguises[src] = nil
    setFlag(rec.real, false)
    return rec
end

function EndDisguise(src, quiet)
    local rec = drop(src)
    if not rec or not Online(src) then return end
    CreateThread(function()
        local row = fetchLook(rec.real)
        if not Online(src) then return end
        local ch = CharOf(src)
        if not ch or ch.id ~= rec.real then return end -- switched character meanwhile: their reload already did it
        if Disguises[src] then return end -- drank another vial during the read: do not undo the new face
        if row then sendLook(src, row, 'pup-disguise:restore') else TriggerClientEvent('pup-disguise:restore', src) end
        if not quiet then
            TipBottom(src, Locale.faceGone, 6000)
            VialSmoke(src)
        end
    end)
end

local function useVial(data)
    if type(data) ~= 'table' then return end
    local src = PlayerIdOf(data.source)
    local item = data.item
    if not src or type(item) ~= 'table' then return end

    Inv.close(src)

    if Disguises[src] then
        TipBottom(src, Locale.alreadyDisguised, 4000)
        return
    end

    local meta = type(item.metadata) == 'table' and item.metadata or {}
    local borrowed = math.tointeger(tonumber(meta.bloodChar))
    local me = CharOf(src)
    if not borrowed or (me and borrowed == me.id) then
        TipBottom(src, Locale.vialSpoiled, 4000)
        return
    end
    if not me or drinking[src] then return end

    drinking[src] = true
    local ok, found = pcall(MySQL.scalar.await, 'SELECT 1 FROM `characters` WHERE `charidentifier` = ? LIMIT 1', { borrowed })
    drinking[src] = nil
    if not ok then WarnOnce('vial.db', 'checking a vial owner failed: ' .. tostring(found)) return end

    -- the read waited: same player, same character, still not disguised
    if not Online(src) or Disguises[src] then return end
    local now = CharOf(src)
    if not now or now.id ~= me.id then return end
    if not found then
        TipBottom(src, Locale.vialNobody, 4000)
        return
    end

    if not Inv.removeById(src, item.id) then return end

    local name = Trim(meta.bloodName)
    if name == '' then name = Locale.someone end

    local drinkMs = math.max(0, tonumber(B.drinkMs) or 0)
    local rec = {
        real = me.id, borrowed = borrowed, name = name,
        endsAt = GetGameTimer() + (tonumber(B.durationMs) or 0), warned = false,
    }
    Disguises[src] = rec
    setFlag(me.id, true)

    TriggerClientEvent('pup-magic:drink', src)
    VialSmoke(src)

    SetTimeout(drinkMs, function()
        if Disguises[src] ~= rec or not Online(src) then return end
        local row = fetchLook(borrowed)
        if Disguises[src] ~= rec or not Online(src) then return end
        if not row then
            EndDisguise(src, true)
            TipBottom(src, Locale.vialNobody, 4000)
            return
        end
        sendLook(src, row, 'pup-disguise:apply')
        TipBottom(src, Locale.wearingFace:format(rec.name), 6000)
    end)
end

local function formatLeft(ms)
    local total = math.max(0, math.floor(ms / 1000))
    local m, s = total // 60, total % 60
    local secs = (s == 1 and Locale.secondOne or Locale.secondMany):format(s)
    if m >= 1 then
        return (m == 1 and Locale.minuteOne or Locale.minuteMany):format(m) .. ' ' .. secs
    end
    return secs
end

RegisterCommand('bloodtime', function(src)
    src = math.tointeger(tonumber(src)) or 0
    if src == 0 then print(Locale.inGameOnly) return end
    local rec = Disguises[src]
    if not rec then
        TipBottom(src, Locale.ownFace, 4000)
        return
    end
    TipBottom(src, Locale.faceTimeLeft:format(rec.name, formatLeft(rec.endsAt - GetGameTimer())), 6000)
end, false)

exports('EndDisguise', function(src)
    src = PlayerIdOf(src)
    if src then EndDisguise(src, false) end
end)

exports('IsDisguised', function(src)
    src = math.tointeger(tonumber(src))
    return src ~= nil and Disguises[src] ~= nil
end)

-- the once-a-second check over every borrowed face
CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for src, rec in pairs(Disguises) do
            if not Online(src) then
                drop(src)
            else
                local ch = CharOf(src)
                if not ch or ch.id ~= rec.real then
                    drop(src) -- switched character: the new one loads its own look, nothing to restore
                else
                    local left = rec.endsAt - now
                    if left <= 0 then
                        EndDisguise(src, false)
                    elseif not rec.warned and left <= (tonumber(B.warnBeforeMs) or 0) then
                        rec.warned = true
                        TipBottom(src, Locale.faceSlipping, 6000)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- after vorp_inventory has settled
    SetTimeout(1500, function()
        local ok, err = pcall(function()
            -- the use runs in a thread of ours: it waits on the database
            exports.vorp_inventory:registerUsableItem(B.item, function(data)
                CreateThread(function() useVial(data) end)
            end, GetCurrentResourceName())
        end)
        if not ok then print(('^1[pup-magic]^7 could not make %s usable: %s'):format(B.item, tostring(err))) end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = math.tointeger(tonumber(source))
    if not src then return end
    drop(src)
    drinking[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, rec in pairs(Disguises) do
        setFlag(rec.real, false)
        -- vorp_character falls back to the snapshot it took before the swap; no database work at shutdown
        if Online(src) then TriggerClientEvent('pup-disguise:restore', src) end
    end
    Disguises = {}
    pcall(function() exports.vorp_inventory:unRegisterUsableItem(B.item) end)
end)
