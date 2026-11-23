-- Contraband that may only be stashed in a hideout

PupRestricted = {
    enabled = true,

    -- Cannot be put into ANY container. Add or remove names freely.
    items = {
        -- the product
        ['moonshine']           = true,
        ['moonshineapple']      = true,
        ['moonshineraspberry']  = true,
        -- the mash it comes from
        ['mashapple']           = true,
        ['mashstrong']          = true,
        -- mashpure is not brewed; kept so leftover stock stays restricted
        ['mashpure']            = true,
        ['mashraspberry']       = true,
        -- still parts
        ['condenser']           = true,
        ['pipecopper']          = true,
        ['pot']                 = true,
        ['rubbertube']          = true,
        ['stillkit']            = true,
    },

    -- alcohol and barrel are left out on purpose: both are used well outside moonshining

    -- containers that may hold the goods anyway, by inventory id
    allowInventories = {
        -- ['some_inv_id'] = true,
    },

    message = 'Hot goods. This only goes in a hideout.',
}

-- Output-only boxes: crafting fills them, players take out, nothing goes back in
PupTakeOnly = {
    enabled = true,
    ranges = {
        { from =  9000000, to =  9999999, label = 'crafting box' },
        { from = 12000000, to = 12999999, label = 'gunsmith box' },
    },
    -- individual ids, if a fixed-id container ever needs the same rule
    ids = {
        -- ['1234'] = true,
    },
    message = 'That box only gives out. Nothing goes back in.',
}

-- nil when the container accepts deposits, otherwise the reason to refuse.
function PupInventoryIsTakeOnly(invId)
    if not PupTakeOnly.enabled then return nil end
    if invId == nil then return nil end

    if PupTakeOnly.ids[tostring(invId)] then return PupTakeOnly.message end

    local n <const> = tonumber(invId)
    if not n then return nil end
    for _, r in ipairs(PupTakeOnly.ranges) do
        if n >= r.from and n <= r.to then return PupTakeOnly.message end
    end
    return nil
end

exports('IsInventoryTakeOnly', function(invId)
    return PupInventoryIsTakeOnly(invId)
end)

-- nil when the item may be stored, otherwise the reason to show the player.
function PupItemBlockedFrom(invId, itemName)
    if not PupRestricted.enabled then return nil end
    if not itemName then return nil end

    local name <const> = string.lower(tostring(itemName))
    if not PupRestricted.items[name] then return nil end
    if invId and PupRestricted.allowInventories[tostring(invId)] then return nil end

    return PupRestricted.message
end

-- Globals do not cross resources
--   exports.vorp_inventory:IsItemRestricted("house", itemName)
exports('IsItemRestricted', function(invId, itemName)
    return PupItemBlockedFrom(invId, itemName)
end)

-- STUCK CONTAINER SWEEPER
-- if no CONNECTED player is holding it, the flag is a leftover and is cleared.
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(30000)
        if CUSTOM_INVENTORIES and INVENTORY_IN_USE then
            -- who is legitimately holding something, by inventory id
            local heldBy = {}
            for src, invId in pairs(INVENTORY_IN_USE) do
                if GetPlayerName(src) then
                    heldBy[invId] = src
                else
                    -- the holder is gone; their claim goes with them
                    INVENTORY_IN_USE[src] = nil
                    if INVENTORY_CAN_MANAGE then INVENTORY_CAN_MANAGE[src] = nil end
                end
            end

            for id, inv in pairs(CUSTOM_INVENTORIES) do
                if type(inv) == "table" and inv.isInUse and inv:isInUse() and not heldBy[id] then
                    inv:setInUse(false)
                    print(("^3[vorp_inventory]^7 released stuck container '%s' - marked in use with nobody in it"):format(tostring(id)))
                end
            end
        end
    end
end)

-- ITEM MOVE TRACE (CONFIG.TRACE_ITEM_MOVES): one console line per give / destroy

local function who(src)
    local name = GetPlayerName(src)
    return ("%s[%s]"):format(name or "?", tostring(src))
end

-- ItemTrace("DESTROY", src, { item = "moonshine", amount = 2, ok = true })
function ItemTrace(action, src, info)
    if not (CONFIG and CONFIG.TRACE_ITEM_MOVES) then return end
    info = info or {}

    local bits = {}
    bits[#bits + 1] = ("item=%s"):format(tostring(info.item or "?"))
    bits[#bits + 1] = ("amount=%s"):format(tostring(info.amount or "?"))
    if info.id ~= nil then bits[#bits + 1] = ("id=%s"):format(tostring(info.id)) end
    if info.target ~= nil then bits[#bits + 1] = ("-> %s"):format(who(info.target)) end
    for _, k in ipairs({ "removed", "added", "clientTold" }) do
        if info[k] ~= nil then bits[#bits + 1] = ("%s=%s"):format(k, tostring(info[k])) end
    end

    local colour = info.fail and "^1" or "^2"
    print(("%s[itemtrace]^7 %-8s %-22s %s%s"):format(
        colour, action, who(src), table.concat(bits, "  "),
        info.fail and ("  ^1FAILED: " .. tostring(info.fail) .. "^7") or ""))
end
