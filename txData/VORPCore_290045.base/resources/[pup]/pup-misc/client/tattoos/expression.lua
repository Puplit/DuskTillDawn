-- pup-misc / tattoos - MetaPed expressions (body and face shape) on the player

local expressionValues = nil
local expressionOriginalSnapshot = {}
local expressionDirty = false
local expressionsLoaded = false
local expressionsRequested = false
local expressionPurchasePending = false
local valueRange = { min = -1.0, max = 1.0, step = 0.05 }

-- Helper for debug prints based on TattooConfig.General.debug
local function DebugPrint(msg)
    if TattooConfig.General.debug then
        print("^4[DEBUG-EXPRESSIONS]^7 " .. msg)
    end
end

-- MetaPed expression presets grouped into simple categories.
local expressionCategories = {
    {
        id = "body",
        label = "Body & Proportions",
        options = {
            { index = 15833, label = "Shoulder Height" },
            { index = 41478, label = "Back Width / Chest Size" },
            { index = 18046, label = "Shoulder Blades / Back Muscles" },
            { index = 46032, label = "Arms Size" },
            { index = 8420, label = "Forearms" },
            { index = 27779, label = "Chest" },
            { index = 50460, label = "Waist Width" },
            { index = 49787, label = "Hip Width / Stomach Size" },
            { index = 64834, label = "Thighs" },
            { index = 42067, label = "Calves" },
            { index = 50039, label = "Shoulders" },
            { index = 7010, label = "Shoulder Thickness" },
            { index = 46240, label = "Chest Height", sex = "female" },
            { index = 8991, label = "Butt / Hip Size", sex = "female" },
        }
    },
    {
        id = "head",
        label = "Head Shape",
        options = {
            { index = 34006, label = "Head Width" },
            { index = 41396, label = "Face Width" },
            { index = 27147, label = "Cheekbones Height" },
            { index = 43983, label = "Cheekbones Width" },
            { index = 13709, label = "Cheekbones Depth" },
            { index = 36106, label = "Jaw Height" },
            { index = 60334, label = "Jaw Width" },
            { index = 7670, label = "Jaw Depth" },
            { index = 15375, label = "Chin Height" },
            { index = 50098, label = "Chin Width" },
            { index = 58147, label = "Chin Depth" },
            { index = 55182, label = "Jaw Y Position" },
        }
    },
    {
        id = "ears",
        label = "Ears",
        options = {
            { index = 49231, label = "Ears Depth" },
            { index = 46798, label = "Ears Angle" },
            { index = 10308, label = "Ears Height" },
            { index = 60720, label = "Earlobes" },
        }
    },
    {
        id = "brows_eyes",
        label = "Brows & Eyes",
        options = {
            { index = 13059, label = "Eyebrow Height" },
            { index = 12281, label = "Eyebrow Width" },
            { index = 19153, label = "Eyebrow Depth" },
            { index = 35627, label = "Eyelid Height" },
            { index = 7019, label = "Eyelid Width" },
            { index = 60996, label = "Eyes Depth" },
            { index = 53862, label = "Eyes Angle" },
            { index = 42318, label = "Eyes Distance" },
            { index = 56827, label = "Eyes Height" },
            { index = 22421, label = "Right Eyelid Open / Close" },
            { index = 52902, label = "Left Eyelid Open / Close" },
        }
    },
    {
        id = "nose",
        label = "Nose",
        options = {
            { index = 28287, label = "Nose Width" },
            { index = 13425, label = "Nose Size" },
            { index = 1013, label = "Nose Height" },
            { index = 13489, label = "Nose Angle" },
            { index = 61782, label = "Nose Curvature" },
            { index = 22046, label = "Nostrils Distance" },
        }
    },
    {
        id = "mouth",
        label = "Mouth & Lips",
        options = {
            { index = 61541, label = "Mouth Width" },
            { index = 43625, label = "Mouth Depth" },
            { index = 31427, label = "Mouth X Position" },
            { index = 16653, label = "Mouth Y Position" },
            { index = 57350, label = "Left Corner Width" },
            { index = 40950, label = "Left Corner Depth" },
            { index = 46661, label = "Left Corner Height" },
            { index = 22344, label = "Left Corner Lip Distance" },
            { index = 60292, label = "Right Corner Width" },
            { index = 49299, label = "Right Corner Depth" },
            { index = 55718, label = "Right Corner Height" },
            { index = 9423, label = "Right Corner Lip Distance" },
            { index = 6656, label = "Upper Lip Height" },
            { index = 37313, label = "Upper Lip Width" },
            { index = 50037, label = "Upper Lip Depth" },
            { index = 47949, label = "Lower Lip Height" },
            { index = 45232, label = "Lower Lip Width" },
            { index = 23830, label = "Lower Lip Depth" },
        }
    },
    {
        id = "neck",
        label = "Neck",
        options = {
            { index = 36277, label = "Neck Width" },
            { index = 60890, label = "Neck Depth" },
        }
    }
}

