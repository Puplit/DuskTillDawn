local target = -1
local targetInventory = {}
local targetWeapons = {}
local isHandcuffed = false
local defaultVehicle = -1
local initialized = false
local isboss = false
local societyMenuOpened = false
local playerJob
local jobgrade
local isDead = IsPedDeadOrDying(PlayerPedId())
local policeOnDuty = false
local pjob
local dragStatus = {}
dragStatus.isDragged = false
local attackKeys = {
    0x1E7D7275, -- "MeleeModifier",
    0xB5EEEFB7, -- "MeleeBlock",
    0x2277FAE9, -- "MeleeGrapple",
    0xADEAF48C, -- "MeleeGrappleAttack",
    0x018C47CF, -- "MeleeGrappleChoke",
    0x91C9A817, -- "MeleeGrappleReversal",
    0xD0C1FEFF, -- "MeleeGrappleBreakout",
    0xBE1F4699, -- "MeleeGrappleStandSwitch",
    0x67ED272E, -- "MeleeGrappleMountSwitch",
    0xB2F377E8, -- "Attack",
    0x07CE1E61, -- "MeleeAttack1",
    0xCEFD9220, -- "Attack2",
}

-- HOTKEYS - hold the modifier, tap the key
local function ctrlPressed(hash)
    return hash and (IsControlPressed(0, hash) or IsDisabledControlPressed(0, hash))
end

local function ctrlReleased(hash)
    return hash and (IsControlJustReleased(0, hash) or IsDisabledControlJustReleased(0, hash))
end

Citizen.CreateThread(function()
    local HK        = PoliceConfig.Keys
    local modifier  = HK.hotkeyModifier
    local cuffKey   = HK.cuff
    local escortKey = HK.escort

    if not modifier or (not cuffKey and not escortKey) then return end

    while true do
        local wait = 250
        -- a civilian never polls at all: the thread idles at a full second and the hotkeys simply do not exist for them
        if not IsLawman() then
            wait = 1000
            -- no resource announces a job change (MDT roster, pup_business, Discord), so a cached
            -- "none" goes stale on its own; otherwise a new lawman stays a civilian until they reconnect
            RefreshJobIfStale()
        elseif not isHandcuffed and ctrlPressed(modifier) then
            wait = 0
            if ctrlReleased(cuffKey) then
                HandcuffPlayer()
            elseif ctrlReleased(escortKey) then
                EscortPlayer()
            end
        end
        Citizen.Wait(wait)
    end
end)

RegisterNetEvent("vorp:SelectedCharacter")
AddEventHandler("vorp:SelectedCharacter", function(charid)
    TriggerServerEvent("pup-misc:police:checkmyjob")
end)

-- REHYDRATE ON RESTART
AddEventHandler('onClientResourceStart', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    local char = LocalPlayer.state.Character
    if not char or not char.CharId then return end
    TriggerServerEvent("pup-misc:police:checkmyjob")
    LoadBadgeOffset()
end)

RegisterNetEvent("pup-misc:police:gooffduty")
AddEventHandler("pup-misc:police:gooffduty", function()
    TriggerServerEvent("pup-misc:police:gooffdutysv")
end)

local onwheel = false

RegisterNetEvent("pup-misc:ferriswheel:StopSeat")
AddEventHandler("pup-misc:ferriswheel:StopSeat", function()
    onwheel = false 

end)
RegisterNetEvent("pup-misc:ferriswheel:StartSeat")
AddEventHandler("pup-misc:ferriswheel:StartSeat", function()
    onwheel = true 
    
end)

