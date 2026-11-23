-- pup_postoffice | brings an older database up to date on start, then loads the business directory

local function try(sql, params)
    local ok, err = pcall(MySQL.query.await, sql, params or {})
    if not ok then print(('[pup_postoffice] schema step skipped: %s'):format(tostring(err))) end
    return ok
end

local function columnExists(tbl, col)
    local ok, n = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tbl, col })
    return ok and (tonumber(n) or 0) > 0
end

local function indexExists(tbl, idx)
    local ok, n = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?',
        { tbl, idx })
    return ok and (tonumber(n) or 0) > 0
end

local function tableCollation(tbl)
    local ok, c = pcall(MySQL.scalar.await,
        'SELECT TABLE_COLLATION FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { tbl })
    return ok and c or nil
end

local function columnCharset(tbl, col)
    local ok, c = pcall(MySQL.scalar.await,
        'SELECT CHARACTER_SET_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tbl, col })
    return ok and c or nil
end

--- Emoji need 4-byte utf8mb4; older databases made these tables as 3-byte utf8. Converting keeps every value.
local function emojiReady()
    for _, tbl in ipairs({ 'mail', 'mail_addressbook', 'mail_business', 'mail_editableFolders',
                           'mail_groups', 'mail_group_members', 'mail_group_messages' }) do
        local c = tableCollation(tbl)
        if c and not tostring(c):find('^utf8mb4') then
            if try(('ALTER TABLE `%s` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci'):format(tbl)) then
                print(('[pup_postoffice] %s now stores emoji (utf8mb4)'):format(tbl))
            end
        end
    end
    -- letters: only the plain text columns. `to` / `toNames` are already utf8mb4_bin and stay exactly as they are,
    -- so resources that write letters straight into `mails` (housing tax, the fence) keep working.
    local cols = {
        { 'from', 'longtext DEFAULT NULL' }, { 'subject', 'longtext DEFAULT NULL' }, { 'body', 'longtext DEFAULT NULL' },
        { 'folder', 'longtext DEFAULT NULL' }, { 'fromName', 'longtext DEFAULT NULL' }, { 'date', 'longtext DEFAULT NULL' },
    }
    local parts = {}
    for _, c in ipairs(cols) do
        local cs = columnCharset('mails', c[1])
        if cs and cs ~= 'utf8mb4' then
            local def = c[2]:gsub('^longtext', 'longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci')
            parts[#parts + 1] = ('MODIFY `%s` %s'):format(c[1], def)
        end
    end
    if #parts > 0 and try('ALTER TABLE `mails` ' .. table.concat(parts, ', ')) then
        try('ALTER TABLE `mails` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci')
        print('[pup_postoffice] letters now store emoji (utf8mb4)')
    end
end

local function addColumn(tbl, col, definition)
    if not columnExists(tbl, col) then
        try(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tbl, col, definition))
    end
end

local function upgrade()
    try([[CREATE TABLE IF NOT EXISTS `mail_business` (
        `job` varchar(50) NOT NULL,
        `handle` varchar(32) NOT NULL,
        PRIMARY KEY (`job`),
        UNIQUE KEY `handle` (`handle`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    addColumn('mails', 'copyToJob', 'varchar(50) NULL DEFAULT NULL')
    addColumn('mails', 'fromJob', 'varchar(50) NULL DEFAULT NULL')
    if not indexExists('mails', 'copyToJob') then
        try('ALTER TABLE `mails` ADD INDEX `copyToJob` (`copyToJob`)')
    end
    addColumn('mail_editableFolders', 'job', 'varchar(50) NULL DEFAULT NULL')

    try([[CREATE TABLE IF NOT EXISTS `mail_groups` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `title` varchar(64) NOT NULL,
        `owner` int(11) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `owner` (`owner`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    try([[CREATE TABLE IF NOT EXISTS `mail_group_members` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `groupId` int(11) NOT NULL,
        `address` int(11) NOT NULL,
        `notify` tinyint(1) NOT NULL DEFAULT 1,
        `lastRead` int(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        UNIQUE KEY `groupMember` (`groupId`, `address`),
        KEY `memberAddress` (`address`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    try([[CREATE TABLE IF NOT EXISTS `mail_group_messages` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `groupId` int(11) NOT NULL,
        `address` int(11) NOT NULL,
        `body` longtext DEFAULT NULL,
        `date` varchar(32) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `groupThread` (`groupId`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    -- columns no longer used by groups
    for _, col in ipairs({ 'status', 'invitedBy' }) do
        if columnExists('mail_group_members', col) then
            try(('ALTER TABLE `mail_group_members` DROP COLUMN `%s`'):format(col))
        end
    end

    -- chats: the group tables carry every conversation; existing groups keep kind 'group'
    addColumn('mail_groups', 'kind', "varchar(16) NOT NULL DEFAULT 'group'")
    addColumn('mail_groups', 'ref', 'varchar(50) NULL DEFAULT NULL')
    addColumn('mail_groups', 'handled', 'tinyint(1) NOT NULL DEFAULT 0')
    addColumn('mail_groups', 'bizRead', 'int(11) NOT NULL DEFAULT 0')
    if not indexExists('mail_groups', 'kindRef') then
        try('ALTER TABLE `mail_groups` ADD INDEX `kindRef` (`kind`, `ref`)')
    end
    addColumn('mail_group_members', 'pinned', 'tinyint(1) NOT NULL DEFAULT 0')
    addColumn('mail_group_messages', 'asJob', 'varchar(50) NULL DEFAULT NULL')

    try([[CREATE TABLE IF NOT EXISTS `mail_blocks` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `address` int(11) NOT NULL,
        `blocked` int(11) NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `pair` (`address`, `blocked`),
        KEY `blocked` (`blocked`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    -- reply threads: a reply points at a top-level message of the same chat
    addColumn('mail_group_messages', 'parentId', 'int(11) NULL DEFAULT NULL')
    if not indexExists('mail_group_messages', 'groupParent') then
        try('ALTER TABLE `mail_group_messages` ADD INDEX `groupParent` (`groupId`, `parentId`, `id`)')
    end
    -- reactions: who is 'p<box>' or 'b:<job>'; utf8mb4_bin so two different emojis never count as the same key
    try([[CREATE TABLE IF NOT EXISTS `mail_group_reactions` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `messageId` int(11) NOT NULL,
        `who` varchar(60) NOT NULL,
        `address` int(11) NOT NULL,
        `emoji` varchar(32) NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `reaction` (`messageId`, `who`, `emoji`),
        KEY `reactAddress` (`address`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])

    -- boxes a business blocked: they cannot write to that business's chat
    try([[CREATE TABLE IF NOT EXISTS `mail_business_blocks` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `job` varchar(50) NOT NULL,
        `address` int(11) NOT NULL,
        `blockedBy` int(11) DEFAULT NULL,
        `date` varchar(32) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `jobAddress` (`job`, `address`),
        KEY `bizBlockAddress` (`address`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])
    PO.bizBlocksReady = columnExists('mail_business_blocks', 'address')

    emojiReady()

    -- chats only run once every column above is really there
    PO.chatReady = columnExists('mail_groups', 'kind') and columnExists('mail_groups', 'bizRead')
        and columnExists('mail_group_members', 'pinned') and columnExists('mail_group_messages', 'asJob')
    if not PO.chatReady then print('[pup_postoffice] chat columns are missing: chats stay off until the database accepts them') end
    -- threads and reactions are extra: chats still work without them
    PO.threadsReady = PO.chatReady and columnExists('mail_group_messages', 'parentId') and columnExists('mail_group_reactions', 'emoji')
    if PO.chatReady and not PO.threadsReady then print('[pup_postoffice] thread/reaction columns are missing: chats run without replies and reactions') end
end

CreateThread(function()
    Wait(1200)
    upgrade()
    PO.loadDirectory()
    if Config.DevResign then
        Wait(500)
        for _, id in ipairs(GetPlayers()) do
            local s = tonumber(id)
            if s and PO.getChar(s) then PO.sendMailbox(s) end
        end
    end
end)
