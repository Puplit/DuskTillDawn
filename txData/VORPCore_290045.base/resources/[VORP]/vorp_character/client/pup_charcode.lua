-- Modified by Puppet (Dusk Till Dawn), 2026
-- Character codes, client half. A code is a look only: no name, no height.

local lastCode = nil

local function tip(msg, ms)
    TriggerEvent('vorp:TipRight', msg, ms or 5000)
end

-- codes are a creator / second-chance thing only: never out in the world
function inCodeScreen()
    return IsInCharCreation == true or ShopType == 'secondchance'
end

-- in the creator the working table is live; the character row is stale
function currentSex()
    if IsInCharCreation and PlayerSkin and PlayerSkin.sex then
        return tostring(PlayerSkin.sex)
    end
    return CachedSkin and CachedSkin.sex and tostring(CachedSkin.sex) or nil
end

-- the creator keeps its own working tables; outside it the cached ones are live
local function currentLook()
    if IsInCharCreation and PlayerSkin and PlayerSkin.sex then
        local comps = PlayerClothing
        if GetNewCompOldStructure then
            local ok, converted = pcall(GetNewCompOldStructure, PlayerClothing)
            if ok and type(converted) == 'table' then comps = converted end
        end
        return PlayerSkin, comps, PlayerTrackingData
    end
    return CachedSkin, CachedComponents, nil
end

RegisterNetEvent('pup-charcode:made', function(code)
    lastCode = tostring(code)
    -- the textarea + execCommand trick, same as the inventory's serial copy
    SendNUIMessage({ action = 'pupCopyText', text = lastCode })
    tip(('Character code: ~e~%s~q~  (copied)'):format(lastCode), 15000)
    print(('^2[vorp_character]^7 character code: %s'):format(lastCode))
end)

RegisterNetEvent('pup-charcode:apply', function(sex, skinJson, compsJson, tintsJson, context)
    -- re-checked on arrival: they may have left the screen while it travelled
    if not inCodeScreen() then return end

    local okS, skin = pcall(json.decode, skinJson or '{}')
    local okC, comps = pcall(json.decode, compsJson or '{}')
    if not okS or type(skin) ~= 'table' then return tip('That code could not be read.') end
    if not okC or type(comps) ~= 'table' then comps = {} end

    -- same sex only: offsets and garments do not carry across
    local mySex <const> = currentSex()
    if mySex and tostring(sex) ~= mySex then
        return tip('That code is for the other sex.')
    end

    -- known keys only: a code is player-supplied
    local clean = {}
    for k, v in pairs(skin) do
        if SKIN_SCHEMA and SKIN_SCHEMA[k] then clean[k] = v end
    end
    clean.sex = mySex or tostring(sex)

    -- height is yours: a shared look must not resize you
    local mine <const> = (IsInCharCreation and PlayerSkin) or CachedSkin or {}
    clean.Scale = mine.Scale

    local tints = nil
    if type(tintsJson) == 'string' and tintsJson ~= '' then
        local okT, decoded = pcall(json.decode, tintsJson)
        tints = okT and decoded or nil
    end

    -- dye colours live in a separate tint table, merged as the creator does
    if tints and next(tints) and ConvertTableComps then
        local okB, merged = pcall(ConvertTableComps, comps, tints)
        if okB and type(merged) == 'table' then comps = merged end
    end

    if IsInCharCreation then
        -- inside the creator the working tables are what the menus read
        for k, v in pairs(clean) do PlayerSkin[k] = v end
    end

    -- sex matches, so no model swap: redressed in place, scale kept
    CachedSkin = clean
    CachedComponents = comps
    LoadPlayerComponents(PlayerPedId(), CachedSkin, CachedComponents, false)

    tip('Look applied. Nothing has been saved yet.', 8000)
end)

-- raised by the Copy My Code row in the creator / second-chance menu
AddEventHandler('pup-charcode:make', function()
    if not inCodeScreen() then return end
    local skin, comps, tints = currentLook()
    if type(skin) ~= 'table' or not skin.sex then
        return tip('No look to share yet.')
    end
    TriggerServerEvent('pup-charcode:create',
        json.encode(skin), json.encode(comps or {}), json.encode(tints or {}))
end)
