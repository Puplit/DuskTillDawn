-- pup_hideouts | client core: state, server calls, prompts, menus, small helpers

Core = exports.vorp_core:GetCore()

HX = {
    charId   = nil,
    rows     = {},    -- [id] = view sent by the server
    insideId = nil,   -- hideout we are in
    menuOpen = false,
    busy     = false, -- an action is running; no prompts
}

local OWNER <const> = 'pup_hideouts'

----------------------------------------------------------------------------------------------------
-- server calls with a time limit
----------------------------------------------------------------------------------------------------
local seq, pending = 0, {}

-- returns answered(bool), ...values
function HX.call(name, timeoutMs, ...)
    seq = seq + 1
    local id = seq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('pup_hideouts:rpc', name, id, ...)
    SetTimeout(timeoutMs or 5000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ n = 0, timeout = true })
        end
    end)
    local r = Citizen.Await(p)
    if r.timeout then return false end
    return true, table.unpack(r, 1, r.n)
end

RegisterNetEvent('pup_hideouts:rpcReply', function(id, ...)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    p:resolve(table.pack(...))
end)

function HX.send(name, ...) TriggerServerEvent('pup_hideouts:' .. name, ...) end

----------------------------------------------------------------------------------------------------
-- notifications
----------------------------------------------------------------------------------------------------
function HX.tip(text, ms) TriggerEvent('vorp:TipRight', text, ms or 5000) end
function HX.bottom(text, ms) TriggerEvent('vorp:TipBottom', text, ms or 5000) end

----------------------------------------------------------------------------------------------------
-- prompts: one group, two buttons, for the whole resource
----------------------------------------------------------------------------------------------------
local group = GetRandomIntInRange(0, 0xffffff)
local buttons = {}
local shownText = {}

local function makePrompt(key)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', ' '))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

CreateThread(function()
    buttons.primary = makePrompt(Config.Keys.interact)
    buttons.secondary = makePrompt(Config.Keys.secondary)
end)

local function setText(which, label)
    local p = buttons[which]
    if not p then return end
    if label then
        if shownText[which] ~= label then
            shownText[which] = label
            PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', label))
        end
        PromptSetEnabled(p, true)
        PromptSetVisible(p, true)
    else
        PromptSetEnabled(p, false)
        PromptSetVisible(p, false)
    end
end

-- call every frame while the group should show; returns 'primary' | 'secondary' | nil
function HX.prompt(title, primary, secondary)
    if not buttons.primary then return nil end
    setText('primary', primary)
    setText('secondary', secondary)
    PromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', title or ''), 0, 0, 0, 0)
    if primary and PromptHasStandardModeCompleted(buttons.primary) then return 'primary' end
    if secondary and PromptHasStandardModeCompleted(buttons.secondary) then return 'secondary' end
    return nil
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(buttons) do PromptDelete(p) end
end)

----------------------------------------------------------------------------------------------------
-- ink menus (pup-ui). One stack; Esc goes back one level, closes at the top.
----------------------------------------------------------------------------------------------------
local menu = nil -- { spec, parent }

function HX.menu(spec, parent)
    menu = { spec = spec, parent = parent, index = spec.startIndex or 1 }
    HX.menuOpen = true
    local opts = {}
    for i, o in ipairs(spec.options) do
        opts[i] = { label = o.label, description = o.description }
    end
    exports['pup-ui']:OpenInkMenu({ owner = OWNER, title = spec.title or '', subtitle = spec.subtitle, options = opts, startIndex = spec.startIndex })
end

function HX.menuClose()
    local m = menu
    menu = nil
    if m then exports['pup-ui']:HideInkMenu() end
    local root = m
    while root and root.parent do root = root.parent end
    if HX.menuOpen then
        HX.menuOpen = false
        if root and root.spec.onClose then root.spec.onClose() end
        TriggerEvent('pup_hideouts:menuClosed')
    end
end

function HX.menuCurrent() return menu end

-- a page built by a function can be rebuilt from fresh data; build() returning nil means
-- "this page no longer makes sense" and the parent is shown instead
function HX.page(build, parent, startIndex)
    local spec = build()
    if not spec then
        if parent then return HX.page(parent.spec.build or function() return parent.spec end, parent.parent) end
        return HX.menuClose()
    end
    spec.build = build
    spec.startIndex = startIndex or spec.startIndex
    HX.menu(spec, parent)
end

-- rebuild the page on screen about 0.6 s after a change, keeping the cursor row
local refreshQueued = false
function HX.menuRefreshSoon()
    if refreshQueued then return end
    refreshQueued = true
    SetTimeout(600, function()
        refreshQueued = false
        local m = menu
        if not m or not HX.menuOpen or not m.spec.build then return end
        HX.page(m.spec.build, m.parent, m.index)
    end)
end

AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if owner == OWNER and menu then menu.index = index end
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER or not menu then return end
    local o = menu.spec.options[index]
    if o and o.onSelect then
        local cur = menu
        CreateThread(function() o.onSelect(cur) end)
    end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= OWNER or not menu then return end
    local m = menu
    menu = nil
    if m.parent then
        -- the parent becomes current first, so a parent that can no longer be built still
        -- closes through its root (and its onClose runs)
        menu = m.parent
        HX.menuBack(m.parent)
        return
    end
    HX.menuOpen = false
    if m.spec.onClose then m.spec.onClose() end
    TriggerEvent('pup_hideouts:menuClosed')
