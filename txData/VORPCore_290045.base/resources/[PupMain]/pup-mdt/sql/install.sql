-- pup-mdt install script. Safe to run more than once (MariaDB).

CREATE TABLE IF NOT EXISTS `mdt_criminals` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `player_id` INT NULL DEFAULT 0,
  `identity` VARCHAR(50) NOT NULL,
  `photo_url` TEXT NULL,
  `firstname` VARCHAR(50) NULL,
  `lastname` VARCHAR(50) NULL,
  `age` INT NOT NULL DEFAULT 0,
  `description` TEXT NULL,
  `status` ENUM('wanted','clear','released') NOT NULL DEFAULT 'clear',
  `wanted_by_hand` TINYINT(1) NOT NULL DEFAULT 0,
  `registered_by` VARCHAR(100) NULL,
  `registered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_identity` (`identity`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_evidence` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `criminal_id` INT NULL,
  `title` TEXT NULL,
  `description` TEXT NULL,
  `created_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_criminal` (`criminal_id`),
  CONSTRAINT `fk_mdt_evidence_criminal` FOREIGN KEY (`criminal_id`) REFERENCES `mdt_criminals` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_lawman_profiles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `player_id` INT NULL DEFAULT 0,
  `citizen_id` VARCHAR(50) NOT NULL,
  `photo_url` TEXT NULL,
  `rank` VARCHAR(50) NOT NULL DEFAULT 'Deputy',
  `department` VARCHAR(100) NULL,
  `region` VARCHAR(50) NULL,
  `trainings` TEXT NULL,
  `description` TEXT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `duty_time_minutes` INT NOT NULL DEFAULT 0,
  `last_duty_update` TIMESTAMP NULL,
  `loa_until` DATE NULL,
  `callsign` VARCHAR(20) NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizen_id`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_lawman_stats` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `player_id` INT NULL DEFAULT 0,
  `citizen_id` VARCHAR(50) NOT NULL,
  `criminals_registered` INT NOT NULL DEFAULT 0,
  `arrests_made` INT NOT NULL DEFAULT 0,
  `fines_applied` INT NOT NULL DEFAULT 0,
  `evidences_collected` INT NOT NULL DEFAULT 0,
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- read directly by vorp_character and pup-spawnselect (charidentifier as text, status 'active', jail_time > 0)
CREATE TABLE IF NOT EXISTS `mdt_prison_records` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `player_name` VARCHAR(100) NULL,
  `charidentifier` VARCHAR(50) NULL,
  `jail_time` INT NOT NULL DEFAULT 0,
  `sentence_minutes` INT NOT NULL DEFAULT 0,
  `imprisoned_by` VARCHAR(100) NULL,
  `imprisoned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` ENUM('active','completed') NOT NULL DEFAULT 'active',
  `fine_amount` INT NOT NULL DEFAULT 0,
  `reason` TEXT NULL,
  `is_bounty_claim` TINYINT(1) NOT NULL DEFAULT 0,
  `cell_x` DOUBLE NULL,
  `cell_y` DOUBLE NULL,
  `cell_z` DOUBLE NULL,
  `cell_h` DOUBLE NULL,
  `escape_radius` DOUBLE NULL,
  `exit_x` DOUBLE NULL,
  `exit_y` DOUBLE NULL,
  `exit_z` DOUBLE NULL,
  `exit_h` DOUBLE NULL,
  PRIMARY KEY (`id`),
  KEY `idx_char_status` (`charidentifier`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_fine_types` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `category` ENUM('theft','violence','public_order','weapons','property','animals','other') NOT NULL DEFAULT 'other',
  `amount` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `jail_time` INT NOT NULL DEFAULT 0,
  `description` TEXT NULL,
  `notes` TEXT NULL,
  `severity` ENUM('low','medium','high','critical') NOT NULL DEFAULT 'low',
  `created_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_penal_codes` (
  `code` VARCHAR(20) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `charge_class` ENUM('felony','misdemeanor','infraction') NOT NULL DEFAULT 'misdemeanor',
  `months` INT NOT NULL DEFAULT 0,
  `fine` INT NOT NULL DEFAULT 0,
  `color` VARCHAR(20) NOT NULL DEFAULT 'green',
  `description` VARCHAR(255) NULL,
  `category` VARCHAR(40) NULL,
  `burdens` TEXT NULL,
  `definitions` TEXT NULL,
  `tiers` TEXT NULL,
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `report_number` VARCHAR(20) NULL,
  `title` VARCHAR(100) NOT NULL,
  `type` VARCHAR(50) NOT NULL DEFAULT 'Incident Report',
  `location` VARCHAR(200) NULL,
  `content` LONGTEXT NULL,
  `content_plaintext` TEXT NULL,
  `crimes_json` LONGTEXT NULL,
  `reduction_percent` INT NOT NULL DEFAULT 0,
  `jail_reduction_percent` INT NOT NULL DEFAULT 0,
  `fine_reduction_percent` INT NOT NULL DEFAULT 0,
  `author_citizenid` VARCHAR(50) NULL,
  `author_name` VARCHAR(100) NULL,
  `confiscated_items` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_number` (`report_number`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_involved` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `reportid` INT NOT NULL,
  `citizenid` VARCHAR(50) NULL,
  `name` VARCHAR(100) NULL,
  `type` ENUM('suspect','victim','witness','lawman') NOT NULL DEFAULT 'suspect',
  `notes` TEXT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`),
  CONSTRAINT `fk_rep_involved` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_lawmen` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `reportid` INT NOT NULL,
  `citizenid` VARCHAR(50) NULL,
  `name` VARCHAR(100) NULL,
  `role` ENUM('lead','assisting','supervisor','consulting') NOT NULL DEFAULT 'assisting',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_rep_lawmen` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_charges` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `reportid` INT NOT NULL,
  `citizenid` VARCHAR(50) NULL,
  `charge_label` VARCHAR(100) NULL,
  `charge_code` VARCHAR(20) NULL,
  `charge_class` ENUM('felony','misdemeanor','infraction') NULL,
  `count` INT NOT NULL DEFAULT 1,
  `jail_time` INT NOT NULL DEFAULT 0,
  `fine` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`),
  CONSTRAINT `fk_rep_charges` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_warrants` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `reportid` INT NULL,
  `citizenid` VARCHAR(50) NOT NULL DEFAULT '',
  `citizen_name` VARCHAR(100) NULL,
  `charges` TEXT NULL,
  `notes` TEXT NULL,
  `felonies` INT NOT NULL DEFAULT 0,
  `misdemeanors` INT NOT NULL DEFAULT 0,
  `infractions` INT NOT NULL DEFAULT 0,
  `expiry_date` TIMESTAMP NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL 7 DAY),
  `issued_by` VARCHAR(100) NULL,
  `status` ENUM('active','expired','served','revoked') NOT NULL DEFAULT 'active',
  `image_url` VARCHAR(500) NULL,
  `bounty_fine` INT NOT NULL DEFAULT 0,
  `bounty_jailtime` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `claimed_by` VARCHAR(100) NULL,
  `bounty_reward` INT NOT NULL DEFAULT 0,
  `revoked_at` TIMESTAMP NULL,
  `revoked_by` VARCHAR(100) NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_expungements` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizen_identity` VARCHAR(50) NOT NULL,
  `citizen_name` VARCHAR(100) NULL,
  `reason` TEXT NULL,
  `requested_by_citizenid` VARCHAR(50) NULL,
  `requested_by_name` VARCHAR(100) NULL,
  `requested_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` ENUM('pending','approved','denied') NOT NULL DEFAULT 'pending',
  `reviewed_by_citizenid` VARCHAR(50) NULL,
  `reviewed_by_name` VARCHAR(100) NULL,
  `reviewed_at` TIMESTAMP NULL,
  `review_notes` TEXT NULL,
  `snapshot` LONGTEXT NULL,
  `records_cleared` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizen_identity`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_bolos` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(30) NOT NULL DEFAULT 'witness_statement',
  `subject_name` VARCHAR(100) NULL,
  `po_number` VARCHAR(50) NULL,
  `location` VARCHAR(200) NULL,
  `description` TEXT NULL,
  `lawman_name` VARCHAR(100) NULL,
  `region` VARCHAR(50) NULL,
  `status` ENUM('active','inactive','resolved') NOT NULL DEFAULT 'active',
  `issued_by` VARCHAR(50) NULL,
  `issued_by_name` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_cases` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `case_number` VARCHAR(20) NOT NULL,
  `title` VARCHAR(150) NOT NULL,
  `location` VARCHAR(200) NULL,
  `description` TEXT NULL,
  `status` ENUM('open','active','suspended','closed') NOT NULL DEFAULT 'open',
  `priority` ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
  `created_by` VARCHAR(100) NULL,
  `created_citizenid` VARCHAR(50) NULL,
  `investigator_name` VARCHAR(100) NULL,
  `assigned_lawmen` TEXT NULL,
  `linked_reports` TEXT NULL,
  `linked_evidence` TEXT NULL,
  `confiscated_items` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_case_number` (`case_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_cases_involved` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `caseid` INT NOT NULL,
  `citizenid` VARCHAR(50) NULL,
  `name` VARCHAR(100) NULL,
  `type` ENUM('suspect','victim','witness','person_of_interest') NOT NULL DEFAULT 'suspect',
  `notes` TEXT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`),
  CONSTRAINT `fk_case_involved` FOREIGN KEY (`caseid`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_cases_lawmen` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `caseid` INT NOT NULL,
  `citizenid` VARCHAR(50) NULL,
  `name` VARCHAR(100) NULL,
  `role` ENUM('lead','assisting','supervisor','consulting') NOT NULL DEFAULT 'assisting',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_case_lawmen` FOREIGN KEY (`caseid`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_arrests` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizen_identity` VARCHAR(50) NOT NULL,
  `citizen_name` VARCHAR(100) NULL,
  `lawman_citizenid` VARCHAR(50) NULL,
  `lawman_name` VARCHAR(100) NULL,
  `charges` LONGTEXT NULL,
  `total_fine` INT NOT NULL DEFAULT 0,
  `total_months` INT NOT NULL DEFAULT 0,
  `discount_percent` INT NOT NULL DEFAULT 0,
  `fine_discount_percent` INT NOT NULL DEFAULT 0,
  `jail_discount_percent` INT NOT NULL DEFAULT 0,
  `final_fine` INT NOT NULL DEFAULT 0,
  `final_months` INT NOT NULL DEFAULT 0,
  `notes` TEXT NULL,
  `fine_applied` TINYINT(1) NOT NULL DEFAULT 0,
  `jail_applied` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizen_identity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_evidence_items` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(30) NOT NULL DEFAULT 'other',
  `label` VARCHAR(150) NOT NULL,
  `description` TEXT NULL,
  `location_found` VARCHAR(200) NULL,
  `collected_by` VARCHAR(100) NULL,
  `linked_case` VARCHAR(30) NULL,
  `status` ENUM('collected','analyzed','stored','destroyed') NOT NULL DEFAULT 'collected',
  `notes` TEXT NULL,
  `image_urls` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_case` (`linked_case`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_permissions_overrides` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `lawman_name` VARCHAR(100) NULL,
  `permissions` LONGTEXT NULL,
  `updated_by` VARCHAR(100) NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_audit_log` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `action` VARCHAR(80) NOT NULL,
  `actor_citizenid` VARCHAR(50) NULL,
  `actor_name` VARCHAR(100) NULL,
  `target_citizenid` VARCHAR(50) NULL,
  `target_name` VARCHAR(100) NULL,
  `details` TEXT NULL,
  `metadata` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_action` (`action`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_bulletins` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(200) NOT NULL,
  `content` TEXT NULL,
  `type` ENUM('general','urgent','motd') NOT NULL DEFAULT 'general',
  `posted_by_citizenid` VARCHAR(50) NULL,
  `posted_by_name` VARCHAR(100) NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_tips` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizen_identity` VARCHAR(50) NULL,
  `citizen_name` VARCHAR(100) NULL,
  `anonymous` TINYINT(1) NOT NULL DEFAULT 0,
  `message` TEXT NOT NULL,
  `location` VARCHAR(120) NULL,
  `status` ENUM('new','read') NOT NULL DEFAULT 'new',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_settings` (
  `setting_key` VARCHAR(64) NOT NULL,
  `setting_value` TEXT NULL,
  `updated_by` VARCHAR(100) NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_bail` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `prison_record_id` INT NULL,
  `citizen_identity` VARCHAR(50) NOT NULL,
  `citizen_name` VARCHAR(100) NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `reason` TEXT NULL,
  `status` ENUM('pending','processing','active','appeared','skipped','denied') NOT NULL DEFAULT 'pending',
  `remaining_seconds` INT NOT NULL DEFAULT 0,
  `paid` TINYINT NOT NULL DEFAULT 0,
  `requested_by_citizenid` VARCHAR(50) NULL,
  `requested_by_name` VARCHAR(100) NULL,
  `requested_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_by_citizenid` VARCHAR(50) NULL,
  `reviewed_by_name` VARCHAR(100) NULL,
  `reviewed_at` TIMESTAMP NULL,
  `review_notes` TEXT NULL,
  `court_due` TIMESTAMP NULL,
  `resolved_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizen_identity`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_appeals` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `prison_record_id` INT NULL,
  `citizen_identity` VARCHAR(50) NOT NULL,
  `citizen_name` VARCHAR(100) NULL,
  `reduction_minutes` INT NOT NULL DEFAULT 0,
  `commute` TINYINT(1) NOT NULL DEFAULT 0,
  `reason` TEXT NULL,
  `status` ENUM('pending','approved','denied') NOT NULL DEFAULT 'pending',
  `minutes_reduced` INT NOT NULL DEFAULT 0,
  `requested_by_citizenid` VARCHAR(50) NULL,
  `requested_by_name` VARCHAR(100) NULL,
  `requested_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_by_citizenid` VARCHAR(50) NULL,
  `reviewed_by_name` VARCHAR(100) NULL,
  `reviewed_at` TIMESTAMP NULL,
  `review_notes` TEXT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizen_identity`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_case_defense` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `lawyer_citizenid` VARCHAR(50) NOT NULL,
  `lawyer_name` VARCHAR(100) NULL,
  `assigned_by_citizenid` VARCHAR(50) NULL,
  `assigned_by_name` VARCHAR(100) NULL,
  `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_case_lawyer` (`case_id`, `lawyer_citizenid`),
  CONSTRAINT `fk_defense_case` FOREIGN KEY (`case_id`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_case_statements` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `author_citizenid` VARCHAR(50) NULL,
  `author_name` VARCHAR(100) NULL,
  `author_role` ENUM('defense','law') NOT NULL DEFAULT 'law',
  `statement` TEXT NOT NULL,
  `filed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_statement_case` FOREIGN KEY (`case_id`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_lawyer_stats` (
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NULL,
  `duty_minutes` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_most_wanted` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizen_identity` VARCHAR(50) NULL,
  `name` VARCHAR(100) NOT NULL,
  `crimes` TEXT NULL,
  `danger` ENUM('low','medium','high','extreme') NOT NULL DEFAULT 'medium',
  `reward` INT NOT NULL DEFAULT 0,
  `notes` TEXT NULL,
  `photo_url` VARCHAR(500) NULL,
  `status` ENUM('active','captured') NOT NULL DEFAULT 'active',
  `added_by_citizenid` VARCHAR(50) NULL,
  `added_by_name` VARCHAR(100) NULL,
  `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `captured_by_name` VARCHAR(100) NULL,
  `captured_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_ledger` (
  `job` VARCHAR(64) NOT NULL,
  `balance` BIGINT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_ledger_log` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job` VARCHAR(64) NOT NULL,
  `type` VARCHAR(32) NOT NULL,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `balance_after` BIGINT NOT NULL DEFAULT 0,
  `actor_name` VARCHAR(100) NULL,
  `note` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_job` (`job`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `evidence_lockers` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `station` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NULL,
  `items` LONGTEXT NULL,
  `weapons` LONGTEXT NULL,
  `updated` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_station` (`station`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- columns older installs may lack
ALTER TABLE `mdt_criminals` ADD COLUMN IF NOT EXISTS `wanted_by_hand` TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE `mdt_evidence_items` ADD COLUMN IF NOT EXISTS `image_urls` TEXT NULL;
ALTER TABLE `mdt_evidence_items` ADD COLUMN IF NOT EXISTS `collected_by` VARCHAR(100) NULL;
ALTER TABLE `mdt_prison_records` ADD COLUMN IF NOT EXISTS `charidentifier` VARCHAR(50) NULL;
ALTER TABLE `mdt_reports_warrants` ADD COLUMN IF NOT EXISTS `revoked_by` VARCHAR(100) NULL;
ALTER TABLE `mdt_reports_warrants` ADD COLUMN IF NOT EXISTS `revoked_at` TIMESTAMP NULL;

-- the MDT item (opens the terminal when the /mdt command is switched off)
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`, `weight`)
VALUES ('mdt', 'Mobile Data Terminal', 1, 1, 'item_standard', 0, 'A lawman''s mobile data terminal.', 1.00);

-- ledgers
INSERT IGNORE INTO `mdt_ledger` (`job`, `balance`) VALUES ('police', 0);

-- penal code seed (64 charges). Western-themed placeholder set written for this build;
-- replace with the server's own rows if wanted. 1 month = 1 minute of jail.
INSERT IGNORE INTO `mdt_penal_codes` (`code`, `label`, `charge_class`, `months`, `fine`, `color`, `description`) VALUES
('P.C. 1001', 'Murder', 'felony', 120, 1500, 'red', 'Killing another person with intent or malice aforethought.'),
('P.C. 1002', 'Manslaughter', 'felony', 80, 1000, 'red', 'Killing another person without intent, through recklessness or a quarrel.'),
('P.C. 1003', 'Attempted Murder', 'felony', 90, 1200, 'red', 'Trying to kill another person and failing.'),
('P.C. 1004', 'Assault with a Deadly Weapon', 'felony', 40, 600, 'red', 'Attacking a person with a firearm, blade or other weapon.'),
('P.C. 1005', 'Assault', 'misdemeanor', 10, 200, 'orange', 'Threatening or attempting bodily harm against another person.'),
('P.C. 1006', 'Battery', 'misdemeanor', 15, 250, 'orange', 'Striking or laying hands on another person without consent.'),
('P.C. 1007', 'Kidnapping', 'felony', 60, 1000, 'red', 'Taking or holding a person against their will.'),
('P.C. 1008', 'Hostage Taking', 'felony', 70, 1200, 'red', 'Holding a person under threat to force the hand of others.'),
('P.C. 1009', 'Robbery of a Person', 'felony', 45, 800, 'red', 'Taking property from a person by force or threat of force.'),
('P.C. 1010', 'Threatening a Citizen', 'misdemeanor', 5, 150, 'orange', 'Making threats of violence against a citizen.'),
('P.C. 1011', 'Brandishing a Firearm', 'misdemeanor', 5, 150, 'orange', 'Drawing or waving a firearm to intimidate.'),
('P.C. 1012', 'Unlawful Hanging', 'felony', 100, 1500, 'red', 'Hanging or attempting to hang a person outside the law.'),
('P.C. 1013', 'Dueling within Town Limits', 'misdemeanor', 15, 300, 'orange', 'Taking part in a duel inside a town.'),
('P.C. 1014', 'Murder of a Lawman', 'felony', 150, 2500, 'red', 'Killing a sworn officer of the law.'),
('P.C. 2001', 'Petty Theft', 'misdemeanor', 5, 100, 'orange', 'Stealing goods of small value.'),
('P.C. 2002', 'Grand Theft', 'felony', 20, 400, 'red', 'Stealing goods of considerable value.'),
('P.C. 2003', 'Burglary', 'felony', 25, 500, 'red', 'Breaking into a building to commit a crime.'),
('P.C. 2004', 'Bank Robbery', 'felony', 90, 2000, 'red', 'Robbing a bank or its vault.'),
('P.C. 2005', 'Train Robbery', 'felony', 80, 1800, 'red', 'Robbing a train, its passengers or its cargo.'),
('P.C. 2006', 'Stagecoach Robbery', 'felony', 60, 1200, 'red', 'Holding up a stagecoach or its passengers.'),
('P.C. 2007', 'Store Robbery', 'felony', 40, 800, 'red', 'Holding up a store or trading post.'),
('P.C. 2008', 'Arson', 'felony', 45, 900, 'red', 'Setting fire to a building, crop or property.'),
('P.C. 2009', 'Vandalism', 'misdemeanor', 5, 150, 'orange', 'Damaging or defacing property.'),
('P.C. 2010', 'Trespassing', 'infraction', 0, 50, 'green', 'Entering private land or property without leave.'),
('P.C. 2011', 'Possession of Stolen Goods', 'misdemeanor', 10, 250, 'orange', 'Holding goods known to be stolen.'),
('P.C. 2012', 'Grave Robbing', 'felony', 30, 600, 'red', 'Disturbing a grave to take what is buried.'),
('P.C. 3001', 'Unlawful Discharge of a Firearm', 'misdemeanor', 5, 150, 'orange', 'Firing a weapon in town or without cause.'),
('P.C. 3002', 'Possession of an Illegal Weapon', 'misdemeanor', 10, 300, 'orange', 'Carrying a weapon the law forbids.'),
('P.C. 3003', 'Use of Explosives', 'felony', 60, 1200, 'red', 'Setting off dynamite or other explosives against people or property.'),
('P.C. 3004', 'Carrying a Weapon in a Restricted Place', 'infraction', 0, 75, 'green', 'Bearing arms where they are not allowed.'),
('P.C. 3005', 'Shooting at a Lawman', 'felony', 80, 1500, 'red', 'Opening fire on a sworn officer of the law.'),
('P.C. 3006', 'Gun Running', 'felony', 50, 1000, 'red', 'Trading weapons outside the law.'),
('P.C. 4001', 'Public Intoxication', 'infraction', 0, 25, 'green', 'Being drunk and disorderly in public.'),
('P.C. 4002', 'Disturbing the Peace', 'infraction', 0, 50, 'green', 'Making a public nuisance of oneself.'),
('P.C. 4003', 'Indecent Exposure', 'misdemeanor', 5, 100, 'orange', 'Exposing oneself in public.'),
('P.C. 4004', 'Loitering', 'infraction', 0, 25, 'green', 'Idling where told to move along.'),
('P.C. 4005', 'Brawling', 'misdemeanor', 5, 150, 'orange', 'Fist fighting in public.'),
('P.C. 4006', 'Reckless Riding', 'infraction', 0, 75, 'green', 'Riding or driving a team with no regard for others.'),
('P.C. 4007', 'Inciting a Riot', 'felony', 25, 500, 'red', 'Stirring a crowd to violence.'),
('P.C. 5001', 'Obstruction of Justice', 'misdemeanor', 10, 300, 'orange', 'Hindering a lawman in the course of their duty.'),
('P.C. 5002', 'Resisting Arrest', 'misdemeanor', 10, 250, 'orange', 'Fighting or refusing a lawful arrest.'),
('P.C. 5003', 'Evading the Law', 'misdemeanor', 15, 300, 'orange', 'Fleeing from a lawman.'),
('P.C. 5004', 'Escaping Custody', 'felony', 40, 800, 'red', 'Breaking out of a cell, prison or a lawman''s custody.'),
('P.C. 5005', 'Impersonating a Lawman', 'felony', 30, 600, 'red', 'Passing oneself off as an officer of the law.'),
('P.C. 5006', 'Bribery', 'felony', 30, 700, 'red', 'Offering money or favours to sway an official.'),
('P.C. 5007', 'Perjury', 'misdemeanor', 15, 400, 'orange', 'Lying under oath.'),
('P.C. 5008', 'Failure to Pay a Fine', 'infraction', 0, 100, 'green', 'Not settling a fine owed.'),
('P.C. 5009', 'Contempt of Court', 'misdemeanor', 10, 200, 'orange', 'Disrespecting or disobeying the court.'),
('P.C. 5010', 'Aiding and Abetting', 'misdemeanor', 15, 400, 'orange', 'Helping another commit a crime.'),
('P.C. 5011', 'Harbouring a Fugitive', 'misdemeanor', 20, 450, 'orange', 'Hiding or sheltering a wanted person.'),
('P.C. 5012', 'Corruption of a Public Official', 'felony', 60, 1500, 'red', 'An official abusing the office for gain.'),
('P.C. 6001', 'Animal Cruelty', 'misdemeanor', 5, 200, 'orange', 'Needless harm to an animal.'),
('P.C. 6002', 'Poaching', 'misdemeanor', 10, 250, 'orange', 'Hunting on protected land or out of season.'),
('P.C. 6003', 'Hunting Legendary Game without Leave', 'misdemeanor', 10, 300, 'orange', 'Taking a legendary animal without permission.'),
('P.C. 6004', 'Cattle Rustling', 'felony', 30, 600, 'red', 'Stealing cattle or other livestock.'),
('P.C. 6005', 'Unlicensed Butchering', 'infraction', 0, 75, 'green', 'Butchering and selling meat without a licence.'),
('P.C. 7001', 'Moonshining', 'felony', 25, 500, 'red', 'Running a still to make untaxed liquor.'),
('P.C. 7002', 'Possession of Moonshine', 'misdemeanor', 5, 150, 'orange', 'Holding untaxed liquor.'),
('P.C. 7003', 'Possession of Narcotics', 'misdemeanor', 10, 300, 'orange', 'Holding opium, heroin or other narcotics without a prescription.'),
('P.C. 7004', 'Narcotics Trafficking', 'felony', 60, 1200, 'red', 'Selling or moving narcotics.'),
('P.C. 7005', 'Smuggling', 'felony', 40, 800, 'red', 'Moving goods past the law to avoid duty or seizure.'),
('P.C. 7006', 'Counterfeiting', 'felony', 50, 1000, 'red', 'Making or passing false money.'),
('P.C. 7007', 'Possession of Burglary Tools', 'misdemeanor', 5, 200, 'orange', 'Carrying lockpicks or safe tools with intent.');

INSERT IGNORE INTO `mdt_penal_codes` (`code`, `label`, `charge_class`, `months`, `fine`, `color`, `description`, `category`, `burdens`, `definitions`, `tiers`) VALUES
('P.C. 2101', 'Horse Theft', 'felony', 35, 700, 'red', 'Taking a horse that belongs to another.', 'property',
 '["The horse belonged to another person.","The accused took or rode off with it without the owner''s leave.","The accused meant to keep it, sell it or keep it from the owner."]',
 '[{"term":"Horse","body":"Any saddle, draft or carriage horse, mule or donkey.","items":["Saddle horses","Draft horses","Mules and donkeys"]},{"term":"Without leave","body":"The owner did not agree, or agreed only because of a threat or a lie.","items":[]}]',
 '[{"kind":"Joyride","description":"Taken and left where it could be found.","fine":250,"months":10},{"kind":"Theft","description":"Taken to keep or sell.","fine":700,"months":35},{"kind":"Ring","description":"Part of an organised horse-stealing ring.","fine":1500,"months":70}]');
