-- pup-perks | config/xp.lua
-- How much experience each activity pays, and to which side.

-------------------------------------------------------------------------------
-- XP SOURCES
-------------------------------------------------------------------------------
-- Keys are the kinds other resources pass to Award(source, '<kind>'): never rename one (see README.md).
Config.XpSources = {
    skin           = { track = 'civ'  , min =  4, max =  9 },  -- skinning any animal (skinanimals)
    skin_legendary = { track = 'civ'  , min = 45, max = 80 },  -- skinning a legendary carcass (skinanimals)
    tame           = { track = 'civ'  , min = 15, max = 25 },  -- breaking a wild horse and selling or keeping it (pup-stable)
    craft          = { track = 'civ'  , min =  1, max =  5 },  -- one completed craft (pup_workbench)
    gunsmith       = { track = 'civ'  , min =  5, max =  7 },  -- one weapon or ammo craft at the gunsmith bench (pup_gunsmith)
    ranch          = { track = 'civ'  , min =  3, max =  6 },  -- milking / egg collection (pup_ranchero)
    farm           = { track = 'civ'  , min =  5, max = 10 },  -- harvesting a grown crop (pup_homestead)
    farm_plant     = { track = 'civ'  , min =  3, max =  6 },  -- putting a seed down (pup_homestead)
    farm_water     = { track = 'civ'  , min =  2, max =  5 },  -- first watering of a plant (pup_homestead)
    farm_trim      = { track = 'civ'  , min =  2, max =  5 },  -- trimming a plant (pup_homestead)
    dig            = { track = 'civ'  , min =  6, max = 11 },  -- a shovel dig that paid out (pup_mortician)
    mining         = { track = 'civ'  , min =  1, max =  4 },  -- a good pickaxe swing at a node (miner_lumber)
    pan            = { track = 'civ'  , min =  1, max =  4 },  -- a gold pan that turned something up (goldpan)
    lumber         = { track = 'civ'  , min =  1, max =  4 },  -- a good axe swing at a tree (miner_lumber)
    fishing        = { track = 'civ'  , min = 10, max = 25 },  -- a landed catch (vorp_fishing)
    robbery        = { track = 'crime', min = 55, max = 95 },  -- looting a robbery box (pup_robbery)
    still          = { track = 'crime', min = 15, max = 28 },  -- tearing down a moonshine still (pup_hideouts)
    drugsale       = { track = 'crime', min = 13, max = 25 },  -- completing a drug sale (pup_hideouts)
    fence_sale     = { track = 'crime', min =  1, max =  2 },  -- moving stolen goods through the fence (pup_robbery)
    graverob       = { track = 'crime', min = 12, max = 22 },  -- robbing a grave (gravedigging)
    wagonrob       = { track = 'crime', min = 45, max = 80 },  -- finishing a wagon robbery mission (pup_hideouts)
    undertaker     = { track = 'both' , min = 25, max = 30, split = true },  -- undertaker work (pup_mortician)
    bounty         = { track = 'both' , min = 20, max = 25, split = true },  -- a bounty turned in (pup-misc/bountyhunting)
    clan_supply    = { track = 'both' , min = 40, max = 70, split = true },  -- a camp supply wagon run (pup_camps)
    clan_delivery  = { track = 'both' , min = 40, max = 70, split = true },  -- a camp delivery wagon run (pup_camps)
}
