-- pup-events | purge cache helpers (shared). Settings are in config/purgecaches.lua.

-- a site whose pos is missing or 0,0,0 is not filled in yet, so it is skipped
function PurgeLootConfigured(site)
    return site ~= nil and site.pos ~= nil
        and not (site.pos.x == 0.0 and site.pos.y == 0.0 and site.pos.z == 0.0)
end