end)

-- show a page again (rebuilt when it can be); nil closes everything
function HX.menuBack(node)
    if not node then return HX.menuClose() end
    if node.spec.build then HX.page(node.spec.build, node.parent, node.index) else HX.menu(node.spec, node.parent) end
end

-- yes / no confirmation as a child menu; fn runs on yes
function HX.confirm(title, subtitle, parent, fn)
    HX.menu({
        title = title, subtitle = subtitle,
        options = {
            { label = L('yes'), onSelect = function() fn() end },
            { label = L('no'), onSelect = function() HX.menuBack(parent) end },
        },
    }, parent)
end

----------------------------------------------------------------------------------------------------
-- input boxes (pup-ui); gives up after two minutes
----------------------------------------------------------------------------------------------------
local inputWait = nil

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= OWNER or not inputWait then return end
    local p = inputWait
    inputWait = nil
    p:resolve({ values = values })
end)

function HX.input(title, subtitle, fields)
    if inputWait then inputWait:resolve({}) end
    local p = promise.new()
    inputWait = p
    exports['pup-ui']:OpenInput({ owner = OWNER, title = title, subtitle = subtitle, submit = L('confirm'), fields = fields })
    SetTimeout(120000, function() if inputWait == p then inputWait = nil; p:resolve({}) end end)
    local r = Citizen.Await(p)
    return r.values
end

----------------------------------------------------------------------------------------------------
-- minigames (a callback that never comes counts as failure after 3 minutes)
----------------------------------------------------------------------------------------------------
local function await(fn)
    local p = promise.new()
    local done = false
    local ok = pcall(fn, function(result)
        if done then return end
        done = true
        p:resolve({ result })
    end)
    if not ok then return nil end
    SetTimeout(180000, function() if not done then done = true; p:resolve({ nil }) end end)
    return Citizen.Await(p)[1]
end

function HX.skillBar(opts)
    local r = await(function(cb) exports['pup-minigames']:skill_bar(opts, cb) end)
    return r == 'success' or r == 'perfect'
end

-- a skill bar sized from a 1-5 difficulty (Config.SkillBar tuning)
function HX.skillBarLevel(level, hint)
    local S = Config.SkillBar
    level = math.max(1, math.min(5, level))
    local zone = math.max(S.minZone or 14, (S.baseZone or 34) - (S.zonePerStep or 1.5) * level)
    local speed = math.min(S.maxSpeed or 0.55, (S.baseSpeed or 0.18) + (S.speedStep or 0.02) * level)
    return HX.skillBar({
        style = 'default', orientation = 1, area_size = zone, perfect_area_size = S.perfectZone or 6,
        speed = speed, moving_icon = false, hint = hint,
    })
end

function HX.safeCrack(level)
    return await(function(cb) exports['pup-minigames']:safe_crack({ style = 'default', difficulty = level }, cb) end) == true
end

function HX.buttonMash(level)
    return await(function(cb) exports['pup-minigames']:button_mash({ style = 'default', difficulty = level }, cb) end) == true
end

----------------------------------------------------------------------------------------------------
-- streaming and drawing helpers
----------------------------------------------------------------------------------------------------
function HX.loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil end
        Wait(50)
    end
    return hash
end

function HX.loadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(50)
    end
    return true
end

function HX.text3d(coords, text)
    exports['pup-ui']:Draw3DText(coords, text)
end

function HX.ped() return PlayerPedId() end
function HX.pos() return GetEntityCoords(PlayerPedId()) end

function HX.fade(out)
    if out then
        DoScreenFadeOut(500)
        local t = GetGameTimer() + 3000
        while not IsScreenFadedOut() and GetGameTimer() < t do Wait(10) end
    else
        DoScreenFadeIn(500)
    end
end

function HX.teleport(c, heading)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
    if heading then SetEntityHeading(ped, heading) end
    local t = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(10) end
end

function HX.progress(label, ms)
    pcall(function() exports['pup-ui']:Progress({ label = label, duration = ms }) end)
end

function HX.progressCancel()
    pcall(function() exports['pup-ui']:ProgressCancel() end)
end

-- job and staff / police standing as the server last reported them (HX.refreshFlags, door.lua);
-- only used to decide what to show - the server re-checks every action
function HX.job() return HX.flags and HX.flags.job or nil end
function HX.isStaff() return HX.flags ~= nil and HX.flags.staff == true end
function HX.isPolice() return HX.flags ~= nil and HX.flags.police == true end

function HX.dead() return IsEntityDead(PlayerPedId()) or IsPedDeadOrDying(PlayerPedId(), true) end

-- town the player stands in (zone type 1 = town)
function HX.inBlockedTown(c)
    if not Config.Hideouts.townBlock then return false end
    local town = Citizen.InvokeNative(0x43AD8FC02B429D33, c.x, c.y, c.z, 1) -- GET_MAP_ZONE_AT_COORDS
    if not town or town == 0 then return false end
    for _, name in ipairs(Config.Hideouts.blockedTowns) do
        if town == joaat(name) or town == joaat(name:lower()) then return true end
    end
    return false
end
