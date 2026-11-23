-- pup-mdt | duty clock, restart lock, purge stand-down, Discord duty role, online lawmen

Duty = {
    state = {},     -- src -> { on, region, since, lastTick, lastPay, isLawyer }
    online = {},    -- src -> { name, rank, grade, job, citizenid, region }
    locked = false,
    roles = {},     -- src -> role id given
}

local function isPurge()
    local ok, live = pcall(function() return exports['pup-events']:IsLive('purge') end)
    return ok and live == true
end

-- on duty in this resource's eyes (lawmen and attorneys)
function Duty.isOn(src)
    src = tonumber(src)
    if not src then return false end
    if not Config.Duty.enabled then
        local a = MDT.player(src)
        return a ~= nil and (a.isLaw or a.isLawyer)
    end
    local s = Duty.state[src]
    if s then return s.on == true end
    if Config.Duty.startOnDuty and not Duty.locked then
        local a = MDT.player(src)
        return a ~= nil and (a.isLaw or a.isLawyer)
    end
    return false
end

-- an on-duty lawman (never an attorney)
function Duty.isLawOnDuty(src)
    local a = MDT.player(src)
    return a ~= nil and a.isLaw and Duty.isOn(src)
end

function Duty.region(src)
    local s = Duty.state[tonumber(src) or -1]
    return s and s.on and s.region or nil
end

