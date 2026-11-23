-- pup_business | hiring, firing and ranks

StashOpenBy = {} -- [src] = container id text this resource opened for them

-- everything that depends on being in a business ends when the player leaves it
function OnLeftJob(src, oldJob)
    src = tonumber(src)
    if not src then return end
    local e = Duty[src]
    if e and e.job == oldJob then
        SetDuty(src, false, nil, { message = L('off_duty_left_job') })
    end
    local open = StashOpenBy[src]
    local b = oldJob and Biz[oldJob]
    if open and b and tostring(b.containerid) == open then
        StashOpenBy[src] = nil
        pcall(function() exports.vorp_inventory:closeInventory(src, open) end)
    end
end

-- sets job and grade in memory and in the database, then tells the client
function ApplyJob(src, newJob, newGrade)
    local ch = GetChar(src)
    if not ch then return false end
    local charid = CharId(ch)
    -- vorp_core raises vorp:playerJobChange / vorp:playerJobGradeChange from these
    -- setters; the handlers below end duty, close the old stash and tell the client
    ch.setJob(newJob)
    ch.setJobGrade(newGrade)
    MySQL.update('UPDATE characters SET job = ?, jobgrade = ? WHERE charidentifier = ?', { newJob, newGrade, charid })
    return true
end

-- jobs changed by anything else (vorp's own /setjob, other resources)
AddEventHandler('vorp:playerJobChange', function(src, newJob, oldJob)
    if newJob ~= oldJob then OnLeftJob(src, oldJob) end
    TriggerClientEvent('pup_business:findnewhired', src)
end)

AddEventHandler('vorp:playerJobGradeChange', function(src)
    TriggerClientEvent('pup_business:findnewhired', src)
end)

AddEventHandler('playerDropped', function()
    StashOpenBy[source] = nil
end)

-- closed by the player: a later closeInventory would clear the lock of whatever they open next
RegisterNetEvent('vorp_inventory:Server:CloseCustomInventory', function()
    StashOpenBy[source] = nil
end)

-- a stash opened by the previous character does not stay with the next one
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    local open = src and StashOpenBy[src]
    if not open then return end
    StashOpenBy[src] = nil
    pcall(function() exports.vorp_inventory:closeInventory(src, open) end)
end)

-- stashes this resource opened are closed when it stops
AddEventHandler('onResourceStop', function(name)
    if name ~= RES then return end
    for s, open in pairs(StashOpenBy) do
        pcall(function() exports.vorp_inventory:closeInventory(s, open) end)
    end
    StashOpenBy = {}
end)

---------------------------------------------------------------------------
-- hire (net event used by vorp_admin too)
---------------------------------------------------------------------------

local lastHired = {} -- [target src] = os.time() they were last hired by a recruiter

AddEventHandler('playerDropped', function()
    lastHired[source] = nil
end)

function DoHire(src, target, job)
    local ch = GetChar(src)
    if not ch then return false end
    target = PB.int(target)
    if not target then Notify(src, L('no_person_nearby')) return false end
    job = (type(job) == 'string' and job ~= '') and job or ch.job
    local b = Biz[job]
    if not b then Notify(src, L('not_business')) return false end

    local admin = IsSocietyAdmin(src)
    if not admin then
        if ch.job ~= job or not CanRecruit(job, CharGrade(ch), 'hire') then
            Notify(src, L('no_permission')) return false
        end
    end
    if target == src then Notify(src, L('cant_hire_self')) return false end
    local tch = GetChar(target)
    if not tch then Notify(src, L('no_person_nearby')) return false end
    if tch.job == job then Notify(src, L('already_member')) return false end
    -- a recruiter hires someone standing with them, and not the same person over and over
    if not admin then
        if not WithinOrUnknown(src, target, Config.HireReachServer or 6.0) then Notify(src, L('too_far_to_hire')) return false end
        local wait = tonumber(Config.HireCooldownSeconds) or 60
        if lastHired[target] and Now() - lastHired[target] < wait then Notify(src, L('hire_wait')) return false end
    end

    if not Lock('job:' .. target) then return false end
    ApplyJob(target, job, 0)
    Unlock('job:' .. target)
    if not admin then lastHired[target] = Now() end

    local name = FullName(tch)
    Notify(src, L('you_hired', name))
    Notify(target, L('you_were_hired', job))
    Activity(job, 'HIRE', ('%s was hired (grade 0)'):format(name), FullName(ch))
    SendLog(job, 'Hired', COLOUR.green, table.pack(
        F('Hired by', WhoText(src)), F('New hire', WhoText(target)), F('Starting rank', 'Grade 0', true)))
    return true
