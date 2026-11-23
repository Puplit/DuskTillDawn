-- pup_staffdesk | the desk panel (pup-ui App): Parcels, Character, Bounty, Playtime, Staff
DeskPanel = {}

local Core = exports.vorp_core:GetCore()
local OWNER <const> = 'pup_staffdesk'
local IMG <const> = Config.General.imagePath

local S = nil       -- panel state while open
local pending = nil -- what the open input dialog is for

local function ask(req) return Core.Callback.TriggerAwait('pup_staffdesk:panel', req) end
local function tip(msg) if msg then TriggerEvent('vorp:TipRight', msg, 4500) end end

-- an answer a tab can draw. No answer, or a refusal ({ ok = false, msg }), draws as the empty tab.
local function view(req, empty)
    local res = ask(req)
    if type(res) ~= 'table' or res.ok == false then return empty end
    return res
end

local function picture(kind, name)
    if kind == 'cash' then return IMG .. 'money.png' end
    return IMG .. tostring(name):lower() .. '.png'
end

local function tabs()
    local t = {
        { id = 'parcels',  label = Locale.tabParcels,  icon = 'box' },
        { id = 'changes',  label = Locale.tabChanges,  icon = 'user' },
    }
    if Config.Bounty.enabled then t[#t + 1] = { id = 'bounty', label = Locale.tabBounty, icon = 'coin' } end
    t[#t + 1] = { id = 'playtime', label = Locale.tabPlaytime, icon = 'chart' }
    if S and S.staff then t[#t + 1] = { id = 'staff', label = Locale.tabStaff, icon = 'eye' } end
    return t
end

local function money(n) return '$' .. Desk.money(n) end

-------------------------------------------------------------------------------
-- TABS
-------------------------------------------------------------------------------
local render = {}

function render.parcels()
    local data = view({ op = 'parcels' }, { list = {}, discord = true })
    local blocks = { { type = 'heading', text = Locale.tabParcels, sub = Locale.parcelsSub } }
    if #data.list == 0 then
        blocks[#blocks + 1] = { type = 'note', text = Locale.nothingWaiting }
    else
        local items = {}
        for _, p in ipairs(data.list) do
            local sub = p.note ~= '' and p.note or Locale.noNote
            sub = sub .. '  -  ' .. Locale.fromWhen:format(p.by, p.when)
            items[#items + 1] = { img = picture(p.kind, p.name), title = p.what, sub = sub,
                actions = { { id = 'claim:' .. p.id, label = Locale.btnCollect, tone = 'green' } } }
        end
        blocks[#blocks + 1] = { type = 'list', items = items }
        if #data.list > 1 then
            blocks[#blocks + 1] = { type = 'actions', buttons = { { id = 'claimall', label = Locale.btnCollectAll:format(#data.list), tone = 'red' } } }
        end
    end
    if not data.discord then blocks[#blocks + 1] = { type = 'note', text = Locale.noDiscordNote } end
    return blocks
end

function render.changes()
    local state = S   -- the panel can be closed while the server answers
    local d = view({ op = 'changes' }, {})
    state.changes = d
    local blocks = { { type = 'heading', text = Locale.tabChanges, sub = Locale.changesSub } }

    if d.height then
        local cur = d.height.current and math.floor(d.height.current * 100 + 0.5) or 100
        blocks[#blocks + 1] = { type = 'heading', text = Locale.heightTitle, sub = Locale.heightSub:format(cur, money(d.height.price)) }
        blocks[#blocks + 1] = { type = 'stepper', id = 'height', label = Locale.heightLabel, value = state.heightValue or cur,
            min = math.floor(d.height.min * 100 + 0.5), max = math.floor(d.height.max * 100 + 0.5), step = 1,
            buttons = { { id = 'height:preview', label = Locale.btnPreview, tone = 'ghost' },
                        { id = 'height:buy', label = Locale.btnBuyFor:format(money(d.height.price)), tone = 'red' } } }
    end

    if d.rename then
        local sub = d.rename.wait > 0 and Locale.renameWait:format(Desk.wait(d.rename.wait))
            or Locale.renameSub:format(money(d.rename.price))
        blocks[#blocks + 1] = { type = 'heading', text = Locale.renameTitle, sub = sub }
        if d.rename.wait <= 0 then
            blocks[#blocks + 1] = { type = 'actions', buttons = { { id = 'rename', label = Locale.btnRename:format(d.rename.first or '', d.rename.last or ''), tone = 'ghost' } } }
        end
    end

    local function namer(title, list, kind, priceCfg, emptyText)
        if list == nil then return end
        blocks[#blocks + 1] = { type = 'heading', text = title, sub = Locale.namerSub:format(money(priceCfg.price), priceCfg.cooldownDays) }
        if #list == 0 then blocks[#blocks + 1] = { type = 'note', text = emptyText } return end
        local items = {}
        for _, r in ipairs(list) do
            local base = kind == 'pet' and r.breed or r.base
            local named = r.name ~= '' and r.name or nil
            items[#items + 1] = {
                title = named or base,
                sub = r.wait > 0 and Locale.namedRecently:format(Desk.wait(r.wait)) or (named and (base .. ' - ' .. Locale.rename) or (base .. ' - ' .. Locale.notNamed)),
                actions = r.wait > 0 and {} or { { id = kind .. ':' .. r.id, label = named and Locale.btnRenameShort or Locale.btnName, tone = 'ghost' } },
            }
        end
        blocks[#blocks + 1] = { type = 'list', items = items }
    end
    namer(Locale.petTitle, d.pets, 'pet', Config.PetName, Locale.noPets)
    namer(Locale.weaponTitle, d.weapons, 'weapon', Config.WeaponName, Locale.noWeapons)
    return blocks
end

function render.bounty()
    local d = view({ op = 'bounty' }, { balance = { points = 0, earned = 0, spent = 0 }, rewards = {}, history = {} })
    local blocks = {
        { type = 'heading', text = Locale.tabBounty, sub = Locale.bountySub },
        { type = 'stats', items = {
            { value = tostring(d.balance.points), label = Locale.statPoints },
            { value = tostring(d.balance.earned), label = Locale.statEarned },
            { value = tostring(d.balance.spent), label = Locale.statSpent },
        } },
    }
    if #d.rewards == 0 then
        blocks[#blocks + 1] = { type = 'note', text = Locale.noRewards }
    else
        local grid = {}
        for _, r in ipairs(d.rewards) do
            grid[#grid + 1] = { img = IMG .. r.item .. '.png', label = r.label, sub = Locale.pts:format(r.cost), dim = not r.afford, id = 'redeem:' .. r.item }
        end
        blocks[#blocks + 1] = { type = 'grid', items = grid }
    end
    if #d.history > 0 then
        local rows = {}
        for _, h in ipairs(d.history) do
            rows[#rows + 1] = { cells = {
                when = { text = h.when, tone = 'muted' },
                pts = { text = (h.delta > 0 and '+' or '') .. h.delta, tone = h.delta >= 0 and 'badge-green' or 'badge-neutral' },
                why = { text = h.reason ~= '' and h.reason or '-' }, by = { text = h.by, tone = 'muted' },
            } }
        end
        blocks[#blocks + 1] = { type = 'table', title = Locale.historyTitle, perPage = 8, rows = rows, columns = {
            { key = 'when', label = Locale.colWhen }, { key = 'pts', label = Locale.colPoints },
            { key = 'why', label = Locale.colReason }, { key = 'by', label = Locale.colBy } } }
    end
    return blocks
end

function render.playtime()
    local d = view({ op = 'playtime' }, { mine = 0, total = 0, count = 1 })
    local blocks = {
        { type = 'heading', text = Locale.tabPlaytime, sub = Locale.playtimeSub },
        { type = 'stats', items = {
            { value = Desk.hours(d.mine), label = Locale.statThisChar },
            { value = Desk.hours(d.total), label = Locale.statAllChars:format(d.count) },
        } },
    }
    if d.nextHours then
        blocks[#blocks + 1] = { type = 'progress', items = { {
            label = Locale.nextMilestone:format(d.nextHours), sub = d.nextNote,
            value = math.min(1, d.mine / d.nextHours), right = ('%d / %d h'):format(math.floor(d.mine), d.nextHours) } } }
    end
    return blocks
end

function render.staff()
    local blocks = { { type = 'heading', text = Locale.tabStaff, sub = Locale.staffSub },
        { type = 'chips', items = {
            { id = 'sv:pending', label = Locale.staffPending, active = S.staffView == 'pending' },
            { id = 'sv:online',  label = Locale.staffOnline,  active = S.staffView == 'online' },
        } },
        { type = 'actions', buttons = {
            { id = 'send:cash', label = Locale.btnSendCash, tone = 'green' },
            { id = 'send:item', label = Locale.btnSendItem, tone = 'green' },
            { id = 'send:weapon', label = Locale.btnSendWeapon, tone = 'green' },
            { id = 'points', label = Locale.btnPoints, tone = 'ghost' },
        } },
    }
    if S.staffView == 'online' then
        local d = view({ op = 'staffOnline' }, { list = {} })
        local rows = {}
        for _, p in ipairs(d.list) do
            rows[#rows + 1] = { cells = { id = { text = tostring(p.src), tone = 'muted' }, char = { text = '#' .. p.charid },
                name = { text = p.name }, job = { text = p.job or '', tone = 'muted' } } }
        end
        blocks[#blocks + 1] = { type = 'table', title = Locale.staffOnline, perPage = 10, rows = rows, columns = {
            { key = 'id', label = Locale.colServerId }, { key = 'char', label = Locale.colCharid },
            { key = 'name', label = Locale.colName }, { key = 'job', label = Locale.colJob } } }
        return blocks
    end
    blocks[#blocks + 1] = { type = 'search', id = 'q:staff', value = S.staffQuery, placeholder = Locale.staffSearch }
    local d = view({ op = 'staffPending', query = S.staffQuery }, { list = {} })
    if #d.list == 0 then
        blocks[#blocks + 1] = { type = 'note', text = Locale.nothingFound }
    else
        local items = {}
        for _, p in ipairs(d.list) do
            items[#items + 1] = { img = picture(p.kind, p.name), title = ('#%d  %s  ->  %s'):format(p.id, p.what, p.to),
                sub = (p.note ~= '' and (p.note .. '  -  ') or '') .. Locale.fromWhen:format(p.by, p.when),
                actions = { { id = 'cancel:' .. p.id, label = Locale.btnCancel, tone = 'ghost' } } }
        end
        blocks[#blocks + 1] = { type = 'list', items = items }
    end
    return blocks
end

-------------------------------------------------------------------------------
-- OPEN / REDRAW
-------------------------------------------------------------------------------
local function draw(first)
    local state = S
    if not state then return end
    state.needOpen = state.needOpen or first
    state.drawing = (state.drawing or 0) + 1
    local mine, tab = state.drawing, state.tab
    local content = render[tab]()
    -- render may have waited on the server: drop this draw if the panel closed or a newer one started
    if S ~= state or state.drawing ~= mine or state.previewing then return end
    local open = state.needOpen
    state.needOpen = false
    local payload = { owner = OWNER, title = Locale.title, subtitle = state.subtitle, tabs = tabs(), active = tab, content = content }
    if open then exports['pup-ui']:OpenApp(payload) else exports['pup-ui']:UpdateApp(payload) end
end

function DeskPanel.isOpen() return S ~= nil end

-- mode 'desk' (standing at one) or 'staff' (the /staffdesk command)
function DeskPanel.open(mode, deskName)
    local state = { tab = 'parcels', staffView = 'pending', staffQuery = '', mode = mode }
    S = state
    local info = ask({ op = 'overview' })
    if S ~= state then return end   -- closed while the server answered
    if not info or info.ok == false then
        S = nil
        return tip(info and info.msg or Locale.failed)
    end
    S.staff = info.staff
    if mode == 'staff' then S.tab = 'staff' end
    S.subtitle = Locale.subtitle:format(info.name, deskName or Locale.anywhere)
    draw(true)
end

local function close()
    S, pending = nil, nil
    exports['pup-ui']:CloseApp()
    TriggerServerEvent('pup_staffdesk:closed')
end
DeskPanel.close = close

local function act(req)
    local res = ask(req)
    if res then tip(res.msg) end
    if S then draw(false) end
    return res and res.ok
end

local function input(kind, data, title, subtitle, fields, submit)
    pending = { kind = kind, data = data }
    exports['pup-ui']:OpenInput({ owner = OWNER, title = title, subtitle = subtitle, submit = submit, fields = fields })
end

-------------------------------------------------------------------------------
-- EVENTS FROM THE PANEL
-------------------------------------------------------------------------------
AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= OWNER or not S then return end
    S.tab = tab
    draw(false)
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    -- a height preview closes the panel itself and brings it back afterwards: not a real close
    if (owner == OWNER or owner == nil) and S and not pending and not S.previewing then
        S = nil
        TriggerServerEvent('pup_staffdesk:closed')
    end
end)

-- the preview is over: bring the panel back, unless they can't use it any more
local function previewOver(state)
    if S ~= state then return end
    state.previewing = nil
    if IsEntityDead(PlayerPedId()) or (state.mode ~= 'staff' and not DeskNear()) then
        S, pending = nil, nil
        TriggerServerEvent('pup_staffdesk:closed')
        return
    end
    draw(true)
end

local function findIn(list, id)
    for _, r in ipairs(list or {}) do if tostring(r.id) == tostring(id) then return r end end
end

AddEventHandler('pup-ui:client:appAction', function(owner, action, data)
    if owner ~= OWNER or not S then return end
    local kind, arg = tostring(action):match('^([^:]+):?(.*)$')
    data = data or {}

    if kind == 'claim' then return act({ op = 'claim', id = tonumber(arg) })
    elseif kind == 'claimall' then return act({ op = 'claimAll' })
    elseif kind == 'redeem' then return act({ op = 'redeem', item = arg })
    elseif kind == 'cancel' then return act({ op = 'staffCancel', id = tonumber(arg) })
    elseif kind == 'sv' then S.staffView = arg return draw(false)
    elseif kind == 'q' then S.staffQuery = tostring(data.value or '') return draw(false)

    elseif kind == 'height' then
        local value = (tonumber(data.value) or 100) / 100
        if arg == 'preview' then
            local back = S.changes and S.changes.height and S.changes.height.current or 1.0
            -- the panel covers the character, so it steps aside and keeps what they were trying
            local state = S
            state.previewing = true
            state.heightValue = tonumber(data.value)
            exports['pup-ui']:CloseApp()
            DeskHeightPreview(value, back, function() previewOver(state) end)
        else
            act({ op = 'height', value = value })
        end

    elseif kind == 'rename' then
        local r = S.changes and S.changes.rename or {}
        input('rename', nil, Locale.renameTitle, Locale.renameRules:format(Config.Rename.minLength, Config.Rename.maxLength), {
            { label = Locale.firstName, type = 'text', default = r.first or '', maxlength = Config.Rename.maxLength, required = true },
            { label = Locale.lastName, type = 'text', default = r.last or '', maxlength = Config.Rename.maxLength, required = true },
        }, Locale.btnBuyFor:format(money(Config.Rename.price)))

    elseif kind == 'pet' or kind == 'weapon' then
        local list = S.changes and (kind == 'pet' and S.changes.pets or S.changes.weapons)
        local r = findIn(list, arg)
        if not r then return end
        local cfg = kind == 'pet' and Config.PetName or Config.WeaponName
        input(kind, { id = r.id }, kind == 'pet' and r.breed or r.base, Locale.namerSub:format(money(cfg.price), cfg.cooldownDays), {
            { label = Locale.nameField, type = 'text', default = r.name, maxlength = kind == 'weapon' and Config.WeaponName.maxNameLength or 32, required = true },
            { label = Locale.descField, type = 'textarea', default = r.desc, maxlength = kind == 'weapon' and Config.WeaponName.maxDescLength or 200 },
        }, Locale.btnBuyFor:format(money(cfg.price)))

    elseif kind == 'send' then
        local fields = { { label = Locale.fTarget, type = 'text', placeholder = Locale.fTargetHint, required = true } }
        if arg == 'cash' then
            fields[#fields + 1] = { label = Locale.fAmount, type = 'number', min = 1, max = Config.Parcels.maxCash, required = true }
        elseif arg == 'item' then
            fields[#fields + 1] = { label = Locale.fItem, type = 'text', placeholder = 'bread', required = true }
            fields[#fields + 1] = { label = Locale.fCount, type = 'number', default = 1, min = 1, max = Config.Parcels.maxItems, required = true }
        else
            fields[#fields + 1] = { label = Locale.fWeapon, type = 'text', placeholder = 'WEAPON_REVOLVER_CATTLEMAN', required = true }
        end
        fields[#fields + 1] = { label = Locale.fNote, type = 'text', maxlength = Config.Parcels.noteLength }
        input('send', { kind = arg }, Locale.sendTitle:format(arg), Locale.sendSub, fields, Locale.btnSend)

    elseif kind == 'points' then
        input('points', nil, Locale.btnPoints, Locale.pointsSub, {
            { label = Locale.fCharid, type = 'number', min = 1, required = true },
            { label = Locale.fPoints, type = 'number', required = true },
            { label = Locale.fReason, type = 'text', maxlength = 160 },
        }, Locale.btnApply)
    end
end)

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= OWNER then return end
    local p = pending
    pending = nil
    if not S or not p then return end
    if values == nil then return draw(true) end

    local req
    if p.kind == 'rename' then req = { op = 'rename', first = values[1], last = values[2] }
    elseif p.kind == 'pet' then req = { op = 'petName', id = p.data.id, name = values[1], desc = values[2] }
    elseif p.kind == 'weapon' then req = { op = 'weaponName', id = p.data.id, name = values[1], desc = values[2] }
    elseif p.kind == 'points' then req = { op = 'staffPoints', charid = values[1], delta = values[2], reason = values[3] }
    elseif p.kind == 'send' then
        req = { op = 'staffSend', kind = p.data.kind, target = values[1] }
        if p.data.kind == 'cash' then req.amount, req.note = values[2], values[3]
        elseif p.data.kind == 'item' then req.name, req.amount, req.note = values[2], values[3], values[4]
        else req.name, req.note = values[2], values[3] end
    end
    local res = req and ask(req)
    if res then tip(res.msg) end
    draw(true)
end)
