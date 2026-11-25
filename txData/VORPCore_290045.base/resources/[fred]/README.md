# [fred]: fred_hud and fred_metabolism

Hunger, thirst, temperature and stress (`fred_metabolism`) and the HUD that shows them (`fred_hud`), modified for this server.

## Credits

Based on [SirFreddie/fred_metabolism_free](https://github.com/SirFreddie/fred_metabolism_free) by SirFreddie (Fred), which is itself an edit of kamelzarandah's edit of Malik's `spaghetti_metabolismo`. Those authors keep their rights; the upstream repository states no licence.

## Changes in this copy

- `/hud`: a layout editor to move and resize the gauges, plus the **Menus: Left/Right** setting that the pup menus (pup-ui, the stable, the gunsmith bench, the tailor and others) follow.
- An Eco Boost gauge, shown above the hunger circle by default.
- Indoors shelter: inside any interior the weather affects you less.
- Western styling taken from pup-ui (fonts and colours are loaded from pup-ui at runtime).
- The food and drink effects (`fred_consumables`) are already in the fresh database dump; `sql/install.sql` is only needed on a database made without it.

Settings are in `fred_hud/config/main.lua` and `fred_metabolism/config/main.lua`.
