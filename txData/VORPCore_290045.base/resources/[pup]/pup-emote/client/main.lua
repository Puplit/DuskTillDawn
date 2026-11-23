local OWNER <const> = 'pup-emote:manage'
local L <const> = Locale
local SETS <const> = Config.Wheel.sets or 4
local SLOTS <const> = Config.Wheel.slots or 4

local sets = {}        -- [set][slot] = { cmd = 'hat_tip' (an emote id), mode = 'upper'|'full' } or false
local liveSet = 1

local menuLevel = nil  -- 'sets' | 'slots' | 'pick' (categories) | 'cat' (emotes) | 'mode'
local pickingSet, pickingSlot, pickingCat, pendingCmd = nil, nil, nil, nil

local quick, quickGroup = {}, nil

local function miscReady() return GetResourceState('pup-misc') == 'started' end

local function labelOf(id)
    local e = EmoteList.byId[id]
    return e and e.label or tostring(id)
end

local function blank()
    local out = {}
    for s = 1, SETS do
        out[s] = {}
        for i = 1, SLOTS do out[s][i] = false end
    end
    return out
end
sets = blank()

local function slotAt(set, i)
    local row = sets[set] and sets[set][i]
    return (type(row) == 'table' and type(row.cmd) == 'string' and row.cmd ~= '') and row or nil
end

local function play(set, i)
    local row = slotAt(set, i)
    if not row then return end
    if not miscReady() then
        return TriggerEvent('vorp:TipRight', L.noEmotes, 5000)
    end
    local e = EmoteList.byId[row.cmd]
    if not e then return end
    -- a missing export fails silently, which reads as a dead keypress
    local ok, err = pcall(function()
        local misc = exports['pup-misc']
        if e.kind == 'kit' then return misc:PlayKitEmote(e.play, e.mode or row.mode) end
        if e.kind == 'scenario' then return misc:PlayScenario(e.play) end
        return misc:PlayAnim(e.play)
    end)
    if not ok then
        TriggerEvent('vorp:TipRight', L.playFailed, 6000)
        print(('^1[pup-emote]^7 %s (%s) failed: %s'):format(e.id, e.kind, tostring(err)))
    end
end

-- ------------------------------------------------------------------- the wheel

local openSets -- defined below; the wheel can jump straight into the set menu