-- Disable player actions
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if isHandcuffed or onwheel then
			DisableControlAction(0, 0xB2F377E8, true) -- Attack
			DisableControlAction(0, 0xC1989F95, true) -- Attack 2
			DisableControlAction(0, 0x07CE1E61, true) -- Melee Attack 1
			DisableControlAction(0, 0xF84FA74F, true) -- MOUSE2
			DisableControlAction(0, 0xCEE12B50, true) -- MOUSE3
			DisableControlAction(0, 0x8FFC75D6, true) -- Shift
			DisableControlAction(0, 0xD9D0E1C0, true) -- SPACE
            DisableControlAction(0, 0xF3830D8E, true) -- J
            DisableControlAction(0, 0x80F28E95, true) -- L
            DisableControlAction(0, 0xDB096B85, true) -- CTRL
            DisableControlAction(0, 0xE30CD707, true) -- R
        elseif isHandcuffed and IsPedDeadOrDying(PlayerPedId()) then
            isHandcuffed = false
            ClearPedSecondaryTask(PlayerPedId())
            SetEnableHandcuffs(PlayerPedId(), false)
            DisablePlayerFiring(PlayerPedId(), false)
            SetPedCanPlayGestureAnims(PlayerPedId(), true)
            
			Citizen.Wait(500)
		end
	end
end)

-- CIVILIANS NEVER SEE THIS SCRIPT
function IsLawman()
    return pjob == "pass"
end

-- NIL IS NOT "CIVILIAN"
local RETRY_MAX <const> = 10
local retries = 0
local jobAskedAt = 0
local STALE_MS <const> = 20000

local function askJob()
    jobAskedAt = GetGameTimer()
    TriggerServerEvent("pup-misc:police:checkmyjob")
end

--- true once the server has told us SOMETHING. nil = still unknown.
local function jobKnown()
    return pjob == "pass" or pjob == "none"
end

-- re-ask once the cached answer is old enough to be wrong
function RefreshJobIfStale()
    if GetGameTimer() - jobAskedAt < STALE_MS then return end
    askJob()
end

-- Call at the top of a law command
local function ensureJob()
    if jobKnown() then
        -- so a promotion since the last answer is not stuck behind the cache
        RefreshJobIfStale()
        return true
    end
    askJob()
    return false
end

-- pup_business's server raises this whenever it hires, promotes or fires someone,
-- so the police side re-asks at the moment the job actually changed
RegisterNetEvent('pup_business:findnewhired', function()
    jobAskedAt = 0
    askJob()
end)

RegisterNetEvent('pup-misc:police:thejob')
AddEventHandler('pup-misc:police:thejob', function(v,job,grade)
    if v == "retry" then
        -- character not loaded server-side yet; try again shortly
        if retries < RETRY_MAX then
            retries = retries + 1
            SetTimeout(2000, askJob)
        end
        return
    end
    retries = 0
    pjob = v
    playerJob = job
    jobgrade = grade
end)

function PoliceGetPlayers()
    local players = {}

    for i = 0, 256 do
        if NetworkIsPlayerActive(i) then
            table.insert(players, GetPlayerServerId(i))
        end
    end
    
    return players
end

local function openLawMenu()
    -- ensureJob() re-asks when the handshake never landed
    if not ensureJob() then return end
    if not IsLawman() then return end
    TriggerServerEvent("pup-misc:police:checkMenuDuty")
end

RegisterCommand(PoliceConfig.General.commands.menu, openLawMenu)
RegisterCommand("mmenu", openLawMenu)   -- alias of the law menu command

RegisterNetEvent("pup-misc:police:menuDutyResponse")
AddEventHandler("pup-misc:police:menuDutyResponse", function(onDuty)
    if onDuty then
        OpenMarshalMenu()
    else
        TriggerEvent("vorp:TipRight", PoliceLocale.notOnDuty, 2000)
    end
end)

RegisterCommand(PoliceConfig.General.commands.badge, function()
    if not ensureJob() then return end
    if not IsLawman() then return end
    TriggerServerEvent("pup-misc:police:checkBadgeDuty")
end)

-- the badge is chosen by rank
RegisterNetEvent("pup-misc:police:badgeDutyResponse")
AddEventHandler("pup-misc:police:badgeDutyResponse", function(onDuty, job, grade, rankName)
    if not onDuty or job == nil or grade == nil then
        TriggerEvent("vorp:TipRight", PoliceLocale.notOnDuty, 2000)
        return
    end
    playerJob = job
    jobgrade  = grade
    EquipBadgeByGrade(job, grade, rankName)
end)

