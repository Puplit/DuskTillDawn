-- huntingbirds | the bird that is out: calling, following, landing, shoulder, trips, talk, camera

Bird = {
    ped = nil,
    data = nil,      -- { id, model, preset, name, xp } as sent by the server
    state = 'none',  -- none | calling | takeoff | following | landing | shoulder | hunting | home | selling
    carry = nil,     -- catch ped hanging from the bird
    trip = nil,      -- reply of the server when a trip started
    returning = false,
    lastTripAt = nil,
    lastTalk = 0,
    cam = nil,
    nearCarcass = false,
    salePrice = nil,
    cancelTrip = false,
    gen = 0,         -- bumped on every reset so old threads stop
}

local N <const> = {
    flyCircle = 0x72997893BFB8ECCC,
    flyToCoord = 0xD6CFC2D59DA72042,
    flyAway = 0xE86A537B5A3C297C,
    catchSetup = 0x1CE875505D45338A,
    stopAmbient = 0xB8BEC0CA6F0EDB0F,
    stopSpeech = 0x79D2F0E66F81D90D,
    speechAt = 0xED640017ED337E45,
}

function Bird.isOut()
    return Bird.state ~= 'none'
end

-------------------------------------------------------------------------------- camera
function Bird.camOff()
    if not Bird.cam then return end
    RenderScriptCams(false, true, 500, true, true, 0)
    DestroyCam(Bird.cam, false)
    Bird.cam = nil
    LocalPlayer.state:set('pup_cam_owned', false, false)
end

function Bird.camToggle()
    if Bird.cam then Bird.camOff() return end
    local ped = Bird.ped
    if not ped or not Cl.exists(ped) then return end
    local c = GetEntityCoords(ped)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, c.x, c.y, c.z)
    ShakeCam(cam, 'DRUNK_SHAKE', 0.1)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1000, true, true, 0)
    AttachCamToEntity(cam, ped, 0.0, 0.0, 0.0, true)
    Bird.cam = cam
    LocalPlayer.state:set('pup_cam_owned', true, false)
end

-------------------------------------------------------------------------------- reset
local function dropCarry()
    local c = Bird.carry
    Bird.carry = nil
    if c and Cl.exists(c) then
        DetachEntity(c, true, true)
        FreezeEntityPosition(c, false)
        SetEntityHealth(c, 0, 0)
        SetEntityAsNoLongerNeeded(c)
    end
end

-- forget everything about the bird; tellServer also clears the server's record
function Bird.reset(tellServer)
    Bird.gen = Bird.gen + 1
    Bird.camOff()
    dropCarry()
    Cl.deleteEntity(Bird.ped)
    Bird.ped, Bird.data, Bird.state = nil, nil, 'none'
    Bird.trip, Bird.returning, Bird.salePrice, Bird.cancelTrip, Bird.nearCarcass = nil, false, nil, false, false
    if tellServer then TriggerServerEvent('huntingbirds:birdhome') end
end

-------------------------------------------------------------------------------- spawn
local function prepare(ped)
    Cl.blockEvents(ped)
    SetEntityInvincible(ped, true)
    SetEntityNoCollisionEntity(ped, PlayerPedId(), false)
end

-- the bird appears ahead of the player, up in the air, facing back toward them
local function spawnBird(height)
    local player = PlayerPedId()
    local at = GetOffsetFromEntityInWorldCoords(player, 0.0, 70.0, height)
    local ped = Cl.spawnPed(Bird.data.model, at, GetEntityHeading(player) + 180.0, true)
    if not ped then return nil end
    Cl.dress(ped, Bird.data.preset)
    prepare(ped)
    return ped
end

function Bird.callOut(birdId)
    Bird.state = 'calling'
    local gen = Bird.gen
    TriggerServerEvent('huntingbirds:callbird', birdId)
    SetTimeout(10000, function()
        if Bird.gen == gen and Bird.state == 'calling' and not Bird.ped then Bird.reset(false) end
    end)
end

