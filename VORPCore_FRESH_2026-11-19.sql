-- Dusk Till Dawn: fresh database (schema + server content, no player data)
-- Generated 2026-11-19 from the live structure (every column, index, trigger and procedure),
-- with the table names of 2026-11-19 (no pup_ prefix; the 5 [VORP] pup_ tables keep theirs).
-- Import this file as it is: it creates the VORPCore_290045 database (the name server.cfg uses)
-- and fills it. To use another name, change it on the two lines below AND in server.cfg's
-- mysql_connection_string. It holds no DROP TABLE, and the first statement below refuses to run in a
-- database that already has tables, so it can never touch an existing (live) database.

CREATE DATABASE IF NOT EXISTS `VORPCore_290045` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `VORPCore_290045`;

-- GUARD: this database must be empty. If the import stops here with
-- "Subquery returns more than 1 row", you are importing into a database that already has tables
-- (for example your live one). Nothing has been created. Use a new, empty database instead.
SELECT (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() LIMIT 2) AS empty_database_check;

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `armory_defaults`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `armory_defaults` (
  `item` varchar(50) NOT NULL,
  `slot` varchar(10) NOT NULL,
  `x` double NOT NULL DEFAULT 0,
  `y` double NOT NULL DEFAULT 0,
  `z` double NOT NULL DEFAULT 0,
  `rx` double NOT NULL DEFAULT 0,
  `ry` double NOT NULL DEFAULT 0,
  `rz` double NOT NULL DEFAULT 0,
  PRIMARY KEY (`item`,`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `armory_defaults`
--

LOCK TABLES `armory_defaults` WRITE;
/*!40000 ALTER TABLE `armory_defaults` DISABLE KEYS */;
/*!40000 ALTER TABLE `armory_defaults` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `armory_offsets`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `armory_offsets` (
  `charid` int(11) NOT NULL,
  `item` varchar(50) NOT NULL,
  `slot` varchar(10) NOT NULL,
  `x` double NOT NULL DEFAULT 0,
  `y` double NOT NULL DEFAULT 0,
  `z` double NOT NULL DEFAULT 0,
  `rx` double NOT NULL DEFAULT 0,
  `ry` double NOT NULL DEFAULT 0,
  `rz` double NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`,`item`,`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `armory_offsets`
--

LOCK TABLES `armory_offsets` WRITE;
/*!40000 ALTER TABLE `armory_offsets` DISABLE KEYS */;
/*!40000 ALTER TABLE `armory_offsets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bank_activity`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bank_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charidentifier` int(11) NOT NULL,
  `bank` varchar(50) NOT NULL DEFAULT '',
  `ts` int(11) NOT NULL,
  `type` varchar(20) NOT NULL,
  `amount` double NOT NULL,
  `balance_after` double NOT NULL DEFAULT 0,
  `actor` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `char_bank` (`charidentifier`,`bank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bank_activity`
--

LOCK TABLES `bank_activity` WRITE;
/*!40000 ALTER TABLE `bank_activity` DISABLE KEYS */;
/*!40000 ALTER TABLE `bank_activity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bank_statement_clears`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bank_statement_clears` (
  `charidentifier` int(11) NOT NULL,
  `bank` varchar(50) NOT NULL,
  `cleared_at` int(11) NOT NULL,
  PRIMARY KEY (`charidentifier`,`bank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bank_statement_clears`
--

LOCK TABLES `bank_statement_clears` WRITE;
/*!40000 ALTER TABLE `bank_statement_clears` DISABLE KEYS */;
/*!40000 ALTER TABLE `bank_statement_clears` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bank_treasury`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bank_treasury` (
  `id` int(11) NOT NULL DEFAULT 1,
  `balance` decimal(14,2) NOT NULL DEFAULT 0.00,
  `total_tax_in` decimal(14,2) NOT NULL DEFAULT 0.00,
  `total_fees_in` decimal(14,2) NOT NULL DEFAULT 0.00,
  `total_loaned` decimal(14,2) NOT NULL DEFAULT 0.00,
  `total_repaid` decimal(14,2) NOT NULL DEFAULT 0.00,
  `updated_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bank_treasury`
--

LOCK TABLES `bank_treasury` WRITE;
/*!40000 ALTER TABLE `bank_treasury` DISABLE KEYS */;
/*!40000 ALTER TABLE `bank_treasury` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bank_users`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bank_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) NOT NULL,
  `steamname` varchar(255) DEFAULT NULL,
  `charidentifier` int(11) NOT NULL,
  `valentine_money` decimal(10,2) DEFAULT 0.00,
  `blackwater_money` decimal(10,2) DEFAULT 0.00,
  `saintdenis_money` decimal(10,2) DEFAULT 0.00,
  `rhodes_money` decimal(10,2) DEFAULT 0.00,
  `strawberry_money` decimal(10,2) DEFAULT 0.00,
  `armadillo_money` decimal(10,2) DEFAULT 0.00,
  `annesburg_money` decimal(10,2) DEFAULT 0.00,
  `total_money` decimal(10,2) DEFAULT 0.00,
  PRIMARY KEY (`id`),
  UNIQUE KEY `charidentifier` (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bank_users`
--

LOCK TABLES `bank_users` WRITE;
/*!40000 ALTER TABLE `bank_users` DISABLE KEYS */;
/*!40000 ALTER TABLE `bank_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bills`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bills` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` longtext DEFAULT NULL,
  `playername` longtext DEFAULT NULL,
  `identifier` varchar(50) DEFAULT NULL,
  `charidentifier` int(11) DEFAULT NULL,
  `issuer` longtext DEFAULT NULL,
  `amount` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bills`
--

LOCK TABLES `bills` WRITE;
/*!40000 ALTER TABLE `bills` DISABLE KEYS */;
/*!40000 ALTER TABLE `bills` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `birds`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `birds` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(60) NOT NULL,
  `charid` int(5) NOT NULL,
  `model` int(25) NOT NULL,
  `name` varchar(50) NOT NULL,
  `preset` int(2) NOT NULL DEFAULT 0,
  `xp` int(6) NOT NULL DEFAULT 0,
  `price` int(8) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `birds`
--

LOCK TABLES `birds` WRITE;
/*!40000 ALTER TABLE `birds` DISABLE KEYS */;
/*!40000 ALTER TABLE `birds` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `boats`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `boats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(100) NOT NULL DEFAULT '',
  `charidentifier` int(11) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT 'Boat',
  `boat` varchar(64) NOT NULL DEFAULT '',
  `components` longtext DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `charidentifier` (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `boats`
--

LOCK TABLES `boats` WRITE;
/*!40000 ALTER TABLE `boats` DISABLE KEYS */;
/*!40000 ALTER TABLE `boats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `book_royalties`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `book_royalties` (
  `charid` int(11) NOT NULL,
  `cash` float DEFAULT 0,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `book_royalties`
--

LOCK TABLES `book_royalties` WRITE;
/*!40000 ALTER TABLE `book_royalties` DISABLE KEYS */;
/*!40000 ALTER TABLE `book_royalties` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `books`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `books` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(50) NOT NULL,
  `author` longtext NOT NULL,
  `data` longtext NOT NULL,
  `edit` longtext NOT NULL,
  `charid` int(50) NOT NULL DEFAULT 0,
  `item` varchar(50) DEFAULT 'book',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `books`
--

LOCK TABLES `books` WRITE;
/*!40000 ALTER TABLE `books` DISABLE KEYS */;
/*!40000 ALTER TABLE `books` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `books_publishing`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `books_publishing` (
  `id` int(11) NOT NULL,
  `publish` int(11) DEFAULT 0,
  `charid` int(11) DEFAULT NULL,
  `copies` int(11) DEFAULT 0,
  `price` float DEFAULT 0,
  `title` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `books_publishing`
--

LOCK TABLES `books_publishing` WRITE;
/*!40000 ALTER TABLE `books_publishing` DISABLE KEYS */;
/*!40000 ALTER TABLE `books_publishing` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bug_points`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bug_points` (
  `charid` int(11) NOT NULL,
  `points` int(11) NOT NULL DEFAULT 0,
  `earned` int(11) NOT NULL DEFAULT 0 COMMENT 'lifetime awarded, never goes down',
  `spent` int(11) NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bug_points`
--

LOCK TABLES `bug_points` WRITE;
/*!40000 ALTER TABLE `bug_points` DISABLE KEYS */;
/*!40000 ALTER TABLE `bug_points` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `character_inventories`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `character_inventories` (
  `character_id` int(11) DEFAULT NULL,
  `inventory_type` varchar(100) NOT NULL DEFAULT 'default',
  `item_crafted_id` int(11) NOT NULL,
  `item_name` varchar(50) DEFAULT 'item',
  `amount` int(11) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `degradation` int(11) DEFAULT NULL,
  `percentage` int(11) DEFAULT NULL,
  KEY `character_inventory_idx` (`character_id`,`inventory_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `character_inventories`
--

LOCK TABLES `character_inventories` WRITE;
/*!40000 ALTER TABLE `character_inventories` DISABLE KEYS */;
/*!40000 ALTER TABLE `character_inventories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `characters`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `characters` (
  `identifier` varchar(50) NOT NULL DEFAULT '',
  `steamname` varchar(50) NOT NULL DEFAULT '',
  `charidentifier` int(11) NOT NULL AUTO_INCREMENT,
  `group` varchar(10) DEFAULT 'user',
  `money` double(11,2) DEFAULT 0.00,
  `gold` double(11,2) DEFAULT 0.00,
  `rol` double(11,2) NOT NULL DEFAULT 0.00,
  `xp` int(11) DEFAULT 0,
  `healthouter` int(4) DEFAULT 500,
  `healthinner` int(4) DEFAULT 100,
  `staminaouter` int(4) DEFAULT 100,
  `staminainner` int(4) DEFAULT 100,
  `hours` float NOT NULL DEFAULT 0,
  `LastLogin` date DEFAULT NULL,
  `inventory` longtext DEFAULT NULL,
  `slots` decimal(20,1) NOT NULL DEFAULT 35.0,
  `job` varchar(50) DEFAULT 'unemployed',
  `joblabel` varchar(255) DEFAULT 'Unemployed',
  `multijobs` longtext DEFAULT '{}',
  `meta` varchar(255) NOT NULL DEFAULT '{}',
  `firstname` varchar(50) DEFAULT ' ',
  `lastname` varchar(50) DEFAULT ' ',
  `character_desc` mediumtext NOT NULL DEFAULT ' ',
  `gender` varchar(50) NOT NULL DEFAULT ' ',
  `age` int(11) NOT NULL DEFAULT 0,
  `nickname` varchar(50) DEFAULT ' ',
  `skinPlayer` longtext DEFAULT NULL,
  `compPlayer` longtext DEFAULT NULL,
  `compTints` longtext DEFAULT NULL,
  `jobgrade` int(11) DEFAULT 0,
  `coords` longtext DEFAULT '{}',
  `status` varchar(140) DEFAULT '{}',
  `isdead` tinyint(1) DEFAULT 0,
  `skills` longtext DEFAULT NULL,
  `walk` varchar(50) DEFAULT 'noanim',
  `gunsmith` double(11,2) DEFAULT 0.00,
  `ammo` longtext DEFAULT '{}',
  `discordid` varchar(255) DEFAULT '0',
  `lastjoined` longtext DEFAULT '[]',
  `character_created` timestamp NOT NULL DEFAULT current_timestamp(),
  `curse` varchar(255) DEFAULT NULL,
  `moonshineenty` longtext DEFAULT '{}',
  `clan` int(11) DEFAULT 0,
  `motel` longtext DEFAULT NULL,
  `crafting` longtext DEFAULT '{"medical":0,"blacksmith":0,"basic":0,"survival":0,"brewing":0,"food":0}',
  `overlay` longtext DEFAULT NULL,
  `expressions` longtext DEFAULT NULL,
  `lastplayed` timestamp NULL DEFAULT NULL,
  UNIQUE KEY `identifier_charidentifier` (`identifier`,`charidentifier`) USING BTREE,
  KEY `charidentifier` (`charidentifier`) USING BTREE,
  KEY `identifier` (`identifier`),
  KEY `compPlayer` (`compPlayer`(768)),
  KEY `inventory` (`inventory`(768)),
  KEY `coords` (`coords`(768)),
  KEY `money` (`money`),
  KEY `meta` (`meta`),
  KEY `steamname` (`steamname`),
  KEY `crafting` (`crafting`(768)),
  CONSTRAINT `FK_characters_users` FOREIGN KEY (`identifier`) REFERENCES `users` (`identifier`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `characters`
--

LOCK TABLES `characters` WRITE;
/*!40000 ALTER TABLE `characters` DISABLE KEYS */;
/*!40000 ALTER TABLE `characters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `clan`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clan` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `info` longtext NOT NULL DEFAULT '[]',
  `cash` tinytext NOT NULL DEFAULT 0,
  `inventory` longtext NOT NULL DEFAULT '[]',
  `invlimit` int(11) DEFAULT 1000,
  `repo` int(11) DEFAULT 0,
  `taxmoney` int(11) DEFAULT 0,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `coords` (`id`),
  KEY `container` (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clan`
--

LOCK TABLES `clan` WRITE;
/*!40000 ALTER TABLE `clan` DISABLE KEYS */;
/*!40000 ALTER TABLE `clan` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `clothing_extras`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clothing_extras` (
  `charidentifier` int(11) NOT NULL,
  `extras` longtext DEFAULT NULL,
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clothing_extras`
--

LOCK TABLES `clothing_extras` WRITE;
/*!40000 ALTER TABLE `clothing_extras` DISABLE KEYS */;
/*!40000 ALTER TABLE `clothing_extras` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `clothing_hidden`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clothing_hidden` (
  `drawable` int(11) NOT NULL,
  `label` varchar(96) DEFAULT NULL,
  `hidden_by` varchar(96) DEFAULT NULL,
  `hidden_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`drawable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clothing_hidden`
--

LOCK TABLES `clothing_hidden` WRITE;
/*!40000 ALTER TABLE `clothing_hidden` DISABLE KEYS */;
/*!40000 ALTER TABLE `clothing_hidden` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `clothing_outfits`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clothing_outfits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charidentifier` int(11) NOT NULL,
  `identifier` varchar(100) DEFAULT NULL,
  `title` varchar(255) NOT NULL DEFAULT 'Outfit',
  `comps` longtext DEFAULT NULL,
  `extras` longtext DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `charidentifier` (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clothing_outfits`
--

LOCK TABLES `clothing_outfits` WRITE;
/*!40000 ALTER TABLE `clothing_outfits` DISABLE KEYS */;
/*!40000 ALTER TABLE `clothing_outfits` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `clothing_starter`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clothing_starter` (
  `charidentifier` int(11) NOT NULL,
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clothing_starter`
--

LOCK TABLES `clothing_starter` WRITE;
/*!40000 ALTER TABLE `clothing_starter` DISABLE KEYS */;
/*!40000 ALTER TABLE `clothing_starter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `container`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `container` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` longtext DEFAULT NULL,
  `items` longtext NOT NULL DEFAULT '{}',
  `invslots` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ID` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `crafting_fav`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `crafting_fav` (
  `charidentifier` int(255) NOT NULL DEFAULT 0,
  `favo` longtext DEFAULT '[]',
  PRIMARY KEY (`charidentifier`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `crafting_fav`
--

LOCK TABLES `crafting_fav` WRITE;
/*!40000 ALTER TABLE `crafting_fav` DISABLE KEYS */;
/*!40000 ALTER TABLE `crafting_fav` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `crafting_locations`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `crafting_locations` (
  `name` varchar(64) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `enabled` tinyint(4) NOT NULL DEFAULT 1,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `crafting_lock_owner`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `crafting_lock_owner` (
  `identifier` varchar(50) NOT NULL,
  `charidentifier` int(11) NOT NULL,
  `steamname` varchar(50) NOT NULL DEFAULT '',
  `charname` varchar(100) NOT NULL DEFAULT '',
  `lastseen` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`identifier`,`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `crafting_lock_owner`
--

LOCK TABLES `crafting_lock_owner` WRITE;
/*!40000 ALTER TABLE `crafting_lock_owner` DISABLE KEYS */;
/*!40000 ALTER TABLE `crafting_lock_owner` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `crafting_queue`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `crafting_queue` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charidentifier` int(11) NOT NULL,
  `label` varchar(96) NOT NULL DEFAULT '',
  `catagory` varchar(64) NOT NULL DEFAULT '',
  `count` int(11) NOT NULL DEFAULT 1,
  `rewards` longtext NOT NULL,
  `exp` int(11) NOT NULL DEFAULT 0,
  `metadata` longtext DEFAULT NULL,
  `queued_at` int(11) NOT NULL DEFAULT 0,
  `ready_at` int(11) NOT NULL DEFAULT 0,
  `claimed` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `owner` (`charidentifier`,`claimed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `crafting_queue`
--

LOCK TABLES `crafting_queue` WRITE;
/*!40000 ALTER TABLE `crafting_queue` DISABLE KEYS */;
/*!40000 ALTER TABLE `crafting_queue` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `crafting_recipes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `crafting_recipes` (
  `id` int(11) NOT NULL,
  `name` varchar(128) DEFAULT NULL,
  `category` varchar(64) DEFAULT NULL,
  `enabled` tinyint(4) NOT NULL DEFAULT 1,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `crafting_recipes`
--

LOCK TABLES `crafting_recipes` WRITE;
/*!40000 ALTER TABLE `crafting_recipes` DISABLE KEYS */;
INSERT INTO `crafting_recipes` VALUES (1,'Boiled Egg','food',1,'{\"Text\":\"Boiled Egg\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":6},{\"label\":\"Water\",\"name\":\"water\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"boiledegg\",\"count\":6}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(2,'Dried Salmon','food',1,'{\"Text\":\"Dried Salmon\",\"Param\":{\"Item\":[{\"label\":\"Sockeye Salmon\",\"name\":\"a_c_fishsalmonsockeye_01_ms\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"consumable_salmon\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":[\"p_campfire02x\",\"p_campfirecombined02x\"]},\"Desc\":\"\"}'),(3,'Medical Box','medical',1,'{\"Text\":\"Medical Box\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":40},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":1}],\"expadd\":1,\"Job\":[\"doctor\"],\"expreq\":150,\"Reward\":[{\"name\":\"medical_box_bag\",\"count\":1}],\"diff\":3000,\"gradelock\":1,\"catagory\":\"medical\",\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(4,'Joint','medical',1,'{\"Param\":{\"prop\":0,\"location\":0,\"expreq\":500,\"catagory\":\"medical\",\"expadd\":1,\"Item\":[{\"name\":\"hemp\",\"count\":1,\"label\":\"Hemp\"},{\"name\":\"rollingpaper\",\"count\":1,\"label\":\"Rolling paper\"}],\"Job\":0,\"Reward\":[{\"name\":\"joint\",\"count\":1,\"label\":\"\"}],\"diff\":3000},\"Desc\":\"\",\"Text\":\"Joint\"}'),(5,'Pure','medical',0,'{\"Text\":\"Pure\",\"Param\":{\"Item\":[{\"label\":\"Coal\",\"name\":\"coal\",\"count\":20},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":5}],\"expadd\":1,\"Job\":[\"pharmacist\",\"fence\"],\"expreq\":5000,\"Reward\":[{\"name\":\"pure\",\"count\":5}],\"diff\":3000,\"gradelock\":1,\"catagory\":\"medical\",\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(6,'Siphoned Pure','medical',0,'{\"Text\":\"Siphoned Pure\",\"Param\":{\"Item\":[{\"label\":\"Coal\",\"name\":\"coal\",\"count\":20},{\"label\":\"Morphine\",\"name\":\"morphine\",\"count\":2},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":5},{\"label\":\"Pure\",\"name\":\"pure\",\"count\":3}],\"expadd\":1,\"Job\":[\"pharmacist\",\"fence\"],\"expreq\":10000,\"Reward\":[{\"name\":\"siphopure\",\"count\":5}],\"diff\":3000,\"gradelock\":1,\"catagory\":\"medical\",\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(7,'Cooked Bluegil with Veggies','food',1,'{\"Text\": \"Cooked Bluegil with Veggies\", \"Param\": {\"Item\": [{\"label\": \"Small Bluegil\", \"name\": \"a_c_fishbluegil_01_sm\", \"count\": 1}, {\"label\": \"Parasol Mushroom\", \"name\": \"Parasol_Mushroom\", \"count\": 1}, {\"label\": \"Wild Carrot\", \"name\": \"Wild_Carrot\", \"count\": 1}], \"expadd\": 2, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cookedbluegil\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(8,'Chocolate Bar','food',1,'{\"Text\": \"Chocolate Bar\", \"Param\": {\"Item\": [{\"label\": \"Cocoa\", \"name\": \"cocoa\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}], \"expadd\": 3, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"consumable_chocolate\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(9,'Fruit Salad','food',1,'{\"Text\":\"Fruit Salad\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":2},{\"label\":\"Peach\",\"name\":\"consumable_peach\",\"count\":2},{\"label\":\"Creekplum\",\"name\":\"Creekplum\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":10,\"Reward\":[{\"name\":\"consumable_fruitsalad\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(10,'Deer Jerky','food',1,'{\"Text\":\"Deer Jerky\",\"Param\":{\"Item\":[{\"label\":\"Venison\",\"name\":\"venison\",\"count\":1}],\"expadd\":0.5,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"beefjerky\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(11,'Dried Bluegil','food',1,'{\"Text\":\"Dried Bluegil\",\"Param\":{\"Item\":[{\"label\":\"Small Bluegil\",\"name\":\"a_c_fishbluegil_01_sm\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"consumable_bluegil\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(12,'Cooked Trout','food',1,'{\"Text\":\"Cooked Trout\",\"Param\":{\"Item\":[{\"label\":\"Rainbow Trout\",\"name\":\"a_c_fishrainbowtrout_01_ms\",\"count\":1},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":2},{\"label\":\"Oleander Sage\",\"name\":\"Oleander_Sage\",\"count\":2}],\"expadd\":2,\"Job\":0,\"expreq\":50,\"Reward\":[{\"name\":\"consumable_trout\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(13,'Jerkied GameMeat','food',1,'{\"Text\":\"Jerkied GameMeat\",\"Param\":{\"Item\":[{\"label\":\"Game Meat\",\"name\":\"game\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":0.5,\"Job\":0,\"expreq\":5,\"Reward\":[{\"name\":\"consumable_game\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(14,'Raspberry Water','brewing',1,'{\"Desc\":\"\",\"Param\":{\"expadd\":1,\"Job\":0,\"diff\":3000,\"Reward\":[{\"count\":1,\"name\":\"raspberrywater\",\"label\":\"\"}],\"location\":0,\"prop\":0,\"Item\":[{\"count\":1,\"name\":\"sugar\",\"label\":\"Sugar\"},{\"count\":1,\"name\":\"water\",\"label\":\"Water\"},{\"count\":2,\"name\":\"Red_Raspberry\",\"label\":\"Red Raspberry\"}],\"catagory\":\"brewing\",\"expreq\":0},\"Text\":\"Raspberry Water\"}'),(15,'Cigarette','basic',1,'{\"Text\":\"Cigarette\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":1},{\"label\":\"Rolling paper\",\"name\":\"rollingpaper\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"cigarette\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(16,'Cigar','basic',1,'{\"Text\":\"Cigar\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":1},{\"label\":\"Rolling paper\",\"name\":\"rollingpaper\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"cigar\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(17,'Caramel','food',1,'{\"Text\":\"Caramel\",\"Param\":{\"Item\":[{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":50,\"Reward\":[{\"name\":\"consumable_caramel\",\"count\":5}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(18,'Heroin','medical',1,'{\"Desc\":\"\",\"Param\":{\"Reward\":[{\"count\":1,\"label\":\"\",\"name\":\"heroin\"}],\"location\":0,\"expreq\":3000,\"diff\":3000,\"Job\":[\"pharmacist\",\"fence\"],\"mixing\":1,\"expadd\":3,\"prop\":0,\"Item\":[{\"count\":1,\"label\":\"Morphine\",\"name\":\"morphine\"},{\"count\":2,\"label\":\"Acid\",\"name\":\"acid\"},{\"count\":1,\"label\":\"Blood_Flower\",\"name\":\"Blood_Flower\"}],\"catagory\":\"medical\"},\"Text\":\"Heroin\"}'),(19,'Gold Bar','blacksmith',1,'{\"Text\":\"Gold Bar\",\"Param\":{\"Item\":[{\"label\":\"Gold nugget\",\"name\":\"goldnugget\",\"count\":5},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":2,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":1,\"Reward\":[{\"name\":\"goldbar\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(20,'Iron Bars','blacksmith',1,'{\"Text\":\"Iron Bars\",\"Param\":{\"Item\":[{\"label\":\"Iron Ore\",\"name\":\"iron\",\"count\":5},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":2,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"ironbar\",\"count\":10}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(21,'Copper Bar','blacksmith',1,'{\"Text\":\"Copper Bar\",\"Param\":{\"Item\":[{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Copper Ore\",\"name\":\"copper\",\"count\":3}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"copper_bar\",\"count\":2}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(22,'Shell Casings','blacksmith',1,'{\"Text\":\"Shell Casings\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1},{\"label\":\"Copper\",\"name\":\"copper\",\"count\":1}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"shellcasing\",\"count\":20}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(23,'Bolts','blacksmith',1,'{\"Text\":\"Bolts\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"bolts\",\"count\":5}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(24,'Nails ','blacksmith',1,'{\"Text\":\"Nails \",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"nails\",\"count\":6}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(25,'Pipe','basic',1,'{\"Text\":\"Pipe\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":2},{\"label\":\"Clay\",\"name\":\"clay\",\"count\":1},{\"label\":\"Copper\",\"name\":\"copper\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"pipe\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(26,'Beer','brewing',1,'{\"Text\": \"Beer\", \"Param\": {\"Item\": [{\"label\": \"Hop\", \"name\": \"hop\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"beer\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(27,'Wine','brewing',1,'{\"Text\": \"Wine\", \"Param\": {\"Item\": [{\"label\": \"Black Berry\", \"name\": \"Black_Berry\", \"count\": 1}, {\"label\": \"Red Raspberry\", \"name\": \"Red_Raspberry\", \"count\": 1}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"wine\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(28,'Blackberry Water','brewing',1,'{\"Text\":\"Blackberry Water\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"blaber\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(29,'Herbal Medicine','medical',1,'{\"Desc\":\"\",\"Param\":{\"expadd\":1,\"Job\":[\"pharmacist\",\"vttribe\",\"bvtribe\",\"bwtribe\",\"doctor\"],\"diff\":3000,\"Reward\":[{\"count\":1,\"name\":\"herbmed\",\"label\":\"\"}],\"location\":0,\"prop\":0,\"Item\":[{\"count\":2,\"name\":\"Parasol_Mushroom\",\"label\":\"Parasol Mushroom\"},{\"count\":2,\"name\":\"English_Mace\",\"label\":\"English Mace\"},{\"count\":2,\"name\":\"Creeking_Thyme\",\"label\":\"Creeking Thyme\"}],\"catagory\":\"medical\",\"expreq\":0},\"Text\":\"Herbal Medicine\"}'),(30,'BlackBerry Ale','brewing',1,'{\"Text\": \"BlackBerry Ale\", \"Param\": {\"Item\": [{\"label\": \"Hop\", \"name\": \"hop\", \"count\": 2}, {\"label\": \"Black Berry\", \"name\": \"Black_Berry\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"blackberryale\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(31,'Raspberry Ale','brewing',1,'{\"Text\": \"Raspberry Ale\", \"Param\": {\"Item\": [{\"label\": \"Hop\", \"name\": \"hop\", \"count\": 2}, {\"label\": \"Red Raspberry\", \"name\": \"Red_Raspberry\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"raspberryale\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(32,'Breakfast','food',1,'{\"Text\":\"Breakfast\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Steak\",\"name\":\"steak\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":2,\"Job\":0,\"expreq\":100,\"Reward\":[{\"name\":\"consumable_breakfast\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(33,'Edible Veggies','food',1,'{\"Text\":\"Edible Veggies\",\"Param\":{\"Item\":[{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":1},{\"label\":\"Parasol Mushroom\",\"name\":\"Parasol_Mushroom\",\"count\":1},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":1}],\"expadd\":2,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"consumable_veggies\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(34,'Bottled Water','survival',1,'{\"Text\":\"Bottled Water\",\"Param\":{\"Item\":[{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":6},{\"label\":\"Wateringcan\",\"name\":\"wateringcan\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"water\",\"count\":6},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(35,'Ginseng Tea','brewing',1,'{\"Text\":\"Ginseng Tea\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"American Ginseng\",\"name\":\"American_Ginseng\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"ginsengtea\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(36,'Stone Hammer','blacksmith',1,'{\"Text\":\"Stone Hammer\",\"Param\":{\"Item\":[{\"label\":\"Rock\",\"name\":\"rock\",\"count\":3},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"stonehammer\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(37,'Iron Hammer','blacksmith',1,'{\"Text\":\"Iron Hammer\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":25,\"Reward\":[{\"name\":\"ironhammer\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(38,'Shovel','blacksmith',1,'{\"Text\":\"Shovel\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":3},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"shovel\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(39,'Hoe','blacksmith',1,'{\"Text\":\"Hoe\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"hoe\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(40,'Plant Trimmer','blacksmith',1,'{\"Text\":\"Plant Trimmer\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"planttrimmer\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(41,'Skinning Knife','blacksmith',1,'{\"Text\":\"Skinning Knife\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":400,\"Reward\":[{\"name\":\"skinning_knife\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(42,'Straight Razor','blacksmith',1,'{\"Text\":\"Straight Razor\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":3},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"Rabbit Skin\",\"name\":\"rabbits\",\"count\":1}],\"expadd\":10,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":25,\"Reward\":[{\"name\":\"unique_straightrazor\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(43,'Wrench','blacksmith',1,'{\"Text\":\"Wrench\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Copper Ore\",\"name\":\"copper\",\"count\":4}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"wrench\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(44,'Gold Pan','blacksmith',1,'{\"Text\":\"Gold Pan\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"goldpan\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(45,'Animal Trap','blacksmith',1,'{\"Text\":\"Animal Trap\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Bolt\",\"name\":\"bolts\",\"count\":6},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":1}],\"expadd\":2,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"beartrap\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(46,'Rifle Barrel ','blacksmith',1,'{\"Text\":\"Rifle Barrel \",\"Param\":{\"Item\":[{\"label\":\"Rifle Mold\",\"name\":\"riflemold\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":15},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":100,\"Reward\":[{\"name\":\"riflebarrel\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(47,'Rifle Receiver ','blacksmith',1,'{\"Text\":\"Rifle Receiver \",\"Param\":{\"Item\":[{\"label\":\"Rifle Receiver Mold\",\"name\":\"riflerecmold\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":15},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":100,\"Reward\":[{\"name\":\"riflereceiver\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(48,'Rifle Stock','blacksmith',1,'{\"Text\":\"Rifle Stock\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":5},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":100,\"Reward\":[{\"name\":\"riflestock\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(49,'Rifle Barrel Mold','blacksmith',1,'{\"Text\":\"Rifle Barrel Mold\",\"Param\":{\"Item\":[{\"label\":\"Clay\",\"name\":\"clay\",\"count\":5},{\"label\":\"Wateringcan\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":100,\"Reward\":[{\"name\":\"riflemold\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(50,'Rifle Receiver Mold','blacksmith',1,'{\"Text\":\"Rifle Receiver Mold\",\"Param\":{\"Item\":[{\"label\":\"Clay\",\"name\":\"clay\",\"count\":5},{\"label\":\"Wateringcan\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":100,\"Reward\":[{\"name\":\"riflerecmold\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(51,'Repeater Barrel ','blacksmith',1,'{\"Text\":\"Repeater Barrel \",\"Param\":{\"Item\":[{\"label\":\"Repeater Mold\",\"name\":\"repeatermold\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":15},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":25,\"Reward\":[{\"name\":\"repeaterbarrel\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(52,'Repeater Receiver','blacksmith',1,'{\"Text\":\"Repeater Receiver\",\"Param\":{\"Item\":[{\"label\":\"Repeater Receiver Mold\",\"name\":\"repeaterrecmold\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":15},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":25,\"Reward\":[{\"name\":\"repeaterreceiver\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(53,'Repeater Stock','blacksmith',1,'{\"Text\":\"Repeater Stock\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":5},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":25,\"Reward\":[{\"name\":\"repeaterstock\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(54,'Repeater Barrel Mold','blacksmith',1,'{\"Text\":\"Repeater Barrel Mold\",\"Param\":{\"Item\":[{\"label\":\"Clay\",\"name\":\"clay\",\"count\":5},{\"label\":\"Wateringcan\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":25,\"Reward\":[{\"name\":\"repeatermold\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(55,'Repeater Receiver Mold','blacksmith',1,'{\"Text\":\"Repeater Receiver Mold\",\"Param\":{\"Item\":[{\"label\":\"Clay\",\"name\":\"clay\",\"count\":5},{\"label\":\"Wateringcan\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":25,\"Reward\":[{\"name\":\"repeaterrecmold\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(56,'Shotgun Barrel','blacksmith',1,'{\"Text\":\"Shotgun Barrel\",\"Param\":{\"Item\":[{\"label\":\"Shotgun Mold\",\"name\":\"shotgunmold\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"shotgunbarrel\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(57,'Shotgun Stock','blacksmith',1,'{\"Text\":\"Shotgun Stock\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"shotgunstock\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(58,'Shotgun Barrel Mold','blacksmith',1,'{\"Text\":\"Shotgun Barrel Mold\",\"Param\":{\"Item\":[{\"label\":\"Clay\",\"name\":\"clay\",\"count\":5},{\"label\":\"Wateringcan\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"shotgunmold\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(59,'Pistol Barrel','blacksmith',1,'{\"Text\":\"Pistol Barrel\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":12},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":500,\"Reward\":[{\"name\":\"pistolbarrel\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(60,'Pistol Receiver','blacksmith',1,'{\"Text\":\"Pistol Receiver\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":15},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":3}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":500,\"Reward\":[{\"name\":\"pistolreceiver\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(61,'Pistol Handle','blacksmith',1,'{\"Text\":\"Pistol Handle\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":4},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":500,\"Reward\":[{\"name\":\"pistolgrip\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(62,'Revolver Barrel','blacksmith',1,'{\"Text\":\"Revolver Barrel\",\"Param\":{\"Item\":[{\"label\":\"Revolver Mold\",\"name\":\"revolvermold\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"revolverbarrel\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(63,'Revolver Cylinder','blacksmith',1,'{\"Text\":\"Revolver Cylinder\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"revolvercylinder\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(64,'Revolver Handle','blacksmith',1,'{\"Text\":\"Revolver Handle\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":4},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"revolverhandle\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(65,'Revolver Barrel Mold','blacksmith',1,'{\"Text\":\"Revolver Barrel Mold\",\"Param\":{\"Item\":[{\"label\":\"Clay\",\"name\":\"clay\",\"count\":5},{\"label\":\"Wateringcan\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"revolvermold\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(66,'Whiskey','brewing',1,'{\"Param\": {\"diff\": 4000, \"catagory\": \"brewing\", \"expadd\": 2, \"prop\": 0, \"Item\": [{\"name\": \"Blood_Flower\", \"count\": 2, \"label\": \"Blood Flower\"}, {\"name\": \"alcohol\", \"count\": 1, \"label\": \"Alcohol\"}], \"Job\": [\"valsaloon\", \"amsaloon\", \"bwbigsaloon\", \"rdsaloon\", \"sdbigsaloon\", \"sdsmallsaloon\", \"vhsaloon\", \"vtbigsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"Reward\": [{\"name\": \"whisky\", \"count\": 1, \"label\": \"\"}], \"expreq\": 0}, \"Desc\": \"House-made whiskey that\'s so good you won\'t remember last night.\", \"Text\": \"Whiskey\"}'),(67,'Rum','brewing',1,'{\"Text\": \"Rum\", \"Param\": {\"Item\": [{\"label\": \"Yarrow\", \"name\": \"Yarrow\", \"count\": 2}, {\"label\": \"Alcohol\", \"name\": \"alcohol\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"rum\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 4000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(68,'Tequila','brewing',1,'{\"Text\": \"Tequila\", \"Param\": {\"Item\": [{\"label\": \"Prairie Poppy\", \"name\": \"Prairie_Poppy\", \"count\": 2}, {\"label\": \"Alcohol\", \"name\": \"alcohol\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"tequila\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(69,'Vodka','brewing',1,'{\"Text\": \"Vodka\", \"Param\": {\"Item\": [{\"label\": \"Corn\", \"name\": \"corn\", \"count\": 2}, {\"label\": \"Alcohol\", \"name\": \"alcohol\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"vodka\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(70,'Wojape','survival',1,'{\"Text\":\"Wojape\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":3},{\"label\":\"Red Raspberry\",\"name\":\"Red_Raspberry\",\"count\":3},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"wojape\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(71,'Steak','food',1,'{\"Text\":\"Steak\",\"Param\":{\"Item\":[{\"label\":\"Beef\",\"name\":\"beef\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":1}],\"expadd\":2,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"steak\",\"count\":2}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(72,'Steak with Veggies','food',1,'{\"Text\":\"Steak with Veggies\",\"Param\":{\"Item\":[{\"label\":\"Beef\",\"name\":\"beef\",\"count\":2},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":4},{\"label\":\"Parasol Mushroom\",\"name\":\"Parasol_Mushroom\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"steakveg\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(73,'Antipoison','medical',1,'{\"Param\":{\"prop\":0,\"location\":0,\"expreq\":10,\"catagory\":\"medical\",\"expadd\":2,\"Item\":[{\"name\":\"Snake_Poison\",\"count\":1,\"label\":\"Snake Venom\"},{\"name\":\"Wintergreen_Berry\",\"count\":2,\"label\":\"Wintergreen Berry\"},{\"name\":\"Choc_Daisy\",\"count\":2,\"label\":\"Choc Daisy\"}],\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"doctor\",\"fence\"],\"Reward\":[{\"name\":\"antipoison\",\"count\":1,\"label\":\"\"}],\"diff\":3000},\"Desc\":\"\",\"Text\":\"Antipoison\"}'),(74,'Antivenom','medical',1,'{\"Param\":{\"prop\":0,\"location\":0,\"expreq\":10,\"catagory\":\"medical\",\"expadd\":2,\"Item\":[{\"name\":\"Snake_Poison\",\"count\":1,\"label\":\"Snake Venom\"},{\"name\":\"Wintergreen_Berry\",\"count\":2,\"label\":\"Wintergreen Berry\"},{\"name\":\"English_Mace\",\"count\":2,\"label\":\"English Mace\"}],\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"doctor\",\"fence\"],\"Reward\":[{\"name\":\"antipoison2\",\"count\":1,\"label\":\"\"}],\"diff\":3000},\"Desc\":\"\",\"Text\":\"Antivenom\"}'),(75,'Clean Water','survival',1,'{\"Text\":\"Clean Water\",\"Param\":{\"Item\":[{\"label\":\"Dirty Watering Jug\",\"name\":\"wateringcan_dirtywater\",\"count\":1}],\"expadd\":0.25,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"wateringcan\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(76,'Morphine','medical',1,'{\"Param\":{\"prop\":0,\"location\":0,\"Reward\":[{\"name\":\"morphine\",\"count\":1,\"label\":\"\"}],\"catagory\":\"medical\",\"expadd\":2,\"mixing\":1,\"Item\":[{\"name\":\"Prairie_Poppy\",\"count\":3,\"label\":\"PrairiePoppy\"},{\"name\":\"alcohol\",\"count\":1,\"label\":\"Alcohol\"},{\"name\":\"glassbottle\",\"count\":1,\"label\":\"Glass Bottle\"}],\"Job\":[\"pharmacist\",\"fence\",\"doctor\"],\"expreq\":50,\"diff\":3000},\"Desc\":\"\",\"Text\":\"Morphine\"}'),(77,'Tylenol','medical',0,'{\"Param\":{\"prop\":0,\"location\":0,\"expreq\":50,\"catagory\":\"medical\",\"expadd\":0,\"Item\":[{\"name\":\"acid\",\"count\":1,\"label\":\"Acid\"},{\"name\":\"salt\",\"count\":1,\"label\":\"Salt\"},{\"name\":\"glassbottle\",\"count\":1,\"label\":\"Glass Bottle\"}],\"Job\":[\"pharmacist\",\"doctor\"],\"Reward\":[{\"name\":\"tylenol\",\"count\":1,\"label\":\"\"}],\"diff\":3000},\"Desc\":\"\",\"Text\":\"Tylenol\"}'),(78,'Morphine Perscription','medical',1,'{\"Text\":\"Morphine Perscription\",\"Param\":{\"Item\":[{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1},{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":1}],\"expadd\":1,\"Job\":[\"doctor\"],\"expreq\":0,\"Reward\":[{\"name\":\"morpcert\",\"count\":1}],\"catagory\":\"medical\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(79,'Acid','medical',1,'{\"Param\":{\"prop\":0,\"location\":0,\"expreq\":50,\"catagory\":\"medical\",\"expadd\":1,\"Item\":[{\"name\":\"nitrite\",\"count\":1,\"label\":\"Nitrite\"},{\"name\":\"Prairie_Poppy\",\"count\":1,\"label\":\"Prairie Poppy\"}],\"Job\":[\"pharmacist\",\"fence\",\"doctor\"],\"Reward\":[{\"name\":\"acid\",\"count\":2,\"label\":\"\"}],\"diff\":3500},\"Desc\":\"\",\"Text\":\"Acid\"}'),(80,'Bandage','medical',0,'{\"Text\":\"Bandage\",\"Param\":{\"Item\":[{\"label\":\"Wool\",\"name\":\"wool\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1}],\"expadd\":1,\"Job\":[\"doctor\"],\"expreq\":0,\"Reward\":[{\"name\":\"bandage\",\"count\":10}],\"catagory\":\"medical\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(81,'Paper','basic',1,'{\"Text\":\"Paper\",\"Param\":{\"Item\":[{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":2},{\"label\":\"Water Jug\",\"name\":\"wateringcan\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"paper\",\"count\":5},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(82,'Lockpick','blacksmith',1,'{\"Text\":\"Lockpick\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5},{\"label\":\"Lockpick Mold\",\"name\":\"lockpickmold\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"lockpick\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(83,'Lockpick Mold','blacksmith',1,'{\"Text\":\"Lockpick Mold\",\"Param\":{\"Item\":[{\"label\":\"Clay\",\"name\":\"clay\",\"count\":3},{\"label\":\"Water Jug\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"lockpickmold\",\"count\":1},{\"name\":\"wateringcan\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(84,'Bandage (Honey)','medical',1,'{\"Text\":\"Bandage (Honey)\",\"Param\":{\"Item\":[{\"label\":\"Wool\",\"name\":\"wool\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1}],\"expadd\":1,\"Job\":[\"doctor\",\"pharmacist\",\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"bandage\",\"count\":2}],\"catagory\":\"medical\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(85,'Fish and Chips (Salmon)','food',1,'{\"Text\": \"Fish and Chips (Salmon)\", \"Param\": {\"Item\": [{\"label\": \"Sockeye Salmon\", \"name\": \"a_c_fishsalmonsockeye_01_ms\", \"count\": 1}, {\"label\": \"Carrot\", \"name\": \"Wild_Carrot\", \"count\": 1}, {\"label\": \"Potato\", \"name\": \"potato\", \"count\": 5}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Pork Fat\", \"name\": \"porkfat\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 50, \"Reward\": [{\"name\": \"fishchips\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 4000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(86,'Fish and Chips (Trout)','food',1,'{\"Text\": \"Fish and Chips (Trout)\", \"Param\": {\"Item\": [{\"label\": \"Rainbow Trout\", \"name\": \"a_c_fishrainbowtrout_01_ms\", \"count\": 1}, {\"label\": \"Carrot\", \"name\": \"Wild_Carrot\", \"count\": 1}, {\"label\": \"Potato\", \"name\": \"potato\", \"count\": 5}, {\"label\": \"Pork Fat\", \"name\": \"porkfat\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"fishchips\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(87,'Horse Brush','basic',1,'{\"Text\":\"Horse Brush\",\"Param\":{\"Item\":[{\"label\":\"Pronghorn Skin\",\"name\":\"prongs\",\"count\":2},{\"label\":\"Copper\",\"name\":\"copper\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":1}],\"expadd\":2,\"Job\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"expreq\":0,\"Reward\":[{\"name\":\"horsebrush\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"prop\":0},\"Desc\":\"\"}'),(88,'Haycube','basic',1,'{\"Text\":\"Haycube\",\"Param\":{\"Item\":[{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":2}],\"expadd\":1,\"Job\":[\"bwstable\",\"mfstable\",\"sbstable\",\"amstable\"],\"expreq\":0,\"Reward\":[{\"name\":\"consumable_haycube\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(89,'Fried Taters','food',1,'{\"Text\":\"Fried Taters\",\"Param\":{\"Item\":[{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Pork Fat\",\"name\":\"porkfat\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"friedtater\",\"count\":2}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(90,'Spaghetti with Meatballs','food',1,'{\"Text\": \"Spaghetti with Meatballs\", \"Param\": {\"Item\": [{\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Beef\", \"name\": \"beef\", \"count\": 1}, {\"label\": \"Yarrow\", \"name\": \"Yarrow\", \"count\": 2}], \"expadd\": 2, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"spaghetti\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(91,'Horse Meds','basic',1,'{\"Text\":\"Horse Meds\",\"Desc\":\"\",\"Param\":{\"diff\":3000,\"catagory\":\"basic\",\"expadd\":2,\"expreq\":100,\"prop\":0,\"location\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"Item\":[{\"label\":\"Prairie Poppy\",\"count\":3,\"name\":\"Prairie_Poppy\"},{\"label\":\"Red Sage\",\"count\":1,\"name\":\"Red_Sage\"},{\"label\":\"Sugar\",\"count\":2,\"name\":\"sugar\"},{\"label\":\"Glass Bottle\",\"count\":1,\"name\":\"glassbottle\"},{\"label\":\"Alcohol\",\"count\":2,\"name\":\"alcohol\"}],\"Reward\":[{\"label\":\"\",\"count\":1,\"name\":\"stim\"}],\"Job\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"]}}'),(92,'Horse Stimulant','basic',0,'{\"Text\":\"Horse Stimulant\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":3},{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1}],\"expadd\":1,\"Job\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"expreq\":0,\"Reward\":[{\"name\":\"stim2\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"prop\":0},\"Desc\":\"\"}'),(93,'Opium','medical',1,'{\"Param\":{\"prop\":0,\"location\":0,\"expreq\":500,\"catagory\":\"medical\",\"expadd\":2,\"Item\":[{\"name\":\"Prairie_Poppy\",\"count\":10,\"label\":\"Prairie Poppy\"},{\"name\":\"glassbottle\",\"count\":1,\"label\":\"Glass Bottle\"}],\"Job\":[\"pharmacist\",\"fence\",\"doctor\"],\"Reward\":[{\"name\":\"opium\",\"count\":1,\"label\":\"\"}],\"diff\":3000},\"Desc\":\"\",\"Text\":\"Opium\"}'),(94,'Chewing Tobbaco','basic',1,'{\"Text\":\"Chewing Tobbaco\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":10,\"Reward\":[{\"name\":\"chewingtobacco\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(95,'Cooked Pork','food',1,'{\"Text\":\"Cooked Pork\",\"Param\":{\"Item\":[{\"label\":\"Pork\",\"name\":\"pork\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"porkcooked\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(96,'Bacon','food',1,'{\"Text\":\"Bacon\",\"Param\":{\"Item\":[{\"label\":\"Pig fat\",\"name\":\"porkfat\",\"count\":5},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"porkbacon\",\"count\":4}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(97,'Porkchops with Veggies','food',1,'{\"Text\": \"Porkchops with Veggies\", \"Param\": {\"Item\": [{\"label\": \"Pork\", \"name\": \"pork\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Potato\", \"name\": \"potato\", \"count\": 3}, {\"label\": \"Wild Carrot\", \"name\": \"Wild_Carrot\", \"count\": 3}], \"expadd\": 3, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"porkwveg\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(98,'Cooked Largemouth Bass (Medium)','food',1,'{\"Text\":\"Cooked Largemouth Bass (Medium)\",\"Param\":{\"Item\":[{\"label\":\"Cooked Largemouth Bass (Medium)\",\"name\":\"a_c_fishlargemouthbass_01_ms\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"fishcookedlmb\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(99,'Cooked Largemouth Bass (Large)','food',1,'{\"Text\":\"Cooked Largemouth Bass (Large)\",\"Param\":{\"Item\":[{\"label\":\"Cooked Largemouth Bass (Large)\",\"name\":\"a_c_fishlargemouthbass_01_lg\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"fishcookedlmblg\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(100,'Cooked Bird Meat','food',1,'{\"Text\":\"Cooked Bird Meat\",\"Param\":{\"Item\":[{\"label\":\"Bird Meat\",\"name\":\"bird\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"birdmeatcook\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(101,'Iguana on a Stick','food',1,'{\"Text\":\"Iguana on a Stick\",\"Param\":{\"Item\":[{\"label\":\"Lizard foot\",\"name\":\"lizardl\",\"count\":4},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"iguanabits\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(102,'Sugar Cube','basic',1,'{\"Text\":\"Sugar Cube\",\"Param\":{\"Item\":[{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwstable\",\"mfstable\",\"sbstable\",\"amstable\"],\"expreq\":0,\"Reward\":[{\"name\":\"sugarcube\",\"count\":2}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(103,'Lenses','blacksmith',1,'{\"Text\":\"Lenses\",\"Param\":{\"Item\":[{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":10},{\"label\":\"Copper\",\"name\":\"copper\",\"count\":5}],\"expadd\":1,\"Job\":[\"bvbounty\"],\"expreq\":0,\"Reward\":[{\"name\":\"lense\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(104,'Muskrat Pie','food',1,'{\"Text\":\"Muskrat Pie\",\"Param\":{\"Item\":[{\"label\":\"Muskrat skin\",\"name\":\"muskrats\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Stringy Meat\",\"name\":\"stringy\",\"count\":1}],\"expadd\":3,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"muskratpie\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(105,'Cooked Mutton','food',1,'{\"Text\":\"Cooked Mutton\",\"Param\":{\"Item\":[{\"label\":\"Mutton\",\"name\":\"mutton\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"muttoncooked\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(106,'Mutton with Veggies','food',1,'{\"Text\": \"Mutton with Veggies\", \"Param\": {\"Item\": [{\"label\": \"Mutton\", \"name\": \"mutton\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Wild Carrot\", \"name\": \"Wild_Carrot\", \"count\": 2}, {\"label\": \"Corn\", \"name\": \"corn\", \"count\": 2}, {\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"muttonveg\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(107,'Prime Rib','food',1,'{\"Text\": \"Prime Rib\", \"Param\": {\"Item\": [{\"label\": \"Big Game Meat\", \"name\": \"biggame\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Wild Carrot\", \"name\": \"Wild_Carrot\", \"count\": 2}, {\"label\": \"Fried Taters\", \"name\": \"friedtater\", \"count\": 2}, {\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"primerib\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(108,'Fried Chicken','food',1,'{\"Text\":\"Fried Chicken\",\"Param\":{\"Item\":[{\"label\":\"Bird Meat\",\"name\":\"bird\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":10,\"Reward\":[{\"name\":\"friedchicken\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(109,'Big Game Chops','food',1,'{\"Text\":\"Big Game Chops\",\"Param\":{\"Item\":[{\"label\":\"Big Game\",\"name\":\"biggame\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":10,\"Reward\":[{\"name\":\"biggamecooked\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(110,'Scrambled Eggs','food',1,'{\"Text\":\"Scrambled Eggs\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":10,\"Reward\":[{\"name\":\"scrambledeggs\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(111,'Scrambled Eggs with Bacon','food',1,'{\"Text\":\"Scrambled Eggs with Bacon\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":5},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2},{\"label\":\"Bacon\",\"name\":\"porkbacon\",\"count\":5}],\"expadd\":1,\"Job\":0,\"expreq\":100,\"Reward\":[{\"name\":\"scrambledeggsbacon\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(112,'Chocolate Milk','food',1,'{\"Text\":\"Chocolate Milk\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":2},{\"label\":\"sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":10,\"Reward\":[{\"name\":\"chocolatemilk\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(113,'Holy Water','basic',1,'{\"Param\": {\"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"Item\": [{\"name\": \"glassbottle\", \"count\": 1, \"label\": \"Glass Bottle\"}, {\"name\": \"water\", \"count\": 1, \"label\": \"Water\"}, {\"name\": \"salt\", \"count\": 1, \"label\": \"Salt\"}, {\"name\": \"goldnugget\", \"count\": 2, \"label\": \"Gold Nugget\"}], \"expadd\": 1, \"catagory\": \"basic\", \"prop\": 0, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"holywater\", \"count\": 1, \"label\": \"\"}], \"diff\": 3000}, \"Text\": \"Holy Water\", \"Desc\": \"\"}'),(114,'Diamond Ring','blacksmith',1,'{\"Text\":\"Diamond Ring\",\"Param\":{\"Item\":[{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":5},{\"label\":\"Diamond\",\"name\":\"diamond\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":500,\"Reward\":[{\"name\":\"dring\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(115,'Fertilizer','survival',1,'{\"Text\":\"Fertilizer\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5}],\"expadd\":1,\"Job\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":0,\"Reward\":[{\"name\":\"fertilizer\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(116,'Fertilizer with Soft Wood','survival',1,'{\"Text\":\"Fertilizer with Soft Wood\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":20,\"Reward\":[{\"name\":\"fertilizersw\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(117,'Fertilizer with Squirrel','survival',1,'{\"Text\":\"Fertilizer with Squirrel\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":2},{\"label\":\"Black Squirrel\",\"name\":\"squirrel_black_c\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":20,\"Reward\":[{\"name\":\"fertilizersq\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(118,'Fertilizer with Wojape','survival',1,'{\"Text\":\"Fertilizer with Wojape\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5},{\"label\":\"Wojape\",\"name\":\"wojape\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":50,\"Reward\":[{\"name\":\"fertilizerwoj\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(119,'Fertilizer with Snake','survival',1,'{\"Text\":\"Fertilizer with Snake\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":2},{\"label\":\"Copperhead Snake Pelt\",\"name\":\"asnakes\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":50,\"Reward\":[{\"name\":\"fertilizersn\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(120,'Fertilizer with Eggs','survival',1,'{\"Text\":\"Fertilizer with Eggs\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5},{\"label\":\"Egg\",\"name\":\"egg\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":100,\"Reward\":[{\"name\":\"fertilizeregg\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(121,'Fertilizer with Produce','survival',1,'{\"Text\":\"Fertilizer with Produce\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":4},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5},{\"label\":\"Apple\",\"name\":\"apple\",\"count\":10},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":250,\"Reward\":[{\"name\":\"fertilizerpro\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(122,'Fertilizer with Pulp/Sap','survival',1,'{\"Text\":\"Fertilizer with Pulp/Sap\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":4},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":10},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":10},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":5},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":250,\"Reward\":[{\"name\":\"fertilizerpulpsap\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(123,'Pure Fertilizer','survival',1,'{\"Text\":\"Pure Fertilizer\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":5},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":20},{\"label\":\"Pure\",\"name\":\"pure\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":250,\"Reward\":[{\"name\":\"fertilizerpure\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(124,'Blessed Fertilizer','survival',1,'{\"Text\":\"Blessed Fertilizer\",\"Param\":{\"Item\":[{\"label\":\"Rocks\",\"name\":\"rock\",\"count\":5},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":20},{\"label\":\"Holy Water\",\"name\":\"holywater\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":250,\"Reward\":[{\"name\":\"fertilizerbless\",\"count\":10}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"rdfarm\",\"emfarm\",\"bwfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"\"}'),(125,'6 X Wooden Boards (Soft wood Board)','furni',1,'{\"Text\":\"6 X Wooden Boards (Soft wood Board)\",\"Param\":{\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":2},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":1}],\"prop\":0,\"catagory\":\"furni\",\"diff\":3000,\"expreq\":0,\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"Reward\":[{\"label\":\"\",\"name\":\"wooden_boards\",\"count\":6}],\"Tools\":[{\"name\":\"hatchet\",\"label\":\"Hatchet\",\"count\":1}]},\"Desc\":\"\"}'),(126,'Wooden fence (Hatchet)','furni',1,'{\"Text\":\"Wooden fence (Hatchet)\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":1}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":10,\"Reward\":[{\"name\":\"woodfence\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"hatchet\",\"label\":\"Hatchet\",\"count\":1}]},\"Desc\":\"\"}'),(127,'Hard Wood Boards','basic',1,'{\"Text\":\"Hard Wood Boards\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":1}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":50,\"Reward\":[{\"name\":\"hwoodboard\",\"count\":4}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(128,'Hatchet','basic',1,'{\"Text\":\"Hatchet\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":2}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"hatchet\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(129,'Pickaxe','basic',1,'{\"Text\":\"Pickaxe\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":2}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":100,\"Reward\":[{\"name\":\"pickaxe\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(130,'Barrel','basic',1,'{\"Text\":\"Barrel\",\"Param\":{\"Item\":[{\"label\":\"Wooden Boards\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":250,\"Reward\":[{\"name\":\"barrel\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(131,'Fire Wood','basic',1,'{\"Text\":\"Fire Wood\",\"Param\":{\"Item\":[{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":1},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"firewood\",\"count\":2}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(132,'Campfire','furni',1,'{\"Text\":\"Campfire\",\"Param\":{\"Item\":[{\"label\":\"Fire Wood\",\"name\":\"firewood\",\"count\":5},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":2}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":25,\"Reward\":[{\"name\":\"campfire\",\"count\":2}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(133,'Handsaw','basic',1,'{\"Text\":\"Handsaw\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":50,\"Reward\":[{\"name\":\"handsaw\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(134,'Churned Milk','food',1,'{\"Text\":\"Churned Milk\",\"Param\":{\"Item\":[{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"churnedmilk\",\"count\":5}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(135,'Butter','food',1,'{\"Text\":\"Butter\",\"Param\":{\"Item\":[{\"label\":\"Churned Milk\",\"name\":\"churnedmilk\",\"count\":5}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"butter\",\"count\":10}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(136,'Milk Cream','food',1,'{\"Text\":\"Milk Cream\",\"Param\":{\"Item\":[{\"label\":\"Churned Milk\",\"name\":\"churnedmilk\",\"count\":5},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"milkcream\",\"count\":5}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(137,'Vanilla Cream Cake','food',1,'{\"Text\":\"Vanilla Cream Cake\",\"Param\":{\"Item\":[{\"label\":\"Milk Cream\",\"name\":\"milkcream\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":50,\"Reward\":[{\"name\":\"vanillacake\",\"count\":1}],\"catagory\":\"food\",\"diff\":2500,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(138,'Chocolate Cream Cake','food',1,'{\"Text\":\"Chocolate Cream Cake\",\"Param\":{\"Item\":[{\"label\":\"Milk Cream\",\"name\":\"milkcream\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":50,\"Reward\":[{\"name\":\"chococake\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(139,'Coffee','brewing',1,'{\"Text\":\"Coffee\",\"Param\":{\"Item\":[{\"label\":\"Coffee Beans\",\"name\":\"coffeebeans\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"consumable_coffee\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(140,'Coffee with Sugar','brewing',1,'{\"Text\":\"Coffee with Sugar\",\"Param\":{\"Item\":[{\"label\":\"Coffee Beans\",\"name\":\"coffeebeans\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"coffeesugar\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(141,'Coffee with Cream','brewing',1,'{\"Text\":\"Coffee with Cream\",\"Param\":{\"Item\":[{\"label\":\"Coffee Beans\",\"name\":\"coffeebeans\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Milk Cream\",\"name\":\"milkcream\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"coffeecream\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(142,'Tea','brewing',1,'{\"Text\":\"Tea\",\"Param\":{\"Item\":[{\"label\":\"Tea Leaf\",\"name\":\"tealeaf\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"tea\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(143,'Tea with Sugar','brewing',1,'{\"Text\":\"Tea with Sugar\",\"Param\":{\"Item\":[{\"label\":\"Tea Leaf\",\"name\":\"tealeaf\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"teasugar\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(144,'British Tea','brewing',1,'{\"Text\":\"British Tea\",\"Param\":{\"Item\":[{\"label\":\"Tea Leaf\",\"name\":\"tealeaf\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"teabritish\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(145,'Crab Legs','food',1,'{\"Text\":\"Crab Legs\",\"Param\":{\"Item\":[{\"label\":\"Crab\",\"name\":\"crab_c\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"crablegs\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(146,'Butter Crab','food',1,'{\"Text\":\"Butter Crab\",\"Param\":{\"Item\":[{\"label\":\"Crab\",\"name\":\"crab_c\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":100,\"Reward\":[{\"name\":\"crabbutter\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(147,'Crab Entree','food',1,'{\"Text\":\"Crab Entree\",\"Param\":{\"Item\":[{\"label\":\"Crab\",\"name\":\"crab_c\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":2},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":2},{\"label\":\"Fried Taters\",\"name\":\"friedtater\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":250,\"Reward\":[{\"name\":\"crabentree\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(148,'Train Ticket','basic',1,'{\"Text\":\"Train Ticket\",\"Param\":{\"Item\":[{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1}],\"expadd\":1,\"Job\":[\"standardtrain\"],\"expreq\":0,\"Reward\":[{\"name\":\"trainticket\",\"count\":5}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(149,'Lifetime Ticket','basic',1,'{\"Text\":\"Lifetime Ticket\",\"Param\":{\"Item\":[{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1}],\"expadd\":1,\"Job\":[\"standardtrain\"],\"expreq\":25,\"Reward\":[{\"name\":\"lifeticket\",\"count\":1}],\"diff\":3000,\"gradelock\":4,\"catagory\":\"basic\",\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(150,'Luxury Ticket','basic',1,'{\"Text\":\"Luxury Ticket\",\"Param\":{\"Item\":[{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1}],\"expadd\":1,\"Job\":[\"standardtrain\"],\"expreq\":25,\"Reward\":[{\"name\":\"luxuryticket\",\"count\":5}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(151,'Peyote','food',1,'{\"Text\":\"Peyote\",\"Param\":{\"Item\":[{\"label\":\"Parasol Mushroom\",\"name\":\"Parasol_Mushroom\",\"count\":1},{\"label\":\"Snake Poison\",\"name\":\"Snake_Poison\",\"count\":2},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2},{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"peyote\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(152,'Cocaine Gum','medical',1,'{\"Param\":{\"prop\":0,\"location\":0,\"expreq\":100,\"catagory\":\"medical\",\"expadd\":2,\"Item\":[{\"name\":\"Wild_Mint\",\"count\":2,\"label\":\"Wild Mint\"},{\"name\":\"sap\",\"count\":2,\"label\":\"Sap\"},{\"name\":\"cocoa\",\"count\":2,\"label\":\"cocoa\"},{\"name\":\"acid\",\"count\":1,\"label\":\"Acid\"}],\"Job\":[\"pharmacist\"],\"Reward\":[{\"name\":\"cocainegum\",\"count\":1,\"label\":\"\"}],\"diff\":3000},\"Desc\":\"\",\"Text\":\"Cocaine Gum\"}'),(153,'Fiber Bandage','medical',0,'{\"Text\":\"Fiber Bandage\",\"Param\":{\"Item\":[{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":2},{\"label\":\"American Ginseng\",\"name\":\"American_Ginseng\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1}],\"expadd\":1,\"Job\":[\"pharmacist\",\"doctor\"],\"expreq\":10,\"Reward\":[{\"name\":\"fiberbandage\",\"count\":4}],\"catagory\":\"medical\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(154,'Wood Chair','furni',1,'{\"Text\":\"Wood Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":3},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"wood_chair\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(155,'Leather Chair','furni',1,'{\"Text\":\"Leather Chair\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":3},{\"label\":\"nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":400,\"Reward\":[{\"name\":\"leather_chair\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(156,'Varnish','basic',1,'{\"Text\":\"Varnish\",\"Param\":{\"Item\":[{\"label\":\"Watering Can\",\"name\":\"wateringcan\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":3},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":5},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"varnish\",\"count\":2}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(157,'Round Table','furni',1,'{\"Text\":\"Round Table\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":7},{\"label\":\"nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":200,\"Reward\":[{\"name\":\"round_table\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(158,'Standard Table','furni',1,'{\"Text\":\"Standard Table\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":1},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"nails\",\"name\":\"nails\",\"count\":5}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"standard_table\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(159,'Rectangle Table','furni',1,'{\"Text\":\"Rectangle Table\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":7},{\"label\":\"nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Hard Wood Board\",\"name\":\"wooden_boards\",\"count\":2}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":100,\"Reward\":[{\"name\":\"rectangle_table\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(160,'Timber','basic',1,'{\"Text\":\"Timber\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"Hard Wood Board\",\"name\":\"wooden_boards\",\"count\":1},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"timber\",\"count\":5}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(161,'Timber Table','furni',1,'{\"Text\":\"Timber Table\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":10},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"timber_table\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(162,'Kindling','basic',1,'{\"Text\":\"Kindling\",\"Param\":{\"Item\":[{\"label\":\"Softwood\",\"name\":\"wood\",\"count\":1}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"kindling\",\"count\":5}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"hatchet\",\"label\":\"Hatchet\",\"count\":1}]},\"Desc\":\"\"}'),(163,'Crafting Fire','furni',1,'{\"Text\":\"Crafting Fire\",\"Param\":{\"Item\":[{\"label\":\"Kindling\",\"name\":\"kindling\",\"count\":10},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":10}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"crafting_fire\",\"count\":2}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(164,'House Pot','blacksmith',1,'{\"Text\":\"House Pot\",\"Param\":{\"Item\":[{\"label\":\"Clay\",\"name\":\"clay\",\"count\":6},{\"label\":\"Watering Can\",\"name\":\"wateringcan\",\"count\":1}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"pota\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(165,'Water Pump Handle','blacksmith',1,'{\"Text\":\"Water Pump Handle\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":3},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":3}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"water_pump_handle\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(166,'Water Pump','blacksmith',1,'{\"Text\":\"Water Pump\",\"Param\":{\"Item\":[{\"label\":\"Water Pump Handle\",\"name\":\"water_pump_handle\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":6},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":6},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":8}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"water_pump\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(167,'Flower Boxes','furni',1,'{\"Text\":\"Flower Boxes\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":5}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"flowerboxes\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(168,'Blanket Box','furni',1,'{\"Text\":\"Blanket Box\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"blanket_box\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(169,'Gun Barrel','furni',1,'{\"Text\":\"Gun Barrel\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":300,\"Reward\":[{\"name\":\"gun_barrel\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(170,'Apple Barrel','furni',1,'{\"Text\":\"Apple Barrel\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":3}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":300,\"Reward\":[{\"name\":\"apple_barrel\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(171,'Apple Basket','furni',1,'{\"Text\":\"Apple Basket\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":6}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"apple_basket\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(172,'String','basic',1,'{\"Text\":\"String\",\"Param\":{\"Item\":[{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"string\",\"count\":5}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(173,'Food Barrel','furni',1,'{\"Text\":\"Food Barrel\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":3}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"food_barrel\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(174,'Washtub','blacksmith',1,'{\"Text\":\"Washtub\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":8}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"washtub\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(175,'Tool Barrel','furni',1,'{\"Text\":\"Tool Barrel\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Blue Paint\",\"name\":\"bluepaint\",\"count\":3}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":300,\"Reward\":[{\"name\":\"tool_barrel\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(176,'Butcher Table','furni',1,'{\"Text\":\"Butcher Table\",\"Param\":{\"Item\":[{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":5},{\"label\":\"Elk Pelt\",\"name\":\"elks\",\"count\":5},{\"label\":\"Buck Skin\",\"name\":\"bucks\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"butchertable3\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"Bucther table used for Camps\"}'),(177,'Bounty Hunter Tent','furni',1,'{\"Text\":\"Bounty Hunter Tent\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":5}],\"expadd\":2,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\",\"sblumber\"],\"expreq\":100,\"Reward\":[{\"name\":\"tent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3500,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(178,'Coyote Taxidermy','furni',1,'{\"Text\":\"Coyote Taxidermy\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Coyote Skin\",\"name\":\"coyotes\",\"count\":2},{\"label\":\"Coyote Tooth\",\"name\":\"coyotef\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"coyote_taxidermy\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"\"}'),(179,'Pheasant Taxidermy','furni',1,'{\"Text\":\"Pheasant Taxidermy\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Pheasant Feather\",\"name\":\"peasantf\",\"count\":6},{\"label\":\"Pheasant Beak\",\"name\":\"peasantb\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"pheasant_taxidermy\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"\"}'),(180,'Deer Taxidermy','furni',1,'{\"Text\":\"Deer Taxidermy\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Deer Heart\",\"name\":\"deerheart\",\"count\":1},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"deer_taxidermy\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"\"}'),(181,'Cougar Taxidermy','furni',1,'{\"Text\":\"Cougar Taxidermy\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Cougar Skin\",\"name\":\"cougars\",\"count\":2},{\"label\":\"Cougar Tooth\",\"name\":\"cougarf\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"cougar_taxidermy\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"\"}'),(182,'Vulture Taxidermy','furni',1,'{\"Text\":\"Vulture Taxidermy\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Eagle feather\",\"name\":\"eaglef\",\"count\":2},{\"label\":\"Western Vulture Beak\",\"name\":\"condorb\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"vulture_taxidermy\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"\"}'),(183,'Bear Bench','furni',1,'{\"Text\":\"Bear Bench\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":10}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":400,\"Reward\":[{\"name\":\"bear_bench\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(184,'Log Bench A','furni',1,'{\"Text\":\"Log Bench A\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"log_bencha\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(185,'Log Bench B','furni',1,'{\"Text\":\"Log Bench B\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":100,\"Reward\":[{\"name\":\"log_benchb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(186,'Cloth Bench','furni',1,'{\"Text\":\"Cloth Bench\",\"Param\":{\"Item\":[{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":600,\"Reward\":[{\"name\":\"cloth_bench\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(187,'Wooden Bench','furni',1,'{\"Text\":\"Wooden Bench\",\"Param\":{\"Item\":[{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":8},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":200,\"Reward\":[{\"name\":\"wooden_bench\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(188,'Wicker','basic',1,'{\"Text\":\"Wicker\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"wicker\",\"count\":5}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wood_plane\",\"label\":\"Wood Plane\",\"count\":1}]},\"Desc\":\"\"}'),(189,'Wood Plane','blacksmith',1,'{\"Text\":\"Wood Plane\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":8},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":4},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":4}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"wood_plane\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(190,'Wicker Bench','furni',1,'{\"Text\":\"Wicker Bench\",\"Param\":{\"Item\":[{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":200,\"Reward\":[{\"name\":\"wicker_bench\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(191,'Brown Wood Dresser','furni',1,'{\"Text\":\"Brown Wood Dresser\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":200,\"Reward\":[{\"name\":\"bwdresser\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(192,'Mirror','blacksmith',1,'{\"Text\":\"Mirror\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"mirror\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(193,'Brown Mirror Dresser','furni',1,'{\"Text\":\"Brown Mirror Dresser\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Mirror\",\"name\":\"mirror\",\"count\":2}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":600,\"Reward\":[{\"name\":\"bmdresser\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(194,'Nightstand','furni',1,'{\"Text\":\"Nightstand\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":400,\"Reward\":[{\"name\":\"nightstand\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(195,'Side Table','furni',1,'{\"Text\":\"Side Table\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"side_table\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(196,'Side Table A','furni',1,'{\"Text\":\"Side Table A\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":8},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":200,\"Reward\":[{\"name\":\"side_tablea\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(197,'Side Table B','furni',1,'{\"Text\":\"Side Table B\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":2}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":200,\"Reward\":[{\"name\":\"side_tableb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(198,'Chest A','furni',1,'{\"Text\":\"Chest A\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":200,\"Reward\":[{\"name\":\"chesta\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(199,'Chest B','furni',1,'{\"Text\":\"Chest B\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10}],\"expadd\":1,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":300,\"Reward\":[{\"name\":\"chestb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(200,'Lantern','blacksmith',1,'{\"Text\":\"Lantern\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":6}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"lana\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(201,'Double Candle','blacksmith',1,'{\"Text\":\"Double Candle\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":4}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"dbcandle\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(202,'Cloth','basic',1,'{\"Text\":\"Cloth\",\"Param\":{\"Item\":[{\"label\":\"Wool\",\"name\":\"wool\",\"count\":3},{\"label\":\"Ram Pelt\",\"name\":\"rams\",\"count\":2}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"cloth\",\"count\":5}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"\"}'),(203,'wax','basic',1,'{\"Text\":\"wax\",\"Param\":{\"Item\":[{\"label\":\"Pork Fat\",\"name\":\"porkfat\",\"count\":3},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"wax\",\"count\":5}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"\"}'),(204,'Candle','blacksmith',1,'{\"Text\":\"Candle\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":4}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"candlea\",\"count\":1}],\"catagory\":\"blacksmith\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(205,'Small Melted Candle','furni',1,'{\"Text\":\"Small Melted Candle\",\"Param\":{\"Item\":[{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":6}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"smallmcandle\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"\"}'),(206,'Bottled Candle','furni',1,'{\"Text\":\"Bottled Candle\",\"Param\":{\"Item\":[{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Small Candle\",\"name\":\"smallmcandle\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"bcandle\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0},\"Desc\":\"\"}'),(207,'Refined Moose Pelt','survival',0,'{\"Text\":\"Refined Moose Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Moose Pelt\",\"name\":\"legmooses\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt1\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(208,'Refined Fox Pelt','survival',0,'{\"Text\":\"Refined Fox Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Fox Pelt\",\"name\":\"legfoxskin\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt2\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(209,'Refined Bison Pelt','survival',0,'{\"Text\":\"Refined Bison Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Bison Pelt\",\"name\":\"legbisons\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt3\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(210,'Refined Buck Pelt','survival',0,'{\"Text\":\"Refined Buck Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Buck Pelt\",\"name\":\"legbucks3\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt4\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(211,'Refined Bear Pelt','survival',0,'{\"Text\":\"Refined Bear Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Bear Pelt\",\"name\":\"leggbears\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt5\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(212,'Refined Wolf Pelt','survival',0,'{\"Text\":\"Refined Wolf Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Wolf Pelt\",\"name\":\"legwolfpelt\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt6\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(213,'Refined Panther Pelt','survival',0,'{\"Text\":\"Refined Panther Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Panther Pelt\",\"name\":\"legpanthers2\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt7\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(214,'Refined Coyote Pelt','survival',0,'{\"Text\":\"Refined Coyote Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Coyote Pelt\",\"name\":\"legcoyotes\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt8\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(215,'Refined Cougar Pelt','survival',0,'{\"Text\":\"Refined Cougar Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Cougar Pelt\",\"name\":\"legcougars\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt9\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(216,'Refined Boar Pelt','survival',0,'{\"Text\":\"Refined Boar Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Boar Pelt\",\"name\":\"legboars\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt10\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(217,'Refined Beaver Pelt','survival',0,'{\"Text\":\"Refined Beaver Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Beaver Pelt\",\"name\":\"legbeawers\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt11\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(218,'Refined Alligator Pelt','survival',0,'{\"Text\":\"Refined Alligator Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Alligator Pelt\",\"name\":\"legaligators\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt12\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(219,'Refined Elk Pelt','survival',0,'{\"Text\":\"Refined Elk Pelt\",\"Param\":{\"Item\":[{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":10},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":10},{\"label\":\"Water Bucket\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Legendary Elk Pelt\",\"name\":\"legelks\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"rpelt13\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"survival\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"Processed pelt used to craft premium items and weapons\"}'),(220,'leather (Bison)','basic',1,'{\"Text\":\"leather (Bison)\",\"Param\":{\"Item\":[{\"label\":\"Bison Pelt\",\"name\":\"bisons\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":3},{\"label\":\"Watering Can\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"leather\",\"count\":5},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"\"}'),(221,'leather (Deer)','basic',1,'{\"Text\":\"leather (Deer)\",\"Param\":{\"Item\":[{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":3},{\"label\":\"Watering Can\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"leather\",\"count\":3},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"\"}'),(222,'leather (Pig)','basic',1,'{\"Text\":\"leather (Pig)\",\"Param\":{\"Item\":[{\"label\":\"Pig skin\",\"name\":\"pigs\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":3},{\"label\":\"Watering Can\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"leather\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"\"}'),(223,'leather (Aligator)','basic',1,'{\"Text\":\"leather (Aligator)\",\"Param\":{\"Item\":[{\"label\":\"Aligator skin\",\"name\":\"aligators\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":3},{\"label\":\"Watering Can\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"leather\",\"count\":5},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"\"}'),(224,'leather (Pronghorn)','basic',1,'{\"Text\":\"leather (Pronghorn)\",\"Param\":{\"Item\":[{\"label\":\"Pronghorn pelt\",\"name\":\"prongs\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":3},{\"label\":\"Watering Can\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"leather\",\"count\":1},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"\"}'),(225,'leather (Wolf)','basic',1,'{\"Text\":\"leather (Wolf)\",\"Param\":{\"Item\":[{\"label\":\"Wolf pelt\",\"name\":\"wolfpelt\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":3},{\"label\":\"Watering Can\",\"name\":\"wateringcan\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":1,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"expreq\":0,\"Reward\":[{\"name\":\"leather\",\"count\":3},{\"name\":\"wateringcan_empty\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"prop\":0,\"Tools\":[{\"name\":\"skinning_knife\",\"label\":\"Skinning Knife\",\"count\":1}]},\"Desc\":\"\"}'),(226,'Flower Arrangements','basic',1,'{\"Param\": {\"expadd\": 1, \"Reward\": [{\"name\": \"flowerarrangement\", \"label\": \"\", \"count\": 1}], \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0, \"diff\": 3000, \"catagory\": \"basic\", \"expreq\": 100, \"Item\": [{\"name\": \"Blood_Flower\", \"label\": \"Blood Flower\", \"count\": 4}, {\"name\": \"Oleander_Sage\", \"label\": \"Oleander Sage\", \"count\": 4}, {\"name\": \"Prairie_Poppy\", \"label\": \"Prairie Poppy\", \"count\": 4}, {\"name\": \"fibers\", \"label\": \"Fiber\", \"count\": 4}, {\"name\": \"string\", \"label\": \"String\", \"count\": 1}], \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"]}, \"Desc\": \"\", \"Text\": \"Flower Arrangements\"}'),(227,'Batter','food',1,'{\"Text\": \"Batter\", \"Param\": {\"Item\": [{\"label\": \"Milk\", \"name\": \"milk\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"batter\", \"count\": 4}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(228,'Bread','food',1,'{\"Text\": \"Bread\", \"Param\": {\"Item\": [{\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"bread\", \"count\": 4}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(229,'Garlic Bread','food',1,'{\"Text\": \"Garlic Bread\", \"Param\": {\"Item\": [{\"label\": \"Bread\", \"name\": \"bread\", \"count\": 1}, {\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 3}, {\"label\": \"Oregano\", \"name\": \"Oregano\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"breadgarlic\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(230,'Corn Bread','food',1,'{\"Text\": \"Corn Bread\", \"Param\": {\"Item\": [{\"label\": \"Bread\", \"name\": \"bread\", \"count\": 1}, {\"label\": \"Corn\", \"name\": \"corn\", \"count\": 1}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"breadcorn\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(231,'Soda Bread','food',1,'{\"Text\": \"Soda Bread\", \"Param\": {\"Item\": [{\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"breadsoda\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(232,'Ginger Bread','food',1,'{\"Text\": \"Ginger Bread\", \"Param\": {\"Item\": [{\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Honey\", \"name\": \"honey\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"breadginger\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(233,'Corn on the cob','food',1,'{\"Text\": \"Corn on the cob\", \"Param\": {\"Item\": [{\"label\": \"Corn\", \"name\": \"corn\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cornoncob\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(234,'Creamed Corn','food',1,'{\"Text\": \"Creamed Corn\", \"Param\": {\"Item\": [{\"label\": \"Corn\", \"name\": \"corn\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Milk Cream\", \"name\": \"milkcream\", \"count\": 1}, {\"label\": \"Oregano\", \"name\": \"Oregano\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"crncrm\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(235,'Parasol Schnitzel','food',1,'{\"Text\": \"Parasol Schnitzel\", \"Param\": {\"Item\": [{\"label\": \"Egg\", \"name\": \"egg\", \"count\": 2}, {\"label\": \"Bread\", \"name\": \"bread\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Parasol Mushroom\", \"name\": \"Parasol_Mushroom\", \"count\": 3}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"parasolcook\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(236,'Corn Beef & Hash','food',1,'{\"Text\": \"Corn Beef & Hash\", \"Param\": {\"Item\": [{\"label\": \"Corn\", \"name\": \"corn\", \"count\": 1}, {\"label\": \"Beef\", \"name\": \"beef\", \"count\": 1}, {\"label\": \"Potato\", \"name\": \"potato\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Oregano\", \"name\": \"Oregano\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cornbeefhash\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(237,'Jambalaya','food',1,'{\"Text\": \"Jambalaya\", \"Param\": {\"Item\": [{\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 2}, {\"label\": \"Bird Meat\", \"name\": \"bird\", \"count\": 1}, {\"label\": \"Big Game Meat\", \"name\": \"biggame\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}, {\"label\": \"Oregano\", \"name\": \"Oregano\", \"count\": 1}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jambalaya\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(238,'Cookie','food',1,'{\"Text\": \"Cookie\", \"Param\": {\"Item\": [{\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cookie\", \"count\": 5}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(239,'Donut','food',1,'{\"Text\": \"Donut\", \"Param\": {\"Item\": [{\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"donut\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3450, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(240,'Chocolate Donut','food',1,'{\"Text\": \"Chocolate Donut\", \"Param\": {\"Item\": [{\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}, {\"label\": \"Cocoa\", \"name\": \"cocoa\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"donutchoco\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(241,'Carrot Cake','food',1,'{\"Text\": \"Carrot Cake\", \"Param\": {\"Item\": [{\"label\": \"Wild Carrot\", \"name\": \"Wild_Carrot\", \"count\": 3}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cakecarrot\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(242,'Red Raspberry Pie','food',1,'{\"Text\": \"Red Raspberry Pie\", \"Param\": {\"Item\": [{\"label\": \"Red Raspberry\", \"name\": \"Red_Raspberry\", \"count\": 2}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 3}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"pieredraspberry\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(243,'Black Berry Pie','food',1,'{\"Text\": \"Black Berry Pie\", \"Param\": {\"Item\": [{\"label\": \"black berry\", \"name\": \"Black_Berry\", \"count\": 2}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 3}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"pieblackberry\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3050, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(244,'Pumpkin Pie','food',1,'{\"Text\": \"Pumpkin Pie\", \"Param\": {\"Item\": [{\"label\": \"Pumpkin\", \"name\": \"pumpkin\", \"count\": 2}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 3}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"piepumpkin\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 4000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(245,'Apple Pie','food',1,'{\"Text\": \"Apple Pie\", \"Param\": {\"Item\": [{\"label\": \"Apple\", \"name\": \"apple\", \"count\": 2}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 3}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 500, \"Reward\": [{\"name\": \"pieapple\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 4000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(246,'Brownie','food',1,'{\"Text\": \"Brownie\", \"Param\": {\"Item\": [{\"label\": \"Egg\", \"name\": \"egg\", \"count\": 3}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Cocoa\", \"name\": \"cocoa\", \"count\": 4}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 500, \"Reward\": [{\"name\": \"brownie\", \"count\": 3}], \"catagory\": \"food\", \"diff\": 4200, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(247,'Hemp Brownie','food',1,'{\"Text\": \"Hemp Brownie\", \"Param\": {\"Item\": [{\"label\": \"Hemp\", \"name\": \"hemp\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 3}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Cocoa\", \"name\": \"cocoa\", \"count\": 4}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 750, \"Reward\": [{\"name\": \"browniehemp\", \"count\": 3}], \"catagory\": \"food\", \"diff\": 4200, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(248,'Pancakes & Fruit','food',1,'{\"Text\": \"Pancakes & Fruit\", \"Param\": {\"Item\": [{\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"egg\", \"name\": \"egg\", \"count\": 1}, {\"label\": \"Red Raspberry\", \"name\": \"Red_Raspberry\", \"count\": 2}, {\"label\": \"Black Berry\", \"name\": \"Black_Berry\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 750, \"Reward\": [{\"name\": \"pancakesfruit\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 4500, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(249,'Pancakes & Chocolate','food',1,'{\"Text\": \"Pancakes & Chocolate\", \"Param\": {\"Item\": [{\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"egg\", \"name\": \"egg\", \"count\": 1}, {\"label\": \"Cocoa\", \"name\": \"cocoa\", \"count\": 4}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 50, \"Reward\": [{\"name\": \"pancakeschoco\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 4500, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(250,'Sarsaprilla','brewing',1,'{\"Text\": \"Sarsaprilla\", \"Param\": {\"Item\": [{\"label\": \"Choc Daisy\", \"name\": \"Choc_Daisy\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"English Mace\", \"name\": \"English_Mace\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"sarsa\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(251,'Root Beer','brewing',1,'{\"Text\": \"Root Beer\", \"Param\": {\"Item\": [{\"label\": \"American Ginseng\", \"name\": \"American_Ginseng\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"sdtheatre\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"rber\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"sdtheatre\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(252,'Ginger Ale','brewing',1,'{\"Text\": \"Ginger Ale\", \"Param\": {\"Item\": [{\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Honey\", \"name\": \"honey\", \"count\": 1}, {\"label\": \"American Ginseng\", \"name\": \"American_Ginseng\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"sdtheatre\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"ginal\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"sdtheatre\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(253,'Ginger Beer','brewing',1,'{\"Text\": \"Ginger Beer\", \"Param\": {\"Item\": [{\"label\": \"Alcohol\", \"name\": \"alcohol\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"American Ginseng\", \"name\": \"American_Ginseng\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"gber\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(254,'Cream Soda','brewing',1,'{\"Text\": \"Cream Soda\", \"Param\": {\"Item\": [{\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Honey\", \"name\": \"honey\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"sdtheatre\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"crso\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"sdtheatre\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(255,'Orange blossom soda','brewing',1,'{\"Text\": \"Orange blossom soda\", \"Param\": {\"Item\": [{\"label\": \"Orange\", \"name\": \"orange\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"orblos\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(256,'Apple Soda','brewing',1,'{\"Text\": \"Apple Soda\", \"Param\": {\"Item\": [{\"label\": \"Apple\", \"name\": \"apple\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"apsod\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(257,'Currant Soda','brewing',1,'{\"Text\": \"Currant Soda\", \"Param\": {\"Item\": [{\"label\": \"Black Currant\", \"name\": \"Black_Currant\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cursod\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(258,'HoreHound Soda','brewing',1,'{\"Text\": \"HoreHound Soda\", \"Param\": {\"Item\": [{\"label\": \"Creekplum\", \"name\": \"Creekplum\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"horsod\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(259,'Sparkling Lemon Soda','brewing',1,'{\"Text\": \"Sparkling Lemon Soda\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"salesod\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(260,'Cheese & Meat Stick','food',1,'{\"Text\": \"Cheese & Meat Stick\", \"Param\": {\"Item\": [{\"label\": \"Stringy Meat\", \"name\": \"stringy\", \"count\": 2}, {\"label\": \"Churned Milk\", \"name\": \"churnedmilk\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"chemes\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(261,'Fried Duck & Crispy Potato','food',1,'{\"Text\": \"Fried Duck & Crispy Potato\", \"Param\": {\"Item\": [{\"label\": \"Bird Meat\", \"name\": \"bird\", \"count\": 1}, {\"label\": \"Potato\", \"name\": \"potato\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}, {\"label\": \"Duck fat\", \"name\": \"duckfat\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"fridco\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(262,'Whole Grain oats','food',1,'{\"Text\":\"Whole Grain oats\",\"Param\":{\"Item\":[{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":2},{\"label\":\"Apple\",\"name\":\"apple\",\"count\":2},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":2}],\"expadd\":1,\"Job\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"expreq\":0,\"Reward\":[{\"name\":\"holgo\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"prop\":0},\"Desc\":\"\"}'),(263,'Apple Lickems','food',1,'{\"Text\":\"Apple Lickems\",\"Param\":{\"Item\":[{\"label\":\"Whole Grain oats\",\"name\":\"holgo\",\"count\":2},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"expreq\":0,\"Reward\":[{\"name\":\"aplic\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"prop\":0},\"Desc\":\"\"}'),(264,'Pickled Eggs','food',1,'{\"Text\": \"Pickled Eggs\", \"Param\": {\"Item\": [{\"label\": \"Egg\", \"name\": \"egg\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}, {\"label\": \"Yarrow\", \"name\": \"Yarrow\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vtcafe\", \"vhgeneralstore\"], \"expreq\": 0, \"Reward\": [{\"name\": \"pegg\", \"count\": 2}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(265,'Chicken & Carrot Soup','food',1,'{\"Text\":\"Chicken & Carrot Soup\",\"Param\":{\"Item\":[{\"label\":\"Bird Meat\",\"name\":\"bird\",\"count\":1},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":1},{\"label\":\"Oregano\",\"name\":\"Oregano\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwchurch\",\"vtchurch\",\"rdchurch\",\"sdchurch\"],\"expreq\":0,\"Reward\":[{\"name\":\"kitsup\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":[\"bwchurch\",\"vtchurch\",\"rdchurch\",\"sdchurch\"],\"prop\":0},\"Desc\":\"\"}'),(266,'Barley Water','brewing',1,'{\"Text\":\"Barley Water\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":1},{\"label\":\"Choc Daisy\",\"name\":\"Choc_Daisy\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwchurch\",\"vtchurch\",\"rdchurch\",\"sdchurch\"],\"expreq\":0,\"Reward\":[{\"name\":\"barwa\",\"count\":2}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":[\"bwchurch\",\"vtchurch\",\"rdchurch\",\"sdchurch\"],\"prop\":0},\"Desc\":\"\"}'),(267,'Milk & Honey','brewing',1,'{\"Text\":\"Milk & Honey\",\"Param\":{\"Item\":[{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1}],\"expadd\":1,\"Job\":[\"doctor\"],\"expreq\":0,\"Reward\":[{\"name\":\"milkhoney\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":[\"doctor\"],\"prop\":0},\"Desc\":\"\"}'),(268,'Berry Mint Fish Bake','food',1,'{\"Text\": \"Berry Mint Fish Bake\", \"Param\": {\"Item\": [{\"label\": \"Rainbow Trout\", \"name\": \"a_c_fishrainbowtrout_01_ms\", \"count\": 1}, {\"label\": \"Blue Berry\", \"name\": \"blueberry\", \"count\": 1}, {\"label\": \"Potato\", \"name\": \"potato\", \"count\": 1}, {\"label\": \"Wild Mint\", \"name\": \"Wild_Mint\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vtcafe\", \"vhgeneralstore\"], \"expreq\": 0, \"Reward\": [{\"name\": \"mintfish\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(269,'Tombstone Chili','food',1,'{\"Text\": \"Tombstone Chili\", \"Param\": {\"Item\": [{\"label\": \"Beef\", \"name\": \"beef\", \"count\": 1}, {\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 1}, {\"label\": \"Tomato\", \"name\": \"tomato1\", \"count\": 1}, {\"label\": \"Creeking Thyme\", \"name\": \"Creeking_Thyme\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vtcafe\", \"vhgeneralstore\"], \"expreq\": 0, \"Reward\": [{\"name\": \"tombchili\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(270,'Milkweed Chicken Soup','food',1,'{\"Text\": \"Milkweed Chicken Soup\", \"Param\": {\"Item\": [{\"label\": \"Milk Weed\", \"name\": \"Milk_Weed\", \"count\": 1}, {\"label\": \"Wild Carrot\", \"name\": \"Wild_Carrot\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}, {\"label\": \"Bird Meat\", \"name\": \"bird\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vtcafe\", \"vhgeneralstore\"], \"expreq\": 0, \"Reward\": [{\"name\": \"milksoup\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(271,'Yarrow and Potato Mash','food',1,'{\"Text\":\"Yarrow and Potato Mash\",\"Param\":{\"Item\":[{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":1},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"yarmash\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(272,'Red sage and garlic roast','food',1,'{\"Text\": \"Red sage and garlic roast\", \"Param\": {\"Item\": [{\"label\": \"Beef\", \"name\": \"beef\", \"count\": 1}, {\"label\": \"Red Sage\", \"name\": \"Red_Sage\", \"count\": 1}, {\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"redgaro\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(273,'Ginseng porridge','food',1,'{\"Text\": \"Ginseng porridge\", \"Param\": {\"Item\": [{\"label\": \"American Ginseng\", \"name\": \"American_Ginseng\", \"count\": 1}, {\"label\": \"sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}, {\"label\": \"Yarrow\", \"name\": \"Yarrow\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"ginpor\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(274,'Minted Berry Pork Fry','food',1,'{\"Text\": \"Minted Berry Pork Fry\", \"Param\": {\"Item\": [{\"label\": \"Pig fat\", \"name\": \"porkfat\", \"count\": 1}, {\"label\": \"Pork\", \"name\": \"pork\", \"count\": 1}, {\"label\": \"Red Raspberry\", \"name\": \"Red_Raspberry\", \"count\": 1}, {\"label\": \"Wintergreen Berry\", \"name\": \"Wintergreen_Berry\", \"count\": 1}, {\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"minbp\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(275,'Country Biscuits with Gravy','food',1,'{\"Text\": \"Country Biscuits with Gravy\", \"Param\": {\"Item\": [{\"label\": \"camp fire biscuits\", \"name\": \"cambis\", \"count\": 1}, {\"label\": \"mushroom gravy\", \"name\": \"mushgravy\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cunbisgrav\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(276,'Venison and mushroom gravy','food',1,'{\"Text\": \"Venison and mushroom gravy\", \"Param\": {\"Item\": [{\"label\": \"Venison\", \"name\": \"venison\", \"count\": 1}, {\"label\": \"mushroom gravy\", \"name\": \"mushgravy\", \"count\": 1}, {\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 1}, {\"label\": \"Creeking Thyme\", \"name\": \"Creeking_Thyme\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"venmush\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(277,'Berry Glazed Game','food',1,'{\"Text\":\"Berry Glazed Game\",\"Param\":{\"Item\":[{\"label\":\"Game Meat\",\"name\":\"game\",\"count\":1},{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Black Currant\",\"name\":\"Black_Currant\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":50,\"Reward\":[{\"name\":\"berglaz\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(278,'Mushroom Gravy','food',1,'{\"Text\":\"Mushroom Gravy\",\"Param\":{\"Item\":[{\"label\":\"Parasol Mushroom\",\"name\":\"Parasol_Mushroom\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"mushgravy\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(279,'Wild Mint Tea','brewing',1,'{\"Text\":\"Wild Mint Tea\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":2},{\"label\":\"Wintergreen Berry\",\"name\":\"Wintergreen_Berry\",\"count\":2}],\"expadd\":1,\"Job\":[\"doctor\"],\"expreq\":0,\"Reward\":[{\"name\":\"wilmite\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(280,'Frontier Stew','food',1,'{\"Text\": \"Frontier Stew\", \"Param\": {\"Item\": [{\"label\": \"Potato\", \"name\": \"potato\", \"count\": 1}, {\"label\": \"Wild Carrot\", \"name\": \"Wild_Carrot\", \"count\": 1}, {\"label\": \"Crows Garlic\", \"name\": \"Crows_Garlic\", \"count\": 1}, {\"label\": \"Creeking Thyme\", \"name\": \"Creeking_Thyme\", \"count\": 1}, {\"label\": \"Game Meat\", \"name\": \"game\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"frostew\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(281,'Fish Chowder','food',1,'{\"Text\":\"Fish Chowder\",\"Param\":{\"Item\":[{\"label\":\"Small Bluegil\",\"name\":\"a_c_fishbluegil_01_sm\",\"count\":1},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":1},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"fischow\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(282,'Crab Root Bake','food',1,'{\"Text\":\"Crab Root Bake\",\"Param\":{\"Item\":[{\"label\":\"Crab\",\"name\":\"crab_c\",\"count\":1},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":1},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":1},{\"label\":\"Oregano\",\"name\":\"Oregano\",\"count\":2},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"crabake\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(283,'Stringy Meat Hash','food',1,'{\"Text\":\"Stringy Meat Hash\",\"Param\":{\"Item\":[{\"label\":\"Stringy Meat\",\"name\":\"stringy\",\"count\":1},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":1},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":1},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":2},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"strinhash\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(284,'Camp Omellete','food',1,'{\"Text\":\"Camp Omellete\",\"Param\":{\"Item\":[{\"label\":\"Parasol Mushroom\",\"name\":\"Parasol_Mushroom\",\"count\":1},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Scrambled Eggs\",\"name\":\"scrambledeggs\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"camole\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(285,'Campfire Biscuit','food',1,'{\"Text\":\"Campfire Biscuit\",\"Param\":{\"Item\":[{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Oleander Sage\",\"name\":\"Oleander_Sage\",\"count\":1},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"bisu\",\"count\":3}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(286,'Plum tart','food',1,'{\"Text\":\"Plum tart\",\"Param\":{\"Item\":[{\"label\":\"Creekplum\",\"name\":\"Creekplum\",\"count\":1},{\"label\":\"sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"English Mace\",\"name\":\"English_Mace\",\"count\":1}],\"expadd\":1,\"Job\":[\"doctor\"],\"expreq\":0,\"Reward\":[{\"name\":\"plutar\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(287,'Crab Cakes','food',1,'{\"Text\":\"Crab Cakes\",\"Param\":{\"Item\":[{\"label\":\"Crab\",\"name\":\"crab_c\",\"count\":1},{\"label\":\"Batter\",\"name\":\"batter\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"cracak\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(288,'Mysterious Key','custom',1,'{\"Text\":\"Mysterious Key\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"String\",\"name\":\"string\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"vampkey\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(289,'Baked Pear','food',1,'{\"Text\":\"Baked Pear\",\"Param\":{\"Item\":[{\"label\":\"Pear\",\"name\":\"pear\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"bakepear\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(290,'Chocolate Banana','food',1,'{\"Text\": \"Chocolate Banana\", \"Param\": {\"Item\": [{\"label\": \"Banana\", \"name\": \"banana\", \"count\": 1}, {\"label\": \"Cocoa\", \"name\": \"cocoa\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"banachoco\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(291,'Fried Banana','food',1,'{\"Text\": \"Fried Banana\", \"Param\": {\"Item\": [{\"label\": \"Banana\", \"name\": \"banana\", \"count\": 1}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 1}, {\"label\": \"Oregano\", \"name\": \"Oregano\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"banafried\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(292,'Banana Bread','food',1,'{\"Text\": \"Banana Bread\", \"Param\": {\"Item\": [{\"label\": \"Banana\", \"name\": \"banana\", \"count\": 1}, {\"label\": \"Bread\", \"name\": \"bread\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"breadbana\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(293,'Blueberry Bread','food',1,'{\"Text\": \"Blueberry Bread\", \"Param\": {\"Item\": [{\"label\": \"Bread\", \"name\": \"bread\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Blue Berry\", \"name\": \"blueberry\", \"count\": 4}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"breadblue\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(294,'Lemon Bread','food',1,'{\"Text\": \"Lemon Bread\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 2}, {\"label\": \"Bread\", \"name\": \"bread\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"breadlemon\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(295,'Orange Bread','food',1,'{\"Text\": \"Orange Bread\", \"Param\": {\"Item\": [{\"label\": \"Orange\", \"name\": \"orange\", \"count\": 2}, {\"label\": \"Bread\", \"name\": \"bread\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"breadorange\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(296,'Blue Berry Bundt Cake','food',1,'{\"Text\": \"Blue Berry Bundt Cake\", \"Param\": {\"Item\": [{\"label\": \"Blue Berry\", \"name\": \"blueberry\", \"count\": 6}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"butter\", \"name\": \"butter\", \"count\": 2}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cakebundblue\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(297,'Mango Cake','food',1,'{\"Text\": \"Mango Cake\", \"Param\": {\"Item\": [{\"label\": \"Milk Cream\", \"name\": \"milkcream\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 2}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Mango\", \"name\": \"mango\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cakemango\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(298,'Strawberry Short Cake','food',1,'{\"Text\": \"Strawberry Short Cake\", \"Param\": {\"Item\": [{\"label\": \"Milk Cream\", \"name\": \"milkcream\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Strawberry\", \"name\": \"strawberry\", \"count\": 2}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cakeshortstraw\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(299,'Lemon Chicken Pasta','food',1,'{\"Text\": \"Lemon Chicken Pasta\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 3}, {\"label\": \"Bird Meat\", \"name\": \"bird\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Oregano\", \"name\": \"Oregano\", \"count\": 1}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"chicklempast\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(300,'Orange Marinated Chicken','food',1,'{\"Text\": \"Orange Marinated Chicken\", \"Param\": {\"Item\": [{\"label\": \"Orange\", \"name\": \"orange\", \"count\": 2}, {\"label\": \"Bird Meat\", \"name\": \"bird\", \"count\": 1}, {\"label\": \"Oregano\", \"name\": \"Oregano\", \"count\": 2}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Butter\", \"name\": \"butter\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"chickorange\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(301,'Orange Cocktail','brewing',1,'{\"Text\": \"Orange Cocktail\", \"Param\": {\"Item\": [{\"label\": \"Orange\", \"name\": \"orange\", \"count\": 2}, {\"label\": \"Alcohol\", \"name\": \"alcohol\", \"count\": 1}, {\"label\": \"Water Bottle\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Honey\", \"name\": \"honey\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cockorange\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(302,'Lemon Cookie','food',1,'{\"Text\": \"Lemon Cookie\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 1}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Egg\", \"name\": \"egg\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"cooklemon\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(303,'Mango Jam','food',1,'{\"Text\": \"Mango Jam\", \"Param\": {\"Item\": [{\"label\": \"Mango\", \"name\": \"mango\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jamango\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(304,'Black Currant Jam','food',1,'{\"Text\": \"Black Currant Jam\", \"Param\": {\"Item\": [{\"label\": \"Black Currant\", \"name\": \"Black_Currant\", \"count\": 4}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jamblackcur\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(305,'Blueberry Jam','food',1,'{\"Text\": \"Blueberry Jam\", \"Param\": {\"Item\": [{\"label\": \"Blueberry\", \"name\": \"blueberry\", \"count\": 4}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jamblue\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(306,'Lemon Jam','food',1,'{\"Text\": \"Lemon Jam\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jamlemon\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(307,'Peach Jam','food',1,'{\"Text\": \"Peach Jam\", \"Param\": {\"Item\": [{\"label\": \"Peach\", \"name\": \"consumable_peach\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jampeach\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(308,'Creek Plum Jam','food',1,'{\"Text\": \"Creek Plum Jam\", \"Param\": {\"Item\": [{\"label\": \"Creekplum\", \"name\": \"Creekplum\", \"count\": 3}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jamplum\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(309,'Raspberry Jam','food',1,'{\"Text\": \"Raspberry Jam\", \"Param\": {\"Item\": [{\"label\": \"Red Raspberry\", \"name\": \"Red_Raspberry\", \"count\": 6}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jamras\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(310,'Strawberry Jam','food',1,'{\"Text\": \"Strawberry Jam\", \"Param\": {\"Item\": [{\"label\": \"Strawberry\", \"name\": \"strawberry\", \"count\": 3}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 2}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"jamstraw\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(311,'Lemonade','brewing',1,'{\"Text\": \"Lemonade\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 2}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"lemonad\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(312,'Mango Lemonade','brewing',1,'{\"Text\": \"Mango Lemonade\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Mango\", \"name\": \"mango\", \"count\": 1}, {\"label\": \"water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"lemonadmang\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(313,'Strawberry Lemonade','brewing',1,'{\"Text\": \"Strawberry Lemonade\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 1}, {\"label\": \"Straberry\", \"name\": \"strawberry\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"lemonadstraw\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(314,'Blueberry Lemonade','brewing',1,'{\"Text\": \"Blueberry Lemonade\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 1}, {\"label\": \"Blueberry\", \"name\": \"blueberry\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"lemondblue\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(315,'Orange Lemonade','brewing',1,'{\"Text\": \"Orange Lemonade\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 1}, {\"label\": \"Orange\", \"name\": \"orange\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"lemondorange\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(316,'Pear Lemonade','brewing',1,'{\"Text\": \"Pear Lemonade\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 1}, {\"label\": \"Pear\", \"name\": \"pear\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"lemondpear\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(317,'Raspberry Lemonade','brewing',1,'{\"Text\": \"Raspberry Lemonade\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 1}, {\"label\": \"Red Raspberry\", \"name\": \"Red_Raspberry\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"lemondras\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(318,'Lemon Martini','brewing',1,'{\"Text\": \"Lemon Martini\", \"Param\": {\"Item\": [{\"label\": \"Lemon\", \"name\": \"lemon\", \"count\": 1}, {\"label\": \"Alcohol\", \"name\": \"alcohol\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"martlemon\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(319,'Blueberry Muffin','food',1,'{\"Text\": \"Blueberry Muffin\", \"Param\": {\"Item\": [{\"label\": \"Blueberry\", \"name\": \"blueberry\", \"count\": 2}, {\"label\": \"Batter\", \"name\": \"batter\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Milk\", \"name\": \"milk\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"muffinblue\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(320,'Orange Juice','brewing',1,'{\"Text\": \"Orange Juice\", \"Param\": {\"Item\": [{\"label\": \"Orange\", \"name\": \"orange\", \"count\": 2}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"orangejuice\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(321,'Pizza','food',1,'{\"Text\": \"Pizza\", \"Param\": {\"Item\": [{\"label\": \"Tomato\", \"name\": \"tomato1\", \"count\": 4}, {\"label\": \"Water\", \"name\": \"water\", \"count\": 1}, {\"label\": \"Salt\", \"name\": \"salt\", \"count\": 2}, {\"label\": \"Oregano\", \"name\": \"Oregano\", \"count\": 2}, {\"label\": \"Bread\", \"name\": \"bread\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"pizza\", \"count\": 1}], \"catagory\": \"food\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(322,'Sugar Strawberry','food',1,'{\"Text\":\"Sugar Strawberry\",\"Param\":{\"Item\":[{\"label\":\"Strawberry\",\"name\":\"strawberry\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1}],\"expadd\":1.5,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"strawsugar\",\"count\":1}],\"catagory\":\"food\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(323,'Burial Oil Perfume','basic',1,'{\"Text\": \"Burial Oil Perfume\", \"Param\": {\"Item\": [{\"label\": \"Oleander Sage\", \"name\": \"Oleander_Sage\", \"count\": 2}, {\"label\": \"Prairie Poppy\", \"name\": \"Prairie_Poppy\", \"count\": 2}, {\"label\": \"Red Sage\", \"name\": \"Red_Sage\", \"count\": 2}, {\"label\": \"Glass Bottle\", \"name\": \"glassbottle\", \"count\": 1}, {\"label\": \"Alcohol\", \"name\": \"alcohol\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"burialoil\", \"count\": 1}], \"catagory\": \"basic\", \"diff\": 3000, \"location\": [\"sdbigsaloon\", \"vtbigsaloon\", \"bwbigsaloon\", \"amsaloon\", \"rdsaloon\", \"vhsaloon\", \"sdsmallsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(324,'Goodbye Liquor','brewing',1,'{\"Text\": \"Goodbye Liquor\", \"Param\": {\"Item\": [{\"label\": \"Black Berry\", \"name\": \"Black_Berry\", \"count\": 3}, {\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 3}, {\"label\": \"Yarrow\", \"name\": \"Yarrow\", \"count\": 1}, {\"label\": \"Alcohol\", \"name\": \"alcohol\", \"count\": 1}], \"expadd\": 1, \"Job\": [\"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"amsaloon\", \"bwbigsaloon\", \"rdsaloon\", \"sdbigsaloon\", \"vhsaloon\", \"vtbigsaloon\", \"sdhotel\"], \"expreq\": 0, \"Reward\": [{\"name\": \"goodbyliquor\", \"count\": 1}], \"catagory\": \"brewing\", \"diff\": 3000, \"location\": [\"sdsmallsaloon\", \"vtsmallsaloon\", \"abdistillery\", \"amdistillery\", \"amsaloon\", \"bwbigsaloon\", \"rdsaloon\", \"sdbigsaloon\", \"vhsaloon\", \"vtbigsaloon\", \"sdhotel\"], \"prop\": 0}, \"Desc\": \"\"}'),(325,'Burial Wraps','basic',1,'{\"Desc\":\"\",\"Param\":{\"expreq\":0,\"Item\":[{\"name\":\"fibers\",\"label\":\"Fibers\",\"count\":2},{\"name\":\"string\",\"label\":\"String\",\"count\":1},{\"name\":\"leather\",\"label\":\"Leather\",\"count\":1},{\"name\":\"wool\",\"label\":\"Wool\",\"count\":1},{\"name\":\"alcohol\",\"label\":\"Alcohol\",\"count\":1}],\"Reward\":[{\"name\":\"burialwraps\",\"label\":\"\",\"count\":1}],\"expadd\":1,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"catagory\":\"basic\",\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"diff\":3000,\"prop\":0,\"Tools\":[{\"name\":\"unique_straightrazor\",\"label\":\"Straight Razor\",\"count\":1}]},\"Text\":\"Burial Wraps\"}'),(326,'Lucky Coin','basic',1,'{\"Text\":\"Lucky Coin\",\"Param\":{\"Item\":[{\"label\":\"Gold Nugget\",\"name\":\"goldnugget\",\"count\":3},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":[\"rdmine\",\"twmine\",\"abmine\",\"bvbounty\"],\"expreq\":0,\"Reward\":[{\"name\":\"luckycoin\",\"count\":1}],\"diff\":3000,\"gradelock\":1,\"catagory\":\"basic\",\"location\":[\"rdmine\",\"twmine\",\"abmine\",\"bvbounty\"],\"prop\":0},\"Desc\":\"\"}'),(327,'Native Tipi','furni',1,'{\"Text\":\"Native Tipi\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Bison Pelt\",\"name\":\"bisons\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":5}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"tipi\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(328,'Dream Catcher','furni',1,'{\"Text\":\"Dream Catcher\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":8},{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":2},{\"label\":\"Peasant feather\",\"name\":\"peasantf\",\"count\":4}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"dreamcatcher\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(329,'Native Pot','furni',1,'{\"Text\":\"Native Pot\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":3},{\"label\":\"Clay\",\"name\":\"clay\",\"count\":4}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativepot\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(330,'Native Basket 1','furni',1,'{\"Text\":\"Native Basket 1\",\"Param\":{\"Item\":[{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":8},{\"label\":\"String\",\"name\":\"string\",\"count\":3},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":1}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativebasket1\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(331,'Native Basket 2','furni',1,'{\"Text\":\"Native Basket 2\",\"Param\":{\"Item\":[{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":12},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativebasket2\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(332,'Native Decor 1','furni',1,'{\"Text\":\"Native Decor 1\",\"Param\":{\"Item\":[{\"label\":\"Rock\",\"name\":\"rock\",\"count\":15},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":3},{\"label\":\"Peasant feather\",\"name\":\"peasantf\",\"count\":7},{\"label\":\"Sheep head\",\"name\":\"sheephead\",\"count\":1}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativeskull\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(333,'Skull Post','furni',1,'{\"Text\":\"Skull Post\",\"Param\":{\"Item\":[{\"label\":\"Rock\",\"name\":\"rock\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4},{\"label\":\"Sheep head\",\"name\":\"sheephead\",\"count\":1}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"skullpost\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(334,'Native Decor Set','furni',1,'{\"Text\":\"Native Decor Set\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":2},{\"label\":\"Pheasant Feather\",\"name\":\"peasantf\",\"count\":5}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativedecor\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(335,'Native Mask','furni',1,'{\"Text\":\"Native Mask\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":4}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativemask\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(336,'Native Arms','furni',1,'{\"Text\":\"Native Arms\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativearms\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(337,'Dead Mans Chair','furni',1,'{\"Text\":\"Dead Mans Chair\",\"Param\":{\"Item\":[{\"label\":\"Wooden Chair\",\"name\":\"wood_chair\",\"count\":1},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Skull Post\",\"name\":\"skullpost\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativeskullchair\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(338,'Native Chair','furni',1,'{\"Text\":\"Native Chair\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativechair\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(339,'Native Wicker Chair','furni',1,'{\"Text\":\"Native Wicker Chair\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":5}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativewickchair\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(340,'Native Bench','furni',1,'{\"Text\":\"Native Bench\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativebench\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(341,'Simple Native Tent','furni',1,'{\"Text\":\"Simple Native Tent\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Bison Pelt\",\"name\":\"bisons\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"simplenativetent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(342,'Native Elk Canvas','furni',1,'{\"Text\":\"Native Elk Canvas\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Elk Antler\",\"name\":\"elkantler\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativeelkcanvas\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(343,'Deer Pelt Native Tent','furni',1,'{\"Text\":\"Deer Pelt Native Tent\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":6},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"deernativetent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(344,'Wolf Pelt Native Tent','furni',1,'{\"Text\":\"Wolf Pelt Native Tent\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Wolf Skin\",\"name\":\"wolfpelt\",\"count\":6},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"wolfnativetent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(345,'Native Platform','furni',1,'{\"Text\":\"Native Platform\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":6},{\"label\":\"String\",\"name\":\"string\",\"count\":2},{\"label\":\"Pronghorn Skin\",\"name\":\"prongs\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativeplatform\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(346,'Native Cooking Structure','furni',1,'{\"Text\":\"Native Cooking Structure\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Moose pelt\",\"name\":\"mooses\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":2},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativesmoker\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(347,'Native Rock Structure','furni',1,'{\"Text\":\"Native Rock Structure\",\"Param\":{\"Item\":[{\"label\":\"Rock\",\"name\":\"rock\",\"count\":20},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":10},{\"label\":\"Fire Wood\",\"name\":\"firewood\",\"count\":5},{\"label\":\"Fiber\",\"name\":\"fibers\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativebloodrock\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(348,'Native Wooden Cage','furni',1,'{\"Text\":\"Native Wooden Cage\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"String\",\"name\":\"string\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":10},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativecage\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(349,'Bow Display','furni',1,'{\"Text\":\"Bow Display\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":1},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":1},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":1},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativebowdisplay\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(350,'Arrow Display','furni',1,'{\"Text\":\"Arrow Display\",\"Param\":{\"Item\":[{\"label\":\"Normal Arrows\",\"name\":\"ammoarrownormal\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":1},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":3},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":1},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":5},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativebowdisplay\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(351,'Native Cooking Pot','furni',1,'{\"Text\":\"Native Cooking Pot\",\"Param\":{\"Item\":[{\"label\":\"Owl Feather\",\"name\":\"owlf\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativecookpot\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(352,'Native Buck Skull','furni',1,'{\"Text\":\"Native Buck Skull\",\"Param\":{\"Item\":[{\"label\":\"Buck Skin\",\"name\":\"bucks\",\"count\":2},{\"label\":\"Buck Antlers\",\"name\":\"buckantler\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativebuckskull\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(353,'Native Leather Stand','furni',1,'{\"Text\":\"Native Leather Stand\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4},{\"label\":\"Bison Pelt\",\"name\":\"bisons\",\"count\":4}],\"expadd\":1,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nativeleatherstand\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(354,'Horse Reviver','basic',0,'{\"Text\":\"Horse Reviver\",\"Param\":{\"Item\":[{\"label\":\"Sap\",\"name\":\"sap\",\"count\":4},{\"label\":\"Black Currant\",\"name\":\"Black_Currant\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":2}],\"expadd\":1,\"Job\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"expreq\":0,\"Reward\":[{\"name\":\"horse_reviver\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"twstable\",\"amstable\",\"bwstable\",\"sbstable\",\"vtstable\",\"rdstable\",\"sdstable\",\"vhstable\",\"smstable\",\"emstable\",\"mfstable\"],\"prop\":0},\"Desc\":\"\"}'),(355,'Wooden Stake','basic',1,'{\"Text\":\"Wooden Stake\",\"Param\":{\"Item\":[{\"label\":\"Wood Board\",\"name\":\"wooden_boards\",\"count\":2},{\"label\":\"Diamond\",\"name\":\"diamond\",\"count\":5},{\"label\":\"Holy Water\",\"name\":\"holywater\",\"count\":1}],\"expadd\":1,\"Job\":[\"bwchurch\",\"vtchurch\",\"rdchurch\",\"sdchurch\"],\"expreq\":0,\"Reward\":[{\"name\":\"stake01\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"bwchurch\",\"vtchurch\",\"rdchurch\",\"sdchurch\"],\"prop\":0},\"Desc\":\"\"}'),(357,'Police Baton','basic',1,'{\"Param\":{\"Tools\":[{\"name\":\"unique_straightrazor\",\"count\":1,\"label\":\"Straight Razor\"}],\"Item\":[{\"name\":\"wooden_boards\",\"count\":2,\"label\":\"Wood Board\"},{\"name\":\"rubber\",\"count\":2,\"label\":\"Rubber\"},{\"name\":\"bolts\",\"count\":2,\"label\":\"Bolt\"},{\"name\":\"leather\",\"count\":2,\"label\":\"Leather\"}],\"diff\":3000,\"catagory\":\"basic\",\"gradelock\":10,\"prop\":0,\"Job\":[\"police\",\"marshal\"],\"expreq\":0,\"Reward\":[{\"name\":\"club01\",\"count\":1,\"label\":\"\"}],\"expadd\":1,\"location\":0},\"Text\":\"Police Baton\",\"Desc\":\"\"}'),(358,'Police Baton (Strap)','basic',1,'{\"Param\":{\"Tools\":[{\"name\":\"unique_straightrazor\",\"count\":1,\"label\":\"Straight Razor\"}],\"Item\":[{\"name\":\"wooden_boards\",\"count\":2,\"label\":\"Wood Board\"},{\"name\":\"rubber\",\"count\":2,\"label\":\"Rubber\"},{\"name\":\"bolts\",\"count\":2,\"label\":\"Bolt\"},{\"name\":\"leather\",\"count\":2,\"label\":\"Leather\"}],\"diff\":3000,\"catagory\":\"basic\",\"gradelock\":4,\"prop\":0,\"Job\":[\"police\",\"marshal\"],\"expreq\":0,\"Reward\":[{\"name\":\"club02\",\"count\":1,\"label\":\"\"}],\"expadd\":1,\"location\":0},\"Text\":\"Police Baton (Strap)\",\"Desc\":\"\"}'),(359,'Executioner Knife','basic',1,'{\"Text\":\"Executioner Knife\",\"Param\":{\"Item\":[{\"label\":\"Wood Board\",\"name\":\"wooden_boards\",\"count\":2},{\"label\":\"Rubber\",\"name\":\"obsidian\",\"count\":16},{\"label\":\"Bolt\",\"name\":\"bolts\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Diamond\",\"name\":\"diamond\",\"count\":10}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":100000,\"Reward\":[{\"name\":\"knife01\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0,\"Tools\":[{\"name\":\"unique_straightrazor\",\"label\":\"Straight Razor\",\"count\":1}]},\"Desc\":\"\"}'),(360,'Apple Cider','custom',1,'{\"Desc\":\"\",\"Text\":\"Apple Cider\",\"Param\":{\"Reward\":[{\"label\":\"\",\"name\":\"UniAppleCider\",\"count\":1}],\"expadd\":1,\"location\":0,\"prop\":0,\"expreq\":0,\"Item\":[{\"label\":\"Apple\",\"name\":\"apple\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":1}],\"diff\":3000,\"Job\":[\"standardtrain\",\"vtcafe\"],\"catagory\":\"custom\"}}'),(361,'Turkey Leg','custom',1,'{\"Text\":\"Turkey Leg\",\"Param\":{\"Item\":[{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Bird Meat\",\"name\":\"bird\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":2}],\"expadd\":1,\"Job\":[\"standardtrain\"],\"expreq\":0,\"Reward\":[{\"name\":\"UniTurkyleg\",\"count\":1}],\"catagory\":\"custom\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(362,'Black Soul Gem','custom',1,'{\"Text\":\"Black Soul Gem\",\"Param\":{\"Item\":[{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"rpblacksoulgem\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(363,'Lesser Soul Gem','custom',1,'{\"Text\":\"Lesser Soul Gem\",\"Param\":{\"Item\":[{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"rplessersoulgem\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(364,'Den Casino Chip','custom',1,'{\"Text\":\"Den Casino Chip\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1},{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"rpdencasinochip\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(365,'Black Powder','custom',1,'{\"Text\":\"Black Powder\",\"Param\":{\"Item\":[{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":2},{\"label\":\"Iron Ore\",\"name\":\"iron\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugblackpowder\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(366,'Lam\'inar Log','custom',1,'{\"Text\":\"Lam\'inar Log\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Deer Heart\",\"name\":\"deerheart\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druglaminarlog\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(367,'Gibellina Cubano','custom',1,'{\"Text\":\"Gibellina Cubano\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugsabatinocubano\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(368,'Human Heart','custom',1,'{\"Text\":\"Human Heart\",\"Param\":{\"Item\":[{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":2},{\"label\":\"Chicken heart\",\"name\":\"chickenheart\",\"count\":2},{\"label\":\"Oregano\",\"name\":\"Oregano\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodhumaneye\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(369,'Human Eye','custom',1,'{\"Text\":\"Human Eye\",\"Param\":{\"Item\":[{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":2},{\"label\":\"Clay\",\"name\":\"clay\",\"count\":2},{\"label\":\"Chicken heart\",\"name\":\"chickenheart\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodhumanheart\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(370,'Devil\'s Grin','custom',1,'{\"Text\":\"Devil\'s Grin\",\"Param\":{\"Item\":[{\"label\":\"Indian_Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdevilsgrin\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(371,'Venison Chili','custom',1,'{\"Text\":\"Venison Chili\",\"Param\":{\"Item\":[{\"label\":\"Venison\",\"name\":\"venison\",\"count\":2},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Wild_Carrot\",\"name\":\"Wild_Carrot\",\"count\":2},{\"label\":\"Beef\",\"name\":\"beef\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodvenisonchili\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(372,'Wobblecock Beer','custom',1,'{\"Text\":\"Wobblecock Beer\",\"Param\":{\"Item\":[{\"label\":\"Hop\",\"name\":\"hop\",\"count\":2},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Water Bottle\",\"name\":\"water\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugwobblecockbeer\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(373,'Shay\'s Chew','custom',1,'{\"Text\":\"Shay\'s Chew\",\"Param\":{\"Item\":[{\"label\":\"Indian Tabacco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugshayschew\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(374,'Blue Magic','custom',1,'{\"Text\":\"Blue Magic\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbluemagic\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(375,'Bastards Breath','custom',1,'{\"Text\":\"Bastards Breath\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":1},{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":1},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":1},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbastardsbreath\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(376,'Silver Cut Cigar','custom',1,'{\"Text\":\"Silver Cut Cigar\",\"Param\":{\"Item\":[{\"label\":\"Indian_Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugsilvercutcigar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(377,'Dirty Dave\'s Lungbuster','custom',1,'{\"Text\":\"Dirty Dave\'s Lungbuster\",\"Param\":{\"expadd\":1,\"uinuqesteam\":[],\"location\":0,\"Job\":0,\"expreq\":0,\"Reward\":[{\"count\":1,\"label\":\"\",\"name\":\"druglungbuster\"}],\"diff\":3000,\"Item\":[{\"count\":2,\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\"},{\"count\":2,\"label\":\"Shell Casing\",\"name\":\"shellcasing\"},{\"count\":1,\"label\":\"Water\",\"name\":\"water\"},{\"count\":2,\"label\":\"Coal\",\"name\":\"coal\"}],\"prop\":0,\"catagory\":\"custom\"},\"Desc\":\"\"}'),(378,'Burger and Fries','custom',1,'{\"Text\":\"Burger and Fries\",\"Param\":{\"Item\":[{\"label\":\"Beef\",\"name\":\"beef\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2},{\"label\":\"Egg\",\"name\":\"egg\",\"count\":1},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodburgerandfries\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(379,'Blue Lagoon','custom',1,'{\"Text\":\"Blue Lagoon\",\"Param\":{\"Item\":[{\"label\":\"Creekplum\",\"name\":\"Creekplum\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodbluelagoon\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(380,'Salty Pickaxe','custom',1,'{\"Text\":\"Salty Pickaxe\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugsaltypickaxe\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(381,'Tangle Stew','custom',1,'{\"Text\":\"Tangle Stew\",\"Param\":{\"Item\":[{\"label\":\"Stringy Meat\",\"name\":\"stringy\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodtanglestew\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(382,'Red Sage','custom',1,'{\"Text\":\"Red Sage\",\"Param\":{\"Item\":[{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":2},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugredsage\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(383,'Saints Communion Bourbon','custom',1,'{\"Text\":\"Saints Communion Bourbon\",\"Param\":{\"Item\":[{\"label\":\"Hop\",\"name\":\"hop\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcommunionbourbon\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(384,'Flaca\'s Crystal Blue','custom',1,'{\"Text\":\"Flaca\'s Crystal Blue\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugflacascrystalblue\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(385,'Sweet Hearts','custom',1,'{\"Text\":\"Sweet Hearts\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Iron Ore\",\"name\":\"iron\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugsweethearts\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(386,'Healthafix','custom',1,'{\"Text\":\"Healthafix\",\"Param\":{\"Item\":[{\"label\":\"Choc Daisy\",\"name\":\"Choc_Daisy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drughealthafix\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(387,'Commander Coffee','custom',1,'{\"Text\":\"Commander Coffee\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Coffee\",\"name\":\"consumable_coffee\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcommandercoffee\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(388,'Filth','custom',1,'{\"Text\":\"Filth\",\"Param\":{\"Item\":[{\"label\":\"Oleander Sage\",\"name\":\"Oleander_Sage\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugfilth\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(389,'Mud Buddies','custom',1,'{\"Text\":\"Mud Buddies\",\"Param\":{\"Item\":[{\"label\":\"Beef\",\"name\":\"beef\",\"count\":1},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Carrot\",\"name\":\"Wild_Carrot\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"water\",\"name\":\"water\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodmudbuddiessnackles\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(390,'Bayou Rock','custom',1,'{\"Text\":\"Bayou Rock\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":1},{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":1},{\"label\":\"Fat\",\"name\":\"Fat\",\"count\":1},{\"label\":\"Bolt\",\"name\":\"bolts\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbayoucrack\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(391,'Devil\'s Lungs','custom',1,'{\"Text\":\"Devil\'s Lungs\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":1},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":1},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdevilslungs\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(392,'Chewable Water','custom',1,'{\"Text\":\"Chewable Water\",\"Param\":{\"Item\":[{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Mutton\",\"name\":\"mutton\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugchewablewater\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(393,'Van Horn Cough Syrup','custom',1,'{\"Text\":\"Van Horn Cough Syrup\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Oleander Sage\",\"name\":\"Oleander_Sage\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugvanhornjuice\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(394,'Iron Root Whisky','custom',1,'{\"Text\":\"Iron Root Whisky\",\"Param\":{\"Item\":[{\"label\":\"Potoato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugironrootwhiskey\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(395,'Bayou Cola','custom',1,'{\"Text\":\"Bayou Cola\",\"Param\":{\"Item\":[{\"label\":\"American Ginseng\",\"name\":\"American_Ginseng\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbayoucola\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(396,'Northern Lights','custom',1,'{\"Text\":\"Northern Lights\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Oleander Sage\",\"name\":\"Oleander_Sage\",\"count\":1},{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugnorthernlights\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(397,'LuLu Juice','custom',1,'{\"Text\":\"LuLu Juice\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":1},{\"label\":\"Peach\",\"name\":\"consumable_peach\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druglulujuice\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(398,'Vial B','custom',1,'{\"Text\":\"Vial B\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugvialb\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(399,'Swamp Stogie','custom',1,'{\"Text\":\"Swamp Stogie\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugswampstogie\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(400,'Bonnie\'s Rose Tonic','custom',1,'{\"Text\":\"Bonnie\'s Rose Tonic\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbonniesrosetonic\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(401,'The Undertaker\'s Kiss','custom',1,'{\"Text\":\"The Undertaker\'s Kiss\",\"Param\":{\"Item\":[{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugundertakerskiss\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(402,'McCormick\'s','custom',1,'{\"Text\":\"McCormick\'s\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugmccormicks\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(403,'Brown Sugar','custom',1,'{\"Text\":\"Brown Sugar\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbrownsugar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(404,'Cold Lead Chew','custom',1,'{\"Text\":\"Cold Lead Chew\",\"Param\":{\"Item\":[{\"label\":\"Indian Tabacco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcoldleadchew\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(405,'Bayou Cigar','custom',1,'{\"Text\":\"Bayou Cigar\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Rolling Paper\",\"name\":\"rollingpaper\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbayoucigar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(406,'Legacy Smackers','custom',1,'{\"Text\":\"Legacy Smackers\",\"Param\":{\"Item\":[{\"label\":\"Prairie_Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druglegacysmackers\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(407,'Red\'s Rage','custom',1,'{\"Text\":\"Red\'s Rage\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugredrage\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(408,'Bee & Leaf Mead','custom',1,'{\"Text\":\"Bee & Leaf Mead\",\"Param\":{\"Item\":[{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodbeeandleafmead\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(409,'Sim\'s Omelette','custom',1,'{\"Text\":\"Sim\'s Omelette\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2},{\"label\":\"Pork\",\"name\":\"pork\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodsimsomelette\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(410,'Honey Cut Skewers','custom',1,'{\"Text\":\"Honey Cut Skewers\",\"Param\":{\"Item\":[{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2},{\"label\":\"Bird Meat\",\"name\":\"bird\",\"count\":2},{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodhoneycutskewers\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(411,'Whitelog Ale','custom',1,'{\"Text\":\"Whitelog Ale\",\"Param\":{\"Item\":[{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Hop\",\"name\":\"hop\",\"count\":1},{\"label\":\"Tea\",\"name\":\"tea\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodwhitelogale\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(412,'Laudanum','custom',1,'{\"Text\":\"Laudanum\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druglaudanum\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(413,'Riviera Rough Cut','custom',1,'{\"Text\":\"Riviera Rough Cut\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugrivieraroughcut\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(414,'Bayou Juice','custom',1,'{\"Text\":\"Bayou Juice\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbayoujuice\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(415,'Donk\'s Last Puff','custom',1,'{\"Text\":\"Donk\'s Last Puff\",\"Param\":{\"Item\":[{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":2},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdonkslastpuff\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(416,'Lee\'s Dragon\'s Dream Opium','custom',1,'{\"Text\":\"Lee\'s Dragon\'s Dream Opium\",\"Param\":{\"Item\":[{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":2},{\"label\":\"Rubber\",\"name\":\"rubber\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdragondream\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(417,'Lee\'s Wonton Noodle Soup','custom',1,'{\"Text\":\"Lee\'s Wonton Noodle Soup\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Venison\",\"name\":\"venison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugleeswonton\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(418,'Flaco Cigar','custom',1,'{\"Text\":\"Flaco Cigar\",\"Desc\":\"\",\"Param\":{\"catagory\":\"custom\",\"uinuqesteam\":[],\"expreq\":0,\"prop\":0,\"diff\":3000,\"Reward\":[{\"label\":\"\",\"name\":\"drugflacocigar\",\"count\":1}],\"expadd\":1,\"Item\":[{\"label\":\"Hop\",\"name\":\"hop\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"Job\":0,\"location\":0}}'),(419,'Blood Moon Smoke','custom',1,'{\"Text\":\"Blood Moon Smoke\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Strawberry\",\"name\":\"strawberry\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbloodmooncigar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(420,'Colton\'s Miracle','custom',1,'{\"Text\":\"Colton\'s Miracle\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcoltonsmiracle\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(421,'Turkey Ass','custom',1,'{\"Text\":\"Turkey Ass\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Bird Meat\",\"name\":\"bird\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugturkeyass\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(422,'Midnight Delight','custom',1,'{\"Text\":\"Midnight Delight\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Blood_Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Iron Ore\",\"name\":\"iron\",\"count\":1},{\"label\":\"Copper Ore\",\"name\":\"copper\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugmidnightdelight\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(423,'Royal Flush','custom',1,'{\"Text\":\"Royal Flush\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Clay\",\"name\":\"clay\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugroyalflush\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(424,'BTB Cigar','custom',1,'{\"Text\":\"BTB Cigar\",\"Param\":{\"Item\":[{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":2},{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbtbcigar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(425,'Death Gum','custom',1,'{\"Text\":\"Death Gum\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdeathgum\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(426,'Bull Moose Blend','custom',1,'{\"Text\":\"Bull Moose Blend\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Iron Ore\",\"name\":\"iron\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbullmooseblend\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(427,'Moon Berry Pie','custom',1,'{\"Text\":\"Moon Berry Pie\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":1},{\"label\":\"Strawberry\",\"name\":\"strawberry\",\"count\":2},{\"label\":\"Lemon\",\"name\":\"lemon\",\"count\":2},{\"label\":\"Blueberry\",\"name\":\"blueberry\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodmoonberrypie\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(428,'Chieftain\'s Peace Pipe','custom',1,'{\"Text\":\"Chieftain\'s Peace Pipe\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Iron Ore\",\"name\":\"iron\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugchieftainspeacepipe\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(429,'Crow Blood','custom',1,'{\"Text\":\"Crow Blood\",\"Param\":{\"Item\":[{\"label\":\"Milkweed\",\"name\":\"Milk_Weed\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcrowblood\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(430,'Bayou Hash','custom',1,'{\"Text\":\"Bayou Hash\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbayouhash\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(431,'Brownsuga Rum','custom',1,'{\"Text\":\"Brownsuga Rum\",\"Param\":{\"Item\":[{\"label\":\"Hemp\",\"name\":\"hemp\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbrownsugarum\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(432,'Cranston\'s Crown Cigar','custom',1,'{\"Text\":\"Cranston\'s Crown Cigar\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Copper Ore\",\"name\":\"copper\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcranstonscrown\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(433,'Hangman\'s Honey','custom',1,'{\"Text\":\"Hangman\'s Honey\",\"Param\":{\"Item\":[{\"label\":\"Milkweed\",\"name\":\"Milk_Weed\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drughangmanshoney\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(434,'Rothschild\'s Cocaine Lemon Drops','custom',1,'{\"Text\":\"Rothschild\'s Cocaine Lemon Drops\",\"Param\":{\"Item\":[{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugrothschilddrops\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(435,'Rothschild\'s Rock Candy','custom',1,'{\"Text\":\"Rothschild\'s Rock Candy\",\"Param\":{\"Item\":[{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugrothschildrockcandy\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(436,'Buckblood Stew','custom',1,'{\"Text\":\"Buckblood Stew\",\"Param\":{\"Item\":[{\"label\":\"Carrot\",\"name\":\"Wild_Carrot\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Venison\",\"name\":\"venison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodbuckbloodstew\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(437,'Dewkie\'s Cannabis','custom',1,'{\"Text\":\"Dewkie\'s Cannabis\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdewkiescannabis\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(438,'Dallas\'s High Protein Stew','custom',1,'{\"Text\":\"Dallas\'s High Protein Stew\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Bird\",\"name\":\"bird\",\"count\":2},{\"label\":\"Big Game Meat\",\"name\":\"biggame\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"fooddallashighprotein\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(439,'Tigrane\'s Roar','custom',1,'{\"Text\":\"Tigrane\'s Roar\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugtigranesroar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(440,'Dwight\'s Doobie','custom',1,'{\"Text\":\"Dwight\'s Doobie\",\"Param\":{\"Item\":[{\"label\":\"Hemp\",\"name\":\"hemp\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdwightsdoobie\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(441,'Cortez Iron Leaf Cigar','custom',1,'{\"Text\":\"Cortez Iron Leaf Cigar\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":1},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcortezironleadcigar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(442,'Spice','custom',1,'{\"Text\":\"Spice\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugspice\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(443,'Chqofa','custom',1,'{\"Text\":\"Chqofa\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugchqofa\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(444,'Timberline Cut','custom',1,'{\"Text\":\"Timberline Cut\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":1},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugtimberlinecut\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(445,'Piece of Candy','custom',1,'{\"Text\":\"Piece of Candy\",\"Param\":{\"Item\":[{\"label\":\"Red Raspberry\",\"name\":\"Red_Raspberry\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugpieceofcandy\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(446,'Bandit\'s Booster','custom',1,'{\"Text\":\"Bandit\'s Booster\",\"Param\":{\"Item\":[{\"label\":\"American Ginseng\",\"name\":\"American_Ginseng\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbanditsboost\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(447,'Flaco\'s Shine','custom',1,'{\"Text\":\"Flaco\'s Shine\",\"Desc\":\"\",\"Param\":{\"catagory\":\"custom\",\"uinuqesteam\":[],\"expreq\":0,\"location\":0,\"diff\":3000,\"Reward\":[{\"label\":\"\",\"name\":\"drugflacosshine\",\"count\":1}],\"expadd\":1,\"Item\":[{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"Job\":0,\"prop\":0}}'),(448,'Hot Chocolate','custom',1,'{\"Text\":\"Hot Chocolate\",\"Param\":{\"Item\":[{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drughotchocolate\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(449,'Captain\'s Stash Carribean Rum','custom',1,'{\"Text\":\"Captain\'s Stash Carribean Rum\",\"Param\":{\"Item\":[{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":3},{\"label\":\"Gold Nugget\",\"name\":\"goldnugget\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodcaptainsrum\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(450,'Golden Stogie','custom',1,'{\"Text\":\"Golden Stogie\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":1},{\"label\":\"Gold Nugget\",\"name\":\"goldnugget\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druggoldenstogie\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(451,'Black Baron Noble Smoke','custom',1,'{\"Text\":\"Black Baron Noble Smoke\",\"Param\":{\"Item\":[{\"label\":\"Wintergreen Berry\",\"name\":\"Wintergreen_Berry\",\"count\":2},{\"label\":\"Iron Ore\",\"name\":\"iron\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugblackbaronboblesmoke\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(452,'Black Baron Boss Sauce','custom',1,'{\"Text\":\"Black Baron Boss Sauce\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugblackbaronbosssauce\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(453,'Harley\'s Healthy Swig','custom',1,'{\"Text\":\"Harley\'s Healthy Swig\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugharleyshealthyswig\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(454,'Legacy Cowboy Killer','custom',1,'{\"Text\":\"Legacy Cowboy Killer\",\"Param\":{\"Item\":[{\"label\":\"Black Currant\",\"name\":\"Black_Currant\",\"count\":2},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druglegacycowboykiller\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(455,'Dajne\'s Wrangler\'s Cut','custom',1,'{\"Text\":\"Dajne\'s Wrangler\'s Cut\",\"Param\":{\"Item\":[{\"label\":\"Indian Tabacco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdajneswranglerscut\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(456,'Cross Juice','custom',1,'{\"Text\":\"Cross Juice\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcrossjuice\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(457,'Gravelight','custom',1,'{\"Text\":\"Gravelight\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druggravelight\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(458,'Comp Juice','custom',1,'{\"Text\":\"Comp Juice\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcompjuice\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(459,'Dajne\'s Sweet Leaf','custom',1,'{\"Text\":\"Dajne\'s Sweet Leaf\",\"Param\":{\"Item\":[{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdajnessweetleaf\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(460,'Petal Pusher','custom',1,'{\"Text\":\"Petal Pusher\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugpetalpusher\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(461,'Dirty Dave\'s Dine N Dash','custom',1,'{\"Text\":\"Dirty Dave\'s Dine N Dash\",\"Param\":{\"Item\":[{\"label\":\"Beef\",\"name\":\"beef\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2},{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"fooddirtydavesdinendash\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(462,'Dragon\'s Breath','custom',1,'{\"Text\":\"Dragon\'s Breath\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdragonsbreath\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(463,'Crux Cineris','custom',1,'{\"Text\":\"Crux Cineris\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcruxcineris\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(464,'Crux Invicta','custom',1,'{\"Text\":\"Crux Invicta\",\"Param\":{\"Item\":[{\"label\":\"Blood Flowery\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcruxinvicta\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(465,'Crux Nocturna','custom',1,'{\"Text\":\"Crux Nocturna\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Milkcream\",\"name\":\"milkcream\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodcruxnocturna\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(466,'Crux Sacra','custom',1,'{\"Text\":\"Crux Sacra\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcruxsacra\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(467,'Crux Sanguinis','custom',1,'{\"Text\":\"Crux Sanguinis\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodcruxsanguinis\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(468,'Giggle Juice','custom',1,'{\"Text\":\"Giggle Juice\",\"Param\":{\"Item\":[{\"label\":\"Black Currant\",\"name\":\"Black_Currant\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druggigglejuice\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(469,'Medical Munchies','custom',1,'{\"Text\":\"Medical Munchies\",\"Param\":{\"Item\":[{\"label\":\"Wintergreen Berry\",\"name\":\"Wintergreen_Berry\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Egg\",\"name\":\"egg\",\"count\":1},{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugmedicalmunchies\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(470,'Psychedelic Mushroom','custom',1,'{\"Text\":\"Psychedelic Mushroom\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Strawberry\",\"name\":\"strawberry\",\"count\":1},{\"label\":\"Parasol Mushroom\",\"name\":\"Parasol_Mushroom\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugpsychedelicmushroom\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(471,'Glacier Frost','custom',1,'{\"Text\":\"Glacier Frost\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Gold Nugget\",\"name\":\"goldnugget\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugglacierfrost\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(472,'Cross Cigar','custom',1,'{\"Text\":\"Cross Cigar\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcrosscigar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(473,'Bam\'s White Crystals','custom',1,'{\"Text\":\"Bam\'s White Crystals\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbamswhitecrystals\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(474,'Mr. Lee\'s Eggroll','custom',1,'{\"Text\":\"Mr. Lee\'s Eggroll\",\"Param\":{\"Item\":[{\"label\":\"American Ginseng\",\"name\":\"American_Ginseng\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Egg\",\"name\":\"egg\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugmrleeseggroll\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(475,'Tommy\'s Hard Tack Candy','custom',1,'{\"Text\":\"Tommy\'s Hard Tack Candy\",\"Param\":{\"Item\":[{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Hemp\",\"name\":\"hemp\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugtommyshardtackcandy\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(476,'Runapocko Resolve','custom',1,'{\"Text\":\"Runapocko Resolve\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugrunapockoresolve\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(477,'Swamp Juice','custom',1,'{\"Text\":\"Swamp Juice\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugswampjuice\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(478,'Shrouded Edge','custom',1,'{\"Text\":\"Shrouded Edge\",\"Desc\":\"\",\"Param\":{\"uinuqesteam\":[],\"uinuqe\":[],\"Job\":0,\"expreq\":0,\"diff\":3000,\"location\":0,\"Reward\":[{\"name\":\"drugshroudededge\",\"count\":1,\"label\":\"\"}],\"prop\":0,\"expadd\":1,\"catagory\":\"custom\",\"Item\":[{\"name\":\"Prairie_Poppy\",\"count\":2,\"label\":\"Prairie Poppy\"},{\"name\":\"Indian_Tobbaco\",\"count\":2,\"label\":\"Shell Casing\"},{\"name\":\"water\",\"count\":1,\"label\":\"Water\"},{\"name\":\"coal\",\"count\":2,\"label\":\"Coal\"}]}}'),(479,'Riviera Crowned Supper','custom',1,'{\"Text\":\"Riviera Crowned Supper\",\"Param\":{\"Item\":[{\"label\":\"Beef\",\"name\":\"beef\",\"count\":1},{\"label\":\"Oregano\",\"name\":\"Oregano\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodrivieracrownedsupper\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(480,'Vitality Tonic','custom',1,'{\"Text\":\"Vitality Tonic\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugvitalitytonic\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(481,'Feyre\'s Serum','custom',1,'{\"Text\":\"Feyre\'s Serum\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugfeyresserum\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(482,'Vito\'s Italian Cigar','custom',1,'{\"Text\":\"Vito\'s Italian Cigar\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":1},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugvitositaliancigar\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(483,'Vito\'s Chewing Tobacco','custom',1,'{\"Text\":\"Vito\'s Chewing Tobacco\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugvitoschewingtobacco\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(484,'Lucii\'s Lucky Chews','custom',1,'{\"Text\":\"Lucii\'s Lucky Chews\",\"Param\":{\"Item\":[{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Animal Fat\",\"name\":\"Fat\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Strawberry\",\"name\":\"strawberry\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugluciisluckychews\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(485,'Dead Man\'s Pour','custom',1,'{\"Text\":\"Dead Man\'s Pour\",\"Param\":{\"Item\":[{\"label\":\"MilkWeed\",\"name\":\"Milk_Weed\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdeadmanspour\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(486,'Fried Chicken Butts','custom',1,'{\"Text\":\"Fried Chicken Butts\",\"Param\":{\"Item\":[{\"label\":\"Bird Meat\",\"name\":\"bird\",\"count\":1},{\"label\":\"Milkweed\",\"name\":\"Milk_Weed\",\"count\":2},{\"label\":\"Oleander Sage\",\"name\":\"Oleander_Sage\",\"count\":2},{\"label\":\"Garlic\",\"name\":\"Crows_Garlic\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodfriedchickenbutts\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(487,'Silas\'s Lemontea','custom',1,'{\"Text\":\"Silas\'s Lemontea\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Tea\",\"name\":\"tea\",\"count\":2},{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":2},{\"label\":\"Peach\",\"name\":\"consumable_peach\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodsilasslemontea\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(488,'LaCroix XI','custom',1,'{\"Text\":\"LaCroix XI\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":2},{\"label\":\"Vodka\",\"name\":\"vodka\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"druglacroixxi\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(489,'Creole Daube','custom',1,'{\"Text\":\"Creole Daube\",\"Param\":{\"Item\":[{\"label\":\"Big Game Meat\",\"name\":\"biggame\",\"count\":1},{\"label\":\"Oregano\",\"name\":\"Oregano\",\"count\":2},{\"label\":\"Carrot\",\"name\":\"Wild_Carrot\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodcreoledaube\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(490,'Lee\'s Milk Tea','custom',1,'{\"Text\":\"Lee\'s Milk Tea\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodleesmilktea\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(491,'Bam\'s Rubies','custom',1,'{\"Text\":\"Bam\'s Rubies\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbamsrubies\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(492,'Dr. Sanchez Coke Elixer','custom',1,'{\"Text\":\"Dr. Sanchez Coke Elixer\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Coyotee Fang\",\"name\":\"coyotef\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdrsanchezcokeelixer\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(493,'Dudio Double Puff','custom',1,'{\"Text\":\"Dudio Double Puff\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugdudiodoublepuff\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(494,'McCarthy\'s Rocks','custom',1,'{\"Text\":\"McCarthy\'s Rocks\",\"Param\":{\"Item\":[{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":1},{\"label\":\"Yarrow\",\"name\":\"Yarrow\",\"count\":1},{\"label\":\"Nitrite\",\"name\":\"nitrite\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugmccarthysrocks\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(495,'Bayou Spliff','custom',1,'{\"Text\":\"Bayou Spliff\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":2},{\"label\":\"Shell Casing\",\"name\":\"shellcasing\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbayouspliff\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(496,'Final Prayer','custom',1,'{\"Text\":\"Final Prayer\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugfinalprayer\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(497,'PoitÃ­n','custom',1,'{\"Text\":\"PoitÃ­n\",\"Param\":{\"Item\":[{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugpoitin\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(498,'Phenoxymethylpenicillin','custom',1,'{\"Text\":\"Phenoxymethylpenicillin\",\"Param\":{\"Item\":[{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":2},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugphenoxymethylpenicillin\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(499,'Expired Can of Beans','custom',1,'{\"Text\":\"Expired Can of Beans\",\"Param\":{\"Item\":[{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Glassbottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodexpiredbeans\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(500,'Succubliss Potion','custom',1,'{\"Text\":\"Succubliss Potion\",\"Param\":{\"Item\":[{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugsuccublisspotion\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(501,'Reaper\'s Ripper','custom',1,'{\"Text\":\"Reaper\'s Ripper\",\"Param\":{\"Item\":[{\"label\":\"Hemp\",\"name\":\"hemp\",\"count\":2},{\"label\":\"Whisky\",\"name\":\"whisky\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugreapersripper\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(502,'McCarthys\' Full English','custom',1,'{\"Text\":\"McCarthys\' Full English\",\"Param\":{\"Item\":[{\"label\":\"Venison\",\"name\":\"venison\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodmccarthysfullenglish\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(503,'McCarthy\'s Cuppa','custom',1,'{\"Text\":\"McCarthy\'s Cuppa\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodmccarthyscuppa\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(504,'Tahiti\'s Mangos','custom',1,'{\"Text\":\"Tahiti\'s Mangos\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugtahitismangos\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(505,'Shadow Leaf','custom',1,'{\"Text\":\"Shadow Leaf\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugshadowleaf\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(506,'Al\'s Ashes','custom',1,'{\"Text\":\"Al\'s Ashes\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugalsashes\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(507,'You\'ve Been Dunn Cigar','custom',1,'{\"Text\":\"You\'ve Been Dunn Cigar\",\"Param\":{\"Item\":[{\"label\":\"Potato\",\"name\":\"potato\",\"count\":1},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":1},{\"label\":\"Gold Nugget\",\"name\":\"goldnugget\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugyouvebeendone\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(508,'Lee\'s Speedy Elixir','custom',1,'{\"Text\":\"Lee\'s Speedy Elixir\",\"Param\":{\"Item\":[{\"label\":\"Parasol Mushroom\",\"name\":\"Parasol_Mushroom\",\"count\":1},{\"label\":\"Coffee Beans\",\"name\":\"coffeebeans\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugleesspeedyhealth\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(509,'Lee\'s Healthy Elixir','custom',1,'{\"Text\":\"Lee\'s Healthy Elixir\",\"Param\":{\"Item\":[{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":1},{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":1},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugleeshealthyelixir\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(510,'Bayou Burst','custom',1,'{\"Text\":\"Bayou Burst\",\"Param\":{\"Item\":[{\"label\":\"Apple\",\"name\":\"apple\",\"count\":2},{\"label\":\"Red Raspberry\",\"name\":\"Red_Raspberry\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodbayouwater\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(511,'Bam\'s Burners','custom',1,'{\"Text\":\"Bam\'s Burners\",\"Param\":{\"Item\":[{\"label\":\"Blood_Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":1},{\"label\":\"Cigar\",\"name\":\"cigar\",\"count\":1},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2},{\"label\":\"Snake Venom\",\"name\":\"Snake_Poison\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugbamsburners\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(512,'Annie\'s Hot Pocket Pie','custom',1,'{\"Text\":\"Annie\'s Hot Pocket Pie\",\"Param\":{\"Item\":[{\"label\":\"Venison\",\"name\":\"venison\",\"count\":2},{\"label\":\"Wild_Carrot\",\"name\":\"Wild_Carrot\",\"count\":2},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodannieshotpocketpie\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(513,'Kat Tea Time','custom',1,'{\"Text\":\"Kat Tea Time\",\"Param\":{\"Item\":[{\"label\":\"Wintergreen Berry\",\"name\":\"Wintergreen_Berry\",\"count\":2},{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":2},{\"label\":\"Tea Leaf\",\"name\":\"tealeaf\",\"count\":1},{\"label\":\"Apple\",\"name\":\"apple\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodkatteatime\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(514,'Calling Card','custom',1,'{\"Text\":\"Calling Card\",\"Param\":{\"Item\":[{\"label\":\"Roling Paper\",\"name\":\"rollingpaper\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"rpitemcallingcard\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(515,'Invitation','custom',1,'{\"Text\":\"Invitation\",\"Param\":{\"Item\":[{\"label\":\"Roling Paper\",\"name\":\"rollingpaper\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"rpiteminvitation\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(516,'Ryder Lee\'s Rabbit Stew','custom',1,'{\"Text\":\"Ryder Lee\'s Rabbit Stew\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Game Meat\",\"name\":\"game\",\"count\":2},{\"label\":\"Wild Carrot\",\"name\":\"Wild_Carrot\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodryderleesrabbitstew\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(517,'Fletcher\'s Rocks','custom',1,'{\"Text\":\"Fletcher\'s Rocks\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugfletchersdrug\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(518,'Grilled Cheese & Tomato Soup','custom',1,'{\"Text\":\"Grilled Cheese & Tomato Soup\",\"Param\":{\"Item\":[{\"label\":\"Egg\",\"name\":\"egg\",\"count\":2},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":2},{\"label\":\"Tomato\",\"name\":\"tomato1\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Oregano\",\"name\":\"Oregano\",\"count\":1}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodgrilledcheesetomatosoup\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(519,'Uncle Eric\'s English Breakfast','custom',1,'{\"Text\":\"Uncle Eric\'s English Breakfast\",\"Param\":{\"Item\":[{\"label\":\"Venison\",\"name\":\"venison\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":2},{\"label\":\"Potato\",\"name\":\"potato\",\"count\":2},{\"label\":\"Parasol Mushroom\",\"name\":\"Parasol_Mushroom\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"fooduncleericsenglish\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(520,'McDougles Pikey Elixir','custom',1,'{\"Text\":\"McDougles Pikey Elixir\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":1},{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":1},{\"label\":\"Whisky\",\"name\":\"whisky\",\"count\":1},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugmcdouglesppikeyelixir\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(521,'Crystal Skull','custom',1,'{\"Text\":\"Crystal Skull\",\"Param\":{\"Item\":[{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":2},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"drugcrystalskull\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(522,'Trailblazer Bites','custom',1,'{\"Text\":\"Trailblazer Bites\",\"Param\":{\"Item\":[{\"label\":\"Venison\",\"name\":\"venison\",\"count\":1},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":2},{\"label\":\"Lemon\",\"name\":\"lemon\",\"count\":2},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodtrailblazerbites\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(523,'Lee\'s Honey Coffee','custom',1,'{\"Text\":\"Lee\'s Honey Coffee\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Coffee Beans\",\"name\":\"coffeebeans\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodleeshoneycoffee\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(524,'Lee\'s Apple Pie','custom',1,'{\"Text\":\"Lee\'s Apple Pie\",\"Param\":{\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2},{\"label\":\"Pulp\",\"name\":\"pulp\",\"count\":2},{\"label\":\"Apple\",\"name\":\"apple\",\"count\":2}],\"expadd\":1,\"Job\":0,\"expreq\":0,\"Reward\":[{\"name\":\"foodleesapplepie\",\"count\":1}],\"diff\":3000,\"catagory\":\"custom\",\"location\":0,\"uinuqesteam\":[],\"prop\":0},\"Desc\":\"\"}'),(525,'Valuable Loot Crate','basic',1,'{\"Text\":\"Valuable Loot Crate\",\"Param\":{\"Item\":[{\"label\":\"Small Bag of Cash\",\"name\":\"moneybag_small\",\"count\":5},{\"label\":\"Medium Bag of Cash\",\"name\":\"moneybag_medium\",\"count\":5},{\"label\":\"Large Bag of Cash\",\"name\":\"moneybag_large\",\"count\":5},{\"label\":\"Stolen Goods\",\"name\":\"stolen_goods\",\"count\":5},{\"label\":\"Diamond\",\"name\":\"diamond\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":25},{\"label\":\"Acid\",\"name\":\"acid\",\"count\":4}],\"expadd\":5,\"Job\":[\"fence\"],\"expreq\":0,\"Reward\":[{\"name\":\"valubox\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(526,'Meteor Shard','furni',1,'{\"Text\":\"Meteor Shard\",\"Param\":{\"Item\":[{\"label\":\"Obsidian\",\"name\":\"obsidian\",\"count\":10}],\"expadd\":5,\"Job\":[\"fence\"],\"expreq\":0,\"Reward\":[{\"name\":\"mete\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(527,'Poker Table Set','furni',1,'{\"Text\":\"Poker Table Set\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":5},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":10},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10}],\"expadd\":2,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"pokerset\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3500,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(528,'Collector Tent','furni',1,'{\"Text\":\"Collector Tent\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":5}],\"expadd\":2,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"decortent3\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3500,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(529,'Mountain Torch','furni',1,'{\"Text\":\"Mountain Torch\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":70},{\"label\":\"Fire Wood\",\"name\":\"firewood\",\"count\":25},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":25},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"String\",\"name\":\"string\",\"count\":15},{\"label\":\"Legendary Fox pelt\",\"name\":\"legfoxskin\",\"count\":2}],\"expadd\":0.5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"bigtor\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(530,'Standing Torch','furni',1,'{\"Text\":\"Standing Torch\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":0.5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"stantor\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(531,'Small Med Box','furni',1,'{\"Text\":\"Small Med Box\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":2},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":2}],\"expadd\":1,\"Job\":[\"pharmacist\",\"doctor\"],\"expreq\":0,\"Reward\":[{\"name\":\"smolmed\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(532,'Flower Coffin','furni',1,'{\"Text\":\"Flower Coffin\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Flower Arrangements\",\"name\":\"flowerarrangement\",\"count\":1}],\"expadd\":1,\"Job\":[\"sdundertaker\",\"rdunderatker\",\"sbundertaker\"],\"expreq\":0,\"Reward\":[{\"name\":\"flocof\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(533,'Single Candle','furni',1,'{\"Text\":\"Single Candle\",\"Param\":{\"Item\":[{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":3}],\"expadd\":1,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"sincan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(534,'Collector Box','furni',1,'{\"Text\":\"Collector Box\",\"Param\":{\"Item\":[{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":3},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":20},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Blue Paint\",\"name\":\"bluepaint\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"colbox\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(535,'Train Map','furni',1,'{\"Text\":\"Train Map\",\"Param\":{\"Item\":[{\"label\":\"Paper\",\"name\":\"paper\",\"count\":5},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":1}],\"expadd\":5,\"Job\":[\"standardtrain\"],\"expreq\":0,\"Reward\":[{\"name\":\"traima\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(536,'Candle Pile','furni',1,'{\"Text\":\"Candle Pile\",\"Param\":{\"Item\":[{\"label\":\"Wax\",\"name\":\"wax\",\"count\":5},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"canpi\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(537,'Small Skull Post','furni',1,'{\"Text\":\"Small Skull Post\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1},{\"label\":\"String\",\"name\":\"string\",\"count\":3},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":5},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":4}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"minskulpo\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(538,'Marked Skull','furni',1,'{\"Text\":\"Marked Skull\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":3}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"predsku1\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(539,'Ritual Skull','furni',1,'{\"Text\":\"Ritual Skull\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":1},{\"label\":\"Prairie Poppy\",\"name\":\"Prairie_Poppy\",\"count\":3}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"predsku2\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(540,'Scavenger Skull','furni',1,'{\"Text\":\"Scavenger Skull\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":1},{\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\",\"count\":3}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"predsku3\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(541,'Death Skull','furni',1,'{\"Text\":\"Death Skull\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":3}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"predsku4\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(542,'Lawn Chair','furni',1,'{\"Text\":\"Lawn Chair\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Leather\",\"name\":\"leather\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"lawcha\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(543,'Folding Chair','furni',1,'{\"Text\":\"Folding Chair\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"nails\",\"name\":\"nails\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"folcha\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(544,'Blanket Folding Chair','furni',1,'{\"Text\":\"Blanket Folding Chair\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":9},{\"label\":\"nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"folchaclo\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(545,'Rotating Desk Chair','furni',1,'{\"Text\":\"Rotating Desk Chair\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":7},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":9},{\"label\":\"nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"deschai\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(546,'Steel Bed','furni',1,'{\"Text\":\"Steel Bed\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":5},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":8},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"rebed\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(547,'Native Chandelier','furni',1,'{\"Text\":\"Native Chandelier\",\"Param\":{\"Item\":[{\"label\":\"Elk Antler\",\"name\":\"elkantler\",\"count\":8},{\"label\":\"String\",\"name\":\"string\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":8}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nachan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(548,'Naturalist Table','furni',1,'{\"Text\":\"Naturalist Table\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":2},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"natab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(549,'Night Stalker Mask','furni',1,'{\"Text\":\"Night Stalker Mask\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":3},{\"label\":\"Sheep head\",\"name\":\"sheephead\",\"count\":1},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":4},{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"nigmas\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(550,'Wood Cloth Covered Table','furni',1,'{\"Text\":\"Wood Cloth Covered Table\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"clotab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(551,'Wooden Stool','furni',1,'{\"Text\":\"Wooden Stool\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"stoo\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(552,'Native Log Bed','furni',1,'{\"Text\":\"Native Log Bed\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":6},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":2},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":15}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"navbed\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(553,'Royal Bed','furni',1,'{\"Text\":\"Royal Bed\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":18},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":20},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"roybed\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wood_plane\",\"label\":\"Wood Plane\",\"count\":1}]},\"Desc\":\"\"}'),(554,'Fancy Wood Bed','furni',1,'{\"Text\":\"Fancy Wood Bed\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":14},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":15},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"covbed\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(555,'Small Fancy Bed','furni',1,'{\"Text\":\"Small Fancy Bed\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":12},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"smolcovbed\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(556,'Iron Bed','furni',1,'{\"Text\":\"Iron Bed\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":8},{\"label\":\"Hard Wood Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":8},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"irobed\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(557,'Ladder','furni',1,'{\"Text\":\"Ladder\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":15}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"lad\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(558,'Decay Bench','furni',1,'{\"Text\":\"Decay Bench\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":14},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"worben\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(559,'Coated Bench','furni',1,'{\"Text\":\"Coated Bench\",\"Param\":{\"Item\":[{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"freben\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(560,'Black Iron Bench','furni',1,'{\"Text\":\"Black Iron Bench\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":15},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"iroblaben\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(561,'White Iron Bench','furni',1,'{\"Text\":\"White Iron Bench\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":16},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":8},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"irowhiben\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(562,'Piano Stool','furni',1,'{\"Text\":\"Piano Stool\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":8},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":6},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"pistoo\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(563,'Double Cabinet','furni',1,'{\"Text\":\"Double Cabinet\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":9},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":16},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":6},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"dblcab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(564,'Black & Brown Dresser','furni',1,'{\"Text\":\"Black & Brown Dresser\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"smalblacab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(565,'Glass Cabinet','furni',1,'{\"Text\":\"Glass Cabinet\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":18},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"glacab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(566,'Fancy Candle','furni',1,'{\"Text\":\"Fancy Candle\",\"Param\":{\"Item\":[{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":3},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":8},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":2}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"tripcan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(567,'Cup Candle','furni',1,'{\"Text\":\"Cup Candle\",\"Param\":{\"Item\":[{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":1},{\"label\":\"Honey\",\"name\":\"honey\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"smolcan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(568,'Bottle Candle','furni',1,'{\"Text\":\"Bottle Candle\",\"Param\":{\"Item\":[{\"label\":\"Water Bottle\",\"name\":\"water\",\"count\":1},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":1},{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":1}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"botcan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(569,'Hanging Iron Lantern','furni',1,'{\"Text\":\"Hanging Iron Lantern\",\"Param\":{\"Item\":[{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":6},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"boxcan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(570,'Iron Stand Candle','furni',1,'{\"Text\":\"Iron Stand Candle\",\"Param\":{\"Item\":[{\"label\":\"Wax\",\"name\":\"wax\",\"count\":1},{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":2},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":3},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"irocan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(571,'Mine Cart','furni',1,'{\"Text\":\"Mine Cart\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":15},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":15}],\"expadd\":5,\"Job\":[\"rdmine\",\"twmine\",\"abmine\",\"bvbounty\"],\"expreq\":0,\"Reward\":[{\"name\":\"mincart\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"rdmine\",\"twmine\",\"abmine\",\"bvbounty\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(572,'Black Wood Chair','furni',1,'{\"Text\":\"Black Wood Chair\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":8},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"blachar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(573,'Linen Chair','furni',1,'{\"Text\":\"Linen Chair\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":7},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"nails\",\"name\":\"nails\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"silchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(574,'Gold Linen Chair','furni',1,'{\"Text\":\"Gold Linen Chair\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":7},{\"label\":\"nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"golchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(575,'Red Linen Chair','furni',1,'{\"Text\":\"Red Linen Chair\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":7},{\"label\":\"nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"rechar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(576,'Black Carved Chair','furni',1,'{\"Text\":\"Black Carved Chair\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":1},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":4},{\"label\":\"nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"blaroychar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(577,'Tall Boy Chair','furni',1,'{\"Text\":\"Tall Boy Chair\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":9},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":9},{\"label\":\"nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"grechar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(578,'Northman Tent','furni',1,'{\"Text\":\"Northman Tent\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":5},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":5},{\"label\":\"Elk Pelt\",\"name\":\"elks\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"nortent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(579,'Trader Tent','furni',1,'{\"Text\":\"Trader Tent\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":5},{\"label\":\"Elk Pelt\",\"name\":\"elks\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"tent2\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(580,'Scavenger Tent','furni',1,'{\"Text\":\"Scavenger Tent\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"scavtent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(581,'Swamp Tent','furni',1,'{\"Text\":\"Swamp Tent\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Ram Pelt\",\"name\":\"rams\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":3},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"bustent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(582,'Mulch Tent','furni',1,'{\"Text\":\"Mulch Tent\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":3},{\"label\":\"Ram Pelt\",\"name\":\"rams\",\"count\":2},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"miltent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(583,'Stick Tent','furni',1,'{\"Text\":\"Stick Tent\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":3},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":4},{\"label\":\"Elk Pelt\",\"name\":\"elks\",\"count\":3},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"stiktent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(584,'Tin Tent','furni',1,'{\"Text\":\"Tin Tent\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":11},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Bolt\",\"name\":\"bolts\",\"count\":10},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":9}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"tintent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(585,'Big Man Tent','furni',1,'{\"Text\":\"Big Man Tent\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":10},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":20},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":15}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"biggtent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(586,'Posse Trader Tent','furni',1,'{\"Text\":\"Posse Trader Tent\",\"Param\":{\"Item\":[{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"postratent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(587,'Mounted Trader Tent','furni',1,'{\"Text\":\"Mounted Trader Tent\",\"Param\":{\"Item\":[{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":7},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"mountratent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(588,'Camping Trader Tent','furni',1,'{\"Text\":\"Camping Trader Tent\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":5},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"camtrtent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(589,'Small Bounty Tent','furni',1,'{\"Text\":\"Small Bounty Tent\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Deer pelt\",\"name\":\"deerskin\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"smolbout\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(590,'Tanner Tent','furni',1,'{\"Text\":\"Tanner Tent\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Coyote Skin\",\"name\":\"coyotes\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"tanntent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(591,'Private Piano','furni',1,'{\"Text\":\"Private Piano\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":20},{\"label\":\"String\",\"name\":\"string\",\"count\":15},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":20},{\"label\":\"Boar Tusk\",\"name\":\"boarmusk\",\"count\":10},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"pripia\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(592,'Carvis Piano','furni',1,'{\"Text\":\"Carvis Piano\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":20},{\"label\":\"String\",\"name\":\"string\",\"count\":15},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":20},{\"label\":\"Cow Horn\",\"name\":\"cowh\",\"count\":10},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"carpia\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(593,'Jolly Jacks Trunk','furni',1,'{\"Text\":\"Jolly Jacks Trunk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":25},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":35},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":15},{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"jollytrunk\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(594,'Wheeler Co Trunk','furni',1,'{\"Text\":\"Wheeler Co Trunk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":25},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":35},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":15},{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"wheeltrunk\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(595,'Cornwall Trunk','furni',1,'{\"Text\":\"Cornwall Trunk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":25},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":35},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":15},{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"corntrunk\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(596,'Small Vault','furni',1,'{\"Text\":\"Small Vault\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":25},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":30},{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":5},{\"label\":\"Pure\",\"name\":\"pure\",\"count\":5}],\"expadd\":5,\"Job\":[\"fence\"],\"expreq\":0,\"Reward\":[{\"name\":\"Smolvau\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(597,'Tall Vault','furni',1,'{\"Text\":\"Tall Vault\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":35},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":35},{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":8},{\"label\":\"Pure\",\"name\":\"pure\",\"count\":8}],\"expadd\":5,\"Job\":[\"fence\"],\"expreq\":0,\"Reward\":[{\"name\":\"bigvau\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(598,'Police Case','furni',1,'{\"Text\":\"Police Case\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Leather\",\"name\":\"leather\",\"count\":10},{\"label\":\"Wool\",\"name\":\"wool\",\"count\":8},{\"label\":\"Bolt\",\"name\":\"bolts\",\"count\":20}],\"expadd\":5,\"Job\":[\"police\",\"marshal\"],\"expreq\":0,\"Reward\":[{\"name\":\"polcase\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(599,'Sugar Sack','furni',1,'{\"Text\": \"Sugar Sack\", \"Param\": {\"Item\": [{\"label\": \"Sugar\", \"name\": \"sugar\", \"count\": 1}, {\"label\": \"Leather\", \"name\": \"leather\", \"count\": 2}, {\"label\": \"String\", \"name\": \"string\", \"count\": 4}, {\"label\": \"Fibers\", \"name\": \"fibers\", \"count\": 5}], \"expadd\": 5, \"Job\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"expreq\": 0, \"Reward\": [{\"name\": \"sugarsak\", \"count\": 1}], \"catagory\": \"furni\", \"diff\": 3000, \"location\": [\"sdgeneralstore\", \"rdgeneralstore\", \"vtgeneralstore\", \"abgeneralstore\", \"amgeneralstore\", \"bwgeneralstore\", \"vhgeneralstore\", \"vtcafe\"], \"prop\": 0}, \"Desc\": \"\"}'),(600,'Book Case','furni',1,'{\"Text\":\"Book Case\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":9},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"clotboocase\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(601,'Windsor Chair','furni',1,'{\"Text\":\"Windsor Chair\",\"Param\":{\"Item\":[{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":9}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"winsochar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(602,'Private Desk Mirror','furni',1,'{\"Text\":\"Private Desk Mirror\",\"Param\":{\"Item\":[{\"label\":\"Mirror\",\"name\":\"mirror\",\"count\":1},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"desmirro\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(603,'Wood Trunk','furni',1,'{\"Text\":\"Wood Trunk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"pirotrunk\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(604,'Iron Trunk','furni',1,'{\"Text\":\"Iron Trunk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":9},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":6},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"irotrunk\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(605,'Grain Trunk','furni',1,'{\"Text\":\"Grain Trunk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":7},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"grantrunk\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(606,'Upholstery Chair','furni',1,'{\"Text\":\"Upholstery Chair\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":7},{\"label\":\"nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"theaspecchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(607,'Pelt Table','furni',1,'{\"Text\":\"Pelt Table\",\"Param\":{\"Item\":[{\"label\":\"Cow Skin\",\"name\":\"cows\",\"count\":3},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"peltab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(608,'Savage Table','furni',1,'{\"Text\":\"Savage Table\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":3},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"savtable\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(609,'Private Painted Table','furni',0,'{\"Text\":\"Private Painted Table\",\"Param\":{\"Item\":[{\"label\":\"Venison\",\"name\":\"venison\",\"count\":1}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"carpaitabb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(610,'Private Black Iron Table','furni',1,'{\"Text\":\"Private Black Iron Table\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":15},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"bliirotab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(611,'Visceral Gold Table','furni',1,'{\"Text\":\"Visceral Gold Table\",\"Param\":{\"Item\":[{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":3},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":2},{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":2},{\"label\":\"Blue Paint\",\"name\":\"bluepaint\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"flowirontab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(612,'Visceral Stone Table','furni',1,'{\"Text\":\"Visceral Stone Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Rock\",\"name\":\"rock\",\"count\":15}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"porcetabb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(613,'Visceral Royal Table','furni',1,'{\"Text\":\"Visceral Royal Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":15}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"goldflowtab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(614,'Carvis Coffee Table','furni',1,'{\"Text\":\"Carvis Coffee Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":9},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Fox Skin\",\"name\":\"foxskin\",\"count\":3},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"carcoftab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(615,'Carvis Round Cloth Table','furni',1,'{\"Text\":\"Carvis Round Cloth Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":15},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"rounclotabb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(616,'Carvis Cloth Table','furni',1,'{\"Text\":\"Carvis Cloth Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":20},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":18},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":12},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"worclotab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(617,'Cutting Table','furni',1,'{\"Text\":\"Cutting Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"cuttabb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(618,'Nit Cover Table','furni',1,'{\"Text\":\"Nit Cover Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":16},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"nittab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(619,'Simple Table','furni',1,'{\"Text\":\"Simple Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"simtabb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(620,'Private Animal Table','furni',1,'{\"Text\":\"Private Animal Table\",\"Param\":{\"Item\":[{\"label\":\"Legendary Cougar pelt\",\"name\":\"legcougars\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"String\",\"name\":\"string\",\"count\":5},{\"label\":\"Wood Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"theatabb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(621,'Private Cloth Table','furni',1,'{\"Text\":\"Private Cloth Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":15},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":14},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":13},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"privtab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(622,'Carvis Table','furni',1,'{\"Text\":\"Carvis Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":18},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"cartabb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(623,'Folding Stool','furni',1,'{\"Text\":\"Folding Stool\",\"Param\":{\"Item\":[{\"label\":\"Softwood\",\"name\":\"wood\",\"count\":1},{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":3},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"folstoo\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(624,'Horn Stool','furni',1,'{\"Text\":\"Horn Stool\",\"Param\":{\"Item\":[{\"label\":\"Angus Bull horn\",\"name\":\"oxhorn\",\"count\":4},{\"label\":\"Leather\",\"name\":\"leather\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":6}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"stoonavi\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(625,'Hunted Skull','furni',1,'{\"Text\":\"Hunted Skull\",\"Param\":{\"Item\":[{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":2},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":4},{\"label\":\"Cow Horn\",\"name\":\"cowh\",\"count\":4},{\"label\":\"Clay\",\"name\":\"clay\",\"count\":4}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"hearo\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(626,'Painted Dream Catcher','furni',1,'{\"Text\":\"Painted Dream Catcher\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":8},{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":2},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"pindreanavi\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(627,'Bull Skull Post','furni',1,'{\"Text\":\"Bull Skull Post\",\"Param\":{\"Item\":[{\"label\":\"Bison horn\",\"name\":\"bisonhorn\",\"count\":4},{\"label\":\"Leather\",\"name\":\"leather\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":10},{\"label\":\"Sheep head\",\"name\":\"sheephead\",\"count\":1}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"ramposnavi\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(628,'Warning Post','furni',1,'{\"Text\":\"Warning Post\",\"Param\":{\"Item\":[{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":5},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Clay\",\"name\":\"clay\",\"count\":8}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"spoonavi\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(629,'Skull Stick','furni',1,'{\"Text\":\"Skull Stick\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":3},{\"label\":\"String\",\"name\":\"string\",\"count\":2},{\"label\":\"Clay\",\"name\":\"clay\",\"count\":4}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"stiskul\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(630,'Visceral Side Table','furni',1,'{\"Text\":\"Visceral Side Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"cussitab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(631,'Iron Coffee Table','furni',1,'{\"Text\":\"Iron Coffee Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"irocoftab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(632,'Top Side Table','furni',1,'{\"Text\":\"Top Side Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"finesitab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(633,'Painted Side Table','furni',1,'{\"Text\":\"Painted Side Table\",\"Param\":{\"Item\":[{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":2},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":2},{\"label\":\"Blue Paint\",\"name\":\"bluepaint\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"painsitab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(634,'Visceral Cut Couch','furni',1,'{\"Text\":\"Visceral Cut Couch\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":2},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"incocouc\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(635,'Painted Couch','furni',1,'{\"Text\":\"Painted Couch\",\"Param\":{\"Item\":[{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":1},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":1},{\"label\":\"Blue Paint\",\"name\":\"bluepaint\",\"count\":1},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"paincouc\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(636,'Visceral Pillow Couch','furni',1,'{\"Text\":\"Visceral Pillow Couch\",\"Param\":{\"Item\":[{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"ivnocouc\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(637,'Theater Chest','furni',1,'{\"Text\":\"Theater Chest\",\"Param\":{\"Item\":[{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":3},{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":3},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"theaches\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(638,'Rubble Bag','furni',1,'{\"Text\":\"Rubble Bag\",\"Param\":{\"Item\":[{\"label\":\"Rock\",\"name\":\"rock\",\"count\":10},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"Fiber\",\"name\":\"fibers\",\"count\":10}],\"expadd\":5,\"Job\":[\"rdmine\",\"twmine\",\"abmine\",\"bvbounty\"],\"expreq\":0,\"Reward\":[{\"name\":\"rubbag\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"rdmine\",\"twmine\",\"abmine\",\"bvbounty\"],\"prop\":0},\"Desc\":\"\"}'),(639,'Private Table','furni',1,'{\"Text\":\"Private Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"privvtab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(640,'Private Lounge Chair','furni',1,'{\"Text\":\"Private Lounge Chair\",\"Param\":{\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":3},{\"label\":\"nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"privvchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(641,'Pedestal','furni',1,'{\"Text\":\"Pedestal\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":1}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"peda\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(642,'Chained Pedastal','furni',1,'{\"Text\":\"Chained Pedastal\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":1},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"chaipeda\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(643,'Standing Out House','furni',1,'{\"Text\":\"Standing Out House\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"stanouthou\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(644,'Hidden Out House','furni',1,'{\"Text\":\"Hidden Out House\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"rooouthou\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(645,'Fine Out House','furni',1,'{\"Text\":\"Fine Out House\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"finouthou\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(646,'Open Out House','furni',1,'{\"Text\":\"Open Out House\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"opeouthou\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(647,'Phonograph','furni',1,'{\"Text\":\"Phonograph\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":15},{\"label\":\"Wooden Boards\",\"name\":\"wooden_boards\",\"count\":5}],\"expadd\":5,\"Job\":[\"standardtrain\"],\"expreq\":0,\"Reward\":[{\"name\":\"grama\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(648,'Clock','furni',1,'{\"Text\":\"Clock\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":2},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":6}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"clock\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(649,'Grandfather Clock','furni',1,'{\"Text\":\"Grandfather Clock\",\"Param\":{\"Item\":[{\"label\":\"Clock\",\"name\":\"clock\",\"count\":1},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"Cougar Tooth\",\"name\":\"cougarf\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"granclo\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(650,'Imported Cabinet','furni',1,'{\"Text\":\"Imported Cabinet\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"chincabb\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(651,'Gold Mirror','furni',1,'{\"Text\":\"Gold Mirror\",\"Param\":{\"Item\":[{\"label\":\"Mirror\",\"name\":\"mirror\",\"count\":2},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":1},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"golmirr\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(652,'Gold Candle','furni',1,'{\"Text\":\"Gold Candle\",\"Param\":{\"Item\":[{\"label\":\"Gold Bar\",\"name\":\"goldbar\",\"count\":1},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"bracan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0},\"Desc\":\"\"}'),(653,'Foster Lamp','furni',1,'{\"Text\":\"Foster Lamp\",\"Param\":{\"Item\":[{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":6},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":2},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"foostalam\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(654,'Dwell Lamp','furni',1,'{\"Text\":\"Dwell Lamp\",\"Param\":{\"Item\":[{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":2},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"benmelam\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(655,'Iron Exterior Lamp','furni',1,'{\"Text\":\"Iron Exterior Lamp\",\"Param\":{\"Item\":[{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":7},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":9}],\"expadd\":5,\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"expreq\":0,\"Reward\":[{\"name\":\"exterlam\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(656,'Triumphant Lamp','furni',1,'{\"Text\":\"Triumphant Lamp\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"trilam\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(657,'Divine Lamp','furni',1,'{\"Text\":\"Divine Lamp\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":2},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"divlam\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(658,'Kitchen Hutch','furni',1,'{\"Text\":\"Kitchen Hutch\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"kithuthh\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(659,'Secretary Hutch','furni',1,'{\"Text\":\"Secretary Hutch\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"secrhuthh\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(660,'Large Hutch','furni',1,'{\"Text\":\"Large Hutch\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":6},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"larhuthh\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(661,'Hutch','furni',1,'{\"Text\":\"Hutch\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":7},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"huthh\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(662,'Severed Skull','furni',1,'{\"Text\":\"Severed Skull\",\"Param\":{\"Item\":[{\"label\":\"Skull\",\"name\":\"skull\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":2},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1}],\"expadd\":5,\"Job\":[\"sdundertaker\",\"rdunderatker\",\"sbundertaker\"],\"expreq\":0,\"Reward\":[{\"name\":\"halfsku\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(663,'Human Skull','furni',1,'{\"Text\":\"Human Skull\",\"Param\":{\"Item\":[{\"label\":\"Skull\",\"name\":\"skull\",\"count\":1},{\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\",\"count\":4},{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1}],\"expadd\":5,\"Job\":[\"sdundertaker\",\"rdunderatker\",\"sbundertaker\"],\"expreq\":0,\"Reward\":[{\"name\":\"humsku\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(664,'Out House','furni',1,'{\"Text\":\"Out House\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":20},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"ouhou\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\",\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"handsaw\",\"label\":\"Handsaw\",\"count\":1}]},\"Desc\":\"\"}'),(665,'Animal Coat Rack','furni',1,'{\"Text\":\"Animal Coat Rack\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"bearstan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(666,'Green Lantern','furni',1,'{\"Text\":\"Green Lantern\",\"Param\":{\"Item\":[{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":6},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":8},{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"grenlan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(667,'Bone Dream Catcher','furni',1,'{\"Text\":\"Bone Dream Catcher\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":3},{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":2},{\"label\":\"Sheep head\",\"name\":\"sheephead\",\"count\":1}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"hangbon\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(668,'Carved Mirror','furni',1,'{\"Text\":\"Carved Mirror\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Mirror\",\"name\":\"mirror\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"tremir\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(669,'Skull Group Post','furni',1,'{\"Text\":\"Skull Group Post\",\"Param\":{\"Item\":[{\"label\":\"Rock\",\"name\":\"rock\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":3},{\"label\":\"Sheep head\",\"name\":\"sheephead\",\"count\":1}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"gruskull\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(670,'Sentinel Desk','furni',1,'{\"Text\":\"Sentinel Desk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"gilmir\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(671,'Ironclad Desk','furni',1,'{\"Text\":\"Ironclad Desk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"irodes\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(672,'Outrider Desk','furni',1,'{\"Text\":\"Outrider Desk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"outdes\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(673,'Executive Row Desk','furni',1,'{\"Text\":\"Executive Row Desk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"exedes\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(674,'Nightfall Desk','furni',1,'{\"Text\":\"Nightfall Desk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"nides\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(675,'Atlas Desk','furni',1,'{\"Text\":\"Atlas Desk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"detdes\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(676,'Organize Desk','furni',1,'{\"Text\":\"Organize Desk\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":12},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"stordes\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(677,'Corner Cabinet','furni',1,'{\"Text\":\"Corner Cabinet\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":1},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"nails\",\"name\":\"nails\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"corncubcab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(678,'Coffee Table','furni',1,'{\"Text\":\"Coffee Table\",\"Param\":{\"Item\":[{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":7},{\"label\":\"nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Hard Wood Board\",\"name\":\"wooden_boards\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"cofetab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(679,'Flat Wood Bed','furni',1,'{\"Text\":\"Flat Wood Bed\",\"Param\":{\"Item\":[{\"label\":\"Timber\",\"name\":\"timber\",\"count\":6},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"flawobed\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(680,'Crate Table','furni',1,'{\"Text\":\"Crate Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"cratabl\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(681,'Square Table','furni',1,'{\"Text\":\"Square Table\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Blue Paint\",\"name\":\"bluepaint\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"blackytable\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(682,'Upholstery Bench','furni',1,'{\"Text\":\"Upholstery Bench\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10},{\"label\":\"Wool\",\"name\":\"wool\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"darkcouc\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(683,'Upholstery Couch','furni',1,'{\"Text\":\"Upholstery Couch\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":8},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":8},{\"label\":\"Wool\",\"name\":\"wool\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"uphcouc\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(684,'Cot','furni',1,'{\"Text\":\"Cot\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Leather\",\"name\":\"leather\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"cotsle\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(685,'Small Engraved Dresser','furni',1,'{\"Text\":\"Small Engraved Dresser\",\"Param\":{\"Item\":[{\"label\":\"Nails\",\"name\":\"nails\",\"count\":1},{\"label\":\"Hard Wood Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"smolirodres\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(686,'Iron Handle Dresser','furni',1,'{\"Text\":\"Iron Handle Dresser\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":2},{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"commdres\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(687,'Commode Dresser','furni',1,'{\"Text\":\"Commode Dresser\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":15},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"comodres\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(688,'Sealed Coffin','furni',1,'{\"Text\":\"Sealed Coffin\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"sdundertaker\",\"rdunderatker\",\"sbundertaker\"],\"expreq\":0,\"Reward\":[{\"name\":\"lincof\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(689,'Ridged Coffin','furni',1,'{\"Text\":\"Ridged Coffin\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2}],\"expadd\":5,\"Job\":[\"sdundertaker\",\"rdunderatker\",\"sbundertaker\"],\"expreq\":0,\"Reward\":[{\"name\":\"ridcof\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(690,'Cut Coffin','furni',1,'{\"Text\":\"Cut Coffin\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":8}],\"expadd\":5,\"Job\":[\"sdundertaker\",\"rdunderatker\",\"sbundertaker\"],\"expreq\":0,\"Reward\":[{\"name\":\"nocof\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(691,'Coat Rack','furni',1,'{\"Text\":\"Coat Rack\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":1}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"wierco\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(692,'Coat Rack Shelf','furni',1,'{\"Text\":\"Coat Rack Shelf\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":2},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"coarashel\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(693,'Open Shelf Case','furni',1,'{\"Text\":\"Open Shelf Case\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"clongdres\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(694,'Imported Box Lantern','furni',1,'{\"Text\":\"Imported Box Lantern\",\"Param\":{\"Item\":[{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":2},{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"chinboxlan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(695,'Imported Long Lantern','furni',1,'{\"Text\":\"Imported Long Lantern\",\"Param\":{\"Item\":[{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":3},{\"label\":\"String\",\"name\":\"string\",\"count\":2},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":2},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":4}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"chinbilan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(696,'Imported Round Lantern','furni',1,'{\"Text\":\"Imported Round Lantern\",\"Param\":{\"Item\":[{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":3},{\"label\":\"String\",\"name\":\"string\",\"count\":2},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":1},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":3}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"chinlan\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(697,'Fine Cabinet','furni',1,'{\"Text\":\"Fine Cabinet\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":4},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":1}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"chincab\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(698,'Native Chest','furni',1,'{\"Text\":\"Native Chest\",\"Param\":{\"Item\":[{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":3},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":12},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":5}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"navches\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(699,'Black Chest','furni',1,'{\"Text\":\"Black Chest\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"blaches\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(700,'Candle Chandelier','furni',1,'{\"Text\":\"Candle Chandelier\",\"Param\":{\"Item\":[{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":10},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":8},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"canchand\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(701,'Diamond Chandelier','furni',1,'{\"Text\":\"Diamond Chandelier\",\"Param\":{\"Item\":[{\"label\":\"Diamond\",\"name\":\"diamond\",\"count\":10},{\"label\":\"Bolts\",\"name\":\"bolts\",\"count\":10},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":8},{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":10},{\"label\":\"Coal\",\"name\":\"coal\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"diachand\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(702,'Chamber Pot','furni',1,'{\"Text\":\"Chamber Pot\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":8},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"shitter\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(703,'Wicker Chair','furni',1,'{\"Text\":\"Wicker Chair\",\"Param\":{\"Item\":[{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":4},{\"label\":\"String\",\"name\":\"string\",\"count\":8},{\"label\":\"Softwood\",\"name\":\"wood\",\"count\":8}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"wickchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(704,'Tall Standing Chair','furni',1,'{\"Text\":\"Tall Standing Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":6},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"tallstnchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(705,'Small Wood Log Chair','furni',1,'{\"Text\":\"Small Wood Log Chair\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":4},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":2},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":1}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"stiklogchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(706,'Wood Log Chair','furni',1,'{\"Text\":\"Wood Log Chair\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":6},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":3}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"ruswechar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(707,'Rustic Rocking Chair','furni',1,'{\"Text\":\"Rustic Rocking Chair\",\"Param\":{\"Item\":[{\"label\":\"String\",\"name\":\"string\",\"count\":6},{\"label\":\"Sap\",\"name\":\"sap\",\"count\":4},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":3},{\"label\":\"Wicker\",\"name\":\"wicker\",\"count\":5}],\"expadd\":5,\"Job\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"expreq\":0,\"Reward\":[{\"name\":\"wicrochar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vttribe\",\"bvtribe\",\"bwtribe\"],\"prop\":0},\"Desc\":\"\"}'),(708,'Serious Swivel Chair','furni',1,'{\"Text\":\"Serious Swivel Chair\",\"Param\":{\"Item\":[{\"label\":\"Bolt\",\"name\":\"bolts\",\"count\":2},{\"label\":\"Rubber\",\"name\":\"rubber\",\"count\":2},{\"label\":\"Wood Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":3},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"specschar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0,\"Tools\":[{\"name\":\"wrench\",\"label\":\"Wrench\",\"count\":1}]},\"Desc\":\"\"}'),(709,'Serious Chair','furni',1,'{\"Text\":\"Serious Chair\",\"Param\":{\"Item\":[{\"label\":\"Wood Board\",\"name\":\"wooden_boards\",\"count\":6},{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"specchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(710,'Decay Folding Chair','furni',1,'{\"Text\":\"Decay Folding Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":3},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":6}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"whifolchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(711,'Commander Chair','furni',1,'{\"Text\":\"Commander Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":10}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"eagroychar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(712,'Center Piece Chair','furni',1,'{\"Text\":\"Center Piece Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":15},{\"label\":\"Leather\",\"name\":\"leather\",\"count\":14}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"centchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(713,'Brown Comfy Chair','furni',1,'{\"Text\":\"Brown Comfy Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"Green Paint\",\"name\":\"greenpaint\",\"count\":1},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":1}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"browcomchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(714,'Pink Comfy Chair','furni',1,'{\"Text\":\"Pink Comfy Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":5},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":5},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":1}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"pincomchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(715,'Red Comfy Chair','furni',1,'{\"Text\":\"Red Comfy Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":6},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"Red Paint\",\"name\":\"redpaint\",\"count\":2}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"redcomchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(716,'Grey Comfy Chair','furni',1,'{\"Text\":\"Grey Comfy Chair\",\"Param\":{\"Item\":[{\"label\":\"Soft Wood\",\"name\":\"wood\",\"count\":6},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":6},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":12},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":1}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"greycomchar\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(717,'Croft Tent','furni',1,'{\"Text\":\"Croft Tent\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":4},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":5},{\"label\":\"String\",\"name\":\"string\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"mpleetent\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(718,'Open Coffin','furni',1,'{\"Text\":\"Open Coffin\",\"Param\":{\"Item\":[{\"label\":\"Wooden Board\",\"name\":\"wooden_boards\",\"count\":10},{\"label\":\"Nails\",\"name\":\"nails\",\"count\":10},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":2},{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":8},{\"label\":\"Wool\",\"name\":\"wool\",\"count\":6}],\"expadd\":5,\"Job\":[\"sdundertaker\",\"rdunderatker\",\"sbundertaker\"],\"expreq\":0,\"Reward\":[{\"name\":\"opocof\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":0,\"prop\":0},\"Desc\":\"\"}'),(719,'Visceral Piano','furni',1,'{\"Text\":\"Visceral Piano\",\"Param\":{\"Item\":[{\"label\":\"Iron Bar\",\"name\":\"ironbar\",\"count\":20},{\"label\":\"Copper Bar\",\"name\":\"copper_bar\",\"count\":20},{\"label\":\"String\",\"name\":\"string\",\"count\":15},{\"label\":\"Timber\",\"name\":\"timber\",\"count\":8},{\"label\":\"Hard Wood\",\"name\":\"hwood\",\"count\":20},{\"label\":\"Boar Tusk\",\"name\":\"boarmusk\",\"count\":10},{\"label\":\"Varnish\",\"name\":\"varnish\",\"count\":5}],\"expadd\":5,\"Job\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"expreq\":0,\"Reward\":[{\"name\":\"vispia\",\"count\":1}],\"catagory\":\"furni\",\"diff\":3000,\"location\":[\"vtlumber\",\"bwlumber\",\"sdlumber\",\"sblumber\"],\"prop\":0},\"Desc\":\"\"}'),(720,'Red Paint','basic',1,'{\"Desc\":\"\",\"Param\":{\"Reward\":[{\"count\":1,\"label\":\"\",\"name\":\"redpaint\"},{\"count\":1,\"label\":\"Empty Watering Jug\",\"name\":\"wateringcan_empty\"}],\"expreq\":0,\"prop\":0,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"diff\":3000,\"expadd\":1,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"Item\":[{\"count\":3,\"label\":\"Blood Flower\",\"name\":\"Blood_Flower\"},{\"count\":3,\"label\":\"Red Sage\",\"name\":\"Red_Sage\"},{\"count\":1,\"label\":\"Watering Can\",\"name\":\"wateringcan\"}],\"catagory\":\"basic\"},\"Text\":\"Red Paint\"}'),(721,'Green Paint','basic',1,'{\"Desc\":\"\",\"Param\":{\"Reward\":[{\"count\":1,\"label\":\"\",\"name\":\"greenpaint\"},{\"count\":1,\"label\":\"Empty Watering Jug\",\"name\":\"wateringcan_empty\"}],\"expreq\":0,\"prop\":0,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"diff\":3000,\"expadd\":1,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"Item\":[{\"count\":3,\"label\":\"Wintergreen Berry\",\"name\":\"Wintergreen_Berry\"},{\"count\":3,\"label\":\"Yarrow\",\"name\":\"Yarrow\"},{\"count\":1,\"label\":\"Watering Can\",\"name\":\"wateringcan\"}],\"catagory\":\"basic\"},\"Text\":\"Green Paint\"}'),(722,'Blue Paint','basic',1,'{\"Desc\":\"\",\"Param\":{\"Reward\":[{\"count\":1,\"label\":\"\",\"name\":\"bluepaint\"},{\"count\":1,\"label\":\"Empty Watering Jug\",\"name\":\"wateringcan_empty\"}],\"expreq\":0,\"prop\":0,\"Job\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"diff\":3000,\"expadd\":1,\"location\":[\"bwtailor\",\"sdtailor\",\"amtailor\",\"emtailor\",\"vttailor\"],\"Item\":[{\"count\":3,\"label\":\"Milk Weed\",\"name\":\"Milk_Weed\"},{\"count\":3,\"label\":\"Creekplum\",\"name\":\"Creekplum\"},{\"count\":1,\"label\":\"Watering Can\",\"name\":\"wateringcan\"}],\"catagory\":\"basic\"},\"Text\":\"Blue Paint\"}'),(723,'Popcorn','food',1,'{\"Text\":\"Popcorn\",\"Param\":{\"Item\":[{\"label\":\"Corn\",\"name\":\"corn\",\"count\":1},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"popo\",\"count\":1}],\"catagory\":\"food\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(724,'Popcorn With Butter','food',1,'{\"Text\":\"Popcorn With Butter\",\"Param\":{\"Item\":[{\"label\":\"Corn\",\"name\":\"corn\",\"count\":1},{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1},{\"label\":\"Salt\",\"name\":\"salt\",\"count\":2},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":2}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"popob\",\"count\":1}],\"catagory\":\"food\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(725,'Peppermint Sticks','food',1,'{\"Text\":\"Peppermint Sticks\",\"Param\":{\"Item\":[{\"label\":\"Wild Mint\",\"name\":\"Wild_Mint\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":3}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"pepsti\",\"count\":1}],\"catagory\":\"food\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(726,'Rock Candy','food',1,'{\"Text\":\"Rock Candy\",\"Param\":{\"Item\":[{\"label\":\"Red Sage\",\"name\":\"Red_Sage\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":3}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"rocan\",\"count\":1}],\"catagory\":\"food\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(727,'Toffee','food',1,'{\"Text\":\"Toffee\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":3}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"tof\",\"count\":1}],\"catagory\":\"food\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(728,'Hot Chocolate','brewing',1,'{\"Text\":\"Hot Chocolate\",\"Param\":{\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Milk Cream\",\"name\":\"milkcream\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"hochoc\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(729,'Champagne','brewing',1,'{\"Text\":\"Champagne\",\"Param\":{\"Item\":[{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Black Berry\",\"name\":\"Black_Berry\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"champe\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(730,'Sherry','brewing',1,'{\"Text\":\"Sherry\",\"Param\":{\"Item\":[{\"label\":\"Alcohol\",\"name\":\"alcohol\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":2},{\"label\":\"Red Raspberry\",\"name\":\"Red_Raspberry\",\"count\":2},{\"label\":\"Glass Bottle\",\"name\":\"glassbottle\",\"count\":1}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"sher\",\"count\":1}],\"catagory\":\"brewing\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(731,'Theatre Ticket','basic',1,'{\"Text\":\"Theatre Ticket\",\"Param\":{\"Item\":[{\"label\":\"Paper\",\"name\":\"paper\",\"count\":1}],\"expadd\":1,\"Job\":[\"sdtheatre\"],\"expreq\":0,\"Reward\":[{\"name\":\"playticket\",\"count\":1}],\"catagory\":\"basic\",\"diff\":2500,\"location\":[\"sdtheatre\"],\"prop\":0},\"Desc\":\"\"}'),(732,'Wild West Root Beer','food',1,'{\"Text\": \"Wild West Root Beer\", \"Desc\": \" Ice cold and refreshing root beer made by pure ingredients.\", \"Param\": {\"Item\": [{\"name\": \"sugar\", \"label\": \"Sugar\", \"count\": 2}, {\"name\": \"water\", \"label\": \"Water\", \"count\": 2}], \"diff\": 3000, \"prop\": 0, \"location\": 0, \"Reward\": [{\"name\": \"wild_west_root_beer\", \"label\": \"Wild West Root Beer\", \"count\": 1}], \"catagory\": \"food\", \"expreq\": 0, \"Job\": [\"vtbigsaloon\", \"amsaloon\", \"bwbigsaloon\", \"rdsaloon\", \"sdbigsaloon\", \"sdsmallsaloon\", \"vhsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"expadd\": 0}}'),(733,'Steak and Mashers','food',1,'{\"Text\": \"Steak and Mashers\", \"Desc\": \"Pan seared steak cooked with butter and thyme and a side of buttery mashed potatoes.\", \"Param\": {\"Item\": [{\"name\": \"steak\", \"label\": \"Steak\", \"count\": 1}, {\"name\": \"potato\", \"label\": \"Potato\", \"count\": 1}, {\"name\": \"butter\", \"label\": \"Butter\", \"count\": 1}], \"Job\": [\"vtbigsaloon\", \"amsaloon\", \"bwbigsaloon\", \"rdsaloon\", \"sdbigsaloon\", \"sdsmallsaloon\", \"vhsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0, \"location\": 0, \"Reward\": [{\"name\": \"steak_and_mashers\", \"label\": \"Steak and Mashers\", \"count\": 1}], \"diff\": 3000, \"expreq\": 0, \"catagory\": \"food\", \"expadd\": 2}}'),(734,'Chicken and Gravy','food',1,'{\"Text\": \"Chicken and Gravy\", \"Desc\": \"Grilled chicken with a nice glaze and topped with creamy chicken gravy.\", \"Param\": {\"Item\": [{\"name\": \"bird\", \"label\": \"Bird Meat\", \"count\": 1}, {\"name\": \"water\", \"label\": \"Water\", \"count\": 1}, {\"name\": \"flour\", \"label\": \"Flour\", \"count\": 1}, {\"name\": \"salt\", \"label\": \"Salt\", \"count\": 1}], \"Job\": [\"vtbigsaloon\", \"amsaloon\", \"bwbigsaloon\", \"rdsaloon\", \"sdbigsaloon\", \"sdsmallsaloon\", \"vhsaloon\", \"vtsmallsaloon\", \"sdhotel\"], \"prop\": 0, \"location\": 0, \"Reward\": [{\"name\": \"chicken_and_gravy\", \"label\": \"Chicken and Gravy\", \"count\": 1}], \"diff\": 3000, \"expreq\": 0, \"catagory\": \"food\", \"expadd\": 2}}'),(735,'Rosebloom Cigar','medical',1,'{\"Desc\":\"A finely hand-rolled cigar made from rich, aged tobacco and finished with a delicate touch of rose.\",\"Param\":{\"Reward\":[{\"count\":1,\"label\":\"Rosebloom Cigar\",\"name\":\"rosebloom_cigar\"}],\"expreq\":5000,\"location\":0,\"Job\":[\"pharmacist\"],\"prop\":0,\"catagory\":\"medical\",\"diff\":3000,\"Item\":[{\"count\":1,\"label\":\"Indian Tobbaco\",\"name\":\"Indian_Tobbaco\"},{\"count\":1,\"label\":\"Coal\",\"name\":\"coal\"},{\"count\":2,\"label\":\"Red Sage\",\"name\":\"Red_Sage\"},{\"count\":2,\"label\":\"Rolling paper\",\"name\":\"rollingpaper\"}],\"expadd\":2},\"Text\":\"Rosebloom Cigar\"}'),(736,'Satin Bloom','basic',1,'{\"Desc\":\"A delicately crafted bar of soap made with rich oils, fragrant rose petals, and a touch of lavender.\",\"Param\":{\"catagory\":\"basic\",\"Job\":[\"pharmacist\",\"doctor\"],\"diff\":3000,\"Reward\":[{\"count\":1,\"name\":\"satin_bloom\",\"label\":\"Satin Bloom\"}],\"location\":0,\"prop\":0,\"Item\":[{\"count\":1,\"name\":\"water\",\"label\":\"Water\"},{\"count\":1,\"name\":\"Fat\",\"label\":\"Animal Fat\"},{\"count\":1,\"name\":\"Oleander_Sage\",\"label\":\"Oleander Sage\"}],\"expadd\":1,\"expreq\":0},\"Text\":\"Satin Bloom\"}'),(737,'Dr.Nixie\'s Liquid Cocaine','medical',1,'{\"Desc\":\"\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"pharmacist\",\"doctor\"],\"diff\":3000,\"Item\":[{\"count\":2,\"name\":\"salt\",\"label\":\"Salt\"},{\"count\":1,\"name\":\"morphine\",\"label\":\"Morphine\"},{\"count\":1,\"name\":\"hemp\",\"label\":\"Hemp\"},{\"count\":2,\"name\":\"glassbottle\",\"label\":\"Glass Bottle\"}],\"location\":0,\"prop\":0,\"expadd\":2,\"Reward\":[{\"count\":1,\"name\":\"unique_shoot\",\"label\":\"Dr.Nixie\'s Liquid Cocaine\"}],\"expreq\":3000},\"Text\":\"Dr.Nixie\'s Liquid Cocaine\"}'),(738,'Saline Bottle','medical',1,'{\"Desc\":\"A simple cleansing solution made with purified water and salt.\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"doctor\",\"pharmacist\"],\"diff\":3000,\"Item\":[{\"count\":1,\"name\":\"salt\",\"label\":\"Salt\"},{\"count\":2,\"name\":\"water\",\"label\":\"Water\"}],\"location\":0,\"prop\":0,\"expadd\":1,\"Reward\":[{\"count\":1,\"name\":\"unique_saline\",\"label\":\"Saline Bottle\"}],\"expreq\":50},\"Text\":\"Saline Bottle\"}'),(739,'Herbal Remedy','medical',1,'{\"Desc\":\"A small bottle packed with a potent blend of wild herbs and natural extracts.\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"doctor\",\"pharmacist\"],\"diff\":3000,\"Reward\":[{\"count\":1,\"name\":\"herbmed\",\"label\":\"Herbal Remedy\"}],\"location\":0,\"prop\":0,\"expadd\":1,\"Item\":[{\"count\":2,\"name\":\"American_Ginseng\",\"label\":\"American Ginseng\"},{\"count\":2,\"name\":\"Crows_Garlic\",\"label\":\"Crows Garlic\"},{\"count\":2,\"name\":\"Wild_Mint\",\"label\":\"Wild Mint\"}],\"expreq\":0},\"Text\":\"Herbal Remedy\"}'),(740,'Tylenol','medical',1,'{\"Desc\":\"Simple, dependable, and easy to carry.\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"doctor\",\"pharmacist\"],\"diff\":3000,\"Reward\":[{\"count\":1,\"name\":\"tylenol\",\"label\":\"Tylenol\"}],\"location\":0,\"prop\":0,\"expadd\":1,\"Item\":[{\"count\":1,\"name\":\"acid\",\"label\":\"Acid\"},{\"count\":2,\"name\":\"salt\",\"label\":\"Salt\"},{\"count\":1,\"name\":\"glassbottle\",\"label\":\"Glass Bottle\"}],\"expreq\":50},\"Text\":\"Tylenol\"}'),(741,'Morphine','medical',0,'{\"Desc\":\"A small vial of powerful frontier medicine, reserved for moments when ordinary remedies won\'t do.\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"doctor\",\"pharmacist\"],\"diff\":3000,\"Item\":[{\"count\":3,\"name\":\"Prairie_Poppy\",\"label\":\"Prairie Poppy\"},{\"count\":1,\"name\":\"alcohol\",\"label\":\"Alcohol\"},{\"count\":1,\"name\":\"glassbottle\",\"label\":\"Glass Bottle\"}],\"location\":0,\"prop\":0,\"expadd\":1,\"Reward\":[{\"count\":1,\"name\":\"morphine\",\"label\":\"Morphine\"}],\"expreq\":50},\"Text\":\"Morphine\"}'),(742,'Fiber Bandage','medical',1,'{\"Desc\":\"A sturdy roll of woven fiber cloth, cut and wrapped for quick use in the field\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"doctor\",\"pharmacist\"],\"diff\":3000,\"Item\":[{\"count\":2,\"name\":\"fibers\",\"label\":\"Fibers\"},{\"count\":1,\"name\":\"American_Ginseng\",\"label\":\"American Ginseng\"},{\"count\":1,\"name\":\"honey\",\"label\":\"Honey\"},{\"count\":1,\"name\":\"sap\",\"label\":\"Sap\"}],\"location\":0,\"prop\":0,\"expadd\":1,\"Reward\":[{\"count\":1,\"name\":\"fiberbandage\",\"label\":\"Fiber Bandage\"}],\"expreq\":10},\"Text\":\"Fiber Bandage\"}'),(743,'Bandage','medical',1,'{\"Desc\":\"A clean strip of sturdy cloth, neatly folded and ready for use.\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"doctor\",\"pharmacist\"],\"diff\":3000,\"Reward\":[{\"count\":1,\"name\":\"bandage\",\"label\":\"Bandage\"}],\"location\":0,\"prop\":0,\"expadd\":1,\"Item\":[{\"count\":1,\"name\":\"wool\",\"label\":\"Wool\"},{\"count\":1,\"name\":\"alcohol\",\"label\":\"Alcohol\"}],\"expreq\":0},\"Text\":\"Bandage\"}'),(744,'Love Potion','medical',1,'{\"Desc\":\"A sweet, rosy tonic brewed from flowers, herbs, and a touch of frontier magic.\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"doctor\",\"pharmacist\"],\"diff\":3000,\"Item\":[{\"count\":2,\"name\":\"Blood_Flower\",\"label\":\"Blood Flower\"},{\"count\":1,\"name\":\"water\",\"label\":\"Water\"},{\"count\":1,\"name\":\"alcohol\",\"label\":\"Alcohol\"},{\"count\":2,\"name\":\"sugar\",\"label\":\"Sugar\"},{\"count\":2,\"name\":\"strawberry\",\"label\":\"Strawberry\"}],\"location\":0,\"prop\":0,\"expadd\":1,\"Reward\":[{\"count\":1,\"name\":\"lovepotion\",\"label\":\"Love Potion\"}],\"expreq\":1000},\"Text\":\"Love Potion\"}'),(745,'Opium','medical',0,'{\"Desc\":\"A dark, carefully prepared frontier narcotic.\",\"Param\":{\"catagory\":\"medical\",\"Job\":[\"pharmacist\"],\"diff\":3000,\"Item\":[{\"count\":1,\"name\":\"morphine\",\"label\":\"Morphine\"},{\"count\":2,\"name\":\"acid\",\"label\":\"Acid\"},{\"count\":1,\"name\":\"Blood_Flower\",\"label\":\"Blood Flower\"}],\"location\":0,\"prop\":0,\"expadd\":1,\"Reward\":[{\"count\":1,\"name\":\"opium\",\"label\":\"Opium\"}],\"expreq\":500},\"Text\":\"Opium\"}'),(746,'weapon repair kit','blacksmith',1,'{\"Desc\":\"weapon repair kit\",\"Text\":\"weapon repair kit\",\"Param\":{\"Reward\":[{\"count\":1,\"name\":\"repair_kit\",\"label\":\"Weapon Repair Kit\"}],\"expadd\":1,\"diff\":3000,\"expreq\":0,\"Item\":[{\"count\":2,\"name\":\"cloth\",\"label\":\"Leather\"},{\"count\":2,\"name\":\"acid\",\"label\":\"Acid\"},{\"count\":1,\"name\":\"leather\",\"label\":\"Leather\"}],\"Job\":[\"rdgunsmith\",\"badmanners\",\"abgunsmith\",\"bwgunsmith\",\"sbgunsmith\",\"vtgunsmith\",\"amgunsmith\"],\"catagory\":\"blacksmith\",\"location\":0,\"prop\":0}}'),(747,'Miner\'s Pack','blacksmith',1,'{\"Param\":{\"expadd\":1,\"Job\":[\"rdmine\",\"twmine\",\"abmine\"],\"expreq\":0,\"location\":0,\"catagory\":\"blacksmith\",\"gradelock\":0,\"prop\":0,\"Reward\":[{\"count\":1,\"name\":\"miner_pack\",\"label\":\"Miner\'s Pack\"}],\"Item\":[{\"count\":2,\"name\":\"leather\",\"label\":\"Leather\"},{\"count\":2,\"name\":\"wax\",\"label\":\"Wax\"},{\"count\":5,\"name\":\"fibers\",\"label\":\"Fibers\"}],\"diff\":3000},\"Text\":\"Miner\'s Pack\",\"Desc\":\"\"}'),(748,'Lumber Pack','basic',1,'{\"Param\":{\"expreq\":0,\"prop\":0,\"location\":0,\"expadd\":0,\"gradelock\":4,\"Item\":[{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"Wax\",\"name\":\"wax\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":5}],\"catagory\":\"basic\",\"Reward\":[{\"label\":\"Lumber Pack\",\"name\":\"lumber_pack\",\"count\":1}],\"Job\":[\"sdlumber\",\"vtlumber\",\"bwlumber\",\"sblumber\"],\"diff\":3000},\"Text\":\"Lumber Pack\",\"Desc\":\"\"}'),(749,'Smelt Gold Dust','blacksmith',1,'{\"Text\":\"Smelt Gold Dust\",\"Param\":{\"location\":0,\"expadd\":1,\"catagory\":\"blacksmith\",\"Item\":[{\"name\":\"golddust\",\"label\":\"Gold Dust\",\"count\":30},{\"name\":\"coal\",\"label\":\"Coal\",\"count\":1}],\"Reward\":[{\"name\":\"goldnugget\",\"label\":\"\",\"count\":1}],\"prop\":0,\"Job\":0,\"diff\":3000,\"expreq\":0},\"Desc\":\"Fine gold washed from the rivers, melted down into a single nugget.\"}'),(750,'Smelt Gold Flakes','blacksmith',1,'{\"Text\":\"Smelt Gold Flakes\",\"Param\":{\"location\":0,\"expadd\":1,\"catagory\":\"blacksmith\",\"Item\":[{\"name\":\"goldflake\",\"label\":\"Gold Flake\",\"count\":10},{\"name\":\"coal\",\"label\":\"Coal\",\"count\":1}],\"Reward\":[{\"name\":\"goldnugget\",\"label\":\"\",\"count\":1}],\"prop\":0,\"Job\":0,\"diff\":3000,\"expreq\":0},\"Desc\":\"Placer flakes melted down into a single nugget.\"}'),(751,'Farmer\'s Pack','basic',1,'{\"Text\":\"Farmer\'s Pack\",\"Param\":{\"Item\":[{\"label\":\"Cloth\",\"name\":\"cloth\",\"count\":2},{\"label\":\"Leather\",\"name\":\"leather\",\"count\":2},{\"label\":\"Fibers\",\"name\":\"fibers\",\"count\":10}],\"expadd\":2,\"Job\":[\"emfarm\",\"rdfarm\",\"bwfarm\",\"bvfarm\"],\"expreq\":0,\"Reward\":[{\"name\":\"farmer_pack\",\"count\":1}],\"catagory\":\"basic\",\"diff\":3000,\"location\":[\"emfarm\",\"bwfarm\",\"rdfarm\",\"bvfarm\"],\"prop\":0},\"Desc\":\"A canvas produce pack that holds 400 units of seeds and crops. Farmers stitch their own.\"}'),(752,'Lazarus\'s Glazed Cornbread','custom',1,'{\"Text\":\"Lazarus\'s Glazed Cornbread\",\"Desc\":\"\",\"Param\":{\"diff\":3000,\"Job\":0,\"expadd\":0,\"uinuqe\":[],\"prop\":0,\"Reward\":[{\"count\":1,\"name\":\"foodlazarussglazedcornbread\",\"label\":\"Lazarus\'s Glazed Cornbread\"}],\"Item\":[{\"count\":2,\"name\":\"sugar\",\"label\":\"Sugar\"},{\"count\":2,\"name\":\"Yarrow\",\"label\":\"Yarrow\"},{\"count\":2,\"name\":\"milk\",\"label\":\"Milk\"},{\"count\":2,\"name\":\"honey\",\"label\":\"Honey\"},{\"count\":2,\"name\":\"egg\",\"label\":\"Egg\"}],\"expreq\":0,\"catagory\":\"custom\",\"location\":0}}'),(753,'Salted Fries','custom',1,'{\"Text\":\"Salted Fries\",\"Desc\":\"\",\"Param\":{\"diff\":3000,\"catagory\":\"custom\",\"expadd\":0,\"prop\":0,\"Reward\":[{\"count\":1,\"name\":\"foodsaltedfries\",\"label\":\"Salted Fries\"}],\"Item\":[{\"count\":2,\"name\":\"salt\",\"label\":\"Salt\"},{\"count\":1,\"name\":\"potato\",\"label\":\"Potato\"},{\"count\":1,\"name\":\"milk\",\"label\":\"Milk\"}],\"expreq\":0,\"Job\":[\"sdhotel\"],\"location\":0}}'),(754,'Ride Me Rum','custom',1,'{\"Text\":\"Ride Me Rum\",\"Desc\":\"\",\"Param\":{\"diff\":3000,\"catagory\":\"custom\",\"expadd\":0,\"prop\":0,\"Reward\":[{\"count\":1,\"name\":\"foodridemerum\",\"label\":\"Ride Me Rum\"}],\"Item\":[{\"count\":2,\"name\":\"Black_Berry\",\"label\":\"Black Berry\"},{\"count\":1,\"name\":\"alcohol\",\"label\":\"Alcohol\"},{\"count\":1,\"name\":\"water\",\"label\":\"Water\"}],\"expreq\":0,\"Job\":[\"sdhotel\"],\"location\":0}}'),(755,'Full Traditional','custom',1,'{\"Text\":\"Full Traditional\",\"Desc\":\"\",\"Param\":{\"diff\":3000,\"catagory\":\"custom\",\"expadd\":0,\"prop\":0,\"Reward\":[{\"count\":1,\"name\":\"foodfulltraditional\",\"label\":\"Full Traditional\"}],\"Item\":[{\"count\":1,\"name\":\"beef\",\"label\":\"Beef\"},{\"count\":2,\"name\":\"salt\",\"label\":\"Salt\"},{\"count\":1,\"name\":\"butter\",\"label\":\"Butter\"},{\"count\":1,\"name\":\"pork\",\"label\":\"Pork\"},{\"count\":1,\"name\":\"friedtater\",\"label\":\"Fried Taters\"}],\"expreq\":0,\"Job\":[\"sdhotel\"],\"location\":0}}'),(756,'Sex on the Beach','custom',1,'{\"Text\":\"Sex on the Beach\",\"Desc\":\"\",\"Param\":{\"diff\":3000,\"catagory\":\"custom\",\"expadd\":0,\"prop\":0,\"Reward\":[{\"count\":1,\"name\":\"foodsexonthebeach\",\"label\":\"Sex on the Beach\"}],\"Item\":[{\"count\":1,\"name\":\"alcohol\",\"label\":\"Alcohol\"},{\"count\":1,\"name\":\"lemon\",\"label\":\"Lemon\"},{\"count\":1,\"name\":\"mango\",\"label\":\"Mango\"},{\"count\":2,\"name\":\"water\",\"label\":\"Water\"}],\"expreq\":0,\"Job\":[\"sdhotel\"],\"location\":0}}'),(757,'Veggie Noodles','custom',1,'{\"Text\":\"Veggie Noodles\",\"Desc\":\"\",\"Param\":{\"diff\":3000,\"catagory\":\"custom\",\"expadd\":0,\"prop\":0,\"Reward\":[{\"count\":1,\"name\":\"foodveggienoodles\",\"label\":\"Veggie Noodles\"}],\"Item\":[{\"count\":1,\"name\":\"Parasol_Mushroom\",\"label\":\"Parasol Mushroom\"},{\"count\":1,\"name\":\"Wild_Carrot\",\"label\":\"Wild Carrot\"},{\"count\":2,\"name\":\"Crows_Garlic\",\"label\":\"Crows Garlic\"},{\"count\":1,\"name\":\"butter\",\"label\":\"Butter\"},{\"count\":1,\"name\":\"salt\",\"label\":\"Salt\"}],\"expreq\":0,\"Job\":[\"sdhotel\"],\"location\":0}}'),(758,'Peach Cobbler','custom',1,'{\"Desc\":\"\",\"Text\":\"Peach Cobbler\",\"Param\":{\"Reward\":[{\"label\":\"Peach Cobbler\",\"name\":\"consumable_peachcobbler\",\"count\":1}],\"expadd\":0,\"location\":0,\"prop\":0,\"expreq\":0,\"Item\":[{\"label\":\"Peach\",\"name\":\"consumable_peach\",\"count\":2},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1}],\"diff\":3000,\"Job\":[\"vtcafe\"],\"catagory\":\"custom\"}}'),(759,'Seafood Gumbo','custom',1,'{\"Desc\":\"\",\"Text\":\"Seafood Gumbo\",\"Param\":{\"Reward\":[{\"label\":\"Seafood Gumbo\",\"name\":\"seafood_gumbo\",\"count\":1}],\"expadd\":0,\"location\":0,\"prop\":0,\"expreq\":0,\"Item\":[{\"label\":\"Salt\",\"name\":\"salt\",\"count\":1},{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":1},{\"label\":\"Bird Meat\",\"name\":\"bird\",\"count\":1}],\"diff\":3000,\"Job\":[\"vtcafe\"],\"catagory\":\"custom\"}}'),(760,'The Cottage Loaf','custom',1,'{\"Desc\":\"\",\"Text\":\"The Cottage Loaf\",\"Param\":{\"Reward\":[{\"label\":\"The Cottage Loaf\",\"name\":\"cottage_loaf\",\"count\":1}],\"expadd\":0,\"location\":0,\"prop\":0,\"expreq\":0,\"Item\":[{\"label\":\"Batter\",\"name\":\"batter\",\"count\":1},{\"label\":\"Crows Garlic\",\"name\":\"Crows_Garlic\",\"count\":1},{\"label\":\"Butter\",\"name\":\"butter\",\"count\":1}],\"diff\":3000,\"Job\":[\"vtcafe\"],\"catagory\":\"custom\"}}'),(761,'Matcha Milk','custom',1,'{\"Desc\":\"\",\"Text\":\"Matcha Milk\",\"Param\":{\"Reward\":[{\"label\":\"Matcha Milk\",\"name\":\"matcha_milk\",\"count\":1}],\"expadd\":0,\"location\":0,\"prop\":0,\"expreq\":0,\"Item\":[{\"label\":\"Water\",\"name\":\"water\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1},{\"label\":\"Tealeaf\",\"name\":\"tealeaf\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1}],\"diff\":3000,\"Job\":[\"vtcafe\"],\"catagory\":\"custom\"}}'),(762,'Teddy Bear Hot Chocolate','custom',1,'{\"Desc\":\"\",\"Text\":\"Teddy Bear Hot Chocolate\",\"Param\":{\"Reward\":[{\"label\":\"Teddy Bear Hot Chocolate\",\"name\":\"teddy_hot_chocolate\",\"count\":1}],\"expadd\":0,\"location\":0,\"prop\":0,\"expreq\":0,\"Item\":[{\"label\":\"Cocoa\",\"name\":\"cocoa\",\"count\":1},{\"label\":\"Milk\",\"name\":\"milk\",\"count\":1},{\"label\":\"Sugar\",\"name\":\"sugar\",\"count\":1}],\"diff\":3000,\"Job\":[\"vtcafe\"],\"catagory\":\"custom\"}}'),(764,'Storage Box','blacksmith',1,'{\"Desc\":\"\",\"Param\":{\"expreq\":100,\"catagory\":\"blacksmith\",\"prop\":0,\"expadd\":2,\"Item\":[{\"name\":\"hwood\",\"label\":\"Hard Wood\",\"count\":5},{\"name\":\"wood\",\"label\":\"Soft Wood\",\"count\":5},{\"name\":\"nails\",\"label\":\"Nails\",\"count\":5},{\"name\":\"bolts\",\"label\":\"Bolts\",\"count\":2},{\"name\":\"coal\",\"label\":\"Coal\",\"count\":1}],\"diff\":3000,\"Reward\":[{\"name\":\"storage_box_1000\",\"label\":\"\",\"count\":1}],\"Job\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"],\"location\":[\"amblacksmith\",\"mfblacksmith\",\"bwblacksmith\",\"sbblacksmith\",\"abblacksmith\",\"rdblacksmith\",\"emblacksmith\",\"sdblacksmith\",\"vtblacksmith\"]},\"Text\":\"Storage Box\"}');
/*!40000 ALTER TABLE `crafting_recipes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cron_state`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cron_state` (
  `name` varchar(64) NOT NULL,
  `lastrun` varchar(16) NOT NULL DEFAULT '',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cron_state`
--

LOCK TABLES `cron_state` WRITE;
/*!40000 ALTER TABLE `cron_state` DISABLE KEYS */;
/*!40000 ALTER TABLE `cron_state` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `death_losses`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `death_losses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charidentifier` int(11) NOT NULL,
  `identifier` varchar(50) NOT NULL DEFAULT '',
  `charname` varchar(100) NOT NULL DEFAULT '',
  `steamname` varchar(50) NOT NULL DEFAULT '',
  `weapons` longtext DEFAULT NULL,
  `items` longtext DEFAULT NULL,
  `cash` double NOT NULL DEFAULT 0,
  `gold` double NOT NULL DEFAULT 0,
  `restored` tinyint(1) NOT NULL DEFAULT 0,
  `restoredby` varchar(100) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `charid_idx` (`charidentifier`),
  KEY `created_idx` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `death_losses`
--

LOCK TABLES `death_losses` WRITE;
/*!40000 ALTER TABLE `death_losses` DISABLE KEYS */;
/*!40000 ALTER TABLE `death_losses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `doorlock_doors`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `doorlock_doors` (
  `doorid` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT 'door',
  `data` longtext NOT NULL DEFAULT '[]',
  `lastupdate` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`doorid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `doors`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `doors` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `doorinfo` longtext NOT NULL DEFAULT '[]',
  `job` longtext NOT NULL DEFAULT '[]',
  `item` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `doors`
--

LOCK TABLES `doors` WRITE;
/*!40000 ALTER TABLE `doors` DISABLE KEYS */;
/*!40000 ALTER TABLE `doors` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `easter_limits`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `easter_limits` (
  `charidentifier` int(11) NOT NULL,
  `patch` int(11) NOT NULL,
  `generation` int(11) NOT NULL,
  `count` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charidentifier`,`patch`,`generation`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `easter_limits`
--

LOCK TABLES `easter_limits` WRITE;
/*!40000 ALTER TABLE `easter_limits` DISABLE KEYS */;
/*!40000 ALTER TABLE `easter_limits` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ecoboost`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ecoboost` (
  `charid` int(11) NOT NULL,
  `last_activated` int(11) NOT NULL DEFAULT 0,
  `exhausted` tinyint(1) NOT NULL DEFAULT 0,
  `earned` double NOT NULL DEFAULT 0,
  `completed_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ecoboost`
--

LOCK TABLES `ecoboost` WRITE;
/*!40000 ALTER TABLE `ecoboost` DISABLE KEYS */;
/*!40000 ALTER TABLE `ecoboost` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `election`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `election` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `region` varchar(32) NOT NULL DEFAULT '',
  `ends_at` timestamp NULL DEFAULT NULL,
  `open` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` varchar(100) NOT NULL DEFAULT '',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `hours` int(11) NOT NULL DEFAULT 48,
  `started_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `region` (`region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `election`
--

LOCK TABLES `election` WRITE;
/*!40000 ALTER TABLE `election` DISABLE KEYS */;
/*!40000 ALTER TABLE `election` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `election_candidates`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `election_candidates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `election_id` int(11) NOT NULL,
  `charid` int(11) NOT NULL,
  `name` varchar(64) NOT NULL,
  `region` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `one_run_each` (`election_id`,`charid`),
  KEY `election_id` (`election_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `election_candidates`
--

LOCK TABLES `election_candidates` WRITE;
/*!40000 ALTER TABLE `election_candidates` DISABLE KEYS */;
/*!40000 ALTER TABLE `election_candidates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `election_settings`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `election_settings` (
  `k` varchar(32) NOT NULL,
  `v` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `election_settings`
--

LOCK TABLES `election_settings` WRITE;
/*!40000 ALTER TABLE `election_settings` DISABLE KEYS */;
/*!40000 ALTER TABLE `election_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `election_votes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `election_votes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `election_id` int(11) NOT NULL,
  `candidate_id` int(11) NOT NULL,
  `identifier` varchar(100) NOT NULL,
  `charid` int(11) DEFAULT NULL,
  `voter_name` varchar(100) NOT NULL DEFAULT '',
  `voted_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `region` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `one_per_region` (`election_id`,`region`,`identifier`),
  KEY `candidate_id` (`candidate_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `election_votes`
--

LOCK TABLES `election_votes` WRITE;
/*!40000 ALTER TABLE `election_votes` DISABLE KEYS */;
/*!40000 ALTER TABLE `election_votes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emotewheel`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `emotewheel` (
  `charid` int(11) NOT NULL,
  `emotes` longtext NOT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emotewheel`
--

LOCK TABLES `emotewheel` WRITE;
/*!40000 ALTER TABLE `emotewheel` DISABLE KEYS */;
/*!40000 ALTER TABLE `emotewheel` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_windows`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_windows` (
  `event` varchar(64) NOT NULL,
  `date_from` varchar(10) DEFAULT NULL,
  `date_to` varchar(10) DEFAULT NULL,
  `hour_from` int(11) DEFAULT NULL,
  `hour_to` int(11) DEFAULT NULL,
  PRIMARY KEY (`event`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `evidence_lockers`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `evidence_lockers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `station` varchar(50) NOT NULL,
  `label` varchar(100) DEFAULT NULL,
  `items` longtext DEFAULT NULL,
  `weapons` longtext DEFAULT NULL,
  `updated` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_station` (`station`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `evidence_lockers`
--

LOCK TABLES `evidence_lockers` WRITE;
/*!40000 ALTER TABLE `evidence_lockers` DISABLE KEYS */;
/*!40000 ALTER TABLE `evidence_lockers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `fred_consumables`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fred_consumables` (
  `name` varchar(50) NOT NULL,
  `displayname` varchar(64) NOT NULL DEFAULT '',
  `hunger` float NOT NULL DEFAULT 0,
  `thirst` float NOT NULL DEFAULT 0,
  `metabolism` int(11) NOT NULL DEFAULT 0,
  `animation` varchar(32) NOT NULL DEFAULT '',
  `propname` varchar(64) NOT NULL DEFAULT '',
  `effect` varchar(64) NOT NULL DEFAULT '',
  `effectduration` int(11) NOT NULL DEFAULT 0,
  `innercorestamina` float NOT NULL DEFAULT 0,
  `innercorestaminagold` float NOT NULL DEFAULT 0,
  `outercorestaminagold` float NOT NULL DEFAULT 0,
  `innercorehealth` float NOT NULL DEFAULT 0,
  `innercorehealthgold` float NOT NULL DEFAULT 0,
  `outercorehealthgold` float NOT NULL DEFAULT 0,
  `innercoredeadeye` float NOT NULL DEFAULT 0,
  `innercoredeadeyegold` float NOT NULL DEFAULT 0,
  `outercoredeadeyegold` float NOT NULL DEFAULT 0,
  `diff` int(11) NOT NULL DEFAULT 0,
  `itemhash` varchar(64) NOT NULL DEFAULT '',
  `propid` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fred_consumables`
--

LOCK TABLES `fred_consumables` WRITE;
/*!40000 ALTER TABLE `fred_consumables` DISABLE KEYS */;
INSERT INTO `fred_consumables` VALUES ('American_Ginseng','American Ginseng',-10,-10,0,'eat','s_inv_alaskanginseng01cx','PlayerHealthPoor',300,0,0,0,0,0,0,0,0,0,0,'',''),('apple','Apple',6,5,0,'eat','s_bit_apple01x','',0,2,0,0,1,0,0,0,0,0,0,'',''),('apsod','Apple Soda',3,39,0,'shortbottle','p_bottlebeer01a_1','',0,4,0,0,1,0,0,0,0,0,0,'',''),('bakepear','Baked Pear',19,0,0,'eat','p_pear_02x','',0,2,0,0,2,0,0,0,0,0,0,'',''),('banachoco','Chocolate Banana',27,0,0,'eat','p_banana_day_08x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('banafried','Fried Banana',29,0,0,'eat','p_banana_day_04x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('banana','Banana',6,5,0,'eat','p_banana_day_01x','',0,2,0,0,1,0,0,0,0,0,0,'',''),('bandage','Bandage',0,0,0,'syringe','p_bottlemedicine09x','',0,0,0,0,50,0,0,0,0,0,5000,'',''),('barwa','Barley Water',5,38,0,'drink_cup','p_teacup01x','',0,3,0,0,15,0,0,0,0,0,0,'',''),('beef','Beef',15,20,0,'eat','p_meatchunk_sm02x','',0,0,0,0,-30,0,0,0,0,0,0,'',''),('beefjerky','Deer Jerky',22,0,0,'eat','p_cs_jerky01x','',0,0,0,0,5,0,0,0,0,0,0,'',''),('beer','Beer',5,31,0,'shortbottle','p_bottlebeer01a','',0,5,0,0,0,5,0,0,0,0,0,'',''),('berglaz','Berry Glazed Game',39,5,0,'bowl','','',0,5,0,0,5,0,0,0,0,0,0,'',''),('berry_goodness','Berry Goodness',40,20,0,'eat','p_pie01x_slice','',0,12,0,0,14,0,0,0,0,0,0,'',''),('biggame','Big Game Meat',10,0,0,'eat','p_soppressata_b_meat','',0,0,0,0,-45,0,0,0,0,0,0,'',''),('biggamecooked','Big Game Chops',34,0,0,'eat','p_meatchunk_sm02x','',0,0,0,0,10,0,0,0,0,0,0,'',''),('bird','Bird Meat',10,0,0,'eat','p_cs_turtlemeat01x','',0,0,0,0,-25,0,0,0,0,0,0,'',''),('birdmeatcook','Cooked Birdmeat',26,0,0,'eat','p_redefleshymeat01xa','',0,0,0,0,10,0,0,0,0,0,0,'',''),('bisu','Campfire Biscuit',13,0,0,'eat','p_pickup_bread01x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('blaber','Blackberry Water',0,33,0,'longbottle','p_bottlewine01x','',0,9,0,0,0,0,0,0,0,0,0,'',''),('blackberryale','BlackBerry Ale',3,28,0,'shortbottle','p_bottlebeer01a_1','',0,9,0,0,3,0,0,0,0,0,0,'',''),('Black_Currant','Black Currant',-10,-10,0,'eat','s_inv_blackcurrant01bx','OJDominoBlur',300,0,0,0,0,0,0,0,0,0,0,'',''),('Blood_Flower','Blood Flower',-10,-10,0,'eat','s_inv_bloodflower01cx','KingCastleRed',300,0,0,0,0,0,0,0,0,0,0,'',''),('blueberry','Blueberry',4,6,0,'eat','p_pebble02x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('boiledegg','Boiled Egg',15,0,0,'eat','p_egg01x','',0,0,0,0,5,0,0,0,0,0,0,'',''),('bread','Bread',27,0,0,'eat','p_bread03x','',0,0,0,0,1,0,0,0,0,0,0,'',''),('breadbana','Banana Bread',42,0,0,'eat','p_bread01x','',0,2,0,0,2,0,0,0,0,0,0,'',''),('breadblue','Blueberry Bread',43,0,0,'eat','p_bread07x','',0,2,0,0,2,0,0,0,0,0,0,'',''),('breadcorn','Corn Bread',37,3,0,'eat','p_bread06x','',0,3,0,0,2,0,0,0,0,0,0,'',''),('breadgarlic','Garlic Bread',39,0,0,'eat','p_bread_14_ab_s','',0,1,0,0,2,0,0,0,0,0,0,'',''),('breadginger','Ginger Bread',44,1,0,'eat','p_bread05x','',0,5,0,0,5,0,0,0,0,0,0,'',''),('breadlemon','Lemon Bread',44,0,0,'eat','p_bread01x','',0,2,0,0,2,0,0,0,0,0,0,'',''),('breadorange','Orange Bread',41,0,0,'eat','p_bread01x','',0,2,0,0,2,0,0,0,0,0,0,'',''),('breadsoda','Soda Bread',34,3,0,'eat','p_bread_13_ab','',0,1,0,0,4,0,0,0,0,0,0,'',''),('brownie','Brownie',37,5,0,'eat','s_chocolatebar02x','',0,15,0,0,15,0,0,0,0,0,0,'',''),('browniehemp','Hemp Brownie',39,0,0,'eat','s_chocolatebar02x','Playerdrughalluc01',320,0,135,145,0,135,145,0,0,0,0,'',''),('cakebundblue','Blue Berry Bundt Cake',41,0,0,'eat','p_pie01x_slice','',0,5,0,0,5,0,0,0,0,0,0,'',''),('cakecarrot','Carrot Cake',37,7,0,'eat','p_pie01x_slice','',0,7,0,0,8,0,0,0,0,0,0,'',''),('cakemango','Mango Cake',49,0,0,'eat','p_pie01x_slice','',0,5,0,0,5,0,0,0,0,0,0,'',''),('cakeshortstraw','Strawberry Short Cake',48,0,0,'eat','p_pie01x_slice','',0,7,0,0,2,0,0,0,0,0,0,'',''),('camole','Camp Omellete',36,9,0,'bowl','','',0,5,0,0,9,0,0,0,0,0,0,'',''),('champe','Champagne',3,42,0,'longbottle','s_champbottle01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('chemes','Cheese & Meat Stick',39,4,0,'eat','p_meatchunk_sm04x','',0,3,0,0,3,0,0,0,0,0,0,'',''),('chicken_and_gravy','Chicken and Gravy',30,0,0,'eat','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('chicklempast','Lemon Chicken Pasta',57,0,0,'bowl','','',0,0,0,0,6,0,0,0,0,0,0,'',''),('chickorange','Orange Marinated Chicken',47,0,0,'eat','p_meatchunk_sm03x','',0,0,0,0,5,0,0,0,0,0,0,'',''),('chococake','Chocolate Cream Cake',42,0,0,'eat','p_pie01x_slice','',0,5,0,0,15,0,0,0,0,0,0,'',''),('chocolatemilk','Chocolate Milk',1,45,0,'drink_cup','p_teacup01x','',0,2,0,0,5,0,0,0,0,0,0,'',''),('cocainegum','Cocaine Gum',5,0,0,'syringe','p_bottlemedicine09x','DEADEYE',10000,50,5,10,-5,50,100,0,0,0,5000,'',''),('cockorange','Orange Cocktail',5,61,0,'longbottle','p_bottle008x_big','',0,2,0,0,2,150,80,0,0,0,0,'',''),('coffeecream','Coffee with Cream',5,29,0,'drink_cup','p_cuptin01x','',0,30,0,0,20,0,0,0,0,0,0,'',''),('coffeesugar','Coffee with Sugar',0,26,0,'drink_cup','p_cuptin01x','',0,33,0,0,40,0,0,0,0,0,0,'',''),('consumable_bluegil','Dried Bluegil',36,0,0,'eat','p_redfishfilet01xa','',0,0,0,0,15,0,0,0,0,0,0,'',''),('consumable_breakfast','Breakfast',51,1,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('consumable_caramel','Caramel',17,0,0,'eat','s_re_chocolate_single','',0,0,0,0,20,0,0,0,0,0,0,'',''),('consumable_chocolate','Chocolate Bar',21,0,0,'eat','s_chocolatebar01x','',0,10,0,0,5,5,0,0,0,0,0,'',''),('consumable_coffee','Cafe',0,50,0,'drink_cup','','',0,30,0,0,30,0,0,0,0,0,0,'',''),('consumable_fruitsalad','Fruit Bowl',37,9,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('consumable_game','Jerkied Game Meat',32,0,0,'eat','s_jerky01bx','',0,0,0,0,10,0,0,0,0,0,0,'',''),('consumable_kidneybeans_can','Canned Beans',0,0,100,'syringe','','DEADEYE',150,0,0,0,0,0,2500,0,0,0,0,'',''),('consumable_meat_greavy','Carne Cocinada',40,0,500,'bowl','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('consumable_medicine','Medicina',0,5,0,'syringe','','',0,0,0,100,0,100,0,0,0,0,0,'',''),('consumable_peachcobbler','Peach Cobbler',38,6,0,'eat','p_pie01x_slice','',0,0,0,0,0,0,0,0,0,0,0,'',''),('consumable_raspberrywater','Berry Water',0,30,0,'longbottle','p_water01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('consumable_salmon','Dried Salmon',35,0,0,'eat','p_redfishfilet01xa','',0,0,0,0,10,0,0,0,0,0,0,'',''),('consumable_salmon_can','Salmon Can',9,3,0,'eat','s_canbeans01x','',0,1,0,0,5,0,0,0,0,0,0,'',''),('consumable_trout','Cooked Trout',33,0,0,'eat','p_redfishfilet01xb','',0,0,0,0,15,0,0,0,0,0,0,'',''),('consumable_veggies','Edible Veggies',34,0,0,'bowl','','',0,0,0,0,5,0,0,0,0,0,0,'',''),('cookedbluegil','Cooked Bluegil with Veggies',36,0,0,'eat','p_whitefishfilet01xb','',0,2,0,0,5,0,0,0,0,0,0,'',''),('cookie','Cookie',21,0,0,'eat','s_candybag01x_blue','',0,2,0,0,1,0,0,0,0,0,0,'',''),('cooklemon','Lemon Cookie',29,0,0,'eat','p_baitbread01x','',0,15,0,0,5,0,0,0,0,0,0,'',''),('corn','Corn',5,-1,0,'eat','p_corn02x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('cornbeefhash','Corn Beef & Hash',49,9,0,'bowl','','',0,3,0,0,8,0,0,0,0,0,0,'',''),('cornoncob','Corn on the cob',29,7,0,'eat','p_corn02x','',0,3,0,0,3,0,0,0,0,0,0,'',''),('cottage_loaf','The Cottage Loaf',46,0,0,'eat','p_bread03x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('crabake','Crab Root Bake',42,9,0,'bowl','','',0,5,0,0,9,0,0,0,0,0,0,'',''),('crabbutter','Butter Crab',26,5,0,'eat','p_crab_cakes01x','',0,5,0,0,5,0,0,0,0,0,0,'',''),('crabentree','Crab Entree',32,10,0,'bowl','','',0,3,0,0,5,0,0,0,0,0,0,'',''),('crablegs','Crab Legs',24,3,0,'eat','p_crab_cakes01x','',0,5,0,0,5,0,0,0,0,0,0,'',''),('cracak','Crab Cakes',23,0,0,'eat','p_crab_cakes01x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('crncrm','Creamed Corn',41,8,0,'bowl','','',0,3,0,0,5,0,0,0,0,0,0,'',''),('Crows_Garlic','Crows Garlic',5,-10,0,'eat','p_garlic_02x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('crso','Cream Soda',7,47,0,'shortbottle','p_bottlebeer01a','',0,1,0,0,15,0,0,0,0,0,0,'',''),('cunbisgrav','Country Biscuits with Gravy',56,9,0,'bowl','','',0,11,0,0,5,0,0,0,0,0,0,'',''),('cursod','Currant Soda',1,37,0,'shortbottle','p_bottlebeer01a_2','',0,1,0,0,1,0,0,0,0,0,0,'',''),('dirty_grave','Dirty Grave',45,0,0,'eat','p_pie01x_slice','',0,14,0,0,12,0,0,0,0,0,0,'',''),('donut','Donut',29,9,0,'eat','s_chocolatebar02x','',0,12,0,0,15,0,0,0,0,0,0,'',''),('donutchoco','Chocolate Donut',31,6,0,'eat','s_chocolatebar02x','',0,13,0,0,14,0,0,0,0,0,0,'',''),('drugbayoucola','Bayo Cola',0,0,0,'longbottle','p_glenswhisky01x','KingCastleBlue',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugblackbaronbosssauce','Black Baron Boss Sauce',0,0,0,'longbottle','p_glenswhisky01x','MP_Deathink_color06',120,0,0,2250,0,0,0,0,0,0,0,'',''),('drugbonniesrosetonic','Bonnie\'s Rose Tonic',0,0,0,'longbottle','p_glenswhisky01x','MP_DeathInk_Color06',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugbrownsugarum','Brownsuga Rum',0,0,0,'longbottle','p_glenswhisky01x','KingCastleBlue',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugchewablewater','Chewable Water',0,0,0,'longbottle','p_glenswhisky01x','MP_ArrowDrain',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugcoldleadchew','Cold Lead Chew',0,0,0,'eat','s_inv_tabaccopotent01x','PhotoMode_FilterModern02',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugcommandercoffee','Commander Cofee',0,0,0,'shortbottle','p_bottlebeer02x','PHOTOMODE_FILTERGAME10',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugcommunionbourbon','Saints Communion Bourbon',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterGame10',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugcompjuice','Comp Juice',0,0,0,'longbottle','p_glenswhisky01x','MP_Deathink_color05',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugcrossjuice','Cross Juice',0,0,0,'longbottle','p_glenswhisky01x','MP_Deathink_color02',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugcruxinvicta','Crux Invicta',0,0,0,'longbottle','s_inv_whiskey02x','',0,0,0,2250,0,0,0,0,0,0,0,'',''),('drugcruxsacra','Crux Sacra',0,0,0,'eat','p_jar04x','PhotoMode_FilterModern01',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugcrystalskull','Crystal Skull',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterModern04',120,0,0,0,0,0,1750,0,0,0,0,'',''),('drugdajneswranglerscut','Dajne\'s Wrangler\'s Cut',0,0,0,'eat','s_inv_tabaccopotent01x','Photomode_FilterModern05',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugdeadmanspour','Dead Man\'s Pour',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterModern01',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugdeathgum','Death Gum',0,0,0,'eat','s_inv_tabaccopotent01x','MP_DeathInk_Color09',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugdrsanchezcokeelixer','Dr. Sanchez Coke Elixer',0,0,0,'longbottle','p_bottlemedicine16x','Photomode_FilterModern05',120,0,0,2000,0,0,250,0,0,0,0,'',''),('drugfilth','Filth',0,0,0,'longbottle','p_glenswhisky01x','Photomode_filtermodern03',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugflacascrystalblue','Flaca\'s Crystal Blue',0,0,0,'longbottle','p_glenswhisky01x','MP_DeathInk_Color01',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugflacosshine','Flaco\'s Shine',0,0,0,'longbottle','p_glenswhisky01x','MP_DeathInk_color02',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drughangmanshoney','Hangman\'s Honey',0,0,0,'eat','p_masonjar01x','PhotoMode_FilterGame06',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugharleyshealthyswig','Harley\'s Healthy Swig',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterModern10',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drughotchocolate','Hot Chocolate',0,0,0,'drink_cup','p_cuptin01x','MP_DeathInk_color01',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugironrootwhiskey','Iron Root Whiskey',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterModern05',120,0,0,0,0,0,2250,0,0,0,0,'',''),('druglacroixxi','LaCroix XI',0,0,0,'longbottle','p_bottle011x','Photomode_FilterModern03',120,0,0,0,0,0,2250,0,0,0,0,'',''),('druglaudanum','Laudanum',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterModern03',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugleeshealthyelixir','Lee\'s Healthy Elixir',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterModern02',120,0,0,0,0,0,1750,0,0,0,0,'',''),('drugleesspeedyhealth','Lee\'s Speedy Elixir',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterGame10',120,0,0,1750,0,0,0,0,0,0,0,'',''),('drugleeswonton','Lee\'s Wonton Noodle Soup',50,15,0,'bowl','p_soup_01','',0,0,0,0,0,0,0,0,0,0,0,'',''),('drugluciisluckychews','Lucii\'s Lucky Chews',0,0,0,'eat','s_inv_tabaccopotent01x','PhotoMode_FilterModern04',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('druglulujuice','LuLu Juice',0,0,0,'longbottle','p_glenswhisky01x','MP_ARROWDRAIN',120,0,0,2250,0,0,0,0,0,0,0,'',''),('drugmedicalmunchies','Medical Munchies',0,0,0,'eat','s_inv_tabaccopotent01x','PhotoMode_FilterGame04',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugmrleeseggroll','Mr. Lee\'s Eggroll',0,0,0,'eat','p_bread_14_ab_s','MP_DeathInk_Color06',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugpoitin','PoitÃ­n',0,0,0,'longbottle','p_bottle011x','PhotoMode_FilterGame02',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugpsychedelicmushroom','Psychedelic Mushroom',0,0,0,'eat','s_inv_parasol','PhotoMode_FilterGame10',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugrothschilddrops','Rothschild\'s Cocaine Lemon Drops',0,0,0,'eat','s_inv_cocainegum01x','MP_DeathInk_Color06',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugrothschildrockcandy','Rothschild\'s Rock Candy',0,0,0,'eat','s_candybag01x_blue','KingCastleBlue',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugshayschew','Shay\'s Chew',0,0,0,'eat','s_inv_tabaccopotent01x','KingCastleRed',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugsuccublisspotion','Succubliss Potion',0,0,0,'longbottle','p_bottle011x','KingCastleRed',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugswampjuice','Swamp Juice',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterModern03',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugtommyshardtackcandy','Tommy\'s Hard Tack Candy',0,0,0,'eat','s_candybag01x_blue','MP_DeathInk_Color09',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugturkeyass','Turkey Ass',0,0,0,'eat','s_platechickenrstd01x','PhotoMode_FilterModern03',120,0,0,1250,0,0,1250,0,0,0,0,'',''),('drugvanhornjuice','Van Horn Juice',0,0,0,'longbottle','p_glenswhisky01x','MP_DeathInk_Color01',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugvitalitytonic','Vitality Tonic',0,0,0,'longbottle','p_glenswhisky01x','MP_DeathInk_Color10',120,0,0,0,0,0,2250,0,0,0,0,'',''),('drugwobblecockbeer','Wobblecock Beer',0,0,0,'longbottle','p_glenswhisky01x','PhotoMode_FilterModern01',120,0,0,0,0,0,2250,0,0,0,0,'',''),('ecstasyelixir','The Ecstasy Elixir',0,0,0,'syringe','p_bottlemedicine09x','DEADEYE',20000,100,100,100,0,0,0,0,0,0,5000,'',''),('fiberbandage','Fiber Bandage',0,0,0,'syringe','p_bottlemedicine09x','',0,0,0,0,50,0,0,0,0,0,5000,'',''),('fischow','Fish Chowder',42,9,0,'bowl','','',0,5,0,0,9,0,0,0,0,0,0,'',''),('fishchips','Fish and Chips (Salmon)',36,0,0,'bowl','p_basketfish01x','',0,0,0,0,5,0,0,0,0,0,0,'',''),('fishcookedlmb','Cooked Largemouth Bass (Medium)',34,0,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('fishcookedlmblg','Cooked Largemouth Bass (Large)',35,0,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('fishmeat','Fish Meat',10,0,0,'eat','s_inv_fishrainbowtrout01x_ms','',0,0,0,0,-40,0,0,0,0,0,0,'',''),('foodannieshotpocketpie','Annie\'s Hot Pocket Pie',65,0,0,'eat','p_crab_cakes01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodbayouwater','Bayou Water',0,65,0,'longbottle','s_inv_whiskey02x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodbeeandleafmead','Bee & Leaf Mead',0,65,0,'longbottle','p_glenswhisky01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodbluelagoon','Blue Lagoon',0,65,0,'longbottle','p_glenswhisky01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodbuckbloodstew','Buckblood Stew',65,0,0,'bowl','p_cs_platestew02x_noanim','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodburgerandfries','Burger and Fries',65,0,0,'eat','p_biscuitsandwich01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodcaptainsrum','Cpatain\'s Stash Carribean Rum',5,60,0,'longbottle','p_glenswhisky01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodcreoledaube','Creole Daube',65,0,0,'bowl','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodcruxnocturna','Crux Nocturna',65,0,0,'eat','p_onionred01x','',0,4,0,0,0,0,0,0,0,0,0,'',''),('foodcruxsanguinis','Crux Sanguinis',0,65,0,'longbottle','s_inv_whiskey02x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('fooddallashighprotein','Dallas\'s High Protein Stew',50,15,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('fooddirtydavesdinendash','Dirty Dave\'s Dine N Dash',65,0,0,'eat','proc_can06x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodexpiredbeans','Expired Can of Beans',50,15,0,'eat','s_canbeans01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodfriedchickenbutts','Fried Chicken Butts',65,0,0,'eat','p_chicken01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodfulltraditional','Full Traditional',62,12,0,'bowl','p_cs_platestew01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodgrilledcheesetomatosoup','Grilled Cheese & Tomato Soup',50,15,0,'eat','p_cs_sandwich01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodhoneycutskewers','Honey Cut Skewers',65,0,0,'eat','p_capicola_meat_b02x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodhumaneye','Human Eye',0,65,0,'longbottle','p_glenswhisky01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodhumanheart','Human Heart',65,0,0,'eat','s_meatbit_organ_medium01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodkatteatime','Kat Tea Time',0,65,0,'drink_cup','p_cuptin01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodlazarussglazedcornbread','Lazarus\'s Glazed Cornbread',50,50,0,'eat','p_bread05x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodleesapplepie','Lee\'s Apple Pie',55,10,0,'eat','p_pie01x_slice','',0,5,0,0,15,0,0,0,0,0,0,'',''),('foodleeshoneycoffee','Lee\'s Honey Coffee',10,55,0,'drink_cup','p_cuptin01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodleesmilktea','Lee\'s Milk Tea',0,65,0,'longbottle','p_vg_jar01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodmccarthyscuppa','McCarthy\'s Cuppa',0,65,0,'drink_cup','p_cup01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodmccarthysfullenglish','McCarthys\' Full English',65,0,0,'bowl','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodmoonberrypie','Moon Berry Pie',50,15,0,'eat','p_pie01x_slice','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodmudbuddiessnackles','Mud Buddies Snackles',50,15,0,'bowl','p_cs_platestew01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodridemerum','Ride Me Rum',6,58,0,'longbottle','p_glenswhisky01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodrivieracrownedsupper','Riviera Crowned Supper',50,15,0,'bowl','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodryderleesrabbitstew','Ryder Lee\'s Rabbit Stew',55,10,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('foodsaltedfries','Salted Fries',38,4,0,'eat','p_crab_cakes01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodsexonthebeach','Sex on the Beach',9,47,0,'drink_cup','p_cup01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodsilasslemontea','Silas\'s Lemontea',0,65,0,'longbottle','p_vg_jar01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodsimsomelette','Sim\'s Omelette',50,15,0,'bowl','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodtanglestew','Tangle Stew',50,15,0,'bowl','p_cs_platestew01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodtrailblazerbites','Trailblazer Bites',65,0,0,'eat','p_shopbait01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('fooduncleericsenglish','Uncle Eric\'s English Breakfast',50,15,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('foodveggienoodles','Veggie Noodles',44,26,0,'bowl','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodvenisonchili','Venison Chili',50,15,0,'bowl','p_cs_platestew01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('foodwhitelogale','Whitelog Ale',0,65,0,'longbottle','p_glenswhisky01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('fridco','Fried Duck & Crispy Potato',51,3,0,'bowl','','',0,4,0,0,9,0,0,0,0,0,0,'',''),('friedchicken','Fried Chicken',19,0,0,'eat','p_cs_duckmeat01x','',0,0,0,0,10,0,0,0,0,0,0,'',''),('friedtater','Fried Taters',22,0,0,'eat','p_cs_potatostewsmall01x','',0,0,0,0,5,0,0,0,0,0,0,'',''),('frostew','Frontier Stew',42,11,0,'bowl','','',0,2,0,0,11,0,0,0,0,0,0,'',''),('game','Game Meat',10,0,0,'eat','p_meatchunks01x','',0,0,0,0,-25,0,0,0,0,0,0,'',''),('gber','Ginger Beer',3,55,0,'shortbottle','p_bottlebeer01a_2','',0,4,0,0,9,0,0,0,0,0,0,'',''),('ginal','Ginger Ale',6,47,0,'shortbottle','p_bottlebeer01a','',0,3,0,0,12,0,0,0,0,0,0,'',''),('ginger_dracula','Ginger Dracula',44,1,0,'eat','p_bread05x','',0,15,0,0,15,0,0,0,0,0,0,'',''),('ginpor','Ginseng porridge',47,9,0,'bowl','','',0,7,0,0,10,0,0,0,0,0,0,'',''),('ginsengtea','Ginseng Tea',0,34,0,'drink_cup','p_cup01x','',0,10,0,0,5,0,0,0,0,0,0,'',''),('herbmed','Herbal Remedy',0,10,0,'syringe','p_bottlemedicine09x','',0,10,10,0,15,50,50,0,0,0,4500,'',''),('heroin','Heroin',0,-5,0,'syringe','p_bottlemedicine09x','PhotoMode_FilterModern10',120000,0,0,0,0,50,100,0,0,0,5000,'',''),('herptile','Herptile Meat',10,0,0,'eat','p_meatchunk_sm01x','',0,0,0,0,-35,0,0,0,0,0,0,'',''),('hochoc','Hot Chocolate',0,31,0,'drink_cup','p_teacup01x','',0,10,0,0,0,0,0,0,0,0,0,'',''),('honey','Honey',9,1,0,'eat','p_pickup_cheese01x','',0,5,0,0,24,0,0,0,0,0,0,'',''),('horsod','HoreHound Soda',6,41,0,'shortbottle','p_bottlebeer03x','',0,6,0,0,6,0,0,0,0,0,0,'',''),('iguanabits','Iguana on a Stick',19,-10,0,'eat','p_cs_meatstewsmall01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('jamango','Mango Jam',52,0,0,'eat','p_can01x','',0,9,0,0,42,0,0,0,0,0,0,'',''),('jambalaya','Jambalaya',59,11,0,'bowl','','',0,2,0,0,9,0,0,0,0,0,0,'',''),('jamblackcur','Black Currant Jam',51,0,0,'eat','p_can02x','',0,2,0,0,22,0,0,0,0,0,0,'',''),('jamblue','Blueberry Jam',54,0,0,'eat','p_can07x','',0,7,0,0,32,0,0,0,0,0,0,'',''),('jamlemon','Lemon Jam',59,0,0,'eat','p_can02x','',0,8,0,0,42,0,0,0,0,0,0,'',''),('jampeach','Peach Jam',52,0,0,'eat','p_can02x','',0,1,0,0,35,0,0,0,0,0,0,'',''),('jamplum','Creek Plum Jam',54,0,0,'eat','p_can01x','',0,5,0,0,32,0,0,0,0,0,0,'',''),('jamras','Raspberry Jam',49,0,0,'eat','p_can01x','',0,9,0,0,22,0,0,0,0,0,0,'',''),('jamstraw','Strawberry Jam',58,0,0,'eat','p_can02x','',0,5,0,0,5,0,0,0,0,0,0,'',''),('kitsup','Chicken & Carrot Soup',39,8,0,'bowl','','',0,3,0,0,18,0,0,0,0,0,0,'',''),('lemon','Lemon',5,9,0,'eat','p_lemon01x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('lemonad','Lemonade',3,65,0,'shortbottle','p_bottlebeer01a','',0,31,0,0,2,0,0,0,0,0,0,'',''),('lemonadmang','Mango Lemonade',3,67,0,'shortbottle','p_bottlebeer01a','',0,34,0,0,2,0,0,0,0,0,0,'',''),('lemonadstraw','Strawberry Lemonade',3,62,0,'shortbottle','p_bottlebeer01a','',0,37,0,0,2,0,0,0,0,0,0,'',''),('lemondblue','Blueberry Lemonade',3,68,0,'shortbottle','p_bottlebeer01a','',0,26,0,0,2,0,0,0,0,0,0,'',''),('lemondorange','Orange Lemonade',3,64,0,'shortbottle','p_bottlebeer01a','',0,18,0,0,2,0,0,0,0,0,0,'',''),('lemondpear','Pear Lemonade',3,66,0,'shortbottle','p_bottlebeer01a','',0,32,0,0,2,0,0,0,0,0,0,'',''),('lemondras','Raspberry Lemonade',3,61,0,'shortbottle','p_bottlebeer01a','',0,11,0,0,2,0,0,0,0,0,0,'',''),('lnitronectar','Lavey Nitro Nectar',0,0,0,'syringe','p_bottlemedicine09x','DEADEYE',5000,100,100,100,0,0,0,0,0,0,5000,'',''),('lovepotion','Love Potion',5,5,0,'syringe','p_bottlemedicine09x','PhotoMode_FilterModern01',120000,0,0,0,25,0,0,0,0,0,10000,'',''),('mango','Mango',8,7,0,'eat','p_mango01x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('martlemon','Lemon Martini',3,61,0,'shortbottle','p_bottlebeer02x','',0,11,0,0,2,220,80,0,0,0,0,'',''),('matcha_milk','Matcha Milk',4,45,0,'drink_cup','p_teacup01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('milk','Milk',0,8,0,'drink_cup','p_teacup01x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('milkhoney','Milk & Honey',15,45,0,'drink_cup','p_teacup01x','',0,10,0,0,19,0,0,0,0,0,0,'',''),('milksoup','Milkweed Chicken Soup',48,9,0,'bowl','','',0,5,0,0,7,0,0,0,0,0,0,'',''),('minbp','Minted Berry Pork Fry',49,9,0,'bowl','','',0,11,0,0,5,0,0,0,0,0,0,'',''),('mintfish','Berry Mint Fish Bake',37,9,0,'bowl','','',0,5,0,0,19,0,0,0,0,0,0,'',''),('miracleelixir','Mircale Elyxir',0,0,0,'syringe','p_bottlemedicine09x','',0,0,0,0,50,0,0,0,0,0,5000,'',''),('mircacleelyxir','Miracle Elixir',0,0,0,'syringe','p_bottlemedicine09x','PhotoMode_FilterModern03',120000,50,50,0,0,0,0,0,0,0,5000,'',''),('monroeelixir','Dr. Monroe Elixir',0,0,0,'syringe','p_bottlemedicine09x','DEADEYE',20000,50,50,50,50,50,50,0,0,0,5000,'',''),('monroeelixirp','Dr Monroe Elixir',-15,-15,0,'syringe','p_bottlemedicine09x','DEADEYE',10000,-50,0,0,-50,0,0,0,0,0,5000,'',''),('moonshine','Moonshine',15,59,0,'longbottle','s_inv_whiskey02x','PhotoMode_FilterGame16',290,35,60,80,25,150,390,0,0,0,0,'',''),('moonshineapple','Apple Moonshine',10,19,0,'longbottle','s_inv_whiskey02x','PhotoMode_FilterModern03',290,35,50,40,25,40,250,0,0,0,0,'',''),('moonshineraspberry','Raspberry Moonshine',5,19,0,'longbottle','s_inv_whiskey02x','PhotoMode_FilterModern01',290,25,40,30,25,30,140,0,0,0,0,'',''),('morphine','Morphine',0,-5,0,'syringe','p_bottlemedicine09x','DEADEYE',120000,0,0,0,50,50,50,0,0,0,3000,'',''),('muffinblue','Blueberry Muffin',36,0,0,'eat','p_bread05x','',0,5,0,0,5,0,0,0,0,0,0,'',''),('muskratpie','Muskrat Pie',12,-50,0,'eat','p_pie01x_slice','PlayerDrunk01',150,0,0,0,10,0,0,0,0,0,0,'',''),('Mutton','Mutton',10,0,0,'eat','s_meatbit_chunck_medium01x','',0,0,0,0,-45,0,0,0,0,0,0,'',''),('muttoncooked','Cooked Mutton',28,0,0,'eat','p_cs_meatstew01x','',0,0,0,0,10,0,0,0,0,0,0,'',''),('octavioelixir','The Octavio Elixir',0,0,0,'syringe','p_bottlemedicine09x','DEADEYE',20000,50,50,50,50,50,0,0,0,0,5000,'',''),('Oleander_Sage','Oleander Sage',-10,-10,0,'eat','s_inv_humbirdsage01cx','PlayerDrunkAberdeen',300,0,0,0,0,0,0,0,0,0,0,'',''),('opium','Opium',0,-5,0,'syringe','p_bottlemedicine09x','PhotoMode_FilterModern01',120000,0,0,0,50,50,100,0,0,0,10000,'',''),('orange','Orange',7,8,0,'eat','p_mango01x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('orangejuice','Orange Juice',6,42,0,'longbottle','p_bottlebeer01x','',0,2,0,0,1,0,0,0,0,0,0,'',''),('orblos','Orange blossom soda',4,55,0,'shortbottle','p_bottlebeer02x','',0,16,0,0,2,0,0,0,0,0,0,'',''),('pancakeschoco','Pancakes & Chocolate',45,5,0,'bowl','','',0,2,0,0,4,0,0,0,0,0,0,'',''),('pancakesfruit','Pancakes & Fruit',43,9,0,'bowl','','',0,2,0,0,4,0,0,0,0,0,0,'',''),('parasolcook','Parasol Schnitzel',34,4,0,'bowl','','',0,9,0,0,10,0,0,0,0,0,0,'',''),('pear','Pear',6,9,0,'eat','p_pear_01x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('pegg','Pickled Eggs',19,9,0,'longbottle','p_pickledeggs01x','',0,1,0,0,9,0,0,0,0,0,0,'',''),('pepsti','Peppermint Sticks',21,0,0,'eat','s_horsnack_peppermint01x','',0,0,0,0,4,0,0,0,0,0,0,'',''),('peyote','Peyote',0,0,0,'drink_cup','','playerdrugshalluc01',120,0,0,0,5,0,800,0,0,0,0,'',''),('pieapple','Apple Pie',49,6,0,'eat','p_pie01x_slice','',0,7,0,0,7,2,2,0,0,0,0,'',''),('pieblackberry','Black Berry Pie',48,3,0,'eat','p_pie01x_slice','',0,2,0,0,12,4,0,0,0,0,0,'',''),('piepumpkin','Pumpkin Pie',44,7,0,'eat','p_pie01x_slice','',0,5,0,0,9,3,2,0,0,0,0,'',''),('pieredraspberry','Red Raspberry Pie',49,12,0,'eat','p_pie01x_slice','',0,1,0,0,13,0,4,0,0,0,0,'',''),('pizza','Pizza',69,5,0,'bowl','','',0,12,0,0,11,0,0,0,0,0,0,'',''),('plutar','Plum tart',37,0,0,'eat','p_bread05x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('popo','Popcorn',32,0,0,'eat','s_candybag01x_red','',0,0,0,0,8,0,0,0,0,0,0,'',''),('popob','Popcorn With Butter',36,0,0,'eat','s_candybag01x_red','',0,0,0,0,8,0,0,0,0,0,0,'',''),('pork','Pork',10,0,0,'eat','s_meatbit_chunck_medium01x','',0,0,0,0,-25,0,0,0,0,0,0,'',''),('porkbacon','Bacon',19,-1,0,'eat','p_redefleshymeat01xa','',0,0,0,0,5,0,0,0,0,0,0,'',''),('porkcooked','Cooked Pork',35,-1,0,'eat','p_cs_meatstewsmall01x','',0,0,0,0,10,0,0,0,0,0,0,'',''),('porkwveg','Porkchops with Veggies',32,0,0,'bowl','p_cs_platestew02x_noanim','',0,0,0,0,9,0,0,0,0,0,0,'',''),('potato','Potato',5,-10,0,'eat','p_potato01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('Prairie_Poppy','Prairie Poppy',-10,-10,0,'eat','s_inv_prariepoppy01cx','playerdrugshalluc01',300,0,0,0,0,0,0,0,0,0,0,'',''),('primerib','Prime Rib',25,0,0,'eat','p_cs_meatstewsmall01x','',0,0,0,0,8,0,0,0,0,0,0,'',''),('raspberryale','Raspberry Ale',3,29,0,'longbottle','s_inv_whiskey02x','',0,5,0,0,2,0,0,0,0,0,0,'',''),('raspberrywater','Raspberry Water',0,32,0,'longbottle','p_bottlewine01x','',0,8,0,0,0,0,0,0,0,0,0,'',''),('rber','Root Beer',5,48,0,'shortbottle','p_bottlebeer01a_3','',0,9,0,0,10,0,0,0,0,0,0,'',''),('redgaro','Red sage and garlic roast',48,8,0,'bowl','','',0,8,0,0,6,0,0,0,0,0,0,'',''),('Red_Raspberry','Red Raspberry',-10,-10,0,'eat','s_inv_raspberry01bx','MP_DeathInk_Color04',300,0,0,0,0,0,0,0,0,0,0,'',''),('Red_Sage','Red Sage',-10,-10,0,'eat','s_inv_goldencurrant01bx','MP_SuddenDeath',300,0,0,0,0,0,0,0,0,0,0,'',''),('rocan','Rock Candy',22,0,0,'eat','s_candybag01x_blue','',0,0,0,0,6,0,0,0,0,0,0,'',''),('rpblacksoulgem','Black Soul Gem',0,0,0,'eat','s_meteoriteshard01x','PhotoMode_FilterVintage02',120,0,0,0,0,0,0,0,0,0,0,'',''),('rplessersoulgem','Lesser Soul Gem',0,0,0,'eat','s_pickup_quartzchunk_01x','PhotoMode_FilterGame03',120,0,0,0,0,0,0,0,0,0,0,'',''),('rum','Rum',2,59,0,'longbottle','p_bottleconklin01x','',0,2,0,30,5,30,60,0,0,0,0,'',''),('salesod','Sparkling Lemon Soda',3,57,0,'shortbottle','p_bottlebeer01a','',0,3,0,0,3,0,0,0,0,0,0,'',''),('sarsa','Sarsaprilla',5,59,0,'shortbottle','p_bottlebeer01a_3','',0,1,0,0,9,0,0,0,0,0,0,'',''),('satin_bloom','Satin Bloom',0,0,0,'sponge','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('scrambledeggs','Scrambled Eggs',21,1,0,'bowl','','',0,0,0,0,5,0,0,0,0,0,0,'',''),('scrambledeggsbacon','Scrambled Eggs with Bacon',23,0,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('seafood_gumbo','Seafood Gumbo',55,12,0,'bowl','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('sher','Sherry',0,41,0,'longbottle','mp005_p_mp_bottlebrandy01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('snakeoil','Snake Oil',-5,-5,0,'syringe','p_bottlemedicine09x','DEADEYE',15000,0,0,0,-5,50,100,0,0,0,5000,'',''),('sour_souls','Sour Souls',25,10,0,'eat','s_chocolatebar02x','',0,20,0,0,8,0,0,0,0,0,0,'',''),('spaghetti','Spaghetti with Meatballs',37,0,0,'bowl','p_stewplate01x','',0,0,0,0,7,0,0,0,0,0,0,'',''),('steak','Steak',36,0,0,'eat','p_meatchunk_sm02x','',0,0,0,0,10,0,0,0,0,0,0,'',''),('steakveg','Steak with Veggies',50,1,0,'bowl','','',0,0,0,0,10,0,0,0,0,0,0,'',''),('steak_and_mashers','Steak and Mashers',30,0,0,'eat','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('strawberry','Strawberry',5,4,0,'eat','p_bulb01x','',0,1,0,0,1,0,0,0,0,0,0,'',''),('strawsugar','Sugar Strawberry',19,10,0,'eat','p_blackberry01x','',0,8,0,0,1,0,0,0,0,0,0,'',''),('stringy','Stringy Meat',15,0,0,'eat','p_whitefleshymeat01xb','',0,0,0,0,-20,0,0,0,0,0,0,'',''),('strinhash','Stringy Meat Hash',32,2,0,'bowl','','',0,2,0,0,7,0,0,0,0,0,0,'',''),('tankertonic','Tanker Tonic',0,0,0,'syringe','p_bottlemedicine09x','DEADEYE',20000,0,0,0,100,100,50,0,0,0,5000,'',''),('tea','Tea',0,28,0,'drink_cup','p_cup01x','',0,25,0,0,0,0,0,0,0,0,0,'',''),('teabritish','British Tea',0,24,0,'drink_cup','p_cup01x','',0,2,0,0,0,0,0,0,0,0,0,'',''),('teasugar','Tea with Sugar',0,25,0,'drink_cup','p_cup01x','',0,22,0,0,0,0,0,0,0,0,0,'',''),('teddy_hot_chocolate','Teddy Bear Hot Chocolate',6,42,0,'drink_cup','p_cuptin01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('tequila','Tequila',3,33,0,'longbottle','p_bottleabsinthe01x','',0,3,2,0,4,9,0,0,0,0,0,'',''),('thickelixir','Thick Elixir',0,0,0,'syringe','p_bottlemedicine09x','DEADEYE',10000,-99,0,0,-99,0,0,0,0,0,5000,'',''),('tof','Toffee',23,0,0,'eat','s_re_chocolate_single','',0,0,0,0,6,0,0,0,0,0,0,'',''),('tomato1','Tomato',5,7,0,'eat','p_onionred01x','',0,4,0,0,3,0,0,0,0,0,0,'',''),('tombchili','Tombstone Chili',38,5,0,'bowl','','',0,7,0,0,11,0,0,0,0,0,0,'',''),('tylenol','Tylenol',0,0,0,'syringe','p_bottlemedicine09x','DEADEYE',60000,0,0,0,10,0,0,0,0,0,5000,'',''),('UniAppleCider','Apple Cider',0,65,0,'drink_cup','p_teacup01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('unique_happy_shot','Dr. Honey\'s Happy Shot',0,50,0,'syringe','p_bottlemedicine09x','PlayerDrugsHalluc01',120000,0,0,0,0,0,0,0,0,0,0,'',''),('unique_saline','Saline Bottle',0,120,0,'syringe','p_bottlemedicine09x','',0,0,0,0,0,0,0,0,0,0,5000,'',''),('unique_shoot','Dr. Kim\'s Medically Certified Liquid Cocaine',0,0,0,'syringe','p_bottlemedicine09x','',0,200,1000,1000,0,0,0,0,0,0,5000,'',''),('unique_sock','Dirty Socks',0,0,0,'syringe','p_bottlemedicine09x','',0,0,0,0,50,0,0,0,0,0,5000,'',''),('unique_tigerbalm','Tigerbalm',0,10,0,'syringe','p_bottlemedicine09x','',0,10,50,50,15,50,50,0,0,0,4500,'',''),('UniTurkyleg','Turkey Leg',55,10,0,'eat','s_meatbit_chunck_medium01x','',0,0,0,0,0,0,0,0,0,0,0,'',''),('vanillacake','Vanilla Cream Cake',39,0,0,'eat','p_pie01x_slice','',0,5,0,0,15,0,0,0,0,0,0,'',''),('venison','Venison',15,0,0,'eat','p_meatchunks01x_raw','',0,0,0,0,-25,0,0,0,0,0,0,'',''),('venmush','Venison and mushroom gravy',49,9,0,'bowl','','',0,5,0,0,15,0,0,0,0,0,0,'',''),('vodka','Vodka',3,27,0,'longbottle','proc_bottlejd01x','',0,4,4,0,2,9,0,0,0,0,0,'',''),('washrag','Washrag',0,0,0,'sponge','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('water','Bottled Water',0,22,0,'longbottle','p_bottlewine01x','',0,2,0,0,0,0,0,0,0,0,0,'',''),('whisky','Whiskey',3,32,0,'longbottle','s_inv_whiskey02x','',0,4,0,0,4,10,0,0,0,0,0,'',''),('wild_west_root_beer','Wild West Root Beer',0,30,0,'drink','','',0,0,0,0,0,0,0,0,0,0,0,'',''),('wilmite','Wild Mint Tea',4,57,0,'drink_cup','p_teacup01x','',0,32,0,0,10,0,0,0,0,0,0,'',''),('wine','Wine',5,47,0,'longbottle','p_bottlewine01x','',0,8,0,0,5,5,0,0,0,0,0,'',''),('witches_brew','Witches Brew',5,60,0,'drink_cup','p_cuptin01x','',0,25,0,0,20,0,0,0,0,0,0,'',''),('wojape','Wojape',37,8,0,'bowl','','',0,5,0,0,10,0,0,0,0,0,0,'',''),('yarmash','Yarrow and Potato Mash',52,9,0,'bowl','','',0,1,0,0,11,0,0,0,0,0,0,'','');
/*!40000 ALTER TABLE `fred_consumables` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `fred_metabolism`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fred_metabolism` (
  `charid` int(11) NOT NULL,
  `food` float NOT NULL DEFAULT 100,
  `water` float NOT NULL DEFAULT 100,
  `metabolism` int(11) NOT NULL DEFAULT 3500,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fred_metabolism`
--

LOCK TABLES `fred_metabolism` WRITE;
/*!40000 ALTER TABLE `fred_metabolism` DISABLE KEYS */;
/*!40000 ALTER TABLE `fred_metabolism` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_activity`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `ts` int(11) NOT NULL DEFAULT 0,
  `type` varchar(32) NOT NULL DEFAULT '',
  `detail` varchar(255) NOT NULL DEFAULT '',
  `actor` varchar(64) NOT NULL DEFAULT '',
  `pts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_pup_gang_activity_gang` (`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_activity`
--

LOCK TABLES `gang_activity` WRITE;
/*!40000 ALTER TABLE `gang_activity` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_activity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_blood_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_blood_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `charid` int(11) DEFAULT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `amount` int(11) NOT NULL DEFAULT 0 COMMENT 'positive = deposit, negative = spend',
  `reason` varchar(96) NOT NULL DEFAULT '',
  `ts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_blood_gang` (`gangid`,`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_blood_log`
--

LOCK TABLES `gang_blood_log` WRITE;
/*!40000 ALTER TABLE `gang_blood_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_blood_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_den_found`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_den_found` (
  `denid` int(11) NOT NULL,
  `gangid` int(11) NOT NULL,
  `ts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`denid`,`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_den_found`
--

LOCK TABLES `gang_den_found` WRITE;
/*!40000 ALTER TABLE `gang_den_found` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_den_found` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_dens`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_dens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) DEFAULT NULL,
  `houseid` int(11) DEFAULT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `h` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `stored` int(11) NOT NULL DEFAULT 0,
  `last_brew` int(11) NOT NULL DEFAULT 0,
  `last_raided` int(11) NOT NULL DEFAULT 0,
  `created_at` int(11) NOT NULL DEFAULT 0,
  `admin` tinyint(4) NOT NULL DEFAULT 0,
  `label` varchar(64) NOT NULL DEFAULT '',
  `cook_until` int(11) NOT NULL DEFAULT 0,
  `last_cook` int(11) NOT NULL DEFAULT 0,
  `last_seized` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_dens_house` (`houseid`),
  KEY `idx_pup_gang_dens_gang` (`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `gang_drug_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_drug_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `charid` int(11) DEFAULT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `kind` varchar(24) NOT NULL DEFAULT '',
  `amount` int(11) NOT NULL DEFAULT 0,
  `detail` varchar(160) NOT NULL DEFAULT '',
  `ts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_drug_gang` (`gangid`,`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_drug_log`
--

LOCK TABLES `gang_drug_log` WRITE;
/*!40000 ALTER TABLE `gang_drug_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_drug_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_factions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_factions` (
  `faction` varchar(32) NOT NULL,
  `points` int(11) NOT NULL DEFAULT 0 COMMENT 'accumulated, never decays',
  `updated_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_factions`
--

LOCK TABLES `gang_factions` WRITE;
/*!40000 ALTER TABLE `gang_factions` DISABLE KEYS */;
INSERT INTO `gang_factions` VALUES ('outlaws',0,0),('reapers',0,0),('syndicate',0,0);
/*!40000 ALTER TABLE `gang_factions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_members`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `charid` int(11) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `rank` int(11) NOT NULL DEFAULT 1,
  `points` int(11) NOT NULL DEFAULT 0 COMMENT 'personal contribution, for the members table',
  `joined_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_members_char` (`charid`),
  KEY `idx_pup_gang_members_gang` (`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_members`
--

LOCK TABLES `gang_members` WRITE;
/*!40000 ALTER TABLE `gang_members` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_meta`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_meta` (
  `k` varchar(50) NOT NULL,
  `v` varchar(50) NOT NULL,
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_meta`
--

LOCK TABLES `gang_meta` WRITE;
/*!40000 ALTER TABLE `gang_meta` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_meta` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_plants`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_plants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attacker` int(11) NOT NULL COMMENT 'gang that planted',
  `defender` int(11) NOT NULL COMMENT 'gang whose territory it is in',
  `territoryid` int(11) NOT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `startts` int(11) NOT NULL DEFAULT 0,
  `endts` int(11) NOT NULL DEFAULT 0,
  `status` varchar(16) NOT NULL DEFAULT 'active',
  PRIMARY KEY (`id`),
  KEY `idx_pup_gang_plants_status` (`status`),
  KEY `idx_pup_gang_plants_def` (`defender`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_plants`
--

LOCK TABLES `gang_plants` WRITE;
/*!40000 ALTER TABLE `gang_plants` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_plants` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_tables`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_tables` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) DEFAULT NULL,
  `houseid` int(11) NOT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `h` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `placed_by` int(11) NOT NULL DEFAULT 0,
  `placed_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_tables_gang` (`gangid`),
  KEY `idx_pup_gang_tables_house` (`houseid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_tables`
--

LOCK TABLES `gang_tables` WRITE;
/*!40000 ALTER TABLE `gang_tables` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_tables` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_territories`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_territories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `gangid` int(11) DEFAULT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `claimed_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_territories_name` (`name`),
  KEY `idx_pup_gang_territories_gang` (`gangid`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_territories`
--

LOCK TABLES `gang_territories` WRITE;
/*!40000 ALTER TABLE `gang_territories` DISABLE KEYS */;
INSERT INTO `gang_territories` VALUES (7,'Fort Mercer',NULL,-4203.0100,-3446.0500,40.0200,0),(8,'Fort Wallace',NULL,357.7900,1466.8200,179.2000,0),(10,'Lemoyne Fort',NULL,2454.5000,292.5000,70.3500,0);
/*!40000 ALTER TABLE `gang_territories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_traphouses`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_traphouses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) DEFAULT NULL,
  `houseid` int(11) DEFAULT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `h` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `stored` int(11) NOT NULL DEFAULT 0,
  `last_brew` int(11) NOT NULL DEFAULT 0,
  `last_raided` int(11) NOT NULL DEFAULT 0,
  `created_at` int(11) NOT NULL DEFAULT 0,
  `admin` tinyint(4) NOT NULL DEFAULT 0,
  `label` varchar(64) NOT NULL DEFAULT '',
  `cook_until` int(11) NOT NULL DEFAULT 0,
  `last_cook` int(11) NOT NULL DEFAULT 0,
  `last_seized` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_traphouses_house` (`houseid`),
  KEY `idx_pup_gang_traphouses_gang` (`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_traphouses`
--

LOCK TABLES `gang_traphouses` WRITE;
/*!40000 ALTER TABLE `gang_traphouses` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_traphouses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gang_wars`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gang_wars` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang_a` int(11) NOT NULL,
  `gang_b` int(11) NOT NULL,
  `score_a` int(11) NOT NULL DEFAULT 0,
  `score_b` int(11) NOT NULL DEFAULT 0,
  `startts` int(11) NOT NULL DEFAULT 0,
  `endts` int(11) NOT NULL DEFAULT 0,
  `status` varchar(16) NOT NULL DEFAULT 'active',
  `winner` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pup_gang_wars_a` (`gang_a`),
  KEY `idx_pup_gang_wars_b` (`gang_b`),
  KEY `idx_pup_gang_wars_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gang_wars`
--

LOCK TABLES `gang_wars` WRITE;
/*!40000 ALTER TABLE `gang_wars` DISABLE KEYS */;
/*!40000 ALTER TABLE `gang_wars` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gangs`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gangs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `faction` varchar(32) NOT NULL DEFAULT 'outlaws',
  `leader` int(11) NOT NULL COMMENT 'charidentifier of the founder/current boss',
  `points` int(11) NOT NULL DEFAULT 0,
  `money` int(11) NOT NULL DEFAULT 0 COMMENT 'gang treasury',
  `motd` varchar(255) NOT NULL DEFAULT '',
  `created_at` int(11) NOT NULL DEFAULT 0 COMMENT 'unix epoch',
  `last_activity` int(11) NOT NULL DEFAULT 0 COMMENT 'unix epoch, drives point decay',
  `last_mission` int(11) NOT NULL DEFAULT 0,
  `shortname` varchar(8) NOT NULL DEFAULT '',
  `stats` longtext DEFAULT NULL,
  `ranks` longtext DEFAULT NULL,
  `blipcolor` varchar(16) NOT NULL DEFAULT '',
  `bloodmoney` int(11) NOT NULL DEFAULT 0,
  `slots_bought` int(11) NOT NULL DEFAULT 0,
  `perks_bought` text DEFAULT NULL,
  `drug_name` varchar(48) DEFAULT NULL,
  `drug_icon` varchar(32) DEFAULT NULL,
  `drug_points` int(11) NOT NULL DEFAULT 0,
  `drug_earned` int(11) NOT NULL DEFAULT 0,
  `drug_nodes` text DEFAULT NULL,
  `drug_created` int(11) NOT NULL DEFAULT 0,
  `drug_seed_pending` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gangs_name` (`name`),
  KEY `idx_pup_gangs_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gangs`
--

LOCK TABLES `gangs` WRITE;
/*!40000 ALTER TABLE `gangs` DISABLE KEYS */;
/*!40000 ALTER TABLE `gangs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gunsmith_presets`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gunsmith_presets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) NOT NULL,
  `weapon` varchar(64) NOT NULL,
  `name` varchar(40) NOT NULL,
  `comps` longtext NOT NULL,
  `updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `char_weapon_name` (`charid`,`weapon`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gunsmith_presets`
--

LOCK TABLES `gunsmith_presets` WRITE;
/*!40000 ALTER TABLE `gunsmith_presets` DISABLE KEYS */;
/*!40000 ALTER TABLE `gunsmith_presets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `homestead_plants`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `homestead_plants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) NOT NULL,
  `crop` varchar(48) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `minutes_left` int(11) NOT NULL DEFAULT 0,
  `watered` tinyint(4) NOT NULL DEFAULT 0,
  `fertilised` tinyint(4) NOT NULL DEFAULT 0,
  `trimmed` tinyint(4) NOT NULL DEFAULT 0,
  `health` int(11) NOT NULL DEFAULT 100,
  `difficulty` int(11) NOT NULL DEFAULT 5,
  `restarts` int(11) NOT NULL DEFAULT 0,
  `ripe_minutes` int(11) NOT NULL DEFAULT 0,
  `planted_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_char` (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `homestead_plants`
--

LOCK TABLES `homestead_plants` WRITE;
/*!40000 ALTER TABLE `homestead_plants` DISABLE KEYS */;
/*!40000 ALTER TABLE `homestead_plants` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `homestead_stats`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `homestead_stats` (
  `charid` int(11) NOT NULL,
  `crop` varchar(48) NOT NULL,
  `planted` int(11) NOT NULL DEFAULT 0,
  `harvested` int(11) NOT NULL DEFAULT 0,
  `gathered` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`,`crop`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `homestead_stats`
--

LOCK TABLES `homestead_stats` WRITE;
/*!40000 ALTER TABLE `homestead_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `homestead_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hotel_rentals`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hotel_rentals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `hotel` varchar(50) NOT NULL,
  `room` varchar(50) NOT NULL,
  `charid` int(11) NOT NULL,
  `identifier` varchar(50) NOT NULL DEFAULT '',
  `guest` varchar(100) NOT NULL DEFAULT '',
  `tier` varchar(30) NOT NULL DEFAULT '',
  `rentedat` int(11) NOT NULL DEFAULT 0,
  `expiresat` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `hotelroom` (`hotel`,`room`),
  KEY `charid` (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `hotel_rentals`
--

LOCK TABLES `hotel_rentals` WRITE;
/*!40000 ALTER TABLE `hotel_rentals` DISABLE KEYS */;
/*!40000 ALTER TABLE `hotel_rentals` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hotel_settings`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hotel_settings` (
  `k` varchar(64) NOT NULL,
  `v` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `housing_activity`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `housing_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `houseid` int(11) NOT NULL,
  `ts` int(11) NOT NULL,
  `type` varchar(20) NOT NULL,
  `detail` varchar(191) NOT NULL DEFAULT '',
  `actor` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `housing_activity`
--

LOCK TABLES `housing_activity` WRITE;
/*!40000 ALTER TABLE `housing_activity` DISABLE KEYS */;
/*!40000 ALTER TABLE `housing_activity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `housing_auction_bids`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `housing_auction_bids` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `auctionid` int(11) NOT NULL,
  `charidentifier` int(11) NOT NULL,
  `identifier` varchar(64) NOT NULL DEFAULT '',
  `name` varchar(100) NOT NULL DEFAULT '',
  `amount` double NOT NULL,
  `ts` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `housing_auction_bids`
--

LOCK TABLES `housing_auction_bids` WRITE;
/*!40000 ALTER TABLE `housing_auction_bids` DISABLE KEYS */;
/*!40000 ALTER TABLE `housing_auction_bids` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `housing_auctions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `housing_auctions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `houseid` int(11) NOT NULL,
  `minbid` double NOT NULL,
  `endts` int(11) NOT NULL,
  `status` varchar(12) NOT NULL DEFAULT 'open',
  `topbid` double NOT NULL DEFAULT 0,
  `topcharid` int(11) DEFAULT NULL,
  `topname` varchar(100) NOT NULL DEFAULT '',
  `createdby` varchar(100) NOT NULL DEFAULT '',
  `createdts` int(11) NOT NULL,
  `topbank` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `housing_auctions`
--

LOCK TABLES `housing_auctions` WRITE;
/*!40000 ALTER TABLE `housing_auctions` DISABLE KEYS */;
/*!40000 ALTER TABLE `housing_auctions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `item_group`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `item_group` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `description` varchar(255) NOT NULL COMMENT 'Description of Item Group',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `item_group`
--

LOCK TABLES `item_group` WRITE;
/*!40000 ALTER TABLE `item_group` DISABLE KEYS */;
INSERT INTO `item_group` VALUES (1,'default'),(2,'medical'),(3,'foods'),(4,'tools'),(5,'weapons'),(6,'ammo'),(7,'documents'),(8,'animals'),(9,'valuables'),(10,'horse'),(11,'herbs');
/*!40000 ALTER TABLE `item_group` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `item_rarity`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `item_rarity` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `description` varchar(255) NOT NULL DEFAULT '' COMMENT 'Description of item rarity',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_item_rarity_name` (`name`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `item_rarity`
--

LOCK TABLES `item_rarity` WRITE;
/*!40000 ALTER TABLE `item_rarity` DISABLE KEYS */;
INSERT INTO `item_rarity` VALUES (1,'Common','Common item'),(2,'Uncommon','Uncommon item'),(3,'Rare','Rare item'),(4,'Epic','Epic item'),(5,'Legendary','Legendary item');
/*!40000 ALTER TABLE `item_rarity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `items`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `items` (
  `item` varchar(50) NOT NULL,
  `label` varchar(50) NOT NULL,
  `limit` int(11) NOT NULL DEFAULT 1,
  `can_remove` tinyint(1) NOT NULL DEFAULT 1,
  `type` varchar(50) DEFAULT 'item_standard',
  `usable` tinyint(1) DEFAULT 0,
  `useExpired` tinyint(1) DEFAULT 0 COMMENT 'if 0 Item cant be used when expired if 1 can be used also metadata can override this',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `groupId` int(10) unsigned NOT NULL DEFAULT 1 COMMENT 'Item Group ID for Filtering',
  `rarityId` int(10) unsigned NOT NULL DEFAULT 1 COMMENT 'Item Rarity ID for filtering',
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT '{}',
  `desc` varchar(5550) NOT NULL DEFAULT 'nice item',
  `degradation` int(11) NOT NULL DEFAULT 0 COMMENT 'if 0 Item do not degrade use a positive number (in minutes) to enable degradation min is 1',
  `durability` int(11) DEFAULT NULL COMMENT 'Optional default/max durability',
  `instructions` longtext CHARACTER SET armscii8 COLLATE armscii8_general_ci DEFAULT NULL COMMENT 'you can add a item instruction like where to find it how to use it',
  `weight` decimal(20,2) NOT NULL DEFAULT 1.00,
  PRIMARY KEY (`item`) USING BTREE,
  UNIQUE KEY `id` (`id`) USING BTREE,
  KEY `FK_items_item_group` (`groupId`) USING BTREE,
  KEY `FK_items_item_rarity` (`rarityId`) USING BTREE,
  CONSTRAINT `FK_items_item_group` FOREIGN KEY (`groupId`) REFERENCES `item_group` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_items_item_rarity` FOREIGN KEY (`rarityId`) REFERENCES `item_rarity` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `metadata` CHECK (json_valid(`metadata`))
) ENGINE=InnoDB AUTO_INCREMENT=33458 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `items`
--

LOCK TABLES `items` WRITE;
/*!40000 ALTER TABLE `items` DISABLE KEYS */;
INSERT INTO `items` VALUES ('absinthe','Absinthe',10,1,'item_standard',1,0,733,1,1,'{}','An anise-flavoured spirit derived from several plants, including the flowers and leaves of Artemisia absinthium',0,NULL,NULL,1.00),('accessories','Accessories',50,1,'item_standard',1,0,1441,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('acid','Acid',50,1,'item_standard',0,0,1,1,1,'{}','A corrosive substance used for various purposes.',0,NULL,NULL,1.00),('Agarita','Agarita',10,1,'item_standard',1,0,2,1,1,'{}','A flowering plant found in the wild, known for its medicinal properties.',0,NULL,NULL,1.00),('Agarita_Seed','Agarita Seed',50,1,'item_standard',1,0,3,1,1,'{}','A seed that can be planted to grow Agarita plants.',0,NULL,NULL,1.00),('Alaskan_Ginseng','Alaskan Ginseng',50,1,'item_standard',1,0,4,1,1,'{}','A knobbly northern root. Doctors and tonic sellers pay well for it.',0,NULL,NULL,1.00),('Alaskan_Ginseng_Seed','Alaskan Ginseng Seed',50,1,'item_standard',1,0,5,1,1,'{}','Plant in cool ground and wait. Alaskan ginseng is slow and fussy.',0,NULL,NULL,1.00),('alcohol','Alcohol',50,1,'item_standard',1,0,6,1,1,'{}','An intoxicating beverage consumed for recreational purposes.',0,NULL,NULL,1.00),('aligatormeat','Alligator Meat',20,1,'item_standard',1,0,7,1,1,'{}','Raw meat obtained from hunting alligators, suitable for cooking.',0,NULL,NULL,1.00),('aligators','Alligator Hide',10,1,'item_standard',1,0,8,1,1,'{}','Plated, leathery hide for boots and bags.',0,NULL,NULL,3.00),('aligatorto','Alligator Tooth',25,1,'item_standard',1,0,9,1,1,'{}','A conical tooth from an alligator.',0,NULL,NULL,0.05),('American_Ginseng','American Ginseng',50,1,'item_standard',1,0,10,1,1,'{}','A forked root from the eastern woods, dried and sold as a cure-all.',0,NULL,NULL,1.00),('American_Ginseng_Seed','American Ginseng Seed',50,1,'item_standard',1,0,11,1,1,'{}','Seed for a bed of American ginseng. Likes shade and patience.',0,NULL,NULL,1.00),('ammoarrmownormal','Normal Arrow Ammo',10,1,'item_standard',1,0,1139,1,1,'{}','nice item',0,NULL,NULL,1.00),('ammoarrowdynamite','Arrow Dynamite',10,1,'item_standard',1,0,13,1,1,'{}','An explosive arrow designed to cause significant damage upon impact.',0,NULL,NULL,1.00),('ammoarrowfire','Arrow Fire',10,1,'item_standard',1,0,14,1,1,'{}','An arrow equipped with a flaming tip, capable of setting targets on fire.',0,NULL,NULL,1.00),('ammoarrowimproved','Arrow Improved',10,1,'item_standard',1,0,15,1,1,'{}','An upgraded arrow with improved accuracy and damage.',0,NULL,NULL,1.00),('ammoarrownormal','Arrow Normal',10,1,'item_standard',1,0,12,1,1,'{}','A standard arrow used with bows for hunting and combat.',0,NULL,NULL,1.00),('ammoarrowpoison','Arrow Poison',10,1,'item_standard',1,0,16,1,1,'{}','An arrow coated with a poisonous substance, capable of inflicting additional damage over time.',0,NULL,NULL,1.00),('ammoarrowsmallgame','Arrow Small Game',10,1,'item_standard',1,0,17,1,1,'{}','A specialized arrow designed for hunting small game without damaging their pelts.',0,NULL,NULL,1.00),('ammobolahawk','Bola Ammo Hawk',10,1,'item_standard',1,0,18,1,1,'{}','A projectile consisting of weights attached to ropes, used to immobilize targets.',0,NULL,NULL,1.00),('ammobolainterwired','Bola Ammo Interwired',10,1,'item_standard',1,0,19,1,1,'{}','A reinforced bola ammunition with interwoven materials, providing enhanced durability.',0,NULL,NULL,1.00),('ammobolaironspiked','Bola Ammo Ironspiked',10,1,'item_standard',1,0,20,1,1,'{}','A bola ammunition featuring iron spikes, inflicting additional damage to immobilized targets.',0,NULL,NULL,1.00),('ammobolla','Bolla Ammo',10,1,'item_standard',1,0,21,1,1,'{}','A weighted throwing weapon used to ensnare and immobilize targets.',0,NULL,NULL,1.00),('ammodynamite','Dynamite Ammo',10,1,'item_standard',1,0,22,1,1,'{}','An explosive device with a short fuse, capable of causing significant damage.',0,NULL,NULL,1.00),('ammoelephant','Elephant Rifle Ammo',10,1,'item_standard',1,0,23,1,1,'{}','Ammunition specifically designed for powerful elephant rifles, providing superior stopping power.',0,NULL,NULL,1.00),('ammoknives','Knives Ammo',10,1,'item_standard',1,0,24,1,1,'{}','Ammunition for a throwing knife, used as a versatile and silent weapon.',0,NULL,NULL,1.00),('ammomolotov','Molotov Ammo',10,1,'item_standard',1,0,25,1,1,'{}','A glass bottle filled with flammable liquid, designed to burst into flames upon impact.',0,NULL,NULL,1.00),('ammopistolexplosive','Pistol Ammo Explosive',10,1,'item_standard',1,0,26,1,1,'{}','Ammunition for a pistol with explosive properties, causing significant damage upon impact.',0,NULL,NULL,1.00),('ammopistolexpress','Pistol Ammo Express',10,1,'item_standard',1,0,27,1,1,'{}','High-velocity ammunition specifically designed for pistols, providing increased range and damage.',0,NULL,NULL,1.00),('ammopistolnormal','Pistol Ammo Normal',10,1,'item_standard',1,0,28,1,1,'{}','Standard ammunition used with pistols for self-defense and combat.',0,NULL,NULL,1.00),('ammopistolsplitpoint','Pistol Ammo Splitpoint',10,1,'item_standard',1,0,29,1,1,'{}','Ammunition with a split point tip, designed to cause more damage and improve accuracy.',0,NULL,NULL,1.00),('ammopistolvelocity','Pistol Ammo Velocity',10,1,'item_standard',1,0,30,1,1,'{}','Ammunition designed to enhance the velocity and accuracy of pistol shots.',0,NULL,NULL,1.00),('ammopoisonbottle','Poison Bottle Ammo',10,1,'item_standard',1,0,31,1,1,'{}','A glass bottle filled with a poisonous substance, used to coat weapons and inflict additional damage.',0,NULL,NULL,1.00),('ammorepeaterexplosive','Repeater Ammo Explosive',10,1,'item_standard',1,0,32,1,1,'{}','Ammunition for a repeater rifle with explosive properties, causing significant damage upon impact.',0,NULL,NULL,1.00),('ammorepeaterexpress','Repeater Ammo Express',10,1,'item_standard',1,0,33,1,1,'{}','High-velocity ammunition specifically designed for repeater rifles, providing increased range and damage.',0,NULL,NULL,1.00),('ammorepeaternormal','Repeater Ammo Normal',10,1,'item_standard',1,0,34,1,1,'{}','Standard ammunition used with repeater rifles for self-defense and combat.',0,NULL,NULL,1.00),('ammorepeatersplitpoint','Repeater Ammo Splitpoint',10,1,'item_standard',1,0,35,1,1,'{}','Ammunition with a split point tip, designed to cause more damage and improve accuracy when used with repeater rifles.',0,NULL,NULL,1.00),('ammorepeatervelocity','Repeater Ammo Velocity',10,1,'item_standard',1,0,36,1,1,'{}','Ammunition designed to enhance the velocity and accuracy of repeater rifle shots.',0,NULL,NULL,1.00),('ammorevolverexplosive','Revolver Ammo Explosive',10,1,'item_standard',1,0,37,1,1,'{}','Ammunition for a revolver with explosive properties, causing significant damage upon impact.',0,NULL,NULL,1.00),('ammorevolverexpress','Revolver Ammo Express',10,1,'item_standard',1,0,38,1,1,'{}','High-velocity ammunition specifically designed for revolvers, providing increased range and damage.',0,NULL,NULL,1.00),('ammorevolvernormal','Revolver Ammo Normal',10,1,'item_standard',1,0,39,1,1,'{}','Standard ammunition used with revolvers for self-defense and combat.',0,NULL,NULL,1.00),('ammorevolversplitpoint','Revolver Ammo Splitpoint',10,1,'item_standard',1,0,40,1,1,'{}','Ammunition with a split point tip, designed to cause more damage and improve accuracy when used with revolvers.',0,NULL,NULL,1.00),('ammorevolvervelocity','Revolver Ammo Velocity',10,1,'item_standard',1,0,41,1,1,'{}','Ammunition designed to enhance the velocity and accuracy of revolver shots.',0,NULL,NULL,1.00),('ammorifleexplosive','Rifle Ammo Explosive',10,1,'item_standard',1,0,42,1,1,'{}','Ammunition for a rifle with explosive properties, causing significant damage upon impact.',0,NULL,NULL,1.00),('ammorifleexpress','Rifle Ammo Express',10,1,'item_standard',1,0,43,1,1,'{}','High-velocity ammunition specifically designed for rifles, providing increased range and damage.',0,NULL,NULL,1.00),('ammoriflenormal','Rifle Ammo Normal',10,1,'item_standard',1,0,44,1,1,'{}','Standard ammunition used with rifles for self-defense and combat.',0,NULL,NULL,1.00),('ammoriflesplitpoint','Rifle Ammo Splitpoint',10,1,'item_standard',1,0,45,1,1,'{}','Ammunition with a split point tip, designed to cause more damage and improve accuracy when used with rifles.',0,NULL,NULL,1.00),('ammoriflevelocity','Rifle Ammo Velocity',10,1,'item_standard',1,0,46,1,1,'{}','Ammunition designed to enhance the velocity and accuracy of rifle shots.',0,NULL,NULL,1.00),('ammoshotgunexplosive','Shotgun Ammo Explosive',10,1,'item_standard',1,0,47,1,1,'{}','Ammunition for a shotgun with explosive properties, causing significant damage upon impact.',0,NULL,NULL,1.00),('ammoshotgunincendiary','Shotgun Ammo Incendiary',10,1,'item_standard',1,0,48,1,1,'{}','Ammunition designed to ignite targets, causing them to burst into flames.',0,NULL,NULL,1.00),('ammoshotgunnormal','Shotgun Ammo Normal',10,1,'item_standard',1,0,49,1,1,'{}','Standard ammunition used with shotguns for self-defense and combat.',0,NULL,NULL,1.00),('ammoshotgunslug','Shotgun Ammo Slug',10,1,'item_standard',1,0,50,1,1,'{}','Ammunition with a single solid projectile, offering increased accuracy and range for shotguns.',0,NULL,NULL,1.00),('ammotomahawk','Tomahawk Ammo',10,1,'item_standard',1,0,51,1,1,'{}','Ammo used for Tomahawk throwing weapons',0,NULL,NULL,1.00),('ammovarmint','Varmint Ammo',10,1,'item_standard',1,0,52,1,1,'{}','Ammo used for Varmint rifles',0,NULL,NULL,1.00),('ammovarminttranq','Varmint Tranquilizer Ammo',10,1,'item_standard',1,0,53,1,1,'{}','Ammo used for tranquilizing animals with Varmint rifles',0,NULL,NULL,1.00),('ammovoldynamite','Volatile Dynamite Ammo',10,1,'item_standard',1,0,54,1,1,'{}','Ammo used for crafting Volatile Dynamite',0,NULL,NULL,1.00),('ammovolmolotov','Volatile Molotov Ammo',10,1,'item_standard',1,0,55,1,1,'{}','Ammo used for crafting Volatile Molotovs',0,NULL,NULL,1.00),('animal_crawfish','Crawfish',10,1,'item_standard',1,0,958,1,1,'{}','A small freshwater crustacean.',0,NULL,NULL,1.00),('antipoison','Antipoison',20,1,'item_standard',1,0,56,1,1,'{}','A medicine used to counteract the effects of poison',0,NULL,NULL,1.00),('antipoison2','Anti Snake Poison',20,1,'item_standard',1,0,57,1,1,'{}','A poison used to fend off snakes',0,NULL,NULL,1.00),('antique_jewelry_box','Antique Jewelry Box',5,1,'item_standard',0,0,4856,1,1,'{}','An ornate antique jewelry box.',0,NULL,NULL,1.00),('aplic','Fresh Apple',20,1,'item_standard',1,0,1962,1,1,'{}','nice item',0,NULL,NULL,1.00),('apple','Apple',50,1,'item_standard',1,0,58,1,1,'{}','Crisp and a little sour. Good eating, better in a pie.',0,NULL,NULL,1.00),('applebarrel','Apple Barrel',20,1,'item_standard',1,0,59,1,1,'{}','A barrel filled with fresh apples',0,NULL,NULL,1.00),('applebasket','Apple Basket',20,1,'item_standard',1,0,60,1,1,'{}','A basket filled with fresh apples',0,NULL,NULL,1.00),('appleCrumbMash','Minty Berry Mash',10,1,'item_standard',1,0,61,1,1,'{}','A mashed mixture of mint and berries used for crafting Moonshine',0,NULL,NULL,1.00),('appleCrumbMoonshine','Minty Berry Moonshine',10,1,'item_standard',1,0,62,1,1,'{}','A strong alcoholic beverage made from mint and berries',0,NULL,NULL,1.00),('apple_barrel','Apple Barrel',20,1,'item_standard',1,0,63,1,1,'{}','A barrel filled with fresh apples',0,NULL,NULL,1.00),('apple_basket','Apple Basket',20,1,'item_standard',1,0,64,1,1,'{}','A basket filled with fresh apples',0,NULL,NULL,1.00),('Apple_Seed','Apple Seed',50,1,'item_standard',1,0,65,1,1,'{}','A pip from a good apple. Plant it and you will have a tree in time.',0,NULL,NULL,1.00),('apsod','Apple Soda',25,1,'item_standard',1,0,2056,1,1,'{}','nice item',0,NULL,NULL,1.00),('armadilloc','Armadillo Claw',25,1,'item_standard',1,0,66,1,1,'{}','A digging claw from an armadillo.',0,NULL,NULL,0.05),('armadillos','Armadillo Shell',10,1,'item_standard',1,0,67,1,1,'{}','The banded shell of an armadillo.',0,NULL,NULL,0.60),('armor','Armor',50,1,'item_standard',1,0,1450,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('art_golden_chalice','Golden Chalice',5,1,'item_standard',0,0,4857,1,1,'{}','A ceremonial golden cup.',0,NULL,NULL,1.00),('asnakes','Fer-de-Lance Skin',10,1,'item_standard',1,0,68,1,1,'{}','A diamond-backed skin from a fer-de-lance.',0,NULL,NULL,0.30),('axe_wep','Woodcutter\'s Axe',1,1,'item_standard',1,0,30508,1,1,'{}','A blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('a_c_fishbluegil_01_ms','Medium Bluegil',10,1,'item_standard',0,0,69,1,1,'{}','A medium-sized Bluegil fish.',0,NULL,NULL,1.00),('a_c_fishbluegil_01_sm','Small Bluegil',5,1,'item_standard',0,0,70,1,1,'{}','A small Bluegil fish.',0,NULL,NULL,1.00),('a_c_fishbullheadcat_01_ms','Medium Bullhead',10,1,'item_standard',0,0,71,1,1,'{}','A medium-sized Bullhead fish.',0,NULL,NULL,1.00),('a_c_fishbullheadcat_01_sm','Small Bullhead',5,1,'item_standard',0,0,72,1,1,'{}','A small Bullhead fish.',0,NULL,NULL,1.00),('a_c_fishchainpickerel_01_ms','Medium Pickerel',10,1,'item_standard',0,0,73,1,1,'{}','A medium-sized Pickerel fish.',0,NULL,NULL,1.00),('a_c_fishchainpickerel_01_sm','Small Pickerel',5,1,'item_standard',0,0,74,1,1,'{}','A small Pickerel fish.',0,NULL,NULL,1.00),('a_c_fishchannelcatfish_01_lg','Channel Catfish (Large)',10,1,'item_standard',0,0,1012,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishchannelcatfish_01_xl','Channel Catfish (Extra Large)',10,1,'item_standard',0,0,1013,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishlakesturgeon_01_lg','Lake Sturgeon (Large)',10,1,'item_standard',0,0,1014,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishlargemouthbass_01_lg','Large Mouth Bass (Large)',10,1,'item_standard',0,0,1015,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishlargemouthbass_01_ms','Largemouth Bass',10,1,'item_standard',0,0,75,1,1,'{}','A large Largemouth Bass fish.',0,NULL,NULL,1.00),('a_c_fishlongnosegar_01_lg','Long Nose Gar (Large)',10,1,'item_standard',0,0,1016,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishmuskie_01_lg','Muskie (Large)',10,1,'item_standard',0,0,1017,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishnorthernpike_01_lg','Northern Pike (Large)',10,1,'item_standard',0,0,1018,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishperch_01_ms','Medium Perch',10,1,'item_standard',0,0,76,1,1,'{}','A medium-sized Perch fish.',0,NULL,NULL,1.00),('a_c_fishperch_01_sm','Small Perch',5,1,'item_standard',0,0,77,1,1,'{}','A small Perch fish.',0,NULL,NULL,1.00),('a_c_fishrainbowtrout_01_lg','Rainbow Trout (Large)',10,1,'item_standard',0,0,1019,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishrainbowtrout_01_ms','Rainbow Trout',10,1,'item_standard',0,0,78,1,1,'{}','A Rainbow Trout fish.',0,NULL,NULL,1.00),('a_c_fishredfinpickerel_01_ms','Medium Redfin Pickerel',10,1,'item_standard',0,0,79,1,1,'{}','A medium-sized Redfin Pickerel fish.',0,NULL,NULL,1.00),('a_c_fishredfinpickerel_01_sm','Small Redfin Pickerel',5,1,'item_standard',0,0,80,1,1,'{}','A small Redfin Pickerel fish.',0,NULL,NULL,1.00),('a_c_fishrockbass_01_ms','Medium Rockbass',10,1,'item_standard',0,0,81,1,1,'{}','A medium-sized Rockbass fish.',0,NULL,NULL,1.00),('a_c_fishrockbass_01_sm','Small Rockbass',5,1,'item_standard',0,0,82,1,1,'{}','A small Rockbass fish.',0,NULL,NULL,1.00),('a_c_fishsalmonsockeye_01_lg','Salmon Sockeye (Large)',10,1,'item_standard',0,0,1020,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishsalmonsockeye_01_ml','Salmon Sockeye (Medium-Large)',10,1,'item_standard',0,0,1021,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishsalmonsockeye_01_ms','Sockeye Salmon',10,1,'item_standard',0,0,83,1,1,'{}','A Sockeye Salmon fish.',0,NULL,NULL,1.00),('a_c_fishsmallmouthbass_01_lg','Small Mouth Bass (Large)',10,1,'item_standard',0,0,1022,1,1,'{}','nice item',0,NULL,NULL,1.00),('a_c_fishsmallmouthbass_01_ms','Smallmouth Bass',10,1,'item_standard',0,0,84,1,1,'{}','A small and tasty bass fish.',0,NULL,NULL,1.00),('bacon','Bacon',10,1,'item_standard',1,0,734,1,1,'{}','Bacon what else do you need to know?',0,NULL,NULL,1.00),('badgers','Badger Pelt',10,1,'item_standard',1,0,85,1,1,'{}','A grizzled pelt; the hair makes good shaving brushes.',0,NULL,NULL,0.60),('bait','Bait',20,1,'item_standard',1,0,86,1,1,'{}','Used as bait to attract fish while fishing.',0,NULL,NULL,1.00),('bakepear','Baked Pear',25,1,'item_standard',1,0,2083,1,1,'{}','nice item',0,NULL,NULL,1.00),('banachoco','Chocolate Banana',25,1,'item_standard',1,0,2084,1,1,'{}','nice item',0,NULL,NULL,1.00),('banafried','Fried Banana',25,1,'item_standard',1,0,2085,1,1,'{}','nice item',0,NULL,NULL,1.00),('banana','Banana',50,1,'item_standard',1,0,87,1,1,'{}','A delicious and nutritious tropical fruit.',0,NULL,NULL,1.00),('bandage','Bandage',20,1,'item_standard',1,0,88,1,1,'{}','A medical item used to dress wounds.',0,NULL,NULL,1.00),('bandage_2','Bandage',20,1,'item_standard',1,0,89,1,1,'{}','A medical item used to dress wounds.',0,NULL,NULL,1.00),('banktools','Safe Tools',10,1,'item_standard',1,0,2406,1,1,'{}','nice item',0,NULL,NULL,1.00),('barberscissors','Barber\'s Scissors',1,1,'item_standard',1,0,22489,1,1,'{}','Sharp, thin and steel. Everything a man needs to make a stranger presentable.',0,NULL,NULL,0.30),('barrel','Barrel',10,1,'item_standard',1,0,90,1,1,'{}','A container made of wood or metal used for storing or transporting goods.',0,NULL,NULL,1.00),('barwa','Barley Water',25,1,'item_standard',1,0,2149,1,1,'{}','nice item',0,NULL,NULL,1.00),('batter','Batter',25,1,'item_standard',0,0,2770,1,1,'{}','nice item',0,NULL,NULL,1.00),('bat_c','Bat',20,1,'item_standard',1,0,91,1,1,'{}','A whole bat, wings folded.',0,NULL,NULL,0.10),('Bay_Bolete','Bay Bolete',10,1,'item_standard',1,0,92,1,1,'{}','An edible mushroom with a brown cap and yellow pores.',0,NULL,NULL,1.00),('Bay_Bolete_Seed','Bay Bolete Seed',50,1,'item_standard',1,0,93,1,1,'{}','A seed that can be planted to grow Bay Bolete mushrooms.',0,NULL,NULL,1.00),('bbears','Black Bear Hide',10,1,'item_standard',1,0,94,1,1,'{}','A glossy black hide from a black bear.',0,NULL,NULL,3.00),('bbirdb','Cormorant Beak',25,1,'item_standard',1,0,95,1,1,'{}','A hooked beak from a cormorant.',0,NULL,NULL,0.05),('bbirdf','Cormorant Feather',50,1,'item_standard',1,0,96,1,1,'{}','A dark, oily feather from a cormorant.',0,NULL,NULL,0.05),('bcandle','Bottle Candle',20,1,'item_standard',1,0,97,1,1,'{}','A candle made from a glass bottle.',0,NULL,NULL,1.00),('bearbench','Bear Bench',20,1,'item_standard',1,0,98,1,1,'{}','A bench made from the hide and bones of a bear.',0,NULL,NULL,1.00),('bearc','Bear Claw',25,1,'item_standard',1,0,99,1,1,'{}','A curved black claw from a bear.',0,NULL,NULL,0.10),('bearstan','Bearstan',25,1,'item_standard',0,0,2642,1,1,'{}','nice item',0,NULL,NULL,1.00),('beart','Bear Tooth',25,1,'item_standard',1,0,100,1,1,'{}','A long canine from a bear.',0,NULL,NULL,0.10),('beartrap','Hunting Trap',3,1,'item_standard',1,0,735,1,1,'{}','A heavy sprung trap. Set it on open ground, put a lure in it and wait for something big.',0,NULL,NULL,4.00),('bear_bench','Bear Bench',20,1,'item_standard',1,0,101,1,1,'{}','A bench made from the hide and bones of a bear.',0,NULL,NULL,1.00),('beavertail','Beaver Tail',25,1,'item_standard',1,0,102,1,1,'{}','A flat, scaly tail. Trappers roast them.',0,NULL,NULL,0.30),('beawers','Beaver Pelt',10,1,'item_standard',1,0,103,1,1,'{}','A dense, water-shedding pelt. Hatters want every one they can get.',0,NULL,NULL,1.00),('beef','Beef',20,1,'item_standard',1,0,104,1,1,'{}','Fresh and tender beef meat.',0,NULL,NULL,1.00),('beefjerky','Beef Jerky',20,1,'item_standard',1,0,105,1,1,'{}','Dried and seasoned beef meat.',0,NULL,NULL,1.00),('beer','Beer',10,1,'item_standard',1,0,106,1,1,'{}','An alcoholic beverage brewed from grains.',0,NULL,NULL,1.00),('beerbox','Beer Box',20,1,'item_standard',1,0,107,1,1,'{}','A container holding multiple bottles of beer.',0,NULL,NULL,1.00),('belts','Belts',50,1,'item_standard',1,0,1444,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('belt_buckles','Buckle',50,1,'item_standard',1,0,1442,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('benmelam','Benmelam',25,1,'item_standard',0,0,2585,1,1,'{}','nice item',0,NULL,NULL,1.00),('berglaz','Berry Glazed Game',25,1,'item_standard',1,0,2073,1,1,'{}','nice item',0,NULL,NULL,1.00),('berry_goodness','Berry Goodness',25,1,'item_standard',1,0,16470,3,4,'{}','Too red to be berries alone.',0,NULL,NULL,1.00),('bigchest','Big Chest',1,1,'item_standard',1,0,108,1,1,'{}','A large chest for storing items.',0,NULL,NULL,1.00),('biggame','Big Game Meat',20,1,'item_standard',1,0,109,1,1,'{}','A raw, bloody cut from a large animal. Wolves and big cats follow the smell for miles.',0,NULL,NULL,0.80),('biggamecooked','Big Game Chops',25,1,'item_standard',1,0,2015,1,1,'{}','nice item',0,NULL,NULL,1.00),('biggtent','Big Man Tent',25,1,'item_standard',0,0,2743,1,1,'{}','nice item',0,NULL,NULL,1.00),('bigmedbo','Medical Box',20,1,'item_standard',1,0,4330,1,1,'{}','nice item',0,NULL,NULL,1.00),('bigtor','Mountain Torch',25,1,'item_standard',0,0,2681,1,1,'{}','nice item',0,NULL,NULL,1.00),('bigvau','Bigvau',25,1,'item_standard',0,0,2694,1,1,'{}','nice item',0,NULL,NULL,1.00),('Big_Leather','Big Leather',10,1,'item_standard',1,0,110,1,1,'{}','Large piece of leather.',0,NULL,NULL,1.00),('bird','Bird Meat',20,1,'item_standard',1,0,111,1,1,'{}','Breast and thigh off a bird. Quick to cook over a small fire.',0,NULL,NULL,0.30),('birdcall','Bird Call',5,1,'item_standard',1,0,2826,1,1,'{}','nice item',0,NULL,NULL,1.00),('birdmeatcook','Cooked Birdmeat',25,1,'item_standard',1,0,2010,1,1,'{}','nice item',0,NULL,NULL,1.00),('biscuitbox','Biscuitbox',10,1,'item_standard',1,0,736,1,1,'{}','A box of assorted biscuits.',0,NULL,NULL,1.00),('bisonhorn','Bison Horn',25,1,'item_standard',1,0,112,1,1,'{}','A short, thick horn from a bison.',0,NULL,NULL,0.50),('bisons','Bison pelt',20,1,'item_standard',1,0,113,1,1,'{}','A pelt obtained from a bison.',0,NULL,NULL,1.00),('bisu','Campfire Biscuit',25,1,'item_standard',1,0,2080,1,1,'{}','nice item',0,NULL,NULL,1.00),('Bitter_Weed','Bitter Weed',10,1,'item_standard',1,0,114,1,1,'{}','A type of bitter herb.',0,NULL,NULL,1.00),('Bitter_Weed_Seed','Bitter Weed Seed',50,1,'item_standard',1,0,115,1,1,'{}','A seed that can be planted to grow bitter weed.',0,NULL,NULL,1.00),('blaber','Blackberry Water',25,1,'item_standard',1,0,2029,1,1,'{}','nice item',0,NULL,NULL,1.00),('blachar','Black Wood Chair',25,1,'item_standard',0,0,2654,1,1,'{}','nice item',0,NULL,NULL,1.00),('blaches','Black Chest',25,1,'item_standard',0,0,2496,1,1,'{}','nice item',0,NULL,NULL,1.00),('blackberryale','Black Berry Ale',10,1,'item_standard',1,0,116,1,1,'{}','An ale made from blackberries.',0,NULL,NULL,1.00),('blackytable','Square Table',25,1,'item_standard',0,0,2561,1,1,'{}','nice item',0,NULL,NULL,1.00),('Black_Berry','Blackberry',50,1,'item_standard',1,0,117,1,1,'{}','Dark, sweet and stains everything it touches.',0,NULL,NULL,1.00),('Black_Berry_Seed','Blackberry Seed',50,1,'item_standard',1,0,118,1,1,'{}','Starts a bramble of blackberries. Mind the thorns at picking time.',0,NULL,NULL,1.00),('Black_Currant','Black Currant',50,1,'item_standard',1,0,119,1,1,'{}','Small, sharp berries for jam, cordial or a sour face.',0,NULL,NULL,1.00),('Black_Currant_Seed','Black Currant Seed',50,1,'item_standard',1,0,120,1,1,'{}','Grows a currant bush that fruits in tight dark clusters.',0,NULL,NULL,1.00),('blanketbox','Blanket Box',20,1,'item_standard',1,0,121,1,1,'{}','A box used for storing blankets.',0,NULL,NULL,1.00),('blanket_box','Blanket Box',20,1,'item_standard',1,0,122,1,1,'{}','A box used for storing blankets.',0,NULL,NULL,1.00),('blaroychar','Black Carved Chair',25,1,'item_standard',0,0,2505,1,1,'{}','nice item',0,NULL,NULL,1.00),('bliirotab','Private Black Iron Table',25,1,'item_standard',0,0,2629,1,1,'{}','nice item',0,NULL,NULL,1.00),('Blood_Flower','Blood Flower',50,1,'item_standard',1,0,123,1,1,'{}','Bright red blooms on a tall stem. Pretty, but do not eat it.',0,NULL,NULL,1.00),('Blood_Flower_Seed','Blood Flower Seed',50,1,'item_standard',1,0,124,1,1,'{}','A pinch of seed for a row of red blood flowers.',0,NULL,NULL,1.00),('blood_money','Blood Money',500,1,'item_standard',0,0,3023,4,4,'{}','A band of notes gone brown at one corner. Nobody asks whose it was. Worth something to a crew that keeps a ledger.',0,NULL,NULL,1.00),('blood_vial','Vial of Blood',1,1,'item_standard',1,0,2836,1,1,'{}','A stoppered vial of human blood.',0,NULL,NULL,1.00),('blueberry','Blueberry',50,1,'item_standard',1,0,125,1,1,'{}','A small sweet fruit with a bluish color.',0,NULL,NULL,1.00),('bluejay_c','Blue Jay',20,1,'item_standard',1,0,126,1,1,'{}','A whole blue jay.',0,NULL,NULL,0.10),('bluepaint','Blue Paint',25,1,'item_standard',0,0,2767,1,1,'{}','nice item',0,NULL,NULL,1.00),('bmdresser','brown mirror dresser',20,1,'item_standard',1,0,127,1,1,'{}','A dresser with a brown mirror.',0,NULL,NULL,1.00),('boarmusk','Boar Tusk',25,1,'item_standard',1,0,128,1,1,'{}','A curved, yellowed tusk.',0,NULL,NULL,0.10),('boars','Boar pelt',20,1,'item_standard',1,0,129,1,1,'{}','A pelt obtained from a boar.',0,NULL,NULL,1.00),('boaskin','Boa Skin',10,1,'item_standard',1,0,130,1,1,'{}','A long, richly marked skin from a red boa.',0,NULL,NULL,0.50),('boiledegg','Boiled Egg',10,1,'item_standard',1,0,131,1,1,'{}','An egg cooked by boiling.',0,NULL,NULL,1.00),('bolts','Bolts',50,1,'item_standard',1,0,737,1,1,'{}','Metal bolts often used in construction.',0,NULL,NULL,1.00),('boobyb','Booby Beak',25,1,'item_standard',1,0,132,1,1,'{}','A pale blue beak from a booby.',0,NULL,NULL,0.05),('boobyf','Booby Feather',50,1,'item_standard',1,0,133,1,1,'{}','A brown feather from a red-footed booby.',0,NULL,NULL,0.05),('book','Book',1,1,'item_standard',1,0,134,1,1,'{}','A written or printed work consisting of pages.',0,NULL,NULL,1.00),('bookcase','Bookcase',20,1,'item_standard',1,0,1381,1,1,'{}','nice item',0,NULL,NULL,1.00),('boots','Boots',50,1,'item_standard',1,0,1445,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('boot_accessories','Spurs',50,1,'item_standard',1,0,1443,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('botcan','Bottle Candle',25,1,'item_standard',0,0,2657,1,1,'{}','nice item',0,NULL,NULL,1.00),('bountylicns','Bounty Hunter License',10,1,'item_standard',1,0,135,1,1,'{}','A license granting permission to be a bounty hunter.',0,NULL,NULL,1.00),('bouquet','Bouquet',1,1,'item_standard',1,0,136,1,1,'{}','A collection of flowers arranged in an artistic way.',0,NULL,NULL,1.00),('boxcan','Boxcan',25,1,'item_standard',0,0,2503,1,1,'{}','nice item',0,NULL,NULL,1.00),('bparrotb','Parrot Beak',25,1,'item_standard',1,0,137,1,1,'{}','A strong curved beak from a parrot.',0,NULL,NULL,0.05),('bparrotf','Parrot Feather',50,1,'item_standard',1,0,138,1,1,'{}','A bright green and yellow feather from a parrot.',0,NULL,NULL,0.02),('bracan','Gold Candle',25,1,'item_standard',0,0,2588,1,1,'{}','nice item',0,NULL,NULL,1.00),('bread','Bread',25,1,'item_standard',1,0,2141,1,1,'{}','nice item',0,NULL,NULL,1.00),('breadbana','Banana Bread',25,1,'item_standard',1,0,2086,1,1,'{}','nice item',0,NULL,NULL,1.00),('breadblue','Blueberry Bread',25,1,'item_standard',1,0,2087,1,1,'{}','nice item',0,NULL,NULL,1.00),('breadcorn','Corn Bread',25,1,'item_standard',1,0,2143,1,1,'{}','nice item',0,NULL,NULL,1.00),('breadgarlic','Garlic Bread',25,1,'item_standard',1,0,2142,1,1,'{}','nice item',0,NULL,NULL,1.00),('breadginger','Ginger Bread',25,1,'item_standard',1,0,2145,1,1,'{}','nice item',0,NULL,NULL,1.00),('breadlemon','Lemon Bread',25,1,'item_standard',1,0,2088,1,1,'{}','nice item',0,NULL,NULL,1.00),('breadorange','Orange Bread',25,1,'item_standard',1,0,2089,1,1,'{}','nice item',0,NULL,NULL,1.00),('breadsoda','Soda Bread',25,1,'item_standard',1,0,2144,1,1,'{}','nice item',0,NULL,NULL,1.00),('brokenpearlnecklace','Broken Pearl Necklace',10,1,'item_standard',1,0,738,1,1,'{}','A broken pearl necklace.',0,NULL,NULL,1.00),('broom','Broom',1,1,'item_standard',1,0,22148,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('browcomchar','Brown Comfy Chair',25,1,'item_standard',0,0,2711,1,1,'{}','nice item',0,NULL,NULL,1.00),('brownie','Brownie',25,1,'item_standard',1,0,2161,1,1,'{}','nice item',0,NULL,NULL,1.00),('browniehemp','Hemp Brownie',25,1,'item_standard',1,0,2162,1,1,'{}','nice item',0,NULL,NULL,1.00),('buckantler','Buck Antlers',25,1,'item_standard',1,0,139,1,1,'{}','A small rack from a whitetail buck.',0,NULL,NULL,0.60),('bucks','Buck Hide',10,1,'item_standard',1,0,140,1,1,'{}','A larger, tougher hide from a whitetail buck.',0,NULL,NULL,1.80),('bullhorn','Bull Horn',25,1,'item_standard',1,0,141,1,1,'{}','A heavy horn from a bull.',0,NULL,NULL,0.40),('bulls','Bull Hide',10,1,'item_standard',1,0,142,1,1,'{}','A thick hide from a bull.',0,NULL,NULL,3.00),('Bulrush','Bulrush',10,1,'item_standard',1,0,143,1,1,'{}','A type of tall wetland plant.',0,NULL,NULL,1.00),('Bulrush_Seed','Bulrush Seed',50,1,'item_standard',1,0,144,1,1,'{}','A seed that can be planted to grow bulrushes.',0,NULL,NULL,1.00),('bunkbed','bunk bed',20,1,'item_standard',1,0,145,1,1,'{}','A bed with two tiers, designed for multiple occupants.',0,NULL,NULL,1.00),('Burdock_Root','Burdock Root',10,1,'item_standard',1,0,146,1,1,'{}','The root of a burdock plant, often used for medicinal purposes.',0,NULL,NULL,1.00),('Burdock_Root_Seed','Burdock Root Seed',50,1,'item_standard',1,0,147,1,1,'{}','A seed that can be planted to grow burdock roots.',0,NULL,NULL,1.00),('burialoil','Burial Perfume Oil',20,1,'item_standard',1,0,1225,1,1,'{}','nice item',0,NULL,NULL,1.00),('burialwraps','Burial Wraps',20,1,'item_standard',1,0,1226,1,1,'{}','nice item',0,NULL,NULL,1.00),('bustent','Swamp Tent',25,1,'item_standard',0,0,2647,1,1,'{}','nice item',0,NULL,NULL,1.00),('butchertable1','Small Butcher Table',20,1,'item_standard',1,0,148,1,1,'{}','A small table used for butchering animals.',0,NULL,NULL,1.00),('butchertable2','Medium Butcher Table',20,1,'item_standard',1,0,149,1,1,'{}','A medium-sized table used for butchering animals.',0,NULL,NULL,1.00),('butchertable3','Large Butcher Table',20,1,'item_standard',1,0,150,1,1,'{}','A large table used for butchering animals.',0,NULL,NULL,1.00),('bottle_river_water','Dirty Water Bottle',25,1,'item_standard',1,0,2823,1,1,'{}','River water. Boil it at a fire before drinking, or risk poisoning.',0,NULL,NULL,1.00),('bottle_boiled_water','Clean Water Bottle',25,1,'item_standard',1,0,2824,1,1,'{}','Boiled water, safe to drink.',0,NULL,NULL,1.00),('butter','Butter',25,1,'item_standard',1,0,2020,1,1,'{}','nice item',0,NULL,NULL,1.00),('bwdresser','brown wood dresser',20,1,'item_standard',1,0,151,1,1,'{}','A dresser made of brown wood.',0,NULL,NULL,1.00),('cage','Cage',20,1,'item_standard',1,0,1380,1,1,'{}','nice item',0,NULL,NULL,1.00),('cakebundblue','Blue Berry Bundt Cake',25,1,'item_standard',1,0,2090,1,1,'{}','nice item',0,NULL,NULL,1.00),('cakecarrot','Carrot Cake',25,1,'item_standard',1,0,2156,1,1,'{}','nice item',0,NULL,NULL,1.00),('cakemango','Mango Cake',25,1,'item_standard',1,0,2091,1,1,'{}','nice item',0,NULL,NULL,1.00),('cakeshortstraw','Strawberry Short Cake',25,1,'item_standard',1,0,2092,1,1,'{}','nice item',0,NULL,NULL,1.00),('cambis','camp fire biscuits',25,1,'item_standard',0,0,2765,1,1,'{}','nice item',0,NULL,NULL,1.00),('camera','Camera',1,1,'item_standard',1,0,152,1,1,'{}','A device used to capture photographs.',0,NULL,NULL,1.00),('camole','Camp Omellete',25,1,'item_standard',1,0,2079,1,1,'{}','nice item',0,NULL,NULL,1.00),('campfire','Campfire',5,1,'item_standard',1,0,153,1,1,'{}','A fire pit used for cooking and warmth during camping.',0,NULL,NULL,1.00),('camtrtent','Camping Trader Tent',25,1,'item_standard',0,0,2473,1,1,'{}','nice item',0,NULL,NULL,1.00),('canchand','Candle Chandelier',25,1,'item_standard',0,0,2545,1,1,'{}','nice item',0,NULL,NULL,1.00),('candlea','Candle',20,1,'item_standard',1,0,154,1,1,'{}','A wax candle that provides light.',0,NULL,NULL,1.00),('cane','Cane',1,1,'item_standard',1,0,155,1,5,'{}','A walking stick for support and stability.',0,NULL,NULL,1.00),('cane_wep','Walking Cane',1,1,'item_standard',1,0,30513,1,1,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('canpi','Candle Pile',25,1,'item_standard',0,0,2459,1,1,'{}','nice item',0,NULL,NULL,1.00),('carcoftab','Carvis Coffee Table',25,1,'item_standard',0,0,2627,1,1,'{}','nice item',0,NULL,NULL,1.00),('cardinal_c','Cardinal',20,1,'item_standard',1,0,156,1,1,'{}','A whole cardinal, wanted for its red feathers.',0,NULL,NULL,0.10),('Cardinal_Flower','Cardinal Flower',10,1,'item_standard',1,0,157,1,1,'{}','A vibrant red flower often found near water.',0,NULL,NULL,1.00),('Cardinal_Flower_Seed','Cardinal Flower Seed',50,1,'item_standard',1,0,158,1,1,'{}','A seed that can be planted to grow Cardinal Flowers.',0,NULL,NULL,1.00),('carpaitabb','Private Painted Table',25,1,'item_standard',0,0,2689,1,1,'{}','nice item',0,NULL,NULL,1.00),('carpia','Carvis Piano',25,1,'item_standard',0,0,2714,1,1,'{}','nice item',0,NULL,NULL,1.00),('carrots','Carrot',10,1,'item_standard',1,0,159,1,1,'{}','An orange root vegetable commonly used in cooking.',0,NULL,NULL,1.00),('cartabb','Carvis Table',25,1,'item_standard',0,0,2754,1,1,'{}','nice item',0,NULL,NULL,1.00),('cedarwaxwing_c','Cedar Waxwing',20,1,'item_standard',1,0,160,1,1,'{}','A whole cedar waxwing, waxy red wingtips intact.',0,NULL,NULL,0.10),('centchar','Center Piece Chair',25,1,'item_standard',0,0,2442,1,1,'{}','nice item',0,NULL,NULL,1.00),('chaipeda','Chained Pedastal',25,1,'item_standard',0,0,2529,1,1,'{}','nice item',0,NULL,NULL,1.00),('champe','Champagne',25,1,'item_standard',1,0,2252,1,1,'{}','nice item',0,NULL,NULL,1.00),('changer','Coat Rack',20,1,'item_standard',1,0,1382,1,1,'{}','nice item',0,NULL,NULL,1.00),('Chanterelles','Chanterelles',10,1,'item_standard',1,0,161,1,1,'{}','A type of edible mushroom with a fruity aroma.',0,NULL,NULL,1.00),('Chanterelles_Seed','Chanterelles Seed',50,1,'item_standard',1,0,162,1,1,'{}','A seed that can be planted to grow Chanterelles mushrooms.',0,NULL,NULL,1.00),('chaps','Chaps',50,1,'item_standard',1,0,1446,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('char','Char',10,1,'item_standard',0,0,163,1,1,'{}','A type of fish commonly found in cold, deep lakes and rivers.',0,NULL,NULL,1.00),('cheesecake','Cheesecake',10,1,'item_standard',1,0,739,1,1,'{}','A tasty cheesecake.',0,NULL,NULL,1.00),('chemes','Cheese & Meat Stick',25,1,'item_standard',1,0,2060,1,1,'{}','nice item',0,NULL,NULL,1.00),('chesta','chest 1',20,1,'item_standard',1,0,1364,1,1,'{}','nice item',0,NULL,NULL,1.00),('chestb','chest 2',20,1,'item_standard',1,0,1365,1,1,'{}','nice item',0,NULL,NULL,1.00),('chestc','Chest C',20,1,'item_standard',1,0,164,1,1,'{}','A storage container used to store items securely.',0,NULL,NULL,1.00),('chewingtobacco','Chewing Tobacco',20,1,'item_standard',1,0,165,1,1,'{}','A form of tobacco that is chewed rather than smoked.',0,NULL,NULL,1.00),('chickenf','Chicken feather',20,1,'item_standard',1,0,166,1,1,'{}','A feather obtained from a chicken.',0,NULL,NULL,1.00),('chickenheart','Chicken Heart',25,1,'item_standard',1,0,167,1,1,'{}','A tiny heart from a chicken.',0,NULL,NULL,0.05),('chicken_and_gravy','Chicken and Gravy',10,1,'item_standard',1,0,5284,1,1,'{}','Grilled chicken with a nice glaze and topped with creamy chicken gravy.',0,NULL,NULL,1.00),('chicklempast','Lemon Chicken Pasta',25,1,'item_standard',1,0,2093,1,1,'{}','nice item',0,NULL,NULL,1.00),('chickorange','Orange Marinated Chicken',25,1,'item_standard',1,0,2094,1,1,'{}','nice item',0,NULL,NULL,1.00),('chinbilan','Imported Long Lantern',25,1,'item_standard',0,0,2546,1,1,'{}','nice item',0,NULL,NULL,1.00),('chinboxlan','Imported Box Lantern',25,1,'item_standard',0,0,2560,1,1,'{}','nice item',0,NULL,NULL,1.00),('chincab','Fine Cabinet',25,1,'item_standard',0,0,2452,1,1,'{}','nice item',0,NULL,NULL,1.00),('chincabb','Imported Cabinet',25,1,'item_standard',0,0,2591,1,1,'{}','nice item',0,NULL,NULL,1.00),('chinlan','Imported Round Lantern',25,1,'item_standard',0,0,2514,1,1,'{}','nice item',0,NULL,NULL,1.00),('chipmunk_c','Chipmunk',20,1,'item_standard',1,0,168,1,1,'{}','A whole chipmunk.',0,NULL,NULL,0.10),('chococake','Chocolate Cake',10,1,'item_standard',1,0,740,1,1,'{}','A tasty chocolate cake.',0,NULL,NULL,1.00),('chocolatemilk','Chocolate Milk',25,1,'item_standard',1,0,2018,1,1,'{}','nice item',0,NULL,NULL,1.00),('Choc_Daisy','Choc Daisy',50,1,'item_standard',1,0,169,1,1,'{}','A yellow wildflower that smells faintly of cocoa.',0,NULL,NULL,1.00),('Choc_Daisy_Seed','Choc Daisy Seed',50,1,'item_standard',1,0,170,1,1,'{}','Plant these and the bed will smell of chocolate come summer.',0,NULL,NULL,1.00),('churnedmilk','Churned Milk',25,1,'item_standard',1,0,2019,1,1,'{}','nice item',0,NULL,NULL,1.00),('cigar','Cigar',20,1,'item_standard',1,0,171,1,1,'{}','A fine cigar for relaxing.',0,NULL,NULL,1.00),('cigarette','Cigarette',20,1,'item_standard',1,0,172,1,1,'{}','A cigarette for a quick smoke.',0,NULL,NULL,1.00),('cigarettefilter','Cig Filter',20,1,'item_standard',1,0,173,1,1,'{}','A filter for cigarettes.',0,NULL,NULL,1.00),('cinematicket','Ticket',2,1,'item_standard',0,0,174,1,1,'{}','A ticket for a movie or event.',0,NULL,NULL,1.00),('clamp01','Clamp',1,1,'item_standard',1,0,1507,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('clay','Clay',50,1,'item_standard',0,0,175,1,1,'{}','A block of clay for crafting.',0,NULL,NULL,1.00),('cleanser','Cleanser',5,1,'item_standard',1,0,176,1,1,'{}','A cleanser for various uses.',0,NULL,NULL,1.00),('cleaver01','Butcher Cleaver',1,1,'item_standard',1,0,1504,1,5,'{}','A blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('cloaks','Cloaks',50,1,'item_standard',1,0,1461,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('clock','Clock',25,1,'item_standard',0,0,2594,1,1,'{}','nice item',0,NULL,NULL,1.00),('clongdres','Open Shelf Case',25,1,'item_standard',0,0,2549,1,1,'{}','nice item',0,NULL,NULL,1.00),('clotab','Wood Cloth Covered Table',25,1,'item_standard',0,0,2750,1,1,'{}','nice item',0,NULL,NULL,1.00),('clotboocase','Book Case',25,1,'item_standard',0,0,2506,1,1,'{}','nice item',0,NULL,NULL,1.00),('cloth','Cloth',20,1,'item_standard',1,0,741,1,1,'{}','Simple cloth with many uses.',0,NULL,NULL,1.00),('clothbench','Cloth Bench',20,1,'item_standard',1,0,177,1,1,'{}','A bench made of cloth material.',0,NULL,NULL,1.00),('clothesline','Clothes Line',20,1,'item_standard',1,0,178,1,1,'{}','A line for hanging clothes.',0,NULL,NULL,1.00),('clothes_line','Clothes Line',20,1,'item_standard',1,0,179,1,1,'{}','A line for hanging clothes.',0,NULL,NULL,1.00),('clothingset','Clothing Set',50,1,'item_standard',1,0,1438,1,1,'{}','A saved copy of a worn outfit. Use to wear it.',0,NULL,NULL,1.00),('clothingset2','Clothing Set',50,1,'item_standard',1,0,1439,1,1,'{}','A tailored outfit. Use to wear it.',0,NULL,NULL,1.00),('cloth_bench','Cloth Bench',20,1,'item_standard',1,0,180,1,1,'{}','A bench made of cloth material.',0,NULL,NULL,1.00),('club01','Club',1,1,'item_standard',1,0,1508,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('club02','Police Club',1,1,'item_standard',1,0,1509,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('club03','Wooden Club',1,1,'item_standard',1,0,1510,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('club06','Bone Club',1,1,'item_standard',1,0,1513,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('coal','Coal',50,1,'item_standard',0,0,181,1,1,'{}','A chunk of coal for fuel.',0,NULL,NULL,1.00),('coarashel','Coat Rack Shelf',25,1,'item_standard',0,0,2550,1,1,'{}','nice item',0,NULL,NULL,1.00),('coats','Coats',50,1,'item_standard',1,0,1463,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('coats_closed','Closed Coats',50,1,'item_standard',1,0,1451,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('cocainegum','Cocaine Gum',25,1,'item_standard',1,0,2488,1,1,'{}','nice item',0,NULL,NULL,1.00),('coca_seeds','Coca Seeds',50,1,'item_standard',1,0,2833,1,1,'{}','Seed for the coca shrub. Its leaves fetch a price from the wrong sort of buyer.',0,NULL,NULL,1.00),('cockc','Rooster Spur',25,1,'item_standard',1,0,182,1,1,'{}','The sharp leg spur of a rooster.',0,NULL,NULL,0.02),('cockf','Rooster Feather',50,1,'item_standard',1,0,183,1,1,'{}','A shining tail feather from a rooster.',0,NULL,NULL,0.02),('cockorange','Orange Cocktail',25,1,'item_standard',1,0,2095,1,1,'{}','nice item',0,NULL,NULL,1.00),('cocoa','Cocoa',50,1,'item_standard',1,0,184,1,1,'{}','Bitter beans that turn into chocolate with enough sugar and work.',0,NULL,NULL,1.00),('cocoaseeds','Cocoa Seeds',50,1,'item_standard',1,0,185,1,1,'{}','Seed for a cocoa plant. Keep it warm and wet.',0,NULL,NULL,1.00),('cofetab','Coffee Table',25,1,'item_standard',0,0,2683,1,1,'{}','nice item',0,NULL,NULL,1.00),('coffeebeans','Coffee Beans',50,1,'item_standard',1,0,742,1,1,'{}','Roast, grind and boil for a cup strong enough to stand a spoon in.',0,NULL,NULL,1.00),('coffeecream','Coffee with Cream',25,1,'item_standard',1,0,2033,1,1,'{}','nice item',0,NULL,NULL,1.00),('coffeefilter','Coffee Filter',10,1,'item_standard',1,0,743,1,1,'{}','A simple coffee filter.',0,NULL,NULL,1.00),('coffeeseeds','Coffee Seeds',50,1,'item_standard',1,0,2831,1,1,'{}','Seed for a coffee bush. Every camp will thank you for it.',0,NULL,NULL,1.00),('coffeesugar','Coffee with Sugar',25,1,'item_standard',1,0,2032,1,1,'{}','nice item',0,NULL,NULL,1.00),('coffindecor','Coffin Decor',20,1,'item_standard',1,0,186,1,1,'{}','Decorations for a coffin.',0,NULL,NULL,1.00),('coin_five_dollar','Five Dollar Coin',50,1,'item_standard',0,0,4835,1,1,'{}','A five dollar gold coin.',0,NULL,NULL,1.00),('coin_gold_dollar','Gold Dollar',50,1,'item_standard',0,0,4834,1,1,'{}','A golden dollar coin.',0,NULL,NULL,1.00),('coin_gold_eagle','Gold Eagle',50,1,'item_standard',0,0,4838,1,1,'{}','A ten dollar eagle gold coin.',0,NULL,NULL,1.00),('coin_gold_quarter','Gold Quarter',50,1,'item_standard',0,0,4836,1,1,'{}','A gold quarter eagle coin.',0,NULL,NULL,1.00),('coin_half_dime','Half Dime',50,1,'item_standard',0,0,4831,1,1,'{}','A small silver half dime coin.',0,NULL,NULL,1.00),('coin_half_eagle','Half Eagle',50,1,'item_standard',0,0,4837,1,1,'{}','A five dollar half eagle gold coin.',0,NULL,NULL,1.00),('coin_half_penny','1796 Half Penny',50,1,'item_standard',0,0,4827,1,1,'{}','An old copper half penny coin.',0,NULL,NULL,1.00),('coin_new_yorke','New Yorke Token',50,1,'item_standard',0,0,4839,1,1,'{}','A rare New Yorke trade token.',0,NULL,NULL,1.00),('coin_nickel_1792','1792 Nickel',50,1,'item_standard',0,0,4830,1,1,'{}','An old nickel coin from 1792.',0,NULL,NULL,1.00),('coin_penny_1787','1787 Penny',50,1,'item_standard',0,0,4828,1,1,'{}','An old copper penny from 1787.',0,NULL,NULL,1.00),('coin_penny_1789','1789 Penny',50,1,'item_standard',0,0,4829,1,1,'{}','An old copper penny from 1789.',0,NULL,NULL,1.00),('coin_quarter_1792','1792 Quarter',50,1,'item_standard',0,0,4832,1,1,'{}','A quarter dollar from 1792.',0,NULL,NULL,1.00),('coin_quarter_1792_2','1792 Quarter (Variant)',50,1,'item_standard',0,0,4833,1,1,'{}','A rare variant quarter from 1792.',0,NULL,NULL,1.00),('colbox','Collector Box',25,1,'item_standard',0,0,2738,1,1,'{}','nice item',0,NULL,NULL,1.00),('collector_fossil_bivalve','Bivalve Fossil',10,1,'item_standard',1,0,744,1,1,'{}','A common fossilized mollusc, badly worn.',0,NULL,NULL,1.00),('collector_fossil_brachiopod','Brachiopod Fossil',10,1,'item_standard',1,0,745,1,1,'{}','A common Brachiopod fossil with some chips and scrapes.',0,NULL,NULL,1.00),('collector_fossil_brow_horn','Brow Horn Fossil',10,1,'item_standard',1,0,746,1,1,'{}','A rare fossilized brow horn, believed to have belonged to a Triceratops.',0,NULL,NULL,1.00),('collector_fossil_cephalopod','Cephalopod Fossil',10,1,'item_standard',1,0,747,1,1,'{}','A common cephalopod fossil. Slightly damaged and brittle.',0,NULL,NULL,1.00),('collector_fossil_coral','Agatized Coral Fossil',10,1,'item_standard',1,0,748,1,1,'{}','A common piece of agatized coral, weather-beaten but still striking.',0,NULL,NULL,1.00),('collector_fossil_neo','Neospirifer Fossil',10,1,'item_standard',1,0,749,1,1,'{}','A common Neospirifer fossil, millions of years old. Good condition.',0,NULL,NULL,1.00),('collector_fossil_pet_wood','Common Petrified Wood Fossil',10,1,'item_standard',1,0,750,1,1,'{}','A common chunk of wood turned to stone over the years.',0,NULL,NULL,1.00),('collector_fossil_pet_wood_rainbow','Rainbow Petrified Wood Fossil',10,1,'item_standard',1,0,751,1,1,'{}','An uncommon piece of petrified wood filled with multicolored crystals.',0,NULL,NULL,1.00),('collector_fossil_pet_wood_yellow_cat','Yellow Cat Petrified Wood Fossil',10,1,'item_standard',1,0,752,1,1,'{}','An uncommon lump of petrified wood featuring bright red and yellow colors.',0,NULL,NULL,1.00),('collector_fossil_sea_lily','Sea Lily Fossil',10,1,'item_standard',1,0,753,1,1,'{}','An uncommon fossilized crinoid, a marine animal millions of years old.',0,NULL,NULL,1.00),('collector_fossil_sea_scorpion','Sea Scorpion Fossil',10,1,'item_standard',1,0,754,1,1,'{}','An uncommon eurypterid fossil in good condition.',0,NULL,NULL,1.00),('collector_fossil_stone','Petoskey Stone Fossil',10,1,'item_standard',1,0,755,1,1,'{}','A common rock made of fossilized coral. Unpolished.',0,NULL,NULL,1.00),('collector_fossil_tail_spike','Tail Spike Fossil',10,1,'item_standard',1,0,756,1,1,'{}','A rare fossilized tail spike, thought to have belonged to a Stegosaurus.',0,NULL,NULL,1.00),('collector_fossil_toe_claw','Toe Sickle Claw Fossil',10,1,'item_standard',1,0,757,1,1,'{}','A rare fossilized claw. Still sharp, it belonged to a genus of Dromaeosauridae.',0,NULL,NULL,1.00),('collector_fossil_tooth_mega','Upper Tooth Fossil',10,1,'item_standard',1,0,758,1,1,'{}','A rare fossilized tooth from a Megalodon.',0,NULL,NULL,1.00),('collector_fossil_tooth_serrated','Serrated Tooth Fossil',10,1,'item_standard',1,0,759,1,1,'{}','A rare and jagged fossilized tooth, once belonging to an Allosaurus.',0,NULL,NULL,1.00),('collector_fossil_tooth_trex','Front Tooth Fossil',10,1,'item_standard',1,0,760,1,1,'{}','A rare fossilized front tooth, perhaps belonging to the recently discovered Manospondylus Gigas. Highly prized.',0,NULL,NULL,1.00),('collector_fossil_trilobite_crypto','Cryptolithus Trilobite Fossil',10,1,'item_standard',1,0,761,1,1,'{}','A small, uncommon trilobite fossil. Good condition.',0,NULL,NULL,1.00),('collector_fossil_trilobite_iso','Isotelus Trilobite Fossil',10,1,'item_standard',1,0,762,1,1,'{}','An uncommon fossil of a huge trilobite. Fully intact.',0,NULL,NULL,1.00),('collector_fossil_tully_monster','Tully Monster Fossil',10,1,'item_standard',1,0,763,1,1,'{}','An uncommon Tullimonstrum fossil, nicely preserved.',0,NULL,NULL,1.00),('commdres','Commdres',25,1,'item_standard',0,0,2558,1,1,'{}','nice item',0,NULL,NULL,1.00),('comodres','Commode Dresser',25,1,'item_standard',0,0,2557,1,1,'{}','nice item',0,NULL,NULL,1.00),('condenser','Condenser',10,1,'item_standard',1,0,187,1,1,'{}','A device used to condense substances.',0,NULL,NULL,1.00),('condorb','Vulture Beak',25,1,'item_standard',1,0,188,1,1,'{}','A pale hooked beak from a vulture.',0,NULL,NULL,0.10),('condorf','Vulture Feather',50,1,'item_standard',1,0,189,1,1,'{}','A ragged brown feather from a vulture.',0,NULL,NULL,0.05),('consumable_blueberrypie','Blueberry Pie',10,1,'item_standard',1,0,764,1,1,'{}','A delicious pie made with blueberries.',0,NULL,NULL,1.00),('consumable_bluegil','Dried Bluegil',10,1,'item_standard',1,0,190,1,1,'{}','A dried Bluegil fish.',0,NULL,NULL,1.00),('consumable_breakfast','Breakfast',5,1,'item_standard',1,0,191,1,1,'{}','A hearty breakfast meal.',0,NULL,NULL,1.00),('consumable_caramel','Caramel',5,1,'item_standard',1,0,192,1,1,'{}','Sweet and sticky caramel.',0,NULL,NULL,1.00),('consumable_chickenpie','Chicken Pie',10,1,'item_standard',1,0,765,1,1,'{}','A delicious pie made with chicken.',0,NULL,NULL,1.00),('consumable_chocolate','Chocolate Bar',10,1,'item_standard',1,0,193,1,1,'{}','A delicious chocolate bar.',0,NULL,NULL,1.00),('consumable_chocolatecake','Chocolate Cake',10,1,'item_standard',1,0,766,1,1,'{}','A tasty chocolate cake.',0,NULL,NULL,1.00),('consumable_chocolatecoffee','Chocolate Coffee',10,1,'item_standard',1,0,767,1,1,'{}','A chocolate flaverd coffee drink.',0,NULL,NULL,1.00),('consumable_coffee','Coffee',25,1,'item_standard',1,0,194,1,1,'{}','A warm cup of coffee.',0,NULL,NULL,1.00),('consumable_coffeecake','Coffee Cake',10,1,'item_standard',1,0,768,1,1,'{}','A delicious coffee cake.',0,NULL,NULL,1.00),('consumable_crumbcake','Crumb Cake',10,1,'item_standard',1,0,769,1,1,'{}','A delicious crumb cake.',0,NULL,NULL,1.00),('consumable_cupcake','Cupcake',10,1,'item_standard',1,0,770,1,1,'{}','A delicious cupcake.',0,NULL,NULL,1.00),('consumable_donut','Donut',10,1,'item_standard',1,0,771,1,1,'{}','A tasty donut.',0,NULL,NULL,1.00),('consumable_fruitsalad','Fruit Salad',5,1,'item_standard',1,0,195,1,1,'{}','A refreshing fruit salad.',0,NULL,NULL,1.00),('consumable_game','Jerkied GameMeat',10,1,'item_standard',1,0,196,1,1,'{}','Dried and seasoned game meat.',0,NULL,NULL,1.00),('consumable_grapejelly','Grape Jelly',10,1,'item_standard',1,0,772,1,1,'{}','Grape flavored jelly.',0,NULL,NULL,1.00),('consumable_haycube','Haycube',10,1,'item_standard',1,0,197,1,1,'{}','A compact cube of hay.',0,NULL,NULL,1.00),('consumable_herb_chanterelles','Chanterelles',10,1,'item_standard',1,0,198,1,1,'{}','A bundle of Chanterelle mushrooms.',0,NULL,NULL,1.00),('consumable_herb_evergreen_huckleberry','Evergreen Huckleberry',10,1,'item_standard',1,0,199,1,1,'{}','Plump and juicy Evergreen Huckleberries.',0,NULL,NULL,1.00),('consumable_herb_oregano','Oregano',10,1,'item_standard',1,0,200,1,1,'{}','Fragrant oregano leaves.',0,NULL,NULL,1.00),('consumable_herb_vanilla_flower','Vanilla Flower',10,1,'item_standard',1,0,201,1,1,'{}','A delicate vanilla flower.',0,NULL,NULL,1.00),('consumable_herb_wintergreen_berry','Wintergreen Berry',10,1,'item_standard',1,0,202,1,1,'{}','Tart and refreshing Wintergreen Berries.',0,NULL,NULL,1.00),('consumable_horsepeppermints','Peppermint Stick',10,1,'item_standard',1,0,773,1,1,'{}','Peppermint flavored candy stick.',0,NULL,NULL,1.00),('consumable_kidneybeans_can','Kidney Beans',5,1,'item_standard',1,0,203,1,1,'{}','Canned kidney beans.',0,NULL,NULL,1.00),('consumable_lemoncake','Lemon Cake',10,1,'item_standard',1,0,774,1,1,'{}','A delicious lemon cake',0,NULL,NULL,1.00),('consumable_lemondrops','Leamon Drops',10,1,'item_standard',1,0,775,1,1,'{}','Lemon flavored candy.',0,NULL,NULL,1.00),('consumable_lock_breaker','Lock Breaker',10,1,'item_standard',1,0,204,1,1,'{}','A tool for breaking locks.',0,NULL,NULL,1.00),('consumable_meat_greavy','Meat Stew',12,1,'item_standard',1,0,205,1,1,'{}','A hearty meat stew.',0,NULL,NULL,1.00),('consumable_medicine','Medicine',10,1,'item_standard',1,0,206,1,1,'{}','Medicinal treatment.',0,NULL,NULL,1.00),('consumable_peach','Peach',50,1,'item_standard',1,0,207,1,1,'{}','Soft, sweet and dripping. Eat it before it bruises.',0,NULL,NULL,1.00),('consumable_peachcobbler','Peach Cobbler',10,1,'item_standard',1,0,776,1,1,'{}','A tasty peach cobbler.',0,NULL,NULL,1.00),('consumable_peachjelly','Peach Jelly',10,1,'item_standard',1,0,777,1,1,'{}','Peach flavored jelly.',0,NULL,NULL,1.00),('consumable_pear','Pear',10,1,'item_standard',1,0,208,1,1,'{}','A sweet and juicy pear.',0,NULL,NULL,1.00),('consumable_peppermint','Peppermint',10,1,'item_standard',1,0,778,1,1,'{}','Peppermint flavored candy.',0,NULL,NULL,1.00),('consumable_poundcake','Pound Cake',10,1,'item_standard',1,0,779,1,1,'{}','A delicious pound cake.',0,NULL,NULL,1.00),('consumable_pretzel','Pretzel',10,1,'item_standard',1,0,780,1,1,'{}','A tasty pretzel with salt.',0,NULL,NULL,1.00),('consumable_raspberryjelly','Raspberry Jelly',10,1,'item_standard',1,0,781,1,1,'{}','Raspberry flavored jelly.',0,NULL,NULL,1.00),('consumable_raspberrywater','Berry Water',10,1,'item_standard',1,0,209,1,1,'{}','Refreshing water infused with berries.',0,NULL,NULL,1.00),('consumable_salmon','Dried Salmon',10,1,'item_standard',1,0,210,1,1,'{}','A dried and preserved salmon.',0,NULL,NULL,1.00),('consumable_salmon_can','Salmon Can',10,1,'item_standard',1,0,211,1,1,'{}','Canned salmon.',0,NULL,NULL,1.00),('consumable_spongecake','Sponge Cake',10,1,'item_standard',1,0,782,1,1,'{}','A soft and delicious spong cake.',0,NULL,NULL,1.00),('consumable_steakpie','Steak Pie',10,1,'item_standard',1,0,783,1,1,'{}','A delicious pie made with beef.',0,NULL,NULL,1.00),('consumable_trout','Cooked Trout',10,1,'item_standard',1,0,212,1,1,'{}','A cooked and seasoned trout.',0,NULL,NULL,1.00),('consumable_veggies','Edible Veggies',5,1,'item_standard',1,0,213,1,1,'{}','A mix of various edible vegetables.',0,NULL,NULL,1.00),('contract','Contract',20,1,'item_standard',1,0,11941,1,1,'{}','nice item',0,NULL,NULL,1.00),('cookedbluegil','Cooked Bluegil with Veggies',5,1,'item_standard',1,0,214,1,1,'{}','A cooked Bluegil fish served with vegetables.',0,NULL,NULL,1.00),('cookie','Cookie',25,1,'item_standard',1,0,2153,1,1,'{}','nice item',0,NULL,NULL,1.00),('cooklemon','Lemon Cookie',25,1,'item_standard',1,0,2096,1,1,'{}','nice item',0,NULL,NULL,1.00),('copper','Copper',50,1,'item_standard',1,0,215,1,1,'{}','A piece of copper.',0,NULL,NULL,1.00),('copper_bar','Copper Bar',25,1,'item_standard',0,0,2609,1,1,'{}','nice item',0,NULL,NULL,1.00),('cordbow','Bow Cord',10,1,'item_standard',1,0,784,1,1,'{}','Cord used for making a bow.',0,NULL,NULL,1.00),('corn','Corn',50,1,'item_standard',1,0,216,1,1,'{}','A full ear of corn, fresh off the stalk.',0,NULL,NULL,1.00),('cornbeefhash','Corn Beef & Hash',25,1,'item_standard',1,0,2151,1,1,'{}','nice item',0,NULL,NULL,1.00),('corncubcab','Corner Cabinet',25,1,'item_standard',0,0,2564,1,1,'{}','nice item',0,NULL,NULL,1.00),('cornoncob','Corn on the cob',25,1,'item_standard',1,0,2146,1,1,'{}','nice item',0,NULL,NULL,1.00),('cornseed','Corn Seed',50,1,'item_standard',1,0,217,1,1,'{}','Dried kernels for sowing. One stalk, a few good ears.',0,NULL,NULL,1.00),('corntrunk','Cornwall Trunk',25,1,'item_standard',0,0,2573,1,1,'{}','nice item',0,NULL,NULL,1.00),('cotsle','Cot',25,1,'item_standard',0,0,2453,1,1,'{}','nice item',0,NULL,NULL,1.00),('cottage_loaf','The Cottage Loaf',25,1,'item_standard',1,0,17150,3,1,'{}','Baked this morning, still warm in the middle.',0,NULL,NULL,1.00),('cougarf','Cougar Fang',25,1,'item_standard',1,0,218,1,1,'{}','A long fang from a mountain lion.',0,NULL,NULL,0.05),('cougars','Cougar Pelt',10,1,'item_standard',1,0,219,1,1,'{}','A tawny, short-haired pelt from a mountain lion.',0,NULL,NULL,2.00),('cougartaxi','Cougar Taxidermy',20,1,'item_standard',1,0,220,1,1,'{}','A taxidermy mount of a cougar.',0,NULL,NULL,1.00),('cougar_taxidermy','Cougar Taxidermy',20,1,'item_standard',1,0,221,1,1,'{}','A taxidermy mount of a cougar.',0,NULL,NULL,1.00),('covbed','Fancy Wood Bed',25,1,'item_standard',0,0,2645,1,1,'{}','nice item',0,NULL,NULL,1.00),('cowh','Cow Horn',25,1,'item_standard',1,0,222,1,1,'{}','A hollow cow horn, handy for powder or drink.',0,NULL,NULL,0.30),('cows','Cow pelt',20,1,'item_standard',1,0,223,1,1,'{}','The soft and furry pelt of a cow.',0,NULL,NULL,1.00),('coyotef','Coyote Fang',25,1,'item_standard',1,0,224,1,1,'{}','A small fang from a coyote.',0,NULL,NULL,0.05),('coyotepelt','Coyote Pelt',20,1,'item_standard',1,0,225,1,1,'{}','The fur pelt of a coyote.',0,NULL,NULL,1.00),('coyotes','Coyote Pelt',10,1,'item_standard',1,0,226,1,1,'{}','A thin, sandy pelt. Cheap, but there are always more.',0,NULL,NULL,1.20),('coyotetaxi','Coyote Taxidermy',20,1,'item_standard',1,0,227,1,1,'{}','A taxidermy mount of a coyote.',0,NULL,NULL,1.00),('coyote_pelt','Coyote Pelt',20,1,'item_standard',1,0,228,1,1,'{}','The fur pelt of a coyote.',0,NULL,NULL,1.00),('coyote_taxidermy','Coyote Taxidermy',20,1,'item_standard',1,0,229,1,1,'{}','A taxidermy mount of a coyote.',0,NULL,NULL,1.00),('crabake','Crab Root Bake',25,1,'item_standard',1,0,2077,1,1,'{}','nice item',0,NULL,NULL,1.00),('crabbutter','Crab Butter',10,1,'item_standard',1,0,785,1,1,'{}','Butter made from crab. Delicious on toast.',0,NULL,NULL,1.00),('crabentree','Crab Entree',25,1,'item_standard',1,0,2026,1,1,'{}','nice item',0,NULL,NULL,1.00),('crablegs','Crab Legs',10,1,'item_standard',1,0,786,1,1,'{}','Legs from a crab.',0,NULL,NULL,1.00),('crab_c','Crab',20,1,'item_standard',1,0,230,1,1,'{}','A whole crab, shell on.',0,NULL,NULL,0.20),('cracak','Crab Cakes',25,1,'item_standard',1,0,2082,1,1,'{}','nice item',0,NULL,NULL,1.00),('craftingfire','Crafting Fire',20,1,'item_standard',1,0,231,1,1,'{}','A fire used for crafting.',0,NULL,NULL,1.00),('crafting_fire','Crafting Fire',20,1,'item_standard',1,0,232,1,1,'{}','A fire used for crafting.',0,NULL,NULL,1.00),('cratabl','Crate Table',25,1,'item_standard',0,0,2562,1,1,'{}','nice item',0,NULL,NULL,1.00),('crawfish_c','Crawfish',20,1,'item_standard',1,0,233,1,1,'{}','A whole crawfish, ready for the boil.',0,NULL,NULL,0.10),('Creeking_Thyme','Creeping Thyme',50,1,'item_standard',1,0,234,1,1,'{}','A low mat of thyme with tiny pink flowers. Lovely in a stew.',0,NULL,NULL,1.00),('Creeking_Thyme_Seed','Creeping Thyme Seed',50,1,'item_standard',1,0,235,1,1,'{}','Scatter it and the thyme will spread along the ground.',0,NULL,NULL,1.00),('Creekplum','Creekplum',50,1,'item_standard',1,0,236,1,1,'{}','A little wild plum that grows by running water. Tart skin, sweet flesh.',0,NULL,NULL,1.00),('Creekplum_Seed','Creekplum Seed',50,1,'item_standard',1,0,237,1,1,'{}','A plum stone ready for planting.',0,NULL,NULL,1.00),('crncrm','Creamed Corn',25,1,'item_standard',1,0,2147,1,1,'{}','nice item',0,NULL,NULL,1.00),('crowbar','Crowbar',10,1,'item_standard',1,0,3273,1,1,'{}','nice item',0,NULL,NULL,1.00),('crowbar01','Crowbar',1,1,'item_standard',1,0,1516,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('Crows_Garlic','Crow\'s Garlic',50,1,'item_standard',1,0,238,1,1,'{}','Wild garlic with a sharp bite. A little goes a long way.',0,NULL,NULL,1.00),('Crows_Garlic_Seed','Crow\'s Garlic Seed',50,1,'item_standard',1,0,239,1,1,'{}','Seed for a patch of crow\'s garlic.',0,NULL,NULL,1.00),('crow_c','Crow',20,1,'item_standard',1,0,240,1,1,'{}','A dead crow, whole. Naturalists and taxidermists buy these.',0,NULL,NULL,0.30),('crso','Cream Soda',25,1,'item_standard',1,0,2054,1,1,'{}','nice item',0,NULL,NULL,1.00),('cunbisgrav','Country Biscuits with Gravy',25,1,'item_standard',1,0,2071,1,1,'{}','nice item',0,NULL,NULL,1.00),('curse_cure','Curse Cure',10,1,'item_standard',1,0,2837,1,1,'{}','nice item',0,NULL,NULL,1.00),('cursod','Currant Soda',25,1,'item_standard',1,0,2057,1,1,'{}','nice item',0,NULL,NULL,1.00),('cussitab','Visceral Side Table',25,1,'item_standard',0,0,2612,1,1,'{}','nice item',0,NULL,NULL,1.00),('cuttabb','Cutting Table',25,1,'item_standard',0,0,2603,1,1,'{}','nice item',0,NULL,NULL,1.00),('damascussteel','Damascus Steel',10,1,'item_standard',0,0,2413,1,1,'{}','nice item',0,NULL,NULL,1.00),('darkcouc','Upholstery Bench',25,1,'item_standard',0,0,2441,1,1,'{}','nice item',0,NULL,NULL,1.00),('darub','Crane Beak',25,1,'item_standard',1,0,241,1,1,'{}','A long beak from a crane.',0,NULL,NULL,0.05),('daruf','Crane Feather',50,1,'item_standard',1,0,242,1,1,'{}','A white feather from a whooping crane.',0,NULL,NULL,0.05),('dbcandle','Dbl Candle',20,1,'item_standard',1,0,243,1,1,'{}','A double-sided candle with two wicks.',0,NULL,NULL,1.00),('dblcab','Double Cabinet',25,1,'item_standard',0,0,2501,1,1,'{}','nice item',0,NULL,NULL,1.00),('decortent1','Decor Tent 1 Set',20,1,'item_standard',1,0,244,1,1,'{}','A decorative tent set with unique patterns.',0,NULL,NULL,1.00),('decortent2','Decor Tent 2 Set',20,1,'item_standard',1,0,245,1,1,'{}','A decorative tent set with unique patterns.',0,NULL,NULL,1.00),('decortent3','Decor Tent 3 Set',20,1,'item_standard',1,0,246,1,1,'{}','A decorative tent set with unique patterns.',0,NULL,NULL,1.00),('deerheart','Deer Heart',25,1,'item_standard',1,0,247,1,1,'{}','A fresh deer heart. Some hunters eat it on the spot.',0,NULL,NULL,0.30),('deernativetent','Deer Pelt Native Tent',20,1,'item_standard',1,0,1389,1,1,'{}','nice item',0,NULL,NULL,1.00),('deerpelt','Deer pelt',20,1,'item_standard',1,0,248,1,1,'{}','The soft and warm pelt of a deer.',0,NULL,NULL,1.00),('deerskin','Deer pelt',20,1,'item_standard',1,0,249,1,1,'{}','The skin of a deer.',0,NULL,NULL,1.00),('deertaxi','Deer Taxidermy',20,1,'item_standard',1,0,250,1,1,'{}','A taxidermy mount of a deer.',0,NULL,NULL,1.00),('deer_pelt','Deer Pelt',20,1,'item_standard',1,0,251,1,1,'{}','The soft and warm pelt of a deer.',0,NULL,NULL,1.00),('deer_taxidermy','Deer Taxidermy',20,1,'item_standard',1,0,252,1,1,'{}','A taxidermy mount of a deer.',0,NULL,NULL,1.00),('den_key','Den Key',1,1,'item_standard',0,0,2877,4,5,'{}','A heavy iron key on a frayed leather cord, the brass tag worn smooth. Opens a door somebody would rather have kept shut.',0,NULL,NULL,1.00),('deschai','Rotating Desk Chair',25,1,'item_standard',0,0,2608,1,1,'{}','nice item',0,NULL,NULL,1.00),('Desert_Sage','Desert Sage',10,1,'item_standard',1,0,253,1,1,'{}','A bundle of Desert Sage used for crafting and medicinal purposes.',0,NULL,NULL,1.00),('Desert_Sage_Seed','Desert Sage Seed',50,1,'item_standard',1,0,254,1,1,'{}','A seed of Desert Sage that can be planted to grow Desert Sage plants.',0,NULL,NULL,1.00),('desmirro','Private Desk Mirror',25,1,'item_standard',0,0,2635,1,1,'{}','nice item',0,NULL,NULL,1.00),('detdes','Atlas Desk',25,1,'item_standard',0,0,2565,1,1,'{}','nice item',0,NULL,NULL,1.00),('diachand','Diamond Chandelier',25,1,'item_standard',0,0,2543,1,1,'{}','nice item',0,NULL,NULL,1.00),('diamond','Diamond',20,1,'item_standard',0,0,255,1,1,'{}','A precious gemstone known for its brilliance and value.',0,NULL,NULL,1.00),('dirty_grave','Dirty Grave',25,1,'item_standard',1,0,16471,3,4,'{}','Chocolate soil, and something buried in it.',0,NULL,NULL,1.00),('divlam','Divlam',25,1,'item_standard',0,0,2497,1,1,'{}','nice item',0,NULL,NULL,1.00),('dleguans','Desert Iguana Skin',10,1,'item_standard',1,0,256,1,1,'{}','A pale, speckled skin from a desert iguana.',0,NULL,NULL,0.30),('donut','Donut',25,1,'item_standard',1,0,2154,1,1,'{}','nice item',0,NULL,NULL,1.00),('donutchoco','Chocolate Donut',25,1,'item_standard',1,0,2155,1,1,'{}','nice item',0,NULL,NULL,1.00),('dreamcatcher','Dream Catcher',20,1,'item_standard',1,0,257,1,1,'{}','A traditional Native American ornament believed to filter out bad dreams and let only good dreams pass through.',0,NULL,NULL,1.00),('dring','Diamond Ring',25,1,'item_standard',0,0,2707,1,1,'{}','nice item',0,NULL,NULL,1.00),('Drink_For_Dog','Pet Water',10,1,'item_standard',1,0,258,1,1,'{}','A refreshing drink specially made for pets to keep them hydrated.',0,NULL,NULL,1.00),('drugalsashes','Al\'s Ashes',25,1,'item_standard',1,0,2692,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbamsburners','Bam\'s Burners',25,1,'item_standard',1,0,2648,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbamsrubies','Bam\'s Rubies',25,1,'item_standard',1,0,2762,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbamswhitecrystals','Bam\'s White Crystals',25,1,'item_standard',1,0,2583,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbanditsboost','Bandit\'s Booster',25,1,'item_standard',0,0,2531,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbastardsbreath','Bastards Breath',25,1,'item_standard',1,0,2580,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbayoucigar','Bayou Cigar',25,1,'item_standard',1,0,2510,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbayoucola','Bayo Cola',25,1,'item_standard',1,0,2185,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbayoucrack','Bayou Rock',25,1,'item_standard',1,0,2687,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbayouhash','Bayou Hash',25,1,'item_standard',1,0,2587,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbayoujuice','Bayou Juice',25,1,'item_standard',0,0,2618,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbayouspliff','Bayou Spliff',25,1,'item_standard',1,0,2699,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugblackbaronboblesmoke','Black Baron Noble Smoke',25,1,'item_standard',1,0,2554,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugblackbaronbosssauce','Black Baron Boss Sauce',25,1,'item_standard',1,0,2207,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugblackpowder','Black Powder',25,1,'item_standard',1,0,2724,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbloodmooncigar','Blood Moon Smoke',25,1,'item_standard',1,0,2455,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbluemagic','Blue Magic',25,1,'item_standard',0,0,2461,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbonniesrosetonic','Bonnie\'s Rose Tonic',25,1,'item_standard',1,0,2187,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbrownsugar','Brown Sugar',25,1,'item_standard',1,0,2731,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbrownsugarum','Brownsuga Rum',25,1,'item_standard',1,0,2198,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbtbcigar','BTB Cigar',25,1,'item_standard',1,0,2700,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugbullmooseblend','Bull Moose Blend',25,1,'item_standard',1,0,2493,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugchewablewater','Chewable Water',25,1,'item_standard',1,0,2182,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugchieftainspeacepipe','Chieftain\'s Peace Pipe',25,1,'item_standard',1,0,2725,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugchqofa','Chqofa',25,1,'item_standard',1,0,2771,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcoldleadchew','Cold Lead Chew',25,1,'item_standard',1,0,2188,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcoltonsmiracle','Colton\'s Miracle',25,1,'item_standard',1,0,2653,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcommandercoffee','Commander Cofee',25,1,'item_standard',1,0,2179,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcommunionbourbon','Saints Communion Bourbon',25,1,'item_standard',1,0,2177,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcompjuice','Comp Juice',25,1,'item_standard',1,0,2223,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcortezironleadcigar','Cortez Iron Leaf Cigar',25,1,'item_standard',1,0,2720,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcranstonscrown','Cranston\'s Crown Cigar',25,1,'item_standard',1,0,2723,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcrosscigar','Cross Cigar',25,1,'item_standard',1,0,2484,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcrossjuice','Cross Juice',25,1,'item_standard',1,0,2209,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcrowblood','Crow Blood',25,1,'item_standard',0,0,2710,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcruxcineris','Crux Cineris',25,1,'item_standard',1,0,2551,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcruxinvicta','Crux Invicta',25,1,'item_standard',1,0,2216,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcruxsacra','Crux Sacra',25,1,'item_standard',1,0,2212,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugcrystalskull','Crystal Skull',25,1,'item_standard',1,0,2253,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdajnessweetleaf','Dajne\'s Sweet Leaf',25,1,'item_standard',1,0,2713,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdajneswranglerscut','Dajne\'s Wrangler\'s Cut',25,1,'item_standard',1,0,2208,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdeadmanspour','Dead Man\'s Pour',25,1,'item_standard',1,0,2224,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdeathgum','Death Gum',25,1,'item_standard',1,0,2196,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdevilsgrin','Devil\'s Grin',25,1,'item_standard',1,0,2633,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdevilslungs','Devil\'s Lungs',25,1,'item_standard',1,0,2735,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdewkiescannabis','Dewkie\'s Cannabis',25,1,'item_standard',1,0,2507,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdonkslastpuff','Donk\'s Last Puff',25,1,'item_standard',1,0,2730,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdragondream','Lee\'s Dragon\'s Dream Opium',25,1,'item_standard',1,0,2729,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdragonsbreath','Dragon\'s Breath',25,1,'item_standard',1,0,2527,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdrsanchezcokeelixer','Dr. Sanchez Coke Elixer',25,1,'item_standard',1,0,2230,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdudiodoublepuff','Dudio Double Puff',25,1,'item_standard',1,0,2701,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugdwightsdoobie','Dwight\'s Doobie',25,1,'item_standard',1,0,2721,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugfeyresserum','Feyre\'s Serum',25,1,'item_standard',0,0,2740,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugfilth','Filth',25,1,'item_standard',1,0,2180,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugfinalprayer','Final Prayer',25,1,'item_standard',0,0,2698,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugflacascrystalblue','Flaca\'s Crystal Blue',25,1,'item_standard',1,0,2178,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugflacocigar','Flaco Cigar',25,1,'item_standard',1,0,2728,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugflacosshine','Flaco\'s Shine',25,1,'item_standard',1,0,2204,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugfletchersdrug','Fletcher\'s Rocks',25,1,'item_standard',0,0,2742,1,1,'{}','nice item',0,NULL,NULL,1.00),('druggigglejuice','Giggle Juice',25,1,'item_standard',0,0,2708,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugglacierfrost','Glacier Frost',25,1,'item_standard',0,0,2485,1,1,'{}','nice item',0,NULL,NULL,1.00),('druggoldenstogie','Golden Stogie',25,1,'item_standard',1,0,2756,1,1,'{}','nice item',0,NULL,NULL,1.00),('druggravelight','Gravelight',25,1,'item_standard',1,0,2715,1,1,'{}','nice item',0,NULL,NULL,1.00),('drughangmanshoney','Hangman\'s Honey',25,1,'item_standard',1,0,2199,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugharleyshealthyswig','Harley\'s Healthy Swig',25,1,'item_standard',1,0,2242,1,1,'{}','nice item',0,NULL,NULL,1.00),('drughealthafix','Healthafix',25,1,'item_standard',0,0,2736,1,1,'{}','nice item',0,NULL,NULL,1.00),('drughotchocolate','Hot Chocolate',25,1,'item_standard',1,0,2205,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugironrootwhiskey','Iron Root Whiskey',25,1,'item_standard',1,0,2184,1,1,'{}','nice item',0,NULL,NULL,1.00),('druglacroixxi','LaCroix XI',25,1,'item_standard',1,0,2227,1,1,'{}','nice item',0,NULL,NULL,1.00),('druglaminarlog','Lam\'inar Log',25,1,'item_standard',1,0,2492,1,1,'{}','nice item',0,NULL,NULL,1.00),('druglaudanum','Laudanum',25,1,'item_standard',1,0,2193,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugleeshealthyelixir','Lee\'s Healthy Elixir',25,1,'item_standard',1,0,2237,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugleesspeedyhealth','Lee\'s Speedy Elixir',25,1,'item_standard',1,0,2236,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugleeswonton','Lee\'s Wonton Noodle Soup',25,1,'item_standard',1,0,2194,1,1,'{}','nice item',0,NULL,NULL,1.00),('druglegacycowboykiller','Legacy Cowboy Killer',25,1,'item_standard',1,0,2502,1,1,'{}','nice item',0,NULL,NULL,1.00),('druglegacysmackers','Legacy Smackers',25,1,'item_standard',1,0,2482,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugluciisluckychews','Lucii\'s Lucky Chews',25,1,'item_standard',1,0,2222,1,1,'{}','nice item',0,NULL,NULL,1.00),('druglulujuice','LuLu Juice',25,1,'item_standard',1,0,2186,1,1,'{}','nice item',0,NULL,NULL,1.00),('druglungbuster','Dirty Dave\'s Lungbuster',25,1,'item_standard',1,0,2671,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugmccarthysrocks','McCarthy\'s Rocks',25,1,'item_standard',1,0,2718,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugmccormicks','McCormick\'s',25,1,'item_standard',1,0,2746,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugmcdouglesppikeyelixir','McDougles Pikey Elixir',25,1,'item_standard',0,0,2685,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugmedicalmunchies','Medical Munchies',25,1,'item_standard',1,0,2214,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugmidnightdelight','Midnight Delight',25,1,'item_standard',1,0,2483,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugmrleeseggroll','Mr. Lee\'s Eggroll',25,1,'item_standard',1,0,2217,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugnorthernlights','Northern Lights',25,1,'item_standard',1,0,2733,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugpetalpusher','Petal Pusher',25,1,'item_standard',0,0,2712,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugphenoxymethylpenicillin','Phenoxymethylpenicillin',25,1,'item_standard',0,0,2513,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugpieceofcandy','Piece of Candy',25,1,'item_standard',1,0,2719,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugpoitin','PoitÃ­n',25,1,'item_standard',1,0,2231,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugpsychedelicmushroom','Psychedelic Mushroom',25,1,'item_standard',1,0,2215,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugreapersripper','Reaper\'s Ripper',25,1,'item_standard',1,0,2696,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugredrage','Red\'s Rage',25,1,'item_standard',0,0,2457,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugredsage','Red Sage',25,1,'item_standard',1,0,2734,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugrivieraroughcut','Riviera Rough Cut',25,1,'item_standard',1,0,2691,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugrothschilddrops','Rothschild\'s Cocaine Lemon Drops',25,1,'item_standard',1,0,2200,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugrothschildrockcandy','Rothschild\'s Rock Candy',25,1,'item_standard',1,0,2201,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugroyalflush','Royal Flush',25,1,'item_standard',1,0,2763,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugrunapockoresolve','Runapocko Resolve',25,1,'item_standard',1,0,2491,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugsabatinocubano','Gibellina Cubano',25,1,'item_standard',1,0,2716,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugsaltypickaxe','Salty Pickaxe',25,1,'item_standard',1,0,2749,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugshadowleaf','Shadow Leaf',25,1,'item_standard',1,0,2693,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugshayschew','Shay\'s Chew',25,1,'item_standard',1,0,2173,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugshroudededge','Shrouded Edge',25,1,'item_standard',1,0,2613,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugsilvercutcigar','Silver Cut Cigar',25,1,'item_standard',1,0,2772,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugspice','Spice',25,1,'item_standard',0,0,2678,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugsuccublisspotion','Succubliss Potion',25,1,'item_standard',1,0,2233,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugswampjuice','Swamp Juice',25,1,'item_standard',1,0,2219,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugswampstogie','Swamp Stogie',25,1,'item_standard',1,0,2575,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugsweethearts','Sweet Hearts',25,1,'item_standard',1,0,2533,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugtahitismangos','Tahiti\'s Mangos',25,1,'item_standard',1,0,2640,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugtigranesroar','Tigrane\'s Roar',25,1,'item_standard',1,0,2706,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugtimberlinecut','Timberline Cut',25,1,'item_standard',1,0,2476,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugtommyshardtackcandy','Tommy\'s Hard Tack Candy',25,1,'item_standard',1,0,2218,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugturkeyass','Turkey Ass',25,1,'item_standard',1,0,2195,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugundertakerskiss','The Undertaker\'s Kiss',25,1,'item_standard',1,0,2637,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugvanhornjuice','Van Horn Juice',25,1,'item_standard',1,0,2183,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugvialb','Vial B',25,1,'item_standard',0,0,2470,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugvitalitytonic','Vitality Tonic',25,1,'item_standard',1,0,2221,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugvitoschewingtobacco','Vito\'s Chewing Tobacco',25,1,'item_standard',0,0,2704,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugvitositaliancigar','Vito\'s Italian Cigar',25,1,'item_standard',1,0,2471,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugwobblecockbeer','Wobblecock Beer',25,1,'item_standard',1,0,2172,1,1,'{}','nice item',0,NULL,NULL,1.00),('drugyouvebeendone','You\'ve Been Dunn Cigar',25,1,'item_standard',1,0,2690,1,1,'{}','nice item',0,NULL,NULL,1.00),('drug_package','Drug Package',1,1,'item_standard',0,0,1807,1,5,'{}','Contraband. Plant it in rival territory.',0,NULL,NULL,1.00),('duckfat','Duck Fat',25,1,'item_standard',1,0,259,1,1,'{}','Rendered duck fat, the best thing to roast potatoes in.',0,NULL,NULL,0.20),('Duck_Egg','Duck Egg',10,1,'item_standard',1,0,260,1,1,'{}','An egg laid by a duck, often used in various culinary preparations.',0,NULL,NULL,1.00),('dynamite','Pipe Charge Dynamite',10,1,'item_standard',1,0,261,1,1,'{}','An explosive device consisting of a tube filled with explosive material, used for various purposes including mining and demolition.',0,NULL,NULL,1.00),('eaglef','Eagle Feather',50,1,'item_standard',1,0,262,1,1,'{}','A long, dark flight feather from an eagle.',0,NULL,NULL,0.05),('eaglet','Eagle Talon',25,1,'item_standard',1,0,263,1,1,'{}','A hooked talon from an eagle.',0,NULL,NULL,0.05),('eagroychar','Commander Chair',25,1,'item_standard',0,0,2528,1,1,'{}','nice item',0,NULL,NULL,1.00),('easter_egg','Painted Egg',50,1,'item_standard',1,0,31461,1,1,'{}','nice item',0,NULL,NULL,1.00),('easter_egg_gold','Golden Egg',1,1,'item_standard',1,0,31462,1,1,'{}','nice item',0,NULL,NULL,1.00),('ecstasyelixir','The Ecstasy Elixir',20,1,'item_standard',1,0,7758,1,1,'{}','Bottled delight, briefly.',0,NULL,NULL,1.00),('egg','Egg',50,1,'item_standard',1,0,264,1,1,'{}','A small oval object laid by a female bird, reptile, or fish, containing a fertilized embryo and nutrients for development.',0,NULL,NULL,1.00),('eggs','Egg',50,1,'item_standard',1,0,265,1,1,'{}','Various types of eggs collected from different animals, often used in cooking and crafting.',0,NULL,NULL,1.00),('egretb','Egret Beak',25,1,'item_standard',1,0,266,1,1,'{}','A slim yellow beak from an egret.',0,NULL,NULL,0.05),('egretf','Egret Plume',50,1,'item_standard',1,0,267,1,1,'{}','A white lace plume. Milliners pay more than it weighs in silver.',0,NULL,NULL,0.05),('elkantler','Elk Antlers',25,1,'item_standard',1,0,268,1,1,'{}','A tall, branched rack from an elk.',0,NULL,NULL,1.20),('elks','Elk Hide',10,1,'item_standard',1,0,269,1,1,'{}','A heavy hide with a dark mane at the neck.',0,NULL,NULL,3.00),('emerald','Emerald',20,1,'item_standard',0,0,270,1,1,'{}','A precious green gemstone with a sparkling appearance.',0,NULL,NULL,1.00),('empty_bottle','Empty Bottle',20,1,'item_standard',1,0,271,1,1,'{}','Empty Bottle',0,NULL,NULL,1.00),('English_Mace','English Mace',50,1,'item_standard',1,0,272,1,1,'{}','A feathery herb with a warm, peppery taste for the kitchen and the medicine chest.',0,NULL,NULL,1.00),('English_Mace_Seed','English Mace Seed',50,1,'item_standard',1,0,273,1,1,'{}','Seed for a clump of English mace.',0,NULL,NULL,1.00),('Evergreen_Huckleberry','Evergreen Huckleberry',10,1,'item_standard',1,0,274,1,1,'{}','A small, dark purple berry known for its tart and sweet flavor.',0,NULL,NULL,1.00),('Evergreen_Huckleberry_Seed','Evergreen Huckleberry Seed',50,1,'item_standard',1,0,275,1,1,'{}','Seeds that can be planted to grow Evergreen Huckleberry bushes.',0,NULL,NULL,1.00),('exedes','Executive Row Desk',25,1,'item_standard',0,0,2568,1,1,'{}','nice item',0,NULL,NULL,1.00),('exterlam','Exterlam',25,1,'item_standard',0,0,2584,1,1,'{}','nice item',0,NULL,NULL,1.00),('eyewear','EyeWear',50,1,'item_standard',1,0,1469,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('fan','Fan',1,1,'item_standard',1,0,276,1,1,'{}','A handheld device with flat blades used to create a breeze or provide cooling.',0,NULL,NULL,1.00),('fancydouble','Fancy Double',20,1,'item_standard',1,0,277,1,1,'{}','A stylish and well-crafted double-barreled firearm.',0,NULL,NULL,1.00),('farmer_pack','Farmer\'s Pack',1,1,'item_standard',1,0,8856,1,4,'{}','A canvas produce pack. Holds 400 units of seeds and crops.',0,NULL,NULL,1.00),('Fat','Animal Fat',10,1,'item_standard',1,0,278,1,1,'{}','Rendered fat obtained from animals, commonly used in cooking and crafting.',0,NULL,NULL,1.00),('Feather','Feather',20,1,'item_standard',1,0,279,1,1,'{}','A lightweight and delicate feather, often used for decorative purposes.',0,NULL,NULL,1.00),('Feed_For_Dog','Dog Food',10,1,'item_standard',1,0,280,1,1,'{}','Nutritious food specifically formulated for dogs.',0,NULL,NULL,1.00),('fertilizer','Fertilizer',10,1,'item_standard',1,0,281,1,1,'{}','A sack of plain feed for the soil. Speeds a crop along.',0,NULL,NULL,1.00),('fertilizerbless','Blessed Fertilizer',10,1,'item_standard',1,0,282,1,1,'{}','Feed that a preacher said a word over. Some swear it doubles the yield.',0,NULL,NULL,1.00),('fertilizeregg','Egg Fertilizer',10,1,'item_standard',1,0,283,1,1,'{}','Crushed eggshell and spoiled egg worked into compost. Smells awful, works well.',0,NULL,NULL,1.00),('fertilizerpro','Produce Fertilizer',10,1,'item_standard',1,0,284,1,1,'{}','Rotted fruit and vegetable scraps, ready to go back into the ground.',0,NULL,NULL,1.00),('fertilizerpulpsap','Sap Fertilizer',10,1,'item_standard',1,0,285,1,1,'{}','Wood pulp soaked in tree sap. Feeds slow and steady.',0,NULL,NULL,1.00),('fertilizerpure','Pure Fertilizer',25,1,'item_standard',0,0,2596,1,1,'{}','nice item',0,NULL,NULL,1.00),('fertilizersn','Snake Fertilizer',10,1,'item_standard',1,0,286,1,1,'{}','Dried snake ground down into meal. Rich feed for hungry roots.',0,NULL,NULL,1.00),('fertilizersq','Squirrel Fertilizer',10,1,'item_standard',1,0,287,1,1,'{}','What was left of a squirrel, buried and broken down into feed.',0,NULL,NULL,1.00),('fertilizersw','Softwood Fertilizer',10,1,'item_standard',1,0,288,1,1,'{}','Fine pine shavings and sawdust, half rotted. Loosens and feeds the soil.',0,NULL,NULL,1.00),('fertilizerwoj','Wojape Fertilizer',10,1,'item_standard',1,0,290,1,1,'{}','Feed mixed with leftover wojape berry mash. Fruit plants love it.',0,NULL,NULL,1.00),('fiberbandage','Fiber Bandage',25,1,'item_standard',1,0,2764,1,1,'{}','nice item',0,NULL,NULL,1.00),('fibers','Fibers',50,1,'item_standard',0,0,291,1,1,'{}','Fine threads or filaments extracted from plants or animals, often used for crafting or weaving.',0,NULL,NULL,1.00),('finesitab','Top Side Table',25,1,'item_standard',0,0,2610,1,1,'{}','nice item',0,NULL,NULL,1.00),('finouthou','Finouthou',25,1,'item_standard',0,0,2552,1,1,'{}','nice item',0,NULL,NULL,1.00),('firewood','Fire Wood',25,1,'item_standard',0,0,2651,1,1,'{}','nice item',0,NULL,NULL,1.00),('fischow','Fish Chowder',25,1,'item_standard',1,0,2076,1,1,'{}','nice item',0,NULL,NULL,1.00),('fish','Fish',50,1,'item_standard',1,0,292,1,1,'{}','A aquatic creature with fins and scales, commonly caught for food or sport.',0,NULL,NULL,1.00),('fishbait','Fishbait',10,1,'item_standard',1,0,293,1,1,'{}','A substance or lure used to attract fish, increasing the chances of a successful catch.',0,NULL,NULL,1.00),('fishchips','Fish and Chips',10,1,'item_standard',1,0,294,1,1,'{}','A classic dish consisting of fried fish fillets and potato chips, often served with tartar sauce.',0,NULL,NULL,1.00),('fishcookedlmb','Cooked Largemouth Bass (Medium)',25,1,'item_standard',1,0,2008,1,1,'{}','nice item',0,NULL,NULL,1.00),('fishcookedlmblg','Cooked Largemouth Bass (Large)',25,1,'item_standard',1,0,2009,1,1,'{}','nice item',0,NULL,NULL,1.00),('fishmeat','Bigfish Meat',20,1,'item_standard',1,0,295,1,1,'{}','Thick fillets and guts from a large fish. Anything that hunts the water comes for it.',0,NULL,NULL,0.60),('flag','Camp Flag',10,1,'item_standard',1,0,296,1,1,'{}','A colorful and distinctive flag used to mark and identify a campsite or specific location.',0,NULL,NULL,1.00),('flawobed','Flat Wood Bed',25,1,'item_standard',0,0,2447,1,1,'{}','nice item',0,NULL,NULL,1.00),('flocof','Flower Coffin',25,1,'item_standard',0,0,2679,1,1,'{}','nice item',0,NULL,NULL,1.00),('flour','Flour',10,1,'item_standard',1,0,787,1,1,'{}','Ground up wheat used for cooking and baking.',0,NULL,NULL,1.00),('floursack','Flour Sack',10,1,'item_standard',1,0,788,1,1,'{}','A sack of flour.',0,NULL,NULL,1.00),('flowerarrangement','Flower Arrangement',20,1,'item_standard',1,0,1228,1,1,'{}','nice item',0,NULL,NULL,1.00),('flowerboxes','Flower Boxes',20,1,'item_standard',1,0,297,1,1,'{}','Containers or receptacles designed to hold and display blooming flowers, adding beauty and charm to any setting.',0,NULL,NULL,1.00),('flowirontab','Visceral Gold Table',25,1,'item_standard',0,0,2468,1,1,'{}','nice item',0,NULL,NULL,1.00),('folcha','Folding Chair',25,1,'item_standard',0,0,2675,1,1,'{}','nice item',0,NULL,NULL,1.00),('folchaclo','Blanket Folding Chair',25,1,'item_standard',0,0,2444,1,1,'{}','nice item',0,NULL,NULL,1.00),('folstoo','Folding Stool',25,1,'item_standard',0,0,2622,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodannieshotpocketpie','Annie\'s Hot Pocket Pie',25,1,'item_standard',1,0,2239,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodbarrel','Food Barrel',20,1,'item_standard',1,0,298,1,1,'{}','A sturdy barrel used for storing and preserving food items, keeping them fresh and safe from pests.',0,NULL,NULL,1.00),('foodbayouwater','Bayou Water',25,1,'item_standard',1,0,2238,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodbeeandleafmead','Bee & Leaf Mead',25,1,'item_standard',1,0,2189,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodbluelagoon','Blue Lagoon',25,1,'item_standard',1,0,2175,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodbuckbloodstew','Buckblood Stew',25,1,'item_standard',1,0,2202,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodburgerandfries','Burger and Fries',25,1,'item_standard',1,0,2174,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodcaptainsrum','Cpatain\'s Stash Carribean Rum',25,1,'item_standard',1,0,2206,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodcreoledaube','Creole Daube',25,1,'item_standard',1,0,2228,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodcruxnocturna','Crux Nocturna',25,1,'item_standard',1,0,2211,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodcruxsanguinis','Crux Sanguinis',25,1,'item_standard',1,0,2213,1,1,'{}','nice item',0,NULL,NULL,1.00),('fooddallashighprotein','Dallas\'s High Protein Stew',25,1,'item_standard',1,0,2203,1,1,'{}','nice item',0,NULL,NULL,1.00),('fooddirtydavesdinendash','Dirty Dave\'s Dine N Dash',25,1,'item_standard',1,0,2210,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodexpiredbeans','Expired Can of Beans',25,1,'item_standard',1,0,2232,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodfriedchickenbutts','Fried Chicken Butts',25,1,'item_standard',1,0,2225,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodfulltraditional','Full Traditional',25,1,'item_standard',1,0,17350,1,1,'{}','Everything the kitchen had, on one plate. You will not need lunch.',0,NULL,NULL,1.00),('foodgrilledcheesetomatosoup','Grilled Cheese & Tomato Soup',25,1,'item_standard',1,0,2243,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodhoneycutskewers','Honey Cut Skewers',25,1,'item_standard',1,0,2191,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodhumaneye','Human Eye',25,1,'item_standard',1,0,2171,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodhumanheart','Human Heart',25,1,'item_standard',1,0,2170,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodkatteatime','Kat Tea Time',25,1,'item_standard',1,0,2240,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodlazarussglazedcornbread','Lazarus\'s Glazed Cornbread',25,1,'item_standard',1,0,17360,1,1,'{}','Baked golden and glazed while still hot. Sweet enough to drink.',0,NULL,NULL,1.00),('foodleesapplepie','Lee\'s Apple Pie',25,1,'item_standard',1,0,2256,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodleeshoneycoffee','Lee\'s Honey Coffee',25,1,'item_standard',1,0,2255,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodleesmilktea','Lee\'s Milk Tea',25,1,'item_standard',1,0,2229,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodmccarthyscuppa','McCarthy\'s Cuppa',25,1,'item_standard',1,0,2235,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodmccarthysfullenglish','McCarthys\' Full English',25,1,'item_standard',1,0,2234,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodmoonberrypie','Moon Berry Pie',25,1,'item_standard',1,0,2197,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodmudbuddiessnackles','Mud Buddies Snackles',25,1,'item_standard',1,0,2181,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodridemerum','Ride Me Rum',25,1,'item_standard',1,0,17351,1,1,'{}','Dark, sweet and strong enough to argue with. The name was not the distiller\'s idea.',0,NULL,NULL,1.00),('foodrivieracrownedsupper','Riviera Crowned Supper',25,1,'item_standard',1,0,2220,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodryderleesrabbitstew','Ryder Lee\'s Rabbit Stew',25,1,'item_standard',1,0,2241,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodsaltedfries','Salted Fries',25,1,'item_standard',1,0,17352,1,1,'{}','Cut thick, fried twice, salted while still spitting.',0,NULL,NULL,1.00),('foodsexonthebeach','Sex on the Beach',25,1,'item_standard',1,0,17353,1,1,'{}','Fruit, spirit and a great deal of confidence. Served cold.',0,NULL,NULL,1.00),('foodsilasslemontea','Silas\'s Lemontea',25,1,'item_standard',1,0,2226,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodsimsomelette','Sim\'s Omelette',25,1,'item_standard',1,0,2190,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodtanglestew','Tangle Stew',25,1,'item_standard',1,0,2176,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodtrailblazerbites','Trailblazer Bites',25,1,'item_standard',1,0,2254,1,1,'{}','nice item',0,NULL,NULL,1.00),('fooduncleericsenglish','Uncle Eric\'s English Breakfast',25,1,'item_standard',1,0,2244,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodveggienoodles','Veggie Noodles',25,1,'item_standard',1,0,17354,1,1,'{}','Noodles, greens and a broth that has been going since morning.',0,NULL,NULL,1.00),('foodvenisonchili','Venison Chili',25,1,'item_standard',1,0,2169,1,1,'{}','nice item',0,NULL,NULL,1.00),('foodwhitelogale','Whitelog Ale',25,1,'item_standard',1,0,2192,1,1,'{}','nice item',0,NULL,NULL,1.00),('food_barrel','Food Barrel',20,1,'item_standard',1,0,299,1,1,'{}','A large barrel specifically designed for storing and transporting food, ideal for provisioning during long journeys or expeditions.',0,NULL,NULL,1.00),('foostalam','Foostalam',25,1,'item_standard',0,0,2539,1,1,'{}','nice item',0,NULL,NULL,1.00),('foxskin','Fox Pelt',10,1,'item_standard',1,0,300,1,1,'{}','A soft red pelt with a full tail.',0,NULL,NULL,0.80),('foxt','Fox Tooth',25,1,'item_standard',1,0,301,1,1,'{}','A needle-thin tooth from a fox.',0,NULL,NULL,0.05),('freben','Coated Bench',25,1,'item_standard',0,0,2663,1,1,'{}','nice item',0,NULL,NULL,1.00),('fridco','Fried Duck & Crispy Potato',25,1,'item_standard',1,0,2061,1,1,'{}','nice item',0,NULL,NULL,1.00),('friedchicken','Fried Chicken',25,1,'item_standard',1,0,2014,1,1,'{}','nice item',0,NULL,NULL,1.00),('friedtater','Fried Taters',10,1,'item_standard',1,0,302,1,1,'{}','Crispy and delicious fried potatoes.',0,NULL,NULL,1.00),('frogbull2_c','Poisoned Frogbull',20,1,'item_standard',1,0,303,1,1,'{}','A toxic variant of a frogbull.',0,NULL,NULL,1.00),('frogbull_c','Bullfrog',20,1,'item_standard',1,0,304,1,1,'{}','A whole bullfrog, legs and all.',0,NULL,NULL,0.20),('frostew','Frontier Stew',25,1,'item_standard',1,0,2075,1,1,'{}','nice item',0,NULL,NULL,1.00),('fsnakes','Rattlesnake Skin',10,1,'item_standard',1,0,305,1,1,'{}','A patterned skin from a rattlesnake, rattle still on.',0,NULL,NULL,0.30),('game','Game Meat',20,1,'item_standard',1,0,306,1,1,'{}','Fresh meat from a wild animal, good on a spit or in a stew.',0,NULL,NULL,0.60),('Gamey_Meat','Gamey Meat',10,1,'item_standard',1,0,307,1,1,'{}','A type of meat with a distinct gamey flavor.',0,NULL,NULL,1.00),('gang_drug','Gang Product',50,1,'item_standard',1,0,12808,1,1,'{}','A gang\'s own product.',0,NULL,NULL,1.00),('gang_seed','Gang Seed',50,1,'item_standard',1,0,12807,1,1,'{}','Seed stock for a gang\'s own crop.',0,NULL,NULL,1.00),('gang_table','Gang Table',1,1,'item_standard',1,0,1806,1,5,'{}','Place inside a house you own to found a gang.',0,NULL,NULL,1.00),('Gator_Egg_3','Aligator Egg 3',10,1,'item_standard',1,0,308,1,1,'{}','The third stage of an alligator egg.',0,NULL,NULL,1.00),('Gator_Egg_4','Aligator Egg 4',10,1,'item_standard',1,0,309,1,1,'{}','The fourth stage of an alligator egg.',0,NULL,NULL,1.00),('Gator_Egg_5','Aligator Egg 5',10,1,'item_standard',1,0,310,1,1,'{}','The final stage of an alligator egg.',0,NULL,NULL,1.00),('gauntlets','Gauntlets',50,1,'item_standard',1,0,1455,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('gbarrelx','Gun Barrel',20,1,'item_standard',1,0,311,1,1,'{}','A part used in firearm manufacturing.',0,NULL,NULL,1.00),('gbears','Grizzly Hide',10,1,'item_standard',1,0,312,1,1,'{}','A huge brown hide. A tanner pays well for one without holes.',0,NULL,NULL,4.00),('gber','Ginger Beer',25,1,'item_standard',1,0,2053,1,1,'{}','nice item',0,NULL,NULL,1.00),('gilmir','Sentinel Desk',25,1,'item_standard',0,0,2569,1,1,'{}','nice item',0,NULL,NULL,1.00),('ginal','Ginger Ale',25,1,'item_standard',1,0,2052,1,1,'{}','nice item',0,NULL,NULL,1.00),('ginger_dracula','Ginger Dracula',25,1,'item_standard',1,0,16472,3,4,'{}','Gingerbread with a bite taken out of you.',0,NULL,NULL,1.00),('ginpor','Ginseng porridge',25,1,'item_standard',1,0,2069,1,1,'{}','nice item',0,NULL,NULL,1.00),('ginsengtea','Ginseng Tea',10,1,'item_standard',1,0,313,1,1,'{}','A soothing tea made from ginseng roots.',0,NULL,NULL,1.00),('glacab','Glass Cabinet',25,1,'item_standard',0,0,2695,1,1,'{}','nice item',0,NULL,NULL,1.00),('glassbottle','Glass Bottle',50,1,'item_standard',1,0,314,1,1,'{}','A transparent bottle made of glass.',0,NULL,NULL,1.00),('glasseye','Glass Eye',10,1,'item_standard',1,0,789,1,1,'{}','A glass eye. Probably lost in a bar fight.',0,NULL,NULL,1.00),('gleguans','Green Iguana Skin',10,1,'item_standard',1,0,315,1,1,'{}','A bright green, finely scaled skin.',0,NULL,NULL,0.30),('gloves','Gloves',50,1,'item_standard',1,0,1460,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('goathead','Goat head',20,1,'item_standard',1,0,316,1,1,'{}','The severed head of a goat.',0,NULL,NULL,1.00),('goats','Goat Hide',10,1,'item_standard',1,0,317,1,1,'{}','A rough-haired goat hide.',0,NULL,NULL,1.20),('golchar','Gold Linen Chair',25,1,'item_standard',0,0,2650,1,1,'{}','nice item',0,NULL,NULL,1.00),('goldbar','Gold Bar',20,1,'item_standard',0,0,318,1,1,'{}','A bar made of solid gold.',0,NULL,NULL,1.00),('golddust','Gold Dust',500,1,'item_standard',0,0,9203,1,1,'{}','Fine gold washed from river gravel. Worth little alone; smelt it down.',0,NULL,NULL,0.02),('Golden_Currant','Golden Currant',10,1,'item_standard',1,0,319,1,1,'{}','A type of golden-colored currant.',0,NULL,NULL,1.00),('Golden_Currant_Seed','Golden Currant Seed',50,1,'item_standard',1,0,320,1,1,'{}','A seed that can be planted to grow golden currants.',0,NULL,NULL,1.00),('goldfish','Gold Fish',10,1,'item_standard',0,0,321,1,1,'{}','A shimmering gold-colored fish.',0,NULL,NULL,1.00),('goldflake','Gold Flake',200,1,'item_standard',0,0,9204,1,1,'{}','A flake of placer gold, bright against the black sand.',0,NULL,NULL,0.05),('goldflowtab','Visceral Royal Table',25,1,'item_standard',0,0,2751,1,1,'{}','nice item',0,NULL,NULL,1.00),('goldnugget','Gold Nugget',20,1,'item_standard',1,0,1213,1,1,'{}','nice item',0,NULL,NULL,1.00),('goldpan','Gold pan',10,1,'item_standard',1,0,322,1,1,'{}','A shallow pan used for gold panning.',0,NULL,NULL,1.00),('goldring','Gold Ring',10,1,'item_standard',1,0,323,1,1,'{}','A ring made of solid gold.',0,NULL,NULL,1.00),('gold_nugget','Gold nugget',30,1,'item_standard',0,0,324,1,1,'{}','A nugget of pure gold.',0,NULL,NULL,1.00),('gold_panning_license','Gold Panning License',10,1,'item_standard',1,0,790,1,1,'{}','A license to pan gold.',0,NULL,NULL,1.00),('golmirr','Gold Mirror',25,1,'item_standard',0,0,2589,1,1,'{}','nice item',0,NULL,NULL,1.00),('goodbyliquor','Good-bye Liquor',20,1,'item_standard',1,0,1227,1,1,'{}','nice item',0,NULL,NULL,1.00),('gooseb','Goose Beak',25,1,'item_standard',1,0,325,1,1,'{}','A black beak from a Canada goose.',0,NULL,NULL,0.05),('goosef','Goose Feather',50,1,'item_standard',1,0,326,1,1,'{}','A stiff grey quill from a goose. Writes well once cut.',0,NULL,NULL,0.02),('Goose_Egg_4','Goose Egg',10,1,'item_standard',1,0,327,1,1,'{}','An egg laid by a goose.',0,NULL,NULL,1.00),('grainmill','Grain Mill',10,1,'item_standard',1,0,791,1,1,'{}','A hand-held Grain Mill for grinding grain.',0,NULL,NULL,1.00),('grama','Grama',25,1,'item_standard',0,0,2595,1,1,'{}','nice item',0,NULL,NULL,1.00),('granclo','Grandfather Clock',25,1,'item_standard',0,0,2592,1,1,'{}','nice item',0,NULL,NULL,1.00),('grantrunk','Grain Trunk',25,1,'item_standard',0,0,2631,1,1,'{}','nice item',0,NULL,NULL,1.00),('grapes','Grapes',10,1,'item_standard',1,0,792,1,1,'{}','A tasty fruit that grows in clusters. Often used to make wine.',0,NULL,NULL,1.00),('grechar','Tall Boy Chair',25,1,'item_standard',0,0,2462,1,1,'{}','nice item',0,NULL,NULL,1.00),('greenpaint','Green Paint',25,1,'item_standard',0,0,2508,1,1,'{}','nice item',0,NULL,NULL,1.00),('grenlan','Green Lantern',25,1,'item_standard',0,0,2572,1,1,'{}','nice item',0,NULL,NULL,1.00),('greycomchar','Grey Comfy Chair',25,1,'item_standard',0,0,2460,1,1,'{}','nice item',0,NULL,NULL,1.00),('grinder','Grinder',10,1,'item_standard',1,0,793,1,1,'{}','Used to crush up and grind herbs and plants.',0,NULL,NULL,1.00),('gruskull','Skull Group Post',25,1,'item_standard',0,0,2674,1,1,'{}','nice item',0,NULL,NULL,1.00),('guitar','Classic Guitar',1,1,'item_standard',1,0,328,1,1,'{}','A traditional six-string guitar.',0,NULL,NULL,1.00),('gunbelts','Gunbelts',50,1,'item_standard',1,0,1448,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('gunbelt_accs','Gunbelt Accs',50,1,'item_standard',1,0,1452,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('gunpowder','Gunpowder',50,1,'item_standard',0,0,3034,4,1,'{}','Coarse black powder in a waxed paper twist. Keep it dry, keep it away from the fire, and do not drop it.',0,NULL,NULL,1.00),('gunrac','Rifle Case',20,1,'item_standard',1,0,4395,1,1,'{}','nice item',0,NULL,NULL,1.00),('gunrak','Weapon Case',20,1,'item_standard',1,0,4396,1,1,'{}','nice item',0,NULL,NULL,1.00),('gun_barrel','Gun Barrel',20,1,'item_standard',1,0,329,1,1,'{}','A cylindrical barrel used in firearm construction.',0,NULL,NULL,1.00),('gypsywagon','Gypsys Wagon Set',20,1,'item_standard',1,0,330,1,1,'{}','A set of items related to a gypsy wagon.',0,NULL,NULL,1.00),('hairpomade','Hair Pomade',5,1,'item_standard',1,0,331,1,1,'{}','A grooming product for styling hair.',0,NULL,NULL,1.00),('hair_accessories','Bows',50,1,'item_standard',1,0,1449,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('halfsku','Severed Skull',25,1,'item_standard',0,0,2761,1,1,'{}','nice item',0,NULL,NULL,1.00),('hammer02','Sledge Hammer',1,1,'item_standard',1,0,1506,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('hammer_wep','Hammer',1,1,'item_standard',1,0,22153,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('handcuffkey','Handcuff Key',1,1,'item_standard',1,0,959,1,1,'{}','A key used to unlock handcuffs.',0,NULL,NULL,1.00),('handcuffs','Handcuffs',10,1,'item_standard',1,0,332,1,1,'{}','Metal restraints used for restraining someone.',0,NULL,NULL,1.00),('handmixer','Handmixer',10,1,'item_standard',1,0,794,1,1,'{}','A hand-held mixing device',0,NULL,NULL,1.00),('handsaw','Handsaw',10,1,'item_standard',1,0,795,1,1,'{}','A hand saw used to cut wood',0,NULL,NULL,1.00),('hangbon','Bone Dream Catcher',25,1,'item_standard',0,0,2617,1,1,'{}','nice item',0,NULL,NULL,1.00),('hatchet','Hatchet',10,1,'item_standard',1,0,333,1,1,'{}','A small axe with a short handle.',0,100,NULL,1.00),('hatchet_wep','Camp Hatchet',1,1,'item_standard',1,0,30509,1,1,'{}','A blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('hats','Hats',50,1,'item_standard',1,0,1471,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('hawkf','Hawk Feather',50,1,'item_standard',1,0,334,1,1,'{}','A barred brown feather from a hawk.',0,NULL,NULL,0.05),('hawkt','Hawk Talon',25,1,'item_standard',1,0,335,1,1,'{}','A small, sharp talon from a hawk.',0,NULL,NULL,0.05),('Health_For_Dog','Pet Bandages',10,1,'item_standard',1,0,336,1,1,'{}','Bandages designed for treating injuries in pets.',0,NULL,NULL,1.00),('hearo','Hunted Skull',25,1,'item_standard',0,0,2619,1,1,'{}','nice item',0,NULL,NULL,1.00),('hemp','Hemp',25,1,'item_standard',1,0,337,1,1,'{}','Tough stalks for rope, sacking and cloth.',0,NULL,NULL,1.00),('hemp_cig','Hemp Cigarette',1,1,'item_standard',1,0,338,1,1,'{}','A cigarette made from hemp leaves.',0,NULL,NULL,1.00),('hemp_seed','Hemp Seed',50,1,'item_standard',1,0,339,1,1,'{}','Seed for a tall stand of hemp.',0,NULL,NULL,1.00),('herbal_medicine','Herbal Medicine',20,1,'item_standard',1,0,340,1,1,'{}','Medicine made from natural herbal ingredients.',0,NULL,NULL,1.00),('herbal_tonic','Herbal Tonic',20,1,'item_standard',1,0,341,1,1,'{}','A tonic made from herbal extracts.',0,NULL,NULL,1.00),('herbmed','Herbal Remedy',10,1,'item_standard',1,0,342,1,1,'{}','A remedy made from various herbs.',0,NULL,NULL,1.00),('heroin','Heroin',20,1,'item_standard',1,0,343,1,1,'{}','A highly addictive and illegal drug.',0,NULL,NULL,1.00),('herptile','Reptile Meat',20,1,'item_standard',1,0,344,1,1,'{}','Pale, firm meat from a snake, lizard or gator. Tastes like whatever you were hoping for.',0,NULL,NULL,0.40),('hideout_plans','Hideout Plans',1,1,'item_standard',1,0,14025,1,5,'{}','nice item',0,NULL,NULL,1.00),('hitchingpost','Hitching Post',20,1,'item_standard',1,0,345,1,1,'{}','A post used for tying up horses.',0,NULL,NULL,1.00),('hk_1','House Key',1,1,'item_standard',1,0,961,1,1,'{}','A standard house key.',0,NULL,NULL,1.00),('hk_101','House Key',1,1,'item_standard',1,0,964,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_102','House Key',1,1,'item_standard',1,0,965,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_103','House Key',1,1,'item_standard',1,0,966,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_104','House Key',1,1,'item_standard',1,0,967,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_105','House Key',1,1,'item_standard',1,0,968,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_106','House Key',1,1,'item_standard',1,0,969,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_107','House Key',1,1,'item_standard',1,0,970,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_108','House Key',1,1,'item_standard',1,0,971,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_109','House Key',1,1,'item_standard',1,0,972,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_110','House Key',1,1,'item_standard',1,0,973,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_111','House Key',1,1,'item_standard',1,0,974,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_112','House Key',1,1,'item_standard',1,0,975,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_113','House Key',1,1,'item_standard',1,0,976,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_114','House Key',1,1,'item_standard',1,0,977,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_115','House Key',1,1,'item_standard',1,0,978,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_116','House Key',1,1,'item_standard',1,0,979,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_117','House Key',1,1,'item_standard',1,0,980,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_118','House Key',1,1,'item_standard',1,0,981,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_119','House Key',1,1,'item_standard',1,0,982,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_120','House Key',1,1,'item_standard',1,0,983,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_121','House Key',1,1,'item_standard',1,0,984,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_122','House Key',1,1,'item_standard',1,0,985,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_123','House Key',1,1,'item_standard',1,0,986,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_124','House Key',1,1,'item_standard',1,0,987,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_125','House Key',1,1,'item_standard',1,0,988,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_126','House Key',1,1,'item_standard',1,0,989,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_127','House Key',1,1,'item_standard',1,0,990,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_128','House Key',1,1,'item_standard',1,0,991,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_129','House Key',1,1,'item_standard',1,0,992,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_130','House Key',1,1,'item_standard',1,0,993,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_131','House Key',1,1,'item_standard',1,0,994,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_132','House Key',1,1,'item_standard',1,0,995,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_133','House Key',1,1,'item_standard',1,0,996,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_134','House Key',1,1,'item_standard',1,0,997,1,1,'{}','A specialized house key.',0,NULL,NULL,1.00),('hk_2','House Key',1,1,'item_standard',1,0,962,1,1,'{}','A standard house key.',0,NULL,NULL,1.00),('hk_3','House Key',1,1,'item_standard',1,0,963,1,1,'{}','A standard house key.',0,NULL,NULL,1.00),('hochoc','Hot Chocolate',25,1,'item_standard',1,0,2250,1,1,'{}','nice item',0,NULL,NULL,1.00),('hoe','Garden Hoe',10,1,'item_standard',1,0,346,1,1,'{}','Breaks the ground for planting. You need one in your satchel to sow.',0,NULL,NULL,1.00),('holgo','Horse Oats',20,1,'item_standard',1,0,1961,1,1,'{}','nice item',0,NULL,NULL,1.00),('holsters_left','Holster',50,1,'item_standard',1,0,1457,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('holywater','Holy Water',25,1,'item_standard',0,0,2566,1,1,'{}','nice item',0,NULL,NULL,1.00),('honey','Honey',50,1,'item_standard',1,0,347,1,1,'{}','A sweet and sticky substance produced by bees.',0,NULL,NULL,1.00),('hook_knife','Hoof Knife',1,1,'item_standard',1,0,22154,1,5,'{}','A short blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('hop','Hop',50,1,'item_standard',1,0,348,1,1,'{}','Green hop cones that give beer its bitter edge.',0,NULL,NULL,1.00),('hop_seed','Hop Seed',50,1,'item_standard',1,0,349,1,1,'{}','Seed for a climbing hop vine. Brewers will want what it grows.',0,NULL,NULL,1.00),('horsebrush','Horse Brush',5,1,'item_standard',1,0,350,1,1,'{}','A brush used for grooming horses.',0,NULL,NULL,1.00),('horsehitches','Horse Hitches Set',20,1,'item_standard',1,0,351,1,1,'{}','A set of items used for hitching horses.',0,NULL,NULL,1.00),('horsemeal','Horse ration',10,1,'item_standard',1,0,352,1,1,'{}','Food provided to horses for sustenance.',0,NULL,NULL,1.00),('horse_coat_changer','Horse Coat Tonic',10,1,'item_standard',1,0,2825,1,1,'{}','nice item',0,NULL,NULL,1.00),('horse_reviver','Horse Reviver',25,1,'item_standard',1,0,2504,1,1,'{}','nice item',0,NULL,NULL,1.00),('horse_whip_weapons','Horse Whip',1,1,'item_standard',1,0,22156,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('horsod','HoreHound Soda',25,1,'item_standard',1,0,2058,1,1,'{}','nice item',0,NULL,NULL,1.00),('Hummingbird_Sage','Hummingbird Sage',10,1,'item_standard',1,0,353,1,1,'{}','A type of sage plant favored by hummingbirds.',0,NULL,NULL,1.00),('Hummingbird_Sage_Seed','Hummingbird Sage Seed',50,1,'item_standard',1,0,354,1,1,'{}','A seed that can be planted to grow hummingbird sage.',0,NULL,NULL,1.00),('humsku','Human Skull',25,1,'item_standard',0,0,2576,1,1,'{}','nice item',0,NULL,NULL,1.00),('huthh','Hutch',25,1,'item_standard',0,0,2486,1,1,'{}','nice item',0,NULL,NULL,1.00),('hwood','Hard Wood',50,1,'item_standard',0,0,355,1,1,'{}','Durable and strong wood used in various applications.',0,NULL,NULL,1.00),('hwoodboard','Hwoodboard',25,1,'item_standard',0,0,2450,1,1,'{}','nice item',0,NULL,NULL,1.00),('iguanabits','Iguana Bits',10,1,'item_standard',1,0,796,1,1,'{}','Tasy cooked Iguna pieces.',0,NULL,NULL,1.00),('illegalsyringe','Illegal Syringe',10,1,'item_standard',1,0,2834,1,1,'{}','nice item',0,NULL,NULL,1.00),('incocouc','Visceral Cut Couch',25,1,'item_standard',0,0,2607,1,1,'{}','nice item',0,NULL,NULL,1.00),('Indian_Tobbaco','Indian Tobacco',50,1,'item_standard',1,0,356,1,1,'{}','A small wild tobacco plant, smoked or brewed by those who know it.',0,NULL,NULL,1.00),('Indian_Tobbaco_Seed','Indian Tobacco Seed',50,1,'item_standard',1,0,357,1,1,'{}','Dust-fine seed for Indian tobacco.',0,NULL,NULL,1.00),('ink','Ink',10,1,'item_standard',1,0,797,1,1,'{}','A small bottle of ink.',0,NULL,NULL,1.00),('irobed','Iron Bed',25,1,'item_standard',0,0,2620,1,1,'{}','nice item',0,NULL,NULL,1.00),('iroblaben','Iroblaben',25,1,'item_standard',0,0,2662,1,1,'{}','nice item',0,NULL,NULL,1.00),('irocan','Iron Stand Candle',25,1,'item_standard',0,0,2656,1,1,'{}','nice item',0,NULL,NULL,1.00),('irocoftab','Iron Coffee Table',25,1,'item_standard',0,0,2611,1,1,'{}','nice item',0,NULL,NULL,1.00),('irodes','Ironclad Desk',25,1,'item_standard',0,0,2547,1,1,'{}','nice item',0,NULL,NULL,1.00),('iron','Iron',50,1,'item_standard',0,0,358,1,1,'{}','A strong and durable metal.',0,NULL,NULL,1.00),('ironbar','Iron Bar',50,1,'item_standard',1,0,359,1,1,'{}','A solid bar made of iron, known for its strength and durability.',0,NULL,NULL,1.00),('ironextract','Iron Extract',1,1,'item_standard',0,0,360,1,1,'{}','A concentrated form of iron, extracted from natural sources.',0,NULL,NULL,1.00),('ironhammer','Iron Hammer',5,1,'item_standard',1,0,361,1,1,'{}','A hammer with a head made of iron, used for various construction and crafting purposes.',0,NULL,NULL,1.00),('irotrunk','Iron Trunk',25,1,'item_standard',0,0,2632,1,1,'{}','nice item',0,NULL,NULL,1.00),('irowhiben','Irowhiben',25,1,'item_standard',0,0,2661,1,1,'{}','nice item',0,NULL,NULL,1.00),('ivnocouc','Visceral Pillow Couch',25,1,'item_standard',0,0,2520,1,1,'{}','nice item',0,NULL,NULL,1.00),('jamango','Mango Jam',25,1,'item_standard',1,0,2097,1,1,'{}','nice item',0,NULL,NULL,1.00),('jambalaya','Jambalaya',25,1,'item_standard',1,0,2152,1,1,'{}','nice item',0,NULL,NULL,1.00),('jamblackcur','Black Currant Jam',25,1,'item_standard',1,0,2098,1,1,'{}','nice item',0,NULL,NULL,1.00),('jamblue','Blueberry Jam',25,1,'item_standard',1,0,2099,1,1,'{}','nice item',0,NULL,NULL,1.00),('jamlemon','Lemon Jam',25,1,'item_standard',1,0,2100,1,1,'{}','nice item',0,NULL,NULL,1.00),('jampeach','Peach Jam',25,1,'item_standard',1,0,2101,1,1,'{}','nice item',0,NULL,NULL,1.00),('jamplum','Creek Plum Jam',25,1,'item_standard',1,0,2102,1,1,'{}','nice item',0,NULL,NULL,1.00),('jamras','Raspberry Jam',25,1,'item_standard',1,0,2103,1,1,'{}','nice item',0,NULL,NULL,1.00),('jamstraw','Strawberry Jam',25,1,'item_standard',1,0,2104,1,1,'{}','nice item',0,NULL,NULL,1.00),('jewelry_bracelets','Bracelets',50,1,'item_standard',1,0,1472,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('jewelry_rings_left','Ring Lh',50,1,'item_standard',1,0,1458,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('jewelry_rings_right','Ring Rh',50,1,'item_standard',1,0,1459,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('joint','Joint',20,1,'item_standard',1,0,1231,1,1,'{}','nice item',0,NULL,NULL,1.00),('jollytrunk','Jolly Jacks Trunk',25,1,'item_standard',0,0,2456,1,1,'{}','nice item',0,NULL,NULL,1.00),('kbirdb','Heron Beak',25,1,'item_standard',1,0,362,1,1,'{}','A long, spear-like beak from a heron.',0,NULL,NULL,0.05),('kbirdf','Heron Plume',50,1,'item_standard',1,0,363,1,1,'{}','A blue-grey plume from a great blue heron.',0,NULL,NULL,0.05),('kcondorb','Condor Beak',25,1,'item_standard',1,0,31819,1,1,'{}','A heavy hooked beak from a condor.',0,NULL,NULL,0.10),('kcondorf','Condor Feather',50,1,'item_standard',1,0,31818,1,1,'{}','A huge black feather from a California condor.',0,NULL,NULL,0.05),('kindling','Kindling',25,1,'item_standard',0,0,2688,1,1,'{}','nice item',0,NULL,NULL,1.00),('kitchencounter','Kitchen Counter',20,1,'item_standard',1,0,364,1,1,'{}','A sturdy counter surface typically found in kitchens, providing space for food preparation and other tasks.',0,NULL,NULL,1.00),('kithuthh','Kitchen Hutch',25,1,'item_standard',0,0,2581,1,1,'{}','nice item',0,NULL,NULL,1.00),('kitsup','Chicken & Carrot Soup',25,1,'item_standard',1,0,2148,1,1,'{}','nice item',0,NULL,NULL,1.00),('kit_bandana','Bandana',2,1,'item_standard',1,0,365,1,1,'{}','A versatile and stylish piece of cloth that can be worn around the neck or head for various purposes. It adds a touch of fashion to any outfit.',0,NULL,NULL,1.00),('knife01','Large Knife',1,1,'item_standard',1,0,1521,1,5,'{}','A short blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('lad','Ladder',25,1,'item_standard',0,0,2664,1,1,'{}','nice item',0,NULL,NULL,1.00),('laddera','Ladder',10,1,'item_standard',0,0,32990,1,1,'{}','nice item',0,NULL,NULL,1.00),('lamppost1','Lamp Post 1 Set',20,1,'item_standard',1,0,366,1,1,'{}','A set of Lamp Post 1',0,NULL,NULL,1.00),('lamppost2','Lamp Post 2 Set',20,1,'item_standard',1,0,367,1,1,'{}','A set of Lamp Post 2',0,NULL,NULL,1.00),('lana','Lana',25,1,'item_standard',0,0,2466,1,1,'{}','nice item',0,NULL,NULL,1.00),('lanterna','Lantern',20,1,'item_standard',1,0,368,1,1,'{}','A lantern',0,NULL,NULL,1.00),('larhuthh','Large Hutch',25,1,'item_standard',0,0,2530,1,1,'{}','nice item',0,NULL,NULL,1.00),('lawcha','Lawcha',25,1,'item_standard',0,0,2709,1,1,'{}','nice item',0,NULL,NULL,1.00),('leather','Leather',50,1,'item_standard',1,0,369,1,1,'{}','Leather material',0,NULL,NULL,1.00),('leatherchair','Leather Chair',20,1,'item_standard',1,0,370,1,1,'{}','A leather chair',0,NULL,NULL,1.00),('leather_chair','Leather Chair',20,1,'item_standard',1,0,371,1,1,'{}','A leather chair',0,NULL,NULL,1.00),('legalbook','Legal Book',1,1,'item_standard',1,0,372,1,1,'{}','A legal book',0,NULL,NULL,1.00),('legaligators','Legendary Alligator Hide',5,1,'item_standard',0,0,373,1,1,'{}','Armoured, knobbled hide from a legendary alligator.',0,NULL,NULL,4.00),('legaligators1','Teca Alligator Hide',5,1,'item_standard',0,0,374,1,1,'{}','Dark, ridged hide from the Teca Alligator.',0,NULL,NULL,4.00),('legaligators2','Sun Alligator Hide',5,1,'item_standard',0,0,375,1,1,'{}','A yellow-banded hide from the Sun Alligator.',0,NULL,NULL,4.00),('legaligators3','Banded Alligator Hide',5,1,'item_standard',0,0,376,1,1,'{}','A hide striped light and dark, from the Banded Alligator.',0,NULL,NULL,4.00),('legalpaper','Legal Paper',4,1,'item_standard',1,0,377,1,1,'{}','Legal paper',0,NULL,NULL,1.00),('legbears1','Deadly Bear Hide',5,1,'item_standard',0,0,378,1,1,'{}','Coarse dark fur from the Deadly Bear, torn along one flank from old fights.',0,NULL,NULL,5.00),('legbears2','Owiza Bear Hide',5,1,'item_standard',0,0,379,1,1,'{}','A thick, warm hide from the Owiza Bear, prized for bedrolls.',0,NULL,NULL,5.00),('legbears3','Ridgeback Spirit Bear Hide',5,1,'item_standard',0,0,380,1,1,'{}','Pale fur with a raised ridge down the spine, from the Ridgeback Spirit Bear.',0,NULL,NULL,5.00),('legbears4','Golden Spirit Bear Hide',5,1,'item_standard',0,0,381,1,1,'{}','A hide that shines gold in the sun, from the Golden Spirit Bear.',0,NULL,NULL,5.00),('legbeavers1','Grey Beaver Pelt',5,1,'item_standard',0,0,382,1,1,'{}','A dense grey pelt from the Grey Beaver.',0,NULL,NULL,1.50),('legbeavers2','White Beaver Pelt',5,1,'item_standard',0,0,383,1,1,'{}','An unusual pale pelt from the White Beaver.',0,NULL,NULL,1.50),('legbeavers3','Black Beaver Pelt',5,1,'item_standard',0,0,384,1,1,'{}','A deep black pelt from the Black Beaver, the hatters\' favourite.',0,NULL,NULL,1.50),('legbeawers','Legendary Beaver Pelt',5,1,'item_standard',0,0,385,1,1,'{}','A thick, water-shedding pelt from a legendary beaver.',0,NULL,NULL,1.50),('legbisonhorn','Legendary Bison Horns',10,1,'item_standard',0,0,386,1,1,'{}','Short, thick horns worn smooth by a legendary bison.',0,NULL,NULL,2.00),('legbisons','Legendary Bison Robe',5,1,'item_standard',0,0,387,1,1,'{}','A shaggy robe from a legendary bison. Warm enough for a Grizzlies winter.',0,NULL,NULL,5.00),('legbisons1','Tatanka Bison Robe',5,1,'item_standard',0,0,388,1,1,'{}','A dark, heavy robe from the Tatanka Bison.',0,NULL,NULL,5.00),('legbisons2','Winyan Bison Robe',5,1,'item_standard',0,0,389,1,1,'{}','A lighter, red-brown robe from the Winyan Bison.',0,NULL,NULL,5.00),('legbisons3','Payata Bison Robe',5,1,'item_standard',0,0,390,1,1,'{}','A pale-shouldered robe from the Payata Bison.',0,NULL,NULL,5.00),('legbisonstak','Great Tatanka Bison Robe',5,1,'item_standard',0,0,391,1,1,'{}','The largest robe the plains have to give, from the great Tatanka bull.',0,NULL,NULL,6.00),('legboars','Legendary Boar Hide',5,1,'item_standard',0,0,392,1,1,'{}','Bristled, tough hide from a legendary boar.',0,NULL,NULL,3.00),('legboars1','Cogi Boar Hide',5,1,'item_standard',0,0,393,1,1,'{}','A reddish, bristled hide from the Cogi Boar.',0,NULL,NULL,3.00),('legboars2','Wakpa Boar Hide',5,1,'item_standard',0,0,394,1,1,'{}','A dark, mud-caked hide from the Wakpa Boar.',0,NULL,NULL,3.00),('legboars3','Icahi Boar Hide',5,1,'item_standard',0,0,395,1,1,'{}','A mottled hide from the Icahi Boar.',0,NULL,NULL,3.00),('legboars4','Wildhog Hide',5,1,'item_standard',0,0,396,1,1,'{}','A scarred, wiry hide from the Legendary Wildhog.',0,NULL,NULL,3.00),('legbucks','Legendary Whitetail Hide',5,1,'item_standard',0,0,397,1,1,'{}','A clean, pale-bellied hide from a legendary whitetail buck.',0,NULL,NULL,2.00),('legbucks1','Legendary Buck Hide',5,1,'item_standard',0,0,398,1,1,'{}','A fine, even hide from a legendary buck.',0,NULL,NULL,2.00),('legbucks2','Mudrunner Buck Hide',5,1,'item_standard',0,0,399,1,1,'{}','A brown hide splashed darker at the legs, from the Mudrunner Buck.',0,NULL,NULL,2.00),('legbucks3','Snow Buck Hide',5,1,'item_standard',0,0,400,1,1,'{}','A white winter hide from the Snow Buck.',0,NULL,NULL,2.00),('legbucks4','Shadow Buck Hide',5,1,'item_standard',0,0,401,1,1,'{}','A dusky, almost black hide from the Shadow Buck.',0,NULL,NULL,2.00),('legcougars','Legendary Cougar Pelt',5,1,'item_standard',0,0,402,1,1,'{}','A long, supple pelt from a legendary cougar.',0,NULL,NULL,2.50),('legcougars1','Iguga Cougar Pelt',5,1,'item_standard',0,0,403,1,1,'{}','A sandy pelt from the Iguga Cougar.',0,NULL,NULL,2.50),('legcougars2','Maza Cougar Pelt',5,1,'item_standard',0,0,404,1,1,'{}','A heavy, dark-tipped pelt from the Maza Cougar.',0,NULL,NULL,2.50),('legcougars3','Sapa Cougar Pelt',5,1,'item_standard',0,0,405,1,1,'{}','A smoky pelt from the Sapa Cougar.',0,NULL,NULL,2.50),('legcougars4','Black Cougar Pelt',5,1,'item_standard',0,0,406,1,1,'{}','A rare, near-black pelt from the Black Cougar.',0,NULL,NULL,2.50),('legcoyotes','Legendary Coyote Pelt',5,1,'item_standard',0,0,407,1,1,'{}','A thin but handsome pelt from a legendary coyote.',0,NULL,NULL,1.50),('legcoyotes1','Red Streak Coyote Pelt',5,1,'item_standard',0,0,408,1,1,'{}','Tawny fur with a rust-red stripe, from the Red Streak Coyote.',0,NULL,NULL,1.50),('legcoyotes2','Midnight Paw Coyote Pelt',5,1,'item_standard',0,0,409,1,1,'{}','A light pelt with dark legs, from the Midnight Paw Coyote.',0,NULL,NULL,1.50),('legcoyotes3','Milk Coyote Pelt',5,1,'item_standard',0,0,410,1,1,'{}','A pale, almost white pelt from the Milk Coyote.',0,NULL,NULL,1.50),('legelkantler','Legendary Elk Antlers',10,1,'item_standard',0,0,411,1,1,'{}','Sweeping antlers from a legendary elk, still in velvet at the tips.',0,NULL,NULL,2.50),('legelks','Legendary Elk Hide',5,1,'item_standard',0,0,412,1,1,'{}','A big, heavy-maned hide from a legendary elk.',0,NULL,NULL,3.50),('legelks1','Katata Elk Hide',5,1,'item_standard',0,0,413,1,1,'{}','A tawny hide from the Katata Elk.',0,NULL,NULL,3.50),('legelks2','Ozula Elk Hide',5,1,'item_standard',0,0,414,1,1,'{}','A dark-necked hide from the Ozula Elk.',0,NULL,NULL,3.50),('legelks3','Inahme Elk Hide',5,1,'item_standard',0,0,415,1,1,'{}','A pale, frosted hide from the Inahme Elk.',0,NULL,NULL,3.50),('legendbuckantler','Legendary Buck Antlers',10,1,'item_standard',0,0,416,1,1,'{}','A wide, many-pointed rack from a legendary buck.',0,NULL,NULL,1.50),('legendsnakes','Legendary Boa Skin',5,1,'item_standard',0,0,417,1,1,'{}','Ten feet of patterned skin from a legendary boa.',0,NULL,NULL,1.50),('legfoxs1','Ota Fox Pelt',5,1,'item_standard',0,0,5539,1,1,'{}','A fine pelt from the Ota Fox, soft enough for a lady\'s collar.',0,NULL,NULL,1.00),('legfoxs2','Marble Fox Pelt',5,1,'item_standard',0,0,418,1,1,'{}','Grey and white fur swirled like stone, from the Marble Fox.',0,NULL,NULL,1.00),('legfoxs3','Cross Fox Pelt',5,1,'item_standard',0,0,419,1,1,'{}','Red fur crossed with a dark band over the shoulders, from the Cross Fox.',0,NULL,NULL,1.00),('legfoxskin','Legendary Fox Pelt',5,1,'item_standard',0,0,420,1,1,'{}','A bright, full-tailed pelt from a legendary fox.',0,NULL,NULL,1.00),('leggbears','Legendary Bear Hide',5,1,'item_standard',0,0,421,1,1,'{}','A vast, scarred hide off a legendary grizzly. It takes a wagon to carry more than one.',0,NULL,NULL,5.00),('legmooseantler','Legendary Moose Antlers',10,1,'item_standard',0,0,422,1,1,'{}','Broad, flat palms of antler from a legendary moose. Heavy enough to need two hands.',0,NULL,NULL,3.50),('legmooses','Legendary Moose Hide',5,1,'item_standard',0,0,423,1,1,'{}','A huge, coarse hide from a legendary moose.',0,NULL,NULL,4.50),('legmooses1','Snowflake Moose Hide',5,1,'item_standard',0,0,424,1,1,'{}','A hide flecked with white, from the Snowflake Moose.',0,NULL,NULL,4.50),('legmooses2','Knight Moose Hide',5,1,'item_standard',0,0,425,1,1,'{}','A dark, stately hide from the Knight Moose.',0,NULL,NULL,4.50),('legmooses3','Ruddy Moose Hide',5,1,'item_standard',0,0,426,1,1,'{}','A red-brown hide from the Ruddy Moose.',0,NULL,NULL,4.50),('legpanthers1','Nightwalker Panther Pelt',5,1,'item_standard',0,0,427,1,1,'{}','A glossy black pelt from the Nightwalker Panther.',0,NULL,NULL,2.50),('legpanthers2','Ghost Panther Pelt',5,1,'item_standard',0,0,428,1,1,'{}','A pale, faintly spotted pelt from the Ghost Panther.',0,NULL,NULL,2.50),('legpanthers3','Iwakta Panther Pelt',5,1,'item_standard',0,0,429,1,1,'{}','A sleek pelt from the Iwakta Panther, the largest of the three.',0,NULL,NULL,2.50),('legprongs','Legendary Pronghorn Hide',5,1,'item_standard',0,0,430,1,1,'{}','A light, banded hide from a legendary pronghorn.',0,NULL,NULL,1.50),('legramhorn','Legendary Ram Horns',10,1,'item_standard',0,0,431,1,1,'{}','A full curl of ridged horn from a legendary ram.',0,NULL,NULL,2.00),('legrams','Legendary Ram Fleece',5,1,'item_standard',0,0,432,1,1,'{}','A thick, curled fleece from a legendary bighorn.',0,NULL,NULL,2.50),('legrams1','Gabbro Horn Ram Fleece',5,1,'item_standard',0,0,433,1,1,'{}','A dark grey fleece from the Gabbro Horn Ram.',0,NULL,NULL,2.50),('legrams2','Chalk Horn Ram Fleece',5,1,'item_standard',0,0,434,1,1,'{}','A chalk-pale fleece from the Chalk Horn Ram.',0,NULL,NULL,2.50),('legrams3','Rutile Horn Ram Fleece',5,1,'item_standard',0,0,435,1,1,'{}','A fleece with a coppery cast, from the Rutile Horn Ram.',0,NULL,NULL,2.50),('legrams4','Great Horn Ram Fleece',5,1,'item_standard',0,0,436,1,1,'{}','The heaviest fleece of any ram, from the Great Horn Ram.',0,NULL,NULL,2.50),('legwolfpelt','Legendary Wolf Pelt',5,1,'item_standard',0,0,437,1,1,'{}','A long, grizzled pelt from a legendary wolf.',0,NULL,NULL,2.50),('legwolfs1','Emerald Wolf Pelt',5,1,'item_standard',0,0,438,1,1,'{}','A dense pelt from the Emerald Wolf, with a green sheen in some light.',0,NULL,NULL,2.50),('legwolfs2','Onyx Wolf Pelt',5,1,'item_standard',0,0,439,1,1,'{}','Jet-black fur from the Onyx Wolf.',0,NULL,NULL,2.50),('legwolfs3','Moonstone Wolf Pelt',5,1,'item_standard',0,0,440,1,1,'{}','Silver-grey fur from the Moonstone Wolf, soft as smoke.',0,NULL,NULL,2.50),('lemon','Lemon',50,1,'item_standard',1,0,1987,1,1,'{}','nice item',0,NULL,NULL,1.00),('lemonad','Lemonade',25,1,'item_standard',1,0,2105,1,1,'{}','nice item',0,NULL,NULL,1.00),('lemonadmang','Mango Lemonade',25,1,'item_standard',1,0,2106,1,1,'{}','nice item',0,NULL,NULL,1.00),('lemonadstraw','Strawberry Lemonade',25,1,'item_standard',1,0,2107,1,1,'{}','nice item',0,NULL,NULL,1.00),('lemondblue','Blueberry Lemonade',25,1,'item_standard',1,0,2108,1,1,'{}','nice item',0,NULL,NULL,1.00),('lemondorange','Orange Lemonade',25,1,'item_standard',1,0,2109,1,1,'{}','nice item',0,NULL,NULL,1.00),('lemondpear','Pear Lemonade',25,1,'item_standard',1,0,2110,1,1,'{}','nice item',0,NULL,NULL,1.00),('lemondras','Raspberry Lemonade',25,1,'item_standard',1,0,2111,1,1,'{}','nice item',0,NULL,NULL,1.00),('lense','Lenses',25,1,'item_standard',0,0,2737,1,1,'{}','nice item',0,NULL,NULL,1.00),('letter','Letter',20,1,'item_standard',1,0,11940,1,1,'{}','nice item',0,NULL,NULL,1.00),('lifeticket','Lifetime Ticket',25,1,'item_standard',0,0,2590,1,1,'{}','nice item',0,NULL,NULL,1.00),('lincof','Sealed Coffin',25,1,'item_standard',0,0,2676,1,1,'{}','nice item',0,NULL,NULL,1.00),('lizardl','Gila Foot',25,1,'item_standard',1,0,441,1,1,'{}','A dried foot from a gila monster.',0,NULL,NULL,0.05),('lizards','Gila Monster Skin',10,1,'item_standard',1,0,442,1,1,'{}','A beaded orange and black skin from a gila monster.',0,NULL,NULL,0.30),('lnitronectar','Lavey Nitro Nectar',20,1,'item_standard',1,0,7757,1,1,'{}','Goes off like a firecracker.',0,NULL,NULL,1.00),('loadouts','Loadouts',50,1,'item_standard',1,0,1454,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('lockpick','Lockpick',5,1,'item_standard',1,0,443,1,1,'{}','A handy tool used for picking locks',0,NULL,NULL,1.00),('lockpickmold','Lockpick Mold',25,1,'item_standard',1,0,444,1,1,'{}','A mold used for crafting lockpicks',0,NULL,NULL,1.00),('logbechs','Log Bench 2',20,1,'item_standard',1,0,445,1,1,'{}','A sturdy and rustic log bench design',0,NULL,NULL,1.00),('logbench','Log Bench 1',20,1,'item_standard',1,0,446,1,1,'{}','A simple and natural log bench',0,NULL,NULL,1.00),('log_bencha','Log Bench 1',20,1,'item_standard',1,0,447,1,1,'{}','A comfortable log bench for outdoor seating',0,NULL,NULL,1.00),('log_benchb','Log Bench 2',20,1,'item_standard',1,0,448,1,1,'{}','A spacious log bench for outdoor gatherings',0,NULL,NULL,1.00),('loonb','Loon Beak',25,1,'item_standard',1,0,449,1,1,'{}','A dagger-shaped beak from a loon.',0,NULL,NULL,0.05),('loonf','Loon Feather',50,1,'item_standard',1,0,450,1,1,'{}','A checkered black and white feather from a loon.',0,NULL,NULL,0.05),('loungechair','Lounge Chair',20,1,'item_standard',1,0,451,1,1,'{}','A comfortable and stylish lounge chair',0,NULL,NULL,1.00),('loungechair2','Lounge Chair 2',20,1,'item_standard',1,0,452,1,1,'{}','A modern and luxurious lounge chair',0,NULL,NULL,1.00),('lovepotion','Love Potion',20,1,'item_standard',1,0,7748,1,1,'{}','Sold with a wink and no guarantee.',0,NULL,NULL,1.00),('luckycoin','Lucky Coin',25,1,'item_standard',0,0,2623,1,1,'{}','nice item',0,NULL,NULL,1.00),('lumberaxe','Lumber Axe',1,1,'item_standard',1,0,453,1,1,'{}','A sturdy axe designed for cutting lumber',0,100,NULL,1.00),('lumber_pack','Lumber Pack',1,1,'item_standard',1,0,8823,1,4,'{}','A strapped timber pack. Holds 400 units of lumber materials.',0,NULL,NULL,1.00),('luxuryticket','Luxury Ticket',25,1,'item_standard',0,0,2758,1,1,'{}','nice item',0,NULL,NULL,1.00),('mackerel','Mackerel',10,1,'item_standard',0,0,454,1,1,'{}','A small and silvery fish called mackerel',0,NULL,NULL,1.00),('magazine','Magazine',20,1,'item_standard',1,0,11939,1,1,'{}','nice item',0,NULL,NULL,1.00),('mallet_wep','Mallet',1,1,'item_standard',1,0,22152,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('mango','Mango',50,1,'item_standard',1,0,1986,1,1,'{}','nice item',0,NULL,NULL,1.00),('marriagebook','Marriage Book',1,1,'item_standard',1,0,455,1,1,'{}','A book containing the guidelines and rituals for marriage',0,NULL,NULL,1.00),('marriagecertification','Marriage Certify',2,1,'item_standard',1,0,456,1,1,'{}','A legal document certifying a marriage',0,NULL,NULL,1.00),('martlemon','Lemon Martini',25,1,'item_standard',1,0,2112,1,1,'{}','nice item',0,NULL,NULL,1.00),('mashalaskan','Alaskan Gin Mash',20,1,'item_standard',1,0,457,1,1,'{}','A mixture of ingredients used in the production of Alaskan gin',0,NULL,NULL,1.00),('mashamerican','Alaskan Gin Mash',20,1,'item_standard',1,0,458,1,1,'{}','A blend of ingredients used in the production of Alaskan gin',0,NULL,NULL,1.00),('mashapple','Apple Mash',20,1,'item_standard',1,0,459,1,1,'{}','A mashed mixture of apples used for various recipes',0,NULL,NULL,1.00),('mashblackberry','Blackberry Mash',20,1,'item_standard',1,0,460,1,1,'{}','A mashed mixture of blackberries used in cooking and beverages',0,NULL,NULL,1.00),('mashblackberry90p','Blackberry Mash 90p',20,1,'item_standard',1,0,461,1,1,'{}','A concentrated blackberry mash used for crafting high-quality beverages',0,NULL,NULL,1.00),('mashpeach','Peach Mash',20,1,'item_standard',1,0,462,1,1,'{}','A mashed mixture of peaches used in culinary preparations',0,NULL,NULL,1.00),('mashplum','Plum Mash',20,1,'item_standard',1,0,463,1,1,'{}','A mashed mixture of plums used in cooking and distilling',0,NULL,NULL,1.00),('mashraspberry','Raspberry Mash',20,1,'item_standard',1,0,464,1,1,'{}','A mashed mixture of raspberries used for culinary purposes',0,NULL,NULL,1.00),('mashraspberry90p','Raspberry Mash 90p',20,1,'item_standard',1,0,465,1,1,'{}','A concentrated raspberry mash used for crafting potent beverages',0,NULL,NULL,1.00),('mashstrong','Strong Mash Batch',20,1,'item_standard',1,0,466,1,1,'{}','A powerful and highly concentrated mash batch for advanced recipes',0,NULL,NULL,1.00),('masks','Masks',50,1,'item_standard',1,0,1470,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('matcha_milk','Matcha Milk',25,1,'item_standard',1,0,17147,3,1,'{}','Green tea and milk, served cold.',0,NULL,NULL,1.00),('mdt','Mobile Data Terminal',1,1,'item_standard',0,0,31317,1,1,'{}','Portable device used by law enforcement to access the Mobile Data Terminal system',0,NULL,NULL,1.00),('meat','Meat',20,1,'item_standard',1,0,467,1,1,'{}','Fresh and uncooked meat from various animals',0,NULL,NULL,1.00),('medical_box_bag','Medical Box',25,1,'item_standard',0,0,2448,1,1,'{}','nice item',0,NULL,NULL,1.00),('metal_gear','Metal gear',10,1,'item_standard',1,0,798,1,1,'{}','A metal gear used in many machines.',0,NULL,NULL,1.00),('mete','Meteor Shard',25,1,'item_standard',0,0,2682,1,1,'{}','nice item',0,NULL,NULL,1.00),('mexitillas','Mexitillas',10,1,'item_standard',1,0,799,1,1,'{}','A can of mixed mexcian beans.',0,NULL,NULL,1.00),('mexitillastaco','Taco',10,1,'item_standard',1,0,800,1,1,'{}','A delicous taco.',0,NULL,NULL,1.00),('milk','Milk',50,1,'item_standard',1,0,468,1,1,'{}','A nutritious and creamy dairy product',0,NULL,NULL,1.00),('milkcream','Milk Cream',25,1,'item_standard',1,0,2021,1,1,'{}','nice item',0,NULL,NULL,1.00),('milkhoney','Milk & Honey',25,1,'item_standard',1,0,2063,1,1,'{}','nice item',0,NULL,NULL,1.00),('milksoup','Milkweed Chicken Soup',25,1,'item_standard',1,0,2066,1,1,'{}','nice item',0,NULL,NULL,1.00),('Milk_Weed','Milkweed',50,1,'item_standard',1,0,469,1,1,'{}','Snap the stem and white sap runs out. Used in old remedies.',0,NULL,NULL,1.00),('Milk_Weed_Seed','Milkweed Seed',50,1,'item_standard',1,0,470,1,1,'{}','Silky-tufted seed for a milkweed patch.',0,NULL,NULL,1.00),('miltent','Mulch Tent',25,1,'item_standard',0,0,2646,1,1,'{}','nice item',0,NULL,NULL,1.00),('minbp','Minted Berry Pork Fry',25,1,'item_standard',1,0,2070,1,1,'{}','nice item',0,NULL,NULL,1.00),('mincart','Mine Cart',25,1,'item_standard',0,0,2655,1,1,'{}','nice item',0,NULL,NULL,1.00),('miner_pack','Miner\'s Pack',1,1,'item_standard',1,0,8822,1,4,'{}','A heavy canvas pack for ore. Holds 400 units of mining materials.',0,NULL,NULL,1.00),('minskulpo','Small Skull Post',25,1,'item_standard',0,0,2521,1,1,'{}','nice item',0,NULL,NULL,1.00),('mintfish','Berry Mint Fish Bake',25,1,'item_standard',1,0,2064,1,1,'{}','nice item',0,NULL,NULL,1.00),('miracleelixir','Mircale Elyxir',20,1,'item_standard',1,0,7752,1,1,'{}','The label was printed in a hurry.',0,NULL,NULL,1.00),('mircacleelyxir','Miracle Elixir',20,1,'item_standard',1,0,7751,1,1,'{}','Cures what ails you. Reportedly.',0,NULL,NULL,1.00),('mirror','Mirror',25,1,'item_standard',0,0,2446,1,1,'{}','nice item',0,NULL,NULL,1.00),('moneybagfv','Average Bag of Cash',10,1,'item_standard',1,0,2408,1,1,'{}','nice item',0,NULL,NULL,1.00),('moneybagone','Small Bag of Cash',10,1,'item_standard',1,0,2407,1,1,'{}','nice item',0,NULL,NULL,1.00),('moneybagth','Big Bag of Cash',10,1,'item_standard',1,0,2409,1,1,'{}','nice item',0,NULL,NULL,1.00),('moneybag_large','Large Bag of Cash',25,1,'item_standard',0,0,2563,1,1,'{}','nice item',0,NULL,NULL,1.00),('moneybag_medium','Medium Bag of Cash',25,1,'item_standard',0,0,2684,1,1,'{}','nice item',0,NULL,NULL,1.00),('moneybag_small','Small Bag of Cash',25,1,'item_standard',0,0,2639,1,1,'{}','nice item',0,NULL,NULL,1.00),('money_coin','Coin',10,1,'item_standard',1,0,801,1,1,'{}','A simple metal coin',0,NULL,NULL,1.00),('money_coinpurse','Coin Purse',10,1,'item_standard',1,0,802,1,1,'{}','A small coin purse.',0,NULL,NULL,1.00),('monroeelixir','Dr. Monroe Elixir',20,1,'item_standard',1,0,7754,1,1,'{}','Dr. Monroe\'s finest work.',0,NULL,NULL,1.00),('monroeelixirp','Dr Monroe Elixir',20,1,'item_standard',1,0,7756,1,1,'{}','A bad batch. It shows.',0,NULL,NULL,1.00),('moonshine','Moonshine',50,1,'item_standard',1,0,471,1,1,'{}','An illegally distilled and potent alcoholic beverage',0,NULL,NULL,1.00),('moonshineapple','Apple Moonshine',50,1,'item_standard',1,0,2118,1,1,'{}','nice item',0,NULL,NULL,1.00),('moonshineraspberry','Raspberry Moonshine',50,1,'item_standard',1,0,2117,1,1,'{}','nice item',0,NULL,NULL,1.00),('mooseantler','Moose Antlers',25,1,'item_standard',1,0,472,1,1,'{}','Flat, broad antlers from a moose.',0,NULL,NULL,1.50),('mooses','Moose Hide',10,1,'item_standard',1,0,473,1,1,'{}','A coarse, very large hide from a moose.',0,NULL,NULL,3.50),('morpcert','Morphine Prescription',10,1,'item_standard',1,0,474,1,1,'{}','A medical prescription for morphine medication',0,NULL,NULL,1.00),('morphine','Morphine',10,1,'item_standard',1,0,475,1,1,'{}','A potent analgesic and narcotic medication',0,NULL,NULL,1.00),('mountainmen','Mountain Camp Set',20,1,'item_standard',1,0,476,1,1,'{}','A set of equipment and supplies for a mountain camp',0,NULL,NULL,1.00),('mountratent','Mounted Trader Tent',25,1,'item_standard',0,0,2643,1,1,'{}','nice item',0,NULL,NULL,1.00),('mp001_p_mp_still02x','Brennerei',1,1,'item_standard',1,0,477,1,1,'{}','A large still used for distilling alcoholic beverages',0,NULL,NULL,1.00),('mpleetent','Croft Tent',25,1,'item_standard',0,0,2454,1,1,'{}','nice item',0,NULL,NULL,1.00),('muffinblue','Blueberry Muffin',25,1,'item_standard',1,0,2113,1,1,'{}','nice item',0,NULL,NULL,1.00),('mushgravy','mushroom gravy',25,1,'item_standard',0,0,2766,1,1,'{}','nice item',0,NULL,NULL,1.00),('muskratpie','Muskrat Pie',25,1,'item_standard',1,0,2012,1,1,'{}','nice item',0,NULL,NULL,1.00),('muskrats','Muskrat Pelt',10,1,'item_standard',1,0,478,1,1,'{}','A small brown pelt from a muskrat.',0,NULL,NULL,0.40),('mutton','Mutton',20,1,'item_standard',1,0,479,1,1,'{}','Meat from mature sheep used in cooking',0,NULL,NULL,1.00),('muttoncooked','Cooked Mutton',25,1,'item_standard',1,0,2013,1,1,'{}','nice item',0,NULL,NULL,1.00),('muttonveg','Mutton with Veggies',25,1,'item_standard',0,0,2745,1,1,'{}','nice item',0,NULL,NULL,1.00),('nachan','Native Chandelier',25,1,'item_standard',0,0,2519,1,1,'{}','nice item',0,NULL,NULL,1.00),('nails','Nails',50,1,'item_standard',1,0,480,1,1,'{}','Small metal fasteners used for joining materials',0,NULL,NULL,1.00),('natab','Naturalist Table',25,1,'item_standard',0,0,2673,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativearms','Native Arms',20,1,'item_standard',1,0,1379,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativearrowdisplay','Arrow Display',20,1,'item_standard',1,0,1397,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativebasket1','Native Basket 1',20,1,'item_standard',1,0,481,1,1,'{}','A traditional native basket for carrying items',0,NULL,NULL,1.00),('nativebasket2','Native Basket 2',20,1,'item_standard',1,0,482,1,1,'{}','A second variation of a traditional native basket',0,NULL,NULL,1.00),('nativebed','Native Bed',20,1,'item_standard',1,0,1377,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativebench','Native Bench',20,1,'item_standard',1,0,1386,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativebloodrock','Native Rock Structure',20,1,'item_standard',1,0,1393,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativebowdisplay','Bow Display',20,1,'item_standard',1,0,1395,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativebuckskull','Native Buck Skull',20,1,'item_standard',1,0,1398,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativecage','Native Wooden Cage',20,1,'item_standard',1,0,1394,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativechair','Native Chair',20,1,'item_standard',1,0,1384,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativecookpot','Native Cooking Pot',20,1,'item_standard',1,0,1396,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativedecor','Native Decor Set',20,1,'item_standard',1,0,483,1,1,'{}','A set of decorative native items for display',0,NULL,NULL,1.00),('nativeelkcanvas','Native Elk Canvas',20,1,'item_standard',1,0,1388,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativeleatherstand','Native Leather Stand',20,1,'item_standard',1,0,1399,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativemask','Native Mask',20,1,'item_standard',1,0,1378,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativeplatform','Native Platform',20,1,'item_standard',1,0,1391,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativepot','Native Pot',20,1,'item_standard',1,0,484,1,1,'{}','A traditional native pot for cooking and storage',0,NULL,NULL,1.00),('nativeskull','Native Decor 1',20,1,'item_standard',1,0,485,1,1,'{}','A decorative native skull for ornamental purposes',0,NULL,NULL,1.00),('nativeskullchair','Dead Mans Chair',20,1,'item_standard',1,0,1383,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativesmoker','Native Cooking Structure',20,1,'item_standard',1,0,1392,1,1,'{}','nice item',0,NULL,NULL,1.00),('nativewickchair','Native Wicker Chair',20,1,'item_standard',1,0,1385,1,1,'{}','nice item',0,NULL,NULL,1.00),('naturalwagon','Naturalists Wagon Set',20,1,'item_standard',1,0,486,1,1,'{}','A wagon set equipped for naturalists and explorers',0,NULL,NULL,1.00),('navbed','Native Log Bed',25,1,'item_standard',0,0,2668,1,1,'{}','nice item',0,NULL,NULL,1.00),('navches','Native Chest',25,1,'item_standard',0,0,2469,1,1,'{}','nice item',0,NULL,NULL,1.00),('necklace_amethyst_braxton','Amethyst Necklace (Braxton)',20,1,'item_standard',0,0,4849,1,1,'{}','A rare amethyst necklace.',0,NULL,NULL,1.00),('necklace_amethyst_richelieu','Amethyst Necklace (Richelieu)',20,1,'item_standard',0,0,4850,1,1,'{}','A highly valuable amethyst necklace.',0,NULL,NULL,1.00),('necklace_ancient','Ancient Necklace',20,1,'item_standard',0,0,4847,1,1,'{}','An ancient necklace of unknown origin.',0,NULL,NULL,1.00),('necklace_gold_cross','Gold Cross Necklace',20,1,'item_standard',0,0,4846,1,1,'{}','A gold cross on a chain.',0,NULL,NULL,1.00),('necklace_gold_ring','Gold Ring Necklace',20,1,'item_standard',0,0,4845,1,1,'{}','A gold chain with a ring.',0,NULL,NULL,1.00),('necklace_mini_blakely','Blakely Miniature Necklace',20,1,'item_standard',0,0,4848,1,1,'{}','A delicate miniature necklace.',0,NULL,NULL,1.00),('necklace_pearl_pelle','Pearl Pendant',20,1,'item_standard',0,0,4844,1,1,'{}','A pearl pendant necklace.',0,NULL,NULL,1.00),('necklace_pearl_rou','Pearl Necklace',20,1,'item_standard',0,0,4843,1,1,'{}','A beautiful pearl necklace.',0,NULL,NULL,1.00),('neckties','NeckTies',50,1,'item_standard',1,0,1467,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('neckwear','NeckWear',50,1,'item_standard',1,0,1468,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('newspaper','Rolled Newspaper',1,1,'item_standard',1,0,487,1,5,'{}','A printed publication containing news and articles',0,NULL,NULL,1.00),('newspaper1','Newspaper',20,1,'item_standard',1,0,11938,1,1,'{}','nice item',0,NULL,NULL,1.00),('nides','Nightfall Desk',25,1,'item_standard',0,0,2567,1,1,'{}','nice item',0,NULL,NULL,1.00),('nightstand','Nightstand',20,1,'item_standard',1,0,488,1,1,'{}','A small bedside table for holding personal items',0,NULL,NULL,1.00),('nigmas','Night Stalker Mask',25,1,'item_standard',0,0,2490,1,1,'{}','nice item',0,NULL,NULL,1.00),('nitrite','Nitrite',50,1,'item_standard',1,0,489,1,1,'{}','A chemical compound used in various industrial processes',0,NULL,NULL,1.00),('nitroglyserolia','Nitroglycerol',30,1,'item_standard',1,0,490,1,1,'{}','A highly explosive liquid compound used in explosives',0,NULL,NULL,1.00),('nittab','Nit Cover Table',25,1,'item_standard',0,0,2614,1,1,'{}','nice item',0,NULL,NULL,1.00),('nocof','Cut Coffin',25,1,'item_standard',0,0,2555,1,1,'{}','nice item',0,NULL,NULL,1.00),('normaltable','Table',20,1,'item_standard',1,0,491,1,1,'{}','A standard table for dining or work purposes',0,NULL,NULL,1.00),('nortent','Northman Tent',25,1,'item_standard',0,0,2478,1,1,'{}','nice item',0,NULL,NULL,1.00),('notebook','Notebook',1,1,'item_standard',1,0,492,1,1,'{}','A small book with blank pages for writing or drawing',0,NULL,NULL,1.00),('obed','Old bed',20,1,'item_standard',1,0,493,1,1,'{}','An old bed that has seen better days.',0,NULL,NULL,1.00),('obsidian','Rubber',25,1,'item_standard',0,0,2499,1,1,'{}','nice item',0,NULL,NULL,1.00),('octavioelixir','The Octavio Elixir',20,1,'item_standard',1,0,7753,1,1,'{}','A showman\'s tonic with real bite.',0,NULL,NULL,1.00),('Oleander_Sage','Oleander Sage',50,1,'item_standard',1,0,494,1,1,'{}','A bitter sage that herbalists keep on hand. Handle it with care.',0,NULL,NULL,1.00),('Oleander_Sage_Seed','Oleander Sage Seed',50,1,'item_standard',1,0,495,1,1,'{}','Seed for a row of oleander sage.',0,NULL,NULL,1.00),('opeouthou','Opeouthou',25,1,'item_standard',0,0,2768,1,1,'{}','nice item',0,NULL,NULL,1.00),('opium','Opium',25,1,'item_standard',1,0,2753,1,1,'{}','nice item',0,NULL,NULL,1.00),('opocof','Open Coffin',25,1,'item_standard',0,0,2524,1,1,'{}','nice item',0,NULL,NULL,1.00),('opossumc','Opossum Claw',25,1,'item_standard',1,0,496,1,1,'{}','A tiny hooked claw from an opossum.',0,NULL,NULL,0.05),('opossums','Opossum Pelt',10,1,'item_standard',1,0,497,1,1,'{}','A thin grey pelt from an opossum.',0,NULL,NULL,0.40),('orange','Orange',50,1,'item_standard',1,0,1988,1,1,'{}','nice item',0,NULL,NULL,1.00),('orangejuice','Orange Juice',25,1,'item_standard',1,0,2114,1,1,'{}','nice item',0,NULL,NULL,1.00),('orblos','Orange blossom soda',25,1,'item_standard',1,0,2055,1,1,'{}','nice item',0,NULL,NULL,1.00),('orden_presidente','Order of the President',10,1,'item_standard',0,0,498,1,1,'{}','A prestigious order awarded by the President.',0,NULL,NULL,1.00),('Oregano','Oregano',50,1,'item_standard',1,0,499,1,1,'{}','A strong kitchen herb. Rub a leaf and your fingers smell of it all day.',0,NULL,NULL,1.00),('Oregano_Seed','Oregano Seed',50,1,'item_standard',1,0,500,1,1,'{}','Seed for a bushy oregano plant.',0,NULL,NULL,1.00),('oriole2_c','Hooded Oriole',20,1,'item_standard',1,0,501,1,1,'{}','Brightly colored feathers from a Hooded Oriole.',0,NULL,NULL,1.00),('oriole_c','Oriole',20,1,'item_standard',1,0,502,1,1,'{}','A whole oriole in orange and black.',0,NULL,NULL,0.10),('ouhou','Ouhou',25,1,'item_standard',0,0,2579,1,1,'{}','nice item',0,NULL,NULL,1.00),('outdes','Outrider Desk',25,1,'item_standard',0,0,2540,1,1,'{}','nice item',0,NULL,NULL,1.00),('owlf','Owl Feather',50,1,'item_standard',1,0,503,1,1,'{}','A soft, silent feather from an owl.',0,NULL,NULL,0.05),('owlt','Owl Talon',25,1,'item_standard',1,0,504,1,1,'{}','A talon from an owl.',0,NULL,NULL,0.05),('oxhorn','Ox Horn',25,1,'item_standard',1,0,505,1,1,'{}','A long, pale horn from an ox.',0,NULL,NULL,0.40),('oxs','Ox Hide',10,1,'item_standard',1,0,506,1,1,'{}','A heavy hide from a draught ox.',0,NULL,NULL,3.00),('paincouc','Painted Couch',25,1,'item_standard',0,0,2458,1,1,'{}','nice item',0,NULL,NULL,1.00),('painfurni','Fancy Painting',20,1,'item_standard',1,0,4294,1,1,'{}','nice item',0,NULL,NULL,1.00),('painsitab','Painted Side Table',25,1,'item_standard',0,0,2498,1,1,'{}','nice item',0,NULL,NULL,1.00),('pan01','Pan',1,1,'item_standard',1,0,1517,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('pan02','Big Pan',1,1,'item_standard',1,0,1518,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('pancakeschoco','Pancakes & Chocolate',25,1,'item_standard',1,0,2164,1,1,'{}','nice item',0,NULL,NULL,1.00),('pancakesfruit','Pancakes & Fruit',25,1,'item_standard',1,0,2163,1,1,'{}','nice item',0,NULL,NULL,1.00),('panthere','Panther Eye',25,1,'item_standard',1,0,507,1,1,'{}','A preserved panther eye. Some swear it brings luck.',0,NULL,NULL,0.05),('panthers','Panther Pelt',10,1,'item_standard',1,0,508,1,1,'{}','A sleek dark pelt from a swamp panther.',0,NULL,NULL,2.00),('pants','Pants',50,1,'item_standard',1,0,1440,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('paper','Paper',50,1,'item_standard',0,0,509,4,1,'{}','Sheets of paper for writing or drawing.',0,NULL,NULL,1.00),('parasol','Parasol',1,1,'item_standard',1,0,510,1,1,'{}','A stylish and functional parasol to shield from the sun.',0,NULL,NULL,1.00),('parasolcook','Parasol Schnitzel',25,1,'item_standard',1,0,2150,1,1,'{}','nice item',0,NULL,NULL,1.00),('Parasol_Mushroom','Parasol Mushroom',50,1,'item_standard',1,0,511,1,1,'{}','A tall mushroom with a broad, scaly cap. Fine fried in butter.',0,NULL,NULL,1.00),('Parasol_Mushroom_Seed','Parasol Mushroom Seed',50,1,'item_standard',1,0,512,1,1,'{}','A twist of spores for growing parasol mushrooms.',0,NULL,NULL,1.00),('peachseeds','Peach Seeds',50,1,'item_standard',1,0,513,1,1,'{}','Peach stones for planting. A tree and its fruit take a while.',0,NULL,NULL,1.00),('pear','Pear',50,1,'item_standard',1,0,1985,1,1,'{}','nice item',0,NULL,NULL,1.00),('pearl','Pearl',10,1,'item_standard',1,0,803,1,1,'{}','A hard, glistening object produced within the soft tissue of a living shelled mollusk.',0,NULL,NULL,1.00),('peasantb','Pheasant Beak',25,1,'item_standard',1,0,514,1,1,'{}','A small pale beak from a pheasant.',0,NULL,NULL,0.05),('peasantf','Pheasant Feather',50,1,'item_standard',1,0,515,1,1,'{}','A long copper tail feather from a pheasant.',0,NULL,NULL,0.02),('pecaris','Javelina Hide',10,1,'item_standard',1,0,516,1,1,'{}','A bristly hide from a desert javelina.',0,NULL,NULL,1.20),('peda','Pedestal',25,1,'item_standard',0,0,2600,1,1,'{}','nice item',0,NULL,NULL,1.00),('pegg','Pickled Eggs',25,1,'item_standard',1,0,2062,1,1,'{}','nice item',0,NULL,NULL,1.00),('pelicanb','Pelican Beak',25,1,'item_standard',1,0,517,1,1,'{}','A long beak from a pelican, pouch dried flat.',0,NULL,NULL,0.10),('pelicanf','Pelican Feather',50,1,'item_standard',1,0,518,1,1,'{}','A broad feather from a pelican.',0,NULL,NULL,0.05),('peltab','Pelt Table',25,1,'item_standard',0,0,2451,1,1,'{}','nice item',0,NULL,NULL,1.00),('pen','Pen',2,1,'item_standard',0,0,519,1,1,'{}','A writing instrument used to apply ink.',0,NULL,NULL,1.00),('pentagram','Pentagram',20,1,'item_standard',1,0,4491,1,1,'{}','nice item',0,NULL,NULL,1.00),('pepsti','Peppermint Sticks',25,1,'item_standard',1,0,2247,1,1,'{}','nice item',0,NULL,NULL,1.00),('pet_armadillo','Armadillo',1,1,'item_standard',1,0,3814,1,5,'{}','Armoured, unhurried, and entirely unbothered by your opinion.',0,NULL,NULL,1.00),('pet_badger','Badger',1,1,'item_standard',1,0,3811,1,5,'{}','Digs first and reconsiders later. Afraid of nothing its own size or larger.',0,NULL,NULL,1.00),('pet_beaver','Beaver',1,1,'item_standard',1,0,3812,1,5,'{}','Will try to dam any water you camp beside. Cannot be reasoned with.',0,NULL,NULL,1.00),('pet_bluejay','Blue Jay',1,1,'item_standard',1,0,3823,1,5,'{}','Loud, bright and spoiling for a fight with birds twice its size.',0,NULL,NULL,1.00),('pet_boar','Boar',1,1,'item_standard',1,0,3839,1,5,'{}','Bad tempered, thick skinned, and a poor choice to startle.',0,NULL,NULL,1.00),('pet_buck','Buck',1,1,'item_standard',1,0,3841,1,5,'{}','Carries its antlers like a warning. Most things take it as one.',0,NULL,NULL,1.00),('pet_cardinal','Cardinal',1,1,'item_standard',1,0,3824,1,5,'{}','A red flame in a bare tree. Easier to hear than to spot.',0,NULL,NULL,1.00),('pet_cat','Cat',1,1,'item_standard',1,0,3804,1,5,'{}','Follows when it suits. Sits exactly where you were about to.',0,NULL,NULL,1.00),('pet_chicken','Chicken',1,1,'item_standard',1,0,3829,1,5,'{}','Follows you for grain and nothing else. Honest about it.',0,NULL,NULL,1.00),('pet_chipmunk','Chipmunk',1,1,'item_standard',1,0,3807,1,5,'{}','Cheeks full, always. Will empty your satchel given an hour.',0,NULL,NULL,1.00),('pet_collie','Collie',1,1,'item_standard',1,0,3795,1,5,'{}','Watchful, tidy and quicker than it looks. Herds by suggestion rather than force.',0,NULL,NULL,1.00),('pet_coonhound','Bluetick Coonhound',1,1,'item_standard',1,0,3792,1,5,'{}','Nose down from dawn to dusk. Follows a scent long after you have lost interest.',0,NULL,NULL,1.00),('pet_cow','Cow',1,1,'item_standard',1,0,3836,1,5,'{}','Slow, warm and entirely uninterested in your plans.',0,NULL,NULL,1.00),('pet_crow','Crow',1,1,'item_standard',1,0,3822,1,5,'{}','Remembers faces, holds grudges, and tells the other crows.',0,NULL,NULL,1.00),('pet_cur','Catahoula Cur',1,1,'item_standard',1,0,3793,1,5,'{}','Half working dog, half swamp ghost. Takes to water and to trouble alike.',0,NULL,NULL,1.00),('pet_deer','Deer',1,1,'item_standard',1,0,3840,1,5,'{}','Skittish in open country, calm once it knows your step.',0,NULL,NULL,1.00),('pet_donkey','Donkey',1,1,'item_standard',1,0,3837,1,5,'{}','Stubborn past persuasion, and right about the footing more often than you.',0,NULL,NULL,1.00),('pet_fox','Fox',1,1,'item_standard',1,0,3838,1,5,'{}','Trots at your heel as though it were its own idea. It was.',0,NULL,NULL,1.00),('pet_foxhound','American Foxhound',1,1,'item_standard',1,0,3790,1,5,'{}','Bred to run all day and bay at what it finds. Rarely quiet, never lost.',0,NULL,NULL,1.00),('pet_frog','Bullfrog',1,1,'item_standard',1,0,3817,1,5,'{}','Bellows at dusk loud enough to carry a mile. Good company by a creek.',0,NULL,NULL,1.00),('pet_gila','Gila Monster',1,1,'item_standard',1,0,22268,1,5,'{}','Beaded, patient and venomous. Bites once and does not let go.',0,NULL,NULL,1.00),('pet_goat','Goat',1,1,'item_standard',1,0,3834,1,5,'{}','Eats your rope, your hat and your patience. Climbs what it should not.',0,NULL,NULL,1.00),('pet_goose','Goose',1,1,'item_standard',1,0,3832,1,5,'{}','Guards better than most dogs and holds a grudge far longer.',0,NULL,NULL,1.00),('pet_hobo','Hobo Dog',1,1,'item_standard',1,0,3796,1,5,'{}','Rode in on a freight car and never got off. Owes nobody a thing.',0,NULL,NULL,1.00),('pet_hound','Hound',1,1,'item_standard',1,0,3797,1,5,'{}','Sleeps by the fire, wakes for a scent. The rest is negotiable.',0,NULL,NULL,1.00),('pet_hound_10','Hound (Variant 10)',1,1,'item_standard',1,0,22267,1,5,'{}','The same old hound in a coat of its own. Rename it once you have met it.',0,NULL,NULL,1.00),('pet_husky','Husky',1,1,'item_standard',1,0,3798,1,5,'{}','Built for weather that kills. Complains loudly about anything warmer.',0,NULL,NULL,1.00),('pet_iguana','Iguana',1,1,'item_standard',1,0,22270,1,5,'{}','Watches everything, moves for nothing, and judges quietly.',0,NULL,NULL,1.00),('pet_iguana_d','Desert Iguana',1,1,'item_standard',1,0,22269,1,5,'{}','Lives on hot stone and asks for nothing but the sun.',0,NULL,NULL,1.00),('pet_lab','Labrador',1,1,'item_standard',1,0,3799,1,5,'{}','Cheerful past all reason. Will swim in anything wet enough to hold it.',0,NULL,NULL,1.00),('pet_leg_beaver','Legendary Beaver',1,1,'item_standard',1,0,3884,1,5,'{}','Older and a good deal larger than any beaver has business being.',0,NULL,NULL,1.00),('pet_leg_bighornram','Legendary Bighorn Ram',1,1,'item_standard',1,0,3883,1,5,'{}','Came down off the high rocks one winter and never went back up.',0,NULL,NULL,1.00),('pet_leg_bison','Legendary Bison',1,1,'item_standard',1,0,3881,1,5,'{}','The last of a herd that once darkened the plains. Walks alone now.',0,NULL,NULL,1.00),('pet_leg_blackbeaver','Legendary Black Beaver',1,1,'item_standard',1,0,3848,1,5,'{}','Dark-pelted and near invisible at dusk. Works the water while you sleep.',0,NULL,NULL,1.00),('pet_leg_blackcougar','Legendary Black Cougar',1,1,'item_standard',1,0,3854,1,5,'{}','Black as a closed room. Only the eyes give it away.',0,NULL,NULL,1.00),('pet_leg_boa','Legendary Boa',1,1,'item_standard',1,0,3879,1,5,'{}','Ten feet of patient muscle. Goes where it likes and takes its time getting there.',0,NULL,NULL,1.00),('pet_leg_buck','Legendary Buck',1,1,'item_standard',1,0,3885,1,5,'{}','Antlers counted in double figures. Has outlived every hunter who tried for them.',0,NULL,NULL,1.00),('pet_leg_bullgator','Legendary Bullgator',1,1,'item_standard',1,0,3846,1,5,'{}','Twelve feet of bad temper hauled out of the bayou. Nothing hunts it twice.',0,NULL,NULL,1.00),('pet_leg_chalkhornram','Legendary Chalk Horn Ram',1,1,'item_standard',1,0,3866,1,5,'{}','Horns white as chalk and hard as an anvil. Comes down mountains sideways.',0,NULL,NULL,1.00),('pet_leg_cogiboar','Legendary Cogi Boar',1,1,'item_standard',1,0,3849,1,5,'{}','Scarred from a hundred fights it started. Still looking for the next one.',0,NULL,NULL,1.00),('pet_leg_coyote','Legendary Coyote',1,1,'item_standard',1,0,3886,1,5,'{}','Sang outside camps for a decade before it finally followed one home.',0,NULL,NULL,1.00),('pet_leg_crossfox','Legendary Cross Fox',1,1,'item_standard',1,0,3875,1,5,'{}','Dark cross over the shoulders, silver at the brush. Rare even in the stories.',0,NULL,NULL,1.00),('pet_leg_deadlybear','Legendary Deadly Bear',1,1,'item_standard',1,0,3863,1,5,'{}','Killed more men than the winter did. Walks at your shoulder now.',0,NULL,NULL,1.00),('pet_leg_elk','Legendary Elk',1,1,'item_standard',1,0,3891,1,5,'{}','Crowned with antlers that catch the light. Steps like it owns the ridge.',0,NULL,NULL,1.00),('pet_leg_emeraldwolf','Legendary Emerald Wolf',1,1,'item_standard',1,0,3860,1,5,'{}','Green fire in its eyes and a pelt no trapper could put a name to.',0,NULL,NULL,1.00),('pet_leg_fox','Legendary Fox',1,1,'item_standard',1,0,3882,1,5,'{}','Silver-tipped and quicker than the eye. Every trapper has a story, none has the pelt.',0,NULL,NULL,1.00),('pet_leg_ghostpanther','Legendary Ghost Panther',1,1,'item_standard',1,0,3859,1,5,'{}','Pale enough to look through. Bounty hunters stopped filing reports on it.',0,NULL,NULL,1.00),('pet_leg_greatboar','Legendary Great Boar',1,1,'item_standard',1,0,3878,1,5,'{}','The boar the old hunters warned about. Still carries their arrowheads.',0,NULL,NULL,1.00),('pet_leg_greathornram','Legendary GreatHorn Ram',1,1,'item_standard',1,0,3868,1,5,'{}','The horns curl full circle. It has never needed to use them twice.',0,NULL,NULL,1.00),('pet_leg_greybeaver','Legendary Grey Beaver',1,1,'item_standard',1,0,3847,1,5,'{}','Grey as river stone and just as patient. Fells trees a man would need an axe for.',0,NULL,NULL,1.00),('pet_leg_igugacougar','Legendary Iguga Cougar',1,1,'item_standard',1,0,3852,1,5,'{}','Moves like smoke through the rocks. You hear it only after it has passed.',0,NULL,NULL,1.00),('pet_leg_katataelk','Legendary Katata Elk',1,1,'item_standard',1,0,3873,1,5,'{}','Antlers wide as a wagon. Bugles loud enough to turn a whole valley.',0,NULL,NULL,1.00),('pet_leg_knightmoose','Legendary Knight Moose',1,1,'item_standard',1,0,3876,1,5,'{}','Armoured in scar tissue and antler. Has walked away from every hunt.',0,NULL,NULL,1.00),('pet_leg_midnightpawcoyote','Legendary Midnight Paw Coyote',1,1,'item_standard',1,0,3856,1,5,'{}','Pale coat, black feet. Leaves tracks that stop making sense.',0,NULL,NULL,1.00),('pet_leg_milkcoyote','Legendary Milk Coyote',1,1,'item_standard',1,0,3857,1,5,'{}','White as spilled milk and twice as hard to catch.',0,NULL,NULL,1.00),('pet_leg_moonstonewolf','Legendary Moonstone Wolf',1,1,'item_standard',1,0,22271,1,5,'{}','Silver-pale and cold to look at. Runs ahead of the storms.',0,NULL,NULL,1.00),('pet_leg_moose','Legendary Moose',1,1,'item_standard',1,0,3889,1,5,'{}','Stands taller than a man on horseback and yields to nothing at all.',0,NULL,NULL,1.00),('pet_leg_mudrunnerbuck','Legendary Mudrunner Buck',1,1,'item_standard',1,0,3869,1,5,'{}','Comes out of the marsh caked to the shoulder. Faster than the ground allows.',0,NULL,NULL,1.00),('pet_leg_nightwalkerpanther','Legendary Nightwalker Panther',1,1,'item_standard',1,0,3858,1,5,'{}','Hunts the hours nobody else is awake for. Never seen twice in one place.',0,NULL,NULL,1.00),('pet_leg_onyxwolf','Legendary Onyx Wolf',1,1,'item_standard',1,0,3861,1,5,'{}','Black as struck coal. Led a pack that was never found.',0,NULL,NULL,1.00),('pet_leg_otafox','Legendary Ota Fox',1,1,'item_standard',1,0,3874,1,5,'{}','A coat of impossible colour. Trappers argued for years over whether it was real.',0,NULL,NULL,1.00),('pet_leg_owizabear','Legendary Owiza Bear',1,1,'item_standard',1,0,3864,1,5,'{}','Named in a language older than the territory. Answers to nothing.',0,NULL,NULL,1.00),('pet_leg_payatabison','Legendary Payata Bison',1,1,'item_standard',1,0,3872,1,5,'{}','Pale-shouldered and enormous. The plains part around it.',0,NULL,NULL,1.00),('pet_leg_pronghorn','Legendary Pronghorn',1,1,'item_standard',1,0,3887,1,5,'{}','Outran horses, dogs and men alike. Then chose to stop.',0,NULL,NULL,1.00),('pet_leg_rattlesnake','Legendary Rattlesnake',1,1,'item_standard',1,0,3880,1,5,'{}','Rattles once, as a courtesy. There is not usually a second warning.',0,NULL,NULL,1.00),('pet_leg_redstreakcoyote','Legendary Red Streak Coyote',1,1,'item_standard',1,0,3855,1,5,'{}','A rust-red streak across the badlands. Laughs at the moon and at you.',0,NULL,NULL,1.00),('pet_leg_ridgebackspiritbear','Legendary Ridgeback Spirit Bear',1,1,'item_standard',1,0,3865,1,5,'{}','White-ridged and spoken of in whispers. Some say it is not entirely here.',0,NULL,NULL,1.00),('pet_leg_ruddymoose','Legendary Ruddy Moose',1,1,'item_standard',1,0,3877,1,5,'{}','Deep red at the flank. Stands chest-deep in water and dares you to come in.',0,NULL,NULL,1.00),('pet_leg_rutilehornram','Legendary Rutile Horn Ram',1,1,'item_standard',1,0,3867,1,5,'{}','Horns shot through with red gold. Worth a fortune on any wall but yours.',0,NULL,NULL,1.00),('pet_leg_sapacougar','Legendary Sapa Cougar',1,1,'item_standard',1,0,3853,1,5,'{}','Dark-masked and silent. The kind of thing that watches camps from the ridge.',0,NULL,NULL,1.00),('pet_leg_shadowbuck','Legendary Shadow Buck',1,1,'item_standard',1,0,3870,1,5,'{}','Dark-coated and gone the moment you look straight at it.',0,NULL,NULL,1.00),('pet_leg_sunalligator','Legendary Sun Alligator',1,1,'item_standard',1,0,3845,1,5,'{}','Pale as bleached bone from the sun-scorched shallows. Older than the swamp roads.',0,NULL,NULL,1.00),('pet_leg_tatankabison','Legendary Tatanka Bison',1,1,'item_standard',1,0,3871,1,5,'{}','Sacred to those who named it. Two thousand pounds of walking history.',0,NULL,NULL,1.00),('pet_leg_tatankabison2','Legendary Tatanka Bison',1,1,'item_standard',1,0,3890,1,5,'{}','Another of the sacred herd. Just as old, and just as unmoved by you.',0,NULL,NULL,1.00),('pet_leg_wakpaboar','Legendary Wakpa Boar',1,1,'item_standard',1,0,3850,1,5,'{}','Named by the river people for the water it never strays far from.',0,NULL,NULL,1.00),('pet_leg_wildhog','Legendary Wildhog',1,1,'item_standard',1,0,3851,1,5,'{}','Hunted for years and never taken. Now it walks behind you instead.',0,NULL,NULL,1.00),('pet_leg_wolf','Legendary Wolf',1,1,'item_standard',1,0,3888,1,5,'{}','The one the ranchers blamed for everything. Most of it was true.',0,NULL,NULL,1.00),('pet_lion','Mangy Lion',1,1,'item_standard',1,0,19516,1,5,'{}','Came off a travelling circus wagon and never found its way back. Moth-eaten, half-starved, and still the largest thing for miles.',0,NULL,NULL,1.00),('pet_liondog','Lion Dog',1,1,'item_standard',1,0,3800,1,5,'{}','Clipped like a lion by somebody with time and shears. Carries it well.',0,NULL,NULL,1.00),('pet_muskrat','Muskrat',1,1,'item_standard',1,0,3813,1,5,'{}','Smells of the river and much prefers it that way.',0,NULL,NULL,1.00),('pet_owl','Owl',1,1,'item_standard',1,0,3820,1,5,'{}','Silent in flight and awake when you are not. Watches the treeline.',0,NULL,NULL,1.00),('pet_parrot','Parrot',1,1,'item_standard',1,0,3819,1,5,'{}','Repeats the worst thing it has heard you say, usually in company.',0,NULL,NULL,1.00),('pet_pig','Pig',1,1,'item_standard',1,0,3833,1,5,'{}','Smarter than the dog and aware of it. Will eat anything you drop.',0,NULL,NULL,1.00),('pet_pigeon','Pigeon',1,1,'item_standard',1,0,3828,1,5,'{}','Finds its way home from anywhere. Home, apparently, is you.',0,NULL,NULL,1.00),('pet_poodle','Poodle',1,1,'item_standard',1,0,3801,1,5,'{}','Curled and groomed and far tougher than the haircut suggests.',0,NULL,NULL,1.00),('pet_possum','Possum',1,1,'item_standard',1,0,3809,1,5,'{}','Plays dead convincingly. Occasionally is.',0,NULL,NULL,1.00),('pet_pronghorn','Pronghorn',1,1,'item_standard',1,0,3842,1,5,'{}','Faster than anything else out here, and quietly aware of it.',0,NULL,NULL,1.00),('pet_rabbit','Rabbit',1,1,'item_standard',1,0,3805,1,5,'{}','Nervous, quick, and gone at the first loud noise. Comes back for food.',0,NULL,NULL,1.00),('pet_raccoon','Raccoon',1,1,'item_standard',1,0,3808,1,5,'{}','Clever hands and no morals whatever. Check your pockets afterwards.',0,NULL,NULL,1.00),('pet_ram','Bighorn Ram',1,1,'item_standard',1,0,3843,1,5,'{}','Settles arguments with its skull. Has never lost one.',0,NULL,NULL,1.00),('pet_rat','Rat',1,1,'item_standard',1,0,3815,1,5,'{}','Nobody wants one. Outlives everything that does.',0,NULL,NULL,1.00),('pet_raven','Raven',1,1,'item_standard',1,0,3821,1,5,'{}','Watches you the way a creditor does. Collects anything that shines.',0,NULL,NULL,1.00),('pet_retriever','Bay Retriever',1,1,'item_standard',1,0,3794,1,5,'{}','Comes back with whatever you sent it after, wet through and pleased about it.',0,NULL,NULL,1.00),('pet_robin','Robin',1,1,'item_standard',1,0,3825,1,5,'{}','Turns up when the frost breaks. Pulls worms with grim determination.',0,NULL,NULL,1.00),('pet_rooster','Rooster',1,1,'item_standard',1,0,3830,1,5,'{}','Announces dawn an hour early and will not be corrected.',0,NULL,NULL,1.00),('pet_rufus','Rufus',1,1,'item_standard',1,0,3802,1,5,'{}','Answers to Rufus. Has never explained where he came from.',0,NULL,NULL,1.00),('pet_sheep','Sheep',1,1,'item_standard',1,0,3835,1,5,'{}','Follows without asking where. Wool worth more than the trouble.',0,NULL,NULL,1.00),('pet_sheep_bow','Pink Bow Sheep',1,1,'item_standard',1,0,9886,1,5,'{}','A merino ewe in a pink ribbon. Somebody loved her. Best not ask who.',0,NULL,NULL,1.00),('pet_shepherd','Australian Shepherd',1,1,'item_standard',1,0,3791,1,5,'{}','Herds anything that moves, including you. Keeps one eye on the horizon.',0,NULL,NULL,1.00),('pet_shepherd_black','Black Australian Shepherd',1,1,'item_standard',1,0,8289,1,5,'{}','Dark as a moonless field, and just as hard to keep track of after dusk. (coat 2)',0,NULL,NULL,1.00),('pet_shepherd_merle','Merle Australian Shepherd',1,1,'item_standard',1,0,8287,1,5,'{}','A marbled grey coat no two of which fall the same way. Herds anything that moves, including you. (coat 0)',0,NULL,NULL,1.00),('pet_shepherd_red','Red Australian Shepherd',1,1,'item_standard',1,0,8288,1,5,'{}','Copper through and through, and twice as stubborn. Keeps one eye on the horizon. (coat 1)',0,NULL,NULL,1.00),('pet_skunk','Skunk',1,1,'item_standard',1,0,3810,1,5,'{}','Loyal, affectionate, and a standing threat to everyone downwind.',0,NULL,NULL,1.00),('pet_snake','Snake',1,1,'item_standard',1,0,3844,1,5,'{}','Coils in the shade and asks only that you watch where you step.',0,NULL,NULL,1.00),('pet_songbird','Songbird',1,1,'item_standard',1,0,3827,1,5,'{}','Sings the morning in whether you wanted it or not.',0,NULL,NULL,1.00),('pet_sparrow','Sparrow',1,1,'item_standard',1,0,3826,1,5,'{}','Small, plain and everywhere. Outlives grander birds by going unnoticed.',0,NULL,NULL,1.00),('pet_squirrel','Squirrel',1,1,'item_standard',1,0,3806,1,5,'{}','Buries things it will never find again. Rides on the saddle horn.',0,NULL,NULL,1.00),('pet_street','Street Dog',1,1,'item_standard',1,0,3803,1,5,'{}','Learned the alleys before it learned its name. Trusts you slowly.',0,NULL,NULL,1.00),('pet_toad','Toad',1,1,'item_standard',1,0,3816,1,5,'{}','Sits. Blinks. Occasionally moves. Asks nothing of anyone.',0,NULL,NULL,1.00),('pet_turkey','Turkey',1,1,'item_standard',1,0,3831,1,5,'{}','Larger and more argumentative than it has any right to be.',0,NULL,NULL,1.00),('pet_turtle','Turtle',1,1,'item_standard',1,0,3818,1,5,'{}','Slow enough to lose in open country. Worth the wait.',0,NULL,NULL,1.00),('peyote','Peyote',25,1,'item_standard',1,0,1994,1,1,'{}','nice item',0,NULL,NULL,1.00),('pheasant_taxidermy','Pheasant Taxidermy',20,1,'item_standard',1,0,520,1,1,'{}','A preserved mount of a pheasant bird for display.',0,NULL,NULL,1.00),('phestaxi','Pheasant Taxidermy',20,1,'item_standard',1,0,521,1,1,'{}','A preserved mount of a pheasant bird for display.',0,NULL,NULL,1.00),('phonograph','Phonograph',5,1,'item_standard',1,0,11958,1,1,'{}','Set it down and play a tune.',0,NULL,NULL,2.00),('pickaxe','Pickaxe',1,1,'item_standard',1,0,522,1,1,'{}','A tool with a pointed end and a handle, used for breaking up rocks and mining.',0,100,NULL,1.00),('pickaxe1','Iron Pickaxe',5,1,'item_standard',1,0,2827,1,1,'{}','nice item',0,100,NULL,1.00),('pickaxe2','Steel Pickaxe',5,1,'item_standard',1,0,2828,1,1,'{}','nice item',0,100,NULL,1.00),('pickaxe3','Reinforced Pickaxe',5,1,'item_standard',1,0,2829,1,1,'{}','nice item',0,100,NULL,1.00),('pickaxe_wep','Pickaxe',1,1,'item_standard',1,0,30510,1,1,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('pieapple','Apple Pie',25,1,'item_standard',1,0,2157,1,1,'{}','nice item',0,NULL,NULL,1.00),('pieblackberry','Black Berry Pie',25,1,'item_standard',1,0,2159,1,1,'{}','nice item',0,NULL,NULL,1.00),('piepumpkin','Pumpkin Pie',25,1,'item_standard',1,0,2158,1,1,'{}','nice item',0,NULL,NULL,1.00),('pieredraspberry','Red Raspberry Pie',25,1,'item_standard',1,0,2160,1,1,'{}','nice item',0,NULL,NULL,1.00),('pigeon_c','Pigeon',20,1,'item_standard',1,0,523,1,1,'{}','A whole pigeon, plucked or not.',0,NULL,NULL,0.30),('pigs','Pig Hide',10,1,'item_standard',1,0,524,1,1,'{}','Thick pig skin, good for gloves and saddle patches.',0,NULL,NULL,1.50),('pincomchar','Pink Comfy Chair',25,1,'item_standard',0,0,2526,1,1,'{}','nice item',0,NULL,NULL,1.00),('pindreanavi','Painted Dream Catcher',25,1,'item_standard',0,0,2571,1,1,'{}','nice item',0,NULL,NULL,1.00),('pipe','Pipe',5,1,'item_standard',1,0,525,1,1,'{}','A tubular device used for smoking tobacco or other substances.',0,NULL,NULL,1.00),('pipecopper','Copper Pipe',10,1,'item_standard',1,0,526,1,1,'{}','A pipe made of copper.',0,NULL,NULL,1.00),('pirotrunk','Wood Trunk',25,1,'item_standard',0,0,2634,1,1,'{}','nice item',0,NULL,NULL,1.00),('pistolbarrel','Pistol Barrel',25,1,'item_standard',0,0,2752,1,1,'{}','nice item',0,NULL,NULL,1.00),('pistolgrip','Pistol Handle',25,1,'item_standard',0,0,2518,1,1,'{}','nice item',0,NULL,NULL,1.00),('pistolreceiver','Pistol Receiver',25,1,'item_standard',0,0,2544,1,1,'{}','nice item',0,NULL,NULL,1.00),('pistoo','Piano Stool',25,1,'item_standard',0,0,2660,1,1,'{}','nice item',0,NULL,NULL,1.00),('pizza','Pizza',25,1,'item_standard',1,0,2115,1,1,'{}','nice item',0,NULL,NULL,1.00),('plank_wep','Wooden Plank',1,1,'item_standard',1,0,30515,1,1,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('planttrimmer','Plant Trimmer',10,1,'item_standard',1,0,804,1,1,'{}','A pair of shears for cutting back weeds and dead leaves. A trimmed plant gives more.',0,NULL,NULL,1.00),('platinum_ring','Platinum Ring',50,1,'item_standard',0,0,4842,1,1,'{}','A valuable platinum ring.',0,NULL,NULL,1.00),('playticket','Theatre Ticket',25,1,'item_standard',0,0,2515,1,1,'{}','nice item',0,NULL,NULL,1.00),('plutar','Plum tart',25,1,'item_standard',1,0,2081,1,1,'{}','nice item',0,NULL,NULL,1.00),('pocketmirror','Pocket Mirror',1,1,'item_standard',1,0,4091,1,1,'{}','A silvered glass in a brass case. Enough to see what you are doing to your own hair.',0,NULL,NULL,1.00),('pocket_watch','Pocket Watch',5,1,'item_standard',1,0,527,1,1,'{}','A small timepiece designed to be carried in a pocket.',0,NULL,NULL,1.00),('pokerset','Poker Table Set',20,1,'item_standard',1,0,528,1,1,'{}','A complete set for playing poker, including a table and cards.',0,NULL,NULL,1.00),('polcase','Police Case',25,1,'item_standard',0,0,2636,1,1,'{}','nice item',0,NULL,NULL,1.00),('pomade','Hair Pomade',10,1,'item_standard',1,0,8203,1,1,'{}','nice item',0,NULL,NULL,1.00),('ponchos','Ponchos',50,1,'item_standard',1,0,1462,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('popo','Popcorn',25,1,'item_standard',1,0,2245,1,1,'{}','nice item',0,NULL,NULL,1.00),('popob','Popcorn With Butter',25,1,'item_standard',1,0,2246,1,1,'{}','nice item',0,NULL,NULL,1.00),('porcetabb','Visceral Stone Table',25,1,'item_standard',0,0,2628,1,1,'{}','nice item',0,NULL,NULL,1.00),('pork','Pork',20,1,'item_standard',1,0,529,1,1,'{}','The meat from a pig, commonly used for cooking and eating.',0,NULL,NULL,1.00),('porkbacon','Bacon',25,1,'item_standard',1,0,2007,1,1,'{}','nice item',0,NULL,NULL,1.00),('porkcooked','Cooked Pork',25,1,'item_standard',1,0,2006,1,1,'{}','nice item',0,NULL,NULL,1.00),('porkfat','Pig fat',20,1,'item_standard',1,0,530,1,1,'{}','The fat obtained from a pig, often used in cooking and making lard.',0,NULL,NULL,1.00),('porkwveg','Porkchops with Veggies',25,1,'item_standard',1,0,2041,1,1,'{}','nice item',0,NULL,NULL,1.00),('postratent','Posse Trader Tent',25,1,'item_standard',0,0,2472,1,1,'{}','nice item',0,NULL,NULL,1.00),('pot','Distillery Pot',10,1,'item_standard',1,0,531,1,1,'{}','A large pot used in the distillation process for making alcohol.',0,NULL,NULL,1.00),('pota','House Pot',20,1,'item_standard',1,0,532,1,1,'{}','A pot typically used for cooking and boiling ingredients.',0,NULL,NULL,1.00),('potato','Potato',50,1,'item_standard',1,0,533,1,1,'{}','A dirt-covered spud. Boil it, fry it, put it in anything.',0,NULL,NULL,1.00),('potatoseed','Potato Seed',50,1,'item_standard',1,0,534,1,1,'{}','A seed potato with good eyes, ready to go in the ground.',0,NULL,NULL,1.00),('potion','Potion',5,1,'item_standard',1,0,960,1,1,'{}','A potion with magical healing properties.',0,NULL,NULL,1.00),('prairib','Prairie Chicken Beak',25,1,'item_standard',1,0,535,1,1,'{}','A short beak from a prairie chicken.',0,NULL,NULL,0.02),('Prairie_Poppy','Prairie Poppy',50,1,'item_standard',1,0,536,1,1,'{}','An orange poppy from the open grassland.',0,NULL,NULL,1.00),('Prairie_Poppy_Seed','Prairie Poppy Seed',50,1,'item_standard',1,0,537,1,1,'{}','Tiny dark seed for a bed of prairie poppies.',0,NULL,NULL,1.00),('prairif','Prairie Chicken Feather',50,1,'item_standard',1,0,538,1,1,'{}','A barred feather from a prairie chicken.',0,NULL,NULL,0.02),('predsku1','Marked Skull',25,1,'item_standard',0,0,2511,1,1,'{}','nice item',0,NULL,NULL,1.00),('predsku2','Ritual Skull',25,1,'item_standard',0,0,2480,1,1,'{}','nice item',0,NULL,NULL,1.00),('predsku3','Scavenger Skull',25,1,'item_standard',0,0,2722,1,1,'{}','nice item',0,NULL,NULL,1.00),('predsku4','Death Skull',25,1,'item_standard',0,0,2670,1,1,'{}','nice item',0,NULL,NULL,1.00),('primerib','Prime Rib',25,1,'item_standard',1,0,2042,1,1,'{}','nice item',0,NULL,NULL,1.00),('pripia','Private Piano',25,1,'item_standard',0,0,2667,1,1,'{}','nice item',0,NULL,NULL,1.00),('pristine_accessories','Pristine Accessories',10,1,'item_standard',1,0,5051,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_armor','Pristine Armor',10,1,'item_standard',1,0,5052,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_belts','Pristine Belts',10,1,'item_standard',1,0,5053,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_belt_buckles','Pristine Buckle',10,1,'item_standard',1,0,5054,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_boots','Pristine Boots',10,1,'item_standard',1,0,5055,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_boot_accessories','Pristine Spurs',10,1,'item_standard',1,0,5056,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_chaps','Pristine Chaps',10,1,'item_standard',1,0,5057,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_cloaks','Pristine Cloaks',10,1,'item_standard',1,0,5058,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_clothingset','Pristine Clothing Set',10,1,'item_standard',1,0,5059,1,1,'{}','Dyed at a tailor. A saved copy of a worn outfit. Use to wear it.',0,NULL,NULL,1.00),('pristine_clothingset2','Pristine Clothing Set II',10,1,'item_standard',1,0,5060,1,1,'{}','Dyed at a tailor. A tailored outfit. Use to wear it.',0,NULL,NULL,1.00),('pristine_coats','Pristine Coats',10,1,'item_standard',1,0,5061,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_coats_closed','Pristine Closed Coats',10,1,'item_standard',1,0,5062,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_eyewear','Pristine EyeWear',10,1,'item_standard',1,0,5063,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_gauntlets','Pristine Gauntlets',10,1,'item_standard',1,0,5064,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_gloves','Pristine Gloves',10,1,'item_standard',1,0,5065,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_gunbelts','Pristine Gunbelts',10,1,'item_standard',1,0,5066,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_gunbelt_accs','Pristine Gunbelt Accs',10,1,'item_standard',1,0,5067,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_hair_accessories','Pristine Bows',10,1,'item_standard',1,0,5068,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_hats','Pristine Hats',10,1,'item_standard',1,0,5069,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_holsters_left','Pristine Holster',10,1,'item_standard',1,0,5070,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_jewelry_bracelets','Pristine Bracelets',10,1,'item_standard',1,0,5071,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_jewelry_rings_left','Pristine Ring Lh',10,1,'item_standard',1,0,5072,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_jewelry_rings_right','Pristine Ring Rh',10,1,'item_standard',1,0,5073,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_loadouts','Pristine Loadouts',10,1,'item_standard',1,0,5074,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_masks','Pristine Masks',10,1,'item_standard',1,0,1473,1,1,'{}','A colour-edited mask. Use to wear it.',0,NULL,NULL,1.00),('pristine_neckties','Pristine NeckTies',10,1,'item_standard',1,0,5075,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_neckwear','Pristine NeckWear',10,1,'item_standard',1,0,1474,1,1,'{}','A colour-edited neckwear. Use to wear it.',0,NULL,NULL,1.00),('pristine_pants','Pristine Pants',10,1,'item_standard',1,0,5076,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_ponchos','Pristine Ponchos',10,1,'item_standard',1,0,5077,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_satchels','Pristine Satchels',10,1,'item_standard',1,0,5078,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_shirts_full','Pristine Shirts',10,1,'item_standard',1,0,5079,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_skirts','Pristine Skirts',10,1,'item_standard',1,0,5080,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_spats','Pristine Spats',10,1,'item_standard',1,0,5081,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_suspenders','Pristine Suspenders',10,1,'item_standard',1,0,5082,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('pristine_vests','Pristine Vests',10,1,'item_standard',1,0,5083,1,1,'{}','Dyed at a tailor. A clothing item. Use to wear it.',0,NULL,NULL,1.00),('privtab','Private Cloth Table',25,1,'item_standard',0,0,2697,1,1,'{}','nice item',0,NULL,NULL,1.00),('privvchar','Private Lounge Chair',25,1,'item_standard',0,0,2601,1,1,'{}','nice item',0,NULL,NULL,1.00),('privvtab','Private Table',25,1,'item_standard',0,0,2605,1,1,'{}','nice item',0,NULL,NULL,1.00),('proleg','Prosthetic Leg',1,1,'item_standard',1,0,22149,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('pronghornh','Pronghorn Horn',25,1,'item_standard',1,0,539,1,1,'{}','A forked black horn from a pronghorn.',0,NULL,NULL,0.30),('prongs','Pronghorn Skin',20,1,'item_standard',1,0,540,1,1,'{}','The skin of a pronghorn, known for its soft and durable fur.',0,NULL,NULL,1.00),('provision_arrowhead_agate','Agate Arrowhead',10,1,'item_standard',1,0,805,1,1,'{}','A rare arrowhead fashioned from sharp, colorful agate.',0,NULL,NULL,1.00),('provision_arrowhead_bone','Bone Arrowhead',10,1,'item_standard',1,0,806,1,1,'{}','A serrated arrowhead made from animal bone.',0,NULL,NULL,1.00),('provision_arrowhead_chipped','Chipped Arrowhead',10,1,'item_standard',1,0,807,1,1,'{}','A hurriedly made arrowhead made from chiseled flint.',0,NULL,NULL,1.00),('provision_arrowhead_crude','Crude Arrowhead',10,1,'item_standard',1,0,808,1,1,'{}','A clumsily made flint arrowhead, blunt from age.',0,NULL,NULL,1.00),('provision_arrowhead_feldspar','Feldspar Arrowhead',10,1,'item_standard',1,0,809,1,1,'{}','A mysterious arrowhead made from some sort of feldspar.',0,NULL,NULL,1.00),('provision_arrowhead_granite','Flint Arrowhead',10,1,'item_standard',1,0,810,1,1,'{}','A strong arrowhead made of flint.',0,NULL,NULL,1.00),('provision_arrowhead_obsidian','Obsidian Arrowhead',10,1,'item_standard',1,0,811,1,1,'{}','A valuable arrowhead of smooth, gleaming obsidian.',0,NULL,NULL,1.00),('provision_arrowhead_quartz','Quartz Arrowhead',10,1,'item_standard',1,0,812,1,1,'{}','An eye-catching arrowhead of cut quartz, in good condition.',0,NULL,NULL,1.00),('provision_arrowhead_raw','Raw Arrowhead',10,1,'item_standard',1,0,813,1,1,'{}','A roughly hacked arrowhead made from pale stone.',0,NULL,NULL,1.00),('provision_arrowhead_rough','Rough Arrowhead',10,1,'item_standard',1,0,814,1,1,'{}','A stone arrowhead, badly weathered over time.',0,NULL,NULL,1.00),('provision_arrowhead_slate','Slate Arrowhead',10,1,'item_standard',1,0,815,1,1,'{}','A carefully made, well-preserved slate arrowhead.',0,NULL,NULL,1.00),('provision_arrowhead_splintered','Splintered Arrowhead',10,1,'item_standard',1,0,816,1,1,'{}','A partially damaged, jagged arrowhead made of chert.',0,NULL,NULL,1.00),('provision_asteroid_chunk','Meteorite',10,1,'item_standard',1,0,817,1,1,'{}','A rock that has fallen from space.',0,NULL,NULL,1.00),('provision_bracelet_gold','Gold Bracelet',10,1,'item_standard',1,0,818,1,1,'{}','A gold bracelet.',0,NULL,NULL,1.00),('provision_bracelet_platinum','Platinum Bracelet',10,1,'item_standard',1,0,819,1,1,'{}','A platinum bracelet',0,NULL,NULL,1.00),('provision_bracelet_silver','Silver Bracelet',10,1,'item_standard',1,0,820,1,1,'{}','A silver bracelet.',0,NULL,NULL,1.00),('provision_bra_shield','Brass Shield',10,1,'item_standard',1,0,821,1,1,'{}','An old brass shield. Probably valuable.',0,NULL,NULL,1.00),('provision_buckle_gold','Gold Buckle',10,1,'item_standard',1,0,822,1,1,'{}','A gold belt buckle.',0,NULL,NULL,1.00),('provision_buckle_platinum','Platinum Buckle',10,1,'item_standard',1,0,823,1,1,'{}','A platinum belt buckle.',0,NULL,NULL,1.00),('provision_buckle_silver','Silver Buckle',10,1,'item_standard',1,0,824,1,1,'{}','A silver belt buckle.',0,NULL,NULL,1.00),('provision_calderon_cross','Wooden Cross',10,1,'item_standard',1,0,825,1,1,'{}','A simple wooden cross. Often used by preists and clergymen.',0,NULL,NULL,1.00),('provision_capitale','Capitale',10,1,'item_standard',1,0,826,1,1,'{}','Capitale. very valuable.',0,NULL,NULL,1.00),('provision_coin_1700_ny_tkn','1700 New Yorke Token',10,1,'item_standard',1,0,827,1,1,'{}','A rare 1700 New Yorke Token',0,NULL,NULL,1.00),('provision_coin_1787_cent_tkn','1787 One cent Token',10,1,'item_standard',1,0,828,1,1,'{}','A rare 1787 One cent Token',0,NULL,NULL,1.00),('provision_coin_1789_pny','1789 Penny',10,1,'item_standard',1,0,829,1,1,'{}','A rare 1789 Penny',0,NULL,NULL,1.00),('provision_coin_1792_lib_qtr','1792 Liberty Quarter',10,1,'item_standard',1,0,830,1,1,'{}','A rare 1792 Liberty Quarter',0,NULL,NULL,1.00),('provision_coin_1792_nickel','1792 Nickel',10,1,'item_standard',1,0,831,1,1,'{}','A rare 1792 Nickel',0,NULL,NULL,1.00),('provision_coin_1792_qtr','1792 Quarter',10,1,'item_standard',1,0,832,1,1,'{}','A rare 1792 Quarter',0,NULL,NULL,1.00),('provision_coin_1794_slv_dlr','1794 Silver Dollar',10,1,'item_standard',1,0,833,1,1,'{}','A rare 1794 Silver Dollar',0,NULL,NULL,1.00),('provision_coin_1795_hlf_eag','1795 Half Eagle',10,1,'item_standard',1,0,834,1,1,'{}','A rare 1795 Half Eagle',0,NULL,NULL,1.00),('provision_coin_1796_hlf_pny','1796 Half Penny',10,1,'item_standard',1,0,835,1,1,'{}','A rare 1796 Half Penny',0,NULL,NULL,1.00),('provision_coin_1797_gld_eag','1797 Gold Eagle',10,1,'item_standard',1,0,836,1,1,'{}','A rare 1797 Gold Eagle',0,NULL,NULL,1.00),('provision_coin_1798_slv_dlr','1798 Silver Dollar',10,1,'item_standard',1,0,837,1,1,'{}','A rare 1798 Silver Dollar',0,NULL,NULL,1.00),('provision_coin_1800_five_dlr','1800 Five Dollar',10,1,'item_standard',1,0,838,1,1,'{}','A rare 1800 Five Dollar',0,NULL,NULL,1.00),('provision_coin_1800_gld_dlr','1800 Gold Dollar',10,1,'item_standard',1,0,839,1,1,'{}','A rare 1800 Gold Dollar',0,NULL,NULL,1.00),('provision_coin_1800_gld_qtr','1800 Gold Quarter',10,1,'item_standard',1,0,840,1,1,'{}','A rare 1800 Gold Quarter',0,NULL,NULL,1.00),('provision_coin_1800_hlf_dime','1800 Half Dime',10,1,'item_standard',1,0,841,1,1,'{}','A rare 1800 Half Dime',0,NULL,NULL,1.00),('provision_db_finger_bone','Bone',10,1,'item_standard',1,0,842,1,1,'{}','A small bone possibly from a finger.',0,NULL,NULL,1.00),('provision_diamond_ring','Diamond Ring',10,1,'item_standard',1,0,843,1,1,'{}','A beautiful diamond ring.',0,NULL,NULL,1.00),('provision_disco_ammolite','Ammolite',10,1,'item_standard',1,0,844,1,1,'{}','Fossilized shell of an ammonite.',0,NULL,NULL,1.00),('provision_disco_ancient_eagle','Ancient Eagle',10,1,'item_standard',1,0,845,1,1,'{}','An ancient eagle statue.',0,NULL,NULL,1.00),('provision_disco_ancient_necklace','Ancient Necklace',10,1,'item_standard',1,0,846,1,1,'{}','An ancient necklace.',0,NULL,NULL,1.00),('provision_disco_fertility_statue','Fertility Statue',10,1,'item_standard',1,0,847,1,1,'{}','A statue that apparently possesses the power to grant fertility.',0,NULL,NULL,1.00),('provision_disco_fluorite','Fluorite',10,1,'item_standard',1,0,848,1,1,'{}','The mineral form of calcium fluoride.',0,NULL,NULL,1.00),('provision_disco_shrunken_head','Shrunken Head',10,1,'item_standard',1,0,849,1,1,'{}','A shurken head. possibly used in vodoo.',0,NULL,NULL,1.00),('provision_disco_urn','Urn',10,1,'item_standard',1,0,850,1,1,'{}','A simple urn often used to hold things.',0,NULL,NULL,1.00),('provision_disco_viking_comb','Viking Comb',10,1,'item_standard',1,0,851,1,1,'{}','A old viking comb.',0,NULL,NULL,1.00),('provision_dog_tag','Dog Tag',10,1,'item_standard',1,0,852,1,1,'{}','A dog tag. Possibly from a soldier.',0,NULL,NULL,1.00),('provision_earring_gold','Gold Earring',10,1,'item_standard',1,0,853,1,1,'{}','A gold earring.',0,NULL,NULL,1.00),('provision_earring_pearl','Pearl Earring',10,1,'item_standard',1,0,854,1,1,'{}','A gold earring.',0,NULL,NULL,1.00),('provision_earring_platinum','Platinum Earring',10,1,'item_standard',1,0,855,1,1,'{}','A beautiful pearl earring.',0,NULL,NULL,1.00),('provision_earring_silver','Silver Earring',10,1,'item_standard',1,0,856,1,1,'{}','A silver earring.',0,NULL,NULL,1.00),('provision_generic_key','Key',10,1,'item_standard',1,0,857,1,1,'{}','A simple key.',0,NULL,NULL,1.00),('provision_hrlm_brush_boar','Boar bristle Brush',10,1,'item_standard',1,0,858,1,1,'{}','A beautifully made boar bristle brush.',0,NULL,NULL,1.00),('provision_hrlm_brush_ebony','Ebony Hairbrush',10,1,'item_standard',1,0,859,1,1,'{}','A delicate and finely crafted ebony brush.',0,NULL,NULL,1.00),('provision_hrlm_brush_goathair','Goat Hair Brush',10,1,'item_standard',1,0,860,1,1,'{}','A exquisite hand crafted goat hair brush.',0,NULL,NULL,1.00),('provision_hrlm_brush_horsehair','Horse Hair brush',10,1,'item_standard',1,0,861,1,1,'{}','A finley made horse hair brush.',0,NULL,NULL,1.00),('provision_hrlm_brush_rosewood','Rosewood Hairbrush',10,1,'item_standard',1,0,862,1,1,'{}','A hand carved rosewood brush.',0,NULL,NULL,1.00),('provision_hrlm_brush_rosewood_ng','New Guinea Rosewood Hairbrush',10,1,'item_standard',1,0,863,1,1,'{}','An exotic new guinea rosewood hairbrush.',0,NULL,NULL,1.00),('provision_hrlm_comb_boxwood','Boxwood Comb',10,1,'item_standard',1,0,864,1,1,'{}','A finley made boxwood comb.',0,NULL,NULL,1.00),('provision_hrlm_comb_cherrywood','Cherrywood Comb',10,1,'item_standard',1,0,865,1,1,'{}','A exquisite cheerywood comb.',0,NULL,NULL,1.00),('provision_hrlm_comb_ivory','Ivory Comb',10,1,'item_standard',1,0,866,1,1,'{}','A delicate ivory comb.',0,NULL,NULL,1.00),('provision_hrlm_comb_tortoiseshell','Tortoiseshell Comb',10,1,'item_standard',1,0,867,1,1,'{}','A beautiful tortoiseshell comb.',0,NULL,NULL,1.00),('provision_hrlm_hairpin_ebony','Ebony Hairpin',10,1,'item_standard',1,0,868,1,1,'{}','A exquisite ebony hairpin.',0,NULL,NULL,1.00),('provision_hrlm_hairpin_ivory','Ivory Hairpin',10,1,'item_standard',1,0,869,1,1,'{}','A delicate ivory hairpin.',0,NULL,NULL,1.00),('provision_hrlm_hairpin_jade','Jade Hairpin',10,1,'item_standard',1,0,870,1,1,'{}','A exotic jade hairpin.',0,NULL,NULL,1.00),('provision_hrlm_hairpin_metal','Meatl Hairpin',10,1,'item_standard',1,0,871,1,1,'{}','A beautiful metal hairpin.',0,NULL,NULL,1.00),('provision_hrlm_hairpin_wooden','Wooden Hairpin',10,1,'item_standard',1,0,872,1,1,'{}','A hand carved wooden hairpin.',0,NULL,NULL,1.00),('provision_jail_keys','Jail Keys',10,1,'item_standard',1,0,541,1,1,'{}','A set of keys used to unlock jail cells and gates.',0,NULL,NULL,1.00),('provision_jewelry_amethyst_necklace','Richelieu Amethyst Necklace',10,1,'item_standard',1,0,873,1,1,'{}','A delicate necklace featuring a duo of purple amethyst and silver pearl.',0,NULL,NULL,1.00),('provision_jewelry_blck_pearl_necklace','Tuamotu Pearl Necklace',10,1,'item_standard',1,0,874,1,1,'{}','A silk strung necklace of magnificent black Tahitian pearls.',0,NULL,NULL,1.00),('provision_jewelry_box','Jewelry Box',10,1,'item_standard',1,0,875,1,1,'{}','A small jewlery box.',0,NULL,NULL,1.00),('provision_jewelry_carved_bracelet','Elliston Carved Bracelet',10,1,'item_standard',1,0,876,1,1,'{}','A solid gold bracelet with elegant etching.',0,NULL,NULL,1.00),('provision_jewelry_coral_dngl_earring','Emmeline Coral Earrings',10,1,'item_standard',1,0,877,1,1,'{}','Drop hook earrings of polished pink coral set in gold.',0,NULL,NULL,1.00),('provision_jewelry_coral_ring','Harland Coral Ring',10,1,'item_standard',1,0,878,1,1,'{}','A delicate gold ring featuring a large angel skin coral.',0,NULL,NULL,1.00),('provision_jewelry_dmnd_bngle_bracelet','AbellÃ³ Ruby Bangle Bracelet',10,1,'item_standard',1,0,879,1,1,'{}','A hinged gold bangle with a series of claw set rubies.',0,NULL,NULL,1.00),('provision_jewelry_dmnd_pendt_earring','OrchidÃ©e Diamond Earrings',10,1,'item_standard',1,0,880,1,1,'{}','Earrings set with clusters of brilliant cut diamonds in a floral pattern.',0,NULL,NULL,1.00),('provision_jewelry_elk_tooth_earring','Sterling Tooth Earrings',10,1,'item_standard',1,0,881,1,1,'{}','A striking pair of elk teeth set into silver.',0,NULL,NULL,1.00),('provision_jewelry_emerald_earring','Duchess Emerald Earrings',10,1,'item_standard',1,0,882,1,1,'{}','A famous set of oval cut emeralds fashioned into earrings.',0,NULL,NULL,1.00),('provision_jewelry_emerald_ring','Bosque Emerald Ring',10,1,'item_standard',1,0,883,1,1,'{}','A gold band with an extravagant bezel set Columbian emerald.',0,NULL,NULL,1.00),('provision_jewelry_french_dmnd_ring','Beaulieux Diamond Ring',10,1,'item_standard',1,0,884,1,1,'{}','A number of old mine cut diamonds claw set in a silver ring from France.',0,NULL,NULL,1.00),('provision_jewelry_gld_bngle_bracelet','Ojeda Rose Gold Bangle Bracelet',10,1,'item_standard',1,0,885,1,1,'{}','A large bracelet of rose gold with elaborate cameo detailing.',0,NULL,NULL,1.00),('provision_jewelry_gld_cross_necklace','Ainsworth Cross Necklace',10,1,'item_standard',1,0,886,1,1,'{}','A solid gold chain necklace with an etched gold cross.',0,NULL,NULL,1.00),('provision_jewelry_gld_pearl_necklace','Rou Pearl Necklace',10,1,'item_standard',1,0,887,1,1,'{}','A necklace made of fine rose gold featuring a single pearl from the Orient.',0,NULL,NULL,1.00),('provision_jewelry_gld_pendt_necklace','Gosselin White Gold Necklace',10,1,'item_standard',1,0,888,1,1,'{}','A lavalier style white gold necklace with a series of small diamonds.',0,NULL,NULL,1.00),('provision_jewelry_grnet_bracelet','Hajnal Garnet Bangle Bracelet',10,1,'item_standard',1,0,889,1,1,'{}','A bohemian style silver bangle with numerous claw set garnets.',0,NULL,NULL,1.00),('provision_jewelry_grnet_post_earring','Harford Garnet Earrings',10,1,'item_standard',1,0,890,1,1,'{}','Clustered garnet studs with silver posts and scrolls.',0,NULL,NULL,1.00),('provision_jewelry_moon_ring','Pilgrim Moonstone Ring',10,1,'item_standard',1,0,891,1,1,'{}','A thick gold band with a single claw set moonstone.',0,NULL,NULL,1.00),('provision_jewelry_mthr_pearl_necklace','PellÃ© Pearl Necklace',10,1,'item_standard',1,0,892,1,1,'{}','A beaded chain necklace with a fashionable mother of pearl pendant.',0,NULL,NULL,1.00),('provision_jewelry_onyx_ring','Aubrey Onyx Ring',10,1,'item_standard',1,0,893,1,1,'{}','A rare white gold ring with a bezel set diamond surrounded by polished onyx.',0,NULL,NULL,1.00),('provision_jewelry_pearl_bracelet','Durant Pearl Bracelet',10,1,'item_standard',1,0,894,1,1,'{}','An intricate link bracelet with natural pearls and gold filigree.',0,NULL,NULL,1.00),('provision_jewelry_pearl_earring','Josephine Pearl Earrings',10,1,'item_standard',1,0,895,1,1,'{}','Fashionable pearl earrings with neat gold hooks.',0,NULL,NULL,1.00),('provision_jewelry_pearl_ring','Bonnard Pearl Ring',10,1,'item_standard',1,0,896,1,1,'{}','A valuable pearl set into a white gold band.',0,NULL,NULL,1.00),('provision_jewelry_pers_turq_ring','Thorburn Turquoise Ring',10,1,'item_standard',1,0,897,1,1,'{}','A delicately crafted rose gold ring with turquoise beads.',0,NULL,NULL,1.00),('provision_jewelry_porcelain_necklace','Braxton Amethyst Necklace',10,1,'item_standard',1,0,898,1,1,'{}','A fashionable necklace with a porcelain hand painted miniature.',0,NULL,NULL,1.00),('provision_jewelry_qn_dmnd_earring','Royal Victoria Diamond Earrings',10,1,'item_standard',1,0,899,1,1,'{}','A series of small diamonds claw set in a floral cluster on a white gold band.',0,NULL,NULL,1.00),('provision_jewelry_rudy_dngl_earring','BeauchÃªne Ruby Earrings',10,1,'item_standard',1,0,900,1,1,'{}','Elaborate gold hook earrings with vivid rubies.',0,NULL,NULL,1.00),('provision_jewelry_slvr_pearl_necklace','Silver Pearl Necklace',10,1,'item_standard',1,0,901,1,1,'{}','A necklace made of fine silver and pearls.',0,NULL,NULL,1.00),('provision_jewelry_sphr_bngle_bracelet','Greco Sapphire Bracelet',10,1,'item_standard',1,0,902,1,1,'{}','A delicate gold bracelet with three small sapphires.',0,NULL,NULL,1.00),('provision_jewelry_sphr_bracelet','Helena Sapphire Bracelet',10,1,'item_standard',1,0,903,1,1,'{}','A fine silver bracelet with claw set sapphires.',0,NULL,NULL,1.00),('provision_jewelry_topaz_necklace','Dane Topaz Necklace',10,1,'item_standard',1,0,904,1,1,'{}','A precious platinum chain necklace with a small drop of topaz.',0,NULL,NULL,1.00),('provision_jewelry_topaz_ring','Banais Topaz Ring',10,1,'item_standard',1,0,905,1,1,'{}','A neat silver wedding ring with brilliant cut topaz.',0,NULL,NULL,1.00),('provision_jewelry_turquoise_bracelet','Infanta Turquoise Bracelet',10,1,'item_standard',1,0,906,1,1,'{}','A solid silver bracelet with a large turquoise stone.',0,NULL,NULL,1.00),('provision_jewelry_turquoise_ring','Magnate Turquoise Ring',10,1,'item_standard',1,0,907,1,1,'{}','A solid gold ring with an oval of polished turquoise from Persia.',0,NULL,NULL,1.00),('provision_jewelry_turq_stud_earring','Calumet Turquoise Earrings',10,1,'item_standard',1,0,908,1,1,'{}','Lavish gold studs with claw set turquoise stones.',0,NULL,NULL,1.00),('provision_jewelry_whtgld_dmnd_ring','Sackville Diamond Ring',10,1,'item_standard',1,0,909,1,1,'{}','A series of small diamonds claw set in a floral cluster on a white gold band.',0,NULL,NULL,1.00),('provision_jewelry_wht_dmnd_earring','Endicott Diamond Earrings',10,1,'item_standard',1,0,910,1,1,'{}','Exquisite pendant earrings with old mine cut diamonds.',0,NULL,NULL,1.00),('provision_jewelry_ylwgld_dmnd_ring','Yates Diamond Ring',10,1,'item_standard',1,0,911,1,1,'{}','An intricate gold band with one cushion cut diamond.',0,NULL,NULL,1.00),('provision_meat_crustacean','Raw Crustacean Meat',25,1,'item_standard',1,0,33455,1,1,'{}','',0,NULL,NULL,0.05),('provision_ring_platinum','Platinum Ring',10,1,'item_standard',1,0,912,1,1,'{}','A finely crafted platinum ring.',0,NULL,NULL,1.00),('provision_ro_flower_acunas_star','Acunas Star Orchid',10,1,'item_standard',1,0,913,1,1,'{}','The Acunas Star Orchid an be identified by the branching of the stems, alternate leaves, and cream colored petals. The trailing plant is often found on the ground or growing around trees in swampland areas.',0,NULL,NULL,1.00),('provision_ro_flower_cigar','Cigar Orchid',10,1,'item_standard',1,0,914,1,1,'{}','The Cigar Orchid can be identified by the inflorescence which can produce around five hundred bright yellow flowers with purple and brown markings.',0,NULL,NULL,1.00),('provision_ro_flower_clamshell','Clamshell Orchid',10,1,'item_standard',1,0,915,1,1,'{}','The Clamshell Orchid can be identified by the deep purple and white petals with yellow streaks, and thin leaves.',0,NULL,NULL,1.00),('provision_ro_flower_dragons','Dragons Orchid',10,1,'item_standard',1,0,916,1,1,'{}','Dragons Mouth Orchids can be recognized by their wild purple flowers which are said to resemble a dragon. The general size of this type of orchid is around six inches.',0,NULL,NULL,1.00),('provision_ro_flower_ghost','Ghost Orchid',10,1,'item_standard',1,0,917,1,1,'{}','The Ghost Orchid is named after the white to pale pink flowers that can be seen in shaded habitats. This small orchid grows in shaded areas, such as woodlands, and under leaves and soil, with only the flower appearing above ground.',0,NULL,NULL,1.00),('provision_ro_flower_lady_of_night','Lady of Night Orchid',10,1,'item_standard',1,0,918,1,1,'{}','Lady of the Night Orchid takes its name from the sweet citrus fragrance it produces during nightfall. The orchid can be identified by the white heart shaped flowers and long leaves.',0,NULL,NULL,1.00),('provision_ro_flower_lady_slipper','Lady Slipper Orchid',10,1,'item_standard',1,0,919,1,1,'{}','Lady Slipper Orchid can be identified by the large bulbous purple flower and speckled purple leaves. This type of orchid can be seen growing in the ground of forests, meadows and woodland areas.',0,NULL,NULL,1.00),('provision_ro_flower_moccasin','Moccasin Orchid',10,1,'item_standard',1,0,920,1,1,'{}','Moccasin Flower Orchid can be identified by the yellow pouch like petal, red sepals, and wide leaves. This orchid can be found growing near pines or conifers in woodlands and forests.',0,NULL,NULL,1.00),('provision_ro_flower_night_scented','Night Scented Orchid',10,1,'item_standard',1,0,921,1,1,'{}','Night Scented Orchid can be identified by the alternate stems, the long sepals, and white petal flowers. This orchid can be found growing upon another plant, often draping down from trees.',0,NULL,NULL,1.00),('provision_ro_flower_queens','Queens Orchid',10,1,'item_standard',1,0,922,1,1,'{}','The Queens Orchid can be identified by the white sepals, and purple and white curled petal.',0,NULL,NULL,1.00),('provision_ro_flower_rat_tail','Rat Tail Orchid',10,1,'item_standard',1,0,923,1,1,'{}','The Rat Tail Orchid has long, thin hanging stems, pencil-like leaves and rigid flowering stems bearing up to twelve crowded white to cream-coloured flowers.',0,NULL,NULL,1.00),('provision_ro_flower_sparrows','Sparrows Orchid',10,1,'item_standard',1,0,924,1,1,'{}','The Sparrows Orchid usually has 3 to 7 oval or lance-shaped leaves arranged alternately on the stem.',0,NULL,NULL,1.00),('provision_ro_flower_spider','Spider Orchid',10,1,'item_standard',1,0,925,1,1,'{}','The Spider Orchid is Characterised by five long spreading petals and sepals around a broad down-curled lip.',0,NULL,NULL,1.00),('pulp','Pulp',50,1,'item_standard',0,0,542,1,1,'{}','A soft and moist mass of plant fibers, typically obtained from crushing or processing plant materials.',0,NULL,NULL,1.00),('pumpkin','Pumpkin',25,1,'item_standard',0,0,2727,1,1,'{}','A heavy orange pumpkin. Pie, soup or a lantern in the fall.',0,NULL,NULL,1.00),('pumpkinseeds','Pumpkin Seeds',50,1,'item_standard',1,0,2832,1,1,'{}','Flat white seed for a sprawling pumpkin vine.',0,NULL,NULL,1.00),('pup_arrows','Arrow Bundle',1,1,'item_standard',1,0,10287,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_badge_deputy','Deputy Badge',1,1,'item_standard',1,0,10252,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_badge_marshal','US Marshal Badge',1,1,'item_standard',1,0,10254,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_badge_pinkerton','Pinkerton Badge',1,1,'item_standard',1,0,24613,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_badge_police','Police Badge',1,1,'item_standard',1,0,24614,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_badge_sheriff','Sheriff Badge',1,1,'item_standard',1,0,10253,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_banjo','Banjo',1,1,'item_standard',1,0,10234,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_banjo_snakeskin','Snakeskin Banjo',1,1,'item_standard',1,0,10233,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_basket','Basket',1,1,'item_standard',1,0,10285,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_bible','Bible',1,1,'item_standard',1,0,10250,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_billyclub','Billy Club',1,1,'item_standard',1,0,10255,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_book_leather','Leather Book',1,1,'item_standard',1,0,10248,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_book_lillian','Old Ledger',1,1,'item_standard',1,0,10249,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_book_worn','Worn Book',1,1,'item_standard',1,0,10247,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_candelabra','Candelabra',1,1,'item_standard',1,0,10238,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_candle','Candle',1,1,'item_standard',1,0,10242,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_candlestand','Candle Stand',1,1,'item_standard',1,0,20116,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_candle_lamp','Candle Lamp',1,1,'item_standard',1,0,10243,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_cane_claw','Claw Cane',1,1,'item_standard',1,0,4552,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_cane_diamond','Diamond Cane',1,1,'item_standard',1,0,4554,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_cane_skull','Skull Cane',1,1,'item_standard',1,0,4551,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_cane_wood','Wooden Cane',1,1,'item_standard',1,0,4553,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_cigar','Lit Cigar',1,1,'item_standard',1,0,4550,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_cigarette','Cigarette',1,1,'item_standard',1,0,4549,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_cigarette_holder','Cigarette Holder',1,1,'item_standard',1,0,4548,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_cigar_unlit','Unlit Cigar',1,1,'item_standard',1,0,10244,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_coffee_mug','Coffee Mug',1,1,'item_standard',1,0,10246,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_contrabass','Double Bass',1,1,'item_standard',1,0,10232,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_cross_necklace','Silver Cross Necklace',1,1,'item_standard',1,0,4561,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_doll','Porcelain Doll',1,1,'item_standard',1,0,10281,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_doll2','Rag Doll',1,1,'item_standard',1,0,10282,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_dreamcatcher','Dreamcatcher',1,1,'item_standard',1,0,10275,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_fan_feather','Feather Fan',1,1,'item_standard',1,0,10295,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_fan_feather2','Feather Fan II',1,1,'item_standard',1,0,10294,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_fan_folding','Folding Fan',1,1,'item_standard',1,0,10286,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_feather_eagle','Eagle Feather',1,1,'item_standard',1,0,10264,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_feather_spoonbill','Spoonbill Feather',1,1,'item_standard',1,0,10265,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_flowers','Flower Pot',1,1,'item_standard',1,0,10280,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_hatband1','Hat Band',1,1,'item_standard',1,0,10291,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_hatband12','Hat Band IV',1,1,'item_standard',1,0,10292,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_hatband2','Hat Band II',1,1,'item_standard',1,0,10293,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_hatband4','Hat Band III',1,1,'item_standard',1,0,10296,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_hay','Hay Piece',1,1,'item_standard',1,0,4559,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_headdress_native','Feathered Mask Headdress',1,1,'item_standard',1,0,20119,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_headdress_owl','Owl Feather Headdress',1,1,'item_standard',1,0,20118,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_lantern_brass','Brass Lantern',1,1,'item_standard',1,0,10240,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_lantern_brass2','Brass Lantern II',1,1,'item_standard',1,0,10241,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_lantern_hanging','Hanging Lantern',1,1,'item_standard',1,0,10239,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_magnifier','Magnifying Glass',1,1,'item_standard',1,0,10251,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_mandolin','Mandolin',1,1,'item_standard',1,0,10235,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_mask_native','Carved Mask',1,1,'item_standard',1,0,10277,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_medical_box','Medical Box',1,1,'item_standard',1,0,10289,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_megaphone','Megaphone',1,1,'item_standard',1,0,10283,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_moneystack','Stack of Bills',1,1,'item_standard',1,0,20114,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_necklace','Necklace',1,1,'item_standard',1,0,10261,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_opium_pipe','Opium Pipe',1,1,'item_standard',1,0,4557,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_pen','Pen',1,1,'item_standard',1,0,20115,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_piano','Upright Piano',1,1,'item_standard',1,0,20120,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_pipe_briar','Briar Pipe',1,1,'item_standard',1,0,4558,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_pipe_clay','Clay Pipe',1,1,'item_standard',1,0,4556,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_pipe_corn','Corn Cob Pipe',1,1,'item_standard',1,0,4555,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_rabbit_foot','Rabbit Foot',1,1,'item_standard',1,0,10263,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_rabbit_head','Rabbit Head',1,1,'item_standard',1,0,10269,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_rattle','Ritual Rattle',1,1,'item_standard',1,0,10276,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_ring1','Gold Band',1,1,'item_standard',1,0,10256,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_ring2','Silver Band',1,1,'item_standard',1,0,10257,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_ring3','Signet Ring',1,1,'item_standard',1,0,10258,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_ring4','Jewelled Ring',1,1,'item_standard',1,0,10259,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_ring5','Bone Ring',1,1,'item_standard',1,0,10260,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_scissors','Barber Scissors',1,1,'item_standard',1,0,10278,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_shoe','Shoe',1,1,'item_standard',1,0,10284,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_shrunken_head','Shrunken Head',1,1,'item_standard',1,0,10274,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_skull','Human Skull',1,1,'item_standard',1,0,10268,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_stethoscope','Stethoscope',1,1,'item_standard',1,0,10279,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_toothpick','Toothpick',1,1,'item_standard',1,0,4560,1,1,'{}','nice item',0,NULL,NULL,1.00),('pup_totem','Carved Totem',1,1,'item_standard',1,0,10273,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_trinket_crane','Crane Feather Trinket',1,1,'item_standard',1,0,10266,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_trinket_gold','Ornate Gold Trinket',1,1,'item_standard',1,0,10267,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_trinket_turtle','Turtle Shell Trinket',1,1,'item_standard',1,0,10262,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_trumpet','Trumpet',1,1,'item_standard',1,0,10237,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_umbrella','Umbrella',1,1,'item_standard',1,0,10290,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_veil','Mourning Veil',1,1,'item_standard',1,0,10288,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_viola','Viola',1,1,'item_standard',1,0,10236,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_voodoo_bag','Voodoo Bag',1,1,'item_standard',1,0,10272,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_voodoo_doll','Voodoo Doll',1,1,'item_standard',1,0,10270,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_voodoo_doll2','Voodoo Doll II',1,1,'item_standard',1,0,10271,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_whiskey_glass','Whiskey Glass',1,1,'item_standard',1,0,10245,1,5,'{}','nice item',0,NULL,NULL,1.00),('pup_wineglass','Glass of Wine',1,1,'item_standard',1,0,20117,1,5,'{}','nice item',0,NULL,NULL,1.00),('pure','Pure',25,1,'item_standard',1,0,2604,1,1,'{}','nice item',0,NULL,NULL,1.00),('p_baitBread01x','Bread Bait',20,1,'item_standard',1,0,543,1,1,'{}','A piece of bread used as bait for fishing.',0,NULL,NULL,1.00),('p_baitCheese01x','Cheese Bait',10,1,'item_standard',1,0,946,1,1,'{}','A soft cheese bait, favored by fish with a strong sense of smell like catfish.',0,NULL,NULL,1.00),('p_baitCorn01x','Corn Bait',10,1,'item_standard',1,0,945,1,1,'{}','A simple bait made from corn, commonly used to attract small freshwater fish.',0,NULL,NULL,1.00),('p_baitCricket01x','Cricket Bait',10,1,'item_standard',1,0,948,1,1,'{}','A lively bait made from crickets, effective for attracting larger fish.',0,NULL,NULL,1.00),('p_baitWorm01x','Worm Bait',10,1,'item_standard',1,0,947,1,1,'{}','A classic bait made from worms, ideal for catching a wide variety of fish species.',0,NULL,NULL,1.00),('p_barrelmoonshine','Barrel',1,1,'item_standard',1,0,544,1,1,'{}','A container, typically made of wood, used for storing and aging moonshine.',0,NULL,NULL,1.00),('p_crawdad01x','Crawfish Bait',10,1,'item_standard',1,0,949,1,1,'{}','A freshwater bait made from crawfish, used to catch larger predatory fish.',0,NULL,NULL,1.00),('p_FinisdFishlure01x','Fish Lure',10,1,'item_standard',1,0,951,1,1,'{}','A versatile fish lure designed to attract a variety of freshwater species.',0,NULL,NULL,1.00),('p_finisdfishlurelegendary01x','Legendary Fish Lure',10,1,'item_standard',1,0,954,1,1,'{}','A premium fish lure designed to catch elusive legendary fish.',0,NULL,NULL,1.00),('p_finishdcrawd01x','Crawfish Lure',10,1,'item_standard',1,0,952,1,1,'{}','A lure that mimics the movement of a crawfish, enticing larger predatory fish.',0,NULL,NULL,1.00),('p_finishdcrawdlegendary01x','Legendary Crawfish Lure',10,1,'item_standard',1,0,955,1,1,'{}','A specialized crawfish lure made for catching rare legendary fish.',0,NULL,NULL,1.00),('p_finishedragonfly01x','Dragonfly Lure',10,1,'item_standard',1,0,950,1,1,'{}','A realistic dragonfly lure designed to mimic flying insects, perfect for catching surface-feeding fish.',0,NULL,NULL,1.00),('p_finishedragonflylegendary01x','Legendary Dragonfly Lure',10,1,'item_standard',1,0,953,1,1,'{}','A high-quality dragonfly lure crafted to attract legendary fish in special locations.',0,NULL,NULL,1.00),('p_lgoc_spinner_v4','Spinner V4',10,1,'item_standard',1,0,956,1,1,'{}','A high-speed spinner lure, perfect for attracting aggressive, fast-moving fish.',0,NULL,NULL,1.00),('p_lgoc_spinner_v6','Spinner V6',10,1,'item_standard',1,0,957,1,1,'{}','An advanced spinner lure with enhanced spinning action, ideal for large, deep-water fish.',0,NULL,NULL,1.00),('quailb','Quail Beak',25,1,'item_standard',1,0,545,1,1,'{}','A tiny beak from a quail.',0,NULL,NULL,0.02),('quailf','Quail Feather',50,1,'item_standard',1,0,546,1,1,'{}','A small speckled feather from a quail.',0,NULL,NULL,0.02),('quartz','Quartz',20,1,'item_standard',1,0,547,1,1,'{}','A hard mineral often used in jewelry and decorative items.',0,NULL,NULL,1.00),('rabbitpaw','Rabbit\'s Foot',25,1,'item_standard',1,0,548,1,1,'{}','Carried for luck. It did the rabbit no good.',0,NULL,NULL,0.05),('rabbits','Rabbit Pelt',10,1,'item_standard',1,0,549,1,1,'{}','A soft little pelt for linings and mittens.',0,NULL,NULL,0.30),('raccoons','Raccoon Pelt',10,1,'item_standard',1,0,550,1,1,'{}','A ringed-tail pelt for caps and collars.',0,NULL,NULL,0.50),('raccoont','Raccoon Tooth',25,1,'item_standard',1,0,551,1,1,'{}','A small tooth from a raccoon.',0,NULL,NULL,0.05),('raisin','Raisin',10,1,'item_standard',1,0,926,1,1,'{}','A dried grape that makes good eating.',0,NULL,NULL,1.00),('rajahdysoljy','Explosive Oil',30,1,'item_standard',1,0,552,1,1,'{}','An explosive oil used for various purposes, such as creating dynamite and explosives.',0,NULL,NULL,1.00),('rake_wep','Garden Rake',1,1,'item_standard',1,0,30512,1,1,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('ramhorn','Ram Horn',25,1,'item_standard',1,0,553,1,1,'{}','A curled, ridged horn from a bighorn.',0,NULL,NULL,0.60),('ramposnavi','Bull Skull Post',25,1,'item_standard',0,0,2449,1,1,'{}','nice item',0,NULL,NULL,1.00),('rams','Ram Pelt',20,1,'item_standard',1,0,554,1,1,'{}','The fur and skin of a ram, known for its warmth and durability.',0,NULL,NULL,1.00),('Rams_Head','Rams Head',10,1,'item_standard',1,0,555,1,1,'{}','The preserved head of a ram, often used as a hunting trophy or decorative item.',0,NULL,NULL,1.00),('Rams_Head_Seed','Rams Head Seed',50,1,'item_standard',1,0,556,1,1,'{}','A seed that can be planted to grow plants resembling a rams head.',0,NULL,NULL,1.00),('raspberryale','Raspberry Ale',10,1,'item_standard',1,0,557,1,1,'{}','A type of ale infused with the flavor of raspberries.',0,NULL,NULL,1.00),('raspberrywater','Raspberry Water',25,1,'item_standard',1,0,2028,1,1,'{}','nice item',0,NULL,NULL,1.00),('rat_c','Rat',20,1,'item_standard',1,0,558,1,1,'{}','A whole rat. Somebody always wants one.',0,NULL,NULL,0.20),('ravenc','Raven Talon',25,1,'item_standard',1,0,559,1,1,'{}','A thin black talon from a raven.',0,NULL,NULL,0.05),('ravenf','Raven Feather',50,1,'item_standard',1,0,560,1,1,'{}','A glossy black feather from a raven.',0,NULL,NULL,0.05),('raw_bacon','Raw Bacon',10,1,'item_standard',1,0,927,1,1,'{}','Raw uncooked bacon.',0,NULL,NULL,1.00),('rber','Root Beer',25,1,'item_standard',1,0,2051,1,1,'{}','nice item',0,NULL,NULL,1.00),('rebed','Rebed',25,1,'item_standard',0,0,2570,1,1,'{}','nice item',0,NULL,NULL,1.00),('rechar','Red Linen Chair',25,1,'item_standard',0,0,2649,1,1,'{}','nice item',0,NULL,NULL,1.00),('rectable','Rectangle Table',20,1,'item_standard',1,0,561,1,1,'{}','A rectangular-shaped table, suitable for various purposes such as dining or work.',0,NULL,NULL,1.00),('rectangle_table','Rectangle Table',20,1,'item_standard',1,0,562,1,1,'{}','A table with a rectangular shape, often used for dining or as a work surface.',0,NULL,NULL,1.00),('redcomchar','Red Comfy Chair',25,1,'item_standard',0,0,2525,1,1,'{}','nice item',0,NULL,NULL,1.00),('redgaro','Red sage and garlic roast',25,1,'item_standard',1,0,2068,1,1,'{}','nice item',0,NULL,NULL,1.00),('redpaint','Red Paint',25,1,'item_standard',0,0,2467,1,1,'{}','nice item',0,NULL,NULL,1.00),('Red_Raspberry','Red Raspberry',50,1,'item_standard',1,0,563,1,1,'{}','Soft red berries that fall apart if you look at them wrong. Great for jam.',0,NULL,NULL,1.00),('Red_Raspberry_Seed','Red Raspberry Seed',50,1,'item_standard',1,0,564,1,1,'{}','Seed for a raspberry cane.',0,NULL,NULL,1.00),('Red_Sage','Red Sage',50,1,'item_standard',1,0,565,1,1,'{}','A sage with red flower spikes, dried and burned or steeped as medicine.',0,NULL,NULL,1.00),('Red_Sage_Seed','Red Sage Seed',50,1,'item_standard',1,0,566,1,1,'{}','Seed for a stand of red sage.',0,NULL,NULL,1.00),('repair_kit','Weapon Repair Kit',10,1,'item_standard',1,0,1875,1,1,'{}','Restores a weapon to like-new condition.',0,NULL,NULL,1.00),('repeaterbarrel','Repeater Barrel',25,1,'item_standard',1,0,567,1,1,'{}','A replacement barrel for a repeater firearm, used for improving accuracy and performance.',0,NULL,NULL,1.00),('repeatermold','Repeater Mold',5,1,'item_standard',1,0,568,1,1,'{}','A mold used for casting the components of a repeater firearm.',0,NULL,NULL,1.00),('repeaterreceiver','Repeater Receiver',5,1,'item_standard',1,0,569,1,1,'{}','A replacement receiver for a repeater firearm, which houses the firing mechanism.',0,NULL,NULL,1.00),('repeaterrecmold','Repeater Receiver Mold',5,1,'item_standard',1,0,570,1,1,'{}','A mold used for casting the receiver of a repeater firearm.',0,NULL,NULL,1.00),('repeaterstock','Repeater Stock',5,1,'item_standard',1,0,571,1,1,'{}','A replacement stock for a repeater firearm, providing stability and control.',0,NULL,NULL,1.00),('revolverbarrel','Revolver Barrel',25,1,'item_standard',1,0,572,1,1,'{}','A replacement barrel for a revolver firearm, used for improving accuracy and performance.',0,NULL,NULL,1.00),('revolvercylinder','Revolver Cylinder',5,1,'item_standard',1,0,573,1,1,'{}','A replacement cylinder for a revolver firearm, which holds the ammunition.',0,NULL,NULL,1.00),('revolverhandle','Revolver Handle',5,1,'item_standard',1,0,574,1,1,'{}','A replacement handle for a revolver firearm, providing grip and control.',0,NULL,NULL,1.00),('revolvermold','Revolver Mold',5,1,'item_standard',1,0,575,1,1,'{}','A mold used for casting the components of a revolver firearm.',0,NULL,NULL,1.00),('ridcof','Ridged Coffin',25,1,'item_standard',0,0,2556,1,1,'{}','nice item',0,NULL,NULL,1.00),('riflebarrel','Rifle Barrel',25,1,'item_standard',1,0,576,1,1,'{}','A replacement barrel for a rifle firearm, used for improving accuracy and performance.',0,NULL,NULL,1.00),('riflemold','Rifle Mold',5,1,'item_standard',1,0,577,1,1,'{}','A mold used for casting the components of a rifle firearm.',0,NULL,NULL,1.00),('riflereceiver','Rifle Receiver',5,1,'item_standard',1,0,578,1,1,'{}','A replacement receiver for a rifle firearm, which houses the firing mechanism.',0,NULL,NULL,1.00),('riflerecmold','Rifle Receiver Mold',5,1,'item_standard',1,0,579,1,1,'{}','A mold used for casting the receiver of a rifle firearm.',0,NULL,NULL,1.00),('riflestock','Rifle Stock',5,1,'item_standard',1,0,580,1,1,'{}','A replacement stock for a rifle firearm, providing stability and control.',0,NULL,NULL,1.00),('roach','Roach',10,1,'item_standard',0,0,581,1,1,'{}','A small insect commonly found in households and other environments.',0,NULL,NULL,1.00),('robberyplanning','Robbery Planning Set',20,1,'item_standard',1,0,582,1,1,'{}','A set of tools and materials used for planning a robbery or heist.',0,NULL,NULL,1.00),('robbery_ledger','Robbery Ledger',5,1,'item_standard',0,0,4860,1,1,'{}','A book containing records of houses and valuable targets.',0,NULL,NULL,1.00),('robin_c','Robin',20,1,'item_standard',1,0,583,1,1,'{}','A whole robin, red breast and all.',0,NULL,NULL,0.10),('rocan','Rock Candy',25,1,'item_standard',1,0,2248,1,1,'{}','nice item',0,NULL,NULL,1.00),('rock','Rock',30,1,'item_standard',0,0,584,1,1,'{}','A solid mineral material that forms the Earths crust, commonly found in various shapes and sizes.',0,NULL,NULL,1.00),('rollingpaper','Rolling paper',30,1,'item_standard',1,0,585,1,1,'{}','A thin, lightweight paper used for rolling cigarettes or other smoking materials.',0,NULL,NULL,1.00),('rooouthou','Rooouthou',25,1,'item_standard',0,0,2597,1,1,'{}','nice item',0,NULL,NULL,1.00),('rosebloom_cigar','Rosebloom Cigar',10,1,'item_standard',1,0,6646,1,1,'{}','A finely hand-rolled cigar made from rich, aged tobacco and finished with a delicate touch of rose.',0,NULL,NULL,1.00),('rounclotabb','Carvis Round Cloth Table',25,1,'item_standard',0,0,2702,1,1,'{}','nice item',0,NULL,NULL,1.00),('roundtable','Round Table',20,1,'item_standard',1,0,586,1,1,'{}','A circular table with a flat top surface, often used for dining or discussions.',0,NULL,NULL,1.00),('round_table','Round Table',20,1,'item_standard',1,0,587,1,1,'{}','A table with a round top surface, typically used for dining or meetings.',0,NULL,NULL,1.00),('roybed','Roybed',25,1,'item_standard',0,0,2759,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpblacksoulgem','Black Soul Gem',25,1,'item_standard',1,0,2167,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpdencasinochip','Den Casino Chip',25,1,'item_standard',0,0,2489,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt1','Rpelt1',25,1,'item_standard',0,0,2495,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt10','Rpelt10',25,1,'item_standard',0,0,2769,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt11','Rpelt11',25,1,'item_standard',0,0,2757,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt12','Rpelt12',25,1,'item_standard',0,0,2440,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt13','Rpelt13',25,1,'item_standard',0,0,2479,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt2','Rpelt2',25,1,'item_standard',0,0,2748,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt3','Rpelt3',25,1,'item_standard',0,0,2665,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt4','Rpelt4',25,1,'item_standard',0,0,2717,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt5','Rpelt5',25,1,'item_standard',0,0,2516,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt6','Rpelt6',25,1,'item_standard',0,0,2741,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt7','Rpelt7',25,1,'item_standard',0,0,2494,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt8','Rpelt8',25,1,'item_standard',0,0,2500,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpelt9','Rpelt9',25,1,'item_standard',0,0,2487,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpitemcallingcard','Calling Card',25,1,'item_standard',0,0,2593,1,1,'{}','nice item',0,NULL,NULL,1.00),('rpiteminvitation','Invitation',25,1,'item_standard',0,0,2443,1,1,'{}','nice item',0,NULL,NULL,1.00),('rplessersoulgem','Lesser Soul Gem',25,1,'item_standard',1,0,2168,1,1,'{}','nice item',0,NULL,NULL,1.00),('rspoonb','Spoonbill Beak',25,1,'item_standard',1,0,588,1,1,'{}','The flat, spoon-ended beak of a spoonbill.',0,NULL,NULL,0.05),('rspoonf','Spoonbill Plume',50,1,'item_standard',1,0,589,1,1,'{}','A pink plume from a roseate spoonbill.',0,NULL,NULL,0.05),('rubbag','Rubble Bag',25,1,'item_standard',0,0,2760,1,1,'{}','nice item',0,NULL,NULL,1.00),('rubber','Rubber',50,1,'item_standard',0,0,590,1,1,'{}','A flexible, elastic material derived from the sap of certain plants or synthesized chemically.',0,NULL,NULL,1.00),('rubbertube','Rubber Tube',10,1,'item_standard',0,0,591,1,1,'{}','A cylindrical tube made of rubber, commonly used for various applications such as plumbing or medical procedures.',0,NULL,NULL,1.00),('ruby','Ruby',50,1,'item_standard',0,0,4852,1,1,'{}','A blood red ruby.',0,NULL,NULL,1.00),('rum','Rum',25,1,'item_standard',1,0,2120,1,1,'{}','nice item',0,NULL,NULL,1.00),('ruswechar','Wood Log Chair',25,1,'item_standard',0,0,2537,1,1,'{}','nice item',0,NULL,NULL,1.00),('saber03','Dancer\'s Sabre',1,1,'item_standard',1,0,1503,1,5,'{}','A blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('salamelle','Fresh Pork ',20,1,'item_standard',1,0,592,1,1,'{}','Fresh pork salamelle',0,NULL,NULL,1.00),('salesod','Sparkling Lemon Soda',25,1,'item_standard',1,0,2059,1,1,'{}','nice item',0,NULL,NULL,1.00),('salmon','Salmon',10,1,'item_standard',0,0,593,1,1,'{}','Fresh salmon',0,NULL,NULL,1.00),('salt','Salt',50,1,'item_standard',0,0,594,1,1,'{}','Common salt',0,NULL,NULL,1.00),('Saltbush','Saltbush',10,1,'item_standard',1,0,595,1,1,'{}','Saltbush plant',0,NULL,NULL,1.00),('Saltbush_Seed','Saltbush Seed',50,1,'item_standard',1,0,596,1,1,'{}','Seed of Saltbush plant',0,NULL,NULL,1.00),('sandbag','Sandbag',10,1,'item_standard',1,0,928,1,1,'{}','A bag of sand. often used in construction.',0,NULL,NULL,1.00),('sandpaper','Sandpaper',10,1,'item_standard',1,0,929,1,1,'{}','A sheet of sandpaper used for smoothing wood.',0,NULL,NULL,1.00),('sap','Sap',50,1,'item_standard',0,0,597,1,1,'{}','Sticky sap',0,NULL,NULL,1.00),('sapphire','Sapphire',50,1,'item_standard',0,0,4853,1,1,'{}','A deep blue sapphire.',0,NULL,NULL,1.00),('sarsa','Sarsaprilla',25,1,'item_standard',1,0,2050,1,1,'{}','nice item',0,NULL,NULL,1.00),('sarsaparilla','Sarsaparilla',10,1,'item_standard',1,0,598,1,1,'{}','Medicinal sarsaparilla',0,NULL,NULL,1.00),('satchels','Satchels',50,1,'item_standard',1,0,1453,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('satin_bloom','Satin Bloom',15,1,'item_standard',1,0,6650,1,1,'{}','A delicately crafted bar of soap made with rich oils, fragrant rose petals, and a touch of lavender.',0,NULL,NULL,1.00),('savtable','Savage Table',25,1,'item_standard',0,0,2535,1,1,'{}','nice item',0,NULL,NULL,1.00),('scale','Scale',5,1,'item_standard',1,0,599,1,1,'{}','Measuring scale',0,NULL,NULL,1.00),('scavtent','Scavenger Tent',25,1,'item_standard',0,0,2744,1,1,'{}','nice item',0,NULL,NULL,1.00),('scentg','Scent Gland',25,1,'item_standard',1,0,600,1,1,'{}','A small, foul gland. Trappers mix it into lures.',0,NULL,NULL,0.05),('scrambledeggs','Scrambled Eggs',25,1,'item_standard',1,0,2016,1,1,'{}','nice item',0,NULL,NULL,1.00),('scrambledeggsbacon','Scrambled Eggs with Bacon',25,1,'item_standard',1,0,2017,1,1,'{}','nice item',0,NULL,NULL,1.00),('scythe','Scythe',1,1,'item_standard',1,0,1529,1,5,'{}','A blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('seafood_gumbo','Seafood Gumbo',25,1,'item_standard',1,0,17148,3,1,'{}','A bowl of it will keep you going all day.',0,NULL,NULL,1.00),('seagullb','Gull Beak',25,1,'item_standard',1,0,601,1,1,'{}','A yellow beak from a gull.',0,NULL,NULL,0.05),('seagullf','Gull Feather',50,1,'item_standard',1,0,602,1,1,'{}','A grey and white feather from a gull.',0,NULL,NULL,0.05),('sealedpackage','Sealed Package',20,1,'item_standard',0,0,33456,1,1,'{}','A tightly bound parcel. Nobody is saying what is inside.',0,NULL,NULL,1.00),('secondchance','Second Chance',10,1,'item_standard',1,0,603,1,1,'{}','A fresh start. Use it to remake your face, body and hair wherever you stand - height stays as it is.',0,NULL,NULL,1.00),('secrhuthh','Secretary Hutch',25,1,'item_standard',0,0,2574,1,1,'{}','nice item',0,NULL,NULL,1.00),('sendes','Sentinel Desk',20,1,'item_standard',1,0,4392,1,1,'{}','nice item',0,NULL,NULL,1.00),('sheephead','Sheep Skull',25,1,'item_standard',1,0,604,1,1,'{}','A cleaned sheep skull.',0,NULL,NULL,0.50),('shellcasing','Shell Casing',50,1,'item_standard',1,0,605,1,1,'{}','Empty shell casing',0,NULL,NULL,1.00),('sher','Sherry',25,1,'item_standard',1,0,2251,1,1,'{}','nice item',0,NULL,NULL,1.00),('shirts_full','Shirts',50,1,'item_standard',1,0,1466,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('shitter','Chamber Pot',25,1,'item_standard',0,0,2542,1,1,'{}','nice item',0,NULL,NULL,1.00),('shootingtarget','Shooting Target',20,1,'item_standard',1,0,606,1,1,'{}','Target for shooting practice',0,NULL,NULL,1.00),('shoptoken','Shop Creation License',5,1,'item_standard',1,0,1138,1,1,'{}','nice item',0,NULL,NULL,1.00),('shotgunbarrel','Shotgun Barrel',25,1,'item_standard',1,0,607,1,1,'{}','Barrel for a shotgun',0,NULL,NULL,1.00),('shotgunmold','Shotgun Mold',5,1,'item_standard',1,0,608,1,1,'{}','Mold for a shotgun',0,NULL,NULL,1.00),('shotgunstock','Shotgun Stock',5,1,'item_standard',1,0,609,1,1,'{}','Stock for a shotgun',0,NULL,NULL,1.00),('shovel','Shovel',20,1,'item_standard',1,0,1235,1,1,'{}','nice item',0,100,NULL,1.00),('shovel_weapon','Shovel',1,1,'item_standard',1,0,1530,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,100,NULL,1.00),('shrimps','Shrimp Stew',1,1,'item_standard',1,0,610,1,1,'{}','Delicious shrimp stew',0,NULL,NULL,1.00),('sidetable','side table 1',20,1,'item_standard',1,0,611,1,1,'{}','Functional side table',0,NULL,NULL,1.00),('sidetablea','side table 2',20,1,'item_standard',1,0,612,1,1,'{}','Stylish side table',0,NULL,NULL,1.00),('sidetableb','side table 3',20,1,'item_standard',1,0,613,1,1,'{}','A beautiful side table',0,NULL,NULL,1.00),('side_table','side table 1',20,1,'item_standard',1,0,614,1,1,'{}','A stylish side table',0,NULL,NULL,1.00),('side_tablea','side table 2',20,1,'item_standard',1,0,615,1,1,'{}','An elegant side table',0,NULL,NULL,1.00),('side_tableb','side table 3',20,1,'item_standard',1,0,616,1,1,'{}','A modern side table',0,NULL,NULL,1.00),('silchar','Linen Chair',25,1,'item_standard',0,0,2652,1,1,'{}','nice item',0,NULL,NULL,1.00),('silver_ring','Silver Ring',50,1,'item_standard',0,0,4840,1,1,'{}','A simple silver ring.',0,NULL,NULL,1.00),('simplenativetent','Simple Native Tent',20,1,'item_standard',1,0,1387,1,1,'{}','nice item',0,NULL,NULL,1.00),('simtabb','Simple Table',25,1,'item_standard',0,0,2625,1,1,'{}','nice item',0,NULL,NULL,1.00),('sincan','Single Candle',25,1,'item_standard',0,0,2672,1,1,'{}','nice item',0,NULL,NULL,1.00),('singlebed','single bed',20,1,'item_standard',1,0,617,1,1,'{}','A comfortable single bed',0,NULL,NULL,1.00),('siphopure','Siphoned Pure',25,1,'item_standard',1,0,2445,1,1,'{}','nice item',0,NULL,NULL,1.00),('skinner_wep','Skinner\'s Knife',1,1,'item_standard',1,0,30517,1,1,'{}','A short blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('skinning_knife','Skinning Knife',25,1,'item_standard',0,0,2747,1,1,'{}','nice item',0,NULL,NULL,1.00),('skirts','Skirts',50,1,'item_standard',1,0,1447,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('skull','Skull',25,1,'item_standard',0,0,2577,1,1,'{}','nice item',0,NULL,NULL,1.00),('skullpost','Skull Post',20,1,'item_standard',1,0,618,1,1,'{}','A decorative skull post',0,NULL,NULL,1.00),('smalblacab','Black & Brown Dresser',25,1,'item_standard',0,0,2659,1,1,'{}','nice item',0,NULL,NULL,1.00),('smallchest','Small Chest',1,1,'item_standard',1,0,619,1,1,'{}','A small storage chest',0,NULL,NULL,1.00),('smallmcandle','Small Melted Candle',20,1,'item_standard',1,0,620,1,1,'{}','A small melted candle',0,NULL,NULL,1.00),('Small_Leather','Small Leather',10,1,'item_standard',1,0,621,1,1,'{}','A small piece of leather',0,NULL,NULL,1.00),('smolbout','Small Bounty Tent',25,1,'item_standard',0,0,2465,1,1,'{}','nice item',0,NULL,NULL,1.00),('smolcan','Cup Candle',25,1,'item_standard',0,0,2658,1,1,'{}','nice item',0,NULL,NULL,1.00),('smolcovbed','Small Fancy Bed',25,1,'item_standard',0,0,2666,1,1,'{}','nice item',0,NULL,NULL,1.00),('smolirodres','Small Engraved Dresser',25,1,'item_standard',0,0,2559,1,1,'{}','nice item',0,NULL,NULL,1.00),('smolmed','Small Med Box',25,1,'item_standard',0,0,2475,1,1,'{}','nice item',0,NULL,NULL,1.00),('Smolvau','Smolvau',25,1,'item_standard',0,0,2523,1,1,'{}','nice item',0,NULL,NULL,1.00),('snakeoil','Snake Oil',20,1,'item_standard',1,0,7755,1,1,'{}','Exactly what it says on the bottle.',0,NULL,NULL,1.00),('SnakeSkin','Snake Skin',20,1,'item_standard',1,0,622,1,1,'{}','A snake skin',0,NULL,NULL,1.00),('snaket','Snake tooth',20,1,'item_standard',1,0,623,1,1,'{}','A tooth from a snake',0,NULL,NULL,1.00),('Snake_Poison','Snake Venom',25,1,'item_standard',1,0,624,1,1,'{}','A small vial of venom milked from a snake.',0,NULL,NULL,0.05),('soborno','Soborno Alcohol',15,1,'item_standard',0,0,625,1,1,'{}','A bottle of Soborno alcohol',0,NULL,NULL,1.00),('societytoken','Society Shop Creation License',5,1,'item_standard',1,0,1137,1,1,'{}','nice item',0,NULL,NULL,1.00),('songbird2_c','Scarlet songbird',20,1,'item_standard',1,0,626,1,1,'{}','A beautiful scarlet songbird',0,NULL,NULL,1.00),('songbird_c','Songbird',20,1,'item_standard',1,0,627,1,1,'{}','A whole songbird, small and bright.',0,NULL,NULL,0.10),('sour_souls','Sour Souls',25,1,'item_standard',1,0,16473,3,4,'{}','They scream on the way down.',0,NULL,NULL,1.00),('spade_wep','Grave Spade',1,1,'item_standard',1,0,30511,1,1,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('spaghetti','Spaghetti with Meatballs',25,1,'item_standard',1,0,2040,1,1,'{}','nice item',0,NULL,NULL,1.00),('sparrow0_c','Common Sparrow',20,1,'item_standard',1,0,628,1,1,'{}','A common sparrow',0,NULL,NULL,1.00),('sparrow1_c','Sparrow',20,1,'item_standard',1,0,629,1,1,'{}','A whole sparrow.',0,NULL,NULL,0.10),('sparrow2_c','Golden Sparrow',20,1,'item_standard',1,0,630,1,1,'{}','A golden sparrow',0,NULL,NULL,1.00),('spats','Spats',50,1,'item_standard',1,0,1456,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('specchar','Serious Chair',25,1,'item_standard',0,0,2534,1,1,'{}','nice item',0,NULL,NULL,1.00),('specialbracelets','Bracelet',50,1,'item_standard',1,0,1479,1,1,'{}','A premium bracelet. Use to wear it.',0,NULL,NULL,1.00),('specialdresses','Dress',50,1,'item_standard',1,0,1478,1,1,'{}','A premium dress. Use to wear it.',0,NULL,NULL,1.00),('specialfancysuit','Fancy Suit',50,1,'item_standard',1,0,1475,1,1,'{}','A premium suit. Use to wear it.',0,NULL,NULL,1.00),('specialfemalepack','Female Outfit',50,1,'item_standard',1,0,1476,1,1,'{}','A premium female outfit. Use to wear it.',0,NULL,NULL,1.00),('specialgloves','Gloves',50,1,'item_standard',1,0,1481,1,1,'{}','Premium gloves. Use to wear them.',0,NULL,NULL,1.00),('specialhats','Hat',50,1,'item_standard',1,0,1482,1,1,'{}','A premium hat. Use to wear it.',0,NULL,NULL,1.00),('specialmalepack','Male Outfit',50,1,'item_standard',1,0,1477,1,1,'{}','A premium male outfit. Use to wear it.',0,NULL,NULL,1.00),('specialNativeAccessoryMen','Native Accessory (M)',50,1,'item_standard',1,0,1484,1,1,'{}','A premium native accessory. Use to wear it.',0,NULL,NULL,1.00),('specialNativeAccessoryWomen','Native Accessory (F)',50,1,'item_standard',1,0,1483,1,1,'{}','A premium native accessory. Use to wear it.',0,NULL,NULL,1.00),('specialNativeHairMen','Native Hair (M)',50,1,'item_standard',1,0,1486,1,1,'{}','A premium native hairstyle. Use to wear it.',0,NULL,NULL,1.00),('specialNativeHairWomen','Native Hair (F)',50,1,'item_standard',1,0,1485,1,1,'{}','A premium native hairstyle. Use to wear it.',0,NULL,NULL,1.00),('specialNativeMenOutfit','Native Outfit (M)',50,1,'item_standard',1,0,1488,1,1,'{}','A premium native outfit. Use to wear it.',0,NULL,NULL,1.00),('specialNativeWomenOutfit','Native Outfit (F)',50,1,'item_standard',1,0,1487,1,1,'{}','A premium native outfit. Use to wear it.',0,NULL,NULL,1.00),('specialnecklaces','Necklace',50,1,'item_standard',1,0,1480,1,1,'{}','A premium necklace. Use to wear it.',0,NULL,NULL,1.00),('specialpelt','Special Pelt',10,1,'item_standard',0,0,32440,1,1,'{}','nice item',0,NULL,NULL,1.00),('specschar','Specschar',25,1,'item_standard',0,0,2630,1,1,'{}','nice item',0,NULL,NULL,1.00),('spool','Spool',10,1,'item_standard',1,0,930,1,1,'{}','A empty spool. often used to wrap wire around.',0,NULL,NULL,1.00),('spoonavi','Warning Post',25,1,'item_standard',0,0,2616,1,1,'{}','nice item',0,NULL,NULL,1.00),('squirrel_black_c','Black Squirrel',20,1,'item_standard',1,0,631,1,1,'{}','A black squirrel',0,NULL,NULL,1.00),('squirrel_grey_c','Squirrel',20,1,'item_standard',1,0,632,1,1,'{}','A whole squirrel, good for a pot of stew.',0,NULL,NULL,0.30),('squirrel_red_c','Red Squirrel',20,1,'item_standard',1,0,633,1,1,'{}','A Red squirrel',0,NULL,NULL,1.00),('stake01','Wooden Stake',1,1,'item_standard',1,0,1519,1,5,'{}','A short blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('stake02','Metal Stake',1,1,'item_standard',1,0,1520,1,5,'{}','A short blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('stake_wooden','Sharpened Stake',1,1,'item_standard',1,0,22146,1,5,'{}','A short blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('standard_table','Table',20,1,'item_standard',1,0,634,1,1,'{}','A standard table for various uses.',0,NULL,NULL,1.00),('standingtorch','Standing Torch',20,1,'item_standard',1,0,635,1,1,'{}','A standing torch to provide light.',0,NULL,NULL,1.00),('stanouthou','Stanouthou',25,1,'item_standard',0,0,2599,1,1,'{}','nice item',0,NULL,NULL,1.00),('stantor','Standing Torch',25,1,'item_standard',0,0,2680,1,1,'{}','nice item',0,NULL,NULL,1.00),('steak','Steak',10,1,'item_standard',1,0,636,1,1,'{}','A delicious steak for a hearty meal.',0,NULL,NULL,1.00),('steakveg','Steak with Veggies',10,1,'item_standard',1,0,637,1,1,'{}','A balanced meal with steak and vegetables.',0,NULL,NULL,1.00),('steak_and_mashers','Steak and Mashers',10,1,'item_standard',1,0,5280,1,1,'{}','Pan seared steak cooked with butter and thyme and a side of buttery mashed potatoes.',0,NULL,NULL,1.00),('stick_wep','Walking Stick',1,1,'item_standard',1,0,30514,1,1,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('stikchar','Stick Log Chair',25,1,'item_standard',0,0,29013,1,1,'{}','nice item',0,NULL,NULL,1.00),('stiklogchar','Small Wood Log Chair',25,1,'item_standard',0,0,2538,1,1,'{}','nice item',0,NULL,NULL,1.00),('stiktent','Stick Tent',25,1,'item_standard',0,0,2602,1,1,'{}','nice item',0,NULL,NULL,1.00),('stillkit','Still Kit',10,1,'item_standard',1,0,638,1,1,'{}','A kit for setting up a still to make distilled spirits.',0,NULL,NULL,1.00),('stim','Horse Meds',50,1,'item_standard',1,0,639,1,1,'{}','A Horse Meds to boost a horses performance.',0,NULL,NULL,1.00),('stim2','Weak Horse Stimulant',50,1,'item_standard',1,0,1965,1,1,'{}','nice item',0,NULL,NULL,1.00),('stiskul','Skull Stick',25,1,'item_standard',0,0,2615,1,1,'{}','nice item',0,NULL,NULL,1.00),('stolenmerch','Stolen Items',20,1,'item_standard',0,0,640,1,1,'{}','Various stolen items of questionable origin.',0,NULL,NULL,1.00),('stolen_goods','Stolen Goods',25,1,'item_standard',0,0,2464,1,1,'{}','nice item',0,NULL,NULL,1.00),('stonehammer','Stone Hammer',5,1,'item_standard',1,0,641,1,1,'{}','A durable hammer made of stone.',0,NULL,NULL,1.00),('stoo','Stoo',25,1,'item_standard',0,0,2669,1,1,'{}','nice item',0,NULL,NULL,1.00),('stoonavi','Horn Stool',25,1,'item_standard',0,0,2621,1,1,'{}','nice item',0,NULL,NULL,1.00),('storage_box_1000','Storage Box',10,1,'item_standard',1,0,1835,1,1,'{}','A portable storage box. Holds up to 1000 item slots.',0,NULL,NULL,1.00),('stordes','Organize Desk',25,1,'item_standard',0,0,2755,1,1,'{}','nice item',0,NULL,NULL,1.00),('strawberry','Strawberry',50,1,'item_standard',1,0,1983,1,1,'{}','nice item',0,NULL,NULL,1.00),('strawsugar','Sugar Strawberry',25,1,'item_standard',1,0,2116,1,1,'{}','nice item',0,NULL,NULL,1.00),('string','String',50,1,'item_standard',1,0,931,1,1,'{}','A bundle of string with many uses.',0,NULL,NULL,1.00),('stringy','Stringy Meat',20,1,'item_standard',1,0,642,1,1,'{}','Gristly scraps that need long cooking. Scavengers are not so fussy.',0,NULL,NULL,0.50),('strinhash','Stringy Meat Hash',25,1,'item_standard',1,0,2078,1,1,'{}','nice item',0,NULL,NULL,1.00),('sugar','Sugar',50,1,'item_standard',0,0,643,1,1,'{}','Pressed from cane and boiled down. Sweetens coffee, baking and moonshine.',0,NULL,NULL,1.00),('sugarcaneseed','Sugarcane Seed',50,1,'item_standard',1,0,644,1,1,'{}','Cane cuttings for planting. Harvest it for sugar.',0,NULL,NULL,1.00),('sugarcube','Sugar Cube',10,1,'item_standard',1,0,645,1,1,'{}','A compact form of sugar for easy use.',0,NULL,NULL,1.00),('sugarsak','Sugar Sack',25,1,'item_standard',0,0,2732,1,1,'{}','nice item',0,NULL,NULL,1.00),('sulfur','Sulfur',30,1,'item_standard',0,0,646,1,1,'{}','A yellow chemical element often used in manufacturing.',0,NULL,NULL,1.00),('suspenders','Suspenders',50,1,'item_standard',1,0,1465,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('sword03','Warrior\'s Sword',1,1,'item_standard',1,0,1498,1,5,'{}','A blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('sword04','Pirate\'s Cutlass',1,1,'item_standard',1,0,1499,1,5,'{}','A blade carried on the body. Use it to take it out or put it away.',0,NULL,NULL,1.00),('syringe','Syringe',20,1,'item_standard',1,0,649,1,1,'{}','A medical instrument used for injecting fluids.',0,NULL,NULL,1.00),('syringecert','Syringe Cert',10,1,'item_standard',1,0,651,1,1,'{}','A certification for the proper use of syringes.',0,NULL,NULL,1.00),('syringe_2','Syringe',20,1,'item_standard',1,0,650,1,1,'{}','A medical instrument used for injecting fluids.',0,NULL,NULL,1.00),('tallstnchar','Tall Standing Chair',25,1,'item_standard',0,0,2586,1,1,'{}','nice item',0,NULL,NULL,1.00),('tankertonic','Tanker Tonic',20,1,'item_standard',1,0,7760,1,1,'{}','Built for men who take a beating.',0,NULL,NULL,1.00),('tanntent','Tanner Tent',25,1,'item_standard',0,0,2686,1,1,'{}','nice item',0,NULL,NULL,1.00),('tbweapon','Field Detector',1,1,'item_standard',1,0,22151,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('tea','Tea',25,1,'item_standard',1,0,2034,1,1,'{}','nice item',0,NULL,NULL,1.00),('teabag','Teabag',10,1,'item_standard',1,0,932,1,1,'{}','A teabag for making that perfect cup.',0,NULL,NULL,1.00),('teabritish','British Tea',25,1,'item_standard',1,0,2036,1,1,'{}','nice item',0,NULL,NULL,1.00),('tealeaf','Tea Leaf',50,1,'item_standard',1,0,933,1,1,'{}','Fresh leaves to dry and brew into a proper cup of tea.',0,NULL,NULL,1.00),('teaseeds','Tea Seeds',50,1,'item_standard',1,0,2830,1,1,'{}','Seed for a tea bush.',0,NULL,NULL,1.00),('teasugar','Tea with Sugar',25,1,'item_standard',1,0,2035,1,1,'{}','nice item',0,NULL,NULL,1.00),('teddy_hot_chocolate','Teddy Bear Hot Chocolate',25,1,'item_standard',1,0,17149,3,1,'{}','Topped with a little bear that melts as you drink.',0,NULL,NULL,1.00),('tent','Tent',1,1,'item_standard',1,0,652,1,1,'{}','A portable shelter for camping or temporary use.',0,NULL,NULL,1.00),('tent2','Trader Tent',20,1,'item_standard',1,0,653,1,1,'{}','A tent specifically designed for trading purposes.',0,NULL,NULL,1.00),('tent3','Simple Tent',20,1,'item_standard',1,0,654,1,1,'{}','A basic tent for camping.',0,NULL,NULL,1.00),('tent4','Canvas Shade',20,1,'item_standard',1,0,655,1,1,'{}','A canvas shade for shelter.',0,NULL,NULL,1.00),('tequila','Tequila',10,1,'item_standard',1,0,656,1,1,'{}','A bottle of tequila.',0,NULL,NULL,1.00),('Texas_Bonnet','Texas Bonnet',10,1,'item_standard',1,0,657,1,1,'{}','A traditional Texas bonnet.',0,NULL,NULL,1.00),('Texas_Bonnet_Seed','Texas Bonnet Seed',50,1,'item_standard',1,0,658,1,1,'{}','Seeds to grow Texas Bonnet flowers.',0,NULL,NULL,1.00),('theaches','Theater Chest',25,1,'item_standard',0,0,2606,1,1,'{}','nice item',0,NULL,NULL,1.00),('theaspecchar','Upholstery Chair',25,1,'item_standard',0,0,2703,1,1,'{}','nice item',0,NULL,NULL,1.00),('theatabb','Private Animal Table',25,1,'item_standard',0,0,2624,1,1,'{}','nice item',0,NULL,NULL,1.00),('thickelixir','Thick Elixir',20,1,'item_standard',1,0,7759,1,1,'{}','Barely pours. Barely legal.',0,NULL,NULL,1.00),('timber','Timber',10,1,'item_standard',1,0,934,1,1,'{}','A sturdy chunck of timber.',0,NULL,NULL,1.00),('timbertable','Timber Table',20,1,'item_standard',1,0,659,1,1,'{}','A sturdy table made of timber.',0,NULL,NULL,1.00),('timber_table','Timber Table',20,1,'item_standard',1,0,660,1,1,'{}','A table made of timber.',0,NULL,NULL,1.00),('tintent','Tin Tent',25,1,'item_standard',0,0,2644,1,1,'{}','nice item',0,NULL,NULL,1.00),('tipi','Native Tipi',20,1,'item_standard',1,0,661,1,1,'{}','A traditional Native American tipi.',0,NULL,NULL,1.00),('toaddesert_c','Desert Toad',20,1,'item_standard',1,0,662,1,1,'{}','A toad found in the desert.',0,NULL,NULL,1.00),('toadpoison_c','Poisoned Toad',20,1,'item_standard',1,0,663,1,1,'{}','A toad that carries poison.',0,NULL,NULL,1.00),('toad_c','Toad',20,1,'item_standard',1,0,664,1,1,'{}','A whole toad. Wash your hands after.',0,NULL,NULL,0.10),('tof','Toffee',25,1,'item_standard',1,0,2249,1,1,'{}','nice item',0,NULL,NULL,1.00),('token','Camp License',5,1,'item_standard',1,0,665,1,1,'{}','A license for setting up a camp.',0,NULL,NULL,1.00),('tomato1','Tomato',50,1,'item_standard',1,0,1981,1,1,'{}','nice item',0,NULL,NULL,1.00),('tombchili','Tombstone Chili',25,1,'item_standard',1,0,2065,1,1,'{}','nice item',0,NULL,NULL,1.00),('toolbarrel','Tool Barrel',20,1,'item_standard',1,0,666,1,1,'{}','A barrel for storing tools.',0,NULL,NULL,1.00),('tool_barrel','Tool Barrel',20,1,'item_standard',1,0,667,1,1,'{}','A barrel used for storing tools.',0,NULL,NULL,1.00),('tooth_gold','Gold Tooth',50,1,'item_standard',0,0,4858,1,1,'{}','A golden tooth pulled from... somewhere.',0,NULL,NULL,1.00),('traima','Train Map',25,1,'item_standard',0,0,2677,1,1,'{}','nice item',0,NULL,NULL,1.00),('trainkey','Train Key',1,1,'item_standard',1,0,668,1,1,'{}','A key to unlock a train.',0,NULL,NULL,1.00),('trainticket','Train Ticket',25,1,'item_standard',0,0,2517,1,1,'{}','nice item',0,NULL,NULL,1.00),('trapoil','Trap Oil',20,1,'item_standard',0,0,5529,1,1,'{}','A tin of thin oil for keeping trap springs from rusting.',0,NULL,NULL,0.20),('trayoffood','Serving Table',20,1,'item_standard',1,0,669,1,1,'{}','A table used for serving food.',0,NULL,NULL,1.00),('tremir','Carved Mirror',25,1,'item_standard',0,0,2463,1,1,'{}','nice item',0,NULL,NULL,1.00),('trilam','Trilam',25,1,'item_standard',0,0,2582,1,1,'{}','nice item',0,NULL,NULL,1.00),('tripcan','Fancy Candle',25,1,'item_standard',0,0,2512,1,1,'{}','nice item',0,NULL,NULL,1.00),('tropicalPunchMash','Ginseng Mash',10,1,'item_standard',0,0,670,1,1,'{}','A mash made from ginseng.',0,NULL,NULL,1.00),('tropicalPunchMoonshine','Ginseng Moonshine',10,1,'item_standard',1,0,671,1,1,'{}','Moonshine infused with ginseng.',0,NULL,NULL,1.00),('trout','Trout',10,1,'item_standard',0,0,672,1,1,'{}','A fish of the trout family.',0,NULL,NULL,1.00),('turkeyb','Turkey Beak',25,1,'item_standard',1,0,673,1,1,'{}','A short beak from a turkey.',0,NULL,NULL,0.05),('turkeyf','Turkey Feather',50,1,'item_standard',1,0,674,1,1,'{}','A banded tail feather from a turkey.',0,NULL,NULL,0.02),('turtleshell','Turtle Shell',10,1,'item_standard',1,0,675,1,1,'{}','A domed turtle shell, used for combs and buttons.',0,NULL,NULL,1.00),('turtlet','Turtle Beak',25,1,'item_standard',1,0,676,1,1,'{}','The hard, hooked beak of a turtle.',0,NULL,NULL,0.05),('tylenol','Tylenol',10,1,'item_standard',1,0,677,1,1,'{}','A medication called Tylenol.',0,NULL,NULL,1.00),('undertaker1','Coffin',20,1,'item_standard',1,0,678,1,1,'{}','A wooden coffin.',0,NULL,NULL,1.00),('undertaker2','Flower Coffin',20,1,'item_standard',1,0,679,1,1,'{}','A coffin decorated with flowers.',0,NULL,NULL,1.00),('UniAppleCider','Apple Cider',25,1,'item_standard',1,0,2165,1,1,'{}','nice item',0,NULL,NULL,1.00),('unique_brad_horsesugar','Brad Horse Sugar',5,1,'item_standard',1,0,680,1,1,'{}','Sugar used for horses owned by Brad.',0,NULL,NULL,1.00),('unique_happy_shot','Dr. Honey\'s Happy Shot',20,1,'item_standard',1,0,7762,1,1,'{}','Honey by name only.',0,NULL,NULL,1.00),('unique_helper','Unique Helper',5,1,'item_standard',1,0,2835,1,1,'{}','nice item',0,NULL,NULL,1.00),('unique_horsesupp','Horse Supplement',10,1,'item_standard',1,0,1966,1,1,'{}','nice item',0,NULL,NULL,1.00),('unique_horse_feed','Horse Feed',5,1,'item_standard',1,0,681,1,1,'{}','Feed for horses.',0,NULL,NULL,1.00),('unique_saline','Saline Bottle',20,1,'item_standard',1,0,7745,1,1,'{}','Sterile saline for rehydration.',0,NULL,NULL,1.00),('unique_shoot','Dr.Nixie\'s Liquid Cocaine',20,1,'item_standard',1,0,7744,1,1,'{}','Medically certified. Allegedly.',0,NULL,NULL,1.00),('unique_sock','Dirty Socks',20,1,'item_standard',1,0,7750,1,1,'{}','It is not clean, but it is absorbent.',0,NULL,NULL,1.00),('unique_straightrazor','Straight Razor',25,1,'item_standard',0,0,2705,1,1,'{}','nice item',0,NULL,NULL,1.00),('unique_tigerbalm','Tigerbalm',20,1,'item_standard',1,0,7761,1,1,'{}','Warms the muscle and clears the head.',0,NULL,NULL,1.00),('UniTurkyleg','Turkey Leg',25,1,'item_standard',1,0,2166,1,1,'{}','nice item',0,NULL,NULL,1.00),('uphcouc','Upholstery Couch',25,1,'item_standard',0,0,2548,1,1,'{}','nice item',0,NULL,NULL,1.00),('valubox','Valuable Loot Crate',25,1,'item_standard',0,0,2474,1,1,'{}','nice item',0,NULL,NULL,1.00),('vampkey','Mysterious Key',25,1,'item_standard',0,0,2481,1,1,'{}','nice item',0,NULL,NULL,1.00),('vanagandr','Vanagandr',1,1,'item_standard',1,0,3862,1,5,'{}','Silver-pale and cold to look at. Runs ahead of the storms.',0,NULL,NULL,1.00),('vanillacake','Vanilla Cake',10,1,'item_standard',1,0,935,1,1,'{}','A tasty vanilla flavored cake.',0,NULL,NULL,1.00),('vanillaFlower','Vanille Flower',20,1,'item_standard',0,0,682,1,1,'{}','A flower known as Vanille.',0,NULL,NULL,1.00),('varnish','Varnish',10,1,'item_standard',1,0,936,1,1,'{}','A typical wood finish made from oils and resins.',0,NULL,NULL,1.00),('venison','Venison',20,1,'item_standard',1,0,683,1,1,'{}','Lean meat obtained from deer.',0,NULL,NULL,1.00),('venmush','Venison and mushroom gravy',25,1,'item_standard',1,0,2072,1,1,'{}','nice item',0,NULL,NULL,1.00),('vests','Vests',50,1,'item_standard',1,0,1464,1,1,'{}','A clothing item. Use to wear it.',0,NULL,NULL,1.00),('Violet_Snowdrop','Violet Snowdrop',10,1,'item_standard',1,0,684,1,1,'{}','A delicate flower called Violet Snowdrop.',0,NULL,NULL,1.00),('Violet_Snowdrop_Seed','Violet Snowdrop Seed',50,1,'item_standard',1,0,685,1,1,'{}','Seeds to grow Violet Snowdrop flowers.',0,NULL,NULL,1.00),('vispia','Visceral Piano',25,1,'item_standard',0,0,2641,1,1,'{}','nice item',0,NULL,NULL,1.00),('vodka','Vodka',10,1,'item_standard',1,0,686,1,1,'{}','A strong alcoholic beverage known as Vodka.',0,NULL,NULL,1.00),('vodkabottle','Broken Bottle',1,1,'item_standard',1,0,22155,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('Volture_Egg','Volture Egg',10,1,'item_standard',1,0,687,1,1,'{}','An egg laid by a Volture bird.',0,NULL,NULL,1.00),('vulturetaxi','Vulture Taxidermy',20,1,'item_standard',1,0,688,1,1,'{}','A taxidermy of a vulture bird.',0,NULL,NULL,1.00),('vulture_taxidermy','Vulture Taxidermy',20,1,'item_standard',1,0,689,1,1,'{}','A preserved vulture bird for display.',0,NULL,NULL,1.00),('wardrobe','Wardrobe',1,1,'item_standard',1,0,1435,1,1,'{}','Change your clothes anywhere.',0,NULL,NULL,1.00),('washrag','Washrag',10,1,'item_standard',1,0,6440,1,1,'{}','A square of coarse cotton. Wet it, and the trail comes off your face',0,NULL,NULL,1.00),('washtub','Wash Tub',20,1,'item_standard',1,0,690,1,1,'{}','A tub used for washing clothes or other items.',0,NULL,NULL,1.00),('water','Water',25,1,'item_standard',1,0,691,1,1,'{}','Clean drinking water.',0,NULL,NULL,1.00),('water_bottle_empty','Empty Water Bottle',25,1,'item_standard',1,0,33457,1,1,'{}','Fill it in a river or lake.',0,NULL,NULL,0.50),('waterbarrel','Water Barrel',20,1,'item_standard',1,0,692,1,1,'{}','A large barrel used for storing water.',0,NULL,NULL,1.00),('wateringcan','Water Jug',50,1,'item_standard',1,0,693,1,1,'{}','Full of clean water from a pump. Pour it on a thirsty plant.',0,NULL,NULL,1.00),('wateringcan_dirtywater','Dirty Watering Jug',50,1,'item_standard',1,0,694,1,1,'{}','Filled from a river, mud and all. The plants do not mind.',0,NULL,NULL,1.00),('wateringcan_empty','Empty Watering Jug',50,1,'item_standard',1,0,695,1,1,'{}','Nothing in it. Fill it at a pump, a river or a water wagon.',0,NULL,NULL,1.00),('waterpump','Water Pump',20,1,'item_standard',1,0,696,1,1,'{}','A device used for pumping water.',0,NULL,NULL,1.00),('water_pump','Water Pump',20,1,'item_standard',1,0,697,1,1,'{}','A pump designed to move water.',0,NULL,NULL,1.00),('water_pump_handle','Water Pump Handle',25,1,'item_standard',0,0,2532,1,1,'{}','nice item',0,NULL,NULL,1.00),('wax','Wax',25,1,'item_standard',0,0,2509,1,1,'{}','nice item',0,NULL,NULL,1.00),('wedding_chain_ring','Wedding Ring on chain',10,1,'item_standard',1,0,937,1,1,'{}','A wedding ring on chain. usally worn this way so they dont get lost.',0,NULL,NULL,1.00),('wedding_ring','Wedding Ring',10,1,'item_standard',1,0,938,1,1,'{}','A beautiful wedding ring.',0,NULL,NULL,1.00),('wet_coca_leaf','Wet Coca Leaf',50,1,'item_standard',1,0,7028,1,1,'{}','Freshly picked coca leaves, still damp. Needs drying before use.',0,NULL,NULL,1.00),('wheat','Wheat',10,1,'item_standard',1,0,939,1,1,'{}','Often ground up into flour to used in cooking and baking',0,NULL,NULL,1.00),('wheatseed','Wheat Seed',50,1,'item_standard',1,0,940,1,1,'{}','When planted will grow into wheat.',0,NULL,NULL,1.00),('wheeltrunk','Wheeler Co Trunk',25,1,'item_standard',0,0,2477,1,1,'{}','nice item',0,NULL,NULL,1.00),('whifolchar','Decay Folding Chair',25,1,'item_standard',0,0,2578,1,1,'{}','nice item',0,NULL,NULL,1.00),('whisky','Whisky',10,1,'item_standard',1,0,698,1,1,'{}','An alcoholic beverage known as whisky.',0,NULL,NULL,1.00),('wickchar','Wicker Chair',25,1,'item_standard',0,0,2541,1,1,'{}','nice item',0,NULL,NULL,1.00),('wicker','Wicker',10,1,'item_standard',1,0,941,1,1,'{}','A natural material made from woven branches or reeds',0,NULL,NULL,1.00),('wickerbench','Wicker Bench',20,1,'item_standard',1,0,699,1,1,'{}','A bench made from wicker material.',0,NULL,NULL,1.00),('wicker_bench','Wicker Bench',20,1,'item_standard',1,0,700,1,1,'{}','A bench constructed with wicker material.',0,NULL,NULL,1.00),('wicrochar','Rustic Rocking Chair',25,1,'item_standard',0,0,2536,1,1,'{}','nice item',0,NULL,NULL,1.00),('wierco','Coat Rack',25,1,'item_standard',0,0,2553,1,1,'{}','nice item',0,NULL,NULL,1.00),('wildCiderMash','Black Berry Mash',10,1,'item_standard',0,0,701,1,1,'{}','Mashed blackberries used for making cider.',0,NULL,NULL,1.00),('wildCiderMoonshine','Black Berry Moonshine',10,1,'item_standard',1,0,702,1,1,'{}','Homemade moonshine crafted from blackberries.',0,NULL,NULL,1.00),('Wild_Carrot','Wild Carrot',50,1,'item_standard',1,0,703,1,1,'{}','A thin, pale carrot with a lacy white flower on top.',0,NULL,NULL,1.00),('Wild_Carrot_Seed','Wild Carrot Seed',50,1,'item_standard',1,0,704,1,1,'{}','Seed gathered from a dried wild carrot head.',0,NULL,NULL,1.00),('Wild_Feverfew','Wild Feverfew',10,1,'item_standard',1,0,705,1,1,'{}','A wild plant known as Feverfew.',0,NULL,NULL,1.00),('Wild_Feverfew_Seed','Wild Feverfew Seed',50,1,'item_standard',1,0,706,1,1,'{}','Seeds to grow Feverfew plants.',0,NULL,NULL,1.00),('Wild_Mint','Wild Mint',50,1,'item_standard',1,0,707,1,1,'{}','Cool, fresh leaves from damp ground. Good in tea or a julep.',0,NULL,NULL,1.00),('Wild_Mint_Seed','Wild Mint Seed',50,1,'item_standard',1,0,708,1,1,'{}','Seed for mint. Once it takes, it will not stop.',0,NULL,NULL,1.00),('Wild_Rhubarb','Wild Rhubarb',10,1,'item_standard',1,0,709,1,1,'{}','A rhubarb plant that grows in the wild.',0,NULL,NULL,1.00),('Wild_Rhubarb_Seed','Wild Rhubarb Seed',50,1,'item_standard',1,0,710,1,1,'{}','Seeds to grow wild rhubarb.',0,NULL,NULL,1.00),('wild_west_root_beer','Wild West Root Beer',10,1,'item_standard',1,0,5274,1,1,'{}','Wild west root beer',0,NULL,NULL,1.00),('wilmite','Wild Mint Tea',25,1,'item_standard',1,0,2074,1,1,'{}','nice item',0,NULL,NULL,1.00),('wine','Wine',10,1,'item_standard',1,0,711,1,1,'{}','An alcoholic beverage made from fermented grapes.',0,NULL,NULL,1.00),('winsochar','Windsor Chair',25,1,'item_standard',0,0,2638,1,1,'{}','nice item',0,NULL,NULL,1.00),('Wintergreen_Berry','Wintergreen Berry',50,1,'item_standard',1,0,712,1,1,'{}','Bright red berries with a minty taste, picked from a low evergreen.',0,NULL,NULL,1.00),('Wintergreen_Berry_Seed','Wintergreen Berry Seed',50,1,'item_standard',1,0,713,1,1,'{}','Seed for a creeping wintergreen plant.',0,NULL,NULL,1.00),('Wisteria','Wisteria',10,1,'item_standard',1,0,714,1,1,'{}','A flowering plant called Wisteria.',0,NULL,NULL,1.00),('Wisteria_Seed','Wisteria Seed',50,1,'item_standard',1,0,715,1,1,'{}','Seeds to grow Wisteria plants.',0,NULL,NULL,1.00),('witches_brew','Witches Brew',25,1,'item_standard',1,0,16474,3,4,'{}','Still warm, and nobody is tending the pot.',0,NULL,NULL,1.00),('wizardstaff','Staff',1,1,'item_standard',1,0,22147,1,5,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('wojape','Wojape',5,1,'item_standard',1,0,716,1,1,'{}','A traditional Native American sauce made from berries.',0,NULL,NULL,1.00),('wolfheart','Wolf heart',20,1,'item_standard',1,0,717,1,1,'{}','The heart of a wolf.',0,NULL,NULL,1.00),('wolfnativetent','Wolf Pelt Native Tent',20,1,'item_standard',1,0,1390,1,1,'{}','nice item',0,NULL,NULL,1.00),('wolfpelt','Wolf Pelt',10,1,'item_standard',1,0,718,1,1,'{}','A thick grey winter pelt.',0,NULL,NULL,2.00),('wolftooth','Wolf Fang',25,1,'item_standard',1,0,719,1,1,'{}','A sharp fang from a wolf.',0,NULL,NULL,0.05),('wood','Soft Wood',50,1,'item_standard',0,0,720,1,1,'{}','A type of wood that is soft and easy to work with.',0,NULL,NULL,1.00),('woodbench','Wooden Bench',20,1,'item_standard',1,0,721,1,1,'{}','A bench made from wood material.',0,NULL,NULL,1.00),('woodchair','Wood Chair',20,1,'item_standard',1,0,722,1,1,'{}','A chair made from wood material.',0,NULL,NULL,1.00),('wooden_bench','Wooden Bench',20,1,'item_standard',1,0,723,1,1,'{}','A bench constructed with wooden material.',0,NULL,NULL,1.00),('wooden_boards','Wooden Boards',25,1,'item_standard',0,0,724,1,1,'{}','Boards made from wood material.',0,NULL,NULL,1.00),('woodfence','Woodfence',25,1,'item_standard',0,0,2739,1,1,'{}','nice item',0,NULL,NULL,1.00),('woodpeck01_c','Woodpecker',20,1,'item_standard',1,0,725,1,1,'{}','A whole woodpecker.',0,NULL,NULL,0.10),('woodpeck02_c','Pileated Woodpecker',20,1,'item_standard',1,0,726,1,1,'{}','A whole woodpecker with a red crest.',0,NULL,NULL,0.20),('woodsaw','Woodsaw',10,1,'item_standard',1,0,942,1,1,'{}','Used to cut wood.',0,NULL,NULL,1.00),('wood_chair','Wood Chair',20,1,'item_standard',1,0,727,1,1,'{}','A chair made from wood material.',0,NULL,NULL,1.00),('wood_plane','Wood Plane',10,1,'item_standard',1,0,943,1,1,'{}','A wood plane used for shaping wood.',0,NULL,NULL,1.00),('wool','Wool',50,1,'item_standard',1,0,728,1,1,'{}','Fiber obtained from the fleece of sheep.',0,NULL,NULL,1.00),('worben','Decay Bench',25,1,'item_standard',0,0,2598,1,1,'{}','nice item',0,NULL,NULL,1.00),('worclotab','Carvis Cloth Table',25,1,'item_standard',0,0,2626,1,1,'{}','nice item',0,NULL,NULL,1.00),('wrench','Wrench',10,1,'item_standard',1,0,944,1,1,'{}','A wrech used to tighten bolts and other things.',0,NULL,NULL,1.00),('wsnakes','Western rattlesnake pelt',20,1,'item_standard',1,0,729,1,1,'{}','The skin of a western rattlesnake.',0,NULL,NULL,1.00),('wsnakeskin','Water Snake Skin',10,1,'item_standard',1,0,730,1,1,'{}','A dull, thin skin from a water snake.',0,NULL,NULL,0.20),('xmaspole','Xmas Pole',20,1,'item_standard',1,0,1376,1,1,'{}','nice item',0,NULL,NULL,1.00),('xmastree','Xmas Tree',20,1,'item_standard',1,0,1375,1,1,'{}','nice item',0,NULL,NULL,1.00),('yardbroom_wep','Yard Broom',1,1,'item_standard',1,0,30516,1,1,'{}','Carried on the body and swung as a club. Use it to take it out or put it away.',0,NULL,NULL,1.00),('yarmash','Yarrow and Potato Mash',25,1,'item_standard',1,0,2067,1,1,'{}','nice item',0,NULL,NULL,1.00),('Yarrow','Yarrow',50,1,'item_standard',1,0,731,1,1,'{}','Flat white flower heads on feathery leaves. An old wound herb.',0,NULL,NULL,1.00),('Yarrow_Seed','Yarrow Seed',50,1,'item_standard',1,0,732,1,1,'{}','Seed for a patch of yarrow.',0,NULL,NULL,1.00);
/*!40000 ALTER TABLE `items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `items_crafted`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `items_crafted` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `character_id` int(11) NOT NULL,
  `item_id` int(11) NOT NULL,
  `item_name` varchar(50) DEFAULT 'item',
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`metadata`)),
  `durability` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ID` (`id`),
  KEY `crafted_item_idx` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `items_crafted`
--

LOCK TABLES `items_crafted` WRITE;
/*!40000 ALTER TABLE `items_crafted` DISABLE KEYS */;
/*!40000 ALTER TABLE `items_crafted` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `loadout`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `loadout` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `charidentifier` int(11) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `ammo` varchar(255) NOT NULL DEFAULT '{}',
  `components` varchar(255) NOT NULL DEFAULT '{}',
  `dirt` decimal(20,6) DEFAULT 0.000000,
  `soot` decimal(20,6) DEFAULT 0.000000,
  `degradation` decimal(20,6) DEFAULT 0.000000,
  `damage` decimal(20,6) DEFAULT 0.000000,
  `used` tinyint(4) DEFAULT 0,
  `used2` tinyint(4) DEFAULT 0,
  `dropped` int(11) NOT NULL DEFAULT 0,
  `comps` longtext NOT NULL DEFAULT '{}',
  `label` varchar(50) DEFAULT NULL,
  `curr_inv` varchar(100) NOT NULL DEFAULT 'default',
  `serial_number` varchar(50) DEFAULT NULL,
  `custom_label` varchar(50) DEFAULT NULL,
  `custom_desc` varchar(50) DEFAULT NULL,
  `tier` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `id` (`id`),
  KEY `identifier` (`identifier`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `loadout`
--

LOCK TABLES `loadout` WRITE;
/*!40000 ALTER TABLE `loadout` DISABLE KEYS */;
/*!40000 ALTER TABLE `loadout` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail` (
  `address` int(11) NOT NULL AUTO_INCREMENT,
  `charidentifier` int(11) DEFAULT NULL,
  PRIMARY KEY (`address`)
) ENGINE=InnoDB AUTO_INCREMENT=1000 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mail`
--

LOCK TABLES `mail` WRITE;
/*!40000 ALTER TABLE `mail` DISABLE KEYS */;
/*!40000 ALTER TABLE `mail` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail_addressbook`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_addressbook` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `address` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `poBox` varchar(255) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `address` (`address`),
  CONSTRAINT `mail_addressbook_ibfk_1` FOREIGN KEY (`address`) REFERENCES `mail` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mail_addressbook`
--

LOCK TABLES `mail_addressbook` WRITE;
/*!40000 ALTER TABLE `mail_addressbook` DISABLE KEYS */;
/*!40000 ALTER TABLE `mail_addressbook` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail_business`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_business` (
  `job` varchar(50) NOT NULL,
  `handle` varchar(32) NOT NULL,
  PRIMARY KEY (`job`),
  UNIQUE KEY `handle` (`handle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mail_business_blocks`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_business_blocks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(50) NOT NULL,
  `address` int(11) NOT NULL,
  `blockedBy` int(11) DEFAULT NULL,
  `date` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `jobAddress` (`job`,`address`),
  KEY `bizBlockAddress` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mail_business_blocks`
--

LOCK TABLES `mail_business_blocks` WRITE;
/*!40000 ALTER TABLE `mail_business_blocks` DISABLE KEYS */;
/*!40000 ALTER TABLE `mail_business_blocks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail_editablefolders`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_editablefolders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `address` int(11) DEFAULT NULL,
  `folderName` varchar(255) DEFAULT NULL,
  `job` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `address` (`address`),
  CONSTRAINT `mail_editablefolders_ibfk_1` FOREIGN KEY (`address`) REFERENCES `mail` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mail_editablefolders`
--

LOCK TABLES `mail_editablefolders` WRITE;
/*!40000 ALTER TABLE `mail_editablefolders` DISABLE KEYS */;
/*!40000 ALTER TABLE `mail_editablefolders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail_group_members`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_group_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `groupId` int(11) NOT NULL,
  `address` int(11) NOT NULL,
  `notify` tinyint(1) NOT NULL DEFAULT 1,
  `lastRead` int(11) NOT NULL DEFAULT 0,
  `pinned` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `groupMember` (`groupId`,`address`),
  KEY `memberAddress` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mail_group_members`
--

LOCK TABLES `mail_group_members` WRITE;
/*!40000 ALTER TABLE `mail_group_members` DISABLE KEYS */;
/*!40000 ALTER TABLE `mail_group_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail_group_messages`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_group_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `groupId` int(11) NOT NULL,
  `address` int(11) NOT NULL,
  `body` longtext DEFAULT NULL,
  `date` varchar(32) DEFAULT NULL,
  `asJob` varchar(50) DEFAULT NULL,
  `parentId` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `groupThread` (`groupId`,`id`),
  KEY `groupParent` (`groupId`,`parentId`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mail_group_messages`
--

LOCK TABLES `mail_group_messages` WRITE;
/*!40000 ALTER TABLE `mail_group_messages` DISABLE KEYS */;
/*!40000 ALTER TABLE `mail_group_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail_group_reactions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_group_reactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `messageId` int(11) NOT NULL,
  `who` varchar(60) NOT NULL,
  `address` int(11) NOT NULL,
  `emoji` varchar(32) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `reaction` (`messageId`,`who`,`emoji`),
  KEY `reactAddress` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mail_group_reactions`
--

LOCK TABLES `mail_group_reactions` WRITE;
/*!40000 ALTER TABLE `mail_group_reactions` DISABLE KEYS */;
/*!40000 ALTER TABLE `mail_group_reactions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail_groups`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(64) NOT NULL,
  `owner` int(11) DEFAULT NULL,
  `kind` varchar(16) NOT NULL DEFAULT 'group',
  `ref` varchar(50) DEFAULT NULL,
  `handled` tinyint(1) NOT NULL DEFAULT 0,
  `bizRead` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`),
  KEY `kindRef` (`kind`,`ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mail_groups`
--

LOCK TABLES `mail_groups` WRITE;
/*!40000 ALTER TABLE `mail_groups` DISABLE KEYS */;
/*!40000 ALTER TABLE `mail_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mail_blocks`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mail_blocks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `address` int(11) NOT NULL,
  `blocked` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pair` (`address`,`blocked`),
  KEY `blocked` (`blocked`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mails`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mails` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mails`
--

LOCK TABLES `mails` WRITE;
/*!40000 ALTER TABLE `mails` DISABLE KEYS */;
/*!40000 ALTER TABLE `mails` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `market`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `market` (
  `charidentifier` int(11) NOT NULL DEFAULT 0,
  `listing` longtext DEFAULT '[]',
  `invid` int(11) DEFAULT 0,
  `invslots` int(11) DEFAULT 0,
  `location` varchar(50) DEFAULT 'Valentine',
  UNIQUE KEY `invid` (`invid`),
  KEY `charid` (`charidentifier`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `market`
--

LOCK TABLES `market` WRITE;
/*!40000 ALTER TABLE `market` DISABLE KEYS */;
/*!40000 ALTER TABLE `market` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `market_ledger`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `market_ledger` (
  `charidentifier` int(11) NOT NULL,
  `bank` varchar(64) DEFAULT NULL,
  `balance` decimal(12,2) NOT NULL DEFAULT 0.00,
  `lifetime` decimal(12,2) NOT NULL DEFAULT 0.00,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `market_ledger`
--

LOCK TABLES `market_ledger` WRITE;
/*!40000 ALTER TABLE `market_ledger` DISABLE KEYS */;
/*!40000 ALTER TABLE `market_ledger` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `market_trades`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `market_trades` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `item` varchar(96) NOT NULL,
  `amount` int(11) NOT NULL DEFAULT 0,
  `per_item` decimal(12,2) NOT NULL DEFAULT 0.00,
  `traded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `item_time` (`item`,`traded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `market_trades`
--

LOCK TABLES `market_trades` WRITE;
/*!40000 ALTER TABLE `market_trades` DISABLE KEYS */;
/*!40000 ALTER TABLE `market_trades` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_appeals`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_appeals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `prison_record_id` int(11) DEFAULT NULL,
  `citizen_identity` varchar(50) NOT NULL,
  `citizen_name` varchar(100) DEFAULT NULL,
  `reduction_minutes` int(11) NOT NULL DEFAULT 0,
  `commute` tinyint(1) NOT NULL DEFAULT 0,
  `reason` text DEFAULT NULL,
  `status` enum('pending','approved','denied') NOT NULL DEFAULT 'pending',
  `minutes_reduced` int(11) NOT NULL DEFAULT 0,
  `requested_by_citizenid` varchar(50) DEFAULT NULL,
  `requested_by_name` varchar(100) DEFAULT NULL,
  `requested_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `reviewed_by_citizenid` varchar(50) DEFAULT NULL,
  `reviewed_by_name` varchar(100) DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `review_notes` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizen_identity`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_appeals`
--

LOCK TABLES `mdt_appeals` WRITE;
/*!40000 ALTER TABLE `mdt_appeals` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_appeals` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_arrests`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_arrests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizen_identity` varchar(50) NOT NULL,
  `citizen_name` varchar(100) DEFAULT NULL,
  `lawman_citizenid` varchar(50) DEFAULT NULL,
  `lawman_name` varchar(100) DEFAULT NULL,
  `charges` longtext DEFAULT NULL,
  `total_fine` int(11) NOT NULL DEFAULT 0,
  `total_months` int(11) NOT NULL DEFAULT 0,
  `discount_percent` int(11) NOT NULL DEFAULT 0,
  `fine_discount_percent` int(11) NOT NULL DEFAULT 0,
  `jail_discount_percent` int(11) NOT NULL DEFAULT 0,
  `final_fine` int(11) NOT NULL DEFAULT 0,
  `final_months` int(11) NOT NULL DEFAULT 0,
  `notes` text DEFAULT NULL,
  `fine_applied` tinyint(1) NOT NULL DEFAULT 0,
  `jail_applied` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizen_identity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_arrests`
--

LOCK TABLES `mdt_arrests` WRITE;
/*!40000 ALTER TABLE `mdt_arrests` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_arrests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_audit_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_audit_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `action` varchar(80) NOT NULL,
  `actor_citizenid` varchar(50) DEFAULT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `target_citizenid` varchar(50) DEFAULT NULL,
  `target_name` varchar(100) DEFAULT NULL,
  `details` text DEFAULT NULL,
  `metadata` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_action` (`action`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_audit_log`
--

LOCK TABLES `mdt_audit_log` WRITE;
/*!40000 ALTER TABLE `mdt_audit_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_audit_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_bail`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_bail` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `prison_record_id` int(11) DEFAULT NULL,
  `citizen_identity` varchar(50) NOT NULL,
  `citizen_name` varchar(100) DEFAULT NULL,
  `amount` int(11) NOT NULL DEFAULT 0,
  `reason` text DEFAULT NULL,
  `status` enum('pending','processing','active','appeared','skipped','denied') NOT NULL DEFAULT 'pending',
  `remaining_seconds` int(11) NOT NULL DEFAULT 0,
  `paid` tinyint(4) NOT NULL DEFAULT 0,
  `requested_by_citizenid` varchar(50) DEFAULT NULL,
  `requested_by_name` varchar(100) DEFAULT NULL,
  `requested_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `reviewed_by_citizenid` varchar(50) DEFAULT NULL,
  `reviewed_by_name` varchar(100) DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `review_notes` text DEFAULT NULL,
  `court_due` timestamp NULL DEFAULT NULL,
  `resolved_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizen_identity`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_bail`
--

LOCK TABLES `mdt_bail` WRITE;
/*!40000 ALTER TABLE `mdt_bail` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_bail` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_bolos`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_bolos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(30) NOT NULL DEFAULT 'witness_statement',
  `subject_name` varchar(100) DEFAULT NULL,
  `po_number` varchar(50) DEFAULT NULL,
  `location` varchar(200) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `lawman_name` varchar(100) DEFAULT NULL,
  `region` varchar(50) DEFAULT NULL,
  `status` enum('active','inactive','resolved') NOT NULL DEFAULT 'active',
  `issued_by` varchar(50) DEFAULT NULL,
  `issued_by_name` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_bolos`
--

LOCK TABLES `mdt_bolos` WRITE;
/*!40000 ALTER TABLE `mdt_bolos` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_bolos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_bulletins`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_bulletins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(200) NOT NULL,
  `content` text DEFAULT NULL,
  `type` enum('general','urgent','motd') NOT NULL DEFAULT 'general',
  `posted_by_citizenid` varchar(50) DEFAULT NULL,
  `posted_by_name` varchar(100) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_bulletins`
--

LOCK TABLES `mdt_bulletins` WRITE;
/*!40000 ALTER TABLE `mdt_bulletins` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_bulletins` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_case_defense`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_case_defense` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `case_id` int(11) NOT NULL,
  `lawyer_citizenid` varchar(50) NOT NULL,
  `lawyer_name` varchar(100) DEFAULT NULL,
  `assigned_by_citizenid` varchar(50) DEFAULT NULL,
  `assigned_by_name` varchar(100) DEFAULT NULL,
  `assigned_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_case_lawyer` (`case_id`,`lawyer_citizenid`),
  CONSTRAINT `fk_defense_case` FOREIGN KEY (`case_id`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_case_defense`
--

LOCK TABLES `mdt_case_defense` WRITE;
/*!40000 ALTER TABLE `mdt_case_defense` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_case_defense` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_case_statements`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_case_statements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `case_id` int(11) NOT NULL,
  `author_citizenid` varchar(50) DEFAULT NULL,
  `author_name` varchar(100) DEFAULT NULL,
  `author_role` enum('defense','law') NOT NULL DEFAULT 'law',
  `statement` text NOT NULL,
  `filed_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `fk_statement_case` (`case_id`),
  CONSTRAINT `fk_statement_case` FOREIGN KEY (`case_id`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_case_statements`
--

LOCK TABLES `mdt_case_statements` WRITE;
/*!40000 ALTER TABLE `mdt_case_statements` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_case_statements` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_cases`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_cases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `case_number` varchar(20) NOT NULL,
  `title` varchar(150) NOT NULL,
  `location` varchar(200) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `status` enum('open','active','suspended','closed') NOT NULL DEFAULT 'open',
  `priority` enum('low','medium','high','critical') NOT NULL DEFAULT 'medium',
  `created_by` varchar(100) DEFAULT NULL,
  `created_citizenid` varchar(50) DEFAULT NULL,
  `investigator_name` varchar(100) DEFAULT NULL,
  `assigned_lawmen` text DEFAULT NULL,
  `linked_reports` text DEFAULT NULL,
  `linked_evidence` text DEFAULT NULL,
  `confiscated_items` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_case_number` (`case_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_cases`
--

LOCK TABLES `mdt_cases` WRITE;
/*!40000 ALTER TABLE `mdt_cases` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_cases` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_cases_involved`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_cases_involved` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `caseid` int(11) NOT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `type` enum('suspect','victim','witness','person_of_interest') NOT NULL DEFAULT 'suspect',
  `notes` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`),
  KEY `fk_case_involved` (`caseid`),
  CONSTRAINT `fk_case_involved` FOREIGN KEY (`caseid`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_cases_involved`
--

LOCK TABLES `mdt_cases_involved` WRITE;
/*!40000 ALTER TABLE `mdt_cases_involved` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_cases_involved` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_cases_lawmen`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_cases_lawmen` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `caseid` int(11) NOT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `role` enum('lead','assisting','supervisor','consulting') NOT NULL DEFAULT 'assisting',
  PRIMARY KEY (`id`),
  KEY `fk_case_lawmen` (`caseid`),
  CONSTRAINT `fk_case_lawmen` FOREIGN KEY (`caseid`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_cases_lawmen`
--

LOCK TABLES `mdt_cases_lawmen` WRITE;
/*!40000 ALTER TABLE `mdt_cases_lawmen` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_cases_lawmen` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_criminals`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_criminals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` int(11) DEFAULT 0,
  `identity` varchar(50) NOT NULL,
  `photo_url` text DEFAULT NULL,
  `firstname` varchar(50) DEFAULT NULL,
  `lastname` varchar(50) DEFAULT NULL,
  `age` int(11) NOT NULL DEFAULT 0,
  `description` text DEFAULT NULL,
  `status` enum('wanted','clear','released') NOT NULL DEFAULT 'clear',
  `wanted_by_hand` tinyint(1) NOT NULL DEFAULT 0,
  `registered_by` varchar(100) DEFAULT NULL,
  `registered_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_identity` (`identity`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_criminals`
--

LOCK TABLES `mdt_criminals` WRITE;
/*!40000 ALTER TABLE `mdt_criminals` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_criminals` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_evidence`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_evidence` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `criminal_id` int(11) DEFAULT NULL,
  `title` text DEFAULT NULL,
  `description` text DEFAULT NULL,
  `created_by` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_criminal` (`criminal_id`),
  CONSTRAINT `fk_mdt_evidence_criminal` FOREIGN KEY (`criminal_id`) REFERENCES `mdt_criminals` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_evidence`
--

LOCK TABLES `mdt_evidence` WRITE;
/*!40000 ALTER TABLE `mdt_evidence` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_evidence` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_evidence_items`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_evidence_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(30) NOT NULL DEFAULT 'other',
  `label` varchar(150) NOT NULL,
  `description` text DEFAULT NULL,
  `location_found` varchar(200) DEFAULT NULL,
  `collected_by` varchar(100) DEFAULT NULL,
  `linked_case` varchar(30) DEFAULT NULL,
  `status` enum('collected','analyzed','stored','destroyed') NOT NULL DEFAULT 'collected',
  `notes` text DEFAULT NULL,
  `image_urls` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_case` (`linked_case`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_evidence_items`
--

LOCK TABLES `mdt_evidence_items` WRITE;
/*!40000 ALTER TABLE `mdt_evidence_items` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_evidence_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_expungements`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_expungements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizen_identity` varchar(50) NOT NULL,
  `citizen_name` varchar(100) DEFAULT NULL,
  `reason` text DEFAULT NULL,
  `requested_by_citizenid` varchar(50) DEFAULT NULL,
  `requested_by_name` varchar(100) DEFAULT NULL,
  `requested_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` enum('pending','approved','denied') NOT NULL DEFAULT 'pending',
  `reviewed_by_citizenid` varchar(50) DEFAULT NULL,
  `reviewed_by_name` varchar(100) DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `review_notes` text DEFAULT NULL,
  `snapshot` longtext DEFAULT NULL,
  `records_cleared` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizen_identity`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_expungements`
--

LOCK TABLES `mdt_expungements` WRITE;
/*!40000 ALTER TABLE `mdt_expungements` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_expungements` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_fine_types`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_fine_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `category` enum('theft','violence','public_order','weapons','property','animals','other') NOT NULL DEFAULT 'other',
  `amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `jail_time` int(11) NOT NULL DEFAULT 0,
  `description` text DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `severity` enum('low','medium','high','critical') NOT NULL DEFAULT 'low',
  `created_by` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_fine_types`
--

LOCK TABLES `mdt_fine_types` WRITE;
/*!40000 ALTER TABLE `mdt_fine_types` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_fine_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_lawman_profiles`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_lawman_profiles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` int(11) DEFAULT 0,
  `citizen_id` varchar(50) NOT NULL,
  `photo_url` text DEFAULT NULL,
  `rank` varchar(50) NOT NULL DEFAULT 'Deputy',
  `department` varchar(100) DEFAULT NULL,
  `region` varchar(50) DEFAULT NULL,
  `trainings` text DEFAULT NULL,
  `description` text DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `duty_time_minutes` int(11) NOT NULL DEFAULT 0,
  `last_duty_update` timestamp NULL DEFAULT NULL,
  `loa_until` date DEFAULT NULL,
  `callsign` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizen_id`,`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_lawman_profiles`
--

LOCK TABLES `mdt_lawman_profiles` WRITE;
/*!40000 ALTER TABLE `mdt_lawman_profiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_lawman_profiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_lawman_stats`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_lawman_stats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` int(11) DEFAULT 0,
  `citizen_id` varchar(50) NOT NULL,
  `criminals_registered` int(11) NOT NULL DEFAULT 0,
  `arrests_made` int(11) NOT NULL DEFAULT 0,
  `fines_applied` int(11) NOT NULL DEFAULT 0,
  `evidences_collected` int(11) NOT NULL DEFAULT 0,
  `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_lawman_stats`
--

LOCK TABLES `mdt_lawman_stats` WRITE;
/*!40000 ALTER TABLE `mdt_lawman_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_lawman_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_lawyer_stats`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_lawyer_stats` (
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `duty_minutes` int(11) NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_lawyer_stats`
--

LOCK TABLES `mdt_lawyer_stats` WRITE;
/*!40000 ALTER TABLE `mdt_lawyer_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_lawyer_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_ledger`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_ledger` (
  `job` varchar(64) NOT NULL,
  `balance` bigint(20) NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_ledger`
--

LOCK TABLES `mdt_ledger` WRITE;
/*!40000 ALTER TABLE `mdt_ledger` DISABLE KEYS */;
INSERT INTO `mdt_ledger` (`job`, `balance`) VALUES ('police',0);
/*!40000 ALTER TABLE `mdt_ledger` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_ledger_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_ledger_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(64) NOT NULL,
  `type` varchar(32) NOT NULL,
  `amount` bigint(20) NOT NULL DEFAULT 0,
  `balance_after` bigint(20) NOT NULL DEFAULT 0,
  `actor_name` varchar(100) DEFAULT NULL,
  `note` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_job` (`job`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_ledger_log`
--

LOCK TABLES `mdt_ledger_log` WRITE;
/*!40000 ALTER TABLE `mdt_ledger_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_ledger_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_most_wanted`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_most_wanted` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizen_identity` varchar(50) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `crimes` text DEFAULT NULL,
  `danger` enum('low','medium','high','extreme') NOT NULL DEFAULT 'medium',
  `reward` int(11) NOT NULL DEFAULT 0,
  `notes` text DEFAULT NULL,
  `photo_url` varchar(500) DEFAULT NULL,
  `status` enum('active','captured') NOT NULL DEFAULT 'active',
  `added_by_citizenid` varchar(50) DEFAULT NULL,
  `added_by_name` varchar(100) DEFAULT NULL,
  `added_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `captured_by_name` varchar(100) DEFAULT NULL,
  `captured_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_most_wanted`
--

LOCK TABLES `mdt_most_wanted` WRITE;
/*!40000 ALTER TABLE `mdt_most_wanted` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_most_wanted` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_penal_codes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_penal_codes` (
  `code` varchar(20) NOT NULL,
  `label` varchar(100) NOT NULL,
  `charge_class` enum('felony','misdemeanor','infraction') NOT NULL DEFAULT 'misdemeanor',
  `months` int(11) NOT NULL DEFAULT 0,
  `fine` int(11) NOT NULL DEFAULT 0,
  `color` varchar(20) NOT NULL DEFAULT 'green',
  `description` varchar(255) DEFAULT NULL,
  `category` varchar(40) DEFAULT NULL,
  `burdens` text DEFAULT NULL,
  `definitions` text DEFAULT NULL,
  `tiers` text DEFAULT NULL,
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_penal_codes`
--

LOCK TABLES `mdt_penal_codes` WRITE;
/*!40000 ALTER TABLE `mdt_penal_codes` DISABLE KEYS */;
INSERT INTO `mdt_penal_codes` VALUES ('P.C. 1001','Murder','felony',120,1500,'red','Killing another person with intent or malice aforethought.',NULL,NULL,NULL,NULL),('P.C. 1002','Manslaughter','felony',80,1000,'red','Killing another person without intent, through recklessness or a quarrel.',NULL,NULL,NULL,NULL),('P.C. 1003','Attempted Murder','felony',90,1200,'red','Trying to kill another person and failing.',NULL,NULL,NULL,NULL),('P.C. 1004','Assault with a Deadly Weapon','felony',40,600,'red','Attacking a person with a firearm, blade or other weapon.',NULL,NULL,NULL,NULL),('P.C. 1005','Assault','misdemeanor',10,200,'orange','Threatening or attempting bodily harm against another person.',NULL,NULL,NULL,NULL),('P.C. 1006','Battery','misdemeanor',15,250,'orange','Striking or laying hands on another person without consent.',NULL,NULL,NULL,NULL),('P.C. 1007','Kidnapping','felony',60,1000,'red','Taking or holding a person against their will.',NULL,NULL,NULL,NULL),('P.C. 1008','Hostage Taking','felony',70,1200,'red','Holding a person under threat to force the hand of others.',NULL,NULL,NULL,NULL),('P.C. 1009','Robbery of a Person','felony',45,800,'red','Taking property from a person by force or threat of force.',NULL,NULL,NULL,NULL),('P.C. 1010','Threatening a Citizen','misdemeanor',5,150,'orange','Making threats of violence against a citizen.',NULL,NULL,NULL,NULL),('P.C. 1011','Brandishing a Firearm','misdemeanor',5,150,'orange','Drawing or waving a firearm to intimidate.',NULL,NULL,NULL,NULL),('P.C. 1012','Unlawful Hanging','felony',100,1500,'red','Hanging or attempting to hang a person outside the law.',NULL,NULL,NULL,NULL),('P.C. 1013','Dueling within Town Limits','misdemeanor',15,300,'orange','Taking part in a duel inside a town.',NULL,NULL,NULL,NULL),('P.C. 1014','Murder of a Lawman','felony',150,2500,'red','Killing a sworn officer of the law.',NULL,NULL,NULL,NULL),('P.C. 2001','Petty Theft','misdemeanor',5,100,'orange','Stealing goods of small value.',NULL,NULL,NULL,NULL),('P.C. 2002','Grand Theft','felony',20,400,'red','Stealing goods of considerable value.',NULL,NULL,NULL,NULL),('P.C. 2003','Burglary','felony',25,500,'red','Breaking into a building to commit a crime.',NULL,NULL,NULL,NULL),('P.C. 2004','Bank Robbery','felony',90,2000,'red','Robbing a bank or its vault.',NULL,NULL,NULL,NULL),('P.C. 2005','Train Robbery','felony',80,1800,'red','Robbing a train, its passengers or its cargo.',NULL,NULL,NULL,NULL),('P.C. 2006','Stagecoach Robbery','felony',60,1200,'red','Holding up a stagecoach or its passengers.',NULL,NULL,NULL,NULL),('P.C. 2007','Store Robbery','felony',40,800,'red','Holding up a store or trading post.',NULL,NULL,NULL,NULL),('P.C. 2008','Arson','felony',45,900,'red','Setting fire to a building, crop or property.',NULL,NULL,NULL,NULL),('P.C. 2009','Vandalism','misdemeanor',5,150,'orange','Damaging or defacing property.',NULL,NULL,NULL,NULL),('P.C. 2010','Trespassing','infraction',0,50,'green','Entering private land or property without leave.',NULL,NULL,NULL,NULL),('P.C. 2011','Possession of Stolen Goods','misdemeanor',10,250,'orange','Holding goods known to be stolen.',NULL,NULL,NULL,NULL),('P.C. 2012','Grave Robbing','felony',30,600,'red','Disturbing a grave to take what is buried.',NULL,NULL,NULL,NULL),('P.C. 2101','Horse Theft','felony',35,700,'red','Taking a horse that belongs to another.','property','[\"The horse belonged to another person.\",\"The accused took or rode off with it without the owner\'s leave.\",\"The accused meant to keep it, sell it or keep it from the owner.\"]','[{\"term\":\"Horse\",\"body\":\"Any saddle, draft or carriage horse, mule or donkey.\",\"items\":[\"Saddle horses\",\"Draft horses\",\"Mules and donkeys\"]},{\"term\":\"Without leave\",\"body\":\"The owner did not agree, or agreed only because of a threat or a lie.\",\"items\":[]}]','[{\"kind\":\"Joyride\",\"description\":\"Taken and left where it could be found.\",\"fine\":250,\"months\":10},{\"kind\":\"Theft\",\"description\":\"Taken to keep or sell.\",\"fine\":700,\"months\":35},{\"kind\":\"Ring\",\"description\":\"Part of an organised horse-stealing ring.\",\"fine\":1500,\"months\":70}]'),('P.C. 3001','Unlawful Discharge of a Firearm','misdemeanor',5,150,'orange','Firing a weapon in town or without cause.',NULL,NULL,NULL,NULL),('P.C. 3002','Possession of an Illegal Weapon','misdemeanor',10,300,'orange','Carrying a weapon the law forbids.',NULL,NULL,NULL,NULL),('P.C. 3003','Use of Explosives','felony',60,1200,'red','Setting off dynamite or other explosives against people or property.',NULL,NULL,NULL,NULL),('P.C. 3004','Carrying a Weapon in a Restricted Place','infraction',0,75,'green','Bearing arms where they are not allowed.',NULL,NULL,NULL,NULL),('P.C. 3005','Shooting at a Lawman','felony',80,1500,'red','Opening fire on a sworn officer of the law.',NULL,NULL,NULL,NULL),('P.C. 3006','Gun Running','felony',50,1000,'red','Trading weapons outside the law.',NULL,NULL,NULL,NULL),('P.C. 4001','Public Intoxication','infraction',0,25,'green','Being drunk and disorderly in public.',NULL,NULL,NULL,NULL),('P.C. 4002','Disturbing the Peace','infraction',0,50,'green','Making a public nuisance of oneself.',NULL,NULL,NULL,NULL),('P.C. 4003','Indecent Exposure','misdemeanor',5,100,'orange','Exposing oneself in public.',NULL,NULL,NULL,NULL),('P.C. 4004','Loitering','infraction',0,25,'green','Idling where told to move along.',NULL,NULL,NULL,NULL),('P.C. 4005','Brawling','misdemeanor',5,150,'orange','Fist fighting in public.',NULL,NULL,NULL,NULL),('P.C. 4006','Reckless Riding','infraction',0,75,'green','Riding or driving a team with no regard for others.',NULL,NULL,NULL,NULL),('P.C. 4007','Inciting a Riot','felony',25,500,'red','Stirring a crowd to violence.',NULL,NULL,NULL,NULL),('P.C. 5001','Obstruction of Justice','misdemeanor',10,300,'orange','Hindering a lawman in the course of their duty.',NULL,NULL,NULL,NULL),('P.C. 5002','Resisting Arrest','misdemeanor',10,250,'orange','Fighting or refusing a lawful arrest.',NULL,NULL,NULL,NULL),('P.C. 5003','Evading the Law','misdemeanor',15,300,'orange','Fleeing from a lawman.',NULL,NULL,NULL,NULL),('P.C. 5004','Escaping Custody','felony',40,800,'red','Breaking out of a cell, prison or a lawman\'s custody.',NULL,NULL,NULL,NULL),('P.C. 5005','Impersonating a Lawman','felony',30,600,'red','Passing oneself off as an officer of the law.',NULL,NULL,NULL,NULL),('P.C. 5006','Bribery','felony',30,700,'red','Offering money or favours to sway an official.',NULL,NULL,NULL,NULL),('P.C. 5007','Perjury','misdemeanor',15,400,'orange','Lying under oath.',NULL,NULL,NULL,NULL),('P.C. 5008','Failure to Pay a Fine','infraction',0,100,'green','Not settling a fine owed.',NULL,NULL,NULL,NULL),('P.C. 5009','Contempt of Court','misdemeanor',10,200,'orange','Disrespecting or disobeying the court.',NULL,NULL,NULL,NULL),('P.C. 5010','Aiding and Abetting','misdemeanor',15,400,'orange','Helping another commit a crime.',NULL,NULL,NULL,NULL),('P.C. 5011','Harbouring a Fugitive','misdemeanor',20,450,'orange','Hiding or sheltering a wanted person.',NULL,NULL,NULL,NULL),('P.C. 5012','Corruption of a Public Official','felony',60,1500,'red','An official abusing the office for gain.',NULL,NULL,NULL,NULL),('P.C. 6001','Animal Cruelty','misdemeanor',5,200,'orange','Needless harm to an animal.',NULL,NULL,NULL,NULL),('P.C. 6002','Poaching','misdemeanor',10,250,'orange','Hunting on protected land or out of season.',NULL,NULL,NULL,NULL),('P.C. 6003','Hunting Legendary Game without Leave','misdemeanor',10,300,'orange','Taking a legendary animal without permission.',NULL,NULL,NULL,NULL),('P.C. 6004','Cattle Rustling','felony',30,600,'red','Stealing cattle or other livestock.',NULL,NULL,NULL,NULL),('P.C. 6005','Unlicensed Butchering','infraction',0,75,'green','Butchering and selling meat without a licence.',NULL,NULL,NULL,NULL),('P.C. 7001','Moonshining','felony',25,500,'red','Running a still to make untaxed liquor.',NULL,NULL,NULL,NULL),('P.C. 7002','Possession of Moonshine','misdemeanor',5,150,'orange','Holding untaxed liquor.',NULL,NULL,NULL,NULL),('P.C. 7003','Possession of Narcotics','misdemeanor',10,300,'orange','Holding opium, heroin or other narcotics without a prescription.',NULL,NULL,NULL,NULL),('P.C. 7004','Narcotics Trafficking','felony',60,1200,'red','Selling or moving narcotics.',NULL,NULL,NULL,NULL),('P.C. 7005','Smuggling','felony',40,800,'red','Moving goods past the law to avoid duty or seizure.',NULL,NULL,NULL,NULL),('P.C. 7006','Counterfeiting','felony',50,1000,'red','Making or passing false money.',NULL,NULL,NULL,NULL),('P.C. 7007','Possession of Burglary Tools','misdemeanor',5,200,'orange','Carrying lockpicks or safe tools with intent.',NULL,NULL,NULL,NULL);
/*!40000 ALTER TABLE `mdt_penal_codes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_permissions_overrides`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_permissions_overrides` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `lawman_name` varchar(100) DEFAULT NULL,
  `permissions` longtext DEFAULT NULL,
  `updated_by` varchar(100) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_permissions_overrides`
--

LOCK TABLES `mdt_permissions_overrides` WRITE;
/*!40000 ALTER TABLE `mdt_permissions_overrides` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_permissions_overrides` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_prison_records`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_prison_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_name` varchar(100) DEFAULT NULL,
  `charidentifier` varchar(50) DEFAULT NULL,
  `jail_time` int(11) NOT NULL DEFAULT 0,
  `sentence_minutes` int(11) NOT NULL DEFAULT 0,
  `imprisoned_by` varchar(100) DEFAULT NULL,
  `imprisoned_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` enum('active','completed') NOT NULL DEFAULT 'active',
  `fine_amount` int(11) NOT NULL DEFAULT 0,
  `reason` text DEFAULT NULL,
  `is_bounty_claim` tinyint(1) NOT NULL DEFAULT 0,
  `cell_x` double DEFAULT NULL,
  `cell_y` double DEFAULT NULL,
  `cell_z` double DEFAULT NULL,
  `cell_h` double DEFAULT NULL,
  `escape_radius` double DEFAULT NULL,
  `exit_x` double DEFAULT NULL,
  `exit_y` double DEFAULT NULL,
  `exit_z` double DEFAULT NULL,
  `exit_h` double DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_char_status` (`charidentifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_prison_records`
--

LOCK TABLES `mdt_prison_records` WRITE;
/*!40000 ALTER TABLE `mdt_prison_records` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_prison_records` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_reports`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `report_number` varchar(20) DEFAULT NULL,
  `title` varchar(100) NOT NULL,
  `type` varchar(50) NOT NULL DEFAULT 'Incident Report',
  `location` varchar(200) DEFAULT NULL,
  `content` longtext DEFAULT NULL,
  `content_plaintext` text DEFAULT NULL,
  `crimes_json` longtext DEFAULT NULL,
  `reduction_percent` int(11) NOT NULL DEFAULT 0,
  `jail_reduction_percent` int(11) NOT NULL DEFAULT 0,
  `fine_reduction_percent` int(11) NOT NULL DEFAULT 0,
  `author_citizenid` varchar(50) DEFAULT NULL,
  `author_name` varchar(100) DEFAULT NULL,
  `confiscated_items` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_number` (`report_number`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_reports`
--

LOCK TABLES `mdt_reports` WRITE;
/*!40000 ALTER TABLE `mdt_reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_reports_charges`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_reports_charges` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reportid` int(11) NOT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `charge_label` varchar(100) DEFAULT NULL,
  `charge_code` varchar(20) DEFAULT NULL,
  `charge_class` enum('felony','misdemeanor','infraction') DEFAULT NULL,
  `count` int(11) NOT NULL DEFAULT 1,
  `jail_time` int(11) NOT NULL DEFAULT 0,
  `fine` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`),
  KEY `fk_rep_charges` (`reportid`),
  CONSTRAINT `fk_rep_charges` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_reports_charges`
--

LOCK TABLES `mdt_reports_charges` WRITE;
/*!40000 ALTER TABLE `mdt_reports_charges` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_reports_charges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_reports_involved`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_reports_involved` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reportid` int(11) NOT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `type` enum('suspect','victim','witness','lawman') NOT NULL DEFAULT 'suspect',
  `notes` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`),
  KEY `fk_rep_involved` (`reportid`),
  CONSTRAINT `fk_rep_involved` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_reports_involved`
--

LOCK TABLES `mdt_reports_involved` WRITE;
/*!40000 ALTER TABLE `mdt_reports_involved` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_reports_involved` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_reports_lawmen`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_reports_lawmen` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reportid` int(11) NOT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `role` enum('lead','assisting','supervisor','consulting') NOT NULL DEFAULT 'assisting',
  PRIMARY KEY (`id`),
  KEY `fk_rep_lawmen` (`reportid`),
  CONSTRAINT `fk_rep_lawmen` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_reports_lawmen`
--

LOCK TABLES `mdt_reports_lawmen` WRITE;
/*!40000 ALTER TABLE `mdt_reports_lawmen` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_reports_lawmen` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_reports_warrants`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_reports_warrants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reportid` int(11) DEFAULT NULL,
  `citizenid` varchar(50) NOT NULL DEFAULT '',
  `citizen_name` varchar(100) DEFAULT NULL,
  `charges` text DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `felonies` int(11) NOT NULL DEFAULT 0,
  `misdemeanors` int(11) NOT NULL DEFAULT 0,
  `infractions` int(11) NOT NULL DEFAULT 0,
  `expiry_date` timestamp NOT NULL DEFAULT (current_timestamp() + interval 7 day),
  `issued_by` varchar(100) DEFAULT NULL,
  `status` enum('active','expired','served','revoked') NOT NULL DEFAULT 'active',
  `image_url` varchar(500) DEFAULT NULL,
  `bounty_fine` int(11) NOT NULL DEFAULT 0,
  `bounty_jailtime` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `claimed_by` varchar(100) DEFAULT NULL,
  `bounty_reward` int(11) NOT NULL DEFAULT 0,
  `revoked_at` timestamp NULL DEFAULT NULL,
  `revoked_by` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_reports_warrants`
--

LOCK TABLES `mdt_reports_warrants` WRITE;
/*!40000 ALTER TABLE `mdt_reports_warrants` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_reports_warrants` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_settings`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_settings` (
  `setting_key` varchar(64) NOT NULL,
  `setting_value` text DEFAULT NULL,
  `updated_by` varchar(100) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_settings`
--

LOCK TABLES `mdt_settings` WRITE;
/*!40000 ALTER TABLE `mdt_settings` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mdt_tips`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mdt_tips` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizen_identity` varchar(50) DEFAULT NULL,
  `citizen_name` varchar(100) DEFAULT NULL,
  `anonymous` tinyint(1) NOT NULL DEFAULT 0,
  `message` text NOT NULL,
  `location` varchar(120) DEFAULT NULL,
  `status` enum('new','read') NOT NULL DEFAULT 'new',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mdt_tips`
--

LOCK TABLES `mdt_tips` WRITE;
/*!40000 ALTER TABLE `mdt_tips` DISABLE KEYS */;
/*!40000 ALTER TABLE `mdt_tips` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mortician_business`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mortician_business` (
  `job` varchar(50) NOT NULL,
  `cut` int(11) NOT NULL DEFAULT 0,
  `webhook` text DEFAULT NULL,
  PRIMARY KEY (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mortician_register`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mortician_register` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(50) NOT NULL,
  `charid` int(11) NOT NULL,
  `undertaker` varchar(100) NOT NULL,
  `deceased` varchar(100) NOT NULL,
  `cause` varchar(100) NOT NULL DEFAULT '',
  `place` varchar(50) NOT NULL DEFAULT '',
  `kind` varchar(10) NOT NULL DEFAULT 'casket',
  `goods` varchar(255) NOT NULL DEFAULT '',
  `paid` int(11) NOT NULL DEFAULT 0,
  `house` int(11) NOT NULL DEFAULT 0,
  `at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_job` (`job`,`at`),
  KEY `idx_char` (`charid`,`at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mortician_register`
--

LOCK TABLES `mortician_register` WRITE;
/*!40000 ALTER TABLE `mortician_register` DISABLE KEYS */;
/*!40000 ALTER TABLE `mortician_register` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mortician_shift`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mortician_shift` (
  `charid` int(11) NOT NULL,
  `started` int(11) NOT NULL,
  `burials` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mortician_shift`
--

LOCK TABLES `mortician_shift` WRITE;
/*!40000 ALTER TABLE `mortician_shift` DISABLE KEYS */;
/*!40000 ALTER TABLE `mortician_shift` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `outfits`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `outfits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(45) NOT NULL,
  `charidentifier` int(11) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `comps` longtext DEFAULT NULL,
  `compTints` longtext DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `outfits`
--

LOCK TABLES `outfits` WRITE;
/*!40000 ALTER TABLE `outfits` DISABLE KEYS */;
/*!40000 ALTER TABLE `outfits` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `outfitter`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `outfitter` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charidentifier` int(11) NOT NULL,
  `sku` varchar(64) NOT NULL,
  `placed` tinyint(1) NOT NULL DEFAULT 0,
  `x` float DEFAULT NULL,
  `y` float DEFAULT NULL,
  `z` float DEFAULT NULL,
  `h` float DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `owner` (`charidentifier`),
  KEY `standing` (`placed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `outfitter`
--

LOCK TABLES `outfitter` WRITE;
/*!40000 ALTER TABLE `outfitter` DISABLE KEYS */;
/*!40000 ALTER TABLE `outfitter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `palette_names`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `palette_names` (
  `palette` bigint(20) NOT NULL,
  `name` varchar(24) NOT NULL,
  PRIMARY KEY (`palette`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `palette_names`
--

LOCK TABLES `palette_names` WRITE;
/*!40000 ALTER TABLE `palette_names` DISABLE KEYS */;
/*!40000 ALTER TABLE `palette_names` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `perks`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `perks` (
  `charidentifier` int(11) NOT NULL,
  `civxp` int(11) NOT NULL DEFAULT 0,
  `crimexp` int(11) NOT NULL DEFAULT 0,
  `bonusciv` int(11) NOT NULL DEFAULT 0,
  `bonuscrime` int(11) NOT NULL DEFAULT 0,
  `civtree` varchar(32) DEFAULT NULL,
  `crimetree` varchar(32) DEFAULT NULL,
  `bonuspoints` int(11) NOT NULL DEFAULT 0,
  `ranks` longtext DEFAULT NULL,
  `equipped` longtext DEFAULT NULL,
  `civbase` int(11) NOT NULL DEFAULT 0,
  `crimebase` int(11) NOT NULL DEFAULT 0,
  `lastreset` int(11) NOT NULL DEFAULT 0,
  `treexp` text DEFAULT NULL,
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `perks`
--

LOCK TABLES `perks` WRITE;
/*!40000 ALTER TABLE `perks` DISABLE KEYS */;
/*!40000 ALTER TABLE `perks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pet_coats`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pet_coats` (
  `charid` int(11) NOT NULL,
  `item` varchar(64) NOT NULL,
  `variant` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`,`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pet_coats`
--

LOCK TABLES `pet_coats` WRITE;
/*!40000 ALTER TABLE `pet_coats` DISABLE KEYS */;
/*!40000 ALTER TABLE `pet_coats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `phonographs`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `phonographs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `owner_identifier` varchar(255) DEFAULT NULL,
  `owner_charid` int(11) DEFAULT NULL,
  `x` double DEFAULT NULL,
  `y` double DEFAULT NULL,
  `z` double DEFAULT NULL,
  `rot_x` double DEFAULT NULL,
  `rot_y` double DEFAULT NULL,
  `rot_z` double DEFAULT NULL,
  `job` varchar(50) DEFAULT '',
  `rank` int(11) DEFAULT 0,
  `current_record` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `phonographs`
--

LOCK TABLES `phonographs` WRITE;
/*!40000 ALTER TABLE `phonographs` DISABLE KEYS */;
/*!40000 ALTER TABLE `phonographs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pinboard_posters`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pinboard_posters` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(16) NOT NULL,
  `content` longtext NOT NULL,
  `author_charid` int(11) NOT NULL,
  `author_name` varchar(128) DEFAULT NULL,
  `location` varchar(64) NOT NULL,
  `created_at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `location` (`location`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pinboard_posters`
--

LOCK TABLES `pinboard_posters` WRITE;
/*!40000 ALTER TABLE `pinboard_posters` DISABLE KEYS */;
/*!40000 ALTER TABLE `pinboard_posters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `player_ranch`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `player_ranch` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) DEFAULT NULL,
  `charidentifier` int(11) DEFAULT NULL,
  `name` longtext DEFAULT NULL,
  `price` float DEFAULT NULL,
  `coords` longtext DEFAULT '[]',
  `owned` int(11) DEFAULT 0,
  `herdtrail` longtext DEFAULT '[]',
  `cattle` longtext DEFAULT '[]',
  `q_cattle` longtext DEFAULT '[]',
  `dist` int(11) DEFAULT NULL,
  `chores` longtext DEFAULT '[]',
  `cows` longtext DEFAULT '[]',
  `chickens` longtext DEFAULT '[]',
  `milk` int(11) DEFAULT 0,
  `eggs` int(11) DEFAULT 0,
  `ledger` float DEFAULT 0,
  `dog` varchar(50) DEFAULT '0',
  `q_ranch` int(11) DEFAULT 0,
  `repoed` int(11) DEFAULT 0,
  `herding` int(11) DEFAULT 0,
  `selling` int(11) DEFAULT 0,
  `milking` int(11) DEFAULT 0,
  `checking` int(11) DEFAULT 0,
  `tax` int(11) DEFAULT 0,
  `hired` longtext DEFAULT '[]',
  `webhook` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `player_ranch`
--

LOCK TABLES `player_ranch` WRITE;
/*!40000 ALTER TABLE `player_ranch` DISABLE KEYS */;
/*!40000 ALTER TABLE `player_ranch` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `player_trains`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `player_trains` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '0',
  `contid` int(11) DEFAULT NULL,
  `maint` float DEFAULT 100,
  `coal` int(11) DEFAULT 0,
  `coalcap` int(11) DEFAULT NULL,
  `speed` float DEFAULT NULL,
  `hash` varchar(50) DEFAULT NULL,
  `company` varchar(50) DEFAULT NULL,
  `coalcon` int(11) DEFAULT NULL,
  `img` varchar(50) DEFAULT NULL,
  `coalup` int(11) DEFAULT 0,
  `speedup` int(11) DEFAULT 0,
  `items` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `player_trains`
--

LOCK TABLES `player_trains` WRITE;
/*!40000 ALTER TABLE `player_trains` DISABLE KEYS */;
/*!40000 ALTER TABLE `player_trains` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `playerfarms`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `playerfarms` (
  `charid` int(11) NOT NULL,
  `farm` longtext NOT NULL DEFAULT '[]',
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `playerfarms`
--

LOCK TABLES `playerfarms` WRITE;
/*!40000 ALTER TABLE `playerfarms` DISABLE KEYS */;
/*!40000 ALTER TABLE `playerfarms` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `playerhousing`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `playerhousing` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` int(11) NOT NULL DEFAULT 0,
  `primarydoor` longtext NOT NULL DEFAULT '[]',
  `otherdoors` longtext NOT NULL DEFAULT '[]',
  `range` int(11) DEFAULT 0,
  `owned` int(11) DEFAULT 0,
  `selleridentifier` varchar(50) NOT NULL DEFAULT '',
  `sellercharidentifier` int(11) NOT NULL DEFAULT 0,
  `ledger` double NOT NULL DEFAULT 0,
  `tax` int(11) NOT NULL DEFAULT 0,
  `repoed` int(11) NOT NULL DEFAULT 0,
  `invspace` int(11) NOT NULL DEFAULT 0,
  `upgrade` int(11) NOT NULL DEFAULT 0,
  `keyholders` longtext NOT NULL DEFAULT '[]',
  `changingroom` longtext NOT NULL DEFAULT '[]',
  `inventorylocation` longtext NOT NULL DEFAULT '[]',
  `items` longtext NOT NULL DEFAULT '[]',
  `furniture` longtext NOT NULL DEFAULT '[]',
  `price` int(11) NOT NULL DEFAULT 0,
  `buyeridentifier` varchar(50) NOT NULL DEFAULT '0',
  `buyercharidentifier` int(11) NOT NULL DEFAULT 0,
  `taxledger` int(11) DEFAULT 0,
  `motel` longtext DEFAULT '0',
  `webhook` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `id` (`id`),
  KEY `primarydoor` (`primarydoor`(768))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `playerhousing`
--

LOCK TABLES `playerhousing` WRITE;
/*!40000 ALTER TABLE `playerhousing` DISABLE KEYS */;
/*!40000 ALTER TABLE `playerhousing` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `playerhousing_sold_home_ledger`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `playerhousing_sold_home_ledger` (
  `id` int(11) NOT NULL DEFAULT 0,
  `identifier` varchar(50) DEFAULT NULL,
  `charidentifier` int(11) DEFAULT NULL,
  `amount` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `playerhousing_sold_home_ledger`
--

LOCK TABLES `playerhousing_sold_home_ledger` WRITE;
/*!40000 ALTER TABLE `playerhousing_sold_home_ledger` DISABLE KEYS */;
/*!40000 ALTER TABLE `playerhousing_sold_home_ledger` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `playerscenes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `playerscenes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) DEFAULT NULL,
  `coords` longtext DEFAULT '{}',
  `text` longtext DEFAULT '',
  `style` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `playerscenes`
--

LOCK TABLES `playerscenes` WRITE;
/*!40000 ALTER TABLE `playerscenes` DISABLE KEYS */;
/*!40000 ALTER TABLE `playerscenes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `playershops`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `playershops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) NOT NULL DEFAULT '0',
  `charidentifier` int(11) NOT NULL DEFAULT 0,
  `items` longtext NOT NULL DEFAULT '[]',
  `weapons` longtext NOT NULL DEFAULT '[]',
  `price` float NOT NULL DEFAULT 0,
  `name` varchar(50) NOT NULL DEFAULT '',
  `slots` int(11) NOT NULL DEFAULT 0,
  `coords` longtext NOT NULL DEFAULT '[]',
  `owned` int(11) DEFAULT 0,
  `blip` int(11) DEFAULT 1,
  `ledger` double DEFAULT 0,
  `level` int(255) DEFAULT 0,
  `taxledger` double DEFAULT 0,
  `repo` int(11) DEFAULT 0,
  `buyitems` longtext DEFAULT '{}',
  `webhook` longtext DEFAULT '',
  `manager` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `playershops`
--

LOCK TABLES `playershops` WRITE;
/*!40000 ALTER TABLE `playershops` DISABLE KEYS */;
/*!40000 ALTER TABLE `playershops` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `police_badge_offsets`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `police_badge_offsets` (
  `charid` int(11) NOT NULL,
  `offset` text NOT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `police_badge_offsets`
--

LOCK TABLES `police_badge_offsets` WRITE;
/*!40000 ALTER TABLE `police_badge_offsets` DISABLE KEYS */;
/*!40000 ALTER TABLE `police_badge_offsets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `prop_offsets`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `prop_offsets` (
  `charidentifier` int(11) NOT NULL,
  `item` varchar(64) NOT NULL,
  `x` float NOT NULL DEFAULT 0,
  `y` float NOT NULL DEFAULT 0,
  `z` float NOT NULL DEFAULT 0,
  `rx` float NOT NULL DEFAULT 0,
  `ry` float NOT NULL DEFAULT 0,
  `rz` float NOT NULL DEFAULT 0,
  PRIMARY KEY (`charidentifier`,`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `prop_offsets`
--

LOCK TABLES `prop_offsets` WRITE;
/*!40000 ALTER TABLE `prop_offsets` DISABLE KEYS */;
/*!40000 ALTER TABLE `prop_offsets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admin_ban_identities`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_ban_identities` (
  `steam` varchar(50) NOT NULL,
  `license` varchar(80) NOT NULL DEFAULT '',
  `license2` varchar(80) NOT NULL DEFAULT '',
  `discord` varchar(40) NOT NULL DEFAULT '',
  `ip` varchar(64) NOT NULL DEFAULT '',
  `tokens` longtext DEFAULT NULL,
  `playername` varchar(100) NOT NULL DEFAULT '',
  `last_seen` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`steam`),
  KEY `license_idx` (`license`),
  KEY `last_seen_idx` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_ban_identities`
--

LOCK TABLES `admin_ban_identities` WRITE;
/*!40000 ALTER TABLE `admin_ban_identities` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin_ban_identities` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admin_bans`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ban_id` varchar(16) NOT NULL,
  `charid` int(11) DEFAULT NULL,
  `charname` varchar(100) NOT NULL DEFAULT '',
  `playername` varchar(100) NOT NULL DEFAULT '',
  `license` varchar(80) NOT NULL DEFAULT '',
  `license2` varchar(80) NOT NULL DEFAULT '',
  `steam` varchar(50) NOT NULL DEFAULT '',
  `discord` varchar(40) NOT NULL DEFAULT '',
  `xbl` varchar(40) NOT NULL DEFAULT '',
  `liveid` varchar(40) NOT NULL DEFAULT '',
  `ip` varchar(64) NOT NULL DEFAULT '',
  `tokens` longtext DEFAULT NULL,
  `reason` varchar(512) NOT NULL DEFAULT '',
  `staff` varchar(100) NOT NULL DEFAULT '',
  `created` timestamp NOT NULL DEFAULT current_timestamp(),
  `expires` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `unbanned_by` varchar(100) DEFAULT NULL,
  `unbanned_at` timestamp NULL DEFAULT NULL,
  `ban_count` int(11) NOT NULL DEFAULT 1,
  `first_banned` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ban_id_idx` (`ban_id`),
  KEY `license_idx` (`license`),
  KEY `steam_idx` (`steam`),
  KEY `discord_idx` (`discord`),
  KEY `active_idx` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_bans`
--

LOCK TABLES `admin_bans` WRITE;
/*!40000 ALTER TABLE `admin_bans` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin_bans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `character_codes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `character_codes` (
  `code` varchar(12) NOT NULL,
  `sex` varchar(16) NOT NULL,
  `skin` longtext NOT NULL,
  `comps` longtext NOT NULL,
  `tints` longtext DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `uses` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`code`),
  KEY `created_by` (`created_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `character_codes`
--

LOCK TABLES `character_codes` WRITE;
/*!40000 ALTER TABLE `character_codes` DISABLE KEYS */;
/*!40000 ALTER TABLE `character_codes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `inventory_layout`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `inventory_layout` (
  `inventory_type` varchar(100) NOT NULL,
  `item_key` varchar(80) NOT NULL,
  `slot` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`inventory_type`,`item_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `inventory_layout`
--

LOCK TABLES `inventory_layout` WRITE;
/*!40000 ALTER TABLE `inventory_layout` DISABLE KEYS */;
/*!40000 ALTER TABLE `inventory_layout` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ranch_activity`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ranch_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ranchid` int(11) NOT NULL,
  `ts` int(11) NOT NULL,
  `type` varchar(20) NOT NULL,
  `detail` varchar(191) NOT NULL DEFAULT '',
  `actor` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ranch_activity`
--

LOCK TABLES `ranch_activity` WRITE;
/*!40000 ALTER TABLE `ranch_activity` DISABLE KEYS */;
/*!40000 ALTER TABLE `ranch_activity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ranch_fresh`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ranch_fresh` (
  `ranchid` int(11) NOT NULL,
  `animal` varchar(50) NOT NULL,
  PRIMARY KEY (`ranchid`,`animal`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ranch_fresh`
--

LOCK TABLES `ranch_fresh` WRITE;
/*!40000 ALTER TABLE `ranch_fresh` DISABLE KEYS */;
/*!40000 ALTER TABLE `ranch_fresh` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ranch_herds`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ranch_herds` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ranchid` int(11) NOT NULL,
  `charid` int(11) NOT NULL,
  `name` varchar(100) NOT NULL DEFAULT '',
  `animal` varchar(50) NOT NULL DEFAULT '',
  `started` int(11) NOT NULL DEFAULT 0,
  `survived` int(11) NOT NULL DEFAULT 0,
  `quality` double NOT NULL DEFAULT 0,
  `ts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `ranch_ts` (`ranchid`,`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ranch_herds`
--

LOCK TABLES `ranch_herds` WRITE;
/*!40000 ALTER TABLE `ranch_herds` DISABLE KEYS */;
/*!40000 ALTER TABLE `ranch_herds` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ranch_paycfg`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ranch_paycfg` (
  `ranchid` int(11) NOT NULL,
  `milk_price` double NOT NULL DEFAULT 1.25,
  `egg_price` double NOT NULL DEFAULT 1.25,
  `reset_period` varchar(16) NOT NULL DEFAULT 'never',
  `last_reset` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`ranchid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ranch_stats`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ranch_stats` (
  `charid` int(11) NOT NULL,
  `ranchid` int(11) NOT NULL,
  `name` varchar(100) NOT NULL DEFAULT '',
  `milk` int(11) NOT NULL DEFAULT 0,
  `eggs` int(11) NOT NULL DEFAULT 0,
  `chores` int(11) NOT NULL DEFAULT 0,
  `chore_score` int(11) NOT NULL DEFAULT 0,
  `herds` int(11) NOT NULL DEFAULT 0,
  `herd_animals` int(11) NOT NULL DEFAULT 0,
  `herd_quality` double NOT NULL DEFAULT 0,
  `first_ts` int(11) NOT NULL DEFAULT 0,
  `last_ts` int(11) NOT NULL DEFAULT 0,
  `cattle_money` double NOT NULL DEFAULT 0,
  `discord` varchar(32) NOT NULL DEFAULT '',
  `p_milk` int(11) NOT NULL DEFAULT 0,
  `p_eggs` int(11) NOT NULL DEFAULT 0,
  `p_chores` int(11) NOT NULL DEFAULT 0,
  `p_herds` int(11) NOT NULL DEFAULT 0,
  `p_herd_animals` int(11) NOT NULL DEFAULT 0,
  `p_herd_quality` double NOT NULL DEFAULT 0,
  `p_cattle_money` double NOT NULL DEFAULT 0,
  `herd_lost` int(11) NOT NULL DEFAULT 0,
  `p_herd_lost` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`,`ranchid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ranch_stats`
--

LOCK TABLES `ranch_stats` WRITE;
/*!40000 ALTER TABLE `ranch_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `ranch_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ranch_stats_meta`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ranch_stats_meta` (
  `k` varchar(50) NOT NULL,
  `v` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ranch_stats_meta`
--

LOCK TABLES `ranch_stats_meta` WRITE;
/*!40000 ALTER TABLE `ranch_stats_meta` DISABLE KEYS */;
/*!40000 ALTER TABLE `ranch_stats_meta` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `recomp_namecd`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recomp_namecd` (
  `kind` varchar(16) NOT NULL,
  `ref` varchar(64) NOT NULL,
  `named_at` int(11) NOT NULL,
  PRIMARY KEY (`kind`,`ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recomp_namecd`
--

LOCK TABLES `recomp_namecd` WRITE;
/*!40000 ALTER TABLE `recomp_namecd` DISABLE KEYS */;
/*!40000 ALTER TABLE `recomp_namecd` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `recomps`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recomps` (
  `discordid` varchar(50) NOT NULL DEFAULT '',
  `cash` varchar(50) DEFAULT '0',
  `items` longtext DEFAULT '[]',
  `weapons` longtext DEFAULT '[]',
  PRIMARY KEY (`discordid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recomps`
--

LOCK TABLES `recomps` WRITE;
/*!40000 ALTER TABLE `recomps` DISABLE KEYS */;
/*!40000 ALTER TABLE `recomps` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `robbery_cooldowns`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `robbery_cooldowns` (
  `scope` varchar(16) NOT NULL,
  `ckey` varchar(64) NOT NULL,
  `expires` int(11) NOT NULL,
  PRIMARY KEY (`scope`,`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `robbery_cooldowns`
--

LOCK TABLES `robbery_cooldowns` WRITE;
/*!40000 ALTER TABLE `robbery_cooldowns` DISABLE KEYS */;
/*!40000 ALTER TABLE `robbery_cooldowns` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `robbery_fence_payouts`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `robbery_fence_payouts` (
  `charidentifier` int(11) NOT NULL,
  `amount` int(11) NOT NULL DEFAULT 0,
  `readyAt` int(11) NOT NULL,
  `mailed` tinyint(4) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `robbery_fence_payouts`
--

LOCK TABLES `robbery_fence_payouts` WRITE;
/*!40000 ALTER TABLE `robbery_fence_payouts` DISABLE KEYS */;
/*!40000 ALTER TABLE `robbery_fence_payouts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `robbery_fence_rep`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `robbery_fence_rep` (
  `charidentifier` int(11) NOT NULL,
  `rep` int(11) NOT NULL DEFAULT 0,
  `sales` int(11) NOT NULL DEFAULT 0,
  `value` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `robbery_fence_rep`
--

LOCK TABLES `robbery_fence_rep` WRITE;
/*!40000 ALTER TABLE `robbery_fence_rep` DISABLE KEYS */;
/*!40000 ALTER TABLE `robbery_fence_rep` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `robbery_history`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `robbery_history` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bank` varchar(64) NOT NULL,
  `outcome` varchar(16) NOT NULL,
  `crew` text DEFAULT NULL,
  `lootTaken` int(11) NOT NULL DEFAULT 0,
  `lootTotal` int(11) NOT NULL DEFAULT 0,
  `alarmPeak` int(11) NOT NULL DEFAULT 0,
  `duration` int(11) NOT NULL DEFAULT 0,
  `at` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `robbery_history`
--

LOCK TABLES `robbery_history` WRITE;
/*!40000 ALTER TABLE `robbery_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `robbery_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `shaman_afflictions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `shaman_afflictions` (
  `charid` int(11) NOT NULL,
  `curse` varchar(32) NOT NULL,
  `started_at` int(11) NOT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `shaman_afflictions`
--

LOCK TABLES `shaman_afflictions` WRITE;
/*!40000 ALTER TABLE `shaman_afflictions` DISABLE KEYS */;
/*!40000 ALTER TABLE `shaman_afflictions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `smokes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `smokes` (
  `name` varchar(64) NOT NULL,
  `pipe` tinyint(1) NOT NULL DEFAULT 0,
  `subitem` tinyint(1) NOT NULL DEFAULT 1,
  `typeof` varchar(16) NOT NULL DEFAULT 'cigar',
  `high` tinyint(1) NOT NULL DEFAULT 0,
  `hightype` varchar(64) NOT NULL DEFAULT '',
  `highduration` int(11) NOT NULL DEFAULT 0,
  `boost` tinyint(1) NOT NULL DEFAULT 0,
  `healthboost` float NOT NULL DEFAULT 0,
  `staminaboost` float NOT NULL DEFAULT 0,
  `drunkamount` float NOT NULL DEFAULT 0,
  `drunkscreen` float NOT NULL DEFAULT 0,
  `drunkwalk` float NOT NULL DEFAULT 0,
  `turbo` tinyint(1) NOT NULL DEFAULT 0,
  `effectinterval` int(11) NOT NULL DEFAULT 10,
  `effects` longtext DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `smokes`
--

LOCK TABLES `smokes` WRITE;
/*!40000 ALTER TABLE `smokes` DISABLE KEYS */;
INSERT INTO `smokes` VALUES ('cigar',0,1,'cigar',0,'',0,0,0,0,0,0,0,0,10,'[]'),('cigarette',0,1,'cigarette',0,'',0,0,0,0,0,0,0,0,10,'[]'),('drugalsashes',1,1,'pipe',1,'KingCastleRed',120,1,1750,0,0,0,0,0,10,'[]'),('drugbamsburners',0,1,'cigar',1,'photomode_filtermodern03',120,1,2250,0,0,0,0,0,10,'[]'),('drugbamsrubies',1,1,'pipe',1,'Photomode_flitermodern01',120,1,2000,250,0,0,0,0,10,'[]'),('drugbamswhitecrystals',1,1,'pipe',1,'Photomode_FilterModern03',120,1,0,2250,0,0,0,0,10,'[]'),('drugbastardsbreath',1,1,'pipe',1,'MP_DeathInk_Color08',120,1,2000,250,0,0,0,0,10,'[]'),('drugbayoucigar',0,1,'cigar',1,'MP_Deathink_color02',120,1,2250,0,0,0,0,0,10,'[]'),('drugbayoucrack',1,1,'pipe',1,'Photomode_flitermodern02',120,1,2250,0,0,0,0,0,10,'[]'),('drugbayouhash',1,1,'pipe',1,'KingCastleRed',120,1,2250,0,0,0,0,0,10,'[]'),('drugbayouspliff',0,1,'cigar',1,'PhotoMode_filterModern02',120,1,2250,0,0,0,0,0,10,'[]'),('drugblackbaronboblesmoke',1,1,'pipe',1,'Photomode_FilterGame02',120,1,2250,0,0,0,0,0,10,'[]'),('drugblackpowder',1,1,'pipe',1,'KingCastleRed',120,1,2250,0,0,0,0,0,10,'[]'),('drugbloodmooncigar',0,1,'cigar',1,'KingCastleRed',120,1,2250,0,0,0,0,0,10,'[]'),('drugbrownsugar',1,1,'pipe',1,'PhotoMode_FilterModern02',120,1,2250,0,0,0,0,0,10,'[]'),('drugbtbcigar',0,1,'cigar',1,'MP_DEATHINK_COLOR03',120,1,2000,250,0,0,0,0,10,'[]'),('drugbullmooseblend',1,1,'pipe',1,'MP_DeathInk_Color01',120,1,2250,0,0,0,0,0,10,'[]'),('drugchieftainspeacepipe',1,1,'pipe',1,'PhotoMode_Filtermodern04',120,1,2250,0,0,0,0,0,10,'[]'),('drugchqofa',1,1,'pipe',1,'PhotoMode_FilterModern02',120,1,2250,0,0,0,0,0,10,'[]'),('drugcoltonsmiracle',1,1,'pipe',1,'PhotoMode_FilterModern02',120,1,2250,0,0,0,0,0,10,'[]'),('drugcortezironleadcigar',0,1,'cigar',1,'MP_DeathInk_Color01',120,1,2250,0,0,0,0,0,10,'[]'),('drugcranstonscrown',0,1,'cigar',1,'MP_DeathInk_Color06',120,1,2250,0,0,0,0,0,10,'[]'),('drugcrosscigar',0,1,'cigar',1,'MP_DEATHINK_COLOR10',120,1,2250,0,0,0,0,0,10,'[]'),('drugcruxcineris',0,1,'cigar',1,'PhotoMode_FilterModern01',120,1,2250,0,0,0,0,0,10,'[]'),('drugdajnessweetleaf',1,1,'pipe',1,'Photomode_FilterModern03',120,1,0,2250,0,0,0,0,10,'[]'),('drugdevilsgrin',1,1,'pipe',1,'MP_DeathInk_Color02',120,1,2250,0,0,0,0,0,10,'[]'),('drugdevilslungs',1,1,'pipe',1,'MP_DEATHINK_COLOR06',120,1,2000,250,0,0,0,0,10,'[]'),('drugdewkiescannabis',1,1,'pipe',1,'MP_DeathInk_Color06',120,1,2250,0,0,0,0,0,10,'[]'),('drugdonkslastpuff',1,1,'pipe',1,'KingCastleBlue',120,1,2250,0,0,0,0,0,10,'[]'),('drugdragondream',1,1,'pipe',1,'KingCastleBlue',120,1,2250,0,0,0,0,0,10,'[]'),('drugdragonsbreath',1,1,'pipe',1,'MP_DeathInk_Color03',120,1,2250,0,0,0,0,0,10,'[]'),('drugdudiodoublepuff',0,1,'cigar',1,'MP_DeathInk_Color08',120,1,2250,0,0,0,0,0,10,'[]'),('drugdwightsdoobie',0,1,'cigar',1,'KingCastleBlue',120,1,2250,0,0,0,0,0,10,'[]'),('drugflacocigar',0,1,'cigar',1,'PhotoMode_FilterModern02',120,1,2250,0,0,0,0,0,10,'[]'),('druggoldenstogie',0,1,'cigar',1,'PhotoMode_FilterGame18',120,1,2000,250,0,0,0,0,10,'[]'),('druggravelight',1,1,'pipe',1,'MP_DeathInk_Color03',120,1,2250,0,0,0,0,0,10,'[]'),('druglaminarlog',0,1,'cigar',1,'PhotoMode_FilterModern03',120,1,2000,250,0,0,0,0,10,'[]'),('druglegacycowboykiller',0,1,'cigar',1,'PhotoMode_FilterModern07',120,1,2250,0,0,0,0,0,10,'[]'),('druglegacysmackers',0,1,'cigar',1,'PhotoMode_FilterGame10',120,1,2250,0,0,0,0,0,10,'[]'),('druglungbuster',1,1,'pipe',1,'PhotoMode_FilterGame11',120,1,2250,0,0,0,0,0,10,'[]'),('drugmccarthysrocks',1,1,'pipe',1,'Photomode_Filtergame10',120,1,2250,0,0,0,0,0,10,'[]'),('drugmccormicks',0,1,'cigar',1,'PHOTOMODE_FILTERMODERN04',120,1,2250,0,0,0,0,0,10,'[]'),('drugmidnightdelight',1,1,'pipe',1,'PhotoMode_FilterModern03',120,1,2250,0,0,0,0,0,10,'[]'),('drugnorthernlights',1,1,'pipe',1,'MP_Deathink_color01',120,1,2250,0,0,0,0,0,10,'[]'),('drugpieceofcandy',1,1,'pipe',1,'KingCastleBlue',120,1,2000,250,0,0,0,0,10,'[]'),('drugreapersripper',0,1,'cigar',1,'MP_ArrowDrain',120,1,2250,0,0,0,0,0,10,'[]'),('drugredsage',1,1,'pipe',1,'Playerdrughalluc01',120,1,1125,1125,0,0,0,0,10,'[]'),('drugrivieraroughcut',1,1,'pipe',1,'MP_Deathink_color05',120,1,2250,0,0,0,0,0,10,'[]'),('drugroyalflush',0,1,'cigar',1,'MP_DEATHINK_COLOR02',120,1,2250,0,0,0,0,0,10,'[]'),('drugrunapockoresolve',0,1,'cigar',1,'PhotoMode_Filtermodern04',120,1,2250,0,0,0,0,0,10,'[]'),('drugsabatinocubano',0,1,'cigar',1,'MP_DeathInk_Color01',120,1,2000,250,0,0,0,0,10,'[]'),('drugsaltypickaxe',1,1,'pipe',1,'PhotoMode_FilterGame10',120,1,2250,0,0,0,0,0,10,'[]'),('drugshadowleaf',1,1,'pipe',1,'MP_DEATHINK_COLORO7',120,1,1750,0,0,0,0,0,10,'[]'),('drugshroudededge',1,1,'pipe',1,'MP_DeathInk_Color03',120,1,2250,0,0,0,0,0,10,'[]'),('drugsilvercutcigar',0,1,'cigar',1,'MP_DeathInk_Color01',120,1,2250,0,0,0,0,0,10,'[]'),('drugswampstogie',0,1,'cigar',1,'Photomode_FilterModern02',120,1,2250,0,0,0,0,0,10,'[]'),('drugsweethearts',1,1,'pipe',1,'MP_DeathInk_Color01',120,1,2250,0,0,0,0,0,10,'[]'),('drugtahitismangos',1,1,'pipe',1,'PhotoMode_FilterGame13',120,1,1750,0,0,0,0,0,10,'[]'),('drugtigranesroar',1,1,'pipe',1,'PhotoMode_Filtermodern04',120,1,2250,0,0,0,0,0,10,'[]'),('drugtimberlinecut',0,1,'cigar',1,'KingCastleBlue',120,1,2250,0,0,0,0,0,10,'[]'),('drugundertakerskiss',0,1,'cigar',1,'MP_DeathInk_Color02',120,1,2250,0,0,0,0,0,10,'[]'),('drugvitositaliancigar',0,1,'cigar',1,'MP_DeathInk_Color03',120,1,2250,0,0,0,0,0,10,'[]'),('drugyouvebeendone',0,1,'cigar',1,'PhotoMode_FilterModern02',120,1,1750,0,0,0,0,0,10,'[]'),('joint',0,1,'cigarette',1,'PlayerRPGcore',60,1,1000,1000,100,5,0,0,10,'[]'),('pure',1,1,'pipe',1,'PhotoMode_FilterModern09',300,1,10000,2500,200,10,0.5,0,10,'[]'),('rosebloom_cigar',0,1,'cigar',1,'PlayerRPGcore',300,1,2500,2500,100,5,0.5,0,0,'[]'),('siphopure',1,1,'pipe',1,'PhotoMode_FilterModern09',2700,1,10000,5000,200,10,0.8,1,150,'[\"PlayerDrunk01\",\"playerdrugshalluc01\",\"KingCastleBlue\",\"KingCastleRed\",\"PlayerRPGCore\",\"MP_ArrowDrain\",\"MP_DeathInk_Color01\",\"MP_DeathInk_Color02\",\"MP_DeathInk_Color03\",\"MP_DeathInk_Color04\",\"MP_DeathInk_Color05\",\"MP_DeathInk_Color06\",\"MP_DeathInk_Color07\",\"MP_DeathInk_Color08\",\"MP_DeathInk_Color09\",\"MP_DeathInk_Color10\",\"MP_ArrowTracking\",\"MP_BountyLagrasSwamp\",\"PhotoMode_FilterGame01\",\"PhotoMode_FilterGame02\",\"PhotoMode_FilterGame03\",\"PhotoMode_FilterGame04\",\"PhotoMode_FilterGame05\",\"PhotoMode_FilterGame06\",\"PhotoMode_FilterGame07\",\"PhotoMode_FilterGame08\",\"PhotoMode_FilterGame09\",\"PhotoMode_FilterGame10\",\"PhotoMode_FilterGame11\",\"PhotoMode_FilterGame12\",\"PhotoMode_FilterGame13\",\"PhotoMode_FilterGame14\",\"PhotoMode_FilterGame15\",\"PhotoMode_FilterGame16\",\"PhotoMode_FilterGame17\",\"PhotoMode_FilterGame18\",\"PhotoMode_FilterModern01\",\"PhotoMode_FilterModern02\",\"PhotoMode_FilterModern03\",\"PhotoMode_FilterModern04\",\"PhotoMode_FilterModern05\",\"PhotoMode_FilterModern06\",\"PhotoMode_FilterModern07\",\"PhotoMode_FilterModern08\",\"PhotoMode_FilterModern09\",\"PhotoMode_FilterModern10\",\"PhotoMode_FilterVintage01\",\"PhotoMode_FilterVintage02\",\"PhotoMode_FilterVintage03\",\"PhotoMode_FilterVintage04\",\"PhotoMode_FilterVintage05\",\"PhotoMode_FilterVintage06\",\"PhotoMode_FilterVintage07\",\"PhotoMode_FilterVintage08\",\"PhotoMode_FilterVintage09\",\"PhotoMode_FilterVintage10\"]');
/*!40000 ALTER TABLE `smokes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `society`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `society` (
  `job` longtext DEFAULT NULL,
  `jobgrade` int(11) DEFAULT NULL,
  `salary` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `society_activity`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `society_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(50) NOT NULL,
  `ts` int(11) NOT NULL,
  `type` varchar(20) NOT NULL,
  `detail` varchar(255) NOT NULL DEFAULT '',
  `actor` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `job_ts` (`job`,`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `society_activity`
--

LOCK TABLES `society_activity` WRITE;
/*!40000 ALTER TABLE `society_activity` DISABLE KEYS */;
/*!40000 ALTER TABLE `society_activity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `society_business`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `society_business` (
  `job` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL DEFAULT '',
  `blipsprite` bigint(20) NOT NULL DEFAULT 778811758,
  `showblip` tinyint(1) NOT NULL DEFAULT 1,
  `recruitmentrank` int(11) NOT NULL DEFAULT 0,
  `bossrank` int(11) NOT NULL DEFAULT 1,
  `containerid` int(11) NOT NULL,
  `containername` varchar(100) NOT NULL DEFAULT 'Storage',
  `billing` tinyint(1) NOT NULL DEFAULT 1,
  `webhook` tinyint(1) NOT NULL DEFAULT 0,
  `salary` tinyint(1) NOT NULL DEFAULT 1,
  `positions` longtext NOT NULL,
  `jobmenu` longtext NOT NULL,
  `created_by` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `tax` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`job`),
  UNIQUE KEY `containerid` (`containerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `society_ledger`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `society_ledger` (
  `job` longtext DEFAULT NULL,
  `ledger` int(11) NOT NULL DEFAULT 0,
  `webhook` longtext DEFAULT NULL,
  `invaccess` int(11) NOT NULL DEFAULT 0,
  UNIQUE KEY `job_unique` (`job`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `society_ranks`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `society_ranks` (
  `job` varchar(50) NOT NULL,
  `grade` int(11) NOT NULL,
  `salary` int(11) NOT NULL DEFAULT 0,
  `perms` longtext NOT NULL DEFAULT '{}',
  `tax` int(11) NOT NULL DEFAULT 0,
  `taxperiod` varchar(10) NOT NULL DEFAULT 'weekly',
  `taxsince` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`job`,`grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `society_shops`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `society_shops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `society` varchar(50) NOT NULL DEFAULT '0',
  `items` longtext NOT NULL DEFAULT '[]',
  `weapons` longtext NOT NULL DEFAULT '[]',
  `slots` int(11) NOT NULL DEFAULT 50,
  `level` int(11) NOT NULL DEFAULT 0,
  `name` varchar(50) DEFAULT '',
  `coords` longtext DEFAULT '{}',
  `rank` int(11) DEFAULT 0,
  `blip` int(11) DEFAULT 0,
  `buyitems` longtext DEFAULT '{}',
  `webhook` longtext DEFAULT '{}',
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `society_tax`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `society_tax` (
  `charidentifier` int(11) NOT NULL,
  `job` varchar(50) NOT NULL,
  `grade` int(11) NOT NULL DEFAULT 0,
  `anchor` int(11) NOT NULL DEFAULT 0,
  `paidperiods` int(11) NOT NULL DEFAULT 0,
  `lastpaid` int(11) DEFAULT NULL,
  PRIMARY KEY (`charidentifier`,`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `society_tax`
--

LOCK TABLES `society_tax` WRITE;
/*!40000 ALTER TABLE `society_tax` DISABLE KEYS */;
/*!40000 ALTER TABLE `society_tax` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `spawnselect`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `spawnselect` (
  `charidentifier` int(11) NOT NULL,
  `last_pick` int(11) NOT NULL DEFAULT 0,
  `last_drop` int(11) NOT NULL DEFAULT 0,
  `picks` int(11) NOT NULL DEFAULT 0,
  `last_label` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spawnselect`
--

LOCK TABLES `spawnselect` WRITE;
/*!40000 ALTER TABLE `spawnselect` DISABLE KEYS */;
/*!40000 ALTER TABLE `spawnselect` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stable_bought`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stable_bought` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) NOT NULL,
  `charid` int(11) NOT NULL,
  `category` varchar(50) NOT NULL,
  `hash` bigint(20) NOT NULL,
  `equiped_on` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`,`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stable_bought`
--

LOCK TABLES `stable_bought` WRITE;
/*!40000 ALTER TABLE `stable_bought` DISABLE KEYS */;
/*!40000 ALTER TABLE `stable_bought` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stable_bred`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stable_bred` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `stableid` varchar(50) NOT NULL,
  `job` varchar(50) NOT NULL DEFAULT '',
  `horseid` int(11) NOT NULL,
  `variation` int(11) NOT NULL DEFAULT 1,
  `model` varchar(100) NOT NULL,
  `name` varchar(100) NOT NULL,
  `price` int(11) NOT NULL,
  `palette` varchar(64) DEFAULT NULL,
  `tint0` smallint(6) NOT NULL DEFAULT 0,
  `tint1` smallint(6) NOT NULL DEFAULT 0,
  `tint2` smallint(6) NOT NULL DEFAULT 0,
  `scale` float NOT NULL DEFAULT 1,
  `stock` int(11) NOT NULL DEFAULT 0,
  `sold` int(11) NOT NULL DEFAULT 0,
  `bredby` varchar(50) DEFAULT NULL,
  `bredat` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `hairpalette` varchar(64) DEFAULT NULL,
  `htint0` smallint(6) NOT NULL DEFAULT 0,
  `htint1` smallint(6) NOT NULL DEFAULT 0,
  `htint2` smallint(6) NOT NULL DEFAULT 0,
  `sirebreed` varchar(100) DEFAULT NULL,
  `dambreed` varchar(100) DEFAULT NULL,
  `speed` smallint(6) DEFAULT NULL,
  `acceleration` smallint(6) DEFAULT NULL,
  `handling` smallint(6) DEFAULT NULL,
  `health` smallint(6) DEFAULT NULL,
  `stamina` smallint(6) DEFAULT NULL,
  `readyat` int(11) NOT NULL DEFAULT 0,
  `siremodel` varchar(100) DEFAULT NULL,
  `dammodel` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `stableid` (`stableid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stable_bred`
--

LOCK TABLES `stable_bred` WRITE;
/*!40000 ALTER TABLE `stable_bred` DISABLE KEYS */;
/*!40000 ALTER TABLE `stable_bred` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stable_color`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stable_color` (
  `id` int(11) NOT NULL,
  `drawable` int(11) DEFAULT NULL,
  `albedo` int(11) DEFAULT NULL,
  `normal` int(11) DEFAULT NULL,
  `material` int(11) DEFAULT NULL,
  `palette` varchar(100) DEFAULT NULL,
  `tint0` tinyint(3) unsigned DEFAULT NULL,
  `tint1` tinyint(3) unsigned DEFAULT NULL,
  `tint2` tinyint(3) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `pup_stable_color_ibfk_1` FOREIGN KEY (`id`) REFERENCES `stable_bought` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stable_color`
--

LOCK TABLES `stable_color` WRITE;
/*!40000 ALTER TABLE `stable_color` DISABLE KEYS */;
/*!40000 ALTER TABLE `stable_color` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stable_horse_stats`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stable_horse_stats` (
  `horseid` int(11) NOT NULL,
  `distance` int(11) NOT NULL DEFAULT 0,
  `lastNewShoes` int(11) NOT NULL DEFAULT 0,
  `bonding` int(11) NOT NULL DEFAULT 0,
  `speedTraining` int(11) NOT NULL DEFAULT 0,
  `accelerationTraining` int(11) NOT NULL DEFAULT 0,
  `handlingTraining` int(11) NOT NULL DEFAULT 0,
  `stamina` int(11) NOT NULL DEFAULT 0,
  `health` int(11) NOT NULL DEFAULT 0,
  `xp` int(11) NOT NULL DEFAULT 0,
  `speedXP` int(11) NOT NULL DEFAULT 0,
  `accelerationXP` int(11) NOT NULL DEFAULT 0,
  `handlingXP` int(11) NOT NULL DEFAULT 0,
  `focus` varchar(20) DEFAULT NULL,
  `healthCore` int(11) NOT NULL DEFAULT 100,
  `staminaCore` int(11) NOT NULL DEFAULT 100,
  `pedStamina` int(11) NOT NULL DEFAULT 0,
  `restedAt` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`horseid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stable_horse_stats`
--

LOCK TABLES `stable_horse_stats` WRITE;
/*!40000 ALTER TABLE `stable_horse_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `stable_horse_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stable_horses`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stable_horses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) NOT NULL,
  `charid` int(11) NOT NULL,
  `stable` varchar(50) NOT NULL,
  `model` varchar(100) NOT NULL,
  `isFemale` tinyint(1) NOT NULL DEFAULT 0,
  `name` varchar(50) NOT NULL,
  `speed` tinyint(4) NOT NULL,
  `acceleration` tinyint(4) NOT NULL,
  `handling` tinyint(4) NOT NULL,
  `favourite` tinyint(1) NOT NULL DEFAULT 0,
  `isDead` tinyint(1) NOT NULL DEFAULT 0,
  `isOut` tinyint(1) NOT NULL DEFAULT 0,
  `baseSpeed` tinyint(4) DEFAULT NULL,
  `baseAcceleration` tinyint(4) DEFAULT NULL,
  `baseHandling` tinyint(4) DEFAULT NULL,
  `scale` float NOT NULL DEFAULT 1,
  `bred` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stable_horses`
--

LOCK TABLES `stable_horses` WRITE;
/*!40000 ALTER TABLE `stable_horses` DISABLE KEYS */;
/*!40000 ALTER TABLE `stable_horses` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50003 TRIGGER `add_stable_horse_stats` AFTER INSERT ON `stable_horses` FOR EACH ROW INSERT INTO stable_horse_stats (horseid) VALUES (NEW.id) */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50003 TRIGGER `update_stable_equiped_component` BEFORE DELETE ON `stable_horses` FOR EACH ROW UPDATE `stable_bought` SET equiped_on = 0 WHERE equiped_on = OLD.id */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50003 TRIGGER `delete_stable_horse_stats` AFTER DELETE ON `stable_horses` FOR EACH ROW DELETE FROM stable_horse_stats WHERE horseid = OLD.id */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `stable_starter`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stable_starter` (
  `charid` int(11) NOT NULL,
  `identifier` varchar(50) NOT NULL,
  `horseid` int(11) NOT NULL DEFAULT 0,
  `grantedat` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stable_starter`
--

LOCK TABLES `stable_starter` WRITE;
/*!40000 ALTER TABLE `stable_starter` DISABLE KEYS */;
/*!40000 ALTER TABLE `stable_starter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stable_wagons`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stable_wagons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) NOT NULL,
  `charid` int(11) NOT NULL,
  `stable` varchar(50) NOT NULL,
  `model` varchar(100) NOT NULL,
  `name` varchar(100) DEFAULT '',
  `vehicle_tints` int(11) NOT NULL DEFAULT -2,
  `vehicle_propsets` varchar(50) NOT NULL DEFAULT '-1',
  `vehicle_liveries` int(11) NOT NULL DEFAULT -1,
  `vehicle_lantern_propsets` varchar(50) NOT NULL DEFAULT '-1',
  `vehicle_extras` int(11) NOT NULL DEFAULT -1,
  `isOut` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stable_wagons`
--

LOCK TABLES `stable_wagons` WRITE;
/*!40000 ALTER TABLE `stable_wagons` DISABLE KEYS */;
/*!40000 ALTER TABLE `stable_wagons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stables`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stables` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) DEFAULT NULL,
  `charidentifier` int(11) NOT NULL,
  `name` varchar(30) NOT NULL,
  `modelname` varchar(70) NOT NULL,
  `type` varchar(11) NOT NULL,
  `status` longtext DEFAULT NULL,
  `xp` int(11) DEFAULT 0,
  `injured` int(11) DEFAULT 0,
  `gear` longtext DEFAULT NULL,
  `isDefault` int(11) NOT NULL DEFAULT 0,
  `inventory` longtext DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stables`
--

LOCK TABLES `stables` WRITE;
/*!40000 ALTER TABLE `stables` DISABLE KEYS */;
/*!40000 ALTER TABLE `stables` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `staffdesk_audit`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `staffdesk_audit` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `at` int(11) NOT NULL,
  `via` varchar(10) NOT NULL,
  `actor` varchar(100) NOT NULL,
  `command` varchar(32) NOT NULL,
  `args` varchar(255) NOT NULL DEFAULT '',
  `ok` tinyint(4) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_at` (`at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `staffdesk_audit`
--

LOCK TABLES `staffdesk_audit` WRITE;
/*!40000 ALTER TABLE `staffdesk_audit` DISABLE KEYS */;
/*!40000 ALTER TABLE `staffdesk_audit` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `staffdesk_bounty`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `staffdesk_bounty` (
  `charid` int(11) NOT NULL,
  `points` int(11) NOT NULL DEFAULT 0,
  `earned` int(11) NOT NULL DEFAULT 0,
  `spent` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `staffdesk_bounty`
--

LOCK TABLES `staffdesk_bounty` WRITE;
/*!40000 ALTER TABLE `staffdesk_bounty` DISABLE KEYS */;
/*!40000 ALTER TABLE `staffdesk_bounty` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `staffdesk_ledger`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `staffdesk_ledger` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) NOT NULL,
  `delta` int(11) NOT NULL,
  `reason` varchar(160) NOT NULL DEFAULT '',
  `by_name` varchar(100) NOT NULL DEFAULT '',
  `at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_char` (`charid`,`at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `staffdesk_ledger`
--

LOCK TABLES `staffdesk_ledger` WRITE;
/*!40000 ALTER TABLE `staffdesk_ledger` DISABLE KEYS */;
/*!40000 ALTER TABLE `staffdesk_ledger` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `staffdesk_milestones`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `staffdesk_milestones` (
  `charid` int(11) NOT NULL,
  `hours` int(11) NOT NULL,
  `paid_at` int(11) NOT NULL,
  PRIMARY KEY (`charid`,`hours`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `staffdesk_milestones`
--

LOCK TABLES `staffdesk_milestones` WRITE;
/*!40000 ALTER TABLE `staffdesk_milestones` DISABLE KEYS */;
/*!40000 ALTER TABLE `staffdesk_milestones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `staffdesk_parcels`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `staffdesk_parcels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) DEFAULT NULL,
  `discordid` varchar(32) DEFAULT NULL,
  `kind` varchar(8) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `label` varchar(100) NOT NULL DEFAULT '',
  `amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `note` varchar(200) NOT NULL DEFAULT '',
  `sent_by` varchar(100) NOT NULL DEFAULT '',
  `origin` varchar(16) NOT NULL DEFAULT 'staff',
  `created_at` int(11) NOT NULL,
  `claimed_at` int(11) DEFAULT NULL,
  `claimed_by` int(11) DEFAULT NULL,
  `cancelled_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_char` (`charid`,`claimed_at`),
  KEY `idx_discord` (`discordid`,`claimed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `staffdesk_parcels`
--

LOCK TABLES `staffdesk_parcels` WRITE;
/*!40000 ALTER TABLE `staffdesk_parcels` DISABLE KEYS */;
/*!40000 ALTER TABLE `staffdesk_parcels` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `staffdesk_renames`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `staffdesk_renames` (
  `kind` varchar(16) NOT NULL,
  `ref` varchar(64) NOT NULL,
  `named_at` int(11) NOT NULL,
  PRIMARY KEY (`kind`,`ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `staffdesk_renames`
--

LOCK TABLES `staffdesk_renames` WRITE;
/*!40000 ALTER TABLE `staffdesk_renames` DISABLE KEYS */;
/*!40000 ALTER TABLE `staffdesk_renames` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `storage_boxes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `storage_boxes` (
  `box_id` varchar(20) NOT NULL,
  `capacity` int(11) NOT NULL DEFAULT 500,
  `placed` tinyint(1) NOT NULL DEFAULT 0,
  `pos_x` float DEFAULT NULL,
  `pos_y` float DEFAULT NULL,
  `pos_z` float DEFAULT NULL,
  `pos_h` float DEFAULT NULL,
  `item_name` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`box_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `storage_boxes`
--

LOCK TABLES `storage_boxes` WRITE;
/*!40000 ALTER TABLE `storage_boxes` DISABLE KEYS */;
/*!40000 ALTER TABLE `storage_boxes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tradepost_accounts`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tradepost_accounts` (
  `charid` int(11) NOT NULL,
  `balance` decimal(12,2) NOT NULL DEFAULT 0.00,
  `lifetime` decimal(12,2) NOT NULL DEFAULT 0.00,
  `pay_with` varchar(8) NOT NULL DEFAULT 'cash',
  `bank` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tradepost_accounts`
--

LOCK TABLES `tradepost_accounts` WRITE;
/*!40000 ALTER TABLE `tradepost_accounts` DISABLE KEYS */;
/*!40000 ALTER TABLE `tradepost_accounts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tradepost_licences`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tradepost_licences` (
  `charid` int(11) NOT NULL,
  `market` varchar(32) NOT NULL,
  `inv_id` int(11) NOT NULL,
  `slots` int(11) NOT NULL DEFAULT 100,
  `created_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`,`market`),
  UNIQUE KEY `inv_id` (`inv_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tradepost_licences`
--

LOCK TABLES `tradepost_licences` WRITE;
/*!40000 ALTER TABLE `tradepost_licences` DISABLE KEYS */;
/*!40000 ALTER TABLE `tradepost_licences` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tradepost_orders`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tradepost_orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) NOT NULL,
  `market` varchar(32) NOT NULL,
  `side` enum('buy','sell') NOT NULL,
  `item` varchar(96) NOT NULL,
  `label` varchar(128) NOT NULL DEFAULT '',
  `total` int(11) NOT NULL,
  `remaining` int(11) NOT NULL,
  `price_each` decimal(12,2) NOT NULL,
  `created_at` int(11) NOT NULL,
  `expires_at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `board` (`side`,`item`),
  KEY `owner` (`charid`),
  KEY `expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tradepost_orders`
--

LOCK TABLES `tradepost_orders` WRITE;
/*!40000 ALTER TABLE `tradepost_orders` DISABLE KEYS */;
/*!40000 ALTER TABLE `tradepost_orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tradepost_trades`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tradepost_trades` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `item` varchar(96) NOT NULL,
  `label` varchar(128) NOT NULL DEFAULT '',
  `qty` int(11) NOT NULL,
  `price_each` decimal(12,2) NOT NULL,
  `buyer` int(11) NOT NULL DEFAULT 0,
  `seller` int(11) NOT NULL DEFAULT 0,
  `market` varchar(32) NOT NULL DEFAULT '',
  `traded_at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `item_time` (`item`,`traded_at`),
  KEY `buyer` (`buyer`),
  KEY `seller` (`seller`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tradepost_trades`
--

LOCK TABLES `tradepost_trades` WRITE;
/*!40000 ALTER TABLE `tradepost_trades` DISABLE KEYS */;
/*!40000 ALTER TABLE `tradepost_trades` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `underground`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `underground` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) DEFAULT NULL,
  `charidentifier` int(11) DEFAULT NULL,
  `coords` longtext DEFAULT NULL,
  `zone` varchar(50) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `theme` varchar(50) DEFAULT NULL,
  `price` float DEFAULT NULL,
  `upgrades` longtext DEFAULT '[]',
  `owned` int(11) DEFAULT 0,
  `ledger` double DEFAULT 0,
  `items` longtext DEFAULT '[]',
  `invslots` int(11) DEFAULT 0,
  `invlevel` int(11) DEFAULT 0,
  `bookie` int(11) DEFAULT 0,
  `justraided` int(11) DEFAULT 0,
  `raidcooldown` int(11) DEFAULT 0,
  `raidday` int(11) DEFAULT 0,
  `lasttimer` int(11) DEFAULT 0,
  `lasttimer2` int(11) DEFAULT 0,
  `mashinfo` longtext DEFAULT '[]',
  `stillinfo` longtext DEFAULT '[]',
  `still` longtext DEFAULT '[]',
  `coowners` longtext DEFAULT '[]',
  `webhook` varchar(255) DEFAULT NULL,
  `raidopenedat` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `underground`
--

LOCK TABLES `underground` WRITE;
/*!40000 ALTER TABLE `underground` DISABLE KEYS */;
/*!40000 ALTER TABLE `underground` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `undertaker_cut`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `undertaker_cut` (
  `job` varchar(50) NOT NULL,
  `pct` int(11) NOT NULL DEFAULT 0,
  `webhook` text DEFAULT NULL,
  PRIMARY KEY (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `identifier` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `group` varchar(50) DEFAULT 'user',
  `warnings` int(11) DEFAULT 0,
  `banned` tinyint(1) DEFAULT NULL,
  `banneduntil` int(10) DEFAULT 0,
  `char` int(11) DEFAULT 5,
  `max_jobs` int(11) DEFAULT 3,
  PRIMARY KEY (`identifier`),
  UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vorp_admin_flags`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vorp_admin_flags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) DEFAULT NULL,
  `identifier` varchar(100) NOT NULL DEFAULT '',
  `name` varchar(100) NOT NULL DEFAULT '',
  `kind` varchar(32) NOT NULL,
  `detail` varchar(255) NOT NULL DEFAULT '',
  `at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `charid` (`charid`),
  KEY `at` (`at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vorp_admin_flags`
--

LOCK TABLES `vorp_admin_flags` WRITE;
/*!40000 ALTER TABLE `vorp_admin_flags` DISABLE KEYS */;
/*!40000 ALTER TABLE `vorp_admin_flags` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wagon_stash`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wagon_stash` (
  `charid` int(11) NOT NULL,
  `stash` longtext DEFAULT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wagon_stash`
--

LOCK TABLES `wagon_stash` WRITE;
/*!40000 ALTER TABLE `wagon_stash` DISABLE KEYS */;
/*!40000 ALTER TABLE `wagon_stash` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wagons`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wagons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(40) NOT NULL,
  `charid` int(11) NOT NULL,
  `selected` int(11) NOT NULL DEFAULT 0,
  `model` varchar(50) NOT NULL,
  `name` varchar(50) NOT NULL,
  `items` longtext DEFAULT '{}',
  PRIMARY KEY (`id`),
  KEY `FK_horses_characters` (`charid`),
  KEY `model` (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wagons`
--

LOCK TABLES `wagons` WRITE;
/*!40000 ALTER TABLE `wagons` DISABLE KEYS */;
/*!40000 ALTER TABLE `wagons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `weapon_craft_locations`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `weapon_craft_locations` (
  `name` varchar(64) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `job` longtext DEFAULT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `weapon_recipes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `weapon_recipes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kind` varchar(8) NOT NULL,
  `category` varchar(64) NOT NULL,
  `label` varchar(128) NOT NULL,
  `enabled` tinyint(4) NOT NULL DEFAULT 1,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `kind_cat_label` (`kind`,`category`,`label`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `whitelist`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `whitelist` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `status` tinyint(1) DEFAULT NULL,
  `firstconnection` tinyint(1) DEFAULT 1,
  `discordid` varchar(255) DEFAULT '0',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `identifier` (`identifier`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `whitelist`
--

LOCK TABLES `whitelist` WRITE;
/*!40000 ALTER TABLE `whitelist` DISABLE KEYS */;
/*!40000 ALTER TABLE `whitelist` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `workbench_favourites`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `workbench_favourites` (
  `charid` int(11) NOT NULL,
  `ids` longtext NOT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `workbench_favourites`
--

LOCK TABLES `workbench_favourites` WRITE;
/*!40000 ALTER TABLE `workbench_favourites` DISABLE KEYS */;
/*!40000 ALTER TABLE `workbench_favourites` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `world_props`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `world_props` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model` varchar(100) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `rx` double NOT NULL DEFAULT 0,
  `ry` double NOT NULL DEFAULT 0,
  `rz` double NOT NULL DEFAULT 0,
  `frozen` tinyint(4) NOT NULL DEFAULT 1,
  `collision` tinyint(4) NOT NULL DEFAULT 1,
  `label` varchar(100) DEFAULT NULL,
  `placed_by` int(11) DEFAULT NULL,
  `placed_by_name` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `bypos` (`x`,`y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'VORPCore_290045'
--
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_VALUE_ON_ZERO' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE PROCEDURE `AlterTableMail`()
BEGIN
    DECLARE table_exists INT DEFAULT 0;
    DECLARE adress_exists INT DEFAULT 0;
    DECLARE adressbook_exists INT DEFAULT 0;
    DECLARE identifier_exists INT DEFAULT 0;

    
    SELECT COUNT(*) INTO table_exists
    FROM information_schema.TABLES
    WHERE TABLE_NAME = 'mail';
    
    
    IF table_exists = 1 THEN
        SELECT COUNT(*) INTO adress_exists
        FROM information_schema.COLUMNS
        WHERE TABLE_NAME = 'mail' AND COLUMN_NAME = 'adress';

        SELECT COUNT(*) INTO adressbook_exists
        FROM information_schema.COLUMNS
        WHERE TABLE_NAME = 'mail' AND COLUMN_NAME = 'adressbook';

        SELECT COUNT(*) INTO identifier_exists
        FROM information_schema.COLUMNS
        WHERE TABLE_NAME = 'mail' AND COLUMN_NAME = 'identifier';

        
        IF adress_exists = 1 THEN
            SET @sql = 'ALTER TABLE mail CHANGE `adress` `address` int(11) NOT NULL AUTO_INCREMENT;';
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END IF;

        IF adressbook_exists = 1 THEN
            SET @sql = 'ALTER TABLE mail DROP COLUMN adressbook;';
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END IF;

        IF identifier_exists = 1 THEN
            SET @sql = 'ALTER TABLE mail DROP COLUMN identifier;';
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END IF;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed
