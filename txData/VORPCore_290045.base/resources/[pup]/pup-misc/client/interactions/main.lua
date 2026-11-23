-- pup-misc / interactions | press the key near furniture to sit, lie down, play piano, bathe or dance
-- Client only: no server part, no items, nothing saved.

local U     <const> = InteractionsUtil
local CFG   <const> = InteractionsConfig
local OWNER <const> = 'pup-misc:interactions'

local CATEGORY_ORDER <const> = { 'sit', 'rest', 'piano', 'bathe', 'dance' }

local function setting(group, key, default)
    local g = CFG[group]
    local v = g and g[key]
    if v == nil then return default end
    return v
end

local function interactKey() return setting('Keys', 'interact', 0xD8F73058) end

local function L(key)
    local t = InteractionsLocale
    return (t and t[key]) or key
end

local function actionLabel(key)
    local t = InteractionsLocale and InteractionsLocale.actions
    return (t and t[key]) or key
end

local function log(msg, ...)
    print(('^3[pup-misc/interactions]^7 ' .. msg):format(...))
end

-------------------------------------------------------------------------------
-- STATE
-------------------------------------------------------------------------------
local menu = nil          -- the open menu: its options, grouping and the rows on screen
local active = nil        -- the running interaction
local origin = nil        -- where the player stood before the first interaction started
local cooldownUntil = 0
local slowBlock = false   -- dead or in combat, refreshed once a second
local nextToken = 0

-------------------------------------------------------------------------------
-- MODEL INDEX (built once from the config)
-------------------------------------------------------------------------------
local byModel, wideSet, filletSet, searchRadius = nil, nil, nil, nil

local function hashSet(list)
    local set = {}
    for _, m in ipairs(list or {}) do
        local h = U.hash(m)
        if h then set[h] = true end
    end
    return set
end

local function buildIndex()
    byModel, searchRadius = {}, {}
    for _, e in ipairs(CFG.Interactions or {}) do
        if type(e.objects) == 'table' then
            local seen = {}
            for _, m in ipairs(e.objects) do
                local h = U.hash(m)
                if h and not seen[h] then
                    seen[h] = true
                    byModel[h] = byModel[h] or {}
                    byModel[h][#byModel[h] + 1] = e
                    local r = e.radius or 1.5
                    if (searchRadius[h] or 0) < r then searchRadius[h] = r end
                end
            end
        end
    end
    local models = CFG.Models or {}
    wideSet = hashSet(models.seatWide)
    filletSet = hashSet(models.filletSeats)
    if setting('Fillet', 'enabled', false) then
        local r = setting('Fillet', 'radius', 1.5)
        for h in pairs(filletSet) do
            if (searchRadius[h] or 0) < r then searchRadius[h] = r end
        end
    end
end

-------------------------------------------------------------------------------
-- SCAN: everything the player could do from where they stand
-------------------------------------------------------------------------------
local function nearbyObjects(me)
    local found = {}
    for _, obj in ipairs(GetGamePool('CObject')) do
        local h = U.hash(GetEntityModel(obj))
        if h and searchRadius[h] and #(GetEntityCoords(obj) - me) <= searchRadius[h] then
            found[obj] = h
        end
    end
    -- some map furniture may not sit in the pool, so also ask for the closest of each known model
    for h, r in pairs(searchRadius) do
        local obj = GetClosestObjectOfType(me.x, me.y, me.z, r, U.signed(h), false, false, false)
        if obj and obj ~= 0 and not found[obj] then found[obj] = h end
    end
    return found
end

local function typeName(category, model, side)
    if category == 'piano' then return L('typePiano') end
    if category == 'rest' then return L('typeBed') end
    if category == 'bathe' then return L('typeBath') end
    if category == 'dance' then return L('typeDance') end
    if (model and wideSet[model]) or side then return L('typeBench') end
    return L('typeChair')
end

local function sideName(side)
    if side == 'left' then return L('sideLeft') end
    if side == 'right' then return L('sideRight') end
    return side
end

local function collect()
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    local options, spots, taken = {}, {}, {}
    local filletOn = setting('Fillet', 'enabled', false)
    local filletRadius = setting('Fillet', 'radius', 1.5)
    local filletNear = false

    local function spotFor(key, fields)
        local s = spots[key]
        if not s then
            fields.key = key
            fields.name = typeName(fields.category, fields.model, fields.side)
            spots[key] = fields
            s = fields
        end
        return s
    end

    local function offer(entry, spot)
        if not U.fits(entry.ped, ped) then return end
        local function push(kind, item, key)
            if not U.fits(item.ped, ped) then return end
            -- the same action on the same spot from two overlapping entries shows once
            local id = spot.key .. '|' .. key
            if taken[id] then return end
            taken[id] = true
            options[#options + 1] = {
                kind = kind, item = item, entry = entry, spot = spot,
                label = actionLabel(key), dist = spot.dist, category = spot.category,
            }
        end
        for _, sc in ipairs(entry.scenarios or {}) do
            if type(sc.scenario) == 'string' then push('scenario', sc, sc.scenario) end
        end
        for _, an in ipairs(entry.animations or {}) do
            if type(an.parts) == 'table' then
                push('layered', an, an.id or 'anim')
            elseif type(an.dict) == 'string' and type(an.clip) == 'string' then
                push('anim', an, an.id or an.clip)
            end
        end
    end

    -- props
    for obj, h in pairs(nearbyObjects(me)) do
        local d = #(GetEntityCoords(obj) - me)
        if filletOn and filletSet[h] and d <= filletRadius then filletNear = true end
        for _, e in ipairs(byModel[h] or {}) do
            if d <= (e.radius or 1.5) then
                local cat = e.category or 'sit'
                local key = ('obj:%d:%s:%s'):format(obj, e.side or '', cat)
                offer(e, spotFor(key, { obj = obj, model = h, side = e.side, dist = d, category = cat }))
            end
        end
    end

    -- world spots and dance
    for i, e in ipairs(CFG.Interactions or {}) do
        if e.anywhere then
            if setting('Dance', 'anywhere', true) ~= false then
                local cat = e.category or 'dance'
                offer(e, spotFor('here:' .. i, { here = true, dist = 0.0, category = cat }))
            end
        elseif e.objects == nil and e.x and e.y and e.z then
            local d = #(vector3(e.x, e.y, e.z) - me)
            if d <= (e.radius or 2.0) then
                local cat = e.category or 'bathe'
                offer(e, spotFor('spot:' .. i, { fixed = true, dist = d, category = cat, side = e.side }))
            end
        end
    end

    table.sort(options, function(a, b)
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.label < b.label
    end)
    return options, filletNear
end

-- options -> categories -> spots, keeping the nearest-first order
local function group(options)
    local cats, byId = {}, {}
    for _, opt in ipairs(options) do
        local c = byId[opt.category]
        if not c then
            c = { id = opt.category, opts = {}, spots = {}, spotByKey = {} }
            byId[opt.category] = c
        end
        c.opts[#c.opts + 1] = opt
        local s = c.spotByKey[opt.spot.key]
        if not s then
            s = { spot = opt.spot, opts = {} }
            c.spotByKey[opt.spot.key] = s
            c.spots[#c.spots + 1] = s
        end
        s.opts[#s.opts + 1] = opt
    end
    -- fixed order first, then anything the owner added
    local known = {}
    for _, id in ipairs(CATEGORY_ORDER) do
        known[id] = true
        if byId[id] then cats[#cats + 1] = byId[id] end
    end
    for _, opt in ipairs(options) do
        local id = opt.category
        if not known[id] then
            known[id] = true
            cats[#cats + 1] = byId[id]
        end
    end
    return cats
end

-------------------------------------------------------------------------------
-- MENU
-------------------------------------------------------------------------------
local function releasePlayer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
end

local function closeMenu(hide)
    if not menu then return end
    menu = nil
    if hide then pcall(function() exports['pup-ui']:HideListMenu() end) end
    if not active then releasePlayer() end
end

local function openList(title, subtitle, options)
    local ok = pcall(function()
        exports['pup-ui']:OpenListMenu({
            owner = OWNER, title = title, subtitle = subtitle, options = options, keyboard = true,
        })
    end)
    if not ok then closeMenu(false) end
end

local function catText(id)
    local key = 'cat' .. id:gsub('^%l', string.upper)
    local t = InteractionsLocale or {}
    return t[key] or id, t[key .. 'Desc'] or ''
end

local function spotDesc(spot)
    if spot.here then return L('hereDesc') end
    local dist = L('distanceAway'):format(spot.dist)
    if spot.side then return L('takeSide'):format(sideName(spot.side)) .. ' ' .. dist end
    return dist
end

local function showCategories()
    local options, rows = {}, {}
    for _, c in ipairs(menu.cats) do
        local label, desc = catText(c.id)
        options[#options + 1] = { label = L('withCount'):format(label, #c.opts), desc = desc }
        rows[#rows + 1] = { kind = 'cat', cat = c }
    end
    if menu.filletNear then
        options[#options + 1] = { label = L('fff'), desc = L('fffDesc') }
        rows[#rows + 1] = { kind = 'fillet' }
    end
    menu.view, menu.rows, menu.cat = 'cats', rows, nil
    openList(L('title'), L('subtitle'), options)
end

local function showActions(cat, s)
    local options, rows = {}, {}
    local desc = spotDesc(s.spot)
    for _, opt in ipairs(s.opts) do
        options[#options + 1] = { label = opt.label, desc = desc }
        rows[#rows + 1] = { kind = 'action', opt = opt }
    end
    menu.view, menu.rows, menu.cat = 'actions', rows, cat
    local title = catText(cat.id)
    openList(title, L('pickAction'), options)
end

local function showSpots(cat)
    if #cat.spots == 1 then return showActions(cat, cat.spots[1]) end
    local options, rows = {}, {}
    for _, s in ipairs(cat.spots) do
        local name = s.spot.name
        if s.spot.side then name = name .. ' - ' .. sideName(s.spot.side) end
        options[#options + 1] = { label = L('withCount'):format(name, #s.opts), desc = spotDesc(s.spot) }
        rows[#rows + 1] = { kind = 'spot', spot = s }
    end
    menu.view, menu.rows, menu.cat = 'spots', rows, cat
    local title = catText(cat.id)
    openList(title, L('pickSeat'), options)
end

-------------------------------------------------------------------------------
-- PLAYING
-------------------------------------------------------------------------------
local function loadDict(dict)
    if not DoesAnimDictExist(dict) then
        log('anim dict does not exist: %s', dict)
        return false
    end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + setting('General', 'animLoadMs', 1000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then
            log('anim dict did not load in time: %s', dict)
            return false
        end
        Wait(10)
    end
    return true
end

-- world position and heading for this option; nil position = play where the player stands
local function placement(opt)
    local e, spot = opt.entry, opt.spot
    if spot.obj then
        if not DoesEntityExist(spot.obj) then return nil, nil, false end
        local p = GetEntityCoords(spot.obj)
        local h = GetEntityHeading(spot.obj)
        local r = math.rad(h)
        local c, s = math.cos(r), math.sin(r)
        local ox, oy = e.x or 0.0, e.y or 0.0
        local pos = vector3(p.x + ox * c - oy * s, p.y + ox * s + oy * c, p.z + (e.z or 0.0))
        return pos, (h + (e.heading or 0.0)) % 360.0, true
    end
    if spot.fixed then
        return vector3(e.x, e.y, e.z), (e.heading or 0.0) % 360.0, true
    end
    return nil, nil, true
end

local function moveTo(ped, a)
    if not a.pos then return end
    SetEntityCoordsNoOffset(ped, a.pos.x, a.pos.y, a.pos.z, false, false, false)
    SetEntityHeading(ped, a.heading)
end

local function playAnim(ped, dict, clip, flag)
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, flag or 1, 0, false, false, false)
end

-- start (or restart) the pose; false = it cannot play
local function play(a)
    local ped = PlayerPedId()
    local opt = a.opt
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)

    if opt.kind == 'scenario' then
        local hash = GetHashKey(opt.item.scenario)
        if a.pos then
            TaskStartScenarioAtPosition(ped, hash, a.pos.x, a.pos.y, a.pos.z, a.heading, -1, false, true, 0, -1.0, false)
        else
            TaskStartScenarioInPlace(ped, hash, -1)
        end
        return true
    end

    if opt.kind == 'anim' then
        local item = opt.item
        if not loadDict(item.dict) then return false end
        if active ~= a then return false end
        moveTo(ped, a)
        playAnim(ped, item.dict, item.clip, 1)
        RemoveAnimDict(item.dict)
        return true
    end

    if opt.kind == 'layered' then
        local parts = opt.item.parts
        for _, part in ipairs(parts) do
            if not loadDict(part.dict) then return false end
        end
        if active ~= a then return false end
        moveTo(ped, a)
        for _, part in ipairs(parts) do
            if (part.delay or 0) > 0 then
                Wait(part.delay)
                if active ~= a then return false end
            end
            playAnim(ped, part.dict, part.clip, part.flag)
        end
        for _, part in ipairs(parts) do RemoveAnimDict(part.dict) end
        return true
    end

    return false
end

local function stillPlaying(a, ped)
    local opt = a.opt
    if opt.kind == 'scenario' then return U.yes(IsPedUsingAnyScenario(ped)) end
    if opt.kind == 'anim' then return U.yes(IsEntityPlayingAnim(ped, opt.item.dict, opt.item.clip, 3)) end
    if opt.kind == 'layered' then
        for _, part in ipairs(opt.item.parts) do
            if U.yes(IsEntityPlayingAnim(ped, part.dict, part.clip, 3)) then return true end
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- GET-UP PROMPT
-------------------------------------------------------------------------------
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local exitPrompt, exitText = nil, nil

local function deletePrompt()
    if exitPrompt then
        PromptDelete(exitPrompt)
        exitPrompt, exitText = nil, nil
    end
end

-- draws the prompt this frame; true once it was pressed
local function promptPressed(text)
    if not exitPrompt then
        exitPrompt = PromptRegisterBegin()
        PromptSetControlAction(exitPrompt, interactKey())
        PromptSetText(exitPrompt, CreateVarString(10, 'LITERAL_STRING', text))
        PromptSetEnabled(exitPrompt, true)
        PromptSetVisible(exitPrompt, true)
        PromptSetStandardMode(exitPrompt, true)
        PromptSetGroup(exitPrompt, promptGroup, 0)
        PromptRegisterEnd(exitPrompt)
        exitText = text
    elseif exitText ~= text then
        PromptSetText(exitPrompt, CreateVarString(10, 'LITERAL_STRING', text))
        exitText = text
    end
    PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', L('promptGroup')))
    return U.yes(PromptHasStandardModeCompleted(exitPrompt))
end

-------------------------------------------------------------------------------
-- GETTING UP
-- stay = true leaves the player where they are (knocked down, or the pose kept failing)
-------------------------------------------------------------------------------
local function standUp(stay)
    local a = active
    if not a then
        closeMenu(true)
        return
    end
    active = nil
    cooldownUntil = GetGameTimer() + setting('General', 'cooldownMs', 750)
    deletePrompt()

    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)

    local back = origin
    origin = nil
    -- a dance never moved the player, so there is nothing to undo
    if not back or stay or a.opt.spot.here then return end

    Wait(100)
    if active then return end
    ped = PlayerPedId()
    -- only step back when the start point is close: another script may have moved the player
    if #(GetEntityCoords(ped) - back.pos) <= setting('General', 'restoreDistance', 5.0) then
        SetEntityCoordsNoOffset(ped, back.pos.x, back.pos.y, back.pos.z, false, false, false)
        SetEntityHeading(ped, back.heading)
    end
end

-------------------------------------------------------------------------------
-- WATCHING A RUNNING INTERACTION
-------------------------------------------------------------------------------
local function retry(a)
    a.busy = true
    CreateThread(function()
        local ok = play(a)
        if active ~= a then return end
        a.busy = false
        a.checkAfter = GetGameTimer() + setting('General', 'startGraceMs', 1500)
        if not ok then standUp(false) end
    end)
end

local function watch(a)
    CreateThread(function()
        local exitLabel = (a.opt.category == 'dance') and L('exitDance') or L('exit')
        local nextCheck = 0
        while active == a do
            Wait(0)
            if promptPressed(exitLabel) then
                standUp(false)
                break
            end
            local now = GetGameTimer()
            if not a.busy and now >= nextCheck then
                nextCheck = now + 250
                local ped = PlayerPedId()
                if setting('General', 'standOnKnockdown', true)
                    and (U.isRagdoll(ped) or U.isOnFire(ped) or U.isFalling(ped)) then
                    standUp(true)
                    break
                end
                if now >= a.checkAfter then
                    if stillPlaying(a, ped) then
                        a.failures = 0
                    elseif now - a.lastTry >= setting('General', 'restartGapMs', 1000) then
                        a.failures = a.failures + 1
                        if a.failures > setting('General', 'restartLimit', 3) then
                            log('%s kept stopping, giving up', a.opt.item.scenario or a.opt.item.id or '?')
                            standUp(false)
                            break
                        end
                        a.lastTry = now
                        retry(a)
                    end
                end
            end
        end
    end)
end

local function begin(a)
    local ped = PlayerPedId()
    if not origin then origin = { pos = GetEntityCoords(ped), heading = GetEntityHeading(ped) } end

    local pos, heading, ok = placement(a.opt)
    if not ok then
        standUp(false)
        return
    end
    a.pos, a.heading = pos, heading

    local started = play(a)
    if active ~= a then return end
    if not started then
        standUp(false)
        return
    end

    local id = a.opt.entry.effect
    local fx = id and CFG.Effects and CFG.Effects[id]
    if type(fx) == 'function' then
        local fine, err = pcall(fx, PlayerPedId())
        if not fine then log('effect "%s" failed: %s', id, tostring(err)) end
    end

    a.busy = false
    a.lastTry = GetGameTimer()
    a.checkAfter = GetGameTimer() + setting('General', 'startGraceMs', 1500)
    watch(a)
end

local function start(opt)
    nextToken = nextToken + 1
    local a = { token = nextToken, opt = opt, failures = 0, lastTry = 0, checkAfter = 0, busy = true }
    active = a
    CreateThread(function() begin(a) end)
end

-------------------------------------------------------------------------------
-- MENU EVENTS
-------------------------------------------------------------------------------
-- another resource's list replaced ours: let the player go
local function foreignEvent(owner)
    if menu and owner ~= nil and owner ~= OWNER then closeMenu(false) end
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= OWNER then return foreignEvent(owner) end
    if not menu then return end
    local row = menu.rows[index]
    if not row then return closeMenu(false) end

    if row.kind == 'cat' then
        showSpots(row.cat)
    elseif row.kind == 'spot' then
        showActions(menu.cat, row.spot)
    elseif row.kind == 'action' then
        menu = nil   -- the player stays frozen: the interaction takes over
        start(row.opt)
    elseif row.kind == 'fillet' then
        closeMenu(false)
        ExecuteCommand(setting('Fillet', 'command', 'fff'))
    end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= OWNER then return foreignEvent(owner) end
    if not menu then return end
    if menu.view == 'actions' and menu.cat and #menu.cat.spots > 1 then
        showSpots(menu.cat)
    elseif menu.view == 'actions' or menu.view == 'spots' then
        showCategories()
    else
        closeMenu(false)
    end
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if not menu then return end
    if owner ~= nil and owner ~= OWNER then return end
    closeMenu(false)
end)

-------------------------------------------------------------------------------
-- OPENING
-------------------------------------------------------------------------------
local function canOpen(ped)
    if GetResourceState('pup-ui') ~= 'started' then return false end
    if active or menu or GetGameTimer() < cooldownUntil then return false end
    if slowBlock or U.isDead(ped) then return false end
    if setting('General', 'humanOnly', true) and not U.isHuman(ped) then return false end
    if U.onMountOrVehicle(ped) or U.isLeadingHorse(ped) then return false end
    if U.isSwimming(ped) or U.isRagdoll(ped) or U.isFalling(ped) then return false end
    if U.isHogtied(ped) or U.isCuffed(ped) then return false end
    local radius = setting('Integrations', 'wagonRadius', 4.0)
    local bag = setting('Integrations', 'wagonStateBag', 'pup_stable_wagonID')
    if U.stableWagonNear(GetEntityCoords(ped), radius, bag) then return false end
    return true
end

local function tryOpen()
    local ped = PlayerPedId()
    if not canOpen(ped) then return end
    local options, filletNear = collect()
    if #options == 0 and not filletNear then return end

    FreezeEntityPosition(ped, true)
    TaskStandStill(ped, -1)
    menu = { cats = group(options), filletNear = filletNear }
    showCategories()
end

CreateThread(function()
    buildIndex()
    while true do
        Wait(0)
        if IsControlJustPressed(0, interactKey()) then tryOpen() end
    end
end)

-- once a second: dead or fighting blocks the key; dying ends an interaction
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local dead = U.isDead(ped)
        slowBlock = dead or U.inCombat(ped)
        if dead then
            if active then standUp(false) elseif menu then closeMenu(true) end
        end
    end
end)

-------------------------------------------------------------------------------
-- CLEAR EVENTS (pup-magic and pup-mdt fire the first before they take over the player)
-------------------------------------------------------------------------------
RegisterNetEvent('pup_worldint:clear', function() standUp(false) end)
RegisterNetEvent('pup-misc:interactions:clear', function() standUp(false) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deletePrompt()
    if active or menu then
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        ClearPedTasksImmediately(ped)
    end
    if menu then pcall(function() exports['pup-ui']:HideListMenu() end) end
    active, menu, origin = nil, nil, nil
end)
