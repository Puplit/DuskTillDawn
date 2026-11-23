-- pup_camps | the camp menu at the flag, the ledger, members, name/blip, invites

CampMenu = {}

local lockBlockedUntil = {}  -- [campId] = game timer
local FLAG_REACH <const> = 1.5

function CanDo(view, action)
    if not view or not view.member then return false end
    return U.meets(view.rank, view.isLeader, Config.Permissions[action] or 'leader')
end

local function camp(id) return State.camps[id] end

local function header(view)
    local days = math.floor((tonumber(view.lifecycle) or 0) / Config.RestartsPerDay)
    return L('camp_id', view.id) .. '   ' .. L('days_up', days)
end

------------------------------------------------------------------------------ ledger

local function ledgerPage(id)
    local v = camp(id)
    if not v then return nil end
    local rows = {}
    local open = not v.repo   -- a shut-down camp only takes tax payments
    if open and CanDo(v, 'withdraw') then
        rows[#rows + 1] = { label = L('withdraw'), description = L('withdraw_desc'), onSelect = function()
            local n = Menu.amount(L('withdraw'))
            if n and Ask('withdraw', id, n) then Menu.replace(ledgerPage(id)) end
        end }
    end
    if open and CanDo(v, 'deposit') then
        rows[#rows + 1] = { label = L('deposit'), description = L('deposit_desc'), onSelect = function()
            local n = Menu.amount(L('deposit'))
            if n and Ask('deposit', id, n) then Menu.replace(ledgerPage(id)) end
        end }
    end
    if CanDo(v, 'tax') then
        rows[#rows + 1] = { label = L('tax_money', U.money(v.tax or 0)), description = L('tax_desc', U.money(Config.Tax.amount)), onSelect = function()
            local n = Menu.amount(L('tax_money', U.money(v.tax or 0)))
            if not n then return end
            local cur = camp(id)
            if (cur and cur.tax or 0) + n > Config.Tax.ledgerCap then
                return Notify(L('tax_cap', U.money(Config.Tax.ledgerCap)))
            end
            if Ask('tax', id, n) then Menu.replace(ledgerPage(id)) end
        end }
    end
    if open and CanDo(v, 'takeAll') then
        rows[#rows + 1] = { label = L('take_all'), description = L('take_all_desc'), onSelect = function()
            if Ask('takeAll', id) then Menu.replace(ledgerPage(id)) end
        end }
    end
    return { title = L('ledger'), subtitle = L('ledger_balance', U.money(v.cash or 0)), rows = rows }
end

------------------------------------------------------------------------------ members

local function memberCountText(v)
    if Config.Camp.maxMembers and Config.Camp.maxMembers > 0 then
        return L('members_count', v.memberCount or 0, Config.Camp.maxMembers)
    end
    return L('members_count_nolimit', v.memberCount or 0)
end

local membersPage, memberList

local function rankPage(id, m)
    local v = camp(id)
    if not v then return nil end
    local rows = {}
    for _, r in ipairs(Config.Ranks) do
        local blocked = r.id == m.rank
        if not v.isLeader and U.rankIndex(r.id) >= U.rankIndex(v.rank) then blocked = true end
        rows[#rows + 1] = {
            label = r.label .. (r.id == m.rank and (' ' .. L('current')) or ''), disabled = blocked,
            onSelect = function()
                if Ask('setRank', id, m.charid, r.id) then
                    Menu.back()
                    Menu.back()
                    Menu.replace(memberList(id))
                end
            end,
        }
    end
    return { title = L('set_rank'), subtitle = L('current_rank', U.rankLabel(m.rank)), rows = rows }
end

local function memberOptions(id, m)
    local v = camp(id)
    if not v then return nil end
    local rows = {}
    if CanDo(v, 'kick') then
        rows[#rows + 1] = { label = L('kick'), onSelect = function()
            Menu.confirm(L('confirm_title'), L('kick_confirm', m.name), function()
                if Ask('kick', id, m.charid) then
                    Menu.back()
                    Menu.back()
                    Menu.replace(memberList(id))
                else
                    Menu.back()
                end
            end)
        end }
    end
    if v.isLeader then
        rows[#rows + 1] = { label = L('transfer'), onSelect = function()
            Menu.confirm(L('confirm_title'), L('transfer_confirm', m.name), function()
                if Ask('transfer', id, m.charid) then
                    Menu.closeAll()
                else
                    Menu.back()
                end
            end)
        end }
    end
    if CanDo(v, 'setRank') then
        rows[#rows + 1] = { label = L('set_rank'), description = L('current_rank', U.rankLabel(m.rank)), onSelect = function()
            local page = rankPage(id, m)
            if page then Menu.push(page) end
        end }
    end
    return { title = m.name, subtitle = U.rankLabel(m.rank), rows = rows }
end