-- GOING OFF DUTY TAKES THE BADGE OFF
RegisterNetEvent('pup-mdt:client:dutyChanged')
AddEventHandler('pup-mdt:client:dutyChanged', function(onDuty)
    if onDuty then return end
    if not IsBadgeOn() then return end
    removebadge()
    TriggerEvent('vorp:TipRight', PoliceLocale.offDutyBadge, 3000)
end)

RegisterNetEvent('pup-misc:police:setBoss')
AddEventHandler('pup-misc:police:setBoss', function(boss)
    isboss = boss
end)
-- pup_business's off-duty command raises this. Off duty is not unemployed (duty is tracked
-- by policeOnDuty and mdt:client:dutyChanged), so only the badge is put away
RegisterNetEvent('pup-misc:police:takeoffbadge')
AddEventHandler('pup-misc:police:takeoffbadge', function()
    removebadge()
end)

RegisterCommand(PoliceConfig.General.commands.adjustBadge, function()
    if not IsLawman() then return end
    OpenBadgeAdjustmentMenu()
end)

-- THE LAW MENU - pup-ui's ink menu
local MENU_OWNER  = 'police_job:lawmenu'
local menuOpen    = false
local menuActions = {}

-- no hard dependency on pup-ui: check rather than throw
function HasPupUI()
    if GetResourceState('pup-ui') == 'started' then return true end
    TriggerEvent("vorp:TipRight", PoliceLocale.menuUnavailable, 3000)
    return false
end

local function closeLawMenu()
    if not menuOpen then return end
    menuOpen = false
    menuActions = {}
    exports['pup-ui']:HideInkMenu()
end