end

RegisterNetEvent('pup_business:hire', function(target, job)
    local src = source
    if not Throttle(src, 'hire', 1000) then return end
    if not GetChar(src) then return end
    DoHire(src, target, job)
end)

Handle('hire', 1000, function(src, _, target)
    return DoHire(src, target, nil)
end)

---------------------------------------------------------------------------
-- fire (net event used by vorp_admin too)
---------------------------------------------------------------------------

function DoFire(src, charid, wantJob)
    local ch = GetChar(src)
    if not ch then return false end
    charid = PB.int(charid)
    if not charid then return false end
    if charid == CharId(ch) then Notify(src, L('cant_fire_self')) return false end

    local admin = IsSocietyAdmin(src)
    local targetSrc = SourceOfChar(charid)
    local tch = targetSrc and GetChar(targetSrc)
    local job

    if admin then
        if type(wantJob) == 'string' and Biz[wantJob] then
            job = wantJob
        elseif tch then
            job = tch.job
        else
            job = MySQL.scalar.await('SELECT job FROM characters WHERE charidentifier = ? LIMIT 1', { charid })
        end
        if not job or not Biz[job] then Notify(src, L('char_not_in_business')) return false end
    else
        job = ch.job
        if not Biz[job] or not CanRecruit(job, CharGrade(ch), 'fire') then Notify(src, L('no_permission')) return false end
    end

    local myGrade = CharGrade(ch)
    local boss = admin or (ch.job == job and IsBossGrade(job, myGrade))
    local unemployed = Config.UnemployedJob

    -- re-read: the database lookup above may have waited
    targetSrc = SourceOfChar(charid)
    tch = targetSrc and GetChar(targetSrc)

    if tch then
        if tch.job ~= job then Notify(src, L('not_in_your_job')) return false end
        if not boss and CharGrade(tch) >= myGrade then Notify(src, L('fire_below_only')) return false end
        if not Lock('job:' .. targetSrc) then return false end
        ApplyJob(targetSrc, unemployed, 0)
        Unlock('job:' .. targetSrc)
        local name = FullName(tch)
        Notify(src, L('you_fired', name))
        Notify(targetSrc, L('you_were_fired', job))
        Activity(job, 'FIRE', ('%s was fired'):format(name), FullName(ch))
        SendLog(job, 'Fired', COLOUR.red, table.pack(F('Fired by', WhoText(src)), F('Fired', WhoText(targetSrc))))
        return true
    end

    local n
    if boss then
        n = MySQL.update.await('UPDATE characters SET job = ?, jobgrade = 0 WHERE charidentifier = ? AND job = ?',
            { unemployed, charid, job })
    else
        n = MySQL.update.await('UPDATE characters SET job = ?, jobgrade = 0 WHERE charidentifier = ? AND job = ? AND jobgrade < ?',
            { unemployed, charid, job, myGrade })
    end
    if (tonumber(n) or 0) == 0 then Notify(src, L('fire_offline_failed')) return false end
    MySQL.update('DELETE FROM society_tax WHERE charidentifier = ? AND job = ?', { charid, job })
    Notify(src, L('you_fired_offline', charid))
    Activity(job, 'FIRE', ('Char #%d was fired (offline)'):format(charid), FullName(ch))
    SendLog(job, 'Fired (offline)', COLOUR.red, table.pack(F('Fired by', WhoText(src)), F('Char ID', charid, true)))
    return true
