-- pup_gunsmith | putting saved parts back on the gun in the player's hands
-- Triggered by the server after vorp_inventory reports a weapon use or a spawn restore,
-- and right after the bench saves new parts.

local function trace(fmt, ...)
    if Config.Debug.components then print(('[pup_gunsmith comps] ' .. fmt):format(...)) end
end

local NAT <const> = {
    REMOVE_COMPONENT_FROM_PED        = 0x19F70C4D80494FF8,
    GIVE_COMPONENT_TO_ENTITY         = 0x74C9090FDD1BB48E,
    APPLY_SHOP_ITEM_TO_PED           = 0xD3A7B003ED343FD9,
    UPDATE_PED_VARIATION             = 0xCC8CA3E88256E58F,
    CURRENT_WEAPON_ENTITY            = 0x3B390A939AF0B5FC,
    PED_HAS_COMPONENT                = 0xBBC67A6F965C688A,
    GET_WEAPON_NAME                  = 0x89CF5FF3D363311E,
    ITEM_KEY_VALID                   = 0x6D5D51B188333FD1,
    ITEM_HAS_TAG                     = 0xFF5A1D5ECA0B4A16,
    INV_GUID_FROM_ITEM               = 0x886DFD3E185C8A89,
    INV_ADD_ITEM_WITH_GUID           = 0xCB5D11F9508A928D,
    INV_EQUIP_ITEM_WITH_GUID         = 0x734311E2852760D0,
}

local GRIP_KEYS <const> = { GRIP = true, GRIPSTOCK_TINT = true, GRIP_TINT = true }
local FIRST <const> = { 'BARREL', 'GRIP', 'SIGHT', 'CLIP', 'MAG', 'STOCK', 'TUBE', 'TORCH_MATCHSTICK', 'GRIPSTOCK' }
local firstRank = {}
for i, k in ipairs(FIRST) do firstRank[k] = i end

local function suffixRank(cat)
    if cat:sub(-19) == '_ENGRAVING_MATERIAL' then return 4 end
    if cat:sub(-10) == '_ENGRAVING' then return 3 end
    if cat:sub(-9) == '_MATERIAL' then return 2 end
    if cat:sub(-5) == '_TINT' then return 5 end
    return 1
end

local function order(a, b)
    local ra, rb = firstRank[a], firstRank[b]
    if ra or rb then
        if ra and rb then return ra < rb end
        return ra ~= nil
    end
    local sa, sb = suffixRank(a), suffixRank(b)
    if sa ~= sb then return sa < sb end
    return a < b
end

local function is1(v) return v == 1 or v == true end

---------------------------------------------------------------------------
-- the grip tint lives in the game's own inventory: character -> weapon -> grip -> tint
-- Guids are 13 x 8 bytes; the natives write straight into these buffers.
---------------------------------------------------------------------------
local GUID_BYTES <const> = 8 * 13

local function newGuid() return string.rep('\0', GUID_BYTES) end

local function childGuid(parent, itemHash, slotHash)
    local out = newGuid()
    local ok = Citizen.InvokeNative(NAT.INV_GUID_FROM_ITEM, 1, parent, itemHash, slotHash, out, Citizen.ResultAsInteger())
    if not is1(ok) then return nil end
    return out
end

