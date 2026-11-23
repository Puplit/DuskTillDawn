-- pup_railroad | client core: server requests, state, menus, input boxes, prompts, clean-up

local L <const> = Rail.L
local OWNER <const> = GetCurrentResourceName()

Cl = {
    out = {},      -- trains out, as sent by the server
    byNet = {},    -- [netId] = entry
    byId = {},     -- [trainId] = entry
    job = nil,
    cash = 0,
    busy = false,  -- a railroad action is running
    menuOpen = false,
    shopOpen = false,
    inputOpen = false,
    route = nil,   -- running delivery
    lastStation = nil,
    trainBlips = {}, -- [trainId] = blip (trains this client brought out)
}

--------------------------------------------------------------------------------
-- server requests
--------------------------------------------------------------------------------
local pending, seq = {}, 0

--- ask the server; returns the result table, or nil when no answer came in time
function Cl.call(name, timeoutMs, ...)
    seq = seq + 1
    local id = seq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('pup_railroad:call', name, id, ...)
    SetTimeout(timeoutMs, function()
        if pending[id] then
            pending[id] = nil
            p:resolve(false)
        end
    end)
    local result = Citizen.Await(p)
    if type(result) ~= 'table' then return nil end
    return result
end

--- tell the server something; no answer expected
function Cl.tell(name, ...)
    TriggerServerEvent('pup_railroad:call', name, nil, ...)
end

RegisterNetEvent('pup_railroad:reply', function(id, result)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    p:resolve(type(result) == 'table' and result or { ok = false })
end)

--------------------------------------------------------------------------------
-- natives: the named wrapper when this build has it, otherwise the raw hash.
-- Value-returning callers pass Citizen.ResultAsInteger()/ResultAsFloat() last;
-- named wrappers ignore the extra argument.
--------------------------------------------------------------------------------
function Cl.native(name, hash, ...)
    local fn = _G[name]
    if type(fn) == 'function' then return fn(...) end
    return Citizen.InvokeNative(hash, ...)
end

local RI <const> = Citizen.ResultAsInteger

Cl.train = {
    cars      = function(cfg) return Cl.native('GetNumCarsFromTrainConfig', 0x635423D55CA84FC8, cfg, RI()) end,
    carModel  = function(cfg, i) return Cl.native('GetTrainModelFromTrainConfigByCarIndex', 0x8DF5F6A19F99F0D5, cfg, i, RI()) end,
    create    = function(cfg, x, y, z, dir) return Cl.native('CreateMissionTrain', 0xC239DBD9A57D2A71, cfg, x, y, z, dir, false, true, false, RI()) end,
    setSpeed  = function(t, s) Cl.native('SetTrainSpeed', 0xDFBA6BBFF7CCAFBB, t, s + 0.0) end,
    setCruise = function(t, s) Cl.native('SetTrainCruiseSpeed', 0x01021EB2E96B793C, t, s + 0.0) end,
    setMax    = function(t, s) Cl.native('SetTrainMaxSpeed', 0x9F29999DFDF2AEB8, t, s + 0.0) end,
    delete    = function(t)
        if type(_G.DeleteMissionTrain) == 'function' then return DeleteMissionTrain(t) end
        Citizen.InvokeNative(0x0D3630FB07E8B570, Citizen.PointerValueIntInitialized(t))
    end,
}

--------------------------------------------------------------------------------
-- notices and checks
--------------------------------------------------------------------------------
function Cl.notify(msg)
    TriggerEvent('vorp:TipRight', msg, 4000)
end

function Cl.officeSilent()
    Cl.notify(L('office_silent'))
end

function Cl.incapacitated(ped)
    ped = ped or PlayerPedId()
    if IsEntityDead(ped) then return true end
    if Citizen.InvokeNative(0x3AA24CCC0D451379, ped, Citizen.ResultAsInteger()) ~= 0 then return true end -- hogtied
    if Citizen.InvokeNative(0x74E559B3BC910685, ped, Citizen.ResultAsInteger()) ~= 0 then return true end -- cuffed
    return false
end

-- no railroad menu, shop or input box open and no railroad action running
function Cl.idle()
    return not Cl.busy and not Cl.menuOpen and not Cl.shopOpen and not Cl.inputOpen
end

function Cl.isTrain(veh)
    return veh and veh ~= 0 and DoesEntityExist(veh) and IsThisModelATrain(GetEntityModel(veh))
end

function Cl.entryForVehicle(veh)
    if not veh or veh == 0 or not NetworkGetEntityIsNetworked(veh) then return nil end
    return Cl.byNet[NetworkGetNetworkIdFromEntity(veh)]
end