memberList = function(id)
    local v = camp(id)
    if not v then return nil end
    local manage = v.isLeader or CanDo(v, 'kick') or CanDo(v, 'setRank')
    local rows = {}
    for _, m in ipairs(v.members or {}) do
        local isLeader = tonumber(m.charid) == tonumber(v.leader)
        local label = L('member_row', m.name, isLeader and U.rankLabel('leader') or U.rankLabel(m.rank))
        local row = { label = label }
        if manage and not isLeader and tonumber(m.charid) ~= tonumber(State.charid) then
            row.description = L('member_options')
            row.onSelect = function()
                local page = memberOptions(id, m)
                if page and #page.rows > 0 then Menu.push(page) end
            end
        end
        rows[#rows + 1] = row
    end
    return { title = L('view_members'), subtitle = memberCountText(v), rows = rows }
end

membersPage = function(id)
    local v = camp(id)
    if not v then return nil end
    local rows = {}
    if CanDo(v, 'invite') then
        rows[#rows + 1] = { label = L('invite'), description = L('invite_desc'), onSelect = function()
            local vals = Menu.input(L('invite'), { { label = L('invite_field'), type = 'number', min = 1, required = true } })
            local sid = vals and tonumber(vals[1])
            if sid then Ask('invite', id, math.floor(sid)) end
        end }
    end
    rows[#rows + 1] = { label = L('view_members'), onSelect = function()
        local page = memberList(id)
        if page then Menu.push(page) end
    end }
    return { title = L('members'), subtitle = L('camp_id', id) .. '   ' .. memberCountText(v), rows = rows }
end

------------------------------------------------------------------------------ name & blip

local function blipPage(id)
    local v = camp(id)
    if not v then return nil end
    local pendingName = v.name
    local colour = v.bcolor or 1
    local values = {}
    for i = 1, Config.Camp.blipColours do values[i] = tostring(i) end
    local page
    page = {
        title = L('blip_menu'), subtitle = v.name,
        onBack = function()
            World.previewColour(nil)
            Menu.back()
        end,
        rows = {
            { label = L('change_name'), description = pendingName, onSelect = function(row)
                local name = Menu.text(L('change_name'), L('name_field'), pendingName, Config.Camp.nameMax)
                if name and name ~= '' then
                    pendingName = name:sub(1, Config.Camp.nameMax)
                    row.description = pendingName
                    page.subtitle = pendingName
                    Menu.replace(page)
                end
            end },
            { label = L('blip_colour'), values = values, valueIndex = colour, onChange = function(_, vi)
                colour = vi
                World.previewColour(vi)
            end },
            { label = L('confirm_changes'), description = L('cost', U.money(Config.Camp.blipPrice)), onSelect = function()
                if Ask('blipSave', id, pendingName, colour) then
                    World.previewColour(nil)
                    Menu.closeAll()
                    Scenario(Config.Anim.notebook, 4000)
                    Wait(4000)
                    StopScenario()
                end
            end },
        },
    }
    return page
end

------------------------------------------------------------------------------ root

local function rootPage(id, info)
    local v = camp(id)
    if not v then return nil end
    local rows = {}
    if v.member and v.repo then
        -- shut down: the tax ledger is the only thing that still works
        if CanDo(v, 'ledger') then
            rows[#rows + 1] = { label = L('ledger'), description = L('camp_shut'), onSelect = function()
                local page = ledgerPage(id)
                if page then Menu.push(page) end
            end }
        end
    elseif v.member then
        if CanDo(v, 'ledger') then
            rows[#rows + 1] = { label = L('ledger'), description = L('ledger_desc'), onSelect = function()
                local page = ledgerPage(id)
                if page then Menu.push(page) end
            end }
        end
        rows[#rows + 1] = { label = L('members'), description = L('members_desc'), onSelect = function()
            local page = membersPage(id)
            if page then Menu.push(page) end
        end }
        if CanDo(v, 'furniture') then
            rows[#rows + 1] = { label = L('furniture'), description = L('furniture_desc'), onSelect = function()
                Furniture.openMenu(id)
            end }
        end
        if CanDo(v, 'blip') then
            rows[#rows + 1] = { label = L('blip_menu'), description = L('blip_menu_desc'), onSelect = function()
                local page = blipPage(id)
                if page then Menu.push(page) end
            end }
        end
        if CanDo(v, 'relocate') then
            rows[#rows + 1] = { label = L('move_camp'), description = L('move_camp_desc', U.money(Config.Camp.relocatePrice)), onSelect = function()
                if Ask('relocateCheck', id) then
                    Menu.closeAll()
                    Founding.startMoving(id)
                end
            end }
        end
        if v.isLeader then
            rows[#rows + 1] = { label = L('disband'), description = L('disband_desc'), onSelect = function()
                Menu.confirm(L('confirm_title'), L('disband_warn'), function()
                    if Ask('disband', id) then Menu.closeAll() else Menu.back() end
                end)
            end }
        end
        if Config.Logs.campWebhooks and CanDo(v, 'webhook') then
            rows[#rows + 1] = { label = L('add_webhook'), description = L('add_webhook_desc'), onSelect = function()
                local url = Menu.text(L('add_webhook'), L('webhook_field'), '', 300)
                if not url then return end
                url = url:gsub('%s+', '')
                if not U.isWebhook(url) then return Notify(L('webhook_invalid')) end
                Ask('webhook', id, url)
            end }
        end
        if not v.isLeader then
            rows[#rows + 1] = { label = L('leave'), description = L('leave_desc'), onSelect = function()
                Menu.confirm(L('confirm_title'), L('leave_desc'), function()
                    if Ask('leave', id) then Menu.closeAll() else Menu.back() end
                end)
            end }
        end
    elseif info and not Raid.ownCampUnderRaid() then
        if info.open then
            rows[#rows + 1] = { label = L('take_cash', U.money(info.cash or v.cash or 0)), onSelect = function()
                Ask('raidTakeCash', id)
                Menu.closeAll()
            end }
            if (v.invlimit or 0) > 0 then
                rows[#rows + 1] = { label = L('storage_action'), onSelect = function()
                    Menu.closeAll()
                    Functional.openStash(id)
                end }
            end
        elseif not info.cooldown and not info.running then
            if not Config.Raids.membersOnly or (State.myCamp or 0) ~= 0 then
                rows[#rows + 1] = { label = L('raid_camp'), description = L('raid_camp_desc'), onSelect = function()
                    Ask('raidStart', id)
                    Menu.closeAll()
                end }
            end
        else
            rows[#rows + 1] = { label = L('raided_recently'), description = L('raided_recently_desc'), disabled = true }
        end
    end
    if #rows == 0 then rows[1] = { label = v.name, disabled = true } end
    return { title = L('menu_title'), subtitle = header(v), rows = rows, refresh = function() return rootPage(id, info) end }
end

-- take the camp's menu lock; false (with the reason shown) when someone else holds it
function CampMenu.takeLock(id)
    if lockBlockedUntil[id] and GetGameTimer() < lockBlockedUntil[id] then return false end
    local ok, why = Request('lock', id)
    if not ok then
        if why then Notify(why) end
        if why == L('menu_in_use') then lockBlockedUntil[id] = GetGameTimer() + Config.Camp.lockRetrySec * 1000 end
        return false
    end
    return true
end

function CampMenu.open(id)
    local v = camp(id)
    if not v or State.busy then return end
    if Raid.canPick(id) then return Raid.pick(id) end
    local info = nil
    local locked = false
    if not v.member then
        info = Request('outsider', id)
        if type(info) ~= 'table' then return end
        if info.open then
            if not CampMenu.takeLock(id) then return end
            locked = true
        end
    else
        if not CampMenu.takeLock(id) then return end
        locked = true
    end
    local page = rootPage(id, info)
    if not page then
        if locked then Request('unlock', id) end
        return
    end
    if not Menu.begin({ campId = id, onClose = function()
        World.previewColour(nil)
        if locked then Request('unlock', id) end
    end }) then
        if locked then Request('unlock', id) end
        return
    end
    if v.member and v.repo then Notify(L('camp_shut')) end
    Menu.push(page)
end

------------------------------------------------------------------------------ prompt at the flag

Interact.add(function(pos)
    local v, d = World.renderedNear(pos, FLAG_REACH)
    if not v then
        -- a shut-down camp is hidden, but its members can still reach the ledger at the spot
        local mine = MyCamp()
        if mine and mine.repo and U.dist3(pos, mine.coords) <= FLAG_REACH then
            v, d = mine, U.dist3(pos, mine.coords)
        end
    end
    if not v then return nil end
    if Raid.waiting(v.id) then return nil end
    local title = Raid.canPick(v.id) and L('pick_lock', v.name) or L('camp_suffix', v.name)
    return {
        dist = d, title = title,
        keys = { { control = Config.Keys.interact, label = Raid.canPick(v.id) and L('pick_lock_action') or L('open_menu'), fn = function() CampMenu.open(v.id) end } },
    }
end)

------------------------------------------------------------------------------ invites

RegisterNetEvent('pup_camps:cl:invite', function(campId, name)
    campId = tonumber(campId)
    if not campId then return end
    State.invites[campId] = tostring(name or ('#' .. campId))
end)

local function invitesPage()
    local rows = {}
    for id, name in pairs(State.invites) do
        rows[#rows + 1] = { label = name, description = L('invite_row_desc'), onSelect = function()
            Menu.push({ title = name, subtitle = L('invites_title'), rows = {
                { label = L('accept'), description = L('accept_desc'), onSelect = function()
                    if Ask('acceptInvite', id) then
                        State.invites[id] = nil
                        Menu.closeAll()
                    end
                end },
                { label = L('decline'), description = L('decline_desc'), onSelect = function()
                    State.invites[id] = nil
                    Menu.back()
                    Menu.replace(invitesPage())
                end },
            } })
        end }
    end
    if #rows == 0 then rows[1] = { label = L('no_invites'), disabled = true } end
    return { title = L('invites_title'), subtitle = L('invites_desc'), rows = rows }
end

RegisterCommand(Config.Commands.invites, function()
    if not State.started or State.busy then return end
    if next(State.invites) == nil then return Notify(L('no_invites')) end
    if Menu.begin({ noFreeze = true }) then Menu.push(invitesPage()) end
end, false)

OnState('mycamp', function(id)
    if id ~= 0 then State.invites = {} end
end)
