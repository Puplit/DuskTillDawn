-- pup_postoffice | settings shared by the server, the client and the mail page (see README)

Config = {}

Config.DevResign = false

Config.Command = 'mail'

Config.Branding = {
    title     = 'Dusk Till Dawn Mail',
    motto     = 'Rain or shine, through sun or snow, The mailman comes, and letters go',
    logo      = '', -- '' = a drawn seal and no watermark
    seal      = true,
    ornaments = true,
    watermark = true,
    paper     = 'parchment', -- parchment | stationery | ruled | plain | crumpled | telegram | ledger
    telegramHeader = 'TELEGRAPH OFFICE',
}

Config.InteractKey = 0x760A9C6F -- G

Config.LocationOnly = false

-- metres
Config.ServerReach       = 10.0
Config.ClientReach       = 1.5
Config.MenuCloseDistance = 4.0

Config.PassWhenNoPosition = true

Config.MailboxProps = {
    enabled = false,
    model   = 'p_mailbox01x',
}

Config.BoxPrice           = 10    -- cash
Config.BusinessChangeCost = 25000 -- from the business ledger

Config.Letters = {
    showSenderName = false,
    maxRecipients  = 20,
    maxSubject     = 150,   -- bytes
    maxBody        = 20000, -- bytes
    cooldown       = 5,     -- seconds
    refuseIfAnyInvalid = false,
    businessByChat = true,  -- true: nobody can write a letter TO a business; customers use the business chat
}

Config.Mailbox = {
    maxContacts  = 500,
    maxFolders   = 30,
    contactName  = 100,  -- bytes
    contactNotes = 2000, -- bytes
}

-- chats (direct, group and business conversations)
Config.Chat = {
    maxMessage      = 500, -- bytes
    pageSize        = 30,  -- messages fetched at a time
    maxGroupMembers = 20,
    maxOwnedGroups  = 5,
    cooldownMs      = 800, -- between two messages from one player
    listLimit       = 150, -- most recent chats sent to the page
    -- anti-spam (checked on the server)
    minLength       = 2,   -- characters; shorter messages are refused
    repeatSeconds   = 30,  -- the same text twice in a row inside this window is refused
    burstCount      = 6,   -- more than this many messages...
    burstSeconds    = 15,  -- ...inside this window...
    muteSeconds     = 20,  -- ...mutes the player's chats for this long
    -- the reactions a player can put on a chat message (the server refuses anything else; at most 12)
    reactions       = { '👍', '❤️', '😂', '😮', '😢', '🤠', '🔥', '👎' },
}

-- characters
Config.PageLimits = {
    subject      = 120,
    contactName  = 48,
    contactBox   = 24,
    contactNotes = 500,
    folderName   = 32,
    groupTitle   = 40,
    groupMessage = 500,
}

Config.Blip = {
    style  = 1664425300,
    sprite = 2119977580,
    scale  = 0.2,
    name   = 'Mail Office',
}

Config.Offices = {
    { name = 'Valentine',   coords = vector3(-183.68, 624.6, 114.089),                              blip = true },
    { name = 'Rhodes',      coords = vector3(1223.29, -1292.9, 76.9),                               blip = true },
    { name = 'Saint Denis', coords = vector3(2731.3, -1402.4, 46.2),                                blip = true },
    { name = 'Tumbleweed',  coords = vector3(-5529.9033203125, -2956.2438964844, -0.74007713794708), blip = false },
    { name = 'Armadillo',   coords = vector3(-3648.1, -2549.33, -12.83),                            blip = true },
    { name = 'Annesburg',   coords = vector3(2940.11, 1291.12, 44.5),                               blip = true },
    { name = 'Blackwater',  coords = vector3(-733.13, -1226.05, 44.78),                             blip = true },
}

Config.Pose = {
    letterProp = 'p_letter01x',
    penProp    = 'p_pen01x',
    letterBone = 'SKEL_L_Hand',
    penBone    = 'SKEL_R_Hand',
    letterOffset = { 0.10, 0.02, -0.03, -80.0, 0.0, 10.0 }, -- x, y, z, rotX, rotY, rotZ
    penOffset    = { 0.08, 0.01, -0.02, 0.0, 0.0, 0.0 },
    animDict   = 'amb_work@world_human_write_notebook@female_a@idle_a',
    animName   = 'idle_a',
    animFlag   = 1,
}

-- ms
Config.SendOff = {
    scenario    = 'WORLD_HUMAN_CROUCH_INSPECT',
    pigeonModel = 'a_c_pigeon',
    kneelMs     = 3500,
    pigeonAtMs  = 2500,
    pigeonLifeMs = 30000,
}