local categoryLookup, optionLookup = {}, {}
for _, category in ipairs(expressionCategories) do
    categoryLookup[category.id] = category
    for _, option in ipairs(category.options) do
        optionLookup[option.index] = option
    end
end

local expressionParentMenu = nil
local expressionActiveCategory = nil

-- delegates to overlay.lua's helper: export first, event fallback, ~2s retry
local function ensureMenuData()
    return TattooEnsureMenuData()
end

local function notify(msg)
    TriggerEvent("chat:addMessage", {
        color = { 186, 132, 255 },
        multiline = true,
        args = { "Expressions", msg }
    })
end

-- Ensures expression data is loaded and available for the player character
local function ensureExpressionsData()
    if expressionValues ~= nil then
        return true
    end

    expressionValues = {}
    
    -- Request data from the server if not already in progress
    if not expressionsRequested then
        expressionsRequested = true
        DebugPrint("Requesting expressions from server...")
        TriggerServerEvent("pup-misc:overlay:requestExpressions")
    end

    -- Data will be populated via overlay:receiveExpressions event
    return true
end

local function isOptionAllowed(option, ped)
    if not option.sex then
        return true
    end

    if option.sex == "female" then
        return not IsPedMale(ped)
    elseif option.sex == "male" then
        return IsPedMale(ped)
    end

    return true
end

local function sortByLabel(list)
    table.sort(list, function(a, b)
        local la = string.lower(a.label or "")
        local lb = string.lower(b.label or "")
        return la < lb
    end)
    return list
end

local function getSortedCategories()
    local categories = {}
    for _, category in ipairs(expressionCategories) do
        table.insert(categories, category)
    end
    return sortByLabel(categories)
end

local function getSortedCategoryOptions(category, ped)
    local options = {}
    for _, option in ipairs(category.options) do
        if not ped or isOptionAllowed(option, ped) then
            table.insert(options, option)
        end
    end
    table.sort(options, function(a, b)
        return string.lower(a.label or "") < string.lower(b.label or "")
    end)
    return options
end

local function sanitizeValue(value)
    local sanitized = tonumber(value) or 0.0
    if sanitized >= 1.0 or math.abs(1.0 - sanitized) <= 0.0001 then
        return 1.0
    end
    if sanitized <= -1.0 or math.abs(-1.0 - sanitized) <= 0.0001 then
        return -1.0
    end
    if sanitized < valueRange.min then
        sanitized = valueRange.min
    elseif sanitized > valueRange.max then
        sanitized = valueRange.max
    end
    return sanitized + 0.0
end

local function setExpressionValue(index, value)
    if expressionValues == nil then
        return
    end
    expressionValues[tostring(index)] = value
end

local function getExpressionValue(index)
    if expressionValues == nil then
        return 0.0
    end
    return expressionValues[tostring(index)] or 0.0
end

local function copyExpressionTable(source)
    if source == nil then
        return {}
    end
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

local function updateDirtyState()
    if expressionValues == nil then
        expressionDirty = false
        return
    end
    local epsilon = 0.0001
    local keys = {}
    for key in pairs(expressionValues) do
        keys[key] = true
    end
    for key in pairs(expressionOriginalSnapshot) do
        keys[key] = true
    end

    for key in pairs(keys) do
        local current = tonumber(expressionValues[key]) or 0.0
        local baseline = tonumber(expressionOriginalSnapshot[key]) or 0.0
        if math.abs(current - baseline) > epsilon then
            expressionDirty = true
            return
        end
    end

    expressionDirty = false
end

local function syncSnapshot()
    if expressionValues == nil then
        expressionOriginalSnapshot = {}
        expressionDirty = false
        return
    end
    expressionOriginalSnapshot = copyExpressionTable(expressionValues)
    expressionDirty = false
end

