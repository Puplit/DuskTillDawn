-- pup-misc / police - rank-driven badge props (the grade comes from pup-mdt, grades 0-12)

local function keyHash(k)
    if type(k) == 'number' then return k end
    return joaat(tostring(k))
end

local K = {}
for name, value in pairs(PoliceConfig.Keys) do K[name] = keyHash(value) end

-- IS_CONTROL_JUST_PRESSED is the ENABLED-only variant: a control disabled this frame reads false from it
local function justPressed(key)
    local h = keyHash(key)
    if Citizen.InvokeNative(0x580417101DDB492F, 0, h) then return true end
    if IsDisabledControlJustPressed(0, h) then return true end
    return false
end

local function keyHeld(key)
    local h = keyHash(key)
    return IsControlPressed(0, h) or IsDisabledControlPressed(0, h)
end

-- STATE

local function defaultOffset()
    local d = PoliceConfig.Badges.default
    return { bone = d.bone, x = d.x, y = d.y, z = d.z, pitch = d.pitch, roll = d.roll, yaw = d.yaw }
end

local badge = {
    visible = false,
    prop    = nil,     -- model name of the badge currently pinned on
    object  = nil,     -- the attached entity
    rank    = nil,     -- rank name, for the toast
    offset  = defaultOffset(),
}

local editing = false

-- PROP BADGE

local function loadModel(model)
    local hash = GetHashKey(model)
    if not IsModelValid(hash) then return false end
    if HasModelLoaded(hash) then return true end
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 3000 do
        Citizen.Wait(50)
        waited = waited + 50
    end
    return HasModelLoaded(hash)
end

function CreateBadge(model)
    if not loadModel(model) then
        print(('[pup-misc/police] badge model "%s" would not load'):format(tostring(model)))
        return nil
    end
    local coords = GetEntityCoords(PlayerPedId())
    local object = CreateObjectNoOffset(GetHashKey(model), coords.x, coords.y, coords.z, true, true, false)
    Citizen.InvokeNative(0xE0580EC84813875A, object, false, true) -- disable collision
    SetModelAsNoLongerNeeded(GetHashKey(model))
    return object
end

function AttachBadge(object, ped)
    if not object or not DoesEntityExist(object) then return end
    local o = badge.offset
    local bone = GetEntityBoneIndexByName(ped, o.bone or PoliceConfig.Badges.default.bone)
    if bone == -1 then bone = GetEntityBoneIndexByName(ped, PoliceConfig.Badges.default.bone) end
    AttachEntityToEntity(object, ped, bone, o.x, o.y, o.z, o.pitch, o.roll, o.yaw, false, true, false, true, 1, true)
end

RegisterNetEvent('pup:cleanupobjectClient')
AddEventHandler('pup:cleanupobjectClient', function(network)
    if badge.object and NetworkGetNetworkIdFromEntity(badge.object) == network then
        DeleteObject(badge.object)
        badge.object = nil
    end
end)

-- Re-attach if the object is culled or the ped is swapped (respawn, disguise).
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if badge.visible then
            local ped = PlayerPedId()
            if not DoesEntityExist(badge.object) or GetEntityAttachedTo(badge.object) ~= ped then
                if DoesEntityExist(badge.object) then DeleteEntity(badge.object) end
                badge.object = CreateBadge(badge.prop)
                AttachBadge(badge.object, ped)
            end
        end
    end
end)

-- EQUIP / REMOVE

function removebadge()
    if badge.object and DoesEntityExist(badge.object) then
        DeleteEntity(badge.object)
    end
    badge.object  = nil
    badge.visible = false
    badge.prop    = nil
end

function IsBadgeOn()
    return badge.visible
end

function GetBadgeRank()
    return badge.rank
end

-- Look the grade up in PoliceConfig.Badges.ranks
function BadgeSpecFor(job, grade)
    -- a law job with no table of its own falls back rather than returning nil
    local byJob = PoliceConfig.Badges.ranks[job]
    if not byJob then return PoliceConfig.Badges.fallback end
    return byJob[tonumber(grade) or -1] or PoliceConfig.Badges.fallback
end

