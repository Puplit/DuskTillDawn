-- pup_shaman | animal forms on the client: shifting, the form loop, abilities, being struck

Forms = {}

local sitting = false
local cooldownUntil = 0  -- strike countdown, started only when the server accepts a strike
local lastSend = 0
local prompt, promptGroup

local function ensurePrompt()
    if prompt then return end
    promptGroup = GetRandomIntInRange(1, 0xFFFFFF)
    prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, Config.Shift.returnKey)
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', L('prompt_return')))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetHoldMode(prompt, Config.Shift.returnHoldMs)
    UiPromptSetGroup(prompt, promptGroup, 0)
    UiPromptRegisterEnd(prompt)
end

local function standUp()
    if not sitting then return end
    sitting = false
    ClearPedTasks(PlayerPedId())
    if Shaman.form then Shaman.SetSize(Shaman.form.size) end -- clearing tasks drops the size
end

--- Back to the human body. dead = the form died: the player is left dead.
function Forms.ReturnToHuman(dead)
    if not Shaman.form then return end
    Shaman.busy = true
    Shaman.form = nil
    sitting = false
    Shaman.FadeOut()
    Shaman.RestoreHuman(dead)
    TriggerServerEvent('pup_shaman:server:human', false)
    if dead then TriggerServerEvent('pup_shaman:server:died', true) end
    Shaman.FadeIn()
    Shaman.busy = false
end

