-- pup-misc/bountyhunting | escort contracts (see README)
-- One line per contract, listed under the board town that posts it:
--   name, notice  what the board says (name = the client)
--   at            where the client waits; drop = where the client must be walked to (within 2 m)
--   tier          1 Petty, 2 Wanted, 3 Notorious (see Tiers in main.lua): ambushers per wave, wave gap, client health
--   client        ped pool for the client; gang = ped pool for the ambushers
--   extra, pay    optional: ambushers added to every wave, purse factor; wave / health override the tier

local v = vector3

BountyConfig.Escort = BountyConfig.build('escort', {
    valentine = {
        { name = 'Tobias Reed, Cattle Buyer', tier = 1, client = 'workfolk', gang = 'roadagents',
          notice = 'Carries a buyer\'s purse to Wallace Station. Road agents have been watching the auction yard.',
          at = v(-168.334, 629.548, 113.682), drop = v(-1299.4, 402.1, 95.39) },
        { name = 'Professor Ellery Moss', tier = 2, client = 'travellers', gang = 'hillfolk',
          notice = 'A rock collector taking his crates to the rail line past Bacchus Station. The hill men think the crates hold gold.',
          at = v(-176.2, 628.27, 114.09), drop = v(556.65, 1725.99, 186.968) },
        { name = 'The Lowell Witness', tier = 3, client = 'gentry', gang = 'hiredguns', pay = 1.1,
          notice = "Saw a killing in Valentine and will testify at Emerald. The killer's friends have put a price on that testimony.",
          at = v(-164.3632, 633.6946, 114.0320), drop = v(1523.527, 442.676, 90.728) },
    },

    annesburg = {
        { name = 'Walter Briggs, Mine Clerk', tier = 1, client = 'workfolk', gang = 'roadagents',
          notice = 'Carries the company ledgers to Van Horn. Somebody wants those ledgers lost.',
          at = v(2939.029, 1280.700, 44.303), drop = v(2973.06, 562.55, 44.5) },
        { name = 'Doctor Lucius Penrose', tier = 2, client = 'travellers', gang = 'claimjumpers', pay = 1.1,
          notice = 'Called to a fever at Emerald Ranch. The men selling false cures there do not want him to arrive.',
          at = v(2941.408, 1270.714, 44.286), drop = v(1523.527, 442.676, 90.728) },
        { name = 'Elias Ward, Union Man', tier = 2, client = 'gentry', gang = 'hiredguns',
          notice = 'Speaks for the miners and is due at Van Horn. The mine bosses hired guns to stop the speech.',
          at = v(2911.58, 1325.57, 45.1), drop = v(2973.06, 562.55, 44.5) },
    },

    rhodes = {
        { name = 'Judge Sutter', tier = 2, client = 'gentry', gang = 'greycoats', pay = 1.1,
          notice = "Bound for the Saint Denis courthouse to sentence a raider. The raider's friends ride the road.",
          at = v(1229.50, -1298.20, 76.95), drop = v(2734.654, -1437.456, 45.815) },
        { name = 'Hollis Bean, Drover', tier = 1, client = 'workfolk', gang = 'roadagents',
          notice = 'Walking to Emerald Station to sign on with a cattle drive, with his savings sewn into his coat.',
          at = v(1238.492, -1314.886, 76.554), drop = v(1523.527, 442.676, 90.728) },
        { name = 'Mister Fontaine, Gambler', tier = 3, client = 'travellers', gang = 'hiredguns',
          notice = 'Cleaned out a card game in Rhodes and wants to reach the Saint Denis hotel alive. The losers hired guns.',
          at = v(1229.0, -1306.1, 76.9), drop = v(2593.6, -1163.8, 53.53) },
    },

    saintdenis = {
        { name = 'The Arceneaux Heir', tier = 2, client = 'travellers', gang = 'cityroughs', pay = 1.1,
          notice = 'Inherited a plantation near Rhodes. The cousins who lost it would rather the heir never arrived.',
          at = v(2734.654, -1437.456, 45.815), drop = v(1229.50, -1298.20, 76.95) },
        { name = 'Isaac Tanner, Peddler', tier = 1, client = 'workfolk', gang = 'roadagents',
          notice = 'Hauling his wares to the Rhodes market. He has been robbed twice on that road this month.',
          at = v(2749.29, -1399.69, 46.19), drop = v(1233.84, -1293.57, 76.90) },
        { name = "Mister Whitcomb, Senator's Aide", tier = 3, client = 'gentry', gang = 'hiredguns',
          notice = 'Carries campaign money to a meeting in Rhodes. Every gun hand in the parish has heard about it.',
          at = v(2683.254, -1449.095, 45.924), drop = v(1229.0, -1306.1, 76.9) },
    },

    blackwater = {
        { name = 'The New Schoolteacher', tier = 1, client = 'townsfolk', gang = 'roadagents',
          notice = 'Starting a school out by Riggs Station. A debt from back east has followed along.',
          at = v(-880.65, -1244.34, 43.92), drop = v(-1100.474, -577.260, 82.045) },
        { name = 'Otis Fry, Timber Buyer', tier = 2, client = 'workfolk', gang = 'hillfolk',
          notice = 'Riding out to buy timber at Manzanita with cash in hand. The hills are full of men who know it.',
          at = v(-877.87, -1343.73, 43.29), drop = v(-1944.43, -1608.14, 116.69) },
        { name = 'Mister Abernathy, Railroad Man', tier = 3, client = 'gentry', gang = 'hiredguns',
          notice = 'Surveying a new line to Strawberry. The landowners in the way have hired guns.',
          at = v(-790.48, -1270.66, 43.63), drop = v(-1827.53, -432.96, 159.97) },
    },

    strawberry = {
        { name = 'Augustus Pell, Land Agent', tier = 1, client = 'townsfolk', gang = 'roadagents',
          notice = 'Carries land deeds to Wallace Station. The squatters would rather the deeds were lost.',
          at = v(-1827.53, -432.96, 159.97), drop = v(-1299.4, 402.1, 95.39) },
        { name = 'Mister Quill, Painter', tier = 2, client = 'travellers', gang = 'hillfolk',
          notice = 'Has made no enemies painting the falls, but the robbers on the Riggs road do not care.',
          at = v(-1831.3, -401.44, 162.23), drop = v(-1100.474, -577.260, 82.045) },
        { name = "Jonah Kent, Butcher's Boy", tier = 2, client = 'workfolk', gang = 'roadagents',
          notice = "Taking the season's hides and takings down to the Blackwater market.",
          at = v(-1794.050, -375.090, 159.899), drop = v(-877.87, -1343.73, 43.29) },
    },

    armadillo = {
        { name = 'Mister Dunmore, Paymaster', tier = 2, client = 'workfolk', gang = 'bandidos',
          notice = 'Carries railroad wages to Tumbleweed. Banditos have watched the station all week.',
          at = v(-3729.02, -2601.26, -12.93), drop = v(-5507.310, -2957.360, -1.610) },
        { name = 'Pastor Abel Greer', tier = 1, client = 'townsfolk', gang = 'dusters',
          notice = "Taking the collection to the church fund at MacFarlane's Ranch.",
          at = v(-3641.26, -2593.91, -13.76), drop = v(-2494.85, -2437.45, 60.7) },
        { name = 'Mister Halloran, Attorney', tier = 3, client = 'gentry', gang = 'bandidos', pay = 1.1,
          notice = 'Carries a land contract to Benedict Point. A rival cattle baron wants it torn up.',
          at = v(-3743.879, -2602.451, -13.590), drop = v(-5230.2, -3468.1, -20.35) },
    },
})
