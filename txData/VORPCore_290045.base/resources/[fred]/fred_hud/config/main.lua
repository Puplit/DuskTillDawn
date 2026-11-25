-- fred_hud | config/main.lua
-- Food / water / temperature gauges, the extra event gauges and the /hud layout editor.

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    editCommand = 'hud',     -- chat command: open / close the HUD layout editor (toggle)
    whyCommand  = 'hudwhy',  -- chat command: explains why the gauge strip is hidden right now
}

-------------------------------------------------------------------------------
-- TIMING
-------------------------------------------------------------------------------
Config.Timing = {
    statusUpdateMs          = 250,   -- how often hunger / thirst / temperature are pushed to the gauges
    layoutLoadDelayMs       = 2000,  -- wait after start before the saved layout is applied (NUI pages loading)
    characterReapplyDelayMs = 2500,  -- re-apply the layout this long after a character is selected
    ecoSyncDelayMs          = 2500,  -- ask pup-misc for the Eco Boost state this long after start
}

-------------------------------------------------------------------------------
-- GAUGES  (look of the round gauges; sent to the NUI page)
-------------------------------------------------------------------------------
Config.Gauges = {
    anchorBottom = '30vh',   -- CSS distance of the gauge strip from the bottom of the screen
    anchorLeft   = '3.7vw',  -- CSS distance of the gauge strip from the left of the screen
    scale        = 1.2,      -- size multiplier of every gauge (1.0 = stock size)
    fadeMs       = 500,      -- fade in / out time when the HUD is shown or hidden

    colours = {               -- any CSS colour
        ring       = '#d6d6d6',    -- hunger / thirst / temperature / recovery ring
        goldRing   = '#e6b422',    -- Eco Boost, heist timer and heist alarm ring
        background = '#00000040',  -- the disc behind the ring
        inner      = '#00000091',  -- the disc inside the ring, behind the icon
    },
}

-------------------------------------------------------------------------------
-- PLAYER SETTINGS  (the "Display" rows of the /hud editor)
-------------------------------------------------------------------------------
-- Each row: key (saved name, do not change), default (what a new player gets)
-- and choices (what one click cycles through, in order). For hunger / thirst
-- 0 = always shown, any other number = only shown at or below that percent;
-- a saved value from 0 to 100 is kept even if it is not one of the choices.
-- Example: { key = 'tempUnit', default = 'C', choices = { 'C', 'F' } },
Config.Settings = {
    { key = 'tempUnit',  default = 'C',      choices = { 'C', 'F' } },
    { key = 'money',     default = 'always', choices = { 'always', 'hidden' } },
    { key = 'moneyFont', default = 'lino',   choices = { 'lino', 'display' } },
    { key = 'moneySize', default = 'm',      choices = { 'm', 's', 'l' } },
    { key = 'hunger',    default = 0,        choices = { 0, 75, 50, 25 } },
    { key = 'thirst',    default = 0,        choices = { 0, 75, 50, 25 } },
    { key = 'menuSide',  default = 'left',   choices = { 'left', 'right' } },
    { key = 'progressStyle', default = 'line', choices = { 'line', 'ring' } }, -- pup-ui progress bar look
}

-------------------------------------------------------------------------------
-- RECOVERY GAUGE  (post-revive countdown, fired by pup-medical)
-------------------------------------------------------------------------------
Config.Recovery = {
    tickMs = 500,  -- how often the countdown ring redraws
}

-------------------------------------------------------------------------------
-- HEIST GAUGES  (sand timer and alarm, fired by pup_robbery)
-------------------------------------------------------------------------------
Config.Heist = {
    alarmMax = 4,     -- alarm steps for a full ring when pup_robbery sends none
    lingerMs = 4000,  -- a timer that ran out stays full this long before it hides
}
