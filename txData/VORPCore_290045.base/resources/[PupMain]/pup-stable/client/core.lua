-- pup-stable | client core: requests to the server, lists of own horses and wagons, HUD hiding

RES = GetCurrentResourceName()
Me = {
    horses = {}, wagons = {}, comps = {}, canColor = false, job = nil,
    horsesLoaded = false, wagonsLoaded = false, loading = false,
}

function Debug(...) if Config.General.debug then print('[pup-stable]', ...) end end

local warned = {}
function WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print('^3[pup-stable]^7 ' .. msg)
end

function Tip(msg, ms) if msg and msg ~= '' then TriggerEvent('vorp:TipRight', msg, ms or 4000) end end

function Running(res) return GetResourceState(res) == 'started' end

------------------------------------------------------------------------------
-- request channel
------------------------------------------------------------------------------
local pending, seq = {}, 0

RegisterNetEvent('pup-stable:reply', function(id, ...)
    local p = pending[id]
    if p then pending[id] = nil; p:resolve(table.pack(...)) end
end)

-- blocking call; returns what the server returned, or false on timeout
function Call(name, ...)
    seq = seq + 1
    local id = seq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('pup-stable:rpc', id, name, ...)
    SetTimeout(10000, function()
        if pending[id] then pending[id] = nil; p:resolve({ false, n = 1 }) end
    end)
    local res = Citizen.Await(p)
    return table.unpack(res, 1, res.n)
end

-- call, and show a refusal message if one came back
function CallTip(name, ...)
    local res = table.pack(Call(name, ...))
    if not res[1] and type(res[2]) == 'string' then Tip(res[2]) end
    return table.unpack(res, 1, res.n)
end

------------------------------------------------------------------------------
-- my horses and wagons
------------------------------------------------------------------------------
function RefreshHorses()
    if Me.loading then
        local deadline = GetGameTimer() + 10000
        while Me.loading and GetGameTimer() < deadline do Wait(50) end
        return Me.horsesLoaded
    end
    Me.loading = true
    local ok, horses, comps, canColor, job = Call('myHorses')
    Me.loading = false
    if not ok then return false end
    local map = {}
    for _, h in ipairs(horses or {}) do map[h.id] = h end
    Me.horses, Me.comps, Me.canColor, Me.job = map, comps or {}, canColor == true, job
    Me.horsesLoaded = true
    TriggerEvent('pup-stable:horsesUpdated')
    return true
end

function RefreshWagons()
    local ok, wagons = Call('myWagons')
    if not ok then return false end
    local map = {}
    for _, w in ipairs(wagons or {}) do map[w.id] = w end
    Me.wagons, Me.wagonsLoaded = map, true
    return true
end

function SetHorse(payload)
    if type(payload) == 'table' and payload.id then Me.horses[payload.id] = payload end
end

function SetWagon(payload)
    if type(payload) == 'table' and payload.id then Me.wagons[payload.id] = payload end
end

function FavouriteHorse()
    for _, h in pairs(Me.horses) do if h.favourite then return h end end
    return nil
end

local function waitFor(flagKey, refresh, wait, force)
    if force or not Me[flagKey] then
        if wait == false then
            CreateThread(refresh)
        else
            refresh()
        end
    end
    if wait ~= false then
        local deadline = GetGameTimer() + 10000
        while not Me[flagKey] and GetGameTimer() < deadline do Wait(100) end
    end
end

exports('getMyHorses', function(wait, forceRefresh)
    waitFor('horsesLoaded', RefreshHorses, wait, forceRefresh == true)
    return Me.horsesLoaded and Me.horses or {}
end)

exports('getMyWagons', function(wait, forceRefresh)
    waitFor('wagonsLoaded', RefreshWagons, wait, forceRefresh == true)
    return Me.wagonsLoaded and Me.wagons or {}
end)

RegisterNetEvent('pup-stable:listChanged', function(which)
    if which == 'wagons' then CreateThread(RefreshWagons) else CreateThread(RefreshHorses) end
end)

-- vorp_admin world cleanup: a swept horse or wagon is put away (the server marks it
-- in and sends listChanged); drop the local links so it can be called again
RegisterNetEvent('vorp_admin:worldCleanupDone', function()
    for id, rec in pairs(Horse.peds) do
        if not DoesEntityExist(rec.ped) then
            Horse.forget(id, false)
            if Me.horses[id] then Me.horses[id].isOut = false end
        end
    end
    local c = Wagon.cur
    if c and not DoesEntityExist(c.veh) then
        if Me.wagons[c.id] then Me.wagons[c.id].isOut = false end
        Wagon.forget(false)
    end
end)

RegisterNetEvent('pup-stable:colorPermission', function(can) Me.canColor = can == true end)

------------------------------------------------------------------------------
-- keys: raw keybinds stay quiet while typing somewhere
------------------------------------------------------------------------------
function Typing()
    return IsNuiFocused() or IsPauseMenuActive() or UpdateOnscreenKeyboard() == 0
end

function KeyPressed(key)
    if Typing() then return false end
    return IsControlJustReleased(0, key) or IsDisabledControlJustReleased(0, key)
end

-- edge-detected keys sampled every 40 ms (no per-frame loop while nothing is happening)
Keys = { list = {} }

