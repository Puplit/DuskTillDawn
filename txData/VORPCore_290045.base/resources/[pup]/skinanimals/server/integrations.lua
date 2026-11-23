-- skinanimals | server/integrations.lua
-- Every call into another resource goes through here. A resource that is missing or
-- throws is treated as "no", with a single console warning per call.

Ext = {}

local warned = {}

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print('^3[skinanimals]^7 ' .. msg)
end

local function started(name)
    return GetResourceState(name) == 'started'
end

-- Calls fn under pcall; returns ok, value.
local function guarded(resource, name, fn)
    if not started(resource) then
        warnOnce(resource .. ':missing', resource .. ' is not running - ' .. name .. ' is skipped.')
        return false, nil
    end
    local ok, value = pcall(fn)
    if not ok then
        warnOnce(resource .. ':' .. name, resource .. ' ' .. name .. ' failed: ' .. tostring(value))
        return false, nil
    end
    return true, value
end

------------------------------------------------------------------------------- vorp_core
local core
function Ext.core()
    if core then return core end
    local ok, value = guarded('vorp_core', 'GetCore', function()
        return exports.vorp_core:GetCore()
    end)
    if ok and type(value) == 'table' then core = value end
    return core
end

-- The active character of a player, or nil.
function Ext.character(src)
    local c = Ext.core()
    if not c then return nil end
    local ok, user = pcall(c.getUser, src)
    if not ok or not user then return nil end
    local okChar, char = pcall(function() return user.getUsedCharacter end)
    if not okChar or type(char) ~= 'table' or not char.charIdentifier then return nil end
    return char
end

------------------------------------------------------------------------------- vorp_inventory
function Ext.canCarry(src, item, amount)
    local ok, v = guarded('vorp_inventory', 'canCarryItem', function()
        return exports.vorp_inventory:canCarryItem(src, item, amount)
    end)
    return ok and v == true
end

-- Returns true when the item was given.
function Ext.addItem(src, item, amount)
    local ok, v = guarded('vorp_inventory', 'addItem', function()
        return exports.vorp_inventory:addItem(src, item, amount, {})
    end)
    return ok and v == true
end

-- true when the inventory knows the item.
function Ext.itemExists(item)
    local ok, v = guarded('vorp_inventory', 'getItemDB', function()
        return exports.vorp_inventory:getItemDB(item)
    end)
    return ok and v ~= nil and v ~= false
end

------------------------------------------------------------------------------- pup-perks
function Ext.perkRoll(src, key)
    if not Config.Integrations.perks then return false end
    local ok, v = guarded('pup-perks', 'Roll', function()
        return exports['pup-perks']:Roll(src, key)
    end)
    return ok and v == true
end

function Ext.perkHas(src, key)
    local ok, v = guarded('pup-perks', 'Has', function()
        return exports['pup-perks']:Has(src, key)
    end)
    return ok and v == true
end

function Ext.perkAward(src, kind)
    if not Config.Integrations.perks then return end
    guarded('pup-perks', 'Award', function()
        exports['pup-perks']:Award(src, kind)
    end)
end

------------------------------------------------------------------------------- pup-stable
function Ext.horseBond(src)
    if not Config.Integrations.horseBond then return end
    guarded('pup-stable', 'HorseCareReward', function()
        exports['pup-stable']:HorseCareReward(src, 'skin')
    end)
end
