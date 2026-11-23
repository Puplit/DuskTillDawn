-- pup-mdt client | places in the world: public records kiosks, the bounty board, the prison register,
-- evidence lockers, and the checks the server asks this client to run

MdtC = MdtC or {}

MdtC.kioskOpen = false
MdtC.boardOpen = nil -- 'bh' or 'jr'

local function focusPage()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end

local function releasePage()
    if MdtC.mdtOpen then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    TriggerEvent('vorp_inventory:blockInventory', false)
end

local function blipsFor(list, cfg)
    local out = {}
    if not cfg or cfg.enabled == false then return out end
    for _, p in ipairs(list) do
        out[#out + 1] = MdtC.blip(p.x, p.y, p.z, cfg.sprite, cfg.scale or 0.2, cfg.label)
    end
    return out
end

---------------------------------------------------------------------------
-- public records kiosk
---------------------------------------------------------------------------
local PR = Config.PublicRecords or {}
local kioskBusy = false

function MdtC.closeKiosk(tellPage)
    if not MdtC.kioskOpen then return end
    MdtC.kioskOpen = false
    if tellPage ~= false then MdtC.send({ action = 'closeCivilianRecord' }) end
    releasePage()
end

local function openKiosk()
    if kioskBusy or MdtC.kioskOpen or MdtC.mdtOpen then return end
    kioskBusy = true
    TriggerEvent('vorp_inventory:blockInventory', true)
    MdtC.rpc('getCivilianRecord', nil, 10000, { ok = false, message = L('cl_records_unavailable') }, function(r)
        kioskBusy = false
        if MdtC.mdtOpen then return end
        if type(r) ~= 'table' or not r.ok then
            TriggerEvent('vorp_inventory:blockInventory', false)
            MdtC.notify((type(r) == 'table' and r.message) or L('cl_no_record'), 4000)
            return
        end
        MdtC.kioskOpen = true
        MdtC.sendLocale()
        focusPage()
        MdtC.send({ action = 'openCivilianRecord', recordData = r.recordData, tips = r.tips, penalCode = r.penalCode, theme = { colors = Config.Theme and Config.Theme.colors } })
    end)
end

CreateThread(function()
    if PR.enabled == false or not PR.spots then return end
    local blips = blipsFor(PR.spots, PR.blip)
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then for _, b in ipairs(blips) do MdtC.removeBlip(b) end end
    end)
    local label = ('%s: %s'):format(PR.header or L('cl_records_header'), PR.label or L('cl_records_prompt'))
    while true do
        local sleep = 700
        if not MdtC.kioskOpen and not MdtC.mdtOpen and not MdtC.boardOpen then
            local c = GetEntityCoords(PlayerPedId())
            for _, p in ipairs(PR.spots) do
                local d = #(c - p)
                if d < 15.0 and sleep > 200 then sleep = 200 end
                if d <= (PR.promptDistance or 2.0) then
                    sleep = 0 -- the key is read every frame only in prompt range
                    MdtC.prompt(label)
                    if IsControlJustReleased(0, Config.Keys.interact) then
                        MdtC.promptHide()
                        openKiosk()
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- bounty hunter board and prison register
---------------------------------------------------------------------------
local BB = Config.BountyBoard or {}
local REG = (Config.Prison and Config.Prison.register) or {}
local bountyAccess = false
local accessAskedAt = 0
local bbBlip = nil

local function setAccess(on)
    bountyAccess = on == true
    if bountyAccess and not bbBlip and BB.blip and BB.blip.enabled ~= false then
        bbBlip = MdtC.blip(BB.coords.x, BB.coords.y, BB.coords.z, BB.blip.sprite, BB.blip.scale or 0.2, BB.blip.label)
    elseif not bountyAccess and bbBlip then
        MdtC.removeBlip(bbBlip)
        bbBlip = nil
    end
end

local function askAccess()
    accessAskedAt = GetGameTimer()
    MdtC.rpc('bountyAccess', nil, 8000, nil, function(r)
        if type(r) == 'table' and r.access ~= nil then setAccess(r.access) end
    end)
end

RegisterNetEvent('pup-mdt:client:bountyAccess', function(access) setAccess(access) end)
RegisterNetEvent('vorp:SelectedCharacter', function() SetTimeout(3000, askAccess) end)
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then SetTimeout(3000, askAccess) end
end)

