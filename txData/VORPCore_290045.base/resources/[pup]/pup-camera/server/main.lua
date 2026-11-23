-- access is decided here from GetPlayerIdentifiers; privileged actions are re-checked

local function steamOf(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 6) == "steam:" then return id end
    end
    return nil
end

local function inList(list, steam)
    if not steam then return false end
    for _, id in ipairs(list or {}) do
        if id == steam then return true end
    end
    return false
end

local function allowed(src) return inList(Config.Access.allowed, steamOf(src)) end
local function unlimited(src) return inList(Config.Access.unlimited, steamOf(src)) end

local lastRefusal = {}
AddEventHandler("playerDropped", function() lastRefusal[source] = nil end)

-- one answer, asked on open
RegisterNetEvent("pup-camera:request", function()
    local src = source
    if not allowed(src) then
        TriggerClientEvent("pup-camera:denied", src)
        local nowMs = GetGameTimer()
        if not lastRefusal[src] or nowMs - lastRefusal[src] > 10000 then
            lastRefusal[src] = nowMs
            print(("^3[pup-camera]^7 %s (%s) was refused - not on the list")
                :format(GetPlayerName(src) or "?", tostring(steamOf(src))))
        end
        return
    end
    TriggerClientEvent("pup-camera:granted", src, {
        maxRange = unlimited(src) and 0.0 or (tonumber(Config.Access.maxRange) or 500.0),
    })
end)

-- opening the camera is logged by name
RegisterNetEvent("pup-camera:opened", function()
    local src = source
    if not allowed(src) then return end
    local c = GetEntityCoords(GetPlayerPed(src))
    print(("^2[pup-camera]^7 %s opened the camera at %.1f, %.1f, %.1f")
        :format(GetPlayerName(src) or "?", c.x, c.y, c.z))
end)

RegisterNetEvent("pup-camera:closed", function()
    local src = source
    if not allowed(src) then return end
    print(("^2[pup-camera]^7 %s closed the camera"):format(GetPlayerName(src) or "?"))
end)

exports("isAllowed", function(src) return allowed(src) end)