local function applyExpressionValue(ped, option, value)
    if not option then
        return
    end

    ped = ped or PlayerPedId()
    local normalized = sanitizeValue(value)
    setExpressionValue(option.index, normalized)
    updateDirtyState()

    if ped == 0 then
        return
    end

    if not IsPedHuman(ped) then
        return
    end

    if not isOptionAllowed(option, ped) then
        return
    end

    Citizen.InvokeNative(0x5653AB26C82938CF, ped, option.index, normalized)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)
end

local function resetExpressions(ped, onlyCategory)
    if expressionValues == nil then
        return
    end
    ped = ped or PlayerPedId()
    local categories = expressionCategories

    if onlyCategory then
        categories = { onlyCategory }
    end

    for _, category in ipairs(categories) do
        for _, option in ipairs(category.options) do
            applyExpressionValue(ped, option, 0.0)
        end
    end
end

local function categoryHasOptions(category, ped)
    for _, option in ipairs(category.options) do
        if isOptionAllowed(option, ped) then
            return true
        end
    end

    return false
end

local function applyAllExpressions()
    -- ensureExpressionsData only starts the fetch, so it cannot be used as "ready"
    if not expressionsLoaded then
        ensureExpressionsData()
        return
    end

    if expressionValues == nil then
        return
    end

    local ped = PlayerPedId()
    if ped == 0 or not IsPedHuman(ped) then
        return
    end

    for key, value in pairs(expressionValues) do
        local index = tonumber(key)
        local option = optionLookup[index]
        if option then
            applyExpressionValue(ped, option, value)
        end
    end
end

local function restoreSnapshot()
    if expressionValues == nil then
        return
    end
    expressionValues = copyExpressionTable(expressionOriginalSnapshot)
    if expressionsLoaded then
        applyAllExpressions()
    end
    updateDirtyState()
end

local function buildPayload()
    local payload = {}
    if expressionValues ~= nil then
        for key, value in pairs(expressionValues) do
            payload[key] = value
        end
    end
    return json.encode(payload)
end

local function hydrateExpressions(data)
    expressionValues = {}
    if type(data) ~= "table" then
        return
    end
    for key, value in pairs(data) do
        local idx = tonumber(key) or key
        setExpressionValue(idx, sanitizeValue(value))
    end
end

local function deserializePayload(payload)
    if not payload or payload == "" then
        hydrateExpressions({})
    elseif type(payload) == "table" then
        -- the server decodes before sending; only the disguise path sends a string
        hydrateExpressions(payload)
    else
        local ok, decoded = pcall(json.decode, payload)
        -- older rows hold a JSON string wrapping the object
        if ok and type(decoded) == "string" then
            ok, decoded = pcall(json.decode, decoded)
        end
        if ok and type(decoded) == "table" then
            hydrateExpressions(decoded)
        else
            hydrateExpressions({})
        end
    end
    syncSnapshot()
end

local function saveExpressionsToServer()
    ensureExpressionsData()
    -- NEVER save a set we have not loaded yet: buildPayload would send {} and
    -- overwrite everything they already own, after charging them for it.
    if not expressionsLoaded then
        TriggerEvent("vorp:TipRight", TattooLocale.bodyLoading, 4000)
        return false
    end
    local payload = buildPayload()
    TriggerServerEvent("pup-misc:overlay:saveExpressions", payload)
    return true
end

local function openExpressionConfirmMenu()
    if not ensureMenuData() then
        return
    end

    local price = TattooConfig and TattooConfig.Prices.bodyAdjustments or 0
    local yesLabel = price > 0 and ("Yes - Pay $"..price) or "Yes"
    local subtext = price > 0 and ("Cost: $"..price) or "Confirm save"
    local elements = {
        { label = yesLabel, value = "yes", desc = "Purchase these adjustments" },
        { label = "No", value = "no", desc = "Return without saving" }
    }

    TattooMenuData.CloseAll()
    TattooMenuData.Open("default", GetCurrentResourceName(), "expression_confirm", {
        title = "Confirm Purchase",
        subtext = subtext,
        align = "top-left",
        elements = elements,
        lastmenu = "TattooOpenExpressionRootMenu",
    }, function(data, menu)
        if data.current == "backup" then
            if data.trigger and _G[data.trigger] then
                _G[data.trigger]()
            end
            return
        end

        if data.current.value == "yes" then
            if saveExpressionsToServer() then
                expressionPurchasePending = true
                if type(TattooExistAndReset) == "function" then
                    TattooExistAndReset()
                end
                menu.close()
            end
            return
        end

        if data.current.value == "no" then
            if data.trigger and _G[data.trigger] then
                _G[data.trigger]()
            end
        end
    end, function(_, menu)
        menu.close()
    end)
