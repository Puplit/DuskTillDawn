-- pup-ui | client bridge between other resources and the NUI page

-- only one focus-holding panel may be open at a time
local PANELS = {
    shop    = { hide = 'shopHide',     closedEvent = 'pup-ui:client:shopClosed' },
    wardrobe = { hide = 'wardrobeHide', closedEvent = 'pup-ui:client:wardrobeClosed' },
    list    = { hide = 'listMenuHide', closedEvent = 'pup-ui:client:listClosed' },
    pm      = { hide = 'pmHide',       closedEvent = 'pup-ui:client:pmClosed' },
    deck    = { hide = 'deckHide',     closedEvent = 'pup-ui:client:deckClosed' },
    wheel   = { hide = 'wheelHide',    closedEvent = 'pup-ui:client:wheelClosed' },
    input   = { hide = 'inputHide',    closedEvent = 'pup-ui:client:inputClosed' },
    app     = { hide = 'appHide',      closedEvent = 'pup-ui:client:appClosed' },
}

local activePanel = nil
local panelOpenedAt = 0

-- debug tracer; global so the other client files can log through it
function UiLog(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print(('[pup-ui %d] %s'):format(GetGameTimer(), table.concat(parts, ' ')))
end

-- PUSH-TO-TALK WHILE A MENU IS OPEN (voice keeps working under NUI focus)
local PTT   <const> = `INPUT_PUSH_TO_TALK`
local RADIO <const> = 249

local pttActive = false
local pttThread = false

local function startPttGuard()
    if pttThread then return end
    pttThread = true
    CreateThread(function()
        while pttActive do
            Wait(0)
            DisableAllControlActions(0)
            EnableControlAction(0, PTT, true)
            if LocalPlayer.state.pup_ptt_latched then
                SetControlNormal(0, PTT, 1.0)
            end
            if LocalPlayer.state.pup_radio_talking then
                EnableControlAction(0, RADIO, true)
                SetControlNormal(0, RADIO, 1.0)
                SetControlNormal(1, RADIO, 1.0)
                SetControlNormal(2, RADIO, 1.0)
            end
        end
        pttThread = false
    end)
end

-- keepInput lets the player keep moving with the cursor up; cleared on release
local function setFocus(on, why, keepInput)
    UiLog(('FOCUS %s  (%s)'):format(on and 'ON' or 'off', why))
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(on and true or false)
    pttActive = (on == true) and (keepInput ~= true)
    if pttActive then startPttGuard() end
end

-- hides the HUD while a menu is up; named holders, since the ink menu holds separately from PanelOpen
local hudHolders = {}
local hudHeld = false
local hudToken = 0 -- bumped on hold; a stale pending restore is dropped

local function setServerUi(show)
    if GetResourceState('vorp_core') == 'started'
        and pcall(function() exports.vorp_core:SetAllUI(show) end) then
        return
    end
    -- fallback for a core without SetAllUI
    DisplayRadar(show)
    DisplayHud(show)
    TriggerEvent('fred_hud:setVisible', show)
    TriggerEvent('pup-displayrange', show)
    TriggerEvent('vorp:showUi', show)
end

-- never takes it when the player (or the stable) already hid it
function HudHold(who)
    hudToken = hudToken + 1 -- cancels a restore that has not fired yet
    if hudHolders[who] then return end
    hudHolders[who] = true
    if hudHeld or IsRadarHidden() then return end
    hudHeld = true
    setServerUi(false)
end

-- delayed on purpose: a menu handing off to another must not flash the HUD back
function HudRelease(who)
    if not hudHolders[who] then return end
    hudHolders[who] = nil
    if next(hudHolders) ~= nil then return end
    if not hudHeld then return end
    local token <const> = hudToken
    SetTimeout(200, function()
        if hudToken ~= token then return end -- something took a hold again
        if next(hudHolders) ~= nil or not hudHeld then return end
        hudHeld = false
        setServerUi(true)
    end)
end

-- /hideui and death: forget we held it, so no release hands the HUD back
function HudDropLatch()
    hudHolders = {}
    hudHeld = false
    hudToken = hudToken + 1
end

function PanelOpen(name, keepInput)
    UiLog(('PanelOpen "%s"  (prev: %s)'):format(name, tostring(activePanel)))
    if activePanel and activePanel ~= name then
        local spec = PANELS[activePanel]
        if spec then
            UiLog(('  force-closing "%s"'):format(activePanel))
            SendNUIMessage({ action = spec.hide })
            if spec.closedEvent then TriggerEvent(spec.closedEvent) end
        end
    end
    activePanel = name
    panelOpenedAt = GetGameTimer()
    setFocus(true, 'PanelOpen ' .. name, keepInput)
    -- one holder for every focus panel: only one is ever on screen
    HudHold('panel')
end

function PanelDone(name)
    if activePanel ~= name then
        UiLog(('PanelDone "%s" IGNORED (active: %s)'):format(name, tostring(activePanel)))
        return -- already replaced; focus isn't ours
    end
    activePanel = nil
    setFocus(false, 'PanelDone ' .. name)
    HudRelease('panel')
end

-- inkmenu.lua polls game input directly (no NUI focus)
function PanelActive()
    return activePanel ~= nil
end

function CloseAllPanels()
    UiLog(('CloseAllPanels  (active: %s)'):format(tostring(activePanel)))
    activePanel = nil
    setFocus(false, 'CloseAllPanels')
    HudRelease('panel')
    SendNUIMessage({ action = 'panelsHide' })
    -- fire every closed signal so no resource believes its menu is still open
    for _, spec in pairs(PANELS) do
        if spec.closedEvent then TriggerEvent(spec.closedEvent) end
    end
end

-- the page reports its steps and errors here
RegisterNUICallback('debugLog', function(data, cb)
    cb('ok')
    if not data or not data.msg then return end
    if data.level == 'error' then
        print(('[pup-ui ^1JS ERROR^7] %s'):format(tostring(data.msg)))
    elseif Config.General.debug then
        print(('[pup-ui JS] %s'):format(tostring(data.msg)))
    end
end)

-- the page asks for its colours and fonts when it loads (config/theme.lua, resolved in shared/theme.lua)
RegisterNUICallback('themeRequest', function(_, cb)
    cb(PupTheme or {})
end)

exports('IsPanelOpen', function() return activePanel ~= nil end)

-- desync watchdog: Lua and the page must agree on what's open
local jsVisible = nil -- last pupSync answer from the page, nil = no answer

RegisterNUICallback('pupSyncState', function(data, cb)
    cb('ok')
    jsVisible = (data and data.visible) or {}
end)

CreateThread(function()
    local misses = 0
    local idleTicks = 0
    while true do
        Wait(1500)
        if activePanel then
            idleTicks = 0
            -- grace period: panels need a moment to render after opening
            if GetGameTimer() - panelOpenedAt > 2500 then
                jsVisible = nil
                SendNUIMessage({ action = 'pupSync' })
                Wait(400)
                if jsVisible == nil or #jsVisible == 0 then
                    misses = misses + 1 -- page dead or showing nothing
                else
                    misses = 0
                end
                if misses >= 2 then
                    print(('[pup-ui] ^1PANEL DESYNC^7: lua holds focus for "%s" but the page shows %s - self-healing, focus released'):format(
                        tostring(activePanel), jsVisible == nil and 'NO ANSWER' or 'nothing'))
                    CloseAllPanels()
                    misses = 0
                end
            end
        else
            misses = 0
            -- a panel left visible with no focus eats clicks for pages below ours
            idleTicks = idleTicks + 1
            if idleTicks >= 4 then
                idleTicks = 0
                jsVisible = nil
                SendNUIMessage({ action = 'pupSync' })
                Wait(400)
                if jsVisible and #jsVisible > 0 then
                    print(('[pup-ui] ^1PANEL DESYNC^7: page shows "%s" but no panel is open - hiding strays'):format(table.concat(jsVisible, ', ')))
                    SendNUIMessage({ action = 'panelsHide' })
                end
            end
        end
    end
end)

-- close everything when the local player dies so no menu is stranded
AddStateBagChangeHandler('isDead', nil, function(bagName, _, value)
    if not value then return end
    if bagName == ('player:%d'):format(GetPlayerServerId(PlayerId())) then
        CloseAllPanels()
    end
end)

-- TOAST
local function toast(data)
    if type(data) == 'string' or type(data) == 'number' then
        data = { title = tostring(data) }
    elseif type(data) == 'table' then
        data = {
            title    = data.title or data.message or data.text or data.label or '',
            subtitle = data.subtitle or data.sub or data.desc or data.description,
            symbol   = data.symbol or data.icon,
            tone     = data.tone,
            duration = data.duration,
        }
    else
        return
    end
    if data.title == '' and not data.subtitle then return end
    SendNUIMessage({ action = 'toast', data = data })
end

local function bannerShow(data)
    if type(data) ~= 'table' then return end
    SendNUIMessage({ action = 'banner', data = data })
end

local function poster(data)
    if type(data) ~= 'table' then return end
    SendNUIMessage({ action = 'poster', data = data })
end

local function openWheel(data)
    if type(data) ~= 'table' then return end
    PanelOpen('wheel')
    SendNUIMessage({ action = 'wheel', data = data })
end

RegisterNUICallback('wheelSelect', function(data, cb)
    UiLog('NUI cb: wheelSelect')
    PanelDone('wheel')
    cb('ok')
    if data and data.item then
        TriggerEvent('pup-ui:client:wheelSelected', data.item)
    end
end)

RegisterNUICallback('wheelClose', function(_, cb)
    UiLog('NUI cb: wheelClose')
    PanelDone('wheel')
    cb('ok')
    TriggerEvent('pup-ui:client:wheelClosed')
end)

local function death(data) SendNUIMessage({ action = 'death', data = data or {} }) end
local function deathUpdate(data) SendNUIMessage({ action = 'deathUpdate', data = data or {} }) end
local function deathHide() SendNUIMessage({ action = 'deathHide' }) end

local function honor(data) SendNUIMessage({ action = 'honor', data = data or {} }) end

local function openPlayerMenu(data)
    PanelOpen('pm')
    SendNUIMessage({ action = 'playerMenu', data = data or {} })
end

RegisterNUICallback('pmClose', function(_, cb)
    UiLog('NUI cb: pmClose')
    PanelDone('pm')
    cb('ok')
    TriggerEvent('pup-ui:client:pmClosed')
end)

local function openPerkDeck(data)
    PanelOpen('deck')
    SendNUIMessage({ action = 'perkDeck', data = data or {} })
end

local function updatePerkDeck(data)
    SendNUIMessage({ action = 'perkDeckUpdate', data = data or {} })
end

RegisterNUICallback('deckClose', function(_, cb)
    UiLog('NUI cb: deckClose')
    PanelDone('deck')
    cb('ok')
    TriggerEvent('pup-ui:client:deckClosed')
end)

RegisterNUICallback('perkToggle', function(data, cb)
    UiLog('NUI cb: perkToggle')
    cb('ok') -- deck stays open; the refresh event repaints it
    if data and data.id then
        TriggerEvent('pup-ui:client:perkToggle', data.id)
    end
end)

RegisterNUICallback('pmTogglePerk', function(data, cb)
    UiLog('NUI cb: pmTogglePerk')
    PanelDone('pm')
    cb('ok')
    if data and data.id then
        TriggerEvent('pup-ui:client:togglePerk', data.id)
    end
end)

exports('Toast', toast)
exports('Banner', bannerShow)
exports('Poster', poster)
exports('OpenWheel', openWheel)
exports('Death', death)
exports('DeathUpdate', deathUpdate)
exports('DeathHide', deathHide)
exports('Honor', honor)
exports('OpenPlayerMenu', openPlayerMenu)
exports('OpenPerkDeck', openPerkDeck)
exports('UpdatePerkDeck', updatePerkDeck)

-- SHOP
local function openShop(data)
    PanelOpen('shop')
    SendNUIMessage({ action = 'shop', data = data or {} })
end
local function hideShop()
    SendNUIMessage({ action = 'shopHide' })
    PanelDone('shop')
end
exports('OpenShop', openShop)
exports('HideShop', hideShop)

RegisterNUICallback('shopBuy', function(data, cb)
    UiLog('NUI cb: shopBuy')
    cb('ok') -- shop stays open for multiple buys
    if data and data.name then
        TriggerEvent('pup-ui:client:shopBuy', data.name)
    end
end)
RegisterNUICallback('shopClose', function(_, cb)
    UiLog('NUI cb: shopClose')
    PanelDone('shop')
    cb('ok')
    -- callers must hear user closes or their shop session goes stale
    TriggerEvent('pup-ui:client:shopClosed')
end)

-- WARDROBE
local function openWardrobe(data)
    PanelOpen('wardrobe')
    SendNUIMessage({ action = 'wardrobe', data = data or {} })
end
local function updateWardrobe(data)
    SendNUIMessage({ action = 'wardrobeUpdate', data = data or {} })
end
local function hideWardrobe()
    SendNUIMessage({ action = 'wardrobeHide' })
    PanelDone('wardrobe')
end
exports('OpenWardrobe', openWardrobe)
exports('UpdateWardrobe', updateWardrobe)
exports('HideWardrobe', hideWardrobe)

RegisterNUICallback('wardrobeChange', function(data, cb)
    UiLog('NUI cb: wardrobeChange')
    cb('ok') -- panel stays open; the change previews live on the ped
    if data and data.id then
        TriggerEvent('pup-ui:client:wardrobeChange', data)
    end
end)

RegisterNUICallback('wardrobeRotate', function(data, cb)
    UiLog('NUI cb: wardrobeRotate')
    cb('ok')
    TriggerEvent('pup-ui:client:wardrobeRotate', (data and tonumber(data.dir)) or 1)
end)

RegisterNUICallback('wardrobeSave', function(_, cb)
    UiLog('NUI cb: wardrobeSave')
    cb('ok') -- the caller closes via HideWardrobe once it has persisted
    TriggerEvent('pup-ui:client:wardrobeSave')
end)

RegisterNUICallback('wardrobeClose', function(_, cb)
    UiLog('NUI cb: wardrobeClose')
    PanelDone('wardrobe')
    cb('ok')
    TriggerEvent('pup-ui:client:wardrobeClosed')
end)

-- INPUT FORM
local activeInputOwner = nil

local function openInput(data)
    if type(data) ~= 'table' or type(data.fields) ~= 'table' then return false end
    PanelOpen('input')
    activeInputOwner = data.owner
    SendNUIMessage({ action = 'inkInput', data = {
        title = data.title or '',
        subtitle = data.subtitle,
        submit = data.submit or 'Confirm',
        fields = data.fields,
    } })
    return true
end
exports('OpenInput', openInput)

local function resolveInput(values)
    local owner = activeInputOwner
    activeInputOwner = nil
    if owner ~= nil or values ~= nil then
        TriggerEvent('pup-ui:client:inputDone', owner, values)
    end
end

RegisterNUICallback('inputSubmit', function(data, cb)
    UiLog('NUI cb: inputSubmit')
    PanelDone('input')
    cb('ok')
    resolveInput((data and data.values) or {})
end)

RegisterNUICallback('inputCancel', function(_, cb)
    UiLog('NUI cb: inputCancel')
    PanelDone('input')
    cb('ok')
    resolveInput(nil)
end)

-- force-closed (replaced by another panel, /hideui, death)
AddEventHandler('pup-ui:client:inputClosed', function()
    if activeInputOwner then resolveInput(nil) end
end)

-- PROMPT PILL: callers refresh it while in range and it expires when nobody does,
-- so one resource's hide cannot wipe another's pill
local PROMPT_TTL <const> = 800

local pill = { owner = nil, key = nil, label = nil, expires = 0, shown = false }

local function callerName()
    return tostring(GetInvokingResource() or GetCurrentResourceName())
end

local function showPrompt(data)
    if type(data) ~= 'table' then return end
    local owner <const> = callerName()
    local key <const> = tostring(data.key or 'G')
    local label <const> = tostring(data.label or '')

    -- another resource holds it and is still refreshing: leave theirs alone
    if pill.shown and pill.owner and pill.owner ~= owner and GetGameTimer() < pill.expires then
        return
    end

    local changed <const> = not pill.shown or pill.key ~= key or pill.label ~= label
    pill.owner, pill.key, pill.label = owner, key, label
    pill.expires = GetGameTimer() + (tonumber(data.ttl) or PROMPT_TTL)
    if changed then
        pill.shown = true
        SendNUIMessage({ action = 'prompt', data = { key = key, label = label } })
    end
end

local function hidePrompt()
    if pill.shown and pill.owner and pill.owner ~= callerName() then return end
    pill.owner, pill.key, pill.label, pill.expires, pill.shown = nil, nil, nil, 0, false
    SendNUIMessage({ action = 'promptHide' })
end

CreateThread(function()
    while true do
        Wait(200)
        if pill.shown and GetGameTimer() > pill.expires then
            pill.owner, pill.key, pill.label, pill.shown = nil, nil, nil, false
            SendNUIMessage({ action = 'promptHide' })
        end
    end
end)

exports('Prompt', showPrompt)
exports('PromptHide', hidePrompt)

-- WORLD KEY: x/y are screen 0-1 from the caller; only real changes are sent to the page
local wk = { shown = false, key = nil, text = nil, tone = nil, x = -1, y = -1 }

local function showWorldKey(data)
    if type(data) ~= 'table' then return end
    local x <const> = tonumber(data.x)
    local y <const> = tonumber(data.y)
    if not x or not y then return end

    local key <const> = data.key and tostring(data.key) or ''
    local text <const> = data.text and tostring(data.text) or ''
    local tone <const> = data.tone and tostring(data.tone) or 'normal'

    local moved <const> = math.abs(x - wk.x) > 0.0015 or math.abs(y - wk.y) > 0.0015
    if wk.shown and not moved and key == wk.key and text == wk.text and tone == wk.tone then
        return
    end

    wk.shown, wk.key, wk.text, wk.tone, wk.x, wk.y = true, key, text, tone, x, y
    SendNUIMessage({ action = 'worldKey', data = { x = x, y = y, key = key, text = text, tone = tone } })
end

local function hideWorldKey()
    if not wk.shown then return end
    wk.shown, wk.key, wk.text, wk.tone, wk.x, wk.y = false, nil, nil, nil, -1, -1
    SendNUIMessage({ action = 'worldKeyHide' })
end

exports('WorldKey', showWorldKey)
exports('WorldKeyHide', hideWorldKey)

-- kind: 'lock' | 'unlock' | 'denied'
exports('DoorSound', function(kind)
    SendNUIMessage({ action = 'doorSound', data = { kind = tostring(kind or 'unlock') } })
end)

-- PROGRESS BAR
local progressDone = nil

local function openProgress(data, onDone)
    if type(data) ~= 'table' then return false end
    progressDone = onDone
    SendNUIMessage({ action = 'progress', data = {
        label = data.label or data.message or '',
        duration = tonumber(data.duration) or tonumber(data.time) or 5000,
    } })
    return true
end
exports('Progress', openProgress)

-- the /hud editor owns where the bar sits; fred_hud pushes the saved offset
AddEventHandler('pup-ui:progressPos', function(dx, dy, editing)
    SendNUIMessage({ action = 'progressPos', data = {
        dx = tonumber(dx) or 0, dy = tonumber(dy) or 0, editing = editing == true,
    } })
end)

-- the look: 'line' or 'ring'. Config.Progress.style until fred_hud's /hud editor pushes the player's pick
local function setProgressStyle(style)
    style = (style == 'ring') and 'ring' or 'line'
    SendNUIMessage({ action = 'progressStyle', data = { style = style } })
end
AddEventHandler('pup-ui:progressStyle', setProgressStyle)
exports('SetProgressStyle', setProgressStyle)
CreateThread(function()
    Wait(500) -- before fred_hud's reapply (1.5 s) so the player's own pick wins
    setProgressStyle(Config.Progress and Config.Progress.style)
end)

local function progressCancel()
    progressDone = nil
    SendNUIMessage({ action = 'progressHide' })
end
exports('ProgressCancel', progressCancel)

RegisterNUICallback('progressDone', function(_, cb)
    UiLog('NUI cb: progressDone')
    cb('ok')
    local done = progressDone
    progressDone = nil
    if done then done() end
end)

-- LIST MENU
local activeListOwner = nil

local listKeyboardStart

local function openListMenu(data)
    if type(data) ~= 'table' then return end
    -- keepCursor: a refresh of the open menu keeps the highlighted row
    if data.keepCursor and ListKb and not data.index then data.index = ListKb.index end
    PanelOpen('list', data.keepInput == true)
    activeListOwner = data.owner
    SendNUIMessage({ action = 'listMenu', data = data })
    if data.keyboard then listKeyboardStart(data) end
end
local function hideListMenu()
    SendNUIMessage({ action = 'listMenuHide' })
    activeListOwner = nil
    ListKb = nil
    PanelDone('list')
end
exports('OpenListMenu', openListMenu)
exports('HideListMenu', hideListMenu)

-- list menu keyboard cursor
local LIST_CONTROLS = {
    up     = `INPUT_FRONTEND_UP`,
    down   = `INPUT_FRONTEND_DOWN`,
    left   = `INPUT_FRONTEND_LEFT`,
    right  = `INPUT_FRONTEND_RIGHT`,
    accept = `INPUT_FRONTEND_ACCEPT`,
    cancel = `INPUT_FRONTEND_CANCEL`,
}
local LIST_REPEAT_FIRST, LIST_REPEAT_EVERY = 350, 110
local listHeld = {}
local listSession = 0
ListKb = nil -- global so hideListMenu (defined above) can clear it

-- read enabled AND disabled state, so a caller disabling controls can't kill nav
local function listJust(c) return IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c) end
local function listDown(c) return IsControlPressed(0, c) or IsDisabledControlPressed(0, c) end

