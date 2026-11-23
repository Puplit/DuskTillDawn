-- pup_hideouts | interior layouts, recovery spots and other game names

Config = Config or {}

Config.Zones = {
    lemoyne = {
        interior = 77313,
        outside  = vector3(1786.26, -820.11, 192.59), -- not used as a door: every hideout has its own door coords
        inside   = vector3(1785.01, -821.53, 191.01),
        insideHeading = 0.0,
        seat     = { coords = vector3(1789.48, -812.1, 192.10), heading = 536.57, scenario = 'MP_LOBBY_PROP_HUMAN_SEAT_CHAIR' },
        mashSpot  = { coords = vector3(1792.71, -818.89, 189.40), heading = 64.73 },
        stillSpot = { coords = vector3(1794.37, -818.9, 189.40), heading = 219.5 },
        workAnim  = { dict = 'script_re@moonshine_camp@player_put_in_herbs', name = 'put_in_still', seconds = 7 },
        ledgerText = vector3(1789.48, -813.1, 192.40),
        stash  = vector3(1784.12, -817.1, 189.4),
        bar    = { coords = vector3(1779.63, -801.65, 188.9), heading = 223.7 },
        wash   = vector3(1785.75, -806.36, 188.95),
        bookie = vector3(1772.29, -806.41, 188.95),
        fighterA = { coords = vector3(1775.66, -811.12, 188.99), heading = 44.8 },
        fighterB = { coords = vector3(1774.9, -810.5, 188.95), heading = 225.3 },
        still  = vector3(1793.8, -819.4, 189.4),
        themeDoors = {
            { hash = 3852416013, rot = vector3(-0.0, 0.0, -137.38) },
            { hash = 4091334792, rot = vector3(0.0, 0.0, 42.72) },
        },
        lockedDoors = {
            { hash = 2422396838, rot = vector3(0.0, 0.0, -46.6) },
            { hash = 2116104995, rot = vector3(0.0, -7.63, -46.8) },
        },
    },
}
Config.DefaultZone = 'lemoyne'

-- stuck-player recovery: the spot nearest the saved last position; the first is the default
Config.FallbackSpots = {
    { name = 'Valentine',  coords = vector3(-283.83, 806.4, 119.38) },
    { name = 'Saint',      coords = vector3(2721.4562, -1446.0975, 46.2303) },
    { name = 'Armadillo',  coords = vector3(-3742.5, -2600.9, -13.23) },
    { name = 'bw',         coords = vector3(-723.9527, -1242.8358, 44.7341) },
    { name = 'rhodes',     coords = vector3(1229.0, -1306.1, 76.9) },
    { name = 'anned',      coords = vector3(2955.95, 1304.94, 44.53) },
    { name = 'vanhorn',    coords = vector3(2973.06, 562.55, 44.5) },
    { name = 'straw',      coords = vector3(-1747.29, -362.9, 169.5) },
    { name = 'snow',       coords = vector3(-1459.6, 1634.11, 243.2) },
    { name = 'tumbleweed', coords = vector3(-5513.53, -2930.86, -2.23) },
}

Config.Imaps = {
    'MP006_A3SUPP_MOONSHINE01', 'MP006_A3SUPP_MOONSHINE01_PLUG',
    'MP006_A2SUPP_MOONSHINE02', 'MP006_A2SUPP_MOONSHINE02_PLUG',
    'MP006_A4SUPP_MOONSHINE03', 'MP006_A4SUPP_MOONSHINE03_PLUG',
    'MP006_A1SUPP_MOONSHINE04', 'MP006_A1SUPP_MOONSHINE04_PLUG',
    'MP006_A4SUPP_MOONSHINE05', 'MP006_A4SUPP_MOONSHINE05_PLUG',
}

Config.Anims = {
    picklock = { dict = 'script_proc@rustling@olar@player_picklock', name = 'base' },
    trade    = { dict = 'script_re@new_love@give_ring', name = 'give_ring_player' },
    crooked  = { dict = 'amb_rest_drunk@world_human_drinking@male_a@idle_a', name = 'idle_a' },
}
Config.AlertBlip = { sprite = 639638961, color = 0x6F85C3CE }
Config.Lasso = 'WEAPON_LASSO'
