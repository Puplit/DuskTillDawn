-- pup_robbery | client core: callbacks, messages, drawing, prompts, minigames, animations, blips

C = {}

local core = nil
function C.core()
    if core then return core end
    local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and c then core = c end
    return core
end

function C.cb(name, ...)
    local c = C.core()
    if not c then return nil end
    local ok, r = pcall(c.Callback.TriggerAwait, name, ...)
    if ok then return r end
    return nil
end

-- a callback that gives up after `ms`; returns the answer or nil
function C.cbWithin(ms, name, ...)
    local c = C.core()
    if not c then return nil end
    local done, answer = false, nil
    local ok = pcall(c.Callback.TriggerAsync, name, function(r)
        answer = r
        done = true
    end, ...)
    if not ok then return nil end
    local limit = GetGameTimer() + ms
    while not done and GetGameTimer() < limit do Wait(50) end
    return answer
end

function C.tip(text, ms)
    TriggerEvent('vorp:TipRight', tostring(text), ms or 4000)
end

local toastWarned = false
function C.toast(text)
    local ok = pcall(function() exports['pup-ui']:Toast(tostring(text)) end)
    if not ok then
        if not toastWarned then
            toastWarned = true
            print('[pup_robbery] pup-ui toasts unavailable - using the right-side tip')
        end
        C.tip(text)
    end
end

RegisterNetEvent('pup_robbery:toast', function(text) C.toast(text) end)

function C.me() return PlayerPedId() end
function C.myPos() return GetEntityCoords(PlayerPedId()) end
function C.dead() return IsEntityDead(PlayerPedId()) or IsPedDeadOrDying(PlayerPedId(), true) end

--------------------------------------------------------------------------------
-- text

local function varString(text)
    return CreateVarString(10, 'LITERAL_STRING', tostring(text))
end

-- 2D line; x/y are screen fractions
function C.text2D(text, x, y, scale, r, g, b)
    SetTextScale(scale or 0.4, scale or 0.4)
    SetTextColor(r or 255, g or 255, b or 255, 230)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(varString(text), x, y)
end

-- 3D label with a dark box behind it
function C.text3D(pos, text, r, g, b)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z)
    if not onScreen then return end
    local spr = Config.LabelSprite
    if not HasStreamedTextureDictLoaded(spr.dict) then RequestStreamedTextureDict(spr.dict, false) end
    local len = string.len(tostring(text))
    DrawSprite(spr.dict, spr.name, x, y + 0.0125, 0.012 + len * 0.0052, 0.032, 0.0, 10, 10, 10, 190, false)
    SetTextScale(0.32, 0.32)
    SetTextColor(r or 255, g or 255, b or 255, 235)
    SetTextCentre(true)
    DisplayText(varString(text), x, y)
end

--------------------------------------------------------------------------------
-- a single-key prompt group

function C.makePrompt(groupLabel, text, key)
    local group = GetRandomIntInRange(0, 0xffffff)
    local p = UiPromptRegisterBegin()
    UiPromptSetControlAction(p, key or Config.InteractKey)
    UiPromptSetText(p, varString(text))
    UiPromptSetEnabled(p, true)
    UiPromptSetVisible(p, true)
    UiPromptSetStandardMode(p, true)
    UiPromptSetGroup(p, group, 0)
    UiPromptRegisterEnd(p)
    return { id = p, group = group, label = groupLabel }
end

function C.showPrompt(prompt, label)
    UiPromptSetActiveGroupThisFrame(prompt.group, varString(label or prompt.label), 0, 0, 0, 0)
end

function C.promptPressed(prompt)
    local r = Citizen.InvokeNative(0xC92AC953F0A982AE, prompt.id) -- UiPromptHasStandardModeCompleted
    return r == true or r == 1
end

function C.dropPrompt(prompt)
    if prompt and prompt.id then Citizen.InvokeNative(0x00EDE88D4D13CF59, prompt.id) end -- UiPromptDelete
end

function C.pressed()
    return IsControlJustReleased(0, Config.InteractKey)
end

--------------------------------------------------------------------------------
-- models and animations

function C.loadModel(model, timeoutMs)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil end
        Wait(25)
    end
    return hash
end

function C.loadDict(dict, timeoutMs)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + (timeoutMs or Config.Heist.animLoadMs)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(25)
    end
    return true
end

-- one animation, or a list tried in order; returns the one that played
function C.playAnim(spec, loop)
    if not spec then return nil end
    local list = spec.dict and { spec } or spec
    for _, a in ipairs(list) do
        if C.loadDict(a.dict) then
            TaskPlayAnim(PlayerPedId(), a.dict, a.name, 8.0, -8.0, -1, loop == false and 0 or 1, 0.0, false, 0, false, '', false)
            return a
        end
    end
    return nil
end

function C.stopAnim()
    ClearPedTasks(PlayerPedId(), true, false)
end

--------------------------------------------------------------------------------
-- minigames (pup-minigames, plus the standalone lockpick resource)

local lockpickWarned = false

