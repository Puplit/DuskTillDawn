-- pup_tailor | main settings. Shared by the client and the server.
Config = {}

Config.Debug = false          -- console tracing

Config.CopyPrice = 5          -- cash for "Create Clothing Item" (copy what you wear)
Config.BenchReach = 15.0      -- metres: how close the server wants you to a bench for paid work
Config.PromptDistance = 1.0   -- metres: how close the prompt shows
Config.MaxAmount = 100        -- most copies one make request may ask for; more is refused with a message
Config.PassUnknownPosition = true -- a player whose position the server cannot see passes the bench check if they have the job

-- Dyeing
Config.DyeMaterials = {
    flat = {                  -- taken once per dye job
        { name = 'leather', label = 'Leather', count = 2 },
        { name = 'wool',    label = 'Wool',    count = 2 },
    },
    perGarment = {            -- taken once for every garment recoloured
        { name = 'acid', label = 'Acid', count = 1 },
    },
}

-- Keys (hashes of game controls)
Config.Keys = {
    open      = 0x760A9C6F, -- G
    reset     = 0x8CC9CD42, -- X
    camUp     = 0xD9D0E1C0, -- SPACE
    camDown   = 0x8AAA0AD4, -- LEFT ALT
    zoomIn    = 0x8FFC75D6, -- SHIFT
    zoomOut   = 0xDB096B85, -- CTRL
    turnLeft  = 0xDE794E3E, -- Q
    turnRight = 0xCEFD9220, -- E
}
-- extra game controls switched off while the showroom keys are live
Config.ShowroomExtraDisabled = { 0x4D8FB4C1, 0xFDA83190 }

Config.Blip = { style = 1664425300, scale = 0.8 }

-- Benches. jobLocked = false lets everyone work there.
-- floorZ: exact ground height for the mannequin (peds inside an interior); nil uses z - 0.98.
Config.Benches = {
    {
        name = 'Emerald Tailor', sprite = 990667866, jobLocked = true,
        prompt = vector3(1417.9791, 377.9896, 89.9704),
        jobs = { 'emtailor' },
        mannequin = vector4(1419.7186, 376.3692, 89.9704, 277.7155),
    },
    {
        name = 'Black Water Tailor', sprite = 990667866, jobLocked = true,
        prompt = vector3(-762.293, -1290.351, 43.484),
        jobs = { 'bwtailor' },
        mannequin = vector4(-764.414, -1291.313, 43.485, 284.92),
    },
    {
        name = 'Saint Denis Tailor', sprite = 990667866, jobLocked = true,
        prompt = vector3(2554.709, -1171.636, 53.334),
        jobs = { 'sdtailor' },
        mannequin = vector4(2550.904, -1165.008, 53.334, 189.56),
    },
    {
        name = 'valentine Tailor', sprite = 990667866, jobLocked = true,
        prompt = vector3(-295.747, 810.454, 118.842),
        jobs = { 'vttailor' },
        mannequin = vector4(-298.233, 810.559, 118.842, 281.97),
        floorZ = 118.192,
    },
}

-- Who counts as staff (hide garments, /hiddengarments)
Config.StaffGroups = { admin = true, superadmin = true }
Config.StaffPermissionKey = 'admin_actions_menu' -- asked of vorp_admin's hasPermission when it runs

-- Default teeth put in when a whole set leaves none
Config.DefaultTeeth = { male = 1629650936, female = 959712255 }

-- Mannequin camera
Config.Camera = {
    fov = 40.0, easeMs = 500,
    zoomStart = 2.8, zoomMin = 0.7, zoomMax = 2.8,
    raiseStart = -0.15, raiseMin = -1.0, raiseMax = 1.2,
    sideOffset = 0.35,    -- metres the look-at point sits beside the ped, so the menu does not cover it
    showroom = { turn = 2.0, zoom = 0.03, raise = 0.02 },  -- per frame
    book     = { turn = 20.0, zoom = 0.2, raise = 0.2 },   -- per key press in the dye book
}
