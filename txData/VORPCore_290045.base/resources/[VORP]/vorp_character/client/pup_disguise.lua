-- Modified by Puppet (Dusk Till Dawn), 2026
-- DISGUISE BRIDGE (blood vials): wearing someone else's look by driving LoadPlayerComponents

local disguised = false
local baseSkin  = nil -- our own complete skin, captured before the first swap
local baseComps = nil -- and the clothes we were standing in at that moment

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- Rebuild the client's component structure from the two database columns
local function buildComps(flat, tints)
    local out = {}
    if type(flat) ~= "table" then return out end

    for k, comp in pairs(flat) do
        if k == "colors" then
            -- pristine dyes ride in compPlayer.colors (category -> color1/2/3/palette); LoadPlayerComponents applies them last
            if type(comp) == "table" and next(comp) then out.colors = comp end
        elseif type(comp) == "table" then
            out[k] = {
                comp    = comp.comp,
                tint0   = comp.tint0 or 0,
                tint1   = comp.tint1 or 0,
                tint2   = comp.tint2 or 0,
                palette = comp.palette or 0,
            }
        else
            -- compTints is nested by the worn hash: { Category = { ["<hash>"] = {tint0..} } }
            local byComp = type(tints) == "table" and tints[k] or nil
            local t = nil
            if type(byComp) == "table" then
                t = byComp[tostring(comp)] or (byComp.tint0 ~= nil and byComp) or nil
            end
            out[k] = {
                comp    = comp,
                tint0   = t and t.tint0 or 0,
                tint1   = t and t.tint1 or 0,
                tint2   = t and t.tint2 or 0,
                palette = t and t.palette or 0,
            }
        end
    end

    -- LoadComps dereferences these three by name after its pairs() loop
    for _, k in ipairs({ "Shirt", "Vest", "Boots" }) do
        if not out[k] then
            out[k] = { comp = -1, tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 }
        end
    end

    return out
end

-- Lay the target's skin over our own so every key LoadAll touches exists
local function mergeSkin(over)
    local out = copy(baseSkin) or {}
    if type(over) == "table" then
        for k, v in pairs(over) do out[k] = v end
    end
    return out
end

local function decode(str, fallback)
    if type(str) == "table" then return str end
    if type(str) ~= "string" or str == "" then return fallback end
    local ok, res = pcall(json.decode, str) -- json.decode THROWS on malformed
    if not ok or type(res) ~= "table" then return fallback end
    return res
end

local function snapshot()
    -- first swap of the session: whatever we look like now is the real us
    if not baseSkin and type(CachedSkin) == "table" and CachedSkin.sex then
        baseSkin  = copy(CachedSkin)
        baseComps = copy(CachedComponents)
    end
end

local function wear(skin, comps)
    if type(skin) ~= "table" or not skin.sex then return false end
    comps = type(comps) == "table" and comps or {}

    -- Only force a model swap when the sex actually changes
    local swap = tostring(skin.sex) ~= tostring(CachedSkin and CachedSkin.sex)

    CachedSkin       = skin
    CachedComponents = comps

    -- a model swap builds a NEW ped with zero ammo; vorp_inventory's belt thread would read that zero as "spent" and save it
    if swap then
        TriggerEvent("vorp_inventory:pup:holdAmmoReconcile", 12000)
    end

    -- The same call VORP itself uses on respawn: body, face overlays, hair, clothes and SetPedScale for height, in one pass
    LoadPlayerComponents(PlayerPedId(), CachedSkin, CachedComponents, swap)

    if swap then
        -- a new ped is empty-handed; ask vorp_inventory to hand the loadout back, then put the belt back on it
        TriggerServerEvent("vorpinventory:getInventory")
        SetTimeout(2500, function() TriggerEvent("vorp_inventory:pup:restoreBeltToPed") end)
    end

    return true
end

RegisterNetEvent("pup-disguise:apply", function(skinJson, compsJson, tintsJson, extrasJson, overlayJson, expressionsJson)
    snapshot()
    local ok = wear(
        mergeSkin(decode(skinJson, nil)),
        buildComps(decode(compsJson, {}), decode(tintsJson, {}))
    )
    if ok then
        disguised = true
        -- pup_clothing's colours and singleplayer garments live in its own extras store
        if type(extrasJson) == "string" and extrasJson ~= "" then
            TriggerEvent("pup_clothing:recExtras", extrasJson)
        end
        -- their makeup, tattoos and body adjustments (pup-misc/tattoos owns those layers); after the ped has settled
        SetTimeout(1200, function()
            TriggerEvent("pup-misc:overlay:applyDisguise", skinJson, overlayJson or "{}", expressionsJson or "{}")
        end)
    end
end)

-- Reverting prefers the snapshot taken before the first swap: it needs no database round trip
RegisterNetEvent("pup-disguise:restore", function(skinJson, compsJson, tintsJson)
    local ok = false

    if baseSkin then
        ok = wear(copy(baseSkin), copy(baseComps) or {})
    end

    if not ok and skinJson then
        ok = wear(
            decode(skinJson, nil),
            buildComps(decode(compsJson, {}), decode(tintsJson, {}))
        )
    end

    if ok then
        disguised = false
        -- back in our own skin: pup_clothing re-fetches OUR extras (colours, singleplayer pieces) exactly as it does after /rc
        TriggerEvent("vorp_character:client:reloadedComponents")
        -- and the mirror system re-fetches OUR makeup, tattoos and body adjustments from the database
        SetTimeout(1200, function() TriggerServerEvent("pup-misc:overlay:walkanim") end)
    end
end)

exports("IsDisguised", function() return disguised end)
