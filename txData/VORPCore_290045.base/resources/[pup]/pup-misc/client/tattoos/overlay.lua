-- pup-misc / tattoos - face overlays (makeup, tattoos, scars), the camera and the shop prompts

-- Table to store blip objects
local blips = {}
-- Random integers for prompt group IDs
local prompts = GetRandomIntInRange(0, 0xffffff)
local prompts2 = GetRandomIntInRange(0, 0xffffff)
-- Prompt variables
local TattooOpenMenuPrompt
local rotate1
local enterconfirm
local backspacebutton
local resetcam
local movecameraup
local movecameradown
local zoomin
local zoomout
local rotate2
local TattooOpenMenuPrompt2
-- Camera and UI state variables
local cam = nil
local camx = false 
local TattooCurrentMenu = ''
local TattooInMenu = false 
local mirrorobject = nil 
local TattooOpenConfirmMenu
-- Master table for overlay definitions (Hashes)
local overlays_info = {

    ["eyebrows"] = {
                    {id=0x07844317,albedo=0xF81B2E66,normal=0x7BC4288B,ma=0x202674A1,},    --   {albedo="mp_u_faov_eyebrow_m_012_ab",normal="mp_u_faov_eyebrow_m_012_nm",ma="mp_u_faov_eyebrow_m_012_ma",},
                    {id=0x0A83CA6E,albedo=0x8FA4286B,normal=0xBD811948,ma=0xB82C8FBB,},    --   {albedo="mp_u_faov_eyebrow_m_006_ab",normal="mp_u_faov_eyebrow_m_006_nm",ma="mp_u_faov_eyebrow_m_006_ma",},
                    {id=0x139A5CA3,albedo=0x487ABE5A,normal=0x22A9DDF9,ma=0x78AA9401,},    --   {albedo="mp_u_faov_eyebrow_m_003_ab",normal="mp_u_faov_eyebrow_m_003_nm",ma="mp_u_faov_eyebrow_m_003_ma",},
                    {id=0x1832E474,albedo=0x96FBB931,normal=0x32FA2683,ma=0xA1775B18,},    --   {albedo="mp_u_faov_eyebrow_m_011_ab",normal="mp_u_faov_eyebrow_m_011_nm",ma="mp_u_faov_eyebrow_m_011_ma",},
                    {id=0x216EF84C,albedo=0x269CD8F8,normal=0x2F54C727,ma=0xCCBD1939,},    --   {albedo="mp_u_faov_eyebrow_m_002_ab",normal="mp_u_faov_eyebrow_m_002_nm",ma="mp_u_faov_eyebrow_m_002_ma",},
                    {id=0x2594304D,albedo=0xA5A23CD1,normal=0x8611B42C,ma=0x0238302B,},    --   {albedo="mp_u_faov_eyebrow_f_004_ab",normal="mp_u_faov_eyebrow_f_004_nm",ma="mp_u_faov_eyebrow_f_004_ma",},
                    {id=0x33C39BC5,albedo=0xF928E29B,normal=0x46C268BD,ma=0x4B92F13E,},    --   {albedo="mp_u_faov_eyebrow_m_013_ab",normal="mp_u_faov_eyebrow_m_013_nm",ma="mp_u_faov_eyebrow_m_013_ma",},
                    {id=0x443E3CBA,albedo=0x6C83B571,normal=0x2B191070,ma=0xD551E623,},    --   {albedo="mp_u_faov_eyebrow_m_014_ab",normal="mp_u_faov_eyebrow_m_014_nm",ma="mp_u_faov_eyebrow_m_014_ma",},
                    {id=0x4F5052DE,albedo=0x827EEF46,normal=0x70E8C702,ma=0xD97518F9,},    --   {albedo="mp_u_faov_eyebrow_m_015_ab",normal="mp_u_faov_eyebrow_m_015_nm",ma="mp_u_faov_eyebrow_m_015_ma",},
                    {id=0x5C049D35,albedo=0x41E90506,normal=0x7E47D163,ma=0x54100288,},    --   {albedo="mp_u_faov_eyebrow_f_001_ab",normal="mp_u_faov_eyebrow_f_001_nm",ma="mp_u_faov_eyebrow_f_001_ma",},
                    {id=0x77A1546E,albedo=0x43C4AE44,normal=0x290FC7F7,ma=0xD8FC26A9,},    --   {albedo="mp_u_faov_eyebrow_f_003_ab",normal="mp_u_faov_eyebrow_f_003_nm",ma="mp_u_faov_eyebrow_f_003_ma",},
                    {id=0x8A4B79C2,albedo=0xAE6ED4E6,normal=0x89B29E5A,ma=0xFA0476E4,},    --   {albedo="mp_u_faov_eyebrow_f_002_ab",normal="mp_u_faov_eyebrow_f_002_nm",ma="mp_u_faov_eyebrow_f_002_ma",},
                    {id=0x9728137B,albedo=0x23E65D35,normal=0xEE39073F,ma=0x218DD4C8,},    --   {albedo="mp_u_faov_eyebrow_f_006_ab",normal="mp_u_faov_eyebrow_f_006_nm",ma="mp_u_faov_eyebrow_f_006_ma",},
                    {id=0xA6DE8325,albedo=0x7A93F649,normal=0x22B33B65,ma=0xEE6CCF11,},    --   {albedo="mp_u_faov_eyebrow_m_008_ab",normal="mp_u_faov_eyebrow_m_008_nm",ma="mp_u_faov_eyebrow_m_008_ma",},
                    {id=0xA8CCB6C4,albedo=0x29AD8BF9,normal=0x34ABB09D,ma=0xCF206860,},    --   {albedo="mp_u_faov_eyebrow_f_005_ab",normal="mp_u_faov_eyebrow_f_005_nm",ma="mp_u_faov_eyebrow_f_005_ma",},
                    {id=0xB3F74D19,albedo=0x3E2F71B1,normal=0xD4809D11,ma=0x9ABFA640,},    --   {albedo="mp_u_faov_eyebrow_f_007_ab",normal="mp_u_faov_eyebrow_f_007_nm",ma="mp_u_faov_eyebrow_f_007_ma",},
                    {id=0xBD38AFD9,albedo=0x058A698E,normal=0x9A732F86,ma=0x2EF1D769,},    --   {albedo="mp_u_faov_eyebrow_m_007_ab",normal="mp_u_faov_eyebrow_m_007_nm",ma="mp_u_faov_eyebrow_m_007_ma",},
                    {id=0xCD0A4F7C,albedo=0xED46998E,normal=0xB5B73A38,ma=0x15C5FB78,},    --   {albedo="mp_u_faov_eyebrow_m_009_ab",normal="mp_u_faov_eyebrow_m_009_nm",ma="mp_u_faov_eyebrow_m_009_ma",},
                    {id=0xD0EC86FF,albedo=0x81B462A2,normal=0x894F8744,ma=0x51551810,},    --   {albedo="mp_u_faov_eyebrow_f_000_ab",normal="mp_u_faov_eyebrow_f_000_nm",ma="mp_u_faov_eyebrow_f_000_ma",},
                    {id=0xEB088A20,albedo=0x0C6CDBDC,normal=0x91A2496E,ma=0xE639F138,},    --   {albedo="mp_u_faov_eyebrow_m_010_ab",normal="mp_u_faov_eyebrow_m_010_nm",ma="mp_u_faov_eyebrow_m_010_ma",},
                    {id=0xF0CA96FC,albedo=0xAC3BCA3F,normal=0x667FEFF8,ma=0xDD8E5EFF,},    --   {albedo="mp_u_faov_eyebrow_m_005_ab",normal="mp_u_faov_eyebrow_m_005_nm",ma="mp_u_faov_eyebrow_m_005_ma",},
                    {id=0xF3351BD9,albedo=0xC3286EA4,normal=0x8BB9158A,ma=0xFBBAE4D8,},    --   {albedo="mp_u_faov_eyebrow_m_001_ab",normal="mp_u_faov_eyebrow_m_001_nm",ma="mp_u_faov_eyebrow_m_001_ma",},
                    {id=0xF9052779,albedo=0x8AEADE78,normal=0x21BB2D97,ma=0x75A0B928,},    --   {albedo="mp_u_faov_eyebrow_m_000_ab",normal="mp_u_faov_eyebrow_m_000_nm",ma="mp_u_faov_eyebrow_m_000_ma",},
                    {id=0xFE183197,albedo=0x92B508CD,normal=0x6AA92A3E,ma=0xB4A436DB,},    --   {albedo="mp_u_faov_eyebrow_m_004_ab",normal="mp_u_faov_eyebrow_m_004_nm",ma="mp_u_faov_eyebrow_m_004_ma",},
                },

    ["scars"] =     {
                    {id=0xC8E45B5B,albedo=0x6245579F,normal=0xD53A336F,},       -- {albedo="mp_u_faov_scar_000_ab",normal="mp_u_faov_scar_000_nm",},
                    {id=0x90D86B44,albedo=0xA1538E6F,normal=0xDFCB1159,},       -- {albedo="mp_u_faov_scar_001_ab",normal="mp_u_faov_scar_001_nm",},
                    {id=0x23190FC3,albedo=0x39683ECE,normal=0x249C1A0A,},       -- {albedo="mp_u_faov_scar_002_ab",normal="mp_u_faov_scar_002_nm",},
                    {id=0x7574B47D,albedo=0x3AB2A0BB,normal=0x7A70886A,},       -- {albedo="mp_u_faov_scar_003_ab",normal="mp_u_faov_scar_003_nm",},
                    {id=0x7FE8C965,albedo=0xB81C8D16,normal=0x7210971B,},       -- {albedo="mp_u_faov_scar_004_ab",normal="mp_u_faov_scar_004_nm",},
                    {id=0x083059FE,albedo=0xC332710C,normal=0x860EE45E,},       -- {albedo="mp_u_faov_scar_005_ab",normal="mp_u_faov_scar_005_nm",},
                    {id=0x19E9FD71,albedo=0x40895310,normal=0xB753C5C7,},       -- {albedo="mp_u_faov_scar_006_ab",normal="mp_u_faov_scar_006_nm",},
                    {id=0x4CAF62FB,albedo=0xD80F2F64,normal=0x00BBF225,},       -- {albedo="mp_u_faov_scar_007_ab",normal="mp_u_faov_scar_007_nm",},
                    {id=0xDE650668,albedo=0x85F6BF71,normal=0x3DD0B0AE,},       -- {albedo="mp_u_faov_scar_008_ab",normal="mp_u_faov_scar_008_nm",},
                    {id=0xC648562B,albedo=0x6397E4D9,normal=0x2B59CDA1,},       -- {albedo="mp_u_faov_scar_009_ab",normal="mp_u_faov_scar_009_nm",},
                    {id=0x484BAEF8,albedo=0xBF2946DE,normal=0xD3F2F2F6,},       -- {albedo="mp_u_faov_scar_010_ab",normal="mp_u_faov_scar_010_nm",},
                    {id=0x190F5080,albedo=0xCBBDB741,normal=0x9518FA34,},       -- {albedo="mp_u_faov_scar_011_ab",normal="mp_u_faov_scar_011_nm",},
                    {id=0x2B5DF51D,albedo=0x0E05C415,normal=0x8B8C57AC,},       -- {albedo="mp_u_faov_scar_012_ab",normal="mp_u_faov_scar_012_nm",},
                    {id=0xE490E784,albedo=0x50853115,normal=0xDA7F2A1E,},       -- {albedo="mp_u_faov_scar_013_ab",normal="mp_u_faov_scar_013_nm",},
                    {id=0x0ED23C06,albedo=0xAEA45D76,normal=0x364DAAA6,},       -- {albedo="mp_u_faov_scar_014_ab",normal="mp_u_faov_scar_014_nm",},
                    {id=0x5712CCB6,albedo=0x9318AF61,normal=0x98104C8C,},       -- {albedo="mp_u_faov_scar_015_ab",normal="mp_u_faov_scar_015_nm",},

                },  

    ["eyeliners"] = {
                    {id=0x29A2E58F,albedo=0xA952BF75,ma=0xDD55AF2A,},                                                -- {albedo="mp_u_faov_eyeliner_000_ab",ma="mp_u_faov_eyeliner_000_ma",},
                },

    ["lipsticks"] = {
                    {id=0x887E11E0,albedo=0x96A5E4FB,normal=0x1C77591C,ma=0x4255A5F4,},                              -- {albedo="mp_u_faov_lipstick_000_ab",normal="mp_u_faov_lipstick_000_nm",ma="mp_u_faov_lipstick_000_ma",},  -- 7 variants
                },

    ["acne"] =  {
                    {id=0x96DD8F42,albedo=0x1BA4244B,normal=0xBA46CE92,},                                           -- {albedo="mp_u_faov_acne_000_ab",normal="mp_u_faov_acne_000_nm",},
                },

    ["shadows"] = {
                    {id=0x47BD7289,albedo=0x5C5C98FC,ma=0xE20345CC,},                                               -- {albedo="mp_u_faov_eyeshadow_000_ab",ma="mp_u_faov_eyeshadow_000_ma",},  -- 6 variants
                },

    ["beardstabble"] = {
                    {id=0x375D4807,albedo=0xB5827817,normal=0x5041B648,ma=0x83F42340,},                              -- {albedo="mp_u_faov_beard_000_ab",normal="mp_u_faov_beard_000_nm",ma="mp_u_faov_beard_000_ma",},
                },

    ["paintedmasks"] = {
                    {id=0x5995AA6F,albedo=0x99BCB03F,},                                                              -- {albedo="mp_u_faov_masks_000_ab",},
                },

    ["ageing"]  = {
                    {id=0x96DD8F42,albedo=0x1BA4244B,normal=0xBA46CE92,},                                            -- {albedo="mp_u_faov_acne_000_ab",normal="mp_u_faov_acne_000_nm",},
                    {id=0x6D9DC405,albedo=0xAFE82F0C,normal=0x5CF8808E,},                                            -- {albedo="mp_u_faov_ageing_000_ab",normal="mp_u_faov_ageing_000_nm",},
                    {id=0x2761B792,albedo=0x4105C6B3,normal=0x8607CC56,},                                            -- {albedo="mp_u_faov_ageing_001_ab",normal="mp_u_faov_ageing_001_nm",},
                    {id=0x19009AD0,albedo=0xEBC18618,normal=0x9087AF96,},                                            -- {albedo="mp_u_faov_ageing_002_ab",normal="mp_u_faov_ageing_002_nm",},
                    {id=0xC29F6E07,albedo=0xF9887FA7,normal=0x1331C3C9,},                                            -- {albedo="mp_u_faov_ageing_003_ab",normal="mp_u_faov_ageing_003_nm",},
                    {id=0xA45F3187,albedo=0x1C30961A,normal=0x3CA2F3AE,},                                            -- {albedo="mp_u_faov_ageing_004_ab",normal="mp_u_faov_ageing_004_nm",},
                    {id=0x5E21250C,albedo=0x01E35044,normal=0x5A965FF0,},                                            -- {albedo="mp_u_faov_ageing_005_ab",normal="mp_u_faov_ageing_005_nm",},
                    {id=0x4FFE08C6,albedo=0xA65757F2,normal=0xC46CC005,},                                            -- {albedo="mp_u_faov_ageing_006_ab",normal="mp_u_faov_ageing_006_nm",},
                    {id=0x2DAD4485,albedo=0x358DEFDA,normal=0x55D317B4,},                                            -- {albedo="mp_u_faov_ageing_007_ab",normal="mp_u_faov_ageing_007_nm",},
                    {id=0x3F70680B,albedo=0x7073A58F,normal=0x33E73C5F,},                                            -- {albedo="mp_u_faov_ageing_008_ab",normal="mp_u_faov_ageing_008_nm",},
                    {id=0xD3310F8E,albedo=0xD9E8A605,normal=0x22297EA5,},                                            -- {albedo="mp_u_faov_ageing_009_ab",normal="mp_u_faov_ageing_009_nm",},
                    {id=0xF27A4C84,albedo=0xE0F0971B,normal=0x9F0E6718,},                                            -- {albedo="mp_u_faov_ageing_010_ab",normal="mp_u_faov_ageing_010_nm",},
                    {id=0x0044E819,albedo=0xFD844ADF,normal=0x315A6D56,},                                            -- {albedo="mp_u_faov_ageing_011_ab",normal="mp_u_faov_ageing_011_nm",},
                    {id=0xA648348D,albedo=0xC329F765,normal=0xE8CD7F20,},                                            -- {albedo="mp_u_faov_ageing_012_ab",normal="mp_u_faov_ageing_012_nm",},
                    {id=0x94F991F0,albedo=0x8586D19B,normal=0xCA334396,},                                            -- {albedo="mp_u_faov_ageing_013_ab",normal="mp_u_faov_ageing_013_nm",},
                    {id=0xCAACFD56,albedo=0xD2D0BF4F,normal=0xE0203BDA,},                                            -- {albedo="mp_u_faov_ageing_014_ab",normal="mp_u_faov_ageing_014_nm",},
                    {id=0xB9675ACB,albedo=0x2387AF71,normal=0x90A80AE1,},                                            -- {albedo="mp_u_faov_ageing_015_ab",normal="mp_u_faov_ageing_015_nm",},
                    {id=0x3C2CE03C,albedo=0xC6DCBCCA,normal=0x609B7EBD,},                                            -- {albedo="mp_u_faov_ageing_016_ab",normal="mp_u_faov_ageing_016_nm",},
                    {id=0xF2D64D90,albedo=0xC6DCBCCA,normal=0x609B7EBD,},                                            -- {albedo="mp_u_faov_ageing_016_ab",normal="mp_u_faov_ageing_016_nm",},
                    {id=0xE389AEF7,albedo=0xDF591FF2,normal=0x11D92A14,},                                            -- {albedo="mp_u_faov_ageing_018_ab",normal="mp_u_faov_ageing_018_nm",},
                    {id=0x89317A44,albedo=0xB4640D19,normal=0x2F56FDA5,},                                            -- {albedo="mp_u_faov_ageing_019_ab",normal="mp_u_faov_ageing_019_nm",},
                    {id=0x64B3347C,albedo=0xFF2E8F96,normal=0x45EE7B10,},                                            -- {albedo="mp_u_faov_ageing_020_ab",normal="mp_u_faov_ageing_020_nm",},
                    {id=0x9FFDAB10,albedo=0x8F2950D9,normal=0x85BDD7E8,},                                            -- {albedo="mp_u_faov_ageing_021_ab",normal="mp_u_faov_ageing_021_nm",},
                    {id=0x91D40EBD,albedo=0x5DCD1D4E,normal=0xA1B5F71F,},                                            -- {albedo="mp_u_faov_ageing_022_ab",normal="mp_u_faov_ageing_022_nm",},
                    {id=0x6B94C23F,albedo=0xF17FE41C,normal=0x0C480977,},                                            -- {albedo="mp_u_faov_ageing_023_ab",normal="mp_u_faov_ageing_023_nm",},
                },
    ["blush"] = {
                    {id=0x6DB440FA,albedo=0x43B1AACA,},                                                              -- {albedo="mp_u_faov_blush_000_ab",},
                    {id=0x47617455,albedo=0x9CAD2EF0,},                                                              -- {albedo="mp_u_faov_blush_001_ab",},
                    {id=0x114D082D,albedo=0xA52E3B98,},                                                              -- {albedo="mp_u_faov_blush_002_ab",},
                    {id=0xEC6F3E72,albedo=0xB5CED4CB,},                                                              -- {albedo="mp_u_faov_blush_003_ab",},
                },
    ["complex"] = {
                    {id=0xF679EDE7,albedo=0xFAAE9FF0,},                                                              -- {albedo="mp_u_faov_complex_000_ab",},
                    {id=0x3FFB80ED,albedo=0x1FDFD4A1,},                                                              -- {albedo="mp_u_faov_complex_001_ab",},
                    {id=0x31C0E478,albedo=0xC72D0698,},                                                              -- {albedo="mp_u_faov_complex_002_ab",},
                    {id=0x2457C9A6,albedo=0x98F1C76F,},                                                              -- {albedo="mp_u_faov_complex_003_ab",},
                    {id=0x16262D43,albedo=0xE0D03293,},                                                              -- {albedo="mp_u_faov_complex_004_ab",},
                    {id=0x88F312DB,albedo=0x2ECCC670,},                                                              -- {albedo="mp_u_faov_complex_005_ab",},
                    {id=0x785C71AE,albedo=0xAE1C329F,},                                                              -- {albedo="mp_u_faov_complex_006_ab",},
                    {id=0x6D7D5BF0,albedo=0x23201E55,},                                                              -- {albedo="mp_u_faov_complex_007_ab",},
                    {id=0x5F2FBF55,albedo=0x94503F97,},                                                              -- {albedo="mp_u_faov_complex_008_ab",},
                    {id=0xBF38FF6A,albedo=0x5F62F986,},                                                              -- {albedo="mp_u_faov_complex_009_ab",},
                    {id=0xF5656C26,albedo=0x83417009,},                                                              -- {albedo="mp_u_faov_complex_010_ab",},
                    {id=0x03A408A3,albedo=0x1BCC4185,},                                                              -- {albedo="mp_u_faov_complex_011_ab",},
                    {id=0x293453C3,albedo=0x6C556574,},                                                              -- {albedo="mp_u_faov_complex_012_ab",},
                    {id=0x43150800,albedo=0x1E486F85,},                                                              -- {albedo="mp_u_faov_complex_013_ab",},
                },
    ["disc"]  = {
                    {id=0xD44A5ABA,albedo=0x2D3AEB2F,},                                                              -- {albedo="mp_u_faov_disc_000_ab",},
                    {id=0xE2CF77C4,albedo=0xB8945AC0,},                                                              -- {albedo="mp_u_faov_disc_001_ab",},
                    {id=0xCF57D0E9,albedo=0xB15E4E47,},                                                              -- {albedo="mp_u_faov_disc_002_ab",},
                    {id=0xE0A8738A,albedo=0x25A711DD,},                                                              -- {albedo="mp_u_faov_disc_003_ab",},
                    {id=0xABD109DC,albedo=0xCEBED6D9,},                                                              -- {albedo="mp_u_faov_disc_004_ab",},
                    {id=0xB91C2472,albedo=0xFDD6C9AB,},                                                              -- {albedo="mp_u_faov_disc_005_ab",},
                    {id=0x894844B7,albedo=0x7E89B165,},                                                              -- {albedo="mp_u_faov_disc_006_ab",},
                    {id=0x96FAE01C,albedo=0x458799CD,},                                                              -- {albedo="mp_u_faov_disc_007_ab",},
                    {id=0x86D3BFCE,albedo=0x8F2F2826,},                                                              -- {albedo="mp_u_faov_disc_008_ab",},
                    {id=0x5488DB39,albedo=0xB49A0275,},                                                              -- {albedo="mp_u_faov_disc_009_ab",},
                    {id=0x7DA5A5AE,albedo=0x8200F51D,},                                                              -- {albedo="mp_u_faov_disc_010_ab",},
                    {id=0xE73778DC,albedo=0x8D35AC90,},                                                              -- {albedo="mp_u_faov_disc_011_ab",},
                    {id=0xD83EDADF,albedo=0x96B619CD,},                                                              -- {albedo="mp_u_faov_disc_012_ab",},
                    {id=0xE380F163,albedo=0xAB7309F7,},                                                              -- {albedo="mp_u_faov_disc_013_ab",},
                    {id=0xB4611324,albedo=0x26FEBDD4,},                                                              -- {albedo="mp_u_faov_disc_014_ab",},
                    {id=0xC6ABB7B9,albedo=0xC162C835,},                                                              -- {albedo="mp_u_faov_disc_015_ab",},
                },
    ["foundation"] = {
                    {id=0xEF5AB280,albedo=0xD9264247,ma=0x1535C7C9,},                                                -- {albedo="mp_u_faov_foundation_000_ab",ma="mp_u_faov_foundation_000_ma",},
                },
    ["freckles"] =  {
                    {id=0x1B794C51,albedo=0x59B8159A,},                                                              -- {albedo="mp_u_faov_freckles_000_ab",},
                    {id=0x29BFE8DE,albedo=0x03FCF67B,},                                                              -- {albedo="mp_u_faov_freckles_001_ab",},
                    {id=0x0EF6B34C,albedo=0x21E2FD82,},                                                              -- {albedo="mp_u_faov_freckles_002_ab",},
                    {id=0x64925E7E,albedo=0x3FD45844,},                                                              -- {albedo="mp_u_faov_freckles_003_ab",},
                    {id=0xF5F280FC,albedo=0xE372E00E,},                                                              -- {albedo="mp_u_faov_freckles_004_ab",},
                    {id=0x33B0FC78,albedo=0x288810E0,},                                                              -- {albedo="mp_u_faov_freckles_005_ab",},
                    {id=0x25675FE5,albedo=0xEB8C0B1D,},                                                              -- {albedo="mp_u_faov_freckles_006_ab",},
                    {id=0xD10F3736,albedo=0x3885AC2A,},                                                              -- {albedo="mp_u_faov_freckles_007_ab",},
                    {id=0x5126B75F,albedo=0xB061C984,},                                                              -- {albedo="mp_u_faov_freckles_008_ab",},
                    {id=0x6B8EEC2F,albedo=0xE1D1113E,},                                                              -- {albedo="mp_u_faov_freckles_009_ab",},
                    {id=0x0A9A26F7,albedo=0xA1EC1AEA,},                                                              -- {albedo="mp_u_faov_freckles_010_ab",},
                    {id=0xFDE40D8B,albedo=0x6DBC9203,},                                                              -- {albedo="mp_u_faov_freckles_011_ab",},
                    {id=0x7E338E44,albedo=0x097D1D0A,},                                                              -- {albedo="mp_u_faov_freckles_012_ab",},
                    {id=0x70F273C2,albedo=0x81A25BCE,},                                                              -- {albedo="mp_u_faov_freckles_013_ab",},
                    {id=0x61C7D56D,albedo=0x197A1335,},                                                              -- {albedo="mp_u_faov_freckles_014_ab",},  
    },
    ["grime"] =     {
                    {id=0xA2F30923,albedo=0x16CDD724,normal=0x136165B3,ma=0xF3DFA7AC,},                              -- {albedo="mp_u_faov_grime_000_ab",normal="mp_u_faov_grime_000_nm",ma="mp_u_faov_grime_000_ma",},
                    {id=0xD5B1EEA0,albedo=0x0E599D69,normal=0x5C67FB68,ma=0x40FEC59E,},                              -- {albedo="mp_u_faov_grime_001_ab",normal="mp_u_faov_grime_001_nm",ma="mp_u_faov_grime_001_ma",},
                    {id=0x7EC740CC,albedo=0x0FAE8DC6,normal=0x9E7A4B63,ma=0xB48BF65A,},                              -- {albedo="mp_u_faov_grime_002_ab",normal="mp_u_faov_grime_002_nm",ma="mp_u_faov_grime_002_ma",},
                    {id=0xB08F245B,albedo=0x98358521,normal=0x1FAA4A84,ma=0x81428E8F,},                              -- {albedo="mp_u_faov_grime_003_ab",normal="mp_u_faov_grime_003_nm",ma="mp_u_faov_grime_003_ma",},
                    {id=0x1A5E77F8,albedo=0x8D3D2563,normal=0x1FAA4A84,ma=0x81428E8F,},                              -- {albedo="mp_u_faov_grime_004_ab",normal="mp_u_faov_grime_003_nm",ma="mp_u_faov_grime_003_ma",},
                    {id=0xE81B9373,albedo=0xAE43378D,normal=0x0CBEEF9B,ma=0x92097B22,},                              -- {albedo="mp_u_faov_grime_005_ab",normal="mp_u_faov_grime_005_nm",ma="mp_u_faov_grime_005_ma",},
                    {id=0x3CFA3D2F,albedo=0x7499570E,normal=0xA27FF667,ma=0x24B49749,},                              -- {albedo="mp_u_faov_grime_006_ab",normal="mp_u_faov_grime_006_nm",ma="mp_u_faov_grime_006_ma",},
                    {id=0x0B865A48,albedo=0xB80F6B12,normal=0x377319E3,ma=0x3CDC25A9,},                              -- {albedo="mp_u_faov_grime_007_ab",normal="mp_u_faov_grime_007_nm",ma="mp_u_faov_grime_007_ma",},
                    {id=0x506DE416,albedo=0x537BA522,normal=0x006AF092,ma=0x5CCEA9F8,},                              -- {albedo="mp_u_faov_grime_008_ab",normal="mp_u_faov_grime_008_nm",ma="mp_u_faov_grime_008_ma",},
                    {id=0x1F250185,albedo=0x51BE975D,normal=0x3F718027,ma=0x5527ACCF,},                              -- {albedo="mp_u_faov_grime_009_ab",normal="mp_u_faov_grime_009_nm",ma="mp_u_faov_grime_009_ma",},
                    {id=0xE71930B0,albedo=0x595D09A3,normal=0xF4E08D43,ma=0x60B91CE7,},                              -- {albedo="mp_u_faov_grime_010_ab",normal="mp_u_faov_grime_010_nm",ma="mp_u_faov_grime_010_ma",},
                    {id=0xDE571F2C,albedo=0xE7FAFDFA,normal=0xE6A18BBF,ma=0xCB315A57,},                              -- {albedo="mp_u_faov_grime_011_ab",normal="mp_u_faov_grime_011_nm",ma="mp_u_faov_grime_011_ma",},
                    {id=0x0CA6FBCB,albedo=0x0E27372E,normal=0xD4894921,ma=0xBF339D56,},                              -- {albedo="mp_u_faov_grime_012_ab",normal="mp_u_faov_grime_012_nm",ma="mp_u_faov_grime_012_ma",},
                    {id=0x21F62669,albedo=0x693623F0,normal=0xDB95176C,ma=0xEA27B375,},                              -- {albedo="mp_u_faov_grime_013_ab",normal="mp_u_faov_grime_013_nm",ma="mp_u_faov_grime_013_ma",},
                    {id=0xFB09D881,albedo=0xC4A40DA0,normal=0xADD1DC3D,ma=0xFD797A87,},                              -- {albedo="mp_u_faov_grime_014_ab",normal="mp_u_faov_grime_014_nm",ma="mp_u_faov_grime_014_ma",},
                    {id=0x11530513,albedo=0x67C6D30F,normal=0x26AA38C3,ma=0x89C2FFE3,},                              -- {albedo="mp_u_faov_grime_015_ab",normal="mp_u_faov_grime_015_nm",ma="mp_u_faov_grime_015_ma",},
                },
    ["hair"] =  {
                    {id=0x39051515,albedo=0x60A4A360,normal=0x8D65EFF2,ma=0x62759D82,},                              -- {albedo="mp_u_faov_m_hair_000_ab",normal="mp_u_faov_m_hair_000_nm",ma="mp_u_faov_m_hair_000_ma",},
                    {id=0x5E71DFEE,albedo=0x71147B90,ma=0xD8EB57BC,},                                                -- {albedo="mp_u_faov_m_hair_002_ab",ma="mp_u_faov_m_hair_002_ma",},
                    {id=0xDD735DEF,albedo=0x493214E4,ma=0x6613D121,},                                                -- {albedo="mp_u_faov_m_hair_009_ab",ma="mp_u_faov_m_hair_009_ma",},
                    {id=0x69622EAD,albedo=0xA6E819C4,ma=0xE581D851,},                                                -- {albedo="mp_u_faov_m_hair_shared_000_ab",ma="mp_u_faov_m_hair_shared_000_ma",},
                },
    ["moles"] = {
                    {id=0x821FD077,albedo=0xDFDA0798,normal=0xE4E90C92,},                                            -- {albedo="mp_u_faov_moles_000_ab",normal="mp_u_faov_moles_000_nm",},
                    {id=0xCD38E6A8,albedo=0xE9CF623E,normal=0x43FAEA4B,},                                            -- {albedo="mp_u_faov_moles_001_ab",normal="mp_u_faov_moles_001_nm",},
                    {id=0x9F9D8B72,albedo=0x27450B2F,normal=0x0808DBFB,},                                            -- {albedo="mp_u_faov_moles_002_ab",normal="mp_u_faov_moles_002_nm",},
                    {id=0xE7179A39,albedo=0x38638E0B,normal=0x99346057,},                                            -- {albedo="mp_u_faov_moles_003_ab",normal="mp_u_faov_moles_003_nm",},
                    {id=0xBB094249,albedo=0x763F8624,normal=0x6975D6F9,},                                            -- {albedo="mp_u_faov_moles_004_ab",normal="mp_u_faov_moles_004_nm",},
                    {id=0x03AC5362,albedo=0xEF158115,normal=0xBA297751,},                                            -- {albedo="mp_u_faov_moles_005_ab",normal="mp_u_faov_moles_005_nm",},
                    {id=0x154FF6A9,albedo=0xEE28E6F7,normal=0xB7548307,},                                            -- {albedo="mp_u_faov_moles_006_ab",normal="mp_u_faov_moles_006_nm",},
                    {id=0x1E23084F,albedo=0x566ACE2F,normal=0x361237C6,},                                            -- {albedo="mp_u_faov_moles_007_ab",normal="mp_u_faov_moles_007_nm",},
                    {id=0x31DBAFC0,albedo=0x0AB0CC2B,normal=0xDBF55701,},                                            -- {albedo="mp_u_faov_moles_008_ab",normal="mp_u_faov_moles_008_nm",},
                    {id=0x3AC5C194,albedo=0xC940CC25,normal=0x41CB48FC,},                                            -- {albedo="mp_u_faov_moles_009_ab",normal="mp_u_faov_moles_009_nm",},
                    {id=0x4500D516,albedo=0x3A1EEDB1,normal=0x17BC19B0,},                                            -- {albedo="mp_u_faov_moles_010_ab",normal="mp_u_faov_moles_010_nm",},
                    {id=0x3695B840,albedo=0x1D30222E,normal=0xDA5FDF7E,},                                            -- {albedo="mp_u_faov_moles_011_ab",normal="mp_u_faov_moles_011_nm",},
                    {id=0x286C1BED,albedo=0x4F0B4FA8,normal=0x40333534,},                                            -- {albedo="mp_u_faov_moles_012_ab",normal="mp_u_faov_moles_012_nm",},
                    {id=0x934BF1AF,albedo=0x4540A8D7,normal=0x933ACF76,},                                            -- {albedo="mp_u_faov_moles_013_ab",normal="mp_u_faov_moles_013_nm",},
                    {id=0x84F55502,albedo=0x47BE6D32,normal=0xDCF7108E,},                                            -- {albedo="mp_u_faov_moles_014_ab",normal="mp_u_faov_moles_014_nm",},
                    {id=0xBD9A464B,albedo=0x9DABB1B9,normal=0x4A3B1739,},                                            -- {albedo="mp_u_faov_moles_015_ab",normal="mp_u_faov_moles_015_nm",},
                },
    ["spots"] = {
                    {id=0x5BBFF5F7,albedo=0x24968425,normal=0xA5D532AD,},                                            -- {albedo="mp_u_faov_spots_000_ab",normal="mp_u_faov_spots_000_nm",},
                    {id=0x65EC0A4F,albedo=0x326A7845,normal=0xC09B2354,},                                            -- {albedo="mp_u_faov_spots_001_ab",normal="mp_u_faov_spots_001_nm",},
                    {id=0x3F143CA0,albedo=0x91D7E39E,normal=0xD607DF75,},                                            -- {albedo="mp_u_faov_spots_002_ab",normal="mp_u_faov_spots_002_nm",},
                    {id=0x49675146,albedo=0x2E6C3769,normal=0xE6A21CD5,},                                            -- {albedo="mp_u_faov_spots_003_ab",normal="mp_u_faov_spots_003_nm",},
                    {id=0x07504D2D,albedo=0x39F16CE6,normal=0x5CB32D5C,},                                            -- {albedo="mp_u_faov_spots_004_ab",normal="mp_u_faov_spots_004_nm",},
                    {id=0xF161214F,albedo=0x47C60FBA,normal=0x19424C77,},                                            -- {albedo="mp_u_faov_spots_005_ab",normal="mp_u_faov_spots_005_nm",},
                    {id=0xE43286F2,albedo=0xA7E86379,normal=0x7C07E0B0,},                                            -- {albedo="mp_u_faov_spots_006_ab",normal="mp_u_faov_spots_006_nm",},
                    {id=0xDDDC7A46,albedo=0x26D3DA64,normal=0x5A69A9BB,},                                            -- {albedo="mp_u_faov_spots_007_ab",normal="mp_u_faov_spots_007_nm",},
                    {id=0xD086DF9B,albedo=0x7D6FF58C,normal=0x5A0D99C8,},                                            -- {albedo="mp_u_faov_spots_008_ab",normal="mp_u_faov_spots_008_nm",},
                    {id=0xBA51B331,albedo=0xCB23CA55,normal=0xA7720C6A,},                                            -- {albedo="mp_u_faov_spots_009_ab",normal="mp_u_faov_spots_009_nm",},
                    {id=0xE4CF097B,albedo=0x51D0FBDA,normal=0xB01F5202,},                                            -- {albedo="mp_u_faov_spots_010_ab",normal="mp_u_faov_spots_010_nm",},
                    {id=0xF70CADF6,albedo=0xD0858DFC,normal=0x7E067837,},                                            -- {albedo="mp_u_faov_spots_011_ab",normal="mp_u_faov_spots_011_nm",},
                    {id=0xC07F40DC,albedo=0x3BAF1008,normal=0x75030E1B,},                                            -- {albedo="mp_u_faov_spots_012_ab",normal="mp_u_faov_spots_012_nm",},
                    {id=0xD3B1E741,albedo=0x97091388,normal=0xA191AA56,},                                            -- {albedo="mp_u_faov_spots_013_ab",normal="mp_u_faov_spots_013_nm",},
                    {id=0xB494A903,albedo=0x18025AE1,normal=0x86F51AD1,},                                            -- {albedo="mp_u_faov_spots_014_ab",normal="mp_u_faov_spots_014_nm",},
                    {id=0xC6EE4DB6,albedo=0xC9F3EBA4,normal=0xE819AD33,},                                            -- {albedo="mp_u_faov_spots_015_ab",normal="mp_u_faov_spots_015_nm",},
                },
}

