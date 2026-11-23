-- bank teller desk (client): a pup-ui list menu reached from the Teller tab; all checks are server side

local MENU_OWNER   = 'pup-bank:teller'
local INPUT_OWNER  = 'pup-bank:tellerinput'
local CONSENT_OWNER= 'pup-bank:consent'

-- set by the server when the app opens; display only, every action is re-checked
TellerIsOn = false

local draft   = nil   -- { fromServerId, fromName, fromBank, toCharid, toName, toBank, branches }
local nearby  = {}
local level   = nil   -- which menu page is open
local pending = nil   -- which input prompt is up
local consent = nil   -- an offer waiting on MY answer

local function tip(t, ms) TriggerEvent("vorp:TipRight", t, ms or 6000) end
local function money(n) return string.format("$%.2f", tonumber(n) or 0) end

local function branchNames()
    local names = {}
    for b in pairs(Config.Banks) do names[#names + 1] = b end
    table.sort(names)
    return names
end

local function closeMenu()
    level = nil
    exports['pup-ui']:HideListMenu()
end

-- menu pages ---------------------------------------------------------------

local showRoot -- forward

local function showList(title, subtitle, options, tag)
    level = tag
    exports['pup-ui']:OpenListMenu({
        owner = MENU_OWNER, title = title, subtitle = subtitle, options = options,
    })
end

local function rootOptions()
    local o = {}
    o[#o + 1] = { label = "Customer at the counter",
        desc = draft and draft.fromName and (draft.fromName .. "  (char " .. tostring(draft.fromCharid) .. ")")
            or "Nobody picked yet" }
    o[#o + 1] = { label = "Their branch",
        desc = (draft and draft.fromBank) or "Which of their accounts the money leaves" }
    o[#o + 1] = { label = "Recipient",
        desc = (draft and draft.toName) and (draft.toName .. "  (char " .. tostring(draft.toCharid) .. ")")
            or "Look up by character ID" }
    o[#o + 1] = { label = "Paying in to",
        desc = (draft and draft.toBank) or "Which of THEIR branches it lands in" }

    local ready = draft and draft.fromServerId and draft.fromBank and draft.toCharid and draft.toBank
    o[#o + 1] = { label = ready and "Take the amount and send" or "Send (fill the four above first)",
        desc = ready and "They will be asked to authorise it" or nil,
        disabled = not ready }
    o[#o + 1] = { label = "Close" }
    return o
end

showRoot = function()
    showList("Bank Teller", "Transfers only - no deposits, no withdrawals", rootOptions(), 'root')
end

local function showNearby()
    local o = {}
    for _, p in ipairs(nearby) do
        o[#o + 1] = { label = p.name, desc = "char " .. tostring(p.charid) }
    end
    if #o == 0 then o[#o + 1] = { label = "Nobody is close enough", disabled = true } end
    o[#o + 1] = { label = "Back" }
    showList("At your counter", "They must be stood with you", o, 'nearby')
end

local function showFromBank()
    local o = {}
    for _, b in ipairs(branchNames()) do o[#o + 1] = { label = b } end
    o[#o + 1] = { label = "Back" }
    showList("Money leaves which branch", draft and draft.fromName or "", o, 'frombank')
end

local function showToBank()
    local o = {}
    if draft and draft.branches then
        for _, b in ipairs(branchNames()) do
            o[#o + 1] = { label = b, desc = money(draft.branches[b] or 0) }
        end
    else
        o[#o + 1] = { label = "Look the recipient up first", disabled = true }
    end
    o[#o + 1] = { label = "Back" }
    showList("Pay in to which branch", draft and draft.toName or "", o, 'tobank')
end

-- input prompts ------------------------------------------------------------

local function askRecipient()
    pending = 'recipient'
    exports['pup-ui']:HideListMenu()
    exports['pup-ui']:OpenInput({
        owner = INPUT_OWNER, title = "Look Up Account", subtitle = "Character ID",
        submit = "Search",
        fields = { { label = "Character ID", type = "number", min = 1, required = true } },
    })
end

local function askAmount()
    pending = 'amount'
    exports['pup-ui']:HideListMenu()
    local t = Config.Teller
    exports['pup-ui']:OpenInput({
        owner = INPUT_OWNER, title = "Transfer",
        subtitle = ("%s  ->  %s"):format(tostring(draft.fromName), tostring(draft.toName)),
        submit = "Request authorisation",
        fields = {
            { label = "Amount", type = "number", min = t.transferMin or 1, required = true },
            { label = ("Your fee (max %d%%, cap $%d)"):format(t.feeMaxPct or 0, t.feeMax or 0),
              type = "number", min = t.feeMin or 0, required = true },
        },
    })
end

-- selection ----------------------------------------------------------------

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= MENU_OWNER then return end

    if level == 'root' then
        if index == 1 then
            TriggerServerEvent("pup-bank:teller:nearby")
        elseif index == 2 then
            showFromBank()
        elseif index == 3 then
            askRecipient()
        elseif index == 4 then
            showToBank()
        elseif index == 5 then
            if draft and draft.fromServerId and draft.fromBank and draft.toCharid and draft.toBank then
                askAmount()
            end
        else
            closeMenu()
        end
        return
    end

    if level == 'nearby' then
        local p = nearby[index]
        if p then
            draft = draft or {}
            draft.fromServerId, draft.fromName, draft.fromCharid = p.serverId, p.name, p.charid
        end
        showRoot()
        return
    end

    if level == 'frombank' then
        local names = branchNames()
        if names[index] then draft = draft or {}; draft.fromBank = names[index] end
        showRoot()
        return
    end

    if level == 'tobank' then
        local names = branchNames()
        if names[index] and draft and draft.branches then draft.toBank = names[index] end
        showRoot()
        return
    end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= MENU_OWNER then return end
    if level == 'root' then closeMenu() else showRoot() end
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= nil and owner ~= MENU_OWNER then return end
    level = nil
end)

-- input results ------------------------------------------------------------

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner == CONSENT_OWNER then
        local offer = consent
        consent = nil
        if not offer then return end
        local said = tostring(values and values[1] or ""):upper():gsub("%s+", "")
        local ok = (said == "YES" or said == "Y")
        TriggerServerEvent("pup-bank:teller:respond", ok)
        if not ok then tip("You declined the transfer.") end
        return
    end

    if owner ~= INPUT_OWNER then return end
    local p = pending
    pending = nil
    if not p then return end

    if values == nil then showRoot() return end

    if p == 'recipient' then
        TriggerServerEvent("pup-bank:teller:lookup", tonumber(values[1]))
        -- the reply reopens the menu
    elseif p == 'amount' then
        local amount = math.floor(tonumber(values[1]) or 0)
        local fee    = math.floor(tonumber(values[2]) or 0)
        if amount <= 0 then
            tip("Enter an amount.")
            showRoot()
        else
            TriggerServerEvent("pup-bank:teller:propose", {
                fromServerId = draft.fromServerId, fromBank = draft.fromBank,
                toCharid     = draft.toCharid,     toBank   = draft.toBank,
                amount = amount, fee = fee,
            })
            closeMenu()
        end
    end
end)

-- server replies -----------------------------------------------------------

RegisterNetEvent("pup-bank:teller:open", function()
    draft = draft or {}
    nearby = {}
    TriggerServerEvent("pup-bank:teller:nearby")
    showRoot()
end)

RegisterNetEvent("pup-bank:teller:nearbyResult", function(list)
    nearby = list or {}
    if level == 'root' then showNearby() end
end)

RegisterNetEvent("pup-bank:teller:lookupResult", function(data)
    if not data then showRoot() return end
    draft = draft or {}
    draft.toCharid, draft.toName, draft.branches = data.charid, data.name, data.branches
    if not data.hasAccount then tip("They have no bank account on record.") end
    showRoot()
end)

-- the consent step: the server holds the transfer until this answer
RegisterNetEvent("pup-bank:teller:consent", function(offer)
    consent = offer
    exports['pup-ui']:OpenInput({
        owner = CONSENT_OWNER,
        title = "Authorise Transfer",
        subtitle = ("%s is serving you"):format(tostring(offer.teller)),
        submit = "Confirm",
        fields = { {
            label = ("Send %s from your %s to %s (%s)?  Fee %s.  Total %s.  Type YES to authorise.")
                :format(money(offer.amount), offer.fromBank, offer.toName, offer.toBank,
                        money(offer.fee), money(offer.total)),
            type = "text", required = true } },
    })
end)

RegisterNetEvent("pup-bank:teller:done", function()
    draft = nil
end)

-- client/main.lua passes the server's answer from every view; true when it changed, because
-- the tab strip is fixed at OpenApp and has to be rebuilt
function TellerSetStatus(on)
    local was = TellerIsOn
    TellerIsOn = on and true or false
    return was ~= TellerIsOn
end

-- the Teller tab's content inside the bank app
function TellerTabContent()
    return {
        { type = "heading", text = Locale.tabTeller,
          sub = "Move money between two accounts. Deposits and withdrawals are not yours to make." },
        { type = "heading", text = "",
          sub = "The customer must be stood at your counter and authorise the transfer themselves." },
        { type = "actions", buttons = {
            { id = "openteller", label = "Open Teller Desk", tone = "red" },
        } },
    }
end

-- the only way in is the Teller tab, i.e. standing at a counter; the server re-checks
function TellerOpenDesk()
    TriggerServerEvent("pup-bank:teller:request")
end
