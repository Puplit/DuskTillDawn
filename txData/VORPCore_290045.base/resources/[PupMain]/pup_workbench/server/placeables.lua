-- Placeables (the campfire): one per character, remembered in memory only.
Placeables = {}

local placed = {}     -- charid -> { item, model, src, pos }, one per character
local begun = {}      -- src -> { item, charid, at }  a use that the client may now complete

function Placeables.placedFor(charid)
    return placed[charid]
end

--- The usable item was used: close the satchel and let the client run the set-up.
function Placeables.onUse(src, item)
    local who = Who(src)
    if not who then return end
    pcall(function() Inv:closeInventory(src) end)
    if placed[who.charid] then
        Notify(src, L('already_placed', Config.Placeables.pickupCommand), 5000)
        return
    end
    begun[src] = { item = item, charid = who.charid, at = os.time() }
    TriggerClientEvent('pup_workbench:place:begin', src, item)
end

--- The client finished the crouch: take one item, then the client may spawn the prop.
function Placeables.place(src, who, payload)
    local b = begun[src]
    begun[src] = nil
    if not b or b.charid ~= who.charid or os.time() - b.at > 60 then return { ok = false, msg = L('place_failed') } end
    if type(payload) ~= 'table' or payload.item ~= b.item then return { ok = false, msg = L('place_failed') } end
    local def = Config.Placeables.items[b.item]
    if not def then return { ok = false, msg = L('place_failed') } end
    if placed[who.charid] then
        return { ok = false, msg = L('already_placed', Config.Placeables.pickupCommand) }
    end
    if not Inv:subItem(src, b.item, 1) then return { ok = false, msg = L('place_failed') } end
    local pos = PlayerPos(src)
    placed[who.charid] = { item = b.item, model = def.model:lower(), src = src, pos = pos }
    return { ok = true, model = def.model }
end

--- /dc: give back exactly what was placed, unless the crafting box still holds goods.
function Placeables.pickup(src, who)
    local p = placed[who.charid]
    if not p then return { ok = false, msg = L('nothing_placed') } end
    if Config.Box.enabled then
        local n = Box.count(who.charid)
        if n > 0 then return { ok = false, msg = L('empty_box_first', n) } end
    end
    -- the box read waited on the database; check nothing changed meanwhile
    local now = Who(src)
    if not now or now.charid ~= who.charid or placed[who.charid] ~= p then
        return { ok = false, msg = L('nothing_placed') }
    end
    if not Inv:canCarryItem(src, p.item, 1) then return { ok = false, msg = L('cannot_carry') } end
    placed[who.charid] = nil
    if not Inv:addItem(src, p.item, 1) then
        placed[who.charid] = p
        return { ok = false, msg = L('cannot_carry') }
    end
    return { ok = true, msg = L('picked_up') }
end

--- Disconnect: forget whatever this player placed (no refund).
function Placeables.dropPlayer(src)
    begun[src] = nil
    for charid, p in pairs(placed) do
        if p.src == src then placed[charid] = nil end
    end
end

--- vorp_admin world cleanup deleted every campfire: hand each one back so it can be set
--- down again. The crafting box is its own inventory and keeps what is in it.
AddEventHandler('vorp_admin:worldCleanupDone', function()
    for charid, p in pairs(placed) do
        placed[charid] = nil
        local now = Who(p.src)
        if now and now.charid == charid and Inv:canCarryItem(p.src, p.item, 1) then
            Inv:addItem(p.src, p.item, 1)
            Notify(p.src, L('picked_up'), 5000)
        end
    end
end)

function Placeables.registerItems()
    for name in pairs(Config.Placeables.items) do
        Inv:registerUsableItem(name, function(data)
            local src = type(data) == 'table' and tonumber(data.source) or nil
            if src then Placeables.onUse(src, name) end
        end, GetCurrentResourceName())
    end
    for name in pairs(Config.Kits) do
        Inv:registerUsableItem(name, function(data)
            local src = type(data) == 'table' and tonumber(data.source) or nil
            if not src or not Who(src) then return end
            pcall(function() Inv:closeInventory(src) end)
            TriggerClientEvent('pup_workbench:kit:open', src, name)
        end, GetCurrentResourceName())
    end
end
