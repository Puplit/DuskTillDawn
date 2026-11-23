-- pup_staffdesk | Discord bridge (server only; token, channel and roles are in server/config.lua)

Config.Discord = {
    enabled         = true,  -- master switch (it also stays off while the token or channel is blank)
    prefix          = '!',   -- command prefix
    intervalSeconds = 3,     -- seconds between channel reads
    reply           = true,  -- post each command's result back into the channel
    audit           = true,  -- keep every command in the staffdesk_audit table

    -- Places for !tp <id> <place>. Each is { x, y, z, heading }; the name is what staff type (lower case).
    spots = {
        -- New Hanover
        valentine  = { -168.334,  629.548,   113.682, 249.71 },  -- main street (spawn card)
        annesburg  = { 2941.408,  1270.714,  44.286,  251.56 },  -- town centre (spawn card)
        vanhorn    = { 2892.96,   626.84,    57.75,   0.0 },     -- train stop

        -- Lemoyne
        saintdenis = { 2683.254,  -1449.095, 45.924,  26.88 },   -- city centre (spawn card)
        rhodes     = { 1238.492,  -1314.886, 76.554,  132.63 },  -- main street (spawn card)

        -- West Elizabeth
        blackwater = { -764.851,  -1272.531, 43.691,  0.0 },     -- sheriff's office
        strawberry = { -1813.876, -354.970,  164.299, 0.0 },     -- sheriff's office
        riggs      = { -1100.474, -577.260,  82.045,  155.30 },  -- Riggs Station (spawn card)

        -- New Austin
        armadillo  = { -3743.879, -2602.451, -13.590, 97.09 },   -- town centre (spawn card)
        tumbleweed = { -5526.588, -2928.456, -1.711,  0.0 },     -- sheriff's office
    },
}