function OpenMarshalMenu()
    if not HasPupUI() then return end

    local options = {}
    menuActions   = {}

    local function add(label, description, fn)
        options[#options + 1]     = { label = label, description = description }
        menuActions[#menuActions + 1] = fn
    end

    add(PoliceLocale.optCuff, PoliceLocale.optCuffDesc,
        function() HandcuffPlayer() end)

    add(PoliceLocale.optEscort, PoliceLocale.optEscortDesc,
        function() EscortPlayer() end)

    add(PoliceLocale.optWagon, PoliceLocale.optWagonDesc,
        function() PutInOutVehicle() end)

    add(IsBadgeOn() and PoliceLocale.optBadgeOff or PoliceLocale.optBadgeOn,
        IsBadgeOn() and PoliceLocale.optBadgeOffDesc or PoliceLocale.optBadgeOnDesc,
        function() TriggerServerEvent('pup-misc:police:checkBadgeDuty') end)

    add(PoliceLocale.optAdjust, PoliceLocale.optAdjustDesc,
        function() OpenBadgeAdjustmentMenu() end)

    add(PoliceLocale.optClose, '', function() end)

    local rank    = GetBadgeRank()
    local subtitle
    if playerJob then
        subtitle = rank and ('%s - %s'):format(playerJob:upper(), rank) or playerJob:upper()
    end

    menuOpen = true
    exports['pup-ui']:OpenInkMenu({
        owner    = MENU_OWNER,
        title    = PoliceLocale.menuTitle,
        subtitle = subtitle,
        options  = options,
    })
end

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= MENU_OWNER or not menuOpen then return end
    local fn = menuActions[index]
    closeLawMenu()
    if fn then fn() end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= MENU_OWNER then return end
    menuOpen    = false
    menuActions = {}
end)

-- ESCORT: the cuffed ped walks beside the lawman on a follow task, with real collision;
-- a snap only happens if they fall far behind or get stuck
local EC <const> = PoliceConfig.Escort or {}
local ESCORT_X, ESCORT_Y = EC.sideMetres or 0.38, EC.forwardMetres or 0.18   -- close at the lawman's right: held by the arm
local ESCORT_SNAP_DIST   = 6.0           -- further than this from the spot = teleport back to it
local ESCORT_RETASK_MS   = 3000          -- re-issue the follow if they have stalled

local MOVE_CONTROLS <const> = {
    0x4D8FB4C1, -- INPUT_MOVE_LR
    0xFDA83190, -- INPUT_MOVE_UD
    0x8FFC75D6, -- INPUT_SPRINT
    0xD9D0E1C0, -- INPUT_JUMP
    0xCEFD9220, -- INPUT_ENTER
    0xDE794E3E, -- INPUT_COVER
}

function EscortStart(ped, cop)
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    ClearPedTasks(ped)
    SetPedCanRagdoll(ped, false)
    -- TASK_FOLLOW_TO_OFFSET_OF_ENTITY: speed 2.0 lets them jog to keep up with a running lawman; persist = keep following
    Citizen.InvokeNative(0x304AE42E357B8C7E, ped, cop, ESCORT_X, ESCORT_Y, 0.0, 2.0, -1, 0.25, true, false, false, false, false, false)
end

-- run every ~250ms while escorting; returns the time of the last re-task
function EscortTick(ped, cop, lastTask)
    local slot = GetOffsetFromEntityInWorldCoords(cop, ESCORT_X, ESCORT_Y, 0.0)
    local dist = #(GetEntityCoords(ped) - slot)
    local now = GetGameTimer()
    if dist > ESCORT_SNAP_DIST then
        -- left behind (a door, a fence, stairs taken fast): put them back in their spot
        SetEntityCoords(ped, slot.x, slot.y, slot.z, false, false, false, false)
        SetEntityHeading(ped, GetEntityHeading(cop))
        EscortStart(ped, cop)
        return now
    elseif dist > 1.5 and now - (lastTask or 0) > ESCORT_RETASK_MS and GetEntitySpeed(ped) < 0.3 then
        EscortStart(ped, cop)
        return now
    end
    return lastTask
end

function EscortStop(ped)
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    ClearPedTasks(ped)
    SetPedCanRagdoll(ped, true)
end

-- THE LAWMAN'S HOLD: an upper-body loop while escorting, so it reads as leading
-- someone by the arm rather than being followed. Re-applied if a jump or a
-- stumble knocks it off; stopped the moment the escort ends.
local holding = false
local HOLD_FLAGS <const> = 1 + 16 + 32   -- loop, upper body only, keep walking control

local function holdAnim()
    local a = EC.holdAnim
    if type(a) ~= 'table' or not a.dict or not a.name then return nil end
    if not HasAnimDictLoaded(a.dict) then
        RequestAnimDict(a.dict)
        local t = 0
        while not HasAnimDictLoaded(a.dict) and t < 2000 do Wait(50) t = t + 50 end
        if not HasAnimDictLoaded(a.dict) then return nil end
    end
    return a
end

function EscortHoldStart()
    if holding then return end
    holding = true
    CreateThread(function()
        local a = holdAnim()
        if not a then holding = false return end
        while holding do
            local me = PlayerPedId()
            if IsPedOnFoot(me) and not IsEntityPlayingAnim(me, a.dict, a.name, 3) then
                TaskPlayAnim(me, a.dict, a.name, 4.0, -4.0, -1, HOLD_FLAGS, 0.0, false, 0, false, 0, false)
            end
            Wait(500)
        end
        StopAnimTask(PlayerPedId(), a.dict, a.name, 2.0)
    end)
end

function EscortHoldStop() holding = false end

-- the escorted PLAYER's side: only they can move their own ped
Citizen.CreateThread(function()
    local wasDragged, lastTask, nextTick = false, 0, 0

    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        if isHandcuffed and dragStatus.isDragged then
            local cop = GetPlayerPed(GetPlayerFromServerId(dragStatus.CopId))

            if cop ~= 0 and DoesEntityExist(cop) and IsPedOnFoot(cop) and not IsPedDeadOrDying(cop, true) then
                if not wasDragged then
                    EscortStart(playerPed, cop)
                    wasDragged, lastTask, nextTick = true, GetGameTimer(), 0
                end
                -- their own stick would fight the follow task
                for _, c in ipairs(MOVE_CONTROLS) do DisableControlAction(0, c, true) end
                if GetGameTimer() >= nextTick then
                    nextTick = GetGameTimer() + 250
                    lastTask = EscortTick(playerPed, cop, lastTask)
                end
            else
                wasDragged = false
                dragStatus.isDragged = false
                EscortStop(playerPed)
            end
        elseif wasDragged then
            wasDragged = false
            EscortStop(playerPed)
        else
            Citizen.Wait(500)
        end
    end
end)

RegisterNetEvent('pup-misc:police:drag')
AddEventHandler('pup-misc:police:drag', function(copId, on)
    -- state from the server, not a local flip. The cuffed check lives server side.
    dragStatus.isDragged = on and true or false
    dragStatus.CopId = copId
end)

local dragPairs = {}  -- [copServerId] = draggedServerId
local pinnedPed = {}  -- [copServerId] = the ped handle this client already pinned

-- ONLY THE DRAGGED PLAYER CAN ATTACH THEMSELVES
-- no collision calls here: SetEntityNoCollisionEntity only lasts one frame. Track the pair only.
local function applyDragPair(copId, targetId)
    local cp, tp = GetPlayerFromServerId(copId), GetPlayerFromServerId(targetId)
    if cp == -1 or tp == -1 then return end
    local cop, dragged = GetPlayerPed(cp), GetPlayerPed(tp)
    if cop == 0 or dragged == 0 then return end
    if pinnedPed[copId] == dragged then return end
    pinnedPed[copId] = dragged
end

RegisterNetEvent('pup-misc:police:dragSync', function(copId, targetId, on)
    -- this is me escorting someone: hold them by the arm for as long as it lasts
    if copId == GetPlayerServerId(PlayerId()) then
        if on then EscortHoldStart() else EscortHoldStop() end
    end
    if on then
        dragPairs[copId] = targetId
        applyDragPair(copId, targetId)
    else
        dragPairs[copId] = nil
        pinnedPed[copId] = nil
        local cp, tp = GetPlayerFromServerId(copId), GetPlayerFromServerId(targetId)
        if cp ~= -1 and tp ~= -1 then
            local cop, dragged = GetPlayerPed(cp), GetPlayerPed(tp)
            if cop ~= 0 and dragged ~= 0 then
                if GetEntityAttachedTo(dragged) == cop then
                    DetachEntity(dragged, true, false)
                end
            end
        end
    end
end)

-- cleanup: a restart must not leave anyone pinned to a ped that is about to go
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local me = PlayerPedId()
    if IsEntityAttached(me) then DetachEntity(me, true, false) end
    EscortHoldStop()
    ClearPedSecondaryTask(me)   -- the hold loop's own cleanup dies with the resource
    -- a restart mid-drag must not leave the dragged player permanently unable to ragdoll
    SetPedCanRagdoll(me, true)
    for copId, targetId in pairs(dragPairs) do
        local tp = GetPlayerFromServerId(targetId)
        local cp = GetPlayerFromServerId(copId)
        if tp ~= -1 and cp ~= -1 then
            local dragged, cop = GetPlayerPed(tp), GetPlayerPed(cp)
            if dragged ~= 0 and cop ~= 0 then
                if GetEntityAttachedTo(dragged) == cop then DetachEntity(dragged, true, false) end
            end
        end
    end
    dragPairs, pinnedPed = {}, {}
end)

