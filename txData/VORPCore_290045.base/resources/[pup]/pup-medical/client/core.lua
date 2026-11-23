-- pup-medical | client helpers shared by every client file

Client = {
    deciding     = false,  -- inside the accept/deny/back step
    cabinetYield = 0,      -- GetGameTimer() until which the cabinet prompt stands down
    onDuty       = false,
}

function TipRight(text, ms)
    TriggerEvent('vorp:TipRight', text, ms or 8000)
end

function TipBottom(text, ms)
    TriggerEvent('vorp:TipBottom', text, ms or 5000)
end

function IsDownNow()
    local ped = PlayerPedId()
    return IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or IsPlayerDead(PlayerId())
end

function InWater()
    local v = IsEntityInWater(PlayerPedId())
    return v == true or v == 1
end

function PedDown(ped)
    return IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
end

---------------------------------------------------------------------------
-- Zone names (town, written name, print name, district, state)
---------------------------------------------------------------------------
local ZONE_TYPES <const> = { 1, 13, 12, 10, 0 }

function ZoneAt(coords)
    if not coords then return 'Unknown' end
    for _, t in ipairs(ZONE_TYPES) do
        local hash = Citizen.InvokeNative(0x43AD8FC02B429D33, coords.x, coords.y, coords.z, t, Citizen.ResultAsInteger())
        if hash and hash ~= 0 then
            return (Config.Zones and Config.Zones[hash]) or 'Unknown'
        end
    end
    return 'Unknown'
end

---------------------------------------------------------------------------
-- Nearby players
---------------------------------------------------------------------------
function NearestPlayer(range)
    local me = PlayerPedId()
    local here = GetEntityCoords(me)
    local best, bestD = nil, range
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - here)
                if d <= bestD then best, bestD = pid, d end
            end
        end
    end
    if not best then return nil end
    return GetPlayerServerId(best), GetPlayerPed(best)
end

---------------------------------------------------------------------------
-- Animations
---------------------------------------------------------------------------
function LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(50) end
    return HasAnimDictLoaded(dict)
end

function PlayReviveAnim(ms)
    local ped = PlayerPedId()
    if LoadDict('mech_revive@unapproved') then
        TaskPlayAnim(ped, 'mech_revive@unapproved', 'revive', 4.0, -4.0, ms, 1, 0.0, false, false, false)
    end
    Wait(ms)
    ClearPedTasks(ped)
    RemoveAnimDict('mech_revive@unapproved')
end

function PlayScenario(name, ms)
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, joaat(name), ms, true, false, false, false)
    Wait(ms)
    ClearPedTasks(ped)
end

---------------------------------------------------------------------------
-- Prompts
---------------------------------------------------------------------------
function MakePrompt(group, key, label, holdMs)
    local p = UiPromptRegisterBegin()
    UiPromptSetControlAction(p, key)
    UiPromptSetText(p, CreateVarString(10, 'LITERAL_STRING', label))
    UiPromptSetEnabled(p, true)
    UiPromptSetVisible(p, true)
    if holdMs then
        UiPromptSetHoldMode(p, holdMs)
    else
        UiPromptSetStandardMode(p, true)
    end
    UiPromptSetGroup(p, group, 0)
    UiPromptRegisterEnd(p)
    return p
end

function ShowGroup(group, title)
    UiPromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', title), 0, 0, 0, 0)
    TriggerEvent('pup:promptYield', 250)
end

function MenuOpen()
    if GetResourceState('pup-ui') ~= 'started' then return false end
    local ok, open = pcall(function() return exports['pup-ui']:IsPanelOpen() end)
    return ok and open == true
end

---------------------------------------------------------------------------
-- Map blips
---------------------------------------------------------------------------
function CoordBlip(coords, sprite, scale, name, modifier)
    local blip = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite, true)
    SetBlipScale(blip, scale)
    if modifier then BlipAddModifier(blip, joaat(modifier)) end
    if name then SetBlipName(blip, name) end
    return blip
end

function RadiusBlip(coords, radius, modifier)
    local blip = BlipAddForRadius(-1282792512, coords.x, coords.y, coords.z, radius)
    if modifier then BlipAddModifier(blip, joaat(modifier)) end
    return blip
end

function DropBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

function SetRoute(coords)
    ClearGpsMultiRoute()
    local here = GetEntityCoords(PlayerPedId())
    StartGpsMultiRoute(joaat('COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(here.x, here.y, here.z, false)
    AddPointToGpsMultiRoute(coords.x, coords.y, coords.z, false)
    SetGpsMultiRouteRender(true)
end

function ClearRoute()
    ClearGpsMultiRoute()
end

-- one GPS route at a time: only the holder that drew it may clear it, so an
-- old decision step closing late cannot wipe the route of the new one
local routeOwner = nil

function SetRouteFor(holder, coords)
    routeOwner = holder
    SetRoute(coords)
end

function ClearRouteFor(holder)
    if routeOwner ~= holder then return end
    routeOwner = nil
    ClearRoute()
end

---------------------------------------------------------------------------
-- On-screen text
---------------------------------------------------------------------------
-- western game font with a hard shadow; start the text with ~e~ for red (scaleY defaults to scale)
function ScreenText(text, x, y, scale, scaleY)
    SetTextFontForCurrentCommand(1)
    SetTextScale(scale or 0.3, scaleY or scale or 0.3)
    SetTextColor(255, 255, 255, 255)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), x, y)
end

RegisterNetEvent('pup-medical:client:duty', function(on)
    Client.onDuty = on == true
end)
