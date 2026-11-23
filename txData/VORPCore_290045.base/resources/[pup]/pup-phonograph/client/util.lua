-- Client helpers: tips, guarded exports, the pup-ui input wrapper, small maths.

PC = PC or {}
PC.Res = GetCurrentResourceName()
PC.IsStaff = false

local warned = {}
function PC.WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s]^7 %s'):format(PC.Res, msg))
end

function PC.Tip(text, ms)
    TriggerEvent('vorp:TipRight', text, ms or 3000)
end

-- call exports[resource][fn](...) without letting a missing resource break us
function PC.Call(resource, fn, ...)
    local ok, r = pcall(function(...)
        local res = exports[resource]
        return res[fn](res, ...)
    end, ...)
    if not ok then
        PC.WarnOnce(resource .. ':' .. fn, ('%s export %s failed: %s'):format(resource, fn, tostring(r)))
        return nil
    end
    return r
end

function PC.Xs(fn, ...)
    return PC.Call('xsound', fn, ...)
end

function PC.Clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function PC.Menu()
    return PC.Call('pup-ui', 'GetMenuData')
end

function PC.CloseMenus()
    local m = PC.Menu()
    if m then pcall(m.CloseAll) end
end

-- One-field pup-ui input. Returns the answer as a string, '' for a blank
-- submit, or nil when cancelled, closed or unanswered within the timeout.
local inputSeq = 0
function PC.Ask(opts)
    inputSeq = inputSeq + 1
    local token = ('%s:input:%d'):format(PC.Res, inputSeq)
    local p = promise.new()
    local settled = false
    local function settle(v)
        if settled then return end
        settled = true
        p:resolve(v)
    end

    local handler = AddEventHandler('pup-ui:client:inputDone', function(owner, values)
        if owner ~= token then return end
        if type(values) ~= 'table' then settle(false) return end
        local v = values[1]
        settle(v == nil and '' or tostring(v))
    end)

    local opened = PC.Call('pup-ui', 'OpenInput', {
        owner = token,
        title = opts.title,
        subtitle = opts.subtitle,
        submit = Lang.inputSubmit,
        fields = { {
            label = opts.label,
            type = opts.type or 'text',
            placeholder = opts.placeholder,
            required = false,
        } },
    })
    if not opened then
        RemoveEventHandler(handler)
        return nil
    end

    SetTimeout(Config.Timing.inputTimeoutMs, function() settle(false) end)
    local answer = Citizen.Await(p)
    RemoveEventHandler(handler)
    if answer == false then return nil end
    return answer
end

-- the same, but a blank answer also counts as cancelled
function PC.AskValue(opts)
    local v = PC.Ask(opts)
    if v == nil then return nil end
    v = v:match('^%s*(.-)%s*$')
    if v == '' then return nil end
    return v
end

function PC.Vec(t)
    return vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0)
end
