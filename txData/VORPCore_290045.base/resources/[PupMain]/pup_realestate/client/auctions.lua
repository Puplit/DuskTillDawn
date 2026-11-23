-- pup_realestate | the town hall auction board (pup-ui app) and bidding from a bank branch

local APP = 'pup_realestate:auctions'
local board = nil      -- last board from the server
local tab = 'active'
local appOpen = false
local wantBoard = false -- open the app when the next board arrives

local function activeContent(b)
    local out = { { type = 'heading', text = Locale.tab_active, sub = Locale.active_help } }
    if #(b.active or {}) == 0 then
        out[#out + 1] = { type = 'heading', text = Locale.no_active }
        return out
    end
    local items = {}
    for _, e in ipairs(b.active) do
        local parts = {}
        if b.sealed then
            parts[#parts + 1] = T('reserve', U.money(e.minimum))
            parts[#parts + 1] = e.hasBids and Locale.bids_sealed or Locale.no_bids_yet
            if e.youLead and e.yourBid then parts[#parts + 1] = T('you_lead', U.money(e.yourBid)) end
        else
            parts[#parts + 1] = T('min', U.money(e.minimum))
            if (tonumber(e.top) or 0) > 0 then
                parts[#parts + 1] = T('top', U.money(e.top), tostring(e.topName or ''))
            else
                parts[#parts + 1] = Locale.no_bids_yet
            end
        end
        parts[#parts + 1] = tostring(e.timeLeft or '')
        items[#items + 1] = {
            title = tostring(e.title or ''),
            sub = table.concat(parts, ' - '),
            actions = { { id = 'bid:' .. tostring(U.int(e.id) or 0), label = Locale.place_bid } },
        }
    end
    out[#out + 1] = { type = 'list', items = items }
    return out
end

local function pastContent(b)
    local out = { { type = 'heading', text = Locale.tab_past, sub = Locale.past_heading } }
    if #(b.past or {}) == 0 then
        out[#out + 1] = { type = 'note', text = Locale.no_past }
        return out
    end
    local rows = {}
    for _, e in ipairs(b.past) do
        local winner = tostring(e.winner or '')
        local tone = 'badge-green'
        if winner == 'No bids' then tone = 'muted' elseif winner == 'Cancelled' then tone = 'badge-red' end
        local amount = tonumber(e.amount) or 0
        rows[#rows + 1] = { cells = {
            house = { text = tostring(e.title or '') },
            winner = { text = winner, tone = tone },
            amount = { text = amount > 0 and ('$' .. U.money(amount)) or '-' },
            when = { text = tostring(e.when or '-') },
        } }
    end
    out[#out + 1] = { type = 'table', columns = {
        { key = 'house', label = Locale.col_house },
        { key = 'winner', label = Locale.col_winner },
        { key = 'amount', label = Locale.col_amount },
        { key = 'when', label = Locale.col_when },
    }, rows = rows }
    return out
end

local function content()
    if not board then return {} end
    return tab == 'past' and pastContent(board) or activeContent(board)
end

local function show()
    if not board then return end
    if appOpen then
        UI:UpdateApp({ active = tab, content = content() })
        return
    end
    appOpen = true
    UI:OpenApp({
        owner = APP, title = Locale.auction_house, subtitle = Locale.town_hall, badge = Locale.public_bidding,
        tabs = {
            { id = 'active', label = Locale.tab_active, icon = 'bank' },
            { id = 'past', label = Locale.tab_past, icon = 'doc' },
        },
        active = tab, content = content(),
    })
end

local function nearHall()
    local pos = C.pos()
    for _, t in ipairs(Config.TownHalls) do
        if #(pos - t.coords) <= Config.Reach.townHall + 2.0 then return true end
    end
    return false
end

-- ask for the board and open (or refresh) the app when it arrives
local function requestBoard()
    local b = Rpc('sv_board', nil)
    if type(b) ~= 'table' then return end
    board = b
    show()
end

function C.openBoard()
    if appOpen then return end
    tab = 'active'
    requestBoard()
end

RegisterNetEvent('pup_realestate:cl_board', function(b)
    if type(b) ~= 'table' then return end
    board = b
    if appOpen or (wantBoard and nearHall()) then
        wantBoard = false
        show()
    end
end)

AddEventHandler('pup-ui:client:appNav', function(owner, newTab)
    if owner ~= APP then return end
    tab = newTab == 'past' and 'past' or 'active'
    show()
    CreateThread(requestBoard)
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner ~= APP then return end
    appOpen = false
    board = nil
end)

-- placing a bid
local function payFrom(aid, amount, banks)
    local p = promise.new()
    local chosen = nil
    Menu.open(function()
        local opts = {}
        for _, b in ipairs(banks) do
            local bank, balance = tostring(b.bank), math.floor(tonumber(b.balance) or 0)
            local label = T('branch_row', bank, U.money(balance))
            if balance >= amount then
                opts[#opts + 1] = { label = label, description = T('branch_ok', U.money(amount)), select = function()
                    chosen = bank
                    Menu.close()
                end }
            else
                opts[#opts + 1] = { label = label, description = T('branch_short', U.money(amount - balance)) }
            end
        end
        return { title = Locale.pay_from, subtitle = T('pay_from_sub', U.money(amount)), options = opts }
    end, function() p:resolve(chosen or false) end)
    local bank = Citizen.Await(p)
    if bank then
        wantBoard = true
        Send('sv_bid', aid, amount, bank)
        return true
    end
    return false
end

local function bidFlow(aid)
    local v = Ask(Locale.place_bid, { { label = Locale.bid_amount, type = 'number', min = 1, required = true } })
    if not v then return requestBoard() end
    local amount = U.int(v[1])
    if not amount or amount < 1 then
        C.tip(Locale.bid_invalid)
        return requestBoard()
    end
    local banks = Rpc('sv_banks', nil)
    if type(banks) ~= 'table' then
        C.tip(Locale.banks_unreadable)
        return requestBoard()
    end
    if #banks == 0 then
        C.tip(Locale.no_bank)
        return requestBoard()
    end
    if not payFrom(aid, amount, banks) then requestBoard() end
    -- after a bid the server sends the board back by itself
end

AddEventHandler('pup-ui:client:appAction', function(owner, action)
    if owner ~= APP or type(action) ~= 'string' then return end
    local aid = U.int(action:match('^bid:(%d+)$'))
    if not aid then return end
    UI:CloseApp()
    appOpen = false
    CreateThread(function() bidFlow(aid) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if appOpen then UI:CloseApp() end
end)
