-- pup-bank | the counter on the client: blips, the prompt and the pup-ui bank app.
-- Nothing here decides anything; the server answers every request with a fresh view.

local APP   = "pup-bank:app"
local INPUT = "pup-bank:amount"

-- one visit to a counter. nil while the player is not banking.
--   branch  : Config.Banks key of the counter in use
--   view    : the server's last answer { balances, lines, teller } (nil until the first)
--   tab     : the tab on screen, nil while the app is hidden for the amount panel
--   asking  : "deposit" | "withdraw" while the amount panel is up
--   waiting : true from a request until its view arrives
local visit = nil

local function trace(...)
    if not Config.General.debug then return end
    local out = {}
    for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end
    print("^6[pup-bank client]^7 " .. table.concat(out, " "))
end

local function ask(event, ...)
    trace("->", event, ...)
    TriggerServerEvent(event, ...)
end

local function dollars(n)
    return ("$%.2f"):format(tonumber(n) or 0)
end

local function heldHere()
    return visit and visit.view and visit.view.balances[visit.branch] or 0
end

-------------------------------------------------------------------------------
-- tab pages
-------------------------------------------------------------------------------

local Pages = {}

function Pages.account()
    local page = {
        { type = "heading", text = Locale.tabAccount, sub = Locale.accountSub },
        { type = "stats", items = { { value = dollars(heldHere()), label = Locale.heldHere } } },
    }
    local lines = visit.view and visit.view.lines
    if lines == nil then
        page[#page + 1] = { type = "heading", text = "", sub = Locale.loading }
    elseif #lines == 0 then
        page[#page + 1] = { type = "heading", text = "", sub = Locale.ledgerEmpty }
    else
        local rows = {}
        for i, l in ipairs(lines) do
            rows[i] = { cells = {
                when    = { text = l.when },
                kind    = { text = l.label, tone = l.incoming and "badge-green" or "badge-red" },
                amount  = { text = l.amount, tone = l.incoming and "pos" or "neg" },
                balance = { text = l.balance },
            } }
        end
        page[#page + 1] = { type = "table", title = Locale.ledgerTitle, rows = rows, columns = {
            { key = "when",    label = Locale.colWhen },
            { key = "kind",    label = Locale.colEntry },
            { key = "amount",  label = Locale.colAmount },
            { key = "balance", label = Locale.colBalance },
        } }
        page[#page + 1] = { type = "actions", buttons = {
            { id = "clear", label = Locale.clearButton, tone = "red" },
        } }
    end
    return page
end

local function moneyPage(title, sub, button, action)
    return {
        { type = "heading", text = title, sub = sub },
        { type = "stats", items = { { value = dollars(heldHere()), label = Locale.heldHere } } },
        { type = "actions", buttons = { { id = action, label = button, tone = "red" } } },
    }
end

function Pages.deposit()
    return moneyPage(Locale.payInTitle, Locale.payInSub, Locale.payInButton, "deposit")
end

function Pages.withdraw()
    return moneyPage(Locale.takeOutTitle, Locale.takeOutSub, Locale.takeOutButton, "withdraw")
end