end

RegisterNetEvent('pup_business:fire', function(charid, job)
    local src = source
    if not Throttle(src, 'fire', 1000) then return end
    if not GetChar(src) then return end
    DoFire(src, charid, job)
end)

Handle('fire', 1000, function(src, _, charid)
    return DoFire(src, charid, nil)
end)

---------------------------------------------------------------------------
-- set rank (own business)
---------------------------------------------------------------------------

Handle('setRank', 750, function(src, ch, charid, grade)
    charid, grade = PB.int(charid), PB.int(grade)
    if not charid or not grade then Notify(src, L('invalid_grade')) return false end
    local job, myGrade = ch.job, CharGrade(ch)
    local b = Biz[job]
    if not b then Notify(src, L('not_in_business')) return false end
    if charid == CharId(ch) then Notify(src, L('cant_rank_self')) return false end

    local admin = IsSocietyAdmin(src)
    if not admin then
        if not CanRecruit(job, myGrade, 'setranks') then Notify(src, L('no_permission')) return false end
        if grade >= myGrade then Notify(src, L('rank_at_or_above', myGrade)) return false end
    end
    grade = math.max(0, math.min(grade, b.bossrank))
    local boss = admin or IsBossGrade(job, myGrade)

    local targetSrc = SourceOfChar(charid)
    local tch = targetSrc and GetChar(targetSrc)
    if tch then
        if tch.job ~= job then Notify(src, L('not_in_your_job')) return false end
        if not boss and CharGrade(tch) >= myGrade then Notify(src, L('rank_below_only')) return false end
        if not Lock('job:' .. targetSrc) then return false end
        ApplyJob(targetSrc, job, grade)
        Unlock('job:' .. targetSrc)
        local name = FullName(tch)
        Notify(src, L('rank_changed', name, grade))
        Notify(targetSrc, L('your_rank_changed', grade))
        Activity(job, 'RANK', ('%s set to grade %d'):format(name, grade), FullName(ch))
        SendLog(job, 'Rank changed', COLOUR.yellow, table.pack(
            F('Changed by', WhoText(src)), F('Member', WhoText(targetSrc)), F('New rank', grade, true)))
        return true
    end

    local n
    if boss then
        n = MySQL.update.await('UPDATE characters SET jobgrade = ? WHERE charidentifier = ? AND job = ?', { grade, charid, job })
    else
        n = MySQL.update.await('UPDATE characters SET jobgrade = ? WHERE charidentifier = ? AND job = ? AND jobgrade < ?',
            { grade, charid, job, myGrade })
    end
    if (tonumber(n) or 0) == 0 then Notify(src, L('rank_offline_failed')) return false end
    Notify(src, L('rank_changed', ('#%d'):format(charid), grade))
    Activity(job, 'RANK', ('Char #%d set to grade %d (offline)'):format(charid, grade), FullName(ch))
    SendLog(job, 'Rank changed (offline)', COLOUR.yellow, table.pack(
        F('Changed by', WhoText(src)), F('Member', ('Char ID: %d'):format(charid)), F('New rank', grade, true)))
    return true
end)

---------------------------------------------------------------------------
-- online members of a business (own members and society admins only)
---------------------------------------------------------------------------

function OnlineMembers(job)
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local sid = tonumber(s)
        local och = GetChar(sid)
        if och and och.job == job then
            out[#out + 1] = { id = sid, name = FullName(och), charid = CharId(och), grade = CharGrade(och) }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

Handle('members', 500, function(src, ch)
    local job = ch.job
    if not Biz[job] then return {} end
    return OnlineMembers(job)
end)
