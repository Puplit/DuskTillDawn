-- pup_hideouts | still crafting, mash and distilling

local function stillLevel(h) return h.still and h.still.stilllevel or 0 end
HX.stillLevel = stillLevel

----------------------------------------------------------------------------------------------------
-- crafting the next still level from parts in the stash
----------------------------------------------------------------------------------------------------
HX.rpc('craftStill', function(src, id, level)
    local h = HX.memberInside(src, id)
    level = U.int(level)
    if not h or not level then return false end
    local def = Config.Stills[level]
    if not def or level ~= stillLevel(h) + 1 then return false end
    for _, p in ipairs(def.parts) do
        if HX.stashCount(h, p.name) < p.amount then HX.tip(src, L('no_mats_stash')) return false end
    end
    for _, p in ipairs(def.parts) do HX.stashRemove(h, p.name, p.amount) end
    h.still = { stilllevel = level, stilltype = def.model }
    HX.save(h, { 'still', 'items' })
    HX.reloadStashInside(h)
    HX.tip(src, L('still_crafted'))
    HX.changed(h)
    return true
end, 1500)

----------------------------------------------------------------------------------------------------
-- delivery: a finished batch goes into the stash, as much as fits
----------------------------------------------------------------------------------------------------
local KIND <const> = {
    mash    = { info = 'mashinfo', timer = 'lasttimer' },
    distill = { info = 'stillinfo', timer = 'lasttimer2' },
}

local function deliver(h, kind)
    local k = KIND[kind]
    local info = h[k.info]
    if not info or os.time() < (h[k.timer] or 0) then return false end
    local qty = math.max(0, math.floor(tonumber(info.qt) or 0))
    local free = math.max(0, h.invslots - HX.stashTotal(h))
    local put = math.min(qty, free)
    local label = info.label or info.resultitem
    if put > 0 then HX.stashPutIn(h, info.resultitem, label, put, nil, 'item_standard', info.limit) end
    h[k.info] = nil
    h[k.timer] = 0
    HX.save(h, { k.info, k.timer, 'items' })
    local who = HX.srcOfChar(info.startedby) or HX.srcOfChar(h.charidentifier)
    if who then
        HX.reloadStashFor(who, h)
        HX.tip(who, L('you_got', label))
        if put < qty then HX.tip(who, L('stash_full', h.invslots)) end
    end
    HX.reloadStashInside(h)
    HX.changed(h)
    return true
end

CreateThread(function()
    while true do
        Wait(10000)
        if HX.ready then
            for _, h in pairs(HX.hideouts) do
                if h.mashinfo then deliver(h, 'mash') end
                if h.stillinfo then deliver(h, 'distill') end
            end
        end
    end
end)

----------------------------------------------------------------------------------------------------
-- starting a batch
----------------------------------------------------------------------------------------------------
HX.rpc('prodStart', function(src, id, kind, resultitem)
    local h = HX.memberInside(src, id)
    if not h or not KIND[kind] then return false end
    local recipe = U.recipe(kind, resultitem)
    if not recipe then return false end
    local k = KIND[kind]
    if h[k.info] then
        if not deliver(h, kind) then
            HX.tip(src, L('wait_s', math.max(0, h[k.timer] - os.time())))
            return false
        end
    end
    if stillLevel(h) < (recipe.stilllevel or 1) then return false end
    for _, it in ipairs(recipe.items) do
        if HX.stashCount(h, it.name) < it.amount then HX.tip(src, L('no_mats')) return false end
    end
    local qty = recipe.qt
    if kind == 'mash' and recipe.resultitem == Config.DoubleYieldItem and Config.DistilleryJobs[HX.jobOf(src) or ''] then
        qty = qty * 2
    end
    qty = qty + math.floor(HX.perkBonus(src, 'still_yield'))
    if HX.stashTotal(h) + qty > h.invslots then
        HX.tip(src, L('stash_full', h.invslots))
        return false
    end
    for _, it in ipairs(recipe.items) do HX.stashRemove(h, it.name, it.amount) end
    local seconds = math.floor(recipe.minutes * 60 * HX.perkMult(src, 'cook_speed'))
    local info = {
        label = recipe.label, resultitem = recipe.resultitem, limit = recipe.limit, qt = qty,
        stilllevel = recipe.stilllevel, items = U.copy(recipe.items), startedby = HX.charId(src),
    }
    if kind == 'mash' then info.mashtime = recipe.minutes
    else info.stilltime = recipe.minutes; info.distill = true; info.sellprice = recipe.sellprice end
    h[k.info] = info
    h[k.timer] = os.time() + seconds
    HX.save(h, { k.info, k.timer, 'items' })
    HX.reloadStashInside(h)
    HX.changed(h)
    Logs.send('Production', kind == 'mash' and 'Mash Started' or 'Distilling Started',
        ('%s x%d'):format(recipe.label, qty), 'production', src,
        { { 'Recipe', recipe.label, true }, { 'Minutes', tostring(math.ceil(seconds / 60)), true } }, h)
    return true, kind
end, 1500)

-- admin "cancel production"
function HX.clearProduction(h)
    h.mashinfo, h.stillinfo, h.lasttimer, h.lasttimer2 = nil, nil, 0, 0
    HX.save(h, { 'mashinfo', 'stillinfo', 'lasttimer', 'lasttimer2' })
end
