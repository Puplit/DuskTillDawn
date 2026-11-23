-- pup_camps | snake-bite poison (server record; survives relog, optionally restarts)

local Poisoned = {}  -- [charid] = true

local function kvpKey(charid) return ('poison:%d'):format(charid) end

local function isPoisoned(charid)
    if Poisoned[charid] then return true end
    if Config.Poison.persistRestart and GetResourceKvpInt(kvpKey(charid)) == 1 then
        Poisoned[charid] = true
        return true
    end
    return false
end

local function setPoisoned(charid, on)
    Poisoned[charid] = on or nil
    if Config.Poison.persistRestart then
        if on then SetResourceKvpInt(kvpKey(charid), 1) else DeleteResourceKvp(kvpKey(charid)) end
    end
end

Handle('poisonBit', function(ctx)
    if not Config.Poison.enabled then return false end
    setPoisoned(ctx.charid, true)
    return true
end, { gapMs = 2000 })

Handle('poisonStatus', function(ctx)
    return Config.Poison.enabled and isPoisoned(ctx.charid) or false
end, { gapMs = 1000 })

-- the client may only clear it itself while dead (and only when cure-on-death is on)
Handle('poisonClearDead', function(ctx)
    if not Config.Poison.cureOnDeath then return false end
    local ped = GetPlayerPed(ctx.src)
    if ped == 0 or GetEntityHealth(ped) > 0 then return false end
    setPoisoned(ctx.charid, false)
    return true
end, { gapMs = 2000 })

for _, item in ipairs(Config.Poison.cureItems) do
    exports.vorp_inventory:registerUsableItem(item, function(data)
        local src = data.source
        local ctx = Ctx(src)
        if not ctx then return end
        if not isPoisoned(ctx.charid) then
            Notify(src, L('poison_none'))
            return
        end
        if not exports.vorp_inventory:subItem(src, item, 1) then return end
        setPoisoned(ctx.charid, false)
        TriggerClientEvent('vorp_inventory:CloseInv', src)
        TriggerClientEvent('pup_camps:cl:poisonCured', src)
        Notify(src, L('poison_cured'))
    end, GetCurrentResourceName())
end
