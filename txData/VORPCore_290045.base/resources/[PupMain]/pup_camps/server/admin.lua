-- pup_camps | vorp_admin "Camps" page bridge. vorp_admin checks its own permissions
-- (manage_camps / delete_camp) before it calls these exports.

local function hasMeta(m) return type(m) == 'table' and next(CleanMeta(m)) ~= nil end

local function leaderInfo(camp)
    local lid = tonumber(camp.leader)
    if not lid then return nil end
    for _, m in ipairs(camp.members) do
        if tonumber(m.charid) == lid then return { charid = lid, name = m.name } end
    end
    return { charid = lid, name = ('char %d'):format(lid) }
end

exports('AdminList', function()
    local list = {}
    for _, camp in pairs(Camps) do
        local members = {}
        for _, m in ipairs(camp.members) do members[#members + 1] = { charid = m.charid, name = m.name } end
        local items = {}
        for _, e in ipairs(camp.inventory) do
            items[#items + 1] = { name = e.name, label = e.label, count = e.count, meta = hasMeta(e.metadata) }
        end
        list[#list + 1] = {
            id = camp.id, name = camp.name, coords = camp.coords,
            leader = leaderInfo(camp), members = members,
            memberCount = #camp.members, memberLimit = Config.Camp.maxMembers,
            cash = camp.cash, taxmoney = camp.taxmoney, invlimit = camp.invlimit,
            items = items, itemCount = #items,
            furniCount = U.placedCount(camp.furni), furniLimit = Config.Camp.maxPieces,
            repo = camp.repo == true, haswebhook = camp.webhook ~= nil and camp.webhook ~= '',
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { list = list, now = os.time() }
end)

local function wholeIn(v, lo, hi)
    local n = tonumber(v)
    if not n or n ~= n or n ~= math.floor(n) or n < lo or n > hi then return nil end
    return math.floor(n)
end

local actions = {}

actions.setledger = function(camp, data)
    local n = wholeIn(data.value, 0, 1000000000)
    if not n then return false, 'Amount must be a whole number from 0 to 1,000,000,000.' end
    camp.cash = n
    PushCamp(camp)
    return true, ('%s safe set to %s'):format(CampTitle(camp), U.money(n))
end

actions.wipeledger = function(camp)
    camp.cash = 0
    PushCamp(camp)
    return true, ('%s safe emptied'):format(CampTitle(camp))
end

actions.settax = function(camp, data)
    local n = wholeIn(data.value, 0, 1000000000)
    if not n then return false, 'Amount must be a whole number from 0 to 1,000,000,000.' end
    camp.taxmoney = n
    PushCamp(camp)
    return true, ('%s tax ledger set to %s'):format(CampTitle(camp), U.money(n))
end

actions.wipetax = function(camp)
    camp.taxmoney = 0
    PushCamp(camp)
    return true, ('%s tax ledger emptied'):format(CampTitle(camp))
end

actions.rename = function(camp, data)
    local name = U.trim(type(data.value) == 'string' and data.value or (type(data.name) == 'string' and data.name or ''))
    if #name < 1 or #name > 48 then return false, 'Name must be 1-48 characters.' end
    local old = CampTitle(camp)
    camp.name = name
    PushCamp(camp)
    return true, ('%s renamed to %s'):format(old, name)
end

-- a real override: kept across furniture changes and restarts
actions.setlimit = function(camp, data)
    local n = wholeIn(data.value, 0, 100000)
    if not n then return false, 'Storage limit must be a whole number from 0 to 100000.' end
    camp.invoverride = n
    RecomputeStorage(camp)
    PushCamp(camp)
    return true, ('%s storage limit set to %d'):format(CampTitle(camp), n)
end

actions.removeitem = function(camp, data)
    local name = type(data.item) == 'string' and data.item or nil
    if not name then return false, 'No item named.' end
    for i, e in ipairs(camp.inventory) do
        if e.name == name then
            table.remove(camp.inventory, i)
            ReloadStashViewers(camp)
            return true, ('Removed %s x%d from %s'):format(e.label or name, e.count, CampTitle(camp))
        end
    end
    return false, 'That item is not in the stash.'
end

actions.wipestash = function(camp)
    local n = #camp.inventory
    camp.inventory = {}
    ReloadStashViewers(camp)
    return true, ('%s stash emptied (%d stacks)'):format(CampTitle(camp), n)
end

actions.removemember = function(camp, data)
    local cid = tonumber(data.charid)
    if not cid then return false, 'No character id.' end
    if IsLeader(camp, cid) then return false, 'The leader cannot be removed. Set a new leader first.' end
    local idx, m = FindMember(camp, cid)
    if not idx then return false, 'That character is not a member.' end
    table.remove(camp.members, idx)
    SetCharClan(cid, 0)
    local s = SrcOfChar(cid)
    if s then
        Notify(s, L('kicked_you', camp.name))
        PushMyCamp(s)
    end
    OnMembershipLost(cid, camp.id)
    PushCamp(camp)
    return true, ('%s removed from %s'):format(m.name, CampTitle(camp))
end

actions.addmember = function(camp, data)
    local cid = tonumber(data.charid)
    if not cid then return false, 'No character id.' end
    local row = MySQL.single.await('SELECT charidentifier, firstname, lastname, clan FROM characters WHERE charidentifier = ?', { cid })
    if not row then return false, 'No character with that id.' end
    -- re-check after the await: the camp may be gone or changed
    if Camps[camp.id] ~= camp then return false, 'The camp no longer exists.' end
    if FindMember(camp, cid) or IsLeader(camp, cid) then return false, 'Already a member.' end
    local other = CampOfChar(cid)
    if other or (tonumber(row.clan) or 0) ~= 0 and Camps[tonumber(row.clan)] then return false, 'That character is in another camp.' end
    if CampFull(camp) then return false, ('The camp is full (max %d).'):format(Config.Camp.maxMembers) end
    local name = U.trim(('%s %s'):format(tostring(row.firstname or ''), tostring(row.lastname or '')))
    camp.members[#camp.members + 1] = { name = name, charid = cid, rank = Config.Ranks[1].id }
    SetCharClan(cid, camp.id)
    local s = SrcOfChar(cid)
    if s then
        Notify(s, L('joined_you', camp.name))
        PushMyCamp(s)
    end
    PushCamp(camp)
    return true, ('%s added to %s'):format(name, CampTitle(camp))
end

actions.setleader = function(camp, data)
    local cid = tonumber(data.charid)
    if not cid then return false, 'No character id.' end
    local idx, m = FindMember(camp, cid)
    if not idx then return false, 'They have to be a member first.' end
    camp.leader = cid
    local s = SrcOfChar(cid)
    if s then Notify(s, L('leadership_yours', camp.name)) end
    PushCamp(camp)
    return true, ('%s now leads %s'):format(m.name, CampTitle(camp))
end

actions.repo = function(camp)
    return RepoCamp(camp, true)
end

actions.unrepo = function(camp)
    return UnrepoCamp(camp, true)
end

actions.delete = function(camp)
    local title = CampTitle(camp)
    DisbandCamp(camp, 'Camp Deleted (Admin Panel)', nil)
    return true, title .. ' deleted'
end

exports('AdminAction', function(action, campId, data)
    if type(action) ~= 'string' or not actions[action] then return false, 'Unknown action.' end
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return false, 'No camp with that id.' end
    data = type(data) == 'table' and data or {}
    local ok, done, msg = pcall(actions[action], camp, data)
    if not ok then
        print('^1[pup_camps]^7 admin action failed: ' .. tostring(done))
        return false, 'Internal error.'
    end
    if done and action ~= 'delete' and Camps[camp.id] == camp then Save(camp) end
    return done == true, msg
end)
