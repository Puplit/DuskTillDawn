-- pup-ui | posse menu and its command

-- the core is resolved lazily: pup-ui starts before vorp_core
local VorpCore = nil

local function Core()
    if VorpCore == nil then
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and core then VorpCore = core end
    end
    return VorpCore
end

local function PosseFetch()
    local core = Core()
    if not core then return nil end
    return core.Callback.TriggerAwait('pup-ui:posse:get')
end

local LIST_OWNER   <const> = 'pup-ui:posse:list'
local INPUT_OWNER  <const> = 'pup-ui:posse:input'
-- its own owner, so the yes/no never collides with the roster list below
local INVITE_OWNER <const> = 'pup-ui:posse:inviteask'

local posse    = { inPosse = false, max = 5, command = 'pose' }
local pendingInvite = nil
local view = nil   -- 'root' | 'kick' | nil (menu closed)
local rows = {}    -- index -> { kind = ..., charid = ... }, 1:1 with menu options

-- MENUS
local function openMenu()
    posse = PosseFetch() or posse
    view, rows = 'root', {}
    local options = {}
    local function add(row, label, desc, disabled)
        options[#options + 1] = { label = label, desc = desc, disabled = disabled }
        rows[#rows + 1] = row
    end

    local subtitle
    if not posse.inPosse then
        subtitle = ('A posse of up to %d rides together.'):format(posse.max or 5)
        add({ kind = 'create' }, 'Form a posse', 'Start your own crew and invite riders.')
    else
        subtitle = ('%d/%d riders'):format(posse.count or 0, posse.max or 5)
            .. (posse.taskLabel and ('  |  Job: ' .. posse.taskLabel) or '  |  No job taken')

        -- offline riders are greyed, not removed
        for _, m in ipairs(posse.members or {}) do
            local label = m.name .. (m.leader and '  (leader)' or '')
            local desc
            if m.online then
                desc = m.src and ('Riding  -  ID ' .. tostring(m.src)) or 'Riding'
            else
                desc = 'Offline'
            end
            add({ kind = 'member' }, label, desc, true)
        end

        if posse.isLeader then
            if (posse.count or 0) < (posse.max or 5) then
                add({ kind = 'invite' }, 'Invite by server ID', 'Bring another rider in.')
            end
            if (posse.count or 0) > 1 then
                add({ kind = 'kickmenu' }, 'Remove a rider', 'Cut someone from the posse.')
            end
        end
        add({ kind = 'leave' },
            posse.isLeader and 'Disband / leave' or 'Leave posse',
            posse.isLeader and 'Leadership passes on, or the posse ends with you.' or 'Ride alone again.')
    end

    exports['pup-ui']:OpenListMenu({
        owner    = LIST_OWNER,
        title    = 'Posse',
        subtitle = subtitle,
        options  = options,
    })
end

local function openKickMenu()
    view, rows = 'kick', {}
    local options = {}
    for _, m in ipairs(posse.members or {}) do
        if not m.leader then
            -- keyed by charid, not src, so offline riders can be removed too
            options[#options + 1] = { label = m.name .. (m.online and '' or '  (offline)'), desc = 'Remove this rider.' }
            rows[#rows + 1] = { kind = 'kick', charid = m.charid }
        end
    end
    if #options == 0 then
        exports['pup-ui']:Toast('No one to remove.')
        return openMenu()
    end
    exports['pup-ui']:OpenListMenu({
        owner    = LIST_OWNER,
        title    = 'Remove who?',
        subtitle = 'They can be invited back later.',
        options  = options,
    })
end

local function openInvitePrompt(info)
    exports['pup-ui']:OpenListMenu({
        owner    = INVITE_OWNER,
        title    = 'Posse Invite',
        subtitle = ('%s wants you to ride with them.'):format((info and info.from) or 'Someone'),
        options  = {
            { label = 'Yes', desc = 'Join their posse.' },
            { label = 'No',  desc = 'Keep riding alone.' },
        },
    })
end

-- LIST EVENTS (owner-filtered; the menu closes itself on select)
AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    -- the invite prompt is its own menu and has no `rows` mapping
    if owner == INVITE_OWNER then
        pendingInvite = nil
        if index == 1 then
            TriggerServerEvent('pup-ui:posse:accept')
            SetTimeout(600, openMenu)
        else
            TriggerServerEvent('pup-ui:posse:decline')
            exports['pup-ui']:Toast('You turned the invite down.')
        end
        return
    end

    if owner ~= LIST_OWNER or view == nil then return end
    local row = rows[index]
    if not row then return end

    if row.kind == 'create' then
        view = nil
        TriggerServerEvent('pup-ui:posse:create')
        SetTimeout(500, openMenu)
    elseif row.kind == 'invite' then
        view = nil
        exports['pup-ui']:OpenInput({
            owner = INPUT_OWNER,
            title = 'Invite a rider',
            subtitle = 'Their server ID (the number on the player list)',
            fields = { { id = 'sid', label = 'Server ID', type = 'number' } },
        })
    elseif row.kind == 'kickmenu' then
        openKickMenu()
    elseif row.kind == 'kick' then
        view = nil
        if row.charid then TriggerServerEvent('pup-ui:posse:kick', row.charid) end
        SetTimeout(600, openMenu)
    elseif row.kind == 'leave' then
        view = nil
        TriggerServerEvent('pup-ui:posse:leave')
    else
        -- dimmed member rows shouldn't fire, but if one does, just come back
        openMenu()
    end
end)

-- ESC in the kick picker steps back to the roster; ESC at the roster closes
AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= LIST_OWNER then return end
    if view == 'kick' then
        openMenu()
    else
        view, rows = nil, {}
    end
end)

-- forced close: drop state so a stale selection can never fire later
AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= nil and owner ~= LIST_OWNER then return end
    view, rows = nil, {}
end)

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= INPUT_OWNER then return end
    -- values is an array in field order, not keyed
    local sid = values and tonumber(values[1])
    if sid then TriggerServerEvent('pup-ui:posse:invite', sid) end
    SetTimeout(400, openMenu)
end)

-- SERVER PUSHES
RegisterNetEvent('pup-ui:posse:update', function(payload)
    posse = payload or { inPosse = false, max = 5, command = 'pose' }
    -- refresh only when the roster is on screen, never mid-choice in the kick picker
    if view == 'root' then openMenu() end
end)

RegisterNetEvent('pup-ui:posse:invited', function(info)
    pendingInvite = info
    local from <const> = (info and info.from) or 'Someone'

    -- never pull someone out of another panel; toast instead and let the command accept it (held 60s)
    local busy = false
    pcall(function() busy = exports['pup-ui']:IsPanelOpen() end)
    if busy then
        exports['pup-ui']:Toast(('%s invited you to their posse - /%s to accept')
            :format(from, posse.command or 'pose'))
        return
    end

    openInvitePrompt(info)
end)

-- COMMAND
local function posseCommand()
    if pendingInvite then
        TriggerServerEvent('pup-ui:posse:accept')
        pendingInvite = nil
        SetTimeout(600, openMenu)
        return
    end
    openMenu()
end

CreateThread(function()
    local names = (Config and Config.Posse and Config.Posse.commands) or { 'pose', 'posse' }
    for _, name in ipairs(names) do
        if type(name) == 'string' and name ~= '' then
            RegisterCommand(name, posseCommand, false)
        end
    end
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    Wait(2000)
    posse = PosseFetch() or posse
end)

-- EXPORTS
exports('OpenPosse', openMenu)
exports('GetPosseLocal', function() return posse end)
