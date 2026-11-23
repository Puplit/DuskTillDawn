-- pup_library | the book screen: opening, closing, saving and the recovery paths.

Book = {
    open = false,
    id = nil,
    editable = false,
    scenario = false,
}

local DELETE_KEY <const> = 0x2E -- Windows virtual key for Delete

local function ped() return PlayerPedId() end

local function stopScenario()
    if Book.scenario then
        ClearPedTasks(ped())
        Book.scenario = false
    end
end

-- Release focus, hide the page and clear the scenario. Never saves.
function Book.Close()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'stopBook' })
    stopScenario()
    Book.open = false
    Book.id = nil
    Book.editable = false
end

-- /bookunstuck and the Delete hold: close everything without saving and unfreeze.
function Book.Unstuck()
    Book.Close()
    ClearPedTasks(ped())
    if LibraryCloseMenu then LibraryCloseMenu() end
    FreezeEntityPosition(ped(), false)
    TriggerEvent('vorp:TipRight', T('unstuck'), Config.Notify.unstuck)
end

local function scenarioLoop()
    CreateThread(function()
        local hash = joaat(Config.Scenario)
        while Book.open do
            local p = ped()
            if not IsPedOnMount(p) and not IsPedUsingAnyScenario(p) then
                TaskStartScenarioInPlaceHash(p, hash, -1, true, 0, -1.0, false)
                Book.scenario = true
            end
            Wait(Config.ScenarioRetryMs)
        end
    end)
end

-- Backup for the Delete hold, in case the page itself has stopped responding.
local function deleteHoldLoop()
    if type(IsRawKeyDown) ~= 'function' then return end
    CreateThread(function()
        local since = nil
        while Book.open do
            if IsRawKeyDown(DELETE_KEY) then
                since = since or GetGameTimer()
                if GetGameTimer() - since >= Config.UnstuckHoldMs then
                    Book.Unstuck()
                    return
                end
            else
                since = nil
            end
            Wait(100)
        end
    end)
end

RegisterNetEvent('pup_library:openBook', function(payload)
    if type(payload) ~= 'table' or not tonumber(payload.id) then return end
    if Book.open then Book.Close() end
    if Menu.active then LibraryCloseMenu() end

    Book.open = true
    Book.id = tonumber(payload.id)
    Book.editable = payload.editable == true

    TriggerEvent('vorp_inventory:CloseInv')
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'startBook',
        data = type(payload.data) == 'string' and payload.data or '',
        title = type(payload.title) == 'string' and payload.title or '',
        author = type(payload.author) == 'string' and payload.author or '',
        editable = Book.editable,
        maxBytes = Config.MaxBytes,
        maxPages = Config.MaxPages,
        newPages = Config.NewBookPages,
        turnMs = Config.PageTurnMs,
        holdMs = Config.UnstuckHoldMs,
        words = Locale.book,
        writer = Config.Writer,
    })
    scenarioLoop()
    deleteHoldLoop()
end)

-- the page asks to save: only an editable book that is open right now
RegisterNUICallback('save', function(data, cb)
    cb('ok')
    if not Book.open then return end
    local id, editable = Book.id, Book.editable
    Book.Close()
    if not editable or type(data) ~= 'table' or type(data.book) ~= 'string' then return end
    if #data.book > Config.MaxBytes * 2 then return end
    TriggerLatentServerEvent('pup_library:save', Config.LatentRate, id, data.book)
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    Book.Close()
end)

-- the page hit an error of its own: close once, never save
RegisterNUICallback('failed', function(_, cb)
    cb('ok')
    Book.Close()
end)

RegisterNUICallback('unstuck', function(_, cb)
    cb('ok')
    Book.Unstuck()
end)

RegisterCommand('bookunstuck', function()
    Book.Unstuck()
end, false)

RegisterNetEvent('vorp:SelectedCharacter', function()
    if Book.open then Book.Close() end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    -- release a reader: focus, scenario and any freeze the book left behind
    if Book.open then
        SetNuiFocus(false, false)
        ClearPedTasks(ped())
        FreezeEntityPosition(ped(), false)
        Book.open = false
    end
end)
