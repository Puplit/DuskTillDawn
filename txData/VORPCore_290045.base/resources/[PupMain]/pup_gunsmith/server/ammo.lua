-- pup_gunsmith | ammo boxes: usable items that load rounds onto the belt

Ammo = {
    registered = {}, -- box item -> true once registered with vorp_inventory
}

local function trace(fmt, ...)
    if Config.Debug.ammo then print(('[pup_gunsmith ammo] ' .. fmt):format(...)) end
end

-- the highest positive belt cap per ammo type among the live ammo recipes
local function capsByType()
    local caps = {}
    for _, cat in pairs(Recipes.live.ammo) do
        for _, rec in pairs(cat) do
            local cap = tonumber(rec.maxammo) or 0
            if cap > 0 and (not caps[rec.key] or cap > caps[rec.key]) then caps[rec.key] = cap end
        end
    end
    return caps
end

function Ammo.pushCaps()
    local caps = capsByType()
    local ok, applied = pcall(function() return Inv:setMaxAmmoBeltBulk(caps) end)
    if not ok then
        print('^1[pup_gunsmith]^7 vorp_inventory has no setMaxAmmoBeltBulk export - restart vorp_inventory first so the belt caps can be pushed.')
        return 0
    end
    return tonumber(applied) or GS.count(caps)
end

local function vorpCap(ammoType)
    local ok, cap = pcall(function() return Inv:getMaxAmmoBelt(ammoType) end)
    if ok then return tonumber(cap) end
    return nil
end

local function closeInventory(src)
    pcall(function() Inv:closeInventory(src) end)
end

local function useBox(src, item)
    if not Srv.validSource(src) then return end
    local char = Srv.char(src)
    if not char then return end
    if not Srv.throttle(src, 'ammobox', 400) then return end
    if not Srv.tryLock(src) then return end

    local ok, err = pcall(function()
        -- the recipe is looked up now, so admin edits apply at once
        local rec = Recipes.ammoByItem(item)
        if not rec then
            Srv.tip(src, L('box_unusable'))
            trace('%s used %s: no live recipe', Srv.who(src), item)
            return
        end
        closeInventory(src)

        local belt = Inv:getUserAmmo(src) or {}
        local current = tonumber(belt[rec.key]) or 0
        local ceiling = tonumber(rec.maxammo) or 0
        local theirs = vorpCap(rec.key)
        if theirs then
            -- a recipe without a belt cap of its own falls back to vorp_inventory's
            ceiling = ceiling > 0 and math.min(ceiling, theirs) or theirs
        end
        local add = math.min(rec.qt, ceiling - current)
        trace('%s %s: belt %d, ceiling %d, box %d, add %d', Srv.who(src), item, current, ceiling, rec.qt, add)

        if current >= ceiling or add <= 0 then
            Srv.tip(src, L('belt_full'))
            trace('  -> kept (belt full)')
            return
        end
        if Srv.count(src, item) < 1 then return end

        Inv:addBullets(src, rec.key, add)
        local after = tonumber((Inv:getUserAmmo(src) or {})[rec.key]) or 0
        if after > current then
            Inv:subItem(src, item, 1)
            trace('  -> used (belt now %d)', after)
        else
            Srv.tip(src, L('belt_full'))
            trace('  -> kept (belt did not move)')
        end
    end)
    Srv.unlock(src)
    if not ok then print(('^1[pup_gunsmith]^7 ammo box %s failed: %s'):format(item, tostring(err))) end
end

--- registers any live box item not yet registered, then (once start-up is done) pushes the
--- belt caps again, so a cap edited in vorp_admin reaches vorp_inventory at once
function Ammo.refresh(noPush)
    local added = 0
    for _, cat in pairs(Recipes.live.ammo) do
        for _, rec in pairs(cat) do
            local item = rec.item
            if item and not Ammo.registered[item] then
                local ok = pcall(function()
                    Inv:registerUsableItem(item, function(data)
                        useBox(data and data.source, item)
                    end, GS.RES)
                end)
                if ok then
                    Ammo.registered[item] = true
                    added = added + 1
                end
            end
        end
    end
    if Ammo.started and not noPush then Ammo.pushCaps() end
    return added
end

local function report(pushed)
    print(('[pup_gunsmith] %d ammo box items usable, %d belt caps pushed'):format(GS.count(Ammo.registered), pushed))
end

function Ammo.startup()
    -- wait up to 15 s for the recipes to load
    local waited = 0
    while not Recipes.loadedOnce and waited < 15000 do
        Wait(250)
        waited = waited + 250
    end
    Ammo.refresh(true)
    Ammo.started = true
    report(Ammo.pushCaps())

    local missing = {}
    for item in pairs(Ammo.registered) do
        local ok, row = pcall(function() return Inv:getItemDB(item) end)
        if not ok or not row then missing[#missing + 1] = item end
    end
    if #missing > 0 then
        table.sort(missing)
        print(('^1[pup_gunsmith]^7 these ammo box items are not in the items table: %s'):format(table.concat(missing, ', ')))
        print('^1[pup_gunsmith]^7 vorp_inventory reads items only when it starts - add them, then restart vorp_inventory.')
    end
    if not pcall(function() return Inv:getMaxAmmoBelt('AMMO_REVOLVER') end) then
        print('^1[pup_gunsmith]^7 vorp_inventory has no getMaxAmmoBelt export - box ceilings fall back to the recipe caps.')
    end
end

-- vorp_inventory restarted under us: its registrations and caps are gone
AddEventHandler('onResourceStart', function(name)
    if name ~= 'vorp_inventory' then return end
    CreateThread(function()
        Wait(2000)
        Inv = exports.vorp_inventory
        Ammo.registered = {}
        Ammo.refresh(true)
        report(Ammo.pushCaps())
        print('[pup_gunsmith] vorp_inventory restarted - ammo boxes and belt caps re-registered')
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GS.RES then return end
    for item in pairs(Ammo.registered) do
        pcall(function() Inv:unRegisterUsableItem(item) end)
    end
end)
