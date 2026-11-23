-- pup-misc/outfitter | what the stable sells (see README)

OutfitterConfig.Camps = {
    { sku = 'tent_leanto',    model = 'pg_ambcamp01x_tent_canvas_leanto01',        label = 'Simple Tent',             price = 25 },
    { sku = 'picnic',         model = 'pg_ambient_camp_add_picnic01',              label = 'Picnic Spread',           price = 25 },
    { sku = 'poker',          model = 'pg_mg_poker',                               label = 'Poker Set',               price = 25 },
    { sku = 'hitch_trainer',  model = 'PG_COMPANIONACTIVITY_RUSTLING',             label = 'Horse Trainers Hitch',    price = 25 },
    { sku = 'umbrella',       model = 'pg_ambient_camp_add_umbrella01',            label = 'Umbrella',                price = 25 },
    { sku = 'gamepole',       model = 'pg_ambient_camp_add_gamepole01',            label = 'Game Pole',               price = 25 },
    { sku = 'lamppost',       model = 'pg_ambient_camp_add_lamppost01',            label = 'Lamp Post',               price = 25 },
    { sku = 'native_kit',     model = 'pg_ambient_camp_add_native01',              label = 'Native Equipment',        price = 25 },
    { sku = 'tent_hide',      model = 'pg_ambcamp01x_tent_hide',                   label = 'Simple Hunters Tent',     price = 25 },
    { sku = 'tent_bounty_s',  model = 'pg_mp_possecamp_tent_bounty04x',            label = 'Simple Bounty Tent',      price = 25 },
    { sku = 'tent_collect_s', model = 'pg_mp_possecamp_tent_collector04x',         label = 'Simple Collectors Tent',  price = 25 },
    { sku = 'tent_leanto2',   model = 'pg_ambcamp01x_tent_canvas_leanto02',        label = 'Simple Tent 2',           price = 40 },
    { sku = 'tent_tall',      model = 'pg_ambcamp01x_tent_canvas_tall02',          label = 'Adventure Tent',          price = 40 },
    { sku = 'explorer_gear',  model = 'pg_ambient_camp_add_explore',               label = 'Explorers Gear',          price = 40 },
    { sku = 'robbery_gear',   model = 'PG_COMPANIONACTIVITY_ROBBERY',              label = 'Robbery Planning Gear',   price = 40 },
    { sku = 'camp_hunter',    model = 'PG_MP_CAMPTRACK306X',                       label = 'Hunters Camp',            price = 90 },
    { sku = 'camp_hunter2',   model = 'PG_HUNTERCAMP01X',                          label = 'Hunters Camp 2',          price = 90 },
    { sku = 'firepit_big',    model = 'PG_MP_POSSECAMP_CAMPFIRE_LARGE002X',        label = 'Big Camp Fire',           price = 90 },
    { sku = 'camp_goldpan',   model = 'pg_goldpanner01x',                          label = 'Goldpanners Camp',        price = 90 },
    { sku = 'snakeoil',       model = 'pg_mp_snakesales01x',                       label = 'Snakeoil Sales Kit',      price = 90 },
    { sku = 'camp_lumber',    model = 'PG_BH_RANCHER01X',                          label = 'Lumberjacks Camp',        price = 90 },
    { sku = 'camp_winter',    model = 'PG_AMBIENT_CAMPFIREWINTER01X',              label = 'Simple Camp',             price = 90 },
    { sku = 'wagon_butcher',  model = 'pg_ambient_camp_add_packwagoncookprep01',   label = 'Butchers Wagon',          price = 90 },
    { sku = 'camp_snow',      model = 'pg_ambcamp02x_tent_snow',                   label = 'Mountain Survival Camp',  price = 90 },
    { sku = 'camp_herbal',    model = 'pg_herbalistcamp01x',                       label = 'Herbalist Camp',          price = 175 },
    { sku = 'wagon_collect',  model = 'PG_MP005_COLLECTORWAGONCAMP01',             label = 'Collectors Wagon',        price = 175 },
    { sku = 'wagon_natural',  model = 'pg_mp007_naturalist_camp01x',               label = 'Naturalists Wagon',       price = 175 },
    { sku = 'camp_moonshine', model = 'pg_moonshinecampgroup01x',                  label = 'Moonshine Camp',          price = 175 },
    { sku = 'tent_bounty',    model = 'pg_mp_possecamp_tent_bounty07x',            label = 'Bounty Hunters Tent',     price = 175 },
    { sku = 'tent_trader',    model = 'pg_mp_possecamp_tent_trader07x',            label = 'Traders Tent',            price = 175 },
    { sku = 'tent_collect',   model = 'pg_mp_possecamp_tent_collector07x',         label = 'Collectors Tent',         price = 175 },
    { sku = 'tent_explorer',  model = 'PG_MP_POSSECAMP_EXPLORERTENT01X',           label = 'Explorers Tent',          price = 175 },
    { sku = 'caravan',        model = 'pg_mp_possecamp_followercaravan_large000x', label = 'Caravaners Tent',         price = 175 },
    { sku = 'caravan2',       model = 'PG_MP_POSSECAMP_FOLLOWERTENT_LARGE000X',    label = 'Caravaners Tent 2',       price = 175 },
    { sku = 'hitches',        model = 'pg_mp_posseCamp_horseEnclo_exlrg_combined', label = 'Horse Hitches',           price = 175 },
    { sku = 'tent_merchant',  model = 'pg_mp_possecamp_merchanttent',              label = 'Merchants Tent',          price = 175 },
    { sku = 'camp_mountain',  model = 'pg_re_mountainmen01x',                      label = 'Mountain Men Camp',       price = 175 },
    { sku = 'camp_shine_big', model = 'PG_MISSION_GRAYS1_SHOOTOUT01X',             label = 'Large Moonshine Camp',    price = 400 },
}

OutfitterConfig.Gear = {
    { sku = 'hitchingpost', model = 'p_hitchingpost01x', label = 'Hitching Post', price = 15 },
    { sku = 'campfire',     model = 'p_campfire04x',     label = 'Campfire',      price = 30 },
}

-- Nothing to edit below: sku -> entry, with the kind attached.
OutfitterIndex = {}
for _, v in ipairs(OutfitterConfig.Camps) do
    OutfitterIndex[v.sku] = { sku = v.sku, model = v.model, label = v.label, price = v.price, kind = 'camp' }
end
for _, v in ipairs(OutfitterConfig.Gear) do
    OutfitterIndex[v.sku] = { sku = v.sku, model = v.model, label = v.label, price = v.price, kind = 'gear' }
end