-- an overlay another system now owns (see TattooConfig.Layers.excluded)
local function TattooExcluded(name)
    return TattooConfig.Layers.excluded ~= nil and TattooConfig.Layers.excluded[name] == true
end

-- drop excluded layers out of anything loaded from the database, so an old saved row cannot put them back on the ped
local function TattooStripExcluded(t)
    if type(t) ~= 'table' then return t end
    for name in pairs(TattooConfig.Layers.excluded or {}) do t[name] = nil end
    return t
end

-- is this layer one of the makeup ones (TattooConfig.Layers.makeup)?
local function TattooIsMakeup(name)
    for _, n in ipairs(TattooConfig.Layers.makeup or {}) do
        if n == name then return true end
    end
    return false
end

-- the label a player should see for a layer
local function TattooLabel(name)
    return TattooLocale.layers[name] or name
end

-- `onlyMakeup` nil = everything except makeup (the top level),
-- true = just the makeup layers (the Makeup submenu).
local function getSortedOverlayNames(onlyMakeup)
    local names = {}
    for name in pairs(overlays_info) do
        if not TattooExcluded(name) then
            local isMakeup = TattooIsMakeup(name)
            if (onlyMakeup and isMakeup) or (not onlyMakeup and not isMakeup) then
                table.insert(names, name)
            end
        end
    end
    table.sort(names, function(a, b)
        return string.lower(TattooLabel(a)) < string.lower(TattooLabel(b))
    end)
    return names