local function listRepeat(c)
    if listJust(c) then
        listHeld[c] = GetGameTimer() + LIST_REPEAT_FIRST
        return true
    end
    if listDown(c) then
        local at = listHeld[c]
        if at and GetGameTimer() >= at then
            listHeld[c] = GetGameTimer() + LIST_REPEAT_EVERY
            return true
        end
    else
        listHeld[c] = nil
    end
    return false
end

local function listMove(dir)
    local kb = ListKb
    if not kb or kb.count == 0 then return end
    local i = kb.index
    -- one full lap at most, so an all-disabled menu cannot spin here
    for _ = 1, kb.count do
        i = i + dir
        if i < 1 then i = kb.count elseif i > kb.count then i = 1 end
        if kb.selectable[i] then
            kb.index = i
            SendNUIMessage({ action = 'listMenuState', data = { index = i } })
            -- owners that preview the highlighted row need the move
            TriggerEvent('pup-ui:client:listMove', i, activeListOwner)
            return
        end
    end
end

listKeyboardStart = function(data)
    local selectable, count, first = {}, 0, nil
    for i, o in ipairs(data.options or {}) do
        count = i
        selectable[i] = not o.disabled
        if selectable[i] and not first then first = i end
    end
    if not first then return end -- nothing to drive

    -- a refresh keeps the running poll thread so no keypress is lost
    if data.keepCursor and ListKb then
        ListKb.count = count
        ListKb.selectable = selectable
        if not selectable[ListKb.index] then ListKb.index = first end
        SendNUIMessage({ action = 'listMenuState', data = { index = ListKb.index } })
        TriggerEvent('pup-ui:client:listMove', ListKb.index, activeListOwner)
        return
    end

    listSession = listSession + 1
    listHeld = {}
    ListKb = { count = count, index = tonumber(data.index) or first, selectable = selectable, session = listSession }
    if not selectable[ListKb.index] then ListKb.index = first end
    SendNUIMessage({ action = 'listMenuState', data = { index = ListKb.index } })
    TriggerEvent('pup-ui:client:listMove', ListKb.index, data.owner)

    local session = listSession
    CreateThread(function()
        -- skip the opening frame so the Enter that opened this menu is not read again
        Wait(0)
        while ListKb and ListKb.session == session do
            Wait(0)
            if activePanel ~= 'list' then
                -- another panel took over (input form, shop): those keys are its
                listHeld = {}
                Wait(100)
            else
                if listRepeat(LIST_CONTROLS.up) then listMove(-1) end
                if listRepeat(LIST_CONTROLS.down) then listMove(1) end

                if listJust(LIST_CONTROLS.accept) or listJust(LIST_CONTROLS.right) then
                    local kb = ListKb
                    if kb and kb.selectable[kb.index] then
                        local owner, index = activeListOwner, kb.index
                        SendNUIMessage({ action = 'listMenuHide' })
                        activeListOwner = nil
                        ListKb = nil
                        PanelDone('list')
                        TriggerEvent('pup-ui:client:listSelect', index, owner)
                    end
                elseif listJust(LIST_CONTROLS.cancel) or listJust(LIST_CONTROLS.left) then
                    local owner = activeListOwner
                    hideListMenu()
                    TriggerEvent('pup-ui:client:listBack', owner)
                end
            end
        end
    end)