function EquipBadgeByGrade(job, grade, rankName)
    if not job then
        TriggerEvent("vorp:TipRight", PoliceLocale.badgeNotOnDuty, 2000)
        return
    end

    if badge.visible then
        removebadge()
        TriggerEvent("vorp:TipRight", PoliceLocale.badgeRemoved, 2000)
        return
    end

    local spec = BadgeSpecFor(job, grade)
    if not spec then
        TriggerEvent("vorp:TipRight", PoliceLocale.noBadge, 3000)
        return
    end

    badge.rank = rankName or spec.rank or PoliceLocale.defaultRank

    local prop = spec.prop or PoliceConfig.Badges.fallback.prop
    badge.object = CreateBadge(prop)
    if not badge.object then
        TriggerEvent("vorp:TipRight", PoliceLocale.badgeLoadFailed, 3000)
        return
    end
    badge.prop    = prop
    badge.visible = true
    AttachBadge(badge.object, PlayerPedId())

    TriggerEvent("vorp:TipRight", (PoliceLocale.badgePinned):format(badge.rank), 3000)
end

-- ============================================================================
-- PERSISTENCE (per character, in the database - see server/police/main.lua)
-- ============================================================================

function SaveBadgeOffset()
    TriggerServerEvent('pup-misc:police:badge:saveBadgeOffset', json.encode(badge.offset))
end

function LoadBadgeOffset()
    TriggerServerEvent('pup-misc:police:badge:loadBadgeOffset')
end

RegisterNetEvent('pup-misc:police:badge:setBadgeOffset')
AddEventHandler('pup-misc:police:badge:setBadgeOffset', function(offsetJson)
    if not offsetJson then return end
    local ok, decoded = pcall(json.decode, offsetJson)
    if not ok or type(decoded) ~= 'table' then return end

    local d = defaultOffset()
    badge.offset = {
        bone  = decoded.bone or d.bone,
        x     = tonumber(decoded.x)     or d.x,
        y     = tonumber(decoded.y)     or d.y,
        z     = tonumber(decoded.z)     or d.z,
        pitch = tonumber(decoded.pitch) or d.pitch,
        roll  = tonumber(decoded.roll)  or d.roll,
        yaw   = tonumber(decoded.yaw)   or d.yaw,
    }
    if badge.visible then
        AttachBadge(badge.object, PlayerPedId())
    end
end)

-- Pull the saved position as soon as the character is picked
RegisterNetEvent('vorp:SelectedCharacter')
AddEventHandler('vorp:SelectedCharacter', function()
    Citizen.SetTimeout(2000, LoadBadgeOffset)
end)

-- THE EDITOR - the pup-ui in-world panel, same as placing a scene

local MODE_MOVE, MODE_ROTATE, MODE_BONE = 1, 2, 3
local MODE_NAME = { [MODE_MOVE] = PoliceLocale.modeMove, [MODE_ROTATE] = PoliceLocale.modeRotate, [MODE_BONE] = PoliceLocale.modeBone }

local function boneIndexOf(name)
    for i, b in ipairs(PoliceConfig.Badges.editor.bones) do
        if b.bone == name then return i end
    end
    return 1
end

local function boneLabel()
    return PoliceConfig.Badges.editor.bones[boneIndexOf(badge.offset.bone)].label
end

local function step(base)
    return keyHeld(K.editorFine) and (base * PoliceConfig.Badges.editor.fineFactor) or base
end

local function nudge(axis, amount)
    badge.offset[axis] = (badge.offset[axis] or 0.0) + amount
    AttachBadge(badge.object, PlayerPedId())
end

