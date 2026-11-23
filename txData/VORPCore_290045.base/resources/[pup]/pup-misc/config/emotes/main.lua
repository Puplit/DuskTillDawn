-- pup-misc/emotes | main settings (see README)

EmotesConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
EmotesConfig.General = {
    stopCommand     = 'sa',          -- stops any emote, animation or scenario
    listCommand     = 'emotelist',   -- prints every command to F8
    poseCommand     = 'photopose',   -- /photopose <id>
    poseListCommand = 'photoposes',  -- prints every pose id to F8
}

EmotesConfig.Keys = {}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
EmotesConfig.Integrations = {
    walkanimCommands = { 'walkanim', 'walkSlow' },
}