end

local info = {}
-- the same rows kept aside: `info` is replaced wholesale by the database row on load,
-- and without a template a missing layer could not be rebuilt
local infoDefaults = {}
Citizen.CreateThread(function()
    for k,v in pairs(overlays_info) do
        if not TattooExcluded(k) then
            if k == "scars" or k == "spots" or k == "disc" or k == "complex" or k == "acne" or k == "ageing" or k == "moles" or k == "freckles" then
                info[k] = {visibility = 0,tx_id = 1,var = 0,tx_color_type = 1 ,opacity = 1.0 ,palette_id = 1,
                palette_color_primary = 0,palette_color_secondary = 0,palette_color_tertiary = 0 }
            else
                info[k] = {visibility = 0,tx_id = 1,var = 0,tx_color_type = 0 ,opacity = 1.0 ,palette_id = 1,
                palette_color_primary = 0,palette_color_secondary = 0,palette_color_tertiary = 0 }
            end
            local copy = {}
            for x, y in pairs(info[k]) do copy[x] = y end
            infoDefaults[k] = copy
        end
    end
end)

-- rebuild any layer the saved row does not carry, seeded from the character's skin
local function TattooBackfill(playerskin)
    if type(playerskin) ~= 'table' then return end
    for k, def in pairs(infoDefaults) do
        if info[k] == nil then
            local row = {}
            for x, y in pairs(def) do
                local saved = playerskin[k .. "_" .. x]
                row[x] = saved ~= nil and saved or y
            end
            -- vorp_character calls the shade <name>_color; here it is the palette's primary colour
            local colour = playerskin[k .. "_color"] or playerskin[k .. "_color_primary"]
            if colour ~= nil then row.palette_color_primary = colour end
            info[k] = row
        end
    end
