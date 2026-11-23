-------------------------------------------------------------------------------
-- TIME PRESETS
-------------------------------------------------------------------------------
Config.TimePresets = {
    { name = "Dawn",          hour = 5,  minute = 30 },
    { name = "Morning",       hour = 8,  minute = 0  },
    { name = "Noon",          hour = 12, minute = 0  },
    { name = "Afternoon",     hour = 15, minute = 0  },
    { name = "Golden Hour",   hour = 18, minute = 30 },
    { name = "Dusk",          hour = 20, minute = 0  },
    { name = "Night",         hour = 23, minute = 0  },
    { name = "Dead of Night", hour = 2,  minute = 0  },
}

-------------------------------------------------------------------------------
-- WEATHER PRESETS
-------------------------------------------------------------------------------
Config.WeatherPresets = {
    "sunny", "highpressure", "clouds", "overcast", "overcastdark",
    "misty", "fog", "drizzle", "rain", "shower", "thunder", "thunderstorm",
    "hail", "sleet", "snow", "snowlight", "blizzard", "groundblizzard",
    "whiteout", "sandstorm", "hurricane",
}

-------------------------------------------------------------------------------
-- SLOW MOTION
-------------------------------------------------------------------------------
Config.TimeScales = { 1.0, 0.5, 0.25, 0.1 }

-------------------------------------------------------------------------------
-- STYLES  (colour grades)
-------------------------------------------------------------------------------
Config.Styles = {
    { name = "Off" },
    { name = "Portrait",     tc = "Online_Character_Editor" },
    { name = "Sepia",        tc = "sepia" },
    { name = "Old Photo",    tc = "PlayerTonic" },
    { name = "Moonlight",    tc = "MP_Night_Vision" },
    { name = "Storm",        tc = "Storm" },
    { name = "Golden Hour",  tc = "Sunset" },
    { name = "Cold",         tc = "Snow" },
    { name = "Fever Dream",  tc = "PlayerDrunk" },
    { name = "Underwater",   tc = "Underwater" },
}

-------------------------------------------------------------------------------
-- SCREEN EFFECTS
-------------------------------------------------------------------------------
Config.ScreenFx = {
    { name = "None" },
    { name = "Dead Eye",     fx = "DeadEye" },
    { name = "Drunk",        fx = "PlayerDrunk" },
    { name = "Damaged",      fx = "DamageIndicator" },
}

-------------------------------------------------------------------------------
-- CAMERA FEEL
-------------------------------------------------------------------------------
Config.FeelPresets = {
    { name = "Handheld",   speed = 0.45, look = 6.0, fov = 50.0 },
    { name = "Slow Dolly", speed = 0.12, look = 2.5, fov = 40.0 },
    { name = "Wide Vista", speed = 0.90, look = 6.0, fov = 85.0 },
    { name = "Telephoto",  speed = 0.25, look = 2.0, fov = 18.0 },
}
