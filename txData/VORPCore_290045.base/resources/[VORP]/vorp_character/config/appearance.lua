-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_character | appearance data
-- Skin tones, heads/bodies, eyes, teeth, body types and face feature sliders for the creator.
-- Values are game asset names/hashes: change labels freely, hashes only if you know them.

-------------------------------------------------------------------------------
-- MISSING HEADS
-------------------------------------------------------------------------------
-- Head numbers that do not exist for a sex. The Heads lists below are shared, but the
-- high entries are male-only. Keyed by head number, so it covers every skin tone.
-- F / M  { [headNumber] = true, ... }
Config.HeadsMissingFor = {
    F = { [18] = true, [21] = true, [22] = true, [25] = true, [28] = true },
    M = {},
}

-------------------------------------------------------------------------------
-- SKIN TONES  (keep the order: entries are picked by index)
-------------------------------------------------------------------------------
-- label     name shown in the creator (change the label only)
-- imgColor  image in images/skin/ (change the image only)
-- Heads / Body / Legs  asset name patterns; %s is replaced by M or F
-- Albedo    head texture pattern for this tone
Config.DefaultChar = {
    {
        label = "White",    -- change label only
        imgColor = "skin1", -- change img only
        Heads = {
            "CLOTHING_ITEM_%s_HEAD_001_V_001",
            "CLOTHING_ITEM_%s_HEAD_002_V_001",
            "CLOTHING_ITEM_%s_HEAD_003_V_001",
            "CLOTHING_ITEM_%s_HEAD_004_V_001",
            "CLOTHING_ITEM_%s_HEAD_005_V_001",
            "CLOTHING_ITEM_%s_HEAD_006_V_001",
            "CLOTHING_ITEM_%s_HEAD_007_V_001",
            "CLOTHING_ITEM_%s_HEAD_008_V_001",
            "CLOTHING_ITEM_%s_HEAD_009_V_001",
            "CLOTHING_ITEM_%s_HEAD_010_V_001",
            "CLOTHING_ITEM_%s_HEAD_011_V_001",
            "CLOTHING_ITEM_%s_HEAD_012_V_001",
            "CLOTHING_ITEM_%s_HEAD_013_V_001",
            "CLOTHING_ITEM_%s_HEAD_014_V_001",
            "CLOTHING_ITEM_%s_HEAD_015_V_001",
            "CLOTHING_ITEM_%s_HEAD_018_V_001",
            "CLOTHING_ITEM_%s_HEAD_021_V_001",
            "CLOTHING_ITEM_%s_HEAD_022_V_001",
            "CLOTHING_ITEM_%s_HEAD_025_V_001",
            "CLOTHING_ITEM_%s_HEAD_028_V_001"
        },
        Body = {
            "CLOTHING_ITEM_%s_BODIES_UPPER_001_V_001",
            "CLOTHING_ITEM_%s_BODIES_UPPER_002_V_001",
            "CLOTHING_ITEM_%s_BODIES_UPPER_003_V_001",
            "CLOTHING_ITEM_%s_BODIES_UPPER_004_V_001",
            "CLOTHING_ITEM_%s_BODIES_UPPER_005_V_001",
        },
        Legs = {
            "CLOTHING_ITEM_%s_BODIES_LOWER_001_V_001",
            "CLOTHING_ITEM_%s_BODIES_LOWER_002_V_001",
            "CLOTHING_ITEM_%s_BODIES_LOWER_003_V_001",
            "CLOTHING_ITEM_%s_BODIES_LOWER_004_V_001",
            "CLOTHING_ITEM_%s_BODIES_LOWER_005_V_001",
        },

        Albedo = {
            "MP_HEAD_%sR1_SC08_C0_000_AB"
        },
    },
    {
        label = "Native Dark",
        imgColor = "skin2",
        Heads = {
            "CLOTHING_ITEM_%s_HEAD_001_V_002",
            "CLOTHING_ITEM_%s_HEAD_002_V_002",
            "CLOTHING_ITEM_%s_HEAD_003_V_002",
            "CLOTHING_ITEM_%s_HEAD_004_V_002",
            "CLOTHING_ITEM_%s_HEAD_005_V_002",
            "CLOTHING_ITEM_%s_HEAD_006_V_002",
            "CLOTHING_ITEM_%s_HEAD_007_V_002",
            "CLOTHING_ITEM_%s_HEAD_008_V_002",
            "CLOTHING_ITEM_%s_HEAD_009_V_002",
            "CLOTHING_ITEM_%s_HEAD_010_V_002",
            "CLOTHING_ITEM_%s_HEAD_011_V_002",
            "CLOTHING_ITEM_%s_HEAD_012_V_002",
            "CLOTHING_ITEM_%s_HEAD_013_V_002",
            "CLOTHING_ITEM_%s_HEAD_014_V_002",
            "CLOTHING_ITEM_%s_HEAD_015_V_002",
            "CLOTHING_ITEM_%s_HEAD_018_V_002",
            "CLOTHING_ITEM_%s_HEAD_021_V_002",
            "CLOTHING_ITEM_%s_HEAD_022_V_002",
            "CLOTHING_ITEM_%s_HEAD_025_V_002",
            "CLOTHING_ITEM_%s_HEAD_028_V_002",
        },
        Body = {
            "CLOTHING_ITEM_%s_BODIES_UPPER_001_V_002",
            "CLOTHING_ITEM_%s_BODIES_UPPER_002_V_002",
            "CLOTHING_ITEM_%s_BODIES_UPPER_003_V_002",
            "CLOTHING_ITEM_%s_BODIES_UPPER_004_V_002",
            "CLOTHING_ITEM_%s_BODIES_UPPER_005_V_002",
        },
        Legs = {
            "CLOTHING_ITEM_%s_BODIES_LOWER_001_V_002",
            "CLOTHING_ITEM_%s_BODIES_LOWER_002_V_002",
            "CLOTHING_ITEM_%s_BODIES_LOWER_003_V_002",
            "CLOTHING_ITEM_%s_BODIES_LOWER_004_V_002",
            "CLOTHING_ITEM_%s_BODIES_LOWER_005_V_002",
        },

        Albedo = { "MP_HEAD_%sR1_SC01_C0_000_AB" },
    },
    {

        label = "Mexican",
        imgColor = "skin3",
        Heads = {
            "CLOTHING_ITEM_%s_HEAD_001_V_003",
            "CLOTHING_ITEM_%s_HEAD_002_V_003",
            "CLOTHING_ITEM_%s_HEAD_003_V_003",
            "CLOTHING_ITEM_%s_HEAD_004_V_003",
            "CLOTHING_ITEM_%s_HEAD_005_V_003",
            "CLOTHING_ITEM_%s_HEAD_006_V_003",
            "CLOTHING_ITEM_%s_HEAD_007_V_003",
            "CLOTHING_ITEM_%s_HEAD_008_V_003",
            "CLOTHING_ITEM_%s_HEAD_009_V_003",
            "CLOTHING_ITEM_%s_HEAD_010_V_003",
            "CLOTHING_ITEM_%s_HEAD_011_V_003",
            "CLOTHING_ITEM_%s_HEAD_012_V_003",
            "CLOTHING_ITEM_%s_HEAD_013_V_003",
            "CLOTHING_ITEM_%s_HEAD_014_V_003",
            "CLOTHING_ITEM_%s_HEAD_015_V_003",
            "CLOTHING_ITEM_%s_HEAD_018_V_003",
            "CLOTHING_ITEM_%s_HEAD_021_V_003",
            "CLOTHING_ITEM_%s_HEAD_022_V_003",
            "CLOTHING_ITEM_%s_HEAD_025_V_003",
            "CLOTHING_ITEM_%s_HEAD_028_V_003",
        },
        Body = {
            "CLOTHING_ITEM_%s_BODIES_UPPER_001_V_003",
            "CLOTHING_ITEM_%s_BODIES_UPPER_002_V_003",
            "CLOTHING_ITEM_%s_BODIES_UPPER_003_V_003",
            "CLOTHING_ITEM_%s_BODIES_UPPER_004_V_003",
            "CLOTHING_ITEM_%s_BODIES_UPPER_005_V_003",
        },
        Legs = {
            "CLOTHING_ITEM_%s_BODIES_LOWER_001_V_003",
            "CLOTHING_ITEM_%s_BODIES_LOWER_002_V_003",
            "CLOTHING_ITEM_%s_BODIES_LOWER_003_V_003",
            "CLOTHING_ITEM_%s_BODIES_LOWER_004_V_003",
            "CLOTHING_ITEM_%s_BODIES_LOWER_005_V_003",
        },

        Albedo = { "MP_HEAD_%sR1_SC02_C0_000_AB" },
    },
    {

        label = "Asian",
        imgColor = "skin4",
        Heads = {
            "CLOTHING_ITEM_%s_HEAD_001_V_004",
            "CLOTHING_ITEM_%s_HEAD_002_V_004",
            "CLOTHING_ITEM_%s_HEAD_003_V_004",
            "CLOTHING_ITEM_%s_HEAD_004_V_004",
            "CLOTHING_ITEM_%s_HEAD_005_V_004",
            "CLOTHING_ITEM_%s_HEAD_006_V_004",
            "CLOTHING_ITEM_%s_HEAD_007_V_004",
            "CLOTHING_ITEM_%s_HEAD_008_V_004",
            "CLOTHING_ITEM_%s_HEAD_009_V_004",
            "CLOTHING_ITEM_%s_HEAD_010_V_004",
            "CLOTHING_ITEM_%s_HEAD_011_V_004",
            "CLOTHING_ITEM_%s_HEAD_012_V_004",
            "CLOTHING_ITEM_%s_HEAD_013_V_004",
            "CLOTHING_ITEM_%s_HEAD_014_V_004",
            "CLOTHING_ITEM_%s_HEAD_015_V_004",
            "CLOTHING_ITEM_%s_HEAD_018_V_004",
            "CLOTHING_ITEM_%s_HEAD_021_V_004",
            "CLOTHING_ITEM_%s_HEAD_022_V_004",
            "CLOTHING_ITEM_%s_HEAD_025_V_004",
            "CLOTHING_ITEM_%s_HEAD_028_V_004",
        },
        Body = {
            "CLOTHING_ITEM_%s_BODIES_UPPER_001_V_004",
            "CLOTHING_ITEM_%s_BODIES_UPPER_002_V_004",
            "CLOTHING_ITEM_%s_BODIES_UPPER_003_V_004",
            "CLOTHING_ITEM_%s_BODIES_UPPER_004_V_004",
            "CLOTHING_ITEM_%s_BODIES_UPPER_005_V_004",
        },
        Legs = {
            "CLOTHING_ITEM_%s_BODIES_LOWER_001_V_004",
            "CLOTHING_ITEM_%s_BODIES_LOWER_002_V_004",
            "CLOTHING_ITEM_%s_BODIES_LOWER_003_V_004",
            "CLOTHING_ITEM_%s_BODIES_LOWER_004_V_004",
            "CLOTHING_ITEM_%s_BODIES_LOWER_005_V_004",
        },

        Albedo = { "MP_HEAD_%sR1_SC03_C0_000_AB" },
    },
    {
        label = "Native",
        imgColor = "skin5",
        Heads = {
            "CLOTHING_ITEM_%s_HEAD_001_V_005",
            "CLOTHING_ITEM_%s_HEAD_002_V_005",
            "CLOTHING_ITEM_%s_HEAD_003_V_005",
            "CLOTHING_ITEM_%s_HEAD_004_V_005",
            "CLOTHING_ITEM_%s_HEAD_005_V_005",
            "CLOTHING_ITEM_%s_HEAD_006_V_005",
            "CLOTHING_ITEM_%s_HEAD_007_V_005",
            "CLOTHING_ITEM_%s_HEAD_008_V_005",
            "CLOTHING_ITEM_%s_HEAD_009_V_005",
            "CLOTHING_ITEM_%s_HEAD_010_V_005",
            "CLOTHING_ITEM_%s_HEAD_011_V_005",
            "CLOTHING_ITEM_%s_HEAD_012_V_005",
            "CLOTHING_ITEM_%s_HEAD_013_V_005",
            "CLOTHING_ITEM_%s_HEAD_014_V_005",
            "CLOTHING_ITEM_%s_HEAD_015_V_005",
            "CLOTHING_ITEM_%s_HEAD_018_V_005",
            "CLOTHING_ITEM_%s_HEAD_021_V_005",
            "CLOTHING_ITEM_%s_HEAD_022_V_005",
            "CLOTHING_ITEM_%s_HEAD_025_V_005",
            "CLOTHING_ITEM_%s_HEAD_028_V_005",
        },
        Body = {
            "CLOTHING_ITEM_%s_BODIES_UPPER_001_V_005",
            "CLOTHING_ITEM_%s_BODIES_UPPER_002_V_005",
            "CLOTHING_ITEM_%s_BODIES_UPPER_003_V_005",
            "CLOTHING_ITEM_%s_BODIES_UPPER_004_V_005",
            "CLOTHING_ITEM_%s_BODIES_UPPER_005_V_005",
        },
        Legs = {
            "CLOTHING_ITEM_%s_BODIES_LOWER_001_V_005",
            "CLOTHING_ITEM_%s_BODIES_LOWER_002_V_005",
            "CLOTHING_ITEM_%s_BODIES_LOWER_003_V_005",
            "CLOTHING_ITEM_%s_BODIES_LOWER_004_V_005",
            "CLOTHING_ITEM_%s_BODIES_LOWER_005_V_005",
        },

        Albedo = { "MP_HEAD_%sR1_SC04_C0_000_AB" },
    },
    {
        label = "African",
        imgColor = "skin6",
        Heads = {
            "CLOTHING_ITEM_%s_HEAD_001_V_006",
            "CLOTHING_ITEM_%s_HEAD_002_V_006",
            "CLOTHING_ITEM_%s_HEAD_003_V_006",
            "CLOTHING_ITEM_%s_HEAD_004_V_006",
            "CLOTHING_ITEM_%s_HEAD_005_V_006",
            "CLOTHING_ITEM_%s_HEAD_006_V_006",
            "CLOTHING_ITEM_%s_HEAD_007_V_006",
            "CLOTHING_ITEM_%s_HEAD_008_V_006",
            "CLOTHING_ITEM_%s_HEAD_009_V_006",
            "CLOTHING_ITEM_%s_HEAD_010_V_006",
            "CLOTHING_ITEM_%s_HEAD_011_V_006",
            "CLOTHING_ITEM_%s_HEAD_012_V_006",
            "CLOTHING_ITEM_%s_HEAD_013_V_006",
            "CLOTHING_ITEM_%s_HEAD_014_V_006",
            "CLOTHING_ITEM_%s_HEAD_015_V_006",
            "CLOTHING_ITEM_%s_HEAD_018_V_006",
            "CLOTHING_ITEM_%s_HEAD_021_V_006",
            "CLOTHING_ITEM_%s_HEAD_022_V_006",
            "CLOTHING_ITEM_%s_HEAD_025_V_006",
            "CLOTHING_ITEM_%s_HEAD_028_V_006",
        },
        Body = {
            "CLOTHING_ITEM_%s_BODIES_UPPER_001_V_006",
            "CLOTHING_ITEM_%s_BODIES_UPPER_002_V_006",
            "CLOTHING_ITEM_%s_BODIES_UPPER_003_V_006",
            "CLOTHING_ITEM_%s_BODIES_UPPER_004_V_006",
            "CLOTHING_ITEM_%s_BODIES_UPPER_005_V_006",
        },
        Legs = {
            "CLOTHING_ITEM_%s_BODIES_LOWER_001_V_006",
            "CLOTHING_ITEM_%s_BODIES_LOWER_002_V_006",
            "CLOTHING_ITEM_%s_BODIES_LOWER_003_V_006",
            "CLOTHING_ITEM_%s_BODIES_LOWER_004_V_006",
            "CLOTHING_ITEM_%s_BODIES_LOWER_005_V_006",
        },

        Albedo = { "MP_HEAD_%sR1_SC05_C0_000_AB" },
    },


}

