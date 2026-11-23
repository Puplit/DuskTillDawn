-- pup-magic | checks config/spells.lua on the client and the server
-- A spell with a mistake is removed from Config.Spells (with a warning), so neither side ever acts on it.
-- MagicKeys = { { raw = 97, id = 'smoke' }, ... }: the keys the client listens for while Alt is held.

local EFFECTS <const> = {
    smoke = true, lightning = true, shock = true, transform = true, aimdot = true, anim = true,
    aura = true, bombpunch = true, bombtoss = true, rocketleap = true, detonate = true,
}

-- key names to Windows virtual-key codes (what IsRawKeyReleased takes)
local KEYS = {}
for i = 0, 9 do
    KEYS['NUMPAD' .. i] = 96 + i
    KEYS[tostring(i)] = 48 + i
end
for i = 0, 25 do KEYS[string.char(65 + i)] = 65 + i end
for i = 1, 12 do KEYS['F' .. i] = 111 + i end

local function warn(msg)
    print(('^3[pup-magic spells]^7 %s'):format(msg))
end

local function rawKey(k)
    if type(k) == 'number' then return math.floor(k) end
    if type(k) == 'string' then return KEYS[k:upper()] end
    return nil
end

local function check()
    local keys, taken = {}, {}
    local ids = {}
    for id in pairs(Config.Spells or {}) do ids[#ids + 1] = id end
    table.sort(ids) -- the same warnings in the same order every start

    for _, id in ipairs(ids) do
        local s = Config.Spells[id]
        local bad
        if type(s) ~= 'table' then
            bad = 'is not a table'
        elseif not EFFECTS[s.effect] then
            bad = ("effect '%s' doesn't exist"):format(tostring(s.effect))
        elseif type(s.casters) ~= 'table' or #s.casters == 0 then
            bad = "needs casters = { 'groupname' }"
        elseif s.effect == 'anim' and not (type(s.anim) == 'table' and s.anim.dict and s.anim.name) then
            bad = 'needs anim = { dict, name }'
        elseif s.effect == 'aura' and not (type(s.fx) == 'table' and ((s.fx.dict and s.fx.name) or (type(s.fx[1]) == 'table' and s.fx[1].dict and s.fx[1].name))) then
            bad = 'needs fx = { dict, name, ... } (or a list of those)'
        elseif s.effect == 'smoke' and not (type(s.fx) == 'table' and s.fx.asset and s.fx.name) then
            bad = 'needs fx = { asset, name, ... }'
        elseif s.effect == 'transform' and type(s.model) ~= 'string' then
            bad = "needs model = 'A_C_...'"
        elseif s.requires and not (Config.Spells[s.requires] and Config.Spells[s.requires].effect == 'aura') then
            bad = ("requires '%s', which isn't a toggle (aura) spell"):format(tostring(s.requires))
        end

        if bad then
            warn(('%s %s, skipped'):format(id, bad))
            Config.Spells[id] = nil
        else
            local list = s.keys or { s.key }
            for _, k in ipairs(list) do
                local raw = rawKey(k)
                if not raw then
                    warn(("%s: key '%s' isn't a key name I know, that key is skipped"):format(id, tostring(k)))
                elseif taken[raw] then
                    warn(("%s: key '%s' is already %s's, that key is skipped"):format(id, tostring(k), taken[raw]))
                else
                    taken[raw] = id
                    keys[#keys + 1] = { raw = raw, id = id }
                end
            end
        end
    end
    return keys
end

MagicKeys = check()