local function openWheel()
    local items = {}
    for i = 1, SLOTS do
        local row = slotAt(liveSet, i)
        if row then items[#items + 1] = { name = tostring(i), label = labelOf(row.cmd) } end
    end
    -- always reachable, so an empty wheel is still a way in rather than a dead end
    items[#items + 1] = { name = 'sets', label = L.changeSet,
        desc = L.setLabel:format(liveSet) }
    exports['pup-ui']:OpenWheel({
        title = L.title,
        subtitle = L.setLabel:format(liveSet),
        items = items,
    })
end

-- the item name is the SLOT number, so two slots holding the same emote stay apart
AddEventHandler('pup-ui:client:wheelSelected', function(item)
    if item == 'sets' then
        -- the wheel closes itself on a pick; let it before the list opens
        return SetTimeout(100, function() openSets() end)
    end
    local i = tonumber(item)
    if i then play(liveSet, i) end
end)

-- ------------------------------------------------------------------ setting up

local openSlots, openPicker, openCategory, openMode

-- the tip comes back from the server once the row is actually written
local function save()
    TriggerServerEvent('pup-emote:server:save', sets, liveSet)
end

openSets = function()
    menuLevel = 'sets'
    local options = {}
    for s = 1, SETS do
        local filled = 0
        for i = 1, SLOTS do if slotAt(s, i) then filled = filled + 1 end end
        options[s] = {
            label = L.setLabel:format(s),
            desc = (s == liveSet) and L.setLive or ('%d/%d'):format(filled, SLOTS),
        }
    end
    exports['pup-ui']:OpenListMenu({
        owner = OWNER, title = L.manageTitle, subtitle = L.quickHint,
        options = options, keyboard = true,
    })
end

openSlots = function(set)
    menuLevel = 'slots'
    pickingSet = set
    local options = {}
    options[1] = { label = L.setPick, desc = (set == liveSet) and L.setLive or '' }
    for i = 1, SLOTS do
        local row = slotAt(set, i)
        local desc = L.empty
        if row then
            desc = labelOf(row.cmd)
            if row.mode == 'upper' then desc = desc .. '  -  ' .. L.modeUpper end
        end
        options[i + 1] = { label = L.slot:format(i), desc = desc }
    end
    exports['pup-ui']:OpenListMenu({
        owner = OWNER, title = L.manageTitle, subtitle = L.setLabel:format(set),
        options = options, keyboard = true,
    })
end

-- step 1 of choosing: the categories, in config order
openPicker = function(set, slot)
    menuLevel = 'pick'
    pickingSet, pickingSlot, pickingCat = set, slot, nil
    local options = { { label = L.clearSlot, desc = '' } }
    for _, cat in ipairs(EmoteList.categories) do
        options[#options + 1] = { label = cat.name, desc = L.emoteCount:format(#cat.ids) }
    end
    exports['pup-ui']:OpenListMenu({
        owner = OWNER, title = L.manageTitle, subtitle = L.pickFor:format(set, slot),
        options = options, keyboard = true,
    })
end

-- step 2: the emotes in one category, in config order
openCategory = function(ci)
    local cat = EmoteList.categories[ci]
    if not cat then return openPicker(pickingSet, pickingSlot) end
    menuLevel = 'cat'
    pickingCat = ci
    local options = {}
    for i, id in ipairs(cat.ids) do
        local e = EmoteList.byId[id]
        options[i] = { label = e.label, desc = (e.kind ~= 'kit') and L.modeFull or '' }
    end
    exports['pup-ui']:OpenListMenu({
        owner = OWNER, title = L.manageTitle, subtitle = cat.name,
        options = options, keyboard = true,
    })
end

local function assign(id, mode)
    sets[pickingSet][pickingSlot] = { cmd = id, mode = (mode == 'upper') and 'upper' or 'full' }
    pendingCmd = nil
    play(pickingSet, pickingSlot)
    save()
    return openSlots(pickingSet)
end

-- step 3, kit emotes only, unless the config fixes the mode
openMode = function(id)
    menuLevel = 'mode'
    pendingCmd = id
    exports['pup-ui']:OpenListMenu({
        owner = OWNER, title = L.manageTitle, subtitle = L.pickMode:format(labelOf(id)),
        keyboard = true,
        options = {
            { label = L.modeUpper, desc = L.modeUpper2 },
            { label = L.modeFull,  desc = L.modeFull2 },
        },
    })
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= OWNER then return end

    if menuLevel == 'sets' then
        return openSlots(index)

    elseif menuLevel == 'slots' then
        if index == 1 then
            liveSet = pickingSet
            save()
            if quickGroup then quickGroup = nil end
            return openSets()
        end
        return openPicker(pickingSet, index - 1)

    elseif menuLevel == 'pick' then
        if index == 1 then
            sets[pickingSet][pickingSlot] = false
            save()
            return openSlots(pickingSet)
        end
        return openCategory(index - 1)

    elseif menuLevel == 'cat' then
        local cat = EmoteList.categories[pickingCat]
        local id = cat and cat.ids[index]
        local e = id and EmoteList.byId[id]
        if not e then return end
        if e.mode then return assign(id, e.mode) end
        return openMode(id)

    elseif menuLevel == 'mode' then
        if not pendingCmd then return end
        return assign(pendingCmd, (index == 1) and 'upper' or 'full')
    end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= OWNER then return end
    if menuLevel == 'mode' then return openCategory(pickingCat) end
    if menuLevel == 'cat' then return openPicker(pickingSet, pickingSlot) end
    if menuLevel == 'pick' then return openSlots(pickingSet) end
    if menuLevel == 'slots' then return openSets() end
    menuLevel = nil
    exports['pup-ui']:HideListMenu()
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= nil and owner ~= OWNER then return end
    menuLevel, pickingSet, pickingSlot, pickingCat, pendingCmd = nil, nil, nil, nil, nil
end)

-- --------------------------------------------------- quick slots while focused

local function clearQuick()
    for i, p in pairs(quick) do
        if p then PromptDelete(p) end
        quick[i] = nil
    end
    quickGroup = nil
end

-- natives answer true/false or 1/0 depending on the build, and 0 is truthy in Lua
local function yes(v) return v == true or v == 1 end

--- Players and NPCs get the quick slots; animals (horses included) never do.
local function isPerson(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 1 then return false end
    if yes(IsPedAPlayer(entity)) then return true end
    return not yes(Citizen.InvokeNative(0x9A100F1CF4546629, entity)) -- GET_IS_ANIMAL
end

local function buildQuick(group)
    clearQuick()
    quickGroup = group
    for i = 1, SLOTS do
        local row = slotAt(liveSet, i)
        local key = Config.Keys.quickSlots and Config.Keys.quickSlots[i]
        if row and key then
            local p = PromptRegisterBegin()
            PromptSetControlAction(p, key)
            PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', labelOf(row.cmd)))
            PromptSetEnabled(p, 1)
            PromptSetVisible(p, 1)
            PromptSetStandardMode(p, 1)
            PromptSetGroup(p, group)
            PromptRegisterEnd(p)
            quick[i] = p
        end
    end
end

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('pup-emote:server:get')

    local openKey <const> = Config.Keys.openWheel
    while true do
        local ped <const> = PlayerPedId()
        local okT, targeting = pcall(function()
            return Citizen.InvokeNative(0x4605C66E0F935F83, PlayerId())
        end)
        -- the native answers with a number on some builds, and 0 is truthy in Lua
        targeting = okT and (targeting == true or targeting == 1)

        if targeting and not IsPedInMeleeCombat(ped) then
            local _, entity = GetPlayerTargetEntity(PlayerId())
            -- prompts hang off the TARGET's own group, so they read on them
            local group = isPerson(entity) and Citizen.InvokeNative(0xB796970BD125FCE8, entity) or nil
            if group then
                if quickGroup ~= group then buildQuick(group) end
                for i, p in pairs(quick) do
                    if p and PromptHasStandardModeCompleted(p) then play(liveSet, i) end
                end
            elseif quickGroup then
                clearQuick()
            end
        elseif quickGroup then
            clearQuick()
        end

        -- only polled when the owner has pinned the wheel to a fixed key
        if openKey then
            local busy = false
            pcall(function() busy = exports['pup-ui']:IsPanelOpen() end)
            if not busy and not IsPauseMenuActive() and IsControlJustPressed(0, openKey) then
                openWheel()
            end
        end
        Wait(0)
    end
end)

-- --------------------------------------------------------------------- wiring

RegisterNetEvent('pup-emote:client:wheel', function(stored, live)
    -- never overwrite what is being edited right now
    if menuLevel then return end
    sets = blank()
    if type(stored) == 'table' then
        for s = 1, SETS do
            local row = stored[s]
            if type(row) == 'table' then
                for i = 1, SLOTS do
                    local v = row[i]
                    -- find() also reads wheels saved under upper-case labels
                    local e = type(v) == 'table' and EmoteList.find(v.cmd) or nil
                    if e then
                        sets[s][i] = { cmd = e.id, mode = (v.mode == 'upper') and 'upper' or 'full' }
                    end
                end
            end
        end
    end
    liveSet = tonumber(live) or 1
    if liveSet < 1 or liveSet > SETS then liveSet = 1 end
    if quickGroup then clearQuick() end
end)

-- the startup request can land before a character exists, so ask again on every pick
RegisterNetEvent('vorp:SelectedCharacter', function()
    SetTimeout(2500, function() TriggerServerEvent('pup-emote:server:get') end)
end)

RegisterNetEvent('pup-emote:client:saved', function()
    TriggerEvent('vorp:TipRight', L.saved, 3000)
end)

-- the one typed command, and it is only for changing the sets
RegisterCommand(Config.General.command or 'emotes', function()
    openSets()
end, false)

-- no default key: each player binds the wheel in Settings > Key Bindings
RegisterCommand('pupemotewheel', function()
    local busy = false
    pcall(function() busy = exports['pup-ui']:IsPanelOpen() end)
    if busy or IsPauseMenuActive() then return end
    openWheel()
end, false)
RegisterKeyMapping('pupemotewheel', Locale.wheelLabel or 'Emote wheel', 'keyboard', '')

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearQuick() end
end)
