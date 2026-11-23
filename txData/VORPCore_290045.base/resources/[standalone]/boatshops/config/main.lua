-- boatshops | general settings (shared)

BoatConfig = {}

BoatConfig.General = {
    debug = false,
    lang = 'en',
}

-- controls: Space opens, parks, arms a purchase; I opens the boat menu while aboard
BoatConfig.Keys = {
    use = 0xD9D0E1C0,  -- Space
    boatMenu = 0xC1989F95, -- I
}

-- park: delete the boat when it is parked (false = it stays where it was left
-- until its owner takes it out again or leaves the server)
BoatConfig.Park = {
    deleteOnPark = true,
}

-- models that have no anchor (hashes)
BoatConfig.NoAnchor = {
    [1468884243] = true,  -- canoe
    [-666024656] = true,  -- canoeTreeTrunk
}

BoatConfig.Storage = {
    title = 'BOAT STORAGE',
    fallbackSlots = 30,
    -- shared = the contents belong to the boat, not to whoever put them in, so
    -- they go with the boat when it is given away. Only the owner can open it.
    shared = true,
    -- the owner must sit in the boat for the server to open its storage
    requireAboard = true,
    -- used when the server cannot read which vehicle the player is in
    nearBoatMeters = 6.0,
    -- wait between registering a storage and opening it
    registerWaitMs = 200,
}

-- selling a boat with things in its storage: the items are handed to the seller
-- first. If they cannot carry it all (or a weapon is aboard) the sale stops.
BoatConfig.Sell = {
    returnStorage = true,
}

BoatConfig.Give = {
    -- the receiver must be this close to the giver (metres)
    maxDistance = 10.0,
}

BoatConfig.Reach = {
    -- server reach for every shop action: the shop's open radius plus this
    extraMeters = 10.0,
}

BoatConfig.Name = {
    min = 3,
    max = 20,
}

BoatConfig.Timings = {
    spawnGuardMs = 5000,       -- one spawn attempt per this many ms (client)
    armedTipMs = 15000,        -- "press ENTER to buy / pay"
    noModsTipMs = 15000,
    parkedTipMs = 20000,
    tipMs = 4000,
    closedTipMs = 3000,
    spawnFadeMs = 500,
    parkFadeMs = 2000,
    parkHoldMs = 2000,
    idleLoopMs = 1000,
    netWaitMs = 10000,         -- client: wait for the server's boat to reach us
    serverSpawnWaitMs = 5000,  -- server: wait for the created boat to exist
    lostCheckMs = 5000,        -- server: how often out boats are checked
    lostGraceMs = 15000,       -- server: a fresh boat is not checked for this long
    replyWaitMs = 3000,        -- client: longest wait for a server answer
    keeperFaceMs = 10000,
    rateLimitMs = 750,         -- server: one action per player per this many ms
}

-- the spawn guard in vorp_admin cancels client-created keel boats and steam
-- boats. Owned boats are created by the server, and the owner is also given a
-- short grant in case the guard sees them as the boat's first owner.
BoatConfig.Spawn = {
    -- 'rpc' = CreateVehicle on the server; 'setter' = CreateVehicleServerSetter
    -- with type 'boat' (falls back to 'rpc' if it fails).
    -- Keep 'rpc' while vorp_admin's guard is on: its entityCreated handler deletes
    -- a keel boat or steam boat that has no player owner, which is what a
    -- 'setter' boat is when it is made.
    method = 'rpc',
    guardGrantMs = 15000,
    -- players this much further from the launch point than the buyer also get
    -- the grant, in case the game hands the creation to them
    grantMarginMeters = 5.0,
}

BoatConfig.Blips = {
    scale = 0.2,
    shopStyle = 1664425300,
    boatStyle = 953018525,
    boatSprite = 'blip_canoe',
    boatModifier = 'BLIP_MODIFIER_MP_COLOR_32',
    closedModifier = 'BLIP_MODIFIER_MP_COLOR_2',
}

BoatConfig.Keeper = {
    voice = '0317_U_M_M_NBXGENERALSTOREOWNER_01',
    params = 'Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath',
    -- local peds are made only while the player is this close
    spawnMeters = 80.0,
    despawnMeters = 120.0,
}

-- upgrade categories, in menu order
BoatConfig.Categories = { 'Tints', 'Extras', 'Liveries', 'Propsets' }
