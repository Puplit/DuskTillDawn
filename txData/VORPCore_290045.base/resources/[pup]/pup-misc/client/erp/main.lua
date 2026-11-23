-- pup-misc | erp, client half. /erp picks a pose and invites the nearest player;
-- they get a prompt to accept. Nothing plays until the server says both agreed.

local OWNER <const> = 'pup-misc:erp'
local GROUP <const> = GetRandomIntInRange(0, 0xffffff)

local acceptPrompt, declinePrompt
local invite = nil   -- { from, key, label, until_ }
local busy = false
local menuOpen = false
local menuKeys = {}  -- menu row -> emote key, since the list is filtered by zone

local function truthy(v) return v == true or v == 1 end

local function emoteByKey(key)
    for _, e in ipairs(ErpConfig.Emotes or {}) do
        if e.key == key then return e end
    end
end

-- a transformed player (wolf, bear, cat) has no place in a paired human pose,
-- and their form owns the ped scale - leave both alone
local function isHuman()
    local h <const> = IsPedHuman(PlayerPedId())
    return h == true or h == 1
end

-- ZONES. The district native is client only, so this is where that half lives.
-- `emote` may be nil, which asks "is anything at all allowed here"
local function zoneAllowed(emote)
    local z <const> = ErpConfig.Zones or {}
    if z.enforce == false then return true end
    if emote and emote.anywhere then return true end

    local here <const> = GetEntityCoords(PlayerPedId())

    for _, s in ipairs(z.spots or {}) do
        local dx, dy, dz = here.x - s.x, here.y - s.y, here.z - s.z
        local r <const> = tonumber(s.radius) or 20.0
        if (dx * dx + dy * dy + dz * dz) <= (r * r) then return true end
    end

    if #(z.districts or {}) > 0 then
        local area <const> = Citizen.InvokeNative(0x43AD8FC02B429D33, here.x, here.y, here.z, 10)
        for _, d in ipairs(z.districts) do
            if area == d then return true end
        end
    end

    return false
end

local function nearestPlayer()
    local me <const> = PlayerPedId()
    local here <const> = GetEntityCoords(me)
    local reach <const> = tonumber(ErpConfig.Invite.range) or 3.0
    local bestSid, bestDist
    for _, p in ipairs(GetActivePlayers()) do
        local ped <const> = GetPlayerPed(p)
        if ped and ped ~= 0 and ped ~= me and DoesEntityExist(ped) then
            local d <const> = #(here - GetEntityCoords(ped))
            if d <= reach and (not bestDist or d < bestDist) then
                bestDist, bestSid = d, GetPlayerServerId(p)
            end
        end
    end
    return bestSid
end

-- HEIGHT. A scaled ped will not line up with a paired pose, so both ends flatten
-- to 1.0 for the duration; the server re-derives the real scale on restore
-- always published, even when the height state bag is still empty
local function neutraliseHeight()
    TriggerServerEvent('vorp_character:pupHeightPublish', 1.0)
    return true
end

-- long enough for the flatten to reach both screens and for pup_height's own
-- re-apply retries to finish, so nothing rescales once the pose has started
local LEVEL_WAIT_MS <const> = 1000

-- the server re-derives the real scale from the character, so this cannot write
-- back a wrong height. Sent twice: pup_height rate limits to one request a
-- second, and a short emote can land the reset inside that window
local function restoreHeight()
    TriggerServerEvent('vorp_character:pupResetHeight')
    SetTimeout(1200, function()
        TriggerServerEvent('vorp_character:pupResetHeight')
    end)
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local waited = 0
    while not HasAnimDictLoaded(dict) and waited < 5000 do
        Wait(100)
        waited = waited + 100
    end
    return HasAnimDictLoaded(dict)
end

local function play(key, role, otherSid)
    local e <const> = emoteByKey(key)
    if not e or busy then return end
    if not isHuman() then return end
    if not zoneAllowed(e) then return TriggerEvent('vorp:TipRight', ErpLocale.notHere, 4000) end

    local part <const> = (role == 'target') and e.target or e.player
    if not part or not part.dict or not part.anim then return end

    local ped <const> = PlayerPedId()
    if not loadDict(part.dict) then
        return TriggerEvent('vorp:TipRight', ErpLocale.animFailed, 4000)
    end

    busy = true
    local levelled <const> = e.level and neutraliseHeight()
    -- both ends must already be at 1.0 before the offset is measured, or each
    -- side lines the pose up against the other's real height
    if levelled then Wait(LEVEL_WAIT_MS) end

    local other = otherSid and GetPlayerPed(GetPlayerFromServerId(otherSid)) or nil
    if other == 0 then other = nil end

    -- only the one who accepted moves; the sender is the anchor the offset is
    -- measured from, so they stay exactly where they stood
    if role == 'target' and other and DoesEntityExist(other) then
        local a <const> = GetEntityCoords(other)
        local h <const> = GetEntityHeading(other)
        local rad <const> = math.rad(h)
        local ox <const> = tonumber(part.posX) or 0.0
        local oy <const> = tonumber(part.posY) or 0.0
        local oz <const> = tonumber(part.posZ) or 0.0
        -- offset is in the sender's frame, so it rotates with their heading.
        -- forward is (-sin, cos) and right is (cos, sin), same as creator_scene
        local wx <const> = a.x + ox * math.cos(rad) - oy * math.sin(rad)
        local wy <const> = a.y + ox * math.sin(rad) + oy * math.cos(rad)
        SetEntityCoordsNoOffset(ped, wx, wy, a.z + oz, false, false, false)
        SetEntityHeading(ped, (h + (tonumber(part.rotZ) or 0.0)) % 360.0)
        SetEntityNoCollisionEntity(ped, other, false)
        SetEntityNoCollisionEntity(other, ped, false)
    end

    local ms <const> = tonumber(e.ms) or 10000
    TaskPlayAnim(ped, part.dict, part.anim, 1.0, 1.0, ms, tonumber(part.flag) or 1, 0, true, 0, false, 0, false)
    Wait(ms + 200)

    ClearPedSecondaryTask(ped)
    ClearPedTasks(ped)
    RemoveAnimDict(part.dict)
    if levelled then restoreHeight() end
    busy = false