function Cl.vehicleForEntry(entry)
    if not entry or not entry.netId or not NetworkDoesNetworkIdExist(entry.netId) then return nil end
    local veh = NetworkGetEntityFromNetworkId(entry.netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
    return nil
end

--------------------------------------------------------------------------------
-- ink menus (pup-ui); rows: { label, description, action = fn | nil }
--------------------------------------------------------------------------------
local current = nil

function Cl.openMenu(def)
    current = def
    Cl.menuOpen = true
    local options = {}
    for i = 1, #def.rows do
        options[i] = { label = def.rows[i].label, description = def.rows[i].description }
    end
    exports['pup-ui']:OpenInkMenu({ owner = OWNER, title = def.title, subtitle = def.subtitle, options = options })
end

--- close the railroad menu (if one is open) and run its onClose
function Cl.closeMenu()
    local def = current
    if not def then return end
    current = nil
    Cl.menuOpen = false
    exports['pup-ui']:HideInkMenu()
    if def.onClose then def.onClose() end
end

-- pup-ui has one ink menu at a time. Another resource opening its own replaces ours
-- without an inkClose for us; the first event carrying a foreign owner tells us so.
local function foreignOwner(owner)
    if owner == OWNER or not current then return false end
    local def = current
    current = nil
    Cl.menuOpen = false
    if def.onClose then def.onClose() end
    return true
end

AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if foreignOwner(owner) or owner ~= OWNER or not current then return end
    current.index = index
end)

AddEventHandler('pup-ui:client:inkChange', function(index, _, owner)
    if foreignOwner(owner) or owner ~= OWNER or not current then return end
    current.index = index
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if foreignOwner(owner) or owner ~= OWNER or not current then return end
    local row = current.rows[Rail.int(index) or 0]
    if row and row.action then CreateThread(row.action) end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if foreignOwner(owner) or owner ~= OWNER then return end
    local def = current
    current = nil
    Cl.menuOpen = false
    if def and def.onClose then def.onClose() end
end)

--------------------------------------------------------------------------------
-- input boxes: one pending at a time, two-minute limit; nil = cancelled
--------------------------------------------------------------------------------
local inputSeq, inputPending = 0, nil

local function settleInput(values)
    local p = inputPending
    if not p then return end
    inputPending = nil
    Cl.inputOpen = false
    p.promise:resolve(values or false)
end

function Cl.ask(title, fields)
    settleInput(nil) -- a newer box cancels the older one
    inputSeq = inputSeq + 1
    local token = OWNER .. ':input:' .. inputSeq
    local entry = { token = token, promise = promise.new() }
    inputPending = entry
    Cl.inputOpen = true
    local opened = exports['pup-ui']:OpenInput({ owner = token, title = title, submit = L('confirm'), fields = fields })
    if not opened then settleInput(nil) end
    SetTimeout(Config.Timings.inputTimeout, function()
        if inputPending == entry then settleInput(nil) end
    end)
    local values = Citizen.Await(entry.promise)
    if type(values) ~= 'table' then return nil end
    return values
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if inputPending and owner == inputPending.token then settleInput(values) end
end)

--------------------------------------------------------------------------------
-- native prompts
--------------------------------------------------------------------------------
-- RedM builds name these natives either Prompt*/CreateVarString or UiPrompt*/VarString;
-- take whichever this build provides, falling back to the raw hash.
local function pick(newName, oldName, hash)
    local fn = _G[newName] or _G[oldName]
    if type(fn) == 'function' then return fn end
    return function(...) return Citizen.InvokeNative(hash, ...) end
end

local N <const> = {
    begin      = pick('UiPromptRegisterBegin', 'PromptRegisterBegin', 0x04F97DE45A519419),
    control    = pick('UiPromptSetControlAction', 'PromptSetControlAction', 0xB5352B7494A08258),
    text       = pick('UiPromptSetText', 'PromptSetText', 0x5DD02A8318420DD7),
    enabled    = pick('UiPromptSetEnabled', 'PromptSetEnabled', 0x8A0FB4D03A630D21),
    visible    = pick('UiPromptSetVisible', 'PromptSetVisible', 0x71215ACCFDE075EE),
    standard   = pick('UiPromptSetStandardMode', 'PromptSetStandardMode', 0xCC6656799977741B),
    group      = pick('UiPromptSetGroup', 'PromptSetGroup', 0x2F11D3A254169EA4),
    finish     = pick('UiPromptRegisterEnd', 'PromptRegisterEnd', 0xF7AA2696A22AD8B9),
    completed  = pick('UiPromptHasStandardModeCompleted', 'PromptHasStandardModeCompleted', 0xC92AC953F0A982AE),
    active     = pick('UiPromptSetActiveGroupThisFrame', 'PromptSetActiveGroupThisFrame', 0xC65A45D4453C2627),
    delete     = pick('UiPromptDelete', 'PromptDelete', 0x00EDE88D4D13CF59),
    varString  = pick('VarString', 'CreateVarString', 0xFA925AC00EB830B9),
}