end

local texture_types = {
    ["male"] = {
        albedo=GetHashKey("head_fr1_sc08_soft_c0_001_ab"),
        normal=GetHashKey("mp_head_mr1_000_nm"),
        material=0x50A4BBA9,
        color_type=1,
        texture_opacity=1.0,
        unk_arg=0,
    },
    ["female"] = {
        albedo=GetHashKey("mp_head_fr1_sc08_c0_000_ab"),
        normal=GetHashKey("head_fr1_mp_002_nm"),
        material=0x7FC5B1E1, 
        color_type=1,
        texture_opacity=1.0,
        unk_arg=0,
    }
}
local overlay_all_layers = {
    {name="eyebrows",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,    },                                      
    {name="scars",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,       },                                      
    {name="eyeliners",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,   },                                      
    {name="lipsticks",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,   },                                      
    {name="acne",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,        },                                      
    {name="shadows",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,     },                                      
    {name="beardstabble",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,},                                      
    {name="paintedmasks",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,},                                      
    {name="ageing",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,      },                                      
    {name="blush",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,       },                                      
    {name="complex",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,     },                                      
    {name="disc",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,        },                                      
    {name="foundation",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,  },                                      
    {name="freckles",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,    },                                      
    {name="grime",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,       },                                      
    {name="hair",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,        },                                      
    {name="moles",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,       },                                      
    {name="spots",visibility=0,tx_id=1,tx_normal=0,tx_material=0,tx_color_type=0,tx_opacity=1.0,tx_unk=0,palette=0,palette_color_primary=0,palette_color_secondary=0,palette_color_tertiary=0,var=0,opacity=1.0,       },                                      
}

