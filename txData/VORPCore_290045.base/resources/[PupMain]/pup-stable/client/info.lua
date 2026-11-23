-- pup-stable | the game's own horse info card (SHOP_BROWSING app + InfoBox databinding) on any targeted horse

Info = { horse = nil, entries = {}, token = 0, lastToggle = 0 }

local Inv = Citizen.InvokeNative
local APP = joaat('SHOP_BROWSING')
local APP_ENTRY = -649639953
local HUD_CTX = joaat('HUD_CTX_INFO_CARD')
local PROMPT_EVENT = U.u32(joaat('EVENT_PLAYER_PROMPT_TRIGGERED'))
local PROMPT_HORSE_INFO = 35
local EVENT_SIZE = 10          -- EVENT_PLAYER_PROMPT_TRIGGERED: 10 fields of 8 bytes
local TOGGLE_GAP = 400         -- ms: the event and the key path fire on the same press

-- natives with no sure RedM name, by hash
local function launchApp() return Inv(0xC1BCF31E975B3195, APP, APP_ENTRY, Citizen.ResultAsInteger()) end   -- LAUNCH_UIAPP_BY_HASH_WITH_ENTRY
local function closeApp() Inv(0x2FF10C9C3F92277E, APP) end                                                 -- _CLOSE_UIAPP_BY_HASH
local function shortDesc(ped) return Inv(0x6C5E5D48E48B4C65, ped, Citizen.ResultAsInteger()) end          -- COMPENDIUM_GET_SHORT_DESCRIPTION_FROM_PED
local function maxRank(ped, a) return Inv(0x704674A0535A471D, ped, a, Citizen.ResultAsInteger()) end      -- GET_MAX_ATTRIBUTE_RANK
local function staminaNorm(ped) return Inv(0x22F2A386D43048A9, ped, Citizen.ResultAsFloat()) end          -- _GET_PED_STAMINA_NORMALIZED
local function dbContainer(parent, name) return Inv(0xEB4F9A3537EEABCD, parent, name, Citizen.ResultAsInteger()) end      -- _DATABINDING_ADD_DATA_CONTAINER
local function dbInt(parent, name, v) return Inv(0x307A3247C5457BDE, parent, name, math.floor(v), Citizen.ResultAsInteger()) end -- _DATABINDING_ADD_DATA_INT
local function dbFloat(parent, name, v) return Inv(0x5154228273ADB9A6, parent, name, v + 0.0, Citizen.ResultAsInteger()) end   -- _DATABINDING_ADD_DATA_FLOAT

local function on(v) return v == true or v == 1 end