function MdtC.closeBoard(kind, tellPage)
    if not MdtC.boardOpen or (kind and MdtC.boardOpen ~= kind) then return end
    local was = MdtC.boardOpen
    MdtC.boardOpen = nil
    if was == 'pending' then return end -- nothing shown yet; the answer will be dropped
    if tellPage ~= false then
        MdtC.send({ action = was == 'bh' and 'closeBountyHunterBoard' or 'closeJailRegister' })
    end
    releasePage()
end

local function openBounty()
    if MdtC.boardOpen or MdtC.mdtOpen then return end
    MdtC.boardOpen = 'pending'
    MdtC.rpc('getBountyBoard', nil, 8000, { ok = false, message = L('cl_timeout') }, function(r)
        if MdtC.boardOpen ~= 'pending' then return end
        MdtC.boardOpen = nil
        if MdtC.mdtOpen then return end
        if type(r) ~= 'table' or not r.ok then
            MdtC.notify((type(r) == 'table' and r.message) or L('cl_timeout'), 5000)
            return
        end
        MdtC.boardOpen = 'bh'
        MdtC.sendLocale()
        TriggerEvent('vorp_inventory:blockInventory', true)
        focusPage()
        MdtC.send({ action = 'openBountyHunterBoard', bounties = r.bounties or {} })
    end)
end

local function openRegister()
    if MdtC.boardOpen or MdtC.mdtOpen then return end
    MdtC.boardOpen = 'pending'
    MdtC.rpc('getJailRoster', nil, 8000, { ok = false, message = L('cl_timeout') }, function(r)
        if MdtC.boardOpen ~= 'pending' then return end
        MdtC.boardOpen = nil
        if MdtC.mdtOpen then return end
        if type(r) ~= 'table' or not r.ok then
            MdtC.notify((type(r) == 'table' and r.message) or L('cl_timeout'), 5000)
            return
        end
        MdtC.boardOpen = 'jr'
        MdtC.sendLocale()
        TriggerEvent('vorp_inventory:blockInventory', true)
        focusPage()
        MdtC.send({ action = 'openJailRegister', roster = r.roster or {} })
    end)
end