-- accessors for nui.lua: the menu lives there, the engine and its locals stay here
function TattooGetInfo() return info end
function TattooSetInfo(t) info = t end
function TattooGetCatalog() return overlays_info end
function TattooSetCamx(v) camx = v and true or false end
function TattooSetInMenu(v) TattooInMenu = v and true or false end
function TattooHasMirror() return mirrorobject ~= nil end
function TattooClearMirror()
    if mirrorobject then
        ClearPedTasks(PlayerPedId())
        DeleteEntity(mirrorobject)
        mirrorobject = nil
    end
end

RegisterNetEvent('pup-misc:overlay:recinfo')
AddEventHandler('pup-misc:overlay:recinfo', function(skin,overlayinfo)
	local playerskin = json.decode(skin)
    local overlay = json.decode(overlayinfo)
    local ped = PlayerPedId()
    if IsPedMale(ped) then
        texture_types["male"].albedo = playerskin.albedo
    else
        texture_types["female"].albedo = playerskin.albedo
    end 
    -- mark the layers as loaded so TattooLocationTrigger stops re-asking on every menu open and overwriting unsaved work
    TattooLoaded = true

    if next(overlay) ~= nil then
        -- an older save may still carry a layer another system owns now
        info = TattooStripExcluded(overlay)
        -- ...and it may be missing a layer this menu owns
        TattooBackfill(playerskin)
    else
        for k,v in pairs(info) do 
            if playerskin[k.."_tx_id"] ~= 1 then 
                for x,y in pairs(v) do 
                    if playerskin[k.."_"..x] ~= nil then
                        info[k][x] = playerskin[k.."_"..x]
                    end
                end
            end
        end
        local infox = json.encode(info)
        TriggerServerEvent("pup-misc:overlay:savetodb2",infox)    
    end
    Wait(250)
    TattooApply()
    Wait(500)
    TriggerEvent("pup-misc:overlay:applyExpressionsToPed")

end)

-- DISGUISE (blood vials): wear somebody else's layers and body adjustments. Nothing here is saved; the wearer's own
-- rows come back through walkanim:overlay when the disguise ends.
RegisterNetEvent('pup-misc:overlay:applyDisguise')
AddEventHandler('pup-misc:overlay:applyDisguise', function(skin, overlayinfo, expressions)
    local ok1, playerskin = pcall(json.decode, skin or "{}")
    local ok2, overlay = pcall(json.decode, overlayinfo or "{}")
    if not ok1 or type(playerskin) ~= 'table' then playerskin = {} end
    if not ok2 or type(overlay) ~= 'table' then overlay = {} end

    local ped = PlayerPedId()
    if playerskin.albedo then
        texture_types[IsPedMale(ped) and "male" or "female"].albedo = playerskin.albedo
    end
    TattooLoaded = true

    if next(overlay) ~= nil then
        info = TattooStripExcluded(overlay)
    else
        -- they never used the mirror: fresh defaults, seeded from their skin below
        info = {}
        for k, def in pairs(infoDefaults) do
            local row = {}
            for x, y in pairs(def) do row[x] = y end
            info[k] = row
        end
    end
    TattooBackfill(playerskin)
    Wait(250)
    TattooApply()
    Wait(300)
    TriggerEvent("pup-misc:overlay:receiveExpressions", expressions or "{}")
end)

local color_palettes = {
    {0x3F6E70FF,},
    {0x0105607B,},
    {0x17CBCC83,},
    {0x29F81B2A,},
    {0x3385C5DB,},
    {0x37CD36D4,},
    {0x4101ED87,},
    {0x63838A81,},
    {0x6765BC15,},
    {0x8BA18876,},
    {0x9AC34F34,},
    {0x9E4803A0,},
    {0xA4041CEF,},
    {0xA4CFABD0,},
    {0xAA65D8A3,},
    {0xB562025C,},
    {0xB9E7F722,},
    {0xBBF43EF8,},
    {0xD1476963,},
    {0xD799E1C2,},
    {0xDC6BC93B,},
    {0xDFB1F64C,},
    {0xF509C745,},
    {0xF93DB0C8,},
    {0xFB71527B,},
}

function TattooKeysx(table)
    local keys = 0
    for k,v in pairs(table) do
       keys = keys + 1
    end
    return keys
end

local current_texture_settings = texture_types["male"]

local textureId = -1
local overlay_opacity = 1.0
local is_overlay_change_active = false

-- tx_color_type: 0 = RGB from palette, 1 = current white texture RGB,
--                2 = current black texture RGB.

local function toggleOverlayChange(name,visibility,tx_id,tx_normal,tx_material,tx_color_type,tx_opacity,tx_unk,palette_id,palette_color_primary,palette_color_secondary,palette_color_tertiary,var,opacity)
    for k,v in pairs(overlay_all_layers) do
        if v.name==name then
            v.visibility = visibility
            if visibility ~= 0 then
                v.tx_normal = tx_normal
                v.tx_material = tx_material
                v.tx_color_type = tx_color_type
                v.tx_opacity =  tx_opacity
                v.tx_unk =  tx_unk
                if  tx_color_type == 0 then
                    if color_palettes[palette_id] == nil and palette_id == 0 then 
                        palette_id = 1
                    end
                    v.palette = color_palettes[palette_id][1]
                    v.palette_color_primary = palette_color_primary
                    v.palette_color_secondary = palette_color_secondary
                    v.palette_color_tertiary = palette_color_tertiary
                end
                if name == "shadows" or name == "eyeliners" or name == "lipsticks" then
                    v.var = var
                    v.tx_id = overlays_info[name][1].id
                else
                    v.var = 0
                    if overlays_info[name][tx_id] ~= nil then 
                        v.tx_id = overlays_info[name][tx_id].id
                    end
                end
                v.opacity = opacity
            end
        end
    end
    is_overlay_change_active = true
