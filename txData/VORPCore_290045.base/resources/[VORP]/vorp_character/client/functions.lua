-- Modified by Puppet (Dusk Till Dawn), 2026
--CREATOR
function RemoveImaps()
    if IsIplActiveByHash(183712523) then
        RequestIplByHash(183712523)
    end

    if IsIplActiveByHash(-1699673416) then
        RequestIplByHash(-1699673416)
    end

    if IsIplActiveByHash(1679934574) then
        RequestIplByHash(1679934574)
    end
end

-- several RDR2 interior natives answer with a number, and 0 is truthy in Lua,
-- so every read of one goes through here rather than being tested directly
function NativeOn(v)
    return v == true or v == 1
end

function IplActive(h)
    return NativeOn(IsIplActiveByHash(h))
end

-- requested unconditionally: an already-active IPL is a no-op, so never guard these
function RequestImapCreator()
    for _, h in ipairs({ 183712523, -1699673416, 1679934574 }) do
        RequestIplByHash(h)
        pcall(function() RequestImap(h) end)
    end
end

function LoadPlayer(sex)
    if not HasModelLoaded(sex) then
        RequestModel(sex, false)
        -- BOUNDED: a model that never arrives must not spin here forever.
        local t0 <const> = GetGameTimer()
        repeat Wait(0) until HasModelLoaded(sex) or GetGameTimer() - t0 > 20000
        if not HasModelLoaded(sex) then
            print(("^1[vorp_character]^7 player model %s never loaded"):format(tostring(sex)))
            return false
        end
    end
    return true
end

TableHair = {}
function GetHair(gender, category)
    TableHair = {}
    for key, value in ipairs(HairComponents[gender][category]) do
        for k, v in ipairs(value) do
            if not TableHair[key] then
                TableHair[key] = {}
            end
            if TableHair[key] then
                TableHair[key][k] = v.hash
            end
        end
    end
    return TableHair
end

function GetHairIndex(category, tablehair)
    for key, value in pairs(CachedSkin) do
        for hairIndex, val in ipairs(tablehair) do
            for colorIndex, v in ipairs(val) do
                if key == category then
                    if v == value then
                        return hairIndex, colorIndex
                    end
                end
            end
        end
    end
    return 1, 1
end

function StartAnimation(anim)
    local __player = PlayerPedId()
    local isMale = IsPedMale(__player)
    local animDict = isMale and "FACE_HUMAN@GEN_MALE@BASE" or "FACE_HUMAN@GEN_FEMALE@BASE"

    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        local t0 <const> = GetGameTimer()
        repeat Wait(0) until HasAnimDictLoaded(animDict) or GetGameTimer() - t0 > 10000
        if not HasAnimDictLoaded(animDict) then return end
    end

    if not IsEntityPlayingAnim(__player, animDict, anim, 1) then
        TaskPlayAnim(__player, animDict, anim, 8.0, -8.0, -1, 16, 0.0, false, 0, false, "", false)
    end
end

function GetGender()
    local Gender = IsPedMale(PlayerPedId()) and "Male" or "Female"
    return Gender
end

local textureId = -1

