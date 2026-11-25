-- fred_hud | config/locale.lua
-- Every player-facing string. The whole table is sent to the NUI page for the /hud editor.
-- \194\176 is the degree sign.

Locale = {
    -- chat tips
    hudSaved = "HUD saved.",
    hudWhy   = "HUD hidden? pause=%s faded=%s charScreen=%s",

    -- gauge caption before the first temperature reading
    tempLoading = "Loading...",

    -- editor panel
    editorTitle    = "HUD",
    sectionDisplay = "Display",
    sectionPosition = "Position",
    positionHint   = "Drag a gauge, or click a row to reset it",
    buttonSave     = "Save",
    buttonReset    = "Reset All",
    buttonClose    = "Close",
    positionDefault = "default",

    -- setting row names
    settingTempUnit  = "Temperature",
    settingMoney     = "Money",
    settingMoneyFont = "Money Font",
    settingMoneySize = "Money Size",
    settingHunger    = "Hunger",
    settingThirst    = "Thirst",
    settingMenuSide  = "Menus",
    settingProgressStyle = "Progress Bar",

    -- setting values
    valueMenuRight   = "Right side",
    valueMenuLeft    = "Left side",
    valueFahrenheit  = "Fahrenheit  \194\176F",
    valueCelsius     = "Celsius  \194\176C",
    valueHidden      = "Hidden",
    valueAlwaysShown = "Always shown",
    valueFontDisplay = "Display",
    valueFontClassic = "Classic",
    valueSizeSmall   = "Small",
    valueSizeLarge   = "Large",
    valueSizeNormal  = "Normal",
    valueBelow       = "Below %d%",   -- %d = the threshold percent
    valueProgressLine = "Line",
    valueProgressRing = "Ring",

    -- position row names
    elementHunger   = "Hunger",
    elementThirst   = "Thirst",
    elementTemp     = "Temperature",
    elementRecovery = "Recovery",
    elementMoney    = "Money",
    elementId       = "Player ID",
    elementMail     = "Mail Icon",
    elementEco      = "Eco Boost",
    elementHeist    = "Heist Timer",
    elementAlarm    = "Heist Alarm",
    elementProgress = "Progress Bar",
    elementVoice    = "Voice",
}