end

RegisterNUICallback('listSelect', function(data, cb)
    UiLog('NUI cb: listSelect')
    PanelDone('list')
    cb('ok')
    local owner = activeListOwner
    activeListOwner = nil
    if data and data.index then
        TriggerEvent('pup-ui:client:listSelect', tonumber(data.index), owner)
    end
end)

RegisterNUICallback('listBack', function(_, cb)
    UiLog('NUI cb: listBack')
    PanelDone('list')
    cb('ok')
    local owner = activeListOwner
    activeListOwner = nil
    TriggerEvent('pup-ui:client:listBack', owner)
end)

-- forced closes route the owner into the generic closed signal
AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner == nil and activeListOwner ~= nil then
        local was = activeListOwner
        activeListOwner = nil
        TriggerEvent('pup-ui:client:listClosed', was)
    end
end)

-- APP: full-screen data-driven dashboard (block schema in html/app.js)
local activeAppOwner = nil

local function openApp(data)
    if type(data) ~= 'table' then return end
    PanelOpen('app')
    activeAppOwner = data.owner
    SendNUIMessage({ action = 'app', data = data })
end

local function updateApp(data)
    SendNUIMessage({ action = 'appUpdate', data = data or {} })
end

local function closeApp()
    SendNUIMessage({ action = 'appHide' })
    activeAppOwner = nil
    PanelDone('app')
