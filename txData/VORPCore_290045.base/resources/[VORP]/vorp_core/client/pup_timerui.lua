-- Modified by Puppet (Dusk Till Dawn), 2026
-- The game's story-mission countdown. Shared here because its state machine is global game state.
-- exports.vorp_core:TimerStart(seconds, low) / TimerUpdate(seconds, low) / TimerStop()

local MACHINE <const> = 1546991729
local data = nil
local owner = nil   -- resource that put it up; only that one may drive or take it down

-- these answer with a NUMBER, and 0 is truthy in Lua, so never test them bare
local function on(v)
    return v == true or v == 1
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes <const> = math.floor(seconds / 60)
    return ('%02d:%02d'):format(minutes, seconds - minutes * 60)
end

local function init()
    if data then return true end

    local block <const> = Citizen.InvokeNative(0xC0081B34E395CE48, -119209833)
    local waited = 0
    while not on(UiflowblockIsLoaded(block)) do
        waited = waited + 1
        if waited > 10000 then
            print('^1[vorp_core]^7 timer flowblock never loaded')
            return false
        end
        Citizen.Wait(1)
    end

    local d = { block = block }
    d.container = DatabindingAddDataContainerFromPath('', 'centralInfoDatastore')
    -- blank on purpose, or the stock "Message" label sits on top of the time
    DatabindingAddDataString(d.container, 'timerMessageString', '')
    d.timer = DatabindingAddDataString(d.container, 'timerString', '')
    d.show  = DatabindingAddDataBool(d.container, 'isVisible', false)
    -- declared once, written below: adding it per tick re-registers the entry
    d.low   = DatabindingAddDataBool(d.container, 'isTimerLow', false)

    UiflowblockEnter(block, `cTimer`)
    if UiStateMachineExists(MACHINE) == 0 then
        UiStateMachineCreate(MACHINE, block)
    end

    data = d
    return true
end

local function write(seconds, low)
    if not data then return end
    DatabindingWriteDataString(data.timer, formatTime(seconds))
    DatabindingWriteDataBool(data.low, low ~= nil and seconds <= low)
end

local function teardown()
    local d <const> = data
    if not d then return end
    data, owner = nil, nil

    DatabindingWriteDataBool(d.show, false)
    if UiStateMachineExists(MACHINE) ~= 0 then
        UiStateMachineDestroy(MACHINE)
    end
    for _, entry in ipairs({ d.low, d.show, d.timer, d.container }) do
        if on(DatabindingIsEntryValid(entry)) then DatabindingRemoveDataEntry(entry) end
    end
end

--- seconds left, and the mark below which the clock turns red
exports('TimerStart', function(seconds, low)
    local who <const> = GetInvokingResource() or GetCurrentResourceName()
    -- first one up keeps it; a second caller is ignored rather than stealing the bindings
    if data and owner and owner ~= who then return false end
    if not init() then return false end
    owner = who
    write(seconds, low)
    DatabindingWriteDataBool(data.show, true)
    return true
end)

exports('TimerUpdate', function(seconds, low)
    local who <const> = GetInvokingResource() or GetCurrentResourceName()
    if owner ~= who then return false end
    write(seconds, low)
    return true
end)

exports('TimerStop', function()
    local who <const> = GetInvokingResource() or GetCurrentResourceName()
    if owner ~= nil and owner ~= who then return false end
    teardown()
    return true
end)

-- the owner stopping with its clock still up would strand it on screen
AddEventHandler('onClientResourceStop', function(res)
    if res == owner or res == GetCurrentResourceName() then teardown() end
end)
