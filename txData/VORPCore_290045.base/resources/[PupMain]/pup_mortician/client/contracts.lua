-- pup_mortician | collecting the dead for a held posting: marker, route,
-- spawning the bodies and telling the server when we arrive

Contract = { posting = nil, blip = nil, markerAt = nil, cleared = false, bodies = {}, arriving = false, respotting = false }

local CC = Config.Contracts

local function removeMarker()
    DropBlip(Contract.blip)
    Contract.blip = nil
    if Contract.markerAt then ClearGpsMultiRoute() end
    Contract.markerAt = nil
end

local function placeMarker(pickup)
    removeMarker()
    Contract.blip = AddBlip(pickup, L('blipCollect'), 0.8)
    local from = GetEntityCoords(PlayerPedId())
    StartGpsMultiRoute(joaat('COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(from.x, from.y, from.z)
    AddPointToGpsMultiRoute(pickup.x, pickup.y, pickup.z)
    SetGpsMultiRouteRender(true)
    Contract.markerAt = pickup
end

local function carriedOrAttached(ent)
    local ped = PlayerPedId()
    return IsEntityAttachedToEntity(ent, ped) or CarriedCorpse() == ent
end

local function existingBodies()
    local n = 0
    for i = #Contract.bodies, 1, -1 do
        if DoesEntityExist(Contract.bodies[i]) then
            n = n + 1
        else
            table.remove(Contract.bodies, i)
        end
    end
    return n
end

-- deletes spawned bodies; keepCarried leaves the one on the player's shoulder
local function deleteBodies(keepCarried)
    for i = #Contract.bodies, 1, -1 do
        local ent = Contract.bodies[i]
        if not (keepCarried and DoesEntityExist(ent) and carriedOrAttached(ent)) then
            DeleteObj(ent)
            table.remove(Contract.bodies, i)
        end
    end
end

function Contract.Clear()
    deleteBodies(false)
    removeMarker()
    Contract.posting = nil
    Contract.cleared = false
end

-- called with the holder view from every status / reply
function Contract.Set(posting)
    if type(posting) ~= 'table' or not posting.pickup then
        if Contract.posting then
            deleteBodies(true)
            removeMarker()
        end
        Contract.posting = nil
        Contract.cleared = false
        return
    end
    local pickup = vector3(posting.pickup.x, posting.pickup.y, posting.pickup.z)
    posting.pickupVec = pickup
    local old = Contract.posting
    if old and old.id ~= posting.id then
        deleteBodies(true)
        removeMarker()
        Contract.cleared = false
    elseif old and old.pickupVec and #(old.pickupVec - pickup) > 2.0 then
        -- re-spotted: bodies at the old place are gone
        deleteBodies(false)
        removeMarker()
        Contract.cleared = false
    end
    Contract.posting = posting
end

-- ground at x, y: z and normal, or nil
local function findGround(x, y, zHint)
    for _ = 1, 15 do
        RequestCollisionAtCoord(x, y, zHint)
        for _, h in ipairs({ zHint + 50.0, 200.0, 100.0 }) do
            local found, z, normal = GetGroundZAndNormalFor_3dCoord(x, y, h)
            if found then return z, normal end
        end
        Wait(100)
    end
    return nil
end

local function askRespot()
    if Contract.respotting then return end
    Contract.respotting = true
    local res = Act('respot', {})
    Say(res)
    if res.ok and res.posting then Contract.Set(res.posting) end
    -- the server throttles too; this keeps us from asking more often
    SetTimeout(CC.respotThrottle * 1000, function() Contract.respotting = false end)
end

local function tagBody(ped)
    local net = EnsureNetworked(ped)
    if not net then return end
    for _ = 1, 5 do
        local res = Act('tagBody', { net = net })
        if res.ok or not res.retry then return end
        Wait(300)
    end
end

-- still the same posting at the same place (status updates replace the table)
local function samePosting(a, b)
    return a ~= nil and b ~= nil and a.id == b.id and #(a.pickupVec - b.pickupVec) <= 2.0
end

-- spawns one body near the pickup; false when the spot was refused
local function spawnBody(posting, slot)
    local off = CC.offsets[((slot - 1) % #CC.offsets) + 1]
    local x, y = posting.pickupVec.x + off[1], posting.pickupVec.y + off[2]
    local z, normal = findGround(x, y, posting.pickupVec.z)
    if not z then return false end
    if GetInteriorAtCoords(x, y, z) ~= 0 then return false end
    if normal and normal.z < CC.maxSlope then return false end

    local hash = LoadModel(posting.model)
    if not hash then return true end -- a bad model is not the spot's fault
    if not samePosting(Contract.posting, posting) then return true end
    local ped = CreatePed(hash, x, y, z, math.random() * 360.0, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return true end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- random outfit
    PlaceEntityOnGroundProperly(ped, false)
    SetEntityAsMissionEntity(ped, true, true)
    Wait(250)
    if IsEntityInWater(ped) then
        DeleteObj(ped)
        return false
    end
    SetEntityHealth(ped, 0, 0)
    pcall(function() ApplyDamageToPed(ped, 500, false, -1, 0) end)
    SetEntityInvincible(ped, true)
    Contract.bodies[#Contract.bodies + 1] = ped
    tagBody(ped)
    return true
end

CreateThread(function()
    while true do
        local posting = Contract.posting
        if not posting then
            if #Contract.bodies > 0 then deleteBodies(true) end
            if Contract.markerAt then removeMarker() end
            Wait(1500)
        else
            local pos = GetEntityCoords(PlayerPedId())
            local dist = #(pos - posting.pickupVec)
            local alive = existingBodies()

            if not Contract.markerAt and not Contract.cleared then
                placeMarker(posting.pickupVec)
            end

            if dist <= CC.spawnRange and alive < posting.bodies then
                local slot = alive
                for _ = alive + 1, posting.bodies do
                    slot = slot + 1
                    if not samePosting(Contract.posting, posting) then break end
                    if not spawnBody(posting, slot) then
                        askRespot()
                        break
                    end
                end
            end

            if not posting.arrived and dist <= CC.arriveClient and not Contract.arriving then
                Contract.arriving = true
                local res = Act('arrive', {})
                if res.ok and res.posting then
                    Say(res)
                    Contract.Set(res.posting)
                    RefreshStatus()
                end
                SetTimeout(3000, function() Contract.arriving = false end)
            end

            if posting.arrived and existingBodies() == 0 and dist > CC.clearMarkerBeyond and Contract.markerAt then
                removeMarker()
                Contract.cleared = true
            end
            Wait(500)
        end
    end
end)
