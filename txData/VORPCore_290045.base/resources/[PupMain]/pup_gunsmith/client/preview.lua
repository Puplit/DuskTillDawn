-- pup_gunsmith | watching someone else's bench: their gun, its parts and how it is turned
-- One gun per bench user. Every event comes from the server, which only relays
-- what the bench user is allowed to show.

Preview = { guns = {} } -- [owner server id] = gun
local tokens = {}       -- [owner] = bumped on every show/hide, so a slow spawn can tell it is stale

local benchById = {}
for _, b in ipairs(Config.Benches) do benchById[b.id] = b end

local function drop(owner)
    local g = Preview.guns[owner]
    if g then
        GunObj.delete(g)
        Preview.guns[owner] = nil
    end
end

RegisterNetEvent('pup_gunsmith:pvShow', function(owner, benchId, hash, name, family, parts, rot)
    if type(owner) ~= 'number' or type(hash) ~= 'number' or type(name) ~= 'string' then return end
    local bench = benchById[benchId]
    if not bench then return end
    tokens[owner] = (tokens[owner] or 0) + 1
    local mine = tokens[owner]
    drop(owner)
    local gun = GunObj.spawn(hash, bench.gun)
    if not gun then return end
    if tokens[owner] ~= mine then -- hidden or replaced while the model was loading
        GunObj.delete(gun)
        return
    end
    gun.catalogue = Catalogue.build(name, Catalogue.isFamily(family) and family or nil)
    GunObj.fitAll(gun, gun.catalogue, GS.cleanParts(parts, Config.Bench.maxParts))
    if type(rot) == 'table' then
        GunObj.rotate(gun, tonumber(rot[1]) or 0.0, tonumber(rot[2]) or 0.0, tonumber(rot[3]) or 0.0)
    end
    Preview.guns[owner] = gun
end)

RegisterNetEvent('pup_gunsmith:pvPart', function(owner, cat, comp, clear)
    local gun = Preview.guns[owner]
    if not gun or type(cat) ~= 'string' then return end
    local variants = {}
    if type(clear) == 'table' then
        for _, v in ipairs(clear) do
            if type(v) == 'string' then variants[#variants + 1] = v end
        end
    end
    GunObj.swap(gun, variants, type(comp) == 'string' and comp or nil)
end)

RegisterNetEvent('pup_gunsmith:pvTurn', function(owner, rx, ry, rz)
    local gun = Preview.guns[owner]
    if not gun then return end
    GunObj.rotate(gun, tonumber(rx) or 0.0, tonumber(ry) or 0.0, tonumber(rz) or 0.0)
end)

RegisterNetEvent('pup_gunsmith:pvHide', function(owner)
    if type(owner) ~= 'number' then return end
    tokens[owner] = (tokens[owner] or 0) + 1
    drop(owner)
end)

function Preview.clearAll()
    for owner in pairs(Preview.guns) do
        tokens[owner] = (tokens[owner] or 0) + 1
        drop(owner)
    end
end