-------------------------------------------------------------------------------
-- HEAD TEXTURE DEFAULTS
-------------------------------------------------------------------------------
-- Male / Female  { albedo, normal, material, color_type, texture_opacity, unk_arg }
Config.texture_types = {
    Male = {
        albedo = joaat("mp_head_mr1_sc08_c0_000_ab"),
        normal = joaat("mp_head_mr1_008_nm"),
        material = joaat("mp_head_mr1_000_m"),
        color_type = 1,
        texture_opacity = 1.0,
        unk_arg = 0,
    },
    Female = {
        albedo = joaat("mp_head_fr1_sc08_c0_000_ab"),
        normal = joaat("mp_head_fr1_008_nm"),
        material = joaat("mp_head_fr1_000_m"),
        color_type = 1,
        texture_opacity = 1.0,
        unk_arg = 0,
    }
}

-------------------------------------------------------------------------------
-- EYES  (keep the order: entries are picked by index)
-------------------------------------------------------------------------------
-- EyesColor  image names in images/eyes/, same order as Eyes
-- Eyes       eye asset name patterns; %s is replaced by M or F
Config.EyesColor = {
    "color1",
    "color2",
    "color3",
    "color4",
    "color5",
    "color6",
    "color7",
    "color8",
    "color9",
    "color10",
    "color11",
    "color12",
    "color13",
    "color14",
}

