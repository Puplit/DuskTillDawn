-- pup-medical | the duty register, /duty, /dutycheck and the duty question

Duty = {}

-- [src] = { job, since, charId, name, ctx } ; in memory only
local register = {}
local lastToggle = {}

local function isDoctorJob(job)
    return InList(Config.Medical and Config.Medical.doctorJobs, job)
end

---------------------------------------------------------------------------
-- Logs. Both come from the server toggle and nothing else, once per change.
---------------------------------------------------------------------------
local function dutyEmbed(entry, on, served)
    local fields = {
        PersonField('Player', entry.ctx),
        Field('Status', on and 'went on duty' or 'went off duty'),
        Field('Job', entry.job),
    }
    if not on then fields[#fields + 1] = Field('Time on duty', HoursMinutesSeconds(served)) end
    return {
        title  = on and 'On duty' or 'Off duty',
        color  = on and Colors.green or Colors.red,
        fields = fields,
    }
end

local function sendDutyLogs(entry, on, served, perJobOnly)
    local avatar = Config.Logs and Config.Logs.avatarUrl
    local general = Hook('duty')
    local perJob = isDoctorJob(entry.job) and Hook('dutyByJob', entry.job) or nil

    if Config.Switches.mergeDutyLogs then
        local url = perJob or (not perJobOnly and general) or nil
        if url then PostWebhook(url, dutyEmbed(entry, on, served), 'Duty Roster', avatar) end
        return
    end
    if general and not perJobOnly then PostWebhook(general, dutyEmbed(entry, on, served), 'Duty Roster', avatar) end
    if perJob then PostWebhook(perJob, dutyEmbed(entry, on, served), 'Duty Roster', avatar) end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------
local function goOff(src, reason, perJobOnly)
    local entry = register[src]
    if not entry then return end
    register[src] = nil
    local served = os.time() - entry.since
    sendDutyLogs(entry, false, served, perJobOnly)
    if Online(src) then TriggerClientEvent('pup-medical:client:duty', src, false, entry.job) end
    Debug('duty', ('%s (%d) off duty as %s after %ds (%s)'):format(entry.name, src, entry.job, served, reason))
end

local function goOn(ctx)
    local entry = { job = ctx.job, since = os.time(), charId = ctx.charId, name = ctx.name, ctx = ctx }
    register[ctx.src] = entry
    sendDutyLogs(entry, true, 0, false)
    TriggerClientEvent('pup-medical:client:duty', ctx.src, true, ctx.job)
    Debug('duty', ('%s (%d) on duty as %s'):format(ctx.name, ctx.src, ctx.job))
end

-- the register entry, dropped when the player no longer holds that job
local function liveEntry(src)
    local entry = register[src]
    if not entry then return nil end
    local ctx = GetCtx(src)
    if not ctx or ctx.charId ~= entry.charId or ctx.job ~= entry.job then
        goOff(src, 'job or character changed', false)
        return nil
    end
    return entry
end

---------------------------------------------------------------------------
-- "Is X on duty (as J)?" Own register first, then pup_business.
---------------------------------------------------------------------------
local function businessSays(src, job)
    local res = Config.Integrations and Config.Integrations.business and Config.Integrations.business.resource
    if not Started(res) then return false, 'not started' end
    local ok, answer = pcall(function()
        if job then
            local list = exports[res]:GetPlayersOnDuty(job)
            if type(list) ~= 'table' then return false end
            for _, s in ipairs(list) do
                if tonumber(s) == src then return true end
            end
            return false
        end
        return exports[res]:IsPlayerOnDuty(src) == true
    end)
    if not ok then
        WarnOnce('business-duty', ('%s duty lookup failed: %s'):format(res, tostring(answer)))
        return false, 'error'
    end
    return answer == true, nil
end

function IsOnDuty(src, job)
    src = tonumber(src)
    if not src then return false end
    if job ~= nil and type(job) ~= 'string' then return false end
    local entry = liveEntry(src)
    if entry and (job == nil or entry.job == job) then return true end
    local yes = businessSays(src, job)
    return yes == true
end

function Duty.Drop(src)
    local entry = register[src]
    if not entry then return end
    -- a doctor leaving mid-shift gets the per-job off-duty record
    goOff(src, 'left', true)
end

-- everyone in the register off duty through the normal path; returns the sources clocked off
function Duty.ClockOffAll(reason)
    local list = {}
    for src in pairs(register) do list[#list + 1] = src end
    local done = {}
    for _, src in ipairs(list) do
        local ok, err = pcall(goOff, src, reason, false)
        if ok then done[#done + 1] = src
        else print(('^1[pup-medical]^7 clock-off of %s failed: %s'):format(tostring(src), tostring(err))) end
    end
    return done
end

OnPlayerLeft(function(src)
    Duty.Drop(src)
    lastToggle[src] = nil
end)

---------------------------------------------------------------------------
-- /duty
---------------------------------------------------------------------------
RegisterCommand((Config.Duty and Config.Duty.command) or 'duty', function(src)
    if src == 0 then return end
    local ctx = GetCtx(src)
    if not ctx then return TipBottom(src, L('noCharacter'), 4000) end
    if not InList(Config.Duty.jobs, ctx.job) and not register[src] then
        return TipBottom(src, L('dutyJobNotAllowed'), 4000)
    end
    local now = GetGameTimer()
    if lastToggle[src] and now - lastToggle[src] < 3000 then
        return TipBottom(src, L('dutyWait'), 3000)
    end
    lastToggle[src] = now

    if liveEntry(src) then
        goOff(src, '/duty', false)
        TipBottom(src, L('dutyOff'), 4000)
    else
        if not InList(Config.Duty.jobs, ctx.job) then
            return TipBottom(src, L('dutyJobNotAllowed'), 4000)
        end
        if MedicalRestartLocked and MedicalRestartLocked() then
            return TipBottom(src, L('dutyRestartLocked'), 4000)
        end
        goOn(ctx)
        TipBottom(src, L('dutyOn'), 4000)
    end
end, false)

---------------------------------------------------------------------------
-- /dutycheck: console report of who is on duty
---------------------------------------------------------------------------
RegisterCommand('dutycheck', function(src)
    if src == 0 then return end
    local ace = Config.Switches.dutycheckAce
    if type(ace) == 'string' and ace ~= '' and not IsPlayerAceAllowed(tostring(src), ace) then
        return TipBottom(src, L('dutyCheckDenied'), 4000)
    end
    local ctx = GetCtx(src)
    if not ctx then return TipBottom(src, L('noCharacter'), 4000) end

    local own = register[src]
    local biz, err = businessSays(src, ctx.job)
    print(('[pup-medical] /dutycheck by %d (job %s)'):format(src, tostring(ctx.job)))
    print(('  own register: %s'):format(own and ('on duty as ' .. own.job) or 'not on duty'))
    print(('  pup_business: %s'):format(err and ('lookup failed (' .. err .. ')') or tostring(biz)))
    print(('  combined for %s: %s'):format(tostring(ctx.job), tostring(IsOnDuty(src, ctx.job))))

    local medical = AlertType(MEDICAL_TYPE)
    local count = 0
    for _, p in ipairs(OnlinePlayers()) do
        local pc = GetCtx(p)
        if pc and medical and InList(medical.jobs, pc.job) and IsOnDuty(p, pc.job) then
            count = count + 1
            print(('  on duty: %d %s (%s)%s'):format(p, pc.name, pc.job, p == src and '  <- you' or ''))
        end
    end
    TipBottom(src, L('dutyCheck', count), 6000)
end, false)

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
local function onDutyList(job)
    local out = {}
    for src in pairs(register) do
        local entry = liveEntry(src)
        if entry and (job == nil or entry.job == job) then
            out[#out + 1] = { source = src, job = entry.job, since = entry.since }
        end
    end
    table.sort(out, function(a, b) return a.source < b.source end)
    return out
end

exports('IsPlayerOnDuty', function(source, job)
    return IsOnDuty(source, job) == true
end)

exports('GetOnDutyPlayers', function(job)
    if job ~= nil and type(job) ~= 'string' then job = nil end
    return onDutyList(job)
end)

exports('GetOnDutyCount', function(job)
    if job ~= nil and type(job) ~= 'string' then job = nil end
    return #onDutyList(job)
end)