function ApplyOverlay(name, visibility, tx_id, tx_normal, tx_material, tx_color_type, tx_opacity, tx_unk, palette_id, palette_color_primary, palette_color_secondary, palette_color_tertiary, var, opacity, albedo)
    for k, v in pairs(Config.overlay_all_layers) do
        if v.name == name then
            v.visibility = visibility
            if visibility ~= 0 then
                v.tx_normal = tx_normal
                v.tx_material = tx_material
                v.tx_color_type = tx_color_type
                v.tx_opacity = tx_opacity
                v.tx_unk = tx_unk
                if tx_color_type == 0 then
                    v.palette = Config.color_palettes[name][palette_id]
                    v.palette_color_primary = palette_color_primary
                    v.palette_color_secondary = palette_color_secondary
                    v.palette_color_tertiary = palette_color_tertiary
                end
                if name == "shadows" or name == "eyeliners" or name == "lipsticks" then
                    v.var = var
                    if tx_id ~= 0 then
                        v.tx_id = Config.overlays_info[name][1].id
                    end
                else
                    v.var = 0
                    if tx_id ~= 0 then
                        v.tx_id = Config.overlays_info[name][tx_id].id
                    end
                end
                v.opacity = opacity
            end
        end
    end

    local ped = PlayerPedId()
    local gender = GetGender()
    local current_texture_settings = Config.texture_types[gender]

    if textureId ~= -1 then
        Citizen.InvokeNative(0xB63B9178D0F58D82, textureId)
        Citizen.InvokeNative(0x6BEFAA907B076859, textureId)
    end

    if albedo == 0 then
        albedo = CachedSkin.albedo ~= 0 and CachedSkin.albedo or current_texture_settings.albedo
    end

    textureId = Citizen.InvokeNative(0xC5E7204F322E49EB, albedo, current_texture_settings.normal, current_texture_settings.material)


    for k, v in pairs(Config.overlay_all_layers) do
        if v.visibility ~= 0 then
            local overlay_id = Citizen.InvokeNative(0x86BB5FF45F193A02, textureId, v.tx_id, v.tx_normal, v.tx_material, v.tx_color_type, v.tx_opacity, v.tx_unk)
            if v.tx_color_type == 0 then
                Citizen.InvokeNative(0x1ED8588524AC9BE1, textureId, overlay_id, v.palette)
                Citizen.InvokeNative(0x2DF59FFE6FFD6044, textureId, overlay_id, v.palette_color_primary, v.palette_color_secondary, v.palette_color_tertiary)
            end

            Citizen.InvokeNative(0x3329AAE2882FC8E4, textureId, overlay_id, v.var);
            Citizen.InvokeNative(0x6C76BC24F8BB709A, textureId, overlay_id, v.opacity);
        end
    end

    -- bounded, same as StartOverlay - an invalid texture must not hang this thread forever with nothing printed
    local deadline = GetGameTimer() + 5000
    while not Citizen.InvokeNative(0x31DC8D3F216D8509, textureId) and GetGameTimer() < deadline do
        Citizen.Wait(0)
    end
    if not Citizen.InvokeNative(0x31DC8D3F216D8509, textureId) then
        print(("^1[vorp_character]^7 overlay texture %s never became valid after 5s - '%s' not applied")
            :format(tostring(textureId), tostring(name)))
        return false
    end

    Citizen.InvokeNative(0x92DAABA2C1C10B0E, textureId)
    Citizen.InvokeNative(0x0B46E25761519058, ped, joaat("heads"), textureId)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

local function CreatePedAtCoords(model, coords)
    RequestModel(model, false)
    -- BOUNDED: a model or ped that never arrives must not hang the creator.
    local t0 <const> = GetGameTimer()
    repeat Wait(0) until HasModelLoaded(model) or GetGameTimer() - t0 > 20000
    if not HasModelLoaded(model) then
        print(("^1[vorp_character]^7 creator ped model %s never loaded"):format(tostring(model)))
        return nil
    end
    local handle = CreatePed(model, coords.x, coords.y, coords.z, 0.0, false, false, false, false)
    local t1 <const> = GetGameTimer()
    repeat Wait(0) until DoesEntityExist(handle) or GetGameTimer() - t1 > 5000
    SetModelAsNoLongerNeeded(model)
    return handle
end

