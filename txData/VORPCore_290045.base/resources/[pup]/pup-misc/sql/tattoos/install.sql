-- pup-misc / tattoos | install.sql
--
-- Creates:  no tables. Adds two columns to the VORP core characters table:
--             overlay      the saved tattoo and makeup layers (JSON)
--             expressions  the saved Body Adjustments (JSON)
-- Items:    none (the pocket mirror item belongs to vorp_barbershop)
-- Requires: VORP core characters (it also reads skinPlayer). Optional: murphy_barber. When that
--           table exists, a mirror save blanks its overlay columns.
--
-- server/tattoos/main.lua also creates both columns on start if they are missing.
-- ADD COLUMN IF NOT EXISTS is MariaDB syntax (this server runs MariaDB).
-- Safe to run more than once.

ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `overlay` longtext DEFAULT NULL;
ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `expressions` longtext DEFAULT NULL;
