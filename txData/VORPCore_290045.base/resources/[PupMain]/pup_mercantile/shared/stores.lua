-- pup_mercantile | builds the NPC store list from config/stores.lua (client and server)
-- NpcStoreList[i] = { name, pos = { x, y, z }, blip = icon hash or nil, jobs = { job, ... },
--                     sell = { row, ... }, buy = { row, ... }, gate, menuOnly }
-- row = { name, label, price, type }: sell rows are what players buy, buy rows what they sell.

NpcStoreList = {}

local GOODS <const> = Config.StoreGoods or {}
local KINDS <const> = Config.StoreKinds or {}

local function rows(names, prices, storeName)
    local out = {}
    for _, item in ipairs(names or {}) do
        local g = GOODS[item]
        if type(g) == 'table' then
            out[#out + 1] = {
                name = item,
                label = g[1],
                price = prices[item] or g[2],
                type = g.weapon and 'item_weapon' or 'item_standard',
            }
        else
            print(('^3[pup_mercantile]^7 %s lists %s, which is not in Config.StoreGoods'):format(storeName, tostring(item)))
        end
    end
    return out
end

for _, site in ipairs(Config.StoreSites or {}) do
    local kind = KINDS[site.kind]
    if type(kind) ~= 'table' then
        print(('^3[pup_mercantile]^7 store %s has unknown kind %s; skipped'):format(tostring(site.name), tostring(site.kind)))
    else
        local at = site.at or {}
        local blip = site.blip
        if blip == nil then blip = kind.blip end
        local prices = site.prices or {}
        NpcStoreList[#NpcStoreList + 1] = {
            name = site.name,
            pos = { x = at[1], y = at[2], z = at[3] },
            blip = blip or nil,
            jobs = site.jobs or {},
            sell = rows(kind.sells, prices, site.name),
            buy = rows(kind.buys, prices, site.name),
            gate = site.gate,
            menuOnly = site.menuOnly == true,
        }
    end
end