end

-- Main thread to handle overlay application logic
Citizen.CreateThread(function()
    while true do
        -- Dynamic wait for performance optimization (1000ms idle, 5ms active)
        local waitTime = 1000
        if is_overlay_change_active then
            waitTime = 5
        end
        Citizen.Wait(waitTime)

        if is_overlay_change_active then  
            local ped = PlayerPedId()
            if IsPedMale(ped) then
                current_texture_settings = texture_types["male"]
            else
                current_texture_settings = texture_types["female"]
            end          
            if textureId ~= -1 then
                Citizen.InvokeNative(0xB63B9178D0F58D82,textureId)  -- reset texture
                Citizen.InvokeNative(0x6BEFAA907B076859,textureId)  -- remove texture
            end
            textureId = Citizen.InvokeNative(0xC5E7204F322E49EB,current_texture_settings.albedo, current_texture_settings.normal, current_texture_settings.material);  -- create texture
            for k,v in pairs(overlay_all_layers) do
                if v.visibility ~= 0 then
                    local overlay_id = Citizen.InvokeNative(0x86BB5FF45F193A02,textureId, v.tx_id , v.tx_normal, v.tx_material, v.tx_color_type, v.tx_opacity,v.tx_unk); -- create overlay
                    if v.tx_color_type == 0 then
                        Citizen.InvokeNative(0x1ED8588524AC9BE1,textureId,overlay_id,v.palette);    -- TattooApply palette
                        Citizen.InvokeNative(0x2DF59FFE6FFD6044,textureId,overlay_id,v.palette_color_primary,v.palette_color_secondary,v.palette_color_tertiary)  -- TattooApply palette colours
                    end
                    Citizen.InvokeNative(0x3329AAE2882FC8E4,textureId,overlay_id, v.var);  -- TattooApply overlay variant
                    Citizen.InvokeNative(0x6C76BC24F8BB709A,textureId,overlay_id, v.opacity); -- TattooApply overlay opacity
                end
            end
            -- Wait for the GPU to finish loading the texture BOUNDED
            local deadline = GetGameTimer() + 5000
            while not Citizen.InvokeNative(0x31DC8D3F216D8509,textureId) and GetGameTimer() < deadline do
                Citizen.Wait(5) -- 5ms active wait
            end
            if Citizen.InvokeNative(0x31DC8D3F216D8509,textureId) then
                Citizen.InvokeNative(0x0B46E25761519058,ped,`heads`,textureId)  -- TattooApply texture to current component in category "heads"
                Citizen.InvokeNative(0x92DAABA2C1C10B0E,textureId)      -- update texture
                Citizen.InvokeNative(0xCC8CA3E88256E58F,ped, 0, 1, 1, 1, false);  -- refresh ped components
            else
                print(("^1[pup-misc/tattoos]^7 overlay texture %s never became valid after 5s - face not updated this pass")
                    :format(tostring(textureId)))
            end
            is_overlay_change_active = false
        end
    end
end)

-- arg[1] name: name of overlay (list below) arg[2] visibility: 0 or 1 arg[3] tx_id
function TattooFetchMenuData()
    if TattooMenuData ~= nil then return end
    local ok, data = pcall(function() return exports['pup-ui']:GetMenuData() end)
    if ok and type(data) == 'table' and data.Open ~= nil then
        TattooMenuData = data
        return
    end
    TriggerEvent("menuapi:getData", function(call) TattooMenuData = call end)
end
TattooFetchMenuData()

AddEventHandler('onClientResourceStart', function(res)
    if res == 'pup-ui' then
        Citizen.CreateThread(function()
            Citizen.Wait(1000)
            TattooFetchMenuData()
        end)
    end
end)

-- call before touching TattooMenuData; ~2s ceiling so a late answer is covered
function TattooEnsureMenuData()
    if TattooMenuData ~= nil then return true end
    for _ = 1, 100 do
        TattooFetchMenuData()
        if TattooMenuData ~= nil then return true end
        Citizen.Wait(20)
    end
    print("^1[pup-misc/tattoos]^7 pup-ui never answered menuapi:getData - menus unavailable")
    return false
end

-- false until the saved layers have loaded from the server
TattooLoaded = false

function TattooLocationTrigger()
    if not TattooLoaded then
        TriggerServerEvent("pup-misc:overlay:walkanim")
        Wait(500)
    end
    -- opens the page in html/tattoos/ (nui.lua)
    TattooInMenu = true
    TattooNuiOpen()
end

function TattooContains(table, element)
    if table ~= 0 then 
        for k, v in pairs(table) do
            if k == element then
                return true
            end
        end
    end
return false
end

local namex
local visibilityx
local tx_idx
local varx
local palette_idx
local palette_color_primaryx
local palette_color_secondaryx
local palette_color_tertiaryx
local opacityx

-- LAYERS THIS MENU DOES NOT OWN, but still has to draw
local function TattooSeedExcluded()
    if GetResourceState('vorp_character') ~= 'started' then return end
    for name in pairs(TattooConfig.Layers.excluded or {}) do
        local ok, raw = pcall(function()
            return exports['vorp_character']:OverlayRaw(name)
        end)
        if ok and type(raw) == 'table' then
            -- mirrors vorp_character's own eyebrow call (ApplyFaceOverlays), so the layer is built here exactly as it is built there
            toggleOverlayChange(name, raw.visibility, raw.tx_id, 1, 0, 0, 1.0, 0, 1,
                raw.colour, 0, 0, 1, raw.opacity)
        end
    end
end

function TattooApply()
    for k,v in pairs(info) do
        toggleOverlayChange(k,v.visibility,v.tx_id,0,0,v.tx_color_type,1.0,0,v.palette_id,v.palette_color_primary,v.palette_color_secondary,v.palette_color_tertiary,v.var,v.opacity)
    end
    TattooSeedExcluded()
end

-- rebuilds the overlay texture after a ped rebuild (/rc), backfilling anything missing
-- (TattooBackfill), plus the layers vorp_character owns,
-- read back live in TattooSeedExcluded
exports('ReapplyOverlayTexture', function()
    if not TattooLoaded then return false end
    TattooApply()
    return true
end)

function TattooApplyAndSave()
    for k,v in pairs(info) do
        toggleOverlayChange(k,v.visibility,v.tx_id,0,0,v.tx_color_type,1.0,0,v.palette_id,v.palette_color_primary,v.palette_color_secondary,v.palette_color_tertiary,v.var,v.opacity)
    end
    TattooSeedExcluded()
    local infox = json.encode(info)
    TriggerServerEvent("pup-misc:overlay:savetodb",infox,true)
end

-- ADD / REMOVE
local function TattooIsOn(name)
    return info[name] ~= nil and (tonumber(info[name].visibility) or 0) ~= 0
end

local function TattooRemove(name)
    if not info[name] then return end
    info[name].visibility = 0
    TattooApply()
end

local function TattooRemoveAll()
    for name in pairs(info) do
        if not TattooExcluded(name) then info[name].visibility = 0 end
    end
    TattooApply()
end

-- which menu a per-layer screen should go BACK to
TattooParentMenu = 'TattooOpenMenu'

-- one row per layer, marked so a player can see at a glance what they have on
local function TattooLayerRows(elements, onlyMakeup)
    for _, overlayName in ipairs(getSortedOverlayNames(onlyMakeup)) do
        local on = TattooIsOn(overlayName)
        table.insert(elements, {
            label = (on and "* " or "") .. TattooLabel(overlayName),
            value = 'select',
            desc  = overlayName,
        })
    end
end

function TattooOpenMenu()
	if not TattooEnsureMenuData() then return end
	TattooMenuData.CloseAll()
    TattooCurrentMenu = 'TattooOpenMenu'
    TattooParentMenu = 'TattooOpenMenu'
	local elements = {
        {label = ("Save ($%s)"):format(TattooConfig.Prices.layers or 0), value = 'save' , desc = ("Save current layers for $%s"):format(TattooConfig.Prices.layers or 0)},
	}

    -- Makeup gets its own row rather than four more entries in the flat list
    if #(TattooConfig.Layers.makeup or {}) > 0 then
        table.insert(elements, {label = "Makeup", value = 'makeup', desc = "Lipstick, blush, eyeliner, shadow"})
    end

    table.insert(elements, {label = "Remove Everything", value = 'removeall', desc = "Take off every layer. Save afterwards to keep it"})

    if not mirrorobject then
        table.insert(elements, {label = "Body Adjustments", value = 'expressions', desc = "Adjust body shape"})
    end

    TattooLayerRows(elements, false)

   TattooMenuData.Open('default', GetCurrentResourceName(), 'menuapi',
	{
		title    = 'Menu',
		subtext    = '* = currently on',
		align    = 'top-left',
		elements = elements,
	},
	function(data, menu)
        if(data.current.value == 'save') then
            TattooConfirmReturn = 'TattooOpenMenu'
            TattooOpenConfirmMenu()
            return
		end
        if(data.current.value == 'makeup') then
            TattooOpenMakeupMenu()
            return
        end
        if(data.current.value == 'removeall') then
            TattooRemoveAll()
            TattooOpenMenu()   -- rebuild so every * disappears
            return
        end
        if(data.current.value == 'expressions') then
            TriggerEvent("pup-misc:overlay:openExpressionMenu", "TattooOpenMenu")
            return
        end
		if(data.current.value == 'select') then
            namex = data.current.desc
            TattooParentMenu = 'TattooOpenMenu'
			TattooOpenMenu2()
		end

	end,
	function(data, menu)
		menu.close()
	end)
end

