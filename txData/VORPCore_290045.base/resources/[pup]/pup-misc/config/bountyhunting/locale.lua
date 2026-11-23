-- pup-misc / bountyhunting | player-facing text (both sides read it)

BountyLocale = {
    boardBlip     = 'Bounty Board',
    promptTitle   = 'Bounty Hunting',
    promptOpen    = 'Read the Board',
    promptEnd     = 'Call It Off',
    promptDeliver = 'Hand Over',

    menuTitle    = 'Choose Your Party',
    menuSubtitle = 'More hunters means more outlaws and a bigger purse',
    partyRows = {
        { label = 'Ride Alone',   desc = 'One hunter' },
        { label = 'Ride as Two',  desc = 'Two hunters' },
        { label = 'Ride as Three', desc = 'Three hunters' },
        { label = 'Ride as Four', desc = 'Four hunters' },
    },
    partnerFields = {
        "Second hunter's server ID",
        "Third hunter's server ID",
        "Fourth hunter's server ID",
    },
    confirm = 'Take the Contract',

    kindName = {
        kill   = 'Kill Contract',
        arrest = 'Capture Contract',
        escort = 'Escort Contract',
    },
    objective = {
        kill   = 'Ride to the marked camp and put the outlaws down.',
        arrest = 'Ride to the marked camp and take the wanted man alive.',
        escort = 'Ride to the marked spot and meet your client.',
    },
    titleLine = '%s - %s',
    -- kind, contract name, its notice, the objective
    briefLine = '%s: %s. %s %s',

    killNext   = 'Bring the bodies to the drop point.',
    arrestNext = 'Keep the marked man alive and bring him to the drop point.',
    escortNext = 'See your client safely to their destination.',

    markStart = {
        kill   = 'Known Bounty Location',
        arrest = 'Known Bounty Location',
        escort = 'Client Location',
    },
    markDrop     = 'Delivery Location',
    markDest     = 'Client Destination',
    markTarget   = 'Wanted Man',
    markHostile  = 'Outlaw',
    markClient   = 'Your Client',
    markAttacker = 'Ambusher',

    failed    = 'Contract failed.',
    over      = 'Contract closed.',
    calledOff = 'The contract was called off.',
    paid      = 'You collected $%s',

    refused       = 'The board has nothing for you right now.',
    cooldown      = 'No work for you yet. Come back in %d %s.',
    minuteOne     = 'minute',
    minuteMany    = 'minutes',
    notOnline     = 'Player ID %d is not online. Contract cancelled.',
    partyMismatch = 'Name %d different riders besides yourself (not your own ID).',
    partnerBusy   = 'Player ID %d is already riding on a contract.',
    partnerFar    = 'Player ID %d must be standing with you at the board.',
    partnerNoJob  = 'Player ID %d does not hold a bounty licence.',
    busy          = 'You are already riding on a contract.',
    noContracts   = 'No contracts are posted here.',
    notAtRank     = 'No contract here suits a party of that size.',
    carryNothing  = 'Carry a bounty to the drop point to hand it over.',
    notYourBounty = 'That is not one of your bounties.',
}
