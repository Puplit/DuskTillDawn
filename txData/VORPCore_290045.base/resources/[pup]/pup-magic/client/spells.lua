-- pup-magic | spell keys: Alt + a spell's key. The allowed list only hides keys; the server checks every cast.

local ALT <const> = 164

local allowed = {}
local anyAllowed = false
local selected = false
local animBusy = false

RegisterNetEvent('pup-magic:spells', function(list)
    allowed = {}
    if type(list) == 'table' then
        for _, id in ipairs(list) do
            if type(id) == 'string' and Config.Spells[id] then allowed[id] = true end
        end
    end
    anyAllowed = next(allowed) ~= nil
    Dbg('spells allowed: %d', #(type(list) == 'table' and list or {}))
end)

local function askSpells() TriggerServerEvent('pup-magic:askSpells') end

RegisterNetEvent('vorp:SelectedCharacter', function()
    selected = true
    Aim.locked = nil
    askSpells()
end)

CreateThread(function()
    if Config.General.debug then askSpells() end
    Wait(1000)
    if not selected then askSpells() end
end)

local function send(id, point, targetSid)
    local msg = { id = id, target = targetSid }
    if point then msg.point = { x = point.x + 0.0, y = point.y + 0.0, z = point.z + 0.0 } end
    TriggerServerEvent('pup-magic:cast', msg)
end

local function playAnim(spell)
    if animBusy then return end
    animBusy = true
    CreateThread(function()
        local a = spell.anim
        local dur = tonumber(a.dur) or 2000
        if LoadAnimDict(a.dict, 3000) then
            local ped = PlayerPedId()
            TaskPlayAnim(ped, a.dict, a.name, 1.0, 1.0, dur, 0, 1.0, false, false, false, '', false)
            Wait(dur)
            ClearPedTasks(PlayerPedId())
        end
        animBusy = false
    end)
end

local Cast = {}

function Cast.aimdot()
    Aim.marker = not Aim.marker
    TipRight(Aim.marker and Locale.aimOn or Locale.aimOff, 2000)
end

function Cast.anim(_, spell) playAnim(spell) end

function Cast.aura(id, spell)
    PlayEmote(spell.emote)
    local target = (not spell.self) and Aim.lockedServerId() or nil
    send(id, nil, target)
end

local function bomb(id, spell)
    local range = tonumber(spell.range) or 60.0
    local ped, point, sid = Aim.pick(range, nil)
    if spell.effect == 'bombpunch' and not ped then
        TipRight(Locale.noReach, 3000)
        return
    end
    PlayEmote(spell.emote)
    send(id, point, sid)
end
Cast.bombpunch = bomb
Cast.bombtoss = bomb

local function selfCentred(id, spell)
    PlayEmote(spell.emote)
    send(id, GetEntityCoords(PlayerPedId()), nil)
end
Cast.rocketleap = selfCentred
Cast.detonate = selfCentred

local function aimed(id, spell)
    local ped, point, sid = Aim.pick(250.0, 3.0)
    if (spell.effect == 'shock' or spell.effect == 'transform') and not ped then
        TipRight(spell.noTarget or Locale.noReach, 3000)
        return
    end
    PlayEmote(spell.emote)
    send(id, point, sid)
end
Cast.smoke = aimed
Cast.lightning = aimed
Cast.shock = aimed
Cast.transform = aimed

local function cast(id)
    local spell = Config.Spells[id]
    if not spell then return end
    local fn = Cast[spell.effect]
    if not fn then return end
    Dbg('cast %s (%s)', id, spell.effect)
    -- the aiming can wait a few frames for the shape test, so it runs off the key loop
    CreateThread(function() fn(id, spell) end)
end

CreateThread(function()
    while true do
        if not anyAllowed then
            Wait(1000)
        else
            if IsRawKeyDown(ALT) then
                for _, k in ipairs(MagicKeys) do
                    if IsRawKeyReleased(k.raw) and allowed[k.id] then cast(k.id) end
                end
            end
            Wait(0)
        end
    end
end)
