-- pup-ui | posse service: a shared crew service any resource can use

-- the core is resolved lazily, not at load
local VorpCore = nil

local function Core() return VorpCore end

TriggerEvent("getCore", function(core) VorpCore = core end)

local CFG = (Config and Config.Posse) or {}
local MAX_SIZE  = tonumber(CFG.maxSize) or 5
local CMD_LABEL = CFG.commandLabel or 'pose'

local function dbg(...)
    if not (Config and Config.Posse and Config.Posse.debug) then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-ui/posse]^7 " .. table.concat(parts, " "))
end

-- posses[id]  = { id, leader = charid, members = { [charid] = { name, charid } },
--                 task = key|nil, taskLabel = string|nil, taskOwner = resource|nil }
local posses      = {}
local posseOfChar = {}
local memberSrc   = {}   -- [charid] = live source (nil when offline)
local invites     = {}   -- [charid] = { posseId, fromName, expires }
local nextPosseId = 1

local function Char(src)
    local core = Core()
    if not core then return nil end
    local user = core.getUser(src)
    return user and user.getUsedCharacter or nil
end
local function notify(src, msg, dur)
    local core = Core()
    if src and core then core.NotifyRightTip(src, msg, dur or 4000) end
end
local function fullName(ch)
    return (('%s %s'):format(tostring(ch.firstname or ''), tostring(ch.lastname or '')))
        :gsub('^%s+', ''):gsub('%s+$', '')
end
local function charOf(src)
    local ch = Char(src)
    return ch and ch.charIdentifier or nil
end
local function srcOf(charid)
    local s = memberSrc[charid]
    -- a stale entry survives an ungraceful drop, so confirm the connection is real
    if s and GetPlayerName(s) ~= nil then return s end
    return nil
end
local function posseOfSrc(src)
    local cid = charOf(src)
    if not cid then return nil, nil end
    local id = posseOfChar[cid]
    return id and posses[id] or nil, cid
end
local function memberCount(p)
    local n = 0
    for _ in pairs(p.members) do n = n + 1 end
    return n
end
local function onlineCount(p)
    local n = 0
    for cid in pairs(p.members) do if srcOf(cid) then n = n + 1 end end
    return n
end

-----------------------------------------------------------------------------------------
-- PAYLOAD (what the panel renders; `online` is what greys a rider out)
-----------------------------------------------------------------------------------------
local function possePayload(charid)
    local id = charid and posseOfChar[charid]
    local p = id and posses[id]
    if not p then return { inPosse = false, max = MAX_SIZE, command = CMD_LABEL } end

    local list = {}
    for cid, m in pairs(p.members) do
        list[#list + 1] = {
            charid = cid, name = m.name, src = srcOf(cid),
            leader = (cid == p.leader), online = srcOf(cid) ~= nil,
        }
    end
    table.sort(list, function(a, b)
        if a.leader ~= b.leader then return a.leader end
        if a.online ~= b.online then return a.online end -- online first, greyed below
        return (a.name or '') < (b.name or '')
    end)

    return {
        inPosse   = true,
        id        = p.id,
        isLeader  = (charid == p.leader),
        members   = list,
        count     = #list,
        online    = onlineCount(p),
        max       = MAX_SIZE,
        command   = CMD_LABEL,
        task      = p.task,
        taskLabel = p.taskLabel,
        taskOwner = p.taskOwner,
    }
end

