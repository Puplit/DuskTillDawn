-- pup-medical | small helpers used on both sides

MEDICAL_TYPE   = 'Medical'      -- the alert type other code and the death rules look for
ALERT_COOLDOWN = 60             -- seconds between two sends of one alert type
UNKNOWN_ZONE   = 'Unknown Zone'

function InList(list, value)
    if type(list) ~= 'table' or value == nil then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

-- alert type keys in a fixed order, so "the first matching type" is stable
function AlertTypeKeys()
    local keys = {}
    for k in pairs((Config.Alerts and Config.Alerts.types) or {}) do
        if type(k) == 'string' then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return keys
end

function AlertType(key)
    if type(key) ~= 'string' then return nil end
    local types = Config.Alerts and Config.Alerts.types
    local def = types and types[key]
    if type(def) ~= 'table' then return nil end
    return def
end

-- zone display names, for checking a name a client sent
local zoneNames = nil
function IsKnownZone(name)
    if type(name) ~= 'string' or name == '' or name == 'Unknown' then return false end
    if not zoneNames then
        zoneNames = {}
        for _, v in pairs(Config.Zones or {}) do zoneNames[v] = true end
    end
    return zoneNames[name] == true
end

function CleanZone(name)
    if IsKnownZone(name) then return name end
    return UNKNOWN_ZONE
end

-- 3725 -> "01h 02m 05s"
function HoursMinutesSeconds(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    return ('%02dh %02dm %02ds'):format(sec // 3600, (sec % 3600) // 60, sec % 60)
end

-- 45 -> "45s", 125 -> "2m 05s"
function ShortWait(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    if sec < 60 then return ('%ds'):format(sec) end
    return ('%dm %02ds'):format(sec // 60, sec % 60)
end

---------------------------------------------------------------------------
-- Purge overrides: while the purge is live, Config.Purge.overrides replaces
-- the same keys of Config.Death.prompt; the saved values come back after.
---------------------------------------------------------------------------
PurgeApplied = false
local savedPrompt = nil

function SetPurgeApplied(on)
    on = on == true
    if on == PurgeApplied then return false end
    local prompt = Config.Death and Config.Death.prompt
    if type(prompt) ~= 'table' then return false end

    if on then
        savedPrompt = {}
        for k, v in pairs((Config.Purge and Config.Purge.overrides) or {}) do
            savedPrompt[k] = { value = prompt[k] }
            prompt[k] = v
        end
    else
        for k, box in pairs(savedPrompt or {}) do
            prompt[k] = box.value
        end
        savedPrompt = nil
    end

    PurgeApplied = on
    print(('[pup-medical] purge rules %s - respawn delay is now %ss'):format(
        on and 'ON' or 'OFF', tostring(prompt.respawnDelaySeconds or 0)))
    return true
end

function PurgeStatus()
    local prompt = (Config.Death and Config.Death.prompt) or {}
    return { applied = PurgeApplied == true, respawnDelay = tonumber(prompt.respawnDelaySeconds) or 0 }
end
