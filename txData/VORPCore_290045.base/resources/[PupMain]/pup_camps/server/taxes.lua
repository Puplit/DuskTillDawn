-- pup_camps | taxes and repossession on a calendar schedule (server clock)

local T = Config.Tax

local function dueToday(now)
    local d = os.date('*t', now)
    if T.monthly.enabled then
        if d.day == T.monthly.day then return T.monthly.hour, T.monthly.minute end
        return nil
    end
    if T.fourDays.enabled then
        for _, day in ipairs(T.fourDays.days) do
            if d.day == day then return T.fourDays.hour, T.fourDays.minute end
        end
    end
    return nil
end

local function problems(camp)
    local list = {}
    if camp.taxmoney < T.amount then
        list[#list + 1] = ('Tax due: %s, held: %s, short by %s'):format(
            U.money(T.amount), U.money(camp.taxmoney), U.money(T.amount - camp.taxmoney))
    end
    if T.checkMembers and #camp.members < T.minMembers then
        list[#list + 1] = ('Members: %d, required: %d'):format(#camp.members, T.minMembers)
    end
    return list
end

local function letter(camp, subject, body)
    local leader = tonumber(camp.leader)
    if not leader then return end
    pcall(Integrations.sendMail, leader, subject, body, T.letterFrom)
end
CampLetter = letter

-- hide a camp from the world and tell its leader
function ShutCamp(camp)
    camp.repo = true
    MenuLocks[camp.id] = nil
    OnCampHidden(camp.id)
    Save(camp)
    PushCamp(camp, true)
end

local function warnRun()
    for _, camp in pairs(Camps) do
        if not camp.repo then
            local list = problems(camp)
            if #list > 0 then
                local title = CampTitle(camp)
                letter(camp, 'Camp At Risk: ' .. title,
                    ('%s will be shut down at the next tax time unless this is put right:\n- %s')
                        :format(title, table.concat(list, '\n- ')))
                local s = SrcOfChar(camp.leader)
                if s then Notify(s, L('tax_warn', title), 10000) end
            end
        end
    end
end

local function taxRun()
    local shut = 0
    for _, camp in pairs(Camps) do
        local list = problems(camp)
        local wasRepo = camp.repo
        if not wasRepo and #list > 0 then
            ShutCamp(camp)
            shut = shut + 1
            local title = CampTitle(camp)
            letter(camp, 'Camp Shut Down: ' .. title,
                ('%s has been shut down:\n- %s\n\nThe camp is gone from the map until staff restore it. Settle the overdue %s%s, then speak to staff.')
                    :format(title, table.concat(list, '\n- '), U.money(T.amount),
                        (T.checkMembers and #camp.members < T.minMembers) and ' and bring the roster up' or ''))
            local s = SrcOfChar(camp.leader)
            if s then Notify(s, L('tax_shut', title), 10000) end
        end
        if camp.taxmoney >= T.amount then
            camp.taxmoney = camp.taxmoney - T.amount
            Save(camp)
            if not camp.repo then PushCamp(camp) end
        end
    end
    print(('^2[pup_camps]^7 tax run done, %d camps shut down'):format(shut))
end

local warnedKey = nil
local doneKey = nil

CreateThread(function()
    while not Ready do Wait(1000) end
    while true do
        local now = os.time()
        local hour, minute = dueToday(now)
        if hour then
            local d = os.date('*t', now)
            local dueAt = os.time({ year = d.year, month = d.month, day = d.day, hour = hour, min = minute, sec = 0 })
            local dayKey = ('%04d-%03d'):format(d.year, d.yday)

            if now >= dueAt - T.warnMinutesBefore * 60 and now < dueAt and warnedKey ~= dayKey then
                warnedKey = dayKey
                warnRun()
            end

            if now >= dueAt and doneKey ~= dayKey then
                local last = MySQL.scalar.await('SELECT lastrun FROM cron_state WHERE name = ?', { T.cronName })
                doneKey = dayKey
                if last ~= dayKey then
                    -- written BEFORE running, so a restart mid-run cannot run it twice
                    MySQL.query.await('INSERT INTO cron_state (name, lastrun) VALUES (?, ?) ON DUPLICATE KEY UPDATE lastrun = VALUES(lastrun)',
                        { T.cronName, dayKey })
                    taxRun()
                end
            end
        end
        Wait(30000)
    end
end)