RegisterNetEvent('huntingbirds:spawnbird', function(data)
    if type(data) ~= 'table' or Bird.state ~= 'calling' then
        TriggerServerEvent('huntingbirds:birdhome')
        return
    end
    Bird.data = { id = data.id, model = Util.u32(data.model), preset = data.preset or 0, name = tostring(data.name or '?'), xp = tonumber(data.xp) or 0 }
    local ped = spawnBird(20.0)
    if not ped then
        Bird.reset(true)
        Cl.toast(Locale.birdFailed, 'red')
        return
    end
    Bird.ped = ped
    FreezeEntityPosition(ped, true)
    Wait(500)
    Bird.follow()
end)

RegisterNetEvent('huntingbirds:xpupdate', function(birdId, xp)
    if Bird.data and Bird.data.id == birdId then Bird.data.xp = tonumber(xp) or Bird.data.xp end
end)

-------------------------------------------------------------------------------- follow
function Bird.follow()
    local ped = Bird.ped
    if not ped or not Cl.exists(ped) then return end
    local gen = Bird.gen
    Bird.state = 'takeoff'
    FreezeEntityPosition(ped, false)
    SetEntityNoCollisionEntity(ped, PlayerPedId(), false)
    if Cl.is(IsEntityAttached(ped)) then DetachEntity(ped, true, true) end
    Citizen.InvokeNative(N.flyAway, ped, PlayerPedId())
    Wait(2000)
    if Bird.gen ~= gen or Bird.state ~= 'takeoff' or not Cl.exists(ped) then return end
    Bird.state = 'following'
    local c = GetEntityCoords(ped)
    Citizen.InvokeNative(N.flyCircle, ped, c.x, c.y, c.z, 4.0, 3.1, 4.1)
end

-- keep circling over the player
CreateThread(function()
    while true do
        Wait(2000)
        local ped = Bird.ped
        if Bird.state == 'following' and ped and Cl.exists(ped) and not Cl.isFrozen(ped) then
            local p = GetEntityCoords(PlayerPedId())
            local b = GetEntityCoords(ped)
            Citizen.InvokeNative(N.flyCircle, ped, p.x, p.y, b.z, 4.0, 3.1, 4.1)
        end
    end
end)

-------------------------------------------------------------------------------- landing
local function attachToShoulder(ped, player)
    local entry = Config.ShoulderOffsets[Bird.data.model] or Config.ShoulderDefault
    if not entry then return end
    local side = Cl.is(IsPedMale(player)) and entry.male or entry.female
    AttachEntityToEntity(ped, player, side.bone, side.offset.x, side.offset.y, side.offset.z,
        side.rotation.x, side.rotation.y, side.rotation.z, false, false, false, false, 2, true, false, false)
end

function Bird.land()
    local ped, player = Bird.ped, PlayerPedId()
    if not ped or not Cl.exists(ped) then return end
    if Cl.isHogtied(player) then
        ClearPedTasks(player)
        return
    end
    local gen = Bird.gen
    Bird.state = 'landing'
    TaskStandStill(player, -1)
    if not Bird.returning then Cl.toast(Locale.waitBird, 'gold') end

    ClearPedTasks(ped)
    local target = GetEntityCoords(player) + vector3(0.0, 0.0, 0.5)
    Citizen.InvokeNative(N.flyToCoord, ped, 1.0, target.x, target.y, target.z, true, false)

    local deadline = GetGameTimer() + 20000
    while GetGameTimer() < deadline do
        Wait(500)
        if Bird.gen ~= gen or Bird.state ~= 'landing' or not Cl.exists(ped) then return end
        local b = GetEntityCoords(ped)
        if #(b - target) < 5.0 then
            local now = GetEntityCoords(player) + vector3(0.0, 0.0, 0.5)
            if #(now - target) > 1.2 then
                target = now
                Citizen.InvokeNative(N.flyToCoord, ped, 1.0, target.x, target.y, target.z, true, false)
            end
            if #(b - target) < 1.5 then break end
        end
    end
    if Bird.gen ~= gen or Bird.state ~= 'landing' then return end

    if Bird.returning then
        Bird.returning = false
        local trip = Bird.trip
        Bird.trip = nil
        dropCarry()
        if trip then
            TriggerServerEvent('huntingbirds:addxp', trip.birdId)
            if trip.role == 'scavenging' then TriggerServerEvent('huntingbirds:addscavengeditem', trip.birdId) end
        end
    end
    Bird.camOff()
    attachToShoulder(ped, player)
    ClearPedTasksImmediately(ped)
    Cl.blockEvents(ped)
    FreezeEntityPosition(ped, true)
    ClearPedTasks(player)
    Bird.state = 'shoulder'