function Cl.literal(text)
    return N.varString(10, 'LITERAL_STRING', tostring(text))
end

function Cl.newGroup()
    return GetRandomIntInRange(0, 0xFFFFFF)
end

function Cl.newPrompt(control, text, group)
    local p = N.begin()
    N.control(p, control)
    N.text(p, Cl.literal(text))
    N.enabled(p, true)
    N.visible(p, true)
    N.standard(p, true)
    if group then N.group(p, group, 0) end
    N.finish(p)
    return { handle = p, text = text }
end

function Cl.promptText(prompt, text)
    if prompt.text == text then return end
    prompt.text = text
    N.text(prompt.handle, Cl.literal(text))
end

function Cl.promptShow(prompt, shown)
    shown = shown and true or false
    if prompt.shown == shown then return end
    prompt.shown = shown
    N.visible(prompt.handle, shown)
    N.enabled(prompt.handle, shown)
end

function Cl.promptPressed(prompt)
    return prompt.shown ~= false and N.completed(prompt.handle) and true or false
end

function Cl.showGroup(group, title)
    N.active(group, Cl.literal(title), 0, 0, 0, 0)
end

function Cl.deletePrompt(prompt)
    if prompt and prompt.handle then N.delete(prompt.handle) end
end

--------------------------------------------------------------------------------
-- blips
--------------------------------------------------------------------------------
function Cl.coordBlip(sprite, coords, scale, name)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z) -- BLIP_ADD_FOR_COORDS
    SetBlipSprite(blip, sprite, true)
    SetBlipScale(blip, scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, name) -- set blip name
    return blip
end

function Cl.entityBlip(sprite, entity, scale, name)
    local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, 1664425300, entity) -- BLIP_ADD_FOR_ENTITY
    SetBlipSprite(blip, sprite, true)
    SetBlipScale(blip, scale)
    if name then Citizen.InvokeNative(0x9CB1A1623062F402, blip, name) end
    return blip
end

function Cl.removeBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

--------------------------------------------------------------------------------
-- trains out (from the server)
--------------------------------------------------------------------------------
local listeners = {}
function Cl.onListChanged(fn) listeners[#listeners + 1] = fn end

local function setList(list)
    Cl.out, Cl.byNet, Cl.byId = {}, {}, {}
    for i = 1, #(list or {}) do
        local e = list[i]
        Cl.out[#Cl.out + 1] = e
        if e.netId then Cl.byNet[e.netId] = e end
        if e.id then Cl.byId[e.id] = e end
    end
    -- a train's blip goes when the train leaves the list
    for id, blip in pairs(Cl.trainBlips) do
        if not Cl.byId[id] then
            Cl.removeBlip(blip)
            Cl.trainBlips[id] = nil
        end
    end
    for i = 1, #listeners do listeners[i]() end
end

RegisterNetEvent('pup_railroad:outList', function(list)
    if type(list) ~= 'table' then return end
    setList(list)
end)

local changeListeners = {}
function Cl.onTrainChanged(fn) changeListeners[#changeListeners + 1] = fn end

RegisterNetEvent('pup_railroad:trainChanged', function(entry)
    if type(entry) ~= 'table' or not entry.id then return end
    local old = Cl.byId[entry.id]
    if not old then return end
    for k, v in pairs(entry) do old[k] = v end
    for i = 1, #changeListeners do changeListeners[i](old) end
end)

--------------------------------------------------------------------------------
-- sign-in
--------------------------------------------------------------------------------
function Cl.signIn()
    local r = Cl.call('hello', 8000)
    if not r or not r.ok then return end
    Cl.job = r.job
    setList(r.list or {})
    if Cl.applySwitches then Cl.applySwitches(r.switches or {}) end
end

CreateThread(function()
    Wait(2000)
    Cl.signIn()
end)

--------------------------------------------------------------------------------
-- resource stop clean-up (each file adds its own step)
--------------------------------------------------------------------------------
local cleanups = {}
function Cl.onCleanup(fn) cleanups[#cleanups + 1] = fn end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = 1, #cleanups do pcall(cleanups[i]) end
    local ped = PlayerPedId()
    if Cl.busy then ClearPedTasks(ped) end -- the repair/upgrade scenario
    FreezeEntityPosition(ped, false)
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(500) end
    pcall(function() exports['pup-ui']:ProgressCancel() end)
    if current then
        current = nil
        Cl.menuOpen = false
        pcall(function() exports['pup-ui']:HideInkMenu() end)
    end
    if Cl.shopOpen then
        Cl.shopOpen = false
        pcall(function() exports['pup-ui']:HideShop() end)
    end
    for id, blip in pairs(Cl.trainBlips) do
        Cl.removeBlip(blip)
        Cl.trainBlips[id] = nil
    end
end)
