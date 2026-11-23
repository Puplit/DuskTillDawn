-- pup_shaman | animal forms: who may shift, and strikes between players

Forms = {}

local lastShift = {}    -- src -> os.time() of the last accepted shift
local pendingShift = {} -- src -> { previous = lastShift before it, at = os.time() } until the client confirms the swap
local attackReady = {}  -- src -> GetGameTimer() when the next strike is allowed

--- The in-game hour as the server sees it, or nil when it cannot tell.
local function serverHour()
    local fn = Config.Shift.serverHour
    if type(fn) ~= 'function' then return nil end
    local ok, hour = pcall(fn)
    hour = ok and tonumber(hour) or nil
    if hour and hour >= 0 and hour < 24 then return math.floor(hour) end
    return nil
end

RegisterNetEvent('pup_shaman:server:shift', function(formKey, coat, alt, clientHour)
    local src = source
    if not Shaman.Throttle(src, 'shift', 1000) then return end
    if type(formKey) ~= 'string' then return end
    local form = Config.Forms[formKey]
    local char = Shaman.Character(src)
    if not char or not form then return end
    if char.isdead == true or char.isdead == 1 then
        return Shaman.Notify(src, L('shift_dead'))
    end
    local charId = tonumber(char.charIdentifier)

    local curse = Store.Get(src)
    if not Shaman.SameChar(src, charId) then return end
    if Rules.FormOf(curse) ~= formKey then
        return Shaman.Notify(src, L('shift_no_curse'))
    end
    if Shaman.Form(src) or Trees.IsDreaming(src) or Rituals.InSession(src) then
        return Shaman.Notify(src, L('shift_busy'))
    end
    if form.nightOnly then
        local hour = serverHour()
        if hour == nil then
            hour = tonumber(clientHour)
            if hour and (hour < 0 or hour > 23) then hour = nil end
        end
        if not Rules.InNightWindow(form, hour) then
            return Shaman.Notify(src, L('shift_night'))
        end
    end
    local now = os.time()
    local cd = Config.Shift.cooldownSeconds
    if lastShift[src] and now - lastShift[src] < cd then
        return Shaman.Notify(src, L('shift_cooldown', cd - (now - lastShift[src])))
    end

    pendingShift[src] = { previous = lastShift[src], at = now, form = formKey }
    lastShift[src] = now
    local coatN = Rules.Coat(form, coat)
    local useAlt = alt == true and form.altModel ~= nil
    local bloodMoon = form.bloodMoon ~= nil and Shaman.BloodMoon()
    Shaman.SetForm(src, formKey)
    TriggerClientEvent('pup_shaman:client:shift', src, formKey, coatN, useAlt, bloodMoon)
end)

-- the swap worked: the cooldown stays spent
RegisterNetEvent('pup_shaman:server:shifted', function()
    pendingShift[source] = nil
end)

-- the player is human again (back from a form, a failed swap, or a vision)
RegisterNetEvent('pup_shaman:server:human', function(failedSwap)
    local src = source
    if not Shaman.Online(src) then return end
    Shaman.SetForm(src, nil)
    local pending = pendingShift[src]
    pendingShift[src] = nil
    -- a model that never loaded does not cost the cooldown; a ped the server still sees as the
    -- animal did load, so a client that claims otherwise keeps its cooldown
    if failedSwap == true and pending and os.time() - pending.at <= 30 then
        local form = Config.Forms[pending.form]
        local ped = Shaman.Ped(src)
        local model = ped and (GetEntityModel(ped) & 0xFFFFFFFF)
        local function is(name) return name ~= nil and model == (joaat(name) & 0xFFFFFFFF) end
        local isAnimal = form and model and (is(form.model) or is(form.altModel))
        if not isAnimal then lastShift[src] = pending.previous end
    end
end)

RegisterNetEvent('pup_shaman:server:attack', function(target)
    local src = source
    if not Shaman.Throttle(src, 'attack', 500) then return end
    if not Shaman.Character(src) then return end
    local formKey = Shaman.Form(src)
    local form = formKey and Config.Forms[formKey]
    local attack = Rules.Attack(form)
    if not attack then return end
    target = tonumber(target)
    if not target or target == src or not Shaman.Online(target) then return end
    local now = GetGameTimer()
    if attackReady[src] and now < attackReady[src] then return end
    local a, b = Shaman.Coords(src), Shaman.Coords(target)
    if not a or not b or #(a - b) > attack.range + Config.Shift.attackSlack then return end

    attackReady[src] = now + attack.cooldownSeconds * 1000
    local damage = attack.damage
    if form.bloodMoon and form.bloodMoon.damage and Shaman.BloodMoon() then
        damage = damage * form.bloodMoon.damage
    end
    damage = math.floor(damage)
    TriggerClientEvent('pup_shaman:client:struck', target, damage, attack.ragdollMs)
    TriggerClientEvent('pup_shaman:client:attackAccepted', src, attack.cooldownSeconds)

    -- the bite may pass the curse on
    local curseKey = Store.Get(src)
    local def = Rules.Curse(curseKey)
    if def and def.form == formKey and (def.spreadChance or 0) > 0 then
        if Shaman.Character(target) and Store.Get(target) == '' and math.random() < def.spreadChance then
            Store.Set(target, curseKey, 'change')
        end
    end
end)

function Forms.Forget(src)
    lastShift[src] = nil
    pendingShift[src] = nil
    attackReady[src] = nil
end

Shaman.OnLeave(function(src)
    Forms.Forget(src)
end)
