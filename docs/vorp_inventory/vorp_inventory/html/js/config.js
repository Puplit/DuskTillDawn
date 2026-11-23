let Config = new Object();
Config.closeKeys = [113, 27];
Config.UseGoldItem = false;
Config.AddGoldItem = false;
Config.AddDollarItem = false;
Config.UseRolItem = false;
Config.AddRollItem = false;
Config.AddAmmoItem = false;
Config.WeightMeasure = "kg";
Config.MaxItemTransferAmount = 200;
Config.EnableCopySerial = true;
Config.EnableHotbar = true;
Config.EnableHandCraftButton = false;
Config.EnableSaddleButton = false;
Config.EnableWeaponAttachments = false;
// pup: "Drop advanced" context row (gizmo prop placement). Overwritten from
// CONFIG.ENABLE_ADVANCED_DROP on every inventory open; false here so the row is
// absent even if that payload has not arrived yet.
Config.EnableAdvancedDrop = false;
Config.HotbarAllow = "all";
Config.MainInventoryWheelScale = 0.45;
Config.ItemRaritySlotStyle = "border";
Config.TooltipPlacement = "hover";
Config.MainInventoryFixedSlotCount = 200;
// pup: the satchel draws only as many squares as it needs instead of always
// painting all 200 (17 items would mean scrolling past 183 empty cells).
// The 200 above is still the real capacity and is what the footer counts against.
Config.MainInventoryGrowSlots  = true; // false = always draw the full 200
Config.MainInventorySpareSlots = 8;    // free squares kept below the last item
Config.MainInventoryMinSlots   = 24;   // never draw fewer than this
// pup: slot badges read "held / stack limit" (3/20). Set false for a bare count.
// Items whose limit is -1 or 0 (no limit) always show just the number.
Config.ShowItemStackLimit = true;
// pup: "Limit x/y" + "Weight n" lines in the item tooltip. Off because weight is
// not a mechanic here (fixed 200-slot satchel, every item weighs 1) and the slot
// badge already carries the limit. Set true to show both lines.
Config.ShowTooltipLimitWeight = false;
// pup: the COMMON / UNCOMMON / RARE line at the bottom of the item tooltip. Off,
// so a tooltip is the item's name, art and description and nothing else - the
// same clean read the store panels give. This is the TOOLTIP TEXT only: the
// coloured slot borders that mark a rare item in the grid still show.
Config.ShowTooltipRarity = false;
// pup: hard ceiling on how many slot cells the SECONDARY panel (house / stash /
// container) will draw, whatever capacity the container reports. Purely a DOM guard.
Config.SecondaryInventoryMaxSlotCount = 200;
Config.ManualWeaponReload = true;
