-- pup_camps | staff commands (chat or console)

local function reply(src, msg)
    if src == 0 then print('[pup_camps] ' .. msg) else Notify(src, msg, 8000) end
end

-- console, group admin, or (for repo/unrepo) a vorp_admin user allowed delete_camp
local function allowed(src, adminAction)
    if src == 0 or IsStaff(src) then return true end
    if adminAction then
        local ok, yes = pcall(Integrations.adminAllowed, src, adminAction)
        if ok and yes then return true end
    end
    return false
end

local function campArg(src, raw, cmd, usage)
    local camp = Camps[tonumber(raw) or -1]
    if not camp then
        reply(src, raw and L('staff_no_camp') or L('staff_usage', cmd, usage))
        return nil
    end
    return camp
end

------------------------------------------------------------------------------ shut down / reopen (shared with the admin panel)

function RepoCamp(camp, byStaff)
    if camp.repo then return false, L('staff_already_repo') end
    ShutCamp(camp)
    local title = CampTitle(camp)
    CampLetter(camp, 'Camp Repossessed: ' .. title,
        ('%s has been repossessed by staff and is hidden from the map. Speak to staff to have it restored.'):format(title))
    if byStaff then
        CampLog(camp, 'camp', 'Camp Repossessed (staff)', LogColour.orange, {}, { system = true, description = title .. ' was repossessed by staff.' })
    end
    return true, L('staff_repo', title)
end

function UnrepoCamp(camp, byStaff)
    if not camp.repo then return false, L('staff_not_repo') end
    camp.repo = false
    Save(camp)
    PushCamp(camp, true)
    local title = CampTitle(camp)
    CampLetter(camp, 'Camp Restored: ' .. title,
        ('%s has been restored by staff and is back on the map.'):format(title))
    if byStaff then
        CampLog(camp, 'camp', 'Camp Restored (staff)', LogColour.green, {}, { system = true, description = title .. ' was restored by staff.' })
    end
    return true, L('staff_unrepo', title)
end

------------------------------------------------------------------------------ commands

local C = Config.Commands

RegisterCommand(C.repo, function(src, args)
    if not allowed(src, 'delete_camp') then return reply(src, L('staff_denied')) end
    local camp = campArg(src, args[1], C.repo, '<camp id>')
    if not camp then return end
    local _, msg = RepoCamp(camp, true)
    reply(src, msg)
end, false)

RegisterCommand(C.unrepo, function(src, args)
    if not allowed(src, 'delete_camp') then return reply(src, L('staff_denied')) end
    local camp = campArg(src, args[1], C.unrepo, '<camp id>')
    if not camp then return end
    local _, msg = UnrepoCamp(camp, true)
    reply(src, msg)
end, false)

RegisterCommand(C.resetFurni, function(src, args)
    if not allowed(src) then return reply(src, L('staff_denied')) end
    local camp = campArg(src, args[1], C.resetFurni, '<camp id>')
    if not camp then return end
    for id, p in pairs(camp.furni) do
        if p.item ~= Config.Camp.flagItem then camp.furni[id] = nil end
    end
    RecomputeStorage(camp)
    Save(camp)
    PushCamp(camp, true)
    reply(src, L('staff_furni_reset', CampTitle(camp)))
end, false)

RegisterCommand(C.changeLead, function(src, args)
    if not allowed(src) then return reply(src, L('staff_denied')) end
    local target = tonumber(args[1])
    local camp = Camps[tonumber(args[2]) or -1]
    if not target or not camp then return reply(src, L('staff_usage', C.changeLead, '<player id> <camp id>')) end
    local tctx = Ctx(target)
    if not tctx then return reply(src, L('player_offline')) end
    -- the new leader must already ride with the camp
    if not FindMember(camp, tctx.charid, tctx.identifier) then return reply(src, L('staff_not_member')) end
    camp.leader = tctx.charid
    Save(camp)
    PushCamp(camp)
    Notify(target, L('leadership_yours', camp.name))
    reply(src, L('staff_leader', tctx.name, CampTitle(camp)))
end, false)

RegisterCommand(C.cycle, function(src)
    if not allowed(src) then return reply(src, L('staff_denied')) end
    CampDay()
    for _, camp in pairs(Camps) do PushCamp(camp) end
    reply(src, L('staff_cycled'))
end, false)

RegisterCommand(C.syncMembers, function(src)
    if not allowed(src) then return reply(src, L('staff_denied')) end
    CreateThread(function()
        MemberSync()
        reply(src, L('staff_synced'))
    end)
end, false)

RegisterCommand(C.resetRaids, function(src)
    if not allowed(src) then return reply(src, L('staff_denied')) end
    local n = 0
    for _, camp in pairs(Camps) do
        if camp.raid > 0 then
            camp.raid = 0
            Save(camp)
            PushCamp(camp)
            n = n + 1
        end
    end
    reply(src, L('staff_raids_reset', n))
end, false)
