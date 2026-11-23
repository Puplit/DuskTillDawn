-- pup_railroad | client: sitting on train seats and the Saint Denis platform chairs

local L <const> = Rail.L
local S <const> = Config.Seats

local TRAIN_SEAT <const> = GetHashKey(S.trainSeat)
local CHAIR <const> = GetHashKey(S.chair)

-- GET_SCENARIO_POINTS_IN_AREA fills a buffer: entry i sits at byte offset 8 * i
local function seatNear(pos, chairsAllowed)
    local buffer = string.rep('\0', 8 * (S.maxPoints + 1) + 8)
    local count = Citizen.InvokeNative(0x345EC3B7EBDE1CB5, pos.x, pos.y, pos.z, S.searchRadius, buffer, S.maxPoints, Citizen.ResultAsInteger())
    count = math.min(tonumber(count) or 0, S.maxPoints)
    for i = 1, count do
        local point = string.unpack('<i4', buffer, 8 * i + 1)
        if point and point ~= 0 then
            local kind = Citizen.InvokeNative(0xA92450B5AE687AAF, point, Citizen.ResultAsInteger()) -- scenario point type
            if kind == TRAIN_SEAT or (chairsAllowed and kind == CHAIR) then return point end
        end
    end
    return nil
end

local function usingScenario(ped)
    return Citizen.InvokeNative(0x57AB4A3080F85143, ped, Citizen.ResultAsInteger()) ~= 0 -- IS_PED_USING_ANY_SCENARIO
end

CreateThread(function()
    local group = Cl.newGroup()
    local prompt = Cl.newPrompt(Config.Keys.interact, L('sit'), group)
    Cl.onCleanup(function() Cl.deletePrompt(prompt) end)

    local seated, seatedAt, hiddenUntil = false, 0, 0
    local point = nil
    local lastScan = 0

    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local now = GetGameTimer()

        if seated and now - seatedAt > S.settleGrace and not usingScenario(ped) then
            seated = false -- stood up some other way
        end

        if Cl.menuOpen or Cl.incapacitated(ped) then
            point = nil
        else
            if not seated and now - lastScan >= 500 then
                lastScan = now
                local pos = GetEntityCoords(ped)
                point = seatNear(pos, #(pos - S.chairCentre) <= S.chairRadius)
            end
            if (seated or point) and now >= hiddenUntil then
                sleep = 0
                Cl.promptText(prompt, seated and L('get_up') or L('sit'))
                Cl.showGroup(group, L('group_chair'))
                if Cl.promptPressed(prompt) then
                    hiddenUntil = now + S.pressCooldown
                    if seated then
                        ClearPedTasks(ped)
                        seated = false
                    elseif point then
                        ClearPedTasks(ped)
                        Cl.native('TaskUseScenarioPoint', 0xCCDAE6324B6A821C, ped, point, '', -1.0, true, false, 0, false, -1.0, true)
                        seated, seatedAt = true, now
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
