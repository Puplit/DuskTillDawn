-- Modified by Puppet (Dusk Till Dawn), 2026
---@diagnostic disable: undefined-global
-- face & body page (ui/): slider rows driving PlayerSkin + SetCharExpression; Config.FacePage.enabled

local fpOpen  = false
local fpTable = nil   -- what OpenFaceMenu was handed; returned on the way back
local fpValue = nil

-- F8 diagnostics for open + every slider change
local FP_DEBUG = false
local function fpDbg(...)
    if not FP_DEBUG then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[facepage]^7 " .. table.concat(parts, " "))
end

-- chip order; each chip pulls one or more Config.FaceFeatures groups
local FP_GROUPS = {
    { id = "head",  label = "Head",   tags = { "head" } },
    { id = "eyes",  label = "Eyes",   tags = { "eyesandbrows" } },
    { id = "ears",  label = "Ears",   tags = { "ears" } },
    { id = "cheek", label = "Cheeks", tags = { "cheek" } },
    { id = "jaw",   label = "Jaw",    tags = { "jaw", "chin" } },
    { id = "nose",  label = "Nose",   tags = { "nose" } },
    { id = "mouth", label = "Mouth",  tags = { "mouthandlips" } },
    { id = "body",  label = "Body",   tags = { "upperbody", "lowerbody" } },
}

-- STAGE 1 - Heritage / Build / Age as chips on this page, so the slider-only ink menus need no drill-down
local FP_PICK_GROUPS <const> = {
    { id = "heritage", label = "Heritage" },
    { id = "build",    label = "Build" },
    { id = "age",      label = "Age" },
    { id = "whistle",  label = "Whistle", creationOnly = true },
}

local function fpBuildTabs()
    return Config.FacePage.buildTabs ~= false
end

-- Clothing on/off. A PREVIEW ONLY: it re-applies what the ped already carries and
-- writes nothing, so toggling it can never change what is saved.
CreatorClothesOn = true

-- during creation PlayerClothing is the live set; a second chance has CachedComponents
local function clothingSource()
    if IsInCharCreation and PlayerClothing and next(PlayerClothing) then return PlayerClothing end
    if CachedComponents and next(CachedComponents) then return CachedComponents end
    return PlayerClothing
end

local function wearingAnything()
    local src = clothingSource()
    if not src then return false end
    for _, c in pairs(src) do
        if type(c) == "table" and c.comp and c.comp ~= -1 then return true end
    end
    return false
end

local function setClothes(on)
    local src = clothingSource()
    if not src or not next(src) then return false end
    local ped <const> = PlayerPedId()
    IsPedReadyToRender(ped)

    -- strip with the engine preset: pulling tags off one at a time leaves the
    -- legs unrendered, because the boots' wearable state needs fixing too
    local preset <const> = tonumber(Config.Creator.undressPreset)
    if not on and preset then
        EquipMetaPedOutfitPreset(ped, preset)
        UpdatePedVariation(ped)
        TriggerEvent("pup_clothing:client:undressExtras")
        CreatorClothesOn = false
        return true
    end

    for cat, c in pairs(src) do
        if type(c) == "table" and c.comp and c.comp ~= -1 then
            local tag <const> = (Config.ComponentCategories or {})[cat]
            if on then
                ApplyShopItemToPed(c.comp, ped)
            elseif tag and IsMetaPedUsingComponent(tag) then
                RemoveTagFromMetaPed(tag, ped)
            end
        end
    end

    -- the tags came off, so the skin has to go back on or the body renders as nothing
    if not on and EnsureBodySkin then EnsureBodySkin(ped) end

    UpdatePedVariation(ped)
    -- pup_clothing's singleplayer garments and custom tints live outside CachedComponents
    TriggerEvent(on and "pup_clothing:client:dressExtras" or "pup_clothing:client:undressExtras")
    if on then
        if ApplyCachedColors then ApplyCachedColors(ped, src) end
        if ReassertRolledClothing then ReassertRolledClothing() end
    end
    CreatorClothesOn = on
    return true
end

-- other client scripts (pup-misc bathing) strip the character the same way the Clothing row does.
-- Local event only: there is no /undress command on purpose.
AddEventHandler("vorp_character:client:undress", function()
    setClothes(false)
end)