end

function TattooOpenExpressionRootMenu(parentMenu)
    if not ensureMenuData() then
        return
    end

    if not ensureExpressionsData() then
        return
    end

    local ped = PlayerPedId()
    if not IsPedHuman(ped) then
        return
    end

    if parentMenu == false then
        expressionParentMenu = nil
    elseif parentMenu ~= nil then
        expressionParentMenu = parentMenu
    end

    local elements = {}
    local price = TattooConfig and TattooConfig.Prices.bodyAdjustments or 0
    local saveLabel = price > 0 and ("Save Changes ($"..price..")") or "Save Changes"
    table.insert(elements, {
        label = saveLabel,
        value = "save",
        desc = "Purchase and store these adjustments"
    })

    for _, category in ipairs(getSortedCategories()) do
        if categoryHasOptions(category, ped) then
            table.insert(elements, {
                label = category.label,
                value = "category",
                desc = category.id
            })
        end
    end

    table.insert(elements, {
        label = "Reset All",
        value = "reset_all",
        desc = "Reset every expression back to default"
    })

    local subtext = "MetaPed expressions"
    if price > 0 then
        subtext = "Body adjustments cost $"..price.." when saved"
    end

    local menuData = {
        title = "Body Adjustments",
        subtext = subtext,
        align = "top-left",
        elements = elements,
    }

    if expressionParentMenu then
        menuData.lastmenu = expressionParentMenu
    end

    TattooMenuData.CloseAll()
    TattooMenuData.Open("default", GetCurrentResourceName(), "expression_root", menuData,
    function(data, menu)
        if data.current == "backup" then
            if data.trigger and _G[data.trigger] then
                _G[data.trigger]()
            end
            return
        end

        if data.current.value == "save" then
            if not expressionDirty then
                return
            end
            openExpressionConfirmMenu()
            return
        end

        if data.current.value == "reset_all" then
            resetExpressions(ped)
            return
        end

        if data.current.value == "category" and data.current.desc then
            local desc = data.current.desc
            TattooMenuData.CloseAll()
            Citizen.SetTimeout(50, function()
                TattooOpenExpressionCategoryMenu(desc)
            end)
        end
    end,
    function(_, menu)
        menu.close()
    end)
end

function TattooOpenExpressionCategoryMenu(categoryId)
    if not ensureMenuData() then
        return
    end

    if not ensureExpressionsData() then
        return
    end

    if categoryId ~= nil then
        expressionActiveCategory = categoryId
    elseif not expressionActiveCategory then
        return
    else
        categoryId = expressionActiveCategory
    end

    local ped = PlayerPedId()
    if not IsPedHuman(ped) then
        return
    end

    local category = categoryLookup[categoryId]
    if not category then
        return
    end

    local elements = {}

    for _, option in ipairs(getSortedCategoryOptions(category, ped)) do
        table.insert(elements, {
            label = option.label,
            desc = "Use left / right to adjust",
            tag = option.index,
            type = "slider",
            min = option.min or valueRange.min,
            max = option.max or valueRange.max,
            hop = option.step or valueRange.step,
            value = getExpressionValue(option.index)
        })
    end

    if #elements == 0 then
        Citizen.SetTimeout(50, function()
            TattooOpenExpressionRootMenu()
        end)
        return
    end

    table.insert(elements, {
        label = "Reset Category",
        value = "reset_category",
        desc = "Reset every slider here"
    })

    TattooMenuData.CloseAll()
    TattooMenuData.Open("default", GetCurrentResourceName(), "expression_" .. categoryId, {
        title = category.label,
        subtext = "Values between -1.0 and 1.0",
        align = "top-left",
        elements = elements,
        lastmenu = "TattooOpenExpressionRootMenu",
    }, function(data, menu)
        if data.current == "backup" then
            if data.trigger and _G[data.trigger] then
                _G[data.trigger]()
            end
            return
        end

        if data.current.value == "reset_category" then
            resetExpressions(ped, category)
            Citizen.SetTimeout(50, function()
                TattooOpenExpressionCategoryMenu(categoryId)
            end)
            return
        end

        local tag = tonumber(data.current.tag)
        if tag and optionLookup[tag] then
            applyExpressionValue(ped, optionLookup[tag], data.current.value)
        end
    end, function(_, menu)
        menu.close()
    end)
end

RegisterNetEvent("pup-misc:overlay:openExpressionMenu", function(lastmenu)
    TattooOpenExpressionRootMenu(lastmenu)
end)

