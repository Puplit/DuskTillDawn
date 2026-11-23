-- pup_camps | one prompt loop for everything the player can press a key at
-- Providers are scanned a few times a second; the chosen candidate is drawn and its keys
-- are read every frame only while one is in reach. Far from everything the loop sleeps.

Interact = {}

local providers = {}
local KEY_NAMES <const> = {
    [Config.Keys.interact] = 'G', [Config.Keys.confirm] = 'ENTER', [Config.Keys.stash] = 'CTRL',
    [Config.Keys.handIn] = 'X', [Config.Keys.cancel] = 'BACKSPACE',
}

-- fn(pos, ped) returns a candidate or nil:
-- { dist = number, title = string, keys = { { control = hash, label = string, fn = function } }, still = fn(pos) optional }
function Interact.add(fn)
    providers[#providers + 1] = fn
end

local suppressedUntil = 0
function Interact.suppress(ms)
    suppressedUntil = GetGameTimer() + (ms or 1000)
end

local current = nil
local running = false

local function scan(pos, ped)
    local best
    for _, fn in ipairs(providers) do
        local ok, c = pcall(fn, pos, ped)
        if ok and c and (not best or c.dist < best.dist) then best = c end
    end
    return best
end

local function promptText(c)
    local parts = {}
    for i, k in ipairs(c.keys) do
        if i > 1 then parts[#parts + 1] = ('[%s] %s'):format(KEY_NAMES[k.control] or '?', k.label) end
    end
    local first = c.keys[1]
    local label = (c.title and c.title ~= '' and (c.title .. ': ') or '') .. first.label
    if #parts > 0 then label = label .. '   ' .. table.concat(parts, '   ') end
    return KEY_NAMES[first.control] or 'G', label
end

CreateThread(function()
    local lastScan = 0
    while true do
        local wait = 500
        -- calling mode reads G itself; a prompt here would fire on the same press
        local calling = Calling ~= nil and Calling.active ~= nil and Calling.active()
        if State.started and not State.busy and not running and not calling and GetGameTimer() >= suppressedUntil and not IsDeadOrDying() then
            local ped = PlayerPedId()
            local now = GetGameTimer()
            if now - lastScan >= 300 then
                lastScan = now
                current = scan(PedPos(), ped)
            end
            if current then
                wait = 0
                if current.still and not current.still(PedPos()) then
                    current = nil
                else
                    local key, label = promptText(current)
                    if UiRunning() then exports['pup-ui']:Prompt({ key = key, label = label }) end
                    for _, k in ipairs(current.keys) do
                        DisableControlAction(0, k.control, true)
                        if IsDisabledControlJustReleased(0, k.control) or IsControlJustReleased(0, k.control) then
                            local fn = k.fn
                            current = nil
                            running = true
                            pcall(function() exports['pup-ui']:PromptHide() end)
                            CreateThread(function()
                                local ok, err = pcall(fn)
                                if not ok then print('^1[pup_camps]^7 action failed: ' .. tostring(err)) end
                                running = false
                            end)
                            break
                        end
                    end
                end
            end
        else
            current = nil
        end
        Wait(wait)
    end
end)
