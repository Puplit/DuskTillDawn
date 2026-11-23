-- pup_clothing | every text a player sees. %s and %d are filled in by the code.

Locale = {
    storeTitle      = 'Clothing Store',
    wardrobeTitle   = 'Wardrobe',
    promptOpen      = 'Open',
    blipStore       = 'Clothing Store',
    blipWardrobe    = 'Wardrobe',

    cantAfford      = 'You cannot afford this ($%s)',
    leftStore       = 'Left the clothing store.',
    outfitLimit     = 'Your wardrobe is full (%d outfits). Delete one first.',
    disguised       = 'You cannot change clothes while wearing a borrowed face.',
    notHere         = 'You need to be at a clothing store or wardrobe for that.',
    saveFailed      = 'Your clothes could not be saved. You were not charged.',
    outfitGone      = 'That outfit no longer exists.',
    toggleCount     = '%d clothing toggle commands registered',

    -- page text
    page = {
        save          = 'Save',
        done          = 'Done',
        reset         = 'Reset',
        saveAs        = 'Save As Outfit',
        cancel        = 'Cancel',
        resetAsk      = 'Take everything off and start again?',
        yes           = 'Yes',
        no            = 'No',
        namePlaceholder = 'Enter the name of the outfit',
        create        = 'Create',
        defaultName   = 'Outfit',
        none          = 'None',
        style         = 'Style %d of %d',
        keyHint       = 'E/F turn   Shift/Alt zoom   Space/Ctrl camera',
        -- the camera guide under the garments (keys must match Config.Keys and Config.Store.failsafeKey)
        controlsTitle = 'Camera',
        controls      = {
            { keys = { 'E', 'F' },        label = 'Turn around' },
            { keys = { 'Shift', 'Alt' },  label = 'Zoom in / out' },
            { keys = { 'Space', 'Ctrl' }, label = 'Camera up / down' },
            { keys = { 'Backspace' },     label = 'Hold to leave' },
        },
        colourTitle   = '%s colour',
        palette       = 'Palette',
        tint1         = 'T1',
        tint2         = 'T2',
        tint3         = 'T3',
        colourHint    = 'Recolouring this costs $%s on top of the outfit',
        removeColour  = 'Remove Colour',
        tinted        = 'dyed',
        outfits       = 'OUTFITS',
        search        = 'Search outfits',
        noOutfits     = 'No outfits saved',
        wear          = 'Wear',
        delete        = 'Delete',
        close         = 'Close',
        deleteAsk     = 'Delete outfit "%s"?',
        special       = 'Special %s',
    },
}

function L(key, ...)
    local s = Locale[key]
    if s == nil then return key end
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end
