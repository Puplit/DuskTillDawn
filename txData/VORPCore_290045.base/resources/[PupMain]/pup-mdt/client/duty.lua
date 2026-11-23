-- pup-mdt client | duty state, the region picker and the AFK watcher

MdtC = MdtC or {}

local afkRunning = false

local function startAfk()
    local minutes = tonumber(Config.Duty and Config.Duty.afkMinutes) or 0
    if afkRunning or minutes <= 0 then return end
    afkRunning = true
    CreateThread(function()
        local poll = (tonumber(Config.Duty.afkPollSeconds) or 10) * 1000
        local move = tonumber(Config.Duty.afkMoveMetres) or 1.5
        local last = GetEntityCoords(PlayerPedId())
        local idleSince = GetGameTimer()
        while afkRunning and MdtC.onDuty do
            Wait(poll)
            local now = GetEntityCoords(PlayerPedId())
            if #(now - last) > move or MdtC.mdtOpen then
                idleSince = GetGameTimer()
                last = now
            elseif GetGameTimer() - idleSince >= minutes * 60000 then
                TriggerServerEvent('pup-mdt:server:afk')
                idleSince = GetGameTimer()
            end
        end
        afkRunning = false
    end)
end

RegisterNetEvent('pup-mdt:client:dutyChanged', function(onDuty, region, isLawyer)
    MdtC.onDuty = onDuty == true
    MdtC.region = region
    if isLawyer ~= nil then
        MdtC.isLawyer = isLawyer == true
        MdtC.dutyLawyer = isLawyer == true
    end
    if MdtC.onDuty then
        startAfk()
    else
        afkRunning = false
        if MdtC.mdtOpen then MdtC.closeMdt(true) end
        if MdtC.clearAllAlerts then MdtC.clearAllAlerts() end
        if MdtC.clearCounsel then MdtC.clearCounsel() end
    end
end)

---------------------------------------------------------------------------
-- region picker: pup-ui list menu, then ox_lib, then MenuData; none = clock on with no region
---------------------------------------------------------------------------
local OWNER = 'pup-mdt:region'
local menuRegions = nil

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= OWNER or not menuRegions then return end
    local r = menuRegions[tonumber(index) or -1] -- pup-ui list rows are 1-based
    menuRegions = nil
    pcall(function() exports['pup-ui']:HideListMenu() end)
    if r then TriggerServerEvent('pup-mdt:server:clockOn', r.id) end
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner == OWNER then menuRegions = nil end
end)
AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner == OWNER then
        menuRegions = nil
        pcall(function() exports['pup-ui']:HideListMenu() end)
    end
end)

local function openPupUi(regions)
    local options = {}
    for _, r in ipairs(regions) do options[#options + 1] = { label = r.label or r.id, desc = r.description, value = r.id } end
    menuRegions = regions
    return pcall(function()
        exports['pup-ui']:OpenListMenu({ owner = OWNER, title = L('cl_clock_on_duty'), subtitle = L('cl_select_region'), options = options, keyboard = true })
    end)
end

local function openOx(regions)
    if GetResourceState('ox_lib') ~= 'started' then return false end
    local opts = {}
    for _, r in ipairs(regions) do
        local id = r.id
        opts[#opts + 1] = { title = r.label or id, description = r.description, onSelect = function() TriggerServerEvent('pup-mdt:server:clockOn', id) end }
    end
    return pcall(function()
        exports.ox_lib:registerContext({ id = OWNER, title = L('cl_clock_on_duty'), options = opts })
        exports.ox_lib:showContext(OWNER)
    end)
end

local function openMenuData(regions)
    local menu = nil
    TriggerEvent('menuapi:getData', function(m) menu = m end)
    if not menu then return false end
    local elements = {}
    for _, r in ipairs(regions) do elements[#elements + 1] = { label = r.label or r.id, value = r.id, desc = r.description } end
    return pcall(function()
        menu.CloseAll()
        menu.Open('default', GetCurrentResourceName(), 'pupmdt_region', { title = L('cl_clock_on_duty'), subtext = L('cl_select_region'), align = 'top-left', elements = elements },
            function(data, m)
                m.close()
                TriggerServerEvent('pup-mdt:server:clockOn', data.current.value)
            end,
            function(_, m) m.close() end)
    end)
end

RegisterNetEvent('pup-mdt:client:regionMenu', function(regions)
    if type(regions) ~= 'table' or #regions == 0 then
        TriggerServerEvent('pup-mdt:server:clockOn', nil)
        return
    end
    if MdtC.pupUi() and openPupUi(regions) then return end
    if openOx(regions) then return end
    if openMenuData(regions) then return end
    TriggerServerEvent('pup-mdt:server:clockOn', nil)
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. ((Config.Duty and Config.Duty.onCommand) or 'onduty'), 'Clock on duty')
    TriggerEvent('chat:addSuggestion', '/' .. ((Config.Duty and Config.Duty.offCommand) or 'offduty'), 'Clock off duty')
    TriggerEvent('chat:addSuggestion', '/' .. (Config.Command or 'mdt'), 'Open the MDT')
end)
