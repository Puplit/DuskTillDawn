-- pup-misc/bountyhunting | kill contracts (see README)
-- One line per contract, listed under the board town that posts it:
--   name, notice  what the board says
--   at            the camp; the outlaws are spread around it (spread metres, default Spread.kill)
--   drop          where the bodies go (default: that town's board)
--   tier          1 Petty, 2 Wanted, 3 Notorious (see Tiers in main.lua)
--   gang          ped pool from peds.lua
--   extra, pay    optional: outlaws added at every party size, purse factor

local v = vector3

BountyConfig.Kill = BountyConfig.build('kill', {
    valentine = {
        { name = 'The Tallow Creek Gang', tier = 1, gang = 'roadagents',
          notice = 'Wanted dead for burning out two homesteads on the Heartland flats. Camped by the rail line near the oil fields.',
          at = v(357.959, 596.374, 115.676) },
        { name = "Corporal Kettle's Deserters", tier = 3, gang = 'greycoats', spread = 14.0,
          notice = 'A deserter and his men hold the old fort walls and shoot at anything in a blue coat.',
          at = v(357.794, 1466.816, 179.2) },
        { name = 'The Larkspur Brothers', tier = 2, gang = 'hillfolk',
          notice = 'Poachers turned killers. They shot a game warden in the Cumberland woods and left him for the wolves.',
          at = v(-70.83, 1579.02, 113.87) },
        { name = 'The Dakota Cut Rail Thieves', tier = 2, gang = 'dusters',
          notice = 'Pried open a freight car south of Valentine and shot the brakeman. The goods are gone, the men are not.',
          at = v(31.405, -29.33, 102.485) },
        { name = 'The Limpany Squatters', tier = 1, gang = 'roadagents', extra = 1,
          notice = 'A crew of robbers has moved into the ruins of Limpany and preys on the Blackwater road.',
          at = v(-382.739, -129.382, 46.975) },
    },

    annesburg = {
        { name = 'The Coal Dust Boys', tier = 1, gang = 'claimjumpers',
          notice = 'Laid-off miners who took to robbing the company wagons on the river road.',
          at = v(2830.57, 931.54, 48.52) },
        { name = "Brother Ezekiel's Flock", tier = 2, gang = 'hillfolk',
          notice = "A hill preacher and his followers who held a trapper's family at gunpoint. The family got out; the flock stays.",
          at = v(2687.22, 1633.86, 148.19) },
        { name = 'The Saltmarsh Wreckers', tier = 2, gang = 'dusters',
          notice = 'Lure boats onto the rocks east of Annesburg and strip the cargo. Three crews drowned this season.',
          at = v(3585.27, 1451.0, 47.54) },
        { name = 'The Gallagher Still Crew', tier = 3, gang = 'hillfolk',
          notice = 'Guard a big still in the Roanoke hills and shot the two revenue men who came calling.',
          at = v(1627.64, 822.9, 144.03) },
    },

    rhodes = {
        { name = 'The Copperhead Still', tier = 2, gang = 'bayoufolk',
          notice = 'Moonshiners who shot a Rhodes deputy over a broken barrel. Their still sits in the woods northeast of town.',
          at = v(1784.90, -821.65, 42.86) },
        { name = 'The Reedwater Gang', tier = 1, gang = 'bayoufolk',
          notice = 'Rob the fishermen and trappers along the river, then sink their boats.',
          at = v(2109.94, -1029.32, 42.06) },
        { name = "Colonel Holloway's Night Riders", tier = 3, gang = 'greycoats', pay = 1.1,
          notice = "Old soldiers who ride after dark and burn freedmen's farms. Wanted dead by order of the governor.",
          at = v(675.17, -1815.8, 43.73) },
        { name = 'The Pettibone Cousins', tier = 1, gang = 'roadagents',
          notice = 'Stole a string of horses from a Scarlett Meadows ranch and shot the stable boy.',
          at = v(320.06, -1316.15, 44.38) },
    },

    saintdenis = {
        { name = 'The Bayou Jack Crew', tier = 1, gang = 'bayoufolk',
          notice = 'Hijack produce barges on the way to the Saint Denis market.',
          at = v(2214.74, -548.61, 41.44) },
        { name = 'The Moreau Gunrunners', tier = 2, gang = 'bayoufolk',
          notice = 'Run stolen rifles up the bayou and killed the customs man who followed them.',
          at = v(2334.37, -317.88, 41.21) },
        { name = 'The Dockside Butchers', tier = 2, gang = 'cityroughs',
          notice = 'Dock toughs who beat a shipping clerk to death and fled up the coast.',
          at = v(3147.11, -776.85, 44.24) },
        { name = 'The Ashford Kidnappers', tier = 3, gang = 'hiredguns',
          notice = "Took a merchant's daughter for ransom. She is home now; the men who took her are camped north of the city.",
          at = v(2550.36, -214.27, 42.95) },
        { name = 'The Fort Squatters', tier = 3, gang = 'greycoats', spread = 14.0, pay = 1.1,
          notice = 'Raiders who have made the old fort their own and fire on every rider who passes.',
          at = v(2454.5, 292.5, 70.35) },
    },

    blackwater = {
        { name = 'The Quarry Road Gang', tier = 1, gang = 'roadagents',
          notice = 'Hold up wagons on the road north of Blackwater and shoot the mules.',
          at = v(-881.36, -742.66, 59.62) },
        { name = 'The Fenwick Rustlers', tier = 2, gang = 'roadagents', extra = 1,
          notice = 'Drove off forty head from a ranch west of Blackwater and burned the bunkhouse.',
          at = v(-1649.38, -1375.40, 84.01) },
        { name = 'The Landing Pirates', tier = 3, gang = 'cityroughs', spread = 12.0,
          notice = 'River pirates working out of Thieves Landing. The Blackwater shipping men want them gone for good.',
          at = v(-1408.485, -2335.257, 42.749) },
        { name = 'The Hollow Pine Killers', tier = 3, gang = 'hillfolk', pay = 1.1,
          notice = 'Murdered a family of settlers in the Tall Trees.',
          at = v(-2539.93, -1369.64, 151.16) },
    },

    strawberry = {
        { name = 'The Mill Road Agents', tier = 1, gang = 'roadagents',
          notice = 'Rob the tourists on the hill road north of Strawberry.',
          at = v(-1719.82, -66.10, 176.68) },
        { name = 'The Hatchet Men', tier = 2, gang = 'hillfolk',
          notice = 'Woodcutters turned bandits who took an axe to a timber agent. Their camp is deep in the western woods.',
          at = v(-2605.52, -24.23, 160.62) },
        { name = 'The Ridge Snipers', tier = 3, gang = 'hiredguns', spread = 14.0,
          notice = 'Shoot travellers crossing the Dakota from the far bank and take their horses. Bring a long gun.',
          at = v(-1156.0123, 730.9919, 108.8246) },
        { name = 'The Briar Patch Gang', tier = 2, gang = 'roadagents',
          notice = 'Ambushed the Strawberry mail rider in the Tall Trees and took every sack.',
          at = v(-2775.4, -1430.57, 164.0) },
    },

    armadillo = {
        { name = 'The Mercer Garrison', tier = 3, gang = 'bandidos', spread = 15.0, pay = 1.15,
          notice = 'Banditos holding Fort Mercer. They raid the stage and ride back behind the walls.',
          at = v(-4211.101, -3442.098, 36.725) },
        { name = 'The Rattler Gang', tier = 2, gang = 'dusters',
          notice = 'Shot up the Armadillo saloon and robbed the drunks on their way out.',
          at = v(-3224.1, -3047.95, 2.5) },
        { name = 'The Cholla Coyotes', tier = 1, gang = 'bandidos',
          notice = 'Steal cattle north of Armadillo and sell them across the river.',
          at = v(-3410.17, -2123.56, -5.85) },
        { name = 'The Gaptooth Diggers', tier = 2, gang = 'claimjumpers',
          notice = 'Claim jumpers who murdered three prospectors and took their diggings.',
          at = v(-3138.7, -3565.62, 11.73) },
        { name = 'The Scorpion Bend Gang', tier = 3, gang = 'bandidos',
          notice = 'Raid the homesteads of the far west and leave nothing standing.',
          at = v(-4711.68, -2587.41, -2.37) },
    },
})
