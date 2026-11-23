-- pup-magic | who may cast. Server only. Character ids (charidentifier), e.g. puppet = { 42, 57 }

MagicCasters = {
    puppet = {},
    reze   = {},
    flex   = {}, -- flex emote only, on top of puppet and reze
}

for name, list in pairs(MagicCasters) do
    for _, id in ipairs(list) do
        if math.type(id) ~= 'integer' then
            print(("^3[pup-magic]^7 casters.%s: '%s' isn't a character id, ignored"):format(name, tostring(id)))
        end
    end
end

for id, spell in pairs(Config.Spells) do
    for _, group in ipairs(spell.casters or {}) do
        if not MagicCasters[group] then
            print(("^3[pup-magic]^7 spell '%s' names caster group '%s', which isn't in server/casters.lua"):format(id, tostring(group)))
        end
    end
end