end

RegisterNetEvent('pup-misc:erp:play', function(key, role, otherSid)
    CreateThread(function()
        local ok, err = pcall(play, key, role, tonumber(otherSid))
        if not ok then
            busy = false
            print('^1[pup-misc erp]^7 ' .. tostring(err))
        end
    end)
end)

-- THE INVITE. A prompt, the same shape pup_hideouts uses, not screen text
RegisterNetEvent('pup-misc:erp:incoming', function(fromSid, key, fromName)
    local e <const> = emoteByKey(key)
    if not e then return end
    -- can't take part right now: say so, or the sender waits on an invite nobody sees
    if busy or not isHuman() then
        return TriggerServerEvent('pup-misc:erp:answer', false)
    end
    invite = {
        from  = tonumber(fromSid),
        key   = key,
        label = ('%s: %s'):format(tostring(fromName or ErpLocale.someone), e.label or key),
        until_ = GetGameTimer() + ((tonumber(ErpConfig.Invite.timeoutSeconds) or 20) * 1000),
    }
end)

CreateThread(function()
    Wait(500)
    acceptPrompt = PromptRegisterBegin()
    PromptSetControlAction(acceptPrompt, ErpConfig.Keys.accept or 0x760A9C6F)
    PromptSetText(acceptPrompt, CreateVarString(10, 'LITERAL_STRING', ErpLocale.accept))
    PromptSetEnabled(acceptPrompt, 1)
    PromptSetVisible(acceptPrompt, 1)
    PromptSetStandardMode(acceptPrompt, 1)
    PromptSetGroup(acceptPrompt, GROUP)
    PromptRegisterEnd(acceptPrompt)

    declinePrompt = PromptRegisterBegin()
    PromptSetControlAction(declinePrompt, ErpConfig.Keys.decline or 0x4CC0E2FE)
    PromptSetText(declinePrompt, CreateVarString(10, 'LITERAL_STRING', ErpLocale.decline))
    PromptSetEnabled(declinePrompt, 1)
    PromptSetVisible(declinePrompt, 1)
    PromptSetStandardMode(declinePrompt, 1)
    PromptSetGroup(declinePrompt, GROUP)
    PromptRegisterEnd(declinePrompt)

    while true do
        local sleep = 500
        if invite then
            if GetGameTimer() > invite.until_ then
                invite = nil
            else
                sleep = 0
                PromptSetActiveGroupThisFrame(GROUP,
                    CreateVarString(10, 'LITERAL_STRING', invite.label))
                if PromptHasStandardModeCompleted(acceptPrompt) then
                    invite = nil
                    TriggerServerEvent('pup-misc:erp:answer', true)
                elseif PromptHasStandardModeCompleted(declinePrompt) then
                    invite = nil
                    TriggerServerEvent('pup-misc:erp:answer', false)
                end
            end
        end
        Wait(sleep)
    end
end)

-- THE MENU
AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER then return end
    exports['pup-ui']:HideInkMenu()
    menuOpen = false

    local key <const> = menuKeys[tonumber(index) or 0]
    if not key then return end

    local sid <const> = nearestPlayer()
    if not sid then return TriggerEvent('vorp:TipRight', ErpLocale.nobodyClose, 4000) end
    TriggerServerEvent('pup-misc:erp:invite', sid, key)
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner == OWNER then menuOpen = false end
end)

RegisterCommand(ErpConfig.General.command or 'erp', function()
    if busy or menuOpen then return end
    if not isHuman() then return end
    if not nearestPlayer() then
        return TriggerEvent('vorp:TipRight', ErpLocale.nobodyClose, 4000)
    end

    -- the menu only lists what is allowed where you stand, so a refusal after
    -- picking one is never a surprise
    local options = {}
    menuKeys = {}
    for _, e in ipairs(ErpConfig.Emotes or {}) do
        if zoneAllowed(e) then
            options[#options + 1] = { label = e.label or e.key, description = ErpLocale.menuRowDesc }
            menuKeys[#menuKeys + 1] = e.key
        end
    end
    if #options == 0 then
        return TriggerEvent('vorp:TipRight', ErpLocale.notSomewhere, 4000)
    end

    menuOpen = true
    exports['pup-ui']:OpenInkMenu({ owner = OWNER, title = ErpLocale.menuTitle, options = options })
end, false)
