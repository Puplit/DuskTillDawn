-- pup_business | one request/answer channel for every client request
-- A handler is registered with Handle(name, gapMs, fn). fn(src, ch, ...) runs in
-- the event's own thread (it may await) and its return value goes back to the
-- caller. Requests from players without a character are dropped.

local handlers = {}

function Handle(name, gap, fn)
    handlers[name] = { gap = gap or 250, fn = fn }
end

RegisterNetEvent('pup_business:rpc', function(id, name, ...)
    local src = source
    if type(id) ~= 'number' or type(name) ~= 'string' then return end
    local h = handlers[name]
    if not h then return end

    local function reply(res)
        TriggerClientEvent('pup_business:rpcReply', src, id, res)
    end

    if not Throttle(src, 'rpc:' .. name, h.gap) then return reply(nil) end
    local ch = GetChar(src)
    if not ch then return reply(nil) end

    local ok, res = pcall(h.fn, src, ch, ...)
    if not ok then
        print(('^1[%s]^7 request %s failed: %s'):format(RES, name, tostring(res)))
        res = nil
    end
    reply(res)
end)
