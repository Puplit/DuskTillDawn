-- vorp_admin | world cleanup
-- The "Clear spawned entities" button on the Anti-Cheat tab. Warns everyone in chat,
-- counts down, then deletes every script-created wagon, horse, ped and prop.
-- Server only. The Discord log goes to the spawnGuard webhook in server/config.lua.

Config.WorldCleanup = {
    enabled    = true,
    permission = 'anticheat_cleanup', -- action key: only holders see the button, and the server re-checks
    seconds    = 10,                  -- countdown before anything is deleted
    announceAt = { 10, 5, 3, 2, 1 },  -- seconds left at which chat is told again
    cooldown   = 60,                  -- seconds after one finishes before another may start

    -- What gets swept. Only script-created entities (population type 7, "mission").
    vehicles = true,
    peds     = true,
    objects  = true,
    -- RedM reports most networked props as population type 0 (unknown) rather than 7.
    -- true = a networked prop with type 0 is treated as script-made too. The game's own
    -- networked props (a townsperson's bucket, a scenario chair) are attached to a ped
    -- that is kept, so they are kept with it.
    objectsUnknownPopType = true,

    -- Players are asked what they are sitting in or on just before the sweep. That
    -- horse, wagon or boat (and the horses in its harness) is never deleted.
    -- Only entities within this many metres of the player who reports them count.
    reportRadius = 30.0,

    -- KEEP. Anything carrying one of these state bag keys is never deleted.
    --   worldCleanupKeep  set by any resource on an entity that must survive a sweep
    keepStateKeys = {
        'worldCleanupKeep',
    },
    -- Models that are never deleted, by name.
    keepModels = {
    },
}

-- Chat and notification text. %d is the number of seconds left.
Config.WorldCleanup.text = {
    chatTitle = 'STAFF',
    warning   = 'All spawned wagons, horses, objects and peds will be deleted in %d seconds.',
    countdown = 'Deleting spawned wagons, horses, objects and peds in %d...',
    done      = 'Spawned wagons, horses, objects and peds have been cleared. Call your horse or wagon again from the stable.',
    started   = 'World cleanup started. Everyone has been warned.',
    running   = 'A world cleanup is already counting down.',
    cooldown  = 'A world cleanup just ran. Wait %d seconds.',
    disabled  = 'World cleanup is turned off in config/worldcleanup.lua.',
    cancelled = 'The world cleanup was cancelled by staff.',
}