-- peds stream in late, so keep re-pinning what the server says is active
CreateThread(function()
    TriggerServerEvent('pup-misc:police:dragResync')
    TriggerServerEvent('pup-misc:police:syncMyCuff') -- clears a stale local cuffed flag
    while true do
        Wait(1000)
        -- catches peds that stream in after the pair was announced; applyDragPair is a no-op once that handle is pinned
        for copId, targetId in pairs(dragPairs) do applyDragPair(copId, targetId) end
    end
end)

RegisterNetEvent('pup-misc:police:putinoutvehicle')
AddEventHandler('pup-misc:police:putinoutvehicle', function()
    local ped = PlayerPedId()
    if IsPedSittingInAnyVehicle(ped) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, vehicle, 16)
        return
    end

    local vehicle = GetClosestVehicle(PoliceConfig.Restraint.interactDistance * 4.0)
    if not vehicle or vehicle == 0 then
        TriggerEvent("vorp:TipRight", PoliceLocale.noWagon, 2000)
        return
    end

    for seat = 1, 6 do
        if Citizen.InvokeNative(0xE052C1B1CAA4ECE4, vehicle, seat) then
            Citizen.InvokeNative(0xF75B0D629E1C063D, ped, vehicle, seat)
            return
        end
    end
    TriggerEvent("vorp:TipRight", PoliceLocale.wagonFull, 2000)
