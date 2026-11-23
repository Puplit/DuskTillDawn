-- pup_business | exports for other resources

exports('AddToLedger', function(job, amount, reason, who)
    return AddToLedger(job, amount, reason, who)
end)

exports('IsPlayerOnDuty', function(src)
    src = tonumber(src)
    if not src then return false end
    return IsOnDutyMerged(src)
end)

exports('SetPlayerDuty', function(src, on, region)
    src = tonumber(src)
    if not src or not GetChar(src) then return end
    SetDuty(src, on == true, region, { quiet = true })
end)

exports('GetPlayersOnDuty', function(job)
    local out = {}
    for s, e in pairs(MergedRoster()) do
        if job == nil or e.job == job then out[#out + 1] = s end
    end
    table.sort(out)
    return out
end)

exports('GetDutyRegion', function(src)
    src = tonumber(src)
    if not src then return nil end
    local e = MergedRoster()[src]
    return e and e.region or nil
end)

exports('HasPerm', function(src, key)
    local ch = GetChar(src)
    if not ch or not Biz[ch.job] or type(key) ~= 'string' then return false end
    return HasRankPerm(ch.job, CharGrade(ch), key)
end)

exports('GetBusinessName', function(job)
    if type(job) ~= 'string' then return nil end
    return DisplayName(job)
end)

exports('GetJobWebhook', function(job)
    if type(job) ~= 'string' then return nil end
    return BusinessWebhook(job)
end)

exports('GetBusinessInfo', function(src)
    local ch = GetChar(src)
    if not ch then return nil end
    local b = Biz[ch.job]
    if not b then return nil end
    local grade = CharGrade(ch)
    return {
        job = ch.job,
        name = DisplayName(ch.job),
        grade = grade,
        bossrank = b.bossrank,
        isBoss = grade >= b.bossrank,
        canSend = HasRankPerm(ch.job, grade, 'mail'),
    }
end)
