-- The crafting flow on the client: start token, scene, skill bar, finish.
Craft = { busy = false }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

--- Pass/fail from pup-minigames' skill bar. Disabled or missing counts as a pass.
local function skillBar(diff)
    local sb = Config.SkillBar
    if not sb.enabled then return true end
    if GetResourceState('pup-minigames') ~= 'started' then return true end
    local d = tonumber(diff) or Config.DefaultDifficulty
    local zone = clamp(sb.baseZone - d * sb.zonePerPoint, sb.minZone, sb.baseZone)
    local speed = clamp(sb.baseSpeed + d * sb.speedPerPoint, sb.baseSpeed, sb.maxSpeed)

    local p = promise.new()
    local settled = false
    local function settle(v)
        if settled then return end
        settled = true
        p:resolve(v)
    end
    local ok = pcall(function()
        exports['pup-minigames']:skill_bar({
            style = 'default',
            orientation = 1,
            area_size = zone,
            perfect_area_size = sb.perfectZone,
            speed = speed,
            moving_icon = false,
        }, settle)
    end)
    if not ok then return true end
    SetTimeout(sb.timeoutMs, function() settle('timeout') end)
    local result = Citizen.Await(p)
    return result == 'success' or result == 'perfect'
end

--- The bench context as sent to the server (it re-checks all of it).
local function ctxPayload(ctx)
    if not ctx then return nil end
    return { mode = ctx.mode, name = ctx.name, model = ctx.model, pos = ctx.pos, item = ctx.item }
end

function Craft.begin(r, amount, desc)
    if Craft.busy then return Notify(L('busy')) end
    if r.locked then return Notify(r.reason or L('cannot_craft')) end
    amount = WB.int(amount)
    if not amount or amount < 1 then return Notify(L('not_amount')) end
    amount = math.min(amount, Config.MaxUnitsPerCraft)

    Prefs.data.amount = amount
    if desc then
        Prefs.data.desc = desc
        Prefs.remember(desc)
    end
    Prefs.save()

    local ctx = Bench.ctx
    Bench.close()
    Craft.busy = true

    CreateThread(function()
        local res = Req('start', { id = r.id, amount = amount, desc = desc, ctx = ctxPayload(ctx) })
        if type(res) ~= 'table' or not res.ok then
            Notify(type(res) == 'table' and res.msg or L('not_ready'))
            Craft.busy = false
            return
        end

        local ped = PlayerPedId()
        local scene = Config.CraftScene
        TaskStartScenarioInPlace(ped, joaat(scene.scenario), scene.durationMs, true, false, false, false)
        Wait(scene.skillBarAfterMs)

        local passed = false
        if not IsEntityDead(ped) then passed = skillBar(res.diff) end

        if not passed then
            Req('cancel', res.token)
            Notify(L('fumbled'))
        else
            local fin = Req('finish', res.token)
            Notify(type(fin) == 'table' and fin.msg or L('cannot_craft'), 6000)
        end
        ClearPedTasks(PlayerPedId())
        Craft.busy = false
    end)
end