end)

-- Nearest wagon to us within `radius` metres, or nil
function GetClosestVehicle(radius)
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, radius

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local dist = #(coords - GetEntityCoords(vehicle))
            if dist < bestDist then
                best, bestDist = vehicle, dist
            end
        end
    end

    return best
end

RegisterNetEvent("pup-misc:police:lockpick")
AddEventHandler("pup-misc:police:lockpick", function()
    local closestPlayer, closestDistance = GetClosestPlayer()
    if closestPlayer ~= -1 and closestDistance <= 2.0 then
        local chance = math.random(1,100)
        if not isDead then
            if chance < 85 then
                local ped = PlayerPedId()
                local anim = "mini_games@story@mud5@cracksafe_look_at_dial@med_r@ped"
                local idle = "base_idle"
                local lr = "left_to_right"
                local rl = "right_to_left"
                RequestAnimDict(anim)
                while not HasAnimDictLoaded(anim) do
                    Citizen.Wait(50)
                end
                
                TaskPlayAnim(PlayerPedId(), anim, idle, 8.0, -8.0, -1, 32, 0, false, false, false)
                Citizen.Wait(1250)
                TaskPlayAnim(PlayerPedId(), anim, lr, 8.0, -8.0, -1, 32, 0, false, false, false)
                Citizen.Wait(325)
                TaskPlayAnim(PlayerPedId(), anim, idle, 8.0, -8.0, -1, 32, 0, false, false, false)
                Citizen.Wait(1250)
                TaskPlayAnim(PlayerPedId(), anim, rl, 8.0, -8.0, -1, 32, 0, false, false, false)
                Citizen.Wait(325)
                repeat
                    TriggerEvent("pup-misc:police:lockpick")
                until(chance)
            end
            if chance >= 85 then
                local breakChance = math.random(1,10)
                if breakChance < 3 then
                    TriggerServerEvent("pup-misc:police:lockpick:break")
                else
                    local ped = PlayerPedId()
                    local anim = "mini_games@story@mud5@cracksafe_look_at_dial@small_r@ped"
                    local open = "open"
                    RequestAnimDict(anim)
                    while not HasAnimDictLoaded(anim) do
                        Citizen.Wait(50)
                    end
                    TaskPlayAnim(PlayerPedId(), anim, open, 8.0, -8.0, -1, 32, 0, false, false, false)
                    Citizen.Wait(1250)
                    TriggerServerEvent('pup-misc:police:lockpicksv', GetPlayerServerId(closestPlayer))
                end
            end
        end
    else
        TriggerEvent("vorp:TipRight", PoliceLocale.noPlayerNearby, 3000)
        return
    end
    
end)

