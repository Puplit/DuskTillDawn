-- pup_mortician | client side of the undertaker's work: setting a body down,
-- the preparation animation and the two kinds of burial

Work = {}
local A = Config.Anim

-- set the carried body on the ground in front of the player, then ask
function Work.LayBody(key)
    local body = CarriedCorpse()
    if not body then
        Tip(L('notCarrying'))
        return false
    end
    local net = EnsureNetworked(body)
    if not net then
        Tip(L('notCarrying'))
        return false
    end
    local ped = PlayerPedId()
    NetworkRequestControlOfEntity(body)
    DetachEntity(body, true, true)
    local front = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
    SetEntityCoords(body, front.x, front.y, front.z, false, false, false, false)
    PlaceEntityOnGroundProperly(body, false)
    Wait(800)
    local res = Act('lay', { key = key, net = net })
    Say(res)
    return res.ok
end

-- the goods are already taken; this is the cosmetic part
function Work.Prepare(count)
    local ms = math.min(A.prepMaxMs, A.prepBaseMs + A.prepPerGoodMs * math.max(0, (count or 1) - 1))
    local ped = PlayerPedId()
    if LoadDict(A.prepDict) then
        TaskPlayAnim(ped, A.prepDict, A.prepClip, 2.0, -2.0, -1, 1, 0.0, false, false, false, '', false)
    end
    ProgressWait(L('progPrep'), ms)
    StopAnimTask(ped, A.prepDict, A.prepClip, 1.0)
end

local function shovelScene()
    local ms = PerkTimed(A.buryMs)
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, joaat(A.buryScenario), -1, true, false, false, false)
    SetTimeout(math.floor(ms * A.buryScenarioShare), function()
        ClearPedTasks(PlayerPedId(), true, false)
    end)
    ProgressWait(L('progBury'), ms)
end

-- run by the world prompt, which holds Busy for the whole call
function Work.BuryCasket()
    local key = Carry.key
    if not key then return end
    local res = Act('bury', { key = key })
    if res.ok then
        Carry.Stop()
        shovelScene()
    end
    Say(res)
    RefreshStatus()
end

-- run by the world prompt, which holds Busy for the whole call
function Work.BuryBody(yardId)
    local body = CarriedCorpse()
    if not body then return end
    local net = EnsureNetworked(body)
    if not net then
        Tip(L('notCarrying'))
        return
    end
    local res = Act('grave', { id = yardId, net = net })
    if res.ok then shovelScene() end
    Say(res)
    RefreshStatus()
end
