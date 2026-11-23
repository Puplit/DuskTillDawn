-- pup_gunsmith | character-select and ammo-wipe hooks, retired events, start-up

-- the client asks after a character select: clear the second-slot flag on that character's guns
RegisterNetEvent('pup_gunsmith:clearSecondSlot', function()
    local src = source
    if not Srv.validSource(src) then return end
    if not Srv.throttle(src, 'clearSecondSlot', 5000) then return end
    local char = Srv.char(src)
    if not char then return end
    MySQL.update('UPDATE loadout SET used2 = 0 WHERE charidentifier = ?', { char.charIdentifier })
end)

-- the client asks after pup_gunsmith:removeallammo: empty its own character's stored ammo
RegisterNetEvent('pup_gunsmith:clearStoredAmmo', function()
    local src = source
    if not Srv.validSource(src) then return end
    if not Srv.throttle(src, 'clearStoredAmmo', 2000) then return end
    local char = Srv.char(src)
    if not char then return end
    MySQL.update("UPDATE characters SET ammo = '{}' WHERE charidentifier = ?", { char.charIdentifier })
end)

---------------------------------------------------------------------------
-- retired network events: logged, never acted on
---------------------------------------------------------------------------
local RETIRED <const> = {
    'checkmoney_secure', 'addcomp', 'gunsmithRepair', 'upgradeTier',
    'weaponobjectserver', 'deleteobjectserver', 'rotate', 'removemod', 'applymoddglobal',
    'buythings', 'itemscheck', 'minigamecheck2', 'addammo', 'givebackbox', 'getjob',
    'getplayerweapons', 'openCraftStorage',
}

for _, name in ipairs(RETIRED) do
    local full = 'pup_gunsmith:' .. name
    RegisterNetEvent(full, function()
        local src = source
        if not Srv.throttle(src, 'retired', 1000) then return end
        print(('^3[pup_gunsmith]^7 ignored retired event %s from %s'):format(full, Srv.who(src)))
    end)
end

-- a retired payment event: nothing legitimate sends it, so a sender is flagged
RegisterNetEvent('pup_gunsmith:checkmoney', function()
    local src = source
    print(('^1[pup_gunsmith SECURITY] cheater detected: %s fired the legacy payment event^7'):format(Srv.who(src)))
    if Config.Security.kickLegacyPayment then
        DropPlayer(tostring(src), 'Anti-Cheat: Attempted to trigger legacy payment event.')
    end
end)

---------------------------------------------------------------------------
-- start-up
---------------------------------------------------------------------------
MySQL.ready(function()
    CreateThread(function()
        if Schema.ensure() then
            Stations.seedIfEmpty()
            Stations.load()
            Recipes.seedIfEmpty()
            Recipes.load()
        else
            print('^1[pup_gunsmith]^7 the database is not usable - the seed recipes stay live and there are no crafting stations')
        end
        -- runs either way, so the live (or seed) ammo boxes stay usable
        Ammo.startup()
    end)
end)