function PoliceDrawTxt(text, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local str = CreateVarString(10, "LITERAL_STRING", text)
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
	SetTextCentre(centre)
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
	Citizen.InvokeNative(0xADA9255D, 1);
    DisplayText(str, x, y)
end

function PoliceDrawText3D(x, y, z, text)
	local onScreen,_x,_y=GetScreenCoordFromWorldCoord(x, y, z)
	local px,py,pz=table.unpack(GetGameplayCamCoord())  
	local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)
	local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
	if onScreen then
	  SetTextScale(0.30, 0.30)
	  SetTextFontForCurrentCommand(1)
	  SetTextColor(255, 255, 255, 215)
	  SetTextCentre(1)
	  DisplayText(str,_x,_y)
	  local factor = (string.len(text)) / 225
	  DrawSprite("feeds", "hud_menu_4a", _x, _y+0.0125,0.015+ factor, 0.03, 0.1, 35, 35, 35, 190, 0)
	end
end

-- imprisonment is handled by pup-mdt

-- fines are handled by pup-mdt (/mdtbill)

function PutInOutVehicle()
    if not IsLawman() then return end
    local closestPlayer, closestDistance = GetClosestPlayer()
    if closestPlayer ~= -1 and closestDistance <= PoliceConfig.Restraint.interactDistance then
        TriggerServerEvent('pup-misc:police:putinoutvehicle', GetPlayerServerId(closestPlayer))
    else
        TriggerEvent("vorp:TipRight", PoliceLocale.noPlayerNearby, 2000)
        return
    end
end

-- the escort, shared by the hotkey and the menu
function EscortPlayer()
    if not IsLawman() then return end
    local closestPlayer, closestDistance = GetClosestPlayer()
    if closestPlayer ~= -1 and closestDistance <= PoliceConfig.Restraint.interactDistance then
        TriggerServerEvent('pup-misc:police:drag', GetPlayerServerId(closestPlayer))
    else
        TriggerEvent("vorp:TipRight", PoliceLocale.noPlayerNearby, 2000)
    end
end

function CheckID()
    if not IsLawman() then return end
    local player = tonumber(onscreenKeyboard('PLAYER_ID'))
    if not tonumber(player) then
        TriggerEvent("vorp:TipRight", PoliceLocale.invalidId, 10000)
        return
    elseif not NetworkIsPlayerActive(GetPlayerFromServerId(player)) then
        TriggerEvent("vorp:TipRight", PoliceLocale.notOnline, 10000)
        return
    end

    TriggerServerEvent('pup-misc:police:GetID', tonumber(player))
end

local targetCuffedState = false

RegisterNetEvent('pup-misc:police:cuffStatus')
AddEventHandler('pup-misc:police:cuffStatus', function(targetId, cuffed)
    targetCuffedState = cuffed
end)

function HandcuffPlayer()
    -- silent for civilians: no tip, and crucially no animation/progress bar
    if not IsLawman() then return end

    local closestPlayer, closestDistance = GetClosestPlayer()

    if closestPlayer ~= -1 and closestDistance <= PoliceConfig.Restraint.interactDistance then
        local targetServerId = GetPlayerServerId(closestPlayer)
        targetCuffedState = false
        TriggerServerEvent('pup-misc:police:checkCuffed', targetServerId)
        Citizen.Wait(100)

        if targetCuffedState then
            TriggerServerEvent('pup-misc:police:handcuff', targetServerId)
            TriggerEvent("vorp:TipRight", PoliceLocale.uncuffed, 2000)
            return
        end

        RequestAnimDict("script_proc@rustling@olar@player_picklock")
        local waiting = 0
        while not HasAnimDictLoaded("script_proc@rustling@olar@player_picklock") do
            waiting = waiting + 100
            Citizen.Wait(100)
            if waiting > 5000 then
                break
            end
        end
        TaskPlayAnim(PlayerPedId(), 'script_proc@rustling@olar@player_picklock',
                     'base', 8.0, 8.0, 3000, 31, 0, true, 0, false, 0, false)
        TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 2.0, 'PinSucc', 0.8)
        exports['pup-ui']:Progress({ label = PoliceLocale.cuffing, duration = 3000 })
        Citizen.Wait(3000)

        local closestPlayer2, closestDistance2 = GetClosestPlayer()
        if closestPlayer2 ~= -1 and closestDistance2 <= PoliceConfig.Restraint.interactDistance then
            TriggerServerEvent('pup-misc:police:handcuff', GetPlayerServerId(closestPlayer2))
        else
            TriggerEvent("vorp:TipRight", PoliceLocale.noPlayerNearby, 10000)
            return
        end
        ClearPedSecondaryTask(PlayerPedId())
    else
        TriggerEvent("vorp:TipRight", PoliceLocale.noPlayerNearby, 10000)
        return
    end
