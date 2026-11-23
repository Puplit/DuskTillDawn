-- pup_business | the duty roster (memory only) merged with pup-mdt's

Duty = {} -- [src] = { job, region, charid, since }

local function mdtRunning() return GetResourceState('pup-mdt') == 'started' end

function PurgeLive()
    if GetResourceState('pup-events') ~= 'started' then return false end
    local ok, live = pcall(function() return exports['pup-events']:IsLive('purge') end)
    return ok and live == true
end

-- drops an entry whose player left or switched character
local function stillValid(src, e)
    local ch = GetChar(src)
    if not ch or CharId(ch) ~= e.charid then
        Duty[src] = nil
        TriggerClientEvent('pup_business:dutyState', src, false, nil)
        return false
    end
    return true
end

function OwnDuty(src)
    src = tonumber(src)
    local e = src and Duty[src]
    if e and stillValid(src, e) then return e end
    return nil
end

local function mdtOnDuty(src)
    if not mdtRunning() then return false end
    local ok, on = pcall(function() return exports['pup-mdt']:IsPlayerOnDuty(src) end)
    return ok and on == true
end

function IsOnDutyMerged(src)
    return OwnDuty(src) ~= nil or mdtOnDuty(tonumber(src))
end

-- [src] = { job, region }: pup-mdt's entries first, ours win on a clash
function MergedRoster()
    local out = {}
    if mdtRunning() then
        local ok, list = pcall(function() return exports['pup-mdt']:GetPlayersOnDuty() end)
        if ok and type(list) == 'table' then
            for _, r in pairs(list) do
                local s = type(r) == 'table' and tonumber(r.source) or tonumber(r)
                local ch = s and GetChar(s)
                if ch then out[s] = { job = ch.job, region = type(r) == 'table' and r.region or nil, mdt = true } end
            end
        end
    end
    for s, e in pairs(Duty) do
        if stillValid(s, e) then out[s] = { job = e.job, region = e.region } end
    end
    return out
end

local function cleanRegion(region)
    return PB.cleanText(region, 40)
end

local function stationFor(region, job)
    for _, st in ipairs(Config.DutyStations or {}) do
        if st.region == region then
            for _, j in ipairs(st.jobs or {}) do
                if j == job then return st end
            end
        end
    end
    return nil
end

-- the one place the roster changes. quiet = no tip to the player.
function SetDuty(src, on, region, opts)
    src = tonumber(src)
    opts = opts or {}
    local ch = GetChar(src)
    if on then
        if not ch then return false end
        if BizRestartLocked and BizRestartLocked() then
            if not opts.quiet then Notify(src, L('restart_no_duty')) end
            return false
        end
        region = cleanRegion(region)
        Duty[src] = { job = ch.job, region = region ~= '' and region or nil, charid = CharId(ch), since = Now() }
        TriggerClientEvent('pup_business:dutyState', src, true, Duty[src].region)
        if not opts.quiet then Notify(src, L('on_duty')) end
        SendLog(ch.job, 'On duty', COLOUR.green, table.pack(F('Who', WhoText(src)), F('Region', Duty[src].region, true)))
        return true
    end

    local was = Duty[src]
    Duty[src] = nil
    TriggerClientEvent('pup_business:dutyState', src, false, nil)
    if was then
        if not opts.quiet then Notify(src, opts.message or L('off_duty')) end
        SendLog(was.job, 'Off duty', COLOUR.red, table.pack(
            F('Who', WhoText(src)), F('Region', cleanRegion(region) ~= '' and cleanRegion(region) or was.region, true)))
    end
    return was ~= nil
end

Handle('dutyOn', 2000, function(src, ch, region)
    if PurgeLive() then Notify(src, L('purge_closed')) return false end
    if BizRestartLocked and BizRestartLocked() then Notify(src, L('restart_no_duty')) return false end
    if Config.DutyRequiresBusiness and not Biz[ch.job] then Notify(src, L('not_in_business')) return false end
    region = cleanRegion(region)

    -- stations are the only way on for station jobs while they are enabled
    if Config.DutyStationsEnabled and not Config.RegionMenu and Config.StationJobs[ch.job] then
        local st = stationFor(region, ch.job)
        if not st then Notify(src, L('duty_station_only')) return false end
        local pos = PedCoords(src)
        if pos and #(pos - st.coords) > Config.StationReach then Notify(src, L('duty_station_only')) return false end
    elseif region ~= '' and Config.DutyStationsEnabled and not stationFor(region, ch.job) then
        region = ''
    end

    return SetDuty(src, true, region)
end)

Handle('dutyOff', 2000, function(src, _, region, afk)
    local had = OwnDuty(src) ~= nil
    SetDuty(src, false, region, { message = afk == true and L('afk_off') or nil })
    if not had then
        -- the client thought it was on duty; it now knows otherwise
        Notify(src, afk == true and L('afk_off') or L('off_duty'))
    end
    return true
end)

Handle('dutyState', 500, function(src)
    local e = OwnDuty(src)
    return { on = e ~= nil, region = e and e.region or nil }
end)

-- the purge closes everything
AddEventHandler('pup-events:server:state', function(key, on)
    if key ~= 'purge' or not on then return end
    for s in pairs(Duty) do SetDuty(s, false, nil) end
end)

AddEventHandler('playerDropped', function()
    Duty[source] = nil
end)

-- selecting a character (another one, or the same one again after the
-- selection screen) always starts off duty
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if src and Duty[src] then
        SetDuty(src, false, nil, { quiet = true })
    end
end)

-- /checkduty
RegisterCommand(Config.DutyCommands.check, function(src)
    if src <= 0 then return end
    if OwnDuty(src) then
        Notify(src, L('check_on_here'))
    elseif mdtOnDuty(src) then
        Notify(src, L('check_on_mdt'))
    else
        Notify(src, L('check_off'))
    end
end, false)

-- /viewduty [job]
RegisterCommand(Config.DutyCommands.view, function(src, args)
    if src <= 0 then return end
    if not Throttle(src, 'viewduty', 1500) then return end
    local ch = GetChar(src)
    if not ch then return end
    local job = ch.job
    if IsGroupAdmin(src) then
        local want = PB.jobCode(args[1] or '')
        if want ~= '' then job = want end
    elseif not IsBossGrade(job, CharGrade(ch)) then
        return Notify(src, L('no_permission'))
    end
    local rows = {}
    for s, e in pairs(MergedRoster()) do
        if e.job == job then
            local other = GetChar(s)
            rows[#rows + 1] = { id = s, name = other and FullName(other) or ('ID %d'):format(s) }
        end
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    TriggerClientEvent('pup_business:showDuty', src, job, rows)
end, false)