end
exports('OpenApp', openApp)
exports('UpdateApp', updateApp)
exports('CloseApp', closeApp)

RegisterNUICallback('appNav', function(data, cb)
    UiLog('NUI cb: appNav')
    cb('ok') -- app stays open; the owner responds with UpdateApp to load the tab
    if data and data.tab then
        TriggerEvent('pup-ui:client:appNav', activeAppOwner, data.tab)
    end
end)

RegisterNUICallback('appAction', function(data, cb)
    UiLog('NUI cb: appAction')
    cb('ok') -- app stays open; the owner decides what to do (and may UpdateApp)
    if data and data.action then
        TriggerEvent('pup-ui:client:appAction', activeAppOwner, data.action, data.data or {})
    end
end)

RegisterNUICallback('appClose', function(_, cb)
    UiLog('NUI cb: appClose')
    local owner = activeAppOwner
    activeAppOwner = nil
    PanelDone('app')
    cb('ok')
    TriggerEvent('pup-ui:client:appClosed', owner)
end)

-- forced closes (replaced panel, /hideui, death) fire appClosed with NO owner
AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner == nil and activeAppOwner ~= nil then
        local was = activeAppOwner
        activeAppOwner = nil
        TriggerEvent('pup-ui:client:appClosed', was)
    end
