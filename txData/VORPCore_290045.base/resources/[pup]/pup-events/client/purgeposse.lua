-- pup-events | THE PURGE: posse blips, and your shots cannot hurt them.
-- Damage comes from the attacker's machine, so this only disarms MY guns.

local active = false
local blips = {}       -- serverId -> blip
local shielded = {}     -- serverId -> ped we turned off, so it can be turned back on

local function cfg()
    local purge = Config.Events and Config.Events.purge
    return (purge and purge.posse) or {}
end

-- posse mates other than me, as serverId -> name
local function mates()
    local ok, p = pcall(function() return exports['pup-ui']:GetPosseLocal() end)
    if not ok or type(p) ~= 'table' or p.inPosse ~= true then return nil end
    local me <const> = GetPlayerServerId(PlayerId())
    local out = {}
    for _, m in ipairs(p.members or {}) do
        local s = tonumber(m.src)
        if s and s ~= me then out[s] = m.name or 'Posse' end
    end
    return out
end

local function pedOf(serverId)
    local idx <const> = GetPlayerFromServerId(serverId)
    if not idx or idx == -1 then return nil end
    local ped <const> = GetPlayerPed(idx)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

local function dropBlip(serverId)
    if blips[serverId] then
        RemoveBlip(blips[serverId])
        blips[serverId] = nil
    end
end

local function unshield(serverId)
    local ped = shielded[serverId]
    if ped and DoesEntityExist(ped) then
        SetEntityCanBeDamaged(ped, true)
    end
    shielded[serverId] = nil
end

local function clearAll()
    for id in pairs(blips) do dropBlip(id) end
    for id in pairs(shielded) do unshield(id) end
    blips, shielded = {}, {}
end

-- pup-events:state is what the server broadcasts, with the event key
RegisterNetEvent('pup-events:state', function(key, on)
    if key ~= 'purge' then return end
    active = on == true
    if not active then clearAll() end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local c <const> = cfg()

        if active and (c.blips ~= false or c.noFriendlyFire ~= false) then
            sleep = 500
            local list = mates()

            -- left the posse, or it was disbanded
            if not list then
                if next(blips) or next(shielded) then clearAll() end
            else
                for id in pairs(blips) do
                    if not list[id] then dropBlip(id) end
                end
                for id in pairs(shielded) do
                    if not list[id] then unshield(id) end
                end

                for id, name in pairs(list) do
                    local ped = pedOf(id)
                    if ped then
                        if c.blips ~= false and not blips[id] then
                            -- blip bound to the ped, so it tracks them without a loop
                            local b = Citizen.InvokeNative(0x23F74C2FDA6E7C61,
                                tonumber(c.blipSprite) or 953018525, ped)
                            if b then
                                Citizen.InvokeNative(0x9CB1A1623062F402, b, name)
                                blips[id] = b
                            end
                        end
                        -- re-applied as they stream in and out: the flag does not
                        -- survive the ped being rebuilt
                        if c.noFriendlyFire ~= false then
                            SetEntityCanBeDamaged(ped, false)
                            shielded[id] = ped
                        end
                    else
                        dropBlip(id)
                        shielded[id] = nil
                    end
                end
            end
        elseif next(blips) or next(shielded) then
            clearAll()
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearAll() end
end)