function SetupAnimscene()
    local Male_MP = CreatePedAtCoords(`MP_MALE`, vector4(0.0, 0.0, 0.0, 0.0))
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, Male_MP, 3, true)
    local Female_MP = CreatePedAtCoords(`MP_FEMALE`, vector4(0.0, 0.0, 0.0, 0.0))
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, Female_MP, 3, true)

    local Sheriff = CreatePedAtCoords(`MP_U_M_O_BlWPoliceChief_01`, vector4(0.0, 0.0, 0.0, 0.0))
    Citizen.InvokeNative(0x283978A15512B2FE, Sheriff, true)
    AddEntityToAudioMixGroup(Sheriff, "rdro_character_creator_guard_group", 0.0)
    SetPedConfigFlag(Sheriff, 130, true)
    SetPedConfigFlag(Sheriff, 301, true)
    SetPedConfigFlag(Sheriff, 315, true)
    FreezeEntityPosition(Sheriff, true)

    local Deputy = CreatePedAtCoords(`CS_MP_MARSHALL_DAVIES`, vector4(0.0, 0.0, 0.0, 0.0))
    Citizen.InvokeNative(0x283978A15512B2FE, Deputy, true)
    AddEntityToAudioMixGroup(Deputy, "rdro_character_creator_guard_group", 0.0)
    SetPedConfigFlag(Deputy, 130, true)
    SetPedConfigFlag(Deputy, 301, true)
    SetPedConfigFlag(Deputy, 315, true)
    GiveWeaponToPed_2(Deputy, `WEAPON_REPEATER_CARBINE`, 100, true, false, 0, false, 0.5, 1.0, 752097756, false, 0.0,  false)
    FreezeEntityPosition(Deputy, true)

    local animscene = CreateAnimScene("script@mp@character_creator@transitions", 0.25, "pl_intro", false, true)
    SetAnimSceneEntity(animscene, "Male_MP", Male_MP, 0)
    SetAnimSceneEntity(animscene, "Female_MP", Female_MP, 0)
    SetAnimSceneEntity(animscene, "Sheriff", Sheriff, 0)
    SetAnimSceneEntity(animscene, "Deputy", Deputy, 0)

    return animscene, { Male_MP, Female_MP, Sheriff, Deputy }
end

-- Male_MP / Female_MP are GLOBALS with no cleanup
function ClearSelectionPeds()
    for _, old in ipairs({ Male_MP, Female_MP }) do
        if old and old ~= 0 and DoesEntityExist(old) then
            SetEntityAsMissionEntity(old, true, true)
            DeleteEntity(old)
        end
    end
    Male_MP, Female_MP = nil, nil
end

function SelectionPeds()
    ClearSelectionPeds()

    local fModel = "MP_FEMALE"
    local mModel = "MP_MALE"

    -- placed from the creator scene when one is configured
    local mSpot, fSpot
    if CreatorScenePeds then mSpot, fSpot = CreatorScenePeds() end
    mSpot = mSpot or { x = -558.52, y = -3775.6,  z = 237.7, heading = 93.2 }
    fSpot = fSpot or { x = -558.43, y = -3776.65, z = 237.7, heading = 93.2 }

    LoadPlayer(fModel)
    Female_MP = CreatePed(joaat(fModel), fSpot.x, fSpot.y, fSpot.z, fSpot.heading, false, true, true, true)
    -- freshly-created metapeds have NO outfit and render INVISIBLE
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, Female_MP, 3, true) -- _SET_PED_OUTFIT_PRESET
    TaskStandStill(Female_MP, -1)
    SetEntityInvincible(Female_MP, true)
    SetEntityVisible(Female_MP, true)
    -- frozen: with no floor under them they drop out of the world before the player
    -- has picked anything. Setup() releases whichever one is chosen before it walks.
    FreezeEntityPosition(Female_MP, true)
    SetModelAsNoLongerNeeded(fModel)

    LoadPlayer(mModel)
    Male_MP = CreatePed(joaat(mModel), mSpot.x, mSpot.y, mSpot.z, mSpot.heading, false, true, true, true)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, Male_MP, 3, true) -- _SET_PED_OUTFIT_PRESET
    TaskStandStill(Male_MP, -1)
    SetEntityInvincible(Male_MP, true)
    SetEntityVisible(Male_MP, true)
    FreezeEntityPosition(Male_MP, true)
    SetModelAsNoLongerNeeded(mModel)

    return { Male_MP, Female_MP }
