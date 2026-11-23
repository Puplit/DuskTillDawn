-- pup_gunsmith | client foundation: state, callbacks, pup-ui round trips

Core = exports.vorp_core:GetCore()

-- what the player is doing here: nil, 'shop', 'station', 'crafting' or 'bench'
Cl = {
    busy = nil,
    stations = {},
}

OWNER = {
    app      = GS.RES .. ':craft-app',
    amount   = GS.RES .. ':amount',
    custom   = GS.RES .. ':custom-text',
    confirm  = GS.RES .. ':shop-confirm',
}

function Cl.rpc(name, ...)
    local ok, res = pcall(Core.Callback.TriggerAwait, 'pup_gunsmith:' .. name, ...)
    if not ok then return nil end
    return res
end

function Cl.tip(msg, ms)
    if type(msg) ~= 'string' or msg == '' then return end
    TriggerEvent('vorp:TipBottom', msg, ms or 4000)
end

function Cl.freeze(on)
    FreezeEntityPosition(PlayerPedId(), on == true)
end

---------------------------------------------------------------------------
-- the journal key stays shut while a counter or station screen is open
---------------------------------------------------------------------------
local journalThread = false
function Cl.blockJournal()
    if journalThread then return end
    journalThread = true
    CreateThread(function()
        while Cl.busy == 'shop' or Cl.busy == 'station' do
            DisableControlAction(0, `INPUT_OPEN_JOURNAL`, true)
            Wait(0)
        end
        journalThread = false
    end)
end

---------------------------------------------------------------------------
-- pup-ui input form and list menu as awaitable calls
---------------------------------------------------------------------------
local pendingInput = {}

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    local p = owner and pendingInput[owner]
    if not p then return end
    pendingInput[owner] = nil
    p:resolve(type(values) == 'table' and values or false)
end)

--- opens a pup-ui input form; returns the values array, or nil when cancelled
function Cl.askInput(data)
    local p = promise.new()
    pendingInput[data.owner] = p
    local ok, opened = pcall(function() return exports['pup-ui']:OpenInput(data) end)
    if not ok or opened == false then
        pendingInput[data.owner] = nil
        return nil
    end
    local v = Citizen.Await(p)
    return v or nil
end

local pendingList = nil

local function settleList(owner, value)
    local pl = pendingList
    if not pl or pl.owner ~= owner then return end
    pendingList = nil
    pl.p:resolve(value)
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner) settleList(owner, index == 1) end)
AddEventHandler('pup-ui:client:listBack', function(owner) settleList(owner, false) end)
AddEventHandler('pup-ui:client:listClosed', function(owner) settleList(owner, false) end)

--- a two-option confirm menu; closing, Escape or the timeout all count as No
function Cl.askConfirm(title, subtitle, timeoutMs)
    local p = promise.new()
    local entry = { owner = OWNER.confirm, p = p }
    pendingList = entry
    exports['pup-ui']:OpenListMenu({
        owner = OWNER.confirm,
        title = title,
        subtitle = subtitle,
        keyboard = true,
        options = { { label = L('confirm') }, { label = L('cancel') } },
    })
    SetTimeout(timeoutMs or 30000, function()
        if pendingList == entry then
            pendingList = nil
            pcall(function() exports['pup-ui']:HideListMenu() end)
            p:resolve(false)
        end
    end)
    return Citizen.Await(p) == true
end

function Cl.askAmount()
    local values = Cl.askInput({
        owner = OWNER.amount,
        title = L('amount'),
        fields = { { label = L('amount'), type = 'number', required = true, min = 1, default = 1 } },
    })
    if not values then return nil end
    local n = tonumber(values[1])
    if not n or n ~= n then return nil end
    n = math.floor(math.abs(n))
    if n < 1 then return nil end
    return n
end