local function gripTint(ped, weaponHash, family, gripComp, tintComp)
    if not Config.Refit.gripTint then return end
    local slots = Config.Refit.inventorySlots
    local tintSlot = Config.Refit.tintSlots[family]
    if not tintSlot then return end
    local tintHash = joaat(tintComp)
    if not is1(Citizen.InvokeNative(NAT.ITEM_KEY_VALID, tintHash, 0, Citizen.ResultAsInteger())) then
        trace('grip tint %s is not a game item - skipped', tintComp)
        return
    end
    local tag = Config.Refit.gripTintSkipTag
    if tag and is1(Citizen.InvokeNative(NAT.ITEM_HAS_TAG, tintHash, joaat(tag), 0, Citizen.ResultAsInteger())) then
        trace('grip tint %s carries %s - skipped', tintComp, tag)
        return
    end
    local charGuid = childGuid(newGuid(), joaat('CHARACTER'), joaat(slots.character))
    local weaponGuid = charGuid and childGuid(charGuid, weaponHash, joaat(slots.weapon))
    local gripGuid = weaponGuid and gripComp and childGuid(weaponGuid, joaat(gripComp), joaat(slots.grip))
    if not gripGuid then
        trace('grip tint %s: no grip found in the game inventory - skipped', tintComp)
        return
    end
    if childGuid(gripGuid, tintHash, tintSlot) then return end -- already there
    local tintGuid = newGuid()
    local added = Citizen.InvokeNative(NAT.INV_ADD_ITEM_WITH_GUID, 1, tintGuid, gripGuid, tintHash, tintSlot, 1,
        joaat('ADD_REASON_DEFAULT'), Citizen.ResultAsInteger())
    if is1(added) then
        Citizen.InvokeNative(NAT.INV_EQUIP_ITEM_WITH_GUID, 1, tintGuid, true)
        trace('grip tint %s fitted', tintComp)
    end
end

---------------------------------------------------------------------------
-- the refit
---------------------------------------------------------------------------
local refitTokens = {} -- [weapon hash] = bumped per request, so only the newest refit of a gun runs on

local function weaponNameOf(hash)
    local key = Catalogue.modelByHash(hash)
    if key then return key:upper() end
    local ok, name = pcall(Citizen.InvokeNative, NAT.GET_WEAPON_NAME, hash, Citizen.ResultAsString())
    if ok and type(name) == 'string' and name ~= '' then return name:upper() end
    return nil
end

local function hasWeapon(ped, hash)
    local r = HasPedGotWeapon(ped, hash, 0, false)
    return r == true or r == 1
end

local function u32(h) return h and (math.tointeger(h) or 0) & 0xFFFFFFFF end

local function currentWeapon(ped)
    local ok, _, h = pcall(GetCurrentPedWeapon, ped, true, 0, true)
    if ok then return h end
    return nil
end

