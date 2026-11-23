-- pup_camps | snake-bite poison on the client (the server keeps the record)

local P = Config.Poison
local poisoned = false
local ticks = 0
local effectOn, walkOn = false, false
local snakeModels = {}
for _, m in ipairs(P.snakeModels) do snakeModels[U.h32(m)] = true end
local SNAKE_WEAPON <const> = GetHashKey(P.snakeWeapon)

-- forget every old hit: the weapon record too, or a past bite still reads as a new one after a cure
local function forgetBites()
    local ped = PlayerPedId()
    ClearEntityLastDamageEntity(ped)
    Citizen.InvokeNative(0xAC678E40BE7C74D2, ped) -- CLEAR_ENTITY_LAST_WEAPON_DAMAGE
end

local function stopEffects()
    local ped = PlayerPedId()
    if effectOn then AnimpostfxStop(Config.Effects.poison) end
    if walkOn then N(0x923583741DC87BCE, ped, 'arthur_healthy') N(0x89F5E7ADECCCB49C, ped, 'default') end
    effectOn, walkOn = false, false
end

-- the antidote is drunk like a water bottle: the game's own "Drink" prompt on a bottle in hand.
-- The long-bottle prompt reads its name from the WHISKEY text entry, so it is renamed for the drink
-- and put back after (text entries are global).
local BOTTLE_KEY <const> = 'WHISKEY'
local function drinkAntidote()
    local ped = PlayerPedId()
    local model = LoadModel(P.drinkProp or 'p_bottlewine01x')
    if not model then -- no bottle model: fall back to the old scenario
        Scenario(Config.Anim.drink, 4000)
        Wait(4000)
        StopScenario()
        return
    end
    local label = L('poison_drink')
    local original = Citizen.InvokeNative(0x3429670F9B9EF2D3, BOTTLE_KEY, Citizen.ResultAsString())
    AddTextEntry(BOTTLE_KEY, label)
    local bottle = CreateObject(model, GetEntityCoords(ped), false, true, false, false, true)
    SetModelAsNoLongerNeeded(model)
    if bottle and bottle ~= 0 then
        pcall(Citizen.InvokeNative, 0xAEE6C800E124CFE1, bottle, label) -- the bottle's own prompt name
        TaskItemInteraction_2(ped, -1199896558, bottle, GetHashKey('p_bottleJD01x_ph_r_hand'),
            GetHashKey('DRINK_BOTTLE@Bottle_Cylinder_D1-3_H30-5_Neck_A13_B2-5_TABLE_HOLD'), 1, 0, -1.0)
        -- the game removes the bottle when the player is done with it
        local deadline = GetGameTimer() + 30000
        while DoesEntityExist(bottle) and GetGameTimer() < deadline do Wait(100) end
        if DoesEntityExist(bottle) then DeleteEntity(bottle) end
    end
    AddTextEntry(BOTTLE_KEY, original or 'Whiskey')
end

local function cure(fade)
    poisoned = false
    ticks = 0
    forgetBites()
    stopEffects()
    if fade then drinkAntidote() end
end

local loopGen = 0

-- one tick loop at a time: a cure + re-poison (or a character restart) inside one tick
-- would otherwise leave the old loop running beside the new one and double the damage
local function tickLoop()
    loopGen = loopGen + 1
    local gen = loopGen
    CreateThread(function()
        while poisoned and gen == loopGen do
            Wait(P.tickSeconds * 1000)
            if not poisoned or gen ~= loopGen then break end
            local ped = PlayerPedId()
            if not IsEntityDead(ped) then
                ticks = ticks + 1
                if ticks >= P.effectAfter and not effectOn then
                    print('^3[pup_camps poison]^7 screen effect on (' .. tostring(Config.Effects.poison) .. ')')
                    effectOn = true
                    AnimpostfxPlay(Config.Effects.poison)
                end
                if ticks >= P.walkAfter and not walkOn then
                    walkOn = true
                    N(0x923583741DC87BCE, ped, 'default')
                    N(0x89F5E7ADECCCB49C, ped, Config.Anim.sickWalk)
                end
                if P.healthDamage and ticks >= P.damageAfter then
                    local hp = GetEntityHealth(ped)
                    local dmg = math.floor(GetEntityMaxHealth(ped) / P.damageDivisor)
                    local target = math.max(P.healthFloor, hp - dmg)
                    if target < hp then SetEntityHealth(ped, target, 0) end
                end
            elseif P.cureOnDeath then
                if Request('poisonClearDead') then cure(false) end
            end
        end
    end)
end

local function becomePoisoned()
    if poisoned then return end
    poisoned = true
    ticks = 0
    CreateThread(function() Request('poisonBit') end)
    tickLoop()
end

-- bitten? read the game's damage events: each one is a single new hit, unlike the
-- "has been damaged by" records, which RedM keeps for good and would re-poison after every cure
local DAMAGE_EVENT <const> = U.h32(GetHashKey('EVENT_ENTITY_DAMAGED'))
local SNAKE_WEAPON_U <const> = U.h32(SNAKE_WEAPON)

-- EVENT_ENTITY_DAMAGED data: [0] damaged entity, [1] attacker, [2] weapon hash (8 bytes a field).
-- The buffer is longer than 40 bytes so Lua never shares (interns) it.
local function readDamage(index)
    local buf = string.rep('\0', 128)
    Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 0, index, buf, 9) -- GET_EVENT_DATA
    return string.unpack('<i4', buf, 1), string.unpack('<i4', buf, 9), string.unpack('<i4', buf, 17)
end

CreateThread(function()
    while true do
        if not (P.enabled and State.started) then
            Wait(1000)
        else
            Wait(0)
            local count = GetNumberOfEvents(0)
            if count > 0 and not poisoned then
                local me = PlayerPedId()
                for i = 0, count - 1 do
                    if U.h32(GetEventAtIndex(0, i)) == DAMAGE_EVENT then
                        local victim, attacker, weapon = readDamage(i)
                        if victim == me then
                            local bySnake = U.h32(weapon) == SNAKE_WEAPON_U
                                or (attacker ~= 0 and DoesEntityExist(attacker) and snakeModels[U.h32(GetEntityModel(attacker))])
                            if bySnake then
                                print('^3[pup_camps poison]^7 poisoned by: a new snake bite')
                                forgetBites()
                                becomePoisoned()
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('pup_camps:cl:poisonCured', function()
    if poisoned then CreateThread(function() cure(true) end) end
end)

OnState('start', function(_, delay)
    poisoned = false
    forgetBites()
    stopEffects()
    if not P.enabled then return end
    SetTimeout((tonumber(delay) or 10) * 1000, function()
        if Request('poisonStatus') == true and not poisoned then
            print('^3[pup_camps poison]^7 poisoned by: the server still had you as poisoned on load')
            poisoned = true
            ticks = 0
            tickLoop()
        end
    end)
end)

OnState('stop', function()
    poisoned = false
    stopEffects()
end)
