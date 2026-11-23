-- pup-medical | job alerts on the client: sending, the call list, the
-- accept/deny/back step, responding, station prompts and on-screen text

local A = Config.Alerts or {}
local CANCEL = A.cancelCommand or 'calert'
local LIST_OWNER <const> = 'pup-medical:calls'
local ARRIVE_RANGE <const> = 20.0
local MAX_ROWS <const> = 20

local caller     = {}    -- [typeKey] = { mode = 'waiting' | 'helpComing' | 'nobody', free = bool }
local cooldown   = {}    -- [typeKey] = GetGameTimer() of the last send
local sentDead   = false -- the last Medical call went out while down
local deadSendAt = nil   -- GetGameTimer() of the first send while down
local incoming   = false
local responding = nil   -- { id, typeKey, coords, blip, area }
local decision   = nil   -- { row, blip, area, result }
local offsets    = {}    -- [alertId] = vector3 offset of the search circle
local listRows   = nil
local listType   = nil
local watcherOn  = false

-- read by death.lua: set when this player was told nobody can come
ToldNoDoctors = nil      -- { inWater = bool }

---------------------------------------------------------------------------
-- Map marks for one call
---------------------------------------------------------------------------
local function unmark(holder)
    if not holder then return end
    DropBlip(holder.blip); holder.blip = nil
    DropBlip(holder.area); holder.area = nil
    ClearRouteFor(holder)
end

local function mark(holder, coords, def, id)
    DropBlip(holder.blip); holder.blip = nil
    DropBlip(holder.area); holder.area = nil
    if def.mode == 'radius' then
        local r = tonumber(def.radius) or 100.0
        local off = offsets[id]
        if not off then
            local ang = math.random() * 2.0 * math.pi
            local dist = math.random() * 0.4 * r
            off = vector3(math.cos(ang) * dist, math.sin(ang) * dist, 0.0)
            offsets[id] = off
        end
        local centre = vector3(coords.x + off.x, coords.y + off.y, coords.z)
        holder.area = RadiusBlip(centre, r + 0.0, def.radiusColor)
        SetRouteFor(holder, centre)
    else
        holder.blip = CoordBlip(coords, def.blipSprite or 2119977580, 1.5, L('blipAlert'), def.blipColor)
        SetRouteFor(holder, coords)
    end
end

local function vecOf(t)
    if type(t) ~= 'table' and type(t) ~= 'vector3' then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

---------------------------------------------------------------------------
-- Clearing
---------------------------------------------------------------------------
local function stopResponding()
    if responding then unmark(responding) end
    responding = nil
end

local function clearAll()
    caller = {}
    sentDead = false
    incoming = false
    stopResponding()
    if decision then decision.result = 'abort' end
    offsets = {}
    listRows = nil
end

-- death.lua calls this when the player is up again
function AlertsOnAlive()
    deadSendAt = nil
    ToldNoDoctors = nil
end

local function cancelAll(quiet)
    TriggerServerEvent('pup-medical:server:cancel', quiet == true)
    clearAll()
    if not quiet then TipRight(L('allCleared'), 8000) end
end

---------------------------------------------------------------------------
-- Caller watcher: the Medical tracker and the client side of free respawn
---------------------------------------------------------------------------
local function startWatcher()
    if watcherOn then return end
    watcherOn = true
    CreateThread(function()
        local lastPos = GetEntityCoords(PlayerPedId())
        while next(caller) ~= nil do
            Wait(2000)
            local ped = PlayerPedId()
            local down = IsDownNow()

            if caller[MEDICAL_TYPE] then
                if sentDead and not down then
                    TipRight(L('upCancelled'), 8000)
                    cancelAll(true)
                    break
                end
                local pos = GetEntityCoords(ped)
                if #(pos - lastPos) > 3.0 then
                    lastPos = pos
                    TriggerServerEvent('pup-medical:server:moved')
                end
            end

            local fr = A.freeRespawn
            if down and deadSendAt and type(fr) == 'table' and fr.enabled then
                local wait = (tonumber(fr.waitMinutes) or 10) * 60000
                if GetGameTimer() - deadSendAt >= wait then
                    for key, st in pairs(caller) do
                        if st.mode ~= 'nobody' then
                            caller[key] = { mode = 'nobody', free = true }
                            ToldNoDoctors = { inWater = InWater() }
                        end
                    end
                end
            end
        end
        watcherOn = false
    end)
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function sendAlert(key)
    local def = AlertType(key)
    if not def then return end
    local now = GetGameTimer()
    if cooldown[key] and now - cooldown[key] < ALERT_COOLDOWN * 1000 then
        return TipRight(L('cooldown', ALERT_COOLDOWN), 8000)
    end
    cooldown[key] = now
    local down = IsDownNow()
    if down and not deadSendAt then deadSendAt = now end
    if not down then deadSendAt = nil end
    if key == MEDICAL_TYPE then sentDead = down end
    TriggerServerEvent('pup-medical:server:sendAlert', key, ZoneAt(GetEntityCoords(PlayerPedId())))