-- onUp(heldMs) fires on release; onDown() on press. Ignored while typing or with our menu open.
function Keys.on(control, onUp, onDown)
    Keys.list[#Keys.list + 1] = { c = control, up = onUp, down = onDown, held = nil }
end

CreateThread(function()
    while true do
        Wait(40)
        local blocked = Typing() or (Ui and Ui.open)
        for _, k in ipairs(Keys.list) do
            local pressed = not blocked and (IsControlPressed(0, k.c) or IsDisabledControlPressed(0, k.c))
            if pressed and not k.held then
                k.held = GetGameTimer()
                if k.down then CreateThread(k.down) end
            elseif not pressed and k.held then
                local ms = GetGameTimer() - k.held
                k.held = nil
                if not blocked and k.up then CreateThread(function() k.up(ms) end) end
            end
        end
    end
end)

------------------------------------------------------------------------------
-- HUD hiding: only what we hid gets restored
------------------------------------------------------------------------------
local hudHidden = false

function HideHud()
    if hudHidden then return end
    hudHidden = true
    local ok = pcall(function() exports.vorp_core:SetAllUI(false) end)
    if not ok then
        WarnOnce('setallui', 'vorp_core SetAllUI missing: hiding the HUD by hand')
        DisplayRadar(false)
        DisplayHud(false)
        TriggerEvent('fred_hud:setVisible', false)
        TriggerEvent('pup-displayrange', false)
        TriggerEvent('vorp:showUi', false)
    end
end

function ShowHud()
    if not hudHidden then return end
    hudHidden = false
    local ok = pcall(function() exports.vorp_core:SetAllUI(true) end)
    if not ok then
        DisplayRadar(true)
        DisplayHud(true)
        TriggerEvent('fred_hud:setVisible', true)
        TriggerEvent('pup-displayrange', true)
        TriggerEvent('vorp:showUi', true)
    end
end

-- pup-ui's panic button: release our latch so nothing hands the HUD back later
AddEventHandler('pup-ui:HideAllUI', function()
    hudHidden = false
    TriggerEvent('pup-stable:closeAll')
end)

------------------------------------------------------------------------------
-- pup-ui text input and list menu
------------------------------------------------------------------------------
local inputWait, inputSeq = nil, 0

-- blocking text input; returns the trimmed string ('' when left empty) or nil when cancelled
function Ask(title, maxLen, kind, default)
    if not Running('pup-ui') then WarnOnce('pupui', 'pup-ui is not running: text input unavailable') return nil end
    inputSeq = inputSeq + 1
    local token = RES .. ':input:' .. inputSeq
    local p = promise.new()
    inputWait = { token = token, p = p }
    exports['pup-ui']:OpenInput({
        owner = token, title = title, submit = L('confirm'),
        fields = { { label = title, type = kind or 'text', maxlength = maxLen or 50, required = false, default = default } },
    })
    local values = Citizen.Await(p)
    -- nil = cancelled; '' = submitted empty
    if type(values) ~= 'table' then return nil end
    return U.trim(tostring(values[1] or ''))
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if inputWait and owner == inputWait.token then
        local p = inputWait.p
        inputWait = nil
        p:resolve(values)
    end
end)

local listWait, listSeq = nil, 0

-- blocking list menu; returns the chosen option's value or nil
function Choose(title, subtitle, options)
    if not Running('pup-ui') then return nil end
    listSeq = listSeq + 1
    local token = RES .. ':list:' .. listSeq
    local p = promise.new()
    listWait = { token = token, p = p, options = options }
    -- pup-ui prints an option's `value` as right-hand text, so values stay on this side
    local shown = {}
    for i, o in ipairs(options) do
        local c = {}
        for k, v in pairs(o) do if k ~= 'value' then c[k] = v end end
        shown[i] = c
    end
    exports['pup-ui']:OpenListMenu({ owner = token, title = title, subtitle = subtitle, options = shown, keyboard = true })
    return Citizen.Await(p)
end

local function settleList(token, value)
    if listWait and listWait.token == token then
        local p = listWait.p
        listWait = nil
        p:resolve(value)
    end
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if listWait and owner == listWait.token then
        local opt = listWait.options[tonumber(index) or 0]
        settleList(owner, opt and opt.value)
    end
end)
AddEventHandler('pup-ui:client:listBack', function(owner) settleList(owner, nil) end)
AddEventHandler('pup-ui:client:listClosed', function(owner)
    if listWait and (owner == nil or owner == listWait.token) then settleList(listWait.token, nil) end
end)

------------------------------------------------------------------------------
-- misc helpers
------------------------------------------------------------------------------
function LoadModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + (timeout or 8000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(10)
    end
    return hash
end

function LoadDict(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

function NetIdOf(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not NetworkGetEntityIsNetworked(ent) then return nil end
    return NetworkGetNetworkIdFromEntity(ent)
end

function StableIdAt(coords, extra)
    for id, s in pairs(Config.Stables) do
        if U.inPoly(s.polygon, coords.x, coords.y) and math.abs(coords.z - s.location.z) <= (extra or 3.0) then return id end
    end
    return nil
end

function InTown(coords, list)
    local zone = N.townAt(coords)
    for _, name in ipairs(list or {}) do
        if zone == joaat(name) then return true end
    end
    return false
end

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    ShowHud()
    N.deleteAllPrompts()
end)
