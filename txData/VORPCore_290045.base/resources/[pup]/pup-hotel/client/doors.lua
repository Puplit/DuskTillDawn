-- Room doors: locked unless the server says otherwise.

local Core <const> = exports.vorp_core:GetCore()
local D <const> = function() return Config.Doors or {} end

local openDoors = {}   -- ['hotel:room'] = true when unlocked
local myAccess = {}    -- ['hotel:room'] = true when this player may work it
local doors = {}       -- flattened: { hotel, room, label, hash, coords }

local function key(hotelId, roomId) return ('%s:%s'):format(hotelId, roomId) end

-- close, then lock: a locked door refuses to move
local function applyDoor(hash, open)
    Citizen.InvokeNative(0xD99229FE93B46286, hash, true, true, false, 0, 0, false) -- AddDoorToSystem
    if open then
        Citizen.InvokeNative(0x6BAB9442830C7F53, hash, 0) -- unlocked
    else
        DoorSystemSetOpenRatio(hash, 0.0, false, false)
        Citizen.InvokeNative(0x6BAB9442830C7F53, hash, 1) -- locked
    end
end

--- `door` is the MLO name or the raw hash /hoteldoor reports.
function HotelDoorHash(door)
    if door == nil then return nil end
    return tonumber(door) or GetHashKey(tostring(door))
end

function buildDoors()
    doors = {}
    for hotelId, hotel in pairs(Config.Hotels or {}) do
        for _, room in ipairs(hotel.rooms or {}) do
            if room.door and room.coords then
                doors[#doors + 1] = {
                    hotel = hotelId,
                    room = room.id,
                    label = room.label or room.id,
                    hash = HotelDoorHash(room.door),
                    coords = room.coords,
                }
            end
        end
    end
end

local function refreshAccess(done)
    Core.Callback.TriggerAsync('pup-hotel:myAccess', function(list)
        myAccess = {}
        for _, k in ipairs(list or {}) do myAccess[k] = true end
        if done then done() end
    end)
end

RegisterNetEvent('pup-hotel:doorState', function(hotelId, roomId, open)
    local k <const> = key(hotelId, roomId)
    openDoors[k] = open or nil
    for _, d in ipairs(doors) do
        if d.hotel == hotelId and d.room == roomId then applyDoor(d.hash, open) end
    end
end)

RegisterNetEvent('pup-hotel:doorsAll', function(list)
    openDoors = {}
    for _, k in ipairs(list or {}) do openDoors[k] = true end
    for _, d in ipairs(doors) do applyDoor(d.hash, openDoors[key(d.hotel, d.room)] == true) end
end)

RegisterNetEvent('pup-hotel:refresh', function() refreshAccess() end)

-- /hotelroom added one, no reconnect needed
RegisterNetEvent('pup-hotel:addRoom', function(hotelId, room)
    HotelAddRoom(hotelId, room)
    buildDoors()
    refreshAccess()
end)

-- ------------------------------------------------------------------ prompt

local group, prompt
local lastRefused = 0 -- so holding the key does not spam the tip
local working = false -- a door is being worked; ignore the prompt until it is done

-- key anim: doorlocks' LockAnimation
local ANIM_DICT <const> = 'script_common@jail_cell@unlock@key'
local ANIM_CLIP <const> = 'action'
local KEY_MODEL <const> = `P_KEY02X`

local function loadDict(dict)
    RequestAnimDict(dict)
    local until_ <const> = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > until_ then return false end
        Wait(50)
    end
    return true
end

--- `done()` fires mid-animation, as the lock turns.
local function keyAnimation(coords, done)
    if working then return end
    working = true
    CreateThread(function()
        local ped = PlayerPedId()
        local prop = nil

        if (Config.Doors or {}).animation ~= false and loadDict(ANIM_DICT) then
            TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, -1)
            Wait(600)

            RequestModel(KEY_MODEL)
            local until_ <const> = GetGameTimer() + 2000
            while not HasModelLoaded(KEY_MODEL) and GetGameTimer() < until_ do Wait(50) end

            TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 8.0, -8.0, 2500, 31, 0, true, false, false)

            if HasModelLoaded(KEY_MODEL) then
                    Wait(750)
                local c <const> = GetEntityCoords(ped)
                prop = CreateObject(KEY_MODEL, c.x, c.y, c.z - 1.0, true, true, true)
                AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_Finger12'),
                    0.02, 0.0120, -0.00850, 0.024, -160.0, 200.0, true, true, false, true, 1, true)
                Wait(900)
            else
                Wait(1650)
            end
        end

        done()

        Wait(600)
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
        ClearPedTasksImmediately(PlayerPedId())
        RemoveAnimDict(ANIM_DICT)
        SetModelAsNoLongerNeeded(KEY_MODEL)
        working = false
    end)
end

local function setupPrompt()
    group = GetRandomIntInRange(0, 0xffffff)
    prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, Config.Keys.door or 0x8FFC75D6)
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', Locale.promptUnlock))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetStandardMode(prompt, true)
    UiPromptSetGroup(prompt, group, 0)
    UiPromptRegisterEnd(prompt)
end

