-- pup_mortician | shovel wear, the shovel item and treasure digging

local DC = Config.Dig

Digs = {}            -- src -> { startedAt (ms), ms, find, pos }
local dugSpots = {}  -- { pos = vector3, at = unix }
local handShovel = {} -- src -> inventory item id of the shovel last taken out

---------------------------------------------------------------------------
-- Wear
---------------------------------------------------------------------------
local function shovelToWear(src)
    -- prefer the shovel the player actually took out
    local id = handShovel[src]
    if id then
        local ok, item = pcall(function() return Inv:getItemById(src, id) end)
        if ok and type(item) == 'table' and Rules.IsShovel(item.name) and (tonumber(item.count) or 0) > 0 then
            return item
        end
        handShovel[src] = nil
    end
    for _, name in ipairs(Config.Shovel.items) do
        local ok, item = pcall(function() return Inv:getItemByName(src, name) end)
        if ok and type(item) == 'table' and item.id then return item end
    end
    return nil
end

function WearShovel(src)
    src = tonumber(src)
    if not src then return end
    local max = math.floor(tonumber(Config.Shovel.uses) or 0)
    if max <= 0 then return end
    local item = shovelToWear(src)
    if not item then return end
    local meta = type(item.metadata) == 'table' and item.metadata or {}
    local left = math.floor(tonumber(meta.durability) or max) - 1
    if left <= 0 then
        pcall(function() Inv:subItemID(src, item.id) end)
        if handShovel[src] == item.id then handShovel[src] = nil end
        TriggerClientEvent('pup_mortician:shovelGone', src)
        Tip(src, L('shovelSnapped'))
        return
    end
    local newMeta = {}
    for k, v in pairs(meta) do newMeta[k] = v end
    newMeta.durability = left
    newMeta.description = L('durability', left, max)
    pcall(function() Inv:setItemMetadata(src, item.id, newMeta, 1) end)
end

exports('WearShovel', function(src) WearShovel(src) end)

---------------------------------------------------------------------------
-- The shovel item
---------------------------------------------------------------------------
local function onUseShovel(data)
    local src = tonumber(data and data.source)
    if not src then return end
    local ctx = GetCtx(src)
    if not ctx then return end
    if not Rules.MayDig(ctx.job) then
        Tip(src, L('notUndertaker'))
        return
    end
    pcall(function() Inv:closeInventory(src) end)
    local id = data.item and tonumber(data.item.id)
    if id then handShovel[src] = id end
    TriggerClientEvent('pup_mortician:toggleShovel', src)
end

CreateThread(function()
    for _, name in ipairs(Config.Shovel.items) do
        Inv:registerUsableItem(name, onUseShovel, RES)
    end
end)

---------------------------------------------------------------------------
-- Digging
---------------------------------------------------------------------------
local function pruneSpots()
    local cutoff = os.time() - DC.dugMinutes * 60
    for i = #dugSpots, 1, -1 do
        if dugSpots[i].at < cutoff then table.remove(dugSpots, i) end
    end
end

local function nearTown(pos)
    for _, t in ipairs(Config.Towns) do
        if #(pos - t.pos) <= DC.townRadius then return true end
    end
    return false
end

local function recentlyDug(pos)
    pruneSpots()
    for _, s in ipairs(dugSpots) do
        if #(pos - s.pos) <= DC.dugRadius then return true end
    end
    return false
end

Actions = Actions or {}

Actions.digStart = function(ctx, _)
    local src = ctx.src
    if not Rules.MayDig(ctx.job) then return { ok = false, msg = L('notUndertaker') } end
    if not HasShovel(src) then return { ok = false, msg = L('needShovel') } end
    local d = Digs[src]
    if d and GetGameTimer() - d.startedAt < d.ms then return { ok = false, msg = L('busy') } end
    local pos = PlayerPos(src)
    if not pos then return { ok = false, quiet = true } end
    if nearTown(pos) then return { ok = false, msg = L('noDigTown') } end
    if recentlyDug(pos) then return { ok = false, msg = L('dugRecently') } end

    local ms = math.floor(DC.seconds * 1000 * PerkMult(src, 'dig_speed'))
    local find = math.random(1, 100) <= DC.findChance
    Digs[src] = { startedAt = GetGameTimer(), ms = ms, find = find, pos = pos, charId = ctx.charId }
    dugSpots[#dugSpots + 1] = { pos = pos, at = os.time() }
    return { ok = true, quiet = true, ms = ms, find = find }
end

Actions.digFinish = function(ctx, _)
    local src = ctx.src
    local d = Digs[src]
    Digs[src] = nil
    if not d or d.charId ~= ctx.charId then return { ok = false, quiet = true } end
    if GetGameTimer() - d.startedAt < d.ms * DC.finishShare then return { ok = false, msg = L('tooSoon') } end
    if DistTo(src, d.pos) > DC.finishRange then return { ok = false, msg = L('wandered') } end
    if not HasShovel(src) then return { ok = false, msg = L('needShovel') } end

    WearShovel(src)
    if not d.find then return { ok = true, msg = L('nothingDown') } end

    if math.random(1, 100) <= DC.moneyShare then
        local cash = math.random(DC.moneyMin, DC.moneyMax)
        local now = StillSame(ctx)
        if not now then return { ok = false, quiet = true } end
        now.char.addCurrency(0, cash)
        PerkAward(src, 'dig')
        StaffLog(ctx, 'Treasure Dig', 'A player found money while digging.', { { 'Found', ('$%d'):format(cash) } }, Colors.gold)
        return { ok = true, msg = L('dugMoney', cash) }
    end

    local t = DC.treasure[math.random(1, #DC.treasure)]
    local amount = math.random(DC.itemMin, DC.itemMax)
    local okCarry, can = pcall(function() return Inv:canCarryItem(src, t.item, amount) end)
    if not okCarry or not can then return { ok = true, msg = L('cannotCarryFind') } end
    local okAdd, added = pcall(function() return Inv:addItem(src, t.item, amount) end)
    if not okAdd or not added then return { ok = true, msg = L('cannotCarryFind') } end
    PerkAward(src, 'dig')
    StaffLog(ctx, 'Treasure Dig', 'A player found treasure while digging.',
        { { 'Found', ('%s (%s) x%d'):format(t.label, t.item, amount) } }, Colors.gold)
    return { ok = true, msg = L('dugItem', amount, t.label) }
end

function ClearDig(src)
    Digs[src] = nil
end

function ForgetShovel(src)
    handShovel[src] = nil
end