end

for _, key in ipairs(AlertTypeKeys()) do
    local def = AlertType(key)
    if type(def.command) == 'string' and def.command ~= '' then
        RegisterCommand(def.command, function() sendAlert(key) end, false)
        TriggerEvent('chat:addSuggestion', '/' .. def.command, def.suggestion or '')
    end
end

RegisterCommand(CANCEL, function() cancelAll(false) end, false)
TriggerEvent('chat:addSuggestion', '/' .. CANCEL, L('txtCancel', CANCEL))

RegisterNetEvent('pup-medical:client:callerState', function(state, typeKey, extra)
    extra = type(extra) == 'table' and extra or {}
    if state == 'clear' then
        if typeKey then caller[typeKey] = nil else caller = {} end
        if next(caller) == nil then sentDead = false end
        return
    end
    if not AlertType(typeKey) then return end
    if state == 'waiting' or state == 'helpComing' then
        caller[typeKey] = { mode = state }
    elseif state == 'nobody' then
        caller[typeKey] = { mode = 'nobody', free = extra.free == true }
        if typeKey == MEDICAL_TYPE and extra.free == true and IsDownNow() then
            ToldNoDoctors = { inWater = InWater() }
        end
    end
    startWatcher()
end)

-- the server could not honour a respawn yet; keep the claim for the next try
RegisterNetEvent('pup-medical:client:keepToldNoDoctors', function()
    if not ToldNoDoctors then ToldNoDoctors = { inWater = InWater() } end
end)

---------------------------------------------------------------------------
-- The call list
---------------------------------------------------------------------------
local function distanceText(d)
    if d < 1000 then return ('%dm'):format(math.floor(d)) end
    return ('%.1fkm'):format(d / 1000)
end

RegisterCommand('alertmenu', function(_, args)
    incoming = false
    local arg = args and args[1]
    TriggerServerEvent('pup-medical:server:openList', type(arg) == 'string' and arg or nil, false)
end, false)
TriggerEvent('chat:addSuggestion', '/alertmenu', L('txtIncomingHow'))

RegisterNetEvent('pup-medical:client:alertList', function(list, typeKey)
    if type(list) ~= 'table' then return end
    incoming = false
    listType = typeKey
    local here = GetEntityCoords(PlayerPedId())
    local rows = {}
    for _, e in ipairs(list) do
        local c = vecOf(e.coords)
        local def = AlertType(e.typeKey)
        if c and def and tonumber(e.id) then
            rows[#rows + 1] = {
                id = tonumber(e.id), typeKey = e.typeKey, coords = c, dead = e.dead == true,
                player = tonumber(e.player) or 0, waited = tonumber(e.waited) or 0,
                dist = #(c - here),
            }
        elseif tonumber(e.id) and type(e.typeKey) == 'string' then
            TriggerServerEvent('pup-medical:server:dropStale', tonumber(e.id), e.typeKey)
        end
    end
    if #rows == 0 then return TipRight(L('noCalls'), 8000) end
    table.sort(rows, function(a, b)
        if a.dead ~= b.dead then return a.dead end
        return a.dist < b.dist
    end)
    local total = #rows
    while #rows > MAX_ROWS do table.remove(rows) end

    local options = {}
    for i, r in ipairs(rows) do
        options[i] = {
            label = ('%s  -  %s  -  %s'):format(ZoneAt(r.coords), r.dead and L('rowDead') or L('rowAlive'), distanceText(r.dist)),
            desc  = ('%s. %s. %s'):format(L('rowWaited', ShortWait(r.waited)), L('rowCaller', r.player), L('rowHelp', CANCEL)),
        }
    end
    listRows = rows
    local ok, err = pcall(function()
        exports['pup-ui']:OpenListMenu({
            owner     = LIST_OWNER,
            title     = L('listTitle', tostring(typeKey)),
            subtitle  = total > MAX_ROWS and L('listSubtitleCapped', total) or L('listSubtitle', total),
            options   = options,
            keyboard  = true,
            keepInput = true,
        })
    end)
    if not ok then print('[pup-medical] pup-ui list menu failed: ' .. tostring(err)) end
end)