-- blocking: returns true or false. `opts` overrides the configured tuning.
function C.minigame(game, base, opts, tipText)
    local params = {}
    for k, v in pairs(base or {}) do params[k] = v end
    for k, v in pairs(opts or {}) do params[k] = v end
    if tipText then C.tip(tipText, 6000) end

    if game == 'lockpick' then
        if GetResourceState('lockpick') == 'started' then
            local ok, r = pcall(function() return exports.lockpick:lockpick() end)
            return ok and r == true
        end
        game = 'safe_crack' -- lockpick not running; pup-minigames stands in
    end

    local done, result = false, false
    local fn = ({
        normal = 'skill_bar', skill_bar = 'skill_bar', skill_circle = 'skill_circle', safe = 'safe_crack',
        safe_crack = 'safe_crack', wire_cut = 'wire_cut', button_mash = 'button_mash', pincode = 'pincode',
        chip_hack = 'chip_hack', key_drop = 'key_drop', anagram = 'anagram', hangman = 'hangman',
    })[game] or 'skill_bar'
    local ok = pcall(function()
        exports['pup-minigames'][fn](exports['pup-minigames'], params, function(r)
            result = (r == true or r == 'perfect' or r == 'success')
            done = true
        end)
    end)
    if not ok then return false end
    local limit = GetGameTimer() + (Config.Minigames.timeoutMs or 240000)
    while not done do
        if GetGameTimer() > limit then
            SetNuiFocus(false, false)
            return false
        end
        Wait(100)
    end
    return result
end

-- the walk-up box games (tuning in Config.Minigames.walkup)
function C.boxGame(game, dials)
    local tune = Config.Minigames.walkup
    local tip = Locale.tips[game] or Locale.tips.normal
    if game == 'safe' then
        local diff = U.clamp((tonumber(dials) or 1) + 1, 1, 5)
        return C.minigame('safe', { style = 'default' }, { difficulty = diff }, tip)
    elseif game == 'lockpick' then
        local r = C.minigame('lockpick', nil, nil, Locale.tips.lockpick)
        if r ~= nil then return r end
        if not lockpickWarned then
            lockpickWarned = true
            print('[pup_robbery] the lockpick resource is not started - using the wire cut instead')
        end
        return C.minigame('wire_cut', tune.wire_cut, nil, Locale.tips.wire_cut)
    end
    local base = tune[game] or tune.normal
    if not tune[game] then game = 'normal' end
    return C.minigame(game, base, nil, tip)
end

-- the heist games (tuning in Config.Minigames.heist); opts come from the server (pincode)
function C.heistGame(game, opts)
    local tune = Config.Minigames.heist
    local tip = Locale.tips[game]
    if game == 'lockpick' then
        local r = C.minigame('lockpick', nil, nil, Locale.tips.lockpick)
        if r == nil then
            C.tip(Locale.lockpickMissing)
            return false
        end
        return r
    elseif game == 'wire_cut' then
        C.tip(Locale.tips.wire_cut, 6000)
        Wait(Config.Minigames.wirePauseMs or 700)
        return C.minigame('wire_cut', tune.wire_cut, nil, nil)
    elseif game == 'pincode' then
        return C.minigame('pincode', { style = 'default' }, opts, tip)
    end
    local base = tune[game]
    if not base then
        game = 'skill_bar'
        base = tune.skill_bar
    end
    return C.minigame(game, base, opts, tip)
end

--------------------------------------------------------------------------------
-- blips

function C.blipAt(pos, sprite, scale, name)
    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, pos.x, pos.y, pos.z)
    if not b or b == 0 then return nil end
    SetBlipSprite(b, sprite, true)
    SetBlipScale(b, scale or 0.8)
    if name then Citizen.InvokeNative(0x9CB1A1623062F402, b, tostring(name)) end
    return b
end

function C.blipModifier(b, modifier)
    if b then Citizen.InvokeNative(0x662D364ABF16DE2F, b, modifier) end
end

function C.blipEntity(ent, style)
    local b = Citizen.InvokeNative(0x23F74C2FDA6E7C61, style or Config.GuardBlipStyle, ent)
    return b
end

function C.removeBlip(b)
    if b and DoesBlipExist(b) then RemoveBlip(b) end
end

--------------------------------------------------------------------------------
-- line of sight (cached per target)

local losCache = {}
function C.clearSight(key, target)
    local now = GetGameTimer()
    local c = losCache[key]
    if c and now - c.at < Config.Heist.losCacheMs then return c.clear end
    local cam = GetGameplayCamCoord()
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, target.x, target.y, target.z, 1 + 16, PlayerPedId(), 7)
    local _, hit, endPos = GetShapeTestResult(ray)
    local clear = hit == 0 or hit == false or #(vector3(endPos.x, endPos.y, endPos.z) - vector3(target.x, target.y, target.z)) <= Config.Heist.losTolerance
    losCache[key] = { at = now, clear = clear }
    return clear
end

function C.v3(t)
    if not t then return nil end
    return vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0)
end
