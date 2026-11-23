-- pup-misc/instance | the instanced zones (see README)
-- one example zone; copy the block for each zone you add and give it its own channelId

InstanceConfig.Zones = {
    {
        channelId = 30,
        name = "Example Saloon",
        points = {
            vector2(-312.4, 797.4),
            vector2(-302.5, 799.8),
            vector2(-306.1, 819.9),
            vector2(-316.9, 818.2),
        },
        minZ = 117.0,
        maxZ = 123.5,
        debugGrid = false,
        gridDivisions = 20,
        allowErp = false,
    },
}
