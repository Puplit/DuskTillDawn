-- Modified by Puppet (Dusk Till Dawn), 2026
-- hair tint, stored on the skin as hair_palette / hair_tint0..2.
-- the category key is lower-case `hair`: "Hair" silently returns nil.

-- known hair palettes, most-used first; -541985204 is the game's own hair palette
HAIR_TINT_PALETTES = {
    -541985204,
    -76459397, -1698476236, -1436165981, -183908539, -783849117,
    1090645383, 1669565057, -1543234321, -1251868068, -1529893936,
    864404955, 1064202495, -113397560, 399232131, 17129595,
}

HAIR_TINT_MAX = 255

local function hairTag(ped)
    local ok, data = pcall(function() return GetMetaPedData("hair", ped or PlayerPedId()) end)
    if not ok or not data or not data.drawable then return nil end
    return data
end

-- paint the hair currently on the ped
function SetHairTint(ped, palette, t0, t1, t2)
    ped = ped or PlayerPedId()
    local tag = hairTag(ped)
    if not tag then return false end
    IsPedReadyToRender(ped)
    SetMetaPedTag(ped, tag.drawable, tag.albedo, tag.normal, tag.material,
        tonumber(palette) or tag.palette,
        tonumber(t0) or 0, tonumber(t1) or 0, tonumber(t2) or 0)
    UpdatePedVariation(ped)
    return true
end

-- drop back to the shade the component ships with: re-applying the component resets its tag to the asset default
function ClearHairTint(ped, hairHash)
    ped = ped or PlayerPedId()
    hairHash = hairHash or (CachedSkin and CachedSkin.Hair)
    if not hairHash or hairHash == 0 then return false end
    IsPedReadyToRender(ped)
    ApplyShopItemToPed(hairHash, ped)
    UpdatePedVariation(ped)
    return true
end

-- Apply a WHOLE tag: drawable + its texture set + palette/tints
function SetHairTag(ped, drawable, albedo, normal, material, palette, t0, t1, t2)
    ped = ped or PlayerPedId()
    drawable = tonumber(drawable) or 0
    if drawable == 0 then return false end
    IsPedReadyToRender(ped)
    SetMetaPedTag(ped, drawable,
        tonumber(albedo) or 0, tonumber(normal) or 0, tonumber(material) or 0,
        tonumber(palette) or 0,
        tonumber(t0) or 0, tonumber(t1) or 0, tonumber(t2) or 0)
    UpdatePedVariation(ped)
    return true
end

-- STORY-PED BEARDS. The catalogue beard is a shop item; a story beard is a tag.
-- The slot must be cleared first or the old beard stays on under the new one.
BEARD_SLOT_HASH = {
    [1] = 0xF8016BCA,   -- Beard (full)
    [2] = 366200818,    -- Chin
    [3] = -1229572297,  -- Chops
    [4] = -322391462,   -- Moustache
}

function SetBeardTag(ped, slot, drawable, albedo, normal, material, palette, t0, t1, t2)
    ped = ped or PlayerPedId()
    drawable = tonumber(drawable) or 0
    if drawable == 0 then return false end
    IsPedReadyToRender(ped)
    local cat = BEARD_SLOT_HASH[tonumber(slot) or 1]
    if cat then Citizen.InvokeNative(0x59BD177A1A48600A, ped, cat) end
    SetMetaPedTag(ped, drawable,
        tonumber(albedo) or 0, tonumber(normal) or 0, tonumber(material) or 0,
        tonumber(palette) or 0,
        tonumber(t0) or 0, tonumber(t1) or 0, tonumber(t2) or 0)
    UpdatePedVariation(ped)
    return true
end

function ApplyBeardTag(ped, skin)
    if not skin then return end
    local drawable = tonumber(skin.beard_drawable) or 0
    if drawable == 0 then return end
    return SetBeardTag(ped, skin.beard_slot, drawable, skin.beard_albedo, skin.beard_normal,
        skin.beard_material, skin.beard_palette,
        skin.beard_tint0, skin.beard_tint1, skin.beard_tint2)
end

exports('BeardTagApply', function(slot, drawable, albedo, normal, material, palette, t0, t1, t2)
    return SetBeardTag(PlayerPedId(), slot, drawable, albedo, normal, material, palette, t0, t1, t2)
end)

-- clear a story beard back to nothing, so the catalogue beard can take over again
exports('BeardTagClear', function(slot)
    local cat = BEARD_SLOT_HASH[tonumber(slot) or 1]
    if not cat then return false end
    local ped <const> = PlayerPedId()
    IsPedReadyToRender(ped)
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, cat)
    UpdatePedVariation(ped)
    return true
end)

