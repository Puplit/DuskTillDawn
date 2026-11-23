-- pup_business | client side of the request/answer channel
-- Call(name, ...) must run inside a thread. It returns the server's answer, or
-- nil after the timeout, so nothing waits forever on a lost reply.

local pending = {}
local seq = 0
local TIMEOUT_MS <const> = 5000

function Call(name, ...)
    seq = seq + 1
    local id = seq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('pup_business:rpc', id, name, ...)
    SetTimeout(TIMEOUT_MS, function()
        if pending[id] then
            pending[id] = nil
            p:resolve(nil)
        end
    end)
    return Citizen.Await(p)
end

-- fire and forget (still answered, the answer is just dropped)
function Send(name, ...)
    local args = table.pack(...)
    CreateThread(function() Call(name, table.unpack(args, 1, args.n)) end)
end

RegisterNetEvent('pup_business:rpcReply', function(id, result)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    p:resolve(result)
end)

function Tip(text, ms)
    TriggerEvent('vorp:TipRight', tostring(text), ms or 4000)
end

function TipBottom(text, ms)
    TriggerEvent('vorp:TipBottom', tostring(text), ms or 4000)
end
