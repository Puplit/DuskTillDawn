-- pup_gunsmith | putting saved parts back on the gun in hand
-- vorp_inventory's client sends pup_gunsmith:weaponused when a weapon is used from the
-- inventory and when weapons are restored at spawn.

local function trace(fmt, ...)
    if Config.Debug.components then print(('[pup_gunsmith comps] ' .. fmt):format(...)) end
end

RegisterNetEvent('pup_gunsmith:weaponused', function(payload)
    local src = source
    if not Srv.validSource(src) then return end
    if type(payload) ~= 'table' or payload.type ~= 'item_weapon' then return end
    -- vorp_inventory's NUI path forwards its raw NUI payload, where the id may be a numeric string
    local id = tonumber(payload.id)
    if not id or id ~= id or id <= 0 then return end
    id = math.floor(id)
    local char = Srv.char(src)
    if not char then return end
    -- a burst at spawn restores several guns at once; anything beyond that is spam
    if not Srv.throttle(src, 'weaponused:' .. id, 400) then return end

    -- the id must be one of this character's weapons
    local ok, row = pcall(MySQL.single.await, 'SELECT charidentifier, name FROM loadout WHERE id = ?', { id })
    if not ok or not row or tostring(row.charidentifier) ~= tostring(char.charIdentifier) then
        trace('%s named weapon %d that is not theirs - ignored', Srv.who(src), id)
        return
    end
    if not Srv.same(src, char) then return end

    local okC, comps = pcall(function() return Inv:getWeaponComponents(src, id) end)
    if not okC or type(comps) ~= 'table' or next(comps) == nil then return end
    local hash = joaat(tostring(row.name):upper())

    TriggerClientEvent('vorp_inventory:setComponents', src, id, comps)
    TriggerClientEvent('pup_gunsmith:refit', src, comps, id, hash)
    if Config.Debug.components then
        for cat, comp in pairs(comps) do trace('weapon %d -> %s = %s', id, tostring(cat), tostring(comp)) end
    end
end)

-- vorp_inventory's dual-wield equip; nothing to do here beyond the trace
RegisterNetEvent('pup_gunsmith:applyDupeTint', function(id, _, weaponHash)
    trace('applyDupeTint from %s: weapon %s hash %s', Srv.who(source), tostring(id), tostring(weaponHash))
end)

-- server-local only (vorp_inventory after a loadout insert); deliberately not a net event
AddEventHandler('pup_gunsmith:registerWeapon', function(weaponId)
    trace('registerWeapon %s', tostring(weaponId))
end)
