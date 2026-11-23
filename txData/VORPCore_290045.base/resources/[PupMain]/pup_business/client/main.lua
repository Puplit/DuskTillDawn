-- pup_business | client state: who am I, the business list, blips, prompts, payday

Me = { job = nil, grade = 0, charid = nil, known = false }
Businesses = {}   -- [job] = public business info from the server

local blips = {}
local stationBlips = {}
local paydayStarted = false

function MyBusiness()
    return Me.job and Businesses[Me.job] or nil
end

function IsBossHere()
    local b = MyBusiness()
    return b ~= nil and (Me.grade or 0) >= b.bossrank
end

-- re-reads job and grade from the server (in a thread)
function RefreshJob()
    local r = Call('whoami')
    if type(r) == 'table' then
        local before = Me.job
        Me.job, Me.grade, Me.charid, Me.known = r.job, tonumber(r.grade) or 0, r.charid, true
        if before ~= Me.job then TriggerEvent('pup_business:client:jobChanged', before, Me.job) end
    end
    return Me.known
end

---------------------------------------------------------------------------
-- blips
---------------------------------------------------------------------------

local function addBlip(x, y, z, sprite, scale, name)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, x, y, z) -- BlipAddForCoords
    SetBlipSprite(blip, sprite, true)
    SetBlipScale(blip, scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, name) -- SetBlipName
    return blip
end

local function clearBlips(list)
    for i = #list, 1, -1 do
        if DoesBlipExist(list[i]) then RemoveBlip(list[i]) end
        list[i] = nil
    end
end

function RebuildBusinessBlips()
    clearBlips(blips)
    for _, b in pairs(Businesses) do
        if b.showblip then
            for _, p in ipairs(b.positions or {}) do
                blips[#blips + 1] = addBlip(p.x, p.y, p.z, b.blipsprite or Config.DefaultBlipSprite, Config.BusinessBlipScale, b.name or b.job)
            end
        end
    end
end

function RebuildStationBlips()
    clearBlips(stationBlips)
    if not Config.DutyStationsEnabled or not Me.job then return end
    for _, st in ipairs(Config.DutyStations or {}) do
        if st.blip then
            for _, j in ipairs(st.jobs or {}) do
                if j == Me.job then
                    stationBlips[#stationBlips + 1] = addBlip(st.coords.x, st.coords.y, st.coords.z,
                        Config.StationBlipSprite, Config.StationBlipScale, st.label or st.region)
                    break
                end
            end
        end
    end
end

RegisterNetEvent('pup_business:businesses', function(list)
    if type(list) ~= 'table' then return end
    local map = {}
    for _, b in ipairs(list) do
        if type(b) == 'table' and type(b.job) == 'string' then map[b.job] = b end
    end
    Businesses = map
    RebuildBusinessBlips()
    TriggerEvent('pup_business:client:businessesChanged')
end)

---------------------------------------------------------------------------
-- payday timer (the server decides whether anything is paid)
---------------------------------------------------------------------------

local function startPayday()
    if paydayStarted then return end
    paydayStarted = true
    CreateThread(function()
        while true do
            Wait(Config.PaydayMinutes * 60 * 1000)
            Call('payday')
        end
    end)
end

---------------------------------------------------------------------------
-- character select, resource start, job change pushes
---------------------------------------------------------------------------

local function onCharacterReady()
    CreateThread(function()
        -- the start-up request is dropped while no character is selected, so a
        -- player who joins after the server started gets the list here
        Call('businesses')
        RefreshJob()
        RebuildBusinessBlips()
        RebuildStationBlips()
        startPayday()
    end)
end

RegisterNetEvent('vorp:SelectedCharacter', function()
    UI.CloseAll()
    onCharacterReady()
end)

-- also restarts the payday timer and re-reads the job after a resource restart
CreateThread(function()
    Wait(2000)
    Call('businesses')
    if LocalPlayer.state.IsInSession then onCharacterReady() end
end)

-- hired, fired, ranked, slots bought: re-read the job, then the open dashboard
-- a job and a grade change arrive together; one re-read covers both
local jobPushToken = 0
RegisterNetEvent('pup_business:findnewhired', function()
    jobPushToken = jobPushToken + 1
    local token = jobPushToken
    CreateThread(function()
        Wait(300)
        if token ~= jobPushToken then return end
        RefreshJob()
        RebuildStationBlips()
        Wait(1000)
        TriggerEvent('pup_business:client:refreshDashboard')
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clearBlips(blips)
    clearBlips(stationBlips)
end)

RegisterCommand('refreshjob', function()
    CreateThread(RefreshJob)
end, false)

RegisterCommand('showjob', function()
    CreateThread(function()
        RefreshJob()
        Wait(1000)
        if not Me.known or not Me.job then
            Tip(L('job_unknown'))
        else
            Tip(L('your_job', Me.job, Me.grade))
        end
    end)
end, false)

---------------------------------------------------------------------------
-- job-menu points: a prompt within reach, a slow scan when nothing is near
---------------------------------------------------------------------------

CreateThread(function()
    local key = Config.InteractKey
    while true do
        local wait = 500
        local b = MyBusiness()
        if b and b.jobmenu and #b.jobmenu > 0 and not UI.AnyOpen() then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local nearest = math.huge
            for _, p in ipairs(b.jobmenu) do
                local d = #(pos - vector3(p.x, p.y, p.z))
                if d < nearest then nearest = d end
            end
            if nearest <= Config.JobMenuRestDistance then
                -- every frame only when the key can actually be pressed
                wait = nearest <= Config.JobMenuDistance + 1.0 and 0 or 200
                local onFoot = not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)
                if nearest <= Config.JobMenuDistance and onFoot then
                    if BizPrompt.show(L('prompt_job_menu'), b.name) then OpenJobMenu() end
                end
            end
        end
        Wait(wait)
    end
end)