-- called from LoadAll on every spawn / character select
function ApplyHairTint(ped, skin)
    if not skin then return end

    -- A story-ped style: the component itself has to be rebuilt from the saved tag
    local drawable = tonumber(skin.hair_drawable) or 0
    if drawable ~= 0 then
        return SetHairTag(ped, drawable, skin.hair_albedo, skin.hair_normal,
            skin.hair_material, skin.hair_palette,
            skin.hair_tint0, skin.hair_tint1, skin.hair_tint2)
    end

    local palette = tonumber(skin.hair_palette) or 0
    if palette == 0 then return end   -- untinted: leave the component's own shade
    SetHairTint(ped, palette, skin.hair_tint0, skin.hair_tint1, skin.hair_tint2)
end

-- the barbershop lives in its own Lua state, so it drives the ped through this
exports('HairTagApply', function(drawable, albedo, normal, material, palette, t0, t1, t2)
    return SetHairTag(PlayerPedId(), drawable, albedo, normal, material, palette, t0, t1, t2)
end)

-- exports for the barbershop (separate Lua state)

-- what the barbershop needs to know: is a tint saved, and what is it?
exports('HairTintInfo', function()
    local saved = CachedSkin or {}
    local savedPal = tonumber(saved.hair_palette) or 0
    return {
        palette = savedPal,
        t0 = tonumber(saved.hair_tint0) or 0,
        t1 = tonumber(saved.hair_tint1) or 0,
        t2 = tonumber(saved.hair_tint2) or 0,
        tinted = savedPal ~= 0,
    }
end)

-- live preview from a raw palette hash + three slots
exports('HairTintApplyRaw', function(palette, t0, t1, t2)
    local pal = tonumber(palette) or 0
    if pal == 0 then return ClearHairTint(PlayerPedId(), CachedSkin and CachedSkin.Hair) end
    return SetHairTint(PlayerPedId(), pal, t0, t1, t2)
end)

-- back to the shade the chosen component ships with
exports('HairTintClear', function()
    return ClearHairTint(PlayerPedId(), CachedSkin and CachedSkin.Hair)
end)

-- put the ped back to the SAVED dye (barbershop cancel)
exports('HairTintRestore', function()
    local skin = CachedSkin or {}
    local palette = tonumber(skin.hair_palette) or 0
    if palette == 0 then return ClearHairTint(PlayerPedId(), skin.Hair) end
    return SetHairTint(PlayerPedId(), palette, skin.hair_tint0, skin.hair_tint1, skin.hair_tint2)
end)

-- /hairsee - where in the chain the colour is being lost
RegisterCommand('hairsee', function()
    local tag  = hairTag(PlayerPedId())
    local skin = CachedSkin or {}

    if not tag then
        print('^1[hairtint]^7 LIVE  = no hair tag on the ped (bald, or the component has not loaded yet)')
    else
        print(('^3[hairtint]^7 LIVE  drawable=%s palette=%s tint=%s/%s/%s')
            :format(tostring(tag.drawable), tostring(tag.palette),
                    tostring(tag.tint0), tostring(tag.tint1), tostring(tag.tint2)))
    end

    local savedPal = tonumber(skin.hair_palette) or 0
    print(('^3[hairtint]^7 SAVED Hair=%s palette=%s tint=%s/%s/%s  (tinted=%s)')
        :format(tostring(skin.Hair), tostring(savedPal),
                tostring(skin.hair_tint0), tostring(skin.hair_tint1), tostring(skin.hair_tint2),
                tostring(savedPal ~= 0)))

    if savedPal == 0 then
        print('^3[hairtint]^7 palette 0 = untinted. If you just picked a Tint entry and paid,')
        print('^3[hairtint]^7 the barbershop never wrote it - the bug is on the SAVE side.')
    elseif tag and tag.palette ~= savedPal then
        print('^1[hairtint]^7 LIVE and SAVED disagree - it saved fine but something')
        print('^1[hairtint]^7 re-applied the hair component and reset the tag. RENDER side.')
    elseif tag then
        print('^2[hairtint]^7 LIVE matches SAVED - the tint is applied correctly right now.')
    end
end, false)

-- skin fields for the server to save, shaped like the overlay payloads so the barbershop can merge them into one save
exports('HairTintPayloadRaw', function(palette, t0, t1, t2)
    local pal = tonumber(palette) or 0
    if pal == 0 then
        return { hair_palette = 0, hair_tint0 = 0, hair_tint1 = 0, hair_tint2 = 0 }
    end
    return {
        hair_palette = pal,
        hair_tint0   = tonumber(t0) or 0,
        hair_tint1   = tonumber(t1) or 0,
        hair_tint2   = tonumber(t2) or 0,
    }
end)