CreateThread(function()
    if D().enabled == false then return end
    buildDoors()
    if #doors == 0 then return end
    setupPrompt()

    Wait(2000)
    TriggerServerEvent('pup-hotel:doorsPlease')
    refreshAccess()

    local range <const> = tonumber(D().promptRadius) or 1.0
    while true do
        local wait = 700
        local me <const> = GetEntityCoords(PlayerPedId())
        local near, nearest = nil, range

        -- closest door, not the first in range
        for i = 1, #doors do
            local d <const> = #(me - doors[i].coords)
            if d < nearest then near, nearest = doors[i], d end
        end

        if near then
            wait = 0
            local k <const> = key(near.hotel, near.room)
            local open <const> = openDoors[k] == true
            local label <const> = myAccess[k]
                and ('%s - %s'):format(near.label, open and Locale.promptLock or Locale.promptUnlock)
                or near.label

            UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', label))
            UiPromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', near.label), 0, 0, 0, 0)

            if not working and UiPromptHasStandardModeCompleted(prompt, 0) then
                local hotel, room, at = near.hotel, near.room, near.coords
                local function openIt()
                    keyAnimation(at, function()
                        TriggerServerEvent('pup-hotel:doorToggle', hotel, room)
                    end)
                end

                if myAccess[k] then
                    openIt()
                elseif GetGameTimer() - lastRefused > 2500 then
                    lastRefused = GetGameTimer()
                    -- myAccess only refreshes on a rental change, so ask again before refusing (a job change does not refresh it)
                    refreshAccess(function()
                        if myAccess[k] then
                            openIt()
                        else
                            TriggerEvent('vorp:TipRight', Locale.notYourRoom, 4000)
                        end
                    end)
                end
            end
        end

        Wait(wait)
    end
end)

-- enforce: lock state is lost when a door streams out

CreateThread(function()
    if D().enabled == false then return end
    while true do
        Wait(math.max(500, tonumber(D().enforceIntervalMs) or 2000))
        if #doors > 0 then
            local me <const> = GetEntityCoords(PlayerPedId())
            local far <const> = tonumber(D().enforceRadius) or 25.0
            for i = 1, #doors do
                local d <const> = doors[i]
                if #(me - d.coords) < far then
                    applyDoor(d.hash, openDoors[key(d.hotel, d.room)] == true)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------- setup aid

local function rotToDir(rot)
    local z <const> = math.rad(rot.z)
    local x <const> = math.rad(rot.x)
    local flat <const> = math.abs(math.cos(x))
    return vector3(-math.sin(z) * flat, math.cos(z) * flat, math.sin(x))
end

--- Names the door under the player's aim.
RegisterNetEvent('pup-hotel:findDoor', function()
    local ped <const> = PlayerPedId()
    local from <const> = GetFinalRenderedCamCoord()
    local to <const> = from + (rotToDir(GetFinalRenderedCamRot(2)) * 12.0)
    local ray <const> = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 511, ped, 4)
    local _, hit, _, _, _, entity = GetShapeTestResultIncludingMaterial(ray)

    if not hit or hit == 0 or not entity or entity == 0 then
        print('^3[pup-hotel]^7 nothing under your aim - stand a step back and look straight at the door')
        return TriggerEvent('vorp:TipRight', Locale.lookAtDoor, 4000)
    end

    local c <const> = GetEntityCoords(entity)
    local model <const> = GetEntityModel(entity)

    local doorHash = nil
    local active <const> = DoorSystemGetActive() or {}
    for i = 1, #active do
        if active[i][2] == entity then doorHash = active[i][1] break end
    end

    print('^2[pup-hotel]^7 door under your aim')
    print(('   model hash   %s'):format(tostring(model)))
    print(('   coords       vector3(%.3f, %.3f, %.3f)'):format(c.x, c.y, c.z))
    if doorHash then
        print(('   DOOR HASH    %s   <- pass this to /hotelroom as the doorName'):format(tostring(doorHash)))
        TriggerEvent('vorp:TipRight', Locale.doorHashFound:format(tostring(doorHash)), 10000)
    else
        print('^3   not in the door system^7 - this door is the MLO\'s own.')
        print('   Use its name from your MLO door list instead, or leave the doorName off')
        print('   and the room will rent but never lock.')
        TriggerEvent('vorp:TipRight', Locale.doorNotRegistered, 8000)
    end
end)

RegisterNetEvent('pup-hotel:printCoords', function()
    local c <const> = GetEntityCoords(PlayerPedId())
    local line <const> = ('vector3(%.3f, %.3f, %.3f)'):format(c.x, c.y, c.z)
    print(('^2[pup-hotel]^7 %s  heading %.2f'):format(line, GetEntityHeading(PlayerPedId())))
    TriggerEvent('vorp:TipRight', line, 10000)

    -- distance to every configured point
    local n = 0
    for id, hotel in pairs(Config.Hotels or {}) do
        n = n + 1
        if hotel.desk then
            print(('   %s desk    %.2fm  (prompt under 2.5)'):format(id, #(c - hotel.desk)))
        end
        if hotel.office then
            print(('   %s office  %.2fm  (prompt under 2.5)'):format(id, #(c - hotel.office)))
        end
        for _, room in ipairs(hotel.rooms or {}) do
            if room.coords then
                print(('   %s %s  %.2fm  (prompt under %.2f)')
                    :format(id, room.id, #(c - room.coords), tonumber((Config.Doors or {}).promptRadius) or 1.0))
            end
        end
    end
    if n == 0 then
        print('^1[pup-hotel]^7 Config.Hotels is EMPTY on this client - nothing is configured')
    end
end)
