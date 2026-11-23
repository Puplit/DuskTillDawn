-- pup-misc/tattoos | player-facing text
-- %s is filled in by the code; keep it.

TattooLocale = {
    -- shop + mirror page
    blipName       = "Make up",
    shopPrompt     = "Make Up",                   -- prompt group title at a shop
    openMenu       = "Open Menu",
    menuTitle      = "Make Up",                   -- title of the mirror page
    bodyTitle      = "Body Adjustments",          -- title of the Body Adjustments page
    backTo         = "Back to ",                  -- + menuTitle, on the Body Adjustments button
    noBodyChanges  = "No body changes to save.",

    -- camera screen prompts
    cameraGroup    = "Press Enter to Apply",
    resetCamera    = "Reset Camera",
    moveUp         = "Move Up",
    moveDown       = "Move Down",
    zoomIn         = "Zoom In",
    zoomOut        = "Zoom Out",
    rotateLeft     = "Rotate Left",
    rotateRight    = "Rotate Right",
    back           = "Back",

    -- body adjustments
    bodyLoading    = "Still loading your body adjustments, try again in a moment.",
    bodyNoFunds    = "You cannot afford those body changes right now.",

    -- server notifications (title, text)
    errorTitle     = "Error",
    successTitle   = "Success",
    notEnoughMoney = "Not enough money",
    saveFailed     = "Could not save - tell an admin",
    saved          = "Overlays saved",

    -- shown instead of the raw overlay name, on the page and in the menus
    layers = {
        disc         = "Tattoos",

        -- makeup
        lipsticks    = "Lipstick",
        blush        = "Blush",
        eyeliners    = "Eyeliner",
        shadows      = "Eye Shadow",

        -- everything else
        complex      = "Complexion",
        grime        = "Dirt",
        freckles     = "Freckles",
        moles        = "Moles",
        spots        = "Spots",
        scars        = "Scars",
        ageing       = "Ageing",
        acne         = "Acne",
        disc2        = "Discolouration",
        hair         = "Face Hair",
        foundation   = "Foundation",
        paintedmasks = "Face Paint",
        beardstabble = "Stubble",
    },
}