-- Handle the initial information received from the server (skin/overlay) This is used as a hook to also TattooApply
AddEventHandler("pup-misc:overlay:recinfo", function()
    Citizen.CreateThread(function()
        -- Wait for the ped to be fully loaded and available
        local ped = PlayerPedId()
        while not ped or ped == 0 do
            Citizen.Wait(100)
            ped = PlayerPedId()
        end
        
        -- Brief delay to ensure VORP core and other dependencies are initialized
        Citizen.Wait(300)
        DebugPrint("Applying expressions on character load")
        applyAllExpressions()
    end)
end)

-- Receive expressions payload from server and TattooApply to ped
RegisterNetEvent("pup-misc:overlay:receiveExpressions", function(payload)
    DebugPrint("Received expressions payload from server")
    deserializePayload(payload)
    expressionsRequested = false
    expressionsLoaded = true
    -- Apply the received values immediately to the player
    applyAllExpressions()
end)

-- Handle the result of a save/purchase request for expressions
RegisterNetEvent("pup-misc:overlay:expressionSaveResult", function(success, payloadOrReason)
    if success then
        DebugPrint("Expression save successful")
        if payloadOrReason then
            deserializePayload(payloadOrReason)
            applyAllExpressions()
        end
        expressionsRequested = false
        expressionsLoaded = true
        expressionPurchasePending = false
        -- what is saved is now the baseline, so the next Save does not charge again and a close does not undo it
        syncSnapshot()
    else
        DebugPrint("Expression save failed: " .. tostring(payloadOrReason))
        expressionPurchasePending = false
        -- Specific error handling for insufficient funds
        if payloadOrReason == "funds" then
            TriggerEvent("vorp:TipRight", TattooLocale.bodyNoFunds, 4000)
        end
        -- restoreSnapshot re-applies to the ped itself, so a failed save needs no character reload
        restoreSnapshot()
    end
end)

RegisterNetEvent("pup-misc:overlay:applyExpressionsToPed", function()
    applyAllExpressions()
end)

RegisterNetEvent("pup-misc:overlay:overlayMenuClosed", function()
    if expressionPurchasePending then
        return
    end
    if expressionDirty then
        restoreSnapshot() -- re-applies to the ped; no character reload needed
    end
end)

RegisterNetEvent("vorp:SelectedCharacter")
AddEventHandler("vorp:SelectedCharacter", function(charidx)
    expressionValues = nil
    expressionOriginalSnapshot = {}
    expressionDirty = false
    expressionsLoaded = false
    expressionsRequested = false
    expressionPurchasePending = false
    ensureExpressionsData()
end)

-- every ped rebuild re-applies the skin's zeroed face values on top of these
AddEventHandler("vorp_character:client:reloadedComponents", function()
    if not expressionsLoaded then return end
    CreateThread(function()
        -- wait for the ped: a write landing while it is still rebuilding is dropped
        local waited = 0
        while waited < 5000 do
            local ped = PlayerPedId()
            if ped ~= 0 and Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) then break end
            Wait(100)
            waited = waited + 100
        end
        Wait(250) -- the variation commit lands a frame or two after "ready"
        applyAllExpressions()
    end)
end)

-- page bridge: the mirror page (nui.lua) drives Body Adjustments through these
function ExpressionPageData()
    ensureExpressionsData()
    local ped = PlayerPedId()
    local cats, items = {}, {}
    for _, category in ipairs(getSortedCategories()) do
        if categoryHasOptions(category, ped) then
            cats[#cats + 1] = { id = category.id, name = category.label }
            for _, option in ipairs(getSortedCategoryOptions(category, ped)) do
                items[#items + 1] = {
                    id = option.index, name = option.label, category = category.id,
                    kind = "expr", value = getExpressionValue(option.index),
                }
            end
        end
    end
    return {
        price = (TattooConfig and TattooConfig.Prices.bodyAdjustments) or 0,
        categories = cats, items = items,
    }
end

function ExpressionPageSet(index, value)
    local option = optionLookup[tonumber(index)]
    if not option then return end
    applyExpressionValue(PlayerPedId(), option, value)
end

function ExpressionPageResetAll()
    resetExpressions(PlayerPedId())
end

-- returns false when there is nothing to buy; true when the save was sent
function ExpressionPageSave()
    if not expressionDirty then return false end
    if saveExpressionsToServer() then
        expressionPurchasePending = true
        return true
    end
    return false
end