---------------------------------------------------------------------------
-- Accept / Deny / Back
---------------------------------------------------------------------------
local function startDecision(row)
    local def = AlertType(row.typeKey)
    if not def then return end
    if decision then decision.result = 'abort' end
    TipRight(L('searchHint'), 8000)
    local d = { row = row }
    decision = d
    mark(d, row.coords, def, row.id)
    Client.deciding = true

    CreateThread(function()
        local group = GetRandomIntInRange(0, 0xffffff)
        local pAccept = MakePrompt(group, Config.Keys.alertAccept, L('promptAccept'))
        local pDeny = MakePrompt(group, Config.Keys.alertDeny, L('promptDeny'))
        local pBack = MakePrompt(group, Config.Keys.alertBackOut, L('promptBack'))
        d.prompts = { pAccept, pDeny, pBack }
        while not d.result do
            Wait(0)
            ShowGroup(group, L('decideTitle'))
            Client.cabinetYield = GetGameTimer() + 250
            if UiPromptHasStandardModeCompleted(pAccept, 0) then
                d.result = 'accept'
            elseif UiPromptHasStandardModeCompleted(pDeny, 0) then
                d.result = 'deny'
            elseif UiPromptHasStandardModeCompleted(pBack, 0) then
                d.result = 'back'
            elseif IsDownNow() then
                d.result = 'abort'
            end
        end
        UiPromptDelete(pAccept)
        UiPromptDelete(pDeny)
        UiPromptDelete(pBack)
        d.prompts = nil
        unmark(d)
        if decision == d then decision = nil end
        Client.deciding = decision ~= nil
        -- a call already being answered keeps its marks and route
        if responding and d.result ~= 'accept' then
            mark(responding, responding.coords, responding.def, responding.id)
        end

        if d.result == 'accept' then
            TriggerServerEvent('pup-medical:server:accept', row.id, row.typeKey, ZoneAt(GetEntityCoords(PlayerPedId())))
        elseif d.result == 'deny' then
            TriggerServerEvent('pup-medical:server:deny', row.id, row.typeKey)
            TipRight(L('alertRemoved'), 8000)
        elseif d.result == 'back' then
            TriggerServerEvent('pup-medical:server:openList', listType, true)
        end
    end)
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= LIST_OWNER then return end
    local row = listRows and listRows[tonumber(index) or 0]
    listRows = nil
    if row then startDecision(row) end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner == LIST_OWNER then listRows = nil end
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner == LIST_OWNER then listRows = nil end
end)

---------------------------------------------------------------------------
-- Responding
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:client:responding', function(data)
    if type(data) ~= 'table' then return end
    local def = AlertType(data.typeKey)
    local c = vecOf(data.coords)
    local id = tonumber(data.id)
    if not def or not c or not id then return end
    stopResponding()
    local r = { id = id, typeKey = data.typeKey, coords = c, def = def }
    responding = r
    mark(r, c, def, id)

    CreateThread(function()
        while responding == r do
            Wait(500)
            if responding ~= r then break end
            if #(GetEntityCoords(PlayerPedId()) - r.coords) <= ARRIVE_RANGE then
                unmark(r)
                responding = nil
                TipRight(L('arrived'), 8000)
                TriggerServerEvent('pup-medical:server:arrived', r.id, r.typeKey)
            end
        end
    end)
end)

RegisterNetEvent('pup-medical:client:targetMoved', function(id, coords)
    local c = vecOf(coords)
    if not responding or responding.id ~= tonumber(id) or not c then return end
    responding.coords = c
    offsets[responding.id] = nil
    mark(responding, c, responding.def, responding.id)
end)

RegisterNetEvent('pup-medical:client:clearResponding', function(id)
    if not responding then return end
    if id == nil or responding.id == tonumber(id) then stopResponding() end
end)

RegisterNetEvent('pup-medical:client:incoming', function(on)
    incoming = on == true
end)

---------------------------------------------------------------------------
-- Revived: any open call is withdrawn
---------------------------------------------------------------------------
local function onRevived()
    if next(caller) ~= nil or responding then
        TriggerServerEvent('pup-medical:server:cancel', true)
    end
    clearAll()
    AlertsOnAlive()
end

RegisterNetEvent('vorp_core:Client:OnPlayerRevive', onRevived)
RegisterNetEvent('vorp:resurrectPlayer', onRevived)