end

function SetupScenes(string)
    local animscene = CreateAnimScene("script@mp@character_creator@transitions", 0.25, string, false, true)
    SetAnimSceneEntity(animscene, GetGender() .. "_MP", PlayerPedId(), 0)
    LoadAnimScene(animscene)
    while not Citizen.InvokeNative(0x477122B8D05E7968, animscene) do
        Citizen.Wait(0)
    end
    return animscene
end

Config.Intro = {
    views = {
        {
            pos = vector3(-561.47, -3775.67, 239.16),
            rot = vector3(-9.35, 0.0, -90.05),
            fov = 35.0,
            focus = 4.0
        },
        {
            pos = vector3(-561.51, -3776.89, 239.15),
            rot = vector3(-9.65, 0.0, -90.33),
            fov = 35.0,
            focus = 4.0
        }
    }
}


function TakePhoto()
    N_0x3c8f74e8fe751614()
    Citizen.InvokeNative(0xD45547D8396F002A)
    Citizen.InvokeNative(0xA15BFFC0A01B34E1)
    Citizen.InvokeNative(0xFA91736933AB3D93, true)
    Citizen.InvokeNative(0x8B3296278328B5EB, 2)
    Citizen.InvokeNative(0x2705D18C11B61046, false)
    Citizen.InvokeNative(0xD1031B83AC093BC7, "SetRegionPhotoTakenStat")
    Citizen.InvokeNative(0x9937FACBBF267244, "SetDistrictPhotoTakenStat")
    Citizen.InvokeNative(0x8952E857696B8A79, "SetStatePhotoTakenStat")
    Citizen.InvokeNative(0x57639FD876B68A91, 0)
end

function DrawText3D(x, y, z, text, color)
    local r, g, b, a = 255, 255, 255, 255
    if color then
        r, g, b, a = table.unpack(color)
    end
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    local str = VarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    if onScreen then
        SetTextScale(0.4, 0.4)
        SetTextFontForCurrentCommand(25) -- font style
        SetTextColor(r, g, b, a)
        SetTextCentre(1)
        DisplayText(str, _x, _y)
        local factor = (string.len(text)) / 100 -- draw sprite size
        DrawSprite("feeds", "toast_bg", _x, _y + 0.0125, 0.015 + factor, 0.03, 0.1, 0, 0, 0, 200, false)
    end
end

function ShowBusyspinnerWithText(text)
    N_0x7f78cd75cc4539e4(VarString(10, "LITERAL_STRING", text))
end

