-- boatshops | upgrades (shared)
-- [category][boat key] = { { name, value, price }, ... } shown in this order.
-- value 'none' removes that category's upgrade. Only keys in BoatConfig.Boats are
-- ever shown; the others are kept for boats that may be added later.

local function tints(count, price)
    local list = { { name = 'remove', value = 'none', price = 0 } }
    for i = 1, count do
        list[#list + 1] = { name = 'tint ' .. i, value = i, price = price }
    end
    return list
end

BoatConfig.Upgrades = {
    Extras = {
        keelboat = { { name = 'extra 1', value = 5, price = 2 }, { name = 'remove', value = 'none', price = 0 } },
        rowboat = { { name = 'extra 1', value = 1, price = 2 }, { name = 'remove', value = 'none', price = 0 } },
        rowboatSwamp = { { name = 'extra 1', value = 5, price = 2 }, { name = 'remove', value = 'none', price = 0 } },
        rowboatSwamp02 = { { name = 'extra 1', value = 5, price = 2 }, { name = 'remove', value = 'none', price = 0 } },

        -- not in the catalogue
        ship_guama02 = { { name = 'extra 1', value = 1, price = 2 }, { name = 'remove', value = 'none', price = 0 } },
        ship_nbdGuama2 = {
            { name = 'extra 2', value = 1, price = 1 }, { name = 'extra 1', value = 2, price = 2 },
            { name = 'extra 2', value = 3, price = 2 }, { name = 'remove', value = 'none', price = 0 },
        },
        TugBoat2 = {
            { name = 'extra 1', value = 1, price = 2 }, { name = 'extra 2', value = 2, price = 2 },
            { name = 'remove', value = 'none', price = 0 },
        },
        smuggler02 = (function()
            local list = {}
            for i = 1, 16 do list[#list + 1] = { name = 'extra ' .. i, value = i, price = 2 } end
            list[#list + 1] = { name = 'remove', value = 'none', price = 2 }
            return list
        end)(),
    },

    Propsets = {
        keelboat = {
            { name = 'lantern 1', value = 'pg_veh_keelboat_lanterns_1', price = 2 },
            { name = 'propset 1', value = 'pg_veh_keelboat_01', price = 2 },
            { name = 'propset 2', value = 'pg_veh_keelboat_02', price = 2 },
            { name = 'propset 3', value = 'pg_veh_keelboat_03', price = 2 },
            { name = 'remove', value = 'none', price = 0 },
        },
        rowboat = {
            { name = 'lantern 1', value = 'pg_veh_rowboat_lightupgrade_1', price = 3 },
            { name = 'lantern 2', value = 'pg_veh_rowboat_lightupgrade_2', price = 5 },
            { name = 'lantern 3', value = 'pg_veh_rowboat_lightupgrade_3', price = 5 },
            { name = 'roaboat 1', value = 'pg_veh_rowboat_01', price = 5 },
            { name = 'roaboat 2', value = 'pg_veh_rowboat_02', price = 5 },
            { name = 'supplies 1', value = 'pg_mp_veh_rowboat_supplies01', price = 5 },
            { name = 'supplies 2', value = 'pg_mp_veh_rowboat_supplies02', price = 5 },
            { name = 'supplies 3', value = 'pg_mp_veh_rowboat_supplies03', price = 5 },
            { name = 'supplies 4', value = 'pg_mp_veh_rowboat_supplies04', price = 5 },
            { name = 'remove', value = 'none', price = 0 },
        },
        rowboatSwamp = {
            { name = 'swamp 1', value = 'pg_veh_rowboatswamp_01', price = 4 },
            { name = 'swamp 2', value = 'pg_veh_rowboatswamp_02', price = 4 },
            { name = 'supplies 1', value = 'pg_mp_veh_rowboatswamp_supplies01', price = 4 },
            { name = 'supplies 2', value = 'pg_mp_veh_rowboatswamp_supplies02', price = 4 },
            { name = 'supplies 3', value = 'pg_mp_veh_rowboatswamp_supplies03', price = 4 },
            { name = 'supplies 4', value = 'pg_mp_veh_rowboatswamp_supplies04', price = 4 },
            { name = 'remove', value = 'none', price = 0 },
        },
        rowboatSwamp02 = {
            { name = 'fetch 1', value = 'pg_mp006_fetch_rowboatswamp02_1', price = 4 },
            { name = 'remove', value = 'none', price = 0 },
        },
        boatsteam02x = {
            { name = 'propset', value = 'pg_veh_boatsteam02x_1', price = 8 },
            { name = 'remove', value = 'none', price = 0 },
        },
        canoe = {
            { name = 'propset 1', value = 'pg_veh_canoe_01', price = 8 },
            { name = 'propset 2', value = 'pg_veh_canoe_02', price = 8 },
            { name = 'remove', value = 'none', price = 8 },
        },
        pirogue = {
            { name = 'propset 1', value = 'pg_veh_pirogue_01', price = 8 },
            { name = 'remove', value = 'none', price = 0 },
        },

        -- not in the catalogue
        HORSEBOAT = {
            { name = 'propset 1', value = 'pg_veh_horseboat_1', price = 4 },
            { name = 'lantern 1', value = 'pg_veh_horseboat_1_lights', price = 4 },
            { name = 'wreckage', value = 'pg_veh_horseboat_1_wreckage', price = 4 },
            { name = 'remove', value = 'none', price = 0 },
        },
        turbineboat = {
            { name = 'lantern 1', value = 'pg_veh_turbineboat01x_lights', price = 4 },
            { name = 'remove', value = 'none', price = 4 },
        },
        SHIP_GUAMA02 = {
            { name = 'lantern 1', value = 'pg_veh_shipguama02_lights01x', price = 6 },
            { name = 'med', value = 'pg_veh_shipguama02_med', price = 6 },
            { name = 'storm', value = 'pg_veh_shipGuama02_storm1x', price = 6 },
            { name = 'remove', value = 'none', price = 6 },
        },
        ship_nbdGuama2 = {
            { name = 'guama 1', value = 'pg_veh_shipnbdguama2_1', price = 6 },
            { name = 'lantern 1', value = 'pg_veh_shipnbdguama2_1_lights', price = 6 },
            { name = 'remove', value = 'none', price = 6 },
        },
        ship_nbdguama = {
            { name = 'lantern 1', value = 'pg_veh_nbdguama_lights01x', price = 5 },
            { name = 'remove', value = 'none', price = 5 },
        },
        tugboat2 = {
            { name = 'lights', value = 'pg_veh_tugboat2_lights01x', price = 8 },
            { name = 'moonshiner', value = 'pg_moonshiner3_tugboat2_1', price = 8 },
            { name = 'tugboat', value = 'pg_veh_tugboat2_1', price = 8 },
            { name = 'remove', value = 'none', price = 8 },
        },
    },

    Liveries = {
        boatsteam02x = {
            { name = 'AnnieMay', value = 0, price = 2 },
            { name = 'Calliope', value = 1, price = 3 },
            { name = 'LaChuparrosa', value = 2, price = 2 },
            { name = 'Magicienne', value = 3, price = 3 },
        },
    },

    Tints = {
        boatsteam02x = tints(6, 3),
        canoe = tints(5, 3),
        canoeTreeTrunk = tints(1, 3),
        keelboat = tints(5, 3),
        pirogue = tints(5, 3),
        pirogue2 = tints(7, 3),
        rowboat = tints(7, 3),
        rowboatSwamp = tints(6, 3),
        rowboatSwamp02 = tints(6, 3),

        -- not in the catalogue
        ship_nbdGuama2 = { { name = 'remove', value = 'none', price = 0 }, { name = 'tint 1', value = 1, price = 3 }, { name = 'tint 2', value = 2, price = 3 } },
        tugboat2 = tints(8, 3),
        TugBoat3 = (function()
            local list = tints(4, 3)
            list[1].price = 3
            return list
        end)(),
        rcBoat = { { name = 'tint', value = 0, price = 3 } },
        SHIP_GUAMA02 = { { name = 'tint', value = 0, price = 3 } },
        ship_nbdGuama = { { name = 'tint', value = 0, price = 3 } },
        smuggler02 = { { name = 'tint', value = 0, price = 3 } },
        steamerdummy = { { name = 'tint', value = 0, price = 3 } },
        turbineboat = { { name = 'tint', value = 0, price = 3 } },
        HORSEBOAT = { { name = 'tint', value = 0, price = 3 } },
    },
}
