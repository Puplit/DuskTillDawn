-- pup-medical | doctors on the client: the /med menu, treatment, cabinets,
-- the back-alley syringe and being bandaged

local M = Config.Medical or {}
local MENU_OWNER <const> = 'pup-medical:med'
local TREAT_RANGE <const> = 3.0

local menuLevel = nil   -- 'root' | 'treat'
local working = false   -- an animation is running

local function openMenu(level)
    menuLevel = level
    local options
    if level == 'root' then
        options = { { label = L('medOptions'), desc = L('medOptionsDesc') } }
    else
        options = {
            { label = L('medRevive'),  desc = L('medReviveDesc') },
            { label = L('medBandage'), desc = L('medBandageDesc') },
        }
    end
    local ok, err = pcall(function()
        exports['pup-ui']:OpenListMenu({
            owner     = MENU_OWNER,
            title     = L('medMenuTitle'),
            subtitle  = L('medMenuSubtitle'),
            options   = options,
            keyboard  = true,
            keepInput = true,
        })
    end)
    if not ok then
        menuLevel = nil
        print('[pup-medical] pup-ui list menu failed: ' .. tostring(err))
    end
end

local function closeMenu()
    menuLevel = nil
    pcall(function() exports['pup-ui']:HideListMenu() end)
end

local function revive()
    if working then return end
    local target, ped = NearestPlayer(TREAT_RANGE)
    if not target then return TipBottom(L('nobodyNear'), 4000) end
    if not PedDown(ped) then return TipBottom(L('notUnconscious'), 4000) end
    working = true
    TipBottom(L('reviving'), 2000)
    PlayReviveAnim(2000)
    working = false
    if IsDownNow() then return end
    TriggerServerEvent('pup-medical:server:revive', target)
end

local function bandage()
    if working then return end
    local target = NearestPlayer(TREAT_RANGE)
    if not target then return TipBottom(L('nobodyNear'), 4000) end
    working = true
    TipBottom(L('bandaging'), 10000)
    PlayScenario('WORLD_HUMAN_CROUCH_INSPECT', 10000)
    working = false
    if IsDownNow() then return end
    TriggerServerEvent('pup-medical:server:bandage', target)
end

RegisterNetEvent('pup-medical:client:openMed', function()
    if IsDownNow() then return end
    openMenu('root')
end)

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= MENU_OWNER then return end
    local level = menuLevel
    menuLevel = nil
    if level == 'root' then
        openMenu('treat')
    elseif level == 'treat' then
        closeMenu()
        if index == 1 then
            CreateThread(revive)
        elseif index == 2 then
            CreateThread(bandage)
        end
    end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= MENU_OWNER then return end
    if menuLevel == 'treat' then openMenu('root') else menuLevel = nil end
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner == MENU_OWNER then menuLevel = nil end
end)

---------------------------------------------------------------------------
-- Being bandaged (only the server sends this)
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:client:bandaged', function()
    local ped = PlayerPedId()
    local health = GetAttributeCoreValue(ped, 0) or 0
    local stamina = GetAttributeCoreValue(ped, 1) or 0
    SetAttributeCoreValue(ped, 0, math.min(100, health + 50))
    SetAttributeCoreValue(ped, 1, math.min(100, stamina + 50))
    local maxHp = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(maxHp, GetEntityHealth(ped) + 50), 0)
end)

---------------------------------------------------------------------------
-- Back-alley syringe (the server says when it was used)
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:client:useIllegal', function()
    TriggerEvent('vorp_inventory:CloseInv')
    if IsDownNow() or working then return end
    local ill = M.illegalSyringe or {}
    local target, ped = NearestPlayer(tonumber(ill.reviveRange) or 3.0)
    if not target then return TipBottom(L('illegalNobody'), 4000) end
    if not PedDown(ped) then return TipBottom(L('illegalNotNeeded'), 4000) end
    local ms = math.floor(tonumber(ill.useTimeMs) or 10000)
    working = true
    TipBottom(L('injecting'), ms)
    PlayReviveAnim(ms)
    working = false
    if IsDownNow() then return end
    TriggerServerEvent('pup-medical:server:illegalRevive', target)
end)

---------------------------------------------------------------------------
-- Cabinets
---------------------------------------------------------------------------
local cab = M.cabinet or {}
local cabinetBlips = {}
local cabinetGroup, cabinetPrompt = nil, nil
local CABINET_RANGE <const> = 1.5

CreateThread(function()
    local spots = cab.locations or {}
    if #spots == 0 then return end
    for _, loc in ipairs(spots) do
        cabinetBlips[#cabinetBlips + 1] = CoordBlip(loc, -695368421, 0.2, L('blipDoctor'))
    end
    cabinetGroup = GetRandomIntInRange(0, 0xffffff)
    cabinetPrompt = MakePrompt(cabinetGroup, Config.Keys.cabinet, L('cabinetOpen'))
    local lastAsk = 0

    while true do
        local here = GetEntityCoords(PlayerPedId())
        local nearest, nearD = nil, math.huge
        for _, loc in ipairs(spots) do
            local d = #(here - loc)
            if d < nearD then nearest, nearD = loc, d end
        end
        if nearD > 15.0 then
            Wait(1500)
        elseif nearD > CABINET_RANGE then
            Wait(300)
        else
            while #(GetEntityCoords(PlayerPedId()) - nearest) <= CABINET_RANGE do
                Wait(0)
                if IsDownNow() or MenuOpen() or Client.deciding or GetGameTimer() < Client.cabinetYield then
                    Wait(200)
                else
                    ShowGroup(cabinetGroup, cab.name or 'Medical Cabinet')
                    if UiPromptHasStandardModeCompleted(cabinetPrompt, 0) and GetGameTimer() - lastAsk > 1000 then
                        lastAsk = GetGameTimer()
                        TriggerServerEvent('pup-medical:server:openCabinet')
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, b in ipairs(cabinetBlips) do DropBlip(b) end
    if cabinetPrompt then UiPromptDelete(cabinetPrompt) end
    if menuLevel then closeMenu() end
end)
