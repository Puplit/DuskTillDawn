-- pup_railroad | client: track junctions, the last station passed, the dispatch board, re-sign-in

local L <const> = Rail.L

--------------------------------------------------------------------------------
-- junctions: every client sets the same points
--------------------------------------------------------------------------------
local function setJunction(track, index, value)
    Citizen.InvokeNative(Config.Natives.trackSwitch, track, index, value)
    Citizen.InvokeNative(Config.Natives.trackDirection, track, index, value)
end

local function applyJunction(i, value)
    local j = Config.Junctions[i]
    if not j or (value ~= 0 and value ~= 1) then return end
    setJunction(j.track, j.index, value)
end

function Cl.applySwitches(list)
    for k = 1, #list do
        local pair = list[k]
        if type(pair) == 'table' then applyJunction(Rail.int(pair[1]), Rail.int(pair[2])) end
    end
end

RegisterNetEvent('pup_railroad:junction', function(i, value)
    applyJunction(Rail.int(i), Rail.int(value))
end)

CreateThread(function()
    for k = 1, #Config.StartupSwitches do
        local s = Config.StartupSwitches[k]
        setJunction(s.track, s.index, s.value)
    end
end)

--------------------------------------------------------------------------------
-- last station passed (first station within 80 m, checked every 2 s)
--------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)
        local pos = GetEntityCoords(PlayerPedId())
        for i = 1, #Config.Stations do
            local st = Config.Stations[i]
            if #(pos - st.coords) <= Config.Timings.lastStation then
                Cl.lastStation = st
                break
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- dispatch board
--------------------------------------------------------------------------------
function Cl.openBoard()
    local origin = Cl.lastStation
    if not origin then return Cl.notify(L('no_last_station')) end
    local cfg = Config.Announcements
    local rows = {}
    for i = 1, #cfg.statuses do
        local s = cfg.statuses[i]
        rows[#rows + 1] = {
            label = s.label,
            description = s.description,
            action = function()
                Cl.closeMenu()
                Cl.tell('announce', 'status', origin.key, s.key)
            end,
        }
    end
    local others = {}
    for i = 1, #Config.Stations do
        if Config.Stations[i].key ~= origin.key then others[#others + 1] = Config.Stations[i] end
    end
    table.sort(others, function(a, b) return a.name < b.name end)
    for i = 1, #others do
        local dest = others[i]
        rows[#rows + 1] = {
            label = dest.name,
            description = L('bound_for', dest.name),
            action = function()
                Cl.closeMenu()
                Cl.tell('announce', 'route', origin.key, dest.key)
            end,
        }
    end
    Cl.openMenu({ title = L('board_title'), subtitle = L('board_sub', origin.name), rows = rows })
end

--------------------------------------------------------------------------------
-- character selection: sign in again a little later
--------------------------------------------------------------------------------
RegisterNetEvent('vorp:SelectedCharacter', function()
    Cl.job = nil
    SetTimeout(5000, function()
        CreateThread(Cl.signIn)
    end)
end)