local function audit(ped, hash, parts)
    for cat, comp in pairs(parts) do
        local present = {}
        for _, v in ipairs(Catalogue.variantsOf(comp)) do
            if is1(Citizen.InvokeNative(NAT.PED_HAS_COMPONENT, ped, joaat(v), hash, Citizen.ResultAsInteger())) then
                present[#present + 1] = v
            end
        end
        local verdict
        if #present == 0 then verdict = 'empty'
        elseif #present > 1 then verdict = 'unknown (' .. table.concat(present, ', ') .. ')'
        elseif present[1] == comp then verdict = 'confirmed'
        else verdict = 'wrong (' .. present[1] .. ')' end
        trace('  %-26s %-48s %s', cat, comp, verdict)
    end
end

local function refit(parts, weaponHash, myToken)
    -- 1. skip junk, 2. hold back the grip pass
    local clean = GS.cleanParts(parts, Config.Bench.maxParts)
    local main, grip = {}, {}
    for cat, comp in pairs(clean) do
        if GRIP_KEYS[cat] then grip[cat] = comp else main[#main + 1] = cat end
    end
    -- 3. order the rest
    table.sort(main, order)

    -- 4. wait for the weapon to actually be there
    local deadline = GetGameTimer() + Config.Refit.waitForWeaponMs
    local ped = PlayerPedId()
    while not hasWeapon(ped, weaponHash) do
        if GetGameTimer() > deadline or refitTokens[weaponHash] ~= myToken then
            trace('weapon %s never arrived - it refits on the next equip', tostring(weaponHash))
            return
        end
        Wait(Config.Refit.pollMs)
        ped = PlayerPedId() -- a respawn swaps the ped
    end
    if refitTokens[weaponHash] ~= myToken then return end

    -- 5. was it drawn before we touched anything?
    local drawn = u32(currentWeapon(ped)) == u32(weaponHash)

    -- 6. load models, 7. clear the slots
    local models = {}
    local fitList = {}
    for _, cat in ipairs(main) do fitList[#fitList + 1] = clean[cat] end
    for _, comp in ipairs(fitList) do
        local m = GunObj.loadComponentModel(joaat(comp))
        if m then models[#models + 1] = m end
        for _, v in ipairs(Catalogue.variantsOf(comp)) do
            Citizen.InvokeNative(NAT.REMOVE_COMPONENT_FROM_PED, ped, joaat(v), weaponHash)
        end
    end

    -- 8. let the game settle
    Wait(Config.Refit.settleMs)
    if refitTokens[weaponHash] ~= myToken then return end

    -- 9. fit to the player
    for _, comp in ipairs(fitList) do
        local h = joaat(comp)
        Citizen.InvokeNative(NAT.GIVE_COMPONENT_TO_ENTITY, ped, h, weaponHash, true)
        Citizen.InvokeNative(NAT.APPLY_SHOP_ITEM_TO_PED, ped, h, true, true, true)
    end

    -- 10. and to the gun object in hand
    local obj
    if drawn then
        for attach = 0, 3 do
            local e = Citizen.InvokeNative(NAT.CURRENT_WEAPON_ENTITY, ped, attach, Citizen.ResultAsInteger())
            if e and e ~= 0 and DoesEntityExist(e) then obj = e break end
        end
        if obj then
            for _, comp in ipairs(fitList) do
                Citizen.InvokeNative(NAT.GIVE_COMPONENT_TO_ENTITY, obj, joaat(comp), weaponHash, true)
            end
        end
    end

    -- 11. the grip pass
    local name = weaponNameOf(weaponHash)
    local gripComp = grip.GRIP or (name and Catalogue.defaultGrip(name))
    if gripComp then
        for _, g in ipairs(name and Catalogue.modelGrips(name) or {}) do
            Citizen.InvokeNative(NAT.REMOVE_COMPONENT_FROM_PED, ped, joaat(g), weaponHash)
        end
        local m = GunObj.loadComponentModel(joaat(gripComp))
        if m then models[#models + 1] = m end
        Citizen.InvokeNative(NAT.GIVE_COMPONENT_TO_ENTITY, ped, joaat(gripComp), weaponHash, true)
        Citizen.InvokeNative(NAT.APPLY_SHOP_ITEM_TO_PED, ped, joaat(gripComp), true, true, true)
        if obj then Citizen.InvokeNative(NAT.GIVE_COMPONENT_TO_ENTITY, obj, joaat(gripComp), weaponHash, true) end
    end
    local tint = grip.GRIPSTOCK_TINT or grip.GRIP_TINT
    if tint then
        local family = BenchCl.familyOf(weaponHash, name)
        if family == 'SHOTGUN' then family = 'LONGARM' end
        local ok, err = pcall(gripTint, ped, weaponHash, family, gripComp, tint)
        if not ok then trace('grip tint failed: %s', tostring(err)) end
    end

    -- 12. refresh, and re-draw so the model in hand is rebuilt
    Citizen.InvokeNative(NAT.UPDATE_PED_VARIATION, ped, false, true, true, true, false)
    if drawn and u32(currentWeapon(ped)) == u32(weaponHash) then
        SetCurrentPedWeapon(ped, weaponHash, true, 0, false, false)
    end

    -- 13. release models
    for _, m in ipairs(models) do SetModelAsNoLongerNeeded(m) end

    -- 14. audit
    if Config.Debug.components then
        trace('refit of %s (%s):', tostring(name), tostring(weaponHash))
        audit(ped, weaponHash, clean)
    end
end

RegisterNetEvent('pup_gunsmith:refit', function(parts, weaponId, weaponHash)
    if type(parts) ~= 'table' or type(weaponHash) ~= 'number' then return end
    refitTokens[weaponHash] = (refitTokens[weaponHash] or 0) + 1
    local mine = refitTokens[weaponHash]
    trace('refit requested for weapon %s', tostring(weaponId))
    CreateThread(function()
        local ok, err = pcall(refit, parts, weaponHash, mine)
        if not ok then print(('^1[pup_gunsmith]^7 refit failed: %s'):format(tostring(err))) end
    end)
end)
