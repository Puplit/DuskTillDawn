-- pup-misc / gestures - hands up (X) and point (L)

local handsUp  = false
local pointing = false

local function ped() return PlayerPedId() end

-- client/emotes/main.lua loads first (manifest order) and publishes this
local function canPlay()
    if EmotesCanPlay then return EmotesCanPlay() end
    return false
end

-- a box in both hands beats a gesture - layering one fights the carry anim. storagebox/ is part of pup-misc
local function carryingBox()
    local ok, res = pcall(function() return exports['pup-misc']:IsCarrying() end)
    return ok and res == true
end

-- gestures play here directly, not through EmotesPlayAnim
local function playGesture(entry)
    if not entry or not entry.dict or not entry.name then return false end

    RequestAnimDict(entry.dict)
    local waited = 0
    while not HasAnimDictLoaded(entry.dict) and waited < 3000 do
        Wait(10)
        waited = waited + 10
    end
    if not HasAnimDictLoaded(entry.dict) then
        print(('^3[pup-misc/gestures]^7 anim dict failed to load: %s'):format(entry.dict))
        return false
    end

    -- re-checked: the player can be shot or hogtied during the load
    if not canPlay() then
        RemoveAnimDict(entry.dict)
        return false
    end

    TaskPlayAnim(ped(), entry.dict, entry.name,
        entry.blend or 1.0, -1.0, -1, entry.flag or 31, 0, false, false, false)
    RemoveAnimDict(entry.dict)
    return true
end

-- Secondary task only - see above. ClearPedTasks would stop the player dead.
-- a consume on the same slot may already have replaced the pose: drop the flag, leave the task alone
local function clearAnim()
    if EmotesConsuming and EmotesConsuming() then return end
    ClearPedSecondaryTask(ped())
end

-- ------------------------------------------------------------------ hands up
local function stopHandsUp()
    if not handsUp then return end
    handsUp = false
    clearAnim()
    if GesturesConfig.HandsUp.blockFiring then
        DisablePlayerFiring(PlayerId(), false)
    end
end

-- holds the surrender while it is up: firing stays blocked every frame
local function handsUpPoseActive(p)
    local entry = GesturesConfig.HandsUp.anim
    return entry.dict and IsEntityPlayingAnim(p, entry.dict, entry.name, 3) or false
end

local function maintainHandsUp()
    CreateThread(function()
        -- playGesture requests the dict and can spend a few frames waiting on it
        local GRACE_MS = 1000
        local started = GetGameTimer()
        local nextPoseCheck = started + GRACE_MS

        while handsUp do
            local p = ped()

            if not canPlay() then
                stopHandsUp()
                break
            end

            -- per-frame, because DisablePlayerFiring is a per-frame call and not a latch
            if GesturesConfig.HandsUp.blockFiring then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 0xB2F377E8, true) -- Attack
                DisableControlAction(0, 0xCEFD9220, true) -- Attack2
                DisableControlAction(0, 0x07CE1E61, true) -- MeleeAttack1
                DisableControlAction(0, 0x1E7D7275, true) -- MeleeModifier
            end

            -- the pose check is cheap but not free, and nothing about it needs to happen 60 times a second
            local now = GetGameTimer()
            if now >= nextPoseCheck then
                nextPoseCheck = now + 250
                if not handsUpPoseActive(p) then
                    -- something else (/sa, a knockout, another script) took the pose off us; the flag would otherwise stay true forever
                    stopHandsUp()
                    break
                end
            end

            Wait(0)
        end
    end)
end

local function toggleHandsUp()
    if handsUp then
        stopHandsUp()
        return
    end
    if not canPlay() or carryingBox() then return end

    if pointing then pointing = false end -- one gesture at a time

    if GesturesConfig.HandsUp.holsterWeapon then
        SetCurrentPedWeapon(ped(), GetHashKey('WEAPON_UNARMED'), true)
    end

    -- only claim the state if the pose actually went on
    if not playGesture(GesturesConfig.HandsUp.anim) then return end

    handsUp = true
    maintainHandsUp()
end

-- ------------------------------------------------------------------ point
local function togglePoint()
    if pointing then
        pointing = false
        clearAnim()
        return
    end
    if not canPlay() or carryingBox() then return end

    if handsUp then stopHandsUp() end -- one gesture at a time

    if not playGesture(GesturesConfig.Point.anim) then return end
    pointing = true
end

-- ------------------------------------------------------------------ binds
local function bind(command, label, defaultKey, handler)
    -- a blank/missing command name would register a bind that nothing answers, and the row would sit in Settings doing nothing
    if type(command) ~= 'string' or command == '' then
        print('^3[pup-misc/gestures]^7 skipped a keybind: command name missing in config/gestures/main.lua')
        return
    end

    -- keymapping commands fire even through DisableAllControlActions
    RegisterCommand(command, function(...)
        if IsNuiFocused() then return end
        handler(...)
    end, false)
    -- '' default = the row still appears, unbound, for the player to assign
    RegisterKeyMapping(command, label or command, 'keyboard', defaultKey or '')
end

bind(GesturesConfig.General.handsUpCommand, GesturesLocale.handsUpBind or 'Hands up',
    GesturesConfig.Keys.handsUp, function() toggleHandsUp() end)

bind(GesturesConfig.General.pointCommand, GesturesLocale.pointBind or 'Point',
    GesturesConfig.Keys.point, function() togglePoint() end)

-- ------------------------------------------------------------------ cleanup
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if handsUp then stopHandsUp() end
    if pointing then clearAnim() end
end)