local function formLoop()
    CreateThread(function()
        ensurePrompt()
        while Shaman.form do
            local f = Shaman.form
            Shaman.DisableControls(f.def.noJump)
            UiPromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', f.def.label), 0, 0, 0, 0)
            if not Shaman.busy then
                if Shaman.IsDead() then
                    Forms.ReturnToHuman(true)
                    break
                elseif UiPromptHasHoldModeCompleted(prompt) then
                    Forms.ReturnToHuman(false)
                    break
                elseif f.endsAt and GetGameTimer() >= f.endsAt then
                    Shaman.Tip(L('shift_wears_off'))
                    Forms.ReturnToHuman(false)
                    break
                end
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('pup_shaman:client:shift', function(formKey, coat, useAlt, bloodMoon)
    local form = Config.Forms[formKey]
    if not form or Shaman.form or Shaman.dream or Shaman.busy then
        return TriggerServerEvent('pup_shaman:server:human', true)
    end
    Shaman.busy = true
    Shaman.FadeOut()
    local ped = Shaman.BecomeAnimal(useAlt and form.altModel or form.model, coat)
    if not ped then
        Shaman.FadeIn()
        Shaman.busy = false
        return TriggerServerEvent('pup_shaman:server:human', true)
    end
    if Config.Shift.invincible then Shaman.Shield(ped) end
    local size = Rules.Size(form, coat, bloodMoon)
    Shaman.SetSize(size)
    local limit = Config.Shift.timeLimitMinutes
    Shaman.form = {
        key = formKey, def = form, coat = coat, bloodMoon = bloodMoon, size = size,
        endsAt = limit > 0 and GetGameTimer() + limit * 60000 or nil,
    }
    sitting = false
    Shaman.FadeIn()
    Shaman.busy = false
    TriggerServerEvent('pup_shaman:server:shifted')
    Shaman.Tip(L('shifted', form.label, coat, Config.Shift.returnCommand, Config.Shift.returnKeyLabel), 6000)
    if bloodMoon then Shaman.Tip(L('shift_bloodmoon')) end
    formLoop()
end)

-- chat commands: /wolf [coat] [mp], /bear, /bat, /cat
for key, form in pairs(Config.Forms) do
    RegisterCommand(form.command, function(_, args)
        if Shaman.IsDead() then return Shaman.Tip(L('shift_dead')) end
        if Shaman.form or Shaman.dream or Shaman.busy then return Shaman.Tip(L('shift_busy')) end
        local hour = GetClockHours()
        if form.nightOnly and not Rules.InNightWindow(form, hour) then return Shaman.Tip(L('shift_night')) end
        TriggerServerEvent('pup_shaman:server:shift', key, tonumber(args[1]), args[2] == 'mp', hour)
    end, false)
end

RegisterCommand(Config.Shift.returnCommand, function()
    if Shaman.form and not Shaman.busy then
        CreateThread(function() Forms.ReturnToHuman(false) end)
    end
end, false)

-- a curse change can take the form away
AddEventHandler('pup_shaman:client:curseUpdated', function(key)
    if Shaman.form and not Shaman.busy and Rules.FormOf(key) ~= Shaman.form.key then
        CreateThread(function() Forms.ReturnToHuman(false) end)
    end
end)

-- abilities ------------------------------------------------------------------------

local function ability(name)
    local f = Shaman.form
    if not f or Shaman.busy or IsNuiFocused() then return nil end
    return f.def.abilities and f.def.abilities[name] or nil
end

local handlers = {
    howl = function(a)
        standUp()
        Shaman.PlayAnim(PlayerPedId(), a.dict, a.clip, a.ms, 0)
        TriggerEvent('pup_shaman:howled')
    end,
    sit = function(a)
        if sitting then return standUp() end
        if Shaman.PlayAnim(PlayerPedId(), a.dict, a.clip, -1, 1) then sitting = true end
    end,
    attack = function()
        local now = GetGameTimer()
        if now - lastSend < Config.Shift.attackResendMs then return end
        if now < cooldownUntil then
            return Shaman.Tip(L('strike_spent', math.ceil((cooldownUntil - now) / 1000)))
        end
        local atk = Rules.Attack(Shaman.form.def)
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local best, bestDist
        for _, pl in ipairs(GetActivePlayers()) do
            if pl ~= PlayerId() then
                local other = GetPlayerPed(pl)
                if other ~= 0 and DoesEntityExist(other) then
                    local d = #(pos - GetEntityCoords(other))
                    if d <= atk.range and (not best or d < bestDist) then best, bestDist = pl, d end
                end
            end
        end
        if not best then return Shaman.Tip(L('strike_none')) end
        lastSend = now
        standUp()
        if atk.dict then Shaman.PlayAnim(ped, atk.dict, atk.clip, atk.ms, 0) end
        TriggerServerEvent('pup_shaman:server:attack', GetPlayerServerId(best))
    end,
}

for _, k in ipairs(Config.AbilityKeys) do
    RegisterCommand(k.command, function()
        local a = ability(k.ability)
        if a then handlers[k.ability](a) end
    end, false)
    RegisterKeyMapping(k.command, k.description, 'keyboard', k.key)
end

RegisterNetEvent('pup_shaman:client:attackAccepted', function(seconds)
    cooldownUntil = GetGameTimer() + (tonumber(seconds) or 0) * 1000
end)

RegisterNetEvent('pup_shaman:client:struck', function(damage, ragdollMs)
    local ped = PlayerPedId()
    if Shaman.IsDead(ped) then return end
    -- an invincible form and a spirit vision cannot be hurt (SetEntityHealth ignores invincibility)
    local shielded = Shaman.dream ~= nil or (Shaman.form ~= nil and Config.Shift.invincible)
    damage = math.max(0, math.floor(tonumber(damage) or 0))
    if not shielded then
        SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - damage))
    end
    ragdollMs = tonumber(ragdollMs)
    if ragdollMs and ragdollMs > 0 then
        SetPedToRagdoll(ped, ragdollMs, ragdollMs, 0, false, false, false)
    end
    local shake = Config.Shift.struckShake
    ShakeGameplayCam(shake.name, shake.amplitude)
    Shaman.Tip(L('struck'))
end)

-- the character changed: drop the form without rebuilding (vorp_character spawns the new one)
Shaman.OnReset(function()
    if not Shaman.form then return end
    Shaman.form = nil
    sitting = false
    Shaman.SetSize(1.0)
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
    SetPedCanRagdoll(ped, true)
    TriggerEvent('vorpinventory:ammoUpdateToggle', true)
end)

Shaman.OnStop(function()
    if prompt then UiPromptDelete(prompt) end
    if not Shaman.form then return end
    Shaman.form = nil
    Citizen.InvokeNative(Shaman.N.setPedScale, PlayerPedId(), 1.0)
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
    SetPedCanRagdoll(ped, true)
    ExecuteCommand(Config.Shift.rebuildCommand)
    TriggerEvent('vorpinventory:ammoUpdateToggle', true)
end)
