-- pup_shaman | ancient trees: who may dream, and what happens on waking

Trees = {}

local dreams = {}        -- src -> { tree, vision, started, charId, confirmed, token }
local cooldowns = {}     -- charId -> { [treeIndex] = os.time() of the last vision }
local returnTo = {}      -- charId -> vector3: a dreamer who left mid-vision is put back at the tree next time

local function setBucket(src, bucket)
    if not Config.Instances.enabled then return end
    TriggerEvent('pup-misc:instance:setNamed2', src, bucket)
end

function Trees.IsDreaming(src)
    return dreams[src] ~= nil
end

local function jobAllowed(tree, job)
    for _, j in ipairs(tree.jobs or {}) do
        if j == job then return true end
    end
    return false
end

--- Ends a dream record. Returns it (or nil when there was none).
local function endDream(src)
    local d = dreams[src]
    if not d then return nil end
    dreams[src] = nil
    setBucket(src, 0)
    return d
end

RegisterNetEvent('pup_shaman:server:vision', function(treeIndex, visionIndex, giveTo)
    local src = source
    if not Shaman.Throttle(src, 'vision', 2000) then return end
    local rules = Config.TreeRules
    local tree = Config.Trees[tonumber(treeIndex) or -1]
    local askerChar = Shaman.Character(src)
    local askerPos = Shaman.Coords(src)
    if not tree or not askerChar or not askerPos then return end
    if #(askerPos - tree.coords) > rules.reach + rules.reachSlack then return end

    if rules.jobLock and not jobAllowed(tree, askerChar.job) then
        local carries = tree.curse and Store.Get(src) == tree.curse
        if not carries then return Shaman.Notify(src, L('tree_nothing')) end
    end
    local vision = tree.visions[tonumber(visionIndex) or -1]
    if not vision then return end

    local dreamer = src
    local giving = giveTo ~= nil
    if giving then
        local other = tonumber(giveTo)
        local otherPos = other and other ~= src and Shaman.Online(other) and Shaman.Coords(other)
        if not otherPos or #(askerPos - otherPos) > rules.giveRange + rules.giveSlack then
            return Shaman.Notify(src, L('tree_no_one'))
        end
        dreamer = other
    end

    local dreamerChar = Shaman.Character(dreamer)
    if not dreamerChar or dreams[dreamer] then return end
    -- someone in a form or a ritual cannot be sent dreaming
    if Shaman.Form(dreamer) or Rituals.InSession(dreamer) then
        return Shaman.Notify(src, L('tree_busy'))
    end
    local charId = tonumber(dreamerChar.charIdentifier)
    local treeIdx = tonumber(treeIndex)
    local now = os.time()
    local cds = cooldowns[charId]
    local last = cds and cds[treeIdx]
    local wait = rules.cooldownMinutes * 60
    if last and now - last < wait then
        return Shaman.Notify(src, L('tree_cooldown', math.ceil((wait - (now - last)) / 60)))
    end
    if not cds then cds = {}; cooldowns[charId] = cds end
    cds[treeIdx] = now

    if tree.curse and not giving and Store.Get(dreamer) == '' then
        Store.Set(dreamer, tree.curse, 'change')
    end
    -- the awaits above may have outlived them
    if not Shaman.SameChar(dreamer, charId) or dreams[dreamer] or Shaman.Form(dreamer) then return end

    local token = math.random(1, 2147483647)
    dreams[dreamer] = { tree = treeIdx, vision = tonumber(visionIndex), started = now, charId = charId, token = token }
    local dest = tree.destinations[math.random(1, #tree.destinations)]
    setBucket(dreamer, dreamer + Config.Instances.offset)
    TriggerClientEvent('pup_shaman:client:dream', dreamer, treeIdx, tonumber(visionIndex), dest)

    -- a vision the client never starts is cleared
    SetTimeout(rules.startTimeoutSec * 1000, function()
        local d = dreams[dreamer]
        if d and d.token == token and not d.confirmed then
            endDream(dreamer)
        end
    end)
end)

RegisterNetEvent('pup_shaman:server:dreamStarted', function()
    local d = dreams[source]
    if d then d.confirmed = true end
end)

RegisterNetEvent('pup_shaman:server:woke', function()
    local src = source
    local d = endDream(src)
    if not d or not d.confirmed then return end
    returnTo[d.charId] = nil
    local tree = Config.Trees[d.tree]
    local reward = tree and tree.reward
    if not reward or not reward.item then return end
    if os.time() - d.started < (reward.minutes or 0) * 60 then return end
    if not Shaman.SameChar(src, d.charId) then return end
    local count = math.max(1, math.floor(tonumber(reward.count) or 1))
    if not exports.vorp_inventory:canCarryItem(src, reward.item, count) then return end
    if not exports.vorp_inventory:addItem(src, reward.item, count) then return end
    local label = reward.label
    if not label then
        local item = exports.vorp_inventory:getItemDB(reward.item)
        label = item and item.label or reward.item
    end
    Shaman.Notify(src, L('dream_reward', count, label))
end)

-- leaving mid-vision: the character is put back at the tree when they next load
Shaman.OnLeave(function(src, _, oldCharId)
    local d = endDream(src)
    if d and d.confirmed then
        local tree = Config.Trees[d.tree]
        if tree then returnTo[d.charId or oldCharId] = tree.coords end
    end
end)

Shaman.OnSelect(function(src, char)
    local charId = tonumber(char.charIdentifier)
    local spot = returnTo[charId]
    if not spot then return end
    returnTo[charId] = nil
    TriggerClientEvent('pup_shaman:client:returnTo', src, spot)
end)
