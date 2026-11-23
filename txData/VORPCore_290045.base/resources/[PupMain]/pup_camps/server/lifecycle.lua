-- pup_camps | start-up, camp day, member sync, character select, disconnect

------------------------------------------------------------------------------ cross-module hooks

function OnMembershipLost(charid, campId)
    charid = tonumber(charid)
    if not charid then return end
    local src = SrcOfChar(charid)
    if src then ReleaseLocksOf(src) end
    MissionsMemberLost(charid, campId)
    RaidsMemberLost(charid, campId)
    StashPrune(campId)
end

function OnCampHidden(campId)
    MenuLocks[campId] = nil
    MissionsCampGone(campId)
    RaidsCampGone(campId)
    StashPrune(campId)
end

function OnCampGone(campId)
    OnCampHidden(campId)
end

------------------------------------------------------------------------------ camp day & member sync

function CampDay()
    local n = 0
    for _, camp in pairs(Camps) do
        camp.lifecycle = camp.lifecycle + 1
        if camp.raid > 0 then camp.raid = camp.raid - 1 end
        Save(camp)
        n = n + 1
    end
    print(('^2[pup_camps]^7 camp day: %d camps aged, raid cooldowns ticked down'):format(n))
end

-- fix one character: a pointer to a missing camp is cleared; a pointer to a camp that does
-- not list them adds them back. Returns the camp id (or nil) and whether anything changed.
local function repairOne(charid, clan, first, last)
    clan = tonumber(clan) or 0
    if clan == 0 then return nil, false end
    local camp = Camps[clan]
    if not camp then
        SetCharClan(charid, 0)
        return nil, true
    end
    if not FindMember(camp, charid) and not IsLeader(camp, charid) then
        camp.members[#camp.members + 1] = {
            name = U.trim(('%s %s'):format(tostring(first or ''), tostring(last or ''))),
            charid = charid, rank = Config.Ranks[1].id,
        }
        Save(camp)
        return clan, true
    end
    return clan, false
end

function MemberSync()
    local rows = MySQL.query.await('SELECT charidentifier, clan, firstname, lastname FROM characters WHERE clan IS NOT NULL AND clan <> 0') or {}
    local cleared, added = 0, 0
    for _, r in ipairs(rows) do
        local cid = tonumber(r.charidentifier)
        if cid then
            local before = Camps[tonumber(r.clan) or -1] ~= nil
            local _, changed = repairOne(cid, r.clan, r.firstname, r.lastname)
            if changed then
                if before then added = added + 1 else cleared = cleared + 1 end
            end
        end
    end
    print(('^2[pup_camps]^7 member sync: %d pointers cleared, %d members added back'):format(cleared, added))
    for _, camp in pairs(Camps) do PushCamp(camp) end
end

local function repairChar(charid)
    local row = MySQL.single.await('SELECT clan, firstname, lastname FROM characters WHERE charidentifier = ?', { charid })
    if not row then return false end
    local _, changed = repairOne(charid, row.clan, row.firstname, row.lastname)
    -- a member whose pointer is wrong gets it set to the camp that lists them
    local listed = CampOfChar(charid)
    if listed and (tonumber(row.clan) or 0) ~= listed then
        SetCharClan(charid, listed)
        changed = true
    end
    return changed
end

------------------------------------------------------------------------------ players

local function startPlayer(src, quick)
    local ctx = Ctx(src)
    if not ctx then return end
    local p = Players[src]
    p.started = true
    local list = {}
    for _, camp in pairs(Camps) do list[#list + 1] = View(camp, src) end
    TriggerClientEvent('pup_camps:cl:start', src, {
        charid = ctx.charid, camp = ctx.camp or 0, camps = list, poisonDelay = quick and 0 or 10,
    })
    PushWagons(src)
end

AddEventHandler('vorp:SelectedCharacter', function(src, character)
    src = tonumber(src)
    if not src then return end
    local cid = character and tonumber(character.charIdentifier)
    -- a new character on this source: drop everything from the old one first
    local p = Players[src]
    if p and cid and p.charid ~= cid then PlayerLeft(src, 'switch') end
    SetTimeout(5000, function()
        if not GetPlayerName(src) then return end
        while not Ready do Wait(500) end
        local ctx = Ctx(src)
        if not ctx then return end
        local changed = repairChar(ctx.charid)
        startPlayer(src, changed)
    end)
end)

-- the client asks after a resource restart or its own character-selected event
Handle('hello', function(ctx, restarted)
    local p = Players[ctx.src]
    if p and p.started and not restarted then return true end
    local changed = repairChar(ctx.charid)
    startPlayer(ctx.src, changed or restarted == true)
    return true
end, { gapMs = 3000 })

function PlayerLeft(src, why)
    local p = Players[src]
    ReleaseLocksOf(src)
    StashForget(src)
    MissionsForget(src)
    RaidsForget(src)
    if p then
        HuntingForget(src, p.charid)
        if why == 'drop' then Invites[p.charid] = nil end
    end
    Players[src] = nil
end

AddEventHandler('playerDropped', function()
    local src = source
    PlayerLeft(src, 'drop')
    RequestsForget(src)
end)

------------------------------------------------------------------------------ boot

CreateThread(function()
    Wait(2000)
    EnsureSchema()
    LoadCamps()
    Ready = true
    Wait(3000)
    CampDay()
    MemberSync()
    while true do
        Wait(Config.SaveEveryMin * 60000)
        SaveAll()
    end
end)