RegisterNetEvent('vorp:SelectedCharacter', function()
    clearAll()
    AlertsOnAlive()
    cooldown = {}
end)

---------------------------------------------------------------------------
-- Stations: blips and the optional send prompt
---------------------------------------------------------------------------
local stationBlips = {}
local stationPrompts = {}   -- [typeKey] = { group, prompt }
local stationRest = {}      -- ["typeKey#index"] = GetGameTimer() until which it rests

local function buildStations()
    local spots = {}
    for _, key in ipairs(AlertTypeKeys()) do
        local def = AlertType(key)
        for i, st in ipairs(type(def.stations) == 'table' and def.stations or {}) do
            if st.coords and st.blip then
                stationBlips[#stationBlips + 1] = CoordBlip(st.coords, 1480984695, 0.2, st.blipName or key)
            end
            if st.coords and def.stationPrompt then
                spots[#spots + 1] = { key = key, index = i, coords = st.coords, reach = tonumber(def.promptDistance) or 6.0 }
            end
        end
    end
    return spots
end

local function promptFor(key)
    local p = stationPrompts[key]
    if p then return p end
    local group = GetRandomIntInRange(0, 0xffffff)
    p = { group = group, prompt = MakePrompt(group, Config.Keys.stationAlert, L('promptAlert')) }
    stationPrompts[key] = p
    return p
end

CreateThread(function()
    local spots = buildStations()
    if #spots == 0 then return end
    while true do
        local here = GetEntityCoords(PlayerPedId())
        local near = nil
        for _, s in ipairs(spots) do
            if #(here - s.coords) <= s.reach then near = s break end
        end
        if not near then
            Wait(1000)
        else
            local restKey = near.key .. '#' .. near.index
            while #(GetEntityCoords(PlayerPedId()) - near.coords) <= near.reach do
                Wait(0)
                if (stationRest[restKey] or 0) <= GetGameTimer() and not IsDownNow() and not MenuOpen() then
                    local def = AlertType(near.key)
                    local p = promptFor(near.key)
                    ShowGroup(p.group, def.suggestion or near.key)
                    if UiPromptHasStandardModeCompleted(p.prompt, 0) then
                        stationRest[restKey] = GetGameTimer() + 10000
                        ExecuteCommand(def.command)
                    end
                else
                    Wait(250)
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- On-screen lines
---------------------------------------------------------------------------
-- each line: { text, red = the "type /..." hint, big = the main status line }
local function currentLines()
    local lines = {}
    local function add(text, red, big) lines[#lines + 1] = { text = text, red = red, big = big } end
    local st, key = caller[MEDICAL_TYPE], MEDICAL_TYPE
    if not st then key, st = next(caller) end
    if st then
        if st.mode == 'nobody' then
            add(L('txtCancelClear', CANCEL), true)
            if key == MEDICAL_TYPE and IsDownNow() then
                add(L('txtNoMedics'), false, true)
                add(InWater() and L('txtInWater') or L('txtOnLand'), false, true)
            else
                add(L('txtNobody'), false, true)
            end
        else
            add(L('txtCancel', CANCEL), true)
            add(st.mode == 'helpComing' and L('txtComing') or L('txtSent'), false, true)
        end
    end
    if incoming then
        add(L('txtIncoming'))
        add(L('txtIncomingHow'), true)
    end
    if responding then
        add(L('txtResponding'))
        add(L('txtRespondingStop', CANCEL), true)
    end
    return lines
end

-- top-left, western font, as the alerts have always looked
local TX <const>, TY <const>, STEP <const> = 0.15, 0.13, 0.03
CreateThread(function()
    while true do
        local lines = currentLines()
        if #lines == 0 then
            Wait(1000)
        else
            Wait(0)
            for i, l in ipairs(lines) do
                local y = TY + (i - 1) * STEP
                if l.big then
                    ScreenText(l.text, TX, y, 0.5, 0.3)
                else
                    ScreenText((l.red and '~e~' or '') .. l.text, TX, y, 0.3)
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Start / stop
---------------------------------------------------------------------------
AddEventHandler('onClientResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    clearAll()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    stopResponding()
    if decision then
        unmark(decision)
        for _, p in ipairs(decision.prompts or {}) do UiPromptDelete(p) end
    end
    for _, b in ipairs(stationBlips) do DropBlip(b) end
    for _, p in pairs(stationPrompts) do UiPromptDelete(p.prompt) end
    ClearRoute()
end)