Config.Eyes = {

    "CLOTHING_ITEM_%s_EYES_001_TINT_001",
    "CLOTHING_ITEM_%s_EYES_001_TINT_002",
    "CLOTHING_ITEM_%s_EYES_001_TINT_003",
    "CLOTHING_ITEM_%s_EYES_001_TINT_004",
    "CLOTHING_ITEM_%s_EYES_001_TINT_005",
    "CLOTHING_ITEM_%s_EYES_001_TINT_006",
    "CLOTHING_ITEM_%s_EYES_001_TINT_007",
    "CLOTHING_ITEM_%s_EYES_001_TINT_008",
    "CLOTHING_ITEM_%s_EYES_001_TINT_009",
    "CLOTHING_ITEM_%s_EYES_001_TINT_010",
    "CLOTHING_ITEM_%s_EYES_001_TINT_011",
    "CLOTHING_ITEM_%s_EYES_001_TINT_012",
    "CLOTHING_ITEM_%s_EYES_001_TINT_013",
    "CLOTHING_ITEM_%s_EYES_001_TINT_014",

}

-------------------------------------------------------------------------------
-- BODY TYPES  (keep the order: entries are picked by index)
-------------------------------------------------------------------------------
-- Body   body shape hashes
-- Waist  waist shape hashes
Config.BodyType = {
    Body = {
        61606861,
        -1241887289,
        -369348190,
        32611963,
        -20262001,
        -369348190
    },
    Waist = {
        -2045421226,
        -1745814259,
        -325933489,
        -1065791927,
        -844699484,
        -1273449080,
        927185840,
        149872391,
        399015098,
        -644349862,
        1745919061,
        1004225511,
        1278600348,
        502499352,
        -2093198664,
        -1837436619,
        1736416063,
        2040610690,
        -1173634986,
        -867801909,
        1960266524,
    }
}