end)

RegisterNetEvent('pup-ui:honor', honor)

RegisterNetEvent('pup-ui:toast', toast)
RegisterNetEvent('pup-ui:banner', bannerShow)
RegisterNetEvent('pup-ui:poster', poster)

-- which side the menus open on; fred_hud's /hud editor owns the setting
local menuSide = 'left'
local function setMenuSide(side)
    side = (side == 'right') and 'right' or 'left'
    menuSide = side
    SendNUIMessage({ action = 'menuSide', data = { side = side } })
end
AddEventHandler('pup-ui:menuSide', setMenuSide)
exports('SetMenuSide', setMenuSide)

-- so a screen that forces a side for its own scene can put the player's back
exports('GetMenuSide', function() return menuSide end)

-- a UI restart forgets it, so ask fred_hud to push its settings again
CreateThread(function()
    Wait(1500)
    TriggerEvent('fred_hud:reapplyLayout')
end)

-- a pup-ui stop/restart must never strand the player's mouse
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        -- a stop with a menu open would leave the player with no HUD at all
        if hudHeld then setServerUi(true) end
    end
end)

-- panic button: force-closes every overlay and releases NUI focus
AddEventHandler('pup-ui:HideAllUI', function()
    HudDropLatch() -- before CloseAllPanels, or it hands the HUD straight back

    CloseAllPanels()
    SendNUIMessage({ action = 'hideAll' }) -- also clears death, poster and ink overlays
end)
