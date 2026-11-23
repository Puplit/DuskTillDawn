local recordedCoords = {}
local MAX_RECORDS <const> = 200

local Core = nil
TriggerEvent("getCore", function(core) Core = core end)

-- a staff tool. Source 0 is the server console.
local function isStaff(src)
    if src == 0 then return true end
    local user = Core and Core.getUser(src)
    if not user then return false end
    local character = user.getUsedCharacter
    return (character and character.group == "admin") or user.getGroup == "admin" or false
end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

RegisterServerEvent('pup-misc:coords:record')
AddEventHandler('pup-misc:coords:record', function()
    local src = source
    if not isStaff(src) then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    -- the server's own reading: nothing the client sends ends up in the list or the console
    local c = GetEntityCoords(ped)
    local coords = ("{x=%s,y=%s,z=%s},"):format(round2(c.x), round2(c.y), round2(c.z))
    if #recordedCoords >= MAX_RECORDS then table.remove(recordedCoords, 1) end
    local playerName = GetPlayerName(src) or tostring(src)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    table.insert(recordedCoords, { player = playerName, coords = coords, time = timestamp })
    print("^2[Coords Recorded]^7 Player: " .. playerName .. " | Coords: " .. coords .. " | Time: " .. timestamp)
end)

RegisterCommand(CoordtoolConfig.General.commands.list, function(source, args, rawCommand)
    if not isStaff(source) then return end
    if source == 0 then
        for i, record in ipairs(recordedCoords) do
            print(i .. ". " .. record.player .. " - " .. record.coords .. " (" .. record.time .. ")")
        end
        return
    end
    if #recordedCoords == 0 then
        TriggerClientEvent('chat:addMessage', source, {
            args = {CoordtoolLocale.chatTitle, CoordtoolLocale.none}
        })
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        args = {CoordtoolLocale.chatTitle, CoordtoolLocale.total .. #recordedCoords}
    })

    for i, record in ipairs(recordedCoords) do
        TriggerClientEvent('chat:addMessage', source, {
            args = {CoordtoolLocale.chatTitle, i .. ". " .. record.player .. " - " .. record.coords .. " (" .. record.time .. ")"}
        })
    end
end)

RegisterCommand(CoordtoolConfig.General.commands.clear, function(source, args, rawCommand)
    if not isStaff(source) then return end
    recordedCoords = {}
    print("^2[Coords Cleared]^7")
end)