local function keep(entry)
    if entry and entry ~= 0 then Info.entries[#Info.entries + 1] = entry end
    return entry
end

------------------------------------------------------------------------------
-- what the card shows
------------------------------------------------------------------------------
local byModel = nil
local function breedOf(ped)
    if not byModel then
        byModel = {}
        for name, ref in pairs(Config.BreedByModel) do byModel[U.u32(joaat(name))] = ref end
    end
    local ref = byModel[U.u32(GetEntityModel(ped))]
    local b = ref and Config.BreedById[ref.breed]
    if not b then return L('infoHorse'), '' end
    local coat = b.coats[ref.coat]
    return b.label, coat and coat.label or ''
end

local function rank10(v) return U.clamp(U.int(v, 0), 0, 10) end

-- rough grade for horses this resource does not know: the agility rank (0..10) mapped to 1..4
local function gradeFromRank(r)
    if r >= 9 then return 4 elseif r >= 6 then return 3 elseif r >= 3 then return 2 end
    return 1
end

local function readStats(ped)
    local st = Entity(ped).state
    local s = st.pup_stable_horseID and st.pup_stable_horse_stats
    local A, c = N.ATTR, Config.Training.ceilings
    local o = {}
    if type(s) == 'table' then
        o.speed, o.speedCap = rank10(s.speed), rank10(c.speed)
        o.acc, o.accCap = rank10(s.acceleration), rank10(c.acceleration)
        o.handling = U.clamp(U.int(s.handling, 1), 1, 4)
        o.bond = U.bondLevel(U.int(s.bonding, 0))
        o.healthRank, o.staminaRank = U.rankFromPoints(s.health), U.rankFromPoints(s.stamina)
    else
        o.speed, o.speedCap = rank10(N.rank(ped, A.speed)), rank10(maxRank(ped, A.speed))
        o.acc, o.accCap = rank10(N.rank(ped, A.acceleration)), rank10(maxRank(ped, A.acceleration))
        o.handling = gradeFromRank(rank10(N.rank(ped, A.handling)))
        o.bond = U.clamp(U.int(N.rank(ped, A.bonding), 0), 0, 4)
        o.healthRank, o.staminaRank = rank10(N.rank(ped, A.health)), rank10(N.rank(ped, A.stamina))
    end
    if o.speedCap < o.speed then o.speedCap = o.speed end
    if o.accCap < o.acc then o.accCap = o.acc end
    local hp, maxHp = GetEntityHealth(ped) or 0, GetEntityMaxHealth(ped) or 0
    o.healthNorm = maxHp > 0 and U.clamp(hp / maxHp, 0.0, 1.0) or 0.0
    o.staminaNorm = U.clamp(staminaNorm(ped) or 0.0, 0.0, 1.0)
    o.healthCore = U.clamp(U.int(N.core(ped, 0), 0), 0, 100)
    o.staminaCore = U.clamp(U.int(N.core(ped, 1), 0), 0, 100)
    return o
end

local function isActiveHorse(ped)
    local cur = Horse.curPed()
    if cur == ped then return true end
    return GetMount(PlayerPedId()) == ped and Entity(ped).state.pup_stable_horseOwner == GetPlayerServerId(PlayerId())
end

local function fill(ped)
    local o = readStats(ped)
    local breed, coat = breedOf(ped)
    local root = keep(DatabindingAddDataContainerFromPath('', 'InfoBox'))
    keep(DatabindingAddDataBool(root, 'isVisible', true))
    keep(DatabindingAddDataBool(root, 'showHorseStats', true))
    keep(DatabindingAddDataString(root, 'itemLabel', L('infoTitle')))
    keep(DatabindingAddDataHash(root, 'itemDescription', shortDesc(ped) or 0))
    keep(DatabindingAddDataString(root, 'horseName', breed))
    -- the card looks HorseCoat and HorseHandling up as game text keys (plain text shows blank),
    -- so our own words are registered under keys of our own first
    AddTextEntry('PUPSTB_INFO_COAT', tostring(coat or ''))
    AddTextEntry('PUPSTB_INFO_HANDLING', tostring(Locale.handlingGrades[o.handling] or ''))
    keep(DatabindingAddDataString(root, 'HorseCoat', 'PUPSTB_INFO_COAT'))
    keep(dbInt(root, 'HorseSpeedValue', o.speed))
    keep(dbInt(root, 'HorseSpeedMinValue', 0))
    keep(dbInt(root, 'HorseSpeedMaxValue', 10))
    keep(dbInt(root, 'HorseSpeedCapacityValue', o.speedCap))
    keep(dbInt(root, 'HorseSpeedCapacityMinValue', 0))
    keep(dbInt(root, 'HorseSpeedCapacityMaxValue', 10))
    keep(dbInt(root, 'HorseAccValue', o.acc))
    keep(dbInt(root, 'HorseAccMinValue', 0))
    keep(dbInt(root, 'HorseAccMaxValue', 10))
    keep(dbInt(root, 'HorseAccCapacityValue', o.accCap))
    keep(dbInt(root, 'HorseAccCapacityMinValue', 0))
    keep(dbInt(root, 'HorseAccCapacityMaxValue', 10))
    keep(DatabindingAddDataString(root, 'HorseHandling', 'PUPSTB_INFO_HANDLING'))
    keep(DatabindingAddDataHash(root, 'itemTipText', 0))

    local rpg = keep(dbContainer(root, 'horseRpgStats'))
    local function ring(name, coreName, rank, norm, coreValue)
        local c = keep(dbContainer(rpg, name))
        keep(dbInt(c, 'unlockedMaxAsState', rank))
        keep(dbFloat(c, 'normalizedValue', norm))
        keep(dbFloat(c, 'normalizedUnlockedMax', rank / 10))
        local core = keep(dbContainer(c, coreName))
        local status = keep(dbContainer(core, 'status'))
        keep(dbInt(status, 'state', coreValue))
    end
    ring('stamina', 'staminaCore', o.staminaRank, o.staminaNorm, o.staminaCore)
    ring('health', 'healthCore', o.healthRank, o.healthNorm, o.healthCore)
    local bonding = keep(dbContainer(rpg, 'bonding'))
    local tex = (isActiveHorse(ped) and 'BLIP_HORSE_OWNED_BONDING_' or 'BLIP_HORSE_TEMP_BONDING_') .. U.clamp(o.bond, 0, 4)
    keep(DatabindingAddDataHash(bonding, 'bondingRankTexture', joaat(tex)))
end

------------------------------------------------------------------------------
-- the trainers' extra: one training tip on their own horse
------------------------------------------------------------------------------
local function trainerTip(ped)
    local st = Entity(ped).state
    if st.pup_stable_horseOwner ~= GetPlayerServerId(PlayerId()) then return end
    local isTrainer = false
    for _, j in ipairs(Config.TrainerJobs) do if Me.job == j then isTrainer = true end end
    if not isTrainer then return end
    local s = st.pup_stable_horse_stats or {}
    local c = Config.Training.ceilings
    local function fmt(v, max) v = U.int(v, 1) if v >= max then return L('maxed') end return ('%d/%d'):format(v, max) end
    Tip(L('trainingTip', fmt(s.speed, c.speed), fmt(s.acceleration, c.acceleration), Locale.handlingGrades[U.clamp(U.int(s.handling, 1), 1, 4)],
        U.bondLevel(U.int(s.bonding, 0)), N.core(ped, 1) or 0), 6000)
end

------------------------------------------------------------------------------
-- open / close / toggle
------------------------------------------------------------------------------
function Info.close()
    if not Info.horse and #Info.entries == 0 then return end
    local wasOpen = Info.horse ~= nil
    Info.horse = nil
    Info.token = Info.token + 1
    closeApp()
    DisableHudContext(HUD_CTX)
    for i = #Info.entries, 1, -1 do
        local e = Info.entries[i]
        if on(DatabindingIsEntryValid(e)) then DatabindingRemoveDataEntry(e) end
    end
    Info.entries = {}
    if wasOpen then pcall(PlaySoundFrontend, 'hide_info', 'Study_Sounds', true, 0) end
end

function Info.open(ped)
    Info.close()
    local ok, err = pcall(fill, ped)
    if not ok then
        Debug('info card failed', err)
        return Info.close()
    end
    launchApp()
    EnableHudContext(HUD_CTX)
    pcall(PlaySoundFrontend, 'show_info', 'Study_Sounds', true, 0)
    Info.horse = ped
    local token = Info.token
    trainerTip(ped)
    -- shut when the player stops looking at this horse
    CreateThread(function()
        Wait(500)
        local misses = 0
        while Info.horse == ped and Info.token == token do
            if not DoesEntityExist(ped) or IsEntityDead(PlayerPedId()) then break end
            if N.targetEntity() == ped then misses = 0 else misses = misses + 1 end
            if misses >= 2 then break end
            Wait(250)
        end
        if Info.token == token then Info.close() end
    end)
end

-- both the game event and the key call this on the same press: the gap keeps it to one toggle
function Info.toggle(ped)
    local now = GetGameTimer()
    if now - Info.lastToggle < TOGGLE_GAP then return end
    Info.lastToggle = now
    if Info.horse then return Info.close() end
    if not ped or ped == 0 or not DoesEntityExist(ped) or not IsEntityAPed(ped) then return end
    if not Config.Horse.statsPrompt then return Tip(L('infoOff')) end
    if Typing() or (Ui and Ui.open) then return end
    Info.open(ped)
end

------------------------------------------------------------------------------
-- the game's horse "Info" prompt: EVENT_PLAYER_PROMPT_TRIGGERED, prompt type 35
------------------------------------------------------------------------------
local function promptData(index)
    local buf = string.rep('\0', 8 * EVENT_SIZE)
    Inv(0x57EC5FA4D4D6AFCA, 0, index, buf, EVENT_SIZE)                          -- GET_EVENT_DATA (a miss leaves zeros)
    return string.unpack('<i4', buf, 1), string.unpack('<i4', buf, 17)         -- [0] prompt type, [2] target entity
end

CreateThread(function()
    while true do
        Wait(0)
        local count = GetNumberOfEvents(0)
        for i = 0, count - 1 do
            if U.u32(GetEventAtIndex(0, i)) == PROMPT_EVENT then
                local kind, target = promptData(i)
                if kind == PROMPT_HORSE_INFO then Info.toggle(target) end
            end
        end
    end
end)

AddEventHandler('pup-stable:closeAll', function() Info.close() end)

AddEventHandler('onResourceStop', function(res)
    if res == RES then Info.close() end
end)