CreateThread(function()
    local regBlip = nil
    if REG.enabled ~= false and REG.coords and REG.blip and REG.blip.enabled then
        regBlip = MdtC.blip(REG.coords.x, REG.coords.y, REG.coords.z, REG.blip.sprite, REG.blip.scale or 0.2, REG.blip.label)
    end
    AddEventHandler('onResourceStop', function(res)
        if res ~= GetCurrentResourceName() then return end
        MdtC.removeBlip(regBlip)
        MdtC.removeBlip(bbBlip)
    end)
    local regPressAt = 0
    while true do
        local sleep = 700
        if not MdtC.boardOpen and not MdtC.mdtOpen and not MdtC.kioskOpen then
            local c = GetEntityCoords(PlayerPedId())
            -- bounty board
            if BB.enabled ~= false and BB.coords then
                local d = #(c - BB.coords)
                if d < 20.0 and GetGameTimer() - accessAskedAt > 30000 then askAccess() end
                if d < 15.0 and sleep > 200 then sleep = 200 end
                if bountyAccess and d <= (BB.promptDistance or 2.0) then
                    sleep = 0
                    MdtC.prompt(BB.label or L('cl_bounty_prompt'))
                    if IsControlJustReleased(0, Config.Keys.interact) then
                        MdtC.promptHide()
                        openBounty()
                    end
                end
            end
            -- prison register
            if REG.enabled ~= false and REG.coords then
                local rc = vector3(REG.coords.x, REG.coords.y, REG.coords.z)
                local d = #(c - rc)
                if d < 15.0 and sleep > 200 then sleep = 200 end
                if d <= (REG.promptDistance or 2.0) then
                    sleep = 0
                    MdtC.prompt(L('ps_register_prompt'))
                    if IsControlJustReleased(0, Config.Keys.interact) and GetGameTimer() - regPressAt > 1000 then
                        regPressAt = GetGameTimer()
                        MdtC.promptHide()
                        openRegister()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- evidence lockers
---------------------------------------------------------------------------
local EV = Config.Evidence or {}
local lockerAccess = nil -- { station = id, ok = bool } while near one station
local asking = false
local askedAt = 0

RegisterNetEvent('pup-mdt:client:dutyChanged', function() lockerAccess = nil end)

local function checkLocker(stationId)
    -- a callback that never answers must not block the locker for good
    if asking and GetGameTimer() - askedAt < 5000 then return end
    asking = true
    askedAt = GetGameTimer()
    local c = MdtC.core()
    if not c or not c.Callback then asking = false lockerAccess = { station = stationId, ok = false } return end
    c.Callback.TriggerAsync('pup-mdt:evidence:canSeize', function(res)
        asking = false
        lockerAccess = { station = stationId, ok = res ~= false and res ~= nil and tostring(res) == tostring(stationId) }
    end)
end

CreateThread(function()
    if EV.enabled == false or not EV.stations then return end
    while true do
        local sleep = 700
        local near = nil
        if not MdtC.mdtOpen and not MdtC.kioskOpen and not MdtC.boardOpen and MdtC.onDuty and not MdtC.isLawyer then
            local c = GetEntityCoords(PlayerPedId())
            for _, s in ipairs(EV.stations) do
                local d = #(c - s.coords)
                if d < 12.0 and sleep > 200 then sleep = 200 end
                if d <= (EV.promptDistance or 2.5) then near = s break end
            end
        end
        if not near then
            if lockerAccess then lockerAccess = nil end
        else
            if not lockerAccess or lockerAccess.station ~= near.id then
                lockerAccess = nil
                checkLocker(near.id)
            elseif lockerAccess.ok then
                sleep = 0
                MdtC.prompt(L('cl_locker_prompt'))
                if IsControlJustReleased(0, Config.Keys.interact) then
                    MdtC.promptHide()
                    TriggerServerEvent('pup-mdt:server:lockerOpen', near.id)
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- checks the server asks this client to run
---------------------------------------------------------------------------
RegisterNetEvent('pup-mdt:client:captureCheck', function(checkId, hunterSrc)
    local ped = PlayerPedId()
    local isDead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
    local hog = MdtC.nativeTrue(0x3AA24CCC0D451379, ped)
    local cuffed = MdtC.nativeTrue(0x74E559B3BC910685, ped)
    local hunter = GetPlayerFromServerId(tonumber(hunterSrc) or -1)
    local hunterPed = (hunter and hunter ~= -1) and GetPlayerPed(hunter) or 0
    local carried = false
    local close = false
    if hunterPed ~= 0 and DoesEntityExist(hunterPed) then
        if MdtC.nativeTrue(0xA911EE21EDF69DAF, hunterPed) then
            carried = Citizen.InvokeNative(0xD806CD2A4F2C2996, hunterPed, Citizen.ResultAsInteger()) == ped
        end
        close = #(GetEntityCoords(ped) - GetEntityCoords(hunterPed)) <= (tonumber(BB.captureRadius) or 6.0)
    end
    local ok = close and (hog or cuffed or carried or isDead)
    TriggerServerEvent('pup-mdt:server:captureAnswer', checkId, ok == true, isDead == true)
end)

RegisterNetEvent('pup-mdt:client:zoneQuery', function(queryId, kind)
    local types = Config.Zones and Config.Zones.hintTypes and Config.Zones.hintTypes[kind] or nil
    local name = MdtC.zoneName(MdtC.myCoords(), types)
    if name == (PupMdtZones and PupMdtZones.unknown) then name = nil end
    TriggerServerEvent('pup-mdt:server:zoneAnswer', queryId, name)
end)