-- every on-duty lawman's server id
function Duty.lawmen()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if Duty.isLawOnDuty(src) then out[#out + 1] = src end
    end
    return out
end

function Duty.lawyers()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local a = MDT.player(src)
        if a and a.isLawyer and Duty.isOn(src) then out[#out + 1] = src end
    end
    return out
end

function Duty.toLawmen(event, ...)
    for _, src in ipairs(Duty.lawmen()) do TriggerClientEvent(event, src, ...) end
end

function Duty.nuiLawmen(msg)
    for _, src in ipairs(Duty.lawmen()) do MDT.nui(src, msg) end
end

---------------------------------------------------------------------------
-- Discord duty role
---------------------------------------------------------------------------
local function discordId(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, 8) == 'discord:' then return id:sub(9) end
    end
    return nil
end

local function roleReady()
    local c = ServerConfig.DiscordRole
    return c.enabled and c.botToken ~= '' and c.guildId ~= '' and c.onDutyRoleId ~= ''
end

local function roleRequest(method, userId, roleId, label)
    local c = ServerConfig.DiscordRole
    local url = ('https://discord.com/api/v10/guilds/%s/members/%s/roles/%s'):format(c.guildId, userId, roleId)
    PerformHttpRequest(url, function(status)
        if status == 204 or status == 200 then
            MDT.debug('discord role', method, userId, 'ok')
        elseif status == 403 then
            print('^3[pup-mdt]^7 Discord role ' .. label .. ' refused (403): the bot needs Manage Roles and must rank above the role.')
        elseif status == 404 then
            print('^3[pup-mdt]^7 Discord role ' .. label .. ' failed (404): wrong guild or role id, or the player is not in the guild.')
        elseif status == 401 then
            print('^3[pup-mdt]^7 Discord role ' .. label .. ' failed (401): the bot token is wrong.')
        elseif status == 429 then
            print('^3[pup-mdt]^7 Discord role ' .. label .. ' rate limited (429); change skipped.')
        else
            print(('^3[pup-mdt]^7 Discord role %s failed (HTTP %s).'):format(label, tostring(status)))
        end
    end, method, '', {
        ['Authorization'] = 'Bot ' .. c.botToken,
        ['User-Agent'] = ('DiscordBot (%s, %s)'):format(c.userAgentUrl, c.userAgentVersion),
        ['Content-Type'] = 'application/json',
        ['X-Audit-Log-Reason'] = 'MDT duty ' .. label,
    })
end

function Duty.roleOn(src)
    if not roleReady() then return end
    local uid = discordId(src)
    if not uid then return end
    local role = ServerConfig.DiscordRole.onDutyRoleId
    Duty.roles[src] = { user = uid, role = role }
    roleRequest('PUT', uid, role, 'add')
end

function Duty.roleOff(src)
    if not roleReady() then Duty.roles[src] = nil return end
    local held = Duty.roles[src]
    local uid = held and held.user or discordId(src)
    if not uid then return end
    roleRequest('DELETE', uid, held and held.role or ServerConfig.DiscordRole.onDutyRoleId, 'remove')
    Duty.roles[src] = nil
end

AddEventHandler('pup-mdt:server:dutyStateChanged', function(src, on)
    if on then Duty.roleOn(src) else Duty.roleOff(src) end
end)

---------------------------------------------------------------------------
-- Online lawmen list
---------------------------------------------------------------------------
local function onlineRow(a)
    return {
        serverId = a.src, name = a.name, rank = Perms.rankName(a.job, a.grade), grade = a.grade,
        job = a.job, citizenid = a.cid, region = Duty.region(a.src),
    }
end

function Duty.onlineList()
    local out = {}
    for _, row in pairs(Duty.online) do out[#out + 1] = row end
    table.sort(out, function(x, y) return (x.grade or 0) > (y.grade or 0) end)
    return out
end

local function broadcastOnline(changed, onDuty)
    if changed then
        Duty.nuiLawmen({ action = 'lawmanStatusChanged', citizenid = changed.citizenid, name = changed.name, onDuty = onDuty })
    end
    Duty.nuiLawmen({ action = 'updateOnlineLawmen', lawmen = Duty.onlineList() })
end

function Duty.addOnline(src, tries)
    CreateThread(function()
        for i = 1, (tries or 3) do
            local a = MDT.player(src)
            if a then
                if a.isLaw and Duty.isOn(src) then
                    local fresh = Duty.online[src] == nil
                    Duty.online[src] = onlineRow(a)
                    if fresh then broadcastOnline(Duty.online[src], true) end
                end
                return
            end
            Wait(1000 + math.random(0, 1000))
        end
    end)
end

function Duty.removeOnline(src)
    local row = Duty.online[src]
    if not row then return end
    Duty.online[src] = nil
    broadcastOnline(row, false)
end

CreateThread(function()
    while true do
        Wait((Config.Duty.onlineListSeconds or 30) * 1000)
        for src in pairs(Duty.online) do
            if not Duty.isLawOnDuty(src) then Duty.removeOnline(src) end
        end
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            if not Duty.online[src] and Duty.isLawOnDuty(src) then
                local a = MDT.player(src)
                if a then Duty.online[src] = onlineRow(a); broadcastOnline(Duty.online[src], true) end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Banking duty time
---------------------------------------------------------------------------
local function bankLawyer(src, s)
    if not s or not s.isLawyer or not s.since then return end
    local mins = math.floor((os.time() - s.since) / 60)
    if mins <= 0 then return end
    local a = MDT.player(src)
    local cid = s.cid or (a and a.cid)
    if not cid then return end
    DB.q('INSERT INTO mdt_lawyer_stats (citizenid, name, duty_minutes) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE duty_minutes = duty_minutes + VALUES(duty_minutes), name = VALUES(name)',
        { cid, s.name or (a and a.name) or '', mins })
end

-- whole minutes since the last bank go onto the active profile
local function bankLawman(src, s)
    if not s or s.isLawyer or not s.lastTick or not s.cid then return end
    local mins = math.floor((os.time() - s.lastTick) / 60)
    if mins <= 0 then return end
    s.lastTick = s.lastTick + mins * 60
    local n = DB.upd('UPDATE mdt_lawman_profiles SET duty_time_minutes = duty_time_minutes + ?, last_duty_update = NOW() WHERE citizen_id = ? AND is_active = 1',
        { mins, s.cid })
    if n == 0 then
        local a = MDT.player(src)
        if a and a.isLaw then
            Lawmen.ensureProfile(a)
            DB.upd('UPDATE mdt_lawman_profiles SET duty_time_minutes = duty_time_minutes + ?, last_duty_update = NOW() WHERE citizen_id = ? AND is_active = 1', { mins, s.cid })
        end
    end
end
Duty.bankLawman = bankLawman

CreateThread(function()
    while true do
        Wait(60000)
        if Config.Duty.trackTime then
            local every = math.max(1, Config.Duty.trackIntervalMinutes or 1) * 60
            for _, src in ipairs(MDT.keys(Duty.state)) do
                local s = Duty.state[src]
                if s and s.on and not s.isLawyer and os.time() - (s.lastTick or 0) >= every then
                    local a = MDT.player(src)
                    if a and a.isLaw then
                        local ok, err = pcall(bankLawman, src, s)
                        if not ok then print('^1[pup-mdt]^7 duty time: ' .. tostring(err)) end
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Clock on / off
---------------------------------------------------------------------------
local function regionById(id)
    if type(id) ~= 'string' then return nil end
    for _, r in ipairs(Config.Duty.regions) do
        if r.id == id then return r.id end
    end
    return nil
end

local function finishOn(a, region)
    local now = os.time()
    Duty.state[a.src] = {
        on = true, region = a.isLaw and region or nil, since = now, lastTick = now, lastPay = now,
        isLawyer = a.isLawyer, cid = a.cid, name = a.name,
    }
    local label = region or L('no_region')
    MDT.notify(a.src, L('now_on_duty', label), 5000)
    TriggerClientEvent('pup-mdt:client:dutyChanged', a.src, true, Duty.region(a.src), a.isLawyer)
    if a.isLaw then
        if region then
            DB.upd('UPDATE mdt_lawman_profiles SET region = ? WHERE citizen_id = ? AND is_active = 1', { region, a.cid })
        end
        TriggerEvent('pup-mdt:server:dutyStateChanged', a.src, true)
        Duty.addOnline(a.src, 1)
        Cache.clear('roster'); Cache.clear('dashboard')
    end
    MDT.audit(a, 'duty_changed', a.cid, a.name, a.isLawyer and 'Clocked ON duty (lawyer)' or 'Clocked ON duty')
    return true
end

-- the clock-on rules; menu = true lets a lawman be shown the region picker
function Duty.clockOn(src, region, menu)
    local a = MDT.player(src)
    if not a or (not a.isLaw and not a.isLawyer) then
        MDT.notify(src, L('not_a_lawman'), 4000)
        return false
    end
    if Duty.locked then MDT.notify(src, L('restart_no_duty'), 5000) return false end
    if isPurge() then MDT.notify(src, L('purge_no_duty'), 5000) return false end
    local s = Duty.state[src]
    if s and s.on then MDT.notify(src, L('already_on_duty'), 4000) return false end
    if a.isLawyer then return finishOn(a, nil) end
    region = regionById(region)
    if menu and not region and Config.Duty.regionPicker then
        local list = {}
        for _, r in ipairs(Config.Duty.regions) do
            list[#list + 1] = { id = r.id, label = r.label, description = r.description }
        end
        TriggerClientEvent('pup-mdt:client:regionMenu', src, list)
        return true
    end
    return finishOn(a, region)
end

-- reason: nil, 'afk', 'restart', 'purge', 'fired', 'switch', 'job', 'drop'
function Duty.clockOff(src, reason, silent)
    src = tonumber(src)
    local s = Duty.state[src]
    if not s or not s.on then
        if not silent then MDT.notify(src, L('already_off_duty'), 4000) end
        return false
    end
    -- off first: banking waits on the database, and nothing may act on duty meanwhile
    Duty.state[src] = nil
    if s.isLawyer then bankLawyer(src, s) else bankLawman(src, s) end
    if reason ~= 'drop' then
        if not silent then
            MDT.notify(src, reason == 'afk' and L('off_duty_afk') or L('now_off_duty'), 5000)
        end
        TriggerClientEvent('pup-mdt:client:dutyChanged', src, false, nil, s.isLawyer)
    end
    if not s.isLawyer then
        TriggerEvent('pup-mdt:server:dutyStateChanged', src, false)
        Duty.removeOnline(src)
        Cache.clear('roster'); Cache.clear('dashboard')
    end
    local a = MDT.player(src) or { src = src, cid = s.cid, name = s.name, job = s.isLawyer and Config.Legal.jobs[1] or Config.LawJobs[1], isLawyer = s.isLawyer, isLaw = not s.isLawyer }
    local text = 'Clocked OFF duty' .. (s.isLawyer and ' (lawyer)' or '') .. (reason == 'afk' and ' (AFK)' or (reason and (' (' .. reason .. ')') or ''))
    MDT.audit(a, 'duty_changed', s.cid, s.name, text)
    return true
end

function Duty.clockOffAll(reason, message)
    for _, src in ipairs(MDT.keys(Duty.state)) do
        local s = Duty.state[src]
        if s and s.on then
            local ok = pcall(Duty.clockOff, src, reason, true)
            if not ok or (Duty.state[src] and Duty.state[src].on) then Duty.state[src] = nil end
            if message then MDT.notify(src, message, 8000) end
        end
    end
end

---------------------------------------------------------------------------
-- Events and commands
---------------------------------------------------------------------------
RegisterNetEvent('pup-mdt:server:clockOn', function(region)
    local src = source
    Duty.clockOn(src, type(region) == 'string' and region or nil, false)
end)

RegisterNetEvent('pup-mdt:server:afk', function()
    local src = source
    if Duty.isOn(src) and Config.Duty.afkMinutes > 0 then Duty.clockOff(src, 'afk') end
end)

-- hand-over from pup_business: exactly what /onduty or /offduty would run
RegisterNetEvent('mdt:server:dutyCommand', function(on)
    local src = source
    if on then Duty.clockOn(src, nil, true) else Duty.clockOff(src) end
end)

RegisterCommand(Config.Duty.onCommand, function(src)
    if src <= 0 then return end
    if Duty.locked then return MDT.notify(src, L('restart_no_duty'), 5000) end
    Duty.clockOn(src, nil, true)
end, false)

RegisterCommand(Config.Duty.offCommand, function(src)
    if src <= 0 then return end
    Duty.clockOff(src)
end, false)

---------------------------------------------------------------------------
-- Restart lock and purge
---------------------------------------------------------------------------
AddEventHandler('txAdmin:events:scheduledRestart', function(ev)
    local lockMins = Config.Duty.restartLockMinutes or 0
    if lockMins <= 0 or Duty.locked then return end
    local secs = tonumber(ev and ev.secondsRemaining)
    if not secs or secs > lockMins * 60 then return end
    Duty.locked = true
    local mins = math.max(1, math.ceil(secs / 60))
    Duty.clockOffAll('restart', L('restart_clocked_off', mins, mins == 1 and L('minute') or L('minutes')))
    print(('^3[pup-mdt]^7 restart in %d s: duty locked, everyone clocked off.'):format(secs))
end)

AddEventHandler('txAdmin:events:scheduledRestartSkipped', function()
    Duty.locked = false
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    Duty.locked = true
    Duty.clockOffAll('restart', L('restart_now_off'))
end)

AddEventHandler('pup-events:server:state', function(key, on)
    if key == 'purge' and on then Duty.clockOffAll('purge', L('purge_no_duty')) end
end)

---------------------------------------------------------------------------
-- Character switch, job change, disconnect
---------------------------------------------------------------------------
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    local s = Duty.state[src]
    if s and s.on then
        Duty.state[src] = nil
        if s.isLawyer then bankLawyer(src, s) else bankLawman(src, s) end
        if not s.isLawyer then
            Duty.online[src] = nil
            Cache.clear('roster'); Cache.clear('dashboard')
            TriggerEvent('pup-mdt:server:dutyStateChanged', src, false)
        end
        TriggerClientEvent('pup-mdt:client:dutyChanged', src, false, nil, s.isLawyer)
    end
end)

AddEventHandler('vorp:playerJobChange', function(src, newJob)
    src = tonumber(src)
    local s = Duty.state[src]
    if not s or not s.on then return end
    local stillOk = s.isLawyer and MDT.isLawyerJob(newJob) or (not s.isLawyer and MDT.isLawJob(newJob))
    if not stillOk then Duty.clockOff(src, 'job') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local s = Duty.state[src]
    Duty.state[src] = nil
    if s and s.on then
        if s.isLawyer then bankLawyer(src, s) else bankLawman(src, s) end
    end
    if Duty.roles[src] and ServerConfig.DiscordRole.removeOnDisconnect then Duty.roleOff(src) end
    Duty.roles[src] = nil
    if Duty.online[src] then Duty.removeOnline(src) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, s in pairs(Duty.state) do
        if s.on then
            if s.isLawyer then bankLawyer(src, s) else bankLawman(src, s) end
        end
    end
    if ServerConfig.DiscordRole.removeAllOnStop then
        for src in pairs(Duty.roles) do Duty.roleOff(src) end
    end
end)

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
exports('IsPlayerOnDuty', function(src) return Duty.isLawOnDuty(src) end)

exports('SetPlayerDuty', function(src, on, region)
    src = tonumber(src)
    if not src or not MDT.online(src) then return false end
    if on then Duty.clockOn(src, region, false) else Duty.clockOff(src, nil, false) end
    return true
end)

exports('GetDutyRegion', function(src) return Duty.region(src) end)

exports('GetPlayersOnDuty', function(region)
    local out = {}
    for _, src in ipairs(Duty.lawmen()) do
        local r = Duty.region(src)
        if not region or region == r then out[#out + 1] = { source = src, region = r } end
    end
    return out
end)

---------------------------------------------------------------------------
-- Screen requests
---------------------------------------------------------------------------
MDT.rpc('getDutyStatus', { staff = true }, function(actor)
    return { onDuty = Duty.isOn(actor.src) }
end)

MDT.rpc('barSetDuty', { staff = true }, function(actor, p)
    if MDT.bool(p.onDuty) then Duty.clockOn(actor.src, nil, true) else Duty.clockOff(actor.src) end
    return { ok = true }
end)
