-- pup-misc/bountyhunting | capture contracts (see README)
-- One line per contract, listed under the board town that posts it:
--   name, notice  what the board says (name = the wanted man)
--   at            his camp; he stands near it, his guards spread around (spread metres, default Spread.guards)
--   drop          where he is handed in alive (default: that town's board)
--   tier          1 Petty, 2 Wanted, 3 Notorious (see Tiers in main.lua): bigger parties meet more wanted men
--   gang          ped pool from peds.lua (the wanted men and their guards)
--   extra, pay    optional: guards added at every party size, purse factor

local v = vector3

BountyConfig.Arrest = BountyConfig.build('arrest', {
    valentine = {
        { name = "Hollis 'Sour Mash' Dempsey", tier = 2, gang = 'hillfolk',
          notice = 'Wanted alive for selling bad liquor in Valentine that left two men blind. He sleeps beside his still.',
          at = v(-1085.63, 714.14, 103.32) },
        { name = 'Silas Thorne', tier = 1, gang = 'roadagents',
          notice = 'Wanted alive for stealing the oil company payroll. Hiding along the tracks east of town with a few friends.',
          at = v(613.963, 683.593, 114.517) },
        { name = 'Mad Jeb Ransome', tier = 3, gang = 'hillfolk', spread = 12.0, pay = 1.1,
          notice = 'Wanted alive for murdering a survey party in the Grizzlies. The court wants him on the gallows, not in a grave.',
          at = v(1003.714, 1703.744, 379.191) },
        { name = 'Lyle Brannigan', tier = 2, gang = 'dusters',
          notice = 'Wanted alive for holding up the Flatneck stage. His gang rides with him, so bring help.',
          at = v(69.6194, -375.174, 90.0691) },
    },

    annesburg = {
        { name = 'Abel Crane', tier = 1, gang = 'claimjumpers',
          notice = 'Wanted alive for blasting a rival claim with the owners still inside.',
          at = v(2736.53, 1947.44, 160.59) },
        { name = "Vernon 'Two Fingers' Pike", tier = 3, gang = 'hiredguns', pay = 1.15,
          notice = 'Wanted alive for the Annesburg payroll robbery. He rides with hired guns and pays them well.',
          at = v(1370.12, 1694.8, 213.07) },
        { name = 'Ned Haskell', tier = 1, gang = 'roadagents', extra = -1,
          notice = 'Wanted alive for knifing a mine foreman. Hiding by the rail spur north of town.',
          at = v(3032.64, 1482.22, 48.7368) },
    },

    rhodes = {
        { name = 'Augustin Lacroix', tier = 2, gang = 'bayoufolk',
          notice = 'Wanted alive for passing forged bank notes in Rhodes. The bank wants to know who else is printing them.',
          at = v(1705.5, -568.26, 42.85) },
        { name = 'Luther Grady', tier = 2, gang = 'hiredguns',
          notice = 'Wanted alive for killing a card player in the Rhodes saloon. Hiding in the bayou with paid protection.',
          at = v(1962.5, -456.23, 40.83) },
        { name = 'Captain Jubal Reese', tier = 3, gang = 'greycoats',
          notice = 'Wanted alive for leading the raid on the Rhodes armoury. His men will die for him.',
          at = v(2292.1, -989.58, 41.49) },
    },

    saintdenis = {
        { name = 'Remy Batiste', tier = 1, gang = 'bayoufolk',
          notice = "Wanted alive for poisoning a rival's oyster beds. Three people died of the bad catch.",
          at = v(2659.79, -435.711, 42.5659) },
        { name = 'Ambrose Whitlock', tier = 2, gang = 'cityroughs',
          notice = 'Wanted alive for robbing the Saint Denis tram company blind. Fled into the swamp with his bodyguards.',
          at = v(2040.44, -293.11, 41.42) },
        { name = 'Orrin Mabry', tier = 3, gang = 'greycoats',
          notice = 'Wanted alive for trying to blow the rail bridge outside the city. The army wants to question him.',
          at = v(2478.55, 103.82, 45.09) },
    },

    blackwater = {
        { name = "Wendell 'Doc' Farrow", tier = 2, gang = 'hillfolk',
          notice = 'Wanted alive for selling wood alcohol as medicine in Blackwater. Holed up at a still near Manzanita.',
          at = v(-1861.7, -1722.17, 108.35) },
        { name = 'Barnaby Coyle', tier = 1, gang = 'dusters',
          notice = 'Wanted alive for robbing the Blackwater post office. Camped by the freight line.',
          at = v(-281.055, -319.6095, 88.1831) },
        { name = 'Gideon Marsh', tier = 3, gang = 'hiredguns',
          notice = 'Wanted alive for shooting a Blackwater councilman. He paid good money for protection.',
          at = v(-2200.94, -1436.36, 137.81) },
    },

    strawberry = {
        { name = 'Cyrus Blackwood', tier = 3, gang = 'claimjumpers', pay = 1.15,
          notice = "Wanted alive for the Mount Hagen mine robbery. He has the company's wages and plenty of guards.",
          at = v(-1415.76, 1167.79, 226.30) },
        { name = 'Percival Nash', tier = 1, gang = 'hillfolk',
          notice = 'Wanted alive for horse theft. Gone to ground in the woods west of Strawberry.',
          at = v(-2863.61, 287.32, 192.21) },
        { name = 'Old Man Tolliver', tier = 2, gang = 'hillfolk', pay = 1.2,
          notice = 'Wanted alive for shooting two trappers over a hunting spot, far up in the high country.',
          at = v(-1828.78, 1889.77, 253.48) },
    },

    armadillo = {
        { name = 'Ezra Hobbs', tier = 1, gang = 'hillfolk',
          notice = 'Wanted alive for selling poisoned whiskey in Armadillo while the town lay sick.',
          at = v(-2769.23, -3048.90, 11.38) },
        { name = "Rafael 'El Cuervo' Montano", tier = 3, gang = 'bandidos',
          notice = 'Wanted alive for the Armadillo bank job. His men hold the high ground south of town.',
          at = v(-3812.84, -3651.87, 40.84) },
        { name = 'Clement Wise', tier = 2, gang = 'roadagents',
          notice = 'Wanted alive for robbing the train at the junction east of Armadillo.',
          at = v(-2214.41, -2519.54, 64.8763) },
        { name = 'Jasper Lowe', tier = 2, gang = 'dusters',
          notice = 'Wanted alive for shooting a Tumbleweed deputy. Camped by the Benedict line.',
          at = v(-4916.56, -3009.53, -19.1817) },
    },
})
