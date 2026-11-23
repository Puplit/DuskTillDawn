# vorp_inventory

This is VORP's **vorp_inventory**, with this server's changes. VORP's code is by the VORP team, under VORP's licence. See [vorp_inventory/license.md](vorp_inventory/license.md).

The folder [vorp_inventory/](vorp_inventory/) holds only the files this server changed or added. It is not the whole resource. You lay it over VORP's own copy.

## Install

1. **Download VORP's inventory.**
   - Repository: https://github.com/VORPCORE/vorp_inventory-v2
   - The exact version this was tested with: https://github.com/VORPCORE/vorp_inventory-v2/archive/7927b22acf7e014b1fcb9065c6267ee5b721b1b3.zip
   - Use the tested version if VORP's newest one does not match these files.
   - Put it in `resources\[VORP]\vorp_inventory`. The folder must be called exactly `vorp_inventory`.
   - Install `vorp_lib` too, as VORP's README says.
2. **Copy this server's files over it.** Copy everything in `docs\vorp_inventory\vorp_inventory\` into your `vorp_inventory` folder. Overwrite all files when asked.
3. **Database.** The fresh database dump in this repository already has this. On a database made only from VORP's SQL, run:

   ```sql
   -- weapon upgrade tier, used by server/pup_weaponRepair.lua (pup_gunsmith)
   ALTER TABLE `loadout` ADD COLUMN IF NOT EXISTS `tier` INT(11) NOT NULL DEFAULT 0;

   -- the weapon repair kit
   INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
     ('repair_kit', 'Weapon Repair Kit', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Restores a weapon to like-new condition.', 0, NULL, NULL, 1.00);
   ```

   `server/pup_layout.lua` makes its own `inventory_layout` table when it starts.
4. **Restart the whole server**, not just the resource.

## Good to know

- **Webhooks** go in `vorp_inventory/server/config.lua`. They are blank by default, which means those logs are off.
- **If you already changed VORP's files**, step 2 overwrites your changes in the files listed below. Back up your copy first and add your changes again afterwards.
- **New files.** `server/config.lua` and every `pup_*` file are this server's own code (GPL-3.0).
- **Item pictures.** 1,944 pictures are in `html/img/items/`. 300 of them replace VORP's picture of the same name with this server's look. `golddust.png` is a copy of VORP's `gold.png`. Most pictures are RDR2 game icons (© Rockstar Games) or community-made icons.
- **Try it on a test server first.** Install VORP's copy plus these files on a test server and check the inventory before you use it on a live one.

## VORP files that are replaced

- `fxmanifest.lua`
- `config/ammo.lua`, `config/config.lua`, `config/config_server.lua`, `config/weapons.lua`
- `languages/language.lua`
- `server/server.lua`, `server/vorpInventoryApi.lua`
- `server/controllers/inventoryController.lua`
- `server/models/customInventory.lua`, `server/models/WeaponClass.lua`
- `server/services/DbService.lua`, `server/services/inventoryApiService.lua`, `server/services/inventoryService.lua`, `server/services/itemsDatabase.lua`, `server/services/UtiliyService.lua`
- `client/client.lua`
- `client/controllers/InventoryApiController.lua`, `client/controllers/inventoryController.lua`, `client/controllers/NUIController.lua`
- `client/models/WeaponClass.lua`
- `client/services/ammoService.lua`, `client/services/InventoryApiService.lua`, `client/services/InventoryService.lua`, `client/services/NUIService.lua`, `client/services/synFunctions.lua`
- `html/ui.html`, `html/css/ui.min.css`
- `html/js/config.js`, `html/js/mainInvScript.js`, `html/js/script.js`, `html/js/secondaryInvScript.js`
