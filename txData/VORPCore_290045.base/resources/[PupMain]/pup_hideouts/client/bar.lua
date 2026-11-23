-- pup_hideouts | the bar (pour, almonds, drink, wash) and the piano skill check

local B <const> = Config.Bar
local PI <const> = Config.Piano

local N <const> = {
    setDrunk = 0x406CCF555B04FAD3,    -- _SET_PED_DRUNKNESS
    fxStrength = 0xCAB4DD2D5B2B7246,  -- ANIMPOSTFX_SET_STRENGTH
    usingScenario = 0x34D6AC1157C8226C, -- IS_PED_USING_SCENARIO_HASH
}

HX.Bar = {}
local poured = false
local working = false
local drunk, distort = 0, 0.0

function HX.Bar.poured() return poured end

local function meta(t)
    if not Config.FredMeta then return end
    TriggerEvent('fred_meta:consume', t.hunger, t.thirst, t.metabolism, 0, 0.0, 0, 0, 0, 0.0, 0.0)
end

-- play a scenario (by hash) for some seconds; the effect lands whatever the animation does
local function scenario(hash, seconds)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    TaskStartScenarioInPlace(ped, hash, seconds * 1000, true, false, false, false)
    Wait(seconds * 1000)
    ClearPedTasks(ped)
end

----------------------------------------------------------------------------------------------------
-- drunk effects
----------------------------------------------------------------------------------------------------
local function applyDrunk()
    local ped = PlayerPedId()
    local t1, t2, t3 = B.thresholds[1], B.thresholds[2], B.thresholds[3]
    if drunk < t1 then
        Citizen.InvokeNative(N.setDrunk, ped, false, 0.0)
        AnimpostfxStop(B.drunkFx)
        AnimpostfxStop(B.lensFx)
        return
    end
    local level = drunk <= t2 and 0.3 or drunk <= t3 and 0.6 or 1.0
    Citizen.InvokeNative(N.setDrunk, ped, true, level)
    if drunk > t3 then
        if not AnimpostfxIsRunning(B.drunkFx) then AnimpostfxPlay(B.drunkFx) end
    else
        AnimpostfxStop(B.drunkFx)
    end
    if distort > 0.0 then
        if not AnimpostfxIsRunning(B.lensFx) then AnimpostfxPlay(B.lensFx) end
        Citizen.InvokeNative(N.fxStrength, B.lensFx, distort)
    else
        AnimpostfxStop(B.lensFx)
    end
end

local function soberUp()
    drunk, distort = 0, 0.0
    applyDrunk()
end

-- wear-off, one step a minute while drunk
CreateThread(function()
    while true do
        Wait(B.wearEvery * 1000)
        if drunk > 0 or distort > 0.0 then
            drunk = math.max(0, drunk - B.wearDrunk)
            distort = math.max(0.0, distort - B.wearDistort)
            if drunk == 0 then distort = 0.0 end
            applyDrunk()
        end
    end
end)

----------------------------------------------------------------------------------------------------
-- the actions
----------------------------------------------------------------------------------------------------
function HX.Bar.pour()
    if working or poured then return end
    working = true
    scenario(B.scenarioPoints.pour, B.pourSeconds)
    poured = true
    working = false
end

function HX.Bar.almonds()
    if working then return end
    working = true
    meta(B.almonds)
    scenario(B.scenarioPoints.almonds, B.almondSeconds)
    working = false
end

function HX.Bar.drink()
    if working or not poured then return end
    working = true
    poured = false
    drunk = drunk + B.drunkPerDrink
    distort = math.min(B.distortCap, distort + B.distortPerDrink)
    local ped = PlayerPedId()
    local name = (IsPedMale(ped) and drunk >= B.thresholds[3]) and B.drunkScenario or B.drinkScenario
    scenario(joaat(name), B.drinkSeconds)
    applyDrunk()
    meta(B.moonshine)
    working = false
end

function HX.Bar.wash()
    if working then return end
    working = true
    scenario(B.scenarioPoints.wash, B.washSeconds)
    soberUp()
    local ped = PlayerPedId()
    ClearPedBloodDamage(ped)
    ClearPedEnvDirt(ped)
    ClearPedWetness(ped)
    working = false
end

-- a drink poured inside does not follow you out
AddEventHandler('pup_hideouts:leavingHideout', function() poured = false end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if drunk > 0 or distort > 0.0 then soberUp() end
end)

----------------------------------------------------------------------------------------------------
-- piano: a skill check every few seconds while playing. The difficulty value (start 5000,
-- falling to 1000) is mapped onto the bar's 1-5 scale. The result pays nothing.
----------------------------------------------------------------------------------------------------
local function playingPiano(ped)
    for _, s in ipairs(PI.scenarios) do
        local v = Citizen.InvokeNative(N.usingScenario, ped, joaat(s))
        if v == true or v == 1 then return true end
    end
    return false
end

-- 5000 -> 1 (easiest), 1000 -> 5 (hardest)
local function pianoLevel(value)
    local span = math.max(1, PI.startDifficulty - PI.floor)
    local t = (PI.startDifficulty - value) / span
    return math.max(1, math.min(5, 1 + math.floor(t * 4 + 0.5)))
end

if PI.enabled then
    CreateThread(function()
        local difficulty = PI.startDifficulty
        local restUntil = 0
        local wasPlaying = false
        while true do
            Wait(PI.everySeconds * 1000)
            local ped = PlayerPedId()
            local playing = playingPiano(ped)
            if wasPlaying and not playing then
                difficulty = PI.startDifficulty
                restUntil = GetGameTimer() + PI.restMinutes * 60000
            end
            wasPlaying = playing
            if playing and GetGameTimer() >= restUntil then
                HX.skillBarLevel(pianoLevel(difficulty))
                difficulty = math.max(PI.floor, difficulty - math.random(PI.dropMin, PI.dropMax))
            end
        end
    end)
end
