-- pup-misc/cannon | main settings (see README)

CannonConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
CannonConfig.General = {
    command       = 'gat',        -- /gat <key>
    removeCommand = 'gatremove',
}

-- turning keys
CannonConfig.Keys = {
    rotateLeft  = 0xA65EBAB4,   -- LEFT arrow
    rotateRight = 0xDEB34313,   -- RIGHT arrow
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
CannonConfig.Integrations = {}

-------------------------------------------------------------------------------
-- ACCESS  (checked on the server)
-------------------------------------------------------------------------------
CannonConfig.Access = {
    jobs     = { 'police', 'marshal' },  -- jobs allowed to place a piece
    minGrade = 5,                        -- default lowest job grade
    -- also has to be on duty in pup-mdt
}

-------------------------------------------------------------------------------
-- MODELS
-------------------------------------------------------------------------------
CannonConfig.Models = {
    { key = 1, model = 'breach_cannon',    label = 'Breach Cannon',    minGrade = 5 },
    { key = 2, model = 'hotchkiss_cannon', label = 'Hotchkiss Cannon', minGrade = 5 },
    { key = 3, model = 'gatling_gun',      label = 'Gatling Gun',      minGrade = 5 },
    { key = 4, model = 'gatlingMaxim02',   label = 'Maxim Gun',        minGrade = 5 },
}

-------------------------------------------------------------------------------
-- PLACEMENT
-------------------------------------------------------------------------------
CannonConfig.Placement = {
    maxPerPlayer      = 2,     -- pieces one player can have out at once
    spawnForward      = 2.5,   -- metres in front of the placer
    rotateStepDegrees = 1.5,   -- degrees per frame
    rotateDistance    = 4.0,   -- metres
    despawnMinutes    = 45,    -- 0 = never
}
