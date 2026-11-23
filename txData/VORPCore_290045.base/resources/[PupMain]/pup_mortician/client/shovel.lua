-- pup_mortician | the shovel in hand and treasure digging

Shovel = { inHand = false, prop = nil, digging = false, session = 0 }

local DC, A = Config.Dig, Config.Anim
local panning = false

AddEventHandler('panning:panning', function(on)
    panning = on == true
end)

local blockedZones = {}
-- keyed unsigned so a signed/unsigned hash from the native still matches
for _, name in ipairs(DC.blockedZones) do blockedZones[joaat(name) & 0xFFFFFFFF] = true end

local group = GetRandomIntInRange(0, 0xffffff)
local digPrompt, awayPrompt

local function ensurePrompts()
    if digPrompt then return end
    digPrompt = MakePrompt(Config.Keys.use, L('dig'), group)
    awayPrompt = MakePrompt(Config.Keys.putAway, L('putAway'), group)
end

function Shovel.PutAway()
    if not Shovel.inHand then return end
    Shovel.inHand = false
    Shovel.session = Shovel.session + 1
    DeleteObj(Shovel.prop)
    Shovel.prop = nil
end

local function takeOut()
    local hash = LoadModel(Config.Models.shovel)
    if not hash then return end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local prop = CreateObject(hash, pos.x, pos.y, pos.z, true, true, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    local bone = IsPedMale(ped) and A.shovelBoneMale or A.shovelBoneFemale
    local o, r = A.shovelOffset, A.shovelRot
    AttachEntityToEntity(prop, ped, bone, o.x, o.y, o.z, r.x, r.y, r.z, true, true, false, true, 1, true, false, false)
    Shovel.prop = prop
    Shovel.inHand = true
    Shovel.session = Shovel.session + 1
    local session = Shovel.session
    ensurePrompts()

    CreateThread(function()
        while Shovel.inHand and Shovel.session == session do
            Wait(0)
            DisableControlAction(0, Config.Keys.weaponWheel, true)
            DisableControlAction(0, Config.Keys.b, true)
            local p = PlayerPedId()
            if not Shovel.digging then
                if IsPedSwimming(p) or IsPedClimbing(p) or IsPedFalling(p) or IsPedDeadOrDying(p, true) then
                    Shovel.PutAway()
                    break
                end
                ShowGroup(group, L('shovelGroup'))
                if PromptHasStandardModeCompleted(awayPrompt) then
                    Shovel.PutAway()
                    break
                end
                if PromptHasStandardModeCompleted(digPrompt) and not IsPedOnMount(p) then
                    CreateThread(Shovel.Dig)
                end
            end
        end
    end)
end

-- the server answered a use of the shovel item
function Shovel.Toggle()
    if Shovel.inHand then
        if not Shovel.digging then Shovel.PutAway() end
        return
    end
    if PlayerBusyBody() then
        Tip(L('cannotDigNow'))
        return
    end
    takeOut()
end

local function skillBar()
    local sb = DC.skillBar
    local area = math.max(sb.areaMin, math.min(sb.areaMax, sb.areaBase - sb.areaStep * sb.difficulty))
    local speed = math.max(sb.speedMin, math.min(sb.speedMax, sb.speedBase + sb.speedStep * sb.difficulty))
    local p = promise.new()
    local settled = false
    local function settle(result)
        if settled then return end
        settled = true
        p:resolve(result)
    end
    local ok = pcall(function()
        exports['pup-minigames']:skill_bar({
            style = sb.style, icon = sb.icon, orientation = sb.orientation,
            area_size = area, perfect_area_size = sb.perfectArea, speed = speed,
            moving_icon = sb.movingIcon, scale = sb.scale,
        }, settle)
    end)
    if not ok then return false end
    -- pup-minigames silently ignores a start while another of its games is
    -- running and never calls back; without this the dig would hang forever
    -- (Shovel.digging stuck, goldpan told we are still shoveling)
    SetTimeout(60000, function() settle(nil) end)
    local result = Citizen.Await(p)
    return result == 'success' or result == 'perfect'
end

-- the treasure-hunting anim scene, where the player stands
local function playScene(dict, list, ms)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local z = pos.z
    local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
    if found and math.abs(pos.z - gz) <= DC.groundSnap then z = gz end
    local heading = GetEntityHeading(ped)
    local scene = Citizen.InvokeNative(0x1FCA98E33C1437B3, dict, 0, list, false, true) -- CREATE_ANIM_SCENE
    if not scene or scene == 0 then
        Wait(ms)
        return
    end
    Citizen.InvokeNative(0x020894BF17A02EF2, scene, pos.x, pos.y, z, 0.0, 0.0, heading, 2) -- SET_ANIM_SCENE_ORIGIN
    Citizen.InvokeNative(0x8B720AD451CA2AB3, scene, 'player', ped, 0)                     -- SET_ANIM_SCENE_ENTITY
    Citizen.InvokeNative(0xAF068580194D9DC7, scene)                                         -- LOAD_ANIM_SCENE
    Wait(A.sceneLoadMs)
    Citizen.InvokeNative(0xF4D94AF761768700, scene)                                         -- START_ANIM_SCENE
    Wait(math.max(0, ms - A.sceneLoadMs))
    pcall(function() Citizen.InvokeNative(0x84EEDB2C6E650000, scene) end)                  -- DELETE_ANIM_SCENE
    ClearPedTasks(PlayerPedId(), true, false)
end

local function inBlockedTown()
    local pos = GetEntityCoords(PlayerPedId())
    local zone = Citizen.InvokeNative(0x43AD8FC02B429D33, pos.x, pos.y, pos.z, 1) -- GET_MAP_ZONE_AT_COORDS (town)
    zone = math.tointeger(zone)
    return zone ~= nil and zone ~= 0 and blockedZones[zone & 0xFFFFFFFF] == true
end

local function setPropVisible(on)
    if Shovel.prop and DoesEntityExist(Shovel.prop) then SetEntityVisible(Shovel.prop, on) end
end

function Shovel.Dig()
    if Shovel.digging then return end
    if panning then Tip(L('panning')) return end
    if inBlockedTown() then Tip(L('noDigTown')) return end
    Shovel.digging = true
    TriggerEvent('shoveling:shoveling', true)

    local ok, err = pcall(function()
        if not skillBar() then
            setPropVisible(false)
            playScene(A.sceneNothingDict, A.sceneNothingList, A.failSceneMs)
            setPropVisible(true)
            Tip(L('nothingDown'))
            return
        end
        local res = Act('digStart', {})
        if not res.ok then
            Say(res)
            return
        end
        local ms = tonumber(res.ms) or (DC.seconds * 1000)
        setPropVisible(false)
        CreateThread(function()
            if res.find then
                playScene(A.sceneGrabDict, A.sceneGrabList, ms)
            else
                playScene(A.sceneNothingDict, A.sceneNothingList, ms)
            end
        end)
        ProgressWait(L('progDig'), ms)
        setPropVisible(true)
        Say(Act('digFinish', {}))
    end)
    if not ok then print(('[%s] dig failed: %s'):format(RES, tostring(err))) end

    setPropVisible(true)
    TriggerEvent('shoveling:shoveling', false)
    Shovel.digging = false
end