end

-------------------------------------------------------------------------------- send home
function Bird.sendHome(byDeath)
    if Bird.state == 'none' or Bird.state == 'home' then return end
    if Bird.state == 'hunting' then
        Bird.cancelTrip = true
        return
    end
    local ped, player = Bird.ped, PlayerPedId()
    local wasStill = Bird.state == 'landing' or Bird.state == 'selling'
    if Bird.state == 'selling' and Bird.data then TriggerServerEvent('huntingbirds:sell:stop', Bird.data.id) end
    Bird.state = 'home'
    local gen = Bird.gen
    Cl.toast(Locale.goingHome, 'gold')
    dropCarry()
    if ped and Cl.exists(ped) then
        if Cl.is(IsEntityAttached(ped)) then DetachEntity(ped, true, true) end
        FreezeEntityPosition(ped, false)
        SetEntityNoCollisionEntity(ped, player, false)
        Citizen.InvokeNative(N.flyAway, ped, player)
    end
    if wasStill then ClearPedTasks(player) end
    Bird.trip, Bird.returning = nil, false
    CreateThread(function()
        Wait(byDeath and 500 or 7000)
        if Bird.gen ~= gen then return end
        Bird.reset(true)
    end)
end

-------------------------------------------------------------------------------- trips
function Bird.askHunt()
    local cd = tonumber(Config.Hunting.cooldownMs) or 0
    if Bird.lastTripAt and GetGameTimer() - Bird.lastTripAt < cd then
        Cl.toast(Locale.huntCooldown:format(Cl.formatWait(cd - (GetGameTimer() - Bird.lastTripAt))), 'red')
        return
    end
    TriggerServerEvent('huntingbirds:checkhunt', Cl.zoneHash())
end

-- wait whole seconds; false when the player died or the trip was called off
local function tripWait(seconds, gen)
    for _ = 1, math.max(0, math.floor(seconds)) do
        Wait(1000)
        if Bird.gen ~= gen or Bird.cancelTrip or Cl.isDead() then return false end
    end
    return Bird.gen == gen and not Bird.cancelTrip
end

RegisterNetEvent('huntingbirds:starthunt', function(trip)
    if type(trip) ~= 'table' or Bird.state ~= 'shoulder' or not Bird.data or trip.birdId ~= Bird.data.id then return end
    local ped, player = Bird.ped, PlayerPedId()
    Bird.lastTripAt = GetGameTimer()
    Bird.trip = trip
    Bird.state = 'hunting'
    Bird.cancelTrip = false
    local gen = Bird.gen
    Cl.toast(Locale.goingHunt:format(tostring(trip.zoneLabel or '?')), 'gold')
    Bird.camOff()
    if ped and Cl.exists(ped) then
        if Cl.is(IsEntityAttached(ped)) then DetachEntity(ped, true, true) end
        FreezeEntityPosition(ped, false)
        SetEntityNoCollisionEntity(ped, player, false)
        Citizen.InvokeNative(N.flyAway, ped, player)
    end

    local ok = tripWait(Config.Hunting.flyAwaySeconds or 20, gen)
    if Bird.gen ~= gen then return end
    Cl.deleteEntity(Bird.ped)
    Bird.ped = nil
    ok = ok and tripWait(Config.Hunting.huntSeconds or 60, gen)
    if Bird.gen ~= gen then return end
    if not ok then
        Bird.reset(true)
        return
    end

    local back = spawnBird(40.0)
    if not back then
        Bird.reset(true)
        Cl.toast(Locale.birdFailed, 'red')
        return
    end
    Bird.ped = back
    if trip.catchModel then
        local catch = Cl.spawnPed(trip.catchModel, GetEntityCoords(back), 0.0, true)
        if catch then
            Cl.dress(catch, trip.catchPreset or 0)
            Citizen.InvokeNative(N.catchSetup, catch, 0, 0)
            FreezeEntityPosition(catch, true)
            AttachEntityToEntity(catch, back, 7, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true, false, false)
            FreezeEntityPosition(catch, false)
            Bird.carry = catch
        end
    end
    Bird.returning = true
    Bird.state = 'following'
    Bird.land()
end)

