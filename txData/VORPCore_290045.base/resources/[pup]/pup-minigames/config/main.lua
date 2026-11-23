-- pup-minigames | main settings
-- Minigame library (skill bar, safe crack, lockpick-style games) used by other resources via exports.

Config = Config or {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    testCommands = false,             -- register the /test_<game> chat commands (true = on, false = off)
}

-------------------------------------------------------------------------------
-- SAFE CRACK
-------------------------------------------------------------------------------
Config.SafeCrack = {
    useQadrSafe = true,              -- use the native RDR2 dial from qadr-safe when that resource is started; false = built-in NUI safe
}
