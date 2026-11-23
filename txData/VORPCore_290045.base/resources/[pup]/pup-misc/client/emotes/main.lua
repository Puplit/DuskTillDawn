-- pup-misc / emotes Chat commands for emotes, animations, scenarios and walk styles

local playing = false

local function ped() return PlayerPedId() end

local function stopAll()
    local p = ped()
    ClearPedSecondaryTask(p)
    ClearPedTasks(p)
    playing = false
end

-- eating, drinking, smoking and every gesture or upper-body emote share the secondary task slot,
-- so nothing may start while a consume runs (it would cancel the consume but keep its effect)
-- smokes/ sets proppromptdisplayed; it loads after this file, so nil means "not smoking"
local function consuming()
    if proppromptdisplayed == true then return true end
    local ok, done = pcall(function() return exports.fred_metabolism:isAnimDone() end)
    return ok and done == false
end

-- blocked by knockout, ragdoll, hogtie, a consume in progress; allowMounted lets upper-body emotes ride
local function canPlay(allowMounted)
    local p = ped()
    if IsPedDeadOrDying(p, true) then return false end
    if consuming() then return false end
    local okTied, tied = pcall(function() return Citizen.InvokeNative(0x3AA24CCC0D451379, p) end)
    if okTied and tied then return false end
    local okRag, rag = pcall(function() return IsPedRagdoll(p) end)
    if okRag and rag then return false end
    if not allowMounted and (IsPedOnMount(p) or IsPedInAnyVehicle(p, false)) then return false end
    return true
end

local function isFemale(p)
    local ok, male = pcall(function() return IsPedMale(p) end)
    if ok then return male == false end
    return false
end

-- the class comes from the name; one class for all plays a greeting as a taunt
local function emoteCategory(kitHash)
    local n <const> = tostring(kitHash):lower()
    if n:find('reaction', 1, true) then return 0 end
    if n:find('action', 1, true) then return 1 end
    if n:find('taunt', 1, true) then return 2 end
    if n:find('greet', 1, true) then return 3 end
    if n:find('dance', 1, true) then return 5 end
    return 1
end

-- 'upper' plays on the top half so you keep moving; anything else plants you
local function playEmote(kitHash, mode)
    local upper <const> = (mode == 'upper')
    if not canPlay(upper) then return end
    local p = ped()
    if not upper then ClearPedTasks(p) end
    local cat <const> = emoteCategory(kitHash)
    pcall(function()
        if upper then
            Citizen.InvokeNative(0xB31A277C1AC7B7FF, p, cat, 0, GetHashKey(kitHash), 1, 1, 0, 0, 0)
        else
            Citizen.InvokeNative(0xB31A277C1AC7B7FF, p, cat, 2, GetHashKey(kitHash), 0, 0, 0, 0, 0)
        end
    end)
    playing = true
end

local function playScenario(scenarioHash)
    if not canPlay() then return end
    local p = ped()
    ClearPedTasksImmediately(p)
    TaskStartScenarioInPlace(p, GetHashKey(scenarioHash), -1)
    playing = true
end

local function playAnim(entry)
    if not canPlay() then return end
    local p = ped()
    local dict, name = entry.dict, entry.name
    if entry.fdict and isFemale(p) then
        dict, name = entry.fdict, entry.fname or entry.name
    end
    if not dict or not name then return end

    RequestAnimDict(dict)
    local tries = 0
    while not HasAnimDictLoaded(dict) and tries < 100 do
        tries = tries + 1
        Citizen.Wait(10)
    end
    if not HasAnimDictLoaded(dict) then
        print(('^3[pup-misc/emotes]^7 anim dict failed to load: %s'):format(dict))
        return
    end

    ClearPedTasks(p)
    TaskPlayAnim(p, dict, name, 1.0, -1.0, -1, entry.flag or 1, 0, false, false, false)
    RemoveAnimDict(dict)
    playing = true
end

-- shared across pup-misc, which runs one client Lua state
EmotesPlayAnim = playAnim
EmotesStopAll  = stopAll
EmotesCanPlay  = canPlay
EmotesConsuming = consuming

-- pup-emote's wheel picks from this and plays through PlayEmoteCommand
local function emoteList()
    local out = {}
    local function add(tbl, kind)
        for cmd in pairs(tbl or {}) do out[#out + 1] = { cmd = cmd, kind = kind } end
    end
    add(EmotesConfig.Emotes, 'emote')
    add(EmotesConfig.Scenarios, 'scenario')
    add(EmotesConfig.Anims, 'anim')
    table.sort(out, function(a, b) return a.cmd < b.cmd end)
    return out
end

exports('GetEmoteList', emoteList)

-- play a KIT_EMOTE_* hash directly, for callers that keep their own list
exports('PlayKitEmote', function(kitHash, mode)
    if type(kitHash) ~= 'string' or kitHash == '' then return false end
    playEmote(kitHash, mode)
    return true
end)

-- a scenario or animation straight from a caller's own list (pup-emote's wheel);
-- same safety checks as the commands. anim = { dict, name, flag?, fdict?, fname? }
exports('PlayScenario', function(scenarioHash)
    if type(scenarioHash) ~= 'string' or scenarioHash == '' then return false end
    playScenario(scenarioHash)
    return true
end)