-------------------------------------------------------------------------------- talk
local function speak(ped)
    local banks = Config.ParrotSpeech
    if #banks == 0 or type(DataView) ~= 'table' then return end
    local bank = banks[math.random(#banks)]
    local line = bank.lines[math.random(#bank.lines)]
    Citizen.InvokeNative(N.stopAmbient, ped)
    Citizen.InvokeNative(N.stopSpeech, ped)
    -- the struct holds pointers to the two strings, so ask for the var string as a number
    local linePtr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', line, Citizen.ResultAsLong())
    local bankPtr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', bank.bank, Citizen.ResultAsLong())
    if type(linePtr) ~= 'number' or type(bankPtr) ~= 'number' then return end
    local struct = DataView.ArrayBuffer(128)
    struct:SetInt64(0, linePtr)
    struct:SetInt64(8, bankPtr)
    struct:SetInt32(16, 1)
    struct:SetInt64(24, 291934926)
    struct:SetInt32(32, 0)
    struct:SetInt32(40, 1)
    struct:SetInt32(48, 1)
    struct:SetInt32(56, 1)
    local c = GetEntityCoords(ped)
    Citizen.InvokeNative(N.speechAt, c.x, c.y, c.z, struct:Buffer())
end

AddEventHandler('huntingbirds:checktalk', function()
    local ped = Bird.ped
    if not ped or not Cl.exists(ped) or not Bird.data then return end
    if (Bird.data.xp or 0) < (tonumber(Config.Talking.xpRequired) or 0) then
        Cl.toast(Locale.noTalkSkill, 'red')
        return
    end
    if not Config.TalkModels[Bird.data.model] then
        Cl.toast(Locale.notTalker, 'red')
        return
    end
    if GetGameTimer() - Bird.lastTalk < 1000 then
        Cl.toast(Locale.waitTalk, 'red')
        return
    end
    Bird.lastTalk = GetGameTimer()
    speak(ped)
end)

-------------------------------------------------------------------------------- watchers
-- leave the shoulder when the player climbs, falls, swims or is tied; send home on death
CreateThread(function()
    while true do
        Wait(500)
        if Bird.ped and Bird.state ~= 'none' and Bird.state ~= 'home' and Bird.state ~= 'hunting' then
            local player = PlayerPedId()
            if Cl.isDead(player) then
                Bird.sendHome(true)
            elseif Bird.state == 'shoulder' and Cl.mustLeaveShoulder(player) then
                CreateThread(Bird.follow)
            end
        end
    end
end)

-- vorp_admin world cleanup deleted a flying bird: count it as gone home so it can be called again.
-- A bird on the shoulder is attached to the player and is kept; one away on a trip has no ped.
RegisterNetEvent('vorp_admin:worldCleanupDone', function()
    if Bird.state == 'none' or Bird.state == 'calling' or Bird.state == 'hunting' then return end
    if Bird.ped and Cl.exists(Bird.ped) then return end
    Bird.reset(true)
end)

-- hide the bird's prompts while the player stands at a carcass, so loot and skin prompts win
CreateThread(function()
    local nearby, tick = {}, 0
    while true do
        if not Bird.ped then
            Bird.nearCarcass, nearby = false, {}
            Wait(500)
        else
            Wait(100)
            local player = PlayerPedId()
            local pc = GetEntityCoords(player)
            tick = tick + 1
            if tick >= 5 then
                tick = 0
                nearby = {}
                for _, e in ipairs(GetGamePool('CPed')) do
                    if e ~= player and e ~= Bird.ped and #(GetEntityCoords(e) - pc) <= 2.0 then nearby[#nearby + 1] = e end
                end
            end
            local near = false
            if Cl.is(IsPedOnFoot(player)) then
                for _, e in ipairs(nearby) do
                    if Cl.exists(e) and Cl.is(IsEntityDead(e)) and not Cl.isHorseModel(GetEntityModel(e))
                        and #(GetEntityCoords(e) - pc) <= 1.5 then
                        near = true
                        break
                    end
                end
            end
            Bird.nearCarcass = near
        end
    end
end)
