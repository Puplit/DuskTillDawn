-- pup_camps | functional furniture: wardrobe, stable purchase, stew pot, trapper supplies

------------------------------------------------------------------------------ wardrobe

Handle('outfits', function(ctx)
    local rows = MySQL.query.await('SELECT id, title FROM outfits WHERE charidentifier = ?', { ctx.charid }) or {}
    local list = {}
    for _, r in ipairs(rows) do list[#list + 1] = { id = r.id, title = tostring(r.title or ('Outfit ' .. tostring(r.id))) } end
    return list
end, { gapMs = 1000 })

Handle('outfitWear', function(ctx, outfitId)
    outfitId = tonumber(outfitId)
    if not outfitId then return nil end
    if not ctx.camp then return nil end
    local camp = Camps[ctx.camp]
    if not camp or camp.repo or not AtCamp(ctx.src, camp) then return nil, L('too_far') end
    local comps = MySQL.scalar.await('SELECT comps FROM outfits WHERE id = ? AND charidentifier = ?', { outfitId, ctx.charid })
    if type(comps) ~= 'string' or comps == '' or #comps > 20000 then return nil end
    local ok, decoded = pcall(json.decode, comps)
    if not ok or type(decoded) ~= 'table' then return nil end
    -- re-check the character after the await
    local live = Ctx(ctx.src)
    if not live or live.charid ~= ctx.charid then return nil end
    -- an empty or array JSON is not an outfit
    if next(decoded) == nil or decoded[1] ~= nil then return nil end
    if GlobalState[('pup_disguise_%s'):format(ctx.charid)] ~= true then
        local ch = live.char
        -- vorp_core's functions arrive as callable tables (cross-resource), not as 'function'
        local kind = type(ch.updateComps)
        if kind == 'function' or kind == 'table' then
            ch.updateComps(comps)
        else
            MySQL.update('UPDATE characters SET compPlayer = ? WHERE charidentifier = ?', { comps, ctx.charid })
        end
    end
    return comps
end, { gapMs = 2000 })

------------------------------------------------------------------------------ hunting wagon purchase

Handle('buyWagon', function(ctx, campId)
    if not Config.HuntingWagon.enabled then return false end
    local camp, why = Can(ctx, campId, 'buyWagon')
    if not camp then return false, why end
    if camp.hwagon == 1 then return false end
    local paid = PayFromSafeOrPlayer(ctx, camp, Config.HuntingWagon.price)
    if not paid then return false, L('not_enough_cash') end
    camp.hwagon = 1
    Save(camp)
    Notify(ctx.src, L('hwagon_bought'))
    CampLog(camp, 'camp', 'Hunting Wagon Bought', LogColour.green, {
        { 'By', Who(ctx.src, camp) }, { 'Cost', U.money(Config.HuntingWagon.price) .. (paid == 'safe' and ' (safe)' or ' (own pocket)'), true },
        { 'Safe', U.money(camp.cash), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 2000 })

------------------------------------------------------------------------------ stew pot

local function emptyPot(camp)
    camp.stewlevel = 0
    camp.stewspoil = nil
end

Handle('stewEat', function(ctx, campId)
    local camp, why = Can(ctx, campId, nil)
    if not camp then return nil, why end
    local level = camp.stewlevel
    local recipe = Config.Stews[level]
    if not recipe then return nil, L('stew_empty') end
    emptyPot(camp)
    Save(camp)
    CampLog(camp, 'supplies', 'Stew Eaten', LogColour.blue, {
        { 'Who', Who(ctx.src, camp) }, { 'Level', ('%d (%s)'):format(level, recipe.name), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return { level = level, stats = recipe.stats }
end, { gapMs = 2000 })

Handle('stewCook', function(ctx, campId, level)
    local camp, why = Can(ctx, campId, nil)
    if not camp then return false, why end
    level = math.floor(tonumber(level) or 0)
    local recipe = Config.Stews[level]
    if not recipe then return false end
    if camp.stewlevel ~= 0 then return false end
    for _, ing in ipairs(recipe.ingredients) do
        local have = tonumber(exports.vorp_inventory:getItemCount(ctx.src, nil, ing[1])) or 0
        if have < ing[2] then
            return false, L('stew_missing', Config.IngredientLabels[ing[1]] or ing[1])
        end
    end
    local taken = {}
    for _, ing in ipairs(recipe.ingredients) do
        if not exports.vorp_inventory:subItem(ctx.src, ing[1], ing[2]) then
            for _, t in ipairs(taken) do exports.vorp_inventory:addItem(ctx.src, t[1], t[2]) end
            return false, L('stew_missing', Config.IngredientLabels[ing[1]] or ing[1])
        end
        taken[#taken + 1] = ing
    end
    -- someone else may have filled the pot while the items were taken
    if Camps[camp.id] ~= camp or camp.stewlevel ~= 0 then
        for _, t in ipairs(taken) do exports.vorp_inventory:addItem(ctx.src, t[1], t[2]) end
        return false
    end
    camp.stewlevel = level
    camp.stewspoil = os.time() + recipe.spoilMin * 60
    Save(camp)
    local used = {}
    for _, ing in ipairs(recipe.ingredients) do used[#used + 1] = ('%dx %s'):format(ing[2], Config.IngredientLabels[ing[1]] or ing[1]) end
    CampLog(camp, 'supplies', 'Stew Cooked', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Level', ('%d (%s)'):format(level, recipe.name), true },
        { 'Spoils in', ('%d min'):format(recipe.spoilMin), true }, { 'Ingredients used', table.concat(used, ', ') },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 2000 })

-- the spoil time is stored with the camp, so a pot cooked before a restart still empties
CreateThread(function()
    while true do
        Wait(30000)
        if Ready then
            local now = os.time()
            for _, camp in pairs(Camps) do
                if camp.stewlevel ~= 0 then
                    if not camp.stewspoil then
                        local r = Config.Stews[camp.stewlevel]
                        camp.stewspoil = now + (r and r.spoilMin or 10) * 60
                        Save(camp)
                    elseif now >= camp.stewspoil then
                        emptyPot(camp)
                        Save(camp)
                        PushCamp(camp)
                    end
                end
            end
        end
    end
end)

------------------------------------------------------------------------------ trapper

Handle('trapperInfo', function(ctx, campId)
    local camp, why = Can(ctx, campId, nil)
    if not camp then return nil, why end
    local now = os.time()
    local cd = MissionCooldowns[camp.id] or {}
    return {
        supplyLeft = math.max(0, (cd.supply or 0) - now),
        deliveryLeft = math.max(0, (cd.delivery or 0) - now),
        stock = camp.stock, maxstock = camp.maxstock, material = camp.material, supply = camp.supply,
    }
end)

Handle('buySupplies', function(ctx, campId, amount)
    local n = WholeAmount(amount)
    if not n or n > 100000 then return false, L('invalid_amount') end
    local camp, why = Can(ctx, campId, 'buySupplies')
    if not camp then return false, why end
    local cost = n * Config.Economy.supplyPrice
    local paid = PayFromSafeOrPlayer(ctx, camp, cost)
    if not paid then return false, L('not_enough_cash') end
    camp.supply = camp.supply + n
    Save(camp)
    Notify(ctx.src, L('supplies_bought', n, U.money(cost)))
    CampLog(camp, 'supplies', 'Supplies Bought', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Amount', tostring(n), true },
        { 'Cost', U.money(cost) .. (paid == 'safe' and ' (safe)' or ' (own pocket)'), true },
        { 'Safe', U.money(camp.cash), true },
    }, { actor = ctx.src })
    PushCamp(camp)
    return true
end, { gapMs = 1000 })

------------------------------------------------------------------------------ stock processing

CreateThread(function()
    while true do
        Wait(Config.Economy.stockEveryMin * 60000)
        if Ready then
            for _, camp in pairs(Camps) do
                if camp.material > 0 and camp.supply >= 1 then
                    local take = math.min(Config.Economy.perCycle, camp.material)
                    camp.material = U.round(camp.material - take, 4)
                    camp.stock = math.min(camp.maxstock, U.round(camp.stock + take, 4))
                    camp.supply = math.max(0, camp.supply - Config.Economy.drainPerCycle)
                    Save(camp)
                    PushCamp(camp)
                end
            end
        end
    end
end)