-- index pickers, not expressions: each one applies a component or an overlay
local function fpPickItems()
    local out = {}
    local function add(role, name, category, value, min, max, names)
        max = tonumber(max) or 0
        if max < min then return end -- config missing that list: skip the row
        value = tonumber(value) or min
        if value < min then value = min elseif value > max then value = max end
        out[#out + 1] = {
            id = "pick_" .. role, name = name, category = category,
            kind = "pick", role = role, value = value, min = min, max = max,
            names = names, -- shown instead of the raw index when present
        }
    end

    -- gender first: it rebuilds the ped, so it belongs above everything it resets
    if IsInCharCreation and Config.Creator.genderInMenu ~= false then
        add("gender", "Gender", "heritage", (GetGender() == "Male") and 1 or 2, 1, 2, { "Male", "Female" })
    end

    local sc <const> = Config.DefaultChar and Config.DefaultChar[SkinColorTracker]
    local bt <const> = Config.BodyType

    add("heritage", "Skin Tone",  "heritage", SkinColorTracker, 1, Config.DefaultChar and #Config.DefaultChar or 0)
    add("head",     "Head Shape", "heritage", HeadIndexTracker, 1,
        sc and #HeadsFor(sc, GetGender() == "Male" and "M" or "F") or 0)

    add("bodytype", "Torso",     "build", BodyTypeTracker, 1, sc and #sc.Body or 0)
    add("legstype", "Legs",      "build", LegsTypeTracker, 1, sc and #sc.Legs or 0)
    add("body",     "Body Type", "build", BodyTracker,     1, bt and #bt.Body or 0)
    add("waist",    "Waist",     "build", WaistTracker,    1, bt and #bt.Waist or 0)

    -- strip the clothes to sculpt the body, then put them back
    if wearingAnything() then
        add("clothes", "Clothing", "build", CreatorClothesOn and 1 or 2, 1, 2, { "On", "Off" })
    end

    -- Whistle: creation only
    if IsInCharCreation then
        add("whistle_style",   "Whistle Style",   "whistle", WHISTLE and WHISTLE.style or 0, 0, 10)
        add("whistle_pitch",   "Whistle Pitch",   "whistle",
            math.floor((tonumber(WHISTLE and WHISTLE.pitch) or 0) * 10 + 0.5), 0, 10)
        add("whistle_clarity", "Whistle Clarity", "whistle",
            math.floor((tonumber(WHISTLE and WHISTLE.clarity) or 0) * 10 + 0.5), 0, 10)
    end

    -- eye colour and height: with these, this page covers everything the Appearance menu does
    add("eyecolor", "Eye Colour", "eyes",  EyeColorIndexTracker, 1, Config.Eyes and #Config.Eyes or 0)
    if IsInCharCreation then -- height is fixed after creation (second chance keeps it)
        add("height", "Height", "build", HeightChosen, 1, 3)
    end

    -- ageing is the exception: 0 is a real value (no wrinkles at all)
    local ageing <const> = Config.overlays_info and Config.overlays_info.ageing
    add("ageing_tx", "Wrinkles", "age", PlayerSkin.ageing_tx_id, 0, ageing and #ageing or 0)
    add("ageing_op", "Opacity",  "age",
        math.floor((tonumber(PlayerSkin.ageing_opacity) or 0) * 10 + 0.5), 0, 10)

    return out
end

-- STAGE 2 - Hair / Beard / Brows / Makeup
local FP_HAIR_CATS <const> = {
    { cat = "Hair",  label = "Hair",  kind = "hair" },
    { cat = "Beard", label = "Beard", kind = "hair", maleOnly = true },
    { cat = "Bow",   label = "Bow",   kind = "hair", femaleOnly = true },
    { cat = "eyebrows",     label = "Brows",   kind = "overlay" },
    { cat = "beardstabble", label = "Stubble", kind = "overlay", maleOnly = true },
    { cat = "hair",         label = "Hair Dye", kind = "overlay" },
}

-- makeup categories come straight from overlayLookup, minus the three above
local FP_MAKEUP_SKIP <const> = { eyebrows = true, beardstabble = true, hair = true }

local function fpHairTable(cat)
    if cat == "Hair" then return GetHair(GetGender(), "hair") end
    if cat == "Beard" then return GetHair("Male", "beard") end
    if cat == "Bow" then return GetHair(GetGender(), "bow") end
    return nil
end

-- same seeding OpenHairSelectionMenu does: in creation start at 1, otherwise resolve what the character is already wearing
local function fpSeedHair(cat, tbl)
    if HairIndexTracker[cat] and HairColorIndexTracker[cat] then return end
    local hi, hci = 1, 1
    if not IsInCharCreation then
        local ok, a, b = pcall(GetHairIndex, cat, tbl)
        if ok and a then hi, hci = a, b or 1 end
    end
    if not HairIndexTracker[cat] then HairIndexTracker[cat] = hi end
    if not HairColorIndexTracker[cat] then HairColorIndexTracker[cat] = hci end
end

local function fpFacePrice(tag)
    local p = Config.Shops and Config.Shops.prices and Config.Shops.prices.face
    return (p and p[tag] and tonumber(p[tag].price)) or 0
end

local function fpHairTabs()
    return Config.FacePage.hairTabs ~= false
end

-- which chips apply to this character
local function fpHairGroups()
    local male <const> = GetGender() == "Male"
    local out = {}
    for _, g in ipairs(FP_HAIR_CATS) do
        if not ((g.maleOnly and not male) or (g.femaleOnly and male)) then
            if g.kind ~= "overlay" or (overlayLookup and overlayLookup[g.cat]) then
                out[#out + 1] = g
            end
        end
    end
    -- MAKEUP IS NOT OFFERED IN CREATION: the tattoo mirror owns it
    if overlayLookup and Config.FacePage.makeup == true then
        local keys = {}
        for k in pairs(overlayLookup) do
            if not FP_MAKEUP_SKIP[k] then keys[#keys + 1] = k end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            out[#out + 1] = { cat = k, label = overlayLookup[k].label or k,
                              kind = "overlay", makeup = true }
        end
    end
    return out
end

local function fpHairItems()
    local out = {}
    local function row(t) out[#out + 1] = t; return t end

    for _, g in ipairs(fpHairGroups()) do
        local page <const> = g.makeup and "makeup" or ("hc_" .. g.cat)

        if g.kind == "hair" then
            local tbl = fpHairTable(g.cat)
            if tbl and #tbl > 0 then
                fpSeedHair(g.cat, tbl)
                local styleIdx <const> = HairIndexTracker[g.cat] or 1
                local shades <const> = tbl[styleIdx] and #tbl[styleIdx] or 0
                row{ id = "hs_" .. g.cat, name = (g.makeup and g.label or g.label) .. " Style",
                     category = page, kind = "pick", role = "hair_style", cat = g.cat,
                     value = styleIdx, min = 1, max = #tbl }
                if shades > 1 then
                    row{ id = "hcol_" .. g.cat, name = g.label .. " Colour",
                         category = page, kind = "pick", role = "hair_color", cat = g.cat,
                         value = math.min(HairColorIndexTracker[g.cat] or 1, shades),
                         min = 1, max = shades }
                end
                row{ id = "hrm_" .. g.cat, name = "Remove " .. g.label,
                     category = page, kind = "action", role = "hair_remove", cat = g.cat }
            end
        else
            local d <const> = overlayLookup and overlayLookup[g.cat]
            local textures <const> = Config.overlays_info and Config.overlays_info[g.cat]
            if d and textures then
                local palette <const> = Config.color_palettes and Config.color_palettes[g.cat]
                row{ id = "ot_" .. g.cat, name = g.label,
                     category = page, kind = "pick", role = "ovl_type", cat = g.cat,
                     value = tonumber(PlayerSkin[d.txt_id]) or 0, min = 0, max = #textures }
                if palette and #palette > 0 then
                    row{ id = "oc_" .. g.cat, name = g.label .. " Colour",
                         category = page, kind = "pick", role = "ovl_color", cat = g.cat,
                         value = MakeupColorIndexTracker[g.cat] or 0, min = 0, max = #palette }
                end
                row{ id = "oo_" .. g.cat, name = g.label .. " Opacity",
                     category = page, kind = "pick", role = "ovl_opacity", cat = g.cat,
                     value = math.floor((tonumber(PlayerSkin[d.opacity]) or 0) * 10 + 0.5),
                     min = 0, max = 10 }
                row{ id = "orm_" .. g.cat, name = "Remove " .. g.label,
                     category = page, kind = "action", role = "ovl_remove", cat = g.cat }
            end
        end
    end
    return out
end

local function fpIsShop()
    return ShopType == "face" and not IsInCharCreation
end

local function fpPushPrice()
    if fpIsShop() then
        SendNUIMessage({ type = "setPrice", price = GetCurrentAmmountToPay() })
    end
end

local function fpItems()
    local items = {}
    for _, g in ipairs(FP_GROUPS) do
        for _, tag in ipairs(g.tags) do
            local group = Config.FaceFeatures[tag]
            if group then
                -- sorted so the row order is stable between opens
                local names = {}
                for label in pairs(group) do names[#names + 1] = label end
                table.sort(names)
                for _, label in ipairs(names) do
                    local def = group[label]
                    items[#items + 1] = {
                        id = def.comp, name = label, category = g.id,
                        hash = def.hash, tag = tag, kind = "expr",
                        value = tonumber(PlayerSkin[def.comp]) or 0.0,
                    }
                end
            end
        end
    end
    -- teeth slides with the mouth rows, same 0..N picker the ink menu had
    items[#items + 1] = {
        id = "__teeth", name = "Teeth", category = "mouth", kind = "teeth",
        min = 0, max = #Config.Teeth, value = tonumber(TheethIndexTracker) or 0,
    }

    if fpBuildTabs() then
        for _, it in ipairs(fpPickItems()) do items[#items + 1] = it end
    end
    if fpHairTabs() then
        for _, it in ipairs(fpHairItems()) do items[#items + 1] = it end
    end
    return items
end

function OpenFacePage(tbl, value)
    fpTable, fpValue = tbl, value
    fpOpen = true
    Form.CloseAll()
    local cats = {}
    for _, g in ipairs(FP_GROUPS) do cats[#cats + 1] = { id = g.id, name = g.label } end
    if fpBuildTabs() then
        for _, g in ipairs(FP_PICK_GROUPS) do
            if not (g.creationOnly and not IsInCharCreation) then
                cats[#cats + 1] = { id = g.id, name = g.label }
            end
        end
    end
    if fpHairTabs() then
        local seenMakeup = false
        for _, g in ipairs(fpHairGroups()) do
            if g.makeup then
                if not seenMakeup then
                    seenMakeup = true
                    cats[#cats + 1] = { id = "makeup", name = "Makeup" }
                end
            else
                cats[#cats + 1] = { id = "hc_" .. g.cat, name = g.label }
            end
        end
    end

    local allItems <const> = fpItems()
    local picks = 0
    for _, it in ipairs(allItems) do if it.kind == "pick" then picks = picks + 1 end end
    -- STAGE1 in this line means the new code is live
    fpDbg("open: creation=" .. tostring(IsInCharCreation), "shop=" .. tostring(ShopType),
        "STAGE1 buildTabs=" .. tostring(fpBuildTabs()),
        "cats=" .. #cats, "items=" .. #allItems, "picks=" .. picks,
        "DefaultChar=" .. tostring(Config.DefaultChar and #Config.DefaultChar or "nil"),
        "BodyType=" .. tostring(Config.BodyType and #Config.BodyType.Body or "nil"))

    SendNUIMessage({
        type = "open", title = "Face & Body",
        categories = cats, items = allItems,
        shop = fpIsShop(), price = fpIsShop() and GetCurrentAmmountToPay() or 0,
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)   -- WASD / zoom camera prompts keep working
end

local function fpClose()
    fpOpen = false
    SendNUIMessage({ type = "close" })
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
end

-- newest request per comp
local fpSeq = {}

RegisterNUICallback('face_set', function(data, cb)
    cb('ok')
    if not fpOpen then return fpDbg("face_set ignored: page not open") end
    local comp, hash = data.comp, tonumber(data.hash)
    -- +0.0 forces a FLOAT: tonumber("1") is a lua54 integer and SetCharExpression is a
    -- bare InvokeNative, so an int is packed as an int and the native reads those bits as a float
    local value = (tonumber(data.value) or 0.0) + 0.0
    if type(comp) ~= "string" or not hash or PlayerSkin[comp] == nil then
        return fpDbg("face_set REJECTED", "comp=" .. tostring(data.comp),
            "hash=" .. tostring(data.hash), "skinHasComp=" .. tostring(PlayerSkin[tostring(data.comp)] ~= nil))
    end
    if value < -1.0 then value = -1.0 elseif value > 1.0 then value = 1.0 end
    PlayerSkin[comp] = value

    local seq <const> = (fpSeq[comp] or 0) + 1
    fpSeq[comp] = seq

    fpDbg("face_set", comp, "hash=" .. hash, "value=" .. value, "ped=" .. PlayerPedId())
    -- bounded ready-wait: the unbounded one can stall every change forever
    local guard = 0
    while guard < 60 and not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, PlayerPedId()) do
        Wait(0)
        guard = guard + 1
    end
    -- a newer drag position arrived while we waited; that one wins
    if fpSeq[comp] ~= seq then
        return fpDbg("face_set superseded", comp, "seq=" .. seq)
    end
    SetCharExpression(PlayerPedId(), hash, value)
    UpdatePedVariation()
    fpDbg("face_set applied", comp, "waitedFrames=" .. guard)
    if TotalAmountToPay and type(data.tag) == "string" then
        TotalAmountToPay[data.tag] = (value == 0) and 0 or fpFacePrice(data.tag)
    end
    fpPushPrice()
end)

-- Randomise / Reset send the whole category at once: one variation rebuild for the lot instead of one per row
RegisterNUICallback('face_many', function(data, cb)
    cb('ok')
    if not fpOpen then return end
    local list = data and data.items
    if type(list) ~= "table" then return end

    local ped <const> = PlayerPedId()
    IsPedReadyToRender(ped)

    local applied = 0
    for _, it in ipairs(list) do
        local comp, hash = it.comp, tonumber(it.hash)
        local value = (tonumber(it.value) or 0.0) + 0.0
        if type(comp) == "string" and hash and PlayerSkin[comp] ~= nil then
            if value < -1.0 then value = -1.0 elseif value > 1.0 then value = 1.0 end
            PlayerSkin[comp] = value
            fpSeq[comp] = (fpSeq[comp] or 0) + 1 -- outranks any in-flight single set
            SetCharExpression(ped, hash, value)
            applied = applied + 1
            if TotalAmountToPay and type(it.tag) == "string" then
                TotalAmountToPay[it.tag] = (value == 0) and 0 or fpFacePrice(it.tag)
            end
        end
    end

    UpdatePedVariation(ped)
    fpDbg("face_many", "applied=" .. applied, "of=" .. #list)
    fpPushPrice()
end)

-- Heritage / Build / Age rows
RegisterNUICallback('face_pick', function(data, cb)
    cb('ok')
    if not fpOpen or not fpBuildTabs() then return end
    local role <const> = data and data.role
    local v <const> = math.floor(tonumber(data and data.value) or 0)
    local g <const> = GetGender() == "Male" and "M" or "F"
    local ped <const> = PlayerPedId()

    if role == "heritage" then
        local list <const> = Config.DefaultChar
        if not list or v < 1 or v > #list then return end
        SkinColorTracker = v
        local sc <const> = list[v]
        -- a tone with fewer heads/bodies would leave the old index dangling
        local heads <const> = HeadsFor(sc, g)
        if HeadIndexTracker > #heads then HeadIndexTracker = #heads end
        if BodyTypeTracker > #sc.Body  then BodyTypeTracker  = #sc.Body end
        if LegsTypeTracker > #sc.Legs  then LegsTypeTracker  = #sc.Legs end
        PlayerSkin.HeadType = joaat(heads[HeadIndexTracker]:format(g))
        PlayerSkin.BodyType = joaat(sc.Body[BodyTypeTracker]:format(g))
        PlayerSkin.LegsType = joaat(sc.Legs[LegsTypeTracker]:format(g))
        PlayerSkin.albedo   = joaat(sc.Albedo[1]:format(g))
        -- Torso and Legs are the meshes LoadAll applies last, so leaving them on
        -- the old tone puts the previous skin back and the tone survives on the head
        PlayerSkin.Torso    = PlayerSkin.BodyType
        PlayerSkin.Legs     = PlayerSkin.LegsType
        IsPedReadyToRender(ped)
        ApplyShopItemToPed(PlayerSkin.HeadType)
        ApplyShopItemToPed(PlayerSkin.BodyType)
        ApplyShopItemToPed(PlayerSkin.LegsType)
        UpdatePedVariation(ped)
        -- the dependent rows may have been clamped, so resend their numbers
        SendNUIMessage({ type = "items", items = fpItems() })
        return fpDbg("face_pick heritage", v)
    end

    if role == "head" then
        local sc <const> = Config.DefaultChar and Config.DefaultChar[SkinColorTracker]
        local heads <const> = HeadsFor(sc, g)
        if not sc or v < 1 or v > #heads then return end
        HeadIndexTracker = v
        PlayerSkin.HeadType = joaat(heads[v]:format(g))
        IsPedReadyToRender(ped)
        ApplyShopItemToPed(PlayerSkin.HeadType)
        UpdatePedVariation(ped)
        return fpDbg("face_pick head", v)
    end

    if role == "bodytype" or role == "legstype" then
        local sc <const> = Config.DefaultChar and Config.DefaultChar[SkinColorTracker]
        local list <const> = sc and ((role == "bodytype") and sc.Body or sc.Legs)
        if not list or v < 1 or v > #list then return end
        local hash <const> = joaat(list[v]:format(g))
        -- menu.lua writes Torso for the "Body" row and Legs for the "Legs" row
        if role == "bodytype" then
            PlayerSkin.Torso = hash
            BodyTypeTracker = v
        else
            PlayerSkin.Legs = hash
            LegsTypeTracker = v
        end
        IsPedReadyToRender(ped)
        ApplyShopItemToPed(hash)
        UpdatePedVariation(ped)
        return fpDbg("face_pick " .. role, v)
    end

    if role == "body" then
        local list <const> = Config.BodyType and Config.BodyType.Body
        if not list or v < 1 or v > #list then return end
        IsPedReadyToRender(ped)
        EquipMetaPedOutfit(list[v])
        UpdatePedVariation(ped)
        PlayerSkin.Body = list[v]
        BodyTracker = v
        return fpDbg("face_pick body", v)
    end

    if role == "waist" then
        local list <const> = Config.BodyType and Config.BodyType.Waist
        if not list or v < 1 or v > #list then return end
        PlayerSkin.Waist = list[v]
        IsPedReadyToRender(ped)
        EquipMetaPedOutfit(PlayerSkin.Waist)
        UpdatePedVariation(ped)
        WaistTracker = v
        return fpDbg("face_pick waist", v)
    end

    if role == "ageing_tx" then
        local ageing <const> = Config.overlays_info and Config.overlays_info.ageing
        if not ageing or v < 0 or v > #ageing then return end
        PlayerSkin.ageing_tx_id = v
        ApplyOverlay("ageing", PlayerSkin.ageing_visibility, v, 0, 0, 1, 1.0, 0, 0, 0, 0, 0, 1,
            PlayerSkin.ageing_opacity, PlayerSkin.albedo)
        return fpDbg("face_pick ageing_tx", v)
    end

    if role == "ageing_op" then
        if v < 0 or v > 10 then return end
        if v > 0 then
            PlayerSkin.ageing_opacity = v / 10
            PlayerSkin.ageing_visibility = 1
        else
            PlayerSkin.ageing_opacity = 0
            PlayerSkin.ageing_visibility = 0
        end
        ApplyOverlay("ageing", PlayerSkin.ageing_visibility, PlayerSkin.ageing_tx_id, 0, 0, 1, 1.0,
            0, 0, 0, 0, 0, 1, PlayerSkin.ageing_opacity, PlayerSkin.albedo)
        return fpDbg("face_pick ageing_op", v)
    end

    -- 1 = dressed, 2 = stripped. Preview only; nothing is written either way.
    if role == "clothes" then
        if v ~= 1 and v ~= 2 then return end
        return fpDbg("face_pick clothes", v, "ok=" .. tostring(setClothes(v == 1)))
    end

    -- 1 = Male, 2 = Female
    if role == "gender" then
        if v ~= 1 and v ~= 2 then return end
        if not SwitchCreatorGender then return fpDbg("face_pick: no gender api") end
        local changed <const> = SwitchCreatorGender(v == 1)
        if changed then
            SendNUIMessage({ type = "items", items = fpItems() })
        end
        return fpDbg("face_pick gender", v, "changed=" .. tostring(changed))
    end

    if role == "eyecolor" then
        local list <const> = Config.Eyes
        if not list or v < 1 or v > #list then return end
        StartAnimation("mood_normal_eyes_wide")
        IsPedReadyToRender(ped)
        PlayerSkin.Eyes = joaat(list[v]:format(g))
        ApplyShopItemToPed(PlayerSkin.Eyes)
        UpdatePedVariation(ped)
        EyeColorIndexTracker = v
        return fpDbg("face_pick eyecolor", v)
    end

    -- style is a whole number 0-10; pitch and clarity are the 0-10 row scaled back to the 0.0-1.0 the engine wants
    if role == "whistle_style" or role == "whistle_pitch" or role == "whistle_clarity" then
        if v < 0 or v > 10 then return end
        if not setWhistles then return fpDbg("face_pick: setWhistles missing") end
        if role == "whistle_style" then
            setWhistles(v, "style")
        elseif role == "whistle_pitch" then
            setWhistles(v / 10, "pitch")
        else
            setWhistles(v / 10, "clarity")
        end
        return fpDbg("face_pick " .. role, v)
    end

    if role == "height" then
        -- 1 short / 2 normal / 3 tall, same scales the Appearance row used
        local scale <const> = ({ [1] = 0.85, [2] = 1.0, [3] = 1.05 })[v]
        if not scale then return end
        SetPedScale(ped, scale)
        PlayerSkin.Scale = scale -- what makes it survive the save
        HeightChosen = v
        -- the framing is measured from the head, which just moved
        if RefreshCreatorCamPreset then RefreshCreatorCamPreset() end
        return fpDbg("face_pick height", v, scale)
    end

    ------------------------------------------------------------------ stage 2
    local cat <const> = data and data.cat

    -- component hair: OpenHairSelectionMenu, tags "component" / "color" / "remove"
    if role == "hair_style" or role == "hair_color" or role == "hair_remove" then
        if type(cat) ~= "string" then return end
        local tbl <const> = fpHairTable(cat)
        if not tbl or #tbl == 0 then return end
        fpSeedHair(cat, tbl)

        if role == "hair_remove" then
            IsPedReadyToRender(ped)
            RemoveTagFromMetaPed(Config.ComponentCategories[cat])
            UpdatePedVariation(ped)
            if cat == "Bow" then PlayerClothing[cat].comp = -1 else PlayerSkin[cat] = -1 end
            HairColorIndexTracker[cat] = 1
            HairIndexTracker[cat] = 1
            if IsInClothingStore then
                if TotalAmountToPay then TotalAmountToPay[cat] = 0 end
                if CachedComponents[cat] then CachedComponents[cat].comp = -1 end
            end
            SendNUIMessage({ type = "items", items = fpItems() })
            fpPushPrice()
            return fpDbg("face_pick hair_remove", cat)
        end

        if role == "hair_style" then
            if v < 1 or v > #tbl then return end
            local shades <const> = tbl[v]
            local ci = HairColorIndexTracker[cat] or 1
            if ci > #shades then ci = #shades end -- a style with fewer shades
            HairIndexTracker[cat] = v
            HairColorIndexTracker[cat] = ci
            local comp <const> = shades[ci]
            if cat == "Bow" then PlayerClothing[cat].comp = comp else PlayerSkin[cat] = comp end
            IsPedReadyToRender(ped)
            ApplyShopItemToPed(comp)
            UpdatePedVariation(ped)
            SendNUIMessage({ type = "items", items = fpItems() })
            return fpDbg("face_pick hair_style", cat, v)
        end

        local shades <const> = tbl[HairIndexTracker[cat] or 1]
        if not shades or v < 1 or v > #shades then return end
        local comp <const> = shades[v]
        IsPedReadyToRender(ped)
        ApplyShopItemToPed(comp)
        UpdatePedVariation(ped)
        if cat == "Bow" then PlayerClothing[cat].comp = comp else PlayerSkin[cat] = comp end
        HairColorIndexTracker[cat] = v
        return fpDbg("face_pick hair_color", cat, v)
    end

    -- overlays: OpenBeardEyebrowMenu / OpenMakeupMenu
    if role == "ovl_type" or role == "ovl_color" or role == "ovl_opacity" or role == "ovl_remove" then
        local d <const> = overlayLookup and overlayLookup[cat]
        if not d then return end
        local function paint()
            ApplyOverlay(cat, PlayerSkin[cat .. "_visibility"], PlayerSkin[d.txt_id], 1, 0, 0, 1.0,
                0, 1, PlayerSkin[d.color], 0, 0, 1, PlayerSkin[d.opacity], PlayerSkin.albedo)
        end

        if role == "ovl_remove" then
            PlayerSkin[d.txt_id] = 0
            PlayerSkin[d.color] = 0
            PlayerSkin[d.opacity] = 0
            PlayerSkin[cat .. "_visibility"] = 0
            MakeupColorIndexTracker[cat] = 0
            MakeupIndexTracker[cat] = 0
            MakeupOpacityTracker[cat] = 0
            paint()
            if IsInClothingStore then
                if TotalAmountToPay then TotalAmountToPay[cat] = 0 end
                if CachedComponents[cat] then CachedComponents[cat].comp = -1 end
            end
            SendNUIMessage({ type = "items", items = fpItems() })
            fpPushPrice()
            return fpDbg("face_pick ovl_remove", cat)
        end

        if role == "ovl_type" then
            local textures <const> = Config.overlays_info and Config.overlays_info[cat]
            if not textures or v < 0 or v > #textures then return end
            PlayerSkin[cat .. "_visibility"] = 1
            PlayerSkin[d.opacity] = PlayerSkin[d.opacity] or 1.0
            MakeupIndexTracker[cat] = v
            PlayerSkin[d.txt_id] = v
            paint()
            return fpDbg("face_pick ovl_type", cat, v)
        end

        if role == "ovl_color" then
            local palette <const> = Config.color_palettes and Config.color_palettes[cat]
            if not palette or v < 0 or v > #palette then return end
            MakeupColorIndexTracker[cat] = v
            PlayerSkin[d.color] = palette[v]
            paint()
            return fpDbg("face_pick ovl_color", cat, v)
        end

        if v < 0 or v > 10 then return end
        -- menu.lua gates visibility on > 0.2 of the 0..10 row, not on > 0
        PlayerSkin[cat .. "_visibility"] = (v > 0.2) and 1 or 0
        MakeupOpacityTracker[cat] = v
        PlayerSkin[d.opacity] = v / 10
        if IsInClothingStore and TotalAmountToPay then
            TotalAmountToPay[cat] = (v > 0.2)
                and ((Config.Shops.prices.hair[cat] and Config.Shops.prices.hair[cat].price) or 0) or 0
        end
        paint()
        fpPushPrice()
        return fpDbg("face_pick ovl_opacity", cat, v)
    end

    fpDbg("face_pick unknown role", tostring(role))
end)

-- Head / Torso / Full framing, so you can see what you are editing without flying the camera there by hand
RegisterNUICallback('face_cam', function(data, cb)
    cb('ok')
    if not fpOpen then return end
    if not SetCreatorCamPreset then return fpDbg("face_cam: no preset api") end
    local ok <const> = SetCreatorCamPreset(data and data.preset)
    fpDbg("face_cam", tostring(data and data.preset), "ok=" .. tostring(ok))
end)

RegisterNUICallback('face_teeth', function(data, cb)
    cb('ok')
    if not fpOpen then return end
    local v = math.floor(tonumber(data.value) or 0)
    if v < 0 or v > #Config.Teeth then return end
    IsPedReadyToRender()
    if v > 0 then
        StartAnimation("Face_Dentistry_Loop")
        local g = GetGender() == "Male" and "M" or "F"
        PlayerClothing.Teeth.comp = joaat(Config.Teeth[v]:format(g))
        ApplyShopItemToPed(PlayerClothing.Teeth.comp)
        TheethIndexTracker = v
        if TotalAmountToPay then TotalAmountToPay.Teeth = fpFacePrice("Teeth") end
    else
        PlayerClothing.Teeth.comp = -1
        RemoveTagFromMetaPed(Config.ComponentCategories.Teeth)
        StartAnimation("Face_Dentistry_Out")
        TheethIndexTracker = 0
        if TotalAmountToPay then TotalAmountToPay.Teeth = 0 end
    end
    UpdatePedVariation()
    fpPushPrice()
end)

RegisterNUICallback('face_close', function(_, cb)
    cb('ok')
    if not fpOpen then return end
    fpClose()
    -- in one-UI mode OpenAppearanceMenu re-opens THIS page
    local oneUI <const> = Config.FacePage.oneUI ~= false and Config.FacePage.enabled
        and ((IsInCharCreation and not IsInClothingStore) or ShopType == "secondchance")
    if oneUI then
        OpenCharCreationMenu(fpTable, fpValue)
    elseif IsInCharCreation or ShopType == "secondchance" then
        OpenAppearanceMenu(fpTable, fpValue)
    else
        BackFromMenu(fpValue)
    end
end)

-- face SHOP only: pay for what changed, then leave (ink confirm button logic)
RegisterNUICallback('face_confirm', function(_, cb)
    cb('ok')
    if not fpOpen or not fpIsShop() then return end
    if GetCurrentAmmountToPay() > 0 then
        local NewTable = GetNewCompOldStructure(PlayerClothing)
        local result = Core.Callback.TriggerAwait("vorp_character:callback:PayToShop",
            { skin = PlayerSkin, comps = NewTable, amount = GetCurrentAmmountToPay() })
        if result then
            CachedSkin = PlayerSkin
            UpdateCache(NewTable)
        end
    end
    fpClose()
    BackFromMenu(fpValue)
end)

-- /hud "Menus: Left / Right" - this page follows it like the others
AddEventHandler('pup-ui:menuSide', function(side)
    SendNUIMessage({ type = "menuSide", side = (side == "right") and "right" or "left" })
end)
CreateThread(function()
    Wait(1500)
    TriggerEvent('fred_hud:reapplyLayout')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if fpOpen then
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end)