-- the makeup layers, on their own screen
function TattooOpenMakeupMenu()
    if not TattooEnsureMenuData() then return end
    TattooMenuData.CloseAll()
    TattooCurrentMenu = 'TattooOpenMakeupMenu'

    -- Save is offered here as well as on the top level
    local elements = {
        {label = ("Save ($%s)"):format(TattooConfig.Prices.layers or 0), value = 'save', desc = ("Save everything for $%s"):format(TattooConfig.Prices.layers or 0)},
        {label = "Remove All Makeup", value = 'removemakeup', desc = "Take off lipstick, blush, eyeliner and shadow"},
    }
    TattooLayerRows(elements, true)

    TattooMenuData.Open('default', GetCurrentResourceName(), 'menuapi',
    {
        title    = 'Makeup',
        subtext  = '* = on. Save before closing',
        align    = 'top-left',
        elements = elements,
        lastmenu = "TattooOpenMenu",
    },
    function(data, menu)
        if data.current == "backup" then
            _G[data.trigger]()
            return
        end
        if(data.current.value == 'save') then
            TattooConfirmReturn = 'TattooOpenMakeupMenu'
            TattooOpenConfirmMenu()
            return
        end
        if(data.current.value == 'removemakeup') then
            for _, n in ipairs(TattooConfig.Layers.makeup or {}) do TattooRemove(n) end
            TattooOpenMakeupMenu()
            return
        end
        if(data.current.value == 'select') then
            namex = data.current.desc
            TattooParentMenu = 'TattooOpenMakeupMenu'
            TattooOpenMenu2()
        end
    end,
    function(data, menu)
        menu.close()
    end)
end

function TattooOpenMenu2()
    if not TattooEnsureMenuData() then return end
    TattooMenuData.CloseAll()
    TattooCurrentMenu = 'TattooOpenMenu2'

    -- the layer list is built from overlays_info (the static catalogue), but the values come from `info`
    if info[namex] == nil then
        info[namex] = { visibility = 0, tx_id = 1, var = 0, tx_color_type = 0, opacity = 1.0,
            palette_id = 1, palette_color_primary = 0, palette_color_secondary = 0,
            palette_color_tertiary = 0 }
    end
    -- Remove sits FIRST and only appears when the layer is actually on
	local elements = {}
    if TattooIsOn(namex) then
        table.insert(elements, {label = "Remove", value = 'remove', desc = "Take this off. Save afterwards to keep it off"})
    end
    -- Save on this screen too, so nothing has to be remembered on the way out
    table.insert(elements, {label = ("Save ($%s)"):format(TattooConfig.Prices.layers or 0), value = 'save', desc = ("Save everything for $%s"):format(TattooConfig.Prices.layers or 0)})

    -- labels are the player-facing words
    table.insert(elements, {label = "Style",tag = "texture", value = info[namex].tx_id  ,desc = "0 takes it off" , type = "slider" , min =0 , max =TattooKeysx(overlays_info[namex]), hop= 1})
    table.insert(elements, {label = "Colour Set",tag = "palette", value = info[namex].palette_id  ,desc = "Which range the colours below come from" , type = "slider" , min =0 , max =25, hop= 1})
    table.insert(elements, {label = "Strength",tag = "opacity", value = info[namex].opacity  ,desc = "How strong it sits on the skin" , type = "slider" , min =0.0 , max =1.0, hop= 0.1})
    table.insert(elements, {label = "Colour 1",tag = "prim", value = info[namex].palette_color_primary  ,desc = "Main colour" , type = "slider" , min =0 , max =254, hop= 1})
    table.insert(elements, {label = "Colour 2",tag = "sec", value = info[namex].palette_color_secondary  ,desc = "Second colour" , type = "slider" , min =0 , max =254, hop= 1})
    table.insert(elements, {label = "Colour 3",tag = "ter", value = info[namex].palette_color_tertiary  ,desc = "Third colour" , type = "slider" , min =0 , max =254, hop= 1})
    if namex == "eyeliners" then
        table.insert( elements,
        {label = "Style",tag = "style", value = info[namex].var  ,desc = "Enter to TattooApply" , type = "slider" , min =0 , max =15, hop= 1}
        )
    elseif namex == "shadows" then 
        table.insert( elements,
        {label = "Style",tag = "style", value = info[namex].var  ,desc = "Enter to TattooApply" , type = "slider" , min =0 , max =5, hop= 1}
        )
    elseif namex == "lipsticks" then 
        table.insert( elements,
        {label = "Style",tag = "style", value = info[namex].var  ,desc = "Enter to TattooApply" , type = "slider" , min =0 , max =7, hop= 1}
        )
    end
   TattooMenuData.Open('default', GetCurrentResourceName(), 'menuapi',
	{
		title    = TattooLabel(namex),
		subtext    = TattooIsOn(namex) and 'On' or 'Off',
		align    = 'top-left',
		elements = elements,
        -- back goes to whichever screen opened this one, so a makeup layer returns to Makeup instead of dumping you on the top
        lastmenu = TattooParentMenu or "TattooOpenMenu",

	},
	function(data, menu)
        if data.current == "backup" then
            _G[data.trigger]()
            return
        end
        if(data.current.value == 'remove') then
            TattooRemove(namex)
            -- back to the list, which now shows it without its *
            _G[TattooParentMenu or 'TattooOpenMenu']()
            return
        end
        if(data.current.value == 'save') then
            TattooConfirmReturn = TattooParentMenu or 'TattooOpenMenu'
            TattooOpenConfirmMenu()
            return
        end
        if(data.current.tag == 'style') then
            local pick = data.current.value
            varx = pick
            info[namex].var = varx
            info[namex].visibility = 1
            TattooApply()
		end
        
        if(data.current.tag == 'ter') then
            local pick = data.current.value
            palette_color_tertiaryx = pick
            info[namex].palette_color_tertiary = palette_color_tertiaryx
            info[namex].visibility = 1
            TattooApply()
		end
        if(data.current.tag == 'sec') then
            local pick = data.current.value
            palette_color_secondaryx = pick
            info[namex].palette_color_secondary = palette_color_secondaryx
            info[namex].visibility = 1
            TattooApply()
		end
        if(data.current.tag == 'prim') then
            local pick = data.current.value
            palette_color_primaryx = pick
            info[namex].palette_color_primary = palette_color_primaryx
            info[namex].visibility = 1
            TattooApply()
		end
        if(data.current.tag == 'opacity') then
            local pick = data.current.value
            if pick == 0 then 
                info[namex].visibility = 0
                TattooApply()
            else
                opacityx = pick
                info[namex].opacity = opacityx + 0.0
                info[namex].visibility = 1
                TattooApply()
            end
		end
        if(data.current.tag == 'palette') then
            local pick = data.current.value
            if pick == 0 then 
                info[namex].visibility = 0
                TattooApply()
            else
                palette_idx = pick
                info[namex].palette_id = palette_idx
                info[namex].visibility = 1
                TattooApply()
            end
		end
        if(data.current.tag == 'texture') then
            local pick = data.current.value
            if pick == 0 then 
                info[namex].visibility = 0
                TattooApply()
            else
                tx_idx = pick
                info[namex].tx_id = tx_idx
                info[namex].visibility = 1
                TattooApply()
            end
		end
	end,
	function(data, menu)
		menu.close()
	end)
end

local DEFAULT_ZOOM = 2.0
local DEFAULT_OFFSET = -0.15
local c_zoom = DEFAULT_ZOOM
local c_offset = DEFAULT_OFFSET

local function clamp(val, min, max)
    if val < min then
        return min
    elseif val > max then
        return max
    end
    return val
end

local function resetCameraView(ped)
    c_zoom = DEFAULT_ZOOM
    c_offset = DEFAULT_OFFSET
    TattooCamera(c_zoom, c_offset, ped)
end

local function adjustZoom(delta)
    c_zoom = clamp(c_zoom + delta, 0.5, 4.0)
    TattooCamera(c_zoom, c_offset)
end

local function adjustOffset(delta)
    c_offset = clamp(c_offset + delta, -1.5, 1.5)
    TattooCamera(c_zoom, c_offset)
end