local function drawEditor(mode)
    local o = badge.offset
    exports['pup-ui']:DrawHudPanel({
        title = ("[ %s ]   %s"):format(MODE_NAME[mode], (
            mode == MODE_MOVE   and PoliceLocale.hintMove or
            mode == MODE_ROTATE and PoliceLocale.hintRotate or
                                    PoliceLocale.hintBone)),
        rows = {
            { label = PoliceLocale.rowRank, value = tostring(badge.rank or PoliceLocale.defaultRank) },
            { label = PoliceLocale.rowBone, value = boneLabel(), selected = (mode == MODE_BONE) },
            "",
            { text = ("X %.3f    Y %.3f    Z %.3f"):format(o.x, o.y, o.z),
              selected = (mode == MODE_MOVE) },
            { text = ("PITCH %.1f    ROLL %.1f    YAW %.1f"):format(o.pitch, o.roll, o.yaw),
              selected = (mode == MODE_ROTATE) },
            "",
            { text = PoliceLocale.fineHint },
        },
        footer = PoliceLocale.editorFooter,
    })
end

function OpenBadgeAdjustmentMenu()
    if editing then return end
    if GetResourceState('pup-ui') ~= 'started' then
        TriggerEvent("vorp:TipRight", PoliceLocale.editorUnavailable, 3000)
        return
    end

    if not badge.visible then
        TriggerEvent("vorp:TipRight", PoliceLocale.pinFirst, 3000)
        return
    end
    editing = true
    local mode = MODE_MOVE
    local revert = {}
    for k, v in pairs(badge.offset) do revert[k] = v end

    Citizen.CreateThread(function()
        -- skip the frame that opened us, or the same keypress lands twice
        Citizen.Wait(0)
        while editing do
            Citizen.Wait(0)
            drawEditor(mode)

            -- the height keys may be bound to weapon slots; suppress only those
            DisableControlAction(0, K.editorRaise, true)
            DisableControlAction(0, K.editorLower, true)

            if justPressed(K.editorMode) then
                mode = mode + 1
                if mode > MODE_BONE then mode = MODE_MOVE end
            end

            if mode == MODE_MOVE then
                local m = step(PoliceConfig.Badges.editor.moveStep)
                if justPressed(K.editorLeft)  then nudge('x', -m) end
                if justPressed(K.editorRight) then nudge('x',  m) end
                if justPressed(K.editorUp)    then nudge('y',  m) end
                if justPressed(K.editorDown)  then nudge('y', -m) end
                if justPressed(K.editorRaise)     then nudge('z',  m) end
                if justPressed(K.editorLower)     then nudge('z', -m) end

            elseif mode == MODE_ROTATE then
                local r = step(PoliceConfig.Badges.editor.rotateStep)
                if justPressed(K.editorLeft)  then nudge('yaw',   -r) end
                if justPressed(K.editorRight) then nudge('yaw',    r) end
                if justPressed(K.editorUp)    then nudge('pitch', -r) end
                if justPressed(K.editorDown)  then nudge('pitch',  r) end
                if justPressed(K.editorRaise)     then nudge('roll',   r) end
                if justPressed(K.editorLower)     then nudge('roll',  -r) end

            else
                local dir = 0
                if justPressed(K.editorRight) then dir = 1 elseif justPressed(K.editorLeft) then dir = -1 end
                if dir ~= 0 then
                    local bones = PoliceConfig.Badges.editor.bones
                    local i = boneIndexOf(badge.offset.bone) + dir
                    if i < 1 then i = #bones elseif i > #bones then i = 1 end
                    badge.offset.bone = bones[i].bone
                    AttachBadge(badge.object, PlayerPedId())
                end
            end

            if justPressed(K.editorReset) then
                badge.offset = defaultOffset()
                AttachBadge(badge.object, PlayerPedId())
                TriggerEvent("vorp:TipRight", PoliceLocale.badgeReset, 1500)
            end

            if justPressed(K.editorSave) then
                editing = false
                SaveBadgeOffset()
                TriggerEvent("vorp:TipRight", PoliceLocale.badgeSaved, 2500)
            elseif justPressed(K.editorCancel) then
                editing = false
                badge.offset = revert
                AttachBadge(badge.object, PlayerPedId())
                TriggerEvent("vorp:TipRight", PoliceLocale.cancelled, 1500)
            end
        end
    end)
end

function ResetBadgePosition()
    badge.offset = defaultOffset()
    if badge.object then AttachBadge(badge.object, PlayerPedId()) end
end

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    editing = false
    if badge.object and DoesEntityExist(badge.object) then
        DeleteEntity(badge.object)
    end
end)
