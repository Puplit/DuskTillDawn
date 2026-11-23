-- pup-misc / instance - polyzone routing-bucket zones

local homebucket    = 0
local currentBucket = 0
local Locations     = {}
local ZCount        = 0
local currentLoveAnimation = false
local currentZoneIndex = nil
local isInLoveZone = false

local function isZoneBucket(id)
    for i = 1, ZCount do
        if InstanceConfig.Zones[i] and InstanceConfig.Zones[i].channelId == id then
            return true
        end
    end
    return false
end

local function getHomeBucket()
    return homebucket or 0
end

local function GetNearestPlayer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearestPlayer = nil
    local nearestDistance = 3.0
    
    for _, player in ipairs(GetActivePlayers()) do
        local otherPlayerPed = GetPlayerPed(player)
        if otherPlayerPed ~= playerPed then
            local otherCoords = GetEntityCoords(otherPlayerPed)
            local distance = #(playerCoords - otherCoords)
            
            if distance < nearestDistance then
                nearestDistance = distance
                nearestPlayer = player
            end
        end
    end
    
    return nearestPlayer
end

local function PlayLoveAnimation(enabling)
    if enabling then
        -- the love-animation sync needs v-emotemenu; skip when it is not running
        if type(Valenor) ~= 'table' or type(Valenor.Love) ~= 'table' then return end
        local targetPlayer = GetNearestPlayer()
        if targetPlayer then
            local targetServerId = GetPlayerServerId(targetPlayer)
            local requesterServerId = GetPlayerServerId(PlayerId())
            local myPed = PlayerPedId()
            local coords = GetEntityCoords(myPed)
            local heading = GetEntityHeading(myPed)
            
            local animationKey = "shared_awkward"
            local animationData = Valenor.Love.Dance[animationKey]
            
            TriggerServerEvent('v-emotemenu:server:requestAnimationSync', requesterServerId, targetServerId, "Love", animationKey, animationData, { x = coords.x, y = coords.y, z = coords.z }, heading)
            currentLoveAnimation = true
            
            if InstanceConfig.General.debug then
            end
        else
            if InstanceConfig.General.debug then
            end
        end
    else
        if currentLoveAnimation then
            TriggerEvent('v-emotemenu:client:remoteRestoreCoupleCollision')
            currentLoveAnimation = false
            
            if InstanceConfig.General.debug then
            end
        end
    end
end

local function setBucket(bucketId)
    if not bucketId then return end
    if currentBucket ~= bucketId then
        -- Capture home bucket if entering a zone from a non-managed bucket
        if isZoneBucket(bucketId) and not isZoneBucket(currentBucket) then
            homebucket = currentBucket
            if InstanceConfig.General.debug then 
                print(("[instancebucket] ENTERING ZONE: Captured current bucket %s as homebucket"):format(homebucket)) 
            end
        end

        if InstanceConfig.General.debug then
            print(("[instancebucket] BUCKET CHANGE: %s -> %s"):format(currentBucket, bucketId))
        end

        currentBucket = bucketId
        TriggerServerEvent('pup-misc:instance:setNamed', bucketId)
    end
end

-- Side-effects for a zone (Love/dungeon). `entering` true on enter, false on leave.
local function applyZoneSideEffects(zoneIndex, entering)
    local cfg = InstanceConfig.Zones[zoneIndex]
    if not cfg then return end

    -- Love animations: track zone state
    if cfg.allowErp ~= nil then
        if entering and cfg.allowErp then
            isInLoveZone = true
            currentZoneIndex = zoneIndex
            if InstanceConfig.General.debug then print("[instancebucket] LOVE: ZONE ENABLED (inside zone "..zoneIndex.." - "..cfg.name..")") end
        else
            isInLoveZone = false
            currentZoneIndex = nil
            PlayLoveAnimation(false)
            if InstanceConfig.General.debug then print("[instancebucket] LOVE: ZONE DISABLED (leaving zone "..zoneIndex.." - "..cfg.name..")") end
        end
    end

    -- Dungeon stance
    if cfg.dungeon then
        TriggerServerEvent("pup_dungeon:stance", entering and true or false)
        if InstanceConfig.General.debug then print("[instancebucket] Dungeon stance -> "..tostring(entering)) end
    end
end

-- Recompute which zone (if any) contains this point (no reliance on cached flags)
local function findZoneAtPoint(point)
    for i = 1, ZCount do
        if Locations[i] and Locations[i]:isPointInside(point) then
            return i
        end
    end
    return nil
end

-- ---------------------------------------------------------------- indicator
-- an on-screen notice while in a private zone, so the server does not look empty