exports('PlayAnim', function(anim)
    if type(anim) ~= 'table' or type(anim.dict) ~= 'string' or type(anim.name) ~= 'string' then return false end
    -- loads the dict with waits, so off the caller's thread
    CreateThread(function() playAnim(anim) end)
    return true
end)

-- mode is kit-emote only: a scenario or anim has no upper-body form
exports('PlayEmoteCommand', function(cmd, mode)
    if type(cmd) ~= 'string' or cmd == '' then return false end
    local kit = EmotesConfig.Emotes and EmotesConfig.Emotes[cmd]
    if kit then playEmote(kit, mode) return true end
    local sc = EmotesConfig.Scenarios and EmotesConfig.Scenarios[cmd]
    if sc then playScenario(sc) return true end
    local an = EmotesConfig.Anims and EmotesConfig.Anims[cmd]
    if an then playAnim(an) return true end
    return false
end)

exports('StopEmote', function() stopAll() end)

-- ------------------------------------------------------------------ commands
local registered = { walks = {}, emotes = {}, scenarios = {}, anims = {} }

-- WALK STYLES: hand off to vorp_walkanim so the style syncs and persists
for cmd, style in pairs(EmotesConfig.WalkStyles or {}) do
    registered.walks[#registered.walks + 1] = cmd
    RegisterCommand(cmd, function()
        if GetResourceState('vorp_walkanim') == 'started' then
            if style == 'noanim' then
                -- its own menu clears with the reset native, same path here
                Citizen.InvokeNative(0xA6F67BEC53379A32, ped(), 'MP_Style_Casual')
                TriggerServerEvent('vorp_walkanim:setwalk', 'noanim')
            else
                TriggerEvent('vorp_walkanim:Client:setAnim', style)
            end
        else
            if style == 'noanim' then
                Citizen.InvokeNative(0xA6F67BEC53379A32, ped(), 'MP_Style_Casual')
            else
                Citizen.InvokeNative(0xCB9401F918CB0F75, ped(), style, 1, -1)
            end
        end
    end, false)
end

for cmd, kit in pairs(EmotesConfig.Emotes or {}) do
    registered.emotes[#registered.emotes + 1] = cmd
    RegisterCommand(cmd, function() playEmote(kit) end, false)
end

for cmd, sc in pairs(EmotesConfig.Scenarios or {}) do
    registered.scenarios[#registered.scenarios + 1] = cmd
    RegisterCommand(cmd, function() playScenario(sc) end, false)
end

for cmd, entry in pairs(EmotesConfig.Anims or {}) do
    registered.anims[#registered.anims + 1] = cmd
    RegisterCommand(cmd, function() playAnim(entry) end, false)
end

RegisterCommand(EmotesConfig.General.stopCommand or 'sa', function()
    -- vorp_core registers /sa too and guards it against hogtie
    if PupBlockIfRestrained and PupBlockIfRestrained(EmotesLocale.restrained) then return end
    -- pup_hideouts sets this while the wagon charge or robbery bar runs
    if LocalPlayer.state.undergroundBusy then
        TriggerEvent('vorp:TipRight', EmotesLocale.busy, 4000)
        return
    end
    stopAll()
    TriggerEvent('pup-misc:stopAnim')   -- piggyback drops the pair on this
end, false)

-- a player who ragdolls, gets hogtied or dies mid-emote should not snap back into it
CreateThread(function()
    while true do
        Citizen.Wait(500)
        if playing then
            local p = ped()
            if IsPedDeadOrDying(p, true) or IsPedOnMount(p) or IsPedInAnyVehicle(p, false) then
                playing = false
            end
        end
    end
end)

-- /emotelist prints everything to F8, grouped - handy while building menus
RegisterCommand(EmotesConfig.General.listCommand or 'emotelist', function()
    local function dump(title, list)
        table.sort(list)
        print(('^3[pup-misc/emotes]^7 %s (%d): %s'):format(title, #list, table.concat(list, ', ')))
    end
    dump('walk styles', registered.walks)
    dump('emotes', registered.emotes)
    dump('scenarios', registered.scenarios)
    dump('animations', registered.anims)

    -- vorp_walkanim's own commands: not ours to register, but listed so they are findable
    if GetResourceState('vorp_walkanim') == 'started' then
        local extra = {}
        for _, c in ipairs(EmotesConfig.Integrations.walkanimCommands or { 'walkanim', 'walkSlow' }) do
            extra[#extra + 1] = c
        end
        print(('^3[pup-misc/emotes]^7 walk menu (vorp_walkanim) (%d): %s')
            :format(#extra, table.concat(extra, ', ')))
    end

    print(('^3[pup-misc/emotes]^7 stop with /%s'):format(EmotesConfig.General.stopCommand or 'sa'))
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if playing then stopAll() end
end)
