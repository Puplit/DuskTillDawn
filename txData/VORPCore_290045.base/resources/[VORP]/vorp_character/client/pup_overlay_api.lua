-- Modified by Puppet (Dusk Till Dawn), 2026
-- Face overlay API (eyebrows, beard stubble) for the barbershop; the overlays live inside this resource

-- the two overlay categories a barber can reasonably sell
local OVERLAYS = {
    eyebrows = {
        tx      = 'eyebrows_tx_id',
        colour  = 'eyebrows_color',
        opacity = 'eyebrows_opacity',
        vis     = 'eyebrows_visibility',
    },
    beardstabble = {
        tx      = 'beardstabble_tx_id',
        colour  = 'beardstabble_color_primary',
        opacity = 'beardstabble_opacity',
        vis     = 'beardstabble_visibility',
    },
}

local function clamp(n, lo, hi)
    n = tonumber(n) or lo
    if n < lo then return lo end
    if n > hi then return hi end
    return math.floor(n)
end

local function styleCount(category)
    local t = Config.overlays_info[category]
    return t and #t or 0
end

local function colourCount(category)
    local t = Config.color_palettes[category]
    return t and #t or 0
end

-- where does a stored palette value sit in the colour list?
local function colourIndexOf(category, value)
    local list = Config.color_palettes[category] or {}
    for i = 1, #list do
        if list[i] == value then return i end
    end
    return 1
end

-- what the barbershop needs to build its sliders, plus the raw saved fields the player wears now
exports('OverlayRaw', function(category)
    local map = OVERLAYS[category]
    if not map then return nil end
    local s = CachedSkin or {}
    return {
        visibility = tonumber(s[map.vis]) or 0,
        tx_id      = tonumber(s[map.tx]) or 0,
        colour     = tonumber(s[map.colour]) or 0,
        opacity    = tonumber(s[map.opacity]) or 1.0,
    }
end)

exports('OverlayInfo', function(category)
    local map = OVERLAYS[category]
    if not map then return nil end
    local styles, colours = styleCount(category), colourCount(category)
    if styles == 0 or colours == 0 then return nil end
    return {
        styles  = styles,
        colours = colours,
        txId    = clamp(CachedSkin[map.tx] or 0, 0, styles),
        colour  = colourIndexOf(category, CachedSkin[map.colour] or 0),
        opacity = tonumber(CachedSkin[map.opacity]) or 0.0,
        visible = (tonumber(CachedSkin[map.vis]) or 0) ~= 0,
    }
end)

-- live preview. txId 0 = the overlay is off
exports('OverlayApply', function(category, txId, colourIndex, opacity)
    local map = OVERLAYS[category]
    if not map then return false end
    local styles, colours = styleCount(category), colourCount(category)
    if styles == 0 or colours == 0 then return false end

    txId = clamp(txId, 0, styles)
    local colourValue = Config.color_palettes[category][clamp(colourIndex, 1, colours)]
    opacity = tonumber(opacity) or 1.0

    if txId == 0 then
        -- ApplyOverlay skips every field when visibility is 0
        ApplyOverlay(category, 0, 0, 1, 0, 0, 1.0, 0, 1, colourValue, 0, 0, 1, 0, CachedSkin.albedo or 0)
        return true
    end

    ApplyOverlay(category, 1, txId, 1, 0, 0, 1.0, 0, 1, colourValue, 0, 0, 1, opacity, CachedSkin.albedo or 0)
    return true
end)

-- put the ped back to whatever is cached (barbershop cancel / ESC)
exports('OverlayRestore', function(category)
    local map = OVERLAYS[category]
    if not map then return false end
    local styles = styleCount(category)
    if styles == 0 then return false end

    local txId = clamp(CachedSkin[map.tx] or 0, 0, styles)
    local vis  = (tonumber(CachedSkin[map.vis]) or 0)
    ApplyOverlay(category, vis, txId, 1, 0, 0, 1.0, 0, 1,
        CachedSkin[map.colour] or 0, 0, 0, 1, tonumber(CachedSkin[map.opacity]) or 0, CachedSkin.albedo or 0)
    return true
end)

-- the skin fields the server has to save for this look
exports('OverlayPayload', function(category, txId, colourIndex, opacity)
    local map = OVERLAYS[category]
    if not map then return {} end
    local styles, colours = styleCount(category), colourCount(category)
    if styles == 0 or colours == 0 then return {} end

    txId = clamp(txId, 0, styles)
    local out = {}
    if txId == 0 then
        out[map.vis]     = 0
        out[map.tx]      = 0
        out[map.colour]  = 0
        out[map.opacity] = 0
    else
        out[map.vis]     = 1
        out[map.tx]      = txId
        out[map.colour]  = Config.color_palettes[category][clamp(colourIndex, 1, colours)]
        out[map.opacity] = tonumber(opacity) or 1.0
    end
    return out
end)