-- driven off currentBucket, not the enter/leave callbacks, so it can never stick
local function zoneByChannel(id)
    for i = 1, ZCount do
        local z = InstanceConfig.Zones[i]
        if z and z.channelId == id then return z end
    end
    return nil
end

local function DrawTxt(str, x, y, scale, r, g, b, a)
    local s <const> = CreateVarString(10, 'LITERAL_STRING', str)
    SetTextScale(scale, scale)
    SetTextColor(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    Citizen.InvokeNative(0xADA9255D, 1)
    DisplayText(s, x, y)
end

CreateThread(function()
    local cfg <const> = InstanceConfig.Indicator or {}
    if cfg.enabled == false then return end

    local col <const> = cfg.colour or { 220, 196, 128, 215 }
    while true do
        if isZoneBucket(currentBucket) then
            local zone <const> = zoneByChannel(currentBucket)
            local label <const> = (InstanceLocale.indicator or 'INSTANCED  -  %s')
                :format((zone and zone.name) or InstanceLocale.unnamedZone)
            DrawTxt(label, cfg.x or 0.5, cfg.y or 0.022, cfg.scale or 0.38,
                col[1], col[2], col[3], col[4])
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Watchdog: if we're not in ANY zone, enforce home bucket (cheap: once/2s)
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        if ped ~= 0 then
            local pos = GetEntityCoords(ped)
            local insideIdx = findZoneAtPoint(pos)
            if not insideIdx then
                -- ONLY force home bucket if we are currently in a zone-managed bucket
                if isZoneBucket(currentBucket) then
                    if InstanceConfig.General.debug then
                        print("[instancebucket] WATCHDOG: Correcting bucket to home ("..getHomeBucket()..") from "..currentBucket)
                    end
                    applyZoneSideEffects(currentZoneIndex or 0, false)
                    setBucket(getHomeBucket())
                end
            end
        end
    end
end)

-- Build zones + robust in/out handler
CreateThread(function()
    ZCount = #InstanceConfig.Zones
    if InstanceConfig.General.debug then
    end
    for k = 1, ZCount do
        local cfg = InstanceConfig.Zones[k]
        Locations[k] = PolyZone:Create(cfg.points, {
            name          = "SearchLocation"..k,
            minZ          = cfg.minZ,
            maxZ          = cfg.maxZ,
            debugGrid     = cfg.debugGrid,
            gridDivisions = cfg.gridDivisions,
        })
        if InstanceConfig.General.debug then
        end

        Locations[k]:onPointInOut(PolyZone.getPlayerPosition, function(isInside, point)
            if isInside then
                -- ENTER: take THIS zone immediately (no stale cache)
                setBucket(cfg.channelId)
                applyZoneSideEffects(k, true)
                if InstanceConfig.General.debug then 
                    print(("[instancebucket] ENTER zone %d (%s) -> bucket %s"):format(k, cfg.name or "?", cfg.channelId)) 
                end
            else
                -- EXIT: recompute the active zone from the actual position right now
                local idxNow = findZoneAtPoint(point)
                if idxNow then
                    local cfgNow = InstanceConfig.Zones[idxNow]
                    -- leaving k, entering idxNow
                    applyZoneSideEffects(k, false)
                    setBucket(cfgNow.channelId)
                    applyZoneSideEffects(idxNow, true)
                    if InstanceConfig.General.debug then
                    end
                else
                    -- Outside every zone => go home + reset side effects
                    applyZoneSideEffects(k, false)
                    setBucket(getHomeBucket())
                    if InstanceConfig.General.debug then 
                    end
                end
            end
        end)
    end
end)

-- Home bucket wiring
RegisterNetEvent("pup-misc:SetHomeBucket")
AddEventHandler("pup-misc:SetHomeBucket", function(bucket)
    if type(bucket) == "number" and bucket >= 0 then
        homebucket = bucket
        if InstanceConfig.General.debug then print("[instancebucket] HOME BUCKET SET -> "..homebucket) end
    end
end)

RegisterNetEvent("vorp:SelectedCharacter")
AddEventHandler("vorp:SelectedCharacter", function(charidx, bucket)
    if type(bucket) == "number" then
        homebucket = bucket
        if InstanceConfig.General.debug then print("[instancebucket] HOME BUCKET from SelectedCharacter -> "..homebucket) end
    end
end)

-- EXPORTS: Allow emotemenu to check if player is in a love zone
exports('IsInLoveZone', function()
    return isInLoveZone
end)

exports('GetCurrentLoveZone', function()
    return currentZoneIndex
end)

exports('GetLoveZoneConfig', function()
    if currentZoneIndex and InstanceConfig.Zones[currentZoneIndex] then
        return InstanceConfig.Zones[currentZoneIndex]
    end
    return nil
end)
