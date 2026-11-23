-- pup_armory | player-facing text. %s / %d placeholders are filled in by the code: keep them.

Locale = {
    -- carrying
    notYourTrade   = "You don't know how to handle that.",          -- job-locked weapon, wrong job
    putAway        = "%s put away.",
    takenOut       = "%s ready. Draw it from your weapon wheel.",
    shieldOn       = "%s strapped to your arm.",
    shieldOff      = "%s taken off.",
    lostItem       = "You no longer have the %s.",

    -- editor: pickers
    editTitle      = "Weapon Positions",
    editNothing    = "You are not carrying anything to adjust. Use a weapon item first.",
    editPickItem   = "What are you adjusting?",
    editPickSpot   = "Which position?",
    spotWorn       = "Carried (put away)",
    spotWornShield = "On the arm",
    spotHand       = "In the hand",
    resetAll       = "Reset to default",
    resetAllDesc   = "Forget your saved positions for this weapon",

    -- editor: panel
    panelTitle     = "%s - %s",
    panelMove      = "ARROWS move   [ ] up/down   hold SHIFT to rotate",
    panelStep      = "Step: %s   G changes it",
    panelKeys      = "ENTER save   B default   BACKSPACE cancel",
    stepFine       = "fine",
    stepNormal     = "normal",
    stepCoarse     = "coarse",

    -- editor: staff
    saveWhere         = "Save this position for...",
    saveForMe         = "My character",
    saveForMeDesc     = "Only you see it here",
    saveForServer     = "Everyone (server default)",
    saveForServerDesc = "The starting position for every player who has not saved their own",
    resetServer       = "Reset server default",
    resetServerDesc   = "Go back to the position in the config",
    defaultSaved      = "Server default saved for %s.",
    defaultReset      = "%s back to the config position for everyone.",

    -- editor: results
    saved          = "Position saved for this character.",
    cancelled      = "Nothing changed.",
    resetDone      = "%s back to its default positions.",
    tooFar         = "That is too far from the body to save.",
}