end

function onscreenKeyboard(defaultTitle)
	local _return = nil

	DisplayOnscreenKeyboard(1,"FMMC_KEY_TIP8", "", defaultTitle, "", "", "", 9)
	while true do
		DisableAllControlActions(0)
		Citizen.Wait(0)

		if UpdateOnscreenKeyboard() == 1 then
			_return = GetOnscreenKeyboardResult()
			break
		elseif UpdateOnscreenKeyboard() == 2 or UpdateOnscreenKeyboard() == 3 then
			break
		end
	end

	return _return
end

function GetClosestPlayer()
    local players, closestDistance, closestPlayer = GetActivePlayers(), -1, -1
    local playerPed, playerId = PlayerPedId(), PlayerId()
    local coords, usePlayerPed = coords, false

    if coords then
        coords = vector3(coords.x, coords.y, coords.z)
    else
        usePlayerPed = true
        coords = GetEntityCoords(playerPed)
    end

    for i = 1, #players do
        local tgt = GetPlayerPed(players[i])

        if not usePlayerPed or (usePlayerPed and players[i] ~= playerId) then
            local targetCoords = GetEntityCoords(tgt)
            local distance = #(coords - targetCoords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer  = players[i]
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

RegisterNetEvent('pup-misc:police:handcuff')
AddEventHandler('pup-misc:police:handcuff', function(state)
	-- state from the server
	if state ~= nil then isHandcuffed = state and true or false
	else isHandcuffed = not isHandcuffed end
	local playerPed = PlayerPedId()

	Citizen.CreateThread(function()
		if isHandcuffed then
			SetEnableHandcuffs(playerPed, true)
			DisablePlayerFiring(playerPed, true)
			SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true) -- unarm player
			SetPedCanPlayGestureAnims(playerPed, false)
        else
            ClearPedSecondaryTask(playerPed)
            SetEnableHandcuffs(playerPed, false)
            DisablePlayerFiring(playerPed, false)
            SetPedCanPlayGestureAnims(playerPed, true)
		end
	end)
end)

RegisterNetEvent('pup-misc:police:lockpicked')
AddEventHandler('pup-misc:police:lockpicked', function()
    local playerPed = PlayerPedId()
    ClearPedSecondaryTask(playerPed)
    SetEnableHandcuffs(playerPed, false)
    DisablePlayerFiring(playerPed, false)
    SetPedCanPlayGestureAnims(playerPed, true)
    isHandcuffed = false
end)

function lockpick()
    local ped = PlayerPedId()
    local anim = "mini_games@story@mud5@cracksafe_look_at_dial@med_r@ped"
    local idle = "base_idle"
    local lr = "left_to_right"
    local rl = "right_to_left"
    RequestAnimDict(anim)
    while not HasAnimDictLoaded(anim) do
        Citizen.Wait(50)
    end
    
    TaskPlayAnim(PlayerPedId(), anim, idle, 8.0, -8.0, -1, 32, 0, false, false, false)
    Citizen.Wait(1250)
    TaskPlayAnim(PlayerPedId(), anim, lr, 8.0, -8.0, -1, 32, 0, false, false, false)
    Citizen.Wait(325)
    TaskPlayAnim(PlayerPedId(), anim, idle, 8.0, -8.0, -1, 32, 0, false, false, false)
    Citizen.Wait(1250)
    TaskPlayAnim(PlayerPedId(), anim, rl, 8.0, -8.0, -1, 32, 0, false, false, false)
    Citizen.Wait(325)
end

-- answers any caller of this export cleanly
function isplayerinjail()
    return false, 0
end

exports("isplayerinjail",isplayerinjail)
  