local function pushPosse(p)
    if not p then return end
    local online = {}
    for cid in pairs(p.members) do
        local s = srcOf(cid)
        if s then
            online[#online + 1] = s
            TriggerClientEvent('pup-ui:posse:update', s, possePayload(cid))
        end
    end
    -- every membership change funnels through here
    TriggerEvent('pup-ui:posse:serverChanged', p.id, online, p.task)
end

-- callback registration needs the core object, so it waits for it
CreateThread(function()
    local waited = 0
    while VorpCore == nil do
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and core then VorpCore = core break end
        waited = waited + 1
        if waited == 40 then -- ~20s
            print("^1[pup-ui/posse]^7 still waiting on vorp_core - posses are inactive until it starts")
        end
        Wait(500)
    end

    VorpCore.Callback.Register('pup-ui:posse:get', function(source, cb)
        cb(possePayload(charOf(source)))
    end)
    dbg('core ready - posse service online')
end)

-- PRESENCE
AddEventHandler('vorp:SelectedCharacter', function(src, character)
    local cid = character and character.charIdentifier or charOf(src)
    if not cid then return end
    -- one connection is one rider: a character swapped away from must not still count
    for c, s in pairs(memberSrc) do
        if s == src and c ~= cid then memberSrc[c] = nil end
    end
    memberSrc[cid] = src
    local id = posseOfChar[cid]
    if id and posses[id] then
        dbg('rider', cid, 'reconnected as source', src)
        pushPosse(posses[id])
    end
end)

AddEventHandler('playerDropped', function()
    local _source = source
    local cid = nil
    for c, s in pairs(memberSrc) do if s == _source then cid = c break end end
    if not cid then cid = charOf(_source) end
    if not cid then return end

    invites[cid] = nil
    memberSrc[cid] = nil

    local id = posseOfChar[cid]
    local p = id and posses[id]
    if not p then return end

    -- the rider keeps their seat, greyed out
    if p.leader == cid then
        local nextLeader = nil
        for c in pairs(p.members) do
            if c ~= cid and srcOf(c) then nextLeader = c break end
        end
        if nextLeader then
            p.leader = nextLeader
            p.task, p.taskLabel, p.taskOwner = nil, nil, nil
            notify(srcOf(nextLeader), 'Your leader went offline - you now lead the posse.', 6000)
        end
    end

    if onlineCount(p) == 0 then
        for c in pairs(p.members) do posseOfChar[c] = nil end
        posses[id] = nil
        dbg('posse', id, 'folded (all riders offline)')
        return
    end

    dbg('rider', cid, 'offline - kept on posse', id)
    pushPosse(p)
end)

-- CREATE / INVITE / JOIN / KICK / LEAVE
RegisterServerEvent('pup-ui:posse:create', function()
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local cid = ch.charIdentifier
    if posseOfChar[cid] then return notify(_source, 'You are already in a posse.') end

    local id = nextPosseId
    nextPosseId = nextPosseId + 1
    posses[id] = { id = id, leader = cid, members = { [cid] = { name = fullName(ch), charid = cid } } }
    posseOfChar[cid] = id
    memberSrc[cid] = _source
    dbg('created posse', id, 'leader', cid)
    notify(_source, ('Posse formed. Invite up to %d more by server ID.'):format(MAX_SIZE - 1))
    pushPosse(posses[id])
end)

-- invite by server ID (the number on the player list)
RegisterServerEvent('pup-ui:posse:invite', function(targetSrc)
    local _source = source
    local p, cid = posseOfSrc(_source)
    if not p then return notify(_source, 'You are not in a posse.') end
    if p.leader ~= cid then return notify(_source, 'Only the leader can invite.') end

    local target = tonumber(targetSrc)
    if not target or target == _source then return notify(_source, 'Give a valid server ID.') end
    if GetPlayerName(target) == nil then return notify(_source, ('No player online with ID %d.'):format(target)) end

    local tch = Char(target)
    if not tch then return notify(_source, 'That player has no character loaded.') end
    local tcid = tch.charIdentifier
    if posseOfChar[tcid] then return notify(_source, 'They are already in a posse.') end

    -- range is checked on invite, not accept, so the leader is told at once
    local maxDist = tonumber(CFG.inviteRadius)
    if maxDist and maxDist > 0 then
        local mePed <const> = GetPlayerPed(_source)
        local themPed <const> = GetPlayerPed(target)
        if not mePed or mePed == 0 or not themPed or themPed == 0 then
            return notify(_source, 'They are too far away.')
        end
        local d <const> = #(GetEntityCoords(mePed) - GetEntityCoords(themPed))
        if d > maxDist then
            return notify(_source, ('They are too far away - ride within %dm of them.'):format(math.floor(maxDist)))
        end
    end
    if memberCount(p) >= MAX_SIZE then
        return notify(_source, ('Your posse is full (%d).'):format(MAX_SIZE))
    end

    -- one invite on their screen at a time, and no flooding them with notices
    local pending = invites[tcid]
    if pending and pending.expires >= os.time() then
        return notify(_source, 'They already have an invite waiting.')
    end

    local me = Char(_source)
    invites[tcid] = { posseId = p.id, fromName = me and fullName(me) or 'Someone', expires = os.time() + 60 }
    notify(_source, ('Invite sent to %s (ID %d).'):format(fullName(tch), target))
    notify(target, ('%s invited you to their posse - /%s to accept'):format(invites[tcid].fromName, CMD_LABEL), 8000)
    TriggerClientEvent('pup-ui:posse:invited', target, { from = invites[tcid].fromName })
end)

RegisterServerEvent('pup-ui:posse:accept', function()
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local cid = ch.charIdentifier
    local inv = invites[cid]
    if not inv or inv.expires < os.time() then
        invites[cid] = nil
        return notify(_source, 'That invite expired.')
    end
    invites[cid] = nil
    if posseOfChar[cid] then return notify(_source, 'You are already in a posse.') end

    local p = posses[inv.posseId]
    if not p then return notify(_source, 'That posse no longer exists.') end
    if memberCount(p) >= MAX_SIZE then return notify(_source, 'That posse is full.') end

    p.members[cid] = { name = fullName(ch), charid = cid }
    posseOfChar[cid] = p.id
    memberSrc[cid] = _source
    -- a new rider invalidates the task: whoever claimed it did so for a different crew
    p.task, p.taskLabel, p.taskOwner = nil, nil, nil
    notify(_source, 'You joined the posse.')
    dbg(fullName(ch), 'joined posse', p.id)
    pushPosse(p)
end)

-- "No" on the invite prompt: drops the invite at once and tells the leader
RegisterServerEvent('pup-ui:posse:decline', function()
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local cid = ch.charIdentifier
    local inv = invites[cid]
    if not inv then return end
    invites[cid] = nil

    local p = posses[inv.posseId]
    local leaderSrc = p and p.leader and memberSrc[p.leader]
    if leaderSrc then
        notify(leaderSrc, ('%s turned down your posse invite.'):format(fullName(ch)), 6000)
    end
end)

RegisterServerEvent('pup-ui:posse:kick', function(targetCharid)
    local _source = source
    local p, cid = posseOfSrc(_source)
    if not p then return end
    if p.leader ~= cid then return notify(_source, 'Only the leader can remove riders.') end

    local target = tonumber(targetCharid)
    if not target or target == cid or not p.members[target] then return end

    local name = p.members[target].name
    p.members[target] = nil
    posseOfChar[target] = nil
    p.task, p.taskLabel, p.taskOwner = nil, nil, nil
    notify(_source, name .. ' removed from the posse.')
    local tsrc = srcOf(target)
    if tsrc then
        notify(tsrc, 'You were removed from the posse.')
        TriggerClientEvent('pup-ui:posse:update', tsrc, { inPosse = false, max = MAX_SIZE, command = CMD_LABEL })
    end
    pushPosse(p)
end)

RegisterServerEvent('pup-ui:posse:leave', function()
    local _source = source
    local p, cid = posseOfSrc(_source)
    if not p then return end

    p.members[cid] = nil
    posseOfChar[cid] = nil
    p.task, p.taskLabel, p.taskOwner = nil, nil, nil

    if p.leader == cid then
        local nextLeader = nil
        for c in pairs(p.members) do if srcOf(c) then nextLeader = c break end end
        if not nextLeader then for c in pairs(p.members) do nextLeader = c break end end
        if nextLeader then
            p.leader = nextLeader
            notify(srcOf(nextLeader), 'You now lead the posse.')
        else
            posses[p.id] = nil
            dbg('posse', p.id, 'disbanded (empty)')
        end
    end

    notify(_source, 'You left the posse.')
    TriggerClientEvent('pup-ui:posse:update', _source, { inPosse = false, max = MAX_SIZE, command = CMD_LABEL })
    if posses[p.id] then pushPosse(p) end
end)

-- EXPORTS

exports('GetPosse', function(src) return possePayload(charOf(src)) end)

-- the crew rules, so consumers can clamp their own requirements to a reachable size
exports('GetPosseLocalConfig', function()
    return { maxSize = MAX_SIZE, command = CMD_LABEL }
end)

-- live sources of everyone riding with this player; offline riders are skipped
exports('GetPosseMembers', function(src)
    local p = posseOfSrc(src)
    if not p then return { src } end
    local out = {}
    for cid in pairs(p.members) do
        local s = srcOf(cid)
        if s then out[#out + 1] = s end
    end
    return out
end)

exports('IsPosseLeader', function(src)
    local p, cid = posseOfSrc(src)
    return p ~= nil and p.leader == cid
end)

-- claim the posse for a task
exports('SetPosseTask', function(src, key, label, owner)
    local p, cid = posseOfSrc(src)
    if not p then return false, 'You need a posse for that.' end
    if p.leader ~= cid then return false, 'Only the leader can take a job.' end
    p.task      = key
    p.taskLabel = label
    p.taskOwner = owner or GetInvokingResource() or 'unknown'
    for c in pairs(p.members) do
        local s = srcOf(c)
        if s and label then notify(s, 'Job taken: ' .. tostring(label) .. '. Get moving.', 6000) end
    end
    dbg('posse', p.id, 'task ->', tostring(key), 'by', tostring(p.taskOwner))
    pushPosse(p)
    return true
end)

exports('GetPosseTask', function(src)
    local p = posseOfSrc(src)
    if not p then return nil end
    return p.task, p.taskLabel, p.taskOwner
end)

exports('ClearPosseTask', function(src)
    local p = posseOfSrc(src)
    if not p then return false end
    p.task, p.taskLabel, p.taskOwner = nil, nil, nil
    pushPosse(p)
    return true
end)

-- is this player in a posse that holds exactly this task?
exports('PosseHasTask', function(src, key)
    local p = posseOfSrc(src)
    if not p then return false, 'You need a posse for this.' end
    if p.task ~= key then return false, 'Your posse has not taken this job.' end
    return true
end)
