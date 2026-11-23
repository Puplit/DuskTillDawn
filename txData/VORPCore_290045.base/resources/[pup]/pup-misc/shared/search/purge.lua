-- search | the rules in force right now, and the purge swap. Loaded on BOTH sides
-- after config/search/*.lua. Every rule that the purge changes is read from
-- SearchRules, never straight from SearchConfig, so flipping the purge is one
-- assignment and the normal values are never lost.

local function toSet(list, upper)
    local set, n = {}, 0
    for _, v in ipairs(list or {}) do
        local key = upper and tostring(v):upper() or tostring(v)
        if not set[key] then
            set[key] = true
            n = n + 1
        end
    end
    return set, n
end

local function copyList(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = v end
    return out
end

local function buildRules(purge)
    local src = purge and SearchConfig.Purge or nil
    local bl = SearchConfig.Blacklist or {}
    local rules = {
        purge = purge == true,
        deadSearch = SearchConfig.Targets.dead == true,
        shieldMinutes = tonumber(purge and src.shieldMinutes or SearchConfig.Limits.shieldMinutes) or 0,
        maxStacks = tonumber(purge and src.maxStacks or SearchConfig.Limits.maxStacks) or 0,
        windowMinutes = tonumber(purge and src.windowMinutes or SearchConfig.Limits.windowMinutes) or 0,
        protectedJobs = copyList(purge and src.protectedJobs or SearchConfig.Duty.protectedJobs),
        prefixes = copyList(purge and src.blacklistPrefixes or bl.prefixes),
    }
    if purge then rules.deadSearch = src.deadSearch == true end
    rules.protectedSet, rules.protectedCount = toSet(rules.protectedJobs)
    rules.itemSet, rules.itemCount = toSet(purge and src.blacklistItems or bl.items)
    rules.weaponSet, rules.weaponCount = toSet(purge and src.blacklistWeapons or bl.weapons, true)
    return rules
end

SearchRules = buildRules(false)

local purgeOn = false

function SearchPurgeActive()
    return purgeOn
end

-- applies (or re-applies) the purge state; prints one line when it actually flips
function SearchSetPurge(on)
    on = on == true
    local flipped = on ~= purgeOn
    purgeOn = on
    SearchRules = buildRules(on)
    if flipped then
        local side = IsDuplicityVersion() and 'server' or 'client'
        print(('^3[pup-misc/search %s]^7 %s'):format(side, on and SearchLocale.purgeOn or SearchLocale.purgeOff))
    end
end