-- every branch from one counter; bank_users keeps them all in one row, so it is one query
function Pages.branches()
    local page = { { type = "heading", text = Locale.tabBranches, sub = Locale.branchesSub } }
    local balances = visit.view and visit.view.balances
    if not balances then
        page[#page + 1] = { type = "heading", text = "", sub = visit.waiting and Locale.loading or Locale.branchesNone }
        return page
    end

    local names = {}
    for name in pairs(balances) do names[#names + 1] = name end
    table.sort(names) -- a stable order between visits

    local rows, sum = {}, 0
    for i, name in ipairs(names) do
        local held = tonumber(balances[name]) or 0
        sum = sum + held
        rows[i] = { cells = {
            branch  = { text = name .. (name == visit.branch and Locale.thisBranch or "") },
            balance = { text = dollars(held), tone = held > 0 and "pos" or nil },
        } }
    end
    page[#page + 1] = { type = "stats", items = { { value = dollars(sum), label = Locale.allTotal } } }
    page[#page + 1] = { type = "table", title = Locale.tabBranches, rows = rows, columns = {
        { key = "branch",  label = Locale.colBranch },
        { key = "balance", label = Locale.colBalance },
    } }
    return page
end

-- client/teller.lua (loaded after this file) supplies the Teller page
function Pages.teller()
    if TellerIsOn and TellerTabContent then return TellerTabContent() end
    return Pages.account()
end

local function pageFor(tab)
    return (Pages[tab] or Pages.account)()
end

local function tabStrip()
    local strip = {
        { id = "account",  label = Locale.tabAccount,  icon = "chart" },
        { id = "deposit",  label = Locale.tabPayIn,    icon = "coins" },
        { id = "withdraw", label = Locale.tabTakeOut,  icon = "box" },
        { id = "branches", label = Locale.tabBranches, icon = "home" },
    }
    -- only when the server says this player is a teller on duty
    if TellerIsOn then strip[#strip + 1] = { id = "teller", label = Locale.tabTeller, icon = "coins" } end
    return strip
end

-------------------------------------------------------------------------------
-- the app
-------------------------------------------------------------------------------

local function showApp(tab)
    visit.tab = tab or "account"
    trace("app", visit.branch, visit.tab)
    exports["pup-ui"]:OpenApp({
        owner = APP, title = Locale.appTitle, subtitle = visit.branch,
        tabs = tabStrip(), active = visit.tab, content = pageFor(visit.tab),
    })
end

local function redraw()
    if visit and visit.tab then
        exports["pup-ui"]:UpdateApp({ active = visit.tab, content = pageFor(visit.tab) })
    end
end

-- leave the counter: close the app (unless pup-ui already did) and free the player
local function endVisit(uiClosed)
    if not visit then return end
    if visit.tab and not uiClosed then exports["pup-ui"]:CloseApp() end
    visit = nil
    ClearPedTasks(PlayerPedId())
end

local function refresh()
    if not visit then return end
    visit.waiting = true
    ask("pup-bank:sv:view", visit.branch)
end

-- the app hides while the amount panel is up; it comes back on the same tab either way
local function askAmount(kind)
    visit.asking = kind
    visit.returnTo = visit.tab
    visit.tab = nil
    exports["pup-ui"]:CloseApp()
    exports["pup-ui"]:OpenInput({
        owner = INPUT,
        title = kind == "deposit" and Locale.payInTitle or Locale.takeOutTitle,
        subtitle = visit.branch,
        submit = Locale.send,
        fields = { { label = Locale.amountField, type = "number", min = 1, required = true } },
    })
end

AddEventHandler("pup-ui:client:inputDone", function(owner, values)
    if owner ~= INPUT or not visit or not visit.asking then return end
    local kind, back = visit.asking, visit.returnTo
    visit.asking, visit.returnTo = nil, nil

    if values ~= nil then
        local amount = tonumber(values[1])
        if amount and amount > 0 then
            visit.waiting = true
            ask("pup-bank:sv:move", kind, amount, visit.branch)
        else
            TriggerEvent("vorp:TipBottom", Locale.refused, 6000)
        end
    end
    showApp(back)
end)

-------------------------------------------------------------------------------
-- server replies and app events
-------------------------------------------------------------------------------

RegisterNetEvent("pup-bank:cl:view", function(view)
    if not visit or type(view) ~= "table" or view.branch ~= visit.branch then return end
    trace("<- view", view.branch, "#lines=" .. tostring(view.lines and #view.lines))
    visit.view = view
    visit.waiting = false
    local stripChanged = TellerSetStatus and TellerSetStatus(view.teller) or false
    if visit.tab then
        if stripChanged then showApp(visit.tab) else redraw() end
    end
end)

AddEventHandler("pup-ui:client:appNav", function(owner, tab)
    if owner ~= APP or not visit or not visit.tab then return end
    visit.tab = tab
    redraw()
    refresh()
end)

AddEventHandler("pup-ui:client:appAction", function(owner, action)
    if owner ~= APP or not visit or not visit.tab then return end
    action = tostring(action)
    if action == "deposit" or action == "withdraw" then
        askAmount(action)
    elseif action == "clear" then
        -- empty the list straight away so the button cannot be pressed twice; the server's view confirms it
        if visit.view then visit.view.lines = {} end
        redraw()
        ask("pup-bank:sv:clear", visit.branch)
        TriggerEvent("vorp:TipRight", Locale.clearedTip, 5000)
    elseif action == "openteller" then
        -- the desk is a list menu; the app goes so the two do not fight for focus
        endVisit(false)
        TellerOpenDesk()
    end
end)

-- x / ESC / forced close. Hiding for the amount panel sets tab to nil first, so it does not count.
AddEventHandler("pup-ui:client:appClosed", function(owner)
    if owner ~= APP or not visit or not visit.tab then return end
    endVisit(true)
end)

-------------------------------------------------------------------------------
-- the world
-------------------------------------------------------------------------------

local blips = {}
local prompt, promptGroup

CreateThread(function()
    Wait(1000)
    for name, bank in pairs(Config.Banks) do
        local c = bank.counter
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, c.x, c.y, c.z) -- BLIP_ADD_FOR_COORDS
        SetBlipSprite(blip, bank.blip or Config.BankBlip, true)
        SetBlipScale(blip, 1.5)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, name) -- SET_BLIP_NAME
        blips[#blips + 1] = blip
    end
end)

local function buildPrompt()
    promptGroup = GetRandomIntInRange(0, 0xffffff)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.Keys.interact)
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", Locale.promptOpen))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetStandardMode(prompt, true)
    PromptSetGroup(prompt, promptGroup)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C, prompt, true)
    PromptRegisterEnd(prompt)
end

-- the counter within reach, if any
local function counterInReach(pos)
    local reach = Config.Counter.promptRange or 1.5
    for name, bank in pairs(Config.Banks) do
        if #(pos - bank.counter) < reach then return name end
    end
    return nil
end

-- walk up, press the key: wait for the first view (up to 10 s), then open on the Account tab
local function beginVisit(branch)
    visit = { branch = branch, waiting = true }
    ask("pup-bank:sv:view", branch)
    local giveUp = GetGameTimer() + 10000
    while visit and visit.branch == branch and not visit.view and GetGameTimer() < giveUp do
        Wait(100)
    end
    if not visit or visit.branch ~= branch then return end
    if not visit.view then visit = nil return end
    TaskStandStill(PlayerPedId(), -1)
    showApp("account")
end

CreateThread(function()
    Wait(5000)
    buildPrompt()
    while true do
        local branch = not visit and counterInReach(GetEntityCoords(PlayerPedId())) or nil
        if branch then
            PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, "LITERAL_STRING", Locale.promptGroup))
            if Citizen.InvokeNative(0xC92AC953F0A982AE, prompt) then -- PROMPT_HAS_STANDARD_MODE_COMPLETED
                beginVisit(branch)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    if visit and visit.tab then exports["pup-ui"]:CloseApp() end
    ClearPedTasks(PlayerPedId())
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)