function GetName(Result)
    local splitString = {}
    for i in string.gmatch(Result, "%S+") do
        splitString[#splitString + 1] = i
    end

    if #splitString < 2 then
        return false
    end

    for _, word in ipairs(Config.Creator.bannedNames) do
        if string.find(splitString[1], word) or string.find(splitString[2], word) then
            return nil
        end
    end

    return splitString[1], splitString[2]
end

function ApplyDefaultClothing()
    local ped = PlayerPedId()
    local isPedMale = IsPedMale(ped)

    local numComponents = GetNumComponentsInPed(ped)
    local componentsWithWearableState = {}
    for componentIndex = 0, numComponents - 1, 1 do
        local componentHash = GetComponentAtIndex(ped, componentIndex, true)
        if componentHash ~= 0 then
            local numWearableStates = Citizen.InvokeNative(0xFFCC2DB2D9953401, componentHash, not isPedMale, true, Citizen.ResultAsInteger())
            if numWearableStates > 0 then
                local wearableStates = { `base` }
                for wearableStateIndex = 0, numWearableStates - 1, 1 do
                    local wearableState = Citizen.InvokeNative(0x6243635AF2F1B826, componentHash, wearableStateIndex, not isPedMale, true, Citizen.ResultAsInteger())
                    if wearableState ~= 0 then
                        table.insert(wearableStates, wearableState)
                    end
                end

                table.insert(componentsWithWearableState,
                    {
                        componentHash = componentHash,
                        componentCategory = GetCategoryOfComponentAtIndex(ped, componentIndex),
                        wearableStates = wearableStates
                    })
            end
        end
    end

    if #componentsWithWearableState < 1 then
        return print("no components with wearable state")
    end

    local Helper = {
        Pant = `pants`,
        Shirt = `shirts_full`,
        Boots = `boots`,
        Gunbelt = `gunbelts`,
        Holster = `holsters_left`,
        Belt = `belts`,
        Hair = `hair`,
        Eyebrows = `eyebrows`,
        Belts = `belts`,
    }

    for category, _ in pairs(PlayerClothing) do
        for _, component in ipairs(componentsWithWearableState) do
            if Helper[category] and Helper[category] == component.componentCategory then
                PlayerClothing[category].comp = component.componentHash

                if CachedComponents[category] then
                    CachedComponents[category] = { comp = component.componentHash }
                else
                    CachedComponents[category] = {}
                    CachedComponents[category] = { comp = component.componentHash }
                end

                if not PlayerTrackingData[category] then
                    PlayerTrackingData[category] = {}
                    PlayerTrackingData[category][component.componentHash] = { tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 }
                end
            end
        end
    end

    CachedComponents.Gunbelt = { comp = isPedMale and 795591403 or 1511461630, tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 }
end

function SortData(data)
    local sortedCategories = {}
    for category, _ in pairs(data) do
        table.insert(sortedCategories, category)
    end
    table.sort(sortedCategories)
    return sortedCategories
end

function SetCamFocusDistance(cam, focus)
    N_0x11f32bb61b756732(cam, focus)
end

function PrepareCreatorMusic()
    Citizen.InvokeNative(0x120C48C614909FA4, "AZL_RDRO_Character_Creation_Area", true)                     -- CLEAR_AMBIENT_ZONE_LIST_STATE
    Citizen.InvokeNative(0x9D5A25BADB742ACD, "AZL_RDRO_Character_Creation_Area_Other_Zones_Disable", true) -- CLEAR_AMBIENT_ZONE_LIST_STATE
    PrepareMusicEvent("MP_CHARACTER_CREATION_START")
    Wait(100)
    TriggerMusicEvent("MP_CHARACTER_CREATION_START")
end

function DrawLight(shop)
    local locationx = shop and shop.x or -560.1646
    local locationy = shop and shop.y or -3782.066
    local locationz = shop and shop.z or 238.5975
    while IsInCharCreation or IsInClothingStore do
        Wait(0)
        FreezeEntityPosition(PlayerPedId(), false)
        DrawLightWithRange(locationx, locationy, locationz, 250, 250, 250, 7.0, 50.0)
    end
end

--- organise and included data for clothing table
function OrganiseClothingData(Gender)
    Clothing = {}
    for category, value in pairs(Data.clothing[Gender]) do
        local categoryTable = {}

        for _, v in ipairs(value) do
            local typeTable = {}
            for _, va in ipairs(v) do
                table.insert(typeTable,
                    { hex = va.hash, remove = va.remove, showSkin = va.showSkin or false, needsFix = va.needsFix or false })
            end
            table.insert(categoryTable, typeTable)
        end
        Clothing[category] = categoryTable
    end
    return Clothing
end

--- update cachedComponents for creator
function UpdateCache(newcomponents)
    for key, value in pairs(newcomponents) do
        if key == "colors" then
            -- dyed-outfit colours travel with the comps; kept as-is
            if type(value) == 'table' and next(value) then CachedComponents.colors = value end
        elseif type(value) == 'table' then
            CachedComponents[key] = {
                comp = value.comp,
                tint0 = value.tint0 or 0,
                tint1 = value.tint1 or 0,
                tint2 = value.tint2 or 0,
                palette = value.palette or 0,
            }
        else
            CachedComponents[key] = {
                comp = value,
                tint0 = 0,
                tint1 = 0,
                tint2 = 0,
                palette = 0,
            }
        end
    end
    return CachedComponents
end

--- get old table structure from the new
function GetNewCompOldStructure(comps)
    local NewComps = {}
    for key, value in pairs(comps) do
        if key == "colors" then
            NewComps.colors = value -- saved with compPlayer so they survive relog
        else
            NewComps[key] = value.comp
        end
    end
    return NewComps
end

--- update CachedComponents with whatever the player have bought
function AssertCachedComponents()
    for category, value in pairs(PlayerTrackingData) do
        for component, v in pairs(value) do
            if not CachedComponents[category] then
                CachedComponents[category] = {}
            end
            CachedComponents[category] = {
                comp = component,
                tint0 = v.tint0,
                tint1 = v.tint1,
                tint2 = v.tint2,
                palette = v.palette,
                index = v.index,
                color = v.color
            }
        end
    end
end

function RegisterBodyIndexs(skin)
    local gender = GetGender() == "Male" and "M" or "F"

    for skinColor, v in ipairs(Config.DefaultChar) do
        --for skinColor, v in ipairs(value) do
        for bodyIndex, a in ipairs(v.Body) do
            if skin.BodyType == joaat(a:format(gender)) then
                BodyTypeTracker = bodyIndex
                SkinColorTracker = skinColor
                break
            end
        end

        for legIndex, j in ipairs(v.Legs) do
            if skin.Legs == joaat(j:format(gender)) then
                LegsTypeTracker = legIndex
                break
            end
        end

        for index, d in ipairs(HeadsFor(v, gender)) do
            if skin.HeadType == joaat(d:format(gender)) then
                HeadIndexTracker = index
                break
            end
        end
        -- end
    end

    for key, value in pairs(Config.BodyType.Body) do
        if skin.Body == value then
            BodyTracker = key
            break
        end
    end

    for key, value in pairs(Config.BodyType.Waist) do
        if skin.Waist == value then
            WaistTracker = key
            break
        end
    end

    if WaistTracker == 0 then
        WaistTracker = 1
    end

    if BodyTracker == 0 then
        BodyTracker = 1
    end

    if BodyTypeTracker == 0 then
        BodyTypeTracker = 1
    end

    if SkinColorTracker == 0 then
        SkinColorTracker = 1
    end
end

function SetCachedSkin()
    for k, v in pairs(CachedSkin) do
        if PlayerSkin[k] then
            PlayerSkin[k] = v
        end
    end
end

-- exports
exports('GetPlayerComponent', function(category)
    if not category then
        print("must provide a category")
        return nil
    end

    if not PlayerClothing[category] then
        print("category does not exist")
        return nil
    end

    if not CachedComponents[category] then
        return nil
    end

    return CachedComponents[category]
end)

exports('GetAllPlayerComponents', function()
    return CachedComponents
end)

-- the body is a component: pulling a garment tag off without re-applying the skin
-- leaves a floating head and hands, so call this after anything that undresses
local function liveSkin()
    local function ok(s)
        return type(s) == 'table' and ((s.BodyType or 0) ~= 0 or (s.LegsType or 0) ~= 0)
    end
    -- PlayerSkin only wins while the creator or a shop owns the ped; outside
    -- those it can still hold the last character built, so the saved skin wins
    if (IsInCharCreation or IsInClothingStore) and ok(PlayerSkin) then return PlayerSkin end
    if ok(CachedSkin) then return CachedSkin end
    if ok(PlayerSkin) then return PlayerSkin end
    return nil
end

function EnsureBodySkin(ped)
    ped = ped or PlayerPedId()
    local skin = liveSkin()
    if not skin then return end

    local function put(hash)
        if hash and hash ~= 0 and hash ~= -1 then ApplyShopItemToPed(hash, ped) end
    end
    put(skin.BodyType)
    put(skin.LegsType)
    UpdatePedVariation(ped)
end
