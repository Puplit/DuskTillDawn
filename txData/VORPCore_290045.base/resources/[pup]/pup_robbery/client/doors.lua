-- pup_robbery | bank doors: held locked and shut unless a live run has opened them

local wanted = {} -- [hash] = true (open) / false (locked)

local ADD_DOOR = 0xD99229FE93B46286 -- AddDoorToSystemNew

local function registered(hash)
    local r = IsDoorRegisteredWithSystem(hash)
    return r == true or r == 1
end

local function apply(hash, open)
    if not registered(hash) then
        Citizen.InvokeNative(ADD_DOOR, hash, 1, 1, 0, 0, 0, 0)
    end
    if open then
        DoorSystemSetDoorState(hash, 0)
        DoorSystemSetOpenRatio(hash, 1.0, true, true)
    else
        DoorSystemSetOpenRatio(hash, 0.0, true, true)
        DoorSystemSetDoorState(hash, 1)
    end
end

local function drifted(hash, open)
    if not registered(hash) then return true end
    local state = DoorSystemGetDoorState(hash)
    if open then return state ~= 0 end
    return state ~= 1
end

local function setList(list)
    for _, pair in ipairs(list or {}) do
        local hash, open = tonumber(pair[1]), pair[2] == true
        if hash then
            wanted[hash] = open
            apply(hash, open)
        end
    end
end

RegisterNetEvent('pup_robbery:doors:set', function(list)
    setList(list)
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    Wait(5000)
    local list = C.cb('pup_robbery:doors:get')
    if type(list) == 'table' then setList(list) end
    while true do
        Wait(2000)
        for hash, open in pairs(wanted) do
            if drifted(hash, open) then apply(hash, open) end
        end
    end
end)
