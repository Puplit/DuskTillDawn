-- fred_metabolism | config/locale.lua
-- Every player-facing string. ~t7~ / ~pa~ / ~t3~ are RedM text colour codes.

Locale = {
    -- using a consumable
    consumedPrefix = "You consumed ",        -- followed by the item's DisplayName
    skillBotched   = "You botched it.",      -- skill check failed, the item is used up
    stopSmoking    = "Stop Smoking",         -- prompt shown while smoking

    -- needs
    lowFood  = "You hear your belly rumbling!",
    lowWater = "You are thirsty!",

    -- cold warnings (title, then text)
    tempTitleCold      = "~t3~Temperature",
    tempTitleColder    = "~pa~Temperature",
    tempTitleFreezing  = "~t7~Temperature",
    tempNotify1 = "You are feeling very cold, you should cover yourself more!!",
    tempNotify2 = "You're cold, you should cover yourself",
    tempNotify3 = "You're freezing cover yourself up, otherwise you will die!",

    -- /temp readout
    tempReadout       = "Temp %dC (ambient %dC, clothes %+d%s) - %s",
    tempComfortable   = "comfortable",
    tempTooCold       = "TOO COLD (extra food drain)",
    tempTooHot        = "TOO HOT (extra water drain)",
    tempPartHat        = "hat",
    tempPartShirt      = "shirt",
    tempPartPants      = "pants",
    tempPartBoots      = "boots",
    tempPartCoat       = "coat",
    tempPartClosedCoat = "closed coat",
    tempPartGloves     = "gloves",
    tempPartVest       = "vest",
    tempPartPoncho     = "poncho",
    tempPartCloak      = "cloak",
    tempPartMask       = "mask",
    tempIndoors        = "indoors %+d",
    tempSleevesRolled  = "sleeves rolled -%d",
    tempCollarOpen     = "collar open -%d",
    tempRolledCovered  = "rolled clothing covered by coat",
}