Citizen.CreateThread(function()
	Citizen.Wait(500)
	for k,v in pairs(TattooConfig.Shops.locations) do 
        if v.showBlip then 
		local blip = N_0x554d9d53f696d002(1664425300, v.coords)
		SetBlipSprite(blip, TattooConfig.Shops.blip.sprite, 1)
		SetBlipScale(blip, TattooConfig.Shops.blip.scale)
		Citizen.InvokeNative(0x9CB1A1623062F402, blip, TattooLocale.blipName)
		table.insert( blips, blip )
        end
	end

    local str = TattooLocale.openMenu
	TattooOpenMenuPrompt = PromptRegisterBegin()
	PromptSetControlAction(TattooOpenMenuPrompt, TattooConfig.Keys.openMenu)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(TattooOpenMenuPrompt, str)
	PromptSetEnabled(TattooOpenMenuPrompt, 1)
	PromptSetVisible(TattooOpenMenuPrompt, 1)
	PromptSetStandardMode(TattooOpenMenuPrompt,1)
	PromptSetGroup(TattooOpenMenuPrompt, prompts)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,TattooOpenMenuPrompt,true)
	PromptRegisterEnd(TattooOpenMenuPrompt)

    local str = TattooLocale.resetCamera
	resetcam = PromptRegisterBegin()
	PromptSetControlAction(resetcam, TattooConfig.Keys.resetCamera)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(resetcam, str)
	PromptSetEnabled(resetcam, 1)
	PromptSetVisible(resetcam, 1)
	PromptSetStandardMode(resetcam,1)
	PromptSetGroup(resetcam, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,resetcam,true)
	PromptRegisterEnd(resetcam)

    local str = TattooLocale.moveUp
	movecameraup = PromptRegisterBegin()
	PromptSetControlAction(movecameraup, TattooConfig.Keys.cameraUp)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(movecameraup, str)
	PromptSetEnabled(movecameraup, 1)
	PromptSetVisible(movecameraup, 1)
	PromptSetStandardMode(movecameraup,1)
	PromptSetGroup(movecameraup, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,movecameraup,true)
	PromptRegisterEnd(movecameraup)

    local str = TattooLocale.moveDown
	movecameradown = PromptRegisterBegin()
	PromptSetControlAction(movecameradown, TattooConfig.Keys.cameraDown)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(movecameradown, str)
	PromptSetEnabled(movecameradown, 1)
	PromptSetVisible(movecameradown, 1)
	PromptSetStandardMode(movecameradown,1)
	PromptSetGroup(movecameradown, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,movecameradown,true)
	PromptRegisterEnd(movecameradown)

    local str = TattooLocale.zoomIn
	zoomin = PromptRegisterBegin()
	PromptSetControlAction(zoomin, TattooConfig.Keys.zoomIn)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(zoomin, str)
	PromptSetEnabled(zoomin, 1)
	PromptSetVisible(zoomin, 1)
	PromptSetStandardMode(zoomin,1)
	PromptSetGroup(zoomin, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,zoomin,true)
	PromptRegisterEnd(zoomin)

    local str = TattooLocale.zoomOut
	zoomout = PromptRegisterBegin()
	PromptSetControlAction(zoomout, TattooConfig.Keys.zoomOut)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(zoomout, str)
	PromptSetEnabled(zoomout, 1)
	PromptSetVisible(zoomout, 1)
	PromptSetStandardMode(zoomout,1)
	PromptSetGroup(zoomout, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,zoomout,true)
	PromptRegisterEnd(zoomout)

    local str = TattooLocale.rotateLeft
	rotate1 = PromptRegisterBegin()
	PromptSetControlAction(rotate1, TattooConfig.Keys.rotateLeft)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(rotate1, str)
	PromptSetEnabled(rotate1, 1)
	PromptSetVisible(rotate1, 1)
	PromptSetStandardMode(rotate1,1)
	PromptSetGroup(rotate1, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,rotate1,true)
	PromptRegisterEnd(rotate1)

    local str = TattooLocale.rotateRight
	rotate2 = PromptRegisterBegin()
	PromptSetControlAction(rotate2, TattooConfig.Keys.rotateRight)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(rotate2, str)
	PromptSetEnabled(rotate2, 1)
	PromptSetVisible(rotate2, 1)
	PromptSetStandardMode(rotate2,1)
	PromptSetGroup(rotate2, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,rotate2,true)
	PromptRegisterEnd(rotate2)

    local str = TattooLocale.back
	backspacebutton = PromptRegisterBegin()
	PromptSetControlAction(backspacebutton, TattooConfig.Keys.back)
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(backspacebutton, str)
	PromptSetEnabled(backspacebutton, 1)
	PromptSetVisible(backspacebutton, 1)
	PromptSetStandardMode(backspacebutton,1)
	PromptSetGroup(backspacebutton, prompts2)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,backspacebutton,true)
	PromptRegisterEnd(backspacebutton)
end)

function TattooDestroy()
    -- the mirror path opens the page without this camera, so it can be nil
    if cam then SetCamActive(cam, false) end
    RenderScriptCams(false, true, 500, true, true)
    DisplayHud(true)
    DisplayRadar(true)
    DestroyAllCams(true)
    cam = nil
end

function TattooCamera(zoom, offset, ped)
    DestroyAllCams(true)
    ped = ped or PlayerPedId()
    local coords    = GetEntityCoords(ped)
    local heading = 45.0
    local zoomOffset = zoom
    local camOffset = offset
    local angle = heading * math.pi / 180.0
    local theta = {
        x = math.cos(angle),
        y = math.sin(angle)
    }
    local pos = {
        x = coords.x + (zoomOffset * theta.x),
        y = coords.y + (zoomOffset * theta.y)
    }
    local angleToLook = heading - 140.0
    if angleToLook > 360 then
        angleToLook = angleToLook - 360
    elseif angleToLook < 0 then
        angleToLook = angleToLook + 360
    end
    angleToLook = angleToLook * math.pi / 180.0
    local thetaToLook = {
        x = math.cos(angleToLook),
        y = math.sin(angleToLook)
    }
    local posToLook = {
        x = coords.x + (zoomOffset * thetaToLook.x),
        y = coords.y + (zoomOffset * thetaToLook.y)
    }
    local add = (1.3*zoom)
    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, coords.z + camOffset, 300.00,0.00,0.00, 40.00, false, 0)
    PointCamAtCoord(cam, posToLook.x-add, posToLook.y, coords.z + camOffset)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
    DisplayHud(false)
    DisplayRadar(false)
end

function TattooExistAndReset()
    FreezeEntityPosition(PlayerPedId(), false)
    camx = false 
    TattooDestroy()
    TriggerEvent("pup-misc:overlay:overlayMenuClosed")
end

AddEventHandler('menuapi:closemenu', function()
    if TattooInMenu then 
	    FreezeEntityPosition(PlayerPedId(), false)
        camx = false 
        TattooDestroy() 
        TattooInMenu = false 
        if mirrorobject then 
            ClearPedTasks(PlayerPedId())
            DeleteEntity(mirrorobject)
            mirrorobject = nil
        end
        -- Let expression.lua know the overlay session ended without a save
        TriggerEvent("pup-misc:overlay:overlayMenuClosed")
    end
end)

-- Thread to handle TattooCamera controls and UI prompts while in the overlay menu
Citizen.CreateThread(function()
    while true do
        -- Performance optimization: 5ms when active, 1000ms when idle
        local waitTime = 1000
        if camx then
            waitTime = 5
        end
        Citizen.Wait(waitTime)

        if camx then 
            local myPed = PlayerPedId()
            local pHead = GetEntityHeading(myPed)
            local coords = GetEntityCoords(myPed)
            -- Dynamic instruction label
            local label  = CreateVarString(10, 'LITERAL_STRING', TattooLocale.cameraGroup)
            -- Add local lighting for better visibility during editing
            DrawLightWithRange(coords.x+1 , coords.y+1 , coords.z + 1, 255, 255, 255, 2.5 ,10.0)
			-- Show the control prompt group
			PromptSetActiveGroupThisFrame(prompts2, label)
			
			-- Handle various TattooCamera and interaction prompts
			if Citizen.InvokeNative(0xC92AC953F0A982AE,TattooOpenMenuPrompt2) then
                FreezeEntityPosition(PlayerPedId(), true)
                resetCameraView()
                camx = true
                TattooLocationTrigger()
            end
            if Citizen.InvokeNative(0xC92AC953F0A982AE,resetcam) then
                resetCameraView()
            end
            if Citizen.InvokeNative(0xC92AC953F0A982AE,movecameraup) then
                adjustOffset(0.2)
            end
            if Citizen.InvokeNative(0xC92AC953F0A982AE,movecameradown) then
                adjustOffset(-0.2)
            end
            if Citizen.InvokeNative(0xC92AC953F0A982AE,zoomin) then
                adjustZoom(-0.2)
            end
            if Citizen.InvokeNative(0xC92AC953F0A982AE,zoomout) then
                adjustZoom(0.2)
            end
            -- Ped rotation controls
            if Citizen.InvokeNative(0xC92AC953F0A982AE,rotate1) then
                SetEntityHeading(myPed, (GetEntityHeading(myPed) - 20) % 360)
            end
            if Citizen.InvokeNative(0xC92AC953F0A982AE,rotate2) then
                SetEntityHeading(myPed, (GetEntityHeading(myPed) + 20) % 360)
            end
        end
    end
end)

-- Thread to handle proximity checks for shop locations
Citizen.CreateThread(function()
    while true do
        -- 5ms check when nearby, 1000ms otherwise
        local waitTime = 1000
	  	local coords = GetEntityCoords(PlayerPedId())
	  	local sleep = true 
        
        -- Loop through defined zones in config
	  	for k, v in pairs(TattooConfig.Shops.locations) do
			if #(coords - v.coords) < TattooConfig.Shops.radius and not camx and not TattooInMenu then
			  	sleep = false
			  	local label  = CreateVarString(10, 'LITERAL_STRING', TattooLocale.shopPrompt)
			  	PromptSetActiveGroupThisFrame(prompts, label)
                -- Trigger menu entry
			  	if Citizen.InvokeNative(0xC92AC953F0A982AE,TattooOpenMenuPrompt) then
                    FreezeEntityPosition(PlayerPedId(), true)
                    resetCameraView()
                    camx = true
					TattooLocationTrigger()
			  	end
                break -- Exit loop early if found
			end
		end

		if not sleep then 
			waitTime = 5
		end
        Citizen.Wait(waitTime)
	end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName == GetCurrentResourceName() then
		for k,v in pairs(blips) do 
            RemoveBlip(v)
        end
    end
end)

RegisterNetEvent('pup-misc:overlay:usedmirror')
AddEventHandler('pup-misc:overlay:usedmirror', function(object)
    mirrorobject = object
    FreezeEntityPosition(PlayerPedId(), true)
    TattooLocationTrigger()
end)
TattooOpenConfirmMenu = function()
    if not TattooEnsureMenuData() then return end
    TattooMenuData.CloseAll()
    local elements = {
        {label = "Yes - Save", value = 'yes', desc = "Apply and save all overlays"},
        {label = "No", value = 'no', desc = "Return to overlay menu"},
    }

    TattooMenuData.Open('default', GetCurrentResourceName(), 'overlay_confirm',
    {
        title    = 'Confirm',
        subtext    = 'Apply selected overlays?',
        align    = 'top-left',
        elements = elements,
        -- back / "No" returns to the screen Save was pressed on
        lastmenu = TattooConfirmReturn or "TattooOpenMenu",
    },
    function(data, menu)
        if data.current == "backup" then
            if data.trigger and _G[data.trigger] then
                _G[data.trigger]()
            end
            return
        end

        if data.current.value == 'yes' then
            TattooApplyAndSave()
            TattooExistAndReset()
        elseif data.current.value == 'no' then
            if data.trigger and _G[data.trigger] then
                _G[data.trigger]()
            end
        end
    end,
    function(data, menu)
        menu.close()
    end)
end