-------------------------------------------------------------------------------
-- TEETH  (keep the order: entries are picked by index)
-------------------------------------------------------------------------------
-- teeth asset name patterns; %s is replaced by M or F
Config.Teeth = {

    "CLOTHING_ITEM_%s_TEETH_000",
    "CLOTHING_ITEM_%s_TEETH_001",
    "CLOTHING_ITEM_%s_TEETH_002",
    "CLOTHING_ITEM_%s_TEETH_003",
    "CLOTHING_ITEM_%s_TEETH_004",
    "CLOTHING_ITEM_%s_TEETH_005",
    "CLOTHING_ITEM_%s_TEETH_006",
}

-------------------------------------------------------------------------------
-- FACE FEATURES  (slider rows)
-------------------------------------------------------------------------------
-- Grouped by page: head, eyesandbrows, ears, cheek, jaw, chin, nose, mouthandlips,
-- upperbody, lowerbody. Each row: ["Label shown"] = { hash = face feature hash, comp = saved skin field }.
-- You may translate the ["labels"]; never change `comp` (it is the key saved on the character).
-- example: ["Head Width"] = { hash = 0x84D6, comp = "HeadSize" },
Config.FaceFeatures = {
    head = {
        ["Head Width"] = { hash = 0x84D6, comp = "HeadSize" },
        ["Face Width"] = { hash = 41396, comp = "FaceW" },
        ["Face Depth"] = { hash = 12281, comp = "FaceD" },
        ["Forehead Size"] = { hash = 13059, comp = "FaceS" },
        ["Neck Width"] = { hash = 36277, comp = "NeckW" },
        ["Neck Depth"] = { hash = 60890, comp = "NeckD" },
    },

    eyesandbrows = {
        ["Brows Height"] = { hash = 0x3303, comp = "EyeBrowH" },
        ["Brows Width"] = { hash = 0x2FF9, comp = "EyeBrowW" },
        ["Brows Depth"] = { hash = 0x4AD1, comp = "EyeBrowD" },
        ["Eyes Depth"] = { hash = 0xEE44, comp = "EyeD" },
        ["Eyes Angle"] = { hash = 0xD266, comp = "EyeAng" },
        ["Eyes Distance"] = { hash = 0xA54E, comp = "EyeDis" },
        ["Eyes Height"] = { hash = 0xDDFB, comp = "EyeH" },
        ["Eyelid Height"] = { hash = 0x8B2B, comp = "EyeLidH" },
        ["Eyelid Width"] = { hash = 0x1B6B, comp = "EyeLidW" },
        ["Eyelid Left O/Close"] = { hash = 52902, comp = "EyeLidL" },
        ["Eyelid Right O/Close"] = { hash = 22421, comp = "EyeLidR" },
    },

    ears = {
        ["Ears Width"] = { hash = 0xC04F, comp = "EarsW" },
        ["Ears Angle"] = { hash = 0xB6CE, comp = "EarsA" },
        ["Ears Height"] = { hash = 0x2844, comp = "EarsH" },
        ["Ears Depth"] = { hash = 0xED30, comp = "EarsD" },
    },
    cheek = {
        ["CheekBone Height"] = { hash = 0x6A0B, comp = "CheekBonesH" },
        ["CheekBone Width"] = { hash = 0xABCF, comp = "CheekBonesW" },
        ["CheekBone Depth"] = { hash = 0x358D, comp = "CheekBonesD" },
    },
    jaw = {
        ["Jaw Height"] = { hash = 0x8D0A, comp = "JawH" },
        ["Jaw Width"] = { hash = 0xEBAE, comp = "JawW" },
        ["Jaw Depth"] = { hash = 0x1DF6, comp = "JawD" },
    },
    chin = {
        ["Chin Height"] = { hash = 0x3C0F, comp = "ChinH" },
        ["Chin Width"] = { hash = 0xC3B2, comp = "ChinW" },
        ["Chin Depth"] = { hash = 0xE323, comp = "ChinD" },
    },
    nose = {
        ["Nose Width"] = { hash = 0x6E7F, comp = "NoseW" },
        ["Nose Size"] = { hash = 0x3471, comp = "NoseS" },
        ["Nose Height"] = { hash = 0x03F5, comp = "NoseH" },
        ["Nose Angle"] = { hash = 0x34B1, comp = "NoseAng" },
        ["Nose Curvature"] = { hash = 0xF156, comp = "NoseC" },
        ["Nose Distance"] = { hash = 0x561E, comp = "NoseDis" },
    },
    mouthandlips = {
        ["Mouth Width"] = { hash = 0xF065, comp = "MouthW" },
        ["Mouth Depth"] = { hash = 0xAA69, comp = "MouthD" },
        ["Mouth DistanceX"] = { hash = 0x7AC3, comp = "MouthX" },
        ["Mouth DistanceY"] = { hash = 0x410D, comp = "MouthY" },
        ["Lip Upper Height"] = { hash = 0x1A00, comp = "ULiphH" },
        ["Lip Upper Width"] = { hash = 0x91C1, comp = "ULiphW" },
        ["Lip Upper Depth"] = { hash = 0xC375, comp = "ULiphD" },
        ["Lip Lower Height"] = { hash = 0xBB4D, comp = "LLiphH" },
        ["Lip Lower Width"] = { hash = 0xB0B0, comp = "LLiphW" },
        ["Lip Lower Depth"] = { hash = 0x5D16, comp = "LLiphD" },
        ["Mouth Corner Left Withd"] = { hash = 57350, comp = "MouthCLW" },
        ["Mouth Corner Right Withd"] = { hash = 60292, comp = "MouthCRW" },
        ["Mouth Corner Left Depth"] = { hash = 40950, comp = "MouthCLD" },
        ["Mouth Corner Right Depth"] = { hash = 49299, comp = "MouthCRD" },
        ["Mouth Corner Left Height"] = { hash = 46661, comp = "MouthCLH" },
        ["Mouth Corner Right Height"] = { hash = 55718, comp = "MouthCRH" },
        ["Mouth Corner Left Lips Distance"] = { hash = 22344, comp = "MouthCLLD" },
        ["Mouth Corner Right Lips Distance"] = { hash = 9423, comp = "MouthCRLD" },
    },
    upperbody = {
        ["Arms Size"] = { hash = 46032, comp = "ArmsS" },
        ["Upper Shoulders Size"] = { hash = 50039, comp = "ShouldersS" },
        ["Back Shoulders Thickness"] = { hash = 7010, comp = "ShouldersT" },
        ["Back Muscles"] = { hash = 18046, comp = "ShouldersM" }, -- shoulder blades / back muscles
        ["Chest Size"] = { hash = 27779, comp = "ChestS" },
        ["Waist Width"] = { hash = 50460, comp = "WaistW" },
        ["Hips Size"] = { hash = 49787, comp = "HipsS" }, -- hip width / stomach size
    },

    lowerbody = {
        ["Tights Size"] = { hash = 64834, comp = "LegsS" },
        ["Calves Size"] = { hash = 42067, comp = "CalvesS" },
    },

}
