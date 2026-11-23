-- pup_postoffice | database install
-- Safe to run more than once: every statement is CREATE TABLE IF NOT EXISTS.
-- PO box numbers start at 1000 on a fresh `mail` table.
-- This resource adds no inventory items, so there is nothing to INSERT IGNORE into `items`.

CREATE TABLE IF NOT EXISTS `mail` (
    `address` int(11) NOT NULL AUTO_INCREMENT,
    `charidentifier` int(11) DEFAULT NULL,
    PRIMARY KEY (`address`)
) ENGINE=InnoDB AUTO_INCREMENT=1000 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mails` (
    `id` int(255) NOT NULL AUTO_INCREMENT,
    `anon` tinyint(1) DEFAULT NULL,
    `read` tinyint(1) DEFAULT NULL,
    `from` longtext DEFAULT NULL,
    `to` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    `subject` longtext DEFAULT NULL,
    `body` longtext DEFAULT NULL,
    `folder` longtext DEFAULT NULL,
    `fromName` longtext DEFAULT NULL,
    `toNames` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    `date` longtext DEFAULT NULL,
    `hidesent` tinyint(4) DEFAULT 0,
    `copyTo` varchar(255) DEFAULT NULL,
    `copyToJob` varchar(50) DEFAULT NULL,
    `fromJob` varchar(50) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `copyToJob` (`copyToJob`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mail_addressbook` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `address` int(11) DEFAULT NULL,
    `name` varchar(255) DEFAULT NULL,
    `poBox` varchar(255) DEFAULT NULL,
    `notes` text DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `address` (`address`),
    CONSTRAINT `mail_addressbook_ibfk_1` FOREIGN KEY (`address`) REFERENCES `mail` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mail_editableFolders` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `address` int(11) DEFAULT NULL,
    `folderName` varchar(255) DEFAULT NULL,
    `job` varchar(50) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `address` (`address`),
    CONSTRAINT `mail_editablefolders_ibfk_1` FOREIGN KEY (`address`) REFERENCES `mail` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mail_business` (
    `job` varchar(50) NOT NULL,
    `handle` varchar(32) NOT NULL,
    PRIMARY KEY (`job`),
    UNIQUE KEY `handle` (`handle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- chats: kind 'group' (owner tools), 'direct' (two boxes) or 'business' (a customer box and the job in `ref`)
CREATE TABLE IF NOT EXISTS `mail_groups` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `title` varchar(64) NOT NULL,
    `owner` int(11) DEFAULT NULL,
    `kind` varchar(16) NOT NULL DEFAULT 'group',
    `ref` varchar(50) DEFAULT NULL,
    `handled` tinyint(1) NOT NULL DEFAULT 0,
    `bizRead` int(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `owner` (`owner`),
    KEY `kindRef` (`kind`, `ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mail_group_members` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `groupId` int(11) NOT NULL,
    `address` int(11) NOT NULL,
    `notify` tinyint(1) NOT NULL DEFAULT 1,
    `lastRead` int(11) NOT NULL DEFAULT 0,
    `pinned` tinyint(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `groupMember` (`groupId`, `address`),
    KEY `memberAddress` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- asJob: the business an employee wrote for (NULL = written as their own box)
-- parentId: the top-level message a thread reply belongs to (NULL = a message in the main chat)
CREATE TABLE IF NOT EXISTS `mail_group_messages` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `groupId` int(11) NOT NULL,
    `address` int(11) NOT NULL,
    `body` longtext DEFAULT NULL,
    `date` varchar(32) DEFAULT NULL,
    `asJob` varchar(50) DEFAULT NULL,
    `parentId` int(11) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `groupThread` (`groupId`, `id`),
    KEY `groupParent` (`groupId`, `parentId`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- emoji reactions on chat messages; who = 'p<box>' or 'b:<job>' (a reaction made for a business)
CREATE TABLE IF NOT EXISTS `mail_group_reactions` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `messageId` int(11) NOT NULL,
    `who` varchar(60) NOT NULL,
    `address` int(11) NOT NULL,
    `emoji` varchar(32) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `reaction` (`messageId`, `who`, `emoji`),
    KEY `reactAddress` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- boxes a business blocked: they cannot write to that business's chat (blockedBy = the employee's box)
CREATE TABLE IF NOT EXISTS `mail_business_blocks` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `job` varchar(50) NOT NULL,
    `address` int(11) NOT NULL,
    `blockedBy` int(11) DEFAULT NULL,
    `date` varchar(32) DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `jobAddress` (`job`, `address`),
    KEY `bizBlockAddress` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- boxes a player blocked: their messages are hidden from that player
CREATE TABLE IF NOT EXISTS `mail_blocks` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `address` int(11) NOT NULL,
    `blocked` int(11) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `pair` (`address`, `blocked`),
    KEY `blocked` (`blocked`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
