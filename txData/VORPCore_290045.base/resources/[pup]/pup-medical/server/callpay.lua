-- pup-medical | distance-based pay for answered calls

CallPay = {}

local calls = {}   -- [callId] = record

local function cfg() return Config.CallPay or {} end

local function void(id, reason)
    local c = calls[id]
    if not c then return end
    calls[id] = nil
    Debug('callPay', ('call %s voided: %s'):format(tostring(id), reason))
end

function CallPay.VoidFor(src, reason)
    for id, c in pairs(calls) do
        if c.caller == src or c.responder == src then void(id, reason or 'player involved left the call') end
    end
end

function CallPay.Void(id, reason) void(id, reason) end

-- the pay for a ride of this many units
local function payFor(distance)
    local c = cfg()
    local minD, maxD = tonumber(c.minDistance) or 0, tonumber(c.maxDistance) or 0
    local minPay, maxPay = tonumber(c.minPay) or 0, tonumber(c.maxPay) or 0
    local range = maxD - minD
    local f
    if range <= 0 then
        f = distance >= maxD and 1 or 0
    else
        f = math.max(0, math.min(1, (distance - minD) / range))
    end
    local curve = tonumber(c.curve) or 1
    if curve > 0 and curve ~= 1 then f = f ^ curve end
    local base = math.floor(minPay + f * (maxPay - minPay))
    local pay = base
    local vp = tonumber(c.variationPercent) or 0
    if vp > 0 then
        local spread = math.floor(base * vp)
        if spread > 0 then pay = pay + math.random(-spread, spread) end
    end
    local vf = math.floor(tonumber(c.variationFlat) or 0)
    if vf > 0 then pay = pay + math.random(-vf, vf) end
    return math.max(minPay, math.min(maxPay, pay)), base
end

local function moneyText(amount, currency)
    if currency == 1 then return L('moneyGold', amount) end
    if currency == 2 then return L('moneyRol', amount) end
    return L('moneyCash', amount)
end

-- on accept
function CallPay.Start(id, alert, callerSrc, responderCtx, typeKey, zone)
    local c = cfg()
    if not c.enabled then return end
    local responder = responderCtx.src
    if responder == callerSrc then return end
    if type(c.jobs) ~= 'table' or c.jobs[responderCtx.job] ~= true then return end

    local callerPos = Pos(callerSrc) or alert.coords
    local startPos = Pos(responder)
    if not callerPos or not startPos then return end

    CallPay.VoidFor(responder, 'responder took a new call')
    CallPay.VoidFor(callerSrc, 'caller has a new call')

    calls[id] = {
        id        = id,
        caller    = callerSrc,
        responder = responder,
        job       = responderCtx.job,
        callerPos = callerPos,
        startPos  = startPos,
        distance  = #(callerPos - startPos),
        accepted  = os.time(),
        typeKey   = typeKey,
        zone      = zone,
        settled   = false,
    }
    Debug('callPay', ('call %d opened: %d -> %d, %.0f units'):format(id, responder, callerSrc, calls[id].distance))
end

-- on a revive or bandage of `treated` by `treater`; kind = 'revive' | 'heal'
function CallPay.Complete(treated, treater, kind, job)
    local c = cfg()
    local id, rec = nil, nil
    for cid, r in pairs(calls) do
        if r.caller == treated then id, rec = cid, r break end
    end
    if not rec then return end
    if rec.settled then return end
    if rec.responder ~= treater then return void(id, 'treated by someone else') end
    if kind == 'heal' and not c.payOnHeal then return end
    if type(c.jobs) ~= 'table' or c.jobs[job] ~= true then return void(id, 'treating job is not paid') end

    local here = Pos(treater)
    local patient = Pos(treated)
    if not here or not patient or #(here - patient) > (tonumber(c.completeDistance) or 10.0) then
        return void(id, 'responder not with the patient')
    end

    rec.settled = true
    local moved = #(here - rec.startPos)
    local distance = math.min(rec.distance, moved)
    local pay = payFor(distance)
    local currency = math.floor(tonumber(c.currency) or 0)

    local ctx = GetCtx(treater)
    if not ctx then return void(id, 'responder has no character') end
    if pay > 0 then ctx.char.addCurrency(currency, pay) end
    TipBottom(treater, L('payDone', moneyText(pay, currency), math.floor(distance)), 6000)

    local callerCtx = GetCtx(treated)
    PostWebhook(Hook('callPayByJob', rec.job) or Hook('callPay'), {
        title  = 'Medical call completed',
        color  = Colors.green,
        fields = {
            Field('Responder', ('%s (%s) - id %d'):format(ctx.name, tostring(rec.job), treater)),
            Field('Caller', ('%s - id %d'):format(callerCtx and callerCtx.name or '?', treated)),
            Field('Zone', rec.zone),
            Field('Distance', ('%.0f'):format(distance)),
            Field('Payment', moneyText(pay, currency)),
            Field('Call', rec.id),
        },
    }, 'Medical Records')
    calls[id] = nil
end

-- open calls past the timeout
CreateThread(function()
    while true do
        Wait(60000)
        local limit = (tonumber(cfg().timeoutMinutes) or 30) * 60
        local now = os.time()
        for id, r in pairs(calls) do
            if now - r.accepted > limit then void(id, 'timed out') end
        end
    end
end)

OnPlayerLeft(function(src) CallPay.VoidFor(src, 'player left') end)

RegisterCommand('callpay', function(src)
    if src ~= 0 then return end
    local any = false
    local now = os.time()
    for id, r in pairs(calls) do
        any = true
        local _, rough = payFor(r.distance)
        print(('[pup-medical] call %d  responder %d (%s)  caller %d  %.0f units  ~%d  open %ds'):format(
            id, r.responder, tostring(r.job), r.caller, r.distance, rough, now - r.accepted))
    end
    if not any then print('[pup-medical] no open calls') end
end, true)
