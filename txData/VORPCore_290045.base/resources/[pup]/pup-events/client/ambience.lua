-- pup-events | Dead of Night scenery. All of this is local to the player.

-- BATS. Posed on a circle every frame: a tasked bat wanders off and fights the streamer.
local bats = {}        -- [n] = { ped, cx, cy, cz, r, h, lap, phase }
local batTown = nil

local function dropBats()
    for i, b in pairs(bats) do
        EVC.deleteEntity(b.ped)
        bats[i] = nil
    end
    batTown = nil
end

local function batHourOk(B)
    -- no hours set = the whole event, same as the UFO
    if not B.hourFrom or not B.hourTo then return true end
    local h <const> = GetClockHours()
    if not h then return false end
    local from, to = B.hourFrom, B.hourTo
    if from <= to then return h >= from and h < to end
    return h >= from or h < to
end

local function buildBats(B, town)
    local hash <const> = EVC.loadModel(B.model or 'A_C_Bat_01', 5000)
    if not hash then return false end

    local lo <const> = math.floor(tonumber(B.count and B.count[1]) or 6)
    local hi <const> = math.floor(tonumber(B.count and B.count[2]) or 11)
    local n <const> = math.random(lo, math.max(lo, hi))

    for i = 1, n do
        local r <const> = math.random() * ((B.radius[2] or 70.0) - (B.radius[1] or 25.0)) + (B.radius[1] or 25.0)
        local hgt <const> = math.random() * ((B.height[2] or 26.0) - (B.height[1] or 12.0)) + (B.height[1] or 12.0)
        local lap <const> = math.random() * ((B.lapSeconds[2] or 26.0) - (B.lapSeconds[1] or 14.0)) + (B.lapSeconds[1] or 14.0)
        local phase <const> = math.random() * math.pi * 2.0

        local ped = CreatePed(hash, town.centre.x + r, town.centre.y, town.centre.z + hgt,
            0.0, false, false, false, false)
        if ped and ped ~= 0 then
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)
            SetBlockingOfNonTemporaryEvents(ped, true)
            FreezeEntityPosition(ped, true)   -- we place it ourselves every frame
            SetEntityCollision(ped, false, false)
            bats[#bats + 1] = { ped = ped, cx = town.centre.x, cy = town.centre.y, cz = town.centre.z,
                                r = r, h = hgt, lap = lap, phase = phase }
        end
    end
    SetModelAsNoLongerNeeded(hash)
    return #bats > 0
end

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    while true do
        local wait = 1000
        local B <const> = Config.DeadOfNight.bats

        if B and B.enabled and EVC.isLive('deadofnight') and batHourOk(B) then
            local me <const> = GetEntityCoords(PlayerPedId())

            local near
            for _, t in ipairs(B.towns or {}) do
                if #(me - t.centre) <= (B.drawDistance or 160.0) then near = t break end
            end

            if near and batTown ~= near.name then
                dropBats()
                if buildBats(B, near) then batTown = near.name end
            elseif not near and batTown then
                dropBats()
            end

            if batTown and #bats > 0 then
                wait = 0
                local t <const> = GetGameTimer() / 1000.0
                for _, b in ipairs(bats) do
                    if DoesEntityExist(b.ped) then
                        local a <const> = b.phase + (t / b.lap) * math.pi * 2.0
                        local x <const> = b.cx + math.cos(a) * b.r
                        local y <const> = b.cy + math.sin(a) * b.r
                        -- a slow bob so the ring does not read as a carousel
                        local z <const> = b.cz + b.h + math.sin(a * 3.0) * 1.5
                        SetEntityCoordsNoOffset(b.ped, x, y, z, false, false, false)
                        SetEntityHeading(b.ped, (math.deg(a) + 90.0) % 360.0)
                    end
                end
            end
        elseif next(bats) then
            dropBats()
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then dropBats() end
end)

-- VAN HORN LIGHTHOUSE. A swept beam drawn every frame, no prop to stream.
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    while true do
        local wait = 1000
        local L <const> = Config.DeadOfNight.lighthouse

        if L and L.enabled and EVC.isLive('deadofnight') then
            local me <const> = GetEntityCoords(PlayerPedId())
            if #(me - L.coords) <= (L.drawDistance or 2200.0) then
                wait = 0
                local period <const> = (L.sweepSeconds or 8.0) * 1000.0
                local t <const> = (GetGameTimer() % period) / period
                local ang <const> = t * math.pi * 2.0
                local b <const> = L.beam or {}

                -- the lamp itself
                DrawLightWithRange(L.coords.x, L.coords.y, L.coords.z,
                    b.r or 255, b.g or 236, b.b or 190, b.range or 60.0, b.intensity or 10.0)

                -- the sweep, as a few lights thrown out along the bearing
                local reach <const> = L.reach or 180.0
                for step = 1, 4 do
                    local f <const> = reach * (step / 4)
                    DrawLightWithRange(
                        L.coords.x + math.cos(ang) * f,
                        L.coords.y + math.sin(ang) * f,
                        L.coords.z - (step * 1.5),
                        b.r or 255, b.g or 236, b.b or 190,
                        (b.range or 60.0) * 0.6, (b.intensity or 10.0) * (1.0 - step * 0.18))
                end
            end
        end

        Wait(wait)
    end
end)
