-- pup-misc/scenario | main settings (see README)

ScenarioConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
ScenarioConfig.General = {
    command = "scenario",
}

-- gun-spin keys
ScenarioConfig.Keys = {
    trickToggle = 0x4AF4D473,   -- turns trick mode on / off
    trickDo     = 0x6319DB71,   -- UP arrow     do the selected trick
    trickEnd    = 0x05CA7C52,   -- DOWN arrow   finish (leave trick mode)
    trickPrev   = 0xA65EBAB4,   -- LEFT arrow   previous trick
    trickNext   = 0xDEB34313,   -- RIGHT arrow  next trick
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
ScenarioConfig.Integrations = {}

-------------------------------------------------------------------------------
-- GUN SPIN
-------------------------------------------------------------------------------
ScenarioConfig.GunSpin = {
    -- order matters (see README)
    tricks = {
        { hash = `KIT_EMOTE_TWIRL_GUN`,       label = "Twirl" },
        { hash = `KIT_EMOTE_TWIRL_GUN_DUAL`,  label = "Dual Twirl" },
        { hash = `KIT_EMOTE_TWIRL_GUN_VAR_A`, label = "Twirl A" },
        { hash = `KIT_EMOTE_TWIRL_GUN_VAR_B`, label = "Twirl B" },
        { hash = `KIT_EMOTE_TWIRL_GUN_VAR_C`, label = "Twirl C" },
        { hash = `KIT_EMOTE_TWIRL_GUN_VAR_D`, label = "Twirl D" },
    },
}
