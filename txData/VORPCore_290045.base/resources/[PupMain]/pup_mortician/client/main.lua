-- pup_mortician | status, the world prompt and lifecycle

local D = Config.Distance

local function applyStatus(st)
    if type(st) ~= 'table' then return end
    Status.undertaker = st.undertaker == true
    Status.job = st.job
    Status.charId = st.charId
    Status.left = st.left or 0
    Status.limit = st.limit or 0
    Status.posting = st.posting
    if type(st.tables) == 'table' then
        for key, s in pairs(st.tables) do
            if Config.Tables[key] then
                local prev = TableStates[key]
                TableStates[key] = s
                if not prev or prev.state ~= s.state or #(prev.laid or {}) ~= #(s.laid or {}) then
                    CreateThread(function() Props.Refresh(key) end)
                end
            end
        end
    end
    Contract.Set(st.posting)
    if not Status.undertaker then
        Carry.Stop()
        if Ledger.open then Ledger.Close() end
    end
end

local refreshing = false
function RefreshStatus()
    if refreshing then return end
    refreshing = true
    local res = Act('status', {})
    if res.ok and res.status then applyStatus(res.status) end
    refreshing = false
end

RegisterNetEvent('pup_mortician:status', function(st)
    applyStatus(st)
end)

RegisterNetEvent('pup_mortician:table', function(key, state)
    if type(key) ~= 'string' or not Config.Tables[key] or type(state) ~= 'table' then return end
    TableStates[key] = state
    CreateThread(function()
        Props.Refresh(key)
        if Ledger.open and Ledger.key == key and not Ledger.inputPending then Ledger.Refresh() end
    end)
end)

RegisterNetEvent('pup_mortician:toggleShovel', function()
    Shovel.Toggle()
end)

RegisterNetEvent('pup_mortician:shovelGone', function()
    if not Shovel.digging then Shovel.PutAway() end
end)

---------------------------------------------------------------------------
-- The world prompt
---------------------------------------------------------------------------
local function nearestTable(pos)
    for key, cfg in pairs(Config.Tables) do
        if #(pos - cfg.pos) <= D.tablePrompt then return key end
    end
    return nil
end

local function nearestYard(pos)
    for id, at in pairs(Config.Graveyards) do
        if #(pos - at) <= D.gravePrompt then return id end
    end
    return nil
end

CreateThread(function()
    local group = GetRandomIntInRange(0, 0xffffff)
    local prompt = MakePrompt(Config.Keys.use, L('promptUse'), group)
    while true do
        local sleep = 800
        if Status.undertaker and not Busy and not Ledger.IsOpen() and not Shovel.digging then
            local pos = GetEntityCoords(PlayerPedId())
            local title, run
            if Carry.key then
                if #(pos - Config.Tables[Carry.key].burial) <= D.burialPrompt then
                    title, run = L('buryCasket'), Work.BuryCasket
                end
            else
                local key = nearestTable(pos)
                if key then
                    title, run = L('ledgerTitle'), function() Ledger.Open(key, 'table') end
                else
                    local yard = nearestYard(pos)
                    if yard and CarriedCorpse() then
                        title, run = L('buryBody'), function() Work.BuryBody(yard) end
                    end
                end
            end
            if title then
                sleep = 0
                ShowGroup(group, title)
                if PromptHasStandardModeCompleted(prompt) then
                    -- Busy is taken here, in the same frame, so the prompt cannot
                    -- start the action twice before the new thread first runs
                    Busy = true
                    CreateThread(function()
                        local ok, err = pcall(run)
                        if not ok then print(('[%s] action failed: %s'):format(RES, tostring(err))) end
                        Busy = false
                    end)
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- Status refresh: 2 s after start, every 30 s, 2.5 s after a character pick
---------------------------------------------------------------------------
CreateThread(function()
    Wait(2000)
    RefreshStatus()
    while true do
        Wait(30000)
        RefreshStatus()
    end
end)

-- drop everything the previous character had in hand
local function resetCharacterState()
    Carry.Stop()
    if not Shovel.digging then Shovel.PutAway() end
    Contract.Clear()
    Ledger.inputPending = nil
    Ledger.Close()
    Status.undertaker = false
    Status.charId = nil
    Status.posting = nil
end

RegisterNetEvent('vorp:SelectedCharacter', function()
    resetCharacterState()
    SetTimeout(2500, function() CreateThread(RefreshStatus) end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= RES then return end
    Carry.Stop()
    Props.ClearAll()
    Contract.Clear()
    Shovel.PutAway()
    if Ledger.open then pcall(function() exports['pup-ui']:CloseApp() end) end
end)
